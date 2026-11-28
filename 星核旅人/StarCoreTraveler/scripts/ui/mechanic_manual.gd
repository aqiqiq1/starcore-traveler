class_name MechanicManual
extends CanvasLayer

## Pause-page mechanism manual shared by the base three levels and DLC1-3.
##
## Content comes only from MechanicRegistry (name / summary / key / icon) plus
## the unlocked ids in MechanicTeach's progress file.  Locked rows read ？？？;
## unlocked rows read the registry copy.  The page never changes gameplay or
## pause state: it is an overlay above the already-paused pause page.
##
## Layout (2026-11-28 rework): 620x300 panel inside 640x360, 8 rows per page at
## a 24 px pitch, so 15 registry rows need two pages.  Columns are separated
## with a real gutter (icon / name / summary / key); an over-wide summary is
## trimmed and ellipsised before it can reach the key column.  Page indicator
## sits bottom-right in its own band, clear of the last row.
##
## Close routes: Esc or the in-panel 返回 button.  F / → turn to the next page
## (wrapping), ← to the previous page.  Every key is swallowed while open, so
## a page turn can never also press a pause-page button.  Opening focus goes to
## the 返回 button so the same keyboard route always works.

signal opened
signal closed

const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")
const TEACH = preload("res://scripts/ui/mechanic_teach.gd")

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const PANEL_POSITION: Vector2 = Vector2(10.0, 30.0)
const PANEL_SIZE: Vector2 = Vector2(620.0, 300.0)
const ROWS_PER_PAGE: int = 8
const ROW_START_Y: float = 58.0
const ROW_STEP: float = 24.0
const ROW_HEIGHT: float = 22.0
const ROW_TEXT_Y: float = 3.0
const ROW_ICON_X: float = 14.0
## 12x12 icons are vertically centred in the 22 px row (3 + 16 text = 22).
const ROW_ICON_Y: float = 5.0
const ICON_SIZE: float = 12.0
## 48 leaves a 22 px gap after the 12x12 icon.  The key column is unchanged:
## the SPACE keycap is still 27 px at 16 px high.
const ROW_NAME_X: float = 48.0
const ROW_NAME_WIDTH: float = 72.0
const ROW_SUMMARY_X: float = 128.0
const ROW_SUMMARY_WIDTH: float = 400.0
const ROW_KEY_X: float = 544.0
const DIVIDER_Y: float = 52.0
## Footer band sits below the 8th row (58 + 7*24 + 22 = 248) with a 6 px gap.
const FOOTER_DIVIDER_Y: float = 254.0
const FOOTER_Y: float = 266.0
const FOOTER_HEIGHT: float = 14.0
const ELLIPSIS: String = "…"
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const KEYCAP_DIR: String = "res://assets/ui/keycaps/"

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DIM: Color = Color("#728889")
const PANEL_BG: Color = Color(0.014, 0.032, 0.040, 0.98)
const PANEL_BORDER: Color = Color(0.45, 0.66, 0.63, 0.9)

## Empty = MechanicTeach.get_progress_path() (the production user:// file).
var progress_path: String = ""

var _root: Control = null
var _shade: ColorRect = null
var _panel: Panel = null
var _title: Label = null
var _subtitle: Label = null
var _back_button: PixelMenuButton = null
var _footer: RichTextLabel = null
var _page_indicator: Label = null
var _font: Font = null
var _rows: Array[Dictionary] = []
var _row_name_labels: Array[Label] = []
var _row_summary_labels: Array[Label] = []
var _row_state: Dictionary = {}
var _open: bool = false
var _unlocked: Dictionary = {}
var _page_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 17
	_font = _load_font()
	_build_ui()
	_root.visible = false
	set_process(true)


func _process(_delta: float) -> void:
	pass


func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)
	if code == KEY_ESCAPE:
		close()
	elif code == KEY_F or code == KEY_RIGHT:
		turn_page(1)
	elif code == KEY_LEFT:
		turn_page(-1)
	# Every key belongs to the manual while it is open, so the pause/chapter
	# input handlers cannot resume, restart or act behind the page.
	get_viewport().set_input_as_handled()


# --- Public API ------------------------------------------------------------

