import AppKit
import Darwin
import Foundation

/// Native kernel process tree metrics via Darwin libproc (`proc_listpids` / `proc_pidinfo`) with zero subprocesses.
enum NativeProcessMonitor {
    private static var previousSamples: [String: (timestamp: Date, totalCpuNanos: UInt64)] = [:]
    private static let lock = NSLock()
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        if info.denom == 0 { info.numer = 1; info.denom = 1 }
        return info
    }()

    private static func ticksToNanos(_ ticks: UInt64) -> UInt64 {
        let numer = UInt64(timebase.numer), denom = UInt64(timebase.denom)
        return (ticks / denom) * numer + ((ticks % denom) * numer) / denom
    }

    static func getProcessTreePids(root: pid_t) -> [pid_t] {
        guard root > 0 else { return [] }
        var pids: [pid_t] = [root], queue: [pid_t] = [root], visited = Set<pid_t>([root])
        while !queue.isEmpty {
            let parent = queue.removeFirst()
            var capacity = 256
            var buffer = [pid_t](repeating: 0, count: capacity)
            var bytes = proc_listpids(UInt32(PROC_PPID_ONLY), UInt32(parent), &buffer, Int32(capacity * MemoryLayout<pid_t>.stride))
            while bytes > 0 && Int(bytes) >= capacity * MemoryLayout<pid_t>.stride {
                capacity *= 2
                buffer = [pid_t](repeating: 0, count: capacity)
                bytes = proc_listpids(UInt32(PROC_PPID_ONLY), UInt32(parent), &buffer, Int32(capacity * MemoryLayout<pid_t>.stride))
            }
            guard bytes > 0 else { continue }
            for i in 0..<(Int(bytes) / MemoryLayout<pid_t>.stride) {
                let child = buffer[i]
                if child > 0 && visited.insert(child).inserted {
                    queue.append(child)
                    pids.append(child)
                }
            }
        }
        return pids
    }

    static func sampleTree(root: pid_t) -> (cpuNanos: UInt64, rssBytes: Int64, processCount: Int)? {
        guard root > 0 else { return nil }
        var totalTicks: UInt64 = 0, totalRss: Int64 = 0, valid = 0
        let size = Int32(MemoryLayout<proc_taskinfo>.stride)
        for pid in getProcessTreePids(root: root) {
            var info = proc_taskinfo()
            if proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size {
                totalTicks += info.pti_total_user + info.pti_total_system
                totalRss += Int64(info.pti_resident_size)
                valid += 1
            }
        }
        return valid > 0 ? (ticksToNanos(totalTicks), totalRss, valid) : nil
    }

    static func scanResourceMetrics(instances: [ManagedInstance], runningAppPids: [String: pid_t] = [:]) -> [String: InstanceResourceMetric] {
        var results: [String: InstanceResourceMetric] = [:]
        let now = Date()
        let runningItems = instances.filter(\.running)
        lock.lock()
        defer { lock.unlock() }
        guard !runningItems.isEmpty else {
            previousSamples.removeAll()
            return results
        }
        let runningIDs = Set(runningItems.map(\.id))
        previousSamples = previousSamples.filter { runningIDs.contains($0.key) }

        for item in runningItems {
            let rootPid: pid_t? = runningAppPids[item.id] ?? {
                let apps = NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID).filter { !$0.isTerminated }
                let expected = item.path.resolvingSymlinksInPath().standardizedFileURL
                return apps.first(where: { $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == expected })?.processIdentifier
                    ?? apps.first?.processIdentifier
            }()
            guard let root = rootPid, root > 0, let sample = sampleTree(root: root) else { continue }
            var cpuPercent = 0.0
            if let prev = previousSamples[item.id] {
                let dt = now.timeIntervalSince(prev.timestamp)
                if dt >= 0.4 {
                    let delta = sample.cpuNanos >= prev.totalCpuNanos ? (sample.cpuNanos - prev.totalCpuNanos) : 0
                    cpuPercent = min(max((Double(delta) / (dt * 1_000_000_000.0)) * 100.0, 0.0), Double(sample.processCount) * 100.0)
                }
            }
            previousSamples[item.id] = (now, sample.cpuNanos)
            results[item.id] = InstanceResourceMetric(cpuPercent: cpuPercent, rssBytes: sample.rssBytes, processCount: sample.processCount)
        }
        return results
    }
}

