class_name MirrorRiftGate
extends HiddenRouteGate

## Optional 裂隙工坊 entrance in DLC3 星核织机, set into the hall wall between
## the recorded checkpoint and the boss arena trigger.  It is built only from
## the chapter's existing mirror art: the 48x48 cyan mirror face plus shards
## cut from its broken variant, inside a code-drawn cold-stone recess and a
## narrow cyan fissure.  No collision, no new texture, and the checkpoint and
## body always draw in front.
##
## Reference use: the real rift workshop mirror hall
## (screenshots/rift_opening_20261127/01_mirror_hall_wide.png) for the round
## mounted mirror / dark arch language, and the recorded Hollow Knight lore
## tablet close-up for "one lit element inside a dark stone frame".  The
## specific composition here is original to this project.

const MIRROR_BROKEN: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_face_cyan_broken_48x48.png"
)
const CYAN: Color = Color("#5fe1e6")
const PALE: Color = Color("#b6f4f2")
const STONE: Color = Color("#2b3537")
const STONE_HI: Color = Color("#485558")
const STONE_LO: Color = Color("#0d1517")
const STONE_EDGE: Color = Color("#080d0f")
const DARK: Color = Color(0.008, 0.022, 0.028, 0.94)

var _time: float = 0.0
var _face: Sprite2D = null
var _shard: Sprite2D = null


func _ready() -> void:
	super._ready()
	z_index = 1
	_build_mirror_art()


func _build_visual() -> void:
	# Art children are built in _ready after the base sets the node's mode.
	pass


func _build_mirror_art() -> void:
	_face = _make_sprite("MirrorFace", MIRROR_BROKEN, Vector2(0.0, -72.0))
	# One small fallen shard resting inside the sill, cut from the same
	# approved broken face.  It is decor, never a second portal.
	_shard = _make_sprite("MirrorShard", MIRROR_BROKEN, Vector2(13.0, -10.0))
	_shard.region_enabled = true
	_shard.region_rect = Rect2(30.0, 26.0, 12.0, 14.0)
	_shard.flip_h = true


func _make_sprite(sprite_name: String, texture: Texture2D, local_position: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.position = local_position
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	if get_tree() != null and get_tree().paused:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.1)

	# Dark cool-stone recess: a tall narrow opening in the hall wall, with a
	# few faint masonry courses so it reads as a built niche rather than a
	# flat black rectangle.  The top corners are cut one pixel.
	draw_rect(Rect2(-22.0, -100.0, 44.0, 100.0), STONE_EDGE)
	draw_rect(Rect2(-20.0, -98.0, 40.0, 98.0), STONE_LO)
	draw_rect(Rect2(-18.0, -96.0, 36.0, 96.0), DARK)
	draw_rect(Rect2(-22.0, -100.0, 6.0, 3.0), STONE_LO)
	draw_rect(Rect2(16.0, -100.0, 6.0, 3.0), STONE_LO)
	for course_y: int in [-78, -52, -26]:
		draw_rect(Rect2(-17.0, float(course_y), 34.0, 1.0), Color(STONE, 0.20))
		draw_rect(Rect2(-17.0, float(course_y + 1), 34.0, 1.0), Color(0.0, 0.0, 0.0, 0.28))
	# Inner shadow at the left/top and a lit sill at the floor.
	draw_rect(Rect2(-18.0, -96.0, 1.0, 96.0), Color(STONE_EDGE, 0.9))
	draw_rect(Rect2(-18.0, -96.0, 36.0, 1.0), Color(STONE_EDGE, 0.9))
	draw_rect(Rect2(-16.0, -3.0, 32.0, 3.0), STONE_LO)
	draw_rect(Rect2(-16.0, -3.0, 32.0, 1.0), STONE_HI)

	# Stone surround, with a single highlighted course on the left.
	draw_rect(Rect2(-28.0, -104.0, 8.0, 104.0), STONE_EDGE)
	draw_rect(Rect2(-27.0, -103.0, 6.0, 103.0), STONE)
	draw_rect(Rect2(-27.0, -103.0, 1.0, 101.0), STONE_HI)
	draw_rect(Rect2(20.0, -104.0, 8.0, 104.0), STONE_EDGE)
	draw_rect(Rect2(21.0, -103.0, 6.0, 103.0), STONE)
	draw_rect(Rect2(21.0, -103.0, 1.0, 101.0), STONE_HI)
	draw_rect(Rect2(-22.0, -110.0, 44.0, 7.0), STONE_EDGE)
	draw_rect(Rect2(-21.0, -109.0, 42.0, 5.0), STONE)
	draw_rect(Rect2(-21.0, -109.0, 42.0, 1.0), STONE_HI)
	draw_rect(Rect2(-20.0, -105.0, 40.0, 1.0), Color(CYAN, 0.18 + 0.10 * pulse))

	# The fissure: a narrow cyan seam under the mirror face, with a brighter
	# 1 px centre and offset crack branches.  It reaches the floor so the
	# entrance still reads as a vertical rift, not a wall plaque.
	var seam_alpha: float = 0.34 + 0.16 * pulse
	draw_rect(Rect2(-4.0, -50.0, 8.0, 47.0), Color(CYAN, 0.07 + 0.05 * pulse))
	draw_rect(Rect2(-1.0, -50.0, 2.0, 47.0), Color(CYAN, seam_alpha))
	draw_rect(Rect2(0.0, -50.0, 1.0, 47.0), Color(PALE, seam_alpha + 0.18))
	draw_rect(Rect2(-7.0, -33.0, 5.0, 1.0), Color(CYAN, seam_alpha * 0.8))
	draw_rect(Rect2(2.0, -24.0, 6.0, 1.0), Color(CYAN, seam_alpha * 0.8))
	draw_rect(Rect2(-9.0, -14.0, 6.0, 1.0), Color(CYAN, seam_alpha * 0.65))

	# Small fallen shards at the foot, clear of the walking body.
	draw_rect(Rect2(-16.0, -3.0, 7.0, 2.0), STONE_LO)
	draw_rect(Rect2(-15.0, -4.0, 5.0, 1.0), STONE_HI)
	draw_rect(Rect2(9.0, -3.0, 6.0, 2.0), STONE_LO)
	draw_rect(Rect2(10.0, -4.0, 3.0, 1.0), Color(CYAN, 0.20 + 0.10 * pulse))

	# Rising sparks around the lower seam.
	for index: int in range(4):
		var rise: float = fmod(_time * 13.0 + float(index) * 7.0, 28.0)
		var spark_x: float = -2.0 + float(index % 2) * 4.0
		draw_rect(
			Rect2(spark_x, -6.0 - rise, 1.0, 1.0),
			Color(PALE, 0.22 + 0.20 * pulse)
		)

	if Engine.is_editor_hint():
		draw_rect(Rect2(-28.0, -110.0, 56.0, 110.0), Color(CYAN, 0.06), true)
