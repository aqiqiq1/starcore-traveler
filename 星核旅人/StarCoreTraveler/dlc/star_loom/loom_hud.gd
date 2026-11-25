class_name LoomHUD
extends CanvasLayer

## Compact HUD for 星核织机.
##
## Same approved header as the other DLC chapters (title / one objective /
## current phase), plus one small boss-state row (stage, live nodes, core
## damage, accepted hits / 3), a one-line event ticker, the recovery cover, the
## completion page ("织机停转 · 用时 mm:ss") and the shared four-item DLC pause
## page.  Both pages follow dlc/UI_PARITY_SPEC.md sections 4 and 5: a 360x236
## pause page with 已暂停 / 星核织机 · 城内原型, and a 400x210 completion page
## with a world-line subtitle, 返回主界面 / 重玩本章 and the chapter-summary
## footnote.  Both pages use the shared UiReveal (0.18 s open / 0.12 s close),
## whose tween runs with TWEEN_PAUSE_PROCESS, so the pause page opens and closes
## while the tree itself is paused.  Every colour, the 12 px project font and
## the STONE / OPTION button faces are the existing project ones.

signal resume_requested
signal restart_requested
signal title_requested
signal quit_requested

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DIM: Color = Color("#728889")
const PANEL_BG: Color = Color(0.014, 0.032, 0.040, 0.97)
const PANEL_BORDER: Color = Color(0.45, 0.66, 0.63, 0.9)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const TITLE: String = "星核织机"
const DEFAULT_OBJECTIVE: String = "目标：向右进入织机厅"
const PAUSE_SUBTITLE: String = "星核织机 · 城内原型"
const PAUSE_NOTE: String = "返回主界面不保存本章进度"
const COMPLETION_SUBTITLE: String = "城内的经线松开，星核的梭子终于停下。"
const COMPLETION_NOTE: String = "本章结算 · Esc 可打开暂停菜单"
const COMPLETION_PANEL_POSITION: Vector2 = Vector2(120.0, 75.0)
const COMPLETION_PANEL_SIZE: Vector2 = Vector2(400.0, 210.0)
const PAUSE_PANEL_POSITION: Vector2 = Vector2(140.0, 56.0)
const PAUSE_PANEL_SIZE: Vector2 = Vector2(360.0, 236.0)

var _root: Control
var _header: CompactLevelHeader
var _stage_label: Label
var _node_label: Label
var _core_label: Label
var _hit_label: Label
var _event_label: Label
var _gear_edge: LoomEdgeWarning
var _event_left: float = 0.0
var _recovery_cover: ColorRect
var _completion_overlay: ColorRect
var _completion_panel: Panel
var _completion_title: Label
var _completion_subtitle: Label
var _completion_note: Label
var _completion_primary: PixelMenuButton
var _completion_secondary: PixelMenuButton
var _pause_overlay: ColorRect
var _pause_panel: Panel
var _pause_subtitle: Label
var _pause_note: Label
var _pause_continue: PixelMenuButton
var _pause_restart: PixelMenuButton
var _pause_title: PixelMenuButton
var _pause_quit: PixelMenuButton
var _font: Font
var _subtitle: String = ""
var _completion_visible: bool = false
var _pause_visible: bool = false
var _completion_reveal: UiReveal
var _pause_reveal: UiReveal


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_font = _load_font()
	_root = Control.new()
	_root.name = "LoomHUDRoot"
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_header()
	_build_status()
	_build_event()
	_build_gear_edge()
	_build_recovery_cover()
	_build_completion()
	_build_pause()
	_completion_reveal = UiReveal.new()
	_completion_reveal.setup(
		self, _completion_overlay, _completion_overlay, _completion_panel,
		COMPLETION_PANEL_POSITION
	)
	_pause_reveal = UiReveal.new()
	_pause_reveal.setup(
		self, _pause_overlay, _pause_overlay, _pause_panel, PAUSE_PANEL_POSITION
	)
	set_polarity(false)
	set_objective(DEFAULT_OBJECTIVE)
	set_boss_state(1, 3, 2, 0, 3, false, 0, 3)
	show_completion(false, 0.0)
	show_pause(false)


