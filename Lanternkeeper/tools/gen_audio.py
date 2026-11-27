#!/usr/bin/env python3
"""효과음과 배경음악을 수식으로 합성해 assets/audio/*.wav 로 저장한다.
외부 음원을 쓰지 않으므로 라이선스 문제가 없다.  실행: python3 tools/gen_audio.py
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1127)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, r=None, curve=3.0):
    """attack 후 지수 감쇠"""
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-4), 0, 1)
    dur = n / SR
    rel = np.exp(-curve * x / max(dur, 1e-4)) if r is None else np.exp(-x / r)
    return att * rel


def sine(f, dur, phase=0.0):
    tt = t(dur)
    if callable(f):
        ph = 2 * np.pi * np.cumsum(f(tt)) / SR
        return np.sin(ph + phase)
    return np.sin(2 * np.pi * f * tt + phase)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, a):
    """1-pole lowpass, a in (0,1): 클수록 어둡다"""
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = acc * a + x[i] * (1 - a)
        y[i] = acc
    return y


def highpass(x, a):
    return x - lowpass(x, a)


def pad_to(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def norm(x, peak=0.8):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write(name, x, peak=0.8):
    x = norm(x, peak)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("wrote", name, f"{len(x)/SR:.2f}s")


def note(n):
    """MIDI 번호 → Hz"""
    return 440.0 * 2 ** ((n - 69) / 12)


def bell(f, dur, bright=1.0):
    x = sine(f, dur) + 0.5 * bright * sine(f * 2.01, dur) + 0.25 * bright * sine(f * 3.02, dur)
    return x * env(len(x), 0.002, curve=5)


# ── 효과음 ──
def sfx():
    write("ui_tap", sine(lambda tt: 900 - 2500 * tt, 0.05) * env(int(SR * 0.05), 0.001, curve=6), 0.4)
    write("ui_confirm", mix(bell(660, 0.18), np.concatenate([np.zeros(int(SR * 0.06)), bell(990, 0.2)])), 0.5)
    th = lowpass(noise(0.08), 0.85) * env(int(SR * 0.08), 0.002, curve=8)
    write("step", mix(th, sine(120, 0.08) * env(int(SR * 0.08), 0.002, curve=8) * 0.6), 0.35)
    wh = lowpass(noise(0.22), 0.7) * np.sin(np.linspace(0, np.pi, int(SR * 0.22))) * 0.6
    write("place", mix(wh, np.concatenate([np.zeros(int(SR * 0.08)), bell(523, 0.5, 0.6) * 0.5])), 0.55)
    sw = sine(lambda tt: 90 + 160 * tt, 0.6) * np.sin(np.linspace(0, np.pi, int(SR * 0.6))) ** 1.5
    sp = highpass(noise(0.6), 0.3) * env(int(SR * 0.6), 0.2, curve=4) * 0.15
    write("ignite", mix(sw, sp, np.concatenate([np.zeros(int(SR * 0.25)), bell(784, 0.6, 0.4) * 0.25])), 0.7)
    hb = lowpass(noise(0.12), 0.4) * env(int(SR * 0.12), 0.001, curve=7)
    write("hit", mix(hb, np.sign(sine(180, 0.1)) * env(int(SR * 0.1), 0.001, curve=9) * 0.25), 0.6)
    k = mix(bell(988, 0.35), np.concatenate([np.zeros(int(SR * 0.07)), bell(740, 0.35)]),
            np.concatenate([np.zeros(int(SR * 0.14)), bell(494, 0.5)]))
    write("kill", k, 0.55)
    write("chain", bell(1320, 0.18, 0.8), 0.45)
    fz = mix(*[sine(f, 0.5) * env(int(SR * 0.5), 0.01, curve=4) * a for f, a in [(2093, 1), (2637, .7), (3136, .5), (4186, .3)]])
    fz *= 1 + 0.3 * sine(23, 0.5)
    write("freeze", fz, 0.4)
    sh = mix(*[np.concatenate([np.zeros(int(SR * d)), highpass(noise(0.12), 0.2) * env(int(SR * 0.12), 0.001, curve=6)])
               for d in (0, 0.04, 0.09, 0.15)])
    write("shatter", mix(sh, bell(2800, 0.3, 1.0) * 0.3), 0.55)
    hl = mix(*[np.concatenate([np.zeros(int(SR * d)), bell(note(n), 0.4, 0.3)]) for d, n in [(0, 72), (0.08, 76), (0.16, 79)]])
    write("heal", hl, 0.45)
    hu = mix(sine(lambda tt: 110 - 60 * tt, 0.22) * env(int(SR * 0.22), 0.001, curve=6), lowpass(noise(0.15), 0.6) * env(int(SR * 0.15), 0.001, curve=8) * 0.6)
    write("hurt", hu, 0.75)
    ex = lowpass(noise(0.7), 0.93) * env(int(SR * 0.7), 0.002, curve=5)
    write("explode", mix(ex, sine(lambda tt: 70 - 40 * tt, 0.5) * env(int(SR * 0.5), 0.002, curve=5)), 0.8)
    write("deflect", mix(bell(1500, 0.35, 1.0), bell(2310, 0.3, 0.8) * 0.6), 0.45)
    write("enemy_step", lowpass(noise(0.05), 0.8) * env(int(SR * 0.05), 0.001, curve=9), 0.2)
    tw = sine(lambda tt: 600 - 400 * tt, 0.18) * env(int(SR * 0.18), 0.001, curve=6)
    write("shoot", mix(tw, highpass(noise(0.1), 0.5) * env(int(SR * 0.1), 0.001, curve=9) * 0.4), 0.5)
    wn = mix(*[np.concatenate([np.zeros(int(SR * 0.12 * i)), bell(note(n), 0.9, 0.5)]) for i, n in enumerate([62, 66, 69, 74, 78, 81])])
    write("win", wn, 0.55)
    ls = mix(*[sine(note(n), 2.0) * env(int(SR * 2.0), 0.05, curve=2.5) for n in (45, 48, 52)])
    write("lose", ls, 0.55)
    write("coin", mix(bell(1568, 0.12), np.concatenate([np.zeros(int(SR * 0.07)), bell(2093, 0.25)])), 0.4)
    write("page", lowpass(highpass(noise(0.14), 0.2), 0.3) * np.sin(np.linspace(0, np.pi, int(SR * 0.14))), 0.3)
    gong = mix(*[sine(f, 2.2) * env(int(SR * 2.2), 0.01, curve=2.2) * a for f, a in [(98, 1), (147, .5), (233, .35), (311, .2)]])
    write("banner", gong, 0.6)
    write("water", lowpass(noise(0.4), 0.75) * np.sin(np.linspace(0, np.pi, int(SR * 0.4))) * (1 + 0.5 * sine(7, 0.4)), 0.4)


# ── 배경음악 (32초 반복) ──
def pad_chord(notes, dur, detune=0.003, bright=0.3):
    out = np.zeros(int(SR * dur))
    for n in notes:
        f = note(n)
        for d in (-detune, 0, detune):
            out += sine(f * (1 + d), dur, rng.uniform(0, 6.28))
            out += bright * sine(f * 2 * (1 + d), dur, rng.uniform(0, 6.28)) * 0.3
    fade = np.minimum(1, np.minimum(np.arange(len(out)) / (SR * 1.5), (len(out) - np.arange(len(out))) / (SR * 1.5)))
    return out * fade


def music(name, chords, scale, base_oct=0, pluck_rate=1.2, bpm=0, drone=None, bright=0.3, drip=False):
    length = 32.0
    total = int(SR * length)
    fade = int(SR * 2.0)
    out = np.zeros(total + fade)
    seg = length / len(chords)
    for i, ch in enumerate(chords):
        p = pad_chord([n + base_oct for n in ch], seg + 2.0, bright=bright) * 0.12
        s = int(SR * i * seg)
        out[s: s + len(p)] += p[: len(out) - s]
    if drone is not None:
        dr = sine(note(drone), length + 2.0) * 0.08 + sine(note(drone) * 1.5, length + 2.0) * 0.03
        dr *= 1 + 0.25 * sine(0.125, length + 2.0)
        out[: len(dr)] += dr
    # 가끔 울리는 맑은 음
    tt = 0.5
    while tt < length - 1:
        n = scale[rng.integers(0, len(scale))] + base_oct + 12
        b = bell(note(n), 1.6, 0.4) * rng.uniform(0.05, 0.11)
        s = int(SR * tt)
        out[s: s + len(b)] += b[: len(out) - s]
        tt += rng.exponential(pluck_rate) + 0.35
    if drip:
        tt = 0.3
        while tt < length - 1:
            b = bell(rng.uniform(1800, 2600), 0.15, 0.2) * 0.05
            s = int(SR * tt)
            out[s: s + len(b)] += b[: len(out) - s]
            tt += rng.exponential(1.7) + 0.4
    if bpm > 0:
        beat = 60.0 / bpm
        tt = 0.0
        k = 0
        while tt < length:
            kd = sine(lambda x: 80 - 50 * x * 4, 0.25) * env(int(SR * 0.25), 0.002, curve=8) * (0.22 if k % 2 == 0 else 0.12)
            s = int(SR * tt)
            out[s: s + len(kd)] += kd[: len(out) - s]
            if k % 2 == 1:
                hh = highpass(noise(0.05), 0.1) * env(int(SR * 0.05), 0.001, curve=9) * 0.03
                out[s: s + len(hh)] += hh[: len(out) - s]
            tt += beat
            k += 1
    # 끝부분을 앞부분과 겹쳐 이음매 없이 반복
    head = out[:fade].copy()
    tail = out[total: total + fade]
    ramp = np.linspace(0, 1, fade)
    out[:fade] = head * ramp + tail * (1 - ramp)
    write("music_" + name, out[:total], 0.5)


if __name__ == "__main__":
    sfx()
    music("title", [[50, 57, 62, 65], [46, 53, 58, 62], [48, 55, 60, 64], [45, 52, 57, 60]], [62, 65, 67, 69, 72], pluck_rate=1.6)
    music("fog", [[45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59], [40, 47, 52, 55]], [57, 60, 62, 64, 67], pluck_rate=1.4, drone=33)
    music("mirror", [[52, 59, 64, 66], [50, 57, 62, 66], [48, 55, 60, 64], [50, 57, 62, 69]], [64, 66, 69, 71, 74, 76], pluck_rate=0.9, bright=0.8)
    music("library", [[48, 55, 60, 63], [44, 51, 56, 60], [46, 53, 58, 62], [43, 50, 55, 58]], [60, 63, 65, 67, 70], pluck_rate=1.8, drip=True)
    music("eclipse", [[42, 49, 54, 57], [40, 47, 52, 55], [38, 45, 50, 54], [37, 44, 49, 52]], [54, 57, 59, 61, 64], pluck_rate=2.2, drone=30, bright=0.15)
    music("boss", [[45, 52, 57, 60], [44, 51, 56, 59], [41, 48, 53, 57], [40, 47, 52, 56]], [57, 59, 60, 64, 65], pluck_rate=0.7, bpm=96, drone=33)
