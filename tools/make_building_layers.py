"""Split the author's school-building elevation into depth layers for the 2.5D model.

art_source/school_building.png (2168x725, RGBA) is a flat front view of the 3-storey school block.
scripts/school_building_3d.gd builds the block from boxes at real depths and paints every face by
projecting this picture onto it from the design camera, so from that camera the render is the picture
itself; move the camera a little and the parts slide over each other like a real building.

Each depth needs the picture without the parts that stand in front of it (what is revealed when they
slide aside):
  front.png  the picture as is: entrance canopy, its pillars, the steps and the roof (frontmost)
  mid.png    canopy group filled in: pillars, parapets, the plinth (the corridor's front edge, z 0)
  back.png   pillars and parapets filled in too: classroom walls, ceilings, the stair hall (z -2.5 / -7)

Fill: wall behind a pillar is continued from the bay beside it (not the stair-hall side); behind a
parapet the wall above is carried down and smoothed; small leftovers use OpenCV inpainting.
Pixel boxes here are the same ones school_building_3d.gd uses for the geometry.

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
    Image.fromarray(src).save(os.path.join(out, "front.png"))

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
    Image.fromarray(mid).save(os.path.join(out, "mid.png"))

    # back: also without pillars, parapets and plinth
    back = mid.copy()
    for a, b in PILLARS:
        # take the bay on the left, except the outer corner and the hall's right pillar (bay on the right)
        side = 1 if a < 120 or a == HALL[1] else -1
        fill_from_side(back, a, b, EAVE_BOTTOM, PLINTH[0], side)
    for y0, y1 in PARAPETS + [PLINTH]:
        fill_rows(back, y0, y1, wall_colour(src, y0))
    Image.fromarray(back).save(os.path.join(out, "back.png"))
    print(f"front/mid/back -> {out}")


if __name__ == "__main__":
    main()
