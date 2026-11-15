#!/usr/bin/env python3
"""Protection check for the formal L1/L2 unified-ground rebuild.

A before-snapshot is written before edits. After the run, changed paths are
reported separately as AUTHORIZED (scene/script/HUD files this task owns) or
UNAUTHORIZED. New files are not in the baseline.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "tests" / "logs" / "bridge_ground_before.json"
REPORT = ROOT / "tests" / "logs" / "bridge_ground_protection.json"

AUTHORIZED = {
    "scenes/level_01.tscn",
    "scenes/level_02.tscn",
    "scripts/level_02.gd",
    "scripts/level_02_hud.gd",
    "scripts/level_hud.gd",
    "scenes/decorations/doric_column_tall.tscn",
    "scenes/decorations/doric_column_broken.tscn",
    "scenes/decorations/doric_column_base.tscn",
    "scripts/bay_rune_link.gd",
    "scripts/rune_stone_field.gd",
    "scripts/tutorial_stele.gd",
}

FIXED = [
    "project.godot",
    "scenes/level_01.tscn",
    "scenes/level_02.tscn",
    "scripts/level_02.gd",
    "scripts/level_02_hud.gd",
    "scenes/decorations/doric_column_tall.tscn",
    "scenes/decorations/doric_column_broken.tscn",
    "scenes/decorations/doric_column_base.tscn",
    "scenes/decorations/doric_column_fallen.tscn",
    "scripts/bay_rune_link.gd",
    "scripts/rune_stone_field.gd",
    "scripts/tutorial_stele.gd",
    "scenes/main.tscn",
    "scenes/player.tscn",
    "scenes/backgrounds/cloud_ruins_ds03.tscn",
    "scenes/narrative/guide_echo.tscn",
    "scenes/enemies/polarity_golem_guard.tscn",
    "scenes/star_core_bay_interactable.tscn",
    "scenes/star_core_bay_visual.tscn",
    "scenes/star_core_carrier.tscn",
    "scenes/star_core_visual.tscn",
    "scenes/rune_stone_field.tscn",
    "scenes/rune_stone_visual.tscn",
    "scenes/polarity_link_visual.tscn",
    "scripts/level_01.gd",
    "scripts/player.gd",
    "scripts/level_terrain_block.gd",
    "scripts/level02_block.gd",
    "scripts/level_hud.gd",
    "scripts/level_checkpoint.gd",
    "scripts/level_exit.gd",
    "scripts/narrative/guide_echo.gd",
    "scripts/backgrounds/cloud_ruins_ds03.gd",
    "scripts/experiments/polarity_golem_enemy.gd",
    "scripts/experiments/polarity_golem_player.gd",
    "scripts/star_core_bay_interactable.gd",
    "scripts/star_core_bay_visual.gd",
    "scripts/star_core_carrier.gd",
    "scripts/star_core_visual.gd",
    "scripts/ui/level_flow.gd",
    "scripts/ui/pause_menu.gd",
    "assets/characters/male_hero-idle.png",
    "assets/guide_echo_20261113/guide_echo_idle_6f.png",
    "assets/doric_columns/doric_column_tall.png",
    "assets/doric_columns/doric_column_broken.png",
    "assets/doric_columns/doric_column_base.png",
    "assets/doric_columns/doric_column_fallen.png",
    "assets/doric_columns/source_manifest.json",
    "assets/bridge_stone_v1/columns/doric_column_tall_basesquare.png",
    "assets/bridge_stone_v1/columns/doric_column_broken_basesquare.png",
    "assets/bridge_stone_v1/columns/doric_column_base_basesquare.png",
    "assets/backgrounds/cloud_ruins_ds03/runtime_config.json",
    "assets/backgrounds/cloud_ruins_ds03/source_manifest.json",
]


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def files() -> list[str]:
    out = list(FIXED)
    ds03 = ROOT / "assets" / "backgrounds" / "cloud_ruins_ds03"
    for path in sorted(ds03.rglob("*.png")):
        out.append(path.relative_to(ROOT).as_posix())
    return out


def main() -> int:
    rels = files()
    current = {rel: sha(ROOT / rel) for rel in rels}
    if "--write" in sys.argv:
        BASE.parent.mkdir(parents=True, exist_ok=True)
        BASE.write_text(json.dumps(current, indent=2) + "\n", encoding="utf-8")
        print(f"WROTE {BASE} ({len(rels)} files)")
        return 0
    before = json.loads(BASE.read_text(encoding="utf-8"))
    changed = [rel for rel in rels if before.get(rel) != current[rel]]
    authorized = [rel for rel in changed if rel in AUTHORIZED]
    unauthorized = [rel for rel in changed if rel not in AUTHORIZED]
    report = {
        "baseline": BASE.relative_to(ROOT).as_posix(),
        "file_count": len(rels),
        "changed": changed,
        "authorized": authorized,
        "unauthorized": unauthorized,
        "current": current,
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for rel in authorized:
        print(f"AUTHORIZED {rel}")
    for rel in unauthorized:
        print(f"UNAUTHORIZED {rel}", file=sys.stderr)
    print(f"PROTECTION {len(rels)} files; authorized={len(authorized)} unauthorized={len(unauthorized)}")
    return 1 if unauthorized else 0


if __name__ == "__main__":
    raise SystemExit(main())
