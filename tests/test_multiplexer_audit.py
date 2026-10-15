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
        # refreshRunningStates must not query CGPreflightScreenCaptureAccess on periodic ticks
        refresh_idx = self.content.find("func refreshRunningStates()")
        self.assertNotEqual(refresh_idx, -1)
        refresh_body = self.content[refresh_idx:refresh_idx + 400]
        self.assertNotIn("CGPreflightScreenCaptureAccess", refresh_body)
        self.assertIn("func checkScreenCapturePermission()", self.content)

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

    def test_draggable_hud_and_position_persistence(self):
        # Floating HUD must be draggable, use hardware-accelerated WindowServer performDrag, and persist user coordinates
        self.assertIn('class DraggableHostingView', self.content)
        self.assertIn('class NativeDragAreaView', self.content)
        self.assertIn('window.performDrag(with: event)', self.content)
        self.assertIn('func saveHUDPosition(origin: NSPoint)', self.content)
        self.assertIn('func moveHUD(by translation: CGSize, startOrigin: NSPoint)', self.content)
        self.assertIn('UserDefaults.standard.object(forKey: "floatingHUD_x")', self.content)
        self.assertIn('UserDefaults.standard.object(forKey: "floatingHUD_y")', self.content)

    def test_cdp_ephemeral_session_and_adaptive_backoff(self):
        # CDP calls must use dedicated ephemeral URLSession without shared cache leaks, and backoff for idle instances
        self.assertIn('static let cdpSession: URLSession', self.content)
        self.assertIn('URLSessionConfiguration.ephemeral', self.content)
        self.assertIn('cdpSession.data(for: req)', self.content)
        self.assertIn('cdpSession.webSocketTask(with: wsURL)', self.content)
        self.assertIn('telemetryTick % 5 == 0', self.content)

    def test_resource_metric_equatable_deadband(self):
        # InstanceResourceMetric must implement deadband Equatable to eliminate float/byte redraw storms
        self.assertIn('static func == (lhs: InstanceResourceMetric, rhs: InstanceResourceMetric) -> Bool', self.content)
        self.assertIn('lhs.memoryLabel == rhs.memoryLabel', self.content)
        self.assertIn('lhs.cpuLabel == rhs.cpuLabel', self.content)

    def test_sentinel_standby_periodic_tick(self):
        # periodicTick must implement Sentinel standby mode to throttle idle tray execution
        self.assertIn('func periodicTick()', self.content)
        self.assertIn('let isStandby = !shouldCaptureScreenshots && activeTaskCount == 0', self.content)
        self.assertIn('guard standbyTickCount % 5 == 0 else { return }', self.content)

    def test_isolated_resource_badges_equatable(self):
        # Badges must be isolated into independent Equatable subviews
        self.assertIn('struct InstanceThumbnailResourceBadge: View, Equatable', self.content)
        self.assertIn('struct InstanceCardResourceBadges: View, Equatable', self.content)
        self.assertIn('InstanceThumbnailResourceBadge(isRunning: item.running, metric: resourceMetric)', self.content)
        self.assertIn('InstanceCardResourceBadges(', self.content)

    def test_native_kernel_process_monitor_libproc(self):
        # NativeProcessMonitor must use Darwin kernel APIs (proc_pidinfo, proc_listchildpids) for zero subprocess churn
        self.assertIn('enum NativeProcessMonitor', self.content)
        self.assertIn('proc_listchildpids', self.content)
        self.assertIn('proc_pidinfo', self.content)
        self.assertIn('PROC_PIDTASKINFO', self.content)
        self.assertIn('getProcessTreePids(root: pid_t)', self.content)
        self.assertIn('sampleTree(root: pid_t)', self.content)
        self.assertIn('fallbackScanResourceMetricsViaPS', self.content)

    def test_floating_hud_interactive_quick_switch(self):
        # Floating HUD must include interactive quick switcher trigger button and liquid glass styling
        self.assertIn('store.toggleQuickSwitcher()', self.content)
        self.assertIn('arrow.left.arrow.right', self.content)
        self.assertIn('width: 356', self.content)

    def test_kernel_direct_dashboard_badge(self):
        # Top dashboard header must display Kernel Direct badge
        self.assertIn('Kernel Direct', self.content)

    def test_telemetry_actor_concurrency(self):
        # TelemetryActor must encapsulate telemetry batch scanning in Swift concurrency actor
        self.assertIn('actor TelemetryActor', self.content)
        self.assertIn('func scanTelemetryBatch(', self.content)
        self.assertIn('TelemetryActor.shared.scanTelemetryBatch(', self.content)

    def test_agent_stall_sentinel(self):
        # Must detect stalled tasks (>180s silence) and alert across UI and system notifications
        self.assertIn('case .stalled', self.content)
        self.assertIn('疑似挂起', self.content)
        self.assertIn('isStalled: Bool', self.content)
        self.assertIn('stalledTaskCount', self.content)
        self.assertIn('task-stalled-', self.content)
        self.assertIn('age >= 180', self.content)

    def test_dock_badge_diff_guard(self):
        # Must guard dock badge display() behind label inequality check
        self.assertIn('lastDockBadgeLabel', self.content)
        self.assertIn('if targetBadge != lastDockBadgeLabel', self.content)

    def test_status_bar_menu_signature_cache(self):
        # Must compute signature hash and skip redundant menu rebuilding
        self.assertIn('lastStatusBarMenuSignature', self.content)
        self.assertIn('if currentSignature == lastStatusBarMenuSignature && statusItem.menu != nil', self.content)

    def test_isolated_floating_hud_state(self):
        # Floating HUD must observe isolated FloatingHUDState rather than entire store
        self.assertIn('class FloatingHUDState: ObservableObject', self.content)
        self.assertIn('@ObservedObject var hudState: FloatingHUDState', self.content)
        self.assertIn('syncHUDState()', self.content)

    def test_cdp_connection_close_header(self):
        # Ephemeral CDP query should pass Connection: close header
        self.assertIn('req.setValue("close", forHTTPHeaderField: "Connection")', self.content)

    def test_single_window_enforcement_and_duplicate_pruning(self):
        # Must activate running apps without openApplication to prevent duplicate windows, and prune duplicates via CDP
        self.assertIn('pageTargets.count > 1', self.content)
        self.assertIn('http://127.0.0.1:\\(port)/json/close/\\(targetId)', self.content)
        self.assertIn('app.activate(options: [.activateIgnoringOtherApps])', self.content)


if __name__ == "__main__":
    unittest.main()

