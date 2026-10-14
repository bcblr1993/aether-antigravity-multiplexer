import AppKit
import SwiftUI
import Sparkle
import WebKit
import UserNotifications
import Carbon
import Darwin

private let accent = Color.accentColor

// MARK: - Design System & Custom Styles

private struct GlassCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let radius: CGFloat
    var isHighlighted: Bool = false
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    } else {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.regularMaterial)
                    }
                    if let tint {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tint.opacity(colorScheme == .dark ? 0.08 : 0.05))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        isHighlighted
                            ? (tint ?? accent).opacity(colorScheme == .dark ? 0.55 : 0.45)
                            : Color.primary.opacity(colorScheme == .dark ? 0.11 : 0.08),
                        lineWidth: isHighlighted ? 1.2 : 1
                    )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? (isHighlighted ? 0.28 : 0.16) : (isHighlighted ? 0.08 : 0.03)),
                radius: isHighlighted ? 14 : 6,
                x: 0,
                y: isHighlighted ? 5 : 2
            )
    }
}

private extension View {
    func systemSurface(radius: CGFloat, isHighlighted: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(radius: radius, isHighlighted: isHighlighted, tint: tint))
    }
}

private struct ModernButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case upgrade
        case secondary
        case ghost
        case danger
    }

    let variant: Variant
    var compact: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        let buttonHeight: CGFloat = compact ? 30 : 34
        let radius: CGFloat = compact ? 8 : 9
        configuration.label
            .font(.system(size: compact ? 12 : 12.5, weight: variant == .primary || variant == .upgrade ? .semibold : .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, compact ? 11 : 14)
            .frame(height: buttonHeight)
            .foregroundStyle(foregroundColor)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(backgroundFill(pressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : (hovered && isEnabled ? 1.015 : 1.0))
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: hovered)
            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: configuration.isPressed)
            .onHover { hovered = $0 }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .upgrade:
            return .white
        case .danger:
            return hovered ? .white : .red
        case .secondary, .ghost:
            return .primary
        }
    }

    private func backgroundFill(pressed: Bool) -> AnyShapeStyle {
        switch variant {
        case .primary:
            let base = pressed ? accent.opacity(0.85) : (hovered ? accent.opacity(0.92) : accent)
            return AnyShapeStyle(
                LinearGradient(
                    colors: [base, base.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .upgrade:
            let top = Color(red: 0.16, green: 0.52, blue: 0.96)
            let bottom = Color(red: 0.36, green: 0.34, blue: 0.92)
            return AnyShapeStyle(
                LinearGradient(
                    colors: pressed ? [top.opacity(0.85), bottom.opacity(0.85)] : (hovered ? [top.opacity(0.95), bottom] : [top, bottom]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .danger:
            if pressed {
                return AnyShapeStyle(Color.red.opacity(0.85))
            } else if hovered {
                return AnyShapeStyle(Color.red)
            } else {
                return AnyShapeStyle(Color.red.opacity(colorScheme == .dark ? 0.15 : 0.10))
            }
        case .secondary:
            if pressed {
                return AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.12))
            } else if hovered {
                return AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.13 : 0.08))
            } else {
                return AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.045))
            }
        case .ghost:
            if pressed {
                return AnyShapeStyle(Color.primary.opacity(0.14))
            } else if hovered {
                return AnyShapeStyle(Color.primary.opacity(0.08))
            } else {
                return AnyShapeStyle(Color.clear)
            }
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary, .upgrade:
            return Color.white.opacity(0.22)
        case .danger:
            return Color.red.opacity(hovered ? 0.6 : 0.3)
        case .secondary:
            return Color.primary.opacity(hovered ? (colorScheme == .dark ? 0.22 : 0.16) : (colorScheme == .dark ? 0.12 : 0.09))
        case .ghost:
            return hovered ? Color.primary.opacity(0.10) : Color.clear
        }
    }
}

private struct IconActionButton: View {
    let symbol: String
    let tooltip: String
    var size: CGFloat = 30
    var rotation: Double = 0
    var badge: Int = 0
    var disabled: Bool = false
    let action: () -> Void
    @State private var hovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let radius: CGFloat = size > 30 ? 9 : 8
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: size > 30 ? 13.5 : 12.5, weight: .medium))
                    .rotationEffect(.degrees(rotation))
                    .frame(width: size, height: size, alignment: .center)
                    .foregroundStyle(hovered ? Color.primary : Color.secondary)
                    .background {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color.primary.opacity(hovered ? (colorScheme == .dark ? 0.14 : 0.08) : (colorScheme == .dark ? 0.06 : 0.035)))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(hovered ? 0.18 : 0.08), lineWidth: 1)
                    }
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(accent))
                        .offset(x: 4, y: -4)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(hovered && !disabled ? 1.04 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: hovered)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1.0)
        .help(tooltip)
        .onHover { hovered = $0 }
    }
}

private struct PulsingStatusDot: View {
    let active: Bool
    var activeColor: Color = .green
    var pulse: Bool = false
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(active ? activeColor : Color.secondary.opacity(0.45))
                .frame(width: 6, height: 6)

            if active && pulse {
                Circle()
                    .stroke(activeColor.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulsing ? 1.4 : 0.6)
                    .opacity(pulsing ? 0.0 : 0.85)
            }
        }
        .frame(width: 14, height: 14, alignment: .center)
        .drawingGroup()
        .onAppear {
            updateAnimation(shouldPulse: active && pulse)
        }
        .onChange(of: active && pulse) { shouldPulse in
            updateAnimation(shouldPulse: shouldPulse)
        }
    }

    private func updateAnimation(shouldPulse: Bool) {
        if shouldPulse {
            pulsing = false
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        } else {
            withAnimation(.linear(duration: 0.1)) {
                pulsing = false
            }
        }
    }
}

// MARK: - Data Models & Telemetry

enum TaskRunState: Equatable {
    case stopped
    case runningTask
    case needsAttention
    case idle
    case error

    var label: String {
        switch self {
        case .stopped: return "未启动"
        case .runningTask: return "任务执行中"
        case .needsAttention: return "等待确认"
        case .idle: return "空闲就绪"
        case .error: return "任务异常"
        }
    }

    var color: Color {
        switch self {
        case .stopped: return .secondary
        case .runningTask: return Color(red: 0.15, green: 0.82, blue: 0.96)
        case .needsAttention: return .orange
        case .idle: return .green
        case .error: return .red
        }
    }

    var symbol: String {
        switch self {
        case .stopped: return "poweroff"
        case .runningTask: return "bolt.horizontal.circle.fill"
        case .needsAttention: return "bell.badge.fill"
        case .idle: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

struct InstanceActivity: Equatable {
    var state: TaskRunState = .stopped
    var currentAction: String = "点击缩略图启动实例"
    var workspace: String = ""
    var lastUpdatedLabel: String = ""
    var stepIndex: Int = 0
    var latestConversationID: String = ""

    static let stopped = InstanceActivity()
}

struct InstanceUserMeta: Codable, Equatable, Hashable {
    var nickname: String = ""
    var tag: String = ""
    var tagColor: String = "blue"
    var notes: String = ""

    var hasCustomContent: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var color: Color {
        switch tagColor {
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        default: return .blue
        }
    }
}

struct InstanceDiskUsage: Equatable {
    var profileBytes: Int64 = 0
    var userDataBytes: Int64 = 0
    var appBundleBytes: Int64 = 0
    var lastCalculated: Date? = nil

    var totalDataBytes: Int64 {
        profileBytes + userDataBytes
    }

    var totalBytes: Int64 {
        profileBytes + userDataBytes + appBundleBytes
    }

    var formattedProfile: String { Self.formatBytes(profileBytes) }
    var formattedUserData: String { Self.formatBytes(userDataBytes) }
    var formattedAppBundle: String { Self.formatBytes(appBundleBytes) }
    var formattedTotalData: String { Self.formatBytes(totalDataBytes) }
    var formattedTotal: String { Self.formatBytes(totalBytes) }

    static func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1.0 {
            return "\(Int(kb)) KB"
        } else {
            return "\(bytes) B"
        }
    }
}

struct InstanceResourceMetric: Equatable {
    var cpuPercent: Double = 0.0
    var rssBytes: Int64 = 0
    var processCount: Int = 0

    var memoryLabel: String {
        guard rssBytes > 0 else { return "0 MB" }
        let mb = Double(rssBytes) / (1024.0 * 1024.0)
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024.0)
        } else {
            return "\(Int(mb)) MB"
        }
    }

    var cpuLabel: String {
        String(format: "%.1f%%", cpuPercent)
    }

    static func == (lhs: InstanceResourceMetric, rhs: InstanceResourceMetric) -> Bool {
        lhs.processCount == rhs.processCount &&
        lhs.memoryLabel == rhs.memoryLabel &&
        lhs.cpuLabel == rhs.cpuLabel &&
        (lhs.cpuPercent > 15) == (rhs.cpuPercent > 15)
    }
}

enum TaskHistoryCategory: String, Codable, CaseIterable {
    case completed
    case needsAttention
    case error

    var label: String {
        switch self {
        case .completed: return "已完成"
        case .needsAttention: return "等待确认"
        case .error: return "执行异常"
        }
    }

    var color: Color {
        switch self {
        case .completed: return .green
        case .needsAttention: return .orange
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .needsAttention: return "bell.badge.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

struct TaskHistoryItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var instanceID: String
    var instanceName: String
    var instanceNickname: String
    var isOriginal: Bool
    var category: TaskHistoryCategory
    var actionSummary: String
    var workspace: String
    var stepIndex: Int
    var timestamp: Date
    var durationSeconds: TimeInterval?

    var displayName: String {
        let base = instanceNickname.isEmpty ? instanceName : "\(instanceNickname) (\(instanceName))"
        return isOriginal ? "👑 \(base)" : base
    }

    var formattedDuration: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        let total = Int(durationSeconds)
        if total < 60 {
            return "\(max(1, total)) 秒"
        } else {
            let mins = total / 60
            let secs = total % 60
            return secs > 0 ? "\(mins) 分 \(secs) 秒" : "\(mins) 分钟"
        }
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var relativeTime: String {
        let elapsed = Date().timeIntervalSince(timestamp)
        if elapsed < 60 { return "刚刚" }
        if elapsed < 3600 { return "\(Int(elapsed / 60)) 分钟前" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600)) 小时前" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: timestamp)
    }
}

extension Notification.Name {
    static let openTaskHistoryRequested = Notification.Name("openTaskHistoryRequested")
}

struct ManagedInstance: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let bundleID: String
    let version: String
    let index: Int
    let running: Bool
    let isHidden: Bool
    let verified: Bool
    var isOriginal: Bool { bundleID == "com.google.antigravity" }
    var profile: String { isOriginal ? "~/.gemini" : "~/.gemini-\(max(index - 1, 1))" }
    var profileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(isOriginal ? ".gemini" : ".gemini-\(max(index - 1, 1))")
    }
    var userDataURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(isOriginal ? "Antigravity" : name)
    }
    var logsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
            .appendingPathComponent(isOriginal ? "Antigravity" : name)
    }
    var callbackScheme: String {
        if isOriginal { return "antigravity" }
        if index >= 8 { return "antigravity-\(index)" }
        let parts = name.split(separator: " ", maxSplits: 1)
        return parts.count > 1 ? "antigravity-\(parts[1].lowercased())" : "antigravity-\(index)"
    }
}

struct SourceReleaseNotes: Decodable, Identifiable {
    let version: String
    let highlights: [String]
    var id: String { version }
    static let bundled: [SourceReleaseNotes] = {
        guard let url = Bundle.main.url(forResource: "source_release_notes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let notes = try? JSONDecoder().decode([SourceReleaseNotes].self, from: data) else { return [] }
        return notes
    }()
}

struct BackupBatch: Decodable, Identifiable {
    let name: String
    let archiveCount: Int
    let bytes: Int64
    let referenced: Bool
    let deletable: Bool
    var id: String { name }
    var dateLabel: String {
        let characters = Array(name)
        guard characters.count == 22 else { return name }
        return "\(String(characters[0..<4]))-\(String(characters[4..<6]))-\(String(characters[6..<8])) " +
               "\(String(characters[9..<11])):\(String(characters[11..<13])):\(String(characters[13..<15]))"
    }
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}

// MARK: - Native Kernel Process Metrics (Darwin libproc / proc_pidinfo)

enum NativeProcessMonitor {
    private static var previousSamples: [String: (timestamp: Date, totalCpuNanos: UInt64)] = [:]
    private static let lock = NSLock()

    /// Collects all descendant process IDs rooted at `root` using Darwin's native `proc_listchildpids`.
    /// Traverses the Electron process tree (main -> helper/gpu/utility/renderer/language_server) in < 0.1ms.
    static func getProcessTreePids(root: pid_t) -> [pid_t] {
        guard root > 0 else { return [] }
        var pids: [pid_t] = [root]
        var queue: [pid_t] = [root]
        var visited = Set<pid_t>([root])

        while !queue.isEmpty {
            let parent = queue.removeFirst()
            var buffer = [pid_t](repeating: 0, count: 512)
            let count = Int(proc_listchildpids(parent, &buffer, Int32(MemoryLayout<pid_t>.stride * 512)))
            if count > 0 {
                for i in 0..<count {
                    let child = buffer[i]
                    if child > 0 && !visited.contains(child) {
                        visited.insert(child)
                        queue.append(child)
                        pids.append(child)
                    }
                }
            }
        }
        return pids
    }

    /// Direct kernel sampling of process tree total CPU time (nanoseconds), resident memory (bytes), and live process count.
    static func sampleTree(root: pid_t) -> (cpuNanos: UInt64, rssBytes: Int64, processCount: Int)? {
        guard root > 0 else { return nil }
        let pids = getProcessTreePids(root: root)
        guard !pids.isEmpty else { return nil }

        var totalCpu: UInt64 = 0
        var totalRss: Int64 = 0
        var validCount = 0

        for pid in pids {
            var ti = proc_taskinfo()
            let r = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &ti, Int32(MemoryLayout<proc_taskinfo>.stride))
            if r > 0 {
                totalCpu += (ti.pti_total_user + ti.pti_total_system)
                totalRss += Int64(ti.pti_resident_size)
                validCount += 1
            }
        }

        guard validCount > 0 else { return nil }
        return (totalCpu, totalRss, validCount)
    }

    /// Scans resource metrics using Darwin native C APIs with zero subprocess forks, zero Mach task creation, and zero pipe I/O.
    static func scanResourceMetrics(
        instances: [ManagedInstance],
        runningAppPids: [String: pid_t] = [:]
    ) -> [String: InstanceResourceMetric] {
        var results: [String: InstanceResourceMetric] = [:]
        let now = Date()

        lock.lock()
        defer { lock.unlock() }

        let runningItems = instances.filter(\.running)
        guard !runningItems.isEmpty else {
            previousSamples.removeAll()
            return results
        }

        let runningIDs = Set(runningItems.map(\.id))
        previousSamples = previousSamples.filter { runningIDs.contains($0.key) }

        for item in runningItems {
            let rootPid: pid_t? = {
                if let pid = runningAppPids[item.id], pid > 0 { return pid }
                let apps = NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID).filter { !$0.isTerminated }
                if let match = apps.first(where: { app in
                    guard let bURL = app.bundleURL else { return true }
                    return bURL.resolvingSymlinksInPath().standardizedFileURL == item.path.resolvingSymlinksInPath().standardizedFileURL
                }) {
                    return match.processIdentifier
                }
                return apps.first?.processIdentifier
            }()

            guard let root = rootPid, let sample = sampleTree(root: root) else { continue }

            var cpuPercent = 0.0
            if let prev = previousSamples[item.id] {
                let dt = now.timeIntervalSince(prev.timestamp)
                if dt >= 0.5 {
                    let dCpu = sample.cpuNanos >= prev.totalCpuNanos ? (sample.cpuNanos - prev.totalCpuNanos) : 0
                    cpuPercent = (Double(dCpu) / (dt * 1_000_000_000.0)) * 100.0
                    cpuPercent = min(max(cpuPercent, 0.0), Double(sample.processCount) * 100.0)
                }
            }
            previousSamples[item.id] = (timestamp: now, totalCpuNanos: sample.cpuNanos)

            results[item.id] = InstanceResourceMetric(
                cpuPercent: cpuPercent,
                rssBytes: sample.rssBytes,
                processCount: sample.processCount
            )
        }

        // If for any rare reason libproc returned empty for running instances, fallback to ps
        if results.isEmpty && !runningItems.isEmpty {
            return fallbackScanResourceMetricsViaPS(instances: instances)
        }

        return results
    }

    /// Safe fallback using /bin/ps in case kernel security policy blocks libproc
    private static func fallbackScanResourceMetricsViaPS(instances: [ManagedInstance]) -> [String: InstanceResourceMetric] {
        var results: [String: InstanceResourceMetric] = [:]
        let runningItems = instances.filter(\.running)
        guard !runningItems.isEmpty else { return results }

        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-A", "-o", "pid,ppid,%cpu,rss,command"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return results }

            let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            guard lines.count > 1 else { return results }

            let sortedByLength = runningItems.sorted { $0.name.count > $1.name.count }

            for line in lines.dropFirst() {
                let parts = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
                guard parts.count >= 5,
                      let cpu = Double(parts[2]),
                      let rssKB = Int64(parts[3]) else { continue }
                let cmd = String(parts[4])

                for item in sortedByLength {
                    let name = item.name
                    let nameNoSpace = name.lowercased().replacingOccurrences(of: " ", with: "")
                    var isMatch = false

                    if cmd.contains("/Applications/\(name).app") || cmd.contains("/Applications/\(name) ") {
                        isMatch = true
                    } else if cmd.contains("--user-data-dir=") && cmd.contains("/\(name)") {
                        isMatch = true
                    } else if cmd.contains("--app_data_dir \(nameNoSpace)") {
                        isMatch = true
                    } else if item.isOriginal && (cmd.contains("--app_data_dir antigravity ") || (cmd.contains("/Applications/Antigravity.app") && !cmd.contains("Antigravity Second") && !cmd.contains("Antigravity Third") && !cmd.contains("Antigravity Fourth") && !cmd.contains("Antigravity Fifth") && !cmd.contains("Antigravity Sixth") && !cmd.contains("Antigravity Seventh") && !cmd.contains("Antigravity Eighth"))) {
                        isMatch = true
                    }

                    if isMatch {
                        var metric = results[item.id] ?? InstanceResourceMetric()
                        metric.cpuPercent += cpu
                        metric.rssBytes += rssKB * 1024
                        metric.processCount += 1
                        results[item.id] = metric
                        break
                    }
                }
            }
        } catch {}
        return results
    }
}

// MARK: - Background Transcript & Window Scanner

private enum TelemetryScanner {
    // Cache stopped instance activity so stopped instances never repeatedly hit disk
    private static var stoppedActivityCache: [String: InstanceActivity] = [:]
    // Cache last known transcript location per profile URL
    private static var lastKnownTranscripts: [URL: (url: URL, date: Date, convID: String)] = [:]

    static func scan(instances: [ManagedInstance], knownConvIDs: [String: String] = [:]) -> [String: InstanceActivity] {
        var results: [String: InstanceActivity] = [:]
        for item in instances {
            if !item.running {
                // If instance is stopped, reuse cached stopped activity without disk traversal
                if let cached = stoppedActivityCache[item.id] {
                    results[item.id] = cached
                    continue
                }
                var stopped = InstanceActivity.stopped
                if let latest = findTranscript(in: item.profileURL, knownConvID: knownConvIDs[item.id]) {
                    let parsed = parseTranscriptTail(at: latest.url, modDate: latest.date, isRunning: false, convID: latest.convID)
                    stopped.workspace = parsed.workspace
                    stopped.lastUpdatedLabel = parsed.lastUpdatedLabel
                    if !parsed.currentAction.isEmpty {
                        stopped.currentAction = "上次：\(parsed.currentAction)"
                    }
                }
                stoppedActivityCache[item.id] = stopped
                results[item.id] = stopped
            } else {
                stoppedActivityCache.removeValue(forKey: item.id)
                if let latest = findTranscript(in: item.profileURL, knownConvID: knownConvIDs[item.id]) {
                    results[item.id] = parseTranscriptTail(at: latest.url, modDate: latest.date, isRunning: true, convID: latest.convID)
                } else {
                    results[item.id] = InstanceActivity(
                        state: .idle,
                        currentAction: "等待新对话指令",
                        workspace: item.profile,
                        lastUpdatedLabel: "刚刚",
                        stepIndex: 0
                    )
                }
            }
        }
        return results
    }

    private static func findTranscript(in profileURL: URL, knownConvID: String?) -> (url: URL, date: Date, convID: String)? {
        let fm = FileManager.default

        // 1. Direct Hit: If we know the active conversation ID from CDP URL (e.g. /c/<uuid>), check directly!
        if let knownConvID, !knownConvID.isEmpty {
            if let topDirs = try? fm.contentsOfDirectory(at: profileURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for dir in topDirs {
                    let directTranscript = dir.appendingPathComponent("brain")
                        .appendingPathComponent(knownConvID)
                        .appendingPathComponent(".system_generated/logs/transcript.jsonl")
                    if let values = try? directTranscript.resourceValues(forKeys: [.contentModificationDateKey]),
                       let modDate = values.contentModificationDate {
                        let res = (directTranscript, modDate, knownConvID)
                        lastKnownTranscripts[profileURL] = res
                        return res
                    }
                }
            }
        }

        // 2. Cache Hit: If cached transcript was recently updated (< 30 seconds ago), avoid directory traversal
        if let cached = lastKnownTranscripts[profileURL] {
            if let values = try? cached.url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate {
                if abs(modDate.timeIntervalSinceNow) < 30 {
                    let updated = (cached.url, modDate, cached.convID)
                    lastKnownTranscripts[profileURL] = updated
                    return updated
                }
            }
        }

        // 3. Fallback: Scan directories and update cache
        if let latest = latestTranscript(in: profileURL) {
            lastKnownTranscripts[profileURL] = latest
            return latest
        }
        return nil
    }

