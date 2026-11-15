class_name PrototypeMain
extends Node2D

## Owns the basic single-screen test room, the F2 switch to the isolated anchor
## trial room, terrain collision, HUD wiring and pause. The basic room is
## deliberately small: one ground split by a fall-test gap, one short step and
## two floating platforms. All collisions are explicit rectangles; the Szadi
## tile strip is only the visual layer.

const SPAWN_POSITION: Vector2 = Vector2(80.0, 288.0)
const TILE_SIZE: int = 16
const RECORD_TEST_SCENE: String = "res://scenes/polarity_record_test_room_standalone.tscn"
const ATLAS: Texture2D = preload("res://assets/map/ruin_platform_tiles.png")

const GROUND_LEFT: Rect2 = Rect2(0.0, 288.0, 416.0, 112.0)
const GROUND_RIGHT: Rect2 = Rect2(496.0, 288.0, 144.0, 112.0)
const SHORT_STEP: Rect2 = Rect2(144.0, 272.0, 64.0, 128.0)
const PLATFORM_A: Rect2 = Rect2(240.0, 224.0, 96.0, 16.0)
const PLATFORM_B: Rect2 = Rect2(368.0, 192.0, 96.0, 16.0)
const PLATFORM_RECTS: Array[Rect2] = [
	GROUND_LEFT,
	GROUND_RIGHT,
	SHORT_STEP,
	PLATFORM_A,
	PLATFORM_B,
]

@onready var _player: PrototypePlayer = $World/Player
@onready var _hud: PrototypeHUD = $HUD
@onready var _terrain: TileMapLayer = $World/Terrain
@onready var _anchor_room: AnchorRoom = $AnchorRoom
@onready var _interaction_room: StarCoreInteractionRoom = $InteractionRoom
@onready var _tutorial_stele: TutorialStele = $World/TutorialStele

var _collision_bodies: Array[StaticBody2D] = []
var _debug_visible: bool = false
var _in_anchor_room: bool = false
var _in_interaction_room: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$World.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Background.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS

	_build_terrain()
	_anchor_room.deactivate()
	_interaction_room.deactivate()
	_hud.set_room_mode(false)

	_player.state_changed.connect(_on_player_state_changed)
	_player.polarity_changed.connect(_on_player_polarity_changed)
	_player.reset_performed.connect(_on_player_reset_performed)
	_player.set_spawn_point(SPAWN_POSITION)
	_player.reset_to_spawn("spawn", false)
	_player.set_debug_enabled(false)
	_hud.set_debug_visible(false)
	_hud.set_polarity(true)
	get_window().focus_exited.connect(_on_window_focus_exited)
	_refresh_hud()


func _input(event: InputEvent) -> void:
	if _player == null or get_tree().paused:
		return
	if event is InputEventKey:
		_player.handle_key_event(event as InputEventKey)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		toggle_pause()
	if Input.is_action_just_pressed(&"toggle_debug"):
		_debug_visible = not _debug_visible
		_player.set_debug_enabled(_debug_visible)
		_hud.set_debug_visible(_debug_visible)
	if Input.is_action_just_pressed(&"toggle_anchor_room") and not get_tree().paused:
		toggle_anchor_room()
	if Input.is_action_just_pressed(&"toggle_interaction_room") and not get_tree().paused:
		toggle_interaction_room()
	if Input.is_action_just_pressed(&"toggle_record_room") and not get_tree().paused:
		# Deliberately a standalone scene switch, not another room embedded in
		# Main. It keeps the existing room/HUD architecture and the F7 test entry
		# small while the feature is being reviewed.
		_tutorial_stele.set_suspended(true)
		get_tree().change_scene_to_file(RECORD_TEST_SCENE)
	_refresh_hud()


func _build_terrain() -> void:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture = ATLAS
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for atlas_y: int in range(2):
		for atlas_x: int in range(12):
			atlas_source.create_tile(Vector2i(atlas_x, atlas_y))

	var source_id: int = tile_set.add_source(atlas_source)
	_terrain.tile_set = tile_set

	for index: int in range(PLATFORM_RECTS.size()):
		var rect: Rect2 = PLATFORM_RECTS[index]
		_paint_platform(rect, source_id)
		_add_collision_rect(rect, index)


func _paint_platform(rect: Rect2, source_id: int) -> void:
	var origin: Vector2i = Vector2i(
		int(rect.position.x) / TILE_SIZE,
		int(rect.position.y) / TILE_SIZE
	)
	var width_tiles: int = int(rect.size.x) / TILE_SIZE
	var height_tiles: int = int(rect.size.y) / TILE_SIZE
	for row: int in range(height_tiles):
		for column: int in range(width_tiles):
			var atlas_row: int = 0 if row == 0 else 1
			var atlas_column: int = _atlas_column(column, width_tiles)
			_terrain.set_cell(
				origin + Vector2i(column, row),
				source_id,
				Vector2i(atlas_column, atlas_row)
			)


func _atlas_column(column: int, width_tiles: int) -> int:
	if column == 0:
		return 0
	if column == width_tiles - 1:
		return 11
	return 1 + ((column - 1) % 10)


func _add_collision_rect(rect: Rect2, index: int) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "PlatformCollision%d" % index
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 1

	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	$World.add_child(body)
	_collision_bodies.append(body)


