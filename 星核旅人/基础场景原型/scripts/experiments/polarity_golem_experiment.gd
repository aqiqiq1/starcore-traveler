extends Node2D

## Standalone F6 entry for the approved independent polarity-golem prototype.
##
## It deliberately does not touch main.tscn, level_01/02, player.tscn,
## player.gd, project.godot, the shared HUD or the shared InputMap. J, Tab and
## this room's R handling are read from raw key events; A/D, arrows, Space and Q
## reuse the project's existing runtime actions unchanged.
##
## Room: one 640x360 ruin floor, one optional low wall at the right side
## (x=544..576) that is not between the spawn and the golem. The golem starts
## at x=420 so it is reachable and visible from the spawn at x=80.

const PLAYER_SPAWN: Vector2 = Vector2(80.0, 288.0)
const GOLEM_SPAWN: Vector2 = Vector2(420.0, 288.0)
const GOLEM_START_POSITIVE: bool = true
const FLOOR_TOP: float = 288.0
const WORLD_LEFT: float = 6.0
const WORLD_RIGHT: float = 634.0
const KILL_Y: float = 420.0

const FLOOR_RECT: Rect2 = Rect2(0.0, 288.0, 640.0, 72.0)
const WALL_RECT: Rect2 = Rect2(544.0, 240.0, 32.0, 48.0)
const TILE_SIZE: int = 16
const ATLAS: Texture2D = preload("res://assets/map/ruin_platform_tiles.png")

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const MUTED: Color = Color("#a8bbb7")
const RED: Color = Color("#ff7f72")

@onready var _world: Node2D = $World
@onready var _player = $World/Player
@onready var _golem = $World/Golem
@onready var _hud = $HUD

var _attack_key_down: bool = false
var _last_result: Dictionary = {}
var _collision_bodies: Array[StaticBody2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$World.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Background.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS

	_build_room()

	_player.allow_self_reset = false
	_player.set_spawn_point(PLAYER_SPAWN)
	_player.set_world_bounds(WORLD_LEFT, WORLD_RIGHT)
	_player.set_kill_y(KILL_Y)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.reset_to_spawn("spawn", false)
	_player.attack_hit_window.connect(_on_attack_hit_window)
	_player.polarity_changed.connect(_on_player_polarity_changed)
	_player.reset_performed.connect(_on_player_reset_performed)

	_golem.world_left = 28.0
	_golem.world_right = 612.0
	_golem.floor_y = FLOOR_TOP
	_golem.set_player_target(_player)
	_golem.player_struck.connect(_on_enemy_player_struck)
	_golem.reset_experiment_state(GOLEM_SPAWN, GOLEM_START_POSITIVE)

	_hud.set_player_polarity(_player.is_positive())
	_hud.set_enemy_polarity(_golem.is_positive(), _golem.get_hp(), _golem.get_max_hp())
	_refresh_hud()

	get_window().focus_exited.connect(_on_window_focus_exited)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		_toggle_pause()
	_refresh_hud()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not get_tree().paused and _player != null:
		# Same raw-event forwarding the base room uses: left/right Shift and
		# double-tap bookkeeping need the real physical key and location.
		_player.handle_key_event(key_event)

	if key_event.echo:
		return
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)
	if code == 0:
		return

	if not key_event.pressed:
		if code == KEY_J:
			_attack_key_down = false
		return

	match code:
		KEY_J:
			# Latch on the physical press. Holding J or key-repeat echo cannot
			# start a second swing until the key is released and pressed again.
			if not _attack_key_down:
				_attack_key_down = true
				if not get_tree().paused and _player != null:
					_player.request_attack()
					get_viewport().set_input_as_handled()
		KEY_TAB:
			if not get_tree().paused:
				_toggle_enemy_polarity()
				get_viewport().set_input_as_handled()
		KEY_R:
			reset_experiment()
			get_viewport().set_input_as_handled()


func _build_room() -> void:
	var terrain: TileMapLayer = TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.z_index = -2
	_world.add_child(terrain)

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture = ATLAS
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for atlas_y: int in range(2):
		for atlas_x: int in range(12):
			atlas_source.create_tile(Vector2i(atlas_x, atlas_y))
	var source_id: int = tile_set.add_source(atlas_source)
	terrain.tile_set = tile_set

	_paint_rect(terrain, FLOOR_RECT, source_id)
	_paint_rect(terrain, WALL_RECT, source_id)
	_add_collision_rect(FLOOR_RECT, "FloorCollision")
	_add_collision_rect(WALL_RECT, "WallCollision")

	# A soft ground shadow under the playable strip keeps the single-screen
	# ruin readable without adding any new art asset.
	var shadow: Polygon2D = Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(0.0, 288.0), Vector2(640.0, 288.0),
		Vector2(640.0, 302.0), Vector2(0.0, 302.0),
	])
	shadow.color = Color(0.01, 0.02, 0.02, 0.28)
	shadow.z_index = -1
	_world.add_child(shadow)


