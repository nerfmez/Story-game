"""Give a sheet the colours of other sheets of the same characters (couple under the umbrella -> standing sheets).

Unlike match_sheet_colours.py (lays one frame over a frame of the same character in a similar pose),
this works across different poses and two characters in one sheet.

The crossing cutscene swaps the game's standing hero + heroine for the couple's walk sheet. The walk
sheet came from another clip and was punched differently: shirt pinker, skin and tracksuit darker,
so the swap shows a colour jump. The poses differ, so pixels can't be paired up (apply_colour_fit.py);
instead the same materials are found in both (shirt, tracksuit, skin, hair/outline, dark shading) by
colour, and one smooth curve per channel (quadratic, black and white kept) is fitted through their
medians and applied to the sheet's solid pixels. See-through pixels (the clear umbrella) keep their colour.

Usage:
  python3 tools/match_material_colours.py SHEET.png OUT.png --to assets/characters/hero_umbrella_idle.png \
      assets/characters/heroine_idle_wet.png
"""
import argparse

import numpy as np
from PIL import Image


def materials(px):
    lum = px.mean(1)
    r, g, b = px[:, 0], px[:, 1], px[:, 2]
    return {
        "shirt": (lum > 165) & (b >= r - 5),
        "tracksuit": (g > r + 15) & (b > r + 10) & (lum < 130) & (lum > 40),
        "skin": (r > g + 30) & (r > b + 15) & (lum > 110) & (lum < 210),
        "hair": lum < 45,
        "shading": (lum >= 45) & (lum < 75) & (np.abs(r - b) < 25),
    }


def solid(path):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    return a[a[..., 3] >= 250][:, :3]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("out")
    ap.add_argument("--to", nargs="+", required=True, help="sheets whose colours to take")
    args = ap.parse_args()

    src = solid(args.sheet)
    ref = np.concatenate([solid(p) for p in args.to])
    ms, mr = materials(src), materials(ref)
    names = list(ms)
    a = np.array([np.median(src[ms[k]], 0) for k in names])
    b = np.array([np.median(ref[mr[k]], 0) for k in names])
    curves = []
    for c in range(3):
        x = np.concatenate([[0.0, 255.0], a[:, c]])
        y = np.concatenate([[0.0, 255.0], b[:, c]])
        w = np.concatenate([[3.0, 3.0], np.ones(len(names))])
        curves.append(np.polyfit(x, y, 2, w=w))

    img = np.asarray(Image.open(args.sheet).convert("RGBA")).astype(float)
    op = img[..., 3] >= 250
    for c in range(3):
        ch = img[..., c]
        ch[op] = np.clip(np.polyval(curves[c], ch[op]), 0, 255)
    Image.fromarray(img.round().astype(np.uint8), "RGBA").save(args.out)

    after = np.array([np.clip([np.polyval(curves[c], a[i, c]) for c in range(3)], 0, 255) for i in range(len(names))])
    for i, k in enumerate(names):
        print(f"{k:9s} {a[i].round().astype(int)} -> {after[i].round().astype(int)}  (target {b[i].round().astype(int)})")
    print("written", args.out)


if __name__ == "__main__":
    main()
