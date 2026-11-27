class_name OpeningSteleGlow
extends Node2D

## Real-scene light layer for the level-01 stele. It does not replace the stele
## or draw a second monument: the grey carrier stone remains the GuideEcho's own
## Sprite2D, and this node only lights its existing groove mask from the centre
## outward, gold in the core and cyan at the travelling tips.
##
## The node is authored under World/GuideEchoMeeting in level_01.tscn. The
## opening controller drives reveal/intensity; ordinary gameplay never touches
## it, so the stele can keep a faint trace after the film if the controller
## leaves one.

const MASK_PATH: String = "res://assets/tutorial_stele/tutorial_stele_groove_mask.png"
const CARRIER_OFFSET: Vector2 = Vector2(-13.0, -52.0)
const MASK_SIZE: Vector2 = Vector2(26.0, 52.0)
const GROOVE_TOP: int = 9
const GROOVE_BOTTOM: int = 44
const GROOVE_CENTER: float = 26.5
const GOLD: Color = Color(1.0, 0.82, 0.38, 1.0)
const CYAN: Color = Color(0.37, 0.88, 0.90, 1.0)
const WHITE: Color = Color(1.0, 0.98, 0.88, 1.0)

var _mask: Texture2D = null
var _reveal: float = 0.0
var _intensity: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(MASK_PATH, "Texture2D"):
		_mask = ResourceLoader.load(
			MASK_PATH, "Texture2D", ResourceLoader.CACHE_MODE_REUSE
		) as Texture2D
	visible = false
	set_process(false)


func set_state(reveal: float, intensity: float) -> void:
	_reveal = clampf(reveal, 0.0, 1.0)
	_intensity = clampf(intensity, 0.0, 1.0)
	visible = _intensity > 0.001
	set_process(visible)
	queue_redraw()


func set_visible_lit(value: bool) -> void:
	if not value:
		set_state(0.0, 0.0)
		return
	visible = true
	set_process(true)
	queue_redraw()


func get_reveal() -> float:
	return _reveal


func get_intensity() -> float:
	return _intensity


func _process(delta: float) -> void:
	_pulse += delta
	if _intensity > 0.001:
		queue_redraw()


func _draw() -> void:
	if _mask == null or _intensity <= 0.001:
		return
	var flicker: float = 1.0 + 0.04 * sin(_pulse * 5.2)
	var top: int = clampi(roundi(lerpf(GROOVE_CENTER - 0.5, float(GROOVE_TOP), _reveal)), GROOVE_TOP, GROOVE_BOTTOM)
	var bottom: int = clampi(roundi(lerpf(GROOVE_CENTER + 1.5, float(GROOVE_BOTTOM + 1), _reveal)), GROOVE_TOP + 1, GROOVE_BOTTOM + 1)
	var height: int = maxi(bottom - top, 1)
	var center: Vector2 = CARRIER_OFFSET + Vector2(MASK_SIZE.x * 0.5, GROOVE_CENTER)

	# Soft diamond bloom behind the real stone. It is deliberately a few
	# translucent polygons, not a second stele silhouette.
	for layer_index: int in range(3):
		var half_width: float = 9.0 + float(layer_index) * 6.0
		var half_height: float = 26.0 + float(layer_index) * 8.0
		var alpha: float = (0.042 - float(layer_index) * 0.010) * _intensity * flicker
		draw_colored_polygon(
			PackedVector2Array([
				center + Vector2(0.0, -half_height),
				center + Vector2(half_width, 0.0),
				center + Vector2(0.0, half_height),
				center + Vector2(-half_width, 0.0),
			]),
			Color(GOLD, alpha)
		)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -22.0),
			center + Vector2(7.0, 0.0),
			center + Vector2(0.0, 22.0),
			center + Vector2(-7.0, 0.0),
		]),
		Color(CYAN, 0.026 * _intensity * flicker)
	)

	var destination: Rect2 = Rect2(
		CARRIER_OFFSET.x + 1.0, CARRIER_OFFSET.y + float(top), MASK_SIZE.x - 2.0, float(height)
	)
	var source: Rect2 = Rect2(1.0, float(top), MASK_SIZE.x - 2.0, float(height))
	draw_texture_rect_region(_mask, destination, source, Color(GOLD, 0.94 * _intensity * flicker))

	# Cyan tips: the new light travels along the groove rather than switching
	# the whole stone on at once.
	if height > 7 and _reveal > 0.16:
		var tip_alpha: float = 0.78 * _intensity * flicker
		draw_texture_rect_region(
			_mask,
			Rect2(CARRIER_OFFSET.x + 1.0, CARRIER_OFFSET.y + float(top), MASK_SIZE.x - 2.0, 2.0),
			Rect2(1.0, float(top), MASK_SIZE.x - 2.0, 2.0),
			Color(CYAN, tip_alpha)
		)
		draw_texture_rect_region(
			_mask,
			Rect2(CARRIER_OFFSET.x + 1.0, CARRIER_OFFSET.y + float(bottom - 2), MASK_SIZE.x - 2.0, 2.0),
			Rect2(1.0, float(bottom - 2), MASK_SIZE.x - 2.0, 2.0),
			Color(CYAN, tip_alpha)
		)

	var center_alpha: float = clampf((_reveal - 0.35) / 0.65, 0.0, 1.0) * _intensity
	if center_alpha > 0.0:
		draw_rect(
			Rect2(center.x - 1.0, CARRIER_OFFSET.y + GROOVE_CENTER - 1.0, 3.0, 3.0),
			Color(WHITE, 0.82 * center_alpha * flicker)
		)
