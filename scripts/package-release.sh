#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to a Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
APP='Aether Antigravity Multiplexer.app'
NAME="Aether-Antigravity-Multiplexer-v${VERSION}-macos-arm64"
ACCOUNT='AntigravityMultiplexer'
GENERATOR='.build/artifacts/sparkle/Sparkle/bin/generate_appcast'
mkdir -p dist

echo "🧪 [Pre-Release Audit] 正在执行发版前强制功能与回归测试门禁..."
python3 -m unittest discover -s tests || {
  echo "❌ 测试未通过，发版流程强制中断！请修复测试后再尝试打包。" >&2
  exit 1
}
echo "✅ 强制测试门禁全部通过 (含升级备份可选性、进度条流式协议、单窗口及磁盘清理测试)"

NOTARY_ZIP="dist/${NAME}-notary.zip"

# Always rebuild from this checkout; an old ticket does not prove source freshness.
./build.sh
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist")" == \
   "$(.build/artifacts/sparkle/Sparkle/bin/generate_keys --account "$ACCOUNT" -p | tail -1 | tr -d '[:space:]')" ]] || {
  echo 'Sparkle public key does not match the release signing account' >&2
  exit 1
}

ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" \
  --wait --timeout 20m --output-format json > dist/notarization.json
python3 - <<'PY'
import json
record=json.load(open('dist/notarization.json'))
print('Notarization:',record.get('status'),'id:',record.get('id'))
raise SystemExit(0 if record.get('status')=='Accepted' else 1)
PY
SUBMISSION_ID="$(python3 -c "import json; print(json.load(open('dist/notarization.json')).get('id',''))")"
if [[ -n "$SUBMISSION_ID" ]] && xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" \
  --output-format json > dist/notarization-log.json 2>/dev/null; then
  python3 - <<'PY'
import json
record=json.load(open('dist/notarization-log.json'))
issues=record.get('issues') or []
print('Notary issues:',len(issues))
raise SystemExit(0 if record.get('status')=='Accepted' and not issues else 1)
PY
else
  echo "⚠️ 提示: 公证日志下载遇到瞬时网络波动，但状态已确认为 Accepted，继续执行装订与验签"
fi
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict "$APP"
spctl --assess --type execute "$APP"

# 立即清理公证阶段产生的未装订临时压缩包与日志，释放磁盘并杜绝误传
echo "🧹 清理公证阶段未装订临时文件: $NOTARY_ZIP"
rm -f "$NOTARY_ZIP" dist/notarization.json dist/notarization-log.json 2>/dev/null || true

# 清理 dist 中历史旧版本的压缩包，确保只留存当前版本
find dist/ -type f -name "*.zip" ! -name "${NAME}.zip" -delete 2>/dev/null || true

python3 - "$VERSION" <<'PYVERIFY'
import pathlib, plistlib, sys
source = plistlib.loads(pathlib.Path('Info.plist').read_bytes())
built = plistlib.loads(pathlib.Path('Aether Antigravity Multiplexer.app/Contents/Info.plist').read_bytes())
for key in ('CFBundleShortVersionString', 'CFBundleVersion', 'SUPublicEDKey'):
    if built.get(key) != source.get(key):
        raise SystemExit(f'Packaged metadata mismatch: {key}')
if built['CFBundleShortVersionString'] != sys.argv[1]:
    raise SystemExit('Packaged release version mismatch')
PYVERIFY

ARCHIVE="dist/${NAME}.zip"
ditto -c -k --keepParent "$APP" "$ARCHIVE"
unzip -tq "$ARCHIVE"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/antigravity-appcast.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
cp "$ARCHIVE" "$STAGE/"
cp RELEASE_NOTES.md "$STAGE/${NAME}.md"
"$GENERATOR" --account "$ACCOUNT" --embed-release-notes \
  --download-url-prefix "https://github.com/bcblr1993/aether-antigravity-multiplexer/releases/download/v${VERSION}/" \
  "$STAGE"
cp "$STAGE/appcast.xml" dist/appcast.xml
python3 - "$VERSION" "$NAME" <<'PY'
import sys,xml.etree.ElementTree as ET
version,name=sys.argv[1:]
root=ET.parse('dist/appcast.xml')
ns={'s':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
items=root.findall('./channel/item')
assert len(items)==1
item=items[0]
assert item.findtext('s:shortVersionString',namespaces=ns)==version
enclosure=item.find('enclosure')
assert enclosure.get('{'+ns['s']+'}edSignature')
assert enclosure.get('url')==f'https://github.com/bcblr1993/aether-antigravity-multiplexer/releases/download/v{version}/{name}.zip'
print('Appcast version, URL and EdDSA signature verified')
PY
".build/artifacts/sparkle/Sparkle/bin/sign_update" --account "$ACCOUNT" --verify dist/appcast.xml
SIGNATURE="$(python3 - <<'PY'
import xml.etree.ElementTree as ET
root=ET.parse('dist/appcast.xml').getroot()
print(root.find('./channel/item/enclosure').get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'))
PY
)"
".build/artifacts/sparkle/Sparkle/bin/sign_update" --account "$ACCOUNT" --verify "$ARCHIVE" "$SIGNATURE"
(cd dist && shasum -a 256 "${NAME}.zip" appcast.xml > SHA256SUMS.txt)
echo "Release files ready in dist/: ${NAME}.zip, appcast.xml, SHA256SUMS.txt"
echo "💡 提示: 版本通过 gh release 发布后，请运行 ./scripts/clean.sh --post-release 及时回收磁盘空间。"
