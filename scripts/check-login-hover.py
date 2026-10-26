"""Judge the real menu for the Launch at Login row (maintainer 2026-10-26 17:17):
only the switch can be pressed, the row never lights up, the switch is in the
accent colour when on and moves, and the menu stays open."""
import colorsys
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops

root = Path(sys.argv[1])
failures, report = [], []


def pixels(image):
    flat = getattr(image, "get_flattened_data", None)
    return list(flat() if flat else image.getdata())


def changed(a, b):
    diff = ImageChops.difference(a, b)
    return sum(max(p) > 24 for p in pixels(diff)) / (a.width * a.height)


def chroma(px):
    _, l, s = colorsys.rgb_to_hls(*(v / 255 for v in px[:3]))
    return s * (1 - abs(2 * l - 1))


def evidence(case, path, phase):
    return json.loads((root / f"{case}-{path}-{phase}.json").read_text())


WORDS = {"on": "オン", "off": "オフ"}  # the CI menu runs in Japanese


def check_switch(context, img, g, scale, expected_on):
    state = "on" if expected_on else "off"
    if g.get("switchClass") != "NSSwitch" or g.get("switchControlSize") != "mini":
        failures.append(f"{context}: expected Apple NSSwitch, mini (got {g.get('switchClass')})")
    if g.get("switchState") != state or g.get("state") != state or g.get("label") != WORDS[state]:
        failures.append(f"{context}: wrong switch state or accessibility word")
    if g.get("switchEnabled") is not True or g.get("nativeBadge"):
        failures.append(f"{context}: switch disabled or duplicate native badge")
    r, t = g["switchRect"], g["titleRect"]
    if (r["x"] < g["x"] or r["y"] < g["y"] or
            r["x"] + r["width"] > g["x"] + g["width"] or
            r["y"] + r["height"] > g["y"] + g["height"]):
        failures.append(f"{context}: switch outside row")
    if abs(r["y"] + r["height"] / 2 - g["y"] - g["height"] / 2) > 1:
        failures.append(f"{context}: switch not vertically centred")
    if r["x"] < t["x"] + t["width"] + 15.5 or abs(r["x"] + r["width"] - g["x"] - g["width"] + 17) > 0.5:
        failures.append(f"{context}: switch overlaps title or wrong trailing inset")
    if g.get("switchFittingSize") != [r["width"], r["height"]]:
        failures.append(f"{context}: switch does not use its fitting size")
    inks = g.get("inks") or {}
    if inks.get("title") != inks.get("label"):
        failures.append(f"{context}: title must always use label ink (the row never highlights)")
    if g.get("rowHighlight") or g.get("highlighted") or g.get("selfPaintedHighlight") is not False:
        failures.append(f"{context}: the row must never highlight")
    # macOS 26 draws an inactive app's on switch gray: krado must be active (StatusMenuActivation).
    if g.get("macOSMajor", 0) >= 26 and (g.get("appIsActive") is not True or g.get("menuWindowIsKey") is not True):
        failures.append(f"{context}: macOS 26 menu opened while krado was not active")
    # Colour: the most saturated pixel inside the switch against controlAccentColor.
    box = tuple(round(v * scale) for v in (r["x"], r["y"], r["x"] + r["width"], r["y"] + r["height"]))
    best = max(pixels(img.crop(box)), key=chroma)
    accent = g["accent"][:3]
    dist = max(abs(a - b) for a, b in zip(best, accent))
    grey_accent = chroma([round(v) for v in accent]) < 0.1  # graphite
    if expected_on and (dist > 48 or (not grey_accent and chroma(best) < 0.3)):
        failures.append(f"{context}: on switch is not the accent colour ({best} vs {[round(v) for v in accent]})")
    if not expected_on and not grey_accent and chroma(best) > 0.3:
        failures.append(f"{context}: off switch shows colour {best}")
    return best


geometry_paths = sorted(root.glob("*-geometry.json"))
if not geometry_paths:
    failures.append("no real-menu evidence found")
