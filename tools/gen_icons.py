"""Иконки предметов 16x16. Запуск: python3 tools/gen_icons.py -> assets/icons/*.png"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixel_lib import Canvas, rgb
T = 16
OUTC = rgb('#2f2a2a')
BR, BRD, BRL = rgb('#a9754a'), rgb('#7d5233'), rgb('#c79566')
GR, GRD, GRL = rgb('#a7b0b5'), rgb('#6f797e'), rgb('#d5dcdf')

def line(c, x0, y0, x1, y1, col):
    dx, dy = abs(x1 - x0), -abs(y1 - y0); sx = 1 if x0 < x1 else -1; sy = 1 if y0 < y1 else -1; err = dx + dy
    while True:
        c.set(x0, y0, col)
        if x0 == x1 and y0 == y1: break
        e2 = 2 * err
        if e2 >= dy: err += dy; x0 += sx
        if e2 <= dx: err += dx; y0 += sy

def axe():
    c = Canvas(T, T); line(c, 3, 13, 11, 5, BR); line(c, 4, 13, 12, 5, BRD)
    c.rect(9, 2, 5, 5, GR); c.rect(9, 2, 5, 1, GRL); c.rect(13, 3, 1, 4, GRD); c.set(9, 6, GRD)
    c.outline(OUTC); return c
def pickaxe():
    c = Canvas(T, T); line(c, 3, 14, 11, 6, BR); line(c, 4, 14, 12, 6, BRD)
    for x, y in ((4, 5), (5, 4), (6, 3), (7, 3), (8, 3), (9, 3), (10, 4), (11, 5), (12, 6), (13, 7)): c.set(x, y, GR)
    for x, y in ((6, 4), (7, 4), (8, 4), (9, 4)): c.set(x, y, GRL)
    c.set(4, 6, GRD); c.set(13, 8, GRD); c.outline(OUTC); return c
def hoe():
    c = Canvas(T, T); line(c, 3, 14, 12, 4, BR); line(c, 4, 14, 13, 4, BRD)
    c.rect(10, 2, 5, 2, GR); c.rect(13, 3, 2, 4, GR); c.rect(10, 2, 5, 1, GRL); c.set(14, 6, GRD)
    c.outline(OUTC); return c
def can():
    c = Canvas(T, T); blue, bd, bl = rgb('#5b9bd5'), rgb('#3f74a8'), rgb('#9cc8ee')
    c.rect(3, 6, 8, 7, blue); c.rect(3, 6, 8, 1, bl); c.rect(3, 12, 8, 1, bd); c.rect(10, 7, 1, 6, bd)
    line(c, 11, 10, 14, 5, blue); line(c, 12, 10, 15, 5, bd); c.rect(14, 3, 2, 2, bl)
    for x, y in ((4, 4), (5, 3), (6, 3), (7, 4), (8, 5)): c.set(x, y, GRD)
    c.outline(OUTC); return c
def seeds():
    c = Canvas(T, T); tan, td = rgb('#d9bd7a'), rgb('#b0925a')
    c.ellipse(8, 10, 5, 4.5, tan, td, rgb('#efdca3')); c.rect(6, 5, 4, 2, td)
    c.set(8, 3, rgb('#4f9e4a')); c.set(7, 4, rgb('#76c364')); c.set(9, 4, rgb('#76c364'))
    c.set(7, 10, rgb('#6a5230')); c.set(9, 11, rgb('#6a5230'))
    c.outline(OUTC); return c
def wood():
    c = Canvas(T, T); c.rect(2, 7, 12, 4, BR); c.rect(2, 7, 12, 1, BRL); c.rect(2, 10, 12, 1, BRD)
    c.rect(3, 3, 11, 4, BRD); c.rect(3, 3, 11, 1, BR)
    c.ellipse(13, 9, 1.8, 2.2, BRL, None, None); c.set(13, 9, BRD)
    c.outline(OUTC); return c
def stone():
    c = Canvas(T, T); c.ellipse(8, 9, 6, 4.5, GR, GRD, GRL, 0.2, -0.3); c.ellipse(5, 7, 3, 2.5, rgb('#b6bec2'), GRD, GRL)
    c.outline(OUTC); return c
def berries():
    c = Canvas(T, T); red, rl = rgb('#d63a5a'), rgb('#ff7f96')
    for x, y in ((5, 9), (10, 9), (8, 5)):
        c.ellipse(x, y, 3, 3, red, rgb('#a82444'), rl, 0.3, -0.3)
    c.rect(7, 2, 3, 1, rgb('#4f9e4a')); c.set(6, 3, rgb('#4f9e4a'))
    c.outline(OUTC); return c
def carrot():
    c = Canvas(T, T); o, od, ol = rgb('#f08a2c'), rgb('#c96a14'), rgb('#ffb15c')
    for i in range(10):
        w = max(1, 5 - i // 2); c.rect(8 - w // 2 - 1 + (1 if i > 5 else 0) + i // 5, 4 + i, w + 1, 1, o)
    c.rect(5, 4, 6, 2, o); c.rect(5, 4, 6, 1, ol); c.set(7, 8, od); c.set(8, 10, od)
    for x, y in ((6, 3), (7, 2), (8, 1), (9, 2), (10, 3), (8, 3)): c.set(x, y, rgb('#5fb356'))
    c.outline(OUTC); return c
def coin():
    c = Canvas(T, T); c.ellipse(8, 8, 5.5, 5.5, rgb('#f4c542'), rgb('#d19a1f'), rgb('#ffe38a'), 0.4, -0.5)
    c.rect(7, 5, 2, 6, rgb('#b27c14')); c.outline(OUTC); return c
def flower():
    c = Canvas(T, T); r, ce = rgb('#e8504a'), rgb('#ffe27a')
    for dx, dy in ((0, -2), (-2, 0), (2, 0), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)): c.rect(7 + dx, 6 + dy, 2, 2, r)
    c.rect(7, 6, 2, 2, ce); c.rect(7, 10, 2, 5, rgb('#3f8a3f')); c.outline(OUTC); return c

# ---------------------------------------------------------------- интерфейс

def stat_health():
    c = Canvas(T, T); r, rd, rl = rgb('#e0504a'), rgb('#a8302c'), rgb('#ff9288')
    c.ellipse(5, 6, 3.4, 3.2, r, rd, None, 0.6, -0.7)
    c.ellipse(11, 6, 3.4, 3.2, r, rd, None, 0.6, -0.7)
    for i in range(7):
        w = 11 - i * 1.5
        c.rect(int(round(8 - w / 2)), 7 + i, max(1, int(round(w))), 1, r)
    c.set(4, 5, rl); c.set(5, 4, rl); c.set(3, 7, rl)
    c.outline(OUTC); return c

def stat_food():
    c = Canvas(T, T); m, md, ml = rgb('#c9713c'), rgb('#8e4a22'), rgb('#e8a266')
    b, bd, bl = rgb('#f2e6cf'), rgb('#c8b89c'), rgb('#ffffff')
    c.ellipse(7, 8, 5.2, 4.6, m, md, ml, 0.5, -0.6)  # мясо
    c.rect(11, 9, 2, 2, m); c.rect(12, 10, 2, 2, m)
    c.rect(12, 11, 2, 1, md)
    c.rect(3, 11, 4, 2, b); c.set(3, 11, bl); c.rect(2, 10, 2, 4, b)  # кость
    c.set(3, 10, bd); c.set(2, 13, bd)
    c.outline(OUTC); return c

def stat_sanity():
    c = Canvas(T, T); p, pd, pl = rgb('#9a6ad8'), rgb('#6a3fa8'), rgb('#c8a8f0')
    c.ellipse(8, 8, 5.6, 5.4, p, pd, pl, 0.4, -0.6)  # мозг
    for x, y in ((6, 6), (9, 6), (7, 8), (10, 8), (6, 10), (9, 10), (11, 7)):
        c.set(x, y, pd)
    c.rect(7, 3, 2, 1, pd); c.set(8, 2, pd)
    c.outline(OUTC); return c

def ui_menu():
    c = Canvas(T, T); g, gd, gl = rgb('#b9c2c8'), rgb('#6f797e'), rgb('#e2eaee')
    c.ellipse(8, 8, 4.6, 4.6, g, gd, gl)
    for dx, dy in ((0, -5), (0, 5), (-5, 0), (5, 0), (-4, -4), (4, -4), (-4, 4), (4, 4)):
        c.rect(7 + dx, 7 + dy, 2, 2, g)
    c.ellipse(8, 8, 1.6, 1.6, rgb('#3b2a24'))
    c.outline(OUTC); return c

def ui_build():
    c = Canvas(T, T); h, hd, hl = rgb('#c9d0d4'), rgb('#7d868b'), rgb('#eef3f6')
    c.rect(2, 4, 9, 5, h); c.rect(2, 4, 9, 1, hl); c.rect(2, 8, 9, 1, hd)
    c.rect(10, 3, 2, 7, hd); c.rect(11, 4, 1, 5, hd)
    c.rect(4, 9, 1, 1, hd); c.rect(9, 9, 1, 1, hd)
    line(c, 11, 10, 14, 14, BR); line(c, 12, 10, 15, 14, BRD)
    c.outline(OUTC); return c

def ui_bag():
    c = Canvas(T, T); b, bd, bl = rgb('#a9754a'), rgb('#7d5233'), rgb('#c79566')
    c.ellipse(8, 9, 5.4, 4.8, b, bd, bl)
    c.rect(4, 3, 8, 2, bd)          # клапан
    c.rect(6, 1, 4, 2, bd)          # лямка
    c.rect(4, 8, 8, 1, bd)          # ремень
    c.rect(7, 7, 2, 3, rgb('#f4c542'))  # пряжка
    c.outline(OUTC); return c

def main():
    d = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icons'); os.makedirs(d, exist_ok=True)
    for n, f in (('axe', axe), ('pickaxe', pickaxe), ('hoe', hoe), ('can', can), ('seeds', seeds), ('wood', wood), ('stone', stone),
                 ('berries', berries), ('carrot', carrot), ('coin', coin), ('flower', flower),
                 ('stat_health', stat_health), ('stat_food', stat_food), ('stat_sanity', stat_sanity),
                 ('ui_menu', ui_menu), ('ui_build', ui_build), ('ui_bag', ui_bag)):
        f().img.save(os.path.join(d, n + '.png'))
    print('icons ok')
if __name__ == '__main__': main()
