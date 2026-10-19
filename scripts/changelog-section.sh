#!/bin/sh
set -eu

# Print the body of one CHANGELOG.md section, e.g. "0.1.0" or "Unreleased".
# Fails if the section is missing or empty, so a release cannot ship without notes.
version=${1:?usage: changelog-section.sh <version|Unreleased> [changelog]}
repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
changelog=${2:-"$repo_root/CHANGELOG.md"}
body=$(awk -v want="$version" '
    /^## \[/ {
        if (found) exit
        heading = $0
        sub(/^## \[/, "", heading)
        sub(/\].*$/, "", heading)
        if (heading == want) { found = 1; next }
    }
    found { print }
' "$changelog" | sed -e '/./,$!d')
if [ -z "$(printf '%s' "$body" | tr -d '[:space:]')" ]; then
    echo "Error: no non-empty ## [$version] section in $changelog." >&2
    exit 1
fi
printf '%s\n' "$body"
