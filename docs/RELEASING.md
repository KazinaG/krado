# Releasing krado

The first public release was v0.1.0 (2026-10-19). Never move or rewrite the tag
of a published release. From the next release, tags use SemVer 2.0.0 `X.Y.Z`
without `v`; published `v0.1.0` through `v0.1.5` remain unchanged. [CHANGELOG.md](../CHANGELOG.md) is the source of truth; keep the Japanese translation's `## [...]` headings byte-identical.

Distribution is a DMG attached to a GitHub Release plus a Sparkle 2 appcast. There
is no Homebrew tap.

The checks before publication are part of the [release checklist](#release-checklist).
Do not tag or package a final candidate until its scope and verification checks are
complete. Trial DMGs use the separate [trial build procedure](trial-build.ja.md).

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
real update check and the uninstall file list:
[signing-and-update-test.md](signing-and-update-test.md).

## Release workflow

[`.github/workflows/release.yml`](../.github/workflows/release.yml):

- **Tag `X.Y.Z` pushed:** runs the changelog check and tests, builds the DMG
  with `scripts/make-dmg.sh`, checks that the tag matches
  `CFBundleShortVersionString`, takes the notes from the `## [<version>]` section
  of `CHANGELOG.md` (`scripts/changelog-section.sh`), signs the DMG and writes
  `appcast.xml` with Sparkle's `generate_appcast`, verifies the signature, length
  and URL, then creates a **draft** GitHub Release with the DMG and appcast.
- **Branch push touching release files:** the same build, signing and
  verification as a dry run; the files are kept only as a workflow artifact.

Sparkle's tools come from the checksum-pinned Sparkle SwiftPM artifact
(`.build/artifacts/.../Sparkle/bin`), matching the framework version in
`Package.resolved`.

## Release checklist

1. Bump the default version (`version="${KRADO_VERSION:-…}"`) in
   `scripts/build-app.sh`; it sets both `CFBundleShortVersionString` and
   `CFBundleVersion`. Follow Semantic Versioning 2.0.0. The trial on the Mac is expected to be
   `0.1.13` while the latest public release is `v0.1.5`, so the next public
   release must be `0.1.14` or higher; bump this default to that number before tagging.
   Every trial DMG the maintainer checks bumps the patch number `x.y.Z`; never
   reuse a number.
2. Move the contents of Unreleased to `## [<version>] - <date>` in both
   changelogs and keep a new empty `## [Unreleased]` section. Describe the final
   behavior for users upgrading from the last public release, without assuming
   familiarity with unpublished builds. Run `scripts/check-changelog-headings.sh`,
   `swift test --disable-keychain` and `swift build --disable-keychain` on macOS; CI
   must also pass the login-probe/CI-hook and lab-hook build configurations.
3. Merge the pull request to `main`, then push the tag `X.Y.Z` on that commit (maintainer
   approval required).
4. Wait for the Release workflow. Its `render` job opens the built DMG in Finder on
   macOS 15 and 26, with default Finder settings and with Path Bar, Status Bar and
   filename extensions on; look at the `render-<os>` screenshots (nothing cut off, no
   scroll bar, labels inside their cards). The draft is only created after it passes.
   Download the draft's DMG and check it on a Mac, on the supported macOS versions.
   Pure-logic tests and static renders cannot establish how other apps respond to
   AX writes, so look at the real app:
   - **Installer:** Finder labels, selection and bars at 1x and 2x, with Path Bar,
     Status Bar and filename extensions both visible and hidden.
   - **Menu:** actual Light/Dark menus, keyboard navigation, multiple displays and
     VoiceOver.
   - **Launch at Login:** run the login-toggle and login-hover checks, and confirm
     real macOS registration and approval states in both languages.
   - **Window motion:** near/far moves, growth/shrinkage, horizontal/vertical
     stretches, screen edges, apps with minimum sizes and Reduce Motion.
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
   `releases/latest/download/appcast.xml` now serves the new feed. When updating
   or signing changes, check a real update as described below. The Gatekeeper
   workflow runs again on the public DMG, downloaded without signing in.

The app is signed with the self-signed certificate, not Apple Developer ID, and is
not notarized, so macOS Gatekeeper asks users to approve the first launch (see
the README). Sparkle's EdDSA signature is independent of Apple code signing.

## When to check updating

A real update check is needed only before releases changing Sparkle, appcast/feed,
EdDSA key, code-signing certificate, or bundle id, not before every release.
To check updating, publish the release with a version higher than the trial build
installed on the Mac, and let that trial build receive the real update.
The trial and release use the same Release workflow, bundle id
`io.github.kazinag.krado`, `SUPublicEDKey`, EdDSA signing key secret, code-signing
certificate, and `SUFeedURL` (`releases/latest/download/appcast.xml`, which ignores
drafts and pre-releases). Sparkle compares `CFBundleVersion`, which
`scripts/build-app.sh` sets to the version number. See the
[real update check](signing-and-update-test.md#checking-a-real-update) for the Mac steps.
