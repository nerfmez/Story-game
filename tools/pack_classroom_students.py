"""Mechanically crop imagegen's 2x2 turnarounds into four aligned RGBA frames.

Input JSON maps each character to {"path": PNG, "order": [front, back, left, right]}.
Order values are cell indices (0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right).
This does not redraw, recolor or replace any generated pixels; scaling is nearest.
"""
from pathlib import Path
import argparse
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def pack(source, order, target, mirror_left=False):
    sheet = Image.open(source).convert('RGBA')
    atlas = Image.new('RGBA', (640, 192))
    for frame, cell_index in enumerate(order):
        col, row = cell_index % 2, cell_index // 2
        cell = sheet.crop((round(col * sheet.width / 2), round(row * sheet.height / 2),
                           round((col + 1) * sheet.width / 2), round((row + 1) * sheet.height / 2)))
        # Ignore nearly transparent pixels when measuring the visible silhouette.
        mask = cell.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
        if mask.histogram()[0] < cell.width * cell.height * 0.4:
            raise ValueError(f'Expected isolated transparent character: {source}, {cell_index}')
        bounds = mask.getbbox()
        if bounds is None:
            raise ValueError(f'Empty cell: {source}, {cell_index}')
        sprite = cell.crop(bounds)
        scale = 180 / sprite.height
        sprite = sprite.resize((round(sprite.width * scale), 180), Image.Resampling.NEAREST)
        # Profile hips are behind the horizontal thighs, not at bbox centre.
        anchor = sprite.width * (0.24 if frame == 2 and mirror_left else 0.76 if frame == 2 else 0.24 if frame == 3 else 0.5)
        if sprite.width > 160:
            raise ValueError(f'Profile exceeds frame: {source}, {cell_index}')
        x = max(0, min(round(80 - anchor), 160 - sprite.width))
        atlas.paste(sprite, (frame * 160 + x, 4))
    target.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(target, optimize=True)
    print(target.relative_to(ROOT))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    args = parser.parse_args()
    for name, source in json.loads(args.manifest.read_text()).items():
        pack(source['path'], source['order'], ROOT / 'assets/classroom/students' / f'{name}.png', source.get('mirror_left', False))


if __name__ == '__main__':
    main()
