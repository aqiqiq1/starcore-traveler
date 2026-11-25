#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《星核旅人》DLC 原创 BGM 生成器
================================
全部声音由本脚本用 numpy 合成，无外部采样、无第三方循环素材。
用法:
    python generate_music.py trial
    python generate_music.py rift
    python generate_music.py loom
    python generate_music.py all

设计要点:
- 每首曲子的循环长度为精确的整数小节，所有持续音/低频振荡器频率都吸附到
  1/loop_length 的整数倍，LFO 周期也取整数个循环 -> 循环点两侧天然连续。
- 所有一次性音符都做"环绕叠加"(写到 buffer 末尾后从头部继续)，混响用
  频域循环卷积，因此尾音跨过循环点也不会被切断。
- 峰值统一归一化到 -8.0 dBFS 左右，留出 OGG 编码的余量。
"""

import argparse
import os
import numpy as np
import soundfile as sf
from scipy import signal
from scipy.ndimage import gaussian_filter1d

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET_PEAK_DB = -8.0

RNG_MASTER = np.random.default_rng(20261126)


# ----------------------------------------------------------------------------
# 基础工具
# ----------------------------------------------------------------------------

def db_to_lin(db):
    return 10.0 ** (db / 20.0)


def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def snap(freq, loop_len):
    """把频率吸附到 1/loop_len 的整数倍，保证整数周期。"""
    k = max(1, int(round(freq * loop_len)))
    return k / loop_len


def pan_gains(pan):
    a = (np.clip(pan, -1, 1) + 1.0) * np.pi / 4.0
    return np.cos(a), np.sin(a)


def cosine_fade(n, fade_in, fade_out):
    env = np.ones(n)
    ni = min(n, int(fade_in * SR))
    no = min(n, int(fade_out * SR))
    if ni > 0:
        env[:ni] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, ni))
    if no > 0:
        env[-no:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, no))
    return env


def env_points(n, points):
    """points: [(seconds, gain), ...]，余弦平滑插值，0 起 0 收。"""
    t = np.arange(n) / SR
    times = np.array([p[0] for p in points], dtype=float)
    vals = np.array([p[1] for p in points], dtype=float)
    out = np.interp(t, times, vals)
    # 用 15 ms 滑动平均柔化折点
    k = max(3, int(0.015 * SR))
    kernel = np.ones(k) / k
    out = np.convolve(out, kernel, mode="same")
    out[0] = 0.0
    out[-1] = 0.0
    return out


class Mix:
    def __init__(self, seconds):
        self.N = int(round(seconds * SR))
        self.L = self.N / SR
        self.dry = np.zeros((self.N, 2), np.float64)
        self.send = np.zeros((self.N, 2), np.float64)

    def add(self, start_s, sig, gain=1.0, pan=0.0, rev=0.0):
        if sig.ndim == 1:
            gl, gr = pan_gains(pan)
            left = sig * gl
            right = sig * gr
        else:
            left = sig[:, 0]
            right = sig[:, 1]
        left = left * gain
        right = right * gain
        n = len(left)
        if n > self.N:
            # 极少见：把超长事件环绕叠加
            reps = int(np.ceil(n / self.N))
            for r in range(reps):
                seg = slice(r * self.N, min(n, (r + 1) * self.N))
                self._place(start_s + r * self.L, left[seg], right[seg], rev)
            return
        self._place(start_s, left, right, rev)

    def _place(self, start_s, left, right, rev):
        start = int(round(start_s * SR)) % self.N
        n = len(left)
        end = start + n
        if end <= self.N:
            self.dry[start:end, 0] += left
            self.dry[start:end, 1] += right
            if rev:
                self.send[start:end, 0] += left * rev
                self.send[start:end, 1] += right * rev
        else:
            k = self.N - start
            self.dry[start:, 0] += left[:k]
            self.dry[start:, 1] += right[:k]
            self.dry[: end - self.N, 0] += left[k:]
            self.dry[: end - self.N, 1] += right[k:]
            if rev:
                self.send[start:, 0] += left[:k] * rev
                self.send[start:, 1] += right[:k] * rev
                self.send[: end - self.N, 0] += left[k:] * rev
                self.send[: end - self.N, 1] += right[k:] * rev


# ----------------------------------------------------------------------------
# 周期噪声 / 混响
# ----------------------------------------------------------------------------

def periodic_noise(N, rng, shape_fn):
    freqs = np.fft.rfftfreq(N, 1.0 / SR)
    spec = rng.normal(size=len(freqs)) + 1j * rng.normal(size=len(freqs))
    x = np.fft.irfft(spec * shape_fn(freqs), n=N)
    s = np.std(x)
    return x / s if s > 1e-12 else x


def band_shape(center, octaves):
    def fn(f):
        z = np.log2(np.maximum(f, 1.0) / center) / octaves
        return np.exp(-0.5 * z * z)
    return fn


def low_shape(cut, order=2):
    def fn(f):
        return 1.0 / np.sqrt(1.0 + (f / cut) ** (2 * order))
    return fn


def high_shape(cut, order=2):
    def fn(f):
        return 1.0 / np.sqrt(1.0 + (cut / np.maximum(f, 1e-6)) ** (2 * order))
    return fn


def fft_lowpass(x, cutoff, order=2):
    """对整段循环做零相位低通，保持循环周期性。"""
    N = x.shape[0]
    freqs = np.fft.rfftfreq(N, 1.0 / SR)
    g = 1.0 / np.sqrt(1.0 + (freqs / cutoff) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x, axis=0) * g[:, None], n=N, axis=0)


def make_reverb_ir(seconds, rt60, rng, bright=0.35):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    dark = rng.normal(size=n) * np.exp(-6.9078 * t / rt60)
    bright_n = rng.normal(size=n) * np.exp(-6.9078 * t / (rt60 * 0.45))
    # 频谱整形（对 IR 本身做因果滤波，不影响循环）
    sos_d = signal.butter(2, 2400, "low", fs=SR, output="sos")
    sos_b = signal.butter(2, 2400, "high", fs=SR, output="sos")
    ir = signal.sosfilt(sos_d, dark) + bright * signal.sosfilt(sos_b, bright_n)
    # 早反射
    for delay_ms, g in [(13, 0.5), (23, -0.35), (37, 0.3), (53, -0.22), (71, 0.18)]:
        idx = int(delay_ms * 1e-3 * SR)
        if idx < n:
            ir[idx] += g
    ir[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    e = np.sum(ir ** 2)
    return ir / np.sqrt(e)


def circular_reverb(send, ir_l, ir_r):
    N = send.shape[0]
    out = np.zeros_like(send)
    out[:, 0] = np.fft.irfft(np.fft.rfft(send[:, 0], n=N) *
                             np.fft.rfft(ir_l, n=N), n=N)
    out[:, 1] = np.fft.irfft(np.fft.rfft(send[:, 1], n=N) *
                             np.fft.rfft(ir_r, n=N), n=N)
    return out


# ----------------------------------------------------------------------------
# 乐器
# ----------------------------------------------------------------------------

def pad_note(freq, N, loop_len, rng, partials=(1, 2, 3, 4.0, 5.0, 6.0),
             amps=(1, .45, .26, .13, .08, .05), lfo_depth=0.18,
             detune_cents=(0.0, 4.5), width=0.55):
    """缓慢呼吸的加法合成 pad，左右用不同相位以获取宽度。"""
    t = np.arange(N) / SR
    out = np.zeros((N, 2))
    for i, (r, a) in enumerate(zip(partials, amps)):
        if a <= 0:
            continue
        base = snap(freq * r, loop_len)
        for ch, det in enumerate(detune_cents):
            f = snap(base * (2 ** (det / 1200.0)), loop_len)
            ph = rng.uniform(0, 2 * np.pi)
            cyc = 1 + (i + ch) % 3
            lfo = 1.0 - lfo_depth + lfo_depth * (0.5 + 0.5 * np.sin(
                2 * np.pi * cyc * t / loop_len + ph * 0.7))
            g = a * (1.0 if ch == 0 else 0.55)
            out[:, ch] += g * lfo * np.sin(2 * np.pi * f * t + ph)
    # 轻微高频滚降；必须用 FFT 零相位滤波，避免破坏循环接缝
    out = fft_lowpass(out, 5200)
    return out * width


def modal_stone(f0, dur, rng, bright=1.0, attack=0.0025):
    n = int(dur * SR)
    t = np.arange(n) / SR
    ratios = [1.0, 2.01, 3.03, 4.16, 5.43, 6.79, 8.21]
    amps = [1.0, .52, .34, .22, .16, .11, .08]
    taus = [dur * .62, dur * .45, dur * .34, dur * .26, dur * .19, dur * .14, dur * .10]
    x = np.zeros(n)
    for i, (r, a, tau) in enumerate(zip(ratios, amps, taus)):
        ph = rng.uniform(0, 2 * np.pi)
        x += a * np.sin(2 * np.pi * f0 * r * t + ph) * np.exp(-t / tau)
    # 敲击噪声
    nz = rng.normal(size=n) * np.exp(-t / (0.012 + 0.006 * bright))
    sos = signal.butter(2, [900, 5200], "band", fs=SR, output="sos")
    x += 0.24 * bright * signal.sosfilt(sos, nz)
    x *= 1.0 - np.exp(-t / attack)
    return x


def soft_tone(f0, dur, rng, attack=0.25, release=1.8, harmonics=(1, 2, 3),
              amps=(1, .22, .08)):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for r, a in zip(harmonics, amps):
        x += a * np.sin(2 * np.pi * f0 * r * t + rng.uniform(0, 2 * np.pi))
    env = np.ones(n)
    na = min(n, int(attack * SR))
    nr = min(n, int(release * SR))
    env[:na] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, na))
    env[-nr:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, nr))
    return x * env / 1.3


def fm_ping(f0, dur, rng, ratio=2.76, index=2.2, decay=1.6, attack=0.004):
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod = index * np.exp(-t / (decay * 0.35)) * np.sin(2 * np.pi * f0 * ratio * t)
    x = np.sin(2 * np.pi * f0 * t + mod)
    x *= np.exp(-t / decay) * (1.0 - np.exp(-t / attack))
    return x * 0.6


def kick(dur=0.55, f0=150, f1=44, pitch_tau=0.035, amp_tau=0.18, click=0.25, rng=None):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / pitch_tau)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * np.exp(-t / amp_tau) * (1.0 - np.exp(-t / 0.0015))
    if click and rng is not None:
        nz = rng.normal(size=n) * np.exp(-t / 0.006)
        sos = signal.butter(2, 1800, "high", fs=SR, output="sos")
        x += click * signal.sosfilt(sos, nz) * 0.5
    return x


def tom(f0, dur=0.5, rng=None, drop=0.55):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (1.0 + drop * np.exp(-t / 0.05))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * np.exp(-t / 0.26) * (1.0 - np.exp(-t / 0.002))
    if rng is not None:
        nz = rng.normal(size=n) * np.exp(-t / 0.02)
        sos = signal.butter(2, [120, 900], "band", fs=SR, output="sos")
        x += 0.25 * signal.sosfilt(sos, nz)
    return x * 0.9


def snare(dur=0.28, rng=None, tone=0.22, bright=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = rng.normal(size=n)
    sos = signal.butter(2, [1300, 6200], "band", fs=SR, output="sos")
    nz = signal.sosfilt(sos, nz) * np.exp(-t / 0.085) * (1.0 - np.exp(-t / 0.001))
    body = np.sin(2 * np.pi * 186 * t) * np.exp(-t / 0.055)
    return (nz * 0.8 * bright + body * tone) * 0.8


def hat(dur=0.09, rng=None, open_=False):
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = rng.normal(size=n)
    sos = signal.butter(2, 5800, "high", fs=SR, output="sos")
    x = signal.sosfilt(sos, nz)
    x *= np.exp(-t / (0.12 if open_ else 0.035)) * (1.0 - np.exp(-t / 0.0008))
    return x * 0.5


def tick(dur=0.05, rng=None, f=3200):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.012)
    nz = rng.normal(size=n) * np.exp(-t / 0.004)
    sos = signal.butter(2, 2200, "high", fs=SR, output="sos")
    return (x * 0.35 + signal.sosfilt(sos, nz) * 0.4) * 0.5


def saw_bass(f0, dur, rng, cutoff=520):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = signal.sawtooth(2 * np.pi * f0 * t)
    sos = signal.butter(2, cutoff, "low", fs=SR, output="sos")
    x = signal.sosfilt(sos, x)
    sub = np.sin(2 * np.pi * f0 * t)
    # 保持到接近音符末尾再快速收尾，给 BOSS 提供持续的低频密度
    env = 1.0 - np.exp(-t / 0.004)
    env *= np.clip((dur - t) / 0.018, 0.0, 1.0)
    env *= 0.82 + 0.18 * np.exp(-t / 0.12)
    return (x * 0.5 + sub * 0.8) * env


def pluck(f0, dur, rng, cutoff=1600, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = signal.sawtooth(2 * np.pi * f0 * t + rng.uniform(0, 2 * np.pi))
    sos = signal.butter(2, cutoff, "low", fs=SR, output="sos")
    x = signal.sosfilt(sos, x)
    env = (1.0 - np.exp(-t / 0.004)) * np.exp(-t / 0.28)
    return x * env * amp


def noise_sweep(dur, rng, f_start=300, f_end=6000, shape=1.0):
    """用两段滤波噪声交叉淡化做扫频，起止都归零。"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = rng.normal(size=n)
    low = signal.sosfilt(signal.butter(2, max(80, f_start * 1.6), "low", fs=SR, output="sos"), nz)
    high = signal.sosfilt(signal.butter(2, max(120, f_end * 0.7), "high", fs=SR, output="sos"), nz)
    mix = np.linspace(0, 1, n) ** shape
    x = low * (1 - mix) + high * mix
    env = np.sin(np.pi * np.linspace(0, 1, n)) ** 2
    return x * env


