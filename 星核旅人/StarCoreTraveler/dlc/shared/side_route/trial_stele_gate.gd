class_name TrialSteleGate
extends HiddenRouteGate

## Optional 星核试炼场 entrance in L3 断桥外郭, built from the game's existing
## tutorial stele.  The 26x52 cyan stele stands on a low cut-stone plinth at
## native size (no scale), with a dim cyan groove glow and a few rising sparks.
## It has no collision and is drawn just in front of the city ground, behind
## the player, so the main path is never blocked.
##
## Reference use: the in-project L1 stele (assets/tutorial_stele) and the
## Hollow Knight White Palace lore-tablet close-up recorded in
## dlc/hidden_levels_20261127/REFERENCE_20261127.md.  Only the dark-stone /
## single-lit-groove reading order is borrowed; the stele art itself is the
## project's own approved asset.

const STELE_TEXTURE: Texture2D = preload(
	"res://assets/tutorial_stele/tutorial_stele_cyan.png"
)
const STELE_SIZE: Vector2 = Vector2(26.0, 52.0)
const CYAN: Color = Color("#5fe1e6")
const STONE: Color = Color("#2b3537")
const STONE_HI: Color = Color("#485558")
const STONE_LO: Color = Color("#0d1517")
const DARK: Color = Color(0.02, 0.03, 0.04, 0.72)

var _time: float = 0.0


func _ready() -> void:
	super._ready()
	z_index = 3


func _process(delta: float) -> void:
	if get_tree() != null and get_tree().paused:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.8)

	# Ground shadow and a low, finished plinth: the stele stands on a real
	# footing instead of floating over the city pavement.
	draw_rect(Rect2(-22.0, -2.0, 44.0, 2.0), DARK)
	draw_rect(Rect2(-18.0, -6.0, 36.0, 4.0), STONE_LO)
	draw_rect(Rect2(-16.0, -6.0, 32.0, 3.0), STONE)
	draw_rect(Rect2(-16.0, -6.0, 32.0, 1.0), STONE_HI)
	draw_rect(Rect2(-11.0, -7.0, 22.0, 1.0), Color(CYAN, 0.30 + 0.16 * pulse))

	# Soft cyan bloom behind the real stone, never a second stele silhouette.
	for layer_index: int in range(3):
		var half_width: float = 11.0 + float(layer_index) * 5.0
		var half_height: float = 24.0 + float(layer_index) * 7.0
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(0.0, -30.0 - half_height),
				Vector2(half_width, -30.0),
				Vector2(0.0, -30.0 + half_height),
				Vector2(-half_width, -30.0),
			]),
			Color(CYAN, (0.035 - float(layer_index) * 0.008) * (0.75 + 0.25 * pulse))
		)

	draw_texture(STELE_TEXTURE, Vector2(-STELE_SIZE.x * 0.5, -STELE_SIZE.y - 6.0))

	# Three 1 px rising sparks keep the marker readable as a live side entrance
	# without adding a label over the world.
	for index: int in range(3):
		var rise: float = fmod(_time * 11.0 + float(index) * 9.0, 22.0)
		var spark_x: float = -8.0 + float(index) * 8.0
		draw_rect(
			Rect2(spark_x, -12.0 - rise, 1.0, 1.0),
			Color(CYAN, 0.28 + 0.24 * pulse)
		)

	if Engine.is_editor_hint():
		draw_rect(Rect2(-28.0, -104.0, 56.0, 104.0), Color(CYAN, 0.06), true)
