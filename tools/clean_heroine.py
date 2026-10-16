"""Clean up a character sprite imported at a reduced height with import_sprite.py --height.

The heroine's art has a thin ahoge and loose strands drawn thinner than one art pixel,
so sampling the middle of each cell breaks them into floating specks, and a few dark
edge pixels keep a green-screen tint. This:
  - rebuilds what sticks out above the head (the ahoge): a pixel is hair wherever the
    dark line crosses its cell in the source, and specks without a line are removed
  - turns teal-tinted pixels on the outer edge of the head (above the shoulders, where
    nothing teal belongs) into dark hair colour
  - drops pixels with no neighbour at all

Usage:
  python3 tools/import_sprite.py art_source/heroine_greenscreen.png assets/characters/heroine.png --height 112
  python3 tools/clean_heroine.py art_source/heroine_greenscreen.png assets/characters/heroine.png
"""
import argparse

import numpy as np
from PIL import Image

from import_sprite import is_green


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("sprite", help="imported sprite, cleaned in place")
    args = ap.parse_args()
    src = np.asarray(Image.open(args.src).convert("RGB")).astype(int)
    spr = np.asarray(Image.open(args.sprite).convert("RGBA")).astype(int).copy()
    h, w = spr.shape[:2]
    fig = ~is_green(src)
    ys, xs = np.nonzero(fig)
    top, block = ys.min(), (ys.max() - ys.min() + 1) / h
    op = spr[..., 3] > 0

    # where the sprite's column 0 lies in the source: best match of the silhouettes
    rows = [int(top + (j + 0.5) * block) for j in range(h)]
    best = None
    for x0 in np.arange(xs.min() - block, xs.min() + block, 0.25):
        cols = np.clip((x0 + (np.arange(w) + 0.5) * block).astype(int), 0, src.shape[1] - 1)
        err = (fig[np.ix_(rows, cols)] != op).sum()
        if best is None or err < best[0]:
            best = (err, x0)
    x0 = best[1]

    # ahoge: rows above the hair mass
    mass = next(j for j in range(h) if op[j].sum() >= 6)
    dark = (src.sum(2) < 330) & fig
    for j in range(mass):
        for i in range(w):
            ya, yb = int(top + j * block), int(top + (j + 1) * block)
            xa, xb = int(x0 + i * block), int(x0 + (i + 1) * block)
            if dark[ya:yb, xa:xb].sum() >= block * 0.9:      # the line crosses this cell
                spr[j, i] = (34, 26, 36, 255)
            elif op[j, i]:
                spr[j, i, 3] = 0                             # speck with no line

    # green-screen tint on the outer edge of the head and hair
    rgb = spr[..., :3]
    s = spr[..., 3] > 0
    edge = s & ~(np.roll(s, 1, 0) & np.roll(s, -1, 0) & np.roll(s, 1, 1) & np.roll(s, -1, 1))
    teal = (rgb[..., 1] > rgb[..., 0] + 12) & (rgb.sum(-1) < 330)
    shoulders = next(j for j in range(h) if s[j].sum() >= 0.8 * w)
    tint = edge & teal
    tint[shoulders:] = False
    rgb[tint] = (40, 30, 42)

    # pixels with no neighbour
    s = spr[..., 3] > 0
    n = sum(np.roll(np.roll(s, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    lone = s & (n == 0)
    spr[lone] = 0
    Image.fromarray(spr.astype(np.uint8), "RGBA").save(args.sprite)
    print(f"x0={x0:.2f} hair from row {mass}; {int(tint.sum())} tinted edge pixels, {int(lone.sum())} lone pixels fixed")


if __name__ == "__main__":
    main()
