"""Build the walk-to-school background from the author's school-front painting (rainy morning, side view).

art_source/school_front_rain.png (2172x724) shows the school wall with the gate near its right end.
Across the crossing the pair keep going, now seen from the far side of the road: they walk left to
right, the boy on the wall side, toward the gate at the right end. The wall is made longer to walk along:

  - the stretch between the centres of the 1st and 3rd wall pillars (two bays with the two big
    trees) is repeated before the painting; every join is at a pillar centre, so the wall lines up
    and the join hides in the pillar. The trees above are cross-faded over a wider band.
  - one more stretch after the painting's right edge: the wall carries on past the gate, so the
    camera never shows the end while the boy stands at the gate
  - scaled so the wall is about as tall as the boy (0.5525) and cropped to 360 rows so the sidewalk
    lies under the characters' feet (row 273 in the game)

Prints where the gate is in the game strip (prologue's school scene uses these).

Also runs on the author's trees-only layer of the same painting (art_source/school_trees_rain.png, RGBA):
the same strip, alpha kept, for tools/draw_school_building.py to lay over the drawn sky and building.

Usage:
  python3 tools/compose_school.py art_source/school_trees_rain.png trees.png
"""
import sys

import numpy as np
from PIL import Image

PILLAR_1, PILLAR_3 = 276, 1162         # wall pillar centres (source x) bounding the repeated stretch
REPEATS = 2
WALL_TOP = 288                          # source row of the wall's top edge (trees above it)
GATE = (1656, 1983)                     # gate opening between the two gate pillars (source x)
SCALE = 0.5525
CROP_TOP = 30                           # game rows cut off the top after scaling
SEAM, TREE_SEAM = 12, 40                # half-widths of the cross-fades (source px): wall / trees


def join(parts):
    """Lay the parts side by side, cross-fading each join (narrow on the wall, wide in the trees)."""
    out = parts[0].astype(float)
    for p in parts[1:]:
        p = p.astype(float)
        h = out.shape[0]
        w = TREE_SEAM * 2
        a, b = out[:, -w:], p[:, :w]
        t = np.linspace(0, 1, w)[None, :, None].repeat(h, 0)
        narrow = np.clip((np.arange(w) - (TREE_SEAM - SEAM)) / (2 * SEAM), 0, 1)[None, :, None]
        t[WALL_TOP:] = narrow.repeat(h - WALL_TOP, 0)
        mid = a * (1 - t) + b * t
        out = np.concatenate([out[:, :-w], mid, p[:, w:]], 1)
    return out


def main():
    pic = Image.open(sys.argv[1])
    mode = "RGBA" if "A" in pic.getbands() else "RGB"            # the trees-only layer keeps its alpha
    src = np.asarray(pic.convert(mode))
    tile = src[:, PILLAR_1 - TREE_SEAM:PILLAR_3 + TREE_SEAM]
    tail = src[:, PILLAR_1 - TREE_SEAM:]                        # painting from the 1st pillar to its end
    ext = src[:, PILLAR_1 - TREE_SEAM:PILLAR_3 + TREE_SEAM]
    strip = join([tile] * REPEATS + [tail, ext])
    # source x of the painting inside the strip (before mirroring): tail starts after the tiles
    tile_w = (PILLAR_3 - PILLAR_1)
    tail_at = REPEATS * tile_w                                   # strip x of source x PILLAR_1
    strip = strip[:, TREE_SEAM:]                                 # drop the first tile's fade margin
    def placed(x):                                               # source x -> strip x
        return tail_at + (x - PILLAR_1)
    img = Image.fromarray(np.clip(strip, 0, 255).astype(np.uint8), mode)
    size = (round(img.width * SCALE), round(img.height * SCALE))
    if mode == "RGBA":
        img = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")   # premultiplied: no dark fringes
    else:
        img = img.resize(size, Image.LANCZOS)
    img = img.crop((0, CROP_TOP, size[0], CROP_TOP + 360))
    img.save(sys.argv[2])
    g0, g1 = sorted(placed(x) * SCALE for x in GATE)
    print(f"{img.width}x{img.height} -> {sys.argv[2]}; gate opening x {g0:.0f}-{g1:.0f} "
          f"(centre {(g0 + g1) / 2:.0f}), wall rows {WALL_TOP * SCALE - CROP_TOP:.0f}-{515 * SCALE - CROP_TOP:.0f}")


if __name__ == "__main__":
    main()
