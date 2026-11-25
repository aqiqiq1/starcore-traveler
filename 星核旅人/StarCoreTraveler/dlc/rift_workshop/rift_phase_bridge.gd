class_name RiftPhaseBridge
extends Node2D

## Rift-workshop phase bridge: a 64 x 10 horizontal light deck that is only
## solid while the player's phase matches `required_positive`.
##
## Matching phase  -> collision layer 1, the player can stand on it.
## Other phase     -> collision layer 0, the deck is gone and the player falls.
##
## Anti-crush rule: the deck never re-materialises inside the player's body.
## If the owner switches phase back while the body still overlaps the 10 px
## slab, solid collision waits until the body is clear (above or below), so a
## quick Q press can never clamp, push or teleport the player.  The chapter
## always places a safe lower shelf under the bridges; falling is a retry, not
## a soft lock.
##
## Presentation reference: Celeste Core Block hot/cold, only for the reading
## order "one solid colour block + central bright core, state before detail".
## Shape, palette, animation and collision are this project's own.

signal solidity_changed(solid: bool)

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const DARK_EDGE: Color = Color(0.004, 0.012, 0.016, 0.96)
const GONE_EDGE: Color = Color(0.55, 0.72, 0.78, 0.30)
const FLASH_TIME: float = 0.22

@export var required_positive: bool = true
@export var bridge_width: float = 64.0
@export var bridge_height: float = 10.0
@export var player_path: NodePath = NodePath()

var _player: Node2D = null
var _blocker: StaticBody2D = null
var _shape: CollisionShape2D = null
var _solid: bool = false
var _flash: float = 0.0
var _time: float = 0.0
var _deferred_reforms: int = 0


func _ready() -> void:
	_blocker = get_node_or_null("Blocker") as StaticBody2D
	_shape = get_node_or_null("Blocker/CollisionShape2D") as CollisionShape2D
	if _shape != null:
		var rect: RectangleShape2D = _shape.shape as RectangleShape2D
		if rect == null:
			rect = RectangleShape2D.new()
			_shape.shape = rect
		rect.size = Vector2(bridge_width, bridge_height)
		_shape.position = Vector2(bridge_width * 0.5, bridge_height * 0.5)
	_resolve_player()
	_solid = _compute_desired()
	_apply_collision()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	var desired: bool = _compute_desired()
	var solid_now: bool = desired
	if desired and _player_overlaps():
		# Never solidify inside the body.  Wait until the fall has carried the
		# player clear of the slab.
		solid_now = false
		_deferred_reforms += 1
	if solid_now != _solid:
		_solid = solid_now
		_apply_collision()
		if _solid:
			_flash = 1.0
		solidity_changed.emit(_solid)


# --- public read API -------------------------------------------------------

func is_solid() -> bool:
	return _solid


func is_player_inside() -> bool:
	return _player_overlaps()


func get_required_positive() -> bool:
	return required_positive


func get_bridge_size() -> Vector2:
	return Vector2(bridge_width, bridge_height)


func get_bridge_rect() -> Rect2:
	return Rect2(global_position, Vector2(bridge_width, bridge_height))


func get_player_rect() -> Rect2:
	if _player == null or not is_instance_valid(_player):
		return Rect2()
	var size: Vector2 = Vector2(12.0, 30.0)
	if _player.has_method("get_collision_size"):
		size = _player.call("get_collision_size") as Vector2
	return Rect2(
		_player.global_position + Vector2(-size.x * 0.5, -size.y),
		size
	)


func get_collision_layer() -> int:
	if _blocker == null:
		return -1
	return _blocker.collision_layer


func get_state_name() -> String:
	return "solid" if _solid else "gone"


func get_deferred_reform_count() -> int:
	return _deferred_reforms


# --- public write API (scene wiring / tests) -------------------------------

func set_required_positive(value: bool) -> void:
	required_positive = value
	_solid = _compute_desired()
	_apply_collision()
	queue_redraw()


