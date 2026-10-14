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

    def test_applescript_system_events_unhide_and_hide(self):
        # hideInstance and open must use AppleScript System Events to reliably manipulate Electron window visibility
        self.assertIn("tell application", self.content)
        self.assertIn("System Events", self.content)
        self.assertIn("visible of (first process whose bundle identifier is", self.content)
        self.assertIn("to false", self.content)
        self.assertIn("to true", self.content)

    def test_open_application_clean_activation(self):
        # open must specify config.createsNewApplicationInstance = false to prevent duplicate windows
        self.assertIn("config.createsNewApplicationInstance = false", self.content)
        self.assertIn("config.activates = true", self.content)

    def test_task_history_limits_and_persistence(self):
        # Task history must cap at 200 items and persist to task_history.json
        self.assertIn('task_history.json', self.content)
        self.assertIn('taskHistory.count > 200', self.content)
        self.assertIn('Array(taskHistory.prefix(200))', self.content)

    def test_task_history_sheet_shortcuts(self):
        # TaskHistorySheet must have standard macOS shortcuts
        self.assertIn('TaskHistorySheet', self.content)
        self.assertIn('.keyboardShortcut(.cancelAction)', self.content)
        self.assertIn('.keyboardShortcut(.defaultAction)', self.content)

    def test_pulsing_dot_drawing_group_and_conditional_pulse(self):
        # PulsingStatusDot must use drawingGroup() and conditional pulse to eliminate layout/shadow recalculations
        self.assertIn('struct PulsingStatusDot: View', self.content)
        self.assertIn('.drawingGroup()', self.content)
        self.assertIn('var pulse: Bool = false', self.content)
        self.assertIn('if active && pulse', self.content)

    def test_tcc_permission_cached_guard(self):
        # refreshRunningStates must not unconditionally query CGPreflightScreenCaptureAccess on every tick
        self.assertIn('if !hasScreenCapturePermission', self.content)
        refresh_idx = self.content.find("func refreshRunningStates()")
        self.assertNotEqual(refresh_idx, -1)
        refresh_body = self.content[refresh_idx:refresh_idx + 250]
        self.assertIn('if !hasScreenCapturePermission', refresh_body)

    def test_background_capture_throttled_when_hidden(self):
        # Screenshots and window captures must be throttled when main window is hidden/minimized
        self.assertIn('var isMainWindowVisible: Bool', self.content)
        self.assertIn('var shouldCaptureScreenshots: Bool', self.content)
        self.assertIn('guard shouldCaptureScreenshots else { return }', self.content)

    def test_resource_metrics_equatable_guard(self):
        # Published resourceMetrics must only mutate when changed
        self.assertIn('if self.resourceMetrics != metrics', self.content)

    def test_equatable_view_performance_conformance(self):
        # Major card and row views must conform to Equatable and use .equatable() to prevent body recalculation storms
        self.assertIn('extension InstanceThumbnailTile: Equatable', self.content)
        self.assertIn('extension InstanceCard: Equatable', self.content)
        self.assertIn('extension QuickSwitcherRow: Equatable', self.content)

    def test_active_instance_name_assignment_guarded(self):
        # updateActiveFrontmostInstance must guard activeInstanceName mutation
        self.assertIn('if activeInstanceName != newActiveName', self.content)

    def test_per_instance_screenshot_throttling(self):
        # Background idle instances must not be captured every tick
        self.assertIn('shouldFetchImage', self.content)
        self.assertIn('hasThumb && !isFront && !isRunningTask', self.content)


if __name__ == "__main__":
    unittest.main()
