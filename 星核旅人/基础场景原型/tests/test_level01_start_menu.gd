extends Node

## End-to-end acceptance for the integrated level 01 start menu.
##
## Everything below drives the real level_01.tscn and the real input path:
##   * InputEventMouseButton / InputEventMouseMotion through the root viewport
##   * InputEventKey through Input.parse_input_event (as in the existing suite)
##   * the real Master audio bus and a temporary user:// config path
## No test calls StartMenu._on_start_pressed(), no test bakes a fake transition,
## and the user's real audio settings file / Master volume are restored.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const TEMP_AUDIO_PATH: String = "user://test_start_menu_audio.cfg"
const TEMP_DISPLAY_PATH: String = "user://test_start_menu_display.cfg"

var _level: Level01
var _menu: StartMenu
var _player: PrototypePlayer
var _hud: Level01HUD
var _world: Node2D
var _menu_camera: Camera2D
var _player_camera: Camera2D
var _background: CloudRuinsDS03

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
	_log("Star Core Traveler - integrated start menu E2E")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"], DisplayServer.get_name()
	])

	await _test_initial_menu_and_focus()
	await _test_settings_audio_and_focus()
	await _test_quit_entry_guards()
	await _test_audio_config_robustness()
	await _test_mouse_start_transition_and_gameplay()
	await _test_keyboard_start_pause_focus_and_restart()
	await _test_scene_reload_returns_to_menu()

	await _finish()


# --- Test groups -----------------------------------------------------------

func _test_initial_menu_and_focus() -> void:
	_section("INITIAL MENU / BACKGROUND / FOCUS")
	await _new_level(true)
	await _settle_frames(3)
	var bg_time: float = _background.get_background_time()
	var player_start: Vector2 = _player.global_position
	var checkpoint_active: bool = _level.get_checkpoint().is_activated()

	_check(_menu.get_phase_name() == "menu", "level 01 opens in the integrated menu", _menu.get_phase_name())
	_check(_level.is_start_menu_enabled(), "production menu flag is enabled in this instance")
	_check(_menu.is_menu_open() and not _menu.is_settings_open(), "menu state is open with settings closed")
	_check(_level.is_intro_active() == false, "opening auto-run has not started behind the menu")
	_check(_level.get_intro_start_count() == 0, "no intro was scheduled during menu startup", str(_level.get_intro_start_count()))
	_check(not _world.visible, "World is hidden while the menu is shown")
	_check(not _player.visible, "Player is hidden while the menu is shown")
	_check(not _hud.visible, "HUD is hidden while the menu is shown")
	_check(_world.process_mode == Node.PROCESS_MODE_DISABLED, "World processing is disabled in the menu", str(_world.process_mode))
	_check(_player.process_mode == Node.PROCESS_MODE_DISABLED, "Player processing is disabled in the menu", str(_player.process_mode))
	_check(_menu_camera.enabled, "temporary menu camera is current")
	_check(not _player_camera.enabled, "player camera is disabled for the menu")
	_check(_menu_camera.get_screen_center_position().is_equal_approx(Vector2(320.0, -180.0)), "menu camera starts above the level", str(_menu_camera.get_screen_center_position()))

	var start_rect: Rect2 = _menu.get_start_button().get_global_rect()
	var settings_rect: Rect2 = _menu.get_settings_button().get_global_rect()
	var quit_rect: Rect2 = _menu.get_quit_button().get_global_rect()
	_check(start_rect.is_equal_approx(Rect2(256.0, 138.0, 128.0, 36.0)), "start hot zone matches V1 128x36 at (256,138)", str(start_rect))
	_check(settings_rect.is_equal_approx(Rect2(294.0, 184.0, 52.0, 20.0)), "settings hot zone sits on the V1 row", str(settings_rect))
	_check(quit_rect.is_equal_approx(Rect2(284.0, 212.0, 72.0, 20.0)), "quit hot zone is centred under settings at (284,212)", str(quit_rect))
	_check(
		not start_rect.intersects(settings_rect)
		and not start_rect.intersects(quit_rect)
		and not settings_rect.intersects(quit_rect),
		"start, settings and quit hot zones do not overlap"
	)
	_check(not _menu.get_quit_button().disabled, "quit entry starts enabled")
	var base_ui: TextureRect = _menu.get_node("StartMenuRoot/MenuGroup/BaseUI") as TextureRect
	_check(base_ui != null and base_ui.texture.get_size() == Vector2(640.0, 360.0), "runtime menu art is a 640x360 texture")
	_check(base_ui != null and base_ui.texture.get_image().get_pixel(0, 0).a == 0.0, "runtime menu art has no baked background")
	var quit_row: TextureRect = _menu.get_node("StartMenuRoot/MenuGroup/QuitRow") as TextureRect
	_check(quit_row != null and quit_row.texture.get_size() == Vector2(640.0, 360.0), "quit row is a separate 640x360 overlay texture")
	_check(quit_row != null and quit_row.texture.get_image().get_pixel(0, 0).a == 0.0, "quit row texture has no baked background")
	var quit_used: Rect2i = quit_row.texture.get_image().get_used_rect()
	_check(absi(quit_used.get_center().x - 320) <= 1, "quit label is horizontally centred under settings", str(quit_used))
	_check(quit_used.size.y <= 14 and quit_used.size.x <= 56, "quit label uses 12px Fusion Pixel text", str(quit_used.size))
	_check(quit_used.position.y >= 212 and quit_used.end.y <= 232, "quit label ink sits inside its 20px hot zone", str(quit_used))
	_check(_menu.get_node("StartMenuRoot/MenuGroup/FocusStart").visible, "start focus has a visible accent")
	_check(not _menu.get_node("StartMenuRoot/MenuGroup/FocusSettings").visible, "settings focus accent is hidden initially")
	_check(not _menu.get_node("StartMenuRoot/MenuGroup/FocusQuit").visible, "quit focus accent is hidden initially")

	await get_tree().create_timer(0.32).timeout
	_check(_background.get_background_time() > bg_time + 0.15, "DS03 background keeps animating under the menu", "%.2f -> %.2f" % [bg_time, _background.get_background_time()])
	_check(_player.global_position.is_equal_approx(player_start), "Player does not update behind the menu", str(_player.global_position))
	_check(_level.get_checkpoint().is_activated() == checkpoint_active and not checkpoint_active, "no checkpoint triggers behind the menu")
	var prompt_layers_hidden: bool = true
	for stele_node: Node in get_tree().get_nodes_in_group(&"tutorial_stele"):
		var prompt_layer: CanvasLayer = stele_node.get_node_or_null("PromptLayer") as CanvasLayer
		if prompt_layer == null or prompt_layer.visible:
			prompt_layers_hidden = false
	_check(prompt_layers_hidden, "stele prompt CanvasLayers are hidden behind the menu")

	# Keyboard focus navigation and hover accents, without starting the game.
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	_check(focus_owner == _menu.get_start_button(), "start button owns initial keyboard focus", str(focus_owner))
	await _tap_key(KEY_DOWN)
	await _settle_frames(1)
	_check(get_viewport().gui_get_focus_owner() == _menu.get_settings_button(), "Down moves focus to settings", str(get_viewport().gui_get_focus_owner()))
	_check(_menu.get_node("StartMenuRoot/MenuGroup/FocusSettings").visible, "settings focus is visible after Down")
	await _tap_key(KEY_DOWN)
	await _settle_frames(1)
	_check(get_viewport().gui_get_focus_owner() == _menu.get_quit_button(), "Down moves focus from settings to quit", str(get_viewport().gui_get_focus_owner()))
	_check(_menu.get_node("StartMenuRoot/MenuGroup/FocusQuit").visible, "quit focus is visible after the second Down")
	_check(not _menu.get_node("StartMenuRoot/MenuGroup/FocusSettings").visible, "settings focus accent hides on quit focus")
	await _tap_key(KEY_DOWN)
	await _settle_frames(1)
	_check(get_viewport().gui_get_focus_owner() == _menu.get_start_button(), "Down wraps from quit back to start", str(get_viewport().gui_get_focus_owner()))
	await _tap_key(KEY_UP)
	await _settle_frames(1)
	_check(get_viewport().gui_get_focus_owner() == _menu.get_quit_button(), "Up wraps from start to quit", str(get_viewport().gui_get_focus_owner()))
	await _tap_key(KEY_UP)
	await _settle_frames(1)
	_check(get_viewport().gui_get_focus_owner() == _menu.get_settings_button(), "Up moves from quit to settings", str(get_viewport().gui_get_focus_owner()))
	await _tap_key(KEY_UP)
	await _settle_frames(1)
	_check(get_viewport().gui_get_focus_owner() == _menu.get_start_button(), "Up moves back to start", str(get_viewport().gui_get_focus_owner()))
	await _tap_key(KEY_TAB)
	await _settle_frames(1)
	_check(get_viewport().gui_get_focus_owner() == _menu.get_settings_button(), "Tab reaches the settings entry", str(get_viewport().gui_get_focus_owner()))
	await _tap_key(KEY_TAB)
	await _settle_frames(1)
	_check(get_viewport().gui_get_focus_owner() == _menu.get_quit_button(), "Tab reaches the quit entry", str(get_viewport().gui_get_focus_owner()))
	await _tap_key(KEY_TAB)
	await _settle_frames(1)
	var tab_owner: Control = get_viewport().gui_get_focus_owner()
	_check(tab_owner == _menu.get_start_button(), "Tab wraps from quit to start", str(tab_owner))

	_mouse_move(_menu.get_settings_button().get_global_rect().get_center())
	await _settle_frames(2)
	_check(_menu.get_node("StartMenuRoot/MenuGroup/FocusSettings").visible, "mouse hover shows the settings accent")
	_mouse_move(_menu.get_quit_button().get_global_rect().get_center())
	await _settle_frames(2)
	_check(_menu.get_node("StartMenuRoot/MenuGroup/FocusQuit").visible, "mouse hover shows the quit accent")
	_check(not _menu.get_node("StartMenuRoot/MenuGroup/FocusSettings").visible, "settings hover accent hides on quit hover")
	_mouse_move(Vector2(20.0, 40.0))
	await _settle_frames(2)
	_check(not _menu.get_node("StartMenuRoot/MenuGroup/FocusQuit").visible, "quit hover accent hides after the pointer leaves")

	# R and Esc in the menu must not start, reset, or pause.
	await _tap_key(KEY_R)
	await _settle_frames(1)
	_check(_menu.get_phase_name() == "menu" and _level.get_intro_start_count() == 0, "R is ignored in the main menu")
	await _tap_key(KEY_ESCAPE)
	await _settle_frames(1)
	_check(
		not get_tree().paused and _menu.get_phase_name() == "menu"
		and not _menu.is_quit_locked(),
		"Esc in the main menu does not pause, start, or quit"
	)
	_check(not _level.is_intro_active() and _player.global_position.is_equal_approx(player_start), "menu input never leaks into the player")


