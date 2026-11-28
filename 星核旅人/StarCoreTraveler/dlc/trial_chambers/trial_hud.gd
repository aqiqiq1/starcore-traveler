class_name TrialHUD
extends CanvasLayer

## Small trial-only HUD.
##
## One top-left chapter/objective row, the shared 20x20 phase icon, the fixed
## lower-left red health bar, the shared 360x16 guard boss bar, and no second
## event line.  Events replace the objective over 0.15 s.  The completion page
## (two entries) and the five-item pause page (four commands plus the in-panel
## 操作 reference) are the only modal panels; all of them hide the HUD chrome.

signal resume_requested
signal title_requested
signal restart_requested
signal quit_requested
## Emitted by the completion page's primary row only while this chapter was
## entered from a hidden in-level entrance.  Normal title entry keeps
## title_requested.
signal mainline_requested

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
const HIT_PULSE_SECONDS: float = 1.0
const HIT_PULSE_SCALE: float = 0.28
## Six-row in-panel reference, keyed to the real route.  The trial keeps the
## shared Q polarity toggle.
const PAUSE_CONTROLS_HEADER: String = "本关操作"
const PAUSE_CONTROLS_ROWS: Array = [
	["移动", "A / D · ← / →"],
	["跳跃", "{SPACE}"],
	["攻击", "{J}"],
	["换相", "{Q}"],
	["暂停", "{ESC}"],
	["重开", "{R}"],
]

var _root: Control
var _header: HudObjective
var _boss_bar: HudBossBar
var _hit_pips: PlayerHealthBar
var _player: Node2D = null
var _pips_visible: bool = true
var _hit_pulse_left: float = 0.0
var _hit_pulse_duration: float = HIT_PULSE_SECONDS
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
var _completion_primary_mainline: bool = false
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
var _pause_controls: PixelMenuButton
var _manual_button: PixelMenuButton
var _manual: MechanicManual
var _pause_controls_root: Control
var _pause_controls_back: PixelMenuButton
var _pause_controls_labels: Array[Control] = []
var _controls_visible: bool = false
var _font: Font
var _subtitle: String = ""
var _completion_visible: bool = false
var _pause_visible: bool = false
var _intro_fade_tween: Tween = null


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
	_build_boss_bar()
	_build_hit_pips()
	_build_recovery_cover()
	_build_completion()
	_build_pause()
	_build_manual()
	set_polarity(false)
	set_player_hits(2, 2)
	set_objective("目标：触碰晶体，换辉相过金门")
	show_completion(false, 0.0)
	show_pause(false)
	_root.modulate.a = 0.0
	_intro_fade_tween = create_tween()
	_intro_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_intro_fade_tween.tween_property(_root, "modulate:a", 1.0, 0.15)


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
	# The operation reference is a sub-page of the pause panel.  While it is
	# open, Enter/Space only closes that sub-page; it must never resume or
	# restart the trial behind the table.
	if _controls_visible:
		if code == int(KEY_ESCAPE) or code == int(KEY_F) \
				or code == int(KEY_ENTER) or code == int(KEY_KP_ENTER) \
				or code == int(KEY_SPACE):
			close_controls()
			get_viewport().set_input_as_handled()
			return
		if code == int(KEY_DOWN) or code == int(KEY_TAB) or code == int(KEY_UP):
			if _pause_controls_back != null:
				_pause_controls_back.grab_focus()
			get_viewport().set_input_as_handled()
			return
		return
	if code == int(KEY_F):
		open_controls()
		get_viewport().set_input_as_handled()
		return
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
	# Even while the tree is paused (guide / mechanic popup / pause page), the
	# HUD is ALWAYS: keep the fixed bar hidden and its pulse settled so resuming
	# cannot flash it mid-scale.
	_update_hit_pulse(delta)
	_update_chrome_visibility()


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
	label.add_theme_constant_override("outline_size", 1)
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


## Key column for the in-panel control reference.  Same 16x16 inline caps and
## 12 px pixel font as the shared pause page.
func _keys_label(
	text_value: String, position_value: Vector2, size_value: Vector2
) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.scroll_active = false
	label.fit_content = false
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font != null:
		label.add_theme_font_override("normal_font", _font)
	label.add_theme_font_size_override("normal_font_size", 12)
	label.add_theme_color_override("default_color", TEXT)
	label.add_theme_color_override("font_outline_color", Color(0.006, 0.014, 0.018, 0.96))
	label.add_theme_constant_override("outline_size", 1)
	label.text = KeyGlyph.decorate(text_value)
	return label


