# -*- coding: utf-8 -*-
"""Small Chrome DevTools Protocol helper for DS03 browser checks.

Uses the installed Chrome in headless mode with a throw-away profile.  It is a
test helper only; the delivered preview never needs a server or this module.
"""

from __future__ import annotations

import json
import shutil
import socket
import subprocess
import tempfile
import time
from pathlib import Path

import requests
import websocket

CHROME = Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe")
TEMP_ROOT = Path(r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode")


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


class ChromeSession:
    def __init__(self, viewport=(1280, 720)):
        self.viewport = viewport
        self.proc = None
        self.ws = None
        self.msg_id = 0
        self.profile = None

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, exc_type, exc, tb):
        self.stop()

    def start(self):
        if not CHROME.is_file():
            raise RuntimeError(f"Chrome not found: {CHROME}")
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        self.profile = Path(tempfile.mkdtemp(prefix="ds03_chrome_", dir=str(TEMP_ROOT)))
        self.port = free_port()
        args = [
            str(CHROME),
            "--headless=new",
            "--disable-gpu",
            "--disable-extensions",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            f"--remote-debugging-port={self.port}",
            "--remote-allow-origins=*",
            f"--user-data-dir={self.profile}",
            "--no-first-run",
            "--no-default-browser-check",
            "about:blank",
        ]
        self.proc = subprocess.Popen(
            args,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        version = None
        deadline = time.time() + 20
        while time.time() < deadline:
            try:
                version = requests.get(
                    f"http://127.0.0.1:{self.port}/json/version", timeout=1
                ).json()
                break
            except Exception:
                if self.proc.poll() is not None:
                    break
                time.sleep(0.1)
        if not version:
            self.stop()
            raise RuntimeError("Chrome remote debugging did not start")
        self.version = version
        tabs = requests.get(f"http://127.0.0.1:{self.port}/json/list", timeout=2).json()
        tab = next(
            (t for t in tabs if t.get("type") == "page" and t.get("url") == "about:blank"),
            None,
        )
        if tab is None:
            tab = next((t for t in tabs if t.get("type") == "page"), None)
        if tab is None:
            raise RuntimeError("No Chrome page target")
        self.ws = websocket.create_connection(
            tab["webSocketDebuggerUrl"], timeout=30, suppress_origin=True
        )
        self.cmd("Page.enable")
        self.cmd("Runtime.enable")
        self.cmd(
            "Emulation.setDeviceMetricsOverride",
            {
                "width": self.viewport[0],
                "height": self.viewport[1],
                "deviceScaleFactor": 1,
                "mobile": False,
            },
        )

    def stop(self):
        if self.ws is not None:
            try:
                self.ws.close()
            except Exception:
                pass
            self.ws = None
        if self.proc is not None:
            try:
                self.proc.terminate()
                self.proc.wait(timeout=8)
            except Exception:
                try:
                    self.proc.kill()
                except Exception:
                    pass
            self.proc = None
        if self.profile is not None:
            shutil.rmtree(self.profile, ignore_errors=True)
            self.profile = None

    def cmd(self, method: str, params: dict | None = None, timeout: float = 30):
        if self.ws is None:
            raise RuntimeError("Chrome session is not started")
        self.msg_id += 1
        msg_id = self.msg_id
        self.ws.send(json.dumps({"id": msg_id, "method": method, "params": params or {}}))
        self.ws.settimeout(timeout)
        while True:
            raw = self.ws.recv()
            if not raw:
                raise RuntimeError(f"CDP socket closed while waiting for {method}")
            message = json.loads(raw)
            if message.get("id") == msg_id:
                if "error" in message:
                    raise RuntimeError(f"CDP {method} failed: {message['error']}")
                return message.get("result", {})

    def eval(self, expression: str, await_promise: bool = False):
        result = self.cmd(
            "Runtime.evaluate",
            {
                "expression": expression,
                "returnByValue": True,
                "awaitPromise": await_promise,
                "userGesture": True,
            },
            timeout=45,
        )
        value = result.get("result", {})
        if value.get("subtype") == "error":
            raise RuntimeError(f"JS error: {value.get('description')}")
        return value.get("value")

    def navigate(self, url: str, wait_ready: bool = True):
        self.cmd("Page.navigate", {"url": url})
        if not wait_ready:
            return
        self.wait_ready()
        self.eval(
            "new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(()=>r(true))))",
            await_promise=True,
        )

    def wait_ready(self, timeout_ms: int = 12000):
        expr = """
        new Promise(res => {
          const t0 = performance.now();
          const tick = () => {
            if (window.DS03) {
              window.DS03.ready.then(() => res("ready"));
              return;
            }
            if (performance.now() - t0 > %d) { res("timeout"); return; }
            setTimeout(tick, 20);
          };
          tick();
        })
        """ % timeout_ms
        result = self.eval(expr, await_promise=True)
        if result != "ready":
            state = self.eval("({url:location.href,title:document.title,body:document.body.innerText.slice(0,500)})")
            raise RuntimeError(f"DS03 did not become ready: {result} {state}")

    def screenshot(self, path: Path | None = None) -> bytes:
        result = self.cmd("Page.captureScreenshot", {"format": "png", "fromSurface": True})
        data = __import__("base64").b64decode(result["data"])
        if path is not None:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        return data

    def run_selftest(self, timeout_ms: int = 12000) -> dict:
        expr = """
        new Promise(res => {
          const t0 = performance.now();
          const tick = () => {
            const els = [...document.querySelectorAll("#selftest")];
            const el = els[els.length - 1];
            if (el && el.textContent.trim()) { res(el.textContent); return; }
            if (performance.now() - t0 > %d) { res(""); return; }
            setTimeout(tick, 50);
          };
          tick();
        })
        """ % timeout_ms
        text = self.eval(expr, await_promise=True)
        if not text:
            raise RuntimeError("selftest did not produce output")
        return json.loads(text)
