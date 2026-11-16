extends Node

## Guard feedback capture (read-only): two real J sequences for the user to point
## at, per the 2026-11-16 demo-finish brief. No guard rule, timing, life or
## state machine is changed; this script only presses J and reads state.
##   Godot --path . res://tests/level03/capture_l3_demo_finish_guard.tscn
##
## SETUP (explicit, not a full playthrough):
##   (a) pre-teaching arena, body pinned at the guard's J reach, real Q to the
##       opposite starlight, real J. The hit window lands during the guard's
##       normal windup, so it is the ordinary invalid hit.
##   (b) post-teaching arena. The guard does its own first gravity attack; the
##       body is kept out of ring range through the charge/release and steps back
##       into J reach only during RECOVER, then presses J. That is the ordinary
##       (non-gravity) invalid hit after the teaching.
## J / Q are real key events through the Input singleton; no shatter function is
## called directly.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/level03_demo_finish_20261116/guard"

var _level: Level03 = null
var _player: L3Player = null
var _guard: L3Guard = null
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	await _new_level()
	await _seq_pre_teaching()
	await _new_level()
	await _seq_post_teaching()
	_write_manifest()
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		_level.queue_free()
		await _phys(3)
	print("GUARD_CAPTURE_DONE")
	get_tree().quit(0)


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _new_level() -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(22)
	_player = _level.get_player()
	_guard = _level.get_guard()


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(code: Key, frames: int = 2) -> void:
	_key(code, true)
	await _phys(frames)
	_key(code, false)
	await _phys(1)


## One 640x360 frame straight off the canvas.
func _frame(prefix: String, index: int) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var file_name: String = "%s_%03d.png" % [prefix, index]
	image.save_png(ProjectSettings.globalize_path(DIR + "/" + file_name))


# --- (a) pre-teaching ordinary hit ---------------------------------------

func _seq_pre_teaching() -> void:
	print("[a] pre-teaching: ordinary invalid hit -> rubble waiting")
	_level.debug_setup_pre_teaching(_guard.global_position.x - 28.0)
	await _phys(8)
	print("  SETUP pending_rubble=%s teaching=%s marks=%d player_positive=%s guard_positive=%s" % [
		str(_guard.is_waiting_teaching_rubble()), str(_guard.has_teaching_seen()),
		_guard.get_remaining_marks(), str(_player.is_positive()), str(_guard.is_positive())])
	if _player.is_positive() == _guard.is_positive():
		await _tap(KEY_Q, 2)
	print("  after Q player_positive=%s guard_positive=%s state=%s" % [
		str(_player.is_positive()), str(_guard.is_positive()), _guard.get_state_name()])
	var frames: int = 0
	for _i: int in range(2):
		await _phys(1)
	await _frame("a_pre_teaching", frames)
	frames += 1
	var audio: Node = _level.get_audio()
	if audio != null and audio.has_method("reset_last_played"):
		audio.call("reset_last_played")
	_key(KEY_J, true)
	await _phys(2)
	_key(KEY_J, false)
	await _phys(10)
	if audio != null and audio.has_method("get_last_played"):
		print("  audio after the pre-teaching hit: '%s'" % str(audio.call("get_last_played")))
	var marks_before: int = _guard.get_remaining_marks()
	for _i: int in range(100):
		await get_tree().physics_frame
		if _i % 2 == 0:
			await _frame("a_pre_teaching", frames)
			frames += 1
		if _guard.is_waiting_teaching_rubble() and _i > 60:
			break
	for _i: int in range(20):
		await get_tree().physics_frame
		if _i % 2 == 0:
			await _frame("a_pre_teaching", frames)
			frames += 1
	print("  RESULT frames=%d waiting_rubble=%s state=%s marks %d->%d hit_taken=%d" % [
		frames, str(_guard.is_waiting_teaching_rubble()), _guard.get_state_name(),
		marks_before, _guard.get_remaining_marks(), _guard.get_true_marks_taken()])
	_lines.append("a_pre_teaching_%03d..%03d | SETUP pre-teaching arena, body pinned at "
		% [0, frames - 1]
		+ "guard.x-28, real Q to opposite starlight, real J. Ordinary invalid hit: shell "
		+ "scatters, cells %d->%d (no life lost), rubble waits for the teaching."
		% [marks_before, _guard.get_remaining_marks()])


# --- (b) post-teaching ordinary hit --------------------------------------

func _seq_post_teaching() -> void:
	print("[b] post-teaching: ordinary invalid hit -> scatter + rebuild")
	_level.debug_setup_arena_combat(_guard.global_position.x - 90.0, true)
	await _phys(8)
	print("  SETUP teaching=%s state=%s marks=%d" % [
		str(_guard.has_teaching_seen()), _guard.get_state_name(), _guard.get_remaining_marks()])
	var frames: int = 0
	var marks_before: int = _guard.get_remaining_marks()
	var bar_seen: bool = false
	var j_done: bool = false
	var audio: Node = _level.get_audio()
	if audio != null and audio.has_method("reset_last_played"):
		audio.call("reset_last_played")
	for _i: int in range(360):
		await get_tree().physics_frame
		var state: String = _guard.get_state_name()
		if not j_done:
			if state == "GRAVITY_CHARGE" or state == "GRAVITY_RELEASE":
				# keep the body out of the ring so the shot is about the shell
				_level.debug_place_player_at(
					Vector2(_guard.global_position.x - 100.0, 320.0))
				if state == "GRAVITY_CHARGE":
					bar_seen = true
			elif state == "RECOVER":
				_level.debug_place_player_at(
					Vector2(_guard.global_position.x - 25.0, 320.0))
				if _player.is_positive() == _guard.is_positive():
					await _tap(KEY_Q, 2)
				_key(KEY_J, true)
				await _phys(2)
				_key(KEY_J, false)
				j_done = true
				print("  J during RECOVER: state=%s marks=%d guard_positive=%s player_positive=%s" % [
					state, _guard.get_remaining_marks(), str(_guard.is_positive()),
					str(_player.is_positive())])
		if _i % 2 == 0:
			await _frame("b_post_teaching", frames)
			frames += 1
		if j_done and _guard.get_state_name() == "ACTIVE" and _i > 200:
			break
	for _i: int in range(24):
		await get_tree().physics_frame
		if _i % 2 == 0:
			await _frame("b_post_teaching", frames)
			frames += 1
	print("  RESULT frames=%d state=%s marks %d->%d marks_taken=%d bar_seen=%s audio='%s'" % [
		frames, _guard.get_state_name(), marks_before, _guard.get_remaining_marks(),
		_guard.get_true_marks_taken(), str(bar_seen),
		str(audio.call("get_last_played")) if audio != null and audio.has_method("get_last_played") else ""])
	_lines.append("b_post_teaching_%03d..%03d | SETUP post-teaching arena. The guard's own "
		% [0, frames - 1]
		+ "gravity attack runs first (3-cell head bar visible during the charge), the body "
		+ "stays out of ring range, then steps in and really presses J during RECOVER. "
		+ "Ordinary invalid hit: shell scatters, cells %d->%d (no life lost), then rebuilds."
		% [marks_before, _guard.get_remaining_marks()])


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(DIR + "/MANIFEST_GUARD.txt", FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
		file.store_line("")
	file.close()
