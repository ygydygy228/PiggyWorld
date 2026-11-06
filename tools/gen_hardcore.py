"""Графика режима выживания: волк, костёр, иконки еды и предметов.
Запуск: python3 tools/gen_hardcore.py -> assets/sprites/animals/wolf.png, assets/objects/campfire.png, assets/icons/*.png"""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixel_lib import Canvas, rgb
ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets')
OUT = rgb('#2b2530')
OUTI = rgb('#2f2a2a')

def shadow(c, cx, cy, rx, ry):
    for y in range(cy - ry - 1, cy + ry + 2):
        for x in range(cx - rx - 1, cx + rx + 2):
            nx, ny = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            if nx * nx + ny * ny <= 1 and c_alpha(c, x, y) == 0: c.set(x, y, (20, 40, 30, 70))
def c_alpha(c, x, y): return c.get(x, y)[3]

def leg(c, x, top, w, col, lift=0):
    h = 28 - top - lift
    if h > 0:
        c.rect(x, top, w, h, col); c.rect(x, 28 - lift - 1, w, 1, rgb('#3a3a44'))

def wolf(anim, f):
    c = Canvas(32, 32)
    G, GS, GL = rgb('#868b96'), rgb('#5f646f'), rgb('#aab0bb')
    bob = 0; hdx = 0; open_mouth = False; lifts = [0, 0, 0, 0]
    if anim == 'idle':
        bob = [0, 0, 1, 0][f]; open_mouth = f == 2
    elif anim == 'walk':
        ph = f / 4 * 2 * math.pi
        lift = lambda o: int(round(max(0.0, math.sin(ph + o)) * 2))
        lifts = [lift(0), lift(math.pi), lift(math.pi), lift(0)]; bob = -int(round(abs(math.sin(ph))))
    elif anim == 'attack':
        hdx = [0, 2, 4, 2][f]; open_mouth = f in (1, 2, 3); bob = -1 if f == 2 else 0
    top = 22 + bob
    leg(c, 10, top, 2, GS, lifts[1]); leg(c, 19, top, 2, GS, lifts[3])
    c.ellipse(4, 19 + bob, 3.4, 2.4, G, GS, GL)                # хвост
    c.ellipse(13, 18 + bob, 9.4, 5, G, GS, GL)
    c.ellipse(19, 20 + bob, 4, 3, GL, G, None)                 # грудь
    leg(c, 7, top, 2, G, lifts[0]); leg(c, 16, top, 2, G, lifts[2])
    hx, hy = 23 + hdx, 14 + bob
    for ex in (hx - 3, hx + 1):                                # уши
        for i in range(4): c.rect(ex + (3 - i) // 2 * 0 + (1 if i else 0), hy - 8 + i, 3 - i // 2, 1, GS)
        c.set(ex + 1, hy - 6, rgb('#d98a9a'))
    c.ellipse(hx, hy, 5.2, 4.4, G, GS, GL)
    c.ellipse(hx + 4.5, hy + 2, 3.6, 2.3, GL, G, None, 0.3)
    c.rect(hx + 7, hy + 1, 2, 2, rgb('#1e1a1e'))
    c.rect(hx + 2, hy - 1, 2, 2, rgb('#e8402a')); c.set(hx + 2, hy - 1, rgb('#ffb84a'))   # глаз
    c.rect(hx, hy - 2, 4, 1, GS)                               # бровь
    if open_mouth:
        c.rect(hx + 3, hy + 3, 6, 2, rgb('#7a2a3a')); c.set(hx + 4, hy + 3, WHITE); c.set(hx + 8, hy + 3, WHITE)
    c.outline(OUT); shadow(c, 14, 29, 10, 2)
    return c
WHITE = rgb('#ffffff')

def build_wolf():
    sheet = Canvas(128, 128)
    for r, (anim, n) in enumerate((('idle', 4), ('walk', 4), ('attack', 4))):
        for f in range(n): sheet.paste(wolf(anim, f), f * 32, r * 32)
    sheet.img.save(os.path.join(ROOT, 'sprites', 'animals', 'wolf.png'))

def campfire_frame(i):
    c = Canvas(20, 24)
    # камни по кругу
    for x, y in ((3, 19), (6, 21), (10, 22), (14, 21), (17, 19), (4, 16), (16, 16)):
        c.ellipse(x, y, 2.2, 1.8, rgb('#8d949a'), rgb('#646b72'), rgb('#b4bbc0'))
    wood, wd = rgb('#7a4f2e'), rgb('#5c3a22')
    ash = i == 3
    wc, wdc = (rgb('#3a3236'), rgb('#2a2428')) if ash else (wood, wd)
    for k in range(5): c.rect(4 + k, 17 + k // 2 + 1, 4, 2, wc)          # левое бревно
    for k in range(5): c.rect(11 + k, 19 - k // 2, 4, 2, wdc)            # правое бревно
    c.rect(6, 19, 8, 2, wc)
    if ash:
        for x, y in ((7, 17), (11, 18), (9, 16)): c.set(x, y, rgb('#c0501e'))
    else:
        h = [11, 13, 12][i]
        sway = [0, 1, -1][i]
        for k in range(h):
            y = 18 - h + k
            t = k / (h - 1)
            half = int(round(1 + 3.2 * t ** 0.85))
            off = sway if t < 0.5 else 0
            c.rect(10 - half + off, y, half * 2, 1, rgb('#e8402a'))
            if t > 0.18:
                ih = max(1, int(round(half * 0.68)))
                c.rect(10 - ih + off // 2, y, ih * 2, 1, rgb('#f6902c'))
            if t > 0.45:
                ch = max(1, int(round(half * 0.38)))
                c.rect(10 - ch, y, ch * 2, 1, rgb('#ffe27a'))
    c.outline(OUT)
    return c

def build_campfire():
    sheet = Canvas(80, 24)
    for i in range(4): sheet.paste(campfire_frame(i), i * 20, 0)
    sheet.img.save(os.path.join(ROOT, 'objects', 'campfire.png'))

def icon(name, fn):
    c = Canvas(16, 16); fn(c); c.outline(OUTI)
    c.img.save(os.path.join(ROOT, 'icons', name + '.png'))

def meat(c, cooked=False):
    m, ms, ml = (rgb('#a8522e'), rgb('#7a3a1e'), rgb('#c97a4a')) if cooked else (rgb('#d9605a'), rgb('#a8403c'), rgb('#f08a84'))
    c.ellipse(7, 7, 5.2, 4.4, m, ms, ml, 0.35, -0.35)
    c.rect(11, 9, 3, 2, rgb('#f2ead6')); c.rect(13, 8, 2, 4, rgb('#f2ead6')); c.rect(12, 10, 2, 2, rgb('#d9cfb6'))
    if cooked:
        for x, y in ((5, 5), (8, 8), (6, 9)): c.set(x, y, rgb('#5a2a14'))
    else: c.set(5, 6, rgb('#ffd0cc')); c.set(6, 6, rgb('#ffd0cc'))

def fried_egg(c):
    c.ellipse(8, 9, 6, 4.6, rgb('#fff6e0'), rgb('#e6d9bc'), None, 0.5)
    c.ellipse(8, 8, 2.6, 2.4, rgb('#f6b82a'), rgb('#e08a14'), rgb('#ffd860'), 0.4, -0.3)

def roasted(c, col, dark, tip):
    for i in range(9):
        w = max(1, 5 - i // 2); c.rect(8 - w // 2 - 1 + i // 4, 5 + i, w + 1, 1, col)
    c.rect(5, 4, 6, 2, col); c.rect(5, 4, 6, 1, tip); c.set(7, 8, dark); c.set(8, 11, dark); c.set(6, 6, dark)
    for x, y in ((6, 3), (7, 2), (8, 1), (9, 2), (10, 3), (8, 3)): c.set(x, y, rgb('#4f7a3a'))

def rot(c):
    c.ellipse(8, 9, 5.5, 4.2, rgb('#6a7a3a'), rgb('#4a5a24'), rgb('#8a9a52'), 0.3, -0.4)
    for x, y in ((5, 8), (9, 10), (7, 11)): c.rect(x, y, 2, 1, rgb('#3a4a1c'))
    c.set(12, 4, rgb('#2a2a2a')); c.set(4, 5, rgb('#2a2a2a')); c.set(11, 6, rgb('#2a2a2a'))

def salve(c):
    c.rect(4, 6, 8, 8, rgb('#7ab0d8')); c.rect(4, 6, 8, 2, rgb('#9ccae8')); c.rect(4, 12, 8, 2, rgb('#5a8cb8'))
    c.rect(3, 3, 10, 3, rgb('#a9754a')); c.rect(3, 3, 10, 1, rgb('#c79566'))
    c.rect(6, 8, 4, 3, rgb('#5fb356')); c.set(7, 9, rgb('#a0e090')); c.set(8, 7, rgb('#e8504a'))

def spear(c):
    for i in range(12): c.set(3 + i, 13 - i, rgb('#a9754a')); c.set(4 + i, 13 - i, rgb('#7d5233'))
    for x, y in ((12, 2), (13, 1), (13, 2), (14, 1), (12, 3), (13, 3), (14, 2), (11, 3)): c.set(x, y, rgb('#b4bbc0'))
    c.set(14, 1, rgb('#e8edf0')); c.set(13, 1, rgb('#e8edf0'))

def vest(c):
    w, ws, wl = rgb('#e8e0cc'), rgb('#bcb39c'), rgb('#ffffff')
    c.ellipse(8, 8, 6, 6, w, ws, wl, 0.4, -0.4)
    c.rect(2, 3, 4, 5, w); c.rect(10, 3, 4, 5, w)
    c.rect(6, 2, 4, 5, rgb('#bcb39c'))           # вырез
    c.rect(7, 7, 2, 7, rgb('#bcb39c'))
    c.set(5, 9, ws); c.set(10, 10, ws); c.set(4, 12, ws)

def main():
    os.makedirs(os.path.join(ROOT, 'icons'), exist_ok=True)
    build_wolf(); build_campfire()
    icon('meat', lambda c: meat(c, False)); icon('cooked_meat', lambda c: meat(c, True)); icon('fried_egg', fried_egg)
    icon('roasted_carrot', lambda c: roasted(c, rgb('#c8702a'), rgb('#7a3a14'), rgb('#e0954a')))
    icon('roasted_turnip', lambda c: roasted(c, rgb('#b894a8'), rgb('#7a5a70'), rgb('#d8b8c8')))
    icon('rot', rot); icon('salve', salve); icon('spear', spear); icon('vest', vest)
    print('hardcore art ok')

if __name__ == '__main__':
    main()
