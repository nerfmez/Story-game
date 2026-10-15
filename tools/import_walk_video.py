"""Turn a green-screen walk video into a pixel-art sprite sheet.

The video should show the character walking in place (camera fixed). The script
takes one walk cycle, samples N frames from it, keys out the green, scales the
frames down to the game's character height and matches their colours to an
existing sprite (histogram matching per channel, then snapping to its palette),
because generated video usually comes out darker and flatter than the still image.

Usage:
  python3 tools/import_walk_video.py VIDEO OUT.png --start 24 --cycle 32 --frames 8 \\
      --height 122 --palette assets/characters/hero_uniform.png
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


def match_histograms(pixels, reference):
    """Remap each RGB channel of `pixels` (N,3) so its distribution matches `reference` (M,3)."""
    out = np.empty_like(pixels)
    for c in range(3):
        src = pixels[:, c]
        order = np.argsort(src)
        ranks = np.empty_like(order)
        ranks[order] = np.arange(len(src))
        ref_sorted = np.sort(reference[:, c])
        out[:, c] = ref_sorted[(ranks * (len(ref_sorted) - 1) / max(1, len(src) - 1)).astype(int)]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out")
    ap.add_argument("--start", type=int, default=0, help="first frame of the cycle")
    ap.add_argument("--cycle", type=int, required=True, help="frames in one full walk cycle")
    ap.add_argument("--frames", type=int, default=8, help="frames to keep from the cycle")
    ap.add_argument("--height", type=int, default=122, help="character height in game pixels")
    ap.add_argument("--palette", help="sprite whose colours the frames are snapped to")
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

    pal_img = None
    if args.palette:
        # Representative colours of the reference sprite (opaque pixels only)
        src = np.asarray(Image.open(args.palette).convert("RGBA"))
        colours = src[..., :3][src[..., 3] > 0].reshape(1, -1, 3)
        pal_img = Image.fromarray(colours.astype(np.uint8), "RGB").quantize(colors=48, method=Image.Quantize.MEDIANCUT)

    smalls = []
    for rgb, mask in zip(frames, masks):
        rgb = rgb[y0:y1, x0:x1].copy()
        mask = mask[y0:y1, x0:x1]
        # despill green fringe
        rgb[..., 1] = np.where(rgb[..., 1] > np.maximum(rgb[..., 0], rgb[..., 2]),
                               np.maximum(rgb[..., 0], rgb[..., 2]), rgb[..., 1])
        img = Image.fromarray(rgb.clip(0, 255).astype(np.uint8), "RGB")
        alpha = Image.fromarray((mask * 255).astype(np.uint8), "L")
        small = np.asarray(img.resize((out_w, args.height), Image.BOX)).astype(float)
        small_a = np.asarray(alpha.resize((out_w, args.height), Image.BOX)) >= 128
        smalls.append((small, small_a))

    if args.palette:
        # One colour mapping for all frames (so they do not flicker), learned from
        # the character pixels of every frame against the reference sprite
        ref = np.asarray(Image.open(args.palette).convert("RGBA")).astype(float)
        ref_px = ref[..., :3][ref[..., 3] > 0]
        all_px = np.concatenate([sm[a] for sm, a in smalls])
        mapped = match_histograms(all_px, ref_px)
        k = 0
        for sm, a in smalls:
            n = int(a.sum())
            sm[a] = mapped[k:k + n]
            k += n

    sheet = Image.new("RGBA", (out_w * args.frames, args.height), (0, 0, 0, 0))
    for i, (sm, a) in enumerate(smalls):
        small = Image.fromarray(sm.clip(0, 255).astype(np.uint8), "RGB")
        if pal_img is not None:
            small = small.quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGB")
        frame = small.convert("RGBA")
        frame.putalpha(Image.fromarray((a * 255).astype(np.uint8), "L"))
        sheet.paste(frame, (i * out_w, 0))
    sheet.save(args.out)
    print(f"{args.frames} frames of {out_w}x{args.height} -> {args.out} (crop {x0},{y0} {x1 - x0}x{y1 - y0})")


if __name__ == "__main__":
    main()