## Pause-page keyboard fallback.  The four buttons form a closed ring:
## 继续游戏 -> 重新开始本章 -> 返回主界面 -> 退出游戏 -> 继续游戏.
func _unhandled_input(event: InputEvent) -> void:
	if not _pause_visible or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)
	if code == int(KEY_ENTER) or code == int(KEY_KP_ENTER) or code == int(KEY_SPACE):
		var focused: Control = get_viewport().gui_get_focus_owner()
		get_viewport().set_input_as_handled()
		if focused == _pause_restart:
			restart_requested.emit()
		elif focused == _pause_title:
			title_requested.emit()
		elif focused == _pause_quit:
			quit_requested.emit()
		else:
			resume_requested.emit()
	elif code == int(KEY_DOWN) or code == int(KEY_TAB):
		_focus_pause_relative(1)
		get_viewport().set_input_as_handled()
	elif code == int(KEY_UP):
		_focus_pause_relative(-1)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _event_left <= 0.0:
		return
	_event_left = maxf(_event_left - delta, 0.0)
	if _event_left <= 0.0:
		_event_label.visible = false


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


func _label(
	text_value: String, position_value: Vector2, size_value: Vector2,
	font_size: int, color: Color
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


func _menu_button(
	text_value: String, position_value: Vector2, size_value: Vector2, variant: int
) -> PixelMenuButton:
	var button: PixelMenuButton = PixelMenuButton.new()
	button.text = text_value
	button.position = position_value
	button.size = size_value
	button.font = _font
	button.font_size = 12
	button.variant = variant
	return button


## Closed keyboard focus ring for a page's buttons.  Both the explicit
## next/previous links and the vertical neighbours are set, so Tab, the arrow
## keys and the HUD's own fallback all reach every item.
func _chain_focus(buttons: Array, vertical: bool) -> void:
	var count: int = buttons.size()
	if count == 0:
		return
	for index: int in range(count):
		var current: PixelMenuButton = buttons[index] as PixelMenuButton
		var next: PixelMenuButton = buttons[(index + 1) % count] as PixelMenuButton
		var previous: PixelMenuButton = buttons[(index - 1 + count) % count] as PixelMenuButton
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		if vertical:
			current.focus_neighbor_bottom = current.get_path_to(next)
			current.focus_neighbor_top = current.get_path_to(previous)


func _focus_pause_relative(step: int) -> void:
	var chain: Array[PixelMenuButton] = [
		_pause_continue, _pause_restart, _pause_title, _pause_quit,
	]
	var focused: Control = get_viewport().gui_get_focus_owner()
	var index: int = chain.find(focused as PixelMenuButton)
	if index < 0:
		chain[0 if step > 0 else chain.size() - 1].grab_focus()
		return
	index = (index + step + chain.size()) % chain.size()
	chain[index].grab_focus()


func _build_header() -> void:
	_header = CompactLevelHeader.new()
	_header.name = "CompactHeader"
	_root.add_child(_header)
	_header.configure(TITLE, DEFAULT_OBJECTIVE, _font)
	_header.set_polarity(false)


func _build_status() -> void:
	_stage_label = _label("阶段 1 / 3", Vector2(12.0, 40.0), Vector2(90.0, 14.0), 12, GOLD)
	_stage_label.name = "StageLabel"
	_root.add_child(_stage_label)

	_node_label = _label("节点 2 / 2", Vector2(108.0, 40.0), Vector2(96.0, 14.0), 12, CYAN)
	_node_label.name = "NodeLabel"
	_root.add_child(_node_label)

	_core_label = _label("核心 0 / 3", Vector2(214.0, 40.0), Vector2(110.0, 14.0), 12, MUTED)
	_core_label.name = "CoreLabel"
	_root.add_child(_core_label)

	_hit_label = _label("受击 0 / 3", Vector2(330.0, 40.0), Vector2(96.0, 14.0), 12, TEXT)
	_hit_label.name = "HitLabel"
	_root.add_child(_hit_label)


func _build_event() -> void:
	_event_label = _label("", Vector2(12.0, 56.0), Vector2(520.0, 16.0), 12, GOLD)
	_event_label.name = "EventLine"
	_event_label.visible = false
	_root.add_child(_event_label)


func _build_gear_edge() -> void:
	_gear_edge = LoomEdgeWarning.new()
	_root.add_child(_gear_edge)


func _build_recovery_cover() -> void:
	_recovery_cover = ColorRect.new()
	_recovery_cover.name = "RecoveryCover"
	_recovery_cover.position = Vector2.ZERO
	_recovery_cover.size = VIEW_SIZE
	_recovery_cover.color = Color(0.0, 0.0, 0.0, 0.0)
	_recovery_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recovery_cover.visible = false
	_root.add_child(_recovery_cover)


func _build_completion() -> void:
	_completion_overlay = ColorRect.new()
	_completion_overlay.name = "CompletionOverlay"
	_completion_overlay.position = Vector2.ZERO
	_completion_overlay.size = VIEW_SIZE
	_completion_overlay.color = Color(0.006, 0.014, 0.018, 0.66)
	_completion_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_completion_overlay.visible = false
	_root.add_child(_completion_overlay)

	var panel: Panel = Panel.new()
	panel.name = "CompletionPanel"
	panel.position = COMPLETION_PANEL_POSITION
	panel.size = COMPLETION_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = GOLD
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	_completion_overlay.add_child(panel)
	_completion_panel = panel

	_completion_title = _label(
		"织机停转 · 用时 00:00",
		Vector2(0.0, 12.0), Vector2(400.0, 34.0), 24, GOLD
	)
	_completion_title.name = "CompletionTitle"
	_completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_completion_title)

	_completion_subtitle = _label(
		COMPLETION_SUBTITLE, Vector2(0.0, 50.0), Vector2(400.0, 18.0), 12, TEXT
	)
	_completion_subtitle.name = "CompletionSubtitle"
	_completion_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_completion_subtitle)

	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(70.0, 74.0)
	divider.size = Vector2(260.0, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.5)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	_completion_primary = _menu_button(
		"返回主界面", Vector2(110.0, 86.0), Vector2(180.0, 28.0),
		PixelMenuButton.Variant.STONE
	)
	_completion_primary.name = "ReturnButton"
	_completion_primary.pressed.connect(func() -> void: title_requested.emit())
	panel.add_child(_completion_primary)

	_completion_secondary = _menu_button(
		"重玩本章", Vector2(110.0, 126.0), Vector2(180.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_completion_secondary.name = "ReplayButton"
	_completion_secondary.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(_completion_secondary)

	_completion_note = _label(
		COMPLETION_NOTE, Vector2(0.0, 158.0), Vector2(400.0, 16.0), 12, DIM
	)
	_completion_note.name = "CompletionNote"
	_completion_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_completion_note)

	_chain_focus(
		[_completion_primary, _completion_secondary], true
	)


func _build_pause() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.position = Vector2.ZERO
	_pause_overlay.size = VIEW_SIZE
	_pause_overlay.color = Color(0.006, 0.014, 0.018, 0.70)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.visible = false
	_root.add_child(_pause_overlay)

	var panel: Panel = Panel.new()
	panel.name = "PausePanel"
	panel.position = PAUSE_PANEL_POSITION
	panel.size = PAUSE_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(2)
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	_pause_overlay.add_child(panel)
	_pause_panel = panel

	var title: Label = _label("已暂停", Vector2(0.0, 8.0), Vector2(360.0, 30.0), 24, GOLD)
	title.name = "PauseTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	_pause_subtitle = _label(
		PAUSE_SUBTITLE, Vector2(0.0, 40.0), Vector2(360.0, 14.0), 12, MUTED
	)
	_pause_subtitle.name = "PauseSubtitle"
	_pause_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_pause_subtitle)

	_pause_continue = _menu_button(
		"继续游戏", Vector2(76.0, 56.0), Vector2(208.0, 24.0),
		PixelMenuButton.Variant.STONE
	)
	_pause_continue.name = "ContinueButton"
	_pause_continue.pressed.connect(func() -> void: resume_requested.emit())
	panel.add_child(_pause_continue)

	_pause_restart = _menu_button(
		"重新开始本章", Vector2(76.0, 90.0), Vector2(208.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_pause_restart.name = "RestartButton"
	_pause_restart.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(_pause_restart)

	_pause_title = _menu_button(
		"返回主界面", Vector2(76.0, 124.0), Vector2(208.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_pause_title.name = "TitleButton"
	_pause_title.pressed.connect(func() -> void: title_requested.emit())
	panel.add_child(_pause_title)

	_pause_quit = _menu_button(
		"退出游戏", Vector2(76.0, 158.0), Vector2(208.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_pause_quit.name = "QuitButton"
	_pause_quit.pressed.connect(func() -> void: quit_requested.emit())
	panel.add_child(_pause_quit)

	_pause_note = _label(
		PAUSE_NOTE, Vector2(0.0, 190.0), Vector2(360.0, 16.0), 12, DIM
	)
	_pause_note.name = "PauseNote"
	_pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_pause_note)

	_chain_focus(
		[_pause_continue, _pause_restart, _pause_title, _pause_quit], true
	)


# --- public state ----------------------------------------------------------

func set_polarity(positive: bool) -> void:
	if _header != null:
		_header.set_polarity(positive)


func set_objective(text_value: String) -> void:
	_subtitle = text_value
	if _header != null:
		_header.configure(TITLE, text_value, _font)


func set_boss_state(
	stage: int, stage_max: int, nodes_alive: int,
	core_hits: int, core_needed: int, exposed: bool,
	player_hits: int = 0, hit_limit: int = 3
) -> void:
	if _stage_label != null:
		_stage_label.text = "阶段 %d / %d" % [stage, stage_max]
	if _node_label != null:
		_node_label.text = "节点 %d / 2" % nodes_alive
		_node_label.add_theme_color_override(
			"font_color", CYAN if nodes_alive > 0 else MUTED
		)
	if _core_label != null:
		_core_label.text = (
			"核心 %d / %d" % [core_hits, core_needed]
			if exposed
			else "核心受护"
		)
		_core_label.add_theme_color_override(
			"font_color", GOLD if exposed else MUTED
		)
	if _hit_label != null:
		_hit_label.text = "受击 %d / %d" % [player_hits, hit_limit]
		var color: Color = TEXT
		if player_hits >= hit_limit - 1:
			color = GOLD
		_hit_label.add_theme_color_override("font_color", color)


func set_gear_warning(active: bool, progress: float = 0.0) -> void:
	if _gear_edge != null:
		_gear_edge.set_warning(active, progress)


func is_gear_warning_visible() -> bool:
	return _gear_edge != null and _gear_edge.is_active()


func show_event(text_value: String, seconds: float = 1.5) -> void:
	if _event_label == null:
		return
	_event_label.text = text_value
	_event_label.visible = true
	_event_left = maxf(seconds, 0.1)


func set_recovery_alpha(value: float) -> void:
	if _recovery_cover == null:
		return
	var alpha: float = clampf(value, 0.0, 1.0)
	_recovery_cover.visible = alpha > 0.0
	_recovery_cover.color = Color(0.0, 0.0, 0.0, alpha)


func show_completion(value: bool, elapsed_seconds: float = 0.0) -> void:
	_completion_visible = value
	if _completion_overlay == null:
		return
	_completion_title.text = "织机停转 · 用时 %s" % _format_time(elapsed_seconds)
	if value:
		if _completion_reveal != null:
			_completion_reveal.play_open()
		else:
			_completion_overlay.visible = true
		call_deferred("_focus_completion")
	else:
		if _completion_reveal != null:
			_completion_reveal.snap_closed()
		else:
			_completion_overlay.visible = false
		if _completion_primary != null:
			_completion_primary.release_focus()
		if _completion_secondary != null:
			_completion_secondary.release_focus()


func show_pause(value: bool) -> void:
	var was_visible: bool = _pause_visible
	_pause_visible = value
	if _pause_overlay == null:
		return
	if value:
		if _pause_reveal != null:
			_pause_reveal.play_open()
		else:
			_pause_overlay.visible = true
		call_deferred("_focus_pause")
	else:
		if _pause_reveal != null:
			if was_visible:
				_pause_reveal.play_close()
			else:
				_pause_reveal.snap_closed()
		else:
			_pause_overlay.visible = false
		for button: PixelMenuButton in [
			_pause_continue, _pause_restart, _pause_title, _pause_quit,
		]:
			if button != null:
				button.release_focus()
		if _completion_visible:
			call_deferred("_focus_completion")


func _focus_pause() -> void:
	if _pause_visible and _pause_continue != null:
		_pause_continue.grab_focus()


func _focus_completion() -> void:
	if _completion_visible and _completion_primary != null:
		_completion_primary.grab_focus()


func _format_time(seconds: float) -> String:
	var total: int = maxi(int(floor(seconds)), 0)
	return "%02d:%02d" % [total / 60, total % 60]


# --- test / capture accessors ---------------------------------------------

func get_header() -> CompactLevelHeader:
	return _header


func get_title_text() -> String:
	return _header.get_title_text() if _header != null else TITLE


func get_objective_text() -> String:
	return _header.get_subtitle_text() if _header != null else _subtitle


func get_affinity_text() -> String:
	return _header.get_affinity_text() if _header != null else ""


func get_stage_text() -> String:
	return _stage_label.text if _stage_label != null else ""


func get_node_text() -> String:
	return _node_label.text if _node_label != null else ""


func get_core_text() -> String:
	return _core_label.text if _core_label != null else ""


func get_hit_text() -> String:
	return _hit_label.text if _hit_label != null else ""


func get_pause_panel_alpha() -> float:
	return _pause_reveal.get_shade_alpha() if _pause_reveal != null else 0.0


func get_pause_panel_offset() -> float:
	if _pause_reveal == null:
		return 0.0
	return _pause_reveal.get_panel_offset_y()


func get_pause_panel_rect() -> Rect2:
	return Rect2(PAUSE_PANEL_POSITION, PAUSE_PANEL_SIZE)


func get_pause_subtitle_text() -> String:
	return _pause_subtitle.text if _pause_subtitle != null else ""


func get_pause_note_text() -> String:
	return _pause_note.text if _pause_note != null else ""


func get_completion_panel_alpha() -> float:
	return _completion_reveal.get_shade_alpha() if _completion_reveal != null else 0.0


func get_completion_panel_offset() -> float:
	if _completion_reveal == null:
		return 0.0
	return _completion_reveal.get_panel_offset_y()


func is_completion_visible() -> bool:
	return _completion_visible


func get_completion_text() -> String:
	return _completion_title.text if _completion_title != null else ""


func get_completion_panel_rect() -> Rect2:
	return Rect2(COMPLETION_PANEL_POSITION, COMPLETION_PANEL_SIZE)


func get_completion_subtitle_text() -> String:
	return _completion_subtitle.text if _completion_subtitle != null else ""


func get_completion_note_text() -> String:
	return _completion_note.text if _completion_note != null else ""


func get_completion_primary_button() -> PixelMenuButton:
	return _completion_primary


func get_completion_secondary_button() -> PixelMenuButton:
	return _completion_secondary


func is_completion_button_focused() -> bool:
	if not _completion_visible:
		return false
	var focused: Control = get_viewport().gui_get_focus_owner()
	return focused != null and (focused == _completion_primary or focused == _completion_secondary)


func is_pause_visible() -> bool:
	return _pause_visible


func get_continue_button() -> PixelMenuButton:
	return _pause_continue


func get_restart_button() -> PixelMenuButton:
	return _pause_restart


func get_title_button() -> PixelMenuButton:
	return _pause_title


func get_quit_button() -> PixelMenuButton:
	return _pause_quit


func get_recovery_cover() -> ColorRect:
	return _recovery_cover


func get_completion_title_label() -> Label:
	return _completion_title


func get_event_text() -> String:
	return _event_label.text if _event_label != null else ""


func is_event_visible() -> bool:
	return _event_label != null and _event_label.visible
