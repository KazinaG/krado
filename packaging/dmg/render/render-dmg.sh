#!/usr/bin/env bash
# CI runner only (GitHub macOS runner with a logged-in GUI session). Never run this on
# a personal Mac: it rewrites Finder preferences and relaunches Finder.
# Opens a DMG in Finder the way a user does and screenshots the window twice:
#   default: Path Bar, Status Bar and "Show all filename extensions" off
#   bars:    all three on (global user preferences that .DS_Store cannot override)
# Scroll bars are forced to "Always" in both, so a scrollable window is visible.
# Fails when no Finder window opens, or (with <expected height>) when Finder did not
# give the window the frame height written into .DS_Store. Whether anything is cut off
# is judged by looking at the PNGs (uploaded as artifacts).
# Usage: render-dmg.sh <dmg> <out dir> <name> [expected window height in pt]
set -euo pipefail
dmg="$1"; out="$2"; name="$3"; expected="${4:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$out"
lister="${RUNNER_TEMP:-/tmp}/finder-windows"
[ -x "$lister" ] || swiftc -O -o "$lister" "$here/finder-windows.swift"
defaults write NSGlobalDomain AppleShowScrollBars -string Always
for cfg in default bars; do
    on=false; [ "$cfg" = bars ] && on=true
    defaults write com.apple.finder ShowPathbar -bool "$on"
    defaults write com.apple.finder ShowStatusBar -bool "$on"
    defaults write NSGlobalDomain AppleShowAllExtensions -bool "$on"
    killall Finder 2>/dev/null || true
    sleep 4
    mnt=$(hdiutil attach "$dmg" -readonly -noautoopen | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)
    open "$mnt"
    sleep 6
    "$lister" | tee "$out/$name-$cfg-windows.txt"
    id=$("$lister" | awk -v v="$(basename "$mnt")" '$6==v{print $1; exit}')
    [ -n "$id" ] || id=$("$lister" | awk '{print $1; exit}')
    screencapture -x "$out/$name-$cfg-screen.png"
    [ -n "$id" ] || { echo "::error::$name ($cfg): no Finder window opened."; exit 1; }
    screencapture -x -o -l "$id" "$out/$name-$cfg.png"
    test -s "$out/$name-$cfg.png"
    height=$("$lister" | awk -v i="$id" '$1==i{print $5; exit}')
    if [ -n "$expected" ] && [ "$height" != "$expected" ]; then
        echo "::error::$name ($cfg): Finder window is $height pt tall, expected $expected pt."; exit 1
    fi
    killall Finder 2>/dev/null || true
    sleep 2
    hdiutil detach "$mnt" -force > /dev/null || true
done
ls -la "$out"
