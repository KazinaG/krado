#!/usr/bin/env python3
"""B-based static follow-up: no corner guides, softer arrow, 160/144-pt comparison.

One background is shared by both icon sizes; shipping assets are never overwritten.
"""
import argparse
from pathlib import Path
import runpy

HERE = Path(__file__).resolve().parent
WORLD = runpy.run_path(str(HERE / "world_studies.py"))
BASE, L = WORLD["BASE"], WORLD["L"]
SEGMENTS = ((0, 0), (9, .4), (18.1, 1.2), (27.7, 2.4), (38.2, 4), (50, 6), (63.5, 11.5))


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


def colors():
    start, end = [to_lab(L['arrow'][key]) for key in ('from', 'to')]
    return [from_lab(tuple(a+(b-a)*i/8 for a, b in zip(start, end))) for i in range(9)]


def arrow():
    x0, x1, y = BASE['X0'], BASE['X1'], BASE['ARROW_Y']
    tip, width = x1+1, L['arrow']['width']
    stops = ''.join(f'<stop offset="{i/8}" stop-color="{color}"/>' for i, color in enumerate(colors()))
    art = f'<defs><linearGradient id="soft-dash" x1="{x0}" x2="{x1}" gradientUnits="userSpaceOnUse">{stops}</linearGradient></defs>'
    art += f'<g fill="none" stroke="url(#soft-dash)" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round">'
    for offset, length in SEGMENTS:
        x = x0+offset
        if length == 0:
            art += f'<circle cx="{x}" cy="{y}" r="{width/2}" fill="url(#soft-dash)" stroke="none"/>'
        else:
            art += f'<path d="M {x} {y} h {length}"/>'
    # The accepted open head is geometrically unchanged, including the 2.6-pt width.
    art += f'<path d="M {tip - 9.5} {y - 7.5} L {tip - 1.3} {y - 1.6} Q {tip + 1.3} {y} {tip - 1.3} {y + 1.6} L {tip - 9.5} {y + 7.5}"/>'
    return art+'</g>'


def background():
    return WORLD['background']('B', corner_guides=False, arrow_art=arrow())


def compose(out, applications_icon):
    from PIL import Image, ImageDraw
    preview = runpy.run_path(str(HERE/'compose_preview.py'))
    font = preview['font']
    app = Image.open(preview['REPO']/'docs/assets/AppIcon.iconset/icon_256x256@2x.png').convert('RGBA')
    applications = Image.open(applications_icon).convert('RGBA')
    background_image = Image.open(out/'background@2x.png').convert('RGBA').crop((0, 0, 1400, 900))
    sheet = Image.new('RGB', (1480, 850), '#f2f4f7')
    d = ImageDraw.Draw(sheet)
    d.text((28, 17), 'krado / B を土台にした調整', font=font(26, True), fill='#263b50')
    d.text((28, 54), '直角ガイドを外し、点から破線へのつながりと色移りを調整。中心・札・ラベル位置は共通。', font=font(14, True), fill='#55667b')
    for i, size in enumerate((160, 144)):
        x = 28+i*724
        title = '現行 160 pt' if size == 160 else '少し小さく 144 pt（10%縮小）'
        d.text((x, 98), title, font=font(22, True), fill='#263b50')
        bg = background_image.copy()
        for icon, pos, label in ((app, L['app'], 'krado'), (applications, L['applications'], 'Applications')):
            resized = icon.resize((size*2, size*2), Image.Resampling.LANCZOS)
            bg.alpha_composite(resized, (pos[0]*2-size, pos[1]*2-size))
            ImageDraw.Draw(bg).text((pos[0]*2, (pos[1]+88)*2), label, font=font(26), anchor='mt', fill='#202124')
        window = Image.new('RGBA', (1400, 964), 'white')
        window.alpha_composite(bg, (0, 64))
        wd = ImageDraw.Draw(window)
        wd.text((700, 32), 'krado', font=font(24), anchor='mm', fill='#656e7a')
        for cx, color in ((17, '#ff6058'), (35, '#ffbd2e'), (53, '#28c840')):
            wd.ellipse(((cx-5)*2, 22, (cx+5)*2, 42), fill=color)
        window.convert('RGB').save(out/f'krado-B-{size}@2x.png')
        native = window.convert('RGB').resize((700, 482), Image.Resampling.LANCZOS)
        native.save(out/f'krado-B-{size}.png')
        sheet.paste(native, (x, 140))
        d.rounded_rectangle((x-1, 139, x+700, 622), 8, outline='#cbd3df', width=1)
    # A single shared detail avoids implying that arrows differ between the two sizes.
    detail = background_image.crop((610, 482, 790, 550)).convert('RGB').resize((360, 136), Image.Resampling.LANCZOS)
    d.text((28, 658), '矢印は両サイズ共通', font=font(17, True), fill='#263b50')
    d.text((28, 689), '先端の形と線幅を維持。拡大でつながりを確認。', font=font(14, True), fill='#55667b')
    sheet.paste(detail, (560, 648))
    d.text((28, 822), '静的なサイズ比較です。Finder 実表示は未確認。144 pt は比較用の提案で、まだ未選択です。', font=font(13, True), fill='#5a6b7e')
    sheet.save(out/'krado-B-icons-160-144.png')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--compose', action='store_true')
    p.add_argument('--applications-icon', type=Path)
    args = p.parse_args()
    if args.compose:
        if args.applications_icon is None:
            p.error('--compose needs --applications-icon')
        compose(args.output_dir, args.applications_icon)
    else:
        WORLD['check']()
        args.output_dir.mkdir(parents=True, exist_ok=True)
        (args.output_dir/'background.svg').write_text(background())
        print(f'B follow-up SVG: {args.output_dir}; arrow stops {colors()}')
