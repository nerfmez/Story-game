"""Turn an upscaled pixel-art image on a green screen into a clean game sprite.

AI image tools usually output "pixel art" upscaled to ~1024-1254px with soft
edges. This script:
  1. finds the size of one art pixel (or uses --block),
  2. samples each block at its centre (median) to get the true low-res pixels,
  3. removes the green screen and green fringes (chroma key + despill),
  4. trims empty space and saves a PNG with transparency.

Usage:
  python3 tools/import_sprite.py SRC.png assets/characters/NAME.png [--block 8.5 | --height 112]
"""
import argparse

import numpy as np
from PIL import Image


def is_green(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (g > 140) & (g > r * 1.6) & (g > b * 1.6)


def estimate_block(rgb):
    """Most common spacing between colour edges inside the subject."""
    mask = ~is_green(rgb)
    ys, xs = np.where(mask)
    sub = rgb[ys.min():ys.max(), xs.min():xs.max()].astype(int)
    best = []
    for axis in (0, 1):
        edges = (np.abs(np.diff(sub, axis=axis)).sum(2) > 30).sum(axis=1 - axis).astype(float)
        edges -= edges.mean()
        scores = {}
        # Search fractional block sizes: score = how well edges line up on a grid
        for step in np.arange(4.0, 16.01, 0.05):
            idx = np.arange(0, len(edges) - 1, step)
            phases = []
            for phase in np.arange(0, step, 0.5):
                pos = np.clip(np.round(idx + phase).astype(int), 0, len(edges) - 1)
                phases.append(edges[pos].mean())
            scores[round(step, 2)] = max(phases) - np.mean(phases)
        best.append(max(scores, key=scores.get))
    return float(np.mean(best))


def find_phase(rgb, block):
    """Grid offset where block boundaries best match colour edges."""
    edges_x = (np.abs(np.diff(rgb.astype(int), axis=1)).sum(2) > 30).sum(0)
    edges_y = (np.abs(np.diff(rgb.astype(int), axis=0)).sum(2) > 30).sum(1)
    def best(edges):
        scores = []
        for phase in np.arange(0, block, 0.25):
            pos = np.round(np.arange(phase, len(edges), block)).astype(int)
            pos = pos[pos < len(edges)]
            scores.append((edges[pos].mean(), phase))
        return max(scores)[1]
    return best(edges_x), best(edges_y)


def downsample(rgb, block, phase):
    h, w, _ = rgb.shape
    px, py = phase
    cols = int((w - px) // block)
    rows = int((h - py) // block)
    out = np.zeros((rows, cols, 3), dtype=np.uint8)
    q = max(1, int(block * 0.25))
    for j in range(rows):
        cy = int(py + (j + 0.5) * block)
        for i in range(cols):
            cx = int(px + (i + 0.5) * block)
            patch = rgb[max(0, cy - q):cy + q + 1, max(0, cx - q):cx + q + 1].reshape(-1, 3)
            out[j, i] = np.median(patch, axis=0)
    return out


def key_out(small):
    rgb = small.astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    alpha = np.where(is_green(rgb), 0, 255)
    # Fringe pixels: still greenish after keying -> pull green down to the other channels
    spill = (g > r) & (g > b) & (alpha > 0)
    rgb[..., 1] = np.where(spill, np.maximum(r, b), g)
    # Fringe that is mostly green -> drop it
    weak = spill & (g > 120) & (g - np.maximum(r, b) > 60)
    alpha = np.where(weak, 0, alpha)
    return np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--block", type=float, default=0.0, help="size of one art pixel in the source (auto if 0)")
    ap.add_argument("--height", type=int, default=0,
                    help="character height in game pixels: sample with the block that gives this height "
                         "(to match another character's size, e.g. a shorter heroine next to the hero)")
    args = ap.parse_args()

    rgb = np.asarray(Image.open(args.src).convert("RGB"))
    if args.height:
        ys = np.nonzero((~is_green(rgb)).any(1))[0]
        block = (ys.max() - ys.min() + 1) / args.height
    else:
        block = args.block or estimate_block(rgb)
    phase = find_phase(rgb, block)
    small = downsample(rgb, block, phase)
    rgba = key_out(small)
    img = Image.fromarray(rgba, "RGBA")
    img = img.crop(img.getbbox())
    img.save(args.dst)
    print(f"block={block:.2f} phase=({phase[0]:.2f},{phase[1]:.2f}) -> {img.size[0]}x{img.size[1]} saved {args.dst}")


if __name__ == "__main__":
    main()
