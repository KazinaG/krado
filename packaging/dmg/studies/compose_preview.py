#!/usr/bin/env python3
"""Headless static previews from existing icons and study PNGs (requires Pillow)."""
import argparse
from pathlib import Path
import runpy
from PIL import Image, ImageDraw, ImageFont

DMG = Path(__file__).resolve().parents[1]
REPO = DMG.parents[1]
L = runpy.run_path(str(DMG / "make_backgrounds.py"))["L"]
FONT = "/System/Library/Fonts/HelveticaNeue.ttc"
JP = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def font(size, jp=False):
    return ImageFont.truetype(JP if jp else FONT, size)


def compose(out, applications_icon):
    app = Image.open(REPO / "docs/assets/AppIcon.iconset/icon_256x256@2x.png").convert("RGBA")
    applications = Image.open(applications_icon).convert("RGBA")
    sheet = Image.new("RGB", (1480, 665), "#f2f4f7")
    d = ImageDraw.Draw(sheet)
    d.text((28, 17), "krado の世界観 / 全体デザイン比較", font=font(26, True), fill="#263b50")
    descriptions = {
        "A": ("静かに収まる", "白い場と揃った余白。Mac の道具として、静かに整う。"),
        "B": ("置き先が見える", "薄いマスから、はっきりした着地点へ。置く行為を伝える。"),
    }
    for i, study in enumerate(("A", "B")):
        x = 28 + i * 724
        title, description = descriptions[study]
        d.text((x, 70), f"{study}  {title}", font=font(22, True), fill="#263b50")
        assert d.textbbox((0, 0), description, font=font(14, True))[2] < 700
        d.text((x, 104), description, font=font(14, True), fill="#55667b")
        scale = 2
        bg = Image.open(out / study / "background@2x.png").convert("RGBA").crop((0, 0, 1400, 900))
        bd = ImageDraw.Draw(bg)
        for icon, pos, label in ((app, L["app"], "krado"), (applications, L["applications"], "Applications")):
            resized = icon.resize((320, 320), Image.Resampling.LANCZOS)
            bg.alpha_composite(resized, ((pos[0] - 80) * scale, (pos[1] - 80) * scale))
            bd.text((pos[0] * scale, (pos[1] + 88) * scale), label, font=font(26), anchor="mt", fill="#202124")
        window = Image.new("RGBA", (1400, 964), "white")
        window.alpha_composite(bg, (0, 64))
        wd = ImageDraw.Draw(window)
        wd.text((700, 32), "krado", font=font(24), anchor="mm", fill="#656e7a")
        for cx, color in ((17, "#ff6058"), (35, "#ffbd2e"), (53, "#28c840")):
            wd.ellipse(((cx - 5) * scale, 22, (cx + 5) * scale, 42), fill=color)
        window.convert("RGB").save(out / f"krado-world-{study}@2x.png")
        native = window.convert("RGB").resize((700, 482), Image.Resampling.LANCZOS)
        native.save(out / f"krado-world-{study}.png")
        sheet.paste(native, (x, 142))
        d.rounded_rectangle((x - 1, 141, x + 700, 624), 8, outline="#cbd3df", width=1)
    d.text((28, 642), "既存のアイコンを重ねた静的プレビューです。Finder の実表示は未確認。両案とも未採用。", font=font(13, True), fill="#5a6b7e")
    sheet.save(out / "krado-world-AB.png")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output-dir", type=Path, required=True)
    p.add_argument("--applications-icon", type=Path, required=True)
    args = p.parse_args()
    compose(args.output_dir, args.applications_icon)