func open() -> bool:
	if _open or _root == null:
		return false
	refresh()
	_page_index = 0
	_apply_page_layout()
	_open = true
	_root.visible = true
	if _back_button != null:
		call_deferred("_focus_back")
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	if _back_button != null:
		_back_button.release_focus()
	closed.emit()


func is_open() -> bool:
	return _open


func get_progress_path() -> String:
	return progress_path if not progress_path.is_empty() else TEACH.get_progress_path()


func get_visible_unlocked_count() -> int:
	return _unlocked.size()


func get_locked_count() -> int:
	return REGISTRY.count() - _unlocked.size()


func get_total_count() -> int:
	return REGISTRY.count()


func get_subtitle_text() -> String:
	return _subtitle.text if _subtitle != null else ""


func get_back_button() -> PixelMenuButton:
	return _back_button


## Real 12 px pixel font used by every row, so the acceptance test can measure
## the same text widths the manual measures.
func get_row_font() -> Font:
	return _font


func get_summary_overrun_behaviors() -> Array[int]:
	var out: Array[int] = []
	for label: Label in _row_summary_labels:
		if label != null:
			out.append(int(label.text_overrun_behavior))
	return out


func get_row_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for label: Label in _row_name_labels:
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	for label: Label in _row_summary_labels:
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


## Read-only row snapshot for tests/captures: id -> {name, summary, key,
## unlocked, locked_name, locked_summary}.
func get_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in REGISTRY.all_ids():
		var entry: Dictionary = REGISTRY.get_entry(id)
		var unlocked: bool = _unlocked.has(id)
		out.append({
			"id": id,
			"name": String(entry.get("name", "")),
			"summary": String(entry.get("summary", "")),
			"key": String(entry.get("key", "")),
			"unlocked": unlocked,
			"shown_name": String(entry.get("name", "")) if unlocked else "？？？",
			"shown_summary": String(entry.get("summary", "")) if unlocked else "",
		})
	return out


func get_row_text(id: String) -> String:
	if not _open:
		return ""
	for row: Dictionary in _rows:
		if String(row.get("id", "")) == id:
			var name_label: Label = row.get("name_label", null) as Label
			var summary_label: Label = row.get("summary_label", null) as Label
			if name_label == null:
				return ""
			return "%s  %s" % [name_label.text, summary_label.text if summary_label != null else ""]
	return ""


func get_page_count() -> int:
	return maxi(int(ceil(float(REGISTRY.count()) / float(ROWS_PER_PAGE))), 1)


func get_page_index() -> int:
	return _page_index


## 1-based "1 / 2" copy, always present so the player can see the total.
func get_page_indicator_text() -> String:
	return _page_indicator.text if _page_indicator != null else ""


func get_rows_per_page() -> int:
	return ROWS_PER_PAGE


func get_row_step() -> float:
	return ROW_STEP


func get_row_height() -> float:
	return ROW_HEIGHT


func get_panel_rect() -> Rect2:
	return Rect2(PANEL_POSITION, PANEL_SIZE)


## Panel-local column rectangles.  The summary rect never touches the key rect;
## tests use this to prove the gutter instead of trusting the screenshot.
func get_column_rects() -> Dictionary:
	return {
		"icon": Rect2(ROW_ICON_X, ROW_ICON_Y, ICON_SIZE, ICON_SIZE),
		"name": Rect2(ROW_NAME_X, ROW_TEXT_Y, ROW_NAME_WIDTH, 16.0),
		"summary": Rect2(ROW_SUMMARY_X, ROW_TEXT_Y, ROW_SUMMARY_WIDTH, 16.0),
		"key": Rect2(ROW_KEY_X, ROW_TEXT_Y, 60.0, 16.0),
	}


## Bottom band: footer text left, page indicator right.  Neither may overlap
## the last row, the panel border or each other.
func get_footer_rects() -> Dictionary:
	return {
		"footer": Rect2(16.0, FOOTER_Y, 420.0, FOOTER_HEIGHT),
		"page_indicator": Rect2(480.0, FOOTER_Y, 120.0, FOOTER_HEIGHT),
		"divider_y": FOOTER_DIVIDER_Y,
	}


func get_last_row_bottom() -> float:
	var last_index: int = mini(ROWS_PER_PAGE, REGISTRY.count()) - 1
	return ROW_START_Y + float(last_index) * ROW_STEP + ROW_HEIGHT


