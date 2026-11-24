extends Node

## 2026-11-19 mechanic-popup demo capture.
##
## Run (windowed, NOT headless, so the real renderer produces pixels):
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://tests/mechanic_popup_20261119/capture_mechanic_demos.tscn
##
## Each clip is 24 frames at 8 fps, captured from the formal level scene in a
## real gameplay state. The crop is 256x144 at the project's 1x logical size.
## No gameplay rule, collision value, dialogue or camera limit is modified.
## Test-only setup uses each level's existing debug entry points plus key/Move
## injection through Input.parse_input_event.

const LEVEL1_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LEVEL3_SCENE: PackedScene = preload("res://scenes/level_03.tscn")

const OUT_ROOT: String = "res://tests/mechanic_popup_20261119"
const RAW_DIR: String = "res://tests/mechanic_popup_20261119/raw"
const DEMO_DIR: String = "res://assets/mechanic_demos"
const FRAME_SIZE: Vector2i = Vector2i(256, 144)
const FRAME_COUNT: int = 24
const FPS: float = 8.0

const TIP_IDS: Array[String] = [
	"polarity", "core_carry", "relay_link", "float_platform", "guard_field",
]

var _frames: Array[Image] = []
var _log_lines: Array[String] = []
var _fails: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_ensure_dirs()
	# Keep the teaching layer out of the capture run; the separate screenshot
	# harness opens the popups against these finished strips.
	for id: String in TIP_IDS:
		MechanicTips.mark_seen(id)

	_log("viewport_size=%s" % str(get_viewport().size))
	_log("window_size=%s" % str(get_window().size))
	_log("frame=%dx%d frames=%d fps=%.2f" % [FRAME_SIZE.x, FRAME_SIZE.y, FRAME_COUNT, FPS])

	await _capture_polarity()
	await _capture_core_carry()
	await _capture_relay_link()
	await _capture_float_platform()
	await _capture_guard_invalid()
	await _capture_guard_valid()

	_write_log()
	print("MECHANIC_DEMO_CAPTURE_RESULT fail=%d" % _fails.size())
	for failure: String in _fails:
		print("CAPTURE FAIL: ", failure)
	if _fails.is_empty():
		print("MECHANIC_DEMO_CAPTURE_OK")
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- A. L1 polarity / rune ------------------------------------------------

