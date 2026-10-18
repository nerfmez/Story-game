"""Draw the school courtyard in front of the 2.5D building (pixel art) and write its layout.

Everything is drawn as the design camera sees it (the same picture space as the building's paint:
24 px per metre on the facade plane, scripts/school_building_3d.gd), one game pixel per texel, then
laid on boxes and cards at real depths by scripts/school_courtyard_3d.gd, which paints them with
shaders/projected_paint.gdshader just like the building. So at rest the picture is exactly what is
drawn here, and a turned view slides the pieces over each other.

In front of the block (world metres: facade z 0, entrance x 0, camera at z 30, eyes 1.6 m):
  - concrete apron with a drain along the wall (z 0-3.9), polished cement under the walkway
  - a covered walkway along the block (z 3.9-6.6): steel posts, metal roof with its front flashing
  - low shrubs in a planter strip before the classrooms (z 3), a trimmed hedge along the lawn (z 7.9)
  - lawn with a paved path out from the entrance, two shade trees, a bench under each
Leaves are stamped from the author's bush (art_source/school_trees_rain.png, the small bush in the
middle) so they match the painted trees; the rest is drawn here.

Usage:
  python3 tools/make_courtyard.py art_source/school_trees_rain.png assets/bg/school/courtyard
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter

D, EYE, PPM = 30.0, 1.6, 24.0
OX, OY = 1083.5 * 0.48, 668.0 * 0.48          # picture pixel of world x 0, y 0 on the facade plane
BUSH = (1150, 150, 1527, 293)                   # the author's bush (source px)

RNG = np.random.default_rng(15)


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
    src = Image.open(path).convert("RGBA").crop(BUSH)
    return src


def stamp(bush, width, flip, tone):
    """The author's bush scaled to `width` px, tinted (tone < 1 darker, > 1 lighter, toward teal-green)."""
    h = max(2, round(bush.height * width / bush.width))
    s = bush.convert("RGBa").resize((max(2, round(width)), h), Image.LANCZOS).convert("RGBA")
    if flip:
        s = s.transpose(Image.FLIP_LEFT_RIGHT)
    a = np.asarray(s).astype(float)
    a[..., :3] *= tone
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def foliage(bush, img, cx, cy, rx, ry, n, size, light=(-0.6, -0.8), seed=0, flat_bottom=None):
    """Crown/shrub: stamps scattered in an ellipse, bottom ones first and darker, top-left lighter."""
    rng = np.random.default_rng(seed)
    pts = []
    while len(pts) < n:
        a, r = rng.uniform(0, 2 * np.pi), np.sqrt(rng.uniform(0, 1))
        x, y = cx + np.cos(a) * r * rx, cy + np.sin(a) * r * ry
        if flat_bottom is not None and y > flat_bottom:
            continue
        pts.append((x, y))
    pts.sort(key=lambda p: -p[1])                      # lower clumps first: upper ones overlap them
    for x, y in pts:
        nx, ny = (x - cx) / rx, (y - cy) / ry
        tone = 0.95 + 0.28 * -(nx * light[0] + ny * light[1]) / 1.0
        tone *= rng.uniform(0.9, 1.05)
        w = size * rng.uniform(0.75, 1.25)
        s = stamp(bush, w, rng.random() < 0.5, max(0.45, min(1.3, tone)))
        img.alpha_composite(s, (int(x - s.width / 2), int(y - s.height * 0.6)))


# ---------------------------------------------------------------- ground

def grass(x, z):
    """Lawn colour at world (x, z) (arrays): dark wet teal-green, streaky clumps."""
    n1 = np.sin(x * 9.1 + np.sin(z * 2.3) * 3) * np.sin(z * 3.7 + x * 1.3)
    n2 = np.sin(x * 23.0 + z * 5.1) * np.sin(x * 4.0 - z * 9.3)
    t = 0.5 + 0.3 * n1 + 0.2 * n2
    dark, mid, light = np.array([34, 58, 58]), np.array([50, 82, 76]), np.array([74, 106, 88])
    c = np.where(t[..., None] < 0.5, dark + (mid - dark) * (t[..., None] / 0.5),
                 mid + (light - mid) * ((t[..., None] - 0.5) / 0.5))
    return c


