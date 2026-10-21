# Menu symbol A/B study — revised comparison

Unselected proposals, 2026-10-20. This is one offscreen light/dark comparison,
not a screenshot or verification of the native menu. Production is unchanged.

## Comparison contract

A = retain the current circled shapes and enlarge them.
B = remove the circles and retain each role's current visible size.
Both include the update symbol. Labels, state, layout, colour roles and weight
stay the same. A/B labels are fixed to this contract, rather than the old study.

| Role | Current / A shape | B shape | Current configuration |
|---|---|---|---|
| About | `info.circle` | `info` | Unconfigured system symbol, template |
| Launch at Login | `power.circle` | `power` | Unconfigured system symbol, template |
| Check for Updates | `arrow.down.circle` | `arrow.down` | Unconfigured system symbol, template |
| Accessibility allowed | `checkmark.circle.fill` | `checkmark` | 15 pt regular; white check/systemGreen for the circle, systemGreen for the bare check |

## Exact size baseline

Production `App.swift` uses default `NSImage(systemSymbolName:)` configuration for
About, Login and Update. Their current-host image canvases are 15 by 15 pt.
`StatusPresentation.image` uses 15 pt regular for allowed Accessibility, whose
current-run image canvas is 18 by 18 pt (the earlier saved study recorded 17 by 17 pt; runtime measurements are authoritative). A 15 pt font setting is not a 15 pt
image canvas. Production has no common image-size override.

We measure the unmodified current symbol's **visible longest edge per role**
on an in-memory transparent bitmap at 8 pixels/pt with alpha >= 8/255.
B keeps that measured value exactly to within 0.5 pt after rasterization. B is
not enlarged to the A size, and the permission role is not silently reduced to
the usual action baseline. A uses a common 18 pt visible longest edge for all
four circled symbols; each must be larger than its own current baseline. A's
percentage increase therefore varies by role; this is not a claim that all
symbols are 20% larger than production.

Uniform scaling preserves natural aspect ratio. Narrow `info` remains narrow;
the wider check retains the current permission baseline as optical compensation.
The common icon centre and font-weight configuration are preserved. In this run the current visible longest edge is 13 pt for each action and 15 pt for allowed permission; B retains those values, while A uses 18 pt. Visible bounds,
canvas bounds, scale factors and the role-specific baseline are all recorded in
`symbol-metrics.json`. Shape widths and ink areas are not forced equal.

The existing power symbol, login On wording without a checkmark, two-line status,
section headings and monitor symbol remain. The study shows allowed permission
and login On as fixed inputs. No direction is selected or applied to production.
The old study and the initial three-file preservation patch are retained.

## Headless reproduction

From the repository root with the existing macOS SDK; no installation:

```sh
mkdir -p .build
xcrun swiftc -module-cache-path .build/menu-symbol-module-cache \
  -D STATUS_RENDERER -parse-as-library \
  Sources/KradoCore/StatusAppearance.swift Sources/Krado/StatusPresentation.swift \
  scripts/menu-symbol-studies/RenderMenuSymbols.swift -o .build/render-menu-symbols-revised
.build/render-menu-symbols-revised /absolute/path/to/new-output-directory
```

The output directory must not already exist. For a correction before any Library upload/attachment only, `--revise-unattached-draft` may update a directory containing exactly the renderer's own PNG and metrics; the invocation must first verify that PNG's expected hash. Output is **one** 1760 by 1800 PNG,
`krado-menu-symbols-AB-current-size@2x.png`, plus metrics JSON. No redundant 1x
image is written. Keep this file until the parent confirms attachment readback.

The tool uses NSBitmapImageRep, bitmap NSGraphicsContext, NSAppearance and
NSImage(systemSymbolName:). It never loads App.swift, starts NSApplication,
creates windows/status items/menus, invokes Accessibility or ServiceManagement,
captures or reads the screen, changes preferences, or uses network access.
Missing symbols fail; there is no UI fallback. The renderer is macOS-specific.

## Verification and limits

- Check all four roles independently against the contract table in both themes.
- Verify alpha bounds, B's baseline preservation, A's enlargement/common size,
  and uniform aspect scaling. Compare all non-icon pixels between A/B panels
  and with the old study to check identical text/layout/state/monitor artwork.
- Inspect the exported bitmap at intended size for balance, clipping and text.
- Native material, placement, hover/highlight, keyboard navigation, VoiceOver,
  real login state/badge and macOS 14 compatibility remain unverified.
- Full application tests are not asserted by a standalone renderer compile.
- After a choice, integrate using native menu images and verify actual states;
  do not replace native rows with bitmap mockups or custom views.

No decision or release-note entry is added before selection and integration.
