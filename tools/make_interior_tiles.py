"""Cut wall, stair and corridor patches from the author's paintings for the walk-in school interior.

The stairs up to the 2nd and 3rd floors and the corridors there are seen from places no painting
shows, so they are built in 3D (scripts/school_interior_3d.gd) and covered with patches of the
author's own paintings laid in world space (shaders/tiled_paint.gdshader), at the densities below:

  hall_wall.png  stair-hall wall (close entrance view, left hall wall): its light top to bottom laid
                 flat with fine grain (tiles without blotches), mirrored downwards, 50 px/m
  parapet.png    the low wall beside the stairs (close view), the same way, 50 px/m
  riser.png      one stair riser band (close view): 17 px = one 0.17 m rise at 100 px/m
  tread.png      stair tread / landing floor (close view hall floor colours, speckled), 50 px/m
  bay.png        one classroom bay of the 2nd-floor corridor back wall (facade painting: window,
                 door, lamp; the strip under the parapet line continued as plain wall), 46 px/m
  corridor_parapet.png  the corridor parapet (facade painting), 46 px/m
  pillar.png     a corridor pillar face (facade painting), 46 px/m
  ceiling.png    corridor / hall ceiling (facade painting), 46 px/m

Usage:
  python3 tools/make_interior_tiles.py art_source/school_entrance_close.png art_source/school_building.png assets/bg/school/interior
"""
import os
import sys

import numpy as np
from PIL import Image


def crop(img, box, scale):
    p = img.crop(box)
    return p.resize((max(1, round(p.width * scale)), max(1, round(p.height * scale))), Image.LANCZOS)


def mirror_tile(p):
    """Mirror the patch both ways so it repeats without seams."""
    a = np.asarray(p)
    row = np.concatenate([a, a[:, ::-1]], 1)
    return Image.fromarray(np.concatenate([row, row[::-1]], 0))


def speckle(base, size, seed, light=1.12, dark=0.86, amount=0.03):
    rng = np.random.default_rng(seed)
    a = np.ones((size[1], size[0], 3)) * np.asarray(base, float)
    r = rng.random(size[::-1])
    a[r < amount] *= dark
    a[r > 1 - amount] *= light
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def flat_rows(p, width, seed, grain=3.0):
    """The patch's light from top to bottom (per-row median) laid flat across, with fine grain:
    tiles sideways without the mirrored blotches of a soft painted patch."""
    a = np.asarray(p).astype(float)
    rows = np.median(a, axis=1)[:, None, :]
    out = np.repeat(rows, width, 1)
    rng = np.random.default_rng(seed)
    out += rng.normal(0, grain, out.shape[:2])[..., None]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def median(img, box):
    a = np.asarray(img.crop(box)).reshape(-1, 3)
    return np.median(a, 0)


def main():
    close = Image.open(sys.argv[1]).convert("RGB")
    facade = Image.open(sys.argv[2]).convert("RGB")
    out = sys.argv[3]
    os.makedirs(out, exist_ok=True)
    # close view: hall wall ~116 px/m there (10 m from its camera), stair parapet ~95 px/m
    wall = flat_rows(crop(close, (470, 300, 556, 500), 50 / 116), 64, 1)          # above the bench
    Image.fromarray(np.concatenate([np.asarray(wall), np.asarray(wall)[::-1]], 0)).save(os.path.join(out, "hall_wall.png"))
    flat_rows(crop(close, (820, 475, 845, 595), 50 / 95), 32, 2).save(os.path.join(out, "parapet.png"))
    # one riser: the lowest step's lit band, stretched to exactly one rise (17 px at 100 px/m)
    flat_rows(close.crop((650, 578, 780, 598)).resize((130, 17), Image.LANCZOS), 64, 4, 2.0).save(
            os.path.join(out, "riser.png"))
    speckle(median(close, (650, 606, 900, 628)) * 1.05, (64, 64), 3).save(os.path.join(out, "tread.png"))
    # facade painting (corridor back wall at 46 px/m): one bay, the part under the parapet line made up
    bay = np.asarray(facade.crop((398, 329, 650, 435)))
    wall = median(facade, (588, 350, 620, 425))                  # plain wall between window and door
    below = np.ones((34, bay.shape[1], 3)) * wall
    below[-3:] *= 0.62                                           # skirting at the floor
    Image.fromarray(np.concatenate([bay, below.astype(np.uint8)], 0)).save(os.path.join(out, "bay.png"))
    facade.crop((398, 435, 650, 496)).save(os.path.join(out, "corridor_parapet.png"))
    mirror_tile(facade.crop((652, 340, 673, 430))).save(os.path.join(out, "pillar.png"))
    speckle(median(facade, (420, 333, 640, 343)), (64, 64), 5, amount=0.015).save(os.path.join(out, "ceiling.png"))
    print(f"interior tiles -> {out}")


if __name__ == "__main__":
    main()
