"""Draw the school courtyard in front of the 2.5D building (pixel art) and write its layout.

Everything is drawn as the design camera sees it (the same picture space as the building's paint:
24 px per metre on the facade plane, scripts/school_building_3d.gd), one game pixel per texel, then
laid on boxes and cards at real depths by scripts/school_courtyard_3d.gd, which paints them with
shaders/projected_paint.gdshader just like the building. So at rest the picture is exactly what is
drawn here, and a turned view slides the pieces over each other.

In front of the block (world metres: facade z 0, entrance x 0, camera at z 30, eyes 1.6 m):
  - wet concrete apron with a drain grating along the wall, rain puddles
  - a covered walkway along the block: one row of steel posts (each in the middle of a classroom bay
    as seen from the camera, downpipes on every other one), roof cantilevered both ways, blue sheet
    edge and gutter; polished cement floor under it
  - low shrubs in a planter strip before the classrooms, a trimmed box hedge along the lawn
  - lawn (mowing stripes, wet) with a paved path out from the entrance, a bench on each side
Hedge and lawn follow photo references of clipped hedges and mown lawns and saint11's vegetation
pixel-art notes (few tones, one leaf motif, detail on the edges, calm areas, no stray pixels).
Leaves are the author's (art_source/school_trees_rain.png: the small bush and a dense patch of a crown)
so they match the painted trees; the rest is drawn here.

Usage:
  python3 tools/make_courtyard.py art_source/school_trees_rain.png assets/bg/school/courtyard
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, map_coordinates

D, EYE, PPM = 30.0, 1.6, 24.0
OX, OY = 1083.5 * 0.48, 668.0 * 0.48          # picture pixel of world x 0, y 0 on the facade plane
BUSH = (1150, 150, 1527, 293)                   # the author's bush (source px)
LEAFAGE = (400, 0, 570, 95)                     # a dense patch of the author's crown, no branches (source px)


def k(z):
    return D / (D - z)


def pic(x, y, z):
    """World point -> picture pixel (u, v) as the design camera sees it."""
    s = k(z)
    return OX + x * s * PPM, OY - (EYE + (y - EYE) * s) * PPM


class Layer:
    """One paint image (cropped to what it covers) and the faces that carry it."""

    def __init__(self, name, x0, x1, y0, y1, z):
        u0, v0 = pic(x0, y1, z)
        u1, v1 = pic(x1, y0, z)
        self.set_box(name, u0, v0, u1, v1)

    def set_box(self, name, u0, v0, u1, v1, pad=2):
        self.name = name
        self.u0, self.v0 = int(np.floor(u0)) - pad, int(np.floor(v0)) - pad
        w, h = int(np.ceil(u1)) - self.u0 + pad, int(np.ceil(v1)) - self.v0 + pad
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.faces = []

    def local(self, u, v):
        return u - self.u0, v - self.v0

    def rect(self, x0, x1, y0, y1, z):
        """Picture rectangle (local px) of a front face."""
        u0, v0 = self.local(*pic(x0, y1, z))
        u1, v1 = self.local(*pic(x1, y0, z))
        return u0, v0, u1, v1

    def face(self, kind, **kw):
        self.faces.append(dict(type=kind, **kw))

    def save(self, out):
        self.img.save(os.path.join(out, self.name + ".png"))
        return {"paint": self.name, "origin": [OX - self.u0, OY - self.v0], "faces": self.faces}


# ---------------------------------------------------------------- leaves

def load_bush(path):
    return Image.open(path).convert("RGBA").crop(BUSH)


def load_leafage(path, scale):
    """Dense leaves from the author's crown, scaled, mirror-tiled large (mirrored copies hide seams)."""
    src = Image.open(path).convert("RGBA").crop(LEAFAGE)
    src = src.resize((round(src.width * scale), round(src.height * scale)), Image.LANCZOS)
    a = np.asarray(src)
    row = np.concatenate([a, a[:, ::-1]], 1)
    block = np.concatenate([row, row[::-1]], 0)
    return np.tile(block, (3, 12, 1)).astype(float)


