class_name PromptFooter
extends Control

## Shared one-line page footer for the three base-story prompts (L1 opening film,
## L2 watcher echo, L3 cinematic).  The DLC guide keeps its in-panel footer; only
## its page content gets the 0.12 s crossfade.
##
## It only draws copy.  It never reads input, never changes pause and never owns
## page state: the owner decides *when* a page is waiting for F and calls
## show_footer()/hide_footer().  Appearance is an immediate 0.15 s alpha fade-in;
## hiding is immediate so a closed page never delays the owner's input.
##
## Geometry follows the 640x360 presentation standard: one 12 px warm-grey line,
## right edge at x=628, text baseline at y=334, and 16 px inline keycaps taken
## from the shared KeyGlyph art (the same caps used by the approved guide rows).
## No panel, shadow or full-screen dimmer is created; the owner adds this Control
## under its existing CanvasLayer.

const PAGE_FOOTER: String = "{F} 继续 · 长按空格 跳过"
const SINGLE_FOOTER: String = "{F} 继续"

const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const FONT_SIZE: int = 12
const TEXT_COLOR: Color = Color("#a4b3be")
const SHADOW_DARK: Color = Color(0.006, 0.014, 0.018, 0.85)
const SCRIM_COLOR: Color = Color(0.006, 0.014, 0.018, 0.62)
const RIGHT_EDGE: float = 628.0
const BASELINE_Y: float = 334.0
const KEYCAP_HEIGHT: int = 16
## Vertical offset of the cap's top from the text baseline.  13 px above the
## baseline keeps the 16 px cap optically centred on the 12 px line.
const KEYCAP_TOP_OFFSET: float = -13.0
const FADE_IN_TIME: float = 0.15
const PANEL_WIDTH: float = 400.0
const PANEL_HEIGHT: float = 24.0
const PANEL_LEFT: float = RIGHT_EDGE - PANEL_WIDTH
const PANEL_TOP: float = BASELINE_Y - 20.0

static var _shared_font: FontFile = null
static var _font_checked: bool = false
static var _key_textures: Dictionary = {}

var _text: String = ""
var _tween: Tween = null


func _ready() -> void:
	name = "PromptFooter"
	position = Vector2(PANEL_LEFT, PANEL_TOP)
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate.a = 0.0
	visible = false


## Shows one footer line.  Repeated calls with the same copy while already
## visible are a no-op, so the owner may call this every frame.
func show_footer(text: String) -> void:
	if text.is_empty():
		hide_footer()
		return
	if visible:
		# The owner may call this every frame.  Repeating the same copy must not
		# restart the fade; a copy change (e.g. last page) just redraws.
		if _text != text:
			_text = text
			queue_redraw()
		return
	_text = text
	visible = true
	modulate.a = 0.0
	queue_redraw()
	_kill_tween()
	if not is_inside_tree():
		modulate.a = 1.0
		return
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.finished.connect(_on_fade_finished)


## Hides immediately; no fade-out can hold a closed page or its input back.
func hide_footer() -> void:
	_kill_tween()
	_text = ""
	modulate.a = 0.0
	visible = false


func get_text() -> String:
	return _text if visible else ""


func get_plain_text() -> String:
	return KeyGlyph.plain(get_text())


func get_font_size() -> int:
	return FONT_SIZE


func get_text_color() -> Color:
	return TEXT_COLOR


func get_keycap_height() -> int:
	return KEYCAP_HEIGHT


func get_right_edge() -> float:
	return position.x + size.x


func get_baseline_y() -> float:
	return position.y + (BASELINE_Y - PANEL_TOP)


func is_fading_in() -> bool:
	return _tween != null and _tween.is_valid()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _on_fade_finished() -> void:
	_tween = null
	modulate.a = 1.0


func _draw() -> void:
	if _text.is_empty():
		return
	var font: Font = _get_font()
	if font == null:
		return
	var segments: Array[Dictionary] = _segments(font)
	if segments.is_empty():
		return
	var total_width: float = 0.0
	for segment: Dictionary in segments:
		total_width += float(segment["width"])
	var x: float = roundf(size.x - total_width)
	var baseline: float = BASELINE_Y - PANEL_TOP
	# A short translucent scrim under the row keeps the low-contrast warm-grey
	# copy readable over the light stone floor (L2) without adding a panel or a
	# border.  On the black cinematic bands it is invisible.
	draw_rect(
		Rect2(x - 4.0, baseline - 12.0, total_width + 8.0, 16.0),
		SCRIM_COLOR
	)
	for segment: Dictionary in segments:
		var width: float = float(segment["width"])
		if bool(segment["key"]):
			var key: String = String(segment["text"])
			var texture: Texture2D = _key_texture(key)
			if texture != null:
				draw_texture_rect(
					texture,
					Rect2(x, baseline + KEYCAP_TOP_OFFSET, width, float(KEYCAP_HEIGHT)),
					false
				)
			else:
				draw_string(
					font, Vector2(x, baseline), key,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, TEXT_COLOR
				)
		else:
			# A 1 px offset shadow keeps the warm-grey line readable where it
			# crosses the light stone floor (L2).  An outline would eat the 1 px
			# strokes of the native 12 px pixel font, so the shadow is offset, not
			# stroked.
			var copy: String = String(segment["text"])
			draw_string(
				font, Vector2(x + 1.0, baseline + 1.0), copy,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, SHADOW_DARK
			)
			draw_string(
				font, Vector2(x, baseline), copy,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, TEXT_COLOR
			)
		x += width


## Splits copy into ordered text/keycap runs and measures each exactly once.
## `{F}` resolves through KeyGlyph so the footer always uses the same 16 px cap
## art and width rounding as the approved guide/popup rows.
func _segments(font: Font) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending: String = ""
	var index: int = 0
	while index < _text.length():
		var open: int = _text.find("{", index)
		if open < 0:
			pending += _text.substr(index)
			break
		var close: int = _text.find("}", open + 1)
		if close < 0:
			pending += _text.substr(index)
			break
		var key: String = _text.substr(open + 1, close - open - 1)
		if not KeyGlyph.KEYS.has(key):
			pending += _text.substr(index, close - open + 1)
			index = close + 1
			continue
		if open > index:
			pending += _text.substr(index, open - index)
		if not pending.is_empty():
			result.append({
				"text": pending,
				"key": false,
				"width": font.get_string_size(
					pending, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE
				).x,
			})
			pending = ""
		var data: Dictionary = KeyGlyph.KEYS[key] as Dictionary
		var base_width: int = int(data["width"])
		var width: float = float(maxi(
			roundi(float(base_width) * float(KEYCAP_HEIGHT) / float(KeyGlyph.ICON_HEIGHT)),
			1
		))
		result.append({"text": key, "key": true, "width": width})
		index = close + 1
	if not pending.is_empty():
		result.append({
			"text": pending,
			"key": false,
			"width": font.get_string_size(
				pending, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE
			).x,
		})
	return result


static func _key_texture(key: String) -> Texture2D:
	if _key_textures.has(key):
		return _key_textures[key] as Texture2D
	var data: Variant = KeyGlyph.KEYS.get(key)
	if not (data is Dictionary):
		_key_textures[key] = null
		return null
	var path: String = KeyGlyph.ICON_DIR + String((data as Dictionary)["file"])
	var texture: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		texture = ResourceLoader.load(
			path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE
		) as Texture2D
	_key_textures[key] = texture
	return texture


static func _get_font() -> FontFile:
	return UiFont.get_font_file()
