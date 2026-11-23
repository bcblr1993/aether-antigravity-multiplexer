import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case dark, light, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dark: return "暗曜石"
        case .light: return "纯净浅色"
        case .system: return "跟随系统"
        }
    }
    var symbol: String {
        switch self {
        case .dark: return "moon.stars.fill"
        case .light: return "sun.max.fill"
        case .system: return "desktopcomputer"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

enum InstanceFilter: String, CaseIterable, Identifiable {
    case all, running, unauthenticated, upgradable
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "全部"
        case .running: return "运行中"
        case .unauthenticated: return "未登录"
        case .upgradable: return "可升级"
        }
    }
}

enum TaskRunState: Equatable, Sendable {
    case stopped, idle, runningTask, stalled, needsAttention, error
    var label: String {
        switch self {
        case .stopped: return "未启动"
        case .idle: return "空闲就绪"
        case .runningTask: return "任务执行中"
        case .stalled: return "疑似挂起"
        case .needsAttention: return "等待确认"
        case .error: return "任务异常"
        }
    }
    var symbol: String {
        switch self {
        case .stopped: return "poweroff"
        case .idle: return "checkmark.circle.fill"
        case .runningTask: return "bolt.horizontal.circle.fill"
        case .stalled: return "clock.badge.exclamationmark.fill"
        case .needsAttention: return "bell.badge.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    var isActiveTask: Bool {
        self == .runningTask || self == .stalled || self == .needsAttention
    }
}

struct InstanceActivity: Equatable, Sendable {
    var state: TaskRunState = .stopped
    var currentAction: String = "点击缩略图启动实例"
    var workspace: String = ""
    var lastUpdatedLabel: String = ""
    var stepIndex: Int = 0
    var latestConversationID: String = ""
    static let stopped = InstanceActivity(state: .stopped, currentAction: "点击缩略图启动实例", workspace: "", lastUpdatedLabel: "")
}

struct InstanceAccountInfo: Equatable, Sendable {
    var email: String = ""
    var isLoggedIn: Bool = false
    static let unauthenticated = InstanceAccountInfo(email: "", isLoggedIn: false)
    func displayEmail(masked: Bool) -> String { masked ? AccountDetector.maskEmail(email) : email }
}

struct InstanceDiskUsage: Equatable, Sendable {
    var profileBytes: Int64 = 0
    var userDataBytes: Int64 = 0
    var appBundleBytes: Int64 = 0
    var totalDataBytes: Int64 { profileBytes + userDataBytes }
    var formattedProfile: String { Self.formatBytes(profileBytes) }
    var formattedUserData: String { Self.formatBytes(userDataBytes) }
    var formattedAppBundle: String { Self.formatBytes(appBundleBytes) }
    var formattedTotalData: String { Self.formatBytes(totalDataBytes) }

    static func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        if gb >= 1.0 { return String(format: "%.2f GB", gb) }
        if mb >= 1.0 { return String(format: "%.1f MB", mb) }
        if kb >= 1.0 { return "\(Int(kb)) KB" }
        return "\(bytes) B"
    }
}

struct InstanceResourceMetric: Equatable, Sendable {
    var cpuPercent: Double = 0.0
    var rssBytes: Int64 = 0
    var processCount: Int = 0

    var cpuLabel: String {
        cpuPercent < 0.8 ? "0.0%" : String(format: "%.1f%%", (cpuPercent * 2.0).rounded() / 2.0)
    }
    var memoryLabel: String {
        guard rssBytes > 0 else { return "0 MB" }
        let mb = Double(rssBytes) / (1024.0 * 1024.0)
        return mb >= 1024 ? String(format: "%.2f GB", mb / 1024.0) : "\(max(1, (Int(mb) / 4) * 4)) MB"
    }
    var compactLabel: String { "\(cpuLabel) · \(memoryLabel)" }

    static func == (lhs: InstanceResourceMetric, rhs: InstanceResourceMetric) -> Bool {
        (lhs.processCount == 0) == (rhs.processCount == 0) &&
        abs(lhs.processCount - rhs.processCount) <= 1 &&
        lhs.memoryLabel == rhs.memoryLabel &&
        lhs.cpuLabel == rhs.cpuLabel &&
        (lhs.cpuPercent > 15) == (rhs.cpuPercent > 15)
    }
}

struct ManagedInstance: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: URL
    let bundleID: String
    let version: String
    let index: Int
    let running: Bool
    let isHidden: Bool

    var isOriginal: Bool { bundleID == "com.google.antigravity" }
    var badgeLabel: String { isOriginal ? "MAIN 01" : String(format: "#%02d", index) }
    var profile: String { isOriginal ? "~/.gemini" : "~/.gemini-\(max(index - 1, 1))" }
    var profileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(isOriginal ? ".gemini" : ".gemini-\(max(index - 1, 1))")
    }
    var userDataURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support").appendingPathComponent(isOriginal ? "Antigravity" : name)
    }
    var logsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs").appendingPathComponent(isOriginal ? "Antigravity" : name)
    }
    var callbackScheme: String {
        if isOriginal { return "antigravity" }
        if index >= 8 { return "antigravity-\(index)" }
        let parts = name.split(separator: " ", maxSplits: 1)
        return parts.count > 1 ? "antigravity-\(parts[1].lowercased())" : "antigravity-\(index)"
    }
}

struct SourceReleaseNotes: Decodable, Identifiable, Sendable {
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

struct UpgradeRequest: Identifiable {
    let id = UUID()
    let instances: [ManagedInstance]
}

extension Notification.Name {
    static let openMainWindowRequested = Notification.Name("openMainWindowRequested")
    static let openCreateInstanceRequested = Notification.Name("openCreateInstanceRequested")
}
