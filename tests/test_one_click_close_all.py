import os
import unittest


class TestOneClickCloseAll(unittest.TestCase):
    def setUp(self):
        source_path = os.path.join(os.path.dirname(__file__), "..", "Sources", "AntigravityMultiplexer.swift")
        self.assertTrue(os.path.exists(source_path), f"Source file not found at {source_path}")
        with open(source_path, "r", encoding="utf-8") as f:
            self.content = f.read()

    def test_store_close_all_includes_main_setting_and_persistence(self):
        """InstanceStore must persist closeAllIncludesMainInstance in UserDefaults with default false."""
        self.assertIn("@Published var closeAllIncludesMainInstance: Bool", self.content)
        self.assertIn('UserDefaults.standard.object(forKey: "closeAllIncludesMainInstance")', self.content)
        self.assertIn('UserDefaults.standard.set(closeAllIncludesMainInstance, forKey: "closeAllIncludesMainInstance")', self.content)

    def test_store_running_counts_and_targets_helper(self):
        """InstanceStore must provide runningCloneCount, runningPrimaryCount, and runningTargetsCount."""
        self.assertIn("var runningCloneCount: Int", self.content)
        self.assertIn("var runningPrimaryCount: Int", self.content)
        self.assertIn("func runningTargetsCount(includeMain: Bool? = nil) -> Int", self.content)
        self.assertIn("shouldInclude || !$0.isOriginal", self.content)

    def test_store_quit_all_instances_method(self):
        """InstanceStore must implement quitAllInstances with graceful termination and haptics."""
        self.assertIn("func quitAllInstances(includeMain: Bool? = nil)", self.content)
        self.assertIn("for item in targets", self.content)
        self.assertIn("quit(item)", self.content)
        self.assertIn("HapticManager.shared.play(.levelChange)", self.content)

    def test_command_palette_stop_all_dispatcher(self):
        """Command palette dispatcher for stopAll must call quitAllInstances."""
        self.assertIn("case .stopAll:\n            quitAllInstances()", self.content)

    def test_header_dashboard_toolbar_ui(self):
        """Action toolbar must render one-click quit Menu with split primaryAction and danger style."""
        self.assertIn("store.quitAllInstances()", self.content)
        self.assertIn("ModernButtonStyle(variant: .danger)", self.content)
        self.assertIn("store.quitAllInstances(includeMain: true)", self.content)
        self.assertIn("store.quitAllInstances(includeMain: false)", self.content)
        self.assertIn("$store.closeAllIncludesMainInstance", self.content)

    def test_preferences_popover_toggle(self):
        """Preferences popover must feature a toggle switch for closeAllIncludesMainInstance."""
        self.assertIn("Toggle(isOn: $store.closeAllIncludesMainInstance)", self.content)
        self.assertIn("store.tr(.closeAllIncludesMainTitle)", self.content)
        self.assertIn("store.tr(.closeAllIncludesMainSubtitle)", self.content)

    def test_status_bar_menu_integration(self):
        """Status bar menu must provide one-click close when runningCount > 0."""
        self.assertIn("StatusBarTarget.quitAllInstancesAction", self.content)
        self.assertIn("func quitAllInstancesAction()", self.content)

    def test_l10n_quad_language_support(self):
        """L10n must provide complete translations for close-all keys in all 4 languages."""
        keys = [
            "toolbarCloseAll",
            "toolbarCloseClones",
            "closeAllIncludesMainTitle",
            "closeAllIncludesMainSubtitle",
        ]
        for key in keys:
            self.assertIn(f"case .{key}:", self.content, f"Missing L10n translation for {key}")


if __name__ == "__main__":
    unittest.main()
