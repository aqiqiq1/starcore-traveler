class_name CoreDeliveryBay
extends Node2D

## Shared star-core bay used by DLC2 rift-workshop and DLC3 star-loom.
## The original loom placement received the core at x = 330; the chapter owns
## the real world position, the bay only exposes its lit/empty state.
##
## The bay borrows the project's existing star-core bay art: the white 32x32
## pedestal (`assets/star_core_bay/star_core_bay_base.png`) and its pale-cyan
## dome (`assets/star_core_bay/star_core_bay_glass.png`).  Both are used 1:1;
## no new PNG is drawn for this scene.  The niche, low stone seats, gold cradle,
## empty core ring, lit seams and the short conduit toward the moon gate are
## code-drawn in the city's existing cold-stone / gold language.
##
## Empty state:
##   - the pedestal is dim cold stone, the glass is hidden, the niche is a dark
##     open mouth with a stone frame and a dim gold core ring, and the flanking
##     stone seats hold a dim gold cradle.  It reads as an empty bay, not a
##     floating black gem or a stone groove.
##
## Occupied state:
##   - the pedestal brightens, the glass dome fades/seals in front of the core,
##     the ring/cradle/seams light gold, a short flash and rising sparks play,
##     and a gold conduit carries power toward the moon gate at x = 380.
##
## Presentation is driven only by `set_occupied()`, which the chapter calls
## from the carrier's real x position.  The bay owns no collision, no force and
## no gate state, so pulling the core back out can never depend on a visual
## callback.

const BASE_TEXTURE: Texture2D = preload(
	"res://assets/star_core_bay/star_core_bay_base.png"
)
const GLASS_TEXTURE: Texture2D = preload(
	"res://assets/star_core_bay/star_core_bay_glass.png"
)
const CENTER: Vector2 = Vector2(0.0, -16.0)
## One paired gesture per state change: a metal seat plus a short charge when the
## core goes in, a pressure release when it comes out.
const INSERT_SFX: String = "res://assets/audio/sfx/core_insert.wav"
const REMOVE_SFX: String = "res://assets/audio/sfx/core_remove.wav"
const GOLD: Color = Color("#f4cd63")
const GOLD_DIM: Color = Color(0.957, 0.804, 0.388, 0.34)
const STONE: Color = Color("#2b3537")
const STONE_HI: Color = Color("#485558")
const STONE_LO: Color = Color("#0d1517")
const STONE_EDGE: Color = Color("#080d0f")
const DARK: Color = Color(0.02, 0.03, 0.04, 0.72)
const BAY_FLASH_TIME: float = 0.55
const LIT_SPEED: float = 5.0
const GLASS_ALPHA: float = 0.92

var _base: Sprite2D = null
var _glass: Sprite2D = null
var _occupied: bool = false
var _lit: float = 0.0
var _glass_alpha: float = 0.0
var _flash: float = 0.0
var _time: float = 0.0
var _sfx: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_base = get_node_or_null("Base") as Sprite2D
	_glass = get_node_or_null("Glass") as Sprite2D
	_ensure_sprites()
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "SeatSfx"
	_sfx.bus = "Master"
	add_child(_sfx)
	_lit = 0.0
	_glass_alpha = 0.0
	_apply_look()
	set_process(false)
	queue_redraw()


func _ensure_sprites() -> void:
	if _base == null:
		_base = Sprite2D.new()
		_base.name = "Base"
		_base.position = CENTER
		_base.centered = true
		_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_base.z_index = -1
		_base.texture = BASE_TEXTURE
		add_child(_base)
	if _glass == null:
		_glass = Sprite2D.new()
		_glass.name = "Glass"
		_glass.position = CENTER
		_glass.centered = true
		_glass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_glass.z_index = 1
		_glass.texture = GLASS_TEXTURE
		add_child(_glass)


## Called by the chapter every physics tick from the carrier's real x.
func set_occupied(value: bool) -> void:
	if _occupied == value:
		return
	_occupied = value
	_play_seat_sfx(value)
	if value:
		_flash = 1.0
	set_process(true)
	queue_redraw()


func is_occupied() -> bool:
	return _occupied


## Read for captures/tests: the bay is visibly lit only while occupied.
func is_lit() -> bool:
	return _occupied


## The seat cue that will play on the next state change, for tests/logs.
func get_seat_sfx_path(seated: bool = true) -> String:
	return INSERT_SFX if seated else REMOVE_SFX


func _play_seat_sfx(seated: bool) -> void:
	if _sfx == null:
		return
	var path: String = get_seat_sfx_path(seated)
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	_sfx.stream = stream
	_sfx.play()


func get_glow_strength() -> float:
	return 1.0 if _occupied else 0.0


## Smooth 0..1 lit blend used by the drawing, exposed for capture checks.
func get_lit_blend() -> float:
	return _lit


func get_base_sprite() -> Sprite2D:
	return _base


