class_name LoomHUD
extends CanvasLayer

## Compact HUD for 星核织机.
##
## Same approved header as the other DLC chapters (title / one objective /
## current phase), plus one small boss-state row (stage, live nodes, core
## damage, accepted hits / 3), a one-line event ticker, the recovery cover, the
## completion page ("织机停转 · 用时 mm:ss") and a two-item pause page.
## The pause and completion panels fade and slide in over 0.16 s.  The pause
## animation runs in _process on this ALWAYS node, so it is safe while the tree
## itself is paused.  Every colour, the 12 px project font and the 112x20 STONE
## buttons are the existing project ones.

signal resume_requested
signal title_requested

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const PANEL_BG: Color = Color(0.014, 0.032, 0.040, 0.97)
const PANEL_BORDER: Color = Color(0.45, 0.66, 0.63, 0.9)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const TITLE: String = "星核织机"
const DEFAULT_OBJECTIVE: String = "目标：向右进入织机厅"
const COMPLETION_PANEL_POSITION: Vector2 = Vector2(140.0, 108.0)
const PAUSE_PANEL_POSITION: Vector2 = Vector2(196.0, 116.0)
const PANEL_ANIM_TIME: float = 0.16
const PANEL_SLIDE: float = 8.0

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
var _completion_hint: Label
var _pause_overlay: ColorRect
var _pause_panel: Panel
var _pause_continue: PixelMenuButton
var _pause_title: PixelMenuButton
var _font: Font
var _subtitle: String = ""
var _completion_visible: bool = false
var _pause_visible: bool = false
var _completion_alpha: float = 0.0
var _completion_target: float = 0.0
var _pause_alpha: float = 0.0
var _pause_target: float = 0.0


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
	set_polarity(false)
	set_objective(DEFAULT_OBJECTIVE)
	set_boss_state(1, 3, 2, 0, 3, false, 0, 3)
	show_completion(false, 0.0)
	show_pause(false)


## Pause-page keyboard fallback (same behaviour as the other DLC chapters).
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
		if focused == _pause_title:
			title_requested.emit()
		else:
			resume_requested.emit()
	elif code == int(KEY_DOWN) or code == int(KEY_TAB):
		_pause_title.grab_focus()
		get_viewport().set_input_as_handled()
	elif code == int(KEY_UP):
		_pause_continue.grab_focus()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Panel fades must also run while the tree is paused (the pause page).
	_animate_panels(delta)
	if get_tree().paused:
		return
	if _event_left <= 0.0:
		return
	_event_left = maxf(_event_left - delta, 0.0)
	if _event_left <= 0.0:
		_event_label.visible = false


func _animate_panels(delta: float) -> void:
	var step: float = delta / PANEL_ANIM_TIME
	_pause_alpha = move_toward(_pause_alpha, _pause_target, step)
	_completion_alpha = move_toward(_completion_alpha, _completion_target, step)
	_apply_panel_anim(
		_pause_panel, PAUSE_PANEL_POSITION, _pause_alpha, _pause_overlay, not _pause_visible
	)
	_apply_panel_anim(
		_completion_panel, COMPLETION_PANEL_POSITION, _completion_alpha,
		_completion_overlay, not _completion_visible
	)


