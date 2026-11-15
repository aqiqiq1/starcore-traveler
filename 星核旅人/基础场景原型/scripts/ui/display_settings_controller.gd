class_name DisplaySettingsController
extends Node

## Runtime owner of window mode / window size / pending confirmation.
##
## The logical canvas is always 640x360.  Windowed mode uses an approved 16:9
## integer multiple that fits the current screen's usable rectangle; fullscreen
## uses Window.MODE_FULLSCREEN (borderless desktop fullscreen, no physical mode
## switch).  The root Window is kept at KEEP aspect with integer stretch, so odd
## desktop sizes get black bars instead of a stretched or larger world.
##
## Changing a setting is staged: begin_apply() changes the window, starts an
## absolute-clock deadline and leaves the config untouched.  Only confirm_pending()
## writes user://display_settings.cfg.  Timeout, Esc, scene release or exit
## restores the previous mode/size/position/content scale.

signal pending_started
signal pending_cancelled(reason: String)
signal confirmed(saved: bool)
signal apply_failed(message: String)

const CONFIG_VERSION: int = 1
const PENDING_TIMEOUT_SECONDS: float = 10.0
const DEFAULT_CONFIG_PATH: String = "user://display_settings.cfg"
const NO_POSITION: Vector2i = Vector2i(-2147483647, -2147483647)

## Test-only injection: func(mode:int, size:Vector2i, position:Vector2i, center:bool)
## -> Dictionary {ok:bool, message:String}.  `mode` is DisplayOptions.Mode
## (0=windowed, 1=fullscreen), never a Window.MODE_* enum.  Empty in production.
var apply_override: Callable = Callable()

var config_path: String = DEFAULT_CONFIG_PATH
var pending_timeout_seconds: float = PENDING_TIMEOUT_SECONDS

var _window: Window = null
var _headless: bool = false
var _initialized: bool = false
var _frame_margin: Vector2i = DisplayOptions.DEFAULT_FRAME_MARGIN

var _active_mode: int = DisplayOptions.Mode.WINDOWED
var _active_window_size: Vector2i = DisplayOptions.DEFAULT_WINDOW_SIZE

var _pending: bool = false
var _pending_mode: int = DisplayOptions.Mode.WINDOWED
var _pending_window_size: Vector2i = DisplayOptions.DEFAULT_WINDOW_SIZE
var _pending_deadline_msec: int = 0
var _snapshot: Dictionary = {}

var _startup_notice: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func initialize(window: Window, path: String = DEFAULT_CONFIG_PATH, apply_now: bool = true) -> void:
	if _initialized:
		return
	_initialized = true
	_window = window
	config_path = path
	_headless = DisplayServer.get_name() == "headless"
	_frame_margin = _measure_frame_margin()
	if not apply_now:
		# Menu-disabled test/legacy instances keep the project Window untouched
		# and never read the user's real display config.
		_active_mode = DisplayOptions.Mode.WINDOWED
		_active_window_size = DisplayOptions.default_window_size(_usable_rect(), _frame_margin)
		return
	_apply_content_scale()
	var startup: Dictionary = _load_startup_state()
	_active_mode = int(startup.get("mode", DisplayOptions.Mode.WINDOWED))
	_active_window_size = startup.get("window_size", DisplayOptions.DEFAULT_WINDOW_SIZE) as Vector2i
	_startup_notice = String(startup.get("notice", ""))
	var result: Dictionary = _set_window_state(
		_active_mode, _active_window_size, NO_POSITION, true
	)
	if not bool(result.get("ok", false)):
		push_warning("DisplaySettings: could not apply initial display: %s" % String(result.get("message", "")))
		_active_mode = DisplayOptions.Mode.WINDOWED
		_active_window_size = DisplayOptions.default_window_size(_usable_rect(), _frame_margin)
		_startup_notice = "初始显示切换失败，已回到窗口模式"
		_set_window_state(_active_mode, _active_window_size, NO_POSITION, true)


func _process(_delta: float) -> void:
	if not _pending:
		return
	if Time.get_ticks_msec() >= _pending_deadline_msec:
		cancel_pending("timeout")


func _exit_tree() -> void:
	dispose()


func dispose() -> void:
	if _pending:
		_pending = false
		_restore_window_state(_snapshot)
		_snapshot = {}
	set_process(false)


# --- Public state ----------------------------------------------------------

func get_active_mode() -> int:
	return _active_mode


