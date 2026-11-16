extends Node

## Gate-focused depth test (2026-11-16). Run headless:
##   Godot --headless --path . res://tests/level03/test_l3_gate_depth.tscn

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")

var _fails: Array[String] = []
var _passes: int = 0
var _level: Level03
var _player: L3Player
var _gate: L3Gate


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _sec_layers()
	await _sec_rise()
	await _sec_pause_and_reset()
	await _sec_blocked_and_completion()
	print("GATE_RESULT pass=%d fail=%d" % [_passes, _fails.size()])
	for failure: String in _fails:
		print("FAIL: ", failure)
	if _fails.is_empty():
		print("GATE_OK")
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
		for _i: int in range(4):
			await get_tree().process_frame
	get_tree().quit(0 if _fails.is_empty() else 1)


func _check(ok: bool, label: String) -> bool:
	if ok:
		_passes += 1
	else:
		_fails.append(label)
		print("  ! ", label)
	return ok


func _new_level() -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(18)


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


## Live gate x, so no test position is hard-coded to the old layout.
func _gx() -> float:
	return _level.get_gate().global_position.x


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _phys(1)
	Input.action_release(action)
	await get_tree().physics_frame


# --- 1. layered facade, both inner pillars, non-colliding tall wall --------

func _sec_layers() -> void:
	print("[1] layers")
	await _new_level()
	_level.debug_setup_gate_with_key(_gx() - 10.0)
	await _phys(10)
	_gate = _level.get_gate()
	_player = _level.get_player()
	var textures: Dictionary = _gate.get_texture_paths()
	_check(String(textures["fixed"]).ends_with("assets/level03_gate_depth/gate_fixed.png"),
		"the facade uses the derived fixed layer, not the whole closed PNG")
	_check(String(textures["plate_closed"]).ends_with("gate_plate_closed.png")
		and String(textures["plate_filled"]).ends_with("gate_plate_filled.png"),
		"the movable plate has its own closed and filled layers")
	_check(String(textures["passage"]).ends_with("gate_passage.png"),
		"the dark passage silhouette is a separate backdrop layer")
	_check(_gate.get_layer_z("Passage") < _player.z_index,
		"the passage and the clipped plate layer sit behind the player (z %d < %d)" % [
			_gate.get_layer_z("Passage"), _player.z_index])
	_check(_gate.get_layer_z("Passage") > _gate.get_layer_z("WallFront"),
		"the doorway backdrop is in front of the building's back face, so the wall cannot show through")
	var plate_node: Node = _gate.get_node_or_null("Passage/DoorPlate")
	_check(plate_node != null, "the moving plate is clipped by the doorway aperture layer")
	var passage_node: CanvasItem = _gate.get_node_or_null("Passage") as CanvasItem
	_check(passage_node != null
		and passage_node.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW,
		"the dark passage is drawn as well as clipping the plate (not a bare mask)")
	_check(_gate.get_fixed_z() < _player.z_index,
		"the whole gatehouse sits BEHIND the player (z %d < player %d)" % [
			_gate.get_fixed_z(), _player.z_index])
	_check(_gate.get_layer_z("RightForeground") == 6,
		"only the right half of the gatehouse comes forward (z 6)")
	_check(_gate.get_barrier_layer() == 1, "the door barrier is on layer 1 while closed")
	var pieces: Dictionary = _gate.get_wall_pieces()
	var return_side: Dictionary = pieces.get("WallReturnSide", {})
	var corner: Dictionary = pieces.get("WallCornerColumn", {})
	var front: Dictionary = pieces.get("WallFront", {})
	var wall_fg: Dictionary = pieces.get("WallRightForeground", {})
	_check(int(return_side.get("z", -1)) == 3 and int(corner.get("z", -1)) == 3
		and int(front.get("z", -1)) == 3,
		"the building face the body walks in front of stays behind the player (z 3)")
	_check(return_side.get("foreground", true) == false
		and corner.get("foreground", true) == false
		and front.get("foreground", true) == false,
		"the back face pieces are not foreground")
	_check(int(wall_fg.get("z", -1)) == 7 and wall_fg.get("foreground", false) == true,
		"the right wall segment from the gate's right edge is the only foreground wall (z 7)")
	var return_rect: Rect2 = return_side.get("rect", Rect2())
	var corner_rect: Rect2 = corner.get("rect", Rect2())
	var front_rect: Rect2 = front.get("rect", Rect2())
	var wall_fg_rect: Rect2 = wall_fg.get("rect", Rect2())
	_check(absf(return_rect.position.x - _gate.BUILDING_WORLD_LEFT) < 0.5,
		"the building keeps its world left end (%.0f)" % return_rect.position.x)
	_check(absf(front_rect.end.x - (_gate.BUILDING_WORLD_LEFT + 320.0)) < 0.5,
		"the building keeps its world right end (%.0f)" % front_rect.end.x)
	_check(absf(wall_fg_rect.position.x - (_gate.global_position.x + 72.0)) < 0.5,
		"the foreground wall starts at the gate's right tower edge (%.0f)" % wall_fg_rect.position.x)
	_check(absf(corner_rect.position.x - return_rect.end.x) < 0.5
		and absf(front_rect.position.x - corner_rect.end.x) < 0.5,
		"return, corner and front are connected without a gap")
	_check(return_rect.position.y <= 0.0 and front_rect.position.y <= 0.0,
		"the building continues above the 360 camera top (%.0f)" % front_rect.position.y)
	var left_of_gate: bool = false
	for key: String in pieces.keys():
		var piece: Dictionary = pieces[key] as Dictionary
		if piece.get("foreground", false) != true:
			continue
		var rect: Rect2 = piece.get("rect", Rect2())
		if rect.position.x < _gate.global_position.x - 72.0 + 88.0 - 0.01:
			left_of_gate = true
	_check(not left_of_gate, "no foreground piece reaches the gate's left half")
	_check(not _gate.has_wall_collision(), "the foreground building has no blocking collision")
	var band_world_y: float = _gate.global_position.y + _gate.IMAGE_TOP + 37.0
	_check(absf(L3GateDepthWall.LOWER_TOP_WORLD_Y - band_world_y) < 0.01,
		"the wall's cornice sits on the gate's real tower-top band (world %.0f)" % band_world_y)
	_check(absf(L3GateDepthWall.CORNICE_TOP_WORLD_Y - (band_world_y - 4.0)) < 0.01,
		"the cornice band is 4 px tall above that line (world %.0f)" % L3GateDepthWall.CORNICE_TOP_WORLD_Y)
	_check(absf(L3GateDepthWall.SETBACK - 16.0) < 0.01,
		"the upper storey is set back 16 px from the lower storey")
	var right_fg: Rect2 = _gate.get_right_foreground_world_rect()
	var pillars_now: Dictionary = _gate.get_inner_pillar_world_rects()
	var right_pillar: Rect2 = pillars_now["right"] as Rect2
	_check(absf(right_fg.position.x - right_pillar.position.x) < 0.5
		and right_fg.end.x >= right_pillar.end.x,
		"the foreground starts at the real right pillar inner edge and covers it (%.0f..%.0f)"
		% [right_fg.position.x, right_fg.end.x])
	_check(right_fg.end.x >= _gate.global_position.x + 72.0,
		"it reaches the right tower's outer edge (%.0f)" % right_fg.end.x)
	# real run in front of the body: no gap, and never on the gate's left half
	var fg: Array[Rect2] = _gate.get_foreground_world_rects()
	_check(fg.size() == 2,
		"the foreground is the gate's right half plus the right wall segment (%d)" % fg.size())
	var continuous: bool = true
	var gap_at: float = -1.0
	for index: int in range(1, fg.size()):
		if fg[index].position.x > fg[index - 1].end.x + 0.01:
			continuous = false
			gap_at = fg[index].position.x
	_check(continuous, "foreground pieces form one continuous run (gap at %.0f)" % gap_at)
	_check(fg[0].position.x >= _gate.global_position.x - 72.0 + 88.0 - 0.01,
		"no foreground piece reaches the gate's left half (leftmost %.0f)" % fg[0].position.x)
	# measured coverage of the real body art, not just z values
	var gx: float = _gx()
	var cover_front: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(gx))
	var cover_lip: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(gx + 25.0))
	var cover_tower: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(gx + 40.0))
	var cover_corner: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(gx + 74.0))
	var cover_wall: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(gx + 110.0))
	_check(cover_front <= 0.001,
		"the body is fully readable in the doorway midline (coverage %.2f)" % cover_front)
	_check(cover_lip > 0.35 and cover_lip < 0.95,
		"the right pillar's inner edge only partly covers the body (coverage %.2f)" % cover_lip)
	_check(cover_tower > 0.99, "past the inner edge the body is behind the tower (coverage %.2f)"
		% cover_tower)
	_check(cover_corner > 0.99 and cover_wall > 0.999,
		"the right tower and the wall segment keep it covered (%.2f / %.2f)" % [cover_corner, cover_wall])
	var cover_old: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(gx - 160.0))
	_check(cover_old == 0.0, "the old gate position is empty of gate and occlusion (%.2f)" % cover_old)
	_check(not _gate.get_fixed_world_rect().has_point(Vector2(gx - 160.0, 300.0)),
		"no gatehouse is left at the old layout position")
	var never_reappears: bool = true
	var worst: float = 0.0
	var previous: float = -1.0
	for step: int in range(140):
		var x: float = gx - 160.0 + float(step) * 2.0
		var coverage: float = _gate.get_occlusion_coverage(_gate.get_body_art_rect_at(x))
		if previous >= 0.0 and coverage < previous - 0.001:
			never_reappears = false
		if x >= gx + 25.0:
			worst = minf(worst, coverage) if worst > 0.0 else coverage
		previous = coverage
	_check(never_reappears,
		"coverage never drops from the old wall position to the new completion line")
	# the LEFT half must never occlude the body, even with the left gap rear
	# lining baked into the fixed layer (that lining is z4, behind the player)
	var cover_left_tower: float = _gate.get_occlusion_coverage(
		_gate.get_body_art_rect_at(gx - 220.0))
	var cover_left_gap: float = _gate.get_occlusion_coverage(
		_gate.get_body_art_rect_at(gx - 194.0))
	_check(cover_left_tower == 0.0 and cover_left_gap == 0.0,
		"left tower and left gap never occlude the body (%.2f / %.2f)" % [
			cover_left_tower, cover_left_gap])
	_check(worst >= cover_lip - 0.001,
		"after the inner edge the body is never more visible again (%.2f)" % worst)
	var pillars: Dictionary = _gate.get_inner_pillar_world_rects()
	var left: Rect2 = pillars["left"] as Rect2
	var right: Rect2 = pillars["right"] as Rect2
	_check(left.size == right.size, "the two inner pillars have the same size")
	_check(absf(left.position.y - right.position.y) < 0.01, "the two inner pillars share the same top")
	_check(absf((left.get_center().x + right.get_center().x) * 0.5 - _gate.global_position.x) <= 2.0,
		"the inner pillars are centred on the doorway")
	_check(_gate.get_plate_progress() == 0.0 and _gate.is_collision_active(),
		"the gate starts closed with the plate down and the collision on")


