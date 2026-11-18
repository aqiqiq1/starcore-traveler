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
## First/again unavailable->available edge: a short visible unfold in front of
## the unchanged 8-frame loop. It animates real coverage (the frame is revealed
## from the doorway threshold upward) and brightness, not one whole-sprite alpha.
## Gameplay timing (trigger/passable/completed) never waits for it.
const GATE_FX_UNFOLD_TIME: float = 0.62
const GATE_FX_UNFOLD_ALPHA_TIME: float = 0.18
## Starts over the sheet's real threshold dashes. Frame 0 keeps ~6 px of
## transparent padding under its art, so 12 px shows the threshold band at once.
const GATE_FX_UNFOLD_MIN_HEIGHT: float = 12.0
const GATE_FX_UNFOLD_BRIGHTNESS: float = 0.62
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
var _gate_fx_unfold_sprite: Sprite2D = null
var _gate_available: bool = false
var _gate_fx_time: float = 0.0
var _gate_fx_unfolding: bool = false
var _gate_fx_unfold_time: float = 0.0


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
## Only a real unavailable->available edge starts the unfold; repeated set(true)
## is a no-op, and set(false)/completed clean the transient state up.
func set_gate_available(value: bool) -> void:
	var was_available: bool = _gate_available
	_gate_available = value
	if value != was_available:
		if value and not _completed:
			_start_gate_fx_unfold()
		elif not value:
			_reset_gate_fx_state()
	_sync_gate_fx_visibility()


func is_gate_available() -> bool:
	return _gate_available


func get_gate_fx_sprite() -> Sprite2D:
	return _gate_fx_sprite


func is_gate_fx_visible() -> bool:
	return _gate_fx_sprite != null and _gate_fx_sprite.visible


func get_gate_fx_frame() -> int:
	return _gate_fx_sprite.frame if _gate_fx_sprite != null else -1


## True only while the short threshold->curtain unfold is running.
func is_gate_fx_unfolding() -> bool:
	return _gate_fx_unfolding


## 0..1 unfold progress; 1 in the steady loop.
func get_gate_fx_unfold_progress() -> float:
	if not _gate_fx_unfolding:
		return 1.0
	return clampf(_gate_fx_unfold_time / GATE_FX_UNFOLD_TIME, 0.0, 1.0)


## Visible frame height during the unfold (px). -1 when not unfolding.
func get_gate_fx_unfold_height() -> float:
	if not _gate_fx_unfolding or _gate_fx_unfold_sprite == null:
		return -1.0
	return _gate_fx_unfold_sprite.region_rect.size.y


func get_gate_fx_unfold_sprite() -> Sprite2D:
	return _gate_fx_unfold_sprite


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
	# Unfold layer: same approved sheet and anchor, framed only by region_rect
	# so the real art is revealed bottom-up (no stretch, no extra effect).
	_gate_fx_unfold_sprite = Sprite2D.new()
	_gate_fx_unfold_sprite.name = "GatePortalUnfold"
	_gate_fx_unfold_sprite.texture = gate_portal_fx_sheet
	_gate_fx_unfold_sprite.hframes = 1
	_gate_fx_unfold_sprite.vframes = 1
	_gate_fx_unfold_sprite.centered = false
	_gate_fx_unfold_sprite.position = -TEXTURE_FOOT_ANCHOR
	_gate_fx_unfold_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gate_fx_unfold_sprite.z_index = -1
	_gate_fx_unfold_sprite.region_enabled = true
	_gate_fx_unfold_sprite.region_rect = Rect2(0.0, 0.0, 0.0, 0.0)
	_gate_fx_unfold_sprite.visible = false
	add_child(_gate_fx_unfold_sprite)
	_sync_gate_fx_visibility()


func _gate_fx_frame_size() -> Vector2:
	if gate_portal_fx_sheet == null:
		return Vector2.ZERO
	return Vector2(
		gate_portal_fx_sheet.get_width() / float(GATE_FX_FRAMES),
		gate_portal_fx_sheet.get_height()
	)