def stamp(bush, width, flip, tone):
    """The author's bush scaled to `width` px and tinted (tone < 1 darker)."""
    h = max(2, round(bush.height * width / bush.width))
    s = bush.convert("RGBa").resize((max(2, round(width)), h), Image.LANCZOS).convert("RGBA")
    if flip:
        s = s.transpose(Image.FLIP_LEFT_RIGHT)
    a = np.asarray(s).astype(float)
    a[..., :3] *= tone
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def foliage(bush, img, cx, cy, rx, ry, n, size, seed=0):
    """Shrub: stamps scattered in an ellipse, bottom ones first and darker, top-left lighter."""
    rng = np.random.default_rng(seed)
    pts = []
    for _ in range(n):
        a, r = rng.uniform(0, 2 * np.pi), np.sqrt(rng.uniform(0, 1))
        pts.append((cx + np.cos(a) * r * rx, cy + np.sin(a) * r * ry))
    pts.sort(key=lambda p: -p[1])
    for x, y in pts:
        nx, ny = (x - cx) / rx, (y - cy) / ry
        tone = (0.95 - 0.28 * (0.6 * nx + 0.8 * ny)) * rng.uniform(0.9, 1.05)
        s = stamp(bush, size * rng.uniform(0.75, 1.25), rng.random() < 0.5, max(0.45, min(1.3, tone)))
        img.alpha_composite(s, (int(x - s.width / 2), int(y - s.height * 0.6)))


# ---------------------------------------------------------------- ground

class Noise:
    """Smooth random fields over the ground (world x, z), sampled bilinearly."""
    X0, X1, Z0, Z1, CELL = -46.0, 46.0, 0.0, 25.0, 0.04

    def __init__(self, seed):
        rng = np.random.default_rng(seed)
        nx, nz = int((self.X1 - self.X0) / self.CELL), int((self.Z1 - self.Z0) / self.CELL)
        self.base = rng.normal(0, 1, (nz, nx))
        self.cache = {}

    def field(self, sx, sz):
        key = (sx, sz)
        if key not in self.cache:
            f = gaussian_filter(self.base, (sz / self.CELL, sx / self.CELL), mode="wrap")
            self.cache[key] = f / f.std()
        return self.cache[key]

    def __call__(self, x, z, sx, sz):
        f = self.field(sx, sz)
        coords = [(z - self.Z0) / self.CELL, (x - self.X0) / self.CELL]
        return map_coordinates(f, coords, order=1, mode="nearest")


def lerp(a, b, t):
    return a + (np.asarray(b, float) - a) * t[..., None]


