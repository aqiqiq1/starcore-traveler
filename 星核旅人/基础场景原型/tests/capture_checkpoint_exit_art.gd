extends Node

## Real-engine 640x360 captures of the approved checkpoint/exit art. These are
## scripted fixed poses, not a claim of manual continuous play. Run with the GUI
## Godot executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_checkpoint_exit_art.tscn

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const CAPTURE_DIR: String = "res://screenshots"
const CAPTURE_PREFIX: String = "checkpoint_exit_warm_"
const MANIFEST_NAME: String = "MANIFEST_CHECKPOINT_EXIT_ART_WARM.txt"

var _level: Level01
var _player: PrototypePlayer
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))

	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _step(8)
	_player = _level.get_player()
	if _player == null:
		push_error("Capture setup failed: player missing")
		get_tree().quit(1)
		return

	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _step(3)

	_lines.append("Star Core Traveler - checkpoint / exit art engine captures")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s" % DisplayServer.get_name())
	_lines.append("Window: %s  logical viewport: 640x360" % str(DisplayServer.window_get_size()))
	_lines.append("These are scripted fixed poses from the running engine root viewport, not manual continuous play.")
	_lines.append("Warm-stone revision: the four runtime PNGs use the doric_column_tall.png stone palette; geometry, alpha, anchors and sizes are unchanged.")
	_lines.append("The four PNGs are byte-identical copies of the approved 40x36 / 76x100 concept art, drawn 1:1 at their 20,35 / 38,99 foot anchors.")
	_lines.append("")
	_lines.append("01 " + CAPTURE_PREFIX + "01_checkpoint_inactive.png | high-platform checkpoint before activation; player staged nearby, real scene, state untouched.")
	_lines.append("02 " + CAPTURE_PREFIX + "02_checkpoint_active.png | same checkpoint after a real Area2D touch activated it; player moved back for framing only.")
	_lines.append("03 " + CAPTURE_PREFIX + "03_exit_open.png | far-bank gate in its normal open state; player staged outside the 36x76 trigger, not completed; existing DoricTallFarBank column shares the frame.")
	_lines.append("04 " + CAPTURE_PREFIX + "04_exit_completed_visual.png | gate forced to its completed visual state for inspection only; NOT a real completion and no completion panel. Real completion is covered by tests/test_level_01.")
	_lines.append("")

	await _wait_intro_done()

	# 01: inactive checkpoint, staged just left of the trigger.
	await _place(Vector2(1082.0, 220.0))
	await _step(6)
	await _capture(
		CAPTURE_PREFIX + "01_checkpoint_inactive.png",
		"checkpoint inactive; staged player at x=1082, outside the trigger"
	)
	if _level.get_checkpoint().is_activated():
		push_error("Capture state error: checkpoint activated during the inactive pose")
		get_tree().quit(1)
		return

	# 02: activate through the real overlap, then step back for a clear view.
	await _place(Vector2(1120.0, 220.0))
	await _step(8)
	if not _level.get_checkpoint().is_activated():
		push_error("Capture state error: checkpoint did not activate on the real touch")
		get_tree().quit(1)
		return
	await _place(Vector2(1082.0, 220.0))
	await get_tree().create_timer(1.7).timeout
	await _step(4)
	await _capture(
		CAPTURE_PREFIX + "02_checkpoint_active.png",
		"checkpoint active after real touch; toast allowed to expire before capture"
	)

	# 03: open exit, staged outside the trigger so it never completes.
	await _place(Vector2(1756.0, 300.0))
	await get_tree().create_timer(1.2).timeout
	await _step(6)
	if _level.is_completed() or _level.get_exit().is_completed():
		push_error("Capture state error: exit completed during the open pose")
		get_tree().quit(1)
		return
	await _capture(
		CAPTURE_PREFIX + "03_exit_open.png",
		"exit open; staged player at x=1756, outside the trigger; DoricTallFarBank column in frame"
	)

	# 04: visual state only. The real completion path shows the panel over the
	# gate, so this inspection shot calls set_completed(true) without completing
	# the level. The manifest states that honestly.
	_level.get_exit().set_completed(true)
	await _step(8)
	await _capture(
		CAPTURE_PREFIX + "04_exit_completed_visual.png",
		"exit completed art, visual-only state; not a real completion, no panel"
	)

	_write_manifest()
	print("CHECKPOINT_EXIT_CAPTURE_DONE checkpoint_active=%s exit_completed_visual=%s level_completed=%s" % [
		str(_level.get_checkpoint().is_activated()),
		str(_level.get_exit().is_completed()),
		str(_level.is_completed()),
	])
	get_tree().quit(0)


func _place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_level.get_camera().reset_smoothing()
	await _step(4)


func _wait_intro_done() -> void:
	for i: int in range(300):
		await get_tree().process_frame
		if not _level.is_intro_active():
			break
	await _step(6)


func _capture(file_name: String, note: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name))
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
	_lines.append("%s | %s" % [file_name, note])


func _step(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(CAPTURE_DIR + "/" + MANIFEST_NAME, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + MANIFEST_NAME)
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
