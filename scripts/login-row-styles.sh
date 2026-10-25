#!/usr/bin/env bash
# Disposable macOS CI only. Screenshots of the real Launch at Login row for each Off
# style (A outline, B faint fill, C both) and On, in Light and Dark, resting and
# highlighted. Files go to login-row-styles/; the comparison sheet is made from them.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo "error: needs a macOS CI desktop" >&2; exit 1; }
out="$PWD/login-row-styles"; mkdir -p "$out"
app_pid=""
cleanup() {
    if [[ -n "$app_pid" ]]; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
        app_pid=""
    fi
}
trap cleanup EXIT
swiftc scripts/login-hover-mouse.swift -o "$RUNNER_TEMP/login-hover-mouse"
swiftc scripts/menu-shot-windows.swift -o "$RUNNER_TEMP/login-hover-windows"
KRADO_CI_HOOKS=1 scripts/build-app.sh
sw_vers > "$out/environment.txt"
for appearance in Light Dark; do
    dark=false
    if [[ "$appearance" == Dark ]]; then dark=true; fi
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark"
    sleep 2
    for spec in A:off B:off C:off A:on; do
        IFS=: read -r style state <<< "$spec"
        case="$appearance-$style-$state"
        NSUnbufferedIO=YES KRADO_CI_LOGIN_FAKE="$state" KRADO_CI_OPEN_MENU=1 KRADO_CI_LOGIN_OFF_STYLE="$style" \
            KRADO_CI_LOGIN_GEOMETRY="$out/$case-geometry.json" \
            dist/krado.app/Contents/MacOS/krado -AppleLanguages '(ja)' -AppleLocale ja_JP > "$out/$case-app.log" 2>&1 &
        app_pid=$!
        sleep 5
        "$RUNNER_TEMP/login-hover-windows" "$app_pid" "$out/$case-windows.txt" > "$out/$case-menu.json"
        "$RUNNER_TEMP/login-hover-mouse" "$out/$case-geometry.json" "$out/$case-menu.json" away >> "$out/$case.log"
        screencapture -x -m "$out/$case-normal.png"; cp "$out/$case-geometry.json" "$out/$case-normal.json"
        "$RUNNER_TEMP/login-hover-mouse" "$out/$case-geometry.json" "$out/$case-menu.json" login >> "$out/$case.log"
        screencapture -x -m "$out/$case-highlighted.png"; cp "$out/$case-geometry.json" "$out/$case-highlighted.json"
        "$RUNNER_TEMP/login-hover-mouse" "$out/$case-geometry.json" "$out/$case-menu.json" jump-to-quit >> "$out/$case.log"
        screencapture -x -m "$out/$case-quit.png"
        cleanup
    done
done
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false' || true
