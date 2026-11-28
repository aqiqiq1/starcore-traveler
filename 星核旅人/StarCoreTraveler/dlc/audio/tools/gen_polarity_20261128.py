# -*- coding: utf-8 -*-
"""
星核旅人 / DLC — 极性换相音 第三轮重做（2026-11-28）

产出（44 100 Hz / 单声道 / PCM 16-bit，与项目其他 SFX 同格式）：
  assets/audio/sfx/polarity_switch_v2.wav       0.40 s  峰值 -6 dBFS  升相（点亮）
  assets/audio/sfx/polarity_switch_moon_v2.wav  0.40 s  峰值 -6 dBFS  落相（熄灭，非倒放）

设计要点
--------
升相：G4 上敲响 → 基音衰减的同时，非谐泛音在 30–150 ms 内逐级点亮并滑到 D5，
      到点后 0.13–0.22 s 保持“亮”，0.30 s 起用 45 ms 时间常数收干（尾巴 0.1 s 内）。
落相：D5 起手最亮 → 110 ms 内按重力曲线落到 G4，高频泛音在 0.19 s 被“关灯”（20 ms 软关），
      只留 1、2 次分音与低八度垫底，2 次一阶低通把整体压暗；低声部自然延续到 0.34 s 再收。
      两条共用同一组非谐比例（1 / 2 / 2.756 / 4.07 / 5.404 / 7.4 / 8.933），所以同族。

全部波形实时计算：正弦/加性分音、包络、时变一阶低通、白噪声。
无采样、无第三方 IR、无预设、无 AI 生成音频。
"""
import os
import numpy as np
import soundfile as sf

SR = 44100
SFX_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                        "..", "..", "..", "assets", "audio", "sfx"))

G4 = 392.00
D5 = 587.33

# 同族非谐比例（玻璃/钟体）
FAMILY = [1.000, 2.000, 2.756, 4.070, 5.404, 7.400, 8.933]


def smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def attack_env(n, atk_s):
    e = np.ones(n)
    na = max(int(round(atk_s * SR)), 1)
    na = min(na, n)
    e[:na] = 0.5 - 0.5 * np.cos(np.pi * np.arange(na) / na)
    return e


def additive(f0, n, specs, atk=0.0035):
    """f0: 标量或逐样点数组（Hz）。specs: [(ratio, a0, a1, rise, d0, tau, det)]"""
    t = np.arange(n) / SR
    ae = attack_env(n, atk)
    out = np.zeros(n)
    for ratio, a0, a1, rise, d0, tau, det in specs:
        if rise is None:
            lvl = np.full(n, a0)
        else:
            r0, r1 = rise
            lvl = a0 + (a1 - a0) * smoothstep((t - r0) / max(r1 - r0, 1e-6))
        dec = np.exp(-np.clip(t - d0, 0.0, None) / tau)
        amp = ae * lvl * dec
        out += amp * np.sin(2 * np.pi * np.cumsum(f0 * ratio * det) / SR)
    return out


def onepole_lp_tv(x, cutoff):
    """时变一阶低通；cutoff 逐样点。"""
    a = np.exp(-2 * np.pi * np.clip(cutoff, 20.0, SR * 0.45) / SR)
    y = np.empty_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1.0 - a[i]) * x[i] + a[i] * prev
        y[i] = prev
    return y


def normalize(x, target_db):
    m = np.max(np.abs(x))
    if m > 0:
        x = x * (10 ** (target_db / 20) / m)
    return x


def finish(x, target_db=-6.0, fade_ms=12.0):
    x = x - np.mean(x)                      # 去直流
    nf = int(fade_ms * SR / 1000)
    x[-nf:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, nf))
    x = normalize(x, target_db)
    return np.clip(x, -1.0, 1.0)


def write(name, x):
    path = os.path.join(SFX_DIR, name)
    sf.write(path, x.astype(np.float32), SR, subtype="PCM_16")
    print(f"written {name}  {len(x)} frames  {len(x)/SR:.4f} s  peak {20*np.log10(np.max(np.abs(x))):.2f} dBFS (pre-quant)")


