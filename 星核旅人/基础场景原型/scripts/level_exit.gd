@tool
class_name LevelExit
extends Area2D

## The formal level exit. Reaching this area finishes level 01; it is not a
## second-level transition. The gate uses the approved 76x100 two-state PNG at
## 1:1 with white modulate. Its foot anchor (38,99) is the ground contact and the
## opening is transparent, so the background shows through. Only the trigger box
## and label guide are editor extras.

signal player_reached_exit

const OPEN_TEXTURE: Texture2D = preload("res://assets/checkpoint_exit/exit_open.png")
const COMPLETED_TEXTURE: Texture2D = preload("res://assets/checkpoint_exit/exit_completed.png")
const DEFAULT_GATE_FX_SHEET: Texture2D = preload("res://assets/checkpoint_exit/gate_portal_fx_v2_8f.png")
const TEXTURE_FOOT_ANCHOR: Vector2 = Vector2(38.0, 99.0)
const GATE_FX_FRAMES: int = 8
const GATE_FX_FPS: float = 8.0
const GOLD: Color = Color("#f4cd63")
const OPEN_LABEL_COLOR: Color = Color("#e7eceb")
const GUIDE_COLOR: Color = Color(0.95, 0.80, 0.40, 0.8)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

@export var trigger_size: Vector2 = Vector2(36.0, 76.0):
	set(value):
		trigger_size = Vector2(maxf(8.0, value.x), maxf(16.0, value.y))
		_sync_shape()
		queue_redraw()

@export var label_text: String = "出口"
## Every LevelExit now owns the approved v2 portal FX by default. The level
## still controls its real availability with set_gate_available(); no new door
## needs a separate sheet or animation script. gate_portal_fx_enabled remains a
## default-on opt-out for future non-interactive exits.
@export var gate_portal_fx_enabled: bool = true
@export var gate_portal_fx_sheet: Texture2D = DEFAULT_GATE_FX_SHEET

var _completed: bool = false
var _collision_shape: CollisionShape2D
var _guide_font: Font
var _gate_fx_sprite: Sprite2D = null
var _gate_available: bool = false
var _gate_fx_time: float = 0.0


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
	_ensure_gate_fx()
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
	if _completed:
		return
	if body is PrototypePlayer:
		# A restart can re-enable monitoring on the same physics frame the
		# player is teleported back to the opening. Ignore queued overlaps that
		# no longer match the trigger's actual position.
		if absf(body.global_position.x - global_position.x) > trigger_size.x * 0.5 + 10.0:
			return
		player_reached_exit.emit()


func set_completed(value: bool) -> void:
	_completed = value
	# set_completed() is called from the Area2D body_entered signal on the
	# completion frame. Godot blocks monitoring changes inside that signal, so
	# defer only the monitoring flag; the completion guard above is immediate.
	set_deferred("monitoring", not value)
	_sync_gate_fx_visibility()
	queue_redraw()


func is_completed() -> bool:
	return _completed


## Every level supplies its real passable state here. Level 01 uses its
## gameplay lifecycle; locked exits such as level 02 use the actual gate condition.
func set_gate_available(value: bool) -> void:
	_gate_available = value
	_sync_gate_fx_visibility()


func is_gate_available() -> bool:
	return _gate_available


func get_gate_fx_sprite() -> Sprite2D:
	return _gate_fx_sprite


func is_gate_fx_visible() -> bool:
	return _gate_fx_sprite != null and _gate_fx_sprite.visible


func get_gate_fx_frame() -> int:
	return _gate_fx_sprite.frame if _gate_fx_sprite != null else -1


func get_gate_fx_frames() -> int:
	return GATE_FX_FRAMES


func get_gate_fx_fps() -> float:
	return GATE_FX_FPS


func _ensure_gate_fx() -> void:
	if not gate_portal_fx_enabled or gate_portal_fx_sheet == null:
		return
	if Engine.is_editor_hint() or _gate_fx_sprite != null:
		return
	_gate_fx_sprite = Sprite2D.new()
	_gate_fx_sprite.name = "GatePortalFX"
	_gate_fx_sprite.texture = gate_portal_fx_sheet
	_gate_fx_sprite.hframes = GATE_FX_FRAMES
	_gate_fx_sprite.vframes = 1
	_gate_fx_sprite.frame = 0
	_gate_fx_sprite.centered = false
	_gate_fx_sprite.position = -TEXTURE_FOOT_ANCHOR
	_gate_fx_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The approved v2 sheet belongs behind the original exit_open frame.
	_gate_fx_sprite.z_index = -1
	_gate_fx_sprite.visible = false
	add_child(_gate_fx_sprite)
	_sync_gate_fx_visibility()


func _sync_gate_fx_visibility() -> void:
	if _gate_fx_sprite == null:
		return
	var show: bool = gate_portal_fx_enabled and _gate_available and not _completed
	_gate_fx_sprite.visible = show
	if not show:
		_gate_fx_time = 0.0
		_gate_fx_sprite.frame = 0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _gate_fx_sprite == null:
		return
	var show: bool = gate_portal_fx_enabled and _gate_available and not _completed
	_gate_fx_sprite.visible = show
	if not show:
		_gate_fx_time = 0.0
		_gate_fx_sprite.frame = 0
		return
	if get_tree() != null and get_tree().paused:
		return
	_gate_fx_time += delta
	_gate_fx_sprite.frame = int(_gate_fx_time * GATE_FX_FPS) % GATE_FX_FRAMES


func get_trigger_rect() -> Rect2:
	return Rect2(Vector2(-trigger_size.x * 0.5, -trigger_size.y), trigger_size)


## The approved art for the current state. The texture is drawn at its native
## 76x100 size, never scaled or tinted.
func get_state_texture() -> Texture2D:
	return COMPLETED_TEXTURE if _completed else OPEN_TEXTURE


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

	if _guide_font != null:
		var text_width: float = _guide_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
		draw_string(
			_guide_font,
			Vector2(-text_width * 0.5, -TEXTURE_FOOT_ANCHOR.y - 6.0),
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			GOLD if _completed else OPEN_LABEL_COLOR
		)

	if not Engine.is_editor_hint():
		return
	var rect: Rect2 = get_trigger_rect()
	draw_rect(rect, Color(GUIDE_COLOR, 0.06), true)
	_dashed_rect(rect, GUIDE_COLOR)
	if _guide_font != null:
		draw_string(
			_guide_font,
			Vector2(-TEXTURE_FOOT_ANCHOR.x, -TEXTURE_FOOT_ANCHOR.y - 24.0),
			"出口触发区",
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
