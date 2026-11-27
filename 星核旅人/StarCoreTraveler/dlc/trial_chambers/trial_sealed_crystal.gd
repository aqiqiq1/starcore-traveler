class_name TrialSealedCrystal
extends Node2D

## The cyan twin that flanks the trial's gold gate.
##
## The approved trial rule is unchanged: only `PhaseCrystal` (gold, in front of
## the gold gate) can flip the body, and the cyan gate still requires the
## player's own Q.  This node is a **sealed, non-interactive relic**: it has no
## player path, no touch test, no collision and no audio.  It exists so the
## opening film can show a real cyan crystal on the door's other side instead of
## painting one, and so the gate's two-sided affinity composition is readable in
## the live level.
##
## The shard is deliberately caged: two stone side posts, a dark iron clamp and
## a 1 px crack tell the player this twin is dormant.  The film only raises its
## modulate and adds a world-space halo; the relic never becomes a pickup.

const GOLD: Color = Color("#f4cd63")  # only for the tiny base sun/moon mark
const CYAN: Color = Color("#5fe1e6")
const STONE: Color = Color("#2b3537")
const STONE_HI: Color = Color("#485558")
const STONE_LO: Color = Color("#0d1517")
const STONE_EDGE: Color = Color("#080d0f")
const IRON: Color = Color(0.10, 0.13, 0.14, 1.0)
const IRON_HI: Color = Color(0.28, 0.34, 0.35, 1.0)
const WHITE: Color = Color(1.0, 0.98, 0.88, 1.0)

var _time: float = 0.0


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	# Only the faint 1 px base stain breathes; the shard itself is sealed and
	# still.  This is a decoration, not a live pickup.
	if _time < 10.0:
		queue_redraw()


## Anchor the opening film uses for its cyan halo.  Same shard-centre height as
## the live PhaseCrystal so the two lights sit on one line.
func get_shard_center_global() -> Vector2:
	return global_position + Vector2(0.0, -19.0)


func is_display_only() -> bool:
	return true


func _draw() -> void:
	var shard_center: Vector2 = Vector2(0.0, -19.0)
	_draw_socket()
	_draw_shard(shard_center)
	_draw_cage(shard_center)


func _draw_socket() -> void:
	# Same three-step stone family as the live key crystal, so the pair reads as
	# one set; the extra iron clamp is what distinguishes the sealed twin.
	draw_rect(Rect2(-12.0, -1.0, 24.0, 1.0), STONE_EDGE)
	draw_rect(Rect2(-11.0, -3.0, 22.0, 2.0), STONE)
	draw_rect(Rect2(-11.0, -3.0, 22.0, 1.0), STONE_HI)
	draw_rect(Rect2(-8.0, -6.0, 16.0, 3.0), STONE)
	draw_rect(Rect2(-8.0, -6.0, 16.0, 1.0), STONE_HI)
	draw_rect(Rect2(-5.0, -9.0, 10.0, 3.0), STONE)
	draw_rect(Rect2(-5.0, -9.0, 10.0, 1.0), STONE_HI)
	draw_rect(Rect2(-8.0, -6.0, 1.0, 3.0), STONE_LO)
	draw_rect(Rect2(-5.0, -9.0, 1.0, 3.0), STONE_LO)
	draw_rect(Rect2(7.0, -6.0, 1.0, 3.0), STONE_LO)
	draw_rect(Rect2(4.0, -9.0, 1.0, 3.0), STONE_LO)
	# A hairline crack through the front step: the socket has been opened before
	# and re-sealed, but it no longer answers a touch.
	draw_rect(Rect2(-2.0, -2.0, 1.0, 1.0), STONE_EDGE)
	draw_rect(Rect2(-1.0, -3.0, 1.0, 1.0), STONE_EDGE)
	draw_rect(Rect2(0.0, -2.0, 1.0, 1.0), STONE_EDGE)
	# Faint cyan seep at the joint, the only motion on the idle relic.
	var breath: float = 0.10 + 0.05 * sin(_time * 2.0)
	draw_rect(Rect2(-1.0, -4.0, 2.0, 1.0), Color(CYAN, breath))


