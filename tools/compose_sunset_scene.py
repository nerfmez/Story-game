"""Build the 2D "sunset railway" scene layers from hand-supplied art.

Inputs (in art_source/):
  sunset_sky.png         full sky painting (16:9)
  railway.png            trees, viaduct, city, crossing - transparent background
  railway_with_train.png same view with a train on the viaduct

Outputs (assets/bg/sunset/), all sized for the 640x360 game with room to pan:
  sky.png           sky, cropped so the sun sits just above the railway band
  railway_back.png  the railway layer without the train (crossing signal removed)
  railway_fill.png  dark foliage behind the railway (no sky under the trees)
  railway_front.png leaves that stand in front of the train
  train.png         a 3-car train cut from the train image (loops along the viaduct)
  road.png          wet road in side view that reflects the sky and the railway
  foreground.png    near utility pole + wires

Usage: python3 tools/compose_sunset_scene.py
"""
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import anime_shapes as shapes

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art_source"
OUT = ROOT / "assets" / "bg" / "sunset"

LAYER_W = 800                       # 640 screen + pan margin
SCALE = LAYER_W / 1671.0            # source art -> game pixels
RAIL_Y = -47                        # where the railway layer sits (its sprite's y in the scene)
ROAD_TOP = 258                      # first row of road in screen space
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
rng = random.Random(5)


def scaled(img):
    w, h = img.size
    return img.resize((round(w * SCALE), round(h * SCALE)), Image.NEAREST)


def build_sky():
    sky = scaled(Image.open(SRC / "sunset_sky.png").convert("RGBA"))
    # 800x450 -> keep 360 rows; the sun ends up near y 150
    sky = sky.crop((0, 45, LAYER_W, 405))
    sky.save(OUT / "sky.png")
    return sky


def remove_crossing(img):
    """Erase the crossing signal (poles, X sign, red lamps) from the railway art
    by clone-stamping the trees/viaduct/city from just left of it."""
    im = np.asarray(img).astype(int).copy()
    r, g, b, a = (im[..., i] for i in range(4))
    x0, x1, y0, y1 = 815, 995, 395, 570          # source-pixel box around the signal
    reg = np.zeros(a.shape, bool)
    reg[y0:y1, x0:x1] = True
    red = (r > 140) & (g < 110) & (b < 110)
    light = (r > 160) & (g > 140) & (b > 120)
    brown = (r >= b - 5) & (r >= g) & (np.maximum(np.maximum(r, g), b) < 130)
    very_dark = np.maximum(np.maximum(r, g), b) < 70          # cable and insulators of the signal
    mask = reg & (red | light | brown | very_dark) & (a > 0)
    for _ in range(3):  # grow to catch anti-aliased edges
        mask = mask | np.roll(mask, 1, 0) | np.roll(mask, -1, 0) | np.roll(mask, 1, 1) | np.roll(mask, -1, 1)
    mask &= reg
    shift = 170
    ys, xs = np.where(mask)
    im[ys, xs] = im[ys, xs - shift]
    return Image.fromarray(im.astype(np.uint8), "RGBA")


def foliage_mask(rgba):
    """Leaves (green to dark teal hues) vs viaduct/city/sky (blue to purple)."""
    rgb = rgba[..., :3].astype(float) / 255.0
    mx, mn = rgb.max(2), rgb.min(2)
    delta = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(mx == r, ((g - b) / delta) % 6, np.where(mx == g, (b - r) / delta + 2, (r - g) / delta + 4)) * 60
    return (hue > 50) & (hue < 205) & (rgba[..., 3] > 0)


