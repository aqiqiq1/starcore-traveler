class_name TrialQHint
extends Node2D

## Icon-only "press Q" feedback that hovers over the player's head.
##
## The trial's gates show a large sun/moon lock icon; when the player walks into
## a gate of the other phase, the gate pulses red and this keycap appears for
## one second.  There is no text popup and no sentence: the shared 11x13 keycap
## language is enlarged to 18x20 (1 px gold border, dark fill, gold Q glyph and
## a small down-pointing marker).
##
## The node is a child of the player, so it follows the body without reading
## input or changing gameplay.  It is PAUSABLE: the pause page, the guide and a
## frozen recovery hold the icon instead of letting its timer run behind the
## black cover.

const DURATION: float = 1.0
const CAP_WIDTH: float = 18.0
const CAP_HEIGHT: float = 20.0
const GOLD: Color = Color("#f4cd63")
const BORDER: Color = Color(0.956, 0.803, 0.388, 0.96)
const BG: Color = Color(0.006, 0.014, 0.018, 0.94)
const SHADOW: Color = Color(0.006, 0.014, 0.018, 0.96)
const WHITE: Color = Color(1.0, 0.96, 0.80, 1.0)
## 8x11 pixel Q with a tail below the bowl.  Row strings keep the glyph crisp
## at the project's 1x pixel scale.
const Q_ROWS: Array[String] = [
	".xxxxxx.",
	"xx....xx",
	"xx....xx",
	"xx....xx",
	"xx....xx",
	"xx....xx",
	"xx....xx",
	".xxxxxx.",
	"......xx",
	"......xx",
	".....xxx",
]

var _remaining: float = 0.0
var _show_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 12
	visible = false
	set_process(false)


func show_q(duration: float = DURATION) -> void:
	_remaining = maxf(duration, 0.05)
	_show_count += 1
	visible = true
	queue_redraw()
	set_process(true)


func hide_hint() -> void:
	_remaining = 0.0
	visible = false
	set_process(false)


func is_active() -> bool:
	return visible and _remaining > 0.0


func get_remaining() -> float:
	return _remaining


func get_show_count() -> int:
	return _show_count


func get_cap_rect() -> Rect2:
	return Rect2(Vector2(-CAP_WIDTH * 0.5, -CAP_HEIGHT), Vector2(CAP_WIDTH, CAP_HEIGHT))


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		hide_hint()
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining <= 0.0:
		hide_hint()
		return
	queue_redraw()


func _draw() -> void:
	var elapsed: float = DURATION - _remaining
	# A tiny 2 px lift on appearance, then settle; no continuous spinning.
	var bob: float = -round(2.0 * sin(clampf(elapsed / 0.12, 0.0, 1.0) * PI))
	var fade: float = clampf(_remaining / 0.20, 0.0, 1.0)
	var alpha: float = fade
	var shadow_offset: Vector2 = Vector2(0.0, 1.0)
	var cap: Rect2 = Rect2(
		Vector2(-CAP_WIDTH * 0.5, -CAP_HEIGHT + bob),
		Vector2(CAP_WIDTH, CAP_HEIGHT)
	)

	# Downward pointer makes the icon read as "this is about the body below".
	draw_rect(Rect2(-2.0, cap.position.y + CAP_HEIGHT, 4.0, 1.0),
		Color(BORDER, alpha))
	draw_rect(Rect2(-1.0, cap.position.y + CAP_HEIGHT + 1.0, 2.0, 2.0),
		Color(BORDER, alpha))
	draw_rect(Rect2(0.0, cap.position.y + CAP_HEIGHT + 3.0, 1.0, 1.0),
		Color(BORDER, alpha))

	draw_rect(cap, Color(BG, alpha))
	draw_rect(cap, Color(BORDER, alpha), false, 1.0)
	# Top inner highlight, same approved keycap look scaled up.
	draw_rect(Rect2(cap.position + Vector2(1.0, 1.0), Vector2(CAP_WIDTH - 2.0, 1.0)),
		Color(1.0, 1.0, 1.0, 0.14 * alpha))

	var glyph_width: float = float(Q_ROWS[0].length())
	var glyph_height: float = float(Q_ROWS.size())
	var glyph_origin: Vector2 = Vector2(
		floorf(-glyph_width * 0.5),
		floorf(cap.position.y + (CAP_HEIGHT - glyph_height) * 0.5)
	)
	for y: int in range(Q_ROWS.size()):
		for x: int in range(Q_ROWS[y].length()):
			if Q_ROWS[y][x] != "x":
				continue
			draw_rect(
				Rect2(glyph_origin + Vector2(float(x), float(y)) + shadow_offset, Vector2.ONE),
				Color(SHADOW, alpha)
			)
	for y: int in range(Q_ROWS.size()):
		for x: int in range(Q_ROWS[y].length()):
			if Q_ROWS[y][x] != "x":
				continue
			draw_rect(
				Rect2(glyph_origin + Vector2(float(x), float(y)), Vector2.ONE),
				Color(GOLD, alpha)
			)
	# One-pixel white spark on the cap's top-right corner: the same "alive" read
	# as the crystal and gate cores without adding a second symbol.
	draw_rect(Rect2(cap.position + Vector2(CAP_WIDTH - 3.0, 2.0), Vector2(1.0, 1.0)),
		Color(WHITE, alpha))
