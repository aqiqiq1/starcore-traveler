@tool
extends Node2D

## Non-collision edge decoration for level 02.
##
## Draws only on the visible edges of three existing collision blocks: the main
## ground, the low-corridor roof and the linked-wall platform (lip + wall).
## Nothing is drawn above a top edge, into the 20 px core corridor, or below a
## main-ground edge, so player feet, the carried core and the real collision
## silhouette are never covered.
##
## The rects mirror the formal level geometry (level_02.tscn). They are exports
## so a future layout edit or duplicate can re-attach the same decoration
## without touching this script's default level. Every mark is an integer 1 px
## rectangle; no texture, no gradient, no random per-run noise. `get_decor_rects`
## exposes the actually drawn rectangles for the capture-time overlap audit.

const TOP_LIGHT: Color = Color(0.88, 0.84, 0.78, 0.34)
const TOP_LIGHT_STRONG: Color = Color(0.96, 0.92, 0.85, 0.66)
const EDGE_SHADOW: Color = Color(0.22, 0.18, 0.20, 0.38)
const CHIP_DARK: Color = Color(0.24, 0.19, 0.21, 0.80)
const MOSS_DARK: Color = Color(0.26, 0.37, 0.30, 0.95)
const MOSS_LIGHT: Color = Color(0.44, 0.57, 0.47, 0.92)
const STONE_MID: Color = Color(0.58, 0.52, 0.49, 0.97)
const STONE_LIGHT: Color = Color(0.78, 0.73, 0.67, 0.92)
const STONE_DARK: Color = Color(0.27, 0.23, 0.24, 0.90)
const UNDER_DARK: Color = Color(0.09, 0.07, 0.09, 0.55)

@export var ground_rect: Rect2 = Rect2(0, 320, 1792, 40)
@export var roof_rect: Rect2 = Rect2(464, 268, 256, 32)
@export var lip_rect: Rect2 = Rect2(1040, 240, 40, 12)
@export var wall_rect: Rect2 = Rect2(1080, 240, 160, 60)

## One readable cluster every 60-90 px, not an even border. x is local.
const GROUND_FEATURES: Array = [
	{"x": 32, "kind": "moss", "w": 9},
	{"x": 96, "kind": "chip", "w": 6},
	{"x": 168, "kind": "light", "w": 16},
	{"x": 238, "kind": "moss", "w": 8},
	{"x": 312, "kind": "rubble"},
	{"x": 386, "kind": "chip", "w": 5},
	{"x": 458, "kind": "moss", "w": 10},
	{"x": 532, "kind": "light", "w": 14},
	{"x": 606, "kind": "rubble"},
	{"x": 680, "kind": "moss", "w": 8},
	{"x": 752, "kind": "chip", "w": 7},
	{"x": 826, "kind": "moss", "w": 10},
	{"x": 896, "kind": "light", "w": 18},
	{"x": 968, "kind": "rubble"},
	{"x": 1040, "kind": "moss", "w": 8},
	{"x": 1112, "kind": "chip", "w": 6},
	{"x": 1186, "kind": "moss", "w": 9},
	{"x": 1258, "kind": "light", "w": 16},
	{"x": 1330, "kind": "rubble"},
	{"x": 1402, "kind": "moss", "w": 8},
	{"x": 1474, "kind": "chip", "w": 6},
	{"x": 1546, "kind": "moss", "w": 10},
	{"x": 1618, "kind": "light", "w": 14},
	{"x": 1690, "kind": "rubble"},
	{"x": 1752, "kind": "moss", "w": 8},
]
const ROOF_FEATURES: Array = [
	{"x": 16, "kind": "moss", "w": 10},
	{"x": 104, "kind": "chip", "w": 7},
	{"x": 206, "kind": "rubble"},
]
## Shared top edge of the 40 px lip and the 160 px wall.
const WALL_FEATURES: Array = [
	{"x": 12, "kind": "chip", "w": 6},
	{"x": 86, "kind": "moss", "w": 10},
	{"x": 158, "kind": "light", "w": 18},
]
const UNDER_CHIP_X: Dictionary = {
	"roof": [40, 134, 208],
	"lip": [10, 30],
	"wall": [40, 100, 150],
}

var _rects: Array[Rect2] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	_rects.clear()
	_draw_top_edge(ground_rect, GROUND_FEATURES)
	_draw_top_edge(roof_rect, ROOF_FEATURES)
	var wall_top: Rect2 = Rect2(
		lip_rect.position.x,
		lip_rect.position.y,
		wall_rect.end.x - lip_rect.position.x,
		1.0
	)
	_draw_top_edge(wall_top, WALL_FEATURES)
	_draw_bottom_edge(roof_rect, UNDER_CHIP_X["roof"])
	_draw_bottom_edge(lip_rect, UNDER_CHIP_X["lip"])
	_draw_bottom_edge(wall_rect, UNDER_CHIP_X["wall"])
	_draw_end_chips(roof_rect)
	_draw_end_chips(lip_rect)
	_draw_end_chips(wall_rect)


func get_decor_rects() -> Array[Rect2]:
	var copy: Array[Rect2] = []
	copy.assign(_rects)
	return copy


