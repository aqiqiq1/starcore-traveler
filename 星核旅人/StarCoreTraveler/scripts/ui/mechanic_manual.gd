class_name MechanicManual
extends CanvasLayer

## Pause-page mechanism manual shared by the base three levels and DLC1-3.
##
## Content comes only from MechanicRegistry (name / summary / key / icon) plus
## the unlocked ids in MechanicTeach's progress file.  Locked rows read ？？？;
## unlocked rows read the registry copy.  The page never changes gameplay or
## pause state: it is an overlay above the already-paused pause page.
##
## Close routes: Esc, F, or the in-panel 返回 button.  Opening focus goes to the
## 返回 button so the same keyboard route always works.

signal opened
signal closed

const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")
const TEACH = preload("res://scripts/ui/mechanic_teach.gd")

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const PANEL_POSITION: Vector2 = Vector2(20.0, 8.0)
const PANEL_SIZE: Vector2 = Vector2(600.0, 344.0)
const ROW_START_Y: float = 58.0
const ROW_STEP: float = 18.0
const ROW_ICON_X: float = 12.0
const ROW_NAME_X: float = 32.0
const ROW_NAME_WIDTH: float = 78.0
const ROW_SUMMARY_X: float = 112.0
const ROW_SUMMARY_WIDTH: float = 400.0
const ROW_KEY_X: float = 520.0
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const KEYCAP_DIR: String = "res://assets/ui/keycaps/"
const SUN_PATH: String = "res://assets/ui/icons/affinity_sun_20.png"
const MOON_PATH: String = "res://assets/ui/icons/affinity_moon_20.png"
const HEART_PATH: String = "res://assets/ui/icons/heart_10.png"

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
var _font: Font = null
var _rows: Array[Dictionary] = []
var _row_name_labels: Array[Label] = []
var _row_summary_labels: Array[Label] = []
var _row_state: Dictionary = {}
var _open: bool = false
var _unlocked: Dictionary = {}


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
	if code == KEY_ESCAPE or code == KEY_F:
		close()
	# Every key belongs to the manual while it is open, so the pause/chapter
	# input handlers cannot resume, restart or act behind the page.
	get_viewport().set_input_as_handled()


# --- Public API ------------------------------------------------------------

func open() -> bool:
	if _open or _root == null:
		return false
	refresh()
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


# --- Build UI --------------------------------------------------------------

func _focus_back() -> void:
	if _open and _back_button != null:
		_back_button.grab_focus()


func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return ThemeDB.fallback_font
	var font_file: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if font_file == null:
		return ThemeDB.fallback_font
	var copy: FontFile = font_file.duplicate() as FontFile
	if copy != null:
		copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		copy.hinting = TextServer.HINTING_NONE
		copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		copy.allow_system_fallback = false
		return copy
	return font_file


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

	_title = _label("机制手册", Vector2(16.0, 8.0), Vector2(360.0, 28.0), 24, GOLD)
	_panel.add_child(_title)

	_subtitle = _label("", Vector2(16.0, 36.0), Vector2(430.0, 14.0), 12, MUTED)
	_panel.add_child(_subtitle)

	_back_button = PixelMenuButton.new()
	_back_button.name = "ManualBackButton"
	_back_button.text = "返回"
	_back_button.position = Vector2(492.0, 10.0)
	_back_button.size = Vector2(92.0, 22.0)
	_back_button.font = _font
	_back_button.font_size = 12
	_back_button.variant = PixelMenuButton.Variant.OPTION
	_back_button.pressed.connect(close)
	_panel.add_child(_back_button)

	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(16.0, 52.0)
	divider.size = Vector2(568.0, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.40)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(divider)

	var index: int = 0
	for id: String in REGISTRY.all_ids():
		var row_y: float = ROW_START_Y + float(index) * ROW_STEP
		var icon: Control = _make_icon(id, row_y)
		if icon != null:
			_panel.add_child(icon)
		var name_label: Label = _label("", Vector2(ROW_NAME_X, row_y), Vector2(ROW_NAME_WIDTH, 16.0), 12, TEXT)
		name_label.name = "RowName_%s" % id
		_panel.add_child(name_label)
		_row_name_labels.append(name_label)
		var summary_label: Label = _label(
			"", Vector2(ROW_SUMMARY_X, row_y), Vector2(ROW_SUMMARY_WIDTH, 16.0), 12, MUTED
		)
		summary_label.name = "RowSummary_%s" % id
		summary_label.clip_text = true
		_panel.add_child(summary_label)
		_row_summary_labels.append(summary_label)
		var key_node: Control = _make_key(id, row_y)
		if key_node != null:
			_panel.add_child(key_node)
		_rows.append({
			"id": id,
			"name_label": name_label,
			"summary_label": summary_label,
			"icon": icon,
			"key": key_node,
		})
		index += 1

	_footer = _rich_label(
		Vector2(16.0, 326.0), Vector2(460.0, 16.0), 12, DIM
	)
	_footer.name = "ManualFooter"
	_footer.text = KeyGlyph.decorate("{ESC} / {F} 关闭")
	_panel.add_child(_footer)


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
		summary_label.text = REGISTRY.get_summary(id)
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


func _make_icon(id: String, row_y: float) -> Control:
	var icon_data: Dictionary = REGISTRY.get_icon(id)
	var kind: String = String(icon_data.get("kind", ""))
	var value: String = String(icon_data.get("value", ""))
	if kind == "key":
		return _make_keycap(value, ROW_ICON_X, row_y + 1.0)
	if kind == "phase":
		var path: String = SUN_PATH if value != "moon" else MOON_PATH
		return _make_texture(path, Vector2(15.0, row_y + 4.0), Vector2(10.0, 10.0))
	if kind == "heart":
		return _make_texture(HEART_PATH, Vector2(15.0, row_y + 4.0), Vector2(10.0, 10.0))
	return null


func _make_key(id: String, row_y: float) -> Control:
	var key_text: String = REGISTRY.get_key_text(id)
	if key_text.is_empty():
		var dash: Label = _label("—", Vector2(ROW_KEY_X, row_y), Vector2(60.0, 16.0), 12, DIM)
		return dash
	if key_text == "SPACE":
		return _make_keycap("SPACE", ROW_KEY_X, row_y + 1.0)
	return _make_keycap(key_text, ROW_KEY_X, row_y + 1.0)


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
