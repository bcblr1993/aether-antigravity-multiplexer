import AppKit
import SwiftUI
import Sparkle
import WebKit

private let accent = Color.accentColor

// Native materials follow the system's Liquid Glass appearance and accessibility settings.
private struct SystemSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: radius).fill(Color(nsColor: .controlBackgroundColor))
            } else {
                RoundedRectangle(cornerRadius: radius).fill(.regularMaterial)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.separator.opacity(0.35)))
    }
}

private extension View {
    func systemSurface(radius: CGFloat) -> some View { modifier(SystemSurface(radius: radius)) }
}

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
        instances = found.sorted { $0.index < $1.index }
        if let source = instances.first(where: { $0.isOriginal }) {
            sourceVersion = source.version
            compatibility = supportedVersions.contains(source.version) ? "已支持本机版本" : "版本待适配"
        } else {
            sourceVersion = "未找到"
            compatibility = "需要官方原版"
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
        if updated != instances { instances = updated }
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

    private func runScript(_ script: URL, arguments: [String], starting: String) {
        busy = true
        error = nil
        output = starting
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
                self?.busy = false
                if completed.terminationStatus != 0 { self?.error = "操作未完成，请查看下方记录。" }
                self?.refresh()
            }
        }
        do { try process.run() }
        catch { busy = false; self.error = "无法启动组件：\(error.localizedDescription)" }
    }

}

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
    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(accent.opacity(0.10)).frame(width: 46, height: 46)
                Image(systemName: item.isOriginal ? "sparkle" : "square.on.square")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.name).font(.system(size: 15, weight: .semibold))
                    Text(item.running ? "运行中" : "未运行")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(item.running ? Color.green : Color.secondary)
                        .help("关闭窗口后应用可能仍在后台运行。点击“退出”才能结束实例并清空工作空间。")
                }
                Text("v\(item.version)  ·  \(item.profile)")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            if !item.isOriginal && item.version.compare(sourceVersion, options: .numeric) == .orderedAscending {
                Button("升级…", action: upgrade).buttonStyle(.bordered)
                    .disabled(busy || !canUpgrade)
            }
            if item.verified { Label("已验证", systemImage: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(.green) }
            Menu {
                Button("在访达中显示", action: reveal)
                Button("查看日志", action: logs)
                if item.index >= 8 && !item.isOriginal {
                    Divider()
                    Button(item.verified ? "取消登录验证标记" : "标记已完成登录验证", action: verify)
                }
                if !item.isOriginal && (2...9999).contains(item.index) {
                    Divider()
                    Button("清空工作空间…", role: .destructive, action: clearWorkspace)
                        .disabled(item.running)
                    Button("销毁实例…", role: .destructive, action: destroy)
                }
            } label: { Image(systemName: "ellipsis").frame(width: 18, height: 18) }
                .menuStyle(.borderlessButton).frame(width: 28)
            if item.running {
                Button("退出", action: quit).buttonStyle(.bordered)
                    .help("正常退出实例；请先保存未完成的工作。")
                    .disabled(busy)
            }
            Button("打开", action: open).buttonStyle(.borderedProminent)
        }
        .padding(16)
        .systemSurface(radius: 17)
    }
}

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
                content = "<p>官方日志加载失败。可查看下方中文摘要，或通过官方链接查看完整日志。</p>"
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
        guard !rows.isEmpty else { return "<p>官方页面暂未提供此版本区间的日志，请查看下方中文摘要或官方链接。</p>" }
        return rows.joined().replacingOccurrences(of: "<details ", with: "<details open ")
            .replacingOccurrences(of: #"<svg\b[\s\S]*?</svg>"#, with: "", options: .regularExpression)
    }
    static func page(_ content: String) -> String {
        """
        <!doctype html><html><head><meta name="color-scheme" content="light dark">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
        <style>
        body{margin:0;background:transparent;color:#222;font:12px -apple-system;line-height:1.6}
        @media(prefers-color-scheme:dark){body{color:#eee}}
        article{padding:0 12px 12px 0}article+article{border-top:1px solid #8885;padding-top:16px}
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
        VStack(alignment: .leading, spacing: 16) {
            Text(instances.count == 1 ? "升级指定副本" : "升级全部副本")
                .font(.system(size: 21, weight: .bold))
            Text("本机主实例 v\(targetVersion) · 待升级 \(instances.count) 个")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(instances) { item in
                            HStack { Text(item.name); Spacer(); Text("v\(item.version) → v\(targetVersion)")
                                .foregroundStyle(.secondary) }.font(.system(size: 12))
                        }
                    }.padding(14).systemSurface(radius: 13)
                    Text("官方更新日志（原文）").font(.system(size: 15, weight: .semibold))
                    Text("联网读取官方原文，保留完整新增功能和修复条目。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    OfficialReleaseNotesView(fromVersions: instances.map(\.version), targetVersion: targetVersion)
                        .frame(height: 300)
                    Text("中文重点摘要").font(.system(size: 15, weight: .semibold))
                    if notes.isEmpty {
                        Text("尚未收录此版本区间的更新摘要，可查看官方完整更新日志。")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("v\(note.version)").font(.system(size: 13, weight: .semibold))
                            ForEach(note.highlights, id: \.self) { text in
                                Text("• " + text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Text("显示所选副本到目标版本之间已收录的重点变化；不同起始版本获得的变化不同。摘要来自官方更新日志，完整条目请查看原文。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Link("查看官方完整更新日志 ↗", destination: URL(string: "https://www.antigravity.google/docs/changelog?tab=hub")!)
                        .font(.system(size: 12))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
            }.frame(height: 400)
            Text("请先保存选定副本中的工作。工具会从本机主实例复制程序，备份这些副本的应用、账号目录和窗口数据后安装；账号目录保持原路径。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack { Spacer()
                Button("取消", action: cancel)
                Button("备份并升级", action: confirm).buttonStyle(.borderedProminent).disabled(busy || instances.isEmpty)
            }
        }.padding(24).frame(width: 570)
    }
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
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Aether Antigravity Multiplexer")
                                    .font(.system(size: 22, weight: .semibold))
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                Text("在这台 Apple Silicon Mac 上管理独立实例。")
                                    .font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 16)
                            Button { showCreate = true } label: { Label("创建实例", systemImage: "plus") }
                                .buttonStyle(.borderedProminent).disabled(store.busy)
                        }
                        HStack(spacing: 8) {
                        Button { updaterController.checkForUpdates(nil) } label: { Label("管理器更新", systemImage: "arrow.down.circle") }
                            .buttonStyle(.bordered)
                        Button { showUpdateSettings = true } label: { Image(systemName: "gearshape") }
                            .buttonStyle(.bordered).help("更新设置")
                        Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.bordered).help("刷新列表")
                        Button { store.refreshBackups(); showBackupManager = true } label: { Label("管理备份", systemImage: "externaldrive") }
                            .buttonStyle(.bordered)
                        Button { upgradeRequest = UpgradeRequest(instances: store.pendingUpgrades) } label: { Label("升级全部副本", systemImage: "arrow.up.circle") }
                            .buttonStyle(.bordered).disabled(store.busy || store.pendingUpgrades.isEmpty || store.compatibility != "已支持本机版本")
                        Spacer(minLength: 0)
                        }
                    }
                    HStack(spacing: 12) {
                        statusTile(title: "已发现实例", value: "\(store.instances.count)", symbol: "square.stack.3d.up")
                        statusTile(title: "本机主实例", value: store.sourceVersion, symbol: "checkmark.shield")
                        statusTile(title: "创建/升级适配", value: store.compatibility, symbol: "wrench.adjustable")
                    }
                    HStack {
                        Text("本机实例").font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("凭据留在各自的数据目录中").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    ForEach(store.instances) { item in
                        InstanceCard(item: item, sourceVersion: store.sourceVersion, busy: store.busy,
                                     canUpgrade: store.compatibility == "已支持本机版本",
                                     upgrade: { upgradeRequest = UpgradeRequest(instances: [item]) },
                                     open: { store.open(item) }, quit: { store.quit(item) }, reveal: { store.reveal(item) },
                                     logs: { store.showLogs(item) }, verify: { store.toggleVerified(item) },
                                     clearWorkspace: { pendingClear = item },
                                     destroy: { pendingDestroy = item })
                    }
                    if store.instances.isEmpty {
                        VStack(spacing: 7) {
                            Image(systemName: "square.stack.3d.up").font(.system(size: 26)).foregroundStyle(accent)
                            Text("未发现 Antigravity").font(.system(size: 14, weight: .semibold))
                            Text("请先安装官方 Apple Silicon 版本。").font(.system(size: 12)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(28)
                            .systemSurface(radius: 17)
                    }
                    if store.busy || !store.output.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack { Text("操作记录").font(.system(size: 14, weight: .semibold)); Spacer()
                                if store.busy { ProgressView().controlSize(.small) } }
                            Text(store.output).font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(16).systemSurface(radius: 16)
                    }
                }.padding(26)
            }
        }
        .background(.regularMaterial)
        .frame(minWidth: 760, minHeight: 590)
        .onAppear { store.refresh() }
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
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("创建 Antigravity \(ordinalName(store.nextIndex))").font(.system(size: 21, weight: .bold))
                        Text("使用已安装的官方 Antigravity.app，新账号将在新窗口登录。")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 10) {
                    detailRow("实例名称", "Antigravity \(ordinalName(store.nextIndex))")
                    detailRow("独立数据", "~/.gemini-\(store.nextIndex - 1)")
                    detailRow("专属回调", "antigravity-\(store.nextIndex)")
                    detailRow("源版本", store.sourceVersion)
                }.padding(16).systemSurface(radius: 13)
                HStack {
                    Text("安装位置").font(.system(size: 12)).foregroundStyle(.secondary)
                    Picker("", selection: $destination) {
                        Text("应用程序 /Applications").tag(URL(fileURLWithPath: "/Applications"))
                        Text("个人应用程序 ~/Applications").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))
                    }.labelsHidden().frame(width: 280)
                }
                Text("创建前会核对原版签名与文件哈希。未知版本会停止，已有实例不会被覆盖。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                HStack { Spacer()
                    Button("取消") { showCreate = false }
                    Button("创建并打开") {
                        store.create(index: store.nextIndex, destination: destination)
                        showCreate = false
                    }.buttonStyle(.borderedProminent).disabled(store.compatibility != "已支持本机版本")
                }
            }.padding(24).frame(width: 510)
        }
        .sheet(item: $upgradeRequest) { request in
            UpgradeConfirmationView(instances: request.instances, targetVersion: store.sourceVersion,
                                    busy: store.busy,
                                    cancel: { upgradeRequest = nil },
                                    confirm: { store.upgrade(request.instances); upgradeRequest = nil })
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
    private func statusTile(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol).foregroundStyle(accent).font(.system(size: 18))
                .frame(width: 34, height: 34).background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }.padding(14).frame(maxWidth: .infinity)
            .systemSurface(radius: 15)
    }
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.medium) }
            .font(.system(size: 12))
    }
}

private struct InstanceNameConfirmation: View {
    let name: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("此操作无法撤销。请输入完整实例名称以确认：")
                .font(.system(size: 12))
            HStack(spacing: 10) {
                Text(name).font(.system(size: 13, weight: .semibold)).textSelection(.enabled)
                Spacer()
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    copied = pasteboard.setString(name, forType: .string)
                } label: {
                    Label(copied ? "已复制" : "复制实例名", systemImage: copied ? "checkmark" : "doc.on.doc")
                }.buttonStyle(.bordered)
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
            Text("清空 \(item.name) 的工作空间").font(.system(size: 21, weight: .bold))
            Text("仅永久清空 \(item.profile) 内的所有数据（包括隐藏文件），保留这个目录、实例应用、其他资料目录及升级备份。独立登录文件位于工作空间外，不会删除；此操作也不等同于退出账号。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text(item.profile).font(.system(size: 12, design: .monospaced))
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .systemSurface(radius: 12)
            if item.running {
                Text("实例仍在运行。请先保存工作并退出，然后刷新列表重试。")
                    .font(.system(size: 12)).foregroundStyle(.orange)
            }
            InstanceNameConfirmation(name: item.name)
            TextField("实例名称", text: $confirmation).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("永久清空", role: .destructive, action: clear)
                    .disabled(busy || item.running || confirmation != item.name)
            }
        }.padding(24).frame(width: 540)
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
            Text("销毁 \(item.name)").font(.system(size: 21, weight: .bold))
            Text("将永久删除所选副本的应用、独立账号资料、窗口数据、日志、登录文件及管理清单。主实例和其他副本不会删除；已有升级备份会保留。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 7) {
                Text(item.path.path)
                Text(item.profile)
                Text("~/Library/Application Support/\(item.name)")
                Text("~/Library/Logs/\(item.name)")
            }.font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .systemSurface(radius: 12)
            if item.running {
                Text("实例仍在运行。请先保存工作并退出，然后刷新列表重试。")
                    .font(.system(size: 12)).foregroundStyle(.orange)
            }
            InstanceNameConfirmation(name: item.name)
            TextField("实例名称", text: $confirmation)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("永久销毁", role: .destructive, action: destroy)
                    .disabled(busy || item.running || confirmation != item.name)
            }
        }.padding(24).frame(width: 530)
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
            HStack {
                Text("升级备份").font(.system(size: 21, weight: .bold))
                Spacer()
                Button { store.refreshBackups() } label: { Image(systemName: "arrow.clockwise") }
                    .help("刷新备份列表")
            }
            Text("\(store.backups.count) 个批次 · 共 \(totalSize)")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if store.backups.isEmpty {
                Text("还没有升级备份。")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.backups) { batch in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(batch.dateLabel).font(.system(size: 14, weight: .semibold))
                                    Text("\(batch.archiveCount) 个压缩包 · \(batch.sizeLabel)")
                                        .font(.system(size: 12)).foregroundStyle(.secondary)
                                    if batch.referenced {
                                        Text("当前升级记录引用此备份").font(.system(size: 11)).foregroundStyle(.orange)
                                    }
                                    if !batch.deletable {
                                        Text("含非备份文件，请在访达检查").font(.system(size: 11)).foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Button("永久删除", role: .destructive) { pendingDeletion = batch }
                                    .disabled(store.busy || !batch.deletable)
                            }
                            .padding(13).systemSurface(radius: 12)
                        }
                    }
                }.frame(maxHeight: 350)
            }
            Text("只删除你选定的备份批次。删除后无法恢复；请先确认各副本的登录和项目正常。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if let error = store.error {
                Text(error).font(.system(size: 12)).foregroundStyle(.red)
            }
            HStack {
                Button("在访达中查看") { store.showBackups() }.disabled(store.backups.isEmpty)
                Spacer()
                Button("完成") { dismiss() }
            }
        }
        .padding(24).frame(width: 570)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("管理器更新").font(.system(size: 21, weight: .bold))
            Toggle("自动检查、下载并安装更新", isOn: $automatic)
                .onChange(of: automatic) { enabled in
                    updater.automaticallyChecksForUpdates = enabled
                    updater.automaticallyDownloadsUpdates = enabled
                }
            Text("开启后每天检查新版本。更新只替换多开管理器；实例和账号数据保留。需要授权时，macOS 会提示你。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack {
                Button("立即检查") { updater.checkForUpdates(); dismiss() }
                Spacer()
                Button("完成") { dismiss() }
            }
        }
        .padding(24).frame(width: 440)
        .onAppear { automatic = updater.automaticallyChecksForUpdates && updater.automaticallyDownloadsUpdates }
    }
}

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
            .windowStyle(.titleBar).windowToolbarStyle(.unifiedCompact)
            .commands {
                MainWindowCommands()
                CommandGroup(after: .appInfo) {
                    Button("检查多开管理器更新…") { updaterController.checkForUpdates(nil) }
                }
            }
    }
}