# ----------------------------------------------------------------------------
# 三首曲子
# ----------------------------------------------------------------------------

def build_trial():
    bpm = 60.0
    bars = 16
    beat = 60.0 / bpm
    dur = bars * 4 * beat  # 64 s
    m = Mix(dur)
    N, L = m.N, m.L
    rng = np.random.default_rng(1101)
    t = np.arange(N) / SR

    # 1) 连续低音 drone：D1 / D2 / A2 / D3
    drone = np.zeros((N, 2))
    drone_spec = [
        (midi_hz(26), 0.32, 0.0),   # D1 36.71
        (midi_hz(38), 0.30, 0.30),  # D2 73.42
        (midi_hz(45), 0.26, -0.30), # A2 110
        (midi_hz(50), 0.15, 0.0),   # D3 146.83
    ]
    for f0, g, pan in drone_spec:
        f = snap(f0, L)
        for det in (-3.5, 0.0, 3.5):
            ff = snap(f * (2 ** (det / 1200.0)), L)
            ph = rng.uniform(0, 2 * np.pi)
            lfo = 0.82 + 0.18 * np.sin(2 * np.pi * (1 + int(abs(det) * 100)) * t / L + ph)
            sig = g * lfo * np.sin(2 * np.pi * ff * t + ph)
            gl, gr = pan_gains(pan)
            drone[:, 0] += sig * gl
            drone[:, 1] += sig * gr
    # 缓慢的八度呼吸
    drone *= (1.0 + 0.06 * np.sin(2 * np.pi * 2 * t / L))[:, None]
    m.add(0, drone, gain=0.25, rev=0.25)

    # 2) 石造空间的空气层
    air_l = periodic_noise(N, rng, band_shape(1150, 1.05))
    air_r = periodic_noise(N, rng, band_shape(1350, 1.15))
    for sig, ch in ((air_l, 0), (air_r, 1)):
        lfo = 0.55 + 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * t / L + ch * 1.7))
        m.dry[:, ch] += sig * lfo * db_to_lin(-27)
    low_air = periodic_noise(N, rng, band_shape(300, 1.2))
    m.add(0, low_air, gain=db_to_lin(-32), rev=0.4)
    mid_air = periodic_noise(N, rng, band_shape(800, 1.0))
    m.add(0, mid_air, gain=db_to_lin(-28), rev=0.5)
    air_hi = periodic_noise(N, rng, band_shape(4200, 0.9))
    hi_lfo = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * t / L + 0.7))
    m.add(0, air_hi * hi_lfo, gain=db_to_lin(-40), rev=0.8)

    # 3) 和声垫：Dm(add9) 的开放排列
    chord = [(midi_hz(38), 0.22, -0.15), (midi_hz(45), 0.24, 0.3),
             (midi_hz(53), 0.22, -0.25), (midi_hz(57), 0.22, 0.2),
             (midi_hz(62), 0.18, 0.0)]
    for f0, g, pan in chord:
        sig = pad_note(f0, N, L, rng, lfo_depth=0.22, width=1.0)
        m.add(0, sig, gain=g * 0.135, pan=pan, rev=0.45)

    # 4) 第二半段的高空微光（32 s 进入、56 s 退去）
    shimmer_env = env_points(N, [(0, 0), (30, 0), (38, 0.8), (50, 0.8), (58, 0), (64, 0)])
    for note, pan in [(midi_hz(69), -0.5), (midi_hz(76), 0.45), (midi_hz(74), 0.0)]:
        f = snap(note, L)
        sig = np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
        sig += 0.3 * np.sin(2 * np.pi * snap(note * 2.01, L) * t + rng.uniform(0, 2 * np.pi))
        sig *= shimmer_env * (0.7 + 0.3 * np.sin(2 * np.pi * 3 * t / L + pan))
        m.add(0, sig, gain=db_to_lin(-32), pan=pan, rev=0.8)

    # 5) 稀疏的石头共鸣
    stone_events = [
        (0.4, midi_hz(50), 0.23, -0.35, 7.5),   # D3
        (16.6, midi_hz(57), 0.21, 0.4, 6.5),    # A3
        (30.2, midi_hz(53), 0.26, -0.2, 7.0),   # F3
        (46.8, midi_hz(62), 0.17, 0.55, 6.0),   # D4
        (57.9, midi_hz(57), 0.14, -0.5, 5.5),   # A3 尾音绕回开头
    ]
    for ts, f0, g, pan, length in stone_events:
        sig = modal_stone(f0, length, rng, bright=0.8 + 0.3 * rng.random())
        m.add(ts, sig, gain=g, pan=pan, rev=0.85)

    # 6) 极稀疏的远处三音动机（不构成强旋律）
    motif = [(40.5, midi_hz(62), 0.5), (45.2, midi_hz(65), 0.45), (50.6, midi_hz(64), 0.4)]
    for ts, f0, g in motif:
        sig = soft_tone(f0, 5.5, rng, attack=0.5, release=2.8)
        m.add(ts, sig, gain=g * 0.08, pan=0.15, rev=0.9)

    # 7) 极轻的低频心跳，让空间不完全静止
    for ts in (12.0, 44.0):
        k = kick(dur=1.8, f0=60, f1=34, pitch_tau=0.14, amp_tau=0.55, click=0.0)
        m.add(ts, k, gain=0.045, rev=0.35)

    return finalize(m, bpm, "D minor (Aeolian / add9 colour)", "trial_ambience", bars,
                    shelf_db=2.5)


