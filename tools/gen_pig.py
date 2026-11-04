"""Генератор спрайт-листа свинки. Запуск: python3 tools/gen_pig.py
Результат: assets/sprites/pig_sheet.png + assets/sprites/pig_sheet.json
Кадр 32x32, строка = одна анимация в одном ракурсе (side смотрит вправо, влево — flip_h)."""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixel_lib import Canvas, rgb

OUT = rgb('#4a2638')
P_L, P, P_D = rgb('#ffd0d9'), rgb('#f7a0b5'), rgb('#dd7998')
S, S_D = rgb('#ffb8c4'), rgb('#ce6686')
EAR = rgb('#e9809f')
HOOF = rgb('#a8566f')
EYE, WHITE = rgb('#2c1828'), rgb('#ffffff')
BLUSH = rgb('#ff8296')
TEAR = rgb('#78bef0')
HEART = rgb('#eb4664')
ZZ = rgb('#c8dcff')
NOSTRIL = rgb('#7a3550')
SIZE = 32
FH = 40
OY = 8
GROUND = 28

class OC(Canvas):
    def set(self, x, y, c):
        Canvas.set(self, x, y + OY, c)


def legs_side(c, bob, lifts, sleeping=False):
    # far legs (dark) first: far-back x=11, far-front x=20
    for x, lift, col in ((11, lifts[1], P_D), (20, lifts[3], P_D)):
        top = 21 + bob
        c.rect(x, top, 2, GROUND - top - lift, col)
        c.rect(x, GROUND - 1 - lift, 2, 1, HOOF)

def legs_side_near(c, bob, lifts):
    for x, lift in ((8, lifts[0]), (17, lifts[2])):
        top = 21 + bob
        c.rect(x, top, 2, GROUND - top - lift, P)
        c.rect(x, GROUND - 1 - lift, 2, 1, HOOF)

def eye_side(c, x, y, state):
    if state == 'open':
        c.rect(x, y, 2, 2, EYE); c.set(x, y, WHITE) if False else None; c.set(x + 1, y, rgb('#6a4a68'))
        c.set(x, y, EYE)
        c.set(x, y - 0, EYE)
        c.set(x + 1, y, WHITE)  # блик
    elif state == 'closed':
        c.rect(x, y + 1, 2, 1, EYE)
    elif state == 'happy':
        c.set(x - 1, y + 1, EYE); c.set(x, y, EYE); c.set(x + 1, y, EYE); c.set(x + 2, y + 1, EYE)
    elif state == 'sad':
        c.rect(x, y, 2, 2, EYE); c.set(x + 1, y, WHITE)
        c.set(x - 1, y - 1, EYE); c.set(x, y - 1, EYE)  # бровь домиком

def draw_side(p):
    c = OC(SIZE, FH)
    bob = p.get('bob', 0); hdx = p.get('hdx', 0); hdy = p.get('hdy', 0)
    lifts = p.get('lifts', [0, 0, 0, 0])
    sleep = p.get('sleep', False)
    ear_dy = p.get('ear_dy', 0)
    if not sleep:
        legs_side(c, bob, lifts)
    # хвост
    ty = 15 + bob if not sleep else 20
    for dx, dy in ((0, 2), (-1, 1), (-1, 0), (0, -1), (1, -1), (1, 0)):
        c.set(5 + dx, ty + dy, P_D)
    # тело
    if sleep:
        c.ellipse(14, 22 + bob, 10, 5.5 + p.get('breath', 0), P, P_D, P_L)
    else:
        c.ellipse(14, 18 + bob, 9.5, 6.2 + p.get('stretch', 0), P, P_D, P_L)
    if not sleep:
        legs_side_near(c, bob, lifts)
    # ухо (сзади головы)
    hx, hy = 23 + hdx, 16 + bob + hdy
    if sleep:
        hx, hy = 24, 21 + bob
    c.ellipse(hx - 2, hy - 5 + ear_dy, 2.6, 2.8, EAR, P_D, None)
    # голова
    c.ellipse(hx, hy, 6.2, 5.6, P, P_D, P_L)
    # пятачок
    sx, sy = hx + 5, hy + 2
    c.ellipse(sx, sy, 2.7, 2.7, S, S_D, None, 0.35)
    c.set(sx + 1, sy, NOSTRIL); c.set(sx + 1, sy - 1, NOSTRIL) if False else None
    if p.get('mouth_open'):
        c.rect(sx - 1, sy + 2, 3, 1, NOSTRIL)
    # щека и глаз
    c.set(hx + 1, hy + 2, BLUSH); c.set(hx + 2, hy + 2, BLUSH)
    eye_side(c, hx + 2, hy - 2, p.get('eyes', 'open'))
    if p.get('tear'):
        c.set(hx + 3, hy + p['tear'], TEAR)
    extras(c, p, hx, hy)
    c.outline(OUT)
    return c

