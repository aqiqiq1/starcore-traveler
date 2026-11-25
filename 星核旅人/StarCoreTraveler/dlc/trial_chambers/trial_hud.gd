class_name TrialHUD
extends CanvasLayer

## Small trial-only HUD.
##
## Only three permanent reads (title / one short objective / current phase) use
## the shared compact header.  The completion page (two entries) and the
## four-item pause page are the only modal panels; the full settings page is
## deliberately not copied here.  Every colour is from the existing palette.

signal resume_requested
signal title_requested
signal restart_requested
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
const TITLE: String = "星核试炼场"

var _root: Control
var _header: CompactLevelHeader
var _event_label: Label
var _event_left: float = 0.0
var _recovery_cover: ColorRect
var _completion_overlay: ColorRect
var _completion_panel: Panel
var _completion_panel_base: Vector2 = Vector2.ZERO
var _completion_tween: Tween
var _completion_title: Label
var _completion_subtitle: Label
var _completion_note: Label
var _completion_primary: PixelMenuButton
var _completion_replay: PixelMenuButton
var _pause_overlay: ColorRect
var _pause_panel: Panel
var _pause_panel_base: Vector2 = Vector2.ZERO
var _pause_tween: Tween
var _pause_subtitle: Label
var _pause_note: Label
var _pause_continue: PixelMenuButton
var _pause_restart: PixelMenuButton
var _pause_return: PixelMenuButton
var _pause_quit: PixelMenuButton
var _font: Font
var _subtitle: String = ""
var _completion_visible: bool = false
var _pause_visible: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_font = _load_font()
	_root = Control.new()
	_root.name = "TrialHUDRoot"
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_header()
	_build_event()
	_build_recovery_cover()
	_build_completion()
	_build_pause()
	set_polarity(false)
	set_objective("目标：Q 换相，穿过金门")
	show_completion(false, 0.0)
	show_pause(false)


## Pause-page keyboard fallback.  The PixelMenuButton controls already handle
## Enter/Space when the viewport delivers GUI input; while the tree is paused
## this unhandled path makes all four entries work even if GUI key delivery is
## skipped.  It never runs when the pause page is hidden.
func _unhandled_input(event: InputEvent) -> void:
	if not _pause_visible or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)
	var chain: Array[PixelMenuButton] = _pause_chain()
	var focused: Control = get_viewport().gui_get_focus_owner()
	var index: int = chain.find(focused as PixelMenuButton)
	if code == int(KEY_ENTER) or code == int(KEY_KP_ENTER) or code == int(KEY_SPACE):
		get_viewport().set_input_as_handled()
		_activate_pause_entry(focused as PixelMenuButton)
	elif code == int(KEY_DOWN) or code == int(KEY_TAB):
		index = 0 if index < 0 else (index + 1) % chain.size()
		chain[index].grab_focus()
		get_viewport().set_input_as_handled()
	elif code == int(KEY_UP):
		index = chain.size() - 1 if index < 0 else (index - 1 + chain.size()) % chain.size()
		chain[index].grab_focus()
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


func _build_header() -> void:
	_header = CompactLevelHeader.new()
	_header.name = "CompactHeader"
	_root.add_child(_header)
	_header.configure(TITLE, "目标：Q 换相，穿过金门", _font)
	_header.set_polarity(false)


