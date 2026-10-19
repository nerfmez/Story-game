"""Material textures for the school model (scripts/school_model_3d.gd), from CC0 PBR sets.

art_source/textures/ holds ambientCG (https://ambientcg.com, CC0) colour and normal maps:
painted plaster, smooth concrete, rough concrete, terrazzo, wood, corrugated steel, grass,
paving stones and painted metal. Each is turned into
  <name>_detail.png  the surface's light/dark detail only, grey around 1.0 (the model multiplies it
                     by the building's own colour, so the walls stay the author's cream, the roof blue)
  <name>_normal.png  its normal map, for the light to catch the surface
both shrunk to 128 px per tile (pixel art at the game's 640x360 view) and read with nearest filtering.

Usage:
  python3 tools/make_school_textures.py art_source/textures assets/bg/school/tex
"""
import os
import sys

import numpy as np
from PIL import Image

SETS = {
    "plaster": "PaintedPlaster017", "smooth": "Concrete034", "concrete": "Concrete047A",
    "terrazzo": "Terrazzo013", "wood": "Wood051", "corrugated": "CorrugatedSteel005",
    "grass": "Grass004", "paving": "PavingStones128", "metal": "PaintedMetal004",
}
SIZE = 128
CONTRAST = {"plaster": 0.7, "smooth": 0.6, "concrete": 0.8, "terrazzo": 0.35, "wood": 1.0,
            "corrugated": 0.9, "grass": 1.0, "paving": 1.0, "metal": 0.3}


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for name, asset in SETS.items():
        col = Image.open(os.path.join(src, f"{asset}_1K-JPG_Color.jpg")).convert("RGB")
        lum = np.asarray(col.convert("L").resize((SIZE, SIZE), Image.LANCZOS), float)
        detail = 1.0 + (lum / lum.mean() - 1.0) * CONTRAST[name]
        detail = np.clip(detail / detail.max(), 0, 1)              # textures stop at 1: model brightens
        Image.fromarray((detail * 255).astype(np.uint8)).save(os.path.join(out, f"{name}_detail.png"))
        nrm = Image.open(os.path.join(src, f"{asset}_1K-JPG_NormalGL.jpg")).convert("RGB")
        nrm.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(out, f"{name}_normal.png"))
        print(f"{name}: detail mean {detail.mean():.2f}")


if __name__ == "__main__":
    main()
