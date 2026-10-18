"""Make sprite sheets less washed out: deeper darks and a little more colour.

Each solid pixel (alpha >= 250; the see-through umbrella keeps its colour) goes through
one smooth curve per channel, c -> 255 * (c / 255) ** gamma (darks and mid-tones get
deeper, whites stay white), then its saturation is scaled around its own brightness.
The same function for every pixel and every sheet, so shading keeps its shape and all
the sheets stay the same tone as each other.

Usage:
  python3 tools/punch_sheet.py --gamma 1.15 --saturation 1.15 SHEET.png [SHEET.png ...]
"""
import argparse

import numpy as np
from PIL import Image


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheets", nargs="+")
    ap.add_argument("--gamma", type=float, default=1.15)
    ap.add_argument("--saturation", type=float, default=1.15)
    args = ap.parse_args()
    for path in args.sheets:
        a = np.asarray(Image.open(path).convert("RGBA")).astype(float)
        op = a[..., 3] >= 250
        rgb = 255 * (a[..., :3][op] / 255) ** args.gamma
        lum = rgb @ np.array((0.299, 0.587, 0.114))
        rgb = lum[:, None] + (rgb - lum[:, None]) * args.saturation
        a[..., :3][op] = np.clip(rgb, 0, 255)
        Image.fromarray(a.round().astype(np.uint8), "RGBA").save(path)
        print("written", path)


if __name__ == "__main__":
    main()
