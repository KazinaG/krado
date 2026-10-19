#!/usr/bin/env bash
# Gatekeeper first-launch check, as a user who downloaded the DMG in a browser sees it.
#
#   scripts/check-gatekeeper.sh <krado-x.y.z.dmg> <expected>
#
# expected: "rejected"  self-signed, not notarized (today): macOS blocks the first
#                       launch and users need the README's "Open Anyway" steps.
#           "accepted"  Developer ID + notarized: must be "source=Notarized Developer ID".
# The app is copied out of the image and given a browser-style quarantine attribute,
# then assessed with spctl (and syspolicy_check when the runner has it). Exits non-zero
# when the result differs from <expected>, so a signing change can't slip by unnoticed.
set -euo pipefail

dmg=${1:?usage: check-gatekeeper.sh <dmg> <rejected|accepted>}
expected=${2:?usage: check-gatekeeper.sh <dmg> <rejected|accepted>}
case "$expected" in rejected|accepted) ;; *) echo "expected must be rejected or accepted" >&2; exit 2 ;; esac

work=$(mktemp -d)
mnt="$work/mnt"
mkdir "$mnt"
cleanup() { hdiutil detach "$mnt" -quiet 2>/dev/null || true; rm -rf "$work"; }
trap cleanup EXIT

# Same attribute format Safari writes: flags;hex time;agent;UUID.
quarantine="0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)"

hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mnt" -quiet
ditto "$mnt/krado.app" "$work/krado.app"
hdiutil detach "$mnt" -quiet
xattr -w -r com.apple.quarantine "$quarantine" "$work/krado.app" 2>/dev/null \
  || find "$work/krado.app" -exec xattr -w com.apple.quarantine "$quarantine" {} \;
xattr -p com.apple.quarantine "$work/krado.app" > /dev/null

echo "== codesign"
codesign -dv --verbose=2 "$work/krado.app" 2>&1 | grep -E '^(Identifier|Authority|TeamIdentifier)' || true

echo "== spctl --assess --type execute -vv"
set +e
spctl_out=$(spctl --assess --type execute -vv "$work/krado.app" 2>&1)
spctl_status=$?
set -e
echo "$spctl_out"
echo "exit status: $spctl_status"

if command -v syspolicy_check > /dev/null; then
  echo "== syspolicy_check distribution"
  syspolicy_check distribution "$work/krado.app" 2>&1 || true
fi

if [ "$spctl_status" -eq 0 ]; then actual=accepted; else actual=rejected; fi
if [ "$actual" = accepted ] && ! grep -q 'source=Notarized Developer ID' <<< "$spctl_out"; then
  echo "::error::Accepted, but not as a notarized Developer ID app." && exit 1
fi

summary="Gatekeeper first launch of $(basename "$dmg"): **$actual** (expected $expected). $(grep '^source=' <<< "$spctl_out" || true)"
echo "$summary"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "$summary" >> "$GITHUB_STEP_SUMMARY"

if [ "$actual" != "$expected" ]; then
  echo "::error::Gatekeeper result is $actual, expected $expected. Update the README first-launch steps and this expectation together."
  exit 1
fi
