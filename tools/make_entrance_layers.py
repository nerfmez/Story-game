"""Cut the author's close view of the school entrance into paint layers for the 2.5D walk-in.

art_source/school_entrance_close.png (1672x941) is the entrance seen from the courtyard: canopy and
pillars, the stair hall (bench, straight stair between low walls, notice board and bins), the
covered walkway's end on the right, a shrub bed on the left, wet paving. scripts/school_entrance_3d.gd
builds it from boxes and cards at the depths measured from its perspective (horizon y 520, eye
1.08 m, 8 m in front of the pillars) and paints every face from the picture's own camera, so from
there the render is the picture and walking in makes the parts slide like the real place.

Everything is shrunk to game pixels first (640 wide: one texel per game pixel from that camera),
one palette, then:
  full.png    the picture
  back.png    with the things standing in front taken out and filled in (pillars, canopy front,
              bench, bins, pots, shrubs, walkway end): what the camera sees once they slide aside
  cutout.png  only those things (alpha), for their own cards

Usage:
  python3 tools/make_entrance_layers.py art_source/school_entrance_close.png assets/bg/school/entrance
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

SCALE = 640 / 1672
COLOURS, ACCENTS = 96, 32

# boxes in the source picture (px)
PILLARS = [(328, 196, 416, 634), (1214, 196, 1306, 634)]
CANOPY = (252, 128, 1398, 202)
BENCH = (446, 508, 640, 622)
BINS = (974, 512, 1192, 623)
POTS = [(232, 486, 324, 648), (1462, 496, 1554, 645), (424, 8, 508, 134)]
SHRUBS = (0, 545, 218, 802)
KERB = [(0, 778), (198, 718), (216, 726), (126, 800), (0, 802)]
WALKWAY = [(1346, 168), (1672, 168), (1672, 306), (1346, 306)]
POST = (1358, 286, 1402, 750)


def colour_mask(img, box, keep):
    """Mask inside box where keep(r, g, b) holds."""
    x0, y0, x1, y1 = box
    a = img[y0:y1, x0:x1].astype(int)
    m = np.zeros(img.shape[:2], bool)
    m[y0:y1, x0:x1] = keep(a[..., 0], a[..., 1], a[..., 2])
    return m


def masks(src):
    h, w = src.shape[:2]
    def rect(b):
        m = np.zeros((h, w), bool)
        m[b[1]:b[3], b[0]:b[2]] = True
        return m
    def poly(points):
        im = Image.new("L", (w, h), 0)
        ImageDraw.Draw(im).polygon(points, fill=255)
        return np.asarray(im) > 0
    wall_like = lambda r, g, b: (abs(r - g) < 14) & (b > g) & (r > 150)          # pale wall behind
    cut = {
        "bench": colour_mask(src, BENCH, lambda r, g, b: (r > b + 12) | ((r + g + b) < 210)),
        "bins": rect(BINS),
        "pots": np.logical_or.reduce([colour_mask(src, p, lambda r, g, b: ~wall_like(r, g, b)) for p in POTS]),
        "shrubs": colour_mask(src, SHRUBS, lambda r, g, b: (g > r + 12) & (g > b - 30)) | poly(KERB),
        "walkway": poly(WALKWAY) | rect(POST),
    }
    for k in ("bench", "pots", "shrubs"):
        cut[k] = cv2.morphologyEx(cut[k].astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)) > 0
    hide = np.logical_or.reduce(list(cut.values()) + [rect(p) for p in PILLARS] + [rect(CANOPY)])
    return cut, hide


def row_median(src, y0, y1, x0, x1):
    """Per-row median colour of a plain strip (no stripes from pipes or frames)."""
    return np.median(src[y0:y1, x0:x1].astype(float), axis=1)[:, None, :]


def fill_structured(src, cut):
    """Fill the big hidden areas from what continues next to them (full size, before shrinking);
    only small leftovers (post, shrub edges) are left to inpainting."""
    img = src.copy()
    done = np.zeros(src.shape[:2], bool)
    # pots first (small), so the walls copied next to them are clean
    # the pot on the 2nd-floor parapet: the parapet beside it carried across
    x0, y0, x1, y1 = POTS[2]
    img[y0:y1, x0:x1] = img[y0:y1, x0 - (x1 - x0):x0]
    pots = np.logical_or.reduce([np.pad(np.ones((y1 - y0, x1 - x0), bool), ((y0, src.shape[0] - y1), (x0, src.shape[1] - x1)))
                                 for x0, y0, x1, y1 in POTS[:2]]) & cut["pots"]
    pots = cv2.dilate(pots.astype(np.uint8) * 255, np.ones((7, 7), np.uint8))
    img = cv2.inpaint(np.ascontiguousarray(img), pots, 6, cv2.INPAINT_TELEA)
    done |= pots > 0
    done[y0:y1, x0:x1] = True
    clean = img.copy()
    # left pillar: the facade beside it (windows run on behind it); right pillar: plain wall
    x0, y0, x1, y1 = PILLARS[0]
    img[y0:y1, x0:x1] = clean[y0:y1, x0 - (x1 - x0):x0]
    x0, y0, x1, y1 = PILLARS[1]
    img[y0:y1, x0:x1] = row_median(clean, y0, y1, 1455, 1462).astype(np.uint8)
    for p in PILLARS:
        done[p[1]:p[3], p[0]:p[2]] = True
    # canopy front: the 2nd-floor parapet band above it, carried down
    x0, y0, x1, y1 = CANOPY
    band = clean[y0 - 30:y0, x0:x1]
    for v in range(y0, y1):
        img[v, x0:x1] = band[(v - y0) % 30]
    done[y0:y1, x0:x1] = True
    # bench: the hall's left wall above it carried down, the floor from further right
    x0, y0, x1, y1 = BENCH
    wall = clean[y0 - 20:y0, x0:x1]
    for v in range(y0, 600):
        img[v, x0:x1] = wall[(v - y0) % 20]
    img[600:y1, x0:x1] = clean[600:y1, x1 + 120:x1 + 120 + (x1 - x0)]
    done[y0:y1, x0:x1] |= cut["bench"][y0:y1, x0:x1]
    # bins: the plain wall left of them under the notice board, tiled across
    x0, y0, x1, y1 = BINS
    img[y0:y1, x0:x1] = row_median(clean, y0, y1, 932, 972).astype(np.uint8)
    done[y0:y1, x0:x1] = True
    # walkway end: the facade wall left of it, as plain rows
    wx0, wy0, wx1, wy1 = 1346, 168, 1672, 306
    img[wy0:wy1, wx0:wx1] = row_median(clean, wy0, wy1, 1300, 1346).astype(np.uint8)
    done[wy0:wy1, wx0:wx1] = True
    return img, done


def shrink(img, size):
    pic = Image.fromarray(img)
    return np.array(pic.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA"))


def palette(rgb):
    px = rgb.reshape(-1, 3)
    sat = px.max(1).astype(int) - px.min(1)
    warm = (px[:, 1] > px[:, 2]) | (px[:, 0] > px[:, 2])
    colours = []
    for sel, n in ((px, COLOURS), (px[(sat > 30) & warm], ACCENTS)):
        q = Image.fromarray(sel.reshape(1, -1, 3)).quantize(n, method=Image.Quantize.MEDIANCUT,
                                                              dither=Image.Dither.NONE)
        colours += q.getpalette()[:n * 3]
    pal = Image.new("P", (1, 1))
    pal.putpalette(colours + [0] * (768 - len(colours)))
    return pal


def quantize(rgba, pal):
    rgb = Image.fromarray(rgba[..., :3]).quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    return np.dstack([np.asarray(rgb), rgba[..., 3]])


def main():
    src = np.asarray(Image.open(sys.argv[1]).convert("RGB"))
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    h, w = src.shape[:2]
    size = (round(w * SCALE), round(h * SCALE))
    cut, hide = masks(src)
    rgba = np.dstack([src, np.full((h, w), 255, np.uint8)])
    full = shrink(rgba, size)
    pal = palette(full[..., :3])
    small = lambda m: np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize(size, Image.BILINEAR)) > 100
    # full picture
    Image.fromarray(quantize(full, pal)).save(os.path.join(out, "full.png"))
    # cutouts: only the standing things
    any_cut = small(np.logical_or.reduce(list(cut.values())))
    co = full.copy()
    co[..., 3] = np.where(any_cut, 255, 0)
    Image.fromarray(quantize(co, pal)).save(os.path.join(out, "cutout.png"))
    # back: filled where they stood: big areas from their surroundings, the rest inpainted
    filled, done = fill_structured(src, cut)
    back = shrink(np.dstack([filled, np.full((h, w), 255, np.uint8)]), size)
    rest = small(hide & ~done)
    hole = cv2.dilate(rest.astype(np.uint8) * 255, np.ones((3, 3), np.uint8))
    back[..., :3] = cv2.inpaint(np.ascontiguousarray(back[..., :3]), hole, 4, cv2.INPAINT_TELEA)
    Image.fromarray(quantize(back, pal)).save(os.path.join(out, "back.png"))
    print(f"{size[0]}x{size[1]} full/back/cutout -> {out}")


if __name__ == "__main__":
    main()
