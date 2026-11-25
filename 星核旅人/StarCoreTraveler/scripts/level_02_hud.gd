class_name Level02HUD
extends CanvasLayer

## Compact player-facing HUD for the level-02 greybox.
##
## This is deliberately not PrototypeHUD: the second-level prototype should
## show short Chinese stage feedback, not the English F4 debug readouts. It owns
## only presentation state; all gameplay state remains in Level02/the shared
## star-core room.

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
const INTERACTION_KEY_HINT = preload("res://scripts/ui/interaction_key_hint.gd")

var _root: Control
var _header: CompactLevelHeader
var _objective: Label
var _phase_base: String = "任务：释放星核"
var _core_text: String = "星核：起始仓"
var _prompt_text: String = ""
var _event_text: String = ""
var _event_left: float = 0.0
var _object_prompt_visible: bool = false
var _prompt_world: Vector2 = Vector2.ZERO
var _world_layer: Control
## Compatibility storage only; the old bottom permanent hint is intentionally
## no longer rendered. Recovery/R feedback uses short events in the one slot.
var _recovery_text: String = ""
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
	_root.name = "Level02HUDRoot"
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_header()
	_build_objective()
	_build_world_prompt()
	_build_completion()
	set_polarity(true)
	set_status("任务：释放星核", "星核：起始仓", "")
	set_pause_visible(false)
	show_completion(false)


func _process(delta: float) -> void:
	if _event_left > 0.0:
		_event_left = maxf(_event_left - delta, 0.0)
		if _event_left <= 0.0:
			_event_text = ""
			if _objective != null and not _completion_active:
				_objective.text = _display_phase(_phase_base)
	_refresh_object_prompt_state()


func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		push_warning("Level02HUD: %s is missing; falling back" % FONT_PATH)
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
	_header.configure("沉寂回廊", "第二关 · 石栅通路", _font)
	_header.set_polarity(true)


func _build_objective() -> void:
	# Single objective line at the level-03 baseline: 12 px gold, no panel, no
	# second core row. The phase prefix is kept internally, but the display drops
	# the "任务：" prefix to match the other two levels' one-line objective.
	_objective = _label("释放星核", Vector2(15.0, 58.0), Vector2(430.0, 18.0), 12, GOLD)
	_root.add_child(_objective)


