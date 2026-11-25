class_name LoomCore
extends Node2D

## The central core of 星核织机.
##
## Two orbiting nodes shield it.  Once both nodes are broken the core opens:
## only an opposite-phase J true hit counts, and the core changes phase after
## every accepted hit (3 per stage).  The boss body is a generated 96x96
## two-frame sprite; the exposed core, shield and hit flashes are drawn in code
## with integer rectangles, so the state reads at 1x without a screen-filling
## glow.
##
## The sprite is centred on this node.  The shield ring is drawn outside it, and
## the exposed core is drawn over the dark socket baked into the art.

const SPRITE: Texture2D = preload(
	"res://dlc/star_loom/assets/sprites/loom_boss_96x96_2f.png"
)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const WHITE: Color = Color(1.0, 0.98, 0.94, 1.0)
const INK: Color = Color(0.02, 0.01, 0.05, 1.0)
const DARK: Color = Color(0.16, 0.08, 0.24, 1.0)

var _sprite: Sprite2D = null
var _positive: bool = true
var _exposed: bool = false
var _active: bool = false
var _defeated: bool = false
var _time: float = 0.0
var _hit_flash: float = 0.0
var _shield_flash: float = 0.0
var _expose_flash: float = 0.0


func _ready() -> void:
	z_index = 4
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.texture = SPRITE
	_sprite.hframes = 2
	_sprite.vframes = 1
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The parent's own _draw() paints the exposed core / shield / hit flashes.
	# A child canvas item would otherwise cover the centre socket, so the body
	# sprite is explicitly drawn behind this node's drawing.
	_sprite.show_behind_parent = true
	add_child(_sprite)
	_apply_visual()
	queue_redraw()


func configure() -> void:
	_positive = true
	_exposed = false
	_active = false
	_defeated = false
	_time = 0.0
	_hit_flash = 0.0
	_shield_flash = 0.0
	_expose_flash = 0.0
	_apply_visual()
	queue_redraw()


func set_active(value: bool) -> void:
	_active = value
	_apply_visual()
	queue_redraw()


func is_active() -> bool:
	return _active


func set_phase(value: bool) -> void:
	if _positive == value:
		return
	_positive = value
	queue_redraw()


func get_phase() -> bool:
	return _positive


func is_positive() -> bool:
	return _positive


func set_exposed(value: bool) -> void:
	if _exposed == value:
		return
	_exposed = value
	if value:
		_expose_flash = 1.0
	queue_redraw()


func is_exposed() -> bool:
	return _exposed


func set_defeated(value: bool) -> void:
	_defeated = value
	_exposed = false
	_apply_visual()
	queue_redraw()


func is_defeated() -> bool:
	return _defeated


func flash_hit() -> void:
	_hit_flash = 1.0
	queue_redraw()


func flash_shield() -> void:
	_shield_flash = 1.0
	queue_redraw()


func get_hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(40.0, 42.0), Vector2(80.0, 84.0))


func _process(delta: float) -> void:
	_time += delta
	_hit_flash = maxf(_hit_flash - delta / 0.28, 0.0)
	_shield_flash = maxf(_shield_flash - delta / 0.22, 0.0)
	_expose_flash = maxf(_expose_flash - delta / 0.45, 0.0)
	if _sprite != null:
		_sprite.frame = int(_time * 3.0) % 2
	queue_redraw()


func _apply_visual() -> void:
	if _sprite == null:
		return
	if _defeated:
		_sprite.modulate = Color(0.42, 0.40, 0.46, 0.85)
	elif not _active:
		_sprite.modulate = Color(0.62, 0.64, 0.70, 0.92)
	else:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var phase_color: Color = GOLD if _positive else CYAN
	if _defeated:
		# Three snapped threads hanging from the dead frame.
		for index: int in range(3):
			var x: float = -26.0 + 26.0 * float(index)
			draw_rect(Rect2(x, 24.0, 1.0, 20.0 + 4.0 * float(index)), Color(0.55, 0.46, 0.34, 0.5))
		return

	if not _active:
		# Dormant: one dull thread ring, no shield, no exposed core.
		_ring(52.0, Color(0.46, 0.50, 0.56, 0.25), 28)
		return

	if not _exposed:
		# Shielded: a segmented ring plus six spokes.  Phase colour is the same
		# gold / cyan language as the nodes; the ring is the "not yet" read.
		var pulse: float = 0.5 + 0.5 * sin(_time * 2.4)
		_ring(54.0, Color(phase_color, 0.55 + 0.15 * pulse), 36)
		_ring(58.0, Color(phase_color, 0.18 + 0.08 * pulse), 36)
		for index: int in range(6):
			var angle: float = float(index) * TAU / 6.0 + _time * 0.18
			var inner: Vector2 = Vector2(cos(angle), sin(angle)) * 52.0
			var outer: Vector2 = Vector2(cos(angle), sin(angle)) * 62.0
			draw_rect(Rect2(inner - Vector2(0.5, 0.5), Vector2(1.0, 1.0)), Color(phase_color, 0.5))
			draw_rect(Rect2(outer - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(phase_color, 0.7))
		if _shield_flash > 0.0:
			_ring(58.0 + 6.0 * (1.0 - _shield_flash), Color(1.0, 1.0, 1.0, 0.85 * _shield_flash), 36)
		if _expose_flash > 0.0:
			_ring(20.0 + 50.0 * (1.0 - _expose_flash), Color(1.0, 1.0, 1.0, 0.5 * _expose_flash), 30)
		return

	# Exposed core: a diamond eye with a white centre, drawn over the socket.
	var pulse2: float = 0.5 + 0.5 * sin(_time * 4.0)
	_ring(22.0 + 2.0 * pulse2, Color(phase_color, 0.30 + 0.15 * pulse2), 24)
	var half: float = 11.0 + 1.0 * pulse2
	# Dark 1 px outline around the diamond.
	_diamond(half + 1.0, INK)
	_diamond(half, phase_color)
	_diamond(6.0, DARK)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), WHITE)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color(1.0, 1.0, 1.0, 1.0))
	# Four small sparks on the diagonal, so the core reads even when the
	# player's talisman is the same colour.
	for direction: Vector2 in [
		Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0),
	]:
		draw_rect(
			Rect2(direction * (half + 5.0) - Vector2(0.5, 0.5), Vector2(1.0, 1.0)),
			Color(WHITE, 0.75)
		)
	if _hit_flash > 0.0:
		_ring(24.0 + 34.0 * (1.0 - _hit_flash), Color(1.0, 1.0, 1.0, 0.9 * _hit_flash), 30)
	if _expose_flash > 0.0:
		_ring(22.0 + 44.0 * (1.0 - _expose_flash), Color(1.0, 1.0, 1.0, 0.5 * _expose_flash), 30)


func _diamond(radius: float, color: Color) -> void:
	# Filled diamond made of integer rows.
	var r: int = int(round(radius))
	for y in range(-r, r + 1):
		var width: int = r - abs(y)
		if width < 0:
			continue
		draw_rect(Rect2(float(-width), float(y), float(width * 2 + 1), 1.0), color)


func _ring(radius: float, color: Color, segments: int) -> void:
	for index: int in range(segments):
		var angle: float = float(index) * TAU / float(segments)
		draw_rect(
			Rect2(round(cos(angle) * radius), round(sin(angle) * radius), 1.0, 1.0),
			color
		)
