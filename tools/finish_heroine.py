"""Finish the heroine's idle and walk sheets after import_char_video.py --keep-colours.

  - magenta fringe: thin hair strands and outline pixels mixed with the magenta
    background (red and blue both well above green: no colour of hers is like that, even the
    red soles have little blue) are
    dropped on the outline, and inside take the median of their plain neighbours
  - specks: a hair strand thinner than a game pixel (the ahoge) samples as a few loose
    pixels floating above the head; anything not joined to the body (8-connected) and
    smaller than 6 pixels is dropped
  - colours: the clips were made from the still's own art, so their colours are already
    close (the tracksuit a little less blue). Each sheet gets one affine colour function,
    fitted so the average colour of each material (white trim and shoes, skin, green
    tracksuit, dark hair and outline, red glasses and soles) lands on the still's.
    Whole-colour functions keep the shading's shape (no blotches); fitting on material
    averages rather than laying a frame over the still keeps the whites white

Usage:
  python3 tools/finish_heroine.py IDLE.png 50 WALK.png 18 \\
      --still assets/characters/heroine.png --out-idle ... --out-walk ...
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))


def split(path, n):
    a = np.asarray(Image.open(path).convert("RGBA")).copy()
    w = a.shape[1] // n
    return [a[:, i * w:(i + 1) * w].copy() for i in range(n)]


def magenta_cast(f):
    r, g, b = (f[..., i].astype(int) for i in range(3))
    return (f[..., 3] > 0) & (r > g + 40) & (b > g + 35)


def defringe(f):
    f = f.copy()
    for _ in range(3):
        bad = magenta_cast(f)
        if not bad.any():
            break
        op = f[..., 3] > 0
        pad = np.pad(op, 1)
        edge = ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
        f[bad & edge, 3] = 0
        for y, x in zip(*np.nonzero(bad & ~edge)):
            win = f[max(0, y - 1):y + 2, max(0, x - 1):x + 2].reshape(-1, 4)
            good = win[(win[:, 3] > 0) & ~magenta_cast(win[None])[0]]
            if len(good):
                f[y, x, :3] = np.median(good[:, :3], 0)
            else:
                f[y, x, 3] = 0
    return f


def drop_specks(f, size=6):
    op = f[..., 3] > 0
    seen = np.zeros(op.shape, bool)
    h, w = op.shape
    f = f.copy()
    for y, x in zip(*np.nonzero(op)):
        if seen[y, x]:
            continue
        part, stack = [], [(y, x)]
        seen[y, x] = True
        while stack:
            cy, cx = stack.pop()
            part.append((cy, cx))
            for ny in range(max(0, cy - 1), min(h, cy + 2)):
                for nx in range(max(0, cx - 1), min(w, cx + 2)):
                    if op[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        if len(part) < size:
            for cy, cx in part:
                f[cy, cx, 3] = 0
    return f


def materials(px):
    r, g, b = px.T
    mn = px.min(1)
    lum = px @ np.array((0.299, 0.587, 0.114))
    return {
        "white": mn > 170,
        "skin": (r > 170) & (r > g + 20) & (g > b) & (mn <= 170),
        "green": (g > r + 15) & (g >= b - 5),
        "dark": (lum < 70) & ~(g > r + 15),
        "red": (r > g + 60) & (r > b + 30) & (r < 200),
    }


def colour_fit(frames, still):
    src = np.concatenate([f[..., :3][f[..., 3] > 0] for f in frames]).astype(float)
    ref = still[..., :3][still[..., 3] > 0].astype(float)
    ms, mr = materials(src), materials(ref)
    rows, targets, weights = [], [], []
    for name in ms:
        rows.append(np.r_[src[ms[name]].mean(0), 1])
        targets.append(ref[mr[name]].mean(0))
        weights.append(np.sqrt(mr[name].sum()) * (3 if name == "skin" else 1))
    W = np.array(weights)[:, None]
    A, *_ = np.linalg.lstsq(np.array(rows) * W, np.array(targets) * W, rcond=None)
    out = []
    for f in frames:
        g = f.copy()
        op = g[..., 3] > 0
        g[..., :3][op] = np.clip(np.c_[g[..., :3][op].astype(float), np.ones(op.sum())] @ A, 0, 255).round()
        out.append(g)
    return out


def save(frames, path):
    Image.fromarray(np.concatenate(frames, 1), "RGBA").save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("idle")
    ap.add_argument("idle_frames", type=int)
    ap.add_argument("walk")
    ap.add_argument("walk_frames", type=int)
    ap.add_argument("--still", default="assets/characters/heroine.png")
    ap.add_argument("--out-idle", required=True)
    ap.add_argument("--out-walk", required=True)
    args = ap.parse_args()

    idle = [drop_specks(defringe(f)) for f in split(args.idle, args.idle_frames)]
    walk = [drop_specks(defringe(f)) for f in split(args.walk, args.walk_frames)]
    still = np.asarray(Image.open(args.still).convert("RGBA"))
    save(colour_fit(idle, still), args.out_idle)
    save(colour_fit(walk, still), args.out_walk)
    print("written", args.out_idle, args.out_walk)


if __name__ == "__main__":
    main()
