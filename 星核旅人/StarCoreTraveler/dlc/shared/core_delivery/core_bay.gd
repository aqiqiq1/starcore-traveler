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
##
## The drawing itself lives in CoreBayLook so the base-game L2/L3 bays use
## exactly the same plinth, gold ring, flash and sparks.

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
var _sfx_enabled: bool = true


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


func set_sfx_enabled(value: bool) -> void:
	_sfx_enabled = value
	if not value and _sfx != null:
		_sfx.stop()
		_sfx.stream = null


func _play_seat_sfx(seated: bool) -> void:
	if not _sfx_enabled or _sfx == null:
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
	CoreBayLook.draw(self, CENTER, _lit, _flash, _time)