def build_railway():
    back = scaled(remove_crossing(Image.open(SRC / "railway.png").convert("RGBA")))
    with_train = scaled(Image.open(SRC / "railway_with_train.png").convert("RGBA"))
    b = np.asarray(back).astype(int)

    # --- Front occluders. Inside the train's span, a leaf is in front only if it
    # also covers the train in the train image (otherwise the train hides it, so it
    # is behind). Past the ends of the train, the side trees cover it.
    t = np.asarray(with_train).astype(int)
    leaves_back, leaves_train = foliage_mask(b), foliage_mask(t)
    front = np.zeros(b.shape[:2], bool)
    band0, band1 = int(440 * SCALE), int(522 * SCALE)
    body0 = int(464 * SCALE)              # top of the train body in the train image
    span0, span1 = int(476 * SCALE), int(1400 * SCALE)
    front[body0:band1] = (leaves_back & leaves_train)[body0:band1]
    front[band0:band1, :span0] = leaves_back[band0:band1, :span0]
    front[band0:band1, span1:] = leaves_back[band0:band1, span1:]
    fr = b.copy()
    fr[~front, 3] = 0
    back.save(OUT / "railway_back.png")
    Image.fromarray(fr.astype(np.uint8), "RGBA").save(OUT / "railway_front.png")

    # --- Backfill: dark foliage behind the railway so no sky shows under the trees
    fill = backfill()
    fill.save(OUT / "railway_fill.png")

    # --- Train: one clean car from the left half (before the crossing), repeated 3 times
    car = with_train.crop((int(362 * SCALE), int(464 * SCALE), int(822 * SCALE), int(505 * SCALE)))
    cw, ch = car.size
    gap = 3
    train = Image.new("RGBA", (cw * 3 + gap * 2, ch), (0, 0, 0, 0))
    for k in range(3):
        train.alpha_composite(car, (k * (cw + gap), 0))
    # Coupler between cars
    d = ImageDraw.Draw(train)
    for k in range(1, 3):
        x = k * (cw + gap) - gap
        d.rectangle((x, ch // 2, x + gap - 1, ch - 6), fill=(40, 36, 70, 255))
    train.save(OUT / "train.png")
    deck_top = int(489 * SCALE)  # top of the viaduct deck in the no-train image
    return back, fill, train, deck_top


def build_road(sky, fill, back):
    """Side-view wet road: dark asphalt that mirrors the scene above it."""
    h = 360
    road = np.zeros((h, LAYER_W, 4))
    # What the road reflects: sky + railway as they appear on screen
    scene = sky.copy()
    scene.alpha_composite(fill, (0, RAIL_Y))
    scene.alpha_composite(back, (0, RAIL_Y))
    src = np.asarray(scene).astype(float)
    yy, xx = np.mgrid[0:h, 0:LAYER_W]
    dither = BAYER[yy % 4, xx % 4]
    asphalt_far, asphalt_near = np.array((58, 52, 96)), np.array((30, 28, 58))
    for y in range(ROAD_TOP, h):
        t = (y - ROAD_TOP) / (h - ROAD_TOP)
        base = asphalt_far * (1 - t) + asphalt_near * t
        # mirror about the road's far edge, compressed (we look down at the road)
        my = int(ROAD_TOP - (y - ROAD_TOP) * 1.6) - 2
        wob = int(2 * np.sin(y * 0.9) + rng.choice((0, 0, 1, -1)))
        if 0 <= my < h:
            row = np.roll(src[my, :, :3], wob, axis=0)
            strength = 0.62 * (1 - t) ** 0.6
            # puddle patches reflect more, dry asphalt less
            col = base * (1 - strength) + row * strength
        else:
            col = np.tile(base, (LAYER_W, 1))
        q = np.floor(col / 6 + dither[y, :, None] * 0.9) * 6  # posterise with dithering
        road[y, :, :3] = q
        road[y, :, 3] = 255
    img = Image.fromarray(np.clip(road, 0, 255).astype(np.uint8), "RGBA")
    img.alpha_composite(hedge())
    d = ImageDraw.Draw(img)
    # Far curb + low fence under the trees, kerb highlight, edge line, cracks, a manhole
    d.rectangle((0, ROAD_TOP - 8, LAYER_W, ROAD_TOP - 1), fill=(74, 66, 112, 255))
    d.line([(0, ROAD_TOP - 8), (LAYER_W, ROAD_TOP - 8)], fill=(150, 120, 160, 255))
    d.line([(0, ROAD_TOP - 1), (LAYER_W, ROAD_TOP - 1)], fill=(26, 20, 46, 255))
    for x in range(4, LAYER_W, 22):  # fence posts
        d.rectangle((x, ROAD_TOP - 20, x + 1, ROAD_TOP - 8), fill=(44, 40, 74, 255))
    d.line([(0, ROAD_TOP - 18), (LAYER_W, ROAD_TOP - 18)], fill=(56, 50, 88, 255))
    d.line([(0, ROAD_TOP - 13), (LAYER_W, ROAD_TOP - 13)], fill=(56, 50, 88, 255))
    for x in range(0, LAYER_W, 36):  # dashed edge line
        d.line([(x, ROAD_TOP + 6), (x + 20, ROAD_TOP + 6)], fill=(200, 190, 210, 255))
    for _ in range(10):
        x, y = rng.randint(0, LAYER_W), rng.randint(ROAD_TOP + 14, 350)
        pts = [(x, y)]
        for _k in range(4):
            x += rng.randint(3, 9)
            y += rng.randint(-1, 1)
            pts.append((x, y))
        d.line(pts, fill=(22, 18, 40, 255))
    d.ellipse((520, 300, 566, 309), fill=(40, 36, 66, 255), outline=(20, 16, 36, 255))
    d.ellipse((526, 302, 560, 307), outline=(70, 64, 100, 255))
    img.save(OUT / "road.png")


def backfill(block=3):
    """Low wall of shadowed foliage behind the railway layer (in railway-layer
    coordinates). It fills the gaps under and between the trees down to the road."""
    w, h = LAYER_W // block, 451 // block
    pal = [(16, 24, 56), (22, 38, 66), (30, 54, 72), (44, 76, 74)]
    top = (ROAD_TOP - 75 - RAIL_Y) / block   # foliage top line, a little above the hedge
    clumps = []
    x = -6
    while x < w + 8:
        r = rng.uniform(7, 12)
        clumps.append((x, top + rng.uniform(-4, 3), r))
        x += r * rng.uniform(0.8, 1.2)
    clumps.sort(key=lambda c: c[1])
    arr = shapes.render_clumps((w, h), clumps, (w * 0.5, 0, 30), pal, shapes.leaf_field((w, h), 33, amp=0.18), (90, 90, 110), rng)
    below = int(top)
    arr[below:, :, :3] = pal[0]   # solid shadow under the clumps
    arr[below:, :, 3] = 255
    small = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return small.resize((LAYER_W, 451), Image.NEAREST)


def hedge(block=3):
    """Row of bushes behind the fence. Rendered at 1/block resolution and scaled up
    so its pixels are as chunky as the supplied art."""
    w, h = LAYER_W // block, 360 // block
    pal = [(22, 34, 70), (30, 58, 78), (44, 84, 80), (78, 118, 74), (130, 150, 80)]
    clumps = []
    x = -4
    while x < w + 6:
        r = rng.uniform(5, 9)
        clumps.append((x, (ROAD_TOP - 14) / block + rng.uniform(-1.5, 1.5), r))
        x += r * rng.uniform(0.9, 1.4)
    clumps.sort(key=lambda c: c[1])
    arr = shapes.render_clumps((w, h), clumps, (w * 0.5, 0, 40), pal, shapes.leaf_field((w, h), 21, amp=0.2), (230, 170, 120), rng)
    arr[int((ROAD_TOP - 8) / block):] = 0  # stops at the curb
    small = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return small.resize((LAYER_W, 360), Image.NEAREST)


def build_foreground():
    w, h = LAYER_W + 200, 360
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    px = 805  # near utility pole at the right edge of the screen
    d.rectangle((px - 13, 0, px + 13, h), fill=(30, 24, 50, 255))
    d.rectangle((px - 13, 0, px - 11, h), fill=(150, 90, 110, 255))  # warm rim from the sunset
    d.rectangle((px - 60, 36, px + 60, 43), fill=(30, 24, 50, 255))
    d.line([(px - 60, 36), (px + 60, 36)], fill=(230, 140, 110, 255))
    d.rectangle((px + 16, 70, px + 34, 100), fill=(44, 38, 66, 255))  # transformer
    d.line([(px + 16, 70), (px + 34, 70)], fill=(180, 110, 110, 255))
    # Wires sagging across the whole frame
    for k, (y0, y1, sag) in enumerate(((40, 64, 34), (40, 84, 40), (40, 52, 26), (78, 120, 30), (92, 104, 22))):
        x0 = px - 56 + k * 22
        pts = []
        for i in range(41):
            t = i / 40
            pts.append((x0 + (-40 - x0) * t, y0 + (y1 - y0) * t + sag * 4 * t * (1 - t)))
        d.line(pts, fill=(18, 14, 34, 255), width=2 if k < 3 else 1)
    img.save(OUT / "foreground.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    sky = build_sky()
    back, fill, train, deck_top = build_railway()
    build_road(sky, fill, back)
    build_foreground()
    print(f"layers written to {OUT}; train {train.size}, train top y in layer = {deck_top - train.size[1]}, "
          f"train clip x = {int(476 * SCALE)}..{int(1405 * SCALE)}")