func _draw_top_edge(edge: Rect2, features: Array) -> void:
	# Continuous 2 px sheen in block-length segments with real gaps, never a
	# solid border. Two lit rows plus the shadow row below make the lip read at
	# 1x while the face keeps its masonry.
	var x: int = 0
	var segments: Array = [12, 15, 9, 17, 11, 14]
	var index: int = 0
	while x < int(edge.size.x):
		var width: int = mini(int(segments[index % segments.size()]), int(edge.size.x) - x)
		_put(Rect2(edge.position.x + x, edge.position.y, width, 2), TOP_LIGHT)
		_put(Rect2(edge.position.x + x + 1, edge.position.y + 2, maxi(width - 2, 1), 1), EDGE_SHADOW)
		x += width + 5 + (index % 3) * 2
		index += 1
	for feature: Dictionary in features:
		var fx: int = int(edge.position.x) + int(feature["x"])
		var top: int = int(edge.position.y)
		match String(feature["kind"]):
			"light":
				var width: int = int(feature["w"])
				_put(Rect2(fx, top, width, 2), TOP_LIGHT_STRONG)
				_put(Rect2(fx + 1, top + 2, maxi(width - 2, 1), 1), EDGE_SHADOW)
			"chip":
				var width: int = int(feature["w"])
				_put(Rect2(fx, top, width, 2), CHIP_DARK)
				_put(Rect2(fx + 1, top + 2, maxi(width - 2, 1), 1), EDGE_SHADOW)
				_put(Rect2(fx + width, top, 2, 2), TOP_LIGHT_STRONG)
			"moss":
				_draw_moss(fx, top, int(feature["w"]))
			"rubble":
				_draw_rubble(fx, top)


func _draw_moss(x: int, top: int, width: int) -> void:
	# Two clumps with a 2 px dark pad on the face and 2-4 px hanging strands.
	# At 1x this reads as a green tuft without becoming a solid green border.
	var clumps: Array
	if width >= 8:
		clumps = [[0, 5, 2], [6, 3, 3]]
	elif width >= 5:
		clumps = [[0, 4, 2], [5, 2, 2]]
	else:
		clumps = [[0, 3, 2]]
	for clump: Array in clumps:
		var cx: int = x + int(clump[0])
		var cap_w: int = int(clump[1])
		var drop: int = int(clump[2])
		_put(Rect2(cx, top + 1, cap_w, 2), MOSS_DARK)
		_put(Rect2(cx, top + 1, 2, 1), MOSS_LIGHT)
		_put(Rect2(cx + cap_w - 1, top + 3, 1, drop), MOSS_DARK)
		if cap_w >= 4:
			_put(Rect2(cx + 1, top + 3, 1, maxi(drop - 1, 1)), MOSS_DARK)
		if cap_w >= 5:
			_put(Rect2(cx + 3, top + 2, 2, 1), MOSS_LIGHT)


func _draw_rubble(x: int, top: int) -> void:
	_put(Rect2(x, top + 1, 5, 2), STONE_MID)
	_put(Rect2(x + 1, top + 1, 2, 1), STONE_LIGHT)
	_put(Rect2(x, top + 3, 5, 1), STONE_DARK)
	_put(Rect2(x + 6, top + 2, 2, 2), STONE_MID)
	_put(Rect2(x + 6, top + 2, 1, 1), STONE_LIGHT)
	_put(Rect2(x + 6, top + 3, 2, 1), STONE_DARK)


func _draw_bottom_edge(edge: Rect2, chip_positions: Array) -> void:
	# Two dark rows read as the block's underside without touching the 20 px
	# core corridor (rows are bottom-2/bottom-1, i.e. 298/299 for a 300 bottom).
	var bottom: int = int(edge.end.y) - 1
	_put(Rect2(edge.position.x, bottom - 1, edge.size.x, 2), Color(0.09, 0.07, 0.09, 0.30))
	_put(Rect2(edge.position.x, bottom, edge.size.x, 1), UNDER_DARK)
	for chip_x: int in chip_positions:
		var x: int = int(edge.position.x) + int(chip_x)
		_put(Rect2(x, bottom - 1, 2, 2), Color(0.18, 0.13, 0.24, 0.45))
		_put(Rect2(x, bottom, 1, 1), Color(0.08, 0.06, 0.11, 0.70))


func _draw_end_chips(edge: Rect2) -> void:
	var top: int = int(edge.position.y)
	var left: int = int(edge.position.x)
	var right: int = int(edge.end.x) - 1
	# Chipped corner read: a 3 px dark bite out of the lit lip plus a broken
	# bright edge just past it. The block silhouette itself is untouched.
	_put(Rect2(left, top, 3, 2), CHIP_DARK)
	_put(Rect2(left, top + 2, 1, 2), EDGE_SHADOW)
	_put(Rect2(left + 3, top, 2, 2), TOP_LIGHT_STRONG)
	_put(Rect2(right - 2, top, 3, 2), CHIP_DARK)
	_put(Rect2(right, top + 2, 1, 2), EDGE_SHADOW)
	_put(Rect2(right - 4, top, 2, 2), TOP_LIGHT_STRONG)


func _put(rect: Rect2, color: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_rect(rect, color)
	_rects.append(rect)
