extends Node

## Real-engine GUI capture of the clean upper-deck frame after the label
## layout fix. The route up to the standing seam is reused from the V3 capture
## script; no other old image is overwritten.
##
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_level02_v3_labels_fixed.tscn
##
## Fixed frame from the real engine root viewport. The route uses the real
## InputMap and real key events; it is not a claim of manual continuous play.
## The upper labels are now at y212..224, clear of the standing player's head;
## the approved V3 pixels, physics and all other UI are unchanged.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const CAPTURE_DIR: String = "res://screenshots"
const MANIFEST_PATH: String = "res://screenshots/MANIFEST_LEVEL02_V3_LABELS_FIXED.txt"
const LOG_PATH: String = "res://tests/logs/level02_v3_labels_fixed_capture.log"
const HIGH_STEP_Y: float = 274.0
const UPPER_Y: float = 264.0

var _level: Level02
var _player: PrototypePlayer
var _core: StarCoreCarrier
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
	_core = _level.get_core()

	_lines.append("Star Core Traveler - Level 02 V3 upper-label layout fix capture")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s" % DisplayServer.get_name())
	_lines.append("Logical viewport: 640x360  window: %s" % str(DisplayServer.window_get_size()))
	_lines.append("Scripted fixed frame from the running engine root viewport, not manual continuous play.")
	_lines.append("Route up to the standing seam uses real InputMap actions and real key events; no teleport, no test force, no direct store/complete call.")
	_lines.append("Label fix: CorridorLabel and UpperLabel moved from y246..258 to y212..224, keeping text/font/colour/horizontal offsets. Standing player head is about y229, so the labels clear the torso.")
	_lines.append("Platform visual/physics: approved V3 non-collision slices and original 11 blocks/seams/field are unchanged. No platform pixel was edited.")
	_lines.append("The pre-fix clean frame is retained as screenshots/level02_v3_03_upper_seam.png; this file is the post-fix review frame.")
	_lines.append("Limitations: scripted fixed frame, not manual continuous play; editor UI was not independently opened.")
	_lines.append("")
	_log_lines.append("Level 02 V3 upper-label layout fix GUI capture log")
	_log_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_log_lines.append("Display: %s  window: %s  viewport: %s" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size()),
		str(get_viewport().get_visible_rect().size)
	])
	_log_lines.append("route=real InputMap/key events up to the upper seam; no teleport/test force/direct store/complete")
	_log_lines.append("label_band=212..224 (pre-fix 246..258); platform pixels and physics unchanged")

	# Real route: release, same-polarity push through the 20 px throat.
	await _move_to_x(100.0, 180)
	await _tap_key(KEY_E)
	await _tap_key(KEY_Q)
	await _wait_until(func() -> bool: return _core.is_active(), 90)
	Input.action_press(&"move_right")
	for _i: int in range(900):
		await get_tree().physics_frame
		if _core.is_active() and _core.global_position.x >= 312.0:
			break
	Input.action_release(&"move_right")
	await _physics(30)

	# Climb the high short step and the V3-continuous upper deck.
	await _move_to_x(142.0, 200, true)
	var on_upper: bool = false
	for _attempt: int in range(3):
		if (
			_player.is_on_floor()
			and absf(_player.global_position.y - UPPER_Y) <= 2.0
			and _player.global_position.x >= 232.0
		):
			on_upper = true
			break
		if not (
			_player.is_on_floor()
			and absf(_player.global_position.y - HIGH_STEP_Y) <= 2.0
		):
			await _move_to_x(142.0, 200, true)
			await _try_platform_jump(HIGH_STEP_Y, 150.0, 208.0, 120)
		await _try_platform_jump(UPPER_Y, 232.0, 300.0, 120)
		if (
			_player.is_on_floor()
			and absf(_player.global_position.y - UPPER_Y) <= 2.0
			and _player.global_position.x >= 232.0
		):
			on_upper = true
			break
	if not on_upper:
		push_error("capture route failed to reach the upper route")
		get_tree().quit(1)
		return
	await _physics(20)
	_log_lines.append("upper landing player=%s core=%s" % [
		str(_player.global_position), str(_core.global_position)
	])

	# Q opposite, then walk along the real seams until the unchanged ray reaches
	# the core below. The scene is paused only after the seam field is active.
	await _tap_key(KEY_Q)
	var seam_player: Vector2 = Vector2.ZERO
	var seam_core: Vector2 = Vector2.ZERO
	var seam_scan_x: float = maxf(300.0, ceilf((_core.global_position.x + 20.0) / 10.0) * 10.0)
	while seam_scan_x <= 392.0:
		await _move_to_x(seam_scan_x, 160)
		var field: Dictionary = _level.compute_field(
			_player.global_position + Vector2(0.0, -15.0),
			_core.global_position,
			_player.is_positive(),
			_core.is_positive()
		)
		if (
			String(field["status"]) == "ATTRACT"
			and not bool(field["blocked"])
			and _player.global_position.x > _core.global_position.x
		):
			seam_player = _player.global_position
			seam_core = _core.global_position
			_log_lines.append("upper seam active player=%s core=%s dist=%.1f force=%s" % [
				str(seam_player), str(seam_core),
				float(field["distance"]), str(field["core_acceleration"])
			])
			break
		seam_scan_x += 10.0
	if seam_player.is_zero_approx():
		push_error("capture route failed to find an upper seam window")
		get_tree().quit(1)
		return
	await _capture("level02_v3_03_upper_seam_labels_fixed.png",
		"clean upper frame after the label layout fix: CorridorLabel/UpperLabel at y212..224, clear of the standing player (~y229 head), V3 platform/decor unchanged, core visible below in the 300..319 lane")
	_log_lines.append("FINAL completed=%s count=%d core_x=%.1f player=%s" % [
		str(_level.is_completed()), _level.get_completion_count(),
		_core.global_position.x, str(_player.global_position)
	])
	_write_manifest()
	_write_capture_log()
	print("LEVEL02_V3_LABELS_FIXED_CAPTURE_DONE completed=%s count=%d core_x=%.1f player=%s" % [
		str(_level.is_completed()), _level.get_completion_count(),
		_core.global_position.x, str(_player.global_position)
	])
	get_tree().quit(0)


