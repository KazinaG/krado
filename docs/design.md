# krado v0.1 design

## Modules and scope

Swift Package, macOS 14+, Swift 6, no package dependencies:

| Target | Responsibility |
| --- | --- |
| `KradoCore` | Value types and pure grid, hit-test, coordinate, layout-policy, movement functions; Foundation/CoreGraphics, no AppKit or AX |
| `Krado` | Menu-bar executable; AppKit panels/displays, listen-only CGEvent tap, AX lookup/read/write |
| `KradoCoreTests` | Swift Testing; depends only on KradoCore; no GUI, event tap, or permission calls |

`scripts/build-app.sh` builds release code with CLI SwiftPM, installs the executable as `dist/krado.app/Contents/MacOS/krado`, writes Info.plist, and signs with `KRADO_SIGN_IDENTITY` (the release certificate) or ad hoc when it is unset. Bundle ID: `io.github.kazinag.krado`; version: `0.1.0`; minimum macOS: `14.0`; `LSUIElement=true`. Signing failure warns and continues. No Apple Developer membership, Developer ID signing, notarization, external packages, or Xcode project is required. The script does not launch the bundle.

Release bundling passes `-debug-info-format none`: no dSYM is needed for v0.1 distribution, and this avoids a `dsymutil` operation rejected by the host sandbox. Debug `swift build` retains debug information for development.

## Display policy and geometry

Policy input is `ScreenDescriptor(isBuiltin, visibleSize, name)`; both name and `isBuiltin` are informational. The same policy applies to built-in and external screens. Rules are evaluated in order, using the width **W** and height **H** of `NSScreen.visibleFrame` in **points**, not hardware pixels:

| Priority | Visible size | Columns × rows |
| --- | --- | --- |
| 1 | Portrait: H > W | H ≥ 1200pt → 1 × 2; otherwise 1 × 1 |
| 2 | Ultrawide: W/H ≥ 2.1 **and** W ≥ 2400pt | H ≥ 1300pt → 4 × 2; otherwise 4 × 1 |
| 3 | W ≥ 2800pt (large / 4K-class) | 4 × 2 |
| 4 | W ≥ 1800pt (mid-size) | 2 × 2 |
| 5 | W ≥ 1200pt (MacBook Air 13-class) | 2 × 1 |
| 6 | Otherwise | 1 × 1 (no split) |

Named constants in `GridPolicy` are `portraitSplitMinimumHeight` (1200), `ultrawideMinimumAspectRatio` (2.1), `ultrawideMinimumWidth` (2400), `ultrawideTwoRowMinimumHeight` (1300), `largeDisplayMinimumWidth` (2800), `midSizeDisplayMinimumWidth` (1800), and `twoColumnMinimumWidth` (1200). Portrait takes precedence even on very large screens; equality H = W is not portrait. Ultrawide requires both its aspect ratio and width thresholds, and precedes the general large-screen rule: 2800×1000pt gets 4×1, not 4×2.

The aim is to keep zones roughly at least 640pt wide and about 500pt tall so typical app windows fit. Mid-size screens get 2×2 rather than three narrow columns. Small landscape screens get full-height left/right halves. Below about 1200pt, even halves become too narrow, so a single zone fills the visible work area. Portrait screens split only with at least 1200pt of height; ultrawides use two rows only with at least 1300pt. These are sizing heuristics, not enforced minimum dimensions: the 1200pt width threshold permits 600pt halves, and unusual work-area aspect ratios or app size constraints may still produce smaller usable windows.

Examples, all using visible points:

- Large: a 3:2 4K-class display at **3008×1975 → 4×2 = 8 zones**; 3840×2135 also gets 4×2.
- Ultrawide: 3440×1410 → 4×2; 2560×1050 → 4×1.
- Mid-size: 1920×1055, 2560×1415, 16-inch MacBook Pro at 2056×1305, and 14-inch MacBook Pro at 1800×1137 → 2×2.
- Small: a 13-inch MacBook Air at **1470×924 → 2×1 = 2 zones**; 1280×800, 1710×1074, 1512×950, and 1728×1085 also get 2×1.
- Tiny: 1024×740 → 1×1. Portrait 800×1100 is also unsplit, while 800×1200 gets stacked halves.

A display's nominal hardware resolution does not directly drive policy. All work areas exclude the Dock and menu bar, including a Dock placed on other edges.

`GridSpan` has nonempty, half-open column and row ranges; row 0 is the top. `GridGeometry` stores absolute x/y edge arrays. Each **internal** edge is independently rounded to the nearest physical pixel with the display's backing scale. The exact outer edges stay fixed to the visible frame. Adjacent cells share the same edges, their dimensions sum to the full work area, and errors do not accumulate. Outer edges provided at a fractional pixel are preserved rather than expanding/shrinking the work area. Spans use those same edges to calculate frames. `KradoDefaults.gap=0`; a nonzero gap insets the resulting span, not each cell inside a combined span.

