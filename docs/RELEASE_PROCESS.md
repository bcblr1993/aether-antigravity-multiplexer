# Aether Antigravity Multiplexer 版本发布与磁盘空间维护规范

本文档为 Aether Antigravity Multiplexer 的标准化发布与磁盘空间维护流程（SOP）。旨在规范版本打包、签名公证、发布交付，并**制度化清理每次编辑构建产物与临时文件，防止开发机与 CI 环境磁盘溢出**。

---

## 1. 产物生命周期与磁盘占用基线

在日常编码、构建调试与正式发版过程中，项目会生成不同类型的产物。若长期不加清理，磁盘将被数百兆至数吉字节的历史文件迅速蚕食：

| 产物名称 / 路径 | 产生环节 | 典型体积 | 生命周期与风险 | 清理策略 |
| :--- | :--- | :--- | :--- | :--- |
| **`.build/out` & `.build/arm64-*`** | `swift build` / `swift test` / `./build.sh` | 350 MB ~ 1 GB | 本地编译中间对象文件（`.o`、`.dSYM` 等），多次增量编译后持续膨胀 | 执行 `./scripts/clean.sh --deep` 或 `swift package clean` 安全释放 |
| **`dist/*-notary.zip`** | `./scripts/package-release.sh` | 3.2 MB / 次 | 仅用于向 Apple Notarytool 提交公证的临时包（**未经 stapler 装订**）。若留存不仅占空间，还极易导致发布资产误传 | 公证校验与装订完成后**即时自动删除** |
| **`dist/Aether-*-macos-arm64.zip`** | `./scripts/package-release.sh` | 3.2 MB / 版 | 装订了公证票据的正式分发包。历史版本累计数十个时占用超 150 MB | 仅保留当前最新版本的压缩包；其余历史包在 GitHub Releases 安全归档，本地予以清理 |
| **`Aether Antigravity Multiplexer.app`** | `./build.sh` (仓库根目录) | ~9.1 MB | 本地编辑测试生成的临时 App Bundle。已安装至 `/Applications` 或打包后属于冗余中间物 | 调试完成或发版后由 `./scripts/clean.sh` 自动清理 |
| **`Icon.icns`** | `scripts/build-icon.sh` | ~1.1 MB | 从 `Resources/AppIcon.png` 和 `make_icon.swift` 编译生成的临时图标 | 可随时通过脚本无损重新生成 |
| **`dist/notarization*.json`** | 提交公证过程中 | < 20 KB | 苹果公证返回的临时日志与 Request ID | 仅供校验使用，验证通过后自动销毁 |
| **`/tmp/aether-icon.*` / `/tmp/antigravity-*`** | 图标转换、Appcast 生成与采样分析 | 数十 KB ~ 数 MB | 系统级临时工作目录与日志 | 脚本退出时通过 `trap` 清理，异常中断时由清理脚本兜底扫描 |

---

## 2. 磁盘清理工具集 (`scripts/clean.sh`)

