"""Judge the real menu: click-stay, one highlight that looks native, and the On/Off capsule."""
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
    """The state word sits inside a capsule that is solid only when On."""
    context = f"{case} {path} {phase}"
    state = "on" if expected_on else "off"
    if g.get("drawsStateText") is not True or g.get("drawsStateCapsule") is not True:
        failures.append(f"{context}: expected the state word inside a capsule")
    if g.get("nativeBadge"):
        failures.append(f"{context}: native badge and custom state word both active")
    if g.get("state") != state or g.get("label") != WORDS[state]:
        failures.append(f"{context}: wrong state/word: {g.get('state')}/{g.get('label')}")
    if g.get("capsuleSolid") is not expected_on:
        failures.append(f"{context}: capsule must be solid only when On (solid={g.get('capsuleSolid')})")
    inks = g.get("inks") or {}
    if not g.get("highlighted"):
        # Resting row: the solid On capsule is label ink; Off's word is label ink, like the title.
        key = "fill" if expected_on else "text"
        if inks.get(key) != inks.get("label") or inks.get("title") != inks.get("label"):
            failures.append(f"{context}: unhighlighted capsule must use label ink ({key})")
    r, t, w = g["stateRect"], g["titleRect"], g["wordRect"]
    if r["x"] < t["x"] + t["width"] + 15.5 or r["x"] + r["width"] > g["x"] + g["width"] - 16.5:
        failures.append(f"{context}: state capsule overlaps the title or the row edge")
    if w["x"] < r["x"] + 2 or w["x"] + w["width"] > r["x"] + r["width"] - 2:
        failures.append(f"{context}: state word is not inside its capsule")
    mid = round((g["y"] + g["height"] / 2) * scale)
    row_bg = img.getpixel((round((r["x"] - 8) * scale), mid))
    inside = img.getpixel((round((r["x"] + 4) * scale), mid))

    def strongest(rect, background):
        crop = img.crop(tuple(round(v * scale) for v in (rect["x"], rect["y"],
                                                        rect["x"] + rect["width"], rect["y"] + rect["height"])))
        return max(ratio(p, background) for p in pixels(crop))
    word, title, fill = strongest(w, inside), strongest(t, row_bg), ratio(inside, row_bg)
    report.append(f"{context}: word {g.get('label')} contrast={word:.2f}:1 (on its capsule); "
                  f"title={title:.2f}:1; capsule fill vs row={fill:.2f}:1")
    # The word must be about as legible as the title.
    if word + 1e-6 < 0.9 * title:
        failures.append(f"{context}: state word {word:.2f}:1 is fainter than the title {title:.2f}:1")
    # Only On is filled: visibly when On, not at all for the shipped outline Off.
    # Under the highlight the white On capsule is as visible as the title's own
    # selected-text ink (yellow accent: about 2.4:1 for both), so judge it against that.
    # Kazina 10/26 21:55: at least as visible as the title (0.03 for rounding), up to
    # WCAG 1.4.11's 3:1 for non-text state indicators.
    if expected_on and fill + 0.03 < min(3, title):
        failures.append(f"{context}: On capsule fill is not visible ({fill:.2f}:1, title {title:.2f}:1)")
    if not expected_on and g.get("offStyle") == "A" and fill > 1.15:
        failures.append(f"{context}: Off capsule (outline) looks filled ({fill:.2f}:1)")
    # Kazina 10/26 03:19: Off stays A, outline only, no fill.
    if not expected_on and g.get("offStyle") == "A" and ("fill" in inks or g.get("capsuleRing") is not True):
        failures.append(f"{context}: Off must be an outline without fill (inks={inks})")
    if expected_on:
        check_on_opacity(context, img, g, scale, row_bg)
    elif g.get("offStyle") == "A":
        check_off_outline(context, img, g, scale, row_bg, title)


def coverage(pixel, background, ink):
    """How much of `ink` was laid over `background`, from the channel that moves most."""
    k = max(range(3), key=lambda i: abs(ink[i] - background[i]))
    span = ink[k] - background[k]
    return (pixel[k] - background[k]) / span if span else 0.0


def check_on_opacity(context, img, g, scale, row_bg):
    """Kazina 10/26 03:22 and 21:55: On's fill and ring share one opacity, the title ink's
    own (labelColor 85 % at rest, opaque selected text while highlighted). Read from the
    app's evidence and from the pixels: fill and top edge coverage both equal that."""
    inks = g.get("inks") or {}
    if inks.get("fillAlpha") != 1 or inks.get("ringAlpha") != 1 or g.get("fillAndRingShareOpacity") is not True:
        failures.append(f"{context}: On fill/ring must use the ink's own opacity "
                        f"(fill={inks.get('fillAlpha')}, ring={inks.get('ringAlpha')})")
    base = inks.get("fill") or [255, 255, 255, 1]
    want = base[3] if len(base) > 3 else 1
    ink = [round(v) for v in base[:3]]
    r = g["stateRect"]
    mid = round((g["y"] + g["height"] / 2) * scale)
    inside = img.getpixel((round((r["x"] + 4) * scale), mid))
    # The straight top edge, just past the rounded end: the ring's whole pixel row.
    edge = img.getpixel((round((r["x"] + 9) * scale), round(r["y"] * scale)))
    a_fill, a_edge = coverage(inside, row_bg, ink), coverage(edge, row_bg, ink)
    report.append(f"{context}: On coverage fill={a_fill:.3f} edge={a_edge:.3f} (ink {ink} over {row_bg})")
    if abs(a_fill - want) > 0.04:
        failures.append(f"{context}: On fill looks {a_fill:.2f} opaque, not {want:.2f}")
    if abs(a_edge - a_fill) > 0.04:
        failures.append(f"{context}: On ring ({a_edge:.2f}) and fill ({a_fill:.2f}) differ in opacity")


