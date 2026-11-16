extends Node

## Gate-inset captures (2026-11-16 layout change, i* set).
##   Godot --path . res://tests/level03/capture_l3_gate_depth_inset.tscn
##
## SETUP: the gate recovery point with the carried core (defeated guard, real
## key). E embedding, the ~1 s rise and the walk through the new gate are real
## input. Each shot asserts the live gate/player state before writing.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/level03_gate_inset_20261116"
const MANIFEST: String = "res://screenshots/level03_gate_inset_20261116/MANIFEST_I.txt"

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
	var gx: float = _gate.global_position.x
	_level.debug_setup_gate_with_key(gx - 180.0)
	await _phys(12)
	if _gate.is_inserted() or _gate.is_open():
		print("SKIP: gate not in the closed recovery state")
		get_tree().quit(1)
		return
	# 1) normal camera: new gate inside the existing building, old place empty
	await _capture("i01_gate_in_wall_640.png",
		"SETUP closed gate at the new layout x=%.0f inside the building face (left end %.0f, "
		% [gx, _gate.BUILDING_WORLD_LEFT]
		+ "front to 2612); old gate centre %.0f is empty ground." % (gx - 160.0))
	# 2) real E, real rise at 25 / 50 / 75 %, then fully open
	_level.debug_place_player_at(Vector2(gx - 10.0, 320.0))
	await _phys(6)
	Input.action_press(&"interact")
	await _phys(1)
	Input.action_release(&"interact")
	await _phys(6)
	if not _gate.is_inserted():
		print("SKIP: insert failed")
		get_tree().quit(1)
		return
	_level.debug_place_player_at(Vector2(gx - 180.0, 320.0))
	var wanted: Array[float] = [0.25, 0.5, 0.75]
	var names: Array[String] = ["i03_rise_25.png", "i04_rise_50.png", "i05_rise_75.png"]
	var index: int = 0
	for _i: int in range(240):
		await get_tree().physics_frame
		var progress: float = _gate.get_plate_progress()
		if index < wanted.size() and progress >= wanted[index]:
			await _capture(names[index],
				"REAL rise %.0f%% (progress %.2f): the plate rises inside the building face, the "
				% [wanted[index] * 100.0, progress]
				+ "socket and the dark doorway stay visible.")
			index += 1
		if progress >= 1.0:
			break
	await _phys(6)
	if not (_gate.is_open() and _gate.get_plate_progress() >= 0.999):
		print("SKIP: gate not open")
		get_tree().quit(1)
		return
	await _capture("i06_gate_open_full.png",
		"REAL fully raised plate: passage open, collision released (barrier layer %d)."
		% _gate.get_barrier_layer())
	# 3) continuous real walk: old wall start -> new gate -> right side -> completion
	_level.debug_place_player_at(Vector2(2292.0, 320.0))
	await _phys(8)
	var targets: Array[float] = [2292.0, 2340.0, gx, gx + 25.0, gx + 65.0, gx + 78.0]
	var labels: Array[String] = ["i10_old_wall_start_2292.png", "i11_before_gate_2340.png",
		"i12_gate_mid.png", "i13_right_edge.png", "i14_right_tower.png",
		"i15_behind_wall.png"]
	var readings: Array[String] = [
		"at the old wall position: body fully visible in front of the building face",
		"before the new gate: body fully visible",
		"in the new doorway: body fully visible",
		"the gate's right pillar starts covering the body",
		"behind the gate's right tower",
		"behind the right wall segment",
	]
	var next: int = 0
	var frame_index: int = 0
	Input.action_press(&"move_right")
	for _i: int in range(400):
		await get_tree().physics_frame
		var x: float = _player.global_position.x
		if frame_index % 4 == 0 and _walk_frames < 60:
			var walk_cover: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(x))
			print("COVER i_walk_%02d x=%.0f coverage=%.2f" % [_walk_frames, x, walk_cover])
			await _capture("i_walk_%02d.png" % _walk_frames,
				"real walk frame x=%.0f, foreground coverage %.2f" % [x, walk_cover])
			_walk_frames += 1
		frame_index += 1
		if next < targets.size() and x >= targets[next]:
			var cover: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(x))
			await _capture(labels[next],
				"REAL walk x=%.0f: gate open, body %.0f, foreground coverage %.2f (%.0f%%). "
				% [x, _player.global_position.y, cover, cover * 100.0] + readings[next])
			_report_rects(labels[next])
			next += 1
		if x >= _level.get_city_enter_x() + 10.0:
			break
	Input.action_release(&"move_right")
	await _phys(10)
	if _level.is_completed():
		await _capture("i16_city_completion.png",
			"REAL walk past the new completion line %.0f (x=%.0f): completion only after the "
			% [_level.get_city_enter_x(), _player.global_position.x]
			+ "body is behind the gate and the wall segment, not on the door.")
	else:
		print("WARN: completion did not trigger")
	_write_manifest()
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		_level.queue_free()
		await _phys(3)
	print("GATE_INSET_CAPTURE_DONE")
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


## Printed with every labelled walk shot: live body rect next to the foreground
## pieces, so the occlusion claims can be checked numerically.
func _report_rects(label: String) -> void:
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var body: Rect2 = Rect2(_player.global_position + Vector2(-6.0, -30.0), Vector2(12.0, 30.0))
	var lip: Rect2 = _gate.get_right_edge_world_rect()
	var wall_fg: Rect2 = Rect2()
	var pieces: Dictionary = _gate.get_wall_pieces()
	for key: String in pieces.keys():
		if pieces[key].get("foreground", false):
			wall_fg = pieces[key]["rect"]
	print("RECT %s body=%s lip=%s wall_fg=%s cover=%.2f cam=%s" % [
		label, _to_screen(canvas, body), _to_screen(canvas, lip),
		_to_screen(canvas, wall_fg),
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
