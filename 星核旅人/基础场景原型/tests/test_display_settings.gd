extends Node

## Display settings acceptance.
##
## Run headless for the pure candidate/config/pending rules:
##   ... --headless --path . res://tests/test_display_settings.tscn
## Run with the GUI executable for the real window/fullscreen, pending overlay,
## countdown, rollback and scaled-click checks:
##   ... --path . res://tests/test_display_settings.tscn
##
## Every instance uses temporary user:// audio/display configs.  The real
## Window mode/size/position/content-scale and Master volume are restored at the
## end, including after failures.  Screen-size simulations are labelled
## SIMULATED and never claim to be a real 2K display.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const TEMP_AUDIO_PATH: String = "user://test_display_settings_audio.cfg"
const TEMP_DISPLAY_PATH: String = "user://test_display_settings_display.cfg"

var _level: Level01
var _menu: StartMenu
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []
var _original_master_db: float = 0.0
var _original_master_mute: bool = false
var _original_window_state: Dictionary = {}
var _gui: bool = false
var _volume_before_display: int = 37


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_gui = DisplayServer.get_name() != "headless"
	_original_master_db = AudioServer.get_bus_volume_db(0)
	_original_master_mute = AudioServer.is_bus_mute(0)
	_original_window_state = _capture_window_state()
	_remove_temp_audio()
	_remove_temp_display()
	_log("Star Core Traveler - display settings acceptance")
	_log("Godot %s  display=%s  gui=%s" % [
		Engine.get_version_info()["string"], DisplayServer.get_name(), str(_gui)
	])
	_log("Screen: %s  usable=%s" % [
		str(DisplayServer.screen_get_size()), str(DisplayServer.screen_get_usable_rect(
			DisplayServer.window_get_current_screen(0)
		))
	])
	await _test_pure_rules()
	await _test_controller_pending_rules()
	if _gui:
		await _test_real_gui_flow()
	else:
		_log("SKIP real GUI window/fullscreen checks: headless cannot create a real display")
	await _finish()


# --- Pure sizing / config rules -------------------------------------------

