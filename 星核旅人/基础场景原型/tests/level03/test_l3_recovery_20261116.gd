extends Node

## Level-03 recovery transition checks (2026-11-16).
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/level03/test_l3_recovery_20261116.tscn
##
## Scope: only the local L3 defeat/automatic-fall cover. The existing two-hit
## rule, 0.15 s reaction, 0.6 s protection, guard and stable restore are kept.
## Real guard strikes are used for the headline sequence; the remaining checks
## use the guard's own player_struck signal to reach the same transition fast.
## This is a state setup, not a full-level playthrough.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const TITLE_SCENE: String = "res://scenes/level_01.tscn"

var _pass: int = 0
var _fail: int = 0
var _level: Level03 = null
var _struck_total: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	print("Star Core Traveler - L3 recovery transition checks (2026-11-16)")
	print("Godot %s" % Engine.get_version_info()["string"])
	await _sec_second_hit_order()
	await _sec_block_and_pause()
	await _sec_auto_fall()
	await _sec_focus_cleanup()
	await _sec_restart_and_return()
	await _clear_all()
	print("")
	print("RECOVERY_TEST_SUMMARY pass=%d fail=%d" % [_pass, _fail])
	print("RESULT: %s" % ("PASS" if _fail == 0 else "FAIL"))
	get_tree().quit(0 if _fail == 0 else 1)


# --- A. real second hit: reaction first, reset only at alpha 1 -------------

func _sec_second_hit_order() -> void:
	_section("A real second hit: existing reaction, then fade / black reset / fade-in")
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	var base: int = _struck_total
	_check(await _wait_for_struck(base + 1, 600), "first real guard hit lands")
	_check(_level.get_player_hits() == 1, "first hit counts once")
	_check(not _level.is_recovery_active(), "first hit does not start any cover")
	_check(_level.get_recovery_reset_count() == 0, "first hit performs no reset")
	_check(await _wait_for_struck(base + 2, 900), "second real guard hit lands")
	_check(_level.get_player_hits() == 2, "second hit counts once")
	_check(_level.is_retry_pending(), "second hit keeps the existing 0.15 s pending window")
	_check(player.get_hurt_tint_amount() >= 0.99, "second hit is red before the cover",
		"tint=%.2f" % player.get_hurt_tint_amount())
	for _i: int in range(30):
		await get_tree().physics_frame
		if not _level.is_retry_pending():
			break
	_check(_level.is_recovery_active(), "the cover starts after the reaction window")
	_check(_level.get_recovery_alpha() < 0.999, "cover is not black yet at the start",
		"alpha=%.3f" % _level.get_recovery_alpha())
	_check(player.global_position.distance_to(_level.get_arena_spawn()) > 100.0,
		"the body has not been teleported to the recovery point while the cover is light",
		str(player.global_position))
	_check(_level.get_recovery_reset_count() == 0, "no reset before the cover is black")
	var reset_seen: bool = false
	for _i: int in range(900):
		await get_tree().process_frame
		if _level.get_recovery_reset_count() >= 1:
			reset_seen = true
			break
	_check(reset_seen, "the stable recovery really runs during the transition")
	_check(_level.get_recovery_reset_alpha() >= 0.999,
		"the reset timestamp is a fully black cover",
		"reset_alpha=%.3f" % _level.get_recovery_reset_alpha())
	_check(_level.get_recovery_overlay_alpha() >= 0.999,
		"the HUD cover is actually opaque at the reset",
		"hud_alpha=%.3f" % _level.get_recovery_overlay_alpha())
	_check(_level.get_recovery_reset_position().distance_to(_level.get_arena_spawn()) <= 6.0,
		"the reset lands on the unchanged guard-front recovery point",
		str(_level.get_recovery_reset_position()))
	_check(player.global_position.distance_to(_level.get_arena_spawn()) <= 6.0,
		"the live body is at the recovery point under black", str(player.global_position))
	_check(_level.get_player_hits() == 0, "the reset clears the two-hit counter")
	_check(player.get_hurt_tint_amount() == 0.0,
		"the fade-in shows the normal body colour, not a carried-over red",
		"tint=%.2f" % player.get_hurt_tint_amount())
	_check(guard.is_suspended(), "the guard stays hung during the cover")
	_check(await _wait_recovery_done(), "fade-in finishes and the cover clears")
	_check(_level.get_recovery_reset_count() == 1,
		"exactly one reset ran in this transition",
		"resets=%d" % _level.get_recovery_reset_count())
	_check(_level.get_recovery_overlay_alpha() == 0.0, "no black is left after the transition")
	_check(player.is_physics_processing() and not player.is_recovery_held(),
		"the body is active again after the fade-in")
	_check(not player.is_input_override_active(),
		"the recovery movement override is released after the fade-in")
	_check(not guard.is_suspended(), "the guard resumes after the fade-in")
	var x0: float = player.global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	Input.action_release(&"move_right")
	_check(player.global_position.x > x0 + 8.0,
		"real movement works after the transition", "x %.1f -> %.1f" % [x0, player.global_position.x])
	await _free_level()