# --- 2. real E, plate rise, fixed frame, collision release, one signal ------

func _sec_rise() -> void:
	print("[2] rise")
	var inserts: Array[int] = [0]
	var opens: Array[int] = [0]
	_gate.insert_started.connect(func() -> void: inserts[0] += 1)
	_gate.door_opened.connect(func() -> void: opens[0] += 1)
	var fixed_before: Rect2 = _gate.get_fixed_world_rect()
	var pillars_before: Dictionary = _gate.get_inner_pillar_world_rects()
	var plate_start: Rect2 = _gate.get_plate_world_rect()
	var socket_start: Vector2 = _gate.get_socket_world_position()
	await _press(&"interact")
	await _phys(4)
	_check(_gate.is_inserted(), "real E embeds the core")
	_check(inserts[0] == 1, "insert_started fired once")
	var filled: bool = String(_gate.get_texture_paths()["plate_current"]).ends_with("gate_plate_filled.png")
	_check(filled, "the embedded plate shows the filled texture")
	# repeated E must not re-trigger anything
	await _press(&"interact")
	await _phys(4)
	_check(inserts[0] == 1, "a second E does not reinsert the core")
	var samples: Array[float] = []
	var plate_ys: Array[float] = []
	var fixed_moved: bool = false
	var pillar_moved: bool = false
	var opened_at: int = -1
	for _i: int in range(240):
		await get_tree().physics_frame
		samples.append(_gate.get_plate_progress())
		plate_ys.append(_gate.get_plate_world_rect().position.y)
		if _gate.get_fixed_world_rect() != fixed_before:
			fixed_moved = true
		var pillars_now: Dictionary = _gate.get_inner_pillar_world_rects()
		if (pillars_now["left"] as Rect2) != (pillars_before["left"] as Rect2) \
				or (pillars_now["right"] as Rect2) != (pillars_before["right"] as Rect2):
			pillar_moved = true
		if opened_at < 0 and _gate.is_open():
			opened_at = _i
		if _gate.get_plate_progress() >= 1.0:
			break
	await _phys(6)
	_check(not fixed_moved, "the fixed facade never moves during the rise")
	_check(not pillar_moved, "both inner pillars never move during the rise")
	var monotonic: bool = true
	for index: int in range(1, samples.size()):
		if samples[index] < samples[index - 1]:
			monotonic = false
	_check(monotonic, "the plate progress is monotonic")
	_check(samples.size() > 0 and samples[-1] >= 0.999, "the plate reaches the fully raised state")
	var plate_end: Rect2 = _gate.get_plate_world_rect()
	_check(plate_end.position.y < plate_start.position.y - 60.0,
		"the plate really travels up (%.0f -> %.0f)" % [plate_start.position.y, plate_end.position.y])
	_check(plate_end.end.y < fixed_before.position.y + 80.0,
		"the raised plate is hidden behind the lintel band")
	_check(socket_start.y - _gate.get_socket_world_position().y > 60.0,
		"the socket follows the moving plate")
	_check(opened_at >= 0, "door_opened fires during the rise")
	_check(opens[0] == 1, "door_opened fires exactly once")
	_check(not _gate.is_collision_active(), "the door collision is released after the passable height")


