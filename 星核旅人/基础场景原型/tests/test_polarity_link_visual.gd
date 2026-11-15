extends Node

## Independent headless acceptance test for PolarityLinkVisual, its scene, and
## the standalone preview. It does not exercise gameplay, bay storage, force
## fields, or the default main scene.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_polarity_link_visual.tscn
##
## The real-GUI screenshot and its pixel checks are produced by:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_polarity_link.tscn -- --capture-preview

const LINK_SCENE: PackedScene = preload("res://scenes/polarity_link_visual.tscn")
const PREVIEW_SCENE: PackedScene = preload("res://tools/preview_polarity_link.tscn")
const BAY_SCENE: PackedScene = preload("res://scenes/star_core_bay_visual.tscn")

const BAY_RECT: Rect2 = Rect2(-16.0, -16.0, 32.0, 32.0)
const BAY_PEDESTAL_RECT: Rect2 = Rect2(-16.0, 8.0, 32.0, 8.0)
const LOCK_MARK_RECT: Rect2 = Rect2(4.0, 11.0, 4.0, 3.0)
const POSITIVE_COLOR: Color = Color("#f4cd63")
const NEGATIVE_COLOR: Color = Color("#5fe1e6")
const LOCKED_PURPLE: Color = Color("#c8a7f2")

var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0
var _log_lines: Array[String] = []

var _link: PolarityLinkVisual
var _deliveries: Array[bool] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - polarity link visual test")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	_test_project_settings()
	await _test_component_contract()
	await _test_anchor_alignment()
	await _test_lamp_contract()
	await _test_transfer_and_signal()
	await _test_last_request_wins()
	await _test_pause_and_stop()
	await _test_no_node_accumulation()
	await _test_preview()
	get_tree().paused = false
	_finish()


func _test_project_settings() -> void:
	_section("PROJECT SETTINGS")
	_check(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
		"logic viewport stays 640x360"
	)
	_check(
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"project default texture filter stays nearest"
	)


func _test_component_contract() -> void:
	_section("COMPONENT CONTRACT")
	_link = LINK_SCENE.instantiate() as PolarityLinkVisual
	_check(_link != null, "polarity link scene instantiates as PolarityLinkVisual")
	if _link == null:
		return
	_link.name = "TestPolarityLink"
	add_child(_link)
	await get_tree().process_frame
	_link.visual_delivery_finished.connect(_on_visual_delivery_finished)
	_link.stop_transfer()
	_link.set_process(false)

	_check(_link is Node2D, "root is Node2D")
	_check(_link.get_script() != null and _link.get_script().is_tool(), "script is @tool")
	_check(_link.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "root uses nearest filtering")
	_check(_link.z_index == 4, "overlay z_index is non-negative and above bay layers", str(_link.z_index))
	_check(_link.has_signal("visual_delivery_finished"), "visual_delivery_finished signal exists")
	_check(_link.has_method("play_transfer"), "play_transfer() exists")
	_check(_link.has_method("stop_transfer"), "stop_transfer() exists")
	_check(_count_physics_nodes(_link) == 0, "component owns no physics nodes")
	_check(_link.get_child_count() == 0, "component is self-drawn with no child-node accumulation", str(_link.get_child_count()))

	var exports: Dictionary = {}
	for property: Dictionary in _link.get_property_list():
		exports[String(property.name)] = true
	for required: String in [
		"record_positive",
		"source_path",
		"target_path",
		"source_position",
		"target_position",
		"link_source_offset",
		"link_target_offset",
		"record_lamp_offset",
		"show_link_guide",
		"show_record_lamp",
		"transfer_duration",
	]:
		_check(exports.has(required), "inspector export present: %s" % required)

	_check(_link.record_positive, "record_positive defaults to true")
	_check(_link.get_record_symbol() == &"plus", "positive lamp symbol is plus")
	_check(_link.get_record_lamp_accent_color() == POSITIVE_COLOR, "positive lamp uses the gold palette")
	_check(_link.get_record_lamp_accent_color() != LOCKED_PURPLE, "recorded polarity is not purple")
	_link.record_positive = false
	_check(_link.get_record_symbol() == &"minus", "negative lamp symbol is minus")
	_check(_link.get_record_lamp_accent_color() == NEGATIVE_COLOR, "negative lamp uses the cyan palette")
	_check(_link.get_record_lamp_accent_color() != LOCKED_PURPLE, "negative lamp is not purple")
	_link.record_positive = true
	_check(not _link.is_transfer_active(), "component begins idle")


