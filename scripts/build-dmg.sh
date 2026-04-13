#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────
APP_NAME="Mac Mistress"
BUNDLE_NAME="MacMistress"
VERSION="${VERSION:-1.0.0}"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${BUNDLE_NAME}-${VERSION}.dmg"
DMG_DIR="${BUILD_DIR}/dmg"

echo "🔨 Building ${APP_NAME} v${VERSION}..."

# ─── Clean ───────────────────────────────────────────────────────
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ─── Build release binary ────────────────────────────────────────
echo "📦 Compiling release binary..."

# Try universal binary first (requires full Xcode), fall back to native arch
if xcode-select -p 2>/dev/null | grep -q "Xcode.app" && xcrun --find xcbuild &>/dev/null; then
    echo "   Building universal binary (arm64 + x86_64)..."
    ARCH_FLAGS="--arch arm64 --arch x86_64"
else
    echo "   Building native architecture only..."
    ARCH_FLAGS=""
fi

swift build -c release ${ARCH_FLAGS}

BINARY=$(swift build -c release ${ARCH_FLAGS} --show-bin-path)/${BUNDLE_NAME}

if [ ! -f "${BINARY}" ]; then
    echo "❌ Binary not found at ${BINARY}"
    exit 1
fi
echo "✅ Binary: ${BINARY}"

# ─── Create .app bundle ─────────────────────────────────────────
echo "📁 Creating .app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/${BUNDLE_NAME}"

# Copy Info.plist and update version
cp Sources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"

# Copy bundled resources (from SPM build)
RESOURCE_BUNDLE=$(find "$(swift build -c release ${ARCH_FLAGS} --show-bin-path)" -name "MacMistress_MacMistress.bundle" -type d | head -1)
if [ -n "${RESOURCE_BUNDLE}" ] && [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
    echo "✅ Copied resource bundle"
fi

# Generate .icns from square icon
ICON_SOURCE="assets/icon.png"
if [ ! -f "${ICON_SOURCE}" ] && [ -f "assets/logo.png" ]; then
    # Generate square icon from logo if icon.png doesn't exist
    python3 -c "
from PIL import Image
img = Image.open('assets/logo.png')
w, h = img.size
size = min(w, h)
left, top = (w - size) // 2, (h - size) // 2
cropped = img.crop((left, top, left + size, top + size)).resize((1024, 1024), Image.LANCZOS)
cropped.save('assets/icon.png')
"
    ICON_SOURCE="assets/icon.png"
fi

if [ -f "${ICON_SOURCE}" ]; then
    echo "🎨 Generating app icon..."
    ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"

    # Generate all required icon sizes from square source
    for size in 16 32 64 128 256 512; do
        sips -z ${size} ${size} "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_${size}x${size}.png" > /dev/null 2>&1
    done
    for size in 32 64 128 256 512 1024; do
        half=$((size / 2))
        sips -z ${size} ${size} "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_${half}x${half}@2x.png" > /dev/null 2>&1
    done

    iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

    # Add icon reference to Info.plist
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${APP_BUNDLE}/Contents/Info.plist"

    echo "✅ App icon generated"
fi

# ─── Code sign (ad-hoc) ──────────────────────────────────────────
echo "🔏 Code signing (ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"
echo "✅ Code signed"

echo "✅ App bundle created at ${APP_BUNDLE}"

# ─── Create aesthetic DMG ─────────────────────────────────────────
echo "💿 Creating DMG..."
DMG_TEMP="${BUILD_DIR}/temp.dmg"
DMG_FINAL="${BUILD_DIR}/${DMG_NAME}"
DMG_VOLUME="/Volumes/${APP_NAME}"
DMG_SIZE="200m"

mkdir -p "${DMG_DIR}"
cp -R "${APP_BUNDLE}" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

# Copy background image
BG_DIR="${DMG_DIR}/.background"
mkdir -p "${BG_DIR}"
if [ -f "assets/dmg-background.png" ]; then
    cp "assets/dmg-background.png" "${BG_DIR}/background.png"
    cp "assets/dmg-background@2x.png" "${BG_DIR}/background@2x.png" 2>/dev/null || true
fi

# Create writable DMG
hdiutil create -srcfolder "${DMG_DIR}" \
    -volname "${APP_NAME}" \
    -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
    -format UDRW -size "${DMG_SIZE}" \
    "${DMG_TEMP}"

# Mount and style
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify "${DMG_TEMP}")
DEVICE=$(echo "${MOUNT_OUTPUT}" | head -1 | awk '{print $1}')

echo "   Styling DMG window..."

# Apply Finder window settings via AppleScript
sleep 2
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        delay 2
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 760, 500}

        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set text size of theViewOptions to 13
        set label position of theViewOptions to bottom

        -- Set background if available
        try
            set backgroundFile to file ".background:background.png"
            set background picture of theViewOptions to backgroundFile
        end try

        -- Position icons
        set position of item "${APP_NAME}.app" of container window to {165, 180}
        set position of item "Applications" of container window to {495, 180}

        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Set white label color on icons (color index 6 = green shows as white-ish on dark bg doesn't work)
# Use Finder label to make text visible on dark background
osascript <<APPLESCRIPT
tell application "Finder"
    set theItems to every item of disk "${APP_NAME}"
    repeat with theItem in theItems
        set name of theItem to name of theItem -- refresh
    end repeat
end tell
APPLESCRIPT

# Set volume icon
if [ -f "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" ]; then
    cp "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" "${DMG_VOLUME}/.VolumeIcon.icns"
    SetFile -a C "${DMG_VOLUME}" 2>/dev/null || true
fi

# Finalize
chmod -Rf go-w "${DMG_VOLUME}" 2>/dev/null || true
sync
hdiutil detach "${DEVICE}" -quiet
hdiutil convert "${DMG_TEMP}" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL}"
rm -f "${DMG_TEMP}"

# Clean up staging dir
rm -rf "${DMG_DIR}"

echo ""
echo "✅ Done!"
echo "   App: ${APP_BUNDLE}"
echo "   DMG: ${BUILD_DIR}/${DMG_NAME}"
echo "   Version: ${VERSION}"
