extends Control

## Standalone 640x360 look-dev preview for the pure-visual polarity link.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_polarity_link.tscn
## Capture:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_polarity_link.tscn -- --capture-preview
##
## This is a visual demo, not gameplay. It does not store a core, apply force,
## change an anchor, or decide what happens when a core is removed. The bay is
## the existing StarCoreBayVisual scene. The rune target is loaded dynamically
## only if res://scenes/rune_stone_visual.tscn exists; when it does not, the
## preview shows a clearly labelled dashed socket instead of pretending a rune
## is complete.

const LINK_SCENE: PackedScene = preload("res://scenes/polarity_link_visual.tscn")
const BAY_SCENE: PackedScene = preload("res://scenes/star_core_bay_visual.tscn")
const RUNE_SCENE_PATH: String = "res://scenes/rune_stone_visual.tscn"
const CAPTURE_PATH: String = "res://screenshots/polarity_link_visual_preview.png"
const CAPTURE_SIZE: Vector2i = Vector2i(640, 360)

const BG_COLOR: Color = Color("#071016")
const HEADER_COLOR: Color = Color("#0b171d")
const PANEL_COLOR: Color = Color("#0a141a")
const PANEL_INNER: Color = Color("#0d1a20")
const GRID_COLOR: Color = Color(0.12, 0.22, 0.25, 0.36)
const BORDER_COLOR: Color = Color(0.24, 0.40, 0.42, 0.72)
const TEXT_COLOR: Color = Color("#dce8e4")
const MUTED_COLOR: Color = Color("#7f999a")
const WARN_COLOR: Color = Color("#e8b96a")
const CYAN_COLOR: Color = Color("#8fdfe6")
const GOLD_COLOR: Color = Color("#e2bd6a")

const STAGE_RECT: Rect2 = Rect2(16.0, 54.0, 414.0, 222.0)
const DETAIL_RECT: Rect2 = Rect2(444.0, 54.0, 180.0, 222.0)
const BOTTOM_RECT: Rect2 = Rect2(0.0, 282.0, 640.0, 78.0)
const GROUND_Y: float = 234.0
const BAY_POSITION: Vector2 = Vector2(82.0, 218.0)
const TARGET_POSITION: Vector2 = Vector2(352.0, 218.0)
const TARGET_PLACEHOLDER_RECT: Rect2 = Rect2(336.0, 202.0, 32.0, 32.0)
const TARGET_LINK_OFFSET: Vector2 = Vector2(-17.0, 0.0)

const POSITIVE_LAMP_RECT: Rect2i = Rect2i(462, 94, 28, 36)
const NEGATIVE_LAMP_RECT: Rect2i = Rect2i(462, 180, 28, 36)
const MAIN_LAMP_RECT: Rect2i = Rect2i(58, 225, 7, 9)
const PULSE_CHECK_RECT: Rect2i = Rect2i(190, 202, 90, 36)
const BASE_CHECK_RECT: Rect2i = Rect2i(66, 226, 32, 8)

var _stage: Node2D
var _bay: StarCoreBayVisual
var _link: PolarityLinkVisual
var _rune: Node2D
var _target_mode: String = "pending"
var _target_event_text: String = ""
var _missing_art_paths: PackedStringArray = PackedStringArray()
var _show_target_placeholder: bool = true
var _last_status_key: String = ""

var _state_label: Label
var _detail_label: Label
var _target_caption: Label
var _controls_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)

	_build()
	await get_tree().process_frame
	_refresh_status(true)

	if _capture_requested():
		var exit_code: int = await _run_capture()
		get_tree().quit(exit_code)


func _process(_delta: float) -> void:
	if _link == null:
		return
	var signature: String = "%s|%s|%s|%s|%s|%s|%s" % [
		str(_link.record_positive),
		str(_link.is_transfer_active()),
		str(_link.is_arrival_flash_active()),
		str(int(round(_link.get_transfer_progress() * 100.0))),
		str(get_tree().paused),
		_target_mode,
		_target_event_text,
	]
	if signature == _last_status_key:
		return
	_refresh_status(false)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_SPACE:
			_trigger_transfer()
			get_viewport().set_input_as_handled()
		KEY_P:
			get_tree().paused = not get_tree().paused
			_refresh_status(true)
			get_viewport().set_input_as_handled()
		KEY_R:
			_reset_demo()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			get_tree().quit()
			get_viewport().set_input_as_handled()


