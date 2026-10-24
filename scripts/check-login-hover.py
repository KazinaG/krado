"""Judge the real menu: click-stay, one highlight, and the On/Off state word."""
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


WORDS = {"on": "オン", "off": "オフ"}  # the CI menu runs in Japanese


def check_state_text(case, path, phase, img, g, scale, expected_on):
    """The state is a word in the title's ink, with no circle or checkmark."""
    context = f"{case} {path} {phase}"
    state = "on" if expected_on else "off"
    if g.get("drawsStateText") is not True or g.get("drawsStateMark") is not False:
        failures.append(f"{context}: expected a state word and no state mark")
    if g.get("nativeBadge"):
        failures.append(f"{context}: native badge and custom state word both active")
    if g.get("state") != state or g.get("label") != WORDS[state]:
        failures.append(f"{context}: wrong state/word: {g.get('state')}/{g.get('label')}")
    inks = g.get("inks") or {}
    if not g.get("highlighted") and inks.get("text") != inks.get("label"):
        failures.append(f"{context}: unhighlighted state word must use label ink")
    r, t = g["stateRect"], g["titleRect"]
    if r["x"] < t["x"] + t["width"] + 15.5 or r["x"] + r["width"] > g["x"] + g["width"] - 16.5:
        failures.append(f"{context}: state word overlaps the title or the row edge")
    background = img.getpixel((round((r["x"] - 8) * scale), round((g["y"] + g["height"] / 2) * scale)))

    def strongest(rect):
        crop = img.crop(tuple(round(v * scale) for v in (rect["x"], rect["y"],
                                                        rect["x"] + rect["width"], rect["y"] + rect["height"])))
        return max(ratio(p, background) for p in pixels(crop))
    word, title = strongest(r), strongest(t)
    report.append(f"{context}: word {g.get('label')} contrast={word:.2f}:1; title={title:.2f}:1")
    # Same font and ink as the title, so the word must be about as legible.
    if word + 1e-6 < 0.9 * title:
        failures.append(f"{context}: state word {word:.2f}:1 is fainter than the title {title:.2f}:1")


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
        # Exclude the state word: after a click it is supposed to differ.
        word_x = min(v["stateRect"]["x"] for v in gs.values())
        login = box(g["x"] + 6, g["y"] + 2, word_x - g["x"] - 14, g["height"] - 4)
        qy = menu["y"] + menu["height"] - 6 - g["height"]
        quit = box(g["x"] + 6, qy + 2, g["width"] - 12, g["height"] - 4)
        crop = {k: v.crop(login) for k, v in imgs.items()}
        hovered = changed(crop["0-fresh"], crop["1-login"])
        if hovered < 0.3 or not g.get("highlighted"):
            failures.append(f"{case} {path}: hovering did not highlight Launch at Login")
        for phase in ("0-fresh", "1-login"):
            check_state_text(case, path, phase, imgs[phase], gs[phase], s, case.endswith("-on"))
        after = "3-left" if path == "click-stay" else "2-after"
        if path == "click-stay":
            stayed = changed(crop["0-fresh"], crop["2-after"])
            if stayed < 0.3 or not gs["2-after"].get("highlighted"):
                failures.append(f"{case}: click-stay lost highlight while pointer stayed still")
            for key in ("x", "y", "width", "height"):
                if gs["2-after"][key] != g[key]:
                    failures.append(f"{case}: click changed row geometry: {key}")
            check_state_text(case, path, "2-after", imgs["2-after"], gs["2-after"], s, not case.endswith("-on"))
            # Independently compare the visible word to a fresh hover in the flipped state.
            target_case = case.rsplit("-", 1)[0] + ("-off" if case.endswith("-on") else "-on")
            target_g = evidence(target_case, "slow-to-quit", "1-login")
            target_img = Image.open(root / f"{target_case}-slow-to-quit-1-login.png").convert("RGB")
            def word(im, geo):
                c = geo["stateRect"]
                return im.crop(box(c["x"], c["y"], c["width"], c["height"]))
            if changed(word(imgs["2-after"], gs["2-after"]), word(target_img, target_g)) > 0.02:
                failures.append(f"{case}: clicked word differs from fresh flipped state")
            report.append(f"{case}: click-stay highlight={stayed:.2f}; state={gs['2-after'].get('state')}")
        check_state_text(case, path, after, imgs[after], gs[after], s,
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
