"""Turn a character video on a plain background (green screen or any flat colour) into a
pixel-art sprite sheet, keeping the video's own shading (like import_idle_video.py's
default mode). Works for standing and for walking-in-place clips, and for see-through
props (a clear umbrella).

  - background: every pixel far enough from the background colour (the median of the
    frame border, or --bg) is the character; tiny specks are dropped
  - frames are lined up: feet on one ground row, and sideways either on the feet
    (--align feet, for standing) or on the shirt (--align torso, for walking)
  - --glass: a clear prop shows the background through it. Above the collar, pixels
    that lie between the background colour and the prop's colour (--plastic) are
    unmixed: alpha = how far along that line they are, colour = the prop's own
  - size: the collar sits --collar game pixels above the feet (default: as in the
    --palette still), like the other sprites, so switching animations doesn't jump
  - each game pixel takes the median colour at the centre of its cell; the overall tone
    is matched to the still with one smooth colour function (see import_idle_video.py)

Usage:
  python3 tools/import_char_video.py VIDEO OUT.png --start 49 --end 95 --step 2 \\
      --palette assets/characters/hero_uniform.png --align feet --glass
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_idle_video import colour_match  # noqa: E402
from import_walk_video import landmarks, shift_img  # noqa: E402


def key(rgb, bg, threshold):
    mask = np.sqrt(((rgb - bg) ** 2).sum(2)) > threshold
    n = sum(np.roll(np.roll(mask, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
    return mask & (n >= 4)                           # drop compression specks


def body_marks(rgb, mask):
    """(ground row, collar row, shirt centre x, feet centre x) at video resolution."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(2)
    hair = mask & (mx < 150) & (r > b + 20) & (r > g) & (mx > 30)
    white = mask & (rgb.min(2) > 195)
    ys = np.nonzero(mask.any(1))[0]
    ground = ys.max()
    hair_top = np.nonzero(hair.sum(1) >= 25)[0].min()
    collar = hair_top + 60 + np.nonzero(white[hair_top + 60:].sum(1) >= 40)[0].min()
    shirt = np.nonzero(white[collar:collar + 200])[1].mean()
    fy, fx = np.nonzero(mask[ground - int(0.06 * (ground - ys.min())):ground + 1])
    return ground, collar, shirt, fx.mean()


