#!/usr/bin/env python3
"""Renders the DMG window background (style B) as SVG -> PNG (1x + @2x).

Run on any machine with cairosvg (the committed PNGs are what CI uses, so the
release runner needs no SVG renderer or fonts):
    python3 packaging/dmg/make_backgrounds.py
    python3 packaging/dmg/make_backgrounds.py --check   # geometry only (CI)
Geometry is shared with packaging/dmg/settings.py via layout.json.
"""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
L = json.loads((HERE / "layout.json").read_text())
W, H = L["window"]["width"], L["window"]["height"]
(AX, AY), (BX, BY) = L["app"], L["applications"]
ICON = L["icon_size"]
# Finder draws the label (and the user's "Show all filename extensions") wherever its
# macOS version puts it, and View > Show Path Bar / Show Status Bar are global Finder
# preferences that .DS_Store cannot switch off. So: no tight chips, a wide band
# under each icon instead, and nothing drawn in the bottom BARS_RESERVE pt.
BAND_TOP, BAND_BOTTOM = AY + L["label_band"][0], AY + L["label_band"][1]
CARD_BOTTOM = BAND_BOTTOM
BARS_RESERVE, SCROLL_MARGIN = L["bars_reserve"], L["scroll_margin"]
# The PNG is taller than the window content so a slightly shorter title bar on another
# macOS version shows more of the same gradient, never an empty strip.
HI = H + L["bleed"]


def check_geometry():
    # Label measured on macOS 26 (v0.1.0 report): icon centre + 77 ... + 90 pt.
    label_bottom = AY + 90
    assert BAND_TOP <= AY + 77 - 8 and BAND_BOTTOM >= label_bottom + 12, "label band too tight"
    # With both bars on, the visible content is H - BARS_RESERVE. Finder shows a scroll
    # bar once the items (plus about 36 pt) reach past it.
    assert label_bottom + SCROLL_MARGIN <= H - BARS_RESERVE, "items reach under the bars"
    assert CARD_BOTTOM <= H - BARS_RESERVE - 8, "art reaches under the bars"

FONT = "Inter Tight, Inter, Helvetica Neue, sans-serif"


def card(cid, x, top, w, rx, body, band_fill, band_opacity, stroke):
    # A card whose bottom part is a light label band, clipped to the card's rounded
    # corners. With a background picture Finder always draws icon labels in black
    # (Light and Dark mode alike), and .DS_Store cannot change that; the band is as
    # wide as the card and about 3 label heights tall, so the label stays on it
    # wherever Finder puts it.
    h = CARD_BOTTOM - top
    band = ""
    if band_fill:
        band = (f'<clipPath id="{cid}"><rect x="{x}" y="{top}" width="{w}" height="{h}" rx="{rx}"/></clipPath>'
                f'<rect x="{x}" y="{BAND_TOP}" width="{w}" height="{CARD_BOTTOM - BAND_TOP}" fill="{band_fill}" '
                f'fill-opacity="{band_opacity}" clip-path="url(#{cid})"/>')
    return (f'<rect x="{x}" y="{top}" width="{w}" height="{h}" rx="{rx}" {body}/>{band}'
            f'<rect x="{x}" y="{top}" width="{w}" height="{h}" rx="{rx}" fill="none" {stroke}/>')


def style_b():
    # krado's own overlay as the motif: the window is split into two zones like a
    # 2 x 1 grid; the app rests in one, Applications glows as the snap target.
    m, g, top = 22, 14, 120
    zw = (W - 2 * m - g) / 2
    zl, zr = m, m + zw + g
    x0, x1 = zl + zw - 34, zr + 26
    dots = "".join(
        f'<circle cx="{x}" cy="{y}" r="1" fill="#ffffff" fill-opacity="0.07"/>'
        for x in range(18, W, 24) for y in range(18, HI, 24))
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{HI}" viewBox="0 0 {W} {HI}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#1b1d4a"/><stop offset="0.55" stop-color="#14294d"/><stop offset="1" stop-color="#0a3b46"/>
    </linearGradient>
    <radialGradient id="glow" cx="{BX}" cy="{BY}" r="230" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#66f2d6" stop-opacity="0.34"/><stop offset="1" stop-color="#66f2d6" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowL" cx="{AX}" cy="{AY}" r="200" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#8183f5" stop-opacity="0.24"/><stop offset="1" stop-color="#8183f5" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="glass" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.12"/><stop offset="1" stop-color="#ffffff" stop-opacity="0.04"/>
    </linearGradient>
    <linearGradient id="dash" x1="{x0}" y1="0" x2="{x1}" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#b3b5ff"/><stop offset="1" stop-color="#66f2d6"/>
    </linearGradient>
  </defs>
  <rect width="{W}" height="{HI}" fill="url(#bg)"/>
  {dots}
  <rect width="{W}" height="{HI}" fill="url(#glowL)"/>
  <rect width="{W}" height="{HI}" fill="url(#glow)"/>
  {card("cl", zl, top, zw, 20, 'fill="url(#glass)"', "#d7deec", 0.92, 'stroke="#ffffff" stroke-opacity="0.18"')}
  {card("cr", zr, top, zw, 20, 'fill="#66f2d6" fill-opacity="0.13"', "#c2f5e9", 0.95,
        'stroke="#66f2d6" stroke-opacity="0.9" stroke-width="2"')}
  <text x="{W/2}" y="68" text-anchor="middle" font-family="{FONT}" font-size="34" font-weight="700"
        letter-spacing="-0.6" fill="#f3f6ff">krado</text>
  <text x="{W/2}" y="94" text-anchor="middle" font-family="{FONT}" font-size="13" font-weight="500"
        letter-spacing="0.2" fill="#a4b4d4">Drop it into place</text>
  <path d="M {x0} {AY} L {x1} {AY}" fill="none" stroke="url(#dash)" stroke-width="2.6" stroke-linecap="round"
        stroke-dasharray="1 8"/>
  <path d="M {x1 - 9} {AY - 8} L {x1 + 1} {AY} L {x1 - 9} {AY + 8}" fill="none" stroke="#66f2d6"
        stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>"""


def main():
    check_geometry()
    if "--check" in sys.argv:  # CI: geometry only, standard library only
        print("DMG geometry OK")
        return
    import cairosvg
    for name, svg in (("B", style_b()),):
        out = HERE / name
        out.mkdir(exist_ok=True)
        (out / "background.svg").write_text(svg)
        cairosvg.svg2png(bytestring=svg.encode(), write_to=str(out / "background.png"), output_width=W, output_height=HI)
        cairosvg.svg2png(bytestring=svg.encode(), write_to=str(out / "background@2x.png"),
                         output_width=W * 2, output_height=HI * 2)
        print(f"{name}: {out}/background.png, background@2x.png ({W}x{HI} pt, window content {W}x{H})")


if __name__ == "__main__":
    main()