func _test_settings_audio_and_focus() -> void:
	_section("SETTINGS / MASTER VOLUME / RETURN")
	await _new_level(true)
	await _settle_frames(3)
	var bg_before: float = _background.get_background_time()

	_mouse_move(_menu.get_settings_button().get_global_rect().get_center())
	await _settle_frames(1)
	await _mouse_click(_menu.get_settings_button().get_global_rect().get_center())
	await _settle_frames(3)
	_check(_menu.is_settings_open(), "real mouse click opens settings")
	_check(get_viewport().gui_get_focus_owner() == _menu.get_slider(), "slider takes focus when settings opens", str(get_viewport().gui_get_focus_owner()))
	_check(not get_tree().paused, "settings does not pause the background")
	_check(not _world.visible and not _player.visible and not _hud.visible, "settings keeps the world/player/HUD hidden")
	_check(_level.get_intro_start_count() == 0, "settings never starts the intro")
	_check(_menu.get_volume_percent() == 100, "missing config defaults to 100 percent", str(_menu.get_volume_percent()))
	_check(_menu.get_volume_label_text() == "100%", "settings shows the percentage", _menu.get_volume_label_text())
	await get_tree().create_timer(0.28).timeout
	_check(_background.get_background_time() > bg_before + 0.1, "DS03 background animates under settings", "%.2f -> %.2f" % [bg_before, _background.get_background_time()])

	# The modal blocks both the start hot zone and keyboard accept.
	await _mouse_click(Vector2(320.0, 156.0))
	await _settle_frames(2)
	_check(_menu.is_settings_open() and _menu.get_start_request_count() == 0, "clicking through settings cannot start the game")
	await _tap_key(KEY_ENTER)
	await _settle_frames(1)
	_check(_menu.is_settings_open() and _menu.get_start_request_count() == 0, "Enter on the slider cannot start the game")

	# Q / Space while settings is open must not reach the hidden world.
	var settings_player_pos: Vector2 = _player.global_position
	var settings_polarity: bool = _player.is_positive()
	_key(KEY_Q, true)
	_key(KEY_SPACE, true)
	Input.action_press(&"move_right")
	await _settle_frames(2)
	_check(_player.is_positive() == settings_polarity, "Q in settings cannot change polarity")
	_check(_player.global_position.is_equal_approx(settings_player_pos), "direction/space in settings cannot move the hidden player", str(_player.global_position))
	_check(not _level.is_intro_active() and _menu.get_start_request_count() == 0, "settings input never starts the world")
	_key(KEY_Q, false)
	_key(KEY_SPACE, false)
	Input.action_release(&"move_right")
	await _settle_frames(1)

	var master: int = AudioServer.get_bus_index(&"Master")
	_check(master >= 0, "Master bus exists")
	await _mouse_click(_slider_point(0.0))
	await _settle_frames(2)
	_check(_menu.get_volume_percent() == 0, "dragging to the left end reaches 0%", str(_menu.get_volume_percent()))
	_check(AudioServer.is_bus_mute(master), "0% mutes the Master bus")
	_check(_menu.get_volume_label_text() == "0%", "percentage label reads 0%", _menu.get_volume_label_text())
	_check(_temp_config_value() == 0.0, "0% is written to the temporary config", str(_temp_config_value()))

	await _mouse_click(_slider_point(1.0))
	await _settle_frames(2)
	_check(_menu.get_volume_percent() == 100, "dragging to the right end reaches 100%", str(_menu.get_volume_percent()))
	_check(not AudioServer.is_bus_mute(master), "100% unmutes the Master bus")
	_check(absf(AudioServer.get_bus_volume_db(master)) < 0.01, "100% restores 0 dB", str(AudioServer.get_bus_volume_db(master)))
	_check(_temp_config_value() == 100.0, "100% is written to the temporary config")

	await _tap_key(KEY_HOME)
	await _settle_frames(1)
	_check(_menu.get_volume_percent() == 0, "Home sets the slider to 0")
	await _tap_key(KEY_END)
	await _settle_frames(1)
	_check(_menu.get_volume_percent() == 100, "End restores the slider to 100")

	# Focus loss during a drag must cancel it and leave no latched motion.
	_mouse_move(_slider_point(0.5))
	_mouse_button(_slider_point(0.5), true)
	await _settle_frames(1)
	_check(_menu.get_slider().is_dragging(), "mouse press starts a real slider drag")
	var drag_value: int = _menu.get_volume_percent()
	get_window().focus_exited.emit()
	await _settle_frames(2)
	_check(not _menu.get_slider().is_dragging(), "focus loss cancels the slider drag")
	_mouse_move(_slider_point(0.0))
	await _settle_frames(1)
	_check(_menu.get_volume_percent() == drag_value, "motion after focus loss cannot move the slider", "%d -> %d" % [drag_value, _menu.get_volume_percent()])
	_mouse_button(_slider_point(0.0), false)
	await _settle_frames(1)
	_check(_menu.is_settings_open() and not get_tree().paused, "focus loss inside settings does not close or pause")

	# A held keyboard key must not keep changing the slider after focus loss.
	await _mouse_click(_slider_point(0.5))
	await _settle_frames(1)
	var held_value: int = _menu.get_volume_percent()
	_key(KEY_RIGHT, true)
	await _settle_frames(1)
	get_window().focus_exited.emit()
	await _settle_frames(2)
	var after_held_loss: int = _menu.get_volume_percent()
	await get_tree().create_timer(0.18).timeout
	_check(_menu.get_volume_percent() == after_held_loss, "held arrow key does not repeat after focus loss", "%d -> %d" % [after_held_loss, _menu.get_volume_percent()])
	_key(KEY_RIGHT, false)
	await _settle_frames(1)
	_check(_menu.get_volume_percent() >= held_value, "a single held-key step still applied before focus loss")

	# Return by mouse; focus goes back to the settings entry.
	await _mouse_click(_menu.get_return_button().get_global_rect().get_center())
	await _settle_frames(3)
	_check(not _menu.is_settings_open(), "real mouse click on 返回 closes settings")
	_check(_menu.get_phase_name() == "menu" and _menu.get_start_request_count() == 0, "return does not start the game")
	_check(get_viewport().gui_get_focus_owner() == _menu.get_settings_button(), "focus returns to the settings entry", str(get_viewport().gui_get_focus_owner()))

	# Enter opens settings; Tab cycles through the expanded display rows to 返回;
	# Enter closes without a second accept.
	await _tap_key(KEY_ENTER)
	await _settle_frames(2)
	_check(_menu.is_settings_open(), "Enter reopens settings from the restored focus")
	var reached_return: bool = false
	for _tab_index: int in range(12):
		await _tap_key(KEY_TAB)
		await _settle_frames(1)
		if get_viewport().gui_get_focus_owner() == _menu.get_return_button():
			reached_return = true
			break
	_check(reached_return, "Tab reaches 返回", str(get_viewport().gui_get_focus_owner()))
	await _tap_key(KEY_ENTER)
	await _settle_frames(3)
	_check(not _menu.is_settings_open(), "Enter on 返回 closes settings")
	_check(_menu.get_phase_name() == "menu" and _menu.get_start_request_count() == 0, "the closing Enter does not also start the game")
	_check(_level.get_intro_start_count() == 0, "settings close never begins the opening run")

	# Esc route.
	await _mouse_click(_menu.get_settings_button().get_global_rect().get_center())
	await _settle_frames(2)
	await _tap_key(KEY_ESCAPE)
	await _settle_frames(1)
	_check(not _menu.is_settings_open() and _menu.get_phase_name() == "menu", "Esc closes settings back to the menu")
	_check(not get_tree().paused and _menu.get_start_request_count() == 0, "Esc in settings does not pause or start")