def ground_colour(x, z, noise):
    c = np.zeros(x.shape + (3,))
    coarse = noise(x, z, 0.9, 0.9)
    fine = noise(x, z, 0.06, 0.12)
    pud = noise(x, z, 0.5, 0.35)
    sky = np.array([150, 160, 180])
    drain = z < 0.35
    apron = (z >= 0.35) & (z < 3.9)
    under = (z >= 3.9) & (z < 6.9)
    curb = (z >= 6.9) & (z < 7.15)
    path = (z >= 7.15) & (np.abs(x) < 1.6)
    edging = path & (np.abs(x) > 1.48)
    lawn = (z >= 7.15) & ~path
    # drain grating along the wall
    c[drain] = [50, 56, 70]
    c[drain & (np.abs(((x * 8) % 1.0) - 0.5) < 0.18)] = [34, 38, 50]
    # apron: wet concrete slabs, joints, stains
    slab = np.array([116, 124, 140]) * (1 + 0.05 * coarse + 0.025 * fine)[..., None]
    c[apron] = slab[apron]
    joint = (np.abs(((x + 0.5) % 1.0) - 0.5) < 0.022) | (np.abs(((z - 0.35) % 1.2) - 0.6) > 0.575)
    c[apron & joint] = (slab * 0.8)[apron & joint]
    # under the walkway: polished cement, darker, faint tiles
    cement = np.array([100, 108, 126]) * (1 + 0.03 * coarse)[..., None]
    c[under] = cement[under]
    tj = (np.abs(((x + 0.25) % 0.5) - 0.25) < 0.012) | (np.abs(((z - 3.9) % 0.5) - 0.25) > 0.235)
    c[under & tj] = (cement * 0.88)[under & tj]
    # curb, with a wet dark drip line from the gutter
    c[curb] = [140, 146, 162]
    c[curb & (z < 7.0)] = [104, 110, 126]
    # path: pavers 0.5 x 0.25 m in running bond, kerb edging
    row = np.floor((z - 7.15) / 0.25)
    off = (row % 2) * 0.25
    pj = (np.abs(((z - 7.15) % 0.25) - 0.125) > 0.108) | (np.abs(((x + off) % 0.5) - 0.25) > 0.238)
    paver = np.array([114, 118, 134]) * (1 + 0.05 * coarse + 0.04 * fine)[..., None]
    c[path] = paver[path]
    c[path & pj] = (paver * 0.76)[path & pj]
    c[edging] = [138, 144, 158]
    # lawn: wet, clumpy, mowing stripes along z, damp shadow at the hedge foot
    t = np.clip(0.5 + 0.22 * coarse + 0.28 * fine, 0, 1)
    dark, mid, light = np.array([32, 54, 56]), np.array([48, 78, 74]), np.array([72, 102, 86])
    g = np.where(t[..., None] < 0.5, lerp(dark, mid, t / 0.5), lerp(mid, light, (t - 0.5) / 0.5))
    g *= np.where((np.floor((x + 0.75) / 1.5) % 2) == 0, 1.05, 0.95)[..., None]
    g *= np.clip((z - 7.15) / 0.6, 0.75, 1.0)[..., None]
    c[lawn] = g[lawn]
    # puddles on hard ground reflect the grey sky, with a darker wet rim
    hard = apron | path | curb
    c[hard & (pud > 1.15)] = lerp(c, sky, np.full(x.shape, 0.55))[hard & (pud > 1.15)]
    rim = hard & (pud > 1.0) & (pud <= 1.15)
    c[rim] = (c * 0.86)[rim]
    # bench shadows
    s = np.ones(x.shape)
    for b in BENCHES:
        dist = ((x - b["x"]) / 1.05) ** 2 + ((z - b["z"]) / 0.4) ** 2
        s *= 1 - 0.35 * np.clip(1.0 - dist, 0, 1)
    return c * s[..., None]


def make_ground(out_layers, out):
    # picture rows from the facade's foot (z 0) down past the frame (z ~19)
    u0, u1 = OX - 33 * PPM, OX + 33 * PPM
    v0, v1 = OY, OY + 74
    lay = Layer.__new__(Layer)
    lay.set_box("ground", u0, v0, u1, v1, pad=0)
    w, h = lay.img.size
    ss = 4
    uu, vv = np.meshgrid((np.arange(w * ss) + 0.5) / ss + lay.u0, (np.arange(h * ss) + 0.5) / ss + lay.v0)
    ys = (OY - vv) / PPM                                # screen height on the facade plane
    s = (EYE - ys) / EYE
    z = D * (1 - 1 / np.maximum(s, 1e-6))
    x = (uu - OX) / PPM / np.maximum(s, 1e-6)
    col = ground_colour(x, z, Noise(7))
    col = col.reshape(h, ss, w, ss, 3).mean((1, 3))
    lawn = (((z >= 7.15) & (np.abs(x) >= 1.6)).reshape(h, ss, w, ss).mean((1, 3)) > 0.5)
    zc = z.reshape(h, ss, w, ss).mean((1, 3))
    xc = x.reshape(h, ss, w, ss).mean((1, 3))
    col = pixel_lawn(col, lawn, xc, zc)
    a = np.full((h, w), 255, np.uint8)
    lay.img = Image.fromarray(np.dstack([np.clip(col, 0, 255).astype(np.uint8), a]))
    lay.face("y", x0=-45.0, x1=45.0, y=0.0, z0=0.0, z1=24.0)
    out_layers.append(lay.save(out))


