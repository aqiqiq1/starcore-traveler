extends Node

## Chapter-select acceptance test.
##
## Covers the six-boolean progress file (missing / malformed / partial), the
## derived unlock rules, the title's 章节 page (locked rows unfocusable and
## unclickable, ↑↓ ring skips locks), 开始游戏's first-unfinished target, one
## real unlocked entry (星核织机), and the real L1 completion write point.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/chapter_select/tests/chapter_select_test.tscn

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")

const LEVEL_01: String = "res://scenes/level_01.tscn"
const LEVEL_02_PATH: String = "res://scenes/level_02.tscn"
const LEVEL_03_PATH: String = "res://scenes/level_03.tscn"
const LOOM_PATH: String = "res://dlc/star_loom/star_loom.tscn"
const TRIAL_PATH: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT_PATH: String = "res://dlc/rift_workshop/rift_workshop.tscn"

const P_MISSING: String = "user://chapter_select_test_missing.cfg"
const P_ONE: String = "user://chapter_select_test_one.cfg"
const P_FLOW: String = "user://chapter_select_test_flow.cfg"
const P_UNLOCKED: String = "user://chapter_select_test_unlocked.cfg"
const P_CORRUPT: String = "user://chapter_select_test_corrupt.cfg"
const P_COMPLETE: String = "user://chapter_select_test_complete.cfg"
const P_L3: String = "user://chapter_select_test_l3.cfg"
const P_CHEAT: String = "user://chapter_select_test_cheat.cfg"
const P_LEGACY: String = "user://chapter_select_test_legacy.cfg"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _wait_process(2)
	_clear_paths()
	_test_default_file()
	_test_legacy_file()
	_test_unlock_chain()
	_test_corrupt_file()
	await _test_locked_page()
	await _test_locked_focus_skip()
	await _test_start_route_to_l2()
	await _test_unlocked_page_and_entry()
	await _test_title_cheat_unlock()
	await _test_l1_completion_hook()
	await _test_l3_completion_hook()
	_clear_paths()
	print("CHAPTER_SELECT_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_physics(1)
	_push_key(code, false)
	await _wait_process(2)


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


func _clear_paths() -> void:
	for path: String in [
		P_MISSING, P_ONE, P_FLOW, P_UNLOCKED, P_CORRUPT, P_COMPLETE, P_L3, P_CHEAT,
		P_LEGACY,
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _assert_defaults(completed: Dictionary, context: String) -> void:
	_check(not CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L1, completed),
		context + ": L1 starts incomplete")
	_check(CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_L1, completed),
		context + ": L1 is always unlocked")
	for id: String in [
		CHAPTER_PROGRESS.ID_L2, CHAPTER_PROGRESS.ID_L3, CHAPTER_PROGRESS.ID_LOOM,
		CHAPTER_PROGRESS.ID_TRIAL, CHAPTER_PROGRESS.ID_RIFT,
	]:
		_check(not CHAPTER_PROGRESS.is_unlocked(id, completed),
			context + ": %s is locked by default" % id)
	_check(CHAPTER_PROGRESS.first_uncompleted(completed) == CHAPTER_PROGRESS.ID_L1,
		context + ": first unfinished is L1")
	_check(CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_L1, completed),
		context + ": L1 is a visible mainline row")
	_check(not CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_TRIAL, completed),
		context + ": trial starts undiscovered")
	_check(not CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_RIFT, completed),
		context + ": rift starts undiscovered")
	_check(not CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_TRIAL, completed),
		context + ": undiscovered trial row is hidden")
	_check(not CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_RIFT, completed),
		context + ": undiscovered rift row is hidden")


func _test_default_file() -> void:
	var completed: Dictionary = CHAPTER_PROGRESS.load_completed(P_MISSING)
	_assert_defaults(completed, "missing file")
	_check(FileAccess.file_exists(P_MISSING) == false,
		"missing file is not created by reading")


