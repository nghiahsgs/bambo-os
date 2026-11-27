#!/usr/bin/env bash
# build-app.sh: build "out/Try BamboOS.app", a window in front of try-bambo.sh.
#
#   scripts/build-app.sh
#
# macOS only. Needs the Xcode command line tools (swiftc). The app remembers
# the path of this repository, so build it again after moving the folder.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(uname -s) == Darwin ]] || { echo "build-app: the app is for macOS only." >&2; exit 1; }
command -v swiftc >/dev/null 2>&1 || { echo "build-app: swiftc not found. Run: xcode-select --install" >&2; exit 1; }

app="$repo/out/Try BamboOS.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

echo "==> Compiling"
swiftc -O -parse-as-library -target "$(uname -m)-apple-macos14.0" \
  -o "$app/Contents/MacOS/TryBamboOS" "$repo/macos/TryBamboOS.swift"

# The icon is the BamboOS logo. Without it the app still works.
icon_key=""
iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"
if sips -s format png -z 1024 1024 "$repo/themes/tessera/logo.svg" --out "$iconset/base.png" >/dev/null 2>&1; then
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$iconset/base.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$iconset/base.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  rm "$iconset/base.png"
  if iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns" 2>/dev/null; then
    icon_key="<key>CFBundleIconFile</key><string>AppIcon</string>"
  fi
fi
[[ -n $icon_key ]] || echo "note: no icon (could not convert themes/tessera/logo.svg)."

# The repository path goes into the plist as XML text.
repo_xml="${repo//&/&amp;}"
repo_xml="${repo_xml//</&lt;}"
cat >"$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Try BamboOS</string>
  <key>CFBundleDisplayName</key><string>Try BamboOS</string>
  <key>CFBundleIdentifier</key><string>org.bambo.try</string>
  <key>CFBundleExecutable</key><string>TryBamboOS</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  $icon_key
  <key>BamboRepo</key><string>$repo_xml</string>
</dict>
</plist>
PLIST

# An ad-hoc signature is enough to run on the machine that built it.
codesign --force --sign - "$app" >/dev/null 2>&1 || echo "note: the app is not signed."

echo "==> Built $app"
echo "Open it with: open \"$app\""
