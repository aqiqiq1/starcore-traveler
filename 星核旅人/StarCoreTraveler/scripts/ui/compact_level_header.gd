class_name CompactLevelHeader
extends Control

## Shared compact top header for the three formal levels.
##
## The approved sample layout is deliberately small:
##   title 12 px at (12, 7), chapter 12 px at (12, 23),
##   right-side 20x20 gold-sun / cyan-moon phase icon with no text.
## There is no panel, no "护符相性" caption, no large 24 px heading and no
## permanent "Q 切换" line. Every control ignores the mouse.

const VIEW_WIDTH: float = 640.0
const HEADER_HEIGHT: float = 40.0
const TITLE_POSITION: Vector2 = Vector2(12.0, 7.0)
const TITLE_SIZE: Vector2 = Vector2(240.0, 16.0)
const SUBTITLE_POSITION: Vector2 = Vector2(12.0, 23.0)
const SUBTITLE_SIZE: Vector2 = Vector2(240.0, 16.0)
## Right-top slot: 20x20 icon, right edge 630, 10 px margin. The old affinity
## word label is kept as a hidden data mirror for existing HUD/test callers.
const ICON_POSITION: Vector2 = Vector2(610.0, 6.0)
const ICON_SIZE: Vector2 = Vector2(20.0, 20.0)
const AFFINITY_POSITION: Vector2 = Vector2(606.0, 8.0)
const AFFINITY_SIZE: Vector2 = Vector2(24.0, 16.0)
const RIGHT_MARGIN: float = 10.0
const FONT_SIZE: int = 12

const TEXT_WARM: Color = Color("#e8e2d5")
const TEXT_MUTED: Color = Color("#9fb0b2")
const OUTLINE_DARK: Color = Color(0.015, 0.03, 0.035, 0.85)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

var _title_label: Label
var _subtitle_label: Label
var _icon: PolarityPhaseIcon
var _affinity_label: Label
var _font_override: Font
var _title_text: String = ""
var _subtitle_text: String = ""
var _positive: bool = true
var _built: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(VIEW_WIDTH, HEADER_HEIGHT)
	_build()
	_apply_text()
	_apply_polarity()


## Called by a level HUD after add_child() (or before; pending text is applied
## when the children are built).
func configure(title_text: String, subtitle_text: String, font: Font = null) -> void:
	_title_text = title_text
	_subtitle_text = subtitle_text
	if font != null:
		_font_override = font
	if _built:
		_apply_text()


func set_polarity(positive: bool) -> void:
	_positive = positive
	if _built:
		_apply_polarity()


func _build() -> void:
	if _built:
		return
	_built = true
	var font: Font = _resolve_font()
	_title_label = _make_label(TITLE_POSITION, TITLE_SIZE, TEXT_WARM, font)
	_title_label.name = "CompactTitle"
	add_child(_title_label)
	_subtitle_label = _make_label(SUBTITLE_POSITION, SUBTITLE_SIZE, TEXT_MUTED, font)
	_subtitle_label.name = "CompactSubtitle"
	add_child(_subtitle_label)

	_icon = PolarityPhaseIcon.new()
	_icon.name = "AffinityIcon"
	_icon.position = ICON_POSITION
	_icon.size = ICON_SIZE
	_icon.custom_minimum_size = ICON_SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	# Hidden data mirror: the visible phase read is icon-only, while older HUDs
	# and tests can still query "辉相/澜相" through get_affinity_text().
	_affinity_label = _make_label(AFFINITY_POSITION, AFFINITY_SIZE, GOLD, font)
	_affinity_label.name = "AffinityText"
	_affinity_label.visible = false
	add_child(_affinity_label)
	_apply_text()
	_apply_polarity()


func _make_label(position_value: Vector2, size_value: Vector2, color: Color, font: Font) -> Label:
	var label: Label = Label.new()
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	label.add_theme_constant_override("outline_size", 1)
	return label


func _resolve_font() -> Font:
	if _font_override != null:
		return _font_override
	if not ResourceLoader.exists(FONT_PATH):
		return ThemeDB.fallback_font
	var base_font: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if base_font == null:
		return ThemeDB.fallback_font
	var copy: FontFile = base_font.duplicate() as FontFile
	if copy == null:
		return base_font
	copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	copy.hinting = TextServer.HINTING_NONE
	copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	copy.allow_system_fallback = false
	copy.generate_mipmaps = false
	copy.oversampling = 1.0
	return copy


func _apply_text() -> void:
	if _title_label != null:
		_title_label.text = _title_text
	if _subtitle_label != null:
		_subtitle_label.text = _subtitle_text


func _apply_polarity() -> void:
	if _icon != null:
		_icon.set_positive(_positive)
	if _affinity_label != null:
		_affinity_label.text = "辉相" if _positive else "澜相"
		_affinity_label.add_theme_color_override("font_color", GOLD if _positive else CYAN)


func get_title_text() -> String:
	return _title_label.text if _title_label != null else _title_text


func get_subtitle_text() -> String:
	return _subtitle_label.text if _subtitle_label != null else _subtitle_text


func get_affinity_text() -> String:
	return _affinity_label.text if _affinity_label != null else ("辉相" if _positive else "澜相")


func get_affinity_color() -> Color:
	return _affinity_label.get_theme_color("font_color") if _affinity_label != null else GOLD


## Kept for older callers; the header now draws the badge instead of loading a
## talisman texture.
func get_icon_texture_path() -> String:
	return ""


func get_icon_texture() -> Texture2D:
	return null


func get_icon_size() -> Vector2:
	return _icon.size if _icon != null else Vector2.ZERO


func get_icon_source_size() -> Vector2:
	return _icon.get_icon_size() if _icon != null else Vector2.ZERO


func get_phase_icon() -> PolarityPhaseIcon:
	return _icon


## "sun" for 辉相, "moon" for 澜相; icon-only HUD read.
func get_phase_kind() -> String:
	if _icon != null:
		return _icon.get_kind()
	return "sun" if _positive else "moon"


func get_phase_color() -> Color:
	if _icon != null:
		return _icon.get_phase_color()
	return GOLD if _positive else CYAN


func is_phase_text_visible() -> bool:
	return _affinity_label != null and _affinity_label.visible


func get_icon_rect() -> Rect2:
	return Rect2(ICON_POSITION, ICON_SIZE)


func get_affinity_rect() -> Rect2:
	return Rect2(AFFINITY_POSITION, AFFINITY_SIZE)


func get_title_rect() -> Rect2:
	return Rect2(TITLE_POSITION, TITLE_SIZE)


func get_subtitle_rect() -> Rect2:
	return Rect2(SUBTITLE_POSITION, SUBTITLE_SIZE)


func get_header_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(VIEW_WIDTH, HEADER_HEIGHT))


func get_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for node: Node in find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


func has_panel() -> bool:
	return not find_children("*", "Panel", true, false).is_empty()


func is_mouse_ignored() -> bool:
	return (
		mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _title_label != null and _title_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _subtitle_label != null and _subtitle_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _icon != null and _icon.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _affinity_label != null and _affinity_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
	)