func _test_quit_entry_guards() -> void:
	_section("QUIT ENTRY / SETTINGS AND DISPLAY-PENDING GUARDS")
	await _new_level(true)
	await _settle_frames(3)
	_check(_menu.get_phase_name() == "menu" and not _menu.is_quit_locked(), "fresh menu has an unlocked quit entry")

	# 设置打开时，退出入口隐藏且 disabled，真实点击其坐标不能穿透。
	await _mouse_click(_menu.get_settings_button().get_global_rect().get_center())
	await _settle_frames(3)
	_check(_menu.is_settings_open(), "settings opens for the quit guard check")
	_check(_menu.get_quit_button().disabled, "quit entry is disabled while settings is open")
	if _menu.is_settings_open() and _menu.get_quit_button().disabled:
		await _mouse_click(_menu.get_quit_button().get_global_rect().get_center())
		await _settle_frames(2)
		_check(
			_menu.is_settings_open() and not _menu.is_quit_locked()
			and _menu.get_phase_name() == "menu",
			"a real click on the quit area behind settings cannot quit"
		)
	else:
		_check(false, "a real click on the quit area behind settings cannot quit", "settings guard was not established")

	await _tap_key(KEY_ESCAPE)
	await _settle_frames(2)
	_check(not _menu.is_settings_open(), "Esc returns from settings")
	_check(not _menu.get_quit_button().disabled, "closing settings re-enables the quit entry")
	_check(get_viewport().gui_get_focus_owner() == _menu.get_settings_button(), "closing settings focuses 设置, not 退出游戏", str(get_viewport().gui_get_focus_owner()))
	_check(_menu.get_node("StartMenuRoot/MenuGroup/FocusSettings").visible, "closing settings shows the settings focus accent")
	_check(not _menu.get_node("StartMenuRoot/MenuGroup/FocusQuit").visible, "closing settings does not focus the quit row")

	# 显示设置待确认时，退出 handler 必须被 pending 守卫拦截。
	var display: DisplaySettingsController = _menu.get_display_controller()
	display.apply_override = func(
		_mode: int, _size: Vector2i, _position: Vector2i, _center: bool
	) -> Dictionary:
		return {"ok": true, "message": ""}
	var target_size: Vector2i = Vector2i.ZERO
	for candidate: Vector2i in DisplayOptions.CANDIDATES:
		if candidate != display.get_active_window_size() and display.is_size_available(candidate):
			target_size = candidate
			break
	var apply_result: Dictionary = {}
	if target_size != Vector2i.ZERO:
		apply_result = display.begin_apply(DisplayOptions.Mode.WINDOWED, target_size)
	else:
		apply_result = display.begin_apply(
			DisplayOptions.Mode.FULLSCREEN, display.get_active_window_size()
		)
	_check(bool(apply_result.get("ok", false)) and display.is_pending(), "display confirmation is pending for the quit guard", str(apply_result))
	if display.is_pending():
		await _mouse_click(_menu.get_quit_button().get_global_rect().get_center())
		await _settle_frames(2)
		_check(
			_menu.get_phase_name() == "menu" and not _menu.is_quit_locked()
			and _menu.get_start_request_count() == 0,
			"a real quit click is blocked while display confirmation is pending"
		)
		display.cancel_pending("test")
	else:
		_check(false, "a real quit click is blocked while display confirmation is pending", "pending guard was not established")
	display.apply_override = Callable()
	await _settle_frames(2)
	_check(not display.is_pending(), "display pending state is cleared after the guard check")
	_check(not _menu.get_quit_button().disabled, "quit entry is enabled again after display pending clears")
	_check(not _menu.is_quit_locked(), "the blocked quit press never latched the quit lock")


