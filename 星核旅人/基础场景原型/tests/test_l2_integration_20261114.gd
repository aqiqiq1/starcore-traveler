extends Node

## Focused formal L2 integration smoke: scene wiring, special RID registration,
## v2 gate sheet opt-in, GuideEcho migration and L1 opt-out. No old suites.

const L2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const L1_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LOG_PATH: String = "res://tests/logs/l2_integration_smoke_20261114.log"

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_l2()
	await _test_l1()
	_write_log()
	print("L2_INTEGRATION_SMOKE pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _test_l2() -> void:
	var level: Level02 = L2_SCENE.instantiate() as Level02
	add_child(level)
	await _frames(8)
	await _physics(4)
	_check(level.is_active(), "formal L2 is active")
	_check(level.get_special_force_body_count() == 4, "formal L2 registers exactly four special bodies")
	for node_name: String in ["ConductiveRoof", "LinkedWall", "LinkedLip", "ReturnPlatform"]:
		var body: StaticBody2D = level.get_node_or_null(NodePath(node_name)) as StaticBody2D
		_check(body != null and body.collision_layer == 1, "%s exists and stays layer 1" % node_name)
		_check(body != null and level.is_special_force_body(body), "%s is registered for the force exception" % node_name)
	var roof: StaticBody2D = level.get_node_or_null("ConductiveRoof") as StaticBody2D
	var roof_shape: CollisionShape2D = roof.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check(roof != null and roof_shape != null and (roof_shape.shape as RectangleShape2D).size == Vector2(256, 32), "roof collision is 256x32")
	var ret: StaticBody2D = level.get_node_or_null("ReturnPlatform") as StaticBody2D
	var ret_shape: CollisionShape2D = ret.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check(ret != null and ret.position == Vector2(1264, 280) and ret_shape != null and (ret_shape.shape as RectangleShape2D).size == Vector2(48, 12), "return platform is 48x12 at (1264,280)")
	_check(level.get_node_or_null("CorridorEntryPier") == null, "old corridor entry pier is removed")
	_check(level.get_node_or_null("BeamA") == null, "old corridor beams are removed")

	var guide: GuideEcho = level.get_start_stele()
	_check(guide != null and guide is GuideEcho, "L2 start stele migrated to GuideEcho")
	_check(level.get_start_guide() == guide, "get_start_guide matches get_start_stele")
	_check(guide.get_page_count() == 4, "L2 GuideEcho has four pages")
	_check(guide.pages[2].contains("护符力") and not guide.pages[2].contains("10px"), "L2 page 3 describes full conductive stone")
	_check(guide.near_range == 56.0 and is_equal_approx(guide.get_leave_range(), 66.0), "L2 GuideEcho keeps F 56/66")
	_check(is_equal_approx(guide.get_manifest_range(), 96.0) and is_equal_approx(guide.get_hide_range(), 112.0), "L2 GuideEcho keeps 96/112")
	_check(guide.get_foot_anchor() == Vector2(24, 60) and guide.get_sprite_offset() == Vector2(-24, -60) and is_equal_approx(guide.get_projection_lift(), 18.0), "L2 GuideEcho keeps foot/offset/18px lift")
	_check(get_tree().get_nodes_in_group(&"tutorial_stele").is_empty(), "L2 has no old TutorialStele group")
	_check(get_tree().get_nodes_in_group(&"guide_echo").size() == 1, "L2 has exactly one GuideEcho")

	var exit: LevelExit = level.get_exit()
	_check(exit.gate_portal_fx_enabled, "L2 exit opts into v2 gate FX")
	var fx: Sprite2D = exit.get_gate_fx_sprite()
	_check(fx != null and fx.hframes == 8, "L2 gate FX is 8-frame")
	_check(fx != null and fx.texture != null and Vector2i(fx.texture.get_size()) == Vector2i(608, 100), "L2 gate sheet is 608x100")
	_check(exit.get_gate_fx_frames() == 8 and is_equal_approx(exit.get_gate_fx_fps(), 8.0), "L2 gate constants are 8/8.0")
	_check(exit.get_state_texture().resource_path.ends_with("exit_open.png"), "L2 gate frame remains original exit_open")

	var field: Dictionary = level.compute_field(Vector2(560, 253), Vector2(560, 312), true, true)
	_check(not bool(field.get("blocked", true)), "player-core ray passes the registered roof")
	var normal: StaticBody2D = StaticBody2D.new()
	normal.position = Vector2(560, 280)
	normal.collision_layer = 1
	normal.collision_mask = 0
	var normal_shape: CollisionShape2D = CollisionShape2D.new()
	var normal_rect: RectangleShape2D = RectangleShape2D.new()
	normal_rect.size = Vector2(8, 8)
	normal_shape.shape = normal_rect
	normal.add_child(normal_shape)
	level.add_child(normal)
	await _physics(2)
	var blocked: Dictionary = level.compute_field(Vector2(560, 253), Vector2(560, 312), true, true)
	_check(bool(blocked.get("blocked", false)), "ordinary layer-1 body still blocks the player-core ray")
	normal.queue_free()
	await _physics(2)
	var rune_blocked: bool = bool(
		level.get_rune_field().call(
			"_is_line_blocked", Vector2(1050, 305), level.get_player().get_rid()
		)
	)
	_check(rune_blocked, "RuneStoneField still treats special stone as occlusion")
	_check(level.get_player().collision_mask == 1 and level.get_core().collision_mask in [0, 1], "player/core masks remain normal")
	level.queue_free()
	await _frames(4)


func _test_l1() -> void:
	var level: Level01 = L1_SCENE.instantiate() as Level01
	level.enable_start_menu = false
	add_child(level)
	await _frames(8)
	await _physics(4)
	var first: GuideEcho = level.get_narrative_guide()
	var second: GuideEcho = level.get_mechanism_guide()
	_check(first != null and second != null, "L1 still has two GuideEcho points")
	_check(first.global_position == Vector2(250, 300) and second.global_position == Vector2(735, 300), "L1 guide positions unchanged")
	_check(first.get_page_count() == 3 and second.get_page_count() == 3, "L1 guide pages unchanged")
	_check(first.get_sheet_texture() != null and Vector2i(first.get_sheet_texture().get_size()) == Vector2i(288, 64), "L1 guide uses 288x64 sheet")
	_check(first.get_sheet_texture() == second.get_sheet_texture(), "L1 two points share the same s40 texture")
	_check(first.get_sheet_texture().resource_path.ends_with("guide_echo_idle_6f_s40.png"), "L1 guide texture path is s40")
	_check(first.get_animation_frame_count() == 6 and is_equal_approx(GuideEcho.IDLE_FPS, 4.0), "L1 guide 6 frames at 4 fps")
	_check(first.get_foot_anchor() == Vector2(24, 60) and is_equal_approx(first.get_projection_lift(), 18.0), "L1 guide foot/lift unchanged")
	_check(first.near_range == 56.0 and is_equal_approx(first.get_manifest_range(), 96.0) and is_equal_approx(first.get_hide_range(), 112.0), "L1 guide visibility ranges unchanged")
	_check(not first.has_collision_body() and not second.has_collision_body(), "L1 guides have no collision")
	var l1_exit: LevelExit = level.get_exit()
	_check(not l1_exit.gate_portal_fx_enabled and l1_exit.get_gate_fx_sprite() == null, "L1 exit does not opt into the L2 gate FX")
	level.queue_free()
	await _frames(4)


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("L2 INTEGRATION SMOKE FAIL: " + text)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
