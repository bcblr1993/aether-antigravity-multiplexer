import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "Resources"))
from clear_workspace import WorkspaceClearer
from create_instance import operation_lock
from test_destroy_instance import DestroyInstanceTests


class ClearWorkspaceTests(unittest.TestCase):
    instance = DestroyInstanceTests.instance

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = pathlib.Path(self.temporary.name) / "home"
        self.apps = pathlib.Path(self.temporary.name) / "Applications"
        self.support = self.home / "Library/Application Support/Antigravity Multiplexer"
        self.apps.mkdir()
        self.home.mkdir()
        self.clearer = WorkspaceClearer(self.home, self.support, [self.apps], lambda: [])

    def test_only_selected_profile_contents_are_removed(self):
        app, profile, window, logs, credential = self.instance(
            2, "Second", "local.antigravity.second", "second-standalone-oauth-token", True)
        other = self.instance(3, "Third", "local.antigravity.third", "thirdx-standalone-oauth-token")
        (profile / ".hidden").write_text("private")
        (profile / "nested").mkdir()
        (profile / "nested/file").write_text("private")
        outside = self.home / "outside"
        outside.write_text("keep")
        (profile / "link").symlink_to(outside)
        backup = self.support / "Backups/example.zip"
        backup.parent.mkdir(parents=True)
        backup.write_text("backup")
        manifest = self.support / "instance-2.json"
        record = json.loads(manifest.read_text())
        record["login_verified"] = True
        manifest.write_text(json.dumps(record))
        self.clearer.clear(2, app)
        self.assertTrue(profile.is_dir())
        self.assertEqual(list(profile.iterdir()), [])
        self.assertFalse(json.loads(manifest.read_text())["login_verified"])
        for path in (app, window, logs, credential, self.support / "instance-2.json", backup, outside, *other):
            self.assertTrue(path.exists(), str(path))

    def test_reject_running_main_symlink_and_lock(self):
        app, profile, *_ = self.instance(
            2, "Second", "local.antigravity.second", "second-standalone-oauth-token", True)
        self.clearer.process_list = lambda: [str(app / "Contents/MacOS/Antigravity")]
        with self.assertRaisesRegex(RuntimeError, "仍在运行"):
            self.clearer.clear(2, app)
        self.clearer.process_list = lambda: []
        with self.assertRaisesRegex(RuntimeError, "主实例"):
            self.clearer.clear(1, app)
        profile.rename(profile.with_name("actual"))
        profile.symlink_to(profile.with_name("actual"), target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, "符号链接"):
            self.clearer.clear(2, app)
        profile.unlink()
        profile.with_name("actual").rename(profile)
        with operation_lock(self.support):
            with self.assertRaisesRegex(RuntimeError, "已有实例创建或升级"):
                self.clearer.clear(2, app)
        self.assertTrue((profile / "private.txt").exists())


if __name__ == "__main__":
    unittest.main()