func _test_audio_config_robustness() -> void:
	_section("AUDIO CONFIG / CLAMP / FAILURE")
	var master: int = AudioServer.get_bus_index(&"Master")

	_remove_temp_audio()
	await _new_level(true)
	await _settle_frames(2)
	_check(_menu.get_volume_percent() == 100, "missing config safely defaults to 100", str(_menu.get_volume_percent()))
	_check(not AudioServer.is_bus_mute(master), "missing config leaves Master unmuted")

	_write_config_text("this is not a ConfigFile\n%%% broken")
	await _new_level(true)
	await _settle_frames(2)
	_check(_menu.get_volume_percent() == 100, "corrupt config safely defaults to 100", str(_menu.get_volume_percent()))
	_check(not AudioServer.is_bus_mute(master), "corrupt config does not mute Master")

	_write_config_value(250.0)
	await _new_level(true)
	await _settle_frames(2)
	_check(_menu.get_volume_percent() == 100, "volume above 100 clamps to 100", str(_menu.get_volume_percent()))
	_check(not AudioServer.is_bus_mute(master) and absf(AudioServer.get_bus_volume_db(master)) < 0.01, "clamped 100 applies 0 dB")

	_write_config_value(-30.0)
	await _new_level(true)
	await _settle_frames(2)
	_check(_menu.get_volume_percent() == 0, "negative volume clamps to 0", str(_menu.get_volume_percent()))
	_check(AudioServer.is_bus_mute(master), "clamped 0 mutes Master")

	_write_config_value(37.0)
	await _new_level(true)
	await _settle_frames(2)
	_check(_menu.get_volume_percent() == 37, "saved 37 percent is restored", str(_menu.get_volume_percent()))
	_check(not AudioServer.is_bus_mute(master), "saved nonzero volume is unmuted")
	_check(absf(AudioServer.get_bus_volume_db(master) - linear_to_db(0.37)) < 0.05, "saved volume applies the matching dB", str(AudioServer.get_bus_volume_db(master)))

	_write_config_text("[audio]\nmaster_volume=\"loud\"\n")
	await _new_level(true)
	await _settle_frames(2)
	_check(_menu.get_volume_percent() == 100, "non-numeric volume safely defaults to 100", str(_menu.get_volume_percent()))
	_check(not AudioServer.is_bus_mute(master), "non-numeric config does not mute Master")


