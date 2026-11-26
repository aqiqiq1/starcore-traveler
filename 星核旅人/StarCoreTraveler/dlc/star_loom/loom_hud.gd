class_name LoomHUD
extends CanvasLayer

## Compact HUD for 星核织机.
##
## One top-left chapter/objective row, shared 20x20 phase icon, fixed lower-left
## three-cell red health bar, and the shared 360x16 boss bar with the run's
## three life hearts underneath (no 9/10 px label row, no node/core icon strip,
## no second event line).  The boss bar's stage / node / core groups carry the
## only persistent state.  The completion page, shared four-item DLC pause page
## and game-over page remain the modal panels and hide all HUD chrome.

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
const COMPLETION_NOTE: String = "本章结算 · 暂停菜单可查看操作"
const COMPLETION_PANEL_POSITION: Vector2 = Vector2(120.0, 75.0)
const COMPLETION_PANEL_SIZE: Vector2 = Vector2(400.0, 210.0)
const PAUSE_PANEL_POSITION: Vector2 = Vector2(140.0, 56.0)
const PAUSE_PANEL_SIZE: Vector2 = Vector2(360.0, 236.0)
const GAME_OVER_PANEL_POSITION: Vector2 = Vector2(140.0, 75.0)
const GAME_OVER_PANEL_SIZE: Vector2 = Vector2(360.0, 210.0)
const GAME_OVER_TITLE: String = "生命耗尽"
const LIFE_FILLED: Color = Color("#ef6b6b")
## The player origin is at the feet; the visible body centre is about 20 px up.
## Lifting 34 px from that centre lands the health meter just above the head.
const PLAYER_HIT_BODY_OFFSET: float = 20.0
const PLAYER_HIT_LIFT: float = 34.0
## Fixed HUD corner for the health VALUE; never floats over the character.
const HEALTH_POSITION: Vector2 = Vector2(14.0, 324.0)
const HEALTH_LABEL_POSITION: Vector2 = Vector2(14.0, 310.0)

var _root: Control
var _header: HudObjective
var _boss_bar: HudBossBar
var _player_health_bar: LoomHealthBar
var _gear_edge: LoomEdgeWarning
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
var _game_over_overlay: ColorRect
var _game_over_panel: Panel
var _game_over_hearts: HitPips
var _game_over_retry: PixelMenuButton
var _game_over_title_button: PixelMenuButton
var _game_over_note: Label
var _font: Font
var _subtitle: String = ""
var _completion_visible: bool = false
var _pause_visible: bool = false
var _game_over_visible: bool = false
var _completion_reveal: UiReveal
var _pause_reveal: UiReveal
var _game_over_reveal: UiReveal
var _player: Node2D = null
var _player_hit_suppress: Callable = Callable()
var _player_hit_pulse_left: float = 0.0
var _last_player_hits: int = 0


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
	_build_boss_bar()
	_build_player_hit_overlay()
	_build_gear_edge()
	_build_recovery_cover()
	_build_completion()
	_build_pause()
	_build_game_over()
	_completion_reveal = UiReveal.new()
	_completion_reveal.setup(
		self, _completion_overlay, _completion_overlay, _completion_panel,
		COMPLETION_PANEL_POSITION
	)
	_pause_reveal = UiReveal.new()
	_pause_reveal.setup(
		self, _pause_overlay, _pause_overlay, _pause_panel, PAUSE_PANEL_POSITION
	)
	_game_over_reveal = UiReveal.new()
	_game_over_reveal.setup(
		self, _game_over_overlay, _game_over_overlay, _game_over_panel,
		GAME_OVER_PANEL_POSITION
	)
	set_polarity(false)
	set_objective(DEFAULT_OBJECTIVE)
	set_boss_state(1, 3, 2, 0, 3, false, 0, 3, 3, 3)
	show_completion(false, 0.0)
	show_pause(false)
	show_game_over(false)
	_root.modulate.a = 0.0
	var intro_tween: Tween = create_tween()
	intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro_tween.tween_property(_root, "modulate:a", 1.0, 0.15)


