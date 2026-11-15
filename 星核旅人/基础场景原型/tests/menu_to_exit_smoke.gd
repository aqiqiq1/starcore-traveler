extends Node

## One same-instance default-menu -> exit smoke test.
##
## This deliberately creates ONE level_01.tscn with the production default
## (enable_start_menu = true), starts it with a real Enter through InputMap,
## waits for the real opening handoff, then follows the same physical-input
## route as tests/test_level_01.gd: talk to both guide echoes, use the high rune stone,
## cross the pit, touch the checkpoint, reach the exit, then press R.
##
## No re-instantiation after the menu starts, no teleport, no collision edits,
## no direct exit emission/completion call and no test-only force. Movement and
## Q/jump use the same InputMap actions as the existing full-route suite; F and
## R are real key events. Audio persistence uses a temporary user:// path and
## Master is restored afterwards.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const TEMP_AUDIO_PATH: String = "user://test_menu_to_exit_audio.cfg"
const TEMP_DISPLAY_PATH: String = "user://test_menu_to_exit_display.cfg"

var _level: Level01
var _menu: StartMenu
var _player: PrototypePlayer
var _hud: Level01HUD
var _world: Node2D
var _menu_camera: Camera2D
var _level_instance_id: int = 0
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []
var _original_master_db: float = 0.0
var _original_master_mute: bool = false
var _original_window_state: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_original_master_db = AudioServer.get_bus_volume_db(0)
	_original_master_mute = AudioServer.is_bus_mute(0)
	_original_window_state = _capture_window_state()
	_remove_temp_audio()
	_remove_temp_display()
	_log("Star Core Traveler - default menu -> exit smoke")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"], DisplayServer.get_name()
	])
	await _run_smoke()
	await _finish()


