"""Draw the school building and the campus seen through the gate as pixel art, keeping the painting's trees.

Runs on the composed strip (tools/compose_school.py), before tools/draw_school_wall.py:
  - the painting's trees are kept: a tree mask from colour (greenish leaves, and dark saturated ones),
    smoothed; everything else behind the wall in the building's stretch is replaced
  - the building (half-size grid like the wall, 1 drawn pixel = 2x2 game pixels): a three-storey
    Thai school block with open corridors: slab edges with deep shadow under them, the classrooms'
    back wall with louvred windows and doors, corridor parapets with rain stains, columns in front,
    a breeze-block stair tower at one end, a metal roof, a drainpipe; misted by the rain
  - through the gate: the ground floor (a few windows lit warm), wet paving mirroring the building
    softly, a covered walkway on the left and a planter with shrubs on the right

Usage:
  python3 tools/draw_school_building.py IN.png OUT.png
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

K = 2
BUILDING = (540, 1172)                   # game x of the building (where the painting has building, mirrored)
GATE = (593, 774)                        # gate opening (compose_school.py)
WALL_TOP, WALL_BASE = 129, 255
FLOOR = 22                               # drawn rows per storey
FLOOR_TOP = 10                           # drawn row of the top storey's slab (roof above it)
GROUND = FLOOR_TOP + 3 * FLOOR           # drawn row where the building meets the ground (game 152)
COL_STEP, WIN_STEP = 28, 14

SKY = np.array((128, 144, 164))
ROOF = np.array((64, 76, 94))
ROOF_LOW = np.array((82, 94, 112))
ROOF_SEAM = np.array((54, 64, 80))
FASCIA = np.array((138, 146, 156))
SLAB = np.array((130, 140, 152))
SHADOW = np.array((48, 56, 72))
BACK = np.array((86, 96, 112))
FRAME = np.array((58, 66, 80))
GLASS = np.array((48, 60, 80))
SLAT = np.array((92, 104, 122))
WARM = np.array((188, 168, 118))
DOOR = np.array((60, 78, 84))
PLATE = np.array((150, 156, 160))
PARAPET = np.array((124, 132, 142))
PARAPET_TOP = np.array((150, 158, 166))
STAIN = np.array((84, 92, 104))
COLUMN = np.array((140, 148, 158))
COLUMN_LIT = np.array((156, 164, 172))
COLUMN_SHADE = np.array((98, 108, 122))
BREEZE = np.array((120, 128, 138))
BREEZE_HOLE = np.array((52, 60, 74))
PIPE = np.array((60, 68, 80))
PAVING = np.array((76, 90, 110))
JOINT = np.array((58, 68, 86))
CANOPY = np.array((62, 72, 88))
CANOPY_EDGE = np.array((122, 132, 146))
POST = np.array((104, 114, 128))
PLANTER = np.array((106, 114, 124))
SHRUB = np.array((44, 84, 66))
SHRUB_LIT = np.array((78, 124, 88))


def tree_mask(img):
    hsv = np.asarray(img.convert("HSV")).astype(float)
    h, s, v = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
    tree = ((h < 203) & (s > 0.25)) | ((v < 0.36) & (s > 0.45))
    m = Image.fromarray((tree * 255).astype(np.uint8))
    m = m.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    return np.asarray(m) > 127


def draw_building(w, h, rng):
    """Building on the drawing grid (rows from the top of the strip), NaN where nothing is drawn.
    A three-storey block with open corridors facing us (each storey: slab edge, deep shadow under it,
    the classrooms' back wall with louvred windows and doors, the corridor parapet, columns in front),
    a stair tower of breeze blocks at the right end, a metal roof, rain stains and a drainpipe."""
    out = np.full((h, w, 3), np.nan)
    x0, x1 = BUILDING[0] // K, BUILDING[1] // K
    tower = x1 - 30
    # roof: darker at the ridge, lighter toward the eave, seams; fascia and gutter shadow
    for y in range(0, FLOOR_TOP - 2):
        t = y / (FLOOR_TOP - 3)
        for x in range(x0 - 3, tower + 3):
            c = ROOF * (1 - t) + ROOF_LOW * t
            out[y, x] = ROOF_SEAM if x % 4 == 0 else c
    out[FLOOR_TOP - 2, x0 - 3:tower + 3] = FASCIA
    out[FLOOR_TOP - 1, x0 - 3:tower + 3] = SHADOW
    for f in range(3):
        top = FLOOR_TOP + f * FLOOR
        ground_floor = f == 2
        for y in range(top, top + FLOOR):
            out[y, x0:tower] = BACK
        out[top:top + 2, x0:tower] = SLAB
        for k, y in enumerate(range(top + 2, top + 6)):          # shadow under the slab, fading
            out[y, x0:tower] = SHADOW * (1 - k * 0.22) + BACK * k * 0.22
        # louvred windows, a door every few bays (with its room plate above)
        for i, wx in enumerate(range(x0 + 6, tower - 12, WIN_STEP)):
            if (wx - x0) % COL_STEP < 5:
                continue                                          # behind a column
            door = i % 5 == 2
            y0, y1 = top + 6, (top + FLOOR - 2 if ground_floor else top + 15) if door else top + 13
            out[y0 - 1:y1 + 1, wx - 1:wx + 9] = FRAME
            if door:
                out[y0:y1, wx:wx + 8] = DOOR
                out[y0 + 1:y0 + 4, wx + 2:wx + 6] = GLASS
                out[y0 - 3, wx + 1:wx + 7] = PLATE
                continue
            lit = ground_floor and rng.random() < 0.45
            for yy in range(y0, y1):
                c = (WARM * 0.85 if (yy - y0) % 2 else WARM) if lit else (SLAT if (yy - y0) % 2 else GLASS)
                out[yy, wx:wx + 8] = c
            out[y0:y1, wx + 3:wx + 5] = FRAME * 0.9 + (WARM * 0.1 if lit else 0)    # two leaves
        if not ground_floor:                                      # corridor parapet with rain stains
            out[top + 14, x0:tower] = PARAPET_TOP
            for x in range(x0, tower):
                stain = rng.integers(0, 5) if rng.random() < 0.35 else 0
                for y in range(top + 15, top + 21):
                    c = PARAPET + rng.normal(0, 2, 3)
                    if y - (top + 15) < stain:
                        c = c * 0.6 + STAIN * 0.4
                    out[y, x] = c
            out[top + 21, x0:tower] = SHADOW
        # columns in front, with a sliver of shadow cast to the right
        for cx in range(x0 + 1, tower - 2, COL_STEP):
            out[top:top + FLOOR, cx] = COLUMN_LIT
            out[top:top + FLOOR, cx + 1:cx + 3] = COLUMN
            out[top:top + FLOOR, cx + 3] = COLUMN_SHADE
            if not ground_floor:
                out[top + 15:top + 21, cx + 4] = SHADOW * 0.6 + PARAPET * 0.4
    # stair tower: breeze-block screen, a little forward and lighter, its own roof cap
    for y in range(FLOOR_TOP - 6, GROUND):
        for x in range(tower, x1):
            hole = (y % 4 in (1, 2)) and (x % 4 in (1, 2))
            out[y, x] = BREEZE_HOLE if hole and FLOOR_TOP - 3 < y < GROUND - 2 else BREEZE
        out[y, tower] = COLUMN_SHADE
    out[FLOOR_TOP - 7, tower - 1:x1 + 1] = FASCIA
    out[FLOOR_TOP - 6, tower - 1:x1 + 1] = SHADOW
    # drainpipe down one column
    px = x0 + 1 + COL_STEP * 4 + 4
    out[FLOOR_TOP - 2:GROUND, px] = PIPE
    # rain mist: the building stands behind the trees and the wall
    mask = ~np.isnan(out[..., 0])
    out[mask] = out[mask] * 0.74 + SKY * 0.26
    return out


def draw_campus(out, w, h, rng):
    """The courtyard through the gate: the building's plinth, wet paving coming toward the gate with a few
    joints (further apart nearer the gate), softly mirroring the building; a covered walkway on the left
    and a planter with shrubs on the right."""
    gx0, gx1 = GATE[0] // K, GATE[1] // K + 1
    bottom = WALL_BASE // K
    out[GROUND:GROUND + 2, gx0:gx1] = SLAB * 0.8 + SKY * 0.2           # plinth
    for y in range(GROUND + 2, bottom):
        t = (y - GROUND) / (bottom - GROUND)
        for x in range(gx0, gx1):
            c = PAVING * (0.92 + 0.12 * t) + rng.normal(0, 1.5, 3)
            ry = GROUND - 1 - int((y - GROUND) * 1.4)
            rx = x + int(round(np.sin(y * 1.9 + x * 0.1) * 1.5))       # rippled by the rain
            if ry >= 0 and 0 <= rx < w and not np.isnan(out[ry, rx, 0]):
                c = c * 0.8 + out[ry, rx] * 0.2 * (1 - 0.5 * t)
            out[y, x] = c
    for k in range(1, 5):
        y = GROUND + 2 + int((bottom - GROUND - 2) * (k / 5) ** 1.7)
        out[y, gx0:gx1] = out[y, gx0:gx1] * 0.7 + JOINT * 0.3
    for _ in range(6):                                                 # puddles catching the sky
        cy = rng.integers(GROUND + 6, bottom - 2)
        cx = rng.integers(gx0 + 6, gx1 - 6)
        rw = rng.integers(4, 10)
        for x in range(max(cx - rw, gx0), min(cx + rw, gx1)):
            f = 1 - abs(x - cx) / rw
            out[cy, x] = out[cy, x] * (1 - 0.3 * f) + SKY * 0.3 * f
    # covered walkway along the left: canopy with a light edge, thin posts
    cy = GROUND - 10
    out[cy:cy + 3, gx0:gx0 + 32] = CANOPY
    out[cy + 3, gx0:gx0 + 32] = CANOPY_EDGE
    for px in range(gx0 + 3, gx0 + 32, 10):
        out[cy + 4:GROUND + 6, px] = POST
    # planter with shrubs on the right, against the building
    out[GROUND:GROUND + 3, gx1 - 28:gx1 - 4] = PLANTER
    for x in range(gx1 - 28, gx1 - 4):
        hgt = 2 + int(abs(np.sin(x * 0.9)) * 3)
        for y in range(GROUND - hgt, GROUND):
            out[y, x] = SHRUB_LIT if y == GROUND - hgt else SHRUB


def main():
    rng = np.random.default_rng(11)
    img = Image.open(sys.argv[1]).convert("RGB")
    src = np.asarray(img).astype(float)
    H, W = src.shape[:2]
    w, h = W // K, H // K
    drawn = draw_building(w, h, rng)
    draw_campus(drawn, w, h, rng)
    big = np.repeat(np.repeat(drawn, K, 0), K, 1)
    trees = tree_mask(img)
    out = src.copy()
    have = ~np.isnan(big[..., 0])
    rows = np.arange(H)[:, None]
    cols = np.arange(W)[None, :]
    in_building = (cols >= BUILDING[0] - 4) & (cols < BUILDING[1] + 4) & (rows < WALL_TOP)
    in_gate = (cols >= GATE[0]) & (cols < GATE[1]) & (rows >= WALL_TOP - 20) & (rows < WALL_BASE)
    paint = have & ((in_building & ~trees) | in_gate)
    out[paint] = big[paint]
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(sys.argv[2])
    print(f"{W}x{H} -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
