extends Node

## Demo-end acceptance test (2026-11-16):
##   Godot --headless --path . res://tests/level03/test_l3_demo_finish.tscn
##
## Real inputs only: the completion page is reached by walking with a real D
## key, the two buttons are clicked with real mouse down/up, keyboard paths use
## real Tab / Enter / Space / R key events, and the return goes through the real
## SceneTree.change_scene_to_file to res://scenes/level_01.tscn.
## Callers may keep this harness alive: it is a separate root child, while the
## level under test can be the real current_scene (F6-like).

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const TITLE_PATH: String = "res://scenes/level_01.tscn"

var _fails: Array[String] = []
var _passes: int = 0
var _level: Level03 = null
var _player: L3Player = null
var _hud: L3HUD = null
var _gate: L3Gate = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _sec_page_content()
	await _sec_mouse_replay_then_move()
	await _sec_keyboard_replay()
	await _sec_r_hint_restarts()
	await _sec_production_scene_change()
	await _sec_harness_owned_return()
	await _sec_enter_on_primary()
	print("DEMO_FINISH_RESULT pass=%d fail=%d" % [_passes, _fails.size()])
	for failure: String in _fails:
		print("FAIL: ", failure)
	if _fails.is_empty():
		print("DEMO_FINISH_OK")
	get_tree().quit(0 if _fails.is_empty() else 1)


func _check(ok: bool, label: String) -> bool:
	if ok:
		_passes += 1
	else:
		_fails.append(label)
		print("  ! ", label)
	return ok


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


# --- level helpers ---------------------------------------------------------

## Harness-owned level (not the current scene): a scene change keeps it alive.
func _new_child_level() -> void:
	await _free_level()
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(20)
	_bind()


## Production-shaped level: it IS the tree's current scene, like running
## res://scenes/level_03.tscn directly. This harness is a sibling root child.
func _new_current_scene_level() -> void:
	await _free_level()
	_level = LEVEL_SCENE.instantiate() as Level03
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _phys(20)
	_bind()


func _bind() -> void:
	_player = _level.get_player()
	_hud = _level.get_hud()
	_gate = _level.get_gate()


func _free_level() -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null


func _gx() -> float:
	return _gate.global_position.x


# --- real input helpers ----------------------------------------------------

## Real key press/release through the Input singleton: this updates the real
## InputMap action state AND dispatches the event to the tree, exactly like an
## OS key (the level's _input, the pause menu polling and the GUI focus system
## all see it).
func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _tap_key(code: Key, frames: int = 2) -> void:
	Input.parse_input_event(_key_event(code, true))
	Input.flush_buffered_events()
	await _phys(frames)
	Input.parse_input_event(_key_event(code, false))
	Input.flush_buffered_events()
	await _phys(1)


func _hold_key(code: Key) -> void:
	Input.parse_input_event(_key_event(code, true))
	Input.flush_buffered_events()
	await get_tree().physics_frame


func _release_key(code: Key) -> void:
	Input.parse_input_event(_key_event(code, false))
	Input.flush_buffered_events()


## Real R through the Input singleton so the pause menu's polling sees it.
func _tap_r_action() -> void:
	Input.parse_input_event(_key_event(KEY_R, true))
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame
	Input.parse_input_event(_key_event(KEY_R, false))
	Input.flush_buffered_events()
	await get_tree().process_frame


## Real mouse down/up inside the control's rect.
func _click(control: Control) -> void:
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


## SETUP is explicit: the gate recovery point (defeated guard + real core),
## the gate rise and the walk to the completion line are real inputs.
func _complete_by_real_walk() -> bool:
	_level.debug_setup_gate_with_key(_gx() - 40.0)
	await _phys(10)
	await _tap_key(KEY_E, 2)
	for _i: int in range(150):
		await get_tree().physics_frame
		if _gate.is_open():
			break
	if not _gate.is_open():
		return false
	_hold_key(KEY_D)
	for _i: int in range(220):
		await get_tree().physics_frame
		if _level.is_completed():
			break
	_release_key(KEY_D)
	await _phys(4)
	return _level.is_completed()


func _movement_axis_ok(before_x: float) -> float:
	return _player.global_position.x - before_x


# --- 1. page content, single connections, focus ---------------------------

