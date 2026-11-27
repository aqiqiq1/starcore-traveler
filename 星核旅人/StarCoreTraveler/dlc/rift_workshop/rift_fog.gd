extends Node2D

## Rift-workshop interior overlay, drawn over the read-only interior backdrop.
##
## Two original layers:
##   1. a generated 640x360 warm-dust haze
##      (assets/interior/interior_warm_haze_640x360.png) with a slow alpha
##      breathing, screen-fixed like the interior backdrop;
##   2. code-drawn warm dust motes and a few slower embers drifting upward.
##
## The three base levels keep their own DS03 instances untouched: this node only
## exists inside dlc/rift_workshop/rift_workshop.tscn.  Nothing here is drawn
## over the terrain or gameplay (the whole Background CanvasLayer sits at
## layer -10, behind the world).

const FOG: Texture2D = preload(
	"res://dlc/rift_workshop/assets/interior/interior_warm_haze_640x360.png"
)
const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const MOTE_COUNT: int = 42
const EMBER: Color = Color("#f0a85e")
const DUST: Color = Color("#d99a62")
const DUST_LIGHT: Color = Color("#ffe0b0")
const DEEP: Color = Color("#7a4426")

var _motes: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261125
	for _index: int in range(MOTE_COUNT):
		_motes.append(_make_mote(rng, rng.randf_range(0.0, VIEW_SIZE.y)))
	queue_redraw()


func _make_mote(rng: RandomNumberGenerator, y: float) -> Dictionary:
	var big: bool = rng.randf() < 0.20
	return {
		"x": rng.randf_range(0.0, VIEW_SIZE.x),
		"y": y,
		"speed": rng.randf_range(5.0, 13.0) if not big else rng.randf_range(2.0, 5.0),
		"size": 2.0 if big else 1.0,
		"alpha": rng.randf_range(0.30, 0.66) if not big else rng.randf_range(0.20, 0.40),
		"phase": rng.randf_range(0.0, TAU),
		"bright": rng.randf() < 0.40,
	}


func _process(delta: float) -> void:
	_time += delta
	for mote: Dictionary in _motes:
		mote["y"] = float(mote["y"]) - float(mote["speed"]) * delta
		var x: float = float(mote["x"]) + sin(_time * 0.6 + float(mote["phase"])) * 0.25
		mote["x"] = x
		if float(mote["y"]) < -4.0:
			var replacement: Dictionary = _make_mote(_respawn_rng(), VIEW_SIZE.y + 4.0)
			mote["x"] = replacement["x"]
			mote["y"] = VIEW_SIZE.y + 4.0
			mote["speed"] = replacement["speed"]
			mote["size"] = replacement["size"]
			mote["alpha"] = replacement["alpha"]
			mote["phase"] = replacement["phase"]
			mote["bright"] = replacement["bright"]
	queue_redraw()


func _respawn_rng() -> RandomNumberGenerator:
	# Deterministic-ish but always changing: the seed is time-based only.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(_time * 1000.0) + _motes.size()
	return rng


func _draw() -> void:
	var breath: float = 0.86 + 0.14 * (0.5 + 0.5 * sin(_time * 0.9))
	draw_texture_rect(FOG, Rect2(Vector2.ZERO, VIEW_SIZE), false, Color(1.0, 1.0, 1.0, breath))
	for mote: Dictionary in _motes:
		var size: float = float(mote["size"])
		var color: Color = DUST_LIGHT if bool(mote["bright"]) else (EMBER if size > 1.0 else DUST)
		color.a = float(mote["alpha"])
		draw_rect(Rect2(round(float(mote["x"])), round(float(mote["y"])), size, size), color)
	# Two faint warm bands near the floor: hearth haze, not a second light
	# source.  They sit on the background layer, never over the player.
	var seam: float = 0.045 + 0.02 * (0.5 + 0.5 * sin(_time * 0.7 + 1.4))
	draw_rect(Rect2(0.0, 300.0, VIEW_SIZE.x, 1.0), Color(DEEP, seam))
	draw_rect(Rect2(0.0, 336.0, VIEW_SIZE.x, 1.0), Color(DEEP, seam * 0.7))
