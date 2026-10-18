"""Draw the school building and the courtyard seen through the gate as pixel art, keeping the painting's trees.

Runs on the trees-only strip (tools/compose_school.py on the author's art_source/school_trees_rain.png),
before tools/draw_school_wall.py. Everything behind the author's trees is drawn here: a rain sky with a
faint far treeline, and on a half-size grid (1 drawn pixel = 2x2 game pixels, like the wall):

  - a Thai school block, three storeys of open corridors, each storey 60 game px (in scale with the
    characters in front): cream walls, a band of the school colour along every parapet, a hipped roof
    of orange-red tiles darkened by the rain, white fascia
  - each bay between two columns: the classroom wall in the corridor's shade with a window pair under a
    louvred transom (glass catching the sky in a slant), now and then a door with its room plate; the
    soffit casts a deep shadow along the top of the corridor
  - the middle block stands forward: a breeze-block screen in a diamond pattern over the stairs and a
    raised parapet with the plate "อาคาร 1" and the school emblem
  - rain: the whole building misted toward the sky, more at the top; drips under the parapets
  - through the gate: the ground floor (a few classrooms lit warm), steps, wet paving that softly
    mirrors the building, puddles, a planter, and the flagpole with the Thai flag hanging wet

Usage:
  python3 tools/draw_school_building.py trees.png OUT.png
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = "assets/fonts/Sarabun-Regular.ttf"
K = 2
BUILDING = (540, 1172)                   # game x of the building (where the painting has building, mirrored)
GATE = (593, 774)                        # gate opening (compose_school.py)
WALL_TOP, WALL_BASE = 129, 255
ROOF_H = 10                              # drawn rows of roof
FLOOR = 30                               # drawn rows per storey (60 game px)
GROUND = ROOF_H + 3 * FLOOR              # drawn row of the courtyard at the building's foot (game 200)
BAY = 26                                 # drawn px between column centres
CENTRE = (800, 880)                      # game x of the middle block (forward, stairs, sign)
SIGN_TOP = 4                             # drawn row of the middle block's raised parapet
FLAG_X = 732                             # game x of the flagpole (seen through the gate and over the wall)

SKY = np.array((132, 148, 170))
SKY_TOP = np.array((112, 130, 156))
SKY_LOW = np.array((150, 164, 184))
FAR_TREES = np.array((70, 94, 108))
TILE = np.array((146, 84, 70))
TILE_DARK = np.array((112, 62, 56))
TILE_LIT = np.array((170, 108, 88))
FASCIA = np.array((196, 196, 188))
CREAM = np.array((182, 172, 150))
CREAM_LIT = np.array((202, 194, 172))
CREAM_SHADE = np.array((124, 118, 108))
CORRIDOR = np.array((112, 108, 102))     # classroom wall in the corridor's shade
SOFFIT = np.array((62, 62, 66))
SCHOOL = np.array((58, 88, 132))         # band of the school colour
SCHOOL_LIT = np.array((82, 112, 152))
FRAME = np.array((70, 66, 62))
GLASS = np.array((52, 64, 84))
GLASS_SKY = np.array((118, 138, 162))
LOUVRE = np.array((96, 92, 86))
WARM = np.array((214, 186, 124))
WARM_DIM = np.array((176, 150, 104))
DOOR = np.array((64, 86, 96))
PLATE = np.array((210, 210, 202))
COLUMN = np.array((196, 188, 166))
COLUMN_LIT = np.array((214, 206, 186))
COLUMN_SHADE = np.array((142, 136, 122))
DRIP = np.array((140, 136, 128))
BREEZE = np.array((196, 188, 168))
BREEZE_HOLE = np.array((70, 70, 74))
PAVING = np.array((80, 92, 110))
JOINT = np.array((60, 70, 86))
STEP = np.array((150, 150, 148))
POLE = np.array((200, 204, 208))
FLAG = [np.array((168, 54, 60)), np.array((220, 220, 222)), np.array((44, 56, 116))]   # red, white, blue
FLAG_ROWS = [0, 0, 1, 1, 2, 2, 2, 2, 1, 1, 0, 0]                                     # stripes 1:1:2:1:1
PLANTER = np.array((150, 140, 124))
SHRUB = np.array((46, 86, 66))
SHRUB_LIT = np.array((82, 128, 90))
INK = (72, 92, 128)                      # sign letters and emblem ring
GOLD = (150, 120, 72)


def roof(out, x0, x1, top, rows):
    """Hipped roof of clay tiles: courses every 2 rows, tiles staggered, darker toward the ridge, the
    roof narrowing toward the ridge at the hips; a white fascia and the gutter's shadow."""
    for i, y in enumerate(range(top, top + rows - 2)):
        inset = (rows - 2 - i) // 2
        t = i / (rows - 3)
        for x in range(x0 - 3 + inset, x1 + 3 - inset):
            c = TILE_DARK * (1 - t) + TILE * t
            if i % 2 == 1:
                c = c * 0.86                                  # course line
            elif (x + (i // 2) * 2) % 4 == 0:
                c = c * 0.9                                   # tile joints, staggered
            elif (x + i) % 9 == 0:
                c = TILE_LIT * 0.6 + c * 0.4                  # wet sheen
            out[y, x] = c
    out[top + rows - 2, x0 - 3:x1 + 3] = FASCIA
    out[top + rows - 1, x0 - 3:x1 + 3] = SOFFIT


def window(out, x, y, lit):
    """Window pair under a louvred transom: dark frame, glass with a slant of sky (or warm light)."""
    out[y - 1:y + 12, x - 1:x + 15] = FRAME
    for k in range(3):
        out[y + k, x:x + 14] = LOUVRE if k % 2 == 0 else FRAME
    for yy in range(y + 4, y + 11):
        for xx in range(x, x + 14):
            if xx in (x + 6, x + 7):
                continue                                       # mullion between the two leaves
            if lit:
                c = WARM if (xx + yy) % 5 else WARM_DIM
            else:
                d = (xx - x) - (yy - y - 4)
                c = GLASS_SKY * 0.7 + GLASS * 0.3 if d in (2, 3, 9) else GLASS
            out[yy, xx] = c


def storey(out, x0, x1, top, ground_floor, rng, columns):
    out[top:top + FLOOR, x0:x1] = CORRIDOR
    out[top:top + 2, x0:x1] = CREAM_LIT                        # slab edge
    for k, y in enumerate(range(top + 2, top + 6)):            # soffit shadow fading down the wall
        out[y, x0:x1] = SOFFIT * (1 - k * 0.24) + CORRIDOR * k * 0.24
    door_bottom = top + FLOOR - 1 if ground_floor else top + 19
    for i, bx in enumerate(range(x0, x1 - BAY + 1, BAY)):
        lit = ground_floor and rng.random() < 0.5
        if i % 4 == 2:                                         # a door with its room plate
            dx = bx + 9
            out[top + 7, dx + 1:dx + 8] = PLATE
            out[top + 9:door_bottom, dx - 1:dx + 10] = FRAME
            out[top + 10:door_bottom, dx:dx + 9] = DOOR
            out[top + 11:top + 15, dx + 2:dx + 7] = WARM_DIM if lit else GLASS
        else:
            window(out, bx + 6, top + 8, lit)
    if not ground_floor:                                       # parapet: cream, a band of the school colour
        out[top + 19, x0:x1] = CREAM_LIT
        out[top + 20:top + 29, x0:x1] = CREAM
        out[top + 22, x0:x1] = SCHOOL_LIT
        out[top + 23:top + 25, x0:x1] = SCHOOL
        for x in range(x0, x1):                                # drips under the band
            if rng.random() < 0.3:
                out[top + 25:top + 25 + rng.integers(1, 4), x] = DRIP
        out[top + 29, x0:x1] = SOFFIT
    else:
        out[top + FLOOR - 2:top + FLOOR, x0:x1] = CREAM_SHADE  # plinth under the classrooms
    for cx in columns:                                         # columns in front, a sliver of shadow to the right
        out[top:top + FLOOR, cx - 2] = COLUMN_LIT
        out[top:top + FLOOR, cx - 1:cx + 1] = COLUMN
        out[top:top + FLOOR, cx + 1] = COLUMN_SHADE
        if not ground_floor:
            out[top + 20:top + 29, cx + 2] = CREAM_SHADE


def centre_block(out, c0, c1):
    """The middle block, forward of the wings: breeze-block screen over the stairs (diamonds), a raised
    parapet for the sign, its own fascia."""
    for y in range(SIGN_TOP, GROUND):
        for x in range(c0, c1):
            u, v = (x - c0) % 6, (y - SIGN_TOP) % 6
            hole = abs(u - 3) + abs(v - 3) <= 1 and ROOF_H + 4 < y < GROUND - 4
            out[y, x] = BREEZE_HOLE if hole else BREEZE
    out[SIGN_TOP:GROUND, c0] = COLUMN_LIT
    out[SIGN_TOP:GROUND, c1 - 1] = COLUMN_SHADE
    out[SIGN_TOP:SIGN_TOP + 9, c0:c1] = CREAM_LIT
    out[SIGN_TOP + 9, c0:c1] = SCHOOL
    out[SIGN_TOP + 10, c0:c1] = SOFFIT
    out[SIGN_TOP - 1, c0 - 1:c1 + 1] = FASCIA


def draw_building(w, h, rng):
    out = np.full((h, w, 3), np.nan)
    x0, x1 = BUILDING[0] // K, BUILDING[1] // K
    roof(out, x0, x1, 0, ROOF_H)
    columns = list(range(x0 + 2, x1, BAY))
    for f in range(3):
        storey(out, x0, x1, ROOF_H + f * FLOOR, f == 2, rng, columns)
    centre_block(out, CENTRE[0] // K, CENTRE[1] // K)
    # rain mist toward the sky, more at the top
    mask = ~np.isnan(out[..., 0])
    for y in range(h):
        k = 0.34 - 0.14 * min(y / GROUND, 1.0)
        out[y, mask[y]] = out[y, mask[y]] * (1 - k) + SKY * k
    return out


def draw_campus(out, w, h, rng):
    """Courtyard through the gate: steps up to the ground floor, wet paving softly mirroring the
    building, puddles, a planter, the flagpole with the flag hanging wet."""
    gx0, gx1 = GATE[0] // K, GATE[1] // K + 1
    bottom = WALL_BASE // K
    out[GROUND, gx0:gx1] = STEP
    out[GROUND + 1, gx0:gx1] = STEP * 0.8
    out[GROUND + 2, gx0:gx1] = JOINT
    for y in range(GROUND + 3, bottom):
        t = (y - GROUND) / (bottom - GROUND)
        for x in range(gx0, gx1):
            c = PAVING * (0.9 + 0.14 * t) + rng.normal(0, 1.5, 3)
            ry = GROUND - 1 - int((y - GROUND) * 1.4)
            rx = x + int(round(np.sin(y * 1.9 + x * 0.1) * 1.5))
            if ry >= 0 and 0 <= rx < w and not np.isnan(out[ry, rx, 0]):
                c = c * 0.78 + out[ry, rx] * 0.22 * (1 - 0.5 * t)
            out[y, x] = c
    for k in range(1, 4):
        y = GROUND + 3 + int((bottom - GROUND - 3) * (k / 4) ** 1.6)
        out[y, gx0:gx1] = out[y, gx0:gx1] * 0.72 + JOINT * 0.28
    for _ in range(5):
        cy = rng.integers(GROUND + 6, bottom - 2)
        cx = rng.integers(gx0 + 6, gx1 - 6)
        rw = rng.integers(4, 10)
        for x in range(max(cx - rw, gx0), min(cx + rw, gx1)):
            f = 1 - abs(x - cx) / rw
            out[cy, x] = out[cy, x] * (1 - 0.32 * f) + SKY * 0.32 * f
    # planter with shrubs against the building, at the left of the gate
    out[GROUND - 3:GROUND, gx0 + 4:gx0 + 30] = PLANTER
    for x in range(gx0 + 4, gx0 + 30):
        hgt = 2 + int(abs(np.sin(x * 0.8)) * 3)
        for y in range(GROUND - 3 - hgt, GROUND - 3):
            out[y, x] = SHRUB_LIT if y == GROUND - 3 - hgt else SHRUB
    # flagpole: base, pole up past the wall's top, the flag hanging wet in folds
    fx = FLAG_X // K
    out[GROUND + 8:GROUND + 11, fx - 2:fx + 3] = STEP
    out[14:GROUND + 8, fx] = POLE
    out[13, fx] = FASCIA
    for k, stripe in enumerate(FLAG_ROWS):
        for j in range(1, 9):
            out[16 + k, fx + j] = FLAG[stripe] * (0.8 if j % 3 == 0 else 1.0)


def sky(H, W, rng):
    """Rain sky behind everything: brighter and mistier toward the horizon, a faint far treeline."""
    rows = np.arange(H)[:, None, None] / WALL_TOP
    out = SKY_TOP * (1 - np.clip(rows, 0, 1)) + SKY_LOW * np.clip(rows, 0, 1)
    out = np.repeat(out, W, 1)
    knots = rng.random(W // 40 + 3)
    ridge = WALL_TOP - 30 - np.interp(np.arange(W) / 40, np.arange(len(knots)), knots) * 26
    for x in range(W):
        top = int(ridge[x] + rng.integers(0, 3))
        out[top:WALL_TOP, x] = out[top:WALL_TOP, x] * 0.7 + FAR_TREES * 0.3
    return out


def main():
    """IN is the trees-only strip (compose_school.py on art_source/school_trees_rain.png, RGBA)."""
    rng = np.random.default_rng(11)
    trees = np.asarray(Image.open(sys.argv[1]).convert("RGBA")).astype(float)
    H, W = trees.shape[:2]
    w, h = W // K, H // K
    drawn = draw_building(w, h, rng)
    draw_campus(drawn, w, h, rng)
    big = np.repeat(np.repeat(drawn, K, 0), K, 1)
    out = sky(H, W, rng)
    have = ~np.isnan(big[..., 0])
    rows = np.arange(H)[:, None]
    cols = np.arange(W)[None, :]
    in_gate = (cols >= GATE[0]) & (cols < GATE[1]) & (rows < WALL_BASE)
    paint = have & ((rows < WALL_TOP) | in_gate)
    out[paint] = big[paint]
    # sign and emblem on the middle block's parapet, at full resolution so the letters read
    sign = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(sign)
    cx, cy = (CENTRE[0] + CENTRE[1]) // 2, SIGN_TOP * K + 9
    d.text((cx + 7, cy), "อาคาร 1", font=ImageFont.truetype(FONT, 11), fill=INK, anchor="mm")
    d.ellipse([cx - 30, cy - 6, cx - 18, cy + 6], outline=INK, width=2)
    d.ellipse([cx - 27, cy - 3, cx - 21, cy + 3], fill=GOLD)
    out = np.asarray(sign).astype(float)
    # the author's trees in front of the sky and the building (the wall is drawn over their feet later)
    a = trees[..., 3:4] / 255.0
    out = out * (1 - a) + trees[..., :3] * a
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(sys.argv[2])
    print(f"{W}x{H} -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
