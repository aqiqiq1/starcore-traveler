extends Node

## Intro-guide test for 星核织机.
##
##   ... --headless --path . res://dlc/star_loom/tests/guide_test.tscn
##
## Verifies that the chapter opens the shared dlc/ui/dlc_guide.tscn with three
## real loom pages, that the page demo ids point at dlc/ui/demos, that F pages
## forward and the long Space hold closes the guide, and that a missing demo
## strip falls back to the shared "演示缺失" placeholder without an error.
## Demo strips are captured by dlc/star_loom/tools/capture_loom_demos.tscn.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const GUIDE_SCENE: PackedScene = preload("res://dlc/ui/dlc_guide.tscn")
const LOOM_GUIDE_SCRIPT: Script = preload("res://dlc/star_loom/loom_guide.gd")

var _loom: StarLoom
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	Input.action_release(&"move_right")
	print("STAR_LOOM_GUIDE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_f() -> void:
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(2)


func _load_loom() -> bool:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		return false
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = true
	get_tree().root.add_child(_loom)
	get_tree().current_scene = _loom
	await _wait_process(4)
	for _index: int in range(40):
		var guide: DlcGuide = _loom.get_intro_guide()
		if guide != null and is_instance_valid(guide) and guide.is_open():
			return true
		await get_tree().process_frame
	return false


func _cleanup() -> void:
	get_tree().paused = false
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(6)


func _run() -> void:
	var opened: bool = await _load_loom()
	_check(opened, "the chapter opens the shared guide on start")
	if not opened:
		return
	var guide: DlcGuide = _loom.get_intro_guide()
	_check(guide.guide_kind == "loom", "the guide is configured for the loom chapter",
		guide.guide_kind)
	_check(guide.get_page_count() == 3, "the guide has three pages",
		str(guide.get_page_count()))
	_check(guide.get_page_indicator_text() == "1 / 3", "page 1 indicator is 1 / 3",
		guide.get_page_indicator_text())
	_check(guide.get_title_text() == "织机与双节点",
		"page 1 title is 织机与双节点", guide.get_title_text())
	_check(guide.get_demo_id() == "loom_nodes", "page 1 demo id is loom_nodes",
		guide.get_demo_id())
	_check(guide.get_footer_text().contains("F 下一页"), "page 1 footer offers F next",
		guide.get_footer_text())
	var demo_ok: bool = guide.has_demo() and guide.get_demo_frame_count() == 24
	_check(demo_ok, "page 1 has a real 24-frame demo strip",
		"frames=%d fps=%.1f" % [guide.get_demo_frame_count(), guide.get_demo_fps()])
	_check(guide.get_demo_fps() == 8.0, "demo runs at 8 fps",
		str(guide.get_demo_fps()))
	_check(guide.is_demo_playing() or not demo_ok,
		"the 24-frame strip animates")

	await _tap_f()
	_check(guide.get_page_index() == 1, "F advances to page 2")
	_check(guide.get_demo_id() == "loom_core", "page 2 demo id is loom_core",
		guide.get_demo_id())
	_check(guide.get_title_text() == "核心暴露与三段真伤",
		"page 2 title is 核心暴露与三段真伤", guide.get_title_text())

	await _tap_f()
	_check(guide.get_page_index() == 2, "F advances to page 3")
	_check(guide.get_demo_id() == "loom_attacks", "page 3 demo id is loom_attacks",
		guide.get_demo_id())
	_check(guide.get_title_text() == "三段攻击与失败重置",
		"page 3 title is 三段攻击与失败重置", guide.get_title_text())
	_check(guide.get_footer_text().contains("F 关闭"), "page 3 footer offers F close",
		guide.get_footer_text())
	_check(guide.has_demo() and guide.get_demo_frame_count() == 24,
		"page 3 has a 24-frame demo strip",
		str(guide.get_demo_frame_count()))

	# Long Space hold closes the whole guide from any page.
	_push_key(KEY_SPACE, true)
	# Headless process frames are not locked to 60 Hz, so wait on the guide's
	# own 0.5 s hold progress rather than on a fixed frame count.
	for _index: int in range(600):
		if not guide.is_open():
			break
		await get_tree().process_frame
	_push_key(KEY_SPACE, false)
	await _wait_process(2)
	_check(not guide.is_open(), "long Space hold closes the guide")
	_check(not get_tree().paused, "closing the guide unpauses the tree")
	_check(_loom.get_player() != null, "the chapter player still exists after the guide")

	# Missing demo: the shared guide shows its static placeholder instead of an
	# error, and all three pages stay readable.
	var fallback: DlcGuide = GUIDE_SCENE.instantiate() as DlcGuide
	fallback.set_script(LOOM_GUIDE_SCRIPT)
	fallback.demo_dir = "res://dlc/ui/demos/__no_such_demos__"
	add_child(fallback)
	fallback.configure("loom", null)
	var fallback_opened: bool = fallback.open_guide()
	await _wait_process(3)
	_check(fallback_opened, "a loom guide opens for the missing-demo check")
	_check(fallback.get_page_count() == 3,
		"missing demos do not remove the three pages",
		str(fallback.get_page_count()))
	_check(fallback.is_demo_placeholder_visible(),
		"missing demo shows the 演示缺失 placeholder")
	_check(not fallback.has_demo(), "missing demo reports no demo")
	_check(fallback.get_title_text() == "织机与双节点",
		"missing demo keeps the page title readable", fallback.get_title_text())
	fallback.close()
	await _wait_process(2)
	_check(not get_tree().paused, "closing the fallback guide unpauses the tree")
