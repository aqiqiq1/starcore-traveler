class_name HudObjective
extends Control

## Unified one-line top-left objective for every chapter plus the shared
## 20x20 top-right phase icon.
##
## Approved layout (dlc/PRESENTATION_SYSTEM.md, 2026-11-27):
##   one row at y = 6: chapter name 12 px warm white, then one objective line
##   12 px gold.  An event replaces the objective line and cross-fades in / out
##   over 0.15 s.  The right-top read is one 20x20 gold-sun / cyan-moon icon on
##   a dark plate with no "相 / 辉相 / 澜相" text.  There is no panel and no
##   second event row.
##
## Presentation reference (opened 2026-11-27):
##   Hades, "Use the Mirror to Grow Stronger" (Game UI Database,
##   Hades01242021-120216-6615.jpg): a single small mission line at the
##   top-left, no caption block.  Only the edge-anchored one-line reading is
##   borrowed; no pixels, palette or layout is copied.

const VIEW_WIDTH: float = 640.0
const ROW_Y: float = 6.0
const ROW_HEIGHT: float = 16.0
const CHAPTER_X: float = 12.0
const OBJECTIVE_GAP: float = 10.0
const TEXT_RIGHT_EDGE: float = 600.0
const FONT_SIZE: int = 12
const OUTLINE_SIZE: int = 1
const ICON_POSITION: Vector2 = Vector2(610.0, 4.0)
const ICON_SIZE: Vector2 = Vector2(20.0, 20.0)
const EVENT_FADE: float = 0.15
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

const TEXT_WARM: Color = Color("#e8e2d5")
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const OUTLINE_DARK: Color = Color(0.006, 0.014, 0.018, 0.96)

var _font: Font
var _chapter_label: Label
var _objective_label: Label
var _event_label: Label
var _icon: PolarityPhaseIcon
var _chapter_text: String = ""
var _objective_raw: String = ""
var _display_objective: String = ""
var _event_text: String = ""
var _event_left: float = 0.0
var _event_tween: Tween
var _fade_tween: Tween
var _positive: bool = true
var _built: bool = false
var _chrome_visible: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW_WIDTH, 22.0)
	size = Vector2(VIEW_WIDTH, 22.0)
	_build()
	_apply_all()
	set_process(false)


func _process(delta: float) -> void:
	if _event_left <= 0.0:
		return
	_event_left = maxf(_event_left - delta, 0.0)
	if _event_left <= 0.0:
		_start_event_out()


func configure(chapter_text: String, objective_text: String, font: Font = null) -> void:
	_chapter_text = chapter_text
	_objective_raw = objective_text
	_display_objective = _display_of(objective_text)
	if font != null:
		_font = font
	if _built:
		_apply_all()


func set_chapter(chapter_text: String) -> void:
	_chapter_text = chapter_text
	if _chapter_label != null:
		_chapter_label.text = chapter_text
		_layout_labels()


func set_objective(objective_text: String) -> void:
	_objective_raw = objective_text
	_display_objective = _display_of(objective_text)
	if _objective_label != null and _event_left <= 0.0:
		_objective_label.text = _display_objective


## Event replaces the objective line for the whole duration.  The swap is a
## 0.15 s cross-fade; it never grows a second row.
func show_event(text_value: String, duration: float = 1.5) -> void:
	if _event_label == null:
		return
	if text_value.is_empty():
		clear_event()
		return
	_kill_event_tween()
	_event_text = text_value
	_event_left = clampf(duration, 0.2, 2.6)
	_event_label.text = text_value
	_event_label.visible = true
	_event_label.modulate.a = 0.0
	_objective_label.modulate.a = 1.0
	_event_tween = _make_tween()
	_event_tween.set_parallel(true)
	_event_tween.tween_property(_objective_label, "modulate:a", 0.0, EVENT_FADE)
	_event_tween.tween_property(_event_label, "modulate:a", 1.0, EVENT_FADE)
	set_process(true)


func clear_event() -> void:
	_kill_event_tween()
	_event_left = 0.0
	if _event_label != null:
		_event_label.visible = false
		_event_label.modulate.a = 0.0
	if _objective_label != null:
		_objective_label.modulate.a = 1.0
	set_process(false)


func _start_event_out() -> void:
	if _event_label == null or not _event_label.visible:
		clear_event()
		return
	_kill_event_tween()
	_event_tween = _make_tween()
	_event_tween.set_parallel(true)
	_event_tween.tween_property(_event_label, "modulate:a", 0.0, EVENT_FADE)
	_event_tween.tween_property(_objective_label, "modulate:a", 1.0, EVENT_FADE)
	_event_tween.chain().tween_callback(_on_event_out_finished)


func _on_event_out_finished() -> void:
	if _event_left > 0.0:
		return
	_event_text = ""
	if _event_label != null:
		_event_label.visible = false
		_event_label.modulate.a = 0.0
	if _objective_label != null:
		_objective_label.modulate.a = 1.0
	set_process(false)


func set_polarity(positive: bool) -> void:
	_positive = positive
	if _icon != null:
		_icon.set_positive(positive)


## Modal pages hide the whole chapter/objective/event/icon row.  Restoring it
## fades back in over 0.15 s; focus and input never wait on the tween.
func set_chrome_visible(value: bool) -> void:
	if _chrome_visible == value:
		return
	_chrome_visible = value
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if not value:
		visible = false
		return
	visible = true
	modulate.a = 0.0
	_fade_tween = _make_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, EVENT_FADE)


func fade_in(duration: float = EVENT_FADE) -> void:
	# A caller may have just revealed the chrome with the default 0.15 s and then
	# asks for a custom duration (the L1 opening hand-off uses 0.25 s). Kill the
	# first tween so the requested duration is the one that actually runs.
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = true
	modulate.a = 0.0
	_fade_tween = _make_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, duration)


