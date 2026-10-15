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


def features(rgb):
    """Colour space for grouping pixels into materials: lightness plus two chroma axes."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    return np.stack([lum, 1.6 * (r - g), 1.6 * ((r + g) / 2 - b)], -1)


def kmeans(x, k, iters=30, seed=1):
    rng = np.random.default_rng(seed)
    c = x[rng.choice(len(x), k, replace=False)]
    for _ in range(iters):
        lab = ((x[:, None] - c[None]) ** 2).sum(2).argmin(1)
        c = np.array([x[lab == i].mean(0) if (lab == i).any() else c[i] for i in range(k)])
    return c


def nearest(x, centres):
    out = np.empty(len(x), int)
    for k in range(0, len(x), 65536):
        out[k:k + 65536] = ((x[k:k + 65536, None] - centres[None]) ** 2).sum(2).argmin(1)
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


def cell_sample(lum, mat, mask, out_w, out_h, n_mat):
    """Downscale without blending: each target pixel takes the material most of its cell is
    made of (crisp, stable edges between hair/skin/shirt...) and the median lightness of
    that material inside the cell."""
    h, w = lum.shape
    sx, sy = w / out_w, h / out_h
    qx, qy = max(1, int(sx * 0.4)), max(1, int(sy * 0.4))
    out_m = np.full((out_h, out_w), -1)
    out_l = np.zeros((out_h, out_w))
    for j in range(out_h):
        cy = int((j + 0.5) * sy)
        ys = slice(max(0, cy - qy), cy + qy + 1)
        for i in range(out_w):
            cx = int((i + 0.5) * sx)
            xs = slice(max(0, cx - qx), cx + qx + 1)
            m = mask[ys, xs]
            if m.mean() < 0.5:
                continue
            mm = mat[ys, xs][m]
            best = np.bincount(mm, minlength=n_mat).argmax()
            out_m[j, i] = best
            out_l[j, i] = np.median(lum[ys, xs][m][mm == best])
    return out_m, out_l


def stretch_rows(img, top, bottom, factor):
    """Stretch rows [top, bottom) vertically by `factor` (nearest), keeping the rest."""
    n = round((bottom - top) * factor)
    rows = np.concatenate([np.arange(top), top + (np.arange(n) / factor).astype(int),
                           np.arange(bottom, img.shape[0])])
    return img[rows]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out")
    ap.add_argument("--start", type=int, default=0, help="first frame of the cycle")
    ap.add_argument("--cycle", type=int, required=True, help="frames in one full walk cycle")
    ap.add_argument("--frames", type=int, default=8, help="frames to keep from the cycle")
    ap.add_argument("--height", type=int, default=122, help="character height in game pixels")
    ap.add_argument("--palette", required=True, help="idle sprite whose colours the frames take on")
    ap.add_argument("--materials", type=int, default=9, help="colour groups (hair, skin, shirt...)")
    ap.add_argument("--legs", type=float, nargs=3, metavar=("TOP", "BOTTOM", "FACTOR"),
                    help="stretch the rows between TOP and BOTTOM (fractions of the height, "
                         "e.g. shorts hem to ankle) by FACTOR so the legs match the idle sprite")
    ap.add_argument("--bob", type=float, default=1.0,
                    help="with --legs: keep this fraction of the video's up-down body bob (0.4 = calmer)")
    ap.add_argument("--lock-upper", type=int, default=0, metavar="ROWS",
                    help="use one frame's body above ROWS pixels from the ground (e.g. mid-shorts) "
                         "for every frame, so only the legs animate (no wobbling hair/shirt)")
    ap.add_argument("--lock-from", type=int, default=0, help="frame whose upper body is used")
    ap.add_argument("--shoe-scale", type=float, default=1.0,
                    help="squash each shoe to this fraction of its height; the frame moves down "
                         "so feet stay grounded")
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

    # Materials (hair, skin, shirt, shorts, bag...) come from the idle sprite's own colours
    ref = np.asarray(Image.open(args.palette).convert("RGBA")).astype(float)
    opaque = ref[..., 3] > 0
    ref_px = ref[..., :3][opaque]
    centres = kmeans(features(ref_px), args.materials)
    ref_mat = nearest(features(ref_px), centres)

    inner = opaque & np.roll(opaque, 1, 0) & np.roll(opaque, -1, 0) & np.roll(opaque, 1, 1) & np.roll(opaque, -1, 1)
    edge_colour = ref[..., :3][opaque & ~inner].mean(0) * 0.6
    ref_lum = features(ref_px)[:, 0]

    def build(leg_factors):
        cells = []
        for rgb, mask, factor in zip(frames, masks, leg_factors):
            rgb = rgb[y0:y1, x0:x1].copy()
            mask = mask[y0:y1, x0:x1]
            # despill green fringe
            rgb[..., 1] = np.minimum(rgb[..., 1], np.maximum(rgb[..., 0], rgb[..., 2]))
            if args.legs:
                h = rgb.shape[0]
                top, bottom = int(args.legs[0] * h), int(args.legs[1] * h)
                rgb = stretch_rows(rgb, top, bottom, factor)
                mask = stretch_rows(mask, top, bottom, factor)
            out_h = round(rgb.shape[0] * scale)
            out_w = round(rgb.shape[1] * scale / 2) * 2  # even width: no half-pixel centre
            feat = features(rgb.reshape(-1, 3))
            mat = nearest(feat, centres).reshape(mask.shape)
            cells.append(cell_sample(feat[:, 0].reshape(mask.shape), mat, mask, out_w, out_h, args.materials))

        # Per material, give the frames the same spread of shades as the idle sprite:
        # the n-th lightest hair pixel becomes the idle's n-th lightest hair colour, etc.
        out_rgb = [np.zeros(m.shape + (3,)) for m, _ in cells]
        for k in range(args.materials):
            pool = ref_px[ref_mat == k][np.argsort(ref_lum[ref_mat == k])]
            sel = [m == k for m, _ in cells]
            vals = np.concatenate([l[s] for (_, l), s in zip(cells, sel)])
            if len(vals) == 0 or len(pool) == 0:
                continue
            ranks = np.empty(len(vals), int)
            ranks[np.argsort(vals, kind="stable")] = np.arange(len(vals))
            mapped = pool[(ranks * (len(pool) - 1) / max(1, len(vals) - 1)).astype(int)]
            n = 0
            for o, s in zip(out_rgb, sel):
                c = int(s.sum())
                o[s] = mapped[n:n + c]
                n += c

        result = []
        for (m, _), rgb in zip(cells, out_rgb):
            frame = np.dstack([rgb, (m >= 0) * 255]).astype(np.uint8)
            if args.shoe_scale < 1.0:
                frame, _ = squash_shoes(frame, args.shoe_scale)
            result.append(add_outline(frame, edge_colour))
        return result

    def landmarks(frame):
        """Height of the shirt collar above the ground and x centre of the torso."""
        a = frame[..., 3] > 0
        white = a & (frame[..., :3].min(2) > 185)
        collar = next(y for y in range(frame.shape[0]) if white[y].sum() >= 6)
        torso = np.nonzero(a[collar:collar + 30])[1]
        return frame.shape[0] - 1 - collar, torso.mean()

    base = args.legs[2] if args.legs else 1.0
    factors = [base] * args.frames
    out_frames = build(factors)
    if args.legs and args.bob < 1.0:
        # The video bobs a lot; lengthen/shorten the legs per frame so the body bobs
        # only `bob` as much (feet stay on the ground, no up-down shake)
        heights = np.array([landmarks(f)[0] for f in out_frames], float)
        region = (args.legs[1] - args.legs[0]) * args.height
        target = heights.mean() + args.bob * (heights - heights.mean())
        factors = [f + (t - h) / region for f, t, h in zip(factors, target, heights)]
        out_frames = build(factors)

    # Line every frame up on the torso (no side-to-side shake) and on the ground
    centres_x = np.array([landmarks(f)[1] for f in out_frames])
    shifts = np.round(centres_x.mean() - centres_x).astype(int)
    pad = int(np.abs(shifts).max())
    out_h = max(f.shape[0] for f in out_frames)
    out_w = out_frames[0].shape[1] + 2 * pad
    canvases = []
    for frame, dx in zip(out_frames, shifts):
        c = np.zeros((out_h, out_w, 4), np.uint8)
        c[out_h - frame.shape[0]:, pad + dx:pad + dx + frame.shape[1]] = frame
        canvases.append(c)

    if args.lock_upper:
        # AI video redraws hair, shirt and bag a little differently every frame, which
        # reads as shaking. Use one frame's upper body for all frames (only the legs
        # move) and give it a clean 1px bob: down on the wide steps, up when passing.
        def spread(c):
            xs = np.nonzero(c[-12:, :, 3].any(0))[0]
            return xs.max() - xs.min()
        spreads = np.array([spread(c) for c in canvases])
        low = (spreads > np.median(spreads)).astype(int)  # feet wide apart = body lowest
        cut = out_h - 1 - args.lock_upper
        ref_up = canvases[args.lock_from][:cut].copy()
        for c, lo in zip(canvases, low):
            d = int(lo) - int(low[args.lock_from])
            c[:cut + d] = 0
            if d >= 0:
                c[d:cut + d] = ref_up
            else:
                c[:cut + d] = ref_up[-d:]
        print("upper body from frame", args.lock_from, "bob", low.tolist(), "feet spread", spreads.tolist())

    sheet = Image.new("RGBA", (out_w * args.frames, out_h), (0, 0, 0, 0))
    for i, c in enumerate(canvases):
        sheet.paste(Image.fromarray(c, "RGBA"), (i * out_w, 0))
    sheet.save(args.out)
    print(f"{args.frames} frames of {out_w}x{out_h} -> {args.out} (crop {x0},{y0} {x1 - x0}x{y1 - y0})")


if __name__ == "__main__":
    main()