def ground_colour(x, z):
    c = np.zeros(x.shape + (3,))
    apron = (z < 3.9)
    under = (z >= 3.9) & (z < 6.6)
    curb = (z >= 6.6) & (z < 6.9)
    path = (z >= 6.9) & (np.abs(x) < 1.6)
    lawn = (z >= 6.9) & ~path
    # apron: wet concrete slabs 1 m, joints, darker drain grating along the wall
    base = np.array([118, 126, 142])
    joint = ((np.abs(((x + 0.5) % 1.0) - 0.5) < 0.025) | (np.abs(((z - 0.5) % 1.2) - 0.6) < 0.03))
    sheen = 1.0 + 0.06 * np.sin(x * 0.9 + z * 0.4)
    c[apron] = (base * sheen[..., None])[apron]
    c[apron & joint] = [92, 100, 118]
    drain = z < 0.35
    c[drain] = [52, 58, 72]
    c[drain & (np.abs(((x * 8) % 1.0) - 0.5) < 0.18)] = [36, 40, 52]
    # walkway: polished cement, faint 0.5 m tiles, a little reflection of the roof edge
    c[under] = [104, 112, 130]
    tj = (np.abs(((x + 0.25) % 0.5) - 0.25) < 0.012) | (np.abs(((z - 3.9) % 0.5) - 0.25) < 0.015)
    c[under & tj] = [90, 96, 114]
    c[curb] = [146, 152, 166]
    # path: pavers 0.5 x 0.25 m in running bond
    row = np.floor((z - 6.9) / 0.25)
    off = (row % 2) * 0.25
    pj = (np.abs(((z - 6.9) % 0.25) - 0.125) > 0.105) | (np.abs(((x + off) % 0.5) - 0.25) > 0.235)
    c[path] = [116, 120, 136]
    c[path & pj] = [86, 90, 104]
    c[path & (np.abs(np.abs(x) - 1.6) < 0.06)] = [140, 146, 160]
    c[lawn] = grass(x, z)[lawn]
    # soft shade under the tree crowns and the benches
    shade = np.ones(x.shape)
    for t in TREES:
        r = t["crown"] / 2
        dist = ((x - t["x"]) / r) ** 2 + ((z - t["z"]) / (r * 0.8)) ** 2
        shade *= 1 - 0.32 * np.clip(1.2 - dist, 0, 1)
    for b in BENCHES:
        dist = ((x - b["x"]) / 1.1) ** 2 + ((z - b["z"]) / 0.45) ** 2
        shade *= 1 - 0.3 * np.clip(1.0 - dist, 0, 1)
    return c * shade[..., None]


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
    col = ground_colour(x, z)
    col = col.reshape(h, ss, w, ss, 3).mean((1, 3))
    a = np.full((h, w), 255, np.uint8)
    lay.img = Image.fromarray(np.dstack([np.clip(col, 0, 255).astype(np.uint8), a]))
    lay.face("y", x0=-45.0, x1=45.0, y=0.0, z0=0.0, z1=24.0)
    out_layers.append(lay.save(out))


# ---------------------------------------------------------------- covered walkway

POSTS = [2.3, 6.0, 9.7, 13.4, 17.1, 20.8]
WALK = dict(x0=-24.0, x1=24.0, roof=2.7, top=3.1, front=6.6, back=3.9, post=0.15)