func _refresh_hud() -> void:
	if _player == null or _hud == null:
		return
	var anchor: Vector2i = _player.get_chest_anchor_frame()
	var anchor_text: String = "(%d, %d)" % [anchor.x, anchor.y]
	_hud.set_state(
		_player.get_state_name(),
		_player.get_anim_frame(),
		_player.get_anim_frame_count(),
		_player.get_hud_on_floor(),
		_player.velocity.x,
		_player.velocity.y,
		anchor_text
	)


func _on_player_state_changed(_anim: StringName, _frame: int, _frame_count: int) -> void:
	_refresh_hud()


func _on_player_polarity_changed(positive: bool) -> void:
	_hud.set_polarity(positive)


func _on_player_reset_performed(reason: String, _count: int) -> void:
	if _in_anchor_room:
		_anchor_room.on_player_reset(reason)
	if _in_interaction_room:
		_interaction_room.on_player_reset(reason)
	if _tutorial_stele != null:
		_tutorial_stele.on_player_reset(reason)
	match reason:
		"fall":
			_hud.show_toast("FELL - RESPAWNED")
		"manual":
			_hud.show_toast("RESET - POLARITY RESTORED")
		_:
			pass


func toggle_anchor_room() -> void:
	if _in_interaction_room:
		exit_interaction_room()
	if _in_anchor_room:
		exit_anchor_room()
	else:
		enter_anchor_room()


func enter_anchor_room() -> void:
	if _in_anchor_room:
		return
	if _in_interaction_room:
		exit_interaction_room()
	_in_anchor_room = true
	_interaction_room.deactivate()
	_set_base_room_active(false)
	_tutorial_stele.set_suspended(true)
	_hud.set_room_mode(true)
	_player.set_spawn_point(_anchor_room.get_spawn_position())
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.reset_to_spawn("room_enter", false)
	_anchor_room.activate(_player, _hud)
	_hud.set_polarity(true)
	_hud.set_anchor_success(false)
	_refresh_hud()


func exit_anchor_room() -> void:
	if not _in_anchor_room:
		return
	_in_anchor_room = false
	_anchor_room.deactivate()
	_set_base_room_active(true)
	_tutorial_stele.set_suspended(false)
	_hud.set_room_mode(false)
	_player.set_spawn_point(SPAWN_POSITION)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.reset_to_spawn("room_exit", false)
	_hud.set_polarity(true)
	_refresh_hud()


func toggle_interaction_room() -> void:
	if _in_anchor_room:
		exit_anchor_room()
	if _in_interaction_room:
		exit_interaction_room()
	else:
		enter_interaction_room()


func enter_interaction_room() -> void:
	if _in_interaction_room:
		return
	if _in_anchor_room:
		exit_anchor_room()
	_set_base_room_active(false)
	_interaction_room.deactivate()
	_tutorial_stele.set_suspended(true)
	_hud.set_interaction_mode(true)
	_player.set_spawn_point(_interaction_room.get_spawn_position())
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.set_anchor_room_bounds(false)
	_player.reset_to_spawn("room_enter", false)
	_in_interaction_room = true
	_interaction_room.activate(_player, _hud)
	_hud.set_polarity(true)
	_refresh_hud()


func exit_interaction_room() -> void:
	if not _in_interaction_room:
		return
	_in_interaction_room = false
	_interaction_room.deactivate()
	_set_base_room_active(true)
	_tutorial_stele.set_suspended(false)
	_hud.set_room_mode(false)
	_player.set_spawn_point(SPAWN_POSITION)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.set_anchor_room_bounds(false)
	_player.reset_to_spawn("room_exit", false)
	_hud.set_polarity(true)
	_refresh_hud()


func _set_base_room_active(active: bool) -> void:
	$World/Terrain.visible = active
	for body: StaticBody2D in _collision_bodies:
		body.collision_layer = 1 if active else 0
		body.collision_mask = 1 if active else 0


func toggle_pause() -> void:
	var new_paused: bool = not get_tree().paused
	get_tree().paused = new_paused
	_hud.set_pause_visible(new_paused)
	_player.clear_input_buffers()
	_player.clear_external_force()


func handle_focus_lost() -> void:
	# Physical keys may still be held while the OS takes focus away. Clear the
	# left-Shift latch and double-tap history so returning to the window cannot
	# resume in RUN by accident; held movement keys continue as WALK.
	if _player != null:
		_player.reset_movement_input_state()
	if _in_interaction_room:
		_interaction_room.on_focus_lost()
	if _tutorial_stele != null:
		_tutorial_stele.on_focus_lost()


func _on_window_focus_exited() -> void:
	handle_focus_lost()


func is_paused() -> bool:
	return get_tree().paused


func get_player() -> PrototypePlayer:
	return _player


func get_hud() -> PrototypeHUD:
	return _hud


func get_spawn_position() -> Vector2:
	return SPAWN_POSITION


func get_platform_rects() -> Array[Rect2]:
	return PLATFORM_RECTS.duplicate()


func get_collision_body_count() -> int:
	return _collision_bodies.size()


func is_in_anchor_room() -> bool:
	return _in_anchor_room


func is_in_interaction_room() -> bool:
	return _in_interaction_room


func get_anchor_room() -> AnchorRoom:
	return _anchor_room


func get_interaction_room() -> StarCoreInteractionRoom:
	return _interaction_room