## Page keyboard fallback.  The pause page's four buttons form a closed ring:
## 继续游戏 -> 重新开始本章 -> 返回主界面 -> 退出游戏 -> 继续游戏.  The game
## over page uses its own two-button ring.
func _unhandled_input(event: InputEvent) -> void:
	if not (_pause_visible or _game_over_visible) or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)
	if _game_over_visible:
		_handle_game_over_key(code)
		return
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


func _handle_game_over_key(code: int) -> void:
	var chain: Array[PixelMenuButton] = [
		_game_over_retry, _game_over_title_button,
	]
	var focused: Control = get_viewport().gui_get_focus_owner()
	var index: int = chain.find(focused as PixelMenuButton)
	if code == int(KEY_ENTER) or code == int(KEY_KP_ENTER) or code == int(KEY_SPACE):
		get_viewport().set_input_as_handled()
		if index == 1:
			title_requested.emit()
		else:
			restart_requested.emit()
	elif code == int(KEY_DOWN) or code == int(KEY_TAB):
		index = 0 if index < 0 else (index + 1) % chain.size()
		chain[index].grab_focus()
		get_viewport().set_input_as_handled()
	elif code == int(KEY_UP):
		index = chain.size() - 1 if index < 0 else (index - 1 + chain.size()) % chain.size()
		chain[index].grab_focus()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# The HUD is PROCESS_MODE_ALWAYS, so the fixed health bar hides correctly
	# even while a guide/popup/pause page has paused the tree.
	_update_player_hit_overlay(delta)
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
	_header = HudObjective.new()
	_header.name = "HudObjective"
	_root.add_child(_header)
	_header.configure(TITLE, DEFAULT_OBJECTIVE, _font)
	_header.set_polarity(true)


## Shared 360x16 boss bar.  The stage cells are the three loom stages, the two
## node diamonds are the live nodes, the three core diamonds are accepted core
## hits, and the three life hearts sit centred under the bar (no text count).
func _build_boss_bar() -> void:
	_boss_bar = HudBossBar.new()
	_boss_bar.name = "BossBar"
	_boss_bar.configure("织机", 3, 3, _font)
	_boss_bar.position = HudBossBar.HUD_POSITION
	_root.add_child(_boss_bar)
	_boss_bar.set_nodes(2, 2, true)
	_boss_bar.set_lives(3, 3, true)
	_boss_bar.set_active(false)


## Three-cell red health VALUE fixed at the lower-left HUD corner, so it never
## covers the character.  The level supplies the suppression predicate (pause,
## guide, popup, recovery, completion, game over); the heart icon is the only
## label, no "生命值" word.
func _build_player_hit_overlay() -> void:
	_player_health_bar = LoomHealthBar.new()
	_player_health_bar.name = "PlayerHealthBar"
	_player_health_bar.max_segments = 3
	_player_health_bar.set_state(3, 3)
	_player_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_health_bar.visible = false
	_player_health_bar.position = HEALTH_POSITION
	_root.add_child(_player_health_bar)
	_player_health_bar.pivot_offset = _player_health_bar.size * 0.5


func bind_player_overhead(player: Node2D, suppress_check: Callable = Callable()) -> void:
	_player = player
	_player_hit_suppress = suppress_check


func _update_player_hit_overlay(delta: float) -> void:
	if _player_health_bar == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player_health_bar.visible = false
		return
	var suppressed: bool = (
		_player_hit_suppress.is_valid() and bool(_player_hit_suppress.call())
	)
	var chrome_hidden: bool = (
		_pause_visible
		or _completion_visible
		or _game_over_visible
		or (get_tree() != null and get_tree().paused)
		or (_recovery_cover != null and _recovery_cover.visible)
	)
	if suppressed or chrome_hidden:
		_player_health_bar.visible = false
		_player_health_bar.scale = Vector2.ONE
		_player_hit_pulse_left = 0.0
		return
	_player_health_bar.position = HEALTH_POSITION
	if not _player_health_bar.visible:
		_player_health_bar.visible = true
		_player_health_bar.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(_player_health_bar, "modulate:a", 1.0, 0.15)
	if _player_hit_pulse_left > 0.0:
		_player_hit_pulse_left = maxf(_player_hit_pulse_left - delta, 0.0)
		var progress: float = 1.0 - _player_hit_pulse_left
		var bump: float = sin(progress * PI)
		_player_health_bar.scale = Vector2.ONE * (1.0 + 0.32 * bump)
	else:
		_player_health_bar.scale = Vector2.ONE


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


