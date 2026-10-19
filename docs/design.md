# krado v0.1 design

## Modules and scope

Swift Package, macOS 14+, Swift 6, no package dependencies:

| Target | Responsibility |
| --- | --- |
| `KradoCore` | Value types and pure grid, hit-test, coordinate, layout-policy, movement functions; Foundation/CoreGraphics, no AppKit or AX |
| `Krado` | Menu-bar executable; AppKit panels/displays, listen-only CGEvent tap, AX lookup/read/write |
| `KradoCoreTests` | Swift Testing; depends only on KradoCore; no GUI, event tap, or permission calls |

`scripts/build-app.sh` builds release code with CLI SwiftPM, installs the executable as `dist/krado.app/Contents/MacOS/krado`, writes Info.plist, and signs with `KRADO_SIGN_IDENTITY` (the release certificate) or ad hoc when it is unset. Bundle ID: `io.github.kazinag.krado`; version: `0.1.1`; minimum macOS: `14.0`; `LSUIElement=true`. Signing failure warns and continues. No Apple Developer membership, Developer ID signing, notarization, external packages, or Xcode project is required. The script does not launch the bundle.

Release bundling passes `-debug-info-format none`: no dSYM is needed for v0.1 distribution, and this avoids a `dsymutil` operation rejected by the host sandbox. Debug `swift build` retains debug information for development.

## Display policy and geometry

Policy input is `ScreenDescriptor(isBuiltin, visibleSize, name)`; both name and `isBuiltin` are informational, and the same policy applies to built-in and external screens. `visibleSize` carries the **whole** screen size, `NSScreen.frame`, in **points** (not hardware pixels), so showing or hiding the Dock or menu bar never changes the grid. The zones themselves still fill the visible work area (`NSScreen.visibleFrame`, excluding the Dock and menu bar on any edge).

One rule, no special cases: keep halving across and down while each zone stays at least 640 pt wide and 720 pt tall.

- columns = the largest of 1, 2, 4, 8 with W / columns ≥ 640
- rows = the largest of 1, 2, 4 with H / rows ≥ 720

Examples: MacBook Air 13 (1470 × 956) and 15 (1710 × 1112) → 2 × 1; 1280 × 832 → 2 × 1; 1920 × 1080 → 2 × 1; 2560 × 1440 → 4 × 2; 3008 × 1692 and 3008 × 2005 → 4 × 2; 4K native 3840 × 2160 → 4 × 2; 5K, 6K and 8K native → 8 × 4; portrait 1080 × 1920 → 1 × 2, portrait 4K native → 2 × 4; ultrawide 2560 × 1080 → 4 × 1, 3440 × 1440 → 4 × 2, 5120 × 1440 → 8 × 2; narrower than 1280 pt → 1 column. Constants live in `GridPolicy`; `GridPhilosophyTests` holds the display table.

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

The standard NSMenu always shows the ステータス / 起動 / krado section headings.
Display-name rows appear only when two or more displays are connected.
Quit follows a separator without a heading. Status rows use standard attributed
secondary lines and palette SF Symbols.

Launch at Login uses a leading `power.circle` image and a trailing
`NSMenuItemBadge` showing On / Off / Needs approval, with no checkmark. Its
accessibility label is "<title>、<state>" and its value is <state>. State is read
from `SMAppService.mainApp.status` on every menu opening and after toggling.
Approval is a separate visible state. `LoginRowPresentation` keeps the mapping
pure and tested.

Production rows have no `NSMenuItem.view`: Apple's [Views in Menu Items](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/ViewsInMenuItems.html)
explains that a view item does not draw its title or state and does not support
keyboard events. Native rows retain system material, highlighting, navigation and
VoiceOver. `KRADO_LOGIN_SWITCH_PROBE=1` is an evidence-only build with a standard
NSSwitch and label in a view, with acceptsFirstMouse enabled; it is never offered
to users. CI screenshots must establish its actual appearance and keyboard behavior.

`KRADO_CI_HOOKS=1` compiles runner-only hooks. `KRADO_CI_LOGIN=on|off` performs real
registration/unregistration before opening the menu, logs errors, raw service status
and mapped state, and logs displayed badge/detail text. `KRADO_CI_OPEN_MENU=1`
opens the menu after two seconds; onboarding and Sparkle starts are suppressed.
`KRADO_CI_STATE=permissionNeeded` remains a displayed-permission hook.
`scripts/menu-shots.sh` installs each A/P app in /Applications and launches it
directly in Japanese. It retains launch logs, SDK evidence, full captures, window
bounds, and crops with a 40-point margin. Each variant is captured with login on
and off using runner-default transparency, then on again after disabling Reduce
Transparency on the disposable runner. A and P also record Down/Return evidence
and service readback after activation. Apple-menu reference shots remain included.

