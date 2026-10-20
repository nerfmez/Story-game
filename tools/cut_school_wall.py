"""Cut the walk-to-school strip into what stands in front of the school: the trees, and the wall layer.

The walk scene (scripts/school_walk.gd) shows the school itself as the 3D model (scripts/school_model_3d.gd)
behind this layer, so the drawn sky, building and campus (tools/draw_school_building.py) are cut out:
a pixel stays in the wall layer where tools/draw_school_wall.py draws it (wall, pillars, gate, sidewalk,
road, the weeds at its foot), in the trees layer where only the author's trees cover it (so the scene can
sway them on their own); the rest (the sky, the building, the campus through the gate) turns clear.

What draw_school_wall.py draws is found by running it on a plain key colour: every pixel it leaves
untouched is the painting behind.

Usage (TREES: the trees-only strip from tools/compose_school.py):
  python3 tools/cut_school_wall.py assets/bg/school/school_front.png TREES.png \
          assets/bg/school/school_wall.png assets/bg/school/school_trees.png
"""
import os
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import draw_school_wall  # noqa: E402

KEY = (255, 0, 255)


def main():
    strip = Image.open(sys.argv[1]).convert("RGB")
    trees = np.asarray(Image.open(sys.argv[2]).convert("RGBA"))
    with tempfile.TemporaryDirectory() as tmp:
        key, drawn = os.path.join(tmp, "key.png"), os.path.join(tmp, "drawn.png")
        Image.new("RGB", strip.size, KEY).save(key)
        argv = sys.argv
        sys.argv = ["draw_school_wall.py", key, drawn, sys.argv[2]]
        draw_school_wall.main()
        sys.argv = argv
        wall = np.asarray(Image.open(drawn).convert("RGB")).astype(int)
    drawn = np.abs(wall - KEY).max(2) > 2
    leaves = (trees[..., 3] >= 128) & ~drawn
    for mask, path in ((drawn, sys.argv[3]), (leaves, sys.argv[4])):
        out = np.dstack([np.asarray(strip), np.where(mask, 255, 0).astype(np.uint8)])
        Image.fromarray(out, "RGBA").save(path)
        print(f"{strip.width}x{strip.height} -> {path}; {100 * mask.mean():.0f}% kept")


if __name__ == "__main__":
    main()
