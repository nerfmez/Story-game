"""Keep the head and shoulders of a walk sheet at one height in every frame.

The walk video's upper body pops up 2-3px in single frames (right after a step), so
in game the character looked like it bounced. For each frame this finds how far its
head and chest (rows 4..60) sit from the median of all frames, then moves only the
band above a cut in the plain middle of the shirt by that much: moving down hides
a few shirt rows at the cut, moving up repeats them. The cut is the run of rows
that looks most like its neighbours, so the seam doesn't show; legs, feet and the
ground line are untouched.

Usage:
  python3 tools/steady_walk_head.py assets/characters/hero_walk.png --frames 15
"""
import argparse

import numpy as np
from PIL import Image


def offset(ref, f, y0=4, y1=60, reach=5):
    """Rows (dy) and columns (dx) to move f by so its head and chest match ref."""
    best = None
    for dy in range(-reach, reach + 1):
        for dx in range(-3, 4):
            g = np.roll(np.roll(f, dy, 0), dx, 1)
            err = np.abs(ref[y0:y1] - g[y0:y1]).mean()
            if best is None or err < best[0]:
                best = (err, dy, dx)
    return best[1]


def cut_row(f, lo, hi, n):
    """Start of the n rows in lo..hi whose loss/doubling is least visible."""
    cost = []
    for y in range(lo, hi - n):
        cost.append(sum(np.abs(f[y + k, :, :3] - f[y + k - 1, :, :3]).sum()
                        + 400 * np.abs(f[y + k, :, 3] - f[y + k - 1, :, 3]).sum() / 255
                        for k in range(max(1, n))))
    return lo + int(np.argmin(cost))


def steady(f, dy, lo, hi):
    if dy == 0:
        return f
    # the hidden rows (moving down) start at the cut; the repeated ones (moving up) end there
    cut = cut_row(f, lo, hi, abs(dy)) + (abs(dy) if dy < 0 else 0)
    out = f.copy()
    if dy > 0:                     # upper band down: rows cut..cut+dy of the lower part hidden
        out[dy:cut + dy] = f[:cut]
        out[:dy] = 0
    else:                          # upper band up: rows at the cut appear twice
        out[:cut + dy] = f[-dy:cut]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("--frames", type=int, required=True)
    ap.add_argument("--cut", type=int, nargs=2, default=(38, 62), metavar=("FROM", "TO"),
                    help="shirt rows to cut in (below the chest, above the hem)")
    ap.add_argument("--out", help="default: overwrite the sheet")
    args = ap.parse_args()

    a = np.asarray(Image.open(args.sheet).convert("RGBA")).astype(int)
    w = a.shape[1] // args.frames
    frames = [a[:, i * w:(i + 1) * w] for i in range(args.frames)]
    ref = np.median(np.stack(frames), 0)
    shifts = [offset(ref, f) for f in frames]
    print("upper body moved by", shifts)
    out = np.concatenate([steady(f, dy, *args.cut) for f, dy in zip(frames, shifts)], 1)
    Image.fromarray(out.astype(np.uint8), "RGBA").save(args.out or args.sheet)


if __name__ == "__main__":
    main()