def build_rift():
    bpm = 72.0
    bars = 24
    beat = 60.0 / bpm
    dur = bars * 4 * beat  # 80 s
    m = Mix(dur)
    N, L = m.N, m.L
    rng = np.random.default_rng(2202)
    t = np.arange(N) / SR

    # 1) 低频基座：F1/F2/C3 + 一个很轻的 B2 三全音
    for note, g, pan, lfo_cyc in [
        (29, 0.55, 0.0, 2),   # F1 43.65
        (41, 0.28, 0.15, 1),  # F2 87.31
        (48, 0.18, -0.2, 2),  # C3 130.81
        (47, 0.055, 0.0, 1),  # B2 三全音染色
    ]:
        f = snap(midi_hz(note), L)
        ph = rng.uniform(0, 2 * np.pi)
        lfo = 0.75 + 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * lfo_cyc * t / L + ph))
        sig = lfo * np.sin(2 * np.pi * f * t + ph)
        m.add(0, sig, gain=g * 0.2, pan=pan, rev=0.3)

    # 2) 和声垫：Fm9 / Abmaj7 的模糊边界
    for note, g, pan in [(41, 0.6, -0.2), (48, 0.4, 0.25), (56, 0.28, -0.1),
                        (63, 0.16, 0.4), (58, 0.10, 0.0)]:
        sig = pad_note(midi_hz(note), N, L, rng, lfo_depth=0.3, width=1.0,
                       amps=(1, .5, .3, .16, .09, .05))
        m.add(0, sig, gain=g * 0.1, pan=pan, rev=0.55)

    # 3) 空气层：高频风 + 中频气流，缓慢交叉
    hi = periodic_noise(N, rng, band_shape(4200, 1.25))
    hi2 = periodic_noise(N, rng, band_shape(6500, 1.0))
    for sig, pan, ph in ((hi, -0.6, 0.0), (hi2, 0.6, 2.1)):
        lfo = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * 3 * t / L + ph))
        m.add(0, sig * lfo, gain=db_to_lin(-30), pan=pan, rev=0.7)
    mid = periodic_noise(N, rng, band_shape(700, 1.0))
    mid_lfo = 0.4 + 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 1 * t / L + 1.2))
    m.add(0, mid * mid_lfo, gain=db_to_lin(-30), rev=0.5)

    # 高空微光：F5 / Ab5 / C6，只在 24~68 s 出现
    sh_env = env_points(N, [(0, 0), (24, 0), (32, 0.7), (60, 0.7), (70, 0), (80, 0)])
    for note, pan in [(77, -0.45), (80, 0.4), (84, 0.0)]:
        f = snap(midi_hz(note), L)
        sig = np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
        sig *= sh_env * (0.75 + 0.25 * np.sin(2 * np.pi * 2 * t / L + pan))
        m.add(0, sig, gain=db_to_lin(-37), pan=pan, rev=0.9)

    # 4) 低频心跳：每两小节一次，B 段加密为每小节
    for bar in range(bars):
        every = 2 if (bar < 8 or bar >= 20) else 1
        if bar % every:
            continue
        ts = bar * 4 * beat
        k1 = kick(dur=2.2, f0=58, f1=35, pitch_tau=0.09, amp_tau=0.55, click=0.0)
        m.add(ts, k1, gain=0.20, rev=0.35)
        k2 = kick(dur=1.6, f0=48, f1=33, pitch_tau=0.07, amp_tau=0.38, click=0.0)
        m.add(ts + 0.32, k2, gain=0.085, rev=0.4)

    # 5) 机械/金属微光：稀疏的 FM 点
    ping_events = [(7.8, 1180, -0.5), (21.0, 890, 0.55), (36.4, 1560, -0.3),
                   (45.5, 740, 0.4), (58.2, 1320, -0.55), (69.0, 990, 0.25),
                   (76.4, 620, 0.0)]
    for i, (ts, f0, pan) in enumerate(ping_events):
        sig = fm_ping(f0, 7.0, rng, ratio=[2.41, 3.17, 1.83][i % 3],
                      index=1.4, decay=3.2)
        m.add(ts, sig, gain=0.075, pan=pan, rev=0.95)

    # 6) 阶段呼吸：中段加入低密度的石质摩擦，末段退去
    rub_env = env_points(N, [(0, 0), (26.7, 0), (34, 0.7), (50, 0.7), (60, 0), (80, 0)])
    rub = periodic_noise(N, rng, band_shape(320, 1.1))
    m.add(0, rub * rub_env, gain=db_to_lin(-32), pan=0.2, rev=0.8)

    # 7) 极低的脉冲录音带质感（每 4 小节一次的软噪声爆发）
    for bar in (4, 8, 16, 20):
        ts = bar * 4 * beat
        nz = periodic_noise(int(2.5 * SR), rng, band_shape(1600, 1.3))
        env = np.sin(np.pi * np.linspace(0, 1, len(nz))) ** 2
        m.add(ts, nz * env, gain=0.02, pan=-0.35, rev=0.7)

    return finalize(m, bpm, "F minor (with B natural tritone colour)", "rift_ambience", bars)


