#!/usr/bin/env bash
# Disposable macOS CI only. Opens krado's real menu and puts the real pointer on the
# Status rows (Kazina 10/26 03:33: information rows cannot be chosen, so they never
# highlight). Accessibility while permission is needed stays choosable and opens the
# guide. Screenshots and AX readings go to status-rows/; check-status-rows.py judges them.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo "error: needs a macOS CI desktop" >&2; exit 1; }
out="$PWD/status-rows"; mkdir -p "$out"
app_pid=""
cleanup() {
    if [[ -n "$app_pid" ]]; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
        app_pid=""
    fi
}
trap cleanup EXIT
swiftc scripts/status-rows-mouse.swift -o "$RUNNER_TEMP/status-rows-mouse"
swiftc scripts/menu-shot-windows.swift -o "$RUNNER_TEMP/status-rows-windows"
[[ -x dist/krado.app/Contents/MacOS/krado ]] || KRADO_CI_HOOKS=1 scripts/build-app.sh
mouse() { "$RUNNER_TEMP/status-rows-mouse" "$@"; }
# One line per menu item: name (newlines as " / "), x, y, width, height, enabled.
ax_items() {
    osascript <<'OSA'
tell application "System Events" to tell process "krado"
    set out to ""
    repeat with mi in (every menu item of menu 1 of menu bar item 1 of last menu bar)
        set n to ""
        try
            set n to (name of mi) as text
        end try
        set AppleScript's text item delimiters to {return, linefeed}
        set parts to text items of n
        set AppleScript's text item delimiters to " / "
        set n to parts as text
        set AppleScript's text item delimiters to ""
        set p to position of mi
        set s to size of mi
        set out to out & n & tab & (item 1 of p) & tab & (item 2 of p) & tab & (item 1 of s) & tab & (item 2 of s) & tab & (enabled of mi) & linefeed
    end repeat
    return out
end tell
OSA
}
for appearance in Light Dark; do
    dark=false
    if [[ "$appearance" == Dark ]]; then dark=true; fi
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark"
    sleep 2
    for permission in permissionGranted permissionNeeded; do
        case="$(tr '[:upper:]' '[:lower:]' <<< "$appearance")-$permission"
        NSUnbufferedIO=YES KRADO_CI_STATE="$permission" KRADO_CI_OPEN_MENU=1 \
            dist/krado.app/Contents/MacOS/krado -AppleLanguages '(ja)' -AppleLocale ja_JP > "$out/$case-app.log" 2>&1 &
        app_pid=$!
        sleep 5
        "$RUNNER_TEMP/status-rows-windows" "$app_pid" "$out/$case-windows.txt" > "$out/$case-menu.json"
        ax_items > "$out/$case-items.tsv"
        mouse move 5 500
        screencapture -x -m "$out/$case-0-fresh.png"
        # Each Status row in turn: the permission row, then the monitor row.
        for row in 1 2; do
            line="$(sed -n "$((row + 1))p" "$out/$case-items.tsv")"
            IFS=$'\t' read -r name x y w h enabled <<< "$line"
            echo "row$row=$name enabled=$enabled" >> "$out/$case-rows.txt"
            mouse move "$((x + w / 2))" "$((y + h / 2))"
            screencapture -x -m "$out/$case-row$row.png"
            mouse move 5 500
        done
        if [[ "$permission" == permissionNeeded ]]; then
            IFS=$'\t' read -r name x y w h enabled <<< "$(sed -n 2p "$out/$case-items.tsv")"
            mouse click "$((x + w / 2))" "$((y + h / 2))"
            sleep 1
        fi
        cleanup
    done
done
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false' || true
python3 scripts/check-status-rows.py "$out"
