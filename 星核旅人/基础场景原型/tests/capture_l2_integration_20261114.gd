extends Node

## Up to three formal 640x360 integration frames: gate closed/open at the same
## camera and the L2 entry GuideEcho. Fixed setup, not a completion run.
## Run:
##   Godot --fixed-fps 60 --path . res://tests/capture_l2_integration_20261114.tscn

const L2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const OUT_DIR: String = "res://screenshots/l2_formal_integration_20261114"
const L2_ART_GATE: String = "res://assets/checkpoint_exit/gate_portal_fx_v2_8f.png"
const L2_ART_ECHO: String = "res://assets/guide_echo_20261113/guide_echo_idle_6f_s40.png"

var _lines: Array[String] = []
var _closed_camera: Vector2 = Vector2.ZERO
var _open_camera: Vector2 = Vector2.ZERO
var _closed_ready: bool = false
var _open_ready: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_log("L2 formal integration capture - 2026-11-14")
	_log("Godot %s; 640x360; fixed setup, not a completion run" % Engine.get_version_info()["string"])
	await _capture_gate()
	await _capture_echo()
	_write_manifest()
	print("L2_FORMAL_CAPTURE_DONE images=3")
	get_tree().quit(0)


func _capture_gate() -> void:
	var level: Level02 = L2_SCENE.instantiate() as Level02
	add_child(level)
	await _frames(5)
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
	await _physics(5)
	var exit: LevelExit = level.get_exit()
	_closed_ready = level.is_exit_gate_ready()
	_closed_camera = level.get_camera().global_position
	await _save(
		"01_gate_closed_setup.png",
		"Formal L2 canonical closed setup: linked bay holds the one core, final bay empty, real gate false, no FX, player/camera fixed at (1600,320)."
	)
	await _open_gate(level, core)
	await _physics(3)
	await _frames(10)
	_open_ready = level.is_exit_gate_ready()
	_open_camera = level.get_camera().global_position
	await _save(
		"02_gate_open_setup.png",
		"Formal L2 same camera: same one core moved to the final bay, linked record/field kept, real gate true, 8-frame/8fps v2 FX."
	)
	level.queue_free()
	await _frames(4)


func _capture_echo() -> void:
	var level: Level02 = L2_SCENE.instantiate() as Level02
	add_child(level)
	await _frames(5)
	await _physics(3)
	var player: PrototypePlayer = level.get_player()
	var guide: GuideEcho = level.get_start_stele()
	player.global_position = Vector2(100, 320)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	level.get_camera().reset_smoothing()
	await _frames(35)
	await _save(
		"03_l2_echo.png",
		"Formal L2 entry StartStele is GuideEcho with s40, one stele/one F prompt, no old TutorialStele, no preview overlay."
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
		push_error("L2 formal capture save failed: %s error=%d" % [path, error])
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


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(OUT_DIR + "/manifest.json", FileAccess.WRITE)
	if file == null:
		return
	var data: Dictionary = {
		"created": "2026-11-14",
		"formal_scene": "res://scenes/level_02.tscn",
		"viewport": [640, 360],
		"scripted_fixed_frames": true,
		"manual_play": false,
		"not_a_completion_run": true,
		"preview_overlay": false,
		"gate": {
			"closed_file": "01_gate_closed_setup.png",
			"open_file": "02_gate_open_setup.png",
			"closed_ready": _closed_ready,
			"open_ready": _open_ready,
			"same_camera": _closed_camera.is_equal_approx(_open_camera),
			"camera_closed": [_closed_camera.x, _closed_camera.y],
			"camera_open": [_open_camera.x, _open_camera.y],
			"art_file": L2_ART_GATE,
			"art_version": "v2_8f",
			"frames": 8,
			"fps": 8.0,
		},
		"echo": {
			"file": "03_l2_echo.png",
			"art_file": L2_ART_ECHO,
			"art_version": "s40_6f",
			"frames": 6,
			"fps": 4.0,
		},
		"log": _lines,
	}
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	file.close()
