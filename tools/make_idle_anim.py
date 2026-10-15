"""Make the idle (standing) frames from the single idle sprite, no video needed.

Pixel-art breathing: the head and shoulders drop by exactly one pixel as a rigid
block (nothing is stretched or duplicated, so the face keeps its shape); one row of
the shirt disappears under them. The script picks the shirt row that looks most like
the row above it, so the missing row doesn't show.

Output: 4 frames side by side, the same size as the input:
  0 rest, 1 breathed out (upper body 1px lower), 2 and 3 the same with eyes closed

Usage:
  python3 tools/make_idle_anim.py assets/characters/hero_uniform.png assets/characters/hero_idle.png \\
      --eyes 11,15 12,15 17,15 18,15
"""
import argparse

import numpy as np
from PIL import Image


def close_eyes(a, eyes):
    """Eyes shut: the eye pixels become a dark lid line, the lashes above turn to
    shaded skin."""
    out = a.copy()
    lid = np.array([74, 30, 52, 255])
    shade = np.array([236, 128, 104, 255])
    for x, y in eyes:
        out[y, x] = lid
        if out[y - 1, x, 0] < 120:          # dark lash pixel above the eye
            out[y - 1, x] = shade
    return out


def drop_upper(a, row):
    """Move every row above `row` down one pixel; `row` itself is covered."""
    out = a.copy()
    out[1:row + 1] = a[0:row]
    out[0] = 0
    return out


def quiet_row(a, lo, hi):
    """The row in lo..hi that differs least from the row above it (its loss is invisible)."""
    f = a.astype(int)
    cost = [np.abs(f[y, :, :3] - f[y - 1, :, :3]).sum() + 400 * np.abs(f[y, :, 3] - f[y - 1, :, 3]).sum() / 255
            for y in range(lo, hi)]
    return lo + int(np.argmin(cost))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--eyes", nargs="+", default=["11,15", "12,15", "17,15", "18,15"],
                    help="x,y of the eye pixels (the white glint and the iris)")
    ap.add_argument("--chest", type=int, nargs=2, default=(36, 56), metavar=("FROM", "TO"),
                    help="shirt rows to choose the hidden row from")
    args = ap.parse_args()
    eyes = [tuple(int(v) for v in e.split(",")) for e in args.eyes]

    a = np.asarray(Image.open(args.src).convert("RGBA"))
    row = quiet_row(a, *args.chest)
    down = drop_upper(a, row)
    frames = [a, down, close_eyes(a, eyes), close_eyes(down, [(x, y + 1) for x, y in eyes])]
    print("hidden row", row)
    h, w = a.shape[:2]
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f, "RGBA"), (i * w, 0))
    sheet.save(args.out)
    print(f"{len(frames)} idle frames of {w}x{h} -> {args.out}")


if __name__ == "__main__":
    main()
