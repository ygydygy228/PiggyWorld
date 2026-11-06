"""Генератор тайлсета и объектов мира. Запуск: python3 tools/gen_world.py
Результат: assets/tiles/tileset.png, assets/objects/*.png"""
import os, random, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixel_lib import Canvas, rgb
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets')
T = 16
N, E, S, W = 1, 2, 4, 8

def make_tex(base, dots, lights, seed, tufts=None, dot_p=0.13, light_p=0.05, detail=0.0):
    r = random.Random(seed)
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            v = r.random()
            col = base
            if v < dot_p: col = dots
            elif v > 1 - light_p: col = lights
            c.set(x, y, col)
    # пучки травы: короткие изогнутые штрихи вместо квадратов
    for _ in range(r.randint(2, 4)):
        x, y = r.randint(1, 12), r.randint(2, 13)
        col = dots if r.random() < 0.6 else lights
        c.set(x, y, col); c.set(x + 1, y, col); c.set(x + 1, y - 1, col)
        if r.random() < 0.5:
            c.set(x + 2, y - 1, col)
    if tufts:
        for _ in range(r.randint(2, 4)):
            x, y = r.randint(2, 13), r.randint(3, 13)
            c.set(x, y, tufts[0]); c.set(x - 1, y - 1, tufts[1]); c.set(x + 1, y - 1, tufts[1])
            if r.random() < 0.45:
                c.set(x, y - 1, tufts[1])
    if detail > 0.0:
        # мелкие цветочки и камешки — «жизнь» на лугу
        for _ in range(r.randint(0, 2)):
            if r.random() > detail:
                continue
            x, y = r.randint(2, 12), r.randint(3, 12)
            if r.random() < 0.55:
                petal = r.choice((rgb('#f7f1d8'), rgb('#ffd95e'), rgb('#f4a5b5'), rgb('#c8b4f0')))
                c.set(x, y, petal); c.set(x + 1, y, petal); c.set(x, y - 1, petal)
                c.set(x + 1, y + 1, rgb('#4a8a45'))
            else:
                c.set(x, y, rgb('#9aa3a6')); c.set(x + 1, y + 1, rgb('#7d878c'))
    return c

GRASS = dict(base=rgb('#6bb35a'), dots=rgb('#5fa44e'), lights=rgb('#82c76c'))
GRASS_T = (rgb('#4a8a45'), rgb('#8fd47a'))
SAND = dict(base=rgb('#e6cf8e'), dots=rgb('#d9bd7a'), lights=rgb('#f3e3ab'))
DIRT = dict(base=rgb('#b98a58'), dots=rgb('#a57747'), lights=rgb('#cfa373'))
LIP = {'grass': rgb('#4a8a45'), 'sand': rgb('#c9a964'), 'dirt': rgb('#8b5f36')}

def overlay_tile(tex, mask, lip_col):
    """Тайл-наложение: края со стороны чужой земли обрезаются (прозрачность) + кромка."""
    out = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            d = 99
            if mask & N: d = min(d, y)
            if mask & S: d = min(d, T - 1 - y)
            if mask & W: d = min(d, x)
            if mask & E: d = min(d, T - 1 - x)
            cut = False
            # скругление выпуклых углов
            R = 5
            for (mx, my, cx, cy, ccx, ccy) in ((N, W, 0, 0, R, R), (N, E, T - 1, 0, T - 1 - R, R),
                                               (S, W, 0, T - 1, R, T - 1 - R), (S, E, T - 1, T - 1, T - 1 - R, T - 1 - R)):
                if mask & mx and mask & my:
                    inx = (x < R) if cx == 0 else (x > T - 1 - R)
                    iny = (y < R) if cy == 0 else (y > T - 1 - R)
                    if inx and iny:
                        dd = ((x - ccx) ** 2 + (y - ccy) ** 2) ** 0.5
                        if dd > R: cut = True
                        elif dd > R - 1.3: d = min(d, 2)
            if cut or d < 2:
                continue
            p = tex.get(x, y)
            if d == 2:
                p = lip_col
            out.set(x, y, p)
    return out

