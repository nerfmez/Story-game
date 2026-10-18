"""Turn a character video on a plain background (green screen or any flat colour) into a
pixel-art sprite sheet, keeping the video's own shading (like import_idle_video.py's
default mode). Works for standing and for walking-in-place clips, and for see-through
props (a clear umbrella).

  - background: every pixel far enough from the background colour (the median of the
    frame border, or --bg) is the character; tiny specks are dropped
  - frames are lined up: feet on one ground row, and sideways either on the feet
    (--align feet, for standing) or on the shirt (--align torso, for walking)
  - --glass: a clear prop shows the background through it. Above the collar, pixels
    that lie between the background colour and the prop's colour (--plastic) are
    unmixed: alpha = how far along that line they are, colour = the prop's own
  - size: the collar sits --collar game pixels above the feet (default: as in the
    --palette still), like the other sprites, so switching animations doesn't jump
  - each game pixel takes the median colour at the centre of its cell; the overall tone
    is matched to the still with one smooth colour function (see import_idle_video.py)

Usage:
  python3 tools/import_char_video.py VIDEO OUT.png --start 49 --end 95 --step 2 \\
      --palette assets/characters/hero_uniform.png --align feet --glass
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_idle_video import colour_match  # noqa: E402
from import_walk_video import landmarks, shift_img  # noqa: E402
from fix_head_size import apply_map, head_map  # noqa: E402


def key(rgb, bg, threshold, border=4):
    mask = np.sqrt(((rgb - bg) ** 2).sum(2)) > threshold
    n = sum(np.roll(np.roll(mask, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
    mask &= n >= 4                                   # drop compression specks
    mask[:border] = mask[-border:] = False           # the frame's edge rows/columns are noisy
    mask[:, :border] = mask[:, -border:] = False
    return mask


def body_marks(rgb, mask):
    """(ground row, collar row, shirt centre x, feet centre x) at video resolution."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(2)
    # hair: dark and not green (brown hair is warm, black hair has no clear hue)
    hair = mask & (mx < 150) & (mx > 15) & (g < r + 20) & ((r > b + 20) | (mx < 110))
    white = mask & (rgb.min(2) > 195)
    ys = np.nonzero(mask.sum(1) >= 6)[0]            # a few stray pixels don't make a ground row
    ground = ys.max()
    hair_top = np.nonzero(hair.sum(1) >= 25)[0].min()
    collar = hair_top + 60 + np.nonzero(white[hair_top + 60:].sum(1) >= 40)[0].min()
    shirt = np.nonzero(white[collar:collar + 200])[1].mean()
    fy, fx = np.nonzero(mask[ground - int(0.06 * (ground - ys.min())):ground + 1])
    return ground, collar, shirt, fx.mean()


def outline_marks(mask):
    """Like body_marks, for a character without the hero's white shirt (--height): the
    "collar" is the top of the head, the torso is the middle of the rows 25-45% down."""
    ys = np.nonzero(mask.sum(1) >= 6)[0]
    ground = ys.max()
    top = np.nonzero(mask.sum(1) >= 2)[0].min()
    h = ground - top
    torso = np.nonzero(mask[top + int(0.25 * h):top + int(0.45 * h)])[1].mean()
    fy, fx = np.nonzero(mask[ground - int(0.06 * h):ground + 1])
    return ground, top, torso, fx.mean()


def unmix(rgb, mask, bg, plastic, rows):
    """Clear plastic over the background: c = a * plastic + (1 - a) * bg."""
    u = plastic - bg
    v = rgb - bg
    a = (v @ u) / (u @ u)
    resid = np.sqrt(((v - a[..., None] * u) ** 2).sum(2))
    prop = mask & (resid < 45) & (a > 0.06)       # between the background and the plastic
    prop[rows:] = False                           # (darker than the background = hair, not plastic)
    glass = prop & (a < 0.92)                     # see-through; the rest of the prop: solid ribs, rim
    a = np.clip(a, 0.15, 1.0)
    # one even colour for the plastic (the unmixed colours wander a little); its shape
    # and the brighter ribs and edges are carried by the alpha
    out = np.where(prop[..., None], plastic, rgb)
    alpha = np.where(glass, a * 255, np.where(mask, 255.0, 0.0))
    return out, alpha, prop


def materials(px):
    """Masks of the materials every sprite of the hero has, by colour."""
    r, g, b = px[:, 0], px[:, 1], px[:, 2]
    mx, mn = px.max(1), px.min(1)
    lum = px @ np.array((0.299, 0.587, 0.114))
    return {
        "skin": (r > 180) & (r - b > 50) & (g > 110) & (g < 205),
        "skin shade": (r > 120) & (r <= 180) & (r - b > 40) & (g > 60),
        "hair, shoes": (mx < 150) & (mx > 25) & (((r > b + 15) & (r >= g)) | (mx < 110)),
        "shirt, socks": mn > 185,
        "shirt shade": (mn > 140) & (mn <= 185) & (b >= r - 10),
        "bag": (b > r + 25) & (mx < 150),
        "darkest": lum < 45,
    }


