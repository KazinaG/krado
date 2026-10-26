#!/usr/bin/env bash
# Check that a trial or release DMG has the expected layout (macOS, headless).
#   scripts/check-trial-dmg.sh <krado.dmg> [expected version]
# Check the designed window (.DS_Store, background, volume icon, and Applications link),
# bundle ID, and designated requirement (DR) for the fixed "krado Self-Signed" certificate.
# Fail for a plain DMG or an ad-hoc signature (a cdhash-based DR). Ad-hoc signing
# resets Accessibility permission on each build and adds duplicate krado entries.
set -euo pipefail

bundle_id="io.github.kazinag.krado"
# Public hash of the release certificate (docs/signing-and-update-test.md). Never regenerate it.
expected_dr="identifier \"$bundle_id\" and certificate leaf = H\"ed2ab20fcf3c07e239daa7022457377caf8efc65\""

dmg="${1:?usage: scripts/check-trial-dmg.sh <krado.dmg> [version]}"
want_version="${2:-}"
mnt="$(mktemp -d "${TMPDIR:-/tmp}/krado-check.XXXXXX")"
hdiutil attach "$dmg" -nobrowse -readonly -noverify -mountpoint "$mnt" >/dev/null
trap 'hdiutil detach "$mnt" >/dev/null 2>&1 || hdiutil detach -force "$mnt" >/dev/null 2>&1; rmdir "$mnt" 2>/dev/null || true' EXIT

fail() { echo "NG: $*" >&2; exit 1; }
for f in .DS_Store .background.tiff .VolumeIcon.icns; do
    [ -f "$mnt/$f" ] || fail "$f is missing (plain DMG; build with DMG_STYLE=B)"
done
[ -L "$mnt/Applications" ] || fail "Applications link is missing"
app="$mnt/krado.app"
[ -d "$app" ] || fail "krado.app is missing"
id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")"
[ "$id" = "$bundle_id" ] || fail "bundle ID is $id (expected $bundle_id)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
if [ -n "$want_version" ] && [ "$version" != "$want_version" ]; then
    fail "version is $version (expected $want_version)"
fi
codesign --verify --deep --strict "$app" || fail "signature verification failed"
dr="$(codesign -d -r- "$app" 2>&1 | sed -n 's/^designated => //p')"
[ "$dr" = "$expected_dr" ] || fail "designated requirement mismatch (ad-hoc signing or a different certificate): $dr"
echo "OK: krado $version / $id / designed DMG / $dr"