项目提供了专用的磁盘清理工具 [scripts/clean.sh](file:///Users/chenxu/IdeaProjects/aether-antigravity-multiplexer/scripts/clean.sh)，支持三种清理粒度：

### 2.1 标准日常清理（推荐在开发编辑后运行）
```bash
./scripts/clean.sh
```
- **执行内容**：
  1. 彻底删除 `dist/` 下所有临时公证包（`*-notary.zip`）与公证中间日志；
  2. 清理 `dist/` 中所有非当前版本的历史 `.zip` 归档；
  3. 清除根目录下临时构建的 `Aether Antigravity Multiplexer.app`；
  4. 扫描并清除系统 `/tmp` 下的图标与 Appcast 残留目录。
- **效果**：常态化节省 100~200 MB 空间，保持仓库与分发目录极简。

### 2.2 版本发布后清理（发布成功后必须运行）
```bash
./scripts/clean.sh --post-release
```
- **执行内容**：
  在发布到 GitHub Releases 之后调用，确保上载完成后本地立即卸载临时负载，仅保留当前版本轻量的 `appcast.xml`、`SHA256SUMS.txt` 与发布说明，杜绝跨版本磁盘堆积。

### 2.3 深度全量清理（磁盘紧张或重置环境时运行）
```bash
./scripts/clean.sh --deep
```
- **执行内容**：
  在标准清理基础上，进一步清理 Swift Package Manager 构建输出（`.build/out`）、中间二进制、`Icon.icns` 与所有本地 `dist/*.zip` 归档。
- **效果**：一次性回收 **500 MB ~ 1.5 GB** 磁盘空间。重新编译时会自动按需重建。

---

## 3. 标准化版本发布流程 (SOP)

发布新版本时，必须严格按照以下顺序执行。**严禁跳过发布后清理环节**：

### 步骤 1：确认代码变更与执行发版前强制测试门禁
发版前必须全量运行并通过测试套件（**8 大核心功能自动化门禁**，共 77+ 项测试）：
```bash
python3 -m unittest discover -s tests
```
> [!IMPORTANT]
> 项目构建脚本 `build.sh`、打包脚本 `scripts/package-release.sh` 与发布脚本 `scripts/publish-release.sh` 均已在流水线入口嵌入强制测试门禁；任一测试失败时将立即中断构建、打包与发布，杜绝带病发版。

#### 🛡️ 每次发版必须验证的 8 大核心功能门禁：
1. **分身托盘图标纯净隐藏（方案 A）** (`test_patch_asar_suppresses_clone_tray_icon`)：
   - 验证分身底层补丁彻底阻断 `tray_1.createTray`、`insertTrayMenuItem`、`updateTrayAgentCount` 与 `electron_1.Tray`，防止多开实例泛滥占满系统菜单栏。
2. **实例红叉关闭防退出与任务后台常驻** (`test_patch_asar_enforces_single_window`)：
   - 验证 `win.on('close')` 执行 `e.preventDefault()` 拦截物理销毁，联动 `win.hide()` 与 `electron_1.app.hide()`，保证多开实例在用户点击关闭时平滑隐藏入后台，Agent 任务零中断继续跑。
3. **实例窗口最小化一键解救与还原** (`test_patch_asar_enforces_single_window`, `test_ax_unminimize_loop_and_reopen_in_open_instance`)：
   - 验证 Electron 入口注入 `w.restore()` + `w.show()` + `w.focus()`，并在管理器 `openInstance` 中通过 Accessibility AX 原生解最小化循环（`AXMinimized = false`）与 AppleScript `reopen` 事件双轨保障点击瞬间恢复最小化窗口。
4. **监控台主窗口关闭拦截与收起自愈拉起** (`test_main_window_delegate_intercepts_close_without_destroying`, `test_bring_monitor_wall_fallback_to_open_main_window`, `test_app_delegate_reopen_fallback_to_open_main_window`)：
   - 验证 `MainWindowDelegate` 拦截监控台自身红叉销毁（转为 `orderOut` 隐藏），并在 `bringMonitorWallToFront` 与 `AppDelegate` 中注入 `openMainWindowHandler` / `openMainWindowRequested` 事件自愈重建机制，彻底消除点击「收起回监控台」后桌面变空的缺陷。
5. **升级引擎宿主防自杀与长稳会话守护** (`test_get_current_host_app_detection`, `test_stop_apps_preserves_current_host_app`)：
   - 验证 `get_current_host_app()` 沿进程树精准溯源宿主实例，升级 `stop_apps` 自动豁免宿主进程 `SIGTERM`，采用原子热重命名替换文件，彻底解决「升级时自己杀死自己」的严重问题。
6. **升级自由选择备份与免备份极速通道** (`test_cli_skip_backup_flag_parsing`, `test_skip_backup_bypasses_backup_completely`, `test_backup_enabled_creates_backup_and_stores_in_manifest`)：
   - 验证用户可选备份开关，`--skip-backup` 跳过耗时归档极速生效，清单安全存储版本元数据。
7. **全流程发光进度条与流式进度协议** (`test_upgrade_all_progress_monotonicity_and_completeness`, `test_swift_stream_progress_chunk_parsing_simulation`)：
   - 验证 `[PROGRESS:0~100]` 进度标识严格单调递增，五阶段看板流式解析稳定呈现。
8. **发版产物与磁盘清理守卫** (`test_clean_script_removes_notary_and_preserves_canonical`)：
   - 验证临时公证包即时销毁、历史旧版本包清退、以及发布后自动瘦身释放磁盘空间。

1. 递增 [Info.plist](file:///Users/chenxu/IdeaProjects/aether-antigravity-multiplexer/Info.plist) 中的版本号与 Build 号：
   - `CFBundleShortVersionString` (如 `0.7.7`)
   - `CFBundleVersion` (如 `45`)
2. 更新 [RELEASE_NOTES.md](file:///Users/chenxu/IdeaProjects/aether-antigravity-multiplexer/RELEASE_NOTES.md)，写入新版本的功能摘要与修复项。

### 步骤 2：提交代码并创建 Git 标签
```bash
git add Info.plist RELEASE_NOTES.md Sources/ ...
git commit -m "chore(release): release vX.Y.Z"
git tag vX.Y.Z
git push origin main vX.Y.Z
```

### 步骤 3：打包、签名与苹果公证
在本地终端执行打包脚本：
```bash
export SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE='your-notarytool-profile'
./scripts/package-release.sh
```
> [!NOTE]
> `package-release.sh` 已内置**临时公证文件自动销毁机制**。当苹果公证通过并完成票据装订（Staple）后，脚本会自动删除未装订的 `${NAME}-notary.zip` 和日志，并修剪历史归档，避免无用文件滞留。

### 步骤 4：执行发布与自动磁盘清理
推荐使用自动化发布脚本一键完成发布、分发与清理：
```bash
./scripts/publish-release.sh
```
该脚本会自动完成：
1. 检查必要资产（`dist/${NAME}.zip`、`appcast.xml`、`SHA256SUMS.txt`）；
2. 调用 `gh release create` 上传且**仅上传**正式资产（自动隔离任何临时文件）；
3. 自动触发官网同步工作流（`aethernative-sync.yml`）；
4. **自动触发 `./scripts/clean.sh --post-release`**，彻底回收本地临时文件与多余缓存。

*若需手动发布，请执行以下命令并确保在完成后运行清理*：
```bash
# 手动上传正式发布包
gh release create "v${VERSION}" --title "v${VERSION}" --notes-file "dist/v${VERSION}-notes.md" \
  "dist/Aether-Antigravity-Multiplexer-v${VERSION}-macos-arm64.zip" \
  "dist/appcast.xml" \
  "dist/SHA256SUMS.txt"

# 必须执行：发布后磁盘清理
./scripts/clean.sh --post-release
```

### 步骤 5：验证官网与在线更新
检查 [aethernative.com](https://aethernative.com/apps/antigravity-multiplexer/appcast.xml) 上的 Sparkle Appcast 清单，确保新版本号、发布日期与 EdDSA 签名均正确呈现。

---

## 4. 磁盘防溢出常态化检查清单 (Checklist)

在日常开发与持续迭代中，请遵守以下防溢出规范：

- [ ] **严禁上传 `*-notary.zip`**：该文件未经 stapler 装订，不仅占磁盘，若上传会导致网站更新同步器与用户校验失败；
- [ ] **本地不保留超过 1 个版本的 `.zip` 安装包**：GitHub Releases 具备永久版本存储能力，本地 `dist/` 仅充当发布中转站；
- [ ] **完成大版本迭代后主动执行深度清理**：运行 `./scripts/clean.sh --deep` 重置构建缓存；
- [ ] **关注 `.git` 与 `.build` 体积**：当发现项目体积异常增长（如超过 1.5 GB）时，运行 `du -sh . .build dist .git` 定位大文件源头。
