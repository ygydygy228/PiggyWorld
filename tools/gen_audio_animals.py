"""Голоса животных. Запуск: python3 tools/gen_audio_animals.py -> assets/audio/{moo,cluck,baa,meow,bark,squeak}.wav"""
import numpy as np, wave, os
SR = 22050
rng = np.random.default_rng(11)
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio'); os.makedirs(OUT, exist_ok=True)

def save(name, data, vol=0.8):
    d = np.clip(data / max(1e-9, np.max(np.abs(data))) * vol, -1, 1)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((d * 32767).astype(np.int16).tobytes())

def t(d): return np.linspace(0, d, int(d * SR), endpoint=False)
def lp(x, k): return np.convolve(x, np.ones(k) / k, mode='same')
def env(n, a, r):
    e = np.ones(n); na, nr = min(int(a * SR), n // 2), min(int(r * SR), n // 2)
    if na: e[:na] = np.linspace(0, 1, na)
    if nr: e[-nr:] *= np.linspace(1, 0, nr)
    return e
def glide(f0, f1, d, harm=(1, .5, .25), vib=0.0):
    tt = t(d); f = np.linspace(f0, f1, len(tt)) * (1 + vib * np.sin(2 * np.pi * 7 * tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return sum(a * np.sin(ph * (i + 1)) for i, a in enumerate(harm)) * env(len(tt), 0.04, 0.2)

save('moo', lp(glide(110, 85, 0.9, (1, .8, .5, .3)), 3))
save('baa', lp(glide(330, 290, 0.6, (1, .7, .5, .3, .2), 0.08) + rng.uniform(-.1, .1, int(0.6 * SR)), 3))
save('meow', np.concatenate([glide(520, 780, 0.2, (1, .4)), glide(780, 480, 0.3, (1, .4))]))
bark = lambda: (lp(rng.uniform(-1, 1, int(0.12 * SR)), 4) + np.sin(2 * np.pi * 240 * t(0.12))) * np.exp(-t(0.12) * 18)
save('bark', np.concatenate([bark(), np.zeros(int(0.08 * SR)), bark()]))
chirp = lambda f: np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * 1.4, int(0.06 * SR))) / SR) * np.hanning(int(0.06 * SR))
save('cluck', np.concatenate([chirp(700), np.zeros(int(0.04 * SR)), chirp(820), np.zeros(int(0.04 * SR)), chirp(760)]))
save('squeak', glide(1800, 2400, 0.09, (1,)))
print('animal sounds ok')