func _capture(file_name: String, note: String) -> void:
	# Freeze the real engine frame without showing the pause overlay; this is a
	# fixed capture pose, not a pause-menu screenshot.
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name))
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
		_log_lines.append("CAPTURED %s size=%s path=%s" % [
			file_name, str(image.get_size()), ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
		])
	_lines.append("%s | %s" % [file_name, note])
	get_tree().paused = false
	await get_tree().process_frame


func _try_platform_jump(target_y: float, min_x: float, max_x: float, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	await _tap_key(KEY_SPACE)
	var landed: bool = false
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if (
			_player.is_on_floor()
			and absf(_player.global_position.y - target_y) <= 2.0
			and _player.global_position.x >= min_x
			and _player.global_position.x <= max_x
		):
			landed = true
			break
	Input.action_release(&"move_right")
	await _physics(5)
	return landed


func _move_to_x(target_x: float, max_frames: int, move_left: bool = false) -> void:
	var action: StringName = &"move_left" if move_left else &"move_right"
	Input.action_press(action)
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if move_left:
			if _player.global_position.x <= target_x:
				break
		else:
			if _player.global_position.x >= target_x:
				break
	Input.action_release(action)
	await _physics(6)


func _move_right_until(condition: Callable, max_frames: int) -> void:
	Input.action_press(&"move_right")
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if bool(condition.call()):
			break
	Input.action_release(&"move_right")
	await _physics(5)


func _wait_until(condition: Callable, max_frames: int) -> void:
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if bool(condition.call()):
			return


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _send_key(key: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.location = location
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap_key(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, true, location)
	await get_tree().process_frame
	await get_tree().physics_frame
	_send_key(key, false, location)
	await get_tree().process_frame
	await get_tree().physics_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write MANIFEST_LEVEL02_V3_LABELS_FIXED.txt")
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
	print("MANIFEST_WRITTEN %s" % MANIFEST_PATH)


func _write_capture_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write level02_v3_labels_fixed_capture.log")
		return
	for line: String in _log_lines:
		file.store_line(line)
	file.close()
