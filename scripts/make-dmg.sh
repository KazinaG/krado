#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$repo_root/scripts/build-app.sh"
bundle="$repo_root/dist/krado.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")"
output_dir="${OUTPUT_DIR:-$repo_root/dist}"
mkdir -p "$output_dir"
staging="$(mktemp -d "${TMPDIR:-/tmp}/krado-dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
# Preserve the app's framework symlinks and signatures.
ditto "$bundle" "$staging/krado.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname krado -srcfolder "$staging" -ov -format UDZO \
    "$output_dir/krado-$version.dmg"
echo "Built $output_dir/krado-$version.dmg (not mounted)."