def water_frames():
    frames = []
    base, dark, light = rgb('#3a84b8'), rgb('#3277aa'), rgb('#86c8e6')
    r = random.Random(7)
    spots = [(r.randint(1, 12), r.randint(1, 14)) for _ in range(4)]
    for f in range(4):
        c = Canvas(T, T)
        c.rect(0, 0, T, T, base)
        for y in range(T):
            for x in range(T):
                if (x * 3 + y * 5) % 11 == 0:
                    c.set(x, y, dark)
        for i, (sx, sy) in enumerate(spots):
            ox = (sx + f * (1 if i % 2 else -1)) % 14
            c.set(ox, sy, light); c.set(ox + 1, sy, light); c.set(ox + 2, sy, light)
        frames.append(c)
    return frames

def soil(wet):
    c = Canvas(T, T)
    base = rgb('#6b4328') if wet else rgb('#8a5a3b')
    fur = rgb('#50301d') if wet else rgb('#6d4429')
    hi = rgb('#8a5d3c') if wet else rgb('#a67348')
    c.rect(0, 0, T, T, base)
    for y in (3, 8, 13):
        c.rect(0, y, T, 2, fur)
        for x in range(1, T, 5):
            c.set(x + (y % 3), y - 1, hi)
    c.rect(0, 0, T, 1, fur); c.rect(0, T - 1, 1, T, fur) if False else None
    return c

def build_tileset():
    cols, rows = 16, 5
    sheet = Canvas(cols * T, rows * T)
    for i, f in enumerate(water_frames()):
        sheet.paste(f, i * T, 0)
    sets = (('grass', GRASS, 1, GRASS_T), ('sand', SAND, 2, None), ('dirt', DIRT, 3, None))
    for name, spec, row, tufts in sets:
        for m in range(16):
            detail = 0.0
            if name == 'grass':
                detail = 0.55 if m % 3 == 0 else 0.0
            tex = make_tex(spec['base'], spec['dots'], spec['lights'], 100 + row * 31 + m, tufts, detail=detail)
            sheet.paste(overlay_tile(tex, m, LIP[name]), m * T, row * T)
    for i in range(4):
        detail = 0.9 if i in (0, 2) else 0.0
        sheet.paste(make_tex(GRASS['base'], GRASS['dots'], GRASS['lights'], 500 + i, GRASS_T, 0.16, 0.07, detail=detail), (2 + i) * T, 4 * T)
    sheet.paste(soil(False), 0, 4 * T)
    sheet.paste(soil(True), 1 * T, 4 * T)
    d = os.path.join(ROOT, 'tiles'); os.makedirs(d, exist_ok=True)
    sheet.img.save(os.path.join(d, 'tileset.png'))

# ------------------------- объекты -------------------------
OUTL = rgb('#2c3a2b')
def shadow(c, cx, cy, rx, ry):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            if nx * nx + ny * ny <= 1 and c.get(x, y)[3] == 0:
                c.set(x, y, (20, 40, 30, 70))

