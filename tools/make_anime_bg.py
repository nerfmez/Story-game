"""Paint the after-school street as anime-style pixel-art parallax layers.

The scene is laid out in metres and projected with a simple pinhole camera, so
the street, houses, poles and wires all share one vanishing point at the
characters' eye level. Each object is painted into the parallax layer that
matches its distance. Lighting is a low sunset behind the street: faces turned
towards the sun get warm rim light, everything else sits in cool purple shade,
and windows, shops and vending machines glow.

Layers are 800x360 (the 640x360 screen plus room to pan), drawn at x = -80.

Usage: python3 tools/make_anime_bg.py
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BG = ROOT / "assets" / "bg"
FONT = ROOT / "assets" / "fonts" / "Sarabun-Regular.ttf"

W, H = 800, 360
CX = 400          # vanishing point x (screen centre inside the 800px layer)
HORIZON = 166     # eye level of a 1.5 m tall camera
F = 288.0         # focal length in px: a 1.7 m character at Z = 4 m is ~122 px tall
EYE = 1.5
rng = random.Random(21)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0

# Palette: warm sunset key light + cool purple shade
SUN = (255, 214, 150)
RIM = (255, 190, 120)
HAZE = (190, 130, 160)
SHADE = (70, 58, 108)
SHADE_DARK = (44, 38, 78)
WINDOW = (255, 214, 140)
WINDOW_DIM = (190, 150, 120)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def haze(col, z):
    return mix(col, HAZE, 1.0 - math.exp(-z / 260.0))


def project(x, y, z):
    return (CX + F * x / z, HORIZON - F * (y - EYE) / z)


class TrackedDraw:
    """ImageDraw that also writes a per-shape ID map, used to draw anime line art.
    Every shape gets a new ID; later shapes are in front of earlier ones."""

    def __init__(self, layer):
        self.layer = layer
        self.img = ImageDraw.Draw(layer.img)
        self.ids = ImageDraw.Draw(layer.ids)

    def _next(self, noline):
        self.layer.next_id += 1
        if noline:
            self.layer.noline.add(self.layer.next_id)
        return self.layer.next_id

    def polygon(self, pts, fill, noline=False):
        self.img.polygon(pts, fill=fill)
        self.ids.polygon(pts, fill=self._next(noline))

    def line(self, pts, fill, width=1, noline=False):
        self.img.line(pts, fill=fill, width=width)
        self.ids.line(pts, fill=self._next(noline), width=width)

    def ellipse(self, box, fill=None, noline=False, outline=None, width=1):
        if outline:  # ring only (bicycle wheels)
            self.img.ellipse(box, outline=outline, width=width)
            self.ids.ellipse(box, outline=self._next(True), width=width)
            return
        self.img.ellipse(box, fill=fill)
        self.ids.ellipse(box, fill=self._next(noline))

    def rectangle(self, box, fill, noline=False):
        self.img.rectangle(box, fill=fill)
        self.ids.rectangle(box, fill=self._next(noline))


class Layer:
    def __init__(self, name, line_strength=1.0):
        self.name = name
        self.line_strength = line_strength
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.ids = Image.new("I", (W, H), 0)
        self.next_id = 0
        self.noline = set()
        self.draw = TrackedDraw(self)
        self.glow = Image.new("RGB", (W, H), (0, 0, 0))  # emissive buffer for bloom
        self.glow_draw = ImageDraw.Draw(self.glow)

    def poly(self, pts, col, glow=None, noline=False):
        pts = [(round(x), round(y)) for x, y in pts]
        self.draw.polygon(pts, fill=col + (255,), noline=noline)
        if glow:
            self.glow_draw.polygon(pts, fill=glow)

    def quad3d(self, corners, col, glow=None, noline=False):
        self.poly([project(*c) for c in corners], col, glow, noline)

    def line3d(self, a, b, col, width=1, noline=True):
        self.draw.line([project(*a), project(*b)], fill=col + (255,), width=width, noline=noline)

    def paste(self, arr, noline=False):
        """Composite an RGBA array (trees, shrubs) as one outlined shape."""
        img = Image.fromarray(arr, "RGBA")
        self.img.alpha_composite(img)
        self.next_id += 1
        if noline:
            self.noline.add(self.next_id)
        mask = Image.fromarray(((arr[..., 3] > 0) * 255).astype(np.uint8), "L")
        self.ids.paste(self.next_id, (0, 0), mask)

    def line_art(self):
        """1px outline wherever a shape meets something behind it (or empty space).
        The line colour is a darker, cooler version of the shape's own colour
        (selective outlining), faded by line_strength for distant layers."""
        ids = np.asarray(self.ids).astype(np.int64)
        rgba = np.asarray(self.img).astype(float)
        noline = np.zeros(self.next_id + 2, bool)
        for i in self.noline:
            noline[i] = True
        edge = np.zeros(ids.shape, bool)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nb = np.roll(np.roll(ids, dy, axis=0), dx, axis=1)
            edge |= (ids > nb) & (ids > 0)
        edge &= ~noline[ids]
        line = rgba[..., :3] * 0.22 + np.array((22, 12, 42)) * 0.78
        k = self.line_strength
        rgba[edge, :3] = rgba[edge, :3] * (1 - k) + line[edge] * k
        self.img = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")
        self.draw = TrackedDraw(self)

    def finish(self, bloom=0.9):
        # Soft glow around light sources, then composite under the alpha of the layer
        g = self.glow.filter(ImageFilter.GaussianBlur(6))
        g2 = self.glow.filter(ImageFilter.GaussianBlur(16))
        base = np.asarray(self.img).astype(float)
        add = (np.asarray(g).astype(float) * 0.55 + np.asarray(g2).astype(float) * 0.45) * bloom
        rgb = base[..., :3] + add * (1 - base[..., :3] / 320.0)
        alpha = base[..., 3]
        # Glow also spills slightly into transparent areas of this layer
        spill = np.clip(add.max(axis=2) * 0.9, 0, 255)
        alpha_out = np.maximum(alpha, spill * (alpha == 0))
        rgb = np.where(alpha[..., None] == 0, add / np.maximum(spill[..., None], 1) * 255 * (spill[..., None] > 0), rgb)
        out = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha_out, 0, 255)]).astype(np.uint8)
        self.img = Image.fromarray(out, "RGBA")
        self.line_art()  # line art goes on top of the lighting, like inked cels
        self.img.save(BG / self.name)


# ---------------------------------------------------------------- 3D primitives

def box(layer, x0, x1, y0, y1, z0, z1, front, side_lit, side_dark, top=None, glow=None):
    """Axis-aligned box. Draws the faces the camera can see, with sunset shading.
    Sun is behind the street on the right: +X-facing faces catch warm light."""
    zf = z0
    hz = lambda c: haze(c, zf)
    # Side face toward the road
    if x1 < 0:  # object on the left: its right face (+X) is visible and sunlit
        layer.quad3d([(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)], hz(side_lit))
    elif x0 > 0:  # object on the right: its left face (-X) is visible, in shade
        layer.quad3d([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], hz(side_dark))
    if y1 < EYE and top:
        layer.quad3d([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], hz(top))
    layer.quad3d([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], hz(front), glow)
    layer.line3d((x0, y1, z0), (x1, y1, z0), hz(mix(front, RIM, 0.55)))
    # Rim light on the sun side edges
    if x1 < 0:
        layer.line3d((x1, y1, z0), (x1, y1, z1), hz(RIM))
        layer.line3d((x1, y0, z0), (x1, y1, z0), hz(mix(side_lit, RIM, 0.5)))


def pole(layer, x, z, height=8.5):
    w = 0.14
    col = haze((58, 52, 86), z)
    box(layer, x - w, x + w, 0, height, z, z + 0.25, col, haze((150, 110, 120), z), col)
    # Cross arms + transformer
    for y, half in ((height - 0.4, 1.0), (height - 1.2, 0.8)):
        layer.quad3d([(x - half, y, z), (x + half, y, z), (x + half, y + 0.1, z), (x - half, y + 0.1, z)], col)
    if int(z) % 3 == 0:
        layer.quad3d([(x - 0.35, height - 3.0, z), (x - 0.05, height - 3.0, z), (x - 0.05, height - 2.0, z), (x - 0.35, height - 2.0, z)], haze((90, 86, 120), z))
    return [(x + dx, height - 0.4 if k < 3 else height - 1.2, z) for k, dx in enumerate((-0.9, 0.0, 0.9, -0.7, 0.7))]


def wire(layer, a, b, sag=0.5, col=(40, 34, 62), steps=24):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        p = [a[k] + (b[k] - a[k]) * t for k in range(3)]
        p[1] -= sag * 4 * t * (1 - t)
        pts.append(project(*p))
    layer.draw.line(pts, fill=col + (255,), width=1, noline=True)


def windows(layer, x_face, z0, z1, y0, y1, rows, cols, lit_ratio, z_ref, facing_left=True):
    """Windows on a side face (plane x = x_face) between z0..z1 and y0..y1."""
    for r in range(rows):
        for c in range(cols):
            wz0 = z0 + (z1 - z0) * (c + 0.2) / cols
            wz1 = z0 + (z1 - z0) * (c + 0.8) / cols
            wy0 = y0 + (y1 - y0) * (r + 0.25) / rows
            wy1 = y0 + (y1 - y0) * (r + 0.75) / rows
            lit = rng.random() < lit_ratio
            col = haze(WINDOW if lit else (60, 70, 120), z_ref)
            layer.quad3d([(x_face, wy0, wz0), (x_face, wy0, wz1), (x_face, wy1, wz1), (x_face, wy1, wz0)], col,
                         glow=tuple(int(v * 0.6) for v in col) if lit else None)


def front_windows(layer, x0, x1, z, y0, y1, rows, lit_ratio):
    """Windows on a face that looks at the camera (plane z)."""
    cols = max(1, int((x1 - x0) / 2.2))
    for r in range(rows):
        for c in range(cols):
            wx0 = x0 + (x1 - x0) * (c + 0.25) / cols
            wx1 = x0 + (x1 - x0) * (c + 0.75) / cols
            wy0 = y0 + (y1 - y0) * (r + 0.3) / rows
            wy1 = y0 + (y1 - y0) * (r + 0.75) / rows
            lit = rng.random() < lit_ratio
            col = haze(WINDOW if lit else (54, 56, 100), z)
            layer.quad3d([(wx0, wy0, z), (wx1, wy0, z), (wx1, wy1, z), (wx0, wy1, z)], col,
                         glow=tuple(int(v * 0.5) for v in col) if lit else None)


def house(layer, side, z, depth, height, color):
    """A Japanese-style house/shop along the street. side = -1 left, +1 right."""
    x_near = 5.2 * side
    x_far = x_near + 7.0 * side
    x0, x1 = min(x_near, x_far), max(x_near, x_far)
    side_col = mix(mix(color, SHADE, 0.5), RIM, 0.12)
    front = mix(color, SHADE_DARK, 0.62)
    box(layer, x0, x1, 0, height, z, z + depth, front, side_col, mix(side_col, SHADE_DARK, 0.2))
    face = x1 if side < 0 else x0
    floors = max(1, int(height / 3))
    windows(layer, face, z + 0.6, z + depth - 0.6, 0.6, height - 0.5, floors, max(1, int(depth / 2.5)), 0.4, z)
    front_windows(layer, x0, x1, z, 0.6, height - 0.5, floors, 0.35)
    # Tiled roof overhang (kawara): a slanted strip along the road side
    roof = haze((70, 62, 98), z)
    edge = face + 0.6 * -side
    layer.quad3d([(face, height, z - 0.4), (face, height, z + depth + 0.4), (edge, height - 0.6, z + depth + 0.4), (edge, height - 0.6, z - 0.4)], roof)
    layer.line3d((edge, height - 0.6, z - 0.4), (edge, height - 0.6, z + depth + 0.4), haze(RIM if side < 0 else (110, 90, 130), z))
    # Siding lines on the street-facing wall and tile ridges on the roof edge
    for k in range(1, int(height / 0.7)):
        layer.line3d((face, k * 0.7, z), (face, k * 0.7, z + depth), haze(mix(side_col, SHADE_DARK, 0.25), z))
    for k in range(int(depth / 0.6) + 1):
        zz = z - 0.4 + k * 0.6
        layer.line3d((face, height, zz), (edge, height - 0.6, zz), haze((50, 44, 78), z))
    # Air conditioner units and a sign now and then
    if rng.random() < 0.6:
        y = rng.uniform(1.0, height - 1.5)
        zz = rng.uniform(z + 0.5, z + depth - 1.5)
        layer.quad3d([(face - 0.05 * side, y, zz), (face - 0.05 * side, y, zz + 0.9), (face - 0.05 * side, y + 0.6, zz + 0.9), (face - 0.05 * side, y + 0.6, zz)], haze((200, 196, 210), z))
    if rng.random() < 0.35:
        sc = rng.choice([(230, 80, 70), (80, 150, 220), (250, 200, 90)])
        y = rng.uniform(2.0, height - 1.0)
        layer.quad3d([(face - 0.8 * side, y, z + 1.0), (face - 0.8 * side, y, z + 1.6), (face - 0.8 * side, y + 1.4, z + 1.6), (face - 0.8 * side, y + 1.4, z + 1.0)],
                     haze(sc, z), glow=tuple(int(v * 0.5) for v in haze(sc, z)))


# ---------------------------------------------------------------- painterly fields

def shaded_blobs(size, blobs, light_dir, palette, rim, seed_noise=0.0):
    """Metaball shape shaded by a light direction -> anime cloud / tree canopy."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    dens = np.zeros((h, w))
    for bx, by, br in blobs:
        dens += np.exp(-(((xx - bx) ** 2 + (yy - by) ** 2) / (br * br)))
    if seed_noise:
        dens += (np.random.default_rng(5).random((h, w)) - 0.5) * seed_noise
    mask = dens > 0.5
    gy, gx = np.gradient(dens)
    norm = np.sqrt(gx * gx + gy * gy) + 1e-6
    nx, ny = -gx / norm, -gy / norm
    light = nx * light_dir[0] + ny * light_dir[1]
    # Interior is mostly in shade; edges facing the light glow
    edge = np.clip(1.0 - (dens - 0.5) * 1.6, 0, 1)
    shade = np.clip(0.35 + 0.65 * light * edge + 0.15 * (dens < 0.75), 0, 1)
    shade += (BAYER[yy.astype(int) % 4, xx.astype(int) % 4] - 0.5) * 0.18
    idx = np.clip((shade * len(palette)).astype(int), 0, len(palette) - 1)
    pal = np.array(palette)
    rgb = pal[idx]
    rim_mask = mask & (light > 0.55) & (edge > 0.75)
    rgb[rim_mask] = rim
    alpha = np.where(mask, 255, 0)
    return np.dstack([rgb, alpha]).astype(np.uint8)