# --- B. input rejection and pause clock freeze -----------------------------

func _sec_block_and_pause() -> void:
	_section("B the cover rejects J/Q/E/movement and a third hit; Esc freezes its clock")
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	guard.player_struck.emit(-1)
	await _physics(2)
	guard.player_struck.emit(-1)
	await _physics(2)
	_check(_level.is_recovery_active(), "two accepted signals open the cover")
	_check(_level.get_player_hits() == 2, "the two accepted hits are the only ones counted")
	_check(_level.get_recovery_reset_count() == 0,
		"the third-hit check runs before the black reset")
	guard.player_struck.emit(-1)
	await _physics(2)
	_check(_level.get_player_hits() == 2,
		"a third hit signal is rejected during the light cover",
		"hits=%d" % _level.get_player_hits())
	var x0: float = player.global_position.x
	var polarity0: bool = player.is_positive()
	var device0: bool = _level.get_device().is_active()
	var key0: bool = _level.is_key_taken()
	_send_key(KEY_J, true)
	await _physics(1)
	_send_key(KEY_J, false)
	_check(not player.is_attacking(), "J is rejected during the cover")
	Input.action_press(&"move_right")
	await _physics(6)
	Input.action_release(&"move_right")
	_check(absf(player.global_position.x - x0) < 0.6,
		"movement is rejected during the cover", "dx=%.2f" % (player.global_position.x - x0))
	Input.action_press(&"polarity")
	await _physics(2)
	Input.action_release(&"polarity")
	_check(player.is_positive() == polarity0, "Q is rejected during the cover")
	Input.action_press(&"interact")
	await _physics(2)
	Input.action_release(&"interact")
	_check(_level.get_device().is_active() == device0 and _level.is_key_taken() == key0,
		"E does not activate or pick anything during the cover")
	_check(guard.is_suspended(), "the real guard is suspended during the cover")
	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await get_tree().process_frame
	_check(get_tree().paused, "Esc opens the real pause page during the cover")
	_check(_level.get_pause_menu().call("is_open"), "the pause page is really open")
	_check(_level.get_hud().is_pause_visible(), "the HUD keeps the pause page visible")
	var alpha0: float = _level.get_recovery_overlay_alpha()
	var phase0: String = _level.get_recovery_phase()
	_check(alpha0 > 0.0, "the cover is visible behind the pause page", "%.3f" % alpha0)
	for _i: int in range(30):
		await get_tree().process_frame
	_check(absf(_level.get_recovery_overlay_alpha() - alpha0) < 0.001,
		"the recovery clock/alpha is frozen while paused",
		"%.3f -> %.3f" % [alpha0, _level.get_recovery_overlay_alpha()])
	_check(_level.get_recovery_phase() == phase0, "the recovery phase is frozen while paused")
	_check(guard.is_suspended(), "the guard stays hung behind the pause page")
	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await get_tree().process_frame
	_check(not get_tree().paused, "Esc resumes the cover")
	_check(await _wait_recovery_done(), "the resumed cover completes")
	_check(_level.get_recovery_overlay_alpha() == 0.0, "pause/resume leaves no black")
	_check(not guard.is_suspended(), "the guard resumes after the cover completes")
	var x1: float = player.global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	Input.action_release(&"move_right")
	_check(player.global_position.x > x1 + 8.0,
		"control is restored after pause + cover", "x %.1f -> %.1f" % [x1, player.global_position.x])
	await _free_level()


# --- C. automatic fall ------------------------------------------------------