    static func scanResourceMetrics(
        instances: [ManagedInstance],
        runningAppPids: [String: pid_t] = [:]
    ) -> [String: InstanceResourceMetric] {
        NativeProcessMonitor.scanResourceMetrics(instances: instances, runningAppPids: runningAppPids)
    }

    static func calculateFolderBytes(at url: URL) -> Int64 {
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        proc.arguments = ["-sk", url.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8),
               let firstWord = str.components(separatedBy: .whitespaces).first,
               let kb = Int64(firstWord) {
                return kb * 1024
            }
        } catch {}
        return 0
    }

    static func scanDiskUsage(for item: ManagedInstance) -> InstanceDiskUsage {
        let profileBytes = calculateFolderBytes(at: item.profileURL)
        let userDataBytes = calculateFolderBytes(at: item.userDataURL) + calculateFolderBytes(at: item.logsURL)
        let appBundleBytes = calculateFolderBytes(at: item.path)
        return InstanceDiskUsage(
            profileBytes: profileBytes,
            userDataBytes: userDataBytes,
            appBundleBytes: appBundleBytes,
            lastCalculated: Date()
        )
    }

    static func scanDiskUsages(instances: [ManagedInstance]) -> [String: InstanceDiskUsage] {
        var results: [String: InstanceDiskUsage] = [:]
        for item in instances {
            results[item.id] = scanDiskUsage(for: item)
        }
        return results
    }

    private static func latestTranscript(in profileURL: URL) -> (url: URL, date: Date, convID: String)? {
        let fm = FileManager.default
        guard let topDirs = try? fm.contentsOfDirectory(at: profileURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return nil
        }
        var newestURL: URL?
        var newestDate: Date = .distantPast
        var newestConvID = ""
        for dir in topDirs {
            let brainDir = dir.appendingPathComponent("brain")
            guard let convDirs = try? fm.contentsOfDirectory(at: brainDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            for conv in convDirs {
                let transcript = conv.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                guard let values = try? transcript.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modDate = values.contentModificationDate else { continue }
                if modDate > newestDate {
                    newestDate = modDate
                    newestURL = transcript
                    newestConvID = conv.lastPathComponent
                }
            }
        }
        if let newestURL { return (newestURL, newestDate, newestConvID) }
        return nil
    }

    private static func parseTranscriptTail(at url: URL, modDate: Date, isRunning: Bool, convID: String) -> InstanceActivity {
        let age = max(0, Date().timeIntervalSince(modDate))
        let ageLabel = formatRelativeAge(age)
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return InstanceActivity(state: isRunning ? .idle : .stopped, currentAction: "已启动就绪", workspace: "", lastUpdatedLabel: ageLabel)
        }
        defer { try? handle.close() }
        let fileSize = (try? handle.seekToEnd()) ?? 0
        let readBytes: UInt64 = min(fileSize, 32_768)
        try? handle.seek(toOffset: fileSize - readBytes)
        let data = handle.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            return InstanceActivity(state: isRunning ? .idle : .stopped, currentAction: "已启动就绪", workspace: "", lastUpdatedLabel: ageLabel)
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        let tailLines = lines.suffix(8)
        var parsedSteps: [[String: Any]] = []
        for line in tailLines {
            if let lineData = line.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                parsedSteps.append(obj)
            }
        }
        guard let last = parsedSteps.last else {
            return InstanceActivity(state: isRunning ? .idle : .stopped, currentAction: "等待新对话指令", workspace: "", lastUpdatedLabel: ageLabel)
        }

        // Extract workspace name from recent tool calls (excluding internal brain/gemini/UUID paths)
        var workspace = ""
        for step in parsedSteps.reversed() {
            if let tools = step["tool_calls"] as? [[String: Any]] {
                for tool in tools {
                    if let args = tool["args"] as? [String: Any] {
                        for key in ["Cwd", "TargetFile", "AbsolutePath"] {
                            if let raw = args[key] as? String {
                                let cleaned = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                                if cleaned.hasPrefix("/") {
                                    let urlPath = URL(fileURLWithPath: cleaned)
                                    let candidate = key == "Cwd" ? urlPath.lastPathComponent : urlPath.deletingLastPathComponent().lastPathComponent
                                    if isValidWorkspaceCandidate(candidate, fullPath: cleaned) {
                                        workspace = candidate
                                        break
                                    }
                                }
                            }
                        }
                    }
                    if !workspace.isEmpty { break }
                }
            }
            if !workspace.isEmpty { break }
        }

        let stepIndex = last["step_index"] as? Int ?? 0
        let lastType = last["type"] as? String ?? ""
        let lastStatus = last["status"] as? String ?? ""
        let hasRunningStep = parsedSteps.contains { ($0["status"] as? String) == "RUNNING" }

        func withConv(_ act: InstanceActivity) -> InstanceActivity {
            var a = act
            a.latestConversationID = convID
            return a
        }

        // Find most recent tool call info from tail steps
        var recentToolName = ""
        var recentToolAction = ""
        var recentTargetName = ""
        for step in parsedSteps.reversed() {
            if let tools = step["tool_calls"] as? [[String: Any]], let first = tools.first {
                recentToolName = first["name"] as? String ?? ""
                if let args = first["args"] as? [String: Any] {
                    recentToolAction = (args["toolAction"] as? String) ?? (args["toolSummary"] as? String) ?? ""
                    if let target = (args["TargetFile"] as? String) ?? (args["AbsolutePath"] as? String) {
                        recentTargetName = URL(fileURLWithPath: target).lastPathComponent
                    } else if let cmd = args["CommandLine"] as? String {
                        let cmdParts = cmd.split(separator: " ", omittingEmptySubsequences: true)
                        if let firstPart = cmdParts.first {
                            recentTargetName = String(firstPart)
                        }
                    }
                }
                break
            }
        }

        // Find most recent user prompt from tail steps
        var recentUserPrompt = ""
        for step in parsedSteps.reversed() {
            if (step["type"] as? String) == "USER_INPUT",
               let content = step["content"] as? String {
                let cleaned = cleanSnippet(content)
                if !cleaned.isEmpty {
                    recentUserPrompt = cleaned
                    break
                }
            }
        }

        // Extract latest human-readable action or message
        var actionText = ""
        if let tools = last["tool_calls"] as? [[String: Any]], let firstTool = tools.first {
            let toolName = firstTool["name"] as? String ?? "tool"
            if let args = firstTool["args"] as? [String: Any] {
                let rawAction = (args["toolAction"] as? String) ?? (args["toolSummary"] as? String) ?? ""
                actionText = rawAction.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            }
            if actionText.isEmpty {
                if !recentTargetName.isEmpty {
                    actionText = "操作 \(recentTargetName)"
                } else {
                    actionText = "调用工具 \(toolName)"
                }
            }
            if isRunning && toolName == "ask_question" && age < 1800 {
                return withConv(InstanceActivity(
                    state: .needsAttention,
                    currentAction: "等待确认：\(actionText)",
                    workspace: workspace,
                    lastUpdatedLabel: ageLabel,
                    stepIndex: stepIndex
                ))
            }
            if isRunning && age < 240 {
                return withConv(InstanceActivity(
                    state: .runningTask,
                    currentAction: actionText,
                    workspace: workspace,
                    lastUpdatedLabel: ageLabel,
                    stepIndex: stepIndex
                ))
            }
        }

        if isRunning && hasRunningStep && age < 600 {
            let runningDesc = !actionText.isEmpty ? actionText : (!recentToolAction.isEmpty ? "正在执行：\(recentToolAction)" : "正在后台执行任务…")
            return withConv(InstanceActivity(
                state: .runningTask,
                currentAction: runningDesc,
                workspace: workspace,
                lastUpdatedLabel: ageLabel,
                stepIndex: stepIndex
            ))
        }

        if isRunning && age < 180 {
            if lastType == "USER_INPUT" {
                let prompt = cleanSnippet(last["content"] as? String ?? "")
                return withConv(InstanceActivity(
                    state: .runningTask,
                    currentAction: prompt.isEmpty ? "正在思考并规划任务…" : "正在处理：\(prompt)",
                    workspace: workspace,
                    lastUpdatedLabel: ageLabel,
                    stepIndex: stepIndex
                ))
            } else if lastType == "GENERIC" {
                let genericAction: String
                if !recentToolAction.isEmpty {
                    genericAction = "分析结果：\(recentToolAction)"
                } else if !recentTargetName.isEmpty {
                    genericAction = "分析结果：\(recentTargetName)"
                } else if !recentToolName.isEmpty {
                    genericAction = "处理 \(recentToolName) 输出"
                } else if !recentUserPrompt.isEmpty {
                    genericAction = "正在处理：\(recentUserPrompt)"
                } else {
                    genericAction = "正在规划下一步操作…"
                }
                return withConv(InstanceActivity(
                    state: .runningTask,
                    currentAction: genericAction,
                    workspace: workspace,
                    lastUpdatedLabel: ageLabel,
                    stepIndex: stepIndex
                ))
            }
        }

        if lastStatus == "ERROR" && isRunning && age < 600 {
            return withConv(InstanceActivity(
                state: .error,
                currentAction: "步骤执行报错，请检查实例",
                workspace: workspace,
                lastUpdatedLabel: ageLabel,
                stepIndex: stepIndex
            ))
        }

        let summary = cleanSnippet(last["content"] as? String ?? "")
        let displayAction: String
        if !summary.isEmpty {
            displayAction = summary
        } else if !recentToolAction.isEmpty {
            displayAction = "已完成：\(recentToolAction)"
        } else if !recentUserPrompt.isEmpty {
            displayAction = "就绪 · 上次：\(recentUserPrompt)"
        } else {
            displayAction = "任务已完成 · 等待新指令"
        }
        return withConv(InstanceActivity(
            state: isRunning ? .idle : .stopped,
            currentAction: displayAction,
            workspace: workspace,
            lastUpdatedLabel: ageLabel,
            stepIndex: stepIndex
        ))
    }

    private static func cleanSnippet(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "<USER_REQUEST>", with: "")
            .replacingOccurrences(of: "</USER_REQUEST>", with: "")
            .replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[#*`>-]+"#, with: " ", options: .regularExpression)
        let firstLine = stripped
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("Created At:") && !$0.hasPrefix("The current local time") } ?? ""
        return String(firstLine.prefix(48))
    }

    private static func isValidWorkspaceCandidate(_ name: String, fullPath: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "/" || trimmed.hasPrefix(".") || trimmed == "brain" || trimmed == "tmp" || trimmed == "scratch" {
            return false
        }
        if UUID(uuidString: trimmed) != nil { return false }
        if trimmed.count > 30 && trimmed.contains("-") { return false }
        if fullPath.contains("/.gemini") || fullPath.contains("/brain/") || fullPath.contains(".system_generated") {
            return false
        }
        return true
    }

    private static func formatRelativeAge(_ seconds: TimeInterval) -> String {
        if seconds < 15 { return "刚刚" }
        if seconds < 60 { return "\(Int(seconds))秒前" }
        if seconds < 3600 { return "\(Int(seconds / 60))分钟前" }
        if seconds < 86400 { return "\(Int(seconds / 3600))小时前" }
        return "\(Int(seconds / 86400))天前"
    }
}

// MARK: - Notification Delegate

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let targetBundle = (userInfo["bundleID"] as? String) ?? (userInfo["instanceID"] as? String)
        if let targetBundle {
            Task { @MainActor in
                InstanceStore.current?.openInstance(byBundleID: targetBundle)
            }
        }
        completionHandler()
    }
}

// MARK: - Instance Store & Window / HUD Coordinator

@MainActor final class InstanceStore: ObservableObject {
    static weak var current: InstanceStore?

