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

### 步骤 1：确认代码变更与本地回归测试
1. 运行所有单元测试，确保全绿：
   ```bash
   swift test
   ```
2. 递增 [Info.plist](file:///Users/chenxu/IdeaProjects/aether-antigravity-multiplexer/Info.plist) 中的版本号与 Build 号：
   - `CFBundleShortVersionString` (如 `0.7.6`)
   - `CFBundleVersion` (如 `44`)
3. 更新 [RELEASE_NOTES.md](file:///Users/chenxu/IdeaProjects/aether-antigravity-multiplexer/RELEASE_NOTES.md)，写入新版本的功能摘要与修复项。

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