def build_loom():
    bpm = 140.0
    bars = 36
    spb = 60.0 / bpm          # 每拍
    bar_len = 4 * spb
    dur = bars * bar_len      # 61.714 s
    m = Mix(dur)
    N, L = m.N, m.L
    rng = np.random.default_rng(3303)
    t = np.arange(N) / SR

    def bt(bar, beat=0.0):
        return (bar * 4 + beat) * spb

    # 0) 连续 drone + 段落和声垫
    for note, g, pan in [(38, 0.6, 0.0), (45, 0.3, 0.25), (50, 0.16, -0.3),
                        (62, 0.20, 0.15), (69, 0.11, -0.2)]:
        f = snap(midi_hz(note), L)
        ph = rng.uniform(0, 2 * np.pi)
        sig = np.sin(2 * np.pi * f * t + ph)
        sig += 0.25 * np.sin(2 * np.pi * snap(f * 1.005, L) * t + ph * 1.3)
        m.add(0, sig, gain=g * 0.16, pan=pan, rev=0.35)

    # 织机的高频气声：跟随八分音符轻轻开合
    loom_air = periodic_noise(N, rng, band_shape(3800, 1.0))
    ph8 = (t % (spb * 0.5)) / (spb * 0.5)
    loom_gate = 1.0 - 0.55 * (1.0 - np.exp(-ph8 * 30)) * np.exp(-ph8 * 7)
    m.add(0, loom_air * loom_gate, gain=db_to_lin(-34), rev=0.3)

    pad_layers = [
        # (start_bar, end_bar, [(midi, gain, pan), ...], fade_in_bars, fade_out_bars)
        (0, 12, [(53, 0.5, -0.25), (57, 0.35, 0.3), (62, 0.2, 0.0)], 2, 2),
        (12, 24, [(51, 0.45, -0.3), (58, 0.3, 0.35), (63, 0.22, 0.0)], 1, 2),
        (24, 36, [(53, 0.5, -0.2), (57, 0.3, 0.3), (60, 0.22, 0.0)], 1, 1),
    ]
    for b0, b1, notes, fi, fo in pad_layers:
        t0 = bt(b0)
        t1 = bt(b1)
        length = t1 - t0
        n = int(round(length * SR))
        for note, g, pan in notes:
            sig = pad_note(midi_hz(note), n, length, rng, lfo_depth=0.12, width=0.9)
            sig *= cosine_fade(n, fi * bar_len, fo * bar_len)[:, None]
            m.add(t0, sig, gain=g * 0.15, pan=pan, rev=0.5)

    # 侧链呼吸（跟随每拍）
    ph = (t % spb) / spb
    duck_pulse = (1 - np.exp(-ph * 90)) * np.exp(-ph * 5.5)
    duck = 1.0 - 0.32 * duck_pulse

    # 1) 鼓组
    for bar in range(bars):
        sec = 0 if bar < 12 else (1 if bar < 24 else 2)
        # kick
        kicks = [0, 1, 2, 3]
        if sec >= 1:
            kicks += [0.75] if bar % 2 == 0 else [2.75]
        if sec == 2 and bar % 4 in (2, 3):
            kicks += [3.75]
        for b in kicks:
            k = kick(dur=0.5, f0=160, f1=46, click=0.22, rng=rng)
            m.add(bt(bar, b), k, gain=0.21, rev=0.12)

        # snare
        snares = [1, 3]
        if sec >= 1:
            if bar % 4 == 2:
                snares += [2.5]
            if bar % 8 == 7:
                snares += [2.75, 3.25, 3.5]
        for b in snares:
            s = snare(0.3, rng=rng, bright=1.0)
            m.add(bt(bar, b), s, gain=0.21, pan=0.05, rev=0.28)

        # hats
        step = 0.5
        if sec == 2:
            step = 0.25 if bar % 2 == 0 else 0.5
        b = 0.0
        while b < 4:
            acc = 0.75 if (b % 1.0) < 0.01 else 0.5
            h = hat(0.12 if (b % 1.0) < 0.01 else 0.07, rng=rng)
            m.add(bt(bar, b), h, gain=0.11 * acc, pan=0.35 if int(b * 4) % 2 else -0.35,
                  rev=0.18)
            b += step

        # 16 分机械 tick（织机）
        if sec >= 1:
            for i in range(16):
                if i % 2 == 0:
                    continue
                tk = tick(rng=rng, f=2800 if i % 4 else 3600)
                m.add(bt(bar, i * 0.25), tk, gain=0.022,
                      pan=-0.5 if i % 4 == 1 else 0.5, rev=0.25)

        # toms
        if sec == 1 and bar % 4 >= 2:
            pattern = [0.75, 1.5, 2.25, 3.5]
            for i, b in enumerate(pattern):
                if (bar + i) % 3 == 0:
                    continue
                tm = tom(midi_hz(45 - (i % 3) * 2), 0.5, rng=rng)
                m.add(bt(bar, b), tm, gain=0.16, pan=-0.2 + 0.15 * i, rev=0.22)
        if sec == 2:
            for b in (0.75, 2.25):
                tm = tom(midi_hz(43), 0.55, rng=rng)
                m.add(bt(bar, b), tm, gain=0.15, pan=0.2, rev=0.22)

    # 2) 低音 16 分 ostinato
    patterns = [
        [26, 26, 38, 26, 27, 26, 36, 26, 26, 26, 38, 26, 39, 38, 36, 26],
        [26, 26, 38, 26, 27, 26, 36, 26, 29, 26, 38, 34, 33, 31, 29, 26],
        [26, 26, 38, 26, 27, 26, 36, 26, 26, 38, 26, 39, 38, 36, 34, 33],
    ]
    for bar in range(bars):
        sec = 0 if bar < 12 else (1 if bar < 24 else 2)
        pat = patterns[(bar // 4) % 3]
        for i, note in enumerate(pat):
            if sec == 0 and bar < 2 and i % 4 != 0:
                continue  # 前两小节留白，逐步进入
            f = midi_hz(note)
            length = 0.17 if i % 4 == 0 else 0.13
            b = saw_bass(f, length, rng, cutoff=420 if note < 40 else 620)
            m.add(bt(bar, i * 0.25), b, gain=0.25 if i % 4 == 0 else 0.18,
                  pan=0.0, rev=0.05)

    # 3) 主题动机：D 弗里几亚的四音细胞
    phrases = [
        # (start_beat_abs, midi, length_beats, gain)
        (4 * 4 + 0.0, 62, 0.75, 0.11), (4 * 4 + 1.0, 65, 0.75, 0.10),
        (4 * 4 + 2.0, 63, 0.75, 0.10), (4 * 4 + 3.0, 62, 1.5, 0.10),
        (5 * 4 + 0.0, 57, 0.75, 0.09), (5 * 4 + 1.0, 60, 0.75, 0.09),
        (5 * 4 + 2.0, 62, 0.75, 0.10), (5 * 4 + 3.0, 65, 1.0, 0.10),

        (8 * 4 + 0.0, 62, 0.75, 0.11), (8 * 4 + 1.0, 65, 0.75, 0.10),
        (8 * 4 + 2.0, 67, 0.75, 0.10), (8 * 4 + 3.0, 63, 1.25, 0.10),
        (9 * 4 + 0.0, 62, 0.75, 0.10), (9 * 4 + 1.5, 57, 0.75, 0.09),
        (9 * 4 + 2.5, 60, 0.75, 0.09), (9 * 4 + 3.0, 62, 1.25, 0.10),

        (16 * 4 + 0.0, 58, 0.75, 0.10), (16 * 4 + 1.0, 57, 0.75, 0.10),
        (16 * 4 + 2.0, 55, 0.75, 0.10), (16 * 4 + 3.0, 53, 1.0, 0.10),
        (17 * 4 + 0.0, 51, 0.75, 0.09), (17 * 4 + 1.0, 53, 0.75, 0.09),
        (17 * 4 + 2.0, 55, 0.75, 0.09), (17 * 4 + 3.0, 57, 1.0, 0.10),

        (20 * 4 + 0.0, 62, 0.75, 0.11), (20 * 4 + 1.0, 63, 0.75, 0.10),
        (20 * 4 + 2.0, 65, 0.75, 0.10), (20 * 4 + 3.0, 69, 1.0, 0.10),
        (21 * 4 + 0.0, 67, 0.75, 0.10), (21 * 4 + 1.0, 65, 0.75, 0.10),
        (21 * 4 + 2.0, 63, 0.75, 0.10), (21 * 4 + 3.0, 62, 1.5, 0.11),

        (24 * 4 + 0.0, 62, 0.5, 0.12), (24 * 4 + 0.5, 65, 0.5, 0.11),
        (24 * 4 + 1.0, 63, 0.5, 0.11), (24 * 4 + 1.5, 62, 1.0, 0.12),
        (25 * 4 + 0.0, 69, 0.75, 0.10), (25 * 4 + 1.0, 67, 0.75, 0.10),
        (25 * 4 + 2.0, 65, 0.5, 0.10), (25 * 4 + 2.5, 63, 0.5, 0.10),
        (25 * 4 + 3.0, 62, 1.0, 0.11),

        (28 * 4 + 0.0, 74, 0.5, 0.09), (28 * 4 + 0.5, 75, 0.5, 0.09),
        (28 * 4 + 1.0, 77, 0.5, 0.09), (28 * 4 + 1.5, 74, 1.0, 0.10),
        (29 * 4 + 0.0, 70, 0.75, 0.09), (29 * 4 + 1.0, 69, 0.75, 0.09),
        (29 * 4 + 2.0, 67, 0.75, 0.09), (29 * 4 + 3.0, 63, 1.0, 0.10),

        (32 * 4 + 0.0, 62, 0.75, 0.11), (32 * 4 + 1.0, 65, 0.75, 0.10),
        (32 * 4 + 2.0, 63, 0.75, 0.10), (32 * 4 + 3.0, 62, 1.0, 0.10),
    ]
    for abs_beat, note, length_beats, g in phrases:
        ts = abs_beat * spb
        dur_n = max(0.1, length_beats * spb)
        sig = pluck(midi_hz(note), dur_n + 0.5, rng, cutoff=2100, amp=1.0)
        m.add(ts, sig, gain=g * 1.4, pan=-0.15, rev=0.45)
        # 附点八分延迟（0.75 拍），左右交替
        for k, (dly, gg, pn) in enumerate([(0.75, 0.32, 0.35), (1.5, 0.16, -0.4), (2.25, 0.08, 0.45)]):
            m.add(ts + dly * spb, sig, gain=g * 1.4 * gg, pan=pn, rev=0.6)

    # 4) 金属织机点缀
    metal_bars = [4, 8, 12, 16, 20, 24, 28, 32]
    for i, bar in enumerate(metal_bars):
        f = [740, 620, 880, 560, 990, 660, 830, 710][i]
        sig = fm_ping(f, 3.5, rng, ratio=2.76, index=1.6, decay=1.4)
        m.add(bt(bar, 0), sig, gain=0.10, pan=-0.55 if i % 2 else 0.55, rev=0.8)

    # 5) 段落转折：噪声上扬 / 军鼓滚奏
    for bar in (10, 22, 34):
        length = 2 * bar_len
        sweeps = noise_sweep(length, rng, 250, 7000, shape=1.4)
        m.add(bt(bar, 0), sweeps, gain=0.035, pan=0.0, rev=0.6)

    for bar in (10, 22, 34):
        for i in range(8):
            ts = bt(bar, 2.0 + i * 0.25)
            s = snare(0.14, rng=rng, bright=0.55, tone=0.12)
            m.add(ts, s, gain=0.03 + 0.012 * i, pan=0.0, rev=0.2)

    for bar in (10, 22, 34):
        for i, b in enumerate((3.0, 3.25, 3.5, 3.75)):
            tm = tom(midi_hz(50 - i * 2), 0.4, rng=rng)
            m.add(bt(bar, b), tm, gain=0.10, pan=-0.3 + 0.2 * i, rev=0.2)

    # 6) 最后两拍 turnaround：收在低音脉冲，留出干净的循环入口
    for i in range(8):
        ts = bt(35, 2.0 + i * 0.25)
        s = snare(0.12, rng=rng, bright=0.5, tone=0.1)
        m.add(ts, s, gain=0.018 + 0.008 * i, rev=0.2)
    m.add(bt(35, 3.5), tom(midi_hz(38), 0.6, rng=rng), gain=0.12, rev=0.25)

    return finalize(m, bpm, "D Phrygian", "loom_boss", bars,
                    wet_gain=0.30, comp=(-20.0, 4.0, 4.0, 6.0),
                    sat=1.12, ir_bright=0.40)


# ----------------------------------------------------------------------------
# 总线处理 / 导出
# ----------------------------------------------------------------------------

def bus_eq(x, shelf_db=0.0):
    N = x.shape[0]
    freqs = np.fft.rfftfreq(N, 1.0 / SR)
    # 24 Hz 高通 + 15.5 kHz 柔化 + 轻微中低频支撑
    hp = 1.0 / np.sqrt(1.0 + (26.0 / np.maximum(freqs, 1e-6)) ** 4)
    lp = 1.0 / np.sqrt(1.0 + (freqs / 15500.0) ** 4)
    shelf = 1.0 + 0.10 * np.exp(-0.5 * (np.log2(np.maximum(freqs, 1) / 180.0) / 1.1) ** 2)
    g = hp * lp * shelf
    if shelf_db:
        hs = 1.0 + (db_to_lin(shelf_db) - 1.0) * (freqs ** 2) / (freqs ** 2 + 2500.0 ** 2)
        g = g * hs
    y = np.fft.irfft(np.fft.rfft(x, axis=0) * g[:, None], n=N, axis=0)
    return y


def compress(x, threshold_db=-20.0, ratio=3.0, env_ms=35.0, smooth_ms=30.0):
    """循环安全的 RMS 压缩：包络/增益都用 wrap 模式平滑。"""
    p = np.mean(x ** 2, axis=1)
    sigma_e = max(1.0, env_ms * SR / 1000.0 / 2.355)
    env = np.sqrt(gaussian_filter1d(p, sigma_e, mode="wrap"))
    thr = db_to_lin(threshold_db)
    gain = np.ones_like(env)
    m = env > thr
    gain[m] = (env[m] / thr) ** (1.0 / ratio - 1.0)
    sigma_g = max(1.0, smooth_ms * SR / 1000.0 / 2.355)
    gain = gaussian_filter1d(gain, sigma_g, mode="wrap")
    gain = np.minimum(gain, 1.0)
    return x * gain[:, None]


def loudness_peak_limit(x, target_db):
    # 轻度过载保护：只在超过 0 dBFS 时做软削，不改变整体动态
    peak = np.max(np.abs(x))
    if peak > 0.99:
        x = np.tanh(x / peak * 0.99) * 0.99
    peak = np.max(np.abs(x))
    return x * (db_to_lin(target_db) / peak)


def finalize(m, bpm, key, track_id, bars, wet_gain=0.55, comp=None, sat=0.0,
             ir_bright=0.32, shelf_db=0.0):
    rng = RNG_MASTER
    ir_l = make_reverb_ir(5.0, 4.2, rng, bright=ir_bright)
    ir_r = make_reverb_ir(5.0, 4.4, rng, bright=ir_bright * 0.95)
    wet = circular_reverb(m.send, ir_l, ir_r)
    print(f"[{track_id}] seam dry={abs(m.dry[0,0]-m.dry[-1,0]):.6f} "
          f"send={abs(m.send[0,0]-m.send[-1,0]):.6f} "
          f"wet={abs(wet[0,0]-wet[-1,0]):.6f}")
    mix = m.dry + wet * wet_gain
    if comp is not None:
        mix = compress(mix, *comp)
    if sat:
        mix = np.tanh(mix * sat) / np.tanh(sat)
    mix = bus_eq(mix, shelf_db=shelf_db)
    mix = loudness_peak_limit(mix, TARGET_PEAK_DB)

    peak = 20 * np.log10(np.max(np.abs(mix)) + 1e-12)
    rms = 20 * np.log10(np.sqrt(np.mean(mix ** 2)) + 1e-12)
    print(f"[{track_id}] N={m.N} ({m.N/SR:.6f}s) peak={peak:.2f} dBFS rms={rms:.2f} dBFS")
    return mix, dict(bpm=bpm, key=key, bars=bars, duration=m.N / SR, rms_db=rms)


def encode(track, path):
    # libsndfile 在本机一次性写长 OGG 会栈溢出，改为分块流式写入。
    data = track.astype(np.float32)
    with sf.SoundFile(path, "w", samplerate=SR, channels=2,
                      format="OGG", subtype="VORBIS",
                      compression_level=0.4) as f:
        block = SR  # 1 s
        for i in range(0, len(data), block):
            f.write(data[i:i + block])
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("which", choices=["trial", "rift", "loom", "all"])
    args = ap.parse_args()

    jobs = []
    if args.which in ("trial", "all"):
        jobs.append(("trial_ambience", build_trial))
    if args.which in ("rift", "all"):
        jobs.append(("rift_ambience", build_rift))
    if args.which in ("loom", "all"):
        jobs.append(("loom_boss", build_loom))

    for track_id, fn in jobs:
        audio, meta = fn()
        out = os.path.join(ROOT, f"{track_id}.ogg")
        encode(audio, out)
        print(f"wrote {out}  {os.path.getsize(out)/1024:.0f} KiB")


if __name__ == "__main__":
    main()
