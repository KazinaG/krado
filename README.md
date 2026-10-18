![krado — Drag a window. Drop it on the grid.](docs/assets/cover.png)

# krado

**Drag a window. Drop it on the grid.** A free, open-source menu-bar window-tiling app for macOS.

English · [日本語](README.ja.md)

krado means 'grid' (マス目) in Esperanto, pronounced 'KRAH-doh' (クラード).

## Features

- Drag a window normally; a grid appears once the window starts moving. Release to snap.
- Drop near an internal boundary to span two cells, or an intersection to span four.
- Automatic layouts sized for each display, including portrait screens and ultrawides.
- Multiple displays, Retina pixel alignment, and work areas that respect the Dock and menu bar.
- A clear menu-bar status, friendly Accessibility setup, and an Open at Login toggle.
- English and Japanese UI. English is the default; macOS chooses the language from your preferences.
- Local operation, no accounts, no dependencies, and an MIT license.

## How it works

krado observes mouse drags and uses macOS Accessibility to read a window's position and size. When the window moves, it shows a grid on the **display under the cursor**. Releasing over the highlighted area moves and resizes the window to fit it. No modifier key is needed.

Layouts use the display's **visible work area in points**, not its hardware resolution. Let `W` be its width and `H` its height. Evaluate the following rules from top to bottom; built-in and external displays use the same rules.

| Visible work area (first matching rule) | Columns × rows | Examples |
| --- | --- | --- |
| Portrait: `H > W` | **1 × 2** if `H ≥ 1200`; otherwise **1 × 1** | Stacked halves when tall enough; no split on short portrait screens |
| Ultrawide: `W/H ≥ 2.1` **and** `W ≥ 2400` | **4 × 2** if `H ≥ 1300`; otherwise **4 × 1** | 3440 × 1410pt → 4 × 2; 2560 × 1050pt → 4 × 1 |
| Large / 4K-class: `W ≥ 2800` | **4 × 2** | a large display at **3008 × 1975pt → 8 zones**; 3840 × 2135pt |
| Mid-size: `W ≥ 1800` | **2 × 2** | 1920 × 1055pt; 2560 × 1415pt; 16-inch MBP at 2056 × 1305pt; 14-inch MBP at 1800 × 1137pt |
| Small / MacBook Air 13-class: `W ≥ 1200` | **2 × 1** | Owner's built-in **1470 × 924pt → 2 zones**; 1280 × 800pt; 1710 × 1074pt; 1512 × 950pt; 1728 × 1085pt |
| Otherwise | **1 × 1** (no split) | 1024 × 740pt: one zone fills the visible work area |

![Automatic layouts: large 4 × 2, mid-size 2 × 2, small 2 × 1, tiny 1 × 1, with portrait and ultrawide notes](docs/assets/layouts.png)

The goal is zones roughly at least **640pt wide and about 500pt tall** for typical app windows. Mid-size displays use 2 × 2 per the owner's preference. Below about 1200pt wide, even halves become too narrow, so krado uses one full-work-area zone. The thresholds are approximate: a 1200pt-wide display gets 600pt halves, and apps can impose their own minimum sizes. Portrait takes priority; ultrawide takes priority over the large width band, so 2800 × 1000pt gets 4 × 1.

## Requirements

- macOS **14 or later**.
- Accessibility permission to read and move other apps' windows.
- Building from source: Swift **6 or later** and Apple's Command Line Tools. No Xcode project or external packages are required.

## Install

