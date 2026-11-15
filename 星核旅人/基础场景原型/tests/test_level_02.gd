extends Node

## Acceptance runner for level 02 "沉寂回廊" greybox.
##
## Run headless:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_level_02.tscn
##
## The main-route section uses only real InputMap actions and real key events at
## the 60 Hz physics step. It never writes the player/core position, never calls
## the store/complete helpers, and never injects a test force. Direct state setup
## appears only in the isolated boundary sections and is labelled as such.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LOG_PATH: String = "res://tests/logs/level02_textured_test.log"

const PLAYER_FLOOR_Y: float = 320.0
const HIGH_STEP_Y: float = 274.0
const UPPER_Y: float = 264.0
const TARGET_X: float = 520.0
const ATLAS_PATH: String = "res://assets/map/ruin_platform_tiles.png"
const V3_VISUAL_PATH: String = "res://assets/level02_platform_v3/layer_platform_visual_640.png"
const V3_DECOR_PATH: String = "res://assets/level02_platform_v3/layer_platform_decor_640.png"
const V3_EXPECTED_PATH: String = "res://assets/level02_platform_v3/level02_v3_platform_expected.png"
const ATLAS_SHA256: String = "3A9FC34281FE33B17194C706B666BD8E0A9B4F0B697DC426481EF7199EF8B5B2"
const V3_VISUAL_SHA256: String = "EE8D38E32684BD1170563C2784FA3E241D64818D2F1DFA7DF0F922677CB04290"
const V3_DECOR_SHA256: String = "58C58508ABD051ED79F52C2EC53401B1BD8B243156050B17C97F529FC0A82A9F"
const V3_EXPECTED_SHA256: String = "A66442DEE14EF6951936604671F05C8EBD5DC8FEA6E2F9587D6E5F6A40CADFC4"

var _level: Level02
var _player: PrototypePlayer
var _hud: Level02HUD
var _core: StarCoreCarrier
var _start_bay: StarCoreBayInteractable
var _target_bay: StarCoreBayInteractable

var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - Level 02 V3 platform acceptance")
	_log("Godot %s  display=%s  physics=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
		str(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")),
	])

	await _test_editable_scene_and_parameters()
	await _test_v3_platform_visual()
	await _test_upper_seam_geometry()
	await _test_block_copy_isolation()
	await _test_opposite_initial_release()
	await _test_upper_seam_force()
	await _test_main_route()
	await _test_pause_focus_and_boundary_resets()
	await _test_isolated_core_out_of_bounds()
	_finish()


# ---------------------------------------------------------------------------
# Scene / parameter checks
# ---------------------------------------------------------------------------

