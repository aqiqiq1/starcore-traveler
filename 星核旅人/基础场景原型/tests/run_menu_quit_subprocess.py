"""Verify that the start-menu 退出游戏 entry really ends its own game process.

Two isolated child processes are launched with the project Godot executable:
  * mouse activation, headless
  * keyboard Down/Down/Enter activation, one real GUI window
Each child writes a ready marker before input and must exit with code 0 on its
own.  On failure the child's watchdog self-quits non-zero; this runner only
terminates the exact Popen handle it created, never a process selected by name
or command line.

Run:
  D:\\minic\\envs\\2024212971\\python.exe tests\\run_menu_quit_subprocess.py
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path(r"D:\Godot\Godot_v4.7.2-stable_win64_console.exe")
LOGS = PROJECT / "tests" / "logs"

READY_TIMEOUT = 30.0
EXIT_TIMEOUT = 30.0


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return ""


def run_case(mode: str, gui: bool, stamp: str) -> dict:
    label = f"{mode}_{'gui' if gui else 'headless'}"
    ready = LOGS / f"menu_quit_ready_{label}_{stamp}.txt"
    failure = LOGS / f"menu_quit_failure_{label}_{stamp}.txt"
    log_path = LOGS / f"menu_quit_subprocess_{label}.log"
    for stale in (ready, failure):
        if stale.is_file():
            stale.unlink()

    args = [str(GODOT)]
    if not gui:
        args.append("--headless")
    args += [
        "--path", str(PROJECT),
        "res://tests/menu_quit_subprocess.tscn",
        "--",
        f"--mode={mode}",
        f"--ready={ready}",
        f"--failure={failure}",
    ]
    creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0) if gui else 0
    result: dict = {
        "case": label,
        "mode": mode,
        "gui": gui,
        "command": args,
        "ready_file": str(ready),
        "failure_file": str(failure),
        "log": str(log_path),
        "pass": False,
        "pid": None,
        "game_pid": None,
        "returncode": None,
        "ready_text": "",
        "failure_text": "",
        "error": "",
    }
    print(f"== menu quit subprocess: {label} ==")
    print(" ".join(f'"{a}"' if " " in a else a for a in args))
    with log_path.open("wb") as log_file:
        proc = subprocess.Popen(
            args,
            cwd=str(PROJECT),
            stdout=log_file,
            stderr=subprocess.STDOUT,
            creationflags=creationflags,
        )
        result["pid"] = proc.pid
        print(f"launched pid={proc.pid}")
        try:
            deadline = time.time() + READY_TIMEOUT
            while time.time() < deadline:
                if ready.is_file():
                    break
                if proc.poll() is not None:
                    break
                time.sleep(0.05)
            result["ready_text"] = read_text(ready)
            pid_match = re.search(r"\bpid=(\d+)\b", result["ready_text"])
            if pid_match:
                result["game_pid"] = int(pid_match.group(1))
            if not result["ready_text"].startswith("READY"):
                result["error"] = (
                    f"no READY marker before input "
                    f"(returncode={proc.poll()}, log={log_path})"
                )
                return result

            print(f"ready: {result['ready_text']}")
            try:
                result["returncode"] = proc.wait(timeout=EXIT_TIMEOUT)
            except subprocess.TimeoutExpired:
                # Last resort only: terminate the exact child this runner
                # started.  The in-game watchdog normally quits by itself.
                print(f"timeout; terminating only pid={proc.pid}")
                proc.terminate()
                try:
                    result["returncode"] = proc.wait(timeout=5.0)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    result["returncode"] = proc.wait(timeout=5.0)
                result["error"] = "process did not exit within the watchdog window"
        finally:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=5.0)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5.0)

    result["failure_text"] = read_text(failure)
    ok = (
        result["ready_text"].startswith("READY")
        and result["returncode"] == 0
        and not result["failure_text"]
        and not result["error"]
    )
    result["pass"] = ok
    print(
        f"launcher_pid={result['pid']} game_pid={result['game_pid']} "
        f"returncode={result['returncode']} pass={ok} "
        f"failure={result['failure_text']!r}"
    )
    return result


def main() -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    if not GODOT.is_file():
        raise SystemExit(f"Godot executable not found: {GODOT}")
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report = {
        "generated": datetime.now().isoformat(timespec="seconds"),
        "godot": str(GODOT),
        "watchdog_seconds": 12.0,
        "cases": [],
    }
    # One headless mouse quit and one independent GUI keyboard quit.
    cases = [("mouse", False), ("keyboard", True)]
    all_ok = True
    for mode, gui in cases:
        result = run_case(mode, gui, stamp)
        report["cases"].append(result)
        all_ok = all_ok and result["pass"]

    report["pass"] = all_ok
    out = LOGS / f"menu_quit_subprocess_{stamp}.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {out}")
    print("RESULT:", "PASS" if all_ok else "FAIL")
    raise SystemExit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