/// Transcript activity & zero-subprocess disk telemetry scanner.
enum TelemetryScanner {
    private static let cacheLock = NSLock()
    private static var stoppedActivityCache: [String: InstanceActivity] = [:]
    private static var lastKnownTranscripts: [URL: (url: URL, date: Date, convID: String)] = [:]
    private static var lastDirectoryScanTime: [URL: Date] = [:]
    private static var parsedTailCache: [URL: (modDate: Date, isRunning: Bool, cachedAt: Date, activity: InstanceActivity)] = [:]
    private static var appBundleSizeCache: [String: (modDate: Date, bytes: Int64)] = [:]

    static func clearStoppedCache() {
        cacheLock.lock(); stoppedActivityCache.removeAll(); cacheLock.unlock()
    }

    static func invalidateCache(for item: ManagedInstance) {
        cacheLock.lock()
        stoppedActivityCache.removeValue(forKey: item.id)
        lastKnownTranscripts.removeValue(forKey: item.profileURL)
        lastDirectoryScanTime.removeValue(forKey: item.profileURL)
        cacheLock.unlock()
    }

    static func scan(instances: [ManagedInstance], knownConvIDs: [String: String] = [:]) -> [String: InstanceActivity] {
        var results: [String: InstanceActivity] = [:]
        for item in instances {
            if !item.running {
                cacheLock.lock()
                let cached = stoppedActivityCache[item.id]
                cacheLock.unlock()
                if let cached { results[item.id] = cached; continue }

                var stopped = InstanceActivity.stopped
                if let latest = findTranscript(in: item.profileURL, knownConvID: knownConvIDs[item.id]) {
                    let parsed = parseTranscriptTail(at: latest.url, modDate: latest.date, isRunning: false, convID: latest.convID)
                    stopped.workspace = parsed.workspace
                    stopped.lastUpdatedLabel = parsed.lastUpdatedLabel
                    stopped.stepIndex = parsed.stepIndex
                    stopped.latestConversationID = parsed.latestConversationID
                    if !parsed.currentAction.isEmpty {
                        stopped.currentAction = withPreviousPrefix(parsed.currentAction)
                    }
                }
                cacheLock.lock(); stoppedActivityCache[item.id] = stopped; cacheLock.unlock()
                results[item.id] = stopped
            } else {
                cacheLock.lock(); stoppedActivityCache.removeValue(forKey: item.id); cacheLock.unlock()
                if let latest = findTranscript(in: item.profileURL, knownConvID: knownConvIDs[item.id]) {
                    results[item.id] = parseTranscriptTail(at: latest.url, modDate: latest.date, isRunning: true, convID: latest.convID)
                } else {
                    results[item.id] = InstanceActivity(state: .idle, currentAction: "等待新对话指令", workspace: item.profile, lastUpdatedLabel: "刚刚")
                }
            }
        }
        return results
    }

    static func findTranscript(in profileURL: URL, knownConvID: String?) -> (url: URL, date: Date, convID: String)? {
        let fm = FileManager.default
        if let knownConvID, !knownConvID.isEmpty,
           let dirs = try? fm.contentsOfDirectory(at: profileURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for dir in dirs {
                let transcript = dir.appendingPathComponent("brain").appendingPathComponent(knownConvID).appendingPathComponent(".system_generated/logs/transcript.jsonl")
                if let modDate = (try? transcript.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
                    let found = (transcript, modDate, knownConvID)
                    cacheLock.lock(); lastKnownTranscripts[profileURL] = found; cacheLock.unlock()
                    return found
                }
            }
        }
        let now = Date()
        cacheLock.lock()
        let cached = lastKnownTranscripts[profileURL]
        let lastScan = lastDirectoryScanTime[profileURL]
        cacheLock.unlock()
        if let cached, let modDate = (try? cached.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
            let recent = lastScan.map { now.timeIntervalSince($0) < 15.0 } ?? false
            if abs(modDate.timeIntervalSinceNow) < 30 || recent {
                let updated = (cached.url, modDate, cached.convID)
                cacheLock.lock(); lastKnownTranscripts[profileURL] = updated; cacheLock.unlock()
                return updated
            }
        }
        cacheLock.lock(); lastDirectoryScanTime[profileURL] = now; cacheLock.unlock()
        if let latest = latestTranscript(in: profileURL) {
            cacheLock.lock(); lastKnownTranscripts[profileURL] = latest; cacheLock.unlock()
            return latest
        }
        return nil
    }

