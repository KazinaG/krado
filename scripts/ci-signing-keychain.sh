#!/usr/bin/env bash
# CI only. Imports the "krado Self-Signed" identity into a throwaway keychain on the
# GitHub Actions runner, or deletes that keychain. Never touches a login keychain and
# never prints the certificate, its key or any password.
#
#   import:  needs KRADO_SIGNING_P12_BASE64 and KRADO_SIGNING_P12_PASSWORD; appends
#            KRADO_SIGN_IDENTITY and KRADO_SIGN_KEYCHAIN to $GITHUB_ENV.
#   cleanup: deletes the temporary keychain (run with `if: always()`).
set -euo pipefail

: "${RUNNER_TEMP:?CI only: RUNNER_TEMP is not set}"
keychain="$RUNNER_TEMP/krado-signing.keychain-db"
identity_name="krado Self-Signed"

case "${1:-}" in
import)
    : "${KRADO_SIGNING_P12_BASE64:?secret KRADO_SIGNING_P12_BASE64 is not available}"
    : "${KRADO_SIGNING_P12_PASSWORD:?secret KRADO_SIGNING_P12_PASSWORD is not available}"
    umask 077
    p12="$RUNNER_TEMP/krado-signing.p12"
    trap 'rm -f "$p12"' EXIT
    printf '%s' "$KRADO_SIGNING_P12_BASE64" | base64 --decode > "$p12"
    keychain_password="$(openssl rand -hex 24)"
    echo "::add-mask::$keychain_password"
    security create-keychain -p "$keychain_password" "$keychain"
    security set-keychain-settings -lut 3600 "$keychain"
    security unlock-keychain -p "$keychain_password" "$keychain"
    security import "$p12" -k "$keychain" -f pkcs12 -P "$KRADO_SIGNING_P12_PASSWORD" \
        -T /usr/bin/codesign >/dev/null
    # Let codesign use the key without a GUI prompt.
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
        -k "$keychain_password" "$keychain" >/dev/null
    # Search list for this user session on the runner: the temporary keychain first.
    existing=()
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"; line="${line%\"}"; line="${line#\"}"
        [[ -n "$line" && "$line" != "$keychain" ]] && existing+=("$line")
    done < <(security list-keychains -d user)
    security list-keychains -d user -s "$keychain" "${existing[@]}"
    # Self-signed identities are untrusted, so no -v. Pick the certificate by SHA-1.
    hash="$(security find-identity -p codesigning "$keychain" \
        | awk -v name="\"$identity_name\"" 'index($0, name) { print $2; exit }')"
    if [[ ! "$hash" =~ ^[0-9A-F]{40}$ ]]; then
        echo "::error::No \"$identity_name\" code-signing identity in the imported p12." >&2
        exit 1
    fi
    echo "Imported \"$identity_name\" ($hash) into a temporary keychain."
    {
        echo "KRADO_SIGN_IDENTITY=$hash"
        echo "KRADO_SIGN_KEYCHAIN=$keychain"
    } >> "${GITHUB_ENV:?CI only: GITHUB_ENV is not set}"
    ;;
cleanup)
    if [[ -e "$keychain" ]]; then
        security delete-keychain "$keychain"
        echo "Deleted the temporary signing keychain."
    fi
    rm -f "$RUNNER_TEMP/krado-signing.p12"
    ;;
*)
    echo "usage: $0 import|cleanup" >&2
    exit 2
    ;;
esac