The C tap callback is scheduled exclusively on `CFRunLoopGetMain()` in common modes; `MainActor.assumeIsolated` reflects that scheduling guarantee. AppKit, AX state, timers, and panel changes stay on the main actor. Disabled-by-timeout or disabled-by-user-input events cancel the drag and re-enable the tap if still trusted. The callback returns the original event without modifying or consuming it. Shutdown invalidates timers, tap, source, and notification observation.

## Drag lifecycle

1. **Mouse down:** clear old state. Use a system-wide AX hit test at the CGEvent location. Resolve `AXWindow` directly or walk up `AXParent` (at most 16 steps), accepting a window role. Skip krado's own windows and windows without settable AX position and size. Capture the current window position and size; this works for windows opened before krado. AX messaging timeouts are set to 0.1 seconds per message, not for the whole lookup.
2. **Mouse dragged:** mark the gesture as dragged and remember the event's cursor location. A 30Hz timer samples two AX attributes; polling is active only while a candidate exists. Repeated events themselves do not perform AX polling.
3. **Classify:** compare with mouse-down snapshot. Width or height difference **greater than 2pt** → resize; discard the candidate for the rest of this gesture. Otherwise Euclidean position distance **at least 3pt** → move; smaller → stationary. Text selection or drag/drop that leaves the window stationary never displays a grid. Once a move is detected, returning near the initial position keeps the grid visible for the remainder of the gesture. The same pure function is tested without AX.
4. **Moving:** choose the display containing the **cursor**, regardless of which screen contains the window. Show that display's whole grid and highlight the hit-tested span. Hide panels on other displays. Reuse each panel; do not order it out/in every poll. If cursor is on a display but outside its visible work area, show no selected span and prepare no target. If cursor is outside all displays, hide all panels.
5. **Mouse up:** sample once more using the release location, rejecting a newly resized/disappeared window or out-of-work-area target. Save the target and clear the gesture while retaining the panel for the glide (see Motion below). The window glides with bounded AX steps. Any AX write error is shown in the menu; apps may still clamp size/position while reporting success. Do not activate or focus the target app.

An invalidated window, screen reload, permission loss, or disabled tap clears the gesture and its target. `NSApplication.didChangeScreenParametersNotification` and **Reload Displays / 画面構成を再読込** close old panels and rebuild screen policy/geometry. There are no custom layout settings or saved layouts; krado is zero-setup by design.

## Open at login

The app uses `ServiceManagement.SMAppService.mainApp`. Launch at Login is **off by default**: krado never registers itself. The welcome/permission guide offers it as one optional button (`LoginItemPolicy.onboardingOffer`): **Launch krado at Login** when it can be registered, **Open Login Items Settings…** while macOS waits for approval, a hint when krado is outside Applications, and a confirmation when it is already on. After Accessibility is granted the guide stays open (with **Done**) only while the button is still useful; otherwise it closes itself. The menu login row does the same registration. Registration/unregistration failures are retained as localized menu errors and never crash the app. The menu refreshes service status when opened: `.enabled` is shown as on, `.requiresApproval` shows a distinct approval state and hint and opens `SMAppService.openSystemSettingsLoginItems()`, `.notRegistered` is off, and `.notFound` is treated as off.

Registration is offered only if `Bundle.main.bundlePath` is inside `/Applications/` or the current user's `~/Applications/` and not under `/AppTranslocation/` (quarantined downloads may run translocated). Otherwise the guide and menu say **Move krado to Applications to launch at login**; an existing registration can still be turned off. `LoginItemPolicy` keeps these pure decisions in KradoCore, normalizes `..`, checks folder boundaries, and is tested without ServiceManagement.

## Updates and signing

Info.plist sets `SUEnableAutomaticChecks` to true, so Sparkle checks on its normal schedule and never shows its "check automatically?" prompt (Sparkle skips the prompt whenever this key is set). `SUAutomaticallyUpdate` and `SUAllowsAutomaticUpdates` are false: a found update is shown in Sparkle's standard alert, and nothing is downloaded or installed without the user choosing to. See [docs/signing-and-update-test.md](signing-and-update-test.md) for the code-signing certificate, the opt-in test feed, and the files krado leaves behind.

## Localization, branding, and distribution

