"""Синтез звуков и музыки (numpy + wave). Запуск: python3 tools/gen_audio.py -> assets/audio/*.wav"""
import numpy as np, wave, os
SR = 22050
rng = np.random.default_rng(42)
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio'); os.makedirs(OUT, exist_ok=True)

def save(name, data, sr=SR, vol=0.8):
    d = np.clip(data / max(1e-9, np.max(np.abs(data))) * vol, -1, 1)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((d * 32767).astype(np.int16).tobytes())

def t(dur, sr=SR): return np.linspace(0, dur, int(dur * sr), endpoint=False)
def env(n, a=0.01, r=0.1, sr=SR):
    e = np.ones(n); na = int(a * sr); nr = int(r * sr)
    if na: e[:na] = np.linspace(0, 1, na)
    if nr: e[-nr:] *= np.linspace(1, 0, nr)
    return e
def lp(x, k=8): return np.convolve(x, np.ones(k) / k, mode='same')
def noise(n): return rng.uniform(-1, 1, n)

def oink(base, dur=0.38):
    tt = t(dur); f = base * (1 + 0.5 * np.exp(-tt * 9)) * (1 - 0.25 * tt / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sign(np.sin(ph)) * 0.5 + np.sin(ph * 2) * 0.3 + noise(len(tt)) * 0.15
    s = lp(s, 6) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * tt))
    return s * env(len(tt), 0.01, 0.12)

def tone(f, dur, shape='sin'):
    tt = t(dur); s = np.sin(2 * np.pi * f * tt)
    if shape == 'tri': s = 2 / np.pi * np.arcsin(s)
    return s * env(len(tt), 0.005, dur * 0.7)

save('oink', np.concatenate([oink(260), np.zeros(int(0.05 * SR)), oink(210, 0.28)]))
save('oink_happy', np.concatenate([oink(340, 0.2), oink(400, 0.22)]))
save('step', lp(noise(int(0.07 * SR)), 10) * env(int(0.07 * SR), 0.002, 0.05), vol=0.5)
save('pickup', np.concatenate([tone(660, 0.08, 'tri'), tone(990, 0.14, 'tri')]))
tt = t(0.18); save('chop', (lp(noise(len(tt)), 5) * 0.7 + np.sin(2 * np.pi * 110 * tt)) * env(len(tt), 0.001, 0.15))
tt = t(0.16); save('mine', (np.sin(2 * np.pi * 1500 * tt) * 0.5 + noise(len(tt)) * 0.4) * np.exp(-tt * 28))
tt = t(0.14); save('plant', np.sin(2 * np.pi * 200 * tt * (1 - tt)) * env(len(tt), 0.005, 0.1))
tt = t(0.45); save('water', lp(noise(len(tt)), 14) * np.sin(np.pi * tt / 0.45) ** 0.6, vol=0.5)
save('coin', np.concatenate([tone(880, 0.07), tone(1320, 0.2)]))
tt = t(0.12); hit = (lp(noise(len(tt)), 4) + np.sin(2 * np.pi * 140 * tt)) * np.exp(-tt * 20)
save('build', np.concatenate([hit, np.zeros(int(0.1 * SR)), hit, np.zeros(int(0.1 * SR)), hit * 1.2]))
tt = t(0.2); save('error', np.sign(np.sin(2 * np.pi * 150 * tt)) * 0.4 * env(len(tt), 0.005, 0.1), vol=0.5)
tt = t(0.25); save('ui_click', np.sin(2 * np.pi * 520 * tt) * np.exp(-tt * 30), vol=0.5)

# ambient днём: птицы + лёгкий ветер (8 c, зациклено)
SRA = 16000; dur = 8; n = SRA * dur
wind = lp(noise(n), 60) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.25 * np.linspace(0, dur, n)))
amb = wind * 0.25
for st in (1.0, 2.7, 3.1, 5.4, 6.6):
    d = 0.18; k = int(d * SRA); tt = np.linspace(0, d, k); f = 3000 + 900 * np.sin(2 * np.pi * 9 * tt) + 600 * tt / d
    chirp = np.sin(2 * np.pi * np.cumsum(f) / SRA) * np.sin(np.pi * tt / d)
    i = int(st * SRA); amb[i:i + k] += chirp * 0.18
save('ambient_day', amb, SRA, 0.35)
# ночь: сверчки
n = SRA * dur; cr = np.zeros(n)
for st in np.arange(0.2, dur, 0.55):
    for j in range(3):
        k = int(0.05 * SRA); tt = np.linspace(0, 0.05, k); i = int((st + j * 0.07) * SRA)
        if i + k < n: cr[i:i + k] += np.sin(2 * np.pi * 4300 * tt) * np.sin(np.pi * tt / 0.05) * 0.15
save('ambient_night', cr + lp(noise(n), 80) * 0.05, SRA, 0.3)

# музыка: спокойная пентатоника (аккорды + мелодия), 12 кГц, ~40 с, петля
SRM = 16000; bpm = 84; beat = 60 / bpm
def pluck(f, dur):
    tt = np.linspace(0, dur, int(dur * SRM), endpoint=False)
    s = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)) * np.exp(-tt * 3.2)
    return s * np.minimum(1, tt * 200)
def pad(f, dur):
    tt = np.linspace(0, dur, int(dur * SRM), endpoint=False)
    s = (np.sin(2 * np.pi * f * tt) + np.sin(2 * np.pi * f * 1.005 * tt)) * 0.5
    return s * np.minimum(1, np.minimum(tt * 3, (dur - tt) * 3))
def hz(m): return 440 * 2 ** ((m - 69) / 12)
chords = [(48, 52, 55), (45, 48, 52), (53, 57, 60), (43, 47, 50)]  # C Am F G
scale = [60, 62, 64, 67, 69, 72, 74, 76]
bars = len(chords) * 4; total = int(bars * 4 * beat * SRM)
mus = np.zeros(total + SRM)
mrng = np.random.default_rng(7)
for b in range(bars):
    ch = chords[b % 4]; t0 = int(b * 4 * beat * SRM)
    for m in ch:
        seg = pad(hz(m), 4 * beat) * 0.12; mus[t0:t0 + len(seg)] += seg
    for k in range(8):  # арпеджио
        m = ch[k % 3] + (12 if k % 3 == 2 else 0)
        s = pluck(hz(m + 12), beat) * 0.10; i = t0 + int(k * beat * SRM / 2); mus[i:i + len(s)] += s
    for k in range(4):  # мелодия
        if mrng.random() < 0.65:
            m = scale[mrng.integers(0, len(scale))]
            s = pluck(hz(m), beat * 1.5) * 0.16; i = t0 + int(k * beat * SRM); mus[i:i + len(s)] += s
save('music_farm', mus[:total], SRM, 0.5)
print('audio ok')
