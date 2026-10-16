import os
import unittest


class TestUIPolishAndPerformance(unittest.TestCase):
    def setUp(self):
        source_path = os.path.join(os.path.dirname(__file__), "..", "Sources", "AntigravityMultiplexer.swift")
        self.assertTrue(os.path.exists(source_path), f"Source file not found at {source_path}")
        with open(source_path, "r", encoding="utf-8") as f:
            self.content = f.read()

    def test_view_density_enum_definition(self):
        # ViewDensity enum must support comfortable, compact, and matrix with min/max widths and heights
        self.assertIn("enum ViewDensity: String, CaseIterable, Identifiable, Hashable, Equatable", self.content)
        self.assertIn("case comfortable = \"comfortable\"", self.content)
        self.assertIn("case compact = \"compact\"", self.content)
        self.assertIn("case matrix = \"matrix\"", self.content)
        self.assertIn("var minWidth: CGFloat", self.content)
        self.assertIn("var maxWidth: CGFloat", self.content)
        self.assertIn("var screenHeight: CGFloat", self.content)
        self.assertIn("var gridSpacing: CGFloat", self.content)
        self.assertIn("func localized(lang: AppLanguage) -> String", self.content)

    def test_view_density_persistence_in_instance_store(self):
        # InstanceStore must publish viewDensity and persist to UserDefaults
        self.assertIn("@Published var viewDensity: ViewDensity", self.content)
        self.assertIn('UserDefaults.standard.string(forKey: "viewDensity")', self.content)
        self.assertIn('UserDefaults.standard.set(viewDensity.rawValue, forKey: "viewDensity")', self.content)

    def test_ambient_glow_border_metal_gpu_and_sentinel(self):
        # AmbientGlowBorder must use Metal GPU flattening and throttle when inactive (Sentinel 0Hz)
        self.assertIn("struct AmbientGlowBorder: View", self.content)
        self.assertIn("let isActive: Bool", self.content)
        self.assertIn(".drawingGroup(opaque: false)", self.content)
        self.assertIn(".allowsHitTesting(false)", self.content)
        self.assertIn("withAnimation(.linear(duration: 0.15))", self.content)

    def test_glass_shimmer_overlay_metal_gpu(self):
        # GlassShimmerOverlay must use Metal GPU flattening and provide single-pass sheen
        self.assertIn("struct GlassShimmerOverlay: View", self.content)
        self.assertIn("let isHovered: Bool", self.content)
        self.assertIn(".drawingGroup(opaque: false)", self.content)
        self.assertIn(".allowsHitTesting(false)", self.content)

    def test_glass_card_modifier_contrast_and_luminance(self):
        # GlassCardModifier must include dark obsidian midnight undertone and light mode clarity
        self.assertIn("Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.40)", self.content)
        self.assertIn("Color.white.opacity(0.42)", self.content)

    def test_instance_thumbnail_tile_adaptive_density_and_fx(self):
        # InstanceThumbnailTile must use density.screenHeight and attach ambient glow and shimmer
        self.assertIn("var density: ViewDensity = .comfortable", self.content)
        self.assertIn(".frame(height: density.screenHeight)", self.content)
        self.assertIn("AmbientGlowBorder(", self.content)
        self.assertIn("GlassShimmerOverlay(", self.content)
        self.assertIn("lhs.density == rhs.density", self.content)

    def test_instance_card_ambient_glow_and_shimmer(self):
        # InstanceCard must attach AmbientGlowBorder and GlassShimmerOverlay
        self.assertIn("AmbientGlowBorder(", self.content)
        self.assertIn("GlassShimmerOverlay(isHovered: hovered, cornerRadius: 16)", self.content)

    def test_thumbnail_wall_section_density_integration(self):
        # thumbnailWallSection must layout LazyVGrid using store.viewDensity
        self.assertIn("store.viewDensity.minWidth", self.content)
        self.assertIn("store.viewDensity.maxWidth", self.content)
        self.assertIn("store.viewDensity.gridSpacing", self.content)
        self.assertIn("density: store.viewDensity", self.content)

    def test_toolbar_and_popover_density_controls(self):
        # Both controlToolbar and toolbarOptionsPopover must provide view density pickers
        self.assertIn("toolbarDensitySwitcher", self.content)
        self.assertIn("popoverDensitySection", self.content)
        self.assertIn("store.tr(.viewDensityTitle)", self.content)

    def test_density_localization_keys_and_translations(self):
        # All 4 languages must support densityTitle, densityComfortable, densityCompact, densityMatrix
        for lang_func in ["stringZHHans", "stringEN", "stringJA", "stringZHHant"]:
            idx = self.content.find(f"func {lang_func}(")
            self.assertNotEqual(idx, -1)
            body = self.content[idx:idx + 4000]
            self.assertIn(".densityTitle", body)
            self.assertIn(".densityComfortable", body)
            self.assertIn(".densityCompact", body)
            self.assertIn(".densityMatrix", body)

    def test_streamlined_header_dashboard_and_utility_menu(self):
        # Header dashboard must feature unified glass utility cluster with consolidated maintenance Menu
        self.assertIn(r"v\(appVersion)", self.content)
        self.assertIn("Kernel Direct", self.content)
        self.assertIn("Label(\"管理升级备份 (\\(store.backups.count) 个批次)\", systemImage: \"externaldrive\")", self.content)
        self.assertIn("Label(\"检查软件更新...\", systemImage: \"arrow.down.circle\")", self.content)
        self.assertIn("Label(\"自动更新设置...\", systemImage: \"gearshape\")", self.content)

    def test_compact_and_expanded_metrics_hud(self):
        # MetricsHUD must support both compact HUD mode and expandable grid
        self.assertIn("@AppStorage(\"metricsHudExpanded\") private var metricsExpanded", self.content)
        self.assertIn("private var compactMetricsHUD: some View", self.content)
        self.assertIn("private var expandedMetricsGrid: some View", self.content)
        self.assertIn("metricsExpanded.toggle()", self.content)

    def test_instance_thumbnail_tile_and_card_visual_hierarchy(self):
        # Thumbnail tile and card must maintain clean spacing and right-anchored popover actions
        self.assertIn("AutoPilotPillView(store: store, item: item, onConfigure: editAutoPilot)", self.content)
        self.assertIn("popoverMenuButton(", self.content)
        self.assertIn("title: \"在访达中显示应用\"", self.content)
        self.assertIn("title: \"查看运行日志\"", self.content)

    def test_tactile_spring_button_style(self):
        # TactileSpringButtonStyle must provide spring animations, haptics, and reusable button scaling
        self.assertIn("struct TactileSpringButtonStyle: ButtonStyle", self.content)
        self.assertIn("var pressedScale: CGFloat", self.content)
        self.assertIn("var hoverScale: CGFloat", self.content)
        self.assertIn("HapticManager.shared.play", self.content)
        # Must be applied across thumbnail, popovers, and action controls
        self.assertIn(".buttonStyle(TactileSpringButtonStyle(", self.content)

    def test_liquid_glass_sheets(self):
        # All modal sheets must use unified LiquidGlassSheetModifier
        self.assertIn("struct LiquidGlassSheetModifier: ViewModifier", self.content)
        self.assertIn("func liquidGlassSheet(radius: CGFloat = 16) -> some View", self.content)
        self.assertIn(".liquidGlassSheet(radius: 16)", self.content)

    def test_version_bump_0_8_13(self):
        # Fallback version string in AntigravityMultiplexer.swift must be 0.8.13
        self.assertIn('Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.8.13"', self.content)

    def test_popover_menu_row_item_reuse(self):
        # PopoverMenuRowItem must be defined and reused across tile and list item popovers
        self.assertIn("struct PopoverMenuRowItem: View", self.content)
        self.assertIn("PopoverMenuRowItem(", self.content)
        self.assertIn(".buttonStyle(TactileSpringButtonStyle(pressedScale: 0.96, hoverScale: 1.01))", self.content)

    def test_modern_button_style_specular_sheen(self):
        # ModernButtonStyle must provide specular highlight for secondary and ghost variants
        self.assertIn("(variant == .secondary || variant == .ghost) && !configuration.isPressed", self.content)
        self.assertIn("LinearGradient(", self.content)

    def test_status_popover_liquid_glass(self):
        # StatusPopoverView must apply liquidGlassSheet(radius: 14)
        self.assertIn("StatusPopoverView: View", self.content)
        self.assertIn(".liquidGlassSheet(radius: 14)", self.content)

    def test_content_view_instant_search(self):
        # ContentView must include instant search field in controlToolbar and full-text filter in matchesFilter
        self.assertIn("@State private var searchText: String = \"\"", self.content)
        self.assertIn("matchesFilter(_ item: ManagedInstance)", self.content)
        self.assertIn("searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()", self.content)
        self.assertIn("Instant Liquid Glass Search Field", self.content)

    def test_clone_dock_policy_enum_and_settings(self):
        # CloneDockPolicy enum and settings integration must be present
        self.assertIn("enum CloneDockPolicy: String, CaseIterable, Identifiable", self.content)
        self.assertIn("case hidden = \"hidden\"", self.content)
        self.assertIn("case auto = \"auto\"", self.content)
        self.assertIn("case always = \"always\"", self.content)
        self.assertIn("@Published var cloneDockPolicy: CloneDockPolicy", self.content)
        self.assertIn('(json["dockPolicy"] as? String) != cloneDockPolicy.rawValue', self.content)
        self.assertIn("Picker(\"\", selection: $store.cloneDockPolicy)", self.content)

    def test_transcript_idle_state_detection_and_system_message(self):
        # parseTranscriptTail must detect idle state for SYSTEM_MESSAGE and completed GENERIC steps
        self.assertIn('(lastType == "SYSTEM_MESSAGE" || lastType == "ERROR_MESSAGE") && isRunning', self.content)
        self.assertIn('后台任务完成 · 等待新指令', self.content)
        self.assertIn('lastType == "GENERIC" && isRunning', self.content)
        self.assertIn('lastStatus == "RUNNING"', self.content)
        self.assertIn('state: .idle', self.content)
        self.assertIn('任务已完成 · 等待新指令', self.content)

    def test_cdp_concurrent_task_group_and_timeout_guard(self):
        # captureCDPScreenshots must use withTaskGroup for concurrency and withTimeout in fetchCDPData
        self.assertIn('await withTaskGroup(of: ItemCDPData?.self)', self.content)
        self.assertIn('withTimeout<T: Sendable>(seconds: Double', self.content)
        self.assertIn('withTimeout(seconds: 0.5', self.content)
        self.assertIn('withTimeout(seconds: 0.6', self.content)

    def test_cdp_execution_state_clears_running_action_strings(self):
        # CDP DOM execution state must clear stale running action strings when instance is confirmed idle
        self.assertIn('if !isExecuting {', self.content)
        self.assertIn('act.currentAction.hasPrefix("正在")', self.content)
        self.assertIn('act.currentAction.hasPrefix("分析结果")', self.content)
        self.assertIn('act.currentAction = "任务已完成 · 等待新指令"', self.content)

    def test_telemetry_scan_watchdog_auto_recovery(self):
        # refreshTelemetryAndThumbnails must auto-reset isScanningTelemetry watchdog if scan exceeds 6 seconds
        self.assertIn('lastTelemetryScanStartTime', self.content)
        self.assertIn('Date().timeIntervalSince(start) > 6.0', self.content)
        self.assertIn('guard !isScanningTelemetry else { return }', self.content)

    def test_multi_tier_window_collapse_protocol(self):
        # Multi-tier instantaneous window collapse protocol checks
        self.assertIn("static func getOnScreenWindowPIDs() -> Set<pid_t>", self.content)
        self.assertIn("static func isProcessCollapsed(pid: pid_t, isHidden: Bool, onScreenPIDs: Set<pid_t>) -> Bool", self.content)
        self.assertIn("static func collapseInstanceWindowCDP(item: ManagedInstance) async -> Bool", self.content)
        self.assertIn("static func collapseWindowViaAccessibility(pid: pid_t)", self.content)
        self.assertIn("func collapseInstanceWindow(_ item: ManagedInstance, app: NSRunningApplication?)", self.content)
        self.assertIn('"expression": "window.close()"', self.content)
        self.assertIn("collapseInstanceWindow(item, app: app)", self.content)
        self.assertIn("collapseAllToMonitorWall()", self.content)

    def test_global_hotkey_option_zero_collapse(self):
        # GlobalHotKeyManager must register Option+0 (kVK_ANSI_0) with id = 10
        self.assertIn("var onCollapseAll: (() -> Void)?", self.content)
        self.assertIn("registerHotKey(keyCode: UInt32(kVK_ANSI_0), modifiers: UInt32(optionKey), id: 10)", self.content)
        self.assertIn("else if id == 10 {", self.content)
        self.assertIn("GlobalHotKeyManager.shared.onCollapseAll?()", self.content)
        self.assertIn("onCollapseAll: { [weak self] in", self.content)
        self.assertIn("self?.collapseAllToMonitorWall()", self.content)

    def test_toolbar_collapse_badge_and_state(self):
        # Toolbar collapse button must show dynamic visible window count and Option+0 help
        self.assertIn("var visibleWindowCount: Int {", self.content)
        self.assertIn("Image(systemName: \"rectangle.compress.vertical\")", self.content)
        self.assertIn('Text("\\(store.tr(.toolbarCollapseAll)) (\\(store.visibleWindowCount))")', self.content)
        self.assertIn(".buttonStyle(ModernButtonStyle(variant: store.visibleWindowCount > 0 ? .primary : .secondary))", self.content)
        self.assertIn("一键收起所有正在显示的 Antigravity 窗口回到监控台 (快捷键 ⌥0，后台任务继续保持运行)", self.content)

    def test_status_bar_and_hud_collapse_shortcuts(self):
        # Status bar menu and Floating HUD must show collapse button with Option+0 hint
        self.assertIn('let collapseItem = NSMenuItem(title: "一键收起所有窗口 (⌥0)"', self.content)
        self.assertIn("collapseItem.keyEquivalentModifierMask = [.option]", self.content)
        self.assertIn('Image(systemName: "rectangle.compress.vertical")', self.content)

    def test_status_bar_right_click_no_recursion(self):
        # handleStatusBarButtonClick must use menu.popUp directly and never call performClick(nil)
        self.assertNotIn("sender.performClick(nil)", self.content)
        self.assertIn("menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)", self.content)

    def test_auto_pilot_task_completion_gate_and_state_tracking(self):
        # InstanceStore must track autoPilotAwaitingTaskCompletion and autoPilotObservedRunning
        self.assertIn("@Published var autoPilotAwaitingTaskCompletion: [String: Bool] = [:]", self.content)
        self.assertIn("@Published var autoPilotObservedRunning: [String: Bool] = [:]", self.content)
        self.assertIn("private var autoPilotInjectedStepIndex: [String: Int] = [:]", self.content)
        self.assertIn("private var autoPilotInjectedTime: [String: Date] = [:]", self.content)

        # handleAutoPilotStateChange must check autoPilotAwaitingTaskCompletion on .idle
        self.assertIn("if autoPilotAwaitingTaskCompletion[item.id] == true {", self.content)
        self.assertIn("let hasSeenRunning = autoPilotObservedRunning[item.id] == true", self.content)
        self.assertIn("let stepProgressed = curStep > prevStep", self.content)
        self.assertIn("if !hasSeenRunning && !stepProgressed && elapsed < 20.0 {", self.content)
        self.assertIn("autoPilotStates[item.id] = .waitingRunning", self.content)

    def test_cdp_preflight_dom_gatekeeper(self):
        # CDP injection must define CDPInjectionResult and execute DOM preflight check
        self.assertIn("enum CDPInjectionResult: Equatable", self.content)
        self.assertIn("case busyRunningOrQueued(hasStop: Bool, hasQueued: Bool)", self.content)
        self.assertIn("func injectPromptViaCDP(item: ManagedInstance, prompt: String) async -> CDPInjectionResult", self.content)
        self.assertIn('button[aria-label="Stop execution"]', self.content)
        self.assertIn("Queued Messages", self.content)
        self.assertIn("Sends after agent finishes", self.content)
        self.assertIn("canInject: !hasStop && !hasQueued", self.content)
        self.assertIn("case .busyRunningOrQueued(let hasStop, let hasQueued):", self.content)


if __name__ == "__main__":
    unittest.main()



