"""Животные и жители деревни. Запуск: python3 tools/gen_animals.py
Листы животных: assets/sprites/animals/<вид>.png (кадр 32x32, строки: idle, walk, eat, sleep; 4 колонки; смотрят вправо).
Жители: assets/sprites/npc/<имя>.png (кадр 24x32, 3 кадра: idle, idle2, talk)."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixel_lib import Canvas, rgb

OUT = rgb('#3b2a2e')
GY = 28  # земля
ANIMS = [('idle', 4), ('walk', 4), ('eat', 4), ('sleep', 2)]
EYE, WHITE = rgb('#2c1828'), rgb('#ffffff')
PINK, PINK_D = rgb('#f4a5b5'), rgb('#dd7998')

def shadow(c, cx, cy, rx, ry):
    for y in range(cy - ry - 1, cy + ry + 2):
        for x in range(cx - rx - 1, cx + rx + 2):
            nx, ny = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            if nx * nx + ny * ny <= 1 and c_alpha(c, x, y) == 0:
                c.set(x, y, (20, 40, 30, 70))

def c_alpha(c, x, y): return c.get(x, y)[3]

def leg(c, x, top, w, col, hoof, lift=0, hoof_h=1, bottom=GY):
    h = bottom - top - lift
    if h > 0:
        c.rect(x, top, w, h, col)
        c.rect(x, bottom - lift - hoof_h, w, hoof_h, hoof)

def params(anim, f, sp):
    p = {'bob': 0, 'hdx': 0, 'hdy': 0, 'lifts': [0, 0, 0, 0], 'eyes': 'open', 'tail': f % 2, 'sleep': False}
    if anim == 'idle':
        p['bob'] = [0, 0, 1, 0][f]
        if f == 2: p['eyes'] = 'closed'
    elif anim == 'walk':
        ph = f / 4 * 2 * math.pi
        lift = lambda o: int(round(max(0.0, math.sin(ph + o)) * 2))
        p['lifts'] = [lift(0), lift(math.pi), lift(math.pi), lift(0)]
        p['bob'] = -int(round(abs(math.sin(ph))))
        if sp == 'rabbit':
            p['bob'] = -int(round(abs(math.sin(ph)) * 4)); p['lifts'] = [0, 0, 0, 0]
    elif anim == 'eat':
        p['hdy'] = [0, 3, 5, 3][f]; p['hdx'] = [0, 1, 2, 1][f]
    elif anim == 'sleep':
        p['sleep'] = True; p['eyes'] = 'closed'; p['bob'] = [3, 4][f]
    return p

def eye(c, x, y, state, col=EYE):
    if state == 'closed': c.rect(x - 1, y + 1, 2, 1, col)
    else:
        c.rect(x, y, 2, 2, col); c.set(x + 1, y, WHITE)

# ---------------------------------------------------------------- виды
def cow(c, p):
    b, hx, hy = p['bob'], 25 + p['hdx'], 14 + p['bob'] + p['hdy']
    W, WS, WL = rgb('#f4f1ea'), rgb('#d6d0c3'), rgb('#ffffff')
    K, HOOF = rgb('#34343a'), rgb('#4a4040')
    L = p['lifts']
    sl = p['sleep']
    top = 22 + b
    if not sl:
        leg(c, 11, top, 2, WS, HOOF, L[1]); leg(c, 20, top, 2, WS, HOOF, L[3])
    # хвост
    for i in range(5): c.set(2, 14 + b + i, K if i < 4 else K)
    c.rect(1, 18 + b, 3, 2, K)
    c.ellipse(13, 17 + b, 10.5, 6.5, W, WS, WL)
    for sx, sy, rx, ry in ((9, 15, 3, 2.5), (17, 19, 3.2, 2.2), (19, 13.5, 2.4, 2)):
        c.ellipse(sx, sy + b, rx, ry, K)
    if not sl:
        c.ellipse(12, 22 + b, 2.2, 1.6, PINK, PINK_D)  # вымя
        leg(c, 8, top, 2, W, HOOF, L[0]); leg(c, 17, top, 2, W, HOOF, L[2])
    else:
        c.rect(8, 25 + b - 3, 3, 2, WS); c.rect(17, 25 + b - 3, 3, 2, WS)
    if sl: hy += 3; hx -= 1
    c.ellipse(22, 9 + hy - 14 + 14, 1.8, 1.4, K)  # ухо
    c.ellipse(hx, hy, 5.2, 4.6, W, WS, WL)
    c.ellipse(hx + 4, hy + 2, 2.8, 2.6, PINK, PINK_D, None, 0.3)
    c.set(hx + 4, hy + 2, rgb('#7a3550'))
    c.rect(hx - 2, hy - 5, 1, 2, rgb('#efe4c4')); c.rect(hx + 2, hy - 5, 1, 2, rgb('#efe4c4'))
    eye(c, hx + 1, hy - 1, p['eyes'])

def sheep(c, p):
    b, hx, hy = p['bob'], 24 + p['hdx'], 16 + p['bob'] + p['hdy']
    WO, WS, WL = rgb('#f4f1e8'), rgb('#d3cdbd'), rgb('#ffffff')
    D, HOOF = rgb('#55453f'), rgb('#3a2e2a')
    L, sl = p['lifts'], p['sleep']
    top = 22 + b
    if not sl:
        leg(c, 11, top, 2, D, HOOF, L[1]); leg(c, 20, top, 2, D, HOOF, L[3])
    for bx, by, rx, ry in ((14, 17, 9.5, 6.3), (8, 14, 4.5, 4), (14, 12, 5.5, 4.5), (20, 14, 4.5, 4), (9, 20, 4.2, 3.6), (19, 20, 4.2, 3.6), (4, 17, 2.8, 2.8)):
        c.ellipse(bx, by + b, rx, ry, WO, WS, WL, 0.4, -0.35)
    if not sl:
        leg(c, 8, top, 2, D, HOOF, L[0]); leg(c, 17, top, 2, D, HOOF, L[2])
    if sl: hy += 3; hx -= 1
    c.ellipse(hx - 1, hy - 1, 3.6, 3, WO, WS, WL)  # чёлка
    c.ellipse(hx + 1, hy + 1, 3.8, 3.6, D)
    c.ellipse(hx - 3, hy + 1, 1.5, 2.2, rgb('#6d5a54'))  # ухо
    eye(c, hx + 1, hy, p['eyes'], WHITE)
    c.set(hx + 4, hy + 2, rgb('#2a1f1c'))

def dog(c, p):
    b, hx, hy = p['bob'], 22 + p['hdx'], 14 + p['bob'] + p['hdy']
    B, BS, BL = rgb('#c58a4a'), rgb('#9d6a35'), rgb('#dba767')
    DK, SN, HOOF = rgb('#7a4a22'), rgb('#e6c08a'), rgb('#f2e2c4')
    L, sl = p['lifts'], p['sleep']
    top = 22 + b
    if not sl:
        leg(c, 10, top, 2, BS, HOOF, L[1]); leg(c, 19, top, 2, BS, HOOF, L[3])
    # хвост виляет
    t = p['tail']
    for i, (dx, dy) in enumerate(((0, 0), (-1, -1), (-1, -2), (-2 + t, -3), (-2 + t, -4))):
        c.rect(4 + dx, 16 + b + dy, 2, 2, B if not sl else BS)
    c.ellipse(13, 18 + b, 8.8, 4.9, B, BS, BL)
    c.ellipse(13, 21 + b, 5, 1.6, rgb('#f2e2c4'))  # пузико
    if not sl:
        leg(c, 7, top, 2, B, HOOF, L[0]); leg(c, 16, top, 2, B, HOOF, L[2])
    if sl: hy += 4; hx -= 1
    c.ellipse(hx, hy, 5.2, 4.4, B, BS, BL)
    c.ellipse(hx + 4, hy + 2, 3.2, 2.4, SN, rgb('#c9a06a'), None, 0.3)
    c.rect(hx + 6, hy + 1, 2, 2, rgb('#2a1f1c'))  # нос
    c.ellipse(hx - 2, hy - 1, 2, 3.6, DK)  # висячее ухо
    eye(c, hx + 1, hy - 1, p['eyes'])
    if p['anim'] == 'idle' and p['tail'] == 1 and not sl: c.rect(hx + 3, hy + 4, 2, 1, PINK_D)

def cat(c, p):
    b, hx, hy = p['bob'], 21 + p['hdx'], 16 + p['bob'] + p['hdy']
    B, BS, BL = rgb('#e08a3c'), rgb('#b8601e'), rgb('#f0a85c')
    L, sl = p['lifts'], p['sleep']
    top = 23 + b
    if not sl:
        leg(c, 10, top, 2, BS, rgb('#f6e6cf'), L[1]); leg(c, 18, top, 2, BS, rgb('#f6e6cf'), L[3])
    # хвост
    t = p['tail']
    pts = [(5, 20), (4, 19), (3, 18), (3, 17), (2, 16), (2 + t, 15), (3 + t, 14)]
    if sl: pts = [(5, 24), (4, 25), (4, 26), (5, 27), (7, 27)]
    for x, y in pts:
        c.rect(x, y + (0 if sl else b), 2, 2, B)
    c.ellipse(13, 20 + b, 7.8, 4.2, B, BS, BL)
    for sx in (9, 13, 17): c.rect(sx, 17 + b, 1, 3, BS)
    if not sl:
        leg(c, 8, top, 2, B, rgb('#f6e6cf'), L[0]); leg(c, 16, top, 2, B, rgb('#f6e6cf'), L[2])
    if sl: hy += 5; hx -= 2
    # уши-треугольники
    for ex in (hx - 3, hx + 1):
        for i in range(4):
            c.rect(ex + i // 2 if ex == hx - 3 else ex + (3 - i) // 2 - 1 + 1, hy - 4 - 3 + i + 1, 4 - i if False else 3 - i // 2 * 1, 1, B)
        c.set(ex + 1, hy - 4, PINK)
    c.ellipse(hx, hy, 4.8, 4.2, B, BS, BL)
    c.set(hx + 5, hy + 1, PINK); c.set(hx + 5, hy + 2, PINK_D)
    eye(c, hx + 1, hy - 1, p['eyes'], rgb('#2c4a1c'))
    c.rect(hx - 1, hy - 3, 1, 2, BS); c.rect(hx + 2, hy - 3, 1, 2, BS)

def rabbit(c, p):
    b, hx, hy = p['bob'], 21 + p['hdx'], 17 + p['bob'] + p['hdy']
    W, WS, WL = rgb('#e8dcc8'), rgb('#c4b69c'), rgb('#ffffff')
    sl = p['sleep']
    c.ellipse(7, 21 + b, 2.6, 2.6, WL, WS)  # хвостик
    c.ellipse(14, 21 + b, 6.2, 5, W, WS, WL)
    if not sl:
        c.ellipse(11, 26, 3.6, 2.2, W, WS)   # задняя лапа
        c.ellipse(18, 26, 2.2, 1.6, W, WS)
    if sl: hy += 3; hx -= 1
    # уши
    ear_dy = 2 if p['anim'] == 'eat' else 0
    c.ellipse(hx - 2, hy - 8 + ear_dy, 1.7, 5, W, WS, WL)
    c.ellipse(hx - 2, hy - 8 + ear_dy, 0.8, 3.6, PINK)
    c.ellipse(hx + 1, hy - 7 + ear_dy, 1.7, 4.6, W, WS, WL)
    c.ellipse(hx, hy, 4.2, 3.8, W, WS, WL)
    c.set(hx + 4, hy + 1, PINK_D)
    eye(c, hx + 1, hy - 1, p['eyes'])

def chicken(c, p):
    b, hx, hy = p['bob'], 21 + p['hdx'], 12 + p['bob'] + p['hdy'] * 1
    W, WS, WL = rgb('#f7f4ee'), rgb('#d9d4c8'), rgb('#ffffff')
    OR, RD = rgb('#f4a02c'), rgb('#e23b3b')
    L, sl = p['lifts'], p['sleep']
    if sl: hy += 6; hx -= 2
    if not sl:
        leg(c, 12, 24 + b, 1, OR, OR, L[0], 1); leg(c, 16, 24 + b, 1, OR, OR, L[2], 1)
        c.rect(11, GY - 1 - L[0], 3, 1, OR); c.rect(15, GY - 1 - L[2], 3, 1, OR)
    c.ellipse(6, 16 + b + (4 if sl else 0), 2.8, 4, W, WS, WL)  # хвост
    c.ellipse(14, 19 + b + (3 if sl else 0), 7.2, 6, W, WS, WL)
    c.ellipse(13, 19 + b + (3 if sl else 0), 4, 3, rgb('#e6dfd0'), rgb('#cfc8b8'), None)  # крыло
    c.ellipse(hx, hy + (0 if not sl else 0), 3.6, 3.6, W, WS, WL)
    c.rect(hx - 1, hy - 5, 1, 2, RD); c.rect(hx, hy - 6, 1, 3, RD); c.rect(hx + 1, hy - 5, 1, 2, RD)  # гребешок
    c.rect(hx + 3, hy, 3, 2, OR); c.set(hx + 5, hy + 1, rgb('#d98414'))
    c.rect(hx + 2, hy + 2, 1, 2, RD)
    eye(c, hx + 1, hy - 1, p['eyes'])

SPECIES = {'cow': cow, 'sheep': sheep, 'dog': dog, 'cat': cat, 'rabbit': rabbit, 'chicken': chicken}
SHADOW = {'cow': 11, 'sheep': 10, 'dog': 9, 'cat': 8, 'rabbit': 7, 'chicken': 7}

def render(sp, anim, f):
    c = Canvas(32, 32)
    p = params(anim, f, sp); p['anim'] = anim
    SPECIES[sp](c, p)
    c.outline(OUT)
    shadow(c, 14, GY + 1, SHADOW[sp], 2)
    return c

# ---------------------------------------------------------------- жители
def human(hair, hair_style, shirt, bottom, apron=None, hat=None, glasses=False, mustache=False, skin='#f2c9a0'):
    frames = []
    for f in range(3):
        c = Canvas(24, 32)
        sk, skd = rgb(skin), rgb('#d9a77c')
        bob = 1 if f == 1 else 0
        # ноги и ботинки
        c.rect(8, 24 + bob, 3, 5 - bob, rgb(bottom)); c.rect(13, 24 + bob, 3, 5 - bob, rgb(bottom))
        c.rect(7, 28, 4, 2, rgb('#4a3020')); c.rect(13, 28, 4, 2, rgb('#4a3020'))
        # тело
        c.ellipse(12, 21 + bob, 6.5, 5.5, rgb(shirt))
        c.rect(5, 18 + bob, 2, 6, rgb(shirt)); c.rect(17, 18 + bob, 2, 6, rgb(shirt))
        c.rect(5, 23 + bob, 2, 2, sk); c.rect(17, 23 + bob, 2, 2, sk)
        if apron:
            c.rect(8, 19 + bob, 8, 8, rgb(apron)); c.rect(8, 19 + bob, 8, 1, rgb('#ffffff'))
        # голова
        hy = 11 + bob
        if hair_style == 'long': c.rect(5, hy - 2, 14, 11, rgb(hair))
        c.ellipse(12, hy, 6, 6, sk, skd, None, 0.55)
        if hair_style == 'bun': c.ellipse(12, hy - 8, 3, 3, rgb(hair))
        c.ellipse(12, hy - 4, 6.4, 3.4, rgb(hair))
        c.set(9, hy, rgb('#2c1828')); c.set(9, hy + 1, rgb('#2c1828')); c.set(14, hy, rgb('#2c1828')); c.set(14, hy + 1, rgb('#2c1828'))
        c.set(8, hy + 3, rgb('#e89a9a')); c.set(15, hy + 3, rgb('#e89a9a'))
        if f == 2: c.rect(11, hy + 3, 2, 2, rgb('#8a3a3a'))
        else: c.rect(11, hy + 3, 2, 1, rgb('#8a3a3a'))
        if glasses:
            for gx in (8, 13): c.rect(gx, hy - 1, 3, 1, rgb('#7a6a5a')); c.rect(gx, hy + 2, 3, 1, rgb('#7a6a5a'))
        if mustache: c.rect(9, hy + 2, 6, 1, rgb(hair))
        if hat == 'straw':
            c.ellipse(12, hy - 5, 10, 2.2, rgb('#e8c868'), rgb('#c9a548'), rgb('#f6e098'))
            c.ellipse(12, hy - 7, 5.4, 3.2, rgb('#e8c868'), rgb('#c9a548'), rgb('#f6e098'))
            c.rect(7, hy - 6, 10, 1, rgb('#b03a3a'))
        c.outline(rgb('#3b2a2e'))
        frames.append(c)
    return frames

NPCS = {
    'shopkeeper': dict(hair='#6a3b22', hair_style='bun', shirt='#f4ead2', bottom='#6a4a8a', apron='#4f9e6a'),
    'farmer': dict(hair='#8a5a2a', hair_style='short', shirt='#c8453a', bottom='#3a6aa8', hat='straw', mustache=True),
    'granny': dict(hair='#cfcfd8', hair_style='bun', shirt='#8a5aa8', bottom='#6a4a78', glasses=True),
}

def main():
    root = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
    os.makedirs(os.path.join(root, 'animals'), exist_ok=True)
    os.makedirs(os.path.join(root, 'npc'), exist_ok=True)
    for sp in SPECIES:
        sheet = Canvas(4 * 32, len(ANIMS) * 32)
        for r, (anim, n) in enumerate(ANIMS):
            for f in range(n):
                sheet.paste(render(sp, anim, f), f * 32, r * 32)
        sheet.img.save(os.path.join(root, 'animals', sp + '.png'))
    for name, kw in NPCS.items():
        fr = human(**kw)
        sheet = Canvas(3 * 24, 32)
        for i, f in enumerate(fr): sheet.paste(f, i * 24, 0)
        sheet.img.save(os.path.join(root, 'npc', name + '.png'))
    print('animals ok')

if __name__ == '__main__':
    main()