    @Published var instances: [ManagedInstance] = []
    @Published var activities: [String: InstanceActivity] = [:]
    @Published var thumbnails: [String: NSImage] = [:]
    @Published var backups: [BackupBatch] = []
    @Published var busy = false
    @Published var output = ""
    @Published var error: String?
    @Published var sourceVersion = "—"
    @Published var compatibility = "检查中"
    @Published var hasScreenCapturePermission = false
    @Published var soloFocusMode: Bool = UserDefaults.standard.object(forKey: "soloFocusMode") as? Bool ?? false {
        didSet { UserDefaults.standard.set(soloFocusMode, forKey: "soloFocusMode") }
    }
    @Published var floatingHUDEnabled: Bool = UserDefaults.standard.object(forKey: "floatingHUDEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(floatingHUDEnabled, forKey: "floatingHUDEnabled")
            updateFloatingHUDVisibility()
        }
    }
    @Published var notificationsEnabled: Bool = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var globalHotkeysEnabled: Bool = UserDefaults.standard.object(forKey: "globalHotkeysEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(globalHotkeysEnabled, forKey: "globalHotkeysEnabled")
            updateGlobalHotkeysRegistration()
        }
    }
    @Published var dockBadgeEnabled: Bool = UserDefaults.standard.object(forKey: "dockBadgeEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(dockBadgeEnabled, forKey: "dockBadgeEnabled")
            updateDockBadge()
        }
    }
    @Published var activeInstanceName: String? = nil
    @Published var activeConversationURLs: [String: String] = [:]
    @Published var resourceMetrics: [String: InstanceResourceMetric] = [:]
    @Published var instanceMetas: [String: InstanceUserMeta] = [:]
    @Published var diskUsages: [String: InstanceDiskUsage] = [:]
    @Published var taskHistory: [TaskHistoryItem] = []

    private var taskStartTimes: [String: Date] = [:]
    var taskHistoryFileURL: URL {
        support.appendingPathComponent("task_history.json")
    }
    var unreadAttentionCount: Int {
        instances.filter { $0.running && activities[$0.id]?.state == .needsAttention }.count
    }

    var hudPanel: NSPanel?
    private var quickSwitcherPanel: QuickSwitcherPanel?
    private var statusItem: NSStatusItem?
    private var lastOpenWindowBundles: Set<String> = []
    private var lastFrontmostAntigravityBundle: String? = nil
    private var hasInitializedActivityBaseline = false
    private var lastNotifiedStates: [String: (state: TaskRunState, stepIndex: Int)] = [:]
    private var lastOpenTime: [String: Date] = [:]
    private var isScanningTelemetry = false
    private var telemetryTickCount: Int = 0

    func saveHUDPosition(origin: NSPoint) {
        UserDefaults.standard.set(Double(origin.x), forKey: "floatingHUD_x")
        UserDefaults.standard.set(Double(origin.y), forKey: "floatingHUD_y")
    }

    func moveHUD(by translation: CGSize, startOrigin: NSPoint) {
        guard let panel = hudPanel else { return }
        let newX = startOrigin.x + translation.width
        let newY = startOrigin.y - translation.height
        panel.setFrameOrigin(NSPoint(x: newX, y: newY))
    }

    private let support = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Antigravity Multiplexer")
    private let supportedVersions: Set<String> = {
        guard let url = Bundle.main.url(forResource: "compatibility", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return Set(records.keys)
    }()
    private let names = ["Second": 2, "Third": 3, "Fourth": 4, "Fifth": 5, "Sixth": 6, "Seventh": 7, "Eighth": 8]

    init() {
        Self.current = self
        hasScreenCapturePermission = CGPreflightScreenCaptureAccess()
        loadInstanceMetas()
        loadTaskHistory()
        setupStatusBarItem()
        setupNotifications()
        setupGlobalHotKeys()
        updateDockBadge()
    }

    func meta(for item: ManagedInstance) -> InstanceUserMeta {
        instanceMetas[item.id] ?? InstanceUserMeta()
    }

    func metric(for item: ManagedInstance) -> InstanceResourceMetric {
        resourceMetrics[item.id] ?? InstanceResourceMetric()
    }

    func diskUsage(for item: ManagedInstance) -> InstanceDiskUsage {
        diskUsages[item.id] ?? InstanceDiskUsage()
    }

    var totalDiskUsageBytes: Int64 {
        instances.reduce(0) { $0 + (diskUsages[$1.id]?.totalDataBytes ?? 0) }
    }

    var formattedTotalDiskUsage: String {
        InstanceDiskUsage.formatBytes(totalDiskUsageBytes)
    }

    func recalculateDiskUsage(for item: ManagedInstance) {
        Task.detached(priority: .utility) {
            let usage = TelemetryScanner.scanDiskUsage(for: item)
            await MainActor.run { [weak self] in
                self?.diskUsages[item.id] = usage
            }
        }
    }

    func refreshDiskUsages() {
        let snapshot = instances
        guard !snapshot.isEmpty else { return }
        Task.detached(priority: .utility) {
            let usages = TelemetryScanner.scanDiskUsages(instances: snapshot)
            await MainActor.run { [weak self] in
                self?.diskUsages = usages
            }
        }
    }

    func revealProfile(_ item: ManagedInstance) {
        let path = item.profileURL.path
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        } else {
            error = "工作空间目录尚未生成（\(path)）"
        }
    }

    func revealUserData(_ item: ManagedInstance) {
        let path = item.userDataURL.path
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        } else {
            error = "应用数据目录尚未生成（\(path)）"
        }
    }

    private func loadInstanceMetas() {
        if let data = UserDefaults.standard.data(forKey: "instance_user_metas"),
           let decoded = try? JSONDecoder().decode([String: InstanceUserMeta].self, from: data) {
            instanceMetas = decoded
        }
    }

    func saveInstanceMeta(for itemID: String, meta: InstanceUserMeta) {
        if meta.hasCustomContent {
            instanceMetas[itemID] = meta
        } else {
            instanceMetas.removeValue(forKey: itemID)
        }
        if let encoded = try? JSONEncoder().encode(instanceMetas) {
            UserDefaults.standard.set(encoded, forKey: "instance_user_metas")
        }
    }

    func loadTaskHistory() {
        guard FileManager.default.fileExists(atPath: taskHistoryFileURL.path),
              let data = try? Data(contentsOf: taskHistoryFileURL),
              let items = try? JSONDecoder().decode([TaskHistoryItem].self, from: data) else {
            taskHistory = []
            return
        }
        taskHistory = items
    }

    func saveTaskHistory() {
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(taskHistory) {
            try? data.write(to: taskHistoryFileURL, options: .atomic)
        }
    }

    func recordTaskEvent(
        item: ManagedInstance,
        category: TaskHistoryCategory,
        action: String,
        workspace: String,
        stepIndex: Int,
        duration: TimeInterval?
    ) {
        let meta = meta(for: item)
        let event = TaskHistoryItem(
            instanceID: item.id,
            instanceName: item.name,
            instanceNickname: meta.nickname,
            isOriginal: item.isOriginal,
            category: category,
            actionSummary: action,
            workspace: workspace,
            stepIndex: stepIndex,
            timestamp: Date(),
            durationSeconds: duration
        )
        taskHistory.insert(event, at: 0)
        if taskHistory.count > 200 {
            taskHistory = Array(taskHistory.prefix(200))
        }
        saveTaskHistory()
        updateStatusBarMenu()
    }

    func clearTaskHistory() {
        taskHistory.removeAll()
        saveTaskHistory()
        updateStatusBarMenu()
    }

    func exportTaskHistory() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var md = "# Antigravity Multiplexer 任务动态历史记录\n\n"
        md += "- 导出时间: \(dateFormatter.string(from: Date()))\n"
        md += "- 记录总数: \(taskHistory.count) 条\n\n"
        md += "| 时间 | 实例 | 类型 | 耗时 | 工作区 | 任务详情 |\n"
        md += "| :--- | :--- | :--- | :--- | :--- | :--- |\n"

        for item in taskHistory {
            let dur = item.formattedDuration ?? "—"
            let ws = item.workspace.isEmpty ? "—" : "`\(item.workspace)`"
            let action = item.actionSummary.replacingOccurrences(of: "|", with: "\\|")
            md += "| \(item.formattedTime) | \(item.displayName) | \(item.category.label) | \(dur) | \(ws) | \(action) |\n"
        }

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? support
        let fileURL = desktop.appendingPathComponent("Antigravity-Task-History-\(Int(Date().timeIntervalSince1970)).md")
        do {
            try md.write(to: fileURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: desktop.path)
            return fileURL
        } catch {
            self.error = "导出历史失败：\(error.localizedDescription)"
            return nil
        }
    }

    func runningDuration(for item: ManagedInstance) -> String? {
        guard item.running,
              activities[item.id]?.state == .runningTask,
              let start = taskStartTimes[item.id] else { return nil }
        let elapsed = Int(Date().timeIntervalSince(start))
        if elapsed < 60 {
            return "\(max(1, elapsed))s"
        } else {
            let m = elapsed / 60
            let s = elapsed % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
    }

    private func isInstanceCollapsed(_ app: NSRunningApplication?) -> Bool {
        guard let app else { return false }
        return app.isHidden || app.activationPolicy != .regular
    }

    /// Ensures `"runInBackground": "true"` in `~/Library/Application Support/<InstanceName>/app_storage.json`
    /// so clicking the macOS red close button (✕) never quits the instance or interrupts running Agent tasks,
    /// and instead detaches the window and hides its Dock icon (`app.dock.hide()`).
    private func enforceRunInBackgroundSetting(for items: [ManagedInstance]) {
        let appSupportRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
        for item in items {
            let dir = appSupportRoot.appendingPathComponent(item.name)
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            let storageFile = dir.appendingPathComponent("app_storage.json")
            var json: [String: Any] = [:]
            if let data = try? Data(contentsOf: storageFile),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json = parsed
            }
            if (json["runInBackground"] as? String) != "true" {
                json["runInBackground"] = "true"
                if let encoded = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
                    try? encoded.write(to: storageFile, options: .atomic)
                }
            }
        }
    }

    func refresh() {
        hasScreenCapturePermission = CGPreflightScreenCaptureAccess()
        let fm = FileManager.default
        let roots = [URL(fileURLWithPath: "/Applications"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var found: [ManagedInstance] = []
        var seen = Set<String>()
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for app in entries where app.pathExtension == "app" && app.lastPathComponent.hasPrefix("Antigravity") {
                guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
                      let bundle = info["CFBundleIdentifier"] as? String,
                      bundle == "com.google.antigravity" || bundle.hasPrefix("local.antigravity.") else { continue }
                guard seen.insert(bundle).inserted else { continue }
                let version = info["CFBundleShortVersionString"] as? String ?? "未知"
                let name = info["CFBundleDisplayName"] as? String ?? app.deletingPathExtension().lastPathComponent
                let index = number(for: app.deletingPathExtension().lastPathComponent, bundle: bundle)
                let manifest = manifestPath(index: index)
                let record = (try? Data(contentsOf: manifest)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let verified = record?["login_verified"] as? Bool ?? false
                let runningApp = runningApplication(bundleID: bundle, path: app)
                let running = runningApp != nil
                let isHidden = isInstanceCollapsed(runningApp)
                found.append(ManagedInstance(id: bundle, name: name, path: app, bundleID: bundle,
                                             version: version, index: index, running: running,
                                             isHidden: isHidden, verified: verified))
            }
        }
        let sorted = found.sorted { a, b in
            if a.isOriginal != b.isOriginal {
                return a.isOriginal
            }
            return a.index < b.index
        }
        enforceRunInBackgroundSetting(for: sorted)
        lastOpenWindowBundles = Set(sorted.filter { $0.running && !$0.isHidden }.map(\.bundleID))
        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            instances = sorted
            if let source = instances.first(where: { $0.isOriginal }) {
                sourceVersion = source.version
                compatibility = supportedVersions.contains(source.version) ? "已支持本机版本" : "版本待适配"
            } else {
                sourceVersion = "未找到"
                compatibility = "需要官方原版"
            }
        }
        refreshBackups()
        refreshTelemetryAndThumbnails()
        refreshDiskUsages()
    }

    private func runningApplication(bundleID: String, path: URL) -> NSRunningApplication? {
        let expected = path.resolvingSymlinksInPath().standardizedFileURL
        let candidates = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { !$0.isTerminated }
        if let match = candidates.first(where: { app in
            guard let bundleURL = app.bundleURL else { return true }
            return bundleURL.resolvingSymlinksInPath().standardizedFileURL == expected
        }) {
            return match
        }
        return candidates.first
    }

    var isMainWindowVisible: Bool {
        NSApp.windows.contains { window in
            !(window is NSPanel) && !window.isSheet && window.canBecomeMain && window.isVisible && !window.isMiniaturized
        }
    }

    var shouldCaptureScreenshots: Bool {
        isMainWindowVisible || (quickSwitcherPanel?.isVisible == true)
    }

    private var standbyTickCount: Int = 0

    func periodicTick() {
        let isStandby = !shouldCaptureScreenshots && activeTaskCount == 0
        if isStandby {
            standbyTickCount += 1
            // Sentinel Low-Power Standby: when window is hidden to tray and all instances are idle,
            // throttle full scan from 2.2s to ~11s (every 5 ticks), allowing macOS App Nap to engage
            guard standbyTickCount % 5 == 0 else { return }
        } else {
            standbyTickCount = 0
        }
        refreshRunningStates()
    }

    func refreshRunningStates() {
        standbyTickCount = 0
        let updated = instances.map { item in
            let app = runningApplication(bundleID: item.bundleID, path: item.path)
            return ManagedInstance(id: item.id, name: item.name, path: item.path, bundleID: item.bundleID,
                                   version: item.version, index: item.index,
                                   running: app != nil, isHidden: isInstanceCollapsed(app), verified: item.verified)
        }
        let currentOpenBundles = Set(updated.filter { $0.running && !$0.isHidden }.map(\.bundleID))
        // Detect if the user just clicked the red close (✕) button on the active Antigravity window:
        // The instance stays running (`running == true`), its window closes & Dock icon hides (`isHidden == true`),
        // so we automatically return focus to the Aether Antigravity Multiplexer Monitor Wall!
        if let lastFront = lastFrontmostAntigravityBundle,
           lastOpenWindowBundles.contains(lastFront),
           !currentOpenBundles.contains(lastFront),
           updated.first(where: { $0.bundleID == lastFront })?.running == true {
            lastFrontmostAntigravityBundle = nil
            bringMonitorWallToFront()
        }
        lastOpenWindowBundles = currentOpenBundles

        if updated != instances {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                instances = updated
            }
        }
        updateActiveFrontmostInstance()
        refreshTelemetryAndThumbnails()
    }

    func refreshTelemetryAndThumbnails() {
        guard !isScanningTelemetry else { return }
        isScanningTelemetry = true
        let snapshot = instances
        let shouldCapture = shouldCaptureScreenshots
        var knownConvIDs: [String: String] = [:]
        for (id, urlString) in activeConversationURLs {
            if let url = URL(string: urlString), let lastComp = url.pathComponents.last, !lastComp.isEmpty {
                knownConvIDs[id] = lastComp
            }
        }
        let currentMetrics = self.resourceMetrics
        let existingThumbnails = Set(thumbnails.keys)
        let activeTasks = Set(activities.filter { $0.value.state == .runningTask }.keys)
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let runningPids = Dictionary(uniqueKeysWithValues: snapshot.compactMap { item -> (String, pid_t)? in
            guard item.running, let app = self.runningApplication(bundleID: item.bundleID, path: item.path) else { return nil }
            return (item.id, app.processIdentifier)
        })

        telemetryTickCount += 1
        let tick = telemetryTickCount

        Task.detached(priority: .utility) {
            let scanned = TelemetryScanner.scan(instances: snapshot, knownConvIDs: knownConvIDs)
            let metrics = shouldCapture ? TelemetryScanner.scanResourceMetrics(instances: snapshot, runningAppPids: runningPids) : currentMetrics
            let cdpData = await Self.captureCDPScreenshots(
                for: snapshot,
                captureThumbnails: shouldCapture,
                frontmostBundleID: frontmost,
                existingThumbnailIDs: existingThumbnails,
                activeTaskIDs: activeTasks,
                telemetryTick: tick
            )
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isScanningTelemetry = false
                var finalActivities = scanned
                for (id, ws) in cdpData.workspaces {
                    if !ws.isEmpty, var act = finalActivities[id] {
                        act.workspace = ws
                        finalActivities[id] = act
                    }
                }
                self.processActivityChangesAndNotify(newActivities: finalActivities)
                if self.activities != finalActivities {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.activities = finalActivities
                    }
                }
                if self.resourceMetrics != metrics {
                    self.resourceMetrics = metrics
                }
                if shouldCapture && !cdpData.thumbnails.isEmpty {
                    for (id, image) in cdpData.thumbnails {
                        self.thumbnails[id] = image
                    }
                }
                if self.activeConversationURLs != cdpData.urls {
                    self.activeConversationURLs = cdpData.urls
                }
                if shouldCapture {
                    self.captureWindowThumbnails()
                }
                self.updateStatusBarMenu()
                self.updateDockBadge()
            }
        }
    }

    private nonisolated static let cdpSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 1.0
        config.timeoutIntervalForResource = 2.0
        return URLSession(configuration: config)
    }()

    /// Zero-permission live window screenshot capture via Chromium DevTools Protocol (`DevToolsActivePort`).
    /// Captures live UI screenshots of all running instances in real-time and remembers the active conversation URL!
    private nonisolated static func captureCDPScreenshots(
        for items: [ManagedInstance],
        captureThumbnails: Bool = true,
        frontmostBundleID: String? = nil,
        existingThumbnailIDs: Set<String> = [],
        activeTaskIDs: Set<String> = [],
        telemetryTick: Int = 0
    ) async -> (thumbnails: [String: NSImage], urls: [String: String], workspaces: [String: String], sessionTitles: [String: String]) {
        var results: [String: NSImage] = [:]
        var urls: [String: String] = [:]
        var workspaces: [String: String] = [:]
        var sessionTitles: [String: String] = [:]
        let appSupportRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")

        for item in items where item.running {
            let isFrontmost = (frontmostBundleID == item.bundleID)
            let isRunningTask = activeTaskIDs.contains(item.id)
            let hasThumbnail = existingThumbnailIDs.contains(item.id)

            // For background idle instances with existing metadata, only query CDP endpoint every 5 ticks (~11s)
            let shouldQueryCDP = isFrontmost || isRunningTask || !hasThumbnail || (telemetryTick % 5 == 0)
            guard shouldQueryCDP else { continue }

            let portFile = appSupportRoot.appendingPathComponent(item.name).appendingPathComponent("DevToolsActivePort")
            guard let content = try? String(contentsOf: portFile, encoding: .utf8),
                  let firstLine = content.components(separatedBy: .newlines).first,
                  let port = Int(firstLine.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let listURL = URL(string: "http://127.0.0.1:\(port)/json/list") else { continue }

            var req = URLRequest(url: listURL)
            req.timeoutInterval = 0.8
            guard let (data, _) = try? await cdpSession.data(for: req),
                  let targets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { continue }

            guard let mainTarget = targets.first(where: { t in
                guard (t["type"] as? String) == "page",
                      let u = t["url"] as? String else { return false }
                return u.hasPrefix("https://127.0.0.1:") || u.hasPrefix("http://127.0.0.1:")
            }),
            let currentURL = mainTarget["url"] as? String else { continue }

            if currentURL.contains("/c/") {
                urls[item.id] = currentURL
            }

            if let windowTitle = mainTarget["title"] as? String {
                let parts = windowTitle.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 3 {
                    sessionTitles[item.id] = parts[0]
                    workspaces[item.id] = parts[1]
                } else if parts.count == 2 {
                    workspaces[item.id] = parts[0]
                }
            }

            let shouldFetchImage = captureThumbnails && (!hasThumbnail || isFrontmost || isRunningTask)

            if shouldFetchImage,
               let wsString = mainTarget["webSocketDebuggerUrl"] as? String,
               let wsURL = URL(string: wsString),
               let image = await fetchCDPScreenshot(wsURL: wsURL) {
                results[item.id] = image
            }
        }
        return (results, urls, workspaces, sessionTitles)
    }

    private nonisolated static func fetchCDPScreenshot(wsURL: URL) async -> NSImage? {
        let task = cdpSession.webSocketTask(with: wsURL)
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }
        let payload = "{\"id\":1,\"method\":\"Page.captureScreenshot\",\"params\":{\"format\":\"jpeg\",\"quality\":62}}"
        do {
            try await task.send(.string(payload))
            let message = try await task.receive()
            guard case .string(let text) = message,
                  let data = text.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let res = obj["result"] as? [String: Any],
                  let b64 = res["data"] as? String,
                  let imgData = Data(base64Encoded: b64),
                  let image = NSImage(data: imgData) else { return nil }
            return image
        } catch {
            return nil
        }
    }


    func checkScreenCapturePermission() {
        let granted = CGPreflightScreenCaptureAccess()
        if hasScreenCapturePermission != granted {
            hasScreenCapturePermission = granted
        }
    }

    func requestScreenCapturePermission() {
        _ = CGRequestScreenCaptureAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkScreenCapturePermission()
            self.captureWindowThumbnails()
        }
    }

    func captureWindowThumbnails(specificBundleID: String? = nil) {
        guard shouldCaptureScreenshots else { return }
        guard hasScreenCapturePermission else { return }
        guard let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else { return }

        let frontmostBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        for item in instances where item.running {
            if let specificBundleID, item.bundleID != specificBundleID { continue }
            guard let app = runningApplication(bundleID: item.bundleID, path: item.path) else { continue }
            // Only capture when not hidden/collapsed so we don't overwrite a good snapshot with an empty frame
            if isInstanceCollapsed(app) && thumbnails[item.id] != nil { continue }
            let isRunningTask = activities[item.id]?.state == .runningTask
            let isFront = (frontmostBundle == item.bundleID)
            let hasThumb = thumbnails[item.id] != nil
            if hasThumb && !isFront && !isRunningTask { continue }
            let pid = app.processIdentifier
            let candidateWindows = windowList.filter { info in
                guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                      (info[kCGWindowLayer as String] as? Int) == 0,
                      let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                      let width = bounds["Width"], let height = bounds["Height"],
                      width >= 480, height >= 320 else { return false }
                return true
            }
            // Pick largest window for this PID
            guard let bestWindow = candidateWindows.max(by: { a, b in
                let ba = a[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
                let bb = b[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
                return (ba["Width"] ?? 0) * (ba["Height"] ?? 0) < (bb["Width"] ?? 0) * (bb["Height"] ?? 0)
            }),
            let windowID = bestWindow[kCGWindowNumber as String] as? CGWindowID else { continue }

            if let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .nominalResolution]),
               cgImage.width > 100 && cgImage.height > 100 {
                thumbnails[item.id] = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }
    }

    private func number(for name: String, bundle: String) -> Int {
        if bundle == "com.google.antigravity" { return 1 }
        for (word, value) in names where name.contains(word) { return value }
        if let value = Int(name.replacingOccurrences(of: "Antigravity ", with: "")) { return value }
        if let digits = bundle.components(separatedBy: "instance").last, let value = Int(digits) { return value }
        return 10_000
    }

    private func manifestPath(index: Int) -> URL { support.appendingPathComponent("instance-\(index).json") }
    var nextIndex: Int { max(8, (instances.map(\.index).filter { $0 < 10_000 }.max() ?? 7) + 1) }
    var pendingUpgrades: [ManagedInstance] { instances.filter { !$0.isOriginal && $0.version.compare(sourceVersion, options: .numeric) == .orderedAscending } }
    var primaryInstance: ManagedInstance? { instances.first(where: { $0.isOriginal }) }
    var cloneInstances: [ManagedInstance] { instances.filter { !$0.isOriginal } }
    var runningCount: Int { instances.filter(\.running).count }
    var activeTaskCount: Int {
        instances.filter { item in
            guard item.running, let state = activities[item.id]?.state else { return false }
            return state == .runningTask || state == .needsAttention
        }.count
    }

    func activity(for item: ManagedInstance) -> InstanceActivity {
        activities[item.id] ?? (item.running ? InstanceActivity(state: .idle, currentAction: "已启动就绪") : .stopped)
    }

    // MARK: - Window Focus, Solo Mode & Dock-Detached Collapse to Monitor Wall

    func openInstance(byBundleID bundleID: String) {
        if let item = instances.first(where: { $0.bundleID == bundleID }) {
            open(item)
        }
    }

    func open(_ item: ManagedInstance) {
        let now = Date()
        if let last = lastOpenTime[item.id], now.timeIntervalSince(last) < 0.6 {
            return
        }
        lastOpenTime[item.id] = now

        enforceRunInBackgroundSetting(for: [item])
        if soloFocusMode {
            hideOtherInstances(except: item.bundleID)
        }

        self.activeInstanceName = item.name
        self.lastFrontmostAntigravityBundle = item.bundleID
        self.updateFloatingHUDVisibility()

        if let app = runningApplication(bundleID: item.bundleID, path: item.path) {
            // 1. Unhide via AppleScript and activate
            let script = "tell application \"System Events\" to set visible of (first process whose bundle identifier is \"\(item.bundleID)\") to true"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            _ = app.unhide()

            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: item.path, configuration: config) { [weak self] runningApp, _ in
                DispatchQueue.main.async {
                    runningApp?.activate(options: [.activateIgnoringOtherApps])
                    self?.refreshRunningStates()
                }
            }
            return
        }

        // 2. Cold start: Instance is not currently running. Launch cleanly once.
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: item.path, configuration: config) { [weak self] app, _ in
            DispatchQueue.main.async {
                app?.activate(options: [.activateIgnoringOtherApps])
                self?.refreshRunningStates()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.refreshRunningStates()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                self?.refreshRunningStates()
            }
        }
    }

    func togglePrimaryInstance() {
        guard let primary = primaryInstance ?? instances.first else { return }
        toggleInstance(primary)
    }

    func toggleInstance(byShortcutNumber number: Int) {
        if number == 1 {
            togglePrimaryInstance()
            return
        }
        let clones = instances.filter { !$0.isOriginal }.sorted { $0.index < $1.index }
        if let target = instances.first(where: { !$0.isOriginal && $0.index == number }) ?? (number - 2 >= 0 && number - 2 < clones.count ? clones[number - 2] : nil) {
            toggleInstance(target)
        }
    }

    func toggleInstance(_ item: ManagedInstance) {
        hideQuickSwitcher()
        let frontmostBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isFrontmost = (frontmostBundle == item.bundleID)
        let isRunning = item.running

        if isRunning && isFrontmost && !item.isHidden {
            hideInstance(item)
        } else {
            open(item)
        }
    }

    private func setupGlobalHotKeys() {
        GlobalHotKeyManager.shared.setup(
            onToggleQuickSwitcher: { [weak self] in
                self?.toggleQuickSwitcher()
            },
            onToggleInstance: { [weak self] number in
                self?.toggleInstance(byShortcutNumber: number)
            }
        )
        if !globalHotkeysEnabled {
            GlobalHotKeyManager.shared.unregister()
        }
    }

    private func updateGlobalHotkeysRegistration() {
        if globalHotkeysEnabled {
            GlobalHotKeyManager.shared.register()
        } else {
            GlobalHotKeyManager.shared.unregister()
        }
    }

    func toggleQuickSwitcher() {
        if let panel = quickSwitcherPanel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        showQuickSwitcher()
    }

    func showQuickSwitcher() {
        if quickSwitcherPanel == nil {
            let panel = QuickSwitcherPanel(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.contentView = NSHostingView(rootView: QuickSwitcherView(store: self, dismiss: { [weak panel] in
                panel?.orderOut(nil)
            }))
            quickSwitcherPanel = panel
        }
        guard let panel = quickSwitcherPanel else { return }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideQuickSwitcher() {
        quickSwitcherPanel?.orderOut(nil)
    }

    func hideInstance(_ item: ManagedInstance) {
        guard let app = runningApplication(bundleID: item.bundleID, path: item.path) else { return }
        enforceRunInBackgroundSetting(for: [item])
        _ = app.hide()
        let script = "tell application \"System Events\" to set visible of (first process whose bundle identifier is \"\(item.bundleID)\") to false"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.refreshRunningStates()
        }
    }

    func hideOtherInstances(except keptBundleID: String?) {
        for item in instances where item.running && item.bundleID != keptBundleID {
            if let app = runningApplication(bundleID: item.bundleID, path: item.path), !isInstanceCollapsed(app) {
                hideInstance(item)
            }
        }
    }

    func bringMonitorWallToFront() {
        quickSwitcherPanel?.orderOut(nil)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where !(window is NSPanel) && !window.isSheet && window.canBecomeMain {
            if let sheet = window.attachedSheet {
                sheet.makeKeyAndOrderFront(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    func collapseAllToMonitorWall() {
        captureWindowThumbnails()
        hideOtherInstances(except: nil)
        lastFrontmostAntigravityBundle = nil
        bringMonitorWallToFront()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.refreshRunningStates()
        }
    }

    private func updateActiveFrontmostInstance() {
        let newActiveName: String?
        let newBundle: String?
        if let front = NSWorkspace.shared.frontmostApplication,
           let bundle = front.bundleIdentifier,
           bundle == "com.google.antigravity" || bundle.hasPrefix("local.antigravity.") {
            newActiveName = instances.first(where: { $0.bundleID == bundle })?.name ?? front.localizedName
            newBundle = bundle
        } else {
            newActiveName = nil
            newBundle = nil
        }
        if activeInstanceName != newActiveName {
            activeInstanceName = newActiveName
        }
        if let newBundle {
            lastFrontmostAntigravityBundle = newBundle
        }
        updateFloatingHUDVisibility()
    }

    // MARK: - Floating Return HUD Pill & Status Bar Item

    private func updateFloatingHUDVisibility() {
        guard floatingHUDEnabled, activeInstanceName != nil else {
            hudPanel?.orderOut(nil)
            return
        }
        if hudPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 315, height: 44),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true

            let savedX = UserDefaults.standard.object(forKey: "floatingHUD_x") as? Double
            let savedY = UserDefaults.standard.object(forKey: "floatingHUD_y") as? Double
            if let x = savedX, let y = savedY, let screen = NSScreen.main?.visibleFrame {
                let minX = screen.minX
                let maxX = max(minX, screen.maxX - 315)
                let minY = screen.minY
                let maxY = max(minY, screen.maxY - 44)
                let clampedX = min(max(x, minX), maxX)
                let clampedY = min(max(y, minY), maxY)
                panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
            } else if let screen = NSScreen.main?.visibleFrame {
                // Default position: Top-Right of screen below menu bar, avoiding bottom chat/prompt box on laptop screens
                panel.setFrameOrigin(NSPoint(x: max(screen.minX, screen.maxX - 335), y: max(screen.minY, screen.maxY - 70)))
            }

            panel.contentView = DraggableHostingView(rootView: FloatingMonitorHUDView(store: self))
            hudPanel = panel
        }
        hudPanel?.orderFrontRegardless()
    }

    // MARK: - System Notifications (UNUserNotificationCenter) & Dock/Status Bar Badges

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = AppNotificationDelegate.shared

        let openAction = UNNotificationAction(
            identifier: "ACTION_OPEN_INSTANCE",
            title: "立即调出窗口",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "INSTANCE_NOTIFICATION_CATEGORY",
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func processActivityChangesAndNotify(newActivities: [String: InstanceActivity]) {
        guard notificationsEnabled else { return }
        guard hasInitializedActivityBaseline else {
            for (id, act) in newActivities {
                lastNotifiedStates[id] = (state: act.state, stepIndex: act.stepIndex)
            }
            hasInitializedActivityBaseline = true
            return
        }

        let frontmostBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        for item in instances where item.running {
            guard let newAct = newActivities[item.id] else { continue }
            let prev = lastNotifiedStates[item.id]
            let prevState = prev?.state ?? .stopped
            let prevStep = prev?.stepIndex ?? -1

            let isUserCurrentlyFocusingInstance = (frontmostBundle == item.bundleID)
            let meta = meta(for: item)
            let displayName = meta.nickname.isEmpty ? item.name : "\(meta.nickname) (\(item.name))"
            let isMainPrefix = item.isOriginal ? "👑 " : ""

            // Start timing when task begins running
            if newAct.state == .runningTask && prevState != .runningTask {
                taskStartTimes[item.id] = Date()
            }

            if newAct.state == .needsAttention && (prevState != .needsAttention || newAct.stepIndex != prevStep) {
                lastNotifiedStates[item.id] = (state: newAct.state, stepIndex: newAct.stepIndex)
                let duration = taskStartTimes[item.id].map { Date().timeIntervalSince($0) }
                recordTaskEvent(
                    item: item,
                    category: .needsAttention,
                    action: newAct.currentAction.isEmpty ? "Agent 需要用户选择或确认操作" : newAct.currentAction,
                    workspace: newAct.workspace,
                    stepIndex: newAct.stepIndex,
                    duration: duration
                )
                if !isUserCurrentlyFocusingInstance {
                    sendSystemNotification(
                        identifier: "needs-attention-\(item.id)-\(newAct.stepIndex)",
                        title: "\(isMainPrefix)\(displayName) · 等待确认",
                        subtitle: newAct.workspace.isEmpty ? "Agent 需要用户选择或确认操作" : "工作区: \(newAct.workspace)",
                        body: newAct.currentAction.isEmpty ? "点击通知立即调出此实例窗口进行确认" : newAct.currentAction,
                        bundleID: item.bundleID
                    )
                }
            } else if prevState == .runningTask && newAct.state == .idle {
                let duration = taskStartTimes[item.id].map { Date().timeIntervalSince($0) }
                taskStartTimes.removeValue(forKey: item.id)
                lastNotifiedStates[item.id] = (state: newAct.state, stepIndex: newAct.stepIndex)
                let cleanedAction = newAct.currentAction.hasPrefix("上次：") ? String(newAct.currentAction.dropFirst(3)) : newAct.currentAction
                recordTaskEvent(
                    item: item,
                    category: .completed,
                    action: cleanedAction.isEmpty ? "所有指令已执行完毕" : cleanedAction,
                    workspace: newAct.workspace,
                    stepIndex: newAct.stepIndex,
                    duration: duration
                )
                if !isUserCurrentlyFocusingInstance {
                    sendSystemNotification(
                        identifier: "task-completed-\(item.id)-\(newAct.stepIndex)",
                        title: "\(isMainPrefix)\(displayName) · 任务已完成",
                        subtitle: newAct.workspace.isEmpty ? "Agent 步骤已顺利完成" : "工作区: \(newAct.workspace)",
                        body: cleanedAction.isEmpty ? "所有指令已执行完毕，点击立即调出窗口" : cleanedAction,
                        bundleID: item.bundleID
                    )
                }
            } else if newAct.state == .error && prevState != .error {
                let duration = taskStartTimes[item.id].map { Date().timeIntervalSince($0) }
                taskStartTimes.removeValue(forKey: item.id)
                lastNotifiedStates[item.id] = (state: newAct.state, stepIndex: newAct.stepIndex)
                recordTaskEvent(
                    item: item,
                    category: .error,
                    action: newAct.currentAction.isEmpty ? "执行遇到错误" : newAct.currentAction,
                    workspace: newAct.workspace,
                    stepIndex: newAct.stepIndex,
                    duration: duration
                )
                if !isUserCurrentlyFocusingInstance {
                    sendSystemNotification(
                        identifier: "task-error-\(item.id)-\(newAct.stepIndex)",
                        title: "\(isMainPrefix)\(displayName) · 任务执行异常",
                        subtitle: newAct.workspace.isEmpty ? "执行步骤报错" : "工作区: \(newAct.workspace)",
                        body: newAct.currentAction.isEmpty ? "执行遇到错误，点击调出窗口查看详情" : newAct.currentAction,
                        bundleID: item.bundleID
                    )
                }
            } else if prev == nil || prevState != newAct.state || prevStep != newAct.stepIndex {
                lastNotifiedStates[item.id] = (state: newAct.state, stepIndex: newAct.stepIndex)
            }
        }
    }

    private func sendSystemNotification(identifier: String, title: String, subtitle: String, body: String, bundleID: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        if !subtitle.isEmpty {
            content.subtitle = subtitle
        }
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "INSTANCE_NOTIFICATION_CATEGORY"
        content.userInfo = ["bundleID": bundleID]

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Notification delivery failed: \(error)")
            }
        }
    }

    func updateDockBadge() {
        guard dockBadgeEnabled else {
            NSApp.dockTile.badgeLabel = nil
            NSApp.dockTile.display()
            return
        }

        let attentionCount = instances.filter { item in
            item.running && activities[item.id]?.state == .needsAttention
        }.count

        let runningTasks = instances.filter { item in
            item.running && activities[item.id]?.state == .runningTask
        }.count

        if attentionCount > 0 {
            NSApp.dockTile.badgeLabel = attentionCount > 1 ? "!\(attentionCount)" : "!"
        } else if runningTasks > 0 {
            NSApp.dockTile.badgeLabel = "\(runningTasks)"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
        NSApp.dockTile.display()
    }

    private func setupStatusBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Antigravity 监控台")
            button.imagePosition = .imageLeading
        }
        statusItem = item
        updateStatusBarMenu()
    }

    func updateStatusBarMenu() {
        guard let statusItem else { return }

        let attentionCount = instances.filter { item in
            item.running && activities[item.id]?.state == .needsAttention
        }.count

        let runningTasks = instances.filter { item in
            item.running && activities[item.id]?.state == .runningTask
        }.count

        if let button = statusItem.button {
            if attentionCount > 0 {
                button.image = NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "有实例等待确认")
                button.title = " \(attentionCount)待确认"
            } else if runningTasks > 0 {
                button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "正在运行任务")
                button.title = " \(runningTasks)"
            } else {
                button.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Antigravity 监控台")
                button.title = ""
            }
        }

        let menu = NSMenu()
        StatusBarTarget.shared.store = self

        let switcherItem = NSMenuItem(title: "极速切换面板 (⌥Space)", action: #selector(StatusBarTarget.toggleQuickSwitcher), keyEquivalent: "")
        switcherItem.target = StatusBarTarget.shared
        menu.addItem(switcherItem)

        let collapseItem = NSMenuItem(title: "收起所有实例并打开监控台", action: #selector(StatusBarTarget.collapseAll), keyEquivalent: "0")
        collapseItem.target = StatusBarTarget.shared
        menu.addItem(collapseItem)

        let showMainWindowItem = NSMenuItem(title: "显示多开监控台主窗口", action: #selector(StatusBarTarget.showMainWindow), keyEquivalent: "")
        showMainWindowItem.target = StatusBarTarget.shared
        menu.addItem(showMainWindowItem)

        let busyInstances = instances.filter { item in
            guard item.running, let act = activities[item.id] else { return false }
            return act.state == .runningTask || act.state == .needsAttention
        }
        if !busyInstances.isEmpty {
            menu.addItem(.separator())
            let headerItem = NSMenuItem(title: "⚡ 活跃任务 (\(busyInstances.count))", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            for item in busyInstances {
                let act = activity(for: item)
                let meta = meta(for: item)
                let name = meta.nickname.isEmpty ? item.name : meta.nickname
                let isMainPrefix = item.isOriginal ? "👑 " : ""
                let icon = act.state == .needsAttention ? "🔔" : "⚡"
                let detail = act.workspace.isEmpty ? act.currentAction : "\(act.workspace) · \(act.currentAction)"
                let taskItem = NSMenuItem(
                    title: "  \(icon) \(isMainPrefix)\(name) — \(detail)",
                    action: #selector(StatusBarTarget.openInstance(_:)),
                    keyEquivalent: ""
                )
                taskItem.representedObject = item.id
                taskItem.target = StatusBarTarget.shared
                taskItem.toolTip = "点击立即调出该实例窗口"
                menu.addItem(taskItem)
            }
        }

        menu.addItem(.separator())
        let listHeader = NSMenuItem(title: "所有实例列表 (\(runningCount) 运行中 / 共 \(instances.count))", action: nil, keyEquivalent: "")
        listHeader.isEnabled = false
        menu.addItem(listHeader)

        for item in instances {
            let act = activity(for: item)
            let meta = meta(for: item)
            let displayName = meta.nickname.isEmpty ? item.name : "\(meta.nickname) (\(item.name))"
            let statePrefix = !item.running ? "⏹" : (act.state == .runningTask ? "⚡" : (act.state == .needsAttention ? "🔔" : "🟢"))
            let shortcutHint = item.isOriginal ? "[⌥1]" : "[⌥\(item.index)]"
            let isMainPrefix = item.isOriginal ? "👑 " : ""
            let menuItem = NSMenuItem(
                title: "\(statePrefix) \(isMainPrefix)\(displayName) \(shortcutHint) · \(act.state.label)",
                action: #selector(StatusBarTarget.openInstance(_:)),
                keyEquivalent: ""
            )
            menuItem.representedObject = item.id
            menuItem.target = StatusBarTarget.shared
            menu.addItem(menuItem)
        }

        if !taskHistory.isEmpty {
            menu.addItem(.separator())
            let historyHeader = NSMenuItem(title: "📋 最近任务动态", action: nil, keyEquivalent: "")
            historyHeader.isEnabled = false
            menu.addItem(historyHeader)

            for item in taskHistory.prefix(3) {
                let dur = item.formattedDuration.map { " (\($0))" } ?? ""
                let icon = item.category == .completed ? "✅" : (item.category == .needsAttention ? "🔔" : "⚠️")
                let title = "  \(icon) \(item.formattedTime) · \(item.displayName) · \(item.actionSummary)\(dur)"
                let historyItem = NSMenuItem(
                    title: title,
                    action: #selector(StatusBarTarget.openHistoryInstance(_:)),
                    keyEquivalent: ""
                )
                historyItem.representedObject = item.instanceID
                historyItem.target = StatusBarTarget.shared
                historyItem.toolTip = "点击调出该实例并聚焦"
                menu.addItem(historyItem)
            }

            let viewAllItem = NSMenuItem(title: "  查看完整任务历史与耗时...", action: #selector(StatusBarTarget.openTaskHistory), keyEquivalent: "")
            viewAllItem.target = StatusBarTarget.shared
            menu.addItem(viewAllItem)
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出多开管理器", action: #selector(StatusBarTarget.quitApp), keyEquivalent: "q")
        quitItem.target = StatusBarTarget.shared
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Existing Instance & Backup Operations

    func refreshBackups() {
        guard let script = Bundle.main.url(forResource: "manage_backups", withExtension: "py") else {
            backups = []; return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [script.path, "list"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                backups = try JSONDecoder().decode([BackupBatch].self, from: data)
            } else {
                backups = []
                if error == nil { error = "无法读取备份列表，请检查备份目录。" }
            }
        } catch { self.error = "无法读取备份列表：\(error.localizedDescription)" }
    }

    func showBackups() { NSWorkspace.shared.open(support.appendingPathComponent("Backups")) }
    func deleteBackup(_ batch: BackupBatch) {
        guard !busy && batch.deletable else { return }
        guard let script = Bundle.main.url(forResource: "manage_backups", withExtension: "py") else {
            error = "应用缺少备份管理组件。"; return
        }
        runScript(script, arguments: ["delete", batch.name], starting: "正在删除选定备份批次…\n")
    }

    func reveal(_ item: ManagedInstance) { NSWorkspace.shared.activateFileViewerSelecting([item.path]) }
    func showLogs(_ item: ManagedInstance) {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/\(item.name)")
        NSWorkspace.shared.open(path)
    }
    func toggleVerified(_ item: ManagedInstance) {
        guard !item.isOriginal && item.index >= 8 else { return }
        let path = manifestPath(index: item.index)
        guard let data = try? Data(contentsOf: path),
              var record = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        record["login_verified"] = !item.verified
        guard let encoded = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]) else { return }
        do { try encoded.write(to: path, options: .atomic); refresh() }
        catch { self.error = "无法保存验证状态：\(error.localizedDescription)" }
    }

    func upgrade(_ selected: [ManagedInstance]) {
        guard !busy && !selected.isEmpty && selected.allSatisfy({ pendingUpgrades.contains($0) }) else { return }
        guard let script = Bundle.main.url(forResource: "upgrade_all", withExtension: "py") else {
            error = "应用缺少升级组件。"; return
        }
        runScript(script, arguments: ["--source", "/Applications/Antigravity.app",
                                      "--only-indices", selected.map { String($0.index) }.joined(separator: ",")],
                  starting: "正在检查本机主实例和选定副本；此操作不下载程序…\n")
    }

    func create(index: Int, destination: URL) {
        guard !busy else { return }
        guard let script = Bundle.main.url(forResource: "create_instance", withExtension: "py") else {
            error = "应用缺少创建组件。"; return
        }
        runScript(script, arguments: ["--index", String(index), "--source", "/Applications/Antigravity.app",
                                      "--destination", destination.path],
                  starting: "正在检查官方应用…\n")
    }

    func destroy(_ item: ManagedInstance) {
        guard !busy && !item.isOriginal && (2...9999).contains(item.index) else { return }
        guard let script = Bundle.main.url(forResource: "destroy_instance", withExtension: "py") else {
            error = "应用缺少实例销毁组件。"; return
        }
        runScript(script, arguments: ["--index", String(item.index), "--app", item.path.path],
                  starting: "正在核对并销毁 \(item.name)…\n")
    }

    func clearWorkspace(_ item: ManagedInstance) {
        guard !busy && !item.isOriginal && !item.running && (2...9999).contains(item.index) else { return }
        guard let script = Bundle.main.url(forResource: "clear_workspace", withExtension: "py") else {
            error = "应用缺少工作空间清理组件。"; return
        }
        runScript(script, arguments: ["--index", String(item.index), "--app", item.path.path],
                  starting: "正在核对并清空 \(item.name) 的独立工作空间…\n")
    }

    func quit(_ item: ManagedInstance) {
        guard !busy else { return }
        let expected = item.path.resolvingSymlinksInPath().standardizedFileURL
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID).filter {
            !$0.isTerminated && $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == expected
        }
        guard !apps.isEmpty else { refreshRunningStates(); return }
        if apps.map({ $0.terminate() }).contains(false) {
            error = "无法正常退出 \(item.name)，请在该实例中选择“退出”后重试。"
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            refreshRunningStates()
        }
    }

    func clearOutput() {
        guard !busy else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            output = ""
        }
    }

    private func runScript(_ script: URL, arguments: [String], starting: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            busy = true
            error = nil
            output = starting
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [script.path] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let message = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.output += message }
        }
        process.terminationHandler = { [weak self] completed in
            pipe.fileHandleForReading.readabilityHandler = nil
            let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor in
                if let text = String(data: remainder, encoding: .utf8) { self?.output += text }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    self?.busy = false
                }
                if completed.terminationStatus != 0 { self?.error = "操作未完成，请查看下方记录。" }
                self?.refresh()
            }
        }
        do {
            try process.run()
            try? pipe.fileHandleForWriting.close()
        } catch {
            withAnimation { busy = false }
            self.error = "无法启动组件：\(error.localizedDescription)"
        }
    }
}

