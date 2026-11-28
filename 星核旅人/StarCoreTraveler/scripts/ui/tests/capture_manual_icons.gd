extends Node

## 640x360 evidence for the 2026-11-28 manual icon set.
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://scripts/ui/tests/capture_manual_icons.tscn
##
## Saves screenshots/manual_icons_20261128/01_page1.png and 02_page2.png.
## Both pages are the live pause-page manual with all 15 rows unlocked, so
## every dedicated 12x12 icon is visible next to its name.

const L1_SCENE: String = "res://scenes/level_01.tscn"
const OUT_DIR: String = "res://screenshots/manual_icons_20261128"
const TEST_PROGRESS: String = "user://capture_manual_icons_20261128.cfg"

const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")

var _level: Node = null
var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MechanicTeach.set_progress_path_override(TEST_PROGRESS)
	_remove_file(TEST_PROGRESS)
	await get_tree().process_frame
	await _run()
	print("MANUAL_ICONS_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	MechanicTeach.clear_progress_path_override()
	get_tree().quit(0 if _saved.size() == 2 else 1)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	_saved.append(name)
	print("SHOT %s size=%dx%d error=%d" % [name, image.get_width(), image.get_height(), error])


func _log_page(manual: MechanicManual, label: String) -> void:
	var ids: Array[String] = manual.get_visible_row_ids()
	var icons: Array[Dictionary] = manual.get_current_row_icon_textures()
	var keys: Array[Dictionary] = manual.get_current_row_key_textures()
	var icon_paths: Array[String] = []
	for icon_info: Dictionary in icons:
		icon_paths.append("%s=%s" % [String(icon_info["id"]), String(icon_info["path"])])
	print("PAGE %s index=%d ids=%s" % [label, manual.get_page_index(), str(ids)])
	print("PAGE %s icons=%s" % [label, " | ".join(icon_paths)])
	var key_summary: String = ""
	for key_info: Dictionary in keys:
		key_summary += "%s:%s; " % [String(key_info["id"]), String(key_info["path"])]
	print("PAGE %s keys=%s" % [label, key_summary])


func _run() -> void:
	var packed: PackedScene = load(L1_SCENE) as PackedScene
	if packed == null:
		print("CAPTURE_FAIL l1 scene missing")
		return
	_level = packed.instantiate()
	_level.set("enable_start_menu", false)
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(8)
	var opening: Node = _level.call("get_opening") as Node
	if opening != null and bool(opening.call("is_active")):
		opening.call("abort")
	await _wait_process(5)
	get_tree().paused = false

	var player: PrototypePlayer = _level.call("get_player") as PrototypePlayer
	var gate: PolarityGate = _level.call("get_exit_polarity_gate") as PolarityGate
	var camera: Camera2D = _level.call("get_camera") as Camera2D
	var teach: MechanicTeach = _level.call("get_mechanic_teach") as MechanicTeach
	var pause: Node = _level.call("get_pause_menu") as Node
	if player == null or gate == null or camera == null or teach == null or pause == null:
		print("CAPTURE_FAIL l1 objects missing")
		return

	# Put the world on the same gate frame the manual normally opens over, then
	# unlock every row so page 1 and page 2 expose all 15 icons.
	player.global_position = Vector2(gate.global_position.x - 56.0, 300.0)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(true)
	player.set_facing_direction(1)
	camera.reset_smoothing()
	await _wait_physics(5)
	await _wait_seconds(0.15)
	for id: String in REGISTRY.all_ids():
		teach.mark_unlocked(id)
	await _wait_process(3)

	pause.call("open_pause")
	await _wait_process(3)
	pause.call("open_manual")
	await _wait_process(4)
	var manual: MechanicManual = pause.call("get_manual") as MechanicManual
	if manual == null or not manual.is_open():
		print("CAPTURE_FAIL manual did not open")
		return
	print("MANUAL unlocked=%d locked=%d pages=%d" % [
		manual.get_visible_unlocked_count(),
		manual.get_locked_count(),
		manual.get_page_count(),
	])
	_log_page(manual, "1")
	await _save("01_page1.png")

	manual.turn_page(1)
	await _wait_process(4)
	_log_page(manual, "2")
	await _save("02_page2.png")

	manual.close()
	pause.call("force_close")
	get_tree().paused = false
	get_tree().current_scene = null
	_level.queue_free()
	_level = null
	await _wait_process(10)
	_remove_file(TEST_PROGRESS)