func _test_anchor_alignment() -> void:
	_section("ANCHOR ALIGNMENT")
	if _link == null:
		return
	var holder: Node2D = Node2D.new()
	holder.position = Vector2(40.0, 20.0)
	add_child(holder)
	var source: Node2D = Node2D.new()
	source.position = Vector2(100.0, 120.0)
	holder.add_child(source)
	var target: Node2D = Node2D.new()
	target.position = Vector2(340.0, 150.0)
	holder.add_child(target)

	var linked: PolarityLinkVisual = LINK_SCENE.instantiate() as PolarityLinkVisual
	linked.position = Vector2(10.0, 5.0)
	holder.add_child(linked)
	await get_tree().process_frame
	linked.source_path = linked.get_path_to(source)
	linked.target_path = linked.get_path_to(target)
	linked.link_source_offset = Vector2(2.0, 3.0)
	linked.link_target_offset = Vector2(-2.0, -4.0)

	_check(linked.get_source_origin().is_equal_approx(linked.to_local(source.global_position)),
		"source node path resolves to the source origin")
	_check(linked.get_target_origin().is_equal_approx(linked.to_local(target.global_position)),
		"target node path resolves to the target origin")
	_check(
		linked.get_link_source_global().is_equal_approx(source.global_position + Vector2(2.0, 3.0)),
		"source link point equals the node position plus the source offset"
	)
	_check(
		linked.get_link_target_global().is_equal_approx(target.global_position + Vector2(-2.0, -4.0)),
		"target link point equals the node position plus the target offset"
	)

	source.position = Vector2(120.0, 90.0)
	_check(
		linked.get_link_source_global().is_equal_approx(source.global_position + Vector2(2.0, 3.0)),
		"moving the linked source updates the resolved link point"
	)

	linked.source_path = NodePath()
	linked.target_path = NodePath()
	linked.position = Vector2(100.0, 50.0)
	linked.source_position = Vector2(10.0, 20.0)
	linked.target_position = Vector2(200.0, 70.0)
	linked.link_source_offset = Vector2(1.0, 2.0)
	linked.link_target_offset = Vector2(3.0, 4.0)
	_check(
		linked.get_link_source_global().is_equal_approx(linked.to_global(Vector2(11.0, 22.0))),
		"fallback source position works without node paths"
	)
	_check(
		linked.get_link_target_global().is_equal_approx(linked.to_global(Vector2(203.0, 74.0))),
		"fallback target position works without node paths"
	)

	holder.queue_free()
	await get_tree().process_frame


