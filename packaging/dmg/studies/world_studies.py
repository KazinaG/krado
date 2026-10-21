#!/usr/bin/env python3
"""Two unselected composition studies. Writes SVGs; never changes shipping assets.

Render with the existing ../render-backgrounds.cjs, then compose static previews.
No application, Finder, DMG, installation or system settings are involved.
"""
import argparse
from copy import deepcopy
from pathlib import Path
import runpy

DMG = Path(__file__).resolve().parents[1]
BASE = runpy.run_path(str(DMG / "make_backgrounds.py"))
# These historical composition studies used 160-pt icons. Keep that comparison
# independent of the current production size (now 144 pt), while BASE's checker
# continues to validate the actual shipping layout and dmgbuild settings.
L = deepcopy(BASE["L"])
L["icon_size"] = 160
W, H, HI = BASE["W"], BASE["H"], BASE["HI"]
AX, AY, BX = BASE["AX"], BASE["AY"], BASE["BX"]
C = L["card"]


def background(study, corner_guides=True, arrow_art=None):
    assert study in ("A", "B")
    quiet = study == "A"
    bottom = "#f2f5f8" if quiet else "#eaf1f6"
    defs = f'''<linearGradient id="bg" x2="0" y2="1"><stop stop-color="#fff"/><stop offset=".06" stop-color="#fff"/><stop offset="1" stop-color="{bottom}"/></linearGradient>
    <linearGradient id="word"><stop stop-color="#3f4296"/><stop offset="1" stop-color="#136f7d"/></linearGradient>
    <linearGradient id="dash" x1="{BASE['X0']}" x2="{BASE['X1']}" gradientUnits="userSpaceOnUse"><stop stop-color="{L['arrow']['from']}"/><stop offset="1" stop-color="{L['arrow']['to']}"/></linearGradient>'''
    art = f'<rect width="{W}" height="{HI}" fill="url(#bg)"/>'
    if not quiet:
        defs += f'<radialGradient id="landing" cx="{BX}" cy="{AY}" r="190" gradientUnits="userSpaceOnUse"><stop stop-color="#2ab8a0" stop-opacity=".10"/><stop offset="1" stop-color="#2ab8a0" stop-opacity="0"/></radialGradient>'
        art += f'<rect width="{W}" height="{HI}" fill="url(#landing)"/>'
    for i, x in enumerate((AX, BX)):
        shape = f'x="{x-C["size"]/2}" y="{C["top"]}" width="{C["size"]}" height="{C["size"]}" rx="{C["radius"]}"'
        if quiet:
            fill, opacity, stroke, width = "#fff", .78, ("#cbd4df" if i == 0 else "#4d918a"), (1 if i == 0 else 1.35)
        else:
            fill, opacity, stroke, width = ("#fff", .76, "#cbd4df", 1) if i == 0 else ("#e7f7f2", .94, "#178678", 1.7)
        art += f'<rect {shape} fill="{fill}" fill-opacity="{opacity}" stroke="{stroke}" stroke-width="{width}"/>'
    if not quiet and corner_guides:
        # Quiet corner guides repeat the real app's highlighted target-zone language.
        # They sit outside the Finder icon/label envelope and imply no extra action.
        left, right = BX-C["size"]/2+16, BX+C["size"]/2-16
        top, bottom = C["top"]+16, C["top"]+C["size"]-16
        for x, sx in ((left, 1), (right, -1)):
            for y, sy in ((top, 1), (bottom, -1)):
                art += f'<path d="M {x} {y+18*sy} V {y} H {x+18*sx}" fill="none" stroke="#3aa99d" stroke-opacity=".68" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    baseline = L["word_ink_top"]+L["word_ink_to_baseline"]
    word_fill = "#2d4359" if quiet else "url(#word)"
    art += f'<text x="{W/2}" y="{baseline}" text-anchor="middle" font-family="{BASE["FONT"]}" font-size="{L["word_size"]}" font-weight="700" letter-spacing="-.6" fill="{word_fill}">krado</text>'
    art += f'<text x="{W/2}" y="{baseline+L["subtitle_below_word"]}" text-anchor="middle" font-family="{BASE["FONT"]}" font-size="{L["subtitle_size"]}" fill="#616e83">Drag krado to Applications</text>'
    # Both whole-screen studies share the same open, straight, rounded arrow.
    art += BASE["arrow_art"]("open") if arrow_art is None else arrow_art
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{HI}" viewBox="0 0 {W} {HI}"><defs>{defs}</defs>{art}</svg>'


def check():
    BASE["check_geometry"]()
    assert (W, H, L["icon_size"], C["size"], BASE["ARROW_Y"]) == (700, 450, 160, 248, 258)
    # The widest new card stroke is smaller than the existing 2-pt envelope.
    assert C["top"]+C["size"]+1+12 <= H-L["bars_reserve"]
    for study in ("A", "B"):
        svg = background(study)
        assert "Drag krado to Applications" in svg and 'stop-color="#fff"' in svg
    print("World-study geometry OK; historical 160-pt icons and current production geometry checked")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    check()
    if args.check:
        return
    if args.output_dir is None:
        parser.error("--output-dir is required")
    for study in ("A", "B"):
        out = args.output_dir/study
        out.mkdir(parents=True, exist_ok=True)
        (out/"background.svg").write_text(background(study))
    print(f"A/B SVGs: {args.output_dir}")


if __name__ == "__main__":
    main()
