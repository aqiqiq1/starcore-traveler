class_name RiftWorkshopHUD
extends CanvasLayer

## Small rift-workshop HUD.
##
## Same approved compact header as the trial chapter (title / one objective /
## current phase), plus a one-line event ticker, the recovery cover, the
## completion page ("裂隙封闭 · 用时 mm:ss") and the four-item pause page.
## No full settings page is copied into the DLC.  Every colour, the 12 px
## Fusion Pixel font and the existing PixelMenuButton are the project ones.
## Both modal pages use the shared UiReveal (0.18 s open / 0.12 s close for the
## pause page; the completion page snaps away when the chapter restarts).

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
const TITLE: String = "裂隙工坊"
const DEFAULT_OBJECTIVE: String = "目标：穿过反转回廊"
const PAUSE_PANEL_POSITION: Vector2 = Vector2(140.0, 56.0)
const PAUSE_PANEL_SIZE: Vector2 = Vector2(360.0, 236.0)
const COMPLETION_PANEL_POSITION: Vector2 = Vector2(120.0, 75.0)
const COMPLETION_PANEL_SIZE: Vector2 = Vector2(400.0, 210.0)
const PAUSE_SUBTITLE: String = "裂隙工坊 · 支线裂隙"
const COMPLETION_SUBTITLE: String = "双生守卫归寂，裂隙核心重新入睡。"
const PAUSE_FOOTER: String = "返回主界面不保存本章进度"
const COMPLETION_FOOTER: String = "本章结算 · Esc 可打开暂停菜单"
const PANEL_ANIM_TIME: float = UiReveal.OPEN_DURATION
const LEGEND_TEXT: String = (
	"金/青=相性 · 紫幕=换相 · 引力=吸附 · 胸口菱形=弱点 · 蓄力+异相 J=真伤"
)

var _root: Control
var _header: CompactLevelHeader
var _event_label: Label
var _event_left: float = 0.0
var _recovery_cover: ColorRect

var _completion_root: Control
var _completion_overlay: ColorRect
var _completion_panel: Panel
var _completion_title: Label
var _completion_subtitle: Label
var _completion_primary: PixelMenuButton
var _completion_replay: PixelMenuButton
var _completion_footer: Label
var _completion_reveal: UiReveal

var _pause_root: Control
var _pause_overlay: ColorRect
var _pause_panel: Panel
var _pause_heading: Label
var _pause_subtitle: Label
var _pause_continue: PixelMenuButton
var _pause_restart: PixelMenuButton
var _pause_title: PixelMenuButton
var _pause_quit: PixelMenuButton
var _pause_footer: Label
var _pause_reveal: UiReveal

var _legend: RiftLegend
var _font: Font
var _subtitle: String = ""
var _completion_visible: bool = false
var _pause_visible: bool = false


## Small permanent element legend under the event line.  Drawn by the HUD
## itself (no panel): a gold/cyan pair for the two phases, a purple bar for the
## inversion curtain, a ring for the gravity field and a diamond for the
## weakpoint.  It is a read-only hint, not an interactable control.
class RiftLegend extends Control:
	const LEGEND_GOLD: Color = Color("#f4cd63")
	const LEGEND_CYAN: Color = Color("#5fe1e6")
	const LEGEND_PURPLE: Color = Color("#b98cff")
	const LEGEND_TEXT_COLOR: Color = Color("#a4b3be")
	const LEGEND_SHADOW: Color = Color(0.006, 0.014, 0.018, 0.92)
	const LEGEND_SIZE: Vector2 = Vector2(616.0, 14.0)

	var font: Font = null

	func _ready() -> void:
		position = Vector2(12.0, 58.0)
		size = LEGEND_SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if font == null:
			return
		_diamond(Vector2(5.0, 7.0), 3.5, LEGEND_GOLD)
		_diamond(Vector2(15.0, 7.0), 3.5, LEGEND_CYAN)
		_text("金/青 相性", 21.0)
		draw_rect(Rect2(78.0, 3.0, 4.0, 9.0), Color(LEGEND_PURPLE, 0.95))
		_text("紫幕换相", 86.0)
		draw_arc(Vector2(136.0, 7.0), 5.0, 0.0, TAU, 14, LEGEND_GOLD, 1.0)
		_text("引力吸附", 144.0)
		_diamond(Vector2(196.0, 7.0), 3.5, Color(1.0, 0.98, 0.9))
		_text("弱点", 204.0)
		_text("· 蓄力时异相 J 才真伤", 232.0)

	func _text(value: String, x: float) -> void:
		draw_string(
			font, Vector2(x + 1.0, 12.0), value,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, LEGEND_SHADOW
		)
		draw_string(
			font, Vector2(x, 11.0), value,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, LEGEND_TEXT_COLOR
		)

	func _diamond(center: Vector2, radius: float, color: Color) -> void:
		draw_colored_polygon(
			PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius),
				center + Vector2(-radius, 0.0),
			]),
			color
		)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_font = _load_font()
	_root = Control.new()
	_root.name = "RiftHUDRoot"
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_header()
	_build_event()
	_build_legend()
	_build_recovery_cover()
	_build_completion()
	_build_pause()

	_completion_reveal = UiReveal.new()
	_completion_reveal.setup(
		self, _completion_root, _completion_overlay, _completion_panel,
		COMPLETION_PANEL_POSITION
	)
	_pause_reveal = UiReveal.new()
	_pause_reveal.setup(
		self, _pause_root, _pause_overlay, _pause_panel, PAUSE_PANEL_POSITION
	)

	set_polarity(false)
	set_objective(DEFAULT_OBJECTIVE)
	show_completion(false, 0.0)
	show_pause(false)


