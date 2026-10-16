import AppKit
import SwiftUI
import Sparkle
import WebKit
import UserNotifications
import Carbon
import Darwin

private let accent = Color.accentColor

// MARK: - Haptic Feedback Manager

final class HapticManager {
    static let shared = HapticManager()
    private init() {}

    func play(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic, performanceTime: NSHapticFeedbackManager.PerformanceTime = .default) {
        guard UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: performanceTime)
    }
}

// MARK: - App Theme & Appearance

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func localized(lang: AppLanguage) -> String {
        switch self {
        case .system: return L10n.tr(.themeSystem, lang: lang)
        case .light: return L10n.tr(.themeLight, lang: lang)
        case .dark: return L10n.tr(.themeDark, lang: lang)
        }
    }
}

// MARK: - Internationalization & Localization (i18n)

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"
    case ja = "ja"
    case zhHant = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Auto"
        case .zhHans: return "简体中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .zhHant: return "繁體中文"
        }
    }

    var effective: AppLanguage {
        if self == .system {
            let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
            if preferred.hasPrefix("en") { return .en }
            if preferred.hasPrefix("ja") { return .ja }
            if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") { return .zhHant }
            return .zhHans
        }
        return self
    }
}

enum L10nKey {
    // Header
    case appSubtitle
    case collapseAll
    case refreshTooltip
    case taskHistoryTooltip
    case manageBackupsTooltip
    case checkUpdatesTooltip
    case updateSettingsTooltip
    case upgradeAllCount
    case createInstance
    case kernelDirectHelp

    // Metrics
    case metricRunningTitle
    case metricRunningCount
    case metricRunningSubtitleActive
    case metricRunningSubtitleIdle
    case metricSourceTitle
    case metricDiskTitle
    case metricDiskSubtitle
    case metricCompatTitle
    case metricCompatAllLatest
    case metricCompatUpgradeable

    // Filters & View Modes
    case filterAll
    case filterRunning
    case filterBusyTask
    case filterWithTags
    case viewGrid
    case viewList
    case densityTitle
    case densityComfortable
    case densityCompact
    case densityMatrix
    case quickSwitcher
    case optionsAndPrefs

    // Preferences & Popover
    case prefTitle
    case prefThemeSection
    case themeSystem
    case themeLight
    case themeDark
    case prefLangSection
    case langSystem
    case prefTilingSection
    case tileSplitLeftRight
    case tileQuadGrid
    case tileCascade
    case prefHapticsTitle
    case prefHapticsSubtitle
    case prefHotkeysTitle
    case prefHotkeysSubtitle
    case prefHotkeysGuide
    case prefSoloFocusTitle
    case prefSoloFocusSubtitle
    case prefFloatingHUDTitle
    case prefFloatingHUDSubtitle
    case prefEcoModeTitle
    case prefEcoModeSubtitle
    case prefNotificationsTitle
    case prefNotificationsSubtitle

    // Instance Tile & Card
    case clickToLaunch
    case bringToFront
    case restoreWindow
    case hideToBackground
    case quitInstance
    case upgradeInstance
    case openInstance
    case switchInstance
    case verifiedBadge
    case officialMainBadge
    case upgradableTo
    case moreOptionsTooltip

    // Task states
    case stateStopped
    case stateRunningTask
    case stateStalled
    case stateNeedsAttention
    case stateIdle
    case stateError

    // Floating HUD
    case hudStalled
    case hudActive
    case hudIdle
    case hudBackToWall

    // Quick Switcher
    case quickSwitcherPlaceholder
    case quickSwitcherNoMatch
    case legendSelect
    case legendBringFront
    case legendDirect
    case legendClose
    case quickSwitcherSummary

    // UI Convenience Aliases
    static var optionsTitle: L10nKey { .prefTitle }
    static var themeTitle: L10nKey { .prefThemeSection }
    static var langTitle: L10nKey { .prefLangSection }
    static var tilePresetsTitle: L10nKey { .prefTilingSection }
    static var hapticsEnabled: L10nKey { .prefHapticsTitle }
    static var hapticsSubtitle: L10nKey { .prefHapticsSubtitle }
    static var ecoModeEnabled: L10nKey { .prefEcoModeTitle }
    static var ecoModeSubtitle: L10nKey { .prefEcoModeSubtitle }
    static var toolbarCollapseAll: L10nKey { .collapseAll }
    static var toolbarCreateInstance: L10nKey { .createInstance }
    static var metricRunningMonitor: L10nKey { .metricRunningTitle }
    static var metricPrimaryVersion: L10nKey { .metricSourceTitle }
    static var metricDiskUsage: L10nKey { .metricDiskTitle }
    static var metricCompatibility: L10nKey { .metricCompatTitle }
    static var toolbarQuickSwitcher: L10nKey { .quickSwitcher }
    static var toolbarOptions: L10nKey { .optionsAndPrefs }
    static var hudCollapse: L10nKey { .hudBackToWall }
    static var qsSearchPlaceholder: L10nKey { .quickSwitcherPlaceholder }
    static var qsNoMatch: L10nKey { .quickSwitcherNoMatch }
    static var qsSelect: L10nKey { .legendSelect }
    static var qsActivate: L10nKey { .legendBringFront }
    static var qsDirect: L10nKey { .legendDirect }
    static var qsClose: L10nKey { .legendClose }
    static var hudStalledTasks: L10nKey { .hudStalled }
    static var hudRunningTasks: L10nKey { .hudActive }
    static var viewDensityTitle: L10nKey { .densityTitle }
}

struct L10n {
    static func tr(_ key: L10nKey, lang: AppLanguage) -> String {
        let eff = lang.effective
        switch eff {
        case .en:
            return stringEN(key)
        case .ja:
            return stringJA(key)
        case .zhHant:
            return stringZHHant(key)
        default:
            return stringZHHans(key)
        }
    }

    private static func stringZHHans(_ key: L10nKey) -> String {
        switch key {
        case .appSubtitle: return "Apple Silicon 多实例监控与隔离工作台 · 实时任务感知与一键调出"
        case .collapseAll: return "收起全部窗口"
        case .refreshTooltip: return "刷新实例与任务状态"
        case .taskHistoryTooltip: return "任务事件与执行动态中心"
        case .manageBackupsTooltip: return "管理升级备份"
        case .checkUpdatesTooltip: return "检查管理器更新"
        case .updateSettingsTooltip: return "管理器自动更新设置"
        case .upgradeAllCount: return "升级全部"
        case .createInstance: return "创建实例"
        case .kernelDirectHelp: return "内核直接通信：使用 macOS Darwin libproc 直读进程指标，0 子进程开销，微秒级能效"

        case .metricRunningTitle: return "实时运行与任务监控"
        case .metricRunningCount: return "运行中"
        case .metricRunningSubtitleActive: return "个实例正在执行 Agent 任务"
        case .metricRunningSubtitleIdle: return "所有已启动实例均处于空闲就绪状态"
        case .metricSourceTitle: return "官方主实例版本"
        case .metricDiskTitle: return "工作空间总磁盘占用"
        case .metricDiskSubtitle: return "个实例独立数据与存储"
        case .metricCompatTitle: return "创建与升级适配"
        case .metricCompatAllLatest: return "全部独立副本均为最新版本"
        case .metricCompatUpgradeable: return "个副本可升级至"

        case .filterAll: return "全部"
        case .filterRunning: return "运行中"
        case .filterBusyTask: return "跑任务中"
        case .filterWithTags: return "有备注标签"
        case .viewGrid: return "网格"
        case .viewList: return "列表"
        case .densityTitle: return "视图密度"
        case .densityComfortable: return "宽适视界"
        case .densityCompact: return "精致紧凑"
        case .densityMatrix: return "超密矩阵"
        case .quickSwitcher: return "极速切换"
        case .optionsAndPrefs: return "选项与偏好"

        case .prefTitle: return "工作台偏好与窗口管理"
        case .prefThemeSection: return "外观主题 (Theme)"
        case .themeSystem: return "跟随系统"
        case .themeLight: return "浅色模式"
        case .themeDark: return "深色模式"
        case .prefLangSection: return "显示语言 (Language)"
        case .langSystem: return "跟随系统"
        case .prefTilingSection: return "多窗口桌面平铺 (Window Tiling)"
        case .tileSplitLeftRight: return "左右双分屏"
        case .tileQuadGrid: return "四宫格平铺"
        case .tileCascade: return "瀑布级联排布"
        case .prefHapticsTitle: return "触觉力反馈 (Haptic Feedback)"
        case .prefHapticsSubtitle: return "切换实例、停靠浮窗与点击时提供细腻物理微震"
        case .prefHotkeysTitle: return "全局快捷键 (⌥Space / ⌥1~9)"
        case .prefHotkeysSubtitle: return "任意桌面呼出极速切换面板或直达 1~9 号实例"
        case .prefHotkeysGuide: return "快捷键快速指南"
        case .prefSoloFocusTitle: return "专注单窗口模式"
        case .prefSoloFocusSubtitle: return "调出某实例时自动隐藏其他实例窗口，保持桌面整洁"
        case .prefFloatingHUDTitle: return "桌面悬浮返回胶囊"
        case .prefFloatingHUDSubtitle: return "在实例窗口右下角浮现微型返回条，点一下即可收起回监控台"
        case .prefEcoModeTitle: return "分身智能节能模式"
        case .prefEcoModeSubtitle: return "无任务运行的后台分身自动降低重绘能耗"
        case .prefNotificationsTitle: return "任务系统通知 (精准调出)"
        case .prefNotificationsSubtitle: return "实例 Agent 任务完成或需介入时弹送系统通知，点击直达"

        case .clickToLaunch: return "点击缩略图启动实例"
        case .bringToFront: return "调出实例"
        case .restoreWindow: return "恢复窗口"
        case .hideToBackground: return "收起"
        case .quitInstance: return "退出"
        case .upgradeInstance: return "升级"
        case .openInstance: return "打开"
        case .switchInstance: return "切换"
        case .verifiedBadge: return "已验证"
        case .officialMainBadge: return "官方主实例源"
        case .upgradableTo: return "可升"
        case .moreOptionsTooltip: return "更多实例操作"

        case .stateStopped: return "未启动"
        case .stateRunningTask: return "任务执行中"
        case .stateStalled: return "疑似挂起"
        case .stateNeedsAttention: return "等待确认"
        case .stateIdle: return "空闲就绪"
        case .stateError: return "任务异常"

        case .hudStalled: return "个任务疑似挂起卡顿"
        case .hudActive: return "个实例正在跑任务"
        case .hudIdle: return "所有运行实例空闲"
        case .hudBackToWall: return "收起回监控台"

        case .quickSwitcherPlaceholder: return "搜索实例名称、标签或工作区… (↑↓ 移动, ⏎ 调出, ⌥1~9 直达)"
        case .quickSwitcherNoMatch: return "未匹配到实例"
        case .legendSelect: return "选择"
        case .legendBringFront: return "调出"
        case .legendDirect: return "直达/收起"
        case .legendClose: return "关闭"
        case .quickSwitcherSummary: return "运行中 · 共"
        }
    }

    private static func stringEN(_ key: L10nKey) -> String {
        switch key {
        case .appSubtitle: return "Apple Silicon Multi-Instance Studio · Real-Time Perception & Focus"
        case .collapseAll: return "Collapse All"
        case .refreshTooltip: return "Refresh instances and telemetry"
        case .taskHistoryTooltip: return "Task events and activity center"
        case .manageBackupsTooltip: return "Manage upgrade backups"
        case .checkUpdatesTooltip: return "Check for manager updates"
        case .updateSettingsTooltip: return "Manager auto-update settings"
        case .upgradeAllCount: return "Upgrade All"
        case .createInstance: return "New Instance"
        case .kernelDirectHelp: return "Kernel Direct: Darwin libproc zero-overhead metrics with microsecond efficiency"

        case .metricRunningTitle: return "Live Runtime & Task Monitor"
        case .metricRunningCount: return "Running"
        case .metricRunningSubtitleActive: return "instance(s) executing Agent tasks"
        case .metricRunningSubtitleIdle: return "All running instances are idle & ready"
        case .metricSourceTitle: return "Official Core Version"
        case .metricDiskTitle: return "Total Workspace Disk Usage"
        case .metricDiskSubtitle: return "instances isolated storage"
        case .metricCompatTitle: return "Compatibility & Upgrade"
        case .metricCompatAllLatest: return "All clone instances are up-to-date"
        case .metricCompatUpgradeable: return "clone(s) upgradeable to"

        case .filterAll: return "All"
        case .filterRunning: return "Running"
        case .filterBusyTask: return "Busy Tasks"
        case .filterWithTags: return "Tagged"
        case .viewGrid: return "Grid"
        case .viewList: return "List"
        case .densityTitle: return "View Density"
        case .densityComfortable: return "Comfortable"
        case .densityCompact: return "Compact"
        case .densityMatrix: return "Matrix"
        case .quickSwitcher: return "Quick Switch"
        case .optionsAndPrefs: return "Preferences"

        case .prefTitle: return "Studio Preferences & Window Manager"
        case .prefThemeSection: return "Appearance & Theme"
        case .themeSystem: return "System"
        case .themeLight: return "Light Crystal"
        case .themeDark: return "Dark Obsidian"
        case .prefLangSection: return "Display Language"
        case .langSystem: return "System Default"
        case .prefTilingSection: return "Window Tiling Presets"
        case .tileSplitLeftRight: return "Side-by-Side Split"
        case .tileQuadGrid: return "2×2 Quad Grid"
        case .tileCascade: return "Cascade Windows"
        case .prefHapticsTitle: return "Haptic Feedback (Trackpad)"
        case .prefHapticsSubtitle: return "Provide delicate mechanical clicks on switching, snapping, and clicking"
        case .prefHotkeysTitle: return "Global Hotkeys (⌥Space / ⌥1~9)"
        case .prefHotkeysSubtitle: return "Summon Quick Switcher anywhere or jump directly to instances 1~9"
        case .prefHotkeysGuide: return "Hotkey Quick Reference"
        case .prefSoloFocusTitle: return "Solo Focus Mode"
        case .prefSoloFocusSubtitle: return "Automatically hide other windows when bringing an instance to front"
        case .prefFloatingHUDTitle: return "Desktop Return Capsule"
        case .prefFloatingHUDSubtitle: return "Floating mini-bar at bottom right of instance to return with one click"
        case .prefEcoModeTitle: return "Smart Eco Energy Saver"
        case .prefEcoModeSubtitle: return "Throttle rendering of idle background clones to save power and thermals"
        case .prefNotificationsTitle: return "Task Notifications (Precise Focus)"
        case .prefNotificationsSubtitle: return "Notify on task completion or required input with direct jump"

        case .clickToLaunch: return "Click thumbnail to launch instance"
        case .bringToFront: return "Bring to Front"
        case .restoreWindow: return "Restore Window"
        case .hideToBackground: return "Collapse"
        case .quitInstance: return "Quit"
        case .upgradeInstance: return "Upgrade"
        case .openInstance: return "Open"
        case .switchInstance: return "Switch"
        case .verifiedBadge: return "Verified"
        case .officialMainBadge: return "Official Core Source"
        case .upgradableTo: return "Upgradable"
        case .moreOptionsTooltip: return "More instance options"

        case .stateStopped: return "Stopped"
        case .stateRunningTask: return "Task Active"
        case .stateStalled: return "Suspiciously Stalled"
        case .stateNeedsAttention: return "Action Required"
        case .stateIdle: return "Idle & Ready"
        case .stateError: return "Task Error"

        case .hudStalled: return "task(s) appear stalled"
        case .hudActive: return "instance(s) executing tasks"
        case .hudIdle: return "All running instances idle"
        case .hudBackToWall: return "Back to Studio"

        case .quickSwitcherPlaceholder: return "Search instance name, tag or workspace… (↑↓ Navigate, ⏎ Focus, ⌥1~9 Jump)"
        case .quickSwitcherNoMatch: return "No matching instances"
        case .legendSelect: return "Select"
        case .legendBringFront: return "Focus"
        case .legendDirect: return "Direct/Hide"
        case .legendClose: return "Close"
        case .quickSwitcherSummary: return "running · Total"
        }
    }

    private static func stringJA(_ key: L10nKey) -> String {
        switch key {
        case .appSubtitle: return "Apple Silicon マルチインスタンス監視・隔離スタジオ · リアルタイム認識と即時起動"
        case .collapseAll: return "全ウィンドウ格納"
        case .refreshTooltip: return "インスタンスとタスク状態を更新"
        case .taskHistoryTooltip: return "タスクイベント・実行動態センター"
        case .manageBackupsTooltip: return "更新バックアップ管理"
        case .checkUpdatesTooltip: return "マネージャー更新を確認"
        case .updateSettingsTooltip: return "自動更新設定"
        case .upgradeAllCount: return "すべて更新"
        case .createInstance: return "インスタンス作成"
        case .kernelDirectHelp: return "カーネル直接通信：macOS Darwin libproc により0子プロセスでマイクロ秒級の省電力計測"

        case .metricRunningTitle: return "稼働・タスクリアルタイム監視"
        case .metricRunningCount: return "稼働中"
        case .metricRunningSubtitleActive: return "個のインスタンスでAgentタスク実行中"
        case .metricRunningSubtitleIdle: return "稼働中のインスタンスはすべて待機中"
        case .metricSourceTitle: return "公式マスターバージョン"
        case .metricDiskTitle: return "ワークスペース総ディスク使用量"
        case .metricDiskSubtitle: return "個のインスタンスの独立ストレージ"
        case .metricCompatTitle: return "作成・更新の互換性"
        case .metricCompatAllLatest: return "すべての複製が最新バージョンです"
        case .metricCompatUpgradeable: return "個の複製を次に更新可能："

        case .filterAll: return "すべて"
        case .filterRunning: return "稼働中"
        case .filterBusyTask: return "タスク中"
        case .filterWithTags: return "タグ付き"
        case .viewGrid: return "グリッド"
        case .viewList: return "リスト"
        case .densityTitle: return "表示密度"
        case .densityComfortable: return "ゆったり"
        case .densityCompact: return "コンパクト"
        case .densityMatrix: return "マトリクス"
        case .quickSwitcher: return "高速切替"
        case .optionsAndPrefs: return "設定・機能"

        case .prefTitle: return "スタジオ環境設定とウィンドウ管理"
        case .prefThemeSection: return "外観テーマ (Theme)"
        case .themeSystem: return "システム連動"
        case .themeLight: return "ライト (白水晶)"
        case .themeDark: return "ダーク (黒曜石)"
        case .prefLangSection: return "表示言語 (Language)"
        case .langSystem: return "システム言語"
        case .prefTilingSection: return "マルチウィンドウ整列 (Tiling)"
        case .tileSplitLeftRight: return "左右2分割"
        case .tileQuadGrid: return "4分割グリッド"
        case .tileCascade: return "カスケード配置"
        case .prefHapticsTitle: return "触覚フィードバック (Trackpad)"
        case .prefHapticsSubtitle: return "切替やスナップ時に微細な触覚クリック感を提供"
        case .prefHotkeysTitle: return "グローバルショートカット (⌥Space / ⌥1~9)"
        case .prefHotkeysSubtitle: return "どこからでも高速切替パネル呼出または1~9番直達"
        case .prefHotkeysGuide: return "ショートカットガイド"
        case .prefSoloFocusTitle: return "シングルウィンドウ集中モード"
        case .prefSoloFocusSubtitle: return "インスタンス表示時に他ウィンドウを自動で隠す"
        case .prefFloatingHUDTitle: return "デスクトップ浮動カプセル"
        case .prefFloatingHUDSubtitle: return "インスタンス右下に表示される格納バーでワンクリック復帰"
        case .prefEcoModeTitle: return "スマート省電力モード"
        case .prefEcoModeSubtitle: return "待機中のバックグラウンド描画を抑制し省電力を実現"
        case .prefNotificationsTitle: return "タスク通知 (即時フォーカス)"
        case .prefNotificationsSubtitle: return "タスク完了や確認時に通知しクリックで直接呼出"

        case .clickToLaunch: return "サムネイルをクリックして起動"
        case .bringToFront: return "表示"
        case .restoreWindow: return "復元"
        case .hideToBackground: return "格納"
        case .quitInstance: return "終了"
        case .upgradeInstance: return "更新"
        case .openInstance: return "開く"
        case .switchInstance: return "切替"
        case .verifiedBadge: return "検証済み"
        case .officialMainBadge: return "公式マスター源"
        case .upgradableTo: return "更新可"
        case .moreOptionsTooltip: return "その他の操作"

        case .stateStopped: return "未起動"
        case .stateRunningTask: return "タスク実行中"
        case .stateStalled: return "応答なし検知"
        case .stateNeedsAttention: return "確認待ち"
        case .stateIdle: return "待機中"
        case .stateError: return "タスク異常"

        case .hudStalled: return "件のタスクが応答停止の疑い"
        case .hudActive: return "個のインスタンスでタスク実行中"
        case .hudIdle: return "全稼働インスタンス待機中"
        case .hudBackToWall: return "モニターに戻る"

        case .quickSwitcherPlaceholder: return "インスタンス名、タグ、ワークスペースを検索… (↑↓ 移動, ⏎ 呼出, ⌥1~9 直達)"
        case .quickSwitcherNoMatch: return "一致するインスタンスがありません"
        case .legendSelect: return "選択"
        case .legendBringFront: return "呼出"
        case .legendDirect: return "直達/格納"
        case .legendClose: return "閉じる"
        case .quickSwitcherSummary: return "稼働中 · 合計"
        }
    }