## Ids that are visible on the current page, in row order.
func get_visible_row_ids() -> Array[String]:
	var ids: Array[String] = []
	for index: int in range(_rows.size()):
		if int(index / ROWS_PER_PAGE) != _page_index:
			continue
		var row: Dictionary = _rows[index]
		var row_root: Control = row.get("root", null) as Control
		if row_root != null and row_root.visible:
			ids.append(String(row.get("id", "")))
	return ids


## Row rectangle in panel space for the current page (hidden rows return empty).
func get_current_row_rects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index: int in range(_rows.size()):
		if int(index / ROWS_PER_PAGE) != _page_index:
			continue
		var row: Dictionary = _rows[index]
		out.append({
			"id": String(row.get("id", "")),
			"rect": Rect2(
				ROW_NAME_X,
				ROW_START_Y + float(index % ROWS_PER_PAGE) * ROW_STEP,
				PANEL_SIZE.x - ROW_NAME_X * 2.0,
				ROW_HEIGHT
			),
		})
	return out


## Icon/key boxes in row-local space for the visible rows.  Icons are dedicated
## 12x12 textures; the key column keeps its 16 px-high keycaps.  A TextureRect
## whose minimum size was not ignored used to report 20 px here instead of the
## requested size, which is exactly the row-overlap regression.
func get_current_row_glyph_rects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index: int in range(_rows.size()):
		if int(index / ROWS_PER_PAGE) != _page_index:
			continue
		var row: Dictionary = _rows[index]
		var icon: Control = row.get("icon", null) as Control
		var key_node: Control = row.get("key", null) as Control
		out.append({
			"id": String(row.get("id", "")),
			"name": Rect2(ROW_NAME_X, ROW_TEXT_Y, ROW_NAME_WIDTH, 16.0),
			"icon": Rect2(icon.position, icon.size) if icon != null and icon.visible else Rect2(),
			"key": Rect2(key_node.position, key_node.size) if key_node != null and key_node.visible else Rect2(),
		})
	return out


## Actual 12x12 icon textures for the visible rows.  The acceptance test checks
## both the loaded path and the on-screen 12x12 box; a missing file leaves the
## icon node null/invisible instead of silently falling back to a keycap.
func get_current_row_icon_textures() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index: int in range(_rows.size()):
		if int(index / ROWS_PER_PAGE) != _page_index:
			continue
		var row: Dictionary = _rows[index]
		var icon_node: Control = row.get("icon", null) as Control
		var path: String = ""
		var texture_size: Vector2 = Vector2.ZERO
		if icon_node is TextureRect:
			var texture_rect: TextureRect = icon_node as TextureRect
			if texture_rect.texture != null:
				path = texture_rect.texture.resource_path
				texture_size = texture_rect.size
		out.append({
			"id": String(row.get("id", "")),
			"path": path,
			"size": texture_size,
		})
	return out


## Actual key-column textures for the visible rows.  The manual never turns a
## keycap into a row icon any more; this lets the acceptance test prove the
## right-hand key column still shows the real keycap art.
func get_current_row_key_textures() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index: int in range(_rows.size()):
		if int(index / ROWS_PER_PAGE) != _page_index:
			continue
		var row: Dictionary = _rows[index]
		var key_node: Control = row.get("key", null) as Control
		var path: String = ""
		var texture_size: Vector2 = Vector2.ZERO
		if key_node is TextureRect:
			var texture_rect: TextureRect = key_node as TextureRect
			if texture_rect.texture != null:
				path = texture_rect.texture.resource_path
				texture_size = texture_rect.size
		out.append({
			"id": String(row.get("id", "")),
			"path": path,
			"size": texture_size,
		})
	return out


