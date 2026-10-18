"""Clean the couple-walking-under-the-umbrella sheet (crossing cutscene).

The clip's backdrop is a pale green (not a strong key green), so import_char_video.py keeps the
clear umbrella as opaque pixels tinted by that green, and leaves green fringes on the outlines.

  1. canopy (rows above the shoulders, not hair or skin): each pixel is the backdrop seen through
     clear plastic, P = (1-k)*BG + k*W. k = how far P moved from BG toward white, projected on
     (W - BG). Becomes white plastic at alpha k (plus a faint film), like the game's own umbrella.
     Pixels much darker than the backdrop are ribs/edges: dark grey, half see-through.
  2. outline pixels (next to transparency) lose their green spill.

Usage:
  python3 tools/finish_pair_walk.py RAW.png OUT.png --frames 45 --bg 141,207,106 --canopy-rows 46
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--frames", type=int, required=True)
    ap.add_argument("--bg", default="141,207,106")
    ap.add_argument("--canopy-rows", type=int, default=46, help="rows from the top that hold the umbrella")
    args = ap.parse_args()

    img = np.asarray(Image.open(args.src).convert("RGBA")).astype(np.float32)
    rgb, alpha = img[..., :3], img[..., 3]
    bg = np.array([float(v) for v in args.bg.split(",")])
    white = np.array([232.0, 238.0, 248.0])
    h = img.shape[0]
    rows = np.arange(h)[:, None] < args.canopy_rows
    lum = rgb.sum(-1)
    green = (rgb[..., 1] - rgb[..., 0] > -5) & (rgb[..., 1] - rgb[..., 2] > 25)     # backdrop green, olive mixes
    near_bg = np.abs(rgb - bg).sum(-1) < 110
    light = (lum > 600) & (rgb.max(-1) - rgb.min(-1) < 40)
    hair = lum < 300
    skin = rgb[..., 0] > rgb[..., 1] + 15
    canopy = rows & (alpha > 0) & (green | near_bg | light) & ~hair & ~skin

    d = white - bg
    k = np.clip(((rgb - bg) @ d) / (d @ d), 0.0, 1.0)
    darker = lum < bg.sum() - 60
    out_rgb = rgb.copy()
    out_a = alpha.copy()
    film = 0.10
    out_rgb[canopy] = white
    out_a[canopy] = np.clip(film + k[canopy] * 0.9, 0, 0.95) * 255
    rib = canopy & darker
    out_rgb[rib] = np.array([88.0, 96.0, 118.0])
    out_a[rib] = 140

    # green spill on the outlines (pixels touching transparency)
    solid = out_a > 200
    edge = solid & ndimage.binary_dilation(~solid)
    # outline pixels mixed with the green backdrop become the dark outline colour; others lose the spill
    spilled = edge & ~canopy & (out_rgb[..., 1] > np.maximum(out_rgb[..., 0], out_rgb[..., 2]) + 12)
    out_rgb[spilled] = np.array([44.0, 42.0, 58.0])
    g_cap = np.maximum(out_rgb[..., 0], out_rgb[..., 2]) + 6
    out_rgb[..., 1] = np.where(edge & ~canopy, np.minimum(out_rgb[..., 1], g_cap), out_rgb[..., 1])

    out = np.dstack([out_rgb, out_a]).clip(0, 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(args.out)
    print(f"{canopy.sum()} canopy pixels ({rib.sum()} ribs), {edge.sum()} outline pixels -> {args.out}")


if __name__ == "__main__":
    main()