    private static func stringZHHant(_ key: L10nKey) -> String {
        switch key {
        case .appSubtitle: return "Apple Silicon 多實例監控與隔離工作台 · 實時任務感知與一鍵調出"
        case .collapseAll: return "收起全部視窗"
        case .refreshTooltip: return "刷新實例與任務狀態"
        case .taskHistoryTooltip: return "任務事件與執行動態中心"
        case .manageBackupsTooltip: return "管理升級備份"
        case .checkUpdatesTooltip: return "檢查管理器更新"
        case .updateSettingsTooltip: return "管理器自動更新設定"
        case .upgradeAllCount: return "升級全部"
        case .createInstance: return "建立實例"
        case .kernelDirectHelp: return "核心直接通訊：使用 macOS Darwin libproc 直讀進程指標，0 子進程開銷，微秒級能效"

        case .metricRunningTitle: return "實時運行與任務監控"
        case .metricRunningCount: return "運行中"
        case .metricRunningSubtitleActive: return "個實例正在執行 Agent 任務"
        case .metricRunningSubtitleIdle: return "所有已啟動實例均處於空閒就緒狀態"
        case .metricSourceTitle: return "官方主實例版本"
        case .metricDiskTitle: return "工作空間總磁碟佔用"
        case .metricDiskSubtitle: return "個實例獨立數據與存儲"
        case .metricCompatTitle: return "建立與升級適配"
        case .metricCompatAllLatest: return "全部獨立副本均為最新版本"
        case .metricCompatUpgradeable: return "個副本可升級至"

        case .filterAll: return "全部"
        case .filterRunning: return "運行中"
        case .filterBusyTask: return "執行任務中"
        case .filterWithTags: return "有備註標籤"
        case .viewGrid: return "網格"
        case .viewList: return "清單"
        case .densityTitle: return "視圖密度"
        case .densityComfortable: return "寬適視界"
        case .densityCompact: return "精緻緊湊"
        case .densityMatrix: return "超密矩陣"
        case .quickSwitcher: return "極速切換"
        case .optionsAndPrefs: return "選項與偏好"

        case .prefTitle: return "工作台偏好與視窗管理"
        case .prefThemeSection: return "外觀主題 (Theme)"
        case .themeSystem: return "跟隨系統"
        case .themeLight: return "淺色模式"
        case .themeDark: return "深色模式"
        case .prefLangSection: return "顯示語言 (Language)"
        case .langSystem: return "跟隨系統"
        case .prefTilingSection: return "多視窗桌面平鋪 (Window Tiling)"
        case .tileSplitLeftRight: return "左右雙分屏"
        case .tileQuadGrid: return "四宮格平鋪"
        case .tileCascade: return "瀑布串聯排列"
        case .prefHapticsTitle: return "觸覺力反饋 (Haptic Feedback)"
        case .prefHapticsSubtitle: return "切換實例、停靠浮窗與點擊時提供細膩物理微震"
        case .prefHotkeysTitle: return "全域快捷鍵 (⌥Space / ⌥1~9)"
        case .prefHotkeysSubtitle: return "任意桌面呼出極速切換面板或直達 1~9 號實例"
        case .prefHotkeysGuide: return "快捷鍵快速指南"
        case .prefSoloFocusTitle: return "專注單視窗模式"
        case .prefSoloFocusSubtitle: return "調出某實例時自動隱藏其他實例視窗，保持桌面整潔"
        case .prefFloatingHUDTitle: return "桌面懸浮返回膠囊"
        case .prefFloatingHUDSubtitle: return "在實例視窗右下角浮現微型返回條，點一下即可收起回監控台"
        case .prefEcoModeTitle: return "分身智能節能模式"
        case .prefEcoModeSubtitle: return "無任務運行的後台分身自動降低重繪能耗"
        case .prefNotificationsTitle: return "任務系統通知 (精準調出)"
        case .prefNotificationsSubtitle: return "實例 Agent 任務完成或需介入時彈送系統通知，點擊直達"

        case .clickToLaunch: return "點擊縮略圖啟動實例"
        case .bringToFront: return "調出實例"
        case .restoreWindow: return "恢復視窗"
        case .hideToBackground: return "收起"
        case .quitInstance: return "結束"
        case .upgradeInstance: return "升級"
        case .openInstance: return "開啟"
        case .switchInstance: return "切換"
        case .verifiedBadge: return "已驗證"
        case .officialMainBadge: return "官方主實例源"
        case .upgradableTo: return "可升"
        case .moreOptionsTooltip: return "更多實例操作"

        case .stateStopped: return "未啟動"
        case .stateRunningTask: return "任務執行中"
        case .stateStalled: return "疑似卡頓"
        case .stateNeedsAttention: return "等待確認"
        case .stateIdle: return "空閒就緒"
        case .stateError: return "任務異常"

        case .hudStalled: return "個任務疑似卡頓"
        case .hudActive: return "個實例正在跑任務"
        case .hudIdle: return "所有運行實例空閒"
        case .hudBackToWall: return "收起回監控台"

        case .quickSwitcherPlaceholder: return "搜尋實例名稱、標籤或工作區… (↑↓ 移動, ⏎ 調出, ⌥1~9 直達)"
        case .quickSwitcherNoMatch: return "未匹配到實例"
        case .legendSelect: return "選擇"
        case .legendBringFront: return "調出"
        case .legendDirect: return "直達/收起"
        case .legendClose: return "關閉"
        case .quickSwitcherSummary: return "運行中 · 共"
        }
    }
}

// MARK: - View Density (Adaptive Layout)

enum ViewDensity: String, CaseIterable, Identifiable, Hashable, Equatable {
    case comfortable = "comfortable"
    case compact = "compact"
    case matrix = "matrix"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .comfortable: return "rectangle.grid.2x2"
        case .compact: return "square.grid.3x2"
        case .matrix: return "square.grid.3x3"
        }
    }

    var minWidth: CGFloat {
        switch self {
        case .comfortable: return 270
        case .compact: return 210
        case .matrix: return 165
        }
    }

    var maxWidth: CGFloat {
        switch self {
        case .comfortable: return 360
        case .compact: return 270
        case .matrix: return 220
        }
    }

    var screenHeight: CGFloat {
        switch self {
        case .comfortable: return 158
        case .compact: return 118
        case .matrix: return 92
        }
    }

    var gridSpacing: CGFloat {
        switch self {
        case .comfortable: return 20
        case .compact: return 14
        case .matrix: return 10
        }
    }

    func localized(lang: AppLanguage) -> String {
        switch self {
        case .comfortable: return L10n.tr(.densityComfortable, lang: lang)
        case .compact: return L10n.tr(.densityCompact, lang: lang)
        case .matrix: return L10n.tr(.densityMatrix, lang: lang)
        }
    }
}

// MARK: - Window Tiling Layout Presets

enum WindowTileLayout: String, CaseIterable, Identifiable {
    case splitLeftRight = "split"
    case quadGrid = "grid"
    case cascade = "cascade"

    var id: String { rawValue }

    func localized(lang: AppLanguage) -> String {
        switch self {
        case .splitLeftRight: return L10n.tr(.tileSplitLeftRight, lang: lang)
        case .quadGrid: return L10n.tr(.tileQuadGrid, lang: lang)
        case .cascade: return L10n.tr(.tileCascade, lang: lang)
        }
    }

    var symbol: String {
        switch self {
        case .splitLeftRight: return "rectangle.split.2x1"
        case .quadGrid: return "rectangle.split.2x2"
        case .cascade: return "square.stack.3d.forward.dottedline"
        }
    }
}

final class WindowTileManager {
    static let shared = WindowTileManager()
    private init() {}

    static func applyLayout(_ layout: WindowTileLayout, instances: [ManagedInstance]) {
        shared.applyLayout(layout, instances: instances)
    }

    func applyLayout(_ layout: WindowTileLayout, instances: [ManagedInstance]) {
        let running = instances.filter { $0.running }.sorted { $0.index < $1.index }
        guard !running.isEmpty else { return }

        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }
        let visible = targetScreen.visibleFrame
        let screenX = Int(visible.origin.x)
        let screenY = Int(targetScreen.frame.height - (visible.origin.y + visible.height))
        let screenW = Int(visible.width)
        let screenH = Int(visible.height)