Packaged downloads, when published, are available on the [Releases page](https://github.com/KazinaG/krado/releases). To build v0.1.0 from a source checkout:

```sh
scripts/build-app.sh
```

This creates `dist/krado.app`, attempts ad-hoc signing, and never launches the app. Move **krado.app to `/Applications`** (or `~/Applications`), then open it yourself. Keep one copy in a stable location so Accessibility and login-item registration can identify it consistently.

The current build is **not Developer ID signed or notarized**. For a downloaded copy that you trust, use **right-click → Open**, or **System Settings → Privacy & Security → Open Anyway** if macOS offers that action. Alternatively, after moving the app, remove its quarantine attribute in Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/krado.app
```

The build script uses local compiler caches and disables SwiftPM's build sandbox by default for restricted CLI environments. Set `KRADO_DISABLE_SANDBOX=0` to retain SwiftPM's sandbox. This does not change macOS privacy protections. Release builds omit debug information; signing failures are reported as warnings.

## First launch and permissions

If Accessibility has not been allowed, krado opens a small setup guide:

1. Choose **Open System Settings** in the guide. This requests the system permission prompt once and opens Accessibility settings.
2. In **System Settings → Privacy & Security → Accessibility**, enable **krado**. Use `+` to add `/Applications/krado.app` if it is missing.
3. Return to krado. The guide checks about once a second while open, shows **All set!**, and closes. Window-drag monitoring starts automatically.

You can reopen the guide from the menu's Accessibility status. The menu also shows whether drags are being watched, any monitoring error, and each display's current grid and zone count; 1 × 1 is labeled **no split**.

**Privacy:** krado needs Accessibility only to read and move other apps' windows. It never reads keystrokes or screen contents and sends nothing over the network. It does not request Screen Recording permission.

## Open at Login

krado enables **Open at Login** by default on its first eligible launch. Toggle it in the menu at any time. If macOS requires approval, the menu offers a link to **Login Items** in System Settings.

Automatic registration is skipped when the app is outside `/Applications` or `~/Applications`, or runs from an **AppTranslocation** path. The menu asks you to move it to Applications. Move the app, resolve any quarantine/opening restriction, and reopen it from that stable location; then use the toggle if needed. Registration errors appear in the menu and do not stop window tiling.

## Usage

1. Drag a normal app window by its title bar.
2. Move onto the desired grid cell. Near an internal divider, the highlight expands to two cells; at a 2 × 2 or 4 × 2 grid intersection it expands to four.
3. Release to place the window. Release outside the visible work area to leave it unsnapped.

The boundary band is 24pt wide (12pt on either side). Outer edges do not combine cells. A single-row layout has no horizontal internal divider. In 1 × 1, dropping anywhere in the zone fills the visible work area. There are no gaps between tiles. Resizing a window cancels snapping for that drag. Windows opened before krado are supported.

Use **Reload Displays** after a display change if needed; screen changes are also detected automatically. The menu includes **About krado**, a GitHub link, and **Quit krado**.

## Troubleshooting

- **Allowed, but windows do not snap:** check the menu's monitoring status and Accessibility setting. Quit and reopen krado from its installed location. Reload displays if the geometry looks outdated.
- **After an update or rebuild:** in Accessibility settings, remove the old krado entry with `−`, then use `+` to add the current app and enable it again. An ad-hoc rebuild can invalidate a previous grant.
- **Open at Login unavailable:** move the app to `/Applications` or `~/Applications`, reopen it, and check **System Settings → General → Login Items** for pending approval. Translocated or quarantined copies may need the installation steps above first.
- **A window will not fit:** some apps enforce minimum sizes or do not expose writable Accessibility position/size. Native macOS tiling and full-screen or protected windows may also limit placement. krado skips unsupported windows; it does not override app constraints.

Movement is inferred from window position and size. A moved window can be detected even when a drag did not start on its title bar. Real-world permission, Spaces/full-screen, focus, and app-specific behavior need manual verification; pure logic tests do not establish those behaviors. See [design and manual checks](docs/design.md).

## Roadmap

- Esc to cancel a drag.
- Customizable layouts per display.
- Keyboard shortcuts.
- Homebrew cask.
- Developer ID signed and notarized builds.
- App Store distribution later.

## Contributing

Issues and pull requests are welcome. Run the pure KradoCore suite and build the bundle:

```sh
swift test
scripts/build-app.sh
```

Tests use Swift Testing and do not launch krado, create event taps, or request permissions. KradoCore stays free of AppKit and Accessibility APIs. See [docs/design.md](docs/design.md) for architecture and remaining manual checks.

To regenerate the icon, cover, and layout diagram using offscreen AppKit/CoreGraphics drawing and the macOS `sips`/`iconutil` tools:

```sh
swift scripts/make-icon.swift
```

To regenerate only the layout diagram, use `swift scripts/make-icon.swift --layouts-only`.

Generated PNGs and `Resources/AppIcon.icns` are included in the repository; ordinary builds do not regenerate artwork.

## License

[MIT](LICENSE) © 2026 Kazina.
