# AGENTS.md

- krado: macOS 14+ window-snapping menu bar app; Swift 6 package (`Package.swift`), Sparkle 2 for updates.
- `Sources/Krado` = AppKit app (menu, overlay, hot keys, drag, Accessibility); `Sources/KradoCore` = pure logic, tested by `Tests/KradoCoreTests`.
- Put new logic in `KradoCore` with a test; keep `Sources/Krado` thin.
- UI strings: `Resources/en.lproj` and `Resources/ja.lproj` `Localizable.strings`. Change both together.
- Kazina's own decisions are kept outside this public repository (`docs/DECISIONS.md` was removed on 2026-10-22). Ask for them before changing look or behaviour; never record inferred or agent-made decisions as hers.
- Other docs: `docs/design.md`, `docs/RELEASING.md`, `docs/signing-and-update-test.md`.
- Work on a `codex/<topic>` branch; get CI green, then squash into `main` (fast-forward).
- Run on macOS (headless only): `swift test --disable-keychain` and `swift build --disable-keychain`.
- CI (`.github/workflows/ci.yml`) also runs `swift build --disable-keychain -Xswiftc -DKRADO_LOGIN_SWITCH_PROBE -Xswiftc -DKRADO_CI_HOOKS` and `swift build --disable-keychain -Xswiftc -DKRADO_LAB_HOOKS`.
- CI skips docs-only pushes (`docs/**`, README, AGENTS.md, CONTRIBUTING.md, LICENSE): no CI run is expected for them. A newer push to the same branch cancels the older CI run (not on `main`).
- Changelog: edit `CHANGELOG.md` and `CHANGELOG.ja.md` together; check with `scripts/check-changelog-headings.sh`.
- Trial DMGs for Kazina: only via `docs/trial-build.ja.md` (Release workflow `trial_version`, then `scripts/check-trial-dmg.sh`). Never a local plain or ad-hoc DMG.
- Never touch tags, releases, signing keys, appcast, or published artifacts; publishing needs Kazina's OK.
- Never print secrets.
