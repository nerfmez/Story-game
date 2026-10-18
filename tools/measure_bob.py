"""Measure how the couple under the umbrella moves inside their walk sheet and print per-frame corrections.

The clip import aligns every frame by the feet, but the planted foot changes every step, so the upper
body (umbrella, hair) moves irregularly inside the frame:
  - up and down 4-5 px (video noise on top of the step bob)        -> bounce
  - forward and back each step: sideways ~5 px (they walk diagonally) and ~7% bigger / smaller
    -> in the cutscene the ground moves on steadily but the body surges ahead and is pulled back.
Enlarged in the cutscene both read as a jerky walk.

Per frame: upper body row = mean of the umbrella's top row and the top of each one's hair; upper body
column = mean of the umbrella's centre and each one's hair; size = mean of umbrella width and full height
(both relative to their average).
Size and column are held at their average (no surge). The row keeps KEEP of the fitted step bob (one sine,
STEPS bobs per loop) without the noise. Corrections are about the feet (the sprite's anchor):
  SIZE_FIX: scale the drawing by this, about the feet
  SWAY_FIX: then move it this far sideways (px of the sheet, + = right)
  BOB_FIX:  and this far down (px of the sheet, + = down)
Paste the lists into crossing_cutscene.gd.

Usage:
  python3 tools/measure_bob.py assets/characters/pair_umbrella_walk.png --frames 45 --columns 23 --steps 6 --keep 0.3
"""
import argparse

import numpy as np
from PIL import Image


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("--frames", type=int, required=True)
    ap.add_argument("--columns", type=int, required=True)
    ap.add_argument("--width", type=int, default=92)
    ap.add_argument("--height", type=int, default=141)
    ap.add_argument("--feet", default="46,140", help="sprite anchor in the frame (x,y)")
    ap.add_argument("--steps", type=int, default=6, help="steps (bobs) in one loop of the sheet")
    ap.add_argument("--keep", type=float, default=0.3, help="how much of the fitted up-down bob to keep")
    ap.add_argument("--hair", default="10:45,45:80", help="column ranges of each one's hair")
    ap.add_argument("--canopy-rows", type=int, default=30, help="rows from the top that hold the umbrella")
    args = ap.parse_args()

    img = np.asarray(Image.open(args.sheet).convert("RGBA")).astype(np.int32)
    hair = [tuple(int(v) for v in r.split(":")) for r in args.hair.split(",")]
    fx, fy = (float(v) for v in args.feet.split(","))
    rows, cols, sizes = [], [], []
    for i in range(args.frames):
        y, x = (i // args.columns) * args.height, (i % args.columns) * args.width
        f = img[y:y + args.height, x:x + args.width]
        alpha = f[..., 3]
        dark = (alpha > 200) & (f[..., :3].sum(-1) < 150)
        used = np.nonzero(alpha.max(1) > 0)[0]
        canopy = np.nonzero((alpha[:args.canopy_rows] > 0).any(0))[0]
        tops = [used.min()] + [np.nonzero(dark[:, a:b].any(1))[0].min() for a, b in hair]
        centres = [(canopy.min() + canopy.max()) / 2.0]
        for a, b in hair:
            ys, xs = np.nonzero(dark[15:50, a:b])
            centres.append(xs.mean() + a)
        rows.append(np.mean(tops))
        cols.append(np.mean(centres))
        sizes.append((canopy.max() - canopy.min(), used.max() - used.min()))
    rows, cols, sizes = np.array(rows), np.array(cols), np.array(sizes, float)
    size = (sizes / sizes.mean(0)).mean(1)

    t = np.arange(args.frames) * 2.0 * np.pi * args.steps / args.frames
    basis = np.stack([np.ones_like(t), np.cos(t), np.sin(t)], 1)
    coef = np.linalg.lstsq(basis, rows, rcond=None)[0]
    target_row = coef[0] + args.keep * (basis @ coef - coef[0])
    target_col = cols.mean()

    size_fix = 1.0 / size
    # after scaling about the feet, where the upper body is; then move it onto the targets
    row_scaled = fy - (fy - rows) * size_fix
    col_scaled = fx + (cols - fx) * size_fix
    bob_fix = (target_row - row_scaled) / size_fix
    sway_fix = (target_col - col_scaled) / size_fix

    jump = lambda r: np.abs(np.diff(np.append(r, r[0]))).mean()
    print(f"up-down: mean jump {jump(rows):.2f} px -> {jump(target_row):.2f} px")
    print(f"sideways: range {np.ptp(cols):.1f} px, mean jump {jump(cols):.2f} px -> 0")
    print(f"size: range {100 * np.ptp(size):.1f}%, mean jump {100 * jump(size):.2f}% -> 0")
    fmt = lambda v, d: ", ".join(f"{x:.{d}f}" for x in v)
    print("const SIZE_FIX := [" + fmt(size_fix, 3) + "]")
    print("const SWAY_FIX := [" + fmt(sway_fix, 1) + "]")
    print("const BOB_FIX := [" + fmt(bob_fix, 1) + "]")


if __name__ == "__main__":
    main()
