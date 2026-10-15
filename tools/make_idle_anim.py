"""Make an idle (standing) animation sheet from the single idle sprite, no video needed.

Breathing is the classic pixel-art trick: part of the body moves down 1px and the
rows below it squash. Shoulders go first, the head follows a beat later (overlapping
action), then both come back up. Every pose also has an eyes-closed copy for blinks.

Output: one row of frames, each the same size as the input:
  0 rest, 1 shoulders down, 2 shoulders + head down,
  3-5 the same three poses with the eyes closed

Usage:
  python3 tools/make_idle_anim.py assets/characters/hero_uniform.png assets/characters/hero_idle.png \\
      --neck 20 --waist 50 --eyes 11,15 12,15 17,15 18,15
"""
import argparse

import numpy as np
from PIL import Image


def shift_down(a, top, bottom):
    """Move rows top..bottom-1 down by one pixel; row `bottom` is covered, row `top`
    keeps a copy of itself (top = 0 leaves an empty first row)."""
    out = a.copy()
    out[top + 1:bottom + 1] = a[top:bottom]
    if top == 0:
        out[0] = 0
    return out


def close_eyes(a, eyes, dy):
    """Eyes shut: the eye pixels become a dark lid line, the lashes above turn to
    shaded skin."""
    out = a.copy()
    lid = np.array([74, 30, 52, 255])
    shade = np.array([236, 128, 104, 255])
    for x, y in eyes:
        y += dy
        out[y, x] = lid
        if out[y - 1, x, 0] < 120:          # dark lash pixel above the eye
            out[y - 1, x] = shade
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--neck", type=int, default=20, help="first row of the shoulders")
    ap.add_argument("--waist", type=int, default=50, help="row where the breathing squash happens")
    ap.add_argument("--eyes", nargs="+", default=["11,15", "12,15", "17,15", "18,15"],
                    help="x,y of the eye pixels (the white glint and the iris)")
    args = ap.parse_args()
    eyes = [tuple(int(v) for v in e.split(",")) for e in args.eyes]

    a = np.asarray(Image.open(args.src).convert("RGBA"))
    rest = a
    shoulders = shift_down(a, args.neck, args.waist)
    both = shift_down(a, 0, args.waist)
    poses = [(rest, 0), (shoulders, 0), (both, 1)]
    frames = [p for p, _ in poses] + [close_eyes(p, eyes, dy) for p, dy in poses]

    h, w = a.shape[:2]
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f, "RGBA"), (i * w, 0))
    sheet.save(args.out)
    print(f"{len(frames)} idle frames of {w}x{h} -> {args.out}")


if __name__ == "__main__":
    main()
