#!/bin/bash
# Xcode acmadan hizli derleme. Ciktisi: ~/Applications/TurboMac.app
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP="$HOME/Applications/TurboMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$DIR/TurboMac/Resources/TurboMac.icns" "$APP/Contents/Resources/" 2>/dev/null || true
swiftc -O -parse-as-library $(find "$DIR/TurboMac" -name "*.swift") -o "$APP/Contents/MacOS/TurboMac"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>TurboMac</string>
  <key>CFBundleDisplayName</key><string>TurboMac</string>
  <key>CFBundleExecutable</key><string>TurboMac</string>
  <key>CFBundleIdentifier</key><string>com.tuna.turbomac</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>TurboMac</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSUIElement</key><true/>
  <key>NSAppSleepDisabled</key><true/>
</dict></plist>
PLIST
codesign --force --deep -s - "$APP" 2>/dev/null || true
echo "Kuruldu: $APP"