## Files written before the two discovery flags existed must still load.  Their
## six completion booleans are read normally and discovery defaults to false.
func _test_legacy_file() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("chapters", "l1", true)
	config.set_value("chapters", "l2", true)
	config.set_value("chapters", "l3", false)
	config.save(P_LEGACY)
	var completed: Dictionary = CHAPTER_PROGRESS.load_completed(P_LEGACY)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L1, completed),
		"legacy file keeps l1")
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L2, completed),
		"legacy file keeps l2")
	_check(not CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L3, completed),
		"legacy file keeps l3 false")
	_check(not CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_TRIAL, completed),
		"legacy file has no trial discovery")
	_check(not CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_RIFT, completed),
		"legacy file has no rift discovery")


func _test_unlock_chain() -> void:
	_check(CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, P_FLOW) == OK,
		"L1 completion writes the progress file")
	var completed: Dictionary = CHAPTER_PROGRESS.load_completed(P_FLOW)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L1, completed),
		"L1 completion persists")
	_check(CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_L2, completed),
		"L1 opens L2")
	_check(CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_TRIAL, completed),
		"L1 opens the trial")
	_check(not CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_L3, completed),
		"L1 does not open L3")
	_check(not CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_LOOM, completed),
		"L1 does not open 城内")
	_check(not CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_RIFT, completed),
		"L1 does not open 裂隙")
	_check(CHAPTER_PROGRESS.first_uncompleted(completed) == CHAPTER_PROGRESS.ID_L2,
		"L1 done: first unfinished is L2")
	_check(CHAPTER_PROGRESS.required_title(CHAPTER_PROGRESS.ID_L2) == "断桥庭院",
		"L2 names 断桥庭院 as its prerequisite")

	# Discovery is written by the entrance, not by completion.
	_check(CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_TRIAL, P_FLOW) == OK,
		"entering the trial writes its discovery flag")
	completed = CHAPTER_PROGRESS.load_completed(P_FLOW)
	_check(CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_TRIAL, completed),
		"trial discovery persists")
	_check(not CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_TRIAL, completed),
		"discovery alone does not mark the trial completed")
	_check(CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_TRIAL, completed),
		"discovered trial row becomes visible")
	_check(not CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_RIFT, completed),
		"undiscovered rift row stays hidden")
	_check(CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_L1, P_FLOW) \
			== ERR_INVALID_PARAMETER,
		"mainline chapters have no discovery flag")

	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L2, P_FLOW)
	completed = CHAPTER_PROGRESS.load_completed(P_FLOW)
	_check(CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_L3, completed),
		"L2 opens L3")
	_check(CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_RIFT, completed),
		"L2 opens 裂隙")
	_check(not CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_LOOM, completed),
		"L2 does not open 城内")
	_check(CHAPTER_PROGRESS.first_uncompleted(completed) == CHAPTER_PROGRESS.ID_L3,
		"L2 done: first unfinished is L3")
	_check(CHAPTER_PROGRESS.required_title(CHAPTER_PROGRESS.ID_LOOM) == "断桥外郭",
		"城内 names 断桥外郭 as its prerequisite")

	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L3, P_FLOW)
	completed = CHAPTER_PROGRESS.load_completed(P_FLOW)
	_check(CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_LOOM, completed),
		"L3 opens 城内")
	_check(CHAPTER_PROGRESS.first_uncompleted(completed) == CHAPTER_PROGRESS.ID_LOOM,
		"L3 done: first unfinished is 城内")
	_check(CHAPTER_PROGRESS.first_uncompleted(completed, false) != "",
		"first_uncompleted can include unavailable scenes")


func _test_corrupt_file() -> void:
	_write_raw(P_CORRUPT, "not a config file\n[chapters\nbroken")
	var completed: Dictionary = CHAPTER_PROGRESS.load_completed(P_CORRUPT)
	_assert_defaults(completed, "corrupt file")
	_check(CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, P_CORRUPT) == OK,
		"corrupt file can be rewritten")
	completed = CHAPTER_PROGRESS.load_completed(P_CORRUPT)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L1, completed),
		"rewritten corrupt file keeps the new completion")


func _load_level_with_menu(progress_path: String) -> Node:
	var packed: PackedScene = load(LEVEL_01) as PackedScene
	if packed == null:
		return null
	var level: Node = packed.instantiate()
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		level.queue_free()
		return null
	menu.chapter_progress_path = progress_path
	level.set("enable_start_menu", true)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(5)
	await _wait_physics(3)
	return level


func _drop_current_scene() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
		await _wait_process(4)


