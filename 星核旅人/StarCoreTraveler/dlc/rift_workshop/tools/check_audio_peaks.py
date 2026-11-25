"""Report the actual sample peak and duration of the DLC's five WAV files.

Read-only: it never rewrites a file.  Run after any regeneration:

  D:/minic/envs/2024212971/python.exe dlc/rift_workshop/tools/check_audio_peaks.py

Targets (from gen_assets.py):
  sfx_inversion / sfx_bridge / sfx_wisp_pop / sfx_complete   -3 dBFS
  sfx_wisp_hum                                               -9 dBFS
"""

from __future__ import annotations

import math
import os
import struct
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.join(os.path.dirname(HERE), "assets", "audio")

TARGETS = {
    "sfx_inversion.wav": -3.0,
    "sfx_bridge.wav": -3.0,
    "sfx_wisp_pop.wav": -3.0,
    "sfx_complete.wav": -3.0,
    "sfx_wisp_hum.wav": -9.0,
}

# The hum loop is a 1.000 s forward loop in rift_polarity_wisp.gd; keep it exact.
EXPECTED_SECONDS = {
    "sfx_wisp_hum.wav": 1.0,
}


def peak_db(path: str) -> tuple[float, float, int, int]:
    with wave.open(path, "rb") as handle:
        channels = handle.getnchannels()
        width = handle.getsampwidth()
        rate = handle.getframerate()
        frames = handle.readframes(handle.getnframes())
    if width != 2:
        raise SystemExit(f"{path}: expected 16-bit PCM, got {width * 8}-bit")
    count = len(frames) // 2
    samples = struct.unpack("<%dh" % count, frames[: count * 2])
    top = max(abs(sample) for sample in samples) if samples else 0
    db = 20.0 * math.log10(max(top, 1) / 32767.0)
    seconds = (count // channels) / float(rate)
    return db, seconds, rate, channels


def main() -> int:
    if not os.path.isdir(AUDIO):
        print("missing audio folder:", AUDIO)
        return 1
    failed = 0
    for name in sorted(TARGETS):
        path = os.path.join(AUDIO, name)
        if not os.path.isfile(path):
            print(f"FAIL {name}: missing")
            failed += 1
            continue
        db, seconds, rate, channels = peak_db(path)
        target = TARGETS[name]
        delta = abs(db - target)
        expected = EXPECTED_SECONDS.get(name)
        duration_ok = expected is None or abs(seconds - expected) < 0.0005
        ok = delta <= 0.15 and duration_ok
        if not ok:
            failed += 1
        print(
            f"{'OK  ' if ok else 'FAIL'} {name:22s} "
            f"peak={db:6.2f} dBFS target={target:5.1f} "
            f"delta={delta:4.2f} {seconds:.3f}s {rate}Hz {channels}ch"
        )
    print("AUDIO_PEAK_RESULT", "PASS" if failed == 0 else "FAIL", f"failed={failed}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