func _sec_page_content() -> void:
	print("[1] completion page content")
	await _new_child_level()
	var ok: bool = await _complete_by_real_walk()
	_check(ok, "the real walk past the completion line shows the page")
	_check(_hud.is_completion_visible(), "completion overlay visible")
	_check(_hud.get_completion_text() == "感谢游玩",
		"title is 感谢游玩 (%s)" % _hud.get_completion_text())
	_check(_hud.get_completion_subtitle_text() == "本次试玩到此结束",
		"subtitle is 本次试玩到此结束 (%s)" % _hud.get_completion_subtitle_text())
	var primary: PixelMenuButton = _hud.get_completion_primary_button()
	var replay: PixelMenuButton = _hud.get_completion_replay_button()
	_check(primary.text == "返回主界面", "primary button says 返回主界面")
	_check(replay.text == "重玩本关", "replay button says 重玩本关")
	_check(_hud.get_completion_hint_text().contains("R"),
		"the page really shows the R hint (%s)" % _hud.get_completion_hint_text())
	_check(not primary.disabled and not replay.disabled, "both buttons start enabled")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(primary.has_focus(), "the primary button owns the initial focus")
	var connections: Array = _hud.replay_requested.get_connections()
	_check(connections.size() == 1, "replay signal is wired exactly once (%d)" % connections.size())
	var back: Array = _hud.return_to_menu_requested.get_connections()
	_check(back.size() == 1, "return signal is wired exactly once (%d)" % back.size())
	_check(_player.is_completion_locked(), "the body is locked while the page is up")


# --- 2. real mouse replay, then real movement -----------------------------

func _sec_mouse_replay_then_move() -> void:
	print("[2] mouse replay -> unlocked -> real movement")
	var replay: PixelMenuButton = _hud.get_completion_replay_button()
	await _click(replay)
	await _phys(6)
	_check(not _hud.is_completion_visible(), "mouse click closes the page")
	_check(not _level.is_completed(), "the level is playable again")
	_check(not _player.is_completion_locked(), "the completion input lock is released")
	_check(_player.global_position.distance_to(_level.get_start_spawn()) <= 2.0,
		"the body is back at the level start spawn (%s)" % str(_player.global_position))
	_check(_level.get_stable_stage() == 0, "stable stage is back to the start")
	var guard: L3Guard = _level.get_guard()
	_check(not guard.is_defeated() and guard.get_remaining_marks() == 3,
		"the guard is restored with three cells (%d)" % guard.get_remaining_marks())
	_check(_level.get_start_bay().has_core(), "the initial core is back in its start bay")
	_check(not _gate.is_open() and _gate.is_collision_active(),
		"the gate is closed again with its real collision")
	_check(not _player.is_input_override_active(), "no input override survives the replay")
	var before_x: float = _player.global_position.x
	_hold_key(KEY_D)
	await _phys(30)
	_release_key(KEY_D)
	await _phys(2)
	var moved: float = _movement_axis_ok(before_x)
	_check(moved > 20.0, "real D input moves the body after replay (%.1f px)" % moved)
	_check(absf(_player.global_position.y - 320.0) < 6.0,
		"the body is standing on the ground (y=%.1f)" % _player.global_position.y)


# --- 3. keyboard: Tab to replay, Space activates --------------------------

func _sec_keyboard_replay() -> void:
	print("[3] Tab + Space on the replay button")
	var ok: bool = await _complete_by_real_walk()
	_check(ok, "second completion reached by a real walk")
	var primary: PixelMenuButton = _hud.get_completion_primary_button()
	var replay: PixelMenuButton = _hud.get_completion_replay_button()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(primary.has_focus(), "focus starts on the primary button")
	await _tap_key(KEY_TAB, 2)
	_check(replay.has_focus(), "Tab moves focus to 重玩本关")
	await _tap_key(KEY_TAB, 2)
	_check(primary.has_focus(), "Tab wraps back to 返回主界面")
	await _tap_key(KEY_TAB, 2)
	await _tap_key(KEY_SPACE, 3)
	await _phys(8)
	_check(not _hud.is_completion_visible() and not _level.is_completed(),
		"Space on the focused replay button restarts the level")
	_check(not _player.is_completion_locked(), "keyboard replay also releases the lock")
	var jump_y: float = _player.global_position.y
	var trace: String = ""
	for _i: int in range(8):
		await get_tree().physics_frame
		trace += "%.1f " % _player.global_position.y
	_check(absf(_player.global_position.y - jump_y) < 2.0,
		"the Space press did not leak into a jump on the fresh run (y %.1f -> %s)" % [jump_y, trace])


