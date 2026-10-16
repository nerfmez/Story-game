"""Give other sheets the same colour correction one sheet got.

import_char_video.py matches a standing clip to the still by laying its first frame over
the still (one smooth quadratic colour function). Walking and other clips can't be laid
over the still (different pose), but when they come from the same generator and design
their raw colours are the same as the standing clip's (checked: shirt, skin, hair within a
few levels). So: fit the function that turns the standing clip's raw sheet
(--keep-colours) into its matched sheet, pixel by pixel (same frames, same pixels), and
apply exactly that to the other raw sheets. All clips then share one set of tones.
See-through pixels (the clear umbrella, alpha < 250) keep their colour.

Usage:
  python3 tools/apply_colour_fit.py RAW_IDLE.png MATCHED_IDLE.png RAW_WALK.png OUT_WALK.png [RAW OUT ...]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_idle_video import poly_terms  # noqa: E402


def main():
    raw, matched, *pairs = sys.argv[1:]
    a = np.asarray(Image.open(raw).convert("RGBA")).astype(float)
    b = np.asarray(Image.open(matched).convert("RGBA")).astype(float)
    both = (a[..., 3] >= 250) & (b[..., 3] >= 250)
    coef, *_ = np.linalg.lstsq(poly_terms(a[..., :3][both]), b[..., :3][both], rcond=None)
    err = np.abs(poly_terms(a[..., :3][both]) @ coef - b[..., :3][both]).mean()
    print(f"fit on {both.sum()} pixels, mean error {err:.2f}")
    for src, dst in zip(pairs[::2], pairs[1::2]):
        s = np.asarray(Image.open(src).convert("RGBA")).astype(float)
        op = s[..., 3] >= 250
        s[..., :3][op] = np.clip(poly_terms(s[..., :3][op]) @ coef, 0, 255)
        Image.fromarray(s.round().astype(np.uint8), "RGBA").save(dst)
        print("written", dst)


if __name__ == "__main__":
    main()
