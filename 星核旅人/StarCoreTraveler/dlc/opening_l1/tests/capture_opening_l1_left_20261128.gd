extends Node

## Real-time 640x360 capture of the 2026-11-28 left-edge opening.
## Run WITHOUT --headless so the viewport renders:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/opening_l1/tests/capture_opening_l1_left_20261128.tscn
##
## Saves exactly three live frames to screenshots/opening_l1_20261128/:
##   01_enter_from_left.png   player walking in from the left edge
##   02_walk_to_stele.png     player stopped beside the stele
##   03_echo_dialogue.png     first echo page on the real GuideEcho
##
## The harness only disables the title menu; every frame is the real film at
## the stated play time.  It also checks the staging while it runs.

const LEVEL_SCENE: String = "res://scenes/level_01.tscn"
const OUT_DIR: String = "res://screenshots/opening_l1_20261128"

var _level: Level01 = null
var _opening: OpeningCinematic = null
var _player: PrototypePlayer = null
var _stele_x: float = 0.0
var _checks: int = 0
var _failures: Array[String] = []


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
	_player = _level.get_player()
	var stele: GuideEcho = _level.get_narrative_stele()
	if _opening == null or _player == null or stele == null:
		print("CAPTURE_FAIL missing opening/player/stele")
		get_tree().quit(1)
		return
	_stele_x = stele.global_position.x
	print("CAPTURE opening duration=%.2f stele_x=%.1f start_x=%.1f" % [
		_opening.get_duration(), _stele_x, _player.global_position.x
	])
	_check(_player.global_position.x <= -8.0,
		"start is off-screen left", str(_player.global_position.x))
	_check(_stele_x - _player.global_position.x >= 200.0,
		"start is >=200 px left of the stele",
		"%.1f" % (_stele_x - _player.global_position.x))

	await _wait_until(5.05)
	var enter_a: float = _player.global_position.x
	await _wait_until(5.75)
	var enter_b: float = _player.global_position.x
	_check(enter_b > enter_a + 10.0,
		"entry x increases (left to right)",
		"%.1f -> %.1f" % [enter_a, enter_b])
	_check(_player.get_facing() == 1,
		"entry faces right toward the stele", str(_player.get_facing()))
	await _wait_until(5.35)
	await _save("01_enter_from_left.png")

	await _wait_until(8.90)
	_check(_player.global_position.x > 278.0
		and _player.global_position.x < 298.0,
		"walk stops in front of the stele",
		str(_player.global_position.x))
	await _save("02_walk_to_stele.png")

	var echo: GuideEcho = _opening.get_dialogue_echo()
	var page_deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < page_deadline:
		if echo != null and echo.is_dialogue_open() \
				and echo.get_page_index() == 0 \
				and echo.get_revealed_count() >= echo.get_full_page_text().length():
			break
		await get_tree().process_frame
	_check(echo != null and echo.is_dialogue_open(),
		"first echo page is open", str(echo != null))
	await _save("03_echo_dialogue.png")

	_print_result()
	_level.queue_free()
	await _wait_process(4)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _print_result() -> void:
	print("OPENING_L1_LEFT_CAPTURE checks=%d failures=%d"
		% [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)


func _wait_until(at_time: float) -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if _opening == null or not _opening.is_active():
			break
		if _opening.get_elapsed() >= at_time:
			break
		await get_tree().process_frame


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(file_name))
	print("SHOT %s size=%dx%d error=%d" % [
		file_name, image.get_width(), image.get_height(), error
	])
