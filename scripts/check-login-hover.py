"""Judge login-hover/ screenshots: one highlight only, and a readable On/Off badge."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops

root = Path(sys.argv[1])
failures, report = [], []


def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in c[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def pixels(image):
    flat = getattr(image, "get_flattened_data", None)
    return list(flat() if flat else image.getdata())


def changed(a, b):
    diff = ImageChops.difference(a, b)
    return sum(max(p) > 24 for p in pixels(diff)) / (a.width * a.height)


for geometry_path in sorted(root.glob("*-geometry.json")):
    case = geometry_path.name[: -len("-geometry.json")]
    g = json.loads(geometry_path.read_text())
    menu = json.loads((root / f"{case}-menu.json").read_text())
    for path in ("slow-to-quit", "jump-to-quit", "down"):
        imgs = {k: Image.open(root / f"{case}-{path}-{k}.png").convert("RGB")
                for k in ("0-fresh", "1-login", "2-after")}
        s = imgs["0-fresh"].width / menu["screenWidth"]
        box = lambda x, y, w, h: tuple(round(v * s) for v in (x, y, x + w, y + h))
        login = box(g["x"] + 6, g["y"] + 2, g["width"] - 12, g["height"] - 4)
        qy = menu["y"] + menu["height"] - 6 - g["height"]
        quit = box(g["x"] + 6, qy + 2, g["width"] - 12, g["height"] - 4)
        crop = {k: v.crop(login) for k, v in imgs.items()}
        hovered = changed(crop["0-fresh"], crop["1-login"])
        stuck = changed(crop["0-fresh"], crop["2-after"])
        line = f"{case} {path}: login row hovered={hovered:.2f} after={stuck:.2f}"
        if hovered < 0.3:
            failures.append(f"{case} {path}: hovering Launch at Login did not highlight it")
        if stuck > 0.02:
            failures.append(f"{case} {path}: Launch at Login still highlighted after leaving it ({stuck:.2f})")
        if path != "down":
            moved = changed(imgs["0-fresh"].crop(quit), imgs["2-after"].crop(quit))
            line += f" quit={moved:.2f}"
            if moved < 0.3:
                failures.append(f"{case} {path}: the pointer did not highlight Quit")
        else:
            whole = box(menu["x"], menu["y"], menu["width"], menu["height"])
            elsewhere = changed(imgs["0-fresh"].crop(whole), imgs["2-after"].crop(whole))
            line += f" menu-changed={elsewhere:.3f}"
            if elsewhere < 0.005:
                failures.append(f"{case} down: keyboard Down highlighted nothing")
        report.append(line)
    # Badge contrast in the hovered state, measured from screen pixels.
    img = Image.open(root / f"{case}-slow-to-quit-1-login.png").convert("RGB")
    s = img.width / menu["screenWidth"]
    c = g["capsule"]
    pill = img.crop(tuple(round(v * s) for v in (c["x"] + 2, c["y"] + 2, c["x"] + c["width"] - 2, c["y"] + c["height"] - 2)))
    pill_pixels = pixels(pill)
    bg = max(set(pill_pixels), key=pill_pixels.count)
    ink = max(pill_pixels, key=lambda p: ratio(p, bg))
    hy = round((g["y"] + g["height"] / 2) * s)
    hx = round((c["x"] - 8) * s)
    highlight = img.getpixel((hx, hy))
    report.append(f"{case} badge (pixels): text {ink} on pill {bg} = {ratio(ink, bg):.2f}:1; "
                  f"pill vs highlight {highlight} = {ratio(bg, highlight):.2f}:1")
    exact = g.get("colors")
    if exact:
        t, p, h = (tuple(exact[k]) for k in ("text", "pill", "highlight"))
        r = ratio(t, p)
        report.append(f"{case} badge (exact): text {t} on pill {p} = {r:.2f}:1; pill vs highlight {h} = {ratio(p, h):.2f}:1")
        if r < 3:
            failures.append(f"{case}: badge text contrast {r:.2f}:1 < 3:1 while highlighted")

(root / "report.txt").write_text("\n".join(report) + "\n")
print("\n".join(report))
if failures:
    sys.exit("\n".join(failures))
