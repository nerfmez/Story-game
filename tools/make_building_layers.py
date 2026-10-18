"""Paint layers for the school model, cut from the author's facade painting.

art_source/school_building.png (2168x725, RGBA) is a flat front view of the 3-storey school block,
50 px per metre. scripts/school_model_3d.gd builds the whole school as one solid model and lays these
layers straight onto its front faces at that size (no viewpoint projection: they are the faces'
own paint, so the model looks right from anywhere a scene walks to):
  front.png  the picture as is: canopy, its pillars, steps, eaves and roof
  mid.png    canopy group filled in: corridor pillars, parapets, the plinth
  back.png   pillars, parapets and the bench filled in too: the classroom walls behind the corridors
  props.png  only the bench (alpha), a standing card in the stair hall

The entrance is the author's close view (art_source/school_entrance_close.png) scaled in, so the
canopy, stair hall, board and bins are the same wherever they are seen from.

Fill: wall behind a pillar is continued from the bay beside it (not the stair-hall side); behind a
parapet a plain lower wall; small leftovers use OpenCV inpainting.
Pixel art: one shared palette without dithering, read with sharp-bilinear filtering.

Usage:
  python3 tools/make_building_layers.py art_source/school_building.png assets/bg/school/model \
          art_source/school_entrance_close.png
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
# the entrance as the author's close view draws it (pasted in by entrance(), boxes in facade px)
CANOPY = (884, 1284, 471, 497)           # slab incl. its soffit (x0, x1, y0, y1)
CANOPY_PILLARS = [(912, 943), (1210, 1242)]
STEPS = (898, 1265, 650, 668)
BENCH = (950, 1023, 602, 646)            # bench in front of the stair passage: its own card (props.png)
BENCH_FLOOR = 640                        # where the passage wall meets the floor behind it

# art_source/school_entrance_close.png scaled into the facade: its pillars' outer edges (328, 1306)
# land on the facade's canopy pillars, its lowest step (y 692) on the ground (668); the canopy
# then spans 885-1284 like the facade's, and the hall's board wall starts at the passage end (1122)
ENTRANCE_SCALE = 0.348
ENTRANCE_AT = (912.0, 668.0)             # facade px of close-view px (328, 692)
ENTRANCE_PARTS = [(252, 128, 1398, 202),  # canopy (close-view px)
                  (328, 202, 1306, 642),  # pillars and the stair hall between them
                  (290, 642, 1340, 692)]  # entrance steps


PIXEL = 1.0                              # full size: 50 px per metre on the model
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


def entrance(src, path):
    """Paste the author's close view of the entrance into the facade (same entrance in both views)."""
    close = Image.open(path).convert("RGB")
    size = (round(close.width * ENTRANCE_SCALE), round(close.height * ENTRANCE_SCALE))
    small = np.asarray(close.resize(size, Image.LANCZOS))
    ox = ENTRANCE_AT[0] - 328 * ENTRANCE_SCALE
    oy = ENTRANCE_AT[1] - 692 * ENTRANCE_SCALE
    out = src.copy()
    for x0, y0, x1, y1 in ENTRANCE_PARTS:
        a0, b0 = round(x0 * ENTRANCE_SCALE), round(y0 * ENTRANCE_SCALE)
        a1, b1 = round(x1 * ENTRANCE_SCALE), round(y1 * ENTRANCE_SCALE)
        u, v = round(ox + a0), round(oy + b0)
        out[v:v + b1 - b0, u:u + a1 - a0, :3] = small[b0:b1, a0:a1]
        out[v:v + b1 - b0, u:u + a1 - a0, 3] = 255
    return out


def main():
    src = np.asarray(Image.open(sys.argv[1]).convert("RGBA")).copy()
    if len(sys.argv) > 3:
        src = entrance(src, sys.argv[3])
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
    # canopy pillars: plain rows of the wall beside them (left: facade past the pot, right: the
    # board wall inside the hall), so no pot or door is copied
    for (a, b), (s0, s1) in zip(CANOPY_PILLARS, ((852, 876), (1124, 1135))):
        rows = np.median(mid[y1:PLINTH[0], s0:s1].astype(float), axis=1)[:, None, :]
        mid[y1:PLINTH[0], a - 2:b + 2] = rows.astype(np.uint8)
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
    # bench: cut out to its own card, the passage floor and wall behind it inpainted
    bx0, bx1, by0, by1 = BENCH
    box = src[by0:by1, bx0:bx1, :3].astype(int)
    # everything in the box that is not the bluish wall/floor behind it
    wall_like = (box[..., 2] > box[..., 0] + 12) & (box.mean(2) > 75)
    bench = cv2.morphologyEx((~wall_like).astype(np.uint8) * 255, cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
    props = np.zeros_like(src)
    props[by0:by1, bx0:bx1] = src[by0:by1, bx0:bx1]
    props[by0:by1, bx0:bx1, 3] = bench
    save(props, "props")
    # behind it: the passage wall above carried down, the floor from further along the passage
    wall = back[by0 - 10:by0, bx0:bx1].copy()
    for v in range(by0, BENCH_FLOOR):
        back[v, bx0:bx1] = wall[(v - by0) % 10]
    back[BENCH_FLOOR:by1, bx0:bx1] = back[BENCH_FLOOR:by1, bx1 + 40:bx1 + 40 + (bx1 - bx0)]
    for y0, y1 in PARAPETS + [PLINTH]:
        fill_rows(back, y0, y1, wall_colour(src, y0))
    save(back, "back")
    print(f"front/mid/back -> {out}")


if __name__ == "__main__":
    main()