## Game over page: a heart row (empty at 0), 生命耗尽, and two real buttons.
## It is deliberately smaller than the completion page and has no prose count.
func _build_game_over() -> void:
	_game_over_overlay = ColorRect.new()
	_game_over_overlay.name = "GameOverOverlay"
	_game_over_overlay.position = Vector2.ZERO
	_game_over_overlay.size = VIEW_SIZE
	_game_over_overlay.color = Color(0.006, 0.014, 0.018, 0.76)
	_game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over_overlay.visible = false
	_root.add_child(_game_over_overlay)

	var panel: Panel = Panel.new()
	panel.name = "GameOverPanel"
	panel.position = GAME_OVER_PANEL_POSITION
	panel.size = GAME_OVER_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#a8463f")
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	_game_over_overlay.add_child(panel)
	_game_over_panel = panel

	var title: Label = _label(
		GAME_OVER_TITLE, Vector2(0.0, 12.0), Vector2(360.0, 34.0), 24, GOLD
	)
	title.name = "GameOverTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	_game_over_hearts = HitPips.new()
	_game_over_hearts.name = "GameOverHearts"
	_game_over_hearts.kind = HitPips.Kind.HEART
	_game_over_hearts.max_pips = 3
	_game_over_hearts.pip_size = 12.0
	_game_over_hearts.gap = 6.0
	_game_over_hearts.filled_color = LIFE_FILLED
	_game_over_hearts.empty_color = Color(0.58, 0.32, 0.34, 0.95)
	# HitPips draws 7x6 pixel art; scale the whole control so the game over icon
	# is a readable 14x12 heart row, not three specks.
	_game_over_hearts.position = Vector2(132.0, 52.0)
	_game_over_hearts.scale = Vector2(2.0, 2.0)
	panel.add_child(_game_over_hearts)
	_game_over_hearts.set_state(0, 3)

	_game_over_retry = _menu_button(
		"重试本章", Vector2(76.0, 84.0), Vector2(208.0, 28.0),
		PixelMenuButton.Variant.STONE
	)
	_game_over_retry.name = "GameOverRetryButton"
	_game_over_retry.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(_game_over_retry)

	_game_over_title_button = _menu_button(
		"返回标题", Vector2(76.0, 120.0), Vector2(208.0, 24.0),
		PixelMenuButton.Variant.OPTION
	)
	_game_over_title_button.name = "GameOverTitleButton"
	_game_over_title_button.pressed.connect(func() -> void: title_requested.emit())
	panel.add_child(_game_over_title_button)

	_game_over_note = _label(
		"R 重试本章 · 生命重置为 3", Vector2(0.0, 164.0), Vector2(360.0, 16.0), 12, DIM
	)
	_game_over_note.name = "GameOverNote"
	_game_over_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_game_over_note)

	_chain_focus([_game_over_retry, _game_over_title_button], true)


# --- public state ----------------------------------------------------------

func set_polarity(positive: bool) -> void:
	if _header != null:
		_header.set_polarity(positive)


func set_objective(text_value: String) -> void:
	_subtitle = text_value
	if _header != null:
		_header.set_objective(text_value)


