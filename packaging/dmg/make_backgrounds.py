#!/usr/bin/env python3
"""Renders the DMG window background (style B) as SVG -> PNG (1x + @2x).

Run on any machine with cairosvg (the committed PNGs are what CI uses, so the
release runner needs no SVG renderer or fonts):
    python3 packaging/dmg/make_backgrounds.py
    python3 packaging/dmg/make_backgrounds.py --check   # geometry only (CI)
Geometry is shared with packaging/dmg/settings.py via layout.json.

Design (round 7 B): modelled on real DMGs shot in Finder at 2x (Ghostty, ChatGPT; Arc
for the cards). Wordmark and caption on top, two square cards with 160-pt icons, and
0.1.0's dotted arrow centred between the cards at icon height. The whole composition
sits about 2.5 % above the centre of Finder's content area (optical centre).
"""
import json
import pathlib
import runpy
import sys

HERE = pathlib.Path(__file__).resolve().parent
L = json.loads((HERE / "layout.json").read_text())
W, H = L["window"]["width"], L["window"]["height"]
(AX, AY), (BX, BY) = L["app"], L["applications"]
ICON = L["icon_size"]
CARD = L["card"]
A = L["arrow"]
MID = (AX + BX) / 2
# Arrow variants (0.1.6 A/B, Kazina 2026-10-20 19:51):
#   "card":  0.1.0's 74-pt arrow, centred between the cards, at the cards' vertical middle.
#   "icons": the arrow ignores the cards and runs from just right of the krado icon art to
#            just left of the Applications icon art, at icon height.
ARROW_MODE = A.get("mode", "icon")
ART_HALF = ICON / 2 - ICON * 0.1  # macOS icon art leaves ~10 % transparent margin per side
if ARROW_MODE == "icons":
    X0, X1 = AX + ART_HALF + A["icon_gap"], BX - ART_HALF - A["icon_gap"] - 1
else:
    X0, X1 = MID + A["dx"][0], MID + A["dx"][1]
ARROW_Y = L["card"]["top"] + L["card"]["size"] / 2 if ARROW_MODE == "card" else AY
# The PNG is taller than the window content so a slightly shorter title bar on another
# macOS version (28 pt on macOS 15) shows more of the same gradient, never an empty strip.
HI = H + L["bleed"]
FONT = "Inter Tight, Inter, Helvetica Neue, sans-serif"


def check_geometry():
    half, size, top = ICON / 2, CARD["size"], CARD["top"]
    assert AY == BY and AX + BX == W, "icons level and centred about W/2"
    if ARROW_MODE != "icons":
        assert X1 - X0 == 74, "0.1.0's arrow length"
    # Arrow ink: the round cap adds width/2 on the left, the chevron tip sits 1 pt past
    # the line end plus width/2.
    ink0, ink1 = X0 - A["width"] / 2, X1 + 1 + A["width"] / 2
    left_gap, right_gap = ink0 - (AX + size / 2), (BX - size / 2) - ink1
    if ARROW_MODE != "icons":
        assert left_gap >= 8 and right_gap >= 8, "arrow clear of the cards"
    assert abs(left_gap - right_gap) < 1e-9, "arrow ink centred between the icons/cards"
    assert size - ICON == 64, "32-pt side padding around the icon"
    # Label measured in Finder at 2x (macOS 15 and 26): down to about icon centre + 106.
    label_bottom = AY + half + 26
    assert top + 8 <= AY - half and label_bottom + 12 <= top + size, "icon and label inside the card"
    sub_bottom = L["word_ink_top"] + L["word_ink_to_baseline"] + L["subtitle_below_word"] + 2
    assert top - sub_bottom >= 28, "air between the caption and the cards"
    # Optical centre: the composition (wordmark top .. card bottom) sits 1.5-3.5 % above
    # the centre of the content area.
    above, below = L["word_ink_top"], H - (top + size)
    assert 0.015 * H <= (below - above) / 2 <= 0.035 * H, (above, below)
    assert label_bottom + 36 <= H, "no scroll bar in Finder's default look"
    for reserve in (0, L["bars_reserve"]):
        assert top + size + 1 + 12 <= H - reserve, "card stroke has bottom air with either bar state"
    settings = runpy.run_path(str(HERE / "settings.py"), init_globals={"defines": {
        "app": "/Applications/krado.app", "style": "B", "dmgdir": str(HERE), "volume_icon": "unused.icns"}})
    assert settings["icon_locations"] == {"krado.app": (AX, AY), "Applications": (BX, BY)}
    for x in (AX, BX):
        left = x - size / 2
        for scale in (1, 2):
            assert (left + size / 2) * scale == x * scale, "card and Finder label share an exact centre"
            assert left * scale == round(left * scale), "no fractional pixel shift"
    # Conservative one-em-per-character label envelope, including extensions.
    for label in ("krado.app", "Applications"):
        label_width = len(label) * L["text_size"]
        assert (size - label_width) / 2 >= 32, "centred filename has equal side padding"
    assert settings["window_rect"][1] == (W, H + L["titlebar"])
    assert HI == H + L["bleed"], "bleed adds height only"