def make_walkway(out_layers, out):
    W = WALK
    # roof: flashing (front face) + underside band, one layer
    roof = Layer("walk_roof", W["x0"], W["x1"], W["roof"], W["top"], W["front"])
    d = ImageDraw.Draw(roof.img)
    u0, v0, u1, v1 = roof.rect(W["x0"], W["x1"], W["roof"], W["top"], W["front"])
    _, vb, _, _ = roof.rect(W["x0"], W["x1"], W["roof"], W["roof"], W["front"] - 0.15)
    ub0, vu, ub1, _ = roof.rect(W["x0"], W["x1"], W["roof"], W["roof"], W["back"])
    # underside (seen from below, ends lower on screen at the back)
    d.rectangle([u0, v1, u1, max(v1, vu) + 1], fill=(66, 74, 94, 255))
    d.line([u0, v1 + 1, u1, v1 + 1], fill=(82, 90, 110, 255))
    # front: blue metal sheet edge on top (corrugation ends), then the gutter, shadow line under it
    sheet = v0 + (v1 - v0) * 0.35
    d.rectangle([u0, v0, u1, sheet], fill=(62, 88, 140, 255))
    for uu in np.arange(u0, u1, 3):
        d.point([uu, v0 + 1], fill=(92, 120, 172, 255))
    d.line([u0, v0, u1, v0], fill=(120, 146, 196, 255))
    d.rectangle([u0, sheet + 1, u1, v1], fill=(132, 144, 166, 255))
    d.line([u0, sheet + 1, u1, sheet + 1], fill=(176, 186, 204, 255))
    d.line([u0, v1, u1, v1], fill=(70, 78, 98, 255))
    # rain streaks on the flashing
    for x in np.arange(W["x0"], W["x1"], 0.37):
        if RNG.random() < 0.35:
            uu = roof.local(*pic(x, 0, W["front"]))[0]
            d.line([uu, v0 + 2, uu, v1 - 1], fill=(124, 138, 162, 255))
    roof.face("z", x0=W["x0"], x1=W["x1"], y0=W["roof"], y1=W["top"], z=W["front"])
    roof.face("y", x0=W["x0"], x1=W["x1"], y=W["roof"], z0=W["front"], z1=W["back"])
    out_layers.append(roof.save(out))
    for row, z in (("front", W["front"] - 0.15), ("back", W["back"] + 0.15)):
        posts = Layer("walk_posts_" + row, W["x0"], W["x1"], 0.0, W["roof"], z)
        d = ImageDraw.Draw(posts.img)
        for side in (-1, 1):
            for p in POSTS:
                x = side * p
                a, b, c, e = posts.rect(x - W["post"] / 2, x + W["post"] / 2, 0.0, W["roof"], z)
                shade = 1.0 if row == "front" else 0.85
                d.rectangle([a, b, c, e], fill=tuple(int(v * shade) for v in (104, 116, 142)) + (255,))
                d.line([a, b, a, e], fill=tuple(int(v * shade) for v in (150, 162, 186)) + (255,))
                d.rectangle([a - 1, e - 2, c + 1, e], fill=(70, 76, 92, 255))          # footing
                posts.face("box", x0=x - W["post"] / 2, x1=x + W["post"] / 2, y0=0.0, y1=W["roof"],
                           zf=z, zb=z - W["post"])
        out_layers.append(posts.save(out))


# ---------------------------------------------------------------- shrubs, hedge, trees, benches

def make_planters(bush, out_layers, out):
    z = 3.0
    for side in (-1, 1):
        x0, x1 = (3.4, 10.4) if side > 0 else (-10.4, -3.4)
        lay = Layer("planter_" + ("r" if side > 0 else "l"), x0 - 0.3, x1 + 0.3, 0.0, 0.9, z)
        u0, v0, u1, v1 = lay.rect(x0, x1, 0.0, 0.6, z)
        d = ImageDraw.Draw(lay.img)
        d.rectangle([u0, v1 - 4, u1, v1], fill=(96, 104, 122, 255))                   # planter kerb
        d.line([u0, v1 - 4, u1, v1 - 4], fill=(140, 148, 164, 255))
        for i, cx in enumerate(np.arange(u0 + 6, u1 - 4, 13)):
            foliage(bush, lay.img, cx, v1 - 9, 8, 5, 4, 15, seed=int(cx) + side * 7)
        lay.face("z", x0=x0 - 0.3, x1=x1 + 0.3, y0=0.0, y1=0.9, z=z)
        out_layers.append(lay.save(out))


HEDGE = dict(front=7.9, back=7.25, h=0.8, gap=1.9, end=24.0)


def make_hedge(bush, out_layers, out):
    H = HEDGE
    for side in (-1, 1):
        x0, x1 = (H["gap"], H["end"]) if side > 0 else (-H["end"], -H["gap"])
        lay = Layer("hedge_" + ("r" if side > 0 else "l"), x0, x1, 0.0, H["h"] + 0.25, H["front"])
        u0, v0, u1, v1 = lay.rect(x0, x1, 0.0, H["h"], H["front"])
        # trimmed body: a dense row of small dark stamps, lit along the top
        img = lay.img
        rng = np.random.default_rng(side + 3)
        for row, (yy, tone) in enumerate(((v1 - 3, 0.62), (v1 - 8, 0.72), (v0 + 7, 0.86), (v0 + 3, 1.0))):
            for cx in np.arange(u0 + 2, u1 - 2, 7):
                s = stamp(bush, 14 * rng.uniform(0.85, 1.15), rng.random() < 0.5, tone * rng.uniform(0.92, 1.05))
                img.alpha_composite(s, (int(cx - s.width / 2), int(yy - s.height * 0.55)))
        # clip the body to the hedge box (leafy bumps allowed on top), square cut at the path end
        a = np.asarray(img).copy()
        vv = np.arange(a.shape[0])[:, None]
        uu = np.arange(a.shape[1])[None, :]
        keep = (vv <= v1) & (uu >= u0) & (uu <= u1) & (vv >= v0 - 4)
        a[..., 3] = np.where(keep, a[..., 3], 0)
        body = (vv >= v0 + 2) & (vv <= v1) & (uu >= u0) & (uu <= u1)
        fill = np.array([40, 64, 62, 255])
        a[body & (a[..., 3] == 0)] = fill
        lay.img = Image.fromarray(a)
        lay.face("z", x0=x0, x1=x1, y0=0.0, y1=H["h"] + 0.25, z=H["front"])
        lay.face("y", x0=x0, x1=x1, y=H["h"], z0=H["front"], z1=H["back"])
        out_layers.append(lay.save(out))