func _test_lamp_contract() -> void:
	_section("RECORD LAMP GEOMETRY")
	if _link == null:
		return
	_link.source_path = NodePath()
	_link.target_path = NodePath()
	_link.position = Vector2.ZERO
	_link.source_position = Vector2.ZERO
	_link.target_position = Vector2(160.0, 0.0)
	_link.record_lamp_offset = Vector2(-24.0, 7.0)
	_link.link_source_offset = Vector2(17.0, 12.0)
	_link.link_target_offset = Vector2.ZERO

	var lamp: Rect2 = _link.get_record_lamp_rect()
	_check(lamp == Rect2(-24.0, 7.0, 7.0, 9.0), "default lamp rect is 7x9 at the bay's left", str(lamp))
	_check(not lamp.intersects(BAY_RECT), "record lamp does not cover the 32x32 bay PNG")
	_check(lamp.end.x == BAY_RECT.position.x - 1.0, "record lamp sits one pixel beside the bay, not on it")
	_check(not lamp.intersects(LOCK_MARK_RECT), "record lamp does not cover the existing 4x3 lock mark")
	_check(
		lamp.position.y < BAY_PEDESTAL_RECT.end.y and lamp.end.y > BAY_PEDESTAL_RECT.position.y,
		"record lamp is vertically beside the pedestal"
	)
	_check(_link.get_record_lamp_lens_rect() == Rect2(-23.0, 9.0, 5.0, 5.0),
		"lamp lens is a 5x5 code-drawn area", str(_link.get_record_lamp_lens_rect()))
	_check(_link.get_record_lamp_bracket_rect() == Rect2(-17.0, 10.0, 1.0, 3.0),
		"lamp bracket stays outside the base")
	_check(_link.get_record_lamp_center() == Vector2(-20.5, 11.5), "lamp center is deterministic")
	_check(lamp.position.x >= -32.0 and lamp.end.x <= 0.0, "lamp remains inside a 32 px left-side margin")
	_check(_link.get_badge_color(true) == POSITIVE_COLOR and _link.get_badge_color(false) == NEGATIVE_COLOR,
		"both record colours come from the shared gold/cyan palette")


func _test_transfer_and_signal() -> void:
	_section("TRANSFER DIRECTION AND COMPLETION")
	if _link == null:
		return
	_deliveries.clear()
	_link.stop_transfer()
	_link.source_path = NodePath()
	_link.target_path = NodePath()
	_link.position = Vector2.ZERO
	_link.source_position = Vector2(20.0, 100.0)
	_link.target_position = Vector2(220.0, 100.0)
	_link.link_source_offset = Vector2.ZERO
	_link.link_target_offset = Vector2.ZERO
	_link.link_arc_height = 0.0
	_link.transfer_duration = 0.5
	_link.record_positive = true
	get_tree().paused = false

	_link.play_transfer(false)
	_check(_link.is_transfer_active(), "play_transfer starts an active visual transfer")
	_check(is_equal_approx(_link.get_transfer_progress(), 0.0), "transfer starts at the source")
	_check(not _link.get_transfer_polarity(), "requested transfer polarity is negative")
	_check(_link.get_pulse_color() == NEGATIVE_COLOR, "negative transfer pulse is cyan")
	_check(_link.record_positive, "record lamp stays on the old state until delivery")
	_check(_link.get_record_lamp_accent_color() == POSITIVE_COLOR, "old gold lamp stays visible during transfer")
	_check(_link.get_pulse_position().is_equal_approx(Vector2(20.0, 100.0)), "pulse starts at source anchor")

	_link.advance_transfer(0.25)
	_check(is_equal_approx(_link.get_transfer_progress(), 0.5), "half duration gives half progress")
	var mid: Vector2 = _link.get_pulse_position()
	_check(mid.x > 20.0 and mid.x < 220.0, "pulse travels left-to-right from source to target", str(mid))
	_check(mid.is_equal_approx(Vector2(120.0, 100.0)), "half progress sits at the line midpoint")
	_check(_deliveries.is_empty(), "no signal before the pulse reaches the target")

	_link.advance_transfer(0.125)
	var late_mid: Vector2 = _link.get_pulse_position()
	_check(late_mid.distance_to(Vector2(220.0, 100.0)) < late_mid.distance_to(Vector2(20.0, 100.0)),
		"pulse is closer to the target at three-quarter progress")
	_link.advance_transfer(0.125)
	_check(not _link.is_transfer_active(), "transfer is inactive at the target")
	_check(is_equal_approx(_link.get_transfer_progress(), 1.0), "progress reaches 1.0")
	_check(_deliveries.size() == 1, "completion signal emitted exactly once", str(_deliveries.size()))
	_check(not _deliveries.is_empty() and not _deliveries[0], "completion signal carries the negative polarity")
	_check(not _link.record_positive, "record lamp changes to negative on delivery")
	_check(_link.get_record_lamp_accent_color() == NEGATIVE_COLOR, "lamp lens is cyan after negative delivery")
	_check(not _link.get_last_delivered_positive(), "last delivery remembers negative")
	_check(_link.is_arrival_flash_active(), "short arrival glint starts on delivery")

	_link.advance_transfer(0.2)
	_check(not _link.is_arrival_flash_active(), "arrival glint is short and ends")
	_check(_deliveries.size() == 1, "arrival fade emits no extra completion")

	_link.play_transfer(true)
	_link.advance_transfer(0.25)
	_check(_link.get_pulse_color() == POSITIVE_COLOR, "positive transfer pulse is gold")
	_link.advance_transfer(0.26)
	_check(_deliveries.size() == 2 and _deliveries[1], "positive completion is delivered once with true")
	_check(_link.record_positive and _link.get_last_delivered_positive(), "lamp and history return to positive")


