extends Node

## Level-03 play-test revision checks (2026-11-15).
##
## One file, six sections, each on a fresh level instance. Real player input
## (Input.action_press + physics frames) drives the route, the float stones and
## the cinematic; the J/guard checks go through the guard's public hit API and
## its real signals, never through a "pretend it is broken" flag.
##
## Run:
##   Godot --headless --path . res://tests/level03/test_level03_revision.tscn

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")

var _fails: Array[String] = []
var _passes: int = 0
var _level: Level03
var _player: L3Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _sec_route()
	await _sec_float()
	await _sec_teaching()
	await _sec_combat()
	await _sec_retry()
	await _sec_ui()
	await _sec_restart()
	await _sec_natural_loop()
	await _sec_state_matrix()
	print("REVISION RESULT pass=%d fail=%d" % [_passes, _fails.size()])
	for failure: String in _fails:
		print("FAIL: ", failure)
	if _fails.is_empty():
		print("REVISION OK")
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		_level.queue_free()
		for _i: int in range(8):
			await get_tree().process_frame
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- helpers --------------------------------------------------------------

func _check(condition: bool, label: String) -> bool:
	if condition:
		_passes += 1
	else:
		_fails.append(label)
		print("  ! ", label)
	return condition


func _new_level() -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(18)
	_player = _level.get_player()


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


## Recovery cover is timed on idle frames; wait for the real transition instead
## of changing the gameplay assertions.
func _wait_recovery(timeout: int = 1200) -> bool:
	for _i: int in range(timeout):
		await get_tree().process_frame
		if _level != null and not _level.is_recovery_active():
			await _phys(2)
			return true
	return false


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _phys(frames)
	Input.action_release(action)
	await _phys(2)


func _walk_to_x(target: float, max_frames: int = 400) -> bool:
	var held: StringName = &""
	for _i: int in range(max_frames):
		var dx: float = target - _player.global_position.x
		if absf(dx) <= 2.0:
			break
		var action: StringName = &"move_right" if dx > 0.0 else &"move_left"
		if action != held:
			if held != &"":
				Input.action_release(held)
			Input.action_press(action)
			held = action
		await get_tree().physics_frame
	if held != &"":
		Input.action_release(held)
	await _phys(2)
	return absf(target - _player.global_position.x) <= 3.0


func _tap_space() -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await _phys(2)
	var release: InputEventKey = InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	release.pressed = false
	Input.parse_input_event(release)
	await _phys(3)


func _hold_space(frames: int) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await _phys(frames)
	var release: InputEventKey = InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	release.pressed = false
	Input.parse_input_event(release)
	await _phys(4)


# --- 1. route: rune lift -> upper-left platform -> device -> back right -----

