extends Node

## Scripted GUI captures for the extended display settings.  Run with the GUI
## executable (not --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tests/capture_display_settings.tscn
##
## The viewport is captured as the real 640x360 logical frame, and each windowed
## evidence shot is cropped from the actual desktop image so integer scaling and
## black bars can be inspected.  Display/audio configs are temporary and the
## original Window mode/size/position/content-scale and Master volume are
## restored before quitting.  No old menu screenshots are overwritten.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const CAPTURE_DIR: String = "res://screenshots"
const TEMP_AUDIO_PATH: String = "user://capture_display_audio.cfg"
const TEMP_DISPLAY_PATH: String = "user://capture_display_display.cfg"

var _level: Level01
var _menu: StartMenu
var _lines: Array[String] = []
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_lines.append("Star Core Traveler - display settings GUI captures")
	_lines.append("Godot: %s  display=%s" % [Engine.get_version_info()["string"], DisplayServer.get_name()])
	_lines.append("Desktop: primary=%s usable=%s" % [
		str(DisplayServer.screen_get_size(DisplayServer.get_primary_screen())),
		str(DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())),
	])
	_lines.append("Logical canvas: always 640x360; content scale VIEWPORT/KEEP/INTEGER.")
	_lines.append("Scripted fixed-time frames from the running engine, not a manual playthrough.")
	_lines.append("Display/audio persistence uses temporary user:// files; both are restored/removed.")
	_lines.append("Available windowed candidates on this desktop: 640x360 and 1280x720.")
	_lines.append("Disabled by the 1920x1032 work area: 1920x1080 and 2560x1440.")
	_lines.append("Not measured: a real 1920x1080/2560x1440 window, 2K/4K or other-DPI monitors;")
	_lines.append("           the 2560x1440 candidate is present but is not claimed as tested hardware.")
	_lines.append("Fullscreen is Window.MODE_FULLSCREEN (borderless desktop fullscreen), no physical mode switch.")
	_lines.append("The 1400x900 shot is a temporary diagnostic window, not a selectable resolution.")
	_lines.append("No audio assets exist; volume persistence is not an audible acceptance.")
	_lines.append("")

	_level = LEVEL_SCENE.instantiate() as Level01
	var temp_menu: StartMenu = _level.get_node("StartMenu") as StartMenu
	temp_menu.audio_settings_path = TEMP_AUDIO_PATH
	temp_menu.display_settings_path = TEMP_DISPLAY_PATH
	add_child(_level)
	await _physics(6)
	_menu = _level.get_menu()

	await _click_logical(_menu.get_settings_button().get_global_rect().get_center())
	await _settle(4)
	_check_state("expanded settings at 1280x720")
	await _capture_logical(
		"display_settings_05_panel_logical.png",
		"expanded settings panel with volume, window/fullscreen, resolution list and apply/返回"
	)
	await _capture_window(
		"display_settings_01_panel_1280.png",
		"real 1280x720 window: extended settings page at exact 2x, no popup clipping"
	)

	await _click_logical(_menu.get_resolution_button(Vector2i(640, 360)).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(4)
	_check_state("pending 640x360 confirmation")
	await _capture_logical(
		"display_settings_06_pending_logical.png",
		"pending confirmation overlay with visible 10 s countdown after applying 640x360"
	)
	await _capture_window(
		"display_settings_02_pending_640.png",
		"real 640x360 window during pending confirmation; countdown and 保留/恢复 buttons"
	)
	await _click_logical(_menu.get_pending_cancel_button().get_global_rect().get_center())
	await _settle(4)
	_check_state("640x360 pending cancelled back to 1280x720")

	await _click_logical(_menu.get_display_mode_button(true).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(5)
	_check_state("pending desktop fullscreen")
	await _capture_window(
		"display_settings_03_pending_fullscreen.png",
		"real borderless desktop fullscreen 1920x1080 during pending; logical canvas remains 640x360 at exact 3x"
	)
	await _click_logical(_menu.get_pending_cancel_button().get_global_rect().get_center())
	await _settle(4)
	_check_state("fullscreen pending cancelled back to windowed")

	# Deliberate non-16:9 window used only to make the integer-scale black bars
	# inspectable.  It is not offered as a selectable resolution.
	get_window().size = Vector2i(1400, 900)
	var screen_index: int = DisplayServer.window_get_current_screen(get_window().get_window_id())
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	get_window().position = usable.position + (usable.size - Vector2i(1400, 900)) / 2
	await _settle(5)
	_check_state("temporary 1400x900 non-16:9 window")
	await _capture_window(
		"display_settings_04_bars_1400x900.png",
		"temporary 1400x900 window: integer 2x 1280x720 content inside 60/90 px black bars"
	)

	_write_manifest()
	await _free_level()
	_remove_temp_audio()
	_remove_temp_display()
	_restore_window_state(_original_window_state)
	AudioServer.set_bus_mute(0, _original_master_mute)
	AudioServer.set_bus_volume_db(0, _original_master_db)
	print("DISPLAY_CAPTURE_DONE")
	get_tree().quit(0)


func _check_state(note: String) -> void:
	var window: Window = get_window()
	var info: String = "window mode=%d size=%s pos=%s viewport=%s content_scale=%s stretch=%d aspect=%d pending=%s" % [
		window.mode, str(window.size), str(window.position),
		str(get_viewport().get_visible_rect().size), str(window.content_scale_size),
		window.content_scale_stretch, window.content_scale_aspect,
		str(_menu.is_display_pending()),
	]
	print("STATE %s | %s" % [note, info])
	_lines.append(note)
	_lines.append("  " + info)


func _capture_logical(file_name: String, note: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() != 640 or image.get_height() != 360:
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var path: String = ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("capture failed for %s (%d)" % [file_name, error])
	else:
		print("CAPTURED %s logical=%s | %s" % [file_name, str(image.get_size()), note])
	_lines.append("%s | 640x360 logical | %s" % [file_name, note])


func _capture_window(file_name: String, note: String) -> void:
	await RenderingServer.frame_post_draw
	if not DisplayServer.has_method("screen_get_image"):
		push_warning("screen_get_image unavailable; skipping %s" % file_name)
		_lines.append("%s | SKIPPED: screen_get_image unavailable | %s" % [file_name, note])
		return
	var window: Window = get_window()
	var screen: int = DisplayServer.window_get_current_screen(window.get_window_id())
	var screen_position: Vector2i = DisplayServer.screen_get_position(screen)
	var local: Vector2i = window.position - screen_position
	var rect: Rect2i = Rect2i(local, window.size)
	var screen_image: Image = DisplayServer.call("screen_get_image", screen) as Image
	if screen_image == null:
		push_warning("screen_get_image returned null; skipping %s" % file_name)
		return
	var clipped: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, screen_image.get_size()))
	if clipped != rect:
		push_error("window crop %s outside screen image %s" % [str(rect), str(screen_image.get_size())])
		return
	var image: Image = screen_image.get_region(rect)
	var path: String = ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("capture failed for %s (%d)" % [file_name, error])
	else:
		print("CAPTURED %s window=%s | %s" % [file_name, str(image.get_size()), note])
	_lines.append("%s | %dx%d real window crop | %s" % [file_name, image.get_width(), image.get_height(), note])


func _click_logical(logical_position: Vector2) -> void:
	DisplayServer.window_move_to_foreground(get_window().get_window_id())
	get_window().grab_focus()
	await get_tree().process_frame
	await _mouse_button_logical(logical_position, true)
	await get_tree().process_frame
	await _mouse_button_logical(logical_position, false)


func _mouse_button_logical(logical_position: Vector2, pressed: bool) -> void:
	var window_size: Vector2i = get_window().size
	var content: Rect2i = DisplayOptions.content_rect(window_size)
	var scale: float = float(content.size.x) / 640.0
	var physical: Vector2 = Vector2(content.position) + logical_position * scale
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = physical
	event.global_position = physical
	get_viewport().push_input(event, false)


func _settle(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _free_level() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null
	_menu = null


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(
		CAPTURE_DIR + "/MANIFEST_DISPLAY_SETTINGS.txt", FileAccess.WRITE
	)
	if file == null:
		push_error("could not write display settings manifest")
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()


func _capture_window_state() -> Dictionary:
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


func _remove_temp_audio() -> void:
	var global: String = ProjectSettings.globalize_path(TEMP_AUDIO_PATH)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)


func _remove_temp_display() -> void:
	var global: String = ProjectSettings.globalize_path(TEMP_DISPLAY_PATH)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)
