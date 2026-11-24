#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Build the single-file, offline DS03 preview.

All runtime PNGs referenced by runtime_config.json are collected from the
config, not from a hard-coded asset count.  preview.js is embedded unchanged:
it already prefers window.__DS03_ASSET_DATA__ when the table is present.
No server, sibling file, network, XHR or fetch is needed.
"""

from __future__ import annotations

import base64
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT_HTML = ROOT / "双击预览_DS03.html"
PREVIEW_HTML = ROOT / "preview.html"
PREVIEW_JS = ROOT / "preview.js"
CONFIG_JS = ROOT / "config.js"
CONFIG_JSON = ROOT / "runtime_config.json"
CHECKS = ROOT / "checks"


def fail(message: str) -> "NoReturn":
    raise SystemExit("BUILD STANDALONE FAILED: " + message)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_size(data: bytes, label: str) -> tuple[int, int]:
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{label} is not a PNG")
    if data[12:16] != b"IHDR":
        fail(f"{label} has no IHDR")
    return struct.unpack(">II", data[16:24])


def load_config() -> dict:
    text = read_text(CONFIG_JS)
    prefix = "window.DS03_CONFIG = "
    if not text.startswith(prefix):
        fail("config.js does not start with the expected assignment")
    body = text[len(prefix):].strip()
    if not body.endswith(";"):
        fail("config.js does not end with ';'")
    cfg = json.loads(body[:-1])
    disk = json.loads(read_text(CONFIG_JSON))
    if cfg != disk:
        fail("config.js and runtime_config.json disagree")
    return cfg


def collect_assets(cfg: dict) -> tuple[list[str], dict[str, tuple[int, int]]]:
    keys: list[str] = []
    sizes: dict[str, tuple[int, int]] = {}

    def add(item: dict, section: str) -> None:
        key = item.get("file")
        if not isinstance(key, str) or not key:
            fail(f"bad file key in {section}: {key!r}")
        if key in keys:
            fail(f"duplicate runtime asset key: {key}")
        size = item.get("size")
        if not isinstance(size, list) or len(size) != 2:
            fail(f"bad size in {section}: {key}")
        keys.append(key)
        sizes[key] = (int(size[0]), int(size[1]))

    add(cfg["base"], "base")
    for section in ("groups", "static", "sky", "sea", "shadows", "debris"):
        items = cfg.get(section)
        if not isinstance(items, list):
            fail(f"config.{section} is not a list")
        for item in items:
            add(item, section)
    if len(keys) < 20:
        fail(f"runtime references only {len(keys)} assets; expected the full DS03 set")
    return keys, sizes


def main() -> int:
    cfg = load_config()
    keys, sizes = collect_assets(cfg)
    sources = [CONFIG_JS, CONFIG_JSON, PREVIEW_HTML, PREVIEW_JS, Path(__file__).resolve()]
    sources += [ROOT / key for key in keys]
    before = {str(p): sha256(p) for p in sources}

    assets: dict[str, str] = {}
    asset_bytes: dict[str, int] = {}
    asset_hashes: dict[str, str] = {}
    for key in keys:
        path = (ROOT / key).resolve()
        try:
            path.relative_to(ROOT)
        except ValueError:
            fail(f"asset escapes DS03: {key}")
        if not path.is_file():
            fail(f"missing asset: {key}")
        data = path.read_bytes()
        width, height = png_size(data, key)
        expected = sizes[key]
        if (width, height) != expected:
            fail(f"{key} is {width}x{height}, config says {expected}")
        assets[key] = "data:image/png;base64," + base64.b64encode(data).decode("ascii")
        asset_bytes[key] = len(data)
        asset_hashes[key] = hashlib.sha256(data).hexdigest()

    if set(assets) != set(keys):
        fail("embedded asset table does not cover exactly the runtime keys")

    preview_html = read_text(PREVIEW_HTML)
    preview_js = read_text(PREVIEW_JS)
    config_js = read_text(CONFIG_JS)

    if preview_js.count("im.src = embedded ? embedded[key] : key;") != 1:
        fail("preview.js embedded-src branch not found exactly once")
    if "</script" in preview_js.lower() or "</script" in config_js.lower():
        fail("a script contains a literal </script and cannot be inlined safely")

    assets_json = json.dumps(assets, ensure_ascii=False, separators=(",", ":"))
    asset_script = (
        "/* DS03 embedded assets: "
        + str(len(assets))
        + " PNG files as data:image/png;base64. */\n"
        + "window.__DS03_ASSET_DATA__ = Object.freeze("
        + assets_json
        + ");"
    )

    replacement = "\n".join(
        [
            "<!-- Single-file offline build: no server, sibling file, network or XHR. -->",
            "<script>\n" + asset_script + "\n</script>",
            "<script>\n" + config_js.rstrip() + "\n</script>",
            "<script>\n" + preview_js.rstrip() + "\n</script>",
        ]
    )
    pattern = re.compile(
        r'<script src="config\.js"></script>\s*<script src="preview\.js"></script>'
    )
    standalone, count = pattern.subn(lambda _m: replacement, preview_html)
    if count != 1:
        fail("preview.html external script block not found exactly once")

    if re.search(r"<script[^>]*\bsrc\s*=", standalone, re.IGNORECASE):
        fail("generated HTML still contains an external script src")
    if re.search(r"<link\b", standalone, re.IGNORECASE):
        fail("generated HTML contains a link element")
    if re.search(r"\b(?:fetch|XMLHttpRequest)\s*\(", standalone):
        fail("generated HTML contains a network API call")
    if re.search(r"https?://", standalone, re.IGNORECASE):
        fail("generated HTML contains an http(s) URL")
    for needle in ('src="art_assets/', 'src="common/', 'src="config.', 'src="preview.'):
        if needle in standalone:
            fail(f"generated HTML contains a relative resource reference: {needle}")
    if standalone.count("data:image/png;base64,") != len(assets):
        fail("generated data-URI count does not match the asset table")

    marker = "window.__DS03_ASSET_DATA__ = Object.freeze("
    start = standalone.find(marker)
    if start < 0:
        fail("generated HTML has no embedded asset marker")
    start += len(marker)
    end = standalone.find(");", start)
    if end < 0:
        fail("generated asset table is not terminated")
    parsed = json.loads(standalone[start:end])
    if parsed != assets:
        fail("parsed embedded table differs from the built table")
    for key, value in parsed.items():
        raw = base64.b64decode(value.split(",", 1)[1], validate=True)
        if raw[:8] != b"\x89PNG\r\n\x1a\n":
            fail(f"embedded value for {key} is not a PNG")
        if hashlib.sha256(raw).hexdigest() != asset_hashes[key]:
            fail(f"embedded PNG bytes differ from source: {key}")

    # The runtime interactions and parameter surface must survive packaging.
    for token in (
        'params.has("t")',
        'params.get("pause")',
        'params.get("seams")',
        'params.get("ui")',
        'params.get("selftest")',
        'params.get("mode")',
        'params.get("skip")',
        "playBtn.onclick",
        '$("reset").onclick',
        '$("seamBefore").onclick',
        '$("seamAfter").onclick',
        '$("seamMark").onclick',
        '$("skyWrap").onclick',
        '$("bridgeUp").onclick',
        '$("bridgeDown").onclick',
        '$("bridgeJoint").onclick',
        '$("islandGap").onclick',
        '$("g3g1Gap").onclick',
        '$("cloudToggle").onclick',
        '$("hideUI").onclick',
    ):
        if token not in standalone:
            fail(f"interaction/API token missing from generated HTML: {token}")

    CHECKS.mkdir(parents=True, exist_ok=True)
    temp = OUT_HTML.with_name(OUT_HTML.name + ".tmp")
    temp.write_bytes(standalone.encode("utf-8"))
    temp.replace(OUT_HTML)

    after = {str(p): sha256(p) for p in sources}
    if before != after:
        changed = [p for p in before if before[p] != after.get(p)]
        fail("source files changed during packaging: " + ", ".join(changed))

    report = {
        "ok": True,
        "output": OUT_HTML.name,
        "bytes": OUT_HTML.stat().st_size,
        "asset_count": len(assets),
        "asset_keys": keys,
        "asset_bytes": asset_bytes,
        "asset_hashes": asset_hashes,
        "embedded_count": len(parsed),
        "embedded_base64_png_verified": True,
        "source_files_unchanged": True,
        "no_external_script_or_link": True,
        "no_http_or_fetch": True,
    }
    (CHECKS / "standalone_build_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"OK  {OUT_HTML}")
    print(f"bytes {OUT_HTML.stat().st_size}")
    print(f"assets {len(assets)} (collected from runtime config)")
    for key in keys:
        print(f"  {key}  png={asset_bytes[key]}B")
    print("embedded base64 -> PNG hashes verified; sources unchanged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