func is_chrome_visible() -> bool:
	return _chrome_visible and visible


func _build() -> void:
	if _built:
		return
	_built = true
	if _font == null:
		_font = _load_font()
	_chapter_label = _make_label()
	_chapter_label.name = "ChapterLabel"
	add_child(_chapter_label)
	_objective_label = _make_label()
	_objective_label.name = "ObjectiveLabel"
	add_child(_objective_label)
	_event_label = _make_label()
	_event_label.name = "EventLabel"
	_event_label.visible = false
	_event_label.modulate.a = 0.0
	add_child(_event_label)
	_icon = PolarityPhaseIcon.new()
	_icon.name = "AffinityIcon"
	_icon.position = ICON_POSITION
	_icon.size = ICON_SIZE
	_icon.custom_minimum_size = ICON_SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_icon.set_positive(_positive)


func _make_label() -> Label:
	var label: Label = Label.new()
	label.position = Vector2.ZERO
	label.size = Vector2(TEXT_RIGHT_EDGE - CHAPTER_X, ROW_HEIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	return label


func _apply_all() -> void:
	if _chapter_label == null:
		return
	_chapter_label.text = _chapter_text
	_chapter_label.add_theme_color_override("font_color", TEXT_WARM)
	_objective_label.text = _display_objective
	_objective_label.add_theme_color_override("font_color", GOLD)
	_event_label.add_theme_color_override("font_color", GOLD)
	_layout_labels()


## The objective starts after the real measured chapter width, so every chapter
## gets the same 10 px separation without a second line or a fixed column.
func _layout_labels() -> void:
	if _chapter_label == null:
		return
	var chapter_width: float = _measure(_chapter_text)
	var chapter_rect_width: float = minf(chapter_width + 2.0, TEXT_RIGHT_EDGE - CHAPTER_X)
	_chapter_label.position = Vector2(CHAPTER_X, ROW_Y)
	_chapter_label.size = Vector2(chapter_rect_width, ROW_HEIGHT)
	var objective_x: float = CHAPTER_X + chapter_rect_width + OBJECTIVE_GAP
	var objective_width: float = maxf(TEXT_RIGHT_EDGE - objective_x, 40.0)
	_objective_label.position = Vector2(objective_x, ROW_Y)
	_objective_label.size = Vector2(objective_width, ROW_HEIGHT)
	_event_label.position = Vector2(objective_x, ROW_Y)
	_event_label.size = Vector2(objective_width, ROW_HEIGHT)


func _measure(text_value: String) -> float:
	if _font == null or text_value.is_empty():
		return 0.0
	return ceilf(_font.get_string_size(
		text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
	).x)


func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return ThemeDB.fallback_font
	var font_file: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if font_file == null:
		return ThemeDB.fallback_font
	var copy: FontFile = font_file.duplicate() as FontFile
	if copy == null:
		return font_file
	copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	copy.hinting = TextServer.HINTING_NONE
	copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	copy.allow_system_fallback = false
	copy.generate_mipmaps = false
	copy.oversampling = 1.0
	return copy


func _make_tween() -> Tween:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _kill_event_tween() -> void:
	if _event_tween != null and _event_tween.is_valid():
		_event_tween.kill()
	_event_tween = null


## Visible copy drops the old "任务：" / "目标：" prefixes so the one line starts
## with the actionable words.  Callers keep their compatibility strings.
func _display_of(text_value: String) -> String:
	var text: String = text_value
	for prefix: String in ["任务：", "目标：", "任务:", "目标:"]:
		if text.begins_with(prefix):
			text = text.substr(prefix.length())
			break
	return text.strip_edges()


# --- compatibility accessors (old CompactLevelHeader callers/tests) ---------

func get_title_text() -> String:
	return _chapter_text


func get_subtitle_text() -> String:
	return _objective_raw


func get_objective_text() -> String:
	return _objective_raw


func get_display_objective_text() -> String:
	return _display_objective


func get_event_text() -> String:
	return _event_text


func is_event_visible() -> bool:
	return _event_label != null and _event_label.visible and _event_left > 0.0


func get_affinity_text() -> String:
	return "辉相" if _positive else "澜相"


func get_affinity_color() -> Color:
	return GOLD if _positive else CYAN


func get_phase_icon() -> PolarityPhaseIcon:
	return _icon


func get_phase_kind() -> String:
	return _icon.get_kind() if _icon != null else ("sun" if _positive else "moon")


func get_phase_color() -> Color:
	return _icon.get_phase_color() if _icon != null else (GOLD if _positive else CYAN)


func get_icon_size() -> Vector2:
	return ICON_SIZE


func get_icon_rect() -> Rect2:
	return Rect2(ICON_POSITION, ICON_SIZE)


func get_affinity_rect() -> Rect2:
	return get_icon_rect()


func get_title_rect() -> Rect2:
	return Rect2(_chapter_label.position, _chapter_label.size)


func get_subtitle_rect() -> Rect2:
	return Rect2(_objective_label.position, _objective_label.size)


func get_header_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(VIEW_WIDTH, 22.0))


func is_phase_text_visible() -> bool:
	return false


func has_panel() -> bool:
	return false


func is_mouse_ignored() -> bool:
	return (
		mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _chapter_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _objective_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _event_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _icon.mouse_filter == Control.MOUSE_FILTER_IGNORE
	)


func get_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for node: Node in find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.visible:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


## Old name kept for the HUDs that hide the old talisman icon.  There is no
## separate texture; every chapter now uses the same drawn PolarityPhaseIcon.
func get_icon_texture_path() -> String:
	return ""


func get_icon_texture() -> Texture2D:
	return null


func get_icon_source_size() -> Vector2:
	return ICON_SIZE