func _trigger_transfer() -> void:
	if _link == null or get_tree().paused:
		return
	# The first press sends the opposite of the recorded lamp. Pressing again
	# during a transfer flips the request and restarts from the source: the
	# latest request wins, matching the component's completion contract.
	var next_positive: bool
	if _link.is_transfer_active():
		next_positive = not _link.get_transfer_polarity()
	else:
		next_positive = not _link.record_positive
	_target_event_text = ""
	_link.play_transfer(next_positive)
	_refresh_status(true)


func _reset_demo() -> void:
	get_tree().paused = false
	if _link != null:
		_link.stop_transfer()
		_link.record_positive = true
	_target_event_text = ""
	if _rune != null and _rune.has_method("set_polarity"):
		_rune.call("set_polarity", true, true)
	_refresh_status(true)


func get_link_component() -> PolarityLinkVisual:
	return _link


func get_bay_component() -> StarCoreBayVisual:
	return _bay


func get_target_visual() -> Node2D:
	return _rune


func get_target_mode() -> String:
	return _target_mode


func is_target_placeholder_explicit() -> bool:
	return _target_mode in ["pending", "missing_art", "invalid"]


func get_target_status_text() -> String:
	return _target_detail_text()


func get_ui_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	_collect_label_text(self, lines)
	return "\n".join(lines)


func _build() -> void:
	_stage = Node2D.new()
	_stage.name = "Stage"
	_stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_stage)

	_bay = BAY_SCENE.instantiate() as StarCoreBayVisual
	if _bay != null:
		_bay.name = "SourceBay"
		_bay.position = BAY_POSITION
		_stage.add_child(_bay)

	_link = LINK_SCENE.instantiate() as PolarityLinkVisual
	if _link != null:
		_link.name = "PolarityLink"
		_link.target_position = TARGET_POSITION
		_link.link_target_offset = TARGET_LINK_OFFSET
		_stage.add_child(_link)
		if _bay != null:
			_link.source_path = _link.get_path_to(_bay)
		_link.visual_delivery_finished.connect(_on_visual_delivery_finished)

	_load_target()

	_build_lamp_inspection()
	_build_labels()


func _load_target() -> void:
	_target_mode = "pending"
	_show_target_placeholder = true
	_missing_art_paths.clear()
	if not ResourceLoader.exists(RUNE_SCENE_PATH, "PackedScene"):
		print("PREVIEW_TARGET mode=pending path=%s" % RUNE_SCENE_PATH)
		return

	_missing_art_paths = _missing_texture_dependencies(RUNE_SCENE_PATH)
	if not _missing_art_paths.is_empty():
		_target_mode = "missing_art"
		print(
			"PREVIEW_TARGET mode=missing_art path=%s missing=%s"
			% [RUNE_SCENE_PATH, ",".join(_missing_art_paths)]
		)
		return

	var packed: Resource = ResourceLoader.load(
		RUNE_SCENE_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REUSE
	)
	if not (packed is PackedScene):
		_target_mode = "invalid"
		print("PREVIEW_TARGET mode=invalid path=%s reason=not_packed_scene" % RUNE_SCENE_PATH)
		return

	var instance: Node = (packed as PackedScene).instantiate()
	if not (instance is Node2D):
		_target_mode = "invalid"
		if instance != null:
			instance.queue_free()
		print("PREVIEW_TARGET mode=invalid path=%s reason=root_not_node2d" % RUNE_SCENE_PATH)
		return

	_rune = instance as Node2D
	_rune.name = "RuneStoneTarget"
	_rune.position = TARGET_POSITION
	_stage.add_child(_rune)
	_show_target_placeholder = false

	if _link != null:
		_link.target_path = _link.get_path_to(_rune)

	if not _rune.has_method("set_polarity"):
		_target_mode = "missing_api"
		print("PREVIEW_TARGET mode=missing_api path=%s reason=no_set_polarity" % RUNE_SCENE_PATH)
		return

	if _rune.has_method("has_art") and not bool(_rune.call("has_art")):
		# The scene loaded, but its component reports missing art. Do not show a
		# half-finished target or call set_polarity as a completed integration.
		_rune.queue_free()
		_rune = null
		_show_target_placeholder = true
		if _link != null:
			_link.target_path = NodePath()
		_target_mode = "missing_art"
		print("PREVIEW_TARGET mode=missing_art path=%s reason=has_art_false" % RUNE_SCENE_PATH)
		return

	_target_mode = "rune"
	_rune.call("set_polarity", true, true)
	if _rune.has_signal("transition_finished"):
		_rune.connect("transition_finished", Callable(self, "_on_rune_transition_finished"))
	print("PREVIEW_TARGET mode=rune path=%s" % RUNE_SCENE_PATH)


