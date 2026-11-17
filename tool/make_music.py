"""Finger Jump — "cozy loop" arka plan müziğini sentezler.

Telifsiz, tamamen bu betikle üretilen kısa bir döngü:
  * 92 BPM, Fa majör, 16 ölçü (~42 sn), dikişsiz döngü
  * Üçgen dalga bas, yumuşak pulse arpej, müzik kutusu benzeri melodi,
    hafif kick + shaker, döngünün başına sarılan yumuşak yankı

Kullanım:
    python3 tool/make_music.py   # assets/audio/cozy_loop.ogg üretir (ffmpeg gerekir)

OGG Vorbis seçildi: MP3'ün kodlayıcı dolgusu döngüde küçük bir boşluk
bırakır, Vorbis boşluksuz döner.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 32000
BPM = 92
BEAT = 60.0 / BPM
BARS = 16
TOTAL_BEATS = BARS * 4
N = int(round(TOTAL_BEATS * BEAT * SR))

rng = np.random.default_rng(7)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env(n, a=0.01, d=0.25, s=0.0, r=0.05):
    """Basit ADSR (s=0 → plucky)."""
    t = np.arange(n) / SR
    e = np.ones(n)
    ai = t < a
    e[ai] = t[ai] / a
    di = t >= a
    e[di] = s + (1 - s) * np.exp(-(t[di] - a) / d)
    rn = int(r * SR)
    if rn > 0 and rn < n:
        e[-rn:] *= np.linspace(1, 0, rn)
    return e


def tri(f, n, phase=0.0):
    t = np.arange(n) / SR
    x = (t * f + phase) % 1.0
    return 4 * np.abs(x - 0.5) - 1


def pulse(f, n, duty=0.25):
    t = np.arange(n) / SR
    return np.where((t * f) % 1.0 < duty, 1.0, -1.0)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


mix = np.zeros(N)


def add(buf, start_beat, sig):
    s = int(round(start_beat * BEAT * SR)) % N
    n = len(sig)
    end = s + n
    if end <= N:
        buf[s:end] += sig
    else:  # döngünün başına sar
        k = N - s
        buf[s:] += sig[:k]
        buf[: n - k] += sig[k:]


# ─── Akorlar: F – Dm – Bb – C (×2), sonra Gm – C – F – F/A … ────────────────
F, Dm, Bb, C, Gm, Am = (
    [53, 57, 60], [50, 53, 57], [46, 50, 53], [48, 52, 55], [43, 46, 50], [45, 48, 52],
)
prog = [F, Dm, Bb, C, F, Dm, Bb, C, Gm, C, F, Dm, Gm, Am, Bb, C]

# Bas (üçgen) — 1. ve 3. vuruş, 3. vuruşta beşli.
for bar, ch in enumerate(prog):
    root = ch[0] - 12
    for beat, note in ((0, root), (2, root + 7), (3.5, root + 12)):
        dur = 0.5 if beat == 3.5 else 1.6
        n = int(dur * BEAT * SR)
        sig = tri(midi_hz(note), n) * env(n, 0.005, 0.35, 0.25, 0.08)
        add(mix, bar * 4 + beat, sig * (0.20 if beat == 3.5 else 0.30))

# Arpej (yumuşatılmış pulse) — sekizlikler, akor tonları yukarı-aşağı.
pattern = [0, 1, 2, 1, 0, 2, 1, 2]
for bar, ch in enumerate(prog):
    tones = [ch[0] + 12, ch[1] + 12, ch[2] + 12]
    for i, p in enumerate(pattern):
        n = int(0.45 * BEAT * SR)
        sig = pulse(midi_hz(tones[p]), n, 0.3) * env(n, 0.003, 0.12, 0.0, 0.03)
        add(mix, bar * 4 + i * 0.5, lowpass(sig, 1800) * 0.075)

# Melodi (müzik kutusu: sinüs + hafif üçgen, vibratolu). (vuruş, süre, nota)
mel = [
    # 1–4
    (0, 1, 72), (1, .5, 74), (1.5, .5, 72), (2, 1.5, 69), (4, 1, 69), (5, 1, 72),
    (6, 2, 74), (8, 1, 70), (9, .5, 72), (9.5, .5, 74), (10, 2, 77), (12, 1.5, 76),
    (13.5, .5, 74), (14, 2, 72),
    # 5–8
    (16, 1, 72), (17, .5, 74), (17.5, .5, 72), (18, 1.5, 69), (20, 1, 74), (21, 1, 77),
    (22, 2, 76), (24, 1, 74), (25, 1, 72), (26, 1, 70), (27, 1, 69), (28, 1.5, 67),
    (29.5, .5, 69), (30, 2, 72),
    # 9–12
    (32, 1.5, 74), (33.5, .5, 72), (34, 1, 70), (35, 1, 67), (36, 1, 72), (37, 1, 76),
    (38, 2, 79), (40, 1, 77), (41, .5, 76), (41.5, .5, 77), (42, 2, 72), (44, 1, 74),
    (45, 1, 77), (46, 2, 81),
    # 13–16
    (48, 1, 79), (49, 1, 77), (50, 2, 74), (52, 1, 76), (53, 1, 72), (54, 2, 69),
    (56, 1, 74), (57, 1, 72), (58, 1, 70), (59, 1, 69), (60, 1, 67), (61, 1, 72),
    (62, 2, 77),
]
for start, dur, note in mel:
    n = int((dur * BEAT + 0.35) * SR)
    t = np.arange(n) / SR
    f = midi_hz(note) * (1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t * 3, 0, 1))
    ph = np.cumsum(f) / SR
    sig = 0.75 * np.sin(2 * np.pi * ph) + 0.25 * (4 * np.abs((ph % 1) - 0.5) - 1)
    sig += 0.12 * np.sin(4 * np.pi * ph)  # müzik kutusu parıltısı
    add(mix, start, sig * env(n, 0.004, 0.5, 0.18, 0.12) * 0.16)

# Perküsyon: yumuşak kick (1, 3) + shaker (ara sekizlikler).
for b in range(TOTAL_BEATS):
    if b % 2 == 0:
        n = int(0.22 * SR)
        t = np.arange(n) / SR
        f = 110 * np.exp(-t * 18) + 45
        sig = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 16)
        add(mix, b, sig * 0.22)
    n = int(0.06 * SR)
    noise = lowpass(rng.standard_normal(n), 6000) - lowpass(rng.standard_normal(n), 900)
    add(mix, b + 0.5, noise * env(n, 0.002, 0.025) * 0.05)

# Yankı (dairesel → döngü dikişsiz).
delay = int(BEAT * 0.75 * SR)
wet = np.zeros(N)
src = mix.copy()
for k in range(1, 5):
    src = np.roll(src, delay) * 0.38
    wet += src
mix = mix + lowpass(wet, 2500) * 0.6

# Hafif sıcak doygunluk + normalize.
mix = np.tanh(mix * 1.4)
mix = mix / np.max(np.abs(mix)) * 0.85

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, "assets", "audio", "cozy_loop.ogg")
os.makedirs(os.path.dirname(out), exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
    wav = os.path.join(tmp, "cozy_loop.wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix * 32767).astype("<i2").tobytes())
    subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-y", "-i", wav,
         "-c:a", "libvorbis", "-q:a", "3", out],
        check=True,
    )
print(out, f"{N / SR:.1f}s")
