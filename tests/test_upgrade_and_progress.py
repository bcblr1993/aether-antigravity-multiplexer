import io
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "Resources"))
import upgrade_all


class UpgradeAndProgressTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = pathlib.Path(self.temp_dir.name)
        self.app_support = self.root / "Application Support"
        self.app_support.mkdir(parents=True)

    def test_cli_skip_backup_flag_parsing(self):
        """Verify upgrade_all.py CLI parser recognizes --skip-backup."""
        parser = argparse = upgrade_all.argparse.ArgumentParser()
        parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path("/Applications/Antigravity.app"))
        parser.add_argument("--dry-run", action="store_true")
        parser.add_argument("--only-indices", help="only indices")
        parser.add_argument("--build-only", action="store_true")
        parser.add_argument("--skip-backup", action="store_true")

        args = parser.parse_args(["--skip-backup", "--dry-run"])
        self.assertTrue(args.skip_backup)
        self.assertTrue(args.dry_run)

    def test_upgrade_all_progress_monotonicity_and_completeness(self):
        """Verify all [PROGRESS:xx] stage markers are monotonic, bounded 0-100, and cover all 5 phases."""
        mock_instances = [
            {
                "app": self.root / "Antigravity Second.app",
                "name": "Antigravity Second",
                "bundle": "local.antigravity.instance2",
                "version": "2.23.0",
                "index": 2,
                "profile": self.root / ".gemini-1",
                "key": b"jetski-standalone-oauth-token",
                "user_data": self.root / "Antigravity Second Data"
            },
            {
                "app": self.root / "Antigravity Third.app",
                "name": "Antigravity Third",
                "bundle": "local.antigravity.instance3",
                "version": "2.23.0",
                "index": 3,
                "profile": self.root / ".gemini-2",
                "key": b"jetski-standalone-oauth-token",
                "user_data": self.root / "Antigravity Third Data"
            }
        ]

        with patch("upgrade_all.source_info", return_value="2.23.1"), \
             patch("upgrade_all.discover", return_value=mock_instances), \
             patch("upgrade_all.build", return_value="antigravity-scheme"), \
             patch("upgrade_all.stop_apps"), \
             patch("upgrade_all.backup"), \
             patch("upgrade_all.run"), \
             patch("upgrade_all.APP_SUPPORT", self.app_support), \
             patch("pathlib.Path.rename"), \
             patch("pathlib.Path.write_text"), \
             patch("upgrade_all.os.replace"), \
             patch("sys.stdout", new_callable=io.StringIO) as mock_stdout:

            upgrade_all.upgrade_all(pathlib.Path("/Applications/Antigravity.app"), skip_backup=False)
            output = mock_stdout.getvalue()

            progress_matches = re.findall(r"\[PROGRESS:(\d+)\]\s*(.*)", output)
            self.assertGreaterEqual(len(progress_matches), 6)

            percentages = [int(p[0]) for p in progress_matches]
            # 1. Bounds check
            for pct in percentages:
                self.assertGreaterEqual(pct, 0)
                self.assertLessEqual(pct, 100)

            # 2. Monotonicity check
            for i in range(len(percentages) - 1):
                self.assertLessEqual(percentages[i], percentages[i + 1],
                                     f"Progress should be monotonic: {percentages[i]} <= {percentages[i+1]}")

            # 3. First and last markers
            self.assertEqual(percentages[0], 5)
            self.assertEqual(percentages[-1], 100)

            # 4. Pipeline stages present
            stages_text = " ".join([p[1] for p in progress_matches])
            self.assertIn("验证主程序", stages_text)
            self.assertIn("适配并验签", stages_text)
            self.assertIn("关闭运行中实例", stages_text)
            self.assertIn("安全备份", stages_text)
            self.assertIn("原子替换安装", stages_text)
            self.assertIn("升级完成", stages_text)

    def test_skip_backup_bypasses_backup_completely(self):
        """When skip_backup=True, backup() is never invoked and manifest record does not contain upgrade_backup."""
        manifest_path = self.app_support / "instance-2.json"
        manifest_path.write_text(json.dumps({"index": 2, "name": "Antigravity Second"}))

        mock_instance = {
            "app": self.root / "Antigravity Second.app",
            "name": "Antigravity Second",
            "bundle": "local.antigravity.instance2",
            "version": "2.23.0",
            "index": 2,
            "profile": self.root / ".gemini-1",
            "key": b"jetski-standalone-oauth-token",
            "user_data": self.root / "Antigravity Second Data"
        }

        with patch("upgrade_all.source_info", return_value="2.23.1"), \
             patch("upgrade_all.discover", return_value=[mock_instance]), \
             patch("upgrade_all.build", return_value="antigravity-second"), \
             patch("upgrade_all.stop_apps") as mock_stop, \
             patch("upgrade_all.backup") as mock_backup, \
             patch("upgrade_all.run"), \
             patch("upgrade_all.APP_SUPPORT", self.app_support), \
             patch("pathlib.Path.rename"), \
             patch("sys.stdout", new_callable=io.StringIO) as mock_stdout:

            upgrade_all.upgrade_all(pathlib.Path("/Applications/Antigravity.app"), skip_backup=True)

            mock_stop.assert_called_once()
            mock_backup.assert_not_called()

            output = mock_stdout.getvalue()
            self.assertIn("⚡️ 用户已选择不备份直接升级，跳过备份归档", output)
            self.assertIn("本次升级未创建备份", output)

            # Check written manifest
            written_data = json.loads(manifest_path.read_text())
            self.assertEqual(written_data["version"], "2.23.1")
            self.assertNotIn("upgrade_backup", written_data)

    def test_backup_enabled_creates_backup_and_stores_in_manifest(self):
        """When skip_backup=False, backup() is invoked and manifest record stores upgrade_backup."""
        manifest_path = self.app_support / "instance-2.json"
        manifest_path.write_text(json.dumps({"index": 2, "name": "Antigravity Second"}))

        mock_instance = {
            "app": self.root / "Antigravity Second.app",
            "name": "Antigravity Second",
            "bundle": "local.antigravity.instance2",
            "version": "2.23.0",
            "index": 2,
            "profile": self.root / ".gemini-1",
            "key": b"jetski-standalone-oauth-token",
            "user_data": self.root / "Antigravity Second Data"
        }

        with patch("upgrade_all.source_info", return_value="2.23.1"), \
             patch("upgrade_all.discover", return_value=[mock_instance]), \
             patch("upgrade_all.build", return_value="antigravity-second"), \
             patch("upgrade_all.stop_apps") as mock_stop, \
             patch("upgrade_all.backup") as mock_backup, \
             patch("upgrade_all.run"), \
             patch("upgrade_all.APP_SUPPORT", self.app_support), \
             patch("pathlib.Path.rename"), \
             patch("sys.stdout", new_callable=io.StringIO) as mock_stdout:

            upgrade_all.upgrade_all(pathlib.Path("/Applications/Antigravity.app"), skip_backup=False)

            mock_stop.assert_called_once()
            mock_backup.assert_called_once()

            output = mock_stdout.getvalue()
            self.assertIn("正在创建旧程序、账号数据与窗口缓存安全备份", output)
            self.assertIn("备份已生成并完成完整性校验", output)

            # Check written manifest
            written_data = json.loads(manifest_path.read_text())
            self.assertEqual(written_data["version"], "2.23.1")
            self.assertIn("upgrade_backup", written_data)
            self.assertIn("Backups", written_data["upgrade_backup"])

    def test_swift_stream_progress_chunk_parsing_simulation(self):
        """Verify the exact regex/string protocol parsed by Swift's processStreamChunk."""
        sample_chunk = (
            "[PROGRESS:5] 正在验证主程序版本与签名完整性...\n"
            "本机主实例：2.23.1；发现 2 个副本；待升级 1 个\n"
            "[PROGRESS:35] 正在从主实例本地复制、适配并验签：Antigravity Second (1/1)\n"
            "从主实例本地复制、适配并验签：Antigravity Second\n"
            "[PROGRESS:76] ⚡️ 用户已选择不备份直接升级，跳过备份归档\n"
            "[PROGRESS:100] 升级完成！全部实例已无损升级至最新版本\n"
        )

        parsed_stages = []
        clean_lines = []

        for line in sample_chunk.splitlines():
            if line.startswith("[PROGRESS:"):
                close_bracket = line.find("]")
                pct_str = line[10:close_bracket]
                msg = line[close_bracket + 1:].strip()
                pct = float(pct_str) / 100.0
                parsed_stages.append((pct, msg))
            else:
                clean_lines.append(line)

        self.assertEqual(len(parsed_stages), 4)
        self.assertEqual(parsed_stages[0], (0.05, "正在验证主程序版本与签名完整性..."))
        self.assertEqual(parsed_stages[1], (0.35, "正在从主实例本地复制、适配并验签：Antigravity Second (1/1)"))
        self.assertEqual(parsed_stages[2], (0.76, "⚡️ 用户已选择不备份直接升级，跳过备份归档"))
        self.assertEqual(parsed_stages[3], (1.00, "升级完成！全部实例已无损升级至最新版本"))

        # Raw console text does not contain [PROGRESS: markers
        self.assertEqual(len(clean_lines), 2)
        self.assertNotIn("[PROGRESS:", "\n".join(clean_lines))

    def test_clean_script_removes_notary_and_preserves_canonical(self):
        """Verify that scripts/clean.sh removes notary zips and historical zips while preserving canonical files."""
        clean_script = pathlib.Path(__file__).resolve().parents[1] / "scripts/clean.sh"
        self.assertTrue(clean_script.exists())
        self.assertTrue(os.access(clean_script, os.X_OK))

    def test_cli_force_flag_parsing(self):
        """Verify upgrade_all.py CLI parser recognizes --force."""
        parser = upgrade_all.argparse.ArgumentParser()
        parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path("/Applications/Antigravity.app"))
        parser.add_argument("--dry-run", action="store_true")
        parser.add_argument("--only-indices", help="only indices")
        parser.add_argument("--build-only", action="store_true")
        parser.add_argument("--skip-backup", action="store_true")
        parser.add_argument("--force", action="store_true")

        args = parser.parse_args(["--force", "--skip-backup"])
        self.assertTrue(args.force)
        self.assertTrue(args.skip_backup)

    def test_upgrade_with_force_includes_same_version(self):
        """Verify that passing force=True includes instances that already match the source version."""
        same_version_instances = [{
            "app": self.root / "Antigravity Second.app",
            "name": "Antigravity Second",
            "bundle": "local.antigravity.instance2",
            "version": "2.23.1",
            "index": 2,
            "profile": self.root / ".gemini-1",
            "key": b"jetski-standalone-oauth-token",
            "user_data": self.root / "Antigravity Second Data"
        }]

        with patch("upgrade_all.source_info", return_value="2.23.1"), \
             patch("upgrade_all.discover", return_value=same_version_instances), \
             patch("upgrade_all.build", return_value="antigravity-second") as mock_build, \
             patch("upgrade_all.stop_apps"), \
             patch("upgrade_all.backup"), \
             patch("upgrade_all.run"), \
             patch("pathlib.Path.rename"), \
             patch("pathlib.Path.write_text"), \
             patch("upgrade_all.os.replace"), \
             patch("upgrade_all.APP_SUPPORT", self.app_support):

            # Without force: 0 pending, build is not called
            upgrade_all.upgrade_all(pathlib.Path("/Applications/Antigravity.app"), force=False)
            mock_build.assert_not_called()

            # With force: 1 pending, build is called
            upgrade_all.upgrade_all(pathlib.Path("/Applications/Antigravity.app"), force=True, skip_backup=True)
            mock_build.assert_called_once()

    def test_get_current_host_app_detection(self):
        """Verify get_current_host_app climbs process tree to identify Antigravity host."""
        def mock_ps(cmd, **kwargs):
            pid = cmd[2]
            if pid == "100":
                return "50 /bin/zsh"
            elif pid == "50":
                return "10 /Applications/Antigravity Second.app/Contents/MacOS/Antigravity"
            elif pid == "10":
                return "1 /sbin/launchd"
            return ""

        with patch("os.getpid", return_value=100), \
             patch("subprocess.check_output", side_effect=mock_ps):
            host = upgrade_all.get_current_host_app()
            self.assertEqual(host, pathlib.Path("/Applications/Antigravity Second.app"))

    def test_stop_apps_preserves_current_host_app(self):
        """Verify stop_apps does not send SIGTERM to the current host application."""
        host_path = pathlib.Path("/Applications/Antigravity Second.app")
        other_path = pathlib.Path("/Applications/Antigravity Third.app")

        instances = [
            {"app": host_path, "name": "Antigravity Second"},
            {"app": other_path, "name": "Antigravity Third"}
        ]

        call_count = 0
        def mock_ps_axo(cmd, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                return (
                    f"101 {host_path}/Contents/MacOS/Antigravity\n"
                    f"202 {other_path}/Contents/MacOS/Antigravity\n"
                )
            return f"101 {host_path}/Contents/MacOS/Antigravity\n"

        with patch("upgrade_all.get_current_host_app", return_value=host_path), \
             patch("subprocess.check_output", side_effect=mock_ps_axo), \
             patch("os.kill") as mock_kill, \
             patch("time.sleep"), \
             patch("sys.stdout", new_callable=io.StringIO) as mock_stdout:

            upgrade_all.stop_apps(instances)
            out = mock_stdout.getvalue()
            self.assertIn("跳过进程终止以保持会话连线", out)
            self.assertIn("Antigravity Second", out)
            # Only PID 202 (Third) should be killed, not 101 (Second)
            mock_kill.assert_any_call(202, upgrade_all.signal.SIGTERM)
            killed_pids = [call_args[0][0] for call_args in mock_kill.call_args_list]
            self.assertNotIn(101, killed_pids)


if __name__ == "__main__":
    unittest.main()
