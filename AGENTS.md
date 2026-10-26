# AGENTS.md

- krado: macOS 14+ window-snapping menu bar app; Swift 6 package (`Package.swift`), Sparkle 2 for updates.
- `Sources/Krado` = AppKit app (menu, overlay, hot keys, drag, Accessibility); `Sources/KradoCore` = pure logic, tested by `Tests/KradoCoreTests`.
- Put new logic in `KradoCore` with a test; keep `Sources/Krado` thin.
- UI strings: `Resources/en.lproj` and `Resources/ja.lproj` `Localizable.strings`. Change both together.
- `docs/DECISIONS.md` holds only the maintainer's own decisions. Read it before changing look or behaviour; never add inferred or agent-made decisions.
- Other docs: `docs/design.md`, `docs/RELEASING.md`, `docs/signing-and-update-test.md`.
- Run on macOS (headless only): `swift test --disable-keychain` and `swift build --disable-keychain`.
- CI (`.github/workflows/ci.yml`) also runs `swift build --disable-keychain -Xswiftc -DKRADO_LOGIN_SWITCH_PROBE -Xswiftc -DKRADO_CI_HOOKS` and `swift build --disable-keychain -Xswiftc -DKRADO_LAB_HOOKS`.
- CodeQL code scanning (`.github/workflows/codeql.yml`, advanced setup) runs on pushes to `main` and weekly; Swift is built with `swift build` because default setup's Swift autobuild needs an Xcode project.
- Flow: trunk-based, using GitHub Flow steps. Cut a short-lived branch, open a PR, and merge once CI and the Codex review pass. Naming and tag rules live in `.github/workflows/conventions.yml`. A newer push to the same branch cancels the older CI run (not on `main`).
- Write commit subjects and PR titles in English. Japanese names may appear only inside backticks (e.g. feat: add `出勤簿` export); the pr-title check in `.github/workflows/conventions.yml` rejects any other non-ASCII character.
- Changelog: edit `CHANGELOG.md` and `CHANGELOG.ja.md` together; check with `scripts/check-changelog-headings.sh`.
- Trial DMGs for the maintainer: only via `docs/trial-build.ja.md` (Release workflow `trial_version`, then `scripts/check-trial-dmg.sh`). Never a local plain or ad-hoc DMG.
- Bump the patch number for every trial DMG the maintainer checks; never reuse a version. Check a real update from the trial only before releases changing updating or signing (see `docs/RELEASING.md`).
- Never touch tags, releases, signing keys, appcast, or published artifacts; publishing needs the maintainer's OK.
- Never print secrets.
