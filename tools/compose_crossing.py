"""The zebra crossing and its signal pole for the rainy morning (the prologue's crossing).

  crosswalk.png   the street under the crossing, copied from assets/bg/rain/road.png at
                  the crossing's world x (the road layer repeats every 720px from x = 0),
                  with the lane dashes taken out and white bars painted across it. The bars
                  run along the street (like real zebra stripes, which you step across) and
                  get taller and wider towards the camera (we look down at the street);
                  the paint is a little worn, and the puddles' see-through stays, so the
                  wet street still mirrors what is above it
  signal_pole.png the pole at the kerb: a car signal head on top, the pedestrian signal
                  box below it (red standing man / green walking man, unlit), a push button
  lamp_*.png      the lit lamps, each the size of the pole sprite (laid over it):
                  car_red / car_yellow / car_green, ped_red, ped_green_a / ped_green_b
                  (the walking man's two steps)
  glow.png        a soft round glow for the lamps (drawn additive, tinted in the game)
  streak.png      a lamp's long reflection in the wet street (additive)

Colours are the rain scene's: the overcast greys of the utility pole in the foreground.
Usage: python3 tools/compose_crossing.py   (writes assets/bg/rain/crosswalk.png, assets/props/)
"""
import numpy as np
from PIL import Image, ImageDraw

import compose_sunset_scene as sunset

ROOT = sunset.ROOT
PROPS = ROOT / "assets" / "props"
ROAD = ROOT / "assets" / "bg" / "rain" / "road.png"

# where the crossing is: the two characters wait at its top, centred on CENTER_X
CENTER_X = -158
TOP_W = 112                       # width at the kerb
HORIZON = 150                     # eye level: the street widens away from it
STREET_TOP = sunset.STREET_TOP    # 286
DASH_Y = STREET_TOP + 8           # the lane dashes (taken out under the crossing)
BARS = [(289, 293), (298, 304), (310, 318), (325, 335), (343, 356)]
PAINT = np.array((132, 138, 148.0))
# pole palette (from the foreground utility pole in the rain)
OUTLINE, DARK, MID, LIGHT, SHINE = (15, 19, 26), (47, 53, 62), (60, 67, 77), (83, 90, 100), (128, 134, 142)
POLE_X = CENTER_X - TOP_W // 2 - 8     # world x of the pole's centre
POLE_BASE = 283                        # foot of the pole: on the sidewalk at the kerb
POLE_TOP = 84


def half_width(y):
    return TOP_W / 2 * (y - HORIZON) / (STREET_TOP - HORIZON)


def crosswalk():
    road = np.asarray(Image.open(ROAD).convert("RGBA")).astype(float)
    x0 = int(np.floor(CENTER_X - half_width(359))) - 2
    x1 = int(np.ceil(CENTER_X + half_width(359))) + 2
    w, h = x1 - x0, 360 - STREET_TOP
    out = np.zeros((h, w, 4))
    rng = np.random.default_rng(5)
    for j in range(h):
        y = STREET_TOP + j
        src = DASH_Y + 2 if abs(y - DASH_Y) <= 0 else y          # no lane dash on the crossing
        for i in range(w):
            out[j, i] = road[src, (x0 + i) % road.shape[1]]
        hw = half_width(y)
        bar = next((b for b in BARS if b[0] <= y <= b[1]), None)
        if bar is None:
            continue
        near = (y - STREET_TOP) / (360 - STREET_TOP)
        paint = PAINT * (1.0 + 0.08 * near)                    # nearer: a little more sheen
        for i in range(w):
            dx = x0 + i - CENTER_X
            if abs(dx) > hw:
                continue
            a = 0.85
            if rng.random() < 0.10:                            # worn paint: asphalt shows
                a = 0.35
            if y in bar and (y == bar[0] or y == bar[1]):
                a *= 0.8                                       # soft bar edges
            if abs(abs(dx) - hw) < 1.0:
                a *= 0.6
            out[j, i, :3] = out[j, i, :3] * (1 - a) + paint * a
            out[j, i, 3] = max(out[j, i, 3], 255 * (0.6 + 0.4 * a))
    return Image.fromarray(np.clip(out, 0, 255).round().astype(np.uint8), "RGBA"), x0


