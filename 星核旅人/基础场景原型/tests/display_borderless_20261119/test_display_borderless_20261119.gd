extends Node

## 2026-11-19 borderless 1920x1080 windowed option acceptance harness.
##
## Run logic + controller flow (headless):
##   Godot --headless --path . \
##     res://tests/display_borderless_20261119/test_display_borderless_20261119.tscn
##
## Run logic + real-window apply/cancel/timeout/readback + 640x360 screenshots:
##   Godot --path . \
##     res://tests/display_borderless_20261119/test_display_borderless_20261119.tscn
##
## Scope: DisplayOptions (pure rules), DisplaySettingsController (staging,
## rollback, config), and the StartMenu settings page.  It does not edit or
## relaunch levels, popups or art.

const SHOT_DIR: String = "res://tests/display_borderless_20261119/"
const CFG_FLOW: String = "user://test_display_borderless_flow.cfg"
const CFG_REAL: String = "user://test_display_borderless_real.cfg"
const CFG_MENU: String = "user://test_display_borderless_menu.cfg"
const CFG_AUDIO: String = "user://test_display_borderless_audio.cfg"
const CFG_LEGACY: String = "user://test_display_borderless_legacy.cfg"
const CFG_BAD: String = "user://test_display_borderless_bad.cfg"
const CFG_BIG: String = "user://test_display_borderless_big.cfg"

const SCREEN_1920: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(1920, 1080))
const USABLE_1920: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(1920, 1032))
const SMALL_SCREEN: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(1366, 768))

var _passes: int = 0
var _fails: Array[String] = []
var _capture: bool = false
var _shot_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture = DisplayServer.get_name() != "headless"
	print("DISPLAY_BORDERLESS capture=%s display=%s" % [
		str(_capture), DisplayServer.get_name()
	])
	_cleanup_configs()
	await get_tree().process_frame
	_test_pure_rules()
	await _test_controller_flow()
	if _capture:
		await _test_menu_ui_and_shots()
		await _test_real_window()
	else:
		print("SKIP real-window apply/cancel/timeout (headless)")
	print("DISPLAY_BORDERLESS_RESULT pass=%d fail=%d shots=%d" % [
		_passes, _fails.size(), _shot_count
	])
	for failure: String in _fails:
		print("FAIL: ", failure)
	if _fails.is_empty():
		print("DISPLAY_BORDERLESS_OK")
	_cleanup_configs()
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- helpers ---------------------------------------------------------------

func _check(ok: bool, label: String) -> bool:
	if ok:
		_passes += 1
		print("  PASS ", label)
	else:
		_fails.append(label)
		print("  FAIL ", label)
	return ok


func _wait_frames(count: int) -> void:
	for _i: int in range(maxi(count, 1)):
		await get_tree().process_frame


func _entry(entries: Array[Dictionary], size: Vector2i) -> Dictionary:
	for entry: Dictionary in entries:
		if entry.get("size", Vector2i.ZERO) == size:
			return entry
	return {}


func _remove_config(path: String) -> void:
	var global: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)
	var temp_global: String = ProjectSettings.globalize_path(path + ".tmp")
	if FileAccess.file_exists(temp_global):
		DirAccess.remove_absolute(temp_global)


func _cleanup_configs() -> void:
	for path: String in [CFG_FLOW, CFG_REAL, CFG_MENU, CFG_AUDIO, CFG_LEGACY, CFG_BAD, CFG_BIG]:
		_remove_config(path)


func _write_config(
	path: String,
	mode: Variant,
	width: Variant,
	height: Variant,
	borderless: Variant = null,
	version: int = 1
) -> void:
	_remove_config(path)
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "version", version)
	config.set_value("display", "mode", mode)
	config.set_value("display", "window_width", width)
	config.set_value("display", "window_height", height)
	if borderless != null:
		config.set_value("display", "borderless", borderless)
	var error: Error = config.save(path)
	_check(error == OK, "test config written: %s" % path.get_file())


func _load_config(path: String) -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(path)
	_check(error == OK, "test config readable: %s" % path.get_file())
	return config


func _read_back(path: String) -> Dictionary:
	var reader: DisplaySettingsController = DisplaySettingsController.new()
	reader.apply_override = func(_mode: int, _size: Vector2i, _pos: Vector2i, _center: bool) -> Dictionary:
		return {"ok": true, "message": ""}
	add_child(reader)
	reader.initialize(get_window(), path, true)
	var result: Dictionary = {
		"mode": reader.get_active_mode(),
		"window_size": reader.get_active_window_size(),
		"notice": reader.get_startup_notice(),
	}
	reader.dispose()
	reader.queue_free()
	return result