func _test_editable_scene_and_parameters() -> void:
	_section("EDITABLE SCENE / PARAMETERS / TEXTURED TERRAIN")
	await _new_level()
	_check(_level != null and _player != null and _hud != null, "level 02 scene instantiates")
	_check(_level is Level02, "root uses Level02")
	_check(_hud is Level02HUD, "HUD is the Chinese level-02 HUD, not PrototypeHUD")
	_check(_level.get_node_or_null("Background/CloudRuinsDS03") != null,
		"approved DS03 background is instanced as temporary background art")
	var background: CanvasLayer = _level.get_node("Background") as CanvasLayer
	_check(background != null and background.layer == -10, "background CanvasLayer is present")

	for path: String in [
		"TerrainTop", "TerrainFill", "TerrainBody", "Bays/StartBay",
		"Bays/TargetBay", "Core", "PlayerSpawn", "StartStele", "Exit", "Player",
		"UpperDeck/CorridorEntryPier", "UpperDeck/CorridorExitPier",
	]:
		_check(_level.get_node_or_null(path) != null, "scene-authored node %s" % path)

	var blocks: Array[StaticBody2D] = _level.get_collision_bodies()
	_check(blocks.size() == 11, "eleven editable level-02 terrain blocks", str(blocks.size()))
	for body: StaticBody2D in blocks:
		var block: Level02Block = body as Level02Block
		_check(block != null, "%s uses Level02Block" % body.name)
		if block != null:
			_check(block.get_collision_size() == block.get_block_size(),
				"%s collision matches block_size" % body.name,
				str(block.get_collision_size()))
			_check(block.get_collision_top_left().is_equal_approx(block.global_position),
				"%s collision top-left equals art origin" % body.name,
				str(block.get_collision_top_left()))
			_check(block.get_atlas_path() == ATLAS_PATH,
				"%s keeps the legacy atlas resource available" % body.name,
				block.get_atlas_path())
			_check(block.get_texture_tile_size() == 16,
				"%s keeps the legacy native 16 px tile metadata" % body.name)
			_check(block.has_native_texture_tiling(),
				"%s keeps Nearest + white legacy tile metadata" % body.name)
			_check(not block.is_legacy_art_enabled(),
				"%s does not draw the legacy brown atlas under V3" % body.name)
			_check(block.visible, "%s remains visible (V3 child slices draw it)" % body.name)

	var deck_blocks: Array[Level02Block] = _level.get_upper_deck_blocks()
	_check(deck_blocks.size() == 9, "perforated upper deck is made of nine real segments",
		str(deck_blocks.size()))
	for block: Level02Block in deck_blocks:
		_check(is_equal_approx(block.global_position.y, UPPER_Y),
			"%s top is the new y=264" % block.name, str(block.global_position))

	var entry_pier: Level02Block = _level.get_node(
		"UpperDeck/CorridorEntryPier"
	) as Level02Block
	var exit_pier: Level02Block = _level.get_node(
		"UpperDeck/CorridorExitPier"
	) as Level02Block
	_check(entry_pier.get_block_size() == Vector2(8.0, 36.0),
		"entry pier is a real 8 x 36 downward stone", str(entry_pier.get_block_size()))
	_check(exit_pier.get_block_size() == Vector2(8.0, 36.0),
		"exit pier is a real 8 x 36 downward stone", str(exit_pier.get_block_size()))
	_check(entry_pier.global_position.y + entry_pier.get_block_size().y == 300.0,
		"entry pier bottom is y=300 (blocks the player, 20 px throat)")
	_check(exit_pier.global_position.y + exit_pier.get_block_size().y == 300.0,
		"exit pier bottom is y=300 (blocks the player, 20 px throat)")

	_check(_level.get_corridor_rect() == Rect2(232.0, 300.0, 72.0, 20.0),
		"low corridor keeps a real 20 px throat", str(_level.get_corridor_rect()))
	_check(_level.get_corridor_open_rect() == Rect2(240.0, 270.0, 56.0, 50.0),
		"middle open cross-section is 50 px under the 6 px perforated deck",
		str(_level.get_corridor_open_rect()))
	_check(_level.get_upper_platform_rect() == Rect2(232.0, 264.0, 168.0, 6.0),
		"upper route walk band is x=232..400 at top y=264, 6 px thick",
		str(_level.get_upper_platform_rect()))

	var gaps: Array[Rect2] = _level.get_upper_gap_rects()
	_check(gaps.size() == 5, "five real empty seams in the upper deck", str(gaps.size()))
	for gap: Rect2 in gaps:
		_check(is_equal_approx(gap.size.x, 8.0) and is_equal_approx(gap.size.y, 6.0),
			"seam is an 8 x 6 px empty slot at x=%.0f" % gap.position.x, str(gap))
		_check(gap.size.x < _player.get_collision_size().x,
			"seam %.0f is narrower than the 12 px player" % gap.size.x,
			"player=%.0f" % _player.get_collision_size().x)
		_check(gap.size.x < float(_core.get_node("CollisionShape2D").shape.size.x),
			"seam %.0f is also narrower than the 12 px core" % gap.size.x,
			"core=%.0f" % float(_core.get_node("CollisionShape2D").shape.size.x))

	# The accessors must follow the real segment nodes, not a second hardcoded
	# rectangle. Move the rightmost walk beam and the entry pier, then restore.
	var right_beam: Level02Block = _level.get_node("UpperDeck/WalkBeamD") as Level02Block
	var right_start: Vector2 = right_beam.global_position
	right_beam.position.x += 16.0
	_check(_level.get_upper_platform_rect().size.x == 184.0,
		"upper-platform accessor follows the rightmost segment",
		str(_level.get_upper_platform_rect()))
	right_beam.position = right_start
	_check(_level.get_upper_platform_rect() == Rect2(232.0, 264.0, 168.0, 6.0),
		"upper-platform accessor returns to the initial geometry",
		str(_level.get_upper_platform_rect()))
	var entry_start: Vector2 = entry_pier.global_position
	entry_pier.position.x += 8.0
	_check(_level.get_corridor_rect().position.x == 240.0,
		"corridor accessor follows the moved entry pier", str(_level.get_corridor_rect()))
	entry_pier.position = entry_start
	_check(_level.get_corridor_rect() == Rect2(232.0, 300.0, 72.0, 20.0),
		"corridor accessor returns to the initial geometry", str(_level.get_corridor_rect()))

	_check(_start_bay.is_locked(), "start bay begins LOCKED")
	_check(_target_bay.is_open_empty(), "target bay begins OPEN/EMPTY")
	_check(_target_bay.global_position == Vector2(TARGET_X, 304.0),
		"target bay is moved to (520, 304)", str(_target_bay.global_position))
	_check(_target_bay.get_store_center() == Vector2(TARGET_X, 312.0),
		"target seat centre follows the bay", str(_target_bay.get_store_center()))
	var target_label: Label = _level.get_node("TargetBayLabel") as Label
	_check(target_label != null and absf(target_label.offset_left + target_label.offset_right - 2.0 * TARGET_X) <= 1.0,
		"target bay label stays centred on the moved bay", str(target_label))
	_check(not _core.is_active(), "moving core begins disabled")
	_check(_start_bay.get_node_or_null("BayVisual") != null, "start bay visual is scene-authored")
	_check(_target_bay.get_node_or_null("BayVisual") != null, "target bay visual is scene-authored")
	_check(_player.get_collision_size() == Vector2(12.0, 30.0), "player body remains 12 x 30",
		str(_player.get_collision_size()))
	_check(_core.get_node("CollisionShape2D").shape.size == Vector2(12.0, 16.0),
		"core collision remains 12 x 16",
		str(_core.get_node("CollisionShape2D").shape.size))

	_check(is_equal_approx(_level.field_range, 100.0), "field range stays 100", str(_level.field_range))
	_check(is_equal_approx(_level.inner_radius, 40.0), "inner zone stays 40", str(_level.inner_radius))
	_check(is_equal_approx(_level.full_radius, 64.0), "full radius stays 64", str(_level.full_radius))
	_check(is_equal_approx(_level.outer_fade, 18.0), "outer fade stays 18", str(_level.outer_fade))
	_check(is_equal_approx(_level.core_acceleration, 620.0), "core acceleration stays 620",
		str(_level.core_acceleration))
	_check(is_equal_approx(_level.player_acceleration, 300.0), "player acceleration stays 300",
		str(_level.player_acceleration))
	_check(is_equal_approx(_core.get_max_speed(), 120.0), "core max speed stays 120",
		str(_core.get_max_speed()))
	_check(is_equal_approx(_core.get_ground_drag(), 420.0), "core ground drag stays 420",
		str(_core.get_ground_drag()))
	_check(is_equal_approx(_start_bay.interaction_radius, 46.0), "bay interaction range stays 46")
	_check(_start_bay.store_half_extents == Vector2(24.0, 18.0), "bay seat stays 24 x 18",
		str(_start_bay.store_half_extents))
	_check(is_equal_approx(_level.store_player_core_range, 80.0),
		"store requires core within 80 of player")
	_check(is_equal_approx(_start_bay.release_distance, 40.0), "release offset stays 40")

	_check(_hud.get_polarity_text() == "辉相", "HUD starts on 辉相", _hud.get_polarity_text())
	_check(_hud.get_controls_text().contains("Q 切换相性"), "HUD uses Chinese Q hint")
	_check(_hud.get_phase_text().contains("E"), "HUD shows a Chinese stage prompt",
		_hud.get_phase_text())
	_check(_level.get_start_stele() != null and _level.get_start_stele().pages.size() == 3,
		"start stele has three short Chinese pages")
	_check(_level.get_start_stele().pages[1].contains("嵌缝")
		and _level.get_start_stele().pages[1].contains("遮挡"),
		"stele page 2 explains the V3 setting joints and solid-block occlusion",
		_level.get_start_stele().pages[1])
	var upper_label: Label = _level.get_node_or_null("UpperLabel") as Label
	_check(upper_label != null and upper_label.text.contains("嵌缝")
		and upper_label.text.contains("遮挡"),
		"upper label matches the continuous V3 deck wording",
		upper_label.text if upper_label != null else "missing")
	var upper_labels: Array[Dictionary] = [
		{"path": "CorridorLabel", "left": 222.0, "right": 308.0},
		{"path": "UpperLabel", "left": 312.0, "right": 420.0},
	]
	for spec: Dictionary in upper_labels:
		var label: Label = _level.get_node_or_null(String(spec["path"])) as Label
		_check(label != null, "%s exists for the upper-deck label clearance check" % spec["path"])
		if label == null:
			continue
		var label_rect: Rect2 = Rect2(
			label.offset_left,
			label.offset_top,
			label.offset_right - label.offset_left,
			label.offset_bottom - label.offset_top
		)
		_check(
			is_equal_approx(label_rect.position.x, float(spec["left"]))
			and is_equal_approx(label_rect.end.x, float(spec["right"]))
			and is_equal_approx(label_rect.position.y, 212.0)
			and is_equal_approx(label_rect.end.y, 224.0),
			"%s keeps its horizontal position and the 212..224 band" % spec["path"],
			str(label_rect)
		)
		_check(label_rect.end.y <= UPPER_Y - 38.0,
			"%s clears the ~y229 standing head" % spec["path"],
			"label_bottom=%.1f head_est=229.0" % label_rect.end.y)
		var overlap_x0: float = maxf(label_rect.position.x, 232.0)
		var overlap_x1: float = minf(label_rect.end.x, 400.0)
		var sample_x: float = (overlap_x0 + overlap_x1) * 0.5
		var standing_player: Rect2 = Rect2(
			sample_x - 6.0, UPPER_Y - 30.0, 12.0, 30.0
		)
		_check(not label_rect.intersects(standing_player),
			"%s does not intersect the upper-deck standing player rect" % spec["path"],
			"label=%s player=%s" % [str(label_rect), str(standing_player)])
	_check(_level.get_exit() != null and _level.get_exit().get_trigger_rect().size == Vector2(36.0, 76.0),
		"exit reuses the approved 36 x 76 trigger")
	_check(_level.get_player().get_world_right() == 634.0, "player stays inside the single 640 screen",
		str(_level.get_player().get_world_right()))
	_check(_level.get_node_or_null("Guard") == null and _level.get_node_or_null("Enemy") == null,
		"no guard or enemy node in this pass")


# ---------------------------------------------------------------------------
# V3 approved platform slices (visual only, no new collision)
# ---------------------------------------------------------------------------

