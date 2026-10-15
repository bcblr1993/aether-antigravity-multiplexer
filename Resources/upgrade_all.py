#!/usr/bin/env python3
"""Build, back up and replace all local clones without rewriting their profiles."""
import argparse
import json
import os
import pathlib
import plistlib
import re
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
from datetime import datetime

from create_instance import (APP_SUPPORT, KNOWN, digest, patch_asar, replace_once,
                             require, run, sign_bundle, operation_lock)

KEY_PATTERN = re.compile(rb"[a-z0-9-]{6}-standalone-oauth-token")
WORDS = {"Second": 2, "Third": 3, "Fourth": 4, "Fifth": 5, "Sixth": 6, "Seventh": 7}
REGISTER = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"


def source_info(source):
    require(sys.platform == "darwin" and os.uname().machine == "arm64", "仅支持 Apple Silicon Mac")
    info = plistlib.loads((source / "Contents/Info.plist").read_bytes())
    version = info.get("CFBundleShortVersionString")
    require(info.get("CFBundleIdentifier") == "com.google.antigravity", "请选择官方原版 Antigravity.app")
    require(version in KNOWN, f"原版 {version} 尚未经过适配验证")
    signature = run("codesign", "-dv", "--verbose=4", str(source)).stderr
    require("TeamIdentifier=EQHXZ8M8AV" in signature and "arm64" in signature,
            "原版签名或架构不符合要求")
    run("codesign", "--verify", "--deep", "--strict", str(source))
    expected = KNOWN[version]
    require(digest(source / "Contents/Resources/app.asar") == expected["asar"], "原版 ASAR 哈希不匹配")
    require(digest(source / "Contents/Resources/bin/language_server") == expected["language_server"],
            "原版语言服务哈希不匹配")
    return version


def discover():
    results = []
    roots = [pathlib.Path("/Applications"), pathlib.Path.home() / "Applications"]
    seen = set()
    for root in roots:
        if not root.is_dir():
            continue
        for app in root.glob("Antigravity*.app"):
            try:
                info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
            except (OSError, ValueError):
                continue
            bundle = info.get("CFBundleIdentifier", "")
            if not bundle.startswith("local.antigravity.") or bundle in seen:
                continue
            seen.add(bundle)
            name = info.get("CFBundleDisplayName", app.stem)
            number_match = re.search(r"instance(\d+)$", bundle)
            index = int(number_match.group(1)) if number_match else next((n for word, n in WORDS.items() if word in name), None)
            require(index is not None, f"无法识别实例编号：{name}")
            profile = pathlib.Path.home() / f".gemini-{index - 1}"
            require(profile.is_dir(), f"缺少账号数据目录：{profile}")
            server = (app / "Contents/Resources/bin/language_server").read_bytes()
            keys = set(KEY_PATTERN.findall(server)) - {b"jetski-standalone-oauth-token"}
            require(len(keys) == 1, f"无法确认独立凭据标识：{name}")
            key = keys.pop()
            require(len(key) == len(b"jetski-standalone-oauth-token"), f"凭据标识长度异常：{name}")
            results.append({"app": app, "name": name, "bundle": bundle, "version": info.get("CFBundleShortVersionString"),
                            "index": index, "profile": profile, "key": key,
                            "user_data": pathlib.Path.home() / "Library/Application Support" / name})
    return sorted(results, key=lambda value: value["index"])


def build(source, target, instance, version, signing_dir):
    name = instance["name"]
    index = instance["index"]
    scheme = f"antigravity-{index}" if index >= 8 else f"antigravity-{name.split(' ', 1)[1].lower()}"
    old_url = b"https://antigravity.google/auth-success?app=%s"
    new_url = f"{scheme}://oauth-success?app=%s".encode()
    require(len(new_url) < len(old_url), f"回调 URL 无法适配：{name}")
    new_url += b"&" + b"x" * (len(old_url) - len(new_url) - 1)
    run("ditto", str(source), str(target))
    asar_hash = patch_asar(source / "Contents/Resources/app.asar", target / "Contents/Resources/app.asar",
                           name, instance["profile"].name, scheme)
    info_path = target / "Contents/Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    info["CFBundleIdentifier"] = instance["bundle"]
    info["CFBundleName"] = "Antigravity"
    info["CFBundleDisplayName"] = name
    info["NSAppleEventsUsageDescription"] = f"{name} 需要控制其他应用来执行你发起的自动化任务。"
    for item in info.get("CFBundleURLTypes", []):
        item["CFBundleURLSchemes"] = [scheme]
    info["ElectronAsarIntegrity"]["Resources/app.asar"]["hash"] = asar_hash
    info_path.write_bytes(plistlib.dumps(info))
    server_path = target / "Contents/Resources/bin/language_server"
    server = bytearray(server_path.read_bytes())
    at = KNOWN[version]["keyring_bypass_offset"]
    require(server[at:at + 12] == bytes.fromhex("900b40f9f1c301d13f0210eb"),
            f"凭据存储结构不匹配：{name}")
    server[at:at + 16] = struct.pack("<4I", 0xd2800020, 0xaa1f03e1, 0xaa1f03e2, 0xd65f03c0)
    server = replace_once(server, b"jetski-standalone-oauth-token", instance["key"], "credential key")
    server = replace_once(server, old_url, new_url, "callback URL")
    server_path.write_bytes(server)
    sign_bundle(target, name, instance["bundle"], signing_dir)
    return scheme


