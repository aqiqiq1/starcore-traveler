class_name L3HUD
extends CanvasLayer

## L3-only low HUD after the play-test: one top-left chapter/objective row, the
## shared 20x20 phase icon, a transient world-space direction guide, small
## object-bound E text, the fixed lower-left red health bar and the shared
## 360x16 guard boss bar.  No task/core black panel, no second event row, no
## full-width toast bar.  The completion page and the shared pause menu remain
## the only modal panels; all of them hide the HUD chrome.

signal replay_requested
signal return_to_menu_requested

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const GOLD: Color = Color("#f4cd63")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DIM: Color = Color("#728889")
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

var _root: Control
var _header: HudObjective
var _objective_base: String = ""
var _control_hint: Label = null
var _control_left: float = 0.0
var _guide: L3Guide
## Shared 360x16 boss bar for the L3 guard.
var _boss_bar: HudBossBar
## Fixed lower-left health VALUE bar (shared with every chapter that has an
## enemy).  Hits taken are mirrored here; the old overhead talisman shards are
## no longer drawn by L3Guide.
var _health_bar: PlayerHealthBar
var _hits: int = 0
## Full-screen recovery cover. It sits above the ordinary HUD (header,
## objective, guide, prompts) but below the completion page, while the separate
## pause CanvasLayer (layer 16) stays above it.
var _recovery_cover: ColorRect
var _completion_overlay: ColorRect
var _completion_panel: Panel
var _completion_panel_base: Vector2 = Vector2.ZERO
var _completion_tween: Tween
var _completion_title: Label
var _completion_subtitle: Label
var _completion_hint: Label
var _completion_primary: PixelMenuButton
var _completion_replay: PixelMenuButton
var _completion_active: bool = false
var _pause_visible: bool = false
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_font = _load_font()
	_root = Control.new()
	_root.name = "Level03HUDRoot"
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_header()
	_build_boss_bar()
	_build_guide()
	_build_health_bar()
	_build_recovery_cover()
	_build_completion()
	set_polarity(true)
	set_objective("送核入符石仓")
	set_hits(0)
	set_pause_visible(false)
	show_completion(false)
	_root.modulate.a = 0.0
	var intro_tween: Tween = create_tween()
	intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro_tween.tween_property(_root, "modulate:a", 1.0, 0.15)


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


func _build_header() -> void:
	_header = CompactLevelHeader.new()
	_header.name = "HudObjective"
	_root.add_child(_header)
	_header.configure("断桥外郭", "送核入符石仓", _font)
	_header.set_polarity(true)


func _build_boss_bar() -> void:
	_boss_bar = HudBossBar.new()
	_boss_bar.name = "BossBar"
	_boss_bar.configure("守卫", 3, 1, _font)
	_boss_bar.position = HudBossBar.HUD_POSITION
	_root.add_child(_boss_bar)


func _build_guide() -> void:
	_guide = L3Guide.new()
	_guide.name = "WorldGuide"
	_guide.position = Vector2.ZERO
	_guide.size = VIEW_SIZE
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_guide)


## Two-segment red bar fixed at (14,324), with the 10x10 heart at its left.
## It is display-only and sits under the recovery cover/completion page, never
## over the player, and never prints a "生命值" word.
func _build_health_bar() -> void:
	_health_bar = PlayerHealthBar.new()
	_health_bar.name = "PlayerHealthBar"
	_health_bar.max_segments = 2
	_health_bar.position = PlayerHealthBar.HUD_POSITION
	_health_bar.set_state(2, 2)
	_root.add_child(_health_bar)
	_update_chrome_visibility()