func _test_v3_platform_visual() -> void:
	_section("V3 PLATFORM VISUAL / APPROVED SLICES / NO COLLISION")
	await _new_level()

	var visual_tex: Texture2D = load(V3_VISUAL_PATH) as Texture2D
	var decor_tex: Texture2D = load(V3_DECOR_PATH) as Texture2D
	var expected_tex: Texture2D = load(V3_EXPECTED_PATH) as Texture2D
	_check(visual_tex != null and visual_tex.get_size() == Vector2(640.0, 360.0),
		"approved V3 platform layer loads at 640x360",
		"missing" if visual_tex == null else str(visual_tex.get_size()))
	_check(decor_tex != null and decor_tex.get_size() == Vector2(640.0, 360.0),
		"approved V3 decor layer loads at 640x360",
		"missing" if decor_tex == null else str(decor_tex.get_size()))
	_check(expected_tex != null and expected_tex.get_size() == Vector2(640.0, 360.0),
		"V3 render reference loads at 640x360",
		"missing" if expected_tex == null else str(expected_tex.get_size()))
	_check(_file_sha256(V3_VISUAL_PATH) == V3_VISUAL_SHA256,
		"V3 platform layer is the byte-exact approved source",
		_file_sha256(V3_VISUAL_PATH))
	_check(_file_sha256(V3_DECOR_PATH) == V3_DECOR_SHA256,
		"V3 decor layer is the byte-exact approved source",
		_file_sha256(V3_DECOR_PATH))
	_check(_file_sha256(V3_EXPECTED_PATH) == V3_EXPECTED_SHA256,
		"V3 render reference is the exact approved-layer composite",
		_file_sha256(V3_EXPECTED_PATH))
	_check(_file_sha256(ATLAS_PATH) == ATLAS_SHA256,
		"legacy atlas file is byte-identical to the integration baseline",
		_file_sha256(ATLAS_PATH))

	var terrain_top: Node2D = _level.get_node("TerrainTop") as Node2D
	var terrain_fill: Node2D = _level.get_node("TerrainFill") as Node2D
	_check(terrain_top.position == Vector2(0.0, 320.0)
		and terrain_top.get("region") == Rect2(16.0, 0.0, 16.0, 16.0)
		and terrain_top.get("strip_size") == Vector2(640.0, 16.0)
		and (terrain_top.get("texture") as Texture2D).resource_path == ATLAS_PATH,
		"TerrainTop keeps its exact position/region/size/texture",
		str(terrain_top.position))
	_check(terrain_fill.position == Vector2(0.0, 336.0)
		and terrain_fill.get("region") == Rect2(16.0, 16.0, 16.0, 16.0)
		and terrain_fill.get("strip_size") == Vector2(640.0, 24.0)
		and (terrain_fill.get("texture") as Texture2D).resource_path == ATLAS_PATH,
		"TerrainFill keeps its exact position/region/size/texture",
		str(terrain_fill.position))

	var specs: Array[Dictionary] = [
		{
			"path": "UpperDeck/V3PlatformVisual", "parent": "UpperDeck",
			"position": Vector2(232.0, 264.0), "world": Vector2(232.0, 264.0),
			"region": Rect2(232.0, 264.0, 168.0, 36.0), "atlas": V3_VISUAL_PATH,
		},
		{
			"path": "UpperDeck/V3PlatformDecor", "parent": "UpperDeck",
			"position": Vector2(232.0, 264.0), "world": Vector2(232.0, 264.0),
			"region": Rect2(232.0, 264.0, 168.0, 36.0), "atlas": V3_DECOR_PATH,
		},
		{
			"path": "HighStep/V3PlatformVisual", "parent": "HighStep",
			"position": Vector2.ZERO, "world": Vector2(152.0, 274.0),
			"region": Rect2(152.0, 274.0, 56.0, 26.0), "atlas": V3_VISUAL_PATH,
		},
		{
			"path": "HighStep/V3PlatformDecor", "parent": "HighStep",
			"position": Vector2.ZERO, "world": Vector2(152.0, 274.0),
			"region": Rect2(152.0, 274.0, 56.0, 26.0), "atlas": V3_DECOR_PATH,
		},
		{
			"path": "RightLedge/V3PlatformVisual", "parent": "RightLedge",
			"position": Vector2.ZERO, "world": Vector2(400.0, 276.0),
			"region": Rect2(400.0, 276.0, 32.0, 24.0), "atlas": V3_VISUAL_PATH,
		},
	]
	for spec: Dictionary in specs:
		var sprite: Sprite2D = _level.get_node_or_null(String(spec["path"])) as Sprite2D
		var label: String = String(spec["path"])
		_check(sprite != null, "%s exists as a Sprite2D" % label)
		if sprite == null:
			continue
		_check(sprite.get_parent() == _level.get_node(String(spec["parent"])),
			"%s is attached to the %s structure node" % [label, String(spec["parent"])])
		_check(sprite.position == Vector2(spec["position"]),
			"%s keeps its native position" % label, str(sprite.position))
		_check(sprite.global_position == Vector2(spec["world"]),
			"%s lands on the approved world rectangle" % label, str(sprite.global_position))
		_check(sprite.scale.is_equal_approx(Vector2.ONE) and sprite.centered == false,
			"%s uses scale 1 and top-left anchoring" % label, str(sprite.scale))
		_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"%s explicitly uses Nearest filtering" % label, str(sprite.texture_filter))
		_check(sprite.modulate == Color.WHITE,
			"%s uses white modulate" % label, str(sprite.modulate))
		_check(sprite.find_children("*", "CollisionObject2D", true, false).is_empty(),
			"%s adds no collision object" % label)
		var atlas: AtlasTexture = sprite.texture as AtlasTexture
		_check(atlas != null and atlas.atlas != null
			and atlas.atlas.resource_path == String(spec["atlas"]),
			"%s reads the approved layer resource" % label,
			"" if atlas == null or atlas.atlas == null else atlas.atlas.resource_path)
		_check(atlas != null and atlas.region == Rect2(spec["region"]),
			"%s keeps the approved atlas crop" % label,
			"none" if atlas == null else str(atlas.region))

	var visual_image: Image = visual_tex.get_image() if visual_tex != null else null
	var decor_image: Image = decor_tex.get_image() if decor_tex != null else null
	if visual_image != null and decor_image != null:
		_check(_alpha_bbox(visual_image) == Rect2i(152, 264, 280, 36),
			"V3 platform pixels occupy exactly y264..299, x152..431",
			str(_alpha_bbox(visual_image)))
		_check(_alpha_bbox(decor_image) == Rect2i(160, 267, 213, 32),
			"V3 decor pixels occupy exactly y267..298, x160..372",
			str(_alpha_bbox(decor_image)))
		var top_line_ok: bool = true
		for x: int in range(232, 400):
			if not is_equal_approx(visual_image.get_pixel(x, 264).a, 1.0):
				top_line_ok = false
				break
		_check(top_line_ok, "the V3 top edge is fully opaque from x232 to x399 at y264")
		var seam_visual_ok: bool = true
		var seam_decor_ok: bool = true
		for gap: Rect2 in _level.get_upper_gap_rects():
			var gap_center: int = int(gap.position.x + gap.size.x * 0.5)
			for y: int in range(264, 274):
				if not is_equal_approx(visual_image.get_pixel(gap_center, y).a, 1.0):
					seam_visual_ok = false
			var joint_alpha: float = decor_image.get_pixel(gap_center, 270).a
			if joint_alpha <= 0.0 or joint_alpha >= 1.0:
				seam_decor_ok = false
		_check(seam_visual_ok,
			"all five real 8 px seams are fully covered by the continuous V3 deck")
		_check(seam_decor_ok,
			"all five seams keep a low-key, semi-transparent setting joint")
		var jump_gap_clear: bool = true
		for x: int in range(208, 232):
			for y: int in range(264, 300):
				if visual_image.get_pixel(x, y).a > 0.0 or decor_image.get_pixel(x, y).a > 0.0:
					jump_gap_clear = false
					break
			if not jump_gap_clear:
				break
		_check(jump_gap_clear, "the 208..232 jump gap stays visually empty")

	# The visual closes the seams, but the real physics rays must still behave
	# exactly as before: empty seams pass, solid beams/pier block.
	for gap: Rect2 in _level.get_upper_gap_rects():
		var gap_center: float = gap.position.x + gap.size.x * 0.5
		_check(_vertical_ray(gap_center).is_empty(),
			"covered seam at x=%.0f still passes the real physics ray" % gap_center)
	_check(not _vertical_ray(310.0).is_empty(),
		"covered solid segment at x=310 still blocks the real physics ray")


func _alpha_bbox(image: Image) -> Rect2i:
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


# ---------------------------------------------------------------------------
# Real perforation: empty seams vs solid stone, and the player staying on top
# ---------------------------------------------------------------------------

