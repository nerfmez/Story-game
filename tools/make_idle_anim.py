"""Make the idle (standing) frames from the single idle sprite, no video needed.

Pixel-art breathing with overlapping action, whole pixels only (nothing stretched).
The sprite is cut into bands at quiet rows (hair | head | body | legs) and each pose
moves the bands by whole pixels; where two bands part, the row between is doubled,
where they meet, one row is hidden. Cuts sit at the row that looks most like its
neighbour (in the hair, below the chin, mid-shirt), so the face keeps its exact shape.

Breathing in also widens the chest and arms by 1px on each side: the torso rows
(neck to hands) are split at a quiet column in the middle of the shirt, the left half
moves left and the right half right (the middle column is doubled). Frames get a 1px
margin on both sides for this (so they are 2px wider than the source).

Poses (hair / head / body offsets down in pixels, width +1px per side):
  0 rest              0 0 0
  1 wide (inhale)     0 0 0  wide
  2 shoulders down    0 0 1
  3 head follows      0 1 1   (hair tips lag behind)
  4 down              1 1 1
  5 hair overshoots   2 1 1
  6 shoulders rise    1 1 0   (head still down)
  7 head rises        1 0 0   (hair lags)
then 8-15 are the same poses with the eyes closed.

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


def pose(a, cuts, offsets):
    """Move each band of rows down by its offset. cuts = (hair_end, head_end, body_end);
    rows below body_end stay put. Overlaps hide rows; gaps double the row above."""
    h = a.shape[0]
    bands = [(0, cuts[0]), (cuts[0], cuts[1]), (cuts[1], cuts[2]), (cuts[2], h)]
    offs = list(offsets) + [0]
    out = np.zeros_like(a)
    filled = np.zeros(h, bool)
    for (y0, y1), off in reversed(list(zip(bands, offs))):   # legs first, hair last (on top)
        out[y0 + off:y1 + off] = a[y0:min(y1, h - off)]
        filled[y0 + off:y1 + off] = True
    for y in range(1, h):                                      # gaps: repeat the row above
        if not filled[y] and filled[y - 1]:
            out[y] = out[y - 1]
            filled[y] = True
    return out


def widen(a, top, bottom, col):
    """Rows top..bottom-1: everything left of `col` moves 1px left, everything right of
    it 1px right; column `col` is doubled. Needs a free column at each edge."""
    out = a.copy()
    out[top:bottom, :col] = a[top:bottom, 1:col + 1]
    out[top:bottom, col + 1:] = a[top:bottom, col:-1]
    return out


def quiet_col(a, top, bottom, lo, hi):
    """The column in lo..hi (rows top..bottom) most like its left neighbour."""
    f = a[top:bottom].astype(int)
    cost = [np.abs(f[:, x] - f[:, x - 1]).sum() for x in range(lo, hi)]
    return lo + int(np.argmin(cost))


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
    ap.add_argument("--arms-end", type=int, default=72, help="last row that widens (below the hands)")
    args = ap.parse_args()
    eyes = [tuple(int(v) for v in e.split(",")) for e in args.eyes]

    a = np.asarray(Image.open(args.src).convert("RGBA"))
    a = np.pad(a, ((0, 0), (1, 1), (0, 0)))          # 1px margin each side for widening
    eyes = [(x + 1, y) for x, y in eyes]
    chest = quiet_row(a, *args.chest)
    neck = quiet_row(a, *args.neck)
    hair = quiet_row(a, *args.hair)
    mid = quiet_col(a, neck, args.arms_end, a.shape[1] // 2 - 6, a.shape[1] // 2 + 4)
    wide = widen(a, neck, args.arms_end, mid)
    cuts = (hair, neck, chest)
    poses = [(a, 0), (wide, 0)]
    for o in [(0, 0, 1), (0, 1, 1), (1, 1, 1), (2, 1, 1), (1, 1, 0), (1, 0, 0)]:
        poses.append((pose(a, cuts, o), o[1]))
    frames = [p for p, _ in poses] + [close_eyes(p, [(x, y + dy) for x, y in eyes]) for p, dy in poses]
    print("rows: hair", hair, "neck", neck, "chest", chest, "| middle column", mid)
    h, w = a.shape[:2]
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f, "RGBA"), (i * w, 0))
    sheet.save(args.out)
    print(f"{len(frames)} idle frames of {w}x{h} -> {args.out}")


if __name__ == "__main__":
    main()
