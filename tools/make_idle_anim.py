"""Make the idle (standing) frames from the single idle sprite, no video needed.

Output: 2 frames side by side, the same size as the input:
  0 eyes open, 1 eyes closed (for blinks)

Breathing is not drawn into frames (moving whole pixel rows looks jerky and can
duplicate rows, e.g. square off the chin); shaders/breathe.gdshader does it smoothly
in the game.

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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--eyes", nargs="+", default=["11,15", "12,15", "17,15", "18,15"],
                    help="x,y of the eye pixels (the white glint and the iris)")
    args = ap.parse_args()
    eyes = [tuple(int(v) for v in e.split(",")) for e in args.eyes]

    a = np.asarray(Image.open(args.src).convert("RGBA"))
    frames = [a, close_eyes(a, eyes)]
    h, w = a.shape[:2]
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f, "RGBA"), (i * w, 0))
    sheet.save(args.out)
    print(f"{len(frames)} idle frames of {w}x{h} -> {args.out}")


if __name__ == "__main__":
    main()