GREENS = np.array([[28, 48, 50], [38, 64, 62], [50, 80, 74], [64, 96, 82], [86, 118, 94], [110, 140, 106]])
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def pixel_lawn(col, lawn, x, z):
    """Lawn as pixel art (references: mown school lawns): mostly calm broad greens with faint mowing
    stripes, dither only where tones meet; grass tufts mainly along the borders (hedge foot, path
    kerb) where detail and contrast belong, a few small clusters inside, longer toward the camera."""
    h, w = lawn.shape
    rng = np.random.default_rng(21)
    near = np.clip((z - 7.0) / 11.0, 0, 1)                      # 0 at the hedge .. 1 near the camera
    noise = Noise(31)
    patch = noise(x, z, 2.0, 3.0)
    stripe = np.where((np.floor((x + 0.9) / 1.8) % 2) == 0, 0.12, -0.12)
    level = 2.4 - 0.6 * near + 0.3 * patch + stripe
    level -= 1.0 * np.clip(1 - (z - 7.15) / 0.45, 0, 1)        # damp shade at the hedge foot
    vv, uu = np.mgrid[0:h, 0:w]
    idx = np.floor(level + (BAYER[vv % 4, uu % 4] - 0.5) * 0.45).astype(int)
    out = col.copy()
    out[lawn] = GREENS[np.clip(idx, 1, 3)][lawn]
    edge_d = np.minimum(np.abs(np.abs(x) - 1.6), z - 7.15)     # metres from the nearest border
    ys, xs = np.nonzero(lawn)
    border = np.exp(-edge_d[ys, xs] / 0.25)
    cluster = np.clip(noise(x, z, 0.6, 0.9)[ys, xs] - 1.2, 0, 1)
    keep = rng.random(len(ys)) < 0.22 * border + 0.05 * cluster
    ys, xs = ys[keep], xs[keep]
    for i in np.argsort(ys):
        v, u = ys[i], xs[i]
        nr = near[v, u]
        length = int(np.clip(round(1.5 + 3.0 * nr * rng.uniform(0.7, 1.2)), 2, 5))
        lean = (-1 if x[v, u] > 0 else 1) if abs(x[v, u]) < 1.85 else 0
        blades = [(0, length, lean)]
        if length >= 3:
            blades += [(-1, length - 1, -1 + lean), (1, length - 1, 1 + lean)]
        for du, ln, bend in blades:
            for j in range(ln):
                vy = v - j
                ux = u + du + (bend if j >= ln - 1 and ln > 2 else 0)
                if 0 <= vy < h and 0 <= ux < w:
                    out[vy, ux] = GREENS[1] if j == 0 else GREENS[4] if j == ln - 1 else GREENS[3]
    return out


# ---------------------------------------------------------------- covered walkway

WALK = dict(x0=-24.0, x1=24.0, under=2.65, top=3.0, front=6.9, back=3.9, posts=6.3, post=0.2)
BAYS_PX = [240.5, 524.0, 798.0, 1367.5, 1642.0, 1925.5]      # classroom bay centres on the facade (src px)
SHEET, SHEET_LIT, SHEET_DARK = (62, 88, 140, 255), (104, 130, 180, 255), (44, 62, 102, 255)
STEEL, STEEL_LIT, STEEL_DARK = (122, 134, 158, 255), (168, 178, 198, 255), (82, 92, 116, 255)


def post_xs():
    """One post per classroom bay, placed so the camera sees it in the middle of the bay."""
    kk = k(WALK["posts"])
    xs = [(b - 1083.5) / 50.0 / kk for b in BAYS_PX]
    step = xs[-1] - xs[-2]
    while xs[-1] + step < WALK["x1"] - 0.5:
        xs.append(xs[-1] + step)
        xs.insert(0, xs[0] - step)
    return xs


