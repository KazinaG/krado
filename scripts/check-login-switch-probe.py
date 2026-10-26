#!/usr/bin/env python3
"""Reads login-switch-probe output: for each switch, the most saturated pixel inside
its rect, and whether it is close to controlAccentColor. Prints a table; exits 0."""
import colorsys, json, sys
from pathlib import Path
from PIL import Image

out = Path(sys.argv[1])
for phase in ("inactive", "active"):
    p = out / f"{phase}.json"
    if not p.exists():
        print(f"{phase}: missing"); continue
    j = json.loads(p.read_text())
    img = Image.open(j["screenshot"]).convert("RGB")
    scale = img.width / j["screenWidth"]
    acc = j["controlAccentColor"][:3]
    print(f"== {phase}: appIsActive={j['appIsActive']} menuWindow={j['menuWindowClass']} key={j['menuWindowIsKey']} accent={[round(v) for v in acc]}")
    for name, c in sorted(j["controls"].items()):
        r = c["rect"]
        if not r: print(f"  {name}: no window"); continue
        box = tuple(round(v * scale) for v in (r["x"], r["y"], r["x"] + r["width"], r["y"] + r["height"]))
        crop = img.crop(box)
        best, best_s = (0, 0, 0), -1.0
        for px in crop.getdata():
            h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in px))
            sat = s * (1 - abs(2 * l - 1))  # chroma
            if sat > best_s: best, best_s = px, sat
        dist = max(abs(a - b) for a, b in zip(best, acc))
        verdict = "ACCENT" if best_s > 0.3 and dist <= 48 else "not-accent"
        crop.resize((crop.width * 4, crop.height * 4)).save(out / f"{phase}-{name}.png")
        print(f"  {name}: most-saturated={best} chroma={best_s:.2f} maxdiff-to-accent={dist:.0f} -> {verdict}")
        for w in c.get("widgets", []): print(f"      widget {w}")
    a = out / f"{phase}-animation.json"
    if a.exists(): print("  animation:", a.read_text())
