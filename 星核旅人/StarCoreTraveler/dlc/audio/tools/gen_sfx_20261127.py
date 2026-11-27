# -*- coding: utf-8 -*-
"""
星核旅人 / DLC — 三条原创 SFX 程序化合成
2026-11-27

产出（44 100 Hz / 单声道 / PCM 16-bit，与 polarity_switch_v2.wav 同格式）：
  assets/audio/sfx/polarity_switch_moon_v2.wav  0.42 s  峰值 -6 dBFS  落相（重做，非倒放）
  assets/audio/sfx/core_insert.wav             0.68 s  峰值 -5 dBFS  星核入仓
  assets/audio/sfx/core_remove.wav             0.52 s  峰值 -6 dBFS  星核出仓

全部波形实时计算：正弦/加性分音、白噪声、包络、双二阶/一阶滤波、时变低通。
无采样、无第三方 IR、无预设、无 AI 生成音频。
"""
import os
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

SR = 44100
SFX_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..",
                       "assets", "audio", "sfx")
SFX_DIR = os.path.normpath(SFX_DIR)

G4 = 392.00
D5 = 587.33


# ---------------------------------------------------------------- 基础工具
def t_axis(dur):
    return np.arange(int(round(dur * SR))) / SR


def osc(freq, phase0=0.0):
    """相位累加，freq 可为标量或逐样点数组。"""
    f = np.asarray(freq, dtype=np.float64)
    if f.ndim == 0:
        f = np.full(len_global, float(f))
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase0)


len_global = 1  # osc 需要知道长度；由调用方在 set_len 后使用


def set_len(n):
    global len_global
    len_global = n


def env_attack(n_atk, shape=1.0):
    x = np.linspace(0, 1, max(n_atk, 1), endpoint=False)
    return (0.5 - 0.5 * np.cos(np.pi * x)) ** shape


def env_exp(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def env_ar(n, atk, tau, shape=1.0):
    """attack + 指数衰减，长度 n 样点。"""
    e = np.zeros(n)
    na = min(int(atk * SR), n)
    e[:na] = env_attack(na, shape)
    e[na:] = np.exp(-np.arange(n - na) / (tau * SR))
    return e


def add_track(buf, start, sig, gain=1.0):
    i = int(round(start * SR))
    j = min(i + len(sig), len(buf))
    if i >= len(buf):
        return
    buf[i:j] += sig[:j - i] * gain


def place(dur, start, sig, gain=1.0):
    """在 dur 长度的总线上放一层，返回该层总线。"""
    b = np.zeros(int(round(dur * SR)))
    add_track(b, start, sig, gain)
    return b


def bp(x, lo, hi, order=4):
    sos = butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], btype="band", output="sos")
    return sosfilt(sos, x)


def hp(x, fc, order=2):
    sos = butter(order, fc / (SR / 2), btype="high", output="sos")
    return sosfilt(sos, x)


def lp(x, fc, order=2):
    sos = butter(order, fc / (SR / 2), btype="low", output="sos")
    return sosfilt(sos, x)


def onepole_lp_tv(x, cutoff):
    """时变一阶低通；cutoff 为逐样点数组（Hz）。"""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1 - a[i]) * x[i] + a[i] * prev
        y[i] = prev
    return y


def fade_tail(x, ms=8.0):
    n = min(int(ms * SR / 1000), len(x))
    x[-n:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n))
    return x


def normalize_peak(x, target_db):
    target = 10 ** (target_db / 20)
    m = np.max(np.abs(x))
    if m > 0:
        x = x * (target / m)
    return x


def write_wav(name, x, target_db):
    x = hp(x, 25, 2)                     # 去直流/超低频
    x = fade_tail(x, 6.0)
    x = normalize_peak(x, target_db)
    x = np.clip(x, -1.0, 1.0)
    path = os.path.join(SFX_DIR, name)
    sf.write(path, x.astype(np.float32), SR, subtype="PCM_16")
    print(f"written {path}  {len(x)} frames  {len(x)/SR:.4f} s  peak {target_db:+.2f} dBFS (pre-quant)")


