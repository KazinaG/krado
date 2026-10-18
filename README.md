![krado — Drag a window. Drop it on the grid.](docs/assets/cover.png)

# krado
English | [日本語](README.ja.md)

**Drag a window. Drop it on the grid.** A free, open-source menu-bar window-tiling app for macOS.

krado means 'grid' (マス目) in Esperanto, pronounced 'KRAH-doh' (クラード).

## Features

- Drag a window normally; a grid appears once the window starts moving. Release to snap.
- Drop near an internal boundary to span two cells, or an intersection to span four.
- Automatic layouts sized for each display, including portrait screens and ultrawides.
- Multiple displays, Retina pixel alignment, and work areas that respect the Dock and menu bar.
- A clear menu-bar status, friendly Accessibility setup, and an Open at Login toggle.
- The interface follows your macOS language setting (Japanese localization included).
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

1. **Get krado.app and move it to Applications.** Packaged downloads, when published, are available on the [Releases page](https://github.com/KazinaG/krado/releases). If you build from source instead, run `scripts/build-app.sh` from the repository folder to create `dist/krado.app`.

   Drag **krado.app** into the **Applications** folder (`/Applications`). **Open at Login** needs krado to be in an Applications folder; your personal Applications folder (`~/Applications`) also works. Keep one installed copy there.

2. **Open krado and allow it through macOS security.** krado is not yet signed with an Apple Developer ID or notarized, so macOS may warn that the developer is unidentified or that it cannot verify the app. Only proceed with a copy you trust.

   - **macOS 15 Sequoia and later (including macOS 26/27):**
     1. Double-click **krado** in Applications. When the warning appears, click **Done**. Do not move it to Trash.
     2. Open **System Settings → Privacy & Security**, then scroll down to **Security**.
     3. Find the message that **“krado was blocked…”** and click **Open Anyway**.
     4. Enter your password or use Touch ID, then click **Open Anyway** again in the next dialog.

     This approval is only needed once for that copy. **Control-click → Open no longer bypasses this warning on macOS 15 or later.**
   - **macOS 14 Sonoma:** Control-click (right-click) **krado** in Applications, then choose **Open → Open**.
   - **Advanced (Terminal):** after moving a trusted copy to Applications, you can remove its quarantine attribute instead:

     ```sh
     xattr -dr com.apple.quarantine /Applications/krado.app
     ```

3. **Allow Accessibility so krado can arrange windows.** krado needs this permission to see where other apps' windows are and to move or resize them when you drop them on the grid.

   **Privacy:** krado does not read what you type, does not record or look at screen contents, and has no network access. It only watches mouse drags to know when a window is being moved. It does not request Screen Recording permission.

   1. On first launch, krado shows a setup guide. Click **Open System Settings**.
   2. In **System Settings → Privacy & Security → Accessibility**, turn on **krado**. If it is missing, click **+** and add `/Applications/krado.app`.
   3. krado detects the permission automatically, shows **All set!**, and closes the guide. You can now drag windows onto the grid.

   You can reopen the guide from the Accessibility status in krado's menu.

4. **If an updated or rebuilt copy asks for Accessibility again, replace the old permission entry.** macOS ties this permission to the exact app build. Because krado is not Developer ID signed, each new build looks like a different app.

   In **System Settings → Privacy & Security → Accessibility**, select the old **krado** entry and remove it with **−**. Then turn on the new **krado** entry; use **+** to add `/Applications/krado.app` if it is missing. You can click **Open System Settings** in krado's guide again to return to these settings. krado detects the new permission automatically.

## Open at Login

krado enables **Open at Login** by default on its first eligible launch. Toggle it in the menu at any time. If macOS requires approval, the menu offers a link to **Login Items** in System Settings.

Automatic registration is skipped when the app is outside `/Applications` or `~/Applications`, or runs from an **AppTranslocation** path. The menu asks you to move it to Applications. Move the app, resolve any quarantine/opening restriction, and reopen it from that stable location; then use the toggle if needed. Registration errors appear in the menu and do not stop window tiling.

## Usage

1. Drag a normal app window by its title bar.
2. Move onto the desired grid cell. Near an internal divider, the highlight expands to two cells; at a 2 × 2 or 4 × 2 grid intersection it expands to four.
3. Release to place the window. Release outside the visible work area to leave it unsnapped.

- **Shift + drag:** hold Shift and sweep across cells to select their bounding rectangle, including three or four columns and multiple rows. Selection starts at the current cell when Shift goes down, includes boundary highlights, and stays selected outside the work area. Moving to another display starts a new selection there; releasing Shift returns to the normal highlight.
- **Option + drag:** ignore zones and hide the grid while Option is held. Release Option before dropping to resume snapping; dropping with Option held never snaps. Option takes precedence over Shift and clears its selection.
- **Ctrl + Cmd + Arrow:** move the focused window one zone, keeping its span size. An unaligned window first snaps to the cell containing its centre. At a display edge, move to the nearest facing zone on an adjacent display, if available.
- **Ctrl + Cmd + Shift + Arrow:** extend the window's span by one cell in that direction, within the current display. An unaligned window starts from the cell containing its centre.

These shortcuts avoid Ctrl + Option because it is VoiceOver's modifier. Ctrl + Cmd + Arrow has a minor overlap with Xcode navigation while krado is running.

The boundary band is 24pt wide (12pt on either side). Outer edges do not combine cells. A single-row layout has no horizontal internal divider. In 1 × 1, dropping anywhere in the zone fills the visible work area. There are no gaps between tiles. Resizing a window cancels snapping for that drag. Windows opened before krado are supported.

Use **Reload Displays** after a display change if needed; screen changes are also detected automatically. The menu includes **About krado**, a GitHub link, and **Quit krado**.

## Troubleshooting

- **Allowed, but windows do not snap:** check the menu's monitoring status and Accessibility setting. Quit and reopen krado from its installed location. Reload displays if the geometry looks outdated.
- **Asked for permission again after an update or rebuild:** follow step 4 of [Install](#install) to replace the old Accessibility entry.
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

## Feedback & contributions

krado is public, free & open source, and available under the [MIT license](LICENSE). Outside pull requests and code contributions are not accepted. Feedback, questions, and bug reports are welcome via [GitHub Issues](https://github.com/KazinaG/krado/issues). See [CONTRIBUTING.md](CONTRIBUTING.md) for this policy.

You may fork and modify krado for yourself under MIT. To build and test your own copy from source:

```sh
swift test
scripts/build-app.sh
```

## License

[MIT](LICENSE) © 2026 Kazina.
