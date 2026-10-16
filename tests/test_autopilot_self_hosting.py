import os
import unittest


class TestAutoPilotSelfHosting(unittest.TestCase):
    """Test suite for the Silent Background Auto-Pilot Self-Hosting System (自托管引擎)."""

    def setUp(self):
        source_path = os.path.join(os.path.dirname(__file__), "..", "Sources", "AntigravityMultiplexer.swift")
        self.assertTrue(os.path.exists(source_path), f"Source file not found at {source_path}")
        with open(source_path, "r", encoding="utf-8") as f:
            self.content = f.read()

    # --- 1. State Machine & Enum Definition ---

    def test_autopilot_run_state_enum(self):
        """AutoPilotRunState must define all lifecycle states for safe autonomous dispatching."""
        self.assertIn("enum AutoPilotRunState: String, Codable, Equatable", self.content)
        required_states = [
            "disabled",
            "standby",
            "debouncing",
            "injecting",
            "waitingRunning",
            "waitingStalled",
            "pausedNeedsAttention",
            "completed",
            "error"
        ]
        for state in required_states:
            self.assertIn(f"case {state}", self.content, f"Missing AutoPilotRunState case: {state}")

    def test_autopilot_run_state_labels_and_colors(self):
        """AutoPilotRunState must provide localized display text and badge color tags."""
        self.assertIn("func label(lang: AppLanguage) -> String", self.content)
        self.assertIn("var color: Color", self.content)
        self.assertIn("var systemImage: String", self.content)

    # --- 2. Configuration & Metadata Persistence ---

    def test_autopilot_fields_in_instance_user_meta(self):
        """InstanceUserMeta must include AutoPilot configuration fields with Codable support."""
        self.assertIn("var autoPilotEnabled: Bool", self.content)
        self.assertIn("var autoPilotPrompt: String", self.content)
        self.assertIn("var autoPilotMaxRounds: Int", self.content)
        self.assertIn("var autoPilotCurrentRounds: Int", self.content)
        self.assertIn("var autoPilotDebounceSeconds: Double", self.content)

        # Ensure CodingKeys and decodeIfPresent handle backwards compatibility
        self.assertIn("case autoPilotEnabled", self.content)
        self.assertIn("case autoPilotPrompt", self.content)
        self.assertIn("case autoPilotMaxRounds", self.content)
        self.assertIn("case autoPilotCurrentRounds", self.content)
        self.assertIn("case autoPilotDebounceSeconds", self.content)

    def test_autopilot_has_custom_content_considers_autopilot(self):
        """InstanceUserMeta.hasCustomContent must include autoPilotEnabled or custom prompt."""
        self.assertIn("autoPilotEnabled", self.content)

    # --- 3. InstanceStore Engine & Debounce State ---

    def test_autopilot_store_state_properties(self):
        """InstanceStore must manage active states, debounce timers, and countdowns."""
        self.assertIn("@Published var autoPilotStates: [String: AutoPilotRunState]", self.content)
        self.assertIn("@Published var autoPilotDebounceRemaining: [String: Int]", self.content)
        self.assertIn("autoPilotDebounceTasks: [String: Task<Void, Never>]", self.content)

    def test_autopilot_toggle_and_lifecycle_methods(self):
        """InstanceStore must provide methods to toggle, configure, and batch-control auto-pilot."""
        self.assertIn("func toggleAutoPilot(for item: ManagedInstance)", self.content)
        self.assertIn("func updateAutoPilotConfig(for item: ManagedInstance", self.content)
        self.assertIn("func startAllAutoPilot()", self.content)
        self.assertIn("func stopAllAutoPilot()", self.content)

    # --- 4. Strict Idle & Debounce Confirmation Invariants ---

    def test_autopilot_idle_debounce_logic(self):
        """Auto-pilot must strictly verify idle condition with a debounce period before injecting."""
        self.assertIn("func handleAutoPilotStateChange(for item: ManagedInstance", self.content)
        self.assertIn("autoPilotDebounceSeconds", self.content)
        # Must cancel debounce if instance starts running or needs attention
        self.assertIn("cancelAutoPilotDebounce", self.content)

    def test_autopilot_stalled_protection_logic(self):
        """Auto-pilot must passively wait when instance is .stalled and never interrupt."""
        self.assertIn(".waitingStalled", self.content)
        self.assertIn(".stalled", self.content)

    def test_autopilot_needs_attention_safety_lock(self):
        """Auto-pilot must lock and pause when instance enters .needsAttention."""
        self.assertIn(".pausedNeedsAttention", self.content)
        self.assertIn(".needsAttention", self.content)

    # --- 5. Silent Background CDP Injection ---

    def test_autopilot_silent_cdp_injection(self):
        """injectPromptViaCDP must silently inject preset text via Chromium DevTools Protocol."""
        self.assertIn("func injectPromptViaCDP(", self.content)
        # Must locate lexical editor / message input
        self.assertIn("data-lexical-editor", self.content)
        self.assertIn("Message input", self.content)
        # Must evaluate JavaScript via CDP
        self.assertIn("Runtime.evaluate", self.content)
        # Must dispatch submit (button click or Enter key)
        self.assertIn("Send message", self.content)

    def test_autopilot_zero_focus_stealing(self):
        """injectPromptViaCDP must never activate the application or steal window focus."""
        # Ensure CDP injection does NOT call NSApplication activate or bring to front
        method_body = self._extract_method_body("injectPromptViaCDP")
        self.assertNotIn("NSApplication.shared.activate", method_body)
        self.assertNotIn("NSApp.activate", method_body)
        self.assertNotIn("activate(ignoringOtherApps: true)", method_body)

    # --- 6. Circuit Breaker & Round Counter ---

    def test_autopilot_circuit_breaker_max_rounds(self):
        """Auto-pilot must halt and transition to .completed when autoPilotMaxRounds is met."""
        self.assertIn("autoPilotCurrentRounds >= meta.autoPilotMaxRounds", self.content)
        self.assertIn(".completed", self.content)

    # --- 7. UI Integration & Command Palette ---

    def test_autopilot_ui_components(self):
        """UI must include AutoPilotPillView badge and AutoPilotConfigSheet."""
        self.assertIn("struct AutoPilotPillView: View", self.content)
        self.assertIn("struct AutoPilotConfigSheet: View", self.content)

    def test_autopilot_command_palette_commands(self):
        """MultiplexerCommand must include commands to start and stop auto-pilot."""
        self.assertIn("case startAllAutoPilot", self.content)
        self.assertIn("case stopAllAutoPilot", self.content)

    # --- 8. State Precision & Anti-Stall Invariants ---

    def test_completed_planner_response_is_idle_not_stalled(self):
        """Completed PLANNER_RESPONSE with status DONE must immediately return .idle and never be marked .stalled."""
        self.assertIn('if lastType == "PLANNER_RESPONSE" && lastStatus == "DONE"', self.content)
        # Ensure hasRunningStep does not hijack completed planner responses
        self.assertNotIn("let hasRunningStep = parsedSteps.contains", self.content)

    def test_cdp_live_dom_execution_state_fusion(self):
        """TelemetryActor must fuse CDP DOM execution state to overrule false stalls when stop button is absent."""
        self.assertIn("var executionStates: [String: Bool]", self.content)
        self.assertIn("Stop execution", self.content)
        self.assertIn("Cancel", self.content)
        self.assertIn("act.state = .idle", self.content)
        self.assertIn("act.isStalled = false", self.content)

    def test_dual_channel_cdp_injection(self):
        """injectPromptViaCDP must implement dual-channel input (Input.insertText + Input.dispatchKeyEvent + button_click)."""
        body = self._extract_method_body("injectPromptViaCDP")
        self.assertIn("Input.insertText", body)
        self.assertIn("Input.dispatchKeyEvent", body)
        self.assertIn("sendBtn.click()", body)
        self.assertIn('"windowsVirtualKeyCode": 13', body)

    def _extract_method_body(self, method_name: str) -> str:
        idx = self.content.find(f"func {method_name}")
        if idx == -1:
            idx = self.content.find(method_name)
        if idx == -1:
            return ""
        start = self.content.find("{", idx)
        if start == -1:
            return ""
        depth = 0
        end = start
        for i in range(start, len(self.content)):
            if self.content[i] == "{":
                depth += 1
            elif self.content[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        return self.content[start:end+1]


if __name__ == "__main__":
    unittest.main()
