#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
swift make_icon.swift Resources/AppIcon.png
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/aether-icon.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ICONSET="$STAGE/Aether.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -s format png -z "$retina" "$retina" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns -o Icon.icns "$ICONSET"
