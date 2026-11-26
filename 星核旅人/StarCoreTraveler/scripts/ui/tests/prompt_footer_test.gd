extends Node

## Shared base-prompt footer test.
##
##   ... --headless --path . res://scripts/ui/tests/prompt_footer_test.tscn
##
## Covers the one PromptFooter component (layout, copy, 0.15 s fade-in,
## immediate hide, no input) and the three real owners:
##   L1 opening film  -> echo pages inside the opening CanvasLayer
##   L2 watcher echo  -> dialogue bubble + range/suspend rules
##   L3 cinematic     -> dialogue bubble inside CineUI
## Each owner must show the footer only while a fully revealed page waits for
## F, and hide it while typing / after closing or ending.

const PROMPT_FOOTER_SCRIPT = preload("res://scripts/ui/prompt_footer.gd")
const L1_SCENE: String = "res://scenes/level_01.tscn"
const L2_SCENE: String = "res://scenes/level_02.tscn"
const L3_SCENE: String = "res://scenes/level_03.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _test_component()
	await _test_level_01()
	await _test_level_02()
	await _test_level_03()
	print("PROMPT_FOOTER_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var started: int = Time.get_ticks_msec()
	var limit: int = int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() - started < limit:
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return false


func _push_key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: Key) -> void:
	_push_key(code, true)
	await _wait_process(2)
	_push_key(code, false)
	await _wait_process(2)


func _cleanup(level: Node) -> void:
	await _wait_process(2)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().paused = false
	if level != null and is_instance_valid(level):
		# Release the looping music and footstep voices before teardown so the
		# headless run does not leave playback objects at exit.
		if level.has_method("get_music"):
			var music: Node = level.call("get_music") as Node
			if music != null and music.has_method("stop"):
				music.call("stop", 0.0)
		if level.has_method("get_footstep_audio"):
			var steps: Node = level.call("get_footstep_audio") as Node
			if steps != null and steps.has_method("stop"):
				steps.call("stop")
	get_tree().current_scene = null
	if level != null and is_instance_valid(level):
		level.queue_free()
	for _index: int in range(16):
		await get_tree().process_frame


func _script_defines_input(footer: Control) -> bool:
	var script: Script = footer.get_script() as Script
	if script == null:
		return false
	for method: Dictionary in script.get_script_method_list():
		if String(method.get("name", "")) == "_input":
			return true
	return false


func _test_component() -> void:
	print("=== PROMPT FOOTER COMPONENT ===")
	var footer: Control = PROMPT_FOOTER_SCRIPT.new()
	add_child(footer)
	await _wait_process(1)
	_check(footer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"footer ignores mouse input")
	_check(not _script_defines_input(footer), "footer does not define _input")
	_check(not footer.is_processing_input(), "footer never processes input")
	_check(not footer.visible, "footer starts hidden")
	_check(is_equal_approx(float(footer.call("get_right_edge")), 628.0),
		"footer right edge is x=628", "%.1f" % float(footer.call("get_right_edge")))
	_check(is_equal_approx(float(footer.call("get_baseline_y")), 334.0),
		"footer baseline is y=334",
		"%.1f" % float(footer.call("get_baseline_y")))
	_check(int(footer.call("get_font_size")) == 12, "footer copy is 12 px")
	_check(int(footer.call("get_keycap_height")) == 16, "footer keycap is 16 px")
	_check((footer.call("get_text_color") as Color) == Color("#a4b3be"),
		"footer copy is warm grey #a4b3be")

	footer.call("show_footer", PROMPT_FOOTER_SCRIPT.PAGE_FOOTER)
	_check(footer.visible, "show_footer makes the row visible")
	_check(String(footer.call("get_text")) == PROMPT_FOOTER_SCRIPT.PAGE_FOOTER,
		"multi-page copy is F continue + hold-space skip",
		String(footer.call("get_text")))
	_check(footer.modulate.a < 1.0, "footer starts its 0.15 s fade",
		"%.3f" % footer.modulate.a)
	await _wait_seconds(0.18)
	_check(is_equal_approx(footer.modulate.a, 1.0),
		"footer fade-in settles at alpha 1", "%.3f" % footer.modulate.a)

	footer.call("show_footer", PROMPT_FOOTER_SCRIPT.SINGLE_FOOTER)
	_check(String(footer.call("get_text")) == PROMPT_FOOTER_SCRIPT.SINGLE_FOOTER,
		"single-confirmation copy is F continue only")
	footer.call("hide_footer")
	_check(not footer.visible, "hide_footer is immediate")
	_check(is_equal_approx(footer.modulate.a, 0.0),
		"hidden footer resets alpha", "%.3f" % footer.modulate.a)
	await _wait_seconds(0.2)
	_check(not footer.visible, "a killed fade cannot bring the footer back")

	# Interrupting a fade-in must not leave a tween that resurrects the row.
	footer.call("show_footer", PROMPT_FOOTER_SCRIPT.PAGE_FOOTER)
	await _wait_seconds(0.02)
	footer.call("hide_footer")
	await _wait_seconds(0.2)
	_check(not footer.visible and is_equal_approx(footer.modulate.a, 0.0),
		"hide during the fade-in stays hidden")
	footer.queue_free()
	await _wait_process(1)