Hit testing first rejects points outside the work area. For each axis, an internal edge within `KradoDefaults.boundaryBandWidth / 2` selects its two neighboring cells. Default full width is 24pt, i.e. ±12pt **inclusive**. Away from an edge, select just the containing cell. Horizontal and vertical ranges combine, producing 1, 2, or 4 cells. Outer edges are never considered internal boundaries. Exact outer-edge coordinates are accepted by the pure hit test; the display selector uses CGRect's half-open containment to disambiguate shared display edges. If bands overlap on tiny work areas, the nearest internal edge wins (earlier edge on an exact tie).

In 2×1 and 4×1 layouts, the only y edges are the work area's outer edges: there is no horizontal internal boundary, and every cell or merged span uses the full height. Portrait 1×2 has no vertical internal boundary. A 1×1 layout has no internal boundaries on either axis: hit testing returns its single cell throughout the work area, overlay drawing produces one zone, and releasing there snaps to the entire visible frame. Overlay drawing iterates the geometry's zones and uses their frames, so these layouts need no special rendering branch.

## Coordinate systems

AX and CGEvent locations are global top-left coordinates with y increasing down. NSScreen uses global bottom-left coordinates with y increasing up. The anchor is the height **H** of the NSScreen corresponding to `CGMainDisplayID()`, never `NSScreen.main`, which changes with keyboard focus.

```text
point: (x, y)       -> (x, H - y)
rect:  (x, y, w, h) -> (x, H - y - h, w, h)
```

The reflection is its own inverse. Negative x/y and displays above, below, left, and right need no special cases. Both the full display frame and visible frame are reflected. Grid calculations and AX writes remain in AX coordinates. The overlay panel uses the original NSScreen visible frame; its flipped NSView draws the top-down grid relative to the AX work area's origin. This keeps row 0 at the visual top on every display.

## Menu, permissions, and lifecycle

On launch, create the status menu and screen panels and create Sparkle's updater without starting it (scheduled checks start only after Accessibility is allowed and the guide is closed, so no update alert interrupts onboarding; **Check for Updates…** always works), then use the non-prompting `AXIsProcessTrusted()` check. If untrusted, create no event tap and show a small, localized permission guide. The denied status row is clickable; **Accessibility Setup…** also reopens the guide while untrusted. The guide explains that Accessibility is used to read and move other apps' windows: krado never reads keystrokes or screen contents and sends nothing over the network. It lists the System Settings steps, adding krado with `+` if needed, and removing/re-adding the old entry after a rebuild or update.

Only the guide's explicit **Open System Settings** button calls `AXIsProcessTrustedWithOptions(prompt: true)`, and only on the first click ever (`KradoAccessibilityPromptShown` in krado's defaults, so relaunches and updates never prompt again). That click raises macOS's alert alone; its own button opens Settings and dismisses it. Every later click only opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`. (Raising the alert and opening Settings together left the alert on screen after krado was turned on.) The flow lives in `KradoCore.AccessibilityOnboarding` with injected system calls and is tested. Showing the guide itself never requests the system prompt. While open, it polls trust every second. On approval it immediately starts monitoring, shows **All set!**, and closes after a short delay. Closing the guide stops its timer; monitoring/trust checks continue independently. Nothing in KradoCore or tests imports this code. The executable is never run during automated verification.

A main-run-loop timer also checks trust every three seconds. Once trusted, attempt a `.cgSessionEventTap` at `.headInsertEventTap`, `.listenOnly`, for left mouse down/drag/up. A failed tap has a distinct warning icon and status, and is retried on the same interval. No Input Monitoring permission request API is called. If Accessibility is revoked, stop monitoring, remove/invalidate the run-loop source/tap, and cancel any drag.

The template menu icon and accessibility description distinguish watching (grid), missing Accessibility (lock), and event-tap failure (warning triangle). Plain-language status rows show Accessibility, watching/paused/tap error, placement errors, and each display's localized name and layout (for example, `Built-in Retina Display: 2 × 1 (2 zones)`). The menu retains reload/quit and adds login settings, **About krado** with the bundle version, and the GitHub link. Unsplit displays explicitly show `1 × 1 (no split)`. OS display names and localized system error descriptions are dynamic values.

The C tap callback is scheduled exclusively on `CFRunLoopGetMain()` in common modes; `MainActor.assumeIsolated` reflects that scheduling guarantee. AppKit, AX state, timers, and panel changes stay on the main actor. Disabled-by-timeout or disabled-by-user-input events cancel the drag and re-enable the tap if still trusted. The callback returns the original event without modifying or consuming it. Shutdown invalidates timers, tap, source, and notification observation.

