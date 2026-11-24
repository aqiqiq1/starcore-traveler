#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Build a single-file, offline DS02 preview.

The generated HTML inlines the existing CSS, config.js, preview.js and every PNG
referenced by the runtime. Image loading in the embedded preview.js is redirected
to a data:image/png;base64 table. No server, sibling file, network, npm or XHR is
required. Source files are never modified.
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
OUT_HTML = ROOT / "双击预览_DS02.html"
PREVIEW_HTML = ROOT / "preview.html"
PREVIEW_JS = ROOT / "preview.js"
CONFIG_JS = ROOT / "config.js"
CONFIG_JSON = ROOT / "config.json"
GENERATOR = ROOT / "generate_ds02.py"

EXPECTED_ASSET_COUNT = 19
IMAGE_NEEDLE = "    im.src = src;"
IMAGE_REPLACEMENT = "    im.src = window.__DS02_ASSET_DATA[src];"


def fail(message: str) -> "NoReturn":
    raise SystemExit("BUILD FAILED: " + message)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        fail(f"{path.name} is not UTF-8: {exc}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_size(data: bytes, label: str) -> tuple[int, int]:
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{label} is not a PNG")
    if data[12:16] != b"IHDR":
        fail(f"{label} has no IHDR at the expected offset")
    return struct.unpack(">II", data[16:24])


def load_config() -> dict:
    text = read_text(CONFIG_JS)
    prefix = "window.DS02_CONFIG = "
    if not text.startswith(prefix):
        fail("config.js does not start with the expected assignment")
    body = text[len(prefix):].strip()
    if not body.endswith(";"):
        fail("config.js does not end with ';'")
    try:
        cfg = json.loads(body[:-1].strip())
    except json.JSONDecodeError as exc:
        fail(f"config.js payload is not valid JSON: {exc}")
    if not isinstance(cfg, dict):
        fail("config.js payload is not an object")
    try:
        cfg_json = json.loads(read_text(CONFIG_JSON))
    except json.JSONDecodeError as exc:
        fail(f"config.json is not valid JSON: {exc}")
    if cfg != cfg_json:
        fail("config.js and config.json disagree; refusing to bake the wrong view")
    return cfg


def collect_asset_keys(cfg: dict) -> list[str]:
    """Collect keys exactly like preview.js builds its srcs set (insertion order)."""
    keys: list[str] = []

    def add(key: object) -> None:
        if not isinstance(key, str) or not key:
            fail(f"invalid asset path in config: {key!r}")
        if key not in keys:
            keys.append(key)

    add("layers/base_static.png")
    add(cfg["arch_overlay"])
    add(cfg["island_overlay"])
    for section in ("sky", "sea", "debris", "shadows"):
        items = cfg.get(section)
        if not isinstance(items, list):
            fail(f"config.{section} is not a list")
        for item in items:
            add(item["file"])
    return keys


def expected_sizes(cfg: dict) -> dict[str, tuple[int, int]]:
    canvas = tuple(cfg["canvas"])
    if len(canvas) != 2:
        fail("config.canvas must have two values")
    result = {
        "layers/base_static.png": canvas,
        cfg["arch_overlay"]: canvas,
        cfg["island_overlay"]: canvas,
    }
    for section in ("sky", "sea", "debris", "shadows"):
        for item in cfg[section]:
            size = tuple(item["size"])
            if len(size) != 2:
                fail(f"config.{section}.{item['name']}.size must have two values")
            result[item["file"]] = size
    return result


def inline_script(label: str, source: str) -> str:
    if re.search(r"</script", source, re.IGNORECASE):
        fail(f"{label} contains a literal </script and cannot be inlined safely")
    return f"<script>\n{source.rstrip()}\n</script>"


def main() -> int:
    cfg = load_config()
    keys = collect_asset_keys(cfg)
    sizes = expected_sizes(cfg)

    if len(keys) != EXPECTED_ASSET_COUNT:
        fail(f"runtime references {len(keys)} assets, expected {EXPECTED_ASSET_COUNT}")
    actual_layer_pngs = {f"layers/{p.name}" for p in (ROOT / "layers").glob("*.png")}
    if set(keys) != actual_layer_pngs:
        missing = sorted(actual_layer_pngs - set(keys))
        extra = sorted(set(keys) - actual_layer_pngs)
        fail(f"runtime keys and layers/*.png differ; unreferenced={missing}, missing={extra}")

    protected_paths = [CONFIG_JS, CONFIG_JSON, PREVIEW_HTML, PREVIEW_JS, GENERATOR]
    protected_paths += [ROOT / key for key in keys]
    before_hashes = {str(path): sha256(path) for path in protected_paths}

    assets: dict[str, str] = {}
    asset_lengths: dict[str, int] = {}
    for key in keys:
        path = (ROOT / key).resolve()
        try:
            path.relative_to(ROOT)
        except ValueError:
            fail(f"asset escapes the DS02 directory: {key}")
        if not path.is_file():
            fail(f"missing asset: {key}")
        data = path.read_bytes()
        width, height = png_size(data, key)
        expected = sizes.get(key)
        if expected is not None and (width, height) != expected:
            fail(f"{key} is {width}x{height}, config says {expected[0]}x{expected[1]}")
        assets[key] = "data:image/png;base64," + base64.b64encode(data).decode("ascii")
        asset_lengths[key] = len(data)

    if set(assets) != set(keys) or len(assets) != EXPECTED_ASSET_COUNT:
        fail("embedded asset table does not exactly cover the runtime keys")

    preview_html = read_text(PREVIEW_HTML)
    preview_js = read_text(PREVIEW_JS)
    config_js = read_text(CONFIG_JS)

    if preview_js.count(IMAGE_NEEDLE) != 1:
        fail(f"preview.js must contain exactly one '{IMAGE_NEEDLE.strip()}' line")
    preview_js_embedded = preview_js.replace(IMAGE_NEEDLE, IMAGE_REPLACEMENT)
    preview_js_embedded = (
        "/* DS02 standalone build: only the image src assignment is redirected to\n"
        "   the embedded data-URI table; all drawing, timing and URL params below\n"
        "   are the reviewed preview.js logic unchanged. */\n"
        + preview_js_embedded
    )
    if IMAGE_NEEDLE in preview_js_embedded or "im.src = window.__DS02_ASSET_DATA[src];" not in preview_js_embedded:
        fail("image source redirection did not apply")

    assets_json = json.dumps(assets, ensure_ascii=False, separators=(",", ":"))
    asset_script = (
        "/* DS02 embedded assets: "
        + str(len(assets))
        + " PNG files as data:image/png;base64. */\n"
        + "window.__DS02_ASSET_DATA = Object.freeze("
        + assets_json
        + ");"
    )

    replacement = "\n".join(
        [
            "<!-- Single-file offline build: no server, no sibling JS/PNG, no network. -->",
            inline_script("embedded asset table", asset_script),
            inline_script("config.js", config_js),
            inline_script("preview.js (redirected image src)", preview_js_embedded),
        ]
    )

    script_pattern = re.compile(
        r'<script src="config\.js"></script>\s*<script src="preview\.js"></script>'
    )
    standalone, replacements = script_pattern.subn(lambda _match: replacement, preview_html)
    if replacements != 1:
        fail("preview.html external script block not found exactly once")

    if re.search(r"<script[^>]*\bsrc\s*=", standalone, re.IGNORECASE):
        fail("generated HTML still contains an external script src")
    if re.search(r"<link\b", standalone, re.IGNORECASE):
        fail("generated HTML contains a link element")
    if re.search(r"\b(?:fetch|XMLHttpRequest)\s*\(", standalone):
        fail("generated HTML contains a runtime network API call")
    if re.search(r"https?://", standalone, re.IGNORECASE):
        fail("generated HTML contains an http(s) URL")
    for pattern in ('src="layers/', "src='layers/", 'src="config.', 'src="preview.'):
        if pattern in standalone:
            fail(f"generated HTML contains a relative resource reference: {pattern}")
    if standalone.count("data:image/png;base64,") != len(assets):
        fail("generated HTML data-URI count does not match the asset table")

    marker = "window.__DS02_ASSET_DATA = Object.freeze("
    start = standalone.find(marker)
    if start < 0:
        fail("generated HTML has no embedded asset marker")
    start += len(marker)
    end = standalone.find(");", start)
    if end < 0:
        fail("generated HTML asset table is not terminated")
    try:
        parsed_assets = json.loads(standalone[start:end])
    except json.JSONDecodeError as exc:
        fail(f"generated asset table cannot be parsed back: {exc}")
    if parsed_assets != assets:
        fail("generated asset table differs from the built table")

    for token in (
        'params.has("t")',
        'params.get("pause")',
        'params.get("seams")',
        'params.get("ui")',
        'playBtn.onclick',
        '$("reset").onclick',
        '$("seamBefore").onclick',
        '$("seamAfter").onclick',
        '$("seamMark").onclick',
        '$("skyWrap").onclick',
        '$("hideUI").onclick',
    ):
        if token not in standalone:
            fail(f"interaction/API token missing from generated HTML: {token}")

    temp = OUT_HTML.with_name(OUT_HTML.name + ".tmp")
    temp.write_bytes(standalone.encode("utf-8"))
    temp.replace(OUT_HTML)

    after_hashes = {str(path): sha256(path) for path in protected_paths}
    if before_hashes != after_hashes:
        changed = [path for path in before_hashes if before_hashes[path] != after_hashes.get(path)]
        fail("source files changed during packaging: " + ", ".join(changed))

    print(f"OK  {OUT_HTML}")
    print(f"bytes {OUT_HTML.stat().st_size}")
    print(f"assets {len(assets)} (all layers/*.png, all config runtime keys)")
    print("keys:")
    for key in keys:
        print(f"  {key}  png={asset_lengths[key]}B  data_uri={len(assets[key])}B")
    print(f"protected_inputs {len(protected_paths)} unchanged_after_build=yes")
    print("hashes:")
    for path in protected_paths:
        print(f"  {sha256(path)}  {path.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
