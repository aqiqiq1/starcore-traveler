# -*- coding: utf-8 -*-
"""极性换相音第三轮：旧/新对照图（波形 + 频谱图 + 频谱重心轨迹）。

用法（旧版备份先放到临时目录）：
  python plot_polarity_ab.py <old_up.wav> <old_down.wav>
输出：dlc/audio/measurements/polarity_r3_ab.png
"""
import os
import sys
import numpy as np
import soundfile as sf
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.signal import spectrogram

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "measurements")
OUT = os.path.normpath(OUT)

old_up, old_moon = sys.argv[1], sys.argv[2]
ROWS = [
    ("OLD  up (G4->D5)", old_up),
    ("NEW  up (G4->D5, rebuilt)", r"assets\audio\sfx\polarity_switch_v2.wav"),
    ("OLD  down (D5->G4)", old_moon),
    ("NEW  down (D5->G4, rebuilt)", r"assets\audio\sfx\polarity_switch_moon_v2.wav"),
]


def centroid_track(y, sr, win=1024, hop=256):
    ts, cs = [], []
    for i in range(0, len(y) - win, hop):
        seg = y[i:i + win] * np.hanning(win)
        P = np.abs(np.fft.rfft(seg)) ** 2
        f = np.fft.rfftfreq(win, 1 / sr)
        cs.append((P * f).sum() / max(P.sum(), 1e-12))
        ts.append((i + win / 2) / sr)
    return np.array(ts), np.array(cs)


os.makedirs(OUT, exist_ok=True)
fig, axes = plt.subplots(4, 2, figsize=(11, 8.6), gridspec_kw={"width_ratios": [1, 1.35]})
for r, (label, path) in enumerate(ROWS):
    y, sr = sf.read(path)
    t = np.arange(len(y)) / sr
    ax = axes[r, 0]
    ax.plot(t * 1000, y, lw=0.6, color="#1f4e79")
    ax.set_xlim(0, 400)
    ax.set_ylim(-0.62, 0.62)
    ax.set_ylabel("amplitude")
    ax.set_title(f"{label}   peak {20*np.log10(np.max(np.abs(y))):.2f} dBFS  rms {20*np.log10(np.sqrt(np.mean(y**2))):.2f} dBFS",
                 fontsize=8, loc="left")
    ax.tick_params(labelsize=7)
    ax.grid(alpha=0.25, lw=0.4)

    ax2 = axes[r, 1]
    f, tt, S = spectrogram(y, sr, nperseg=512, noverlap=448, scaling="spectrum", mode="magnitude")
    Sdb = 20 * np.log10(S + 1e-9)
    m = f <= 8000
    im = ax2.pcolormesh(tt * 1000, f[m], Sdb[m], shading="auto", cmap="magma", vmin=Sdb.max() - 55, vmax=Sdb.max())
    ts, cs = centroid_track(y, sr)
    ax2.plot(ts * 1000, cs, color="#4fd1c5", lw=1.0)
    ax2.set_ylim(0, 8000)
    ax2.set_xlim(0, 400)
    ax2.set_ylabel("Hz")
    ax2.tick_params(labelsize=7)
    ax2.set_title("spectrogram (0-8 kHz), cyan = spectral centroid", fontsize=8, loc="left")
axes[3, 0].set_xlabel("ms")
axes[3, 1].set_xlabel("ms")
fig.tight_layout()
out = os.path.join(OUT, "polarity_r3_ab.png")
fig.savefig(out, dpi=140)
print("saved", out)
