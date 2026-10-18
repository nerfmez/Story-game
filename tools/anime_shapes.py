"""Anime-style pixel-art shapes: cumulus clouds and leafy trees.

Both are built from round "lobes" (cloud puffs / leaf clumps) that are each lit
like a small sphere and quantised into a few hard-edged cel tones. Lobes are
drawn back to front, and where a lobe overlaps one already drawn, its rim on
the side away from the light gets a darker crease, giving the familiar
cauliflower clouds and clumpy trees of anime backgrounds.

All functions return float RGBA arrays (H, W, 4) in 0..255.
"""
import math
import random

import numpy as np

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def _norm3(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def _tone(v, thresholds, xx, yy, dither_band=0.05):
    """Quantise lighting into tone indices with a thin dithered band at each step."""
    d = (BAYER[yy % 4, xx % 4] - 0.5) * 2 * dither_band
    idx = np.zeros(v.shape, int)
    for t in thresholds:
        idx += (v + d) > t
    return idx


# ---------------------------------------------------------------- clouds

def cumulus_lobes(rng, cx, base_y, width, height, base_r=(14, 22)):
    """Lobes for a cumulus / cumulonimbus: wide flat base, puffs piled into a
    tower that narrows towards the top. Returned top-first (draw order)."""
    lobes = []
    tiers = max(2, int(height / (base_r[0] * 1.1)))
    for t in range(tiers):
        f = t / max(1, tiers - 1)                      # 0 at the base, 1 at the top
        span = width * (1 - 0.65 * f) * 0.5
        r_mid = (base_r[0] + (base_r[1] - base_r[0]) * (1 - f)) * (1 - 0.35 * f)
        y = base_y - r_mid * 0.6 - height * f * 0.85
        n = max(1, int(span * 2 / (r_mid * 0.8)))
        for k in range(n):
            x = cx - span + (k + 0.5) * span * 2 / n + rng.uniform(-r_mid * 0.3, r_mid * 0.3)
            r = r_mid * rng.uniform(0.6, 1.25)
            lobes.append((x, y + rng.uniform(-r * 0.25, r * 0.15), r))
    # Small puffs breaking the outline
    for _ in range(int(width / 18)):
        lx, ly, lr = rng.choice(lobes)
        a = rng.uniform(math.pi * 1.0, math.pi * 2.0)
        lobes.append((lx + math.cos(a) * lr * 0.8, ly + math.sin(a) * lr * 0.8, lr * rng.uniform(0.35, 0.55)))
    lobes.sort(key=lambda l: l[1] - l[2] * 0.2)  # higher lobes first, lower ones overlap them
    return lobes


def stratus_lobes(rng, x0, x1, y, thickness):
    """Long thin cloud streak: a chain of flattened puffs."""
    lobes = []
    x = x0
    while x < x1:
        r = thickness * rng.uniform(0.7, 1.2)
        lobes.append((x, y + rng.uniform(-thickness * 0.3, thickness * 0.3), r))
        x += r * rng.uniform(0.7, 1.1)
    return lobes


def render_lobes(size, lobes, light_at, palette, base_y=None, squash=1.0, crease=True,
                 edge_jitter=0.0, leaf_noise=None, rng=None, crease_col=None, rim_col=None,
                 global_weight=0.0):
    """Draw lit spherical lobes back to front.

    light_at: (x, y, z) position of the light (a far sun can use a big z).
    palette: tones from darkest to brightest.
    base_y: clip everything below this line (flat cloud base).
    squash: vertical squash of each lobe (stratus < 1).
    edge_jitter: scallop amplitude for leafy edges (fraction of radius).
    leaf_noise: optional (H, W) field added to lighting to break tones into clumps.
    """
    w, h = size
    out = np.zeros((h, w, 4))
    yy_all, xx_all = np.mgrid[0:h, 0:w]
    n_tones = len(palette)
    thresholds = [-0.15 + 1.25 * (i + 1) / n_tones for i in range(n_tones - 1)]
    pal = np.array(palette, float)
    rng = rng or random.Random(0)
    # Overall form: one big ellipsoid around all lobes, so the whole cloud/crown
    # is lit as a single volume and lobes only add local bumps
    gx0 = min(l[0] - l[2] for l in lobes)
    gx1 = max(l[0] + l[2] for l in lobes)
    gy0 = min(l[1] - l[2] * squash for l in lobes)
    gy1 = max(l[1] + l[2] * squash for l in lobes)
    if base_y is not None:
        gy1 = min(gy1, base_y)
    gcx, gcy = (gx0 + gx1) / 2, (gy0 + gy1) / 2
    grx, gry = max(1.0, (gx1 - gx0) / 2), max(1.0, (gy1 - gy0) / 2)
    GL = _norm3((light_at[0] - gcx, light_at[1] - gcy, light_at[2]))
    for (cx, cy, r) in lobes:
        ry = r * squash
        x0, x1 = int(max(0, cx - r - 2)), int(min(w, cx + r + 3))
        y0, y1 = int(max(0, cy - ry - 2)), int(min(h, cy + ry + 3))
        if x0 >= x1 or y0 >= y1:
            continue
        xx, yy = xx_all[y0:y1, x0:x1], yy_all[y0:y1, x0:x1]
        dx, dy = (xx - cx) / r, (yy - cy) / ry
        d = np.sqrt(dx * dx + dy * dy)
        if edge_jitter:
            theta = np.arctan2(dy, dx)
            k = rng.randint(7, 11)
            phase = rng.uniform(0, 6.28)
            bump = 1 - edge_jitter * (0.5 + 0.5 * np.cos(k * theta + phase)) ** 0.6
            inside = d < bump
            d = d / bump
        else:
            inside = d < 1
        if base_y is not None:
            inside &= yy <= base_y
        if not inside.any():
            continue
        nz = np.sqrt(np.clip(1 - d * d, 0, 1))
        L = _norm3((light_at[0] - cx, light_at[1] - cy, light_at[2]))
        v = dx * L[0] + dy * L[1] + nz * L[2]
        if global_weight:
            gdx, gdy = (xx - gcx) / grx, (yy - gcy) / gry
            gnz = np.sqrt(np.clip(1 - gdx * gdx - gdy * gdy, 0, 1))
            vg = gdx * GL[0] + gdy * GL[1] + gnz * GL[2]
            v = global_weight * vg + (1 - global_weight) * v
        if leaf_noise is not None:
            v = v + leaf_noise[y0:y1, x0:x1]
        idx = _tone(v, thresholds, xx, yy)
        col = pal[idx]
        prev = out[y0:y1, x0:x1, 3] > 0
        if crease:
            # Dark crease where this lobe sits over another, on the side away from the light
            # one tone darker than the local tone (soft fold), or a fixed crease colour
            ring = (d > 1 - 2.2 / r) & ((dx * L[0] + dy * L[1]) < 0.25) & prev
            if crease_col is None:
                col[ring] = pal[np.maximum(idx - 1, 0)][ring]
            else:
                col[ring] = crease_col
        if rim_col is not None:
            # Bright rim on the light side of the outer silhouette
            rim = (d > 1 - 1.6 / r) & ((dx * L[0] + dy * L[1]) > 0.55) & ~prev
            col[rim] = rim_col
        region = out[y0:y1, x0:x1]
        region[inside, :3] = col[inside]
        region[inside, 3] = 255
    return out


def cloud(size, lobes, sun, warm, cool, base_y=None, squash=1.0):
    """Sunset cumulus: palette blends from cool (far from the sun) to warm."""
    palette = [
        mix3(cool[0], warm[0], 0.0),
        mix3(cool[1], warm[1], 0.35),
        mix3(cool[2], warm[2], 0.7),
        warm[3],
    ]
    return render_lobes(size, lobes, sun, palette, base_y=base_y, squash=squash,
                        crease_col=None, rim_col=warm[4], global_weight=0.65)


def mix3(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


# ---------------------------------------------------------------- trees

def leaf_field(size, seed, amp=0.24, density=0.09):
    """Texture of small diagonal leaf strokes (values +/-amp) that breaks the
    cel tones into leaf clusters."""
    w, h = size
    r = np.random.default_rng(seed)
    field = np.zeros((h, w))
    n = int(w * h * density)
    xs = r.integers(0, w - 3, n)
    ys = r.integers(1, h, n)
    vals = r.choice([-amp, amp * 0.6, amp], n)
    for dx, dy in ((0, 0), (1, 0), (1, -1), (2, -1)):
        field[np.clip(ys + dy, 0, h - 1), xs + dx] = vals
    return field


def tree(size, rng, base, height, spread, light_at, palette, trunk_col, rim_col, seed=1,
         clumps=None, trunk_width=None):
    """A broadleaf tree: trunk + branches + a crown of scalloped leaf clumps.

    base: (x, y) of the trunk foot in px; height/spread in px.
    """
    w, h = size
    out = np.zeros((h, w, 4))
    bx, by = base
    crown_cy = by - height * 0.62
    trunk_width = trunk_width or max(2, int(spread * 0.07))
    # Trunk (tapered) and a few branches reaching into the crown
    from PIL import Image, ImageDraw
    timg = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    td = ImageDraw.Draw(timg)
    tw = trunk_width
    td.polygon([(bx - tw, by), (bx + tw, by), (bx + tw * 0.5, crown_cy), (bx - tw * 0.5, crown_cy)], fill=tuple(int(c) for c in trunk_col) + (255,))
    td.line([(bx + tw * 0.6, by), (bx + tw * 0.3, crown_cy)], fill=tuple(int(c) for c in rim_col) + (255,), width=1)
    for k in range(4):
        a = rng.uniform(-2.4, -0.7)
        sx, sy = bx, by - height * rng.uniform(0.35, 0.6)
        ex, ey = sx + math.cos(a) * spread * 0.45, sy + math.sin(a) * height * 0.3
        td.line([(sx, sy), (ex, ey)], fill=tuple(int(c) for c in trunk_col) + (255,), width=max(1, tw // 2))
    out = np.asarray(timg).astype(float)

    if clumps is None:
        clumps = []
        n = rng.randint(11, 15)
        for i in range(n):
            a = rng.uniform(math.pi * 0.9, math.pi * 2.1)  # mostly the upper half: a dome
            rr = rng.uniform(0.25, 1.0) ** 0.6
            cx = bx + math.cos(a) * spread * 0.4 * rr
            cy = crown_cy + math.sin(a) * height * 0.3 * rr + height * 0.06
            r = spread * rng.uniform(0.14, 0.21)
            clumps.append((cx, cy, r))
        clumps.append((bx, crown_cy + height * 0.02, spread * 0.24))  # solid core
        # back (upper) clumps first, lower/front ones last
        clumps.sort(key=lambda c: c[1])
    noise = leaf_field(size, seed)
    crown = render_clumps(size, clumps, light_at, palette, noise, rim_col, rng)
    m = crown[..., 3] > 0
    out[m] = crown[m]
    # Branches showing through the lower crown
    from PIL import Image as _I, ImageDraw as _D
    bimg = _I.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = _D.Draw(bimg)
    top = crown_cy + height * 0.12
    for k in range(3):
        ex = bx + rng.uniform(-0.3, 0.3) * spread
        ey = top - rng.uniform(0.02, 0.12) * height
        bd.line([(bx, by - height * 0.3), (bx + (ex - bx) * 0.5, top + 2), (ex, ey)], fill=tuple(int(c) for c in trunk_col) + (255,), width=max(1, trunk_width // 2))
    barr = np.asarray(bimg).astype(float)
    bm = (barr[..., 3] > 0) & (rng.random() < 2)
    lower = np.zeros_like(bm)
    lower[int(top - height * 0.12):, :] = True
    out[bm & lower] = barr[bm & lower]
    # Sky holes through the crown
    for _ in range(rng.randint(2, 4)):
        cx, cy, r = rng.choice(clumps)
        hx, hy = int(cx + rng.uniform(-r, r) * 0.5), int(cy + rng.uniform(-r, r) * 0.4)
        if 0 <= hx < w - 3 and 0 <= hy < h - 2 and out[hy, hx, 3] > 0:
            out[hy:hy + 2, hx:hx + 3, 3] = 0
    return out


def _shift(m, dy, dx):
    return np.roll(np.roll(m, dy, axis=0), dx, axis=1)


def render_clumps(size, clumps, light_at, palette, noise, rim_col, rng):
    """Leaf clumps with rounded, bumpy (scalloped) edges.

    Each clump is a core circle ringed by small circles, so its outline is a
    chain of little rounded bumps like painted foliage. Lighting uses the clump
    as one sphere (plus a bit of the whole crown), so the bumps stay part of
    one mass instead of turning into separate balls.
    """
    w, h = size
    out = np.zeros((h, w, 4))
    yy, xx = np.mgrid[0:h, 0:w]
    pal = np.array(palette, float)
    n_tones = len(palette)
    thresholds = [-0.15 + 1.25 * (i + 1) / n_tones for i in range(n_tones - 1)]
    gx = np.mean([c[0] for c in clumps])
    gy = np.mean([c[1] for c in clumps])
    gr = max(c[2] for c in clumps) * 2.2
    GL = _norm3((light_at[0] - gx, light_at[1] - gy, light_at[2]))
    for (cx, cy, r) in clumps:
        L = _norm3((light_at[0] - cx, light_at[1] - cy, light_at[2]))
        mask = (xx - cx) ** 2 + (yy - cy) ** 2 < (r * 0.8) ** 2
        k = max(7, int(r * 0.7))
        for i in range(k):
            a = (i + rng.uniform(-0.3, 0.3)) * 2 * math.pi / k
            rs = r * rng.uniform(0.22, 0.32)
            sx, sy = cx + math.cos(a) * r * 0.74, cy + math.sin(a) * r * 0.74
            mask |= (xx - sx) ** 2 + (yy - sy) ** 2 < rs * rs
        dx, dy = (xx - cx) / r, (yy - cy) / r
        dd = np.clip(dx * dx + dy * dy, 0, 1)
        nz = np.sqrt(1 - dd)
        v = dx * L[0] + dy * L[1] + nz * L[2]
        gdx, gdy = (xx - gx) / gr, (yy - gy) / gr
        vg = gdx * GL[0] + gdy * GL[1] + np.sqrt(np.clip(1 - gdx * gdx - gdy * gdy, 0, 1)) * GL[2]
        v = 0.75 * v + 0.25 * vg + noise
        idx = _tone(v, thresholds, xx, yy)
        col = pal[idx]
        prev = out[..., 3] > 0
        inner = mask & _shift(mask, 1, 0) & _shift(mask, -1, 0) & _shift(mask, 0, 1) & _shift(mask, 0, -1)
        edge = mask & ~inner
        facing = dx * L[0] + dy * L[1]
        crease = edge & prev & (facing < 0.3)
        col[crease] = pal[np.maximum(idx - 2, 0)][crease]
        rim = edge & ~prev & (facing > 0.45)
        col[rim] = rim_col
        out[mask, :3] = col[mask]
        out[mask, 3] = 255
    return out
