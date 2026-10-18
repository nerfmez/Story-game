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
MOSS_LIGHT = np.array((92, 136, 92))
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

    # wall panels: concrete, lighter where the rain runs off the coping, darker toward the damp foot,
    # blotchy (low-frequency noise), dark drip stains hanging from the coping, moss and weeds at the foot
    def smooth_noise(n, step):
        knots = rng.random(n // step + 3)
        return np.interp(np.arange(n) / step, np.arange(len(knots)), knots)
    rows = np.arange(top, base)
    blot = np.repeat(smooth_noise(w, 9)[None, :], len(rows), 0) * 0.5 + \
        np.repeat(smooth_noise(len(rows), 7)[:, None], w, 1) * 0.5
    drip = smooth_noise(w, 4) * 0.6 + rng.random(w) * 0.4                    # stain length per column
    for x in range(w):
        if open0 <= x < open1:
            continue
        length = int(drip[x] * (base - top) * 0.75)
        for i, y in enumerate(rows):
            f = i / (base - top)
            c = WALL * (1.04 - 0.12 * f) + rng.normal(0, 2.0, 3)
            c = c * (0.86 + 0.18 * blot[i, x])
            if i < length:
                k = 0.62 * (1 - i / max(length, 1)) ** 0.8 + 0.1
                c = c * (1 - k) + STREAK * 0.82 * k                          # drip stain
            if y >= base - 12:
                c = c * 0.5 + WALL_DARK * 0.5 * (0.9 + 0.1 * blot[i, x])
            out[y, x] = c
        out[top, x] = COPING + 6
        out[top + 1, x] = COPING
        out[top + 2, x] = COPING_SHADE                        # shadow under the coping
        out[base - 1, x] = BASE
    for _ in range(int(w * 0.06)):                            # moss and weed clumps at the foot
        cx = rng.integers(0, w)
        if open0 - 2 <= cx < open1 + 2:
            continue
        tall = rng.integers(2, 9)
        for x in range(cx - 2, cx + 3):
            if 0 <= x < w:
                for y in range(base - max(1, tall - abs(x - cx) * 2), base):
                    out[y, x] = MOSS_LIGHT if rng.random() < 0.4 else MOSS

    def pillar(cx, half, y0, cap):
        x0, x1 = int(round(cx / K - half)), int(round(cx / K + half))
        for x in range(max(x0, 0), min(x1, w)):
            for y in range(y0, base):
                c = PILLAR + rng.normal(0, 2.0, 3)
                if x == x0:
                    c = PILLAR_LIT
                elif x >= x1 - 2:
                    c = PILLAR_SHADE
                if y >= base - 9:
                    c = c * 0.6 + WALL_DARK * 0.4
                out[y, x] = c
        for x in range(max(x0 - cap, 0), min(x1 + cap, w)):  # cap
            out[y0 - 2, x] = PILLAR_LIT + 8
            out[y0 - 1, x] = PILLAR_LIT
            out[y0, x] = COPING_SHADE
        return x0, x1

    for cx in PILLARS:
        pillar(cx, 6.5, top - 3, 1)
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