# ---------------------------------------------------------------- 1. 落相
def make_moon():
    dur = 0.42
    n = int(round(dur * SR))
    set_len(n)
    t = t_axis(dur)
    rng = np.random.default_rng(20261127)

    # 音高：D5 先立住 30 ms，再用 115 ms 按“重力”落到 G4（快起慢收），之后驻留
    fall_start = 0.030
    fall_end = 0.145
    x = np.clip((t - fall_start) / (fall_end - fall_start), 0, 1)
    curve = 1 - (1 - x) ** 2.2          # 一开始掉得快，接近 G4 时减速
    f0 = D5 * (G4 / D5) ** curve

    # 冷玻璃分音：高比例分音衰减极短，只留 0.02–0.09 s
    partials = [
        (1.000, 1.00, 0.200),
        (2.000, 0.32, 0.150),
        (2.756, 0.16, 0.058),
        (4.070, 0.085, 0.036),
        (5.404, 0.050, 0.025),
        (7.400, 0.022, 0.011),
        (8.933, 0.020, 0.015),
    ]
    body = np.zeros(n)
    for ratio, amp, tau in partials:
        det = 1.0 + (0.0018 if ratio > 3 else 0.0)   # 高泛音微去谐，冷金属感
        body += amp * osc(f0 * ratio * det) * env_exp(n, tau)

    # 玻璃槌击：极短带通噪声，随低通一起收，避免变成“另一个游戏”的明亮点击
    nz = rng.standard_normal(n)
    strike = bp(nz, 1200, 5500) * env_ar(n, 0.0025, 0.012)
    body += 0.16 * strike

    # 落位：到达 G4 时一枚闷的接触点（比升相的 2.64/3.95 kHz 交接点更暗）
    settle = np.zeros(n)
    i0 = int(0.142 * SR)
    ns = n - i0
    tt = np.arange(ns) / SR
    for freq, amp, tau in [(1.0 * G4 * 2.02, 0.10, 0.070),
                           (1.0 * G4 * 3.02, 0.055, 0.045),
                           (1.0 * G4 * 1.0, 0.05, 0.10)]:
        settle[i0:] += amp * np.sin(2 * np.pi * freq * tt) * env_ar(ns, 0.004, tau)

    body += settle

    # 手势包络：4 ms 硬起音 → 快速衰减 → 落位小凸起 → 短尾收干
    base = np.zeros(n)
    na = int(0.004 * SR)
    base[:na] = env_attack(na)
    base[na:] = np.exp(-np.arange(n - na) / (0.240 * SR))
    base[i0:] += 0.33 * env_ar(n - i0, 0.006, 0.12)
    # 最后 140 ms 额外收尾，使尾音明显短于升相
    tail = np.ones(n)
    nt = int(0.140 * SR)
    tail[-nt:] = np.exp(-np.arange(nt) / (0.065 * SR))
    body *= base * tail

    # 频谱随音高一起“往下关”：9 kHz → 1.5 kHz，180 ms 内完成
    cut = 1500 + 7500 * np.exp(-t / 0.055)
    body = onepole_lp_tv(body, np.clip(cut, 800, 16000))
    return body