def tree(w, h, variant):
    c = Canvas(w, h)
    cx = w // 2
    trunk, trunk_d, trunk_l = rgb('#7a4f2e'), rgb('#5c3a22'), rgb('#9a6b43')
    if variant == 2:  # сосна
        c.rect(cx - 3, h - 18, 6, 18, trunk); c.rect(cx - 3, h - 18, 2, 18, trunk_l); c.rect(cx + 1, h - 18, 2, 18, trunk_d)
        g, gd, gl = rgb('#2f7a4a'), rgb('#215c37'), rgb('#49a066')
        for i, (yy, rr) in enumerate(((h - 20, 15), (h - 32, 12), (h - 43, 9), (h - 53, 6))):
            for y in range(yy - 12, yy + 1):
                half = int(rr * (y - (yy - 12)) / 12) + 1
                for x in range(cx - half, cx + half + 1):
                    col = g
                    if x > cx + half * 0.3 or y > yy - 3: col = gd
                    if x < cx - half * 0.35 and y < yy - 4: col = gl
                    c.set(x, y, col)
    else:
        c.rect(cx - 4, h - 22, 8, 22, trunk); c.rect(cx - 4, h - 22, 3, 22, trunk_l); c.rect(cx + 2, h - 22, 2, 22, trunk_d)
        c.rect(cx - 7, h - 3, 3, 3, trunk); c.rect(cx + 4, h - 3, 3, 3, trunk_d)  # корни
        g, gd, gl = (rgb('#5aa84e'), rgb('#3f8a3f'), rgb('#7fcb68')) if variant == 0 else (rgb('#6bb050'), rgb('#4a9140'), rgb('#9bd870'))
        blobs = [(cx, h - 38, 17, 14), (cx - 11, h - 30, 12, 10), (cx + 11, h - 30, 12, 10), (cx, h - 26, 15, 9)] if variant == 0 else \
                [(cx, h - 40, 19, 15), (cx - 13, h - 30, 12, 10), (cx + 13, h - 31, 12, 10), (cx, h - 27, 16, 9), (cx - 5, h - 48, 9, 7)]
        for bx, by, rx, ry in blobs:
            c.ellipse(bx, by, rx, ry, g, gd, gl, 0.25, -0.35)
        if variant == 1:
            for px, py in ((cx - 10, h - 38), (cx + 8, h - 44), (cx + 12, h - 30), (cx - 3, h - 33)):
                c.rect(px, py, 2, 2, rgb('#e8504a')); c.set(px, py, rgb('#ff8a80'))
    c.outline(OUTL)
    shadow(c, cx, h - 2, 18, 4)
    return c