func _test_pure_rules() -> void:
	_section("SIMULATED SCREEN FILTERING / CONFIG VALIDATION")
	var margin: Vector2i = Vector2i(32, 64)
	var desktop: Rect2i = Rect2i(0, 0, 1920, 1032)
	var entries: Array[Dictionary] = DisplayOptions.candidate_entries(desktop, margin)
	_check(entries.size() == 4, "four 16:9 output candidates are described", str(entries.size()))
	_check(_entry_fits(entries, Vector2i(640, 360)), "SIMULATED 1920x1032 work area fits 640x360")
	_check(_entry_fits(entries, Vector2i(1280, 720)), "SIMULATED 1920x1032 work area fits 1280x720")
	_check(not _entry_fits(entries, Vector2i(1920, 1080)), "SIMULATED 1920x1032 work area rejects 1920x1080")
	_check(not _entry_fits(entries, Vector2i(2560, 1440)), "SIMULATED 1920x1032 work area rejects 2560x1440")
	_check(
		DisplayOptions.default_window_size(desktop, margin) == Vector2i(1280, 720),
		"SIMULATED default is the largest fitting candidate 1280x720"
	)

	var small: Rect2i = Rect2i(0, 0, 1280, 680)
	var small_entries: Array[Dictionary] = DisplayOptions.candidate_entries(small, margin)
	_check(_entry_fits(small_entries, Vector2i(640, 360)), "SIMULATED 1280x680 work area keeps 640x360")
	_check(not _entry_fits(small_entries, Vector2i(1280, 720)), "SIMULATED 1280x680 work area rejects 1280x720")
	_check(
		DisplayOptions.default_window_size(small, margin) == Vector2i(640, 360),
		"SIMULATED smaller desktop falls back to 640x360"
	)

	var tiny: Rect2i = Rect2i(0, 0, 500, 300)
	var tiny_size: Vector2i = DisplayOptions.default_window_size(tiny, margin)
	_check(
		DisplayOptions.fits(tiny_size, tiny, margin) and tiny_size.x < 640,
		"SIMULATED very small desktop gets a fitting sub-640 fallback, not an off-screen window",
		str(tiny_size)
	)

	var uhd: Rect2i = Rect2i(0, 0, 3840, 2080)
	_check(
		DisplayOptions.default_window_size(uhd, margin) == Vector2i(1280, 720),
		"SIMULATED 4K desktop with no config keeps the 1280x720 default, not 2560x1440"
	)
	var uhd_saved: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 2560, 1440, uhd, margin
	)
	_check(
		uhd_saved["window_size"] == Vector2i(2560, 1440) and not bool(uhd_saved["changed"]),
		"SIMULATED 4K honors an explicitly saved 2560x1440 window"
	)
	var uhd_bad: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 9999, 9999, uhd, margin
	)
	_check(
		uhd_bad["window_size"] == Vector2i(1280, 720),
		"SIMULATED 4K bad config falls back to 1280x720"
	)

	var valid: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 1280, 720, desktop, margin
	)
	_check(int(valid["mode"]) == DisplayOptions.Mode.WINDOWED, "valid saved mode stays windowed")
	_check(valid["window_size"] == Vector2i(1280, 720), "valid saved size stays 1280x720")
	_check(not bool(valid["changed"]), "valid saved state reports no clamp")

	var negative: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", -640, 360, desktop, margin
	)
	_check(negative["window_size"] == Vector2i(1280, 720), "negative saved size safely defaults")
	_check(bool(negative["changed"]), "negative saved size is reported as corrected")
	var bad_type: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", "1280", "720", desktop, margin
	)
	_check(bad_type["window_size"] == Vector2i(1280, 720), "string saved size safely defaults")
	var huge: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 8192, 4608, desktop, margin
	)
	_check(huge["window_size"] == Vector2i(1280, 720), "oversized saved window clamps down")
	var bad_mode: Dictionary = DisplayOptions.validate_saved_state(
		"stretched", 1280, 720, desktop, margin
	)
	_check(int(bad_mode["mode"]) == DisplayOptions.Mode.WINDOWED, "unknown saved mode defaults to windowed")
	var full: Dictionary = DisplayOptions.validate_saved_state(
		"fullscreen", 640, 360, desktop, margin
	)
	_check(int(full["mode"]) == DisplayOptions.Mode.FULLSCREEN, "saved fullscreen mode is preserved")
	_check(full["window_size"] == Vector2i(640, 360), "saved fullscreen keeps its window target size")
	var saved_small: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 1280, 720, small, margin
	)
	_check(
		saved_small["window_size"] == Vector2i(640, 360),
		"saved 1280 window clamps to 640 on a simulated smaller screen"
	)

	var reject: Dictionary = DisplayOptions.validate_choice(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080), desktop, margin
	)
	_check(not bool(reject["ok"]), "1920x1080 is rejected on a 1920x1032 work area")
	var accept: Dictionary = DisplayOptions.validate_choice(
		DisplayOptions.Mode.WINDOWED, Vector2i(1280, 720), desktop, margin
	)
	_check(bool(accept["ok"]), "1280x720 is accepted on the simulated desktop")

	var logical_rect: Rect2i = DisplayOptions.content_rect(Vector2i(1400, 900))
	_check(logical_rect == Rect2i(60, 90, 1280, 720), "1400x900 keeps integer 2x with black bars", str(logical_rect))
	_check(DisplayOptions.integer_scale(Vector2i(1400, 900)) == 2, "1400x900 integer scale is 2")
	_check(
		DisplayOptions.content_rect(Vector2i(1707, 1019)) == Rect2i(213, 149, 1280, 720),
		"1707x1019 simulation keeps 16:9 and black bars"
	)
	_check(
		DisplayOptions.content_rect(Vector2i(1280, 720)) == Rect2i(0, 0, 1280, 720),
		"1280x720 has no black bars"
	)


