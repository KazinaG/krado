"""Judge the Status rows in the real menu (Kazina 10/26 03:29, 03:33): information rows
cannot be chosen and never highlight; Accessibility while permission is needed stays
choosable and opens the setup guide."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops

root = Path(sys.argv[1])
failures, report = [], []


def changed(a, b):
    diff = ImageChops.difference(a, b)
    flat = getattr(diff, "get_flattened_data", None)
    data = list(flat() if flat else diff.getdata())
    return sum(max(p) > 24 for p in data) / max(1, len(data))


cases = sorted(p.name[: -len("-items.tsv")] for p in root.glob("*-items.tsv"))
if len(cases) < 4:
    failures.append(f"expected 4 cases (Light/Dark x granted/needed), found {cases}")
for case in cases:
    needed = case.endswith("permissionNeeded")
    menu = json.loads((root / f"{case}-menu.json").read_text())
    items = [line.split("\t") for line in (root / f"{case}-items.tsv").read_text().splitlines() if line.strip()]
    log = (root / f"{case}-app.log").read_text(errors="replace")
    fresh = Image.open(root / f"{case}-0-fresh.png").convert("RGB")
    s = fresh.width / menu["screenWidth"]
    crop = tuple(round(v * s) for v in (menu["x"], menu["y"], menu["x"] + menu["width"], menu["y"] + menu["height"]))
    fresh.crop(crop).save(root / f"{case}-menu.png")
    expected = {1: ("アクセシビリティ", needed, "permission"), 2: ("ウインドウ", False, "monitor")}
    for row, (word, enabled, key) in expected.items():
        name, x, y, w, h, ax_enabled = items[row]
        x, y, w, h = (float(v) for v in (x, y, w, h))
        hovered = Image.open(root / f"{case}-row{row}.png").convert("RGB")
        box = tuple(round(v * s) for v in (x + 8, y + 2, x + w - 8, y + h - 2))
        lit = changed(fresh.crop(box), hovered.crop(box))
        highlighted_in_log = f"KRADO_CI menu willHighlight item={key}" in log
        report.append(f"{case} row{row} {name!r}: AX enabled={ax_enabled}, hover change={lit:.2f}, "
                      f"willHighlight={highlighted_in_log}")
        if word not in name:
            failures.append(f"{case} row{row}: expected the {key} row, found {name!r}")
        if (ax_enabled == "true") != enabled:
            failures.append(f"{case} {key}: enabled={ax_enabled}, expected {str(enabled).lower()}")
        if enabled and (lit < 0.3 or not highlighted_in_log):
            failures.append(f"{case} {key}: choosable row did not highlight ({lit:.2f})")
        if not enabled and (lit > 0.02 or highlighted_in_log):
            failures.append(f"{case} {key}: information row highlighted on hover ({lit:.2f})")
    guide = "KRADO_CI permission guide shown" in log
    report.append(f"{case}: permission guide shown={guide}")
    if needed and not guide:
        failures.append(f"{case}: clicking Accessibility did not open the setup guide")
    if not needed and guide:
        failures.append(f"{case}: the setup guide opened without a click")

(root / "report.txt").write_text("\n".join(report + failures) + "\n")
print("\n".join(report))
if failures:
    sys.exit("\n".join(failures))