func get_active_window_size() -> Vector2i:
	return _active_window_size


func is_pending() -> bool:
	return _pending


func get_pending_mode() -> int:
	return _pending_mode


func get_pending_window_size() -> Vector2i:
	return _pending_window_size


func get_pending_remaining_seconds() -> float:
	if not _pending:
		return 0.0
	return maxf(0.0, float(_pending_deadline_msec - Time.get_ticks_msec()) / 1000.0)


func get_pending_timeout_seconds() -> float:
	return pending_timeout_seconds


func get_startup_notice() -> String:
	return _startup_notice


func get_config_path() -> String:
	return config_path


func is_headless() -> bool:
	return _headless


func get_frame_margin() -> Vector2i:
	return _frame_margin


func get_usable_rect() -> Rect2i:
	return _usable_rect()


func get_candidate_entries() -> Array[Dictionary]:
	return DisplayOptions.candidate_entries(_usable_rect(), _frame_margin)


func is_size_available(size: Vector2i) -> bool:
	return DisplayOptions.fits(size, _usable_rect(), _frame_margin)


func get_default_window_size() -> Vector2i:
	return DisplayOptions.default_window_size(_usable_rect(), _frame_margin)


# --- Apply / confirm / cancel ---------------------------------------------

func begin_apply(mode: int, window_size: Vector2i) -> Dictionary:
	if _pending:
		return {"ok": false, "message": "已有待确认的显示设置"}
	if mode == _active_mode and window_size == _active_window_size:
		return {"ok": false, "message": "显示设置没有变化"}
	var usable: Rect2i = _usable_rect()
	var choice: Dictionary = DisplayOptions.validate_choice(mode, window_size, usable, _frame_margin)
	if not bool(choice.get("ok", false)):
		var failure: String = String(choice.get("message", "显示设置无效"))
		apply_failed.emit(failure)
		return {"ok": false, "message": failure}
	mode = int(choice.get("mode", mode))
	window_size = choice.get("window_size", window_size) as Vector2i
	var snapshot: Dictionary = _capture_window_state()
	var result: Dictionary = _set_window_state(mode, window_size, NO_POSITION, true)
	if not bool(result.get("ok", false)):
		var message: String = String(result.get("message", "窗口切换失败"))
		_restore_window_state(snapshot)
		var final_message: String = "切换失败，已恢复原显示设置：%s" % message
		apply_failed.emit(final_message)
		return {"ok": false, "message": final_message}
	_snapshot = snapshot
	_pending = true
	_pending_mode = mode
	_pending_window_size = window_size
	var timeout: float = maxf(pending_timeout_seconds, 0.1)
	_pending_deadline_msec = Time.get_ticks_msec() + int(round(timeout * 1000.0))
	pending_started.emit()
	return {"ok": true, "message": ""}


func confirm_pending() -> Dictionary:
	if not _pending:
		return {"ok": false, "saved": false, "message": "没有待确认的显示设置"}
	var usable: Rect2i = _usable_rect()
	var choice: Dictionary = DisplayOptions.validate_choice(
		_pending_mode, _pending_window_size, usable, _frame_margin
	)
	if not bool(choice.get("ok", false)):
		var message: String = String(choice.get("message", "显示设置已不可用"))
		cancel_pending("invalid")
		return {"ok": false, "saved": false, "message": message}
	if not _pending_window_is_effective():
		cancel_pending("verify_failed")
		return {"ok": false, "saved": false, "message": "显示切换未生效，已恢复原设置"}
	var saved: bool = _save_config(_pending_mode, _pending_window_size)
	_active_mode = _pending_mode
	_active_window_size = _pending_window_size
	_pending = false
	_snapshot = {}
	confirmed.emit(saved)
	return {
		"ok": true,
		"saved": saved,
		"message": "" if saved else "已应用，但保存失败",
	}


func cancel_pending(reason: String) -> bool:
	if not _pending:
		return false
	_pending = false
	var restored: Dictionary = _restore_window_state(_snapshot)
	_snapshot = {}
	if not bool(restored.get("ok", true)):
		push_warning("DisplaySettings: could not restore previous display: %s" % String(restored.get("message", "")))
	pending_cancelled.emit(reason)
	return true


# --- Screen / content scale ------------------------------------------------

func _apply_content_scale() -> void:
	if _headless or _window == null:
		return
	_window.content_scale_size = DisplayOptions.LOGICAL_SIZE
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	_window.content_scale_factor = 1.0