TREES = [dict(name="tree_l", x=-8.4, z=12.0, h=6.8, crown=7.2, seed=4),
         dict(name="tree_r", x=9.6, z=13.5, h=6.4, crown=6.6, seed=9)]
BARK, BARK_LIT, BARK_DARK = (72, 70, 82), (108, 106, 118), (44, 44, 56)
LEAFAGE = (600, 0, 880, 120)                     # a dense patch of the author's crown (source px)


def load_leafage(path, scale):
    src = Image.open(path).convert("RGBA").crop(LEAFAGE)
    src = src.resize((round(src.width * scale), round(src.height * scale)), Image.LANCZOS)
    # mirror-tile it large enough for any clump (mirrored copies hide the seams)
    a = np.asarray(src)
    row = np.concatenate([a, a[:, ::-1]], 1)
    block = np.concatenate([row, row[::-1]], 0)
    return Image.fromarray(np.tile(block, (4, 3, 1)))


def limb(d, a, b, w0, w1, bend=0.0):
    """Tapered, slightly bent limb from a to b (picture px): lit left edge, dark right edge."""
    n = int(np.hypot(b[0] - a[0], b[1] - a[1])) + 2
    for i in range(n + 1):
        f = i / n
        x = a[0] + (b[0] - a[0]) * f + np.sin(f * np.pi) * bend
        y = a[1] + (b[1] - a[1]) * f
        w = w0 + (w1 - w0) * f
        d.line([x - w, y, x + w, y], fill=BARK)
        d.line([x - w, y, x - w + max(1, w * 0.45), y], fill=BARK_LIT)
        d.point([x + w, y], fill=BARK_DARK)
        if (i * 7) % 11 == 0:
            d.point([x + w * 0.2, y], fill=BARK_DARK)             # bark marks


def dome(img, leafage, bush, cx, cy, r, tone, rng):
    """One leaf clump: dense author leaves in a round mask, lit from the upper left, leafy rim."""
    size = int(2 * r) + 2
    ox, oy = rng.integers(0, max(1, leafage.width - size)), rng.integers(0, max(1, leafage.height - size))
    tex = leafage.crop((ox, oy, ox + size, oy + size)).resize((size, size))
    t = np.asarray(tex).astype(float)
    yy, xx = np.mgrid[0:size, 0:size]
    nx, ny = (xx - r) / r, (yy - r) / r
    shade = tone * (1.12 - 0.42 * (ny + 1) / 2 - 0.12 * nx)
    t[..., :3] *= shade[..., None]
    edge = gaussian_filter(rng.normal(0, 0.5, (size, size)), 2.0)        # soft lumps, not speckles
    inside = (nx ** 2 + (ny * 1.15) ** 2 + edge) < 1.0
    t[..., 3] = np.where(inside, 255, 0)
    img.alpha_composite(Image.fromarray(np.clip(t, 0, 255).astype(np.uint8)), (int(cx - r), int(cy - r)))
    # leafy rim over the upper half
    for a in np.linspace(np.pi * 1.05, np.pi * 1.95, 5):
        s = stamp(bush, r * rng.uniform(0.6, 0.85), rng.random() < 0.5, tone * rng.uniform(1.0, 1.12))
        px, py = cx + np.cos(a) * r * 0.82, cy + np.sin(a) * r * 0.72
        img.alpha_composite(s, (int(px - s.width / 2), int(py - s.height * 0.6)))