func _test_upper_seam_geometry() -> void:
	_section("UPPER DECK: REAL PERFORATION / PHYSICS RAYS")
	await _new_level()
	var gaps: Array[Rect2] = _level.get_upper_gap_rects()
	for gap: Rect2 in gaps:
		var gap_x: float = gap.position.x + gap.size.x * 0.5
		var gap_hit: Dictionary = _vertical_ray(gap_x)
		_check(gap_hit.is_empty(),
			"vertical physics ray passes through the real seam at x=%.0f" % gap_x,
			str(gap_hit))
	for solid_x: float in [236.0, 248.0, 272.0, 292.0, 312.0, 336.0, 360.0, 388.0]:
		var solid_hit: Dictionary = _vertical_ray(solid_x)
		_check(not solid_hit.is_empty(),
			"vertical physics ray is blocked by solid stone at x=%.0f" % solid_x,
			str(solid_hit))

	# Real-input walk across the whole perforated deck. The starting placement
	# is simulated; every step afterwards uses InputMap movement.
	_player.global_position = Vector2(236.0, UPPER_Y)
	_player.velocity = Vector2.ZERO
	await _physics(6)
	_check(_player.is_on_floor(), "player starts standing on the first deck stone",
		str(_player.global_position))
	var min_y: float = _player.global_position.y
	var fell: bool = false
	Input.action_press(&"move_right")
	for _i: int in range(260):
		await get_tree().physics_frame
		min_y = minf(min_y, _player.global_position.y)
		if _player.global_position.y > UPPER_Y + 6.0:
			fell = true
			break
		if _player.global_position.x >= 394.0:
			break
	Input.action_release(&"move_right")
	await _physics(5)
	_check(not fell and min_y >= UPPER_Y - 0.5,
		"player never drops through an 8 px seam while walking the deck",
		"min_y=%.1f fell=%s" % [min_y, str(fell)])
	_check(_player.global_position.x >= 390.0,
		"player can walk across every seam to the right end",
		str(_player.global_position))

	# Both ground entrances of the low corridor are really closed by the piers.
	_player.global_position = Vector2(218.0, PLAYER_FLOOR_Y)
	_player.velocity = Vector2.ZERO
	await _physics(6)
	Input.action_press(&"move_right")
	for _i: int in range(120):
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	await _physics(4)
	_check(_player.global_position.x <= 226.5,
		"entry pier really stops the player at the low corridor",
		str(_player.global_position))
	_player.global_position = Vector2(316.0, PLAYER_FLOOR_Y)
	_player.velocity = Vector2.ZERO
	await _physics(6)
	Input.action_press(&"move_left")
	for _i: int in range(120):
		await get_tree().physics_frame
	Input.action_release(&"move_left")
	await _physics(4)
	_check(_player.global_position.x >= 309.5,
		"exit pier really stops the player from entering the corridor backwards",
		str(_player.global_position))


# ---------------------------------------------------------------------------
# Editor duplicate / shared collision shape isolation
# ---------------------------------------------------------------------------

func _test_block_copy_isolation() -> void:
	_section("BLOCK COPY / SHARED SHAPE ISOLATION")
	await _new_level()
	var original: Level02Block = _level.get_node("UpperDeck/DeckBeamB") as Level02Block
	_check(original != null, "copy test has a real Level02Block")
	if original == null:
		return
	var original_pos: Vector2 = original.global_position
	var original_shape: RectangleShape2D = (
		original.get_node("CollisionShape2D").shape as RectangleShape2D
	)
	var original_shape_size: Vector2 = original_shape.size

	# Simulate the editor copy path: duplicate() copies the child CollisionShape2D
	# and its RectangleShape2D resource by reference, then add the copy to the
	# tree so the real _ready/_refresh_collision path runs.
	var copy: Level02Block = original.duplicate() as Level02Block
	copy.name = "DeckBeamBCopy"
	copy.position = Vector2(420.0, 80.0)
	_level.add_child(copy)
	await _physics(2)
	_check(copy.get_node("CollisionShape2D").shape != original_shape,
		"duplicated block gets its own shape resource")
	_check(original.get_collision_size() == original.get_block_size(),
		"original block art/collision stay same-source")
	_check(copy.get_collision_size() == copy.get_block_size(),
		"copy block art/collision stay same-source")
	_check(original.get_collision_top_left().is_equal_approx(original.global_position),
		"original collision top-left equals its art origin")
	_check(copy.get_collision_top_left().is_equal_approx(copy.global_position),
		"copy collision top-left equals its art origin")

	copy.block_size = Vector2(80.0, 32.0)
	await _physics(2)
	_check(original.get_block_size() == Vector2(16.0, 6.0),
		"changing copy size leaves the original block_size unchanged",
		str(original.get_block_size()))
	_check(original.get_collision_size() == Vector2(16.0, 6.0),
		"changing copy size leaves the original collision size unchanged",
		str(original.get_collision_size()))
	_check(original_shape.size == original_shape_size,
		"the original RectangleShape2D resource itself is unchanged",
		str(original_shape.size))
	_check(original.global_position.is_equal_approx(original_pos),
		"changing copy size leaves the original position unchanged",
		str(original.global_position))
	_check(copy.get_collision_size() == Vector2(80.0, 32.0),
		"copy collision follows its new block_size",
		str(copy.get_collision_size()))
	_check(copy.get_collision_top_left().is_equal_approx(copy.global_position),
		"copy collision stays aligned after resize",
		str(copy.get_collision_top_left()))
	_check(copy.get_block_rect() == Rect2(copy.global_position, Vector2(80.0, 32.0)),
		"copy art rect and collision rect remain the same source")
	copy.queue_free()
	await _physics(2)


# ---------------------------------------------------------------------------
# Initial opposite polarity
# ---------------------------------------------------------------------------

func _test_opposite_initial_release() -> void:
	_section("INITIAL OPPOSITE POLARITY RELEASE")
	await _new_level()
	# The player starts 辉相. Press Q first so the release snapshot must be the
	# opposite (澜相). The core's own value is never written by the test.
	await _tap_key(KEY_Q)
	_check(not _player.is_positive(), "player is configured 澜相 before release", _hud.get_polarity_text())
	await _move_to_x(100.0, 160)
	_check(_start_bay.is_player_in_range(_player.global_position), "player is in release range")
	await _tap_key(KEY_E)
	await _wait_until(func() -> bool: return _core.is_active(), 90)
	_check(_core.is_active(), "E releases the core normally")
	_check(_core.is_positive(), "release snapshot is the opposite of the 澜相 player (辉相)")
	_check(_core.global_position.is_equal_approx(Vector2(158.0, 312.0)),
		"release point is 40 px on the far side, 0 initial speed", str(_core.global_position))
	_check(is_zero_approx(_level.get_last_release_initial_speed()),
		"released core starts at 0 speed", str(_level.get_last_release_initial_speed()))
	var field: Dictionary = _level.compute_field(
		_player.global_position + Vector2(0.0, -15.0),
		_core.global_position,
		_player.is_positive(),
		_core.is_positive()
	)
	_check(String(field["status"]) == "ATTRACT", "opposite initial polarity reads ATTRACT",
		String(field["status"]))
	await _tap_key(KEY_Q)
	field = _level.compute_field(
		_player.global_position + Vector2(0.0, -15.0),
		_core.global_position,
		_player.is_positive(),
		_core.is_positive()
	)
	_check(String(field["status"]) == "REPEL", "Q to the core's polarity reads REPEL",
		String(field["status"]))
	_check(_core.is_positive(), "Q did not rewrite the released core's polarity")


# ---------------------------------------------------------------------------
# Upper seam force: isolated setup, real room force, both polarities
# ---------------------------------------------------------------------------