func _run_smoke() -> void:
	_level = LEVEL_SCENE.instantiate() as Level01
	var temp_menu: StartMenu = _level.get_node("StartMenu") as StartMenu
	temp_menu.audio_settings_path = TEMP_AUDIO_PATH
	temp_menu.display_settings_path = TEMP_DISPLAY_PATH
	add_child(_level)
	_level_instance_id = _level.get_instance_id()
	await _physics(6)
	await _process_frames(2)

	_menu = _level.get_menu()
	_player = _level.get_player()
	_hud = _level.get_hud()
	_world = _level.get_node("World") as Node2D
	_menu_camera = _level.get_menu_camera()

	_section("DEFAULT INSTANCE / REAL MENU START")
	_check(_level.is_start_menu_enabled(), "smoke instance uses the production default menu flag")
	_check(_menu.get_phase_name() == "menu", "default instance opens in the menu", _menu.get_phase_name())
	_check(not _level.is_intro_active(), "no intro before the real start")
	_check(not _world.visible and not _player.visible and not _hud.visible, "menu still hides world/player/HUD")
	_check(get_viewport().gui_get_focus_owner() == _menu.get_start_button(), "start entry owns the real keyboard focus", str(get_viewport().gui_get_focus_owner()))
	_log("SMOKE_INSTANCE id=%d default_menu=true menu_phase=%s" % [
		_level_instance_id, _menu.get_phase_name()
	])
	_log("SMOKE_START input=real_enter_through_InputMap")

	await _tap_key(KEY_ENTER)
	await _process_frames(1)
	_check(_menu.get_start_request_count() == 1, "real Enter starts exactly once", str(_menu.get_start_request_count()))
	_check(_menu.get_phase_name() == "title_fade", "real Enter enters the title fade", _menu.get_phase_name())
	_check(not _level.is_intro_active(), "real Enter does not skip the camera transition")
	_check(_level.get_instance_id() == _level_instance_id, "same instance after the real start")

	var reached: bool = await _wait_phase("done", 900)
	_check(reached, "same instance reaches the entry phase")
	_check(_level.get_instance_id() == _level_instance_id, "level instance id is unchanged through the menu transition", str(_level.get_instance_id()))
	_check(_menu.get_phase_name() == "done", "menu phase is done after entry", _menu.get_phase_name())
	_check(_world.visible and _player.visible and _hud.visible, "world/player/HUD appear at entry")
	_check(_level.is_intro_active(), "the original opening auto-run starts at entry")
	_check(_level.get_intro_start_count() == 1, "exactly one intro starts from the menu", str(_level.get_intro_start_count()))
	_check(not _menu.get_node("StartMenuRoot").visible, "menu root is hidden after entry")
	_check(_menu.get_start_request_count() == 1, "menu start count stays 1 through entry")

	await _wait_intro_done()
	_check(not _level.is_intro_active(), "original opening hands control back")
	_check(_player.is_on_floor(), "player stands after the opening handoff", str(_player.global_position))
	_check(_player.global_position.x > 80.0 and _player.global_position.x < 140.0, "player starts the route at the real IntroEnd, not a teleport", str(_player.global_position))
	_check(_menu.get_phase_name() == "done" and not _menu.get_node("StartMenuRoot").visible, "menu stays hidden during play")
	_log("SMOKE_ROUTE_BEGIN pos=%s intro_start_count=%d" % [
		str(_player.global_position), _level.get_intro_start_count()
	])

	await _route_from_menu_start()

	# The route completed through the real exit trigger. Press real R and make
	# sure completion clears without the menu reappearing.
	var completion_x: float = _player.global_position.x
	_check(completion_x >= 1800.0, "completion happened at the real exit", str(_player.global_position))
	_check(_level.get_completion_count() == 1, "exit completes exactly once", str(_level.get_completion_count()))
	_check(_hud.is_completion_visible() and _hud.get_completion_text().contains("第一关完成"), "completion panel is visible", _hud.get_completion_text())
	_check(_player.is_input_override_active(), "player is frozen at completion")
	_check(_level.get_exit().is_completed() and not _level.get_exit().monitoring, "exit trigger is closed after completion")

	await _tap_key(KEY_R)
	await _physics(5)
	_check(_level.get_instance_id() == _level_instance_id, "same instance after real R")
	_check(not _level.is_completed(), "real R clears completion")
	_check(not _hud.is_completion_visible(), "real R hides the completion panel")
	_check(_level.is_intro_active(), "real R replays the original opening run")
	_check(_player.is_positive(), "real R restores 辉相")
	_check(_menu.get_phase_name() == "done", "real R does not return to the menu", _menu.get_phase_name())
	_check(not _menu.get_node("StartMenuRoot").visible, "menu root stays hidden after real R")
	_check(not _menu_camera.enabled, "real R does not re-enable the menu camera")
	_check(_menu.get_start_request_count() == 1, "real R never starts a second menu run", str(_menu.get_start_request_count()))
	_check(_level.get_intro_start_count() == 2, "one menu start plus one R replay, no menu loop", str(_level.get_intro_start_count()))
	_check(get_tree().get_nodes_in_group(&"guide_echo").size() == 2, "the same instance still owns its two guide echoes", str(get_tree().get_nodes_in_group(&"guide_echo").size()))
	_log("SMOKE_R_AFTER_EXIT completed=%s intro=%s pos=%s menu_phase=%s instance=%d" % [
		str(_level.is_completed()), str(_level.is_intro_active()),
		str(_player.global_position), _menu.get_phase_name(), _level.get_instance_id()
	])

	await _wait_intro_done()
	_check(not _level.is_intro_active(), "R replay hands control back")
	_check(_menu.get_phase_name() == "done" and not _menu.get_node("StartMenuRoot").visible, "menu still does not reappear after the R replay")
	_log("SMOKE_RESULT pass=%d fail=%d same_instance=%s" % [
		_pass_count, _fail_count, str(_level.get_instance_id() == _level_instance_id)
	])


# --- Existing level 01 route (copied from the full-route test) -------------

