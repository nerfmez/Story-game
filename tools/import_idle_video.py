"""Turn a green-screen idle (standing) video into a pixel-art sprite sheet.

By default the video's own colours are kept: each game pixel takes the median colour
at the centre of its cell in the video, exactly like tools/import_sprite.py does for
stills (use this when the video already matches the still, as AI clips made from it
do). --recolour instead uses import_walk_video.py's steps (majority material per cell,
the still's spread of shades, a redrawn outline), for a video whose colours are off;
on a clip that already matches it only adds blotchy shading.
It also:
  - pins the feet: every frame is shifted so the planted feet stay on the same
    pixels (the body still sways; only the camera/AI drift is removed)
  - scales the character so the shirt collar is as high above the ground as in the
    idle sprite, so walking and standing match
  - keeps one sampling grid for all frames, so still parts don't shimmer
  - draws the backpack's second strap over the free shoulder (the source art wears
    the bag on one shoulder, so flipping the sprite moved the bag to the other side;
    the walk shows both straps). It follows the collar and the shoulder outline
    frame by frame.

Usage:
  python3 tools/import_idle_video.py VIDEO assets/characters/hero_idle_video.png \\
      --start 39 --end 111 --step 2 --palette assets/characters/hero_uniform.png
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_walk_video import (add_outline, cell_sample, features, is_green,  # noqa: E402
                               kmeans, landmarks, nearest, shift_img)


# Second strap, relative to the collar row (first row with 6+ white shirt pixels) and
# the outline of the free shoulder 8 rows below it: (dy, dx, width) per row.
# Following the reference art (art_source/hero_two_straps_ref.png): over the top of
# the shoulder, then down the side of the chest next to the sleeve, bowing slightly
# outward with the chest, to below the sleeve where the arm covers it, with a metal
# adjuster buckle about a third of the way down. Both straps get a buckle.
STRAP = ([(-1, 6, 2), (0, 4, 4), (1, 5, 3)] + [(dy, 5, 2) for dy in range(2, 8)]
         + [(dy, 4, 2) for dy in range(8, 17)] + [(17, 3, 2), (18, 3, 2), (19, 3, 1)])
BUCKLE_DY = 7                       # high enough that the original strap is still in view there
STRAP_DARK, STRAP_MID, STRAP_LIT = (26, 30, 70, 255), (40, 52, 104, 255), (62, 78, 140, 255)
METAL, METAL_DARK = (196, 196, 214, 255), (96, 96, 122, 255)


def is_navy(px):
    r, g, b = int(px[0]), int(px[1]), int(px[2])
    return px[3] > 0 and b > r + 20 and b > g + 10 and max(r, g, b) < 150


def add_buckle(out, y, x):
    """2x2 metal adjuster with a dark lower edge, centred on a strap at (x, y)."""
    out[y, x] = METAL
    out[y, x + 1] = METAL
    out[y + 1, x] = METAL_DARK
    out[y + 1, x + 1] = METAL_DARK


def add_strap(frame):
    a = frame[..., 3] > 0
    white = a & (frame[..., :3].min(2) > 185)
    collar = next(y for y in range(frame.shape[0]) if white[y].sum() >= 6)
    left = int(np.nonzero(a[collar + 8])[0].min())
    out = frame.copy()
    for dy, dx, width in STRAP:
        y = collar + dy
        for k in range(width):
            x = left + dx + k
            if not a[y, x]:
                continue
            if width == 1:
                colour = STRAP_MID
            elif dy <= 0:                      # top of the shoulder catches the light
                colour = STRAP_LIT if k > 0 else STRAP_MID
            else:
                colour = STRAP_DARK if k == 0 else STRAP_LIT
            out[y, x] = colour
    by = collar + BUCKLE_DY
    bx = left + [dx for dy, dx, _ in STRAP if dy == BUCKLE_DY][0]
    add_buckle(out, by, bx)
    # the original strap on the other shoulder: first navy run just right of the middle
    # (further out is the bag itself)
    # The strap shifts a little from frame to frame, so look a couple of rows around too.
    mid = frame.shape[1] // 2
    for y in (by, by - 1, by + 1, by - 2, by + 2):
        xs = [x for x in range(mid, mid + 10) if is_navy(frame[y, x]) and is_navy(frame[y, x + 1])]
        if xs:
            add_buckle(out, y, xs[0])
            break
    return out


def direct(args, frames, masks):
    """Keep the video's colours: scale so the figure is as tall as the still, then give
    each game pixel the median colour at the centre of its cell (no blending across
    cells, so edges and the drawn outline stay crisp)."""
    ref = Image.open(args.palette)
    heights = [np.nonzero(m.any(1))[0] for m in masks]
    fig_h = np.median([h.max() - h.min() + 1 for h in heights])
    scale = ref.size[1] / fig_h
    ch, cw = masks[0].shape
    out_w, out_h = round(cw * scale / 2) * 2, round(ch * scale)
    sy, sx = ch / out_h, cw / out_w
    q = max(1, int(min(sx, sy) * 0.25))
    result = []
    for rgb, mk in zip(frames, masks):
        out = np.zeros((out_h, out_w, 4), np.uint8)
        for j in range(out_h):
            cy = int((j + 0.5) * sy)
            ys = slice(max(0, cy - q), cy + q + 1)
            for i in range(out_w):
                cx = int((i + 0.5) * sx)
                xs = slice(max(0, cx - q), cx + q + 1)
                m = mk[ys, xs]
                if m.mean() >= 0.5:
                    out[j, i, :3] = np.median(rgb[ys, xs][m], axis=0)
                    out[j, i, 3] = 255
        if not args.no_strap:
            out = add_strap(out)
        result.append(out)
    sheet = Image.new("RGBA", (out_w * len(result), out_h), (0, 0, 0, 0))
    for i, f in enumerate(result):
        sheet.paste(Image.fromarray(f, "RGBA"), (i * out_w, 0))
    sheet.save(args.out)
    marks = [landmarks(f) for f in result]
    print(f"{len(result)} frames of {out_w}x{out_h} -> {args.out} (video colours kept); collar heights",
          sorted({int(h) for h, _ in marks}), "torso x", round(float(np.mean([x for _, x in marks])), 2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out")
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--end", type=int, default=-1, help="last frame (inclusive), -1 = to the end")
    ap.add_argument("--step", type=int, default=2, help="keep every n-th frame (24 fps / 2 = 12 fps)")
    ap.add_argument("--palette", required=True, help="idle sprite whose colours and proportions to match")
    ap.add_argument("--materials", type=int, default=9)
    ap.add_argument("--no-strap", action="store_true", help="don't draw the second backpack strap")
    ap.add_argument("--recolour", action="store_true",
                    help="map colours to the still's shades (only for videos whose colours are off)")
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["ffmpeg", "-v", "error", "-i", args.video, f"{tmp}/f%04d.png"], check=True)
        files = sorted(Path(tmp).glob("f*.png"))
        end = len(files) - 1 if args.end < 0 else args.end
        frames = [np.asarray(Image.open(files[i]).convert("RGB")).astype(float)
                  for i in range(args.start, end + 1, args.step)]

    masks = [~is_green(f) for f in frames]
    for rgb in frames:                       # despill green fringe
        rgb[..., 1] = np.minimum(rgb[..., 1], np.maximum(rgb[..., 0], rgb[..., 2]))

    # Pin the feet: lowest row and the centre of the feet (bottom 6% of the figure)
    feet = []
    for m in masks:
        ys, xs = np.nonzero(m)
        ground = ys.max()
        band = ys > ground - 0.06 * (ground - ys.min())
        feet.append((ground, xs[band].mean()))
    g_ref = int(np.median([g for g, _ in feet]))
    x_ref = float(np.median([x for _, x in feet]))
    frames = [shift_img(f, int(round(x_ref - x)), g_ref - g) for f, (g, x) in zip(frames, feet)]
    masks = [shift_img(m, int(round(x_ref - x)), g_ref - g) for m, (g, x) in zip(masks, feet)]

    # Crop to the union of the figure, with the feet on the last row
    union = np.any(masks, axis=0)
    ys, xs = np.nonzero(union)
    m = 6
    x0, x1, y0, y1 = xs.min() - m, xs.max() + 1 + m, ys.min() - m, g_ref + 1
    frames = [f[y0:y1, x0:x1] for f in frames]
    masks = [mk[y0:y1, x0:x1] for mk in masks]

    if not args.recolour:
        direct(args, frames, masks)
        return

    # Scale: collar height above the ground like the idle sprite
    ref = np.asarray(Image.open(args.palette).convert("RGBA"))
    idle_collar = landmarks(ref)[0]
    mid = len(frames) // 2
    white = masks[mid] & (frames[mid].min(2) > 200)
    collar = next(y for y in range(white.shape[0]) if white[y].sum() >= 25)
    scale = idle_collar / (white.shape[0] - 1 - collar)
    ch, cw = masks[0].shape

    refp = ref.astype(float)
    opaque = refp[..., 3] > 0
    ref_px = refp[..., :3][opaque]
    centres = kmeans(features(ref_px), args.materials)
    ref_mat = nearest(features(ref_px), centres)
    ref_lum = features(ref_px)[:, 0]
    inner = opaque & np.roll(opaque, 1, 0) & np.roll(opaque, -1, 0) & np.roll(opaque, 1, 1) & np.roll(opaque, -1, 1)
    edge_colour = refp[..., :3][opaque & ~inner].mean(0) * 0.6

    def build(scale):
        out_w = round(cw * scale / 2) * 2
        out_h = round(ch * scale)
        cells = []
        for rgb, mk in zip(frames, masks):
            feat = features(rgb.reshape(-1, 3))
            mat = nearest(feat, centres).reshape(mk.shape)
            cells.append(cell_sample(feat[:, 0].reshape(mk.shape), mat, mk, out_w, out_h, args.materials))
        out_rgb = [np.zeros(mt.shape + (3,)) for mt, _ in cells]
        for k in range(args.materials):
            pool = ref_px[ref_mat == k][np.argsort(ref_lum[ref_mat == k])]
            sel = [mt == k for mt, _ in cells]
            vals = np.concatenate([lum[s] for (_, lum), s in zip(cells, sel)])
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
        for (mt, _), rgb in zip(cells, out_rgb):
            frame = add_outline(np.dstack([rgb, (mt >= 0) * 255]).astype(np.uint8), edge_colour)
            if not args.no_strap:
                frame = add_strap(frame)
            result.append(frame)
        return result, out_w, out_h

    # The collar test on the video is rough, so measure the result and rescale once
    result, out_w, out_h = build(scale)
    mean_collar = np.mean([landmarks(f)[0] for f in result])
    scale *= idle_collar / mean_collar
    result, out_w, out_h = build(scale)
    sheet = Image.new("RGBA", (out_w * len(result), out_h), (0, 0, 0, 0))
    for i, frame in enumerate(result):
        sheet.paste(Image.fromarray(frame, "RGBA"), (i * out_w, 0))
    sheet.save(args.out)
    marks = [landmarks(f) for f in result]
    print(f"{len(result)} frames of {out_w}x{out_h} -> {args.out}; collar heights",
          sorted({int(h) for h, _ in marks}), "torso x", round(float(np.mean([x for _, x in marks])), 2))


if __name__ == "__main__":
    main()
