class_name LoomCore
extends Node2D

## The central loom of the city prototype.
##
## The 208x152 four-frame sprite is a stone/wood frame: two piers, a top beam,
## a bottom cloth beam, a stone base, a near-black weave face, 8-10 warp
## threads and a moving shuttle.  The exposed core is a purple knot at the
## weaving mouth.  While the nodes are alive a gold thread net wraps that knot;
## once both nodes break, the net visibly splits left/right and the core opens.
##
## The sprite is drawn behind this node's own drawing (show_behind_parent), so
## the net, core, base shadow and the two chains up to the ceiling stay on top
## of the frame without covering the weak point.

const SPRITE: Texture2D = preload(
	"res://dlc/star_loom/assets/city/loom_boss_city_208x152_4f.png"
)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const GOLD_THREAD: Color = Color("#ffd77a")
const GOLD_DARK: Color = Color(0.42, 0.28, 0.10, 0.95)
const WHITE: Color = Color(1.0, 0.98, 0.94, 1.0)
const INK: Color = Color(0.02, 0.01, 0.05, 1.0)
const DARK: Color = Color(0.16, 0.08, 0.24, 1.0)
const ORBIT: Color = Color(0.62, 0.54, 0.38, 0.13)
const IRON: Color = Color(0.10, 0.09, 0.09, 0.85)
const IRON_LIGHT: Color = Color(0.46, 0.40, 0.32, 0.8)

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
	_sprite.hframes = 4
	_sprite.vframes = 1
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


## Generous 112x116 weak-point box over the 208x152 frame.  A grounded J can
## reach the lower half of the knot; a jump reaches the rest.
func get_hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(56.0, 58.0), Vector2(112.0, 116.0))


func _process(delta: float) -> void:
	_time += delta
	_hit_flash = maxf(_hit_flash - delta / 0.28, 0.0)
	_shield_flash = maxf(_shield_flash - delta / 0.22, 0.0)
	_expose_flash = maxf(_expose_flash - delta / 0.45, 0.0)
	if _sprite != null:
		_sprite.frame = int(_time * 3.2) % 4
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
	_draw_orbit()
	_draw_base_shadow()
	_draw_chains()
	var phase_color: Color = GOLD if _positive else CYAN
	if _defeated:
		for index: int in range(4):
			var x: float = -42.0 + 28.0 * float(index)
			draw_rect(
				Rect2(x, 46.0, 1.0, 22.0 + 5.0 * float(index)),
				Color(0.55, 0.46, 0.34, 0.5)
			)
		return
	if not _active:
		_ring(30.0, Color(0.46, 0.50, 0.56, 0.18), 28)
		return
	if not _exposed:
		_draw_net_shield()
		_draw_shuttle()
		if _shield_flash > 0.0:
			_ring(
				38.0 + 8.0 * (1.0 - _shield_flash),
				Color(1.0, 1.0, 1.0, 0.7 * _shield_flash),
				32
			)
		return
	_draw_split_net()
	_draw_shuttle()
	_draw_exposed_core(phase_color)


func _draw_net_shield() -> void:
	# A gold warp net woven across the purple knot: two diagonal families,
	# clipped to the socket.  It is a net, not a circular clock face.
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.4)
	for offset in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		_net_line(
			Vector2(offset - 38.0, -38.0), Vector2(offset + 38.0, 38.0),
			33.0, Color(GOLD_THREAD, 0.58 + 0.28 * pulse), false
		)
		_net_line(
			Vector2(offset - 38.0, 38.0), Vector2(offset + 38.0, -38.0),
			33.0, Color(GOLD_THREAD, 0.58 + 0.28 * pulse), false
		)
	# Four gold knots where the net is tied.
	for angle in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var kx: float = cos(angle) * 32.0
		var ky: float = sin(angle) * 32.0
		draw_rect(Rect2(kx - 1.0, ky - 1.0, 3.0, 3.0), GOLD_DARK)
		draw_rect(Rect2(kx, ky, 1.0, 1.0), GOLD_THREAD)


