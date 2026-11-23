import SwiftUI

struct BentoInstanceCard: View {
    let item: ManagedInstance
    @ObservedObject var store: InstanceStore
    let palette: StudioPalette
    let onUpgrade: () -> Void
    let onClearWorkspace: () -> Void
    let onDestroy: () -> Void

    @State private var isHovered = false
    @State private var isEditingAlias = false
    @State private var aliasDraft = ""
    @State private var copiedEmail = false
    @State private var showMorePopover = false
    @State private var dotPulsing = false
    @State private var progressSliding = false
    @FocusState private var aliasFieldFocused: Bool

    private var activity: InstanceActivity { store.activity(for: item) }
    private var account: InstanceAccountInfo { store.account(for: item) }
    private var dupCount: Int { store.duplicateCount(for: item) }
    private var metric: InstanceResourceMetric { store.metric(for: item) }
    private var diskUsage: InstanceDiskUsage { store.diskUsage(for: item) }
    private var durationText: String? { store.runningDuration(for: item) }

    private var canUpgradeInstance: Bool {
        !item.isOriginal && !store.sourceVersion.isEmpty && store.sourceVersion != "—" &&
        item.version.compare(store.sourceVersion, options: .numeric) == .orderedAscending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            zone1Header
            zone2Viewport
            zone3Footer
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovered ? palette.cardHoverBackground : palette.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [palette.sheenColor, .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(false)
        )
        .overlay(borderGlowOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: cardShadowColor, radius: isHovered ? 16 : 9, y: isHovered ? 6 : 3)
        .scaleEffect(isHovered ? 1.006 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
        .onAppear { updatePulseState() }
        .onChange(of: item.running) { _ in updatePulseState() }
        .onChange(of: activity.state) { _ in updatePulseState() }
    }

    // MARK: - Zone 1 (2-Row Header)

    private var zone1Header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 7) {
                statusPulseDot.padding(.top, 5)
                indexBadge.padding(.top, 1)

                if isEditingAlias {
                    inlineAliasEditor
                } else {
                    HStack(alignment: .top, spacing: 4) {
                        Text(store.displayTitle(for: item))
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(palette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .help(item.name)

                        Button { beginAliasEdit() } label: {
                            Text("✎")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(palette.secondaryText)
                                .frame(width: 20, height: 20)
                                .background(palette.pillBackground)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .opacity(isHovered ? 1 : 0)
                        .help("修改实例别名")
                    }
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    if canUpgradeInstance {
                        Button(action: onUpgrade) {
                            Text("↑ v\(store.sourceVersion)")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .studioCapsule(background: palette.accentAmber, height: 22)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.busy || !store.canUpgrade)
                    }

                    if store.isShownInDock(item) {
                        Button { store.toggleShowInDock(item) } label: {
                            Text("📌 Dock")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(palette.accentPurple)
                                .studioCapsule(background: palette.accentPurple.opacity(palette.isDark ? 0.18 : 0.11), border: palette.accentPurple.opacity(0.35), height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("点击从 Dock 栏移除")
                    }

                    Button { showMorePopover.toggle() } label: {
                        Text("⋯")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.secondaryText)
                            .frame(width: 24, height: 22)
                            .background(palette.pillBackground)
                            .overlay(Capsule().strokeBorder(palette.pillBorder, lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMorePopover, arrowEdge: .bottom) { moreActionsPopover }
                }
            }

            accountIdentityStrip
        }
    }

    private var statusPulseDot: some View {
        ZStack {
            if item.running {
                Circle()
                    .fill(stateColor.opacity(0.36))
                    .frame(width: 12, height: 12)
                    .scaleEffect(dotPulsing ? 1.45 : 0.9)
                    .opacity(dotPulsing ? 0.1 : 0.65)
            }
            Circle().fill(stateColor).frame(width: 7.5, height: 7.5)
        }
        .frame(width: 12, height: 12)
    }

    @ViewBuilder
    private var indexBadge: some View {
        if item.isOriginal {
            Text(item.badgeLabel)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 7).frame(height: 20)
                .background(palette.mainBadgeGradient)
                .clipShape(Capsule())
        } else {
            Text(item.badgeLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
                .studioCapsule(background: palette.pillBackground, border: palette.pillBorder, height: 20)
        }
    }

    private var inlineAliasEditor: some View {
        HStack(spacing: 4) {
            TextField("输入别名", text: $aliasDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .frame(minWidth: 94, maxWidth: 160)
                .focused($aliasFieldFocused)
                .onSubmit { commitAliasEdit() }
                .onExitCommand { isEditingAlias = false }
            Button("存") { commitAliasEdit() }.buttonStyle(.borderedProminent).controlSize(.mini)
            Button("✕") { isEditingAlias = false }.buttonStyle(.bordered).controlSize(.mini)
        }
    }

    private var accountIdentityStrip: some View {
        HStack(spacing: 6) {
            if account.isLoggedIn {
                Button {
                    store.copyAccountEmail(for: item)
                    withAnimation(.easeOut(duration: 0.15)) { copiedEmail = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.2)) { copiedEmail = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(copiedEmail ? "✓" : "👤").font(.system(size: 10.5))
                        Text(copiedEmail ? "已复制邮箱" : account.displayEmail(masked: store.maskAccountEmails))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .lineLimit(1).truncationMode(.middle)
                    }
                    .foregroundStyle(copiedEmail ? palette.accentGreen : palette.primaryText.opacity(0.88))
                    .studioCapsule(background: palette.pillBackground, border: copiedEmail ? palette.accentGreen.opacity(0.45) : palette.pillBorder, height: 22)
                }
                .buttonStyle(.plain)
                .help("点击复制账号邮箱")

                if dupCount > 1 {
                    Text("同号 ×\(dupCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(palette.accentAmber)
                        .studioCapsule(background: palette.accentAmber.opacity(palette.isDark ? 0.16 : 0.12), border: palette.accentAmber.opacity(0.38), height: 20)
                        .help("共有 \(dupCount) 个实例登录了同一账号")
                }
            } else {
                Text("○ 未登录账号")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accentAmber)
                    .studioCapsule(background: palette.accentAmber.opacity(palette.isDark ? 0.14 : 0.10), border: palette.accentAmber.opacity(0.36), height: 22)
            }

            Spacer(minLength: 4)

            if store.globalHotkeysEnabled && item.index <= 9 {
                Text("⌥\(item.index)")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.mutedText)
                    .padding(.horizontal, 6).frame(height: 20)
                    .background(palette.pillBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
    }

    // MARK: - Zone 2 (16:10 Studio Monitor Viewport)

    private var zone2Viewport: some View {
        Group {
            if item.running { runningViewport } else { stoppedDotMatrixViewport }
        }
        .frame(height: 142)
        .studioSurface(
            background: .clear,
            border: (activity.state.isActiveTask && item.running) ? palette.accentCyan.opacity(0.34) : palette.cardBorder,
            radius: 11
        )
    }

    private var runningViewport: some View {
        ZStack {
            LinearGradient(colors: [palette.viewportRunningTop, palette.viewportRunningBottom], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(stateColor).frame(width: 6, height: 6)
                        Text(runningCapsuleTitle).font(.system(size: 10, weight: .semibold)).foregroundStyle(palette.primaryText)
                    }
                    .studioCapsule(background: palette.pillBackground, border: stateColor.opacity(0.35), height: 19)

                    Spacer(minLength: 4)

                    HStack(spacing: 4) {
                        Text(metric.compactLabel)
                        if let durationText { Text("· ⏱ \(durationText)") }
                    }
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.secondaryText)
                    .studioCapsule(background: palette.pillBackground, height: 19)
                }

                syntheticLiveTerminal
            }
            .padding(9)

            if isHovered {
                ZStack {
                    Color.black.opacity(palette.isDark ? 0.36 : 0.16)
                    HStack(spacing: 8) {
                        Button(item.isHidden ? "恢复窗口" : "调出实例") { store.open(item) }
                            .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .primary, compact: true))
                        if !item.isHidden {
                            Button("收起") { hideWindow() }
                                .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
                        }
                    }
                }
                .transition(.opacity.animation(.easeOut(duration: 0.15)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.open(item) }
    }

    private var syntheticLiveTerminal: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: 0xFF5F57)).frame(width: 6.5, height: 6.5)
                    Circle().fill(Color(hex: 0xFEBC2E)).frame(width: 6.5, height: 6.5)
                    Circle().fill(Color(hex: 0x28C840)).frame(width: 6.5, height: 6.5)
                }
                Text(activity.workspace.isEmpty ? item.profile : activity.workspace)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                if activity.stepIndex > 0 {
                    Text("Step #\(activity.stepIndex)")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(palette.mutedText)
                }
            }
            .padding(.horizontal, 8).frame(height: 22)
            .background(palette.terminalHeaderBackground)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 7) {
                    RoundedRectangle(cornerRadius: 1.5).fill(stateColor).frame(width: 3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(terminalStateTag)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(stateColor)
                        Text(activity.currentAction)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(palette.primaryText.opacity(0.92))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if activity.state.isActiveTask {
                    GeometryReader { geo in
                        let w = max(geo.size.width * 0.34, 38)
                        ZStack(alignment: .leading) {
                            Capsule().fill(stateColor.opacity(0.16))
                            Capsule()
                                .fill(LinearGradient(colors: [stateColor.opacity(0.5), stateColor], startPoint: .leading, endPoint: .trailing))
                                .frame(width: w)
                                .offset(x: progressSliding ? max(0, geo.size.width - w) : 0)
                        }
                    }
                    .frame(height: 3.5)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.terminalBoxBackground)
        }
        .studioSurface(background: .clear, border: palette.terminalBoxBorder, radius: 8)
    }

    private var stoppedDotMatrixViewport: some View {
        ZStack {
            palette.viewportStoppedBackground
            Canvas { context, size in
                var y: CGFloat = 10
                while y < size.height {
                    var x: CGFloat = 10
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(palette.dotMatrixColor))
                        x += 14
                    }
                    y += 14
                }
            }
            RadialGradient(
                colors: [(item.isOriginal ? palette.accentPurple : palette.accentBlue).opacity(palette.isDark ? 0.15 : 0.09), .clear],
                center: .center, startRadius: 6, endRadius: 115
            )
            VStack {
                HStack {
                    Text("未启动")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .studioCapsule(background: palette.pillBackground, height: 19)
                    Spacer()
                    Text("v\(item.version)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(palette.mutedText)
                        .studioCapsule(background: palette.pillBackground, height: 19)
                }
                Spacer()
                Button { store.open(item) } label: {
                    Text(account.isLoggedIn ? "▶ 就绪" : "▶ 打开登录")
                }
                .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: isHovered ? .primary : .secondary, compact: true))
                Spacer()
            }
            .padding(10)
        }
        .contentShape(Rectangle())
        .onTapGesture { store.open(item) }
    }

    // MARK: - Zone 3 (Footer) & Action Popover

    private var zone3Footer: some View {
        HStack(spacing: 6) {
            Image(systemName: activity.state.symbol)
                .font(.system(size: 11))
                .foregroundStyle(item.running ? stateColor : palette.mutedText)
            Text(activity.currentAction)
                .font(.system(size: 11))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            if !activity.lastUpdatedLabel.isEmpty {
                Text(activity.lastUpdatedLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(palette.mutedText)
            }
            Text("💾 \(diskUsage.formattedTotalData)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.mutedText)
        }
        .frame(height: 34)
    }

    private var moreActionsPopover: some View {
        VStack(alignment: .leading, spacing: 2) {
            if account.isLoggedIn {
                menuItem("复制登录账号邮箱", systemImage: "doc.on.doc") { store.copyAccountEmail(for: item) }
            }
            menuItem("修改实例别名…", systemImage: "pencil") { beginAliasEdit() }
            menuItem(store.isShownInDock(item) ? "📌 从 Dock 栏移除此实例" : "📌 在 Dock 栏显示此实例", systemImage: "pin") {
                store.toggleShowInDock(item)
            }
            Divider().padding(.vertical, 4)
            menuItem("在访达中显示应用", systemImage: "folder") { store.reveal(item) }
            menuItem("打开独立工作空间", systemImage: "internaldrive") { store.revealProfile(item) }
            menuItem("查看运行日志", systemImage: "doc.text.magnifyingglass") { store.showLogs(item) }
            if item.running {
                menuItem("安全退出实例", systemImage: "power") { store.quit(item) }
            }
            if !item.isOriginal {
                Divider().padding(.vertical, 4)
                menuItem("清空工作空间…", systemImage: "eraser", disabled: item.running || store.busy) { onClearWorkspace() }
                menuItem("销毁实例…", systemImage: "trash", destructive: true, disabled: item.running || store.busy) { onDestroy() }
            }
        }
        .padding(8).frame(width: 220)
    }

    private func menuItem(_ title: String, systemImage: String, destructive: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            showMorePopover = false
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 11.5)).frame(width: 15)
                Text(title).font(.system(size: 12))
                Spacer()
            }
            .foregroundStyle(destructive ? palette.accentRed : palette.primaryText)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.45 : 1)
    }

    // MARK: - Helpers

    private var stateColor: Color {
        guard item.running else { return palette.mutedText }
        switch activity.state {
        case .stopped: return palette.mutedText
        case .idle: return palette.accentGreen
        case .runningTask: return palette.accentCyan
        case .stalled, .needsAttention: return palette.accentAmber
        case .error: return palette.accentRed
        }
    }

    private var runningCapsuleTitle: String {
        let base: String
        switch activity.state {
        case .idle: base = "空闲就绪"
        case .runningTask: base = "任务执行中"
        case .needsAttention: base = "等待确认"
        default: base = activity.state.label
        }
        return item.isHidden ? "\(base) · 后台实时" : base
    }

    private var terminalStateTag: String {
        switch activity.state {
        case .runningTask: return "AGENT EXECUTING TASK"
        case .needsAttention, .stalled: return "WAITING FOR INPUT"
        case .error: return "AGENT ERROR"
        case .idle, .stopped: return "AGENT READY"
        }
    }

    private var borderGlowOverlay: some View {
        let color: Color = (activity.state.isActiveTask && item.running) ? palette.activeTaskGlow : (item.isOriginal ? palette.mainGlow : (isHovered ? palette.cardHoverBorder : palette.cardBorder))
        let width: CGFloat = (activity.state.isActiveTask && item.running) || item.isOriginal ? 1.35 : 1.0
        return RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(color, lineWidth: width).allowsHitTesting(false)
    }

    private var cardShadowColor: Color {
        if activity.state.isActiveTask && item.running { return palette.activeTaskGlow.opacity(0.28) }
        return item.isOriginal ? palette.mainGlow.opacity(0.22) : palette.cardShadow
    }

    private func beginAliasEdit() {
        aliasDraft = store.alias(for: item)
        isEditingAlias = true
        DispatchQueue.main.async { aliasFieldFocused = true }
    }

    private func commitAliasEdit() {
        store.setAlias(aliasDraft, for: item)
        isEditingAlias = false
    }

    private func hideWindow() { store.hideInstance(item) }

    private func updatePulseState() {
        dotPulsing = false
        progressSliding = false
        if item.running {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { dotPulsing = true }
        }
        if item.running && activity.state.isActiveTask {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { progressSliding = true }
        }
    }
}
