"""Draw in the back leg's ankle on the heroine's walk sheet where the source left a gap.

In 7 of the 18 walk frames the back leg's ankle (between the trouser cuff and the shoe) came
out of the video as a few loose outline pixels, so the shoe looks cut off from the leg while
she walks. Each gap is given by hand (read off a zoomed frame): the cuff end and the shoe end
of the ankle. The ankle is drawn as a 2 px line of shaded skin inside a 1 px dark outline
(as thin as the front leg's), only on empty or outline pixels, so the trousers and shoe stay
on top. The few salmon pixels the source left of the back ankle are recoloured to the same
skin, so the ankle is one colour.
On frame 16 the back leg is behind the front one (only the toe peeks out): there the loose
pixels of the gap are just removed (specks of under 6 pixels not joined to the body).

Run on the dry sheet, then rebuild the rain sheet from it (tools/wet_heroine.py keeps skin):
  python3 tools/fix_heroine_ankles.py assets/characters/heroine_walk.png
  python3 tools/wet_heroine.py assets/characters/heroine_walk.png 18 \\
      assets/characters/heroine_walk_wet.png --lens 19 21 19 20 --lens 25 27 19 20
"""
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

FRAME_W = 50
SKIN = (224, 188, 158)        # the front leg's skin (255, 229, 184) a little shaded: the back leg is further away
OUTLINE = (100, 41, 49)
# frame: ((cuff x, y), (shoe x, y)), x within the frame
ANKLES = {
    0: ((33, 95), (37, 102)),
    1: ((33, 95), (36, 101)),
    2: ((35, 93), (40, 100)),
    3: ((32, 90), (36, 94)),
    4: ((31, 92), (33, 95)),
    17: ((31, 98), (32, 104)),
}
CLEAN = [16]


def main():
    path = sys.argv[1]
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).copy()
    for frame, (cuff, shoe) in ANKLES.items():
        ox = frame * FRAME_W
        x0, x1 = sorted((cuff[0], shoe[0]))
        y0, y1 = sorted((cuff[1], shoe[1]))
        box = a[y0 - 2:y1 + 3, ox + x0 - 2:ox + x1 + 3]
        salmon = (box[..., 3] > 0) & (box[..., 0] > 235) & (box[..., 1] < 175) & (box[..., 2] < 150)
        box[salmon, :3] = SKIN
        for colour, width in ((OUTLINE, 4), (SKIN, 2)):
            mask = Image.new("L", im.size, 0)
            ImageDraw.Draw(mask).line([(ox + cuff[0], cuff[1]), (ox + shoe[0], shoe[1])], fill=255, width=width)
            m = np.asarray(mask) > 0
            dark = a[..., :3].sum(-1) < 260                     # outline pixels may be painted over
            free = (a[..., 3] == 0) | dark if colour == OUTLINE else (a[..., 3] == 0) | dark | painted
            m &= free
            if colour == OUTLINE:
                painted = m.copy()
                m &= a[..., 3] == 0                              # outline only on empty pixels
            a[m, :3] = colour
            a[m, 3] = 255
    for frame in CLEAN:
        sl = (slice(None), slice(frame * FRAME_W, (frame + 1) * FRAME_W))
        lab, n = ndimage.label(a[sl][..., 3] > 0, structure=np.ones((3, 3)))
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        for k, size in enumerate(sizes, 1):
            if size < 6:
                a[sl][lab == k] = 0
    Image.fromarray(a).save(path)
    print(f"ankles drawn on {len(ANKLES)} frames -> {path}")


if __name__ == "__main__":
    main()