def kmeans_rgb(px, k, iters=30, seed=3):
    rng = np.random.default_rng(seed)
    c = px[rng.choice(len(px), k, replace=False)].astype(float)
    for _ in range(iters):
        lab = ((px[:, None] - c[None]) ** 2).sum(2).argmin(1)
        for j in range(k):
            if (lab == j).any():
                c[j] = px[lab == j].mean(0)
    return c


def match_materials(frames, solid, ref_px, k=10, sigma=28.0):
    """Light-to-shadow range of every material, matched to the reference sprite.

    The reference's colours are split into k groups (skin light/shadow, hair, shirt,
    shirt shading, bag, shorts...). Each group gets a ramp: its colour as a function of
    how bright a pixel is within the group (dark end -> light end). A frame pixel belongs
    softly to the groups near its colour; within each it takes the ramp colour at the
    same brightness rank its frame group has. The result depends smoothly on the input
    colour (similar colours stay similar), so the shading keeps its shape: no blotches."""
    lum_w = np.array((0.299, 0.587, 0.114))
    centres = kmeans_rgb(ref_px, k)
    ref_lab = ((ref_px[:, None] - centres[None]) ** 2).sum(2).argmin(1)
    q = np.linspace(0, 1, 33)
    ramps = []
    for j in range(k):
        v = ref_px[ref_lab == j]
        order = np.argsort(v @ lum_w)
        idx = np.clip((q * (len(v) - 1)).round().astype(int), 0, len(v) - 1)
        ramp = v[order][idx].astype(float)
        ramp = np.array([ramp[max(0, i - 2):i + 3].mean(0) for i in range(len(q))])   # smooth
        ramps.append(ramp)
    src = np.concatenate([f[..., :3][m] for f, m in zip(frames, solid)]).astype(float)
    src_lab = ((src[:, None] - centres[None]) ** 2).sum(2).argmin(1)
    cdfs = []
    for j in range(k):
        l = np.sort(src[src_lab == j] @ lum_w) if (src_lab == j).sum() >= 10 else None
        cdfs.append(l)

    def remap(px):
        d2 = ((px[:, None] - centres[None]) ** 2).sum(2)
        w = np.exp(-(d2 - d2.min(1, keepdims=True)) / (2 * sigma ** 2))
        w /= w.sum(1, keepdims=True)
        lum = px @ lum_w
        out = np.zeros_like(px)
        for j in range(k):
            if cdfs[j] is None:
                out += w[:, j:j + 1] * px
                continue
            rank = np.searchsorted(cdfs[j], lum) / len(cdfs[j])
            col = np.stack([np.interp(rank, q, ramps[j][:, c]) for c in range(3)], 1)
            out += w[:, j:j + 1] * col
        return out

    result = []
    for f, m in zip(frames, solid):
        g = f.copy()
        g[..., :3][m] = np.clip(remap(g[..., :3][m].astype(float)), 0, 255).round()
        result.append(g)
    return result


