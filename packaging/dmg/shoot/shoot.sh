#!/usr/bin/env bash
# CI runner only (GitHub macOS runner). Never run on a personal Mac: it rewrites Finder
# preferences and relaunches Finder. Opens each DMG in Finder in its default look (no path
# bar, no status bar, extensions hidden), screenshots the window at the display's backing
# scale, asks Finder where it put each item, and reads .DS_Store. Downloaded third-party
# DMGs stay in RUNNER_TEMP and are deleted right after; only screenshots/text are kept.
# Usage: shoot.sh <out dir> <list.tsv: name<TAB>url|github:owner/repo|file:path>
set -uo pipefail
out="$1"; list="$2"; mkdir -p "$out"; out="$(cd "$out" && pwd)"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; repo="$(cd "$here/../../.." && pwd)"
py="$repo/.build/dmgbuild-venv/bin/python"; work="${RUNNER_TEMP:-/tmp}/shoot"; mkdir -p "$work"
[ -x "$work/finder-windows" ] || swiftc -O -o "$work/finder-windows" "$here/../render/finder-windows.swift"
[ -x "$work/image-info" ] || swiftc -O -o "$work/image-info" "$here/image-info.swift"
defaults write com.apple.finder ShowPathbar -bool false
defaults write com.apple.finder ShowStatusBar -bool false
defaults write NSGlobalDomain AppleShowAllExtensions -bool false
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'
while IFS=$'\t' read -r name src; do
    [ "$name" = name ] && continue
    (
        dmg="$work/$name.dmg"; mnt=''; own=0
        trap '[ -z "$mnt" ] || hdiutil detach "$mnt" -force >/dev/null 2>&1; [ $own = 1 ] && rm -f "$dmg"' EXIT
        echo "== $name ($src)"
        case "$src" in
            file:*) dmg="${src#file:}" ;;
            github:*) own=1; url=$(gh api "repos/${src#github:}/releases/latest" --jq '[.assets[]|select(.name|test("\\.dmg$";"i"))][0].browser_download_url // empty')
                      [ -n "$url" ] || { echo "no dmg in latest release"; exit 0; }
                      curl -fsSL --max-time 600 -A "$UA" -o "$dmg" "$url" || { echo "download failed"; exit 0; } ;;
            *) own=1; curl -fsSL --max-time 600 -A "$UA" -o "$dmg" -w 'final URL: %{url_effective}\n' "$src" || { echo "download failed"; exit 0; } ;;
        esac
        hdiutil imageinfo "$dmg" > /dev/null 2>&1 || { echo "not a disk image"; exit 0; }
        killall Finder 2>/dev/null; sleep 3
        mnt=$(yes | hdiutil attach "$dmg" -readonly -noautoopen 2>/dev/null | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)
        [ -n "$mnt" ] || { echo "attach failed"; exit 0; }
        open "$mnt"; sleep 8
        "$work/finder-windows" | tee "$out/$name-windows.txt"
        id=$(awk -v v="$(basename "$mnt")" 'index($0,v){print $1; exit}' "$out/$name-windows.txt")
        [ -n "$id" ] || id=$(awk '{print $1; exit}' "$out/$name-windows.txt")
        screencapture -x "$out/$name-screen.png"
        [ -n "$id" ] && screencapture -x -o -l "$id" "$out/$name.png"
        { perl -e 'alarm 20; exec @ARGV' osascript -e 'tell application "Finder" to get {name, position} of every item of front Finder window'
          perl -e 'alarm 20; exec @ARGV' osascript -e 'tell application "Finder" to get bounds of front Finder window'
          perl -e 'alarm 20; exec @ARGV' osascript -e 'tell application "Finder" to get {icon size, text size} of icon view options of front Finder window'
        } > "$out/$name-finder.txt" 2>&1
        "$py" "$here/inspect-volume.py" "$mnt" "$work/image-info" > "$out/$name-dsstore.txt" 2>&1
        sips -g pixelWidth "$out/$name.png" 2>/dev/null | tail -1
    ) >> "$out/log.txt" 2>&1
done < "$list"
killall Finder 2>/dev/null || true
exit 0
