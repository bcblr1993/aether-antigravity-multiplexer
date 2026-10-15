#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
NAME="Aether-Antigravity-Multiplexer-v${VERSION}-macos-arm64"
TAG="v${VERSION}"
NOTES="dist/v${VERSION}-notes.md"
ARCHIVE="dist/${NAME}.zip"
APPCAST="dist/appcast.xml"
SUMS="dist/SHA256SUMS.txt"

echo "🚀 [Publish] Aether Antigravity Multiplexer 版本发布与自动清理工具"
echo "📌 目标发布版本: ${TAG}"

# 1. 预检文件与状态
[[ -f "$ARCHIVE" ]] || { echo "❌ 缺失安装包: $ARCHIVE，请先执行 ./scripts/package-release.sh" >&2; exit 1; }
[[ -f "$APPCAST" ]] || { echo "❌ 缺失更新清单: $APPCAST" >&2; exit 1; }
[[ -f "$SUMS" ]] || { echo "❌ 缺失校验文件: $SUMS" >&2; exit 1; }

# 2. 检查 Git 标签
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "❌ Git 标签 $TAG 不存在，请先确认代码提交并执行 git tag $TAG" >&2
  exit 1
fi

# 3. 检查 Release 是否已存在
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "⚠️  GitHub Release $TAG 已存在！"
  read -q "REPLACE?是否更新/重新上传资产? (y/n): " || { echo "\n取消发布"; exit 0; }
  echo ""
  gh release upload "$TAG" "$ARCHIVE" "$APPCAST" "$SUMS" --clobber
else
  # 4. 创建正式 Release
  if [[ -f "$NOTES" ]]; then
    gh release create "$TAG" --title "$TAG" --notes-file "$NOTES" "$ARCHIVE" "$APPCAST" "$SUMS"
  else
    gh release create "$TAG" --title "$TAG" "$ARCHIVE" "$APPCAST" "$SUMS"
  fi
fi

echo "✅ GitHub Release $TAG 发布成功！"

# 5. 触发官网 Appcast 同步
if gh workflow view aethernative-sync.yml >/dev/null 2>&1; then
  echo "🌐 正在触发官网版本同步工作流..."
  gh workflow run aethernative-sync.yml -f tag="$TAG" || echo "⚠️  自动同步触发未成功，可稍后重试"
fi

# 6. 核心步骤：版本发布后自动执行磁盘清理，防止磁盘溢出
echo "🧹 正在执行版本发布后磁盘与临时文件自动清理..."
./scripts/clean.sh --post-release

echo "🎉 发布及磁盘清理全部完成！"