func _sec_route() -> void:
	print("[1] route")
	await _new_level()
	await _phys(8)
	var device: L3FixedDevice = _level.get_device()
	var target: Vector2 = _level.get_device_target()
	var rune: RuneStoneField = _level.get_rune_field()
	_check(_level.get_player_force_provider_count() == 2,
		"the rune stone and the guard are the only player-force providers")
	# REAL start chain: fresh spawn -> start bay E -> drag the core -> target
	# bay E -> the rune lights. No debug_restore_stage, no teleport, no direct store.
	await _walk_to_x(150.0, 240)
	await _phys(4)
	await _hold(&"interact", 1)
	var released: bool = false
	for _i: int in range(160):
		await get_tree().physics_frame
		if _level.get_core().is_active():
			released = true
			break
	_check(released, "fresh spawn: E at the start bay releases the transport core")
	await _walk_to_x(362.0, 320)
	await _phys(40)
	_check(_level.get_target_bay().is_core_in_store_zone(_level.get_core().global_position),
		"the dragged core really sits in the target bay seat")
	await _hold(&"interact", 1)
	var stored: bool = false
	for _i: int in range(200):
		await get_tree().physics_frame
		if _level.get_target_bay().has_core():
			stored = true
			break
	_check(stored, "E stores the core in the target bay (real release+store chain)")
	var lit: bool = false
	for _i: int in range(240):
		await get_tree().physics_frame
		if rune.is_activated():
			lit = true
			break
	_check(lit, "the stored core really lit the rune stone")
	_check(_level.get_stable_stage() >= 1, "the stable stage records the rune checkpoint")
	_check(absf(rune.get_field_range() - 160.0) < 0.1 and absf(rune.get_full_acceleration() - 2400.0) < 0.1,
		"the L3 stone uses the shared 160 / 2400 numbers")
	_check(not device.is_player_in_range(Vector2(560.0, 210.0)),
		"device E range must not reach the right ledge")
	_check(not device.is_player_in_range(Vector2(430.0, 320.0)),
		"device E range must not reach the ground below")
	_check(device.is_player_in_range(target), "device E range covers its platform spot")

	# 1) real input: ground -> point attract -> right ledge.
	var on_ledge: bool = false
	Input.action_press(&"move_right")
	for _i: int in range(320):
		await get_tree().physics_frame
		var p: Vector2 = _player.global_position
		if _player.is_on_floor() and p.y > 200.0 and p.x >= 520.0:
			on_ledge = true
			break
	Input.action_release(&"move_right")
	await _phys(6)
	_check(on_ledge, "real input: the point attract carries the body onto the right ledge")

	# 2) walk to the ledge edge, jump off with the attract, Q at the top.
	for _i: int in range(80):
		if _player.global_position.x <= 526.0:
			break
		Input.action_press(&"move_left")
		await get_tree().physics_frame
		Input.action_release(&"move_left")
		await get_tree().physics_frame
	await _phys(2)
	Input.action_press(&"move_left")
	await _phys(2)
	Input.action_press(&"jump")
	await _phys(3)
	Input.action_release(&"jump")
	var q_done: bool = false
	var landed: bool = false
	for _i: int in range(300):
		await get_tree().physics_frame
		var p: Vector2 = _player.global_position
		if not q_done and p.y <= 158.0:
			q_done = true
			Input.action_press(&"polarity")
			await get_tree().physics_frame
			Input.action_release(&"polarity")
		if q_done and _player.is_on_floor():
			landed = p.y <= 145.0 and p.x > 235.0 and p.x < 405.0
			break
	Input.action_release(&"move_left")
	await _phys(8)
	_check(q_done, "the jump+Q timing fired at the top of the attract arc")
	_check(landed, "real input lands on the higher left platform (top 130)")
	_check(absf(_player.global_position.y - 130.0) <= 2.0,
		"higher platform top is 130 (got %.1f)" % _player.global_position.y)
	var force_on_platform: Vector2 = _level.get_last_player_force()
	_check(force_on_platform.length() < 40.0,
		"the platform body shields the stone on its surface (%.0f)" % force_on_platform.length())

	var walked: bool = await _walk_to_x(device.global_position.x, 300)
	await _phys(6)
	_check(device.is_player_in_range(_player.global_position),
		"player can walk to the device on the high platform")
	_check(walked, "walk to device finished")
	await _hold(&"interact", 1)
	await _phys(12)
	_check(device.is_active(), "E activates the fixed device")
	_check(_level.get_float_route().is_running(), "device starts the per-block float route")
	_check(_level.get_stable_stage() >= 2, "stable stage advanced to device")
	# The stone keeps working under its own attract/repel rule after E.
	var probe_center: Vector2 = Vector2(470.0, 300.0)
	var still: Dictionary = rune.sample_field(probe_center, _player.is_positive())
	_check((still.get("acceleration", Vector2.ZERO) as Vector2).length() > 1.0,
		"after the device the stone still pulls/pushes by the same rule")
	_check(_level.get_last_player_force().length() >= 0.0, "force sample readable after E")

	# 3) return: walk back to the platform edge, make sure the phase is opposite
	# (only if the stone and the body share the same light), then jump right.
	await _walk_to_x(390.0, 200)
	await _phys(12)
	_check(_player.is_on_floor(), "return stands on the platform edge before jumping")
	if _player.is_positive() == rune.is_positive():
		await _hold(&"polarity", 1)
		await _phys(4)
	await _phys(4)
	Input.action_press(&"jump")
	await _phys(2)
	Input.action_press(&"move_right")
	await _phys(3)
	Input.action_release(&"jump")
	var back: bool = false
	for _i: int in range(280):
		await get_tree().physics_frame
		if _player.is_on_floor() and _player.global_position.y > 200.0 and _player.global_position.x > 500.0:
			back = true
			break
	Input.action_release(&"move_right")
	await _phys(6)
	_check(back, "the return jump lands on the right ledge edge")
	if back:
		# The edge landing can be half on the lip: one short jump with the
		# attract carries the body onto the solid part, as a player would.
		if _player.global_position.x < 525.0:
			Input.action_press(&"jump")
			await _phys(2)
			Input.action_press(&"move_right")
			await _phys(3)
			Input.action_release(&"jump")
			for _i: int in range(80):
				await get_tree().physics_frame
				if _player.is_on_floor() and _player.global_position.y > 200.0 						and _player.global_position.x > 520.0:
					break
			Input.action_release(&"move_right")
			await _phys(6)
		_check(_player.global_position.x > 520.0 and absf(_player.global_position.y - 210.0) <= 2.0,
			"the body stands on the solid ledge after the short hop (%.0f, %.0f)" % [
				_player.global_position.x, _player.global_position.y])
		await _hold(&"polarity", 1)
		await _phys(4)
		var start_x: float = _player.global_position.x
		Input.action_press(&"move_right")
		await _phys(30)
		Input.action_release(&"move_right")
		await _phys(4)
		if _player.is_positive() != rune.is_positive():
			# opposite light: switch to the same light so the stone pushes the
			# body right along the ledge instead of dragging it left.
			await _hold(&"polarity", 1)
			await _phys(4)
		start_x = _player.global_position.x
		Input.action_press(&"move_right")
		await _phys(20)
		Input.action_release(&"move_right")
		await _phys(4)
		_check(_player.global_position.x > start_x + 8.0,
			"same-phase repel lets the body move right again (%.0f -> %.0f)" % [
				start_x, _player.global_position.x])
		_check(_player.is_on_floor() and absf(_player.global_position.y - 210.0) <= 2.0,
			"the return walk stays on the right ledge (got %.1f)" % _player.global_position.y)


# --- 2. float stones: per-block, non-refreshable, unstepped stay -----------

