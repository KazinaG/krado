"""Judge the real menu: click-stay, one highlight, state marks and graphic contrast."""
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


def evidence(case, path, phase):
    return json.loads((root / f"{case}-{path}-{phase}.json").read_text())


def composite(ink, background):
    return tuple(v * ink[3] + b * (1 - ink[3]) for v, b in zip(ink[:3], background))


def check_indicator(case, path, phase, img, g, scale, expected_on):
    context = f"{case} {path} {phase}"
    c = g["capsule"]
    highlighted = g.get("highlighted")
    if c["width"] != 16 or c["height"] != 16 or g.get("drawsStateText") is not False:
        failures.append(f"{context}: expected a fixed 16pt mark without state text")
    if g.get("nativeBadge"):
        failures.append(f"{context}: native and custom indicators both active")
    if g.get("state") != ("on" if expected_on else "off") or g.get("symbol") != ("checkmark" if expected_on else ""):
        failures.append(f"{context}: wrong state/symbol: {g.get('state')}/{g.get('symbol')}")
    if (g.get("highlightedFill") != (expected_on or highlighted)
            or g.get("highlightedCheckmark") != expected_on
            or g.get("drawsRing") != (not expected_on)):
        failures.append(f"{context}: wrong indicator style")
    if not expected_on and (g.get("ringWidth") != 1 or g.get("ringInset") != 0.5):
        failures.append(f"{context}: expected a 1pt ring inset 0.5pt")
    # Crop safely inside the circle, excluding the ring and its antialiasing.
    box = tuple(round(v * scale) for v in (c["x"] + 4, c["y"] + 4,
                                           c["x"] + c["width"] - 4, c["y"] + c["height"] - 4))
    samples = pixels(img.crop(box))
    fill = max(set(samples), key=samples.count)
    background = img.getpixel((round((c["x"] - 8) * scale), round((g["y"] + g["height"] / 2) * scale)))
    exact, inks = g.get("colors"), g.get("inks")
    if not exact or not inks:
        failures.append(f"{context}: no current-draw colors/inks recorded")
        return
    # Validate the requested ink, separately from screenshot contrast. No circle
    # is required to contrast with the accent: native white menu text on yellow
    # itself has only 2.08:1 contrast.
    if expected_on:
        expected_fill = (255, 255, 255) if highlighted else composite(inks["pill"], background)
        if highlighted and inks["pill"] != [255, 255, 255, 1]:
            failures.append(f"{context}: highlighted On must have a solid white fill")
    else:
        expected_fill = tuple(v * 0.6 for v in background) if highlighted else background
        if highlighted and (inks["pill"] != [0, 0, 0, 0.4] or inks["ring"] != [255, 255, 255, 1]):
            failures.append(f"{context}: highlighted Off must have 40% black fill and white ring")
        if not highlighted and (inks["ring"][:3] != inks["label"][:3] or inks["ring"][3] not in (0.45, 1)):
            failures.append(f"{context}: unhighlighted Off must use label ink at faint or full alpha")
    if max(abs(a - b) for a, b in zip(fill, expected_fill)) > 24:
        failures.append(f"{context}: indicator fill {fill} differs from {expected_fill}")
    if expected_on:
        ink = max(samples, key=lambda p: ratio(p, fill))
        pixel_contrast = ratio(ink, fill)
        exact_fill = exact["pill"] if highlighted else composite(inks["pill"], background)
        exact_contrast = ratio(composite(inks["text"], exact_fill), exact_fill)
        target, description = 3, "checkmark vs circle"
    else:
        # At each cardinal point, choose the strongest ring pixel in a narrow
        # strip. This avoids corner antialiasing and verifies all four sides.
        x, y, w, h = (c[k] for k in ("x", "y", "width", "height"))
        strips = [(x + w / 2 - 1, y, 2, 1), (x + w / 2 - 1, y + h - 1, 2, 1),
                  (x, y + h / 2 - 1, 1, 2), (x + w - 1, y + h / 2 - 1, 1, 2)]
        ring_pixels = []
        for sx, sy, sw, sh in strips:
            crop = img.crop(tuple(round(v * scale) for v in (sx, sy, sx + sw, sy + sh)))
            candidates = pixels(crop)
            ring_pixels.append(max(candidates, key=lambda p: ratio(p, fill)))
        pixel_contrast = min(ratio(p, fill) for p in ring_pixels)
        if highlighted:
            if any(max(abs(v - 255) for v in p) > 24 for p in ring_pixels):
                failures.append(f"{context}: white ring is missing in screenshot")
            exact_contrast = ratio(exact["ring"], exact["pill"])
            target, description = 3, "white ring vs inner fill"
        else:
            exact_contrast = ratio(composite(inks["ring"], background), background)
            target = min(3, ratio(composite(inks["label"], background), background))
            description = "ring vs menu background (capped at native label ink)"
    report.append(f"{context}: {description}: pixels={pixel_contrast:.2f}:1; exact={exact_contrast:.2f}:1; target={target:.2f}:1")
    if pixel_contrast + 1e-6 < target:
        failures.append(f"{context}: {description} (pixels) {pixel_contrast:.2f}:1 < {target:.2f}:1")
    if exact_contrast + 1e-6 < target:
        failures.append(f"{context}: {description} (exact) {exact_contrast:.2f}:1 < {target:.2f}:1")


