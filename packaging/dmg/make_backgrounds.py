#!/usr/bin/env python3
"""Renders the DMG window background (style B) as SVG -> PNG (1x + @2x).

Run on any machine with cairosvg (the committed PNGs are what CI uses, so the
release runner needs no SVG renderer or fonts):
    python3 packaging/dmg/make_backgrounds.py
    python3 packaging/dmg/make_backgrounds.py --check   # geometry only (CI)
Geometry is shared with packaging/dmg/settings.py via layout.json.

Design: Kazina's selected B follow-up with 144-pt icons, no corner guides, and the
shared rounded arrow. Wordmark and caption sit above two square cards. The design
grew from real DMGs shot in Finder at 2x (Ghostty, ChatGPT; Arc for the cards).
The whole composition
sits about 2.5 % above the centre of Finder's content area (optical centre).
"""
import argparse
import json
import pathlib
import runpy

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
SEGMENTS = ((0, 0), (9, .4), (18.1, 1.2), (27.7, 2.4), (38.2, 4), (50, 6), (63.5, 11.5))


def check_geometry():
    half, size, top = ICON / 2, CARD["size"], CARD["top"]
    assert AY == BY and AX + BX == W, "icons level and centred about W/2"
    if ARROW_MODE != "icons":
        assert X1 - X0 == 74, "0.1.0's arrow length"
    # The adopted arrow and both historical studies keep trial A's ink envelope:
    # width/2 on the left,
    # and 1 pt plus width/2 past X1 on the right (curve + round cap, or filled tip).
    ink0, ink1 = X0 - A["width"] / 2, X1 + 1 + A["width"] / 2
    left_gap, right_gap = ink0 - (AX + size / 2), (BX - size / 2) - ink1
    if ARROW_MODE != "icons":
        assert left_gap >= 8 and right_gap >= 8, "arrow clear of the cards"
    assert abs(left_gap - right_gap) < 1e-9, "arrow ink centred between the icons/cards"
    # Finder's selection box is about icon + 8 pt per side; keep even air around it and
    # the label inside the card (Kazina 2026-10-20 19:53).
    sel_top, label_bottom_ = AY - half - 8, AY + half + 26
    m_top, m_bottom, m_side = sel_top - top, top + size - label_bottom_, (size - ICON - 16) / 2
    assert min(m_top, m_bottom, m_side) >= 20 and max(m_top, m_bottom, m_side) - min(m_top, m_bottom, m_side) <= 12, (m_top, m_bottom, m_side)
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
    assert settings["icon_size"] == ICON == 144, "adopted 144-pt Finder icons"
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


def arrow_art(variant="open"):
    """Two unselected finishing studies; both share A's original ink envelope.

    The dots lengthen into a stem, which meets the head. The tip is drawn with
    a curve rather than relying on the round join of an acute chevron.
    """
    assert variant in ("open", "filled")
    tip, y, r = X1 + 1, ARROW_Y, A["width"] / 2
    art = f'<g fill="none" stroke="url(#dash)" stroke-width="{A["width"]}" stroke-linecap="round" stroke-linejoin="round">'
    for offset, length in ((0, 0), (9, 0), (18, 0), (27, 0), (36, 0), (45, 1.5), (54.5, 4)):
        x = X0 + offset
        # A zero-length line can disappear in some SVG renderers; a circle is explicit.
        if length == 0:
            art += f'<circle cx="{x}" cy="{y}" r="{r}" fill="url(#dash)" stroke="none"/>'
        else:
            art += f'<path d="M {x} {y} h {length}"/>'
    art += f'<path d="M {X0 + 64} {y} H {tip}"/>'
    if variant == "open":
        # The quadratic reaches tip at its midpoint, with a vertical tangent.
        art += f'<path d="M {tip - 9.5} {y - 7.5} L {tip - 1.3} {y - 1.6} Q {tip + 1.3} {y} {tip - 1.3} {y + 1.6} L {tip - 9.5} {y + 7.5}"/>'
    else:
        # A softly filled head is the alternative; its outer tip has the same bound
        # as the open stroke's round cap. The stem overlaps it without a gap.
        art += f'<path d="M {tip - 8.8} {y - 7.2} Q {tip - 10} {y - 8.2} {tip - 10} {y - 6.4} L {tip - 10} {y + 6.4} Q {tip - 10} {y + 8.2} {tip - 8.8} {y + 7.2} L {tip + .3} {y + 1.6} Q {tip + 2.3} {y} {tip + .3} {y - 1.6} Z" fill="url(#dash)" stroke="none"/>'
    return art + '</g>'


