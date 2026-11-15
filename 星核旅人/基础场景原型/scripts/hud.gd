class_name PrototypeHUD
extends CanvasLayer

## English-only HUD to avoid missing-glyph issues with system CJK fonts.
## Top: controls + polarity. Bottom-right: current state / optional debug.
## The pause overlay lives in this always-processing CanvasLayer.

const WIDTH: float = 640.0
const HEIGHT: float = 360.0
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const PURPLE: Color = Color("#c8a7f2")
const TEXT: Color = Color("#e9efeb")
const MUTED: Color = Color("#a8bbb7")
const DIM: Color = Color("#6f8582")
const PANEL_BG: Color = Color(0.012, 0.025, 0.031, 0.82)

var _root: Control
var _polarity_panel: Panel
var _polarity_style: StyleBoxFlat
var _polarity_value: Label
var _state_panel: Panel
var _state_label: Label
var _physics_label: Label
var _anchor_label: Label
var _toast_label: Label
var _pause_overlay: ColorRect
var _pause_panel: Panel
var _title_label: Label
var _controls_label: Label
var _hint_label: Label
var _anchor_panel: Panel
var _anchor_status_label: Label
var _anchor_guide_label: Label
var _success_banner: Label
var _interaction_panel: Panel
var _interaction_polarity_label: Label
var _interaction_field_label: Label
var _interaction_e_label: Label
var _interaction_tips_label: Label
var _bay_panel: Panel
var _bay_status_label: Label
var _bay_hint_label: Label
var _interaction_banner: Label
var _record_link_panel: Panel
var _record_bay_label: Label
var _record_stone_label: Label
var _record_stage_label: Label

