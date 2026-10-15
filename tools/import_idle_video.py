"""Turn a green-screen idle (standing) video into a pixel-art sprite sheet.

Uses the same steps as import_walk_video.py: key out the green, cut the frames into
pixels by the majority material of each cell (crisp, no blending), give every
material the idle sprite's exact spread of shades, redraw the 1px outline.
For standing still it also:
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
# Shaped like the original strap on the other shoulder: wide where it crosses the top
# of the shoulder, then curving outward over the chest as the bag's weight pulls it
# back, tapering and slipping under the armpit.
STRAP = [(-1, 7, 1), (0, 4, 5), (1, 5, 3), (2, 5, 3), (3, 4, 3), (4, 4, 3),
         (5, 3, 3), (6, 3, 3), (7, 3, 2), (8, 3, 1)]
STRAP_DARK, STRAP_MID, STRAP_LIT = (26, 30, 70, 255), (40, 52, 104, 255), (62, 78, 140, 255)


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
            elif dy == 0:                      # top of the shoulder catches the light
                colour = STRAP_LIT if 0 < k < width - 1 else STRAP_MID
            else:
                colour = STRAP_DARK if k == 0 else (STRAP_LIT if k == width - 1 else STRAP_MID)
            out[y, x] = colour
    return out


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

    # Scale: collar height above the ground like the idle sprite
    ref = np.asarray(Image.open(args.palette).convert("RGBA"))
    idle_collar = landmarks(ref)[0]
    mid = len(frames) // 2
    white = masks[mid] & (frames[mid].min(2) > 200)
    collar = next(y for y in range(white.shape[0]) if white[y].sum() >= 25)
    scale = idle_collar / (white.shape[0] - 1 - collar)
    ch, cw = masks[0].shape
    out_w = round(cw * scale / 2) * 2
    out_h = round(ch * scale)

    refp = ref.astype(float)
    opaque = refp[..., 3] > 0
    ref_px = refp[..., :3][opaque]
    centres = kmeans(features(ref_px), args.materials)
    ref_mat = nearest(features(ref_px), centres)
    ref_lum = features(ref_px)[:, 0]
    inner = opaque & np.roll(opaque, 1, 0) & np.roll(opaque, -1, 0) & np.roll(opaque, 1, 1) & np.roll(opaque, -1, 1)
    edge_colour = refp[..., :3][opaque & ~inner].mean(0) * 0.6

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

    sheet = Image.new("RGBA", (out_w * len(cells), out_h), (0, 0, 0, 0))
    for i, ((mt, _), rgb) in enumerate(zip(cells, out_rgb)):
        frame = add_outline(np.dstack([rgb, (mt >= 0) * 255]).astype(np.uint8), edge_colour)
        if not args.no_strap:
            frame = add_strap(frame)
        sheet.paste(Image.fromarray(frame, "RGBA"), (i * out_w, 0))
    sheet.save(args.out)
    marks = [landmarks(np.asarray(sheet.crop((i * out_w, 0, (i + 1) * out_w, out_h)))) for i in range(len(cells))]
    print(f"{len(cells)} frames of {out_w}x{out_h} -> {args.out}; collar heights",
          sorted({int(h) for h, _ in marks}), "torso x", round(float(np.mean([x for _, x in marks])), 2))


if __name__ == "__main__":
    main()