func _shot(file_name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(SHOT_DIR + file_name)
	var error: Error = image.save_png(path)
	_shot_count += 1
	print("SHOT %s size=%dx%d error=%d" % [
		path, image.get_width(), image.get_height(), error
	])
	_check(error == OK, "%s saved" % file_name)
	return image


# --- pure rules ------------------------------------------------------------

func _test_pure_rules() -> void:
	print("PURE RULES")
	var margin: Vector2i = DisplayOptions.DEFAULT_FRAME_MARGIN
	var available: Vector2i = DisplayOptions.available_size(USABLE_1920, margin)
	_check(available == Vector2i(1896, 976), "usable 1920x1032 minus frame = 1896x976")

	_check(DisplayOptions.is_borderless_size(Vector2i(1920, 1080)),
		"1920x1080 is the borderless candidate")
	_check(not DisplayOptions.is_borderless_size(Vector2i(1280, 720)),
		"1280x720 is not borderless")
	_check(DisplayOptions.size_label(Vector2i(1920, 1080)) == "1920×1080（无边框）",
		"1920x1080 label says 无边框")
	_check(DisplayOptions.size_label(Vector2i(1280, 720)) == "1280×720",
		"1280x720 label is unchanged")
	_check(DisplayOptions.is_borderless_choice(DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080)),
		"windowed + 1920x1080 is borderless")
	_check(not DisplayOptions.is_borderless_choice(DisplayOptions.Mode.FULLSCREEN, Vector2i(1920, 1080)),
		"fullscreen 1920x1080 is not the borderless windowed choice")

	_check(DisplayOptions.fits_bordered(Vector2i(1280, 720), USABLE_1920, margin),
		"1280x720 fits with a decorated frame")
	_check(not DisplayOptions.fits_bordered(Vector2i(1920, 1080), USABLE_1920, margin),
		"1920x1080 does not fit with a decorated frame")
	_check(DisplayOptions.fits(Vector2i(1920, 1080), USABLE_1920, margin, SCREEN_1920),
		"1920x1080 fits borderless on a 1920x1080 screen")
	_check(not DisplayOptions.fits(Vector2i(1920, 1080), USABLE_1920, margin, SMALL_SCREEN),
		"1920x1080 borderless rejected on a 1366x768 screen")
	_check(not DisplayOptions.fits(Vector2i(2560, 1440), USABLE_1920, margin, SCREEN_1920),
		"2560x1440 still does not fit")
	_check(DisplayOptions.fits_screen(Vector2i(1920, 1080), SCREEN_1920),
		"screen fit uses the physical resolution")

	var entries: Array[Dictionary] = DisplayOptions.candidate_entries(
		USABLE_1920, margin, SCREEN_1920
	)
	_check(entries.size() == 4, "four candidates are listed")
	var first: Dictionary = _entry(entries, Vector2i(640, 360))
	var second: Dictionary = _entry(entries, Vector2i(1280, 720))
	var third: Dictionary = _entry(entries, Vector2i(1920, 1080))
	var fourth: Dictionary = _entry(entries, Vector2i(2560, 1440))
	_check(bool(first.get("fits", false)) and not bool(first.get("borderless", true)),
		"640x360 is enabled and framed")
	_check(bool(second.get("fits", false)) and not bool(second.get("borderless", true)),
		"1280x720 is enabled and framed")
	_check(bool(third.get("fits", false)) and bool(third.get("borderless", false)),
		"1920x1080 is enabled and borderless")
	_check(String(third.get("label", "")) == "1920×1080（无边框）",
		"entry label carries 无边框")
	_check(not bool(fourth.get("fits", true)),
		"2560x1440 is disabled")
	_check(String(fourth.get("reason", "")).contains("超出本屏"),
		"2560x1440 shows an out-of-screen reason")

	_check(DisplayOptions.default_window_size(USABLE_1920, margin) == Vector2i(1280, 720),
		"default window stays 1280x720")
	_check(DisplayOptions.resolve_window_size(Vector2i(1920, 1080), USABLE_1920, margin, SCREEN_1920)
		== Vector2i(1920, 1080), "1920x1080 resolves to itself")
	_check(DisplayOptions.resolve_window_size(Vector2i(2560, 1440), USABLE_1920, margin, SCREEN_1920)
		== Vector2i(1280, 720), "2560x1440 falls back to 1280x720")

	var choice: Dictionary = DisplayOptions.validate_choice(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080), USABLE_1920, margin, SCREEN_1920
	)
	_check(bool(choice.get("ok", false)) and bool(choice.get("borderless", false)),
		"windowed 1920x1080 choice is accepted borderless")
	var too_big: Dictionary = DisplayOptions.validate_choice(
		DisplayOptions.Mode.WINDOWED, Vector2i(2560, 1440), USABLE_1920, margin, SCREEN_1920
	)
	_check(not bool(too_big.get("ok", true)), "windowed 2560x1440 choice is rejected")
	var small: Dictionary = DisplayOptions.validate_choice(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080), USABLE_1920, margin, SMALL_SCREEN
	)
	_check(not bool(small.get("ok", true)) and String(small.get("message", "")).contains("无边框"),
		"borderless 1920x1080 explains the screen requirement")
	var full: Dictionary = DisplayOptions.validate_choice(
		DisplayOptions.Mode.FULLSCREEN, Vector2i(1920, 1080), USABLE_1920, margin, SCREEN_1920
	)
	_check(bool(full.get("ok", false)) and not bool(full.get("borderless", true)),
		"fullscreen choice is unchanged and not borderless")

	var legacy: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 1280, 720, USABLE_1920, margin
	)
	_check(not bool(legacy.get("changed", true))
		and legacy.get("window_size", Vector2i.ZERO) == Vector2i(1280, 720)
		and not bool(legacy.get("borderless", true)),
		"old windowed 1280x720 config stays valid")
	var old_full: Dictionary = DisplayOptions.validate_saved_state(
		"fullscreen", 1920, 1080, USABLE_1920, margin
	)
	_check(int(old_full.get("mode", -1)) == DisplayOptions.Mode.FULLSCREEN
		and not bool(old_full.get("borderless", true)),
		"old fullscreen config stays fullscreen")
	var inferred: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 1920, 1080, USABLE_1920, margin
	)
	_check(int(inferred.get("mode", -1)) == DisplayOptions.Mode.WINDOWED
		and inferred.get("window_size", Vector2i.ZERO) == Vector2i(1920, 1080)
		and bool(inferred.get("borderless", false))
		and not bool(inferred.get("changed", true)),
		"missing borderless field is inferred from 1920x1080")
	var explicit: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 1920, 1080, USABLE_1920, margin, true
	)
	_check(bool(explicit.get("borderless", false))
		and not bool(explicit.get("changed", true)),
		"explicit borderless=true is accepted")
	var contradicted: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 1920, 1080, USABLE_1920, margin, false
	)
	_check(contradicted.get("window_size", Vector2i.ZERO) == Vector2i(1280, 720)
		and bool(contradicted.get("changed", false)),
		"borderless=false with 1920x1080 falls back to 1280x720")
	var unknown_mode: Dictionary = DisplayOptions.validate_saved_state(
		"borderless", 1920, 1080, USABLE_1920, margin
	)
	_check(int(unknown_mode.get("mode", -1)) == DisplayOptions.Mode.WINDOWED
		and bool(unknown_mode.get("changed", false))
		and String(unknown_mode.get("reason", "")).contains("显示模式无效"),
		"unknown mode falls back to windowed")
	var bad_flag: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 1920, 1080, USABLE_1920, margin, "yes"
	)
	_check(bool(bad_flag.get("changed", false))
		and String(bad_flag.get("reason", "")).contains("无边框设置无效"),
		"invalid borderless field is corrected")
	var oversized: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", 2560, 1440, USABLE_1920, margin, true
	)
	_check(oversized.get("window_size", Vector2i.ZERO) == Vector2i(1280, 720)
		and bool(oversized.get("changed", false)),
		"oversized saved size falls back")
	var corrupt: Dictionary = DisplayOptions.validate_saved_state(
		"windowed", -1, 0, USABLE_1920, margin
	)
	_check(corrupt.get("window_size", Vector2i.ZERO) == Vector2i(1280, 720)
		and String(corrupt.get("reason", "")).contains("窗口尺寸无效"),
		"corrupt saved size falls back")

	_check(DisplayOptions.integer_scale(Vector2i(1920, 1080)) == 3,
		"1920x1080 is exactly 3x")
	_check(DisplayOptions.content_rect(Vector2i(1920, 1080)) == Rect2i(Vector2i.ZERO, Vector2i(1920, 1080)),
		"1920x1080 content fills the window")
	_check(DisplayOptions.integer_scale(Vector2i(1280, 720)) == 2,
		"1280x720 is still 2x")
	_check(DisplayOptions.integer_scale(Vector2i(640, 360)) == 1,
		"640x360 is still 1x")
	_check(DisplayOptions.mode_from_value("FULLSCREEN") == DisplayOptions.Mode.FULLSCREEN,
		"mode_from_value is case insensitive")
	_check(DisplayOptions.mode_from_value("anything-else") == DisplayOptions.Mode.WINDOWED,
		"mode_from_value unknown value falls back to windowed")


