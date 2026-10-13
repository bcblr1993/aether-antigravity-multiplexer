import AppKit
import SwiftUI
import Sparkle
import WebKit

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
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(active ? activeColor : Color.secondary.opacity(0.45))
            .frame(width: 6, height: 6)
            .overlay {
                if active {
                    Circle()
                        .stroke(activeColor.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 12, height: 12)
                        .scaleEffect(pulsing ? 1.35 : 0.65)
                        .opacity(pulsing ? 0.0 : 0.9)
                }
            }
            .frame(width: 10, height: 10, alignment: .center)
            .onAppear {
                guard active else { return }
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
            .onChange(of: active) { isNowActive in
                if isNowActive {
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
}

// MARK: - Data Models & Store

struct ManagedInstance: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let bundleID: String
    let version: String
    let index: Int
    let running: Bool
    let verified: Bool
    var isOriginal: Bool { bundleID == "com.google.antigravity" }
    var profile: String { isOriginal ? "~/.gemini" : "~/.gemini-\(max(index - 1, 1))" }
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

@MainActor final class InstanceStore: ObservableObject {
    @Published var instances: [ManagedInstance] = []
    @Published var backups: [BackupBatch] = []
    @Published var busy = false
    @Published var output = ""
    @Published var error: String?
    @Published var sourceVersion = "—"
    @Published var compatibility = "检查中"
    private let support = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Antigravity Multiplexer")
    private let supportedVersions: Set<String> = {
        guard let url = Bundle.main.url(forResource: "compatibility", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return Set(records.keys)
    }()
    private let names = ["Second": 2, "Third": 3, "Fourth": 4, "Fifth": 5, "Sixth": 6, "Seventh": 7, "Eighth": 8]

    func refresh() {
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
                let running = isInstanceRunning(bundleID: bundle, path: app)
                found.append(ManagedInstance(id: bundle, name: name, path: app, bundleID: bundle,
                                             version: version, index: index, running: running, verified: verified))
            }
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            instances = found.sorted { $0.index < $1.index }
            if let source = instances.first(where: { $0.isOriginal }) {
                sourceVersion = source.version
                compatibility = supportedVersions.contains(source.version) ? "已支持本机版本" : "版本待适配"
            } else {
                sourceVersion = "未找到"
                compatibility = "需要官方原版"
            }
        }
        refreshBackups()
    }

    private func isInstanceRunning(bundleID: String, path: URL) -> Bool {
        let expected = path.resolvingSymlinksInPath().standardizedFileURL
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains { app in
            !app.isTerminated && app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == expected
        }
    }

    func refreshRunningStates() {
        let updated = instances.map { item in
            ManagedInstance(id: item.id, name: item.name, path: item.path, bundleID: item.bundleID,
                            version: item.version, index: item.index,
                            running: isInstanceRunning(bundleID: item.bundleID, path: item.path), verified: item.verified)
        }
        if updated != instances {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                instances = updated
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

    func open(_ item: ManagedInstance) {
        NSWorkspace.shared.open(item.path)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.refresh() }
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
        do { try process.run() }
        catch {
            withAnimation { busy = false }
            self.error = "无法启动组件：\(error.localizedDescription)"
        }
    }
}

// MARK: - Instance Card View

struct InstanceCard: View {
    let item: ManagedInstance
    let sourceVersion: String
    let busy: Bool
    let canUpgrade: Bool
    let upgrade: () -> Void
    let open: () -> Void
    let quit: () -> Void
    let reveal: () -> Void
    let logs: () -> Void
    let verify: () -> Void
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
                colors: [Color(red: 0.22, green: 0.48, blue: 0.98), Color(red: 0.42, green: 0.30, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if item.running {
            return LinearGradient(
                colors: [Color.green.opacity(0.20), accent.opacity(0.14)],
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
                                    : (item.running ? Color.green.opacity(0.45) : accent.opacity(0.22)),
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
                            .foregroundStyle(item.running ? Color.green : accent)
                        Text("CLONE")
                            .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Center Metadata & Badges (Exact 48pt height: 22pt top row + 4pt gap + 22pt bottom row)
            VStack(alignment: .leading, spacing: 4) {
                // Top Row: Title + Status Pill + Role/Verified Pill
                HStack(alignment: .center, spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.primary)

                    // Live Running Status Pill (Fixed 20pt height)
                    HStack(alignment: .center, spacing: 5) {
                        PulsingStatusDot(active: item.running)
                        Text(item.running ? "运行中" : "已停止")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(item.running ? Color.green : Color.secondary)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background {
                        Capsule()
                            .fill(item.running
                                  ? Color.green.opacity(colorScheme == .dark ? 0.14 : 0.10)
                                  : Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.045))
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(item.running ? Color.green.opacity(0.30) : Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .help("关闭窗口后应用可能仍在后台运行。点击“退出”才能结束实例并清空工作空间。")

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

                // Quick Reveal & Logs Icon Buttons (30x30)
                IconActionButton(symbol: "folder", tooltip: "在访达中显示应用", size: 30, action: reveal)
                IconActionButton(symbol: "doc.text.magnifyingglass", tooltip: "查看运行日志", size: 30, action: logs)

                // More Actions Button (30x30, identical box to IconActionButton, no misaligned disclosure chevron)
                if !item.isOriginal && (2...9999).contains(item.index) {
                    IconActionButton(symbol: "ellipsis", tooltip: "更多实例操作", size: 30) {
                        showMorePopover.toggle()
                    }
                    .popover(isPresented: $showMorePopover, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
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
                        .padding(6)
                        .frame(width: 176)
                    }
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
                        Text(item.running ? "切换" : "打开")
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
            tint: item.isOriginal ? accent : (item.running ? .green : nil)
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
                    // Target Instances List
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

                    // Chinese Highlights Section
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

                    // Official Changelog WebView
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
                Button("备份并升级", action: confirm)
                    .buttonStyle(ModernButtonStyle(variant: .upgrade))
                    .disabled(busy || instances.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 600)
    }
}

// MARK: - Main Content View

private enum InstanceFilter: String, CaseIterable, Identifiable {
    case all = "全部副本"
    case running = "运行中"
    case upgradable = "可升级"
    var id: String { rawValue }
}

struct ContentView: View {
    let updaterController: SPUStandardUpdaterController
    @StateObject private var store = InstanceStore()
    @State private var showCreate = false
    @State private var upgradeRequest: UpgradeRequest?
    @State private var showBackupManager = false
    @State private var showUpdateSettings = false
    @State private var pendingDestroy: ManagedInstance?
    @State private var pendingClear: ManagedInstance?
    @State private var destination = URL(fileURLWithPath: "/Applications")
    @State private var selectedFilter: InstanceFilter = .all
    @State private var refreshSpin: Double = 0
    @State private var logExpanded = true
    @State private var appeared = false
    @Environment(\.colorScheme) private var colorScheme

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.4.4"
    }

    private var filteredClones: [ManagedInstance] {
        switch selectedFilter {
        case .all:
            return store.cloneInstances
        case .running:
            return store.cloneInstances.filter(\.running)
        case .upgradable:
            return store.pendingUpgrades
        }
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
            // Subtle Ambient Background Layer
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
                    VStack(alignment: .leading, spacing: 20) {
                        headerDashboard
                        metricsStrip

                        if let primary = store.primaryInstance {
                            primarySection(primary)
                        }

                        if !store.instances.isEmpty {
                            clonesSection
                        } else {
                            emptyStateView
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
        .frame(minWidth: 820, minHeight: 620)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshRunningStates()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            store.refreshRunningStates()
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
        .alert("操作未完成", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("好") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    // MARK: - Top Dashboard Header

    private var headerDashboard: some View {
        HStack(alignment: .center, spacing: 16) {
            // Brand Emblem + Title
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
                    }
                    Text("Apple Silicon 多实例隔离工作台 · 独立账号、凭据标识与专属回调")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            // Action Toolbar (All controls strictly 34pt height)
            HStack(alignment: .center, spacing: 8) {
                IconActionButton(
                    symbol: "arrow.clockwise",
                    tooltip: "刷新实例与状态",
                    size: 34,
                    rotation: refreshSpin
                ) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        refreshSpin += 360
                    }
                    store.refresh()
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

    // MARK: - 3-Column Metrics Strip

    private var metricsStrip: some View {
        HStack(alignment: .center, spacing: 12) {
            metricTile(
                title: "本机实例概览",
                value: "\(store.instances.count) 个实例",
                subtitle: store.runningCount > 0 ? "\(store.runningCount) 个实例正在后台或前台运行" : "所有实例当前均未运行",
                symbol: "square.stack.3d.up.fill",
                tint: accent,
                leadingIndicator: {
                    AnyView(PulsingStatusDot(active: store.runningCount > 0))
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

    // MARK: - Primary Instance Section

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
                sourceVersion: store.sourceVersion,
                busy: store.busy,
                canUpgrade: false,
                upgrade: {},
                open: { store.open(primary) },
                quit: { store.quit(primary) },
                reveal: { store.reveal(primary) },
                logs: { store.showLogs(primary) },
                verify: {},
                clearWorkspace: {},
                destroy: {}
            )
        }
    }

    // MARK: - Isolated Clones Section

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

                // Segmented Pill Filter
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
                            .frame(height: 24)
                            .background {
                                if active {
                                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.09))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }
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
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: selectedFilter == .running ? "moon.zzz" : "checkmark.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text(selectedFilter == .running ? "当前没有正在运行的副本" : "所有副本均已是最新版本")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 26)
                    Spacer()
                }
                .systemSurface(radius: 15)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(filteredClones.enumerated()), id: \.element.id) { idx, item in
                        InstanceCard(
                            item: item,
                            sourceVersion: store.sourceVersion,
                            busy: store.busy,
                            canUpgrade: store.compatibility == "已支持本机版本",
                            upgrade: { upgradeRequest = UpgradeRequest(instances: [item]) },
                            open: { store.open(item) },
                            quit: { store.quit(item) },
                            reveal: { store.reveal(item) },
                            logs: { store.showLogs(item) },
                            verify: { store.toggleVerified(item) },
                            clearWorkspace: { pendingClear = item },
                            destroy: { pendingDestroy = item }
                        )
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

    private func filterCount(_ filter: InstanceFilter) -> Int {
        switch filter {
        case .all: return store.cloneInstances.count
        case .running: return store.cloneInstances.filter(\.running).count
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
                Button("创建并启动") {
                    store.create(index: store.nextIndex, destination: destination)
                    showCreate = false
                }
                .buttonStyle(ModernButtonStyle(variant: .primary))
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
                    Text("实例仍在运行。请先保存工作并点击卡片上的“退出”后再试。")
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
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { automatic = updater.automaticallyChecksForUpdates && updater.automaticallyDownloadsUpdates }
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

@main struct AntigravityMultiplexerApp: App {
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
