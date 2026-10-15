"""Generate placeholder pixel-art character sprites (32x72, front view).

Students in Thai school uniform: white shirt, navy skirt/shorts, white socks,
black shoes, backpack straps, plus a small prop each. A dark outline is added
around every sprite automatically.

Usage: python3 tools/make_characters.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "characters"

W, H = 32, 72
OUTLINE = (34, 28, 48, 255)
SKIN = (246, 205, 170, 255)
SKIN_SHADE = (222, 170, 140, 255)
SHIRT = (246, 246, 252, 255)
SHIRT_SHADE = (200, 200, 222, 255)
NAVY = (40, 50, 98, 255)
NAVY_SHADE = (28, 34, 70, 255)
SOCK = (240, 240, 245, 255)
SHOE = (26, 24, 32, 255)
SHOE_HI = (90, 90, 110, 255)
STRAP = (36, 36, 44, 255)
EYE = (30, 24, 36, 255)
BLUSH = (240, 160, 150, 255)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.px = self.img.load()

    def rect(self, x0, y0, x1, y1, col):
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                self.px[x, y] = col

    def dot(self, x, y, col):
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = col

    def outline(self):
        src = self.img.copy().load()
        for y in range(H):
            for x in range(W):
                if src[x, y][3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and src[nx, ny][3] != 0 and src[nx, ny] != OUTLINE:
                        self.px[x, y] = OUTLINE
                        break


def head(c, hair, hair_hi, style):
    # Hair behind the head
    if style == "bob":
        c.rect(8, 4, 23, 22, hair)
    elif style == "ponytail":
        c.rect(9, 4, 22, 15, hair)
        c.rect(23, 8, 25, 28, hair)  # ponytail hanging at the side
        c.rect(24, 9, 24, 26, hair_hi)
    # Face
    c.rect(10, 7, 21, 18, SKIN)
    c.rect(11, 19, 20, 19, SKIN)
    c.rect(21, 9, 21, 18, SKIN_SHADE)
    # Hair on top / fringe
    if style == "spiky":
        c.rect(9, 3, 22, 9, hair)
        for x in (9, 12, 15, 18, 21):
            c.rect(x, 1, x + 1, 3, hair)
        c.rect(9, 10, 9, 13, hair)
        c.rect(22, 10, 22, 13, hair)
        for x in (11, 14, 17, 20):
            c.dot(x, 10, hair)
    elif style == "short":
        c.rect(9, 4, 22, 9, hair)
        c.rect(9, 10, 9, 14, hair)
        c.rect(22, 10, 22, 14, hair)
        for x in range(11, 21, 3):
            c.dot(x, 10, hair)
    else:  # bob / ponytail fringe
        c.rect(9, 4, 22, 10, hair)
        for x in range(10, 22, 2):
            c.dot(x, 11, hair)
        if style == "bob":
            c.rect(8, 10, 9, 21, hair)
            c.rect(22, 10, 23, 21, hair)
    c.rect(12, 5, 16, 5, hair_hi)  # shine
    c.rect(11, 6, 12, 6, hair_hi)
    # Eyes, blush, mouth
    for ex in (12, 18):
        c.rect(ex, 12, ex + 1, 14, EYE)
        c.dot(ex, 12, (255, 255, 255, 255))
    c.dot(11, 16, BLUSH)
    c.dot(20, 16, BLUSH)
    c.rect(15, 17, 16, 17, SKIN_SHADE)


def torso(c, girl):
    c.rect(14, 20, 17, 21, SKIN_SHADE)  # neck
    c.rect(9, 22, 22, 38, SHIRT)
    c.rect(21, 23, 22, 38, SHIRT_SHADE)
    c.rect(7, 22, 8, 29, SHIRT)  # sleeves
    c.rect(23, 22, 24, 29, SHIRT_SHADE)
    c.rect(7, 30, 8, 37, SKIN)  # arms
    c.rect(23, 30, 24, 37, SKIN_SHADE)
    c.rect(7, 38, 8, 39, SKIN)  # hands
    c.rect(23, 38, 24, 39, SKIN_SHADE)
    c.rect(11, 22, 12, 32, STRAP)  # backpack straps
    c.rect(19, 22, 20, 32, STRAP)
    if girl:
        c.rect(14, 23, 17, 25, NAVY)  # bow
        c.rect(15, 26, 16, 28, NAVY)
    else:
        c.rect(14, 22, 17, 22, SHIRT_SHADE)  # collar
        c.dot(15, 23, SHIRT_SHADE)
        c.dot(16, 23, SHIRT_SHADE)
        c.rect(13, 27, 15, 28, (70, 110, 200, 255))  # school initials on chest
        for y in (26, 29, 32, 35):
            c.dot(16, y, SHIRT_SHADE)  # buttons


def legs(c, girl):
    if girl:
        for y in range(39, 51):
            grow = (y - 39) // 4
            c.rect(9 - grow, y, 22 + grow, y, NAVY)
        for x in range(9, 23, 3):
            c.rect(x, 42, x, 50, NAVY_SHADE)  # pleats
        top = 51
    else:
        c.rect(9, 39, 22, 49, NAVY)
        c.rect(15, 45, 16, 49, (0, 0, 0, 0))
        c.rect(21, 39, 22, 49, NAVY_SHADE)
        c.rect(9, 39, 22, 39, NAVY_SHADE)  # belt line
        top = 50
    c.rect(11, top, 13, 61, SKIN)
    c.rect(18, top, 20, 61, SKIN_SHADE)
    c.rect(11, 62, 13, 66, SOCK)
    c.rect(18, 62, 20, 66, SOCK)
    c.rect(10, 67, 14, 70, SHOE)
    c.rect(17, 67, 21, 70, SHOE)
    c.dot(11, 67, SHOE_HI)
    c.dot(18, 67, SHOE_HI)


def drink(c, x, y, col):
    c.rect(x, y, x + 3, y + 7, col)
    c.rect(x, y, x + 3, y, (250, 250, 250, 255))
    c.rect(x + 2, y - 3, x + 2, y - 1, (240, 60, 60, 255))  # straw
    c.dot(x + 1, y + 3, (255, 255, 255, 255))


def make(name, hair, hair_hi, style, girl, prop=None, glasses=False):
    c = Canvas()
    head(c, hair, hair_hi, style)
    if glasses:
        for ex in (11, 17):
            c.rect(ex, 11, ex + 3, 11, EYE)
            c.rect(ex, 15, ex + 3, 15, EYE)
            c.rect(ex, 11, ex, 15, EYE)
            c.rect(ex + 3, 11, ex + 3, 15, EYE)
            c.rect(ex + 1, 12, ex + 2, 14, SKIN)  # clear lens, smaller eye inside
            c.rect(ex + 1, 13, ex + 2, 14, EYE)
            c.dot(ex + 2, 12, (200, 230, 255, 255))  # lens glint
        c.rect(15, 12, 16, 12, EYE)
    torso(c, girl)
    legs(c, girl)
    if prop == "camera":
        # Holding a camera up to the face, filming
        c.rect(9, 10, 22, 17, (34, 34, 40, 255))
        c.rect(10, 11, 21, 11, (70, 70, 84, 255))
        c.rect(5, 12, 9, 15, (40, 40, 48, 255))  # lens
        c.rect(4, 12, 4, 15, (120, 170, 220, 255))
        c.rect(19, 12, 20, 13, (220, 60, 60, 255))  # REC light
        c.rect(7, 16, 9, 18, SKIN)  # hands
        c.rect(22, 16, 24, 18, SKIN_SHADE)
        c.rect(7, 30, 8, 39, (0, 0, 0, 0))  # arms are raised, not hanging
        c.rect(23, 30, 24, 39, (0, 0, 0, 0))
        c.rect(7, 19, 8, 29, SHIRT)
        c.rect(23, 19, 24, 29, SHIRT_SHADE)
    elif prop == "tea":
        drink(c, 24, 32, (235, 140, 70, 255))  # Thai iced tea
    elif prop == "pink":
        drink(c, 24, 32, (240, 150, 190, 255))  # pink milk
    elif prop == "earphones":
        c.rect(9, 15, 9, 17, (250, 250, 250, 255))
        for y in range(18, 34):
            c.dot(9 + (y % 2), y, (250, 250, 250, 255))
        c.rect(5, 34, 8, 39, (40, 40, 50, 255))  # phone in hand
    c.outline()
    c.img.save(OUT / f"{name}.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    make("friend_girl", (92, 58, 40, 255), (140, 96, 70, 255), "bob", True, "earphones")
    make("player", (22, 22, 32, 255), (70, 70, 96, 255), "spiky", False, "camera")
    make("friend_glasses", (26, 26, 36, 255), (74, 74, 100, 255), "short", False, "tea", glasses=True)
    make("friend_ponytail", (40, 30, 40, 255), (96, 76, 96, 255), "ponytail", True, "pink")
    print("characters written to", OUT)
