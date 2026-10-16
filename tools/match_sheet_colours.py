"""Match a sheet's colours to another sheet of the same character in a similar pose.

Clips where the character is small in the video frame come out lighter (dark hair and
shorts blend with the background more), so one colour correction for all clips is not
enough for them. This lays one frame of SRC over one frame of REF (best spot within a
few pixels of --dx/--dy), fits one smooth colour function (quadratic in RGB) on the
pixels both cover, dropping the 30% that differ most (where the poses differ, e.g. the
hand holding a phone), and applies it to every frame of SRC. See-through pixels
(alpha < 250, the clear umbrella) keep their colour.

Usage:
  python3 tools/match_sheet_colours.py SRC.png 62 0 REF.png 32 5 OUT.png --dx 9
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_idle_video import poly_terms  # noqa: E402


def frame(path, n, i):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    w = a.shape[1] // n
    return a, a[:, i * w:(i + 1) * w]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("src_frames", type=int)
    ap.add_argument("src_frame", type=int)
    ap.add_argument("ref")
    ap.add_argument("ref_frames", type=int)
    ap.add_argument("ref_frame", type=int)
    ap.add_argument("out")
    ap.add_argument("--dx", type=int, default=0, help="SRC's x minus REF's x for the same body part")
    ap.add_argument("--dy", type=int, default=0, help="the same for y, with both sheets' feet on the bottom row")
    args = ap.parse_args()

    sheet, s = frame(args.src, args.src_frames, args.src_frame)
    _, r = frame(args.ref, args.ref_frames, args.ref_frame)
    best = None
    for dy in range(args.dy - 2, args.dy + 3):
        for dx in range(args.dx - 3, args.dx + 4):
            # pixel (y, x) of REF <-> (y + oy, x + dx) of SRC, feet rows lined up
            oy = s.shape[0] - r.shape[0] + dy
            ys = np.arange(r.shape[0])[:, None] + oy
            xs = np.arange(r.shape[1])[None, :] + dx
            ok = (ys >= 0) & (ys < s.shape[0]) & (xs >= 0) & (xs < s.shape[1])
            sv = np.zeros_like(r)
            sv[ok] = s[np.clip(ys, 0, s.shape[0] - 1), np.clip(xs, 0, s.shape[1] - 1)][ok]
            both = (sv[..., 3] >= 250) & (r[..., 3] >= 250)
            err = np.abs(sv[..., :3] - r[..., :3])[both].mean() + 80 * (1 - both.sum() / max(1, (r[..., 3] >= 250).sum()))
            if best is None or err < best[0]:
                best = (err, sv, both, dx, dy)
    _, sv, both, dx, dy = best
    src, dst = sv[..., :3][both], r[..., :3][both]
    keep = np.ones(len(src), bool)
    for _ in range(4):
        coef, *_ = np.linalg.lstsq(poly_terms(src[keep]), dst[keep], rcond=None)
        res = np.abs(poly_terms(src) @ coef - dst).sum(1)
        keep = res < np.percentile(res, 70)
    op = sheet[..., 3] >= 250
    sheet[..., :3][op] = np.clip(poly_terms(sheet[..., :3][op]) @ coef, 0, 255)
    Image.fromarray(sheet.round().astype(np.uint8), "RGBA").save(args.out)
    print(f"laid at dx={dx} dy={dy}; {both.sum()} pixels; written {args.out}")


if __name__ == "__main__":
    main()
