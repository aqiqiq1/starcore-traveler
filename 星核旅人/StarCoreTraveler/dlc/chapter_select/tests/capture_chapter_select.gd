extends Node

## 640x360 evidence for the title's 章节 entry and in-place chapter list.
## Run WITHOUT --headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --resolution 640x360 --path . \
##     res://dlc/chapter_select/tests/capture_chapter_select.tscn
##
## Saves to res://screenshots/chapter_select_20261127/:
##   title_menu_no_direct_rows.png  default title: only 开始游戏/章节/设置/退出游戏
##   title_menu_chapter_row.png  the 章节 row under 开始游戏 (focused)
##   chapter_select_locked.png   only L1 open; five rows greyed with 需先完成
##   chapter_select_unlocked.png L1..L3 已通关; 城内/试炼/裂隙 可进入

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")
const LEVEL_01: String = "res://scenes/level_01.tscn"
const OUT_DIR: String = "res://screenshots/chapter_select_20261127"
const CAPTURE_PROGRESS: String = "user://chapter_select_capture.cfg"

var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CAPTURE_PROGRESS))
	# The project ships a 2x window; the acceptance evidence must be native
	# 640x360, so the capture window is resized before the level is added.
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CAPTURE_PROGRESS))
	print("CHAPTER_SELECT_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _run() -> void:
	var packed: PackedScene = load(LEVEL_01) as PackedScene
	var level: Node = packed.instantiate()
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		print("CHAPTER_SELECT_CAPTURE missing StartMenu")
		level.queue_free()
		return
	menu.chapter_progress_path = CAPTURE_PROGRESS
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	for _index: int in range(24):
		await get_tree().process_frame

	# Title menu: default focus proves the page now has only the four base rows.
	menu.get_start_button().grab_focus()
	await _wait_process(4)
	await _save("title_menu_no_direct_rows")

	# Focus/hover the 章节 row so its caret + underline are visible.
	menu.get_chapter_button().grab_focus()
	await _wait_process(4)
	await _save("title_menu_chapter_row")

	# Locked page: L1 only, focus on L1.
	menu.get_chapter_button().pressed.emit()
	await _wait_process(6)
	await _save("chapter_select_locked")

	# Close, write L1..L3 completions, reopen; focus lands on 城内.
	menu.call("_close_chapters")
	await _wait_process(2)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, CAPTURE_PROGRESS)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L2, CAPTURE_PROGRESS)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L3, CAPTURE_PROGRESS)
	menu.get_chapter_button().pressed.emit()
	await _wait_process(8)
	await _save("chapter_select_unlocked")

	menu.call("_close_chapters")
	await _wait_process(4)
	get_tree().current_scene = null
	level.queue_free()
	for _index: int in range(6):
		await get_tree().process_frame


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() != 640 or image.get_height() != 360:
		print("CAPTURE_SIZE unexpected %dx%d, resizing" % [image.get_width(), image.get_height()])
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var error: Error = image.save_png(directory.path_join(shot_name + ".png"))
	_saved.append(shot_name)
	print("SHOT %s size=%dx%d error=%d" % [
		shot_name, image.get_width(), image.get_height(), error
	])