## Reads the scene file's declared Texture2D ext_resources and reports any whose
## imported Texture2D cannot be resolved. This lets the preview avoid loading a
## half-imported parallel scene and let its own explicit pending socket remain.
func _missing_texture_dependencies(scene_path: String) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	if not FileAccess.file_exists(scene_path):
		return missing
	var text: String = FileAccess.get_file_as_string(scene_path)
	for line: String in text.split("\n"):
		if not line.begins_with("[ext_resource") or not line.contains("type=\"Texture2D\""):
			continue
		var marker: String = "path=\""
		var start: int = line.find(marker)
		if start < 0:
			continue
		start += marker.length()
		var finish: int = line.find("\"", start)
		if finish <= start:
			continue
		var path: String = line.substr(start, finish - start)
		if not ResourceLoader.exists(path, "Texture2D"):
			missing.append(path)
	return missing


func _build_lamp_inspection() -> void:
	# Two real instances of the component, scaled 4x for inspection. They have
	# no target and no guide, so only the code-drawn lamp is visible. Scaling is
	# nearest-filtered pixels, not a new hand-drawn icon.
	_add_lamp_chip("PositiveLamp4x", Vector2(558.0, 66.0), true)
	_add_lamp_chip("NegativeLamp4x", Vector2(558.0, 152.0), false)


func _add_lamp_chip(chip_name: String, at: Vector2, positive: bool) -> void:
	if _stage == null:
		return
	var chip: PolarityLinkVisual = LINK_SCENE.instantiate() as PolarityLinkVisual
	if chip == null:
		return
	chip.name = chip_name
	chip.position = at
	chip.scale = Vector2(4.0, 4.0)
	chip.show_link_guide = false
	chip.show_record_lamp = true
	chip.record_positive = positive
	chip.set_process(false)
	_stage.add_child(chip)