def check_fade(case, path, log_path=None):
    """Kazina 10/26 03:14: the toggle cross-fades over 150 ms through in-between values."""
    log = (log_path or root / f"{case}-{path}-app.log").read_text(errors="replace")
    samples = []
    for line in log.splitlines():
        if line.startswith("KRADO_CI login fade "):
            fields = dict(part.split("=", 1) for part in line.split()[3:])
            samples.append({k: float(v) for k, v in fields.items()})
    middle = [s for s in samples if 0.02 < s["p"] < 0.98]
    done = [s for s in samples if s["p"] >= 1]
    report.append(f"{case} {path}: fade samples={len(samples)} in-between={len(middle)} "
                  f"first-done-t={done[0]['t'] if done else None}")
    if not middle:
        failures.append(f"{case} {path}: toggle did not pass through in-between opacities")
    elif any(abs(s["outgoing"] + s["incoming"] - 1) > 0.01 for s in middle):
        failures.append(f"{case} {path}: cross-fade opacities do not add up to 1")
    if not done or not 0.15 <= done[0]["t"] <= 0.4 or any(s["t"] >= 0.15 for s in middle):
        failures.append(f"{case} {path}: fade must take 150 ms (done at {done[0]['t'] if done else None})")


def check_off_outline(context, img, g, scale, row_bg, title):
    """Kazina 10/26 21:55: Off's outline is as strong as On's fill, the title ink at its own
    opacity, and as visible as the title (same threshold as On). Read on the straight top edge."""
    inks = g.get("inks") or {}
    ring = inks.get("ring") or inks.get("text") or [255, 255, 255, 1]
    if inks.get("ring") != inks.get("title") or "ringAlpha" in inks:
        failures.append(f"{context}: Off outline must be the title ink as the system gives it (inks={inks})")
    want = ring[3] if len(ring) > 3 else 1
    r = g["stateRect"]
    edge = img.getpixel((round((r["x"] + 9) * scale), round(r["y"] * scale)))
    a_edge = coverage(edge, row_bg, [round(v) for v in ring[:3]])
    contrast = ratio(edge, row_bg)
    report.append(f"{context}: Off outline coverage={a_edge:.3f} (want {want:.2f}) "
                  f"contrast={contrast:.2f}:1 title={title:.2f}:1")
    if abs(a_edge - want) > 0.04:
        failures.append(f"{context}: Off outline looks {a_edge:.2f} opaque, not {want:.2f}")
    if contrast + 0.03 < min(3, title):
        failures.append(f"{context}: Off outline is not visible ({contrast:.2f}:1, title {title:.2f}:1)")


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
            check_fade(case, path)
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
        if path == "slow-to-quit":
            check_native_selection(case, imgs, gs, menu, s)
        report.append(f"{case} {path}: hover={hovered:.2f}; after-leaving={stuck:.2f}")

# Kazina 10/26 20:43: Down arrows to Launch at Login, then Return toggles it exactly once,
# with the same 150 ms fade as a click (real menu, posted key events).
key_logs = sorted((root / "fade").glob("fade-*-key-app.log"))
if len(key_logs) < 2:
    failures.append(f"expected Off and On keyboard cases, found {[p.name for p in key_logs]}")
for log_path in key_logs:
    case = log_path.name[: -len("-app.log")]
    text = log_path.read_text(errors="replace")
    toggles = text.count("KRADO_CI real login row click: fake state=")
    steps = (root / "fade" / f"{case}.log").read_text(errors="replace")
    by = next((l.split("=", 1)[1] for l in steps.splitlines() if l.startswith("toggled-by=")), "missing")
    report.append(f"{case}: toggles={toggles} toggled-by={by} "
                  f"key-lines={[l for l in text.splitlines() if l.startswith('KRADO_CI login key ')]}")
    if toggles != 1 or by != "CGEvent Return":
        failures.append(f"{case}: Return on Launch at Login must toggle once (toggles={toggles}, by={by})")
    else:
        check_fade(case, "keyboard", log_path)

(root / "report.txt").write_text("\n".join(report + failures) + "\n")
print("\n".join(report))
if failures:
    sys.exit("\n".join(failures))