func _test_last_request_wins() -> void:
	_section("REPEATED CALLS: LAST REQUEST WINS")
	if _link == null:
		return
	_deliveries.clear()
	_link.stop_transfer()
	_link.record_positive = false
	_link.transfer_duration = 0.4
	get_tree().paused = false

	_link.play_transfer(true)
	_link.advance_transfer(0.2)
	_check(is_equal_approx(_link.get_transfer_progress(), 0.5), "first request is halfway")
	_link.play_transfer(false)
	_check(is_equal_approx(_link.get_transfer_progress(), 0.0), "a newer request restarts at the source")
	_check(not _link.get_transfer_polarity(), "newest request polarity is retained")
	_link.advance_transfer(0.2)
	_check(_deliveries.is_empty(), "abandoned request emits no completion")

	_link.play_transfer(true)
	_check(is_equal_approx(_link.get_transfer_progress(), 0.0), "third request restarts again")
	_link.advance_transfer(0.2)
	_check(_deliveries.is_empty(), "no intermediate completion while the final request is in flight")
	_link.advance_transfer(0.21)
	_check(_deliveries.size() == 1 and _deliveries[0], "only the final request completes, with true", str(_deliveries))
	_link.advance_transfer(0.2)
	_check(_deliveries.size() == 1, "no stale completion arrives later")


func _test_pause_and_stop() -> void:
	_section("PAUSE AND STOP")
	if _link == null:
		return
	_deliveries.clear()
	_link.stop_transfer()
	_link.record_positive = false
	_link.transfer_duration = 0.4
	get_tree().paused = false

	_link.play_transfer(true)
	_link.advance_transfer(0.1)
	var before_pause: float = _link.get_transfer_progress()
	_check(before_pause > 0.0 and before_pause < 1.0, "transfer is in flight before pause")
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(_link.get_transfer_progress(), before_pause), "tree pause freezes visual progress")
	_link.advance_transfer(0.4)
	_check(is_equal_approx(_link.get_transfer_progress(), before_pause), "fixed-delta advance also respects pause")
	_check(_deliveries.is_empty(), "pause emits no completion")
	get_tree().paused = false
	_link.advance_transfer(0.31)
	_check(_deliveries.size() == 1 and _deliveries[0], "transfer completes after unpause")

	_deliveries.clear()
	_link.stop_transfer()
	_link.record_positive = false
	_link.play_transfer(true)
	_link.advance_transfer(0.1)
	var lamp_before_stop: Color = _link.get_record_lamp_accent_color()
	var lamp_rect_before_stop: Rect2 = _link.get_record_lamp_rect()
	_link.stop_transfer()
	_check(not _link.is_transfer_active(), "stop_transfer clears the active transfer")
	_check(is_equal_approx(_link.get_transfer_progress(), 0.0), "stop_transfer resets progress")
	_check(_link.get_record_lamp_rect() == lamp_rect_before_stop, "stop_transfer leaves the lamp in place")
	_check(_link.get_record_lamp_accent_color() == lamp_before_stop, "stop_transfer does not invent a new record state")
	_link.advance_transfer(0.5)
	_check(_deliveries.is_empty(), "stop_transfer emits no completion")
	_check(not _link.is_arrival_flash_active(), "stop_transfer clears the arrival glint")
	get_tree().paused = false