func _build_labels() -> void:
	var title: Label = _add_label(
		"POLARITY LINK VISUAL PREVIEW",
		Vector2(20.0, 8.0),
		Vector2(430.0, 18.0),
		14,
		TEXT_COLOR
	)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)

	_add_label(
		"VISUAL ONLY / NOT GAMEPLAY / NO BAY STATE, FORCE, OR RECOVERY RULE",
		Vector2(20.0, 31.0),
		Vector2(560.0, 12.0),
		8,
		MUTED_COLOR
	)
	_add_label(
		"640x360 / 1x PIXELS",
		Vector2(490.0, 12.0),
		Vector2(130.0, 12.0),
		7,
		MUTED_COLOR,
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	_add_label(
		"1x ACTUAL-PIXEL STAGE",
		Vector2(24.0, 60.0),
		Vector2(210.0, 11.0),
		8,
		TEXT_COLOR
	)
	_add_label(
		"EXISTING STAR-CORE BAY + CODE-DRAWN LINK",
		Vector2(24.0, 71.0),
		Vector2(300.0, 10.0),
		6,
		MUTED_COLOR
	)

	_add_label("4x LAMP INSPECTION", Vector2(452.0, 60.0), Vector2(160.0, 11.0), 8, TEXT_COLOR)
	_add_label(
		"NEAREST / CODE-DRAWN / NO PNG",
		Vector2(452.0, 71.0),
		Vector2(160.0, 10.0),
		6,
		MUTED_COLOR
	)

	_add_label("GOLD +", Vector2(500.0, 92.0), Vector2(74.0, 12.0), 9, GOLD_COLOR)
	_add_label(
		"RECORDED\nPOSITIVE",
		Vector2(500.0, 106.0),
		Vector2(80.0, 22.0),
		6,
		MUTED_COLOR
	)
	_add_label("CYAN -", Vector2(500.0, 178.0), Vector2(74.0, 12.0), 9, CYAN_COLOR)
	_add_label(
		"RECORDED\nNEGATIVE",
		Vector2(500.0, 192.0),
		Vector2(80.0, 22.0),
		6,
		MUTED_COLOR
	)
	_add_label(
		"LAMP SITS BESIDE THE BASE.\nBASE AND LOCK MARK STAY VISIBLE.",
		Vector2(452.0, 246.0),
		Vector2(160.0, 22.0),
		6,
		MUTED_COLOR
	)

	_add_label("SOURCE BAY", Vector2(64.0, 238.0), Vector2(52.0, 9.0), 6, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("RECORD LAMP", Vector2(20.0, 248.0), Vector2(70.0, 9.0), 6, MUTED_COLOR)
	_add_label("LINK / PULSE", Vector2(190.0, 248.0), Vector2(80.0, 9.0), 6, MUTED_COLOR)
	_target_caption = _add_label(
		"TARGET SOCKET / PENDING",
		Vector2(300.0, 248.0),
		Vector2(104.0, 9.0),
		6,
		WARN_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	_add_label("LIVE STATE", Vector2(20.0, 288.0), Vector2(120.0, 10.0), 8, CYAN_COLOR)
	_state_label = _add_label("", Vector2(20.0, 299.0), Vector2(414.0, 12.0), 8, TEXT_COLOR)
	_detail_label = _add_label("", Vector2(20.0, 314.0), Vector2(414.0, 34.0), 7, MUTED_COLOR)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_controls_label = _add_label(
		"SPACE  send / flip request\nP      pause (freezes transfer)\nR      reset demo\nESC    quit",
		Vector2(452.0, 289.0),
		Vector2(170.0, 48.0),
		7,
		MUTED_COLOR
	)
	_controls_label.add_theme_color_override("font_color", MUTED_COLOR)


func _refresh_status(force: bool = false) -> void:
	if _link == null or _state_label == null:
		return
	var recorded_name: String = _polarity_name(_link.record_positive)
	var state_text: String = "RECORDED: %s   |   " % recorded_name
	if _link.is_transfer_active():
		state_text += "TRANSFER: %s  %d%% -> TARGET" % [
			_polarity_name(_link.get_transfer_polarity()),
			int(round(_link.get_transfer_progress() * 100.0)),
		]
	elif _link.is_arrival_flash_active():
		state_text += "DELIVERED: %s" % recorded_name
	else:
		state_text += "IDLE"
	if get_tree().paused:
		state_text += "   |   PAUSED"

	var detail_text: String = _target_detail_text()
	if not _target_event_text.is_empty():
		detail_text += " " + _target_event_text
	if _state_label.text != state_text:
		_state_label.text = state_text
	if _detail_label.text != detail_text:
		_detail_label.text = detail_text
	_detail_label.add_theme_color_override(
		"font_color",
		MUTED_COLOR if _target_mode == "rune" else WARN_COLOR
	)
	_refresh_target_caption()
	_last_status_key = "%s|%s|%s|%s|%s|%s|%s" % [
		str(_link.record_positive),
		str(_link.is_transfer_active()),
		str(_link.is_arrival_flash_active()),
		str(int(round(_link.get_transfer_progress() * 100.0))),
		str(get_tree().paused),
		_target_mode,
		_target_event_text,
	]
	if force:
		queue_redraw()


func _target_detail_text() -> String:
	match _target_mode:
		"rune":
			return (
				"TARGET: RuneStoneVisual loaded. Delivery calls set_polarity(positive) "
				+ "so the stone can darken then re-light."
			)
		"missing_art":
			return (
				"TARGET: rune scene present, but its art is missing or not imported. "
				+ "Its own dashed placeholder is shown; no completed stone effect is claimed."
			)
		"missing_api":
			return (
				"TARGET: rune scene is present but set_polarity() is missing. "
				+ "Integration is incomplete; no fake response is shown."
			)
		"invalid":
			return (
				"TARGET: rune scene exists but could not be instantiated as Node2D. "
				+ "No fake stone is shown."
			)
		_:
			return (
				"TARGET: rune stone visual is not present. The dashed socket is a "
				+ "labelled placeholder, not a completed stone effect."
			)


func _refresh_target_caption() -> void:
	if _target_caption == null:
		return
	match _target_mode:
		"rune":
			_target_caption.text = "TARGET: RUNE STONE"
			_target_caption.add_theme_color_override("font_color", CYAN_COLOR)
		"missing_art":
			_target_caption.text = "TARGET: ART MISSING"
			_target_caption.add_theme_color_override("font_color", WARN_COLOR)
		"missing_api":
			_target_caption.text = "TARGET: API MISSING"
			_target_caption.add_theme_color_override("font_color", WARN_COLOR)
		"invalid":
			_target_caption.text = "TARGET: INVALID SCENE"
			_target_caption.add_theme_color_override("font_color", WARN_COLOR)
		_:
			_target_caption.text = "TARGET SOCKET / PENDING"
			_target_caption.add_theme_color_override("font_color", WARN_COLOR)


func _on_visual_delivery_finished(positive: bool) -> void:
	var polarity: String = _polarity_name(positive)
	if _target_mode == "rune" and _rune != null and _rune.has_method("set_polarity"):
		_rune.call("set_polarity", positive, false)
		_target_event_text = "LAST DELIVERY: %s -> set_polarity(%s, false)." % [polarity, str(positive)]
		print("PREVIEW_DELIVERY positive=%s target=set_polarity" % str(positive))
	elif _target_mode == "missing_art":
		_target_event_text = "LAST DELIVERY: %s; target art missing, no colour change claimed." % polarity
		print("PREVIEW_DELIVERY positive=%s target=missing_art" % str(positive))
	else:
		_target_event_text = "LAST DELIVERY: %s; no usable target rune (visual only)." % polarity
		print("PREVIEW_DELIVERY positive=%s target=none" % str(positive))
	_refresh_status(true)


func _on_rune_transition_finished(positive: bool) -> void:
	print("PREVIEW_RUNE_TRANSITION_FINISHED positive=%s" % str(positive))


func _polarity_name(positive: bool) -> String:
	return "GOLD (+)" if positive else "CYAN (-)"


func _add_label(
	text: String,
	at: Vector2,
	box_size: Vector2,
	font_size: int,
	color: Color,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	# Theme overrides must be applied before size: otherwise the Label clamps
	# its requested box to the default-font minimum, then keeps that oversized
	# rect after the smaller font is applied. That was the first screenshot's
	# clipped/shifted caption bug. The size is applied after add_child so the
	# Label has resolved the overridden minimum size in the tree.
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	label.position = at
	label.size = box_size
	return label


func _collect_label_text(node: Node, lines: PackedStringArray) -> void:
	for child: Node in node.get_children():
		if child is Label:
			lines.append((child as Label).text)
		_collect_label_text(child, lines)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)

	# Sparse 32 px lab grid.
	for x: int in range(0, int(size.x) + 1, 32):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), size.y), GRID_COLOR, 1.0)
	for y: int in range(0, int(size.y) + 1, 32):
		draw_line(Vector2(0.0, float(y)), Vector2(size.x, float(y)), GRID_COLOR, 1.0)

	draw_rect(Rect2(0.0, 0.0, size.x, 48.0), HEADER_COLOR)
	draw_line(Vector2(0.0, 48.0), Vector2(size.x, 48.0), BORDER_COLOR, 1.0)

	draw_rect(STAGE_RECT, PANEL_COLOR)
	draw_rect(STAGE_RECT, BORDER_COLOR, false, 1.0)
	draw_rect(DETAIL_RECT, PANEL_COLOR)
	draw_rect(DETAIL_RECT, BORDER_COLOR, false, 1.0)
	draw_rect(BOTTOM_RECT, PANEL_COLOR)
	draw_line(Vector2(0.0, 282.0), Vector2(size.x, 282.0), BORDER_COLOR, 1.0)
	draw_line(Vector2(436.0, 288.0), Vector2(436.0, 352.0), BORDER_COLOR, 1.0)

	# Stage floor. The line is the 1x ground; the short ticks are scale marks.
	draw_rect(Rect2(16.0, GROUND_Y, 414.0, 42.0), PANEL_INNER)
	draw_line(Vector2(24.0, GROUND_Y), Vector2(422.0, GROUND_Y), BORDER_COLOR, 1.0)
	for x: int in range(24, 422, 16):
		draw_line(Vector2(float(x), GROUND_Y), Vector2(float(x), GROUND_Y + 3.0), GRID_COLOR, 1.0)

	# Inspection card frames. The lamp pixels themselves are the real component
	# instances added as Node2D children in _build_lamp_inspection().
	draw_rect(Rect2(452.0, 82.0, 166.0, 76.0), PANEL_INNER)
	draw_rect(Rect2(452.0, 82.0, 166.0, 76.0), BORDER_COLOR, false, 1.0)
	draw_rect(Rect2(452.0, 162.0, 166.0, 76.0), PANEL_INNER)
	draw_rect(Rect2(452.0, 162.0, 166.0, 76.0), BORDER_COLOR, false, 1.0)
	draw_line(Vector2(452.0, 242.0), Vector2(618.0, 242.0), BORDER_COLOR, 1.0)

	if _show_target_placeholder:
		_draw_pending_socket()