func _open_chapters(menu: StartMenu, by_mouse: bool = false) -> void:
	if by_mouse:
		await _push_click(menu.get_chapter_button().get_global_rect().get_center())
	else:
		menu.get_chapter_button().pressed.emit()
	await _wait_process(4)


func _test_locked_page() -> void:
	var level: Node = await _load_level_with_menu(P_MISSING)
	_check(level != null, "L1 loads with the missing progress path")
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	_check(menu != null and menu.is_menu_open(), "title menu is open")
	if menu == null:
		return
	_check(menu.get_start_target_chapter_id() == CHAPTER_PROGRESS.ID_L1,
		"开始游戏 targets L1 when the file is missing")

	# Keyboard route: Down from 开始游戏 reaches 章节, Enter opens the list.
	var start_button: Button = menu.get_start_button()
	start_button.grab_focus()
	await _wait_process(2)
	await _tap_key(KEY_DOWN)
	_check(get_viewport().gui_get_focus_owner() == menu.get_chapter_button(),
		"Down from 开始游戏 reaches 章节", _focus_name(menu))
	await _tap_key(KEY_ENTER)
	await _wait_process(3)
	_check(menu.is_chapters_open(), "Enter on 章节 opens the list")
	await _tap_key(KEY_ESCAPE)
	_check(not menu.is_chapters_open(), "Esc closes the keyboard-opened list")

	# Mouse route into the same page.
	await _open_chapters(menu, true)
	_check(menu.is_chapters_open(), "鼠标点击 章节 opens the in-place list")
	_check(menu.get_chapters_layer() != null and menu.get_chapters_layer().visible,
		"the list layer is visible")
	_check(menu.get_chapters_progress_text() == "已完成 0 / 4",
		"locked page reports 0 / 4 visible mainline chapters",
		menu.get_chapters_progress_text())

	var l1: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_L1)
	_check(l1 != null and l1.focus_mode == Control.FOCUS_ALL,
		"L1 row is focusable")
	_check(l1 != null and l1.mouse_filter == Control.MOUSE_FILTER_STOP,
		"L1 row accepts the mouse")
	for id: String in [
		CHAPTER_PROGRESS.ID_L2, CHAPTER_PROGRESS.ID_L3, CHAPTER_PROGRESS.ID_LOOM,
	]:
		var row: PixelMenuButton = menu.get_chapter_row(id)
		_check(row != null and row.visible,
			"%s mainline row is always on the page" % id)
		_check(row != null and row.focus_mode == Control.FOCUS_NONE,
			"%s row cannot take focus" % id)
		_check(row != null and row.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s row cannot be clicked" % id)
	for id: String in [CHAPTER_PROGRESS.ID_TRIAL, CHAPTER_PROGRESS.ID_RIFT]:
		var side_row: PixelMenuButton = menu.get_chapter_row(id)
		_check(side_row != null and not side_row.visible,
			"%s undiscovered side row is hidden" % id)
		_check(side_row != null and side_row.focus_mode == Control.FOCUS_NONE,
			"%s hidden side row cannot take focus" % id)
		_check(side_row != null and side_row.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s hidden side row cannot be clicked" % id)
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_L2) == "需先完成 断桥庭院",
		"L2 shows its prerequisite",
		menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_L2))
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_L3) == "需先完成 沉寂回廊",
		"L3 shows its prerequisite",
		menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_L3))
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_LOOM) == "需先完成 断桥外郭",
		"城内 shows its prerequisite",
		menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_LOOM))
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_TRIAL) == "需先完成 断桥庭院",
		"trial shows its prerequisite",
		menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_TRIAL))
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_RIFT) == "需先完成 沉寂回廊",
		"rift shows its prerequisite",
		menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_RIFT))

	# A real click on a locked row must not change scene or close the page.
	var locked_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_L2)
	await _push_click(locked_row.get_global_rect().get_center())
	await _wait_process(4)
	_check(menu.is_chapters_open(), "locked click leaves the page open")
	_check(get_tree().current_scene == level, "locked click loads no scene")

	await _tap_key(KEY_ESCAPE)
	_check(not menu.is_chapters_open(), "Esc returns from the list")
	_check(menu.is_menu_open(), "Esc leaves the title menu usable")
	await _drop_current_scene()


