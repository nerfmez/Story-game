"""Generate placeholder pixel-art layers for the parallax demo scene.

Replace the PNGs in assets/ with real art (e.g. exported from Aseprite)
at any time; keep the same file names and roughly the same sizes.

Usage: python3 tools/make_placeholder_art.py
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BG = ROOT / "assets" / "bg"
CHARS = ROOT / "assets" / "characters"

# Base game resolution is 640x360. Layers are wider so the camera can pan.
W, H = 800, 360
rng = random.Random(7)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def sky():
    img = Image.new("RGBA", (W, H))
    px = img.load()
    stops = [(0.0, (40, 44, 110)), (0.45, (120, 80, 150)), (0.7, (235, 140, 110)), (1.0, (250, 200, 120))]
    for y in range(H):
        t = y / (H - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                lt = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                # Quantise into bands for a pixel-art look, with 2x2 dithering.
                for x in range(W):
                    d = ((x + y) % 2) * 0.06
                    band = math.floor((lt + d) * 6) / 6
                    px[x, y] = lerp(stops[i][1], stops[i + 1][1], band) + (255,)
                break
    draw = ImageDraw.Draw(img)
    # Sun
    draw.ellipse((360, 150, 410, 200), fill=(255, 225, 150, 255))
    draw.ellipse((368, 158, 402, 192), fill=(255, 240, 190, 255))
    # Pixel clouds
    for _ in range(14):
        cx, cy = rng.randint(0, W), rng.randint(20, 170)
        col = (250, 170, 120, 255) if cy > 100 else (150, 110, 170, 255)
        for _ in range(rng.randint(4, 9)):
            w, h = rng.randint(16, 50), rng.randint(4, 10)
            ox, oy = rng.randint(-30, 30), rng.randint(-6, 6)
            draw.rectangle((cx + ox, cy + oy, cx + ox + w, cy + oy + h), fill=col)
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


def character(name, hair, skirt=False, glasses=False):
    img = Image.new("RGBA", (24, 56), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin, shirt, navy = (240, 200, 160, 255), (235, 235, 250, 255), (35, 45, 90, 255)
    d.rectangle((7, 4, 16, 14), fill=skin)  # head
    d.rectangle((6, 1, 17, 6), fill=hair)  # hair
    if skirt:
        d.rectangle((5, 3, 7, 18), fill=hair)
        d.rectangle((16, 3, 18, 18), fill=hair)
    if glasses:
        d.rectangle((8, 8, 15, 9), fill=(20, 20, 20, 255))
    else:
        d.point((10, 9), fill=(20, 20, 20, 255))
        d.point((14, 9), fill=(20, 20, 20, 255))
    d.rectangle((5, 15, 18, 30), fill=shirt)  # shirt
    d.rectangle((3, 16, 5, 28), fill=shirt)  # arms
    d.rectangle((18, 16, 20, 28), fill=shirt)
    if skirt:
        d.polygon([(5, 30), (18, 30), (20, 40), (3, 40)], fill=navy)
        d.rectangle((7, 40, 9, 50), fill=skin)
        d.rectangle((14, 40, 16, 50), fill=skin)
    else:
        d.rectangle((5, 30, 18, 38), fill=navy)
        d.rectangle((7, 38, 9, 50), fill=skin)
        d.rectangle((14, 38, 16, 50), fill=skin)
    d.rectangle((6, 50, 10, 54), fill=(20, 20, 25, 255))  # shoes
    d.rectangle((13, 50, 17, 54), fill=(20, 20, 25, 255))
    img.save(CHARS / f"{name}.png")


if __name__ == "__main__":
    BG.mkdir(parents=True, exist_ok=True)
    CHARS.mkdir(parents=True, exist_ok=True)
    sky(); city_far(); train(); mid(); ground(); foreground()
    character("friend_girl", (60, 40, 30, 255), skirt=True)
    character("player", (20, 20, 30, 255))
    character("friend_glasses", (25, 25, 35, 255), glasses=True)
    print("placeholder art written to", BG, "and", CHARS)