geometry_paths = sorted(root.glob("*-geometry.json"))
if not geometry_paths:
    failures.append("no real-menu evidence found")
for geometry_path in geometry_paths:
    case = geometry_path.name[: -len("-geometry.json")]
    menu = json.loads((root / f"{case}-menu.json").read_text())
    for path in ("slow-to-quit", "jump-to-quit", "down", "click-stay"):
        phases = ["0-fresh", "1-login", "2-after"] + (["3-left"] if path == "click-stay" else [])
        imgs = {k: Image.open(root / f"{case}-{path}-{k}.png").convert("RGB") for k in phases}
        gs = {k: evidence(case, path, k) for k in phases}
        g = gs["1-login"]
        s = imgs["0-fresh"].width / menu["screenWidth"]
        box = lambda x, y, w, h: tuple(round(v * s) for v in (x, y, x + w, y + h))
        # Exclude the indicator: after a click its state is supposed to differ.
        login = box(g["x"] + 6, g["y"] + 2, g["capsule"]["x"] - g["x"] - 14, g["height"] - 4)
        qy = menu["y"] + menu["height"] - 6 - g["height"]
        quit = box(g["x"] + 6, qy + 2, g["width"] - 12, g["height"] - 4)
        crop = {k: v.crop(login) for k, v in imgs.items()}
        hovered = changed(crop["0-fresh"], crop["1-login"])
        if hovered < 0.3 or not g.get("highlighted"):
            failures.append(f"{case} {path}: hovering did not highlight Launch at Login")
        for phase in ("0-fresh", "1-login"):
            check_indicator(case, path, phase, imgs[phase], gs[phase], s, case.endswith("-on"))
        after = "3-left" if path == "click-stay" else "2-after"
        if path == "click-stay":
            stayed = changed(crop["0-fresh"], crop["2-after"])
            if stayed < 0.3 or not gs["2-after"].get("highlighted"):
                failures.append(f"{case}: click-stay lost highlight while pointer stayed still")
            for key in ("x", "y", "width", "height", "capsule"):
                if gs["2-after"][key] != g[key]:
                    failures.append(f"{case}: click changed row/indicator geometry: {key}")
            check_indicator(case, path, "2-after", imgs["2-after"], gs["2-after"], s, not case.endswith("-on"))
            # Independently compare the visible mark to a fresh hover in the flipped state.
            target_case = case.rsplit("-", 1)[0] + ("-off" if case.endswith("-on") else "-on")
            target_g = evidence(target_case, "slow-to-quit", "1-login")
            target_img = Image.open(root / f"{target_case}-slow-to-quit-1-login.png").convert("RGB")
            def mark(im, geo):
                c = geo["capsule"]
                return im.crop(box(c["x"], c["y"], c["width"], c["height"]))
            if changed(mark(imgs["2-after"], gs["2-after"]), mark(target_img, target_g)) > 0.02:
                failures.append(f"{case}: clicked mark differs from fresh flipped state")
            report.append(f"{case}: click-stay highlight={stayed:.2f}; state={gs['2-after'].get('state')}")
        check_indicator(case, path, after, imgs[after], gs[after], s,
                        case.endswith("-on") != (path == "click-stay"))
        stuck = changed(crop["0-fresh"], crop[after])
        if stuck > 0.02 or gs[after].get("highlighted"):
            failures.append(f"{case} {path}: stale Launch at Login highlight after leaving ({stuck:.2f})")
        if path != "down":
            moved = changed(imgs["0-fresh"].crop(quit), imgs[after].crop(quit))
            if moved < 0.3:
                failures.append(f"{case} {path}: Quit did not highlight")
        else:
            whole = box(menu["x"], menu["y"], menu["width"], menu["height"])
            if changed(imgs["0-fresh"].crop(whole), imgs[after].crop(whole)) < 0.005:
                failures.append(f"{case}: keyboard Down highlighted nothing")
        report.append(f"{case} {path}: hover={hovered:.2f}; after-leaving={stuck:.2f}")

(root / "report.txt").write_text("\n".join(report + failures) + "\n")
print("\n".join(report))
if failures:
    sys.exit("\n".join(failures))
