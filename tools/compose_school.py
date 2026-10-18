"""Build the walk-to-school background from the author's school-front painting (rainy morning, side view).

art_source/school_front_rain.png (2172x724) shows the school wall with the gate near its right end.
The walk goes right to left like the street before it, so the strip is mirrored (gate near the left
end) and the wall is made longer to walk along:

  - the stretch between the centres of the 1st and 3rd wall pillars (two bays with the two big
    trees) is repeated before the painting; every join is at a pillar centre, so the wall lines up
    and the join hides in the pillar. The trees above are cross-faded over a wider band.
  - one more stretch after the painting's right edge: the wall carries on past the gate, so the
    camera never shows the end while the boy stands at the gate
  - mirrored as a whole, then the name plate on the gate pillar is mirrored back (readable text)
  - scaled so the wall is about as tall as the boy (0.5525) and cropped to 360 rows so the sidewalk
    lies under the characters' feet (row 273 in the game)

Prints where the gate is in the game strip (prologue's school scene uses these).

Usage:
  python3 tools/compose_school.py art_source/school_front_rain.png assets/bg/school/school_front.png
"""
import sys

import numpy as np
from PIL import Image

PILLAR_1, PILLAR_3 = 276, 1162         # wall pillar centres (source x) bounding the repeated stretch
REPEATS = 2
WALL_TOP = 288                          # source row of the wall's top edge (trees above it)
PLATE = (1990, 322, 2072, 362)          # name plate on the gate pillar (source box)
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
    src = np.asarray(Image.open(sys.argv[1]).convert("RGB"))
    tile = src[:, PILLAR_1 - TREE_SEAM:PILLAR_3 + TREE_SEAM]
    tail = src[:, PILLAR_1 - TREE_SEAM:]                        # painting from the 1st pillar to its end
    ext = src[:, PILLAR_1 - TREE_SEAM:PILLAR_3 + TREE_SEAM]
    strip = join([tile] * REPEATS + [tail, ext])
    # source x of the painting inside the strip (before mirroring): tail starts after the tiles
    tile_w = (PILLAR_3 - PILLAR_1)
    tail_at = REPEATS * tile_w                                   # strip x of source x PILLAR_1
    strip = strip[:, TREE_SEAM:]                                 # drop the first tile's fade margin
    w = strip.shape[1]
    strip = strip[:, ::-1]                                       # gate near the left end
    def mirrored(x):                                             # source x -> mirrored strip x
        return w - 1 - (tail_at + (x - PILLAR_1))
    x0, y0, x1, y1 = PLATE
    a, b = int(mirrored(x1)), int(mirrored(x0))
    strip[y0:y1, a:b] = strip[y0:y1, a:b][:, ::-1]               # plate text reads the right way again
    img = Image.fromarray(np.clip(strip, 0, 255).astype(np.uint8))
    size = (round(img.width * SCALE), round(img.height * SCALE))
    img = img.resize(size, Image.LANCZOS).crop((0, CROP_TOP, size[0], CROP_TOP + 360))
    img.save(sys.argv[2])
    g0, g1 = sorted(mirrored(x) * SCALE for x in GATE)
    print(f"{img.width}x{img.height} -> {sys.argv[2]}; gate opening x {g0:.0f}-{g1:.0f} "
          f"(centre {(g0 + g1) / 2:.0f}), wall rows {WALL_TOP * SCALE - CROP_TOP:.0f}-{515 * SCALE - CROP_TOP:.0f}")


if __name__ == "__main__":
    main()
