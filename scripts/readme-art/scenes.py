import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anim import *

C, R = 4, 2
START = (150, 200, 330, 318)
GRAB = (60, 10)                   # grab point inside the title bar

def seg(t, a, b): return (t - a) / (b - a)

def window_at(cursor):
    w, h = START[2] - START[0], START[3] - START[1]
    x, y = cursor[0] - GRAB[0], cursor[1] - GRAB[1]
    return (x, y, x + w, y + h)

def keys_text(img, keys, active, plus=None):
    draw_keys(img, keys + ([plus] if plus else []), active)

def path(points, t):
    """Piecewise eased path through points over t in [0,1]."""
    n = len(points) - 1
    i = min(int(t * n), n - 1); u = ease(t * n - i)
    (x0, y0), (x1, y1) = points[i], points[i + 1]
    return (lerp(x0, x1, u), lerp(y0, y1, u))

def cell_of(pt):
    for c in range(C):
        for r in range(R):
            x0, y0, x1, y1 = grid_rect(C, R, c, r, c + 1, r + 1)
            if x0 - 4 <= pt[0] <= x1 + 4 and y0 - 4 <= pt[1] <= y1 + 4: return c, r
    return None

def drag_scene(mode):
    """mode: 'snap', 'shift', 'option', 'esc'"""
    rest = (START[0] + GRAB[0], START[1] + GRAB[1])
    approach = (rest[0] + 40, rest[1] + 60)
    if mode == "shift":
        pts = [rest, (190, 90), (330, 95), (460, 100)]
    elif mode == "option":
        pts = [rest, (300, 150), (380, 120)]
    else:
        pts = [rest, (300, 150), (470, 110)]
    T0, T1, T2, T3, T4 = 0.5, 0.8, 3.4, 3.9, 5.4   # approach, press, drag end, settle, reset
    def scene(img, t):
        # cursor approach
        if t < T0:
            cur = (lerp(approach[0], rest[0], ease(seg(t, 0, T0))), lerp(approach[1], rest[1], ease(seg(t, 0, T0))))
        elif t < T1:
            cur = rest
        elif t < T2:
            cur = path(pts, seg(t, T1, T2))
        else:
            cur = pts[-1]
        dragging = T1 <= t < T2
        grid_alpha = 0.0
        hl = None
        span = None
        if T1 + 0.15 <= t < T2 + 0.35:
            grid_alpha = ease_out(seg(t, T1 + 0.15, T1 + 0.45)) if t < T2 else 1 - ease(seg(t, T2, T2 + 0.35))
        # modifier timing
        mod_on = False
        if mode == "shift": mod_on = 1.15 <= t < T2
        if mode == "option": mod_on = 1.3 <= t < T2
        esc_at = 2.45
        cancelled = mode == "esc" and t >= esc_at
        if mode == "option" and mod_on:
            grid_alpha *= max(0.0, 1 - seg(t, 1.3, 1.55))
        if cancelled:
            grid_alpha *= max(0.0, 1 - seg(t, esc_at, esc_at + 0.25))
        if mode == "option" and t >= 1.55 and t < T2 + 0.35: grid_alpha = 0
        # highlight from the cursor
        c = cell_of(cur if t < T2 else pts[-1])
        if mode == "shift" and c:
            # bounding span of visited cells after Shift went down
            first = cell_of(path(pts, seg(1.15, T1, T2)))
            fc = first[0] if first else c[0]
            span = (min(fc, c[0]), 0, max(fc, c[0]) + 1, 1)
        elif c:
            span = (c[0], c[1], c[0] + 1, c[1] + 1)
        if span: hl = grid_rect(C, R, *span)
        snaps = mode in ("snap", "shift") and span is not None
        final_free = window_at(pts[-1])
        final = hl if snaps else final_free
        draw_grid(img, C, R, grid_alpha, hl if grid_alpha > 0 and not cancelled else None)
        if t < T1:
            win = START
        elif t < T2:
            win = window_at(cur)
        elif t < T3:
            win = lerp_rect(final_free, final, ease(seg(t, T2, T3)))
        elif t < T4:
            win = final
        else:
            win = lerp_rect(final, START, ease(seg(t, T4, T4 + 0.6)))
        draw_window(img, win)
        if t < T4: draw_cursor(img, *cur, pressed=dragging)
        # key chips
        if mode == "shift":
            draw_keys(img, ["⇧ shift", "+ drag"], 1.0 if mod_on else 0.0)
        elif mode == "option":
            draw_keys(img, ["⌥ option", "+ drag"], 1.0 if mod_on else 0.0)
        elif mode == "esc":
            draw_keys(img, ["~drag +", "esc"], ease_out(1 - seg(t, esc_at, esc_at + 0.6)) if t >= esc_at and t < esc_at + 0.6 else 0.0)
    return scene, T4 + 0.8

def keyboard_scene():
    steps = [  # (keys, span after)
        (["⌃", "⌘", "→"], (2, 0, 3, 1)),
        (["⌃", "⌘", "←"], (1, 0, 2, 1)),
        (["⌃", "⌘", "⇧", "→"], (1, 0, 3, 1)),
        (["⌃", "⌘", "⇧", "→"], (1, 0, 4, 1)),
        (["⌃", "⌘", "⇧", "←"], (1, 0, 3, 1)),
        (["⌃", "⌘", "⇧", "←"], (1, 0, 2, 1)),
    ]
    start = (1, 0, 2, 1)
    STEP = 1.05
    def scene(img, t):
        i = int(t // STEP) - 1           # first second shows the start state
        u = (t % STEP) / STEP
        prev = start if i <= 0 else steps[i - 1][1]
        if i < 0:
            draw_grid(img, C, R, 0.6)
            draw_window(img, grid_rect(C, R, *start))
            draw_keys(img, ["⌃", "⌘", "⇧", "←→"], 0.0)
            return
        if i >= len(steps):
            draw_grid(img, C, R, 0.6)
            draw_window(img, grid_rect(C, R, *start))
            draw_keys(img, ["⌃", "⌘", "⇧", "←→"], 0.0)
            return
        keys, span = steps[i]
        prev = start if i == 0 else steps[i - 1][1]
        draw_grid(img, C, R, 0.6, grid_rect(C, R, *span), hl_alpha=1 - ease(seg(u, 0.35, 0.9)))
        draw_window(img, lerp_rect(grid_rect(C, R, *prev), grid_rect(C, R, *span), ease(seg(u, 0.12, 0.45))))
        press = 1.0 if u < 0.5 else 1 - ease(seg(u, 0.5, 0.8))
        draw_keys(img, keys, press)
    return scene, STEP * (len(steps) + 2)

if __name__ == "__main__":
    which = sys.argv[1:] or ["drag-snap", "shift-drag", "option-drag", "esc-cancel", "keyboard"]
    for name in which:
        if name == "keyboard":
            sc, dur = keyboard_scene()
        else:
            sc, dur = drag_scene({"drag-snap": "snap", "shift-drag": "shift", "option-drag": "option", "esc-cancel": "esc"}[name])
        render(name, dur, sc)