# ---------------------------------------------------------------- 2. 入仓
def make_insert():
    dur = 0.68
    n = int(round(dur * SR))
    set_len(n)
    rng = np.random.default_rng(20261128)

    # A. 金属座落位“咔”——0.000 s
    seat = np.zeros(n)
    # A1 撞击噪声边（2.2–9 kHz，12 ms 衰完）
    nz = rng.standard_normal(n)
    seat += 0.55 * bp(nz, 2200, 9000) * env_ar(n, 0.0012, 0.011)
    # A2 金属座模态：非谐分音，高频先死
    tt = np.arange(n) / SR
    for freq, amp, tau in [(1870, 0.55, 0.050), (2960, 0.40, 0.038),
                           (4230, 0.26, 0.027), (5870, 0.16, 0.018),
                           (7350, 0.09, 0.012)]:
        seat += amp * np.sin(2 * np.pi * freq * tt + 0.3) * env_ar(n, 0.0015, tau)
    # A3 座体闷击：给“重量”，不抢中频
    seat += 0.34 * np.sin(2 * np.pi * 148 * tt) * env_ar(n, 0.003, 0.065)
    seat += 0.12 * np.sin(2 * np.pi * 296 * tt) * env_ar(n, 0.003, 0.045)

    # B. 气密 + 玻璃合拢——0.045–0.21 s
    seal = np.zeros(n)
    b_start = 0.045
    nb = n - int(b_start * SR)
    tb = np.arange(nb) / SR
    nz2 = rng.standard_normal(nb)
    # B1 抽气：带通噪声渐强，0.150 s 处被“合上”切断
    suck = bp(nz2, 420, 2100)
    suck_env = (1 - np.exp(-tb / 0.030)) * np.exp(-tb / 0.20)
    cut_at = 0.150 - b_start
    suck_env[tb > cut_at] = 0.0
    # 2 ms 收口，避免硬切爆音
    k = int(0.002 * SR)
    ki = int(cut_at * SR)
    suck_env[max(0, ki - k):ki] *= np.linspace(1, 0, min(k, ki - max(0, ki - k)))
    seal[int(b_start * SR):] += 0.34 * suck * suck_env

    # B2 玻璃边合拢：2.2/3.3/4.9 kHz，短衰减
    i2 = int(0.146 * SR)
    n2 = n - i2
    t2 = np.arange(n2) / SR
    for freq, amp, tau in [(2210, 0.26, 0.080), (3315, 0.17, 0.055), (4890, 0.10, 0.030)]:
        seal[i2:] += amp * np.sin(2 * np.pi * freq * t2 + 1.1) * env_ar(n2, 0.0015, tau)
    seal[i2:] += 0.22 * bp(rng.standard_normal(n2), 3000, 9000) * env_ar(n2, 0.0010, 0.008)
    # B3 气压回弹：90 Hz 一记很短的“合上”
    seal[i2:] += 0.16 * np.sin(2 * np.pi * 90 * t2) * env_ar(n2, 0.002, 0.045)

    # C. 上行充能——0.16–0.63 s
    charge = np.zeros(n)
    c0 = 0.16
    nc = n - int(c0 * SR)
    tc = np.arange(nc) / SR
    # 音高 196 → 392 Hz，先慢后快（吸气式上行）
    u = np.clip(tc / 0.44, 0, 1)
    fc = 196 * (2.0 ** (u ** 1.6))
    ch_env = np.zeros(nc)
    na = int(0.012 * SR)
    ch_env[:na] = env_attack(na)
    ch_env[na:] = 1 - np.exp(-(tc[na:] - 0.012) / 0.14)
    rel = np.clip((tc - 0.47) / 0.055, 0, 1)
    ch_env *= np.exp(-rel ** 1.5 * 4.0)
    seg = np.zeros(nc)
    for ratio, amp in [(1.0, 0.56), (2.0, 0.20), (3.0, 0.085), (5.0, 0.03)]:
        seg += amp * np.sin(2 * np.pi * np.cumsum(fc * ratio) / SR)
    # 24 Hz 以下的振幅脉动：暖，不刺
    seg *= 0.82 + 0.18 * np.sin(2 * np.pi * 6.0 * tc)
    charge[int(c0 * SR):] += seg * ch_env

    # C2 加速脉冲：8 → 30 Hz，像能量灌进去
    n_p = int(0.44 * SR)
    tp = np.arange(n_p) / SR
    rate = 8 + 22 * (tp / 0.44) ** 1.3
    phase = np.cumsum(rate) / SR
    pulses = (np.mod(phase, 1.0) < 0.16).astype(float)
    pulses = lp(pulses, 2500)
    pulse_sig = pulses * np.sin(2 * np.pi * np.cumsum(fc[:n_p]) / SR)
    charge[int(c0 * SR):int(c0 * SR) + n_p] += 0.19 * pulse_sig * ch_env[:n_p] * 0.9

    # C3 吸气高频微光：1.5k → 6.5k
    sh = rng.standard_normal(nc)
    sh_lo = lp(hp(sh, 900), 2600)
    sh_hi = lp(hp(sh, 3000), 9000)
    mix = np.clip((tc - 0.10) / 0.36, 0, 1) ** 2
    shim = sh_lo * (1 - mix) + sh_hi * mix
    charge[int(c0 * SR):] += 0.068 * shim * ch_env

    # C4 收束：0.600 s 一记短亮边 + 八度泛音，0.68 s 前收干
    i3 = int(0.600 * SR)
    n3 = n - i3
    t3 = np.arange(n3) / SR
    bloom = 0.14 * np.sin(2 * np.pi * 784 * t3) * env_ar(n3, 0.002, 0.045)
    bloom += 0.08 * np.sin(2 * np.pi * 1176 * t3) * env_ar(n3, 0.002, 0.035)
    bloom += 0.05 * bp(rng.standard_normal(n3), 4000, 11000) * env_ar(n3, 0.001, 0.012)
    charge[i3:] += bloom

    mix = seat + seal + charge
    mix = hp(mix, 28, 2)
    return mix


