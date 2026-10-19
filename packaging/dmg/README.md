# DMG window

The window that opens with `krado-<version>.dmg` (style B, round 7 B, chosen by Kazina
on 2026-10-19): a light gradient, the "krado" wordmark and "Drag krado to Applications"
on top, two square cards with 160-pt icons (krado; Applications as the mint target),
and 0.1.0's dotted arrow centred between the cards at icon height.

- `layout.json`: shared geometry (660 × 430 pt content plus a 32 pt title bar, 160 pt
  icons at (164, 229) and (496, 229), 224-pt cards from y 139, the arrow). 430 pt so
  that with Finder's Path Bar and Status Bar both on, macOS 26 shows no scroll bar.
- `make_backgrounds.py`: draws the background as SVG and renders 1x + @2x PNGs
  (`pip install cairosvg`). The PNGs are committed, so CI needs no renderer or fonts;
  `--check` only asserts the geometry and centring (standard library, run by the
  Release workflow): icons level and centred about W/2, 32-pt padding around the icon
  in its card, icon and label inside the card, the 74-pt arrow clear of the cards with
  equal gaps on both sides, and the composition (wordmark top to card bottom) 1.5-3.5 %
  above the centre of the content area.
- `settings.py`: the dmgbuild layout. `scripts/make-dmg.sh` uses it by default
  (`DMG_STYLE=B`); `DMG_STYLE=plain` builds the old plain window.
- `requirements.txt`: dmgbuild and its two dependencies, pinned with hashes. Installed
  into `.build/dmgbuild-venv` on the build machine only; nothing is installed for users.

## Design notes

- Model: the Ghostty and ChatGPT DMGs (660-pt-wide window, 160-pt icons, a small arrow
  between them, the group optically centred, generous air), shot in Finder at 2x next to
  krado. Cards spaced like Arc's frame. Notion Calendar (+14 %) and Figma (−6 %) show how
  far off-centre looks wrong.
- Optical centre: the composition sits about 2.5 % above the centre of Finder's content
  area (the area below the title bar, which is 32 pt on macOS 26 and 28 pt on macOS 15;
  `window_rect` and .DS_Store's WindowBounds include it).
- Arrow: 0.1.0's dotted arrow (74 pt, dasharray "1 8", 2.6 pt, round caps, 9 × 8
  chevron). Its colours #b3b5ff → #66f2d6 keep their hue and saturation with lower
  lightness (#7579ff → #0d967b) for 3:1 on the light background. Its ink leaves 15.2 pt
  to each card.
- Padding in the cards: the icon centre is 90 pt below the card top, so the space above
  the icon art and below the label averages out over macOS 15 and 26. krado's icon art
  fills its square on macOS 15 and has a margin on macOS 26, so on 15 the space above it
  is about 7 pt smaller; Applications' folder art has empty space on top on both.
- The colours are part of the image: Finder shows a static picture, so the window
  cannot follow the user's accent colour or Dark Mode. With a background picture Finder
  draws icon labels in black, which the light background keeps readable.
- Finder ignores the DMG for some settings: View > Show Path Bar / Show Status Bar and
  "Show all filename extensions" are the user's global preferences. Look at the `bars`
  screenshots of the render job before publishing.

## CI tools (GitHub macOS runners only, never on a personal Mac)

- `render/render-dmg.sh`: opens a DMG in Finder and screenshots the real window with
  default preferences and with both bars and extensions on. The Release workflow's
  `render` job runs it on macos-15 and macos-26 for every DMG it builds (artifacts
  `render-<os>`); a draft release is only created after it passes.
- `shoot/` and the `DMG shoot` workflow (by hand): shoots krado's DMG at 1x and on a 2x
  virtual display next to the DMGs in `shoot/refs.tsv`, downloaded from their official
  sites into the runner's temporary folder and deleted after the shot (only screenshots
  and text are kept). `shoot.sh` also asks Finder where it put each item and reads
  .DS_Store. `hidpi-display.m` uses CoreGraphics' private `CGVirtualDisplay` class (as
  Chromium's tests do) and is only compiled on the runner; it rewrites Finder
  preferences and relaunches Finder.
