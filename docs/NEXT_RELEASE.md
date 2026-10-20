# Next release preparation

Snapshot: 2026-10-20. Planned version: **0.1.6**. Local preparation only; the final
scope, dated release notes and release candidate are not approved or complete.

Sources: [canonical handoff](https://app.notion.com/p/3fdd89d6d454816abcf8d6badc08fa7b),
[development guide](https://app.notion.com/p/3ffd89d6d45481d9b70deebdeac5ba67),
[Agent Operating Guide](https://app.notion.com/p/3fdd89d6d45481ccac82d452da5ebc8c),
[decisions](DECISIONS.md). The latest conversation selects 144-pt icons and the
current arrow, superseding the canonical page's older “size not selected” text.
The parent conversation maintains Notion.

## Confirmed scope and remaining work

| Item | Actual state | Next step |
|---|---|---|
| Static DMG design | Adopted: composition B, right-hand 144-pt icons, current rounded arrow, white top, gradient wordmark and destination emphasis, no corner guides. Applied to production layout and tracked asset files locally. | Verify the actual Finder labels, selection and bars on the built DMG in a permitted environment. |
| Menu symbols | About still uses `info.circle`; Launch at Login still uses `power.circle`. No new icon-size/weight variant is implemented or selected. Update-check symbol was considered readable; the Accessibility check may be small. | Prepare one labelled A/B comparison: clearer symbols without enclosing circles versus larger/heavier existing symbols, including Accessibility status and light/dark display. Select before final integration. |
| Window motion | Desired feel: closer to macOS Show Desktop, with B preferred to A. This checkout preserves main: 0.26/0.34 s, ease-out cubic. The preserved A trial is 0.26/0.34 s, ease-in-out cubic; remote B is 0.28/0.38 s, ease-out quint. | Keep DMG adoption separate from motion. Prepare near/far, move/grow/shrink evidence before selecting final motion. Spring behaviour and distance-dependent timing are ideas, not confirmed decisions. |
| Shrinking / write order | Main code shrinks each axis before moving, then grows at the new origin. Trial A/B's additional edge-rounding change has not been carried into this DMG-only branch. The reported real-window shrinking behaviour has no new Mac verification here. | Review the edge-rounding fix separately from the trial curve; verify near screen edges and mixed-axis resizing, including apps with minimum window sizes. |
| Uninstall / login | Implementation exists; no uninstall, login registration or permission changes were run. | Verify in an explicitly permitted disposable environment. |
| Multiple displays / Accessibility | Display rows are conditional on two or more screens; the login state has an accessibility value. Real two-display menu appearance and VoiceOver readability remain unverified. | Verify actual menu, focus, native tiling and Reduce Motion together with normal interaction. |
| Distribution | GitHub Release DMG + Sparkle, with stable self-signing, appcast generation and Gatekeeper/render jobs already implemented. Homebrew is obsolete. | Retain the existing keys/certificate. Complete the checks below before a new release. |

## Repository and release snapshot

- GitHub `main` / tag `v0.1.5`: `cefb6f95104e0294fc87fabbc0d9000b3cc12254`.
  Trials: [A](https://github.com/KazinaG/krado/tree/codex/v016-arrow-a)
  `dcf96daad6a7b84ddabf4ed74bfa7508e4086186`,
  [B](https://github.com/KazinaG/krado/tree/codex/v016-arrow-b)
  `f40b3aaf3bc59ada10e77f686b4e2131bb82a1ab`.
- [Release list](https://github.com/KazinaG/krado/releases): v0.1.0 is public;
  v0.1.2–v0.1.5 are drafts with DMG/appcast assets. No v0.1.6 release exists.
  Preserve those drafts and tags; deleting or repurposing them is outside this work.
- The read-only GitHub issue listing returned no issues. The outstanding user
  requests live in Notion and this checklist, not an issue queue.
- Existing main and A/B CI/Release runs succeeded. For example,
  [A CI](https://github.com/KazinaG/krado/actions/runs/39412822326) and
  [B CI](https://github.com/KazinaG/krado/actions/runs/39412819587).
  Those runs predate the adopted DMG assets and do not verify this local change.
- Active local `codex/v016-release-prep-main` starts directly from GitHub main
  `cefb6f9`. Sources, Tests, Resources, package dependencies and workflows match
  main. Its changes are DMG assets/tools, version metadata and documentation.
- Preserved `codex/v016-release-prep` at `8a4e83c` descends from the A trial via the
  design-study commits. **Do not merge that study branch wholesale:** it would also
  select trial A motion. The active main-based branch already separates the final
  packaging changes from that application trial.
- The old clone in `Documents/Codex/Development/krado` remains at `326d43f` and was
  preserved. It is behind the real GitHub main; it is not the release baseline.

## Completed local preparation

- Production SVG and both PNG scales match the adopted B follow-up byte for byte;
  144-pt icons flow from `layout.json` to dmgbuild's settings. Window 700×450,
  248-pt cards, icon centres and bar reserve match the adopted comparison. Relative
  to main, the window grows from 660×430 to 700×450 and cards from 224 to 248 pt.
- The default generator uses the selected design without importing study scripts.
  Historical open/filled and 160-pt studies remain reproducible.
- Geometry, opaque white top at 1x/2x, arrow shape/gradient/spacing, changelog headings
  and diff checks pass. These are static checks, not Finder screenshots.
- Decision and bilingual Unreleased notes describe the adopted result. The local
  bundle-version default is 0.1.6. No application bundle, DMG or signature was built
  by this preparation step.

## Gates before release

1. Settle the menu and motion scope, then integrate only the intended changes onto
   the main-based preparation branch. Preserve the separation from trial A.
2. Run the full Swift tests with a compatible existing Xcode/XCTest environment.
   On this Mac test compilation is blocked by missing `XCTest`; test assertions did
   not run. Normal, login-probe/CI-hook and lab builds all pass on the active
   main-based preparation branch; linker warnings about missing CLT framework
   search directories remain. No Xcode installation or global toolchain change is
   authorized here.
3. Verify the final DMG in Finder with bars and extensions on/off, 1x/2x, and perform
   the actual application checks above. No UI launch, DMG mount or app execution is
   authorized on the user's Mac in this task.
4. Finalize bilingual 0.1.6 dated notes. Include the relevant unpublished 0.1.1–0.1.5
   changes when preparing notes for users upgrading from public v0.1.0; do not imply
   the intervening drafts were published. Until then there is deliberately no
   `## [0.1.6]` section, so normal `v0.1.6` release-note extraction cannot pass.
   A `v0.1.6-test` run would instead use Unreleased notes; no such run is authorized
   or dispatched here.
5. Obtain approval for push/main integration/tagging and the release workflow.
   No new CI run was dispatched here. Follow [RELEASING.md](RELEASING.md) for the
   final CI, signing, Finder-render, Gatekeeper and Sparkle-update checks.
6. Obtain publication approval. Publishing the GitHub Release changes the live
   Sparkle feed; it is not part of local preparation.

The next small implementation unit is the menu-symbol A/B comparison. It can be
reviewed independently while the motion reference and test environment are pending.
