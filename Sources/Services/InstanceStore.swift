import AppKit
import Foundation
import SwiftUI
import UserNotifications

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let targetBundle = (info["bundleID"] as? String) ?? (info["instanceID"] as? String) {
            Task { @MainActor in InstanceStore.current?.openInstance(byBundleID: targetBundle) }
        }
        completionHandler()
    }
}

@MainActor
final class InstanceStore: ObservableObject {
    static weak var current: InstanceStore?

    @Published var instances: [ManagedInstance] = []
    @Published var activities: [String: InstanceActivity] = [:]
    @Published var accounts: [String: InstanceAccountInfo] = [:]
    @Published var resourceMetrics: [String: InstanceResourceMetric] = [:]
    @Published var diskUsages: [String: InstanceDiskUsage] = [:]

    @Published var aliases: [String: String] {
        didSet { UserDefaults.standard.set(aliases, forKey: "instanceAliases") }
    }
    @Published var appTheme: AppTheme {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme") }
    }
    @Published var maskAccountEmails: Bool {
        didSet { UserDefaults.standard.set(maskAccountEmails, forKey: "maskAccountEmails") }
    }
    @Published var globalHotkeysEnabled: Bool {
        didSet {
            UserDefaults.standard.set(globalHotkeysEnabled, forKey: "globalHotkeysEnabled")
            if globalHotkeysEnabled { GlobalHotKeyManager.shared.register() } else { GlobalHotKeyManager.shared.unregister() }
        }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var dockVisibleInstanceIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(dockVisibleInstanceIDs).sorted(), forKey: "dockVisibleInstanceIDs")
            syncAppStorageSettings(for: instances)
        }
    }

    @Published var sourceVersion: String = "—"
    @Published var compatibility: String = "检查中"
    @Published var busy: Bool = false
    @Published var operationProgress: Double? = nil
    @Published var operationStage: String = ""
    @Published var output: String = ""
    @Published var error: String? = nil

    var openMainWindowHandler: (() -> Void)?

    private let supportedVersions: Set<String> = {
        guard let url = Bundle.main.url(forResource: "compatibility", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return Set(records.keys)
    }()
    private let ordinalWords = ["Second": 2, "Third": 3, "Fourth": 4, "Fifth": 5, "Sixth": 6, "Seventh": 7, "Eighth": 8, "Ninth": 9, "Tenth": 10, "Eleventh": 11, "Twelfth": 12]
    private var localNetworkVerifiedBundles = Set<String>()
    private var lastOpenTime: [String: Date] = [:]
    private var lastOpenWindowBundles = Set<String>()
    private var lastFrontmostAntigravityBundle: String?
    private var taskStartTimes: [String: Date] = [:]
    private var hasInitializedActivityBaseline = false
    private var lastNotifiedStates: [String: (state: TaskRunState, stepIndex: Int)] = [:]
    private var isScanningTelemetry = false
    private var lastTelemetryScanStartTime: Date?
    private var activeConversationURLs: [String: String] = [:]
    private var standbyTickCount = 0
    private var telemetryTickCount = 0

    nonisolated private static let cdpSession: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.urlCache = nil; cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.httpShouldSetCookies = false; cfg.httpCookieAcceptPolicy = .never
        cfg.timeoutIntervalForRequest = 1.0; cfg.timeoutIntervalForResource = 2.0
        return URLSession(configuration: cfg)
    }()

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "instanceAliases") == nil {
            var migrated: [String: String] = [:]
            if let data = defaults.data(forKey: "instance_user_metas"),
               let legacy = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                for (bundleID, meta) in legacy {
                    if let nick = (meta["nickname"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty {
                        migrated[bundleID] = nick
                    }
                }
            }
            self.aliases = migrated
            defaults.set(migrated, forKey: "instanceAliases")
        } else {
            self.aliases = (defaults.dictionary(forKey: "instanceAliases") as? [String: String]) ?? [:]
        }

        self.appTheme = AppTheme(rawValue: defaults.string(forKey: "appTheme") ?? "") ?? .system
        self.maskAccountEmails = defaults.object(forKey: "maskAccountEmails") as? Bool ?? false
        self.globalHotkeysEnabled = defaults.object(forKey: "globalHotkeysEnabled") as? Bool ?? true
        self.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.dockVisibleInstanceIDs = defaults.object(forKey: "dockVisibleInstanceIDs") != nil
            ? Set(defaults.stringArray(forKey: "dockVisibleInstanceIDs") ?? [])
            : Self.readSystemDockAntigravityBundleIDs()

        Self.current = self
        setupNotifications()
        GlobalHotKeyManager.shared.setup(
            onCollapseAll: { [weak self] in self?.collapseAllToMonitorWall() },
            onToggleInstance: { [weak self] in self?.toggleInstanceByHotkey($0) },
            shouldRegister: globalHotkeysEnabled
        )
        refresh()
    }

    // MARK: - Computed Metrics & Helpers

    var runningCount: Int { instances.filter(\.running).count }
    var runningCloneCount: Int { instances.filter { !$0.isOriginal && $0.running }.count }
    var visibleWindowCount: Int { instances.filter { $0.running && !$0.isHidden }.count }
    var activeTaskCount: Int { instances.filter { $0.running && (activities[$0.id]?.state.isActiveTask ?? false) }.count }
    var loggedInCount: Int { instances.filter { accounts[$0.id]?.isLoggedIn == true }.count }

    var duplicateAccountCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for item in instances {
            guard let acct = accounts[item.id], acct.isLoggedIn else { continue }
            let key = acct.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !key.isEmpty && key != "已授权独立账号" { counts[key, default: 0] += 1 }
        }
        return counts
    }

    var uniqueAccountCount: Int {
        var seen = Set<String>(), placeholders = 0
        for item in instances {
            guard let acct = accounts[item.id], acct.isLoggedIn else { continue }
            let key = acct.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if key.isEmpty || key == "已授权独立账号" { placeholders += 1 } else { seen.insert(key) }
        }
        return seen.count + placeholders
    }

    var pendingUpgrades: [ManagedInstance] {
        guard canUpgrade, sourceVersion.first?.isNumber == true else { return [] }
        return instances.filter { !$0.isOriginal && $0.version.first?.isNumber == true && $0.version.compare(sourceVersion, options: .numeric) == .orderedAscending }
    }

    var canUpgrade: Bool { compatibility == "已支持本机版本" }
    var nextAvailableIndex: Int { max(8, (instances.map(\.index).filter { $0 < 10_000 }.max() ?? 7) + 1) }

    func alias(for item: ManagedInstance) -> String { aliases[item.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    func displayTitle(for item: ManagedInstance) -> String { let c = alias(for: item); return c.isEmpty ? item.name : c }

    func setAlias(_ newAlias: String, for item: ManagedInstance) {
        let trimmed = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { aliases.removeValue(forKey: item.id) } else { aliases[item.id] = trimmed }
    }

    func activity(for item: ManagedInstance) -> InstanceActivity {
        activities[item.id] ?? (item.running ? InstanceActivity(state: .idle, currentAction: "已启动就绪") : .stopped)
    }
    func account(for item: ManagedInstance) -> InstanceAccountInfo { accounts[item.id] ?? .unauthenticated }

    func duplicateCount(for item: ManagedInstance) -> Int {
        let acct = account(for: item)
        guard acct.isLoggedIn else { return 0 }
        let key = acct.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty, key != "已授权独立账号" else { return 1 }
        return duplicateAccountCounts[key] ?? 1
    }

    func metric(for item: ManagedInstance) -> InstanceResourceMetric { resourceMetrics[item.id] ?? InstanceResourceMetric() }
    func diskUsage(for item: ManagedInstance) -> InstanceDiskUsage { diskUsages[item.id] ?? InstanceDiskUsage() }

    func runningDuration(for item: ManagedInstance) -> String? {
        guard item.running, let state = activities[item.id]?.state,
              state == .runningTask || state == .stalled, let start = taskStartTimes[item.id] else { return nil }
        let elapsed = Int(Date().timeIntervalSince(start))
        if elapsed < 60 { return "\(max(1, (elapsed / 5) * 5))s" }
        let m = elapsed / 60, s = (elapsed % 60) / 10 * 10
        return s > 0 ? "\(m)m \(s)s" : "\(m)m"
    }

    func copyAccountEmail(for item: ManagedInstance) {
        let info = account(for: item)
        guard info.isLoggedIn, !info.email.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info.email, forType: .string)
    }

    // MARK: - Dock Residency & Local Network Isolation

    func isShownInDock(_ item: ManagedInstance) -> Bool { dockVisibleInstanceIDs.contains(item.id) }
    func toggleShowInDock(_ item: ManagedInstance) { setShowInDock(item, show: !isShownInDock(item), syncSystemDock: true) }

    func setShowInDock(_ item: ManagedInstance, show: Bool, syncSystemDock: Bool = true) {
        var updated = dockVisibleInstanceIDs
        if show { updated.insert(item.id) } else { updated.remove(item.id) }
        dockVisibleInstanceIDs = updated
        if item.isOriginal && !show && item.running && !activity(for: item).state.isActiveTask { quit(item) }
        if syncSystemDock { syncSystemDockPersistentApps() }
    }

    func setBatchShowInDock(_ ids: Set<String>, syncSystemDock: Bool = true) {
        let removedOrig = dockVisibleInstanceIDs.contains("com.google.antigravity") && !ids.contains("com.google.antigravity")
        dockVisibleInstanceIDs = ids
        if removedOrig, let orig = instances.first(where: { $0.isOriginal }), orig.running, !activity(for: orig).state.isActiveTask {
            quit(orig)
        }
        if syncSystemDock { syncSystemDockPersistentApps() }
    }

    static func readSystemDockAntigravityBundleIDs() -> Set<String> {
        let dockPlist = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        guard let data = try? Data(contentsOf: dockPlist),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let apps = plist["persistent-apps"] as? [[String: Any]] else { return ["com.google.antigravity"] }
        let found = Set(apps.compactMap { entry -> String? in
            guard let bid = (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String,
                  bid == "com.google.antigravity" || bid.hasPrefix("local.antigravity.") else { return nil }
            return bid
        })
        return found.isEmpty ? ["com.google.antigravity"] : found
    }

    func syncSystemDockPersistentApps() {
        let selected = instances.filter { dockVisibleInstanceIDs.contains($0.id) }
            .sorted { $0.isOriginal != $1.isOriginal ? $0.isOriginal : $0.index < $1.index }
        let selectedIDs = Set(selected.map(\.bundleID))
        let dockPlist = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        guard let data = try? Data(contentsOf: dockPlist),
              var format = Optional(PropertyListSerialization.PropertyListFormat.binary),
              var plist = (try? PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: &format)) as? [String: Any],
              var apps = plist["persistent-apps"] as? [[String: Any]] else { return }

        let isAntigravityTile: ([String: Any]) -> Bool = { entry in
            guard let bid = (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String else { return false }
            return bid == "com.google.antigravity" || bid.hasPrefix("local.antigravity.")
        }
        var existingTiles: [String: [String: Any]] = [:]
        var firstIdx: Int?, muxIdx: Int?
        for (i, entry) in apps.enumerated() {
            guard let bid = (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String else { continue }
            if bid == "com.google.antigravity" || bid.hasPrefix("local.antigravity.") {
                firstIdx = firstIdx ?? i; existingTiles[bid] = entry
            } else if bid == "dev.chenxu.antigravity-multiplexer" && muxIdx == nil {
                muxIdx = i
            }
        }
        let anchor = firstIdx ?? muxIdx ?? apps.count
        let targetSlot = apps.prefix(anchor).filter { !isAntigravityTile($0) }.count
        apps.removeAll(where: isAntigravityTile)

        let newEntries: [[String: Any]] = selected.map { item in
            let urlStr = item.path.absoluteString + (item.path.absoluteString.hasSuffix("/") ? "" : "/")
            if var cached = existingTiles[item.bundleID], var td = cached["tile-data"] as? [String: Any] {
                td["bundle-identifier"] = item.bundleID; td["file-label"] = item.name
                td["file-data"] = ["_CFURLString": urlStr, "_CFURLStringType": 15]
                cached["tile-data"] = td
                return cached
            }
            return ["tile-type": "file-tile", "tile-data": ["bundle-identifier": item.bundleID, "dock-extra": 0, "file-data": ["_CFURLString": urlStr, "_CFURLStringType": 15], "file-label": item.name, "file-type": 41]]
        }
        apps.insert(contentsOf: newEntries, at: min(max(0, targetSlot), apps.count))
        plist["persistent-apps"] = apps
        if var recent = plist["recent-apps"] as? [[String: Any]] {
            recent.removeAll { entry in
                guard let bid = (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String else { return false }
                return (bid == "com.google.antigravity" || bid.hasPrefix("local.antigravity.")) && !selectedIDs.contains(bid)
            }
            plist["recent-apps"] = recent
        }
        if let out = try? PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0) {
            try? out.write(to: dockPlist, options: .atomic)
            CFPreferencesAppSynchronize("com.apple.dock" as CFString)
            Task.detached(priority: .utility) {
                let proc = Process(); proc.executableURL = URL(fileURLWithPath: "/usr/bin/killall"); proc.arguments = ["Dock"]
                try? proc.run(); proc.waitUntilExit()
            }
        }
    }

    func ensureCloneLocalNetworkIsolation(for items: [ManagedInstance]) {
        for item in items where !item.isOriginal && !localNetworkVerifiedBundles.contains(item.bundleID) {
            guard let info = NSDictionary(contentsOf: item.path.appendingPathComponent("Contents/Info.plist")) else { continue }
            localNetworkVerifiedBundles.insert(item.bundleID)
            if info["NSLocalNetworkUsageDescription"] == nil,
               let script = Bundle.main.url(forResource: "create_instance", withExtension: "py") {
                let appPath = item.path.path
                Task.detached(priority: .utility) {
                    let proc = Process(); proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                    proc.arguments = [script.path, "--repair-local-network", appPath]
                    try? proc.run(); proc.waitUntilExit()
                }
            }
        }
    }

    private func syncAppStorageSettings(for items: [ManagedInstance]) {
        for item in items where !item.isOriginal {
            guard FileManager.default.fileExists(atPath: item.userDataURL.path) else { continue }
            let storageFile = item.userDataURL.appendingPathComponent("app_storage.json")
            var json = (try? Data(contentsOf: storageFile)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            let policy = dockVisibleInstanceIDs.contains(item.id) ? "always" : "hidden"
            guard (json["runInBackground"] as? String) != "true" || (json["dockPolicy"] as? String) != policy else { continue }
            json["runInBackground"] = "true"
            json["dockPolicy"] = policy
            if let encoded = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
                try? encoded.write(to: storageFile, options: .atomic)
            }
        }
    }

    // MARK: - Discovery & Telemetry Polling

    func refresh() {
        let fm = FileManager.default
        let roots = [URL(fileURLWithPath: "/Applications"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        let onScreenPIDs = Self.getOnScreenWindowPIDs()
        var found: [ManagedInstance] = [], seen = Set<String>()

        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for app in entries where app.pathExtension == "app" && app.lastPathComponent.hasPrefix("Antigravity") {
                guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
                      let bundle = info["CFBundleIdentifier"] as? String,
                      bundle == "com.google.antigravity" || bundle.hasPrefix("local.antigravity."),
                      seen.insert(bundle).inserted else { continue }
                let version = info["CFBundleShortVersionString"] as? String ?? "未知"
                let name = info["CFBundleDisplayName"] as? String ?? app.deletingPathExtension().lastPathComponent
                let index = instanceIndex(forName: app.deletingPathExtension().lastPathComponent, bundle: bundle)
                let runningApp = runningApplication(bundleID: bundle, path: app)
                found.append(ManagedInstance(id: bundle, name: name, path: app, bundleID: bundle, version: version, index: index,
                                             running: runningApp != nil, isHidden: isInstanceCollapsed(runningApp, onScreenPIDs: onScreenPIDs)))
            }
        }
        let sorted = found.sorted { $0.isOriginal != $1.isOriginal ? $0.isOriginal : $0.index < $1.index }
        syncAppStorageSettings(for: sorted)
        ensureCloneLocalNetworkIsolation(for: sorted)
        lastOpenWindowBundles = Set(sorted.filter { $0.running && !$0.isHidden }.map(\.bundleID))
        TelemetryScanner.clearStoppedCache()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
            instances = sorted
            accounts = AccountDetector.detectAll(for: sorted)
            if let source = sorted.first(where: { $0.isOriginal }) {
                sourceVersion = source.version
                compatibility = supportedVersions.contains(source.version) ? "已支持本机版本" : "版本待适配"
            } else {
                sourceVersion = "—"; compatibility = "需要官方原版"
            }
        }
        refreshTelemetry(force: true)
        let snapshot = sorted
        Task.detached(priority: .utility) {
            let usages = TelemetryScanner.scanDiskUsages(instances: snapshot)
            await MainActor.run { [weak self] in self?.diskUsages = usages }
        }
    }

    func refreshRunningStates() {
        let onScreenPIDs = Self.getOnScreenWindowPIDs()
        let updated = instances.map { item in
            let app = runningApplication(bundleID: item.bundleID, path: item.path)
            return ManagedInstance(id: item.id, name: item.name, path: item.path, bundleID: item.bundleID, version: item.version,
                                   index: item.index, running: app != nil, isHidden: isInstanceCollapsed(app, onScreenPIDs: onScreenPIDs))
        }
        let openBundles = Set(updated.filter { $0.running && !$0.isHidden }.map(\.bundleID))
        if let lastFront = lastFrontmostAntigravityBundle, lastOpenWindowBundles.contains(lastFront),
           !openBundles.contains(lastFront), updated.first(where: { $0.bundleID == lastFront })?.running == true {
            lastFrontmostAntigravityBundle = nil
            bringMonitorWallToFront()
        }
        lastOpenWindowBundles = openBundles
        if updated != instances { withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { instances = updated } }
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           front == "com.google.antigravity" || front.hasPrefix("local.antigravity.") {
            lastFrontmostAntigravityBundle = front
        }
        refreshTelemetry()
    }

    func periodicTick() {
        if !isMainWindowVisible && activeTaskCount == 0 {
            standbyTickCount += 1; guard standbyTickCount % 5 == 0 else { return }
        } else if !isMainWindowVisible {
            standbyTickCount += 1; guard standbyTickCount % 2 == 0 else { return }
        } else {
            standbyTickCount = 0
        }
        refreshRunningStates()
    }

    private func refreshTelemetry(force: Bool = false) {
        if let start = lastTelemetryScanStartTime, Date().timeIntervalSince(start) > 6.0 { isScanningTelemetry = false }
        if !force, let start = lastTelemetryScanStartTime, Date().timeIntervalSince(start) < 1.2 { return }
        guard !isScanningTelemetry else { return }
        isScanningTelemetry = true; lastTelemetryScanStartTime = Date()

        let snapshot = instances
        var knownConvIDs: [String: String] = [:]
        for (id, urlStr) in activeConversationURLs {
            if let last = URL(string: urlStr)?.pathComponents.last, !last.isEmpty { knownConvIDs[id] = last }
        }
        let runningPids = Dictionary(uniqueKeysWithValues: snapshot.compactMap { item -> (String, pid_t)? in
            guard item.running, let app = runningApplication(bundleID: item.bundleID, path: item.path) else { return nil }
            return (item.id, app.processIdentifier)
        })
        let shouldScanMetrics = isMainWindowVisible || activeTaskCount > 0 || force
        let prevMetrics = resourceMetrics
        telemetryTickCount += 1
        let tick = telemetryTickCount, frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        Task.detached(priority: .utility) {
            let scanned = TelemetryScanner.scan(instances: snapshot, knownConvIDs: knownConvIDs)
            let metrics = shouldScanMetrics ? TelemetryScanner.scanResourceMetrics(instances: snapshot, runningAppPids: runningPids) : prevMetrics
            let detectedAccounts = AccountDetector.detectAll(for: snapshot)
            let cdpMeta = await Self.fetchCDPMetadata(for: snapshot, frontmostBundleID: frontmost, telemetryTick: tick)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isScanningTelemetry = false
                var merged = scanned
                for (id, ws) in cdpMeta.workspaces where !ws.isEmpty { merged[id]?.workspace = ws }
                self.processActivityChanges(newActivities: merged)
                if self.activities != merged { withAnimation(.easeInOut(duration: 0.2)) { self.activities = merged } }
                if self.resourceMetrics != metrics { self.resourceMetrics = metrics }
                if self.accounts != detectedAccounts { self.accounts = detectedAccounts }
                if self.activeConversationURLs != cdpMeta.urls { self.activeConversationURLs = cdpMeta.urls }
            }
        }
    }

    nonisolated private static func fetchCDPMetadata(for items: [ManagedInstance], frontmostBundleID: String?, telemetryTick: Int) async -> (urls: [String: String], workspaces: [String: String]) {
        var urls: [String: String] = [:], workspaces: [String: String] = [:]
        let collected = await withTaskGroup(of: (String, String?, String?)?.self) { group in
            for item in items where item.running && (frontmostBundleID == item.bundleID || telemetryTick % 3 == 0) {
                let portFile = item.userDataURL.appendingPathComponent("DevToolsActivePort")
                guard let content = try? String(contentsOf: portFile, encoding: .utf8),
                      let port = content.components(separatedBy: .newlines).first.flatMap({ Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }),
                      let listURL = URL(string: "http://127.0.0.1:\(port)/json/list") else { continue }
                group.addTask {
                    var req = URLRequest(url: listURL); req.timeoutInterval = 0.8; req.setValue("close", forHTTPHeaderField: "Connection")
                    guard let (data, _) = try? await cdpSession.data(for: req),
                          let targets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                          let main = targets.first(where: { ($0["type"] as? String) == "page" && ((($0["url"] as? String)?.hasPrefix("http://127.0.0.1:") == true) || (($0["url"] as? String)?.hasPrefix("https://127.0.0.1:") == true)) }) else { return nil }
                    let u = main["url"] as? String
                    let parts = (main["title"] as? String)?.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
                    let ws: String? = parts.count >= 3 ? parts[1] : (parts.count == 2 ? parts[0] : nil)
                    return (item.id, (u?.contains("/c/") == true) ? u : nil, ws)
                }
            }
            var out: [(String, String?, String?)] = []
            for await entry in group { if let entry { out.append(entry) } }
            return out
        }
        for (id, u, ws) in collected {
            if let u { urls[id] = u }
            if let ws, !ws.isEmpty { workspaces[id] = ws }
        }
        return (urls, workspaces)
    }

    // MARK: - Window Control (Strictly Non-Destructive)

    func openInstance(byBundleID bundleID: String) {
        if let item = instances.first(where: { $0.bundleID == bundleID }) { open(item) }
    }

    func open(_ item: ManagedInstance) {
        let now = Date()
        if let last = lastOpenTime[item.id], now.timeIntervalSince(last) < 0.6 { return }
        lastOpenTime[item.id] = now
        syncAppStorageSettings(for: [item])
        lastFrontmostAntigravityBundle = item.bundleID

        if let app = runningApplication(bundleID: item.bundleID, path: item.path) {
            _ = app.unhide()
            app.activate(options: [.activateIgnoringOtherApps])
            Self.runAppleScriptAsync("""
            tell application "System Events"
                tell (first process whose bundle identifier is "\(item.bundleID)")
                    set visible to true
                    set frontmost to true
                    repeat with w in (windows)
                        try
                            if value of attribute "AXMinimized" of w is true then set value of attribute "AXMinimized" of w to false
                        end try
                    end repeat
                end tell
            end tell
            try
                tell application id "\(item.bundleID)" to reopen
            end try
            """)
        }
        let cfg = NSWorkspace.OpenConfiguration(); cfg.activates = true; cfg.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: item.path, configuration: cfg) { [weak self] app, _ in
            DispatchQueue.main.async {
                app?.activate(options: [.activateIgnoringOtherApps])
                self?.refreshRunningStates()
            }
            for delay in [0.8, 1.8] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self?.refreshRunningStates() }
            }
        }
    }

    func toggleInstanceByHotkey(_ number: Int) {
        if number == 1 {
            if let primary = instances.first(where: { $0.isOriginal }) ?? instances.first { toggleInstance(primary) }
            return
        }
        let clones = instances.filter { !$0.isOriginal }.sorted { $0.index < $1.index }
        if let target = instances.first(where: { !$0.isOriginal && $0.index == number }) ?? (number - 2 >= 0 && number - 2 < clones.count ? clones[number - 2] : nil) {
            toggleInstance(target)
        }
    }

    private func toggleInstance(_ item: ManagedInstance) {
        if item.running && NSWorkspace.shared.frontmostApplication?.bundleIdentifier == item.bundleID && !item.isHidden {
            hideInstance(item)
        } else {
            open(item)
        }
    }

    func hideInstance(_ item: ManagedInstance) {
        guard let app = runningApplication(bundleID: item.bundleID, path: item.path) else { return }
        syncAppStorageSettings(for: [item])
        collapseInstanceWindow(item, app: app)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.refreshRunningStates() }
    }

    func collapseAllToMonitorWall() {
        let runningItems = instances.filter(\.running)
        for item in runningItems {
            if let app = runningApplication(bundleID: item.bundleID, path: item.path) {
                _ = app.hide()
                Self.collapseWindowViaAccessibility(pid: app.processIdentifier)
            }
            Self.runAppleScriptAsync("tell application \"System Events\" to set visible of (first process whose bundle identifier is \"\(item.bundleID)\") to false")
        }
        Task {
            await withTaskGroup(of: Void.self) { group in
                for item in runningItems { group.addTask { _ = await Self.collapseInstanceWindowCDP(item: item) } }
            }
            await MainActor.run { self.refreshRunningStates() }
        }
        lastFrontmostAntigravityBundle = nil
        bringMonitorWallToFront()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.refreshRunningStates() }
    }

    private func collapseInstanceWindow(_ item: ManagedInstance, app: NSRunningApplication?) {
        guard let app = app ?? runningApplication(bundleID: item.bundleID, path: item.path) else { return }
        _ = app.hide()
        Task { _ = await Self.collapseInstanceWindowCDP(item: item) }
        Self.collapseWindowViaAccessibility(pid: app.processIdentifier)
        Self.runAppleScriptAsync("tell application \"System Events\" to set visible of (first process whose bundle identifier is \"\(item.bundleID)\") to false")
    }

    nonisolated private static func collapseInstanceWindowCDP(item: ManagedInstance) async -> Bool {
        let portFile = item.userDataURL.appendingPathComponent("DevToolsActivePort")
        guard let content = try? String(contentsOf: portFile, encoding: .utf8),
              let port = content.components(separatedBy: .newlines).first.flatMap({ Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }),
              let listURL = URL(string: "http://127.0.0.1:\(port)/json/list") else { return false }
        var req = URLRequest(url: listURL); req.timeoutInterval = 0.8; req.setValue("close", forHTTPHeaderField: "Connection")
        guard let (data, _) = try? await cdpSession.data(for: req),
              let targets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return false }

        var collapsedAny = false
        for target in targets where (target["type"] as? String) == "page" {
            guard let wsURL = (target["webSocketDebuggerUrl"] as? String).flatMap(URL.init(string:)) else { continue }
            let task = cdpSession.webSocketTask(with: wsURL)
            task.resume()
            defer { task.cancel(with: .goingAway, reason: nil) }
            let js = "(() => { try { if (window.electronNative && typeof window.electronNative.minimize === 'function') { window.electronNative.minimize(); return true; } } catch (e) {} return false; })()"
            let payload: [String: Any] = ["id": 9999, "method": "Runtime.evaluate", "params": ["expression": js, "returnByValue": true]]
            if let jsonData = try? JSONSerialization.data(withJSONObject: payload), let str = String(data: jsonData, encoding: .utf8) {
                try? await task.send(.string(str))
                _ = try? await withTimeout(seconds: 0.4) { try await task.receive() }
                collapsedAny = true
            }
        }
        return collapsedAny
    }

    private static func collapseWindowViaAccessibility(pid: pid_t) {
        let appElem = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }
        for win in windows {
            _ = AXUIElementSetAttributeValue(win, "AXMinimized" as CFString, kCFBooleanTrue)
            var minBtnRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, "AXMinimizeButton" as CFString, &minBtnRef) == .success, let minBtnRef {
                _ = AXUIElementPerformAction(minBtnRef as! AXUIElement, kAXPressAction as CFString)
            }
        }
    }

    func bringMonitorWallToFront() {
        NSApp.unhide(nil); NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where !(window is NSPanel) && !window.isSheet && window.canBecomeMain {
            if let sheet = window.attachedSheet { sheet.makeKeyAndOrderFront(nil) } else { window.makeKeyAndOrderFront(nil) }
            return
        }
        if let handler = openMainWindowHandler { handler() }
        else { NotificationCenter.default.post(name: .openMainWindowRequested, object: nil) }
    }

    // MARK: - Quit, Reveal & Script Operations

    func quit(_ item: ManagedInstance) {
        guard !busy else { return }
        let expected = item.path.resolvingSymlinksInPath().standardizedFileURL
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID).filter {
            !$0.isTerminated && $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == expected
        }
        guard !apps.isEmpty else { refreshRunningStates(); return }
        if apps.map({ $0.terminate() }).contains(false) { error = "无法正常退出 \(item.name)，请在该实例中选择“退出”后重试。" }
        Task { @MainActor in try? await Task.sleep(nanoseconds: 500_000_000); refreshRunningStates() }
    }

    func quitAllClones() { quitAllInstances(includeMain: false) }

    func quitAllInstances(includeMain: Bool = false) {
        guard !busy else { return }
        for item in instances where item.running && (includeMain || !item.isOriginal) { quit(item) }
    }

    func reveal(_ item: ManagedInstance) { NSWorkspace.shared.activateFileViewerSelecting([item.path]) }

    func revealProfile(_ item: ManagedInstance) {
        if FileManager.default.fileExists(atPath: item.profileURL.path) { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.profileURL.path) }
        else { error = "工作空间目录尚未生成（\(item.profileURL.path)）" }
    }

    func showLogs(_ item: ManagedInstance) {
        if FileManager.default.fileExists(atPath: item.logsURL.path) { NSWorkspace.shared.open(item.logsURL) }
        else { error = "日志目录尚未生成（\(item.logsURL.path)）" }
    }

    func createInstance(initialAlias: String = "", destination: URL = URL(fileURLWithPath: "/Applications")) {
        guard !busy else { return }
        guard let script = Bundle.main.url(forResource: "create_instance", withExtension: "py") else { error = "应用缺少创建组件。"; return }
        let idx = nextAvailableIndex, trimmed = initialAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        runScript(script, arguments: ["--index", String(idx), "--source", "/Applications/Antigravity.app", "--destination", destination.path], starting: "正在检查官方应用…\n") { [weak self] in
            if !trimmed.isEmpty { self?.aliases["local.antigravity.instance\(idx)"] = trimmed }
        }
    }

    func upgrade(_ selected: [ManagedInstance]) {
        guard !busy, !selected.isEmpty, selected.allSatisfy({ pendingUpgrades.contains($0) }) else { return }
        guard let script = Bundle.main.url(forResource: "upgrade_all", withExtension: "py") else { error = "应用缺少升级组件。"; return }
        runScript(script, arguments: ["--source", "/Applications/Antigravity.app", "--only-indices", selected.map { String($0.index) }.joined(separator: ","), "--skip-backup"],
                  starting: "正在检查本机主实例和选定副本；⚡️ 已跳过备份直接替换…\n")
    }

    func clearWorkspace(_ item: ManagedInstance) {
        guard !busy, !item.isOriginal, !item.running, (2...9999).contains(item.index) else { return }
        guard let script = Bundle.main.url(forResource: "clear_workspace", withExtension: "py") else { error = "应用缺少工作空间清理组件。"; return }
        runScript(script, arguments: ["--index", String(item.index), "--app", item.path.path], starting: "正在核对并清空 \(item.name) 的独立工作空间…\n") {
            TelemetryScanner.invalidateCache(for: item)
        }
    }

    func destroy(_ item: ManagedInstance) {
        guard !busy, !item.isOriginal, (2...9999).contains(item.index) else { return }
        guard let script = Bundle.main.url(forResource: "destroy_instance", withExtension: "py") else { error = "应用缺少实例销毁组件。"; return }
        runScript(script, arguments: ["--index", String(item.index), "--app", item.path.path], starting: "正在核对并销毁 \(item.name)…\n") { [weak self] in
            guard let self else { return }
            self.aliases.removeValue(forKey: item.id)
            if self.dockVisibleInstanceIDs.remove(item.id) != nil { self.syncSystemDockPersistentApps() }
            TelemetryScanner.invalidateCache(for: item)
        }
    }

    func clearConsoleOutput() {
        guard !busy else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            output = ""; operationProgress = nil; operationStage = ""; error = nil
        }
    }

    private func runScript(_ script: URL, arguments: [String], starting: String, onSuccess: (() -> Void)? = nil) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            busy = true; error = nil; output = starting; operationProgress = 0.05; operationStage = "正在准备操作环境…"
        }
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [script.path] + arguments
        process.standardOutput = pipe; process.standardError = pipe
        do {
            try process.run()
            try? pipe.fileHandleForWriting.close()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var decoder = ScriptOutputDecoder()
                while true {
                    let data = pipe.fileHandleForReading.availableData
                    guard !data.isEmpty else { break }
                    let text = decoder.append(data)
                    if !text.isEmpty { DispatchQueue.main.async { self?.processStreamChunk(text) } }
                }
                let tail = decoder.append(Data(), finishing: true)
                process.waitUntilExit()
                try? pipe.fileHandleForReading.close()
                DispatchQueue.main.async {
                    guard let self else { return }
                    if !tail.isEmpty { self.processStreamChunk(tail) }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        self.busy = false
                        if process.terminationStatus == 0 {
                            self.operationProgress = 1.0; self.operationStage = "操作已全部顺利完成"
                        } else {
                            self.error = "操作未完成，请查看下方记录。"
                        }
                    }
                    if process.terminationStatus == 0 { onSuccess?() }
                    self.refresh()
                }
            }
        } catch {
            withAnimation { busy = false; operationProgress = nil; operationStage = "" }
            self.error = "无法启动组件：\(error.localizedDescription)"
        }
    }

    private func processStreamChunk(_ chunk: String) {
        var clean = ""
        let lines = chunk.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            if line.hasPrefix("[PROGRESS:"), let close = line.firstIndex(of: "]") {
                let pctStr = line[line.index(line.startIndex, offsetBy: 10)..<close]
                let msg = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
                if let pct = Double(pctStr) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        operationProgress = min(1.0, max(0.0, pct / 100.0))
                        if !msg.isEmpty { operationStage = msg }
                    }
                }
            } else {
                clean += line + (i == lines.count - 1 ? "" : "\n")
            }
        }
        if !clean.isEmpty { output += clean }
    }

    // MARK: - Ordinal Naming, Notifications & Low-Level Helpers

    static func ordinalName(_ number: Int) -> String {
        let units = [1: "First", 2: "Second", 3: "Third", 4: "Fourth", 5: "Fifth", 6: "Sixth", 7: "Seventh", 8: "Eighth", 9: "Ninth", 10: "Tenth", 11: "Eleventh", 12: "Twelfth", 13: "Thirteenth", 14: "Fourteenth", 15: "Fifteenth", 16: "Sixteenth", 17: "Seventeenth", 18: "Eighteenth", 19: "Nineteenth"]
        let tens = [20: "Twenty", 30: "Thirty", 40: "Forty", 50: "Fifty", 60: "Sixty", 70: "Seventy", 80: "Eighty", 90: "Ninety"]
        let exactTens = [20: "Twentieth", 30: "Thirtieth", 40: "Fortieth", 50: "Fiftieth", 60: "Sixtieth", 70: "Seventieth", 80: "Eightieth", 90: "Ninetieth"]
        let cardinals = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
        if let u = units[number] { return u }
        if number < 100 {
            let dec = (number / 10) * 10, rem = number % 10
            return rem == 0 ? (exactTens[number] ?? "\(number)th") : "\(tens[dec] ?? "") \(units[rem] ?? "")"
        }
        if number < 1000 {
            let h = number / 100, rem = number % 100
            return "\(cardinals[h]) Hundred" + (rem > 0 ? " \(ordinalName(rem))" : "th")
        }
        if number < 10_000 {
            let t = number / 1000, rem = number % 1000
            return "\(cardinals[t]) Thousand" + (rem > 0 ? " \(ordinalName(rem))" : "th")
        }
        return "\(number)th"
    }

    private func setupNotifications() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = AppNotificationDelegate.shared
        let openAction = UNNotificationAction(identifier: "ACTION_OPEN_INSTANCE", title: "立即调出窗口", options: [.foreground])
        center.setNotificationCategories([UNNotificationCategory(identifier: "INSTANCE_NOTIFICATION_CATEGORY", actions: [openAction], intentIdentifiers: [], options: [.customDismissAction])])
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func processActivityChanges(newActivities: [String: InstanceActivity]) {
        if !hasInitializedActivityBaseline {
            for (id, act) in newActivities { lastNotifiedStates[id] = (act.state, act.stepIndex) }
            hasInitializedActivityBaseline = true
            return
        }
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        for item in instances {
            if !item.running {
                taskStartTimes.removeValue(forKey: item.id)
                lastNotifiedStates[item.id] = (.stopped, 0)
                continue
            }
            guard let act = newActivities[item.id] else { continue }
            let prev = lastNotifiedStates[item.id]
            let prevState = prev?.state ?? .stopped, prevStep = prev?.stepIndex ?? -1
            if (act.state == .runningTask || act.state == .stalled) && prevState != .runningTask && prevState != .stalled {
                taskStartTimes[item.id] = Date()
            } else if act.state == .idle || act.state == .error {
                taskStartTimes.removeValue(forKey: item.id)
            }

            if notificationsEnabled && frontmost != item.bundleID {
                let prefix = item.isOriginal ? "👑 " : "", name = displayTitle(for: item)
                let wsSub = act.workspace.isEmpty ? nil : "工作区: \(act.workspace)"
                if (prevState == .runningTask || prevState == .stalled) && act.state == .idle {
                    let body = act.currentAction.hasPrefix("上次：") ? String(act.currentAction.dropFirst(3)) : act.currentAction
                    sendNotification("done-\(item.id)-\(act.stepIndex)", "\(prefix)\(name) · 任务已完成", wsSub ?? "Agent 步骤已顺利完成", body.isEmpty ? "点击立即调出窗口" : body, item.bundleID)
                } else if act.state == .needsAttention && (prevState != .needsAttention || act.stepIndex != prevStep) {
                    sendNotification("attn-\(item.id)-\(act.stepIndex)", "\(prefix)\(name) · 等待确认", wsSub ?? "Agent 需要用户确认操作", act.currentAction.isEmpty ? "点击立即确认" : act.currentAction, item.bundleID)
                } else if act.state == .error && prevState != .error {
                    sendNotification("err-\(item.id)-\(act.stepIndex)", "\(prefix)\(name) · 任务执行异常", wsSub ?? "执行步骤报错", act.currentAction.isEmpty ? "点击查看详情" : act.currentAction, item.bundleID)
                } else if act.state == .stalled && prevState != .stalled {
                    sendNotification("stall-\(item.id)-\(act.stepIndex)", "\(prefix)\(name) · 任务疑似挂起", wsSub.map { "\($0) · 超 3 分钟无响应" } ?? "已持续超过 3 分钟无响应", act.currentAction, item.bundleID)
                }
            }
            if prev == nil || prevState != act.state || prevStep != act.stepIndex {
                lastNotifiedStates[item.id] = (act.state, act.stepIndex)
            }
        }
    }

    private func sendNotification(_ id: String, _ title: String, _ subtitle: String, _ body: String, _ bundleID: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title; content.subtitle = subtitle; content.body = body
        content.sound = .default; content.categoryIdentifier = "INSTANCE_NOTIFICATION_CATEGORY"
        content.userInfo = ["bundleID": bundleID]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil), withCompletionHandler: nil)
    }

    private var isMainWindowVisible: Bool {
        NSApp.windows.contains { !($0 is NSPanel) && !$0.isSheet && $0.canBecomeMain && $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible) }
    }

    private func instanceIndex(forName name: String, bundle: String) -> Int {
        if bundle == "com.google.antigravity" { return 1 }
        for (word, value) in ordinalWords where name.contains(word) { return value }
        if let value = Int(name.replacingOccurrences(of: "Antigravity ", with: "")) { return value }
        if let digits = bundle.components(separatedBy: "instance").last, let value = Int(digits) { return value }
        return 10_000
    }

    private func runningApplication(bundleID: String, path: URL) -> NSRunningApplication? {
        let candidates = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { !$0.isTerminated }
        guard candidates.count > 1 else { return candidates.first }
        let expected = path.resolvingSymlinksInPath().standardizedFileURL
        return candidates.first { $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == expected } ?? candidates.first
    }

    private static func getOnScreenWindowPIDs() -> Set<pid_t> {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return Set(list.compactMap { win in
            guard (win[kCGWindowLayer as String] as? Int) == 0,
                  let pid = win[kCGWindowOwnerPID as String] as? pid_t,
                  let b = win[kCGWindowBounds as String] as? [String: CGFloat],
                  (b["Width"] ?? 0) >= 200, (b["Height"] ?? 0) >= 200 else { return nil }
            return pid
        })
    }

    private func isInstanceCollapsed(_ app: NSRunningApplication?, onScreenPIDs: Set<pid_t>) -> Bool {
        guard let app else { return true }
        return app.isHidden || !onScreenPIDs.contains(app.processIdentifier)
    }

    nonisolated private static func runAppleScriptAsync(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async { var err: NSDictionary?; NSAppleScript(source: source)?.executeAndReturnError(&err) }
    }

    nonisolated private static func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)); throw CancellationError() }
            guard let result = try await group.next() else { throw CancellationError() }
            group.cancelAll()
            return result
        }
    }
}
