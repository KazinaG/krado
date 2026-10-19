![krado — Drag a window. Drop it on the grid.](docs/assets/cover.png)

# krado

English | [日本語](README.ja.md) · [Changelog](CHANGELOG.md)

**Drag a window. Drop it on the grid.** krado is a small menu-bar app that tiles windows on macOS. There is nothing to set up: it picks a grid that fits each screen.

![Dragging a window onto the grid](docs/assets/demo/drag-snap.gif)

## A grid that fits each screen

krado chooses the split from the screen's size, as set in **System Settings → Displays**. Every screen, built-in or external, follows the same rules.

| Screen | Grid | For example |
| --- | --- | --- |
| Large | **4 × 2** | Big high-resolution displays (about 2800 wide or more) |
| Medium | **2 × 2** | Typical desktop monitors such as 1920 × 1080 or 2560 × 1440 |
| Small | **2 × 1** | MacBook screens at their default size |
| Very small | **1 × 1** | Narrow or low-resolution screens |
| Portrait | **1 × 2** | A monitor turned vertical (short portrait screens stay 1 × 1) |
| Ultrawide | **4 × 1** or **4 × 2** | Very wide monitors, with two rows when tall enough |

![Grids for large, medium, small, very small and portrait screens](docs/assets/layouts.png)

## Use it

Drag any window by its title bar. A grid appears on the screen under the pointer; release to drop the window into the highlighted zone. Near a line between zones, the highlight covers both sides.

| | |
| --- | --- |
| **Shift + drag** — sweep across zones to cover all of them. | ![Shift + drag spans several zones](docs/assets/demo/shift-drag.gif) |
| **Option + drag** — ignore the grid and drop the window anywhere. | ![Option + drag ignores the grid](docs/assets/demo/option-drag.gif) |
| **Esc while dragging** — cancel snapping for this drag; the window stays where you release it. | ![Esc cancels snapping](docs/assets/demo/esc-cancel.gif) |
| **Keyboard** — **⌃⌘ + arrow** moves the active window one zone (and onto the next screen at the edge). **⌃⌘⇧ + arrow** grows it; the opposite arrow shrinks it back. | ![Move, grow and shrink with the keyboard](docs/assets/demo/keyboard.gif) |

The menu-bar icon shows whether krado is working. Its menu has **Launch at Login** (off until you turn it on; the welcome window offers it as one click) and **Check for Updates…**. krado checks for updates automatically and always asks before installing one.

## Install

Requires macOS 14 or later.

1. Download `krado-x.y.z.dmg` from [Releases](https://github.com/KazinaG/krado/releases), open it, and drag **krado** to **Applications**.
2. Open krado. If macOS says it cannot verify the app:
   - **macOS 15 or later:** click **Done**, then go to **System Settings → Privacy & Security** and click **Open Anyway**.
   - **macOS 14:** Control-click krado in Applications and choose **Open**.
3. Allow **Accessibility** when krado asks. It needs this to move and resize other apps' windows. krado detects the permission automatically.

Releases are signed with the same certificate every time, so updates keep the Accessibility permission. If macOS still asks again, remove the old **krado** entry in **System Settings → Privacy & Security → Accessibility** and turn on the new one.

## Privacy

krado only watches mouse drags, the Esc key while you drag, and its own shortcuts, and moves windows through Accessibility. It does not read what you type or look at your screen. Nothing leaves your Mac except update checks, which fetch the update feed from GitHub.

## Troubleshooting

- **No grid appears when dragging:** check the status in krado's menu and that krado is on in **Accessibility**, then quit and reopen it.
- **A window won't fit:** some apps limit their window size or position; krado leaves those as they are.

## Feedback

Questions and bug reports are welcome in [GitHub Issues](https://github.com/KazinaG/krado/issues). Pull requests are not accepted; see [CONTRIBUTING.md](CONTRIBUTING.md).

To build it yourself: `swift test`, then `scripts/build-app.sh` (Swift 6 or later).

## License

[MIT](LICENSE) © 2026 Kazina.
