extends Node

## 2x-window evidence: renders the real L1 pause page at the project's default
## 1280x720 window (640x360 viewport, 2x) and saves BOTH the native viewport and
## the OS-level screen so the blit can be inspected.  Run windowed, not headless.
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 620,120 \
##     res://dlc/font_clarity_20261128/tests/capture_window2x.tscn
##
## The screen image is the full monitor; the crop to the window is done outside
## Godot with the printed position/size.

const L1: String = "res://scenes/level_01.tscn"
const OUT_DIR: String = "res://screenshots/font_clarity_20261128"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var packed: PackedScene = load(L1) as PackedScene
	var level: Node = packed.instantiate()
	level.set("enable_start_menu", false)
	level.set("show_intro_cinematic", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await get_tree().process_frame
	level.call("_finish_intro")
	await get_tree().create_timer(0.5, true).timeout
	level.call("get_pause_menu").call("open_pause")
	await get_tree().create_timer(0.6, true).timeout
	var window: Window = get_window()
	print("WINDOW2X window=%s viewport=%s scale_factor=%.3f screen_scale=%.3f" % [
		str(window.size), str(window.get_visible_rect().size),
		window.content_scale_factor, DisplayServer.screen_get_scale()
	])
	await RenderingServer.frame_post_draw
	var native: Image = get_viewport().get_texture().get_image()
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	native.save_png(directory.path_join("20_pause_l1_640.png"))
	print("WINDOW2X native=%s" % str(native.get_size()))
	var screen: Image = DisplayServer.screen_get_image()
	if screen != null and not screen.is_empty():
		screen.save_png(directory.path_join("_probe_pause_window2x_screen.png"))
		var position: Vector2i = DisplayServer.window_get_position()
		var window_size: Vector2i = window.size
		print("WINDOW2X screen=%s pos=%s winsize=%s" % [
			str(screen.get_size()), str(position), str(window_size)
		])
		if position.x >= 0 and position.y >= 0 \
				and position.x + window_size.x <= screen.get_width() \
				and position.y + window_size.y <= screen.get_height():
			var client: Image = screen.get_region(
				Rect2i(position, window_size)
			)
			client.save_png(directory.path_join("_probe_pause_window2x_client.png"))
			print("WINDOW2X client=%s" % str(client.get_size()))
	get_tree().current_scene = null
	level.queue_free()
	await get_tree().create_timer(12.0, true).timeout
	get_tree().quit(0)
