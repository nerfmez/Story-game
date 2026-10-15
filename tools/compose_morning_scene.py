"""Build the morning version of the railway scene in assets/bg/morning/.

Same layer names and sizes as assets/bg/sunset/ (the game swaps each sunset texture
for the morning one with the same name), made from:
  sky.png           art_source/morning_sky.png (blue sky, white clouds), scaled and
                    mirrored into a seamless tile like the sunset sky
  railway_back.png  the railway art is already in daylight greens: a touch brighter
  city.png          the distant city fades towards the sky colour (daylight haze)
  railway_fill.png, road.png, foreground.png
                    the sunset layers recoloured by hue for morning light: violet greys
                    become light blue-grey concrete/asphalt, the orange-pink sunset rims
                    pale highlights (light yellow-green leaves on the hedge), navy shadows
                    dark teal-green; brighter overall
  train.png         the skytrain in sunlight (white/blue/red, dark glass, lights off)
  sky/city/rail_reflect.png  the wet road mirrors the morning layers
  haze_far.png, haze_near.png  thin pale-blue haze where the sunset haze was
The sunset-only layers (sun glow, rays, cloud wisps, train window glow) have no
morning version; the game hides them.

Run tools/compose_sunset_scene.py first (this reads its output).
Usage: python3 tools/compose_morning_scene.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

import compose_sunset_scene as sunset

SUNSET = sunset.OUT
OUT = sunset.ROOT / "assets" / "bg" / "morning"
SKY_COLOUR = np.array((150, 200, 246.0))       # the sky near the horizon in morning_sky.png


def rgb_to_hsv(rgb):
    r, g, b = (rgb[..., i] for i in range(3))
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    h = np.where(mx - mn < 1e-6, 0, h)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    c = v * s
    x = c * (1 - np.abs((h / 60) % 2 - 1))
    m = v - c
    k = (h // 60).astype(int) % 6
    z = np.zeros_like(h)
    r = np.choose(k, [c, x, z, z, x, c])
    g = np.choose(k, [x, c, c, x, z, z])
    b = np.choose(k, [z, z, x, c, c, x])
    return np.stack([r + m, g + m, b + m], -1)


def to_morning(img, exposure=1.35, rim=(48, 0.35, 0.85)):
    """Recolour a sunset layer for morning light, by hue (alpha untouched).
    rim = (hue, saturation scale, lowest value) for the sunset-lit edges."""
    a = np.asarray(img.convert("RGBA")).astype(float)
    h, s, v = rgb_to_hsv(a[..., :3] / 255.0)
    violet = (h >= 215) & (h <= 335)                 # the dusk cast on greys, navy shadows
    grey = violet & (s < 0.5)
    navy = violet & ~grey
    warm = ((h < 45) | (h > 335)) & (s > 0.25)        # sunset rims, pink-orange light
    green = (h >= 60) & (h < 180)
    h2, s2, v2 = h.copy(), s.copy(), v * exposure
    h2[grey], s2[grey] = 212, s[grey] * 0.45          # concrete / asphalt: light blue-grey
    h2[navy], s2[navy] = 190, s[navy] * 0.75          # shadows in foliage: dark teal-green
    h2[warm], s2[warm] = rim[0], s[warm] * rim[1]     # sunset rims -> morning highlights
    v2[warm] = np.maximum(v2[warm], rim[2])
    s2[green] = np.minimum(1, s[green] * 1.05)
    rgb = hsv_to_rgb(h2, np.clip(s2, 0, 1), np.clip(v2, 0, 1)) * 255
    out = np.dstack([rgb, a[..., 3]])
    return Image.fromarray(np.clip(out, 0, 255).round().astype(np.uint8), "RGBA")


def brighten(img, k):
    a = np.asarray(img.convert("RGBA")).astype(float)
    a[..., :3] *= k
    return Image.fromarray(np.clip(a, 0, 255).round().astype(np.uint8), "RGBA")


def fade_to_sky(img, amount, exposure=1.3):
    """Distant things in daylight: brighter and washed towards the sky colour."""
    a = np.asarray(img.convert("RGBA")).astype(float)
    a[..., :3] = a[..., :3] * exposure * (1 - amount) + SKY_COLOUR * amount
    return Image.fromarray(np.clip(a, 0, 255).round().astype(np.uint8), "RGBA")


def build_sky():
    sky = sunset.scaled(Image.open(sunset.SRC / "morning_sky.png").convert("RGBA"))
    sky = sky.resize((sunset.LAYER_W, round(sky.size[1] * sunset.LAYER_W / sky.size[0])), Image.NEAREST)
    sky = sky.crop((0, 45, sunset.LAYER_W, 405))
    tile = Image.new("RGBA", (sunset.SKY_TILE, 360))
    tile.paste(sky, (0, 0))
    tile.paste(sky.transpose(Image.FLIP_LEFT_RIGHT), (sunset.LAYER_W, 0))   # mirror -> seamless
    return tile


def haze(name, colour=(214, 232, 248), strength=0.55):
    a = np.asarray(Image.open(SUNSET / name).convert("RGBA")).astype(float)
    out = np.zeros_like(a)
    out[..., :3] = colour
    out[..., 3] = a[..., 3] * strength
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sky = build_sky()
    sky.save(OUT / "sky.png")
    city = fade_to_sky(Image.open(SUNSET / "city.png"), 0.5)
    city.save(OUT / "city.png")
    back = brighten(Image.open(SUNSET / "railway_back.png"), 1.06)
    back.save(OUT / "railway_back.png")
    fill = to_morning(Image.open(SUNSET / "railway_fill.png"), 1.25)
    fill.save(OUT / "railway_fill.png")
    # the hedge tops on the road layer: sun on the leaves, light yellow-green
    to_morning(Image.open(SUNSET / "road.png"), rim=(78, 1.0, 0.72)).save(OUT / "road.png")
    to_morning(Image.open(SUNSET / "foreground.png"), 1.5).save(OUT / "foreground.png")
    train, _ = sunset.make_train(daylight=True)
    train.save(OUT / "train.png")
    # the wet road mirrors the morning layers (tinted towards the sky, not violet)
    tint = (70, 96, 130)
    sunset.mirror(sky, 0, sunset.SKY_TILE, tint=tint).save(OUT / "sky_reflect.png")
    sunset.mirror(city, sunset.RAIL_Y, sunset.TILE, tint=tint).save(OUT / "city_reflect.png")
    rail = fill.copy()
    rail.alpha_composite(back)
    sunset.mirror(rail, sunset.RAIL_Y, rail.size[0], tint=tint).save(OUT / "rail_reflect.png")
    haze("haze_far.png").save(OUT / "haze_far.png")
    haze("haze_near.png", strength=0.4).save(OUT / "haze_near.png")
    print("morning layers written to", OUT)


if __name__ == "__main__":
    main()