## Trim + ellipsis used for the summary column.  Kept static and public so the
## acceptance test can feed an over-wide string and check the real rule.
static func fit_text(text_value: String, font: Font, max_width: float, font_size: int) -> String:
	if font == null or max_width <= 0.0:
		return text_value
	if font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
		return text_value
	var out: String = ""
	for index: int in range(text_value.length()):
		var candidate: String = out + text_value[index]
		if font.get_string_size(candidate + ELLIPSIS, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
			break
		out = candidate
	return out + ELLIPSIS


func turn_page(delta: int) -> void:
	if not _open:
		return
	var count: int = get_page_count()
	if count <= 1:
		return
	_page_index = posmod(_page_index + delta, count)
	_apply_page_layout()


## Re-reads the progress file.  Called on every open so a mechanism taught in
## the same pause session is already readable.
func refresh() -> void:
	_unlocked = TEACH.load_unlocked_ids(get_progress_path())
	for row: Dictionary in _rows:
		_apply_row(row)
	if _subtitle != null:
		_subtitle.text = "已解锁 %d / %d · 首次遇到自动记录" % [
			_unlocked.size(), REGISTRY.count()
		]
	_apply_page_layout()


# --- Build UI --------------------------------------------------------------

func _focus_back() -> void:
	if _open and _back_button != null:
		_back_button.grab_focus()


func _load_font() -> Font:
	return UiFont.get_font()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MechanicManualRoot"
	_root.position = Vector2.ZERO
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_shade = ColorRect.new()
	_shade.position = Vector2.ZERO
	_shade.size = VIEW_SIZE
	_shade.color = Color(0.006, 0.014, 0.018, 0.90)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_shade)

	_panel = Panel.new()
	_panel.name = "ManualPanel"
	_panel.position = PANEL_POSITION
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(2)
	style.anti_aliasing = false
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	_title = _label("机制手册", Vector2(16.0, 6.0), Vector2(300.0, 28.0), 24, GOLD)
	_panel.add_child(_title)

	_subtitle = _label("", Vector2(16.0, 34.0), Vector2(430.0, 14.0), 12, MUTED)
	_panel.add_child(_subtitle)

	_back_button = PixelMenuButton.new()
	_back_button.name = "ManualBackButton"
	_back_button.text = "返回"
	_back_button.position = Vector2(508.0, 8.0)
	_back_button.size = Vector2(96.0, 24.0)
	_back_button.font = _font
	_back_button.font_size = 12
	_back_button.variant = PixelMenuButton.Variant.OPTION
	_back_button.pressed.connect(close)
	_panel.add_child(_back_button)

	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(16.0, DIVIDER_Y)
	divider.size = Vector2(588.0, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.40)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(divider)

	var index: int = 0
	for id: String in REGISTRY.all_ids():
		var row_root: Control = Control.new()
		row_root.name = "Row_%s" % id
		row_root.position = Vector2(0.0, ROW_START_Y + float(index % ROWS_PER_PAGE) * ROW_STEP)
		row_root.size = Vector2(PANEL_SIZE.x, ROW_HEIGHT)
		row_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(row_root)

		var icon: Control = _make_icon(id)
		if icon != null:
			row_root.add_child(icon)
		var name_label: Label = _label(
			"", Vector2(ROW_NAME_X, ROW_TEXT_Y), Vector2(ROW_NAME_WIDTH, 16.0), 12, TEXT
		)
		name_label.name = "RowName_%s" % id
		row_root.add_child(name_label)
		_row_name_labels.append(name_label)
		var summary_label: Label = _label(
			"", Vector2(ROW_SUMMARY_X, ROW_TEXT_Y), Vector2(ROW_SUMMARY_WIDTH, 16.0), 12, MUTED
		)
		summary_label.name = "RowSummary_%s" % id
		# Clip + ellipsis: an over-wide line can never reach the key column.
		summary_label.clip_text = true
		summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row_root.add_child(summary_label)
		_row_summary_labels.append(summary_label)
		var key_node: Control = _make_key(id)
		if key_node != null:
			row_root.add_child(key_node)
		_rows.append({
			"id": id,
			"root": row_root,
			"name_label": name_label,
			"summary_label": summary_label,
			"icon": icon,
			"key": key_node,
		})
		index += 1

	var footer_divider: ColorRect = ColorRect.new()
	footer_divider.position = Vector2(16.0, FOOTER_DIVIDER_Y)
	footer_divider.size = Vector2(588.0, 1.0)
	footer_divider.color = Color(0.45, 0.66, 0.63, 0.28)
	footer_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(footer_divider)

	_footer = _rich_label(
		Vector2(16.0, FOOTER_Y), Vector2(420.0, FOOTER_HEIGHT), 12, DIM
	)
	_footer.name = "ManualFooter"
	_footer.text = KeyGlyph.decorate("{ESC} 关闭 · {F} / → 下一页 · ← 上一页")
	_panel.add_child(_footer)

	_page_indicator = _label(
		"1 / 1", Vector2(480.0, FOOTER_Y), Vector2(120.0, FOOTER_HEIGHT), 12, MUTED
	)
	_page_indicator.name = "ManualPageIndicator"
	_page_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_page_indicator)
	_apply_page_layout()


