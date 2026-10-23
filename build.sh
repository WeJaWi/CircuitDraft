#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
OUTPUT_APP="$PWD/CircuitDraft.app"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/circuitdraft-build.XXXXXX")"
trap 'rm -rf -- "$BUILD_DIR"' EXIT
APP="$BUILD_DIR/CircuitDraft.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target arm64-apple-macosx14.0 -module-name CircuitDraft -o "$APP/Contents/MacOS/CircuitDraft" Sources/Model.swift Sources/Store.swift Sources/Automation.swift Sources/Drawing.swift Sources/App.swift -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CircuitDraft</string>
<key>CFBundleIdentifier</key><string>local.circuitdraft.editor</string>
<key>CFBundleName</key><string>CircuitDraft</string>
<key>CFBundleDisplayName</key><string>CircuitDraft Alpha</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CircuitDraftReleaseChannel</key><string>alpha</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
xattr -cr "$APP"
codesign --force --sign - "$APP"
ditto -c -k --keepParent --norsrc --noextattr "$APP" "$PWD/CircuitDraft-Mac.zip"
ditto --norsrc --noextattr "$APP" "$OUTPUT_APP"
echo "Built $OUTPUT_APP"
