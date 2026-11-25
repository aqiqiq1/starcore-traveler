class_name LoomNode
extends Node2D

## One orbiting polarity node of the 星核织机.
##
## The node is a target, not a contact hazard.  It orbits the central core on an
## ellipse, flips polarity on its own timer, and only an opposite-phase J hit
## breaks it (the chapter resolves the swing; same phase is a bounce).
##
## Art: assets/city/loom_node_city_40x40_2f.png, a dark-outlined ivory disc
## modulated to bright gold / cyan, with a code-drawn white heart, a polarity
## ring and four short orbit arcs.  The draw order keeps the heart white when
## the body is tinted, so both nodes read at 1x over the dark weave face.

signal broken(node: LoomNode)
signal phase_flipped(node: LoomNode, positive: bool)

const SPRITE: Texture2D = preload(
	"res://dlc/star_loom/assets/city/loom_node_city_40x40_2f.png"
)
const GOLD: Color = Color("#ffdf8a")
const CYAN: Color = Color("#7ff3ef")
const WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
const OUTLINE: Color = Color(0.02, 0.015, 0.05, 0.9)

@export var start_positive: bool = true
@export var orbit_speed: float = 1.15
@export var phase_period: float = 2.6

var _sprite: Sprite2D = null
var _center: Vector2 = Vector2(700.0, 240.0)
var _radius: Vector2 = Vector2(120.0, 50.0)
var _angle: float = 0.0
var _positive: bool = true
var _alive: bool = true
var _active: bool = false
var _phase_left: float = 0.0
var _time: float = 0.0
var _break_time: float = 0.0
var _deny_flash: float = 0.0
var _flip_flash: float = 0.0
var _orbit_enabled: bool = true
var _phase_timer_enabled: bool = true
var _core_global: Vector2 = Vector2(700.0, 240.0)


func _ready() -> void:
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.texture = SPRITE
	_sprite.hframes = 2
	_sprite.vframes = 1
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The code-drawn white heart, polarity ring and orbit arcs stay over the
	# tinted body.
	_sprite.show_behind_parent = true
	add_child(_sprite)
	_positive = start_positive
	_phase_left = phase_period
	_apply_visual()
	queue_redraw()


func configure(
	center: Vector2, angle: float, positive: bool,
	radius: Vector2 = Vector2(120.0, 50.0)
) -> void:
	_center = center
	_core_global = center
	_radius = radius
	_angle = angle
	_positive = positive
	_alive = true
	_break_time = 0.0
	_deny_flash = 0.0
	_flip_flash = 0.0
	_phase_left = phase_period
	_time = 0.0
	position = _orbit_point()
	_apply_visual()
	queue_redraw()


func set_active(value: bool) -> void:
	_active = value
	if _sprite != null:
		_sprite.visible = value and _alive
	if value:
		_apply_visual()
	queue_redraw()


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_deny_flash = maxf(_deny_flash - delta / 0.24, 0.0)
	_flip_flash = maxf(_flip_flash - delta / 0.18, 0.0)
	if not _alive:
		_break_time += delta
		queue_redraw()
		return
	if _orbit_enabled:
		_angle = fmod(_angle + orbit_speed * delta, TAU)
		position = _orbit_point()
	if _phase_timer_enabled:
		_phase_left -= delta
		if _phase_left <= 0.0:
			_phase_left = phase_period
			set_phase(not _positive)
	if _sprite != null:
		_sprite.frame = int(_time * 5.0) % 2
	queue_redraw()


func _orbit_point() -> Vector2:
	return _center + Vector2(cos(_angle) * _radius.x, sin(_angle) * _radius.y)


func _apply_visual() -> void:
	if _sprite == null:
		return
	_sprite.modulate = GOLD if _positive else CYAN
	_sprite.visible = _active and _alive


func set_phase(value: bool) -> void:
	if _positive == value:
		return
	_positive = value
	_flip_flash = 1.0
	_apply_visual()
	phase_flipped.emit(self, _positive)
	queue_redraw()


func is_positive() -> bool:
	return _positive


func is_alive() -> bool:
	return _alive


func get_phase_time_left() -> float:
	return _phase_left


func get_orbit_angle() -> float:
	return _angle


func get_core_position() -> Vector2:
	return _core_global


## Generous 40x40 target box: the approved J arc is 38x40, so a node passing low
## in its orbit is hittable without pixel-perfect standing.
func get_hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(20.0, 20.0), Vector2(40.0, 40.0))


func flash_deny() -> void:
	_deny_flash = 1.0
	queue_redraw()


