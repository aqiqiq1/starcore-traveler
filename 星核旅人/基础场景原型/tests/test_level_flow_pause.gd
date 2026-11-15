extends Node

## Narrow, critical smoke validation for level flow + the shared pause page.
##
## This is intentionally not a full playthrough: the user will play the levels
## and report feel issues.  The completion state below is set up through the
## real exit signal (not by walking from spawn), so it must not be reported as a
## full route.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/test_level_flow_pause.tscn

const LEVEL01_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL02_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const TEMP_AUDIO: String = "user://test_level_flow_pause_audio.cfg"
const TEMP_DISPLAY: String = "user://test_level_flow_pause_display.cfg"

var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []
var _level: Node = null
var _original_master_db: float = 0.0
var _original_master_mute: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_original_master_db = AudioServer.get_bus_volume_db(0)
	_original_master_mute = AudioServer.is_bus_mute(0)
	_remove_temp(TEMP_AUDIO)
	_remove_temp(TEMP_DISPLAY)
	_log("Star Core Traveler - level flow / pause critical smoke")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	await _test_load_initial_state_and_controls()
	await _test_pause_layers_both_levels()
	await _test_volume_persistence()
	await _test_completion_to_level02()
	await _test_return_to_title()
	await _test_level02_completion_return()
	await _test_display_pending_priority()
	_finish()


# --- 1/2. Load, initial state, permanent strip removal, pause layers ---------

func _test_load_initial_state_and_controls() -> void:
	_section("LOAD / INITIAL STATES / CONTROLS MOVE INTO PAUSE")
	await _new_level01(false)
	await _wait_intro_done()
	var hud: Level01HUD = _level.get_hud()
	var pause_menu: Node = _level.get_pause_menu()
	_check(not hud.has_controls_bar(), "level 01 no longer draws the permanent bottom strip")
	_check(pause_menu != null and bool(pause_menu.call("has_controls_section")),
		"level 01 pause page has a grouped controls section")
	var l1_controls: String = String(pause_menu.call("get_controls_text"))
	_check(l1_controls.contains("Esc") and l1_controls.contains("Q") and l1_controls.contains("F"),
		"level 01 pause controls list movement/Q/F/Esc", l1_controls.replace("\n", " | "))
	_check(not l1_controls.contains("释放 / 入仓") and not l1_controls.contains("E  "),
		"level 01 pause controls do not show the level-02 E action", l1_controls.replace("\n", " | "))
	await _free_level()

	await _new_level02()
	var hud2: Level02HUD = _level.get_hud()
	var pause2: Node = _level.get_pause_menu()
	_check(_level.get_player().global_position.is_equal_approx(Vector2(36.0, 320.0)),
		"level 02 starts at the real spawn (36,320)", str(_level.get_player().global_position))
	_check(_level.get_player().is_positive(), "level 02 starts in 辉相")
	_check(_level.get_start_bay().is_locked(), "level 02 start bay starts locked")
	_check(_level.get_target_bay().is_open_empty(), "level 02 target bay starts open/empty")
	_check(not get_tree().paused, "level 02 starts with the tree unpaused")
	_check(not hud2.has_controls_bar(), "level 02 no longer draws the permanent bottom strip")
	_check(pause2 != null and bool(pause2.call("has_controls_section")),
		"level 02 pause page has a grouped controls section")
	var l2_controls: String = String(pause2.call("get_controls_text"))
	_check(l2_controls.contains("释放 / 入仓") and l2_controls.contains("E"),
		"level 02 pause controls include E release/store", l2_controls.replace("\n", " | "))
	await _free_level()


func _test_pause_layers_both_levels() -> void:
	_section("ESC / PAUSE / SETTINGS / RESUME - BOTH LEVELS")
	await _new_level01(false)
	await _wait_intro_done()
	await _pause_settings_resume_cycle(true)
	await _free_level()

	await _new_level02()
	await _pause_settings_resume_cycle(false)
	await _free_level()