func _build_world_prompt() -> void:
	# Object-bound action hint near the real bay. Real E actions draw the one
	# approved 11x13 E cap + action word through InteractionKeyHint; lid motion
	# ("开罩中…/合罩中…") stays plain state text with no cap. No panel, no
	# central strip. It reads only public level/player/core/bay interfaces.
	_world_layer = Control.new()
	_world_layer.name = "WorldActionPrompt"
	_world_layer.position = Vector2.ZERO
	_world_layer.size = VIEW_SIZE
	_world_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_layer.visible = false
	_world_layer.draw.connect(_draw_object_prompt)
	_root.add_child(_world_layer)


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

	var title: Label = _label("第二关完成", Vector2(0.0, 12.0), Vector2(400.0, 34.0), 24, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	_completion_title = title
	var subtitle: Label = _label("沉寂回廊 · 星核已归位", Vector2(0.0, 50.0), Vector2(400.0, 18.0), 12, TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)
	var divider: ColorRect = ColorRect.new()
	divider.position = Vector2(70.0, 74.0)
	divider.size = Vector2(260.0, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.5)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	_completion_primary = _menu_button("进入第三关", Vector2(110.0, 86.0), Vector2(180.0, 28.0), PixelMenuButton.Variant.STONE)
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

	# Same approved three-button focus loop as level 01: primary first, the two
	# secondary commands share the second row.
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


func set_status(phase: String, core_text: String, prompt: String) -> void:
	_phase_base = phase
	_core_text = core_text
	_prompt_text = prompt
	# A real event owns the one line until it expires. A core-text change alone
	# never takes the slot (compatibility data only), so the objective cannot
	# flicker on every transport state.
	if _objective != null and _event_left <= 0.0 and not _completion_active:
		_objective.text = _display_phase(phase)
	_refresh_object_prompt_state()


func _display_phase(phase: String) -> String:
	return phase.trim_prefix("任务：")


func show_toast(text_value: String, duration: float = 1.6) -> void:
	if _objective == null:
		return
	if text_value.is_empty():
		_event_left = 0.0
		_event_text = ""
		if not _completion_active:
			_objective.text = _display_phase(_phase_base)
		return
	_event_text = text_value
	_event_left = clampf(duration, 0.2, 1.4)
	_objective.visible = not _completion_active
	_objective.text = text_value


func _refresh_object_prompt_state() -> void:
	var visible_now: bool = false
	if (
		_world_layer != null
		and not _prompt_text.is_empty()
		and not _completion_active
		and not get_tree().paused
	):
		var bay: StarCoreBayInteractable = _find_prompt_bay()
		if bay != null:
			_prompt_world = bay.get_store_center() + Vector2(0.0, -42.0)
			visible_now = true
	_object_prompt_visible = visible_now
	if _world_layer != null:
		if _world_layer.visible != visible_now:
			_world_layer.visible = visible_now
		if visible_now:
			_world_layer.queue_redraw()


## Read-only binding: the level, player and bay state decide the anchor. The HUD
## never calls a level mutator or changes bay/core state.
func _find_prompt_bay() -> StarCoreBayInteractable:
	var level: Node = get_parent()
	if level == null:
		return null
	if not level.has_method("get_player") or not level.has_method("get_bays"):
		return null
	var player: PrototypePlayer = level.call("get_player") as PrototypePlayer
	if player == null:
		return null
	var bays: Array = level.call("get_bays") as Array
	var core: StarCoreCarrier = null
	if level.has_method("get_core"):
		core = level.call("get_core") as StarCoreCarrier
	var store_action: bool = _prompt_text.begins_with("存入")
	var best: StarCoreBayInteractable = null
	var best_distance: float = 1e20
	var fallback: StarCoreBayInteractable = null
	var fallback_distance: float = 1e20
	for item: Variant in bays:
		var bay: StarCoreBayInteractable = item as StarCoreBayInteractable
		if bay == null or not bay.is_player_in_range(player.global_position):
			continue
		var distance: float = player.global_position.distance_to(bay.global_position)
		if distance > 64.0:
			continue
		if distance < fallback_distance:
			fallback = bay
			fallback_distance = distance
		if store_action:
			if (
				core == null or not core.is_active() or not bay.is_open_empty()
				or not bay.is_core_in_store_zone(core.global_position)
			):
				continue
		elif not bay.has_core():
			continue
		if distance < best_distance:
			best = bay
			best_distance = distance
	if best != null:
		return best
	# Animation wording ("开罩中…" / "合罩中…") still belongs beside the bay the
	# player is actually using.
	return fallback


## Short action name for the bay-anchored label. The level keeps its full
## compatibility prompt strings; the HUD only presents the action word next to
## the object, matching L3's "启动 / 取核" language.
func _display_action_name(prompt: String) -> String:
	var clean: String = prompt.trim_prefix("E ").strip_edges()
	if clean.begins_with("存入"):
		return "存入"
	if clean.begins_with("取出"):
		return "取核"
	if clean.begins_with("开罩"):
		return "开罩中…"
	if clean.begins_with("合罩"):
		return "合罩中…"
	return clean


## Lid motion is a state, not a new E action: it must not draw a key cap that
## would invite a second press.
func _prompt_is_state() -> bool:
	return _prompt_text.begins_with("开罩") or _prompt_text.begins_with("合罩")


func _draw_object_prompt() -> void:
	if not _object_prompt_visible or _font == null or _world_layer == null:
		return
	var rect: Rect2 = get_prompt_screen_rect()
	if rect.size == Vector2.ZERO:
		return
	var text: String = _display_action_name(_prompt_text)
	if _prompt_is_state():
		INTERACTION_KEY_HINT.draw_state(_world_layer, _font, rect.position, text)
	else:
		INTERACTION_KEY_HINT.draw_action(_world_layer, _font, rect.position, "E", text)


## Screen rect of the visible bay hint, using the same geometry as the drawing.
func get_prompt_screen_rect() -> Rect2:
	if not _object_prompt_visible or _font == null:
		return Rect2()
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return Rect2()
	var text: String = _display_action_name(_prompt_text)
	if text.is_empty():
		return Rect2()
	var actionable: bool = not _prompt_is_state()
	var width: float = (
		INTERACTION_KEY_HINT.action_width(_font, text)
		if actionable
		else INTERACTION_KEY_HINT.state_width(_font, text)
	)
	var screen: Vector2 = _prompt_world - camera.get_screen_center_position() + VIEW_SIZE * 0.5
	var pos: Vector2 = Vector2(
		clampf(screen.x - width * 0.5, 8.0, maxf(8.0, 632.0 - width)),
		clampf(screen.y, 92.0, 306.0)
	)
	return Rect2(Vector2(roundf(pos.x), roundf(pos.y)), Vector2(width, 13.0))


func set_pause_visible(value: bool) -> void:
	_pause_visible = value
	if value:
		_object_prompt_visible = false
		if _world_layer != null:
			_world_layer.visible = false


func set_recovery_hint(text_value: String) -> void:
	# Kept as a compatibility data sink; no persistent bottom label exists.
	_recovery_text = text_value


func get_recovery_hint_text() -> String:
	return _recovery_text


func show_completion(value: bool, completion_count: int = 0) -> void:
	if _completion_overlay == null:
		return
	_completion_overlay.visible = value
	_completion_active = value
	if value:
		_play_completion_reveal()
		_event_left = 0.0
		_event_text = ""
		if _objective != null:
			_objective.visible = false
		_object_prompt_visible = false
		if _world_layer != null:
			_world_layer.visible = false
		call_deferred("focus_completion_primary")
	else:
		release_completion_focus()
		if _objective != null:
			_objective.visible = true
			_objective.text = _display_phase(_phase_base)
		_refresh_object_prompt_state()
	if not value:
		_stop_completion_reveal()
	if _completion_count_label != null:
		_completion_count_label.text = "本关结算 · Esc 可打开暂停菜单" if value else ""


## Same-frame page, animated alpha/scale only (see UiReveal.play_overlay_open).
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


func get_phase_text() -> String:
	return _phase_base


func get_core_text() -> String:
	return _core_text


func get_prompt_text() -> String:
	return _prompt_text


func is_prompt_visible() -> bool:
	return _object_prompt_visible


## Visible key cap for the bay hint. Only real E actions get one; "开罩中…" and
## "合罩中…" are transient states and return an empty key.
func get_prompt_key() -> String:
	if not _object_prompt_visible or _prompt_is_state():
		return ""
	return "E"


func get_prompt_verb() -> String:
	if not _object_prompt_visible:
		return ""
	return _display_action_name(_prompt_text)


func is_prompt_keycap_visible() -> bool:
	return _object_prompt_visible and not _prompt_is_state()


func get_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for node: Node in _root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


func get_toast_text() -> String:
	return _event_text


func is_toast_visible() -> bool:
	return _event_left > 0.0


func is_pause_visible() -> bool:
	return _pause_visible


func is_completion_visible() -> bool:
	return _completion_overlay != null and _completion_overlay.visible


func get_completion_text() -> String:
	return _completion_title.text if _completion_title != null else ""


func get_controls_text() -> String:
	return (
		"A/D 移动   左Shift 奔跑   空格 跳跃   Q 切换相性   "
		+ "J 挥击   E 释放/入仓   F 阅读   R 重来   Esc 暂停"
	)
