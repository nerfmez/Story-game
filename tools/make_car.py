"""Draw the car that passes in the foreground on the way to the crossing (an out-of-focus silhouette).

It drives along the near side of the road, between the camera and the boy, so it is close to the
camera: big, dark against the dawn light, out of focus, and mostly below the bottom of the screen
(only the roof, windows and the top of the body show). Side view, facing right.
Drawn 4x larger from shapes, shrunk smoothly, then blurred a little (out of focus):
  - body: near-black blue, a pale rim along the roof and shoulder (sky light on wet paint)
  - windows: a little lighter, with a faint slanted reflection
  - headlight (front) and tail light (back); the game adds their glow
Writes the car and prints the light positions for crossing_car.gd.

Usage:
  python3 tools/make_car.py assets/props/car_silhouette.png
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 300, 112          # game pixels
K = 4
BODY = (14, 17, 27, 255)
RIM = (58, 70, 96, 255)
GLASS = (26, 33, 50, 255)
SHINE = (60, 72, 98, 255)
HEAD = (236, 228, 200, 255)
TAIL = (190, 40, 46, 255)


def main():
    im = Image.new("RGBA", (W * K, H * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = lambda pts: [(x * K, y * K) for x, y in pts]
    # body: low sedan, nose to the right
    body = [(6, 70), (14, 56), (70, 50), (100, 22), (128, 12), (196, 12), (230, 30), (262, 48),
            (292, 56), (298, 70), (298, 112), (6, 112)]
    d.polygon(s(body), fill=BODY)
    # pale rim on the top edge (roof and shoulder catch the sky)
    for a, b in [((70, 50), (100, 22)), ((100, 22), (128, 12)), ((128, 12), (196, 12)), ((196, 12), (230, 30)),
                 ((230, 30), (262, 48)), ((262, 48), (292, 56)), ((14, 56), (70, 50))]:
        d.line(s([a, b]), fill=RIM, width=int(1.6 * K))
    # windows: rear and front, split by the pillar
    d.polygon(s([(84, 50), (108, 26), (156, 19), (156, 50)]), fill=GLASS)
    d.polygon(s([(164, 19), (196, 19), (222, 34), (240, 50), (164, 50)]), fill=GLASS)
    d.polygon(s([(120, 50), (138, 22), (146, 22), (128, 50)]), fill=SHINE)          # slanted reflection
    d.polygon(s([(186, 50), (200, 26), (205, 26), (192, 50)]), fill=SHINE)
    # wet shine along the body
    d.line(s([(20, 64), (290, 64)]), fill=RIM, width=int(1.0 * K))
    # lights
    d.polygon(s([(282, 60), (298, 62), (298, 70), (284, 68)]), fill=HEAD)
    d.polygon(s([(6, 62), (16, 60), (16, 68), (6, 70)]), fill=TAIL)
    # wheel arches (mostly off screen)
    for cx in (60, 240):
        d.ellipse(s([(cx - 26, 84), (cx + 26, 136)]), fill=(6, 7, 12, 255))
    small = im.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.4))
    out = sys.argv[1] if len(sys.argv) > 1 else "car_silhouette.png"
    small.save(out)
    print(f"{W}x{H} -> {out}; headlight at (296, 65), tail light at (9, 65)")


if __name__ == "__main__":
    main()
