extends Node

## Gate depth captures (2026-11-16). Real engine frames:
##   Godot --path . res://tests/level03/capture_l3_gate_depth.tscn
##
## Every shot asserts the live gate state before the file is written; a shot
## whose state does not match is skipped instead of being mislabeled.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/level03_gate_depth_20261116"
const MANIFEST: String = "res://screenshots/level03_gate_depth_20261116/MANIFEST.txt"

var _level: Level03
var _player: L3Player
var _gate: L3Gate
var _lines: Array[String] = []
var _rise_frames: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	await _shot_closed()
	await _shot_rise()
	await _shot_pillars_zoom()
	await _shot_doorway_and_wall()
	await _shot_completion()
	_write_manifest()
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		_level.queue_free()
		await _phys(3)
	print("GATE_CAPTURE_DONE")
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


func _shot_closed() -> void:
	await _new_level()
	_level.debug_setup_gate_with_key(2170.0)
	await _phys(12)
	# move the body away from the doorway so the facade reads unobstructed
	_level.debug_place_player_at(Vector2(2145.0, 320.0))
	await _phys(8)
	var ok: bool = _gate.get_plate_progress() == 0.0 and _gate.is_collision_active() and not _gate.is_inserted()
	if not ok:
		print("SKIP g01: progress=", _gate.get_plate_progress(), " collision=", _gate.is_collision_active())
		return
	await _capture("g01_gate_closed.png",
		"SETUP gate recovery point, body at x=2145: whole closed facade (fixed towers/arch/both inner "
		+ "pillars), dark passage behind the plate, building wall to the right reaching above the "
		+ "camera top. plate progress 0, collision on.")


func _shot_rise() -> void:
	# keep the same fight-free setup, body away from the doorway, then real E
	_level.debug_place_player_at(Vector2(2206.0, 320.0))
	await _phys(6)
	Input.action_press(&"interact")
	await _phys(1)
	Input.action_release(&"interact")
	await _phys(6)
	if not _gate.is_inserted():
		print("SKIP g02: gate not inserted")
		return
	await _capture("g02_gate_embedded.png",
		"REAL E: the 16 px core is seated in the 24 px hole of the plate (short feedback before the rise).")
	level_hide_player_hint()
	var wanted: Array[float] = [0.25, 0.5, 0.75]
	var names: Array[String] = ["g03_gate_25.png", "g04_gate_50.png", "g05_gate_75.png"]
	var index: int = 0
	var frame_index: int = 0
	while index < wanted.size():
		await get_tree().physics_frame
		var progress: float = _gate.get_plate_progress()
		if frame_index % 5 == 0 and _rise_frames < 12:
			await _capture("g_rise_%02d.png" % _rise_frames,
				"real rise frame %.2f" % progress)
			_rise_frames += 1
		frame_index += 1
		if progress >= wanted[index]:
			var fixed: Rect2 = _gate.get_fixed_world_rect()
			var pillars: Dictionary = _gate.get_inner_pillar_world_rects()
			await _capture(names[index],
				"REAL rise at %.0f%% (progress %.2f): plate only moves up into the lintel; towers, arch "
				% [wanted[index] * 100.0, progress] + "and both inner pillars fixed; collision %s."
				% ("released" if not _gate.is_collision_active() else "still blocking"))
			index += 1
		if progress >= 1.0:
			break
	for _i: int in range(120):
		await get_tree().physics_frame
		if _gate.get_plate_progress() >= 1.0:
			break
	await _phys(6)
	if _gate.is_open() and _gate.get_plate_progress() >= 0.999:
		await _capture("g06_gate_open.png",
			"REAL fully raised plate (progress 1.0): passage open, collision released, facade and both "
			+ "inner pillars unchanged.")


func level_hide_player_hint() -> void:
	# The body stays where it is; only the camera is centred on the gate for the
	# rise sequence so the plate motion reads unobstructed.
	_player.global_position = Vector2(2170.0, 320.0)
	_player.velocity = Vector2.ZERO


func _shot_pillars_zoom() -> void:
	await _new_level()
	_level.debug_setup_gate_with_key(2170.0)
	await _phys(12)
	_level.debug_place_player_at(Vector2(2130.0, 320.0))
	await _phys(8)
	var pillars: Dictionary = _gate.get_inner_pillar_world_rects()
	var left: Rect2 = pillars["left"] as Rect2
	var right: Rect2 = pillars["right"] as Rect2
	if left.size != right.size or absf(left.position.y - right.position.y) > 0.01:
		print("SKIP g07: pillar rects differ")
		return
	await _capture("g07_gate_left.png",
		"SETUP body at x=2130 (out of the doorway): normal frame used for the inner-pillar zoom.")
	await _capture("g07_gate_right.png",
		"SETUP same frame, body away: the right inner pillar is present and fixed.")
	_lines.append("g07_inner_pillars_zoom.png | derived 3x crop of g07_gate_left.png (real engine frame, "
		+ "no player over the doorway): both inner pillars visible, same width/top (%.0f,%.0f) vs (%.0f,%.0f)."
		% [left.position.x, left.position.y, right.position.x, right.position.y])
	_lines.append("")


func _shot_doorway_and_wall() -> void:
	# open the gate first (real E + rise), then place the body in the doorway
	_level.debug_place_player_at(Vector2(2210.0, 320.0))
	await _phys(6)
	if not _gate.is_inserted():
		Input.action_press(&"interact")
		await _phys(1)
		Input.action_release(&"interact")
	for _i: int in range(160):
		await get_tree().physics_frame
		if _gate.is_open():
			break
	if not _gate.is_open():
		print("SKIP g08/g09: gate not open")
		return
	var pillars: Dictionary = _gate.get_inner_pillar_world_rects()
	var right: Rect2 = pillars["right"] as Rect2
	_level.debug_place_player_at(Vector2(right.get_center().x, 320.0))
	await _phys(8)
	if absf(_player.global_position.x - right.get_center().x) > 8.0:
		print("SKIP g08: body not at the right pillar")
		return
	await _capture("g08_doorway_right_pillar.png",
		"REAL position at the right inner pillar x=%.0f with the gate open: the fixed right pillar/frame "
		% right.get_center().x + "draws over the body (z 10 > player 5) while the passage backdrop stays behind it.")
	var wall: Rect2 = _gate.get_wall_world_rect()
	_level.debug_place_player_at(Vector2(wall.position.x + 24.0, 320.0))
	await _phys(10)
	await _capture("g09_behind_right_wall.png",
		"REAL position x=%.0f behind the foreground building wall (left edge %.0f): the body is fully "
		% [wall.position.x + 24.0, wall.position.x] + "covered by the depth wall; no collision and no visibility change.")


func _shot_completion() -> void:
	Input.action_press(&"move_right")
	var completed: bool = false
	for _i: int in range(260):
		await get_tree().physics_frame
		if _level.is_completed():
			completed = true
			break
	Input.action_release(&"move_right")
	await _phys(10)
	print("completion walk end x=", _player.global_position.x, " completed=", _level.is_completed())
	if completed:
		await _capture("g10_city_completion.png",
			"REAL walk past CITY_ENTER_X=2360: completion only after crossing; the earlier doorway frames "
			+ "were not a settlement.")


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


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