func _test_level_01() -> void:
	print("=== L1 OPENING FOOTER ===")
	var level: Node = (load(L1_SCENE) as PackedScene).instantiate()
	level.set("enable_start_menu", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(3)
	var opening: Node = level.call("get_opening")
	_check(opening != null, "L1 opening controller exists")
	if opening == null:
		await _cleanup(level)
		return
	var reached: bool = await _wait_until(func() -> bool:
		var echo_node: Node = opening.call("get_dialogue_echo")
		return (
			String(opening.call("get_phase_name")) == "DIALOGUE"
			and echo_node != null
			and bool(echo_node.call("is_dialogue_open"))
		), 14.0)
	_check(reached, "L1 opening reaches its waiting page")
	if not reached:
		await _cleanup(level)
		return
	var echo: Node = opening.call("get_dialogue_echo")
	var footer: Control = opening.call("get_prompt_footer") as Control
	_check(footer != null, "L1 opening owns a PromptFooter")
	if footer == null:
		await _cleanup(level)
		return
	_check(footer.get_parent() != null
		and footer.get_parent().get_parent() is CanvasLayer,
		"L1 footer sits under the opening CanvasLayer")
	var echo_footer: Control = echo.call("get_prompt_footer") as Control
	_check(echo_footer != null and not echo_footer.visible,
		"the echo's own footer stays hidden while the film owns it")
	_check(not bool(opening.call("is_prompt_footer_visible")),
		"L1 footer stays hidden while the page is typing")

	var revealed: bool = await _wait_until(func() -> bool:
		return int(echo.call("get_revealed_count")) \
			>= String(echo.call("get_full_page_text")).length(), 8.0)
	_check(revealed, "L1 page 1 finishes revealing")
	await _wait_seconds(0.18)
	_check(bool(opening.call("is_prompt_footer_visible")),
		"L1 footer appears when the page waits for F")
	_check(String(opening.call("get_prompt_footer_text"))
		== PROMPT_FOOTER_SCRIPT.PAGE_FOOTER,
		"L1 first page shows the multi-page footer",
		String(opening.call("get_prompt_footer_text")))

	echo.call("advance_page")
	await _wait_process(2)
	_check(not bool(opening.call("is_prompt_footer_visible")),
		"L1 footer hides while the next page types")
	revealed = await _wait_until(func() -> bool:
		return int(echo.call("get_revealed_count")) \
			>= String(echo.call("get_full_page_text")).length(), 8.0)
	_check(revealed, "L1 page 2 finishes revealing")
	await _wait_seconds(0.18)
	_check(String(opening.call("get_prompt_footer_text"))
		== PROMPT_FOOTER_SCRIPT.PAGE_FOOTER,
		"L1 middle page shows the multi-page footer")

	echo.call("advance_page")
	await _wait_process(2)
	revealed = await _wait_until(func() -> bool:
		return int(echo.call("get_revealed_count")) \
			>= String(echo.call("get_full_page_text")).length(), 8.0)
	_check(revealed, "L1 page 3 finishes revealing")
	await _wait_seconds(0.18)
	_check(String(opening.call("get_prompt_footer_text"))
		== PROMPT_FOOTER_SCRIPT.SINGLE_FOOTER,
		"L1 last page shows the single-confirmation footer",
		String(opening.call("get_prompt_footer_text")))
	_check(footer.get_parent().get_parent() is CanvasLayer
		and int((footer.get_parent().get_parent() as CanvasLayer).layer) < 16,
		"L1 footer is above the scene and below the pause page")

	# The hold bar owns the same lower-right corner.  A real Space hold shows
	# it and the footer yields; releasing returns the footer without touching
	# the existing skip timer/hand-off.
	_push_key(KEY_SPACE, true)
	var bar_seen: bool = await _wait_until(func() -> bool:
		return bool(opening.call("is_skip_bar_visible")), 0.35)
	_check(bar_seen, "L1 hold bar appears while Space is held")
	_check(not bool(opening.call("is_prompt_footer_visible")),
		"L1 footer yields the corner to the hold bar")
	_push_key(KEY_SPACE, false)
	await _wait_process(3)
	_check(bool(opening.call("is_prompt_footer_visible")),
		"L1 footer returns after Space is released")

	echo.call("close_dialogue")
	await _wait_process(2)
	_check(not bool(opening.call("is_prompt_footer_visible")),
		"L1 footer hides when the bubble closes")
	opening.call("abort")
	await _wait_process(2)
	_check(not bool(opening.call("is_prompt_footer_visible")),
		"L1 footer stays hidden after the film ends")
	await _cleanup(level)


func _test_level_02() -> void:
	print("=== L2 GUIDE ECHO FOOTER ===")
	var level: Node = (load(L2_SCENE) as PackedScene).instantiate()
	# This probe is about the footer, not the tutorial popup; keep the
	# range-move from opening the queued core-carry lesson and pausing the tree.
	MechanicTips.mark_seen("core_carry")
	MechanicTips.mark_seen("relay_link")
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_seconds(0.6)
	var echo: Node = level.call("get_start_stele")
	_check(echo != null, "L2 start echo exists")
	if echo == null:
		await _cleanup(level)
		return
	_check(bool(echo.call("open_dialogue")), "L2 echo opens its bubble")
	await _wait_process(2)
	var footer: Control = echo.call("get_prompt_footer") as Control
	_check(footer != null, "L2 echo owns a PromptFooter")
	if footer == null:
		await _cleanup(level)
		return
	_check(footer.get_parent() is CanvasLayer,
		"L2 footer sits under the echo's existing CanvasLayer")
	_check(not bool(echo.call("is_prompt_footer_visible")),
		"L2 footer stays hidden while the page is typing")

	var revealed: bool = await _wait_until(func() -> bool:
		return int(echo.call("get_revealed_count")) \
			>= String(echo.call("get_full_page_text")).length(), 8.0)
	_check(revealed, "L2 page 1 finishes revealing")
	await _wait_seconds(0.18)
	_check(bool(echo.call("is_prompt_footer_visible")),
		"L2 footer appears while the bubble waits for F")
	_check(String(echo.call("get_prompt_footer_text"))
		== PROMPT_FOOTER_SCRIPT.PAGE_FOOTER,
		"L2 first page shows the multi-page footer",
		String(echo.call("get_prompt_footer_text")))

	# Four pages: advance and immediately complete each reveal so the last page
	# is reached quickly without waiting on the typewriter.
	for _index: int in range(3):
		echo.call("advance_page")
		await _wait_process(1)
		echo.call("advance_page")
		await _wait_process(1)
	await _wait_process(2)
	_check(int(echo.call("get_page_index")) == int(echo.call("get_page_count")) - 1,
		"L2 reaches its last page", str(echo.call("get_page_index")))
	_check(String(echo.call("get_prompt_footer_text"))
		== PROMPT_FOOTER_SCRIPT.SINGLE_FOOTER,
		"L2 last page shows the single-confirmation footer",
		String(echo.call("get_prompt_footer_text")))

	# Leaving the interaction range closes the bubble and the footer at once.
	var player: Node2D = level.call("get_player") as Node2D
	var saved: Vector2 = player.global_position
	player.global_position = saved + Vector2(300.0, 0.0)
	await _wait_process(4)
	_check(not bool(echo.call("is_prompt_footer_visible")),
		"L2 footer hides when the player leaves the range")
	_check(not bool(echo.call("is_dialogue_open")),
		"L2 bubble closes out of range")

	player.global_position = saved
	# Distance is immediate but the echo's 0.25 s manifestation fade must return
	# before open_dialogue() accepts the page again.
	var back_in_range: bool = await _wait_until(func() -> bool:
		return bool(echo.call("is_in_range")) \
			and float(echo.call("get_manifestation")) > 0.9, 3.0)
	_check(back_in_range, "L2 echo manifests again back in range")
	_check(bool(echo.call("open_dialogue")), "L2 echo reopens back in range")
	await _wait_process(2)
	revealed = await _wait_until(func() -> bool:
		return int(echo.call("get_revealed_count")) \
			>= String(echo.call("get_full_page_text")).length(), 8.0)
	_check(revealed, "L2 reopened page finishes revealing")
	await _wait_seconds(0.18)
	_check(bool(echo.call("is_prompt_footer_visible")),
		"L2 footer returns for the reopened page")
	echo.call("set_suspended", true)
	await _wait_process(2)
	_check(not bool(echo.call("is_prompt_footer_visible")),
		"L2 footer hides immediately on suspend (the pause path)")
	echo.call("set_suspended", false)
	var awake: bool = await _wait_until(func() -> bool:
		return bool(echo.call("is_in_range")) \
			and float(echo.call("get_manifestation")) > 0.9, 3.0)
	_check(awake, "L2 echo wakes after suspend")
	_check(bool(echo.call("open_dialogue")), "L2 echo reopens after suspend")
	await _wait_process(2)
	echo.call("close_dialogue")
	await _wait_process(2)
	_check(not bool(echo.call("is_prompt_footer_visible")),
		"L2 footer hides when the bubble closes")
	await _cleanup(level)


func _test_level_03() -> void:
	print("=== L3 CINEMATIC FOOTER ===")
	var level: Node = (load(L3_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(4)
	level.call("debug_setup_pre_teaching", 2250.0)
	await _wait_process(4)
	var guard: Node = level.call("get_guard")
	guard.call("restore_waiting_rubble", level.call("get_guard_spawn"))
	await _wait_process(2)
	level.call("_start_cinematic")
	var cine: Node = level.call("get_cine")
	_check(cine != null and bool(cine.call("is_active")),
		"L3 cinematic starts through the real level path")
	if cine == null:
		await _cleanup(level)
		return
	var reached: bool = await _wait_until(func() -> bool:
		return (
			String(cine.call("get_phase_name")) == "DIALOGUE"
			and bool(cine.call("is_bubble_visible"))
		), 14.0)
	_check(reached, "L3 cinematic reaches its dialogue page")
	if not reached:
		await _cleanup(level)
		return
	var footer: Control = cine.call("get_prompt_footer") as Control
	_check(footer != null, "L3 cinematic owns a PromptFooter")
	if footer == null:
		await _cleanup(level)
		return
	_check(footer.get_parent() != null
		and footer.get_parent().get_parent() is CanvasLayer,
		"L3 footer sits under CineUI")
	_check(not bool(cine.call("is_prompt_footer_visible")),
		"L3 footer stays hidden while the page is typing")

	var revealed: bool = await _wait_until(func() -> bool:
		return String(cine.call("get_body_text")).length() \
			>= String(cine.call("get_full_page_text")).length(), 8.0)
	_check(revealed, "L3 page 1 finishes revealing")
	await _wait_seconds(0.18)
	_check(bool(cine.call("is_prompt_footer_visible")),
		"L3 footer appears while the bubble waits for F")
	_check(String(cine.call("get_prompt_footer_text"))
		== PROMPT_FOOTER_SCRIPT.PAGE_FOOTER,
		"L3 first page shows the multi-page footer",
		String(cine.call("get_prompt_footer_text")))

	await _tap_key(KEY_F)
	await _wait_process(2)
	_check(int(cine.call("get_page_index")) == 1, "L3 F advances to page 2")
	_check(not bool(cine.call("is_prompt_footer_visible")),
		"L3 footer hides while page 2 types")
	revealed = await _wait_until(func() -> bool:
		return String(cine.call("get_body_text")).length() \
			>= String(cine.call("get_full_page_text")).length(), 8.0)
	_check(revealed, "L3 page 2 finishes revealing")
	await _wait_seconds(0.18)
	_check(String(cine.call("get_prompt_footer_text"))
		== PROMPT_FOOTER_SCRIPT.PAGE_FOOTER,
		"L3 middle page shows the multi-page footer")

	await _tap_key(KEY_F)
	await _wait_process(2)
	_check(int(cine.call("get_page_index")) == 2, "L3 F advances to page 3")
	revealed = await _wait_until(func() -> bool:
		return String(cine.call("get_body_text")).length() \
			>= String(cine.call("get_full_page_text")).length(), 8.0)
	_check(revealed, "L3 page 3 finishes revealing")
	await _wait_seconds(0.18)
	_check(String(cine.call("get_prompt_footer_text"))
		== PROMPT_FOOTER_SCRIPT.SINGLE_FOOTER,
		"L3 last page shows the single-confirmation footer",
		String(cine.call("get_prompt_footer_text")))
	_check(footer.get_parent().get_parent() is CanvasLayer
		and int((footer.get_parent().get_parent() as CanvasLayer).layer) < 16,
		"L3 footer is above the scene and below the pause page")

	cine.call("abort")
	await _wait_process(2)
	_check(not bool(cine.call("is_prompt_footer_visible")),
		"L3 footer hides when the cinematic ends")
	await _cleanup(level)
