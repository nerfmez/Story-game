"""Rain versions of the heroine's sheets: soaked clothes and hair, fogged-up glasses.

  - fogged glasses: the lenses are given as boxes on the sheet's first frame (--lens,
    read off a zoomed frame: the rows of the eyes, between the rims). At 112px the red
    frame of the glasses is broken into a few pixels, too few to find the lenses in every
    frame, so instead each frame's head is lined up with the first frame's (the shift
    that best matches the head and face rows) and the boxes move with it. Inside them
    the pixels are covered with misty white: the eyes vanish behind the fog.
  - soaked: wet cloth and hair are darker and a little richer in colour; skin, the
    white trim and the shoes keep their colours (the trim just a touch greyer)

Usage:
  python3 tools/wet_heroine.py assets/characters/heroine_idle.png 50 \
      assets/characters/heroine_idle_wet.png --lens 16 18 17 18 --lens 21 24 17 18
  python3 tools/wet_heroine.py assets/characters/heroine_walk.png 18 \
      assets/characters/heroine_walk_wet.png --lens 19 21 19 20 --lens 25 27 19 20
"""
import argparse

import numpy as np
from PIL import Image

FOG = np.array((214, 222, 228.0))


def head_shift(ref, f, rows=(8, 26), reach=3):
    """(dy, dx) that lays frame f's head on the reference frame's."""
    best = None
    a = ref.astype(float)
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            g = np.roll(np.roll(f.astype(float), -dy, 0), -dx, 1)
            err = np.abs(a[rows[0]:rows[1]] - g[rows[0]:rows[1]]).mean()
            if best is None or err < best[0]:
                best = (err, dy, dx)
    return best[1], best[2]


def fog(f, boxes, shift, fog_amount=0.8):
    f = f.copy()
    dy, dx = shift
    for x0, x1, y0, y1 in boxes:
        for y in range(y0 + dy, y1 + dy + 1):
            for x in range(x0 + dx, x1 + dx + 1):
                if f[y, x, 3] > 0:
                    f[y, x, :3] = np.round(f[y, x, :3] * (1 - fog_amount) + FOG * fog_amount)
    return f


def soak(f):
    f = f.copy().astype(float)
    op = f[..., 3] > 0
    rgb = f[..., :3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mn = rgb.min(2)
    skin = (r > 170) & (r > g + 20) & (g > b) & (mn <= 170)
    white = mn > 170
    lum = rgb @ np.array((0.299, 0.587, 0.114))
    rich = lum[..., None] + (rgb - lum[..., None]) * 1.12
    wet = np.clip(rich * 0.8, 0, 255)
    trim = rgb * 0.93
    out = np.where(skin[..., None], rgb, np.where(white[..., None], trim, wet))
    f[..., :3] = np.where(op[..., None], out, rgb)
    return f.round().astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("frames", type=int)
    ap.add_argument("out")
    ap.add_argument("--lens", nargs=4, type=int, action="append", required=True,
                    metavar=("X0", "X1", "Y0", "Y1"), help="a lens on the first frame (inclusive)")
    args = ap.parse_args()
    a = np.asarray(Image.open(args.sheet).convert("RGBA"))
    w = a.shape[1] // args.frames
    frames = [a[:, i * w:(i + 1) * w] for i in range(args.frames)]
    shifts = [head_shift(frames[0], f) for f in frames]
    print("head shifts", shifts)
    frames = [soak(fog(f, args.lens, s)) for f, s in zip(frames, shifts)]
    Image.fromarray(np.concatenate(frames, 1), "RGBA").save(args.out)
    print("written", args.out)


if __name__ == "__main__":
    main()