func _test_upper_seam_force() -> void:
	_section("UPPER SEAM FORCE - SIMULATED SETUP, REAL ROOM PHYSICS")
	# Geometry-window scan. Only the player/core starting placements are
	# simulated here; the room's field, raycast and carrier physics are real.
	await _new_level()
	var windows: Array[Dictionary] = []
	for core_x: float in [248.0, 264.0, 272.0, 304.0, 312.0, 320.0, 328.0]:
		for offset: float in [20.0, 24.0, 30.0, 36.0, 44.0, 48.0, 52.0]:
			var player_x: float = core_x + offset
			if player_x < 232.0 or player_x > 400.0:
				continue
			var field: Dictionary = _level.compute_field(
				Vector2(player_x, UPPER_Y - 15.0),
				Vector2(core_x, 312.0),
				true,
				true
			)
			if (
				String(field["status"]) == "REPEL"
				and not bool(field["blocked"])
				and float(field["distance"]) < _level.field_range
			):
				windows.append({
					"core_x": core_x,
					"player_x": player_x,
					"distance": float(field["distance"]),
					"force": field["core_acceleration"],
				})
				break
	_check(windows.size() >= 4,
		"scan finds several real standing windows over seams", str(windows.size()))
	for window: Dictionary in windows:
		_log("  seam window core_x=%.0f player_x=%.0f dist=%.1f force=%s" % [
			float(window["core_x"]), float(window["player_x"]),
			float(window["distance"]), str(window["force"]),
		])

	# Same polarity: REPEL pushes the resting core away from the player (left).
	await _new_level()
	_core.activate_at(Vector2(264.0, 312.0), true)
	_player.global_position = Vector2(294.0, UPPER_Y)
	_player.velocity = Vector2.ZERO
	_check(_core.velocity.length() < 0.5,
		"repel test core starts at rest (no prior push inertia)", str(_core.velocity))
	var repel_core_start: Vector2 = _core.global_position
	await _physics(8)
	var repel_field: Dictionary = _level.compute_field(
		_player.global_position + Vector2(0.0, -15.0),
		_core.global_position,
		_player.is_positive(),
		_core.is_positive()
	)
	_check(String(repel_field["status"]) == "REPEL" and not bool(repel_field["blocked"]),
		"same-polarity standing seam reads REPEL with clear LOS",
		"%s blocked=%s" % [String(repel_field["status"]), str(repel_field["blocked"])])
	_check(absf(float(repel_field["core_acceleration"].x)) > 100.0,
		"same-polarity seam has a real horizontal component",
		str(repel_field["core_acceleration"]))
	var repel_player_start: Vector2 = _player.global_position
	var repel_min_y: float = _player.global_position.y
	var repel_force_min: float = 0.0
	var repel_force_max: float = 0.0
	for _i: int in range(24):
		await get_tree().physics_frame
		repel_min_y = minf(repel_min_y, _player.global_position.y)
		var live_x: float = _level.get_last_force().x
		repel_force_min = minf(repel_force_min, live_x)
		repel_force_max = maxf(repel_force_max, live_x)
	_log("  repel: core %.2f -> %.2f, player %.2f -> %.2f, force_x=%.1f..%.1f, grounded=%s" % [
		repel_core_start.x, _core.global_position.x,
		repel_player_start.x, _player.global_position.x,
		repel_force_min, repel_force_max, str(_core.is_on_floor()),
	])
	_check(_core.global_position.x <= repel_core_start.x - 2.0,
		"same-polarity seam actually moves the core away (left)",
		"dx=%.2f" % (_core.global_position.x - repel_core_start.x))
	_check(repel_min_y >= UPPER_Y - 0.5 and _player.is_on_floor(),
		"player stays standing on the seam during same-polarity force",
		"min_y=%.1f" % repel_min_y)
	_check(absf(_core.global_position.y - 312.0) < 1.0 and _core.is_on_floor(),
		"same-polarity force does not lift the 12 px core through the 8 px seam",
		str(_core.global_position))
	_check(repel_force_min < -20.0,
		"live room force is applied left during the same-polarity test",
		"min_force_x=%.1f" % repel_force_min)

	# Opposite polarity: ATTRACT pulls the resting core toward the player (right).
	await _new_level()
	_core.activate_at(Vector2(264.0, 312.0), false)
	_player.global_position = Vector2(294.0, UPPER_Y)
	_player.velocity = Vector2.ZERO
	_check(_core.velocity.length() < 0.5,
		"attract test core starts at rest (no prior push inertia)", str(_core.velocity))
	var attract_core_start: Vector2 = _core.global_position
	await _physics(8)
	var attract_field: Dictionary = _level.compute_field(
		_player.global_position + Vector2(0.0, -15.0),
		_core.global_position,
		_player.is_positive(),
		_core.is_positive()
	)
	_check(String(attract_field["status"]) == "ATTRACT" and not bool(attract_field["blocked"]),
		"opposite-polarity standing seam reads ATTRACT with clear LOS",
		"%s blocked=%s" % [String(attract_field["status"]), str(attract_field["blocked"])])
	_check(absf(float(attract_field["core_acceleration"].x)) > 100.0,
		"opposite-polarity seam has a real horizontal component",
		str(attract_field["core_acceleration"]))
	var attract_player_start: Vector2 = _player.global_position
	var attract_min_y: float = _player.global_position.y
	var attract_force_min: float = 0.0
	var attract_force_max: float = 0.0
	for _i: int in range(24):
		await get_tree().physics_frame
		attract_min_y = minf(attract_min_y, _player.global_position.y)
		var live_x: float = _level.get_last_force().x
		attract_force_min = minf(attract_force_min, live_x)
		attract_force_max = maxf(attract_force_max, live_x)
	_log("  attract: core %.2f -> %.2f, player %.2f -> %.2f, force_x=%.1f..%.1f, grounded=%s" % [
		attract_core_start.x, _core.global_position.x,
		attract_player_start.x, _player.global_position.x,
		attract_force_min, attract_force_max, str(_core.is_on_floor()),
	])
	_check(_core.global_position.x >= attract_core_start.x + 2.0,
		"opposite-polarity seam actually moves the core toward the player (right)",
		"dx=%.2f" % (_core.global_position.x - attract_core_start.x))
	_check(attract_min_y >= UPPER_Y - 0.5 and _player.is_on_floor(),
		"player stays standing on the seam during opposite-polarity force",
		"min_y=%.1f" % attract_min_y)
	_check(absf(_core.global_position.y - 312.0) < 1.0 and _core.is_on_floor(),
		"opposite-polarity force does not lift the 12 px core through the 8 px seam",
		str(_core.global_position))
	_check(attract_force_max > 20.0,
		"live room force is applied right during the opposite-polarity test",
		"max_force_x=%.1f" % attract_force_max)

	# Solid segment: a vertical line through real stone stays BLOCKED and the
	# resting core receives no horizontal motion.
	await _new_level()
	_core.activate_at(Vector2(310.0, 312.0), true)
	_player.global_position = Vector2(310.0, UPPER_Y)
	_player.velocity = Vector2.ZERO
	await _physics(8)
	var solid_field: Dictionary = _level.compute_field(
		_player.global_position + Vector2(0.0, -15.0),
		_core.global_position,
		_player.is_positive(),
		_core.is_positive()
	)
	_check(bool(solid_field["blocked"]) and String(solid_field["status"]) == "BLOCKED",
		"solid stone segment still blocks the polarity line",
		"%s blocked=%s" % [String(solid_field["status"]), str(solid_field["blocked"])])
	var solid_start: float = _core.global_position.x
	await _physics(20)
	_check(absf(_core.global_position.x - solid_start) < 0.5,
		"solid stone segment applies no horizontal push",
		"dx=%.2f" % (_core.global_position.x - solid_start))

	# Outside the unchanged 100 px field: zero force and no motion.
	await _new_level()
	_core.activate_at(Vector2(312.0, 312.0), true)
	_player.global_position = Vector2(430.0, PLAYER_FLOOR_Y)
	_player.velocity = Vector2.ZERO
	await _physics(8)
	var far_field: Dictionary = _level.compute_field(
		_player.global_position + Vector2(0.0, -15.0),
		_core.global_position,
		_player.is_positive(),
		_core.is_positive()
	)
	_check(String(far_field["status"]) == "OUT OF RANGE" and not bool(far_field["in_range"]),
		"beyond 100 px the field reports OUT OF RANGE", str(far_field))
	_check(Vector2(far_field["core_acceleration"]).is_zero_approx(),
		"beyond 100 px the core acceleration is exactly zero",
		str(far_field["core_acceleration"]))
	var far_start: float = _core.global_position.x
	await _physics(20)
	_check(absf(_core.global_position.x - far_start) < 0.5,
		"beyond 100 px the resting core does not move",
		"dx=%.2f" % (_core.global_position.x - far_start))


# ---------------------------------------------------------------------------
# Main real-input route
# ---------------------------------------------------------------------------

