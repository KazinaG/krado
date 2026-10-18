#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# Optional file arguments allow checking a temporary translation without editing the repo.
english=${1:-"$repo_root/CHANGELOG.md"}
japanese=${2:-"$repo_root/CHANGELOG.ja.md"}
headings=$(mktemp -d "${TMPDIR:-/tmp}/krado-changelog.XXXXXX")
trap 'rm -rf "$headings"' 0
trap 'exit 1' HUP INT TERM
awk '/^## \[/' "$english" > "$headings/english"
awk '/^## \[/' "$japanese" > "$headings/japanese"
if [ ! -s "$headings/english" ] || [ ! -s "$headings/japanese" ]; then
    echo "Error: both changelogs must contain at least one ## [ heading." >&2
    diff -u "$headings/english" "$headings/japanese" || :
    exit 1
fi
if ! diff -u "$headings/english" "$headings/japanese"; then
    echo "Error: English and Japanese changelog headings differ." >&2
    exit 1
fi
