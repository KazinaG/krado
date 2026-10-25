# DMG window

The window that opens with `krado-<version>.dmg` has a light gradient,
the "krado" wordmark and "Drag krado to Applications" on top, two square cards with
144-pt icons (krado; Applications as the mint target), and a dotted arrow between them.
The wordmark has a gradient, the background starts at white, and the destination
card is emphasized without corner guides. The checks of this window before release (Finder at 1x and 2x) are in the
[release checklist](../../docs/RELEASING.md#release-checklist).

- `layout.json`: shared geometry (700 × 450 pt content plus a 32 pt title bar, 144 pt
  icons at (172, 249) and (528, 249), 248-pt cards from y 134, arrow at y 258). The
  bottom 52 pt is reserved for Finder's Path Bar and Status Bar; the card stroke ends
  at y 383, leaving 15 pt before that reserve. This is a geometry check, not a new
  Finder rendering result.
- `make_backgrounds.py`: draws the background as SVG and renders 1x + @2x PNGs
  (`pip install cairosvg`). The PNGs are committed, so CI needs no renderer or fonts;
  `--check` only asserts the geometry and centring (standard library, run by the
  Release workflow): icons level and centred about W/2, selection and label margins
  inside the card, the arrow clear of the cards with
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
- Arrow: dots lengthen into capsules while their gaps narrow, meeting an open rounded
  head. Nine Oklab colour stops smooth #7579ff → #0d967b. The default
  (`--arrow-variant accepted`) keeps y 258 and a 2.6-pt stroke, with 15.2 pt of ink
  clearance to each card. Explicit `open` and `filled` options preserve the earlier
  unselected finishing studies; neither is the production default.
- Background: a short pure-white plateau at the top joins a white top bar, then
  fades into the existing light gradient. Static preview pixels are checked at 1x/2x;
  a real Finder window remains unverified in this headless-only pass.
- Padding in the cards: the icon centre is 115 pt below the card top. Its estimated
  selection envelope starts 35 pt below the top, the label ends 35 pt above the
  bottom, and the selection envelope leaves 44 pt on either side. Actual Finder
  label placement with 144-pt icons remains unverified. krado's icon art
  fills its square on macOS 15 and has a margin on macOS 26, so on 15 the space above it
  is about 7 pt smaller; Applications' folder art has empty space on top on both.
- The colours are part of the image: Finder shows a static picture, so the window
  cannot follow the user's accent colour or Dark Mode. With a background picture Finder
  draws icon labels in black, which the light background keeps readable.
- Finder ignores the DMG for some settings: View > Show Path Bar / Show Status Bar and
  "Show all filename extensions" are the user's global preferences. Look at the `bars`
  screenshots of the render job before publishing.

## Generate assets without opening Finder

Generate the production background with an already available SVG renderer:

```sh
python3 packaging/dmg/make_backgrounds.py --svg-only
node packaging/dmg/render-backgrounds.cjs packaging/dmg/B
python3 packaging/dmg/make_backgrounds.py --check
```

The production SVG and both PNG scales are committed in `B/`.

To reproduce the historical finishing studies, use `--output-dir` to keep them
separate from production. `--svg-only` writes vector sources without
importing CairoSVG, for an SVG renderer already available on the build machine:

```sh
python3 packaging/dmg/make_backgrounds.py --arrow-variant open --svg-only --output-dir /tmp/krado-study-open
python3 packaging/dmg/make_backgrounds.py --arrow-variant filled --svg-only --output-dir /tmp/krado-study-filled
node packaging/dmg/render-backgrounds.cjs /tmp/krado-study-open /tmp/krado-study-filled
```

The render command uses an already available `sharp` installation (normal Node module
resolution, including `NODE_PATH`). The committed images were rendered with sharp 0.35.5 / libvips 8.18.7 /
librsvg 2.63.2 to generate the committed PNGs and both previews from those SVGs.
CairoSVG's default PNG path remains available; rasterizer/font differences can
change antialiasing, so compare SVG geometry and pixels from the same renderer.

Render each SVG at 700 × 466 and 1400 × 932 px (450 pt content + 16 pt bottom bleed).
The bottom bleed adds height only.

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
