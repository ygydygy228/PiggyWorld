"""Мостик и вход в пещеру. Запуск: python3 tools/gen_extra.py"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixel_lib import Canvas, rgb
d = os.path.join(os.path.dirname(__file__), '..', 'assets', 'objects')
# мостик 16x16: горизонтальные доски
c = Canvas(16, 16)
w, wd, wl = rgb('#b9814f'), rgb('#8a5c36'), rgb('#d29d68')
for y in range(0, 16, 4):
    c.rect(0, y, 16, 3, w); c.rect(0, y, 16, 1, wl); c.rect(0, y + 3, 16, 1, wd)
c.rect(0, 0, 1, 16, wd); c.rect(15, 0, 1, 16, wd)
for y in (1, 5, 9, 13): c.set(3, y + 1, wd); c.set(12, y + 1, wd)
c.img.save(os.path.join(d, 'bridge.png'))
# пещера 56x44
c = Canvas(56, 44)
G, GD, GL = rgb('#8b949a'), rgb('#626b72'), rgb('#b9c1c5')
c.ellipse(28, 28, 26, 17, G, GD, GL, 0.35, -0.4)
c.ellipse(14, 24, 11, 10, rgb('#9aa3a8'), GD, GL, 0.35, -0.4)
c.ellipse(43, 25, 11, 10, rgb('#9aa3a8'), GD, GL, 0.35, -0.4)
# тёмный вход
for y in range(22, 42):
    half = 9 if y > 28 else 5 + (y - 22) * 4 // 6
    for x in range(28 - half, 28 + half):
        c.set(x, y, rgb('#1b1620') if y < 38 else rgb('#2a2330'))
c.rect(19, 36, 18, 3, rgb('#3a3140'))
for x, y in ((12, 20), (36, 14), (46, 22), (20, 12)): c.set(x, y, GD); c.set(x + 1, y, GD)
c.outline(rgb('#3a4348'))
# тень
for y in range(40, 44):
    for x in range(4, 52):
        if c.get(x, y)[3] == 0 and ((x - 28) / 26.0) ** 2 + ((y - 42) / 3.0) ** 2 <= 1: c.set(x, y, (20, 40, 30, 70))
c.img.save(os.path.join(d, 'cave.png'))
print('extra ok')