func _test_no_node_accumulation() -> void:
	_section("NO NODE ACCUMULATION")
	if _link == null:
		return
	var nodes_before: int = _count_nodes(_link)
	var children_before: int = _link.get_child_count()
	for index: int in range(24):
		_link.play_transfer(index % 2 == 0)
		_link.advance_transfer(0.01)
	_check(_count_nodes(_link) == nodes_before, "repeated transfers create no extra nodes", str(_count_nodes(_link)))
	_check(_link.get_child_count() == children_before, "child count stays constant")
	_link.stop_transfer()
	_check(not _link.is_transfer_active(), "final stop leaves the test node idle")


func _test_preview() -> void:
	_section("PREVIEW AND OPTIONAL RUNE INTEGRATION")
	var preview: Control = PREVIEW_SCENE.instantiate() as Control
	_check(preview != null, "preview scene instantiates as Control")
	if preview == null:
		return
	add_child(preview)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(preview.size.is_equal_approx(Vector2(640.0, 360.0)), "preview is 640x360", str(preview.size))
	var preview_link: PolarityLinkVisual = preview.get_link_component()
	var preview_bay: StarCoreBayVisual = preview.get_bay_component()
	_check(preview_link != null, "preview contains a real PolarityLinkVisual")
	_check(preview_bay != null, "preview contains the existing StarCoreBayVisual")
	if preview_link != null and preview_bay != null:
		_check(preview_link.get_node_or_null(preview_link.source_path) == preview_bay,
			"preview link source path points at the existing bay")
		_check(preview_bay.get_core_visual() != null and preview_bay.get_core_visual().state == StarCoreVisual.CoreState.LOCKED,
			"preview bay keeps the existing purple LOCKED core")
		_check(not preview_link.is_transfer_active(), "preview begins idle")

	var text: String = preview.get_ui_text()
	_check(text.contains("VISUAL ONLY"), "preview labels itself as visual only")
	_check(text.contains("NOT GAMEPLAY"), "preview labels itself as not gameplay")
	_check(text.contains("SPACE"), "preview documents the SPACE demo control")
	_check(text.contains("4x LAMP INSPECTION"), "preview contains the 4x lamp inspection panel")

	var positive_chip: PolarityLinkVisual = _find_link_named(preview, "PositiveLamp4x")
	var negative_chip: PolarityLinkVisual = _find_link_named(preview, "NegativeLamp4x")
	_check(positive_chip != null and positive_chip.record_positive, "4x positive lamp is a real gold component instance")
	_check(negative_chip != null and not negative_chip.record_positive, "4x negative lamp is a real cyan component instance")
	if positive_chip != null:
		_check(positive_chip.scale == Vector2(4.0, 4.0), "positive lamp inspection uses integer 4x nearest scaling")
	if negative_chip != null:
		_check(negative_chip.scale == Vector2(4.0, 4.0), "negative lamp inspection uses integer 4x nearest scaling")

	if preview_link != null:
		var space_event: InputEventKey = InputEventKey.new()
		space_event.physical_keycode = KEY_SPACE
		space_event.pressed = true
		preview._input(space_event)
		_check(preview_link.is_transfer_active(), "SPACE starts the visual transfer in the preview")
		preview_link.stop_transfer()

	var mode: String = preview.get_target_mode()
	_check(
		mode in ["rune", "pending", "missing_art", "missing_api", "invalid"],
		"preview reports a supported target state",
		mode
	)
	if mode == "pending":
		_check(preview.get_target_visual() == null, "missing rune art leaves no fake rune node")
		_check(preview.is_target_placeholder_explicit(), "missing rune art is an explicit placeholder")
		_check(preview.get_target_status_text().contains("not present"), "missing rune art is named in the status")
		_check(text.contains("PENDING"), "pending target is labelled in the preview")
		_log("TARGET_INTEGRATION_PENDING res://scenes/rune_stone_visual.tscn is not present; no integration claim made.")
	elif mode == "rune":
		var rune: Node2D = preview.get_target_visual()
		_check(rune != null and rune.has_method("set_polarity"),
			"loaded rune scene exposes set_polarity()")
		_check(preview_link != null and preview_link.get_node_or_null(preview_link.target_path) == rune,
			"preview link target path points at the loaded rune")
		_check(preview.get_target_status_text().contains("set_polarity"),
			"loaded rune integration is documented in the preview status")
		if rune != null and preview_link != null and rune.has_method("set_polarity"):
			preview_link.record_positive = true
			preview_link.play_transfer(false)
			preview_link.advance_transfer(preview_link.transfer_duration + 0.01)
			_check(preview.get_ui_text().contains("LAST DELIVERY"),
				"visual_delivery_finished reaches the preview integration callback")
			var polarity_value: Variant = rune.get("polarity_positive")
			if polarity_value != null:
				_check(not bool(polarity_value), "delivery passes the negative polarity into set_polarity()")
			if rune.has_method("is_transitioning"):
				_check(bool(rune.call("is_transitioning")),
					"delivered rune starts its short dark/relight transition")
	elif mode == "missing_art":
		_check(preview.get_target_visual() == null, "missing rune art does not show a half-finished target")
		_check(preview.is_target_placeholder_explicit(), "missing rune art is explicitly labelled")
		_check(preview.get_target_status_text().contains("art is missing"),
			"missing rune art is named in the status")
		_check(not preview.get_target_status_text().contains("loaded. Delivery"),
			"missing rune art does not claim a completed integration")
		_log("TARGET_INTEGRATION_ART_PENDING rune scene exists but its texture dependencies are not imported.")
	else:
		_check(preview.get_target_status_text().contains("incomplete") or preview.get_target_status_text().contains("No fake"),
			"incomplete rune integration is explicitly warned")
		_check(not preview.is_target_placeholder_explicit() or preview.get_target_visual() == null,
			"incomplete rune state does not pretend to be a finished target")

	preview.queue_free()
	await get_tree().process_frame


