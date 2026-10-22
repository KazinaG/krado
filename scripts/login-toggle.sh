#!/usr/bin/env bash
# Disposable macOS CI only. No LaunchServices and no real login registration.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
    echo "error: this regression requires a macOS CI desktop" >&2
    exit 1
fi
mkdir -p login-toggle
out="$PWD/login-toggle"
app_pid=""
cleanup() {
    if [[ -n "$app_pid" ]]; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
        app_pid=""
    fi
}
trap cleanup EXIT
swiftc scripts/login-toggle-mouse.swift -o "$RUNNER_TEMP/login-toggle-mouse"
swiftc scripts/menu-shot-windows.swift -o "$RUNNER_TEMP/login-toggle-windows"
KRADO_CI_HOOKS=1 scripts/build-app.sh
capture() {
    local stem="$1"
    screencapture -x -m "$out/$stem.png"
    "$RUNNER_TEMP/login-toggle-windows" "$app_pid" "$out/$stem-windows.txt" > "$out/$stem-menu.json"
    python3 - "$out/geometry.json" "$out/$stem-menu.json" "$out/$stem.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
row['screenWidth'] = json.load(open(sys.argv[2]))['screenWidth']
with open(sys.argv[3], 'w') as f:
    json.dump(row, f)
PY
}
for initial in off on; do
    rm -f "$out/geometry.json"
    NSUnbufferedIO=YES KRADO_CI_LOGIN_FAKE="$initial" KRADO_CI_OPEN_MENU=1 \
        KRADO_CI_LOGIN_GEOMETRY="$out/geometry.json" \
        dist/krado.app/Contents/MacOS/krado -AppleLanguages '(ja)' -AppleLocale ja_JP \
        > "$out/$initial.log" 2>&1 &
    app_pid=$!
    sleep 5
    "$RUNNER_TEMP/login-toggle-mouse" "$out/geometry.json"
    sleep 1
    capture "$initial-fresh"
    cp "$out/$initial-fresh.png" "$out/$initial-before.png"
    "$RUNNER_TEMP/login-toggle-mouse" "$out/geometry.json" click
    sleep 1
    capture "$initial-after"
    grep -q 'KRADO_CI real login row click: fake state=' "$out/$initial.log"
    cleanup
done
python3 scripts/check-login-toggle.py "$out"