## The recovery cover is a plain black rectangle owned by this HUD. The level
## drives its alpha; the HUD itself never starts or times the transition. It is
## inserted after the guide and before the completion page so the normal HUD is
## covered while the pause menu (separate layer 16) and a rare completion page
## remain readable.
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
	_completion_panel = panel
	_completion_panel_base = panel.position

	var title: Label = _label("第三关完成", Vector2(0.0, 12.0), Vector2(400.0, 34.0), 24, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	_completion_title = title
	var subtitle: Label = _label("断桥外郭 · 城门在望", Vector2(0.0, 50.0), Vector2(400.0, 18.0), 12, TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)
	_completion_subtitle = subtitle
	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(70.0, 74.0)
	divider.size = Vector2(260.0, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.5)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	_completion_primary = _menu_button("返回主界面", Vector2(110.0, 86.0), Vector2(180.0, 28.0), PixelMenuButton.Variant.STONE)
	_completion_primary.pressed.connect(func() -> void: return_to_menu_requested.emit())
	panel.add_child(_completion_primary)
	_completion_replay = _menu_button("重玩本关", Vector2(120.0, 126.0), Vector2(160.0, 24.0), PixelMenuButton.Variant.OPTION)
	_completion_replay.pressed.connect(func() -> void: replay_requested.emit())
	panel.add_child(_completion_replay)
	var completion_footer: Label = _label(
		"本章结算 · 暂停菜单可查看操作", Vector2(0.0, 158.0), Vector2(400.0, 16.0), 12, DIM
	)
	completion_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(completion_footer)
	_completion_hint = null
	_completion_primary.focus_next = _completion_primary.get_path_to(_completion_replay)
	_completion_primary.focus_previous = _completion_primary.get_path_to(_completion_replay)
	_completion_replay.focus_next = _completion_replay.get_path_to(_completion_primary)
	_completion_replay.focus_previous = _completion_replay.get_path_to(_completion_primary)


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


func setup_player(player: L3Player) -> void:
	if _guide != null:
		_guide.setup(player)


func set_polarity(positive: bool) -> void:
	if _header != null:
		_header.set_polarity(positive)


func set_objective(text_value: String) -> void:
	_objective_base = text_value
	if _header != null:
		_header.set_objective(text_value)


func set_guide(target_world: Vector2, stage_key: String) -> void:
	if _guide != null:
		_guide.set_target(target_world, stage_key)


func set_combat(value: bool) -> void:
	if _guide != null:
		_guide.set_combat(value)


func set_prompt(text_value: String, world_position: Vector2, visible_value: bool) -> void:
	if _guide != null:
		_guide.set_prompt(text_value, world_position, visible_value)


func set_boss_visible(value: bool) -> void:
	if _boss_bar != null:
		_boss_bar.set_active(value)


## Guard HP is the existing three true-damage points; keep those numbers.  The
## shared bar shows them as three red segments, with no second diamond row.
func set_boss_state(core_current: int, core_max: int) -> void:
	if _boss_bar != null:
		_boss_bar.set_bar_values(core_current, core_max, 0, 1)


func set_hits(value: int) -> void:
	_hits = clampi(value, 0, 2)
	if _guide != null:
		_guide.set_hits(_hits)
	if _health_bar != null:
		_health_bar.set_state(2 - _hits, 2)
		_health_bar.pivot_offset = _health_bar.size * 0.5


func show_event(text_value: String, duration: float = 1.4) -> void:
	# Event replaces the objective on the same one row for at most 2.6 s.
	if _header != null:
		_header.show_event(text_value, duration)
	if _guide != null:
		_guide.show_event(text_value, duration)


func show_control_hint(_duration: float = 3.0) -> void:
	# Compatibility no-op: the bottom control strip was removed from gameplay.
	_control_left = 0.0
	if _control_hint != null:
		_control_hint.visible = false


func _process(delta: float) -> void:
	_update_chrome_visibility()
	if _control_left > 0.0:
		_control_left = maxf(_control_left - delta, 0.0)
		if _control_left <= 0.0 and _control_hint != null:
			_control_hint.visible = false


## Pause, mechanic popup/guide, failure recovery and the completion page all
## own the screen; the top row, boss bar and health group are hidden rather than
## dimmed, then fade back in over 0.15 s.
func _update_chrome_visibility() -> void:
	var hidden: bool = (
		_pause_visible
		or _completion_active
		or (get_tree() != null and get_tree().paused)
		or (_recovery_cover != null and _recovery_cover.visible)
	)
	if _header != null:
		_header.set_chrome_visible(not hidden)
	if _boss_bar != null:
		_boss_bar.set_modal_suppressed(hidden)
	if _guide != null and not _completion_active:
		_guide.visible = not hidden and not _pause_visible
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
		tween.tween_property(_health_bar, "modulate:a", 1.0, 0.15)
		return
	_health_bar.visible = false


func show_world_text(text_value: String, world_position: Vector2, duration: float = 0.7) -> void:
	if _guide != null:
		_guide.show_world_text(text_value, world_position, duration)


## Stable short icon at a world anchor: "?" or "!" only.
func show_symbol(glyph: String, world_position: Vector2, duration: float = 0.8) -> void:
	if _guide != null:
		_guide.show_symbol(glyph, world_position, duration)


func set_pause_visible(value: bool) -> void:
	_pause_visible = value
	if _guide != null:
		_guide.visible = not value and not _completion_active
	_update_chrome_visibility()


func set_gameplay_visible(value: bool) -> void:
	visible = value


## Recovery cover alpha is always readable, even at 0, so tests and captures can
## assert the real value rather than only counting visible nodes.
func set_recovery_alpha(value: float) -> void:
	if _recovery_cover == null:
		return
	var alpha: float = clampf(value, 0.0, 1.0)
	_recovery_cover.color = Color(0.0, 0.0, 0.0, alpha)
	_recovery_cover.visible = alpha > 0.0001
	_recovery_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_chrome_visibility()


func get_recovery_alpha() -> float:
	return _recovery_cover.color.a if _recovery_cover != null else 0.0


func is_recovery_cover_visible() -> bool:
	return _recovery_cover != null and _recovery_cover.visible


func show_completion(value: bool, completion_count: int = 0) -> void:
	if _completion_overlay == null:
		return
	if _control_hint != null and value:
		_control_hint.visible = false
	_completion_active = value
	if _guide != null:
		_guide.visible = not value and not _pause_visible
	_completion_overlay.visible = value
	if value:
		# A failed scene change must never leave the page with dead buttons.
		_play_completion_reveal()
		set_completion_buttons_enabled(true)
		call_deferred("focus_completion_primary")
	else:
		release_completion_focus()
		_stop_completion_reveal()
	_update_chrome_visibility()


## Same-frame page; only alpha/scale/slide animate (see UiReveal).
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


func set_completion_buttons_enabled(value: bool) -> void:
	for button: PixelMenuButton in [_completion_primary, _completion_replay]:
		if button != null:
			button.disabled = not value


func get_completion_primary_button() -> PixelMenuButton:
	return _completion_primary


func get_completion_replay_button() -> PixelMenuButton:
	return _completion_replay


func is_completion_active() -> bool:
	return _completion_active


## Test/audit hook for the completion reveal; no gameplay effect.
func get_completion_reveal_alpha() -> float:
	return _completion_overlay.modulate.a if _completion_overlay != null else 0.0


func get_compact_header() -> CompactLevelHeader:
	return _header


func get_objective_text() -> String:
	return _objective_base


func get_boss_bar() -> HudBossBar:
	return _boss_bar


func get_guide() -> L3Guide:
	return _guide


func get_hits() -> int:
	return _hits


func get_player_health_bar() -> PlayerHealthBar:
	return _health_bar


## The old 12 px "生命值" word label is gone; the heart icon carries the read.
func get_health_label() -> Label:
	return null


func is_health_bar_visible() -> bool:
	return _health_bar != null and _health_bar.visible


func get_health_bar_rect() -> Rect2:
	if _health_bar == null:
		return Rect2()
	return Rect2(_health_bar.position, _health_bar.size)


func get_hit_pips_current() -> int:
	return _health_bar.get_current() if _health_bar != null else 0


func get_hit_pips_max() -> int:
	return _health_bar.get_max() if _health_bar != null else 0


func get_prompt_text() -> String:
	return _guide.get_prompt_text() if _guide != null else ""


func get_event_text() -> String:
	return _header.get_event_text() if _header != null else ""


func get_control_hint_visible() -> bool:
	return _control_hint != null and _control_hint.visible


func is_pause_visible() -> bool:
	return _pause_visible


func is_completion_visible() -> bool:
	return _completion_overlay != null and _completion_overlay.visible


func get_completion_text() -> String:
	return _completion_title.text if _completion_title != null else ""


func get_completion_subtitle_text() -> String:
	return _completion_subtitle.text if _completion_subtitle != null else ""


func get_completion_hint_text() -> String:
	return _completion_hint.text if _completion_hint != null else ""


## The old permanent bottom controls legend is gone; pause shows the bindings.
func get_controls_text() -> String:
	return "移动、奔跑、跳跃、换相、攻击与交互都在暂停页。"
