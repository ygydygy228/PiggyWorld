"""Звуки выживания: вой, укус, боль, еда. Запуск: python3 tools/gen_audio_hardcore.py"""
import numpy as np, wave, os
SR = 22050
rng = np.random.default_rng(23)
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio'); os.makedirs(OUT, exist_ok=True)
def save(name, data, vol=0.8):
    d = np.clip(data / max(1e-9, np.max(np.abs(data))) * vol, -1, 1)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((d * 32767).astype(np.int16).tobytes())
def t(d): return np.linspace(0, d, int(d * SR), endpoint=False)
def lp(x, k): return np.convolve(x, np.ones(k) / k, mode='same')
tt = t(1.4)
f = 260 + 220 * np.sin(np.pi * np.minimum(1, tt / 1.0) * 0.5) ** 2 - 120 * np.clip(tt - 0.9, 0, None) / 0.5
f = f * (1 + 0.03 * np.sin(2 * np.pi * 6 * tt))
ph = 2 * np.pi * np.cumsum(f) / SR
env = np.minimum(1, tt / 0.15) * np.minimum(1, (1.4 - tt) / 0.35)
save('howl', (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)) * env, 0.7)
tt = t(0.16); save('bite', (lp(rng.uniform(-1, 1, len(tt)), 5) + np.sin(2 * np.pi * 120 * tt)) * np.exp(-tt * 22))
tt = t(0.22); save('hurt', np.sin(2 * np.pi * np.cumsum(np.linspace(220, 90, len(tt))) / SR) * np.exp(-tt * 10), 0.8)
crunch = lambda: lp(rng.uniform(-1, 1, int(0.05 * SR)), 3) * np.hanning(int(0.05 * SR))
save('eat', np.concatenate([crunch(), np.zeros(int(0.05 * SR)), crunch(), np.zeros(int(0.06 * SR)), crunch()]), 0.7)
print('hardcore audio ok')
