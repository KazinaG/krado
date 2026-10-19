#!/usr/bin/env python3
"""Crop a main-display screenshot around a menu, converting points to pixels."""
import json
import math
import subprocess
import sys

full, bounds_file, output = sys.argv[1:]
with open(bounds_file, encoding="utf-8") as stream:
    bounds = json.load(stream)
info = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", full], text=True)
dimensions = dict(line.strip().split(": ", 1) for line in info.splitlines() if ": " in line)
width, height = int(dimensions["pixelWidth"]), int(dimensions["pixelHeight"])
sx, sy = width / bounds["screenWidth"], height / bounds["screenHeight"]
left = max(0, math.floor((bounds["x"] - 40) * sx))
top = max(0, math.floor((bounds["y"] - 40) * sy))
right = min(width, math.ceil((bounds["x"] + bounds["width"] + 40) * sx))
bottom = min(height, math.ceil((bounds["y"] + bounds["height"] + 40) * sy))
if right <= left or bottom <= top:
    raise SystemExit("Menu is outside the captured main display")
subprocess.run(["sips", "--cropToHeightWidth", str(bottom - top), str(right - left),
                "--cropOffset", str(top), str(left), full, "--out", output], check=True)
