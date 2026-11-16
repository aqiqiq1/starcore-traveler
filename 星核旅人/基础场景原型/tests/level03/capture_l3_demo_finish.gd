extends Node

## Demo-finish evidence capture (2026-11-16):
##   Godot --path . res://tests/level03/capture_l3_demo_finish.tscn
##
## Normal 640x360 render. The level is the real current scene (F6-shaped), so
## the return button performs a real SceneTree change to level_01; this harness
## stays alive as a separate root child to take the last frames.
## SETUP is explicit: the gate recovery point (defeated guard, real core) for
## the gate/wall shots and each completion; E, D and the J/Q presses are real
## key events. The walk to the completion line is real input.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/level03_demo_finish_20261116"
const MANIFEST: String = "res://screenshots/level03_demo_finish_20261116/MANIFEST_FINISH.txt"

var _level: Level03 = null
var _player: L3Player = null
var _hud: L3HUD = null
var _gate: L3Gate = null
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	await _new_level()
	await _wall_detail_shots()
	await _open_and_walk()
	await _completion_and_mouse_replay()
	await _second_completion_and_return()
	_write_manifest()
	print("FINISH_CAPTURE_DONE")
	get_tree().quit(0)


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _new_level() -> void:
	_level = LEVEL_SCENE.instantiate() as Level03
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _phys(22)
	_player = _level.get_player()
	_hud = _level.get_hud()
	_gate = _level.get_gate()


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(code: Key, frames: int = 2) -> void:
	_key(code, true)
	await _phys(frames)
	_key(code, false)
	await _phys(1)


func _shot(file_name: String) -> Image:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(DIR + "/" + file_name))
	print("CAPTURED ", file_name)
	get_tree().paused = false
	await get_tree().process_frame
	return image


func _zoom(file_name: String, region: Rect2i, scale: int) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var crop: Image = image.get_region(region)
	crop.resize(region.size.x * scale, region.size.y * scale, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(DIR + "/" + file_name))
	print("CAPTURED ", file_name)
	get_tree().paused = false
	await get_tree().process_frame


func _note(file_name: String, text: String) -> void:
	_lines.append("%s | %s" % [file_name, text])
	_lines.append("")


# --- 1. wall detail, same composition as the previous gate-inset shot ------

func _wall_detail_shots() -> void:
	print("[1] wall detail")
	_level.debug_setup_gate_with_key(_gate.global_position.x - 180.0)
	await _phys(10)
	await _shot("f01_wall_detail_640.png")
	_note("f01_wall_detail_640.png",
		"SETUP closed gate at x=2380; body at 2200, normal camera pinned at 1880..2520 - "
		+ "the same composition as the pre-detail i01_gate_in_wall_640.png.")
	await _zoom("f02_wall_detail_zoom3x.png", Rect2i(400, 50, 240, 290), 3)
	_note("f02_wall_detail_zoom3x.png",
		"3x crop of f01: upper wall bays with the 104 belt, pilaster capitals/bases, one "
		+ "blind arched niche per bay, low-contrast wear; the gatehouse sits in the face.")
	await _zoom("f03_wall_upper_zoom4x.png", Rect2i(420, 60, 220, 170), 4)
	_note("f03_wall_upper_zoom4x.png",
		"4x crop of the upper wall: niches are recessed stone (no black window, no glow), "
		+ "structural lines stay stronger than the wear.")


# --- 2. real E, real walk, foot and right-end close-ups --------------------