@MainActor private final class StatusBarTarget: NSObject {
    static let shared = StatusBarTarget()
    weak var store: InstanceStore?

    @objc func toggleQuickSwitcher() {
        store?.toggleQuickSwitcher()
    }

    @objc func collapseAll() {
        store?.collapseAllToMonitorWall()
    }

    @objc func showMainWindow() {
        store?.bringMonitorWallToFront()
    }

    @objc func openInstance(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = store?.instances.first(where: { $0.id == id }) else { return }
        store?.open(item)
    }

    @objc func openHistoryInstance(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = store?.instances.first(where: { $0.id == id }) else { return }
        store?.open(item)
    }

    @objc func openTaskHistory() {
        store?.bringMonitorWallToFront()
        NotificationCenter.default.post(name: .openTaskHistoryRequested, object: nil)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
}

// MARK: - Floating Return to Monitor HUD View

private struct FloatingMonitorHUDView: View {
    @ObservedObject var store: InstanceStore
    @State private var hovered = false
    @State private var dragStartOrigin: NSPoint? = nil

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { val in
                guard let panel = store.hudPanel else { return }
                if dragStartOrigin == nil {
                    dragStartOrigin = panel.frame.origin
                }
                if let start = dragStartOrigin {
                    store.moveHUD(by: val.translation, startOrigin: start)
                }
            }
            .onEnded { _ in
                if let panel = store.hudPanel {
                    store.saveHUDPosition(origin: panel.frame.origin)
                }
                dragStartOrigin = nil
            }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Draggable Area (Grip Icon + Pulsing Dot + Instance Info)
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.40))
                    .frame(width: 12)
                    .help("按住可随意拖动浮窗到屏幕任意位置")

                PulsingStatusDot(
                    active: true,
                    activeColor: store.activeTaskCount > 0 ? Color(red: 0.15, green: 0.82, blue: 0.96) : .green,
                    pulse: store.activeTaskCount > 0
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.activeInstanceName ?? "Antigravity")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(store.activeTaskCount > 0 ? "\(store.activeTaskCount) 个实例正在跑任务" : "所有运行实例空闲")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)

            Spacer(minLength: 4)
                .contentShape(Rectangle())
                .gesture(dragGesture)

            Button {
                store.toggleQuickSwitcher()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("快速切换到其他 Antigravity 实例 (⌥Space)")

            Button {
                store.collapseAllToMonitorWall()
            } label: {
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text("收起回监控台")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(accent))
            }
            .buttonStyle(.plain)
            .help("隐藏当前实例窗口并返回缩略图监控墙（后台任务继续运行）")

            if hovered {
                Button {
                    store.floatingHUDEnabled = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("关闭悬浮胶囊（可在设置中重新开启）")
                .transition(.opacity)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, hovered ? 8 : 12)
        .frame(width: 315, height: 42)
        .background {
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.14, blue: 0.20).opacity(0.94),
                                Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.97)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(hovered ? 0.38 : 0.20),
                            accent.opacity(hovered ? 0.45 : 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(
            color: Color.black.opacity(hovered ? 0.45 : 0.30),
            radius: hovered ? 12 : 8,
            x: 0,
            y: hovered ? 5 : 3
        )
        .scaleEffect(hovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: hovered)
        .onHover { hovered = $0 }
    }
}

// MARK: - Global Carbon HotKey Manager

final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private(set) var isRegistered = false

    var onToggleQuickSwitcher: (() -> Void)?
    var onToggleInstance: ((Int) -> Void)?

    func setup(onToggleQuickSwitcher: @escaping () -> Void, onToggleInstance: @escaping (Int) -> Void) {
        self.onToggleQuickSwitcher = onToggleQuickSwitcher
        self.onToggleInstance = onToggleInstance
        register()
    }

    func register() {
        guard !isRegistered else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetEventDispatcherTarget(), { (_, event, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard err == noErr, hotKeyID.signature == OSType(0x4147594D) else {
                return OSStatus(eventNotHandledErr)
            }

            let id = Int(hotKeyID.id)
            DispatchQueue.main.async {
                if id == 0 {
                    GlobalHotKeyManager.shared.onToggleQuickSwitcher?()
                } else if id >= 1 && id <= 9 {
                    GlobalHotKeyManager.shared.onToggleInstance?(id)
                }
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)

        guard status == noErr else { return }

        // 1. Option + Space -> id = 0 (Toggle Quick Switcher)
        registerHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), id: 0)

        // 2. Option + 1~9 -> id = 1~9 (Toggle Instance 1..9, 1 is Main)
        let numberKeys: [(Int, UInt32)] = [
            (1, UInt32(kVK_ANSI_1)),
            (2, UInt32(kVK_ANSI_2)),
            (3, UInt32(kVK_ANSI_3)),
            (4, UInt32(kVK_ANSI_4)),
            (5, UInt32(kVK_ANSI_5)),
            (6, UInt32(kVK_ANSI_6)),
            (7, UInt32(kVK_ANSI_7)),
            (8, UInt32(kVK_ANSI_8)),
            (9, UInt32(kVK_ANSI_9)),
        ]
        for (num, code) in numberKeys {
            registerHotKey(keyCode: code, modifiers: UInt32(optionKey), id: num)
        }

        isRegistered = true
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: Int) {
        var hkRef: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x4147594D), id: UInt32(id)) // 'AGYM'
        let err = RegisterEventHotKey(keyCode, modifiers, hkID, GetEventDispatcherTarget(), 0, &hkRef)
        if err == noErr, let hkRef {
            hotKeyRefs.append(hkRef)
        }
    }

    func unregister() {
        guard isRegistered else { return }
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        isRegistered = false
    }
}

// MARK: - Quick Switcher Floating Panel & View

final class QuickSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var onDismiss: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        onDismiss?()
    }
}

private struct QuickSwitcherView: View {
    @ObservedObject var store: InstanceStore
    let dismiss: () -> Void

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var keyMonitor: Any?

    private var filteredInstances: [ManagedInstance] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return store.instances }
        return store.instances.filter { item in
            let meta = store.meta(for: item)
            let act = store.activity(for: item)
            return item.name.lowercased().contains(q) ||
                   meta.nickname.lowercased().contains(q) ||
                   meta.tag.lowercased().contains(q) ||
                   act.workspace.lowercased().contains(q) ||
                   act.currentAction.lowercased().contains(q) ||
                   String(item.index) == q
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Search Bar Header
            HStack(spacing: 10) {
                Image(systemName: "command.square.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.52, green: 0.32, blue: 0.98))

                TextField("搜索实例名称、标签或工作区… (↑↓ 移动, ⏎ 调出, ⌥1~9 直达)", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14.5, weight: .medium))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _ in
                        selectedIndex = 0
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 4) {
                    Text("Esc")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5.5)
                        .frame(height: 20)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .opacity(0.6)

            // 2. Instances List
            if filteredInstances.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("未匹配到实例")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(filteredInstances.enumerated()), id: \.element.id) { index, item in
                                QuickSwitcherRow(
                                    item: item,
                                    activity: store.activity(for: item),
                                    meta: store.meta(for: item),
                                    metric: store.metric(for: item),
                                    duration: store.runningDuration(for: item),
                                    isSelected: index == selectedIndex,
                                    shortcutNumber: shortcutNumber(for: item),
                                    onSelect: {
                                        doDismiss()
                                        store.open(item)
                                    }
                                )
                                .equatable()
                                .id(index)
                            }
                        }
                        .padding(10)
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .frame(maxHeight: 330)
            }

            Divider()
                .opacity(0.6)

            // 3. Bottom Status Bar & Shortcuts Legend
            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    legendItem(key: "↑ ↓", label: "选择")
                    legendItem(key: "⏎", label: "调出")
                    legendItem(key: "⌥ 1~9", label: "直达/收起")
                    legendItem(key: "Esc", label: "关闭")
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(store.runningCount > 0 ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text("\(store.runningCount) 运行中 · 共 \(store.instances.count) 个实例")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(colorScheme == .dark ? 0.03 : 0.015))
        }
        .frame(width: 620)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.25), radius: 24, y: 12)
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func doDismiss() {
        removeKeyMonitor()
        dismiss()
    }

    private func shortcutNumber(for item: ManagedInstance) -> Int? {
        if item.isOriginal { return 1 }
        let clones = store.instances.filter { !$0.isOriginal }.sorted { $0.index < $1.index }
        if let idx = clones.firstIndex(where: { $0.id == item.id }), idx + 2 <= 9 {
            return idx + 2
        }
        return nil
    }

    private func legendItem(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4.5)
                .frame(height: 17)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.primary.opacity(0.08)))
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak store] event in
            // CRITICAL: Only handle keyboard events if they are targeting the Quick Switcher panel!
            guard let window = event.window, window is QuickSwitcherPanel, window.isVisible else {
                return event
            }
            if event.keyCode == 53 { // Esc
                doDismiss()
                return nil
            } else if event.keyCode == 126 { // Up
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
                return nil
            } else if event.keyCode == 125 { // Down
                if selectedIndex < filteredInstances.count - 1 {
                    selectedIndex += 1
                }
                return nil
            } else if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                if !filteredInstances.isEmpty {
                    let safeIndex = min(max(0, selectedIndex), filteredInstances.count - 1)
                    let target = filteredInstances[safeIndex]
                    doDismiss()
                    store?.open(target)
                }
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

