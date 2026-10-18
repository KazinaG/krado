#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# Keep compiler caches inside the workspace in restricted CLI environments.
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$repo_root/.build/module-cache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$repo_root/.build/module-cache}"
# The app needs no dSYM. CLT's dsymutil may be restricted by a host sandbox.
build_args=(build -c release -debug-info-format none)
# Set to 0 when SwiftPM's own sandbox is wanted; default supports the Codex sandbox.
if [[ "${KRADO_DISABLE_SANDBOX:-1}" == "1" ]]; then
    build_args+=(--disable-sandbox)
fi
swift "${build_args[@]}"
binary_dir="$(swift "${build_args[@]}" --show-bin-path)"

bundle="$repo_root/dist/krado.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
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
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Kazina. MIT License.</string>
</dict>
</plist>
PLIST
plutil -lint "$bundle/Contents/Info.plist" >/dev/null

if ! codesign --force --deep -s - "$bundle"; then
    echo "Warning: ad-hoc signing failed; the app bundle was built but its signature may be invalid." >&2
fi
echo "Built $bundle (not launched)."