def colour_transfer(frames, solid, ref_px):
    """Give the frames the colours of a reference sprite with one smooth (affine) colour
    function, fitted so the average colour of each material (skin, hair, shirt, bag...)
    lands on the reference's. Works whatever the pose (unlike laying the frame over the
    still)."""
    src = np.concatenate([f[..., :3][m] for f, m in zip(frames, solid)]).astype(float)
    ms, mr = materials(src), materials(ref_px)
    rows, targets, weights = [], [], []
    for name in ms:
        if ms[name].sum() >= 30 and mr[name].sum() >= 30:
            rows.append(np.r_[src[ms[name]].mean(0), 1])
            targets.append(ref_px[mr[name]].mean(0))
            weight = np.sqrt(min(ms[name].sum(), mr[name].sum()))
            weights.append(weight * (3 if name == "skin" else 1))   # skin is what the eye checks first
    W = np.array(weights)[:, None]
    A, *_ = np.linalg.lstsq(np.array(rows) * W, np.array(targets) * W, rcond=None)
    out = []
    for f, m in zip(frames, solid):
        g = f.copy()
        g[..., :3][m] = np.clip(np.c_[g[..., :3][m].astype(float), np.ones(m.sum())] @ A, 0, 255).round()
        out.append(g)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out")
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--end", type=int, default=-1, help="last frame (inclusive), -1 = to the end")
    ap.add_argument("--step", type=int, default=2, help="keep every n-th frame (24 fps / 2 = 12 fps)")
    ap.add_argument("--palette", required=True, help="still sprite: tone and collar height to match")
    ap.add_argument("--collar", type=float, default=0, help="collar height above the feet (default: the still's)")
    ap.add_argument("--height", type=int, default=0,
                    help="scale by the whole figure (top of the head to the feet) to this many game "
                         "pixels instead of by the collar (for characters without the hero's shirt)")
    ap.add_argument("--count", type=int, default=0,
                    help="take this many evenly spaced frames from --start up to (not including) "
                         "--end, the frame that matches --start again (instead of --step)")
    ap.add_argument("--align", choices=("feet", "torso"), default="feet")
    ap.add_argument("--bg", default="auto", help="background colour R,G,B (auto: median of the frame border)")
    ap.add_argument("--threshold", type=float, default=30, help="colour distance from the background")
    ap.add_argument("--glass", action="store_true", help="unmix a see-through prop above the collar")
    ap.add_argument("--head-scale", type=float, default=1.0,
                    help="scale everything above the collar (head, umbrella) around the neck, e.g. 0.92")
    ap.add_argument("--match", nargs=2, metavar=("SHEET", "FRAMES"),
                    help="take the colours of this sprite sheet (materials matched, any pose); "
                         "default: lay the first frame over the --palette still")
    ap.add_argument("--keep-colours", action="store_true",
                    help="keep the video's own colours (when the clip was made from the still's own art)")
    ap.add_argument("--plastic", default="226,232,242", help="colour of the see-through prop itself")
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["ffmpeg", "-v", "error", "-i", args.video, f"{tmp}/f%04d.png"], check=True)
        files = sorted(Path(tmp).glob("f*.png"))
        end = len(files) - 1 if args.end < 0 else args.end
        if args.count:
            picks = [round(args.start + k * (end - args.start) / args.count) for k in range(args.count)]
        else:
            picks = range(args.start, end + 1, args.step)
        frames = [np.asarray(Image.open(files[i]).convert("RGB")).astype(float) for i in picks]

    f0 = frames[0]
    border = np.concatenate([f0[:8].reshape(-1, 3), f0[-8:].reshape(-1, 3), f0[:, :8].reshape(-1, 3), f0[:, -8:].reshape(-1, 3)])
    bg = np.median(border, 0) if args.bg == "auto" else np.array([float(v) for v in args.bg.split(",")])
    plastic = np.array([float(v) for v in args.plastic.split(",")])
    masks = [key(f, bg, args.threshold) for f in frames]
    marks = [outline_marks(m) if args.height else body_marks(f, m) for f, m in zip(frames, masks)]

    # line the frames up: one ground row, and the feet or the shirt at one x
    g_ref = int(np.median([m[0] for m in marks]))
    xi = 3 if args.align == "feet" else 2
    x_ref = float(np.median([m[xi] for m in marks]))
    shifts = [(int(round(x_ref - m[xi])), g_ref - m[0]) for m in marks]
    frames = [shift_img(f, dx, dy) for f, (dx, dy) in zip(frames, shifts)]
    masks = [shift_img(m, dx, dy) for m, (dx, dy) in zip(masks, shifts)]
    collars = [m[1] + dy for m, (_, dy) in zip(marks, shifts)]
    necks = [m[2] + dx for m, (dx, _) in zip(marks, shifts)]

    union = np.any(masks, axis=0)
    ys, xs = np.nonzero(union)
    mg = 6
    x0, x1, y0, y1 = max(0, xs.min() - mg), xs.max() + 1 + mg, max(0, ys.min() - mg), g_ref + 1
    frames = [f[y0:y1, x0:x1] for f in frames]
    masks = [m[y0:y1, x0:x1] for m in masks]
    collars = [c - y0 for c in collars]
    necks = [x - x0 for x in necks]

    if args.head_scale != 1.0:
        # AI clips often draw the head (and what is above the collar) too big for the body:
        # scale it around the neck, ramping in above the collar (see fix_head_size.py)
        ch, cw = masks[0].shape
        for k in range(len(frames)):
            sy, sx, bad = head_map(ch, cw, int(collars[k]), necks[k], args.head_scale)
            frames[k] = apply_map(frames[k], sy, sx, bad, bg)
            masks[k] = apply_map(masks[k], sy, sx, bad, False)

    green_screen = bg[1] > bg[0] + 60 and bg[1] > bg[2] + 60
    alphas, props = [], []
    for k in range(len(frames)):
        if args.glass:
            frames[k], al, pr = unmix(frames[k], masks[k], bg, plastic, collars[k])
        else:
            al, pr = masks[k] * 255.0, np.zeros(masks[k].shape, bool)
        props.append(pr)
        if green_screen:
            # pull leftover green out of the solid edge pixels (after the unmix, which needs
            # it; the tone match would otherwise push greenish edges to pink)
            f = frames[k]
            solid = al >= 255
            f[..., 1] = np.where(solid, np.minimum(f[..., 1], np.maximum(f[..., 0], f[..., 2])), f[..., 1])
        alphas.append(al)

    ref = np.asarray(Image.open(args.palette).convert("RGBA"))
    if args.height:
        target = args.height - 1                  # top row to ground row
    else:
        target = args.collar or landmarks(ref)[0]
    ch, cw = masks[0].shape
    scale = target / np.median([ch - 1 - c for c in collars])
    out_w, out_h = round(cw * scale / 2) * 2, round(ch * scale)
    sy, sx = ch / out_h, cw / out_w
    q = max(1, int(min(sx, sy) * 0.25))
    result, glassy, propy = [], [], []
    for rgb, mk, al, pr in zip(frames, masks, alphas, props):
        out = np.zeros((out_h, out_w, 4))
        prop_cell = np.zeros((out_h, out_w), bool)
        for j in range(out_h):
            cy = min(ch - 1, int((j + 0.5) * sy))
            if j == out_h - 1:
                cy = ch - 1 - q                   # bottom row samples the soles, not below them
            ys_ = slice(max(0, cy - q), cy + q + 1)
            for i in range(out_w):
                cx = int((i + 0.5) * sx)
                xs_ = slice(max(0, cx - q), cx + q + 1)
                m = mk[ys_, xs_]
                if m.mean() >= 0.5:
                    out[j, i, :3] = np.median(rgb[ys_, xs_][m], axis=0)
                    out[j, i, 3] = np.median(al[ys_, xs_][m])
                    prop_cell[j, i] = pr[ys_, xs_][m].mean() >= 0.5
        result.append(out.round().astype(np.uint8))
        glassy.append((out[..., 3] > 0) & (out[..., 3] < 250))
        propy.append(prop_cell | glassy[-1])
    if args.keep_colours:
        final = result
    elif args.match:
        path, n = args.match[0], int(args.match[1])
        sheet_ref = np.asarray(Image.open(path).convert("RGBA"))
        ref_px = sheet_ref[..., :3][sheet_ref[..., 3] >= 250].astype(float)
        # the umbrella keeps its own colour: the unmixed plastic, and above the collar
        # everything that is neither hair nor skin (ribs, rim, shaft)
        solid = []
        for f, pr, c in zip(result, propy, collars):
            r, g, b = (f[..., i].astype(int) for i in range(3))
            mx = np.maximum(np.maximum(r, g), b)
            hair = (mx < 160) & (((r > b + 12) & (r >= g)) | (mx < 110))   # brown or black
            skin = (r > 150) & (r - b > 45) & (r > g + 15)
            above = np.zeros(pr.shape, bool)
            above[:int(round(c * scale)) - 4] = True      # (the shirt collar's points rise a few px)
            ribs = (f[..., 3] >= 250) & ~pr & above & ~hair & ~skin
            # solid umbrella parts (ribs, rim, shaft): their own brightness in the plastic's
            # cool grey (on a green screen they pick up teal/lavender casts)
            lum = f[..., :3].astype(float) @ np.array((0.299, 0.587, 0.114))
            grey = np.clip(plastic[None, None] * (lum / (plastic @ np.array((0.299, 0.587, 0.114))))[..., None], 0, 255)
            f[..., :3][ribs] = grey[ribs].round()
            solid.append((f[..., 3] >= 250) & ~pr & ~ribs)
        final = match_materials(colour_transfer(result, solid, ref_px), solid, ref_px)
    else:
        matched = colour_match([np.where(gl[..., None], 0, f) for f, gl in zip(result, glassy)], ref)
        final = []
        for m, f, gl in zip(matched, result, glassy):
            m = m.copy()
            m[gl] = f[gl]                             # the clear prop keeps its unmixed colour
            final.append(m)

    sheet = Image.new("RGBA", (out_w * len(final), out_h), (0, 0, 0, 0))
    for i, f in enumerate(final):
        sheet.paste(Image.fromarray(f, "RGBA"), (i * out_w, 0))
    sheet.save(args.out)
    heights = [round(out_h - 1 - c * scale) for c in collars]
    print(f"{len(final)} frames of {out_w}x{out_h} -> {args.out}; background {bg.round().tolist()}; "
          f"collar heights {sorted(set(heights))} (target {target}); scale {scale:.4f}")


if __name__ == "__main__":
    main()
