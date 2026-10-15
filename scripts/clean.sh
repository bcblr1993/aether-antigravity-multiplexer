#!/bin/zsh
set -euo pipefail
setopt +o nomatch 2>/dev/null || true
cd "${0:A:h}/.."

ROOT_DIR="$(pwd)"
CURRENT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist 2>/dev/null || echo "unknown")"
CURRENT_ARCHIVE="Aether-Antigravity-Multiplexer-v${CURRENT_VERSION}-macos-arm64.zip"

MODE="${1:-standard}"

echo "🧹 [Clean] Aether Antigravity Multiplexer 磁盘与构建产物清理工具"
echo "📌 当前版本: v${CURRENT_VERSION}"
echo "⚙️  清理模式: ${MODE}"

SIZE_BEFORE="$(du -sk . 2>/dev/null | awk '{print $1}')"

case "$MODE" in
  --help|-h|help)
    echo "使用方式: ./scripts/clean.sh [MODE]"
    echo ""
    echo "模式选项:"
    echo "  standard (默认)    清理根目录临时 App、未装订公证包与历史旧版 zip，清理 /tmp 残留"
    echo "  --post-release     版本发布后执行：卸载临时构建与归档负载，保留当前版本元数据"
    echo "  --deep / --all     深度清理：包含上述全部，并清理 SPM 构建输出 (.build/out) 与图标"
    exit 0
    ;;

  --post-release|post-release)
    echo "🚀 执行版本发布后清理 (Post-Release Clean)..."
    
    # 1. 彻底删除临时未装订公证包与公证中间日志
    rm -f dist/*-notary.zip dist/notarization.json dist/notarization-log.json 2>/dev/null || true
    
    # 2. 清理历史旧版本的归档压缩包（保留当前版本的 zip 以及元数据）
    if [[ -d "dist" ]]; then
      find dist/ -type f -name "*.zip" ! -name "$CURRENT_ARCHIVE" -delete 2>/dev/null || true
    fi
    
    # 3. 清理根目录下编辑构建生成的 app bundle
    rm -rf "Aether Antigravity Multiplexer.app" 2>/dev/null || true
    
    # 4. 清理系统 /tmp 下本项目构建或分析残留的临时文件
    rm -rf /tmp/aether-icon.* /tmp/antigravity-appcast.* /tmp/antigravity_sample.txt 2>/dev/null || true
    rm -rf "${TMPDIR:-/tmp}/aether-icon."* "${TMPDIR:-/tmp}/antigravity-appcast."* 2>/dev/null || true
    ;;

  --deep|--all|deep|all)
    echo "💥 执行深度全量清理 (Deep Clean)..."
    
    # 1. 彻底删除临时公证包、日志与所有 dist 压缩包
    rm -f dist/*.zip dist/notarization.json dist/notarization-log.json 2>/dev/null || true
    
    # 2. 清理根目录构建产物与临时图标
    rm -rf "Aether Antigravity Multiplexer.app" Icon.icns 2>/dev/null || true
    
    # 3. 清理 Swift Package Manager 构建输出目录（保留 Sparkle 工具以防重新下载慢，清理 .build/out）
    if [[ -d ".build/out" ]]; then
      rm -rf .build/out
    fi
    if [[ -d ".build/arm64-apple-macosx" ]]; then
      rm -rf .build/arm64-apple-macosx
    fi
    swift package clean 2>/dev/null || true
    
    # 4. 清理 /tmp 临时文件
    rm -rf /tmp/aether-icon.* /tmp/antigravity-appcast.* /tmp/antigravity_sample.txt 2>/dev/null || true
    rm -rf "${TMPDIR:-/tmp}/aether-icon."* "${TMPDIR:-/tmp}/antigravity-appcast."* 2>/dev/null || true
    ;;

  --standard|standard|*)
    echo "✨ 执行标准清理 (Standard Clean)..."
    
    # 1. 删除临时未装订公证包与中间日志
    rm -f dist/*-notary.zip dist/notarization.json dist/notarization-log.json 2>/dev/null || true
    
    # 2. 清理 dist 中历史旧版本的压缩包（仅保留当前版本）
    if [[ -d "dist" ]]; then
      find dist/ -type f -name "*.zip" ! -name "$CURRENT_ARCHIVE" -delete 2>/dev/null || true
    fi
    
    # 3. 清理根目录下编辑构建生成的 app bundle（可在开发需要时重新执行 ./build.sh 生成）
    rm -rf "Aether Antigravity Multiplexer.app" 2>/dev/null || true
    
    # 4. 清理 /tmp 临时构建目录
    rm -rf /tmp/aether-icon.* /tmp/antigravity-appcast.* /tmp/antigravity_sample.txt 2>/dev/null || true
    rm -rf "${TMPDIR:-/tmp}/aether-icon."* "${TMPDIR:-/tmp}/antigravity-appcast."* 2>/dev/null || true
    ;;
esac

SIZE_AFTER="$(du -sk . 2>/dev/null | awk '{print $1}')"
RECLAIMED=$(( (SIZE_BEFORE - SIZE_AFTER) / 1024 ))

echo "✅ 清理完成！"
echo "📊 清理前占用: $(( SIZE_BEFORE / 1024 )) MB"
echo "📊 清理后占用: $(( SIZE_AFTER / 1024 )) MB"
echo "🎉 共释放磁盘空间: ${RECLAIMED} MB"
