#!/usr/bin/env bash
# Only run on disposable macOS CI runners; never launches through LaunchServices.
set -euo pipefail
os="$1"
# Menu language: ja (default) or en. Files carry the language so both sets can sit side by side.
lang="${2:-ja}"
case "$lang" in
    ja) locale=ja_JP ;;
    en) locale=en_US ;;
    *) echo "error: unknown language $lang" >&2; exit 2 ;;
esac
mkdir -p menu-shots
app_pid=""
cleanup() {
    if [[ -n "$app_pid" ]]; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
        app_pid=""
    fi
}
trap cleanup EXIT
# Compile once, before opening a menu (swift startup can otherwise delay capture).
swiftc scripts/menu-shot-windows.swift -o "$RUNNER_TEMP/menu-shot-windows"
# CI runner only: a colorful wallpaper so a translucent (glass) menu is visible, plus settings that change the look.
{
    defaults read com.apple.universalaccess reduceTransparency 2>&1 || echo "reduceTransparency: not set (default off)"
    defaults read com.apple.universalaccess increaseContrast 2>&1 || echo "increaseContrast: not set (default off)"
    wallpaper=$(ls "/System/Library/Desktop Pictures/"*.heic 2>/dev/null | head -1 || true)
    echo "wallpaper: ${wallpaper:-none}"
    if [[ -n "$wallpaper" ]]; then
        osascript -e "tell application \"System Events\" to tell every desktop to set picture to POSIX file \"$wallpaper\"" || true
    fi
} > "menu-shots/environment-$os.txt" 2>&1
sleep 2
# Reference: Apple's own Apple menu on the same machine, for comparing the material.
osascript -e 'tell application "System Events" to tell process "Finder" to click menu bar item 1 of menu bar 1' >/dev/null 2>&1 &
ref_pid=$!
sleep 3
screencapture -x -m "menu-shots/reference-apple-menu-$os-full.png"
osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true
kill "$ref_pid" 2>/dev/null || true
build_variant() {
    local variant="$1" probe=0
    if [[ "$variant" == P ]]; then probe=1; fi
    KRADO_LOGIN_SWITCH_PROBE="$probe" KRADO_CI_HOOKS=1 scripts/build-app.sh
    # Install before direct launch so ServiceManagement sees the installed bundle.
    rm -rf /Applications/krado.app
    ditto dist/krado.app /Applications/krado.app
    { sw_vers; xcodebuild -version; xcrun --show-sdk-version; vtool -show-build dist/krado.app/Contents/MacOS/krado; } \
        > "menu-shots/sdk-$variant-$os.txt" 2>&1 || true
}
shot() {
    local stem="$1"
    screencapture -x -m "$stem-full.png"
    "$RUNNER_TEMP/menu-shot-windows" "$app_pid" "$stem-windows.txt" > "$stem-bounds.json"
    python3 scripts/crop-menu-shot.py "$stem-full.png" "$stem-bounds.json" "$stem.png"
}
capture_login() {
    local variant="$1" login="$2" suffix="${3:-}"
    local stem="menu-shots/menu-$lang-$variant-login$login-$os$suffix"
    local readback="$RUNNER_TEMP/krado-login-readback"
    rm -f "$readback"
    : > "$stem-launch.txt"
    NSUnbufferedIO=YES KRADO_CI_LOGIN="$login" KRADO_CI_LOGIN_READBACK="$readback" KRADO_CI_OPEN_MENU=1 \
        /Applications/krado.app/Contents/MacOS/krado -AppleLanguages "($lang)" -AppleLocale "$locale" \
        >>"$stem-launch.txt" 2>&1 &
    app_pid=$!
    sleep 5
    shot "$stem"
    if [[ "$variant" == A ]]; then
        echo "KRADO_CI ax menu items:" >> "$stem-launch.txt"
        osascript -e 'tell application "System Events" to tell process "krado" to get count of menu bars' >> "$stem-launch.txt" 2>&1 || true
        osascript -e 'tell application "System Events" to tell process "krado" to get {name, description, value, value of attribute "AXMenuItemMarkChar"} of every menu item of menu 1 of menu bar item 1 of last menu bar' >> "$stem-launch.txt" 2>&1 || true
    fi
    if [[ "$variant" == A || "$variant" == P ]]; then
        # Permission and monitor rows are enabled; headers/separators are skipped.
        # Setup is visible only without permission. The next Down should reach login
        # in A; P records whether AppKit skips the custom view instead.
        local downs=3
        if ! grep -q 'Accessibility trusted: true' "$stem-launch.txt"; then downs=4; fi
        echo "KRADO_CI keyboard Down count=$downs, intended row=Launch at Login" >> "$stem-launch.txt"
        for ((i=0; i<downs; i++)); do
            osascript -e 'tell application "System Events" to key code 125'
        done
        shot "$stem-keyboard"
        osascript -e 'tell application "System Events" to key code 36'
        sleep 1
        touch "$readback"
        sleep 1
    fi
    cleanup
    if ! grep -q 'Accessibility trusted: true' "$stem-launch.txt"; then
        echo "error: runner Accessibility grant was not inherited; see $stem-launch.txt" >&2
        exit 1
    fi
}
for variant in A P; do
    build_variant "$variant"
    for login in on off; do capture_login "$variant" "$login"; done
done
# Disposable runner only: retain its default for the first set, then expose the material.
if defaults write com.apple.universalaccess reduceTransparency -bool false >>"menu-shots/environment-$os.txt" 2>&1; then
    echo "reduceTransparency after write: $(defaults read com.apple.universalaccess reduceTransparency 2>&1)" >> "menu-shots/environment-$os.txt"
    sleep 2
    osascript -e 'tell application "System Events" to tell process "Finder" to click menu bar item 1 of menu bar 1' >/dev/null 2>&1 &
    ref_pid=$!
    sleep 3
    screencapture -x -m "menu-shots/reference-apple-menu-$os-transparent-full.png"
    osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true
    kill "$ref_pid" 2>/dev/null || true
    for variant in A P; do
        build_variant "$variant"
        capture_login "$variant" on -transparent
    done
fi