    static func scanResourceMetrics(instances: [ManagedInstance], runningAppPids: [String: pid_t] = [:]) -> [String: InstanceResourceMetric] {
        NativeProcessMonitor.scanResourceMetrics(instances: instances, runningAppPids: runningAppPids)
    }

    static func scanDiskUsage(for item: ManagedInstance) -> InstanceDiskUsage {
        let profileBytes = directoryAllocatedBytes(at: item.profileURL)
        let userDataBytes = directoryAllocatedBytes(at: item.userDataURL) + directoryAllocatedBytes(at: item.logsURL)
        let modDate = (try? item.path.appendingPathComponent("Contents/Info.plist").resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast

        cacheLock.lock(); let cached = appBundleSizeCache[item.id]; cacheLock.unlock()
        let appBundleBytes: Int64
        if let cached, cached.modDate == modDate, cached.bytes > 0 {
            appBundleBytes = cached.bytes
        } else {
            let computed = directoryAllocatedBytes(at: item.path)
            if computed > 0 { cacheLock.lock(); appBundleSizeCache[item.id] = (modDate, computed); cacheLock.unlock() }
            appBundleBytes = computed
        }
        return InstanceDiskUsage(profileBytes: profileBytes, userDataBytes: userDataBytes, appBundleBytes: appBundleBytes)
    }

    static func scanDiskUsages(instances: [ManagedInstance]) -> [String: InstanceDiskUsage] {
        Dictionary(uniqueKeysWithValues: instances.map { ($0.id, scanDiskUsage(for: $0)) })
    }

    private static func directoryAllocatedBytes(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return 0 }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: []) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: keys), values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        return total
    }

    private static func latestTranscript(in profileURL: URL) -> (url: URL, date: Date, convID: String)? {
        let fm = FileManager.default
        guard let topDirs = try? fm.contentsOfDirectory(at: profileURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return nil }
        var newestURL: URL?, newestDate = Date.distantPast, newestConvID = ""
        for dir in topDirs {
            guard let convDirs = try? fm.contentsOfDirectory(at: dir.appendingPathComponent("brain"), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for conv in convDirs {
                let transcript = conv.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                if let modDate = (try? transcript.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, modDate > newestDate {
                    newestDate = modDate; newestURL = transcript; newestConvID = conv.lastPathComponent
                }
            }
        }
        return newestURL.map { ($0, newestDate, newestConvID) }
    }

    private static func parseTranscriptTail(at url: URL, modDate: Date, isRunning: Bool, convID: String) -> InstanceActivity {
        let now = Date()
        cacheLock.lock(); let cached = parsedTailCache[url]; cacheLock.unlock()
        if let cached, cached.modDate == modDate, cached.isRunning == isRunning, now.timeIntervalSince(cached.cachedAt) < 10.0 {
            return cached.activity
        }
        let activity = parseTranscriptTailUncached(at: url, modDate: modDate, isRunning: isRunning, convID: convID)
        cacheLock.lock(); parsedTailCache[url] = (modDate, isRunning, now, activity); cacheLock.unlock()
        return activity
    }

    private static func parseTranscriptTailUncached(at url: URL, modDate: Date, isRunning: Bool, convID: String) -> InstanceActivity {
        let age = max(0, Date().timeIntervalSince(modDate))
        let ageLabel = formatRelativeAge(age)
        func build(_ state: TaskRunState, _ action: String, workspace: String = "", stepIndex: Int = 0) -> InstanceActivity {
            InstanceActivity(
                state: isRunning ? state : .stopped,
                currentAction: isRunning ? action : withPreviousPrefix(action),
                workspace: workspace,
                lastUpdatedLabel: ageLabel,
                stepIndex: stepIndex,
                latestConversationID: convID
            )
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return build(.idle, "已启动就绪") }
        defer { try? handle.close() }
        let fileSize = (try? handle.seekToEnd()) ?? 0
        let readBytes = min(fileSize, 32_768)
        try? handle.seek(toOffset: fileSize - readBytes)
        guard let text = String(data: handle.readDataToEndOfFile(), encoding: .utf8) else { return build(.idle, "已启动就绪") }

        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        if fileSize > readBytes && lines.count > 1 { lines.removeFirst() }
        let parsedSteps = lines.suffix(8).compactMap {
            $0.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
        guard let last = parsedSteps.last else { return build(.idle, "等待新对话指令") }

        let workspace = extractWorkspace(from: parsedSteps)
        let stepIndex = last["step_index"] as? Int ?? 0
        let lastType = last["type"] as? String ?? ""
        let lastStatus = last["status"] as? String ?? ""
        let (recentTool, recentAction, recentTarget) = extractRecentToolInfo(from: parsedSteps)
        let recentPrompt = parsedSteps.reversed().compactMap { step -> String? in
            guard (step["type"] as? String) == "USER_INPUT", let c = step["content"] as? String else { return nil }
            let cleaned = cleanSnippet(c)
            return cleaned.isEmpty ? nil : cleaned
        }.first ?? ""

        if let tools = last["tool_calls"] as? [[String: Any]], let firstTool = tools.first {
            let toolName = firstTool["name"] as? String ?? "tool"
            let rawAction = ((firstTool["args"] as? [String: Any])?["toolAction"] as? String)
                ?? ((firstTool["args"] as? [String: Any])?["toolSummary"] as? String) ?? ""
            var actionText = rawAction.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            if actionText.isEmpty { actionText = recentTarget.isEmpty ? "调用工具 \(toolName)" : "操作 \(recentTarget)" }
            if isRunning && toolName == "ask_question" && age < 1800 {
                return build(.needsAttention, "等待确认：\(actionText)", workspace: workspace, stepIndex: stepIndex)
            }
            if !isRunning { return build(.stopped, actionText, workspace: workspace, stepIndex: stepIndex) }
            if age >= 600 { return build(.idle, "就绪 · 上次：\(actionText)", workspace: workspace, stepIndex: stepIndex) }
            return build(age >= 180 ? .stalled : .runningTask, age >= 180 ? "⚠️ 疑似挂起（\(ageLabel)无响应）：\(actionText)" : actionText, workspace: workspace, stepIndex: stepIndex)
        }

        if lastType == "PLANNER_RESPONSE" && lastStatus == "DONE" {
            let summary = cleanSnippet(last["content"] as? String ?? "")
            let action = !summary.isEmpty ? summary
                : (!recentAction.isEmpty ? "已完成：\(recentAction)"
                : (!recentPrompt.isEmpty ? (isRunning ? "就绪 · 上次：\(recentPrompt)" : recentPrompt) : "任务已完成 · 等待新指令"))
            return build(.idle, action, workspace: workspace, stepIndex: stepIndex)
        }
        if (lastStatus == "ERROR" || lastType == "ERROR_MESSAGE") && isRunning && age < 600 {
            return build(.error, "步骤执行报错，请检查实例", workspace: workspace, stepIndex: stepIndex)
        }
        if lastType == "USER_INPUT" && isRunning {
            let prompt = cleanSnippet(last["content"] as? String ?? "")
            if age >= 600 { return build(.idle, prompt.isEmpty ? "等待新对话指令" : "就绪 · 上次：\(prompt)", workspace: workspace, stepIndex: stepIndex) }
            let stalled = age >= 120
            let action = stalled ? "⚠️ 疑似挂起（\(ageLabel)无响应）：\(prompt)" : (prompt.isEmpty ? "正在思考并规划任务…" : "正在处理：\(prompt)")
            return build(stalled ? .stalled : .runningTask, action, workspace: workspace, stepIndex: stepIndex)
        }
        if (lastType == "SYSTEM_MESSAGE" || lastType == "ERROR_MESSAGE") && isRunning {
            return build(.idle, recentAction.isEmpty ? "后台任务完成 · 等待新指令" : "已完成：\(recentAction)", workspace: workspace, stepIndex: stepIndex)
        }
        if lastType == "GENERIC" && isRunning {
            let doneDesc = !recentAction.isEmpty ? "已完成：\(recentAction)"
                : (!recentTarget.isEmpty ? "已完成：\(recentTarget)" : (!recentTool.isEmpty ? "完成 \(recentTool)" : "任务已完成 · 等待新指令"))
            if lastStatus == "RUNNING" {
                let desc = recentAction.isEmpty ? "正在后台执行任务…" : "正在执行：\(recentAction)"
                return build(age >= 180 ? .stalled : .runningTask, age >= 180 ? "⚠️ 疑似挂起（\(ageLabel)无响应）：\(desc)" : desc, workspace: workspace, stepIndex: stepIndex)
            }
            if age < 3 {
                return build(.runningTask, recentAction.isEmpty ? "操作已完成" : "完成操作：\(recentAction)", workspace: workspace, stepIndex: stepIndex)
            }
            return build(.idle, doneDesc, workspace: workspace, stepIndex: stepIndex)
        }
        if isRunning && lastStatus == "RUNNING" && age < 600 {
            let desc = recentAction.isEmpty ? "正在后台执行任务…" : "正在执行：\(recentAction)"
            return build(age >= 180 ? .stalled : .runningTask, age >= 180 ? "⚠️ 疑似挂起（\(ageLabel)无响应）：\(desc)" : desc, workspace: workspace, stepIndex: stepIndex)
        }

        let rawContent = last["content"] as? String ?? ""
        let isSystem = rawContent.hasPrefix("Created At:") || rawContent.hasPrefix("The following is a <SYSTEM_MESSAGE>")
            || rawContent.hasPrefix("[Message]") || ["GENERIC", "SYSTEM_MESSAGE", "ERROR_MESSAGE"].contains(lastType)
        let fallback = (!isSystem && !rawContent.isEmpty) ? cleanSnippet(rawContent)
            : (!recentAction.isEmpty ? "已完成：\(recentAction)"
            : (!recentPrompt.isEmpty ? (isRunning ? "就绪 · 上次：\(recentPrompt)" : recentPrompt) : "任务已完成 · 等待新指令"))
        return build(.idle, fallback, workspace: workspace, stepIndex: stepIndex)
    }

    private static func extractWorkspace(from steps: [[String: Any]]) -> String {
        for step in steps.reversed() {
            guard let tools = step["tool_calls"] as? [[String: Any]] else { continue }
            for tool in tools {
                guard let args = tool["args"] as? [String: Any] else { continue }
                for key in ["Cwd", "TargetFile", "AbsolutePath"] {
                    if let raw = args[key] as? String {
                        let cleaned = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                        guard cleaned.hasPrefix("/") else { continue }
                        let urlPath = URL(fileURLWithPath: cleaned)
                        let candidate = key == "Cwd" ? urlPath.lastPathComponent : urlPath.deletingLastPathComponent().lastPathComponent
                        if isValidWorkspaceCandidate(candidate, fullPath: cleaned) { return candidate }
                    }
                }
            }
        }
        return ""
    }

    private static func extractRecentToolInfo(from steps: [[String: Any]]) -> (name: String, action: String, target: String) {
        for step in steps.reversed() {
            guard let tools = step["tool_calls"] as? [[String: Any]], let first = tools.first else { continue }
            let name = first["name"] as? String ?? ""
            let args = first["args"] as? [String: Any]
            let action = (args?["toolAction"] as? String) ?? (args?["toolSummary"] as? String) ?? ""
            var target = ""
            if let path = (args?["TargetFile"] as? String) ?? (args?["AbsolutePath"] as? String) {
                target = URL(fileURLWithPath: path).lastPathComponent
            } else if let cmd = args?["CommandLine"] as? String, let firstPart = cmd.split(separator: " ").first {
                target = String(firstPart)
            }
            return (name, action, target)
        }
        return ("", "", "")
    }

    private static func withPreviousPrefix(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("就绪 · 上次：") {
            cleaned = String(cleaned.dropFirst("就绪 · ".count))
        }
        guard !cleaned.isEmpty else { return "" }
        while cleaned.hasPrefix("上次：") && cleaned.dropFirst(3).hasPrefix("上次：") {
            cleaned = String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !cleaned.hasPrefix("上次：") {
            return "上次：\(cleaned)"
        }
        return cleaned
    }

    private static func cleanSnippet(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "<USER_REQUEST>", with: "")
            .replacingOccurrences(of: "</USER_REQUEST>", with: "")
            .replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[#*`>-]+"#, with: " ", options: .regularExpression)
        let firstLine = stripped.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("Created At:") && !$0.hasPrefix("The current local time") } ?? ""
        return String(firstLine.prefix(48))
    }

    private static func isValidWorkspaceCandidate(_ name: String, fullPath: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "/" || trimmed.hasPrefix(".") || ["brain", "tmp", "scratch"].contains(trimmed) { return false }
        if UUID(uuidString: trimmed) != nil || (trimmed.count > 30 && trimmed.contains("-")) { return false }
        return !fullPath.contains("/.gemini") && !fullPath.contains("/brain/") && !fullPath.contains(".system_generated")
    }

    private static func formatRelativeAge(_ seconds: TimeInterval) -> String {
        if seconds < 15 { return "刚刚" }
        if seconds < 60 { return "\(Int(seconds))秒前" }
        if seconds < 3600 { return "\(Int(seconds / 60))分钟前" }
        if seconds < 86400 { return "\(Int(seconds / 3600))小时前" }
        return "\(Int(seconds / 86400))天前"
    }
}