func _draw_pending_socket() -> void:
	var warn: Color = WARN_COLOR
	warn.a = 0.55
	var faint: Color = WARN_COLOR
	faint.a = 0.10
	draw_rect(TARGET_PLACEHOLDER_RECT, faint)
	var x0: int = int(TARGET_PLACEHOLDER_RECT.position.x)
	var y0: int = int(TARGET_PLACEHOLDER_RECT.position.y)
	var x1: int = int(TARGET_PLACEHOLDER_RECT.end.x) - 1
	var y1: int = int(TARGET_PLACEHOLDER_RECT.end.y) - 1
	for x: int in range(x0, x1 + 1, 4):
		draw_rect(Rect2(float(x), float(y0), 2.0, 1.0), warn)
		draw_rect(Rect2(float(x), float(y1), 2.0, 1.0), warn)
	for y: int in range(y0, y1 + 1, 4):
		draw_rect(Rect2(float(x0), float(y), 1.0, 2.0), warn)
		draw_rect(Rect2(float(x1), float(y), 1.0, 2.0), warn)
	# Four corner ticks make this read as a socket, not as a rune-stone sprite.
	draw_rect(Rect2(float(x0 - 1), float(y0 - 1), 4.0, 1.0), warn)
	draw_rect(Rect2(float(x1 - 2), float(y1 + 1), 4.0, 1.0), warn)
	draw_rect(Rect2(float(x0 - 1), float(y0 - 1), 1.0, 4.0), warn)
	draw_rect(Rect2(float(x1 + 1), float(y1 - 2), 1.0, 4.0), warn)