func _test_controller_pending_rules() -> void:
	_section("PENDING / CONFIRM / TIMEOUT / ESC / FAILURE / CLEANUP")
	_remove_temp_display()
	var fake: Dictionary = {"calls": [], "fail_next": false}
	var failed_signal: Dictionary = {"count": 0}
	var controller: DisplaySettingsController = DisplaySettingsController.new()
	controller.name = "FakeDisplayController"
	controller.apply_override = func(
		mode: int, size: Vector2i, position: Vector2i, center: bool
	) -> Dictionary:
		fake["calls"].append({"mode": mode, "size": size, "position": position, "center": center})
		if bool(fake["fail_next"]):
			fake["fail_next"] = false
			return {"ok": false, "message": "simulated apply failure"}
		return {"ok": true, "message": ""}
	controller.apply_failed.connect(
		func(_message: String) -> void: failed_signal["count"] = int(failed_signal["count"]) + 1
	)
	add_child(controller)
	controller.initialize(get_window(), TEMP_DISPLAY_PATH)
	_check(
		controller.get_active_mode() == DisplayOptions.Mode.WINDOWED,
		"missing display config starts in windowed mode, never forced fullscreen"
	)
	_check(
		is_equal_approx(controller.get_pending_timeout_seconds(), 10.0),
		"production pending timeout is 10.0 s",
		"%.1f" % controller.get_pending_timeout_seconds()
	)
	var base_size: Vector2i = controller.get_active_window_size()
	var target_a: Vector2i = (
		Vector2i(640, 360) if base_size != Vector2i(640, 360) else Vector2i(1280, 720)
	)
	var target_b: Vector2i = (
		Vector2i(1280, 720) if target_a == Vector2i(640, 360) else Vector2i(640, 360)
	)

	var first: Dictionary = controller.begin_apply(DisplayOptions.Mode.WINDOWED, target_a)
	_check(bool(first.get("ok", false)), "pending apply accepts an available window size")
	_check(controller.is_pending(), "apply is pending before confirmation")
	_check(not _display_config_exists(), "pending apply does not write the display config")
	var duplicate: Dictionary = controller.begin_apply(DisplayOptions.Mode.WINDOWED, target_b)
	_check(not bool(duplicate.get("ok", false)), "a second apply is rejected while pending")
	var restored_calls: int = (fake["calls"] as Array).size()
	_check(controller.cancel_pending("escape"), "pending apply can be cancelled")
	_check(not controller.is_pending(), "cancel clears pending")
	_check(
		controller.get_active_window_size() == base_size,
		"cancel keeps the previous active size",
		DisplayOptions.format_size(controller.get_active_window_size())
	)
	_check((fake["calls"] as Array).size() > restored_calls, "cancel asks the window backend to restore")

	var applied: Dictionary = controller.begin_apply(DisplayOptions.Mode.WINDOWED, target_a)
	_check(bool(applied.get("ok", false)), "windowed apply starts a pending switch")
	var confirmed: Dictionary = controller.confirm_pending()
	_check(bool(confirmed.get("ok", false)) and bool(confirmed.get("saved", false)), "confirm saves the display config")
	_check(controller.get_active_window_size() == target_a, "confirm makes the size active")
	_check(_display_config_size() == target_a, "display config stores the confirmed size")
	_check(_display_config_mode() == "windowed", "display config stores windowed mode")

	var full_pending: Dictionary = controller.begin_apply(
		DisplayOptions.Mode.FULLSCREEN, controller.get_active_window_size()
	)
	_check(bool(full_pending.get("ok", false)), "fullscreen apply starts pending")
	controller.cancel_pending("escape")
	_check(
		controller.get_active_mode() == DisplayOptions.Mode.WINDOWED,
		"fullscreen cancel returns to the previous windowed mode"
	)
	_check(_display_config_size() == target_a, "fullscreen cancel keeps the confirmed config")

	controller.pending_timeout_seconds = 0.35
	var timeout_apply: Dictionary = controller.begin_apply(
		DisplayOptions.Mode.WINDOWED, target_b
	)
	_check(bool(timeout_apply.get("ok", false)), "timeout test apply starts")
	await get_tree().create_timer(0.75).timeout
	_check(not controller.is_pending(), "absolute-clock timeout clears pending")
	_check(
		controller.get_active_window_size() == target_a,
		"timeout restores the previous active size"
	)
	_check(_display_config_size() == target_a, "timeout leaves the confirmed config untouched")

	fake["fail_next"] = true
	var failure: Dictionary = controller.begin_apply(DisplayOptions.Mode.WINDOWED, target_b)
	_check(not bool(failure.get("ok", false)), "simulated backend failure is reported")
	_check(not controller.is_pending(), "failed apply leaves no pending state")
	_check(int(failed_signal["count"]) >= 1, "failed apply emits apply_failed")
	_check(_display_config_size() == target_a, "failed apply does not corrupt the config")
	controller.pending_timeout_seconds = 10.0

	var pre_free_calls: int = (fake["calls"] as Array).size()
	var free_apply: Dictionary = controller.begin_apply(DisplayOptions.Mode.WINDOWED, target_b)
	_check(bool(free_apply.get("ok", false)), "cleanup test apply starts")
	controller.queue_free()
	await get_tree().process_frame
	_check(
		(fake["calls"] as Array).size() > pre_free_calls,
		"freeing a pending controller restores the window backend"
	)
	_check(_display_config_size() == target_a, "freeing a pending controller keeps the confirmed config")

	var reload: DisplaySettingsController = DisplaySettingsController.new()
	reload.apply_override = func(
		_mode: int, _size: Vector2i, _position: Vector2i, _center: bool
	) -> Dictionary:
		return {"ok": true, "message": ""}
	add_child(reload)
	reload.initialize(get_window(), TEMP_DISPLAY_PATH)
	_check(
		reload.get_active_window_size() == target_a,
		"confirmed config loads back into a new controller",
		DisplayOptions.format_size(reload.get_active_window_size())
	)
	reload.queue_free()
	await get_tree().process_frame
	_remove_temp_display()

	_write_raw_display_config("this is not a ConfigFile\n%%% broken")
	var corrupt: DisplaySettingsController = DisplaySettingsController.new()
	corrupt.apply_override = func(
		_mode: int, _size: Vector2i, _position: Vector2i, _center: bool
	) -> Dictionary:
		return {"ok": true, "message": ""}
	add_child(corrupt)
	corrupt.initialize(get_window(), TEMP_DISPLAY_PATH)
	_check(
		corrupt.get_active_mode() == DisplayOptions.Mode.WINDOWED,
		"corrupt display config safely falls back to windowed"
	)
	_check(
		corrupt.get_active_window_size().x > 0 and corrupt.get_active_window_size().y > 0,
		"corrupt display config still yields a visible size",
		str(corrupt.get_active_window_size())
	)
	_check(not corrupt.is_pending(), "corrupt config never starts a pending confirmation")
	corrupt.queue_free()
	await get_tree().process_frame
	_remove_temp_display()

	var invalid_backend_modes: Array[int] = []
	for call_entry: Dictionary in fake["calls"] as Array:
		var call_mode: int = int(call_entry.get("mode", -1))
		if (
			call_mode != DisplayOptions.Mode.WINDOWED
			and call_mode != DisplayOptions.Mode.FULLSCREEN
		):
			invalid_backend_modes.append(call_mode)
	_check(
		invalid_backend_modes.is_empty(),
		"window backend only receives DisplayOptions modes, never Window.MODE_* values",
		str(invalid_backend_modes)
	)


