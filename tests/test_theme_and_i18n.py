import os
import unittest


class TestThemeAndI18n(unittest.TestCase):
    def setUp(self):
        source_path = os.path.join(os.path.dirname(__file__), "..", "Sources", "AntigravityMultiplexer.swift")
        self.assertTrue(os.path.exists(source_path), f"Source file not found at {source_path}")
        with open(source_path, "r", encoding="utf-8") as f:
            self.content = f.read()

    def test_app_theme_definition_and_cases(self):
        # AppTheme enum must provide system, light, and dark modes
        self.assertIn("enum AppTheme: String, CaseIterable, Identifiable", self.content)
        self.assertIn("case system", self.content)
        self.assertIn("case light", self.content)
        self.assertIn("case dark", self.content)
        self.assertIn("var symbol: String", self.content)
        self.assertIn("var colorScheme: ColorScheme?", self.content)
        self.assertIn("func localized(lang: AppLanguage) -> String", self.content)

    def test_app_language_definition_and_cases(self):
        # AppLanguage enum must support system auto-detect and major locales
        self.assertIn("enum AppLanguage: String, CaseIterable, Identifiable", self.content)
        self.assertIn("case system = \"system\"", self.content)
        self.assertIn("case zhHans = \"zh-Hans\"", self.content)
        self.assertIn("case en = \"en\"", self.content)
        self.assertIn("case ja = \"ja\"", self.content)
        self.assertIn("case zhHant = \"zh-Hant\"", self.content)
        self.assertIn("var effective: AppLanguage", self.content)

    def test_l10n_key_and_dictionary(self):
        # L10nKey and L10n must have full translations and lookup method
        self.assertIn("enum L10nKey", self.content)
        self.assertIn("struct L10n", self.content)
        self.assertIn("static func tr(_ key: L10nKey, lang: AppLanguage) -> String", self.content)
        self.assertIn("func tr(_ key: L10nKey) -> String", self.content)

    def test_haptic_manager_definition(self):
        # HapticManager must interface with NSHapticFeedbackManager
        self.assertIn("final class HapticManager", self.content)
        self.assertIn("static let shared = HapticManager()", self.content)
        self.assertIn("NSHapticFeedbackManager.defaultPerformer", self.content)
        self.assertIn("perform(pattern, performanceTime: performanceTime)", self.content)

    def test_window_tile_manager(self):
        # WindowTileManager must provide splitLeftRight, quadGrid, and cascade presets
        self.assertIn("enum WindowTileLayout: String, CaseIterable, Identifiable", self.content)
        self.assertIn("case splitLeftRight", self.content)
        self.assertIn("case quadGrid", self.content)
        self.assertIn("case cascade", self.content)
        self.assertIn("final class WindowTileManager", self.content)
        self.assertIn("static func applyLayout(_ layout: WindowTileLayout, instances: [ManagedInstance])", self.content)

    def test_instance_store_theme_and_i18n_persistence(self):
        # InstanceStore must publish appTheme, appLanguage, hapticsEnabled, ecoModeEnabled with persistence
        self.assertIn("@Published var appTheme: AppTheme", self.content)
        self.assertIn("@Published var appLanguage: AppLanguage", self.content)
        self.assertIn("@Published var hapticsEnabled: Bool", self.content)
        self.assertIn("@Published var ecoModeEnabled: Bool", self.content)
        self.assertIn('UserDefaults.standard.string(forKey: "appTheme")', self.content)
        self.assertIn('UserDefaults.standard.string(forKey: "appLanguage")', self.content)

    def test_color_scheme_propagation(self):
        # ContentView, FloatingMonitorHUDView, and QuickSwitcherView must observe preferredColorScheme
        self.assertIn(".preferredColorScheme(store.appTheme.colorScheme)", self.content)

    def test_toolbar_options_popover_controls(self):
        # Popover must include theme switcher, language picker, tile presets, haptics and eco toggles
        self.assertIn("store.tr(.themeTitle)", self.content)
        self.assertIn("store.tr(.langTitle)", self.content)
        self.assertIn("store.tr(.tilePresetsTitle)", self.content)
        self.assertIn("store.tr(.hapticsEnabled)", self.content)
        self.assertIn("store.tr(.ecoModeEnabled)", self.content)
        self.assertIn("WindowTileManager.applyLayout(layout, instances: store.instances)", self.content)

    def test_quick_switcher_localized_and_haptics(self):
        # Quick Switcher must use store.tr and play haptics on selection
        self.assertIn("store.tr(.qsSearchPlaceholder)", self.content)
        self.assertIn("store.tr(.qsNoMatch)", self.content)
        self.assertIn("store.tr(.qsSelect)", self.content)
        self.assertIn("store.tr(.qsActivate)", self.content)
        self.assertIn("HapticManager.shared.play(.alignment)", self.content)


if __name__ == "__main__":
    unittest.main()
