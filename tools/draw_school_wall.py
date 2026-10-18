"""Draw the school wall, gate pillars, wet sidewalk, curb and road as pixel art over the walk strip.

The painting (tools/compose_school.py) keeps what is behind the wall: the trees, the school building
and the campus seen through the open gate. Everything in front is drawn here, on a half-size grid
(1 drawn pixel = 2x2 game pixels, about the painting's own pixel size), so it is sharp, even and
the same all along the walk:

  - wall: rain-darkened concrete panels with a lighter coping, dark rain streaks running down from
    the top, a damp darker band and moss at the foot; pillars where the painting has them (their
    caps stand above the wall, over the painting's own)
  - gate: two tall pillars with caps, open iron gate leaves folded against them, the name plate
    "โรงเรียน" (Sarabun) on the left pillar; between them the painting's campus stays visible
  - sidewalk: square paving with joints, soaked: it mirrors the wall, pillars and trees above it
    (rippled, darker), with a few puddles holding the sky's light
  - curb and road: a light curb edge, dark wet asphalt mirroring the scene more faintly, a lane line

Usage:
  python3 tools/draw_school_wall.py assets/bg/school/school_front.png assets/bg/school/school_front.png
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = "assets/fonts/Sarabun-Regular.ttf"
K = 2                                   # game pixels per drawn pixel
WALL_TOP, WALL_BASE = 129, 255          # game rows (painting's wall line; feet stand at 273)
CURB_TOP, ROAD_TOP = 318, 324
PILLARS = [21.5, 236, 511, 1047, 1261, 1536.6, 1750, 2026, 2240, 2515.5]   # game x (compose_school.py)
GATE = (568.5, 798.0)                   # gate pillar centres; opening between them
GATE_TOP = 104

WALL = np.array((88, 108, 133))
WALL_DARK = np.array((66, 84, 108))
COPING = np.array((132, 150, 168))
COPING_SHADE = np.array((58, 72, 92))
STREAK = np.array((56, 72, 94))
BASE = np.array((50, 64, 84))
MOSS = np.array((62, 104, 74))
MOSS_LIGHT = np.array((96, 140, 92))
MOSS_DARK = np.array((40, 70, 56))
ALGAE = np.array((46, 70, 62))
LICHEN = np.array((140, 160, 128))
PILLAR = np.array((104, 122, 146))
PILLAR_LIT = np.array((126, 144, 166))
PILLAR_SHADE = np.array((72, 88, 112))
TILE = np.array((66, 90, 122))
JOINT = np.array((44, 58, 82))
CURB = np.array((116, 134, 156))
CURB_FACE = np.array((44, 56, 76))
ROAD = np.array((40, 52, 72))
LANE = np.array((150, 162, 178))
IRON = np.array((30, 38, 52))
IRON_LIT = np.array((70, 82, 100))


def main():
    rng = np.random.default_rng(7)
    src = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(float)
    H, W = src.shape[:2]
    h, w = H // K, W // K
    paint = src.reshape(h, K, w, K, 3).mean((1, 3))          # the painting on the drawing grid
    out = paint.copy()
    top, base = WALL_TOP // K, WALL_BASE // K
    curb, road = CURB_TOP // K, ROAD_TOP // K
    g0, g1 = (int(round(c / K)) for c in GATE)
    open0, open1 = g0 + 13, g1 - 12                           # the opening between the gate pillars

    # wall panels: concrete, lighter where the rain runs off the coping, darker toward the damp foot.
    # Each bay between two pillars has its own tone (patched/repainted at different times); blotches at two
    # sizes, dark drip stains and a few long streaks hanging from the coping, green-black algae under the
    # coping and over the damp lower part, pale lime spots, moss creeping up from the foot.
    def smooth_noise(n, step):
        knots = rng.random(n // step + 3)
        return np.interp(np.arange(n) / step, np.arange(len(knots)), knots)

    def noise2d(cell):
        g = rng.random(((base - top) // cell + 2, w // cell + 2))
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((w + 2 * cell, base - top + 2 * cell), Image.BILINEAR)
        return np.asarray(im)[cell:cell + base - top, cell:cell + w] / 255.0

    rows = np.arange(top, base)
    n = base - top
    blot = noise2d(10) * 0.6 + noise2d(3) * 0.4
    algae = noise2d(7)
    edges = sorted([c / K for c in PILLARS] + [c / K for c in GATE])
    bay = np.searchsorted(edges, np.arange(w))
    tone = 0.86 + rng.random(len(edges) + 1) * 0.24
    tint = rng.normal(0, 3.5, (len(edges) + 1, 3))
    drip = smooth_noise(w, 4) * 0.6 + rng.random(w) * 0.4                    # stain length per column
    streak = rng.random(w) < 0.05                                            # long thin streaks
    for x in range(w):
        if open0 <= x < open1:
            continue
        length = int(drip[x] * n * 0.8)
        for i, y in enumerate(rows):
            f = i / n
            c = (WALL * (1.05 - 0.14 * f) + tint[bay[x]]) * tone[bay[x]] + rng.normal(0, 2.2, 3)
            c = c * (0.8 + 0.32 * blot[i, x])
            if i < length:
                k = 0.66 * (1 - i / max(length, 1)) ** 0.8 + 0.1
                c = c * (1 - k) + STREAK * 0.8 * k                           # drip stain
            if streak[x] and i < n - 6:
                c = c * 0.62 + STREAK * 0.7 * 0.38
            under = max(0.0, 1 - i / 7)                                      # wet band right under the coping
            low = max(0.0, (f - 0.4) / 0.6)                                  # lower part stays damp
            a = max(under * 0.8, low) * max(0.0, algae[i, x] - 0.35) * 1.6
            if a > 0:
                c = c * (1 - min(a, 0.7)) + ALGAE * min(a, 0.7)              # green-black algae
            if blot[i, x] > 0.86 and rng.random() < 0.25:
                c = c * 0.7 + LICHEN * 0.3                                   # pale lime specks
            if y >= base - 12:
                c = c * 0.55 + WALL_DARK * 0.45 * (0.85 + 0.2 * blot[i, x])
            out[y, x] = c
        out[top, x] = COPING + 6 + tint[bay[x]]
        out[top + 1, x] = COPING + tint[bay[x]]
        out[top + 2, x] = COPING_SHADE                        # shadow under the coping
        out[base - 1, x] = BASE
        if algae[0, x] > 0.72:                                # moss on the coping
            out[top - 1, x] = MOSS
            out[top, x] = MOSS_LIGHT

    def moss(cx, tall, wide):
        """A cushion of moss at the foot: low and wide with a ragged top (each column its own height),
        dark underneath, lighter where it catches the light, a few specks creeping up the damp wall."""
        heights = smooth_noise(2 * wide + 1, 2) * tall * 0.8 + rng.random(2 * wide + 1) * tall * 0.4
        for k, x in enumerate(range(cx - wide, cx + wide + 1)):
            if not 0 <= x < w or open0 - 1 <= x < open1 + 1:
                continue
            edge = 1 - (abs(x - cx) / (wide + 1)) ** 2
            hgt = max(2, int(heights[k] * edge + 1))
            for j in range(hgt):
                y = base - 1 - j
                shade = MOSS_DARK if j < hgt * 0.5 else MOSS
                if j == hgt - 1 and rng.random() < 0.7:
                    shade = MOSS_LIGHT
                out[y, x] = out[y, x] * 0.15 + (shade + rng.normal(0, 4, 3)) * 0.85
            for j in range(hgt, hgt + int(tall * 1.5)):              # specks creeping up
                if rng.random() < 0.18 * (1 - (j - hgt) / (tall * 1.5)):
                    y = base - 1 - j
                    out[y, x] = out[y, x] * 0.4 + MOSS * 0.6

    for _ in range(int(w * 0.05)):
        moss(rng.integers(0, w), rng.integers(4, 12), rng.integers(3, 10))

    def pillar(cx, half, y0, cap):
        x0, x1 = int(round(cx / K - half)), int(round(cx / K + half))
        tone_p = 0.92 + rng.random() * 0.12
        for x in range(max(x0, 0), min(x1, w)):
            stain = int(rng.random() * (base - y0) * 0.6)            # rain running down from the cap
            for y in range(y0, base):
                c = PILLAR * tone_p + rng.normal(0, 2.0, 3)
                if x == x0:
                    c = PILLAR_LIT * tone_p
                elif x >= x1 - 2:
                    c = PILLAR_SHADE
                if y - y0 < stain:
                    c = c * 0.75 + STREAK * 0.25
                if y >= base - 9:
                    c = c * 0.55 + ALGAE * 0.2 + WALL_DARK * 0.25
                out[y, x] = c
        for x in range(max(x0 - cap, 0), min(x1 + cap, w)):  # cap
            out[y0 - 2, x] = PILLAR_LIT + 8
            out[y0 - 1, x] = PILLAR_LIT
            out[y0, x] = COPING_SHADE
        return x0, x1

    for cx in PILLARS:
        pillar(cx, 6.5, top - 3, 1)
        if rng.random() < 0.6:
            moss(int(round(cx / K)) + rng.integers(-5, 6), rng.integers(5, 13), rng.integers(4, 9))
    lx = pillar(GATE[0], 13.5, GATE_TOP // K, 1)
    rx = pillar(GATE[1], 12.5, GATE_TOP // K, 1)

    # gate leaves folded open against the pillars (vertical bars, a rail top and bottom)
    for x0, x1 in [(lx[1], lx[1] + 7), (rx[0] - 7, rx[0])]:
        for x in range(x0, x1):
            for y in range(GATE_TOP // K + 10, base):
                if (x - x0) % 2 == 0 or y in (GATE_TOP // K + 10, GATE_TOP // K + 11, base - 3):
                    out[y, x] = IRON_LIT if x == x0 else IRON

    # sidewalk: paving with joints, mirroring what stands above it (the wall's foot is the mirror line)
    for y in range(base, curb):
        depth = (y - base) / max(curb - base, 1)
        for x in range(w):
            c = TILE + rng.normal(0, 1.5, 3)
            ry = base - 1 - int((y - base) * 1.6) - 1
            rx_ = x + int(round(np.sin(y * 1.7 + x * 0.05) * 1.2))   # ripples
            if 0 <= ry < h and 0 <= rx_ < w:
                refl = out[ry, rx_]
                c = c * 0.58 + refl * 0.42 * (0.95 - depth * 0.25)
            out[y, x] = c
        if (y - base) % 7 == 6:                               # joints across
            out[y, :] = out[y, :] * 0.6 + JOINT * 0.4
    for x in range(0, w, 19):                                 # joints along, leaning out toward the curb
        for y in range(base, curb):
            xx = x + (y - base) // 4
            if xx < w:
                out[y, xx] = out[y, xx] * 0.55 + JOINT * 0.45
    for _ in range(40):                                       # puddles: thin bright bands of the sky's light
        cx, cy = rng.integers(0, w), rng.integers(base + 3, curb - 2)
        rw = rng.integers(8, 26)
        for x in range(cx - rw, cx + rw):
            if 0 <= x < w:
                f = (1 - abs(x - cx) / rw) ** 0.7
                for dy, a in ((0, 0.42), (1, 0.18)):
                    out[cy + dy, x] = out[cy + dy, x] * (1 - a * f) + np.array((150, 172, 198)) * a * f
    # curb
    out[curb] = CURB + 10
    out[curb + 1] = CURB
    out[curb + 2:road] = CURB_FACE
    # road: dark asphalt, a faint long mirror of the scene, a dashed lane line
    for y in range(road, h):
        for x in range(w):
            c = ROAD + rng.normal(0, 1.2, 3)
            ry = curb - (y - road) * 3
            if 0 <= ry < h:
                c = c * 0.78 + out[ry, x] * 0.22
            out[y, x] = c
    lane = h - 3
    for x in range(w):
        if (x // 14) % 2 == 0:
            out[lane, x] = out[lane, x] * 0.4 + LANE * 0.6

    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).resize((w * K, h * K), Image.NEAREST)
    big = np.asarray(img).copy()
    # name plate on the left gate pillar, drawn at full game resolution so the letters read
    plate = Image.new("RGB", (40, 14), (38, 46, 60))
    d = ImageDraw.Draw(plate)
    d.rectangle([0, 0, 39, 13], outline=(150, 160, 176))
    d.text((20, 7), "โรงเรียน", font=ImageFont.truetype(FONT, 10), fill=(210, 218, 228), anchor="mm")
    px, py = int(GATE[0] - 20), 150
    big[py:py + 14, px:px + 40] = np.asarray(plate)
    Image.fromarray(big).save(sys.argv[2])
    print(f"{W}x{H} -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
