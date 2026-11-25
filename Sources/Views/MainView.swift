import AppKit
import Sparkle
import SwiftUI

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

struct MainView: View {
    @ObservedObject var store: InstanceStore
    let updaterController: SPUStandardUpdaterController

    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.openWindow) private var openWindow

    @State private var selectedFilter: InstanceFilter = .all
    @State private var searchText = ""
    @State private var showSettingsPopover = false
    @State private var showCreateSheet = false
    @State private var upgradeRequest: UpgradeRequest?
    @State private var pendingClear: ManagedInstance?
    @State private var pendingDestroy: ManagedInstance?
    @State private var consoleExpanded = true
    @State private var autoCheckUpdates = true

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2"
    }

    private var palette: StudioPalette {
        StudioPalette.resolve(theme: store.appTheme, systemScheme: systemScheme)
    }

    private var filteredInstances: [ManagedInstance] {
        let upgradableIDs = Set(store.pendingUpgrades.map(\.id))
        let byFilter = store.instances.filter { item in
            switch selectedFilter {
            case .all: return true
            case .running: return item.running
            case .unauthenticated: return !store.account(for: item).isLoggedIn
            case .upgradable: return upgradableIDs.contains(item.id)
            }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return byFilter }
        return byFilter.filter { item in
            item.name.lowercased().contains(query) ||
            store.alias(for: item).lowercased().contains(query) ||
            store.displayTitle(for: item).lowercased().contains(query) ||
            store.account(for: item).email.lowercased().contains(query) ||
            store.activity(for: item).workspace.lowercased().contains(query) ||
            item.profile.lowercased().contains(query) ||
            item.badgeLabel.lowercased().contains(query) ||
            String(item.index) == query
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                palette.canvasBackground
                RadialGradient(colors: [palette.canvasAuraPrimary, .clear], center: .topLeading, startRadius: 20, endRadius: 620)
                RadialGradient(colors: [palette.canvasAuraSecondary, .clear], center: .bottomTrailing, startRadius: 20, endRadius: 520)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topStudioHeader
                filterSearchMaskBar

                ScrollView {
                    if filteredInstances.isEmpty {
                        emptyStateView
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 295, maximum: 390), spacing: 16)], spacing: 16) {
                            ForEach(filteredInstances) { item in
                                BentoInstanceCard(
                                    item: item,
                                    store: store,
                                    palette: palette,
                                    onUpgrade: { upgradeRequest = UpgradeRequest(instances: [item]) },
                                    onClearWorkspace: { pendingClear = item },
                                    onDestroy: { pendingDestroy = item }
                                )
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                        .padding(.bottom, (store.busy || !store.output.isEmpty) ? (consoleExpanded ? 210 : 68) : 24)
                    }
                }
            }

            if store.busy || !store.output.isEmpty {
                operationConsoleDrawer.transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 920, minHeight: 620)
        .background(MainWindowAccessor())
        .preferredColorScheme(store.appTheme.colorScheme)
        .onAppear {
            store.openMainWindowHandler = { [openWindow] in
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            StatusBarController.shared.bind(store: store, updaterController: updaterController)
            autoCheckUpdates = updaterController.updater.automaticallyChecksForUpdates
            store.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMainWindowRequested)) { _ in
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCreateInstanceRequested)) { _ in showCreateSheet = true }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in store.refreshRunningStates() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in store.refreshRunningStates() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in store.refreshRunningStates() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didHideApplicationNotification)) { _ in store.refreshRunningStates() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnhideApplicationNotification)) { _ in store.refreshRunningStates() }
        .onReceive(Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()) { _ in store.periodicTick() }
        .sheet(isPresented: $showCreateSheet) { CreateInstanceSheet(store: store, palette: palette) }
        .sheet(item: $upgradeRequest) { req in
            FastUpgradeSheet(store: store, instances: req.instances, palette: palette) { upgradeRequest = nil }
        }
        .sheet(item: $pendingClear) { item in
            DangerConfirmationSheet(mode: .clearWorkspace, item: item, busy: store.busy, palette: palette) { store.clearWorkspace(item) }
        }
        .sheet(item: $pendingDestroy) { item in
            DangerConfirmationSheet(mode: .destroyInstance, item: item, busy: store.busy, palette: palette) { store.destroy(item) }
        }
    }

    // MARK: - Top Studio Header

    private var topStudioHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 11) {
                if let icon = NSApp?.applicationIconImage {
                    Image(nsImage: icon).resizable().interpolation(.high)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text("Aether Antigravity Multiplexer").font(.system(size: 16.5, weight: .bold)).foregroundStyle(palette.primaryText)
                        Text("v\(appVersion)")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.accentPurple)
                            .studioCapsule(background: palette.accentPurple.opacity(palette.isDark ? 0.18 : 0.10), height: 19)
                        Text("v\(store.sourceVersion) · \(store.compatibility)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(store.canUpgrade ? palette.accentGreen : palette.accentAmber)
                            .studioCapsule(background: (store.canUpgrade ? palette.accentGreen : palette.accentAmber).opacity(palette.isDark ? 0.16 : 0.10), height: 19)
                    }
                    Text("\(store.runningCount) / \(store.instances.count) 运行中 · 已登录 \(store.loggedInCount) 个实例 (\(store.uniqueAccountCount) 个独立账号)")
                        .font(.system(size: 11.5)).foregroundStyle(palette.secondaryText)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { store.appTheme = palette.isDark ? .light : .dark }
                } label: {
                    Text(palette.isDark ? "☀️ 浅色" : "🌙 深色")
                }
                .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))

                if !store.pendingUpgrades.isEmpty {
                    Button("升级全部 (\(store.pendingUpgrades.count))") { upgradeRequest = UpgradeRequest(instances: store.pendingUpgrades) }
                        .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
                        .disabled(store.busy || !store.canUpgrade)
                }
                if store.runningCount > 0 {
                    Button("收起全部 (\(store.visibleWindowCount))") { store.collapseAllToMonitorWall() }
                        .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
                }
                if store.runningCloneCount > 0 {
                    Button("退出分身 (\(store.runningCloneCount))") { store.quitAllClones() }
                        .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
                }

                Button("⚙️ 设置") {
                    autoCheckUpdates = updaterController.updater.automaticallyChecksForUpdates
                    showSettingsPopover.toggle()
                }
                .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
                .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) { settingsPopoverContent }

                Button("+ 创建实例") { showCreateSheet = true }
                    .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .primary, compact: true))
            }
        }
        .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 12)
    }

    // MARK: - Settings Popover

    private var settingsPopoverContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("🎨 外观主题风格").font(.system(size: 12.5, weight: .bold)).foregroundStyle(palette.primaryText)
                HStack(spacing: 6) {
                    ForEach(AppTheme.allCases) { theme in
                        let selected = store.appTheme == theme
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { store.appTheme = theme }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: theme.symbol).font(.system(size: 10.5))
                                Text(theme.title).font(.system(size: 11.5, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity).frame(height: 28)
                            .foregroundStyle(selected ? .white : palette.primaryText)
                            .background(selected ? AnyShapeStyle(palette.primaryGradient) : AnyShapeStyle(palette.pillBackground))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(selected ? .clear : palette.pillBorder, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("📌 指定在 Dock 栏显示的实例 (可多选)").font(.system(size: 12.5, weight: .bold)).foregroundStyle(palette.primaryText)
                HStack(spacing: 6) {
                    Button("全选") { store.setBatchShowInDock(Set(store.instances.map(\.id))) }
                        .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
                    Button("仅主实例") { store.setBatchShowInDock(Set(store.instances.filter(\.isOriginal).map(\.id))) }
                        .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
                    Button("全不选") { store.setBatchShowInDock([]) }
                        .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(store.instances) { item in
                            let pinned = store.isShownInDock(item)
                            let acct = store.account(for: item)
                            Button { store.toggleShowInDock(item) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: pinned ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12)).foregroundStyle(pinned ? palette.accentPurple : palette.mutedText)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(String(format: "#%02d", item.index)) \(store.displayTitle(for: item))")
                                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.primaryText).lineLimit(1)
                                        Text(acct.isLoggedIn ? acct.displayEmail(masked: store.maskAccountEmails) : "未登录")
                                            .font(.system(size: 9.5, design: .monospaced)).foregroundStyle(palette.mutedText).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .studioSurface(
                                    background: pinned ? palette.accentPurple.opacity(palette.isDark ? 0.16 : 0.09) : palette.pillBackground,
                                    border: pinned ? palette.accentPurple.opacity(0.42) : palette.pillBorder,
                                    radius: 8
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 168)
            }

            Divider()

            Toggle("全局快捷键 (⌥1 ~ ⌥9)", isOn: $store.globalHotkeysEnabled).font(.system(size: 12.5, weight: .medium))
            Toggle("后台任务完成通知", isOn: $store.notificationsEnabled).font(.system(size: 12.5, weight: .medium))

            HStack {
                Toggle("Sparkle 自动更新", isOn: Binding(
                    get: { autoCheckUpdates },
                    set: { autoCheckUpdates = $0; updaterController.updater.automaticallyChecksForUpdates = $0 }
                ))
                .font(.system(size: 12.5, weight: .medium))
                Spacer()
                Button("检查更新…") {
                    showSettingsPopover = false
                    updaterController.checkForUpdates(nil)
                }
                .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
            }
        }
        .padding(16).frame(width: 410)
    }

    // MARK: - Filter + Search + Privacy Mask Bar

    private var filterSearchMaskBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(InstanceFilter.allCases) { filter in
                    let selected = selectedFilter == filter
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selectedFilter = filter }
                    } label: {
                        HStack(spacing: 4) {
                            Text(filter.title).font(.system(size: 11.5, weight: .semibold))
                            Text("\(filterCount(filter))")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(selected ? .white.opacity(0.9) : palette.mutedText)
                        }
                        .foregroundStyle(selected ? .white : palette.secondaryText)
                        .padding(.horizontal, 10).frame(height: 27)
                        .background(selected ? AnyShapeStyle(palette.primaryGradient) : AnyShapeStyle(Color.clear))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3).studioSurface(background: palette.pillBackground, border: palette.pillBorder, radius: 9)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11.5)).foregroundStyle(palette.mutedText)
                TextField("搜索实例、登录邮箱、别名或项目…", text: $searchText).textFieldStyle(.plain).font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 11.5)).foregroundStyle(palette.mutedText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).frame(height: 31)
            .studioSurface(background: palette.pillBackground, border: palette.pillBorder, radius: 9)

            Button { store.maskAccountEmails.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: store.maskAccountEmails ? "eye" : "eye.slash").font(.system(size: 11))
                    Text(store.maskAccountEmails ? "显示完整邮箱" : "隐藏邮箱")
                }
            }
            .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary))
        }
        .padding(.horizontal, 22).padding(.bottom, 12)
    }

    private func filterCount(_ filter: InstanceFilter) -> Int {
        switch filter {
        case .all: return store.instances.count
        case .running: return store.runningCount
        case .unauthenticated: return store.instances.filter { !store.account(for: $0).isLoggedIn }.count
        case .upgradable: return store.pendingUpgrades.count
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2").font(.system(size: 28)).foregroundStyle(palette.mutedText)
            Text(store.instances.isEmpty ? "未检测到 Antigravity 实例" : "没有符合当前筛选或搜索条件的实例")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.primaryText)
            Text(store.instances.isEmpty ? "请确认 /Applications/Antigravity.app 已安装或点击右上角创建新实例。" : "尝试切换筛选标签或清空搜索关键词。")
                .font(.system(size: 12)).foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 280).padding(24)
    }

    private var operationConsoleDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if store.busy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: store.error == nil ? "terminal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12)).foregroundStyle(store.error == nil ? palette.accentCyan : palette.accentRed)
                }
                Text("操作执行记录").font(.system(size: 12, weight: .bold)).foregroundStyle(palette.primaryText)
                if !store.operationStage.isEmpty {
                    Text(store.operationStage).font(.system(size: 11.5)).foregroundStyle(palette.secondaryText).lineLimit(1)
                }
                Spacer()
                if let progress = store.operationProgress {
                    ProgressView(value: progress).progressViewStyle(.linear).frame(width: 120)
                    Text("\(Int(progress * 100))%").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(palette.accentCyan)
                }
                Button(consoleExpanded ? "收起日志" : "展开日志") {
                    withAnimation(.easeOut(duration: 0.16)) { consoleExpanded.toggle() }
                }
                .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .subtle, compact: true))
                if !store.busy {
                    Button("✕") { store.clearConsoleOutput() }
                        .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .subtle, compact: true))
                }
            }
            .padding(.horizontal, 14).frame(height: 40)

            if consoleExpanded {
                Rectangle().fill(palette.divider).frame(height: 1)
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(store.output.isEmpty ? "正在执行操作…" : store.output)
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(palette.secondaryText)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .id("consoleEnd")
                    }
                    .frame(height: 132)
                    .onChange(of: store.output) { _ in
                        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo("consoleEnd", anchor: .bottom) }
                    }
                }
            }
        }
        .studioSurface(background: palette.cardBackground, border: store.busy ? palette.accentCyan.opacity(0.45) : palette.cardBorder, radius: 14)
        .shadow(color: palette.cardShadow, radius: 14, y: 4)
        .padding(.horizontal, 22).padding(.bottom, 12)
    }
}
