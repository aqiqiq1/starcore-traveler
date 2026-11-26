extends Node

## 90-frame load/run smoke test for the six chapters after the art pass.
## Run WITHOUT --headless so any rendering-only error still appears:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/art_audit_20261127/smoke_90f.tscn
##
## This does not assert gameplay routes.  It only proves each scene loads,
## reaches 90 process frames and frees without the harness dying.  The console
## log is checked separately for SCRIPT ERROR / ERROR lines.

const SCENES: Array[String] = [
	"res://scenes/level_01.tscn",
	"res://scenes/level_02.tscn",
	"res://scenes/level_03.tscn",
	"res://dlc/trial_chambers/trial_chambers.tscn",
	"res://dlc/rift_workshop/rift_workshop.tscn",
	"res://dlc/star_loom/star_loom.tscn",
]

var _failures: int = 0
var _normal_entry: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_normal_entry = OS.get_cmdline_user_args().has("normal")
	await get_tree().process_frame
	for scene_path: String in SCENES:
		await _run_one(scene_path)
	print("SMOKE_90F failures=%d normal=%s" % [_failures, str(_normal_entry)])
	get_tree().quit(1 if _failures > 0 else 0)


func _run_one(scene_path: String) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		print("SMOKE_FAIL load %s" % scene_path)
		_failures += 1
		return
	var level: Node = packed.instantiate()
	if level == null:
		print("SMOKE_FAIL instantiate %s" % scene_path)
		_failures += 1
		return
	if not _normal_entry:
		level.set("show_intro_guide", false)
		level.set("show_intro_cinematic", false)
		level.set("show_mechanic_tips", false)
	if scene_path == "res://scenes/level_01.tscn":
		level.set("enable_start_menu", false)
	add_child(level)
	if not _normal_entry:
		var opening: Node = level.get_node_or_null("OpeningCinematic")
		if opening != null and opening.has_method("abort"):
			opening.call("abort")
	for _index: int in range(90):
		await get_tree().process_frame
	if not is_instance_valid(level) or not level.is_inside_tree():
		print("SMOKE_FAIL run %s" % scene_path)
		_failures += 1
		return
	print("SMOKE_OK %s frames=90" % scene_path)
	level.queue_free()
	await get_tree().process_frame
