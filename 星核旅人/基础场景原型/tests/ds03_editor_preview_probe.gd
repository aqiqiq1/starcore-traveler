@tool
extends Node

## Editor-only probe: proves the background scene is in its deterministic t=0
## preview state and is not processing animation in the editor. Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --editor --quit --path . \
##     res://tests/ds03_editor_preview_probe.tscn

const LOG_PATH: String = "res://tests/logs/ds03_editor_preview_probe.log"


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	call_deferred("_probe_editor_preview")


func _probe_editor_preview() -> void:
	var bg: CloudRuinsDS03 = get_parent().get_node_or_null("CloudRuinsDS03") as CloudRuinsDS03
	var lines: Array[String] = []
	lines.append("editor_hint=%s" % str(Engine.is_editor_hint()))
	lines.append("component=%s" % str(bg != null))
	if bg != null:
		lines.append("time=%.3f" % bg.get_background_time())
		lines.append("processing=%s" % str(bg.is_processing()))
		lines.append("sea_main_phase=%d" % bg.get_sea_phase("sea_main"))
		lines.append("sky_bank_left_x=%d" % bg.get_sky_x("sky_bank_left"))
		lines.append("G1_dy=%d" % bg.get_group_render_dy("G1"))
		lines.append("G3_dy=%d" % bg.get_group_render_dy("G3"))
		lines.append("sea_main_clip=%d" % (bg.get_node("SeaMain") as Node2D).clip_children)
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	print("DS03_EDITOR_PREVIEW_PROBE " + " ".join(lines))