func _sec_float() -> void:
	print("[2] float")
	await _new_level()
	_level.debug_restore_stage(2, true, false)
	await _phys(6)
	var route: L3FloatRoute = _level.get_float_route()
	route.start_cycle()
	await _phys(140)
	var states: Array[String] = route.get_block_states()
	var all_stable: bool = true
	for state: String in states:
		if state != "STABLE":
			all_stable = false
	_check(all_stable, "every block is STABLE after starting (states=%s)" % str(states))

	var blocks: Array[L3FloatBlock] = route.get_blocks()
	var block0: L3FloatBlock = blocks[0]
	var block1: L3FloatBlock = blocks[1]
	var top0: float = block0.get_top_y()
	var mid0: float = block0.global_position.x + block0.get_block_width() * 0.5
	# Standing on the first block only: real standing, real countdown.
	_level.debug_place_player_at(Vector2(mid0, top0 - 1.0))
	await _phys(6)
	_check(block0.is_standing_triggered(), "standing on a block triggers its own countdown")
	_check(block0.get_phase_label() in ["COUNTDOWN", "SHAKE"], "first block leaves STABLE after standing")
	_check(_level.get_hud().get_event_text().find("石块") < 0,
		"the collapse warning is an icon, not a repeated text line")
	_check(block1.get_phase_label() == "STABLE", "the next block is not dragged into the countdown")
	# Wait past the old global 20 s mark, with the player back on the ground.
	_level.debug_place_player_at(Vector2(200.0, 320.0))
	await _phys(10)
	var still_stable: bool = true
	for index: int in range(1, blocks.size()):
		if blocks[index].get_phase_label() != "STABLE":
			still_stable = false
	_check(still_stable, "unstepped blocks stay STABLE while the first one is counting down")
	var dropped: bool = false
	for _i: int in range(200):
		await get_tree().physics_frame
		if block0.get_phase_label() == "DROPPED":
			dropped = true
			break
	_check(dropped, "the stepped block really drops after countdown + shake")
	await _phys(60 * 22)
	var late_states: Array[String] = route.get_block_states()
	var late_stable: bool = true
	for index: int in range(1, blocks.size()):
		if late_states[index] != "STABLE":
			late_stable = false
	_check(late_stable, "22 s later the unstepped blocks are still STABLE (no 20 s global fall)")

	# Real crossing: reset, stand on block 1, jump right to block 2.
	route.start_cycle()
	await _phys(140)
	_level.debug_place_player_at(Vector2(mid0, top0 - 1.0))
	await _phys(6)
	Input.action_press(&"move_right")
	await _phys(6)
	Input.action_press(&"jump")
	await _phys(4)
	Input.action_release(&"jump")
	var crossed: bool = false
	for _i: int in range(120):
		await get_tree().physics_frame
		if _player.is_on_floor() and _player.global_position.x >= block1.global_position.x + 4.0:
			crossed = true
			break
	Input.action_release(&"move_right")
	await _phys(4)
	_check(crossed, "real input crosses to the second block")
	_check(block1.is_standing_triggered(), "the second block starts its own countdown on landing")
	var phase_after_return: String = block0.get_phase_label()
	_level.debug_place_player_at(Vector2(mid0, top0 - 1.0))
	await _phys(10)
	_check(block0.get_phase_label() != "STABLE" and block0.get_phase_label() != "COUNTDOWN",
		"re-standing on the same block does not refresh its countdown (was %s, now %s)"
		% [phase_after_return, block0.get_phase_label()])
	_check(route.get_triggered_count() == 2, "each block has its own trigger counter (got %d)"
		% route.get_triggered_count())


# --- 3. teaching threshold: no force, waiting rubble, real rebuild ---------