# ---------------------------------------------------------------- 3. 出仓
def make_remove():
    dur = 0.52
    n = int(round(dur * SR))
    set_len(n)
    rng = np.random.default_rng(20261129)
    tt = np.arange(n) / SR

    # A. 气压释放：0.000 s 一记泄压爆音 + 下扫嘶声
    rel = np.zeros(n)
    nz = rng.standard_normal(n)
    rel += 0.62 * bp(nz, 500, 7000) * env_ar(n, 0.0025, 0.048)
    rel += 0.30 * lp(nz, 900) * env_ar(n, 0.003, 0.14)
    rel += 0.16 * bp(rng.standard_normal(n), 2200, 8000) * env_ar(n, 0.0015, 0.055)
    # 嘶声下扫：2.6k→700 Hz，用两段静态噪声交叉淡入
    nh = rng.standard_normal(n)
    low = bp(nh, 380, 1700)
    high = bp(nh, 1800, 6000)
    s = np.clip(tt / 0.16, 0, 1)
    sweep = high * (1 - s) + low * s
    rel += 0.30 * sweep * env_ar(n, 0.004, 0.085)

    # B. 低沉脱离：0.020 s 起 150 → 48 Hz
    det = np.zeros(n)
    i0 = int(0.020 * SR)
    nd = n - i0
    td = np.arange(nd) / SR
    u = np.clip(td / 0.11, 0, 1)
    fd = 150 * (48 / 150) ** (u ** 0.8)
    det[i0:] += 0.55 * np.tanh(1.6 * np.sin(2 * np.pi * np.cumsum(fd) / SR)) * env_ar(nd, 0.003, 0.105)
    det[i0:] += 0.10 * lp(rng.standard_normal(nd), 120) * env_ar(nd, 0.004, 0.14)
    det[i0:] += 0.055 * np.sin(2 * np.pi * 72 * td) * env_ar(nd, 0.004, 0.18)

    # C. 锁扣松开：0.165 s，比入仓更暗更轻（同族不同力）
    tick = np.zeros(n)
    i1 = int(0.165 * SR)
    nt = n - i1
    t1 = np.arange(nt) / SR
    for freq, amp, tau in [(1420, 0.20, 0.028), (2240, 0.13, 0.020), (3410, 0.07, 0.013)]:
        tick[i1:] += amp * np.sin(2 * np.pi * freq * t1) * env_ar(nt, 0.0015, tau)
    tick[i1:] += 0.12 * bp(rng.standard_normal(nt), 1500, 6000) * env_ar(nt, 0.0012, 0.014)

    # D. 短尾：玻璃从 D5 滑落 G4，低通一路关，0.36 s 前收干
    tailvol = np.zeros(n)
    i2 = int(0.190 * SR)
    ntl = n - i2
    ttl = np.arange(ntl) / SR
    uu = np.clip(ttl / 0.11, 0, 1)
    ft = D5 * (G4 / D5) ** (1 - (1 - uu) ** 2.0)
    tone = np.zeros(ntl)
    for ratio, amp, tau in [(1.0, 0.14, 0.11), (2.0, 0.05, 0.07), (2.756, 0.025, 0.035)]:
        tone += amp * np.sin(2 * np.pi * np.cumsum(ft * ratio) / SR) * env_ar(ntl, 0.002, tau)
    cut = 1200 + 5200 * np.exp(-ttl / 0.045)
    tone = onepole_lp_tv(tone, np.clip(cut, 900, 16000))
    tailvol[i2:] += tone

    mix = rel + det + tick + tailvol
    mix = hp(mix, 26, 2)
    # 末端更干：0.40 s 后快速收
    k = int(0.40 * SR)
    mix[k:] *= np.exp(-np.arange(n - k) / (0.032 * SR))
    return mix


if __name__ == "__main__":
    os.makedirs(SFX_DIR, exist_ok=True)
    write_wav("polarity_switch_moon_v2.wav", make_moon(), -6.0)
    write_wav("core_insert.wav", make_insert(), -5.0)
    write_wav("core_remove.wav", make_remove(), -6.0)
