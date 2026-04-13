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
DMG_FINAL="${BUILD_DIR}/${DMG_NAME}"

# Use create-dmg for reliable styling
CREATE_DMG_ARGS=(
    --volname "${APP_NAME}"
    --volicon "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    --window-pos 200 120
    --window-size 660 400
    --icon-size 100
    --icon "${APP_NAME}.app" 165 175
    --icon "Applications" 495 175
    --hide-extension "${APP_NAME}.app"
    --app-drop-link 495 175
    --text-size 13
)

# Add background if available
if [ -f "assets/dmg-background.png" ]; then
    CREATE_DMG_ARGS+=(--background "assets/dmg-background.png")
fi

# Remove existing DMG if present
rm -f "${DMG_FINAL}"

create-dmg "${CREATE_DMG_ARGS[@]}" "${DMG_FINAL}" "${APP_BUNDLE}"

# create-dmg returns 2 if it couldn't set custom icon (non-fatal)
if [ ! -f "${DMG_FINAL}" ]; then
    echo "❌ DMG creation failed"
    exit 1
fi

echo ""
echo "✅ Done!"
echo "   App: ${APP_BUNDLE}"
echo "   DMG: ${BUILD_DIR}/${DMG_NAME}"
echo "   Version: ${VERSION}"
