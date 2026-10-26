"""Judge the real menu: click-stay, one highlight that looks native, and the Apple mini switch."""
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


def evidence(case, path, phase):
    return json.loads((root / f"{case}-{path}-{phase}.json").read_text())


WORDS = {"on": "オン", "off": "オフ"}  # the CI menu runs in Japanese


def check_switch(case, path, phase, img, g, scale, expected_on):
    context = f"{case} {path} {phase}"
    state = "on" if expected_on else "off"
    if g.get("switchClass") != "NSSwitch" or g.get("switchControlSize") != "mini":
        failures.append(f"{context}: expected Apple NSSwitch, mini")
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
    if not g.get("highlighted") and inks.get("title") != inks.get("label"):
        failures.append(f"{context}: resting title must use label ink")


def selection_profile(img, fresh, x_left, y_from, y_to, scale):
    """Where the highlight differs from the fresh menu: top row, height, left edge at
    mid-height, its colour, and the top-left corner's missing area in square points
    (radius r leaves about 0.21 r^2: 3.4 for r=4, 13.7 for r=8)."""
    x = round((x_left + 11) * scale)

    def changed_at(xx, y):
        return max(abs(a - b) for a, b in zip(img.getpixel((xx, y)), fresh.getpixel((xx, y)))) > 30
    ys = [y for y in range(round(y_from * scale), round(y_to * scale)) if changed_at(x, y)]
    if not ys:
        return None
    top, bottom = ys[0], ys[-1]
    mid = (top + bottom) // 2
    left = next((xx for xx in range(round(x_left * scale), round((x_left + 40) * scale)) if changed_at(xx, mid)), None)
    if left is None:
        return None
    fill = img.getpixel((x, mid))
    # Fractional coverage of each pixel in the corner box, from how far it moved
    # from the fresh menu toward the fill colour.
    box = round(10 * scale)
    deficit = 0.0
    for y in range(top, top + box):
        for xx in range(left, left + box):
            p, q = img.getpixel((xx, y)), fresh.getpixel((xx, y))
            span = sum(abs(f - b) for f, b in zip(fill, q)) or 1
            cover = min(1.0, sum(abs(a - b) for a, b in zip(p, q)) / span)
            deficit += 1 - cover
    return {"top": top, "height": bottom - top + 1, "left": left, "colour": fill,
            "corner": round(deficit / scale / scale, 1)}


def check_native_selection(case, imgs, gs, menu, s):
    """The custom row's highlight looks like the native one: Quit in the same menu."""
    g = gs["1-login"]
    if g.get("selfPaintedHighlight") is not False or g.get("selectionMaterial") is not True \
            or g.get("selectionVisible") is not True:
        failures.append(f"{case}: highlight must be the system selection material, not self-painted")
    login = selection_profile(imgs["1-login"], imgs["0-fresh"], g["x"], g["y"] - 4, g["y"] + g["height"] + 4, s)
    bottom = menu["y"] + menu["height"]
    quit = selection_profile(imgs["2-after"], imgs["0-fresh"], g["x"], bottom - g["height"] - 12, bottom, s)
    if not login or not quit:
        failures.append(f"{case}: could not find the login or Quit highlight ({login}, {quit})")
        return
    colour = max(abs(a - b) for a, b in zip(login["colour"], quit["colour"]))
    corner = abs(login["corner"] - quit["corner"])
    report.append(f"{case}: selection login={login} quit={quit} colour-diff={colour} corner-diff={corner:.1f}")
    if colour > 4:
        failures.append(f"{case}: highlight colour {login['colour']} differs from native {quit['colour']}")
    if corner > 2 or abs(login["left"] - quit["left"]) > 1 or abs(login["height"] - quit["height"]) > 1:
        failures.append(f"{case}: highlight shape differs from native (corner {login['corner']} vs {quit['corner']}, "
                        f"left {login['left']} vs {quit['left']}, height {login['height']} vs {quit['height']})")


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
        # Exclude the switch: after a click it is supposed to differ.
        word_x = min(v["switchRect"]["x"] for v in gs.values())
        login = box(g["x"] + 6, g["y"] + 2, word_x - g["x"] - 14, g["height"] - 4)
        qy = menu["y"] + menu["height"] - 6 - g["height"]
        quit = box(g["x"] + 6, qy + 2, g["width"] - 12, g["height"] - 4)
        crop = {k: v.crop(login) for k, v in imgs.items()}
        hovered = changed(crop["0-fresh"], crop["1-login"])
        if hovered < 0.3 or not g.get("highlighted"):
            failures.append(f"{case} {path}: hovering did not highlight Launch at Login")
        for phase in ("0-fresh", "1-login"):
            check_switch(case, path, phase, imgs[phase], gs[phase], s, case.endswith("-on"))
        after = "3-left" if path == "click-stay" else "2-after"
        if path == "click-stay":
            log = (root / f"{case}-{path}-app.log").read_text()
            if log.count("KRADO_CI real login row click: fake state=") != 1:
                failures.append(f"{case}: click must toggle exactly once")
            stayed = changed(crop["0-fresh"], crop["2-after"])
            if stayed < 0.3 or not gs["2-after"].get("highlighted"):
                failures.append(f"{case}: click-stay lost highlight while pointer stayed still")
            for key in ("x", "y", "width", "height"):
                if gs["2-after"][key] != g[key]:
                    failures.append(f"{case}: click changed row geometry: {key}")
            check_switch(case, path, "2-after", imgs["2-after"], gs["2-after"], s, not case.endswith("-on"))
            # Independently compare the visible word to a fresh hover in the flipped state.
            target_case = case.rsplit("-", 1)[0] + ("-off" if case.endswith("-on") else "-on")
            target_g = evidence(target_case, "slow-to-quit", "1-login")
            target_img = Image.open(root / f"{target_case}-slow-to-quit-1-login.png").convert("RGB")
            def word(im, geo):
                c = geo["switchRect"]
                return im.crop(box(c["x"], c["y"], c["width"], c["height"]))
            if changed(word(imgs["2-after"], gs["2-after"]), word(target_img, target_g)) > 0.02:
                failures.append(f"{case}: clicked switch differs from fresh flipped state")
            report.append(f"{case}: click-stay highlight={stayed:.2f}; state={gs['2-after'].get('state')}")
        check_switch(case, path, after, imgs[after], gs[after], s,
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
        if path == "slow-to-quit":
            check_native_selection(case, imgs, gs, menu, s)
        report.append(f"{case} {path}: hover={hovered:.2f}; after-leaving={stuck:.2f}")

(root / "report.txt").write_text("\n".join(report + failures) + "\n")
print("\n".join(report))
if failures:
    sys.exit("\n".join(failures))