def make_walkway(out_layers, out):
    W = WALK
    roof = Layer("walk_roof", W["x0"], W["x1"], W["under"], W["top"], W["front"])
    d = ImageDraw.Draw(roof.img)
    u0, v0, u1, v1 = roof.rect(W["x0"], W["x1"], W["under"], W["top"], W["front"])
    vu = roof.local(*pic(0, W["under"], W["back"]))[1]
    v0, v1, vu = round(v0), round(v1), round(vu)
    # underside, seen from below: dark, a purlin over the posts, lamps between them
    d.rectangle([u0, v1, u1, max(v1 + 1, vu)], fill=(58, 66, 86, 255))
    vp = round(roof.local(*pic(0, W["under"], W["posts"]))[1])
    d.line([u0, vp, u1, vp], fill=(76, 84, 104, 255))
    xs = post_xs()
    for a_x, b_x in zip(xs, xs[1:]):
        mid = (a_x + b_x) / 2
        a = roof.local(*pic(mid - 0.3, W["under"], W["posts"]))[0]
        b = roof.local(*pic(mid + 0.3, W["under"], W["posts"]))[0]
        d.line([a, vp, b, vp], fill=(206, 214, 226, 255))
    # front: corrugated blue sheet ends on top, then the gutter (lit lip, round body, dark underside)
    sheet = v0 + max(2, round((v1 - v0) * 0.4))
    d.rectangle([u0, v0, u1, sheet], fill=SHEET)
    for uu in np.arange(u0, u1, 3):
        d.line([uu, v0 + 1, uu, sheet], fill=SHEET_LIT)
        d.point([uu + 1, sheet], fill=SHEET_DARK)
    d.line([u0, v0, u1, v0], fill=(128, 152, 198, 255))
    d.rectangle([u0, sheet + 1, u1, v1], fill=(126, 138, 160, 255))
    d.line([u0, sheet + 1, u1, sheet + 1], fill=(184, 194, 210, 255))
    d.line([u0, v1 - 1, u1, v1 - 1], fill=(98, 108, 130, 255))
    d.line([u0, v1, u1, v1], fill=(64, 72, 92, 255))
    roof.face("z", x0=W["x0"], x1=W["x1"], y0=W["under"], y1=W["top"], z=W["front"])
    roof.face("y", x0=W["x0"], x1=W["x1"], y=W["under"], z0=W["front"], z1=W["back"])
    out_layers.append(roof.save(out))

    z, half = W["posts"], W["post"] / 2
    posts = Layer("walk_posts", W["x0"], W["x1"], 0.0, W["under"], z)
    d = ImageDraw.Draw(posts.img)
    for i, x in enumerate(xs):
        a, b, c, e = (round(v) for v in posts.rect(x - half, x + half, 0.0, W["under"], z))
        d.rectangle([a, b, c, e], fill=STEEL)
        d.line([a, b, a, e], fill=STEEL_LIT)
        d.line([c, b, c, e], fill=STEEL_DARK)
        d.line([a, b, c, b], fill=STEEL_DARK)                     # bracket shadow under the roof
        if i % 2 == 0:                                             # downpipe from the gutter
            d.line([c + 1, b, c + 1, e - 1], fill=(150, 160, 180, 255))
            d.point([c + 1, e - 1], fill=(96, 104, 124, 255))
        fa, fb, fc, fe = (round(v) for v in posts.rect(x - 0.17, x + 0.17, 0.0, 0.25, z + 0.07))
        d.rectangle([fa, fb, fc, fe], fill=(132, 138, 152, 255))  # concrete footing
        d.line([fa, fb, fc, fb], fill=(164, 170, 182, 255))
        posts.face("box", x0=x - half, x1=x + half, y0=0.0, y1=W["under"], zf=z, zb=z - W["post"])
        posts.face("box", x0=x - 0.17, x1=x + 0.17, y0=0.0, y1=0.25, zf=z + 0.07, zb=z - 0.27)
    out_layers.append(posts.save(out))


# ---------------------------------------------------------------- shrubs, hedge, benches

def make_planters(bush, out_layers, out):
    z = 3.0
    for side in (-1, 1):
        x0, x1 = (3.4, 10.4) if side > 0 else (-10.4, -3.4)
        lay = Layer("planter_" + ("r" if side > 0 else "l"), x0 - 0.3, x1 + 0.3, 0.0, 0.9, z)
        u0, v0, u1, v1 = lay.rect(x0, x1, 0.0, 0.6, z)
        d = ImageDraw.Draw(lay.img)
        d.rectangle([u0, v1 - 4, u1, v1], fill=(96, 104, 122, 255))                   # planter kerb
        d.line([u0, v1 - 4, u1, v1 - 4], fill=(140, 148, 164, 255))
        for cx in np.arange(u0 + 6, u1 - 4, 13):
            foliage(bush, lay.img, cx, v1 - 9, 8, 5, 4, 15, seed=int(cx) + side * 7)
        lay.face("z", x0=x0 - 0.3, x1=x1 + 0.3, y0=0.0, y1=0.9, z=z)
        out_layers.append(lay.save(out))


