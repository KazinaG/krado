# Changelog

English | [日本語](CHANGELOG.ja.md)

All notable changes to krado are documented in this file, the source of truth.
The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Planned as 0.2.0. 0.1.1 to 0.1.5 were not published; their changes are included here.

### Changed

- Window motion is calmer: moving a window into a zone takes 0.26 s and enlarging it takes 0.34 s (both were 0.2 s).
- The menu is easier to scan: it is split into sections with headings (Status, Startup and krado), with Quit krado on its own at the bottom. Status shows two rows with colored symbols: whether Accessibility is allowed and whether window drags can snap. Every menu action has an icon that follows light and dark mode (including Reload Displays), and Quit krado has the shortcut ⌘Q.
- Launch at Login shows its state as a word at the right end of the row (On, Off or Needs approval) instead of a checkmark. Choosing it switches it on or off right away; VoiceOver reads the state too.
- The rows listing each display and its grid now appear only when two or more displays are connected. Reload Displays stays in the menu.
- When you drop a window on a zone, the window now glides into place instead of jumping (it moves instantly when Reduce Motion is on, or when an app's window cannot follow smoothly). While you drag, the highlight slides from zone to zone.
- The grid now follows one rule with no special cases: krado keeps halving the screen, across and down, while every zone stays at least 640 pt wide and 720 pt tall (columns 1, 2, 4 or 8; rows 1, 2 or 4). It reads the whole screen size, so showing or hiding the Dock or menu bar no longer changes the grid. For example, 1920 × 1080 is now 2 × 1, 2560 × 1440 and 3008-pt-wide displays (including 6K at its default size) are now 4 × 2 instead of 2 × 2 or 3 × 2, and 6K at native size is 8 × 4.
- Installer window: a new light design. krado and Applications keep their square cards, now with larger 160 pt icons, joined by a dotted arrow like 0.1.0's that sits centred between the cards; the whole layout is optically centred in the window.

### Fixed

- The install window now always shows its own background, even when a disk image from another krado version is still open. The disk is named after its version (for example "krado 0.2.0"), because Finder looked up the background by disk name and could show an older version's picture, which made the cards look cut off and the labels misplaced.
- On macOS 27 the menu icons are shown again (macOS 27 hides menu icons unless an app asks to keep them).
- The install window that opens with the DMG is no longer cut off at the bottom and no longer shows a scroll bar when Finder's Path Bar or Status Bar is turned on, and the "krado" and "Applications" labels now sit inside their cards (also with filename extensions shown).
- Enlarging a window by dropping it on more zones (for example from one zone to four) no longer jolts near the screen edge: krado moves the window before growing it, and shrinks it before moving.

## [0.1.0] - 2026-10-20

### Added

- Menu-bar window tiling for macOS with drag-to-snap zone overlays and boundary/intersection spanning.
- An automatic, evenly divided grid sized by a minimum zone size (about 900 × 1000 pt), up to 8 × 4: MacBook screens stay 2 × 1, 4K at native size gets 4 × 2, 6K 6 × 3 and 8K 8 × 4; portrait screens use 1 × 1 or 1 × 2 and ultrawide screens 4 × 1 or 4 × 2. Wide but short screens (under 900 pt tall) are never split top and bottom, so no zone is shorter than 450 pt.
- Multiple-display support, Retina pixel alignment, Dock/menu-bar work-area handling, and automatic display refresh.
- Zone overlays in the macOS accent color, redrawn immediately when the accent color changes.
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
- The DMG opens in a designed window: krado's zones on a dark background, the app in one cell and Applications glowing as the mint snap target, with Retina artwork, a volume icon, and hidden toolbar and sidebar. The layout is written by dmgbuild in CI (no Finder automation).

### Fixed

- The "new version available" alert no longer appears during first-run setup: scheduled update checks start only after Accessibility is allowed and the welcome guide is closed. Check for Updates… always works.
- The macOS Accessibility alert is raised at most once (not again after a relaunch or update) and no longer opens together with System Settings, which could leave it on screen after krado was turned on. Later clicks on Open System Settings only open the settings pane.
- README fixes: Japanese bold text renders on GitHub, the usage tables have headers, and the difference between Option and Esc during a drag is explained.