func _capture_polarity() -> void:
	var level: Level01 = LEVEL1_SCENE.instantiate() as Level01
	level.enable_start_menu = false
	add_child(level)
	await _wait(0.6)
	_hide_hud(level)
	if level.get_opening() != null:
		level.get_opening().abort()
	await _wait(0.5)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(900.0, 220.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	level.get_camera().reset_smoothing()
	await _wait(0.5)
	# Start in the attraction state: a real Q press makes the player opposite
	# the positive rune, so the rune stays in the crop while the force acts.
	_press_key(KEY_Q)
	await _wait_physics(1)
	_release_key(KEY_Q)
	await _wait(0.12)

	var rect: Rect2i = Rect2i(140, 110, FRAME_SIZE.x, FRAME_SIZE.y)
	await _begin_strip("polarity")
	for index: int in range(FRAME_COUNT):
		if index > 0:
			await _wait(1.0 / FPS)
		if index == 6 or index == 16:
			_press_key(KEY_Q)
			await _wait_physics(1)
			_release_key(KEY_Q)
		await _record_frame("polarity", rect, index)
	_finish_strip(
		"polarity",
		rect,
		"L1 high-step rune, real force field, 3 s",
		"Player starts opposite the live RuneStoneHigh (attracted); real Q at frame 6 repels and at frame 16 attracts again, so the 3 s clip keeps the same rune and player in the fixed crop."
	)
	await _free_level(level)


# --- B. L2 core take / carry ---------------------------------------------

func _capture_core_carry() -> void:
	var level: Level02 = LEVEL2_SCENE.instantiate() as Level02
	add_child(level)
	await _wait(0.6)
	_hide_hud(level)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(140.0, 320.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	level.get_camera().reset_smoothing()
	await _wait(0.4)

	# Real E release from the real start bay, then walk right so the opposite
	# polarity core follows the player (the normal transport rule).
	_press_key(KEY_E)
	await _wait_physics(2)
	_release_key(KEY_E)
	await _wait_physics(2)

	var rect: Rect2i = Rect2i(90, 200, FRAME_SIZE.x, FRAME_SIZE.y)
	await _begin_strip("core_carry")
	for index: int in range(FRAME_COUNT):
		if index > 0:
			await _wait(1.0 / FPS)
		if index == 0:
			_press_key(KEY_D)
		if index == 8:
			_release_key(KEY_D)
		if index == 16:
			_press_key(KEY_A)
		if index == 23:
			_release_key(KEY_A)
		await _record_frame("core_carry", rect, index)
	_release_key(KEY_D)
	_release_key(KEY_A)
	_finish_strip(
		"core_carry",
		rect,
		"L2 start bay, real E release + core pair force, 3 s",
		"Player releases the real start-bay core, walks right for 1 s, pauses while the core catches up, then walks left; the core keeps its own opposite polarity and follows the live pair force."
	)
	await _free_level(level)


# --- C. L2 relay unlock ---------------------------------------------------

func _capture_relay_link() -> void:
	var level: Level02 = LEVEL2_SCENE.instantiate() as Level02
	add_child(level)
	await _wait(0.6)
	_hide_hud(level)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(100.0, 320.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	level.get_camera().reset_smoothing()
	await _wait(0.4)

	# Real take + real carry to the relay bay. This setup is not captured.
	_press_key(KEY_E)
	await _wait_physics(2)
	_release_key(KEY_E)
	await _wait_physics(10)
	_press_key(KEY_D)
	var moved: int = 0
	while player.global_position.x < 390.0 and moved < 240:
		await _wait_physics(1)
		moved += 1
	_release_key(KEY_D)
	await _wait_physics(2)

	var store_ok: bool = false
	for _i: int in range(240):
		var info: Dictionary = level.call("_find_store_bay") as Dictionary
		if bool(info.get("ok", false)):
			store_ok = true
			break
		await _wait_physics(1)
	if not store_ok:
		_fails.append("relay_link: core never entered the relay seat")
		_finish_strip(
			"relay_link",
			Rect2i(230, 180, FRAME_SIZE.x, FRAME_SIZE.y),
			"L2 relay bay (setup incomplete)",
			"Setup failed to reach a valid seat; frames still show the formal level state."
		)
		await _free_level(level)
		return

	# Frame 0 starts on the real E store. The lid close and record lamp are the
	# visible part of the unlock; the roof effect is farther right than a 1x
	# 256 px crop can include, and is not faked here.
	_press_key(KEY_E)
	await _wait_physics(2)
	_release_key(KEY_E)

	var rect: Rect2i = Rect2i(230, 180, FRAME_SIZE.x, FRAME_SIZE.y)
	await _begin_strip("relay_link")
	for index: int in range(FRAME_COUNT):
		if index > 0:
			await _wait(1.0 / FPS)
		await _record_frame("relay_link", rect, index)
	_finish_strip(
		"relay_link",
		rect,
		"L2 relay bay, real store completion, 3 s",
		"Player carried the core from the start bay and stores it into the real relay bay; the clip starts on the accepted E store, then holds the real seated/unlocked bay and wall state for the remaining seconds."
	)
	await _free_level(level)


# --- D. L3 float device ---------------------------------------------------

func _capture_float_platform() -> void:
	var level: Level03 = LEVEL3_SCENE.instantiate() as Level03
	add_child(level)
	await _wait(0.9)
	_hide_hud(level)
	level.debug_restore_stage(Level03.STAGE_DEVICE)
	await _wait(0.5)
	var player: PrototypePlayer = level.get_player()

	# Player is at the real device spawn; a real E starts the float route.
	_press_key(KEY_E)
	await _wait_physics(2)
	_release_key(KEY_E)
	await _wait(1.8)

	# Walk onto the second real floating stone and let its own countdown run.
	level.debug_place_player_at(Vector2(1082.0, 248.0))
	await _wait(0.12)

	var rect: Rect2i = Rect2i(190, 130, FRAME_SIZE.x, FRAME_SIZE.y)
	await _begin_strip("float_platform")
	# 12 real frames cover the 1.1 s countdown + start of the 0.35 s shake.
	# The remaining 12 frames repeat the three on-stone shake frames instead of
	# showing the recovery black after the drop; this is the allowed "loop the
	# tail" fallback, not a fabricated motion.
	var real_frames: int = 12
	for index: int in range(real_frames):
		if index > 0:
			await _wait(1.0 / FPS)
		await _record_frame("float_platform", rect, index)
	for index: int in range(real_frames, FRAME_COUNT):
		var source_index: int = (real_frames - 4) + ((index - real_frames) % 3)
		var duplicated: Image = _frames[source_index].duplicate()
		_frames.append(duplicated)
		duplicated.save_png("%s/float_platform_%02d.png" % [RAW_DIR, index])
	_finish_strip(
		"float_platform",
		rect,
		"L3 floating stones, real countdown/shake + looped shake tail, 3 s",
		"Device was started by a real E at the device; the player stands on Block2. The first 1.5 s is the stone's real 1.1 s countdown and shake; the last 1.5 s repeats those real shake frames because the true drop leads into the recovery black, which would be an unrelated screen."
	)
	await _free_level(level)


# --- E. L3 guard: invalid damage (page 1) ---------------------------------

func _capture_guard_invalid() -> void:
	var level: Level03 = LEVEL3_SCENE.instantiate() as Level03
	add_child(level)
	await _wait(0.9)
	_hide_hud(level)
	level.debug_setup_arena_combat(1900.0, true)
	await _wait(0.4)
	var player: PrototypePlayer = level.get_player()
	var guard: L3Guard = level.get_guard()
	player.call("set_polarity_state", false)
	level.debug_place_player_at(Vector2(1955.0, 320.0))
	player.call("face_direction", 1)
	await _wait_physics(2)

	var charge_seen: bool = false
	for _i: int in range(180):
		if guard.get_state_name() == "GRAVITY_CHARGE":
			charge_seen = true
			break
		await _wait_physics(1)
	if not charge_seen:
		_fails.append("guard_invalid: guard never started its post-teaching gravity cycle")
	else:
		# Start with the field attraction, then escape the real release ring,
		# and use the recovered normal phase for the invalid shell hit.
		await _wait(0.80)

	var rect: Rect2i = Rect2i(210, 190, FRAME_SIZE.x, FRAME_SIZE.y)
	await _begin_strip("guard_invalid")
	var attacked: bool = false
	var left_held: bool = false
	var right_held: bool = false
	for index: int in range(FRAME_COUNT):
		if index > 0:
			await _wait(1.0 / FPS)
		if index == 0 or index == 1:
			# Pure attraction frames before the real Q escape.
			await _record_frame("guard_invalid", rect, index)
			continue
		if index == 2:
			# Same phase + A: the live field now repels while the player backs
			# out of the 92 px release ring.
			_press_key(KEY_Q)
			await _wait_physics(1)
			_release_key(KEY_Q)
			_press_key(KEY_A)
			left_held = true
		if index == 5 and left_held:
			_release_key(KEY_A)
			left_held = false
		if index == 6:
			# Back to opposite and approach the recovered normal guard.
			_press_key(KEY_Q)
			await _wait_physics(1)
			_release_key(KEY_Q)
			_press_key(KEY_D)
			right_held = true
		if right_held:
			var approach_dx: float = guard.global_position.x - player.global_position.x
			if approach_dx <= 45.0:
				_release_key(KEY_D)
				right_held = false
		if not attacked and not right_held:
			var state_name: String = guard.get_state_name()
			if state_name == "ACTIVE" or state_name == "NORMAL_WINDUP":
				var dx: float = guard.global_position.x - player.global_position.x
				if dx > 36.0 and dx < 60.0:
					_press_key(KEY_D)
					await _wait_physics(1)
					_release_key(KEY_D)
				elif dx > 2.0 and dx <= 36.0:
					_log("guard_invalid attack at frame %d gap=%.1f state=%s" % [
						index, dx, state_name
					])
					_press_key(KEY_J)
					await _wait_physics(1)
					_release_key(KEY_J)
					attacked = true
		if not attacked:
			_log("guard_invalid frame %d gap=%.1f state=%s player_x=%.1f guard_x=%.1f left=%s right=%s" % [
				index,
				guard.global_position.x - player.global_position.x,
				guard.get_state_name(),
				player.global_position.x,
				guard.global_position.x,
				str(left_held),
				str(right_held)
			])
		await _record_frame("guard_invalid", rect, index)
	_release_key(KEY_A)
	_release_key(KEY_D)
	var result: Dictionary = guard.get_last_result()
	if String(result.get("code", "")) != "SHELL_SHATTER":
		_fails.append("guard_invalid: expected SHELL_SHATTER, got %s" % String(result.get("code", "")))
	if level.is_recovery_active():
		_fails.append("guard_invalid: player was hit by the release ring")
	_finish_strip(
		"guard_invalid",
		rect,
		"L3 guard real field -> Q escape -> ordinary J, 3 s",
		"The first frames are the real attraction field; a real Q switches to same phase and A backs the player out of the release ring. After the guard recovers, an ordinary opposite J runs _apply_normal_break: shell scatters and reassembles with no true damage."
	)
	await _free_level(level)


# --- F. L3 guard: valid weakpoint damage (page 2) -------------------------

func _capture_guard_valid() -> void:
	var level: Level03 = LEVEL3_SCENE.instantiate() as Level03
	add_child(level)
	await _wait(0.9)
	_hide_hud(level)
	level.debug_setup_arena_combat(1900.0, true)
	await _wait(0.4)
	var player: PrototypePlayer = level.get_player()
	var guard: L3Guard = level.get_guard()
	player.call("set_polarity_state", false)
	level.debug_place_player_at(Vector2(1955.0, 320.0))
	player.call("face_direction", 1)
	await _wait_physics(2)
	var charge_seen: bool = false
	for _i: int in range(240):
		if guard.get_state_name() == "GRAVITY_CHARGE":
			charge_seen = true
			break
		await _wait_physics(1)
	if not charge_seen:
		_fails.append("guard_valid: guard never reached GRAVITY_CHARGE")

	var rect: Rect2i = Rect2i(190, 190, FRAME_SIZE.x, FRAME_SIZE.y)
	await _begin_strip("guard_valid")
	var attacked: bool = false
	for index: int in range(FRAME_COUNT):
		if index == 0:
			# Key state first: the live field pulls the opposite-phase player.
			await _record_frame("guard_valid", rect, 0)
			_press_key(KEY_D)
			continue
		for _s: int in range(8):
			await _wait_physics(1)
			if index == 1 and _s == 5:
				_release_key(KEY_D)
			if not attacked and guard.get_state_name() == "GRAVITY_CHARGE":
				var dx: float = guard.global_position.x - player.global_position.x
				if dx > 2.0 and dx <= 32.0:
					_log("guard_valid attack at frame %d gap=%.1f facing=%d" % [
						index, dx, player.get_facing()
					])
					_press_key(KEY_J)
					await _wait_physics(1)
					_release_key(KEY_J)
					_release_key(KEY_D)
					attacked = true
		if not attacked:
			_log("guard_valid frame %d gap=%.1f state=%s player_x=%.1f guard_x=%.1f" % [
				index,
				guard.global_position.x - player.global_position.x,
				guard.get_state_name(),
				player.global_position.x,
				guard.global_position.x
			])
		await _record_frame("guard_valid", rect, index)
	_release_key(KEY_D)
	var result: Dictionary = guard.get_last_result()
	if String(result.get("code", "")) != "TRUE_HIT":
		_fails.append("guard_valid: expected TRUE_HIT, got %s" % String(result.get("code", "")))
	else:
		_log("guard_valid landed TRUE_HIT; remaining=%s" % str(result.get("remaining_marks", -1)))
	_finish_strip(
		"guard_valid",
		rect,
		"L3 guard GRAVITY_CHARGE, real attraction + weakpoint J, 3 s",
		"Player is opposite and starts just inside the field; the clip shows the live pull, a real J at reach, the true hit, shell scatter/rebuild and the guard's new phase."
	)
	await _free_level(level)


# --- Capture plumbing -----------------------------------------------------

func _ensure_dirs() -> void:
	for path: String in [OUT_ROOT, RAW_DIR, DEMO_DIR]:
		var absolute: String = ProjectSettings.globalize_path(path)
		DirAccess.make_dir_recursive_absolute(absolute)


func _begin_strip(id: String) -> void:
	_frames.clear()
	await _wait(0.05)
	_log("capture %s start" % id)


func _record_frame(id: String, rect: Rect2i, index: int) -> void:
	await RenderingServer.frame_post_draw
	var viewport_image: Image = get_viewport().get_texture().get_image()
	if viewport_image == null or viewport_image.is_empty():
		_fails.append("%s: empty viewport image" % id)
		return
	if viewport_image.get_size() != Vector2i(640, 360):
		_fails.append("%s: unexpected viewport image %s" % [id, str(viewport_image.get_size())])
		return
	var region: Image = viewport_image.get_region(rect)
	if region.get_size() != FRAME_SIZE:
		region.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_NEAREST)
	_frames.append(region)
	region.save_png("%s/%s_%02d.png" % [RAW_DIR, id, index])
	if index == 0 or index == FRAME_COUNT - 1:
		viewport_image.save_png("%s/full_%s_%02d.png" % [RAW_DIR, id, index])


func _finish_strip(id: String, rect: Rect2i, source: String, note: String) -> void:
	if _frames.size() != FRAME_COUNT:
		_fails.append("%s: captured %d/%d frames" % [id, _frames.size(), FRAME_COUNT])
		return
	var strip: Image = Image.create(
		FRAME_SIZE.x * FRAME_COUNT, FRAME_SIZE.y, false, Image.FORMAT_RGBA8
	)
	for index: int in range(FRAME_COUNT):
		strip.blit_rect(_frames[index], Rect2i(0, 0, FRAME_SIZE.x, FRAME_SIZE.y), Vector2i(index * FRAME_SIZE.x, 0))
	var png_path: String = "%s/%s.png" % [DEMO_DIR, id]
	var error: Error = strip.save_png(png_path)
	if error != OK:
		_fails.append("%s: save_png failed %d" % [id, int(error)])
		return
	var json_data: Dictionary = {
		"id": id,
		"frames": FRAME_COUNT,
		"fps": FPS,
		"frame_width": FRAME_SIZE.x,
		"frame_height": FRAME_SIZE.y,
		"crop": {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y},
		"source": source,
		"capture_script": "res://tests/mechanic_popup_20261119/capture_mechanic_demos.gd",
		"captured_from": "formal level scene, real gameplay state",
		"note": note,
	}
	var json_file: FileAccess = FileAccess.open("%s/%s.json" % [DEMO_DIR, id], FileAccess.WRITE)
	if json_file == null:
		_fails.append("%s: JSON open failed" % id)
		return
	json_file.store_string(JSON.stringify(json_data, "\t"))
	json_file.close()
	_log("capture %s OK png=%s crop=%s" % [id, png_path, str(rect)])


func _hide_hud(level: Node) -> void:
	if level != null and level.has_method("get_hud"):
		var hud: Node = level.call("get_hud") as Node
		if hud != null:
			hud.visible = false


func _free_level(level: Node) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false


func _wait(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(ceil(seconds * 1000.0))
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait_physics(frames: int) -> void:
	for _i: int in range(maxi(frames, 1)):
		await get_tree().physics_frame


func _press_key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release_key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _log(line: String) -> void:
	_log_lines.append(line)
	print("CAPTURE ", line)


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("%s/capture_log.txt" % OUT_ROOT, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_log_lines) + "\n")
	file.close()