func get_glass_sprite() -> Sprite2D:
	return _glass


func get_flash_left() -> float:
	return _flash


func _apply_look() -> void:
	if _base != null:
		_base.modulate = Color(0.55, 0.61, 0.63, 1.0).lerp(Color.WHITE, _lit)
	if _glass != null:
		_glass.visible = _glass_alpha > 0.01
		_glass.modulate = Color(0.88, 0.97, 1.0, _glass_alpha)


func _process(delta: float) -> void:
	_time += delta
	var target_lit: float = 1.0 if _occupied else 0.0
	var target_glass: float = GLASS_ALPHA if _occupied else 0.0
	_lit = move_toward(_lit, target_lit, LIT_SPEED * delta)
	_glass_alpha = move_toward(_glass_alpha, target_glass, LIT_SPEED * delta)
	_flash = maxf(_flash - delta / BAY_FLASH_TIME, 0.0)
	_apply_look()
	if (
		not _occupied
		and _lit <= 0.0
		and _glass_alpha <= 0.0
		and _flash <= 0.0
	):
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.6)
	var seam: Color = GOLD_DIM.lerp(GOLD, _lit)
	var lit: float = _lit

	# The bay sits on the floor: a narrow dark shadow and two low stone lips.
	# The centre is the open niche, not one solid block.
	draw_rect(Rect2(-33.0, 0.0, 66.0, 2.0), DARK)
	draw_rect(Rect2(-27.0, 2.0, 54.0, 1.0), Color(DARK, 0.35))

	# Flanking stone lips stay low (floor level) so the core can slide in above
	# them.  Tall posts would sit in the core's 296-312 px path and make the
	# payload visibly pass through a stone arm; the bay's identity comes from
	# the base, niche, ring and the glass that seals in when occupied.
	for side: float in [-1.0, 1.0]:
		var x: float = 21.0 if side > 0.0 else -33.0
		draw_rect(Rect2(x, -7.0, 12.0, 8.0), STONE_EDGE)
		draw_rect(Rect2(x + 1.0, -6.0, 10.0, 6.0), STONE)
		draw_rect(Rect2(x + 1.0, -6.0, 10.0, 1.0), STONE_HI)
		draw_rect(Rect2(x + 2.0, -5.0, 8.0, 1.0), seam)
		if _occupied:
			draw_rect(Rect2(x + 2.0, -4.0, 8.0, 1.0), Color(GOLD, 0.70))

	# Connect the low side seats to the pedestal with a 1 px floor rail, so the
	# bay reads as one low plinth instead of three detached rectangles.  The
	# rail sits below the core's 296-312 px path.
	draw_rect(Rect2(-21.0, -4.0, 5.0, 1.0), STONE)
	draw_rect(Rect2(16.0, -4.0, 5.0, 1.0), STONE)
	draw_rect(Rect2(-21.0, -5.0, 5.0, 1.0), seam)
	draw_rect(Rect2(16.0, -5.0, 5.0, 1.0), seam)

	# The niche mouth: a dark recess cut into the pedestal, with a stone rim
	# and a gold core ring.  This is what makes the empty bay read as a
	# receptacle instead of a floating gem.
	draw_rect(Rect2(-12.0, -29.0, 24.0, 24.0), STONE_EDGE)
	draw_rect(Rect2(-11.0, -28.0, 22.0, 22.0), Color("#1b2528"))
	draw_rect(Rect2(-11.0, -28.0, 22.0, 1.0), STONE_HI)
	draw_rect(Rect2(-11.0, -7.0, 22.0, 1.0), STONE_LO)
	draw_rect(Rect2(-11.0, -28.0, 1.0, 21.0), STONE_LO)
	draw_rect(Rect2(10.0, -28.0, 1.0, 21.0), STONE_LO)
	# Cut the top corners by one pixel so the mouth has a small arch.
	draw_rect(Rect2(-12.0, -29.0, 2.0, 1.0), Color("#1b2528"))
	draw_rect(Rect2(10.0, -29.0, 2.0, 1.0), Color("#1b2528"))
	# Dim gold rim: the mouth is an empty but finished socket, not a hole.
	draw_rect(Rect2(-10.0, -27.0, 20.0, 1.0), Color(GOLD, 0.22 + 0.30 * lit))
	draw_rect(Rect2(-10.0, -6.0, 20.0, 1.0), Color(GOLD, 0.25 + 0.35 * lit))
	draw_rect(Rect2(-10.0, -26.0, 1.0, 20.0), Color(GOLD, 0.12 + 0.25 * lit))
	draw_rect(Rect2(9.0, -26.0, 1.0, 20.0), Color(GOLD, 0.12 + 0.25 * lit))

	# Empty core ring: 17 px diameter, dim gold when empty and bright when
	# the core is held.  The core itself covers the centre when seated.
	var ring_alpha: float = 0.42 + 0.45 * lit
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		draw_rect(
			Rect2(
				round(cos(angle) * 8.5),
				CENTER.y + round(sin(angle) * 8.5),
				1.0, 1.0
			),
			Color(GOLD, ring_alpha)
		)
	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0 + PI * 0.25
		draw_rect(
			Rect2(
				round(cos(angle) * 10.0),
				CENTER.y + round(sin(angle) * 10.0),
				2.0, 2.0
			),
			Color(GOLD, ring_alpha + 0.18)
		)

	# Cradle across the pedestal top; the two prongs hold the core's lower
	# corners.  This is code-drawn over the base sprite, so the seat is
	# readable while the base PNG stays untouched.
	draw_rect(Rect2(-13.0, -8.0, 26.0, 1.0), seam)
	for prong_x: float in [-13.0, 11.0]:
		draw_rect(Rect2(prong_x, -12.0, 2.0, 4.0), Color(STONE_EDGE, 0.95))
		draw_rect(Rect2(prong_x, -12.0, 2.0, 3.0), seam)

	# Floor conduit: dim groove when empty, moving gold dashes when powered.
	draw_rect(Rect2(21.0, -2.0, 30.0, 1.0), Color(STONE_EDGE, 0.95))
	if _occupied:
		var travel: float = fmod(_time * 26.0, 30.0)
		draw_rect(Rect2(21.0 + travel, -2.0, 5.0, 1.0), Color(GOLD, 0.86))
		draw_rect(Rect2(47.0, -4.0, 2.0, 3.0), Color(GOLD, 0.80))
		draw_rect(Rect2(49.0, -3.0, 1.0, 1.0), Color(GOLD, 0.55))

	# Lit bay: gold halo around the ring, a short light column and rising
	# sparks.  The existing glass sits in front at z=5 and the core at z=4, so
	# the core reads as being inside the dome, not pasted on top.
	if lit > 0.01:
		_fill_diamond(CENTER, 34.0, 30.0, Color(GOLD, (0.05 + 0.025 * pulse) * lit))
		_diamond_outline(CENTER, 28.0, 24.0, Color(GOLD, (0.30 + 0.16 * pulse) * lit))
		for index: int in range(3):
			var line_x: float = -3.0 + 3.0 * float(index)
			var y: float = -22.0
			while y > -48.0:
				var fade: float = clampf((y + 48.0) / 26.0, 0.0, 1.0)
				draw_rect(
					Rect2(line_x, y, 1.0, 2.0),
					Color(GOLD, (0.10 + 0.16 * pulse) * fade * lit)
				)
				y -= 4.0
		for index: int in range(6):
			var rise: float = fmod(_time * 18.0 + float(index) * 7.0, 26.0)
			var spark_x: float = -10.0 + float(index) * 4.0
			draw_rect(
				Rect2(spark_x, CENTER.y - rise, 1.0, 1.0),
				Color(1.0, 0.97, 0.86, (0.55 + 0.30 * pulse) * lit)
			)
		if _flash > 0.0:
			var expand: float = 1.0 - _flash
			_diamond_outline(
				CENTER, 28.0 + 24.0 * expand, 24.0 + 20.0 * expand,
				Color(1.0, 0.98, 0.90, _flash * 0.75)
			)
			_diamond_outline(
				CENTER, 21.0 + 11.0 * expand, 18.0 + 9.0 * expand,
				Color(GOLD, _flash * 0.55)
			)


