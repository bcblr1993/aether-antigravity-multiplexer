import AppKit
import SwiftUI

// MARK: - v0.9.0 "Aether Fleet Commander" Modular Extensions & Sheets

struct TranscriptStepPreview: Identifiable, Equatable {
    let id: String
    let stepIndex: Int
    let role: String
    let status: String
    let timestampLabel: String
    let summary: String
    let toolNames: [String]

    var roleColor: Color {
        switch role {
        case "USER_INPUT": return .cyan
        case "PLANNER_RESPONSE": return Color(red: 0.52, green: 0.32, blue: 0.98)
        case "ERROR_MESSAGE": return .red
        default: return .secondary
        }
    }

    var roleLabel: String {
        switch role {
        case "USER_INPUT": return "👤 用户指令"
        case "PLANNER_RESPONSE": return "🤖 Agent 响应"
        case "ERROR_MESSAGE": return "⚠️ 异常输出"
        case "SYSTEM_MESSAGE": return "🔔 系统通知"
        default: return role
        }
    }
}

struct ProfileSyncReport: Equatable {
    var syncedInstanceCount: Int = 0
    var syncedFileCount: Int = 0
    var details: [String] = []
    var timestamp: Date = Date()
}

// MARK: - Live Transcript Step Reader

extension TelemetryScanner {
    static func readRecentTranscriptSteps(for item: ManagedInstance, limit: Int = 12) -> [TranscriptStepPreview] {
        guard let latest = findTranscript(in: item.profileURL, knownConvID: nil),
              let handle = try? FileHandle(forReadingFrom: latest.url) else {
            return []
        }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        let readBytes: UInt64 = min(fileSize, 131_072)
        if fileSize > readBytes {
            try? handle.seek(toOffset: fileSize - readBytes)
        } else {
            try? handle.seek(toOffset: 0)
        }
        let data = handle.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var rawLines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if fileSize > readBytes && !rawLines.isEmpty {
            rawLines.removeFirst()
        }

        var results: [TranscriptStepPreview] = []
        for (idx, line) in rawLines.enumerated() {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
            let type = obj["type"] as? String ?? "GENERIC"
            guard type == "USER_INPUT" || type == "PLANNER_RESPONSE" || type == "ERROR_MESSAGE" || type == "SYSTEM_MESSAGE" else {
                continue
            }
            let stepIndex = obj["step_index"] as? Int ?? idx
            let status = obj["status"] as? String ?? "DONE"
            let createdAt = obj["created_at"] as? String ?? ""
            let timeShort: String = {
                if let tRange = createdAt.range(of: "T") {
                    let afterT = createdAt[tRange.upperBound...]
                    return String(afterT.prefix(8))
                }
                return ""
            }()

            var toolNames: [String] = []
            if let tools = obj["tool_calls"] as? [[String: Any]] {
                for t in tools {
                    if let name = t["name"] as? String ?? t["tool_name"] as? String {
                        toolNames.append(name)
                    }
                }
            }

            let content = (obj["content"] as? String ?? "")
                .replacingOccurrences(of: "<USER_REQUEST>", with: "")
                .replacingOccurrences(of: "</USER_REQUEST>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let summaryText: String
            if !content.isEmpty {
                summaryText = String(content.prefix(260))
            } else if !toolNames.isEmpty {
                summaryText = "调用工具：\(toolNames.joined(separator: ", "))"
            } else {
                continue
            }

            results.append(
                TranscriptStepPreview(
                    id: "\(stepIndex)-\(idx)",
                    stepIndex: stepIndex,
                    role: type,
                    status: status,
                    timestampLabel: timeShort,
                    summary: summaryText,
                    toolNames: toolNames
                )
            )
        }

        return Array(results.suffix(limit).reversed())
    }
}

// MARK: - InstanceStore v0.9.0 Fleet Commander Operations

extension InstanceStore {
    /// Remotely clicks Approve / Proceed / Run / Allow (or Reject / Cancel) buttons inside the target instance via CDP without switching windows.
    func approveOrRejectViaCDP(item: ManagedInstance, approve: Bool) async -> Bool {
        let portFile = item.userDataURL.appendingPathComponent("DevToolsActivePort")
        guard let content = try? String(contentsOf: portFile, encoding: .utf8),
              let firstLine = content.components(separatedBy: .newlines).first,
              let port = Int(firstLine.trimmingCharacters(in: .whitespacesAndNewlines)),
              let listURL = URL(string: "http://127.0.0.1:\(port)/json/list") else {
            return false
        }

        var req = URLRequest(url: listURL)
        req.timeoutInterval = 1.0
        req.setValue("close", forHTTPHeaderField: "Connection")
        guard let (data, _) = try? await Self.cdpSession.data(for: req),
              let targets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let pageTarget = targets.first(where: { ($0["type"] as? String) == "page" }),
              let wsString = pageTarget["webSocketDebuggerUrl"] as? String,
              let wsURL = URL(string: wsString) else {
            return false
        }

        let task = Self.cdpSession.webSocketTask(with: wsURL)
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }

        let keywordsJS = approve
            ? "['proceed', 'accept', 'allow', 'approve', 'run command', 'confirm', '继续', '允许', '确认', '同意', '执行']"
            : "['reject', 'deny', 'cancel', 'decline', '拒绝', '取消']"

        let jsExpr = """
        (() => {
            const keywords = \(keywordsJS);
            const buttons = Array.from(document.querySelectorAll('button, [role="button"]'));
            for (const btn of buttons) {
                if (btn.disabled) continue;
                const text = ((btn.innerText || '') + ' ' + (btn.getAttribute('aria-label') || '') + ' ' + (btn.getAttribute('title') || '')).toLowerCase().trim();
                if (!text) continue;
                if (keywords.some(k => text.includes(k))) {
                    btn.click();
                    return { clicked: true, label: (btn.innerText || btn.getAttribute('aria-label') || '').trim() };
                }
            }
            return { clicked: false };
        })()
        """

        guard let payloadData = try? JSONSerialization.data(withJSONObject: [
            "id": 2090,
            "method": "Runtime.evaluate",
            "params": ["expression": jsExpr, "returnByValue": true]
        ]), let payloadStr = String(data: payloadData, encoding: .utf8) else {
            return false
        }

        do {
            try await task.send(.string(payloadStr))
            if let resp = try? await Self.withTimeout(seconds: 1.5, operation: { try await task.receive() }),
               case .string(let text) = resp,
               let respData = text.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let res = obj["result"] as? [String: Any],
               let resultVal = res["result"] as? [String: Any],
               let valDict = resultVal["value"] as? [String: Any],
               let clicked = valDict["clicked"] as? Bool, clicked {
                let label = valDict["label"] as? String ?? (approve ? "Proceed" : "Reject")
                await MainActor.run {
                    self.recordTaskEvent(
                        item: item,
                        category: .completed,
                        action: approve ? "✓ 已通过监控台远程批准操作 (\(label))" : "✕ 已通过监控台远程拒绝操作 (\(label))",
                        workspace: self.activities[item.id]?.workspace ?? "",
                        stepIndex: self.activities[item.id]?.stepIndex ?? 0,
                        duration: nil
                    )
                    self.refreshTelemetryAndThumbnails()
                }
                return true
            }
        } catch {}
        return false
    }