## Pause-page keyboard fallback.  The PixelMenuButton controls already handle
## Enter/Space when the viewport delivers GUI input; while the tree is paused
## this unhandled path keeps every row reachable even if GUI key delivery is
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
		_move_pause_focus(1)
		get_viewport().set_input_as_handled()
	elif code == int(KEY_UP):
		_move_pause_focus(-1)
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
	_header.configure(TITLE, DEFAULT_OBJECTIVE, _font)
	_header.set_polarity(false)


func _build_event() -> void:
	_event_label = _label("", Vector2(12.0, 42.0), Vector2(460.0, 16.0), 12, GOLD)
	_event_label.name = "EventLine"
	_event_label.visible = false
	_root.add_child(_event_label)


func _build_legend() -> void:
	_legend = RiftLegend.new()
	_legend.name = "ElementLegend"
	_legend.font = _font
	_root.add_child(_legend)


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
	_completion_root = Control.new()
	_completion_root.name = "CompletionRoot"
	_completion_root.position = Vector2.ZERO
	_completion_root.size = VIEW_SIZE
	_completion_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_completion_root.visible = false
	_root.add_child(_completion_root)

	_completion_overlay = ColorRect.new()
	_completion_overlay.name = "CompletionOverlay"
	_completion_overlay.position = Vector2.ZERO
	_completion_overlay.size = VIEW_SIZE
	_completion_overlay.color = Color(0.006, 0.014, 0.018, 0.66)
	_completion_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_completion_root.add_child(_completion_overlay)

	var panel: Panel = Panel.new()
	panel.name = "CompletionPanel"
	panel.position = COMPLETION_PANEL_POSITION
	panel.size = COMPLETION_PANEL_SIZE
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
	_completion_root.add_child(panel)
	_completion_panel = panel

	_completion_title = _label(
		"裂隙封闭 · 用时 00:00", Vector2(0.0, 12.0), Vector2(400.0, 34.0), 24, GOLD
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
	_completion_primary.name = "CompletionPrimary"
	_completion_primary.pressed.connect(func() -> void: title_requested.emit())
	panel.add_child(_completion_primary)

	_completion_replay = _menu_button(
		"重玩本章", Vector2(110.0, 126.0), Vector2(180.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_completion_replay.name = "CompletionReplay"
	_completion_replay.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(_completion_replay)

	_completion_footer = _label(
		COMPLETION_FOOTER, Vector2(0.0, 158.0), Vector2(400.0, 16.0), 12, DIM
	)
	_completion_footer.name = "CompletionFooter"
	_completion_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_completion_footer)

	_completion_primary.focus_next = _completion_primary.get_path_to(_completion_replay)
	_completion_primary.focus_previous = _completion_primary.get_path_to(_completion_replay)
	_completion_primary.focus_neighbor_bottom = _completion_primary.get_path_to(_completion_replay)
	_completion_primary.focus_neighbor_top = _completion_primary.get_path_to(_completion_replay)
	_completion_replay.focus_next = _completion_replay.get_path_to(_completion_primary)
	_completion_replay.focus_previous = _completion_replay.get_path_to(_completion_primary)
	_completion_replay.focus_neighbor_bottom = _completion_replay.get_path_to(_completion_primary)
	_completion_replay.focus_neighbor_top = _completion_replay.get_path_to(_completion_primary)


func _build_pause() -> void:
	_pause_root = Control.new()
	_pause_root.name = "PauseRoot"
	_pause_root.position = Vector2.ZERO
	_pause_root.size = VIEW_SIZE
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_root.visible = false
	_root.add_child(_pause_root)

	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.position = Vector2.ZERO
	_pause_overlay.size = VIEW_SIZE
	_pause_overlay.color = Color(0.006, 0.014, 0.018, 0.70)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_root.add_child(_pause_overlay)

	var panel: Panel = Panel.new()
	panel.name = "PausePanel"
	panel.position = PAUSE_PANEL_POSITION
	panel.size = PAUSE_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_pause_root.add_child(panel)
	_pause_panel = panel

	_pause_heading = _label(
		"已暂停", Vector2(0.0, 10.0), Vector2(360.0, 28.0), 24, GOLD
	)
	_pause_heading.name = "PauseTitle"
	_pause_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_pause_heading)

	_pause_subtitle = _label(
		PAUSE_SUBTITLE, Vector2(0.0, 38.0), Vector2(360.0, 16.0), 12, MUTED
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

	_pause_footer = _label(
		PAUSE_FOOTER, Vector2(0.0, 190.0), Vector2(360.0, 16.0), 12, DIM
	)
	_pause_footer.name = "PauseFooter"
	_pause_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_pause_footer)

	var order: Array[PixelMenuButton] = [
		_pause_continue, _pause_restart, _pause_title, _pause_quit
	]
	for index: int in range(order.size()):
		var current: PixelMenuButton = order[index]
		var next: PixelMenuButton = order[(index + 1) % order.size()]
		var previous: PixelMenuButton = order[(index - 1 + order.size()) % order.size()]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(previous)


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
	var changed: bool = value != _completion_visible
	_completion_visible = value
	if _completion_title != null:
		_completion_title.text = "裂隙封闭 · 用时 %s" % _format_time(elapsed_seconds)
	if _completion_root == null:
		return
	if value:
		if changed:
			_completion_reveal.play_open()
		call_deferred("_focus_completion")
		return
	if changed:
		_completion_reveal.snap_closed()
	_release_completion_focus()


func show_pause(value: bool) -> void:
	var changed: bool = value != _pause_visible
	_pause_visible = value
	if _pause_root == null:
		return
	if value:
		if changed:
			_pause_reveal.play_open()
		call_deferred("_focus_pause")
		return
	if changed:
		_pause_reveal.play_close()
	_release_pause_focus()
	if _completion_visible:
		call_deferred("_focus_completion")


func _move_pause_focus(step: int) -> void:
	var order: Array[PixelMenuButton] = [
		_pause_continue, _pause_restart, _pause_title, _pause_quit
	]
	var focused: Control = get_viewport().gui_get_focus_owner()
	var index: int = order.find(focused as PixelMenuButton)
	if index < 0:
		index = 0
	var next_index: int = (index + step + order.size()) % order.size()
	order[next_index].grab_focus()


func _focus_pause() -> void:
	if _pause_visible and _pause_continue != null:
		_pause_continue.grab_focus()


func _release_pause_focus() -> void:
	for button: PixelMenuButton in [
		_pause_continue, _pause_restart, _pause_title, _pause_quit
	]:
		if button != null:
			button.release_focus()


func _focus_completion() -> void:
	if _completion_visible and _completion_primary != null:
		_completion_primary.grab_focus()


func _release_completion_focus() -> void:
	for button: PixelMenuButton in [_completion_primary, _completion_replay]:
		if button != null:
			button.release_focus()


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


func get_completion_subtitle_text() -> String:
	return _completion_subtitle.text if _completion_subtitle != null else ""


func get_completion_footer_text() -> String:
	return _completion_footer.text if _completion_footer != null else ""


func get_completion_primary_button() -> PixelMenuButton:
	return _completion_primary


func get_completion_replay_button() -> PixelMenuButton:
	return _completion_replay


func get_completion_panel_rect() -> Rect2:
	return Rect2(COMPLETION_PANEL_POSITION, COMPLETION_PANEL_SIZE)


func is_pause_visible() -> bool:
	return _pause_visible


func get_pause_title_text() -> String:
	return _pause_heading.text if _pause_heading != null else ""


func get_pause_subtitle_text() -> String:
	return _pause_subtitle.text if _pause_subtitle != null else ""


func get_pause_footer_text() -> String:
	return _pause_footer.text if _pause_footer != null else ""


func get_continue_button() -> PixelMenuButton:
	return _pause_continue


func get_restart_button() -> PixelMenuButton:
	return _pause_restart


func get_title_button() -> PixelMenuButton:
	return _pause_title


func get_quit_button() -> PixelMenuButton:
	return _pause_quit


func get_pause_panel_rect() -> Rect2:
	return Rect2(PAUSE_PANEL_POSITION, PAUSE_PANEL_SIZE)


func get_recovery_cover() -> ColorRect:
	return _recovery_cover


func get_completion_title_label() -> Label:
	return _completion_title


## Current event-line text, whether or not its display timer has expired.
func get_event_text() -> String:
	return _event_label.text if _event_label != null else ""


func is_event_visible() -> bool:
	return _event_label != null and _event_label.visible


func is_legend_visible() -> bool:
	return _legend != null and _legend.visible and _legend.font != null


func get_legend_text() -> String:
	return LEGEND_TEXT


func get_legend_rect() -> Rect2:
	if _legend == null:
		return Rect2()
	return Rect2(_legend.position, _legend.size)


func get_pause_panel_alpha() -> float:
	return _pause_reveal.get_shade_alpha() if _pause_reveal != null else 0.0


func get_pause_panel_offset() -> float:
	return _pause_reveal.get_panel_offset_y() if _pause_reveal != null else 0.0


func get_completion_panel_alpha() -> float:
	return _completion_reveal.get_shade_alpha() if _completion_reveal != null else 0.0


func get_completion_panel_offset() -> float:
	return (
		_completion_reveal.get_panel_offset_y() if _completion_reveal != null else 0.0
	)


func is_panel_animating() -> bool:
	var pause_animating: bool = _pause_reveal != null and _pause_reveal.is_animating()
	var completion_animating: bool = (
		_completion_reveal != null and _completion_reveal.is_animating()
	)
	return pause_animating or completion_animating


func get_panel_anim_time() -> float:
	return PANEL_ANIM_TIME
