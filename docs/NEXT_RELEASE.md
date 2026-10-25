# Next release preparation

This checklist covers verification before the next public release. The user-facing
changes are in [CHANGELOG.md](../CHANGELOG.md) and [CHANGELOG.ja.md](../CHANGELOG.ja.md).
Unreleased changes do not imply that an intervening version was published.

| Area | Current behavior | Checks before release |
| --- | --- | --- |
| Installer | Light 700 × 450 pt window, 248-pt square cards, 144-pt icons, gradient wordmark, rounded dotted arrow and mint Applications card. | Verify Finder labels, selection and bars at 1x and 2x using the Release workflow's render artifacts. |
| Menu | Section headings, separate permission and drag status, bare About/Login/Update symbols, circled Accessibility symbol. Display rows appear with two or more screens. | Review actual Light/Dark menus, keyboard navigation, multiple displays and VoiceOver. |
| Launch at Login | The state word (On / Off / Needs approval) sits at the right of the row and updates when toggled without closing the menu. | Run login-toggle and login-hover checks, and confirm real macOS registration and approval states in both languages. |
| Window motion | Moves/shrinks take 0.26 s, enlargements 0.34 s, on the Core Animation default curve. Slow apps skip frames on the same wall-clock curve; only a failed or single hung (over 80 ms) AX write places the window at its destination immediately. | Check near/far moves, growth/shrinkage, horizontal/vertical stretches, screen edges, apps with minimum sizes and Reduce Motion. |
| Distribution | GitHub Release DMG and Sparkle updates with stable self-signing. | Preserve existing keys and certificates; complete the signing, Gatekeeper and update checks. |

The desired motion feel is closer to macOS Show Desktop. The current durations and
curve remain in `MotionSpec`; comparison recordings should cover near/far moves,
growth and shrinkage. Spring behavior and distance-dependent timing were ideas,
not confirmed decisions.

## Checks before publication

1. Run `swift test --disable-keychain` and `swift build --disable-keychain` on macOS,
   including the login-probe/CI-hook and lab-hook build configurations in CI.
2. Review the actual menu, window motion and Accessibility behavior. Pure-logic
   tests and static renders cannot establish how other apps respond to AX writes.
3. Verify the signed DMG in Finder on supported macOS versions, with Path Bar,
   Status Bar and filename extensions both visible and hidden, at 1x and 2x.
   Trial DMGs must follow [trial-build.ja.md](trial-build.ja.md).
4. Finalize the version and dated bilingual release notes. Describe the final
   behavior for users upgrading from the last public release, without assuming
   familiarity with unpublished builds.
5. Follow [RELEASING.md](RELEASING.md) for CI, signing, Finder rendering, Gatekeeper
   and Sparkle update checks.
6. Obtain Kazina's approval before publication. Publishing the GitHub Release
   changes the live Sparkle feed.
