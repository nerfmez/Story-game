"""Build the rainy dawn version of the railway scene in assets/bg/rain/.

Early morning, overcast, raining: dim, cool and wet. Same layer names and sizes as
assets/bg/sunset/ (the game swaps each sunset texture for the one with the same name):
  sky.png           art_source/rain_sky.png (heavy blue-grey clouds), scaled and
                    mirrored into a seamless tile like the sunset sky
  railway_back.png, railway_fill.png, foreground.png
                    recoloured for flat grey light: the sunset hues are turned into
                    daylight ones first (compose_morning_scene.to_morning), then
                    desaturated, cooled towards blue-grey and darkened ("gloom")
  road.png          the wet road (puddles kept: it is raining), recoloured the same way;
                    the hedge's sunset rims become dull wet green
  city.png          the distant city nearly lost in the rain haze
  train.png         the skytrain in its real paint (white / royal blue / red line), dimmed
                    by the overcast, with its cabin lights on (the warm window band stays
                    warm; train_glow.png is the same as at sunset)
  sky/city/rail_reflect.png  the puddles mirror the rainy layers
  haze_far.png, haze_near.png  thick grey-blue rain haze
The rain itself (falling streaks, splashes) is drawn in the game (shaders/rain.gdshader).

Run tools/compose_sunset_scene.py first (this reads its output).
Usage: python3 tools/compose_rain_scene.py
"""
import numpy as np
from PIL import Image

import compose_morning_scene as morning
import compose_sunset_scene as sunset

SUNSET = sunset.OUT
OUT = sunset.ROOT / "assets" / "bg" / "rain"
HAZE = np.array((104, 120, 150.0))            # the rain haze / sky low down in rain_sky.png


def gloom(img, exposure=0.72, desat=0.55, tint=(70, 86, 116), tint_amount=0.22):
    """Overcast light: less colour, cooler, darker."""
    a = np.asarray(img.convert("RGBA")).astype(float)
    rgb = a[..., :3]
    lum = rgb @ np.array((0.299, 0.587, 0.114))
    out = rgb * (1 - desat) + lum[..., None] * desat
    out = out * exposure * (1 - tint_amount) + np.array(tint) * tint_amount
    a[..., :3] = out
    return Image.fromarray(np.clip(a, 0, 255).round().astype(np.uint8), "RGBA")


def build_sky():
    sky = sunset.scaled(Image.open(sunset.SRC / "rain_sky.png").convert("RGBA"))
    sky = sky.resize((sunset.LAYER_W, round(sky.size[1] * sunset.LAYER_W / sky.size[0])), Image.NEAREST)
    sky = sky.crop((0, 45, sunset.LAYER_W, 405))
    tile = Image.new("RGBA", (sunset.SKY_TILE, 360))
    tile.paste(sky, (0, 0))
    tile.paste(sky.transpose(Image.FLIP_LEFT_RIGHT), (sunset.LAYER_W, 0))   # mirror -> seamless
    return tile


def fade_to_haze(img, amount, exposure=0.8):
    a = np.asarray(img.convert("RGBA")).astype(float)
    a[..., :3] = a[..., :3] * exposure * (1 - amount) + HAZE * amount
    return Image.fromarray(np.clip(a, 0, 255).round().astype(np.uint8), "RGBA")


def haze(name, colour=(112, 128, 158), strength=0.95):
    a = np.asarray(Image.open(SUNSET / name).convert("RGBA")).astype(float)
    out = np.zeros_like(a)
    out[..., :3] = colour
    out[..., 3] = np.clip(a[..., 3] * strength * 1.4, 0, 255)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sky = build_sky()
    sky.save(OUT / "sky.png")
    city = fade_to_haze(Image.open(SUNSET / "city.png"), 0.7)
    city.save(OUT / "city.png")
    back = gloom(Image.open(SUNSET / "railway_back.png"), 0.66, 0.62)
    back.save(OUT / "railway_back.png")
    fill = gloom(morning.to_morning(Image.open(SUNSET / "railway_fill.png"), 1.1), 0.7, 0.55)
    fill.save(OUT / "railway_fill.png")
    # wet road with its puddles; hedge rims (sunset orange) -> dull wet green
    road = morning.to_morning(Image.open(SUNSET / "road.png"), 1.05, rim=(84, 0.7, 0.5))
    gloom(road, 0.74, 0.55).save(OUT / "road.png")
    gloom(morning.to_morning(Image.open(SUNSET / "foreground.png"), 1.2), 0.8, 0.4).save(OUT / "foreground.png")
    # train in the gloom, cabin lights on: everything but the lit windows goes grey-blue
    # train: its real paint (white / royal blue / red line) dimmed by the overcast, cabin
    # lights on; the lit windows stay as they are
    train, lit = sunset.make_train(daylight=True, lights=True)
    big = np.asarray(Image.fromarray((lit * 255).astype(np.uint8)).resize(train.size, Image.NEAREST)) > 0
    grey = np.asarray(gloom(train, 0.66, 0.3, tint_amount=0.12)).copy()
    grey[big] = np.asarray(train)[big]
    Image.fromarray(grey, "RGBA").save(OUT / "train.png")
    tint = (40, 50, 72)
    sunset.mirror(sky, 0, sunset.SKY_TILE, tint=tint).save(OUT / "sky_reflect.png")
    sunset.mirror(city, sunset.RAIL_Y, sunset.TILE, tint=tint).save(OUT / "city_reflect.png")
    rail = fill.copy()
    rail.alpha_composite(back)
    sunset.mirror(rail, sunset.RAIL_Y, rail.size[0], tint=tint).save(OUT / "rail_reflect.png")
    haze("haze_far.png").save(OUT / "haze_far.png")
    haze("haze_near.png", strength=0.7).save(OUT / "haze_near.png")
    print("rain layers written to", OUT)


if __name__ == "__main__":
    main()
