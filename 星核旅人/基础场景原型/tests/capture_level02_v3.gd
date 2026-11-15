extends Node

## Real-engine GUI captures for the V3 continuous / perforated level 02.
##
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_level02_v3.tscn
##
## Fixed frames from the real engine root viewport. The route uses the real
## InputMap and real key events; it is not a claim of manual continuous play.
## The visual change is presentation only: the V3 approved platform layers are
## attached as non-collision child Sprite2D slices, while the old 8x6 seams and
## 6 px beams still exist in physics. New prefixes avoid overwriting the earlier
## textured evidence.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const CAPTURE_DIR: String = "res://screenshots"
const MANIFEST_PATH: String = "res://screenshots/MANIFEST_LEVEL02_V3.txt"
const LOG_PATH: String = "res://tests/logs/level02_v3_capture.log"
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

	_lines.append("Star Core Traveler - Level 02 V3 continuous platform engine captures")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s" % DisplayServer.get_name())
	_lines.append("Logical viewport: 640x360  window: %s" % str(DisplayServer.window_get_size()))
	_lines.append("Scripted fixed frames from the running engine root viewport, not manual continuous play.")
	_lines.append("Route uses real InputMap actions and real key events; no teleport, no test force, no direct store/complete call.")
	_lines.append("Visual: approved V3 continuous coping / twin-arch bridge / unified ends, attached as non-collision Sprite2D slices under HighStep, UpperDeck and RightLedge. Legacy brown atlas drawing is off in this scene only.")
	_lines.append("Physics: the original 11 blocks, 8x6 real seams, 6 px beams, 100 px field, obstacle ray and ground are unchanged. The continuous surface is visual only.")
	_lines.append("Known reading risk: the continuous deck hides where the field can pass; it is NOT evidence that the player can fall through the seams (8 px < 12 px body, previously tested).")
	_lines.append("The debug upper frame enables the player's existing debug field overlay only to show the live ray/force direction; it does not change physics. The clean upper frame is the one for review.")
	_lines.append("Reproducible route: E release at x~100; Q during the lid; push the core through the low corridor; jump the high step and upper deck; Q opposite; walk to a real seam above the core; let the seam field move it; drop on the right; pull the core to the moved target at (520,304); E; walk to the exit at x~600.")
	_lines.append("Screenshot size: 640x360 RGBA each. States below are captured from the same running instance; the route completes with completed=true, count=1, core_x=520.")
	_lines.append("Limitations: scripted fixed frames, not manual continuous play; the editor UI was not independently opened; the 1px setting joints are a visual hint, not a widened physical force window. The 8px seams and 6px beams are still real physics. The approved high-step/right-ledge visuals extend down to y299 while their collision bottoms stay y288/y286; a player walking underneath is drawn in front of the lower face (observed frame 02b), not hidden by it, and no collision was added.")
	_lines.append("Label layout fix: CorridorLabel/UpperLabel now use y212..224 (was 246..258), clear of the standing player's ~y229 head. The pre-fix clean frame is level02_v3_03_upper_seam.png; the post-fix review frame is level02_v3_03_upper_seam_labels_fixed.png (see MANIFEST_LEVEL02_V3_LABELS_FIXED.txt). Platform pixels/physics are unchanged.")
	_lines.append("")
	_log_lines.append("Level 02 V3 continuous platform GUI capture log")
	_log_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_log_lines.append("Display: %s  window: %s  viewport: %s" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size()),
		str(get_viewport().get_visible_rect().size)
	])
	_log_lines.append("route=real InputMap/key events; no teleport/test force/direct store/complete call")
	_log_lines.append("visual=V3 approved non-collision slices; legacy Level02Block atlas drawing off in level_02.tscn")

	await _capture("level02_v3_01_start.png",
		"start: V3 continuous platform slices, real seams still in physics, 起始仓/说明碑/HUD; no combat or guard placed")

	# Extra visual evidence for the task: a normal jump in front of the new
	# dressed high-step face. The player is drawn after the platform, so this
	# frame shows whether the body/feet are readable over the stone.
	await _move_to_x(140.0, 240)
	await _tap_key(KEY_SPACE)
	await _physics(6)
	await _capture("level02_v3_02_jump_face.png",
		"jump in front of the V3 high-step face: normal running frame, no collision added to the decoration")
	await _wait_until(func() -> bool: return _player.is_on_floor(), 90)
	await _move_to_x(180.0, 120)
	await _physics(6)
	await _capture("level02_v3_02b_under_step.png",
		"standing under the V3 high-step face: the real collision bottom is still y288, the player is drawn in front of the non-collision face; no collision was added to the decoration")
	await _move_to_x(100.0, 160, true)

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
	await _capture("level02_v3_03_upper_seam.png",
		"pre-fix clean upper frame: labels at y246..258; retained as before evidence. Post-fix review frame: level02_v3_03_upper_seam_labels_fixed.png")
	_player.set_debug_enabled(true)
	await _physics(3)
	await _capture("level02_v3_04_upper_seam_debug.png",
		"same standing seam with the existing debug overlay only: ray/force passes a real 8 px seam to the core below")
	var seam_before: Vector2 = _core.global_position
	await _physics(14)
	_log_lines.append("upper seam displacement core %.2f -> %.2f force_x=%.1f" % [
		seam_before.x, _core.global_position.x, _level.get_last_force().x
	])
	_player.set_debug_enabled(false)
	_level.queue_redraw()

	# Walk the rest of the upper route, drop on the right, then pull the core
	# toward the moved target at x=520 in short real steps.
	await _move_to_x(394.0, 220)
	await _move_right_until(
		func() -> bool:
			return (
				_player.is_on_floor()
				and _player.global_position.y >= 318.0
				and _player.global_position.x >= 432.0
			),
		260
	)
	# The drop lands the player to the right of the core. Close the gap leftward
	# once so the 100 px field actually reaches it before walking it right.
	await _move_to_x(
		clampf(_core.global_position.x + 70.0, 440.0, 560.0),
		260,
		true
	)
	await _physics(20)
	var ready: bool = false
	for _step: int in range(5):
		var pull_target: float = clampf(_core.global_position.x + 70.0, 440.0, 560.0)
		await _move_to_x(pull_target, 180)
		await _physics(30)
		_log_lines.append("ground pull %d player=%s core=%s status=%s" % [
			_step, str(_player.global_position), str(_core.global_position),
			_level.get_last_status()
		])
		if bool(_level._find_store_bay().get("ok", false)):
			ready = true
			break
	if not ready:
		for _i: int in range(180):
			await get_tree().physics_frame
			if bool(_level._find_store_bay().get("ok", false)):
				ready = true
				break
	if not ready:
		push_error("capture route failed to reach a ready target seat")
		get_tree().quit(1)
		return
	# Step just right of the bay so the target art/label is not fully hidden
	# behind the player; the field may settle the core inside the same seat.
	await _move_to_x(548.0, 100)
	await _physics(10)
	await _capture("level02_v3_05_target.png",
		"target ready: core in the moved seat (520,304), player within 46 px, Chinese E-to-store prompt")

	await _tap_key(KEY_E)
	await _wait_until(func() -> bool: return _level.get_target_bay().is_locked(), 90)
	await _capture("level02_v3_06_stored.png",
		"target locked: exit report becomes ready, HUD 可以到出口; player is still beside the target, not the exit")

	await _move_to_x(600.0, 260)
	await _physics(8)
	if not _level.is_completed():
		push_error("capture route reached the exit but did not complete")
		get_tree().quit(1)
		return
	await _capture("level02_v3_07_complete.png",
		"complete: player at the exit, 第二关完成 panel")

	_write_manifest()
	_log_lines.append("FINAL completed=%s count=%d core_x=%.1f player=%s" % [
		str(_level.is_completed()), _level.get_completion_count(),
		_core.global_position.x, str(_player.global_position)
	])
	_write_capture_log()
	print("LEVEL02_V3_CAPTURE_DONE completed=%s count=%d core_x=%.1f player=%s" % [
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
		push_error("Could not write MANIFEST_LEVEL02_V3.txt")
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
	print("MANIFEST_WRITTEN %s" % MANIFEST_PATH)


func _write_capture_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write level02_v3_capture.log")
		return
	for line: String in _log_lines:
		file.store_line(line)
	file.close()