private struct QuickSwitcherRow: View {
    let item: ManagedInstance
    let activity: InstanceActivity
    let meta: InstanceUserMeta
    let metric: InstanceResourceMetric
    let duration: String?
    let isSelected: Bool
    let shortcutNumber: Int?
    let onSelect: () -> Void

    @State private var hovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var isMain: Bool { item.isOriginal }

    private var mainGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.52, green: 0.28, blue: 0.98), Color(red: 0.22, green: 0.46, blue: 1.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 1. Identity Emblem Badge
                if isMain {
                    HStack(spacing: 3.5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                        Text("MAIN 01")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 24)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(mainGradient)
                            .shadow(color: Color(red: 0.50, green: 0.28, blue: 0.98).opacity(0.40), radius: 5, y: 1.5)
                    }
                } else {
                    Text("#\(String(format: "%02d", item.index))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(item.running ? activity.state.color : accent)
                        .padding(.horizontal, 6.5)
                        .frame(height: 24)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(item.running ? activity.state.color.opacity(0.18) : accent.opacity(0.12))
                        }
                }

                // 2. Info Cluster (Title, Tag, Action, Workspace)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(meta.nickname.isEmpty ? item.name : meta.nickname)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isMain ? (colorScheme == .dark ? Color.white : Color(red: 0.12, green: 0.08, blue: 0.28)) : Color.primary)
                            .lineLimit(1)

                        if isMain {
                            Text("官方主实例")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(Color(red: 0.52, green: 0.32, blue: 0.98))
                                .padding(.horizontal, 5)
                                .frame(height: 16)
                                .background(Capsule().fill(Color(red: 0.52, green: 0.32, blue: 0.98).opacity(0.12)))
                        } else if !meta.nickname.isEmpty {
                            Text("(\(item.name))")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if !meta.tag.isEmpty {
                            Text(meta.tag)
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(meta.color)
                                .padding(.horizontal, 5.5)
                                .frame(height: 17)
                                .background(Capsule().fill(meta.color.opacity(0.16)))
                                .overlay(Capsule().strokeBorder(meta.color.opacity(0.35), lineWidth: 0.8))
                        }

                        Spacer()
                    }

                    HStack(spacing: 6) {
                        if item.running {
                            PulsingStatusDot(
                                active: true,
                                activeColor: activity.state.color,
                                pulse: activity.state == .runningTask || activity.state == .needsAttention
                            )
                            Text(activity.currentAction)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            if !activity.workspace.isEmpty {
                                Text("· \(activity.workspace)")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        } else {
                            Circle()
                                .fill(Color.secondary.opacity(0.35))
                                .frame(width: 5, height: 5)
                            Text("未启动")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 6)

                // 3. Right Cluster: Metrics, Duration & Shortcut Pill
                HStack(spacing: 8) {
                    if let duration {
                        HStack(spacing: 3) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 8))
                            Text(duration)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 5.5)
                        .frame(height: 20)
                        .background(Capsule().fill(Color.cyan.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Color.cyan.opacity(0.35), lineWidth: 0.8))
                    }

                    if item.running && metric.processCount > 0 {
                        HStack(spacing: 3.5) {
                            Image(systemName: metric.cpuPercent > 15 ? "bolt.fill" : "cpu")
                                .font(.system(size: 8))
                                .foregroundStyle(metric.cpuPercent > 15 ? Color.cyan : .secondary)
                            Text("\(metric.cpuLabel)")
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 5.5)
                        .frame(height: 20)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                    }

                    if let shortcutNumber {
                        HStack(spacing: 2) {
                            Text("⌥")
                                .font(.system(size: 10.5, weight: .bold))
                            Text("\(shortcutNumber)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(isMain ? Color(red: 0.52, green: 0.32, blue: 0.98) : Color.primary.opacity(0.85))
                        .padding(.horizontal, 6.5)
                        .frame(height: 22)
                        .background {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isMain ? Color(red: 0.52, green: 0.32, blue: 0.98).opacity(0.16) : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(isMain ? Color(red: 0.52, green: 0.32, blue: 0.98).opacity(0.35) : Color.primary.opacity(0.12), lineWidth: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isMain ? Color(red: 0.52, green: 0.32, blue: 0.98).opacity(colorScheme == .dark ? 0.22 : 0.14) : Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.12))
                } else if hovered {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.045))
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isMain ? Color(red: 0.52, green: 0.32, blue: 0.98).opacity(0.55) : Color.accentColor.opacity(0.45), lineWidth: 1.2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

extension QuickSwitcherRow: Equatable {
    static func == (lhs: QuickSwitcherRow, rhs: QuickSwitcherRow) -> Bool {
        lhs.item == rhs.item &&
        lhs.activity == rhs.activity &&
        lhs.meta == rhs.meta &&
        lhs.metric == rhs.metric &&
        lhs.duration == rhs.duration &&
        lhs.isSelected == rhs.isSelected &&
        lhs.shortcutNumber == rhs.shortcutNumber
    }
}

// MARK: - Isolated Resource Metric Badges (Equatable Subtree Isolation)

struct InstanceThumbnailResourceBadge: View, Equatable {
    let isRunning: Bool
    let metric: InstanceResourceMetric

    static func == (lhs: InstanceThumbnailResourceBadge, rhs: InstanceThumbnailResourceBadge) -> Bool {
        lhs.isRunning == rhs.isRunning && lhs.metric == rhs.metric
    }

    var body: some View {
        if isRunning && metric.processCount > 0 {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: metric.cpuPercent > 15 ? "bolt.fill" : "cpu")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(metric.cpuPercent > 15 ? Color.cyan : .white.opacity(0.85))
                    .frame(width: 10, height: 10, alignment: .center)
                Text("\(metric.cpuLabel) · \(metric.memoryLabel)")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(Capsule().fill(Color.black.opacity(0.62)))
            .overlay(Capsule().strokeBorder(metric.cpuPercent > 15 ? Color.cyan.opacity(0.45) : Color.white.opacity(0.18), lineWidth: 1))
        }
    }
}

struct InstanceCardResourceBadges: View, Equatable {
    let isRunning: Bool
    let metric: InstanceResourceMetric
    let isDarkMode: Bool

    static func == (lhs: InstanceCardResourceBadges, rhs: InstanceCardResourceBadges) -> Bool {
        lhs.isRunning == rhs.isRunning && lhs.metric == rhs.metric && lhs.isDarkMode == rhs.isDarkMode
    }

    var body: some View {
        if isRunning && metric.processCount > 0 {
            HStack(spacing: 6) {
                pill(
                    icon: metric.cpuPercent > 15 ? "bolt.fill" : "cpu",
                    text: metric.cpuLabel,
                    foreground: metric.cpuPercent > 15 ? .cyan : .secondary,
                    background: metric.cpuPercent > 15 ? Color.cyan.opacity(isDarkMode ? 0.16 : 0.10) : Color.primary.opacity(isDarkMode ? 0.06 : 0.04),
                    border: metric.cpuPercent > 15 ? Color.cyan.opacity(0.30) : Color.primary.opacity(0.06)
                )

                pill(
                    icon: "memorychip.fill",
                    text: metric.memoryLabel,
                    foreground: .secondary,
                    background: Color.primary.opacity(isDarkMode ? 0.06 : 0.04),
                    border: Color.primary.opacity(0.06)
                )
            }
        }
    }

    private func pill(icon: String, text: String, foreground: Color, background: Color, border: Color) -> some View {
        HStack(alignment: .center, spacing: 4.5) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
                .frame(width: 11, height: 11, alignment: .center)
                .opacity(0.75)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 7.5)
        .frame(height: 21)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(border, lineWidth: 0.8)
        }
    }
}

// MARK: - Thumbnail Grid Tile Card (Remote-Desktop / Mission-Control Style)

struct InstanceThumbnailTile: View {
    let item: ManagedInstance
    let activity: InstanceActivity
    let meta: InstanceUserMeta
    let resourceMetric: InstanceResourceMetric
    let diskUsage: InstanceDiskUsage
    let thumbnail: NSImage?
    let sourceVersion: String
    var duration: String? = nil
    let busy: Bool
    let canUpgrade: Bool
    let open: () -> Void
    let hideWindow: () -> Void
    let quit: () -> Void
    let upgrade: () -> Void
    let reveal: () -> Void
    let revealProfile: () -> Void
    let logs: () -> Void
    let verify: () -> Void
    let editMeta: () -> Void
    let clearWorkspace: () -> Void
    let destroy: () -> Void

    @State private var hovered = false
    @State private var showMorePopover = false
    @State private var scanProgress = false
    @Environment(\.colorScheme) private var colorScheme

    private var hasPendingUpgrade: Bool {
        !item.isOriginal && item.version.compare(sourceVersion, options: .numeric) == .orderedAscending
    }

    private var borderTint: Color {
        if item.isOriginal { return Color(red: 0.52, green: 0.32, blue: 0.98) }
        if !item.running { return .primary }
        switch activity.state {
        case .runningTask: return Color(red: 0.15, green: 0.82, blue: 0.96)
        case .needsAttention: return .orange
        case .error: return .red
        case .idle: return .green
        case .stopped: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            // 16:10 Miniature Monitor Screen Container
            ZStack {
                // Screen Background & Content
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.09, blue: 0.13),
                                Color(red: 0.12, green: 0.14, blue: 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if item.running, let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 158)
                        .clipped()
                        .opacity(item.running ? 0.96 : 0.72)
                } else if item.running {
                    syntheticLiveScreen
                } else {
                    stoppedScreen
                }

                // Top Screen Overlay Bar
                VStack {
                    HStack(alignment: .center, spacing: 6) {
                        // Top-left state badge
                        HStack(alignment: .center, spacing: 5) {
                            PulsingStatusDot(
                                active: item.running,
                                activeColor: activity.state.color,
                                pulse: item.running && (activity.state == .runningTask || activity.state == .needsAttention)
                            )
                            Text(item.running ? (item.isHidden ? "\(activity.state.label) · 后台实时" : activity.state.label) : "未启动")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(Color.black.opacity(0.62)))
                        .overlay(Capsule().strokeBorder(activity.state.color.opacity(0.45), lineWidth: 1))

                        if hasPendingUpgrade {
                            Text("可升 v\(sourceVersion)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6.5)
                                .frame(height: 20)
                                .background(Capsule().fill(Color.black.opacity(0.65)))
                                .overlay(Capsule().strokeBorder(Color.orange.opacity(0.45), lineWidth: 1))
                        }

                        // Real-time Resource Metric Capsule (CPU & Memory, Equatable Subtree)
                        InstanceThumbnailResourceBadge(isRunning: item.running, metric: resourceMetric)
                            .equatable()

                        if let duration {
                            HStack(alignment: .center, spacing: 3.5) {
                                Image(systemName: "stopwatch")
                                    .font(.system(size: 8.5))
                                Text(duration)
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(Color.cyan)
                            .padding(.horizontal, 6.5)
                            .frame(height: 22)
                            .background(Capsule().fill(Color.black.opacity(0.62)))
                            .overlay(Capsule().strokeBorder(Color.cyan.opacity(0.45), lineWidth: 1))
                        }

                        Spacer()

                        // Top-Right [...] Menu Button
                        Button {
                            showMorePopover.toggle()
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(hovered || showMorePopover ? 0.98 : 0.75))
                                .frame(width: 26, height: 26)
                                .background {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.black.opacity(hovered || showMorePopover ? 0.72 : 0.45))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.white.opacity(hovered || showMorePopover ? 0.35 : 0.18), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showMorePopover, arrowEdge: .bottom) {
                            tilePopoverMenu
                        }
                    }
                    .padding(10)

                    Spacer()

                    // Bottom Live Task Telemetry Caption Bar
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: item.running ? activity.state.symbol : (activity.currentAction.hasPrefix("上次：") ? "clock.arrow.circlepath" : "circle"))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(item.running ? activity.state.color : Color.secondary)
                            .frame(width: 13, height: 13, alignment: .center)

                        Text(item.running ? activity.currentAction : (activity.currentAction.hasPrefix("上次：") ? activity.currentAction : "点击缩略图启动实例"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        if !activity.workspace.isEmpty {
                            Text(activity.workspace)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.70))
                                .lineLimit(1)
                        } else if !activity.lastUpdatedLabel.isEmpty {
                            Text(activity.lastUpdatedLabel)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.60))
                        }

                        if diskUsage.totalDataBytes > 0 {
                            Text("· 💾 \(diskUsage.formattedTotalData)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                                .help("独立工作空间与数据占用：\(diskUsage.formattedTotalData)（工作空间 \(diskUsage.formattedProfile) · 缓存 \(diskUsage.formattedUserData) · 程序包 \(diskUsage.formattedAppBundle)）")
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.black.opacity(0.68))
                }

                // Center Play / Switch Action Overlay
                centerPlayOverlay
            }
            .frame(height: 158)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        item.isOriginal
                            ? Color(red: 0.52, green: 0.32, blue: 0.98).opacity(hovered ? 0.95 : 0.70)
                            : (item.running
                                ? borderTint.opacity(hovered ? 0.85 : (activity.state == .runningTask || activity.state == .needsAttention ? 0.65 : 0.35))
                                : Color.primary.opacity(hovered ? 0.30 : 0.12)),
                        lineWidth: (item.isOriginal || hovered || activity.state == .runningTask || activity.state == .needsAttention) ? 1.6 : 1
                    )
            }
            .shadow(
                color: item.isOriginal
                    ? Color(red: 0.52, green: 0.32, blue: 0.98).opacity(0.28)
                    : ((item.running && activity.state == .runningTask)
                        ? borderTint.opacity(0.22)
                        : Color.black.opacity(hovered ? 0.25 : 0.12)),
                radius: (item.isOriginal || hovered) ? 12 : 6,
                x: 0,
                y: hovered ? 5 : 2
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .onTapGesture {
                open()
            }

            // Bottom Instance Name Pill
            HStack(alignment: .center, spacing: 6) {
                if item.isOriginal {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                        Text("MAIN 01")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(LinearGradient(colors: [Color(red: 0.52, green: 0.28, blue: 0.98), Color(red: 0.22, green: 0.46, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Color(red: 0.50, green: 0.28, blue: 0.98).opacity(0.35), radius: 4, y: 1)
                    }
                } else {
                    Text("#\(String(format: "%02d", item.index))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(item.running ? borderTint : accent)
                        .padding(.horizontal, 5.5)
                        .frame(height: 18)
                        .background {
                            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                .fill(item.running ? borderTint.opacity(0.18) : accent.opacity(0.12))
                        }
                }

                if !meta.tag.isEmpty {
                    Text(meta.tag)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(meta.color)
                        .padding(.horizontal, 5)
                        .frame(height: 17)
                        .background(Capsule().fill(meta.color.opacity(colorScheme == .dark ? 0.20 : 0.12)))
                        .overlay(Capsule().strokeBorder(meta.color.opacity(0.35), lineWidth: 0.8))
                }

                Text(meta.nickname.isEmpty ? item.name : meta.nickname)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !meta.nickname.isEmpty {
                    Text("(\(item.name.replacingOccurrences(of: "Antigravity", with: "").trimmingCharacters(in: .whitespaces).isEmpty ? "Main" : item.name.replacingOccurrences(of: "Antigravity", with: "").trimmingCharacters(in: .whitespaces)))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !activity.workspace.isEmpty {
                    Text("· \(activity.workspace)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !meta.notes.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "note.text")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4.5)
                    .frame(height: 16)
                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                    .help("备注：\(meta.notes)")
                }

                Button(action: editMeta) {
                    Image(systemName: meta.hasCustomContent ? "tag.fill" : "tag")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(meta.hasCustomContent ? meta.color : .secondary.opacity(0.8))
                        .frame(width: 15, height: 15)
                }
                .buttonStyle(.plain)
                .help("编辑此实例的项目别名与标签")
            }
            .padding(.horizontal, 11)
            .frame(height: 26)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(item.isOriginal
                        ? Color(red: 0.52, green: 0.28, blue: 0.98).opacity(colorScheme == .dark ? 0.12 : 0.08)
                        : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(item.isOriginal
                        ? Color(red: 0.52, green: 0.32, blue: 0.98).opacity(0.35)
                        : Color.primary.opacity(hovered ? 0.18 : 0.07), lineWidth: 1)
            }
        }
        .scaleEffect(hovered ? 1.018 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: hovered)
        .onHover { hovered = $0 }
    }

    // Center Play / Focus Overlay
    @ViewBuilder
    private var centerPlayOverlay: some View {
        if !item.running {
            // Stopped: Prominent Play Button over Instance Emblem (exact match to screenshot)
            Button(action: open) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(hovered ? 0.78 : 0.58))
                        .frame(width: 54, height: 40)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(hovered ? 0.35 : 0.18), lineWidth: 1)
                        }
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(hovered ? 1.0 : 0.82))
                        .offset(x: 1)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(hovered ? 1.08 : 1.0)
        } else if hovered {
            // Running & Hovered: Quick Focus + Collapse/Hide buttons
            HStack(alignment: .center, spacing: 8) {
                Button(action: open) {
                    HStack(alignment: .center, spacing: 5) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text(item.isHidden ? "恢复窗口" : "调出实例")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Capsule().fill(accent))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                }
                .buttonStyle(.plain)

                if !item.isHidden {
                    Button(action: hideWindow) {
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("收起")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.black.opacity(0.75)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("隐藏窗口回到缩略图监控台（后台任务继续运行）")
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    // Stopped Screen Backdrop
    private var stoppedScreen: some View {
        ZStack {
            // Subtle perspective window panes (echoing the screenshot's geometric window icon)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: item.isOriginal
                            ? [Color(red: 0.20, green: 0.44, blue: 0.92).opacity(0.45), Color(red: 0.36, green: 0.25, blue: 0.85).opacity(0.25)]
                            : [accent.opacity(0.32), Color.indigo.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 86, height: 68)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                }
                .offset(y: -4)
        }
    }

    // Synthetic Live IDE Screen when running without screen recording or before first capture
    private var syntheticLiveScreen: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer().frame(height: 28)
            HStack(alignment: .center, spacing: 6) {
                Circle().fill(Color.red.opacity(0.75)).frame(width: 6, height: 6)
                Circle().fill(Color.yellow.opacity(0.75)).frame(width: 6, height: 6)
                Circle().fill(Color.green.opacity(0.75)).frame(width: 6, height: 6)
                Text(activity.workspace.isEmpty ? item.profile : activity.workspace)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Spacer()
                if activity.stepIndex > 0 {
                    Text("Step #\(activity.stepIndex)")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(activity.state.color)
                }
            }
            .padding(.horizontal, 12)

            // Simulated live agent workspace lines
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(activity.state.color.opacity(0.85))
                        .frame(width: 3, height: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(activity.state == .runningTask ? "AGENT EXECUTING TASK" : (activity.state == .needsAttention ? "WAITING FOR USER INPUT" : "AGENT READY"))
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(activity.state.color)
                        Text(activity.currentAction)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                    }
                }

                if activity.state == .runningTask {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.10)).frame(height: 3)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [activity.state.color.opacity(0.3), activity.state.color, .white],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * 0.45, height: 3)
                                .offset(x: scanProgress ? geo.size.width * 0.55 : 0)
                        }
                    }
                    .frame(height: 3)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            scanProgress = true
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            }
            .padding(.horizontal, 10)

            Spacer()
        }
    }

    private var tilePopoverMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            tileMenuItem(title: "编辑项目备注与标签…", symbol: "tag") {
                showMorePopover = false
                editMeta()
            }

            Divider().padding(.vertical, 3)

            tileMenuItem(
                title: item.running ? (item.isHidden ? "恢复并调出窗口" : "调出并置顶窗口") : "启动此实例",
                symbol: item.running ? "macwindow.on.rectangle" : "play.fill"
            ) {
                showMorePopover = false
                open()
            }

            if item.running && !item.isHidden {
                tileMenuItem(title: "收起回监控台（后台继续跑）", symbol: "eye.slash") {
                    showMorePopover = false
                    hideWindow()
                }
            }

            Divider().padding(.vertical, 3)

            if hasPendingUpgrade {
                tileMenuItem(title: "升级至 v\(sourceVersion)…", symbol: "arrow.up.circle") {
                    showMorePopover = false
                    upgrade()
                }
            }

            tileMenuItem(title: "在访达中显示", symbol: "folder") {
                showMorePopover = false
                reveal()
            }

            tileMenuItem(title: "在访达中显示独立工作空间", symbol: "internaldrive") {
                showMorePopover = false
                revealProfile()
            }

            tileMenuItem(title: "查看运行日志", symbol: "doc.text.magnifyingglass") {
                showMorePopover = false
                logs()
            }

            if item.index >= 8 && !item.isOriginal {
                tileMenuItem(
                    title: item.verified ? "取消登录验证标记" : "标记已完成登录验证",
                    symbol: item.verified ? "xmark.seal" : "checkmark.seal"
                ) {
                    showMorePopover = false
                    verify()
                }
            }

            if item.running {
                Divider().padding(.vertical, 3)
                tileMenuItem(title: "正常退出实例", symbol: "stop.circle", destructive: true) {
                    showMorePopover = false
                    quit()
                }
            }

            if !item.isOriginal && (2...9999).contains(item.index) {
                Divider().padding(.vertical, 3)
                tileMenuItem(
                    title: "清空工作空间…",
                    symbol: "eraser.line.dashed",
                    destructive: true,
                    disabled: item.running
                ) {
                    showMorePopover = false
                    clearWorkspace()
                }
                tileMenuItem(title: "销毁实例…", symbol: "trash", destructive: true) {
                    showMorePopover = false
                    destroy()
                }
            }
        }
        .padding(6)
        .frame(width: 196)
    }

    private func tileMenuItem(
        title: String,
        symbol: String,
        destructive: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 15, height: 15, alignment: .center)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Spacer()
            }
            .foregroundStyle(destructive ? Color.red : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }
}

