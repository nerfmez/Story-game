"""Build the 2D "sunset railway" scene layers from hand-supplied art.

Inputs (in art_source/):
  sunset_sky.png         full sky painting (16:9)
  railway.png            trees, viaduct, city, crossing - transparent background
  railway_long.png       long viaduct strip with trees (the railway layer itself)

Outputs (assets/bg/sunset/). Every layer tiles seamlessly left-right, so the
scene can scroll forever (Parallax2D.repeat_size in the game):
  sky.png           sky + its mirror image (1600 wide), sun just above the railway band
  city.png          the distant city skyline, split out of the railway art so it can
                    scroll far slower than the trees (extended down behind the trees)
  railway_back.png  railway tile made from railway_long.png, joined end to end along the
                    least visible cut (width printed at the end = RAIL_TILE in the scene)
  railway_fill.png  dark foliage behind the railway (no sky under the trees)
  train.png         a 4-car skytrain (white / blue / red livery) drawn in pixel art,
                    wheels on the near rail
  sky_reflect.png   the sky mirrored in the wet road (moves with the sky)
  city_reflect.png  the city mirrored in the wet road (moves with the city)
  rail_reflect.png  the railway mirrored in the wet road (moves with the railway)
  road.png          wet asphalt (semi-transparent over the reflections), fence, hedge
  foreground.png    near utility pole + wires (960 wide tile)
  bird.png          a small bird silhouette, 2 wing frames side by side (for the flocks)
  Atmosphere (all line up with the sky tile: 1600 wide, sun at SUN_X / SUN_Y and its
  mirror image, so they scroll with the sky):
  sun_glow.png      warm bloom around the sun, drawn additively over the tree tops
  sun_rays.png      faint light shafts fanning down from the sun (additive)
  haze_far.png      evening haze over the distant city (lighter and warmer near the sun)
  haze_near.png     thinner haze over the railway trees
  wisps.png         thin drifting cloud streaks (the layer auto-scrolls)

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
RAIL_BLOCK = 3                      # railway trees/viaduct: 3x3 game pixels per art pixel (like the hedge)
TRAIN_BLOCK = 2                     # train: 2x2 game pixels per art pixel
SUN_X, SUN_Y = 248, 150             # sun centre in the sky layer (its sprite sits at x -48)
MIRROR = 1.6                        # reflection squash: we look down at the road
ROAD_TOP = 258                      # first row of the ground (sidewalk) in screen space; reflections mirror here
KERB_Y = 280                        # sidewalk ends: kerb face from here down to the street
STREET_TOP = 286                    # first row of asphalt
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


def pixelate(img, block, colours=48, rails=()):
    """Scale source art to game size with chunky block x block pixels: average down to
    1/block of the game size, cut the colours to a small palette (crisp, flat areas like
    hand-made pixel art), then blow each pixel up to block x block.
    Foliage and the grey-blue structure get palettes of their own, so the many greens
    don't push the viaduct's colours green. `rails` = (source row, colour) lines that are
    too thin to survive the averaging; they are drawn back as one pixel row each."""
    w, h = img.size
    sw, sh = round(w * SCALE / block), round(h * SCALE / block)
    small = img.resize((sw, sh), Image.BOX)              # Pillow resamples RGBA premultiplied
    a = np.asarray(small).astype(int)
    solid = a[..., 3] > 128
    green = (a[..., 1] > a[..., 2] + 4) | (a[..., 1] > a[..., 0] + 30)
    out = np.zeros((sh, sw, 3), np.uint8)
    for part, n in ((green, colours * 2 // 3), (~green, colours // 3)):
        px = a[..., :3][part & solid].astype(np.uint8)
        if not len(px):
            continue
        q = Image.fromarray(px[None]).quantize(n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        out[part & solid] = np.asarray(q.convert("RGB"))[0]
    for row, colour in rails:
        y = round(row * sh / h)
        out[y][solid[y]] = colour
    rgba = np.dstack([out, solid * 255]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA").resize((sw * block, sh * block), Image.NEAREST)


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
    b = np.asarray(back).astype(int)

    # --- Distant city goes to its own (much slower) layer (from the original art)
    city, _ = split_city(b)
    box = (CROP_X0, 0, CROP_X0 + TILE, back.size[1])
    city = Image.fromarray(city.astype(np.uint8), "RGBA").crop(box)
    city.save(OUT / "city.png")

    # --- The railway layer itself: the long viaduct strip, made into a tile and
    # scaled like the other art, with its rails at the same height as before
    deck_top = int(489 * SCALE)  # the near rail's top (where the train's wheels run) in layer pixels
    tile = seamless(Image.open(SRC / "railway_long.png").convert("RGBA"))
    # Rails = rows whose pixels are mostly the warm rail highlight (trees above the
    # deck can also be solid all the way across, so opacity alone is not enough).
    # There are two; the train's wheels stand on the near (lower) one.
    ta = np.asarray(tile)
    lit = np.nonzero(np.median(ta[..., 0], axis=1) > 150)[0]
    groups = np.split(lit, np.nonzero(np.diff(lit) > 2)[0] + 1)
    rail_lines = [(int(g[0]), tuple(int(v) for v in np.median(ta[g[0], :, :3], axis=0))) for g in groups]
    strip = pixelate(tile, RAIL_BLOCK, rails=rail_lines)
    rails = round(groups[-1][0] * strip.size[1] / tile.size[1] / RAIL_BLOCK) * RAIL_BLOCK
    back = Image.new("RGBA", (strip.size[0], 451), (0, 0, 0, 0))
    back.paste(strip, (0, deck_top - rails))
    back.save(OUT / "railway_back.png")

    # --- Backfill: dark foliage behind the railway so no sky shows under the trees
    fill = backfill(back.size[0])
    fill.save(OUT / "railway_fill.png")

    # --- Train: drawn in pixel art at game scale (4 commuter cars)
    train = make_train()
    train.save(OUT / "train.png")
    return back, fill, city, train, deck_top


def make_train(cars=4, car_w=56, gap=2):
    """Side view of a Bangkok-skytrain-style train at dusk (no logos), drawn at
    1/TRAIN_BLOCK resolution and scaled up so its pixels are chunky. Light grey roof,
    red line, white upper body with a black glass window band, royal-blue lower body,
    black cab faces outlined in red. The side is in shade (sun behind); the roof edge
    catches the sunset. Wheels on the bottom row. Moves right; cab at both ends."""
    H = 12
    W = cars * car_w + (cars - 1) * gap
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ink = (20, 18, 36, 255)
    rim, roof = (250, 184, 136, 255), (150, 150, 174, 255)
    red = (206, 46, 58, 255)
    white, white_lo = (206, 208, 226, 255), (164, 168, 198, 255)
    glass, glow = (26, 26, 40, 255), (112, 90, 74, 255)
    blue, blue_lo = (40, 70, 168, 255), (28, 48, 128, 255)
    bogie, wheel = (30, 28, 46, 255), (14, 12, 26, 255)
    trng = random.Random(3)
    for c in range(cars):
        x0 = c * (car_w + gap)
        x1 = x0 + car_w - 1
        d.line([(x0 + 1, 0), (x1 - 1, 0)], fill=rim)            # sunlit roof edge
        d.line([(x0, 1), (x1, 1)], fill=roof)
        d.line([(x0, 2), (x1, 2)], fill=red)                    # red line under the roof
        d.rectangle((x0, 3, x1, 6), fill=white)
        d.rectangle((x0 + 1, 4, x1 - 1, 5), fill=glass)         # black window band
        for wx in range(x0 + 2, x1 - 1, 5):
            if trng.random() < 0.5:
                d.point((wx + 2, 5), fill=glow)                 # dim cabin light
        d.rectangle((x0, 7, x1, 9), fill=blue)
        d.line([(x0, 9), (x1, 9)], fill=blue_lo)
        for k in range(4):                                       # doors
            dx = x0 + 5 + k * (car_w - 13) // 3
            d.rectangle((dx, 3, dx + 2, 9), fill=white_lo)
            d.point((dx + 1, 4), fill=glass)
            d.point((dx + 1, 5), fill=glass)
            d.line([(dx, 7), (dx + 2, 7)], fill=blue_lo)
            d.line([(dx, 8), (dx + 2, 8)], fill=blue_lo)
        for bx in (x0 + 4, x1 - 10):                             # bogies + wheels
            d.rectangle((bx, 10, bx + 6, 10), fill=bogie)
            d.point((bx + 1, 11), fill=wheel)
            d.point((bx + 5, 11), fill=wheel)
        d.line([(x0 + 14, 10), (x1 - 14, 10)], fill=bogie)
        if c < cars - 1:
            d.rectangle((x1 + 1, 3, x1 + gap, 8), fill=(30, 28, 48, 255))
    for end, sign in ((W - 1, -1), (0, 1)):                      # cab faces
        img.putpixel((end, 0), (0, 0, 0, 0))
        img.putpixel((end + sign, 0), (0, 0, 0, 0))
        img.putpixel((end, 1), (0, 0, 0, 0))
        for y in range(1, 7):
            depth = 3 if y > 1 else 2
            for k in range(depth):
                if (end + sign * k, y) != (end, 1):
                    img.putpixel((end + sign * k, y), glass)
            img.putpixel((end + sign * depth, y), red)
        img.putpixel((end + sign, 7), (255, 244, 214, 255) if sign < 0 else (236, 52, 52, 255))
    a = np.asarray(img).copy()                                   # 1px dark outline
    solid = a[..., 3] > 0
    edge = solid & ~(np.roll(solid, 1, 0) & np.roll(solid, -1, 0) & np.roll(solid, 1, 1) & np.roll(solid, -1, 1))
    keep = (a[..., 0] == rim[0]) & (a[..., 1] == rim[1])
    a[edge & ~keep] = ink
    out = Image.fromarray(a, "RGBA")
    return out.resize((W * TRAIN_BLOCK, H * TRAIN_BLOCK), Image.NEAREST)


def make_bird():
    """Tiny backlit bird, two frames (wings up / wings down), 7x4 each."""
    img = Image.new("RGBA", (14, 4), (0, 0, 0, 0))
    ink = (40, 26, 52, 255)
    for (x, y) in ((0, 0), (1, 1), (2, 2), (3, 2), (4, 2), (5, 1), (6, 0), (3, 3)):   # wings up
        img.putpixel((x, y), ink)
    for (x, y) in ((0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (1, 3), (5, 3), (3, 1)):
        img.putpixel((7 + x, y), ink)                                                # wings down
    return img


def dithered(value, block=2, steps=12):
    """Quantize a [0, 1] field to flat steps (pixel-art style bands). A dither pattern
    would show as a screen-door grid in these faint, wide overlays, so there is none."""
    return np.clip(np.round(value * steps) / steps, 0, 1)


def sun_fields(w=SKY_TILE, h=360):
    """Distance to the nearest sun (the sky tile holds the sun and its mirror image)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    suns = (SUN_X, w - SUN_X - 96)          # mirror: sprite offset -48 on both sides
    dx = np.min([np.minimum(np.abs(xx - sx), w - np.abs(xx - sx)) for sx in suns], axis=0)
    return xx, yy, dx, yy - SUN_Y


