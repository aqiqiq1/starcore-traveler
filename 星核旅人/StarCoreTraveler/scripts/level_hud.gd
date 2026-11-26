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
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

var _root: Control
var _header: CompactLevelHeader
var _objective: Label
var _objective_base: String = "前往庭院出口"
var _event_text: String = ""
var _event_left: float = 0.0
var _opening_active: bool = false
var _pending_event_text: String = ""
var _pending_event_left: float = 0.0
var _completion_overlay: ColorRect
var _completion_panel: Panel
var _completion_panel_base: Vector2 = Vector2.ZERO
var _completion_tween: Tween
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
	_build_objective()
	_build_completion()
	set_polarity(true)
	set_pause_visible(false)
	show_completion(false)


func _process(delta: float) -> void:
	if _event_left <= 0.0:
		return
	_event_left = maxf(_event_left - delta, 0.0)
	if _event_left <= 0.0:
		_event_text = ""
		if _objective != null and not _opening_active and not _completion_active:
			_objective.text = _objective_base


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


func _build_header() -> void:
	_header = CompactLevelHeader.new()
	_header.name = "CompactHeader"
	_root.add_child(_header)
	_header.configure("断桥庭院", "第一关", _font)
	_header.set_polarity(true)


func _build_objective() -> void:
	# One single objective/event line, same baseline as level 03: 12 px gold at
	# (15, 58), no panel, no second row. Short events replace it and restore.
	_objective = _label(_objective_base, Vector2(15.0, 58.0), Vector2(430.0, 18.0), 12, GOLD)
	_root.add_child(_objective)


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
	_completion_panel = panel
	_completion_panel_base = panel.position

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


func set_objective(text_value: String) -> void:
	_objective_base = text_value
	if _objective != null and _event_left <= 0.0 and not _opening_active and not _completion_active:
		_objective.text = text_value


## Opening-film state: the objective/event slot is hidden from the first bar
## frame until control is actually handed back. A restart event raised during
## the film is held and shown once the slot returns.
func set_opening_active(value: bool) -> void:
	_opening_active = value
	# The 44 px bar is 0.96-opaque, so the compact header would otherwise show
	# as a ghost through it. Hide the whole header (title/chapter/affinity) for
	# the film, and restore it only on the real hand-off/abort.
	if _header != null:
		_header.visible = not value
	if value:
		if _event_left > 0.0 and not _event_text.is_empty():
			_pending_event_text = _event_text
			_pending_event_left = _event_left
		_event_left = 0.0
		_event_text = ""
		if _objective != null:
			_objective.visible = false
		return
	if _objective != null:
		_objective.visible = not _completion_active
	if not _completion_active:
		_restore_objective_after_opening()


func _restore_objective_after_opening() -> void:
	if _objective == null:
		return
	if not _pending_event_text.is_empty():
		var pending_text: String = _pending_event_text
		var pending_left: float = maxf(_pending_event_left, 0.2)
		_pending_event_text = ""
		_pending_event_left = 0.0
		_start_event(pending_text, pending_left)
		return
	_objective.text = _objective_base


func show_toast(text_value: String, duration: float = 1.6) -> void:
	if _objective == null:
		return
	if text_value.is_empty():
		_event_left = 0.0
		_event_text = ""
		_pending_event_text = ""
		_pending_event_left = 0.0
		if not _opening_active and not _completion_active:
			_objective.text = _objective_base
		return
	var event_duration: float = clampf(duration, 0.2, 2.6)
	if _opening_active:
		_pending_event_text = text_value
		_pending_event_left = event_duration
		return
	_start_event(text_value, event_duration)


func _start_event(text_value: String, duration: float) -> void:
	_event_text = text_value
	_event_left = maxf(duration, 0.2)
	if _objective != null:
		_objective.visible = not _completion_active
		_objective.text = text_value


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
	if _header != null:
		_header.visible = not value
	if value:
		_play_completion_reveal()
		_event_left = 0.0
		_event_text = ""
		_pending_event_text = ""
		_pending_event_left = 0.0
		if _objective != null:
			_objective.visible = false
		call_deferred("focus_completion_primary")
	else:
		release_completion_focus()
		if _objective != null:
			_objective.visible = not _opening_active
			_objective.text = _objective_base
	if not value:
		_stop_completion_reveal()
	if _completion_count_label != null:
		_completion_count_label.text = "本关结算 · Esc 可打开暂停菜单" if value else ""


## The page shows on the same frame it is requested; only its alpha and 0.96
## scale/slide animate, so buttons and focus never wait on the tween.
func _play_completion_reveal() -> void:
	if _completion_tween != null and _completion_tween.is_valid():
		_completion_tween.kill()
	_completion_tween = UiReveal.play_overlay_open(
		self, _completion_overlay, _completion_panel, _completion_panel_base
	)


func _stop_completion_reveal() -> void:
	if _completion_tween != null and _completion_tween.is_valid():
		_completion_tween.kill()
	_completion_tween = null
	UiReveal.snap_overlay(_completion_overlay, _completion_panel, _completion_panel_base)


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


## Test/audit hook for the completion reveal; no gameplay effect.
func get_completion_reveal_alpha() -> float:
	return _completion_overlay.modulate.a if _completion_overlay != null else 0.0


func has_controls_bar() -> bool:
	return false


func get_polarity_text() -> String:
	return _header.get_affinity_text() if _header != null else ""


func get_toast_text() -> String:
	return _event_text


func get_objective_text() -> String:
	return _objective.text if _objective != null else ""


func is_objective_visible() -> bool:
	return _objective != null and _objective.visible


func get_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for node: Node in _root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


func is_toast_visible() -> bool:
	return _event_left > 0.0 and _objective != null and _objective.visible


func is_pause_visible() -> bool:
	return _pause_visible


func is_completion_visible() -> bool:
	return _completion_overlay != null and _completion_overlay.visible


func get_completion_text() -> String:
	return _completion_title.text if _completion_title != null else ""


## The old permanent bottom controls legend is gone; pause shows the bindings.
func get_controls_text() -> String:
	return "移动、奔跑、跳跃与换相都在暂停页。"