## Maps the existing loom state onto the shared bar.  Stage is 1-based; core
## cells fill with the accepted core hits; the red bar shows remaining core
## health.  The three life hearts sit under the bar and keep their own count.
func set_boss_state(
	stage: int, stage_max: int, nodes_alive: int,
	core_hits: int, core_needed: int, exposed: bool,
	player_hits: int = 0, hit_limit: int = 3,
	lives: int = 3, life_limit: int = 3
) -> void:
	var phase_index: int = clampi(stage - 1, 0, maxi(stage_max - 1, 0))
	var needed: int = maxi(core_needed, 1)
	var remaining: int = clampi(needed - core_hits, 0, needed)
	if _boss_bar != null:
		_boss_bar.set_bar_values(
			core_hits if exposed else 0, needed, phase_index, maxi(stage_max, 1),
			float(remaining) / float(needed)
		)
		_boss_bar.set_nodes(nodes_alive, 2, true)
		_boss_bar.set_lives(lives, life_limit, true)
	if _player_health_bar != null:
		var hit_increased: bool = player_hits > _last_player_hits
		_last_player_hits = player_hits
		var health_value: int = clampi(hit_limit - player_hits, 0, hit_limit)
		_player_health_bar.set_state(health_value, hit_limit)
		_player_health_bar.queue_redraw()
		if hit_increased and player_hits > 0:
			# A single 1.0 s sine pulse, scaled around the row's centre.
			_player_hit_pulse_left = 1.0
			_player_health_bar.pivot_offset = _player_health_bar.size * 0.5


func set_boss_visible(value: bool) -> void:
	if _boss_bar != null:
		_boss_bar.set_active(value)


func is_boss_visible() -> bool:
	return _boss_bar != null and _boss_bar.is_bar_visible()


func get_boss_bar() -> HudBossBar:
	return _boss_bar


func set_gear_warning(active: bool, progress: float = 0.0) -> void:
	if _gear_edge != null:
		_gear_edge.set_warning(active, progress)


func is_gear_warning_visible() -> bool:
	return _gear_edge != null and _gear_edge.is_active()


func show_event(text_value: String, seconds: float = 1.5) -> void:
	if _header != null:
		_header.show_event(text_value, seconds)


func hide_event() -> void:
	if _header != null:
		_header.clear_event()


func set_recovery_alpha(value: float) -> void:
	if _recovery_cover == null:
		return
	var alpha: float = clampf(value, 0.0, 1.0)
	_recovery_cover.visible = alpha > 0.0
	_recovery_cover.color = Color(0.0, 0.0, 0.0, alpha)
	_update_chrome_visibility()


## Pause / guide / popup / recovery / completion / game over hide the chapter
## row, boss bar (and its life hearts) and the fixed health bar.
func _update_chrome_visibility() -> void:
	var hidden: bool = (
		_pause_visible
		or _completion_visible
		or _game_over_visible
		or (get_tree() != null and get_tree().paused)
		or (_recovery_cover != null and _recovery_cover.visible)
	)
	if _header != null:
		_header.set_chrome_visible(not hidden)
	if _boss_bar != null:
		_boss_bar.set_modal_suppressed(hidden)
	if hidden and _player_health_bar != null:
		_player_health_bar.visible = false


func show_completion(value: bool, elapsed_seconds: float = 0.0) -> void:
	_completion_visible = value
	if _header != null:
		_header.clear_event()
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
	_update_chrome_visibility()


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
		_update_chrome_visibility()
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
		_update_chrome_visibility()
		if _completion_visible:
			call_deferred("_focus_completion")


func show_game_over(value: bool, lives: int = 0) -> void:
	var was_visible: bool = _game_over_visible
	_game_over_visible = value
	if _game_over_overlay == null:
		return
	if _game_over_hearts != null:
		_game_over_hearts.set_state(lives, 3)
	if value:
		if _game_over_reveal != null:
			_game_over_reveal.play_open()
		else:
			_game_over_overlay.visible = true
		_update_chrome_visibility()
		call_deferred("_focus_game_over")
	else:
		if _game_over_reveal != null:
			if was_visible:
				_game_over_reveal.play_close()
			else:
				_game_over_reveal.snap_closed()
		else:
			_game_over_overlay.visible = false
		if _game_over_retry != null:
			_game_over_retry.release_focus()
		if _game_over_title_button != null:
			_game_over_title_button.release_focus()
		_update_chrome_visibility()


func _focus_pause() -> void:
	if _pause_visible and _pause_continue != null:
		_pause_continue.grab_focus()


func _focus_completion() -> void:
	if _completion_visible and _completion_primary != null:
		_completion_primary.grab_focus()


