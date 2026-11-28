class_name Level01HUD
extends CanvasLayer

## Formal level HUD.  One top-left row (chapter 12 px warm white + one 12 px
## gold objective, events replace the objective over 0.15 s), one 20x20 phase
## icon at top-right, and the fixed lower-left red health bar.  It owns pause
## and first-level completion panels but no gameplay state.  Every modal page
## hides the HUD chrome and restores it with a 0.15 s fade.

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
var _header: HudObjective
var _health_bar: PlayerHealthBar
var _objective_base: String = "前往庭院出口"
var _opening_active: bool = false
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
var _chrome_fade_duration: float = 0.15
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
	_build_health_bar()
	_build_completion()
	set_polarity(true)
	set_pause_visible(false)
	show_completion(false)
	_root.modulate.a = 0.0
	var intro_tween: Tween = create_tween()
	intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro_tween.tween_property(_root, "modulate:a", 1.0, 0.15)


func _process(_delta: float) -> void:
	_update_chrome_visibility()


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
	label.add_theme_constant_override("outline_size", 1)
	return label


func _build_header() -> void:
	_header = CompactLevelHeader.new()
	_header.name = "HudObjective"
	_root.add_child(_header)
	_header.configure("断桥庭院", _objective_base, _font)
	_header.set_polarity(true)


## Fixed lower-left red bar, exactly the same group as every chapter.  The
## base story levels do not have an enemy yet, but the HUD keeps a full bar so
## the layout never changes between chapters.
func _build_health_bar() -> void:
	_health_bar = PlayerHealthBar.new()
	_health_bar.name = "PlayerHealthBar"
	_health_bar.max_segments = 3
	_health_bar.position = PlayerHealthBar.HUD_POSITION
	_health_bar.set_state(3, 3)
	_root.add_child(_health_bar)


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
	CompletionEmblem.attach_to(panel)

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
	_completion_primary.pressed.connect(_on_completion_primary_pressed)
	panel.add_child(_completion_primary)

	_completion_replay = _menu_button("重玩本关", Vector2(32.0, 126.0), Vector2(160.0, 24.0), PixelMenuButton.Variant.OPTION)
	_completion_replay.pressed.connect(func() -> void: replay_requested.emit())
	panel.add_child(_completion_replay)

	_completion_return = _menu_button("返回主界面", Vector2(208.0, 126.0), Vector2(160.0, 24.0), PixelMenuButton.Variant.OPTION)
	_completion_return.pressed.connect(_on_completion_return_pressed)
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
	if _header != null and not _opening_active and not _completion_active:
		_header.set_objective(text_value)


## Opening-film state: the whole chrome row (chapter/objective/icon) and the
## health bar are hidden from the first bar frame until control is handed back.
## A mechanism hint raised during the film is discarded, never held for the
## hand-off: after control returns the player must be near the device themselves.
func set_opening_active(value: bool, fade_duration: float = 0.15) -> void:
	var was_opening_active: bool = _opening_active
	_opening_active = value
	if value:
		_chrome_fade_duration = 0.15
		if _header != null:
			_header.clear_event()
	else:
		_chrome_fade_duration = clampf(fade_duration, 0.0, 1.0)
		_restore_objective_after_opening()
	_update_chrome_visibility()
	if not value and _header != null and was_opening_active:
		_header.fade_in(_chrome_fade_duration)


func _restore_objective_after_opening() -> void:
	if _header == null:
		return
	_header.set_objective(_objective_base)


func show_toast(text_value: String, duration: float = 1.6) -> void:
	if _header == null:
		return
	if text_value.is_empty():
		_header.clear_event()
		if not _opening_active and not _completion_active:
			_header.set_objective(_objective_base)
		return
	if _opening_active:
		# Hints produced behind the opening film are dropped, not queued.  The
		# old pending slot made a distant gate line pop on hand-off.
		return
	_header.show_event(text_value, clampf(duration, 0.2, 2.6))


func set_pause_visible(value: bool) -> void:
	# The real pause page is owned by PauseMenu; this HUD only hides its chrome
	# while the page/guide/popup is up.
	_pause_visible = value
	_update_chrome_visibility()


func show_completion(value: bool, elapsed_seconds: float = 0.0) -> void:
	if _completion_overlay == null:
		return
	_completion_overlay.visible = value
	_completion_active = value
	if value:
		_completion_title.text = "第一关完成 · 用时 %s" % _format_time(elapsed_seconds)
		_play_completion_reveal()
		_header.clear_event()
		call_deferred("focus_completion_primary")
	else:
		release_completion_focus()
		if not _opening_active:
			_header.set_objective(_objective_base)
		if not value:
			_stop_completion_reveal()
	_update_chrome_visibility()
	if _completion_count_label != null:
		_completion_count_label.text = "本关结算 · Esc 可打开暂停菜单" if value else ""


func _format_time(seconds: float) -> String:
	var total: int = maxi(int(floor(seconds)), 0)
	return "%02d:%02d" % [total / 60, total % 60]


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


## Both leaving rows hand the frame to the shared 0.5 s mirror ripple + black
## before the real scene change.  重玩本关 stays in place and keeps its old
## immediate route.
func _on_completion_primary_pressed() -> void:
	if _completion_primary != null:
		_completion_primary.disabled = true
	if not CompletionMirrorFade.play(self, _emit_next_level):
		_emit_next_level()


func _emit_next_level() -> void:
	next_level_requested.emit()


func _on_completion_return_pressed() -> void:
	if _completion_return != null:
		_completion_return.disabled = true
	if not CompletionMirrorFade.play(self, _emit_return_to_menu):
		_emit_return_to_menu()


func _emit_return_to_menu() -> void:
	return_to_menu_requested.emit()


func get_completion_mirror_fade() -> CompletionMirrorFade:
	return get_node_or_null("CompletionMirrorFade") as CompletionMirrorFade


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
	return _header.get_event_text() if _header != null else ""


func get_objective_text() -> String:
	return _objective_base


func is_objective_visible() -> bool:
	return _header != null and _header.is_chrome_visible()


func get_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for node: Node in _root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


func is_toast_visible() -> bool:
	return _header != null and _header.is_event_visible()


## Pause / guide / mechanic popup / opening film / completion all hide the
## chapter, objective, event and health bar.  Restoring fades the row in.
func _update_chrome_visibility() -> void:
	var hidden: bool = (
		_pause_visible
		or _completion_active
		or _opening_active
		or (get_tree() != null and get_tree().paused)
	)
	if _header != null:
		_header.set_chrome_visible(not hidden)
	_set_health_visible(not hidden)


func _set_health_visible(value: bool) -> void:
	if _health_bar == null:
		return
	if value:
		if _health_bar.visible:
			return
		_health_bar.visible = true
		_health_bar.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(_health_bar, "modulate:a", 1.0, _chrome_fade_duration)
		return
	_health_bar.visible = false


func get_player_health_bar() -> PlayerHealthBar:
	return _health_bar


func is_health_bar_visible() -> bool:
	return _health_bar != null and _health_bar.visible


func get_health_bar_rect() -> Rect2:
	if _health_bar == null:
		return Rect2()
	return Rect2(_health_bar.position, _health_bar.size)


func is_pause_visible() -> bool:
	return _pause_visible


func is_completion_visible() -> bool:
	return _completion_overlay != null and _completion_overlay.visible


func get_completion_text() -> String:
	return _completion_title.text if _completion_title != null else ""


## The old permanent bottom controls legend is gone; pause shows the bindings.
func get_controls_text() -> String:
	return "移动、奔跑、跳跃与换相都在暂停页。"
