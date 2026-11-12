import os
import unittest


class TestV090FleetCommander(unittest.TestCase):
    def setUp(self):
        root = os.path.join(os.path.dirname(__file__), "..", "Sources")
        main_path = os.path.join(root, "AntigravityMultiplexer.swift")
        fleet_path = os.path.join(root, "FleetCommander.swift")
        self.assertTrue(os.path.exists(main_path), f"Missing {main_path}")
        with open(main_path, "r", encoding="utf-8") as f:
            self.main_content = f.read()
        self.fleet_path = fleet_path
        self.fleet_content = ""
        if os.path.exists(fleet_path):
            with open(fleet_path, "r", encoding="utf-8") as f:
                self.fleet_content = f.read()
        self.combined = self.main_content + "\n" + self.fleet_content

    def test_v0_9_0_version_and_modular_architecture(self):
        # Must bump version to 0.9.3 and split v0.9.x Fleet Commander modules into Sources/FleetCommander.swift
        self.assertIn('Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.9.3"', self.main_content)
        self.assertTrue(os.path.exists(self.fleet_path), "Sources/FleetCommander.swift must exist for v0.9.0 modular architecture")
        self.assertIn("struct TranscriptStepPreview: Identifiable, Equatable", self.fleet_content)
        self.assertIn("struct ProfileSyncReport: Equatable", self.fleet_content)
        self.assertIn("struct LiveTranscriptInspectorSheet: View", self.fleet_content)
        self.assertIn("struct FleetBroadcastSheet: View", self.fleet_content)
        self.assertIn("struct ProfileSyncHubSheet: View", self.fleet_content)

    def test_pillar1_inline_quick_reply_and_remote_cdp_approval(self):
        # Must support inline quick-reply, remote CDP Approve/Reject, and live transcript step inspection
        self.assertIn("func approveOrRejectViaCDP(item: ManagedInstance, approve: Bool) async -> Bool", self.combined)
        self.assertIn("func sendInlineQuickReply(to item: ManagedInstance, prompt: String)", self.combined)
        self.assertIn("static func readRecentTranscriptSteps(for item: ManagedInstance, limit: Int = 12) -> [TranscriptStepPreview]", self.combined)
        self.assertIn("showQuickReplyBar", self.combined)
        self.assertIn("quickReplyText", self.combined)
        self.assertIn("远程批准", self.combined)

    def test_pillar2_sequential_prompt_queue_and_fleet_broadcast(self):
        # InstanceUserMeta must support autoPilotQueue sequential prompt pipeline and Fleet Broadcast
        self.assertIn("var autoPilotQueue: [String] = []", self.combined)
        self.assertIn("if !m.autoPilotQueue.isEmpty", self.combined)
        self.assertIn("m.autoPilotQueue.removeFirst()", self.combined)
        self.assertIn("func broadcastPrompt(_ prompt: String, to targets: [ManagedInstance])", self.combined)
        self.assertIn("showFleetBroadcastSheet", self.combined)

    def test_pillar3_profile_and_customization_sync_hub(self):
        # Must support syncing MCP, Skills, Rules (GEMINI.md), and Editor settings from Primary to Clones
        self.assertIn("func syncMasterCustomizationsToClones(", self.combined)
        self.assertIn("mcp_config.json", self.combined)
        self.assertIn("GEMINI.md", self.combined)
        self.assertIn("settings.json", self.combined)
        self.assertIn("keybindings.json", self.combined)
        self.assertIn("跨实例配置与技能同步中心...", self.combined)

    def test_pillar4_smart_memory_guard_and_idle_hibernation(self):
        # Must support configurable idle auto-hibernation to reclaim RAM while preserving snapshot & context
        self.assertIn("@Published var idleAutoHibernateMinutes: Int", self.combined)
        self.assertIn("@Published var hibernatedInstanceIDs: Set<String>", self.combined)
        self.assertIn("func checkIdleAutoHibernation()", self.combined)
        self.assertIn("已休眠省存", self.combined)


if __name__ == "__main__":
    unittest.main()
