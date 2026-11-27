extends Node

## Chapter-page entry test for 星核试炼场 (DLC1).
##
## The title page has no DLC direct rows: 试炼场 is reachable only through the
## 章节 page, and only while chapter_progress unlocks its row.
##   locked (no L1 completion): row greyed, unfocusable, unclickable;
##   unlocked (L1 complete):    row enabled, Enter loads the trial scene.
##
##   ... --headless --path . res://dlc/trial_chambers/tests/title_test.tscn

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")

const LEVEL_01: String = "res://scenes/level_01.tscn"
const TRIAL: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const PROGRESS: String = "user://trial_title_test.cfg"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_remove_progress()
	await _run()
	await _cleanup()
	print("TRIAL_TITLE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: " + label + ("" if detail.is_empty() else " [" + detail + "]"))
		return
	_failures.append(label + ("" if detail.is_empty() else " [" + detail + "]"))
	print("FAIL: " + label + ("" if detail.is_empty() else " [" + detail + "]"))


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _push_click(position: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.global_position = position
	get_viewport().push_input(down, true)
	await _wait_process(1)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.global_position = position
	get_viewport().push_input(up, true)


func _remove_progress() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))


func _load_level_01() -> Node:
	var packed: PackedScene = load(LEVEL_01) as PackedScene
	if packed == null:
		return null
	var level: Node = packed.instantiate()
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		level.queue_free()
		return null
	menu.chapter_progress_path = PROGRESS
	level.set("enable_start_menu", true)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(5)
	await _wait_physics(4)
	return level


func _open_chapters(menu: StartMenu) -> void:
	menu.get_chapter_button().pressed.emit()
	await _wait_process(4)