func _draw_shard(center: Vector2) -> void:
	# 10x16 diamond, same silhouette as the live crystal, but the fill is held
	# at a dim sealed value and a dark fracture runs through it.
	var outline: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -10.0),
		center + Vector2(7.0, -2.0),
		center + Vector2(0.0, 10.0),
		center + Vector2(-7.0, -2.0),
	])
	draw_colored_polygon(outline, STONE_EDGE)
	var fill: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -8.0),
		center + Vector2(5.0, -2.0),
		center + Vector2(0.0, 8.0),
		center + Vector2(-5.0, -2.0),
	])
	draw_colored_polygon(fill, Color(CYAN.darkened(0.18), 0.72))
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -8.0),
			center + Vector2(2.0, -2.0),
			center + Vector2(0.0, 6.0),
			center + Vector2(-3.0, -2.0),
		]),
		Color(CYAN.lightened(0.22), 0.55)
	)
	# Dull 1 px rim, no white core.
	draw_rect(Rect2(center + Vector2(-2.0, -6.0), Vector2(1.0, 1.0)),
		Color(CYAN.lightened(0.35), 0.55))
	# Fracture from the top facet to the bottom point.
	draw_rect(Rect2(center + Vector2(0.0, -10.0), Vector2(1.0, 1.0)), STONE_EDGE)
	draw_rect(Rect2(center + Vector2(-1.0, -9.0), Vector2(1.0, 3.0)), STONE_EDGE)
	draw_rect(Rect2(center + Vector2(0.0, -6.0), Vector2(1.0, 4.0)), STONE_EDGE)
	draw_rect(Rect2(center + Vector2(1.0, -2.0), Vector2(1.0, 3.0)), STONE_EDGE)
	draw_rect(Rect2(center + Vector2(0.0, 1.0), Vector2(1.0, 4.0)), STONE_EDGE)


func _draw_cage(center: Vector2) -> void:
	# Two stone posts and an iron clamp physically hold the shard.  Nothing here
	# can be mistaken for the bright, open glow of the working key crystal.
	draw_rect(Rect2(center.x - 11.0, center.y - 12.0, 3.0, 22.0), STONE_EDGE)
	draw_rect(Rect2(center.x - 10.0, center.y - 11.0, 2.0, 20.0), STONE)
	draw_rect(Rect2(center.x - 10.0, center.y - 11.0, 1.0, 20.0), STONE_HI)
	draw_rect(Rect2(center.x + 8.0, center.y - 12.0, 3.0, 22.0), STONE_EDGE)
	draw_rect(Rect2(center.x + 8.0, center.y - 11.0, 2.0, 20.0), STONE)
	draw_rect(Rect2(center.x + 9.0, center.y - 11.0, 1.0, 20.0), STONE_HI)
	# Iron clamp across the shard's waist.
	draw_rect(Rect2(center.x - 10.0, center.y - 2.0, 20.0, 4.0), STONE_EDGE)
	draw_rect(Rect2(center.x - 9.0, center.y - 1.0, 18.0, 2.0), IRON)
	draw_rect(Rect2(center.x - 9.0, center.y - 1.0, 18.0, 1.0), IRON_HI)
	# Two rivets and a short chain loop keep the clamp readable at 1x.
	draw_rect(Rect2(center.x - 7.0, center.y, 1.0, 1.0), STONE_HI)
	draw_rect(Rect2(center.x + 6.0, center.y, 1.0, 1.0), STONE_HI)
	draw_rect(Rect2(center.x - 1.0, center.y + 3.0, 2.0, 1.0), IRON_HI)
	draw_rect(Rect2(center.x - 2.0, center.y + 4.0, 1.0, 1.0), IRON_HI)
	draw_rect(Rect2(center.x + 1.0, center.y + 4.0, 1.0, 1.0), IRON_HI)