func set_player_node(player: Node2D) -> void:
	_player = player
	_solid = _compute_desired()
	_apply_collision()
	queue_redraw()


# --- internals -------------------------------------------------------------

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
		if child is Node2D and child.has_method("is_positive") \
				and child.has_method("get_collision_size"):
			_player = child as Node2D
			return


func _compute_desired() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return bool(_player.call("is_positive")) == required_positive


func _player_overlaps() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return get_player_rect().intersects(get_bridge_rect())


func _apply_collision() -> void:
	if _blocker == null:
		return
	var layer: int = 1 if _solid else 0
	if _blocker.collision_layer != layer:
		_blocker.collision_layer = layer


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var color: Color = GOLD if required_positive else CYAN
	var w: float = bridge_width
	var h: float = bridge_height
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)

	if not _solid:
		# Ghost state: 1 px dashed outline plus a few drifting sparks.  Empty
		# middle, so "not standable" is obvious at a glance.
		var dash: int = 4
		var x: float = 0.0
		while x < w:
			var length: float = minf(float(dash), w - x)
			draw_rect(Rect2(x, 0.0, length, 1.0), GONE_EDGE)
			draw_rect(Rect2(x, h - 1.0, length, 1.0), Color(GONE_EDGE, 0.5))
			x += float(dash) + 4.0
		draw_rect(Rect2(0.0, 0.0, 1.0, h), Color(GONE_EDGE, 0.6))
		draw_rect(Rect2(w - 1.0, 0.0, 1.0, h), Color(GONE_EDGE, 0.6))
		for index: int in range(3):
			var spark_x: float = fmod(_time * 12.0 + float(index) * 23.0, w)
			var spark_alpha: float = 0.25 + 0.35 * absf(sin(_time * 2.0 + float(index)))
			draw_rect(Rect2(spark_x, 4.0 + float(index % 2), 1.0, 1.0),
				Color(color, spark_alpha))
		return

	# Solid: dark silhouette, saturated body, bright core stripe and end caps.
	# A 3 px soft glow above and a 2 px dim echo below give the thin 64x10 deck
	# enough presence to read as a light bridge without changing its collision.
	draw_rect(Rect2(0.0, -3.0, w, 3.0), Color(color, 0.10 + 0.04 * pulse))
	draw_rect(Rect2(0.0, h, w, 2.0), Color(color, 0.10))
	draw_rect(Rect2(0.0, 0.0, w, h), DARK_EDGE)
	draw_rect(Rect2(1.0, 1.0, w - 2.0, h - 2.0), Color(color, 0.46 + 0.06 * pulse))
	draw_rect(Rect2(1.0, 3.0, w - 2.0, 4.0), Color(color, 0.82))
	draw_rect(Rect2(1.0, 4.0, w - 2.0, 2.0), color.lerp(Color.WHITE, 0.42))
	# End caps make the 64 px span read as a built deck, not a stretched bar.
	draw_rect(Rect2(0.0, 0.0, 3.0, h), Color(color, 0.96))
	draw_rect(Rect2(w - 3.0, 0.0, 3.0, h), Color(color, 0.96))
	draw_rect(Rect2(2.0, 1.0, 1.0, h - 2.0), Color(color.lightened(0.35), 0.9))
	draw_rect(Rect2(w - 3.0, 1.0, 1.0, h - 2.0), Color(color.lightened(0.35), 0.9))
	# Energy ticks every 8 px, fixed (no scrolling) so the deck is a stable
	# landing surface to read while moving.
	var tick_x: float = 6.0
	while tick_x < w - 5.0:
		draw_rect(Rect2(tick_x, 1.0, 1.0, 1.0), Color(1.0, 0.98, 0.9, 0.55))
		draw_rect(Rect2(tick_x, h - 2.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 0.35))
		tick_x += 8.0
	if _flash > 0.0:
		draw_rect(Rect2(0.0, 0.0, w, h), Color(1.0, 1.0, 1.0, 0.55 * _flash))
