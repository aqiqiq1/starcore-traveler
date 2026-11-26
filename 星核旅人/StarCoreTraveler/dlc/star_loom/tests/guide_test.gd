extends Node

## Intro-guide test for 星核织机.
##
##   ... --headless --path . res://dlc/star_loom/tests/guide_test.tscn
##
## Verifies that the chapter opens the shared dlc/ui/dlc_guide.tscn with two
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


## Full-width units: ASCII and digits count 0.5, CJK punctuation and Han 1.0.
## The shared body label is 266 px wide at 12 px, so 21 units is the safe cap.
func _display_width(text_value: String) -> float:
	var width: float = 0.0
	for index: int in range(text_value.length()):
		width += 0.5 if text_value.unicode_at(index) < 128 else 1.0
	return width


func _max_body_line_width(text_value: String) -> float:
	var widest: float = 0.0
	for line: String in text_value.split("\n"):
		widest = maxf(widest, _display_width(line))
	return widest


func _body_line_count(text_value: String) -> int:
	return text_value.split("\n").size()


## A standalone Q/J/E/F (not the E of "Esc") is banned outside key rows.
func _has_bare_key_letter(text: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("(^|[^A-Za-z])[QJEF]([^A-Za-z]|$)")
	return regex.search(text) != null


func _load_loom() -> bool:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		return false
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = true
	_loom.show_intro_cinematic = false
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
	_check(_loom.is_mechanic_popup_blocked(),
		"the mechanic popup is blocked while the intro guide is open")
	_check(guide.get_page_count() == 2, "the guide has two pages",
		str(guide.get_page_count()))
	_check(guide.get_page_indicator_text() == "1 / 2", "page 1 indicator is 1 / 2",
		guide.get_page_indicator_text())
	_check(guide.get_title_text() == "星核织机",
		"page 1 title is 星核织机", guide.get_title_text())
	_check(guide.get_body_text() == "织机以星核为梭，把全城命脉织进经线。\n打停两节点→打暴露核心；核心受创换相。",
		"page 1 body matches the condensed spec", guide.get_body_text())
	_check(guide.get_key_text() == "先看清相位，再绕到节点的异相一侧挥剑。",
		"page 1 key is a natural sentence", guide.get_key_text())
	_check(not _has_bare_key_letter(guide.get_body_text()),
		"page 1 body has no bare Q/J/E/F", guide.get_body_text())
	_check(guide.get_footer_rich_text().contains("[img=16x16]"),
		"page 1 footer renders the F keycap", guide.get_footer_rich_text())
	_check(_max_body_line_width(guide.get_body_text()) <= 21.0,
		"page 1 body lines fit 21 full-width units",
		"%.1f" % _max_body_line_width(guide.get_body_text()))
	_check(_body_line_count(guide.get_body_text()) <= 3,
		"page 1 body has at most three lines",
		str(_body_line_count(guide.get_body_text())))
	_check(_display_width(guide.get_key_text()) <= 21.0,
		"page 1 key fits 21 full-width units",
		"%.1f" % _display_width(guide.get_key_text()))
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
	_check(guide.get_demo_id() == "loom_gear", "page 2 demo id is loom_gear",
		guide.get_demo_id())
	_check(guide.has_demo() and guide.get_demo_frame_count() == 24,
		"page 2 has a 24-frame demo strip",
		str(guide.get_demo_frame_count()))
	_check(guide.get_title_text() == "城垣的护持",
		"page 2 title is 城垣的护持", guide.get_title_text())
	_check(guide.get_body_text() == "生命值三格，每受击掉一格；三格耗尽折一命。\n阶段 1 结束补满；失败从当前阶段重开。\n齿轮跳过，浮灵用攻击清。",
		"page 2 body explains health, lives, refill and retry", guide.get_body_text())
	_check(not _has_bare_key_letter(guide.get_body_text()),
		"page 2 body has no bare Q/J/E/F", guide.get_body_text())
	_check(guide.get_key_text() == "跳过齿轮，用攻击清掉浮灵。",
		"page 2 key is a natural sentence", guide.get_key_text())
	_check(not guide.get_key_text().contains("[img]")
		and not guide.get_key_text().contains("{"),
		"page 2 get_key_text is plain, not markup")
	_check(guide.get_footer_rich_text().contains("[img=16x16]"),
		"page 2 footer renders the F keycap", guide.get_footer_rich_text())
	_check(_max_body_line_width(guide.get_body_text()) <= 21.0,
		"page 2 body lines fit 21 full-width units",
		"%.1f" % _max_body_line_width(guide.get_body_text()))
	_check(_body_line_count(guide.get_body_text()) <= 3,
		"page 2 body has at most three lines",
		str(_body_line_count(guide.get_body_text())))
	_check(_display_width(guide.get_key_text()) <= 21.0,
		"page 2 key fits 21 full-width units",
		"%.1f" % _display_width(guide.get_key_text()))
	_check(guide.get_footer_text().contains("F 关闭"), "page 2 footer offers F close",
		guide.get_footer_text())

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
	# R restarts the chapter after the guide is closed; it must not reopen the
	# two intro pages or create a fresh guide instance.
	_push_key(KEY_R, true)
	await _wait_process(2)
	_push_key(KEY_R, false)
	await _wait_process(12)
	_check(not guide.is_open(), "R does not reopen the intro guide")
	_check(_loom.get_intro_guide() == guide,
		"R does not recreate the intro guide instance")

	# Missing demo: the shared guide shows its static placeholder instead of an
	# error, and both pages stay readable.
	var fallback: DlcGuide = GUIDE_SCENE.instantiate() as DlcGuide
	fallback.set_script(LOOM_GUIDE_SCRIPT)
	fallback.demo_dir = "res://dlc/ui/demos/__no_such_demos__"
	add_child(fallback)
	fallback.configure("loom", null)
	var fallback_opened: bool = fallback.open_guide()
	await _wait_process(3)
	_check(fallback_opened, "a loom guide opens for the missing-demo check")
	_check(fallback.get_page_count() == 2,
		"missing demos do not remove the two pages",
		str(fallback.get_page_count()))
	_check(fallback.is_demo_placeholder_visible(),
		"missing demo shows the 演示缺失 placeholder")
	_check(not fallback.has_demo(), "missing demo reports no demo")
	_check(fallback.get_title_text() == "星核织机",
		"missing demo keeps the page title readable", fallback.get_title_text())
	fallback.close()
	await _wait_process(2)
	_check(not get_tree().paused, "closing the fallback guide unpauses the tree")
