# DMG window

The window that opens with `krado-<version>.dmg` (style B: krado's zones, the app
in one cell, Applications glowing as the mint snap target).

- `layout.json`: shared geometry (660 × 420 pt content, 128 pt icons, icon centres).
- `make_backgrounds.py`: draws the background as SVG and renders 1x + @2x PNGs
  (`pip install cairosvg`). The PNGs are committed, so CI needs no renderer or fonts.
- `settings.py`: the dmgbuild layout. `scripts/make-dmg.sh` uses it by default
  (`DMG_STYLE=B`); `DMG_STYLE=plain` builds the old plain window.
- `requirements.txt`: dmgbuild and its two dependencies, pinned with hashes. Installed
  into `.build/dmgbuild-venv` on the build machine only; nothing is installed for users.
- The colours are part of the image: Finder shows a static picture, so the window
  cannot follow the user's accent colour. With a background picture Finder always
  draws icon labels in black, so each label sits on a light chip.
