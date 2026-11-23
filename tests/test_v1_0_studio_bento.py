import pathlib
import plistlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources"


def read_swift_files():
    """Return mapping of relative path -> source text for all Swift files under Sources/."""
    files = {}
    for path in sorted(SOURCES.rglob("*.swift")):
        files[path.relative_to(ROOT).as_posix()] = path.read_text(encoding="utf-8")
    return files


def extract_brace_block(source: str, pattern: str) -> str:
    """Extract a Swift type/declaration block from its header regex through its matching closing brace."""
    match = re.search(pattern, source)
    if not match:
        return ""
    brace_start = source.find("{", match.start())
    if brace_start == -1:
        return ""
    depth = 0
    for idx in range(brace_start, len(source)):
        ch = source[idx]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[match.start():idx + 1]
    return ""


class TestV100StudioBentoContract(unittest.TestCase):
    def test_1_modular_file_layout_and_line_budget(self):
        expected_files = [
            "Sources/Models/InstanceModels.swift",
            "Sources/Services/AccountDetector.swift",
            "Sources/Services/ActivityMonitor.swift",
            "Sources/Services/HotKeyService.swift",
            "Sources/Services/InstanceStore.swift",
            "Sources/Views/StudioTheme.swift",
            "Sources/Views/BentoInstanceCard.swift",
            "Sources/Views/MainView.swift",
            "Sources/Views/ConfirmationSheets.swift",
            "Sources/App/MultiplexerApp.swift",
            "Sources/ScriptOutputDecoder.swift",
        ]
        for rel_path in expected_files:
            full_path = ROOT / rel_path
            self.assertTrue(full_path.is_file(), f"Missing required modular file: {rel_path}")
            self.assertGreater(len(full_path.read_text(encoding="utf-8").strip()), 0, f"Empty Swift file: {rel_path}")

        obsolete_monoliths = [
            "Sources/AntigravityMultiplexer.swift",
            "Sources/FleetCommander.swift",
        ]
        for rel_path in obsolete_monoliths:
            self.assertFalse((ROOT / rel_path).exists(), f"Obsolete monolith must be deleted: {rel_path}")

        swift_files = read_swift_files()
        total_lines = sum(len(text.splitlines()) for text in swift_files.values())
        self.assertGreater(total_lines, 500, "Total Swift line count suspiciously low")
        self.assertLess(total_lines, 3600, f"Total Swift line count ({total_lines}) exceeds 3600-line v1.0.0 budget")

    def test_2_version_info_plist_release_notes_and_build_script(self):
        plist_data = plistlib.loads((ROOT / "Info.plist").read_bytes())
        self.assertEqual(plist_data.get("CFBundleShortVersionString"), "1.0.0")
        self.assertEqual(plist_data.get("CFBundleVersion"), "100")

        release_notes = (ROOT / "RELEASE_NOTES.md").read_text(encoding="utf-8")
        self.assertTrue(
            release_notes.lstrip().startswith("## v1.0.0 (Build 100) — 2026-11-23"),
            "RELEASE_NOTES.md must start with v1.0.0 (Build 100) — 2026-11-23 heading",
        )
        for keyword in ("Studio Bento", "Dark Obsidian", "Light Frost", "2.34.0", "Dock", "⌥1"):
            self.assertIn(keyword, release_notes, f"RELEASE_NOTES.md missing key v1.0.0 summary topic: {keyword}")

        main_view = (SOURCES / "Views/MainView.swift").read_text(encoding="utf-8")
        self.assertIn('CFBundleShortVersionString', main_view)
        self.assertIn('?? "1.0.0"', main_view)
        for rel_path, content in read_swift_files().items():
            self.assertNotIn('?? "0.9.7"', content, f"Stale fallback version 0.9.7 in {rel_path}")

        build_sh = (ROOT / "build.sh").read_text(encoding="utf-8")
        self.assertNotIn("manage_backups.py", build_sh)
        self.assertFalse((ROOT / "Resources/manage_backups.py").exists())
        for kept_resource in (
            "create_instance.py",
            "upgrade_all.py",
            "clear_workspace.py",
            "destroy_instance.py",
            "compatibility.json",
            "source_release_notes.json",
        ):
            self.assertTrue((ROOT / "Resources" / kept_resource).is_file(), f"Missing required resource: {kept_resource}")
            self.assertIn(kept_resource, build_sh, f"build.sh must copy {kept_resource}")

    def test_3_removed_bloat_and_obsolete_tests(self):
        removed_symbols = [
            "AutoPilotConfigSheet",
            "FleetBroadcastSheet",
            "LiveTranscriptInspectorSheet",
            "ProfileSyncHubSheet",
            "BackupManagementView",
            "WindowTileManager",
            "FloatingMonitorHUDView",
            "QuickSwitcherPanel",
            "CGWindowListCreateImage",
        ]
        for rel_path, content in read_swift_files().items():
            for symbol in removed_symbols:
                self.assertNotIn(symbol, content, f"Removed bloat symbol {symbol} still referenced in {rel_path}")

        obsolete_tests = [
            "tests/test_autopilot_self_hosting.py",
            "tests/test_v0_9_0_fleet_commander.py",
            "tests/test_manage_backups.py",
            "tests/test_p1_p4_advanced_features.py",
            "tests/test_multiplexer_audit.py",
            "tests/test_metadata_and_storage.py",
            "tests/test_theme_and_i18n.py",
            "tests/test_ui_polish_and_performance.py",
            "tests/test_one_click_close_all.py",
        ]
        for rel_path in obsolete_tests:
            self.assertFalse((ROOT / rel_path).exists(), f"Obsolete test file should be deleted: {rel_path}")

    def test_4_dual_theme_studio_bento_contract(self):
        models_src = (SOURCES / "Models/InstanceModels.swift").read_text(encoding="utf-8")
        theme_body = extract_brace_block(models_src, r"enum\s+AppTheme\b")
        self.assertTrue(theme_body, "enum AppTheme definition not found in InstanceModels.swift")
        self.assertIn("CaseIterable", theme_body)
        self.assertRegex(theme_body, r"\bdark\b")
        self.assertRegex(theme_body, r"\blight\b")
        self.assertRegex(theme_body, r"\bsystem\b")
        self.assertIn("var colorScheme: ColorScheme?", theme_body)
        for model_name in ("ManagedInstance", "InstanceActivity", "InstanceAccountInfo", "TaskRunState"):
            self.assertIn(model_name, models_src, f"Missing model type {model_name} in InstanceModels.swift")

        studio_theme = (SOURCES / "Views/StudioTheme.swift").read_text(encoding="utf-8")
        self.assertIn("struct StudioPalette", studio_theme)
        self.assertIn("darkObsidian", studio_theme)
        self.assertIn("lightFrost", studio_theme)
        self.assertIn("resolve(", studio_theme)

        main_view = (SOURCES / "Views/MainView.swift").read_text(encoding="utf-8")
        self.assertIn(".preferredColorScheme(store.appTheme.colorScheme)", main_view)
        self.assertIn("AppTheme.allCases", main_view)

        bento_card = (SOURCES / "Views/BentoInstanceCard.swift").read_text(encoding="utf-8")
        self.assertIn("struct BentoInstanceCard: View", bento_card)
        # Zone 1: header badge, title, inline alias editing
        self.assertIn("displayTitle", bento_card)
        self.assertIn("setAlias", bento_card)
        self.assertIn("TextField", bento_card)
        # Zone 2: synthetic live terminal viewport & dot-matrix stopped viewport
        self.assertIn("AGENT EXECUTING TASK", bento_card)
        self.assertIn("AGENT READY", bento_card)
        self.assertIn("WAITING FOR INPUT", bento_card)
        self.assertIn("Canvas", bento_card)
        self.assertIn("未启动", bento_card)
        # Zone 3: footer status & disk usage
        self.assertIn("currentAction", bento_card)
        self.assertIn("lastUpdatedLabel", bento_card)
        self.assertIn("formattedTotalData", bento_card)

    def test_5_realtime_google_account_detection_contract(self):
        detector = (SOURCES / "Services/AccountDetector.swift").read_text(encoding="utf-8")
        self.assertIn("AccountDetector", detector)
        self.assertIn("agy.onboarding.lastLoginUsername", detector)
        self.assertIn("jetski.onboarding.lastLoginUsername", detector)
        self.assertIn("google_accounts.json", detector)
        self.assertIn("-standalone-oauth-token", detector)
        self.assertIn("jetski-standalone-oauth-token", detector)
        self.assertIn("func maskEmail(", detector)

        store = (SOURCES / "Services/InstanceStore.swift").read_text(encoding="utf-8")
        self.assertIn("maskAccountEmails", store)
        self.assertIn("duplicateAccountCounts", store)
        self.assertIn("func account(for", store)
        self.assertIn("func duplicateCount(for", store)
        self.assertIn("func copyAccountEmail(for", store)

        main_view = (SOURCES / "Views/MainView.swift").read_text(encoding="utf-8")
        self.assertIn("maskAccountEmails", main_view)
        self.assertIn("隐藏邮箱", main_view)
        self.assertIn("显示完整邮箱", main_view)

        bento_card = (SOURCES / "Views/BentoInstanceCard.swift").read_text(encoding="utf-8")
        self.assertIn("maskAccountEmails", bento_card)
        self.assertIn("同号", bento_card)

    def test_6_bugfix_and_safety_invariants(self):
        swift_files = read_swift_files()
        all_services = "\n".join(
            text for rel, text in swift_files.items() if rel.startswith("Sources/Services/")
        )

        # 6a. ActivityMonitor must never double-prefix "上次：上次："
        activity_monitor = (SOURCES / "Services/ActivityMonitor.swift").read_text(encoding="utf-8")
        self.assertIn("上次：", activity_monitor)
        self.assertNotIn("上次：上次：", activity_monitor)
        if 'stopped.currentAction = "上次：\\(parsed.currentAction)"' in activity_monitor:
            self.fail("ActivityMonitor must not unconditionally wrap parsed.currentAction with 上次：")

        # 6b. Non-destructive window collapse across all Swift sources
        for rel_path, content in swift_files.items():
            self.assertNotIn("window.close()", content, f"Destructive window.close() forbidden in {rel_path}")
            self.assertNotIn("kAXCloseButtonAttribute", content, f"Destructive kAXCloseButtonAttribute forbidden in {rel_path}")
            # Ensure macOS 13 deployment target compatibility (no macOS 14+ exclusive syntax in code lines)
            code_only = "\n".join(line for line in content.splitlines() if not line.lstrip().startswith("//"))
            self.assertNotIn("@Observable", code_only, f"macOS 14+ @Observable forbidden in {rel_path}")
            self.assertNotIn(".symbolEffect", code_only, f"macOS 14+ .symbolEffect forbidden in {rel_path}")
            self.assertNotIn("#Preview", code_only, f"macOS 14+ #Preview macro forbidden in {rel_path}")

        self.assertIn("window.electronNative.minimize()", all_services)
        self.assertIn('"AXMinimized"', all_services)
        self.assertIn('"AXMinimizeButton"', all_services)

        # 6c. InstanceStore legacy nickname migration, Dock residency sync, and Local Network isolation
        store = (SOURCES / "Services/InstanceStore.swift").read_text(encoding="utf-8")
        self.assertIn('"instance_user_metas"', store)
        self.assertIn('"instanceAliases"', store)
        self.assertIn("nickname", store)
        self.assertIn('"dockVisibleInstanceIDs"', store)
        self.assertIn("func syncSystemDockPersistentApps()", store)
        self.assertIn("static func readSystemDockAntigravityBundleIDs()", store)
        self.assertIn("ensureCloneLocalNetworkIsolation", store)
        self.assertIn("func hideInstance(", store)
        self.assertIn("func collapseAllToMonitorWall()", store)

        # 6d. Global hotkeys, sheets, and app entry structure
        hotkeys = (SOURCES / "Services/HotKeyService.swift").read_text(encoding="utf-8")
        self.assertIn("kVK_ANSI_0", hotkeys)
        self.assertIn("optionKey", hotkeys)

        sheets = (SOURCES / "Views/ConfirmationSheets.swift").read_text(encoding="utf-8")
        for sheet_name in ("CreateInstanceSheet", "FastUpgradeSheet", "DangerConfirmationSheet"):
            self.assertIn(sheet_name, sheets)

        app_entry = (SOURCES / "App/MultiplexerApp.swift").read_text(encoding="utf-8")
        self.assertIn("@main", app_entry)
        self.assertIn("SPUStandardUpdaterController", app_entry)
        self.assertIn("applicationDockMenu", app_entry)


if __name__ == "__main__":
    unittest.main()
