class_name LoomCore
extends Node2D

## The central loom of the city prototype.
##
## The 208x152 four-frame sprite is a stone/wood frame: two piers, a top beam,
## a bottom cloth beam, a stone base, a near-black weave face, 8-10 warp
## threads and a moving shuttle.  While the nodes are alive a gold thread net
## wraps a dim purple knot; once both nodes break, the net visibly peels
## left/right and a 40x40 solid phase diamond (purple inset core + sun/moon
## icon) is uncovered.
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
## The exposed weak point is a single 40x40 phase diamond.  The whole face is
## gold or cyan; the purple knot stays as a small inset core, so the phase
## colour dominates at 1x.  The shield net peels left/right and leaves a clear
## vertical opening (never narrower than 24 px).
const PHASE_DIAMOND_SIZE: Vector2 = Vector2(40.0, 40.0)
const CORE_HIT_SIZE: Vector2 = Vector2(40.0, 36.0)
const NET_OPEN_GAP: float = 26.0
const NET_PEEL: float = 3.0
const PURPLE_CORE: Color = Color(0.24, 0.10, 0.34, 1.0)
const PURPLE_MID: Color = Color(0.45, 0.26, 0.64, 1.0)
const PURPLE_LIGHT: Color = Color(0.68, 0.47, 0.92, 1.0)
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
var _phase_flash: float = 0.0
## Opening-film support: the real 4-frame sheet is driven from the film clock
## while the boss is still inactive, so the shuttle movement is deterministic
## and the boss cannot start from the film.
var _cinematic_frame_lock: bool = false


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
	_phase_flash = 0.0
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
	# A short white overlay sells the whole-face colour swap without adding a
	# ring; the fill itself is always one solid phase colour.
	_phase_flash = 1.0
	queue_redraw()


func get_phase() -> bool:
	return _positive


func is_positive() -> bool:
	return _positive


func set_exposed(value: bool) -> void:
	if _exposed == value:
		return
	_exposed = value
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


## A tight 40x36 weak-point box around the raised diamond.  Its bottom edge is
## 56 px above the floor, so a grounded J (top of the swing ~38 px above the
## feet) misses and a jump J reaches it.
func get_hit_rect() -> Rect2:
	return Rect2(global_position - CORE_HIT_SIZE * 0.5, CORE_HIT_SIZE)


func _process(delta: float) -> void:
	_time += delta
	_hit_flash = maxf(_hit_flash - delta / 0.28, 0.0)
	_shield_flash = maxf(_shield_flash - delta / 0.22, 0.0)
	_phase_flash = maxf(_phase_flash - delta / 0.16, 0.0)
	if _sprite != null and not _cinematic_frame_lock:
		_sprite.frame = int(_time * 3.2) % 4
	queue_redraw()


## The opening film drives the same four real frames from its own clock.  The
## lock only stops the idle frame counter; `_active` and gameplay stay off.
func set_cinematic_frame_lock(value: bool, start_frame: int = 0) -> void:
	_cinematic_frame_lock = value
	if value and _sprite != null:
		_sprite.frame = clampi(start_frame, 0, 3)


func set_cinematic_frame(frame: int) -> void:
	if _sprite != null:
		_sprite.frame = clampi(frame, 0, 3)


func get_sprite_frame() -> int:
	return _sprite.frame if _sprite != null else -1


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
		_fill_diamond(26.0, 26.0, Color(0.06, 0.06, 0.09, 0.45))
		_fill_diamond(20.0, 20.0, Color(0.32, 0.34, 0.38, 0.72))
		return
	if not _exposed:
		_draw_shielded_core()
		_draw_net_shield()
		_draw_shuttle()
		return
	_draw_split_net()
	_draw_shuttle()
	_draw_exposed_core(phase_color)


## The purple knot stays visible through the gold net, so the shield reads as a
## woven cover over a real core instead of an empty ring of threads.
func _draw_shielded_core() -> void:
	_fill_diamond(26.0, 26.0, Color(0.02, 0.01, 0.05, 0.65), Vector2(0.0, 2.0))
	_fill_diamond(22.0, 22.0, Color(0.16, 0.08, 0.24, 0.92), Vector2(0.0, 2.0))
	_fill_diamond(14.0, 14.0, Color(0.28, 0.14, 0.42, 0.9), Vector2(0.0, 2.0))


