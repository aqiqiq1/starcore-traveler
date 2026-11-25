class_name LoomBrazier
extends Node2D

## Decorative city brazier with a two-frame flame.
##
## It is not a hitbox: the damaging fire comes from the floor vents.  The bowl
## stands on the hall floor and the whole prop draws at z=4, behind the player,
## so it adds light and city detail without hiding the fight.

const SPRITE: Texture2D = preload(
	"res://dlc/star_loom/assets/city/brazier_28x44_2f.png"
)
const WARM: Color = Color(0.94, 0.60, 0.28, 0.20)

var _sprite: Sprite2D = null
var _time: float = 0.0


func _ready() -> void:
	z_index = 4
	_sprite = Sprite2D.new()
	_sprite.name = "Brazier"
	_sprite.texture = SPRITE
	_sprite.hframes = 2
	_sprite.vframes = 1
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0.0, -22.0)
	add_child(_sprite)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _sprite != null:
		_sprite.frame = int(_time * 6.0) % 2
	queue_redraw()


func _draw() -> void:
	# A 1 px warm halo around the bowl, plus three rising embers.
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
	_ring(17.0 + pulse, Color(WARM, 0.18 + 0.10 * pulse))
	for index: int in range(3):
		var rise: float = fmod(_time * 22.0 + float(index) * 11.0, 34.0)
		draw_rect(
			Rect2(-6.0 + float(index) * 6.0, -40.0 - rise, 1.0, 1.0),
			Color(1.0, 0.86, 0.55, 0.35)
		)


func _ring(radius: float, color: Color) -> void:
	for index: int in range(24):
		var angle: float = float(index) * TAU / 24.0
		draw_rect(
			Rect2(round(cos(angle) * radius), round(sin(angle) * radius), 1.0, 1.0),
			color
		)