func _pause_settings_resume_cycle(expect_no_e: bool) -> void:
	var pause_menu: Node = _level.get_pause_menu()
	var hud: CanvasLayer = _level.get_hud()
	await _tap_key(KEY_ESCAPE)
	_check(get_tree().paused and bool(pause_menu.call("is_open")),
		"Esc opens the real pause page while paused")
	_check(hud.is_pause_visible(), "HUD pause state flag follows the pause page")
	_check(_focus_owner() == pause_menu.call("get_continue_button"),
		"pause opens with focus on 继续游戏", _focus_name())

	var before: Vector2 = _level.get_player().global_position
	Input.action_press(&"move_right")
	await _physics(10)
	Input.action_release(&"move_right")
	_check(_level.get_player().global_position.is_equal_approx(before),
		"pause freezes level physics while a direction is held", str(_level.get_player().global_position))

	await _tap_key(KEY_DOWN)
	_check(_focus_owner() == pause_menu.call("get_settings_button"),
		"Down moves focus from 继续 to 设置", _focus_name())
	await _tap_key(KEY_ENTER)
	await _settle(2)
	_check(bool(pause_menu.call("is_settings_open")), "Enter opens the shared settings page")
	_check(get_tree().paused, "settings stays paused")
	var host: StartMenu = pause_menu.call("get_settings_host") as StartMenu
	_check(host != null and host.is_settings_open(), "settings host uses the real StartMenu settings code")
	_check(not bool(pause_menu.call("is_pause_root_visible")),
		"settings layer hides the pause root buttons")
	await _tap_key(KEY_R)
	await _settle(2)
	_check(bool(pause_menu.call("is_settings_open")) and get_tree().paused,
		"R is ignored while the settings layer is open")
	_check(not _level.is_completed(), "R in settings does not restart or complete the level")

	await _tap_key(KEY_ESCAPE)
	await _settle(2)
	_check(not bool(pause_menu.call("is_settings_open")), "Esc returns from settings to the pause root")
	_check(get_tree().paused and bool(pause_menu.call("is_open")), "returning from settings keeps the tree paused")
	_check(_focus_owner() == pause_menu.call("get_settings_button"),
		"settings return focuses the settings button", _focus_name())

	await _tap_key(KEY_ESCAPE)
	await _settle(2)
	_check(not bool(pause_menu.call("is_open")) and not get_tree().paused,
		"Esc on the pause root resumes the level")
	_check(not hud.is_pause_visible(), "HUD pause flag clears on resume")

	# R on the normal pause root must still restart and close the page.
	await _tap_key(KEY_ESCAPE)
	await _settle(2)
	await _tap_key(KEY_R)
	await _settle(3)
	_check(not bool(pause_menu.call("is_open")) and not get_tree().paused,
		"R on the pause root restarts and closes the page")
	_check(not _level.is_completed(), "R on the pause root leaves a fresh level")

	if expect_no_e:
		var text: String = String(pause_menu.call("get_controls_text"))
		_check(not text.contains("释放 / 入仓"), "level 01 pause page still has no E row")


# --- 3. Volume config reuse across scenes ----------------------------------

func _test_volume_persistence() -> void:
	_section("MASTER VOLUME CONFIG REUSE ACROSS SCENES")
	await _new_level01(false)
	await _wait_intro_done()
	await _tap_key(KEY_ESCAPE)
	var pause_menu: Node = _level.get_pause_menu()
	pause_menu.call("open_settings")
	await _settle(2)
	var host: StartMenu = pause_menu.call("get_settings_host") as StartMenu
	host.get_slider().value = 37.0
	await _settle(2)
	_check(host.get_volume_percent() == 37, "pause settings changes the master volume to 37%",
		host.get_volume_label_text())
	await _free_level()

	await _new_level02()
	await _tap_key(KEY_ESCAPE)
	var pause2: Node = _level.get_pause_menu()
	pause2.call("open_settings")
	await _settle(2)
	var host2: StartMenu = pause2.call("get_settings_host") as StartMenu
	_check(host2.get_volume_percent() == 37,
		"the same audio config is read by level 02's pause settings",
		host2.get_volume_label_text())
	_check(host2.get_volume_label_text() == "37%", "level 02 shows the persisted percentage",
		host2.get_volume_label_text())
	await _free_level()


# --- 4. Completion -> real level 02 scene ----------------------------------

