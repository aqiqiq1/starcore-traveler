class_name Level01HUD
extends CanvasLayer

## Formal level HUD. Unlike PrototypeHUD this is player-facing Chinese text:
## 辉相 / 澜相, no numeric polarity, no debug readouts. It owns pause and
## first-level completion panels but no gameplay state.

signal next_level_requested
signal replay_requested
signal return_to_menu_requested

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DIM: Color = Color("#728889")
const PANEL_BG: Color = Color(0.012, 0.028, 0.035, 0.82)
const PANEL_BORDER: Color = Color(0.33, 0.52, 0.51, 0.55)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

var _root: Control
var _header: CompactLevelHeader
var _toast: Label
var _toast_panel: Panel
var _toast_time: float = 0.0
var _completion_overlay: ColorRect
var _completion_title: Label
var _completion_count_label: Label
var _completion_primary: PixelMenuButton
var _completion_replay: PixelMenuButton
var _completion_return: PixelMenuButton
var _completion_active: bool = false
var _pause_visible: bool = false
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_font = _load_font()
	_root = Control.new()
	_root.name = "LevelHUDRoot"
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_header()
	_build_toast()
	_build_completion()
	set_polarity(true)
	set_pause_visible(false)
	show_completion(false)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time = maxf(_toast_time - delta, 0.0)
		if _toast_time <= 0.0:
			_toast_panel.visible = false
			_toast.visible = false


func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		push_warning("Level01HUD: %s is missing; falling back" % FONT_PATH)
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
	label.add_theme_constant_override("outline_size", 2)
	return label


func _panel(position_value: Vector2, size_value: Vector2, border_color: Color) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = position_value
	panel.size = size_value
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.set_corner_radius_all(2)
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	return panel


func _build_header() -> void:
	_header = CompactLevelHeader.new()
	_header.name = "CompactHeader"
	_root.add_child(_header)
	_header.configure("断桥庭院", "第一关", _font)
	_header.set_polarity(true)


func _build_toast() -> void:
	_toast_panel = _panel(Vector2(160.0, 64.0), Vector2(320.0, 26.0), Color(GOLD, 0.55))
	_toast_panel.visible = false
	_toast = _label("", Vector2(166.0, 67.0), Vector2(308.0, 18.0), 12, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_toast)


