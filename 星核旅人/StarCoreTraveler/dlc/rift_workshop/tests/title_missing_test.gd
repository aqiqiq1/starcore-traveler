extends Node

## Missing-scene branch test for 裂隙工坊.
##
## Run with rift_workshop.tscn temporarily renamed:
##   ... --headless --path . res://dlc/rift_workshop/tests/title_missing_test.tscn
##
## The title has no DLC direct rows.  With the scene absent, the 章节 page hides
## the rift row and it stays disabled / unfocusable / unclickable, while the
## base title rows and the remaining chapter rows are unchanged.

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")

const LEVEL_01: String = "res://scenes/level_01.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	await _cleanup()
	print("RIFT_TITLE_MISSING_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _cleanup() -> void:
	var current: Node = get_tree().current_scene
	if current != null:
		var menu: Node = current.get_node_or_null("StartMenu")
		if menu != null and menu.has_method("stop_title_music_for_test"):
			menu.call("stop_title_music_for_test")
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(20)


func _run() -> void:
	await _wait_process(2)
	_check(not ResourceLoader.exists(RIFT), "rift scene file is absent for this run")
	_check(not CHAPTER_PROGRESS.is_available(CHAPTER_PROGRESS.ID_RIFT),
		"chapter_progress reports the missing rift scene")
	var packed: PackedScene = load(LEVEL_01) as PackedScene
	_check(packed != null, "level_01 loads with the DLC scene absent")
	if packed == null:
		return
	var level: Node = packed.instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(4)
	await _wait_physics(4)
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	_check(menu != null and menu.is_menu_open(), "title menu is open")
	if menu == null:
		return

	_check(menu.find_child("RiftButton", true, false) == null,
		"title has no 裂隙工坊 direct row")
	_check(menu.find_child("TrialButton", true, false) == null,
		"title has no 试炼场 direct row")
	_check(menu.find_child("LoomButton", true, false) == null,
		"title has no 星核织机 direct row")

	var start_button: Button = menu.get_start_button()
	var chapter_button: Button = menu.get_chapter_button()
	var settings_button: Button = menu.get_settings_button()
	var quit_button: Button = menu.get_quit_button()
	_check(start_button.get_node(start_button.focus_next) == chapter_button,
		"start focus_next is 章节")
	_check(chapter_button.get_node(chapter_button.focus_next) == settings_button,
		"章节 focus_next is 设置")
	_check(settings_button.get_node(settings_button.focus_next) == quit_button,
		"设置 focus_next is 退出游戏")
	_check(quit_button.get_node(quit_button.focus_next) == start_button,
		"退出游戏 focus_next loops to 开始游戏")

	chapter_button.pressed.emit()
	await _wait_process(4)
	var rift_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_RIFT)
	_check(rift_row != null, "missing rift row still exists as a node")
	if rift_row != null:
		_check(not rift_row.visible, "missing scene hides the rift row")
		_check(rift_row.disabled, "missing scene leaves the rift row disabled")
		_check(rift_row.focus_mode == Control.FOCUS_NONE,
			"hidden rift row cannot take focus", str(rift_row.focus_mode))
		_check(rift_row.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"hidden rift row cannot be clicked")
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_RIFT) == "章节场景缺失",
		"rift row reports the missing scene",
		menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_RIFT))
	var l1_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_L1)
	_check(l1_row != null and l1_row.visible and not l1_row.disabled,
		"L1 row remains visible and enterable")
	menu.call("_close_chapters")
	await _wait_process(2)

	_check(start_button.visible and not start_button.disabled,
		"existing 开始游戏 row stays visible and enabled")
	start_button.grab_focus()
	await _wait_process(3)
	_check(start_button.has_focus(), "existing start row still takes focus")
	await _wait_process(3)