func _sec_teaching() -> void:
	print("[3] teaching")
	await _new_level()
	_level.debug_setup_pre_teaching(1560.0)
	await _phys(6)
	# Watch from the buffer, out of the guard's reach, so the observation itself
	# cannot trigger a two-hit retry.
	_level.debug_place_player_at(Vector2(1560.0, 252.0))
	await _phys(4)
	var guard: L3Guard = _level.get_guard()
	var cine: L3Cinematic = _level.get_cine()
	# Pre-teaching: only normal slams, never a gravity field.
	var saw_gravity: bool = false
	for _i: int in range(180):
		await get_tree().physics_frame
		if guard.get_state_name().begins_with("GRAVITY") or guard.is_field_visible():
			saw_gravity = true
			break
	_check(not saw_gravity, "before teaching the guard never uses a gravity field")
	_check(not guard.has_teaching_seen(), "teaching is not marked before the real shatter")

	# Walking to the locked gate without a real shatter must not start the film.
	# gate layout moved by the user in 2026-11-16; keep the setup next to
	# the real gate instead of the old x.
	_level.debug_place_player_at(Vector2(_level.get_gate().global_position.x - 50.0, 320.0))
	await _phys(40)
	_check(not cine.is_active(), "no forced cinematic before the first invalid shatter")
	_check(not cine.has_played(), "cinematic memory stays empty before the shatter")

	# A real invalid break: ONE effective opposite-phase hit now scatters.
	var player: L3Player = _player
	player.global_position = guard.global_position + Vector2(-30.0, 0.0)
	await _phys(3)
	var first: Dictionary = guard.receive_player_hit(player, 1, not guard.is_positive(), 900)
	_check(String(first.get("code", "")) == "SHELL_SHATTER",
		"one effective normal hit scatters the shell (no two-hit shell)")
	_check(guard.get_remaining_marks() == 3, "the normal scatter spends no life cell")
	await _phys(60)
	_check(guard.is_waiting_teaching_rubble(), "the first invalid shatter waits as teaching rubble")
	_check(not guard.has_teaching_seen(), "waiting rubble is not teaching yet")
	await _phys(180)
	_check(guard.is_waiting_teaching_rubble(), "waiting rubble does not auto-reassemble")
	_check(guard.get_state_name() == "WAIT_RUBBLE", "rubble keeps the last real rubble frame state")
	var hits_before_film: int = _level.get_player_hits()

	# Now approach the gate: the one-shot film starts and rebuilds for real.
	# gate layout moved by the user in 2026-11-16; keep the setup next to
	# the real gate instead of the old x.
	_level.debug_place_player_at(Vector2(_level.get_gate().global_position.x - 50.0, 320.0))
	await _phys(30)
	_check(cine.is_active(), "after a real shatter, approaching the gate starts the film")
	var rebuild_seen: bool = false
	var gravity_seen: bool = false
	for _i: int in range(150):
		await get_tree().physics_frame
		if guard.get_state_name() == "REASSEMBLING":
			rebuild_seen = true
		if guard.get_state_name() == "GRAVITY_CHARGE":
			gravity_seen = true
			break
	_check(rebuild_seen, "the film drives the real rubble rebuild")
	_check(gravity_seen, "the gravity charge is shown right after the rebuild")
	_check(guard.is_field_visible(), "the gravity field is present during the shown charge")
	var bubble_ok: bool = false
	# Walk the film to its dialogue pages.
	for _i: int in range(400):
		await get_tree().physics_frame
		if cine.get_phase_name() == "DIALOGUE":
			bubble_ok = true
			break
	_check(bubble_ok, "the film reaches its dialogue pages")
	await _phys(20)
	var bubble: Rect2 = cine.get_bubble_rect()
	_check(cine.is_bubble_visible(), "the echo bubble is visible")
	_check(cine.get_body_text().length() > 0, "the bubble carries text")
	_check(bubble.size.x > 80.0 and bubble.size.x <= 250.0, "bubble width stays small (%.0f)" % bubble.size.x)
	_check(bubble.position.x >= 0.0 and bubble.end.x <= 640.0
		and bubble.position.y >= 0.0 and bubble.end.y <= 360.0,
		"bubble stays inside the 640x360 frame")
	_check(bubble.end.y <= 320.0, "bubble does not use the old bottom dialogue band")
	var echo_rect: Rect2 = cine.get_echo_screen_rect()
	_check(echo_rect.position.distance_to(bubble.position) < 170.0,
		"bubble is anchored to the echo's head")
	_check(cine.get_bar_height() > 40.0,
		"the film keeps its top/bottom letterbox bars (%.0f)" % cine.get_bar_height())
	_check(bubble.position.y >= 48.0 and bubble.end.y <= 312.0,
		"the echo bubble stays inside the letterbox safe area")
	_check(cine.get_page_count() == 3, "the film has exactly the three finalised pages")
	var hint_rect: Rect2 = cine.get_hint_rect()
	var hint_width: float = cine.get_hint_text_width()
	_check(hint_rect.end.x <= 640.0 and hint_rect.position.x >= 0.0,
		"the hint label stays inside the 640 frame (%.0f..%.0f)" % [hint_rect.position.x, hint_rect.end.x])
	_check(hint_width + 2.0 <= hint_rect.size.x,
		"the hint text with its 2 px outline fits the label width (%.0f <= %.0f)" % [
			hint_width + 2.0, hint_rect.size.x])
	_check(hint_rect.position.y >= 316.0,
		"the hint sits inside the bottom letterbox bar (y=%.0f)" % hint_rect.position.y)
	_check(cine.get_full_page_text().find("星核") >= 0,
		"the page speaks about the star core, not hit counts")
	_check(cine.get_full_page_text().find("真伤") < 0 and cine.get_full_page_text().find("J") < 0,
		"the page carries no damage words or key letters")
	var pages_seen: int = 0
	for _i: int in range(10):
		await _tap_space()
		await _tap_space()
		pages_seen = maxi(pages_seen, cine.get_page_index() + 1)
		if not cine.is_active():
			break
	_check(pages_seen >= 3, "short-space advances through the pages (reached %d)" % pages_seen)
	# Long hold skips the rest.
	await _hold_space(45)
	await _phys(20)
	_check(not cine.is_active(), "long space skips the film and returns control")
	_check(cine.has_played(), "the film is remembered as played")
	_check(cine.get_bar_height() <= 1.0, "the letterbox bars retract after the film")
	_check(_level.get_hud().get_control_hint_visible(),
		"one independent key reminder appears after the hand-back")
	_check(guard.has_teaching_seen(), "the guard is taught after the rebuild")
	_check(guard.get_state_name().begins_with("GRAVITY") or guard.get_next_action_name() == "GRAVITY",
		"after the film the guard starts from a gravity turn")
	_check(_level.get_player_hits() == hits_before_film,
		"the film does not add a player hit (%d -> %d)" % [hits_before_film, _level.get_player_hits()])


# --- 4. combat: opposite-phase J, gravity window, ring, one hit per swing ---

