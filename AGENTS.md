# AGENTS.md

- krado: macOS 14+ window-snapping menu bar app; Swift 6 package (`Package.swift`), Sparkle 2 for updates.
- `Sources/Krado` = AppKit app (menu, overlay, hot keys, drag, Accessibility); `Sources/KradoCore` = pure logic, tested by `Tests/KradoCoreTests`.
- Put new logic in `KradoCore` with a test; keep `Sources/Krado` thin.
- UI strings: `Resources/en.lproj` and `Resources/ja.lproj` `Localizable.strings`. Change both together.
- `docs/DECISIONS.md` holds only the maintainer's own decisions. Read it before changing look or behaviour; never add inferred or agent-made decisions.
- Other docs: `docs/design.md`, `docs/RELEASING.md`, `docs/signing-and-update-test.md`.
- Use Conventional Branch prefixes `feature/`, `feat/`, `bugfix/`, `fix/`, `hotfix/`, `release/`, `chore/` plus lowercase words joined by hyphens; no tool prefixes. `main` and `dependabot/` are exempt.
- Use Conventional Commits 1.0.0, with lowercase English subjects; CI job `conventions` checks branches, commits (commitlint with `@commitlint/config-conventional`, merge-base with `origin/main`..HEAD), and tags in `.github/workflows/conventions.yml`. Get CI green, then fast-forward `main`.
- New release tags use SemVer 2.0.0 `X.Y.Z` without `v`; published `v0.1.0` through `v0.1.5` stay unchanged.
- Run on macOS (headless only): `swift test --disable-keychain` and `swift build --disable-keychain`.
- CI (`.github/workflows/ci.yml`) also runs `swift build --disable-keychain -Xswiftc -DKRADO_LOGIN_SWITCH_PROBE -Xswiftc -DKRADO_CI_HOOKS` and `swift build --disable-keychain -Xswiftc -DKRADO_LAB_HOOKS`.
- CI runs on every push, docs-only included: `main` requires the CI jobs `changelog` and `tests` (repository ruleset), so a commit reaches `main` only after CI is green on a branch at the same SHA. A newer push to the same branch cancels the older CI run (not on `main`).
- Changelog: edit `CHANGELOG.md` and `CHANGELOG.ja.md` together; check with `scripts/check-changelog-headings.sh`.
- Trial DMGs for the maintainer: only via `docs/trial-build.ja.md` (Release workflow `trial_version`, then `scripts/check-trial-dmg.sh`). Never a local plain or ad-hoc DMG.
- Bump the patch number for every trial DMG the maintainer checks; never reuse a version. Check a real update from the trial only before releases changing updating or signing (see `docs/RELEASING.md`).
- Never touch tags, releases, signing keys, appcast, or published artifacts; publishing needs the maintainer's OK.
- Never print secrets.