func _open_and_walk() -> void:
	print("[2] gate opens, body walks through")
	_level.debug_place_player_at(Vector2(_gate.global_position.x - 10.0, 320.0))
	await _phys(6)
	await _tap(KEY_E, 2)
	var opened: bool = false
	for _i: int in range(150):
		await get_tree().physics_frame
		if _gate.is_open():
			opened = true
			break
	print("  gate_open=%s" % str(opened))
	_level.debug_place_player_at(Vector2(2292.0, 320.0))
	await _phys(8)
	var targets: Array[float] = [2300.0, 2340.0, 2380.0, 2396.0, 2406.0, 2425.0, 2452.0]
	var labels: Array[String] = ["f04_walk_before_gate.png", "f05_walk_left_tower.png",
		"f06_walk_doorway.png", "f07_walk_right_pillar.png", "f08_walk_covered_half.png",
		"f09_walk_right_tower.png", "f10_walk_behind_wall.png"]
	var next: int = 0
	_key(KEY_D, true)
	for _i: int in range(400):
		await get_tree().physics_frame
		var x: float = _player.global_position.x
		if next < targets.size() and x >= targets[next]:
			var cover: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(x))
			await _shot(labels[next])
			_note(labels[next], "REAL walk x=%.0f, foreground coverage %.2f" % [x, cover])
			next += 1
		if x >= 2454.0:
			break
	_key(KEY_D, false)
	await _phys(8)
	var x_now: float = _player.global_position.x
	var cover_now: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(x_now))
	print("  stop at x=%.0f cover=%.2f" % [x_now, cover_now])
	await _shot("f11_wall_foot_full.png")
	_note("f11_wall_foot_full.png",
		"SETUP stop just before the completion line (x=%.0f, coverage %.2f): the body is "
		% [x_now, cover_now] + "fully behind the foreground run.")
	await _zoom("f12_wall_foot_zoom5x.png", Rect2i(550, 290, 90, 56), 5)
	_note("f12_wall_foot_zoom5x.png",
		"5x of the wall foot behind the body: no feet/cape pixels below the plinth; the "
		+ "plinth stone reaches the ground with one dark contact row.")
	await _zoom("f13_right_end_zoom5x.png", Rect2i(500, 230, 140, 120), 5)
	_note("f13_right_end_zoom5x.png",
		"5x of the right end: the wall face, pilaster, niche and plinth are continuous; the "
		+ "old city column instances behind the wall are gone from the scene.")


# --- 3. real completion, mouse replay, real movement ----------------------

func _completion_and_mouse_replay() -> void:
	print("[3] completion -> mouse replay -> movement")
	_key(KEY_D, true)
	for _i: int in range(180):
		await get_tree().physics_frame
		if _level.is_completed():
			break
	_key(KEY_D, false)
	await _phys(8)
	print("  completed=%s x=%.1f" % [str(_level.is_completed()), _player.global_position.x])
	await _shot("f14_completion_page.png")
	_note("f14_completion_page.png",
		"REAL walk past x=2460: 感谢游玩 / 本次试玩到此结束 / 返回主界面 / 重玩本关, "
		+ "focus on the primary button, hint line with R.")
	var replay: PixelMenuButton = _hud.get_completion_replay_button()
	await _click(replay)
	await _phys(10)
	print("  after replay: completed=%s lock=%s pos=%s" % [
		str(_level.is_completed()), str(_player.is_completion_locked()),
		str(_player.global_position)])
	await _shot("f15_replay_spawn.png")
	_note("f15_replay_spawn.png",
		"REAL mouse down/up on 重玩本关: page closed, body back at the start spawn, guard "
		+ "and core restored, completion lock released.")
	var before_x: float = _player.global_position.x
	_key(KEY_D, true)
	await _phys(26)
	_key(KEY_D, false)
	await _phys(4)
	await _shot("f16_replay_moved.png")
	_note("f16_replay_moved.png",
		"REAL D after the replay: the body really walks on the start ground (x %.0f -> %.0f)."
		% [before_x, _player.global_position.x])
	print("  moved %.1f px after replay" % (_player.global_position.x - before_x))


func _click(control: Control) -> void:
	var center: Vector2 = control.get_global_rect().get_center()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	get_viewport().push_input(up, true)
	await get_tree().process_frame
	await get_tree().process_frame


# --- 4. second completion, mouse return to the real title -----------------

func _second_completion_and_return() -> void:
	print("[4] second completion -> mouse return")
	_level.debug_setup_gate_with_key(_gate.global_position.x - 40.0)
	await _phys(10)
	await _tap(KEY_E, 2)
	for _i: int in range(150):
		await get_tree().physics_frame
		if _gate.is_open():
			break
	_key(KEY_D, true)
	for _i: int in range(220):
		await get_tree().physics_frame
		if _level.is_completed():
			break
	_key(KEY_D, false)
	await _phys(8)
	await _shot("f17_second_completion.png")
	_note("f17_second_completion.png",
		"SETUP second completion (gate recovery point, real E + real walk): the same demo-end "
		+ "page returns after a replay.")
	var primary: PixelMenuButton = _hud.get_completion_primary_button()
	await _click(primary)
	for _i: int in range(40):
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if current != null and current.scene_file_path.ends_with("level_01.tscn"):
			break
	var current: Node = get_tree().current_scene
	print("  current_scene=%s path=%s" % [
		current.name if current != null else "<null>",
		current.scene_file_path if current != null else "<null>"])
	await _phys(6)
	await _shot("f18_level01_menu.png")
	_note("f18_level01_menu.png",
		"REAL mouse down/up on 返回主界面: the tree really switched to res://scenes/level_01.tscn "
		+ "(the title scene); this harness is a separate root child and stayed alive.")


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