var _toast_time: float = 0.0
var _debug_visible: bool = false
var _last_anchor_text: String = "(64, 63)"
var _paused: bool = false
var _anchor_mode: bool = false
var _anchor_success: bool = false
var _interaction_mode: bool = false
var _interaction_success: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.size = Vector2(WIDTH, HEIGHT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top_bar()
	_build_polarity_panel()
	_build_state_panel()
	_build_anchor_panel()
	_build_interaction_panel()
	_build_bay_panel()
	_build_record_link_panel()
	_build_interaction_banner()
	_build_toast()
	_build_pause_overlay()
	set_polarity(true)
	set_room_mode(false)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time = maxf(_toast_time - delta, 0.0)
		if _toast_time <= 0.0:
			_toast_label.visible = false


func _build_top_bar() -> void:
	var panel: Panel = Panel.new()
	panel.position = Vector2(0.0, 0.0)
	panel.size = Vector2(WIDTH, 44.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_bottom = 1
	style.border_color = Color(0.33, 0.52, 0.51, 0.55)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var title: Label = _make_label(
		"STAR CORE TRAVELER / BASIC SCENE",
		Vector2(8.0, 3.0), Vector2(430.0, 12.0), 9, GOLD, 0
	)
	_root.add_child(title)
	_title_label = title

	var controls: Label = _make_label(
		"A/D or ARROWS: WALK   L-SHIFT: RUN   DOUBLE-TAP: RUN   SPACE: JUMP",
		Vector2(8.0, 15.0), Vector2(456.0, 11.0), 8, TEXT, 0
	)
	_root.add_child(controls)
	_controls_label = controls

	var hint: Label = _make_label(
		"Q: POLARITY   R: RESET   ESC: PAUSE   F3: DEBUG   FALL: RESPAWN",
		Vector2(8.0, 27.0), Vector2(430.0, 10.0), 8, MUTED, 0
	)
	_root.add_child(hint)
	_hint_label = hint


func _build_polarity_panel() -> void:
	_polarity_panel = Panel.new()
	_polarity_panel.position = Vector2(472.0, 4.0)
	_polarity_panel.size = Vector2(160.0, 36.0)
	_polarity_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_polarity_style = StyleBoxFlat.new()
	_polarity_style.bg_color = Color(0.02, 0.035, 0.041, 0.9)
	_polarity_style.border_width_left = 2
	_polarity_style.border_width_top = 1
	_polarity_style.border_width_right = 1
	_polarity_style.border_width_bottom = 1
	_polarity_style.border_color = GOLD
	_polarity_panel.add_theme_stylebox_override("panel", _polarity_style)
	_root.add_child(_polarity_panel)

	var caption: Label = _make_label(
		"POLARITY", Vector2(480.0, 5.0), Vector2(145.0, 9.0), 7, MUTED, 0
	)
	_root.add_child(caption)
	_polarity_value = _make_label(
		"GOLD  +", Vector2(480.0, 13.0), Vector2(145.0, 22.0), 14, GOLD, 1
	)
	_root.add_child(_polarity_value)


func _build_state_panel() -> void:
	var panel: Panel = Panel.new()
	panel.position = Vector2(416.0, 304.0)
	panel.size = Vector2(216.0, 50.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.031, 0.76)
	style.border_width_top = 1
	style.border_color = Color(0.33, 0.52, 0.51, 0.45)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	_state_panel = panel

	_state_label = _make_label(
		"STATE  IDLE   FRAME 1/10",
		Vector2(8.0, 2.0), Vector2(202.0, 11.0), 9, TEXT, 0
	)
	_state_panel.add_child(_state_label)
	_physics_label = _make_label(
		"FLOOR YES   VX    0.0   VY    0.0",
		Vector2(8.0, 14.0), Vector2(202.0, 9.0), 7, MUTED, 0
	)
	_state_panel.add_child(_physics_label)
	_anchor_label = _make_label(
		"F3: DEBUG / CHEST ANCHOR",
		Vector2(8.0, 25.0), Vector2(202.0, 9.0), 7, DIM, 0
	)
	_state_panel.add_child(_anchor_label)


func _build_anchor_panel() -> void:
	_anchor_panel = Panel.new()
	_anchor_panel.position = Vector2(8.0, 300.0)
	_anchor_panel.size = Vector2(312.0, 54.0)
	_anchor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.031, 0.84)
	style.border_width_left = 2
	style.border_color = CYAN
	_anchor_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_anchor_panel)

	var title: Label = _make_label(
		"ANCHOR TRIAL", Vector2(8.0, 2.0), Vector2(296.0, 10.0), 8, GOLD, 0
	)
	_anchor_panel.add_child(title)
	_anchor_status_label = _make_label(
		"FIELD  OUT OF RANGE   DIST 0", Vector2(8.0, 13.0), Vector2(296.0, 10.0), 8, MUTED, 0
	)
	_anchor_panel.add_child(_anchor_status_label)
	_anchor_guide_label = _make_label(
		"Q: CYAN ATTRACT > JUMP + D > Q: GOLD REPEL",
		Vector2(8.0, 26.0), Vector2(296.0, 9.0), 7, TEXT, 0
	)
	_anchor_panel.add_child(_anchor_guide_label)
	var debug_note: Label = _make_label(
		"F3: RANGE / FORCE DIRECTION     F2: BASE ROOM",
		Vector2(8.0, 37.0), Vector2(296.0, 9.0), 7, DIM, 0
	)
	_anchor_panel.add_child(debug_note)

	_success_banner = _make_label(
		"DESTINATION REACHED  -  R: RETRY  /  F2: BASE",
		Vector2(120.0, 70.0), Vector2(400.0, 22.0), 12, GOLD, 2
	)
	_success_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success_banner.visible = false
	_root.add_child(_success_banner)


func _build_interaction_panel() -> void:
	_interaction_panel = Panel.new()
	_interaction_panel.position = Vector2(8.0, 110.0)
	_interaction_panel.size = Vector2(400.0, 60.0)
	_interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.031, 0.86)
	style.border_width_left = 2
	style.border_color = CYAN
	_interaction_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_interaction_panel)

	var title: Label = _make_label(
		"CORE LINK", Vector2(8.0, 2.0), Vector2(384.0, 10.0), 8, GOLD, 0
	)
	_interaction_panel.add_child(title)
	_interaction_polarity_label = _make_label(
		"PLAYER GOLD +   CORE LOCKED",
		Vector2(8.0, 14.0), Vector2(384.0, 10.0), 8, TEXT, 0
	)
	_interaction_panel.add_child(_interaction_polarity_label)
	_interaction_field_label = _make_label(
		"FIELD LOCKED   DIST 0",
		Vector2(8.0, 26.0), Vector2(384.0, 10.0), 7, MUTED, 0
	)
	_interaction_panel.add_child(_interaction_field_label)
	_interaction_e_label = _make_label(
		"E: CORE LOCKED IN BAY",
		Vector2(8.0, 38.0), Vector2(384.0, 10.0), 7, TEXT, 0
	)
	_interaction_panel.add_child(_interaction_e_label)
	_interaction_tips_label = _make_label(
		"F3: RANGE/LINE   F2: ANCHOR   F4: BASE   R: RESET",
		Vector2(8.0, 50.0), Vector2(384.0, 9.0), 7, DIM, 0
	)
	_interaction_panel.add_child(_interaction_tips_label)
	_interaction_panel.visible = false


