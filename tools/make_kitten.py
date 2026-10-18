"""Draw the rain-soaked kitten on the way to the crossing (pixel art, drawn from shapes).

Each frame is drawn 8x larger from simple shapes (body, head, ears, tail, legs, white chest and
paws, eyes) as material labels, shrunk to game pixels by taking the material that covers most of each
pixel (no blended colours, so no stray specks), and given a 1 px dark outline like the other sprites. Grey tabby, fur darkened by the rain. Faces right; the game flips it to run left.

  frames 0-3: sitting, looking at the boy (tail tip flicks, a blink on frame 2)
  frames 4-9: running: one gallop stride (stretch, front feet land, gather with the back arched,
              hind feet push, launch), each leg placed by hand per frame

Usage:
  python3 tools/make_kitten.py assets/characters/kitten.png
"""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

SC = 1.3               # shapes below are laid out on a 32x24 frame; drawn this much bigger
W, H = round(32 * SC), round(24 * SC)   # frame, game pixels
K = 8                  # drawing scale
FUR = (112, 114, 128)
FUR_DARK = (84, 85, 99)
STRIPE = (66, 66, 80)
WHITE = (226, 224, 232)
EYE = (196, 214, 104)
NOSE = (214, 140, 150)
OUTLINE = (34, 30, 44)


PALETTE = [None, FUR, FUR_DARK, STRIPE, WHITE, EYE, NOSE, OUTLINE]


def blank():
    im = Image.new("L", (W * K, H * K), 0)
    d = ImageDraw.Draw(im)
    # colours below are drawn as their label (index in PALETTE)
    return im, Labels(d)


class Labels:
    def __init__(self, d):
        self.d = d

    def ellipse(self, box, fill):
        self.d.ellipse(box, fill=PALETTE.index(fill))

    def polygon(self, pts, fill):
        self.d.polygon(pts, fill=PALETTE.index(fill))

    def line(self, pts, fill, width, joint=None):
        self.d.line(pts, fill=PALETTE.index(fill), width=width, joint=joint)


U = K * SC             # drawing pixels per layout unit


def e(d, cx, cy, rx, ry, col):
    d.ellipse([(cx - rx) * U, (cy - ry) * U, (cx + rx) * U, (cy + ry) * U], fill=col)


def poly(d, pts, col):
    d.polygon([(x * U, y * U) for x, y in pts], fill=col)


def line(d, pts, col, width):
    d.line([(x * U, y * U) for x, y in pts], fill=col, width=int(width * U), joint="curve")
    for x, y in (pts[0], pts[-1]):
        r = width * U / 2
        d.ellipse([x * U - r, y * U - r, x * U + r, y * U + r], fill=col)


def head(d, cx, cy, blink=False):
    poly(d, [(cx - 3.6, cy - 1.5), (cx - 3.2, cy - 6.0), (cx - 0.8, cy - 2.8)], FUR)   # ears
    poly(d, [(cx + 3.6, cy - 1.5), (cx + 3.2, cy - 6.0), (cx + 0.8, cy - 2.8)], FUR)
    poly(d, [(cx - 3.0, cy - 2.2), (cx - 2.9, cy - 4.6), (cx - 1.4, cy - 2.9)], NOSE)
    poly(d, [(cx + 3.0, cy - 2.2), (cx + 2.9, cy - 4.6), (cx + 1.4, cy - 2.9)], NOSE)
    e(d, cx, cy, 4.0, 3.4, FUR)
    line(d, [(cx - 0.9, cy - 3.2), (cx - 0.6, cy - 1.8)], STRIPE, 0.7)                 # forehead stripes
    line(d, [(cx + 0.9, cy - 3.2), (cx + 0.6, cy - 1.8)], STRIPE, 0.7)
    e(d, cx, cy + 1.5, 2.2, 1.5, WHITE)                                               # muzzle
    if blink:
        line(d, [(cx - 2.4, cy - 0.2), (cx - 1.0, cy - 0.2)], OUTLINE, 0.6)
        line(d, [(cx + 1.0, cy - 0.2), (cx + 2.4, cy - 0.2)], OUTLINE, 0.6)
    else:
        e(d, cx - 1.7, cy - 0.3, 0.9, 1.0, EYE)
        e(d, cx + 1.7, cy - 0.3, 0.9, 1.0, EYE)
        e(d, cx - 1.6, cy - 0.2, 0.35, 0.75, OUTLINE)
        e(d, cx + 1.8, cy - 0.2, 0.35, 0.75, OUTLINE)
    e(d, cx, cy + 0.9, 0.6, 0.4, NOSE)


def sitting(i):
    im, d = blank()
    flick = [0.0, 1.2, 2.0, 0.6][i]
    # tail lying round the front, tip lifting
    line(d, [(9.5, 21.0), (6.5, 21.4), (4.5, 19.8), (4.0, 17.8 - flick)], FUR_DARK, 2.2)
    e(d, 14.0, 17.0, 6.2, 5.6, FUR)                                                   # body
    e(d, 13.0, 19.6, 5.6, 3.2, FUR_DARK)                                              # shade under
    for x in (10.5, 13.0):                                                            # back stripes
        line(d, [(x, 12.4), (x - 1.2, 15.0)], STRIPE, 0.9)
    e(d, 17.6, 17.4, 2.6, 4.0, WHITE)                                                 # chest
    line(d, [(16.2, 17.5), (16.0, 22.0)], FUR, 1.7)                                   # front legs
    line(d, [(19.0, 17.5), (19.0, 22.0)], FUR, 1.7)
    e(d, 16.0, 22.2, 1.2, 0.8, WHITE)
    e(d, 19.0, 22.2, 1.2, 0.8, WHITE)
    head(d, 18.6, 9.6, blink=i == 2)
    return im