def style_b():
    defs = f'''<linearGradient id="bg" x2="0" y2="1"><stop stop-color="#fbfbfe"/><stop offset="1" stop-color="#e9edf6"/></linearGradient>
    <linearGradient id="word"><stop stop-color="#3f4296"/><stop offset="1" stop-color="#136f7d"/></linearGradient>
    <linearGradient id="dash" x1="{X0}" y1="0" x2="{X1}" y2="0" gradientUnits="userSpaceOnUse"><stop stop-color="{A["from"]}"/><stop offset="1" stop-color="{A["to"]}"/></linearGradient>'''
    art = f'<rect width="{W}" height="{HI}" fill="url(#bg)"/>'
    for i, ((x, cy), hue, opacity) in enumerate(zip((L["app"], L["applications"]), ("#6d6fd8", "#1fb5a8"), (.16, .14))):
        defs += f'<radialGradient id="a{i}" cx="{x}" cy="{cy}" r="{L["aura_radius"]}" gradientUnits="userSpaceOnUse"><stop stop-color="{hue}" stop-opacity="{opacity}"/><stop offset="1" stop-color="{hue}" stop-opacity="0"/></radialGradient>'
        art += f'<rect width="{W}" height="{HI}" fill="url(#a{i})"/>'
    for i, x in enumerate((AX, BX)):
        shape = f'x="{x - CARD["size"]/2}" y="{CARD["top"]}" width="{CARD["size"]}" height="{CARD["size"]}" rx="{CARD["radius"]}"'
        art += f'<rect {shape} fill="#ffffff" fill-opacity="0.55"/>'
        if i:
            art += f'<rect {shape} fill="#1fb5a8" fill-opacity="0.08"/>'
        stroke, opacity, sw = ("#1fb5a8", .9, 2) if i else ("#c6cfdf", 1, 1)
        art += f'<rect {shape} fill="none" stroke="{stroke}" stroke-opacity="{opacity}" stroke-width="{sw}"/>'
    base = L["word_ink_top"] + L["word_ink_to_baseline"]
    cw, chh = A["chevron"]
    art += f'''<text x="{W/2}" y="{base}" text-anchor="middle" font-family="{FONT}" font-size="{L['word_size']}" font-weight="700" letter-spacing="-0.6" fill="url(#word)">krado</text>
    <text x="{W/2}" y="{base + L['subtitle_below_word']}" text-anchor="middle" font-family="{FONT}" font-size="{L['subtitle_size']}" fill="#6b7290">Drag krado to Applications</text>
    <path d="M {X0} {ARROW_Y} L {X1} {ARROW_Y}" fill="none" stroke="url(#dash)" stroke-width="{A['width']}" stroke-linecap="round" stroke-dasharray="{A['dasharray']}"/>
    <path d="M {X1 - cw} {ARROW_Y - chh} L {X1 + 1} {ARROW_Y} L {X1 - cw} {ARROW_Y + chh}" fill="none" stroke="{A['to']}" stroke-width="{A['width']}" stroke-linecap="round" stroke-linejoin="round"/>'''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{HI}" viewBox="0 0 {W} {HI}"><defs>{defs}</defs>{art}</svg>'


def main():
    check_geometry()
    if "--check" in sys.argv:  # CI: geometry only, standard library only
        print("DMG geometry OK")
        return
    import cairosvg
    svg = style_b()
    out = HERE / "B"
    out.mkdir(exist_ok=True)
    (out / "background.svg").write_text(svg)
    for scale, suffix in ((1, ""), (2, "@2x")):
        cairosvg.svg2png(bytestring=svg.encode(), write_to=str(out / f"background{suffix}.png"),
                         output_width=W * scale, output_height=HI * scale)
    print(f"B: {out}/background.png, background@2x.png ({W}x{HI} pt, window content {W}x{H})")


if __name__ == "__main__":
    main()
