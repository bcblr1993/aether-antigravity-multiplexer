import json
import pathlib
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "Resources"))
from create_instance import KNOWN
from upgrade_all import source_info


class CompatibilityTests(unittest.TestCase):
    def test_unknown_version_is_rejected_before_signature_or_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory)
            (source / "Contents").mkdir()
            (source / "Contents/Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": "com.google.antigravity",
                "CFBundleShortVersionString": "999.0.0",
            }))
            with patch("upgrade_all.run") as run:
                with self.assertRaisesRegex(RuntimeError, "尚未经过适配验证"):
                    source_info(source)
                run.assert_not_called()

    def test_changed_source_hash_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory)
            resources = source / "Contents/Resources"
            resources.mkdir(parents=True)
            (source / "Contents/Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": "com.google.antigravity",
                "CFBundleShortVersionString": "2.23.0",
            }))
            (resources / "app.asar").write_bytes(b"changed official source")
            with patch("upgrade_all.run") as run:
                run.return_value.stderr = "TeamIdentifier=EQHXZ8M8AV arm64"
                with self.assertRaisesRegex(RuntimeError, "ASAR 哈希不匹配"):
                    source_info(source)

    def test_compatibility_table_entries(self):
        self.assertIn("2.23.1", KNOWN)
        self.assertIn("2.24.0", KNOWN)
        entry = KNOWN["2.24.0"]
        self.assertEqual(len(entry["asar"]), 64)
        self.assertEqual(len(entry["language_server"]), 64)
        self.assertEqual(entry["keyring_bypass_offset"], 26853952)

    def test_patch_asar_enforces_single_window(self):
        import pathlib
        create_instance_py = (pathlib.Path(__file__).resolve().parents[1] / "Resources/create_instance.py").read_text(encoding="utf-8")
        self.assertIn("utils_1.createWindow = function(url, storageManager)", create_instance_py)
        self.assertIn("const existing = electron_1.BrowserWindow.getAllWindows()", create_instance_py)
        self.assertIn("win.hide()", create_instance_py)
        self.assertIn("electron_1.app.hide()", create_instance_py)
        self.assertIn("e.preventDefault()", create_instance_py)
        self.assertIn("if (w.isMinimized()) w.restore()", create_instance_py)
        self.assertIn("w.show()", create_instance_py)
        self.assertIn("w.focus()", create_instance_py)
        self.assertIn("electron_1.app.on('activate'", create_instance_py)

    def test_patch_asar_suppresses_clone_tray_icon(self):
        import pathlib
        create_instance_py = (pathlib.Path(__file__).resolve().parents[1] / "Resources/create_instance.py").read_text(encoding="utf-8")
        self.assertIn("tray_1.createTray = function()", create_instance_py)
        self.assertIn("tray_1.insertTrayMenuItem = function()", create_instance_py)
        self.assertIn("tray_1.updateTrayAgentCount = function()", create_instance_py)
        self.assertIn("electron_1.Tray = class DummyTray", create_instance_py)

    def test_patch_asar_dock_policy_and_auto_hiding(self):
        import pathlib
        create_instance_py = (pathlib.Path(__file__).resolve().parents[1] / "Resources/create_instance.py").read_text(encoding="utf-8")
        self.assertIn("function _readDockPolicy()", create_instance_py)
        self.assertIn("function _syncDockState(forceShow)", create_instance_py)
        self.assertIn("electron_1.app.dock.hide()", create_instance_py)
        self.assertIn("_origDockShow = electron_1.app.dock.show.bind(electron_1.app.dock)", create_instance_py)
        self.assertIn("if (_readDockPolicy() === 'hidden') return", create_instance_py)
        self.assertIn("require('fs').watchFile(_cfgFile", create_instance_py)
        self.assertIn("electron_1.app.on('hide', () => {", create_instance_py)
        self.assertIn("_syncDockState(false)", create_instance_py)
        self.assertIn("_syncDockState(true)", create_instance_py)

    def test_upgrade_all_skip_backup_argument_and_progress(self):
        import io
        import upgrade_all

        with tempfile.TemporaryDirectory() as support, \
             patch("upgrade_all.APP_SUPPORT", pathlib.Path(support)), \
             patch("upgrade_all.source_info", return_value="2.23.1"), \
             patch("upgrade_all.discover", return_value=[{
                 "app": pathlib.Path("/Applications/Antigravity Second.app"),
                 "name": "Antigravity Second",
                 "bundle": "local.antigravity.instance2",
                 "version": "2.23.0",
                 "index": 2,
                 "profile": pathlib.Path.home() / ".gemini-1",
                 "key": b"jetski-standalone-oauth-token",
                 "user_data": pathlib.Path.home() / "Library/Application Support/Antigravity Second"
             }]), \
             patch("upgrade_all.build", return_value="antigravity-second"), \
             patch("upgrade_all.stop_apps"), \
             patch("upgrade_all.backup") as mock_backup, \
             patch("upgrade_all.run"), \
             patch("pathlib.Path.rename"), \
             patch("pathlib.Path.write_text"), \
             patch("upgrade_all.os.replace"), \
             patch("sys.stdout", new_callable=io.StringIO) as mock_stdout:

            upgrade_all.upgrade_all(pathlib.Path("/Applications/Antigravity.app"), skip_backup=True)
            mock_backup.assert_not_called()
            output = mock_stdout.getvalue()
            self.assertIn("[PROGRESS:5]", output)
            self.assertIn("[PROGRESS:100]", output)
            self.assertIn("跳过备份", output)

    def test_upgrade_all_with_backup_calls_backup(self):
        import io
        import upgrade_all

        with tempfile.TemporaryDirectory() as support, \
             patch("upgrade_all.APP_SUPPORT", pathlib.Path(support)), \
             patch("upgrade_all.source_info", return_value="2.23.1"), \
             patch("upgrade_all.discover", return_value=[{
                 "app": pathlib.Path("/Applications/Antigravity Second.app"),
                 "name": "Antigravity Second",
                 "bundle": "local.antigravity.instance2",
                 "version": "2.23.0",
                 "index": 2,
                 "profile": pathlib.Path.home() / ".gemini-1",
                 "key": b"jetski-standalone-oauth-token",
                 "user_data": pathlib.Path.home() / "Library/Application Support/Antigravity Second"
             }]), \
             patch("upgrade_all.build", return_value="antigravity-second"), \
             patch("upgrade_all.stop_apps"), \
             patch("upgrade_all.backup") as mock_backup, \
             patch("upgrade_all.run"), \
             patch("pathlib.Path.rename"), \
             patch("pathlib.Path.write_text"), \
             patch("upgrade_all.os.replace"), \
             patch("sys.stdout", new_callable=io.StringIO) as mock_stdout:

            upgrade_all.upgrade_all(pathlib.Path("/Applications/Antigravity.app"), skip_backup=False)
            mock_backup.assert_called_once()
            output = mock_stdout.getvalue()
            self.assertIn("[PROGRESS:68]", output)
            self.assertIn("安全备份", output)


if __name__ == "__main__":
    unittest.main()
