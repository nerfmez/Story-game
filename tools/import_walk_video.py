"""Turn a green-screen walk video into a pixel-art sprite sheet.

The video should show the character walking in place (camera fixed). The script
takes one walk cycle, samples N frames from it, keys out the green, scales the
frames down to the game's character height (sampling the centre of each pixel
cell, so edges stay crisp), matches their brightness to an existing sprite and
snaps every pixel to that sprite's real colours, then redraws a 1px outline.

Usage:
  python3 tools/import_walk_video.py VIDEO OUT.png --start 24 --cycle 32 --frames 8 \\
      --height 122 --palette assets/characters/hero_uniform.png --shoe-scale 0.7
"""
import argparse
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image


def is_green(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (g > 120) & (g > r * 1.35) & (g > b * 1.35)


def label(mask):
    """4-connected component labelling (flood fill), like scipy.ndimage.label."""
    labels = np.zeros(mask.shape, int)
    n = 0
    for y, x in zip(*np.nonzero(mask)):
        if labels[y, x]:
            continue
        n += 1
        stack = [(y, x)]
        labels[y, x] = n
        while stack:
            cy, cx = stack.pop()
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = n
                    stack.append((ny, nx))
    return labels, n


def squash_shoes(rgba, factor, band=16):
    """Make chunky shoes lower: every shoe (dark blob near the bottom) is resampled
    to `factor` of its height, anchored at the ankle, so its shape stays intact.
    Returns (new rgba, rows freed at the bottom of the planted foot)."""
    h, w = rgba.shape[:2]
    out = rgba.copy()
    region = np.zeros((h, w), bool)
    region[h - band:] = True
    dark = (rgba[..., :3].max(axis=2) < 110) & (rgba[..., 3] > 0) & region
    labels, n = label(dark)
    lowest = 0
    for i in range(1, n + 1):
        ys, xs = np.where(labels == i)
        if len(ys) < 12:
            continue
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        blob = rgba[y0:y1, x0:x1].copy()
        blob[labels[y0:y1, x0:x1] != i] = 0
        nh = max(2, round((y1 - y0) * factor))
        rows = (np.arange(nh) * (y1 - y0) / nh).astype(int)
        small = blob[rows]
        out[y0:y1, x0:x1][labels[y0:y1, x0:x1] == i] = 0
        tgt = out[y0:y0 + nh, x0:x1]
        m = small[..., 3] > 0
        tgt[m] = small[m]
        lowest = max(lowest, y0 + nh - 1)
    shift = (h - 1) - lowest
    shifted = np.zeros_like(out)
    if shift > 0:
        shifted[shift:] = out[:h - shift]
        return shifted, shift
    return out, 0


def match_luminance(pixels, reference):
    """Match the brightness distribution only (keeps each pixel's hue and saturation)."""
    lum = lambda p: p @ np.array([0.299, 0.587, 0.114])
    src, ref = lum(pixels), np.sort(lum(reference))
    order = np.argsort(src)
    ranks = np.empty_like(order)
    ranks[order] = np.arange(len(src))
    target = ref[(ranks * (len(ref) - 1) / max(1, len(src) - 1)).astype(int)]
    gain = target / np.maximum(src, 1.0)
    return np.clip(pixels * gain[:, None], 0, 255)


def nearest_colours(pixels, palette):
    """Snap each pixel to the closest colour that really occurs in the reference sprite."""
    out = np.empty_like(pixels)
    for k in range(0, len(pixels), 4096):
        chunk = pixels[k:k + 4096]
        d = ((chunk[:, None, :] - palette[None, :, :]) ** 2).sum(2)
        out[k:k + 4096] = palette[d.argmin(1)]
    return out


def add_outline(rgba, colour_from=None, strength=0.62):
    """Darken the outer silhouette pixels into a 1px outline like the idle sprite."""
    a = rgba[..., 3] > 0
    inner = a & np.roll(a, 1, 0) & np.roll(a, -1, 0) & np.roll(a, 1, 1) & np.roll(a, -1, 1)
    edge = a & ~inner
    out = rgba.astype(float).copy()
    tint = np.array(colour_from if colour_from is not None else (60, 34, 52), float)
    out[edge, :3] = out[edge, :3] * (1 - strength) + tint * strength
    return out.astype(np.uint8)


def block_sample(img, mask, out_w, out_h):
    """Downscale by taking the median of the centre of each target cell (no averaging
    across cell borders), so outlines and pixel edges stay crisp."""
    h, w = img.shape[:2]
    sx, sy = w / out_w, h / out_h
    q = max(1, int(min(sx, sy) * 0.22))
    rgb = np.zeros((out_h, out_w, 3))
    alpha = np.zeros((out_h, out_w), bool)
    for j in range(out_h):
        cy = int((j + 0.5) * sy)
        for i in range(out_w):
            cx = int((i + 0.5) * sx)
            ys, xs = slice(max(0, cy - q), cy + q + 1), slice(max(0, cx - q), cx + q + 1)
            m = mask[ys, xs]
            alpha[j, i] = m.mean() >= 0.5
            if alpha[j, i]:
                rgb[j, i] = np.median(img[ys, xs][m], axis=0)
    return rgb, alpha


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out")
    ap.add_argument("--start", type=int, default=0, help="first frame of the cycle")
    ap.add_argument("--cycle", type=int, required=True, help="frames in one full walk cycle")
    ap.add_argument("--frames", type=int, default=8, help="frames to keep from the cycle")
    ap.add_argument("--height", type=int, default=122, help="character height in game pixels")
    ap.add_argument("--palette", help="sprite whose colours the frames are snapped to")
    ap.add_argument("--shoe-scale", type=float, default=1.0,
                    help="squash each shoe to this fraction of its height (e.g. 0.7 for chunky "
                         "AI shoes -> flat school shoes); the frame moves down so feet stay grounded")
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["ffmpeg", "-v", "error", "-i", args.video, f"{tmp}/f%04d.png"], check=True)
        files = sorted(Path(tmp).glob("f*.png"))
        picks = [files[args.start + round(i * args.cycle / args.frames)] for i in range(args.frames)]
        frames = [np.asarray(Image.open(f).convert("RGB")).astype(float) for f in picks]

    # One crop box for all frames (union of the character), so the feet stay put
    masks = [~is_green(f) for f in frames]
    union = np.any(masks, axis=0)
    ys, xs = np.where(union)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    scale = args.height / (y1 - y0)
    out_w = round((x1 - x0) * scale)

    smalls = []
    for rgb, mask in zip(frames, masks):
        rgb = rgb[y0:y1, x0:x1].copy()
        mask = mask[y0:y1, x0:x1]
        # despill green fringe
        rgb[..., 1] = np.where(rgb[..., 1] > np.maximum(rgb[..., 0], rgb[..., 2]),
                               np.maximum(rgb[..., 0], rgb[..., 2]), rgb[..., 1])
        small, small_a = block_sample(rgb, mask, out_w, args.height)
        smalls.append((small, small_a))

    edge_colour = None
    if args.palette:
        # One brightness mapping for all frames (no flicker); hue and saturation are kept,
        # then every pixel snaps to the nearest colour that exists in the reference sprite
        ref = np.asarray(Image.open(args.palette).convert("RGBA")).astype(float)
        opaque = ref[..., 3] > 0
        ref_px = ref[..., :3][opaque]
        all_px = np.concatenate([sm[a] for sm, a in smalls])
        mapped = nearest_colours(all_px, np.unique(ref_px, axis=0))
        k = 0
        for sm, a in smalls:
            n = int(a.sum())
            sm[a] = mapped[k:k + n]
            k += n
        inner = opaque & np.roll(opaque, 1, 0) & np.roll(opaque, -1, 0) & np.roll(opaque, 1, 1) & np.roll(opaque, -1, 1)
        edge_colour = ref[..., :3][opaque & ~inner].mean(0) * 0.6

    sheet = Image.new("RGBA", (out_w * args.frames, args.height), (0, 0, 0, 0))
    for i, (sm, a) in enumerate(smalls):
        frame = np.dstack([sm.clip(0, 255), a * 255]).astype(np.uint8)
        if args.shoe_scale < 1.0:
            frame, _ = squash_shoes(frame, args.shoe_scale)
        frame = add_outline(frame, edge_colour)
        sheet.paste(Image.fromarray(frame, "RGBA"), (i * out_w, 0))
    sheet.save(args.out)
    print(f"{args.frames} frames of {out_w}x{args.height} -> {args.out} (crop {x0},{y0} {x1 - x0}x{y1 - y0})")


if __name__ == "__main__":
    main()