# ------------------------------------------------------------------ 升相
def make_up():
    dur = 0.40
    n = int(round(dur * SR))
    t = np.arange(n) / SR

    # G4 驻留 30 ms，再用 100 ms 的 S 曲线滑到 D5（0.130 s 到点）
    u = smoothstep((t - 0.030) / 0.100)
    f0 = G4 * (D5 / G4) ** u

    # 基音先立后让位；泛音在滑行中逐级点亮。衰减慢，让“亮”撑到 0.30 s 再收。
    specs = [
        (1.000, 0.95, 0.72, (0.020, 0.120), 0.010, 0.400, 1.0000),
        (2.000, 0.40, 0.50, (0.020, 0.120), 0.015, 0.420, 1.0004),
        (2.756, 0.12, 0.30, (0.030, 0.130), 0.025, 0.360, 1.0012),
        (4.070, 0.04, 0.19, (0.040, 0.140), 0.035, 0.220, 1.0018),
        (5.404, 0.025, 0.100, (0.050, 0.150), 0.045, 0.150, 1.0024),
        (7.400, 0.010, 0.045, (0.060, 0.160), 0.055, 0.100, 1.0030),
        (8.933, 0.006, 0.024, (0.070, 0.170), 0.065, 0.075, 1.0036),
    ]
    body = additive(f0, n, specs)

    # 75 ms 处轻微“换气”：基音让一下，泛音接着点亮——起音因此仍站得住
    body *= 1.0 - 0.22 * np.exp(-0.5 * ((t - 0.075) / 0.030) ** 2)

    # 槌头：两个非谐高点，5–15 ms 衰完，给“敲击”一个起点（无宽带噪声）
    chiff = additive(f0, n, [
        (6.190, 0.040, 0.040, None, 0.000, 0.016, 1.000),
        (9.140, 0.020, 0.020, None, 0.000, 0.010, 1.000),
    ], atk=0.0025)
    body += chiff

    # 微光：11.8 / 14.6 倍的分音，0.08–0.16 s 才出现，给“点亮”一层空气感
    shimmer = additive(f0, n, [
        (11.830, 0.000, 0.016, (0.080, 0.160), 0.155, 0.055, 1.000),
        (14.600, 0.000, 0.010, (0.095, 0.170), 0.170, 0.045, 1.000),
    ], atk=0.012)
    body += shimmer

    # 亮度自动化：起手 3 kHz → 0.13 s 打开到 14 kHz → 0.22 s 保持 → 收尾关到 4 kHz
    cut = np.interp(t, [0.0, 0.13, 0.22, 0.30, 0.40], [3000, 14000, 14000, 9000, 4000])
    body = onepole_lp_tv(body, cut)

    # 尾巴：0.30 s 起 45 ms 时间常数收干（最后 0.1 s 内），不是混响
    g = np.ones(n)
    k = int(0.30 * SR)
    g[k:] = np.exp(-np.arange(n - k) / (0.045 * SR))
    body *= g

    return finish(body, -6.0)


# ------------------------------------------------------------------ 落相
def make_down():
    dur = 0.40
    n = int(round(dur * SR))
    t = np.arange(n) / SR

    # D5 驻留 22 ms，再用 125 ms 落到 G4：一开始掉得快，接近地面减速
    x = np.clip((t - 0.022) / 0.125, 0.0, 1.0)
    curve = 1.0 - (1.0 - x) ** 2.2
    f0 = D5 * (G4 / D5) ** curve

    # 高频泛音短命：落到 G4（0.147 s）时把它们关掉，像灯灭
    hi = additive(f0, n, [
        (2.756, 0.200, 0.200, None, 0.002, 0.110, 1.0014),
        (4.070, 0.090, 0.090, None, 0.002, 0.070, 1.0020),
        (5.404, 0.040, 0.040, None, 0.002, 0.040, 1.0026),
        (7.400, 0.018, 0.018, None, 0.002, 0.025, 1.0030),
        (8.933, 0.010, 0.010, None, 0.002, 0.015, 1.0036),
    ], atk=0.0018)
    # “关灯”：0.148 s（落点）起 18 ms 软关高频，高频先灭、低频继续
    gate = np.ones(n)
    g0, gf = int(0.148 * SR), int(0.018 * SR)
    gate[g0:g0 + gf] = np.cos(np.linspace(0, np.pi / 2, gf)) ** 2
    gate[g0 + gf:] = 0.0
    hi *= gate

    # 低频主体：基音 + 2 次分音 + 低八度，衰减慢，负责“沉下去”的重量
    lo = additive(f0, n, [
        (1.000, 1.00, 0.92, None, 0.003, 0.340, 1.0000),
        (2.000, 0.34, 0.32, None, 0.004, 0.250, 1.0003),
        (3.000, 0.060, 0.060, None, 0.004, 0.180, 1.0006),
    ])
    sub = additive(f0 * 0.5, n, [
        (1.000, 0.25, 0.25, None, 0.004, 0.400, 1.0000),
    ])

    body = hi + lo + sub

    # 两次一阶低通 ≈ 12 dB/oct：8 kHz 起手 → 0.12 s 3 kHz → 0.40 s 1.3 kHz
    cut = np.interp(t, [0.0, 0.12, 0.24, 0.40], [8000, 3000, 1800, 1300])
    body = onepole_lp_tv(onepole_lp_tv(body, cut), cut)

    # 尾部：0.34 s 起 30 ms 收干，最后 60 ms 到真静音
    g = np.ones(n)
    k = int(0.34 * SR)
    g[k:] = np.exp(-np.arange(n - k) / (0.030 * SR))
    body *= g

    return finish(body, -6.0)


if __name__ == "__main__":
    os.makedirs(SFX_DIR, exist_ok=True)
    write("polarity_switch_v2.wav", make_up())
    write("polarity_switch_moon_v2.wav", make_down())
