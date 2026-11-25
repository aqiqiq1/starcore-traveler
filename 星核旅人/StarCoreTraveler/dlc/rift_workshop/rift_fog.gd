extends Node2D

## Rift-workshop background overlay, drawn over the read-only DS03 scene.
##
## Two original layers:
##   1. a generated 640x360 violet haze (assets/rift_fog_640x360.png) with a
##      slow alpha breathing, screen-fixed like DS03 itself;
##   2. code-drawn purple motes drifting upward and wrapping, plus a few
##      larger slow embers.
##
## The three base levels keep their own DS03 instances untouched: this node only
## exists inside dlc/rift_workshop/rift_workshop.tscn.  Nothing here is drawn
## over the terrain or gameplay (the whole Background CanvasLayer sits at
## layer -10, behind the world).

const FOG: Texture2D = preload("res://dlc/rift_workshop/assets/rift_fog_640x360.png")
const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const MOTE_COUNT: int = 46
const PURPLE: Color = Color("#a874ff")
const PURPLE_LIGHT: Color = Color("#d8bcff")
const DEEP: Color = Color("#6a3fb8")

var _motes: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
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
		var color: Color = PURPLE_LIGHT if bool(mote["bright"]) else PURPLE
		color.a = float(mote["alpha"])
		var size: float = float(mote["size"])
		draw_rect(Rect2(round(float(mote["x"])), round(float(mote["y"])), size, size), color)
	# Two thin violet horizon wisps: they read as the rift's open seam without
	# adding a screen-wide gradient over the ruin silhouettes.
	var seam: float = 0.10 + 0.05 * (0.5 + 0.5 * sin(_time * 0.7 + 1.4))
	draw_rect(Rect2(0.0, 248.0, VIEW_SIZE.x, 1.0), Color(DEEP, seam))
	draw_rect(Rect2(0.0, 268.0, VIEW_SIZE.x, 1.0), Color(DEEP, seam * 0.7))
