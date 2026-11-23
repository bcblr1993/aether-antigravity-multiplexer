import SwiftUI

struct CreateInstanceSheet: View {
    @ObservedObject var store: InstanceStore
    let palette: StudioPalette
    @Environment(\.dismiss) private var dismiss

    @State private var initialAlias = ""
    @State private var destination = URL(fileURLWithPath: "/Applications")

    private var nextIndex: Int { store.nextAvailableIndex }
    private var ordinal: String { InstanceStore.ordinalName(nextIndex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.mainBadgeGradient)
                        .frame(width: 44, height: 44)
                    Text("#\(String(format: "%02d", nextIndex))")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("创建 Antigravity \(ordinal)")
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(palette.primaryText)
                    Text("从本机官方 Antigravity.app 克隆并隔离账号、凭据与回调协议。")
                        .font(.system(size: 12)).foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("实例别名（可选）").font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.secondaryText)
                TextField("例如：主力账号 / 备用工作区", text: $initialAlias).textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                detailRow("实例名称", "Antigravity \(ordinal)")
                Divider().opacity(0.4)
                detailRow("独立数据目录", "~/.gemini-\(max(nextIndex - 1, 1))", monospaced: true)
                Divider().opacity(0.4)
                detailRow("专属回调协议", "antigravity-\(nextIndex)://", monospaced: true)
                Divider().opacity(0.4)
                detailRow("官方源版本", "v\(store.sourceVersion)", monospaced: true)
            }
            .padding(14)
            .studioSurface(background: palette.pillBackground, border: palette.pillBorder, radius: 12)

            HStack {
                Text("安装位置").font(.system(size: 12.5, weight: .medium)).foregroundStyle(palette.secondaryText)
                Spacer()
                Picker("", selection: $destination) {
                    Text("系统应用程序 (/Applications)").tag(URL(fileURLWithPath: "/Applications"))
                    Text("个人应用程序 (~/Applications)").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))
                }
                .labelsHidden().frame(width: 260)
            }

            if !store.canUpgrade {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("本机官方版本状态为「\(store.compatibility)」，暂不可克隆新实例。").font(.system(size: 11.5))
                }
                .foregroundStyle(palette.accentAmber)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("创建并启动") {
                    store.createInstance(initialAlias: initialAlias.trimmingCharacters(in: .whitespacesAndNewlines), destination: destination)
                    dismiss()
                }
                .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .primary))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(store.busy || !store.canUpgrade)
            }
        }
        .padding(24).frame(width: 500).background(palette.cardBackground)
    }

    private func detailRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(palette.secondaryText)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold, design: monospaced ? .monospaced : .default)).foregroundStyle(palette.primaryText)
        }
    }
}

struct FastUpgradeSheet: View {
    @ObservedObject var store: InstanceStore
    let instances: [ManagedInstance]
    let palette: StudioPalette
    let onDismiss: () -> Void

    @State private var startedUpgrade = false

