#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Convenience reproduction wrapper for DS03.

Run with:
  D:\\minic\\envs\\2024212971\\python.exe reproduce.py

The browser step uses the installed Chrome headless with a throw-away profile
and a temporary localhost server only for the split/standalone comparison.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-browser", action="store_true", help="only rebuild config/assets/standalone")
    args = ap.parse_args()
    steps = ["build_runtime.py", "build_standalone.py"]
    if not args.skip_browser:
        steps += ["capture_checks.py"]
    steps += ["verify_hashes.py"]
    for name in steps:
        print(">>", name)
        subprocess.run([sys.executable, str(ROOT / name)], cwd=str(ROOT), check=True)
    print("DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