## Drag lifecycle

1. **Mouse down:** clear old state. Use a system-wide AX hit test at the CGEvent location. Resolve `AXWindow` directly or walk up `AXParent` (at most 16 steps), accepting a window role. Skip krado's own windows and windows without settable AX position and size. Capture the current window position and size; this works for windows opened before krado. AX messaging timeouts are set to 0.1 seconds per message, not for the whole lookup.
2. **Mouse dragged:** mark the gesture as dragged and remember the event's cursor location. A 30Hz timer samples two AX attributes; polling is active only while a candidate exists. Repeated events themselves do not perform AX polling.
3. **Classify:** compare with mouse-down snapshot. Width or height difference **greater than 2pt** → resize; discard the candidate for the rest of this gesture. Otherwise Euclidean position distance **at least 3pt** → move; smaller → stationary. Text selection or drag/drop that leaves the window stationary never displays a grid. The same pure function is tested without AX.
4. **Moving:** choose the display containing the **cursor**, regardless of which screen contains the window. Show that display's whole grid and highlight the hit-tested span. Hide panels on other displays. Reuse each panel; do not order it out/in every poll. If cursor is on a display but outside its visible work area, show no selected span and prepare no target. If cursor is outside all displays, hide all panels.
5. **Mouse up:** sample once more using the release location, rejecting a newly resized/disappeared window or out-of-work-area target. Save the target, clear the gesture, hide panels, then write AX **Position → Size → Position**. Any AX write error is shown in the menu; apps may still clamp size/position while reporting success. Do not activate or focus the target app.

An invalidated window, screen reload, permission loss, or disabled tap clears the gesture and its target. `NSApplication.didChangeScreenParametersNotification` and **Reload Displays / 画面構成を再読込** close old panels and rebuild screen policy/geometry. There are no custom layout settings or saved layouts; krado is zero-setup by design.

## Open at login

The app uses `ServiceManagement.SMAppService.mainApp`. Launch at Login is **off by default**: krado never registers itself. The welcome/permission guide offers it as one optional button (`LoginItemPolicy.onboardingOffer`): **Launch krado at Login** when it can be registered, **Open Login Items Settings…** while macOS waits for approval, a hint when krado is outside Applications, and a confirmation when it is already on. After Accessibility is granted the guide stays open (with **Done**) only while the button is still useful; otherwise it closes itself. The menu checkbox does the same registration. Registration/unregistration failures are retained as localized menu errors and never crash the app. The menu refreshes service status when opened: `.enabled` is checked, `.requiresApproval` shows an approval hint and opens `SMAppService.openSystemSettingsLoginItems()`, `.notRegistered` is off, and `.notFound` is treated as off.

Registration is offered only if `Bundle.main.bundlePath` is inside `/Applications/` or the current user's `~/Applications/` and not under `/AppTranslocation/` (quarantined downloads may run translocated). Otherwise the guide and menu say **Move krado to Applications to launch at login**; an existing registration can still be turned off. `LoginItemPolicy` keeps these pure decisions in KradoCore, normalizes `..`, checks folder boundaries, and is tested without ServiceManagement.

## Updates and signing

Info.plist sets `SUEnableAutomaticChecks` to true, so Sparkle checks on its normal schedule and never shows its "check automatically?" prompt (Sparkle skips the prompt whenever this key is set). `SUAutomaticallyUpdate` and `SUAllowsAutomaticUpdates` are false: a found update is shown in Sparkle's standard alert, and nothing is downloaded or installed without the user choosing to. See [docs/signing-and-update-test.md](signing-and-update-test.md) for the code-signing certificate, the opt-in test feed, and the files krado leaves behind.

## Localization, branding, and distribution

All app-owned menu, guide, tooltip, accessibility, and error text uses `NSLocalizedString` through `L10n`, explicitly with `Bundle.main`. English keys provide readable fallback when running a bare executable; supported app languages are English (default) and Japanese. `Resources/en.lproj` and `Resources/ja.lproj` contain standard `Localizable.strings`. The hand-built app does not use `Bundle.module`. The build script copies both `.lproj` folders and `Resources/AppIcon.icns` into `Contents/Resources` before ad-hoc signing. Info.plist declares `CFBundleDevelopmentRegion=en`, `CFBundleLocalizations=[en, ja]`, and `CFBundleIconFile=AppIcon`.