# --- controller flow (headless, no real window changes) --------------------

func _test_controller_flow() -> void:
	print("CONTROLLER FLOW")
	_remove_config(CFG_FLOW)
	var flow: DisplaySettingsController = DisplaySettingsController.new()
	var calls: Array[Dictionary] = []
	flow.apply_override = func(mode: int, size: Vector2i, pos: Vector2i, center: bool) -> Dictionary:
		calls.append({"mode": mode, "size": size, "pos": pos, "center": center})
		return {"ok": true, "message": ""}
	add_child(flow)
	flow.initialize(get_window(), CFG_FLOW, true)
	_check(flow.get_pending_timeout_seconds() == 15.0, "pending timeout default is 15 s")
	_check(flow.get_active_mode() == DisplayOptions.Mode.WINDOWED, "initial mode is windowed")
	_check(flow.get_active_window_size() == Vector2i(1280, 720),
		"initial size is 1280x720 without a config")
	_check(flow.is_size_available(Vector2i(1920, 1080)),
		"controller reports borderless 1920x1080 available")
	_check(not flow.is_size_available(Vector2i(2560, 1440)),
		"controller reports 2560x1440 unavailable")
	var entries: Array[Dictionary] = flow.get_candidate_entries()
	_check(bool(_entry(entries, Vector2i(1920, 1080)).get("borderless", false)),
		"controller candidate entries expose borderless")

	var before: int = calls.size()
	var started: Dictionary = flow.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080)
	)
	_check(bool(started.get("ok", false)), "begin_apply borderless 1920x1080 succeeds")
	_check(flow.is_pending(), "borderless apply is pending")
	_check(flow.get_pending_window_size() == Vector2i(1920, 1080),
		"pending size is 1920x1080")
	_check(calls.size() > before and calls[calls.size() - 1].get("size", Vector2i.ZERO) == Vector2i(1920, 1080),
		"apply override received 1920x1080")
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(CFG_FLOW)),
		"pending apply does not write config")
	var remaining: float = flow.get_pending_remaining_seconds()
	_check(remaining > 14.0 and remaining <= 15.0, "pending countdown starts near 15 s")

	flow.pending_timeout_seconds = 0.25
	flow.cancel_pending("test_setup")
	_check(not flow.is_pending(), "setup cancel clears pending")
	_check(flow.get_active_window_size() == Vector2i(1280, 720),
		"setup cancel keeps 1280x720 active")

	var timeout_calls: int = calls.size()
	flow.pending_timeout_seconds = 0.25
	var timeout_begin: Dictionary = flow.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080)
	)
	_check(bool(timeout_begin.get("ok", false)), "timeout test begin_apply succeeds")
	await get_tree().create_timer(0.55).timeout
	_check(not flow.is_pending(), "short timeout auto-cancels pending")
	_check(flow.get_active_window_size() == Vector2i(1280, 720),
		"timeout restores the previous size")
	_check(calls.size() > timeout_calls
		and calls[calls.size() - 1].get("size", Vector2i.ZERO) == Vector2i(1280, 720),
		"timeout restore override received the previous size")

	flow.pending_timeout_seconds = 15.0
	var cancel_begin: Dictionary = flow.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080)
	)
	_check(bool(cancel_begin.get("ok", false)), "cancel test begin_apply succeeds")
	flow.cancel_pending("test_cancel")
	_check(not flow.is_pending(), "cancel clears pending")
	_check(flow.get_active_window_size() == Vector2i(1280, 720),
		"cancel restores 1280x720")

	var failed_calls: int = calls.size()
	flow.apply_override = func(_mode: int, _size: Vector2i, _pos: Vector2i, _center: bool) -> Dictionary:
		failed_calls += 1
		return {"ok": false, "message": "模拟失败"}
	var failed: Dictionary = flow.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080)
	)
	_check(not bool(failed.get("ok", true)), "apply failure is reported")
	_check(not flow.is_pending(), "apply failure leaves no pending state")
	_check(flow.get_active_window_size() == Vector2i(1280, 720),
		"apply failure keeps the previous size")
	_check(failed_calls >= 2, "apply failure also restores the snapshot")

	flow.apply_override = func(mode: int, size: Vector2i, pos: Vector2i, center: bool) -> Dictionary:
		calls.append({"mode": mode, "size": size, "pos": pos, "center": center})
		return {"ok": true, "message": ""}
	var confirm_begin: Dictionary = flow.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080)
	)
	_check(bool(confirm_begin.get("ok", false)), "confirm test begin_apply succeeds")
	var confirmed: Dictionary = flow.confirm_pending()
	_check(bool(confirmed.get("ok", false)) and bool(confirmed.get("saved", false)),
		"confirm applies and saves")
	_check(not flow.is_pending(), "confirm clears pending")
	_check(flow.get_active_window_size() == Vector2i(1920, 1080),
		"confirm makes 1920x1080 active")

	var saved: ConfigFile = _load_config(CFG_FLOW)
	_check(int(saved.get_value("display", "version", -1)) == 2,
		"config version is 2")
	_check(String(saved.get_value("display", "mode", "")) == "windowed",
		"saved mode is windowed")
	_check(int(saved.get_value("display", "window_width", -1)) == 1920
		and int(saved.get_value("display", "window_height", -1)) == 1080,
		"saved size is 1920x1080")
	_check(bool(saved.get_value("display", "borderless", false)),
		"saved borderless flag is true")

	var reread: Dictionary = _read_back(CFG_FLOW)
	_check(int(reread.get("mode", -1)) == DisplayOptions.Mode.WINDOWED,
		"readback keeps windowed mode")
	_check(reread.get("window_size", Vector2i.ZERO) == Vector2i(1920, 1080),
		"readback restores 1920x1080")
	_check(String(reread.get("notice", "")).is_empty(),
		"readback needs no correction notice")
	flow.dispose()
	flow.queue_free()
	await get_tree().process_frame

	_write_config(CFG_LEGACY, "windowed", 1280, 720, null, 1)
	var legacy_read: Dictionary = _read_back(CFG_LEGACY)
	_check(legacy_read.get("window_size", Vector2i.ZERO) == Vector2i(1280, 720)
		and String(legacy_read.get("notice", "")).is_empty(),
		"legacy windowed 1280x720 config reads without changes")

	_write_config(CFG_LEGACY, "fullscreen", 1920, 1080, null, 1)
	var legacy_full: Dictionary = _read_back(CFG_LEGACY)
	_check(int(legacy_full.get("mode", -1)) == DisplayOptions.Mode.FULLSCREEN,
		"legacy fullscreen config reads as fullscreen")

	_write_config(CFG_LEGACY, "windowed", 1920, 1080, null, 1)
	var legacy_borderless: Dictionary = _read_back(CFG_LEGACY)
	_check(legacy_borderless.get("window_size", Vector2i.ZERO) == Vector2i(1920, 1080)
		and String(legacy_borderless.get("notice", "")).is_empty(),
		"legacy 1920x1080 without a borderless field upgrades cleanly")

	_write_config(CFG_BAD, "borderless", 1920, 1080, null, 2)
	var bad_mode: Dictionary = _read_back(CFG_BAD)
	_check(int(bad_mode.get("mode", -1)) == DisplayOptions.Mode.WINDOWED
		and bad_mode.get("window_size", Vector2i.ZERO) == Vector2i(1920, 1080)
		and String(bad_mode.get("notice", "")).contains("显示模式无效"),
		"unknown saved mode falls back to windowed borderless")

	_write_config(CFG_BAD, "windowed", 1920, 1080, false, 2)
	var bad_flag: Dictionary = _read_back(CFG_BAD)
	_check(bad_flag.get("window_size", Vector2i.ZERO) == Vector2i(1280, 720)
		and String(bad_flag.get("notice", "")).contains("超出"),
		"borderless=false 1920x1080 is corrected at load")

	_write_config(CFG_BAD, "windowed", 1920, 1080, "yes", 2)
	var bad_type: Dictionary = _read_back(CFG_BAD)
	_check(bad_type.get("window_size", Vector2i.ZERO) == Vector2i(1920, 1080)
		and String(bad_type.get("notice", "")).contains("无边框设置无效"),
		"invalid borderless field type is corrected")

	_write_config(CFG_BIG, "windowed", 2560, 1440, true, 2)
	var oversized: Dictionary = _read_back(CFG_BIG)
	_check(oversized.get("window_size", Vector2i.ZERO) == Vector2i(1280, 720)
		and String(oversized.get("notice", "")).contains("超出"),
		"oversized saved borderless size is corrected")


