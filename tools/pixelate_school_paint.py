"""Pixel-art copies of the paintings pasted on the school model (scripts/school_model_3d.gd).

The model pastes the author's paintings at 50 px per metre (the close entrance view at 2.87x that).
Read smoothly that looks like a photo up close; here each is shrunk to PPM game pixels per metre,
snapped to one shared palette without dithering, then blown back up with nearest neighbour to its
own size, so the model's UVs stay the same and nearest filtering shows clean square pixels.

  assets/bg/school/paint/{front,mid,props,back_detail,entrance_detail}.png
    -> assets/bg/school/pixel/<same name>.png

Usage:
  python3 tools/pixelate_school_paint.py assets/bg/school/paint assets/bg/school/pixel
"""
import os
import sys

import numpy as np
from PIL import Image

PPM = 25                                  # game pixels per metre on the model
SOURCE_PPM = {"front": 50, "mid": 50, "props": 50, "back_detail": 50,
              "entrance_detail": 50 / 0.348}  # the close view is pasted at 34.8% of its size
COLOURS = 96                              # shared palette: the bluish building
ACCENTS = 32                              # + the few saturated things (bins, board, plants)


def shrink(img, ppm):
    """Premultiplied resize (no dark fringes on the cut-out props), hard alpha."""
    k = PPM / ppm
    size = (max(1, round(img.width * k)), max(1, round(img.height * k)))
    return img.convert("RGBa").resize(size, Image.BOX).convert("RGBA")


def palette(images):
    px = np.concatenate([np.asarray(s)[np.asarray(s)[..., 3] >= 128][:, :3] for s in images])
    sat = px.max(1).astype(int) - px.min(1)
    warm = (px[:, 1] > px[:, 2]) | (px[:, 0] > px[:, 2])           # not blue-dominant
    colours = []
    for sel, n in ((px, COLOURS), (px[(sat > 30) & warm], ACCENTS)):
        q = Image.fromarray(sel.reshape(1, -1, 3)).quantize(n, method=Image.Quantize.MEDIANCUT,
                                                              dither=Image.Dither.NONE)
        colours += q.getpalette()[:n * 3]
    pal = Image.new("P", (1, 1))
    pal.putpalette(colours + [0] * (768 - len(colours)))
    return pal


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    full = {n: Image.open(os.path.join(src, n + ".png")).convert("RGBA") for n in SOURCE_PPM}
    small = {n: shrink(img, SOURCE_PPM[n]) for n, img in full.items()}
    pal = palette(small.values())
    for n, s in small.items():
        alpha = s.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
        rgb = s.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
        rgb.putalpha(alpha)
        rgb.resize(full[n].size, Image.NEAREST).save(os.path.join(out, n + ".png"))
        print(f"{n}: {s.width}x{s.height} game px")


if __name__ == "__main__":
    main()