def extras(c, p, hx, hy):
    if p.get('zzz') is not None:
        k = p['zzz']
        for i in range(2):
            ox, oy = hx + 3 + i * 3, hy - 8 - ((k + i * 2) % 5)
            if oy > -OY:
                for dx, dy in ((0, 0), (1, 0), (2, 0), (1, 1), (0, 2), (1, 2), (2, 2)):
                    c.set(ox + dx - (1 if i else 0), oy + dy, ZZ)
    if p.get('heart') is not None:
        k = p['heart']
        ox, oy = hx - 2 + (k % 2) * 2, hy - 11 - k
        for dx, dy in ((0, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (2, 1), (3, 1), (0, 2), (1, 2), (2, 2), (1, 3)):
            c.set(ox + dx, oy + dy, HEART)

def draw_front(p, back=False):
    c = OC(SIZE, FH)
    bob = p.get('bob', 0); hdy = p.get('hdy', 0)
    lifts = p.get('lifts', [0, 0, 0, 0])
    ear_dy = p.get('ear_dy', 0)
    # ноги (две видимые)
    for x, lift in ((10, lifts[0]), (20, lifts[2])):
        top = 23 + bob
        c.rect(x, top, 2, GROUND - top - lift, P)
        c.rect(x, GROUND - 1 - lift, 2, 1, HOOF)
    # тело
    c.ellipse(16, 20 + bob, 9, 5.6 + p.get('stretch', 0), P, P_D, P_L)
    # уши (сзади головы)
    c.ellipse(9, 8 + bob + hdy + ear_dy, 3.2, 3.2, EAR, P_D, None)
    c.ellipse(23, 8 + bob + hdy + ear_dy, 3.2, 3.2, EAR, P_D, None)
    # голова
    hy = 14 + bob + hdy
    c.ellipse(16, hy, 8.2, 7.0, P, P_D, P_L)
    if back:
        # хвостик по центру спины
        for dx, dy in ((0, 0), (1, 0), (1, -1), (0, -2), (-1, -1)):
            c.set(16 + dx, 22 + bob + dy, P_D)
    else:
        sy = hy + 3
        c.ellipse(16, sy, 4.2, 3.0, S, S_D, None, 0.3)
        c.set(14, sy, NOSTRIL); c.set(17, sy, NOSTRIL)
        if p.get('mouth_open'):
            c.rect(14, sy + 2, 4, 1, NOSTRIL)
        c.set(9, hy + 2, BLUSH); c.set(22, hy + 2, BLUSH)
        for ex in (11, 19):
            st = p.get('eyes', 'open')
            if st == 'open':
                c.rect(ex, hy - 1, 2, 3, EYE); c.set(ex + (1 if ex == 11 else 0), hy - 1, WHITE)
            elif st == 'closed':
                c.rect(ex, hy + 1, 2, 1, EYE)
            elif st == 'happy':
                c.set(ex, hy + 1, EYE); c.set(ex + 1, hy, EYE) if ex == 11 else (c.set(ex, hy, EYE), c.set(ex + 1, hy + 1, EYE))
            elif st == 'sad':
                c.rect(ex, hy - 1, 2, 3, EYE); c.set(ex + (1 if ex == 11 else 0), hy - 1, WHITE)
                c.set(ex + (0 if ex == 11 else 1), hy - 3, EYE); c.set(ex + (1 if ex == 11 else 0), hy - 2 if ex == 11 else hy - 2, EYE)
        if p.get('tear'):
            c.set(12, hy + p['tear'] + 1, TEAR)
        extras(c, p, 14, hy - 2)
    c.outline(OUT)
    return c

def walk_params(n, i, height, bob_amp, run=False):
    ph = i / n * 2 * math.pi
    def lift(offset):
        v = math.sin(ph + offset)
        return int(round(max(0.0, v) * height))
    lifts = [lift(0), lift(math.pi), lift(math.pi), lift(0)]  # диагональные пары
    bob = -int(round(abs(math.sin(ph)) * bob_amp))
    return {'lifts': lifts, 'bob': bob, 'hdx': 1 if run else 0, 'stretch': 0.4 if run else 0}

def build():
    anims = {}  # имя -> (кадры [(view, params)...], fps, loop)
    def add(name, views, frames, fps, loop=True):
        anims[name] = {'views': views, 'frames': frames, 'fps': fps, 'loop': loop}

    idle = []
    for i in range(4):
        idle.append({'bob': [0, 0, 1, 1][i], 'hdy': [0, 0, 0, 1][i], 'ear_dy': [0, 1, 0, 0][i],
                     'eyes': 'closed' if i == 3 else 'open'})
    add('idle', ['down', 'side', 'up'], idle, 4)
    add('walk', ['down', 'side', 'up'], [walk_params(6, i, 2, 1) for i in range(6)], 9)
    run = []
    for i in range(6):
        q = walk_params(6, i, 4, 2, True); q['eyes'] = 'open'; run.append(q)
    add('run', ['down', 'side', 'up'], run, 13)
    eat = []
    for i in range(4):
        eat.append({'hdy': [4, 5, 4, 5][i], 'hdx': 1, 'mouth_open': i % 2 == 1, 'eyes': 'closed' if i == 1 else 'open', 'bob': 1})
    add('eat', ['down', 'side', 'up'], eat, 6)
    happy = []
    for i in range(6):
        b = [0, -2, -5, -6, -3, 0][i]
        happy.append({'bob': b, 'lifts': [0, 0, 0, 0] if i in (0, 5) else [1, 1, 1, 1], 'eyes': 'happy',
                      'heart': (i - 2) if 2 <= i <= 5 else None, 'stretch': 0.0 if i not in (0, 5) else -0.4, 'ear_dy': -1 if i in (2, 3) else 0})
    add('happy', ['down', 'side', 'up'], happy, 8)
    sad = []
    for i in range(4):
        sad.append({'bob': 1, 'hdy': 2, 'ear_dy': 3, 'eyes': 'sad', 'tear': [3, 4, 5, 6][i] if i > 0 else None})
    add('sad', ['down', 'side', 'up'], sad, 4)
    inter = []
    for i in range(4):
        l = [0, 0, 0, 0]; l[2] = [0, 3, 0, 3][i]
        inter.append({'hdy': [0, 2, 3, 1][i], 'hdx': [0, 1, 2, 1][i], 'lifts': l, 'bob': 0})
    add('interact', ['down', 'side', 'up'], inter, 6)
    sleep = []
    for i in range(4):
        sleep.append({'sleep': True, 'eyes': 'closed', 'breath': [0, 0.3, 0.6, 0.3][i], 'zzz': i})
    add('sleep', ['side'], sleep, 3)
    return anims

def main():
    anims = build()
    rows = []
    for name, a in anims.items():
        for v in a['views']:
            rows.append((name, v, a))
    cols = 6
    sheet = Canvas(cols * SIZE, len(rows) * FH)
    meta = {'frame_w': SIZE, 'frame_h': FH, 'ground_y': GROUND + OY, 'columns': cols, 'rows': []}
    for r, (name, v, a) in enumerate(rows):
        for i, params in enumerate(a['frames']):
            if v == 'side':
                f = draw_side(params)
            elif v == 'down':
                f = draw_front(params)
            else:
                f = draw_front(params, back=True)
            sheet.paste(f, i * SIZE, r * FH)
        meta['rows'].append({'name': f'{name}_{v}', 'row': r, 'frames': len(a['frames']), 'fps': a['fps'], 'loop': a['loop']})
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
    os.makedirs(out_dir, exist_ok=True)
    sheet.img.save(os.path.join(out_dir, 'pig_sheet.png'))
    with open(os.path.join(out_dir, 'pig_sheet.json'), 'w') as fh:
        json.dump(meta, fh, indent=1)
    print('rows', len(rows))

if __name__ == '__main__':
    main()