    /// Sends an inline quick-reply prompt directly to a running instance in the background via CDP without switching windows.
    func sendInlineQuickReply(to item: ManagedInstance, prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, item.running else { return }
        HapticManager.shared.play(.alignment)
        Task {
            let res = await self.injectPromptViaCDP(item: item, prompt: trimmed)
            await MainActor.run {
                if res == .success {
                    self.recordTaskEvent(
                        item: item,
                        category: .autoPilot,
                        action: "💬 监控台内联快回已送达：\(String(trimmed.prefix(48)))",
                        workspace: self.activities[item.id]?.workspace ?? "",
                        stepIndex: self.activities[item.id]?.stepIndex ?? 0,
                        duration: nil
                    )
                    self.refreshTelemetryAndThumbnails()
                } else {
                    self.error = "向 \(item.name) 发送内联指令未成功（请确认该实例不在忙碌或弹窗阻塞状态）。"
                }
            }
        }
    }

    /// Concurrently broadcasts a prompt across multiple selected or running instances via CDP.
    func broadcastPrompt(_ prompt: String, to targets: [ManagedInstance]) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let runningTargets = targets.filter(\.running)
        guard !trimmed.isEmpty, !runningTargets.isEmpty else { return }
        HapticManager.shared.play(.levelChange)