func _build_header() -> void:
	_header = HudObjective.new()
	_header.name = "HudObjective"
	_root.add_child(_header)
	_header.configure(TITLE, "目标：触碰晶体，换辉相过金门", _font)
	_header.set_polarity(false)


func _build_boss_bar() -> void:
	_boss_bar = HudBossBar.new()
	_boss_bar.name = "BossBar"
	_boss_bar.configure("守卫", 3, 1, _font)
	_boss_bar.position = HudBossBar.HUD_POSITION
	_root.add_child(_boss_bar)
	_boss_bar.set_active(false)


## Shared two-segment red health VALUE bar, fixed at the lower-left HUD corner.
## The trial has no "受击 1 / 2" text: an accepted hit removes one segment, the
## second hit starts the existing failure recovery and both segments refill.
## The row never follows the character; the 10 px heart replaces the old word.
func _build_hit_pips() -> void:
	_hit_pips = PlayerHealthBar.new()
	_hit_pips.name = "PlayerHealthBar"
	_hit_pips.max_segments = 2
	_hit_pips.position = PlayerHealthBar.HUD_POSITION
	_hit_pips.set_state(2, 2)
	_hit_pips.visible = false
	_root.add_child(_hit_pips)
	_hit_pips.pivot_offset = _hit_pips.size * 0.5


## Kept for the existing chapter call.  The bar is fixed at the lower-left, so
## the player's screen position no longer affects it.
func set_player_node(player: Node2D) -> void:
	_player = player


func set_hit_pips_visible(value: bool) -> void:
	_pips_visible = value
	_update_hit_pips_visibility()


func is_hit_pips_visible() -> bool:
	return _hit_pips != null and _hit_pips.visible


func get_hit_pips_position() -> Vector2:
	return _hit_pips.position if _hit_pips != null else Vector2.ZERO


func get_hit_pips_screen_center() -> Vector2:
	if _hit_pips == null:
		return Vector2.ZERO
	return _hit_pips.position + _hit_pips.size * 0.5


func get_hit_pips_rect() -> Rect2:
	if _hit_pips == null:
		return Rect2()
	return Rect2(_hit_pips.position, _hit_pips.size)


func pulse_hit_pips(duration: float = HIT_PULSE_SECONDS) -> void:
	_hit_pulse_duration = maxf(duration, 0.05)
	_hit_pulse_left = _hit_pulse_duration
	set_process(true)


func is_hit_pulse_active() -> bool:
	return _hit_pulse_left > 0.0


func get_hit_pulse_left() -> float:
	return _hit_pulse_left


func get_hit_pulse_duration() -> float:
	return _hit_pulse_duration


func _update_hit_pips_visibility() -> void:
	if _hit_pips == null:
		return
	# Pausing covers the guide, mechanic popup and pause page; completion and
	# recovery are explicit.  The recovery cover is checked directly so a direct
	# alpha test hides the bar too.
	var should_show: bool = (
		_pips_visible
		and not get_tree().paused
		and not _completion_visible
		and not _pause_visible
		and not (_recovery_cover != null and _recovery_cover.visible)
	)
	if should_show:
		if not _hit_pips.visible:
			_hit_pips.visible = true
			_hit_pips.modulate.a = 0.0
			var tween: Tween = create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_property(_hit_pips, "modulate:a", 1.0, 0.15)
		return
	_hit_pips.visible = false
	_hit_pips.scale = Vector2.ONE


## Pause, guide/popup, recovery and completion own the screen: hide the
## chapter/objective/event row, boss bar and health group; restore on close.
func _update_chrome_visibility() -> void:
	var hidden: bool = (
		_pause_visible
		or _completion_visible
		or (get_tree() != null and get_tree().paused)
		or (_recovery_cover != null and _recovery_cover.visible)
	)
	if _header != null:
		_header.set_chrome_visible(not hidden)
	if _boss_bar != null:
		_boss_bar.set_modal_suppressed(hidden)
	_update_hit_pips_visibility()