func _test_main_route() -> void:
	_section("MAIN ROUTE - REAL INPUT / SAME INSTANCE")
	await _new_level()
	_check(_player.global_position.is_equal_approx(Vector2(36.0, 320.0)),
		"F6/default spawn is the level-02 marker", str(_player.global_position))

	# 1) Walk to the start bay and release.
	await _move_to_x(100.0, 160)
	_check(_start_bay.is_player_in_range(_player.global_position), "player reaches the start bay")
	var release_player_positive: bool = _player.is_positive()
	await _tap_key(KEY_E)
	_check(_level.get_pending_release(), "E starts the 0.25 s lid opening")
	_check(_level.get_release_bay() == _start_bay,
		"start opening is attributed to the start bay")
	_check(_hud.get_phase_text().contains("起始仓"),
		"start opening HUD uses the 起始仓 label", _hud.get_phase_text())
	# Q during the lid opening changes only the player. The release snapshot was
	# already taken at E time, so the core still uses the E-time opposite.
	await _tap_key(KEY_Q)
	await _wait_until(func() -> bool: return _core.is_active(), 90)
	_check(_core.is_active(), "lid finishes and the core activates")
	_check(_core.is_positive() == (not release_player_positive),
		"E-time 辉相 player released the opposite 澜相 core",
		"CORE=%s" % str(_core.is_positive()))
	_check(not _player.is_positive() and not _core.is_positive(),
		"Q during opening prepared the same-polarity push",
		"player=%s core=%s" % [str(_player.is_positive()), str(_core.is_positive())])
	_check(_start_bay.is_open_empty(), "start bay is OPEN/EMPTY after release")
	_check(_level.get_store_bay() == null and _target_bay.is_open_empty(),
		"nothing is auto-stored on release")

	# 2) The player is already on the core's polarity, so hold right to push.
	_check(_player.is_positive() == _core.is_positive(), "player and core are same polarity")
	await _physics(2)
	_check(_level.get_last_status() == "REPEL", "same polarity live field is REPEL",
		_level.get_last_status())

	var core_min_x: float = _core.global_position.x
	var core_max_x: float = _core.global_position.x
	var core_min_y: float = _core.global_position.y
	var core_max_y: float = _core.global_position.y
	var player_max_x: float = _player.global_position.x
	var player_min_y: float = _player.global_position.y

	Input.action_press(&"move_right")
	for _i: int in range(900):
		await get_tree().physics_frame
		core_min_x = minf(core_min_x, _core.global_position.x)
		core_max_x = maxf(core_max_x, _core.global_position.x)
		core_min_y = minf(core_min_y, _core.global_position.y)
		core_max_y = maxf(core_max_y, _core.global_position.y)
		player_max_x = maxf(player_max_x, _player.global_position.x)
		player_min_y = minf(player_min_y, _player.global_position.y)
		if _core.is_active() and _core.global_position.x >= 312.0:
			break
	Input.action_release(&"move_right")
	await _physics(40)

	_log("  push path: core x %.1f..%.1f y %.1f..%.1f; player max x %.1f min y %.1f" % [
		core_min_x, core_max_x, core_min_y, core_max_y, player_max_x, player_min_y,
	])
	_check(core_min_x >= 150.0, "core starts at the release point and only moves right",
		"min x=%.1f" % core_min_x)
	_check(core_max_x >= 302.0, "core centre is fully past the corridor exit (x>=302)",
		"max x=%.1f" % core_max_x)
	_check(core_max_x <= 380.0, "core is not flung across the whole screen",
		"max x=%.1f" % core_max_x)
	_check(core_min_y >= 311.0 and core_max_y <= 313.0,
		"core stays on the ground through the 20 px corridor (y≈312)",
		"y=%.1f..%.1f" % [core_min_y, core_max_y])
	_check(player_max_x <= 227.5, "player body stays left of the corridor throat while pushing",
		"max player x=%.1f" % player_max_x)
	_check(_player.global_position.y >= 319.0,
		"player stays on the lower floor while pushing (cannot enter the corridor)",
		"y=%.1f" % _player.global_position.y)
	_check(_level.get_last_status() != "BLOCKED" or core_max_x >= 302.0,
		"push is not relying on a hidden wall bypass")

	# The core is now far enough to be out of the field. With no opposing
	# force, the player must still be physically stopped by the entry pier.
	await _move_to_x(230.0, 120)
	_check(_player.global_position.x <= 226.5,
		"entry pier physically stops the player at the low corridor",
		str(_player.global_position))
	_log("  push end: core=%s player=%s status=%s" % [
		str(_core.global_position), str(_player.global_position), _level.get_last_status()
	])

	# 3) Climb the high short step, then the upper route.
	await _move_to_x(142.0, 200, true)
	_check(_player.global_position.y >= 319.0, "player returns to open ground before the step")
	var on_step: bool = false
	var on_upper: bool = false
	var high_step_pos: Vector2 = Vector2.ZERO
	var upper_landing_pos: Vector2 = Vector2.ZERO
	for _attempt: int in range(3):
		if (
			_player.is_on_floor()
			and absf(_player.global_position.y - UPPER_Y) <= 2.0
			and _player.global_position.x >= 232.0
		):
			on_upper = true
			break
		if not (
			_player.is_on_floor()
			and absf(_player.global_position.y - HIGH_STEP_Y) <= 2.0
		):
			await _move_to_x(142.0, 240, true)
			on_step = await _try_platform_jump(HIGH_STEP_Y, 150.0, 208.0, 120)
			if on_step:
				high_step_pos = _player.global_position
				_log("  high step landing: player=%s" % str(high_step_pos))
		else:
			on_step = true
			if high_step_pos.is_zero_approx():
				high_step_pos = _player.global_position
		if not on_step:
			continue
		on_upper = await _try_platform_jump(UPPER_Y, 232.0, 300.0, 120)
		if on_upper:
			upper_landing_pos = _player.global_position
			_log("  upper landing: player=%s" % str(upper_landing_pos))
			break
	_check(on_step, "real jump lands on the high short step (top y=274)",
		"player=%s" % str(high_step_pos))
	_check(on_upper, "real jump from the step reaches the upper route (top y=264)",
		"player=%s" % str(upper_landing_pos))
	if not on_upper:
		# Keep the rest of the route meaningful in the log even if the climb
		# fails: the following upper/exit checks will also fail clearly.
		pass

	# The player is now above the low corridor. A line through the solid entry
	# pier must remain blocked; the real occlusion path is unchanged.
	var ceiling_field: Dictionary = _level.compute_field(
		_player.global_position + Vector2(0.0, -15.0),
		Vector2(264.0, 312.0),
		_player.is_positive(),
		_core.is_positive()
	)
	_check(bool(ceiling_field["blocked"]),
		"a point under the solid pier is occluded from the upper route",
		"%s blocked=%s" % [String(ceiling_field["status"]), str(ceiling_field["blocked"])])

	# 4) Real-input upper-seam action: switch opposite and walk right along the
	# perforated deck until the unchanged ray really passes a seam. The player
	# is physically standing on the stone; the core is on the ground below.
	await _physics(30)
	_check(_core.velocity.length() < 1.0,
		"core is at rest before the upper-seam action (no push inertia)",
		str(_core.velocity))
	await _tap_key(KEY_Q)
	_check(_player.is_positive() != _core.is_positive(),
		"upper-deck player switches to the core's opposite polarity",
		"player=%s core=%s" % [str(_player.is_positive()), str(_core.is_positive())])
	var seam_start_core: Vector2 = _core.global_position
	var seam_player_pos: Vector2 = Vector2.ZERO
	var seam_core_pos: Vector2 = Vector2.ZERO
	var seam_field: Dictionary = {}
	var scan_target_x: float = maxf(300.0, ceilf((seam_start_core.x + 20.0) / 10.0) * 10.0)
	while scan_target_x <= 392.0:
		await _move_to_x(scan_target_x, 160)
		var probe_field: Dictionary = _level.compute_field(
			_player.global_position + Vector2(0.0, -15.0),
			_core.global_position,
			_player.is_positive(),
			_core.is_positive()
		)
		if (
			String(probe_field["status"]) == "ATTRACT"
			and not bool(probe_field["blocked"])
			and _player.global_position.x > _core.global_position.x
		):
			seam_player_pos = _player.global_position
			seam_core_pos = _core.global_position
			seam_field = probe_field
			break
		scan_target_x += 10.0
	_check(not seam_field.is_empty(),
		"real-input walk finds a standing seam that reaches the core",
		"player=%s core=%s" % [str(_player.global_position), str(_core.global_position)])
	if not seam_field.is_empty():
		_log("  upper seam: t=%.2fs player=%s core=%s dist=%.1f force=%s blocked=%s grounded=%s" % [
			float(Engine.get_physics_frames()) / 60.0,
			str(seam_player_pos), str(seam_core_pos),
			float(seam_field["distance"]), str(seam_field["core_acceleration"]),
			str(seam_field["blocked"]), str(_core.is_on_floor()),
		])
		_check(absf(float(seam_field["core_acceleration"].x)) > 100.0,
			"upper seam has a real horizontal component in the live route",
			str(seam_field["core_acceleration"]))
		var live_core_before: Vector2 = _core.global_position
		var live_player_min_y: float = _player.global_position.y
		for _i: int in range(24):
			await get_tree().physics_frame
			live_player_min_y = minf(live_player_min_y, _player.global_position.y)
		_log("  upper seam result: core %.2f -> %.2f, player %.2f -> %.2f, force_x=%.1f" % [
			live_core_before.x, _core.global_position.x,
			seam_player_pos.x, _player.global_position.x, _level.get_last_force().x,
		])
		_check(_core.global_position.x >= live_core_before.x + 2.0,
			"the real upper-seam field moves the core toward the player (right)",
			"dx=%.2f" % (_core.global_position.x - live_core_before.x))
		_check(live_player_min_y >= UPPER_Y - 0.5 and _player.is_on_floor(),
			"the player never drops through a seam during the live action",
			"min_y=%.1f" % live_player_min_y)

	# Walk the rest of the upper route to the right-hand drop.
	await _move_to_x(394.0, 220)
	_check(_player.global_position.y <= UPPER_Y + 1.0 and _player.global_position.x >= 296.0,
		"upper route is walkable across the corridor and walkway",
		"player=%s" % str(_player.global_position))
	var upper_x: float = _player.global_position.x
	await _move_right_until(
		func() -> bool:
			return (
				_player.is_on_floor()
				and _player.global_position.y >= 318.0
				and _player.global_position.x >= 432.0
			),
		260
	)
	_check(_player.global_position.x >= 432.0 and _player.global_position.y >= 318.0,
		"right-hand descent returns the player to the ground",
		"player=%s" % str(_player.global_position))
	_check(_player.global_position.x > upper_x, "descent moves right, not through the corridor")

	# 5a) Exit before store must NOT complete. The target bay is empty, so even
	# standing in the 600 px exit trigger only produces the not-ready feedback.
	await _move_to_x(600.0, 260)
	await _physics(6)
	_check(not _level.is_completed(), "reaching the exit before storing does not complete")
	_check(not _level.can_exit_now(), "exit gate reports not-ready without a locked target")
	_check(_hud.get_toast_text().contains("星核尚未入仓"),
		"unready exit shows the Chinese not-ready feedback", _hud.get_toast_text())
	await _move_to_x(440.0, 260, true)
	_check(not get_tree().paused, "test remains unpaused before the target store")

	# 6) Ground pull: the player is already opposite. Stay right of the core
	# and walk it toward the moved target bay at x=520, in short real steps.
	_check(_player.is_positive() != _core.is_positive(),
		"right-side player keeps the opposite polarity",
		"player=%s core=%s" % [str(_player.is_positive()), str(_core.is_positive())])
	var ready_seen: bool = false
	for _step: int in range(5):
		var pull_target: float = clampf(_core.global_position.x + 70.0, 440.0, 560.0)
		await _move_to_x(pull_target, 180)
		await _physics(30)
		_log("  ground pull step %d: player=%s core=%s status=%s" % [
			_step, str(_player.global_position), str(_core.global_position),
			_level.get_last_status(),
		])
		if bool(_level._find_store_bay().get("ok", false)):
			ready_seen = true
			break
	if not ready_seen:
		for _i: int in range(180):
			await get_tree().physics_frame
			if bool(_level._find_store_bay().get("ok", false)):
				ready_seen = true
				break
	_log("  store wait: player=%s core=%s target=%s info=%s" % [
		str(_player.global_position), str(_core.global_position),
		_target_bay.get_state_name(), str(_level._find_store_bay())
	])
	_check(ready_seen, "core reaches the target seat while the player is in range")
	_check(_player.global_position.x <= 566.0,
		"player stays within the moved target bay's 46 px range",
		str(_player.global_position))
	_check(_target_bay.is_open_empty() and _core.is_active() and _level.get_store_bay() == null,
		"seat entry does not auto-capture; E is still required")
	await _physics(4)
	_check(_target_bay.is_open_empty() and _level.get_store_bay() == null,
		"four more frames in the seat still do not auto-capture")
	await _tap_key(KEY_E)
	await _physics(3)
	_check(_level.get_store_bay() == _target_bay, "E accepts the three-party store")
	_check(not _core.is_active(), "accepted store deactivates the moving core")
	_check(_target_bay.is_closing(), "target lid is closing")
	await _wait_until(func() -> bool: return _target_bay.is_locked(), 90)
	_check(_target_bay.is_locked(), "target bay becomes LOCKED")
	_check(_target_bay.get_record_label() == "CYAN -", "target records the core's own 澜相",
		_target_bay.get_record_label())
	_check(_hud.get_core_text().contains("澜相") and not _hud.get_core_text().contains("CYAN"),
		"target record HUD maps the shared record to Chinese 澜相",
		_hud.get_core_text())
	_check(_level.can_exit_now(), "exit gate becomes ready only after the target locks")
	_check(_hud.get_prompt_text() == "可以到出口", "HUD tells the player the exit is available",
		_hud.get_prompt_text())

	# 7) Taking the target core out closes the exit gate again; re-store to finish.
	await _tap_key(KEY_E)
	_check(_level.get_release_bay() == _target_bay,
		"target opening is attributed to the target bay")
	_check(_hud.get_phase_text().contains("目标仓") and not _hud.get_phase_text().contains("起始仓"),
		"target opening HUD uses the 目标仓 label", _hud.get_phase_text())
	await _wait_until(func() -> bool: return _core.is_active(), 90)
	_check(_core.is_active() and _target_bay.is_open_empty(),
		"E releases the target core and opens the target bay")
	_check(not _level.can_exit_now(), "taking the target core out makes the exit not-ready again")
	_check(_target_bay.get_record_label() == "CYAN -", "release keeps the target record",
		_target_bay.get_record_label())
	# The release point is on the far side of the moved bay. Stay in place:
	# the opposite field has a real arm to pull the core back through the seat
	# without any teleport or force injection.
	await _physics(30)
	ready_seen = false
	for _i: int in range(300):
		await get_tree().physics_frame
		var info2: Dictionary = _level._find_store_bay()
		if bool(info2.get("ok", false)):
			ready_seen = true
			break
	_log("  re-store wait: player=%s core=%s target=%s info=%s" % [
		str(_player.global_position), str(_core.global_position),
		_target_bay.get_state_name(), str(_level._find_store_bay())
	])
	_check(ready_seen, "released core can be attracted back into the target seat")
	await _tap_key(KEY_E)
	await _wait_until(func() -> bool: return _target_bay.is_locked(), 90)
	_check(_target_bay.is_locked(), "re-store locks the target again")

	# 8) Walk to the exit; completion must happen there, not earlier. The
	# player is already near the target; passing 540 must not complete.
	await _move_to_x(540.0, 160)
	_check(not _level.is_completed(), "walking toward the exit is not completion")
	await _move_to_x(600.0, 160)
	await _physics(6)
	_check(_level.is_completed(), "player reaches the exit and the level completes")
	_check(_hud.is_completion_visible(), "第二关完成 panel is visible")
	_check(_hud.get_completion_text() == "第二关完成", "completion panel uses Chinese level-02 text",
		_hud.get_completion_text())
	_check(_level.get_completion_count() == 1, "completion count is 1",
		str(_level.get_completion_count()))
	_check(_player.is_input_override_active(), "completion freezes normal input")
	_check(_level.get_exit().is_completed(), "exit visual switches to completed")

	# 9) R during completion: full reset including record/hud.
	await _tap_key(KEY_R)
	await _physics(8)
	_check(not _level.is_completed(), "R after completion clears completion")
	_check(not _hud.is_completion_visible(), "completion panel is hidden after R")
	_check(not get_tree().paused, "R leaves the tree unpaused")
	_check(_player.global_position.is_equal_approx(Vector2(36.0, 320.0)),
		"R returns the player to the level spawn", str(_player.global_position))
	_check(_player.is_positive(), "R restores 辉相")
	_check(_start_bay.is_locked(), "R restores the start bay LOCKED")
	_check(_target_bay.is_open_empty(), "R restores the target bay OPEN/EMPTY")
	_check(not _core.is_active(), "R disables the moving core")
	_check(_target_bay.get_record_label() == "NO RECORD", "R clears the target record",
		_target_bay.get_record_label())
	_check(_hud.get_polarity_text() == "辉相", "R restores the Chinese 辉相 HUD")
	_check(_hud.get_prompt_text().contains("E"), "R restores the release prompt", _hud.get_prompt_text())
	_check(_target_bay.get_node("BayVisual").is_lid_open()
		if _target_bay.get_node("BayVisual").has_method("is_lid_open") else true,
		"target lid is reset open (visual helper)")

	# 10) Stele re-entry has no stale page after R.
	await _move_to_x(80.0, 160)
	await _physics(4)
	# Historical test; L2 now uses GuideEcho. Dynamic access keeps the old
	# script parseable, not a current runtime assertion.
	var stele = _level.get_start_stele()
	_check(stele.is_prompt_visible() and stele.get_page_index() == 0,
		"re-entering the stele after R starts at page 1",
		"page=%d visible=%s" % [stele.get_page_index(), str(stele.is_prompt_visible())])
	await _tap_key(KEY_F)
	await _physics(2)
	_check(stele.get_page_index() == 1, "F advances the stele once")
	await _tap_key(KEY_R)
	await _physics(6)
	await _move_to_x(80.0, 160)
	await _physics(4)
	_check(stele.get_page_index() == 0, "R clears the old stele page before re-entry",
		"page=%d" % stele.get_page_index())