# --- Real GUI flow ---------------------------------------------------------

func _test_real_gui_flow() -> void:
	_section("REAL GUI: 640/1280 WINDOW, PENDING, FULLSCREEN, SCALED CLICKS")
	_remove_temp_display()
	_remove_temp_audio()
	await _new_level()
	_check(_menu.get_phase_name() == "menu", "GUI instance opens in the menu", _menu.get_phase_name())
	_check(_window_size() == Vector2i(1280, 720), "default real window is 1280x720", str(_window_size()))
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "logical viewport stays 640x360", str(get_viewport().get_visible_rect().size))
	var window: Window = get_window()
	_check(window.content_scale_size == Vector2i(640, 360), "content scale size is 640x360", str(window.content_scale_size))
	_check(window.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT, "content scale mode is viewport", str(window.content_scale_mode))
	_check(window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "content scale aspect is keep", str(window.content_scale_aspect))
	_check(window.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER, "content scale stretch is integer", str(window.content_scale_stretch))

	await _open_settings_with_real_click()
	var controller: DisplaySettingsController = _menu.get_display_controller()
	var entries: Array[Dictionary] = controller.get_candidate_entries()
	_log("GUI candidate entries: %s  frame_margin=%s  usable=%s" % [
		str(entries), str(controller.get_frame_margin()), str(controller.get_usable_rect())
	])
	_check(
		_menu.get_resolution_button(Vector2i(640, 360)) != null,
		"expanded settings builds a 640x360 option"
	)
	_check(
		_menu.get_resolution_button(Vector2i(1280, 720)) != null,
		"expanded settings builds a 1280x720 option"
	)
	_check(
		not _menu.get_resolution_button(Vector2i(640, 360)).disabled,
		"640x360 option is available"
	)
	_check(
		not _menu.get_resolution_button(Vector2i(1280, 720)).disabled,
		"1280x720 option is available"
	)
	_check(
		_menu.get_resolution_button(Vector2i(1920, 1080)).disabled,
		"1920x1080 is disabled on this 1920x1032 work area"
	)
	_check(
		_menu.get_resolution_button(Vector2i(2560, 1440)).disabled,
		"2560x1440 is disabled on this desktop"
	)
	_check(_menu.get_display_note_text().contains("超出本屏"), "disabled sizes are explained in the panel", _menu.get_display_note_text())
	_check(_menu.get_apply_button().disabled, "apply is disabled when the draft matches the active display")
	_check(_menu.get_display_mode_button(false).selected, "windowed mode starts selected")

	# Keyboard route: Tab reaches the new rows, Left/Right move between mode
	# choices, Enter stages a choice and does not touch the real window.
	await _tap_key(KEY_TAB)
	await _settle(1)
	_check(
		get_viewport().gui_get_focus_owner() == _menu.get_display_mode_button(false),
		"Tab reaches the window mode button",
		str(get_viewport().gui_get_focus_owner())
	)
	await _tap_key(KEY_RIGHT)
	await _settle(1)
	_check(
		get_viewport().gui_get_focus_owner() == _menu.get_display_mode_button(true),
		"Right moves focus to the fullscreen mode button",
		str(get_viewport().gui_get_focus_owner())
	)
	await _tap_key(KEY_ENTER)
	await _settle(1)
	_check(_menu.get_display_mode_button(true).selected, "Enter stages fullscreen mode")
	_check(
		_menu.get_resolution_button(Vector2i(640, 360)).disabled,
		"staged fullscreen disables resolution choices"
	)
	_check(_window_size() == Vector2i(1280, 720), "Enter on a mode button does not change the window")
	await _tap_key(KEY_LEFT)
	await _settle(1)
	_check(
		get_viewport().gui_get_focus_owner() == _menu.get_display_mode_button(false),
		"Left moves focus back to the window mode button",
		str(get_viewport().gui_get_focus_owner())
	)
	await _tap_key(KEY_ENTER)
	await _settle(1)
	_check(_menu.get_display_mode_button(false).selected, "Enter returns the draft to windowed mode")
	await _tap_key(KEY_TAB)
	await _settle(1)
	await _tap_key(KEY_TAB)
	await _settle(1)
	_check(
		get_viewport().gui_get_focus_owner() == _menu.get_resolution_button(Vector2i(640, 360)),
		"Tab reaches the 640x360 resolution option",
		str(get_viewport().gui_get_focus_owner())
	)
	await _tap_key(KEY_ENTER)
	await _settle(1)
	_check(_menu.get_resolution_button(Vector2i(640, 360)).selected, "Enter stages the 640x360 option")
	_check(not _menu.get_apply_button().disabled, "keyboard staging enables apply")
	# Reset the draft to the active 1280 before the mouse/apply flow.
	await _click_logical(_menu.get_resolution_button(Vector2i(1280, 720)).get_global_rect().get_center())
	await _settle(2)
	_check(_menu.get_apply_button().disabled, "resetting the draft disables apply again")

	# Move the real Master bus through the scaled slider, then make sure display
	# rollback never touches it.
	await _click_logical(_slider_point(0.37))
	await _settle(3)
	_volume_before_display = _menu.get_volume_percent()
	_check(_volume_before_display >= 35 and _volume_before_display <= 39, "real slider click sets about 37%", str(_volume_before_display))
	var master: int = AudioServer.get_bus_index(&"Master")
	var master_db_before: float = AudioServer.get_bus_volume_db(master)

	# Staged change must not touch the window until Apply.
	var before_size: Vector2i = _window_size()
	await _click_logical(_menu.get_resolution_button(Vector2i(640, 360)).get_global_rect().get_center())
	await _settle(2)
	_check(_window_size() == before_size, "choosing 640 does not change the window before apply", str(_window_size()))
	_check(not _menu.get_apply_button().disabled, "apply enables after a real option change")
	_check(_menu.get_display_status_text().contains("待应用"), "status says the change is pending", _menu.get_display_status_text())

	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(4)
	_check(_menu.is_display_pending(), "apply opens the pending confirmation")
	_check(_menu.get_pending_overlay().visible, "pending confirmation overlay is visible")
	_check(_window_size() == Vector2i(640, 360), "real window becomes 640x360", str(_window_size()))
	_check(get_window().mode == Window.MODE_WINDOWED, "640 switch stays windowed", str(get_window().mode))
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "viewport stays 640x360 at 640 window", str(get_viewport().get_visible_rect().size))
	_check(DisplayOptions.content_rect(_window_size()) == Rect2i(0, 0, 640, 360), "640 window has no letterbox")
	_check(not _display_config_exists(), "pending 640 does not write the config")
	_log("pending countdown text: %s" % _menu.get_pending_countdown_text())
	_check(_menu.get_pending_countdown_text().contains("秒后自动恢复"), "visible countdown is shown")
	_check(_menu.get_resolution_button(Vector2i(1280, 720)).disabled, "underlying options lock while pending")

	# Clicking through the overlay must not reach Start or 返回.
	await _click_logical(_menu.get_start_button().get_global_rect().get_center())
	await _settle(2)
	_check(_menu.is_display_pending() and _menu.get_start_request_count() == 0, "pending overlay blocks start clicks")
	await _click_logical(_menu.get_return_button().get_global_rect().get_center())
	await _settle(2)
	_check(_menu.is_display_pending() and _menu.is_settings_open(), "pending overlay blocks 返回 clicks")
	var duplicate: Dictionary = controller.begin_apply(DisplayOptions.Mode.WINDOWED, Vector2i(1280, 720))
	_check(not bool(duplicate.get("ok", false)), "duplicate apply is rejected through the controller")
	_check(_menu.is_display_pending(), "duplicate apply keeps one pending state")

	await _click_logical(_menu.get_pending_confirm_button().get_global_rect().get_center())
	await _settle(4)
	_check(not _menu.is_display_pending(), "confirming 640 clears pending")
	_check(_window_size() == Vector2i(640, 360), "confirmed 640 window remains", str(_window_size()))
	_check(_display_config_size() == Vector2i(640, 360), "confirmed 640 is persisted")
	_check(_display_config_mode() == "windowed", "confirmed 640 mode is windowed")
	_check(_menu.get_display_status_text().contains("已保存"), "confirm status says saved", _menu.get_display_status_text())
	_check(_menu.get_volume_percent() == _volume_before_display, "confirm does not change volume", str(_menu.get_volume_percent()))
	_check(absf(AudioServer.get_bus_volume_db(master) - master_db_before) < 0.01, "confirm does not change Master dB")

	# 640x360 scaled hot zones still land on the generated buttons.
	await _click_logical(_menu.get_return_button().get_global_rect().get_center())
	await _settle(3)
	_check(not _menu.is_settings_open(), "640x360 scaled 返回 closes settings")
	await _open_settings_with_real_click()
	_check(_menu.is_settings_open(), "640x360 scaled settings hot zone reopens")
	_check(_window_size() == Vector2i(640, 360), "640x360 window is retained after reopening settings", str(_window_size()))

	# 1280 window.
	await _click_logical(_menu.get_resolution_button(Vector2i(1280, 720)).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(3)
	_check(_menu.is_display_pending(), "1280 apply is pending")
	_check(_window_size() == Vector2i(1280, 720), "real window becomes 1280x720", str(_window_size()))
	await _click_logical(_menu.get_pending_confirm_button().get_global_rect().get_center())
	await _settle(4)
	_check(_display_config_size() == Vector2i(1280, 720), "1280x720 is persisted")
	_check(_window_size() == Vector2i(1280, 720), "confirmed 1280 remains", str(_window_size()))

	# Timeout with window focus lost: absolute clock must still restore.
	controller.pending_timeout_seconds = 0.8
	var position_before_timeout: Vector2i = get_window().position
	await _click_logical(_menu.get_resolution_button(Vector2i(640, 360)).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(3)
	_check(_menu.is_display_pending(), "timeout test apply starts")
	get_window().focus_exited.emit()
	await get_tree().create_timer(1.15).timeout
	await _settle(3)
	_check(not _menu.is_display_pending(), "focus loss does not freeze the countdown")
	_check(_window_size() == Vector2i(1280, 720), "timeout restores 1280x720", str(_window_size()))
	_check(
		get_window().position == position_before_timeout,
		"timeout restores the previous window position",
		"%s -> %s" % [str(position_before_timeout), str(get_window().position)]
	)
	_check(
		get_window().content_scale_size == Vector2i(640, 360),
		"timeout keeps the 640x360 content scale",
		str(get_window().content_scale_size)
	)
	_check(_display_config_size() == Vector2i(1280, 720), "timeout keeps the confirmed 1280 config")
	_check(_menu.get_display_status_text().contains("超时"), "timeout status is visible", _menu.get_display_status_text())
	controller.pending_timeout_seconds = 10.0

	# Esc rollback.
	var position_before_esc: Vector2i = get_window().position
	await _click_logical(_menu.get_resolution_button(Vector2i(640, 360)).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(3)
	_check(_menu.is_display_pending(), "Esc rollback apply starts")
	await _tap_key(KEY_ESCAPE)
	await _settle(4)
	_check(not _menu.is_display_pending(), "Esc clears pending")
	_check(_window_size() == Vector2i(1280, 720), "Esc restores 1280x720", str(_window_size()))
	_check(
		get_window().position == position_before_esc,
		"Esc restores the previous window position",
		"%s -> %s" % [str(position_before_esc), str(get_window().position)]
	)
	_check(_display_config_size() == Vector2i(1280, 720), "Esc keeps the confirmed config")
	_check(_menu.is_settings_open(), "Esc during pending keeps settings open", str(_menu.is_settings_open()))
	_check(
		_menu.get_volume_percent() == _volume_before_display,
		"display rollback does not roll back volume",
		str(_menu.get_volume_percent())
	)
	_check(
		absf(AudioServer.get_bus_volume_db(master) - master_db_before) < 0.01,
		"display rollback keeps the Master dB unchanged"
	)

	# Fullscreen cancel.
	var screen_size_before: Vector2i = DisplayServer.screen_get_size()
	var position_before_fullscreen: Vector2i = get_window().position
	await _click_logical(_menu.get_display_mode_button(true).get_global_rect().get_center())
	await _settle(2)
	_check(_menu.get_display_mode_button(true).selected, "fullscreen draft is selected")
	_check(_menu.get_resolution_button(Vector2i(640, 360)).disabled, "resolution is disabled in fullscreen draft")
	_check(_menu.get_display_note_text().contains("仅窗口模式"), "fullscreen explains resolution is window-only", _menu.get_display_note_text())
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(5)
	_check(_menu.is_display_pending(), "fullscreen apply is pending")
	_check(get_window().mode == Window.MODE_FULLSCREEN, "real window enters borderless fullscreen", str(get_window().mode))
	_check(DisplayServer.screen_get_size() == screen_size_before, "desktop mode/size is not changed", str(DisplayServer.screen_get_size()))
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "fullscreen viewport stays 640x360", str(get_viewport().get_visible_rect().size))
	_check(_display_config_mode() == "windowed", "pending fullscreen does not write fullscreen config")
	await _click_logical(_menu.get_pending_cancel_button().get_global_rect().get_center())
	await _settle(5)
	_check(not _menu.is_display_pending(), "fullscreen cancel clears pending")
	_check(get_window().mode == Window.MODE_WINDOWED, "fullscreen cancel returns to windowed", str(get_window().mode))
	_check(_window_size() == Vector2i(1280, 720), "fullscreen cancel restores 1280x720", str(_window_size()))
	_check(
		get_window().position == position_before_fullscreen,
		"fullscreen cancel restores the previous window position",
		"%s -> %s" % [str(position_before_fullscreen), str(get_window().position)]
	)
	_check(_display_config_mode() == "windowed", "fullscreen cancel keeps windowed config")

	# Fullscreen confirm, then leave fullscreen to the retained 1280 target.
	await _click_logical(_menu.get_display_mode_button(true).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(5)
	await _click_logical(_menu.get_pending_confirm_button().get_global_rect().get_center())
	await _settle(5)
	_check(not _menu.is_display_pending(), "fullscreen confirm clears pending")
	_check(_display_config_mode() == "fullscreen", "fullscreen mode is persisted")
	_check(get_window().mode == Window.MODE_FULLSCREEN, "confirmed fullscreen remains active", str(get_window().mode))
	_check(_menu.get_volume_percent() == _volume_before_display, "fullscreen does not change volume", str(_menu.get_volume_percent()))

	await _click_logical(_menu.get_display_mode_button(false).get_global_rect().get_center())
	await _settle(2)
	_check(_menu.get_resolution_button(Vector2i(1280, 720)).selected, "windowed draft keeps the retained 1280 target")
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(5)
	_check(get_window().mode == Window.MODE_WINDOWED, "leaving fullscreen applies windowed mode", str(get_window().mode))
	_check(_window_size() == Vector2i(1280, 720), "leaving fullscreen restores the 1280 target", str(_window_size()))
	await _click_logical(_menu.get_pending_confirm_button().get_global_rect().get_center())
	await _settle(5)
	_check(_display_config_mode() == "windowed", "windowed mode is persisted after leaving fullscreen")
	_check(_display_config_size() == Vector2i(1280, 720), "windowed size remains 1280x720")

	# Close 返回 through the physical scaled hot zone.
	await _click_logical(_menu.get_return_button().get_global_rect().get_center())
	await _settle(4)
	_check(not _menu.is_settings_open(), "scaled click on 返回 closes settings")
	_check(get_viewport().gui_get_focus_owner() == _menu.get_settings_button(), "focus returns to settings after 返回")

	# Non-16:9 real window: integer 2x content with black bars and correct input.
	get_window().size = Vector2i(1400, 900)
	await _settle(5)
	var rect: Rect2i = DisplayOptions.content_rect(_window_size())
	_check(_window_size() == Vector2i(1400, 900), "non-16:9 test window is 1400x900", str(_window_size()))
	_check(rect == Rect2i(60, 90, 1280, 720), "1400x900 uses 2x content with 60/90 black bars", str(rect))
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "black-bar window keeps 640x360 logical canvas", str(get_viewport().get_visible_rect().size))
	await _open_settings_with_real_click()
	_check(_menu.is_settings_open(), "settings hot zone works inside black bars")
	await _click_logical(_menu.get_return_button().get_global_rect().get_center())
	await _settle(3)
	_check(not _menu.is_settings_open(), "返回 hot zone works inside black bars")

	# Real start click at the non-integer scaled window.
	await _click_logical(_menu.get_start_button().get_global_rect().get_center())
	await _settle(3)
	_check(_menu.get_start_request_count() == 1, "scaled start click starts exactly once", str(_menu.get_start_request_count()))
	_check(_menu.get_phase_name() == "title_fade", "scaled start enters the approved transition", _menu.get_phase_name())

	# Release during a pending display change must restore, not write config.
	await _free_level()
	get_window().size = Vector2i(1280, 720)
	await _settle(4)
	await _new_level()
	await _open_settings_with_real_click()
	var controller2: DisplaySettingsController = _menu.get_display_controller()
	_check(
		controller2.get_active_window_size() == Vector2i(1280, 720)
		and _window_size() == Vector2i(1280, 720),
		"saved 1280 windowed display loads in a fresh scene",
		str(_window_size())
	)
	await _click_logical(_menu.get_resolution_button(Vector2i(640, 360)).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(4)
	_check(_menu.is_display_pending(), "scene-release test starts pending")
	_check(_window_size() == Vector2i(640, 360), "scene-release test changed the window", str(_window_size()))
	await _free_level()
	await _settle(4)
	_check(_window_size() == Vector2i(1280, 720), "freeing the scene restores 1280x720", str(_window_size()))
	_check(_display_config_size() == Vector2i(1280, 720), "freeing the scene keeps the confirmed config")
	_check(_menu == null or not _menu.is_display_pending(), "freed scene leaves no pending state")

	# A saved fullscreen config must load visibly and still be exitable through
	# the same windowed apply/confirm path.
	_write_display_config("fullscreen", Vector2i(1280, 720))
	await _new_level()
	_check(
		get_window().mode == Window.MODE_FULLSCREEN,
		"saved fullscreen config loads at startup",
		str(get_window().mode)
	)
	_check(
		get_viewport().get_visible_rect().size == Vector2(640.0, 360.0),
		"loaded fullscreen keeps the 640x360 logical canvas",
		str(get_viewport().get_visible_rect().size)
	)
	await _open_settings_with_real_click()
	await _click_logical(_menu.get_display_mode_button(false).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(5)
	_check(get_window().mode == Window.MODE_WINDOWED, "loaded fullscreen can return to windowed", str(get_window().mode))
	await _click_logical(_menu.get_pending_confirm_button().get_global_rect().get_center())
	await _settle(5)
	_check(_display_config_mode() == "windowed", "leaving loaded fullscreen persists windowed mode")
	_check(_display_config_size() == Vector2i(1280, 720), "loaded fullscreen leaves a usable 1280 target")


# --- Level / input helpers -------------------------------------------------

func _new_level() -> void:
	if is_instance_valid(_level):
		await _free_level()
	_level = LEVEL_SCENE.instantiate() as Level01
	var temp_menu: StartMenu = _level.get_node("StartMenu") as StartMenu
	temp_menu.audio_settings_path = TEMP_AUDIO_PATH
	temp_menu.display_settings_path = TEMP_DISPLAY_PATH
	add_child(_level)
	await _physics(6)
	_menu = _level.get_menu()


func _free_level() -> void:
	if not is_instance_valid(_level):
		_menu = null
		return
	_level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_level = null
	_menu = null


func _open_settings_with_real_click() -> void:
	for _attempt: int in range(2):
		await _click_logical(_menu.get_settings_button().get_global_rect().get_center())
		await _settle(4)
		if _menu.is_settings_open():
			return


func _click_logical(logical_position: Vector2) -> void:
	DisplayServer.window_move_to_foreground(get_window().get_window_id())
	get_window().grab_focus()
	await get_tree().process_frame
	await _mouse_button_logical(logical_position, true)
	await get_tree().process_frame
	await _mouse_button_logical(logical_position, false)


func _mouse_button_logical(logical_position: Vector2, pressed: bool) -> void:
	var window_size: Vector2i = _window_size()
	var content: Rect2i = DisplayOptions.content_rect(window_size)
	var scale: float = float(content.size.x) / 640.0
	var physical: Vector2 = Vector2(content.position) + logical_position * scale
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = physical
	event.global_position = physical
	get_viewport().push_input(event, false)


func _slider_point(ratio: float) -> Vector2:
	var rect: Rect2 = _menu.get_slider().get_global_rect()
	return Vector2(
		rect.position.x + 2.5 + (rect.size.x - 5.0) * clampf(ratio, 0.0, 1.0),
		rect.get_center().y
	)


func _tap_key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _settle(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _window_size() -> Vector2i:
	return get_window().size


# --- Config helpers -------------------------------------------------------

func _display_config_exists() -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(TEMP_DISPLAY_PATH))


func _write_display_config(mode: String, size: Vector2i) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "version", 1)
	config.set_value("display", "mode", mode)
	config.set_value("display", "window_width", size.x)
	config.set_value("display", "window_height", size.y)
	config.save(TEMP_DISPLAY_PATH)


func _write_raw_display_config(text: String) -> void:
	var file: FileAccess = FileAccess.open(TEMP_DISPLAY_PATH, FileAccess.WRITE)
	if file == null:
		push_error("could not write raw display config")
		return
	file.store_string(text)
	file.close()


func _display_config_size() -> Vector2i:
	var config: ConfigFile = ConfigFile.new()
	if config.load(TEMP_DISPLAY_PATH) != OK:
		return Vector2i.ZERO
	return Vector2i(
		int(config.get_value("display", "window_width", 0)),
		int(config.get_value("display", "window_height", 0))
	)


func _display_config_mode() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(TEMP_DISPLAY_PATH) != OK:
		return ""
	return String(config.get_value("display", "mode", ""))


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


func _entry_fits(entries: Array[Dictionary], size: Vector2i) -> bool:
	for entry: Dictionary in entries:
		if entry.get("size", Vector2i.ZERO) == size:
			return bool(entry.get("fits", false))
	return false


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
	await _free_level()
	get_tree().paused = false
	AudioServer.set_bus_mute(0, _original_master_mute)
	AudioServer.set_bus_volume_db(0, _original_master_db)
	_remove_temp_audio()
	_remove_temp_display()
	_restore_window_state(_original_window_state)
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d gui=%s" % [_pass_count, _fail_count, str(_gui)])
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/display_settings_%s.log" % stamp, FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	get_tree().quit(0 if _fail_count == 0 else 1)
