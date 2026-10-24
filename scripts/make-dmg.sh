#!/usr/bin/env bash
set -euo pipefail

# DMG_STYLE=B (default): krado's designed Finder window (packaging/dmg/B/), laid out
# by dmgbuild, which writes .DS_Store directly (no Finder, AppleScript or GUI).
# DMG_STYLE=plain: a plain window with an Applications shortcut (hdiutil only).
# DMGBUILD=<path> uses an existing dmgbuild; otherwise a pinned, hash-checked copy
# is installed into .build/dmgbuild-venv (build machine only).
# A plain or ad-hoc DMG is refused unless KRADO_UNSIGNED_DMG_OK=1 (layout experiments
# only, never for a trial or a release): ad hoc changes the designated requirement on
# every build, so Accessibility shows a second krado. Trial DMGs: docs/trial-build.ja.md.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
style="${DMG_STYLE:-B}"
case "$style" in plain) ;; *) [ -f "$repo_root/packaging/dmg/$style/background@2x.png" ] || { echo "Unknown DMG_STYLE $style (no packaging/dmg/$style/)." >&2; exit 2; } ;; esac
if [ "${SKIP_APP_BUILD:-0}" != 1 ]; then "$repo_root/scripts/build-app.sh"; fi
bundle="$repo_root/dist/krado.app"
if [ "${KRADO_UNSIGNED_DMG_OK:-0}" != 1 ]; then
    if [ "$style" = plain ] || codesign -dv "$bundle" 2>&1 | grep -q '^Signature=adhoc'; then
        echo "error: plain or ad-hoc DMG refused (set KRADO_SIGN_IDENTITY and keep DMG_STYLE=B;" >&2
        echo "       trial DMGs come from the Release workflow, see docs/trial-build.ja.md)." >&2
        exit 3
    fi
fi
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")"
output_dir="${OUTPUT_DIR:-$repo_root/dist}"
mkdir -p "$output_dir"
dmg="$output_dir/${DMG_NAME:-krado-$version.dmg}"

if [ "$style" = plain ]; then
    staging="$(mktemp -d "${TMPDIR:-/tmp}/krado-dmg.XXXXXX")"
    trap 'rm -rf "$staging"' EXIT
    # Preserve the app's framework symlinks and signatures.
    ditto "$bundle" "$staging/krado.app"
    ln -s /Applications "$staging/Applications"
    hdiutil create -volname "krado $version" -srcfolder "$staging" -ov -format UDZO "$dmg"
else
    dmgdir="$repo_root/packaging/dmg"
    dmgbuild_bin="${DMGBUILD:-}"
    if [ -z "$dmgbuild_bin" ]; then
        venv="$repo_root/.build/dmgbuild-venv"
        [ -x "$venv/bin/dmgbuild" ] || {
            python3 -m venv "$venv"
            "$venv/bin/pip" install --quiet --disable-pip-version-check --require-hashes --no-deps \
                -r "$dmgdir/requirements.txt"
        }
        dmgbuild_bin="$venv/bin/dmgbuild"
    fi
    rm -f "$dmg"
    "$dmgbuild_bin" -s "$dmgdir/settings.py" \
        -D app="$bundle" -D style="$style" -D dmgdir="$dmgdir" \
        -D volume_icon="$repo_root/Resources/AppIcon.icns" \
        "krado $version" "$dmg"
fi
# The app inside must keep its signature (ditto preserves it in both paths).
echo "Built $dmg (style $style, not mounted)."
