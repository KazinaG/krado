"""Animated illustrations for the README (drawn, not screen recordings).
Run from the repository root: python3 scripts/readme-art/scenes.py  (needs Pillow, ffmpeg, Inter and DejaVu fonts)."""
import math, os, subprocess, shutil, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 2                      # supersampling
W, H = 720, 450            # output size
FPS = 25
OUT = os.environ.get("OUT", "docs/assets/demo")
BG0, BG1 = (16, 26, 48), (14, 52, 64)
BEZEL = (78, 96, 120)
SCREEN = (28, 38, 58)
CELL = (236, 238, 242)
MINT = (94, 242, 214)
WIN = (250, 250, 252)
WIN_BAR = (232, 234, 238)
INTER = "/usr/share/fonts/truetype/sand-box/google/Inter/Inter-VariableFont_opsz,wght.ttf"
SYM = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

def font(path, size, weight=None):
    f = ImageFont.truetype(path, size * S)
    if weight and path == INTER:
        try: f.set_variation_by_axes([14, weight])
        except Exception: pass
    return f

def ease(t):  # easeInOutCubic
    t = max(0.0, min(1.0, t))
    return 4 * t * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2

def ease_out(t):
    t = max(0.0, min(1.0, t)); return 1 - (1 - t) ** 3

def lerp(a, b, t): return a + (b - a) * t
def lerp_rect(a, b, t): return tuple(lerp(x, y, t) for x, y in zip(a, b))
def mix(c1, c2, t): return tuple(int(lerp(a, b, t)) for a, b in zip(c1, c2))

def background():
    img = Image.new("RGB", (W * S, H * S))
    d = ImageDraw.Draw(img)
    for y in range(H * S):
        d.line([(0, y), (W * S, y)], fill=mix(BG0, BG1, y / (H * S)))
    return img

# Display: a rounded monitor centred, grid inside.
SX, SY, SW, SH = 110, 30, 500, 300       # screen interior (output px)
PAD = 7
def grid_rect(cols, rows, c0, r0, c1, r1):
    """Union rect of cells [c0,c1) x [r0,r1)."""
    cw = (SW - PAD * (cols + 1)) / cols; ch = (SH - PAD * (rows + 1)) / rows
    x0 = SX + PAD + c0 * (cw + PAD); y0 = SY + PAD + r0 * (ch + PAD)
    x1 = SX + PAD + c1 * (cw + PAD) - PAD; y1 = SY + PAD + r1 * (ch + PAD) - PAD
    return (x0, y0, x1, y1)

def rr(d, rect, r, fill, outline=None, width=0):
    d.rounded_rectangle([v * S for v in rect], radius=r * S, fill=fill, outline=outline, width=width * S)

def draw_monitor(img):
    d = ImageDraw.Draw(img)
    rr(d, (SX - 12, SY - 12, SX + SW + 12, SY + SH + 12), 16, BEZEL)
    rr(d, (SX, SY, SX + SW, SY + SH), 8, SCREEN)
    cx = SX + SW / 2
    d.rectangle([(cx - 22) * S, (SY + SH + 12) * S, (cx + 22) * S, (SY + SH + 40) * S], fill=BEZEL)
    rr(d, (cx - 70, SY + SH + 38, cx + 70, SY + SH + 48), 5, BEZEL)

def draw_grid(img, cols, rows, alpha, highlight=None, hl_alpha=1.0):
    if alpha <= 0: return
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a = int(255 * alpha)
    for c in range(cols):
        for r in range(rows):
            rr(d, grid_rect(cols, rows, c, r, c + 1, r + 1), 7, CELL + (int(a * 0.22),), outline=CELL + (int(a * 0.55),), width=1)
    if highlight:
        rr(d, highlight, 8, MINT + (int(a * 0.55 * hl_alpha),), outline=MINT + (int(a * hl_alpha),), width=2)
    img.paste(layer, (0, 0), layer)

def shadow(img, rect, r):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = rect
    rr(d, (x0, y0 + 6, x1, y1 + 8), r, (0, 0, 0, 110))
    layer = layer.filter(ImageFilter.GaussianBlur(10 * S))
    img.paste(layer, (0, 0), layer)