func _build_bay_panel() -> void:
	_bay_panel = Panel.new()
	_bay_panel.position = Vector2(416.0, 110.0)
	_bay_panel.size = Vector2(216.0, 52.0)
	_bay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.031, 0.82)
	style.border_width_top = 1
	style.border_color = Color(0.55, 0.75, 0.70, 0.65)
	_bay_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_bay_panel)

	var title: Label = _make_label(
		"BAY STATUS", Vector2(8.0, 2.0), Vector2(200.0, 10.0), 8, GOLD, 0
	)
	_bay_panel.add_child(title)
	_bay_status_label = _make_label(
		"START LOCKED / TARGET OPEN",
		Vector2(8.0, 15.0), Vector2(200.0, 10.0), 7, TEXT, 0
	)
	_bay_panel.add_child(_bay_status_label)
	_bay_hint_label = _make_label(
		"",
		Vector2(8.0, 28.0), Vector2(200.0, 10.0), 7, MUTED, 0
	)
	_bay_panel.add_child(_bay_hint_label)
	var note: Label = _make_label(
		"E: RELEASE / STORE   Q: POLARITY",
		Vector2(8.0, 40.0), Vector2(200.0, 9.0), 7, DIM, 0
	)
	_bay_panel.add_child(note)
	_bay_panel.visible = false


func _build_record_link_panel() -> void:
	_record_link_panel = Panel.new()
	_record_link_panel.position = Vector2(8.0, 174.0)
	_record_link_panel.size = Vector2(400.0, 56.0)
	_record_link_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.031, 0.86)
	style.border_width_left = 2
	style.border_color = GOLD
	_record_link_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_record_link_panel)

	var title: Label = _make_label(
		"POLARITY RECORD LINK  /  TEST ROOM",
		Vector2(8.0, 2.0), Vector2(384.0, 10.0), 8, GOLD, 0
	)
	_record_link_panel.add_child(title)
	_record_bay_label = _make_label(
		"BAY RECORD: NO RECORD   LAMP: NEUTRAL",
		Vector2(8.0, 14.0), Vector2(384.0, 10.0), 7, TEXT, 0
	)
	_record_link_panel.add_child(_record_bay_label)
	_record_stone_label = _make_label(
		"RUNE STONE: INACTIVE   FORCE: IDLE",
		Vector2(8.0, 26.0), Vector2(384.0, 10.0), 7, MUTED, 0
	)
	_record_link_panel.add_child(_record_stone_label)
	_record_stage_label = _make_label(
		"STAGE: NO RECORD",
		Vector2(8.0, 38.0), Vector2(384.0, 10.0), 7, MUTED, 0
	)
	_record_link_panel.add_child(_record_stage_label)
	_record_link_panel.visible = false


func _build_interaction_banner() -> void:
	_interaction_banner = _make_label(
		"TARGET BAY REACHED - E: RELEASE / R: RESET",
		Vector2(120.0, 178.0), Vector2(400.0, 22.0), 11, GOLD, 2
	)
	_interaction_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_banner.visible = false
	_root.add_child(_interaction_banner)


func _build_toast() -> void:
	_toast_label = _make_label(
		"", Vector2(0.0, 58.0), Vector2(WIDTH, 16.0), 10, GOLD, 1
	)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.visible = false
	_root.add_child(_toast_label)


func _build_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.position = Vector2.ZERO
	_pause_overlay.size = Vector2(WIDTH, HEIGHT)
	_pause_overlay.color = Color(0.008, 0.016, 0.02, 0.66)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	_root.add_child(_pause_overlay)

	_pause_panel = Panel.new()
	_pause_panel.position = Vector2(204.0, 132.0)
	_pause_panel.size = Vector2(232.0, 96.0)
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.034, 0.04, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.45, 0.66, 0.63, 0.9)
	_pause_panel.add_theme_stylebox_override("panel", style)
	_pause_overlay.add_child(_pause_panel)

	var title: Label = _make_label(
		"PAUSED", Vector2(0.0, 12.0), Vector2(232.0, 30.0), 20, GOLD, 1
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_panel.add_child(title)
	var resume: Label = _make_label(
		"ESC  RESUME", Vector2(0.0, 54.0), Vector2(232.0, 14.0), 9, TEXT, 0
	)
	resume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_panel.add_child(resume)
	var note: Label = _make_label(
		"PHYSICS AND EFFECTS FROZEN", Vector2(0.0, 72.0), Vector2(232.0, 10.0), 7, MUTED, 0
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_panel.add_child(note)


func _make_label(
	text: String,
	pos: Vector2,
	box_size: Vector2,
	font_size: int,
	color: Color,
	outline_size: int
) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.size = box_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.025, 0.95))
		label.add_theme_constant_override("outline_size", outline_size)
	return label