func _apply_row(row: Dictionary) -> void:
	var id: String = String(row.get("id", ""))
	var unlocked: bool = _unlocked.has(id)
	var name_label: Label = row.get("name_label", null) as Label
	var summary_label: Label = row.get("summary_label", null) as Label
	var icon: Control = row.get("icon", null) as Control
	var key_node: Control = row.get("key", null) as Control
	if name_label == null or summary_label == null:
		return
	if unlocked:
		name_label.text = REGISTRY.display_name(id)
		name_label.add_theme_color_override("font_color", TEXT)
		summary_label.text = fit_text(
			REGISTRY.get_summary(id), _font, ROW_SUMMARY_WIDTH, 12
		)
		summary_label.add_theme_color_override("font_color", MUTED)
		if icon != null:
			icon.visible = true
			icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if key_node != null:
			key_node.visible = true
			key_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		name_label.text = "？？？"
		name_label.add_theme_color_override("font_color", DIM)
		summary_label.text = ""
		summary_label.add_theme_color_override("font_color", DIM)
		if icon != null:
			icon.visible = false
		if key_node != null:
			key_node.visible = false


## Shows only the rows of `_page_index`, each at its own slot inside the page.
func _apply_page_layout() -> void:
	for index: int in range(_rows.size()):
		var row: Dictionary = _rows[index]
		var row_root: Control = row.get("root", null) as Control
		if row_root == null:
			continue
		var in_page: bool = int(index / ROWS_PER_PAGE) == _page_index
		row_root.visible = in_page
		if in_page:
			row_root.position = Vector2(
				0.0, ROW_START_Y + float(index % ROWS_PER_PAGE) * ROW_STEP
			)
	if _page_indicator != null:
		_page_indicator.text = "%d / %d" % [_page_index + 1, get_page_count()]


func _make_icon(id: String) -> Control:
	var icon_data: Dictionary = REGISTRY.get_icon(id)
	if String(icon_data.get("kind", "")) != "texture":
		return null
	var path: String = String(icon_data.get("value", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return _make_texture(
		path, Vector2(ROW_ICON_X, ROW_ICON_Y), Vector2(ICON_SIZE, ICON_SIZE)
	)


func _make_key(id: String) -> Control:
	var key_text: String = REGISTRY.get_key_text(id)
	if key_text.is_empty():
		var dash: Label = _label(
			"—", Vector2(ROW_KEY_X, ROW_TEXT_Y), Vector2(60.0, 16.0), 12, DIM
		)
		return dash
	if key_text == "SPACE":
		return _make_keycap("SPACE", ROW_KEY_X, ROW_TEXT_Y)
	return _make_keycap(key_text, ROW_KEY_X, ROW_TEXT_Y)


func _make_keycap(key: String, x: float, y: float) -> Control:
	var data: Variant = KeyGlyph.KEYS.get(key, null)
	if not (data is Dictionary):
		return null
	var path: String = KEYCAP_DIR + String((data as Dictionary).get("file", ""))
	if not ResourceLoader.exists(path):
		return null
	var base_width: int = int((data as Dictionary).get("width", 18))
	var width: int = maxi(roundi(float(base_width) * 16.0 / 18.0), 1)
	return _make_texture(path, Vector2(x, y), Vector2(float(width), 16.0))


func _make_texture(path: String, position_value: Vector2, size_value: Vector2) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Without EXPAND_IGNORE_SIZE the Control is clamped to the source texture's
	# size (18 px keycaps, 12 px icons), so a requested 12/16 px box could be
	# overridden and reach into the next row.  The manual really draws the
	# requested 12/16 px box.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = position_value
	rect.size = size_value
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(
	text_value: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.006, 0.014, 0.018, 0.96))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _rich_label(
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.scroll_active = false
	label.fit_content = false
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _font != null:
		label.add_theme_font_override("normal_font", _font)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	return label