All app-owned menu, guide, tooltip, accessibility, and error text uses `NSLocalizedString` through `L10n`, explicitly with `Bundle.main`. English keys provide readable fallback when running a bare executable; supported app languages are English (default) and Japanese. `Resources/en.lproj` and `Resources/ja.lproj` contain standard `Localizable.strings`. The hand-built app does not use `Bundle.module`. The build script copies both `.lproj` folders and `Resources/AppIcon.icns` into `Contents/Resources` before ad-hoc signing. Info.plist declares `CFBundleDevelopmentRegion=en`, `CFBundleLocalizations=[en, ja]`, and `CFBundleIconFile=AppIcon`.

`scripts/make-icon.swift` draws offscreen using AppKit/CoreGraphics, without starting any GUI application. Run `swift scripts/make-icon.swift` to regenerate the 1024px `docs/assets/icon.png`, 1280×640 `cover.png`, `layouts.png`, iconset PNGs, and `Resources/AppIcon.icns` using local `sips`/`iconutil`. Use `swift scripts/make-icon.swift --layouts-only` to regenerate only the layout diagram. The app icon uses an indigo/teal rounded background, a white 4×2 grid, and a highlighted two-cell span. README.md and README.ja.md give English/Japanese install, usage and privacy notes. The demo GIFs in `docs/assets/demo/`, `layouts*.png`, and the cover subtitles are box-made illustrations from `scripts/readme-art/` (Python + Pillow + ffmpeg); `make-icon.swift` still draws the icon. Releases are signed with the free "krado Self-Signed" certificate (no Developer ID, no notarization), so the Accessibility grant survives updates; users install a stable copy in Applications and use macOS's explicit Open/Open Anyway flow if blocked. No automated step launches the bundle or opens Settings, browsers, or other GUI apps.

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

## Motion

ウインドウ本体 glides
from its drop frame to the zone for about 0.20 seconds with ease-out cubic timing.
A main-run-loop `NSScreen.displayLink(target:selector:)` (public since macOS 14)
drives whole-point AX steps. Progress is elapsed wall-clock time divided by the
0.20-second duration: slow AX writes produce fewer frames, never extra animation
time. Each step skips unchanged size/position, writes size first while in full
mode, reads the actual frame, and anchors position after any app-induced move.
A size deviation greater than 2 points or a size write exceeding one display
frame (`1000 / refreshRate` ms, about 16.7 ms at 60 Hz) switches permanently to
position-only frames for this glide. Position uses the actual size so the zone's
outer display edge (or centre for interior/full-display zones) follows the eased
path. This hybrid defers further size writes to the final placement.

Any failed write/read or individual size/position write exceeding
`MotionSpec.abortWriteMilliseconds` (80 ms) ends stepping. Completion, abort,
a new mouse-down, cancellation, or a new snap attempts the existing final
`Accessibility.setFrame` (Position → Size → Position) placement once. AX calls
share the wall-clock budget; an in-flight synchronous call and the final placement
can still block past the duration, up to the AX messaging timeout per call.
The pure `MotionSpec.nextMode` decision and actual-size anchoring are tested in
KradoCore. The 光る枠 stays at the target during the glide and hides through the
completion callback when it lands.

Motion honors `accessibilityDisplayShouldReduceMotion`: placement and
layer/panel transitions become instant.

The grid uses cached static tile layers, rebuilt only for geometry/system colors.
The 光る枠 is a separate shape layer: position, bounds, and rounded path animate
for 0.12 seconds from their current presentation values, including Shift span
changes; its first appearance fades and grows. Retargeting neither redraws tiles
nor changes panel alpha. The previous redraw-per-target code and the stationary
branch's hide when returning near the original position were flicker sources.
Movement now latches for the gesture, while resize detection remains active.
Other-screen hide calls were already guarded, but now run only when the active
display changes. Release retains the existing panel through the landing effect
instead of hiding it before placement. Option, Escape, invalid windows, leaving
all screens, screen reload, and gesture cancellation still hide appropriately.
A panel fades in only on a visibility transition, never on a cell/span change.

The CI-only motion lab measures S0–S3 three times each, saves individual AX write
latencies and pixel-scaled readback deviation, and captures the app on
macOS 15 and 26. It inherits runner grants and never modifies TCC. Missing AX or
capture permissions are logged rather than treated as measurements of motion.
`screen.log` prints GridPolicy's whole-screen layout (1920×1080 → 2×1,
1024×768 → 1×1; the latter cannot demonstrate an internal cell crossing).
Artifacts `motion-lab-macos-15` and `motion-lab-macos-26` contain `lab/`, `video/`,
and `logs/`, sourced from `dist/lab`, `dist/video`, and `dist/logs`. The app stays in
`dist/krado.app` locally on the runner. Lab hooks `KRADO_LAB_HOOKS`,
`KRADO_LAB_GRID`, `KRADO_LAB_IGNORE_REDUCE_MOTION` and `KRADO_LAB_LOG` remain available.