for geometry_path in geometry_paths:
    case = geometry_path.name[: -len("-geometry.json")]
    menu = json.loads((root / f"{case}-menu.json").read_text())
    start_on = case.endswith("-on")
    for path in ("slow-to-quit", "jump-to-quit", "down", "up-down", "click-row", "click-switch"):
        phases = ["0-fresh", "1-login", "2-after"] + (["3-left"] if path.startswith("click-") else [])
        imgs = {k: Image.open(root / f"{case}-{path}-{k}.png").convert("RGB") for k in phases}
        gs = {k: evidence(case, path, k) for k in phases}
        g = gs["1-login"]
        s = imgs["0-fresh"].width / menu["screenWidth"]
        box = lambda x, y, w, h: tuple(round(v * s) for v in (x, y, x + w, y + h))
        # The row without the switch (the switch may move after a click).
        sw_x = min(v["switchRect"]["x"] for v in gs.values())
        row_box = box(g["x"] + 6, g["y"] + 1, sw_x - g["x"] - 14, g["height"] - 2)
        qy = menu["y"] + menu["height"] - 6 - g["height"]
        quit = box(g["x"] + 6, qy + 2, g["width"] - 12, g["height"] - 4)
        whole = box(menu["x"], menu["y"], menu["width"], menu["height"])
        crop = {k: v.crop(row_box) for k, v in imgs.items()}
        hovered = changed(crop["0-fresh"], crop["1-login"])
        if hovered > 0.02:
            failures.append(f"{case} {path}: hovering lit up the Launch at Login row ({hovered:.2f})")
        if not g.get("menuItemHighlighted"):
            report.append(f"{case} {path}: note: AppKit did not mark the hovered item highlighted")
        for phase in ("0-fresh", "1-login"):
            best = check_switch(f"{case} {path} {phase}", imgs[phase], gs[phase], s, start_on)
        report.append(f"{case} {path}: switch colour at rest {best}, accent {[round(v) for v in g['accent'][:3]]}")
        log = (root / f"{case}-{path}-app.log").read_text()
        clicks = log.count("KRADO_CI real login row click: fake state=")
        after_on = start_on
        if path == "click-row":
            if clicks != 0:
                failures.append(f"{case}: a click on the row title must not toggle ({clicks})")
        elif path == "click-switch":
            after_on = not start_on
            if clicks != 1:
                failures.append(f"{case}: a click on the switch must toggle exactly once ({clicks})")
        if path.startswith("click-"):
            # The menu is still open: Quit is where it was and the row still draws.
            if changed(imgs["0-fresh"].crop(quit), imgs["2-after"].crop(quit)) > 0.02 \
                    or changed(crop["0-fresh"], crop["2-after"]) > 0.02:
                failures.append(f"{case} {path}: menu closed or the row lit up after the click")
            for key in ("x", "y", "width", "height"):
                if gs["2-after"][key] != g[key]:
                    failures.append(f"{case} {path}: click changed row geometry: {key}")
            check_switch(f"{case} {path} 2-after", imgs["2-after"], gs["2-after"], s, after_on)
            if path == "click-switch":
                # Settled switch equals a fresh menu in the flipped state.
                target_case = case.rsplit("-", 1)[0] + ("-off" if start_on else "-on")
                tg = evidence(target_case, "slow-to-quit", "0-fresh")
                timg = Image.open(root / f"{target_case}-slow-to-quit-0-fresh.png").convert("RGB")
                def sw(im, geo):
                    c = geo["switchRect"]
                    return im.crop(box(c["x"], c["y"], c["width"], c["height"]))
                d = changed(sw(imgs["2-after"], gs["2-after"]), sw(timg, tg))
                if d > 0.02:
                    failures.append(f"{case}: clicked switch differs from a fresh menu in the flipped state ({d:.2f})")
                report.append(f"{case}: click-switch toggled once, menu open, settled-diff={d:.2f}")
        if path == "up-down":
            ga = gs["2-after"]
            ring = changed(imgs["0-fresh"].crop(box(ga["switchRect"]["x"] - 4, ga["switchRect"]["y"] - 4,
                                                    ga["switchRect"]["width"] + 8, ga["switchRect"]["height"] + 8)),
                           imgs["2-after"].crop(box(ga["switchRect"]["x"] - 4, ga["switchRect"]["y"] - 4,
                                                    ga["switchRect"]["width"] + 8, ga["switchRect"]["height"] + 8)))
            if ga.get("focusRing") is not True or ring < 0.05:
                failures.append(f"{case}: keyboard focus on the row must show a focus ring at the switch ({ring:.2f})")
            if changed(crop["0-fresh"], crop["2-after"]) > 0.02:
                failures.append(f"{case}: keyboard focus lit up the row instead of ringing the switch")
            report.append(f"{case}: up-down focus ring changed={ring:.2f}")
        after = "3-left" if path.startswith("click-") else "2-after"
        if path in ("slow-to-quit", "jump-to-quit") or path.startswith("click-"):
            if changed(imgs["0-fresh"].crop(quit), imgs[after].crop(quit)) < 0.3:
                failures.append(f"{case} {path}: Quit did not highlight")
        if path == "down" and changed(imgs["0-fresh"].crop(whole), imgs[after].crop(whole)) < 0.005:
            failures.append(f"{case}: keyboard Down highlighted nothing")
        if gs[after].get("focusRing") and path != "up-down":
            failures.append(f"{case} {path}: focus ring left on after leaving")
        report.append(f"{case} {path}: hover-change={hovered:.2f}")

(root / "report.txt").write_text("\n".join(report + failures) + "\n")
print("\n".join(report))
if failures:
    sys.exit("\n".join(failures))