func _draw_net_shield() -> void:
	# A gold warp net woven across the purple knot: two diagonal families,
	# clipped to the socket.  It is a net, not a circular clock face.
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.4)
	var alpha: float = 0.58 + 0.28 * pulse + 0.20 * _shield_flash
	for offset in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		_net_line(
			Vector2(offset - 38.0, -38.0), Vector2(offset + 38.0, 38.0),
			33.0, Color(GOLD_THREAD, alpha), false
		)
		_net_line(
			Vector2(offset - 38.0, 38.0), Vector2(offset + 38.0, -38.0),
			33.0, Color(GOLD_THREAD, alpha), false
		)
	# Four gold knots where the net is tied.
	for angle in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var kx: float = cos(angle) * 32.0
		var ky: float = sin(angle) * 32.0
		draw_rect(Rect2(kx - 1.0, ky - 1.0, 3.0, 3.0), GOLD_DARK)
		draw_rect(Rect2(kx, ky, 1.0, 1.0), GOLD_THREAD)


## The same net pulls to the sides.  Each half is clipped so the remaining
## vertical opening is exactly NET_OPEN_GAP (26 px, against the required 24 px
## minimum); torn inner thread ends show that it was opened, not erased.
func _draw_split_net() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	var color: Color = Color(GOLD_THREAD, 0.74)
	for side: float in [-1.0, 1.0]:
		for offset in [-24.0, -12.0, 0.0, 12.0, 24.0]:
			_net_line(
				Vector2(offset - 38.0, -38.0), Vector2(offset + 38.0, 38.0),
				35.0, color, true, side, NET_OPEN_GAP, NET_PEEL
			)
			_net_line(
				Vector2(offset - 38.0, 38.0), Vector2(offset + 38.0, -38.0),
				35.0, color, true, side, NET_OPEN_GAP, NET_PEEL
			)
		_draw_net_torn_edge(side, pulse)


func _draw_net_torn_edge(side: float, pulse: float) -> void:
	var edge_x: float = side * (NET_OPEN_GAP * 0.5)
	var bright: Color = Color(GOLD_THREAD, 0.70 + 0.25 * pulse)
	for index: int in range(6):
		var y: float = -26.0 + float(index) * 10.0 + float(index % 2)
		var jog: float = -1.0 if index % 3 == 0 else 0.0
		draw_rect(Rect2(edge_x + side * jog, y, 1.0, 4.0), bright)
		draw_rect(
			Rect2(minf(edge_x, edge_x + side * 4.0), y + 2.0, 4.0, 1.0),
			Color(GOLD_THREAD, 0.50 + 0.20 * pulse)
		)
	# Two longer peeled hooks at the widest rows.
	draw_rect(
		Rect2(minf(edge_x - side * 3.0, edge_x + side * 5.0), -14.0, 8.0, 1.0),
		bright
	)
	draw_rect(
		Rect2(minf(edge_x - side * 3.0, edge_x + side * 5.0), 14.0, 8.0, 1.0),
		Color(GOLD_THREAD, 0.55 + 0.20 * pulse)
	)


func _draw_exposed_core(phase_color: Color) -> void:
	# One solid phase diamond (40x40) with a 1 px dark edge.  The purple knot is
	# a small inset, so the required phase colour owns the shape.  No ring,
	# halo or bracket is drawn around the weak point.
	_fill_diamond(44.0, 44.0, Color(0.0, 0.0, 0.0, 0.32), Vector2(1.0, 2.0))
	_fill_diamond(42.0, 42.0, INK)
	_fill_diamond(40.0, 40.0, phase_color)
	# Purple core, inset but still visible at the centre.
	_fill_diamond(22.0, 22.0, Color(0.06, 0.03, 0.10, 0.96), Vector2(0.0, 3.0))
	_fill_diamond(20.0, 20.0, PURPLE_CORE, Vector2(0.0, 3.0))
	_fill_diamond(14.0, 14.0, PURPLE_MID, Vector2(0.0, 3.0))
	_fill_diamond(8.0, 8.0, PURPLE_LIGHT, Vector2(-1.0, 2.0))
	# White highlight on the upper-left phase face.
	for index: int in range(7):
		var row_y: float = -16.0 + float(index) * 2.0
		var cy: float = (row_y + 0.5) / 20.0
		var span: int = int(round(20.0 * (1.0 - absf(cy))))
		draw_rect(
			Rect2(-float(span) + 1.0, row_y, 1.0, 1.0),
			Color(WHITE, 0.82)
		)
	draw_rect(Rect2(-9.0, -12.0, 2.0, 1.0), WHITE)
	# Sun = gold phase, moon = cyan phase.  The ~15 px icon sits above the
	# inset knot, inside the diamond, so the required phase reads without text.
	_draw_phase_icon(Vector2(0.0, -5.0), phase_color)
	# Hit and phase flashes only brighten the diamond face itself.
	var flash: float = maxf(_hit_flash * 0.62, _phase_flash * 0.46)
	if flash > 0.0:
		_fill_diamond(40.0, 40.0, Color(1.0, 1.0, 1.0, flash))