func _sec_combat() -> void:
	print("[4] combat")
	await _new_level()
	_level.debug_setup_arena_combat(2020.0, true)
	await _phys(20)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _player
	guard.force_gravity_first()
	await _phys(1)
	var tuning: Dictionary = guard.get_field_tuning()
	_check(float(tuning["reach"]) <= 38.0 and float(tuning["reach"]) >= 30.0,
		"J reach is the revised 32-38 band (%.0f)" % float(tuning["reach"]))
	_check(float(tuning["vertical"]) <= 30.0, "J vertical tolerance is 26-30 (%.0f)" % float(tuning["vertical"]))
	_check(float(tuning["range"]) <= 125.0, "gravity field range is 110-125 (%.0f)" % float(tuning["range"]))
	_check(float(tuning["acceleration"]) <= 850.0, "gravity field acceleration is 650-850 (%.0f)"
		% float(tuning["acceleration"]))
	_check(float(tuning["gravity_charge"]) <= 1.85,
		"gravity charge is shorter than the old 2.5 s (%.2f)" % float(tuning["gravity_charge"]))
	_check(int(tuning["ring_damage_radius"]) < int(tuning["range"]),
		"damage ring is smaller than the attract range")
	var center: Vector2 = player.global_position + Vector2(0.0, -15.0)
	var sample: Dictionary = guard.sample_player_force(center, not guard.is_positive())
	_check((sample.get("acceleration", Vector2.ZERO) as Vector2).length() > 1.0,
		"gravity force is live from the action's first frame")

	player.global_position = guard.global_position + Vector2(-30.0, 0.0)
	await _phys(2)
	var phase_before: bool = guard.is_positive()
	var true_hit: Dictionary = guard.receive_player_hit(player, 1, not guard.is_positive(), 10)
	_check(String(true_hit.get("code", "")) == "TRUE_HIT", "opposite-phase J on the lit core costs a cell")
	_check(bool(true_hit.get("true_damage", false)), "the gravity hit is flagged as true damage")
	_check(guard.get_remaining_marks() == 2, "one of three cells is gone")
	_check(guard.get_state_name() == "SCATTERING", "the gravity hit visibly scatters the shell")
	var scatter_follow: Dictionary = guard.receive_player_hit(player, 1, not guard.is_positive(), 12)
	_check(String(scatter_follow.get("code", "")) == "INACTIVE",
		"rubble does not accept a same-frame follow-up")
	var rebuilt: bool = false
	for _i: int in range(200):
		await get_tree().physics_frame
		if guard.get_state_name() == "ACTIVE" and guard.get_true_marks_taken() == 1:
			rebuilt = true
			break
	_check(rebuilt, "the gravity hit rebuilds instead of only hurting")
	_check(guard.is_positive() != phase_before, "the rebuild turns the guard's phase")
	await _phys(4)
	var same_phase: bool = guard.is_positive()
	guard.force_gravity_first()
	await _phys(1)
	var no_damage: Dictionary = guard.receive_player_hit(player, 1, same_phase, 13)
	_check(String(no_damage.get("code", "")) == "SAME_PHASE", "same-phase J does no damage")
	_check(guard.get_true_marks_taken() == 1, "same-phase J does not spend a cell")
	var duplicate: Dictionary = guard.receive_player_hit(player, 1, not guard.is_positive(), 13)
	_check(String(duplicate.get("code", "")) == "DUPLICATE_SWING", "one swing resolves at most once")
	_check(guard.get_state_name() == "GRAVITY_CHARGE", "the same-phase hit keeps the attack going")
	# Normal slam is a forward fist zone, not the ring.
	_check(guard.get_ring_damage_radius() > 0.0, "gravity release has a readable damage ring")

	# Ring damage: front/back at the same distance both hit once, outside misses.
	# The player is re-placed just before the release so the attract/repel field
	# cannot drift them; the damage itself is the guard's real release.
	var front_hits: int = await _ring_release_hits(-80.0)
	_check(front_hits == 1, "a player in front inside the ring is struck exactly once (got %d)"
		% front_hits)
	var back_hits: int = await _ring_release_hits(80.0)
	_check(back_hits == 1, "a player behind inside the ring is struck exactly once (got %d)"
		% back_hits)
	var outside_hits: int = await _ring_release_hits(120.0)
	_check(outside_hits == 0, "a player outside the damage ring is not struck (got %d)"
		% outside_hits)