def unmix(rgb, mask, bg, plastic, rows):
    """Clear plastic over the background: c = a * plastic + (1 - a) * bg."""
    u = plastic - bg
    v = rgb - bg
    a = (v @ u) / (u @ u)
    resid = np.sqrt(((v - a[..., None] * u) ** 2).sum(2))
    glass = mask & (resid < 45) & (a > 0.06) & (a < 0.92)   # between the background and the plastic
                                                             # (darker than the background = hair, not plastic)
    glass[rows:] = False
    a = np.clip(a, 0.15, 1.0)
    # one even colour for the plastic (the unmixed colours wander a little); its shape
    # and the brighter ribs and edges are carried by the alpha
    out = np.where(glass[..., None], plastic, rgb)
    alpha = np.where(glass, a * 255, np.where(mask, 255.0, 0.0))
    return out, alpha


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out")
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--end", type=int, default=-1, help="last frame (inclusive), -1 = to the end")
    ap.add_argument("--step", type=int, default=2, help="keep every n-th frame (24 fps / 2 = 12 fps)")
    ap.add_argument("--palette", required=True, help="still sprite: tone and collar height to match")
    ap.add_argument("--collar", type=float, default=0, help="collar height above the feet (default: the still's)")
    ap.add_argument("--align", choices=("feet", "torso"), default="feet")
    ap.add_argument("--bg", default="auto", help="background colour R,G,B (auto: median of the frame border)")
    ap.add_argument("--threshold", type=float, default=30, help="colour distance from the background")
    ap.add_argument("--glass", action="store_true", help="unmix a see-through prop above the collar")
    ap.add_argument("--plastic", default="226,232,242", help="colour of the see-through prop itself")
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["ffmpeg", "-v", "error", "-i", args.video, f"{tmp}/f%04d.png"], check=True)
        files = sorted(Path(tmp).glob("f*.png"))
        end = len(files) - 1 if args.end < 0 else args.end
        frames = [np.asarray(Image.open(files[i]).convert("RGB")).astype(float)
                  for i in range(args.start, end + 1, args.step)]

    f0 = frames[0]
    border = np.concatenate([f0[:8].reshape(-1, 3), f0[-8:].reshape(-1, 3), f0[:, :8].reshape(-1, 3), f0[:, -8:].reshape(-1, 3)])
    bg = np.median(border, 0) if args.bg == "auto" else np.array([float(v) for v in args.bg.split(",")])
    plastic = np.array([float(v) for v in args.plastic.split(",")])
    masks = [key(f, bg, args.threshold) for f in frames]
    marks = [body_marks(f, m) for f, m in zip(frames, masks)]

    # line the frames up: one ground row, and the feet or the shirt at one x
    g_ref = int(np.median([m[0] for m in marks]))
    xi = 3 if args.align == "feet" else 2
    x_ref = float(np.median([m[xi] for m in marks]))
    shifts = [(int(round(x_ref - m[xi])), g_ref - m[0]) for m in marks]
    frames = [shift_img(f, dx, dy) for f, (dx, dy) in zip(frames, shifts)]
    masks = [shift_img(m, dx, dy) for m, (dx, dy) in zip(masks, shifts)]
    collars = [m[1] + dy for m, (_, dy) in zip(marks, shifts)]

    union = np.any(masks, axis=0)
    ys, xs = np.nonzero(union)
    mg = 6
    x0, x1, y0, y1 = max(0, xs.min() - mg), xs.max() + 1 + mg, max(0, ys.min() - mg), g_ref + 1
    frames = [f[y0:y1, x0:x1] for f in frames]
    masks = [m[y0:y1, x0:x1] for m in masks]
    collars = [c - y0 for c in collars]

    green_screen = bg[1] > bg[0] + 60 and bg[1] > bg[2] + 60
    alphas = []
    for k in range(len(frames)):
        if args.glass:
            frames[k], al = unmix(frames[k], masks[k], bg, plastic, collars[k])
        else:
            al = masks[k] * 255.0
        if green_screen:
            # pull leftover green out of the solid edge pixels (after the unmix, which needs
            # it; the tone match would otherwise push greenish edges to pink)
            f = frames[k]
            solid = al >= 255
            f[..., 1] = np.where(solid, np.minimum(f[..., 1], np.maximum(f[..., 0], f[..., 2])), f[..., 1])
        alphas.append(al)

    ref = np.asarray(Image.open(args.palette).convert("RGBA"))
    target = args.collar or landmarks(ref)[0]
    ch, cw = masks[0].shape
    scale = target / np.median([ch - 1 - c for c in collars])
    out_w, out_h = round(cw * scale / 2) * 2, round(ch * scale)
    sy, sx = ch / out_h, cw / out_w
    q = max(1, int(min(sx, sy) * 0.25))
    result, glassy = [], []
    for rgb, mk, al in zip(frames, masks, alphas):
        out = np.zeros((out_h, out_w, 4))
        for j in range(out_h):
            cy = min(ch - 1, int((j + 0.5) * sy))
            if j == out_h - 1:
                cy = ch - 1 - q                   # bottom row samples the soles, not below them
            ys_ = slice(max(0, cy - q), cy + q + 1)
            for i in range(out_w):
                cx = int((i + 0.5) * sx)
                xs_ = slice(max(0, cx - q), cx + q + 1)
                m = mk[ys_, xs_]
                if m.mean() >= 0.5:
                    out[j, i, :3] = np.median(rgb[ys_, xs_][m], axis=0)
                    out[j, i, 3] = np.median(al[ys_, xs_][m])
        result.append(out.round().astype(np.uint8))
        glassy.append((out[..., 3] > 0) & (out[..., 3] < 250))
    matched = colour_match([np.where(gl[..., None], 0, f) for f, gl in zip(result, glassy)], ref)
    final = []
    for m, f, gl in zip(matched, result, glassy):
        m = m.copy()
        m[gl] = f[gl]                             # the clear prop keeps its unmixed colour
        final.append(m)

    sheet = Image.new("RGBA", (out_w * len(final), out_h), (0, 0, 0, 0))
    for i, f in enumerate(final):
        sheet.paste(Image.fromarray(f, "RGBA"), (i * out_w, 0))
    sheet.save(args.out)
    heights = [round(out_h - 1 - c * scale) for c in collars]
    print(f"{len(final)} frames of {out_w}x{out_h} -> {args.out}; background {bg.round().tolist()}; "
          f"collar heights {sorted(set(heights))} (target {target}); scale {scale:.4f}")


if __name__ == "__main__":
    main()