func _start_gate_fx_unfold() -> void:
	if _gate_fx_sprite == null or _gate_fx_unfold_sprite == null:
		return
	if _gate_fx_frame_size().y <= 0.0:
		return
	_gate_fx_unfolding = true
	_gate_fx_unfold_time = 0.0
	_gate_fx_time = 0.0
	_gate_fx_sprite.frame = 0
	# The steady loop is present (is_gate_fx_visible()) but transparent during
	# the unfold; the reveal layer is the only thing drawn.
	_gate_fx_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_gate_fx_unfold_sprite.visible = true
	_apply_gate_fx_unfold()


func _apply_gate_fx_unfold() -> void:
	if _gate_fx_unfold_sprite == null:
		return
	var frame_size: Vector2 = _gate_fx_frame_size()
	var t: float = clampf(_gate_fx_unfold_time / GATE_FX_UNFOLD_TIME, 0.0, 1.0)
	var spread: float = smoothstep(0.06, 0.86, t)
	var height: float = lerpf(GATE_FX_UNFOLD_MIN_HEIGHT, frame_size.y, spread)
	# Frame 0 of the approved sheet, bottom rows only: the curtain rises out of
	# the doorway's threshold instead of the whole sprite fading in.
	_gate_fx_unfold_sprite.region_rect = Rect2(0.0, frame_size.y - height,
		frame_size.x, height)
	_gate_fx_unfold_sprite.position = Vector2(
		-TEXTURE_FOOT_ANCHOR.x,
		-TEXTURE_FOOT_ANCHOR.y + frame_size.y - height
	)
	var alpha: float = clampf(_gate_fx_unfold_time / GATE_FX_UNFOLD_ALPHA_TIME, 0.0, 1.0)
	var brightness: float = lerpf(GATE_FX_UNFOLD_BRIGHTNESS, 1.0,
		smoothstep(0.0, 0.7, t))
	_gate_fx_unfold_sprite.modulate = Color(brightness, brightness, brightness, alpha)


func _finish_gate_fx_unfold() -> void:
	_gate_fx_unfolding = false
	_gate_fx_unfold_time = 0.0
	_gate_fx_time = 0.0
	if _gate_fx_unfold_sprite != null:
		_gate_fx_unfold_sprite.visible = false
		_gate_fx_unfold_sprite.region_rect = Rect2(0.0, 0.0, 0.0, 0.0)
		_gate_fx_unfold_sprite.modulate = Color.WHITE
	if _gate_fx_sprite != null:
		_gate_fx_sprite.modulate = Color.WHITE
		_gate_fx_sprite.frame = 0


func _reset_gate_fx_state() -> void:
	_finish_gate_fx_unfold()


func _sync_gate_fx_visibility() -> void:
	if _gate_fx_sprite == null:
		return
	var show: bool = gate_portal_fx_enabled and _gate_available and not _completed
	_gate_fx_sprite.visible = show
	if not show:
		_reset_gate_fx_state()
	elif not _gate_fx_unfolding:
		_gate_fx_sprite.modulate = Color.WHITE


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _gate_fx_sprite == null:
		return
	var show: bool = gate_portal_fx_enabled and _gate_available and not _completed
	if not show:
		if _gate_fx_sprite.visible or _gate_fx_unfolding:
			_sync_gate_fx_visibility()
		return
	if not _gate_fx_sprite.visible:
		_gate_fx_sprite.visible = true
	# Pause freezes whatever stage is on screen; gameplay timing is unaffected.
	if get_tree() != null and get_tree().paused:
		return
	if _gate_fx_unfolding:
		_gate_fx_unfold_time += delta
		if _gate_fx_unfold_time >= GATE_FX_UNFOLD_TIME:
			_finish_gate_fx_unfold()
		else:
			_apply_gate_fx_unfold()
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