func _test_completion_to_level02() -> void:
	_section("LEVEL 01 COMPLETION -> REAL LEVEL 02 (SETUP COMPLETION STATE)")
	await _new_level01(false)
	await _wait_intro_done()
	var hud: Level01HUD = _level.get_hud()
	var pause_menu: Node = _level.get_pause_menu()
	# Setup only: the real exit signal enters completion; this is not a spawn
	# route or a full playthrough.
	_level.get_exit().player_reached_exit.emit()
	await _settle(3)
	_check(_level.is_completed() and hud.is_completion_visible(),
		"completion page is visible after the real exit signal")
	_check(hud.get_completion_primary_button() != null,
		"completion page has the real 进入第二关 button")
	_check(_focus_owner() == hud.get_completion_primary_button(),
		"completion focuses 进入第二关 for keyboard Enter", _focus_name())

	# The test root must survive change_scene_to_file: make the level the
	# current scene so only the level is freed, as in production.
	get_tree().current_scene = _level
	_send_key(KEY_ENTER, true)
	var accepted_once: bool = is_instance_valid(_level) and _level.is_next_level_started()
	var primary_disabled: bool = (
		is_instance_valid(hud) and hud.get_completion_primary_button().disabled
	)
	_send_key(KEY_ENTER, false)
	_check(accepted_once, "Enter accepts the next-level command once")
	_check(primary_disabled,
		"the next-level button disables immediately after the single accepted press")
	await _physics(10)
	await _settle(4)

	var new_scene: Node = get_tree().current_scene
	_check(new_scene != null and new_scene is Level02,
		"production change_scene_to_file landed on Level02", str(new_scene))
	_check(not is_instance_valid(_level), "the old level instance was freed by the scene change")
	_level = new_scene
	_check(not get_tree().paused, "the new level tree is not paused")
	_check(_level.get_player().global_position.is_equal_approx(Vector2(36.0, 320.0)),
		"level 02 initial spawn is (36,320)", str(_level.get_player().global_position))
	_check(_level.get_player().is_positive(), "level 02 initial polarity is 辉相")
	_check(_level.get_start_bay().is_locked(), "level 02 start bay is locked")
	_check(_level.get_target_bay().is_open_empty(), "level 02 target bay is empty")
	_check(_level.get_pause_menu() != null, "the new level has its own pause page")
	var l2_hud: Level02HUD = _level.get_hud()
	_check(l2_hud.visible and not l2_hud.is_completion_visible(),
		"no old completion overlay is shown in the new level")
	_check(get_tree().root.get_children().filter(
		func(node: Node) -> bool: return node.name == "Level02").size() == 1,
		"exactly one Level02 root instance exists after the single transition")
	await _free_level()


# --- 5. Pause -> real title ------------------------------------------------

func _test_return_to_title() -> void:
	_section("LEVEL 02 PAUSE -> REAL TITLE / MENU")
	await _new_level02()
	await _tap_key(KEY_ESCAPE)
	var pause_menu: Node = _level.get_pause_menu()
	_check(bool(pause_menu.call("is_open")), "pause opens for the return-to-title check")
	await _tap_key(KEY_DOWN)
	await _tap_key(KEY_DOWN)
	await _tap_key(KEY_DOWN)
	_check(_focus_owner() == pause_menu.call("get_return_button"),
		"Down reaches 返回主界面", _focus_name())
	get_tree().current_scene = _level
	await _tap_key(KEY_ENTER)
	await _settle(10)
	await _physics(4)
	var new_scene: Node = get_tree().current_scene
	_check(new_scene != null and new_scene is Level01,
		"return goes to the real Level01 scene", str(new_scene))
	_check(not is_instance_valid(_level), "the paused level was freed by the scene change")
	_level = new_scene
	_check(not get_tree().paused, "title screen is not left paused")
	_check(_level.get_menu() != null and _level.get_menu().is_menu_open(),
		"returned Level01 shows the initial title menu")
	_check(_level.get_menu().get_phase_name() == "menu",
		"returned title menu is in the initial menu phase", _level.get_menu().get_phase_name())
	_check(not _level.get_hud().visible and not _level.get_player().visible,
		"returned title hides the gameplay HUD and player")
	await _free_level()


func _test_level02_completion_return() -> void:
	_section("LEVEL 02 COMPLETION -> REAL TITLE (SETUP COMPLETION STATE)")
	await _new_level02()
	# Setup only: lock the target bay and place the player in the exit trigger;
	# this is not a spawn-to-exit playthrough.
	var target = _level.get_target_bay()
	var started: bool = target.start_store_core(true)
	target.finish_store()
	await _settle(2)
	_check(started and target.is_locked(), "setup locks the level-02 target bay")
	_level.get_player().global_position = _level.get_exit().global_position
	_level._try_complete_at_exit()
	await _settle(4)
	var hud: Level02HUD = _level.get_hud()
	_check(_level.is_completed() and hud.is_completion_visible(),
		"level-02 completion page is visible after the real completion path")
	var primary: PixelMenuButton = hud.get_completion_primary_button()
	_check(primary != null and primary.text == "返回主界面",
		"level-02 completion primary is 返回主界面, not a next level",
		primary.text if primary != null else "<none>")
	_check(hud.get_completion_return_button() == primary,
		"the level-02 return button is wired to the completion primary")
	_check(_focus_owner() == primary, "level-02 completion focuses 返回主界面", _focus_name())

	get_tree().current_scene = _level
	await _tap_key(KEY_ENTER)
	await _settle(10)
	var new_scene: Node = get_tree().current_scene
	_check(new_scene != null and new_scene is Level01,
		"level-02 completion returns to the real Level01 title", str(new_scene))
	_check(not is_instance_valid(_level), "the completed level-02 instance was freed")
	_level = new_scene
	_check(not get_tree().paused and _level.get_menu().is_menu_open(),
		"level-02 completion reaches the initial title menu")
	await _free_level()


# --- 6. Display pending Esc priority ---------------------------------------

