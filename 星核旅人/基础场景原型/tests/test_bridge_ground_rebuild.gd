extends Node

## Focused checks for the formal L1 ground swap and the rebuilt L2 structure.
## Run:
##   Godot --headless --path . res://tests/test_bridge_ground_rebuild.tscn

const L1: PackedScene = preload("res://scenes/level_01.tscn")
const L2: PackedScene = preload("res://scenes/level_02.tscn")

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_l1()
	await _test_l2_initial()
	await _test_l2_stable_restore()
	_write_log()
	print("BRIDGE_GROUND_REBUILD_TEST pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("CHECK FAIL: " + text)


func _test_l1() -> void:
	var level: Level01 = L1.instantiate() as Level01
	level.set("enable_start_menu", false)
	level.set("intro_max_duration", 0.05)
	add_child(level)
	await _frames(20)
	var expected: Dictionary = {
		"World/StartGround": [Vector2(-160, 300), Vector2(1024, 64), "l1_start_1024x64.png"],
		"World/HighPlatform": [Vector2(864, 220), Vector2(336, 144), "l1_high_336x144.png"],
		"World/FarBank": [Vector2(1456, 300), Vector2(496, 64), "l1_far_496x64.png"],
	}
	for path_value: String in expected.keys():
		var block: LevelTerrainBlock = level.get_node_or_null(path_value) as LevelTerrainBlock
		var spec: Array = expected[path_value]
		_check(block != null, "%s exists" % path_value)
		if block == null:
			continue
		_check(block.get_collision_top_left().is_equal_approx(spec[0]), "%s collision top-left unchanged" % path_value)
		_check(block.get_collision_size().is_equal_approx(spec[1]), "%s collision size unchanged" % path_value)
		_check(not bool(block.get("draw_visual")), "%s old atlas visual off" % path_value)
		var visual: Sprite2D = block.get_node_or_null("GroundVisual") as Sprite2D
		_check(
			visual != null and visual.texture != null and visual.texture.get_size().is_equal_approx(spec[1]),
			"%s new ground texture size" % path_value
		)
		_check(
			visual != null and not visual.centered and visual.scale.is_equal_approx(Vector2.ONE)
			and visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"%s new ground nearest/scale1/top-left" % path_value
		)
	var broken: Sprite2D = level.get_node("World/Decorations/DoricBrokenMidway") as Sprite2D
	var base: Sprite2D = level.get_node("World/Decorations/DoricBaseMidway") as Sprite2D
	var tall: Sprite2D = level.get_node("World/Decorations/DoricTallEntry") as Sprite2D
	_check(
		tall != null and tall.texture != null
		and String(tall.texture.resource_path).ends_with("doric_column_tall_basesquare.png"),
		"L1 tall column uses square-foot art"
	)
	_check(
		broken != null and broken.texture != null
		and String(broken.texture.resource_path).ends_with("doric_column_broken_basesquare.png"),
		"L1 broken column uses square-foot art"
	)
	_check(
		base != null and base.texture != null
		and String(base.texture.resource_path).ends_with("doric_column_base_basesquare.png"),
		"L1 column base uses square-foot art"
	)
	level.queue_free()
	await _frames(5)


func _test_l2_initial() -> void:
	var level: Level02 = L2.instantiate() as Level02
	add_child(level)
	await _frames(12)
	await _physics_frames(4)

	_check(level.get_node_or_null("Guard") == null, "L2 has no Guard node")
	_check(level.get_player().get_script().resource_path.ends_with("scripts/player.gd"), "L2 uses the base player script")
	var bays: Array[StarCoreBayInteractable] = level.get_bays()
	_check(bays.size() == 4, "L2 has four authored bays")
	_check(level.find_children("*", "StarCoreCarrier", true, false).size() == 1, "L2 has exactly one star-core carrier")
	_check(level.get_node("Bays/StartBay").is_locked(), "start bay begins locked")
	_check(level.get_relay_bay().is_open_empty(), "relay bay begins empty")
	_check(level.get_linked_bay().is_open_empty(), "linked bay begins empty")
	_check(level.get_final_bay().is_open_empty(), "final bay begins empty")
	_check(not level.get_rune_field().is_activated(), "rune begins INACTIVE")
	_check(level.get_link().get_bay() == level.get_linked_bay(), "link bay NodePath resolves")
	_check(level.get_link().get_field() == level.get_rune_field(), "link field NodePath resolves")
	_check(level.get_camera().limit_right == 1792, "camera limit_right 1792")
	_check(level.get_camera().limit_left == 0, "camera limit_left 0")
	_check(level.get_player().world_right == 1786.0, "player world_right 1786")
	_check(level.get_player().global_position.is_equal_approx(Vector2(36, 320)), "player initial spawn safe")

	var ground: StaticBody2D = level.get_node("TerrainBody") as StaticBody2D
	var shape: CollisionShape2D = ground.get_node("CollisionShape2D") as CollisionShape2D
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	_check(rect != null and rect.size == Vector2(1792, 40), "ground collision 1792x40")
	_check(ground.global_position.y - rect.size.y * 0.5 == 320.0, "ground top at y320")

	var entry: Level02Block = level.get_node("CorridorEntryPier") as Level02Block
	_check(entry.get_block_rect().end.y == 300.0, "corridor pier bottom 300 (20 px throat)")
	var wall: Level02Block = level.get_node("LinkedWall") as Level02Block
	_check(wall.get_block_rect().position.y == 240.0, "linked wall top 240 (80 px above ground)")
	_check(wall.get_block_rect().end.y == 300.0, "linked wall bottom 300 (20 px throat)")
	var lip: Level02Block = level.get_node("LinkedLip") as Level02Block
	_check(lip.get_block_rect().end.x == wall.get_block_rect().position.x, "lip meets wall")

	level.queue_free()
	await _frames(5)


func _test_l2_stable_restore() -> void:
	var level: Level02 = L2.instantiate() as Level02
	add_child(level)
	await _frames(10)

	level.debug_restore_stage(1, true)
	await _physics_frames(3)
	_check(level.get_stable_stage() == 1, "relay stable stage set")
	_check(level.get_relay_bay().is_locked(), "relay checkpoint restores core in relay bay")
	_check(level.get_relay_bay().has_record(), "relay bay keeps record")
	_check(not level.get_rune_field().is_activated(), "relay stage leaves rune inactive")
	_check(level.get_player().global_position.is_equal_approx(Vector2(400, 320)), "relay respawn safe")

	level.debug_restore_stage(2, false)
	await _physics_frames(3)
	_check(level.get_stable_stage() == 2, "linked stable stage set")
	_check(level.get_linked_bay().is_locked(), "linked checkpoint restores core in linked bay")
	_check(level.get_linked_bay().has_record(), "linked bay keeps record")
	_check(level.get_rune_field().is_activated(), "linked checkpoint restores active rune")
	_check(not level.get_rune_field().is_positive(), "linked checkpoint restores record polarity (CYAN)")
	_check(level.get_link().get_record_positive() == false, "link lamp shows recorded CYAN")
	_check(level.get_linked_checkpoint().is_activated(), "linked visual checkpoint active")
	_check(level.get_player().global_position.is_equal_approx(Vector2(830, 320)), "linked respawn safe")

	level.queue_free()
	await _frames(5)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("res://tests/logs/bridge_ground_rebuild_test.log", FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