# --- menu UI and screenshots ----------------------------------------------

func _test_menu_ui_and_shots() -> void:
	print("MENU UI")
	_remove_config(CFG_MENU)
	_remove_config(CFG_AUDIO)
	var menu: StartMenu = StartMenu.new()
	menu.name = "BorderlessTestMenu"
	menu.settings_host_mode = true
	menu.display_settings_path = CFG_MENU
	menu.audio_settings_path = CFG_AUDIO
	add_child(menu)
	await get_tree().process_frame
	menu.open_settings_host()
	await get_tree().process_frame

	_check(menu.is_settings_open(), "settings host opens")
	var window: Window = get_window()
	_check(window.size == Vector2i(1280, 720), "menu starts at 1280x720")
	var res_640: PixelMenuButton = menu.get_resolution_button(Vector2i(640, 360))
	var res_1280: PixelMenuButton = menu.get_resolution_button(Vector2i(1280, 720))
	var res_1920: PixelMenuButton = menu.get_resolution_button(Vector2i(1920, 1080))
	var res_2560: PixelMenuButton = menu.get_resolution_button(Vector2i(2560, 1440))
	_check(res_640 != null and res_1280 != null and res_1920 != null and res_2560 != null,
		"all four resolution buttons exist")
	_check(res_1920.text == "1920×1080（无边框）",
		"1920x1080 button text includes 无边框")
	_check(not res_640.disabled and not res_1280.disabled and not res_1920.disabled,
		"640, 1280 and borderless 1920 are clickable")
	_check(res_2560.disabled, "2560x1440 is disabled")
	var note: String = menu.get_display_note_text()
	_check(note.contains("无边框窗口") and note.contains("3× 整数缩放"),
		"note explains borderless 3x integer scaling")
	_check(note.contains("2560×1440") and note.contains("超出本屏"),
		"note gives the 2560x1440 reason")
	_check(note.contains("\n"), "note uses two lines")

	# Apply 640x360 through the real UI so the settings page screenshot is the
	# actual 640x360 window the user asked to inspect.
	res_640.pressed.emit()
	await get_tree().process_frame
	_check(not menu.get_apply_button().disabled, "apply enables after choosing 640")
	menu.get_apply_button().pressed.emit()
	await get_tree().process_frame
	_check(menu.is_display_pending(), "640 apply shows the confirmation overlay")
	menu.get_pending_confirm_button().pressed.emit()
	await get_tree().process_frame
	_check(window.size == Vector2i(640, 360), "640x360 window applied")
	_check(not window.borderless, "640x360 is framed")
	_check(menu.get_display_status_text().contains("已保存"), "640x360 confirm saves")
	var settings_shot: Image = await _shot("settings_page_640_borderless_option.png")
	_check(settings_shot.get_width() == 640 and settings_shot.get_height() == 360,
		"settings screenshot is 640x360")

	# Select and confirm the borderless option through the same UI.
	res_1920.pressed.emit()
	await get_tree().process_frame
	_check(not menu.get_apply_button().disabled, "apply enables after choosing 1920")
	menu.get_apply_button().pressed.emit()
	await get_tree().process_frame
	_check(menu.is_display_pending(), "1920 apply is pending")
	_check(window.mode == Window.MODE_WINDOWED, "borderless stays Window.MODE_WINDOWED")
	_check(window.borderless, "1920 window is borderless")
	_check(window.size == Vector2i(1920, 1080), "1920 window is exactly 1920x1080")
	_check(menu.get_pending_countdown_text().contains("秒后自动恢复"),
		"pending countdown is visible")
	var pending_shot: Image = await _shot("pending_1920_borderless.png")
	_check(pending_shot.get_width() == 640 and pending_shot.get_height() == 360,
		"pending logical screenshot is 640x360 at the 3x window")
	menu.get_pending_confirm_button().pressed.emit()
	await get_tree().process_frame
	_check(not menu.is_display_pending(), "1920 confirm clears pending")
	_check(window.borderless and window.size == Vector2i(1920, 1080),
		"1920 confirm keeps the borderless window")
	_check(menu.get_display_status_text().contains("已保存"), "1920 confirm saves")
	var saved_menu: ConfigFile = _load_config(CFG_MENU)
	_check(bool(saved_menu.get_value("display", "borderless", false)),
		"menu config saved borderless=true")
	var applied_shot: Image = await _shot("settings_applied_1920_borderless.png")
	_check(applied_shot.get_width() == 640 and applied_shot.get_height() == 360,
		"applied logical screenshot is 640x360 at the 3x window")

	# Cancel must restore the previous borderless window too.
	res_640.pressed.emit()
	await get_tree().process_frame
	menu.get_apply_button().pressed.emit()
	await get_tree().process_frame
	_check(menu.is_display_pending(), "cancel test is pending")
	_check(window.size == Vector2i(640, 360) and not window.borderless,
		"cancel test applied 640 first")
	menu.get_pending_cancel_button().pressed.emit()
	await get_tree().process_frame
	_check(not menu.is_display_pending(), "cancel button clears pending")
	_check(window.borderless and window.size == Vector2i(1920, 1080),
		"cancel restores the previous borderless 1920 window")
	_check(menu.get_display_status_text().contains("已恢复"), "cancel status is shown")

	# Fullscreen remains MODE_FULLSCREEN and a cancel returns to the borderless
	# window exactly as it was.
	menu.get_display_mode_button(true).pressed.emit()
	await get_tree().process_frame
	menu.get_apply_button().pressed.emit()
	await get_tree().process_frame
	_check(menu.is_display_pending(), "fullscreen from borderless is pending")
	_check(window.mode == Window.MODE_FULLSCREEN,
		"fullscreen from borderless enters MODE_FULLSCREEN")
	menu.get_pending_cancel_button().pressed.emit()
	await _wait_frames(2)
	print("FULLSCREEN_CANCEL mode=%d borderless=%s size=%s pos=%s active=%s draft=%s" % [
		window.mode, str(window.borderless), window.size, window.position,
		menu.get_display_controller().get_active_window_size(),
		menu.get_display_controller().get_active_mode(),
	])
	_check(window.mode == Window.MODE_WINDOWED
		and window.borderless
		and window.size == Vector2i(1920, 1080),
		"fullscreen cancel restores the borderless 1920 window")

	# Starting in fullscreen and choosing windowed 1920x1080 must also work;
	# this is the path a user with the old fullscreen config takes.
	menu.get_display_mode_button(true).pressed.emit()
	await get_tree().process_frame
	menu.get_apply_button().pressed.emit()
	await get_tree().process_frame
	menu.get_pending_confirm_button().pressed.emit()
	await get_tree().process_frame
	_check(window.mode == Window.MODE_FULLSCREEN, "fullscreen confirmed for the switch test")
	menu.get_display_mode_button(false).pressed.emit()
	await get_tree().process_frame
	menu.get_resolution_button(Vector2i(1920, 1080)).pressed.emit()
	await get_tree().process_frame
	menu.get_apply_button().pressed.emit()
	await _wait_frames(2)
	_check(menu.is_display_pending(), "fullscreen to borderless apply is pending")
	_check(window.mode == Window.MODE_WINDOWED
		and window.borderless
		and window.size == Vector2i(1920, 1080),
		"fullscreen to borderless apply ends as a 1920 windowed window")
	menu.get_pending_confirm_button().pressed.emit()
	await get_tree().process_frame
	_check(not menu.is_display_pending()
		and window.mode == Window.MODE_WINDOWED
		and window.borderless
		and window.size == Vector2i(1920, 1080),
		"fullscreen to borderless confirm keeps the windowed borderless state")

	# Leave the test session at the normal framed default.
	res_1280.pressed.emit()
	await get_tree().process_frame
	menu.get_apply_button().pressed.emit()
	await get_tree().process_frame
	menu.get_pending_confirm_button().pressed.emit()
	await get_tree().process_frame
	_check(window.size == Vector2i(1280, 720) and not window.borderless,
		"cleanup restores 1280x720 framed")
	menu.hide_settings_host()
	menu.queue_free()
	await get_tree().process_frame
	_remove_config(CFG_MENU)
	_remove_config(CFG_AUDIO)