func _test_mouse_start_transition_and_gameplay() -> void:
	_section("REAL MOUSE START / TIMING / CAMERA / CONTROL HANDOFF")
	_remove_temp_audio()
	await _new_level(true)
	await _settle_frames(3)
	var player_start: Vector2 = _player.global_position
	var start_button_center: Vector2 = _menu.get_start_button().get_global_rect().get_center()
	var t_click: int = Time.get_ticks_msec()
	await _mouse_click(start_button_center)
	await _settle_frames(1)
	_check(_menu.get_phase_name() == "title_fade", "real mouse click enters title fade", _menu.get_phase_name())
	_check(_menu.get_start_request_count() == 1, "one accepted start request", str(_menu.get_start_request_count()))
	_check(_menu.is_start_locked(), "start button locks after the first press")
	_check(
		_menu.get_start_button().disabled and _menu.get_settings_button().disabled
		and _menu.get_quit_button().disabled,
		"all three menu hot zones are disabled while starting"
	)
	_check(not _menu.is_quit_locked(), "starting does not latch the quit handler")
	_check(not _level.is_intro_active(), "intro is postponed until the camera settles")
	_check(not _world.visible and not _player.visible and not _hud.visible, "title fade still shows only background and UI")

	# Duplicate input during the fade must be ignored, including the quit row.
	await _mouse_click(start_button_center)
	await _tap_key(KEY_ENTER)
	if _menu.get_quit_button().disabled:
		await _mouse_click(_menu.get_quit_button().get_global_rect().get_center())
		await _tap_key(KEY_ENTER)
		await _settle_frames(1)
		_check(
			_menu.get_phase_name() == "title_fade" and not _menu.is_quit_locked(),
			"quit area/Enter during the start fade cannot quit"
		)
	else:
		_check(false, "quit area/Enter during the start fade cannot quit", "quit was not disabled by the start")
	_check(_menu.get_start_request_count() == 1, "duplicate mouse/Enter keeps a single start", str(_menu.get_start_request_count()))
	await _tap_key(KEY_R)
	await _settle_frames(1)
	_check(_level.get_intro_start_count() == 0 and _menu.get_phase_name() != "done", "R during the transition is ignored")

	# Q / Space / direction held during the transition must not become gameplay.
	var polarity_before_transition: bool = _player.is_positive()
	_key(KEY_Q, true)
	_key(KEY_SPACE, true)
	Input.action_press(&"move_right")
	await _settle_frames(2)
	_check(_player.is_positive() == polarity_before_transition, "Q held during the transition does not toggle polarity")
	_check(_player.global_position.is_equal_approx(player_start), "direction/space held during the transition do not move the player", str(_player.global_position))
	_check(not _level.is_intro_active(), "held transition input does not start the intro early")
	_key(KEY_Q, false)
	_key(KEY_SPACE, false)
	Input.action_release(&"move_right")
	await _settle_frames(1)

	var samples: Array[Dictionary] = []
	var phase_times: Dictionary = {"title_fade": t_click}
	var last_phase: String = "title_fade"
	var timeout_ms: int = 12000
	while _menu.get_phase_name() != "done" and Time.get_ticks_msec() - t_click < timeout_ms:
		await get_tree().process_frame
		var phase: String = _menu.get_phase_name()
		var now: int = Time.get_ticks_msec()
		if phase != last_phase:
			phase_times[phase] = now
			last_phase = phase
		var center: Vector2 = _menu_camera.get_screen_center_position()
		samples.append({
			"phase": phase,
			"center": center,
			"terrain_y": 300.0 - center.y + 180.0,
			"world": _world.visible,
			"player": _player.visible,
			"hud": _hud.visible,
			"intro": _level.is_intro_active(),
			"pos": _player.global_position,
			"time": now,
		})
	_check(_menu.get_phase_name() == "done", "transition reaches the entry state", _menu.get_phase_name())
	_check(_menu.get_quit_button().disabled and not _menu.is_quit_locked(), "quit entry stays disabled after entering gameplay")
	_check(phase_times.has("camera_pan") and phase_times.has("settle") and phase_times.has("done"), "all transition phases were observed", str(phase_times.keys()))
	var fade_ms: int = int(phase_times.get("camera_pan", 0)) - int(phase_times.get("title_fade", 0))
	var pan_ms: int = int(phase_times.get("settle", 0)) - int(phase_times.get("camera_pan", 0))
	var settle_ms: int = int(phase_times.get("done", 0)) - int(phase_times.get("settle", 0))
	_log("phase durations ms: fade=%d pan=%d settle=%d" % [fade_ms, pan_ms, settle_ms])
	_check(fade_ms >= 200 and fade_ms <= 900, "title fade takes about 0.35 s", str(fade_ms))
	_check(
		is_equal_approx(_level.get_menu_camera_pan_duration(), 2.2),
		"menu camera pan default is 2.2 s",
		"%.2f" % _level.get_menu_camera_pan_duration()
	)
	# The real Tween is measured. The lower bound rejects the old 1.6 s pace;
	# the upper bound also allows a windowed render/shader hitch, which can add
	# a frame or two of wall-clock time without changing the Tween's 2.2 s duration.
	_check(pan_ms >= 2050 and pan_ms <= 2800, "camera pan takes about 2.2 s", str(pan_ms))
	_check(settle_ms >= 40 and settle_ms <= 450, "camera settle takes about 0.15 s", str(settle_ms))

	var first_world: Dictionary = {}
	var first_pan: Dictionary = {}
	var last_pre_entry: Dictionary = {}
	var first_done: Dictionary = {}
	var pre_entry_player_moved: bool = false
	var centers: Array[float] = []
	var settle_samples: int = 0
	var settle_safe: bool = true
	for sample: Dictionary in samples:
		var phase: String = String(sample["phase"])
		if bool(sample["world"]) and first_world.is_empty():
			first_world = sample
		if phase == "camera_pan" and first_pan.is_empty():
			first_pan = sample
		if phase != "done" and not bool(sample["intro"]):
			last_pre_entry = sample
			var sample_pos: Vector2 = sample["pos"]
			if not sample_pos.is_equal_approx(player_start):
				pre_entry_player_moved = true
		if phase == "settle":
			settle_samples += 1
			if bool(sample["intro"]) or bool(sample["player"]) or bool(sample["hud"]):
				settle_safe = false
		if phase == "done" and first_done.is_empty():
			first_done = sample
		if phase == "camera_pan" or phase == "settle" or phase == "done":
			var sample_center: Vector2 = sample["center"]
			centers.append(sample_center.y)

	_check(not first_world.is_empty(), "the real World becomes visible during the transition")
	_check(not first_pan.is_empty(), "the camera pan phase is observed")
	_check(bool(first_world.get("world", false)), "World is visible on the first pan frame")
	_check(String(first_world.get("phase", "")) == "camera_pan", "World appears exactly when the camera pan starts", String(first_world.get("phase", "")))
	_check(not bool(first_world.get("player", true)) and not bool(first_world.get("hud", true)), "Player and HUD stay hidden at the first world frame")
	_check(not bool(first_world.get("intro", true)), "intro is inactive at the first world frame")
	var first_world_center: Vector2 = first_world.get("center", Vector2.ZERO)
	_check(first_world_center.y <= -175.0, "the first world frame still looks above the level", str(first_world_center))
	_check(float(first_world.get("terrain_y", 0.0)) > 360.0, "the ground is still below the screen on the first world frame", str(first_world.get("terrain_y", 0.0)))
	var terrain_visible_samples: int = 0
	var terrain_prev: float = INF
	var terrain_monotonic: bool = true
	for sample: Dictionary in samples:
		if String(sample["phase"]) == "done":
			continue
		var terrain_y: float = float(sample.get("terrain_y", INF))
		if terrain_y > 1.0 and terrain_y < 359.0:
			terrain_visible_samples += 1
		if terrain_prev != INF and terrain_y > terrain_prev + 0.75:
			terrain_monotonic = false
		terrain_prev = terrain_y
	_check(terrain_visible_samples >= 5, "the real terrain crosses the screen during the pan", str(terrain_visible_samples))
	_check(terrain_monotonic, "terrain screen coordinates move smoothly upward, not instantly")
	_check(not pre_entry_player_moved, "Player never moves before the camera settles")
	_check(settle_samples > 0, "the settled-before-entry state is observed", str(settle_samples))
	_check(not last_pre_entry.is_empty(), "a pre-entry settle sample is recorded")
	_check(settle_safe, "every settle sample keeps intro/player/HUD hidden")
	_check(not bool(last_pre_entry.get("intro", true)) and not bool(last_pre_entry.get("player", true)) and not bool(last_pre_entry.get("hud", true)), "entry has not happened at the settled frame")
	var last_pre_center: Vector2 = last_pre_entry.get("center", Vector2.ZERO)
	_check(last_pre_center.y >= 179.0, "the camera is fully down before entry", str(last_pre_center))
	_check(not first_done.is_empty(), "a done/entry sample is recorded")
	_check(bool(first_done.get("intro", false)) and bool(first_done.get("player", false)) and bool(first_done.get("hud", false)), "intro, player and HUD appear together at entry")

	var center_jump: float = 0.0
	var distinct: Dictionary = {}
	for index: int in range(centers.size()):
		distinct[snappedf(centers[index], 0.01)] = true
		if index > 0:
			var delta: float = centers[index] - centers[index - 1]
			if delta < -0.75:
				center_jump = minf(center_jump, delta)
	_check(center_jump >= -0.75, "camera screen centre never moves back up", str(center_jump))
	_check(distinct.size() >= 12, "camera centre has many smooth intermediate values", str(distinct.size()))
	var first_done_center: Vector2 = first_done.get("center", Vector2.ZERO)
	var entry_gap: float = absf(first_done_center.y - last_pre_center.y)
	_check(entry_gap <= 1.0, "player camera handoff has no visible frame jump", str(entry_gap))
	_check(_player_camera.enabled and not _menu_camera.enabled, "player camera replaces the temporary camera at entry")
	_check(_player_camera.get_screen_center_position().is_equal_approx(Vector2(320.0, 180.0)), "final camera centre is the normal level view", str(_player_camera.get_screen_center_position()))
	var prompts_restored: bool = true
	for stele_node: Node in get_tree().get_nodes_in_group(&"tutorial_stele"):
		var prompt_layer: CanvasLayer = stele_node.get_node_or_null("PromptLayer") as CanvasLayer
		if prompt_layer == null or not prompt_layer.visible:
			prompts_restored = false
	_check(prompts_restored, "stele prompt CanvasLayers are restored at entry")
	_check(_level.get_intro_start_count() == 1, "exactly one intro started over the whole transition", str(_level.get_intro_start_count()))
	_check(_menu.get_start_request_count() == 1, "duplicate input during the transition never started a second time")

	# Measure the real opening auto-run in the same instance, on the real
	# physics step, from the slow scripted target to the IntroEnd handoff.
	var intro: Dictionary = await _measure_intro_run()
	_log("INTRO_MEASURE ratio=%.2f expected_target=%.1f target=%.1f velocity=%.1f frames=%d elapsed=%.3f start_x=%.1f handoff_x=%.1f settled_x=%.1f intro_end_x=%.1f max_duration=%.2f" % [
		float(intro["ratio"]), float(intro["expected_target"]),
		float(intro["target_speed"]), float(intro["velocity"]), int(intro["frames"]),
		float(intro["elapsed"]), float(intro["start_x"]), float(intro["handoff_x"]),
		float(intro["settled_x"]), _level.get_intro_end_position().x, _level.get_intro_max_duration(),
	])
	_check(float(intro["handoff_x"]) > float(intro["start_x"]) + 20.0, "the original opening auto-run still moves the player")
	_check(not _level.is_intro_active(), "opening hands control back")
	_check(
		is_equal_approx(_level.get_intro_run_speed_ratio(), 0.75),
		"opening run ratio default is 0.75",
		"%.2f" % _level.get_intro_run_speed_ratio()
	)
	_check(
		absf(float(intro["target_speed"]) - float(intro["expected_target"])) < 0.5,
		"opening target is 120 px/s (0.75 * run 160), not 160",
		"%.1f" % float(intro["target_speed"])
	)
	_check(
		absf(float(intro["velocity"]) - float(intro["expected_target"])) <= 2.0,
		"opening actually moves at the slower 120 px/s",
		"%.1f" % float(intro["velocity"])
	)
	_check(
		float(intro["elapsed"]) >= 1.25,
		"opening run lasts long enough for the whole -60 -> 100 path",
		"%.3f s" % float(intro["elapsed"])
	)
	_check(
		float(intro["elapsed"]) < _level.get_intro_max_duration() - 0.02,
		"opening is not cut short by intro_max_duration",
		"elapsed=%.3f max=%.2f" % [float(intro["elapsed"]), _level.get_intro_max_duration()]
	)
	_check(
		float(intro["handoff_x"]) >= _level.get_intro_end_position().x,
		"opening reaches IntroEnd before handing control back",
		"x=%.1f marker=%.1f" % [float(intro["handoff_x"]), _level.get_intro_end_position().x]
	)
	_check(_hud.visible and _player.visible, "HUD and player remain visible after the opening")
	_check(not _hud.get_toast_text().contains("交还") and not _hud.is_toast_visible(), "no control-return toast is added")
	_check(_player.is_positive(), "held Q during the transition did not leak a polarity change into play")
	_check(_player.is_on_floor(), "held Space during the transition did not leave a jump buffer", str(_player.global_position))

	# The slower opening must not change normal input pace after the handoff.
	Input.action_press(&"move_right")
	await _physics(20)
	_check(
		absf(_player.get_target_speed() - _player.get_walk_speed()) < 0.5,
		"normal direction input still targets walk 100",
		"%.1f" % _player.get_target_speed()
	)
	_check(
		absf(_player.velocity.x - _player.get_walk_speed()) <= 2.0,
		"normal direction input actually walks at 100",
		"%.1f" % _player.velocity.x
	)
	_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	await _physics(20)
	_check(
		absf(_player.get_target_speed() - _player.get_run_speed()) < 0.5,
		"real left Shift still targets run 160",
		"%.1f" % _player.get_target_speed()
	)
	_check(
		absf(_player.velocity.x - _player.get_run_speed()) <= 2.0,
		"real left Shift actually runs at 160",
		"%.1f" % _player.velocity.x
	)
	_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	Input.action_release(&"move_right")
	await _physics(4)

	var before_q: bool = _player.is_positive()
	_key(KEY_Q, true)
	await _physics(3)
	_key(KEY_Q, false)
	await _physics(1)
	_check(_player.is_positive() != before_q, "Q changes polarity after the menu handoff")
	_check(_hud.get_polarity_text() == ("澜相" if not _player.is_positive() else "辉相"), "HUD follows the post-menu Q toggle", _hud.get_polarity_text())
	var x_before: float = _player.global_position.x
	Input.action_press(&"move_right")
	await _physics(14)
	Input.action_release(&"move_right")
	await _physics(2)
	_check(_player.global_position.x > x_before + 2.0, "D/right movement works after the menu handoff", "%.1f -> %.1f" % [x_before, _player.global_position.x])
	await _physics(8)
	_key(KEY_SPACE)
	await _physics(4)
	_key(KEY_SPACE, false)
	_check(_player.global_position.y < 299.0 or _player.velocity.y < -40.0, "Space jumps after the menu handoff", str(_player.global_position))
	await _physics(20)

	# R after play restarts the level and replays only the opening run.
	var intro_before_r: int = _level.get_intro_start_count()
	await _tap_key(KEY_R)
	await _physics(2)
	_check(_level.is_intro_active(), "R after play restarts the opening run")
	_check(_level.get_intro_start_count() == intro_before_r + 1, "R adds one intro, not a menu transition", str(_level.get_intro_start_count()))
	_check(_menu.get_phase_name() == "done", "R after play does not return to the menu", _menu.get_phase_name())
	_check(not _menu.visible or not _menu.get_node("StartMenuRoot").visible, "menu root stays hidden after R")
	_check(not _menu_camera.enabled and _player_camera.enabled, "R does not re-enable the transition camera")
	_check(_player_camera.get_screen_center_position().is_equal_approx(Vector2(320.0, 180.0)), "R does not replay the camera pan", str(_player_camera.get_screen_center_position()))
	_check(_hud.visible and _world.visible, "R keeps HUD/world visible")
	await _physics(18)
	var r_intro_target: float = _player.get_target_speed()
	_check(
		absf(r_intro_target - _level.get_intro_run_speed_ratio() * _player.get_run_speed()) < 0.5,
		"R replay keeps the slower opening target 120",
		"%.1f" % r_intro_target
	)
	await _wait_intro_done()
	_check(
		_player.global_position.x >= _level.get_intro_end_position().x,
		"R replay reaches IntroEnd before handoff",
		"x=%.1f marker=%.1f" % [_player.global_position.x, _level.get_intro_end_position().x]
	)


