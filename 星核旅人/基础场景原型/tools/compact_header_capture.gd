extends Node

## Two real 640x360 GUI frames for the compact formal header.
## Run with the console executable (not --headless):
##   Godot --path . res://tools/compact_header_capture.tscn
## The L1 frame is a fixed setup with the real level/HUD (menu/intro skipped,
## then a real Q to cyan). The L2 frame is the real spawn with the default gold.

const L1: PackedScene = preload("res://scenes/level_01.tscn")
const L2: PackedScene = preload("res://scenes/level_02.tscn")
const OUT: String = "res://screenshots/compact_header_20261114"
const L1_PATH: String = OUT + "/01_l1_cyan.png"
const L2_PATH: String = OUT + "/02_l2_gold.png"
const LOG_PATH: String = OUT + "/capture_manifest.json"

var _log: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if DisplayServer.window_get_size() == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _frames(3)
	_log_line("Compact formal HUD capture - 2026-11-14")
	_log_line("Godot %s; logical viewport 640x360" % Engine.get_version_info()["string"])

	var l1: Level01 = L1.instantiate() as Level01
	l1.enable_start_menu = false
	l1.set("intro_max_duration", 0.05)
	add_child(l1)
	await _frames(12)
	if l1.is_intro_active():
		l1.call("_finish_intro")
	var p1: PrototypePlayer = l1.get_player()
	p1.global_position = Vector2(100, 300)
	p1.velocity = Vector2.ZERO
	l1.get_camera().reset_smoothing()
	await _frames(6)
	await _tap_key(KEY_Q)      # real player Q -> cyan HUD
	await _frames(6)
	await _save(L1_PATH, "L1 real level/HUD, cyan header, fixed player x100; menu skipped")
	l1.queue_free()
	await _frames(4)

	var l2: Level02 = L2.instantiate() as Level02
	add_child(l2)
	await _frames(16)
	await _physics(4)
	await _save(L2_PATH, "L2 real spawn (36,320), default gold header, normal status block")
	l2.queue_free()
	await _frames(4)
	_write_manifest()
	print("COMPACT_HEADER_CAPTURE_DONE images=2")
	get_tree().quit(0)


func _save(path: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Capture save failed: %s error=%d" % [path, error])
	else:
		print("CAPTURED %s size=%s" % [path.get_file(), str(image.get_size())])
		_log_line("CAPTURED %s size=%s note=%s" % [path.get_file(), str(image.get_size()), note])
	get_tree().paused = false
	await get_tree().process_frame


func _tap_key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _log_line(text: String) -> void:
	_log.append(text)


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	var data: Dictionary = {
		"created": "2026-11-14",
		"viewport": [640, 360],
		"scripted_fixed_frames": true,
		"manual_play": false,
		"frames": [
			{"file": "01_l1_cyan.png", "note": "L1 real level/HUD, cyan header, fixed setup"},
			{"file": "02_l2_gold.png", "note": "L2 real spawn, gold header"},
		],
		"derived": "header_compare.png (top 0..48 of each raw, stacked 640x96; no repaint)",
		"log": _log,
	}
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	file.close()
