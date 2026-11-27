class_name LoomDustAtmosphere
extends IndoorAtmosphereBase

## DLC3 world-front atmosphere: dust motes inside the two brazier light cones
## and three very short loom fibres.  No full-screen haze and no large dark
## shapes.
##
## The cones are analytical: apex at the bowl (y=286), 5 px half-width there,
## opening to 34 px at y=196.  A mote is only drawn if its 1 px rect stays
## inside that cone.  The fibres are 1 px vertical segments above the boss and
## never enter the play band.

const BRAZIERS: Array[Vector2] = [Vector2(236.0, 320.0), Vector2(860.0, 320.0)]
const CONE_APEX_Y: float = 286.0
const CONE_TOP_Y: float = 196.0
const CONE_APEX_HALF: float = 5.0
const CONE_TOP_HALF: float = 34.0
const MOTE_COUNT: int = 34
const FIBRES: Array = [
	[630.0, 110.0, 168.0, 0.16, 0.0],
	[700.0, 120.0, 180.0, 0.15, 2.1],
	[770.0, 104.0, 160.0, 0.17, 4.2],
]

var _motes: Array[Dictionary] = []
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _items: Array[Dictionary] = []


func _ready() -> void:
	super._ready()
	_rng.seed = 28112026
	# Static damage geometry: the three floor vents and the three boss nodes.
	for vent_x: float in [500.0, 640.0, 820.0]:
		add_hazard_rect(Rect2(vent_x - 16.0, 316.0, 32.0, 20.0))
	for node_x: float in [580.0, 700.0, 820.0]:
		add_hazard_rect(Rect2(node_x - 22.0, 222.0, 44.0, 44.0))
	for index: int in range(MOTE_COUNT):
		var brazier: int = index % BRAZIERS.size()
		_motes.append({
			"brazier": brazier,
			"u": _rng.randf_range(-0.70, 0.70),
			"v": _rng.randf_range(0.0, 1.0),
			"speed": _rng.randf_range(2.5, 5.0),
			"phase": _rng.randf_range(0.0, TAU),
			"warm": _rng.randf() < 0.55,
			"alpha": 0.14 + float(index % 4) * 0.02,
		})


func _process(delta: float) -> void:
	_time += delta
	super._process(delta)


func _rebuild_effects() -> void:
	_items.clear()
	# Brazier dust.
	for mote: Dictionary in _motes:
		var brazier: Vector2 = BRAZIERS[int(mote["brazier"])]
		var cycle: float = fmod(
			float(mote["v"]) + _time * float(mote["speed"]) / (CONE_APEX_Y - CONE_TOP_Y),
			1.0
		)
		var y: float = CONE_APEX_Y - cycle * (CONE_APEX_Y - CONE_TOP_Y)
		var half: float = _cone_half(y) * 0.70
		var sway: float = roundf(sin(_time * 0.45 + float(mote["phase"])) * 1.0)
		var x: float = brazier.x + float(mote["u"]) * half + sway
		var point: Vector2 = Vector2(roundf(x), roundf(y))
		if not is_inside_cone(point):
			continue
		var rect: Rect2 = Rect2(point, Vector2.ONE)
		var alpha: float = float(mote["alpha"])
		if _emit(rect, alpha):
			var color: Color = Color("#ffe0b0") if bool(mote["warm"]) \
				else Color("#d9c9a0")
			_items.append({
				"kind": "mote", "rect": rect, "alpha": alpha, "color": color
			})
	# Three loom fibres; 1 px wide and well above the fight.
	for fibre: Array in FIBRES:
		var fx: float = float(fibre[0])
		var y0: float = float(fibre[1])
		var y1: float = float(fibre[2])
		var alpha: float = float(fibre[3])
		var phase: float = float(fibre[4])
		var sway: float = roundf(sin(_time * 0.30 + phase) * 1.0)
		var rect: Rect2 = Rect2(
			Vector2(roundf(fx + sway), roundf(y0)),
			Vector2(1.0, roundf(y1 - y0) + 1.0)
		)
		if _emit(rect, alpha):
			_items.append({
				"kind": "fibre", "rect": rect, "alpha": alpha,
				"color": Color("#b8a98c")
			})


func _draw() -> void:
	for item: Dictionary in _items:
		var rect: Rect2 = item["rect"]
		var alpha: float = float(item["alpha"])
		var color: Color = item["color"]
		if String(item["kind"]) == "mote":
			draw_rect(rect, Color(color, _draw_alpha(alpha)))
		else:
			draw_rect(rect, Color(color, _draw_alpha(alpha)))
			draw_rect(
				Rect2(Vector2(rect.position.x, rect.end.y - 1.0), Vector2.ONE),
				Color(Color("#8f8166"), _draw_alpha(alpha))
			)


func _cone_half(y: float) -> float:
	if y >= CONE_APEX_Y:
		return CONE_APEX_HALF
	if y <= CONE_TOP_Y:
		return CONE_TOP_HALF
	var t: float = (CONE_APEX_Y - y) / (CONE_APEX_Y - CONE_TOP_Y)
	return CONE_APEX_HALF + (CONE_TOP_HALF - CONE_APEX_HALF) * t


func is_inside_cone(point: Vector2) -> bool:
	if point.y < CONE_TOP_Y or point.y > CONE_APEX_Y:
		return false
	for brazier: Vector2 in BRAZIERS:
		if absf(point.x - brazier.x) <= _cone_half(point.y) + 0.51:
			return true
	return false


func get_effect_bounds() -> Rect2:
	return Rect2(200.0, 100.0, 700.0, 188.0)


func get_mote_count() -> int:
	return _motes.size()