# --- real window -----------------------------------------------------------

func _test_real_window() -> void:
	print("REAL WINDOW")
	_remove_config(CFG_REAL)
	var window: Window = get_window()
	var original_mode: int = window.mode
	var original_size: Vector2i = window.size
	var original_position: Vector2i = window.position
	print("ENV screen=%s usable=%s usable_pos=%s window_size=%s window_pos=%s borderless=%s mode=%d" % [
		DisplayOptions.format_size(DisplayServer.screen_get_size()),
		DisplayOptions.format_size(DisplayServer.screen_get_usable_rect().size),
		DisplayServer.screen_get_usable_rect().position,
		DisplayOptions.format_size(window.size),
		window.position,
		str(window.borderless),
		window.mode,
	])
	_check(DisplayServer.screen_get_size() == Vector2i(1920, 1080),
		"physical screen is 1920x1080")
	_check(DisplayServer.screen_get_usable_rect().size == Vector2i(1920, 1032),
		"usable work area is 1920x1032")
	_check(original_mode == Window.MODE_WINDOWED,
		"real test starts in Window.MODE_WINDOWED")
	_check(original_size == Vector2i(1280, 720) and not window.borderless,
		"real test starts at 1280x720 framed")

	var controller: DisplaySettingsController = DisplaySettingsController.new()
	var cancelled_reasons: Array[String] = []
	controller.pending_cancelled.connect(func(reason: String) -> void:
		cancelled_reasons.append(reason)
	)
	add_child(controller)
	controller.initialize(window, CFG_REAL, true)
	_check(controller.get_active_window_size() == Vector2i(1280, 720),
		"real controller starts at 1280x720")
	_check(window.size == Vector2i(1280, 720) and not window.borderless,
		"real window starts framed at 1280x720")

	# 640x360 remains a framed window.
	var r640: Dictionary = controller.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(640, 360)
	)
	_check(bool(r640.get("ok", false)), "real 640x360 apply succeeds")
	_check(window.size == Vector2i(640, 360) and not window.borderless,
		"real 640x360 is framed and sized")
	controller.cancel_pending("test_640")
	_check(window.size == Vector2i(1280, 720) and not window.borderless,
		"real 640 cancel restores 1280x720 framed")

	# Apply the borderless candidate and inspect the actual OS window.
	var r1920: Dictionary = controller.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080)
	)
	_check(bool(r1920.get("ok", false)), "real borderless apply succeeds")
	await get_tree().process_frame
	var decorated: Vector2i = DisplayServer.window_get_size_with_decorations(window.get_window_id())
	var screen_position: Vector2i = DisplayServer.screen_get_position()
	print("APPLY mode=%d size=%s pos=%s borderless=%s decorated=%s content=%s scale=%d pending=%s remaining=%.2f" % [
		window.mode,
		DisplayOptions.format_size(window.size),
		window.position,
		str(window.borderless),
		DisplayOptions.format_size(decorated),
		DisplayOptions.format_size(controller.get_active_window_size()),
		DisplayOptions.integer_scale(window.size),
		str(controller.is_pending()),
		controller.get_pending_remaining_seconds(),
	])
	_check(window.mode == Window.MODE_WINDOWED, "real borderless is still windowed mode")
	_check(window.borderless, "real window borderless flag is true")
	_check(window.size == Vector2i(1920, 1080), "real window is 1920x1080")
	_check(decorated == Vector2i(1920, 1080),
		"window_get_size_with_decorations equals 1920x1080 (no title bar)")
	_check(window.position == screen_position,
		"borderless window is anchored to the screen origin")
	_check(DisplayOptions.integer_scale(window.size) == 3,
		"real borderless window uses exact 3x integer scale")
	_check(window.content_scale_size == Vector2i(640, 360),
		"content scale stays 640x360")
	_check(controller.get_pending_remaining_seconds() > 14.0,
		"real pending countdown starts near 15 s")

	controller.cancel_pending("test_borderless_cancel")
	_check(not controller.is_pending(), "real borderless cancel clears pending")
	_check(window.size == original_size and not window.borderless,
		"real borderless cancel restores the original framed window")
	_check(window.position == original_position,
		"real borderless cancel restores the original window position")
	print("CANCEL size=%s pos=%s borderless=%s mode=%d" % [
		DisplayOptions.format_size(window.size), window.position,
		str(window.borderless), window.mode,
	])

	# Fullscreen is unchanged.
	var rfull: Dictionary = controller.begin_apply(
		DisplayOptions.Mode.FULLSCREEN, Vector2i(1920, 1080)
	)
	_check(bool(rfull.get("ok", false)), "real fullscreen apply succeeds")
	_check(window.mode == Window.MODE_FULLSCREEN, "real window enters MODE_FULLSCREEN")
	controller.cancel_pending("test_fullscreen")
	_check(window.mode == Window.MODE_WINDOWED and window.size == original_size,
		"real fullscreen cancel restores the windowed window")
	_check(not window.borderless, "real fullscreen cancel restores a framed window")

	# Real 15 s timeout rollback.
	var timeout_start: int = Time.get_ticks_msec()
	var rtimeout: Dictionary = controller.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080)
	)
	_check(bool(rtimeout.get("ok", false)), "real 15 s timeout apply starts")
	_check(window.borderless and window.size == Vector2i(1920, 1080),
		"real timeout state is borderless 1920x1080")
	while controller.is_pending() and Time.get_ticks_msec() - timeout_start < 18000:
		await get_tree().process_frame
	var elapsed: int = Time.get_ticks_msec() - timeout_start
	print("TIMEOUT elapsed_ms=%d reasons=%s size=%s borderless=%s" % [
		elapsed, str(cancelled_reasons),
		DisplayOptions.format_size(window.size), str(window.borderless),
	])
	_check(not controller.is_pending(), "real 15 s timeout clears pending")
	_check(elapsed >= 14500 and elapsed <= 17000,
		"real timeout fired after about 15 s")
	_check(cancelled_reasons.has("timeout"), "real timeout reason is timeout")
	_check(window.size == original_size and not window.borderless,
		"real timeout restores the original framed window")

	# Confirm saves borderless, and a fresh controller reads it back.
	var rconfirm: Dictionary = controller.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(1920, 1080)
	)
	_check(bool(rconfirm.get("ok", false)), "real confirm apply starts")
	var confirmation: Dictionary = controller.confirm_pending()
	_check(bool(confirmation.get("ok", false)) and bool(confirmation.get("saved", false)),
		"real confirm saves")
	_check(window.borderless and window.size == Vector2i(1920, 1080),
		"real confirm leaves borderless 1920x1080")
	var saved: ConfigFile = _load_config(CFG_REAL)
	_check(bool(saved.get_value("display", "borderless", false)),
		"real config saved borderless=true")
	controller.dispose()
	controller.queue_free()
	await get_tree().process_frame

	var reader: DisplaySettingsController = DisplaySettingsController.new()
	add_child(reader)
	reader.initialize(window, CFG_REAL, true)
	print("READBACK active_mode=%d active_size=%s window_mode=%d window_size=%s borderless=%s notice=%s" % [
		reader.get_active_mode(), DisplayOptions.format_size(reader.get_active_window_size()),
		window.mode, DisplayOptions.format_size(window.size),
		str(window.borderless), reader.get_startup_notice(),
	])
	_check(reader.get_active_mode() == DisplayOptions.Mode.WINDOWED,
		"restart readback mode is windowed")
	_check(reader.get_active_window_size() == Vector2i(1920, 1080),
		"restart readback size is 1920x1080")
	_check(reader.get_startup_notice().is_empty(), "restart readback has no correction notice")
	_check(window.borderless and window.size == Vector2i(1920, 1080),
		"restart readback re-applies the borderless window")
	_check(window.mode == Window.MODE_WINDOWED,
		"restart readback does not use exclusive fullscreen")

	# Cleanup to the framed default and remove the test config.
	var cleanup: Dictionary = reader.begin_apply(
		DisplayOptions.Mode.WINDOWED, Vector2i(1280, 720)
	)
	_check(bool(cleanup.get("ok", false)), "readback cleanup apply starts")
	reader.confirm_pending()
	_check(window.size == Vector2i(1280, 720) and not window.borderless,
		"readback cleanup restores 1280x720 framed")
	reader.dispose()
	reader.queue_free()
	await get_tree().process_frame
	_remove_config(CFG_REAL)
	_check(window.mode == original_mode, "test ends in the original window mode")
