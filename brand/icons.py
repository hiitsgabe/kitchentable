#!/usr/bin/env python3
"""Rebuilds every icon and both logos from brand/mark.png.

Run it from anywhere; it writes in place, over the icons in web/, android/
and ios/. The only input is the mark, so changing the mark and running this
is the whole job.

    python3 brand/icons.py

Needs Pillow. The mark is four cards laid around a table seen from above,
which is the app: a few people, one table, everybody facing in.
"""
import json
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, 'brand')
FONT = os.path.join(ROOT, 'fonts', 'PixelifySans.ttf')

GROUND = (7, 6, 10)      # Palette.felt
INK = (244, 241, 246)    # Palette.ink
PINK = (255, 46, 136)    # Palette.accent
OUTLINE = (18, 23, 26)   # Palette.outline


def square(mark, size, margin):
    """The mark centred on a square of [size], leaving [margin] of air."""
    room = int(size * (1 - margin * 2))
    scale = room / max(mark.size)
    small = mark.resize(
        (max(1, round(mark.width * scale)), max(1, round(mark.height * scale))),
        Image.LANCZOS,
    )
    out = Image.new('RGB', (size, size), GROUND)
    out.paste(small, ((size - small.width) // 2, (size - small.height) // 2))
    return out


def icons(mark):
    web = os.path.join(ROOT, 'web')
    square(mark, 192, 0.06).save(f'{web}/icons/Icon-192.png')
    square(mark, 512, 0.06).save(f'{web}/icons/Icon-512.png')
    square(mark, 180, 0.06).save(f'{web}/icons/apple-touch-icon.png')
    square(mark, 32, 0.06).save(f'{web}/favicon.png')

    # Android crops a maskable icon to a circle inside the middle eighty
    # percent, so these need the air the others do not want.
    square(mark, 192, 0.20).save(f'{web}/icons/Icon-maskable-192.png')
    square(mark, 512, 0.20).save(f'{web}/icons/Icon-maskable-512.png')

    # One .ico carrying the three sizes that still get asked for.
    square(mark, 48, 0.06).save(
        f'{web}/favicon.ico', sizes=[(16, 16), (32, 32), (48, 48)]
    )

    res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
    for density, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                        ('xxhdpi', 144), ('xxxhdpi', 192)]:
        square(mark, px, 0.06).save(f'{res}/mipmap-{density}/ic_launcher.png')

    # iOS wants a file per slot, and the catalog already lists which.
    app = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets',
                       'AppIcon.appiconset')
    for slot in json.load(open(f'{app}/Contents.json'))['images']:
        name = slot.get('filename')
        if not name:
            continue
        px = round(float(slot['size'].split('x')[0])
                   * float(slot['scale'].rstrip('x')))
        square(mark, px, 0.06).save(f'{app}/{name}')


def wordmark(mark, size=150, pad=40, gap=46, stacked=False):
    """The mark and the name, in the face the app itself draws the name in.

    Drawn rather than generated: the title screen uses this font, so this is
    the same shapes rather than something close to them.
    """
    font = ImageFont.truetype(FONT, size)
    font.set_variation_by_axes([700])

    rule = ImageDraw.Draw(Image.new('RGB', (1, 1)))
    first = rule.textlength('kitchen', font=font)
    text_w = round(first + rule.textlength('table', font=font))

    tall = round(size * 1.45)
    wide = round(mark.width * tall / mark.height)
    badge = mark.resize((wide, tall), Image.LANCZOS)
    line = round(size * 1.35)

    if stacked:
        w, h = max(wide, text_w) + pad * 2, tall + gap + line + pad * 2
    else:
        w, h = wide + gap + text_w + pad * 2, max(tall, line) + pad * 2

    img = Image.new('RGB', (w, h), GROUND)
    draw = ImageDraw.Draw(img)

    if stacked:
        img.paste(badge, ((w - wide) // 2, pad))
        x, y = (w - text_w) // 2, pad + tall + gap
    else:
        img.paste(badge, (pad, (h - tall) // 2))
        x, y = pad + wide + gap, (h - line) // 2

    # The same hard offset shadows the slabs carry, so the logo and the
    # buttons in the app are lit from the same place.
    drop = round(size * 0.055)
    for dx, dy in ((0, drop), (drop, drop), (-drop, drop)):
        draw.text((x + dx, y + dy), 'kitchen', font=font, fill=OUTLINE)
        draw.text((x + first + dx, y + dy), 'table', font=font, fill=OUTLINE)
    draw.text((x, y), 'kitchen', font=font, fill=INK)
    draw.text((x + first, y), 'table', font=font, fill=PINK)
    return img


if __name__ == '__main__':
    mark = Image.open(os.path.join(BRAND, 'mark.png')).convert('RGB')
    icons(mark)
    wordmark(mark).save(os.path.join(BRAND, 'logo-wide.png'))
    wordmark(mark, stacked=True).save(os.path.join(BRAND, 'logo-stacked.png'))
    print('icons and logos rebuilt from brand/mark.png')