def get_current_host_app():
    pid = os.getpid()
    for _ in range(15):
        try:
            out = subprocess.check_output(['ps', '-p', str(pid), '-o', 'ppid=,comm='], text=True).strip()
            parts = out.split(None, 1)
            if len(parts) == 2:
                comm = parts[1]
                if '/Applications/Antigravity' in comm:
                    idx = comm.find('.app')
                    if idx != -1:
                        return pathlib.Path(comm[:idx + 4])
                pid = int(parts[0])
            else:
                break
        except Exception:
            break
    return None


def stop_apps(instances):
    host_app = get_current_host_app()
    target_instances = [item for item in instances if host_app is None or item["app"] != host_app]
    if host_app:
        for item in instances:
            if item["app"] == host_app:
                print(f"  注意：{item['name']} 为当前会话宿主实例，跳过进程终止以保持会话连线（文件将在磁盘热替换）", flush=True)

    roots = [str(item["app"]) + "/Contents/" for item in target_instances]
    main_paths = {str(item["app"] / "Contents/MacOS/Antigravity") for item in target_instances}
    active = []
    for line in subprocess.check_output(["ps", "-axo", "pid=,comm="], text=True).splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2 and parts[1] in main_paths:
            active.append(int(parts[0]))
    for pid in active:
        os.kill(pid, signal.SIGTERM)
    for attempt in range(200):
        if attempt == 50:
            for pid in active:
                try:
                    os.kill(pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
        commands = [line.strip().split(None, 1)[1] for line in subprocess.check_output(
            ["ps", "-axo", "pid=,comm="], text=True).splitlines() if len(line.strip().split(None, 1)) == 2]
        if not any(command.startswith(root) for root in roots for command in commands):
            return
        time.sleep(.1)
    raise RuntimeError("仍有实例进程在运行；请先保存工作并正常退出后重试")


def backup(instances, backup_dir):
    backup_dir.mkdir(parents=True, mode=0o700)
    for item in instances:
        number = item["index"]
        for label, path in [("app", item["app"]), ("profile", item["profile"]), ("window", item["user_data"])]:
            if not path.exists():
                continue
            archive = backup_dir / f"instance-{number}-{label}.zip"
            run("ditto", "-c", "-k", "--keepParent", str(path), str(archive))
            require(archive.stat().st_size > 0, f"备份失败：{archive}")
            run("unzip", "-tq", str(archive))
        print(f"已备份 {item['name']} 的程序和数据", flush=True)


def version_tuple(version):
    parts = str(version).split(".")
    require(all(part.isdigit() for part in parts), f"无法比较版本号：{version}")
    return tuple(int(part) for part in parts)


def get_running_instances(instances):
    main_paths = {str(item["app"] / "Contents/MacOS/Antigravity") for item in instances}
    running = []
    try:
        out = subprocess.check_output(["ps", "-axo", "pid=,comm="], text=True)
        for line in out.splitlines():
            parts = line.strip().split(None, 1)
            if len(parts) == 2 and parts[1] in main_paths:
                for item in instances:
                    if str(item["app"] / "Contents/MacOS/Antigravity") == parts[1] and item not in running:
                        running.append(item)
    except Exception:
        pass
    return running


def upgrade_all(source, dry_run=False, only_indices=None, build_only=False, skip_backup=False, force=False):
    print("[PROGRESS:5] 正在验证主程序版本与签名完整性...", flush=True)
    version = source_info(source)
    instances = discover()
    pending = [item for item in instances if (force or version_tuple(item["version"]) < version_tuple(version)) and (only_indices is None or item["index"] in only_indices)]
    print(f"[PROGRESS:12] 本机主实例：{version}；发现 {len(instances)} 个副本；待升级/重适配 {len(pending)} 个", flush=True)
    for item in pending:
        tag = f"{item['version']} → {version}" if item['version'] != version else f"{item['version']} (刷新适配补丁)"
        print(f"  {item['name']}: {tag}", flush=True)
    if dry_run or not pending:
        print("[PROGRESS:100] 无需升级或已完成预检", flush=True)
        return
    APP_SUPPORT.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup_dir = APP_SUPPORT / "Backups" / stamp if not skip_backup else None
    total_count = len(pending)
    with tempfile.TemporaryDirectory(prefix="upgrade-staging-", dir=APP_SUPPORT) as temporary:
        staging = pathlib.Path(temporary)
        built = []
        for i, item in enumerate(pending):
            name = item["name"]
            pct = 15 + int(45 * i / max(1, total_count))
            print(f"[PROGRESS:{pct}] 正在从主实例本地复制、适配并验签：{name} ({i+1}/{total_count})", flush=True)
            target = staging / f"{name}.app"
            signing_dir = staging / f"sign-{item['index']}"
            signing_dir.mkdir()
            scheme = build(source, target, item, version, signing_dir)
            built.append((item, target, scheme))
        if build_only:
            print("[PROGRESS:100] 所有待升级副本已完成构建和深度签名验证；未替换现有实例", flush=True)
            return
        print("[PROGRESS:62] 所有新副本已通过签名检查；正在安全关闭运行中实例...", flush=True)
        running_apps = get_running_instances(pending)
        stop_apps(pending)
        if not skip_backup:
            print("[PROGRESS:68] 正在创建旧程序、账号数据与窗口缓存安全备份...", flush=True)
            backup(pending, backup_dir)
            print("[PROGRESS:76] 备份已生成并完成完整性校验", flush=True)
        else:
            print("[PROGRESS:76] ⚡️ 用户已选择不备份直接升级，跳过备份归档", flush=True)
        moved = []
        try:
            for i, (item, target, scheme) in enumerate(built):
                pct = 78 + int(18 * i / max(1, total_count))
                print(f"[PROGRESS:{pct}] 正在原子替换安装：{item['name']} ({i+1}/{total_count})", flush=True)
                old = item["app"]
                held = staging / f"held-{item['index']}.oldbundle"
                old.rename(held)
                try:
                    target.rename(old)
                except Exception:
                    held.rename(old)
                    raise
                moved.append((item, held))
                run(REGISTER, "-f", str(old))
                print(f"已安装：{item['name']}", flush=True)
        except Exception:
            for item, held in reversed(moved):
                app = item["app"]
                failed = staging / f"failed-{item['index']}.oldbundle"
                app.rename(failed)
                held.rename(app)
                run(REGISTER, "-f", str(app))
            raise
        print("[PROGRESS:96] 正在更新实例元数据清单与版本标识...", flush=True)
        for item, target, scheme in built:
            manifest = APP_SUPPORT / f"instance-{item['index']}.json"
            record = json.loads(manifest.read_text()) if manifest.exists() else {}
            record.update({"index": item["index"], "name": item["name"], "app": str(item["app"]),
                           "profile": str(item["profile"]), "version": version, "scheme": scheme,
                           "source_asar_sha256": KNOWN[version]["asar"],
                           "login_verified": False})
            if backup_dir is not None:
                record["upgrade_backup"] = str(backup_dir)
            manifest.write_text(json.dumps(record, ensure_ascii=False, indent=2))
        if running_apps:
            print("[PROGRESS:98] 正在重新拉起升级前处于运行状态的实例...", flush=True)
            host_app = get_current_host_app()
            for item in running_apps:
                if host_app is None or item["app"] != host_app:
                    try:
                        run("open", "-a", str(item["app"]))
                    except Exception:
                        pass
    print("[PROGRESS:100] 升级完成！全部实例已无损升级至最新版本", flush=True)
    if backup_dir:
        print(f"升级完成。数据目录保持原路径；完整备份：{backup_dir}", flush=True)
        print("请逐一打开实例确认登录与对话后，再清理备份。", flush=True)
    else:
        print("升级完成。数据目录保持原路径（本次升级未创建备份）。", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path("/Applications/Antigravity.app"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--only-indices", help=argparse.SUPPRESS)
    parser.add_argument("--build-only", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--skip-backup", action="store_true", help="跳过升级前备份旧程序和数据的步骤")
    parser.add_argument("--force", action="store_true", help="强制重新适配与构建所有实例（即使版本号一致）")
    args = parser.parse_args()
    try:
        with operation_lock():
            upgrade_all(args.source.resolve(), args.dry_run,
                        {int(value) for value in args.only_indices.split(",")} if args.only_indices else None,
                        args.build_only,
                        args.skip_backup,
                        args.force)
    except Exception as error:
        print(f"批量升级失败：{error}", file=sys.stderr, flush=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
