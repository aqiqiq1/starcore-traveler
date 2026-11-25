extends CanvasLayer

## Shared in-level pause page for both formal levels.
##
## The pause page owns the real commands (resume, settings, restart, return to
## title, quit) and the per-level control reference that used to sit in a
## permanent bottom strip.  Esc is routed here only, one layer per press:
##   display confirmation -> cancel pending, stay in settings (tree stays paused)
##   settings             -> close settings, still on the paused root
##   paused root          -> resume
##   gameplay             -> open the paused root
## The tree is paused while the page is open, so the level physics, core, lids,
## pulse animations and enemy-free world all freeze.  Settings are the same
## StartMenu settings UI in host mode, sharing audio_settings.cfg and
## display_settings.cfg rather than forking the volume/display code.

signal restart_requested
signal return_to_menu_requested
signal quit_requested
signal opened
signal resumed

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DIM: Color = Color("#728889")
const PANEL_BG: Color = Color(0.014, 0.032, 0.040, 0.96)
const PANEL_BORDER: Color = Color(0.45, 0.66, 0.63, 0.9)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const DEFAULT_AUDIO_PATH: String = "user://audio_settings.cfg"
const DEFAULT_DISPLAY_PATH: String = "user://display_settings.cfg"
const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")

## Set by the level before add_child().  The level also supplies the control
## rows because level 02 has E (release/store) and level 01 does not.
var level_node: Node = null
var controls_rows: Array = []
var audio_settings_path: String = DEFAULT_AUDIO_PATH
var display_settings_path: String = DEFAULT_DISPLAY_PATH

var _root: Control = null
var _shade: ColorRect = null
var _panel: Panel = null
var _continue_button: PixelMenuButton = null
var _settings_button: PixelMenuButton = null
var _restart_button: PixelMenuButton = null
var _return_button: PixelMenuButton = null
var _quit_button: PixelMenuButton = null
var _controls_header: Label = null
var _controls_labels: Array[Label] = []
var _font: Font = null
var _reveal: UiReveal = null

var _settings_host: StartMenu = null
var _open: bool = false
var _settings_open: bool = false
var _completion_active: bool = false
var _scene_leaving: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 16
	_font = _load_font()
	_build_ui()
	_build_settings_host()
	_reveal = UiReveal.new()
	_reveal.setup(self, _root, _shade, _panel, _panel.position)
	_root.visible = false
	set_process(true)


func _process(_delta: float) -> void:
	if _scene_leaving or not _can_use():
		return
	if Input.is_action_just_pressed(&"pause"):
		_handle_pause()
		return
	if Input.is_action_just_pressed(&"reset"):
		_handle_reset()


# --- Public state / commands ----------------------------------------------

func is_open() -> bool:
	return _open


## Shared reveal state for tests/audits; pause state never waits on it.
func get_reveal() -> UiReveal:
	return _reveal


func is_settings_open() -> bool:
	return _settings_open


func is_pause_root_visible() -> bool:
	return _root != null and _root.visible


func is_display_pending() -> bool:
	return _settings_host != null and _settings_host.is_display_pending()


func get_settings_host() -> StartMenu:
	return _settings_host


func get_continue_button() -> PixelMenuButton:
	return _continue_button


func get_settings_button() -> PixelMenuButton:
	return _settings_button


func get_restart_button() -> PixelMenuButton:
	return _restart_button


func get_return_button() -> PixelMenuButton:
	return _return_button


func get_quit_button() -> PixelMenuButton:
	return _quit_button


func get_controls_text() -> String:
	var lines: Array[String] = []
	for row: Variant in controls_rows:
		if row is Array and (row as Array).size() >= 2:
			lines.append("%s  %s" % [String((row as Array)[0]), String((row as Array)[1])])
	return "\n".join(lines)


func has_controls_section() -> bool:
	return _controls_header != null and _controls_labels.size() > 0


## Read-only audit helper for the per-level control rows (not the shared
## settings host, whose approved menu typography is intentionally separate).
func get_control_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for label: Label in _controls_labels:
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


func set_completion_active(value: bool) -> void:
	_completion_active = value


## Production entry when Esc is pressed in gameplay or from the completion
## page.  It is also used by the focused-key smoke tests.
func open_pause() -> void:
	if _open or _scene_leaving or not _can_use():
		return
	if level_node != null and level_node.has_method("before_pause_opened"):
		level_node.call("before_pause_opened")
	_open = true
	_settings_open = false
	_root.visible = true
	_panel.visible = true
	get_tree().paused = true
	if _reveal != null:
		_reveal.play_open()
	_clean_player_input()
	# The deferred focus happens after the reveal starts; the tween never owns
	# pause/focus and cannot delay them.
	call_deferred("_focus_continue")
	opened.emit()


