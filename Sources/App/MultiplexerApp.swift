import AppKit
import Combine
import Sparkle
import SwiftUI

final class MultiplexerUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        NSLog("[Sparkle] Update aborted: domain=%@, code=%ld, description=%@", nsError.domain, nsError.code, nsError.localizedDescription)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if let error = error {
            let nsError = error as NSError
            NSLog("[Sparkle] Update cycle error: domain=%@, code=%ld, description=%@", nsError.domain, nsError.code, nsError.localizedDescription)
        }
    }
}

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController()

    private(set) weak var store: InstanceStore?
    private weak var updaterController: SPUStandardUpdaterController?
    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?
    private var lastSymbolName = ""

    func bind(store: InstanceStore, updaterController: SPUStandardUpdaterController) {
        self.store = store
        self.updaterController = updaterController
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Aether Antigravity Multiplexer")
            item.button?.imagePosition = .imageLeading
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        }
        cancellable = store.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshStatusButton() }
        }
        refreshStatusButton()
    }

    func refreshStatusButton() {
        guard let button = statusItem?.button, let store else { return }
        let attention = store.instances.filter { $0.running && store.activity(for: $0).state == .needsAttention }.count
        let stalled = store.instances.filter { $0.running && store.activity(for: $0).state == .stalled }.count
        let active = store.activeTaskCount

        let (symbolName, title): (String, String) = attention > 0
            ? ("bell.badge.fill", " \(attention)待确认")
            : stalled > 0 ? ("clock.badge.exclamationmark.fill", " \(stalled)挂起")
            : active > 0 ? ("bolt.fill", " \(active)")
            : ("square.grid.2x2.fill", "")

        if lastSymbolName != symbolName {
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Aether Antigravity Multiplexer")
            lastSymbolName = symbolName
        }
        if button.title != title { button.title = title }
    }

    static func instanceMenuTitle(for item: ManagedInstance, store: InstanceStore) -> String {
        let acct = store.account(for: item)
        let emailPart = acct.isLoggedIn ? " (\(acct.displayEmail(masked: store.maskAccountEmails)))" : ""
        return "\(String(format: "#%02d", item.index)) \(store.displayTitle(for: item))\(emailPart)"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let store else { return }

        let header = NSMenuItem(title: "实例列表 (\(store.runningCount) / \(store.instances.count) 运行中)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for item in store.instances {
            let act = store.activity(for: item)
            let icon = stateEmoji(running: item.running, state: act.state)
            let hint = (store.globalHotkeysEnabled && item.index <= 9) ? " [⌥\(item.index)]" : ""
            let title = "\(icon) \(Self.instanceMenuTitle(for: item, store: store)) · \(act.state.label)\(hint)"
            menu.addItem(makeItem(title: title, action: #selector(openInstanceAction(_:)), object: item.id))
        }

        menu.addItem(.separator())
        menu.addItem(makeItem(title: "收起全部窗口 (⌥0)", action: #selector(collapseAllAction)))
        if store.runningCloneCount > 0 {
            menu.addItem(makeItem(title: "安全退出所有分身 (\(store.runningCloneCount))", action: #selector(quitAllClonesAction)))
        }

        let dockParent = NSMenuItem(title: "📌 指定 Dock 栏显示实例 (\(store.dockVisibleInstanceIDs.count))", action: nil, keyEquivalent: "")
        let dockSubmenu = NSMenu()
        for item in store.instances {
            let pinItem = makeItem(title: Self.instanceMenuTitle(for: item, store: store), action: #selector(toggleDockPinAction(_:)), object: item.id)
            pinItem.state = store.isShownInDock(item) ? .on : .off
            dockSubmenu.addItem(pinItem)
        }
        dockParent.submenu = dockSubmenu
        menu.addItem(dockParent)

        menu.addItem(.separator())
        menu.addItem(makeItem(title: "打开主窗口", action: #selector(openMainWindowAction)))
        menu.addItem(makeItem(title: "检查软件更新…", action: #selector(checkForUpdatesAction)))
        menu.addItem(makeItem(title: "退出管理器", action: #selector(quitAppAction), keyEquivalent: "q"))
    }

    private func makeItem(title: String, action: Selector, object: Any? = nil, keyEquivalent: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.representedObject = object
        menuItem.target = self
        return menuItem
    }

    private func stateEmoji(running: Bool, state: TaskRunState) -> String {
        guard running else { return "⏹" }
        switch state {
        case .runningTask: return "⚡"
        case .needsAttention: return "🔔"
        case .stalled: return "⚠️"
        case .error: return "❌"
        case .idle, .stopped: return "🟢"
        }
    }

    @objc func openInstanceAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = store?.instances.first(where: { $0.id == id }) else { return }
        store?.open(item)
    }

    @objc func toggleDockPinAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = store?.instances.first(where: { $0.id == id }) else { return }
        store?.toggleShowInDock(item)
    }

    @objc func collapseAllAction() { store?.collapseAllToMonitorWall() }
    @objc func quitAllClonesAction() { store?.quitAllClones() }

    @objc func openMainWindowAction() {
        for window in NSApp.windows where !(window is NSPanel) && !window.isSheet && window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if let handler = store?.openMainWindowHandler {
            handler()
        } else {
            NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func checkForUpdatesAction() {
        NSApp.activate(ignoringOtherApps: true)
        updaterController?.checkForUpdates(nil)
    }

    @objc func quitAppAction() { NSApp.terminate(nil) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let store = InstanceStore.current else { return nil }
        let menu = NSMenu()

        let pinHeader = NSMenuItem(title: "📌 勾选要在 Dock 栏显示的实例 (可多选)", action: nil, keyEquivalent: "")
        pinHeader.isEnabled = false
        menu.addItem(pinHeader)

        for item in store.instances {
            let pinItem = NSMenuItem(
                title: StatusBarController.instanceMenuTitle(for: item, store: store),
                action: #selector(StatusBarController.toggleDockPinAction(_:)),
                keyEquivalent: ""
            )
            pinItem.state = store.isShownInDock(item) ? .on : .off
            pinItem.representedObject = item.id
            pinItem.target = StatusBarController.shared
            menu.addItem(pinItem)
        }

        menu.addItem(.separator())
        let openHeader = NSMenuItem(title: "🚀 快速打开 / 切换实例", action: nil, keyEquivalent: "")
        openHeader.isEnabled = false
        menu.addItem(openHeader)

        for item in store.instances {
            let act = store.activity(for: item)
            let openItem = NSMenuItem(
                title: "\(item.running ? "🟢" : "⏹") \(StatusBarController.instanceMenuTitle(for: item, store: store)) · \(act.state.label)",
                action: #selector(StatusBarController.openInstanceAction(_:)),
                keyEquivalent: ""
            )
            openItem.representedObject = item.id
            openItem.target = StatusBarController.shared
            menu.addItem(openItem)
        }
        return menu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        for window in sender.windows where !(window is NSPanel) && !window.isSheet && window.canBecomeMain {
            if let sheet = window.attachedSheet { sheet.makeKeyAndOrderFront(nil) } else { window.makeKeyAndOrderFront(nil) }
            sender.activate(ignoringOtherApps: true)
            return true
        }
        NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
        sender.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct AntigravityMultiplexerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = InstanceStore()

    private static let updaterDelegate = MultiplexerUpdaterDelegate()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: updaterDelegate,
        userDriverDelegate: nil
    )

    var body: some Scene {
        Window("Aether Antigravity Multiplexer", id: "main") {
            MainView(store: store, updaterController: updaterController)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("显示主窗口") {
                    Task { @MainActor in StatusBarController.shared.openMainWindowAction() }
                }
                .keyboardShortcut("0")
            }
            CommandGroup(after: .appInfo) {
                Button("检查软件更新…") { updaterController.checkForUpdates(nil) }
            }
        }
    }
}