def quilt(leaves, w, h, rng, block=30, overlap=10):
    """Leaf texture for a long hedge: random patches (random flips) cross-faded side by side."""
    out = np.zeros((h, w, 4))
    weight = np.zeros((h, w, 1))
    ramp = np.minimum(1, np.minimum(np.arange(block + overlap) + 1, block + overlap - np.arange(block + overlap)) / overlap)
    for u in range(-overlap, w, block):
        oy = int(rng.integers(0, leaves.shape[0] - h))
        ox = int(rng.integers(0, leaves.shape[1] - block - overlap))
        p = leaves[oy:oy + h, ox:ox + block + overlap]
        if rng.random() < 0.5:
            p = p[:, ::-1]
        a, b = max(0, u), min(w, u + block + overlap)
        r = ramp[a - u:b - u][None, :, None]
        out[:, a:b] += p[:, a - u:b - u] * r
        weight[:, a:b] += r
    return out / np.maximum(weight, 1e-6)


HEDGE = dict(front=7.95, back=7.3, h=0.85, gap=1.95, end=24.0)
# trimmed hedge in the rain: highlight, light, base, shadow, dark (few colours: pixel-art rule)
HEDGE_TONES = np.array([[118, 146, 106], [86, 116, 88], [58, 88, 72], [40, 64, 58], [26, 42, 44]])
# one small leaf motif used everywhere on the hedge (consistent leaf pattern)
LEAF = np.array([[0, 1, 0],
                 [1, 1, 1],
                 [0, 0, 1]])


