"""Новые предметы и культуры: яйцо, молоко, шерсть, репа, тыква, пакеты семян, стадии роста.
Запуск: python3 tools/gen_items.py -> assets/icons/*.png, assets/objects/crop_*_*.png"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixel_lib import Canvas, rgb
T = 16
OUTC = rgb('#2f2a2a')
ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets')

def egg():
    c = Canvas(T, T); c.ellipse(8, 9, 4.6, 5.6, rgb('#f6ead0'), rgb('#d9c7a0'), rgb('#ffffff'), 0.35, -0.4)
    c.outline(OUTC); return c

def milk():
    c = Canvas(T, T); w, ws = rgb('#f4f6fa'), rgb('#cdd6e6')
    c.rect(6, 2, 4, 3, w); c.rect(5, 1, 6, 2, rgb('#5b9bd5'))
    c.rect(4, 5, 8, 9, w); c.rect(4, 12, 8, 2, ws); c.rect(10, 5, 2, 9, ws)
    c.rect(5, 7, 5, 3, rgb('#8fc0ea')); c.set(7, 8, rgb('#ffffff'))
    c.outline(OUTC); return c

def wool():
    c = Canvas(T, T); w, ws, wl = rgb('#f4f1e8'), rgb('#cfc9ba'), rgb('#ffffff')
    for x, y, r in ((5, 9, 3.5), (10, 9, 3.5), (8, 6, 4), (8, 11, 4)):
        c.ellipse(x, y, r, r, w, ws, wl, 0.35, -0.4)
    c.outline(OUTC); return c

def turnip():
    c = Canvas(T, T)
    for x, y in ((6, 4), (7, 3), (8, 2), (9, 3), (10, 4), (8, 4)): c.set(x, y, rgb('#5fb356'))
    c.ellipse(8, 10, 5, 4.6, rgb('#f2ecf4'), rgb('#cfc3d6'), rgb('#ffffff'), 0.4, -0.4)
    c.ellipse(8, 7, 4.2, 2, rgb('#9a5ab0'), rgb('#7a3a90'), None)
    c.set(8, 14, rgb('#cfc3d6')); c.outline(OUTC); return c

def pumpkin():
    c = Canvas(T, T); o, od, ol = rgb('#f08a2c'), rgb('#c0560e'), rgb('#ffb15c')
    c.ellipse(8, 10, 6.5, 5, o, od, ol, 0.4, -0.45)
    for x in (5, 8, 11): c.rect(x, 6, 1, 8, od)
    c.rect(7, 3, 2, 3, rgb('#4f7a3a')); c.set(9, 3, rgb('#4f7a3a'))
    c.outline(OUTC); return c

def seeds(stripe):
    c = Canvas(T, T); tan, td = rgb('#d9bd7a'), rgb('#b0925a')
    c.ellipse(8, 10, 5, 4.5, tan, td, rgb('#efdca3')); c.rect(6, 5, 4, 2, td)
    c.rect(4, 9, 8, 2, rgb(stripe))
    c.set(8, 3, rgb('#4f9e4a')); c.set(7, 4, rgb('#76c364')); c.set(9, 4, rgb('#76c364'))
    c.outline(OUTC); return c

def soil_mound(c):
    c.ellipse(8, 13, 5, 2.2, rgb('#7a4f2e'), rgb('#5c3a22'), None)

def crop_turnip(stage):
    c = Canvas(T, T); soil_mound(c)
    g = rgb('#5fb356')
    if stage == 0: c.set(8, 11, rgb('#d8c070')); c.set(7, 12, rgb('#d8c070'))
    elif stage == 1: c.rect(8, 8, 1, 4, g); c.set(7, 8, rgb('#76c364')); c.set(9, 8, rgb('#76c364'))
    elif stage == 2:
        for dx, dy in ((-2, 6), (-1, 5), (0, 5), (1, 5), (2, 6), (0, 7)): c.set(8 + dx, dy, g)
        c.rect(8, 8, 1, 3, g)
    else:
        for dx, dy in ((-3, 4), (-2, 3), (-1, 3), (0, 2), (1, 3), (2, 3), (3, 4), (0, 4)): c.set(8 + dx, dy, g)
        c.ellipse(8, 10, 3.2, 2.8, rgb('#f2ecf4'), rgb('#cfc3d6'), None); c.rect(5, 8, 7, 1, rgb('#9a5ab0'))
    if stage > 0: c.outline(rgb('#3a2a1f'))
    return c

def crop_pumpkin(stage):
    c = Canvas(T, T); soil_mound(c)
    g = rgb('#4f9e4a')
    if stage == 0: c.set(8, 11, rgb('#d8c070')); c.set(7, 12, rgb('#d8c070'))
    elif stage == 1: c.rect(8, 9, 1, 3, g); c.set(7, 9, rgb('#76c364')); c.set(9, 8, rgb('#76c364')); c.set(10, 9, rgb('#76c364'))
    elif stage == 2:
        for dx, dy in ((-3, 8), (-2, 7), (-1, 7), (2, 7), (3, 8), (4, 9), (-4, 9)): c.set(8 + dx, dy, g)
        c.rect(7, 8, 3, 3, rgb('#8ccf6a'))
    else:
        c.ellipse(8, 10, 5.5, 4, rgb('#f08a2c'), rgb('#c0560e'), rgb('#ffb15c'), 0.4, -0.45)
        for x in (6, 8, 10): c.rect(x, 7, 1, 7, rgb('#c0560e'))
        c.rect(7, 4, 2, 3, rgb('#4f7a3a'))
    if stage > 0: c.outline(rgb('#3a2a1f'))
    return c

def main():
    ic = os.path.join(ROOT, 'icons'); ob = os.path.join(ROOT, 'objects')
    os.makedirs(ic, exist_ok=True); os.makedirs(ob, exist_ok=True)
    for n, f in (('egg', egg), ('milk', milk), ('wool', wool), ('turnip', turnip), ('pumpkin', pumpkin)):
        f().img.save(os.path.join(ic, n + '.png'))
    seeds('#9a5ab0').img.save(os.path.join(ic, 'seeds_turnip.png'))
    seeds('#f08a2c').img.save(os.path.join(ic, 'seeds_pumpkin.png'))
    for s in range(4):
        crop_turnip(s).img.save(os.path.join(ob, f'crop_turnip_{s}.png'))
        crop_pumpkin(s).img.save(os.path.join(ob, f'crop_pumpkin_{s}.png'))
    print('items ok')

if __name__ == '__main__':
    main()