# --- the pole -------------------------------------------------------------------------
W, H = 30, POLE_BASE - POLE_TOP + 1
PX = 15                                # pole's left column inside the sprite (3px wide)
CAR = (PX + 4, 0)                      # car signal head: left/top
PED = (PX - 14, 52)                    # pedestrian box
LAMP_CAR = [(CAR[0] + 2, CAR[1] + 3 + k * 9) for k in range(3)]   # red, yellow, green (5x5)
LAMP_PED = [(PED[0] + 2, PED[1] + 3), (PED[0] + 2, PED[1] + 15)]   # red man, green man (9x10)

MAN_STAND = ["...##....", "...##....", "..####...", ".######..", ".#.##.#..", "...##....", "...##....",
             "..#..#...", "..#..#...", "..#..#..."]
MAN_WALK_A = ["....##...", "....##...", "...###...", "..####...", ".#.##.#..", "...##....", "...###...",
              "..#...#..", ".#....#..", ".#.....#."]
MAN_WALK_B = ["....##...", "....##...", "...###...", "..#####..", "...##..#.", "...##....", "...##....",
              "...#.#...", "...#.#...", "..#..#..."]


def draw_man(d, x, y, shape, colour):
    for r, row in enumerate(shape):
        for c, ch in enumerate(row):
            if ch == "#":
                d.point((x + c, y + r), fill=colour)


def pole():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # the pole: 3px, lit a little from the left (the sky), outlined
    d.rectangle((PX - 1, 6, PX + 3, H - 1), fill=OUTLINE + (255,))
    d.rectangle((PX, 6, PX + 2, H - 2), fill=MID + (255,))
    d.line([(PX, 6), (PX, H - 2)], fill=LIGHT + (255,))
    d.line([(PX + 2, 6), (PX + 2, H - 2)], fill=DARK + (255,))
    d.rectangle((PX - 2, H - 4, PX + 4, H - 1), fill=OUTLINE + (255,))                   # base plate
    d.rectangle((PX - 1, H - 3, PX + 3, H - 2), fill=DARK + (255,))
    d.rectangle((PX - 1, 2, PX + 3, 6), fill=OUTLINE + (255,))                           # cap
    # car signal head: housing with three lamps and little visors
    cx, cy = CAR
    d.rectangle((cx, cy, cx + 8, cy + 28), fill=OUTLINE + (255,))
    d.rectangle((cx + 1, cy + 1, cx + 7, cy + 27), fill=(32, 36, 44, 255))
    for (lx, ly), dim in zip(LAMP_CAR, [(70, 34, 38), (72, 62, 36), (34, 62, 52)]):
        d.ellipse((lx, ly, lx + 4, ly + 4), fill=dim + (255,))
        d.line([(lx - 1, ly - 1), (lx + 5, ly - 1)], fill=OUTLINE + (255,))           # visor
    d.rectangle((PX + 3, cy + 10, cx, cy + 12), fill=DARK + (255,))                    # bracket
    # pedestrian box: two windows with the figures (unlit: dark glass, faint figures)
    bx, by = PED
    d.rectangle((bx, by, bx + 12, by + 26), fill=OUTLINE + (255,))
    d.rectangle((bx + 1, by + 1, bx + 11, by + 25), fill=(40, 44, 54, 255))
    for (lx, ly) in LAMP_PED:
        d.rectangle((lx, ly, lx + 8, ly + 9), fill=(22, 24, 30, 255))
    draw_man(d, LAMP_PED[0][0], LAMP_PED[0][1], MAN_STAND, (64, 34, 38, 255))
    draw_man(d, LAMP_PED[1][0], LAMP_PED[1][1], MAN_WALK_A, (30, 56, 46, 255))
    d.line([(bx + 1, by + 1), (bx + 11, by + 1)], fill=LIGHT + (255,))                 # wet top edge
    d.rectangle((bx + 12, by + 6, PX - 1, by + 8), fill=DARK + (255,))                 # bracket
    # push button box at hand height
    py = H - 1 - 62
    d.rectangle((PX + 3, py, PX + 8, py + 9), fill=OUTLINE + (255,))
    d.rectangle((PX + 4, py + 1, PX + 7, py + 8), fill=(150, 140, 60, 255))
    d.rectangle((PX + 5, py + 3, PX + 6, py + 5), fill=OUTLINE + (255,))
    return img