    private var relevantNotes: [SourceReleaseNotes] {
        SourceReleaseNotes.bundled.filter { note in
            note.version.compare(store.sourceVersion, options: .numeric) != .orderedDescending &&
            instances.contains { $0.version.compare(note.version, options: .numeric) == .orderedAscending }
        }.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(palette.accentBlue.opacity(0.16)).frame(width: 42, height: 42)
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 20)).foregroundStyle(palette.accentBlue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(instances.count == 1 ? "升级实例至 v\(store.sourceVersion)" : "批量极速升级 (\(instances.count) 个副本)")
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(palette.primaryText)
                    Text("直接以本机官方 v\(store.sourceVersion) 无损原子替换，保留独立账号与数据目录")
                        .font(.system(size: 12)).foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }

            if startedUpgrade || store.busy { progressSection } else { reviewSection }
        }
        .padding(24).frame(width: 580).background(palette.cardBackground)
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("待升级实例版本对比").font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.secondaryText)
                        ForEach(instances) { item in
                            HStack {
                                Text(item.badgeLabel).font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(palette.accentPurple).frame(width: 54, alignment: .leading)
                                Text(store.displayTitle(for: item)).font(.system(size: 12.5, weight: .medium)).foregroundStyle(palette.primaryText)
                                Spacer()
                                Text("v\(item.version) → v\(store.sourceVersion)")
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced)).foregroundStyle(palette.accentAmber)
                            }
                        }
                    }
                    .padding(13).studioSurface(background: palette.pillBackground, border: palette.pillBorder, radius: 11)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bolt.fill").font(.system(size: 14)).foregroundStyle(palette.accentAmber).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("极速免备份升级模式").font(.system(size: 12.5, weight: .bold)).foregroundStyle(palette.primaryText)
                            Text("跳过冗余备份直接原子替换应用主体并重新应用凭据隔离，保留全部 ~/.gemini-* 数据与 OAuth 登录文件。")
                                .font(.system(size: 11.5)).foregroundStyle(palette.secondaryText)
                        }
                    }
                    .padding(12)
                    .studioSurface(background: palette.accentAmber.opacity(palette.isDark ? 0.12 : 0.08), border: palette.accentAmber.opacity(0.32), radius: 11)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("版本更新亮点").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(palette.primaryText)
                            Spacer()
                            Link("官方更新日志 ↗", destination: URL(string: "https://www.antigravity.google/docs/changelog?tab=hub")!).font(.system(size: 11.5))
                        }
                        if relevantNotes.isEmpty {
                            Text("当前版本区间暂无内置中文摘要，可点击右上角查看官方日志。").font(.system(size: 11.5)).foregroundStyle(palette.secondaryText)
                        } else {
                            ForEach(relevantNotes) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("v\(note.version)").font(.system(size: 11.5, weight: .bold, design: .monospaced)).foregroundStyle(palette.accentPurple)
                                    ForEach(note.highlights, id: \.self) { line in
                                        HStack(alignment: .top, spacing: 6) {
                                            Text("•").foregroundStyle(palette.accentPurple)
                                            Text(line).font(.system(size: 11.5)).foregroundStyle(palette.primaryText.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(13).studioSurface(background: palette.pillBackground, border: palette.pillBorder, radius: 11)
                }
            }
            .frame(maxHeight: 330)

            HStack(spacing: 10) {
                Spacer()
                Button("取消") { onDismiss() }
                    .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary)).keyboardShortcut(.cancelAction)
                Button("立即极速升级") {
                    startedUpgrade = true
                    store.upgrade(instances)
                }
                .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .primary))
                .disabled(store.busy || !store.canUpgrade)
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.busy ? (store.operationStage.isEmpty ? "正在执行极速升级…" : store.operationStage) : (store.error == nil ? "升级完成" : "升级失败"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.error == nil ? palette.primaryText : palette.accentRed)
                Spacer()
                if let progress = store.operationProgress {
                    Text("\(Int(progress * 100))%").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(palette.accentCyan)
                }
            }
            if let progress = store.operationProgress {
                ProgressView(value: progress).progressViewStyle(.linear)
            } else if store.busy {
                ProgressView().progressViewStyle(.linear)
            }
            ScrollView {
                Text(store.output.isEmpty ? "正在准备升级环境…" : store.output)
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(palette.secondaryText)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            .frame(height: 165)
            .studioSurface(background: palette.viewportStoppedBackground, border: palette.pillBorder, radius: 10)

            if let error = store.error {
                Text(error).font(.system(size: 11.5)).foregroundStyle(palette.accentRed)
            }
            HStack {
                Spacer()
                Button(store.busy ? "升级进行中…" : "完成") { onDismiss() }
                    .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .primary)).disabled(store.busy)
            }
        }
    }
}

enum DangerConfirmationMode { case clearWorkspace, destroyInstance }

struct DangerConfirmationSheet: View {
    let mode: DangerConfirmationMode
    let item: ManagedInstance
    let busy: Bool
    let palette: StudioPalette
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    private var isDestroy: Bool { mode == .destroyInstance }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill((isDestroy ? palette.accentRed : palette.accentAmber).opacity(0.16)).frame(width: 42, height: 42)
                    Image(systemName: isDestroy ? "trash.fill" : "eraser.line.dashed.fill")
                        .font(.system(size: 18)).foregroundStyle(isDestroy ? palette.accentRed : palette.accentAmber)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isDestroy ? "销毁 \(item.name)" : "清空 \(item.name) 的工作空间")
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(palette.primaryText)
                    Text(isDestroy ? "永久删除此副本的应用、数据目录与独立凭据文件" : "保留应用与独立登录文件，仅清空工作空间目录内容")
                        .font(.system(size: 12)).foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                if isDestroy {
                    Text(item.path.path)
                    Text(item.profile)
                    Text(item.userDataURL.path)
                    Text(item.logsURL.path)
                } else {
                    Text(item.profile)
                }
            }
            .font(.system(size: 11, design: .monospaced)).foregroundStyle(palette.secondaryText)
            .textSelection(.enabled).padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .studioSurface(background: palette.pillBackground, border: palette.pillBorder, radius: 10)

            if item.running {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("实例仍在运行中，请先安全退出实例后再执行此操作。")
                }
                .font(.system(size: 12, weight: .medium)).foregroundStyle(palette.accentAmber)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("请输入完整实例名称以确认：\(item.name)").font(.system(size: 12)).foregroundStyle(palette.secondaryText)
                    Spacer()
                    Button("一键填入名称") { confirmation = item.name }
                        .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary, compact: true))
                }
                TextField("输入 \(item.name)", text: $confirmation).textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .secondary)).keyboardShortcut(.cancelAction)
                Button(isDestroy ? "永久销毁" : "永久清空") {
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(StudioCapsuleButtonStyle(palette: palette, tone: .danger))
                .disabled(busy || item.running || confirmation != item.name)
            }
        }
        .padding(24).frame(width: 520).background(palette.cardBackground)
    }
}