extension InstanceThumbnailTile: Equatable {
    static func == (lhs: InstanceThumbnailTile, rhs: InstanceThumbnailTile) -> Bool {
        lhs.item == rhs.item &&
        lhs.activity == rhs.activity &&
        lhs.meta == rhs.meta &&
        lhs.resourceMetric == rhs.resourceMetric &&
        lhs.diskUsage == rhs.diskUsage &&
        lhs.thumbnail === rhs.thumbnail &&
        lhs.sourceVersion == rhs.sourceVersion &&
        lhs.duration == rhs.duration &&
        lhs.busy == rhs.busy &&
        lhs.canUpgrade == rhs.canUpgrade
    }
}

// MARK: - Detailed List Instance Card View

struct InstanceCard: View {
    let item: ManagedInstance
    let activity: InstanceActivity
    let meta: InstanceUserMeta
    let resourceMetric: InstanceResourceMetric
    let diskUsage: InstanceDiskUsage
    let sourceVersion: String
    let busy: Bool
    let canUpgrade: Bool
    let upgrade: () -> Void
    let open: () -> Void
    let hideWindow: () -> Void
    let quit: () -> Void
    let reveal: () -> Void
    let revealProfile: () -> Void
    let logs: () -> Void
    let verify: () -> Void
    let editMeta: () -> Void
    let clearWorkspace: () -> Void
    let destroy: () -> Void

    @State private var hovered = false
    @State private var showMorePopover = false
    @Environment(\.colorScheme) private var colorScheme

    private var hasPendingUpgrade: Bool {
        !item.isOriginal && item.version.compare(sourceVersion, options: .numeric) == .orderedAscending
    }

    private var badgeGradient: LinearGradient {
        if item.isOriginal {
            return LinearGradient(
                colors: [Color(red: 0.52, green: 0.28, blue: 0.98), Color(red: 0.22, green: 0.46, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if item.running {
            return LinearGradient(
                colors: [activity.state.color.opacity(0.22), accent.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [accent.opacity(0.14), accent.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            // Left Identity Emblem (48x48 matches 22 + 4 + 22 = 48pt center block)
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(badgeGradient)
                    .frame(width: 48, height: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(
                                item.isOriginal
                                    ? Color.white.opacity(0.28)
                                    : (item.running ? activity.state.color.opacity(0.45) : accent.opacity(0.22)),
                                lineWidth: 1.2
                            )
                    }

                if item.isOriginal {
                    VStack(spacing: 1.5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                        Text("MAIN")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .tracking(0.6)
                    }
                    .foregroundStyle(.white)
                } else {
                    VStack(spacing: 0.5) {
                        Text("#\(String(format: "%02d", item.index))")
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(item.running ? activity.state.color : accent)
                        Text("CLONE")
                            .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Center Metadata & Badges (Exact 48pt height: 22pt top row + 4pt gap + 22pt bottom row)
            VStack(alignment: .leading, spacing: 4) {
                // Top Row: Title + Live Task Status Pill + Role/Verified Pill
                HStack(alignment: .center, spacing: 8) {
                    if !meta.tag.isEmpty {
                        Text(meta.tag)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(meta.color)
                            .padding(.horizontal, 6)
                            .frame(height: 20)
                            .background(Capsule().fill(meta.color.opacity(colorScheme == .dark ? 0.20 : 0.12)))
                            .overlay(Capsule().strokeBorder(meta.color.opacity(0.35), lineWidth: 0.8))
                    }

                    Text(meta.nickname.isEmpty ? item.name : meta.nickname)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.primary)

                    if !meta.nickname.isEmpty {
                        Text("(\(item.name))")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    // Live Task State Pill (Fixed 20pt height)
                    HStack(alignment: .center, spacing: 5) {
                        PulsingStatusDot(
                            active: item.running,
                            activeColor: activity.state.color,
                            pulse: item.running && (activity.state == .runningTask || activity.state == .needsAttention)
                        )
                        Text(item.running ? (item.isHidden ? "\(activity.state.label) · 已收起" : activity.state.label) : "未启动")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(item.running ? activity.state.color : Color.secondary)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background {
                        Capsule()
                            .fill(item.running
                                  ? activity.state.color.opacity(colorScheme == .dark ? 0.14 : 0.10)
                                  : Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.045))
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(item.running ? activity.state.color.opacity(0.30) : Color.primary.opacity(0.08), lineWidth: 1)
                    }

                    if item.isOriginal {
                        Text("官方主实例源")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(Capsule().fill(accent.opacity(0.12)))
                            .overlay(Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 1))
                    } else if item.verified {
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 11, height: 11, alignment: .center)
                            Text("已验证")
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Capsule().fill(Color.green.opacity(0.11)))
                        .overlay(Capsule().strokeBorder(Color.green.opacity(0.25), lineWidth: 1))
                    }

                    if item.running {
                        Text(activity.currentAction)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if !meta.notes.isEmpty {
                        HStack(spacing: 3.5) {
                            Image(systemName: "note.text")
                                .font(.system(size: 9.5))
                            Text(meta.notes)
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.8))
                        .help("实例备注：\(meta.notes)")
                    }
                }
                .frame(height: 22)

                // Bottom Row: Uniform 22pt Technical Pills
                HStack(alignment: .center, spacing: 7) {
                    if hasPendingUpgrade {
                        metaPill(
                            icon: "arrow.up.right.circle.fill",
                            text: "v\(item.version) → v\(sourceVersion)",
                            foreground: .orange,
                            background: Color.orange.opacity(colorScheme == .dark ? 0.16 : 0.11),
                            border: Color.orange.opacity(0.32),
                            bold: true
                        )
                    } else {
                        metaPill(
                            icon: "tag.fill",
                            text: "v\(item.version)",
                            foreground: .secondary,
                            background: Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04),
                            border: Color.primary.opacity(0.06)
                        )
                    }

                    metaPill(
                        icon: "folder.fill",
                        text: item.profile,
                        foreground: .secondary,
                        background: Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04),
                        border: Color.primary.opacity(0.06)
                    )

                    if !item.isOriginal {
                        metaPill(
                            icon: "link",
                            text: "\(item.callbackScheme)://",
                            foreground: .secondary.opacity(0.85),
                            background: Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.03),
                            border: Color.primary.opacity(0.05)
                        )
                    }

                    if diskUsage.totalDataBytes > 0 {
                        metaPill(
                            icon: "internaldrive",
                            text: "💾 \(diskUsage.formattedTotalData)",
                            foreground: .secondary,
                            background: Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04),
                            border: Color.primary.opacity(0.06)
                        )
                        .help("工作空间与存储：工作空间 \(diskUsage.formattedProfile) · 缓存 \(diskUsage.formattedUserData) · 程序包 \(diskUsage.formattedAppBundle)")
                    }

                    InstanceCardResourceBadges(
                        isRunning: item.running,
                        metric: resourceMetric,
                        isDarkMode: colorScheme == .dark
                    )
                    .equatable()

                    Button(action: editMeta) {
                        metaPill(
                            icon: meta.hasCustomContent ? "tag.fill" : "tag",
                            text: meta.hasCustomContent ? (meta.nickname.isEmpty ? meta.tag : meta.nickname) : "添加备注",
                            foreground: meta.hasCustomContent ? meta.color : .secondary,
                            background: meta.hasCustomContent ? meta.color.opacity(colorScheme == .dark ? 0.14 : 0.08) : Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04),
                            border: meta.hasCustomContent ? meta.color.opacity(0.28) : Color.primary.opacity(0.06)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("编辑此实例的项目别名与标签")
                }
                .frame(height: 22)
                .lineLimit(1)
            }

            Spacer(minLength: 10)

            // Right Action Cluster (All buttons strictly 30pt height & centered)
            HStack(alignment: .center, spacing: 7) {
                if hasPendingUpgrade {
                    Button(action: upgrade) {
                        HStack(alignment: .center, spacing: 4.5) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 11.5, weight: .semibold))
                                .frame(width: 13, height: 13, alignment: .center)
                            Text("升级")
                        }
                    }
                    .buttonStyle(ModernButtonStyle(variant: .upgrade, compact: true))
                    .disabled(busy || !canUpgrade)
                }

                if item.running && !item.isHidden {
                    IconActionButton(symbol: "eye.slash", tooltip: "收起隐藏窗口（后台继续跑任务）", size: 30, action: hideWindow)
                }

                IconActionButton(symbol: "folder", tooltip: "在访达中显示应用", size: 30, action: reveal)
                IconActionButton(symbol: "doc.text.magnifyingglass", tooltip: "查看运行日志", size: 30, action: logs)

                IconActionButton(symbol: "ellipsis", tooltip: "更多实例操作", size: 30) {
                    showMorePopover.toggle()
                }
                .popover(isPresented: $showMorePopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        popoverMenuButton(
                            title: "编辑项目备注与标签…",
                            symbol: "tag",
                            destructive: false
                        ) {
                            showMorePopover = false
                            editMeta()
                        }
                        popoverMenuButton(
                            title: "在访达中显示独立工作空间",
                            symbol: "internaldrive",
                            destructive: false
                        ) {
                            showMorePopover = false
                            revealProfile()
                        }
                        Divider().padding(.vertical, 3)

                        if item.index >= 8 {
                            popoverMenuButton(
                                title: item.verified ? "取消登录验证标记" : "标记已完成登录验证",
                                symbol: item.verified ? "xmark.seal" : "checkmark.seal",
                                destructive: false
                            ) {
                                showMorePopover = false
                                verify()
                            }
                            Divider().padding(.vertical, 3)
                        }
                        if !item.isOriginal {
                            popoverMenuButton(
                                title: "清空工作空间…",
                                symbol: "eraser.line.dashed",
                                destructive: true,
                                disabled: item.running
                            ) {
                                showMorePopover = false
                                clearWorkspace()
                            }
                            popoverMenuButton(
                                title: "销毁实例…",
                                symbol: "trash",
                                destructive: true
                            ) {
                                showMorePopover = false
                                destroy()
                            }
                        }
                    }
                    .padding(6)
                    .frame(width: 176)
                }

                if item.running {
                    Button(action: quit) {
                        HStack(alignment: .center, spacing: 4.5) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 9.5, weight: .semibold))
                                .frame(width: 11, height: 11, alignment: .center)
                            Text("退出")
                        }
                    }
                    .buttonStyle(ModernButtonStyle(variant: .danger, compact: true))
                    .help("正常退出实例；请先保存未完成的工作。")
                    .disabled(busy)
                }

                Button(action: open) {
                    HStack(alignment: .center, spacing: 4.5) {
                        Image(systemName: item.running ? "macwindow.on.rectangle" : "play.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .frame(width: 12, height: 12, alignment: .center)
                        Text(item.running ? (item.isHidden ? "恢复" : "切换") : "打开")
                    }
                }
                .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .systemSurface(
            radius: 16,
            isHighlighted: hovered || item.isOriginal,
            tint: item.isOriginal ? Color(red: 0.52, green: 0.32, blue: 0.98) : (item.running ? activity.state.color : nil)
        )
        .scaleEffect(hovered ? 1.003 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.80), value: hovered)
        .onHover { hovered = $0 }
    }

    private func metaPill(
        icon: String,
        text: String,
        foreground: Color,
        background: Color,
        border: Color,
        bold: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 4.5) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
                .frame(width: 11, height: 11, alignment: .center)
                .opacity(bold ? 1.0 : 0.75)
            Text(text)
                .font(.system(size: 11, weight: bold ? .semibold : .medium, design: .monospaced))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 7.5)
        .frame(height: 21)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        }
    }

    private func popoverMenuButton(
        title: String,
        symbol: String,
        destructive: Bool,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 15, height: 15, alignment: .center)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Spacer()
            }
            .foregroundStyle(destructive ? Color.red : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }
}

extension InstanceCard: Equatable {
    static func == (lhs: InstanceCard, rhs: InstanceCard) -> Bool {
        lhs.item == rhs.item &&
        lhs.activity == rhs.activity &&
        lhs.meta == rhs.meta &&
        lhs.resourceMetric == rhs.resourceMetric &&
        lhs.diskUsage == rhs.diskUsage &&
        lhs.sourceVersion == rhs.sourceVersion &&
        lhs.busy == rhs.busy &&
        lhs.canUpgrade == rhs.canUpgrade
    }
}

// MARK: - Official Release Notes WebView

struct OfficialReleaseNotesView: NSViewRepresentable {
    let fromVersions: [String]
    let targetVersion: String

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        view.loadHTMLString(Self.page("<p>正在读取官方更新日志…</p>"), baseURL: nil)
        let request = URLRequest(url: URL(string: "https://www.antigravity.google/docs/changelog?tab=hub")!, timeoutInterval: 20)
        URLSession.shared.dataTask(with: request) { [weak view] data, response, error in
            let content: String
            if error == nil, (response as? HTTPURLResponse)?.statusCode == 200,
               let data, let html = String(data: data, encoding: .utf8) {
                content = Self.extract(html, from: fromVersions, to: targetVersion)
            } else {
                content = "<p>官方日志加载失败。可查看上方中文摘要，或通过官方链接查看完整日志。</p>"
            }
            DispatchQueue.main.async { view?.loadHTMLString(Self.page(content), baseURL: request.url) }
        }.resume()
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}

    static func extract(_ html: String, from versions: [String], to target: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"<article\b[^>]*id="rel-hub-([0-9.]+)"[^>]*>[\s\S]*?</article>"#) else { return "" }
        let source = html as NSString
        let rows = regex.matches(in: html, range: NSRange(location: 0, length: source.length)).filter { match in
            let version = source.substring(with: match.range(at: 1))
            return version.compare(target, options: .numeric) != .orderedDescending &&
                versions.contains { $0.compare(version, options: .numeric) == .orderedAscending }
        }.map { source.substring(with: $0.range) }
        guard !rows.isEmpty else { return "<p>官方页面暂未提供此版本区间的日志，请查看中文摘要或官方链接。</p>" }
        return rows.joined().replacingOccurrences(of: "<details ", with: "<details open ")
            .replacingOccurrences(of: #"<svg\b[\s\S]*?</svg>"#, with: "", options: .regularExpression)
    }
    static func page(_ content: String) -> String {
        """
        <!doctype html><html><head><meta name="color-scheme" content="light dark">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
        <style>
        body{margin:0;background:transparent;color:#222;font:12px -apple-system;line-height:1.65}
        @media(prefers-color-scheme:dark){body{color:#e5e7eb}}
        article{padding:0 12px 12px 0}article+article{border-top:1px solid #8884;padding-top:16px}
        h3{margin:8px 0;font-size:14px}p{margin:8px 0}ul{padding-left:20px}li{margin:7px 0}
        time,.rn-latest-tag{opacity:.65;font-size:11px}a{color:inherit;text-decoration:none}
        summary{font-weight:600;margin-top:12px}.rn-count{margin-left:5px}
        </style></head><body>\(content)</body></html>
        """
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url,
               url.scheme == "https", url.host == "www.antigravity.google" || url.host == "antigravity.google" {
                NSWorkspace.shared.open(url); decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
    }
}

// MARK: - Edit Instance Meta Sheet

struct EditInstanceMetaSheet: View {
    let item: ManagedInstance
    let initialMeta: InstanceUserMeta
    let diskUsage: InstanceDiskUsage
    let onRecalculateDisk: () -> Void
    let onSave: (InstanceUserMeta) -> Void
    let onDismiss: () -> Void

    @State private var nickname: String = ""
    @State private var tag: String = ""
    @State private var selectedColor: String = "blue"
    @State private var notes: String = ""
    @State private var recalculatingDisk = false
    @Environment(\.colorScheme) private var colorScheme

    private let presetColors: [(id: String, name: String, color: Color)] = [
        ("blue", "海天蓝", .blue),
        ("purple", "星云紫", .purple),
        ("green", "薄荷绿", .green),
        ("orange", "暖阳橙", .orange),
        ("pink", "霓虹粉", .pink),
        ("teal", "青碧绿", .teal),
        ("indigo", "极光靛", .indigo)
    ]

    private let presetTags = ["生产环境", "微服务后端", "前端 UI", "数据清洗", "核心架构", "算法评测", "学习调试"]

    init(
        item: ManagedInstance,
        initialMeta: InstanceUserMeta,
        diskUsage: InstanceDiskUsage,
        onRecalculateDisk: @escaping () -> Void,
        onSave: @escaping (InstanceUserMeta) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.initialMeta = initialMeta
        self.diskUsage = diskUsage
        self.onRecalculateDisk = onRecalculateDisk
        self.onSave = onSave
        self.onDismiss = onDismiss
        _nickname = State(initialValue: initialMeta.nickname)
        _tag = State(initialValue: initialMeta.tag)
        _selectedColor = State(initialValue: initialMeta.tagColor)
        _notes = State(initialValue: initialMeta.notes)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "tag.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("编辑实例项目标签、备注与磁盘")
                        .font(.system(size: 14.5, weight: .bold))
                    Text("\(item.name) · \(item.profile)")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // Nickname
                    VStack(alignment: .leading, spacing: 5) {
                        Text("项目别名 / 显示名称")
                            .font(.system(size: 12, weight: .medium))
                        TextField("例如：核心后端微服务 / Web 前端开发", text: $nickname)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5))
                    }

                    // Tag
                    VStack(alignment: .leading, spacing: 5) {
                        Text("分类标签")
                            .font(.system(size: 12, weight: .medium))
                        TextField("例如：生产 / 测试 / 开发", text: $tag)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5))

                        // Preset Tag Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(presetTags, id: \.self) { preset in
                                    Button {
                                        tag = preset
                                    } label: {
                                        Text(preset)
                                            .font(.system(size: 10.5))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3.5)
                                            .background(Capsule().fill(Color.primary.opacity(tag == preset ? 0.14 : 0.05)))
                                            .foregroundStyle(tag == preset ? Color.primary : Color.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    // Color Picker
                    VStack(alignment: .leading, spacing: 5) {
                        Text("标签主题色")
                            .font(.system(size: 12, weight: .medium))
                        HStack(spacing: 12) {
                            ForEach(presetColors, id: \.id) { preset in
                                Button {
                                    selectedColor = preset.id
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(preset.color)
                                            .frame(width: 22, height: 22)
                                        if selectedColor == preset.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // Notes / Memo
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("实例备注 / 备忘说明")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("可记录当前开发目标、Git 分支或配置细节")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("例如：负责支付网关重构；当前 Git 分支 feature/v2-pay；本地已映射 8080 端口；注意勿清空临时测试缓存...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondary.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                            }
                            TextEditor(text: $notes)
                                .font(.system(size: 12))
                                .frame(height: 64)
                                .padding(4)
                                .background(Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.02))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                        }
                    }

                    // Disk Usage Analysis Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            HStack(spacing: 5) {
                                Image(systemName: "internaldrive.fill")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(.cyan)
                                Text("工作空间与存储空间占用")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Spacer()
                            Button {
                                recalculatingDisk = true
                                onRecalculateDisk()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    recalculatingDisk = false
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10))
                                        .rotationEffect(.degrees(recalculatingDisk ? 360 : 0))
                                        .animation(recalculatingDisk ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: recalculatingDisk)
                                    Text("重新统计")
                                        .font(.system(size: 10.5))
                                }
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 6) {
                            diskStorageRow(
                                title: "独立工作空间",
                                path: item.profile,
                                sizeText: diskUsage.formattedProfile,
                                icon: "folder.fill",
                                color: .indigo,
                                action: { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.profileURL.path) }
                            )

                            diskStorageRow(
                                title: "应用配置与缓存",
                                path: "Application Support/\(item.isOriginal ? "Antigravity" : item.name)",
                                sizeText: diskUsage.formattedUserData,
                                icon: "externaldrive.fill",
                                color: .teal,
                                action: { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.userDataURL.path) }
                            )

                            diskStorageRow(
                                title: "应用程序包",
                                path: item.path.lastPathComponent,
                                sizeText: diskUsage.formattedAppBundle,
                                icon: "macwindow",
                                color: .secondary,
                                action: { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.path.path) }
                            )
                        }
                        .padding(9)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.035)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))

                        HStack(spacing: 8) {
                            Text("合计数据占用：")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(diskUsage.formattedTotalData)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text("含程序包总计：")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(diskUsage.formattedTotal)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.cyan)
                            Spacer()
                        }
                        .padding(.horizontal, 2)
                    }

                    // Preview Capsule
                    HStack(spacing: 8) {
                        Text("效果预览：")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        if !tag.isEmpty {
                            Text(tag)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(InstanceUserMeta(tagColor: selectedColor).color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(InstanceUserMeta(tagColor: selectedColor).color.opacity(0.15)))
                        }
                        Text(nickname.isEmpty ? item.name : nickname)
                            .font(.system(size: 12, weight: .semibold))

                        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Image(systemName: "note.text")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                        }

                        if diskUsage.totalDataBytes > 0 {
                            Text("💾 \(diskUsage.formattedTotalData)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                }
                .padding(.horizontal, 1)
            }
            .frame(maxHeight: 480)

            // Buttons
            HStack(spacing: 10) {
                if initialMeta.hasCustomContent {
                    Button("清除自定义备注", role: .destructive) {
                        onSave(InstanceUserMeta())
                    }
                    .buttonStyle(ModernButtonStyle(variant: .danger, compact: true))
                }
                Spacer()
                Button("取消", action: onDismiss)
                    .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))
                    .keyboardShortcut(.cancelAction)
                Button("保存备注与标签") {
                    onSave(InstanceUserMeta(
                        nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                        tag: tag.trimmingCharacters(in: .whitespacesAndNewlines),
                        tagColor: selectedColor,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
                .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))
                .keyboardShortcut(.return, modifiers: .command)
                .help("保存修改 (快捷键: ⌘ + Enter)")
            }
        }
        .padding(22)
        .frame(width: 470)
    }

    private func diskStorageRow(title: String, path: String, sizeText: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
            Text("(\(path))")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer()
            Text(sizeText)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Button(action: action) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("在访达中显示该目录")
        }
    }
}

