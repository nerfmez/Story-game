"""Generate the simple placeholder layers used by the HD-2D scene (sky, city, leaves).

The 2D scene uses the anime-style layers from tools/make_anime_bg.py instead.

Replace the PNGs in assets/ with real art (e.g. exported from Aseprite)
at any time; keep the same file names and roughly the same sizes.

Usage: python3 tools/make_placeholder_art.py
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BG = ROOT / "assets" / "bg" / "hd2d"

# Base game resolution is 640x360. Layers are wider so the camera can pan.
W, H = 800, 360
rng = random.Random(7)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def sky():
    img = Image.new("RGBA", (W, H))
    px = img.load()
    stops = [(0.0, (38, 40, 104)), (0.35, (96, 70, 150)), (0.6, (214, 120, 130)), (0.8, (246, 160, 110)), (1.0, (252, 210, 140))]
    sun = (385, 210)
    for y in range(H):
        t = y / (H - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                lt = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                for x in range(W):
                    # Quantised bands with ordered dithering for a pixel-art look
                    d = ((x % 2) * 2 + (y % 2)) / 4 * 0.12
                    band = min(1.0, math.floor((lt + d) * 7) / 7)
                    col = lerp(stops[i][1], stops[i + 1][1], band)
                    # Warm halo around the sun
                    dist = math.hypot(x - sun[0], (y - sun[1]) * 1.4)
                    glow = max(0.0, 1.0 - dist / 170.0)
                    glow = math.floor((glow + d) * 5) / 5
                    px[x, y] = lerp(col, (255, 214, 150), glow * 0.75) + (255,)
                break
    draw = ImageDraw.Draw(img)
    draw.ellipse((sun[0] - 26, sun[1] - 26, sun[0] + 26, sun[1] + 26), fill=(255, 226, 160, 255))
    draw.ellipse((sun[0] - 19, sun[1] - 19, sun[0] + 19, sun[1] + 19), fill=(255, 246, 210, 255))
    # Long sunset clouds: dark purple tops, glowing orange undersides
    for _ in range(16):
        cx, cy = rng.randint(-40, W + 40), rng.randint(30, 190)
        length = rng.randint(60, 180)
        thick = rng.randint(5, 11)
        near_sun = cy > 110
        top = (122, 84, 150) if near_sun else (92, 72, 140)
        under = (255, 170, 120) if near_sun else (200, 130, 160)
        for k in range(rng.randint(3, 6)):
            ox = rng.randint(-length // 3, length // 3)
            w = rng.randint(length // 3, length)
            y0 = cy + rng.randint(-thick, thick // 2)
            draw.rectangle((cx + ox, y0, cx + ox + w, y0 + thick), fill=top + (255,))
            draw.rectangle((cx + ox + 4, y0 + thick - 2, cx + ox + w - 4, y0 + thick), fill=under + (255,))
    img.save(BG / "01_sky.png")


def city_far():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = 0
    while x < W:
        w, h = rng.randint(20, 46), rng.randint(40, 110)
        top = 230 - h
        d.rectangle((x, top, x + w, 240), fill=(70, 60, 120, 255))
        for wy in range(top + 6, 228, 8):
            for wx in range(x + 4, x + w - 4, 7):
                if rng.random() < 0.25:
                    d.rectangle((wx, wy, wx + 2, wy + 3), fill=(255, 200, 120, 255))
        x += w + rng.randint(0, 6)
    # Trees line
    for tx in range(0, W, 10):
        r = rng.randint(8, 16)
        d.ellipse((tx - r, 225 - r, tx + r, 225 + r), fill=(40, 70, 70, 255))
    # Power poles
    for px_ in range(40, W, 180):
        d.rectangle((px_, 120, px_ + 3, 240), fill=(30, 30, 50, 255))
        d.rectangle((px_ - 10, 128, px_ + 13, 130), fill=(30, 30, 50, 255))
    img.save(BG / "02_city_far.png")


def train():
    img = Image.new("RGBA", (300, 34), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for car in range(3):
        x0 = car * 100
        d.rectangle((x0 + 2, 2, x0 + 96, 30), fill=(90, 90, 150, 255))
        d.rectangle((x0 + 2, 24, x0 + 96, 30), fill=(60, 60, 110, 255))
        for wx in range(x0 + 8, x0 + 90, 14):
            d.rectangle((wx, 8, wx + 8, 16), fill=(255, 220, 140, 255))
    img.save(BG / "03_train.png")


def mid():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # School gate (left)
    d.rectangle((30, 120, 250, 270), fill=(215, 210, 200, 255))
    d.rectangle((50, 140, 230, 180), fill=(30, 40, 80, 255))
    d.rectangle((136, 150, 144, 168), fill=(220, 180, 80, 255))
    for gx in range(60, 230, 10):
        d.rectangle((gx, 190, gx + 2, 270), fill=(40, 40, 50, 255))
    d.rectangle((20, 100, 44, 275), fill=(230, 225, 215, 255))
    d.rectangle((240, 100, 264, 275), fill=(230, 225, 215, 255))
    # Railway crossing sign
    d.rectangle((440, 170, 444, 275), fill=(50, 50, 60, 255))
    d.line((426, 160, 458, 184), fill=(240, 240, 240, 255), width=4)
    d.line((426, 184, 458, 160), fill=(240, 240, 240, 255), width=4)
    for lx in (428, 452):
        d.ellipse((lx - 6, 192, lx + 6, 204), fill=(220, 40, 40, 255))
    # Drink shop (right)
    d.rectangle((520, 130, 790, 275), fill=(120, 80, 60, 255))
    d.rectangle((540, 160, 780, 270), fill=(255, 210, 140, 255))
    for i, sx in enumerate(range(510, 640, 16)):
        d.rectangle((sx, 140, sx + 15, 156), fill=(60, 90, 160, 255) if i % 2 else (230, 230, 240, 255))
    for bx in range(560, 780, 30):
        d.rectangle((bx, 162, bx + 2, 170), fill=(255, 250, 220, 255))
    for i in range(30):
        bx, by = rng.randint(620, 770), rng.randint(185, 255)
        d.rectangle((bx, by, bx + 6, by + 8), fill=rng.choice([(220, 80, 70, 255), (80, 160, 200, 255), (240, 200, 80, 255)]))
    d.rectangle((510, 120, 800, 132), fill=(90, 60, 50, 255))
    img.save(BG / "04_mid.png")


def ground():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 270, W, H), fill=(50, 55, 95, 255))
    # Wet reflections: horizontal dashes of warm/cool light
    for _ in range(260):
        x, y = rng.randint(0, W), rng.randint(272, H)
        w = rng.randint(4, 22)
        col = rng.choice([(250, 180, 110, 255), (120, 120, 190, 255), (255, 220, 150, 255), (80, 85, 140, 255)])
        d.rectangle((x, y, x + w, y), fill=col)
    img.save(BG / "05_ground.png")


def foreground():
    img = Image.new("RGBA", (W + 200, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for cx, cy, n in ((150, 10, 40), (850, 30, 40), (200, 345, 18)):
        for _ in range(n):
            x, y = cx + rng.randint(-70, 70), cy + rng.randint(-40, 50)
            r = rng.randint(5, 12)
            col = rng.choice([(40, 90, 50, 255), (60, 120, 60, 255), (90, 150, 70, 255)])
            d.ellipse((x - r, y - r // 2, x + r, y + r // 2), fill=col)
    img.save(BG / "06_foreground.png")


if __name__ == "__main__":
    BG.mkdir(parents=True, exist_ok=True)
    sky(); city_far(); foreground()
    print("placeholder art written to", BG)
    print("characters: python3 tools/make_characters.py")
