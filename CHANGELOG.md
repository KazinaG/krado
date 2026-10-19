# Changelog

English | [日本語](CHANGELOG.ja.md)

All notable changes to krado are documented in this file, the source of truth.
The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Larger screens are divided evenly by a minimum zone size (about 900 × 1000 pt), up to 8 × 4: 4K at native size stays 4 × 2, 6K gets 6 × 3, 8K gets 8 × 4. MacBook screens stay 2 × 1.
- Wide but short screens (under 900 pt tall) are no longer split top and bottom, so no zone is shorter than 450 pt.

- The "new version available" alert no longer appears during first-run setup: scheduled update checks start only after Accessibility is allowed and the welcome guide is closed. Check for Updates… always works.
- The macOS Accessibility alert is raised at most once (not again after a relaunch or update) and no longer opens together with System Settings, which could leave it on screen after krado was turned on. Later clicks on Open System Settings only open the settings pane.

## [0.1.0] - 2026-10-20

### Added

- Menu-bar window tiling for macOS with drag-to-snap zone overlays and boundary/intersection spanning.
- Automatic split tiers: portrait 1 × 1 or 1 × 2, ultrawide 4 × 1 or 4 × 2, and landscape 1 × 1, 2 × 1, 2 × 2, or 4 × 2 based on visible work area.
- Multiple-display support, Retina pixel alignment, Dock/menu-bar work-area handling, and automatic display refresh.
- Shift+drag to span visited cells, Option+drag to bypass snapping, and Esc during a drag to cancel snapping for that drag (the window stays where it is released).
- Ctrl+Cmd+Arrow to move the focused window between zones and adjacent displays; Ctrl+Cmd+Shift+Arrow to extend its span, with the opposite arrow shrinking it back toward the zone where growing started (never below that zone).
- Accessibility setup guidance, permission/monitoring status, placement error feedback, and recovery checks.
- A single Launch at Login checkbox in the menu (SMAppService), off by default; the welcome guide offers a one-click button to turn it on, with a one-line hint only when macOS needs approval or krado is outside Applications.
- An Uninstall krado… menu item: after confirmation it unregisters the login item, resets krado's own Accessibility entry with `tccutil` (current user, no sudo), removes its preferences, caches and HTTP storage, moves the app to the Trash, and quits; if any step fails it explains the manual steps and opens Accessibility settings.
- English and Japanese localization, illustrated READMEs, an app icon, and MIT licensing.
- Pure-logic tests and design/manual-check documentation; feedback and issue templates with a contribution policy.
- A DMG packaging script with an Applications shortcut and an optional output directory.
- Sparkle 2 framework bundling, HTTPS appcast configuration, a tested configuration policy, and a localized Check for Updates menu item. Automatic update checks are on from the start without Sparkle's permission prompt; a found update is shown in Sparkle's standard alert and is never downloaded or installed silently. Updates are verified with krado's Sparkle EdDSA public key.
- An opt-in test feed (`KradoTestFeedURL`, limited to this repository's release assets and still EdDSA-verified) for trying an update between unpublished builds.
- A tag-triggered release workflow that builds the DMG, signs it and the appcast entry with the Sparkle key from a GitHub Actions secret, and attaches both to a draft GitHub Release with notes from this changelog. It signs the app with the "krado Self-Signed" certificate from Actions secrets in a temporary keychain that is deleted at the end of the job; `v<version>-test` tags make a draft pre-release with `appcast-test.xml` for update tests.
- Bilingual changelogs, a matching-heading check, GitHub Actions checks for changelog headings and Swift tests, and future release instructions.

### Changed

- The drag grid uses rounded, slightly inset tiles and fades in and out (instantly with Reduce Motion).
- Status presentation uses SF Symbols and color, with localized labels and accessibility descriptions; an offscreen renderer supplies reference images.
- README presentation includes language switching and Japanese cover/layout images.
- Installation documentation describes future DMG downloads, macOS first-launch approval, and signed-update availability.
- App packaging embeds Sparkle and verifies bundle signatures, framework linkage, and the executable's framework search path. Release builds are signed with a stable self-signed certificate ("krado Self-Signed", imported into a temporary CI keychain) so Accessibility permission survives updates; local builds without it fall back to ad-hoc signing.
