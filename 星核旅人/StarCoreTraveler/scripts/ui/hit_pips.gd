class_name HitPips
extends Control

## Icon-only counter for hits and lives.  The base HUD spells "受击 1 / 3";
## the DLC rows replace that text with pips so the count is readable without
## reading a sentence.  Seven-pixel art, no anti-aliasing, no labels.

enum Kind { HEART, DIAMOND, STAR }

@export var kind: Kind = Kind.HEART
@export var max_pips: int = 3
@export var current: int = 3
@export var pip_size: float = 8.0
@export var gap: float = 3.0
@export var filled_color: Color = Color("#f4cd63")
@export var empty_color: Color = Color(0.28, 0.34, 0.36, 0.95)

var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_size()
	set_process(false)


func set_state(current_value: int, max_value: int) -> void:
	var changed: bool = current_value != current or max_value != max_pips
	current = clampi(current_value, 0, max_value)
	max_pips = maxi(max_value, 1)
	_refresh_size()
	queue_redraw()
	if changed:
		_pulse = 1.0
		set_process(true)


func get_current() -> int:
	return current


func get_max() -> int:
	return max_pips


func _refresh_size() -> void:
	custom_minimum_size = Vector2(
		float(max_pips) * pip_size + float(maxi(max_pips - 1, 0)) * gap,
		pip_size
	)
	size = custom_minimum_size


func _process(delta: float) -> void:
	_pulse = maxf(_pulse - delta * 4.0, 0.0)
	queue_redraw()
	if _pulse <= 0.0:
		set_process(false)


func _draw() -> void:
	var alpha: float = 1.0 + 0.35 * _pulse
	for index: int in range(max_pips):
		var origin: Vector2 = Vector2(float(index) * (pip_size + gap), 0.0)
		var color: Color = filled_color if index < current else empty_color
		color.a = minf(color.a * alpha, 1.0)
		if kind == Kind.HEART:
			_draw_heart(origin, color)
		elif kind == Kind.STAR:
			_draw_star(origin, color)
		else:
			_draw_diamond(origin, color)


## 7x6 pixel heart, drawn as integer rects so it stays crisp at 1x.
func _draw_heart(origin: Vector2, color: Color) -> void:
	var rows: Array[String] = [
		".xx.xx.",
		"xxxxxxx",
		"xxxxxxx",
		".xxxxx.",
		"..xxx..",
		"...x...",
	]
	for y: int in range(rows.size()):
		for x: int in range(rows[y].length()):
			if rows[y][x] != "x":
				continue
			draw_rect(
				Rect2(origin + Vector2(float(x), float(y)), Vector2.ONE),
				color
			)


## A 7x7 diamond with a 1 px dark outline.
func _draw_diamond(origin: Vector2, color: Color) -> void:
	var half: int = 3
	for y: int in range(7):
		var span: int = half - absi(y - half)
		var left: int = half - span
		var right: int = half + span
		for x: int in range(left, right + 1):
			draw_rect(
				Rect2(origin + Vector2(float(x), float(y)), Vector2.ONE),
				color
			)


## A 7x7 pixel star for the run's life count; distinct from health hearts.
func _draw_star(origin: Vector2, color: Color) -> void:
	var rows: Array[String] = [
		"...x...",
		"..xxx..",
		"xxxxxxx",
		".xxxxx.",
		"..x.x..",
		".x...x.",
		"...x...",
	]
	for y: int in range(rows.size()):
		for x: int in range(rows[y].length()):
			if rows[y][x] != "x":
				continue
			draw_rect(
				Rect2(origin + Vector2(float(x), float(y)), Vector2.ONE),
				color
			)