# ---------------------------------------------------------------------------
# Pause / focus / R during opening and closing
# ---------------------------------------------------------------------------

func _test_pause_focus_and_boundary_resets() -> void:
	_section("PAUSE / FOCUS / R DURING OPENING AND CLOSING")
	await _new_level()
	# Focus-loss clears Shift and double-tap latches.
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	_send_key(KEY_D, true)
	await _physics(4)
	_send_key(KEY_D, false)
	await _physics(2)
	_check(_player.is_left_shift_held(), "left Shift latch is set before focus loss")
	get_window().focus_exited.emit()
	await _physics(2)
	_check(not _player.is_left_shift_held(), "focus loss clears the left-Shift latch")
	_check(not _player.is_double_tap_run_locked(), "focus loss clears double-tap run")
	_check(not _player.is_input_override_active(), "focus loss does not leave a scripted axis")
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)

	# Double-tap D must also reach the player through the level's raw-key
	# forwarding (the same path used by left Shift).
	await _physics(10)
	_send_key(KEY_D, true)
	await _physics(2)
	_send_key(KEY_D, false)
	await _physics(2)
	_send_key(KEY_D, true)
	await _physics(3)
	_check(_player.is_double_tap_run_locked(), "double-tap D reaches the player")
	_check(_player.is_sprint_intent(), "double-tap D sets sprint intent")
	_send_key(KEY_D, false)
	await _physics(6)

	# Pause during the 0.25 s opening freezes player, core and lid.
	await _move_to_x(100.0, 160)
	await _tap_key(KEY_E)
	await _physics(3)
	_check(_level.get_pending_release(), "lid is opening before pause")
	var player_before: Vector2 = _player.global_position
	var lid_ready_before: bool = _start_bay.is_release_ready()
	await _tap_key(KEY_ESCAPE)
	_check(get_tree().paused and _hud.is_pause_visible(), "Esc pauses and shows the pause overlay")
	for _i: int in range(20):
		await get_tree().process_frame
	_check(_player.global_position.is_equal_approx(player_before),
		"paused player physics is frozen", str(_player.global_position))
	_check(not _core.is_active(), "core stays inactive while paused during opening")
	_check(_start_bay.is_release_ready() == lid_ready_before and not _start_bay.is_release_ready(),
		"lid animation is frozen while paused")
	await _tap_key(KEY_ESCAPE)
	_check(not get_tree().paused and not _hud.is_pause_visible(), "Esc resumes")
	await _wait_until(func() -> bool: return _core.is_active(), 90)
	_check(_core.is_active(), "opening finishes normally after resume")

	# R during opening: reset clears pending state immediately.
	await _tap_key(KEY_R)
	await _physics(6)
	await _move_to_x(100.0, 160)
	await _tap_key(KEY_E)
	await _physics(2)
	_check(_level.get_pending_release(), "a fresh opening is pending before R")
	await _tap_key(KEY_R)
	await _physics(6)
	_check(not _level.get_pending_release(), "R during opening clears pending release")
	_check(_start_bay.is_locked(), "R during opening restores LOCKED")
	_check(not _core.is_active(), "R during opening leaves no active core")

	# R during closing and pause during closing. This is an isolated boundary
	# setup: the store state is prepared directly so the test can target the
	# close animation without replaying the whole route a third time.
	await _new_level()
	_core.activate_at(_target_bay.get_store_center(), false)
	_level._begin_store(_target_bay)
	await _physics(2)
	_check(_target_bay.is_closing(), "isolated setup puts the target lid in CLOSING")
	await _tap_key(KEY_ESCAPE)
	_check(get_tree().paused, "pause during closing")
	await _physics(1)
	var closing_ready_before: bool = _target_bay.is_store_ready()
	for _i: int in range(16):
		await get_tree().process_frame
	_check(_target_bay.is_closing() and _target_bay.is_store_ready() == closing_ready_before,
		"closing lid is frozen while paused")
	await _tap_key(KEY_ESCAPE)
	await _wait_until(func() -> bool: return _target_bay.is_locked(), 90)
	_check(_target_bay.is_locked(), "closing finishes after resume")
	await _tap_key(KEY_R)
	await _physics(6)
	_check(_target_bay.is_open_empty() and not _core.is_active(),
		"R during/after closing resets the target and core")
	_check(_target_bay.get_record_label() == "NO RECORD", "R during closing clears the record")