`scripts/make-icon.swift` draws offscreen using AppKit/CoreGraphics, without starting any GUI application. Run `swift scripts/make-icon.swift` to regenerate the 1024px `docs/assets/icon.png`, 1280×640 `cover.png`, `layouts.png`, iconset PNGs, and `Resources/AppIcon.icns` using local `sips`/`iconutil`. Use `swift scripts/make-icon.swift --layouts-only` to regenerate only the layout diagram. The app icon uses an indigo/teal rounded background, a white 4×2 grid, and a highlighted two-cell span. README.md and README.ja.md give English/Japanese install, usage and privacy notes. The demo GIFs in `docs/assets/demo/`, `layouts*.png`, and the cover subtitles are box-made illustrations from `scripts/readme-art/` (Python + Pillow + ffmpeg); `make-icon.swift` still draws the icon. The build remains ad-hoc signed, without Developer ID signing or notarization; users install a stable copy in Applications and use macOS's explicit Open/Open Anyway flow if blocked. No automated step launches the bundle or opens Settings, browsers, or other GUI apps.

## Overlay behavior

One transparent borderless `NSPanel` per screen, `.nonactivatingPanel`, level `.floating`, `ignoresMouseEvents=true`, `hidesOnDeactivate=false`, no shadow. `canBecomeKey` and `canBecomeMain` are false. Collection behavior contains `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`. All cells have light fill/borders; the single rectangular target span has stronger fill and outline. Panels are excluded from accessibility and never intentionally focus/activate an application.

## Verification and remaining manual checks

Run from the repo root (restricted environments need writable compiler caches):

```sh
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/module-cache"
swift test
scripts/build-app.sh
```

If the host restricts SwiftPM's nested sandbox, use `swift test --disable-sandbox` with those same cache variables. This affects the build sandbox only and never launches the app.

Tests cover 1×1 full-work-area hit tests and snap frames, 2×1/4×1 full-height cells, 1×2 portrait spans, 2×2/4×2 frames, physical-pixel rounding and exact sums, cell interiors, all internal boundaries/intersections, band endpoints and just-outside points, outer edges, custom band/gap, off-grid points, all example display sizes and zone counts (including 3008×1975 → 8 and 1470×924 → 2), every width/aspect/height/orientation threshold and rule priority, built-in/external equivalence, login-path/first-run policy, coordinate round trips across all display arrangements, and movement/resize thresholds. There are no AX or AppKit test targets. macOS 14 is the deployment target; runtime compatibility still needs verification on an actual macOS 14 system.

The test target conditionally adds the selected compiler's bundled Testing macro directory with `-plugin-path`, working around the [Swift 6.4 CLT macro discovery issue](https://github.com/swiftlang/swift-build/issues/1870). The manifest resolves `SWIFT_EXEC` or `xcrun --find swiftc` and checks that the macro exists. No downloaded dependency or fixed Xcode install path is involved; the app and Core targets receive no extra flags. Remove the workaround once the toolchain issue is fixed. This CLT installation also emits linker warnings for nonexistent `Developer/Library/Frameworks` and `Developer/usr/lib` search directories; builds still succeed.

GUI checks are intentionally left to Kazina; this implementation was not launched during development:

- Permission denied at startup: guide appears without a system prompt or tap; only its settings button requests the prompt once. Check one-second approval detection, All set/auto-close, closing/reopening, revocation, tap failures, and reauthorization after an ad-hoc rebuild.
- Verify English/Japanese guide fitting, menu labels, state icons and accessibility descriptions, per-display layouts, About version, and GitHub link. Check that Launch at Login stays off until chosen, the guide button only from Applications, requiresApproval/settings, registration errors, and the move hint outside Applications or under App Translocation.
- Start with windows already open. Drag title bars on the built-in screen and an external display; cross between displays in both directions and confirm the cursor determines the grid. Exercise left/above/below arrangements, menu bar/Dock exclusions, and screen reconfiguration while dragging.
- Verify 1×1 shows one zone and fills the visible frame on drop, no horizontal internal edge in 2×1/4×1, stacked halves in eligible portrait screens, and 1/2/4-cell drops and ±12pt boundaries; move back toward the starting position; verify resizing, text selection, and drag/drop do not snap.
- Verify panels never steal keyboard focus or mouse input, including across Spaces and full-screen applications; quit/reload must remove overlays.
- Check native macOS edge tiling and apps with minimum sizes or incomplete AX support. Movement is inferred rather than a guaranteed title-bar hit. A native tile resize cancels krado's gesture. Synchronous mouse-up AX writes may race an application's final drag processing; only real GUI testing can establish whether a delayed placement is needed.

v0.1 does not force apps past size constraints, verify the final applied AX frame, or recover an app's original frame after partial write failure. Full-screen/secure UI and nonstandard windows may be inaccessible or refuse movement. Those cases are skipped or reported when AX returns an error, and are not claimed to be validated by pure-logic tests.