func _test_locked_focus_skip() -> void:
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, P_ONE)
	var level: Node = await _load_level_with_menu(P_ONE)
	_check(level != null, "L1 loads for the focus-skip check")
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		await _drop_current_scene()
		return
	_check(menu.get_start_target_chapter_id() == CHAPTER_PROGRESS.ID_L2,
		"L1 done: 开始游戏 targets L2", menu.get_start_target_chapter_id())
	# Only L1/L2 are unlocked and visible; the undiscovered trial row and the
	# locked L3/城内/裂隙 rows must all be skipped by the ring.
	await _open_chapters(menu)
	await _wait_process(2)
	_check(_focused_row(menu, CHAPTER_PROGRESS.ID_L2),
		"entry focus lands on L2, the first unfinished unlocked row",
		_focus_name(menu))
	await _tap_key(KEY_DOWN)
	_check(_focused_row(menu, CHAPTER_PROGRESS.ID_L1),
		"Down wraps over hidden/locked rows to L1", _focus_name(menu))
	await _tap_key(KEY_DOWN)
	_check(_focused_row(menu, CHAPTER_PROGRESS.ID_L2),
		"Down continues to L2", _focus_name(menu))
	await _tap_key(KEY_UP)
	_check(_focused_row(menu, CHAPTER_PROGRESS.ID_L1),
		"Up wraps back to L1", _focus_name(menu))

	# Discovery reveals the side row; it is then a real mouse/keyboard target.
	menu.call("_close_chapters")
	await _wait_process(2)
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_TRIAL, P_ONE)
	await _open_chapters(menu)
	await _wait_process(3)
	var trial_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_TRIAL)
	_check(trial_row != null and trial_row.visible and not trial_row.disabled,
		"discovered trial row appears as an enterable side row")
	await _push_click(trial_row.get_global_rect().get_center())
	var clicked_entry: bool = await _wait_for_scene(TRIAL_PATH, 360)
	_check(clicked_entry, "mouse click on 试炼场 loads the trial scene", _current_path())
	await _drop_current_scene()


func _test_start_route_to_l2() -> void:
	var level: Node = await _load_level_with_menu(P_ONE)
	_check(level != null, "L1 loads for the 开始游戏 route check")
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		await _drop_current_scene()
		return
	_check(menu.get_start_target_chapter_id() == CHAPTER_PROGRESS.ID_L2,
		"开始游戏 sees L2 as its target", menu.get_start_target_chapter_id())
	var start_button: Button = menu.get_start_button()
	start_button.grab_focus()
	await _wait_process(2)
	await _tap_key(KEY_ENTER)
	_check(menu.get_start_request_count() == 1,
		"开始游戏 accepted exactly one request")
	var loaded: bool = await _wait_for_scene(LEVEL_02_PATH, 420)
	_check(loaded, "开始游戏 with L1 complete really loads L2", _current_path())
	await _drop_current_scene()