        switch layout {
        case .splitLeftRight:
            if running.count == 1 {
                setWindowBounds(bundleID: running[0].bundleID, x: screenX, y: screenY, w: screenW, h: screenH)
            } else {
                let halfW = screenW / 2
                setWindowBounds(bundleID: running[0].bundleID, x: screenX, y: screenY, w: halfW, h: screenH)
                let rightInstances = Array(running.dropFirst())
                let rightH = screenH / max(1, rightInstances.count)
                for (idx, item) in rightInstances.enumerated() {
                    setWindowBounds(bundleID: item.bundleID, x: screenX + halfW, y: screenY + idx * rightH, w: halfW, h: rightH)
                }
            }
        case .quadGrid:
            let cols = running.count > 2 ? 2 : max(1, running.count)
            let rows = (running.count + cols - 1) / cols
            let cellW = screenW / cols
            let cellH = screenH / max(1, rows)
            for (idx, item) in running.prefix(4).enumerated() {
                let col = idx % cols
                let row = idx / cols
                setWindowBounds(bundleID: item.bundleID, x: screenX + col * cellW, y: screenY + row * cellH, w: cellW, h: cellH)
            }
        case .cascade:
            let offset = 42
            let baseW = Int(Double(screenW) * 0.72)
            let baseH = Int(Double(screenH) * 0.75)
            for (idx, item) in running.enumerated() {
                let x = screenX + 50 + (idx * offset) % max(1, (screenW - baseW - 60))
                let y = screenY + 40 + (idx * offset) % max(1, (screenH - baseH - 60))
                setWindowBounds(bundleID: item.bundleID, x: x, y: y, w: baseW, h: baseH)
            }
        }
        HapticManager.shared.play(.alignment)
    }

    private func setWindowBounds(bundleID: String, x: Int, y: Int, w: Int, h: Int) {
        let scriptSource = """
        tell application "System Events"
            set matchingProcs to (processes whose bundle identifier is "\(bundleID)")
            if (count of matchingProcs) > 0 then
                set p to item 1 of matchingProcs
                if (count of windows of p) > 0 then
                    set position of window 1 of p to {\(x), \(y)}
                    set size of window 1 of p to {\(w), \(h)}
                end if
            end if
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            script.executeAndReturnError(&errorInfo)
        }
    }
}

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
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.04),
                                            Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.40),
                                            Color.black.opacity(0.18)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(Color.white.opacity(0.42))
                        }
                    }
                    if let tint {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(colorScheme == .dark ? 0.14 : 0.09),
                                        tint.opacity(colorScheme == .dark ? 0.04 : 0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .overlay {
                // Liquid Glass Specular Bevel & Edge Highlight
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(
                                    color: (isHighlighted ? (tint ?? accent) : Color.white)
                                        .opacity(colorScheme == .dark ? (isHighlighted ? 0.52 : 0.32) : (isHighlighted ? 0.70 : 0.50)),
                                    location: 0.0
                                ),
                                .init(
                                    color: (isHighlighted ? (tint ?? accent) : Color.white)
                                        .opacity(colorScheme == .dark ? (isHighlighted ? 0.24 : 0.12) : (isHighlighted ? 0.38 : 0.20)),
                                    location: 0.35
                                ),
                                .init(
                                    color: Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.07),
                                    location: 1.0
                                )
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isHighlighted ? 1.25 : 0.95
                    )
            }
            // Dual-Layer Ambient Occlusion & Contact Shadows
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06),
                radius: 2.5,
                x: 0,
                y: 1.2
            )
            .shadow(
                color: (isHighlighted ? (tint ?? accent) : Color.black)
                    .opacity(colorScheme == .dark ? (isHighlighted ? 0.28 : 0.16) : (isHighlighted ? 0.10 : 0.04)),
                radius: isHighlighted ? 16 : 8,
                x: 0,
                y: isHighlighted ? 6 : 3
            )
    }
}

private extension View {
    func systemSurface(radius: CGFloat, isHighlighted: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(radius: radius, isHighlighted: isHighlighted, tint: tint))
    }
}

// MARK: - Liquid Glass Dynamic FX (Metal GPU Flattened & 0Hz Standby)

struct AmbientGlowBorder: View {
    let isActive: Bool
    let color: Color
    var cornerRadius: CGFloat = 13
    var lineWidth: CGFloat = 1.5

    @State private var breathing: Bool = false

    var body: some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(breathing ? 0.65 : 0.20), lineWidth: lineWidth)
                    .blur(radius: breathing ? 4.5 : 1.5)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(breathing ? 0.35 : 0.08), lineWidth: lineWidth * 1.8)
                    .blur(radius: breathing ? 8.0 : 3.0)
            }
        }
        .drawingGroup(opaque: false)
        .allowsHitTesting(false)
        .onAppear {
            updateBreathing(isActive)
        }
        .onChange(of: isActive) { active in
            updateBreathing(active)
        }
    }

    private func updateBreathing(_ active: Bool) {
        if active {
            breathing = false
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                breathing = true
            }
        } else {
            withAnimation(.linear(duration: 0.15)) {
                breathing = false
            }
        }
    }
}

struct GlassShimmerOverlay: View {
    let isHovered: Bool
    var cornerRadius: CGFloat = 13
    @State private var shimmerOffset: CGFloat = -1.2

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                if isHovered {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.12), location: 0.45),
                            .init(color: Color.white.opacity(0.22), location: 0.50),
                            .init(color: Color.white.opacity(0.12), location: 0.55),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(25))
                    .offset(x: shimmerOffset * width)
                    .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .drawingGroup(opaque: false)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
        .onChange(of: isHovered) { hovered in
            if hovered {
                shimmerOffset = -1.2
                withAnimation(.easeOut(duration: 0.45)) {
                    shimmerOffset = 1.4
                }
            } else {
                shimmerOffset = -1.2
            }
        }
    }
}

// MARK: - Live Metric Sample & Sparkline Charts (P2)

struct MetricSample: Equatable, Hashable {
    let timestamp: Date
    let value: Double
}

struct SparklineView: View {
    let samples: [Double]
    var minVal: Double? = nil
    var maxVal: Double? = nil
    var color: Color = .purple
    var showGradient: Bool = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if samples.count >= 2 && w > 0 && h > 0 {
                let actualMin = minVal ?? (samples.min() ?? 0.0)
                let actualMax = maxVal ?? max(actualMin + 1.0, samples.max() ?? 100.0)
                let range = max(0.001, actualMax - actualMin)

                let points: [CGPoint] = samples.enumerated().map { idx, val in
                    let x = CGFloat(idx) / CGFloat(samples.count - 1) * w
                    let normalized = CGFloat(max(0.0, min(1.0, (val - actualMin) / range)))
                    let y = h - (normalized * (h - 4.0) + 2.0)
                    return CGPoint(x: x, y: y)
                }

                ZStack {
                    if showGradient {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: h))
                            path.addLine(to: points[0])
                            for pt in points.dropFirst() {
                                path.addLine(to: pt)
                            }
                            path.addLine(to: CGPoint(x: w, y: h))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.24), color.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    Path { path in
                        path.move(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                }
                .drawingGroup(opaque: false)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 6-Color Tag Classification (P3)

enum InstanceColorTag: String, CaseIterable, Identifiable, Codable {
    case blue = "blue"
    case green = "green"
    case purple = "purple"
    case orange = "orange"
    case yellow = "yellow"
    case pink = "pink"
    case none = "none"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return Color(red: 0.22, green: 0.55, blue: 0.98)
        case .green: return Color(red: 0.20, green: 0.78, blue: 0.45)
        case .purple: return Color(red: 0.62, green: 0.38, blue: 0.98)
        case .orange: return Color(red: 0.98, green: 0.52, blue: 0.20)
        case .yellow: return Color(red: 0.98, green: 0.78, blue: 0.20)
        case .pink: return Color(red: 0.98, green: 0.35, blue: 0.60)
        case .none: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .blue: return "tag.fill"
        case .green: return "bolt.fill"
        case .purple: return "sparkles"
        case .orange: return "flame.fill"
        case .yellow: return "terminal.fill"
        case .pink: return "cube.transparent.fill"
        case .none: return "tag"
        }
    }

    func localized(lang: AppLanguage) -> String {
        let eff = lang.effective
        switch (self, eff) {
        case (.blue, .en): return "Core Dev"
        case (.blue, .ja): return "コア開発"
        case (.blue, .zhHant): return "核心開發"
        case (.blue, _): return "核心开发"

        case (.green, .en): return "Production"
        case (.green, .ja): return "本番稼働"
        case (.green, .zhHant): return "生產部署"
        case (.green, _): return "生产部署"

        case (.purple, .en): return "Automated Testing"
        case (.purple, .ja): return "自動テスト"
        case (.purple, .zhHant): return "自動化測試"
        case (.purple, _): return "自动化测试"

        case (.orange, .en): return "Experiment"
        case (.orange, .ja): return "実験・検証"
        case (.orange, .zhHant): return "演算法實驗"
        case (.orange, _): return "算法实验"

        case (.yellow, .en): return "Data Crawler"
        case (.yellow, .ja): return "クローラー"
        case (.yellow, .zhHant): return "資料爬蟲"
        case (.yellow, _): return "数据爬虫"

        case (.pink, .en): return "Sandbox"
        case (.pink, .ja): return "サンドボックス"
        case (.pink, .zhHant): return "臨時沙箱"
        case (.pink, _): return "临时沙箱"

        case (.none, .en): return "No Tag"
        case (.none, .ja): return "タグなし"
        case (.none, .zhHant): return "無標籤"
        case (.none, _): return "无标签"
        }
    }
}

// MARK: - Universal Command Palette (P1)

enum MultiplexerCommand: String, CaseIterable, Identifiable {
    case launchAll = "launchAll"
    case stopAll = "stopAll"
    case restartAll = "restartAll"
    case tileSplit = "tileSplit"
    case tileGrid = "tileGrid"
    case tileCascade = "tileCascade"
    case collapseAll = "collapseAll"
    case createNew = "createNew"
    case upgradeAll = "upgradeAll"
    case switchTheme = "switchTheme"
    case switchDensity = "switchDensity"
    case switchLanguage = "switchLanguage"
    case openSettings = "openSettings"
    case cleanCaches = "cleanCaches"
    case startAllAutoPilot = "startAllAutoPilot"
    case stopAllAutoPilot = "stopAllAutoPilot"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .launchAll: return "play.fill"
        case .stopAll: return "stop.fill"
        case .restartAll: return "arrow.clockwise"
        case .tileSplit: return "rectangle.split.2x1.fill"
        case .tileGrid: return "square.grid.2x2.fill"
        case .tileCascade: return "square.stack.fill"
        case .collapseAll: return "rectangle.compress.vertical"
        case .createNew: return "plus.rectangle.on.rectangle"
        case .upgradeAll: return "arrow.triangle.2.circlepath"
        case .switchTheme: return "circle.lefthalf.filled"
        case .switchDensity: return "square.grid.3x3.fill"
        case .switchLanguage: return "globe"
        case .openSettings: return "gearshape.fill"
        case .cleanCaches: return "trash.fill"
        case .startAllAutoPilot: return "sparkles"
        case .stopAllAutoPilot: return "play.slash"
        }
    }

    var shortcutHint: String? {
        switch self {
        case .launchAll: return "⌘R"
        case .stopAll: return "⌘."
        case .tileSplit: return "⌥⌘2"
        case .tileGrid: return "⌥⌘4"
        case .tileCascade: return "⌥⌘C"
        case .collapseAll: return "⌥0"
        case .createNew: return "⌘N"
        default: return nil
        }
    }

    func title(lang: AppLanguage) -> String {
        let eff = lang.effective
        switch (self, eff) {
        case (.launchAll, .en): return "Launch All Instances"
        case (.launchAll, .ja): return "すべてのインスタンスを起動"
        case (.launchAll, .zhHant): return "啟動所有實例"
        case (.launchAll, _): return "启动所有实例"

        case (.stopAll, .en): return "Quit All Instances"
        case (.stopAll, .ja): return "すべてのインスタンスを終了"
        case (.stopAll, .zhHant): return "安全結束所有實例"
        case (.stopAll, _): return "安全退出所有实例"

        case (.restartAll, .en): return "Restart All Running Instances"
        case (.restartAll, .ja): return "実行中インスタンスを再起動"
        case (.restartAll, .zhHant): return "重啟所有運行中實例"
        case (.restartAll, _): return "重启所有运行中实例"

        case (.tileSplit, .en): return "Tile Windows: Side-by-Side (Split)"
        case (.tileSplit, .ja): return "ウィンドウ整列: 左右2分割"
        case (.tileSplit, .zhHant): return "左右雙分屏平鋪"
        case (.tileSplit, _): return "左右双分屏平铺"

        case (.tileGrid, .en): return "Tile Windows: 2×2 Quad Grid"
        case (.tileGrid, .ja): return "ウィンドウ整列: 4分割グリッド"
        case (.tileGrid, .zhHant): return "四宮格平鋪"
        case (.tileGrid, _): return "四宫格平铺"

        case (.tileCascade, .en): return "Tile Windows: Cascade"
        case (.tileCascade, .ja): return "ウィンドウ整列: カスケード"
        case (.tileCascade, .zhHant): return "瀑布級聯排布"
        case (.tileCascade, _): return "瀑布级联排布"

        case (.collapseAll, .en): return "Collapse All Windows & Open Console"
        case (.collapseAll, .ja): return "全画面を閉じて管理画面へ"
        case (.collapseAll, .zhHant): return "收起所有實例並打開監控台"
        case (.collapseAll, _): return "收起所有实例回监控台"

        case (.createNew, .en): return "Create New Instance"
        case (.createNew, .ja): return "新しいインスタンスを作成"
        case (.createNew, .zhHant): return "新建分身實例"
        case (.createNew, _): return "新建分身实例"

        case (.upgradeAll, .en): return "Upgrade & Re-patch Eligible Instances"
        case (.upgradeAll, .ja): return "対象インスタンスを一括更新"
        case (.upgradeAll, .zhHant): return "一鍵適配與升級待更新副本"
        case (.upgradeAll, _): return "一键适配与升级待更新副本"

        case (.switchTheme, .en): return "Cycle Appearance Theme"
        case (.switchTheme, .ja): return "外観テーマを切り替え"
        case (.switchTheme, .zhHant): return "切換外觀主題"
        case (.switchTheme, _): return "切换外观主题"

        case (.switchDensity, .en): return "Cycle View Density"
        case (.switchDensity, .ja): return "表示密度を切り替え"
        case (.switchDensity, .zhHant): return "切換視圖密度"
        case (.switchDensity, _): return "切换视图密度"

        case (.switchLanguage, .en): return "Cycle Display Language"
        case (.switchLanguage, .ja): return "言語を切り替え"
        case (.switchLanguage, .zhHant): return "切換顯示語言"
        case (.switchLanguage, _): return "切换界面语言"

        case (.openSettings, .en): return "Open Preferences"
        case (.openSettings, .ja): return "環境設定を開く"
        case (.openSettings, .zhHant): return "打開偏好設定"
        case (.openSettings, _): return "打开偏好设置"

        case (.cleanCaches, .en): return "Clean Orphan Processes & Cache"
        case (.cleanCaches, .ja): return "孤立プロセスとキャッシュの削除"
        case (.cleanCaches, .zhHant): return "清理孤兒進程與臨時快取"
        case (.cleanCaches, _): return "清理孤儿进程与临时磁盘"

        case (.startAllAutoPilot, .en): return "Start Auto-Pilot for All"
        case (.startAllAutoPilot, .ja): return "全インスタンスで自律運転を開始"
        case (.startAllAutoPilot, .zhHant): return "開啟所有實例自託管"
        case (.startAllAutoPilot, _): return "全部开启自托管"

        case (.stopAllAutoPilot, .en): return "Stop Auto-Pilot for All"
        case (.stopAllAutoPilot, .ja): return "全インスタンスで自律運転を停止"
        case (.stopAllAutoPilot, .zhHant): return "暫停所有實例自託管"
        case (.stopAllAutoPilot, _): return "全部暂停自托管"
        }
    }

    func subtitle(lang: AppLanguage) -> String {
        let eff = lang.effective
        switch (self, eff) {
        case (.launchAll, .en): return "Launch all stopped instances at once"
        case (.launchAll, _): return "一键同时拉起未运行的实例"
        case (.stopAll, .en): return "Safely terminate all running instances"
        case (.stopAll, _): return "优雅关闭所有处于运行状态的实例"
        case (.restartAll, .en): return "Restart all running instances"
        case (.restartAll, _): return "快速重新拉起当前正在运行的实例"
        case (.tileSplit, .en): return "Align running windows side-by-side"
        case (.tileSplit, _): return "将运行中窗口左右并列分配"
        case (.tileGrid, .en): return "Tile up to 4 windows into a 2x2 grid"
        case (.tileGrid, _): return "将运行中窗口居中平铺为田字格"
        case (.tileCascade, .en): return "Cascade windows with progressive offset"
        case (.tileCascade, _): return "阶梯式层叠排列所有运行窗口"
        case (.collapseAll, .en): return "Hide all instance windows and reveal console"
        case (.collapseAll, _): return "隐藏所有实例窗口并置顶监控控制台"
        case (.createNew, .en): return "Create an isolated Antigravity workspace clone"
        case (.createNew, _): return "创建具备独立隔离环境的全新分身"
        case (.upgradeAll, .en): return "Batch upgrade clones to match host version"
        case (.upgradeAll, _): return "无损同步主程序最新引擎与补丁"
        case (.switchTheme, .en): return "Switch between System, Light, and Dark"
        case (.switchTheme, _): return "在系统、浅色高透晶体与曜石深色间切换"
        case (.switchDensity, .en): return "Switch between Comfortable, Compact, and Matrix"
        case (.switchDensity, _): return "在舒适、紧凑与矩阵多开密度间切换"
        case (.switchLanguage, .en): return "Switch between Chinese, English, and Japanese"
        case (.switchLanguage, _): return "循环切换应用界面显示语言"
        case (.openSettings, .en): return "Configure hotkeys, haptics, and auto-sync"
        case (.openSettings, _): return "配置全局快捷键、触觉反馈及节能选项"
        case (.cleanCaches, .en): return "Reclaim disk space and kill dead processes"
        case (.cleanCaches, _): return "释放无用磁盘占用并回收僵死进程"
        case (.startAllAutoPilot, .en): return "Silently inject preset prompts when instances become idle"
        case (.startAllAutoPilot, _): return "当实例空闲时自动向后台静默注入预设文本"
        case (.stopAllAutoPilot, .en): return "Pause all auto-pilot loops immediately"
        case (.stopAllAutoPilot, _): return "暂停所有实例的自托管自动发送任务"
        }
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
        let buttonHeight: CGFloat = compact ? 29 : 33
        let radius: CGFloat = compact ? 8.5 : 9.5
        configuration.label
            .font(.system(size: compact ? 12 : 12.5, weight: variant == .primary || variant == .upgrade ? .semibold : .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, compact ? 11 : 14)
            .frame(height: buttonHeight)
            .foregroundStyle(foregroundColor)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(backgroundFill(pressed: configuration.isPressed))
                    if (variant == .primary || variant == .upgrade) && !configuration.isPressed {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(borderGradient(pressed: configuration.isPressed), lineWidth: 0.95)
            }
            .shadow(
                color: buttonShadow(pressed: configuration.isPressed),
                radius: configuration.isPressed ? 2 : (hovered ? 8 : 4),
                x: 0,
                y: configuration.isPressed ? 1 : (hovered ? 3 : 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.965 : (hovered && isEnabled ? 1.018 : 1.0))
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: hovered)
            .animation(.spring(response: 0.16, dampingFraction: 0.75), value: configuration.isPressed)
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

    private func buttonShadow(pressed: Bool) -> Color {
        guard isEnabled && !pressed else { return .clear }
        switch variant {
        case .primary:
            return accent.opacity(hovered ? 0.36 : 0.20)
        case .upgrade:
            return Color(red: 0.20, green: 0.46, blue: 0.95).opacity(hovered ? 0.40 : 0.24)
        case .danger:
            return Color.red.opacity(hovered ? 0.35 : 0.15)
        case .secondary, .ghost:
            return Color.black.opacity(hovered ? (colorScheme == .dark ? 0.22 : 0.06) : 0.0)
        }
    }

    private func backgroundFill(pressed: Bool) -> AnyShapeStyle {
        switch variant {
        case .primary:
            let base = pressed ? accent.opacity(0.85) : (hovered ? accent.opacity(0.92) : accent)
            return AnyShapeStyle(
                LinearGradient(
                    colors: [base, base.opacity(0.84)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .upgrade:
            let top = Color(red: 0.16, green: 0.52, blue: 0.96)
            let bottom = Color(red: 0.36, green: 0.34, blue: 0.92)
            return AnyShapeStyle(
                LinearGradient(
                    colors: pressed ? [top.opacity(0.85), bottom.opacity(0.85)] : (hovered ? [top.opacity(0.96), bottom] : [top, bottom]),
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

    private func borderGradient(pressed: Bool) -> AnyShapeStyle {
        switch variant {
        case .primary, .upgrade:
            return AnyShapeStyle(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(hovered ? 0.45 : 0.28), location: 0.0),
                        .init(color: Color.white.opacity(0.10), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .danger:
            return AnyShapeStyle(Color.red.opacity(hovered ? 0.65 : 0.35))
        case .secondary:
            return AnyShapeStyle(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(hovered ? 0.28 : 0.14), location: 0.0),
                        .init(color: Color.primary.opacity(hovered ? (colorScheme == .dark ? 0.18 : 0.10) : 0.05), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .ghost:
            return AnyShapeStyle(hovered ? Color.primary.opacity(0.12) : Color.clear)
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
        let radius: CGFloat = size > 30 ? 9.5 : 8.5
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: size > 30 ? 13.5 : 12.5, weight: .medium))
                    .rotationEffect(.degrees(rotation))
                    .frame(width: size, height: size, alignment: .center)
                    .foregroundStyle(hovered ? Color.primary : Color.secondary)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(Color.primary.opacity(hovered ? (colorScheme == .dark ? 0.14 : 0.08) : (colorScheme == .dark ? 0.06 : 0.035)))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(hovered ? (colorScheme == .dark ? 0.32 : 0.45) : (colorScheme == .dark ? 0.12 : 0.20)), location: 0.0),
                                        .init(color: Color.primary.opacity(hovered ? 0.14 : 0.06), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.95
                            )
                    }
                    .shadow(
                        color: Color.black.opacity(hovered ? (colorScheme == .dark ? 0.24 : 0.06) : 0.0),
                        radius: hovered ? 4 : 0,
                        y: hovered ? 1.5 : 0
                    )
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
            if active {
                Circle()
                    .fill(activeColor.opacity(0.35))
                    .frame(width: 9, height: 9)
                    .blur(radius: 1.6)
            }

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
    case stalled
    case needsAttention
    case idle
    case error

    var label: String {
        switch self {
        case .stopped: return "未启动"
        case .runningTask: return "任务执行中"
        case .stalled: return "疑似挂起"
        case .needsAttention: return "等待确认"
        case .idle: return "空闲就绪"
        case .error: return "任务异常"
        }
    }

    var color: Color {
        switch self {
        case .stopped: return .secondary
        case .runningTask: return Color(red: 0.15, green: 0.82, blue: 0.96)
        case .stalled: return Color(red: 0.98, green: 0.65, blue: 0.18)
        case .needsAttention: return .orange
        case .idle: return .green
        case .error: return .red
        }
    }

    var symbol: String {
        switch self {
        case .stopped: return "poweroff"
        case .runningTask: return "bolt.horizontal.circle.fill"
        case .stalled: return "clock.badge.exclamationmark.fill"
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
    var isStalled: Bool = false

    static let stopped = InstanceActivity()
}

// MARK: - Auto-Pilot Run State (自托管运行生命周期状态)

enum AutoPilotRunState: String, Codable, Equatable {
    case disabled = "disabled"
    case standby = "standby"
    case debouncing = "debouncing"
    case injecting = "injecting"
    case waitingRunning = "waitingRunning"
    case waitingStalled = "waitingStalled"
    case pausedNeedsAttention = "pausedNeedsAttention"
    case completed = "completed"
    case error = "error"

    func label(lang: AppLanguage) -> String {
        let eff = lang.effective
        switch (self, eff) {
        case (.disabled, .en): return "Disabled"
        case (.disabled, .ja): return "無効"
        case (.disabled, .zhHant): return "未開啟"
        case (.disabled, _): return "未开启"

        case (.standby, .en): return "Standby"
        case (.standby, .ja): return "待機中"
        case (.standby, .zhHant): return "就緒待命"
        case (.standby, _): return "就绪待命"

        case (.debouncing, .en): return "Debouncing"
        case (.debouncing, .ja): return "空腹判定中"
        case (.debouncing, .zhHant): return "防抖確認中"
        case (.debouncing, _): return "防抖确认中"

        case (.injecting, .en): return "Injecting"
        case (.injecting, .ja): return "バックグラウンド送信中"
        case (.injecting, .zhHant): return "靜默注入中"
        case (.injecting, _): return "静默注入中"

        case (.waitingRunning, .en): return "Running"
        case (.waitingRunning, .ja): return "タスク実行中"
        case (.waitingRunning, .zhHant): return "任務執行中"
        case (.waitingRunning, _): return "任务执行中"

        case (.waitingStalled, .en): return "Stalled (Waiting)"
        case (.waitingStalled, .ja): return "長時間保留中 (保護中)"
        case (.waitingStalled, .zhHant): return "掛起等待中"
        case (.waitingStalled, _): return "挂起等待中"

        case (.pausedNeedsAttention, .en): return "Needs Attention"
        case (.pausedNeedsAttention, .ja): return "ユーザー確認待ち"
        case (.pausedNeedsAttention, .zhHant): return "需要人工介入"
        case (.pausedNeedsAttention, _): return "需要人工介入"

        case (.completed, .en): return "Completed"
        case (.completed, .ja): return "完了"
        case (.completed, .zhHant): return "已達最大輪數"
        case (.completed, _): return "已达最大轮数"

        case (.error, .en): return "Error"
        case (.error, .ja): return "送信エラー"
        case (.error, .zhHant): return "注入異常"
        case (.error, _): return "注入异常"
        }
    }

    var color: Color {
        switch self {
        case .disabled: return .secondary
        case .standby: return .blue
        case .debouncing: return .purple
        case .injecting: return .cyan
        case .waitingRunning: return .green
        case .waitingStalled: return .orange
        case .pausedNeedsAttention: return .yellow
        case .completed: return .teal
        case .error: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .disabled: return "play.slash"
        case .standby: return "sparkles"
        case .debouncing: return "timer"
        case .injecting: return "paperplane.fill"
        case .waitingRunning: return "figure.run"
        case .waitingStalled: return "hourglass"
        case .pausedNeedsAttention: return "exclamationmark.triangle.fill"
        case .completed: return "checkmark.seal.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct InstanceUserMeta: Codable, Equatable, Hashable {
    var nickname: String = ""
    var tag: String = ""
    var tagColor: String = "blue"
    var colorTag: InstanceColorTag = .none
    var notes: String = ""
    var autoPilotEnabled: Bool = false
    var autoPilotPrompt: String = ""
    var autoPilotMaxRounds: Int = 0
    var autoPilotCurrentRounds: Int = 0
    var autoPilotDebounceSeconds: Double = 3.0

    var hasCustomContent: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        colorTag != .none ||
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        autoPilotEnabled ||
        !autoPilotPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var color: Color {
        if colorTag != .none {
            return colorTag.color
        }
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

    enum CodingKeys: String, CodingKey {
        case nickname, tag, tagColor, colorTag, notes
        case autoPilotEnabled
        case autoPilotPrompt
        case autoPilotMaxRounds
        case autoPilotCurrentRounds
        case autoPilotDebounceSeconds
    }

    init(
        nickname: String = "",
        tag: String = "",
        tagColor: String = "blue",
        colorTag: InstanceColorTag = .none,
        notes: String = "",
        autoPilotEnabled: Bool = false,
        autoPilotPrompt: String = "",
        autoPilotMaxRounds: Int = 0,
        autoPilotCurrentRounds: Int = 0,
        autoPilotDebounceSeconds: Double = 3.0
    ) {
        self.nickname = nickname
        self.tag = tag
        self.tagColor = tagColor
        self.colorTag = colorTag
        self.notes = notes
        self.autoPilotEnabled = autoPilotEnabled
        self.autoPilotPrompt = autoPilotPrompt
        self.autoPilotMaxRounds = autoPilotMaxRounds
        self.autoPilotCurrentRounds = autoPilotCurrentRounds
        self.autoPilotDebounceSeconds = autoPilotDebounceSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
        tagColor = try container.decodeIfPresent(String.self, forKey: .tagColor) ?? "blue"
        colorTag = try container.decodeIfPresent(InstanceColorTag.self, forKey: .colorTag) ?? .none
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        autoPilotEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoPilotEnabled) ?? false
        autoPilotPrompt = try container.decodeIfPresent(String.self, forKey: .autoPilotPrompt) ?? ""
        autoPilotMaxRounds = try container.decodeIfPresent(Int.self, forKey: .autoPilotMaxRounds) ?? 0
        autoPilotCurrentRounds = try container.decodeIfPresent(Int.self, forKey: .autoPilotCurrentRounds) ?? 0
        autoPilotDebounceSeconds = try container.decodeIfPresent(Double.self, forKey: .autoPilotDebounceSeconds) ?? 3.0
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
    case autoPilot

    var label: String {
        switch self {
        case .completed: return "已完成"
        case .needsAttention: return "等待确认"
        case .error: return "执行异常"
        case .autoPilot: return "自托管"
        }
    }

    var color: Color {
        switch self {
        case .completed: return .green
        case .needsAttention: return .orange
        case .error: return .red
        case .autoPilot: return .cyan
        }
    }

    var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .needsAttention: return "bell.badge.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .autoPilot: return "sparkles"
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
    static let openMainWindowRequested = Notification.Name("openMainWindowRequested")
    static let openCreateInstanceRequested = Notification.Name("openCreateInstanceRequested")
    static let openPreferencesRequested = Notification.Name("openPreferencesRequested")
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

// MARK: - Swift Concurrency Telemetry Actor

actor TelemetryActor {
    static let shared = TelemetryActor()

    struct ScanBatchResult {
        var activities: [String: InstanceActivity]
        var metrics: [String: InstanceResourceMetric]
        var cdpData: (thumbnails: [String: NSImage], urls: [String: String], workspaces: [String: String], sessionTitles: [String: String])
    }

    func scanTelemetryBatch(
        instances: [ManagedInstance],
        knownConvIDs: [String: String],
        runningAppPids: [String: pid_t],
        shouldCapture: Bool,
        currentMetrics: [String: InstanceResourceMetric],
        frontmostBundleID: String?,
        existingThumbnailIDs: Set<String>,
        activeTaskIDs: Set<String>,
        telemetryTick: Int
    ) async -> ScanBatchResult {
        let scanned = TelemetryScanner.scan(instances: instances, knownConvIDs: knownConvIDs)
        let metrics = shouldCapture ? TelemetryScanner.scanResourceMetrics(instances: instances, runningAppPids: runningAppPids) : currentMetrics
        let cdpData = await InstanceStore.captureCDPScreenshots(
            for: instances,
            captureThumbnails: shouldCapture,
            frontmostBundleID: frontmostBundleID,
            existingThumbnailIDs: existingThumbnailIDs,
            activeTaskIDs: activeTaskIDs,
            telemetryTick: telemetryTick
        )
        return ScanBatchResult(activities: scanned, metrics: metrics, cdpData: cdpData)
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
                let isStalled = age >= 180
                return withConv(InstanceActivity(
                    state: isStalled ? .stalled : .runningTask,
                    currentAction: isStalled ? "⚠️ 疑似挂起（\(ageLabel)无响应）：\(actionText)" : actionText,
                    workspace: workspace,
                    lastUpdatedLabel: ageLabel,
                    stepIndex: stepIndex,
                    isStalled: isStalled
                ))
            }
        }

        if isRunning && hasRunningStep && age < 600 {
            let runningDesc = !actionText.isEmpty ? actionText : (!recentToolAction.isEmpty ? "正在执行：\(recentToolAction)" : "正在后台执行任务…")
            let isStalled = age >= 180
            return withConv(InstanceActivity(
                state: isStalled ? .stalled : .runningTask,
                currentAction: isStalled ? "⚠️ 疑似挂起（\(ageLabel)无响应）：\(runningDesc)" : runningDesc,
                workspace: workspace,
                lastUpdatedLabel: ageLabel,
                stepIndex: stepIndex,
                isStalled: isStalled
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

// MARK: - Isolated Floating HUD Observable State

@MainActor final class FloatingHUDState: ObservableObject {
    @Published var activeInstanceName: String = "Antigravity"
    @Published var activeTaskCount: Int = 0
    @Published var stalledTaskCount: Int = 0
}

// MARK: - Instance Store & Window / HUD Coordinator

@MainActor final class InstanceStore: ObservableObject {
    static weak var current: InstanceStore?

    @Published var instances: [ManagedInstance] = []
    @Published var activities: [String: InstanceActivity] = [:]
    @Published var thumbnails: [String: NSImage] = [:]
    @Published var autoPilotStates: [String: AutoPilotRunState] = [:]
    @Published var autoPilotDebounceRemaining: [String: Int] = [:]
    var autoPilotDebounceTasks: [String: Task<Void, Never>] = [:]
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
    @Published var appTheme: AppTheme = {
        let raw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        return AppTheme(rawValue: raw) ?? .system
    }() {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme")
        }
    }
    @Published var appLanguage: AppLanguage = {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }() {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
        }
    }
    @Published var viewDensity: ViewDensity = {
        let raw = UserDefaults.standard.string(forKey: "viewDensity") ?? ViewDensity.comfortable.rawValue
        return ViewDensity(rawValue: raw) ?? .comfortable
    }() {
        didSet {
            UserDefaults.standard.set(viewDensity.rawValue, forKey: "viewDensity")
        }
    }
    @Published var hapticsEnabled: Bool = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    @Published var ecoModeEnabled: Bool = UserDefaults.standard.object(forKey: "ecoModeEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(ecoModeEnabled, forKey: "ecoModeEnabled") }
    }

    var effectiveLanguage: AppLanguage {
        appLanguage.effective
    }

    func tr(_ key: L10nKey) -> String {
        L10n.tr(key, lang: appLanguage)
    }
    @Published var activeInstanceName: String? = nil
    @Published var activeConversationURLs: [String: String] = [:]
    @Published var resourceMetrics: [String: InstanceResourceMetric] = [:]
    @Published var instanceMetas: [String: InstanceUserMeta] = [:]
    @Published var diskUsages: [String: InstanceDiskUsage] = [:]
    @Published var taskHistory: [TaskHistoryItem] = []
    @Published var operationProgress: Double? = nil
    @Published var operationStage: String? = nil
    @Published var activeUpgradeInstances: [ManagedInstance] = []
    var openMainWindowHandler: (() -> Void)? = nil

    // MARK: - Metric Sample History & 20-Point Buffer (P2)
    static let sampleBufferCapacity = 20
    @Published var globalCpuHistory: [MetricSample] = []
    @Published var globalRamHistory: [MetricSample] = []
    @Published var instanceMetricHistories: [String: [MetricSample]] = [:]

    func appendMetricSample(instanceID: String?, cpu: Double, ram: Double) {
        let now = Date()
        if let id = instanceID {
            var list = instanceMetricHistories[id] ?? []
            list.append(MetricSample(timestamp: now, value: cpu))
            if list.count > Self.sampleBufferCapacity {
                list.removeFirst(list.count - Self.sampleBufferCapacity)
            }
            instanceMetricHistories[id] = list
        } else {
            globalCpuHistory.append(MetricSample(timestamp: now, value: cpu))
            if globalCpuHistory.count > Self.sampleBufferCapacity {
                globalCpuHistory.removeFirst(globalCpuHistory.count - Self.sampleBufferCapacity)
            }
            globalRamHistory.append(MetricSample(timestamp: now, value: ram))
            if globalRamHistory.count > Self.sampleBufferCapacity {
                globalRamHistory.removeFirst(globalRamHistory.count - Self.sampleBufferCapacity)
            }
        }
    }

    // MARK: - Batch Multi-Selection State Machine (P3)
    @Published var isSelectionMode: Bool = false
    @Published var selectedInstanceIds: Set<String> = []

    func toggleSelection(id: String) {
        if selectedInstanceIds.contains(id) {
            selectedInstanceIds.remove(id)
            if selectedInstanceIds.isEmpty {
                isSelectionMode = false
            }
        } else {
            selectedInstanceIds.insert(id)
            isSelectionMode = true
        }
        HapticManager.shared.play(.alignment)
    }

    func selectAllInstances() {
        selectedInstanceIds = Set(instances.map(\.id))
        isSelectionMode = true
        HapticManager.shared.play(.alignment)
    }

    func clearSelection() {
        selectedInstanceIds.removeAll()
        isSelectionMode = false
        HapticManager.shared.play(.generic)
    }

    func batchOpenSelected() {
        let targets = instances.filter { selectedInstanceIds.contains($0.id) }
        for item in targets {
            open(item)
        }
        clearSelection()
        HapticManager.shared.play(.levelChange)
    }

    func batchQuitSelected() {
        let targets = instances.filter { selectedInstanceIds.contains($0.id) && $0.running }
        for item in targets {
            quit(item)
        }
        clearSelection()
        HapticManager.shared.play(.levelChange)
    }

    func batchTileSelected() {
        let targets = instances.filter { selectedInstanceIds.contains($0.id) && $0.running }
        if !targets.isEmpty {
            WindowTileManager.applyLayout(.quadGrid, instances: targets)
        }
        HapticManager.shared.play(.levelChange)
    }

    // MARK: - Window Geometry Memory (P4)
    @Published var windowGeometries: [String: [Double]] = {
        (UserDefaults.standard.dictionary(forKey: "windowGeometries") as? [String: [Double]]) ?? [:]
    }() {
        didSet {
            UserDefaults.standard.set(windowGeometries, forKey: "windowGeometries")
        }
    }

    func saveWindowGeometry(id: String, rect: CGRect) {
        windowGeometries[id] = [Double(rect.origin.x), Double(rect.origin.y), Double(rect.size.width), Double(rect.size.height)]
    }

    func loadWindowGeometry(id: String) -> CGRect? {
        guard let arr = windowGeometries[id], arr.count == 4 else { return nil }
        return CGRect(x: arr[0], y: arr[1], width: arr[2], height: arr[3])
    }

    // MARK: - Universal Command Dispatcher (P1)
    func executeCommand(_ command: MultiplexerCommand) {
        HapticManager.shared.play(.levelChange)
        switch command {
        case .launchAll:
            for item in instances where !item.running {
                open(item)
            }
        case .stopAll:
            for item in instances where item.running {
                quit(item)
            }
        case .restartAll:
            let running = instances.filter(\.running)
            for item in running {
                quit(item)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                for item in running {
                    self?.open(item)
                }
            }
        case .tileSplit:
            WindowTileManager.applyLayout(.splitLeftRight, instances: instances)
        case .tileGrid:
            WindowTileManager.applyLayout(.quadGrid, instances: instances)
        case .tileCascade:
            WindowTileManager.applyLayout(.cascade, instances: instances)
        case .collapseAll:
            collapseAllToMonitorWall()
        case .createNew:
            NotificationCenter.default.post(name: .openCreateInstanceRequested, object: nil)
        case .upgradeAll:
            upgradeAllEligible()
        case .switchTheme:
            switch appTheme {
            case .system: appTheme = .light
            case .light: appTheme = .dark
            case .dark: appTheme = .system
            }
        case .switchDensity:
            switch viewDensity {
            case .comfortable: viewDensity = .compact
            case .compact: viewDensity = .matrix
            case .matrix: viewDensity = .comfortable
            }
        case .switchLanguage:
            switch appLanguage {
            case .system: appLanguage = .zhHans
            case .zhHans: appLanguage = .en
            case .en: appLanguage = .ja
            case .ja: appLanguage = .zhHant
            case .zhHant: appLanguage = .system
            }
        case .openSettings:
            NotificationCenter.default.post(name: .openPreferencesRequested, object: nil)
        case .cleanCaches:
            cleanOrphanProcessesAndCache()
        case .startAllAutoPilot:
            startAllAutoPilot()
        case .stopAllAutoPilot:
            stopAllAutoPilot()
        }
    }

    func cleanOrphanProcessesAndCache() {
        Task { @MainActor in
            _ = try? await Task.sleep(nanoseconds: 300_000_000)
            refresh()
        }
    }

    func upgradeAllEligible() {
        let eligible = cloneInstances.filter { $0.version.compare(sourceVersion, options: .numeric) == .orderedAscending }
        if !eligible.isEmpty {
            upgrade(eligible, backup: true)
        }
    }

    private var taskStartTimes: [String: Date] = [:]
    var taskHistoryFileURL: URL {
        support.appendingPathComponent("task_history.json")
    }
    var unreadAttentionCount: Int {
        instances.filter { $0.running && activities[$0.id]?.state == .needsAttention }.count
    }

    var hudPanel: NSPanel?
    let hudState = FloatingHUDState()
    private var lastDockBadgeLabel: String? = nil
    private var lastStatusBarMenuSignature: Int = 0
    private var lastStatusButtonImage: String? = nil
    private var quickSwitcherPanel: QuickSwitcherPanel?
    private var statusItem: NSStatusItem?
    private var lastOpenWindowBundles: Set<String> = []
    private var lastFrontmostAntigravityBundle: String? = nil
    private var hasInitializedActivityBaseline = false
    private var lastNotifiedStates: [String: (state: TaskRunState, stepIndex: Int)] = [:]
    private var lastOpenTime: [String: Date] = [:]
    private var isScanningTelemetry = false
    private var telemetryTickCount: Int = 0

    func syncHUDState() {
        let name = activeInstanceName ?? "Antigravity"
        let active = activeTaskCount
        let stalled = stalledTaskCount
        if hudState.activeInstanceName != name {
            hudState.activeInstanceName = name
        }
        if hudState.activeTaskCount != active {
            hudState.activeTaskCount = active
        }
        if hudState.stalledTaskCount != stalled {
            hudState.stalledTaskCount = stalled
        }
    }

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

    // MARK: - Auto-Pilot Autonomous Dispatch Engine (自托管静默调度引擎)

    func autoPilotState(for item: ManagedInstance) -> AutoPilotRunState {
        autoPilotStates[item.id] ?? .disabled
    }

    func toggleAutoPilot(for item: ManagedInstance) {
        var m = meta(for: item)
        m.autoPilotEnabled.toggle()
        if m.autoPilotEnabled {
            if m.autoPilotPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                m.autoPilotPrompt = "继续下一步"
            }
            m.autoPilotCurrentRounds = 0
            saveInstanceMeta(for: item.id, meta: m)
            evaluateAutoPilotInitialState(for: item)
        } else {
            cancelAutoPilotDebounce(for: item.id)
            autoPilotStates[item.id] = .disabled
            saveInstanceMeta(for: item.id, meta: m)
        }
    }

    func updateAutoPilotConfig(for item: ManagedInstance, enabled: Bool, prompt: String, maxRounds: Int, debounceSeconds: Double) {
        var m = meta(for: item)
        let wasEnabled = m.autoPilotEnabled
        m.autoPilotEnabled = enabled
        m.autoPilotPrompt = prompt
        m.autoPilotMaxRounds = maxRounds
        m.autoPilotDebounceSeconds = max(1.0, debounceSeconds)
        if enabled && !wasEnabled {
            m.autoPilotCurrentRounds = 0
        }
        saveInstanceMeta(for: item.id, meta: m)
        if enabled {
            evaluateAutoPilotInitialState(for: item)
        } else {
            cancelAutoPilotDebounce(for: item.id)
            autoPilotStates[item.id] = .disabled
        }
    }

    func startAllAutoPilot() {
        for item in instances where item.running {
            var m = meta(for: item)
            m.autoPilotEnabled = true
            if m.autoPilotPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                m.autoPilotPrompt = "继续下一步"
            }
            m.autoPilotCurrentRounds = 0
            saveInstanceMeta(for: item.id, meta: m)
            evaluateAutoPilotInitialState(for: item)
        }
    }

    func stopAllAutoPilot() {
        for item in instances {
            cancelAutoPilotDebounce(for: item.id)
            autoPilotStates[item.id] = .disabled
            var m = meta(for: item)
            if m.autoPilotEnabled {
                m.autoPilotEnabled = false
                saveInstanceMeta(for: item.id, meta: m)
            }
        }
    }

    private func evaluateAutoPilotInitialState(for item: ManagedInstance) {
        let meta = meta(for: item)
        guard meta.autoPilotEnabled else {
            autoPilotStates[item.id] = .disabled
            return
        }
        guard item.running else {
            autoPilotStates[item.id] = .standby
            return
        }
        let currentActivity = activities[item.id]
        let st = currentActivity?.state ?? .stopped
        handleAutoPilotStateChange(for: item, newState: st)
    }

    func cancelAutoPilotDebounce(for itemID: String) {
        autoPilotDebounceTasks[itemID]?.cancel()
        autoPilotDebounceTasks.removeValue(forKey: itemID)
        autoPilotDebounceRemaining.removeValue(forKey: itemID)
    }

    func processAutoPilotStateChanges(newActivities: [String: InstanceActivity]) {
        for item in instances {
            if item.running {
                let act = newActivities[item.id] ?? InstanceActivity(state: .idle)
                handleAutoPilotStateChange(for: item, newState: act.state)
            } else if autoPilotStates[item.id] != .disabled {
                cancelAutoPilotDebounce(for: item.id)
                autoPilotStates[item.id] = .standby
            }
        }
    }

    func handleAutoPilotStateChange(for item: ManagedInstance, newState: TaskRunState) {
        let meta = meta(for: item)
        guard meta.autoPilotEnabled else {
            if autoPilotStates[item.id] != .disabled {
                autoPilotStates[item.id] = .disabled
                cancelAutoPilotDebounce(for: item.id)
            }
            return
        }

        switch newState {
        case .runningTask:
            cancelAutoPilotDebounce(for: item.id)
            autoPilotStates[item.id] = .waitingRunning

        case .stalled:
            // Long-running build, test execution, or deep reasoning:
            // MUST passively wait and NEVER interrupt!
            cancelAutoPilotDebounce(for: item.id)
            autoPilotStates[item.id] = .waitingStalled

        case .needsAttention:
            // Waiting for user confirmation or choices:
            // MUST safely pause and wait for user, never inject blindly!
            cancelAutoPilotDebounce(for: item.id)
            autoPilotStates[item.id] = .pausedNeedsAttention

        case .stopped, .error:
            cancelAutoPilotDebounce(for: item.id)
            autoPilotStates[item.id] = (newState == .error) ? .error : .standby

        case .idle:
            // Circuit Breaker: check max rounds limit
            if meta.autoPilotMaxRounds > 0 && meta.autoPilotCurrentRounds >= meta.autoPilotMaxRounds {
                cancelAutoPilotDebounce(for: item.id)
                autoPilotStates[item.id] = .completed
                return
            }

            guard !meta.autoPilotPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                autoPilotStates[item.id] = .standby
                return
            }

            // If already debouncing or injecting, avoid spawning duplicate tasks
            let currentState = autoPilotStates[item.id]
            if currentState == .debouncing || currentState == .injecting {
                return
            }

            // Start debounce confirmation timer
            let debounceSec = max(1.0, meta.autoPilotDebounceSeconds)
            autoPilotStates[item.id] = .debouncing
            autoPilotDebounceRemaining[item.id] = Int(debounceSec)

            cancelAutoPilotDebounce(for: item.id)

            let task = Task { [weak self] in
                guard let self = self else { return }
                var remaining = Int(debounceSec)
                while remaining > 0 {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                    remaining -= 1
                    await MainActor.run {
                        self.autoPilotDebounceRemaining[item.id] = remaining
                    }
                }

                // Debounce completed: confirm state is STILL .idle and instance is running
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    let latestState = self.activities[item.id]?.state ?? .stopped
                    guard latestState == .idle else {
                        // Task started running or state changed during debounce
                        return
                    }

                    let latestMeta = self.meta(for: item)
                    guard latestMeta.autoPilotEnabled else { return }
                    if latestMeta.autoPilotMaxRounds > 0 && latestMeta.autoPilotCurrentRounds >= latestMeta.autoPilotMaxRounds {
                        self.autoPilotStates[item.id] = .completed
                        return
                    }

                    self.autoPilotStates[item.id] = .injecting
                    self.autoPilotDebounceRemaining.removeValue(forKey: item.id)

                    Task {
                        let success = await self.injectPromptViaCDP(item: item, prompt: latestMeta.autoPilotPrompt)
                        await MainActor.run {
                            if success {
                                var updated = latestMeta
                                updated.autoPilotCurrentRounds += 1
                                self.saveInstanceMeta(for: item.id, meta: updated)

                                if updated.autoPilotMaxRounds > 0 && updated.autoPilotCurrentRounds >= updated.autoPilotMaxRounds {
                                    self.autoPilotStates[item.id] = .completed
                                } else {
                                    self.autoPilotStates[item.id] = .waitingRunning
                                }

                                self.recordTaskEvent(
                                    item: item,
                                    category: .autoPilot,
                                    action: "🤖 自托管已静默发送预设文本 (第 \(updated.autoPilotCurrentRounds) 轮): \"\(updated.autoPilotPrompt)\"",
                                    workspace: self.activities[item.id]?.workspace ?? "",
                                    stepIndex: self.activities[item.id]?.stepIndex ?? 0,
                                    duration: nil
                                )
                            } else {
                                self.autoPilotStates[item.id] = .error
                            }
                        }
                    }
                }
            }
            autoPilotDebounceTasks[item.id] = task
        }
    }

    /// Silent background prompt injection via Chromium DevTools Protocol (CDP).
    /// Dispatches preset prompt to background window without bringing it to front or stealing focus.
    func injectPromptViaCDP(item: ManagedInstance, prompt: String) async -> Bool {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let appSupportRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
        let portFile = appSupportRoot.appendingPathComponent(item.name).appendingPathComponent("DevToolsActivePort")

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
              let targets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return false
        }

        let pageTargets = targets.filter { t in
            guard (t["type"] as? String) == "page",
                  let u = t["url"] as? String else { return false }
            return u.hasPrefix("https://127.0.0.1:") || u.hasPrefix("http://127.0.0.1:")
        }

        guard let mainTarget = pageTargets.first,
              let wsString = mainTarget["webSocketDebuggerUrl"] as? String,
              let wsURL = URL(string: wsString) else {
            return false
        }

        guard let promptJSONData = try? JSONSerialization.data(withJSONObject: [prompt]),
              let promptJSONStr = String(data: promptJSONData, encoding: .utf8) else {
            return false
        }

        let jsPayload = """
        (() => {
            const promptText = (\(promptJSONStr))[0];
            const editor = document.querySelector('[data-lexical-editor="true"]')
                        || document.querySelector('[aria-label="Message input"]')
                        || document.querySelector('div[contenteditable="true"]')
                        || document.querySelector('textarea');
            if (!editor) {
                return { success: false, reason: "input_not_found" };
            }

            editor.focus();

            if (editor.tagName === 'TEXTAREA') {
                editor.value = promptText;
                editor.dispatchEvent(new Event('input', { bubbles: true }));
                editor.dispatchEvent(new Event('change', { bubbles: true }));
            } else {
                document.execCommand('selectAll', false, null);
                const inserted = document.execCommand('insertText', false, promptText);
                if (!inserted) {
                    editor.innerText = promptText;
                    editor.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: promptText }));
                }
            }

            // Click send button
            let sendBtn = document.querySelector('button[aria-label="Send message"]')
                       || document.querySelector('button[aria-label*="Send"]')
                       || document.querySelector('button.send-button');

            if (!sendBtn) {
                const btns = Array.from(document.querySelectorAll('button'));
                sendBtn = btns.find(b => {
                    const label = b.getAttribute('aria-label') || '';
                    const txt = b.innerText || '';
                    return label.toLowerCase().includes('send') || txt.toLowerCase().includes('send') || label.includes('发送');
                });
            }

            if (sendBtn && !sendBtn.disabled) {
                sendBtn.click();
                return { success: true, method: "button_click" };
            }

            // Fallback: dispatch Enter key event
            const enterEvent = new KeyboardEvent('keydown', {
                key: 'Enter',
                code: 'Enter',
                keyCode: 13,
                which: 13,
                bubbles: true,
                cancelable: true
            });
            editor.dispatchEvent(enterEvent);
            return { success: true, method: "enter_key" };
        })()
        """

        guard let evalRequestObj = try? JSONSerialization.data(withJSONObject: [
            "id": 1001,
            "method": "Runtime.evaluate",
            "params": [
                "expression": jsPayload,
                "returnByValue": true
            ]
        ]), let evalRequestStr = String(data: evalRequestObj, encoding: .utf8) else {
            return false
        }

        let task = Self.cdpSession.webSocketTask(with: wsURL)
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }

        do {
            try await task.send(.string(evalRequestStr))
            let response = try await task.receive()
            guard case .string(let text) = response,
                  let respData = text.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let res = obj["result"] as? [String: Any],
                  let resultVal = res["result"] as? [String: Any],
                  let valDict = resultVal["value"] as? [String: Any],
                  let success = valDict["success"] as? Bool else {
                return false
            }
            return success
        } catch {
            return false
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
              (activities[item.id]?.state == .runningTask || activities[item.id]?.state == .stalled),
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
        let activeTasks = Set(activities.filter { $0.value.state == .runningTask || $0.value.state == .stalled }.keys)
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let runningPids = Dictionary(uniqueKeysWithValues: snapshot.compactMap { item -> (String, pid_t)? in
            guard item.running, let app = self.runningApplication(bundleID: item.bundleID, path: item.path) else { return nil }
            return (item.id, app.processIdentifier)
        })

        telemetryTickCount += 1
        let tick = telemetryTickCount

        Task.detached(priority: .utility) {
            let result = await TelemetryActor.shared.scanTelemetryBatch(
                instances: snapshot,
                knownConvIDs: knownConvIDs,
                runningAppPids: runningPids,
                shouldCapture: shouldCapture,
                currentMetrics: currentMetrics,
                frontmostBundleID: frontmost,
                existingThumbnailIDs: existingThumbnails,
                activeTaskIDs: activeTasks,
                telemetryTick: tick
            )
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isScanningTelemetry = false
                var finalActivities = result.activities
                for (id, ws) in result.cdpData.workspaces {
                    if !ws.isEmpty, var act = finalActivities[id] {
                        act.workspace = ws
                        finalActivities[id] = act
                    }
                }
                self.processActivityChangesAndNotify(newActivities: finalActivities)
                self.processAutoPilotStateChanges(newActivities: finalActivities)
                if self.activities != finalActivities {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.activities = finalActivities
                    }
                }
                self.syncHUDState()
                let metrics = result.metrics
                if self.resourceMetrics != metrics {
                    self.resourceMetrics = metrics
                }
                if self.runningCount > 0 {
                    var totalCpu: Double = 0.0
                    var totalRamMB: Double = 0.0
                    for (id, metric) in metrics {
                        totalCpu += metric.cpuPercent
                        let ramMB = Double(metric.rssBytes) / (1024.0 * 1024.0)
                        totalRamMB += ramMB
                        self.appendMetricSample(instanceID: id, cpu: metric.cpuPercent, ram: ramMB)
                    }
                    self.appendMetricSample(instanceID: nil, cpu: totalCpu, ram: totalRamMB)
                }
                if shouldCapture && !result.cdpData.thumbnails.isEmpty {
                    for (id, image) in result.cdpData.thumbnails {
                        self.thumbnails[id] = image
                    }
                }
                if self.activeConversationURLs != result.cdpData.urls {
                    self.activeConversationURLs = result.cdpData.urls
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
    fileprivate nonisolated static func captureCDPScreenshots(
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
            req.setValue("close", forHTTPHeaderField: "Connection")
            guard let (data, _) = try? await cdpSession.data(for: req),
                  let targets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { continue }

            let pageTargets = targets.filter { t in
                guard (t["type"] as? String) == "page",
                      let u = t["url"] as? String else { return false }
                return u.hasPrefix("https://127.0.0.1:") || u.hasPrefix("http://127.0.0.1:")
            }

            if pageTargets.count > 1 {
                for duplicate in pageTargets.dropFirst() {
                    if let targetId = duplicate["id"] as? String,
                       let closeURL = URL(string: "http://127.0.0.1:\(port)/json/close/\(targetId)") {
                        var closeReq = URLRequest(url: closeURL)
                        closeReq.timeoutInterval = 0.5
                        closeReq.setValue("close", forHTTPHeaderField: "Connection")
                        _ = try? await cdpSession.data(for: closeReq)
                    }
                }
            }

            guard let mainTarget = pageTargets.first,
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
            let isRunningTask = (activities[item.id]?.state == .runningTask || activities[item.id]?.state == .stalled)
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
            return state == .runningTask || state == .stalled || state == .needsAttention
        }.count
    }

    var stalledTaskCount: Int {
        instances.filter { item in
            guard item.running, let state = activities[item.id]?.state else { return false }
            return state == .stalled
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
        HapticManager.shared.play(.alignment)
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
            _ = app.unhide()
            app.activate(options: [.activateIgnoringOtherApps])

            // 2. AppleScript to bring process frontmost and deliver reopen event to Electron
            let script = """
            tell application "System Events"
                tell (first process whose bundle identifier is "\(item.bundleID)")
                    set visible to true
                    set frontmost to true
                    repeat with w in (windows)
                        try
                            if value of attribute "AXMinimized" of w is true then
                                set value of attribute "AXMinimized" of w to false
                            end if
                        end try
                    end repeat
                end tell
            end tell
            try
                tell application id "\(item.bundleID)" to reopen
            end try
            """
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)

            // 3. Open configuration to trigger LaunchServices de-miniaturization and activate
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: item.path, configuration: config) { [weak self] _, _ in
                DispatchQueue.main.async {
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
        HapticManager.shared.play(.levelChange)
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
        HapticManager.shared.play(.generic)
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
        var shown = false
        for window in NSApp.windows where !(window is NSPanel) && !window.isSheet && window.canBecomeMain {
            if let sheet = window.attachedSheet {
                sheet.makeKeyAndOrderFront(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
            shown = true
        }
        if !shown {
            if let handler = openMainWindowHandler {
                handler()
            } else {
                NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
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
        syncHUDState()
        updateFloatingHUDVisibility()
    }

    // MARK: - Floating Return HUD Pill & Status Bar Item

    private func updateFloatingHUDVisibility() {
        guard floatingHUDEnabled, activeInstanceName != nil else {
            if hudPanel?.isVisible == true {
                hudPanel?.orderOut(nil)
            }
            return
        }
        if hudPanel == nil {
            let panelWidth: CGFloat = 392
            let panelHeight: CGFloat = 78
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.isMovableByWindowBackground = false
            panel.acceptsMouseMovedEvents = true

            let savedX = UserDefaults.standard.object(forKey: "floatingHUD_x") as? Double
            let savedY = UserDefaults.standard.object(forKey: "floatingHUD_y") as? Double
            var restored = false
            if let x = savedX, let y = savedY {
                let targetPoint = NSPoint(x: x, y: y)
                let targetRect = NSRect(origin: targetPoint, size: CGSize(width: panelWidth, height: panelHeight))
                if let targetScreen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(targetRect) }) {
                    let screen = targetScreen.visibleFrame
                    let minX = screen.minX - 18
                    let maxX = max(minX, screen.maxX - panelWidth + 18)
                    let minY = screen.minY - 18
                    let maxY = max(minY, screen.maxY - panelHeight + 18)
                    let clampedX = min(max(x, minX), maxX)
                    let clampedY = min(max(y, minY), maxY)
                    panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
                    restored = true
                }
            }
            if !restored, let screen = NSScreen.main?.visibleFrame {
                // Default position: Top-Right of screen below menu bar, avoiding bottom chat/prompt box on laptop screens
                panel.setFrameOrigin(NSPoint(x: max(screen.minX, screen.maxX - panelWidth - 10), y: max(screen.minY, screen.maxY - panelHeight - 10)))
            }

            panel.contentView = DraggableHostingView(rootView: FloatingMonitorHUDView(hudState: hudState, store: self))
            hudPanel = panel
        }
        if hudPanel?.isVisible != true {
            hudPanel?.orderFrontRegardless()
        }
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
            if (newAct.state == .runningTask || newAct.state == .stalled) && prevState != .runningTask && prevState != .stalled {
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
            } else if newAct.state == .stalled && prevState != .stalled {
                lastNotifiedStates[item.id] = (state: newAct.state, stepIndex: newAct.stepIndex)
                let duration = taskStartTimes[item.id].map { Date().timeIntervalSince($0) }
                recordTaskEvent(
                    item: item,
                    category: .needsAttention,
                    action: newAct.currentAction.isEmpty ? "Agent 任务执行疑似挂起卡顿（超过3分钟无响应）" : newAct.currentAction,
                    workspace: newAct.workspace,
                    stepIndex: newAct.stepIndex,
                    duration: duration
                )
                if !isUserCurrentlyFocusingInstance {
                    sendSystemNotification(
                        identifier: "task-stalled-\(item.id)-\(newAct.stepIndex)",
                        title: "\(isMainPrefix)\(displayName) · 任务疑似挂起",
                        subtitle: newAct.workspace.isEmpty ? "已持续超过 3 分钟无响应" : "工作区: \(newAct.workspace) · 超 3 分钟无响应",
                        body: newAct.currentAction.isEmpty ? "终端进程或提示可能处于等待中，点击立即查看" : newAct.currentAction,
                        bundleID: item.bundleID
                    )
                }
            } else if (prevState == .runningTask || prevState == .stalled) && newAct.state == .idle {
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
            if lastDockBadgeLabel != nil {
                NSApp.dockTile.badgeLabel = nil
                NSApp.dockTile.display()
                lastDockBadgeLabel = nil
            }
            return
        }

        let attentionCount = instances.filter { item in
            item.running && activities[item.id]?.state == .needsAttention
        }.count

        let stalledCount = instances.filter { item in
            item.running && activities[item.id]?.state == .stalled
        }.count

        let runningTasks = instances.filter { item in
            item.running && activities[item.id]?.state == .runningTask
        }.count

        let targetBadge: String? = {
            if attentionCount > 0 {
                return attentionCount > 1 ? "!\(attentionCount)" : "!"
            } else if stalledCount > 0 {
                return stalledCount > 1 ? "⏳\(stalledCount)" : "⏳"
            } else if runningTasks > 0 {
                return "\(runningTasks)"
            } else {
                return nil
            }
        }()

        if targetBadge != lastDockBadgeLabel {
            lastDockBadgeLabel = targetBadge
            NSApp.dockTile.badgeLabel = targetBadge
            NSApp.dockTile.display()
        }
    }

    private func setupStatusBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Antigravity 监控台")
            button.imagePosition = .imageLeading
            button.target = StatusBarTarget.shared
            button.action = #selector(StatusBarTarget.handleStatusBarButtonClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        updateStatusBarMenu()
    }

    func updateStatusBarMenu() {
        guard let statusItem else { return }

        let attentionCount = instances.filter { item in
            item.running && activities[item.id]?.state == .needsAttention
        }.count

        let stalledCount = instances.filter { item in
            item.running && activities[item.id]?.state == .stalled
        }.count

        let runningTasks = instances.filter { item in
            item.running && activities[item.id]?.state == .runningTask
        }.count

        if let button = statusItem.button {
            let (targetImageName, targetTitle): (String, String) = {
                if attentionCount > 0 {
                    return ("bell.badge.fill", " \(attentionCount)待确认")
                } else if stalledCount > 0 {
                    return ("clock.badge.exclamationmark.fill", " \(stalledCount)挂起")
                } else if runningTasks > 0 {
                    return ("bolt.fill", " \(runningTasks)")
                } else {
                    return ("square.grid.2x2.fill", "")
                }
            }()
            if lastStatusButtonImage != targetImageName {
                button.image = NSImage(systemSymbolName: targetImageName, accessibilityDescription: "Antigravity 监控台")
                lastStatusButtonImage = targetImageName
            }
            if button.title != targetTitle {
                button.title = targetTitle
            }
        }

        var hasher = Hasher()
        hasher.combine(instances.count)
        for item in instances {
            hasher.combine(item.id)
            hasher.combine(item.running)
            hasher.combine(item.name)
            if let meta = instanceMetas[item.id] {
                hasher.combine(meta.nickname)
            }
            if let act = activities[item.id] {
                hasher.combine(act.state.label)
                hasher.combine(act.currentAction)
                hasher.combine(act.workspace)
            }
        }
        hasher.combine(taskHistory.count)
        for item in taskHistory.prefix(3) {
            hasher.combine(item.id)
            hasher.combine(item.actionSummary)
            hasher.combine(item.category.rawValue)
        }
        let currentSignature = hasher.finalize()

        if currentSignature == lastStatusBarMenuSignature && statusItem.menu != nil {
            return
        }
        lastStatusBarMenuSignature = currentSignature

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
            return act.state == .runningTask || act.state == .stalled || act.state == .needsAttention
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
                let icon = act.state == .needsAttention ? "🔔" : (act.state == .stalled ? "⚠️" : "⚡")
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
            let statePrefix = !item.running ? "⏹" : (act.state == .runningTask ? "⚡" : (act.state == .stalled ? "⚠️" : (act.state == .needsAttention ? "🔔" : "🟢")))
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

        StatusBarTarget.shared.cachedMenu = menu
        statusItem.menu = nil
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

    func upgrade(_ selected: [ManagedInstance], backup: Bool = true) {
        guard !busy && !selected.isEmpty && selected.allSatisfy({ pendingUpgrades.contains($0) }) else { return }
        guard let script = Bundle.main.url(forResource: "upgrade_all", withExtension: "py") else {
            error = "应用缺少升级组件。"; return
        }
        activeUpgradeInstances = selected
        var args = ["--source", "/Applications/Antigravity.app",
                    "--only-indices", selected.map { String($0.index) }.joined(separator: ",")]
        if !backup {
            args.append("--skip-backup")
        }
        runScript(script, arguments: args,
                  starting: "正在检查本机主实例和选定副本；\(backup ? "将执行安全备份" : "⚡️ 已跳过备份直接替换")…\n")
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
            operationProgress = nil
            operationStage = nil
            activeUpgradeInstances = []
        }
    }

    private func runScript(_ script: URL, arguments: [String], starting: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            busy = true
            error = nil
            output = starting
            operationProgress = 0.05
            operationStage = "正在准备操作环境…"
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
            Task { @MainActor in self?.processStreamChunk(message) }
        }
        process.terminationHandler = { [weak self] completed in
            pipe.fileHandleForReading.readabilityHandler = nil
            let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor in
                if let text = String(data: remainder, encoding: .utf8) { self?.processStreamChunk(text) }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    self?.busy = false
                    if completed.terminationStatus == 0 {
                        self?.operationProgress = 1.0
                        self?.operationStage = "操作已全部顺利完成"
                    } else {
                        self?.error = "操作未完成，请查看下方记录。"
                    }
                }
                self?.refresh()
            }
        }
        do {
            try process.run()
            try? pipe.fileHandleForWriting.close()
        } catch {
            withAnimation {
                busy = false
                operationProgress = nil
                operationStage = nil
            }
            self.error = "无法启动组件：\(error.localizedDescription)"
        }
    }

    private func processStreamChunk(_ chunk: String) {
        var cleanChunk = ""
        let lines = chunk.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            let isLast = index == lines.count - 1
            if line.hasPrefix("[PROGRESS:") {
                if let closeBracket = line.firstIndex(of: "]") {
                    let numStart = line.index(line.startIndex, offsetBy: 10)
                    let pctStr = line[numStart..<closeBracket]
                    let msg = line[line.index(after: closeBracket)...].trimmingCharacters(in: .whitespaces)
                    if let pct = Double(pctStr) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            self.operationProgress = min(1.0, max(0.0, pct / 100.0))
                            if !msg.isEmpty {
                                self.operationStage = msg
                            }
                        }
                    }
                }
            } else {
                cleanChunk += line
                if !isLast {
                    cleanChunk += "\n"
                }
            }
        }
        if !cleanChunk.isEmpty {
            self.output += cleanChunk
        }
    }
}

@MainActor private final class StatusBarTarget: NSObject {
    static let shared = StatusBarTarget()
    weak var store: InstanceStore?
    var statusPopover: NSPopover?
    var cachedMenu: NSMenu?

    @objc func handleStatusBarButtonClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false) {
            if let menu = cachedMenu {
                sender.menu = menu
                sender.performClick(nil)
                sender.menu = nil
            }
        } else {
            toggleStatusPopover(sender)
        }
    }

    @objc func toggleStatusPopover(_ sender: NSStatusBarButton) {
        guard let store else { return }
        if let popover = statusPopover, popover.isShown {
            popover.performClose(nil)
            return
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 260)
        popover.contentViewController = NSHostingController(
            rootView: StatusPopoverView(
                store: store,
                onOpenMainWindow: { [weak popover] in
                    popover?.performClose(nil)
                    NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
                },
                onOpenQuickSwitcher: { [weak popover, weak store] in
                    popover?.performClose(nil)
                    store?.toggleQuickSwitcher()
                }
            )
        )
        self.statusPopover = popover
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

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
    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only accept mouse events within the capsule boundary, passing through clicks in the transparent padding
        let capsuleRect = bounds.insetBy(dx: 14, dy: 14)
        if !capsuleRect.contains(point) {
            return nil
        }
        return super.hitTest(point)
    }
}

final class NativeDragAreaView: NSView {
    var onDragEnded: ((NSPoint) -> Void)?

    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.cursorUpdate, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.openHand.set()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else {
            super.mouseDown(with: event)
            return
        }
        NSCursor.closedHand.push()
        window.performDrag(with: event)
        NSCursor.pop()

        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            let f = window.frame
            let minX = visible.minX - 18
            let maxX = max(minX, visible.maxX - f.width + 18)
            let minY = visible.minY - 18
            let maxY = max(minY, visible.maxY - f.height + 18)
            let clampedOrigin = NSPoint(
                x: min(max(f.origin.x, minX), maxX),
                y: min(max(f.origin.y, minY), maxY)
            )
            if clampedOrigin != f.origin {
                window.setFrameOrigin(clampedOrigin)
            }
            onDragEnded?(clampedOrigin)
        } else {
            onDragEnded?(window.frame.origin)
        }
    }
}

struct NativeWindowDragViewRepresentable: NSViewRepresentable {
    var onDragEnded: ((NSPoint) -> Void)?

    func makeNSView(context: Context) -> NativeDragAreaView {
        let v = NativeDragAreaView()
        v.onDragEnded = onDragEnded
        return v
    }

    func updateNSView(_ nsView: NativeDragAreaView, context: Context) {
        nsView.onDragEnded = onDragEnded
    }
}

// MARK: - Floating Return to Monitor HUD View

private struct FloatingMonitorHUDView: View {
    @ObservedObject var hudState: FloatingHUDState
    let store: InstanceStore
    @State private var hovered = false

    var body: some View {
        ZStack {
            // Native Window Drag Area (Hardware-accelerated WindowServer dragging at 120 FPS / display refresh rate)
            NativeWindowDragViewRepresentable { newOrigin in
                store.saveHUDPosition(origin: newOrigin)
            }
            .clipShape(Capsule())

            HStack(alignment: .center, spacing: 8) {
                // Draggable Area (Grip Icon + Pulsing Dot + Instance Info)
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.40))
                        .frame(width: 12)
                        .help("按住可随意拖动浮窗到屏幕任意位置")

                    let hudDotColor: Color = {
                        if hudState.stalledTaskCount > 0 {
                            return Color(red: 0.98, green: 0.65, blue: 0.18)
                        } else if hudState.activeTaskCount > 0 {
                            return Color(red: 0.15, green: 0.82, blue: 0.96)
                        } else {
                            return .green
                        }
                    }()
                    let hudSubtitle: String = {
                        if hudState.stalledTaskCount > 0 {
                            return "⚠️ \(hudState.stalledTaskCount) " + store.tr(.hudStalled)
                        } else if hudState.activeTaskCount > 0 {
                            return "\(hudState.activeTaskCount) " + store.tr(.hudActive)
                        } else {
                            return store.tr(.hudIdle)
                        }
                    }()

                    PulsingStatusDot(
                        active: true,
                        activeColor: hudDotColor,
                        pulse: hudState.activeTaskCount > 0
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(hudState.activeInstanceName)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(hudSubtitle)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(hudState.stalledTaskCount > 0 ? Color(red: 0.98, green: 0.75, blue: 0.35) : .white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .allowsHitTesting(false)

                Spacer(minLength: 4)
                    .allowsHitTesting(false)

                Button {
                    store.toggleQuickSwitcher()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                        .frame(width: 24, height: 24)
                        .background {
                            Circle().fill(Color.white.opacity(0.12))
                        }
                        .overlay {
                            Circle().strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.40), location: 0.0),
                                        .init(color: Color.white.opacity(0.08), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.95
                            )
                        }
                }
                .buttonStyle(.plain)
                .help("快速切换到其他 Antigravity 实例 (⌥Space)")

                Button {
                    store.collapseAllToMonitorWall()
                } label: {
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(store.tr(.hudCollapse))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background {
                        Capsule().fill(accent)
                    }
                    .overlay {
                        Capsule().strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.45), location: 0.0),
                                    .init(color: Color.white.opacity(0.10), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.95
                        )
                    }
                    .shadow(color: accent.opacity(0.35), radius: 4, y: 1.5)
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
            .padding(.leading, 12)
            .padding(.trailing, hovered ? 8 : 12)
        }
        .frame(width: 356, height: 42)
        .background {
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.14, green: 0.16, blue: 0.24).opacity(0.96), location: 0.0),
                                .init(color: Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.98), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(hovered ? 0.50 : 0.32), location: 0.0),
                            .init(color: accent.opacity(hovered ? 0.55 : 0.22), location: 0.45),
                            .init(color: Color.white.opacity(0.08), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.15
                )
                .allowsHitTesting(false)
        }
        .shadow(
            color: Color.black.opacity(hovered ? 0.50 : 0.32),
            radius: hovered ? 12 : 7,
            x: 0,
            y: hovered ? 5 : 2.5
        )
        .shadow(
            color: accent.opacity(hovered ? 0.25 : 0.10),
            radius: hovered ? 16 : 8,
            x: 0,
            y: hovered ? 4 : 2
        )
        .scaleEffect(hovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: hovered)
        .padding(18)
        .preferredColorScheme(store.appTheme.colorScheme)
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

    private var isCommandMode: Bool {
        searchText.hasPrefix(">")
    }

    private var filteredCommands: [MultiplexerCommand] {
        let q = searchText.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return MultiplexerCommand.allCases }
        return MultiplexerCommand.allCases.filter { cmd in
            cmd.rawValue.lowercased().contains(q) ||
            cmd.title(lang: store.appLanguage).lowercased().contains(q) ||
            cmd.subtitle(lang: store.appLanguage).lowercased().contains(q)
        }
    }

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
                Image(systemName: isCommandMode ? "terminal.fill" : "command.square.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isCommandMode ? Color.purple : Color(red: 0.52, green: 0.32, blue: 0.98))

                TextField(isCommandMode ? "输入指令名称直接执行…" : store.tr(.qsSearchPlaceholder), text: $searchText)
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
                    Text(isCommandMode ? "指令模式" : "输入 > 指令")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(isCommandMode ? Color.purple : .secondary)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(Capsule().fill(isCommandMode ? Color.purple.opacity(0.15) : Color.primary.opacity(0.08)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .opacity(0.6)

            // 2. List (Commands or Instances)
            if isCommandMode {
                if filteredCommands.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text("未找到匹配的系统命令")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 6) {
                                ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, cmd in
                                    CommandPaletteRow(
                                        command: cmd,
                                        isSelected: index == selectedIndex,
                                        lang: store.appLanguage,
                                        onSelect: {
                                            doDismiss()
                                            store.executeCommand(cmd)
                                        }
                                    )
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
            } else if filteredInstances.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text(store.tr(.qsNoMatch))
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
                                        HapticManager.shared.play(.generic)
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
                    legendItem(key: "↑ ↓", label: store.tr(.qsSelect))
                    legendItem(key: "⏎", label: isCommandMode ? "执行命令" : store.tr(.qsActivate))
                    if isCommandMode {
                        legendItem(key: "Esc", label: store.tr(.qsClose))
                    } else {
                        legendItem(key: "⌥ 1~9", label: store.tr(.qsDirect))
                        legendItem(key: "Esc", label: store.tr(.qsClose))
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(store.runningCount > 0 ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(store.effectiveLanguage == .en
                        ? "\(store.runningCount) running · \(store.instances.count) instances total"
                        : "\(store.runningCount) 运行中 · 共 \(store.instances.count) 个实例")
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
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    Color.clear,
                                    Color.black.opacity(0.18)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.38 : 0.55), location: 0.0),
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.14 : 0.22), location: 0.35),
                            .init(color: Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.08), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.15
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 4, x: 0, y: 2)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.22), radius: 28, y: 14)
        .preferredColorScheme(store.appTheme.colorScheme)
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
            let maxCount = isCommandMode ? filteredCommands.count : filteredInstances.count
            if event.keyCode == 53 { // Esc
                doDismiss()
                return nil
            } else if event.keyCode == 126 { // Up
                if selectedIndex > 0 {
                    selectedIndex -= 1
                    HapticManager.shared.play(.alignment)
                }
                return nil
            } else if event.keyCode == 125 { // Down
                if selectedIndex < maxCount - 1 {
                    selectedIndex += 1
                    HapticManager.shared.play(.alignment)
                }
                return nil
            } else if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                if isCommandMode {
                    if !filteredCommands.isEmpty {
                        let safeIndex = min(max(0, selectedIndex), filteredCommands.count - 1)
                        let cmd = filteredCommands[safeIndex]
                        doDismiss()
                        store?.executeCommand(cmd)
                    }
                } else {
                    if !filteredInstances.isEmpty {
                        let safeIndex = min(max(0, selectedIndex), filteredInstances.count - 1)
                        let target = filteredInstances[safeIndex]
                        HapticManager.shared.play(.generic)
                        doDismiss()
                        store?.open(target)
                    }
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
                                pulse: activity.state == .runningTask || activity.state == .stalled || activity.state == .needsAttention
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
                        .fill(
                            isMain
                                ? Color(red: 0.52, green: 0.32, blue: 0.98).opacity(colorScheme == .dark ? 0.28 : 0.16)
                                : Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14)
                        )
                } else if hovered {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.045))
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(colorScheme == .dark ? 0.55 : 0.75), location: 0.0),
                                    .init(color: (isMain ? Color(red: 0.52, green: 0.32, blue: 0.98) : Color.accentColor).opacity(0.65), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.25
                        )
                }
            }
            .shadow(
                color: isSelected
                    ? (isMain ? Color(red: 0.52, green: 0.32, blue: 0.98) : Color.accentColor).opacity(colorScheme == .dark ? 0.25 : 0.10)
                    : .clear,
                radius: 5,
                y: 1.5
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(isSelected ? 1.008 : (hovered ? 1.004 : 1.0))
            .animation(.spring(response: 0.20, dampingFraction: 0.82), value: isSelected)
            .animation(.spring(response: 0.18, dampingFraction: 0.80), value: hovered)
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

// MARK: - Command Palette Row (P1)

private struct CommandPaletteRow: View {
    let command: MultiplexerCommand
    let isSelected: Bool
    let lang: AppLanguage
    let onSelect: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color(red: 0.52, green: 0.32, blue: 0.98) : Color.primary.opacity(0.06))
                    Image(systemName: command.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title(lang: lang))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    Text(command.subtitle(lang: lang))
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let shortcut = command.shortcutHint {
                    Text(shortcut)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
                        .padding(.horizontal, 6)
                        .frame(height: 19)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.06))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(red: 0.52, green: 0.32, blue: 0.98))
                } else if hovered {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.045))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Floating Batch Action Bar (P3)

struct BatchActionBarView: View {
    @ObservedObject var store: InstanceStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Text(store.effectiveLanguage == .en
                    ? "Selected \(store.selectedInstanceIds.count) of \(store.instances.count)"
                    : "已选择 \(store.selectedInstanceIds.count) / \(store.instances.count) 个实例")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            }
            .padding(.leading, 6)

            Divider()
                .frame(height: 16)
                .opacity(0.5)

            Button {
                store.batchOpenSelected()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                    Text(store.effectiveLanguage == .en ? "Launch Selected" : "批量启动")
                }
            }
            .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))

            Button {
                store.batchQuitSelected()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11))
                    Text(store.effectiveLanguage == .en ? "Quit Selected" : "批量退出")
                }
            }
            .buttonStyle(ModernButtonStyle(variant: .danger, compact: true))

            Button {
                store.batchTileSelected()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11))
                    Text(store.effectiveLanguage == .en ? "Tile 2×2" : "四宫格平铺")
                }
            }
            .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))

            Button {
                store.selectAllInstances()
            } label: {
                Text(store.effectiveLanguage == .en ? "Select All" : "全选")
            }
            .buttonStyle(ModernButtonStyle(variant: .ghost, compact: true))

            Button {
                store.clearSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.primary.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.0
                )
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 12, y: 6)
    }
}

// MARK: - Menu Bar Liquid Glass Popover (P4)

struct StatusPopoverView: View {
    @ObservedObject var store: InstanceStore
    let onOpenMainWindow: () -> Void
    let onOpenQuickSwitcher: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            // Header summary
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Aether Multiplexer")
                        .font(.system(size: 12.5, weight: .bold))
                    Text(store.effectiveLanguage == .en
                        ? "\(store.runningCount) running · \(store.instances.count) total"
                        : "\(store.runningCount) 个实例运行中 · 共 \(store.instances.count) 个")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onOpenQuickSwitcher()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "command.square.fill")
                            .font(.system(size: 10))
                        Text("⌥Space")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            // Global Sparkline Metric Summary
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("CPU")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", store.globalCpuHistory.last?.value ?? 0.0))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    SparklineView(
                        samples: store.globalCpuHistory.map(\.value),
                        minVal: 0,
                        maxVal: 100,
                        color: Color.purple
                    )
                    .frame(height: 28)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.04)))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("RAM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0fMB", store.globalRamHistory.last?.value ?? 0.0))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    SparklineView(
                        samples: store.globalRamHistory.map(\.value),
                        minVal: 0,
                        maxVal: max(1024, (store.globalRamHistory.map(\.value).max() ?? 1024) * 1.2),
                        color: Color.blue
                    )
                    .frame(height: 28)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.04)))
            }

            // Running instances mini list
            let running = store.instances.filter(\.running)
            if !running.isEmpty {
                VStack(spacing: 6) {
                    ForEach(running.prefix(4)) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)

                            let meta = store.meta(for: item)
                            Text(meta.nickname.isEmpty ? item.name : meta.nickname)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            Spacer()

                            let metric = store.metric(for: item)
                            Text(String(format: "%.1f%%", metric.cpuPercent))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Button {
                                store.open(item)
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.03)))
                    }
                }
            }

            // Bottom Actions
            HStack(spacing: 6) {
                Button {
                    WindowTileManager.applyLayout(.splitLeftRight, instances: store.instances)
                } label: {
                    Label("双分屏", systemImage: "rectangle.split.2x1.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))

                Button {
                    WindowTileManager.applyLayout(.quadGrid, instances: store.instances)
                } label: {
                    Label("四宫格", systemImage: "square.grid.2x2.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))

                Spacer()

                Button {
                    onOpenMainWindow()
                } label: {
                    Label("监控主台", systemImage: "macwindow")
                        .font(.system(size: 11))
                }
                .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))
            }
        }
        .padding(14)
        .frame(width: 320)
        .preferredColorScheme(store.appTheme.colorScheme)
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
    var density: ViewDensity = .comfortable
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
    var editAutoPilot: (() -> Void)? = nil
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
        case .stalled: return Color(red: 0.98, green: 0.65, blue: 0.18)
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
                        .frame(height: density.screenHeight)
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
                                pulse: item.running && (activity.state == .runningTask || activity.state == .stalled || activity.state == .needsAttention)
                            )
                            Text(item.running ? (item.isHidden ? "\(activity.state.label) · 后台实时" : activity.state.label) : "未启动")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background {
                            Capsule().fill(Color.black.opacity(0.60))
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.42), location: 0.0),
                                            .init(color: activity.state.color.opacity(0.40), location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.95
                                )
                        }

                        if hasPendingUpgrade {
                            Text("可升 v\(sourceVersion)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6.5)
                                .frame(height: 20)
                                .background(Capsule().fill(Color.black.opacity(0.65)))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: Color.white.opacity(0.45), location: 0.0),
                                                    .init(color: Color.orange.opacity(0.45), location: 1.0)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.95
                                        )
                                }
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
                            .background(Capsule().fill(Color.black.opacity(0.60)))
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color.white.opacity(0.45), location: 0.0),
                                                .init(color: Color.cyan.opacity(0.45), location: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.95
                                    )
                            }
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
                    .background {
                        ZStack(alignment: .top) {
                            Color.black.opacity(0.70)
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 1)
                        }
                    }
                }

                // Center Play / Switch Action Overlay
                centerPlayOverlay
            }
            .frame(height: density.screenHeight)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                AmbientGlowBorder(
                    isActive: item.running && (activity.state == .runningTask || activity.state == .stalled || activity.state == .needsAttention),
                    color: activity.state == .stalled ? Color(red: 0.98, green: 0.69, blue: 0.20) : Color(red: 0.15, green: 0.82, blue: 0.96),
                    cornerRadius: 13,
                    lineWidth: 1.8
                )
            }
            .overlay {
                GlassShimmerOverlay(isHovered: hovered, cornerRadius: 13)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(
                                    color: (item.isOriginal ? Color(red: 0.75, green: 0.55, blue: 1.0) : (item.running ? borderTint : Color.white))
                                        .opacity(hovered ? 0.70 : (item.running ? 0.42 : 0.20)),
                                    location: 0.0
                                ),
                                .init(
                                    color: (item.isOriginal ? Color(red: 0.52, green: 0.32, blue: 0.98) : borderTint)
                                        .opacity(hovered ? 0.45 : (item.running ? 0.28 : 0.08)),
                                    location: 0.40
                                ),
                                .init(
                                    color: Color.primary.opacity(hovered ? 0.16 : 0.05),
                                    location: 1.0
                                )
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: (item.isOriginal || hovered || activity.state == .runningTask || activity.state == .stalled || activity.state == .needsAttention) ? 1.5 : 1
                    )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06),
                radius: 2.5,
                x: 0,
                y: 1.2
            )
            .shadow(
                color: (item.isOriginal ? Color(red: 0.52, green: 0.32, blue: 0.98) : borderTint)
                    .opacity(item.running || hovered ? (colorScheme == .dark ? 0.28 : 0.14) : 0.0),
                radius: hovered ? 16 : 8,
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

                Spacer(minLength: 4)

                if let store = InstanceStore.current {
                    AutoPilotPillView(store: store, item: item, onConfigure: editAutoPilot)
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
                        ? Color(red: 0.52, green: 0.28, blue: 0.98).opacity(colorScheme == .dark ? 0.14 : 0.08)
                        : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(colorScheme == .dark ? 0.25 : 0.40), location: 0.0),
                                .init(color: (item.isOriginal ? Color(red: 0.52, green: 0.32, blue: 0.98) : Color.primary).opacity(hovered ? 0.24 : 0.08), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.95
                    )
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
                        Text(activity.state == .runningTask ? "AGENT EXECUTING TASK" : (activity.state == .stalled ? "TASK SUSPECTED STALLED (>3M)" : (activity.state == .needsAttention ? "WAITING FOR USER INPUT" : "AGENT READY")))
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(activity.state.color)
                        Text(activity.currentAction)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                    }
                }

                if activity.state == .runningTask || activity.state == .stalled {
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

            tileMenuItem(
                title: meta.autoPilotEnabled ? "🤖 配置/关闭自托管…" : "🤖 开启自托管…",
                symbol: "sparkles"
            ) {
                showMorePopover = false
                editAutoPilot?()
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
        lhs.density == rhs.density &&
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
    var editAutoPilot: (() -> Void)? = nil
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
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(item.isOriginal ? 0.65 : (item.running ? 0.48 : 0.28)), location: 0.0),
                                        .init(color: (item.isOriginal ? Color.white : (item.running ? activity.state.color : accent)).opacity(0.12), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.15
                            )
                    }
                    .shadow(
                        color: (item.isOriginal ? Color(red: 0.52, green: 0.28, blue: 0.98) : (item.running ? activity.state.color : accent))
                            .opacity(colorScheme == .dark ? (item.running ? 0.32 : 0.12) : 0.15),
                        radius: item.running || hovered ? 8 : 3.5,
                        y: item.running || hovered ? 3 : 1.5
                    )

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
                            pulse: item.running && (activity.state == .runningTask || activity.state == .stalled || activity.state == .needsAttention)
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

                    if let store = InstanceStore.current {
                        AutoPilotPillView(store: store, item: item, onConfigure: editAutoPilot)
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

                    Spacer(minLength: 6)

                    if item.running && !activity.currentAction.isEmpty {
                        Text(activity.currentAction)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let store = InstanceStore.current {
                        AutoPilotPillView(store: store, item: item, onConfigure: editAutoPilot)
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

                IconActionButton(symbol: "ellipsis", tooltip: "更多实例操作", size: 30) {
                    showMorePopover.toggle()
                }
                .popover(isPresented: $showMorePopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        popoverMenuButton(
                            title: "在访达中显示应用",
                            symbol: "folder",
                            destructive: false
                        ) {
                            showMorePopover = false
                            reveal()
                        }
                        popoverMenuButton(
                            title: "查看运行日志",
                            symbol: "doc.text.magnifyingglass",
                            destructive: false
                        ) {
                            showMorePopover = false
                            logs()
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

                        popoverMenuButton(
                            title: "编辑项目备注与标签…",
                            symbol: "tag",
                            destructive: false
                        ) {
                            showMorePopover = false
                            editMeta()
                        }
                        popoverMenuButton(
                            title: meta.autoPilotEnabled ? "🤖 配置/关闭自托管…" : "🤖 开启自托管…",
                            symbol: "sparkles",
                            destructive: false
                        ) {
                            showMorePopover = false
                            editAutoPilot?()
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
        .overlay {
            AmbientGlowBorder(
                isActive: item.running && (activity.state == .runningTask || activity.state == .stalled || activity.state == .needsAttention),
                color: activity.state == .stalled ? Color(red: 0.98, green: 0.69, blue: 0.20) : Color(red: 0.15, green: 0.82, blue: 0.96),
                cornerRadius: 16,
                lineWidth: 1.8
            )
        }
        .overlay {
            GlassShimmerOverlay(isHovered: hovered, cornerRadius: 16)
        }
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
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.22 : 0.40), location: 0.0),
                            .init(color: border, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.92
                )
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

// MARK: - Auto-Pilot Pill Badge View

struct AutoPilotPillView: View {
    @ObservedObject var store: InstanceStore
    let item: ManagedInstance
    @Binding var showingConfigSheet: Bool
    var onConfigure: (() -> Void)? = nil

    init(store: InstanceStore, item: ManagedInstance, showingConfigSheet: Binding<Bool> = .constant(false), onConfigure: (() -> Void)? = nil) {
        self.store = store
        self.item = item
        self._showingConfigSheet = showingConfigSheet
        self.onConfigure = onConfigure
    }

    var body: some View {
        let meta = store.meta(for: item)
        let state = store.autoPilotState(for: item)
        let remaining = store.autoPilotDebounceRemaining[item.id]

        if meta.autoPilotEnabled {
            Button(action: {
                if let onConfigure {
                    onConfigure()
                } else {
                    showingConfigSheet = true
                }
            }) {
                HStack(spacing: 4.5) {
                    Image(systemName: state.systemImage)
                        .font(.system(size: 9.5, weight: .bold))
                    Text(displayText(state: state, remaining: remaining, lang: store.appLanguage))
                        .font(.system(size: 10, weight: .semibold))
                    if meta.autoPilotMaxRounds > 0 {
                        Text("(\(meta.autoPilotCurrentRounds)/\(meta.autoPilotMaxRounds))")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .opacity(0.85)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(state.color.opacity(0.16))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(state.color.opacity(0.40), lineWidth: 0.9)
                )
                .foregroundStyle(state.color)
            }
            .buttonStyle(.plain)
            .help(store.appLanguage == .zhHans || store.appLanguage == .zhHant
                  ? "🤖 自托管已启用：点击配置预设指令与防抖确认参数"
                  : "🤖 Auto-Pilot active: Click to configure prompt and debounce")
        }
    }

    private func displayText(state: AutoPilotRunState, remaining: Int?, lang: AppLanguage) -> String {
        if state == .debouncing, let rem = remaining {
            return "\(state.label(lang: lang)) (\(rem)s)"
        }
        return state.label(lang: lang)
    }
}

// MARK: - Auto-Pilot Configuration Sheet

struct AutoPilotConfigSheet: View {
    @ObservedObject var store: InstanceStore
    let item: ManagedInstance
    let onDismiss: () -> Void

    @State private var enabled: Bool
    @State private var promptText: String
    @State private var maxRounds: Int
    @State private var debounceSeconds: Double
    @State private var isTestingInjection = false
    @State private var testResultMsg: String? = nil

    private let promptTemplates: [(title: String, prompt: String)] = [
        ("继续下一步", "继续下一步"),
        ("深入分析", "请继续分析当前工作区代码并给出改进建议与完整实现"),
        ("测试驱动", "运行所有关联测试并针对失败项进行修复直至全部通过"),
        ("代码重构", "检查代码规范、死代码与可读性并执行针对性重构")
    ]

    init(store: InstanceStore, item: ManagedInstance, onDismiss: @escaping () -> Void) {
        self.store = store
        self.item = item
        self.onDismiss = onDismiss
        let currentMeta = store.meta(for: item)
        _enabled = State(initialValue: currentMeta.autoPilotEnabled)
        _promptText = State(initialValue: currentMeta.autoPilotPrompt.isEmpty ? "继续下一步" : currentMeta.autoPilotPrompt)
        _maxRounds = State(initialValue: currentMeta.autoPilotMaxRounds)
        _debounceSeconds = State(initialValue: max(1.0, currentMeta.autoPilotDebounceSeconds))
    }

    var body: some View {
        let state = store.autoPilotState(for: item)
        let currentMeta = store.meta(for: item)

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [Color.cyan.opacity(0.8), Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("自托管配置 (Auto-Pilot)")
                            .font(.system(size: 15, weight: .bold))
                        Text("· \(item.name)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("当实例空闲时，后台静默自动向当前窗口注入预设指令，绝不抢占前台焦点与鼠标")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            Divider()

            // Status Bar Banner
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: state.systemImage)
                        .font(.system(size: 11, weight: .bold))
                    Text("当前调度状态: \(state.label(lang: store.appLanguage))")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(state.color)
                Spacer()
                if currentMeta.autoPilotMaxRounds > 0 {
                    Text("已执行: \(currentMeta.autoPilotCurrentRounds) / \(currentMeta.autoPilotMaxRounds) 轮")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("已执行: \(currentMeta.autoPilotCurrentRounds) 轮 (无限循环)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(state.color.opacity(0.10)))

            // Enable Toggle
            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("启用此实例的后台静默自托管")
                        .font(.system(size: 12.5, weight: .medium))
                    Text("开启后将在任务执行完成并连续空闲达到确认防抖时间后，自动注入文本继续执行")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            // Preset Prompt
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("预设自动发送文本")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("快捷填入:")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    ForEach(promptTemplates, id: \.title) { tmpl in
                        Button(action: { promptText = tmpl.prompt }) {
                            Text(tmpl.title)
                                .font(.system(size: 10))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.primary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextEditor(text: $promptText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 70)
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
            }

            // Sliders: Debounce Seconds & Max Rounds
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("空闲防抖确认:")
                            .font(.system(size: 11.5, weight: .medium))
                        Text("\(Int(debounceSeconds)) 秒")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                    }
                    Slider(value: $debounceSeconds, in: 1...10, step: 1)
                    Text("避免 Agent 多步工具调用间 1~2 秒假空闲误触发")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("循环最大轮数:")
                            .font(.system(size: 11.5, weight: .medium))
                        Text(maxRounds == 0 ? "无限制 (连续)" : "\(maxRounds) 轮")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                    }
                    Stepper(value: $maxRounds, in: 0...100) {
                        Text(maxRounds == 0 ? "连续运行直至人工介入" : "达到 \(maxRounds) 轮后安全停止")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Invariant Notice Banner
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.blue)
                    Text("安全守护与不打扰保证")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                Text("• 长时间挂起保护：当任务在编译、跑测试或深度推理处于挂起状态时，持续等待，绝不打断。\n• 人工介入锁定：若遇到 Agent 询问或弹窗确认，自托管立即暂停并通知您，绝不盲目乱发。\n• 零焦点抢占：采用 Chromium DevTools Protocol 底层注入，窗口在后台静默运行，不抢鼠标键盘。")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.06)))

            if let msg = testResultMsg {
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(msg.contains("成功") ? .green : .red)
            }

            Divider()

            // Footer Actions
            HStack {
                Button(action: {
                    guard !isTestingInjection else { return }
                    isTestingInjection = true
                    testResultMsg = "正在通过 CDP 静默注入..."
                    Task {
                        let ok = await store.injectPromptViaCDP(item: item, prompt: promptText)
                        await MainActor.run {
                            isTestingInjection = false
                            if ok {
                                testResultMsg = "✅ 测试注入成功！预设指令已静默递送并触发提交"
                            } else {
                                testResultMsg = "❌ 注入失败：未检测到 DevToolsActivePort 或对话窗口未加载"
                            }
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isTestingInjection ? "arrow.triangle.2.circlepath" : "paperplane")
                        Text("立即后台测试发送")
                    }
                }
                .buttonStyle(ModernButtonStyle(variant: .secondary, compact: true))
                .disabled(!item.running || isTestingInjection || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                Button("取消") {
                    onDismiss()
                }
                .buttonStyle(ModernButtonStyle(variant: .ghost, compact: true))

                Button("保存并应用") {
                    store.updateAutoPilotConfig(
                        for: item,
                        enabled: enabled,
                        prompt: promptText.trimmingCharacters(in: .whitespacesAndNewlines),
                        maxRounds: maxRounds,
                        debounceSeconds: debounceSeconds
                    )
                    onDismiss()
                }
                .buttonStyle(ModernButtonStyle(variant: .primary, compact: true))
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

// MARK: - Upgrade Confirmation Sheet

struct UpgradeRequest: Identifiable {
    let id = UUID()
    let instances: [ManagedInstance]
}

struct UpgradeConfirmationView: View {
    @ObservedObject var store: InstanceStore
    let instances: [ManagedInstance]
    let targetVersion: String
    let dismiss: () -> Void

    @State private var createBackup: Bool = true
    @State private var isUpgrading: Bool = false
    @State private var showLogs: Bool = false

    private var notes: [SourceReleaseNotes] {
        SourceReleaseNotes.bundled.filter { note in
            note.version.compare(targetVersion, options: .numeric) != .orderedDescending &&
            instances.contains { $0.version.compare(note.version, options: .numeric) == .orderedAscending }
        }.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !isUpgrading && !store.busy {
                confirmationContent
            } else {
                inProgressContent
            }
        }
        .padding(24)
        .frame(width: 620)
        .onAppear {
            if store.busy {
                isUpgrading = true
            }
        }
    }

    private var confirmationContent: some View {
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
                    Text("源版本 v\(targetVersion)  ·  共 \(instances.count) 个待升级实例  ·  \(createBackup ? "已选择安全备份" : "已选择不备份极速升级")")
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

                    // 备份选项切换卡 (Backup Toggle Selection Card)
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $createBackup) {
                            HStack(alignment: .center, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(createBackup ? Color.green.opacity(0.16) : Color.orange.opacity(0.16))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: createBackup ? "shield.lefthalf.filled.badge.checkmark" : "bolt.slash.fill")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(createBackup ? .green : .orange)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text("升级前创建安全备份")
                                            .font(.system(size: 13.5, weight: .semibold))
                                        Text(createBackup ? "推荐" : "不备份")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(createBackup ? .green : .orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1.5)
                                            .background(createBackup ? Color.green.opacity(0.14) : Color.orange.opacity(0.14))
                                            .clipShape(Capsule())
                                    }
                                    Text(createBackup
                                        ? "自动完整备份旧程序、账号数据与窗口缓存到 Backups 目录；升级若遇异常可一键还原"
                                        : "⚡️ 跳过备份直接原子替换：升级速度提升 3 倍，且不产生额外备份文件；升级前请确保各副本工作已保存")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                    .padding(14)
                    .systemSurface(radius: 13, isHighlighted: true, tint: createBackup ? .green : .orange)

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
                            .frame(height: 200)
                            .padding(10)
                            .systemSurface(radius: 12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 6)
            }
            .frame(height: 380)

            HStack(alignment: .center, spacing: 10) {
                Button("取消", action: dismiss)
                    .buttonStyle(ModernButtonStyle(variant: .secondary))
                    .keyboardShortcut(.cancelAction)

                Spacer()

                if createBackup {
                    Button {
                        startUpgrade(backup: false)
                    } label: {
                        Text("跳过备份直接升级")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("无需手动勾选，一键直接升级")

                    Button("备份并升级") {
                        startUpgrade(backup: true)
                    }
                    .buttonStyle(ModernButtonStyle(variant: .upgrade))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(store.busy || instances.isEmpty)
                } else {
                    Button {
                        startUpgrade(backup: true)
                    } label: {
                        Text("改为备份并升级")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button("直接升级 (不备份)") {
                        startUpgrade(backup: false)
                    }
                    .buttonStyle(ModernButtonStyle(variant: .upgrade))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(store.busy || instances.isEmpty)
                }
            }
        }
    }

    private var inProgressContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(statusTint.opacity(0.14))
                        .frame(width: 44, height: 44)
                    if store.busy {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(accent)
                    } else if store.error == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.busy ? "正在升级实例…" : (store.error == nil ? "实例升级完成！" : "升级未能全部完成"))
                        .font(.system(size: 19, weight: .bold))
                    Text(store.busy 
                        ? "目标版本 v\(targetVersion)  ·  \(createBackup ? "已启用安全备份" : "未备份快速升级")  ·  请保持应用开启"
                        : (store.error == nil ? "所有选定实例已成功升级至最新版本 v\(targetVersion)" : (store.error ?? "操作出现异常")))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // 升级全局进度条与阶段文字 (Glowing Progress Bar)
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center) {
                    HStack(spacing: 7) {
                        if store.busy {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(store.operationStage ?? (store.busy ? "正在准备升级环境…" : "升级流程已就绪"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(store.error == nil ? Color.primary : Color.orange)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(Int((store.operationProgress ?? (store.busy ? 0.05 : 1.0)) * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(statusTint)
                }

                ProgressView(value: store.operationProgress ?? (store.busy ? 0.05 : 1.0), total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(statusTint)
            }
            .padding(16)
            .systemSurface(radius: 14, isHighlighted: store.busy, tint: statusTint)

            // 升级执行流水线阶段卡片 (Pipeline Stepper)
            VStack(alignment: .leading, spacing: 8) {
                Text("执行阶段")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    pipelineStage(step: 1, title: "官方源验签", threshold: 0.05)
                    pipelineStage(step: 2, title: "适配与签名", threshold: 0.15)
                    pipelineStage(step: 3, title: "关闭实例", threshold: 0.62)
                    pipelineStage(step: 4, title: createBackup ? "安全备份" : "跳过备份", threshold: 0.68)
                    pipelineStage(step: 5, title: "替换安装", threshold: 0.78)
                }
            }

            // 待升级实例卡片列表
            VStack(alignment: .leading, spacing: 8) {
                Text("实例升级状态 (\(instances.count))")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                ScrollView {
                    VStack(spacing: 6) {
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
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                
                                instanceStatusPill(for: item)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .systemSurface(radius: 10)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }

            // 实时操作日志抽屉
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        showLogs.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showLogs ? "收起操作日志" : "查看实时详细日志")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: showLogs ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if showLogs {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(store.output)
                                .font(.system(size: 10.5, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .id("upgradeLogBottom")
                        }
                        .frame(height: 110)
                        .systemSurface(radius: 10)
                        .onChange(of: store.output) { _ in
                            proxy.scrollTo("upgradeLogBottom", anchor: .bottom)
                        }
                    }
                }
            }

            // 底部操作按钮
            HStack(alignment: .center, spacing: 10) {
                if store.busy {
                    Button("后台运行并收起", action: dismiss)
                        .buttonStyle(ModernButtonStyle(variant: .secondary))
                        .help("收起此窗口，升级将在后台继续平稳执行，底部操作栏会持续显示进度")

                    Spacer()
                    Text("升级进行中，请勿强制退出应用")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Spacer()
                    if store.error == nil {
                        Button("完成并关闭", action: dismiss)
                            .buttonStyle(ModernButtonStyle(variant: .primary))
                        if instances.count == 1 {
                            Button("立即打开实例") {
                                store.open(instances[0])
                                dismiss()
                            }
                            .buttonStyle(ModernButtonStyle(variant: .upgrade))
                        }
                    } else {
                        Button("关闭", action: dismiss)
                            .buttonStyle(ModernButtonStyle(variant: .secondary))
                    }
                }
            }
        }
    }

    private func pipelineStage(step: Int, title: String, threshold: Double) -> some View {
        let currentProgress = store.operationProgress ?? (store.busy ? 0.05 : 1.0)
        let isDone = !store.busy ? (store.error == nil) : (currentProgress >= threshold + 0.08)
        let isActive = store.busy && currentProgress >= threshold && currentProgress < threshold + 0.08
        
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green.opacity(0.18) : (isActive ? accent.opacity(0.18) : Color.secondary.opacity(0.12)))
                    .frame(width: 22, height: 22)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                } else if isActive {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                } else {
                    Text("\(step)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Text(title)
                .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isDone ? Color.primary : (isActive ? accent : Color.secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .systemSurface(radius: 8, isHighlighted: isActive, tint: isActive ? accent : nil)
    }

    private func instanceStatusPill(for item: ManagedInstance) -> some View {
        let currentProgress = store.operationProgress ?? (store.busy ? 0.05 : 1.0)
        if !store.busy {
            if store.error == nil {
                return AnyView(
                    Text("已完成 ✓")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.14))
                        .clipShape(Capsule())
                )
            } else {
                return AnyView(
                    Text("异常")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.14))
                        .clipShape(Capsule())
                )
            }
        }
        
        if currentProgress >= 0.96 {
            return AnyView(
                Text("安装就绪")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.14))
                    .clipShape(Capsule())
            )
        } else if currentProgress >= 0.78 {
            return AnyView(
                Text("替换中…")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.14))
                    .clipShape(Capsule())
            )
        } else if currentProgress >= 0.68 {
            return AnyView(
                Text(createBackup ? "备份中…" : "准备中…")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.14))
                    .clipShape(Capsule())
            )
        } else if currentProgress >= 0.15 {
            return AnyView(
                Text("适配中…")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.14))
                    .clipShape(Capsule())
            )
        } else {
            return AnyView(
                Text("排队中")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            )
        }
    }

    private var statusTint: Color {
        if store.busy { return accent }
        return store.error == nil ? .green : .orange
    }

    private func startUpgrade(backup: Bool) {
        createBackup = backup
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            isUpgrading = true
        }
        store.upgrade(instances, backup: backup)
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
    func localized(lang: AppLanguage) -> String {
        switch self {
        case .grid: return L10n.tr(.viewGrid, lang: lang)
        case .list: return L10n.tr(.viewList, lang: lang)
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
    func localized(lang: AppLanguage) -> String {
        switch self {
        case .all: return L10n.tr(.filterAll, lang: lang)
        case .running: return L10n.tr(.filterRunning, lang: lang)
        case .busyTask: return L10n.tr(.filterBusyTask, lang: lang)
        case .withTags: return L10n.tr(.filterWithTags, lang: lang)
        case .upgradable: return L10n.tr(.upgradableTo, lang: lang)
        }
    }
}

final class MainWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowDelegate()
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

private struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.delegate = MainWindowDelegate.shared
                window.isReleasedWhenClosed = false
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    let updaterController: SPUStandardUpdaterController
    @Environment(\.openWindow) private var openWindow
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
    @State private var editingAutoPilotItem: ManagedInstance?
    @State private var showOptionsPopover = false
    @State private var destination = URL(fileURLWithPath: "/Applications")
    @State private var selectedFilter: InstanceFilter = .all
    @State private var refreshSpin: Double = 0
    @State private var logExpanded = true
    @State private var appeared = false
    @AppStorage("metricsHudExpanded") private var metricsExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.8.4"
    }

    private func matchesFilter(_ item: ManagedInstance) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .running:
            return item.running
        case .busyTask:
            let state = store.activity(for: item).state
            return item.running && (state == .runningTask || state == .stalled || state == .needsAttention)
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

            if store.isSelectionMode && !store.selectedInstanceIds.isEmpty {
                BatchActionBarView(store: store)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }

            if store.busy || !store.output.isEmpty {
                operationConsoleDrawer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 860, minHeight: 640)
        .background(MainWindowAccessor())
        .onAppear {
            store.openMainWindowHandler = { [openWindow] in
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            store.refresh()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                appeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMainWindowRequested)) { _ in
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCreateInstanceRequested)) { _ in
            showCreate = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPreferencesRequested)) { _ in
            showOptionsPopover = true
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
                store: store,
                instances: request.instances,
                targetVersion: store.sourceVersion,
                dismiss: { upgradeRequest = nil }
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
        .sheet(item: $editingAutoPilotItem) { item in
            AutoPilotConfigSheet(
                store: store,
                item: item,
                onDismiss: {
                    editingAutoPilotItem = nil
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
        .preferredColorScheme(store.appTheme.colorScheme)
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
                        .frame(width: 44, height: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.60), location: 0.0),
                                            .init(color: Color.white.opacity(0.12), location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.15
                                )
                        }
                        .shadow(color: accent.opacity(0.36), radius: 10, x: 0, y: 3.5)
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("Aether Antigravity Multiplexer")
                            .font(.system(size: 19, weight: .bold))
                            .lineLimit(1)

                        HStack(alignment: .center, spacing: 6) {
                            Text("v\(appVersion)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(accent)
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                            Text("Kernel Direct")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Capsule().fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.045)))
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.25 : 0.40), location: 0.0),
                                            .init(color: Color.green.opacity(0.30), location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.95
                                )
                        }
                        .help("内核直接通信：使用 macOS Darwin libproc 直读进程指标，0 子进程开销，微秒级能效")
                    }
                    Text(store.tr(.appSubtitle))
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
                            Text(store.tr(.toolbarCollapseAll))
                        }
                    }
                    .buttonStyle(ModernButtonStyle(variant: .secondary))
                    .help("隐藏所有正在显示的 Antigravity 窗口并回到缩略图监控墙（后台任务继续运行）")
                }

                // Consolidated Glass Utility Cluster: Refresh, Task History, and Maintenance Menu
                HStack(spacing: 2) {
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

                    Menu {
                        Button {
                            store.refreshBackups()
                            showBackupManager = true
                        } label: {
                            Label("管理升级备份 (\(store.backups.count) 个批次)", systemImage: "externaldrive")
                        }

                        Divider()

                        Button {
                            updaterController.checkForUpdates(nil)
                        } label: {
                            Label("检查软件更新...", systemImage: "arrow.down.circle")
                        }

                        Button {
                            showUpdateSettings = true
                        } label: {
                            Label("自动更新设置...", systemImage: "gearshape")
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: Color.white.opacity(colorScheme == .dark ? 0.18 : 0.28), location: 0.0),
                                                    .init(color: Color.primary.opacity(0.04), location: 1.0)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.95
                                        )
                                }
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.primary.opacity(0.85))
                                .frame(width: 34, height: 34)

                            if store.backups.count > 0 {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 6, height: 6)
                                    .offset(x: -4, y: 4)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 34, height: 34)
                    .help("维护工具与更新设置（管理升级备份、检查更新、偏好）")
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
                        Text(store.tr(.toolbarCreateInstance))
                    }
                }
                .buttonStyle(ModernButtonStyle(variant: .primary))
                .disabled(store.busy)
            }
        }
    }

    // MARK: - Metrics Strip (Compact HUD with Optional Expansion)

    @ViewBuilder
    private var metricsStrip: some View {
        if metricsExpanded {
            expandedMetricsGrid
        } else {
            compactMetricsHUD
        }
    }

    private var compactMetricsHUD: some View {
        HStack(alignment: .center, spacing: 0) {
            // Segment 1: 运行监控
            HStack(spacing: 8) {
                PulsingStatusDot(
                    active: store.runningCount > 0,
                    activeColor: store.activeTaskCount > 0 ? Color(red: 0.15, green: 0.82, blue: 0.96) : .green,
                    pulse: store.activeTaskCount > 0
                )
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4.5) {
                        Text("\(store.runningCount)/\(store.instances.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("运行中")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(store.activeTaskCount > 0 ? "⚡ \(store.activeTaskCount) 个任务执行中" : "所有实例空闲")
                        .font(.system(size: 10))
                        .foregroundStyle(store.activeTaskCount > 0 ? Color(red: 0.15, green: 0.82, blue: 0.96) : .secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if store.globalCpuHistory.count >= 2 {
                    SparklineView(samples: store.globalCpuHistory.map(\.value), minVal: 0, color: store.activeTaskCount > 0 ? Color(red: 0.15, green: 0.82, blue: 0.96) : accent)
                        .frame(width: 40, height: 20)
                        .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)

            Divider().frame(height: 22).opacity(0.5)

            // Segment 2: 存储与数据
            HStack(spacing: 8) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4.5) {
                        Text(store.totalDiskUsageBytes > 0 ? store.formattedTotalDiskUsage : "统计中…")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("存储占用")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("\(store.instances.count) 个独立实例")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if store.globalRamHistory.count >= 2 {
                    SparklineView(samples: store.globalRamHistory.map(\.value), minVal: 0, color: .cyan)
                        .frame(width: 40, height: 20)
                        .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)

            Divider().frame(height: 22).opacity(0.5)

            // Segment 3: 官方主版本
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4.5) {
                        Text(store.sourceVersion == "—" ? "—" : "v\(store.sourceVersion)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("主程序")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("/Applications/Antigravity.app")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)

            Divider().frame(height: 22).opacity(0.5)

            // Segment 4: 兼容状态
            HStack(spacing: 8) {
                Image(systemName: store.compatibility == "已支持本机版本" ? "wrench.and.screwdriver.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(compatibilityColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.compatibility)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(compatibilityColor)
                        .lineLimit(1)
                    Text(store.pendingUpgrades.isEmpty ? "全部副本最新" : "\(store.pendingUpgrades.count) 个可升级")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)

            // Far right: Expand toggle button
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    metricsExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .help("展开大图监控卡片与详细指标")
        }
        .padding(.vertical, 8)
        .frame(height: 48)
        .systemSurface(radius: 12)
    }

    private var expandedMetricsGrid: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                metricTile(
                    title: store.tr(.metricRunningMonitor),
                    value: "\(store.runningCount) / \(store.instances.count) 运行中",
                    subtitle: store.activeTaskCount > 0 ? "⚡ 当前有 \(store.activeTaskCount) 个实例正在执行 Agent 任务" : "所有已启动实例均处于空闲就绪状态",
                    symbol: "waveform.path.ecg.rectangle.fill",
                    tint: store.activeTaskCount > 0 ? Color(red: 0.15, green: 0.82, blue: 0.96) : accent,
                    sparklineSamples: store.globalCpuHistory.map(\.value),
                    leadingIndicator: {
                        AnyView(PulsingStatusDot(
                            active: store.runningCount > 0,
                            activeColor: store.activeTaskCount > 0 ? Color(red: 0.15, green: 0.82, blue: 0.96) : .green,
                            pulse: store.activeTaskCount > 0
                        ))
                    }
                )

                metricTile(
                    title: store.tr(.metricPrimaryVersion),
                    value: store.sourceVersion == "—" ? "—" : "v\(store.sourceVersion)",
                    subtitle: "/Applications/Antigravity.app",
                    symbol: "checkmark.shield.fill",
                    tint: .indigo
                )

                metricTile(
                    title: store.tr(.metricDiskUsage),
                    value: store.totalDiskUsageBytes > 0 ? store.formattedTotalDiskUsage : "统计中…",
                    subtitle: "\(store.instances.count) 个实例独立数据与存储",
                    symbol: "internaldrive.fill",
                    tint: .cyan,
                    sparklineSamples: store.globalRamHistory.map(\.value)
                )

                metricTile(
                    title: store.tr(.metricCompatibility),
                    value: store.compatibility,
                    subtitle: store.pendingUpgrades.isEmpty
                        ? "全部独立副本均为最新版本"
                        : "发现 \(store.pendingUpgrades.count) 个副本可升级至 v\(store.sourceVersion)",
                    symbol: store.compatibility == "已支持本机版本" ? "wrench.and.screwdriver.fill" : "exclamationmark.triangle.fill",
                    tint: compatibilityColor
                )
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        metricsExpanded = false
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("收起指标")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("折叠为紧凑状态指标条")
            }
        }
    }

    private func metricTile(
        title: String,
        value: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        sparklineSamples: [Double]? = nil,
        leadingIndicator: (() -> AnyView)? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 42, height: 42)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.35), location: 0.0),
                                        .init(color: tint.opacity(0.20), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.95
                            )
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

            if let samples = sparklineSamples, samples.count >= 2 {
                SparklineView(samples: samples, minVal: 0, color: tint)
                    .frame(width: 46, height: 26)
                    .opacity(0.85)
            }
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
                            Text(filter.localized(lang: store.appLanguage))
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
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    stops: [
                                                        .init(color: Color.white.opacity(colorScheme == .dark ? 0.25 : 0.40), location: 0.0),
                                                        .init(color: Color.primary.opacity(0.08), location: 1.0)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 0.95
                                            )
                                    }
                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.05), radius: 3, y: 1)
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
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(colorScheme == .dark ? 0.18 : 0.28), location: 0.0),
                                .init(color: Color.primary.opacity(0.05), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.95
                    )
            }

            // Multi-selection mode toggle
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    if store.isSelectionMode {
                        store.clearSelection()
                    } else {
                        store.isSelectionMode = true
                    }
                }
            } label: {
                HStack(spacing: 4.5) {
                    Image(systemName: store.isSelectionMode ? "checkmark.circle.fill" : "checklist")
                        .font(.system(size: 11, weight: .semibold))
                    Text(store.isSelectionMode ? (store.effectiveLanguage == .en ? "Select Mode" : "多选模式") : (store.effectiveLanguage == .en ? "Batch Select" : "批量选择"))
                        .font(.system(size: 11.5, weight: store.isSelectionMode ? .semibold : .medium))
                }
                .foregroundStyle(store.isSelectionMode ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 9)
                .frame(height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(store.isSelectionMode ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
                }
            }
            .buttonStyle(.plain)

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
                            Text(mode.localized(lang: store.appLanguage))
                                .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                        }
                        .foregroundStyle(active ? Color.primary : Color.secondary)
                        .padding(.horizontal, 9.5)
                        .frame(height: 26)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    stops: [
                                                        .init(color: Color.white.opacity(colorScheme == .dark ? 0.25 : 0.40), location: 0.0),
                                                        .init(color: Color.primary.opacity(0.08), location: 1.0)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 0.95
                                            )
                                    }
                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.05), radius: 3, y: 1)
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
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(colorScheme == .dark ? 0.18 : 0.28), location: 0.0),
                                .init(color: Color.primary.opacity(0.05), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.95
                    )
            }

            // Density Switcher (Active in Grid Mode)
            if viewMode == .grid {
                toolbarDensitySwitcher
            }

            // Quick Switcher Button
            Button {
                store.toggleQuickSwitcher()
            } label: {
                HStack(alignment: .center, spacing: 5) {
                    Image(systemName: "command.square")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0.52, green: 0.28, blue: 0.98))
                    Text(store.tr(.toolbarQuickSwitcher))
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
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(colorScheme == .dark ? 0.22 : 0.35), location: 0.0),
                                    .init(color: Color(red: 0.52, green: 0.28, blue: 0.98).opacity(0.20), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.95
                        )
                }
                .shadow(color: Color(red: 0.52, green: 0.28, blue: 0.98).opacity(0.12), radius: 4, y: 1.5)
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
                    Text(store.tr(.toolbarOptions))
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

    private var toolbarDensitySwitcher: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(ViewDensity.allCases, id: \.self) { density in
                let active = store.viewDensity == density
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        store.viewDensity = density
                    }
                    HapticManager.shared.play(.alignment)
                } label: {
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: density.symbol)
                            .font(.system(size: 10.5, weight: .semibold))
                            .frame(width: 12, height: 12, alignment: .center)
                        Text(density.localized(lang: store.appLanguage))
                            .font(.system(size: 11, weight: active ? .semibold : .medium))
                    }
                    .foregroundStyle(active ? Color.primary : Color.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(active ? (colorScheme == .dark ? 0.16 : 0.10) : 0.0))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.white.opacity(active ? (colorScheme == .dark ? 0.25 : 0.40) : 0.0), lineWidth: 0.95)
                    )
                }
                .buttonStyle(.plain)
                .help(density.localized(lang: store.appLanguage))
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.28), lineWidth: 0.95)
        )
    }

    private var toolbarOptionsPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Text(store.tr(.optionsTitle))
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }

            Divider()

            popoverThemeSection
            popoverLanguageSection
            popoverTilingSection
            popoverDensitySection

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $store.hapticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.tr(.hapticsEnabled))
                            .font(.system(size: 12, weight: .semibold))
                        Text(store.tr(.hapticsSubtitle))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $store.ecoModeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.tr(.ecoModeEnabled))
                            .font(.system(size: 12, weight: .semibold))
                        Text(store.tr(.ecoModeSubtitle))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

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
        .frame(width: 356)
    }

    private var popoverThemeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                Text(store.tr(.themeTitle))
                    .font(.system(size: 11.5, weight: .semibold))
            }
            HStack(spacing: 4) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    let active = store.appTheme == theme
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.appTheme = theme
                        }
                        HapticManager.shared.play(.levelChange)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: theme.symbol)
                                .font(.system(size: 10, weight: .semibold))
                            Text(theme.localized(lang: store.appLanguage))
                                .font(.system(size: 11, weight: active ? .semibold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .foregroundStyle(active ? Color.primary : Color.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(active ? (colorScheme == .dark ? 0.16 : 0.10) : 0.0))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.03)))
        }
    }

    private var popoverLanguageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                Text(store.tr(.langTitle))
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer()
                Picker("", selection: $store.appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 140)
                .onChange(of: store.appLanguage) { _ in
                    HapticManager.shared.play(.levelChange)
                }
            }
        }
    }

    private var popoverTilingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                Text(store.tr(.tilePresetsTitle))
                    .font(.system(size: 11.5, weight: .semibold))
            }
            HStack(spacing: 6) {
                ForEach(WindowTileLayout.allCases) { layout in
                    Button {
                        HapticManager.shared.play(.alignment)
                        WindowTileManager.applyLayout(layout, instances: store.instances)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: layout.symbol)
                                .font(.system(size: 10))
                            Text(layout.localized(lang: store.appLanguage))
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04)))
                    }
                    .buttonStyle(.plain)
                    .help(layout.localized(lang: store.appLanguage))
                }
            }
        }
    }

    private var popoverDensitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                Text(store.tr(.viewDensityTitle))
                    .font(.system(size: 11.5, weight: .semibold))
            }
            HStack(spacing: 4) {
                ForEach(ViewDensity.allCases, id: \.self) { density in
                    let active = store.viewDensity == density
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.viewDensity = density
                        }
                        HapticManager.shared.play(.alignment)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: density.symbol)
                                .font(.system(size: 10, weight: .semibold))
                            Text(density.localized(lang: store.appLanguage))
                                .font(.system(size: 11, weight: active ? .semibold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .foregroundStyle(active ? Color.primary : Color.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(active ? (colorScheme == .dark ? 0.16 : 0.10) : 0.0))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.03)))
        }
    }

    // MARK: - Thumbnail Monitor Wall View (Grid Mode)

    private var thumbnailWallSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if filteredInstances.isEmpty {
                filteredEmptyView
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: store.viewDensity.minWidth, maximum: store.viewDensity.maxWidth), spacing: store.viewDensity.gridSpacing)],
                    spacing: store.viewDensity.gridSpacing + 2
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
                            density: store.viewDensity,
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
                            editAutoPilot: { editingAutoPilotItem = item },
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
                editAutoPilot: { editingAutoPilotItem = primary },
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
                            editAutoPilot: { editingAutoPilotItem = item },
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

                Text(store.busy ? (store.operationStage ?? "正在执行实例操作…") : "操作执行记录")
                    .font(.system(size: 12.5, weight: .semibold))

                if store.busy, let progress = store.operationProgress {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(width: 130)
                        .tint(accent)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                } else if let lastLine = store.output.split(separator: "\n").last {
                    Text("·  \(String(lastLine))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if store.busy && !store.activeUpgradeInstances.isEmpty {
                    Button {
                        upgradeRequest = UpgradeRequest(instances: store.activeUpgradeInstances)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 11))
                            Text("查看升级面板")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }

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
        var shown = false
        for window in sender.windows where !(window is NSPanel) && !window.isSheet && window.canBecomeMain {
            if let sheet = window.attachedSheet {
                sheet.makeKeyAndOrderFront(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
            sender.activate(ignoringOtherApps: true)
            shown = true
            return true
        }
        if !shown {
            NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
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
