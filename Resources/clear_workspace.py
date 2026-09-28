#!/usr/bin/env python3
"""Clear one stopped clone's isolated ~/.gemini-N directory only."""
import argparse
import json
import os
import pathlib
import shutil
import sys
import tempfile

from create_instance import operation_lock, require
from destroy_instance import InstanceDestroyer


class WorkspaceClearer(InstanceDestroyer):
    def clear(self, index, app):
        with operation_lock(self.support):
            name, _ = self._inspect(index, pathlib.Path(app))
            profile = self.home / f".gemini-{index - 1}"
            require(profile.is_dir() and not profile.is_symlink(), "独立工作空间目录异常")
            stage = pathlib.Path(tempfile.mkdtemp(prefix=f"clear-workspace-{index}-", dir=self.support))
            held = stage / "profile"
            mode = profile.stat().st_mode & 0o777
            try:
                require(profile.stat().st_dev == stage.stat().st_dev,
                        "工作空间与暂存目录不在同一磁盘，停止清空")
                # Recheck just before the atomic move, including background helper processes.
                require(not any(line.strip().startswith(str(app) + "/Contents/") for line in self.process_list()),
                        "实例仍在运行；请先保存工作并退出该实例")
                os.replace(profile, held)
                profile.mkdir(mode=mode)
            except Exception as error:
                if held.exists():
                    try:
                        if profile.exists():
                            profile.rmdir()
                        os.replace(held, profile)
                    except Exception as rollback_error:
                        raise RuntimeError(f"清空中断且回滚失败；原数据暂存于 {held}：{rollback_error}") from error
                stage.rmdir()
                raise
            try:
                shutil.rmtree(stage)
            except Exception as error:
                raise RuntimeError(f"清理未完成；原数据暂存于 {held}：{error}") from error
            manifest = self.support / f"instance-{index}.json"
            if manifest.exists():
                record = json.loads(manifest.read_text())
                record["login_verified"] = False
                temporary = stage.with_name(stage.name + "-manifest.json")
                try:
                    temporary.write_text(json.dumps(record, ensure_ascii=False, indent=2))
                    os.replace(temporary, manifest)
                finally:
                    temporary.unlink(missing_ok=True)
            return name, profile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", type=int, required=True)
    parser.add_argument("--app", type=pathlib.Path, required=True)
    args = parser.parse_args()
    try:
        name, profile = WorkspaceClearer().clear(args.index, args.app)
        print(f"已清空 {name} 的工作空间：{profile}。实例应用、其他目录和升级备份未改动。")
    except Exception as error:
        print(f"清空失败：{error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
