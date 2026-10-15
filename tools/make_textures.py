"""Generate tileable pixel-art textures for the HD-2D scene.

Each texture is small (64x64 unless noted) and is shown with Nearest filtering,
so every texel reads as a crisp pixel. Swap in hand-made textures with the same
file names at any time.

Usage: python3 tools/make_textures.py
"""
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures"
rng = random.Random(3)


def shade(col, amount):
    return tuple(max(0, min(255, int(c + amount))) for c in col[:3]) + (col[3] if len(col) > 3 else 255,)


def noise_fill(px, w, h, base, spread):
    for y in range(h):
        for x in range(w):
            px[x, y] = shade(base, rng.randint(-spread, spread))


def plaster():
    img = Image.new("RGBA", (64, 64))
    px = img.load()
    noise_fill(px, 64, 64, (222, 212, 192), 6)
    for x in range(64):
        px[x, 31] = (186, 176, 160, 255)  # panel line
        px[x, 32] = (236, 228, 212, 255)
        px[x, 63] = (186, 176, 160, 255)
    for x in range(0, 64, 32):
        for y in range(64):
            px[x, y] = shade(px[x, y], -18)
    # Rain stains running down
    for _ in range(6):
        x = rng.randint(0, 63)
        for y in range(rng.randint(34, 50), 63):
            px[x, y] = shade(px[x, y], -22)
    img.save(OUT / "plaster.png")


def brick():
    img = Image.new("RGBA", (64, 64))
    px = img.load()
    mortar = (150, 140, 140, 255)
    for y in range(64):
        for x in range(64):
            px[x, y] = mortar
    for row in range(8):
        offset = 8 if row % 2 else 0
        for col in range(-1, 5):
            base = rng.choice([(150, 70, 56), (166, 82, 62), (138, 62, 52), (172, 96, 72)])
            x0 = col * 16 + offset
            for y in range(row * 8 + 1, row * 8 + 8):
                for x in range(x0 + 1, x0 + 16):
                    if 0 <= x < 64:
                        hi = 14 if y == row * 8 + 1 else 0
                        px[x, y] = shade(base + (255,), rng.randint(-8, 8) + hi)
    img.save(OUT / "brick.png")


def wood():
    img = Image.new("RGBA", (64, 64))
    px = img.load()
    for x in range(64):
        plank = x // 8
        base = [(120, 78, 52), (108, 70, 48), (128, 86, 58)][plank % 3]
        for y in range(64):
            c = shade(base + (255,), rng.randint(-5, 5))
            if x % 8 == 0:
                c = (64, 40, 30, 255)
            elif x % 8 == 1:
                c = shade(c, 14)
            elif (y + plank * 13) % 23 == 0:
                c = shade(c, -20)  # grain / knots
            px[x, y] = c
    img.save(OUT / "wood.png")


def roof():
    img = Image.new("RGBA", (64, 64))
    px = img.load()
    for y in range(64):
        for x in range(64):
            ridge = x % 8
            base = (110, 82, 70) if ridge < 4 else (86, 62, 56)
            c = shade(base + (255,), rng.randint(-6, 6) + (12 if ridge == 0 else 0))
            if rng.random() < 0.03:
                c = (150, 90, 50, 255)  # rust specks
            px[x, y] = c
    img.save(OUT / "roof.png")


def road():
    # 128x128 asphalt; alpha marks puddles (low alpha = more reflection shows)
    size = 128
    img = Image.new("RGBA", (size, size))
    px = img.load()
    puddles = [(rng.randint(0, size), rng.randint(0, size), rng.randint(10, 26), rng.randint(5, 10)) for _ in range(7)]
    for y in range(size):
        for x in range(size):
            c = shade((52, 54, 82), rng.randint(-7, 7))
            if rng.random() < 0.04:
                c = shade(c, 22)  # gravel
            wet = 0.0
            for cx, cy, rx, ry in puddles:
                for ox in (-size, 0, size):
                    for oy in (-size, 0, size):
                        d = ((x - cx - ox) / rx) ** 2 + ((y - cy - oy) / ry) ** 2
                        wet = max(wet, 1.0 - d)
            alpha = 255 if wet <= 0 else (90 if wet > 0.25 else 170)
            px[x, y] = c[:3] + (alpha,)
    img.save(OUT / "road.png")


def tiles():
    img = Image.new("RGBA", (64, 64))
    px = img.load()
    for y in range(64):
        for x in range(64):
            tile = (x // 16 + y // 16) % 2
            base = (150, 146, 160) if tile else (138, 134, 150)
            c = shade(base + (255,), rng.randint(-5, 5))
            if x % 16 == 0 or y % 16 == 0:
                c = (96, 92, 108, 255)
            elif x % 16 == 1 or y % 16 == 1:
                c = shade(c, 12)
            px[x, y] = c
    img.save(OUT / "tiles.png")


def leaves():
    img = Image.new("RGBA", (64, 64))
    px = img.load()
    palette = [(40, 84, 56), (56, 110, 64), (78, 134, 72), (104, 160, 84), (30, 64, 48)]
    for y in range(64):
        for x in range(64):
            px[x, y] = palette[0] + (255,)
    for _ in range(260):
        cx, cy = rng.randint(0, 63), rng.randint(0, 63)
        col = rng.choice(palette[1:]) + (255,)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0), (1, 1)):
            px[(cx + dx) % 64, (cy + dy) % 64] = col
    img.save(OUT / "leaves.png")


def awning():
    img = Image.new("RGBA", (64, 32))
    px = img.load()
    for y in range(32):
        for x in range(64):
            blue = (x // 8) % 2 == 0
            base = (58, 92, 170) if blue else (236, 236, 244)
            c = shade(base + (255,), -y * 1.2)
            if y >= 28:
                c = shade(c, -30)  # scalloped edge shadow
                if (x % 8) in (0, 7):
                    c = (0, 0, 0, 0)
            px[x, y] = c
    img.save(OUT / "awning.png")


def vending():
    img = Image.new("RGBA", (32, 48))
    px = img.load()
    for y in range(48):
        for x in range(32):
            px[x, y] = (230, 236, 246, 255)
    drinks = [(220, 60, 60), (60, 140, 220), (250, 200, 60), (90, 190, 110), (240, 140, 60), (200, 100, 200)]
    for row in range(4):
        for col in range(5):
            x0, y0 = 3 + col * 5, 4 + row * 8
            c = rng.choice(drinks) + (255,)
            for y in range(y0, y0 + 6):
                for x in range(x0, x0 + 3):
                    px[x, y] = c
            px[x0, y0] = (255, 255, 255, 255)
            for x in range(x0 - 1, x0 + 4):
                px[x, y0 + 6] = (120, 130, 150, 255)  # price strip
    for y in range(37, 46):
        for x in range(4, 28):
            px[x, y] = (40, 44, 60, 255)  # dispenser slot
    img.save(OUT / "vending.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    plaster(); brick(); wood(); roof(); road(); tiles(); leaves(); awning(); vending()
    print("textures written to", OUT)
