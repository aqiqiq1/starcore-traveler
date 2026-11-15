extends Node

## Two formal 640x360 frames for the text cleanup / unified exit FX:
##  01 cleaned L2 gate-open setup (no world labels, short HUD)
##  02 L1 normal gameplay gate with the shared v2 FX
## Fixed setup, not a completion run. No preview overlay.

const L1_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const L2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const OUT_DIR: String = "res://screenshots/gate_text_cleanup_20261114"
const LOG_PATH: String = OUT_DIR + "/manifest.json"

var _lines: Array[String] = []
var _l2_open_camera: Vector2 = Vector2.ZERO
var _l1_camera: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_log("L2 text cleanup / unified exit FX capture - 2026-11-14")
	_log("Godot %s; 640x360; fixed setup, not a completion run" % Engine.get_version_info()["string"])
	await _capture_l2()
	await _capture_l1()
	_write_manifest()
	print("GATE_TEXT_CLEANUP_CAPTURE_DONE images=2")
	get_tree().quit(0)


func _capture_l2() -> void:
	var level: Level02 = L2_SCENE.instantiate() as Level02
	add_child(level)
	await _frames(6)
	await _physics(3)
	var player: PrototypePlayer = level.get_player()
	var core: StarCoreCarrier = level.get_core()
	level.debug_restore_stage(2, true)
	if level.get_hud() != null:
		level.get_hud().show_toast("", 0.0)
	player.global_position = Vector2(1600, 320)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	level.get_camera().reset_smoothing()
	await _physics(4)
	await _open_gate(level, core)
	await _physics(4)
	await _frames(10)
	_l2_open_camera = level.get_camera().global_position
	_check(level.is_exit_gate_ready(), "L2 capture setup is gate-ready")
	_check(level.get_exit().is_gate_fx_visible(), "L2 capture FX visible")
	await _save(
		"01_l2_clean_scene.png",
		"Formal L2 cleaned scene: no bay/rule/ExitStatus world labels, short objective/core HUD, no permanent recovery line; gate-open setup with v2 FX, player/camera fixed at (1600,320)."
	)
	level.queue_free()
	await _frames(4)


func _capture_l1() -> void:
	var level: Level01 = L1_SCENE.instantiate() as Level01
	level.enable_start_menu = false
	level.intro_max_duration = 0.5
	add_child(level)
	await _frames(3)
	for _i: int in range(80):
		await _frames(1)
		if not level.is_intro_active():
			break
	await _frames(6)
	await _physics(3)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(1760, 300)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	level.get_camera().reset_smoothing()
	await _physics(6)
	_l1_camera = level.get_camera().global_position
	_check(not level.is_intro_active(), "L1 capture is normal gameplay")
	_check(level.get_exit().is_gate_available(), "L1 normal gate is available")
	_check(level.get_exit().is_gate_fx_visible(), "L1 normal gate FX visible")
	await _save(
		"02_l1_gate_fx.png",
		"Formal L1 normal gameplay setup: intro finished, reachable exit has the shared v2 FX, player/camera fixed near (1760,300); not completed."
	)
	level.queue_free()
	await _frames(4)


func _open_gate(level: Level02, core: StarCoreCarrier) -> void:
	var start_bay: StarCoreBayInteractable = level.get_start_bay()
	var linked: StarCoreBayInteractable = level.get_linked_bay()
	var final_bay: StarCoreBayInteractable = level.get_final_bay()
	var link: BayRuneLink = level.get_link()
	start_bay.reset_empty()
	linked.reset_empty()
	final_bay.reset_empty()
	core.deactivate()
	core.collision_mask = 0
	linked.start_store_core(true)
	linked.finish_store()
	link.restore_committed(true, true)
	linked.start_release()
	linked.finish_release()
	final_bay.start_store_core(true)
	final_bay.finish_store()
	core.global_position = final_bay.get_store_center()
	core.collision_mask = 0
	await _physics(3)


func _save(file_name: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var path: String = OUT_DIR + "/" + file_name
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("cleanup capture save failed: %s error=%d" % [path, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
		_log("CAPTURED %s size=%s note=%s" % [file_name, str(image.get_size()), note])
	get_tree().paused = false
	await get_tree().process_frame


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _log(text: String) -> void:
	_lines.append(text)


func _check(ok: bool, text: String) -> void:
	if not ok:
		push_error("CLEANUP CAPTURE FAIL: " + text)


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	var data: Dictionary = {
		"created": "2026-11-14",
		"formal_scenes": ["res://scenes/level_02.tscn", "res://scenes/level_01.tscn"],
		"viewport": [640, 360],
		"scripted_fixed_frames": true,
		"manual_play": false,
		"not_a_completion_run": true,
		"preview_overlay": false,
		"l2": {
			"file": "01_l2_clean_scene.png",
			"world_labels_removed": true,
			"permanent_recovery_line_removed": true,
			"gate_ready_setup": true,
			"camera": [_l2_open_camera.x, _l2_open_camera.y],
			"gate_fx_file": "res://assets/checkpoint_exit/gate_portal_fx_v2_8f.png",
			"gate_fx_frames": 8,
			"gate_fx_fps": 8.0,
		},
		"l1": {
			"file": "02_l1_gate_fx.png",
			"normal_gameplay_setup": true,
			"gate_available": true,
			"camera": [_l1_camera.x, _l1_camera.y],
			"gate_fx_file": "res://assets/checkpoint_exit/gate_portal_fx_v2_8f.png",
		},
		"log": _lines,
	}
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	file.close()
