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
    k, c = args.scale, args.collar

    # forward map for a source row at distance d above the collar: local scale
    # g(d) = 1 -> k over the ramp; the output distance is its integral
    d_src = np.arange(0, c + 1, 0.25)
    g = 1 - (1 - k) * np.clip(d_src / args.ramp, 0, 1)
    d_out = np.concatenate([[0], np.cumsum((g[1:] + g[:-1]) / 2 * 0.25)])

    out = np.empty_like(img)
    out[:] = green
    out[c:] = img[c:]
    xs = np.arange(w)
    for y in range(c):
        do = c - y
        if do > d_out[-1]:
            continue                                            # above the shrunk drawing: background
        ds = np.interp(do, d_out, d_src)                        # source distance above the collar
        hs = 1 - (1 - k) * min(ds / args.ramp, 1)               # horizontal scale on that row
        sy = int(round(c - ds))
        sx = np.round(args.neck_x + (xs - args.neck_x) / hs).astype(int)
        ok = (sx >= 0) & (sx < w)
        out[y, ok] = img[sy, sx[ok]]
    Image.fromarray(out).save(args.out)
    print(f"head part scaled by {k} around ({args.neck_x}, {c}); drawing above the collar now "
          f"{d_out[-1]:.0f} px tall (was {c})")


if __name__ == "__main__":
    main()