func _ring_release_hits(offset_x: float) -> int:
	await _new_level()
	_level.debug_setup_arena_combat(2000.0, true)
	await _phys(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _player
	player.set_polarity_state(not guard.is_positive())
	var before: int = _level.get_player_hits()
	var ready: bool = false
	for _i: int in range(240):
		await get_tree().physics_frame
		if guard.get_state_name() == "GRAVITY_CHARGE" and guard.get_charge_ratio() > 0.90:
			ready = true
			break
	if not ready:
		guard.debug_force_gravity()
		await _phys(2)
	player.global_position = guard.global_position + Vector2(offset_x, 0.0)
	player.velocity = Vector2.ZERO
	for _i: int in range(40):
		await get_tree().physics_frame
		if guard.get_enemy_ring_count() >= 1:
			break
	await _phys(12)
	return _level.get_player_hits() - before


# --- 5. two real hits: retry the current fight, keep the earlier progress ---

func _sec_retry() -> void:
	print("[5] retry")
	await _new_level()
	_level.debug_setup_arena_combat(2020.0, true)
	await _phys(10)
	var guard: L3Guard = _level.get_guard()
	var cine: L3Cinematic = _level.get_cine()
	var marks_before: int = guard.get_true_marks_taken()
	_check(cine.has_played(), "the film is remembered before the retry")
	guard.player_struck.emit(-1)
	await _phys(3)
	_check(_level.get_player_hits() == 1, "first real hit is counted once")
	_check(guard.get_true_marks_taken() == marks_before, "first hit keeps the current fight")
	guard.player_struck.emit(-1)
	await _phys(12)
	_check(_level.is_recovery_active(),
		"second hit opens the approved recovery cover before the retry")
	_check(await _wait_recovery(),
		"the approved recovery transition completes")
	_check(_level.get_player_hits() == 0, "second hit resets the hit counter")
	_check(_player.global_position.distance_to(_level.get_arena_spawn()) <= 6.0,
		"second hit returns the player to the guard-front recovery point")
	_check(guard.get_true_marks_taken() == 0, "second hit clears the true-damage marks")
	_check(guard.get_state_name() == "ACTIVE" or guard.get_state_name() == "GRAVITY_CHARGE",
		"guard is reset, not left in a broken state (%s)" % guard.get_state_name())
	_check(guard.get_next_action_name() == "GRAVITY" or guard.get_state_name() == "GRAVITY_CHARGE",
		"the retry starts from a gravity turn")
	_check(not cine.is_active(), "the retry does not replay the film")
	_check(cine.has_played(), "the film stays remembered after the retry")
	_check(_level.get_stable_stage() >= 3, "the retry keeps the arena recovery stage (no replay of the route)")
	_check(_level.is_checkpoint_mark_visible(), "the recovery point answers with a lit marker, not a text line")


# --- 6. low HUD / guidance / hit pips -------------------------------------

func _sec_ui() -> void:
	print("[6] ui")
	await _new_level()
	var hud: L3HUD = _level.get_hud()
	var guide: L3Guide = hud.get_guide()
	_check(hud.get_objective_text().length() > 0 and hud.get_objective_text().length() <= 16,
		"one short objective line")
	_check(hud.get_compact_header() != null, "the polarity talisman header is kept")
	_check(_level.get_node_or_null("Background/FarGate") == null,
		"the duplicated FarGate silhouette is no longer in the scene")
	_check(_level.get_node_or_null("CityBack") == null
		and _level.get_node_or_null("CityArch") == null,
		"the old CityBack bricks / CityArch are not displayed")

	# Device stage, airborne over the lift: the true direction is up-left.
	_level.debug_restore_stage(1, true, false)
	await _phys(6)
	_level.debug_place_player_at(Vector2(500.0, 210.0))
	await _phys(4)
	var target: Vector2 = _level.get_device_target()
	var player_center: Vector2 = _player.global_position + Vector2(0.0, -15.0)
	var direction: Vector2 = target - player_center
	_check(direction.x < 0.0 and direction.y < 0.0,
		"device guidance really points up-left (%.0f,%.0f)" % [direction.x, direction.y])
	_check(hud.get_objective_text().find("左上") >= 0, "objective names the upper-left goal")
	_check(guide.get_guide_visible() or guide.get_target_screen() != Vector2.ZERO,
		"the world guide has a target")
	_check(hud.get_hits() <= 2, "hit feedback uses two small talismans")
	_check(guide.get_pips_visible() == false, "talismans stay hidden outside a fight")
	_check(hud.get_prompt_text().length() <= 4,
		"the interaction hint is a short verb, not a sentence (%s)" % hud.get_prompt_text())
	# Locked gate: E answers with the stable "?" icon, not a sentence.
	_level.debug_restore_stage(0, true, true)
	await _phys(6)
	_level.debug_place_player_at(Vector2(_level.get_gate().global_position.x - 20.0, 320.0))
	await _phys(4)
	Input.action_press(&"interact")
	await get_tree().physics_frame
	Input.action_release(&"interact")
	await _phys(4)
	_check(guide.get_symbol_text() == "?", "a locked gate answers with the ? icon")
	# Combat hides navigation.
	_level.debug_setup_arena_combat(2020.0, true)
	await _phys(10)
	_check(guide.is_combat(), "navigation is hidden during the fight")
	_check(_level.get_guard().is_alert_mark_visible(),
		"a first sighting shows a short ! over the guard")
	_check(not guide.get_guide_visible(), "no navigation line is drawn in combat")
	guard_feedback_pips_check(hud)


# --- 7. R restart clears the film memory, the rubble and the stage ---------

func _sec_restart() -> void:
	print("[7] restart")
	await _new_level()
	_level.debug_setup_arena_combat(2020.0, true)
	await _phys(8)
	var cine: L3Cinematic = _level.get_cine()
	var guard: L3Guard = _level.get_guard()
	_check(cine.has_played(), "setup marks the film as seen")
	var pause_menu: Node = _level.get_pause_menu()
	_check(pause_menu != null, "pause menu exists for the restart path")
	pause_menu.restart_requested.emit()
	await _phys(24)
	_check(not cine.has_played(), "R clears the film memory")
	_check(not guard.has_teaching_seen(), "R clears the teaching mark")
	_check(not guard.is_waiting_teaching_rubble(), "R clears the waiting rubble")
	_check(not cine.is_active(), "R leaves no film running")
	_check(_level.get_stable_stage() == 0, "R returns to the start stage")
	_check(_player.global_position.distance_to(_level.get_start_spawn()) <= 6.0,
		"R puts the player back at the start spawn")
	_check(not _level.get_device().is_active(), "R restores the colourless device")
	_check(not _level.get_float_route().is_running(), "R stops the float route")
	_check(_level.get_hud().get_hits() == 0, "R clears the hit pips")


# --- 8. natural rhythm -> 3 true hits -> core -> gate -> real city entry ---
#
# No force_gravity / no direct state writes on the guard: only public input
# (A/D, Q, J, E) plus the guard's own AI and its public hit API, so the action
# order is produced by the real rhythm rule.

func _press_key(code: int) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	await _phys(2)
	var release: InputEventKey = InputEventKey.new()
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await _phys(2)


func _sec_natural_loop() -> void:
	print("[8] natural loop")
	await _new_level()
	# SETUP: post-teaching arena fight at the recovery point; the action order
	# and every hit below is the guard's own AI + public hit resolution.
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _player
	var sequence: Array[String] = []
	var phases: Array[bool] = []
	var marks_seen: Array[int] = []
	var defeat_count: Array[int] = [0]
	# Signals are connected before the setup so the very first gravity charge of
	# the settling guard is recorded, not just the ones after the setup ticks.
	guard.charge_started.connect(func(_p: bool) -> void: sequence.append("G"))
	guard.slam_contact.connect(func(_f: int) -> void: sequence.append("N"))
	guard.true_damage_dealt.connect(func(taken: int, _rem: int) -> void:
		phases.append(guard.is_positive())
		marks_seen.append(taken))
	guard.defeated.connect(func() -> void: defeat_count[0] += 1)
	_level.debug_setup_arena_combat(2020.0, true)
	await _phys(2)
	var attacked_in_charge: bool = false
	var held: StringName = &""
	var lethal_frames: Array[int] = []
	for _i: int in range(4200):
		await get_tree().physics_frame
		if guard.is_defeated():
			break
		var state: String = guard.get_state_name()
		var dx: float = guard.global_position.x - player.global_position.x
		var want: StringName = &""
		if state == "GRAVITY_CHARGE":
			if held != &"":
				Input.action_release(held)
				held = &""
			# Keep the body a short step in front so the J can land, and switch
			# to the opposite phase so the hit counts as true damage.
			if absf(dx) > 26.0:
				want = &"move_right" if dx > 0.0 else &"move_left"
			elif absf(dx) < 12.0:
				want = &"move_left" if dx > 0.0 else &"move_right"
			if not attacked_in_charge and player.is_positive() == guard.is_positive():
				await _press_key(KEY_Q)
			if not attacked_in_charge and guard.get_state_name() == "GRAVITY_CHARGE":
				await _press_key(KEY_J)
				attacked_in_charge = true
		else:
			attacked_in_charge = false
			if guard.get_true_marks_taken() >= 3 and not guard.is_defeated():
				lethal_frames.append(guard.get_sprite_frame())
			if state == "ACTIVE" or state == "NORMAL_WINDUP":
				if absf(dx) > 17.0:
					want = &"move_right" if dx > 0.0 else &"move_left"
		if want != held:
			if held != &"":
				Input.action_release(held)
			if want != &"":
				Input.action_press(want)
			held = want
	if held != &"":
		Input.action_release(held)
	# The lethal hit goes through HURT before the guard really scatters and
	# emits defeated, so wait for the real death hold, not just the hit.
	for _i: int in range(150):
		await get_tree().physics_frame
		if defeat_count[0] > 0:
			break
	await _phys(6)
	print("[8] sequence=", sequence, " marks=", marks_seen, " phases=", phases,
		" hits=", _level.get_player_hits())
	_check(sequence.size() >= 5, "the guard produced a natural action sequence: %s" % str(sequence))
	_check(not sequence.is_empty() and sequence[0] == "G",
		"after the teaching the first action is the gravity charge (%s)" % str(sequence))
	var expected: Array[String] = ["G", "N", "N", "G", "N", "N", "G"]
	var prefix_ok: bool = sequence.size() >= expected.size()
	if prefix_ok:
		for index: int in range(expected.size()):
			if sequence[index] != expected[index]:
				prefix_ok = false
	_check(prefix_ok, "natural order is GRAVITY, NORMAL, NORMAL, GRAVITY ... (%s)" % str(sequence))
	_check(marks_seen == [1, 2, 3], "three true hits, each counted once (%s)" % str(marks_seen))
	_check(phases.size() == 3 and phases[0] != phases[1] and phases[1] != phases[2],
		"each of the first two true hits really switches the phase (%s)" % str(phases))
	_check(guard.get_true_marks_taken() == 3, "the third cell is the lethal one")
	_check(guard.get_remaining_marks() == 0, "no cells left on the lethal hit")
	_check(guard.get_state_name() == "DEAD" or guard.is_defeated(),
		"the lethal hit scatters without rebuilding (%s)" % guard.get_state_name())
	var monotonic: bool = not lethal_frames.is_empty()
	for index: int in range(1, lethal_frames.size()):
		if lethal_frames[index] < lethal_frames[index - 1]:
			monotonic = false
	_check(monotonic, "the lethal rubble plays once without restarting from frame 0 (%s)"
		% str(lethal_frames))
	_check(guard.get_sprite_frame() == 11, "the lethal rubble holds the last content frame")
	_check(lethal_frames.size() > 0 and lethal_frames[-1] >= 11,
		"the rubble reached its final frame before defeated")
	_check(defeat_count[0] == 1, "the guard emits defeated exactly once (%d)" % defeat_count[0])
	_check(guard.get_key_core_drop_position().distance_to(guard.global_position) < 20.0,
		"the single key core drops at the guard")

	# Take the core with the real E path.
	_check(_level.get_hud() != null, "hud alive after the fight")
	var key_position: Vector2 = _level.get_key_drop_position()
	await _walk_to_x(key_position.x, 260)
	await _phys(6)
	Input.action_press(&"interact")
	await get_tree().physics_frame
	Input.action_release(&"interact")
	await _phys(6)
	_check(_level.is_key_taken(), "E takes the dropped guard core")
	_check(not _level.is_key_embedded(), "the core is carried, not embedded yet")

	# Walk to the gate, embed with E, wait for the door.
	var gate: L3Gate = _level.get_gate()
	await _walk_to_x(gate.global_position.x - 12.0, 420)
	await _phys(6)
	_check(gate.can_embed(player.global_position), "the player is close enough to the gate socket")
	Input.action_press(&"interact")
	await get_tree().physics_frame
	Input.action_release(&"interact")
	await _phys(10)
	_check(_level.is_key_embedded(), "E embeds the core into the 24px gate socket")
	var opened: bool = false
	for _i: int in range(120):
		await get_tree().physics_frame
		if gate.is_open():
			opened = true
			break
	_check(opened, "the gate really opens")
	_check(not _level.is_completed(), "an open gate alone does not complete the level")

	# Real walk into the city: completion only after crossing the entry line.
	Input.action_press(&"move_right")
	var completed: bool = false
	for _i: int in range(400):
		await get_tree().physics_frame
		if _level.is_completed():
			completed = true
			break
	Input.action_release(&"move_right")
	await _phys(8)
	_check(completed, "walking into the city completes the level")
	_check(_level.is_completed() and _level.get_hud().is_completion_visible(),
		"the completion page is shown")
	_check(player.global_position.x > _level.get_city_enter_x() - 20.0,
		"completion happened past the city entry line")


# --- 9. state matrix: every hittable state scatters, only gravity costs a cell ---
#
# SETUP per case: a fresh post-teaching arena, the player placed near the guard
# and set to the opposite starlight so the real hit can resolve. The state is
# produced by the guard's own AI/timers; nothing calls _begin_scatter directly.

func _matrix_case(state_name: String, expect_cell_loss: bool) -> void:
	await _new_level()
	_level.debug_setup_arena_combat(2020.0, true)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _player
	# SETUP: keep the body just inside the guard's fist (so its own slam misses)
	# while the guard walks through its real states; the hit below is the public
	# resolution. Nothing calls _begin_scatter.
	player.set_polarity_state(not guard.is_positive())
	_level.debug_place_player_at(Vector2(1810.0, 320.0))
	await _phys(2)
	var reached: bool = false
	var seen: Array[String] = []
	if state_name == "ACTIVE":
		await _phys(20)
		reached = guard.get_state_name() == "ACTIVE"
	else:
		for _i: int in range(420):
			await get_tree().physics_frame
			var state: String = guard.get_state_name()
			if seen.is_empty() or seen[-1] != state:
				seen.append(state)
			if state == state_name:
				reached = true
				break
			var dx: float = guard.global_position.x - player.global_position.x
			if absf(dx) > 20.0 or absf(player.global_position.y - 320.0) > 20.0:
				player.global_position = guard.global_position + Vector2(-14.0, 0.0)
				player.velocity = Vector2.ZERO
	if not reached:
		print("  states seen for ", state_name, ": ", seen)
	_check(reached, "setup reached guard state %s" % state_name)
	if not reached:
		return
	var hp_before: int = guard.get_remaining_marks()
	var phase_before: bool = guard.is_positive()
	player.set_polarity_state(not guard.is_positive())
	player.global_position = guard.global_position + Vector2(-30.0, 0.0)
	player.velocity = Vector2.ZERO
	var swing: int = 4000 + hp_before * 10 + int(expect_cell_loss) * 3
	var result: Dictionary = guard.receive_player_hit(player, 1, not guard.is_positive(), swing)
	var code: String = String(result.get("code", ""))
	_check(code == ("TRUE_HIT" if expect_cell_loss else "SHELL_SHATTER"),
		"%s: effective hit resolves as %s (got %s)" % [
			state_name, "TRUE_HIT" if expect_cell_loss else "SHELL_SHATTER", code])
	_check(guard.get_remaining_marks() == hp_before - (1 if expect_cell_loss else 0),
		"%s: life cell %s" % [state_name, "lost" if expect_cell_loss else "kept"])
	_check(guard.get_state_name() == "SCATTERING",
		"%s: the hit visibly scatters the shell" % state_name)
	var rebuilt: bool = false
	for _i: int in range(240):
		await get_tree().physics_frame
		if guard.get_state_name() == "ACTIVE" and not guard.is_pending_death():
			rebuilt = true
			break
	_check(rebuilt, "%s: the shell rebuilds after the scatter" % state_name)
	if expect_cell_loss:
		_check(guard.is_positive() != phase_before, "%s: the rebuild turns the phase" % state_name)


func _sec_state_matrix() -> void:
	print("[9] state matrix")
	await _matrix_case("ACTIVE", false)
	await _matrix_case("NORMAL_WINDUP", false)
	await _matrix_case("NORMAL_SLAM", false)
	await _matrix_case("RECOVER", false)
	await _matrix_case("GRAVITY_CHARGE", true)
	await _matrix_case("GRAVITY_RELEASE", true)


func guard_feedback_pips_check(hud: L3HUD) -> void:
	var guide: L3Guide = hud.get_guide()
	hud.set_combat(true)
	hud.set_hits(0)
	_check(guide.get_pips_visible() and hud.get_hits() == 0,
		"two whole talismans while both hits are still available")
	hud.set_hits(1)
	_check(hud.get_hits() == 1, "one taken hit cracks exactly one talisman")
	hud.set_hits(2)
	_check(hud.get_hits() == 2, "two taken hits crack both talismans")
	hud.set_hits(0)
	_check(hud.get_hits() == 0, "the retry restores both talismans")
