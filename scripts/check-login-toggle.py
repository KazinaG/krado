"""Compare a settled, clicked switch with a fresh menu in the target state."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops

root = Path(sys.argv[1])
failures = []
for initial, target in [("off", "on"), ("on", "off")]:
    def crop(stem):
        geometry = json.loads((root / f"{stem}.json").read_text())
        image = Image.open(root / f"{stem}.png").convert("RGB")
        # Main-display captures on hosted runners use screen points at 1x/2x.
        scale = image.width / geometry["screenWidth"]
        x, y, w, h = (geometry[k] for k in ("x", "y", "width", "height"))
        box = tuple(round(v * scale) for v in (x + w - 75, y, x + w, y + h))
        switch = image.crop(box)
        switch.save(root / f"{stem}-switch.png")
        return geometry, switch
    log = (root / f"{initial}.log").read_text()
    if log.count("KRADO_CI real login row click: fake state=") != 1:
        failures.append(f"{initial}: switch click must toggle exactly once")
    clicked, actual = crop(f"{initial}-after")
    fresh, expected = crop(f"{target}-fresh")
    if clicked["switchState"] != target or clicked["label"] != fresh["label"]:
        failures.append(f"{initial}: click did not reach target state")
    if actual.size != expected.size:
        failures.append(f"{initial}: row geometry changed")
        continue
    diff = ImageChops.difference(actual, expected)
    diff.save(root / f"{initial}-diff.png")
    # Ignore <= 3/255 compositor rounding; every other pixel must match.
    changed = sum(max(pixel) > 3 for pixel in diff.getdata())
    print(f"{initial} → {target}: changed switch pixels={changed}")
    if changed:
        failures.append(f"{initial}: settled switch differs from fresh target render ({changed} pixels)")
    # Independent ownership invariant: only the Apple switch displays state.
    if clicked["nativeBadge"]:
        failures.append(f"{initial}: native and custom switch owners are both active")
if failures:
    sys.exit("\n".join(failures))
