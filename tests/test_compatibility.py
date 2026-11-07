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
        self.assertIn("2.25.0", KNOWN)
        self.assertIn("2.26.0", KNOWN)
        self.assertIn("2.28.0", KNOWN)
        self.assertIn("2.28.1", KNOWN)
        self.assertIn("2.28.2", KNOWN)
        self.assertIn("2.29.0", KNOWN)
        entry = KNOWN["2.29.0"]
        self.assertEqual(len(entry["asar"]), 64)
        self.assertEqual(len(entry["language_server"]), 64)
        self.assertEqual(entry["keyring_bypass_offset"], 29185952)

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

    def test_patch_macho_uuid_replaces_lc_uuid_deterministically(self):
        import struct
        import uuid
        from create_instance import patch_macho_uuid

        with tempfile.TemporaryDirectory() as directory:
            binary = pathlib.Path(directory) / "Antigravity"
            orig_uuid = uuid.UUID("4c4c448f-5555-3144-a1ab-f1a26eb65237").bytes
            header = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 1, 24, 0, 0)
            lc_uuid = struct.pack("<2I", 0x1B, 24) + orig_uuid
            binary.write_bytes(header + lc_uuid + b"payload")

            patch_macho_uuid(binary, "local.antigravity.fifth")
            patched = binary.read_bytes()
            expected_uuid = uuid.uuid5(uuid.NAMESPACE_DNS, "local.antigravity.fifth").bytes
            self.assertEqual(patched[40:56], expected_uuid)
            self.assertNotEqual(patched[40:56], orig_uuid)

    def test_sign_bundle_patches_uuid_and_adds_local_network_usage_description(self):
        import struct
        import uuid
        from create_instance import sign_bundle

        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            app = root / "Antigravity Fifth.app"
            work = root / "work"
            work.mkdir()
            (app / "Contents/MacOS").mkdir(parents=True)
            (app / "Contents/Resources/bin").mkdir(parents=True)
            helper = app / "Contents/Frameworks/Antigravity Helper.app"
            (helper / "Contents/MacOS").mkdir(parents=True)

            (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": "local.antigravity.fifth",
                "CFBundleExecutable": "Antigravity",
            }))
            (helper / "Contents/Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": "com.google.antigravity.helper",
                "CFBundleExecutable": "Antigravity Helper",
            }))

            orig_uuid = uuid.UUID("4c4c448f-5555-3144-a1ab-f1a26eb65237").bytes
            macho_bytes = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 1, 24, 0, 0) + struct.pack("<2I", 0x1B, 24) + orig_uuid
            (app / "Contents/MacOS/Antigravity").write_bytes(macho_bytes)
            (helper / "Contents/MacOS/Antigravity Helper").write_bytes(macho_bytes)
            (app / "Contents/Resources/bin/language_server").write_bytes(macho_bytes)

            with patch("create_instance.run"):
                sign_bundle(app, "Antigravity Fifth", "local.antigravity.fifth", work)

            main_info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
            self.assertIn("NSLocalNetworkUsageDescription", main_info)
            main_uuid = (app / "Contents/MacOS/Antigravity").read_bytes()[40:56]
            helper_uuid = (helper / "Contents/MacOS/Antigravity Helper").read_bytes()[40:56]
            ls_uuid = (app / "Contents/Resources/bin/language_server").read_bytes()[40:56]
            self.assertEqual(main_uuid, uuid.uuid5(uuid.NAMESPACE_DNS, "local.antigravity.fifth").bytes)
            self.assertEqual(helper_uuid, uuid.uuid5(uuid.NAMESPACE_DNS, "local.antigravity.fifth.helper").bytes)
            self.assertEqual(ls_uuid, uuid.uuid5(uuid.NAMESPACE_DNS, "local.antigravity.fifth.language_server").bytes)

    def test_patch_asar_unconditional_watchfile_for_dock_policy(self):
        create_instance_py = (pathlib.Path(__file__).resolve().parents[1] / "Resources/create_instance.py").read_text(encoding="utf-8")
        self.assertNotIn("if (require('fs').existsSync(_cfgFile))", create_instance_py)
        self.assertIn("require('fs').watchFile(_cfgFile, {{ interval: 1000 }}, () => _syncDockState(false));", create_instance_py)

    def test_upgrade_all_supports_eighth_and_higher_ordinal_names(self):
        import upgrade_all
        self.assertEqual(upgrade_all.WORDS.get("Eighth"), 8)
        self.assertEqual(upgrade_all.WORDS.get("Ninth"), 9)
        self.assertEqual(upgrade_all.WORDS.get("Tenth"), 10)
        self.assertEqual(upgrade_all.WORDS.get("Eleventh"), 11)
        self.assertEqual(upgrade_all.WORDS.get("Twelfth"), 12)


if __name__ == "__main__":
    unittest.main()