func _on_visual_delivery_finished(positive: bool) -> void:
	_deliveries.append(positive)


func _find_link_named(node: Node, desired_name: String) -> PolarityLinkVisual:
	for child: Node in node.get_children():
		if child is PolarityLinkVisual and String(child.name) == desired_name:
			return child as PolarityLinkVisual
		var found: PolarityLinkVisual = _find_link_named(child, desired_name)
		if found != null:
			return found
	return null


func _count_physics_nodes(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is CollisionObject2D or child is Area2D or child is CollisionShape2D:
			count += 1
		count += _count_physics_nodes(child)
	return count


func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("PASS  %s%s" % [label, "" if detail.is_empty() else "  [%s]" % detail])
	else:
		_fail_count += 1
		_log("FAIL  %s%s" % [label, "" if detail.is_empty() else "  [%s]" % detail])


func _section(name: String) -> void:
	_log("")
	_log("== %s ==" % name)


func _log(line: String) -> void:
	_log_lines.append(line)


func _finish() -> void:
	var log_path: String = "res://tests/logs/polarity_link_visual_test.log"
	var directory: String = ProjectSettings.globalize_path("res://tests/logs")
	DirAccess.make_dir_recursive_absolute(directory)
	_log("")
	_log("SUMMARY passed=%d failed=%d skipped=%d" % [_pass_count, _fail_count, _skip_count])
	var file: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()

	print(
		"POLARITY_LINK_TEST_RESULT passed=%d failed=%d skipped=%d log=%s"
		% [_pass_count, _fail_count, _skip_count, log_path]
	)
	get_tree().quit(0 if _fail_count == 0 else 1)