        Task {
            await withTaskGroup(of: (ManagedInstance, CDPInjectionResult).self) { group in
                for target in runningTargets {
                    group.addTask {
                        let res = await self.injectPromptViaCDP(item: target, prompt: trimmed)
                        return (target, res)
                    }
                }
                for await (target, res) in group {
                    if res == .success {
                        await MainActor.run {
                            self.recordTaskEvent(
                                item: target,
                                category: .autoPilot,
                                action: "📡 集群广播指令已送达：\(String(trimmed.prefix(42)))",
                                workspace: self.activities[target.id]?.workspace ?? "",
                                stepIndex: self.activities[target.id]?.stepIndex ?? 0,
                                duration: nil
                            )
                        }
                    }
                }
            }
            await MainActor.run {
                self.refreshTelemetryAndThumbnails()
            }
        }
    }

    /// Synchronizes MCP Servers, Skills, Global Rules (GEMINI.md), and Editor Settings from Primary (#01) to target Clone instances.
    func syncMasterCustomizationsToClones(
        targets: [ManagedInstance],
        syncMCP: Bool = true,
        syncSkills: Bool = true,
        syncRules: Bool = true,
        syncSettings: Bool = true
    ) -> ProfileSyncReport {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let masterProfile = home.appendingPathComponent(".gemini")
        let masterAppSupport = home.appendingPathComponent("Library/Application Support/Antigravity/User")
        let clones = targets.filter { !$0.isOriginal }

        var report = ProfileSyncReport()

        for clone in clones {
            var syncedForClone = 0
            let cloneProfile = clone.profileURL
            let cloneUserDir = clone.userDataURL.appendingPathComponent("User")
            try? fm.createDirectory(at: cloneProfile, withIntermediateDirectories: true)
            try? fm.createDirectory(at: cloneUserDir, withIntermediateDirectories: true)

            // Find sub-folders in master & clone (e.g. antigravity, antigravitysecond, etc.)
            let cloneSubdirName = clone.name.lowercased().replacingOccurrences(of: " ", with: "")
            let masterSubdir = masterProfile.appendingPathComponent("antigravity")
            let cloneSubdir = cloneProfile.appendingPathComponent(cloneSubdirName)
            try? fm.createDirectory(at: cloneSubdir, withIntermediateDirectories: true)

            if syncMCP {
                for rel in ["mcp_config.json", "antigravity/mcp_config.json"] {
                    let src = masterProfile.appendingPathComponent(rel)
                    if fm.fileExists(atPath: src.path) {
                        let dst1 = cloneProfile.appendingPathComponent("mcp_config.json")
                        let dst2 = cloneSubdir.appendingPathComponent("mcp_config.json")
                        try? fm.removeItem(at: dst1)
                        try? fm.copyItem(at: src, to: dst1)
                        try? fm.removeItem(at: dst2)
                        try? fm.copyItem(at: src, to: dst2)
                        syncedForClone += 1
                        break
                    }
                }
            }

            if syncRules {
                for rel in ["GEMINI.md", "antigravity/GEMINI.md"] {
                    let src = masterProfile.appendingPathComponent(rel)
                    if fm.fileExists(atPath: src.path) {
                        let dst1 = cloneProfile.appendingPathComponent("GEMINI.md")
                        let dst2 = cloneSubdir.appendingPathComponent("GEMINI.md")
                        try? fm.removeItem(at: dst1)
                        try? fm.copyItem(at: src, to: dst1)
                        try? fm.removeItem(at: dst2)
                        try? fm.copyItem(at: src, to: dst2)
                        syncedForClone += 1
                        break
                    }
                }
            }

            if syncSkills {
                let candidateSkillsDirs = [
                    masterSubdir.appendingPathComponent("skills"),
                    masterProfile.appendingPathComponent("skills")
                ]
                if let srcSkills = candidateSkillsDirs.first(where: { fm.fileExists(atPath: $0.path) }) {
                    let dstSkills = cloneSubdir.appendingPathComponent("skills")
                    try? fm.removeItem(at: dstSkills)
                    if (try? fm.copyItem(at: srcSkills, to: dstSkills)) != nil {
                        syncedForClone += 1
                    }
                }
            }

            if syncSettings {
                for file in ["settings.json", "keybindings.json"] {
                    let src = masterAppSupport.appendingPathComponent(file)
                    if fm.fileExists(atPath: src.path) {
                        let dst = cloneUserDir.appendingPathComponent(file)
                        try? fm.removeItem(at: dst)
                        if (try? fm.copyItem(at: src, to: dst)) != nil {
                            syncedForClone += 1
                        }
                    }
                }
            }

            if syncedForClone > 0 {
                report.syncedInstanceCount += 1
                report.syncedFileCount += syncedForClone
                report.details.append("✓ \(clone.name)（已同步 \(syncedForClone) 项配置）")
            } else {
                report.details.append("• \(clone.name)（主实例无对应源文件可同步）")
            }
        }

        HapticManager.shared.play(.levelChange)
        return report
    }

    /// Evaluates idle duration across running clone instances and hibernates clones that exceed `idleAutoHibernateMinutes`.
    func checkIdleAutoHibernation() {
        guard idleAutoHibernateMinutes > 0 else {
            if !lastIdleSince.isEmpty { lastIdleSince.removeAll() }
            return
        }
        let now = Date()
        let thresholdSeconds = Double(idleAutoHibernateMinutes * 60)

        for item in instances where !item.isOriginal {
            guard item.running else {
                lastIdleSince.removeValue(forKey: item.id)
                continue
            }
            if hibernatedInstanceIDs.contains(item.id) {
                hibernatedInstanceIDs.remove(item.id)
            }
            let actState = activities[item.id]?.state ?? .idle
            let isFrontmost = (lastFrontmostAntigravityBundle == item.bundleID)
            let isAutoPilotActive = meta(for: item).autoPilotEnabled

            if actState == .idle && !isFrontmost && !isAutoPilotActive {
                let idleStart = lastIdleSince[item.id] ?? now
                lastIdleSince[item.id] = idleStart
                if now.timeIntervalSince(idleStart) >= thresholdSeconds {
                    lastIdleSince.removeValue(forKey: item.id)
                    hibernatedInstanceIDs.insert(item.id)
                    quit(item)
                    recordTaskEvent(
                        item: item,
                        category: .completed,
                        action: "💤 闲置满 \(idleAutoHibernateMinutes) 分钟，已智能热休眠释放内存（保留视窗快照与工作区上下文）",
                        workspace: activities[item.id]?.workspace ?? "",
                        stepIndex: activities[item.id]?.stepIndex ?? 0,
                        duration: nil
                    )
                }
            } else {
                lastIdleSince.removeValue(forKey: item.id)
            }
        }
    }
}

// MARK: - Live Transcript Inspector Sheet

