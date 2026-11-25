#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""检查 DLC 三首 BGM 的格式、峰值、循环缝与频谱平衡。"""
import json
import os
import sys
import numpy as np
import soundfile as sf
from scipy import signal

SR_EXPECT = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRACKS = ["trial_ambience", "rift_ambience", "loom_boss"]


def db(x):
    return 20 * np.log10(max(float(x), 1e-12))


def band_rms(x, lo, hi):
    sos = signal.butter(4, [lo, min(hi, SR_EXPECT / 2 - 100)], "band",
                        fs=SR_EXPECT, output="sos")
    y = signal.sosfilt(sos, x, axis=0)
    return db(np.sqrt(np.mean(y ** 2)))


def main():
    rows = []
    for tid in TRACKS:
        path = os.path.join(ROOT, f"{tid}.ogg")
        x, sr = sf.read(path, always_2d=True)
        n = len(x)
        peak = np.max(np.abs(x))
        ipk = int(np.argmax(np.max(np.abs(x), axis=1)))
        rms = np.sqrt(np.mean(x ** 2))
        crest = db(peak) - db(rms)
        # 循环缝：首尾样本差与相邻样本差分布比较
        d = np.abs(np.diff(x[:, 0]))
        seam = abs(float(x[0, 0]) - float(x[-1, 0]))
        seam_med = float(np.median(d))
        seam_p999 = float(np.percentile(d, 99.9))
        # 边界 30 ms 的能量与整体比较
        n30 = int(0.03 * SR_EXPECT)
        head_rms = np.sqrt(np.mean(x[:n30] ** 2))
        tail_rms = np.sqrt(np.mean(x[-n30:] ** 2))
        # 立体声
        mid = (x[:, 0] + x[:, 1]) / 2
        side = (x[:, 0] - x[:, 1]) / 2
        corr = float(np.corrcoef(x[:, 0], x[:, 1])[0, 1])
        # 真峰值（4x 带限重采样近似，左右声道取最大）
        tp = max(db(np.max(np.abs(signal.resample_poly(x[:, 0], 4, 1)))),
                 db(np.max(np.abs(signal.resample_poly(x[:, 1], 4, 1)))))
        info = {
            "id": tid,
            "file": f"{tid}.ogg",
            "sr": sr,
            "channels": x.shape[1],
            "frames": n,
            "duration": n / sr,
            "peak_db": db(peak),
            "true_peak_db_approx": tp,
            "peak_time": ipk / sr,
            "rms_db": db(rms),
            "crest_db": crest,
            "dc": float(np.mean(x)),
            "seam_absdiff": seam,
            "median_absdiff": seam_med,
            "p999_absdiff": seam_p999,
            "seam_ratio_vs_median": seam / max(seam_med, 1e-9),
            "head30_rms": db(head_rms),
            "tail30_rms": db(tail_rms),
            "bands_db": {
                "sub20_60": band_rms(x, 20, 60),
                "low60_250": band_rms(x, 60, 250),
                "mid250_2k": band_rms(x, 250, 2000),
                "presence2k_8k": band_rms(x, 2000, 8000),
                "air8k_16k": band_rms(x, 8000, 16000),
            },
            "L_R_corr": corr,
            "mid_rms_db": db(np.sqrt(np.mean(mid ** 2))),
            "side_rms_db": db(np.sqrt(np.mean(side ** 2))),
        }
        rows.append(info)
        print(json.dumps(info, ensure_ascii=False, indent=2))
    out = os.path.join(ROOT, "tools", "analysis_report.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
    print("report ->", out)


if __name__ == "__main__":
    main()
