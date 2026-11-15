extends Node

## Focused formal-L2 gate / GuideEcho integration. Uses real E/R/Esc keys and
## the actual LevelExit opt-in FX. No old suite or full level completion.

const L2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LOG_PATH: String = "res://tests/logs/l2_gate_echo_formal_20261114.log"

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_gate()
	await _test_echo()
	_write_log()
	print("L2_GATE_ECHO_FORMAL pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _test_gate() -> void:
	var level: Level02 = L2_SCENE.instantiate() as Level02
	add_child(level)
	await _frames(5)
	await _physics(3)
	var player: PrototypePlayer = level.get_player()
	var core: StarCoreCarrier = level.get_core()
	var linked: StarCoreBayInteractable = level.get_linked_bay()
	var final_bay: StarCoreBayInteractable = level.get_final_bay()
	var link: BayRuneLink = level.get_link()
	var rune: RuneStoneField = level.get_rune_field()
	var exit: LevelExit = level.get_exit()
	level.debug_restore_stage(2, true)
	if level.get_hud() != null:
		level.get_hud().show_toast("", 0.0)
	player.global_position = Vector2(1600, 320)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	level.get_camera().reset_smoothing()
	await _physics(5)
	_check(exit.gate_portal_fx_enabled, "L2 exit opts into v2 gate FX")
	var fx: Sprite2D = exit.get_gate_fx_sprite()
	_check(fx != null and fx.hframes == 8, "L2 gate FX is 8-frame")
	_check(fx != null and fx.texture != null and Vector2i(fx.texture.get_size()) == Vector2i(608, 100), "L2 gate sheet is 608x100")
	_check(not level.is_exit_gate_ready(), "canonical closed state is really closed")
	_check(linked.has_core() and not final_bay.has_core(), "closed state holds one core in the linked bay")
	_check(link.is_field_activated() and rune.is_activated(), "closed state keeps record/field")
	_check(_core_count() == 1, "closed state has exactly one core")
	_check(fx != null and not fx.visible, "closed state hides gate FX")
	_check(level.get_hud().get_core_text().contains("联动仓"), "closed HUD names the linked bay")

	await _open_gate(level, core)
	await _physics(3)
	_check(level.is_exit_gate_ready(), "open state satisfies the real gate contract")
	_check(final_bay.has_core() and not linked.has_core(), "open state holds one core in the final bay")
	_check(linked.has_record() and link.is_field_activated(), "open state keeps linked record/field")
	_check(_core_count() == 1, "open state has exactly one core")
	fx = exit.get_gate_fx_sprite()
	_check(fx != null and fx.visible, "open state shows the gate FX")
	var seen: Dictionary = {}
	for _i: int in range(24):
		await _frames(1)
		if fx != null:
			seen[fx.frame] = true
	_check(seen.size() >= 2, "gate FX advances at 8 fps")
	var camera_open: Vector2 = level.get_camera().global_position

	var pause = level.get_pause_menu()
	await _tap_ui_key(KEY_ESCAPE)
	await _wait_paused(true)
	_check(pause.is_open(), "real Esc opens the formal pause menu")
	var frozen: int = fx.frame if fx != null else -1
	await _frames(30)
	_check(fx != null and fx.frame == frozen, "real Esc freezes the gate FX")
	await _tap_ui_key(KEY_ESCAPE)
	await _wait_paused(false)
	_check(not pause.is_open(), "real Esc resumes")
	await _frames(24)
	_check(fx != null and fx.frame != frozen, "resume advances the gate FX")
	_check(level.get_camera().global_position.is_equal_approx(camera_open), "gate camera unchanged")

	await _tap_key(KEY_E)
	await _physics(28)
	_check(core.is_active(), "real E takes the final-bay core out")
	_check(not level.is_exit_gate_ready(), "E revokes gate readiness")
	_check(linked.has_record() and link.is_field_activated(), "E keeps linked record/field")
	_check(_core_count() == 1, "E keeps exactly one core")
	await _frames(4)
	_check(fx != null and not fx.visible, "E hides gate FX")

	await _open_gate(level, core)
	await _physics(3)
	_check(level.is_exit_gate_ready(), "gate can be reopened for R")
	await _tap_key(KEY_R)
	await _frames(20)
	await _physics(4)
	_check(not level.is_exit_gate_ready(), "real R closes the gate")
	_check(fx != null and not fx.visible, "real R hides gate FX")
	_check(not exit.is_completed(), "real R restores the original open exit frame")
	_check(_core_count() == 1, "R keeps exactly one core")
	var guide: GuideEcho = level.get_start_stele()
	_check(guide != null and not guide.is_suspended(), "R leaves the formal GuideEcho usable")

	await _open_gate(level, core)
	await _physics(3)
	player.global_position = Vector2(1600, 320)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	level.get_camera().reset_smoothing()
	await _physics(4)
	Input.action_press(&"move_right")
	for _i: int in range(120):
		await get_tree().physics_frame
		if player.global_position.x >= 1668.0:
			break
	Input.action_release(&"move_right")
	await _frames(12)
	_check(level.is_completed(), "real ready exit completes the level")
	_check(exit.is_completed(), "LevelExit completed state is preserved")
	_check(exit.get_state_texture().resource_path.ends_with("exit_completed.png"), "completed gate uses original completed texture")
	_check(level.get_hud().is_completion_visible(), "formal completion page appears")
	_check(fx != null and not fx.visible, "completion hides gate FX")

	level.queue_free()
	await _frames(4)


func _test_echo() -> void:
	var level: Level02 = L2_SCENE.instantiate() as Level02
	add_child(level)
	await _frames(5)
	await _physics(3)
	var player: PrototypePlayer = level.get_player()
	var guide: GuideEcho = level.get_start_stele()
	player.global_position = Vector2(100, 320)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	level.get_camera().reset_smoothing()
	await _frames(30)
	_check(guide != null and guide.get_page_count() == 4, "L2 GuideEcho has four pages")
	_check(guide.pages[2].contains("护符力") and not guide.pages[2].contains("10px"), "L2 page 3 explains conductive stone")
	_check(get_tree().get_nodes_in_group(&"tutorial_stele").is_empty(), "L2 has no TutorialStele group")
	_check(get_tree().get_nodes_in_group(&"guide_echo").size() == 1, "L2 has one GuideEcho")
	_check(guide.is_prompt_visible(), "L2 GuideEcho shows F prompt")
	await _tap_key(KEY_F)
	await _frames(2)
	_check(guide.is_dialogue_open() and guide.get_page_index() == 0, "real F opens L2 GuideEcho page 1")

	var pause = level.get_pause_menu()
	await _tap_ui_key(KEY_ESCAPE)
	await _wait_paused(true)
	_check(guide.is_suspended(), "real Esc suspends L2 GuideEcho")
	_check(guide.get_page_index() == -1, "real Esc clears the page")
	await _tap_ui_key(KEY_ESCAPE)
	await _wait_paused(false)
	_check(not guide.is_suspended(), "resume unsuspends L2 GuideEcho")

	await _tap_key(KEY_F)
	await _frames(2)
	_check(guide.is_dialogue_open(), "F can reopen after pause")
	await _tap_key(KEY_R)
	await _frames(20)
	await _physics(4)
	_check(guide.get_page_index() == -1, "real R clears L2 GuideEcho")
	_check(not guide.is_suspended(), "R leaves L2 GuideEcho usable")
	_check(get_tree().get_nodes_in_group(&"guide_echo").size() == 1, "R does not duplicate L2 GuideEcho")

	player.global_position = Vector2(300, 320)
	player.velocity = Vector2.ZERO
	await _frames(80)
	_check(not guide.is_in_range() and not guide.is_prompt_visible(), "L2 GuideEcho leaves range")
	_check(not guide.is_manifestation_visible(), "L2 GuideEcho fades out")

	level.queue_free()
	await _frames(4)


func _open_gate(level: Level02, core: StarCoreCarrier) -> void:
	var start_bay: StarCoreBayInteractable = level.get_start_bay()
	var linked: StarCoreBayInteractable = level.get_linked_bay()
	var final_bay: StarCoreBayInteractable = level.get_final_bay()
	var link: BayRuneLink = level.get_link()
	start_bay.reset_empty()
	linked.reset_empty()
	final_bay.reset_empty()
	core.deactivate()
	core.collision_mask = 0
	linked.start_store_core(true)
	linked.finish_store()
	link.restore_committed(true, true)
	linked.start_release()
	linked.finish_release()
	final_bay.start_store_core(true)
	final_bay.finish_store()
	core.global_position = final_bay.get_store_center()
	core.collision_mask = 0
	await _physics(3)


func _tap_ui_key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait_paused(expected: bool) -> void:
	for _i: int in range(40):
		if get_tree().paused == expected:
			return
		await get_tree().process_frame


func _tap_key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame


func _core_count() -> int:
	return get_tree().get_root().find_children("*", "StarCoreCarrier", true, false).size()


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("L2 GATE ECHO FAIL: " + text)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
