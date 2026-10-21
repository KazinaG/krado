# Releasing krado

The first public release was v0.1.0 (2026-10-19). Never move or rewrite the tag
of a published release. [CHANGELOG.md](../CHANGELOG.md) is the source of truth; keep the Japanese translation's `## [...]` headings byte-identical.

Distribution is a DMG attached to a GitHub Release plus a Sparkle 2 appcast. There
is no Homebrew tap.

Local preparation for the next version is tracked in [NEXT_RELEASE.md](NEXT_RELEASE.md).
The build default is 0.1.6, but the release scope and dated notes are not final.
The active preparation branch is based on GitHub main and changes only DMG assets
and tools, version metadata and documentation. Earlier study branches retain motion trial A;
do not merge those wholesale. Do not tag or package a final candidate until the
scope and verification gates in that checklist are resolved.

## Update feed

`SUFeedURL` is `https://github.com/KazinaG/krado/releases/latest/download/appcast.xml`.
`appcast.xml` is uploaded alongside the DMG as an asset of every GitHub Release.
GitHub's `releases/latest` redirect always points at the newest **published**,
non-prerelease release, so:

- the feed URL never changes and needs no GitHub Pages site or bot commits to `main`;
- a draft release is invisible to the feed until it is published, which
  makes "Publish release" the single go-live switch.

Enclosure URLs inside the feed use the specific release's
`/releases/download/<tag>/` asset URL, so an entry always points at its own DMG.
Each feed contains only the newest version, which is all Sparkle needs to offer
an update (no delta updates are generated).

## Signing key

Updates are signed with an Ed25519 (EdDSA) key in Sparkle 2's format:

- `SUPublicEDKey` in `scripts/build-app.sh` is the base64 of the 32-byte public key.
- The private key is the base64 of the 32-byte seed, the same format
  `generate_keys -x` exports and `sign_update`/`generate_appcast --ed-key-file`
  read. It is stored only in the repository's Actions secret
  `SPARKLE_ED_PRIVATE_KEY` (and the maintainer's offline backup). It is never
  committed, and the workflow passes it to Sparkle's tools through standard
  input (`--ed-key-file -`), never as an argument or a file.

Losing the private key means existing installs can no longer verify updates.
Sparkle accepts an update when either its EdDSA signature or its code signature
matches the installed app, so with the stable code-signing certificate below a key
rotation is possible in principle; it has not been tested, so keep the backup safe.

## Code-signing certificate

Release builds are signed with the self-signed `krado Self-Signed` certificate so
the Accessibility permission survives updates. The p12 and its password are the
Actions secrets `KRADO_SIGNING_P12_BASE64` and `KRADO_SIGNING_P12_PASSWORD`;
`scripts/ci-signing-keychain.sh` imports them into a temporary keychain on the
runner and deletes it at the end of the job. Never regenerate it. Details, the
update-test feed and the uninstall file list:
[signing-and-update-test.md](signing-and-update-test.md).

## Release workflow

[`.github/workflows/release.yml`](../.github/workflows/release.yml):

- **Tag `v<version>` pushed:** runs the changelog check and tests, builds the DMG
  with `scripts/make-dmg.sh`, checks that the tag matches
  `CFBundleShortVersionString`, takes the notes from the `## [<version>]` section
  of `CHANGELOG.md` (`scripts/changelog-section.sh`), signs the DMG and writes
  `appcast.xml` with Sparkle's `generate_appcast`, verifies the signature, length
  and URL, then creates a **draft** GitHub Release with the DMG and appcast.
- **Tag `v<version>-test` pushed:** builds update-test build B with
  `KRADO_VERSION=<version>`, writes `appcast-test.xml`, and creates a **draft
  pre-release**. See [signing-and-update-test.md](signing-and-update-test.md).
- **Branch push touching release files:** the same build, signing and
  verification as a dry run; the files are kept only as a workflow artifact.

Sparkle's tools come from the checksum-pinned Sparkle SwiftPM artifact
(`.build/artifacts/.../Sparkle/bin`), matching the framework version in
`Package.resolved`.

## Release checklist

1. Bump the default version (`version="${KRADO_VERSION:-…}"`) in
   `scripts/build-app.sh`; it sets both `CFBundleShortVersionString` and
   `CFBundleVersion`. Follow Semantic Versioning.
2. Move the contents of Unreleased to `## [<version>] - <date>` in both
   changelogs and keep a new empty `## [Unreleased]` section. Run
   `scripts/check-changelog-headings.sh` and `swift test --disable-keychain`.
3. Merge to `main`, then push the tag `v<version>` on that commit (maintainer
   approval required).
4. Wait for the Release workflow. Its `render` job opens the built DMG in Finder on
   macOS 15 and 26, with default Finder settings and with Path Bar, Status Bar and
   filename extensions on; look at the `render-<os>` screenshots (nothing cut off, no
   scroll bar, labels inside their cards). The draft is only created after it passes.
   Download the draft's DMG and check it on a Mac.
5. **Gatekeeper first launch (quarantined download).** The
   [Gatekeeper workflow](../.github/workflows/gatekeeper.yml) runs after every Release
   run on the DMG it built: it copies `krado.app` out of the image, adds a Safari-style
   `com.apple.quarantine` attribute, and runs `spctl --assess --type execute -vv`
   (plus `syspolicy_check distribution` when available). Confirm it passed and read the
   result in its job summary. Expected today: **rejected** (self-signed, not
   notarized), so the README's first-launch steps (**Open Anyway**) must be present
   and match the current macOS. If the signing ever changes, change
   `GATEKEEPER_EXPECTED` and the README together.
   A DMG copied to a Mac with `scp`, `curl`, `gh` or an agent tool has **no**
   quarantine attribute and opens without any Gatekeeper dialog, so it is not a
   first-launch test. When signing changes, also do one real first launch on a Mac
   from a DMG downloaded in Safari.
6. Publish the draft (maintainer approval required). Confirm
   `releases/latest/download/appcast.xml` now serves the new feed, then verify
   updating from an older build with **Check for Updates…**. The Gatekeeper
   workflow runs again on the public DMG, downloaded without signing in.

The app is signed with the self-signed certificate, not Apple Developer ID, and is
not notarized, so macOS Gatekeeper asks users to approve the first launch (see
the README). Sparkle's EdDSA signature is independent of Apple code signing.
