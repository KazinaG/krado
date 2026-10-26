#!/usr/bin/env python3
"""Reads login-switch-probe output. Colour: the most saturated pixel in each switch
rect versus controlAccentColor. Motion: knob position (centroid of the brightest
pixels) in each sampled frame. Prints a report; exits 0 (diagnosis only)."""
import colorsys, json, sys
from pathlib import Path
from PIL import Image

out = Path(sys.argv[1])
def chroma(px):
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in px[:3]))
    return s * (1 - abs(2 * l - 1))
for phase in ("inactive-early", "inactive", "activate-before-open-early", "activate-before-open"):
    p = out / f"{phase}.json"
    if not p.exists(): print(f"{phase}: missing"); continue
    j = json.loads(p.read_text())
    img = Image.open(j["screenshot"]).convert("RGB")
    scale = img.width / j["screenWidth"]
    acc = j["controlAccentColor"][:3]
    print(f"== {phase}: appIsActive={j['appIsActive']} menuWindowIsKey={j['menuWindowIsKey']} accent={[round(v) for v in acc]}")
    for name, c in sorted(j["controls"].items()):
        r = c["rect"]
        if not r: print(f"  {name}: not on screen (menu not open)"); continue
        box = tuple(round(v * scale) for v in (r["x"], r["y"], r["x"] + r["width"], r["y"] + r["height"]))
        crop = img.crop(box)
        best = max(crop.getdata(), key=chroma)
        dist = max(abs(a - b) for a, b in zip(best, acc))
        verdict = "ACCENT" if chroma(best) > 0.3 and dist <= 48 else "not-accent"
        crop.resize((crop.width * 4, crop.height * 4)).save(out / f"{phase}-{name}.png")
        print(f"  {name}: most-saturated={best} chroma={chroma(best):.2f} maxdiff={dist:.0f} -> {verdict}")
log = json.loads((out / "log.json").read_text()) if (out / "log.json").exists() else {}
print("log:", json.dumps(log, indent=1))
for phase in ("inactive", "activate-before-open"):
    for kind in ("animator", "click"):
        f = out / f"{phase}-{kind}-frames.json"
        if not f.exists(): print(f"{phase} {kind}: no frames"); continue
        t_evt = log.get(f"{phase}.{'animatorAt' if kind == 'animator' else 'clickAt'}")
        rows = []
        for fr in json.loads(f.read_text()):
            im = Image.open(fr["path"]).convert("RGB")
            w, h = im.size
            pts = [(x, y) for y in range(h) for x in range(w) if sum(im.getpixel((x, y))) / 3 > 245 and chroma(im.getpixel((x, y))) < 0.08]
            kx = sum(p[0] for p in pts) / len(pts) / w if pts else -1
            fill = max(im.getdata(), key=chroma)
            dt = (fr["t0"] - t_evt) * 1000 if t_evt else float("nan")
            rows.append(f"{dt:+7.0f}ms knob={kx:.2f} fill={fill}")
        print(f"-- {phase} {kind} (t relative to event):")
        for r in rows: print("   ", r)