func _route_from_menu_start() -> void:
	# Meeting guide echo: approach only shows the prompt; real F opens page 1.
	await _move_until_x(245.0, 500)
	await _physics(6)
	var narrative: GuideEcho = _level.get_narrative_guide()
	_check(narrative.is_in_range(), "meeting guide echo is in range on approach", str(_player.global_position))
	_check(narrative.is_prompt_visible() and narrative.get_page_index() == -1, "meeting guide only shows the F prompt on approach")
	await _press_f()
	_check(narrative.get_page_index() == 0, "meeting F opens page 1")
	await _press_f()
	_check(narrative.get_page_index() == 1, "meeting F advances to page 2")
	await _press_f()
	_check(narrative.get_page_index() == 2, "meeting F advances to page 3")
	await _press_f()
	_check(narrative.get_page_index() == -1, "meeting F closes the last page")

	# High-step guide echo: same three-page F interaction, same in-range prompt.
	await _move_until_x(725.0, 600)
	await _physics(6)
	var mechanism: GuideEcho = _level.get_mechanism_guide()
	_check(mechanism.is_in_range(), "high-step guide echo is in range before the field")
	_check(mechanism.is_prompt_visible() and mechanism.get_page_index() == -1, "high-step guide only shows the F prompt on approach")
	var prompt_rect: Rect2 = mechanism.get_prompt_rect()
	_check(prompt_rect.position.y >= 49.5 and prompt_rect.end.x <= 636.5 and prompt_rect.end.y <= 356.0, "scrolled guide prompt stays inside the screen", str(prompt_rect))
	await _press_f()
	_check(mechanism.get_page_index() == 0, "high-step F opens page 1")
	await _press_f()
	_check(mechanism.get_page_index() == 1, "high-step F advances to page 2")
	await _press_f()
	_check(mechanism.get_page_index() == 2, "high-step F advances to page 3")
	await _press_f()
	_check(mechanism.get_page_index() == -1, "high-step F closes the last page")

	# High platform: attraction lifts, same phase repels right.
	Input.action_press(&"move_right")
	await _physics(80)
	await _tap_action(&"polarity")
	_check(not _player.is_positive(), "Q selects 澜相 for the attraction")
	_check(_hud.get_polarity_text() == "澜相", "HUD shows 澜相", _hud.get_polarity_text())
	await _physics(8)
	var high_stone: RuneStoneField = _level.get_rune_stones()[0]
	var to_high_stone: Vector2 = high_stone.global_position - (_player.global_position + Vector2(0.0, -15.0))
	var attract_force: Vector2 = _level.get_last_force()
	_check(attract_force.dot(to_high_stone) > 0.0 and attract_force.y < 0.0, "异相吸引 force points toward the high stone and lifts", str(attract_force))
	var landed: bool = false
	for _i: int in range(280):
		await get_tree().physics_frame
		if _player.is_on_floor() and _player.global_position.y <= 222.0 and _player.global_position.x >= 864.0:
			landed = true
			break
	_check(landed, "异相吸引 carries the player onto the high platform", str(_player.global_position))
	await _tap_action(&"polarity")
	_check(_player.is_positive(), "Q returns to 辉相 for the rightward repel")
	await _physics(3)
	var repel_force: Vector2 = _level.get_last_force()
	_check(repel_force.x > 50.0, "同相排斥 pushes the player right off the high platform", str(repel_force))

	for _i: int in range(240):
		await get_tree().physics_frame
		if _level.get_checkpoint().is_activated() or _player.global_position.x >= 1125.0:
			break
	_check(_level.get_checkpoint().is_activated(), "checkpoint activates on the platform", str(_player.global_position))
	_check(_player.global_position.y < 230.0, "checkpoint run stays on the platform", str(_player.global_position))
	for _i: int in range(160):
		await get_tree().physics_frame
		if _player.global_position.x >= 1172.0:
			break
	Input.action_release(&"move_right")
	await _physics(12)
	_check(_player.global_position.y < 230.0, "player waits safely before the pit", str(_player.global_position))

	# Pit: attraction first, then same-phase repulsion to the far bank.
	await _tap_action(&"polarity")
	_check(not _player.is_positive(), "pit attempt starts on 澜相")
	Input.action_press(&"move_right")
	await _tap_action(&"jump")
	var switched: bool = false
	var pit_repel_right: bool = false
	for _i: int in range(220):
		await get_tree().physics_frame
		if not switched and _player.global_position.x >= 1405.0 and _player.global_position.y <= 262.0 and _player.velocity.x > 0.0:
			await _tap_action(&"polarity")
			switched = true
			await _physics(2)
			pit_repel_right = _level.get_last_force().x > 50.0
			continue
		if _player.is_on_floor() and _player.global_position.x >= 1500.0:
			break
		if _player.global_position.y > 420.0:
			break
	_check(switched, "pit route switches phase while airborne", "x=%.1f y=%.1f" % [_player.global_position.x, _player.global_position.y])
	_check(pit_repel_right, "同相排斥 points across the pit, not back to the platform")
	Input.action_release(&"move_right")
	await _physics(16)
	_check(_player.global_position.x >= 1500.0 and _player.global_position.y < 310.0, "attract->repel crosses the wide pit", str(_player.global_position))
	_check(_player.is_on_floor(), "player is safely on the far bank", str(_player.global_position))

	# Exit by walking right into the real trigger.
	Input.action_press(&"move_right")
	for _i: int in range(420):
		await get_tree().physics_frame
		if _level.is_completed():
			break
	Input.action_release(&"move_right")
	await _physics(4)
	_check(_level.is_completed(), "reaching the exit completes level 01", str(_player.global_position))
	_log("SMOKE_EXIT pos=%s completed=%s count=%d" % [
		str(_player.global_position), str(_level.is_completed()), _level.get_completion_count()
	])


