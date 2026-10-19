#!/usr/bin/env python3
"""Renders the DMG window background (style B) as SVG -> PNG (1x + @2x).

Run on any machine with cairosvg (the committed PNGs are what CI uses, so the
release runner needs no SVG renderer or fonts):
    python3 packaging/dmg/make_backgrounds.py
Geometry is shared with packaging/dmg/settings.py via layout.json.
"""
import json
import pathlib

import cairosvg

HERE = pathlib.Path(__file__).resolve().parent
L = json.loads((HERE / "layout.json").read_text())
W, H = L["window"]["width"], L["window"]["height"]
(AX, AY), (BX, BY) = L["app"], L["applications"]
ICON = L["icon_size"]

FONT = "Inter Tight, Inter, Helvetica Neue, sans-serif"


def label_chip(cx, cy, w, fill, opacity):
    # With a background picture Finder always draws icon labels in black (Light and
    # Dark mode alike), and .DS_Store cannot change that. On a dark design a light
    # chip under each label keeps it readable.
    return (f'<rect x="{cx - w / 2}" y="{cy - 12}" width="{w}" height="24" rx="12" '
            f'fill="{fill}" fill-opacity="{opacity}"/>')


def style_b():
    # krado's own overlay as the motif: the window is split into two zones like a
    # 2 x 1 grid; the app rests in one, Applications glows as the snap target.
    m, g, top = 22, 14, 126
    zw = (W - 2 * m - g) / 2
    zl, zr = m, m + zw + g
    zh = H - top - m
    x0, x1 = zl + zw - 34, zr + 26
    ly = AY + 76
    dots = "".join(
        f'<circle cx="{x}" cy="{y}" r="1" fill="#ffffff" fill-opacity="0.07"/>'
        for x in range(18, W, 24) for y in range(18, H, 24))
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
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
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  {dots}
  <rect width="{W}" height="{H}" fill="url(#glowL)"/>
  <rect width="{W}" height="{H}" fill="url(#glow)"/>
  <rect x="{zl}" y="{top}" width="{zw}" height="{zh}" rx="20" fill="url(#glass)" stroke="#ffffff" stroke-opacity="0.18"/>
  <rect x="{zr}" y="{top}" width="{zw}" height="{zh}" rx="20" fill="#66f2d6" fill-opacity="0.13"
        stroke="#66f2d6" stroke-opacity="0.9" stroke-width="2"/>
  {label_chip(AX, ly, 84, "#d7deec", 0.92)}{label_chip(BX, ly, 112, "#c2f5e9", 0.95)}
  <text x="{W/2}" y="70" text-anchor="middle" font-family="{FONT}" font-size="34" font-weight="700"
        letter-spacing="-0.6" fill="#f3f6ff">krado</text>
  <text x="{W/2}" y="96" text-anchor="middle" font-family="{FONT}" font-size="13" font-weight="500"
        letter-spacing="0.2" fill="#a4b4d4">Drop it into place</text>
  <path d="M {x0} {AY} L {x1} {AY}" fill="none" stroke="url(#dash)" stroke-width="2.6" stroke-linecap="round"
        stroke-dasharray="1 8"/>
  <path d="M {x1 - 9} {AY - 8} L {x1 + 1} {AY} L {x1 - 9} {AY + 8}" fill="none" stroke="#66f2d6"
        stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>"""


def main():
    for name, svg in (("B", style_b()),):
        out = HERE / name
        out.mkdir(exist_ok=True)
        (out / "background.svg").write_text(svg)
        cairosvg.svg2png(bytestring=svg.encode(), write_to=str(out / "background.png"), output_width=W, output_height=H)
        cairosvg.svg2png(bytestring=svg.encode(), write_to=str(out / "background@2x.png"),
                         output_width=W * 2, output_height=H * 2)
        print(f"{name}: {out}/background.png, background@2x.png ({W}x{H} pt)")


if __name__ == "__main__":
    main()