func break_node() -> void:
	if not _alive:
		return
	_alive = false
	_break_time = 0.0
	if _sprite != null:
		_sprite.visible = false
	broken.emit(self)
	queue_redraw()


## Full reset for a retry / R / stage change.
func reset_node(angle: float, positive: bool) -> void:
	_alive = true
	_angle = angle
	_positive = positive
	_phase_left = phase_period
	_time = 0.0
	_break_time = 0.0
	_deny_flash = 0.0
	_flip_flash = 0.0
	position = _orbit_point()
	_apply_visual()
	queue_redraw()


# --- test / capture hooks --------------------------------------------------

func debug_set_angle(angle: float) -> void:
	_angle = angle
	position = _orbit_point()
	queue_redraw()


func debug_set_phase(value: bool) -> void:
	_positive = value
	_apply_visual()
	queue_redraw()


func set_orbit_enabled(value: bool) -> void:
	_orbit_enabled = value


func set_phase_timer_enabled(value: bool) -> void:
	_phase_timer_enabled = value


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	if not _active:
		return
	var phase_color: Color = GOLD if _positive else CYAN
	# Tether to the core: a dashed 1 px thread, so the node clearly belongs to
	# the loom instead of floating as a loose object.
	var core_local: Vector2 = to_local(_core_global)
	var tether_length: float = core_local.length()
	if tether_length > 20.0:
		var direction: Vector2 = core_local / tether_length
		var travelled: float = 26.0
		while travelled < tether_length - 48.0:
			draw_rect(
				Rect2(direction * travelled - Vector2(0.5, 0.5), Vector2(1.0, 1.0)),
				Color(phase_color, 0.20)
			)
			travelled += 7.0
	if not _alive:
		var t: float = clampf(_break_time / 0.36, 0.0, 1.0)
		if t >= 1.0:
			return
		var burst: float = 1.0 - t
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color(1.0, 1.0, 1.0, burst))
		for index: int in range(8):
			var angle: float = float(index) * TAU / 8.0 + 0.3
			var radius: float = 4.0 + 26.0 * t
			var size: float = 3.0 - 2.0 * t
			draw_rect(
				Rect2(
					Vector2(cos(angle), sin(angle)) * radius - Vector2(1.0, 1.0),
					Vector2(size, size)
				),
				Color(phase_color, 0.9 * burst)
			)
		return

	# White heart, polarity ring and four short orbit arcs.  The heart stays
	# white while the body is gold/cyan, so the target is readable on the dark
	# weave face.
	_ring(22.0, Color(phase_color, 0.65))
	for index in range(4):
		var mid: float = float(index) * TAU / 4.0 + _time * 0.45
		_arc(25.0, mid - 0.16, mid + 0.16, Color(phase_color, 0.80), 8)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), WHITE)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color(0.14, 0.11, 0.09, 1.0))
	draw_rect(Rect2(-3.0, -4.0, 1.0, 1.0), WHITE)
	if _flip_flash > 0.0:
		_ring(24.0 + 3.0 * (1.0 - _flip_flash), Color(1.0, 1.0, 1.0, 0.85 * _flip_flash))
	if _deny_flash > 0.0:
		_ring(27.0 + 5.0 * (1.0 - _deny_flash), Color(1.0, 1.0, 1.0, 0.9 * _deny_flash))

	# Glyph above the node: gold diamond / cyan double bar.
	var glyph_y: float = -34.0
	if _positive:
		for offset: Vector2 in [
			Vector2(0.0, -2.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
			Vector2(0.0, 0.0), Vector2(-2.0, -1.0), Vector2(2.0, -1.0),
		]:
			draw_rect(Rect2(offset + Vector2(0.0, glyph_y) - Vector2(0.5, 0.5), Vector2(1.0, 1.0)), phase_color)
	else:
		draw_rect(Rect2(-3.0, glyph_y - 1.0, 6.0, 1.0), phase_color)
		draw_rect(Rect2(-3.0, glyph_y + 1.0, 6.0, 1.0), phase_color)


func _arc(radius: float, start: float, end: float, color: Color, steps: int) -> void:
	for index in range(steps + 1):
		var angle: float = lerpf(start, end, float(index) / float(maxi(steps, 1)))
		draw_rect(
			Rect2(round(cos(angle) * radius), round(sin(angle) * radius), 1.0, 1.0),
			color
		)


func _ring(radius: float, color: Color) -> void:
	var segments: int = 28
	for index: int in range(segments):
		var angle: float = float(index) * TAU / float(segments)
		draw_rect(
			Rect2(round(cos(angle) * radius), round(sin(angle) * radius), 1.0, 1.0),
			color
		)
