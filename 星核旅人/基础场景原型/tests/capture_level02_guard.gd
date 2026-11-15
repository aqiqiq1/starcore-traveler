extends Node

## Two real-engine GUI frames for the level-02 guard integration.
##
## Run with the GUI executable (no _console):
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_level02_guard.tscn
##
## The frames are scripted fixed poses from the real engine root viewport, not a
## claim of manual continuous play. Only two images are produced:
##   level02_guard_01_bridge.png  - guard, 3-pip bar, labels clear of the bar
##   level02_guard_02_stele_rules.png - the new readable rule page

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const CAPTURE_DIR: String = "res://screenshots"
const LOG_PATH: String = "res://tests/logs/level02_guard_capture.log"

var _level: Level02
var _player: PrototypePlayer
var _guard = null
var _lines: Array[String] = []
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_level = LEVEL_SCENE.instantiate() as Level02
	add_child(_level)
	await _physics(8)
	_player = _level.get_player()
	_guard = _level.get_guard()

	_log("Level 02 guard integration GUI capture")
	_log("Godot: %s" % Engine.get_version_info()["string"])
	_log("Display: %s  window: %s  viewport: %s" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size()),
		str(get_viewport().get_visible_rect().size)
	])
	_log("Scripted fixed frames from the running engine root viewport, not manual play.")

	# Fixed bridge pose. The guard is held on patrol so the HP bar and labels
	# are judged as layout, not as an attack frame.
	_player.global_position = Vector2(300.0, 264.0)
	_player.velocity = Vector2.ZERO
	_guard.reset_experiment_state(Vector2(344.0, 264.0), true)
	_guard.set_ai_suspended(true)
	await _physics(4)
	await _capture(
		"level02_guard_01_bridge.png",
		"bridge guard: orange-gold body, 3-pip bar at y=208, no head polarity word; labels moved to y=188..200"
	)

	# New stele rule page. Position the player at the real start stele and open
	# page 3 (colour recognition + same-phase J) at native 12 px.
	_level._restart_level()
	await _physics(4)
	_player.global_position = Vector2(80.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _physics(6)
	# Historical tutorial-stele capture; L2 now exposes GuideEcho. Keep the
	# dynamic access so this old script still parses without claiming its old
	# runtime behavior is current.
	var stele = _level.get_start_stele()
	stele.open_first_page()
	stele.advance_page()
	stele.advance_page()
	await get_tree().process_frame
	await get_tree().process_frame
	_log("stele page index=%d pages=%d" % [stele.get_page_index(), stele.get_page_count()])
	await _capture(
		"level02_guard_02_stele_rules.png",
		"new rule page: orange/blue phase recognition and same-phase J, native 12 px, 3 short lines"
	)

	_write_log()
	print("LEVEL02_GUARD_CAPTURE_DONE images=%d" % _lines.size())
	get_tree().quit(0)


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


func _physics(count: int) -> void:
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