func set_polarity(positive: bool) -> void:
	var color: Color = GOLD if positive else CYAN
	_polarity_value.text = "GOLD  +" if positive else "CYAN  -"
	_polarity_value.add_theme_color_override("font_color", color)
	_polarity_style.border_color = color
	_polarity_panel.add_theme_stylebox_override("panel", _polarity_style)


func set_room_mode(anchor: bool) -> void:
	_interaction_mode = false
	_anchor_mode = anchor
	_anchor_panel.visible = anchor
	_state_panel.visible = not anchor
	_interaction_panel.visible = false
	_bay_panel.visible = false
	_record_link_panel.visible = false
	_interaction_banner.visible = false
	_success_banner.visible = anchor and _anchor_success
	if anchor:
		_title_label.text = "STAR CORE TRAVELER / ANCHOR TRIAL"
		_controls_label.text = "A/D: WALK   L-SHIFT: RUN   SPACE: JUMP   Q: POLARITY"
		_hint_label.text = "R: RESET   ESC: PAUSE   F3: RANGE/FORCE   F2: BASE   F4: CORE BAY   F7: RECORD TEST"
	else:
		_title_label.text = "STAR CORE TRAVELER / BASIC SCENE"
		_controls_label.text = "A/D or ARROWS: WALK   L-SHIFT: RUN   DOUBLE-TAP: RUN   SPACE: JUMP"
		_hint_label.text = "Q: POLARITY   R: RESET   ESC: PAUSE   F3: DEBUG   F2: ANCHOR   F4: CORE BAY   F7: RECORD TEST"


func set_interaction_mode(active: bool) -> void:
	if not active:
		set_room_mode(false)
		return
	_interaction_mode = true
	_anchor_mode = false
	_anchor_panel.visible = false
	_state_panel.visible = false
	_interaction_panel.visible = true
	_bay_panel.visible = true
	_record_link_panel.visible = false
	_success_banner.visible = false
	_interaction_banner.visible = _interaction_success
	_title_label.text = "STAR CORE TRAVELER / CORE BAY TEST"
	_controls_label.text = "A/D: WALK   L-SHIFT: RUN   SPACE: JUMP   E: RELEASE/STORE   Q: POLARITY"
	_hint_label.text = "R: RESET   ESC: PAUSE   F3: RANGE/LINE   F2: ANCHOR   F4: BASE   F7: RECORD TEST"


## Standalone wrapper can replace the navigation hint without touching the
## interaction panel state.
func set_interaction_navigation(text: String) -> void:
	if _interaction_mode:
		_hint_label.text = text


## Standalone/test room can replace the static F2/F4 tips line. The normal
## interaction room keeps its defaults.
func set_interaction_tips(text: String) -> void:
	_interaction_tips_label.text = text


## Test-room-only record/link panel. It is hidden by the normal room modes and
## explicitly shown by the polarity-record test room.
func set_record_link_visible(value: bool) -> void:
	_record_link_panel.visible = value


func set_record_link_state(bay_text: String, stone_text: String, stage_text: String) -> void:
	_record_bay_label.text = bay_text
	_record_stone_label.text = stone_text
	_record_stage_label.text = stage_text


func is_record_link_visible() -> bool:
	return _record_link_panel.visible


func get_record_link_bay_text() -> String:
	return _record_bay_label.text


func get_record_link_stone_text() -> String:
	return _record_stone_label.text


func get_record_link_stage_text() -> String:
	return _record_stage_label.text