func _paint_rect(terrain: TileMapLayer, rect: Rect2, source_id: int) -> void:
	var origin: Vector2i = Vector2i(
		int(rect.position.x) / TILE_SIZE,
		int(rect.position.y) / TILE_SIZE
	)
	var width_tiles: int = int(rect.size.x) / TILE_SIZE
	var height_tiles: int = ceili(rect.size.y / float(TILE_SIZE))
	for row: int in range(height_tiles):
		for column: int in range(width_tiles):
			var atlas_row: int = 0 if row == 0 else 1
			terrain.set_cell(
				origin + Vector2i(column, row),
				source_id,
				Vector2i(_atlas_column(column, width_tiles), atlas_row)
			)


func _atlas_column(column: int, width_tiles: int) -> int:
	if width_tiles <= 1:
		return 1
	if column == 0:
		return 0
	if column == width_tiles - 1:
		return 11
	return 1 + ((column - 1) % 10)


func _add_collision_rect(rect: Rect2, body_name: String) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = body_name
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	_world.add_child(body)
	_collision_bodies.append(body)


func _on_attack_hit_window(swing_id: int, facing: int, positive: bool) -> void:
	var result: Dictionary = _golem.receive_attack(_player, facing, positive, swing_id)
	_last_result = result
	var color: Color = result.get("color", MUTED)
	_hud.show_toast(String(result.get("message", "--")), color)
	_refresh_hud()


func _on_player_polarity_changed(positive: bool) -> void:
	_hud.set_player_polarity(positive)
	_refresh_hud()


func _on_enemy_player_struck(direction: int) -> void:
	var side: String = "右侧" if direction > 0 else "左侧"
	_hud.show_toast("石怪砸击：向%s短退（无伤害，0.6s保护）" % side, RED)


func _on_player_reset_performed(reason: String, _count: int) -> void:
	if reason == "fall":
		_golem.reset_experiment_state(GOLEM_SPAWN, GOLEM_START_POSITIVE)
		_hud.show_toast("跌落重生：石怪回到初始状态", MUTED)
		_refresh_hud()


func _toggle_enemy_polarity() -> void:
	if _golem.toggle_polarity():
		_hud.show_toast("敌方极性：%s" % _golem.get_polarity_label(), _golem.get_polarity_text_color())
	else:
		_hud.show_toast("重组期间极性锁定", MUTED)
	_refresh_hud()


func _toggle_pause() -> void:
	if get_tree().paused:
		_set_paused(false)
	else:
		_set_paused(true)


func _set_paused(value: bool, reason: String = "") -> void:
	get_tree().paused = value
	_hud.set_pause_visible(value, reason)
	_attack_key_down = false
	if _player != null:
		_player.clear_input_buffers()
		_player.clear_external_force()


func _on_window_focus_exited() -> void:
	handle_focus_lost()


## Safe OS focus loss: latch-free pause, no held Shift/double-tap leak.
func handle_focus_lost() -> void:
	if _player != null:
		_player.reset_movement_input_state()
		_player.clear_input_buffers()
	_attack_key_down = false
	if not get_tree().paused:
		_set_paused(true, "窗口失焦：已自动暂停")


## R: one complete experiment restore. Also works while paused and interrupts
## every in-flight swing, pull, knockback and reassembly timer.
func reset_experiment() -> void:
	get_tree().paused = false
	_hud.set_pause_visible(false)
	_attack_key_down = false
	if _player != null:
		_player.set_spawn_point(PLAYER_SPAWN)
		_player.clear_input_buffers()
		_player.clear_external_force()
		_player.reset_to_spawn("experiment_reset", false)
	_golem.reset_experiment_state(GOLEM_SPAWN, GOLEM_START_POSITIVE)
	_last_result = {}
	_hud.show_toast("实验已重开：R", GOLD)
	_refresh_hud()


func _refresh_hud() -> void:
	if _hud == null or _player == null or _golem == null:
		return
	_hud.set_player_polarity(_player.is_positive())
	_hud.set_enemy_polarity(_golem.is_positive(), _golem.get_hp(), _golem.get_max_hp())
	_hud.set_attack_status(_player.get_attack_phase_label())

	var state_name: String = _golem.get_state_name()
	var state_text: String = ""
	var state_color: Color = MUTED
	match state_name:
		"ACTIVE":
			state_text = "活动 / %s" % _golem.get_ai_phase_label()
			state_color = Color("#e9efeb")
			if _golem.get_ai_phase_name() == "ATTACK":
				state_color = RED
		"HURT":
			state_text = "受击"
			state_color = GOLD
		"SCATTERING":
			state_text = "击散中"
			state_color = RED
		"RUBBLE":
			var remaining: float = _golem.get_scatter_wait_remaining()
			state_text = "%.1f秒后重组" % remaining
			state_color = GOLD if remaining <= 1.0 else MUTED
		"REASSEMBLING":
			state_text = "重组中"
			state_color = CYAN
		_:
			state_text = state_name
	_hud.set_enemy_status(state_text, state_color)


func is_paused() -> bool:
	return get_tree().paused


func get_player():
	return _player


func get_golem():
	return _golem


func get_hud():
	return _hud


func get_last_result() -> Dictionary:
	return _last_result


func get_spawn_position() -> Vector2:
	return PLAYER_SPAWN


func get_golem_spawn_position() -> Vector2:
	return GOLEM_SPAWN


func get_floor_rect() -> Rect2:
	return FLOOR_RECT


func get_wall_rect() -> Rect2:
	return WALL_RECT


func get_collision_body_count() -> int:
	return _collision_bodies.size()
