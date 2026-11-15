@tool
class_name LevelCheckpoint
extends Area2D

## A small, editable respawn marker. Its node position is the respawn point
## (feet height). The Area2D trigger is centred above that point so walking over
## the marker activates it. The marker uses the approved 40x36 two-state PNG at
## 1:1 with white modulate; the image's foot anchor (20,35) is the ground
## contact, not the last transparent canvas row. Only the trigger box and guide
## text appear in the editor.

signal checkpoint_entered(checkpoint: LevelCheckpoint)

const INACTIVE_TEXTURE: Texture2D = preload("res://assets/checkpoint_exit/checkpoint_inactive.png")
const ACTIVE_TEXTURE: Texture2D = preload("res://assets/checkpoint_exit/checkpoint_active.png")
const TEXTURE_FOOT_ANCHOR: Vector2 = Vector2(20.0, 35.0)
const GUIDE_COLOR: Color = Color(0.38, 0.88, 0.86, 0.75)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

@export var trigger_size: Vector2 = Vector2(40.0, 72.0):
	set(value):
		trigger_size = Vector2(maxf(8.0, value.x), maxf(16.0, value.y))
		_sync_shape()
		queue_redraw()

var _activated: bool = false
var _collision_shape: CollisionShape2D
var _guide_font: Font


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate = Color.WHITE
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_ensure_shape()
	_sync_shape()
	_load_guide_font()
	queue_redraw()


func _ensure_shape() -> void:
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
		if Engine.is_editor_hint() and owner != null:
			_collision_shape.owner = owner


func _sync_shape() -> void:
	if not is_inside_tree():
		return
	_ensure_shape()
	if _collision_shape == null:
		return
	var rect: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		_collision_shape.shape = rect
	rect.size = trigger_size
	_collision_shape.position = Vector2(0.0, -trigger_size.y * 0.5)


func _on_body_entered(body: Node2D) -> void:
	if body is PrototypePlayer:
		# Ignore a queued overlap from before a restart teleported the player
		# back to the opening.
		if absf(body.global_position.x - global_position.x) > trigger_size.x * 0.5 + 10.0:
			return
		checkpoint_entered.emit(self)


func set_activated(value: bool) -> void:
	if _activated == value:
		return
	_activated = value
	queue_redraw()


func is_activated() -> bool:
	return _activated


func get_trigger_rect() -> Rect2:
	return Rect2(Vector2(-trigger_size.x * 0.5, -trigger_size.y), trigger_size)


## The approved art for the current state. The texture is drawn at its native
## 40x36 size, never scaled or tinted.
func get_state_texture() -> Texture2D:
	return ACTIVE_TEXTURE if _activated else INACTIVE_TEXTURE


func get_foot_anchor() -> Vector2:
	return TEXTURE_FOOT_ANCHOR


func get_texture_size() -> Vector2:
	return get_state_texture().get_size()


func get_display_rect() -> Rect2:
	return Rect2(-TEXTURE_FOOT_ANCHOR, get_texture_size())


func _load_guide_font() -> void:
	if _guide_font != null or not ResourceLoader.exists(FONT_PATH):
		return
	var font_file: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if font_file != null:
		var copy: FontFile = font_file.duplicate() as FontFile
		if copy != null:
			copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			copy.hinting = TextServer.HINTING_NONE
			copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			copy.allow_system_fallback = false
			_guide_font = copy


func _draw() -> void:
	draw_texture(get_state_texture(), -TEXTURE_FOOT_ANCHOR)

	if not Engine.is_editor_hint():
		return
	var rect: Rect2 = get_trigger_rect()
	draw_rect(rect, Color(GUIDE_COLOR, 0.07), true)
	_dashed_rect(rect, GUIDE_COLOR)
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, -60.0), Color(GUIDE_COLOR, 0.7), 1.0)
	if _guide_font != null:
		draw_string(
			_guide_font,
			Vector2(8.0, -66.0),
			"恢复点 / 出生点",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			10,
			GUIDE_COLOR
		)


func _dashed_rect(rect: Rect2, color: Color) -> void:
	_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color)
	_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color)
	_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color)
	_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color)


func _dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var length: float = from.distance_to(to)
	if length <= 0.0:
		return
	var direction: Vector2 = (to - from) / length
	var travelled: float = 0.0
	while travelled < length:
		var segment: float = minf(5.0, length - travelled)
		draw_line(from + direction * travelled, from + direction * (travelled + segment), color, 1.0)
		travelled += 9.0