func _capture_requested() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return args.has("--capture-preview")


func _run_capture() -> int:
	if DisplayServer.get_name() == "headless":
		printerr("PREVIEW_CAPTURE_FAILED requires a real display")
		return 2
	if _link == null:
		printerr("PREVIEW_CAPTURE_FAILED link component missing")
		return 1

	# Freeze a real mid-transfer frame for the screenshot: cyan pulse from a bay
	# whose record lamp is still gold. This shows both polarities without
	# drawing a fake completed target.
	_link.play_transfer(false)
	_link.advance_transfer(_link.transfer_duration * 0.56)
	_link.set_process(false)
	_refresh_status(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		printerr("PREVIEW_CAPTURE_FAILED viewport image is null")
		return 1
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)

	var directory: String = ProjectSettings.globalize_path("res://screenshots")
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		printerr("PREVIEW_CAPTURE_FAILED cannot create %s error=%d" % [directory, dir_error])
		return 1
	var absolute_path: String = ProjectSettings.globalize_path(CAPTURE_PATH)
	var save_error: Error = image.save_png(absolute_path)
	if save_error != OK:
		printerr("PREVIEW_CAPTURE_FAILED %s error=%d" % [CAPTURE_PATH, save_error])
		return 1
	print("PREVIEW_CAPTURED %s size=%s" % [CAPTURE_PATH, str(image.get_size())])

	var pixel_check: Dictionary = check_rendered_preview(image)
	_print_pixel_result("normal", pixel_check)

	var negative_ok: bool = false
	if _bay != null and _bay.get_base_sprite() != null:
		var normal_base: int = int(pixel_check.get("base_light", 0))
		_bay.get_base_sprite().visible = false
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var negative_image: Image = get_viewport().get_texture().get_image()
		if negative_image != null:
			if negative_image.get_size() != CAPTURE_SIZE:
				negative_image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
			var negative_check: Dictionary = check_rendered_preview(negative_image)
			_print_pixel_result("base_hidden_control", negative_check)
			negative_ok = (
				int(negative_check.get("base_light", normal_base))
				< normal_base - 20
			)
		_bay.get_base_sprite().visible = true
		await get_tree().process_frame

	var target_ok: bool = _target_mode == "rune"
	var overall_ok: bool = bool(pixel_check.get("ok", false)) and negative_ok
	print(
		"PREVIEW_CAPTURE_RESULT ok=%s target_mode=%s base_negative_ok=%s"
		% [str(overall_ok), _target_mode, str(negative_ok)]
	)
	if not target_ok:
		print(
			"PREVIEW_TARGET_NOTE rune stone scene absent or art/API incomplete; "
			+ "the target is explicitly labelled. Re-run after the parallel rune "
			+ "asset scene and its textures are ready to verify integration."
		)
	return 0 if overall_ok else 1