func _fill_diamond(center: Vector2, width: float, height: float, color: Color) -> void:
	var half_h: float = height * 0.5
	var half_w: float = width * 0.5
	var y_start: int = int(round(center.y - half_h))
	var y_end: int = int(round(center.y + half_h))
	for y: int in range(y_start, y_end):
		var cy: float = (float(y) + 0.5 - center.y) / half_h
		if absf(cy) > 1.0:
			continue
		var span: int = int(round(half_w * (1.0 - absf(cy))))
		if span < 1:
			continue
		draw_rect(
			Rect2(center.x - float(span), float(y), float(span * 2), 1.0),
			color
		)


## One-pixel diamond rim, drawn with integer rows so it stays crisp at 1x.
func _diamond_outline(
	center: Vector2, width: float, height: float, color: Color
) -> void:
	var half_h: float = height * 0.5
	var half_w: float = width * 0.5
	var y_start: int = int(round(center.y - half_h))
	var y_end: int = int(round(center.y + half_h))
	for y: int in range(y_start, y_end):
		var cy: float = (float(y) + 0.5 - center.y) / half_h
		if absf(cy) > 1.0:
			continue
		var span: int = int(round(half_w * (1.0 - absf(cy))))
		if span < 1:
			continue
		draw_rect(Rect2(center.x - float(span), float(y), 1.0, 1.0), color)
		draw_rect(Rect2(center.x + float(span) - 1.0, float(y), 1.0, 1.0), color)