func _test_unlocked_page_and_entry() -> void:
	_clear_paths()
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, P_UNLOCKED)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L2, P_UNLOCKED)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L3, P_UNLOCKED)
	var level: Node = await _load_level_with_menu(P_UNLOCKED)
	_check(level != null, "L1 loads with L1..L3 completed")
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		await _drop_current_scene()
		return
	_check(menu.get_start_target_chapter_id() == CHAPTER_PROGRESS.ID_LOOM,
		"开始游戏 targets 城内 after L3", menu.get_start_target_chapter_id())
	_check(menu.get_start_target_path() == LOOM_PATH,
		"开始游戏 path is the loom scene", menu.get_start_target_path())

	await _open_chapters(menu)
	await _wait_process(2)
	_check(menu.get_chapters_progress_text() == "已完成 3 / 4",
		"unlocked page reports 3 / 4 before discovery",
		menu.get_chapters_progress_text())
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_L1) == "已通关",
		"L1 row marks 已通关")
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_LOOM) == "可进入",
		"城内 row is enterable")
	# L1..L3 completion alone must not reveal the side chapters; only entering
	# their in-level gates does.
	for id: String in [CHAPTER_PROGRESS.ID_TRIAL, CHAPTER_PROGRESS.ID_RIFT]:
		var hidden_row: PixelMenuButton = menu.get_chapter_row(id)
		_check(hidden_row != null and not hidden_row.visible,
			"%s row stays hidden until discovered" % id)
		_check(hidden_row != null and hidden_row.focus_mode == Control.FOCUS_NONE,
			"%s hidden row stays out of the focus ring" % id)

	menu.call("_close_chapters")
	await _wait_process(2)
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_TRIAL, P_UNLOCKED)
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_RIFT, P_UNLOCKED)
	await _open_chapters(menu)
	await _wait_process(3)
	_check(menu.get_chapters_progress_text() == "已完成 3 / 6",
		"discovery does not inflate the completed count",
		menu.get_chapters_progress_text())
	for id: String in [CHAPTER_PROGRESS.ID_TRIAL, CHAPTER_PROGRESS.ID_RIFT]:
		var side_row: PixelMenuButton = menu.get_chapter_row(id)
		_check(side_row != null and side_row.visible,
			"%s discovered row is visible" % id)
		_check(side_row != null and not side_row.disabled,
			"%s discovered row is enterable" % id)
		_check(menu.get_chapter_status_text(id) == "可进入",
			"%s discovered row is marked 可进入" % id,
			menu.get_chapter_status_text(id))

	# All five non-L1 paths are real, distinct files.
	var expected_paths: Dictionary = {
		CHAPTER_PROGRESS.ID_L1: LEVEL_01,
		CHAPTER_PROGRESS.ID_L2: LEVEL_02_PATH,
		CHAPTER_PROGRESS.ID_L3: LEVEL_03_PATH,
		CHAPTER_PROGRESS.ID_LOOM: LOOM_PATH,
		CHAPTER_PROGRESS.ID_TRIAL: TRIAL_PATH,
		CHAPTER_PROGRESS.ID_RIFT: RIFT_PATH,
	}
	for id: String in expected_paths:
		_check(menu.get_chapter_target_path(id) == String(expected_paths[id]),
			"row %s maps to its scene" % id, menu.get_chapter_target_path(id))

	# Complete everything: 开始游戏 falls back to L1, not an empty target.
	for id: String in CHAPTER_PROGRESS.chapter_ids():
		CHAPTER_PROGRESS.mark_completed(id, P_UNLOCKED)
	_check(menu.get_start_target_chapter_id() == CHAPTER_PROGRESS.ID_L1,
		"all complete: 开始游戏 falls back to L1")
	await _wait_process(1)

	# Enter the real loom scene from the chapter page.
	var loom_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_LOOM)
	loom_row.grab_focus()
	await _wait_process(2)
	await _tap_key(KEY_ENTER)
	var entered: bool = await _wait_for_scene(LOOM_PATH, 360)
	_check(entered, "Enter on 城内 loads the loom scene",
		_current_path())
	await _drop_current_scene()


