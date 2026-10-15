import os
import unittest


class TestP1P4AdvancedFeatures(unittest.TestCase):
    def setUp(self):
        source_path = os.path.join(os.path.dirname(__file__), "..", "Sources", "AntigravityMultiplexer.swift")
        self.assertTrue(os.path.exists(source_path), f"Source file not found at {source_path}")
        with open(source_path, "r", encoding="utf-8") as f:
            self.content = f.read()

    # --- P1: Quick Switcher Command Palette ---

    def test_p1_command_palette_enum_definition(self):
        """P1: MultiplexerCommand must define comprehensive system actions with icons and titles."""
        self.assertIn("enum MultiplexerCommand: String, CaseIterable, Identifiable", self.content)
        commands = [
            "launchAll", "stopAll", "restartAll",
            "tileSplit", "tileGrid", "tileCascade", "collapseAll",
            "createNew", "upgradeAll", "switchTheme", "switchDensity", "switchLanguage",
            "openSettings", "cleanCaches"
        ]
        for cmd in commands:
            self.assertIn(f"case {cmd}", self.content, f"Missing MultiplexerCommand case: {cmd}")

    def test_p1_command_palette_localization(self):
        """P1: MultiplexerCommand must support multi-language titles and subtitles."""
        self.assertIn("func title(lang: AppLanguage) -> String", self.content)
        self.assertIn("var systemImage: String", self.content)
        self.assertIn("var shortcutHint: String?", self.content)

    def test_p1_quick_switcher_command_mode(self):
        """P1: QuickSwitcherView must detect '>' prefix or command mode and execute commands."""
        self.assertIn("isCommandMode", self.content)
        self.assertIn('searchText.hasPrefix(">")', self.content)
        self.assertIn("executeCommand", self.content)

    # --- P2: Live Sparkline Activity Charts ---

    def test_p2_sparkline_sample_buffer(self):
        """P2: InstanceStore must manage circular sample history buffers (20 samples max)."""
        self.assertIn("MetricSample", self.content)
        self.assertIn("sampleBufferCapacity = 20", self.content)
        self.assertIn("appendMetricSample", self.content)

    def test_p2_sparkline_view_metal_gpu(self):
        """P2: SparklineView must use Path and Metal GPU hardware acceleration."""
        self.assertIn("struct SparklineView: View", self.content)
        self.assertIn(".drawingGroup(opaque: false)", self.content)
        self.assertIn("Path", self.content)

    def test_p2_sparkline_integration_in_ui(self):
        """P2: SparklineView must be integrated into metrics strip and instance cards."""
        self.assertIn("SparklineView(", self.content)

    # --- P3: Batch Multi-Selection & 6-Color Tags ---

    def test_p3_selection_mode_in_store(self):
        """P3: InstanceStore must support multi-selection state machine and batch actions."""
        self.assertIn("@Published var isSelectionMode: Bool", self.content)
        self.assertIn("@Published var selectedInstanceIds: Set<String>", self.content)
        self.assertIn("func toggleSelection(", self.content)
        self.assertIn("func selectAllInstances()", self.content)
        self.assertIn("func clearSelection()", self.content)
        self.assertIn("func batchOpenSelected()", self.content)
        self.assertIn("func batchQuitSelected()", self.content)

    def test_p3_floating_batch_action_bar(self):
        """P3: BatchActionBarView must be present with Liquid Glass surface and batch controls."""
        self.assertIn("struct BatchActionBarView: View", self.content)
        self.assertIn("batchOpenSelected", self.content)
        self.assertIn("batchQuitSelected", self.content)

    def test_p3_color_tags_enum_and_persistence(self):
        """P3: InstanceColorTag must support 6 colors and be persisted in InstanceMeta."""
        self.assertIn("enum InstanceColorTag: String, CaseIterable, Identifiable, Codable", self.content)
        color_cases = ["blue", "green", "purple", "orange", "yellow", "pink", "none"]
        for case in color_cases:
            self.assertIn(f"case {case}", self.content, f"Missing color tag case: {case}")
        self.assertIn("var colorTag: InstanceColorTag", self.content)

    # --- P4: Menu Bar Popover & Window Geometry ---

    def test_p4_menu_bar_status_popover(self):
        """P4: StatusPopoverView must be integrated with NSPopover for status bar left-click."""
        self.assertIn("struct StatusPopoverView: View", self.content)
        self.assertIn("NSPopover", self.content)

    def test_p4_window_geometry_persistence(self):
        """P4: InstanceStore must save and restore window geometries for instances."""
        self.assertIn("windowGeometries", self.content)


if __name__ == "__main__":
    unittest.main()
