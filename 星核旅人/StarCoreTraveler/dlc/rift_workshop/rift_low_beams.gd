class_name RiftLowBeams
extends Node2D

## Low iron truss over the rift-workshop bridge corridor.
##
## The player body is 12 x 30.  The beams sit so their underside is 27 px above
## a standing player's head on the 280 deck:
##
##   deck top           y = 280
##   standing body top  y = 250
##   beam underside     y = 223   (27 px of headroom)
##   beam top           y = 211
##
## Jump velocity is -375 with 1100 px/s^2 gravity (about 64 px of free jump),
## so the ceiling stops the head after 27 px.  That shortens the air time enough
## that a missing 64 px bridge cannot be cleared from either bank; the only
## legal route is the phase deck itself.  There is no invisible wall: the beams
## are drawn and carry three real StaticBody2D rectangle shapes.
##
## Presentation: Super Metroid's Wrecked Ship corridor was viewed as a
## readability reference for "dark industrial ceiling over a lighter room"
## (repeated rivets, dark silhouette, a few hanging conduits).  Nothing is
## copied; the truss, chain rhythm, palette and dimensions are this project's.
## See REFERENCE_LOW_BEAM_WISP_20261126.md.

const DECK_Y: float = 280.0
const PLAYER_HEIGHT: float = 30.0
const HEADROOM: float = 27.0
const BEAM_BOTTOM: float = DECK_Y - PLAYER_HEIGHT - HEADROOM
const BEAM_HEIGHT: float = 12.0
const BEAM_TOP: float = BEAM_BOTTOM - BEAM_HEIGHT
const SPAN_START: float = 552.0
const SPAN_END: float = 1040.0

## Three visible beams with a 4 px workshop seam between them.
const BEAM_SPANS: Array[Vector2] = [
	Vector2(552.0, 716.0),
	Vector2(720.0, 876.0),
	Vector2(880.0, 1040.0),
]

const IRON_DARK: Color = Color(0.075, 0.071, 0.065, 0.98)
const IRON_BODY: Color = Color(0.150, 0.142, 0.128, 1.0)
const IRON_TOP: Color = Color(0.275, 0.255, 0.220, 1.0)
const IRON_EDGE: Color = Color(0.365, 0.330, 0.268, 1.0)
const RIVET: Color = Color(0.540, 0.450, 0.300, 1.0)
const CHAIN: Color = Color(0.300, 0.285, 0.250, 0.95)
const CHAIN_LIGHT: Color = Color(0.435, 0.395, 0.300, 0.82)
const HAZARD: Color = Color(0.650, 0.470, 0.180, 0.72)

var _beam_rects: Array[Rect2] = []


func _ready() -> void:
	z_index = 3
	_build_collision()
	queue_redraw()


func _build_collision() -> void:
	_beam_rects.clear()
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "BeamBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for span: Vector2 in BEAM_SPANS:
		var rect: Rect2 = Rect2(
			span.x, BEAM_TOP, span.y - span.x, BEAM_HEIGHT
		)
		_beam_rects.append(rect)
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.name = "BeamShape%d" % (_beam_rects.size())
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rect.size
		shape_node.shape = shape
		shape_node.position = rect.position + rect.size * 0.5
		body.add_child(shape_node)


# --- public read API (tests / capture) -------------------------------------

func get_beam_count() -> int:
	return _beam_rects.size()


func get_beam_rects() -> Array[Rect2]:
	return _beam_rects.duplicate()


func get_beam_bottom_y() -> float:
	return BEAM_BOTTOM


func get_headroom() -> float:
	return HEADROOM


func get_span() -> Vector2:
	return Vector2(SPAN_START, SPAN_END)


