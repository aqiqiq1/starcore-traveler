class_name InteractionKeyHint
extends RefCounted

## Single shared drawing/sizing source for the approved on-screen interaction
## keycap (2026-11-18 local-interaction pass).
##
## One 11x13 dark cap, 1 px gold border, 9 px gold key glyph, 4 px gap, then a
## 12 px gold action word with a 1 px dark shadow. These are the same numbers
## and look as the old approved L3 E keycap; L1 (F 交谈), L2 (E release/store)
## and L3 (E device/pickup/embed/store) all draw through this helper so there is
## exactly one style source. It is presentation only: callers keep their own
## real range, anchor and viewport clamp. A transient state ("开罩中…") must be
## drawn with draw_state(), never with a cap, so it cannot suggest a repeat key.

const KEY_SIZE: Vector2 = Vector2(11.0, 13.0)
const KEY_GAP: float = 4.0
const KEY_FONT_SIZE: int = 9
const ACTION_FONT_SIZE: int = 12
## Both the key glyph and the action word share this baseline offset from the
## top of the cap (old L3: cap top pos.y-1, baseline pos.y+9).
const TEXT_BASELINE: float = 10.0

const GOLD: Color = Color("#f4cd63")
const KEY_BG: Color = Color(0.006, 0.014, 0.018, 0.92)
const KEY_BORDER: Color = Color(0.956, 0.803, 0.388, 0.90)
const SHADOW: Color = Color(0.006, 0.014, 0.018, 0.96)


static func action_width(font: Font, verb: String) -> float:
	return KEY_SIZE.x + KEY_GAP + text_width(font, verb)


static func state_width(font: Font, text: String) -> float:
	return text_width(font, text)


static func text_width(font: Font, text: String) -> float:
	if text.is_empty():
		return 0.0
	var use_font: Font = _font_or_fallback(font)
	return ceilf(use_font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ACTION_FONT_SIZE
	).x)


## Draws the keycap plus the action word. `origin` is the top-left of the cap
## and is expected to be pixel-rounded by the caller.
static func draw_action(
	canvas: CanvasItem, font: Font, origin: Vector2, key: String, verb: String
) -> void:
	if canvas == null or key.is_empty():
		return
	var use_font: Font = _font_or_fallback(font)
	var key_rect: Rect2 = Rect2(origin, KEY_SIZE)
	canvas.draw_rect(key_rect, KEY_BG, true)
	canvas.draw_rect(key_rect, KEY_BORDER, false, 1.0)
	var key_width: float = use_font.get_string_size(
		key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, KEY_FONT_SIZE
	).x
	var key_x: float = origin.x + floorf((KEY_SIZE.x - key_width) * 0.5)
	canvas.draw_string(
		use_font, Vector2(key_x, origin.y + TEXT_BASELINE), key,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, KEY_FONT_SIZE, GOLD
	)
	var verb_pos: Vector2 = origin + Vector2(KEY_SIZE.x + KEY_GAP, TEXT_BASELINE)
	canvas.draw_string(
		use_font, verb_pos + Vector2(1.0, 1.0), verb,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, ACTION_FONT_SIZE, SHADOW
	)
	canvas.draw_string(
		use_font, verb_pos, verb,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, ACTION_FONT_SIZE, GOLD
	)


## Gold state text with the same shadow, but no keycap: used while a lid is
## opening/closing so the hint cannot imply a repeat E press.
static func draw_state(
	canvas: CanvasItem, font: Font, origin: Vector2, text: String
) -> void:
	if canvas == null or text.is_empty():
		return
	var use_font: Font = _font_or_fallback(font)
	var text_pos: Vector2 = origin + Vector2(0.0, TEXT_BASELINE)
	canvas.draw_string(
		use_font, text_pos + Vector2(1.0, 1.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, ACTION_FONT_SIZE, SHADOW
	)
	canvas.draw_string(
		use_font, text_pos, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, ACTION_FONT_SIZE, GOLD
	)


static func _font_or_fallback(font: Font) -> Font:
	return font if font != null else ThemeDB.fallback_font