func _test_keyboard_start_pause_focus_and_restart() -> void:
	_section("KEYBOARD START / ESC / FOCUS-LOSS TRANSITION PAUSE")
	_remove_temp_audio()
	await _new_level(true)
	await _settle_frames(3)
	await _tap_key(KEY_ENTER)
	await _settle_frames(2)
	_check(_menu.get_phase_name() == "title_fade", "real Enter starts from the focused menu", _menu.get_phase_name())
	_check(_menu.get_start_request_count() == 1, "keyboard start is counted once", str(_menu.get_start_request_count()))
	await _settle_frames(6)

	# Pause during the title fade.
	await _tap_key(KEY_ESCAPE)
	await _settle_frames(1)
	_check(get_tree().paused and _menu.is_transition_paused(), "Esc pauses the title-fade transition")
	_check(_menu.get_phase_name() == "title_fade", "paused transition keeps its phase", _menu.get_phase_name())
	var frozen_bg: float = _background.get_background_time()
	var frozen_center: Vector2 = _menu_camera.get_screen_center_position()
	await get_tree().create_timer(0.25).timeout
	_check(is_equal_approx(_background.get_background_time(), frozen_bg), "paused transition freezes the background clock", "%.3f -> %.3f" % [frozen_bg, _background.get_background_time()])
	_check(_menu_camera.get_screen_center_position().is_equal_approx(frozen_center), "paused transition does not move the camera")
	_check(not _level.is_intro_active(), "paused transition does not enter the intro")
	await _tap_key(KEY_ESCAPE)
	await _settle_frames(1)
	_check(not get_tree().paused and not _menu.is_transition_paused(), "Esc resumes the title-fade transition")
	_check(not _menu.is_transition_paused() and _menu.get_phase_name() != "done", "resume continues the same transition")

	# Wait for the pan, then pause via focus loss and resume manually.
	await _wait_phase("camera_pan", 300)
	_check(_menu.get_phase_name() == "camera_pan", "transition reaches the camera pan")
	await _settle_frames(8)
	var pan_before: Vector2 = _menu_camera.get_screen_center_position()
	get_window().focus_exited.emit()
	await _settle_frames(2)
	_check(get_tree().paused and _menu.is_transition_paused(), "focus loss pauses the camera pan")
	var pan_frozen: Vector2 = _menu_camera.get_screen_center_position()
	var pan_bg: float = _background.get_background_time()
	await get_tree().create_timer(0.22).timeout
	_check(_menu_camera.get_screen_center_position().is_equal_approx(pan_frozen), "pan camera does not jump while focus-paused")
	_check(is_equal_approx(_background.get_background_time(), pan_bg), "pan pause freezes the DS03 clock")
	_check(_menu.get_phase_name() == "camera_pan", "focus pause keeps the transition at the pan", _menu.get_phase_name())
	await _tap_key(KEY_ESCAPE)
	await _settle_frames(2)
	_check(not get_tree().paused, "manual Esc resume lifts the transition pause")
	await _settle_frames(4)
	_check(_menu_camera.get_screen_center_position().y >= pan_frozen.y - 0.5, "camera resumes from the paused point without snapping back", "%s -> %s" % [str(pan_frozen), str(_menu_camera.get_screen_center_position())])

	# Pause during settle.
	await _wait_phase("settle", 300)
	_check(_menu.get_phase_name() == "settle", "transition reaches the settled state")
	var settle_center: Vector2 = _menu_camera.get_screen_center_position()
	await _tap_key(KEY_ESCAPE)
	await _settle_frames(1)
	_check(get_tree().paused and _menu.get_phase_name() == "settle", "Esc pauses during settle")
	await get_tree().create_timer(0.18).timeout
	_check(_menu_camera.get_screen_center_position().is_equal_approx(settle_center), "settle pause holds the final camera")
	await _tap_key(KEY_ESCAPE)
	await _settle_frames(1)
	_check(not get_tree().paused, "Esc resumes from settle")
	await _wait_phase("done", 300)
	_check(_menu.get_phase_name() == "done", "transition finishes after all pauses")
	_check(_level.get_intro_start_count() == 1, "paused/resumed transition starts exactly one intro", str(_level.get_intro_start_count()))

	await _wait_intro_done()
	_check(_hud.visible and _player.visible and not _level.is_intro_active(), "controls return after the paused transition")
	var x_before: float = _player.global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	Input.action_release(&"move_right")
	await _physics(2)
	_check(_player.global_position.x > x_before + 2.0, "movement works after a paused/resumed transition", "%.1f -> %.1f" % [x_before, _player.global_position.x])