func covers_x(x: float) -> bool:
	for rect: Rect2 in _beam_rects:
		if x >= rect.position.x and x <= rect.end.x:
			return true
	return false


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	for index: int in range(BEAM_SPANS.size()):
		var span: Vector2 = BEAM_SPANS[index]
		_draw_beam(span.x, span.y)
	# Upper suspension rods: short dark hangers that tie the truss to the
	# workshop roof, read as structure rather than a floating bar.
	var hanger_x: float = SPAN_START + 20.0
	while hanger_x < SPAN_END - 8.0:
		draw_rect(Rect2(hanger_x, BEAM_TOP - 18.0, 1.0, 18.0), IRON_DARK)
		draw_rect(Rect2(hanger_x + 1.0, BEAM_TOP - 18.0, 1.0, 18.0),
			Color(IRON_BODY, 0.72))
		hanger_x += 46.0


func _draw_beam(left: float, right: float) -> void:
	var width: float = right - left
	# Under-shadow and the dark iron slab.
	draw_rect(Rect2(left, BEAM_BOTTOM - 1.0, width, 2.0), Color(0.0, 0.0, 0.0, 0.38))
	draw_rect(Rect2(left, BEAM_TOP, width, BEAM_HEIGHT), IRON_DARK)
	draw_rect(Rect2(left + 1.0, BEAM_TOP + 1.0, width - 2.0, BEAM_HEIGHT - 2.0),
		IRON_BODY)
	# Top catch-light and lower edge keep the 12 px beam legible at 1x.
	draw_rect(Rect2(left + 1.0, BEAM_TOP + 1.0, width - 2.0, 2.0), IRON_TOP)
	draw_rect(Rect2(left + 1.0, BEAM_BOTTOM - 3.0, width - 2.0, 2.0), IRON_EDGE)
	draw_rect(Rect2(left, BEAM_TOP, 2.0, BEAM_HEIGHT), Color(IRON_EDGE, 0.72))
	draw_rect(Rect2(right - 2.0, BEAM_TOP, 2.0, BEAM_HEIGHT), Color(IRON_EDGE, 0.72))
	# End gussets with a small hazard tick: the starts and seams are readable
	# even when the player is moving fast under them.
	for cap_x: float in [left + 2.0, right - 6.0]:
		draw_rect(Rect2(cap_x, BEAM_TOP + 3.0, 4.0, 2.0), Color(HAZARD, 0.65))
	# Rivets every 12 px, two rows.
	var rivet_x: float = left + 8.0
	while rivet_x < right - 5.0:
		draw_rect(Rect2(rivet_x, BEAM_TOP + 3.0, 1.0, 1.0), RIVET)
		draw_rect(Rect2(rivet_x, BEAM_BOTTOM - 4.0, 1.0, 1.0),
			Color(RIVET, 0.62))
		rivet_x += 12.0
	# Hanging chains are decoration; the colliding beam above is the hard
	# ceiling.  The chains stop 13 px above the standing head, so walking never
	# catches on them.
	var chain_x: float = left + 14.0
	var chain_index: int = 0
	while chain_x < right - 10.0:
		var length: float = 12.0 if chain_index % 2 == 0 else 17.0
		_draw_chain(chain_x, BEAM_BOTTOM, length)
		chain_x += 30.0
		chain_index += 1
	# A short cross-brace at each seam.
	draw_rect(Rect2(left - 1.0, BEAM_TOP - 5.0, 2.0, 5.0), IRON_DARK)
	draw_rect(Rect2(right - 1.0, BEAM_TOP - 5.0, 2.0, 5.0), IRON_DARK)


func _draw_chain(x: float, top: float, length: float) -> void:
	var y: float = 0.0
	var link: int = 0
	while y < length:
		var segment: float = 2.0 if link % 2 == 0 else 1.0
		var color: Color = CHAIN_LIGHT if link % 2 == 0 else CHAIN
		draw_rect(Rect2(x, top + y, 1.0, segment), color)
		if link % 3 == 0:
			draw_rect(Rect2(x + 1.0, top + y, 1.0, 1.0), Color(CHAIN, 0.7))
		y += segment + 1.0
		link += 1
	# Hook / ring at the bottom.
	draw_rect(Rect2(x - 1.0, top + length - 1.0, 3.0, 1.0), RIVET)
	draw_rect(Rect2(x, top + length, 1.0, 1.0), Color(RIVET, 0.6))
