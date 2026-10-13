import os
import unittest


class TestMultiplexerAudit(unittest.TestCase):
    def setUp(self):
        source_path = os.path.join(os.path.dirname(__file__), "..", "Sources", "AntigravityMultiplexer.swift")
        self.assertTrue(os.path.exists(source_path), f"Source file not found at {source_path}")
        with open(source_path, "r", encoding="utf-8") as f:
            self.content = f.read()

    def test_solo_focus_mode_defaults_to_false(self):
        # soloFocusMode must default to false so instances do not disappear when clicking another
        self.assertIn('UserDefaults.standard.object(forKey: "soloFocusMode") as? Bool ?? false', self.content)

    def test_telemetry_scan_guarded_against_storm(self):
        # refreshTelemetryAndThumbnails must be guarded by isScanningTelemetry flag
        self.assertIn("guard !isScanningTelemetry else { return }", self.content)
        self.assertIn("self.isScanningTelemetry = false", self.content)

    def test_global_hotkey_checks_signature(self):
        # GlobalHotKeyManager must check hotKeyID.signature == OSType(0x4147594D) to prevent eating other apps hotkeys
        self.assertIn("hotKeyID.signature == OSType(0x4147594D)", self.content)
        self.assertIn("return OSStatus(eventNotHandledErr)", self.content)

    def test_quick_switcher_index_clamped(self):
        # Quick Switcher enter key must clamp selectedIndex within 0 ..< filteredInstances.count
        self.assertIn("min(max(0, selectedIndex), filteredInstances.count - 1)", self.content)

    def test_run_script_pipe_write_end_closed(self):
        # runScript must close pipe write handle to prevent EOF hang
        self.assertIn("try? pipe.fileHandleForWriting.close()", self.content)

    def test_edit_instance_meta_uses_command_return(self):
        # Saving notes must use Cmd+Return so pressing Enter for newlines does not accidentally submit
        self.assertIn(".keyboardShortcut(.return, modifiers: .command)", self.content)
        self.assertIn(".keyboardShortcut(.cancelAction)", self.content)

    def test_dock_reopen_and_sheet_safety(self):
        # AppDelegate must implement applicationShouldHandleReopen with sheet safety
        self.assertIn("applicationShouldHandleReopen", self.content)
        self.assertIn("if let sheet = window.attachedSheet", self.content)
        self.assertIn("sheet.makeKeyAndOrderFront(nil)", self.content)

    def test_no_task_storm_in_hide_instance(self):
        # hideInstance should not spawn redundant captureCDPScreenshots tasks
        hide_func_idx = self.content.find("func hideInstance(_ item: ManagedInstance)")
        self.assertNotEqual(hide_func_idx, -1)
        hide_func_body = self.content[hide_func_idx:hide_func_idx + 400]
        self.assertNotIn("captureCDPScreenshots", hide_func_body)


if __name__ == "__main__":
    unittest.main()