def draw_window(img, rect, focused=True):
    x0, y0, x1, y1 = rect
    shadow(img, rect, 9)
    d = ImageDraw.Draw(img)
    rr(d, rect, 9, WIN)
    bar = min(22, (y1 - y0) * 0.3)
    d.rounded_rectangle([x0 * S, y0 * S, x1 * S, (y0 + bar) * S], radius=9 * S, fill=WIN_BAR, corners=(True, True, False, False))
    for i, col in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)] if focused else [(200, 200, 205)] * 3):
        cx, cy, rad = x0 + 13 + i * 15, y0 + bar / 2, 4.5
        d.ellipse([(cx - rad) * S, (cy - rad) * S, (cx + rad) * S, (cy + rad) * S], fill=col)
    # content lines
    lx = x0 + 14
    for i, frac in enumerate([0.55, 0.8, 0.7, 0.4]):
        ly = y0 + bar + 14 + i * 14
        if ly + 6 > y1 - 8: break
        rr(d, (lx, ly, lx + (x1 - x0 - 28) * frac, ly + 6), 3, (214, 218, 226))

def draw_cursor(img, x, y, pressed=False):
    pts = [(0, 0), (0, 17), (4.2, 13.2), (7.2, 20), (10, 18.8), (7.1, 12.3), (12.6, 12.3)]
    sc = 0.92 if pressed else 1.0
    d = ImageDraw.Draw(img)
    poly = [((x + px * sc) * S, (y + py * sc) * S) for px, py in pts]
    d.polygon(poly, fill=(20, 20, 24), outline=(255, 255, 255), width=int(1.6 * S))

def draw_keys(img, keys, active):
    """Key chips centred at the bottom. keys: list of labels; active: 0..1 press glow."""
    d = ImageDraw.Draw(img)
    fs = font(SYM, 15)
    widths = [max(34, d.textlength(k, font=fs) / S + 20) for k in keys]
    gap = 8
    total = sum(widths) + gap * (len(keys) - 1)
    x = (W - total) / 2; y = H - 52
    for k, w in zip(keys, widths):
        if k.startswith("+") or k.startswith("~"):
            k = k.lstrip("~")
            tw = d.textlength(k, font=fs) / S
            d.text(((x + (w - tw) / 2) * S, (y + 9) * S), k, font=fs, fill=(190, 204, 222))
            x += w + gap
            continue
        lift = 2 * active
        fill = mix((44, 58, 82), (70, 210, 190), active)
        rr(d, (x, y + 3, x + w, y + 37), 8, (10, 16, 30))
        rr(d, (x, y + 2 - lift, x + w, y + 34 - lift), 8, fill)
        tw = d.textlength(k, font=fs) / S
        d.text(((x + (w - tw) / 2) * S, (y + 9 - lift) * S), k, font=fs, fill=(245, 248, 252))
        x += w + gap

def render(name, duration, scene):
    frames_dir = f"/tmp/krado-frames-{name}"
    shutil.rmtree(frames_dir, ignore_errors=True); os.makedirs(frames_dir)
    n = int(duration * FPS)
    for i in range(n):
        img = background()
        draw_monitor(img)
        scene(img, i / FPS)
        img.resize((W, H), Image.LANCZOS).save(f"{frames_dir}/{i:04d}.png")
    os.makedirs(OUT, exist_ok=True)
    out = f"{OUT}/{name}.gif"
    log = open(f"{frames_dir}/ffmpeg.log", "w")
    pal = f"{frames_dir}/pal.png"
    subprocess.run(["ffmpeg", "-y", "-framerate", str(FPS), "-i", f"{frames_dir}/%04d.png",
                    "-vf", "palettegen=max_colors=128:stats_mode=full", pal], check=True, stdout=log, stderr=log)
    subprocess.run(["ffmpeg", "-y", "-framerate", str(FPS), "-i", f"{frames_dir}/%04d.png", "-i", pal,
                    "-lavfi", "paletteuse=dither=sierra2_4a", "-loop", "0", out], check=True, stdout=log, stderr=log)
    print(name, os.path.getsize(out) // 1024, "KB")