func _test_scene_reload_returns_to_menu() -> void:
	_section("SCENE RE-ENTRY RETURNS TO THE INITIAL MENU")
	await _new_level(true)
	await _settle_frames(3)
	_check(_menu.get_phase_name() == "menu", "fresh scene opens in the menu")
	_check(not _world.visible and not _player.visible and not _hud.visible, "fresh scene hides world/player/HUD")
	_check(not _level.is_intro_active() and _level.get_intro_start_count() == 0, "fresh scene starts no intro")
	_check(_menu_camera.enabled and not _player_camera.enabled, "fresh scene restores the menu camera")
	_check(_menu_camera.get_screen_center_position().is_equal_approx(Vector2(320.0, -180.0)), "fresh scene resets the menu camera height", str(_menu_camera.get_screen_center_position()))
	_check(_player.global_position.is_equal_approx(Vector2(-60.0, 300.0)), "fresh scene has the original spawn point", str(_player.global_position))
	_check(not get_tree().paused, "fresh scene is not left paused")
	_check(_menu.get_start_request_count() == 0, "fresh menu has no stale start request")
	_check(not _menu.get_quit_button().disabled and not _menu.is_quit_locked(), "fresh scene restores an enabled, unlocked quit entry")
	_check(get_viewport().gui_get_focus_owner() == _menu.get_start_button(), "fresh scene keeps initial focus on start, not quit", str(get_viewport().gui_get_focus_owner()))
	_check(not _menu.get_node("StartMenuRoot/MenuGroup/FocusQuit").visible, "fresh scene hides the quit focus accent")