func _draw_split_net() -> void:
	# The same net opens left/right: only the outer threads remain, leaving a
	# clear vertical gap for the purple core.
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	for offset in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		_net_line(
			Vector2(offset - 38.0, -38.0), Vector2(offset + 38.0, 38.0),
			35.0, Color(GOLD_THREAD, 0.72), true
		)
		_net_line(
			Vector2(offset - 38.0, 38.0), Vector2(offset + 38.0, -38.0),
			35.0, Color(GOLD_THREAD, 0.72), true
		)
	# Two short peeled arcs.
	_arc(34.0, -0.62, 0.62, Color(GOLD_THREAD, 0.65 + 0.20 * pulse), 12)
	_arc(34.0, PI - 0.62, PI + 0.62, Color(GOLD_THREAD, 0.65 + 0.20 * pulse), 12)


func _draw_exposed_core(phase_color: Color) -> void:
	# The core is a purple knot; the phase is a 1 px outline plus four corner
	# brackets, so gold/cyan stays readable without turning the knot gold.
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
	var half: float = 15.0 + 1.5 * pulse
	_diamond(half + 2.0, INK)
	_diamond(half + 1.0, phase_color)
	_diamond(half, Color(0.23, 0.13, 0.32, 1.0))
	_diamond(half - 4.0, Color(0.42, 0.24, 0.60, 1.0))
	_diamond(9.0, Color(0.66, 0.45, 0.92, 1.0))
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), WHITE)
	for direction: Vector2 in [
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
		Vector2(-1.0, 1.0), Vector2(1.0, 1.0),
	]:
		var corner: Vector2 = direction * 19.0
		var bx: float = minf(corner.x, corner.x + direction.x * 3.0)
		var by: float = minf(corner.y, corner.y + direction.y * 3.0)
		draw_rect(Rect2(bx, corner.y, 3.0, 1.0), phase_color)
		draw_rect(Rect2(corner.x, by, 1.0, 3.0), phase_color)
		draw_rect(Rect2(corner.x - 1.0, corner.y - 1.0, 2.0, 2.0), Color(WHITE, 0.65))
	if _hit_flash > 0.0:
		_ring(
			30.0 + 30.0 * (1.0 - _hit_flash),
			Color(1.0, 1.0, 1.0, 0.85 * _hit_flash),
			34
		)
	if _expose_flash > 0.0:
		_ring(
			26.0 + 36.0 * (1.0 - _expose_flash),
			Color(1.0, 1.0, 1.0, 0.45 * _expose_flash),
			34
		)


func _draw_orbit() -> void:
	# Very faint ellipse through the two node anchors.  It shows the orbit
	# without competing with the warp threads.
	var segments: int = 96
	for index in range(segments):
		var angle: float = float(index) * TAU / float(segments)
		draw_rect(
			Rect2(
				round(cos(angle) * 120.0),
				round(sin(angle) * 54.0),
				1.0, 1.0
			),
			ORBIT
		)


func _draw_shuttle() -> void:
	# A gold shuttle slides across the weaving mouth in front of the net.  The
	# sprite also has a baked shuttle, but this one stays visible while the net
	# wraps the core, so the "loom" read never depends on the exposed state.
	var x: float = sin(_time * 1.35) * 46.0
	draw_rect(Rect2(x - 10.0, -16.0, 20.0, 5.0), Color(GOLD_DARK, 0.95))
	draw_rect(Rect2(x - 9.0, -16.0, 18.0, 2.0), GOLD_THREAD)
	draw_rect(Rect2(x - 6.0, -14.0, 12.0, 1.0), Color(1.0, 0.93, 0.70, 1.0))
	draw_rect(Rect2(x - 3.0, -13.0, 6.0, 1.0), INK)
	for trail in range(1, 4):
		draw_rect(
			Rect2(x - 10.0 - float(trail) * 3.0, -14.0, 2.0, 1.0),
			Color(GOLD_THREAD, 0.30 - float(trail) * 0.06)
		)
	# Two thin rails / heddle bars around the mouth.
	draw_rect(Rect2(-64.0, -17.0, 128.0, 1.0), Color(GOLD_DARK, 0.65))
	draw_rect(Rect2(-64.0, -9.0, 128.0, 1.0), Color(GOLD_DARK, 0.45))


