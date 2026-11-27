extends Node

## Real-time 640x360 capture of the reworked level-01 opening.
## Run WITHOUT --headless so the viewport renders:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/opening_l1/tests/capture_opening_l1.tscn
##
## Each image is the live viewport at the stated actual play time; no debug
## poses, no hidden scene and no separately drawn stage. The harness only
## disables the title menu and waits for the real film.

const LEVEL_SCENE: String = "res://scenes/level_01.tscn"
const OUT_DIR: String = "res://screenshots/opening_l1_20261127"

var _level: Level01 = null
var _opening: OpeningCinematic = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var packed: PackedScene = load(LEVEL_SCENE) as PackedScene
	if packed == null:
		print("CAPTURE_FAIL load level_01")
		get_tree().quit(1)
		return
	_level = packed.instantiate() as Level01
	_level.enable_start_menu = false
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(4)
	_opening = _level.get_opening()
	if _opening == null:
		print("CAPTURE_FAIL no opening")
		get_tree().quit(1)
		return
	print("CAPTURE opening duration=%.2f" % _opening.get_duration())

	await _wait_and_save("01_black_shake.png", 1.20)
	await _wait_and_save("02_enter_from_right.png", 5.55)
	await _wait_and_save("03_touch_stele.png", 9.40)
	await _wait_and_save("09_zoom_touch.png", 9.52)
	await _wait_and_save("07_doubt_question.png", 9.95)
	await _wait_and_save("04_echo_page1.png", 12.05)
	await _wait_and_save("08_echo_manifest.png", 12.60)
	var echo: GuideEcho = _opening.get_dialogue_echo()
	if echo != null:
		await _wait_page_ready(echo)
		_press_f()
		await _wait_process(3)
		await _wait_page_ready(echo)
		await _save("04b_echo_page2_after_f.png")
		# Finish the remaining pages with the same real F route.
		while echo.is_dialogue_open():
			await _wait_page_ready(echo)
			_press_f()
			await _wait_process(3)
	await _wait_and_save("05_star_core_handoff.png", 18.85)
	await _wait_for_finish()
	await _wait_process(8)
	await _save("06_back_to_gameplay.png")
	await _save("10_letterbox_playback.png")

	print("CAPTURE_OPENING_L1 done")
	_level.queue_free()
	await _wait_process(4)
	get_tree().quit(0)


func _wait_and_save(file_name: String, at_time: float) -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if _opening == null or not _opening.is_active():
			break
		if _opening.get_elapsed() >= at_time:
			break
		await get_tree().process_frame
	await _save(file_name)


func _wait_page_ready(echo: GuideEcho) -> void:
	var deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		if echo == null or not echo.is_dialogue_open():
			return
		if echo.get_revealed_count() >= echo.get_full_page_text().length():
			return
		await get_tree().process_frame


func _press_f() -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_F
	down.keycode = KEY_F
	down.pressed = true
	get_viewport().push_input(down)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_F
	up.keycode = KEY_F
	up.pressed = false
	get_viewport().push_input(up)


func _wait_for_finish() -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if _level == null or not _level.is_intro_active():
			return
		await get_tree().process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(file_name))
	print("SHOT %s size=%dx%d error=%d" % [file_name, image.get_width(), image.get_height(), error])


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
