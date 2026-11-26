extends Node

## 640x360 live-viewport evidence for the base-story page footers and the DLC
## guide's 0.12 s page crossfade.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://scripts/ui/tests/capture_base_prompts.tscn
##
## Saves screenshots/base_prompts_20261127/:
##   l1_opening_waiting.png        L1 opening page waiting for F
##   l2_echo_bubble.png            L2 watcher echo bubble waiting for F
##   l3_cinematic_dialogue.png     L3 cinematic bubble waiting for F
##   dlc_guide_transition_mid.png  DLC guide page flip, content alpha < 1
##   dlc_guide_transition_after.png DLC guide settled on the next page
##
## Every shot uses the real scene state.  Character/guide placement is reached
## through the level's existing setup helpers; no gameplay or layout is changed.

const OUT_DIR: String = "res://screenshots/base_prompts_20261127"
const L1_SCENE: String = "res://scenes/level_01.tscn"
const L2_SCENE: String = "res://scenes/level_02.tscn"
const L3_SCENE: String = "res://scenes/level_03.tscn"
const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"

var _saved: Array[String] = []
var _level: Node = null


func _ready() -> void:
	await get_tree().process_frame
	await _capture_l1()
	await _capture_l2()
	await _capture_l3()
	await _capture_dlc_guide()
	print("BASE_PROMPTS_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0 if _saved.size() >= 5 else 1)


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


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	_saved.append(name)
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _push_key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_f() -> void:
	_push_key(KEY_F, true)
	_push_key(KEY_F, false)


func _load(path: String, no_menu: bool = false) -> Node:
	_level = (load(path) as PackedScene).instantiate()
	if no_menu:
		_level.set("enable_start_menu", false)
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	get_tree().paused = false
	await _wait_process(8)
	return _level


func _cleanup() -> void:
	DemoAudio.stop_world()
	get_tree().paused = false
	get_tree().current_scene = null
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
	_level = null
	await _wait_process(8)


func _capture_l1() -> void:
	print("=== L1 OPENING WAITING PAGE ===")
	var level: Node = await _load(L1_SCENE, true)
	var opening: Node = level.call("get_opening")
	var reached: bool = await _wait_until(func() -> bool:
		var echo: Node = opening.call("get_dialogue_echo")
		return (
			String(opening.call("get_phase_name")) == "DIALOGUE"
			and echo != null
			and bool(echo.call("is_dialogue_open"))
		), 14.0)
	if not reached:
		print("CAPTURE_FAIL l1 did not reach its waiting page")
		await _cleanup()
		return
	var echo: Node = opening.call("get_dialogue_echo")
	var revealed: bool = await _wait_until(func() -> bool:
		return int(echo.call("get_revealed_count")) \
			>= String(echo.call("get_full_page_text")).length(), 8.0)
	if not revealed or not bool(opening.call("is_prompt_footer_visible")):
		print("CAPTURE_FAIL l1 footer not visible")
		await _cleanup()
		return
	await _wait_seconds(0.25)
	await _save("l1_opening_waiting.png")
	await _cleanup()


func _capture_l2() -> void:
	print("=== L2 ECHO BUBBLE ===")
	MechanicTips.mark_seen("core_carry")
	MechanicTips.mark_seen("relay_link")
	var level: Node = await _load(L2_SCENE)
	await _wait_seconds(0.6)
	var echo: Node = level.call("get_start_stele")
	if echo == null or not bool(echo.call("open_dialogue")):
		print("CAPTURE_FAIL l2 did not open its bubble")
		await _cleanup()
		return
	var revealed: bool = await _wait_until(func() -> bool:
		return int(echo.call("get_revealed_count")) \
			>= String(echo.call("get_full_page_text")).length(), 8.0)
	if not revealed or not bool(echo.call("is_prompt_footer_visible")):
		print("CAPTURE_FAIL l2 footer not visible")
		await _cleanup()
		return
	await _wait_seconds(0.25)
	await _save("l2_echo_bubble.png")
	echo.call("close_dialogue")
	await _cleanup()


func _capture_l3() -> void:
	print("=== L3 CINEMATIC DIALOGUE ===")
	var level: Node = await _load(L3_SCENE)
	level.call("debug_setup_pre_teaching", 2250.0)
	await _wait_process(4)
	var guard: Node = level.call("get_guard")
	guard.call("restore_waiting_rubble", level.call("get_guard_spawn"))
	await _wait_process(2)
	level.call("_start_cinematic")
	var cine: Node = level.call("get_cine")
	var reached: bool = await _wait_until(func() -> bool:
		return (
			String(cine.call("get_phase_name")) == "DIALOGUE"
			and bool(cine.call("is_bubble_visible"))
		), 14.0)
	if not reached:
		print("CAPTURE_FAIL l3 did not reach its dialogue")
		await _cleanup()
		return
	var revealed: bool = await _wait_until(func() -> bool:
		return String(cine.call("get_body_text")).length() \
			>= String(cine.call("get_full_page_text")).length(), 8.0)
	if not revealed or not bool(cine.call("is_prompt_footer_visible")):
		print("CAPTURE_FAIL l3 footer not visible")
		await _cleanup()
		return
	await _wait_seconds(0.25)
	await _save("l3_cinematic_dialogue.png")
	cine.call("abort")
	await _cleanup()


func _capture_dlc_guide() -> void:
	print("=== DLC GUIDE PAGE FLIP ===")
	var level: Node = await _load(TRIAL_SCENE)
	var guide: Node = null
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 12000:
		guide = level.call("get_intro_guide") as Node
		if guide != null and bool(guide.call("is_open")):
			break
		await get_tree().process_frame
	if guide == null or not bool(guide.call("is_open")):
		print("CAPTURE_FAIL dlc guide did not open")
		await _cleanup()
		return
	# Let the panel reveal finish and the demo reach a readable frame.
	await _wait_seconds(0.6)
	_tap_f()
	# 5 frames lands near the middle of the 0.06 s fade-out on the local
	# 120 Hz window; the logged alpha below is the actual captured state.
	await _wait_process(5)
	await _save("dlc_guide_transition_mid.png")
	print("MID alpha=%.3f transitioning=%s page=%d" % [
		float(guide.call("get_content_alpha")),
		str(guide.call("is_page_transitioning")),
		int(guide.call("get_page_index")),
	])
	await _wait_seconds(0.16)
	await _save("dlc_guide_transition_after.png")
	print("AFTER alpha=%.3f transitioning=%s page=%d indicator=%s" % [
		float(guide.call("get_content_alpha")),
		str(guide.call("is_page_transitioning")),
		int(guide.call("get_page_index")),
		String(guide.call("get_page_indicator_text")),
	])
	await _cleanup()