def finishing_study_b(variant="open"):
    """Retain the earlier unselected arrow studies for explicit CLI requests."""
    # A short white plateau makes every pixel of the top row pure white at 1x/2x.
    defs = f'''<linearGradient id="bg" x2="0" y2="1"><stop stop-color="#ffffff"/><stop offset="0.02" stop-color="#ffffff"/><stop offset="1" stop-color="#e9edf6"/></linearGradient>
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
    art += f'''<text x="{W/2}" y="{base}" text-anchor="middle" font-family="{FONT}" font-size="{L['word_size']}" font-weight="700" letter-spacing="-0.6" fill="url(#word)">krado</text>
    <text x="{W/2}" y="{base + L['subtitle_below_word']}" text-anchor="middle" font-family="{FONT}" font-size="{L['subtitle_size']}" fill="#6b7290">Drag krado to Applications</text>'''
    art += arrow_art(variant)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{HI}" viewBox="0 0 {W} {HI}"><defs>{defs}</defs>{art}</svg>'


def to_lab(color):
    # Oklab's public-domain reference matrices, Björn Ottosson (2021 revision):
    # https://bottosson.github.io/posts/oklab/
    rgb = [int(color[i:i+2], 16)/255 for i in (1, 3, 5)]
    r, g, b = [c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in rgb]
    l = (.4122214708*r+.5363325363*g+.0514459929*b)**(1/3)
    m = (.2119034982*r+.6806995451*g+.1073969566*b)**(1/3)
    s = (.0883024619*r+.2817188376*g+.6299787005*b)**(1/3)
    return (.2104542553*l+.7936177850*m-.0040720468*s,
            1.9779984951*l-2.4285922050*m+.4505937099*s,
            .0259040371*l+.7827717662*m-.8086757660*s)


def from_lab(lab):
    L_, a, b = lab
    l = (L_+.3963377774*a+.2158037573*b)**3
    m = (L_-.1055613458*a-.0638541728*b)**3
    s = (L_-.0894841775*a-1.2914855480*b)**3
    linear = (4.0767416621*l-3.3077115913*m+.2309699292*s,
              -1.2684380046*l+2.6097574011*m-.3413193965*s,
              -.0041960863*l-.7034186147*m+1.7076147010*s)
    srgb = [12.92*c if c <= .0031308 else 1.055*c**(1/2.4)-.055 for c in linear]
    return '#'+''.join(f'{round(max(0, min(1, c))*255):02x}' for c in srgb)


def arrow_colors():
    start, end = [to_lab(A[key]) for key in ('from', 'to')]
    return [from_lab(tuple(a+(b-a)*i/8 for a, b in zip(start, end))) for i in range(9)]


def accepted_arrow_art():
    """The shared arrow selected with the B follow-up, matching that SVG exactly."""
    x0, x1, y = X0, X1, ARROW_Y
    tip, width = x1+1, A['width']
    stops = ''.join(f'<stop offset="{i/8}" stop-color="{color}"/>' for i, color in enumerate(arrow_colors()))
    art = f'<defs><linearGradient id="soft-dash" x1="{x0}" x2="{x1}" gradientUnits="userSpaceOnUse">{stops}</linearGradient></defs>'
    art += f'<g fill="none" stroke="url(#soft-dash)" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round">'
    for offset, length in SEGMENTS:
        x = x0+offset
        if length == 0:
            art += f'<circle cx="{x}" cy="{y}" r="{width/2}" fill="url(#soft-dash)" stroke="none"/>'
        else:
            art += f'<path d="M {x} {y} h {length}"/>'
    # Keep the selected open head's exact path and 2.6-pt stroke.
    art += f'<path d="M {tip - 9.5} {y - 7.5} L {tip - 1.3} {y - 1.6} Q {tip + 1.3} {y} {tip - 1.3} {y + 1.6} L {tip - 9.5} {y + 7.5}"/>'
    return art+'</g>'


def style_b(variant="accepted"):
    """Reproduce the selected B background without importing historical studies."""
    if variant != "accepted":
        return finishing_study_b(variant)
    defs = f'''<linearGradient id="bg" x2="0" y2="1"><stop stop-color="#fff"/><stop offset=".06" stop-color="#fff"/><stop offset="1" stop-color="#eaf1f6"/></linearGradient>
    <linearGradient id="word"><stop stop-color="#3f4296"/><stop offset="1" stop-color="#136f7d"/></linearGradient>
    <linearGradient id="dash" x1="{X0}" x2="{X1}" gradientUnits="userSpaceOnUse"><stop stop-color="{A['from']}"/><stop offset="1" stop-color="{A['to']}"/></linearGradient>'''
    art = f'<rect width="{W}" height="{HI}" fill="url(#bg)"/>'
    defs += f'<radialGradient id="landing" cx="{BX}" cy="{AY}" r="190" gradientUnits="userSpaceOnUse"><stop stop-color="#2ab8a0" stop-opacity=".10"/><stop offset="1" stop-color="#2ab8a0" stop-opacity="0"/></radialGradient>'
    art += f'<rect width="{W}" height="{HI}" fill="url(#landing)"/>'
    for i, x in enumerate((AX, BX)):
        shape = f'x="{x-CARD["size"]/2}" y="{CARD["top"]}" width="{CARD["size"]}" height="{CARD["size"]}" rx="{CARD["radius"]}"'
        fill, opacity, stroke, width = ("#fff", .76, "#cbd4df", 1) if i == 0 else ("#e7f7f2", .94, "#178678", 1.7)
        art += f'<rect {shape} fill="{fill}" fill-opacity="{opacity}" stroke="{stroke}" stroke-width="{width}"/>'
    baseline = L["word_ink_top"]+L["word_ink_to_baseline"]
    art += f'<text x="{W/2}" y="{baseline}" text-anchor="middle" font-family="{FONT}" font-size="{L["word_size"]}" font-weight="700" letter-spacing="-.6" fill="url(#word)">krado</text>'
    art += f'<text x="{W/2}" y="{baseline+L["subtitle_below_word"]}" text-anchor="middle" font-family="{FONT}" font-size="{L["subtitle_size"]}" fill="#616e83">Drag krado to Applications</text>'
    art += accepted_arrow_art()
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{HI}" viewBox="0 0 {W} {HI}"><defs>{defs}</defs>{art}</svg>'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="check shared geometry without a renderer")
    parser.add_argument("--arrow-variant", choices=("accepted", "open", "filled"), default="accepted", help="selected B follow-up by default; open/filled retain historical studies")
    parser.add_argument("--output-dir", type=pathlib.Path, default=HERE / "B")
    parser.add_argument("--svg-only", action="store_true", help="write SVG for an already available renderer")
    args = parser.parse_args()
    check_geometry()
    if args.check:  # CI: geometry only, standard library only
        print("DMG geometry OK")
        return
    svg = style_b(args.arrow_variant)
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)
    (out / "background.svg").write_text(svg)
    if args.svg_only:
        print(f"{args.arrow_variant}: {out}/background.svg")
        return
    import cairosvg
    for scale, suffix in ((1, ""), (2, "@2x")):
        cairosvg.svg2png(bytestring=svg.encode(), write_to=str(out / f"background{suffix}.png"),
                         output_width=W * scale, output_height=HI * scale)
    print(f"B: {out}/background.png, background@2x.png ({W}x{HI} pt, window content {W}x{H})")


if __name__ == "__main__":
    main()