func resume() -> void:
	if not _open:
		return
	if _settings_open:
		close_settings()
	# Resume (and any focus hand-back) is immediate; the root only remains for
	# the 0.12 s visual exit and ignores mouse input during it.
	_open = false
	get_tree().paused = false
	if _reveal != null:
		_reveal.play_close()
	else:
		_root.visible = false
	_clean_player_input()
	LEVEL_FLOW.release_one_shot_actions()
	if level_node != null and level_node.has_method("on_pause_resumed"):
		level_node.call("on_pause_resumed")
	resumed.emit()


## Used by restart / scene changes.  Idempotent; never opens the game.
func force_close() -> void:
	_cancel_pending_for_leave()
	_open = false
	_settings_open = false
	if _settings_host != null:
		_settings_host.hide_settings_host()
	if _reveal != null:
		_reveal.snap_closed()
	if _root != null:
		_root.visible = false
	get_tree().paused = false


## Explicit scene-leave path: commit nothing, restore an unconfirmed display
## change, unpause the tree and release input that must not cross scenes.
func prepare_scene_change() -> void:
	_scene_leaving = true
	force_close()
	LEVEL_FLOW.release_gameplay_actions()


func open_settings() -> void:
	if not _open or _settings_open or _settings_host == null:
		return
	if _settings_host.is_display_pending():
		return
	_settings_open = true
	_panel.visible = false
	if _reveal != null:
		_reveal.snap_closed()
	_root.visible = false
	_settings_host.open_settings_host()


func close_settings() -> void:
	if not _settings_open:
		return
	if _settings_host != null and _settings_host.is_display_pending():
		return
	_settings_open = false
	if _settings_host != null:
		_settings_host.hide_settings_host()
	if _root != null:
		_root.visible = true
	_panel.visible = true
	get_tree().paused = true
	if _reveal != null:
		_reveal.play_open()
	call_deferred("_focus_settings")


# --- Input routing ---------------------------------------------------------

func _can_use() -> bool:
	if level_node != null and level_node.has_method("is_pause_menu_blocked"):
		return not bool(level_node.call("is_pause_menu_blocked"))
	return true


func _handle_pause() -> void:
	if _settings_open:
		if _settings_host != null and _settings_host.is_display_pending():
			# Highest priority: Esc cancels the unconfirmed display change and
			# leaves the settings page open, still paused.
			_settings_host.cancel_display_pending("escape")
		else:
			close_settings()
		return
	if _open:
		resume()
	else:
		open_pause()


func _handle_reset() -> void:
	# R is deliberately inert while the settings / display confirmation layer is
	# open, so it cannot restart behind the panel.
	if _settings_open or is_display_pending():
		return
	if _open:
		_restart_from_pause()
		return
	LEVEL_FLOW.release_one_shot_actions()
	restart_requested.emit()


# --- Buttons ---------------------------------------------------------------

func _on_continue_pressed() -> void:
	if not _open:
		return
	resume()


func _on_settings_pressed() -> void:
	if not _open:
		return
	open_settings()


func _on_restart_pressed() -> void:
	if not _open:
		return
	_restart_from_pause()


func _restart_from_pause() -> void:
	if not _open:
		return
	_open = false
	_settings_open = false
	if _reveal != null:
		_reveal.snap_closed()
	if _root != null:
		_root.visible = false
	get_tree().paused = false
	_clean_player_input()
	LEVEL_FLOW.release_gameplay_actions()
	restart_requested.emit()


func _on_return_pressed() -> void:
	if not _open:
		return
	prepare_scene_change()
	return_to_menu_requested.emit()


func _on_quit_pressed() -> void:
	if not _open:
		return
	prepare_scene_change()
	quit_requested.emit()
	get_tree().quit(0)


# --- Settings host ---------------------------------------------------------

func _build_settings_host() -> void:
	_settings_host = StartMenu.new()
	_settings_host.name = "PauseSettingsHost"
	_settings_host.settings_host_mode = true
	_settings_host.audio_settings_path = audio_settings_path
	_settings_host.display_settings_path = display_settings_path
	add_child(_settings_host)
	_settings_host.settings_host_closed.connect(_on_settings_host_closed)


func _on_settings_host_closed() -> void:
	if not _settings_open:
		return
	_settings_open = false
	_root.visible = true
	_panel.visible = true
	get_tree().paused = true
	if _reveal != null:
		_reveal.play_open()
	call_deferred("_focus_settings")


func _cancel_pending_for_leave() -> void:
	if _settings_host != null:
		_settings_host.cancel_display_pending_for_leave()


# --- Focus / input cleanup -------------------------------------------------

func _focus_continue() -> void:
	if not _open or _settings_open:
		return
	_continue_button.grab_focus()


func _focus_settings() -> void:
	if not _open or _settings_open:
		return
	_settings_button.grab_focus()


func _clean_player_input() -> void:
	if level_node == null or not level_node.has_method("get_player"):
		return
	var player: PrototypePlayer = level_node.call("get_player") as PrototypePlayer
	if player == null:
		return
	player.clear_input_buffers()
	player.clear_external_force()