# --- 3. pause freezes plate and collision; R restores everything -----------

func _sec_pause_and_reset() -> void:
	print("[3] pause/reset")
	await _new_level()
	_level.debug_setup_gate_with_key(_gx() - 10.0)
	await _phys(10)
	_gate = _level.get_gate()
	_player = _level.get_player()
	await _press(&"interact")
	# wait until the plate is clearly moving but not passable yet
	for _i: int in range(120):
		await get_tree().physics_frame
		if _gate.get_plate_progress() > 0.2:
			break
	var before_pause: float = _gate.get_plate_progress()
	get_tree().paused = true
	await _phys(30)
	_check(absf(_gate.get_plate_progress() - before_pause) < 0.001,
		"pause freezes the plate progress (%.2f)" % before_pause)
	_check(_gate.is_collision_active(), "pause keeps the collision state in sync")
	get_tree().paused = false
	await _phys(12)
	_check(_gate.get_plate_progress() > before_pause, "the rise continues after unpause")
	# reset restores the initial plate, hole, collision and state
	_gate.reset_state()
	await _phys(4)
	_check(_gate.get_plate_progress() == 0.0, "reset puts the plate back down")
	_check(_gate.is_collision_active(), "reset restores the closed collision")
	_check(not _gate.is_inserted() and not _gate.is_open(), "reset clears the inserted/open state")
	_check(String(_gate.get_texture_paths()["plate_current"]).ends_with("gate_plate_closed.png"),
		"reset shows the empty closed plate again")
	_check(_gate.get_socket_world_position().distance_to(
		_gate.global_position + _gate.SOCKET_LOCAL) < 0.01, "reset restores the empty socket position")
	await _new_level()
	_level.debug_setup_gate_with_key(_gx() - 10.0)
	await _phys(10)
	_gate = _level.get_gate()
	await _press(&"interact")
	await _phys(4)
	_check(_gate.is_inserted(), "a fresh setup can embed the core once more after the gate reset")