def build_atmosphere():
    xx, yy, dx, dy = sun_fields()
    h, w = yy.shape
    near_sun = np.exp(-(dx / 260.0) ** 2)
    # --- bloom around the sun
    r = np.sqrt(dx ** 2 + (dy * 1.25) ** 2)
    glow = 0.85 * np.exp(-(r / 70.0) ** 2) + 0.35 * np.exp(-(r / 170.0) ** 2)
    g = dithered(np.clip(glow, 0, 1))
    img = np.zeros((h, w, 4))
    img[..., :3] = np.array((236, 112, 104))
    img[..., 3] = g * 80
    Image.fromarray(img.astype(np.uint8), "RGBA").save(OUT / "sun_glow.png")
    # --- light shafts fanning down from the sun, broken up by the trees they pass
    ang = np.arctan2(dy, np.where(dx == 0, 1e-3, dx))
    rays = np.zeros((h, w))
    rr = random.Random(9)
    for _ in range(9):
        a0, width, strength = rr.uniform(0.25, 1.35), rr.uniform(0.03, 0.08), rr.uniform(0.4, 1.0)
        rays += strength * np.exp(-((ang - a0) / width) ** 2)
    fade = np.clip(dy / 40.0, 0, 1) * np.exp(-np.clip(dy - 40, 0, None) / 120.0) * np.exp(-(dx / 330.0) ** 2)
    shafts = dithered(np.clip(rays * fade * 0.55, 0, 1))
    img = np.zeros((h, w, 4))
    img[..., :3] = np.array((240, 136, 132))
    img[..., 3] = shafts * 45
    Image.fromarray(img.astype(np.uint8), "RGBA").save(OUT / "sun_rays.png")
    # --- haze: densest at the horizon (behind the trees), warm near the sun, violet elsewhere
    for name, peak, centre, spread, strength in (("haze_far.png", 0.55, 205, 55, 1.0),
                                                 ("haze_near.png", 0.2, 160, 30, 0.8)):
        band = np.exp(-((yy - centre) / spread) ** 2)
        band = np.where(yy > centre, np.exp(-((yy - centre) / (spread * 0.45)) ** 2), band)
        a = dithered(np.clip(band * (0.55 + 0.45 * near_sun) * strength, 0, 1)) * peak
        warm, violet = np.array((236, 140, 146)), np.array((150, 112, 178))
        col = violet[None, None] * (1 - near_sun[..., None]) + warm[None, None] * near_sun[..., None]
        img = np.dstack([col, a * 255])
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").save(OUT / name)
    # --- thin cloud streaks, chunky pixels, wrapping (the layer drifts slowly)
    block = 3
    sw, sh = w // block, 140 // block
    small = np.zeros((sh, sw, 4))
    for _ in range(14):
        cx, cy = rr.uniform(0, sw), rr.uniform(4, sh - 6)
        ln, th = rr.uniform(25, 70), rr.uniform(1.0, 2.2)
        lit = rr.uniform(0.6, 1.0)
        yv, xv = np.mgrid[0:sh, 0:sw]
        for off in (-sw, 0, sw):
            d = ((xv - cx - off) / ln) ** 2 + ((yv - cy) / th) ** 2
            m = np.clip(1 - d, 0, 1)
            small[..., 3] = np.maximum(small[..., 3], m * lit)
    yv, xv = np.mgrid[0:sh, 0:sw]
    sun_side = np.exp(-((np.minimum(np.abs(xv * block - SUN_X), sw * block - np.abs(xv * block - SUN_X))) / 400.0) ** 2)
    small[..., :3] = np.array((236, 150, 150)) * (1 - sun_side[..., None]) + np.array((255, 196, 140)) * sun_side[..., None]
    a = dithered(small[..., 3], 1) * 0.55
    small[..., 3] = a * 255
    wisp = Image.fromarray(np.clip(small, 0, 255).astype(np.uint8), "RGBA").resize((sw * block, sh * block), Image.NEAREST)
    canvas = Image.new("RGBA", (w, 360), (0, 0, 0, 0))
    canvas.paste(wisp, (0, 10))
    canvas.save(OUT / "wisps.png")


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

    road = road_surface()
    img = road
    img.alpha_composite(sidewalk())
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
        d.line([(x, STREET_TOP + 8), (x + 20, STREET_TOP + 8)], fill=(190, 180, 200, 255))
    for _ in range(16):  # cracks, some branching
        x, y = rng.randint(20, TILE - 60), rng.randint(STREET_TOP + 12, 350)
        pts = [(x, y)]
        for _k in range(rng.randint(3, 7)):
            x += rng.randint(2, 8)
            y += rng.randint(-1, 1)
            pts.append((x, y))
        d.line(pts, fill=(22, 18, 40, 255))
        if rng.random() < 0.5:
            bx, by = pts[len(pts) // 2]
            d.line([(bx, by), (bx + rng.randint(-4, 4), by + rng.choice((-2, 2)))], fill=(26, 22, 46, 255))
    d.ellipse((520, 324, 566, 333), fill=(40, 36, 66, 255), outline=(20, 16, 36, 255))
    d.ellipse((526, 326, 560, 331), outline=(70, 64, 100, 255))
    img.save(OUT / "road.png")


def tile_noise(h, w, cell, nrng):
    """Smooth value noise in [0, 1] that wraps left-right (w must be a multiple of cell)."""
    gh, gw = h // cell + 2, w // cell
    g = nrng.random((gh, gw))
    y = np.arange(h) / cell
    x = np.arange(w) / cell
    y0, x0 = y.astype(int), x.astype(int)
    fy, fx = (y - y0)[:, None], (x - x0)[None, :]
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    x1 = (x0 + 1) % gw
    a, b = g[y0][:, x0], g[y0][:, x1]
    c, d = g[y0 + 1][:, x0], g[y0 + 1][:, x1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def sidewalk(block=2):
    """Thai sidewalk where the hero walks: rows of concrete paving slabs (smaller far
    away), worn and patched, then a plain concrete kerb down to the street.
    Mostly opaque: damp slabs only let a little reflection through."""
    sr = random.Random(17)
    w, h = TILE // block, 360 // block
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    grout, moss = (60, 52, 80, 245), (54, 66, 66, 245)
    y = ROAD_TOP // block
    rows = []
    for k, rh in enumerate((3, 4, 4)):                 # slab rows, far to near (foreshortened)
        rows.append((y, y + rh - 1, k))
        y += rh
    for y0, y1, k in rows:
        shift = (k % 2) * 6                            # staggered like bricks
        for x0 in range(-12 + shift, w, 12):
            tone = sr.uniform(-3, 3) - k * 3                          # subtle: the ground stays quiet
            base = (int(78 + tone), int(68 + tone), int(96 + tone))
            damp = sr.random() < 0.18
            a = 205 if damp else 245
            if damp:
                base = tuple(int(c * 0.8) for c in base)
            xs = [(x % w) for x in range(x0, x0 + 12)]
            for x in xs:
                d.line([(x, y0), (x, y1)], fill=base + (a,))
                if k == 0:                                             # only the far row catches a little light
                    d.point((x, y0), fill=(base[0] + 8, base[1] + 5, base[2] + 7, a))
            d.line([(xs[0], y0), (xs[0], y1)], fill=grout)           # grout between slabs
            if sr.random() < 0.08:                                    # cracked slab
                cx = xs[0] + sr.randint(3, 8)
                d.line([((cx) % w, y0 + 1), ((cx + 2) % w, y1)], fill=grout)
            if sr.random() < 0.12:                                    # stain
                d.point(((xs[0] + sr.randint(2, 10)) % w, sr.randint(y0 + 1, y1)), fill=(66, 56, 82, 245))
            if sr.random() < 0.15:                                    # moss in the joint
                d.point((xs[0], sr.randint(y0, y1)), fill=moss)
        d.line([(0, y1), (w, y1)], fill=grout)
    ky = KERB_Y // block
    d.line([(0, ky - 1), (w, ky - 1)], fill=(98, 86, 112, 250))      # kerb top edge, faintly lit
    for x0 in range(0, w, 18):                                       # plain concrete kerb blocks
        tone = sr.uniform(-6, 6)
        col = (int(66 + tone / 2), int(57 + tone / 2), int(82 + tone / 2), 255)
        d.rectangle((x0, ky, x0 + 17, STREET_TOP // block - 2), fill=col)
        d.line([(x0, ky), (x0, STREET_TOP // block - 2)], fill=(58, 50, 74, 255))   # joint
        for _ in range(3):                                            # chips and stains
            d.point((x0 + sr.randint(1, 17), sr.randint(ky, STREET_TOP // block - 2)), fill=(60, 52, 76, 255))
    d.line([(0, STREET_TOP // block - 1), (w, STREET_TOP // block - 1)], fill=(30, 24, 44, 255))
    return img.resize((TILE, 360), Image.NEAREST)


def road_surface(block=2):
    """Asphalt for the road layer, drawn at 1/block resolution (chunky pixels) and
    semi-transparent where it is wet, so the reflection layers below show through.
    Wetness fades out gradually (dithered steps) instead of hard puddle edges; even the
    deepest puddle keeps some asphalt and ripples on top, so it is not a mirror.
    The surface has aggregate grain, patches, repairs, oil stains and tyre tracks."""
    nrng = np.random.default_rng(12)
    h, w = 360 // block, TILE // block
    top = STREET_TOP // block
    yy, xx = np.mgrid[0:h, 0:w]
    t = np.clip((yy - top) / (h - top), 0, 1)            # 0 at the far kerb, 1 at the bottom
    dither = BAYER[yy % 4, xx % 4]

    # --- wetness: soft puddles with ragged edges + damp patches + wetter gutter by the kerb
    ragged = tile_noise(h, w, 6, nrng)
    wet = np.zeros((h, w))
    for _ in range(8):
        cx, cy = nrng.uniform(0, w), nrng.uniform(top + 6, h - 4)
        rx, ry = nrng.uniform(14, 34), nrng.uniform(2.5, 6) * (0.7 + 0.6 * (cy - top) / (h - top))
        for off in (-w, 0, w):
            dist = np.sqrt(((xx - cx - off) / rx) ** 2 + ((yy - cy) / ry) ** 2)
            dist = dist * (0.8 + 0.5 * ragged)              # ragged outline
            wet = np.maximum(wet, np.clip(1.3 - dist, 0, 1))
    damp = tile_noise(h, w, 30, nrng)
    wet = np.maximum(wet, np.clip(damp - 0.45, 0, 1) * 0.9)
    gutter = np.clip(1 - (yy - top) / 4, 0, 1) * (tile_noise(h, w, 10, nrng) > 0.58)
    wet = np.maximum(wet, gutter * 0.4)                                # broken puddles by the kerb
    levels = 4                                               # dithered steps, pixel-art style
    wetq = np.floor(np.clip(wet, 0, 1) * levels + dither * 0.999) / levels
    wetq = np.clip(wetq, 0, 1)

    # --- dry asphalt colour and texture
    far, near = np.array((60, 54, 96.0)), np.array((32, 30, 58.0))
    col = far * (1 - t[..., None]) + near * t[..., None]
    col += (tile_noise(h, w, 12, nrng)[..., None] - 0.5) * 14          # uneven tone
    grain = nrng.random((h, w))
    col[grain < 0.07] += 16                                           # light aggregate
    col[grain > 0.95] -= 12                                           # dark pits
    for ty in (0.38, 0.47, 0.78, 0.88):                               # tyre tracks (worn, darker)
        band = np.abs(t - ty) < 0.035
        col[band] -= 6
    for _ in range(4):                                                # patched repairs
        px, py = int(nrng.uniform(0, w)), int(nrng.uniform(top + 4, h - 10))
        pw, ph = int(nrng.uniform(10, 26)), int(nrng.uniform(3, 7))
        cols = np.arange(px, px + pw) % w
        col[py:py + ph][:, cols] = col[py:py + ph][:, cols] * 0.88 + 4
        col[py, cols] -= 8
        col[py + ph - 1, cols] -= 8
    for _ in range(5):                                                # oil stains
        cx, cy = nrng.uniform(0, w), nrng.uniform(top + 8, h - 4)
        rx, ry = nrng.uniform(3, 8), nrng.uniform(1, 2.5)
        for off in (-w, 0, w):
            m = ((xx - cx - off) / rx) ** 2 + ((yy - cy) / ry) ** 2 < 1
            col[m] = col[m] * 0.75 + np.array((14, 6, 24)) * 0.25
    col *= (1 - 0.28 * wetq)[..., None]                                # wet asphalt is darker
    col = np.floor(col / 6 + dither[..., None] * 0.9) * 6

    # --- how much reflection shows: a little on damp asphalt (more at a grazing angle,
    # far away), at most about half in the deepest puddles
    show = (0.05 + 0.04 * (1 - t) ** 2) + wetq * (0.4 + 0.04 * (1 - t))
    alpha = 1 - np.clip(show, 0, 0.62)

    # --- ripples / sky glints on the puddles: short light dashes on the surface
    glint = (wetq >= 0.75) & (nrng.random((h, w)) < 0.05)
    glint_x = glint | np.roll(glint, 1, axis=1)
    col[glint_x] = np.array((150, 126, 176))
    alpha[glint_x] = 0.85

    out = np.zeros((h, w, 4))
    out[..., :3] = col
    out[..., 3] = alpha * 255
    out[:top] = 0
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    return img.resize((TILE, 360), Image.NEAREST)


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


def build_foreground(block=2):
    """Near utility pole (Thai concrete pole) with wires to the previous pole, drawn at
    1/block resolution so its pixels are chunky. Backlit by the low sun on the left:
    dark body, a pink-orange rim on the sun side."""
    w, h = FG_TILE // block, 360 // block
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pr = random.Random(4)
    px = 900 // block                     # pole centre; the previous tile's pole is at px - w
    rim, lit, body, shade, dark = (226, 136, 132), (84, 68, 104), (50, 40, 72), (34, 27, 52), (20, 16, 34)
    wire = (16, 12, 30)
    # --- wires first (behind the pole): power lines from the insulators, then a sagging
    # bundle of telecom cables lower down, all hanging towards the previous pole
    def sag_line(x0, y0, sag, width=1, colour=wire, step=0):
        x1 = x0 - w
        pts = [(x0 + (x1 - x0) * t, y0 + sag * 4 * t * (1 - t)) for t in np.linspace(0, 1, 120)]
        for off in (0, w):
            d.line([(p[0] + off, p[1]) for p in pts], fill=colour, width=width)
    for k, (dx, y0) in enumerate(((-17, 8), (-9, 8), (8, 8), (-7, 16))):
        sag_line(px + dx, y0, 13 + 4 * k)
    for k in range(3):                    # telecom bundle
        sag_line(px - 4, 36 + k, 10 + 2 * k, colour=(24, 18, 38) if k % 2 else wire)
    # --- tapered concrete pole
    for y in range(h):
        half = int(round(4.5 + 1.6 * y / h))
        x0, x1 = px - half, px + half
        d.line([(x0, y), (x1, y)], fill=body)
        d.line([(x1 - 1, y), (x1, y)], fill=shade)
        d.point((x0, y), fill=rim)
        d.point((x0 + 1, y), fill=lit)
    for y in range(20, h, 9):             # concrete seams / stains
        d.line([(px - 3, y), (px + 3, y)], fill=shade)
    for _ in range(40):
        d.point((px + pr.randint(-4, 4), pr.randint(10, h - 1)), fill=dark)
    for i, y in enumerate(range(66, h - 10, 7)):  # climbing steps, left and right
        sx = px - 7 if i % 2 == 0 else px + 6
        d.line([(sx, y), (sx + 1, y)], fill=(70, 62, 92))
    # --- cross-arms with ceramic insulators
    for y, x0, x1, cups in ((10, px - 20, px + 18, (-17, -9, 8, 15)), (18, px - 10, px + 9, (-7, 6))):
        d.rectangle((x0, y, x1, y + 1), fill=shade)
        d.line([(x0, y), (x1, y)], fill=rim)
        d.line([(px - 4, y + 2), (x0 + 4, y + 6)], fill=shade)      # brace
        for c in cups:
            d.rectangle((px + c, y - 3, px + c + 1, y - 1), fill=(190, 172, 196))
            d.point((px + c, y - 3), fill=(236, 210, 220))
    # --- transformer drum on a bracket, with cooling fins and bushings
    tx, ty = px + 7, 26
    d.rectangle((px + 4, ty + 3, tx, ty + 4), fill=dark)
    d.rectangle((tx, ty, tx + 9, ty + 13), fill=(58, 54, 84))
    for fx in range(tx + 1, tx + 9, 2):
        d.line([(fx, ty + 3), (fx, ty + 11)], fill=(42, 38, 64))
    d.line([(tx, ty), (tx + 9, ty)], fill=(160, 120, 140))
    for bx in (tx + 2, tx + 7):
        d.rectangle((bx, ty - 2, bx, ty - 1), fill=(190, 172, 196))
    # --- street lamp arm reaching over the road, lamp just switched on
    d.line([(px - 5, 30), (px - 14, 27), (px - 20, 27)], fill=shade, width=1)
    d.rectangle((px - 24, 26, px - 19, 28), fill=(40, 34, 60))
    d.line([(px - 23, 29), (px - 20, 29)], fill=(255, 226, 180))
    # --- coiled cable loop and junction box
    d.ellipse((px + 3, 40, px + 11, 48), outline=wire)
    d.ellipse((px + 4, 41, px + 10, 47), outline=(28, 22, 42))
    d.rectangle((px - 11, 56, px - 6, 63), fill=(70, 66, 92))
    d.line([(px - 11, 56), (px - 6, 56)], fill=(150, 130, 150))
    d.point((px - 9, 59), fill=(220, 90, 80))
    # --- notices stuck on the pole (faded paper, a line of text each)
    for y, colour in ((92, (176, 160, 176)), (100, (196, 150, 150)), (130, (170, 170, 190))):
        d.rectangle((px - 3, y, px + 2, y + 5), fill=colour)
        d.line([(px - 2, y + 2), (px + 1, y + 2)], fill=(90, 80, 110))
        d.point((px - 2, y + 4), fill=(90, 80, 110))
    big = img.resize((w * block, h * block), Image.NEAREST)
    big.save(OUT / "foreground.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    sky = build_sky()
    back, fill, city, train, deck_top = build_railway()
    build_road(sky, city, fill, back)
    build_foreground()
    make_bird().save(OUT / "bird.png")
    build_atmosphere()
    print(f"layers written to {OUT}; railway tile {back.size[0]}px (RAIL_TILE), "
          f"train {train.size}, train top y in layer = {deck_top - train.size[1]}")
