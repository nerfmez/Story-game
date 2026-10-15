"""Make the idle (standing) frames from the single idle sprite, no video needed.

Pixel-art breathing with overlapping action, whole pixels only (nothing stretched):
  0 rest
  1 shoulders 1px down, head still (the neck gains one row)
  2 head follows, hair tips still up (the hair gains one row)
  3 everything 1px down, hair settled (one shirt row hidden under the chest)
then 4-7 are the same four poses with the eyes closed. Every added or hidden row is
the one in its area that looks most like its neighbour, so the face and chin keep
their exact shape and no seam shows.

Usage:
  python3 tools/make_idle_anim.py assets/characters/hero_uniform.png assets/characters/hero_idle.png
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


def drop(a, top, row):
    """Move rows top..row-1 down one pixel (row `row` is covered). Row `top` keeps its
    old content, i.e. it is doubled (top = 0 leaves an empty first row instead)."""
    out = a.copy()
    out[top + 1:row + 1] = a[top:row]
    if top == 0:
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
    ap.add_argument("--neck", type=int, nargs=2, default=(21, 27), metavar=("FROM", "TO"),
                    help="neck/collar rows to choose the doubled row from (below the chin)")
    ap.add_argument("--hair", type=int, nargs=2, default=(3, 9), metavar=("FROM", "TO"),
                    help="hair rows to choose the doubled row from")
    args = ap.parse_args()
    eyes = [tuple(int(v) for v in e.split(",")) for e in args.eyes]

    a = np.asarray(Image.open(args.src).convert("RGBA"))
    chest = quiet_row(a, *args.chest)
    neck = quiet_row(a, *args.neck)
    hair = quiet_row(a, *args.hair)
    shoulders = drop(a, neck, chest)
    head = drop(a, hair, chest)
    down = drop(a, 0, chest)
    poses = [(a, 0), (shoulders, 0), (head, 1), (down, 1)]
    frames = [p for p, _ in poses] + [close_eyes(p, [(x, y + dy) for x, y in eyes]) for p, dy in poses]
    print("rows: hair", hair, "neck", neck, "chest", chest)
    h, w = a.shape[:2]
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f, "RGBA"), (i * w, 0))
    sheet.save(args.out)
    print(f"{len(frames)} idle frames of {w}x{h} -> {args.out}")


if __name__ == "__main__":
    main()