# --- Assertion helpers ----------------------------------------------------


# --- Scene / input helpers ------------------------------------------------

func _new_level(menu_enabled: bool) -> void:
	_release_inputs()
	get_tree().paused = false
	if is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = menu_enabled
	if menu_enabled:
		var temp_menu: StartMenu = _level.get_node("StartMenu") as StartMenu
		temp_menu.audio_settings_path = TEMP_AUDIO_PATH
		temp_menu.display_settings_path = TEMP_DISPLAY_PATH
	add_child(_level)
	await _physics(6)
	_menu = _level.get_menu()
	_player = _level.get_player()
	_hud = _level.get_hud()
	_world = _level.get_node("World") as Node2D
	_menu_camera = _level.get_menu_camera()
	_player_camera = _level.get_camera()
	_background = _level.get_node("Background/CloudRuinsDS03") as CloudRuinsDS03


func _settle_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _wait_phase(phase_name: String, max_frames: int) -> bool:
	# A windowed run can render far above 60 fps, so a frame-only budget can
	# expire before a short real-time phase such as the 0.15 s settle. Keep the
	# frame budget but also wait against wall-clock time.
	var deadline: int = Time.get_ticks_msec() + 5000
	for _i: int in range(max_frames):
		if _menu.get_phase_name() == phase_name:
			return true
		if Time.get_ticks_msec() >= deadline:
			break
		await get_tree().process_frame
	while Time.get_ticks_msec() < deadline:
		if _menu.get_phase_name() == phase_name:
			return true
		await get_tree().process_frame
	var missing: bool = _menu.get_phase_name() != phase_name
	if missing:
		_log("WAIT_PHASE_MISS want=%s got=%s paused=%s transition_paused=%s" % [
			phase_name, _menu.get_phase_name(),
			str(get_tree().paused), str(_menu.is_transition_paused()),
		])
	return not missing


func _wait_intro_done(max_frames: int = 420) -> void:
	for _i: int in range(max_frames):
		if not _level.is_intro_active():
			break
		await get_tree().process_frame
	await _physics(4)


func _measure_intro_run() -> Dictionary:
	var start_x: float = _player.global_position.x
	var ratio: float = _level.get_intro_run_speed_ratio()
	var expected_target: float = ratio * _player.get_run_speed()
	var frames: int = 0
	var target_speed: float = 0.0
	var velocity: float = 0.0
	var handoff_x: float = start_x
	while _level.is_intro_active() and frames < 300:
		await get_tree().physics_frame
		frames += 1
		handoff_x = maxf(handoff_x, _player.global_position.x)
		if frames == 20:
			target_speed = _player.get_target_speed()
			velocity = _player.velocity.x
	var elapsed: float = _level.get_intro_elapsed()
	await _physics(4)
	return {
		"start_x": start_x,
		"ratio": ratio,
		"expected_target": expected_target,
		"target_speed": target_speed,
		"velocity": velocity,
		"frames": frames,
		"elapsed": elapsed,
		"handoff_x": handoff_x,
		"settled_x": _player.global_position.x,
	}


func _mouse_move(pos: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event, true)


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event, true)


func _mouse_click(pos: Vector2) -> void:
	_mouse_button(pos, true)
	await get_tree().process_frame
	_mouse_button(pos, false)


func _slider_point(ratio: float) -> Vector2:
	var rect: Rect2 = _menu.get_slider().get_global_rect()
	return Vector2(
		rect.position.x + 2.5 + (rect.size.x - 5.0) * clampf(ratio, 0.0, 1.0),
		rect.get_center().y
	)


func _key(code: Key, pressed: bool = true, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.location = location
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_key(code: Key) -> void:
	_key(code, true)
	await get_tree().process_frame
	_key(code, false)
	await get_tree().process_frame


func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause"]:
		Input.action_release(action)


# --- Audio config helpers -------------------------------------------------

func _write_config_text(text: String) -> void:
	var path: String = ProjectSettings.globalize_path(TEMP_AUDIO_PATH)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write temp audio config")
		return
	file.store_string(text)
	file.close()


func _write_config_value(value: float) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", value)
	var error: Error = config.save(TEMP_AUDIO_PATH)
	if error != OK:
		push_error("could not save temp audio config")


func _temp_config_value() -> float:
	var config: ConfigFile = ConfigFile.new()
	if config.load(TEMP_AUDIO_PATH) != OK:
		return NAN
	return float(config.get_value("audio", "master_volume", NAN))


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


# --- Reporting ------------------------------------------------------------

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
	if is_instance_valid(_level):
		_level.queue_free()
	await get_tree().process_frame
	AudioServer.set_bus_mute(0, _original_master_mute)
	AudioServer.set_bus_volume_db(0, _original_master_db)
	_remove_temp_audio()
	_remove_temp_display()
	_restore_window_state(_original_window_state)
	var probe_config: String = ProjectSettings.globalize_path("user://probe_audio.cfg")
	if FileAccess.file_exists(probe_config):
		DirAccess.remove_absolute(probe_config)
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count])
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/menu_quit_e2e_%s.log" % stamp, FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	get_tree().quit(0 if _fail_count == 0 else 1)