static func check_rendered_preview(image: Image) -> Dictionary:
	if image == null:
		return {"ok": false, "reason": "image is null"}
	if image.get_size() != CAPTURE_SIZE:
		return {
			"ok": false,
			"reason": "image size %s, expected %s" % [str(image.get_size()), str(CAPTURE_SIZE)],
		}

	var gold_lamp: int = _count_color_rect(image, POSITIVE_LAMP_RECT, "gold")
	var cyan_lamp: int = _count_color_rect(image, NEGATIVE_LAMP_RECT, "cyan")
	var main_lamp: int = _count_color_rect(image, MAIN_LAMP_RECT, "gold")
	var pulse: int = _count_color_rect(image, PULSE_CHECK_RECT, "cyan")
	var base_light: int = _count_light_rect(image, BASE_CHECK_RECT)
	var ok: bool = (
		gold_lamp >= 60
		and cyan_lamp >= 60
		and main_lamp >= 8
		and pulse >= 3
		and base_light >= 50
	)
	return {
		"ok": ok,
		"gold_lamp": gold_lamp,
		"cyan_lamp": cyan_lamp,
		"main_lamp": main_lamp,
		"pulse": pulse,
		"base_light": base_light,
		"positive_rect": POSITIVE_LAMP_RECT,
		"negative_rect": NEGATIVE_LAMP_RECT,
		"main_lamp_rect": MAIN_LAMP_RECT,
		"pulse_rect": PULSE_CHECK_RECT,
		"base_rect": BASE_CHECK_RECT,
	}


static func _count_color_rect(image: Image, rect: Rect2i, kind: String) -> int:
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.5:
				continue
			if kind == "gold" and _is_gold(color):
				count += 1
			elif kind == "cyan" and _is_cyan(color):
				count += 1
	return count


static func _count_light_rect(image: Image, rect: Rect2i) -> int:
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.5 and maxf(color.r, maxf(color.g, color.b)) > 0.55:
				count += 1
	return count


static func _is_gold(color: Color) -> bool:
	return color.r > 0.62 and color.g > 0.48 and color.b < 0.62 and color.r > color.b + 0.18


static func _is_cyan(color: Color) -> bool:
	return color.g > 0.50 and color.b > 0.50 and color.r < 0.62 and color.b > color.r + 0.12


func _print_pixel_result(label: String, result: Dictionary) -> void:
	print(
		"PREVIEW_PIXEL_CHECK %s gold_lamp=%d cyan_lamp=%d main_lamp=%d pulse=%d base_light=%d ok=%s"
		% [
			label,
			int(result.get("gold_lamp", 0)),
			int(result.get("cyan_lamp", 0)),
			int(result.get("main_lamp", 0)),
			int(result.get("pulse", 0)),
			int(result.get("base_light", 0)),
			str(result.get("ok", false)),
		]
	)