struct LiveTranscriptInspectorSheet: View {
    @ObservedObject var store: InstanceStore
    let item: ManagedInstance
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var steps: [TranscriptStepPreview] = []
    @State private var quickPrompt: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.52, green: 0.32, blue: 0.98), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.name) · 实时对话流抽屉预览")
                        .font(.system(size: 15.5, weight: .bold))
                    Text("免切窗检视最近 12 条 Agent 推理步骤、工具调用与用户输入，支持直接内联回复")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    steps = TelemetryScanner.readRecentTranscriptSteps(for: item, limit: 12)
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))

                IconActionButton(symbol: "xmark", tooltip: "关闭", size: 28, action: { dismiss() })
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            if steps.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("暂无可预览的 Transcript 对话步骤")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(steps) { step in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(step.roleLabel)
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundStyle(step.roleColor)
                                        .padding(.horizontal, 6.5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(step.roleColor.opacity(0.14)))

                                    Text("Step #\(step.stepIndex)")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)

                                    if !step.toolNames.isEmpty {
                                        Text("🔧 \(step.toolNames.joined(separator: ", "))")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.cyan)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if !step.timestampLabel.isEmpty {
                                        Text(step.timestampLabel)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Text(step.summary)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary.opacity(0.92))
                                    .textSelection(.enabled)
                                    .lineLimit(5)
                            }
                            .padding(11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035)))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)
            }

            if item.running {
                Divider()
                HStack(spacing: 8) {
                    TextField("免切窗直接向 \(item.name) 发送指令...", text: $quickPrompt)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                        .onSubmit {
                            guard !quickPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            store.sendInlineQuickReply(to: item, prompt: quickPrompt)
                            quickPrompt = ""
                        }

                    if store.activity(for: item).state == .needsAttention {
                        Button {
                            Task { _ = await store.approveOrRejectViaCDP(item: item, approve: true) }
                        } label: {
                            Label("远程批准", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(ModernButtonStyle(variant: .upgrade, compact: true))
                    }

                    Button {
                        store.sendInlineQuickReply(to: item, prompt: quickPrompt)
                        quickPrompt = ""
                    } label: {
                        Label("发送指令", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))
                    .disabled(quickPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(22)
        .frame(width: 640)
        .liquidGlassSheet(radius: 16)
        .onAppear {
            steps = TelemetryScanner.readRecentTranscriptSteps(for: item, limit: 12)
        }
    }
}

// MARK: - Fleet Broadcast Sheet (Multi-Instance Concurrent Dispatch)

struct FleetBroadcastSheet: View {
    @ObservedObject var store: InstanceStore
    @Environment(\.dismiss) private var dismiss
    @State private var promptText: String = ""
    @State private var targetIds: Set<String> = []
    @State private var dispatchedCount: Int? = nil

    var body: some View {
        let runningInstances = store.instances.filter(\.running)

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("集群广播与并发任务分发 (Fleet Broadcast)")
                        .font(.system(size: 16, weight: .bold))
                    Text("通过 CDP 并发通道同时向多个运行中的实例静默下发指令，无需逐一切换窗口")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                IconActionButton(symbol: "xmark", tooltip: "关闭", size: 28, action: { dismiss() })
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("选择目标运行中实例 (\(targetIds.count)/\(runningInstances.count))")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("全选空闲实例") {
                        targetIds = Set(runningInstances.filter { store.activity(for: $0).state == .idle }.map(\.id))
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)

                    Text("·").foregroundStyle(.tertiary)

                    Button("全选运行中") {
                        targetIds = Set(runningInstances.map(\.id))
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                }

                if runningInstances.isEmpty {
                    Text("当前没有运行中的实例，请先启动至少一个实例。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(12)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(runningInstances) { inst in
                            let selected = targetIds.contains(inst.id)
                            let act = store.activity(for: inst)
                            Button {
                                if selected { targetIds.remove(inst.id) } else { targetIds.insert(inst.id) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(selected ? accent : .secondary)
                                    Text(inst.name)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(act.state.label)
                                        .font(.system(size: 10))
                                        .foregroundStyle(act.state.color)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(selected ? 0.10 : 0.04)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("广播指令内容")
                    .font(.system(size: 12, weight: .semibold))
                TextEditor(text: $promptText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 90)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
            }

            if let count = dispatchedCount {
                Text("✅ 已并发向 \(count) 个实例下发广播指令！")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.green)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))
                Button {
                    let targets = runningInstances.filter { targetIds.contains($0.id) }
                    store.broadcastPrompt(promptText, to: targets)
                    dispatchedCount = targets.count
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                } label: {
                    Label("立即并发广播 (\(targetIds.count))", systemImage: "paperplane.fill")
                }
                .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))
                .disabled(targetIds.isEmpty || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(22)
        .frame(width: 560)
        .liquidGlassSheet(radius: 16)
        .onAppear {
            if !store.selectedInstanceIds.isEmpty {
                targetIds = store.selectedInstanceIds.intersection(Set(runningInstances.map(\.id)))
            } else {
                targetIds = Set(runningInstances.filter { store.activity(for: $0).state == .idle }.map(\.id))
            }
        }
    }
}

// MARK: - Profile & Customization Sync Hub Sheet (Master -> Clones)

struct ProfileSyncHubSheet: View {
    @ObservedObject var store: InstanceStore
    @Environment(\.dismiss) private var dismiss
    @State private var syncMCP = true
    @State private var syncSkills = true
    @State private var syncRules = true
    @State private var syncSettings = true
    @State private var lastReport: ProfileSyncReport? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("跨实例配置与技能同步中心 (Profile & Skills Sync Hub)")
                        .font(.system(size: 16, weight: .bold))
                    Text("以 #01 官方主实例 (~/.gemini) 为基准源，一键将 MCP、Skills、全局规则与编辑器偏好同步至全部多开分身")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                IconActionButton(symbol: "xmark", tooltip: "关闭", size: 28, action: { dismiss() })
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Toggle("🔌 同步 MCP Servers 配置 (mcp_config.json)", isOn: $syncMCP)
                    .font(.system(size: 12.5, weight: .medium))
                Toggle("🧠 同步自定义 Skills 技能库目录 (skills/)", isOn: $syncSkills)
                    .font(.system(size: 12.5, weight: .medium))
                Toggle("📜 同步全局 Agent 规则文件 (GEMINI.md)", isOn: $syncRules)
                    .font(.system(size: 12.5, weight: .medium))
                Toggle("⌨️ 同步编辑器设置与快捷键 (settings.json / keybindings.json)", isOn: $syncSettings)
                    .font(.system(size: 12.5, weight: .medium))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .systemSurface(radius: 12)

            if let report = lastReport {
                VStack(alignment: .leading, spacing: 6) {
                    Text("✅ 同步完成：已更新 \(report.syncedInstanceCount) 个分身实例，共写入 \(report.syncedFileCount) 项配置")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(report.details, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.08)))
            }

            HStack {
                Text("目标分身数量：\(store.cloneInstances.count) 个（独立账号登录凭证与对话历史绝不覆盖）")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))
                Button {
                    lastReport = store.syncMasterCustomizationsToClones(
                        targets: store.cloneInstances,
                        syncMCP: syncMCP,
                        syncSkills: syncSkills,
                        syncRules: syncRules,
                        syncSettings: syncSettings
                    )
                } label: {
                    Label("一键同步至全部分身 (\(store.cloneInstances.count))", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))
                .disabled(store.cloneInstances.isEmpty || (!syncMCP && !syncSkills && !syncRules && !syncSettings))
            }
        }
        .padding(22)
        .frame(width: 580)
        .liquidGlassSheet(radius: 16)
    }
}