func _update_hit_pulse(delta: float) -> void:
	if _hit_pips == null:
		return
	if _hit_pulse_left <= 0.0:
		if _hit_pips.scale != Vector2.ONE:
			_hit_pips.scale = Vector2.ONE
		return
	_hit_pulse_left = maxf(_hit_pulse_left - delta, 0.0)
	var progress: float = 1.0 - _hit_pulse_left / _hit_pulse_duration
	var amount: float = (1.0 - progress) * absf(sin(progress * PI * 3.0 + PI * 0.5))
	# Only the bar pulses; the 生命值 label keeps its 12 px scale.
	_hit_pips.pivot_offset = _hit_pips.size * 0.5
	_hit_pips.scale = Vector2.ONE * (1.0 + HIT_PULSE_SCALE * amount)
	if _hit_pulse_left <= 0.0:
		_hit_pips.scale = Vector2.ONE


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
	CompletionEmblem.attach_to(panel)

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
	_completion_primary.pressed.connect(_on_completion_primary_pressed)
	panel.add_child(_completion_primary)

	_completion_replay = _menu_button(
		"重玩本关", Vector2(110.0, 126.0), Vector2(180.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_completion_replay.name = "CompletionReplay"
	_completion_replay.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(_completion_replay)

	_completion_note = _label(
		"本章结算 · 暂停菜单可查看操作",
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
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
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

	# The four existing entries keep their order; 操作 is appended so the real
	# route reference stays one click/F away without adding a settings page.
	_pause_controls = _menu_button(
		"操作", Vector2(76.0, 192.0), Vector2(100.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_pause_controls.name = "ControlsButton"
	_pause_controls.pressed.connect(_on_controls_pressed)
	panel.add_child(_pause_controls)

	_manual_button = _menu_button(
		"手册", Vector2(184.0, 192.0), Vector2(100.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_manual_button.name = "ManualButton"
	_manual_button.pressed.connect(_on_manual_pressed)
	panel.add_child(_manual_button)

	_pause_note = _label(
		"返回主界面不保存本章进度",
		Vector2(0.0, 220.0), Vector2(360.0, 14.0), 12, DIM
	)
	_pause_note.name = "PauseNote"
	_pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_pause_note)

	_build_pause_controls(panel)

	var chain: Array[PixelMenuButton] = _pause_chain()
	for index: int in range(chain.size()):
		var current: PixelMenuButton = chain[index]
		var next: PixelMenuButton = chain[(index + 1) % chain.size()]
		var previous: PixelMenuButton = chain[(index - 1 + chain.size()) % chain.size()]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(previous)


## One-page 12 px control reference inside the existing 360x236 pause panel.
## It replaces the five buttons and footnote while open; Esc, F or the in-panel
## 返回 button closes it and returns to the unchanged pause menu.
func _build_pause_controls(panel: Panel) -> void:
	_pause_controls_root = Control.new()
	_pause_controls_root.name = "PauseControls"
	_pause_controls_root.position = Vector2(0.0, 56.0)
	_pause_controls_root.size = Vector2(360.0, 174.0)
	_pause_controls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_controls_root.visible = false
	panel.add_child(_pause_controls_root)

	var header: Label = _label(
		PAUSE_CONTROLS_HEADER, Vector2(0.0, 0.0), Vector2(360.0, 14.0), 12, CYAN
	)
	header.name = "ControlsHeader"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_controls_root.add_child(header)
	_pause_controls_labels.append(header)

	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(40.0, 16.0)
	divider.size = Vector2(280.0, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.35)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_controls_root.add_child(divider)

	for index: int in range(PAUSE_CONTROLS_ROWS.size()):
		var row: Array = PAUSE_CONTROLS_ROWS[index]
		var row_y: float = 24.0 + float(index) * 18.0
		var keys_label: RichTextLabel = _keys_label(
			String(row[1]), Vector2(54.0, row_y), Vector2(110.0, 16.0)
		)
		_pause_controls_root.add_child(keys_label)
		_pause_controls_labels.append(keys_label)
		var name_label: Label = _label(
			String(row[0]), Vector2(178.0, row_y), Vector2(128.0, 16.0), 12, MUTED
		)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_pause_controls_root.add_child(name_label)
		_pause_controls_labels.append(name_label)

	var hint: Label = _label(
		"Esc / F 返回", Vector2(0.0, 134.0), Vector2(360.0, 14.0), 12, DIM
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_controls_root.add_child(hint)
	_pause_controls_labels.append(hint)

	_pause_controls_back = _menu_button(
		"返回", Vector2(76.0, 150.0), Vector2(208.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_pause_controls_back.name = "ControlsBackButton"
	_pause_controls_back.pressed.connect(close_controls)
	_pause_controls_root.add_child(_pause_controls_back)


func _on_controls_pressed() -> void:
	open_controls()


func _build_manual() -> void:
	_manual = MechanicManual.new()
	_manual.name = "MechanicManual"
	_manual.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_manual)


func _on_manual_pressed() -> void:
	open_manual()


func open_manual() -> void:
	if not _pause_visible or _controls_visible or _manual == null:
		return
	_manual.open()


func is_manual_open() -> bool:
	return _manual != null and _manual.is_open()


func get_manual() -> MechanicManual:
	return _manual


func get_manual_button() -> PixelMenuButton:
	return _manual_button


func open_controls() -> void:
	if not _pause_visible or _controls_visible:
		return
	_controls_visible = true
	_set_pause_menu_rows_visible(false)
	_pause_note.visible = false
	_pause_controls_root.visible = true
	call_deferred("_focus_controls_back")


func close_controls() -> void:
	if not _controls_visible:
		return
	_controls_visible = false
	_pause_controls_root.visible = false
	_set_pause_menu_rows_visible(true)
	_pause_note.visible = true
	if _pause_visible and _pause_controls != null:
		_pause_controls.grab_focus()


func _set_pause_menu_rows_visible(value: bool) -> void:
	for button: PixelMenuButton in [
		_pause_continue, _pause_restart, _pause_return, _pause_quit,
		_pause_controls, _manual_button,
	]:
		if button != null:
			button.visible = value


func _focus_controls_back() -> void:
	if _controls_visible and _pause_controls_back != null:
		_pause_controls_back.grab_focus()


func _pause_chain() -> Array[PixelMenuButton]:
	var chain: Array[PixelMenuButton] = [
		_pause_continue, _pause_restart, _pause_return, _pause_quit,
		_pause_controls, _manual_button,
	]
	return chain


func _activate_pause_entry(focused: PixelMenuButton) -> void:
	if focused == _pause_restart:
		restart_requested.emit()
	elif focused == _pause_return:
		title_requested.emit()
	elif focused == _pause_quit:
		quit_requested.emit()
	elif focused == _pause_controls:
		open_controls()
	elif focused == _manual_button:
		open_manual()
	else:
		resume_requested.emit()


# --- public state ----------------------------------------------------------

func set_polarity(positive: bool) -> void:
	if _header != null:
		_header.set_polarity(positive)


func get_affinity_icon() -> PolarityPhaseIcon:
	return _header.get_phase_icon() if _header != null else null


func get_affinity_icon_positive() -> bool:
	var icon: PolarityPhaseIcon = get_affinity_icon()
	return icon.is_positive() if icon != null else false


func is_affinity_text_visible() -> bool:
	return false


func get_affinity_icon_rect() -> Rect2:
	return _header.get_icon_rect() if _header != null else Rect2()


func set_player_hits(current_value: int, max_value: int = 2) -> void:
	if _hit_pips == null:
		return
	_hit_pips.set_state(current_value, max_value)
	_hit_pips.pivot_offset = _hit_pips.size * 0.5


func get_hit_pips_current() -> int:
	return _hit_pips.get_current() if _hit_pips != null else 0


func get_hit_pips_max() -> int:
	return _hit_pips.get_max() if _hit_pips != null else 0


func is_health_bar_visible() -> bool:
	return _hit_pips != null and _hit_pips.visible


## Compatibility name kept from the old heart row; the value is now the shared
## red health VALUE bar.
func get_hit_pips() -> PlayerHealthBar:
	return _hit_pips


## Old 12 px "生命值" word is gone; the heart icon is the only label.
func get_health_label() -> Label:
	return null


func set_boss_visible(value: bool) -> void:
	if _boss_bar != null:
		_boss_bar.set_active(value)


## Trial guard uses the existing three true-damage points, drawn as three red
## segments on the shared bar (no duplicate core diamonds).
func set_boss_state(core_current: int, core_max: int = 3) -> void:
	if _boss_bar != null:
		_boss_bar.set_bar_values(core_current, core_max, 0, 1)


func get_boss_bar() -> HudBossBar:
	return _boss_bar


func is_boss_bar_visible() -> bool:
	return _boss_bar != null and _boss_bar.is_bar_visible()


func set_objective(text_value: String) -> void:
	_subtitle = text_value
	if _header != null:
		_header.set_objective(text_value)


func show_event(text_value: String, seconds: float = 1.5) -> void:
	if _header == null:
		return
	_header.show_event(text_value, seconds)


func set_recovery_alpha(value: float) -> void:
	if _recovery_cover == null:
		return
	var alpha: float = clampf(value, 0.0, 1.0)
	_recovery_cover.visible = alpha > 0.0
	_recovery_cover.color = Color(0.0, 0.0, 0.0, alpha)
	_update_chrome_visibility()


## The opening film hands the screen back to live gameplay.  Show the real HUD
## and fade its chrome in from transparent.  Pause-process keeps the fade honest
## if a modal opens during the hand-off.
func fade_in_after_intro(seconds: float = 0.35) -> void:
	if _root == null:
		return
	if _intro_fade_tween != null and _intro_fade_tween.is_valid():
		_intro_fade_tween.kill()
	_root.modulate.a = 0.0
	_intro_fade_tween = create_tween()
	_intro_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_intro_fade_tween.tween_property(_root, "modulate:a", 1.0, maxf(seconds, 0.01))


func set_chrome_alpha(value: float) -> void:
	if _root != null:
		_root.modulate.a = clampf(value, 0.0, 1.0)


func get_chrome_alpha() -> float:
	return _root.modulate.a if _root != null else 0.0


func show_completion(value: bool, elapsed_seconds: float = 0.0) -> void:
	_completion_visible = value
	if _completion_overlay == null:
		return
	_completion_overlay.visible = value
	if _header != null:
		_header.clear_event()
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
	_update_chrome_visibility()


func show_pause(value: bool) -> void:
	if not value and _manual != null and _manual.is_open():
		_manual.close()
	_pause_visible = value
	if _pause_overlay == null:
		return
	_pause_overlay.visible = value
	if value:
		# Every fresh pause opens on the unchanged four-item menu, never on a
		# table left over from the previous pause.
		_set_controls_open_immediate(false)
		_release_completion_focus()
		_pause_tween = _play_reveal(_pause_tween, _pause_overlay, _pause_panel, _pause_panel_base)
		call_deferred("_focus_pause")
	else:
		_set_controls_open_immediate(false)
		_snap_reveal(_pause_tween, _pause_overlay, _pause_panel, _pause_panel_base)
		_pause_tween = null
		for button: PixelMenuButton in _pause_chain():
			button.release_focus()
		if _pause_controls_back != null:
			_pause_controls_back.release_focus()
		if _completion_visible:
			call_deferred("_focus_completion_primary")
	_update_chrome_visibility()


func _set_controls_open_immediate(value: bool) -> void:
	_controls_visible = value
	if _pause_controls_root != null:
		_pause_controls_root.visible = value
	_set_pause_menu_rows_visible(not value)
	if _pause_note != null:
		_pause_note.visible = not value


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

func get_header() -> HudObjective:
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


func get_pause_controls_button() -> PixelMenuButton:
	return _pause_controls


func get_pause_controls_back_button() -> PixelMenuButton:
	return _pause_controls_back


func is_controls_visible() -> bool:
	return _controls_visible


func has_controls_section() -> bool:
	return _pause_controls_root != null


func get_controls_text() -> String:
	var lines: Array[String] = []
	for row: Array in PAUSE_CONTROLS_ROWS:
		lines.append("%s  %s" % [
			KeyGlyph.plain(String(row[1])),
			String(row[0]),
		])
	return "\n".join(lines)


func get_control_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for control: Control in _pause_controls_labels:
		if control == null:
			continue
		if control is RichTextLabel:
			sizes.append(
				(control as RichTextLabel).get_theme_font_size("normal_font_size")
			)
		else:
			sizes.append(control.get_theme_font_size("font_size"))
	return sizes


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


## Completion-page-only label/action swap used by a hidden side run.  The pause
## page and game-over page keep their own 返回主界面 rows.
func set_completion_primary_action(text_value: String, continue_mainline: bool) -> void:
	_completion_primary_mainline = continue_mainline
	if _completion_primary != null:
		_completion_primary.text = text_value


func is_completion_primary_mainline() -> bool:
	return _completion_primary_mainline


func _on_completion_primary_pressed() -> void:
	if _completion_primary != null:
		_completion_primary.disabled = true
	if not CompletionMirrorFade.play(self, _emit_completion_primary):
		_emit_completion_primary()


## 0.5 s mirror ripple + black, then the real title/mainline hand-off.
func _emit_completion_primary() -> void:
	if _completion_primary_mainline:
		mainline_requested.emit()
		return
	title_requested.emit()


func get_completion_mirror_fade() -> CompletionMirrorFade:
	return get_node_or_null("CompletionMirrorFade") as CompletionMirrorFade


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


## Current event text, whether or not the 0.15 s fade-out has finished.
func get_event_text() -> String:
	return _header.get_event_text() if _header != null else ""


func is_event_visible() -> bool:
	return _header != null and _header.is_event_visible()