# --- 4. the shown R hint restarts ------------------------------------------

func _sec_r_hint_restarts() -> void:
	print("[4] R hint while the page is up")
	var ok: bool = await _complete_by_real_walk()
	_check(ok, "third completion reached by a real walk")
	_check(_hud.is_completion_visible(), "page visible before R")
	await _tap_r_action()
	await _phys(8)
	_check(not _hud.is_completion_visible() and not _level.is_completed(),
		"R restarts the level from the completion page")
	_check(not _player.is_completion_locked(), "R also releases the completion lock")


# --- 5. real SceneTree change to the level-01 title -----------------------

func _sec_production_scene_change() -> void:
	print("[5] production-shaped scene change (level is current_scene)")
	await _new_current_scene_level()
	var ok: bool = await _complete_by_real_walk()
	_check(ok, "completion reached inside a current_scene level")
	var primary: PixelMenuButton = _hud.get_completion_primary_button()
	_check(primary.has_focus(), "primary focused on the second page")
	await _click(primary)
	# The real change is committed by the deferred SceneTree swap.
	for _i: int in range(30):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene != _level:
			break
	var current: Node = get_tree().current_scene
	_check(current != null and current.scene_file_path == TITLE_PATH,
		"the tree really switched to %s (%s)" % [
			TITLE_PATH, current.scene_file_path if current != null else "<null>"])
	if current != null:
		_check(current.name == "Level01" and current.get_node_or_null("StartMenu") != null,
			"the new scene is the real level-01 title scene (%s / StartMenu %s)" % [
				current.name, str(current.get_node_or_null("StartMenu") != null)])
	_check(_level == null or not is_instance_valid(_level),
		"the level-03 scene was freed by the change")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_inside_tree(), "this harness survived the change as a separate root child")


# --- 6. harness-owned level: the change is real, the driver stays alive -----

func _sec_harness_owned_return() -> void:
	print("[6] return with a harness-owned level (no current_scene)")
	var leftover: Node = get_tree().current_scene
	if leftover != null and is_instance_valid(leftover):
		leftover.queue_free()
		await get_tree().process_frame
	get_tree().current_scene = null
	await _new_child_level()
	var ok: bool = await _complete_by_real_walk()
	_check(ok, "completion reached with a harness-owned level")
	var primary: PixelMenuButton = _hud.get_completion_primary_button()
	await _click(primary)
	for _i: int in range(30):
		await get_tree().process_frame
		if get_tree().current_scene != null:
			break
	var current: Node = get_tree().current_scene
	_check(current != null and current.scene_file_path == TITLE_PATH,
		"the same real change fires without a current scene (%s)" % [
			current.scene_file_path if current != null else "<null>"])
	_check(is_inside_tree() and _level != null and is_instance_valid(_level),
		"the harness-owned level is not the thing being freed by the change")
	await _free_level()


# --- 7. Enter on the focused primary really returns ------------------------

func _sec_enter_on_primary() -> void:
	print("[7] Enter on the focused 返回主界面")
	var leftover: Node = get_tree().current_scene
	if leftover != null and is_instance_valid(leftover):
		leftover.queue_free()
		await get_tree().process_frame
	get_tree().current_scene = null
	await _new_child_level()
	var ok: bool = await _complete_by_real_walk()
	_check(ok, "completion reached for the Enter path")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_hud.get_completion_primary_button().has_focus(), "primary focused before Enter")
	await _tap_key(KEY_ENTER, 3)
	for _i: int in range(30):
		await get_tree().process_frame
		if get_tree().current_scene != null:
			break
	var current: Node = get_tree().current_scene
	_check(current != null and current.scene_file_path == TITLE_PATH,
		"Enter on the focused primary performs the real title change (%s)" % [
			current.scene_file_path if current != null else "<null>"])
	_check(_level == null or _level.is_scene_leaving() or not is_instance_valid(_level),
		"the level marked itself as leaving before the change")