func _apply_panel_anim(
	panel: Panel, base: Vector2, alpha: float, overlay: ColorRect, hide_when_done: bool
) -> void:
	if panel == null or overlay == null:
		return
	var eased: float = alpha * alpha * (3.0 - 2.0 * alpha)
	panel.modulate = Color(1.0, 1.0, 1.0, eased)
	panel.position = base + Vector2(0.0, (1.0 - eased) * PANEL_SLIDE)
	if hide_when_done and alpha <= 0.001:
		overlay.visible = false


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
	panel.position = COMPLETION_PANEL_POSITION + Vector2(0.0, PANEL_SLIDE)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.size = Vector2(360.0, 144.0)
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
		"织机停转 · 用时 00:00", Vector2(0.0, 28.0), Vector2(360.0, 24.0), 18, GOLD
	)
	_completion_title.name = "CompletionTitle"
	_completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_completion_title)

	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(60.0, 66.0)
	divider.size = Vector2(240.0, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.55)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	_completion_hint = _label(
		"E / Enter 返回标题", Vector2(0.0, 88.0), Vector2(360.0, 18.0), 12, TEXT
	)
	_completion_hint.name = "CompletionHint"
	_completion_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_completion_hint)


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
	panel.position = PAUSE_PANEL_POSITION + Vector2(0.0, PANEL_SLIDE)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.size = Vector2(248.0, 128.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	_pause_overlay.add_child(panel)
	_pause_panel = panel

	var title: Label = _label("已暂停", Vector2(0.0, 14.0), Vector2(248.0, 24.0), 18, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	_pause_continue = _menu_button(
		"继续", Vector2(40.0, 52.0), Vector2(168.0, 24.0), PixelMenuButton.Variant.STONE
	)
	_pause_continue.name = "ContinueButton"
	_pause_continue.pressed.connect(func() -> void: resume_requested.emit())
	panel.add_child(_pause_continue)

	_pause_title = _menu_button(
		"返回标题", Vector2(40.0, 84.0), Vector2(168.0, 24.0), PixelMenuButton.Variant.OPTION
	)
	_pause_title.name = "TitleButton"
	_pause_title.pressed.connect(func() -> void: title_requested.emit())
	panel.add_child(_pause_title)

	_pause_continue.focus_next = _pause_continue.get_path_to(_pause_title)
	_pause_continue.focus_previous = _pause_continue.get_path_to(_pause_title)
	_pause_title.focus_next = _pause_title.get_path_to(_pause_continue)
	_pause_title.focus_previous = _pause_title.get_path_to(_pause_continue)


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
		_completion_overlay.visible = true
		_completion_alpha = 0.0
		_completion_target = 1.0
		_completion_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_completion_panel.position = COMPLETION_PANEL_POSITION + Vector2(0.0, PANEL_SLIDE)
	else:
		_completion_target = 0.0
		if _completion_alpha <= 0.001:
			_completion_overlay.visible = false


func show_pause(value: bool) -> void:
	_pause_visible = value
	if _pause_overlay == null:
		return
	if value:
		_pause_overlay.visible = true
		_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_pause_alpha = 0.0
		_pause_target = 1.0
		_pause_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_pause_panel.position = PAUSE_PANEL_POSITION + Vector2(0.0, PANEL_SLIDE)
		call_deferred("_focus_pause")
	else:
		_pause_target = 0.0
		# Do not keep swallowing clicks while the panel fades out after resume.
		_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pause_continue.release_focus()
		_pause_title.release_focus()


func _focus_pause() -> void:
	if _pause_visible and _pause_continue != null:
		_pause_continue.grab_focus()


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
	return _pause_alpha


func get_pause_panel_offset() -> float:
	return _pause_panel.position.y - PAUSE_PANEL_POSITION.y if _pause_panel != null else 0.0


func get_completion_panel_alpha() -> float:
	return _completion_alpha


func get_completion_panel_offset() -> float:
	if _completion_panel == null:
		return 0.0
	return _completion_panel.position.y - COMPLETION_PANEL_POSITION.y


func is_completion_visible() -> bool:
	return _completion_visible


func get_completion_text() -> String:
	return _completion_title.text if _completion_title != null else ""


func is_pause_visible() -> bool:
	return _pause_visible


func get_continue_button() -> PixelMenuButton:
	return _pause_continue


func get_title_button() -> PixelMenuButton:
	return _pause_title


func get_recovery_cover() -> ColorRect:
	return _recovery_cover


func get_completion_title_label() -> Label:
	return _completion_title


func get_event_text() -> String:
	return _event_label.text if _event_label != null else ""


func is_event_visible() -> bool:
	return _event_label != null and _event_label.visible
