#!/usr/bin/env python3
"""CI probe helper: capture one switch rect ~25 times as fast as screencapture allows,
writing <out>/<phase>-<kind>-frames.json with timestamps."""
import json, subprocess, sys, time
out, phase, kind = sys.argv[1:4]
r = json.load(open(f"{out}/{phase}-frames-spec.json"))[kind]
frames = []
end = time.time() + 1.6
i = 0
while time.time() < end:
    path = f"{out}/{phase}-{kind}-{i:02d}.png"
    t0 = time.time()
    subprocess.run(["/usr/sbin/screencapture", "-x", "-R%d,%d,%d,%d" % (r["x"], r["y"], r["width"], r["height"]), path])
    frames.append({"path": path, "t0": t0, "t1": time.time()})
    i += 1
json.dump(frames, open(f"{out}/{phase}-{kind}-frames.json", "w"), indent=1)