def make_tree(bush, t, out_layers, out):
    """Rain tree: short trunk splitting into spreading limbs under a wide umbrella of leaf clumps."""
    x, z, h, cw = t["x"], t["z"], t["h"], t["crown"]
    rng = np.random.default_rng(t["seed"])
    lay = Layer(t["name"], x - cw / 2 - 0.8, x + cw / 2 + 0.8, 0.0, h + 0.6, z)
    img = lay.img
    d = ImageDraw.Draw(img)
    m = k(z) * PPM                                          # picture px per metre at this depth
    leafage = load_leafage(sys.argv[1], 0.42 * m / 40)
    bu, bv = lay.local(*pic(x, 0.0, z))
    fork = (bu + rng.uniform(-0.1, 0.1) * m, bv - 2.2 * m)
    # flared foot and trunk
    d.polygon([(bu - 0.5 * m, bv), (bu - 0.22 * m, bv - 0.45 * m), (bu + 0.22 * m, bv - 0.45 * m),
               (bu + 0.52 * m, bv)], fill=BARK)
    d.line([bu - 0.5 * m, bv, bu - 0.22 * m, bv - 0.45 * m], fill=BARK_LIT)
    limb(d, (bu, bv - 1), fork, 0.24 * m, 0.19 * m, bend=0.08 * m)
    ends = []
    for side, up, bend in ((-1, 1.9, -0.3), (-0.25, 2.6, 0.15), (0.35, 2.5, -0.1), (1, 1.8, 0.3)):
        e = (fork[0] + side * cw * 0.33 * m, fork[1] - up * m)
        limb(d, fork, e, 0.14 * m, 0.06 * m, bend=bend * m)
        ends.append(e)
    # crown: back row of domes high and darker, front row lower and lit; umbrella outline
    base_v = lay.local(*pic(x, h - 2.7, z))[1]
    domes = []
    for row, (n, lift, rad, tone) in enumerate(((6, 1.5, 1.15, 0.8), (7, 0.9, 1.0, 0.95), (5, 0.35, 0.85, 1.05))):
        for i in range(n):
            f = (i + 0.5) / n
            spread = (0.98 - row * 0.12)
            cx = bu + (f - 0.5) * cw * m * spread + rng.uniform(-0.2, 0.2) * m
            bulge = 1 - (2 * f - 1) ** 2
            cy = base_v - (lift + 0.8 * bulge) * m + rng.uniform(-0.15, 0.15) * m
            domes.append((cx, cy, rad * m * (0.85 + 0.3 * bulge) * rng.uniform(0.9, 1.1), tone))
    for cx, cy, r, tone in domes:
        dome(img, leafage, bush, cx, cy, r, tone * rng.uniform(0.95, 1.04), rng)
    # limbs through the gaps under the crown
    d = ImageDraw.Draw(img)
    for e in (ends[0], ends[3]):
        a = (fork[0] + (e[0] - fork[0]) * 0.5, fork[1] + (e[1] - fork[1]) * 0.5)
        limb(d, a, (fork[0] + (e[0] - fork[0]) * 0.75, fork[1] + (e[1] - fork[1]) * 0.72), 0.09 * m, 0.06 * m)
    lay.face("z", x0=x - cw / 2 - 0.8, x1=x + cw / 2 + 0.8, y0=0.0, y1=h + 0.6, z=z)
    out_layers.append(lay.save(out))


BENCHES = [dict(name="bench_l", x=-5.6, z=10.6), dict(name="bench_r", x=6.2, z=11.4)]


def make_bench(b, out_layers, out):
    x, z, w = b["x"], b["z"], 1.8
    lay = Layer(b["name"], x - w / 2 - 0.1, x + w / 2 + 0.1, 0.0, 0.95, z)
    d = ImageDraw.Draw(lay.img)
    u0, v0, u1, v1 = lay.rect(x - w / 2, x + w / 2, 0.0, 0.9, z)
    m = k(z) * PPM                                          # px per metre here
    seat = v1 - 0.45 * m
    wood, wood_d, wood_l, iron = (132, 88, 60, 255), (98, 64, 46, 255), (164, 116, 80, 255), (40, 46, 60, 255)
    # backrest: three slats
    for i in range(3):
        y = v0 + 2 + i * 0.13 * m
        d.rectangle([u0, y, u1, y + 0.08 * m], fill=wood)
        d.line([u0, y, u1, y], fill=wood_l)
    # seat seen a little from above, front edge darker
    d.rectangle([u0 - 1, seat - 0.07 * m, u1 + 1, seat], fill=wood_l)
    d.rectangle([u0 - 1, seat, u1 + 1, seat + 0.06 * m], fill=wood_d)
    # iron legs/ends
    for uu in (u0 + 2, u1 - 3):
        d.rectangle([uu, v0 + 1, uu + 1, v1], fill=iron)
        d.line([uu - 2, v1, uu + 3, v1], fill=iron)
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
    make_hedge(bush, layers, out)
    for b in BENCHES:
        make_bench(b, layers, out)
    for t in TREES:
        make_tree(bush, t, layers, out)
    with open(os.path.join(out, "courtyard.json"), "w") as f:
        json.dump({"px_per_m": PPM, "layers": layers}, f, indent=1)
    print(f"{len(layers)} layers -> {out}")


if __name__ == "__main__":
    main()
