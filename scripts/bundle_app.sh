#!/usr/bin/env bash
set -euo pipefail

# bundle_app.sh
# Assembles Reclaim.app desktop bundle from SPM build

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🔨 Building ReclaimUI binary (release mode)..."
swift build -c release --product ReclaimUI -Xswiftc -gnone

APP_NAME="Reclaim.app"
APP_DIR="$PROJECT_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Packaging $APP_NAME..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
BIN_PATH="$(swift build -c release --show-bin-path)/ReclaimUI"
cp "$BIN_PATH" "$MACOS_DIR/ReclaimUI"
chmod +x "$MACOS_DIR/ReclaimUI"

# Copy App Icon
ICON_SOURCE="$PROJECT_DIR/Sources/ReclaimUI/Resources/AppIcon.icns"
if [ ! -f "$ICON_SOURCE" ]; then
    echo "⚡ Generating high-resolution AppIcon.icns..."
    swift "$PROJECT_DIR/scripts/generate_app_icon.swift"
fi
if [ -f "$ICON_SOURCE" ]; then
    cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
    echo "🎨 AppIcon.icns packaged successfully."
fi

# Create Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ReclaimUI</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.reclaim.macos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Reclaim</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Reclaim needs access to Finder to inspect and manage items in Trash.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Reclaim needs access to Documents to inspect project workspaces and developer caches.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Reclaim needs access to Downloads to discover large and old unused files.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Reclaim needs access to Desktop to inspect storage items.</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>Reclaim needs access to inspect external storage volumes.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>Reclaim needs access to perform maintenance tasks and storage diagnostics.</string>
</dict>
</plist>
EOF

echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "🔐 Sealing and signing application bundle with stable identifier com.reclaim.macos..."
codesign --force --deep --sign - --identifier "com.reclaim.macos" "$APP_DIR"

echo "✅ Successfully created desktop application: $APP_DIR"
echo "You can now open it with: open \"$APP_DIR\" or double-click it in Finder!"