func _focus_game_over() -> void:
	if _game_over_visible and _game_over_retry != null:
		_game_over_retry.grab_focus()


func _format_time(seconds: float) -> String:
	var total: int = maxi(int(floor(seconds)), 0)
	return "%02d:%02d" % [total / 60, total % 60]


# --- test / capture accessors ---------------------------------------------

func get_header() -> HudObjective:
	return _header


func get_title_text() -> String:
	return _header.get_title_text() if _header != null else TITLE


func get_objective_text() -> String:
	return _subtitle


func get_affinity_text() -> String:
	return _header.get_affinity_text() if _header != null else ""


# The old four icon rows are gone; these compatibility names expose the shared
# boss bar data so older audits fail loudly if they still expect the old row.
func get_stage_pips() -> HitPips:
	return null


func get_node_pips() -> HitPips:
	return null


func get_core_pips() -> HitPips:
	return null


func get_player_health_bar() -> LoomHealthBar:
	return _player_health_bar


func get_health_value() -> int:
	return _player_health_bar.get_current() if _player_health_bar != null else 0


func get_health_max() -> int:
	return _player_health_bar.get_max() if _player_health_bar != null else 0


func is_health_bar_visible() -> bool:
	return _player_health_bar != null and _player_health_bar.visible


func get_player_hit_position() -> Vector2:
	return _player_health_bar.position if _player_health_bar != null else Vector2.ZERO


func get_player_hit_pulse_left() -> float:
	return _player_hit_pulse_left


func get_life_pips() -> HitPips:
	return null


func get_life_bar_current() -> int:
	return _boss_bar.get_lives_current() if _boss_bar != null else 0


func get_life_bar_max() -> int:
	return _boss_bar.get_lives_max() if _boss_bar != null else 0


func get_stage_icon() -> LoomStatusIcon:
	return null


func get_status_labels() -> Dictionary:
	return {}


func get_status_label_texts() -> Array[String]:
	return []


func get_status_label_font_size() -> int:
	return 0


func get_stage_label() -> Label:
	return null


func get_node_label() -> Label:
	return null


func get_core_label() -> Label:
	return null


func get_life_label() -> Label:
	return null


func get_phase_icon() -> PolarityPhaseIcon:
	return _header.get_phase_icon() if _header != null else null


func get_phase_icon_state() -> String:
	return _header.get_phase_kind() if _header != null else ""


func get_phase_icon_rect() -> Rect2:
	return _header.get_icon_rect() if _header != null else Rect2()


## The top row has no hit group any more; the fixed bar is lower-left.
func has_top_hit_group() -> bool:
	return false


func is_phase_text_hidden() -> bool:
	return true


## The permanent counter row is icon-only; this returns false for the old
## "受击 0 / 3" text row.  Kept as an explicit assertion hook.
func shows_text_counters() -> bool:
	return false


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


func is_game_over_visible() -> bool:
	return _game_over_visible


func get_game_over_panel_rect() -> Rect2:
	return Rect2(GAME_OVER_PANEL_POSITION, GAME_OVER_PANEL_SIZE)


func get_game_over_hearts() -> HitPips:
	return _game_over_hearts


func get_game_over_retry_button() -> PixelMenuButton:
	return _game_over_retry


func get_game_over_title_button() -> PixelMenuButton:
	return _game_over_title_button


func get_game_over_title_text() -> String:
	return GAME_OVER_TITLE


func get_game_over_note_text() -> String:
	return _game_over_note.text if _game_over_note != null else ""


func get_game_over_panel_alpha() -> float:
	return _game_over_reveal.get_shade_alpha() if _game_over_reveal != null else 0.0


func is_game_over_button_focused() -> bool:
	if not _game_over_visible:
		return false
	var focused: Control = get_viewport().gui_get_focus_owner()
	return focused != null and (
		focused == _game_over_retry or focused == _game_over_title_button
	)


func get_recovery_cover() -> ColorRect:
	return _recovery_cover


func get_completion_title_label() -> Label:
	return _completion_title


func get_event_text() -> String:
	return _header.get_event_text() if _header != null else ""


func is_event_visible() -> bool:
	return _header != null and _header.is_event_visible()
