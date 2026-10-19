# DMG window

The window that opens with `krado-<version>.dmg` (style B: krado's zones, the app
in one cell, Applications glowing as the mint snap target).

- `layout.json`: shared geometry (660 × 432 pt content plus a 32 pt title bar, 128 pt
  icons, icon centres, the label band, and the bottom 56 pt kept free of art).
- `make_backgrounds.py`: draws the background as SVG and renders 1x + @2x PNGs
  (`pip install cairosvg`). The PNGs are committed, so CI needs no renderer or fonts;
  `--check` only asserts the geometry below (standard library, run by the Release workflow).
- `settings.py`: the dmgbuild layout. `scripts/make-dmg.sh` uses it by default
  (`DMG_STYLE=B`); `DMG_STYLE=plain` builds the old plain window.
- `requirements.txt`: dmgbuild and its two dependencies, pinned with hashes. Installed
  into `.build/dmgbuild-venv` on the build machine only; nothing is installed for users.
- The colours are part of the image: Finder shows a static picture, so the window
  cannot follow the user's accent colour. With a background picture Finder always
  draws icon labels in black, so each card ends in a wide light band the label sits on.
- Finder ignores the DMG for some settings: View > Show Path Bar / Show Status Bar and
  "Show all filename extensions" are the user's global preferences, and the label
  position and title bar height change between macOS versions (v0.1.0's window, sized
  for a 28 pt title bar with label-sized chips, was cut off with a scroll bar). So the
  design keeps the bottom 56 pt free of art, keeps the items far enough up that no
  scroll bar appears with both bars on, and uses a band instead of a label-sized chip.
- `render/render-dmg.sh` (CI runner only, never on a personal Mac): opens a DMG in
  Finder and screenshots the real window with default preferences and with both bars
  and extensions on. The Release workflow's `render` job runs it on macos-15 and
  macos-26 for every DMG it builds (artifacts `render-<os>`); a draft release is only
  created after it passes. Look at the PNGs before publishing.
