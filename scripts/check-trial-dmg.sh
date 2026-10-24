#!/usr/bin/env bash
# 試し版・リリースの DMG が「いつもの形」かを確かめる（macOS、画面は出さない）。
#   scripts/check-trial-dmg.sh <krado.dmg> [期待する版番号]
# 見た目つきの窓（.DS_Store・背景・ボリュームアイコン・Applications へのリンク）、
# bundle id、固定の「krado Self-Signed」証明書の署名要件（DR）を確かめる。
# plain の DMG や ad-hoc 署名（DR が cdhash）なら失敗する。ad-hoc だとビルドごとに
# アクセシビリティの許可が外れ、一覧に krado が増えるため。
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
    [ -f "$mnt/$f" ] || fail "$f がない（plain の DMG。DMG_STYLE=B で作る）"
done
[ -L "$mnt/Applications" ] || fail "Applications へのリンクがない"
app="$mnt/krado.app"
[ -d "$app" ] || fail "krado.app がない"
id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")"
[ "$id" = "$bundle_id" ] || fail "bundle id が $id（期待 $bundle_id）"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
if [ -n "$want_version" ] && [ "$version" != "$want_version" ]; then
    fail "版番号が $version（期待 $want_version）"
fi
codesign --verify --deep --strict "$app" || fail "署名の検証に失敗"
dr="$(codesign -d -r- "$app" 2>&1 | sed -n 's/^designated => //p')"
[ "$dr" = "$expected_dr" ] || fail "署名要件が違う（ad-hoc か別の証明書）：$dr"
echo "OK: krado $version / $id / 見た目つきDMG / $dr"
