"""Split the author's school-building elevation into depth layers for the 2.5D model.

art_source/school_building.png (2168x725, RGBA) is a flat front view of the 3-storey school block.
scripts/school_building_3d.gd builds the block from boxes at real depths and paints every face by
projecting this picture onto it from the design camera, so from that camera the render is the picture
itself; move the camera a little and the parts slide over each other like a real building.

Each depth needs the picture without the parts that stand in front of it (what is revealed when they
slide aside):
  front.png  the picture as is: entrance canopy, its pillars, the steps and the roof (frontmost)
  mid.png    canopy group filled in: pillars, parapets, the plinth (the corridor's front edge, z 0)
  back.png   pillars, parapets and the bench filled in too: classroom walls, ceilings, the stair hall
  props.png  only the bench (alpha), stood a little in front of the stair passage
  hall.png   the ground-floor stair hall of back.png at full size (HALL_CROP), for walking in

Fill: wall behind a pillar is continued from the bay beside it (not the stair-hall side); behind a
parapet the wall above is carried down and smoothed; small leftovers use OpenCV inpainting.
Pixel boxes here are the same ones school_building_3d.gd uses for the geometry.

Pixel art: every layer is shrunk to the game's pixel size (PIXEL = 0.48: 24 px per metre, so with the
view's 15 m frame one texel is one game pixel at rest), alpha cut hard, and all layers mapped to one
shared palette without dithering, then read with nearest filtering like the other backgrounds.

Usage:
  python3 tools/make_building_layers.py art_source/school_building.png assets/bg/school/building
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

# pillars (x0, x1) running from the eaves to the ground; the hall pair stops on the canopy
PILLARS = [(73, 109), (372, 398), (650, 675), (921, 945), (1220, 1245), (1490, 1515), (1769, 1794),
           (2057, 2094)]
HALL = (945, 1220)                       # stair hall opening between its pillars
PARAPETS = [(271, 329), (435, 496)]      # rows: 3rd / 2nd floor parapet incl. slab edge
PLINTH = (645, 668)
EAVE_BOTTOM = 157                        # soffit row; pillars and walls start below it
CANOPY = (884, 1284, 463, 497)           # slab incl. its soffit (x0, x1, y0, y1)
CANOPY_PILLARS = [(912, 942), (1225, 1252)]
STEPS = (898, 1266, 645, 668)
HALL_CROP = (900, 470, 1260, 668)        # stair hall, kept full size in hall.png
BENCH = (948, 1028, 602, 647)            # bench in front of the stair passage: its own card (props.png)
BENCH_FLOOR = 632                        # where the passage wall meets the floor behind the bench


PIXEL = 0.48
COLOURS = 96                             # shared palette: the bluish building
ACCENTS = 32                             # + colours kept for the few saturated things (plants, bins, bench)


def pixelate(img, palette):
    """Shrink to game pixels (premultiplied, no dark fringes), hard alpha, shared palette."""
    pic = Image.fromarray(img)
    size = (round(pic.width * PIXEL), round(pic.height * PIXEL))
    small = pic.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    rgb = small.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")
    rgb.putalpha(alpha)
    return rgb


def make_palette(img):
    pic = Image.fromarray(img)
    small = pic.convert("RGBa").resize((round(pic.width * PIXEL), round(pic.height * PIXEL)), Image.LANCZOS)
    opaque = np.asarray(small.convert("RGBA"))
    px = opaque[opaque[..., 3] >= 128][:, :3]
    sat = px.max(1).astype(int) - px.min(1)
    warm = (px[:, 1] > px[:, 2]) | (px[:, 0] > px[:, 2])           # not blue-dominant: greens, ambers, wood
    colours = []
    for sel, n in ((px, COLOURS), (px[(sat > 30) & warm], ACCENTS)):
        q = Image.fromarray(sel.reshape(1, -1, 3)).quantize(n, method=Image.Quantize.MEDIANCUT,
                                                              dither=Image.Dither.NONE)
        colours += q.getpalette()[:n * 3]
    pal = Image.new("P", (1, 1))
    pal.putpalette(colours + [0] * (768 - len(colours)))
    return pal


def fill_from_side(img, x0, x1, y0, y1, side):
    """Continue the wall beside a narrow box across it (copy the strip next to it, feathered)."""
    w, gap = x1 - x0, 14                 # skip the corner shading painted right next to the pillar
    src = img[y0:y1, x0 - w - gap:x0 - gap] if side < 0 else img[y0:y1, x1 + gap:x1 + w + gap]
    img[y0:y1, x0:x1] = src


def fill_rows(img, y0, y1, wall):
    """Behind a parapet: plain lower wall (the wall colour, a little grain) and a darker floor strip."""
    h, w = y1 - y0, img.shape[1]
    rng = np.random.default_rng(y0)
    grain = cv2.GaussianBlur(rng.normal(0, 4, (h, w)).astype(np.float32), (0, 0), 2)[..., None]
    band = wall[None, None] + grain
    floor = max(h - 10, 0)
    band[floor:] *= 0.72
    img[y0:y1, :, :3] = np.clip(band, 0, 255).astype(np.uint8)
    img[y0:y1, :, 3] = np.where(img[y0:y1, :, 3] > 0, 255, 0)


def wall_colour(img, y0):
    """Shaded corridor wall just above a parapet: median of the mid-bright pixels (not windows/doors)."""
    px = img[y0 - 30:y0 - 4, 120:2050, :3].reshape(-1, 3).astype(float)
    lum = px.mean(1)
    return np.median(px[(lum > 70) & (lum < 150)], axis=0) * 0.9


def inpaint(img, mask):
    rgb = cv2.inpaint(np.ascontiguousarray(img[..., :3]), mask, 5, cv2.INPAINT_TELEA)
    img[..., :3] = np.where(mask[..., None] > 0, rgb, img[..., :3])


def main():
    src = np.asarray(Image.open(sys.argv[1]).convert("RGBA")).copy()
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    palette = make_palette(src)

    def save(img, name):
        pixelate(img, palette).save(os.path.join(out, name + ".png"))

    save(src, "front")

    # mid: what the corridor front (pillars, parapets) shows once the canopy group slides aside
    mid = src.copy()
    mask = np.zeros(src.shape[:2], np.uint8)
    x0, x1, y0, y1 = CANOPY
    mask[y0:y1, x0:x1] = 255
    for a, b in CANOPY_PILLARS:
        mask[y1:PLINTH[0], a - 2:b + 2] = 255
    sx0, sx1, sy0, sy1 = STEPS
    mask[sy0:sy1, sx0:sx1] = 255
    # the 2nd-floor parapet runs on behind the canopy: its hidden rows copied from a plain bay
    py1 = PARAPETS[1][1]
    mid[y0:py1, x0:x1] = np.tile(mid[y0:py1, 400:648], (1, 2, 1))[:, :x1 - x0]
    mask[y0:py1, x0:x1] = 0
    # under the canopy: ground-floor wall of the bays either side; hall interior stays (it is deeper)
    inpaint(mid, mask)
    mid[..., 3] = np.where(mask > 0, 255, mid[..., 3])
    save(mid, "mid")

    # back: also without pillars, parapets and plinth
    back = mid.copy()
    for a, b in PILLARS:
        # take the bay on the left, except the outer corner and the hall's right pillar (bay on the right)
        side = 1 if a < 120 or a == HALL[1] else -1
        hall = b == HALL[0] or a == HALL[1]      # the hall pair stops on the canopy (canopy pillars below)
        fill_from_side(back, a, b, EAVE_BOTTOM, CANOPY[2] if hall else PLINTH[0], side)
    # bench: cut out to its own card
    bx0, bx1, by0, by1 = BENCH
    box = src[by0:by1, bx0:bx1, :3].astype(int)
    wood = box[..., 0] > box[..., 2] + 15
    legs = (box.mean(2) < 60) & (np.arange(by1 - by0)[:, None] > 26)
    bench = cv2.dilate((wood | legs).astype(np.uint8) * 255, np.ones((3, 3), np.uint8))
    props = np.zeros_like(src)
    props[by0:by1, bx0:bx1] = src[by0:by1, bx0:bx1]
    props[by0:by1, bx0:bx1, 3] = bench
    save(props, "props")
    mask = np.zeros(src.shape[:2], np.uint8)
    mask[by0:by1, bx0:bx1] = cv2.dilate(bench, np.ones((5, 5), np.uint8))
    # behind the bench: the passage's left wall carried down from just above it, and the floor
    # from the same rows further along the passage (the camera walks in and sees this up close)
    fill = back.copy()
    wall = back[by0 - 14:by0, bx0:bx1]
    for v in range(by0, BENCH_FLOOR):
        fill[v, bx0:bx1] = wall[(v - by0) % wall.shape[0]]
    fill[BENCH_FLOOR:by1, bx0:bx1] = back[BENCH_FLOOR:by1, bx0 + 90:bx1 + 90]
    on = mask > 0
    back[on] = fill[on]
    for y0, y1 in PARAPETS + [PLINTH]:
        fill_rows(back, y0, y1, wall_colour(src, y0))
    save(back, "back")
    # the stair hall at full size (no shrinking): the camera walks into it, so it is seen up close
    hx0, hy0, hx1, hy1 = HALL_CROP
    Image.fromarray(back[hy0:hy1, hx0:hx1]).save(os.path.join(out, "hall.png"))
    print(f"front/mid/back/hall -> {out}")


if __name__ == "__main__":
    main()
