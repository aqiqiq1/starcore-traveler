class_name RiftInversionCrystal
extends Node2D

## Arena floor crystal: touching it flips the player's polarity, then the
## crystal dims for a 2 s cooldown.  This is the Q-less escape hatch on both
## sides of the mirror arena.  It never hurts and never blocks movement.

signal flipped(positive_after: bool)

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const GOLD_PALE: Color = Color("#ffe796")
const CYAN_PALE: Color = Color("#bcffff")
const INK: Color = Color(0.008, 0.018, 0.024, 0.96)
const WHITE: Color = Color(1.0, 0.985, 0.92)
const IRON: Color = Color(0.20, 0.23, 0.24, 1.0)
const READY_PULSE: float = 1.8

@export var cooldown_seconds: float = 2.0
@export var crystal_height: float = 32.0
@export var player_path: NodePath = NodePath()

var _player: Node2D = null
var _area: Area2D = null
var _cooldown_left: float = 0.0
var _flip_count: int = 0
var _flash: float = 0.0
var _time: float = 0.0
var _inside: bool = false


func _ready() -> void:
	z_index = 3
	_build_trigger()
	_resolve_player()
	queue_redraw()


func _build_trigger() -> void:
	_area = Area2D.new()
	_area.name = "Touch"
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitoring = true
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.name = "Shape"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(30.0, 44.0)
	shape_node.shape = shape
	shape_node.position = Vector2(0.0, -22.0)
	_area.add_child(shape_node)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if not player_path.is_empty():
		var target: Node = get_node_or_null(player_path)
		if target is Node2D:
			_player = target as Node2D
			return
	var parent: Node = get_parent()
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child is Node2D and child.has_method("set_polarity_state") \
				and child.has_method("is_positive"):
			_player = child as Node2D
			return


func _process(delta: float) -> void:
	_time += delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	if body != _player:
		return
	if _inside:
		return
	_inside = true
	if _cooldown_left > 0.0 or not is_ready():
		return
	_trigger()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_inside = false


func _trigger() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var positive: bool = not bool(_player.call("is_positive"))
	_player.call("set_polarity_state", positive)
	_cooldown_left = cooldown_seconds
	_flip_count += 1
	_flash = 1.0
	flipped.emit(positive)
	queue_redraw()


# --- public read / test API ------------------------------------------------

func set_player_node(player: Node2D) -> void:
	_player = player
	_inside = false


func is_ready() -> bool:
	return _cooldown_left <= 0.0


func get_cooldown_left() -> float:
	return _cooldown_left


func get_flip_count() -> int:
	return _flip_count


func get_trigger_rect() -> Rect2:
	return Rect2(global_position + Vector2(-15.0, -44.0), Vector2(30.0, 44.0))


func reset_state() -> void:
	_cooldown_left = 0.0
	_flip_count = 0
	_flash = 0.0
	_inside = false
	queue_redraw()


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var ready: bool = is_ready()
	var pulse: float = 0.5 + 0.5 * sin(_time * TAU / READY_PULSE)
	var alpha: float = 1.0 if ready else 0.48
	# Floor base: a small iron socket, not a new platform.
	draw_rect(Rect2(-15.0, -4.0, 30.0, 4.0), INK)
	draw_rect(Rect2(-12.0, -3.0, 24.0, 2.0), IRON)
	draw_rect(Rect2(-4.0, -6.0, 8.0, 2.0), IRON)

	# Floating split crystal: gold left face, cyan right face.
	var tip: Vector2 = Vector2(0.0, -crystal_height - 6.0)
	var left: Vector2 = Vector2(-12.0, -crystal_height * 0.55 - 4.0)
	var right: Vector2 = Vector2(12.0, -crystal_height * 0.55 - 4.0)
	var bottom: Vector2 = Vector2(0.0, -7.0)
	draw_colored_polygon(
		PackedVector2Array([tip, left, bottom]), Color(GOLD, alpha)
	)
	draw_colored_polygon(
		PackedVector2Array([tip, right, bottom]), Color(CYAN, alpha)
	)
	draw_line(tip, left, Color(INK, alpha), 1.0)
	draw_line(left, bottom, Color(INK, alpha), 1.0)
	draw_line(bottom, right, Color(INK, alpha), 1.0)
	draw_line(right, tip, Color(INK, alpha), 1.0)
	# Bright seam and two tiny facet lights.
	draw_line(tip, bottom, Color(WHITE, 0.55 * alpha), 1.0)
	draw_rect(Rect2(-6.0, -crystal_height * 0.72, 2.0, 5.0), Color(GOLD_PALE, alpha))
	draw_rect(Rect2(4.0, -crystal_height * 0.62, 2.0, 4.0), Color(CYAN_PALE, alpha))

	# Tiny sun / moon marks at the crystal shoulders, matching the HUD.
	_draw_sun(Vector2(-18.0, -crystal_height * 0.55), alpha)
	_draw_moon(Vector2(18.0, -crystal_height * 0.55), alpha)

	# Cooldown ring: a 24-pixel arc.  Ready crystals also breathe softly.
	if ready:
		_draw_ring(Vector2(0.0, -crystal_height * 0.55), 18.0,
			Color(GOLD if pulse > 0.5 else CYAN, 0.10 + 0.10 * pulse))
	else:
		var progress: float = 1.0 - _cooldown_left / maxf(cooldown_seconds, 0.01)
		_draw_arc(Vector2(0.0, -crystal_height * 0.55), 18.0, progress)
	if _flash > 0.0:
		_draw_ring(Vector2(0.0, -crystal_height * 0.55), 22.0 + 10.0 * (1.0 - _flash),
			Color(WHITE, 0.55 * _flash))


func _draw_sun(center: Vector2, alpha: float) -> void:
	draw_rect(Rect2(center - Vector2(2.0, 2.0), Vector2(5.0, 5.0)), Color(GOLD, alpha))
	draw_rect(Rect2(center + Vector2(-1.0, -4.0), Vector2(1.0, 2.0)), Color(GOLD_PALE, alpha))
	draw_rect(Rect2(center + Vector2(-1.0, 3.0), Vector2(1.0, 2.0)), Color(GOLD_PALE, alpha))


func _draw_moon(center: Vector2, alpha: float) -> void:
	draw_rect(Rect2(center - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(CYAN, alpha))
	draw_rect(Rect2(center + Vector2(1.0, -3.0), Vector2(2.0, 2.0)), Color(INK, 1.0))
	draw_rect(Rect2(center + Vector2(0.0, -4.0), Vector2(1.0, 1.0)), Color(CYAN_PALE, alpha))


func _draw_ring(center: Vector2, radius: float, color: Color) -> void:
	for index: int in range(24):
		var angle: float = float(index) * TAU / 24.0
		draw_rect(
			Rect2(center + Vector2(round(cos(angle) * radius), round(sin(angle) * radius)),
				Vector2(1.0, 1.0)),
			color
		)


func _draw_arc(center: Vector2, radius: float, progress: float) -> void:
	var count: int = 24
	var lit: int = int(round(clampf(progress, 0.0, 1.0) * count))
	for index: int in range(count):
		var angle: float = -PI * 0.5 + float(index) * TAU / float(count)
		var color: Color = Color(CYAN_PALE, 0.75) if index < lit else Color(IRON, 0.55)
		draw_rect(
			Rect2(center + Vector2(round(cos(angle) * radius), round(sin(angle) * radius)),
				Vector2(1.0, 1.0)),
			color
		)
