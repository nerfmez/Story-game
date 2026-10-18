"""Cut wall, floor, stair and courtyard patches from the author's paintings for the school model.

scripts/school_model_3d.gd lays these on the faces no painting shows straight on (floors, ceilings,
pillar sides, the stair core, the ends and back of the block, the courtyard), repeated in world space
by shaders/tiled_paint.gdshader at the densities its TILES table gives:

  hall_wall.png  stair-hall wall (close entrance view, left hall wall), light top to bottom, 50 px/m
  parapet.png    the low wall beside the stairs (close view), 50 px/m
  riser.png      one stair riser band (close view), 100 px/m (one 0.165 m rise)
  tread.png      stair tread / hall floor (close view floor colours, speckled), 50 px/m
  ceiling.png    corridor / hall ceiling (facade painting), 46 px/m
  plaster.png    the block's plain wall (facade painting), for the ends and the stair core, 50 px/m
  back_bay.png   a ground-floor classroom bay (facade painting) for the block's back wall, 50 px/m
  concrete.png   wet concrete apron slabs 1 m, 48 px/m
  paver.png      the path's pavers 0.5 x 0.25 m running bond, 48 px/m
  lawn.png       mown wet lawn (greens of the author's trees, grass tufts), seamless, 32 px/m
  hedge.png      clipped hedge leaves (the author's tree crown, branch-free patch), mirrored, 90 px/m
  grime.png      the parapet's stained plaster (facade painting), mirrored: ends, parapet insides, 50 px/m
  pillar_side.png  a pillar's lit face (facade painting) for the pillar sides, 50 px/m
  core_wall.png  stair-core wall for one storey (3.3 m): the close view's hall wall above a painted dado
                 1.1 m high with a light rail line, stains from the parapet plaster, 50 px/m
  vent.png       the breeze-block vent screen (close view, above the notice board), 50 px/m
  sheet.png      blue corrugated roof sheet of the covered walkway, 40 px/m
  steel.png      painted steel posts, 40 px/m

Usage:
  python3 tools/make_school_tiles.py art_source/school_entrance_close.png art_source/school_building.png \
          art_source/school_trees_rain.png assets/bg/school/model
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter


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


def wrap_noise(shape, sigma, seed):
    rng = np.random.default_rng(seed)
    f = gaussian_filter(rng.normal(0, 1, shape), sigma, mode="wrap")
    return f / f.std()


def lawn(size=64):
    """Seamless lawn: a few greens by smooth wrapped noise, then small grass tufts (lit tips)."""
    greens = np.array([[32, 54, 56], [42, 68, 64], [52, 82, 74], [66, 98, 84], [88, 120, 96]])
    n = wrap_noise((size, size), 5, 11) * 0.5 + wrap_noise((size, size), 1.5, 12) * 0.35
    idx = np.clip(np.floor(2.0 + n), 1, 3).astype(int)
    a = greens[idx].astype(np.uint8)
    rng = np.random.default_rng(13)
    for _ in range(size * size // 22):
        u, v = rng.integers(0, size, 2)
        for j, c in enumerate((greens[1], greens[3], greens[4])):
            a[(v - j) % size, u] = c
        if rng.random() < 0.5:
            a[(v - 1) % size, (u + 1) % size] = greens[3]
    return Image.fromarray(a)


def concrete(ppm=48):
    rng = np.random.default_rng(21)
    base = np.array([116, 124, 140], float)
    a = np.ones((ppm, ppm, 3)) * base * (1 + 0.03 * wrap_noise((ppm, ppm), 4, 22))[..., None]
    a[rng.random((ppm, ppm)) < 0.03] *= 0.88
    a[0, :] *= 0.8
    a[:, 0] *= 0.8
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def paver(ppm=48):
    w, h = ppm // 2, ppm // 4                     # 0.5 x 0.25 m
    a = np.ones((ppm, ppm, 3)) * np.array([114, 118, 134], float)
    a *= (1 + 0.04 * wrap_noise((ppm, ppm), 2, 31))[..., None]
    for r in range(4):
        y = r * h
        a[y, :] *= 0.76
        off = (r % 2) * (w // 2)
        for x in range(off, ppm, w):
            a[y:y + h, x % ppm] *= 0.76
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def sheet(ppm=40):
    a = np.zeros((8, 16, 3))
    for x in range(16):
        a[:, x] = (62, 88, 140) if x % 4 else (104, 130, 180)
        if x % 4 == 3:
            a[:, x] = (44, 62, 102)
    return Image.fromarray(a.astype(np.uint8))


def main():
    close = Image.open(sys.argv[1]).convert("RGB")
    facade = Image.open(sys.argv[2]).convert("RGB")
    trees = Image.open(sys.argv[3]).convert("RGB")
    out = sys.argv[4]
    os.makedirs(out, exist_ok=True)
    # close view: hall wall ~116 px/m there (10 m from its camera), stair parapet ~95 px/m
    wall = flat_rows(crop(close, (470, 300, 556, 500), 50 / 116), 64, 1)          # above the bench
    Image.fromarray(np.concatenate([np.asarray(wall), np.asarray(wall)[::-1]], 0)).save(os.path.join(out, "hall_wall.png"))
    flat_rows(crop(close, (820, 475, 845, 595), 50 / 95), 32, 2).save(os.path.join(out, "parapet.png"))
    # one riser: the lowest step's lit band, stretched to exactly one rise (17 px at 100 px/m)
    flat_rows(close.crop((650, 578, 780, 598)).resize((130, 17), Image.LANCZOS), 64, 4, 2.0).save(
            os.path.join(out, "riser.png"))
    speckle(median(close, (650, 606, 900, 628)) * 1.05, (64, 64), 3).save(os.path.join(out, "tread.png"))
    speckle(median(facade, (420, 333, 640, 343)), (64, 64), 5, amount=0.015).save(os.path.join(out, "ceiling.png"))
    speckle(median(facade, (430, 606, 560, 640)), (64, 64), 7, light=1.05, dark=0.94, amount=0.05).save(
            os.path.join(out, "plaster.png"))
    facade.crop((398, 496, 650, 645)).save(os.path.join(out, "back_bay.png"))
    concrete().save(os.path.join(out, "concrete.png"))
    paver().save(os.path.join(out, "paver.png"))
    lawn().save(os.path.join(out, "lawn.png"))
    leaves = trees.crop((400, 0, 570, 95))
    leaves = leaves.resize((round(leaves.width * 0.45), round(leaves.height * 0.45)), Image.LANCZOS)
    mirror_tile(leaves).save(os.path.join(out, "hedge.png"))
    sheet().save(os.path.join(out, "sheet.png"))
    grime = facade.crop((412, 442, 640, 478))
    mirror_tile(grime).save(os.path.join(out, "grime.png"))
    pil = np.asarray(facade.crop((376, 160, 394, 640)))
    Image.fromarray(np.concatenate([pil, pil[:, ::-1]], 1)).save(os.path.join(out, "pillar_side.png"))
    # core wall: 165 px = one storey; wall light from the close view, dado below, parapet stains on both
    top = np.asarray(flat_rows(crop(close, (470, 300, 556, 500), 50 / 116), 128, 8).resize((128, 110)), float)
    dado = np.ones((55, 128, 3)) * np.array([62, 76, 104], float)
    dado[:2] = (150, 160, 182)                                   # painted rail line
    dado[-3:] *= 0.7                                             # skirting
    wall = np.concatenate([top, dado], 0)
    stains = np.asarray(grime.resize((128, 165)).convert("L"), float)
    wall *= (0.86 + 0.14 * stains / max(1.0, stains.max()))[..., None]
    Image.fromarray(np.clip(wall, 0, 255).astype(np.uint8)).save(os.path.join(out, "core_wall.png"))
    vent = close.crop((980, 300, 1165, 350))
    vent.resize((round(vent.width * 50 / 126), round(vent.height * 50 / 126)), Image.LANCZOS).save(
            os.path.join(out, "vent.png"))
    Image.new("RGB", (4, 4), (122, 134, 158)).save(os.path.join(out, "steel.png"))
    print(f"school tiles -> {out}")


if __name__ == "__main__":
    main()