func _wait_for_scene(path: String, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		var current: Node = get_tree().current_scene
		if current != null and current.scene_file_path == path:
			return true
		await get_tree().process_frame
	return false


func _current_path() -> String:
	var current: Node = get_tree().current_scene
	return current.scene_file_path if current != null else "null"


func _drop_current_scene() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
		await _wait_process(4)


func _check_title_rows(menu: StartMenu) -> void:
	_check(menu.find_child("TrialButton", true, false) == null,
		"title has no 试炼场 direct row")
	_check(menu.find_child("RiftButton", true, false) == null,
		"title has no 裂隙工坊 direct row")
	_check(menu.find_child("LoomButton", true, false) == null,
		"title has no 星核织机 direct row")

	var start_button: Button = menu.get_start_button()
	var chapter_button: Button = menu.get_chapter_button()
	var settings_button: Button = menu.get_settings_button()
	var quit_button: Button = menu.get_quit_button()
	_check(start_button.get_node(start_button.focus_next) == chapter_button,
		"Tab from 开始游戏 reaches 章节")
	_check(chapter_button.get_node(chapter_button.focus_next) == settings_button,
		"Tab from 章节 reaches 设置")
	_check(settings_button.get_node(settings_button.focus_next) == quit_button,
		"Tab from 设置 reaches 退出游戏")
	_check(quit_button.get_node(quit_button.focus_next) == start_button,
		"Tab from 退出游戏 wraps to 开始游戏")
	_check(start_button.focus_neighbor_bottom != NodePath()
		and start_button.get_node(start_button.focus_neighbor_bottom) == chapter_button,
		"Down from 开始游戏 reaches 章节")
	_check(quit_button.focus_neighbor_bottom != NodePath()
		and quit_button.get_node(quit_button.focus_neighbor_bottom) == start_button,
		"Down from 退出游戏 wraps to 开始游戏")

	# Real Tab key: the same four-row ring must drive actual focus traversal.
	start_button.grab_focus()
	await _wait_process(2)
	var expected: Array[Control] = [chapter_button, settings_button, quit_button, start_button]
	for index: int in range(expected.size()):
		_push_key(KEY_TAB, true)
		await _wait_physics(1)
		_push_key(KEY_TAB, false)
		await _wait_process(2)
		_check(get_viewport().gui_get_focus_owner() == expected[index],
			"real Tab step %d follows the title ring" % (index + 1))


func _cleanup() -> void:
	Input.action_release(&"move_right")
	await _drop_current_scene()
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	_remove_progress()
	await _wait_process(16)


func _run() -> void:
	await _wait_process(2)
	_check(ResourceLoader.exists(TRIAL), "trial scene file exists on disk")
	_check(CHAPTER_PROGRESS.is_available(CHAPTER_PROGRESS.ID_TRIAL),
		"chapter_progress reports the trial scene")

	# --- locked page ------------------------------------------------------
	_remove_progress()
	var level: Node = await _load_level_01()
	_check(level != null, "level_01 loads for the locked chapter-page check")
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	_check(menu != null and menu.is_menu_open(), "title menu is open")
	if menu == null:
		return
	await _check_title_rows(menu)

	await _open_chapters(menu)
	_check(menu.is_chapters_open(), "章节 page opens")
	var locked_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_TRIAL)
	_check(locked_row != null, "章节 page has the trial row")
	if locked_row != null:
		_check(locked_row.disabled, "locked trial row is disabled")
		_check(locked_row.focus_mode == Control.FOCUS_NONE,
			"locked trial row cannot take focus")
		_check(locked_row.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"locked trial row cannot be clicked")
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_TRIAL) == "需先完成 断桥庭院",
		"locked trial row shows its prerequisite",
		menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_TRIAL))
	menu.call("_close_chapters")
	await _wait_process(2)
	await _drop_current_scene()

	# --- unlocked page ----------------------------------------------------
	_check(CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, PROGRESS) == OK,
		"L1 completion writes the test progress file")
	var level2: Node = await _load_level_01()
	_check(level2 != null, "level_01 loads for the unlocked chapter-page check")
	if level2 == null:
		return
	var menu2: StartMenu = level2.get_node_or_null("StartMenu") as StartMenu
	if menu2 == null:
		return
	await _open_chapters(menu2)
	var trial_row: PixelMenuButton = menu2.get_chapter_row(CHAPTER_PROGRESS.ID_TRIAL)
	_check(trial_row != null and not trial_row.disabled,
		"L1 complete unlocks the trial row")
	if trial_row == null:
		return
	_check(trial_row.focus_mode == Control.FOCUS_ALL,
		"unlocked trial row is keyboard focusable")
	_check(menu2.get_chapter_status_text(CHAPTER_PROGRESS.ID_TRIAL) == "可进入",
		"unlocked trial row is enterable")
	trial_row.grab_focus()
	await _wait_process(2)
	_check(trial_row.has_focus(), "trial row takes keyboard focus")
	_push_key(KEY_ENTER, true)
	await _wait_physics(1)
	_push_key(KEY_ENTER, false)
	var entered: bool = await _wait_for_scene(TRIAL, 360)
	_check(entered, "Enter on the trial chapter row loads the trial scene",
		_current_path())
	await _drop_current_scene()

	# --- original title rows still work ----------------------------------
	var level3: Node = await _load_level_01()
	var menu3: StartMenu = level3.get_node_or_null("StartMenu") as StartMenu
	if menu3 != null:
		var start_button: Button = menu3.get_start_button()
		start_button.grab_focus()
		await _wait_process(2)
		_push_key(KEY_ENTER, true)
		await _wait_physics(1)
		_push_key(KEY_ENTER, false)
		await _wait_process(4)
		_check(menu3.get_start_request_count() == 1,
			"existing 开始游戏 row still triggers the opening")
		_check(menu3.get_phase_name() != "menu",
			"start no longer leaves the menu idle", menu3.get_phase_name())
	await _drop_current_scene()

	var level4: Node = await _load_level_01()
	var menu4: StartMenu = level4.get_node_or_null("StartMenu") as StartMenu
	if menu4 != null:
		var settings_button: Button = menu4.get_settings_button()
		await _push_click(settings_button.get_global_rect().get_center())
		await _wait_process(4)
		_check(menu4.is_settings_open(), "existing 设置 row still opens settings")
		_push_key(KEY_ESCAPE, true)
		await _wait_physics(1)
		_push_key(KEY_ESCAPE, false)
		await _wait_process(4)
		_check(not menu4.is_settings_open(), "Esc still closes settings")
	await _drop_current_scene()
