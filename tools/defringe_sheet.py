"""Take the last of the green backdrop off a finished sheet (couple under the umbrella, crossing cutscene).

finish_pair_walk.py caps the green on the outlines, so the pale green backdrop mixed into the edges
stays as a ring of olive pixels (R ~ G, B lower) around both of them: a green-yellow frame on the
dark street. punch_sheet.py makes it stronger.

  1. olive pixels touching transparency are backdrop, not character: peeled off (alpha 0), a few rings deep.
  2. olive pixels left inside (the clear umbrella's edge and ribs, a few on the clothes) lose the
     colour cast: a cool grey of the same brightness, like the game's own clear umbrella. Alpha stays.

Usage:
  python3 tools/defringe_sheet.py SHEET.png [OUT.png] --rings 4
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--rings", type=int, default=4, help="how many rings of olive outline to peel")
    args = ap.parse_args()

    img = np.asarray(Image.open(args.src).convert("RGBA")).astype(np.int32)
    r, g, b, a = (img[..., i] for i in range(4))
    olive = (np.abs(r - g) <= 12) & (g - b >= 12) & (r + g + b > 250) & (a > 0)

    peeled = np.zeros_like(olive)
    for _ in range(args.rings):
        ring = olive & ~peeled & ndimage.binary_dilation(img[..., 3] == 0)
        if not ring.any():
            break
        peeled |= ring
        img[ring, 3] = 0

    inside = olive & ~peeled
    lum = img[..., :3].mean(-1)
    tint = np.array([0.95, 0.98, 1.06])
    img[inside, :3] = np.clip(lum[inside, None] * tint, 0, 255).astype(np.int32)
    img[img[..., 3] == 0, :3] = 0

    out = args.out or args.src
    Image.fromarray(img.astype(np.uint8), "RGBA").save(out)
    print(f"{peeled.sum()} outline pixels peeled, {inside.sum()} inside made grey -> {out}")


if __name__ == "__main__":
    main()