# --- 4. closed blocks, open passes, completion only past the real line -----

func _sec_blocked_and_completion() -> void:
	print("[4] passage")
	await _new_level()
	_level.debug_setup_gate_with_key(_gx() - 14.0)
	await _phys(10)
	_gate = _level.get_gate()
	_player = _level.get_player()
	# closed: walk right into the barrier
	Input.action_press(&"move_right")
	await _phys(70)
	Input.action_release(&"move_right")
	await _phys(6)
	_check(_player.global_position.x < _gate.global_position.x + 1.0,
		"a closed gate really blocks the body (%.0f)" % _player.global_position.x)
	_check(not _level.is_completed(), "walking into the closed gate does not complete")
	# open it for real and walk through
	_level.debug_place_player_at(Vector2(_gx() - 10.0, 320.0))
	await _phys(6)
	await _press(&"interact")
	for _i: int in range(200):
		await get_tree().physics_frame
		if _gate.is_open():
			break
	await _phys(8)
	_check(_gate.is_open(), "the gate opens for the passage check")
	Input.action_press(&"move_right")
	for _i: int in range(90):
		await get_tree().physics_frame
		if _player.global_position.x > _gx() + 40.0:
			break
	Input.action_release(&"move_right")
	await _phys(6)
	_check(_player.global_position.x > _gx() + 40.0,
		"the body walks through the open doorway (%.0f)"
		% _player.global_position.x)
	_check(not _level.is_completed(),
		"walking through the door but before the completion line is not a completion")
	Input.action_press(&"move_right")
	for _i: int in range(300):
		await get_tree().physics_frame
		if _level.is_completed():
			break
	Input.action_release(&"move_right")
	await _phys(8)
	_check(_level.is_completed(), "completion only after the real walk past CITY_ENTER_X")
	_check(_player.global_position.x >= _level.get_city_enter_x() - 2.0,
		"the completion happened past the real completion line %.0f (%.0f)" % [
			_level.get_city_enter_x(), _player.global_position.x])
	_check(_level.get_city_enter_x() > _gate.global_position.x + 72.0,
		"the completion line stays behind the gate's right edge (%.0f)" % _level.get_city_enter_x())