func _measure_frame_margin() -> Vector2i:
	if _headless or _window == null:
		return DisplayOptions.DEFAULT_FRAME_MARGIN
	var measured: Vector2i = DisplayOptions.DEFAULT_FRAME_MARGIN
	if DisplayServer.has_method("window_get_size_with_decorations"):
		var raw: Variant = DisplayServer.call("window_get_size_with_decorations", _window_id())
		if typeof(raw) == TYPE_VECTOR2I:
			var decorated: Vector2i = raw
			var extra: Vector2i = decorated - _window.size
			if extra.x >= 0 and extra.y >= 0:
				measured = extra
	# Keep an explicit safety band beyond the measured border/title bar.
	return Vector2i(maxi(measured.x, 16) + 8, maxi(measured.y, 39) + 8)


func _usable_rect() -> Rect2i:
	if _headless:
		return Rect2i(Vector2i.ZERO, Vector2i(1920, 1080))
	var screen: int = DisplayServer.window_get_current_screen(_window_id())
	if screen < 0:
		screen = DisplayServer.get_primary_screen()
	var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if rect.size.x <= 0 or rect.size.y <= 0:
		rect = Rect2i(Vector2i.ZERO, Vector2i(1280, 720))
	return rect


func _window_id() -> int:
	if _window == null:
		return 0
	if _window.has_method("get_window_id"):
		return int(_window.call("get_window_id"))
	return 0


# --- Window state ----------------------------------------------------------

func _capture_window_state() -> Dictionary:
	if _window == null:
		return {}
	if _headless and not apply_override.is_valid():
		return {}
	if _headless:
		return {
			"internal_mode": _active_mode,
			"window_mode": _display_mode_to_window_mode(_active_mode),
			"size": _active_window_size,
			"position": NO_POSITION,
		}
	return {
		"internal_mode": _window_mode_to_display_mode(_window.mode),
		"window_mode": _window.mode,
		"size": _window.size,
		"position": _window.position,
		"content_scale_size": _window.content_scale_size,
		"content_scale_mode": _window.content_scale_mode,
		"content_scale_aspect": _window.content_scale_aspect,
		"content_scale_stretch": _window.content_scale_stretch,
		"content_scale_factor": _window.content_scale_factor,
	}