# gallop, one stride in 6 frames: (body y, body length, spine arch, front near/far feet, hind near/far feet, tail lift)
# feet are (x, y) in the 32x24 layout, ground at y = 22; far legs are drawn darker, behind the body
GALLOP = [
    # 0: fully stretched, flying: front legs reach forward, hind legs kick back
    (14.6, 8.4, 0.0, (25.6, 19.6), (24.0, 20.6), (4.0, 19.8), (5.6, 20.8), 0.0),
    # 1: front feet land one after the other, hind legs swing forward
    (15.4, 7.8, 0.4, (22.6, 22.0), (24.4, 21.2), (7.6, 20.0), (6.2, 21.0), 0.6),
    # 2: gathered: front feet push back under the chest, hind feet reach under the belly, back arched
    (14.2, 6.6, 1.6, (18.4, 22.0), (19.8, 22.0), (13.6, 21.6), (12.4, 22.0), 1.4),
    # 3: hind feet land and push, front feet leave the ground
    (14.0, 6.8, 1.2, (17.2, 20.4), (18.8, 21.4), (11.2, 22.0), (12.6, 22.0), 1.0),
    # 4: launching: front legs swing forward, hind legs straighten behind
    (14.4, 7.6, 0.4, (21.6, 19.8), (20.2, 20.8), (7.4, 22.0), (8.8, 21.6), 0.4),
    # 5: almost stretched
    (14.4, 8.2, 0.0, (24.4, 19.4), (22.8, 20.4), (5.0, 20.6), (6.6, 21.6), 0.0),
]


def leg(d, top, foot, col, knee_back):
    """Two-segment leg from the body to the foot, knee pushed sideways (front legs bend back,
    hind legs forward at the hock), white paw."""
    mx, my = (top[0] + foot[0]) / 2, (top[1] + foot[1]) / 2
    knee = (mx + knee_back, my)
    line(d, [top, knee, foot], col, 1.6)
    e(d, foot[0] + (0.4 if knee_back < 0 else -0.4), foot[1] - 0.4, 1.0, 0.65, WHITE)


def running(i):
    im, d = blank()
    by, length, arch, fn, ff, hn, hf, tail = GALLOP[i]
    cx = 14.6
    shoulder = (cx + length * 0.62, by + 0.8)
    hip = (cx - length * 0.62, by + 0.6)
    # far legs first (darker, behind)
    leg(d, (shoulder[0] - 0.8, shoulder[1]), ff, FUR_DARK, -0.9)
    leg(d, (hip[0] + 0.8, hip[1]), hf, FUR_DARK, 1.0)
    # tail streams up behind
    line(d, [(hip[0] - 0.4, by - 0.8), (hip[0] - 3.0, by - 2.6 - tail), (hip[0] - 4.2, by - 5.4 - tail * 0.6)], FUR_DARK, 1.8)
    # body (arched back = taller middle), shade underneath, stripes
    e(d, cx, by - arch * 0.5, length, 3.4 + arch * 0.4, FUR)
    e(d, cx, by + 1.8, length - 0.8, 1.5, FUR_DARK)
    for k in (-0.45, -0.1, 0.25):
        x = cx + k * length
        line(d, [(x, by - 3.0 - arch * 0.7), (x - 0.8, by - 0.9)], STRIPE, 0.9)
    e(d, shoulder[0] + 0.6, by + 1.0, 1.9, 1.7, WHITE)                                  # chest
    leg(d, shoulder, fn, FUR, -0.9)
    leg(d, hip, hn, FUR, 1.0)
    head(d, cx + length * 0.95 + 0.6, by - 3.8 - arch * 0.3)
    return im


def finish(big):
    """Shrink to game pixels (each pixel = the label covering most of it; small details like eyes and
    nose win when they cover a quarter), then a 1 px outline round the shape."""
    lab = np.asarray(big).reshape(H, K, W, K).transpose(0, 2, 1, 3).reshape(H, W, K * K)
    counts = np.stack([(lab == i).sum(-1) for i in range(len(PALETTE))], -1).astype(float)
    small_detail = [PALETTE.index(c) for c in (EYE, NOSE, OUTLINE, WHITE)]
    counts[..., small_detail] *= 2.0
    idx = counts.argmax(-1)
    alpha = (counts[..., 0] < K * K / 2) & (idx > 0)
    idx = np.where(idx == 0, counts[..., 1:].argmax(-1) + 1, idx)
    out = np.zeros((H, W, 4), np.uint8)
    for i, col in enumerate(PALETTE[1:], 1):
        out[idx == i, :3] = col
    out[..., 3] = alpha * 255
    grown = alpha.copy()
    grown[1:] |= alpha[:-1]
    grown[:-1] |= alpha[1:]
    grown[:, 1:] |= alpha[:, :-1]
    grown[:, :-1] |= alpha[:, 1:]
    ring = grown & ~alpha
    out[ring] = (*OUTLINE, 255)
    return Image.fromarray(out, "RGBA")


def main():
    frames = [sitting(i) for i in range(4)] + [running(i) for i in range(6)]
    sheet = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(finish(f), (i * W, 0))
    out = sys.argv[1] if len(sys.argv) > 1 else "kitten.png"
    sheet.save(out)
    print(f"{len(frames)} frames of {W}x{H} -> {out}")


if __name__ == "__main__":
    main()
