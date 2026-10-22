#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP='Aether Antigravity Multiplexer.app'

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  echo "🧪 [Pre-Build Audit] 正在执行构建前全量单元测试与核心功能门禁..."
  python3 -m unittest discover -s tests || {
    echo "❌ 核心测试未通过，构建中断！请修复测试后再尝试打包。" >&2
    exit 1
  }
  echo "✅ 核心功能与回归测试门禁全量通过"
fi

./scripts/build-icon.sh
swift build -c release --triple arm64-apple-macosx13.0
BIN_DIR="$(swift build -c release --triple arm64-apple-macosx13.0 --show-bin-path)"
SPARKLE='.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework'
[[ -d "$SPARKLE" ]] || { echo 'Sparkle.framework missing' >&2; exit 1; }
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/AntigravityMultiplexer" "$APP/Contents/MacOS/AntigravityMultiplexer"
cp Resources/source_release_notes.json Resources/compatibility.json Resources/create_instance.py Resources/upgrade_all.py Resources/manage_backups.py Resources/destroy_instance.py Resources/clear_workspace.py "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"
cp Icon.icns "$APP/Contents/Resources/Icon.icns"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$APP/Contents/Resources/Sparkle-LICENSE"
xattr -cr "$APP"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  for COMPONENT in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app/Contents/MacOS/Updater Updater.app; do
    if [[ -e "$FRAMEWORK/Versions/B/$COMPONENT" ]]; then
      codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$FRAMEWORK/Versions/B/$COMPONENT"
    fi
  done
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$FRAMEWORK/Versions/B/Sparkle"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$FRAMEWORK"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$FRAMEWORK"
  codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
file "$APP/Contents/MacOS/AntigravityMultiplexer"
