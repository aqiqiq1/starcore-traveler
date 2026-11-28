# -*- coding: utf-8 -*-
"""
极性换相音第三轮：完整测量（可复现）
用法：
  D:/minic/envs/2024212971/python.exe -X utf8 dlc/audio/tools/measure_polarity_r3.py \
      assets/audio/sfx/polarity_switch_v2.wav assets/audio/sfx/polarity_switch_moon_v2.wav
旧版对照可额外传入备份路径。
"""
import sys
import os
import hashlib
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly


def db(v):
    return 20 * np.log10(max(float(v), 1e-12))


def peak_time(y, sr):
    return float(np.argmax(np.abs(y))) / sr


def centroid(seg, sr):
    P = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
    f = np.fft.rfftfreq(len(seg), 1 / sr)
    return float((P * f).sum() / max(P.sum(), 1e-20))


def pitch_at(y, sr, t, win=2048):
    i = int(t * sr)
    if i + win > len(y):
        return float("nan")
    seg = y[i:i + win] * np.hanning(win)
    P = np.abs(np.fft.rfft(seg))
    f = np.fft.rfftfreq(win, 1 / sr)
    m = (f > 150) & (f < 950)
    P, f = P[m], f[m]
    k = int(np.argmax(P))
    if 0 < k < len(P) - 1:                     # 抛物线插值
        a, b, c = np.log(P[k - 1] + 1e-12), np.log(P[k] + 1e-12), np.log(P[k + 1] + 1e-12)
        d = 0.5 * (a - c) / (a - 2 * b + c + 1e-12)
    else:
        d = 0.0
    return float(f[k] + d * (f[1] - f[0]))


def report(path):
    y, sr = sf.read(path)
    if y.ndim > 1:
        y = y[:, 0]
    n = len(y)
    e = y ** 2
    print(f"== {os.path.basename(path)}")
    print(f"frames {n} | dur {n/sr:.4f} s | sr {sr} | ch 1 | "
          f"peak {db(np.max(np.abs(y))):.3f} dBFS @ {peak_time(y, sr)*1000:.2f} ms")
    print(f"true-peak(4x) {db(np.max(np.abs(resample_poly(y, 4, 1)))):.3f} dBFS | "
          f"rms {db(np.sqrt(np.mean(e))):.3f} dBFS | dc {np.mean(y):+.2e}")
    w = int(0.05 * sr)
    r50 = [db(np.sqrt(np.mean(e[i * w:(i + 1) * w]))) for i in range(int(np.ceil(n / w)))]
    print(f"max 50ms rms {max(r50):.2f} dBFS @ {int(np.argmax(r50))*50} ms | "
          f"time-centroid {float((e*np.arange(n)).sum()/e.sum())/sr*1000:.1f} ms")
    print(f"centroid {centroid(y, sr):.0f} Hz | zcr {np.mean(np.abs(np.diff(np.sign(y))) > 0)*sr/2:.0f} Hz")
    P = np.abs(np.fft.rfft(y * np.hanning(n))) ** 2
    f = np.fft.rfftfreq(n, 1 / sr)
    tot = P.sum()
    br = [(lo, hi, P[(f >= lo) & (f < hi)].sum() / tot * 100) for lo, hi in
          [(20, 250), (250, 1000), (1000, 3000), (3000, 8000), (8000, 20000)]]
    print("bands " + "  ".join(f"{lo}-{hi}:{v:.2f}%" for lo, hi, v in br))
    wins = [(0.00, 0.05), (0.05, 0.10), (0.10, 0.15), (0.15, 0.20),
            (0.20, 0.25), (0.25, 0.30), (0.30, 0.35), (0.35, 0.40)]
    print("win-centroid " + "  ".join(f"{a:.2f}-{b:.2f}:{centroid(y[int(a*sr):int(b*sr)], sr):.0f}"
                                      for a, b in wins))
    print("pitch " + "  ".join(f"{t*1000:.0f}ms:{pitch_at(y, sr, t):.0f}"
                               for t in [0.010, 0.030, 0.060, 0.090, 0.120, 0.150, 0.200, 0.300]))
    fr = np.array([np.sqrt(np.mean(e[i:i + int(0.002 * sr)])) for i in range(0, n, int(0.002 * sr))])
    last = np.where(fr > 10 ** (-30 / 20))[0]
    print(f"last 2ms frame > -30 dBFS: {last.max()*2} ms | tail from 300 ms: {(last.max()*2-300)} ms")
    print(f"sha1 {hashlib.sha1(open(path, 'rb').read()).hexdigest()[:12]}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        report(p)
        print()
