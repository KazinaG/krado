#!/usr/bin/env bash
# CI only. Inherit the runner shell's existing grants; never edit TCC.
set -uo pipefail
lab="$PWD/dist/MotionLab"
mkdir -p dist/video dist/logs
# Hosted runners ship with Reduce Motion / Reduce Transparency on; record them (krado honours them; the lab build ignores Reduce Motion).
for key in reduceMotion reduceTransparency; do echo "$key=$(defaults read com.apple.universalaccess $key 2>&1 | tail -1)"; done > dist/logs/accessibility-settings.log
"$lab" screen | tee dist/logs/screen.log
read -r sx sy sw sh < <("$lab" screen | tail -1)
if [[ -z "${sh:-}" ]]; then
    echo 'No screen available; capture skipped' >&2
    exit 0
fi
# GridPolicy can yield 1x1 on a 1024-point display. Fractions still exercise
# target appearance and snap; screen.log explicitly records that limitation.
left=$((sx + sw / 6))
right=$((sx + sw * 5 / 6))
cy=$((sy + sh / 2))
upper=$((sy + sh / 3))
px=$((sx + sw / 8))
py=$((sy + sh / 8))
pw=$((sw * 2 / 3))
ph=$((sh * 2 / 3))
# Probe before starting a scenario so still capture is ready before the drag.
video_supported=0
if screencapture -v -V 1 -x dist/video/probe.mov >dist/logs/video-probe.log 2>&1; then
    video_supported=1
fi
krado_pid=''
cleanup() {
    if [[ -n "$krado_pid" ]]; then
        kill "$krado_pid" 2>/dev/null || true
        wait "$krado_pid" 2>/dev/null || true
        krado_pid=''
    fi
}
trap cleanup EXIT
capture() {
    local name="$1"
    # Video often fails on hosted runners. Keep both the failure log and stills.
    if [[ "$video_supported" != 1 ]] || ! screencapture -v -V 8 -x "dist/video/$name.mov" >"dist/logs/$name-capture.log" 2>&1; then
        mkdir -p "dist/video/$name-stills"
        for ((i=0; i<240; i++)); do
            screencapture -x "dist/video/$name-stills/$(printf '%04d' "$i").png" 2>>"dist/logs/$name-capture.log" || break
            sleep 0.033
        done
    fi
}
KRADO_LAB_IGNORE_REDUCE_MOTION=1 KRADO_LAB_GRID=2x2 KRADO_LAB_LOG=1 NSUnbufferedIO=YES "dist/krado.app/Contents/MacOS/krado" -AppleLanguages '(ja)' >"dist/logs/krado.log" 2>&1 &
krado_pid=$!
sleep 3
for scenario in cell-crossing snap; do
    "$lab" place com.apple.TextEdit "$px" "$py" "$pw" "$ph" >"dist/logs/$scenario-place.log" 2>&1 || continue
    sleep 0.5
    "$lab" windows TextEdit >>"dist/logs/$scenario-place.log" 2>&1
    # Read back the actual frame: TextEdit may impose a minimum size.
    actual=$(tail -n 1 < <("$lab" place com.apple.TextEdit "$px" "$py" "$pw" "$ph"))
    title=$(python3 -c 'import json,sys; r=json.loads(sys.argv[1]); print(round(r[0]+min(120,r[2]/2)),round(r[1]+12))' "$actual") || continue
    read -r tx ty <<< "$title"
    capture "$scenario" &
    capture_pid=$!
    sleep 0.5
    if [[ "$scenario" == cell-crossing ]]; then
        # Lab grid is 2 x 2: top-left -> top-right -> bottom-right -> bottom-left (hold), crossing three borders.
        "$lab" drag "$tx" "$ty" "$((sx + sw / 4))" "$((sy + sh * 2 / 3))" 3 --via "$((sx + sw / 4)),$((sy + sh / 3))" "$((sx + sw * 3 / 4)),$((sy + sh / 3))" "$((sx + sw * 3 / 4)),$((sy + sh * 2 / 3))" --hold 0.6 >"dist/logs/$scenario-drag.log" 2>&1 || true
    else
        "$lab" drag "$tx" "$ty" "$((sx + sw * 3 / 4))" "$((sy + sh * 2 / 3))" 0.5 --hold 0.3 >"dist/logs/$scenario-drag.log" 2>&1 || true
    fi
    sleep 1
    wait "$capture_pid" || true
done
cleanup
