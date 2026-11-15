extends Node

## Three real 640x360 GUI frames for the formal rebuild.
## Run with the GUI/console executable, not --headless:
##   Godot --path . res://tools/bridge_ground_capture.tscn

const L1: PackedScene = preload("res://scenes/level_01.tscn")
const L2: PackedScene = preload("res://scenes/level_02.tscn")
const OUT: String = "res://screenshots/level02_rebuild_20261113"
const RAW: String = OUT + "/raw"

var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RAW))
	if DisplayServer.window_get_size() == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _frames(3)
	_log("Formal L1/L2 unified-ground rebuild captures - 2026-11-13")
	_log("Godot %s; viewport 640x360" % Engine.get_version_info()["string"])

	await _capture_l1()
	await _capture_l2_initial()
	await _capture_l2_combo()
	_write_manifest()
	print("BRIDGE_GROUND_CAPTURE_DONE images=3")
	get_tree().quit(0)


func _capture_l1() -> void:
	var level: Level01 = L1.instantiate() as Level01
	level.set("enable_start_menu", false)
	level.set("intro_max_duration", 0.05)
	add_child(level)
	await _frames(10)
	if level.is_intro_active():
		level.call("_finish_intro")
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(1030, 220)
	player.velocity = Vector2.ZERO
	player.show_showcase(&"idle", 0, 1, true)
	var formal: Camera2D = level.get_camera()
	if formal != null:
		formal.enabled = false
	var camera: Camera2D = Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.position = Vector2(1264, 180)
	add_child(camera)
	camera.enabled = true
	camera.make_current()
	await _frames(3)
	await _save("01_l1_ground.png", "L1 formal ground, fixed screen_left 944; player idle at (1030,220)")
	level.queue_free()
	camera.queue_free()
	await _frames(4)


func _capture_l2_initial() -> void:
	var level: Level02 = L2.instantiate() as Level02
	add_child(level)
	await _frames(16)
	await _physics(4)
	await _save("02_l2_initial.png", "L2 initial safe transport: real spawn (36,320), start/relay bays visible")
	level.queue_free()
	await _frames(4)


func _capture_l2_combo() -> void:
	var level: Level02 = L2.instantiate() as Level02
	add_child(level)
	await _frames(10)
	level.debug_restore_stage(2, false)
	await _frames(4)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(1100, 240)
	player.velocity = Vector2.ZERO
	player.show_showcase(&"idle", 0, -1, true)
	# The capture shows the post-release combo: the linked bay is open but its
	# record/lamp/field stay held. This is a setup, not a second core.
	level.get_linked_bay().start_release()
	level.get_linked_bay().finish_release()
	var core: StarCoreCarrier = level.get_core()
	core.activate_at(Vector2(1130, 312), false)
	core.velocity = Vector2.ZERO
	level.call("_update_level_hud")
	level.get_hud().show_toast("", 0.0)
	var formal: Camera2D = level.get_camera()
	if formal != null:
		formal.enabled = false
	var camera: Camera2D = Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.position = Vector2(1100, 180)
	add_child(camera)
	camera.enabled = true
	camera.make_current()
	await _save(
		"03_l2_linked_combo.png",
		"L2 linked combo setup: rune active, core at corridor mouth, player on the 240 sill; fixed camera center 1100"
	)
	level.queue_free()
	camera.queue_free()
	await _frames(4)


func _save(file_name: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var path: String = RAW + "/" + file_name
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Capture save failed %s error=%d" % [file_name, error])
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
	var path: String = OUT + "/capture_manifest.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	var data: Dictionary = {
		"created": "2026-11-13",
		"viewport": [640, 360],
		"scripted_fixed_frames": true,
		"manual_play": false,
		"completion_claim": false,
		"frames": [
			{"file": "raw/01_l1_ground.png", "note": "L1 formal ground, fixed screen_left 944"},
			{"file": "raw/02_l2_initial.png", "note": "L2 real spawn, safe transport"},
			{"file": "raw/03_l2_linked_combo.png", "note": "L2 linked combo setup, not a completion"},
		],
		"log": _lines,
	}
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	file.close()
