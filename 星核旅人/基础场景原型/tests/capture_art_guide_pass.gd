extends Node

## Three real-engine GUI frames for the 2026-11-12 art + guide-echo pass.
##
## Run with the GUI executable (no _console):
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_art_guide_pass.tscn
##
## These are scripted fixed poses, not manual continuous play. For the first
## frame the start menu is disabled and the intro is shortened so the capture can
## focus on the NPC/dialogue; the F event is a real InputEventKey through the
## running engine. The level geometry and dialogue text are the production ones.

const LEVEL01: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL02: PackedScene = preload("res://scenes/level_02.tscn")
const CAPTURE_DIR: String = "res://screenshots"
const LOG_PATH: String = "res://tests/logs/art_guide_pass_capture_20261112.log"

var _lines: Array[String] = []
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_log("Art + guide echo GUI capture - 2026-11-12")
	_log("Godot: %s" % Engine.get_version_info()["string"])
	_log("Display: %s  window: %s  viewport: %s" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size()),
		str(get_viewport().get_visible_rect().size)
	])
	_log("Scripted fixed poses from the running engine root viewport, not manual play.")
	_log("Level 01 setup: start menu disabled, intro shortened to 0.15 s; real F event.")

	var level01: Level01 = LEVEL01.instantiate() as Level01
	level01.enable_start_menu = false
	level01.intro_max_duration = 0.15
	add_child(level01)
	for _i: int in range(240):
		await get_tree().process_frame
		if not level01.is_intro_active():
			break
	var player: PrototypePlayer = level01.get_player()
	player.global_position = Vector2(286.0, 300.0)
	player.velocity = Vector2.ZERO
	level01.get_camera().reset_smoothing()
	await _process_frames(5)
	var guide: GuideEcho = level01.get_narrative_guide()
	_log("guide in_range=%s prompt=%s dialog=%s" % [
		str(guide.is_in_range()), str(guide.is_prompt_visible()), str(guide.is_dialogue_open())
	])
	await _tap_f()
	_log("after real F: prompt=%s dialog=%s page=%d/%d" % [
		str(guide.is_prompt_visible()), str(guide.is_dialogue_open()),
		guide.get_page_index() + 1, guide.get_page_count()
	])
	await _capture(
		"art_guide_pass_01_level01_echo_dialogue.png",
		"first fixed echo at (250,300), 48x64 idle frame and 12 px speaker/body panel above the player; real F opened page 1"
	)
	level01.queue_free()
	await _process_frames(4)

	var level02: Level02 = LEVEL02.instantiate() as Level02
	add_child(level02)
	await _physics_frames(10)
	var l2_player: PrototypePlayer = level02.get_player()
	var guard = level02.get_guard()
	l2_player.global_position = Vector2(300.0, 264.0)
	l2_player.velocity = Vector2.ZERO
	guard.reset_experiment_state(Vector2(344.0, 264.0), true)
	guard.set_ai_suspended(true)
	await _physics_frames(6)
	await _capture(
		"art_guide_pass_02_level02_guard_seams.png",
		"warm-grey platform, five neutral seam grooves at x260/284/324/348/372, 12 px world labels (exit status y196..212; duplicate door label suppressed), guard HP bar clear of labels"
	)

	l2_player.global_position = Vector2(180.0, 320.0)
	l2_player.velocity = Vector2.ZERO
	l2_player.set_physics_process(true)
	await _physics_frames(14)
	await _capture(
		"art_guide_pass_03_level02_under_highstep.png",
		"player standing in the 32 px gap under HighStep (x152..208); HighStep V3 slices at z6 now occlude hair at y284..287, alpha remains clear at y>=288, collision bottom 288"
	)

	_write_log()
	print("ART_GUIDE_PASS_CAPTURE_DONE images=%d" % _lines.size())
	get_tree().quit(0)


func _tap_f() -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_F
	down.keycode = KEY_F
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_F
	up.keycode = KEY_F
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame


func _capture(file_name: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = CAPTURE_DIR + "/" + file_name
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
		_log("CAPTURED %s size=%s path=%s" % [
			file_name, str(image.get_size()), ProjectSettings.globalize_path(path)
		])
	_lines.append("%s | %s" % [file_name, note])
	get_tree().paused = false
	await get_tree().process_frame


func _process_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _write_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % LOG_PATH)
		return
	for line: String in _log_lines:
		file.store_line(line)
	for line: String in _lines:
		file.store_line(line)
	file.close()
