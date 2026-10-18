"""Shrink (or grow) everything above the collar of a character drawing, around the neck.

AI image tools asked for a new pose (e.g. holding an umbrella) often keep the head the
same size but draw the body smaller, so the head looks too big. Measure the reference
and the new drawing (collar -> feet, hair top -> collar) and pass the factor that brings
the head back in proportion. The change ramps in over --ramp px above the collar (no
seam: things that cross the collar line, like an umbrella shaft, stay continuous) and
is constant above that. The body below the collar is untouched. Sampling is nearest-
neighbour, so the pixel-art blocks stay hard-edged; the background is green screen.

Usage:
  python3 tools/fix_head_size.py SRC.png OUT.png --collar 387 --neck-x 615 --scale 0.91
"""
import argparse

import numpy as np
from PIL import Image


def head_map(h, w, collar, neck_x, k, ramp=120):
    """Source (row, col) to read for every output pixel when everything above `collar`
    is scaled by k around (neck_x, collar), ramping in over `ramp` rows. Rows that end up
    above the shrunk drawing get -1 (background)."""
    d_src = np.arange(0, collar + 1, 0.25)
    g = 1 - (1 - k) * np.clip(d_src / ramp, 0, 1)
    d_out = np.concatenate([[0], np.cumsum((g[1:] + g[:-1]) / 2 * 0.25)])
    sy = np.tile(np.arange(h)[:, None], (1, w))
    sx = np.tile(np.arange(w)[None, :], (h, 1))
    xs = np.arange(w)
    for y in range(collar):
        do = collar - y
        if do > d_out[-1]:
            sy[y] = -1
            continue
        ds = np.interp(do, d_out, d_src)
        hs = 1 - (1 - k) * min(ds / ramp, 1)
        sy[y] = int(round(collar - ds))
        sx[y] = np.round(neck_x + (xs - neck_x) / hs).astype(int)
    bad = (sy < 0) | (sx < 0) | (sx >= w)
    return sy, sx, bad


def apply_map(img, sy, sx, bad, fill):
    out = img[np.clip(sy, 0, img.shape[0] - 1), np.clip(sx, 0, img.shape[1] - 1)]
    out[bad] = fill
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--collar", type=int, required=True, help="first row of the shirt collar")
    ap.add_argument("--neck-x", type=float, required=True, help="x of the neck (centre of the change)")
    ap.add_argument("--scale", type=float, required=True, help="size of the head part afterwards (0.91 = 9%% smaller)")
    ap.add_argument("--ramp", type=float, default=120, help="rows above the collar over which the change ramps in")
    args = ap.parse_args()

    img = np.asarray(Image.open(args.src).convert("RGB"))
    h, w = img.shape[:2]
    green = np.median(img[:20, :20].reshape(-1, 3), axis=0)
    sy, sx, bad = head_map(h, w, args.collar, args.neck_x, args.scale, args.ramp)
    out = apply_map(img, sy, sx, bad, green)
    Image.fromarray(out).save(args.out)
    print(f"head part scaled by {args.scale} around ({args.neck_x}, {args.collar})")


if __name__ == "__main__":
    main()