## Title-only hidden sequence: k s k b l fills every completion flag.  A wrong
## character clears the buffer, and the chapter page blocks the sequence.
func _test_title_cheat_unlock() -> void:
	print("=== TITLE CHEAT UNLOCK ===")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P_CHEAT))
	var level: Node = await _load_level_with_menu(P_CHEAT)
	_check(level != null, "L1 loads for the title cheat")
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		await _drop_current_scene()
		return
	menu.get_start_button().grab_focus()
	await _wait_process(2)

	# Wrong sequence: k s x b l.  The x clears the buffer; nothing unlocks.
	for key: int in [KEY_K, KEY_S, KEY_X, KEY_B, KEY_L]:
		await _tap_key(key)
	await _wait_process(2)
	var after_wrong: Dictionary = CHAPTER_PROGRESS.load_completed(P_CHEAT)
	for id: String in CHAPTER_PROGRESS.chapter_ids():
		_check(not CHAPTER_PROGRESS.is_completed(id, after_wrong),
			"wrong title sequence leaves %s incomplete" % id)
	_check(menu.get_cheat_unlock_count() == 0,
		"wrong title sequence does not fire the unlock")
	_check(not menu.is_cheat_feedback_visible(),
		"wrong title sequence shows no feedback")

	# Correct sequence: k s k b l.
	for key: int in [KEY_K, KEY_S, KEY_K, KEY_B, KEY_L]:
		await _tap_key(key)
	await _wait_process(2)
	var after_cheat: Dictionary = CHAPTER_PROGRESS.load_completed(P_CHEAT)
	for id: String in CHAPTER_PROGRESS.chapter_ids():
		_check(CHAPTER_PROGRESS.is_completed(id, after_cheat),
			"kskbl completes %s" % id)
		_check(CHAPTER_PROGRESS.is_unlocked(id, after_cheat),
			"kskbl unlocks %s" % id)
		_check(CHAPTER_PROGRESS.is_visible(id, after_cheat),
			"kskbl reveals %s" % id)
	_check(menu.get_cheat_unlock_count() == 1,
		"kskbl fires exactly once", str(menu.get_cheat_unlock_count()))
	_check(menu.is_cheat_feedback_visible()
		and menu.get_cheat_feedback_text() == "全部章节已解锁",
		"kskbl shows the 1.5 s feedback line",
		menu.get_cheat_feedback_text())
	await _wait_seconds(1.7)
	_check(not menu.is_cheat_feedback_visible(),
		"the cheat feedback clears after 1.5 s")

	await _open_chapters(menu)
	await _wait_process(3)
	_check(menu.get_chapters_progress_text() == "已完成 6 / 6",
		"all six chapters show as complete",
		menu.get_chapters_progress_text())
	for id: String in CHAPTER_PROGRESS.chapter_ids():
		_check(menu.get_chapter_status_text(id) == "已通关",
			"%s row reads 已通关" % id, menu.get_chapter_status_text(id))
		var row: PixelMenuButton = menu.get_chapter_row(id)
		_check(row != null and row.focus_mode != Control.FOCUS_NONE,
			"%s row is enterable after kskbl" % id)

	# Chapter page open: the same keys must not unlock again.
	for key: int in [KEY_K, KEY_S, KEY_K, KEY_B, KEY_L]:
		await _tap_key(key)
	await _wait_process(2)
	_check(menu.get_cheat_unlock_count() == 1,
		"the chapter page blocks the title cheat",
		str(menu.get_cheat_unlock_count()))
	await _drop_current_scene()


func _test_l1_completion_hook() -> void:
	var packed: PackedScene = load(LEVEL_01) as PackedScene
	var level: Node = packed.instantiate() if packed != null else null
	if level == null:
		_check(false, "L1 loads for the completion-hook check")
		return
	level.set("enable_start_menu", false)
	level.set("chapter_progress_path", P_COMPLETE)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(6)
	await _wait_physics(2)
	level.call("_on_exit_reached")
	await _wait_process(3)
	var completed: Dictionary = CHAPTER_PROGRESS.load_completed(P_COMPLETE)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L1, completed),
		"real L1 completion writes l1=true")
	_check(not CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L2, completed),
		"L1 hook does not write unrelated chapters")
	_check(CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_L2, completed),
		"real L1 hook unlocks L2")
	_check(CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_TRIAL, completed),
		"real L1 hook unlocks the trial")
	await _drop_current_scene()


func _test_l3_completion_hook() -> void:
	var packed: PackedScene = load(LEVEL_03_PATH) as PackedScene
	var level: Node = packed.instantiate() if packed != null else null
	if level == null:
		_check(false, "L3 loads for the completion-hook check")
		return
	level.set("chapter_progress_path", P_L3)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(8)
	level.call("_complete_city")
	await _wait_process(3)
	var completed: Dictionary = CHAPTER_PROGRESS.load_completed(P_L3)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L3, completed),
		"real L3 completion writes l3=true")
	_check(CHAPTER_PROGRESS.is_unlocked(CHAPTER_PROGRESS.ID_LOOM, completed),
		"real L3 hook unlocks 城内")
	await _drop_current_scene()


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


func _focused_row(menu: StartMenu, id: String) -> bool:
	return get_viewport().gui_get_focus_owner() == menu.get_chapter_row(id)


func _focus_name(menu: StartMenu) -> String:
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner == null:
		return "null"
	for id: String in CHAPTER_PROGRESS.chapter_ids():
		if owner == menu.get_chapter_row(id):
			return id
	return owner.name