func _draw_base_shadow() -> void:
	# 1-2 px contact shadow under the stone base, so the loom stands on the
	# floor instead of being a sticker on the wall.
	draw_rect(Rect2(-100.0, 76.0, 200.0, 2.0), Color(0.0, 0.0, 0.0, 0.38))
	draw_rect(Rect2(-94.0, 75.0, 188.0, 1.0), Color(0.38, 0.32, 0.26, 0.55))


func _draw_chains() -> void:
	for chain_x in [-32.0, 32.0]:
		var sway: float = sin(_time * 0.9 + chain_x) * 1.5
		var y: float = -192.0
		var toggle: int = 0
		while y < -76.0:
			var x: float = chain_x + sway * ((y + 192.0) / 116.0)
			# 2 px links with a 1 px dark bed; readable against the drape.
			draw_rect(Rect2(x - 1.0, y + 1.0, 3.0, 1.0), Color(0.05, 0.04, 0.04, 0.9))
			if toggle % 2 == 0:
				draw_rect(Rect2(x - 1.0, y, 2.0, 1.0), Color(0.68, 0.60, 0.48, 0.95))
				draw_rect(Rect2(x + 1.0, y, 1.0, 1.0), Color(0.34, 0.28, 0.22, 0.9))
			else:
				draw_rect(Rect2(x, y, 1.0, 2.0), Color(0.56, 0.48, 0.38, 0.95))
			y += 4.0
			toggle += 1
		# Attachment ring at the top beam.
		draw_rect(Rect2(chain_x - 2.0, -77.0, 5.0, 2.0), Color(0.66, 0.58, 0.46, 0.95))
		draw_rect(Rect2(chain_x - 1.0, -78.0, 3.0, 1.0), Color(0.30, 0.25, 0.20, 0.9))


func _net_line(
	from: Vector2, to: Vector2, clip_radius: float, color: Color, split: bool
) -> void:
	var steps: int = 96
	for index in range(steps + 1):
		var t: float = float(index) / float(steps)
		var point: Vector2 = from.lerp(to, t)
		if point.length() > clip_radius:
			continue
		if split and absf(point.x) < 5.0:
			continue
		draw_rect(Rect2(round(point.x) + 1.0, round(point.y) + 1.0, 1.0, 1.0), Color(GOLD_DARK, 0.55))
		draw_rect(Rect2(round(point.x), round(point.y), 1.0, 1.0), color)


func _draw_radial(angle: float, r0: float, r1: float, color: Color) -> void:
	var steps: int = int(maxf(r1 - r0, 1.0))
	for index in range(steps + 1):
		var t: float = float(index) / float(maxi(steps, 1))
		var radius: float = lerpf(r0, r1, t)
		draw_rect(
			Rect2(
				round(cos(angle) * radius),
				round(sin(angle) * radius),
				1.0, 1.0
			),
			color
		)


func _arc(radius: float, start: float, end: float, color: Color, steps: int) -> void:
	for index in range(steps + 1):
		var angle: float = lerpf(start, end, float(index) / float(maxi(steps, 1)))
		draw_rect(
			Rect2(round(cos(angle) * radius), round(sin(angle) * radius), 1.0, 1.0),
			color
		)


func _diamond(radius: float, color: Color) -> void:
	var r: int = int(round(radius))
	for y in range(-r, r + 1):
		var width: int = r - abs(y)
		if width < 0:
			continue
		draw_rect(Rect2(float(-width), float(y), float(width * 2 + 1), 1.0), color)


func _ring(radius: float, color: Color, segments: int) -> void:
	for index in range(segments):
		var angle: float = float(index) * TAU / float(segments)
		draw_rect(
			Rect2(round(cos(angle) * radius), round(sin(angle) * radius), 1.0, 1.0),
			color
		)