func set_interaction_state(
	player_positive: bool,
	core_state: int,
	field_status: String,
	distance: float,
	force: Vector2,
	bay_text: String,
	e_text: String,
	hint_text: String
) -> void:
	var player_text: String = "GOLD +" if player_positive else "CYAN -"
	var core_text: String
	var core_color: Color
	match core_state:
		1:
			core_text = "GOLD +"
			core_color = GOLD
		0:
			core_text = "CYAN -"
			core_color = CYAN
		_:
			core_text = "LOCKED"
			core_color = PURPLE
	_interaction_polarity_label.text = "PLAYER %s   CORE %s" % [player_text, core_text]
	_interaction_polarity_label.add_theme_color_override("font_color", core_color)

	var status: String = field_status.to_upper()
	var status_color: Color = MUTED
	match status:
		"ATTRACT":
			status_color = CYAN
		"REPEL":
			status_color = GOLD
		"BLOCKED":
			status_color = Color("#ff7f72")
		"STORED":
			status_color = PURPLE
		"RELEASED":
			status_color = GOLD
		_:
			status_color = MUTED
	var force_text: String = ""
	if not force.is_zero_approx():
		force_text = "   F(%+.0f,%+.0f)" % [force.x, force.y]
	_interaction_field_label.text = "FIELD %s   DIST %.0f%s" % [status, distance, force_text]
	_interaction_field_label.add_theme_color_override("font_color", status_color)
	_interaction_e_label.text = e_text if not e_text.is_empty() else "E: --"
	_bay_status_label.text = bay_text
	_bay_hint_label.text = hint_text
	_interaction_banner.visible = _interaction_mode and _interaction_success


func set_interaction_success(value: bool) -> void:
	_interaction_success = value
	_interaction_banner.visible = _interaction_mode and value


func is_interaction_mode() -> bool:
	return _interaction_mode


func is_interaction_panel_visible() -> bool:
	return _interaction_panel.visible


func is_bay_panel_visible() -> bool:
	return _bay_panel.visible


func is_interaction_success_visible() -> bool:
	return _interaction_banner.visible


func get_interaction_polarity_text() -> String:
	return _interaction_polarity_label.text


func get_interaction_field_text() -> String:
	return _interaction_field_label.text


func get_interaction_e_text() -> String:
	return _interaction_e_label.text


func get_hint_text() -> String:
	return _hint_label.text


func get_toast_text() -> String:
	return _toast_label.text


func is_toast_visible() -> bool:
	return _toast_label.visible


func get_bay_status_text() -> String:
	return _bay_status_label.text


func get_bay_hint_text() -> String:
	return _bay_hint_label.text


func set_anchor_field(status: String, distance: float, force: Vector2) -> void:
	var state: String = status.to_upper()
	var color: Color = MUTED
	match state:
		"ATTRACT":
			color = CYAN
		"REPEL":
			color = GOLD
		"BLOCKED":
			color = Color("#ff7f72")
		_:
			color = MUTED
	var force_text: String = ""
	if not force.is_zero_approx():
		force_text = "   F(%+.0f,%+.0f)" % [force.x, force.y]
	_anchor_status_label.text = "FIELD %s   DIST %.0f%s" % [state, distance, force_text]
	_anchor_status_label.add_theme_color_override("font_color", color)


func set_anchor_success(value: bool) -> void:
	_anchor_success = value
	_success_banner.visible = _anchor_mode and value


func is_anchor_panel_visible() -> bool:
	return _anchor_panel.visible


func is_state_panel_visible() -> bool:
	return _state_panel.visible


func is_anchor_success_visible() -> bool:
	return _success_banner.visible


func get_anchor_status_text() -> String:
	return _anchor_status_label.text


func get_anchor_guide_text() -> String:
	return _anchor_guide_label.text


func set_state(
	state_name: String,
	frame_index: int,
	frame_count: int,
	on_floor: bool,
	velocity_x: float,
	velocity_y: float,
	anchor_text: String
) -> void:
	_state_label.text = "STATE  %s   FRAME %d/%d" % [
		state_name.to_upper(), frame_index + 1, frame_count
	]
	_physics_label.text = "FLOOR %s   VX %6.1f   VY %6.1f" % [
		"YES" if on_floor else "NO ", velocity_x, velocity_y
	]
	_last_anchor_text = anchor_text
	if _debug_visible:
		_anchor_label.text = "CHEST %s   COLLISION 12x30" % anchor_text
	else:
		_anchor_label.text = "F3: DEBUG / CHEST ANCHOR"


func set_debug_visible(value: bool) -> void:
	_debug_visible = value
	if value:
		_anchor_label.text = "CHEST %s   COLLISION 12x30" % _last_anchor_text
		_anchor_label.add_theme_color_override("font_color", GOLD)
	else:
		_anchor_label.text = "F3: DEBUG / CHEST ANCHOR"
		_anchor_label.add_theme_color_override("font_color", DIM)


func set_pause_visible(value: bool) -> void:
	_paused = value
	_pause_overlay.visible = value


func is_pause_visible() -> bool:
	return _paused


func get_polarity_text() -> String:
	return _polarity_value.text


func get_state_text() -> String:
	return _state_label.text


func get_debug_visible() -> bool:
	return _debug_visible


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_time = 1.35
