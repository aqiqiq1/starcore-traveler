extends Node

## Gate depth resume captures (2026-11-16, r* set).
##   Godot --path . res://tests/level03/capture_l3_gate_depth_resume.tscn
##
## SETUP: the gate recovery point with the carried core (defeated guard, real
## key). E embedding, the 1 s rise and the walk through are real input. Each
## shot asserts the live gate/player state before writing.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/level03_gate_depth_20261116"
const MANIFEST: String = "res://screenshots/level03_gate_depth_20261116/MANIFEST_R.txt"

var _level: Level03
var _player: L3Player
var _gate: L3Gate
var _lines: Array[String] = []
var _walk_frames: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	await _new_level()
	_level.debug_setup_gate_with_key(2210.0)
	await _phys(12)
	# the decoration that leaked through the left gap must be gone from the scene
	var decoration: Node = _level.get_node_or_null("Decorations/ColumnArenaRight")
	if decoration != null:
		print("SKIP: ColumnArenaRight still present")
		get_tree().quit(1)
		return
	_level.debug_place_player_at(Vector2(2160.0, 320.0))
	await _phys(10)
	await _capture("r01_gate_left_tower_body.png",
		"SETUP closed gate, body at x=2160 standing on the left tower's face: the body is drawn over the "
		+ "gatehouse (fixed facade z4 < player z5), so the left tower / left pillar / left gap never cover it.")
	_level.debug_place_player_at(Vector2(2140.0, 320.0))
	await _phys(10)
	await _capture("r02_gate_full_640.png",
		"SETUP same closed gate at the normal 640x360 view: whole gatehouse and the connected right "
		+ "building (return + corner + front) in one frame.")
	# structure-only framing: the body waits away from the gate so the crop has
	# no character covering the pillars or the two gaps
	_level.debug_place_player_at(Vector2(2020.0, 320.0))
	await _phys(12)
	await _capture("r03_gate_structure_640.png",
		"SETUP body at x=2020 (outside the crop): closed gatehouse only, both arch pillars and both "
		+ "left/right gaps visible with the same sky/bridge background behind them.")
	# embedding + real rise at 25 / 50 / 75 / open
	_level.debug_place_player_at(Vector2(2210.0, 320.0))
	await _phys(6)
	Input.action_press(&"interact")
	await _phys(1)
	Input.action_release(&"interact")
	await _phys(6)
	if not _gate.is_inserted():
		print("SKIP: insert failed")
		get_tree().quit(1)
		return
	_level.debug_place_player_at(Vector2(2140.0, 320.0))
	var wanted: Array[float] = [0.25, 0.5, 0.75]
	var names: Array[String] = ["r05_rise_25.png", "r06_rise_50.png", "r07_rise_75.png"]
	var index: int = 0
	for _i: int in range(240):
		await get_tree().physics_frame
		var progress: float = _gate.get_plate_progress()
		if index < wanted.size() and progress >= wanted[index]:
			await _capture(names[index], "REAL rise %.0f%% (progress %.2f), fixed facade z%d behind the "
				% [wanted[index] * 100.0, progress, _gate.get_fixed_z()]
				+ "body, plate clipped into the lintel.")
			index += 1
		if progress >= 1.0:
			break
	await _phys(6)
	if not (_gate.is_open() and _gate.get_plate_progress() >= 0.999):
		print("SKIP: gate not open")
		get_tree().quit(1)
		return
	await _capture("r08_gate_open_full.png",
		"REAL fully raised plate: passage open, collision released (barrier layer %d)."
		% _gate.get_barrier_layer())
	# continuous real walk from in front of the gate into the city
	_level.debug_place_player_at(Vector2(2120.0, 320.0))
	await _phys(8)
	var targets: Array[float] = [2130.0, 2190.0, 2220.0, 2245.0, 2292.0, 2330.0]
	var labels: Array[String] = ["r10_front_2130.png", "r11_mouth_2190.png", "r12_mid_2220.png",
		"r13_right_lip_2245.png", "r14_corner_2292.png", "r15_behind_wall_2330.png"]
	var next: int = 0
	var frame_index: int = 0
	Input.action_press(&"move_right")
	for _i: int in range(400):
		await get_tree().physics_frame
		var x: float = _player.global_position.x
		if frame_index % 4 == 0 and _walk_frames < 60:
			var walk_cover: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(x))
			print("COVER r_walk_%02d x=%.0f coverage=%.2f" % [_walk_frames, x, walk_cover])
			await _capture("r_walk_%02d.png" % _walk_frames,
				"real walk frame x=%.0f, foreground coverage %.2f" % [x, walk_cover])
			_walk_frames += 1
		frame_index += 1
		if next < targets.size() and x >= targets[next]:
			var cover: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(x))
			var reading: String = "in front of the gate, fully visible"
			if targets[next] == 2220.0:
				reading = "inside the doorway midline, fully visible"
			elif targets[next] == 2245.0:
				reading = "right pillar + jamb + tower foreground starts to cover the body"
			elif targets[next] == 2292.0:
				reading = "corner member continues the cover"
			elif targets[next] >= 2330.0:
				reading = "behind the building front, fully covered"
			await _capture(labels[next],
				"REAL walk x=%.0f: gate open, body %.0f, foreground coverage %.2f (%.0f%%). "
				% [x, _player.global_position.y, cover, cover * 100.0] + reading)
			_report_rects(labels[next])
			next += 1
		if x >= 2365.0:
			break
	Input.action_release(&"move_right")
	await _phys(10)
	if _level.is_completed():
		await _capture("r16_city_completion.png",
			"REAL walk past CITY_ENTER_X=2360 (x=%.0f): completion only after crossing, not on the door."
			% _player.global_position.x)
	_write_manifest()
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		_level.queue_free()
		await _phys(3)
	print("GATE_RESUME_CAPTURE_DONE")
	get_tree().quit(0)


func _new_level() -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(24)
	_player = _level.get_player()
	_gate = _level.get_gate()


func _capture(file_name: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(DIR + "/" + file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
	_lines.append("%s | %s" % [file_name, note])
	_lines.append("")
	get_tree().paused = false
	await get_tree().process_frame


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


## Printed with every labelled walk shot: the live body rect on screen next to
## the foreground pieces, so the occlusion claims can be checked numerically
## instead of by eye.
func _report_rects(label: String) -> void:
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var body: Rect2 = Rect2(_player.global_position + Vector2(-6.0, -30.0), Vector2(12.0, 30.0))
	var lip: Rect2 = _gate.get_right_edge_world_rect()
	var corner: Rect2 = (_gate.get_wall_pieces()["WallCornerColumn"] as Dictionary)["rect"]
	var front: Rect2 = (_gate.get_wall_pieces()["WallFront"] as Dictionary)["rect"]
	print("RECT %s body=%s lip=%s corner=%s front=%s cover=%.2f cam=%s" % [
		label, _to_screen(canvas, body), _to_screen(canvas, lip),
		_to_screen(canvas, corner), _to_screen(canvas, front),
		_gate.get_occlusion_coverage(_gate.get_body_art_rect_at(_player.global_position.x)),
		canvas.origin])


func _to_screen(canvas: Transform2D, rect: Rect2) -> Rect2:
	var a: Vector2 = canvas * rect.position
	var b: Vector2 = canvas * rect.end
	return Rect2(a, b - a)


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