func _build_completion() -> void:
	_completion_overlay = ColorRect.new()
	_completion_overlay.position = Vector2.ZERO
	_completion_overlay.size = VIEW_SIZE
	_completion_overlay.color = Color(0.006, 0.014, 0.018, 0.66)
	_completion_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_completion_overlay.visible = false
	_root.add_child(_completion_overlay)

	var panel: Panel = Panel.new()
	panel.position = Vector2(120.0, 75.0)
	panel.size = Vector2(400.0, 210.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.032, 0.040, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.95, 0.80, 0.39, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	_completion_overlay.add_child(panel)

	var title: Label = _label("第一关完成", Vector2(0.0, 12.0), Vector2(400.0, 34.0), 24, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	_completion_title = title
	var subtitle: Label = _label("断桥庭院 · 你抵达了出口", Vector2(0.0, 50.0), Vector2(400.0, 18.0), 12, TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)
	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(70.0, 74.0)
	divider.size = Vector2(260.0, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.5)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	_completion_primary = _menu_button("进入第二关", Vector2(110.0, 86.0), Vector2(180.0, 28.0), PixelMenuButton.Variant.STONE)
	_completion_primary.pressed.connect(func() -> void: next_level_requested.emit())
	panel.add_child(_completion_primary)

	_completion_replay = _menu_button("重玩本关", Vector2(32.0, 126.0), Vector2(160.0, 24.0), PixelMenuButton.Variant.OPTION)
	_completion_replay.pressed.connect(func() -> void: replay_requested.emit())
	panel.add_child(_completion_replay)

	_completion_return = _menu_button("返回主界面", Vector2(208.0, 126.0), Vector2(160.0, 24.0), PixelMenuButton.Variant.OPTION)
	_completion_return.pressed.connect(func() -> void: return_to_menu_requested.emit())
	panel.add_child(_completion_return)

	_completion_count_label = _label("", Vector2(0.0, 158.0), Vector2(400.0, 16.0), 12, DIM)
	_completion_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_completion_count_label)
	var hint: Label = _label("Enter 进入第二关 · R 重玩 · Esc 暂停",
		Vector2(0.0, 178.0), Vector2(400.0, 16.0), 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

	_completion_primary.focus_next = _completion_primary.get_path_to(_completion_replay)
	_completion_primary.focus_previous = _completion_primary.get_path_to(_completion_return)
	_completion_primary.focus_neighbor_bottom = _completion_primary.get_path_to(_completion_replay)
	_completion_primary.focus_neighbor_top = _completion_primary.get_path_to(_completion_return)
	_completion_replay.focus_next = _completion_replay.get_path_to(_completion_return)
	_completion_replay.focus_previous = _completion_replay.get_path_to(_completion_primary)
	_completion_replay.focus_neighbor_top = _completion_replay.get_path_to(_completion_primary)
	_completion_replay.focus_neighbor_bottom = _completion_replay.get_path_to(_completion_return)
	_completion_return.focus_next = _completion_return.get_path_to(_completion_primary)
	_completion_return.focus_previous = _completion_return.get_path_to(_completion_replay)
	_completion_return.focus_neighbor_top = _completion_return.get_path_to(_completion_replay)
	_completion_return.focus_neighbor_bottom = _completion_return.get_path_to(_completion_primary)


func _menu_button(
	text_value: String,
	position_value: Vector2,
	size_value: Vector2,
	variant: int
) -> PixelMenuButton:
	var button: PixelMenuButton = PixelMenuButton.new()
	button.text = text_value
	button.position = position_value
	button.size = size_value
	button.font = _font
	button.font_size = 12
	button.variant = variant
	return button


func set_polarity(positive: bool) -> void:
	if _header == null:
		return
	_header.set_polarity(positive)


func get_compact_header() -> CompactLevelHeader:
	return _header


func show_toast(text_value: String, duration: float = 1.6) -> void:
	if _toast == null:
		return
	if text_value.is_empty():
		_toast_time = 0.0
		_toast_panel.visible = false
		_toast.visible = false
		return
	_toast.text = text_value
	_toast_time = maxf(duration, 0.1)
	_toast_panel.visible = true
	_toast.visible = true


func set_pause_visible(value: bool) -> void:
	# The real pause page is owned by PauseMenu; the HUD keeps only the state
	# flag for compatibility with gameplay tests.  No permanent controls strip
	# or duplicate pause panel is drawn here any more.
	_pause_visible = value


func show_completion(value: bool, completion_count: int = 0) -> void:
	if _completion_overlay == null:
		return
	_completion_overlay.visible = value
	_completion_active = value
	if value:
		_toast_time = 0.0
		_toast_panel.visible = false
		_toast.visible = false
		call_deferred("focus_completion_primary")
	else:
		release_completion_focus()
	if _completion_count_label != null:
		_completion_count_label.text = "本关结算 · Esc 可打开暂停菜单" if value else ""


func focus_completion_primary() -> void:
	if _completion_active and _completion_primary != null and not _completion_primary.disabled:
		_completion_primary.grab_focus()


func release_completion_focus() -> void:
	if _completion_primary != null:
		_completion_primary.release_focus()
	if _completion_replay != null:
		_completion_replay.release_focus()
	if _completion_return != null:
		_completion_return.release_focus()


func set_completion_buttons_enabled(value: bool) -> void:
	for button: PixelMenuButton in [_completion_primary, _completion_replay, _completion_return]:
		if button != null:
			button.disabled = not value


func get_completion_primary_button() -> PixelMenuButton:
	return _completion_primary


func get_completion_replay_button() -> PixelMenuButton:
	return _completion_replay


func get_completion_return_button() -> PixelMenuButton:
	return _completion_return


func is_completion_active() -> bool:
	return _completion_active


func has_controls_bar() -> bool:
	return false


func get_polarity_text() -> String:
	return _header.get_affinity_text() if _header != null else ""


func get_toast_text() -> String:
	return _toast.text if _toast != null else ""


func get_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for node: Node in _root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


func is_toast_visible() -> bool:
	return _toast_panel != null and _toast_panel.visible


func is_pause_visible() -> bool:
	return _pause_visible


func is_completion_visible() -> bool:
	return _completion_overlay != null and _completion_overlay.visible


func get_completion_text() -> String:
	return _completion_title.text if _completion_title != null else ""


func get_controls_text() -> String:
	return "A/D 移动   左Shift 奔跑   空格 跳跃   Q 切换   F 交谈   R 重来   Esc 暂停"