func _build_event() -> void:
	_event_label = _label("", Vector2(12.0, 42.0), Vector2(430.0, 16.0), 12, GOLD)
	_event_label.name = "EventLine"
	_event_label.visible = false
	_root.add_child(_event_label)


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
	panel.position = Vector2(120.0, 75.0)
	panel.size = Vector2(400.0, 210.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_completion_panel_base = panel.position

	_completion_title = _label(
		"试炼完成 · 用时 00:00", Vector2(0.0, 12.0), Vector2(400.0, 34.0), 24, GOLD
	)
	_completion_title.name = "CompletionTitle"
	_completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_completion_title)

	_completion_subtitle = _label(
		"试炼场的门重新合拢，星核记住了你的相性。",
		Vector2(0.0, 50.0), Vector2(400.0, 18.0), 12, TEXT
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
	_completion_primary.name = "CompletionReturn"
	_completion_primary.pressed.connect(func() -> void: title_requested.emit())
	panel.add_child(_completion_primary)

	_completion_replay = _menu_button(
		"重玩本章", Vector2(110.0, 126.0), Vector2(180.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_completion_replay.name = "CompletionReplay"
	_completion_replay.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(_completion_replay)

	_completion_note = _label(
		"本章结算 · Esc 可打开暂停菜单",
		Vector2(0.0, 158.0), Vector2(400.0, 16.0), 12, DIM
	)
	_completion_note.name = "CompletionNote"
	_completion_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_completion_note)

	_completion_primary.focus_next = _completion_primary.get_path_to(_completion_replay)
	_completion_primary.focus_previous = _completion_primary.get_path_to(_completion_replay)
	_completion_primary.focus_neighbor_bottom = _completion_primary.get_path_to(_completion_replay)
	_completion_primary.focus_neighbor_top = _completion_primary.get_path_to(_completion_replay)
	_completion_replay.focus_next = _completion_replay.get_path_to(_completion_primary)
	_completion_replay.focus_previous = _completion_replay.get_path_to(_completion_primary)
	_completion_replay.focus_neighbor_bottom = _completion_replay.get_path_to(_completion_primary)
	_completion_replay.focus_neighbor_top = _completion_replay.get_path_to(_completion_primary)


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
	panel.position = Vector2(140.0, 56.0)
	panel.size = Vector2(360.0, 236.0)
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
	_pause_panel_base = panel.position

	var title: Label = _label("已暂停", Vector2(0.0, 6.0), Vector2(360.0, 30.0), 24, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	_pause_subtitle = _label(
		"星核试炼场 · 支线试炼", Vector2(0.0, 36.0), Vector2(360.0, 16.0), 12, MUTED
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

	_pause_return = _menu_button(
		"返回主界面", Vector2(76.0, 124.0), Vector2(208.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_pause_return.name = "ReturnButton"
	_pause_return.pressed.connect(func() -> void: title_requested.emit())
	panel.add_child(_pause_return)

	_pause_quit = _menu_button(
		"退出游戏", Vector2(76.0, 158.0), Vector2(208.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_pause_quit.name = "QuitButton"
	_pause_quit.pressed.connect(func() -> void: quit_requested.emit())
	panel.add_child(_pause_quit)

	_pause_note = _label(
		"返回主界面不保存本章进度",
		Vector2(0.0, 190.0), Vector2(360.0, 16.0), 12, DIM
	)
	_pause_note.name = "PauseNote"
	_pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_pause_note)

	var chain: Array[PixelMenuButton] = _pause_chain()
	for index: int in range(chain.size()):
		var current: PixelMenuButton = chain[index]
		var next: PixelMenuButton = chain[(index + 1) % chain.size()]
		var previous: PixelMenuButton = chain[(index - 1 + chain.size()) % chain.size()]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(previous)


func _pause_chain() -> Array[PixelMenuButton]:
	var chain: Array[PixelMenuButton] = [
		_pause_continue, _pause_restart, _pause_return, _pause_quit
	]
	return chain


func _activate_pause_entry(focused: PixelMenuButton) -> void:
	if focused == _pause_restart:
		restart_requested.emit()
	elif focused == _pause_return:
		title_requested.emit()
	elif focused == _pause_quit:
		quit_requested.emit()
	else:
		resume_requested.emit()


# --- public state ----------------------------------------------------------

func set_polarity(positive: bool) -> void:
	if _header != null:
		_header.set_polarity(positive)


func set_objective(text_value: String) -> void:
	_subtitle = text_value
	if _header != null:
		_header.configure(TITLE, text_value, _font)


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
	_completion_overlay.visible = value
	_completion_title.text = "试炼完成 · 用时 %s" % _format_time(elapsed_seconds)
	if value:
		_completion_tween = _play_reveal(
			_completion_tween, _completion_overlay, _completion_panel, _completion_panel_base
		)
		call_deferred("_focus_completion_primary")
	else:
		_snap_reveal(_completion_tween, _completion_overlay, _completion_panel, _completion_panel_base)
		_completion_tween = null
		_release_completion_focus()


func show_pause(value: bool) -> void:
	_pause_visible = value
	if _pause_overlay == null:
		return
	_pause_overlay.visible = value
	if value:
		_release_completion_focus()
		_pause_tween = _play_reveal(_pause_tween, _pause_overlay, _pause_panel, _pause_panel_base)
		call_deferred("_focus_pause")
	else:
		_snap_reveal(_pause_tween, _pause_overlay, _pause_panel, _pause_panel_base)
		_pause_tween = null
		for button: PixelMenuButton in _pause_chain():
			button.release_focus()
		if _completion_visible:
			call_deferred("_focus_completion_primary")


## Same-frame overlay with a 0.18 s alpha/scale/slide entrance (see UiReveal).
## The HUD is PROCESS_MODE_ALWAYS, so the tweens finish while the tree is paused.
func _play_reveal(
	previous: Tween, overlay: ColorRect, panel: Panel, panel_base: Vector2
) -> Tween:
	if previous != null and previous.is_valid():
		previous.kill()
	return UiReveal.play_overlay_open(self, overlay, panel, panel_base)


func _snap_reveal(
	previous: Tween, overlay: ColorRect, panel: Panel, panel_base: Vector2
) -> void:
	if previous != null and previous.is_valid():
		previous.kill()
	UiReveal.snap_overlay(overlay, panel, panel_base)


func _focus_pause() -> void:
	if _pause_visible and _pause_continue != null:
		_pause_continue.grab_focus()


func _focus_completion_primary() -> void:
	if _completion_visible and not _pause_visible and _completion_primary != null:
		_completion_primary.grab_focus()


func _release_completion_focus() -> void:
	if _completion_primary != null:
		_completion_primary.release_focus()
	if _completion_replay != null:
		_completion_replay.release_focus()


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


func is_completion_visible() -> bool:
	return _completion_visible


func get_completion_text() -> String:
	return _completion_title.text if _completion_title != null else ""


func is_pause_visible() -> bool:
	return _pause_visible


func get_continue_button() -> PixelMenuButton:
	return _pause_continue


## Kept for the existing pause test name; this is the 返回主界面 row.
func get_title_button() -> PixelMenuButton:
	return _pause_return


func get_restart_button() -> PixelMenuButton:
	return _pause_restart


func get_pause_return_button() -> PixelMenuButton:
	return _pause_return


func get_quit_button() -> PixelMenuButton:
	return _pause_quit


func get_pause_subtitle_text() -> String:
	return _pause_subtitle.text if _pause_subtitle != null else ""


func get_pause_note_text() -> String:
	return _pause_note.text if _pause_note != null else ""


func get_pause_panel_rect() -> Rect2:
	return Rect2(_pause_panel_base, _pause_panel.size if _pause_panel != null else Vector2.ZERO)


func get_completion_primary_button() -> PixelMenuButton:
	return _completion_primary


func get_completion_replay_button() -> PixelMenuButton:
	return _completion_replay


func get_completion_subtitle_text() -> String:
	return _completion_subtitle.text if _completion_subtitle != null else ""


func get_completion_note_text() -> String:
	return _completion_note.text if _completion_note != null else ""


func get_completion_panel_rect() -> Rect2:
	return Rect2(
		_completion_panel_base,
		_completion_panel.size if _completion_panel != null else Vector2.ZERO
	)


func get_recovery_cover() -> ColorRect:
	return _recovery_cover


func get_completion_title_label() -> Label:
	return _completion_title


## Current event-line text, whether or not its display timer has expired.
func get_event_text() -> String:
	return _event_label.text if _event_label != null else ""


func is_event_visible() -> bool:
	return _event_label != null and _event_label.visible
