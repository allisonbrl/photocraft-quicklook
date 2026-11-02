#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="/Applications/PCraftQuickLook.app"
PREVIEW_DIR="$APP_DIR/Contents/PlugIns/PCraftPreview.appex"
THUMB_DIR="$APP_DIR/Contents/PlugIns/PCraftThumbnail.appex"

echo "==> Limpando instalação anterior..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$PREVIEW_DIR/Contents/MacOS" "$PREVIEW_DIR/Contents/Resources"
mkdir -p "$THUMB_DIR/Contents/MacOS" "$THUMB_DIR/Contents/Resources"

echo "==> Gerando Info.plist do App Host..."
cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.allison.PCraftQuickLook</string>
    <key>CFBundleName</key>
    <string>PCraftQuickLook</string>
    <key>CFBundleDisplayName</key>
    <string>PCraft QuickLook</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleExecutable</key>
    <string>PCraftQuickLook</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Gerando Info.plist da extensão PCraftPreview..."
cat << 'EOF' > "$PREVIEW_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.allison.PCraftQuickLook.Preview</string>
    <key>CFBundleName</key>
    <string>PCraftPreview</string>
    <key>CFBundleDisplayName</key>
    <string>PCraft Preview Extension</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleExecutable</key>
    <string>PCraftPreview</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.quicklook.preview</string>
        <key>NSExtensionPrincipalClass</key>
        <string>PCraftPreviewProvider</string>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>QLIsDataBasedPreview</key>
            <true/>
            <key>QLSupportedContentTypes</key>
            <array>
                <string>ai.storyteller.photocraft.document</string>
            </array>
            <key>QLSupportsSearchableItems</key>
            <false/>
        </dict>
    </dict>
</dict>
</plist>
EOF

echo "==> Gerando Info.plist da extensão PCraftThumbnail..."
cat << 'EOF' > "$THUMB_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.allison.PCraftQuickLook.Thumbnail</string>
    <key>CFBundleName</key>
    <string>PCraftThumbnail</string>
    <key>CFBundleDisplayName</key>
    <string>PCraft Thumbnail Extension</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleExecutable</key>
    <string>PCraftThumbnail</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.quicklook.thumbnail</string>
        <key>NSExtensionPrincipalClass</key>
        <string>PCraftThumbnailProvider</string>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>QLSupportedContentTypes</key>
            <array>
                <string>ai.storyteller.photocraft.document</string>
            </array>
        </dict>
    </dict>
</dict>
</plist>
EOF

echo "==> Compilando binários nativos..."
swiftc -O "$DIR/src/HostMain.swift" -o "$APP_DIR/Contents/MacOS/PCraftQuickLook"
clang -O2 -fmodules -framework Foundation -framework QuickLookUI -framework UniformTypeIdentifiers -e _NSExtensionMain "$DIR/src/ExtensionMain.m" -o "$PREVIEW_DIR/Contents/MacOS/PCraftPreview"
clang -O2 -fmodules -framework Foundation -framework AppKit -framework QuickLookThumbnailing -e _NSExtensionMain "$DIR/src/ThumbnailMain.m" -o "$THUMB_DIR/Contents/MacOS/PCraftThumbnail"

echo "==> Assinando bundles com entitlements..."
cat << 'EOF' > /tmp/entitlements.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
EOF

codesign --force --sign - --entitlements /tmp/entitlements.plist "$PREVIEW_DIR"
codesign --force --sign - --entitlements /tmp/entitlements.plist "$THUMB_DIR"
codesign --force --sign - --entitlements /tmp/entitlements.plist "$APP_DIR"
rm -f /tmp/entitlements.plist

echo "==> Registrando extensões no LaunchServices e PlugInKit..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR"
pluginkit -a "$PREVIEW_DIR"
pluginkit -a "$THUMB_DIR"
pluginkit -e use -i com.allison.PCraftQuickLook.Preview
pluginkit -e use -i com.allison.PCraftQuickLook.Thumbnail

echo "==> Resetando cache do QuickLook..."
qlmanage -r
qlmanage -r cache
killall quicklookd 2>/dev/null || true

echo "✅ Pronto! Quick Look e Miniaturas ativados com sucesso."
