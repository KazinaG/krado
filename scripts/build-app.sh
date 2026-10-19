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
    <key>CFBundleShortVersionString</key><string>KRADO_VERSION_VALUE</string>
    <key>CFBundleVersion</key><string>KRADO_VERSION_VALUE</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>ja</string></array>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>SUFeedURL</key><string>https://github.com/KazinaG/krado/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key><string>KRADO_SPARKLE_PUBLIC_KEY_PLACEHOLDER</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUAutomaticallyUpdate</key><false/>
    <key>SUAllowsAutomaticUpdates</key><false/>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Kazina. MIT License.</string>
</dict>
</plist>
PLIST
# KRADO_VERSION exists only for update tests (e.g. a 0.1.1 test build); releases use the default.
version="${KRADO_VERSION:-0.1.0}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: KRADO_VERSION must look like 1.2.3" >&2
    exit 1
fi
/usr/bin/sed -i '' "s/KRADO_VERSION_VALUE/$version/g" "$bundle/Contents/Info.plist"
plutil -lint "$bundle/Contents/Info.plist" >/dev/null

# Signing identity. KRADO_SIGN_IDENTITY (name or SHA-1) selects the stable
# "krado Self-Signed" certificate; CI imports it into a temporary keychain via
# scripts/ci-signing-keychain.sh. Without it, sign ad hoc (local builds only):
# ad-hoc builds get a cdhash requirement, so Accessibility must be granted again.
identity="${KRADO_SIGN_IDENTITY:--}"
sign_args=(--force --timestamp=none -s "$identity")
if [[ -n "${KRADO_SIGN_KEYCHAIN:-}" ]]; then
    sign_args+=(--keychain "$KRADO_SIGN_KEYCHAIN")
fi
if [[ "$identity" == "-" ]]; then
    echo "Signing ad hoc (set KRADO_SIGN_IDENTITY to use the release certificate)."
    # Sign nested XPC services, Autoupdate, and Updater.app before the enclosing app.
    codesign --force --deep -s - "$framework"
    codesign --force --deep -s - "$bundle"
else
    echo "Signing with the configured certificate."
    # Inside out, as Sparkle documents for non-ad-hoc identities; no --deep.
    sparkle_b="$framework/Versions/B"
    for item in "$sparkle_b"/XPCServices/*.xpc "$sparkle_b/Autoupdate" "$sparkle_b/Updater.app"; do
        [[ -e "$item" ]] && codesign "${sign_args[@]}" "$item"
    done
    codesign "${sign_args[@]}" "$framework"
    codesign "${sign_args[@]}" "$bundle"
    # The point of the certificate: a designated requirement that survives rebuilds.
    requirement="$(codesign -d -r- "$bundle" 2>&1 | sed -n 's/^designated => //p')"
    if [[ "$requirement" != *'identifier "io.github.kazinag.krado"'* || "$requirement" != *"certificate "* || "$requirement" == *cdhash* ]]; then
        echo "error: unexpected designated requirement: $requirement" >&2
        exit 1
    fi
    if codesign -dv "$bundle" 2>&1 | grep -E '^TeamIdentifier=' | grep -vq 'not set'; then
        echo "error: the signing certificate must not carry a Team ID (OU)." >&2
        exit 1
    fi
    echo "Designated requirement: $requirement"
fi
codesign --verify --deep --strict "$bundle"
otool -L "$bundle/Contents/MacOS/krado" | grep -F '@rpath/Sparkle.framework/'
otool -l "$bundle/Contents/MacOS/krado" | grep -F 'path @executable_path/../Frameworks (offset'
echo "Built $bundle (not launched)."
