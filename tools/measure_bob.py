"""Measure the up-down bounce of a walk sheet and print a per-frame correction (couple under the umbrella).

The clip import aligns every frame by the feet, but the upper body then jumps 4-5 px from frame to
frame, irregularly (video noise, the clear umbrella's top edge, hair). Enlarged in the cutscene it
reads as bouncing. The real walk has a smooth bob, one up-down per step.

Per frame: upper body row = mean of the umbrella's top row and the top of each one's hair.
Fit one sine with STEPS bobs per loop (the step bob), keep KEEP of it, and print for every frame
how far to move the drawing (pixels, + = down) to put the upper body on that smooth curve.
Paste the list into crossing_cutscene.gd (BOB_FIX).

Usage:
  python3 tools/measure_bob.py assets/characters/pair_umbrella_walk.png --frames 45 --columns 23 --steps 6 --keep 0.6
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
    ap.add_argument("--steps", type=int, default=6, help="steps (bobs) in one loop of the sheet")
    ap.add_argument("--keep", type=float, default=0.6, help="how much of the fitted bob to keep")
    ap.add_argument("--hair", default="15:45,45:75", help="column ranges of each one's hair")
    args = ap.parse_args()

    img = np.asarray(Image.open(args.sheet).convert("RGBA")).astype(np.int32)
    hair = [tuple(int(v) for v in r.split(":")) for r in args.hair.split(",")]
    rows = []
    for i in range(args.frames):
        y, x = (i // args.columns) * args.height, (i % args.columns) * args.width
        f = img[y:y + args.height, x:x + args.width]
        alpha = f[..., 3]
        dark = (alpha > 200) & (f[..., :3].sum(-1) < 150)
        tops = [np.nonzero(alpha.max(1) > 0)[0].min()]
        tops += [np.nonzero(dark[:, a:b].any(1))[0].min() for a, b in hair]
        rows.append(np.mean(tops))
    rows = np.array(rows)

    t = np.arange(args.frames) * 2.0 * np.pi * args.steps / args.frames
    basis = np.stack([np.ones_like(t), np.cos(t), np.sin(t)], 1)
    coef = np.linalg.lstsq(basis, rows, rcond=None)[0]
    bob = basis @ coef - coef[0]
    target = coef[0] + args.keep * bob
    fix = target - rows
    jump = lambda r: np.abs(np.diff(np.append(r, r[0]))).mean()
    print(f"bob {2 * np.hypot(coef[1], coef[2]):.1f} px peak to peak, jitter around it {np.std(rows - coef[0] - bob):.2f} px")
    print(f"mean jump between frames {jump(rows):.2f} px -> {jump(rows + fix):.2f} px")
    print("const BOB_FIX := [" + ", ".join(f"{v:.1f}" for v in fix) + "]")


if __name__ == "__main__":
    main()
