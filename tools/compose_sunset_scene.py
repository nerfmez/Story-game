"""Build the 2D "sunset railway" scene layers from hand-supplied art.

Inputs (in art_source/):
  sunset_sky.png         full sky painting (16:9)
  railway.png            trees, viaduct, city, crossing - transparent background
  railway_with_train.png same view with a train on the viaduct (the train is cut from it)
  railway_long.png       long viaduct strip with trees (the railway layer itself)

Outputs (assets/bg/sunset/). Every layer tiles seamlessly left-right, so the
scene can scroll forever (Parallax2D.repeat_size in the game):
  sky.png           sky + its mirror image (1600 wide), sun just above the railway band
  city.png          the distant city skyline, split out of the railway art so it can
                    scroll far slower than the trees (extended down behind the trees)
  railway_back.png  railway tile made from railway_long.png, joined end to end along the
                    least visible cut (width printed at the end = RAIL_TILE in the scene)
  railway_fill.png  dark foliage behind the railway (no sky under the trees)
  train.png         a 3-car train cut from the train image (loops along the viaduct)
  sky_reflect.png   the sky mirrored in the wet road (moves with the sky)
  city_reflect.png  the city mirrored in the wet road (moves with the city)
  rail_reflect.png  the railway mirrored in the wet road (moves with the railway)
  road.png          wet asphalt (semi-transparent over the reflections), fence, hedge
  foreground.png    near utility pole + wires (960 wide tile)

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
TILE = 720                          # repeat width of railway/road layers (fence 24px, dashes 36px fit)
CROP_X0 = 48                        # the railway art's trees start here in the 800px-wide scaled image
SKY_TILE = 1600                     # sky + mirrored sky
FG_TILE = 960                       # one near utility pole per foreground tile
MIRROR = 1.6                        # reflection squash: we look down at the road
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
    tile = Image.new("RGBA", (SKY_TILE, 360))
    tile.paste(sky, (0, 0))
    tile.paste(sky.transpose(Image.FLIP_LEFT_RIGHT), (LAYER_W, 0))  # mirror -> always seamless
    tile.save(OUT / "sky.png")
    return tile


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


def hue_of(rgba):
    rgb = rgba[..., :3].astype(float) / 255.0
    mx, mn = rgb.max(2), rgb.min(2)
    delta = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return np.where(mx == r, ((g - b) / delta) % 6, np.where(mx == g, (b - r) / delta + 2, (r - g) / delta + 4)) * 60


def split_city(b, bottom=238):
    """Pull the blue city skyline (and bluish far trees) out of the railway art.

    Returns (city RGBA array, mask). Where trees hide the lower part of the city,
    each column is extended down with its lowest visible colour, and columns
    hidden completely reuse the nearest visible column, so no holes appear when
    the trees slide past the slower city."""
    hue = hue_of(b)
    mask = (hue > 215) & (hue < 265) & (b[..., 3] > 0)
    mask[225:] = False
    city = np.zeros_like(b)
    cols = np.where(mask.any(0))[0]
    if len(cols) == 0:
        return city, mask
    filled = np.zeros(b.shape[1], bool)
    for x in cols:
        rows = np.where(mask[:, x])[0]
        top = rows.min()
        last = b[top, x]
        for y in range(top, bottom):
            if mask[y, x]:
                last = b[y, x]
                city[y, x] = last
            elif b[y, x, 3] == 0:
                continue          # real sky between buildings (e.g. the sun) stays open
            else:
                city[y, x] = last  # hidden behind trees: continue the building down
        filled[x] = True
    for x in range(cols.min(), cols.max() + 1):
        if not filled[x]:
            near = cols[np.argmin(np.abs(cols - x))]
            hidden = b[:, x, 3] > 0                 # only where something covers this column
            city[hidden, x] = city[hidden, near]
    return city, mask


def seamless(img):
    """Make a wide strip tile: overlap its end on its start and cut along the path
    where the two differ least (through gaps, the deck, similar foliage).
    Returns the tile (narrower than the strip by the overlap)."""
    a = np.asarray(img).astype(float)
    h, w = a.shape[:2]
    opaque = a[..., 3] > 128
    deck = np.nonzero(opaque.mean(1) > 0.999)[0]      # rows that are solid all the way across (deck)
    # overlap that lines up the deck's railing pattern best
    best = None
    for ov in range(120, w // 3):
        d = np.abs(a[deck, w - ov:w, :3] - a[deck, 0:ov, :3]).mean()
        if best is None or d < best[0] - 0.5:
            best = (d, ov)
    ov = best[1]
    A, B = a[:, w - ov:], a[:, :ov]
    cost = (np.abs(A[..., :3] - B[..., :3]).sum(2) * np.minimum(A[..., 3], B[..., 3]) / 255
            + np.abs(A[..., 3] - B[..., 3]) * 3)
    # dynamic programming: cheapest top-to-bottom path (one column step per row)
    acc = cost.copy()
    for y in range(1, h):
        prev = acc[y - 1]
        acc[y] += np.minimum(prev, np.minimum(np.r_[np.inf, prev[:-1]], np.r_[prev[1:], np.inf]))
    path = np.zeros(h, int)
    path[-1] = acc[-1].argmin()
    for y in range(h - 2, -1, -1):
        x = path[y + 1]
        lo, hi = max(0, x - 1), min(ov, x + 2)
        path[y] = lo + acc[y, lo:hi].argmin()
    joined = B.copy()
    for y in range(h):
        joined[y, :path[y]] = A[y, :path[y]]       # left of the cut: the strip's end
    tile = np.concatenate([joined, a[:, ov:w - ov]], axis=1)
    print(f"railway strip {w}px: overlap {ov}px, tile {tile.shape[1]}px")
    return Image.fromarray(tile.astype(np.uint8), "RGBA")


def build_railway():
    back = scaled(remove_crossing(Image.open(SRC / "railway.png").convert("RGBA")))
    with_train = scaled(Image.open(SRC / "railway_with_train.png").convert("RGBA"))
    b = np.asarray(back).astype(int)

    # --- Distant city goes to its own (much slower) layer (from the original art)
    city, _ = split_city(b)
    box = (CROP_X0, 0, CROP_X0 + TILE, back.size[1])
    city = Image.fromarray(city.astype(np.uint8), "RGBA").crop(box)
    city.save(OUT / "city.png")

    # --- The railway layer itself: the long viaduct strip, made into a tile and
    # scaled like the other art, with its rails at the same height as before
    deck_top = int(489 * SCALE)  # top of the viaduct deck (where the train runs) in layer pixels
    strip = scaled(seamless(Image.open(SRC / "railway_long.png").convert("RGBA")))
    sa = np.asarray(strip)
    # rails = first row whose pixels are mostly the warm rail highlight (trees above
    # the deck can also be solid all the way across, so opacity alone is not enough)
    rails = np.nonzero(np.median(sa[..., 0], axis=1) > 150)[0][0]
    back = Image.new("RGBA", (strip.size[0], 451), (0, 0, 0, 0))
    back.paste(strip, (0, deck_top - rails))
    back.save(OUT / "railway_back.png")

    # --- Backfill: dark foliage behind the railway so no sky shows under the trees
    fill = backfill(back.size[0])
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
    return back, fill, city, train, deck_top


def mirror(src, src_y, width, darken=0.8, tint=(30, 24, 70)):
    """Mirror image rows above the road into the road rows (screen coordinates).
    src_y: screen y of src's row 0. Rows are squashed by MIRROR and wobbled with
    whole-row shifts (np.roll keeps the tile seamless)."""
    s = np.asarray(src).astype(float)
    out = np.zeros((360, width, 4))
    for y in range(ROAD_TOP, 360):
        my = int(ROAD_TOP - (y - ROAD_TOP) * MIRROR) - 2 - src_y
        if not 0 <= my < s.shape[0]:
            continue
        wob = int(round(1.5 * np.sin(y * 0.9) + 0.8 * np.sin(y * 2.3)))
        row = np.roll(s[my], wob, axis=0)
        out[y, :, :3] = row[:, :3] * darken + np.array(tint) * (1 - darken)
        out[y, :, 3] = row[:, 3]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def build_road(sky, city, fill, back):
    """Wet road in side view, as three tiling layers:
    sky_reflect + rail_reflect (they scroll with what they reflect) under a
    semi-transparent asphalt layer that scrolls with the ground."""
    mirror(sky, 0, SKY_TILE).save(OUT / "sky_reflect.png")
    mirror(city, RAIL_Y, TILE).save(OUT / "city_reflect.png")
    rail = fill.copy()
    rail.alpha_composite(back)
    mirror(rail, RAIL_Y, rail.size[0]).save(OUT / "rail_reflect.png")

    h = 360
    road = np.zeros((h, TILE, 4))
    yy, xx = np.mgrid[0:h, 0:TILE]
    dither = BAYER[yy % 4, xx % 4]
    # Puddles (wrap around the tile edge): the asphalt is thinner there, so more reflection
    puddle = np.zeros((h, TILE), bool)
    for _ in range(9):
        cx, cy = rng.uniform(0, TILE), rng.uniform(ROAD_TOP + 12, 350)
        for _k in range(3):
            ex, ey = cx + rng.uniform(-25, 25), cy + rng.uniform(-3, 3)
            rx, ry = rng.uniform(18, 50), rng.uniform(3, 7)
            for off in (-TILE, 0, TILE):
                puddle |= ((xx - ex - off) / rx) ** 2 + ((yy - ey) / ry) ** 2 < 1
    asphalt_far, asphalt_near = np.array((58, 52, 96)), np.array((30, 28, 58))
    for y in range(ROAD_TOP, h):
        t = (y - ROAD_TOP) / (h - ROAD_TOP)
        road[y, :, :3] = np.floor((asphalt_far * (1 - t) + asphalt_near * t) / 6 + dither[y, :, None] * 0.9) * 6
        alpha = 1 - 0.62 * (1 - t) ** 0.6
        road[y, :, 3] = np.where(puddle[y], alpha * 0.45, alpha) * 255
    img = Image.fromarray(np.clip(road, 0, 255).astype(np.uint8), "RGBA")
    img.alpha_composite(hedge())
    d = ImageDraw.Draw(img)
    # Far curb + low fence under the trees, kerb highlight, edge line, cracks, a manhole
    d.rectangle((0, ROAD_TOP - 8, TILE, ROAD_TOP - 1), fill=(74, 66, 112, 255))
    d.line([(0, ROAD_TOP - 8), (TILE, ROAD_TOP - 8)], fill=(150, 120, 160, 255))
    d.line([(0, ROAD_TOP - 1), (TILE, ROAD_TOP - 1)], fill=(26, 20, 46, 255))
    for x in range(4, TILE, 24):  # fence posts (720 / 24 = 30 per tile)
        d.rectangle((x, ROAD_TOP - 20, x + 1, ROAD_TOP - 8), fill=(44, 40, 74, 255))
    d.line([(0, ROAD_TOP - 18), (TILE, ROAD_TOP - 18)], fill=(56, 50, 88, 255))
    d.line([(0, ROAD_TOP - 13), (TILE, ROAD_TOP - 13)], fill=(56, 50, 88, 255))
    for x in range(0, TILE, 36):  # dashed edge line (720 / 36 = 20 per tile)
        d.line([(x, ROAD_TOP + 6), (x + 20, ROAD_TOP + 6)], fill=(200, 190, 210, 255))
    for _ in range(10):
        x, y = rng.randint(20, TILE - 60), rng.randint(ROAD_TOP + 14, 350)
        pts = [(x, y)]
        for _k in range(4):
            x += rng.randint(3, 9)
            y += rng.randint(-1, 1)
            pts.append((x, y))
        d.line(pts, fill=(22, 18, 40, 255))
    d.ellipse((520, 300, 566, 309), fill=(40, 36, 66, 255), outline=(20, 16, 36, 255))
    d.ellipse((526, 302, 560, 307), outline=(70, 64, 100, 255))
    img.save(OUT / "road.png")


def periodic(clumps, w):
    """Repeat clumps that touch an edge on the other side, so a tile of width w wraps cleanly."""
    out = list(clumps)
    for (x, y, r) in clumps:
        if x - r < 0:
            out.append((x + w, y, r))
        if x + r > w:
            out.append((x - w, y, r))
    return out


def backfill(width, block=3):
    """Low wall of shadowed foliage behind the railway layer (in railway-layer
    coordinates). It fills the gaps under and between the trees down to the road."""
    w, h = width // block, 451 // block
    pal = [(16, 24, 56), (22, 38, 66), (30, 54, 72), (44, 76, 74)]
    top = (ROAD_TOP - 75 - RAIL_Y) / block   # foliage top line, a little above the hedge
    clumps = []
    x = 0
    while x < w:
        r = rng.uniform(7, 12)
        clumps.append((x, top + rng.uniform(-4, 3), r))
        x += r * rng.uniform(0.8, 1.2)
    clumps = periodic(clumps, w)
    clumps.sort(key=lambda c: c[1])
    arr = shapes.render_clumps((w, h), clumps, (w * 0.5, 0, 30), pal, shapes.leaf_field((w, h), 33, amp=0.18), (90, 90, 110), rng)
    below = int(top)
    arr[below:, :, :3] = pal[0]   # solid shadow under the clumps
    arr[below:, :, 3] = 255
    small = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return small.resize((width, 451), Image.NEAREST)


def hedge(block=3):
    """Row of bushes behind the fence. Rendered at 1/block resolution and scaled up
    so its pixels are as chunky as the supplied art."""
    w, h = TILE // block, 360 // block
    pal = [(22, 34, 70), (30, 58, 78), (44, 84, 80), (78, 118, 74), (130, 150, 80)]
    clumps = []
    x = 0
    while x < w:
        r = rng.uniform(5, 9)
        clumps.append((x, (ROAD_TOP - 14) / block + rng.uniform(-1.5, 1.5), r))
        x += r * rng.uniform(0.9, 1.4)
    clumps = periodic(clumps, w)
    clumps.sort(key=lambda c: c[1])
    arr = shapes.render_clumps((w, h), clumps, (w * 0.5, 0, 40), pal, shapes.leaf_field((w, h), 21, amp=0.2), (230, 170, 120), rng)
    arr[int((ROAD_TOP - 8) / block):] = 0  # stops at the curb
    small = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return small.resize((TILE, 360), Image.NEAREST)


def build_foreground():
    w, h = FG_TILE, 360
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    px = 900  # near utility pole; the previous tile's pole is at px - FG_TILE
    d.rectangle((px - 13, 0, px + 13, h), fill=(30, 24, 50, 255))
    d.rectangle((px - 13, 0, px - 11, h), fill=(150, 90, 110, 255))  # warm rim from the sunset
    d.rectangle((px - 60, 36, px + 59, 43), fill=(30, 24, 50, 255))
    d.line([(px - 60, 36), (px + 59, 36)], fill=(230, 140, 110, 255))
    d.rectangle((px + 16, 70, px + 34, 100), fill=(44, 38, 66, 255))  # transformer
    d.line([(px + 16, 70), (px + 34, 70)], fill=(180, 110, 110, 255))
    # Wires sag from this pole to the previous one (drawn in the previous tile)
    for k, (y0, sag) in enumerate(((40, 70), (40, 84), (40, 58), (84, 60), (96, 48))):
        x0 = px - 56 + k * 22 if k < 3 else px - 30 + (k - 3) * 60
        x1 = x0 - FG_TILE
        pts = []
        for i in range(81):
            t = i / 80
            pts.append((x0 + (x1 - x0) * t, y0 + sag * 4 * t * (1 - t)))
        d.line(pts, fill=(18, 14, 34, 255), width=2 if k < 3 else 1)
        d.line([(p[0] + FG_TILE, p[1]) for p in pts], fill=(18, 14, 34, 255), width=2 if k < 3 else 1)
    img.save(OUT / "foreground.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    sky = build_sky()
    back, fill, city, train, deck_top = build_railway()
    build_road(sky, city, fill, back)
    build_foreground()
    print(f"layers written to {OUT}; railway tile {back.size[0]}px (RAIL_TILE), "
          f"train {train.size}, train top y in layer = {deck_top - train.size[1]}")