func _sec_auto_fall() -> void:
	_section("C automatic fall: local intercept, stable restore at black, then fade-in")
	await _new_l3()
	_level.debug_place_player_at(Vector2(850.0, 210.0))
	await _physics(4)
	_check(not _level.is_recovery_active(), "standing on the real ledge is normal play")
	Input.action_press(&"move_right")
	var fell: bool = false
	for _i: int in range(140):
		await get_tree().physics_frame
		if _level.is_recovery_active():
			fell = true
			break
	Input.action_release(&"move_right")
	_check(fell, "walking off the real ledge into the pit starts the local fall cover")
	_check(_level.get_recovery_kind() == "fall", "the transition is the automatic-fall kind")
	_check(_level.get_recovery_alpha() < 0.999, "the fall cover is still fading in")
	_check(_level.get_player().global_position.y > 430.0,
		"the fall request comes from the unchanged shared kill line",
		str(_level.get_player().global_position))
	var reset_seen: bool = false
	for _i: int in range(900):
		await get_tree().process_frame
		if _level.get_recovery_reset_count() >= 1:
			reset_seen = true
			break
	_check(reset_seen, "the fall cover reaches black and restores")
	_check(_level.get_recovery_reset_alpha() >= 0.999,
		"the fall restore also runs at a fully black cover")
	_check(_level.get_player().global_position.distance_to(_level.get_start_spawn()) <= 6.0,
		"the fall restores the opening stable point", str(_level.get_player().global_position))
	_check(_level.get_stable_stage() == 0, "the opening stable stage is preserved")
	_check(await _wait_recovery_done(), "the fall fade-in finishes")
	_check(_level.get_recovery_overlay_alpha() == 0.0, "fall leaves no black")
	var x0: float = _level.get_player().global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	Input.action_release(&"move_right")
	_check(_level.get_player().global_position.x > x0 + 8.0,
		"real movement works after the fall cover")
	await _free_level()

	# Arena stable stage: debug setup then a real free fall over the pit. The
	# restore must keep the arena recovery point, not replay the route.
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	_level.debug_place_player_at(Vector2(1000.0, 300.0))
	var fell2: bool = false
	for _i: int in range(120):
		await get_tree().physics_frame
		if _level.is_recovery_active():
			fell2 = true
			break
	_check(fell2, "a free fall from the open pit is also intercepted")
	_check(await _wait_recovery_done(), "the arena-stage fall cover completes")
	_check(_level.get_stable_stage() >= 3, "the arena stable stage survives the fall")
	_check(_level.get_player().global_position.distance_to(_level.get_arena_spawn()) <= 6.0,
		"the arena fall restores the arena recovery point",
		str(_level.get_player().global_position))
	await _free_level()


# --- D. focus loss / return cleanup ---------------------------------------

func _sec_focus_cleanup() -> void:
	_section("D window focus loss: the cover completes with no black or stuck guard lock")
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	guard.player_struck.emit(-1)
	await _physics(2)
	guard.player_struck.emit(-1)
	await _physics(2)
	_check(_level.is_recovery_active(), "focus check starts from an active cover")
	_level.call("_on_window_focus_exited")
	_check(_level.is_recovery_active(), "focus loss does not drop the recovery")
	_check(guard.is_suspended(), "the guard stays hung after focus loss")
	var alpha0: float = _level.get_recovery_overlay_alpha()
	for _i: int in range(20):
		await get_tree().process_frame
	_check(_level.get_recovery_overlay_alpha() > alpha0,
		"the cover still advances while the window is unfocused",
		"%.3f -> %.3f" % [alpha0, _level.get_recovery_overlay_alpha()])
	_check(await _wait_recovery_done(), "the unfocused cover still completes")
	_check(_level.get_recovery_overlay_alpha() == 0.0, "focus loss leaves no black")
	_check(guard.is_suspended(), "the guard stays hung while focus is absent")
	_level.call("_on_window_focus_entered")
	await _physics(2)
	_check(not guard.is_suspended(), "focus return resumes the guard")
	var x0: float = _level.get_player().global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	Input.action_release(&"move_right")
	_check(_level.get_player().global_position.x > x0 + 8.0,
		"control works after focus return")
	await _free_level()