func _refresh_focus_chain() -> void:
	var chain: Array[Control] = [
		_continue_button,
		_settings_button,
		_restart_button,
		_return_button,
		_quit_button,
	]
	for index: int in range(chain.size()):
		var current: Control = chain[index]
		var next: Control = chain[(index + 1) % chain.size()]
		var previous: Control = chain[(index - 1 + chain.size()) % chain.size()]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(previous)


# --- Build UI --------------------------------------------------------------

func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		push_warning("PauseMenu: %s is missing; falling back" % FONT_PATH)
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
	_root.name = "PauseMenuRoot"
	_root.position = Vector2.ZERO
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_shade = ColorRect.new()
	_shade.position = Vector2.ZERO
	_shade.size = VIEW_SIZE
	_shade.color = Color(0.006, 0.014, 0.018, 0.70)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_shade)

	_panel = Panel.new()
	_panel.position = Vector2(60.0, 28.0)
	_panel.size = Vector2(520.0, 302.0)
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

	var title: Label = _label("已暂停", Vector2(0.0, 8.0), Vector2(520.0, 32.0), 24, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)
	var subtitle: Label = _label("断桥庭院 · 第一关" if _is_level_one() else "沉寂回廊 · 第二关",
		Vector2(0.0, 40.0), Vector2(520.0, 16.0), 12, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(subtitle)

	_continue_button = _menu_button("继续游戏", Vector2(22.0, 62.0), PixelMenuButton.Variant.STONE)
	_continue_button.pressed.connect(_on_continue_pressed)
	_panel.add_child(_continue_button)

	_settings_button = _menu_button("设置", Vector2(22.0, 94.0), PixelMenuButton.Variant.OPTION)
	_settings_button.pressed.connect(_on_settings_pressed)
	_panel.add_child(_settings_button)

	_restart_button = _menu_button("重新开始本关", Vector2(22.0, 126.0), PixelMenuButton.Variant.OPTION)
	_restart_button.pressed.connect(_on_restart_pressed)
	_panel.add_child(_restart_button)

	_return_button = _menu_button("返回主界面", Vector2(22.0, 158.0), PixelMenuButton.Variant.OPTION)
	_return_button.pressed.connect(_on_return_pressed)
	_panel.add_child(_return_button)

	_quit_button = _menu_button("退出游戏", Vector2(22.0, 190.0), PixelMenuButton.Variant.OPTION)
	_quit_button.pressed.connect(_on_quit_pressed)
	_panel.add_child(_quit_button)

	var note: Label = _label("返回主界面不保存本关进度", Vector2(22.0, 220.0), Vector2(208.0, 32.0), 12, DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(note)

	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(244.0, 58.0)
	divider.size = Vector2(1.0, 224.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.40)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(divider)

	_controls_header = _label("本关操作", Vector2(262.0, 58.0), Vector2(236.0, 16.0), 12, CYAN)
	_panel.add_child(_controls_header)
	var controls_divider: ColorRect = ColorRect.new()
	controls_divider.position = Vector2(262.0, 76.0)
	controls_divider.size = Vector2(236.0, 1.0)
	controls_divider.color = Color(0.45, 0.66, 0.63, 0.35)
	controls_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(controls_divider)

	var row_y: float = 80.0
	var row_step: float = 16.0 if controls_rows.size() > 9 else 18.0
	for row: Variant in controls_rows:
		if not (row is Array) or (row as Array).size() < 2:
			continue
		var keys_label: Label = _label(
			String((row as Array)[1]),
			Vector2(262.0, row_y),
			Vector2(130.0, 16.0),
			12,
			TEXT
		)
		_panel.add_child(keys_label)
		_controls_labels.append(keys_label)
		var name_label: Label = _label(
			String((row as Array)[0]),
			Vector2(396.0, row_y),
			Vector2(102.0, 16.0),
			12,
			MUTED
		)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_panel.add_child(name_label)
		_controls_labels.append(name_label)
		row_y += row_step

	var route_hint: Label = _label(
		"Esc 逐层返回 · 设置与显示确认仍会暂停游戏",
		Vector2(262.0, 260.0 if controls_rows.size() > 9 else 246.0),
		Vector2(236.0, 32.0),
		12,
		DIM
	)
	route_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(route_hint)

	_refresh_focus_chain()


func _menu_button(text_value: String, position_value: Vector2, variant: int) -> PixelMenuButton:
	var button: PixelMenuButton = PixelMenuButton.new()
	button.text = text_value
	button.position = position_value
	button.size = Vector2(208.0, 24.0)
	button.font = _font
	button.font_size = 12
	button.variant = variant
	return button


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


func _is_level_one() -> bool:
	if level_node == null:
		return false
	return level_node.get_script() != null and String(level_node.get_script().resource_path).ends_with("level_01.gd")
