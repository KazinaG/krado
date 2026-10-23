# DMG composition studies

Selected direction: B without the extra corner guides, with the refined shared
static arrow and the right-hand 144-pt icons from the 160/144 comparison. These are
now reflected in `../layout.json` and `../B/background.*`. The original comparison
descriptions and 160-pt studies below are retained as history.

These follow the [canonical Notion request](https://app.notion.com/p/3fdd89d6d454816abcf8d6badc08fa7b).
The previous arrow studies were both unselected; A was only closer. The request is
to express intention and worldview, not a literal thread motif.

Grounding: README's “Drag a window. Drop it on the grid” and zero setup; the app's
light grid and stronger highlighted landing zone; its indigo/teal icon and native
macOS controls. No new brand story or feature is asserted.

- **A — 静かに収まる / Quiet fit:** one restrained white field, equal card proportions,
  aligned margins, a neutral wordmark and a quiet destination keyline. The order of
  the composition carries the idea of an unobtrusive Mac utility.
- **B — 置き先が見える / Clear landing:** a pale destination surface, a stronger edge
  and corner guides express the highlighted zone. The unchanged start-to-target
  alignment and shared straight arrow explain the act of placing something.

Both keep the light gradient, white top edge, square cards, central composition,
160-pt icons, straight rounded arrow and actual install instruction. They do not
restore the rejected background dot grid, add a label band, tilt the cards or add
illustrative mini-windows. The numbers stay 700×450 content, 248-pt cards and the
existing icon centres. This is a comparison of the whole composition, not of tips.

`world_studies.py` keeps its historical 160-pt geometry and writes separate SVG
studies; it does not change the shipping
`B/background.*`, `layout.json`, menu or motion. Use an already available renderer:

```sh
python3 packaging/dmg/studies/world_studies.py --output-dir /tmp/krado-world
node packaging/dmg/render-backgrounds.cjs /tmp/krado-world/A /tmp/krado-world/B
python3 packaging/dmg/studies/compose_preview.py --output-dir /tmp/krado-world --applications-icon /path/to/existing-applications-icon.png
```

The compositor uses an already available Pillow installation and macOS fonts.
The previews combine the real existing krado and Applications icons with each
background at the shared coordinates. They are static compositions. Finder, actual
selection rendering and global bars settings are not claimed to be verified.

## B follow-up and icon sizes

Kazina chose B as the base, retaining its wordmark gradient, white top, background,
frame and destination emphasis, while removing the extra right-angle corner guides.
`b_followup.py` writes that background separately and compares 160 pt with 144 pt
(a 10% reduction). Kazina adopted the right-hand 144-pt option and the shared arrow.
The production generator reproduces the selected background independently of these
study scripts; its SVG and both PNG scales match the selected reference bytes.

Both previews use the same background, icon centres, cards and label baseline to
isolate icon size. Actual Finder label placement is still unverified. The shared
arrow keeps the accepted head path and 2.6-pt stroke. Capsules grow progressively
and their gaps narrow; nine colour stops approximate [Oklab interpolation](https://bottosson.github.io/posts/oklab/)
between the existing endpoint colours. The wordmark gradient is unchanged.
“Both arrows” referred to correcting the shared arrow, not adding animation.

```sh
python3 packaging/dmg/studies/b_followup.py --output-dir /tmp/krado-B-followup
node packaging/dmg/render-backgrounds.cjs /tmp/krado-B-followup
python3 packaging/dmg/studies/b_followup.py --output-dir /tmp/krado-B-followup --compose --applications-icon /path/to/existing-applications-icon.png
```