# --- D2. R and menu return cleanup ----------------------------------------
func _sec_restart_and_return() -> void:
	_section("E R restart and menu return clean the cover without black or a retry")
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	guard.player_struck.emit(-1)
	await _physics(2)
	guard.player_struck.emit(-1)
	await _physics(2)
	_check(_level.is_recovery_active(), "R check starts from an active cover")
	_send_key(KEY_R, true)
	await get_tree().process_frame
	_send_key(KEY_R, false)
	await get_tree().process_frame
	await _physics(4)
	_check(not _level.is_recovery_active(), "R cancels the cover")
	_check(_level.get_recovery_overlay_alpha() == 0.0, "R leaves no black")
	_check(_level.get_stable_stage() == 0, "R returns to the opening stage")
	_check(_level.get_player_hits() == 0, "R clears the two-hit state")
	_check(_level.get_player().global_position.distance_to(_level.get_start_spawn()) <= 6.0,
		"R returns the body to the level start", str(_level.get_player().global_position))
	var x0: float = _level.get_player().global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	Input.action_release(&"move_right")
	_check(_level.get_player().global_position.x > x0 + 8.0, "R leaves real movement working")
	await _free_level()

	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	guard = _level.get_guard()
	guard.player_struck.emit(-1)
	await _physics(2)
	guard.player_struck.emit(-1)
	await _physics(2)
	_check(_level.is_recovery_active(), "return check starts from an active cover")
	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await get_tree().process_frame
	var back: PixelMenuButton = _level.get_pause_menu().call("get_return_button") as PixelMenuButton
	get_tree().current_scene = _level
	await _click(back)
	var title: Node = await _wait_scene("Level01", 240)
	_check(title != null and title.name.begins_with("Level01"),
		"menu return during the cover reaches the real title", str(title))
	_check(not get_tree().paused, "the returned title is unpaused")
	var leftovers: int = get_tree().root.get_children().filter(
		func(n: Node) -> bool: return n is Level03).size()
	_check(leftovers == 0, "the covered L3 instance is gone; no black or lock remains",
		str(leftovers))
	_level = null
	await _clear_all()


# --- harness ---------------------------------------------------------------

func _new_l3() -> void:
	await _clear_all()
	_struck_total = 0
	_level = LEVEL_SCENE.instantiate() as Level03
	get_tree().root.add_child(_level)
	await _physics(24)
	var guard: L3Guard = _level.get_guard()
	if not guard.player_struck.is_connected(_on_player_struck):
		guard.player_struck.connect(_on_player_struck, CONNECT_DEFERRED)


func _on_player_struck(_facing: int) -> void:
	_struck_total += 1


func _wait_for_struck(target: int, limit: int) -> bool:
	for _i: int in range(limit):
		await get_tree().physics_frame
		if _struck_total >= target:
			return true
	return false


func _wait_recovery_done(limit: int = 1200) -> bool:
	for _i: int in range(limit):
		await get_tree().process_frame
		if _level != null and not _level.is_recovery_active():
			await _physics(2)
			return true
	return false


func _free_level() -> void:
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		if get_tree().current_scene == _level:
			get_tree().current_scene = null
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null


func _clear_all() -> void:
	get_tree().paused = false
	for child: Node in get_tree().root.get_children():
		if child == self:
			continue
		if child is Level03 or child is Level01 or child is Level02:
			var audio: Node = child.call("get_audio") if child.has_method("get_audio") else null
			if audio != null and audio.has_method("release_streams"):
				audio.call("release_streams")
			if get_tree().current_scene == child:
				get_tree().current_scene = null
			child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_level = null
	_struck_total = 0
	get_tree().paused = false
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity",
			&"interact", &"reset", &"pause", &"tutorial_next"]:
		Input.action_release(action)


func _wait_scene(prefix: String, max_frames: int) -> Node:
	for _i: int in range(max_frames):
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if current != null and current.name.begins_with(prefix):
			for _j: int in range(4):
				await get_tree().process_frame
			return current
	return get_tree().current_scene


func _click(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var center: Vector2 = control.get_global_rect().get_center()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	get_viewport().push_input(up, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _section(title: String) -> void:
	print("")
	print("-- %s --" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass += 1
		print("[PASS] %s  (%s)" % [label, detail])
	else:
		_fail += 1
		print("[FAIL] %s  (%s)" % [label, detail])
