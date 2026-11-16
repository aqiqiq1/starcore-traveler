class_name Level02HUD
extends CanvasLayer

## Compact player-facing HUD for the level-02 greybox.
##
## This is deliberately not PrototypeHUD: the second-level prototype should
## show short Chinese stage feedback, not the English F4 debug readouts. It owns
## only presentation state; all gameplay state remains in Level02/the shared
## star-core room.

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
var _phase_label: Label
var _core_label: Label
var _prompt_panel: Panel
var _prompt_label: Label
var _prompt_text: String = ""
var _toast: Label
var _toast_panel: Panel
var _toast_time: float = 0.0
## Compatibility storage only; the old bottom permanent hint is intentionally
## no longer rendered. Recovery/R feedback uses short event toasts.
var _recovery_text: String = ""
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
	_root.name = "Level02HUDRoot"
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_header()
	_build_status()
	_build_prompt()
	_build_toast()
	_build_completion()
	set_polarity(true)
	set_status("任务：释放星核", "星核：起始仓", "")
	set_pause_visible(false)
	show_completion(false)


func _process(delta: float) -> void:
	if _toast_time <= 0.0:
		return
	_toast_time = maxf(_toast_time - delta, 0.0)
	if _toast_time <= 0.0:
		_toast_panel.visible = false
		_toast.visible = false
		_show_prompt_if_available()


func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		push_warning("Level02HUD: %s is missing; falling back" % FONT_PATH)
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
	_header.configure("沉寂回廊", "第二关 · 石栅通路", _font)
	_header.set_polarity(true)


func _build_status() -> void:
	# Two lines only: current objective and star-core state. The single action
	# prompt lives in the one shared panel below; no duplicate E/read/restart
	# stack on screen.
	var panel: Panel = _panel(Vector2(8.0, 54.0), Vector2(330.0, 44.0), Color(PANEL_BORDER, 0.7))
	_phase_label = _label("任务：释放星核", Vector2(15.0, 57.0), Vector2(316.0, 18.0), 12, GOLD)
	_root.add_child(_phase_label)
	_core_label = _label("星核：起始仓", Vector2(15.0, 77.0), Vector2(316.0, 16.0), 12, MUTED)
	_root.add_child(_core_label)
	panel.size = Vector2(330.0, 44.0)


func _build_prompt() -> void:
	# One shared slot for the main action prompt and short toasts. They are never
	# visible at the same time.
	_prompt_panel = _panel(Vector2(160.0, 104.0), Vector2(320.0, 26.0), Color(GOLD, 0.5))
	_prompt_label = _label("", Vector2(166.0, 107.0), Vector2(308.0, 18.0), 12, GOLD)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt_label)
	_prompt_text = ""
	_prompt_panel.visible = false
	_prompt_label.visible = false


func _build_toast() -> void:
	_toast_panel = _panel(Vector2(160.0, 104.0), Vector2(320.0, 26.0), Color(GOLD, 0.55))
	_toast_panel.visible = false
	_toast = _label("", Vector2(166.0, 107.0), Vector2(308.0, 18.0), 12, GOLD)
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
	panel.position = Vector2(120.0, 80.0)
	panel.size = Vector2(400.0, 200.0)
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

	var title: Label = _label("第二关完成", Vector2(0.0, 12.0), Vector2(400.0, 34.0), 24, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	_completion_title = title
	var subtitle: Label = _label("沉寂回廊 · 星核已归位", Vector2(0.0, 50.0), Vector2(400.0, 18.0), 12, TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)
	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(70.0, 74.0)
	divider.size = Vector2(260.0, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.5)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	_completion_primary = _menu_button("进入第三关", Vector2(110.0, 86.0), Vector2(180.0, 28.0), PixelMenuButton.Variant.STONE)
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
	var hint: Label = _label("Enter 进入第三关 · R 重玩 · Esc 暂停",
		Vector2(0.0, 178.0), Vector2(400.0, 16.0), 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

	# Same approved three-button focus loop as level 01: primary first, the two
	# secondary commands share the second row.
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


func set_status(phase: String, core_text: String, prompt: String) -> void:
	if _phase_label != null:
		_phase_label.text = phase
	if _core_label != null:
		_core_label.text = core_text
	if _prompt_label != null:
		_prompt_text = prompt
		_prompt_label.text = prompt
	# A transient toast owns the shared slot until it expires; replacing the
	# objective must not stack a second same-meaning line underneath it.
	if _toast_time <= 0.0:
		_show_prompt_if_available()


func show_toast(text_value: String, duration: float = 1.6) -> void:
	if _toast == null:
		return
	if text_value.is_empty():
		_toast_time = 0.0
		_toast_panel.visible = false
		_toast.visible = false
		_show_prompt_if_available()
		return
	_toast.text = text_value
	_toast_time = maxf(duration, 0.1)
	_prompt_panel.visible = false
	_prompt_label.visible = false
	_toast_panel.visible = true
	_toast.visible = true


func _show_prompt_if_available() -> void:
	if _prompt_panel == null or _prompt_label == null:
		return
	var available: bool = (
		not _prompt_text.is_empty()
		and _toast_time <= 0.0
		and not _completion_active
	)
	_prompt_panel.visible = available
	_prompt_label.visible = available


func set_pause_visible(value: bool) -> void:
	_pause_visible = value


func set_recovery_hint(text_value: String) -> void:
	# Kept as a compatibility data sink; no persistent bottom label exists.
	_recovery_text = text_value


func get_recovery_hint_text() -> String:
	return _recovery_text


func show_completion(value: bool, completion_count: int = 0) -> void:
	if _completion_overlay == null:
		return
	_completion_overlay.visible = value
	_completion_active = value
	if value:
		_toast_time = 0.0
		_toast_panel.visible = false
		_toast.visible = false
		_prompt_panel.visible = false
		_prompt_label.visible = false
		call_deferred("focus_completion_primary")
	else:
		release_completion_focus()
		_show_prompt_if_available()
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


func get_phase_text() -> String:
	return _phase_label.text if _phase_label != null else ""


func get_core_text() -> String:
	return _core_label.text if _core_label != null else ""


func get_prompt_text() -> String:
	return _prompt_label.text if _prompt_label != null else ""


func is_prompt_visible() -> bool:
	return _prompt_panel != null and _prompt_panel.visible


func get_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for node: Node in _root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


func get_toast_text() -> String:
	return _toast.text if _toast != null else ""


func is_toast_visible() -> bool:
	return _toast_panel != null and _toast_panel.visible


func is_pause_visible() -> bool:
	return _pause_visible


func is_completion_visible() -> bool:
	return _completion_overlay != null and _completion_overlay.visible


func get_completion_text() -> String:
	return _completion_title.text if _completion_title != null else ""


func get_controls_text() -> String:
	return (
		"A/D 移动   左Shift 奔跑   空格 跳跃   Q 切换相性   "
		+ "J 挥击   E 释放/入仓   F 阅读   R 重来   Esc 暂停"
	)
