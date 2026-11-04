"""Растровый пиксельный шрифт (латиница+кириллица) в формате BMFont. Основа: DejaVu Sans (свободная лицензия).
Запуск: python3 tools/gen_font.py"""
import os
from PIL import Image, ImageDraw, ImageFont
SIZE = 11
CAND = ['/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']
path = next(p for p in CAND if os.path.exists(p))
font = ImageFont.truetype(path, SIZE)
chars = list(range(32, 127)) + list(range(0x410, 0x450)) + [0x401, 0x451, 0x2116, 0xB7, 0xD7]
W, H = 256, 128
img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img); d.fontmode = '1'
x = y = 1; row_h = SIZE + 4
lines = []
for cp in chars:
    ch = chr(cp)
    adv = int(round(font.getlength(ch)))
    gw = max(adv, 1) + 1
    if x + gw + 1 >= W:
        x = 1; y += row_h
    d.text((x, y), ch, font=font, fill=(255, 255, 255, 255))
    lines.append(f'char id={cp} x={x} y={y} width={gw} height={row_h} xoffset=0 yoffset=0 xadvance={adv + 1} page=0 chnl=15')
    x += gw + 2
out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fonts'); os.makedirs(out, exist_ok=True)
# убрать полупрозрачность: жёсткие пиксели
px = img.load()
for yy in range(H):
    for xx in range(W):
        r, g, b, a = px[xx, yy]
        px[xx, yy] = (255, 255, 255, 255 if a > 100 else 0)
img.save(os.path.join(out, 'pixel.png'))
fnt = [f'info face="pixel" size={SIZE} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0',
       f'common lineHeight={row_h} base={SIZE} scaleW={W} scaleH={H} pages=1 packed=0',
       'page id=0 file="pixel.png"', f'chars count={len(lines)}'] + lines
open(os.path.join(out, 'pixel.fnt'), 'w').write('\n'.join(fnt) + '\n')
print('font ok', len(lines), 'glyphs, last y', y)