def lamp(kind):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    car = {"car_red": (0, (255, 84, 70), (255, 190, 170)), "car_yellow": (1, (255, 196, 70), (255, 236, 180)),
           "car_green": (2, (70, 235, 170), (190, 255, 225))}
    if kind in car:
        k, col, core = car[kind]
        lx, ly = LAMP_CAR[k]
        d.ellipse((lx, ly, lx + 4, ly + 4), fill=col + (255,))
        d.point((lx + 1, ly + 1), fill=core + (255,))
        d.point((lx + 2, ly + 1), fill=core + (255,))
        return img
    if kind == "ped_red":
        lx, ly = LAMP_PED[0]
        d.rectangle((lx, ly, lx + 8, ly + 9), fill=(52, 18, 20, 255))
        draw_man(d, lx, ly, MAN_STAND, (255, 80, 64, 255))
    else:
        lx, ly = LAMP_PED[1]
        d.rectangle((lx, ly, lx + 8, ly + 9), fill=(14, 44, 34, 255))
        draw_man(d, lx, ly, MAN_WALK_A if kind == "ped_green_a" else MAN_WALK_B, (90, 255, 170, 255))
    return img


def glow(size=48):
    y, x = np.mgrid[0:size, 0:size] - (size - 1) / 2
    r = np.sqrt(x * x + y * y) / (size / 2)
    a = np.clip(1 - r, 0, 1) ** 2.2
    out = np.zeros((size, size, 4))
    out[..., :3] = 255
    out[..., 3] = a * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def streak(w=10, h=64):
    """A lamp's reflection on wet asphalt: a soft vertical smear, broken up by the ripples."""
    rng = np.random.default_rng(3)
    y, x = np.mgrid[0:h, 0:w]
    across = np.exp(-((x - (w - 1) / 2) / (w / 4)) ** 2)
    down = np.clip(1 - y / h, 0, 1) ** 1.3
    ripple = 0.65 + 0.35 * (rng.random((h, 1)) > 0.35)
    out = np.zeros((h, w, 4))
    out[..., :3] = 255
    out[..., 3] = np.clip(across * down * ripple, 0, 1) * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main():
    PROPS.mkdir(parents=True, exist_ok=True)
    cw, x0 = crosswalk()
    cw.save(ROOT / "assets" / "bg" / "rain" / "crosswalk.png")
    pole().save(PROPS / "signal_pole.png")
    for kind in ["car_red", "car_yellow", "car_green", "ped_red", "ped_green_a", "ped_green_b"]:
        lamp(kind).save(PROPS / f"lamp_{kind}.png")
    glow().save(PROPS / "glow.png")
    streak().save(PROPS / "streak.png")
    print(f"crosswalk at x={x0}, y={STREET_TOP} ({cw.size[0]}x{cw.size[1]}); "
          f"pole sprite at x={POLE_X - PX - 1}, y={POLE_TOP} ({W}x{H}); "
          f"lamps: car {LAMP_CAR}, ped {LAMP_PED}")


if __name__ == "__main__":
    main()