def rock(w, h, big):
    c = Canvas(w, h)
    cx, cy = w // 2, h - 8
    c.ellipse(cx, cy, w // 2 - 2, h // 2 - 3, rgb('#9aa3a6'), rgb('#6f797e'), rgb('#c4cccd'), 0.2, -0.3)
    if big:
        c.ellipse(cx - 5, cy - 4, 6, 5, rgb('#a9b2b5'), rgb('#7d878c'), rgb('#d3dadb'), 0.2, -0.3)
    c.set(cx + 3, cy - 1, rgb('#5d676c')); c.set(cx + 4, cy, rgb('#5d676c')); c.set(cx + 4, cy + 1, rgb('#5d676c'))
    c.outline(rgb('#3a4348'))
    shadow(c, cx, h - 2, w // 2, 3)
    return c

def bush(berries):
    w, h = 28, 22
    c = Canvas(w, h)
    for bx, by, rx, ry in ((9, 13, 8, 7), (19, 13, 8, 7), (14, 9, 9, 7)):
        c.ellipse(bx, by, rx, ry, rgb('#4f9e4a'), rgb('#37803c'), rgb('#76c364'), 0.25, -0.35)
    if berries:
        for px, py in ((8, 11), (15, 7), (20, 12), (12, 14), (17, 15)):
            c.rect(px, py, 2, 2, rgb('#d63a5a')); c.set(px, py, rgb('#ff7f96'))
    c.outline(OUTL)
    shadow(c, 14, h - 2, 12, 3)
    return c

def flower(col, center):
    c = Canvas(T, T)
    c.rect(7, 8, 1, 6, rgb('#3f8a3f')); c.set(6, 11, rgb('#3f8a3f')); c.set(8, 10, rgb('#3f8a3f'))
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        c.set(7 + dx, 7 + dy, col)
    c.set(7, 7, center)
    return c

def house():
    w, h = 64, 64
    c = Canvas(w, h)
    wall, wall_d, wall_l = rgb('#e9cf9e'), rgb('#c9a972'), rgb('#f6e4be')
    roof, roof_d, roof_l = rgb('#c9553d'), rgb('#9d3b2c'), rgb('#e2745a')
    c.rect(8, 30, 48, 30, wall)
    for y in range(32, 60, 4): c.rect(8, y, 48, 1, wall_d)
    c.rect(8, 30, 48, 2, wall_l)
    c.rect(52, 30, 4, 30, wall_d)
    # крыша
    for y in range(8, 32):
        half = 8 + (y - 8) * 26 // 24 + 2
        for x in range(32 - half, 32 + half):
            col = roof
            if (y // 3 + (x // 4)) % 2 == 0: col = roof_d if (x // 4 + y // 3) % 3 == 0 else roof
            if y % 3 == 0: col = roof_l if x % 8 < 4 else roof
            c.set(x, y, col)
    c.rect(44, 10, 6, 14, rgb('#8a6a55')); c.rect(43, 8, 8, 3, rgb('#6e523f'))
    # дверь и окно
    c.rect(26, 42, 12, 18, rgb('#7a4f2e')); c.rect(26, 42, 12, 2, rgb('#9a6b43')); c.set(35, 52, rgb('#f4d35e')); c.set(35, 53, rgb('#f4d35e'))
    c.rect(13, 40, 9, 9, rgb('#8fd0e8')); c.rect(13, 40, 9, 1, rgb('#d8f1fa')); c.rect(17, 40, 1, 9, rgb('#7a4f2e')); c.rect(13, 44, 9, 1, rgb('#7a4f2e'))
    c.rect(12, 49, 11, 2, rgb('#9a6b43'))
    c.outline(rgb('#3d2a1f'))
    shadow(c, 32, 61, 30, 3)
    return c

def crop(stage, kind='carrot'):
    c = Canvas(T, T)
    c.ellipse(8, 13, 5, 2.2, rgb('#7a4f2e'), rgb('#5c3a22'), None)
    if stage == 0:
        c.set(8, 11, rgb('#d8c070')); c.set(7, 12, rgb('#d8c070'))
    elif stage == 1:
        c.rect(8, 8, 1, 4, rgb('#4f9e4a')); c.set(7, 8, rgb('#76c364')); c.set(9, 9, rgb('#76c364'))
    elif stage == 2:
        c.rect(8, 6, 1, 6, rgb('#4f9e4a'))
        for dx, dy in ((-2, 6), (-1, 5), (2, 6), (1, 5), (-1, 7), (1, 7)):
            c.set(8 + dx, dy, rgb('#5fb356'))
    else:
        for dx, dy in ((-3, 5), (-2, 4), (-1, 3), (0, 3), (1, 3), (2, 4), (3, 5), (0, 4), (-1, 5), (1, 5)):
            c.set(8 + dx, dy, rgb('#5fb356'))
        c.rect(7, 8, 3, 3, rgb('#f08a2c')); c.rect(7, 8, 3, 1, rgb('#ffb15c')); c.set(8, 11, rgb('#d96f14'))
    c.outline(rgb('#3a2a1f')) if stage > 0 else None
    return c

def fence():
    c = Canvas(T, T)
    wood, wd, wl = rgb('#a9754a'), rgb('#7d5233'), rgb('#c79566')
    c.rect(1, 4, 3, 11, wood); c.rect(1, 4, 1, 11, wl); c.rect(3, 4, 1, 11, wd)
    c.rect(12, 4, 3, 11, wood); c.rect(12, 4, 1, 11, wl); c.rect(14, 4, 1, 11, wd)
    c.rect(4, 6, 8, 2, wood); c.rect(4, 6, 8, 1, wl); c.rect(4, 11, 8, 2, wood); c.rect(4, 12, 8, 1, wd)
    c.outline(rgb('#4a3020'))
    return c

def main():
    build_tileset()
    d = os.path.join(ROOT, 'objects'); os.makedirs(d, exist_ok=True)
    def save(name, cv): cv.img.save(os.path.join(d, name + '.png'))
    save('tree_oak', tree(48, 64, 0)); save('tree_oak_big', tree(56, 72, 1)); save('tree_pine', tree(40, 64, 2))
    save('rock_small', rock(24, 20, False)); save('rock_big', rock(32, 26, True))
    save('bush', bush(False)); save('bush_berries', bush(True))
    for n, col, ctr in (('red', rgb('#e8504a'), rgb('#ffe27a')), ('yellow', rgb('#f6d44a'), rgb('#e98a2a')),
                        ('blue', rgb('#6a8cf0'), rgb('#ffffff')), ('white', rgb('#f4f4f4'), rgb('#f2c14e'))):
        save('flower_' + n, flower(col, ctr))
    save('house', house())
    for s in range(4): save(f'crop_carrot_{s}', crop(s))
    save('fence', fence())
    print('ok')

if __name__ == '__main__':
    main()
