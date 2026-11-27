extends Node

## Base-campaign 90-frame load/run smoke test (L1/L2/L3 only).
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/opening_l1/tests/smoke_base_90f.tscn
##
## This proves each base level and the real level-01 opening survive 90 process
## frames and free without the harness dying. The console log is checked
## separately for SCRIPT ERROR / ERROR lines.

const SCENES: Array[String] = [
	"res://scenes/level_01.tscn",
	"res://scenes/level_02.tscn",
	"res://scenes/level_03.tscn",
]

var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	for scene_path: String in SCENES:
		await _run_one(scene_path)
	print("SMOKE_BASE_90F failures=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run_one(scene_path: String) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		print("SMOKE_BASE_FAIL load %s" % scene_path)
		_failures += 1
		return
	var level: Node = packed.instantiate()
	if level == null:
		print("SMOKE_BASE_FAIL instantiate %s" % scene_path)
		_failures += 1
		return
	if scene_path == "res://scenes/level_01.tscn":
		level.set("enable_start_menu", false)
	get_tree().root.add_child(level)
	for _index: int in range(90):
		await get_tree().process_frame
	if not is_instance_valid(level) or not level.is_inside_tree():
		print("SMOKE_BASE_FAIL run %s" % scene_path)
		_failures += 1
		return
	print("SMOKE_BASE_OK %s frames=90" % scene_path)
	level.queue_free()
	for _index: int in range(24):
		await get_tree().process_frame
