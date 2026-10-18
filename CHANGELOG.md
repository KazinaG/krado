# Changelog

English | [日本語](CHANGELOG.ja.md)

All notable changes to krado are documented in this file, the source of truth.
The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
No version has been released; all work so far is unreleased.

## [Unreleased]

### Added

- Menu-bar window tiling for macOS with drag-to-snap zone overlays and boundary/intersection spanning.
- Automatic split tiers: portrait 1 × 1 or 1 × 2, ultrawide 4 × 1 or 4 × 2, and landscape 1 × 1, 2 × 1, 2 × 2, or 4 × 2 based on visible work area.
- Multiple-display support, Retina pixel alignment, Dock/menu-bar work-area handling, and automatic display refresh.
- Shift+drag to span visited cells and Option+drag to bypass snapping.
- Ctrl+Cmd+Arrow to move the focused window between zones and adjacent displays; Ctrl+Cmd+Shift+Arrow to extend its span.
- Accessibility setup guidance, permission/monitoring status, placement error feedback, and recovery checks.
- Open at Login with an installation-path policy, approval guidance, and a menu toggle.
- English and Japanese localization, illustrated READMEs, an app icon, and MIT licensing.
- Pure-logic tests and design/manual-check documentation; feedback and issue templates with a contribution policy.
- A DMG packaging script with an Applications shortcut and an optional output directory.
- Sparkle 2 framework bundling, HTTPS appcast configuration, a tested configuration policy, and a localized Check for Updates menu item. Updates remain disabled while the public key is a placeholder; automatic checks default to off.
- Bilingual changelogs, a matching-heading check, GitHub Actions checks for changelog headings and Swift tests, and future release instructions.

### Changed

- Status presentation uses SF Symbols and color, with localized labels and accessibility descriptions; an offscreen renderer supplies reference images.
- README presentation includes language switching and Japanese cover/layout images.
- Installation documentation describes future DMG downloads, macOS first-launch approval, and signed-update availability.
- App packaging embeds and ad-hoc signs Sparkle and verifies bundle signatures, framework linkage, and the executable's framework search path.
