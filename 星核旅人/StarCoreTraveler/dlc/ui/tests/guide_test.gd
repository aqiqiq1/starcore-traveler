extends Node

## Shared DLC intro-guide test.
##
##   ... --headless --path . res://dlc/ui/tests/guide_test.tscn
##
## Verifies both chapters auto-open exactly one 3-page guide, pause the tree,
## advance/close with real F key events, swallow Esc, ignore a Space tap, close
## on a 0.5 s Space hold, and leave the player able to move afterwards.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run_trial()
	await _run_rift()
	print("DLC_GUIDE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _near(value: float, expected: float) -> bool:
	return absf(value - expected) <= 0.001


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


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
	await _wait_process(3)


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _check_demo(guide: DlcGuide, expected_id: String) -> void:
	_check(guide.get_demo_id() == expected_id, "page binds demo %s" % expected_id,
		guide.get_demo_id())
	_check(guide.has_demo(), "demo %s is present" % expected_id)
	_check(guide.get_demo_frame_count() == 24,
		"demo %s has 24 frames" % expected_id, str(guide.get_demo_frame_count()))
	_check(is_equal_approx(guide.get_demo_fps(), 8.0),
		"demo %s plays at 8 fps" % expected_id, "%.2f" % guide.get_demo_fps())
	_check(guide.get_demo_rect().size == Vector2(256.0, 144.0),
		"demo window is 256x144", str(guide.get_demo_rect().size))


func _press_f_now() -> void:
	_push_key(KEY_F, true)
	_push_key(KEY_F, false)


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	if current != null and current.has_method("get_ambience"):
		# Release the looping Ogg before teardown; otherwise a forced quit can
		# leave four playback objects in the engine's exit report.
		var ambience: DlcChapterAmbience = current.call("get_ambience") as DlcChapterAmbience
		if ambience != null:
			var player: AudioStreamPlayer = ambience.get_player()
			if player != null:
				player.stream = null
			ambience.stop(0.0)
			ambience.set("_stream", null)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(4)
	# Give the audio thread time to release the cleared playback objects.
	for _index: int in range(16):
		await get_tree().process_frame


## The real chapter plays its short intro film before the guide.  Wait for the
## hand-off instead of assuming the guide exists six frames after add_child().
func _wait_for_guide(level: Node, timeout_ms: int) -> DlcGuide:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		var guide: DlcGuide = level.call("get_intro_guide") as DlcGuide
		if guide != null:
			return guide
		await get_tree().process_frame
	return null


func _wait_page_transition(guide: DlcGuide, timeout_ms: int = 900) -> void:
	var started: int = Time.get_ticks_msec()
	while guide.is_page_transitioning() and Time.get_ticks_msec() - started < timeout_ms:
		await get_tree().process_frame
	await _wait_process(1)


func _hold_space_until(guide: DlcGuide, timeout_ms: int) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var bar_seen: bool = false
	_push_key(KEY_SPACE, true)
	while Time.get_ticks_msec() - started < timeout_ms:
		await get_tree().process_frame
		if guide.is_skip_bar_visible():
			bar_seen = true
		if not guide.is_open():
			break
	_push_key(KEY_SPACE, false)
	await _wait_process(3)
	return {"bar_seen": bar_seen}


func _run_trial() -> void:
	print("=== TRIAL GUIDE ===")
	var trial: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	get_tree().root.add_child(trial)
	get_tree().current_scene = trial
	await _wait_process(6)
	var guide: DlcGuide = await _wait_for_guide(trial, 12000)
	_check(guide != null, "trial auto-creates the shared guide")
	if guide == null:
		await _cleanup()
		return
	_check(guide.is_open(), "trial guide opens at level start")
	_check(get_tree().paused, "opening the guide pauses the tree")
	var reveal: UiReveal = guide.get_reveal()
	_check(reveal != null, "trial guide uses the shared UiReveal")
	_check(reveal != null and reveal.is_root_visible(), "trial guide root is visible")
	_check(guide.get_page_count() == 2, "trial guide has 2 pages",
		str(guide.get_page_count()))
	_check(guide.get_page_indicator_text() == "1 / 2",
		"trial page indicator starts at 1 / 2", guide.get_page_indicator_text())
	_check(guide.get_panel_rect().size == Vector2(560.0, 236.0),
		"guide panel is 560x236", str(guide.get_panel_rect().size))
	_check_demo(guide, "trial_gate")
	_check(guide.get_footer_text() == "F 下一页 · 长按空格 跳过",
		"footer shows F next + hold-space skip", guide.get_footer_text())
	await _wait_seconds(0.4)
	_check(guide.get_demo_frame() > 0, "page 1 demo is playing",
		"frame=%d" % guide.get_demo_frame())
	if reveal != null:
		_check(not reveal.is_animating(), "trial open reveal ends while paused")
		_check(_near(reveal.get_shade_alpha(), 1.0), "trial shade settles at 1",
			"%.3f" % reveal.get_shade_alpha())
		_check(_near(reveal.get_panel_scale(), 1.0), "trial panel settles at 1x",
			"%.3f" % reveal.get_panel_scale())

	# Esc is swallowed: neither the guide nor the pause page reacts.
	await _tap_key(KEY_ESCAPE)
	_check(guide.is_open(), "Esc does not close the guide")
	_check(not trial.is_pause_open(), "Esc does not open the pause page")

	# A short Space tap is inert (one page stays, guide stays open).
	_push_key(KEY_SPACE, true)
	await _wait_process(2)
	_push_key(KEY_SPACE, false)
	await _wait_process(3)
	_check(guide.is_open() and guide.get_page_index() == 0,
		"a short Space tap changes nothing",
		"page=%d" % guide.get_page_index())

	# F advances one page at a time; the flip is a 0.12 s alpha crossfade with
	# no scale/slide.  The next page's demo starts at frame 0 after the swap.
	_check(_near(DlcGuide.PAGE_FADE_OUT + DlcGuide.PAGE_FADE_IN, 0.12),
		"page crossfade is 0.06 s out + 0.06 s in = 0.12 s")
	_press_f_now()
	_check(guide.is_open(), "F keeps the guide open on page 2")
	_check(guide.get_page_index() == 1, "F accepts page 2 immediately")
	_check(guide.is_page_transitioning(), "F starts the 0.12 s page crossfade")
	await _wait_process(3)
	_check(guide.get_content_alpha() < 1.0,
		"page content alpha drops during the flip",
		"%.3f" % guide.get_content_alpha())
	_press_f_now()
	_check(guide.get_page_index() == 1,
		"F during the flip does not skip a page", str(guide.get_page_index()))
	await _wait_page_transition(guide)
	_check(not guide.is_page_transitioning(), "the page flip finishes")
	_check(_near(guide.get_content_alpha(), 1.0),
		"page content returns to alpha 1 after 0.12 s",
		"%.3f" % guide.get_content_alpha())
	_check(guide.get_page_indicator_text() == "2 / 2",
		"page indicator is 2 / 2", guide.get_page_indicator_text())
	_check(guide.get_demo_frame() == 0, "page 2 demo restarts at frame 0",
		"frame=%d" % guide.get_demo_frame())
	_check_demo(guide, "trial_guard_hit")
	_check(guide.get_footer_text() == "F 关闭 · 长按空格 跳过",
		"last page footer says F closes", guide.get_footer_text())
	await _wait_seconds(0.4)
	_check(guide.get_demo_frame() > 0, "page 2 demo is playing",
		"frame=%d" % guide.get_demo_frame())

	# A 0.5 s Space hold closes the whole guide from the last page.
	var hold: Dictionary = await _hold_space_until(guide, 900)
	_check(not guide.is_open(), "long Space hold closes the guide")
	_check(bool(hold.get("bar_seen", false)), "skip bar is visible during the hold")
	_check(not get_tree().paused, "closing the guide unpauses the tree")
	if reveal != null:
		_check(not reveal.is_animating() or reveal.is_close_animating(),
			"long hold either finishes or is in the exit tween")
		await _wait_seconds(0.16)
		_check(not reveal.is_root_visible(), "trial guide hides after the exit fade")
		_check(not reveal.is_animating(), "trial close tween ends")
	_check(guide.get_open_count() == 1, "trial guide opened exactly once",
		str(guide.get_open_count()))

	# It must not reopen by itself.
	await _wait_process(60)
	_check(not guide.is_open(), "trial guide does not reopen after closing")

	# Missing demo: no code diagram, no error.  The 256x144 window shows the
	# "演示缺失" placeholder and the page text stays readable.
	guide.demo_dir = "res://dlc/ui/tests/out/missing_demos"
	_check(guide.open_guide(), "guide can reopen for the missing-demo fallback")
	if reveal != null:
		_check(reveal.is_open_animating(), "guide reopen starts the reveal tween")
		_check(reveal.get_shade_alpha() < 1.0, "guide reopen shade starts below 1",
			"%.3f" % reveal.get_shade_alpha())
		_check(_near(reveal.get_panel_scale(), 1.0),
			"guide reopen panel stays at 1.0 (no text zoom)")
	_check(not guide.has_demo(), "missing demo is not treated as a playing strip")
	_check(guide.is_demo_placeholder_visible(), "missing demo shows the placeholder")
	_check(guide.get_demo_placeholder_text() == "演示缺失",
		"placeholder text is 演示缺失", guide.get_demo_placeholder_text())
	_check(guide.get_demo_frame_count() == 0,
		"missing demo has no frame count", str(guide.get_demo_frame_count()))
	_check(guide.get_title_text().length() > 0 and guide.get_body_text().length() > 0,
		"missing demo keeps the page text")
	# F must keep working during the open tween: input is never gated by it.
	_press_f_now()
	_check(guide.get_page_index() == 1 and not guide.has_demo(),
		"missing demo fallback advances pages during the reveal")
	await _wait_page_transition(guide)
	_check(guide.get_page_index() == 1 and guide.is_open(),
		"missing demo fallback reaches the last page")
	_press_f_now()
	_check(not guide.is_open(), "missing demo guide closes with F")
	_check(not get_tree().paused, "missing demo close unpauses the tree")
	if reveal != null:
		_check(reveal.is_close_animating(), "F close starts the exit tween")
		_check(reveal.is_root_visible(), "guide root stays only for the exit fade")
		await _wait_seconds(0.16)
		_check(not reveal.is_root_visible(), "guide root hides after the exit fade")
		_check(not reveal.is_animating(), "guide exit tween ends")
	guide.demo_dir = DlcGuide.DEMO_DIR
	await _wait_process(4)

	# The player must be able to move after closing the guide.
	var x_before: float = trial.get_player().global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(14)
	Input.action_release(&"move_right")
	await _wait_physics(2)
	_check(trial.get_player().global_position.x > x_before + 2.0,
		"player can move after closing the trial guide",
		"x=%.2f" % trial.get_player().global_position.x)
	await _cleanup()


func _run_rift() -> void:
	print("=== RIFT GUIDE ===")
	# The shared test only needs the chapter's public duck-typed API.  Keeping a
	# Node type here avoids a transient global-class-cache failure while another
	# task rebuilds the rift chapter; the scene is still the real one.
	var rift: Node = (load(RIFT_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(rift)
	get_tree().current_scene = rift
	await _wait_process(6)
	var guide: DlcGuide = await _wait_for_guide(rift, 12000)
	_check(guide != null, "rift auto-creates the shared guide")
	if guide == null:
		await _cleanup()
		return
	_check(guide.is_open(), "rift guide opens at level start")
	_check(get_tree().paused, "rift guide pauses the tree")
	var reveal: UiReveal = guide.get_reveal()
	_check(reveal != null, "rift guide uses the shared UiReveal")
	# RiftGuide (rift_workshop) supplies its own three-page set after the
	# 2026-11-26 rework: corridor, phase bridge, double mirror.
	var page_count: int = guide.get_page_count()
	_check(page_count == 3, "rift guide has 3 pages", str(page_count))
	_check(guide.get_page_indicator_text() == "1 / %d" % page_count,
		"rift page indicator starts at 1 / N", guide.get_page_indicator_text())
	_check_demo(guide, "rift_inversion")
	await _wait_seconds(0.4)
	_check(guide.get_demo_frame() > 0, "rift page 1 demo is playing",
		"frame=%d" % guide.get_demo_frame())
	if reveal != null:
		_check(not reveal.is_animating(), "rift open reveal ends while paused")
		_check(_near(reveal.get_panel_scale(), 1.0), "rift panel settles at 1x")
	_press_f_now()
	_check(guide.get_page_index() == 1, "rift F advances to page 2")
	await _wait_page_transition(guide)
	_check(guide.get_demo_frame() == 0, "rift page 2 demo restarts at frame 0",
		"frame=%d" % guide.get_demo_frame())
	_check_demo(guide, "rift_bridge")
	await _wait_seconds(0.4)
	_check(guide.get_demo_frame() > 0, "rift page 2 demo is playing",
		"frame=%d" % guide.get_demo_frame())
	_press_f_now()
	_check(guide.get_page_index() == 2, "rift F advances to page 3")
	await _wait_page_transition(guide)
	_check(guide.get_title_text() == "双面镜",
		"rift page 3 title is 双面镜", guide.get_title_text())
	_check(guide.get_body_text()
		== "双面镜有三形态，金、青面盘护着核心。\n第二形态起面盘被光灵锚定，先熄光灵，\n六秒内用异相攻击击碎；核心有时限。",
		"rift page 3 body teaches the double mirror", guide.get_body_text())
	_check(guide.get_key_text() == "先熄锚定光灵，六秒内碎面盘，再打核心。",
		"rift page 3 key is the natural mirror sentence", guide.get_key_text())
	_check(not guide.get_key_text().contains("[img]")
		and not guide.get_key_text().contains("{"),
		"rift page 3 get_key_text is plain", guide.get_key_text())
	_check(guide.get_footer_rich_text().contains("[img=16x16]"),
		"rift footer renders the F keycap", guide.get_footer_rich_text())
	_check(guide.get_demo_frame() == 0, "rift page 3 demo restarts at frame 0",
		"frame=%d" % guide.get_demo_frame())
	_check_demo(guide, "rift_mirror")
	await _wait_seconds(0.4)
	_check(guide.get_demo_frame() > 0, "rift page 3 demo is playing",
		"frame=%d" % guide.get_demo_frame())
	_check(guide.get_page_index() == page_count - 1,
		"page 3 is the last rift page", "page=%d" % guide.get_page_index())
	_check(guide.get_footer_text() == "F 关闭 · 长按空格 跳过",
		"last rift page footer says F closes", guide.get_footer_text())
	_press_f_now()
	_check(not guide.is_open(), "F on the last page closes the rift guide")
	_check(not get_tree().paused, "rift guide close unpauses the tree")
	if reveal != null:
		_check(reveal.is_close_animating(), "rift F close starts the exit tween")
		await _wait_seconds(0.16)
		_check(not reveal.is_root_visible(), "rift guide hides after the exit fade")
	_check(guide.get_open_count() == 1, "rift guide opened exactly once",
		str(guide.get_open_count()))
	var x_before: float = rift.get_player().global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(14)
	Input.action_release(&"move_right")
	await _wait_physics(2)
	_check(rift.get_player().global_position.x > x_before + 2.0,
		"player can move after closing the rift guide",
		"x=%.2f" % rift.get_player().global_position.x)
	await _cleanup()