func _restore_window_state(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {"ok": true, "message": ""}
	if _window == null:
		return {"ok": true, "message": ""}
	var position: Vector2i = state.get("position", NO_POSITION) as Vector2i
	var internal_mode: int = int(
		state.get("internal_mode", DisplayOptions.Mode.WINDOWED)
	)
	var result: Dictionary = _set_window_state(
		internal_mode,
		state.get("size", _window.size) as Vector2i,
		position,
		false
	)
	if not _headless:
		_window.content_scale_size = state.get("content_scale_size", DisplayOptions.LOGICAL_SIZE) as Vector2i
		_window.content_scale_mode = int(state.get("content_scale_mode", Window.CONTENT_SCALE_MODE_VIEWPORT))
		_window.content_scale_aspect = int(state.get("content_scale_aspect", Window.CONTENT_SCALE_ASPECT_KEEP))
		_window.content_scale_stretch = int(state.get("content_scale_stretch", Window.CONTENT_SCALE_STRETCH_INTEGER))
		_window.content_scale_factor = float(state.get("content_scale_factor", 1.0))
	return result


func _window_mode_to_display_mode(window_mode: int) -> int:
	if (
		window_mode == Window.MODE_FULLSCREEN
		or window_mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	):
		return DisplayOptions.Mode.FULLSCREEN
	return DisplayOptions.Mode.WINDOWED


func _display_mode_to_window_mode(display_mode: int) -> int:
	return (
		Window.MODE_FULLSCREEN
		if display_mode == DisplayOptions.Mode.FULLSCREEN
		else Window.MODE_WINDOWED
	)


func _set_window_state(
	mode: int,
	size: Vector2i,
	position: Vector2i,
	center: bool
) -> Dictionary:
	if mode != DisplayOptions.Mode.WINDOWED and mode != DisplayOptions.Mode.FULLSCREEN:
		push_warning("DisplaySettings: invalid internal mode %d; using windowed" % mode)
		mode = DisplayOptions.Mode.WINDOWED
	if apply_override.is_valid():
		var overridden: Variant = apply_override.call(mode, size, position, center)
		if typeof(overridden) == TYPE_DICTIONARY:
			return overridden
		return {"ok": true, "message": ""}
	if _headless or _window == null:
		return {"ok": true, "message": ""}
	if mode == DisplayOptions.Mode.FULLSCREEN:
		_window.mode = Window.MODE_FULLSCREEN
		if _window.mode != Window.MODE_FULLSCREEN:
			return {"ok": false, "message": "无法进入全屏模式"}
		return {"ok": true, "message": ""}
	if _window.mode != Window.MODE_WINDOWED:
		_window.mode = Window.MODE_WINDOWED
		if _window.mode != Window.MODE_WINDOWED:
			return {"ok": false, "message": "无法退出全屏模式"}
	_window.size = size
	if center:
		var usable: Rect2i = _usable_rect()
		var target: Vector2i = usable.position + (usable.size - size) / 2
		target.x = maxi(target.x, usable.position.x)
		target.y = maxi(target.y, usable.position.y)
		_window.position = target
	elif position != NO_POSITION:
		_window.position = position
	if _window.size != size:
		return {"ok": false, "message": "窗口尺寸未生效"}
	return {"ok": true, "message": ""}


func _pending_window_is_effective() -> bool:
	if _headless or apply_override.is_valid() or _window == null:
		return true
	if _pending_mode == DisplayOptions.Mode.FULLSCREEN:
		return _window.mode == Window.MODE_FULLSCREEN
	return _window.mode == Window.MODE_WINDOWED and _window.size == _pending_window_size


# --- Config ----------------------------------------------------------------

func _load_startup_state() -> Dictionary:
	var usable: Rect2i = _usable_rect()
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(config_path)
	if error != OK:
		return {
			"mode": DisplayOptions.Mode.WINDOWED,
			"window_size": DisplayOptions.default_window_size(usable, _frame_margin),
			"notice": "",
		}
	var mode_value: Variant = config.get_value("display", "mode", "")
	var width_value: Variant = config.get_value("display", "window_width", 0)
	var height_value: Variant = config.get_value("display", "window_height", 0)
	var state: Dictionary = DisplayOptions.validate_saved_state(
		mode_value, width_value, height_value, usable, _frame_margin
	)
	var notice: String = ""
	if bool(state.get("changed", false)):
		notice = "已修正保存的显示设置：%s" % String(state.get("reason", ""))
		push_warning("DisplaySettings: %s" % notice)
	return {
		"mode": int(state.get("mode", DisplayOptions.Mode.WINDOWED)),
		"window_size": state.get("window_size", DisplayOptions.DEFAULT_WINDOW_SIZE) as Vector2i,
		"notice": notice,
	}


func _save_config(mode: int, window_size: Vector2i) -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "version", CONFIG_VERSION)
	config.set_value("display", "mode", DisplayOptions.mode_to_text(mode))
	config.set_value("display", "window_width", window_size.x)
	config.set_value("display", "window_height", window_size.y)
	var temp_path: String = config_path + ".tmp"
	var error: Error = config.save(temp_path)
	if error != OK:
		push_warning("DisplaySettings: could not write %s (error %d)" % [temp_path, error])
		return false
	var verify: ConfigFile = ConfigFile.new()
	if verify.load(temp_path) != OK:
		_remove_file(temp_path)
		return false
	if int(verify.get_value("display", "version", -1)) != CONFIG_VERSION:
		_remove_file(temp_path)
		return false
	if (
		String(verify.get_value("display", "mode", "")) != DisplayOptions.mode_to_text(mode)
		or int(verify.get_value("display", "window_width", -1)) != window_size.x
		or int(verify.get_value("display", "window_height", -1)) != window_size.y
	):
		_remove_file(temp_path)
		return false
	var global_path: String = ProjectSettings.globalize_path(config_path)
	var global_temp: String = ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(global_path):
		DirAccess.remove_absolute(global_path)
	var rename_error: Error = DirAccess.rename_absolute(global_temp, global_path)
	if rename_error == OK:
		return true
	# Some Windows configurations refuse rename over an existing path.  Falling
	# back to a fresh file still never leaves the previous config half-merged.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(global_temp)
	if bytes.is_empty():
		_remove_file(temp_path)
		return false
	var file: FileAccess = FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		_remove_file(temp_path)
		return false
	file.store_buffer(bytes)
	file.close()
	_remove_file(temp_path)
	return true


func _remove_file(path: String) -> void:
	var global: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)