func _test_display_pending_priority() -> void:
	_section("DISPLAY PENDING: ESC CANCELS BEFORE CLOSING SETTINGS")
	await _new_level02()
	await _tap_key(KEY_ESCAPE)
	var pause_menu: Node = _level.get_pause_menu()
	pause_menu.call("open_settings")
	await _settle(2)
	_check(bool(pause_menu.call("is_settings_open")), "settings open for the pending-priority check")
	var host: StartMenu = pause_menu.call("get_settings_host") as StartMenu
	var display: DisplaySettingsController = host.get_display_controller()
	display.apply_override = func(_mode: int, _size: Vector2i, _position: Vector2i, _center: bool) -> Dictionary:
		return {"ok": true, "message": ""}
	var target_mode: int = (
		DisplayOptions.Mode.FULLSCREEN
		if display.get_active_mode() == DisplayOptions.Mode.WINDOWED
		else DisplayOptions.Mode.WINDOWED
	)
	var result: Dictionary = display.begin_apply(target_mode, display.get_active_window_size())
	await _settle(2)
	_check(bool(result.get("ok", false)) and display.is_pending(),
		"partial setup leaves a display change pending", str(result))
	_check(get_tree().paused, "display pending keeps the game paused")

	await _tap_key(KEY_ESCAPE)
	await _settle(2)
	_check(not display.is_pending(), "Esc cancels the pending display change first")
	_check(bool(pause_menu.call("is_settings_open")),
		"the settings page stays open after Esc cancels the pending display")
	_check(get_tree().paused, "the game is still paused after the display cancel")
	_check(not bool(pause_menu.call("is_pause_root_visible")), "the pause root did not intercept the same Esc press")

	await _tap_key(KEY_ESCAPE)
	await _settle(2)
	_check(not bool(pause_menu.call("is_settings_open")) and bool(pause_menu.call("is_open")),
		"the next Esc only closes settings back to the paused root")
	_check(get_tree().paused, "closing settings does not unpause")

	await _tap_key(KEY_ESCAPE)
	await _settle(2)
	_check(not bool(pause_menu.call("is_open")) and not get_tree().paused,
		"one more Esc resumes from the pause root")
	display.apply_override = Callable()
	await _free_level()


# --- Harness ---------------------------------------------------------------

func _new_level01(menu_enabled: bool) -> void:
	await _clear_scene()
	_level = LEVEL01_SCENE.instantiate() as Level01
	_level.enable_start_menu = menu_enabled
	if menu_enabled:
		var menu: StartMenu = _level.get_node("StartMenu") as StartMenu
		menu.audio_settings_path = TEMP_AUDIO
		menu.display_settings_path = TEMP_DISPLAY
	else:
		_level.pause_audio_settings_path = TEMP_AUDIO
		_level.pause_display_settings_path = TEMP_DISPLAY
	get_tree().root.add_child(_level)
	await _physics(6)
	await _settle(2)


func _new_level02() -> void:
	await _clear_scene()
	_level = LEVEL02_SCENE.instantiate() as Level02
	_level.pause_audio_settings_path = TEMP_AUDIO
	_level.pause_display_settings_path = TEMP_DISPLAY
	get_tree().root.add_child(_level)
	await _physics(8)
	await _settle(2)


func _clear_scene() -> void:
	if is_instance_valid(_level):
		if get_tree().current_scene == _level:
			get_tree().current_scene = null
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null
	get_tree().paused = false
	get_tree().current_scene = null


func _free_level() -> void:
	get_tree().paused = false
	if is_instance_valid(_level):
		if get_tree().current_scene == _level:
			get_tree().current_scene = null
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null


func _wait_intro_done() -> void:
	for _i: int in range(300):
		await get_tree().process_frame
		if _level != null and not _level.is_intro_active():
			break
	await _physics(6)


func _tap_key(key: Key) -> void:
	_send_key(key, true)
	await get_tree().process_frame
	_send_key(key, false)
	await get_tree().process_frame


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _settle(frames: int) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _physics(frames: int) -> void:
	for _i: int in range(frames):
		await get_tree().physics_frame


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


func _focus_name() -> String:
	var owner: Control = _focus_owner()
	return owner.name if owner != null else "<none>"


func _remove_temp(path: String) -> void:
	var global: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)


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


func _finish() -> void:
	get_tree().paused = false
	AudioServer.set_bus_mute(0, _original_master_mute)
	AudioServer.set_bus_volume_db(0, _original_master_db)
	_remove_temp(TEMP_AUDIO)
	_remove_temp(TEMP_DISPLAY)
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count])
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/level_flow_pause_critical.log", FileAccess.WRITE
	)
	if file != null:
		file.store_string("\n".join(_log_lines) + "\n")
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