// MARK: - Upgrade Confirmation Sheet

struct UpgradeRequest: Identifiable {
    let id = UUID()
    let instances: [ManagedInstance]
}

struct UpgradeConfirmationView: View {
    let instances: [ManagedInstance]
    let targetVersion: String
    let busy: Bool
    let cancel: () -> Void
    let confirm: () -> Void

    private var notes: [SourceReleaseNotes] {
        SourceReleaseNotes.bundled.filter { note in
            note.version.compare(targetVersion, options: .numeric) != .orderedDescending &&
            instances.contains { $0.version.compare(note.version, options: .numeric) == .orderedAscending }
        }.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(instances.count == 1 ? "升级指定副本" : "批量升级全部副本")
                        .font(.system(size: 19, weight: .bold))
                    Text("源版本 v\(targetVersion)  ·  共 \(instances.count) 个待升级实例  ·  自动完整备份")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("将要升级的实例")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(instances) { item in
                            HStack(alignment: .center) {
                                Text("#\(String(format: "%02d", item.index))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(accent)
                                    .frame(width: 28, alignment: .leading)
                                Text(item.name)
                                    .font(.system(size: 12.5, weight: .medium))
                                Spacer()
                                Text("v\(item.version) → v\(targetVersion)")
                                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.orange)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .padding(14)
                    .systemSurface(radius: 13)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center) {
                            HStack(alignment: .center, spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(accent)
                                    .frame(width: 15, height: 15, alignment: .center)
                                Text("中文重点更新摘要")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Spacer()
                            Link("查看官方完整更新日志 ↗", destination: URL(string: "https://www.antigravity.google/docs/changelog?tab=hub")!)
                                .font(.system(size: 11.5))
                        }

                        if notes.isEmpty {
                            Text("尚未收录此版本区间的更新摘要，可查看下方官方完整更新日志。")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(notes) { note in
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("v\(note.version)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(accent)
                                    ForEach(note.highlights, id: \.self) { text in
                                        HStack(alignment: .top, spacing: 6) {
                                            Text("•").foregroundStyle(accent)
                                            Text(text)
                                                .font(.system(size: 12))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .systemSurface(radius: 11)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("官方更新日志（原文）")
                            .font(.system(size: 14, weight: .semibold))
                        Text("联网读取官方原文，保留完整新增功能和修复条目。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        OfficialReleaseNotesView(fromVersions: instances.map(\.version), targetVersion: targetVersion)
                            .frame(height: 240)
                            .padding(10)
                            .systemSurface(radius: 12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 6)
            }
            .frame(height: 410)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                    .frame(width: 16, height: 16, alignment: .center)
                Text("升级前请先保存各副本中的工作。工具会先备份旧应用、账号目录和窗口缓存，再做原子替换。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 10) {
                Spacer()
                Button("取消", action: cancel)
                    .buttonStyle(ModernButtonStyle(variant: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("备份并升级", action: confirm)
                    .buttonStyle(ModernButtonStyle(variant: .upgrade))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(busy || instances.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 600)
    }
}

// MARK: - Main Content View

private enum ViewMode: String, CaseIterable, Identifiable {
    case grid = "缩略图墙"
    case list = "详细列表"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .grid: return "square.grid.2x2.fill"
        case .list: return "list.bullet.rectangle.fill"
        }
    }
}

private enum InstanceFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case running = "运行中"
    case busyTask = "跑任务中"
    case withTags = "带标签/备注"
    case upgradable = "可升级"
    var id: String { rawValue }
}

struct ContentView: View {
    let updaterController: SPUStandardUpdaterController
    @StateObject private var store = InstanceStore()
    @State private var viewMode: ViewMode = .grid
    @State private var showCreate = false
    @State private var upgradeRequest: UpgradeRequest?
    @State private var showBackupManager = false
    @State private var showUpdateSettings = false
    @State private var showTaskHistory = false
    @State private var pendingDestroy: ManagedInstance?
    @State private var pendingClear: ManagedInstance?
    @State private var editingMetaItem: ManagedInstance?
    @State private var showOptionsPopover = false
    @State private var destination = URL(fileURLWithPath: "/Applications")
    @State private var selectedFilter: InstanceFilter = .all
    @State private var refreshSpin: Double = 0
    @State private var logExpanded = true
    @State private var appeared = false
    @Environment(\.colorScheme) private var colorScheme

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.6.6"
    }

    private func matchesFilter(_ item: ManagedInstance) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .running:
            return item.running
        case .busyTask:
            let state = store.activity(for: item).state
            return item.running && (state == .runningTask || state == .needsAttention)
        case .withTags:
            return store.meta(for: item).hasCustomContent
        case .upgradable:
            return !item.isOriginal && item.version.compare(store.sourceVersion, options: .numeric) == .orderedAscending
        }
    }

    private var filteredInstances: [ManagedInstance] {
        store.instances.filter(matchesFilter)
    }

    private var filteredClones: [ManagedInstance] {
        store.cloneInstances.filter(matchesFilter)
    }

    private var compatibilityColor: Color {
        switch store.compatibility {
        case "已支持本机版本": return .green
        case "版本待适配": return .orange
        default: return .red
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                Rectangle().fill(.regularMaterial)
                LinearGradient(
                    colors: [
                        accent.opacity(colorScheme == .dark ? 0.09 : 0.05),
                        Color.clear,
                        Color.purple.opacity(colorScheme == .dark ? 0.05 : 0.025)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerDashboard
                        metricsStrip
                        controlToolbar

                        if store.instances.isEmpty {
                            emptyStateView
                        } else if viewMode == .grid {
                            thumbnailWallSection
                        } else {
                            if let primary = store.primaryInstance {
                                primarySection(primary)
                            }
                            clonesSection
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 22)
                    .padding(.bottom, (store.busy || !store.output.isEmpty) ? (logExpanded ? 230 : 76) : 28)
                }
            }

            if store.busy || !store.output.isEmpty {
                operationConsoleDrawer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 860, minHeight: 640)
        .onAppear {
            store.refresh()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                appeared = true
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
            store.refreshRunningStates()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            store.refreshRunningStates()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in
            store.refreshRunningStates()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didHideApplicationNotification)) { _ in
            store.refreshRunningStates()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnhideApplicationNotification)) { _ in
            store.refreshRunningStates()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.checkScreenCapturePermission()
            store.refreshRunningStates()
        }
        .onReceive(Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()) { _ in
            store.periodicTick()
        }
        .sheet(isPresented: $showCreate) {
            createInstanceSheet
        }
        .sheet(item: $upgradeRequest) { request in
            UpgradeConfirmationView(
                instances: request.instances,
                targetVersion: store.sourceVersion,
                busy: store.busy,
                cancel: { upgradeRequest = nil },
                confirm: { store.upgrade(request.instances); upgradeRequest = nil }
            )
        }
        .sheet(isPresented: $showUpdateSettings) {
            UpdateSettingsView(updater: updaterController.updater)
        }
        .sheet(isPresented: $showBackupManager) {
            BackupManagementView(store: store)
        }
        .sheet(item: $pendingDestroy) { item in
            DestroyInstanceView(item: item, busy: store.busy) {
                store.destroy(item)
                pendingDestroy = nil
            }
        }
        .sheet(item: $pendingClear) { item in
            ClearWorkspaceView(item: item, busy: store.busy) {
                store.clearWorkspace(item)
                pendingClear = nil
            }
        }
        .sheet(item: $editingMetaItem) { item in
            EditInstanceMetaSheet(
                item: item,
                initialMeta: store.meta(for: item),
                diskUsage: store.diskUsage(for: item),
                onRecalculateDisk: {
                    store.recalculateDiskUsage(for: item)
                },
                onSave: { newMeta in
                    store.saveInstanceMeta(for: item.id, meta: newMeta)
                    editingMetaItem = nil
                },
                onDismiss: {
                    editingMetaItem = nil
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTaskHistoryRequested)) { _ in
            showTaskHistory = true
        }
        .sheet(isPresented: $showTaskHistory) {
            TaskHistorySheet(store: store)
        }
        .alert("操作未完成", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("好") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    // MARK: - Top Dashboard Header

    private var headerDashboard: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.19, green: 0.44, blue: 0.96), Color(red: 0.36, green: 0.27, blue: 0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                        .shadow(color: accent.opacity(0.32), radius: 8, x: 0, y: 3)
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("Aether Antigravity Multiplexer")
                            .font(.system(size: 19.5, weight: .bold))
                            .lineLimit(1)
                        Text("v\(appVersion)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 7.5)
                            .frame(height: 19)
                            .background(Capsule().fill(accent.opacity(0.12)))
                            .overlay(Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 1))

                        HStack(alignment: .center, spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5.5, height: 5.5)
                            Text("Kernel Direct")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 6.5)
                        .frame(height: 19)
                        .background(Capsule().fill(Color.green.opacity(0.10)))
                        .overlay(Capsule().strokeBorder(Color.green.opacity(0.20), lineWidth: 1))
                        .help("内核直接通信：使用 macOS Darwin libproc 直读进程指标，0 子进程开销，微秒级能效")
                    }
                    Text("Apple Silicon 多实例监控与隔离工作台 · 实时任务感知与一键调出")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            // Action Toolbar (All controls strictly 34pt height)
            HStack(alignment: .center, spacing: 8) {
                if store.runningCount > 0 {
                    Button {
                        store.collapseAllToMonitorWall()
                    } label: {
                        HStack(alignment: .center, spacing: 5) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 11.5, weight: .semibold))
                                .frame(width: 13, height: 13, alignment: .center)
                            Text("收起全部窗口")
                        }
                    }
                    .buttonStyle(ModernButtonStyle(variant: .secondary))
                    .help("隐藏所有正在显示的 Antigravity 窗口并回到缩略图监控墙（后台任务继续运行）")
                }

                IconActionButton(
                    symbol: "arrow.clockwise",
                    tooltip: "刷新实例与任务状态",
                    size: 34,
                    rotation: refreshSpin
                ) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        refreshSpin += 360
                    }
                    store.refresh()
                }

                IconActionButton(
                    symbol: "list.bullet.rectangle.portrait",
                    tooltip: "任务事件与执行动态中心（\(store.taskHistory.count) 条记录）",
                    size: 34,
                    badge: store.unreadAttentionCount
                ) {
                    showTaskHistory = true
                }

                IconActionButton(
                    symbol: "externaldrive",
                    tooltip: "管理升级备份（\(store.backups.count) 个批次）",
                    size: 34,
                    badge: store.backups.count
                ) {
                    store.refreshBackups()
                    showBackupManager = true
                }

                IconActionButton(
                    symbol: "arrow.down.circle",
                    tooltip: "检查管理器更新",
                    size: 34
                ) {
                    updaterController.checkForUpdates(nil)
                }

                IconActionButton(
                    symbol: "gearshape",
                    tooltip: "管理器自动更新设置",
                    size: 34
                ) {
                    showUpdateSettings = true
                }

                if !store.pendingUpgrades.isEmpty {
                    Button {
                        upgradeRequest = UpgradeRequest(instances: store.pendingUpgrades)
                    } label: {
                        HStack(alignment: .center, spacing: 5) {
                            Image(systemName: "arrow.up.forward.circle.fill")
                                .font(.system(size: 12.5, weight: .semibold))
                                .frame(width: 14, height: 14, alignment: .center)
                            Text("升级全部 (\(store.pendingUpgrades.count))")
                        }
                    }
                    .buttonStyle(ModernButtonStyle(variant: .upgrade))
                    .disabled(store.busy || store.compatibility != "已支持本机版本")
                    .transition(.scale.combined(with: .opacity))
                }

                Button {
                    showCreate = true
                } label: {
                    HStack(alignment: .center, spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 13, height: 13, alignment: .center)
                        Text("创建实例")
                    }
                }
                .buttonStyle(ModernButtonStyle(variant: .primary))
                .disabled(store.busy)
            }
        }
    }

    // MARK: - 4-Column Metrics Strip

    private var metricsStrip: some View {
        HStack(alignment: .center, spacing: 12) {
            metricTile(
                title: "实时运行与任务监控",
                value: "\(store.runningCount) / \(store.instances.count) 运行中",
                subtitle: store.activeTaskCount > 0 ? "⚡ 当前有 \(store.activeTaskCount) 个实例正在执行 Agent 任务" : "所有已启动实例均处于空闲就绪状态",
                symbol: "waveform.path.ecg.rectangle.fill",
                tint: store.activeTaskCount > 0 ? Color(red: 0.15, green: 0.82, blue: 0.96) : accent,
                leadingIndicator: {
                    AnyView(PulsingStatusDot(
                        active: store.runningCount > 0,
                        activeColor: store.activeTaskCount > 0 ? Color(red: 0.15, green: 0.82, blue: 0.96) : .green,
                        pulse: store.activeTaskCount > 0
                    ))
                }
            )

            metricTile(
                title: "官方主实例版本",
                value: store.sourceVersion == "—" ? "—" : "v\(store.sourceVersion)",
                subtitle: "/Applications/Antigravity.app",
                symbol: "checkmark.shield.fill",
                tint: .indigo
            )

            metricTile(
                title: "工作空间总磁盘占用",
                value: store.totalDiskUsageBytes > 0 ? store.formattedTotalDiskUsage : "统计中…",
                subtitle: "\(store.instances.count) 个实例独立数据与存储",
                symbol: "internaldrive.fill",
                tint: .cyan
            )

            metricTile(
                title: "创建与升级适配",
                value: store.compatibility,
                subtitle: store.pendingUpgrades.isEmpty
                    ? "全部独立副本均为最新版本"
                    : "发现 \(store.pendingUpgrades.count) 个副本可升级至 v\(store.sourceVersion)",
                symbol: store.compatibility == "已支持本机版本" ? "wrench.and.screwdriver.fill" : "exclamationmark.triangle.fill",
                tint: compatibilityColor
            )
        }
    }

    private func metricTile(
        title: String,
        value: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        leadingIndicator: (() -> AnyView)? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 42, height: 42)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(tint.opacity(0.20), lineWidth: 1)
                    }
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2.5) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .center, spacing: 6) {
                    if let leadingIndicator {
                        leadingIndicator()
                    }
                    Text(value)
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .systemSurface(radius: 15)
    }

    // MARK: - Control Toolbar (Filter Pills + View Switcher + Preferences Menu)

    private var controlToolbar: some View {
        HStack(alignment: .center, spacing: 10) {
            // Segmented Filter Bar
            HStack(alignment: .center, spacing: 3) {
                ForEach(InstanceFilter.allCases) { filter in
                    let count = filterCount(filter)
                    let active = selectedFilter == filter
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 4.5) {
                            Text(filter.rawValue)
                                .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                            Text("\(count)")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .opacity(active ? 0.95 : 0.65)
                        }
                        .foregroundStyle(active ? Color.primary : Color.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.09))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }

            Spacer()

            // View Switcher (Grid / List)
            HStack(alignment: .center, spacing: 3) {
                ForEach(ViewMode.allCases) { mode in
                    let active = viewMode == mode
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            viewMode = mode
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 4.5) {
                            Image(systemName: mode.symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 13, height: 13, alignment: .center)
                            Text(mode.rawValue)
                                .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                        }
                        .foregroundStyle(active ? Color.primary : Color.secondary)
                        .padding(.horizontal, 9.5)
                        .frame(height: 26)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.09))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }

            // Quick Switcher Button
            Button {
                store.toggleQuickSwitcher()
            } label: {
                HStack(alignment: .center, spacing: 5) {
                    Image(systemName: "command.square")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0.52, green: 0.28, blue: 0.98))
                    Text("极速切换")
                        .font(.system(size: 11.5, weight: .medium))
                    Text("⌥Space")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 3.5))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 9)
                .frame(height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help("呼出极速切换悬浮窗 (全局快捷键 ⌥Space)")

            // Options & Preferences Popover Button
            Button {
                showOptionsPopover.toggle()
            } label: {
                HStack(alignment: .center, spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11.5, weight: .semibold))
                        .frame(width: 13, height: 13, alignment: .center)
                    Text("选项与偏好")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundStyle(showOptionsPopover ? Color.primary : Color.secondary)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(showOptionsPopover ? (colorScheme == .dark ? 0.14 : 0.09) : (colorScheme == .dark ? 0.06 : 0.035)))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(showOptionsPopover ? 0.20 : 0.08), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help("工作台窗口管理与通知偏好设置")
            .popover(isPresented: $showOptionsPopover, arrowEdge: .bottom) {
                toolbarOptionsPopover
            }
        }
    }

    private var toolbarOptionsPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Text("工作台偏好与窗口管理")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $store.globalHotkeysEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("全局快捷键 (⌥Space / ⌥1~9)")
                            .font(.system(size: 12, weight: .semibold))
                        Text("任意桌面呼出极速切换面板或直达 1~9 号实例（⌥1 为主实例，前台时按则隐藏）")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if store.globalHotkeysEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(red: 0.52, green: 0.28, blue: 0.98))
                            Text("快捷键快速指南")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        VStack(alignment: .leading, spacing: 4.5) {
                            HStack {
                                Text("⌥ Space")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 3.5))
                                Text("唤出 / 隐藏极速切换面板")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("⌥ 1")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1.5)
                                    .background(Color(red: 0.52, green: 0.28, blue: 0.98).opacity(0.2))
                                    .foregroundStyle(Color(red: 0.52, green: 0.28, blue: 0.98))
                                    .clipShape(RoundedRectangle(cornerRadius: 3.5))
                                Text("直达 👑 主实例 (置顶紫标，前台按隐藏)")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("⌥ 2 ~ ⌥ 9")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 3.5))
                                Text("直达分身实例 02 ~ 09")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(9)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.03))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                }

                Toggle(isOn: $store.soloFocusMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("专注单窗口模式")
                            .font(.system(size: 12, weight: .semibold))
                        Text("调出某实例时自动隐藏其他实例窗口，保持桌面整洁")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $store.floatingHUDEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("桌面悬浮返回胶囊")
                            .font(.system(size: 12, weight: .semibold))
                        Text("在实例窗口右下角浮现微型返回条，点一下即可收起回监控台")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $store.notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("任务系统通知 (精准调出)")
                            .font(.system(size: 12, weight: .semibold))
                        Text("后台实例任务跑完或需要确认时发送通知，支持点击横幅立即精准调出对应窗口")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $store.dockBadgeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dock 图标任务角标")
                            .font(.system(size: 12, weight: .semibold))
                        Text("在程序坞图标实时显示后台正在跑任务或等待确认的实例数量")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 16, height: 16, alignment: .center)
                VStack(alignment: .leading, spacing: 2.5) {
                    Text("关闭即转后台托管 (始终生效)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("在实例窗口点击左上角红色 ✕ 关闭按钮，不会退出软件或中断任务，自动转为后台托管；在此工具中点击「退出」才会真正关闭实例。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.green.opacity(colorScheme == .dark ? 0.10 : 0.06))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.18), lineWidth: 1)
            }
        }
        .padding(16)
        .frame(width: 330)
    }

    // MARK: - Thumbnail Monitor Wall View (Grid Mode)

    private var thumbnailWallSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if filteredInstances.isEmpty {
                filteredEmptyView
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 270, maximum: 360), spacing: 20)],
                    spacing: 22
                ) {
                    ForEach(Array(filteredInstances.enumerated()), id: \.element.id) { idx, item in
                        InstanceThumbnailTile(
                            item: item,
                            activity: store.activity(for: item),
                            meta: store.meta(for: item),
                            resourceMetric: store.metric(for: item),
                            diskUsage: store.diskUsage(for: item),
                            thumbnail: store.thumbnails[item.id],
                            sourceVersion: store.sourceVersion,
                            duration: store.runningDuration(for: item),
                            busy: store.busy,
                            canUpgrade: store.compatibility == "已支持本机版本",
                            open: { store.open(item) },
                            hideWindow: { store.hideInstance(item) },
                            quit: { store.quit(item) },
                            upgrade: { upgradeRequest = UpgradeRequest(instances: [item]) },
                            reveal: { store.reveal(item) },
                            revealProfile: { store.revealProfile(item) },
                            logs: { store.showLogs(item) },
                            verify: { store.toggleVerified(item) },
                            editMeta: { editingMetaItem = item },
                            clearWorkspace: { pendingClear = item },
                            destroy: { pendingDestroy = item }
                        )
                        .equatable()
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(
                            .spring(response: 0.36, dampingFraction: 0.82).delay(Double(idx) * 0.03),
                            value: appeared
                        )
                    }
                }
                .padding(20)
                .systemSurface(radius: 20)
            }
        }
    }

    // MARK: - Detailed List Sections (List Mode)

    private func primarySection(_ primary: ManagedInstance) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("官方原版主实例")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("创建与升级副本的签名基准源")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)

            InstanceCard(
                item: primary,
                activity: store.activity(for: primary),
                meta: store.meta(for: primary),
                resourceMetric: store.metric(for: primary),
                diskUsage: store.diskUsage(for: primary),
                sourceVersion: store.sourceVersion,
                busy: store.busy,
                canUpgrade: false,
                upgrade: {},
                open: { store.open(primary) },
                hideWindow: { store.hideInstance(primary) },
                quit: { store.quit(primary) },
                reveal: { store.reveal(primary) },
                revealProfile: { store.revealProfile(primary) },
                logs: { store.showLogs(primary) },
                verify: {},
                editMeta: { editingMetaItem = primary },
                clearWorkspace: {},
                destroy: {}
            )
            .equatable()
        }
    }

    private var clonesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("独立隔离副本")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(store.cloneInstances.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6.5)
                        .frame(height: 18)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                Spacer()
            }
            .padding(.horizontal, 2)

            if store.cloneInstances.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("尚未创建独立副本 · 点击右上角「创建实例」生成隔离副本")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 26)
                    Spacer()
                }
                .systemSurface(radius: 15)
            } else if filteredClones.isEmpty {
                filteredEmptyView
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(filteredClones.enumerated()), id: \.element.id) { idx, item in
                        InstanceCard(
                            item: item,
                            activity: store.activity(for: item),
                            meta: store.meta(for: item),
                            resourceMetric: store.metric(for: item),
                            diskUsage: store.diskUsage(for: item),
                            sourceVersion: store.sourceVersion,
                            busy: store.busy,
                            canUpgrade: store.compatibility == "已支持本机版本",
                            upgrade: { upgradeRequest = UpgradeRequest(instances: [item]) },
                            open: { store.open(item) },
                            hideWindow: { store.hideInstance(item) },
                            quit: { store.quit(item) },
                            reveal: { store.reveal(item) },
                            revealProfile: { store.revealProfile(item) },
                            logs: { store.showLogs(item) },
                            verify: { store.toggleVerified(item) },
                            editMeta: { editingMetaItem = item },
                            clearWorkspace: { pendingClear = item },
                            destroy: { pendingDestroy = item }
                        )
                        .equatable()
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(
                            .spring(response: 0.36, dampingFraction: 0.82).delay(Double(idx) * 0.035),
                            value: appeared
                        )
                    }
                }
            }
        }
    }

    private var filteredEmptyView: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: selectedFilter == .busyTask ? "bolt.slash" : (selectedFilter == .running ? "moon.zzz" : "checkmark.circle"))
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                Text(
                    selectedFilter == .busyTask
                        ? "当前没有正在执行任务的实例"
                        : (selectedFilter == .running ? "当前没有正在运行的实例" : "所有副本均已是最新版本")
                )
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 32)
            Spacer()
        }
        .systemSurface(radius: 15)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func filterCount(_ filter: InstanceFilter) -> Int {
        switch filter {
        case .all: return store.instances.count
        case .running: return store.runningCount
        case .busyTask: return store.activeTaskCount
        case .withTags: return store.instances.filter { store.meta(for: $0).hasCustomContent }.count
        case .upgradable: return store.pendingUpgrades.count
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 30))
                .foregroundStyle(accent)
            Text("未发现 Antigravity 实例")
                .font(.system(size: 15, weight: .semibold))
            Text("请先将官方 Apple Silicon 版 Antigravity.app 放入 /Applications 目录。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(36)
        .systemSurface(radius: 17)
    }

    // MARK: - Live Operation Console Drawer

    private var operationConsoleDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                if store.busy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: store.error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(store.error == nil ? .green : .orange)
                        .font(.system(size: 13))
                        .frame(width: 15, height: 15, alignment: .center)
                }

                Text(store.busy ? "正在执行实例操作…" : "操作执行记录")
                    .font(.system(size: 12.5, weight: .semibold))

                if let lastLine = store.output.split(separator: "\n").last {
                    Text("·  \(String(lastLine))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        logExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .center, spacing: 4) {
                        Text(logExpanded ? "收起日志" : "展开日志")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: logExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 11, height: 11, alignment: .center)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if !store.busy {
                    Button {
                        store.clearOutput()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 15, height: 15, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .help("关闭操作记录")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            if logExpanded {
                Divider().opacity(0.5)
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(store.output)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .id("consoleBottom")
                    }
                    .frame(height: 135)
                    .onChange(of: store.output) { _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("consoleBottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .systemSurface(radius: 16, isHighlighted: store.busy, tint: store.busy ? accent : nil)
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    // MARK: - Create Instance Sheet

    private var createInstanceSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Text("#\(String(format: "%02d", store.nextIndex))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("创建 Antigravity \(ordinalName(store.nextIndex))")
                        .font(.system(size: 19, weight: .bold))
                    Text("从本机官方 Antigravity.app 克隆并自动隔离账号、凭据与回调协议。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                detailRow("实例名称", "Antigravity \(ordinalName(store.nextIndex))")
                Divider().opacity(0.4)
                detailRow("独立数据目录", "~/.gemini-\(store.nextIndex - 1)", monospaced: true)
                Divider().opacity(0.4)
                detailRow("专属回调协议", "antigravity-\(store.nextIndex)://", monospaced: true)
                Divider().opacity(0.4)
                detailRow("官方源版本", "v\(store.sourceVersion)", monospaced: true)
            }
            .padding(16)
            .systemSurface(radius: 13)

            HStack(alignment: .center) {
                Text("目标安装位置")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $destination) {
                    Text("系统应用程序 (/Applications)").tag(URL(fileURLWithPath: "/Applications"))
                    Text("个人应用程序 (~/Applications)").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))
                }
                .labelsHidden()
                .frame(width: 260)
            }
            .padding(.horizontal, 4)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                    .frame(width: 16, height: 16, alignment: .center)
                Text("创建前严格校验原版签名与哈希；已有实例绝不会被覆盖。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 10) {
                Spacer()
                Button("取消") { showCreate = false }
                    .buttonStyle(ModernButtonStyle(variant: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("创建并启动") {
                    store.create(index: store.nextIndex, destination: destination)
                    showCreate = false
                }
                .buttonStyle(ModernButtonStyle(variant: .primary))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(store.compatibility != "已支持本机版本")
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func ordinalName(_ number: Int) -> String {
        let units = [1: "First", 2: "Second", 3: "Third", 4: "Fourth", 5: "Fifth",
                     6: "Sixth", 7: "Seventh", 8: "Eighth", 9: "Ninth", 10: "Tenth",
                     11: "Eleventh", 12: "Twelfth", 13: "Thirteenth", 14: "Fourteenth",
                     15: "Fifteenth", 16: "Sixteenth", 17: "Seventeenth", 18: "Eighteenth",
                     19: "Nineteenth"]
        let tens = [20: "Twenty", 30: "Thirty", 40: "Forty", 50: "Fifty",
                    60: "Sixty", 70: "Seventy", 80: "Eighty", 90: "Ninety"]
        let tensOrdinal = [20: "Twentieth", 30: "Thirtieth", 40: "Fortieth", 50: "Fiftieth",
                           60: "Sixtieth", 70: "Seventieth", 80: "Eightieth", 90: "Ninetieth"]
        let cardinal = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
        if let word = units[number] { return word }
        if number < 100 {
            let remainder = number % 10
            return remainder == 0 ? (tensOrdinal[number] ?? String(number))
                : (tens[(number / 10) * 10] ?? "") + " " + (units[remainder] ?? "")
        }
        if number < 1000 {
            let remainder = number % 100
            return cardinal[number / 100] + " Hundred" + (remainder == 0 ? "th" : " " + ordinalName(remainder))
        }
        let remainder = number % 1000
        return cardinal[number / 1000] + " Thousand" + (remainder == 0 ? "th" : " " + ordinalName(remainder))
    }

    private func detailRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: monospaced ? .monospaced : .default))
        }
    }
}

// MARK: - Confirmation & Management Sheets

private struct InstanceNameConfirmation: View {
    let name: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("此操作无法撤销。请输入完整实例名称以确认：")
                .font(.system(size: 12))
            HStack(alignment: .center, spacing: 10) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        copied = pasteboard.setString(name, forType: .string)
                    }
                } label: {
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 12, height: 12, alignment: .center)
                        Text(copied ? "已复制" : "复制实例名")
                    }
                }
                .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))
            }
        }
    }
}