def make_hedge(path, out_layers, out):
    """Trimmed box hedge (references: clipped ficus/duranta hedges): softly rounded top edge lit by
    the sky, front face darkening toward the foot, dark gap at the ground. Pixel-art rules: five
    tones, one repeated leaf motif, detail on the edges, calm areas inside, no stray pixels."""
    H = HEDGE
    rng = np.random.default_rng(5)
    for side in (-1, 1):
        x0, x1 = (H["gap"], H["end"]) if side > 0 else (-H["end"], -H["gap"])
        lay = Layer("hedge_" + ("r" if side > 0 else "l"), x0, x1, 0.0, H["h"] + 0.1, H["front"])
        w, h = lay.img.size
        u0, v0, u1, v1 = (round(v) for v in lay.rect(x0, x1, 0.0, H["h"], H["front"]))
        vt = round(lay.local(*pic(0, H["h"], H["back"]))[1])        # back edge of the top face
        top = min(vt, v0)
        tone = np.full((h, w), -1)
        rows = v1 - top
        # profile: top face + rounded edge = highlight/light, then base, shadow, dark foot
        # tone borders wander a pixel or two (leaf clumps), not ruler-straight lines
        wob = [np.round(gaussian_filter(rng.normal(0, 1, w), 2.5) * 2.2).astype(int) for _ in range(4)]
        cuts = [0.1, 0.28, 0.7, 0.93]
        for uu in range(u0, u1 + 1):
            for v in range(top, v1 + 1):
                t = 0
                for i, c in enumerate(cuts):
                    if v - top >= round(c * rows) + (wob[i][uu] if i < 3 else 0):
                        t = i + 1
                tone[v, uu] = t
        # rounded ends at the path: cut the corners (radius 3 px top, 1 px foot)
        for cu, dirn in ((u0, 1), (u1, -1)):
            for i, cut in enumerate((3, 2, 1)):
                tone[top + i, cu: cu + dirn * cut: dirn] = -1
            tone[v1, cu] = -1
            # the end face catches less light
            for v in range(top, v1 + 1):
                if tone[v, cu] >= 0:
                    tone[v, cu] = min(4, tone[v, cu] + 1)
        # leafy top edge: small leaf tips standing above the cut line, regular-ish spacing
        u = u0 + 3
        while u < u1 - 3:
            tone[top - 1, u] = 0
            if rng.random() < 0.4:
                tone[top - 1, u + 1] = 0
            u += int(rng.integers(3, 6))
        # leaf motifs: highlights scattered in the light band, shadows clustered in the base band,
        # dense near the edges and the ends, few in the middle (calm areas)
        def motif(cu, cv, t):
            for dv in range(3):
                for du in range(3):
                    if LEAF[dv, du]:
                        vv, uu = cv + dv, cu + du
                        if 0 <= vv < h and 0 <= uu < w and tone[vv, uu] >= 0:
                            tone[vv, uu] = t
        band = lambda f: top + round(f * rows)
        for _ in range((u1 - u0) // 3):
            motif(int(rng.integers(u0, u1 - 2)), band(rng.uniform(0.12, 0.3)), 0)        # lit leaves
        calm = gaussian_filter(rng.random(w), 12)
        calm = (calm - calm.min()) / (calm.max() - calm.min() + 1e-6)
        for _ in range((u1 - u0) // 4):
            cu = int(rng.integers(u0, u1 - 2))
            if rng.random() < 0.35 + 0.65 * calm[cu]:
                motif(cu, band(rng.uniform(0.35, 0.65)), 3)                                # shadow pockets
                if rng.random() < 0.5:
                    motif(cu + 1, band(rng.uniform(0.3, 0.45)), 1)                         # lit leaf above
        for _ in range((u1 - u0) // 5):
            motif(int(rng.integers(u0, u1 - 2)), band(rng.uniform(0.72, 0.85)), 4)        # deep shade low
        img = np.zeros((h, w, 4), np.uint8)
        on = tone >= 0
        img[on, :3] = HEDGE_TONES[tone[on]]
        img[on, 3] = 255
        lay.img = Image.fromarray(img)
        lay.face("box", x0=x0, x1=x1, y0=0.0, y1=H["h"] + 0.1, zf=H["front"], zb=H["back"])
        lay.face("y", x0=x0, x1=x1, y=H["h"], z0=H["front"], z1=H["back"])
        out_layers.append(lay.save(out))


BENCHES = [dict(name="bench_l", x=-5.6, z=10.6), dict(name="bench_r", x=6.2, z=11.4)]
WOOD, WOOD_LIT, WOOD_DARK = (134, 90, 60, 255), (170, 122, 84, 255), (92, 60, 44, 255)
IRON, IRON_LIT = (40, 46, 62, 255), (76, 84, 104, 255)


def make_bench(b, out_layers, out):
    """Park bench, slatted wood on cast-iron ends, a little seen from above."""
    x, z, w = b["x"], b["z"], 1.8
    lay = Layer(b["name"], x - w / 2 - 0.1, x + w / 2 + 0.1, 0.0, 0.95, z)
    d = ImageDraw.Draw(lay.img)
    u0, v0, u1, v1 = (round(v) for v in lay.rect(x - w / 2, x + w / 2, 0.0, 0.88, z))
    m = k(z) * PPM
    seat = round(v1 - 0.45 * m)
    # backrest: three slats with gaps
    slat = max(2, round(0.09 * m))
    for i in range(3):
        y = v0 + 1 + i * (slat + max(1, round(0.04 * m)))
        d.rectangle([u0 + 1, y, u1 - 1, y + slat - 1], fill=WOOD)
        d.line([u0 + 1, y, u1 - 1, y], fill=WOOD_LIT)
        d.line([u0 + 1, y + slat - 1, u1 - 1, y + slat - 1], fill=WOOD_DARK)
    # seat: lit top, front edge, shadow under it
    d.rectangle([u0, seat - 2, u1, seat - 1], fill=WOOD_LIT)
    d.rectangle([u0, seat, u1, seat + 1], fill=WOOD)
    d.line([u0, seat + 2, u1, seat + 2], fill=WOOD_DARK)
    # cast-iron ends: back post, arm rest, front leg, feet
    for e in (u0 + 2, u1 - 3):
        d.rectangle([e, v0, e + 1, v1], fill=IRON)
        d.point([e, v0], fill=IRON_LIT)
        d.line([e - 2, seat - 3, e + 3, seat - 3], fill=IRON)
        d.line([e - 1, seat + 3, e - 1, v1], fill=IRON)
        d.line([e - 1, v1, e + 2, v1], fill=IRON)
    lay.face("z", x0=x - w / 2 - 0.1, x1=x + w / 2 + 0.1, y0=0.0, y1=0.95, z=z)
    out_layers.append(lay.save(out))


def main():
    bush = load_bush(sys.argv[1])
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    layers = []
    make_ground(layers, out)
    make_planters(bush, layers, out)
    make_walkway(layers, out)
    make_hedge(sys.argv[1], layers, out)
    for b in BENCHES:
        make_bench(b, layers, out)
    with open(os.path.join(out, "courtyard.json"), "w") as f:
        json.dump({"px_per_m": PPM, "layers": layers}, f, indent=1)
    print(f"{len(layers)} layers -> {out}")


if __name__ == "__main__":
    main()
