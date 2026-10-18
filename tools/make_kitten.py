"""Draw the rain-soaked kitten on the way to the crossing (pixel art, drawn from shapes).

Each frame is drawn 8x larger from simple shapes (body, head, ears, tail, legs, white chest and
paws, eyes) as material labels, shrunk to game pixels by taking the material that covers most of each
pixel (no blended colours, so no stray specks), and given a 1 px dark outline like the other sprites. Grey tabby, fur darkened by the rain. Faces right; the game flips it to run left.

  frames 0-3: sitting, looking at the boy (tail tip flicks, a blink on frame 2)
  frames 4-9: running (gallop: legs gather and stretch, body and tail bob)

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


def running(i):
    im, d = blank()
    p = i / 6.0 * 2.0 * math.pi
    stretch = 0.5 + 0.5 * math.cos(p)                 # 1 = stretched out, 0 = legs gathered
    bob = -1.2 * math.sin(p)
    body_y = 15.0 + bob
    # tail streams up behind
    line(d, [(8.0, body_y - 0.5), (5.0, body_y - 3.0 - stretch), (3.4, body_y - 6.0 + bob * 0.5)], FUR_DARK, 1.9)
    back = (9.0 - 2.2 * stretch, 9.0 + 2.0 * (1 - stretch))       # hind feet x (stretched / gathered)
    front = (22.5 + 2.4 * stretch, 18.5 - 2.4 * (1 - stretch))
    foot_y = 22.0
    for hx, ox in ((back[0], 0.0), (back[1], 1.4)):
        line(d, [(10.5 + ox * 0.5, body_y + 1.0), (hx + ox, foot_y - 1.5), (hx + ox - 0.8, foot_y)], FUR_DARK, 1.7)
    e(d, 14.5, body_y, 7.4 + stretch * 0.8, 3.6, FUR)                                 # body
    e(d, 14.5, body_y + 1.9, 6.6, 1.6, FUR_DARK)
    for x in (11.0, 13.6, 16.2):
        line(d, [(x, body_y - 3.2), (x - 0.8, body_y - 1.0)], STRIPE, 0.9)
    e(d, 19.6, body_y + 1.2, 2.0, 1.8, WHITE)                                         # chest
    for fx, ox in ((front[0], 0.0), (front[1], -1.3)):
        line(d, [(19.5 + ox * 0.3, body_y + 1.0), (fx + ox, foot_y - 1.0)], FUR, 1.6)
        e(d, fx + ox, foot_y - 0.6, 1.0, 0.7, WHITE)
    head(d, 23.4, body_y - 4.2 + bob * 0.3)
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
