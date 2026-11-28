extends Node

## 640x360 evidence for the first-encounter teaching line and mixed manual.
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://scripts/ui/tests/capture_mechanic_manual.tscn
##
## Saves screenshots/manual_20261128/01_first_teach.png and 02_manual_mixed.png.
## Both frames are the live viewport, not a mockup.

const L1_SCENE: String = "res://scenes/level_01.tscn"
const OUT_DIR: String = "res://screenshots/manual_20261128"
const TEST_PROGRESS: String = "user://capture_mechanic_manual_20261128.cfg"

var _level: Node = null
var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MechanicTeach.set_progress_path_override(TEST_PROGRESS)
	_remove_file(TEST_PROGRESS)
	await get_tree().process_frame
	await _run()
	print("MECHANIC_MANUAL_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
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
	var hud: Level01HUD = _level.call("get_hud") as Level01HUD
	if player == null or gate == null or camera == null or teach == null or hud == null:
		print("CAPTURE_FAIL l1 objects missing")
		return

	# 1. First encounter: 56 px before the closed same-phase gate, facing it.
	player.global_position = Vector2(gate.global_position.x - 56.0, 300.0)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(true)
	player.set_facing_direction(1)
	camera.reset_smoothing()
	await _wait_physics(5)
	await _wait_seconds(0.25)
	await _wait_process(2)
	print("CAPTURE_TEACH line=%s unlocked=%s" % [
		hud.get_toast_text(), str(teach.is_unlocked("gate"))
	])
	await _save("01_first_teach.png")

	# 2. Mixed manual: the real pause page over the same level, with the gate
	# already recorded plus a few more rows, so locked ？？？ rows are visible.
	teach.mark_unlocked("polarity")
	teach.mark_unlocked("rune")
	teach.mark_unlocked("bay")
	teach.mark_unlocked("checkpoint")
	var pause: Node = _level.call("get_pause_menu") as Node
	if pause == null:
		print("CAPTURE_FAIL pause menu missing")
		return
	pause.call("open_pause")
	await _wait_process(3)
	pause.call("open_manual")
	await _wait_process(4)
	var manual: MechanicManual = pause.call("get_manual") as MechanicManual
	print("CAPTURE_MANUAL open=%s unlocked=%d locked=%d subtitle=%s" % [
		str(manual.is_open()) if manual != null else "null",
		manual.get_visible_unlocked_count() if manual != null else -1,
		manual.get_locked_count() if manual != null else -1,
		manual.get_subtitle_text() if manual != null else "",
	])
	await _save("02_manual_mixed.png")

	if manual != null:
		manual.close()
	pause.call("force_close")
	get_tree().paused = false
	get_tree().current_scene = null
	_level.queue_free()
	_level = null
	await _wait_process(10)
	_remove_file(TEST_PROGRESS)
