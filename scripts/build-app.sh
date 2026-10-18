#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# Keep compiler caches inside the workspace in restricted CLI environments.
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$repo_root/.build/module-cache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$repo_root/.build/module-cache}"
# The app needs no dSYM. CLT's dsymutil may be restricted by a host sandbox.
# Public dependencies need no credentials; never query the login Keychain.
build_args=(build --disable-keychain -c release -debug-info-format none)
# Set to 0 when SwiftPM's own sandbox is wanted; default supports the Codex sandbox.
if [[ "${KRADO_DISABLE_SANDBOX:-1}" == "1" ]]; then
    build_args+=(--disable-sandbox)
fi
swift "${build_args[@]}"
binary_dir="$(swift "${build_args[@]}" --show-bin-path)"

bundle="$repo_root/dist/krado.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources" "$bundle/Contents/Frameworks"
framework="$bundle/Contents/Frameworks/Sparkle.framework"
# ditto preserves the versioned framework's symlinks and executable permissions.
rm -rf "$framework"
ditto "$binary_dir/Sparkle.framework" "$framework"
install -m 755 "$binary_dir/krado" "$bundle/Contents/MacOS/krado"
for language in en ja; do
    rm -rf "$bundle/Contents/Resources/$language.lproj"
    cp -R "$repo_root/Resources/$language.lproj" "$bundle/Contents/Resources/"
    plutil -lint "$bundle/Contents/Resources/$language.lproj/Localizable.strings" \
        "$bundle/Contents/Resources/$language.lproj/InfoPlist.strings" >/dev/null
done
install -m 644 "$repo_root/Resources/AppIcon.icns" "$bundle/Contents/Resources/AppIcon.icns"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.github.kazinag.krado</string>
    <key>CFBundleName</key><string>krado</string>
    <key>CFBundleExecutable</key><string>krado</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>0.1.0</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>ja</string></array>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>SUFeedURL</key><string>https://github.com/KazinaG/krado/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key><string>KRADO_SPARKLE_PUBLIC_KEY_PLACEHOLDER</string>
    <key>SUEnableAutomaticChecks</key><false/>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Kazina. MIT License.</string>
</dict>
</plist>
PLIST
plutil -lint "$bundle/Contents/Info.plist" >/dev/null

# Sign nested XPC services, Autoupdate, and Updater.app before the enclosing app.
codesign --force --deep -s - "$framework"
codesign --force --deep -s - "$bundle"
codesign --verify --deep --strict "$bundle"
otool -L "$bundle/Contents/MacOS/krado" | grep -F '@rpath/Sparkle.framework/'
otool -l "$bundle/Contents/MacOS/krado" | grep -F 'path @executable_path/../Frameworks (offset'
echo "Built $bundle (not launched)."