# --- Input / wait helpers --------------------------------------------------

func _wait_phase(phase_name: String, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		if _menu.get_phase_name() == phase_name:
			return true
		await get_tree().process_frame
	return _menu.get_phase_name() == phase_name


func _wait_intro_done() -> void:
	for _i: int in range(420):
		if not _level.is_intro_active():
			break
		await get_tree().physics_frame
	await _physics(6)


func _move_until_x(target_x: float, max_frames: int) -> void:
	Input.action_press(&"move_right")
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if _player.global_position.x >= target_x:
			break
	Input.action_release(&"move_right")
	await _physics(8)


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _press_f() -> void:
	_send_key(KEY_F, true)
	await get_tree().process_frame
	_send_key(KEY_F, false)
	await get_tree().process_frame


func _tap_key(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, true, location)
	await get_tree().process_frame
	_send_key(key, false, location)
	await get_tree().process_frame


func _send_key(key: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.location = location
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _process_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause"]:
		Input.action_release(action)


# --- Reporting / cleanup ---------------------------------------------------

func _section(title: String) -> void:
	_log("")
	_log("-- %s --" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s  (%s)" % [label, detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s  (%s)" % [label, detail])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _remove_temp_audio() -> void:
	var global: String = ProjectSettings.globalize_path(TEMP_AUDIO_PATH)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)


func _remove_temp_display() -> void:
	var global: String = ProjectSettings.globalize_path(TEMP_DISPLAY_PATH)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)


func _capture_window_state() -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {}
	var window: Window = get_window()
	return {
		"mode": window.mode,
		"size": window.size,
		"position": window.position,
		"content_scale_size": window.content_scale_size,
		"content_scale_mode": window.content_scale_mode,
		"content_scale_aspect": window.content_scale_aspect,
		"content_scale_stretch": window.content_scale_stretch,
		"content_scale_factor": window.content_scale_factor,
	}


func _restore_window_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var window: Window = get_window()
	window.mode = int(state.get("mode", Window.MODE_WINDOWED))
	window.size = state.get("size", window.size)
	window.position = state.get("position", window.position)
	window.content_scale_size = state.get("content_scale_size", Vector2i(640, 360))
	window.content_scale_mode = int(state.get("content_scale_mode", Window.CONTENT_SCALE_MODE_VIEWPORT))
	window.content_scale_aspect = int(state.get("content_scale_aspect", Window.CONTENT_SCALE_ASPECT_KEEP))
	window.content_scale_stretch = int(state.get("content_scale_stretch", Window.CONTENT_SCALE_STRETCH_INTEGER))
	window.content_scale_factor = float(state.get("content_scale_factor", 1.0))


func _finish() -> void:
	_release_inputs()
	get_tree().paused = false
	AudioServer.set_bus_mute(0, _original_master_mute)
	AudioServer.set_bus_volume_db(0, _original_master_db)
	_remove_temp_audio()
	_remove_temp_display()
	_restore_window_state(_original_window_state)
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d same_instance=%s" % [
		_pass_count, _fail_count,
		str(is_instance_valid(_level) and _level.get_instance_id() == _level_instance_id)
	])
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/menu_to_exit_smoke_%s.log" % stamp, FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	if is_instance_valid(_level):
		_level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _fail_count == 0 else 1)
