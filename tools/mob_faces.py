"""Background-classmate faces: no eyes, a shadow over the eye line, like extras in anime.

Each sheet in assets/classroom/students/ (4 frames of 160x192: front, back, side, side) keeps its
drawing except the face. In every frame that shows a face the face is found as the largest patch of
skin above the shirt collar, with the eyes and brows it encloses (closing its gaps); across its upper
half the eyes and brows are painted over with the face's own skin, then shaded darker toward the hair
line so the eyes read as hidden in the fringe's shadow. Sun and Saifon are not touched.

Usage:
  python3 tools/mob_faces.py assets/classroom/students assets/classroom/students/mob
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

FRAME = (160, 192)
LEADS = {"sun", "saifon"}
FACE_FRAMES = (0, 2, 3)                  # front and the two sides; frame 1 is the back of the head
BAND = (0.0, 0.52)                      # eye band, as a share of the face's height from its top
SHADE = (0.58, 0.86)                    # brightness at the top / bottom of the band


def skin_mask(rgb, alpha):
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    return (alpha > 128) & (r > 110) & (r >= g) & (g >= b - 6) & (r - b > 28) & (rgb.min(2) < 225)


def collar_row(rgb, alpha):
    """First row from the top with a run of the white shirt."""
    white = (alpha > 128) & (rgb.min(2) > 185) & (rgb.max(2).astype(int) - rgb.min(2) < 32)
    rows = np.nonzero(white.sum(1) >= 8)[0]
    return int(rows[0]) if len(rows) else rgb.shape[0] // 2


def mob_face(frame):
    rgb, alpha = frame[..., :3], frame[..., 3]
    skin = skin_mask(rgb, alpha)
    skin[collar_row(rgb, alpha) + 2:] = False
    # glasses frames and lashes cut the skin into pieces: join pieces a thin line apart
    labels, n = ndimage.label(ndimage.binary_closing(skin, np.ones((3, 3))) | skin)
    if n == 0:
        return frame
    # the face: the highest sizeable patch of skin (right under the hair; hands and arms sit lower)
    sizes = ndimage.sum(skin, labels, range(1, n + 1))
    tops = ndimage.minimum(np.arange(skin.size).reshape(skin.shape) // skin.shape[1], labels, range(1, n + 1))
    big = [i for i in range(n) if sizes[i] >= 0.25 * sizes.max()]
    face = (labels == (min(big, key=lambda i: tops[i]) + 1)) & skin
    # with its eyes and brows: what it encloses once its gaps are closed, and anything between its
    # left and right edges on a row
    whole = ndimage.binary_fill_holes(ndimage.binary_closing(face, np.ones((7, 7))) | face)
    for y in np.nonzero(face.any(1))[0]:
        cols = np.nonzero(face[y])[0]
        whole[y, cols.min():cols.max() + 1] = True
    whole &= alpha > 128
    ys, xs = np.nonzero(face)
    y0, y1 = ys.min(), ys.max()
    h = y1 - y0 + 1
    band0, band1 = y0 + int(BAND[0] * h), y0 + int(BAND[1] * h)
    tone = np.median(rgb[face], axis=0)
    out = frame.copy().astype(float)
    features = whole & ~face
    features[:band0] = False
    features[band1 + 1:] = False
    out[..., :3][features] = tone
    for y in range(band0, band1 + 1):
        t = (y - band0) / max(band1 - band0, 1)
        out[y, :, :3][whole[y]] *= SHADE[0] + (SHADE[1] - SHADE[0]) * t
    return np.clip(out, 0, 255).astype(np.uint8)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for name in sorted(os.listdir(src)):
        if not name.endswith(".png") or name[:-4] in LEADS:
            continue
        sheet = np.asarray(Image.open(os.path.join(src, name)).convert("RGBA")).copy()
        w = FRAME[0]
        for f in FACE_FRAMES:
            sheet[:, f * w:(f + 1) * w] = mob_face(sheet[:, f * w:(f + 1) * w])
        Image.fromarray(sheet, "RGBA").save(os.path.join(dst, name))
        print(name)


if __name__ == "__main__":
    main()