private struct ClearWorkspaceView: View {
    let item: ManagedInstance
    let busy: Bool
    let clear: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "eraser.line.dashed.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("清空 \(item.name) 的工作空间")
                        .font(.system(size: 19, weight: .bold))
                    Text("保留实例应用与独立登录状态，仅清空工作空间目录内容")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Text("仅永久清空 \(item.profile) 内的所有数据（包括隐藏文件），保留这个目录、实例应用、其他资料目录及升级备份。独立登录文件位于工作空间外，不会删除；此操作也不等同于退出账号。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(item.profile)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .systemSurface(radius: 12)

            if item.running {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .frame(width: 14, height: 14, alignment: .center)
                    Text("实例仍在运行。请先保存工作并点击“退出”后再试。")
                }
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            }

            InstanceNameConfirmation(name: item.name)
            TextField("输入完整实例名称（\(item.name)）", text: $confirmation)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .center, spacing: 10) {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(ModernButtonStyle(variant: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("永久清空", action: clear)
                    .buttonStyle(ModernButtonStyle(variant: .danger))
                    .disabled(busy || item.running || confirmation != item.name)
            }
        }
        .padding(24)
        .frame(width: 540)
    }
}

private struct DestroyInstanceView: View {
    let item: ManagedInstance
    let busy: Bool
    let destroy: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("销毁 \(item.name)")
                        .font(.system(size: 19, weight: .bold))
                    Text("永久移除此副本的应用、数据目录与独立凭据文件")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Text("将永久删除所选副本的应用、独立账号资料、窗口数据、日志、登录文件及管理清单。主实例和其他副本不会删除；已有升级备份会保留。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 7) {
                Text(item.path.path)
                Text(item.profile)
                Text("~/Library/Application Support/\(item.name)")
                Text("~/Library/Logs/\(item.name)")
            }
            .font(.system(size: 11, design: .monospaced))
            .textSelection(.enabled)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .systemSurface(radius: 12)

            if item.running {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .frame(width: 14, height: 14, alignment: .center)
                    Text("实例仍在运行。请先保存工作并退出，然后刷新列表重试。")
                }
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            }

            InstanceNameConfirmation(name: item.name)
            TextField("输入完整实例名称（\(item.name)）", text: $confirmation)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .center, spacing: 10) {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(ModernButtonStyle(variant: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("永久销毁", action: destroy)
                    .buttonStyle(ModernButtonStyle(variant: .danger))
                    .disabled(busy || item.running || confirmation != item.name)
            }
        }
        .padding(24)
        .frame(width: 540)
    }
}

private struct BackupManagementView: View {
    @ObservedObject var store: InstanceStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeletion: BackupBatch?
    private var totalSize: String {
        ByteCountFormatter.string(fromByteCount: store.backups.reduce(0) { $0 + $1.bytes }, countStyle: .file)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "externaldrive.fill.badge.timemachine")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("升级备份管理")
                        .font(.system(size: 19, weight: .bold))
                    Text("\(store.backups.count) 个备份批次  ·  共占用 \(totalSize)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                IconActionButton(symbol: "arrow.clockwise", tooltip: "刷新备份列表") {
                    store.refreshBackups()
                }
            }

            if store.backups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.checkmark")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text("还没有升级备份")
                        .font(.system(size: 13.5, weight: .medium))
                    Text("执行副本升级时会自动在此生成应用与数据目录的完整归档。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
                .systemSurface(radius: 14)
            } else {
                ScrollView {
                    VStack(spacing: 9) {
                        ForEach(store.backups) { batch in
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(alignment: .center, spacing: 8) {
                                        Text(batch.dateLabel)
                                            .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                                        Text(batch.sizeLabel)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(accent)
                                            .padding(.horizontal, 7)
                                            .frame(height: 18)
                                            .background(Capsule().fill(accent.opacity(0.12)))
                                    }
                                    Text("包含 \(batch.archiveCount) 个实例完整归档压缩包")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.secondary)
                                    if batch.referenced {
                                        HStack(alignment: .center, spacing: 4) {
                                            Image(systemName: "bookmark.fill")
                                                .font(.system(size: 10))
                                                .frame(width: 12, height: 12, alignment: .center)
                                            Text("当前升级记录引用此备份")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundStyle(.orange)
                                    }
                                    if !batch.deletable {
                                        HStack(alignment: .center, spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 10))
                                                .frame(width: 12, height: 12, alignment: .center)
                                            Text("含非备份文件，请在访达中检查")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Button("永久删除") { pendingDeletion = batch }
                                    .buttonStyle(ModernButtonStyle(variant: .danger, compact: true))
                                    .disabled(store.busy || !batch.deletable)
                            }
                            .padding(14)
                            .systemSurface(radius: 13)
                        }
                    }
                }
                .frame(maxHeight: 340)
            }

            Text("只删除你选定的备份批次。删除后无法恢复；请先确认各副本的登录和项目正常。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if let error = store.error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            HStack(alignment: .center) {
                Button("在访达中查看") { store.showBackups() }
                    .buttonStyle(ModernButtonStyle(variant: .secondary))
                    .disabled(store.backups.isEmpty)
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(ModernButtonStyle(variant: .primary))
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 580)
        .alert("永久删除此备份？", isPresented: Binding(get: { pendingDeletion != nil },
                                             set: { if !$0 { pendingDeletion = nil } })) {
            Button("永久删除", role: .destructive) {
                if let batch = pendingDeletion { store.deleteBackup(batch) }
                pendingDeletion = nil
            }
            Button("取消", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("将删除 \(pendingDeletion?.dateLabel ?? "") 的整个备份批次，约 \(pendingDeletion?.sizeLabel ?? "0 B")。此操作无法撤销。")
        }
    }
}

private struct UpdateSettingsView: View {
    let updater: SPUUpdater
    @Environment(\.dismiss) private var dismiss
    @State private var automatic = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("管理器更新设置")
                        .font(.system(size: 18, weight: .bold))
                    Text("通过 Sparkle 安全验证签名并更新管理器")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("自动检查、下载并安装管理器更新", isOn: $automatic)
                    .font(.system(size: 13, weight: .medium))
                    .onChange(of: automatic) { enabled in
                        updater.automaticallyChecksForUpdates = enabled
                        updater.automaticallyDownloadsUpdates = enabled
                    }
                Text("开启后每天自动检查新版本。此更新仅替换多开管理器自身，不会自动改动任何 Antigravity 副本或账号数据目录。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .systemSurface(radius: 12)

            HStack(alignment: .center) {
                Button("立即检查更新") { updater.checkForUpdates(); dismiss() }
                    .buttonStyle(ModernButtonStyle(variant: .secondary))
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(ModernButtonStyle(variant: .primary))
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { automatic = updater.automaticallyChecksForUpdates && updater.automaticallyDownloadsUpdates }
    }
}

// MARK: - Task History & Telemetry Sheet

private struct TaskHistorySheet: View {
    @ObservedObject var store: InstanceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchQuery: String = ""
    @State private var selectedCategory: TaskHistoryCategory? = nil
    @State private var showClearConfirmation = false
    @State private var exportSuccessURL: URL? = nil

    private var filteredItems: [TaskHistoryItem] {
        store.taskHistory.filter { item in
            if let cat = selectedCategory, item.category != cat {
                return false
            }
            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty { return true }
            return item.instanceName.lowercased().contains(q) ||
                item.instanceNickname.lowercased().contains(q) ||
                item.actionSummary.lowercased().contains(q) ||
                item.workspace.lowercased().contains(q) ||
                item.category.label.lowercased().contains(q)
        }
    }

    private var attentionCount: Int {
        store.taskHistory.filter { $0.category == .needsAttention }.count
    }

    private var completedCount: Int {
        store.taskHistory.filter { $0.category == .completed }.count
    }

    private var errorCount: Int {
        store.taskHistory.filter { $0.category == .error }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Header Bar
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.19, green: 0.44, blue: 0.96), Color(red: 0.36, green: 0.27, blue: 0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                        .shadow(color: accent.opacity(0.3), radius: 6, y: 2)
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("任务事件与执行动态中心")
                            .font(.system(size: 16.5, weight: .bold))
                        Text("共 \(store.taskHistory.count) 条记录")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 7)
                            .frame(height: 19)
                            .background(Capsule().fill(accent.opacity(0.12)))
                    }
                    Text("实时聚合各多开实例的 Agent 执行状态、耗时与用户待确认事件 · 支持一键跳转实例")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // 2. Filter Tabs & Search Bar
            HStack(spacing: 12) {
                // Category Pills
                HStack(spacing: 6) {
                    categoryFilterTab(title: "全部", category: nil, count: store.taskHistory.count)
                    categoryFilterTab(title: "待确认", category: .needsAttention, count: attentionCount, color: .orange)
                    categoryFilterTab(title: "已完成", category: .completed, count: completedCount, color: .green)
                    categoryFilterTab(title: "异常", category: .error, count: errorCount, color: .red)
                }

                Spacer()

                // Search Input
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("搜索实例名、工作区、任务内容...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 9)
                .frame(width: 240, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(colorScheme == .dark ? 0.025 : 0.015))

            Divider()

            // 3. Item List or Empty State
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: searchQuery.isEmpty ? "clock.badge.checkmark" : "magnifyingglass")
                        .font(.system(size: 38))
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text(searchQuery.isEmpty ? "暂无任务历史记录" : "未找到匹配的任务记录")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(searchQuery.isEmpty ? "当各实例运行 Agent 任务并完成、遇到报错或等待确认时，事件与耗时会自动记录在此处。" : "请尝试更改筛选条件或搜索关键词")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 60)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            TaskHistoryCard(
                                item: item,
                                onOpen: {
                                    if let target = store.instances.first(where: { $0.id == item.instanceID }) {
                                        dismiss()
                                        store.open(target)
                                    }
                                },
                                onShowLogs: {
                                    if let target = store.instances.first(where: { $0.id == item.instanceID }) {
                                        store.showLogs(target)
                                    }
                                }
                            )
                        }
                    }
                    .padding(20)
                }
            }

            Divider()

            // 4. Bottom Action Bar
            HStack(alignment: .center) {
                Button {
                    if let url = store.exportTaskHistory() {
                        exportSuccessURL = url
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text("导出 Markdown 报告")
                    }
                }
                .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))
                .help("将当前所有任务动态耗时导出为 Markdown 文件并保存到桌面")

                if !store.taskHistory.isEmpty {
                    Button {
                        showClearConfirmation = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("清空历史")
                        }
                    }
                    .buttonStyle(ModernButtonStyle(variant: .danger, compact: true))
                }

                if let exportSuccessURL {
                    Text("✓ 已导出至 \(exportSuccessURL.lastPathComponent)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.green)
                }

                Spacer()

                Button("完成") {
                    dismiss()
                }
                .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(colorScheme == .dark ? 0.03 : 0.02))
        }
        .frame(minWidth: 740, idealWidth: 780, minHeight: 520, idealHeight: 580)
        .confirmationDialog(
            "确定要清空所有任务历史记录吗？",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空历史记录", role: .destructive) {
                store.clearTaskHistory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清空后将无法恢复已记录的任务耗时与事件详情。")
        }
    }

    private func categoryFilterTab(title: String, category: TaskHistoryCategory?, count: Int, color: Color = accent) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : (category != nil ? color : .secondary))
                    .padding(.horizontal, 5)
                    .frame(height: 15)
                    .background(Capsule().fill(isSelected ? Color.white.opacity(0.25) : color.opacity(0.12)))
            }
            .foregroundStyle(isSelected ? .white : Color.primary.opacity(0.85))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? color : Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? color : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TaskHistoryCard: View {
    let item: TaskHistoryItem
    let onOpen: () -> Void
    let onShowLogs: () -> Void

    @State private var hovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Category Tag, Instance Identity, Duration Pill, Timestamp
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 4.5) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 10.5, weight: .bold))
                    Text(item.category.label)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(item.category.color)
                .padding(.horizontal, 7.5)
                .frame(height: 21)
                .background(Capsule().fill(item.category.color.opacity(0.14)))
                .overlay(Capsule().strokeBorder(item.category.color.opacity(0.35), lineWidth: 1))

                HStack(spacing: 4) {
                    if item.isOriginal {
                        Text("👑 官方主实例")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color(red: 0.52, green: 0.32, blue: 0.98))
                    } else {
                        Text(item.displayName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(accent)
                    }
                }
                .padding(.horizontal, 6.5)
                .frame(height: 21)
                .background(Capsule().fill(item.isOriginal ? Color(red: 0.52, green: 0.32, blue: 0.98).opacity(0.12) : accent.opacity(0.1)))

                if let duration = item.formattedDuration {
                    HStack(spacing: 3.5) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 9))
                        Text("耗时 \(duration)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(Color.cyan)
                    .padding(.horizontal, 7)
                    .frame(height: 21)
                    .background(Capsule().fill(Color.cyan.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(Color.cyan.opacity(0.3), lineWidth: 1))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(item.formattedTime)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("(\(item.relativeTime))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }

            // Row 2: Action Summary
            Text(item.actionSummary)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.92))
                .lineLimit(3)

            // Row 3: Workspace & Action Buttons
            HStack(alignment: .center, spacing: 8) {
                if !item.workspace.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 9.5))
                        Text(item.workspace)
                            .font(.system(size: 10.5, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.05)))
                }

                Spacer()

                Button {
                    onShowLogs()
                } label: {
                    Text("日志")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .buttonStyle(ModernButtonStyle(variant: .ghost, compact: true))
                .help("打开该实例的系统日志目录")

                Button {
                    onOpen()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10.5))
                        Text("调出并聚焦")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    item.category == .needsAttention ? Color.orange.opacity(0.35) :
                    (item.category == .error ? Color.red.opacity(0.35) : Color.primary.opacity(hovered ? 0.18 : 0.08)),
                    lineWidth: 1
                )
        }
        .onHover { hovered = $0 }
    }
}

// MARK: - App & Window Commands

private struct MainWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("显示主窗口") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("0")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        for window in sender.windows where !(window is NSPanel) && !window.isSheet && window.canBecomeMain {
            if let sheet = window.attachedSheet {
                sheet.makeKeyAndOrderFront(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
            sender.activate(ignoringOtherApps: true)
            return true
        }
        return true
    }
}

@main struct AntigravityMultiplexerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    var body: some Scene {
        Window("Aether Antigravity Multiplexer", id: "main") {
            ContentView(updaterController: updaterController)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            MainWindowCommands()
            CommandGroup(after: .appInfo) {
                Button("检查多开管理器更新…") { updaterController.checkForUpdates(nil) }
            }
        }
    }
}