def paste_rgba(dst, arr, x, y):
    img = Image.fromarray(arr, "RGBA")
    dst.alpha_composite(img, (int(x), int(y)))


# ---------------------------------------------------------------- layers

def paint_sky():
    img = Image.new("RGBA", (W, H))
    px = np.zeros((H, W, 3))
    stops = [(0.0, (34, 38, 100)), (0.25, (70, 62, 140)), (0.45, (150, 96, 160)), (0.6, (232, 130, 140)), (0.75, (252, 170, 120)), (1.0, (255, 214, 150))]
    sun = (CX, 140)
    yy, xx = np.mgrid[0:H, 0:W]
    dither = BAYER[yy % 4, xx % 4]
    for y in range(H):
        t = min(1.0, y / 200.0)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                lt = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                c0, c1 = np.array(stops[i][1]), np.array(stops[i + 1][1])
                q = np.floor((lt * 10 + dither[y]) ) / 10
                px[y] = c0 + (c1 - c0) * q[:, None]
                break
    dist = np.sqrt((xx - sun[0]) ** 2 + ((yy - sun[1]) * 1.3) ** 2)
    glow = np.clip(1 - dist / 260.0, 0, 1) ** 1.6
    glow = np.floor(glow * 8 + dither) / 8
    px = px + (np.array(SUN) - px) * glow[..., None] * 0.8
    img = Image.fromarray(np.dstack([np.clip(px, 0, 255), np.full((H, W), 255)]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    d.ellipse((sun[0] - 17, sun[1] - 17, sun[0] + 17, sun[1] + 17), fill=(255, 236, 190, 255))
    d.ellipse((sun[0] - 12, sun[1] - 12, sun[0] + 12, sun[1] + 12), fill=(255, 250, 230, 255))

    cloud_pal = [(70, 60, 120), (112, 78, 140), (170, 104, 150), (226, 136, 140), (250, 176, 130)]
    # Big towering cumulonimbus on the left, lit from the low sun on the right
    blobs = []
    for i in range(46):
        t = i / 46
        bx = 150 + rng.gauss(0, 34) * (0.6 + t)
        by = 210 - t * 170 + rng.gauss(0, 8)
        br = 34 - t * 14 + rng.uniform(-5, 6)
        blobs.append((bx, by, br))
    paste_rgba(img, shaded_blobs((W, H), blobs, (0.85, 0.5), cloud_pal, (255, 226, 180), 0.05), 0, 0)
    # Long low strato clouds across the sun
    for cy, cx0, length in ((112, 470, 240), (92, 560, 200), (70, 250, 200), (150, 120, 150)):
        blobs = [(cx0 + k * length / 14, cy + rng.gauss(0, 2.5), rng.uniform(7, 12)) for k in range(14)]
        paste_rgba(img, shaded_blobs((W, H), blobs, (0.2, 1.0), cloud_pal, (255, 214, 160)), 0, 0)
    # Birds and a contrail
    for bx, by in ((520, 70), (531, 76), (545, 66), (300, 96)):
        d.line([(bx - 3, by - 2), (bx, by), (bx + 3, by - 2)], fill=(60, 50, 90, 255))
    d.line([(600, 30), (790, 12)], fill=(250, 200, 190, 255))
    img.save(BG / "01_sky.png")


def paint_far():
    layer = Layer("02_city_far.png", line_strength=0.25)
    # Distant mountains + skyline, heavy haze
    pts = [(0, HORIZON - 6)]
    for x in range(0, W + 40, 40):
        pts.append((x, HORIZON - 4 - (6 + 14 * abs(math.sin(x * 0.011))) * min(1.0, abs(x - CX) / 160.0) - rng.uniform(0, 3)))
    pts += [(W, HORIZON + 4), (0, HORIZON + 4)]
    layer.poly(pts, (150, 110, 160))
    x = 0
    while x < W:
        w = rng.randint(10, 26)
        h = rng.randint(8, 46) if abs(x - CX) > 70 else rng.randint(4, 14)
        col = mix((120, 92, 150), HAZE, rng.uniform(0.1, 0.3))
        layer.poly([(x, HORIZON - h), (x + w, HORIZON - h), (x + w, HORIZON + 4), (x, HORIZON + 4)], col)
        for wy in range(int(HORIZON - h + 3), HORIZON, 4):
            for wx in range(x + 2, x + w - 2, 4):
                if rng.random() < 0.18:
                    layer.poly([(wx, wy), (wx + 1, wy), (wx + 1, wy + 1), (wx, wy + 1)], (255, 210, 150), glow=(120, 90, 60))
        x += w + rng.randint(0, 3)
    # A tower with a blinking red light
    layer.poly([(268, HORIZON - 70), (272, HORIZON - 70), (276, HORIZON), (264, HORIZON)], (118, 92, 146))
    layer.poly([(269, HORIZON - 73), (271, HORIZON - 73), (271, HORIZON - 71), (269, HORIZON - 71)], (255, 90, 80), glow=(200, 40, 30))
    # Far end of the street (Z 60..200)
    for z in range(190, 60, -14):
        for side in (-1, 1):
            house(layer, side, z, 10, rng.uniform(5, 12), rng.choice([(170, 150, 180), (150, 140, 170), (190, 160, 160)]))
    layer.quad3d([(-3.5, 0, 60), (3.5, 0, 60), (3.5, 0, 400), (-3.5, 0, 400)], haze((80, 70, 110), 120))
    layer.finish(0.6)


def paint_street():
    layer = Layer("03_street.png", line_strength=0.6)
    # Road + sidewalks from Z 18..60
    layer.quad3d([(-5.2, 0, 18), (5.2, 0, 18), (5.2, 0, 61), (-5.2, 0, 61)], (110, 96, 140))
    layer.quad3d([(-3.5, 0, 18), (3.5, 0, 18), (3.5, 0, 61), (-3.5, 0, 61)], (78, 70, 112))
    for side in (-1, 1):
        layer.line3d((3.4 * side, 0, 18), (3.4 * side, 0, 61), (190, 170, 190))
    for z in range(58, 18, -2):
        for side in (-1, 1):
            pass
    zs = list(range(56, 18, -9))
    palette = [(214, 190, 186), (190, 176, 196), (226, 206, 178), (170, 160, 196), (206, 170, 160)]
    for z in zs:
        for side in (-1, 1):
            house(layer, side, z, 8.5, rng.uniform(5.5, 9.5), rng.choice(palette))
    # Poles and sagging wires down the street
    tops = {}
    for side in (-1, 1):
        prev = None
        for z in (60, 46, 32, 20):
            t = pole(layer, 4.4 * side, z)
            if prev:
                for a, b in zip(prev, t):
                    wire(layer, a, b, sag=0.6)
            prev = t
        tops[side] = prev
    # Wires crossing the street
    wire(layer, (-4.4, 8.1, 46), (4.4, 7.3, 32), sag=0.4)
    wire(layer, (4.4, 8.1, 60), (-4.4, 7.3, 46), sag=0.4)
    # Street lamps
    for z in (40, 26):
        p = project(-4.0, 5.2, z)
        layer.poly([(p[0] - 2, p[1]), (p[0] + 2, p[1]), (p[0] + 2, p[1] + 1), (p[0] - 2, p[1] + 1)], (255, 240, 210), glow=(255, 200, 140))
    layer.finish(0.8)
    return tops


def paint_mid(street_tops):
    layer = Layer("04_mid.png", line_strength=0.95)
    # Road and sidewalks Z 7.5..18
    layer.quad3d([(-30, 0, 7.5), (30, 0, 7.5), (30, 0, 18.2), (-30, 0, 18.2)], (100, 88, 130))
    layer.quad3d([(-3.5, 0, 7.5), (3.5, 0, 7.5), (3.5, 0, 18.2), (-3.5, 0, 18.2)], (74, 66, 106))
    for side in (-1, 1):
        layer.line3d((3.4 * side, 0, 7.5), (3.4 * side, 0, 15.5), (200, 180, 196))
    # Railway: ballast + rails across the road at Z ~16-17.5
    layer.quad3d([(-40, 0.02, 15.6), (40, 0.02, 15.6), (40, 0.02, 17.8), (-40, 0.02, 17.8)], (96, 84, 110))
    for rz in (16.1, 17.3):
        layer.line3d((-40, 0.15, rz), (40, 0.15, rz), (230, 200, 190))
    # Stop line in front of the crossing
    layer.quad3d([(-3.3, 0.01, 14.6), (0, 0.01, 14.6), (0, 0.01, 14.9), (-3.3, 0.01, 14.9)], (230, 220, 220))

    # --- School on the left: long wall along the road, gate, building behind
    school = (236, 222, 206)
    box(layer, -30, -20, 0, 12, 22, 40, mix(school, SHADE_DARK, 0.55), mix(mix(school, SHADE, 0.4), RIM, 0.2), school)
    windows(layer, -20, 22.5, 39.5, 1, 11.5, 4, 7, 0.5, 22)
    front_windows(layer, -30, -20, 22, 1, 11.5, 4, 0.4)
    layer.quad3d([(-27, 12, 22), (-23, 12, 22), (-23, 13.6, 22), (-27, 13.6, 22)], mix(school, SHADE_DARK, 0.5))  # clock tower
    c = project(-25, 12.8, 22)
    layer.draw.ellipse((c[0] - 4, c[1] - 4, c[0] + 4, c[1] + 4), fill=(240, 230, 210, 255))
    trees = [(-10, 6.0, 14), (-15, 7.0, 19), (-8.0, 5.5, 24), (12.5, 5.5, 16)]
    for tx, ty, tz in trees:
        base = project(tx, 0, tz)
        top = project(tx, ty, tz)
        r = (base[1] - top[1]) * 0.3
        blobs = [(top[0] + rng.gauss(0, r * 0.6), top[1] + r * 0.7 + rng.gauss(0, r * 0.4), r * rng.uniform(0.22, 0.4)) for _ in range(34)]
        tree_pal = [(24, 36, 58), (34, 54, 66), (48, 76, 74), (74, 108, 80), (120, 146, 88)]
        arr = shaded_blobs((W, H), blobs, (0.8, -0.2), tree_pal, (220, 200, 120), 0.04)
        layer.draw.line([base, (top[0], top[1] + r)], fill=(60, 44, 54, 255), width=max(1, int(r * 0.12)))
        layer.paste(arr)
    # Wall + gate pillars + name plate
    for k in range(10):  # shrubs peeking over the wall
        base = project(-6.0, 2.2, 7.8 + k * 0.8)
        r = F / (7.8 + k * 0.8) * 0.5
        blobs = [(base[0] + rng.gauss(0, r * 0.6), base[1] - r * 0.3 + rng.gauss(0, r * 0.3), r * rng.uniform(0.4, 0.7)) for _ in range(5)]
        layer.paste(shaded_blobs((W, H), blobs, (0.8, -0.3), [(28, 44, 60), (44, 70, 70), (76, 108, 80), (122, 150, 90)], (220, 200, 120)))
    wall_side = mix(mix(school, SHADE, 0.35), RIM, 0.25)
    box(layer, -5.6, -5.2, 0, 2.2, 7.5, 15.5, mix(school, SHADE_DARK, 0.5), wall_side, school, top=mix(school, RIM, 0.6))
    layer.quad3d([(-5.2, 2.0, 7.5), (-5.2, 2.0, 15.5), (-5.2, 2.2, 15.5), (-5.2, 2.2, 7.5)], mix(school, SHADE, 0.6))  # coping
    for k in range(9):
        layer.line3d((-5.19, 0.1, 7.5 + k * 0.9), (-5.19, 2.0, 7.5 + k * 0.9), mix(wall_side, SHADE, 0.35))
    layer.quad3d([(-5.19, 0, 7.5), (-5.19, 0, 15.5), (-5.19, 0.25, 15.5), (-5.19, 0.25, 7.5)], mix(wall_side, SHADE_DARK, 0.45))
    for gz in (10.5, 13.0):
        box(layer, -5.8, -5.0, 0, 2.9, gz, gz + 0.6, mix(school, SHADE, 0.35), mix(school, RIM, 0.5), school, top=RIM)
    layer.quad3d([(-5.0, 1.0, 11.1), (-5.0, 1.0, 13.0), (-5.0, 2.6, 13.0), (-5.0, 2.6, 11.1)], (40, 44, 78))  # open gate shadow
    plate = [project(-4.98, 2.3, 11.25), project(-4.98, 2.3, 12.9), project(-4.98, 1.9, 12.9), project(-4.98, 1.9, 11.25)]
    layer.poly(plate, (60, 70, 110))
    # Vending machines by the school gate: anime staple, strong cool glow
    for i, vz in enumerate((8.0, 9.0)):
        col = (230, 236, 250) if i == 0 else (120, 180, 240)
        box(layer, -5.15, -4.45, 0, 1.85, vz, vz + 0.85, (70, 80, 130), col, col)
        face = [(-4.45, 0.7, vz + 0.08), (-4.45, 0.7, vz + 0.77), (-4.45, 1.75, vz + 0.77), (-4.45, 1.75, vz + 0.08)]
        layer.quad3d(face, (236, 244, 255), glow=(150, 180, 230))
        for row in range(3):
            for k in range(4):
                c = rng.choice([(230, 70, 70), (70, 140, 230), (250, 200, 60), (80, 190, 120)])
                zz = vz + 0.12 + k * 0.16
                yy = 1.55 - row * 0.28
                layer.quad3d([(-4.44, yy, zz), (-4.44, yy, zz + 0.08), (-4.44, yy + 0.16, zz + 0.08), (-4.44, yy + 0.16, zz)], c)

    # --- Drink shop on the right (warm interior, striped awning, Thai sign)
    wood = (150, 96, 80)
    box(layer, 5.0, 11.0, 0, 3.6, 7.5, 13.0, mix(wood, SHADE, 0.5), wood, mix(wood, SHADE, 0.6))
    layer.quad3d([(5.0, 0.0, 7.9), (5.0, 0.0, 12.6), (5.0, 2.6, 12.6), (5.0, 2.6, 7.9)], (255, 196, 120), glow=(255, 150, 70))
    front_wood = mix(wood, SHADE, 0.5)
    for k in range(1, 15):
        layer.line3d((5.0 + k * 0.4, 0.05, 7.5), (5.0 + k * 0.4, 3.55, 7.5), mix(front_wood, SHADE_DARK, 0.35))
    layer.quad3d([(6.0, 1.1, 7.49), (7.6, 1.1, 7.49), (7.6, 2.3, 7.49), (6.0, 2.3, 7.49)], (255, 210, 150), glow=(160, 110, 60))  # side window
    layer.quad3d([(6.75, 1.1, 7.48), (6.85, 1.1, 7.48), (6.85, 2.3, 7.48), (6.75, 2.3, 7.48)], mix(front_wood, SHADE_DARK, 0.4))
    for k, pc in enumerate(((240, 230, 200), (250, 190, 120))):  # menu posters
        x0 = 8.2 + k * 0.9
        layer.quad3d([(x0, 1.2, 7.49), (x0 + 0.7, 1.2, 7.49), (x0 + 0.7, 2.2, 7.49), (x0, 2.2, 7.49)], pc)
        for r in range(3):
            layer.line3d((x0 + 0.1, 1.95 - r * 0.25, 7.48), (x0 + 0.6, 1.95 - r * 0.25, 7.48), (150, 90, 80))
    for k in range(4):  # noren curtain at the entrance
        z0 = 8.0 + k * 0.5
        layer.quad3d([(4.98, 2.6, z0), (4.98, 2.6, z0 + 0.45), (4.98, 2.0, z0 + 0.45), (4.98, 2.0, z0)], (60, 70, 140))
    for k in range(7):  # shelves with goods inside
        y = 0.9 + (k % 3) * 0.55
        zz = 8.3 + (k // 3) * 1.4
        for j in range(5):
            c = rng.choice([(240, 120, 90), (110, 170, 220), (250, 220, 120), (150, 210, 150), (240, 150, 190)])
            layer.quad3d([(5.01, y, zz + j * 0.24), (5.01, y, zz + j * 0.24 + 0.16), (5.01, y + 0.3, zz + j * 0.24 + 0.16), (5.01, y + 0.3, zz + j * 0.24)], c)
    layer.quad3d([(5.0, 0.0, 8.2), (5.0, 0.0, 10.4), (5.0, 1.0, 10.4), (5.0, 1.0, 8.2)], (200, 80, 70))  # counter
    # Awning stripes slanting over the sidewalk
    for k in range(12):
        z0 = 7.4 + k * 0.48
        col = (70, 104, 190) if k % 2 == 0 else (240, 236, 244)
        layer.quad3d([(5.0, 3.0, z0), (5.0, 3.0, z0 + 0.48), (3.9, 2.55, z0 + 0.48), (3.9, 2.55, z0)], mix(col, SHADE, 0.25))
    layer.line3d((3.9, 2.55, 7.4), (3.9, 2.55, 13.2), (255, 220, 170))
    # Hanging bulbs
    for k in range(4):
        b = project(4.3, 2.35, 8.0 + k * 1.4)
        layer.poly([(b[0] - 1, b[1] - 1), (b[0] + 1, b[1] - 1), (b[0] + 1, b[1] + 1), (b[0] - 1, b[1] + 1)], (255, 240, 200), glow=(255, 190, 110))
    # Sign board on the roof
    sb = [project(5.3, 4.6, 7.45), project(8.6, 4.6, 7.45), project(8.6, 3.65, 7.45), project(5.3, 3.65, 7.45)]
    layer.poly(sb, (196, 58, 52), glow=(70, 16, 8))
    layer.draw.line([sb[0], sb[1]], fill=(255, 200, 150, 255))
    _sign_text(layer, "ชาเย็น น้ำปั่น", sb)

    street_details(layer)

    # --- Railway crossing on both sides of the road
    for side in (-1, 1):
        crossing(layer, 4.0 * side, 15.2, side)
    # Near poles + wires reaching into the street
    tops = {}
    for side in (-1, 1):
        tops[side] = pole(layer, 4.4 * side, 12.0, 9.0)
        for a, b in zip(tops[side], street_tops[side]):
            wire(layer, a, b, sag=0.5)
    wire(layer, tops[-1][0], tops[1][2], sag=0.6)
    wire(layer, tops[-1][3], tops[1][4], sag=0.5)
    layer.finish(1.0)
    return tops


def street_details(layer):
    # Zebra crossing in front of the stop line
    for k in range(8):
        x0 = -3.2 + k * 0.82
        layer.quad3d([(x0, 0.01, 13.2), (x0 + 0.45, 0.01, 13.2), (x0 + 0.45, 0.01, 14.3), (x0, 0.01, 14.3)], (214, 206, 226))
    # Convex traffic mirror (orange pole, round mirror showing the sunset)
    mx, mz = 3.85, 10.5
    box(layer, mx - 0.05, mx + 0.05, 0, 2.6, mz, mz + 0.1, (230, 110, 50), (250, 150, 80), (200, 90, 40))
    c = project(mx - 0.35, 2.75, mz)
    r = F / mz * 0.33
    layer.draw.ellipse((c[0] - r - 1, c[1] - r - 1, c[0] + r + 1, c[1] + r + 1), fill=(236, 110, 50, 255))
    layer.draw.ellipse((c[0] - r + 1, c[1] - r + 1, c[0] + r - 1, c[1] + r - 1), fill=(220, 160, 170, 255))
    layer.draw.ellipse((c[0] - r + 2, c[1], c[0] + r - 2, c[1] + r - 1), fill=(120, 96, 150, 255), noline=True)
    layer.draw.line([(c[0] - r * 0.4, c[1] - r * 0.5), (c[0] - r * 0.1, c[1] - r * 0.6)], fill=(255, 240, 230, 255), noline=True)
    # Blue road sign on the school side
    sx, sz = -4.85, 9.4
    box(layer, sx - 0.04, sx + 0.04, 0, 2.3, sz, sz + 0.08, (150, 150, 170), (190, 190, 210), (120, 120, 140))
    c = project(sx, 2.55, sz)
    r = F / sz * 0.3
    layer.draw.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=(240, 240, 250, 255))
    layer.draw.ellipse((c[0] - r + 1, c[1] - r + 1, c[0] + r - 1, c[1] + r - 1), fill=(56, 96, 190, 255))
    layer.draw.polygon([(c[0], c[1] - r * 0.6), (c[0] + r * 0.45, c[1] + r * 0.1), (c[0] - r * 0.45, c[1] + r * 0.1)], fill=(250, 250, 255, 255), noline=True)
    layer.draw.rectangle((c[0] - 1, c[1], c[0] + 1, c[1] + r * 0.6), fill=(250, 250, 255, 255), noline=True)
    # Bicycle parked in front of the shop
    bz = 7.3
    w1, w2 = project(3.7, 0.33, bz), project(4.6, 0.33, bz)
    wr = F / bz * 0.33
    for w in (w1, w2):
        layer.draw.ellipse((w[0] - wr, w[1] - wr, w[0] + wr, w[1] + wr), outline=(34, 28, 52, 255), width=2)
        layer.draw.ellipse((w[0] - 1, w[1] - 1, w[0] + 1, w[1] + 1), fill=(150, 150, 170, 255), noline=True)
    seat, bar = project(3.95, 0.95, bz), project(4.5, 1.05, bz)
    for a, b in ((w1, seat), (seat, bar), (bar, w2), (seat, (w1[0] + (w2[0] - w1[0]) * 0.45, w1[1])), ((w1[0] + (w2[0] - w1[0]) * 0.45, w1[1]), w2)):
        layer.draw.line([a, b], fill=(70, 150, 200, 255), width=2)
    layer.draw.rectangle((bar[0] - 3, bar[1] - 4, bar[0] + 3, bar[1] - 1), fill=(200, 200, 210, 255))  # basket
    # Potted plants by the shop and the school gate
    for px, pz in ((4.75, 7.6), (4.75, 13.0), (-4.95, 13.8)):
        box(layer, px - 0.22, px + 0.22, 0, 0.45, pz, pz + 0.4, (170, 96, 70), (200, 120, 90), (140, 80, 60), top=(90, 60, 50))
        top = project(px, 0.75, pz)
        rr = F / pz * 0.4
        blobs = [(top[0] + rng.gauss(0, rr * 0.4), top[1] + rng.gauss(0, rr * 0.3), rr * rng.uniform(0.35, 0.6)) for _ in range(6)]
        layer.paste(shaded_blobs((W, H), blobs, (0.8, -0.4), [(30, 60, 60), (48, 90, 70), (80, 130, 80), (140, 170, 90)], (230, 210, 130)))


def crossing(layer, x, z, side):
    # Yellow/black striped post
    for k in range(12):
        y0 = k * 0.27
        col = (250, 210, 60) if k % 2 == 0 else (40, 36, 46)
        layer.quad3d([(x - 0.06, y0, z), (x + 0.06, y0, z), (x + 0.06, y0 + 0.27, z), (x - 0.06, y0 + 0.27, z)], col)
    # X sign
    cx, cy = project(x, 3.5, z)
    s = F / z * 0.55
    for sgn in (-1, 1):
        layer.draw.line([(cx - s, cy - s * 0.55 * sgn), (cx + s, cy + s * 0.55 * sgn)], fill=(250, 240, 230, 255), width=3)
        layer.draw.line([(cx - s, cy - s * 0.55 * sgn), (cx + s, cy + s * 0.55 * sgn)], fill=(240, 200, 60, 255), width=1)
    # Red lamps (one lit)
    ly = project(x, 2.75, z)[1]
    for k, dx in enumerate((-0.35, 0.35)):
        lx = project(x + dx, 2.75, z)[0]
        lit = (k == 0) == (side < 0)
        col = (255, 80, 60) if lit else (90, 30, 40)
        layer.draw.ellipse((lx - 3, ly - 3, lx + 3, ly + 3), fill=(30, 26, 40, 255))
        layer.draw.ellipse((lx - 2, ly - 2, lx + 2, ly + 2), fill=col + (255,))
        if lit:
            layer.glow_draw.ellipse((lx - 3, ly - 3, lx + 3, ly + 3), fill=(255, 60, 40))
    # Barrier arm, raised diagonally
    base = project(x, 1.0, z - 0.2)
    tip = project(x - 2.6 * side, 3.9, z - 0.2)
    n = 8
    for k in range(n):
        a = (base[0] + (tip[0] - base[0]) * k / n, base[1] + (tip[1] - base[1]) * k / n)
        b = (base[0] + (tip[0] - base[0]) * (k + 1) / n, base[1] + (tip[1] - base[1]) * (k + 1) / n)
        layer.draw.line([a, b], fill=((240, 60, 50) if k % 2 == 0 else (250, 250, 250)) + (255,), width=2)


def _sign_text(layer, text, quad):
    xs = [p[0] for p in quad]
    ys = [p[1] for p in quad]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    # Pick the biggest font that fits, render it 1:1 and threshold for crisp pixels
    for size in range(22, 7, -1):
        font = ImageFont.truetype(str(FONT), size)
        tmp = Image.new("L", (int(x1 - x0) * 2 + 40, size * 3), 0)
        ImageDraw.Draw(tmp).text((4, size // 2), text, font=font, fill=255)
        bbox = tmp.getbbox()
        if bbox and bbox[2] - bbox[0] <= (x1 - x0) - 6 and bbox[3] - bbox[1] <= (y1 - y0) - 4:
            break
    tmp = tmp.crop(bbox).point(lambda v: 255 if v > 100 else 0)
    color = Image.new("RGBA", tmp.size, (255, 244, 220, 255))
    layer.img.paste(color, (int((x0 + x1 - tmp.width) / 2), int((y0 + y1 - tmp.height) / 2)), tmp)


def paint_ground():
    layer = Layer("05_ground.png", line_strength=0.9)
    # Near road Z 2..7.5 (drawn wider than the screen for panning), wet asphalt
    layer.quad3d([(-30, 0, 2.0), (30, 0, 2.0), (30, 0, 7.6), (-30, 0, 7.6)], (96, 86, 124))
    layer.quad3d([(-3.5, 0, 2.0), (3.5, 0, 2.0), (3.5, 0, 7.6), (-3.5, 0, 7.6)], (60, 56, 92))
    for side in (-1, 1):
        layer.line3d((3.4 * side, 0, 2.0), (3.4 * side, 0, 7.6), (200, 180, 196))
    img = np.asarray(layer.img).astype(float)
    yy, xx = np.mgrid[0:H, 0:W]
    dither = BAYER[yy % 4, xx % 4]
    # Vertical light streaks reflected in the wet road (positions of the lights above)
    streaks = [(project(4.3, 2.4, 9.0)[0], (255, 190, 110), 26), (project(-4.6, 1.3, 8.5)[0], (170, 200, 255), 16),
               (project(4.0, 2.75, 15.2)[0], (255, 90, 70), 6), (project(-4.0, 2.75, 15.2)[0], (255, 90, 70), 6),
               (CX + 70, (255, 214, 150), 40)]
    top = project(0, 0, 7.6)[1]
    for sx, col, width in streaks:
        fall = np.clip(1 - np.abs(xx - sx) / width, 0, 1) * np.clip((yy - top) / 30.0, 0, 1) * np.clip(1 - (yy - top) / 140.0, 0, 1)
        fall = np.floor(fall * 5 + dither * 0.9) / 5
        img[..., :3] += (np.array(col) - img[..., :3]) * fall[..., None] * 0.6 * (img[..., 3:] > 0)
    layer.img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    layer.draw = TrackedDraw(layer)
    # Manhole cover, drain grates along the curbs, cracks, faded centre line
    mc = project(1.2, 0, 5.0)
    rx, ry = F / 5.0 * 0.35, F / 5.0 * 0.07
    layer.draw.ellipse((mc[0] - rx, mc[1] - ry, mc[0] + rx, mc[1] + ry), fill=(70, 66, 96, 255))
    layer.draw.ellipse((mc[0] - rx + 2, mc[1] - ry + 1, mc[0] + rx - 2, mc[1] + ry - 1), fill=(86, 80, 112, 255))
    for side in (-1, 1):
        for gz in (3.0, 5.5):
            layer.quad3d([(3.05 * side, 0, gz), (3.4 * side, 0, gz), (3.4 * side, 0, gz + 0.8), (3.05 * side, 0, gz + 0.8)], (52, 48, 76))
            for k in range(5):
                layer.line3d((3.05 * side, 0, gz + 0.15 * k + 0.1), (3.4 * side, 0, gz + 0.15 * k + 0.1), (90, 84, 116))
    for k in range(3):
        layer.quad3d([(-0.06, 0, 2.2 + k * 2.0), (0.06, 0, 2.2 + k * 2.0), (0.06, 0, 3.2 + k * 2.0), (-0.06, 0, 3.2 + k * 2.0)], (120, 112, 140))
    for _ in range(6):
        cx_, cz = rng.uniform(-3, 3), rng.uniform(2.5, 7)
        pts = [project(cx_, 0, cz)]
        for _k in range(4):
            cx_ += rng.uniform(-0.4, 0.4)
            cz += rng.uniform(0.1, 0.3)
            pts.append(project(cx_, 0, cz))
        layer.draw.line(pts, fill=(44, 40, 70, 255), width=1, noline=True)
    img = np.asarray(layer.img).astype(float)
    # Puddles: irregular, mirror the sunset sky, brighter towards their far edge
    for _ in range(7):
        px, pz = rng.choice((-1, 1)) * rng.uniform(0.5, 3.4), rng.uniform(2.6, 7.0)
        m = np.zeros((H, W), bool)
        cx, cy = project(px, 0, pz)
        for k in range(3):
            ox, oz = rng.uniform(-0.6, 0.6), rng.uniform(-0.15, 0.15)
            ex, ey = project(px + ox, 0, pz + oz)
            rx, ry = F / pz * rng.uniform(0.25, 0.6), F / pz * rng.uniform(0.03, 0.06)
            m |= ((xx - ex) / rx) ** 2 + ((yy - ey) / ry) ** 2 < 1
        t = np.clip((yy - cy + 8) / 16.0, 0, 1)
        t = np.floor(t * 4 + dither * 0.9) / 4
        sky = np.array((255, 196, 150)) * (1 - t[..., None]) + np.array((110, 80, 150)) * t[..., None]
        img[m, :3] = sky[m] * 0.6 + img[m, :3] * 0.4
    layer.img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    layer.draw = TrackedDraw(layer)
    layer.finish(0.5)


def paint_foreground(near_tops):
    img = Image.new("RGBA", (W + 200, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Big utility pole very close on the right with wires across the top of the frame
    px = 805
    d.rectangle((px - 14, 0, px + 14, H), fill=(36, 30, 54, 255))
    d.rectangle((px - 14, 0, px - 11, H), fill=(120, 80, 100, 255))  # rim light
    d.rectangle((px - 60, 40, px + 60, 47), fill=(36, 30, 54, 255))
    d.rectangle((px - 60, 40, px + 60, 41), fill=(200, 130, 110, 255))
    for k, y in enumerate((44, 44, 44, 70, 90)):
        x_end = [100, 240, 380, 0, 160][k]
        y_end = [150, 128, 118, 160, 110][k]
        pts = []
        for i in range(31):
            t = i / 30
            x = px - 50 + k * 20 + (x_end - (px - 50 + k * 20)) * t
            y_ = y + (y_end - y) * t + 26 * 4 * t * (1 - t)
            pts.append((x, y_))
        d.line(pts, fill=(30, 26, 46, 255), width=2 if k < 3 else 1)
    # Leaves at the top-left corner, backlit
    leaves_pal = [(26, 40, 52), (36, 58, 62), (52, 84, 70), (92, 120, 80)]
    blobs = [(rng.uniform(60, 260), rng.uniform(-20, 50), rng.uniform(16, 30)) for _ in range(26)]
    arr = shaded_blobs((W + 200, H), blobs, (0.7, 0.7), leaves_pal, (230, 200, 120), 0.06)
    img.alpha_composite(Image.fromarray(arr, "RGBA"))
    img.save(BG / "06_foreground.png")


def paint_train():
    # Commuter train seen side-on at Z 17: ~68 px tall, 3 cars
    car_w, h = 340, 68
    img = Image.new("RGBA", (car_w * 3 + 6, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for c in range(3):
        x0 = c * (car_w + 3)
        d.rectangle((x0, 4, x0 + car_w, h - 8), fill=(170, 160, 190, 255))
        d.rectangle((x0, 4, x0 + car_w, 7), fill=(220, 190, 190, 255))  # roof rim light
        d.rectangle((x0, h - 22, x0 + car_w, h - 18), fill=(80, 130, 200, 255))  # stripe
        d.rectangle((x0, h - 8, x0 + car_w, h - 4), fill=(60, 52, 78, 255))  # underframe
        for wx in range(x0 + 16, x0 + car_w - 20, 26):
            d.rectangle((wx, 16, wx + 18, 34), fill=(255, 216, 150, 255))
            if rng.random() < 0.5:  # passenger silhouettes
                d.rectangle((wx + 5, 24, wx + 10, 34), fill=(120, 90, 100, 255))
        for dx in (60, car_w - 80):
            d.rectangle((x0 + dx, 12, x0 + dx + 14, h - 10), fill=(120, 116, 150, 255))  # doors
        for wx in (x0 + 30, x0 + car_w - 40):
            d.ellipse((wx - 5, h - 9, wx + 5, h - 1), fill=(40, 34, 50, 255))
    img.save(BG / "03_train.png")


if __name__ == "__main__":
    BG.mkdir(parents=True, exist_ok=True)
    paint_sky()
    paint_far()
    street_tops = paint_street()
    near_tops = paint_mid(street_tops)
    paint_ground()
    paint_foreground(near_tops)
    paint_train()
    print("anime background layers written to", BG)