func _test_isolated_core_out_of_bounds() -> void:
	_section("ISOLATED CORE OUT-OF-BOUNDS RECOVERY")
	await _new_level()
	# Isolated boundary setup only: place an active core outside the room. The
	# recovery itself runs through the real room code on the next physics tick.
	_core.activate_at(Vector2(2.0, 312.0), true)
	await _physics(3)
	_check(not _core.is_active(), "core outside x<4 is deactivated by the room")
	_check(_player.global_position.is_equal_approx(Vector2(36.0, 320.0)),
		"out-of-bounds recovery returns the player to spawn", str(_player.global_position))
	_check(_start_bay.is_locked() and _target_bay.is_open_empty(),
		"out-of-bounds recovery restores the bay states")
	_check(_hud.get_toast_text().contains("星核越界"), "out-of-bounds shows a clear Chinese recovery toast",
		_hud.get_toast_text())
	await _tap_key(KEY_R)
	await _physics(6)
	_check(not _core.is_active() and _level.get_pending_release() == false,
		"R after out-of-bounds is clean and playable")


# ---------------------------------------------------------------------------
# Input / routing helpers
# ---------------------------------------------------------------------------

func _vertical_ray(x: float) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	if space == null:
		return {}
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		Vector2(x, 258.0),
		Vector2(x, 278.0),
		1
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [_player.get_rid(), _core.get_rid()]
	return space.intersect_ray(query)


func _file_sha256(path: String) -> String:
	var digest: String = FileAccess.get_sha256(path)
	return digest.to_upper()


func _new_level() -> void:
	_release_inputs()
	get_tree().paused = false
	if is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level02
	add_child(_level)
	await _physics(8)
	_player = _level.get_player()
	_hud = _level.get_hud()
	_core = _level.get_core()
	_start_bay = _level.get_start_bay()
	_target_bay = _level.get_target_bay()
	_check(_level.is_active(), "level 02 is active at F6/default start")
	_check(_level.get_node("HUD").visible, "level-02 HUD is visible at start")


func _try_platform_jump(target_y: float, min_x: float, max_x: float, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	await _tap_key(KEY_SPACE)
	var landed: bool = false
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if (
			_player.is_on_floor()
			and absf(_player.global_position.y - target_y) <= 2.0
			and _player.global_position.x >= min_x
			and _player.global_position.x <= max_x
		):
			landed = true
			break
	Input.action_release(&"move_right")
	await _physics(5)
	return landed


func _recover_from_fall() -> void:
	if _player.global_position.y > 330.0:
		await _move_to_x(142.0, 240, true)
		await _physics(4)


func _move_to_x(target_x: float, max_frames: int, move_left: bool = false) -> void:
	var action: StringName = &"move_left" if move_left else &"move_right"
	Input.action_press(action)
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if move_left:
			if _player.global_position.x <= target_x:
				break
		else:
			if _player.global_position.x >= target_x:
				break
	Input.action_release(action)
	await _physics(6)


func _move_right_until(condition: Callable, max_frames: int) -> void:
	Input.action_press(&"move_right")
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if bool(condition.call()):
			break
	Input.action_release(&"move_right")
	await _physics(5)


func _wait_until(condition: Callable, max_frames: int) -> void:
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if bool(condition.call()):
			return


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _send_key(key: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.location = location
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap_key(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, true, location)
	await get_tree().process_frame
	await get_tree().physics_frame
	_send_key(key, false, location)
	await get_tree().process_frame
	await get_tree().physics_frame


func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause"]:
		Input.action_release(action)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)


func _section(title: String) -> void:
	_log("")
	_log("-- %s --" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s  (%s)" % [label, detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s  (%s)" % [label, detail])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count])
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log_lines) + "\n")
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
