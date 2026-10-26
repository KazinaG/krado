#!/usr/bin/env bash
# Disposable macOS CI only. Opens krado's real menu and moves the real pointer:
# Launch at Login → Quit (slow and in one jump), and keyboard Down while the pointer
# rests on the row. Screenshots go to login-hover/; check-login-hover.py judges them.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo "error: needs a macOS CI desktop" >&2; exit 1; }
out="$PWD/login-hover"; mkdir -p "$out"
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
mouse() { "$RUNNER_TEMP/login-hover-mouse" "$out/$case-geometry.json" "$out/$case-menu.json" "$1" >> "$out/$case.log"; }
shot() {
    screencapture -x -m "$out/$case-$1.png"
    cp "$out/$case-geometry.json" "$out/$case-$1.json"
}
# case: name, appearance (Light/Dark), accent (AppleAccentColor; empty = default blue)
for spec in light-blue:Light: dark-blue:Dark: light-yellow:Light:2 dark-graphite:Dark:-1 light-pink:Light:6; do
    IFS=: read -r case appearance accent <<< "$spec"
    args=(-AppleLanguages '(ja)' -AppleLocale ja_JP)
    # Menu-bar menus follow the system appearance, so switch the runner itself.
    dark=false
    if [[ "$appearance" == Dark ]]; then dark=true; fi
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark"
    sleep 2
    echo "$case dark mode: $(defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light)" >> "$out/environment.txt"
    if [[ -n "$accent" ]]; then args+=(-AppleAccentColor "$accent"); fi
    # Graphite also needs the graphite Aqua variant.
    if [[ "$accent" == -1 ]]; then args+=(-AppleAquaColorVariant 6); fi
    appearance_case=$case
    for state in off on; do
        case="$appearance_case-$state"
        for path in slow-to-quit jump-to-quit down click-stay; do
            rm -f "$out/$case-geometry.json"
            NSUnbufferedIO=YES KRADO_CI_LOGIN_FAKE="$state" KRADO_CI_OPEN_MENU=1 \
                KRADO_CI_LOGIN_GEOMETRY="$out/$case-geometry.json" \
                dist/krado.app/Contents/MacOS/krado "${args[@]}" > "$out/$case-$path-app.log" 2>&1 &
            app_pid=$!
            sleep 5
            "$RUNNER_TEMP/login-hover-windows" "$app_pid" "$out/$case-windows.txt" > "$out/$case-menu.json"
            mouse away; shot "$path-0-fresh"
            mouse login; shot "$path-1-login"
            mouse "$path"; shot "$path-2-after"
            if [[ "$path" == click-stay ]]; then
                grep -q 'KRADO_CI real login row click: fake state=' "$out/$case-$path-app.log"
                mouse jump-to-quit; shot "$path-3-left"
            fi
            cleanup
        done
    done
done
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false' || true
# Anywhere on the row toggles exactly once and the menu stays open (Kazina 10/26 01:53):
# one launch, Off at first, then a click at the left edge, the capsule and the right edge.
# Its evidence is named *.geo.json so check-login-hover.py's *-geometry.json cases skip it.
case=click-anywhere
geo="$out/$case.geo.json"
rm -f "$geo"
NSUnbufferedIO=YES KRADO_CI_LOGIN_FAKE=off KRADO_CI_OPEN_MENU=1 \
    KRADO_CI_LOGIN_GEOMETRY="$geo" \
    dist/krado.app/Contents/MacOS/krado -AppleLanguages '(ja)' -AppleLocale ja_JP > "$out/$case-app.log" 2>&1 &
app_pid=$!
sleep 5
"$RUNNER_TEMP/login-hover-windows" "$app_pid" "$out/$case-windows.txt" > "$out/$case-menu.json"
anywhere() { "$RUNNER_TEMP/login-hover-mouse" "$geo" "$out/$case-menu.json" "$1" >> "$out/$case.log"; }
anywhere login
expected=(true false true)
n=0
anywhere_failed=0
for where in click-left click-capsule click-right; do
    anywhere "$where"; screencapture -x -m "$out/$case-$where.png"
    n=$((n + 1))
    clicks=$(grep -c 'KRADO_CI real login row click: fake state=' "$out/$case-app.log" || true)
    last=$(grep 'KRADO_CI real login row click: fake state=' "$out/$case-app.log" | tail -1 | sed 's/.*fake state=//')
    state=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("state"))' "$geo")
    echo "$where: clicks=$clicks last=$last capsule=$state" | tee -a "$out/click-anywhere.txt"
    want=$([[ "${expected[$((n - 1))]}" == true ]] && echo on || echo off)
    if [[ "$clicks" != "$n" || "$last" != "${expected[$((n - 1))]}" || "$state" != "$want" ]]; then
        echo "error: $where did not toggle exactly once with the menu open" >&2
        anywhere_failed=1
    fi
done
cleanup
python3 scripts/check-login-hover.py "$out"
exit "$anywhere_failed"