func get_phase_color() -> Color:
	return GOLD if _positive else CYAN


func get_phase_icon_name() -> String:
	return "sun" if _positive else "moon"


func get_diamond_size() -> Vector2:
	return PHASE_DIAMOND_SIZE


func get_net_gap() -> float:
	return NET_OPEN_GAP


## Public facts used by tests and the capture scripts.  This replaces the old
## cyan/gold ring contract; has_ring is kept false on purpose.
func get_expose_visual_info() -> Dictionary:
	return {
		"diamond_size": PHASE_DIAMOND_SIZE,
		"diamond_color": get_phase_color(),
		"edge_color": INK,
		"highlight_color": WHITE,
		"icon": get_phase_icon_name(),
		"icon_size": Vector2(15.0, 15.0),
		"net_gap": NET_OPEN_GAP,
		"net_peel": NET_PEEL,
		"hit_rect": get_hit_rect(),
		"purple_core": PURPLE_CORE,
		"has_ring": false,
	}


func _draw_phase_icon(center: Vector2, _phase_color: Color) -> void:
	if _positive:
		for pixel: Dictionary in LoomPhaseGlyph.sun_pixels(
			center.round(), 4, 3, [5.0, 6.0, 7.0], INK, WHITE, WHITE
		):
			draw_rect(pixel["rect"], pixel["color"])
	else:
		# The cut side is simply not drawn, so the phase-coloured diamond shows
		# through and the crescent keeps a 1 px dark rim.
		for pixel: Dictionary in LoomPhaseGlyph.moon_pixels(
			center.round(), 6, 5, Vector2(4.0, -3.0), 5, INK, WHITE
		):
			draw_rect(pixel["rect"], pixel["color"])


## Crisp diamond fill measured in whole pixels.  width/height give the outer
## extent; a 1 px wider dark diamond behind it supplies the outline.
func _fill_diamond(
	width: float, height: float, color: Color, offset: Vector2 = Vector2.ZERO
) -> void:
	var half_h: float = height * 0.5
	var half_w: float = width * 0.5
	var base_x: float = round(offset.x)
	var base_y: float = round(offset.y)
	var y_start: int = int(round(base_y - half_h))
	var y_end: int = int(round(base_y + half_h))
	for y: int in range(y_start, y_end):
		var cy: float = (float(y) + 0.5 - base_y) / half_h
		if absf(cy) > 1.0:
			continue
		var span: int = int(round(half_w * (1.0 - absf(cy))))
		if span < 1:
			continue
		draw_rect(
			Rect2(base_x - float(span), float(y), float(span * 2), 1.0),
			color
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
	from: Vector2, to: Vector2, clip_radius: float, color: Color, split: bool,
	side: float = 0.0, gap: float = NET_OPEN_GAP, peel: float = NET_PEEL
) -> void:
	var steps: int = 96
	var inner_cut: float = maxf(gap * 0.5 - peel, 0.0)
	for index in range(steps + 1):
		var t: float = float(index) / float(steps)
		var point: Vector2 = from.lerp(to, t)
		if split:
			if side < 0.0 and point.x > -inner_cut:
				continue
			if side > 0.0 and point.x < inner_cut:
				continue
			point.x += side * peel
		if point.length() > clip_radius:
			continue
		draw_rect(Rect2(round(point.x) + 1.0, round(point.y) + 1.0, 1.0, 1.0), Color(GOLD_DARK, 0.55))
		draw_rect(Rect2(round(point.x), round(point.y), 1.0, 1.0), color)


## (All old ring/halo helpers were removed with the exposure beacon; the core
## is read from its shape and solid phase colour now.)
