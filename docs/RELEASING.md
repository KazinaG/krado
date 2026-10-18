# Releasing krado

No version has been released yet. [CHANGELOG.md](../CHANGELOG.md) is the source of
truth; keep the Japanese translation's `## [...]` headings byte-identical.

## Update feed

`SUFeedURL` is `https://github.com/KazinaG/krado/releases/latest/download/appcast.xml`.
Upload `appcast.xml` alongside the DMG as an asset of every GitHub Release. GitHub's
latest-release redirect provides a stable feed URL without GitHub Pages. Enclosure
URLs inside the feed must use the specific release's `/releases/download/<tag>/`
asset URLs, so older feed entries keep pointing to the correct downloads.

The public key is currently `KRADO_SPARKLE_PUBLIC_KEY_PLACEHOLDER`. No updater is
created until a valid Ed25519 public key and HTTPS feed are configured. The menu
item stays disabled and `SUEnableAutomaticChecks` defaults to false.

## One-time setup — owner approval required

The owner must approve key generation and Keychain access before running Sparkle's
`generate_keys`. Run it only as an explicit future owner action, keep the private
key safe, and replace the placeholder `SUPublicEDKey` in `scripts/build-app.sh`
with the public key. Never commit private keys. Review the setup guide's privacy
text before enabling network update checks in a released build.

Sparkle EdDSA archive signatures are separate from Apple Developer ID signing and
notarization. The current build script uses ad-hoc signing only; it does not provide
Developer ID signing or notarization. See [Sparkle setup](https://sparkle-project.org/documentation/)
for signing and distribution requirements. No signing keys are created by the
build or DMG scripts.

## Future release checklist

1. Bump both `CFBundleShortVersionString` and `CFBundleVersion` in the Info.plist
   heredoc in `scripts/build-app.sh`, following Semantic Versioning and increasing
   the build version.
2. Move the contents of Unreleased to the chosen version and actual release date
   in both changelogs; keep a new `## [Unreleased]` section. Run
   `scripts/check-changelog-headings.sh` and `swift test --disable-keychain`.
3. Run `scripts/make-dmg.sh` to build `dist/krado-<version>.dmg` (or use
   `OUTPUT_DIR=/path/to/output`). It does not mount the image or open Finder.
   Verify the app's signature and framework linkage. Developer ID signing and
   notarization, when available, must happen before final packaging/signing.
4. With separately approved access to the owner's signing key, use Sparkle's
   `sign_update` to sign the final DMG and put its EdDSA signature and byte length
   in the appcast, or use `generate_appcast` to sign archives and generate the feed.
   These tools are in Sparkle's distribution `bin` directory (SwiftPM artifacts
   may also include them). For example, generate a feed from a release directory
   containing the final DMG using:

   ```sh
   /path/to/Sparkle/bin/generate_appcast --download-url-prefix "https://github.com/KazinaG/krado/releases/download/<tag>/" /path/to/release-directory
   ```

   Check the tool's help for the installed version. Inspect the generated
   `appcast.xml`: its version, HTTPS enclosure URL, signature, and length must
   match the final asset. Do not modify the DMG after signing. Upload any delta
   archives too if the feed references them.
5. After the owner approves publication, create the GitHub Release for that
   version and upload the DMG and `appcast.xml` together. Confirm the stable feed
   URL resolves to this appcast and that the enclosure downloads correctly.
   In a separately authorized manual session, verify updating from an older
   configured build before declaring updates ready.
