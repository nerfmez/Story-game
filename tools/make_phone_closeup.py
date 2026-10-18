"""Close-up of the hero's phone (lock screen showing the time) as pixel art finer than the scene.

The scene is drawn at 640x360 game pixels; this picture is shown at 2/3 scale (one picture
pixel = 2/3 of a game pixel, 2 screen pixels at 3x), so it reads as a closer, more detailed shot
while staying pixel art.

  1. key out the green screen of the hand-and-phone drawing
  2. lay a lock screen (dark gradient + the time) onto the black screen, following the phone's
     tilt, only where the screen shows (the thumb stays in front)
  3. shrink to the target size, few colours, hard alpha edge

Usage:
  python3 tools/make_phone_closeup.py art_source/phone_hand_greenscreen.png assets/ui/phone_closeup.png --time 7:35 --height 495 --colours 32
"""
import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

FONT = Path(__file__).resolve().parent.parent / "assets/fonts/Sarabun-Regular.ttf"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--time", default="7:35")
    ap.add_argument("--height", type=int, default=660, help="output height in picture pixels")
    ap.add_argument("--colours", type=int, default=64)
    args = ap.parse_args()

    img = np.asarray(Image.open(args.src).convert("RGB")).astype(np.float32)
    h, w = img.shape[:2]
    green = img[..., 1] - np.maximum(img[..., 0], img[..., 2])
    alpha = np.clip((110 - green) / 60, 0, 1)
    dark = (img.sum(-1) < 90) & (alpha > 0.5)              # before the spill fix turns the green dark
    spill = np.minimum(img[..., 1], np.maximum(img[..., 0], img[..., 2]) + 8)
    img[..., 1] = np.where(alpha < 1, spill, img[..., 1])

    # the phone's black screen: the largest dark area
    lab, n = ndimage.label(dark)
    screen = lab == (np.argmax(ndimage.sum(dark, lab, range(1, n + 1))) + 1)
    ys, xs = np.nonzero(screen)
    # tilt from the top edge: topmost screen pixel of each column, fitted with a line
    # (only columns well inside the top edge: the rounded corners and the sides would bend it)
    tops = {}
    for x, y in zip(xs, ys):
        if y < tops.get(x, 1 << 30):
            tops[x] = y
    top_x = np.array(sorted(tops)); top_y = np.array([tops[x] for x in top_x])
    near_top = top_y < top_y.min() + (ys.max() - ys.min()) * 0.12
    cols = top_x[near_top]
    inner = (cols > np.percentile(cols, 25)) & (cols < np.percentile(cols, 75))
    slope = np.polyfit(cols[inner], top_y[near_top][inner], 1)[0]
    tilt = math.atan(slope)
    c, s = math.cos(-tilt), math.sin(-tilt)
    u = xs * c - ys * s
    v = xs * s + ys * c
    # the screen as an upright rectangle (rounded corners don't change its bounding box)
    u0, u1, v0, v1 = np.percentile(u, 0.2), np.percentile(u, 99.8), np.percentile(v, 0.2), np.percentile(v, 99.8)
    sw, sh = int(u1 - u0), int(v1 - v0)

    # lock screen, upright
    grad = np.linspace(0, 1, sh)[:, None]
    top, bottom = np.array([28, 34, 58]), np.array([12, 14, 26])
    rows = top * (1 - grad) + bottom * grad                       # (sh, 3)
    lock = Image.fromarray(np.broadcast_to(rows[:, None, :], (sh, sw, 3)).astype(np.uint8))
    draw = ImageDraw.Draw(lock)
    font = ImageFont.truetype(str(FONT), int(sw * 0.36))
    tb = draw.textbbox((0, 0), args.time, font=font)
    tx = (sw - (tb[2] - tb[0])) / 2 - tb[0]
    ty = sh * 0.17 - tb[1]
    draw.text((tx, ty), args.time, font=font, fill=(236, 240, 250))

    # place it: every screen pixel looks up its spot on the upright lock screen
    yy, xx = np.nonzero(np.ones((h, w), bool))
    uu = xx * c - yy * s - u0
    vv = xx * s + yy * c - v0
    lock_a = np.asarray(lock).astype(np.float32)
    ui = np.clip(uu.astype(int), 0, sw - 1)
    vi = np.clip(vv.astype(int), 0, sh - 1)
    placed = lock_a[vi, ui].reshape(h, w, 3)
    soft = ndimage.binary_dilation(screen, iterations=2)
    img = np.where(soft[..., None], placed, img)

    rgba = np.dstack([img, alpha * 255]).clip(0, 255).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    ow = round(w * args.height / h)
    out = out.resize((ow, args.height), Image.BOX)
    a = np.asarray(out)[..., 3]
    rgb = out.convert("RGB").quantize(args.colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    final = np.dstack([np.asarray(rgb), np.where(a >= 128, 255, 0)]).astype(np.uint8)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(final, "RGBA").save(args.out)
    print(f"tilt {math.degrees(tilt):.1f} deg, screen {sw}x{sh}, out {ow}x{args.height} -> {args.out}")


if __name__ == "__main__":
    main()
