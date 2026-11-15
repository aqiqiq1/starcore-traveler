extends Node

## Independent acceptance test for RuneStoneField.
##
## Run:
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/test_rune_stone_field.tscn
##
## This scene is separate from test_runner.tscn. It verifies the force sample,
## layer-1 occlusion and RID exclusion, polarity commit timing, pause, reset,
## superseded requests, debug drawing availability, and inspector exports.

const FIELD_SCENE: PackedScene = preload("res://scenes/rune_stone_field.tscn")
const VISUAL_SCENE_PATH: String = "res://scenes/rune_stone_visual.tscn"
const LOG_PATH: String = "res://tests/logs/rune_stone_field_test.log"

var _world: Node2D
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []
var _committed: Array[bool] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_world = Node2D.new()
	_world.name = "FieldTestWorld"
	add_child(_world)

	_log("Star Core Traveler - independent RuneStoneField test")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	await _test_scene_contract()
	await _test_force_math_and_limits()
	await _test_occlusion_and_rid_exclusion()
	await _test_polarity_commit_timing()
	await _test_superseded_requests_and_reset()
	await _test_pause_freezes_transition()
	await _test_exported_configuration()
	await _test_inactive_first_light_up()
	await _test_inactive_override_cancel_and_reset()
	await _finish()


func _test_scene_contract() -> void:
	_section("SCENE / INTERFACE CONTRACT")
	await _clear_world()
	var field: RuneStoneField = await _spawn_field(Vector2(320.0, 200.0), true)

	_check(field != null, "scene instantiates as RuneStoneField")
	if field == null:
		return
	_check(field is Node2D, "component root is Node2D")
	var script: Script = field.get_script() as Script
	_check(script != null and script.is_tool(), "script is @tool for editor drag/drop")
	_check(
		script != null and script.get_global_name() == &"RuneStoneField",
		"global class_name is RuneStoneField",
		"" if script == null else str(script.get_global_name())
	)
	_check(field.position.is_equal_approx(Vector2(320.0, 200.0)), "position is editable and used")
	_check(field.process_mode == Node.PROCESS_MODE_PAUSABLE, "component is pausable")
	_check(not field.is_processing(), "component has no autonomous process")
	_check(not field.has_method("apply_external_force"), "component never owns a force-application API")
	_check(_count_physics_nodes(field) == 0, "component is not a physical ball and owns no collider")
	_check(field.get_child_count() == 1, "component owns exactly one visual child", str(field.get_child_count()))
	_check(field.is_activated(), "default field is active for existing callers")

	var visual: RuneStoneVisual = field.get_node_or_null("Visual") as RuneStoneVisual
	_check(visual != null, "Visual child is a RuneStoneVisual")
	if visual != null:
		_check(visual.scene_file_path == VISUAL_SCENE_PATH, "visual reuses rune_stone_visual.tscn", visual.scene_file_path)
		_check(visual.polarity_positive, "initial visual polarity is positive")
		_check(visual.is_energized(), "default visual is energized")
		_check(not visual.show_polarity_hint, "hint is hidden before any sample")

	_check(field.has_signal("polarity_committed"), "polarity_committed signal is declared")
	var signal_info: Dictionary = {}
	for info: Dictionary in field.get_signal_list():
		if str(info.name) == "polarity_committed":
			signal_info = info
	var signal_args: Array = signal_info.get("args", [])
	_check(
		signal_args.size() == 1 and str(signal_args[0].get("name", "")) == "positive",
		"polarity_committed carries one positive argument"
	)

	for method_name: String in [
		"sample_field", "request_polarity", "is_positive", "is_activated",
		"cancel_pending_request", "reset_state",
		"set_debug_enabled", "set_polarity_hint_visible",
		"clear_polarity_hint_override",
	]:
		_check(field.has_method(method_name), "%s method exists" % method_name)

	var result: Dictionary = field.sample_field(Vector2(200.0, 225.0), false)
	_check(result.size() == 4, "sample result carries exactly the four contract keys", str(result.keys()))
	for key: String in ["acceleration", "status", "distance", "blocked"]:
		_check(result.has(key), "sample result contains %s" % key)
	_check(result["acceleration"] is Vector2, "acceleration is a Vector2")
	_check(result["distance"] is float, "distance is a float")
	_check(result["blocked"] is bool, "blocked is a bool")
	_check(result["status"] is String, "status is a String")

	var exported_types: Dictionary = {
		"initial_active": TYPE_BOOL,
		"initial_positive": TYPE_BOOL,
		"field_range": TYPE_FLOAT,
		"inner_radius": TYPE_FLOAT,
		"full_radius": TYPE_FLOAT,
		"outer_fade": TYPE_FLOAT,
		"full_acceleration": TYPE_FLOAT,
		"auto_hint_in_range": TYPE_BOOL,
	}
	var exported_seen: Dictionary = {}
	for property: Dictionary in field.get_property_list():
		var property_name: String = str(property.get("name", ""))
		if not exported_types.has(property_name):
			continue
		exported_seen[property_name] = true
		_check(
			(int(property["usage"]) & PROPERTY_USAGE_EDITOR) != 0,
			"%s is exposed to the inspector" % property_name
		)
		_check(
			int(property["type"]) == int(exported_types[property_name]),
			"%s has the expected type" % property_name
		)
	_check(exported_seen.size() == exported_types.size(), "all inspector fields are present", str(exported_seen.keys()))

	_check(is_equal_approx(field.field_range, 160.0), "default range is 160 px")
	_check(is_equal_approx(field.inner_radius, 16.0), "default inner radius is 16 px")
	_check(is_equal_approx(field.full_radius, 52.0), "default full radius is 52 px")
	_check(is_equal_approx(field.outer_fade, 40.0), "default outer fade is 40 px")
	_check(is_equal_approx(field.full_acceleration, 2400.0), "default full acceleration is 2400 px/s^2")
	_check(is_equal_approx(field.get_field_range(), 160.0), "range getter reports the value")
	_check(is_equal_approx(field.get_full_acceleration(), 2400.0), "force getter reports the value")


func _test_force_math_and_limits() -> void:
	_section("FORCE MATH / ZERO / RANGE / HINT")
	await _clear_world()
	var field: RuneStoneField = await _spawn_field(Vector2(320.0, 200.0), true)
	var visual: RuneStoneVisual = field.get_visual()
	var center: Vector2 = Vector2(200.0, 225.0)
	var to_field: Vector2 = field.global_position - center

	var attract: Dictionary = field.sample_field(center, false)
	var attract_acceleration: Vector2 = attract["acceleration"]
	_check(String(attract["status"]) == "ATTRACT", "opposite polarity attracts", String(attract["status"]))
	_check(attract_acceleration.dot(to_field) > 0.0, "attraction points at the stone", str(attract_acceleration))
	_check(attract_acceleration.length() > 1100.0, "full-range attraction beats gravity", "%.1f" % attract_acceleration.length())
	_check(attract_acceleration.length() <= 2400.01, "attraction never exceeds full acceleration", "%.1f" % attract_acceleration.length())
	_check(not bool(attract["blocked"]), "clear line is not blocked")
	_check(absf(float(attract["distance"]) - to_field.length()) < 0.01, "distance is centre-to-centre", "%.2f" % float(attract["distance"]))
	_check(visual.show_polarity_hint, "sample inside range shows the polarity hint")

	var repel: Dictionary = field.sample_field(center, true)
	var repel_acceleration: Vector2 = repel["acceleration"]
	_check(String(repel["status"]) == "REPEL", "same polarity repels", String(repel["status"]))
	_check(repel_acceleration.dot(to_field) < 0.0, "repulsion points away from the stone", str(repel_acceleration))
	_check(
		(attract_acceleration + repel_acceleration).length() < 0.01,
		"attract and repel have equal magnitude and opposite sign"
	)

	var far_center: Vector2 = Vector2(72.0, 273.0)
	var far: Dictionary = field.sample_field(far_center, false)
	_check(String(far["status"]) == "OUT OF RANGE", "outside 160 px is OUT OF RANGE", String(far["status"]))
	_check(far["acceleration"] == Vector2.ZERO, "out-of-range force is zero")
	_check(not bool(far["blocked"]), "out-of-range result is not blocked")
	_check(float(far["distance"]) > 160.0, "out-of-range distance exceeds 160", "%.1f" % float(far["distance"]))
	_check(not visual.show_polarity_hint, "sample outside range hides the polarity hint")

	var zero: Dictionary = field.sample_field(field.global_position, false)
	var zero_force: Vector2 = zero["acceleration"]
	_check(String(zero["status"]) == "NEAR / STABLE", "zero distance reports NEAR / STABLE", String(zero["status"]))
	_check(zero_force == Vector2.ZERO, "zero distance force is neutral")
	_check(is_finite(zero_force.x) and is_finite(zero_force.y), "zero distance never produces NaN")

	var boundary: Dictionary = field.sample_field(field.global_position + Vector2(160.0, 0.0), false)
	_check(String(boundary["status"]) == "OUT OF RANGE", "exactly 160 px is outside the range")
	_check(boundary["acceleration"] == Vector2.ZERO, "boundary force is zero")

	field.set_polarity_hint_visible(true)
	field.sample_field(far_center, false)
	_check(visual.show_polarity_hint, "manual hint control survives an out-of-range sample")
	field.clear_polarity_hint_override()
	_check(not visual.show_polarity_hint, "clearing manual control resumes automatic hiding")

	field.field_range = 100.0
	_check(String(field.sample_field(center, false)["status"]) == "OUT OF RANGE", "inspector range is used by the sample")
	field.field_range = 160.0

	field.full_acceleration = 100.0
	var custom_force: Vector2 = field.sample_field(Vector2(285.0, 200.0), false)["acceleration"]
	_check(custom_force.length() > 0.0 and custom_force.length() <= 100.01, "inspector force scales the sample", "%.2f" % custom_force.length())
	field.full_acceleration = 2400.0

	field.position = Vector2(500.0, 200.0)
	_check(
		String(field.sample_field(center, false)["status"]) == "OUT OF RANGE",
		"moved field uses its new global position"
	)
	field.position = Vector2(320.0, 200.0)
	_check(field.is_positive(), "sampling never changes committed polarity")


func _test_occlusion_and_rid_exclusion() -> void:
	_section("LAYER-1 OCCLUSION / RID / SELF EXCLUSION")
	await _clear_world()
	var field: RuneStoneField = await _spawn_field(Vector2(320.0, 200.0), true)
	var center: Vector2 = Vector2(200.0, 225.0)

	var blocker: StaticBody2D = _add_blocker(Vector2(260.0, 212.5), Vector2(30.0, 30.0), 1)
	await _wait_physics(2)
	var blocked: Dictionary = field.sample_field(center, true)
	_check(bool(blocked["blocked"]), "solid layer-1 body between centres blocks the field")
	_check(String(blocked["status"]) == "BLOCKED", "blocked line reports BLOCKED", String(blocked["status"]))
	_check(blocked["acceleration"] == Vector2.ZERO, "blocked force is zero")
	_check(field.get_visual().show_polarity_hint, "blocked but in-range sample still shows the hint")

	blocker.queue_free()
	await _wait_physics(2)
	_check(not bool(field.sample_field(center, true)["blocked"]), "removing the occluder restores line of sight")

	var off_layer: StaticBody2D = _add_blocker(Vector2(260.0, 212.5), Vector2(30.0, 30.0), 2)
	await _wait_physics(2)
	_check(not bool(field.sample_field(center, true)["blocked"]), "a body on layer 2 does not occlude")
	off_layer.collision_layer = 1
	await _wait_physics(2)
	_check(bool(field.sample_field(center, true)["blocked"]), "the same body occludes after moving to layer 1")
	off_layer.queue_free()
	await _wait_physics(2)

	var proxy: CharacterBody2D = _add_player_proxy(Vector2(230.0, 225.0), Vector2(40.0, 30.0))
	await _wait_physics(2)
	_check(
		bool(field.sample_field(center, true)["blocked"]),
		"an unexcluded player body on the line blocks the ray"
	)
	_check(
		not bool(field.sample_field(center, true, proxy.get_rid())["blocked"]),
		"the caller-supplied player RID is excluded"
	)
	proxy.queue_free()
	await _wait_physics(2)

	var self_body: StaticBody2D = _add_blocker(Vector2.ZERO, Vector2(24.0, 24.0), 1, field)
	await _wait_physics(2)
	_check(
		not bool(field.sample_field(center, true)["blocked"]),
		"the field's own collider cannot occlude its own ray"
	)
	self_body.queue_free()
	await _wait_physics(2)
	_check(not bool(field.sample_field(center, true)["blocked"]), "clear line remains unblocked after cleanup")

	field.set_debug_enabled(true)
	await get_tree().process_frame
	_check(field.is_debug_enabled(), "debug drawing can be enabled for F3")
	field.set_debug_enabled(false)
	await get_tree().process_frame
	_check(not field.is_debug_enabled(), "debug drawing can be disabled again")


func _test_polarity_commit_timing() -> void:
	_section("TRANSITION COMMIT / OLD FORCE UNTIL FINISH")
	await _clear_world()
	var field: RuneStoneField = await _spawn_field(Vector2(320.0, 200.0), true)
	var visual: RuneStoneVisual = field.get_visual()
	field.polarity_committed.connect(_on_polarity_committed)
	var center: Vector2 = Vector2(200.0, 225.0)
	var to_field: Vector2 = field.global_position - center

	var before: Dictionary = field.sample_field(center, false)
	_check(String(before["status"]) == "ATTRACT", "positive stone attracts the cyan player before a request")
	_check(field.is_positive(), "committed polarity starts positive")

	field.request_polarity(false)
	_check(field.is_positive(), "committed polarity stays positive at request time")
	_check(not field.get_requested_positive(), "requested polarity is negative immediately")
	_check(visual.is_transitioning(), "visual dim/relight transition is running")
	_check(visual.get_applied_positive(), "visual still displays the old positive colour")
	_check(_committed.is_empty(), "request does not emit polarity_committed synchronously")
	_check(
		String(field.sample_field(center, false)["status"]) == "ATTRACT",
		"old force sign remains during the transition"
	)

	visual.advance_transition(0.05)
	var elapsed_mid: float = visual.get_transition_elapsed()
	field.request_polarity(false)
	_check(
		is_equal_approx(visual.get_transition_elapsed(), elapsed_mid),
		"repeating the same target mid-transition does not restart the visual"
	)
	_check(_committed.is_empty(), "repeated target still emits nothing")

	visual.advance_transition(visual.transition_duration)
	_check(not visual.is_transitioning(), "transition completes")
	_check(not field.is_positive(), "polarity commits only after transition_finished")
	_check(_committed.size() == 1 and _committed[0] == false, "one polarity_committed(false) is emitted")
	_check(not visual.get_applied_positive(), "visual now displays the negative colour")

	var after: Dictionary = field.sample_field(center, false)
	var after_force: Vector2 = after["acceleration"]
	_check(String(after["status"]) == "REPEL", "force sign flips to REPEL after commit", String(after["status"]))
	_check(after_force.dot(to_field) < 0.0, "committed negative field pushes the cyan player away")

	field.request_polarity(false)
	_check(not visual.is_transitioning(), "same committed polarity request is a visual no-op")
	_check(_committed.size() == 1, "same committed polarity request emits no duplicate signal")

	field.request_polarity(true)
	_check(not field.is_positive(), "reverse request keeps the old negative force until finish")
	_check(String(field.sample_field(center, false)["status"]) == "REPEL", "reverse transition keeps the negative field")
	visual.advance_transition(visual.transition_duration + 0.01)
	_check(field.is_positive(), "reverse transition commits positive")
	_check(_committed.size() == 2 and _committed[1] == true, "reverse transition emits one polarity_committed(true)")
	_check(String(field.sample_field(center, false)["status"]) == "ATTRACT", "force returns to ATTRACT after reverse commit")

	field.request_polarity(true)
	_check(not visual.is_transitioning(), "same positive request after commit is a no-op")
	_check(_committed.size() == 2, "same positive request does not duplicate the signal")


func _test_superseded_requests_and_reset() -> void:
	_section("REQUEST OVERRIDE / STALE COMPLETION / RESET")
	await _clear_world()
	var field: RuneStoneField = await _spawn_field(Vector2(320.0, 200.0), true)
	var visual: RuneStoneVisual = field.get_visual()
	field.polarity_committed.connect(_on_polarity_committed)

	# Request back to the already-committed polarity while a transition is in
	# flight. A late completion for the abandoned target must be ignored.
	field.request_polarity(false)
	visual.advance_transition(0.05)
	field.request_polarity(true)
	_check(field.is_positive(), "reverting to the committed polarity keeps old force during its transition")
	_check(
		String(field.sample_field(Vector2(200.0, 225.0), false)["status"]) == "ATTRACT",
		"old ATTRACT force remains while reverting"
	)
	_check(field.get_requested_positive(), "reverting updates the requested target")
	visual.transition_finished.emit(false)
	_check(field.is_positive(), "a stale false completion cannot change committed state")
	_check(_committed.is_empty(), "a stale false completion emits no commit")
	visual.advance_transition(visual.transition_duration)
	_check(field.is_positive(), "reverse transition returns to already-committed positive")
	_check(_committed.is_empty(), "completing back at the committed polarity emits no duplicate commit")

	# Last request wins across three overlapping targets.
	field.request_polarity(false)
	visual.advance_transition(0.04)
	field.request_polarity(true)
	visual.advance_transition(0.04)
	field.request_polarity(false)
	visual.advance_transition(visual.transition_duration)
	_check(not field.is_positive(), "the newest request is the committed target")
	_check(_committed.size() == 1 and _committed[0] == false, "three overlapping requests emit one final commit")

	# reset_state cancels work in flight and restores initial_positive.
	field.request_polarity(false)
	visual.advance_transition(0.05)
	field.reset_state()
	_check(field.is_positive(), "reset restores initial_positive")
	_check(not visual.is_transitioning(), "reset cancels the in-flight transition")
	_check(visual.get_applied_positive(), "reset restores the initial visual immediately")
	_check(field.get_requested_positive(), "reset resets the requested target too")
	_check(_committed.size() == 1, "reset itself emits no polarity signal")
	visual.transition_finished.emit(false)
	_check(field.is_positive(), "old completion after reset cannot change state")
	_check(_committed.size() == 1, "old completion after reset emits no commit")

	# A committed negative then reset must restore positive without emitting.
	field.request_polarity(false)
	visual.advance_transition(visual.transition_duration)
	_check(_committed.size() == 2 and _committed[1] == false, "negative commit is recorded before reset")
	field.reset_state()
	_check(field.is_positive(), "reset after a committed negative restores initial positive")
	_check(_committed.size() == 2, "reset after commit does not emit a synthetic positive signal")


func _test_pause_freezes_transition() -> void:
	_section("PAUSE FREEZE")
	await _clear_world()
	var field: RuneStoneField = await _spawn_field(Vector2(320.0, 200.0), true)
	var visual: RuneStoneVisual = field.get_visual()
	field.polarity_committed.connect(_on_polarity_committed)

	field.request_polarity(false)
	get_tree().paused = true
	var elapsed_before: float = visual.get_transition_elapsed()
	for i: int in range(6):
		await get_tree().process_frame
	_check(is_equal_approx(visual.get_transition_elapsed(), elapsed_before), "pause freezes transition elapsed time")
	_check(visual.is_transitioning(), "pause leaves the transition unfinished")
	_check(field.is_positive(), "pause keeps the old committed polarity")
	_check(_committed.is_empty(), "pause emits no polarity_committed")
	visual.advance_transition(1.0)
	_check(visual.is_transitioning(), "manual advance also cannot finish while paused")
	_check(_committed.is_empty(), "paused advance emits no commit")

	get_tree().paused = false
	await get_tree().process_frame
	visual.advance_transition(visual.transition_duration + 0.01)
	_check(not field.is_positive(), "transition finishes after resume")
	_check(_committed.size() == 1 and _committed[0] == false, "resume completion emits exactly one commit")


func _test_exported_configuration() -> void:
	_section("EXPORTED SCENE CONFIGURATION")
	await _clear_world()
	var field: RuneStoneField = FIELD_SCENE.instantiate() as RuneStoneField
	field.initial_positive = false
	field.position = Vector2(100.0, 100.0)
	field.field_range = 90.0
	field.inner_radius = 10.0
	field.full_radius = 30.0
	field.outer_fade = 20.0
	field.full_acceleration = 1234.0
	field.auto_hint_in_range = false
	_world.add_child(field)
	await get_tree().process_frame

	_check(not field.is_positive(), "exported initial_positive=false is applied on ready")
	_check(is_equal_approx(field.field_range, 90.0), "exported range is applied")
	_check(is_equal_approx(field.inner_radius, 10.0), "exported inner radius is applied")
	_check(is_equal_approx(field.full_radius, 30.0), "exported full radius is applied")
	_check(is_equal_approx(field.outer_fade, 20.0), "exported outer fade is applied")
	_check(is_equal_approx(field.full_acceleration, 1234.0), "exported acceleration is applied")

	var visual: RuneStoneVisual = field.get_visual()
	_check(visual != null and not visual.polarity_positive, "negative initial polarity previews on the visual")
	_check(visual != null and not visual.get_applied_positive(), "negative initial visual is applied immediately")

	var result: Dictionary = field.sample_field(Vector2(120.0, 100.0), false)
	_check(String(result["status"]) == "REPEL", "negative field repels a negative player", String(result["status"]))
	_check(float(result["acceleration"].length()) <= 1234.01, "custom acceleration limits the sample")
	_check(not visual.show_polarity_hint, "auto hint can be disabled from the inspector")

	field.polarity_committed.connect(_on_polarity_committed)
	field.request_polarity(true)
	_check(not field.is_positive(), "custom field also waits for its visual transition")
	visual.advance_transition(visual.transition_duration + 0.01)
	_check(field.is_positive(), "custom initial field can commit the opposite polarity")
	_check(_committed.size() == 1 and _committed[0] == true, "custom field emits the committed positive signal")


func _test_inactive_first_light_up() -> void:
	_section("INACTIVE / FIRST LIGHT-UP / FORCE ONLY AFTER FINISH")
	await _clear_world()
	var field: RuneStoneField = await _spawn_field(Vector2(320.0, 200.0), true, false)
	var visual: RuneStoneVisual = field.get_visual()
	var center: Vector2 = Vector2(200.0, 225.0)
	field.polarity_committed.connect(_on_polarity_committed)

	_check(not field.is_activated(), "initial_active=false starts the field dormant")
	_check(field.is_positive(), "dormant field still keeps initial_positive internally")
	_check(not visual.is_energized(), "dormant visual is not energized")
	_check(visual.get_displayed_color().is_equal_approx(RuneStoneVisual.INACTIVE_COLOR),
		"dormant cracks use the dark groove colour", str(visual.get_displayed_color()))
	_check(visual.get_hint_kind() == &"none", "dormant visual offers no plus/minus hint")
	_check(not visual.show_polarity_hint, "dormant visual has no hint drawn")

	for player_positive: bool in [true, false]:
		var dormant: Dictionary = field.sample_field(center, player_positive)
		_check(String(dormant["status"]) == "INACTIVE",
			"dormant sample is INACTIVE regardless of player polarity",
			String(dormant["status"]))
		_check(dormant["acceleration"] == Vector2.ZERO,
			"dormant sample force is exactly zero", str(dormant["acceleration"]))
		_check(not bool(dormant["blocked"]), "dormant sample is not falsely blocked")
		_check(not field.is_activated(), "sampling never activates the stone")
		_check(not visual.show_polarity_hint, "dormant sample never shows a +/- hint")

	var far_dormant: Dictionary = field.sample_field(Vector2(0.0, 0.0), false)
	_check(String(far_dormant["status"]) == "INACTIVE",
		"even an out-of-range sample reports INACTIVE while dormant")

	# First light-up whose target equals the internal initial default (GOLD).
	field.request_polarity(true)
	_check(field.is_activation_pending(), "first request marks activation pending")
	_check(not field.is_activated(), "first request does not activate synchronously")
	_check(visual.is_energized() and visual.is_transitioning(),
		"first request starts a dark-to-colour light-up")
	_check(visual.get_applied_positive(), "visual target stays the internal GOLD +")
	_check(_committed.is_empty(), "first request emits no early commit")
	var request_elapsed: float = visual.get_transition_elapsed()
	visual.advance_transition(0.05)
	_check(String(field.sample_field(center, false)["status"]) == "INACTIVE",
		"field stays INACTIVE during the first light-up")
	_check(field.sample_field(center, false)["acceleration"] == Vector2.ZERO,
		"field force stays exactly zero during the first light-up")
	field.request_polarity(true)
	_check(is_equal_approx(visual.get_transition_elapsed(), request_elapsed + 0.05),
		"repeating the same first target does not restart its light-up")
	_check(not field.is_activated() and _committed.is_empty(),
		"repeating the same first target still cannot activate early")

	visual.advance_transition(visual.transition_duration)
	_check(field.is_activated(), "field activates only when the first light-up finishes")
	_check(field.is_positive(), "same-as-default first light-up keeps GOLD +")
	_check(_committed.size() == 1 and _committed[0], "first light-up emits exactly one GOLD commit")
	_check(visual.get_displayed_color().is_equal_approx(RuneStoneVisual.POSITIVE_COLOR),
		"finished first light-up shows the gold crack")
	var live: Dictionary = field.sample_field(center, false)
	_check(String(live["status"]) == "ATTRACT", "live GOLD field attracts a CYAN player", String(live["status"]))
	_check((live["acceleration"] as Vector2).length() > 0.0, "live field produces real force")
	_check(visual.show_polarity_hint, "live in-range sample now shows the +/- hint")

	# A fresh dormant stone with the opposite first target.
	await _clear_world()
	var cyan_field: RuneStoneField = await _spawn_field(Vector2(320.0, 200.0), true, false)
	var cyan_visual: RuneStoneVisual = cyan_field.get_visual()
	cyan_field.polarity_committed.connect(_on_polarity_committed)
	cyan_field.request_polarity(false)
	_check(not cyan_field.is_activated() and cyan_visual.is_transitioning(),
		"opposite first target also starts dormant then light-up")
	_check(String(cyan_field.sample_field(center, true)["status"]) == "INACTIVE",
		"opposite first target has no force during light-up")
	cyan_visual.advance_transition(cyan_visual.transition_duration)
	_check(cyan_field.is_activated() and not cyan_field.is_positive(),
		"opposite first light-up finishes as an active CYAN stone")
	_check(_committed.size() == 1 and not _committed[0],
		"opposite first light-up emits exactly one CYAN commit")
	_check(String(cyan_field.sample_field(center, false)["status"]) == "REPEL",
		"live CYAN field repels a CYAN player")
	_check(String(cyan_field.sample_field(center, true)["status"]) == "ATTRACT",
		"live CYAN field attracts a GOLD player")


func _test_inactive_override_cancel_and_reset() -> void:
	_section("INACTIVE OVERRIDE / CANCEL / RESET / PAUSE")
	await _clear_world()
	var field: RuneStoneField = await _spawn_field(Vector2(320.0, 200.0), true, false)
	var visual: RuneStoneVisual = field.get_visual()
	var center: Vector2 = Vector2(200.0, 225.0)
	field.polarity_committed.connect(_on_polarity_committed)

	# Override the first target while dormant. The abandoned target must never
	# activate the stone, even if its completion arrives.
	field.request_polarity(false)
	visual.advance_transition(0.05)
	field.request_polarity(true)
	visual.transition_finished.emit(false)
	_check(not field.is_activated(), "stale first-target completion cannot activate the stone")
	_check(_committed.is_empty(), "stale first-target completion emits no field commit")
	_check(visual.is_transitioning(), "newest first target is still running")
	visual.advance_transition(visual.transition_duration)
	_check(field.is_activated() and field.is_positive(),
		"newest first target activates the stone")
	_check(_committed.size() == 1 and _committed[0],
		"override emits exactly one final commit")

	# R-style reset during a first light-up restores dormant and ignores late work.
	await _clear_world()
	field = await _spawn_field(Vector2(320.0, 200.0), true, false)
	visual = field.get_visual()
	field.polarity_committed.connect(_on_polarity_committed)
	field.request_polarity(false)
	visual.advance_transition(0.05)
	field.reset_state()
	_check(not field.is_activated(), "reset during first light-up restores dormant")
	_check(field.is_positive(), "reset restores the internal initial GOLD +")
	_check(not visual.is_energized() and visual.get_hint_kind() == &"none",
		"reset returns the visual to dark and removes the hint")
	_check(not visual.is_transitioning(), "reset cancels the first light-up")
	_check(_committed.is_empty(), "reset itself emits no commit")
	visual.transition_finished.emit(false)
	_check(not field.is_activated(), "a late callback after reset cannot activate the stone")
	_check(_committed.is_empty(), "a late callback after reset emits no commit")
	_check(String(field.sample_field(center, true)["status"]) == "INACTIVE",
		"reset dormant sample stays INACTIVE despite the late callback")

	# A newer record cancels the pending field request visually, without
	# changing committed force, and a late completion stays inert.
	field.request_polarity(false)
	visual.advance_transition(0.05)
	field.cancel_pending_request()
	_check(not field.is_activated() and not visual.is_transitioning(),
		"cancel_pending_request abandons the first light-up")
	_check(not visual.is_energized(), "cancelled dormant visual returns to dark")
	_check(_committed.is_empty(), "cancel emits no commit")
	visual.transition_finished.emit(false)
	_check(not field.is_activated() and _committed.is_empty(),
		"late completion after cancel cannot activate or commit")

	# Pause freezes the first light-up exactly like an ordinary change.
	field.request_polarity(false)
	get_tree().paused = true
	for i: int in range(4):
		await get_tree().process_frame
	visual.advance_transition(visual.transition_duration + 0.1)
	_check(not field.is_activated(), "pause keeps a first light-up from activating")
	_check(_committed.is_empty(), "pause emits no first-light-up commit")
	get_tree().paused = false
	await get_tree().process_frame
	visual.advance_transition(visual.transition_duration + 0.01)
	_check(field.is_activated() and not field.is_positive(),
		"first light-up finishes after resume")
	_check(_committed.size() == 1 and not _committed[0],
		"resume emits exactly one first-light-up commit")

	# reset_state on a live field with initial_active=false returns to dormant.
	field.reset_state()
	_check(not field.is_activated(), "reset of a live inactive-start field restores dormant")
	_check(field.is_positive(), "dormant reset restores internal initial polarity")
	_check(not visual.is_energized(), "dormant reset darkens the visual again")
	_check(String(field.sample_field(center, true)["status"]) == "INACTIVE",
		"dormant reset produces zero force")


func _spawn_field(
	at: Vector2,
	initial_positive: bool,
	initial_active: bool = true
) -> RuneStoneField:
	var field: RuneStoneField = FIELD_SCENE.instantiate() as RuneStoneField
	field.initial_active = initial_active
	field.initial_positive = initial_positive
	field.position = at
	_world.add_child(field)
	await get_tree().process_frame
	return field


func _add_blocker(
	center: Vector2,
	size: Vector2,
	layer: int,
	parent: Node = null
) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = center
	body.collision_layer = layer
	body.collision_mask = 0
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var host: Node = _world if parent == null else parent
	host.add_child(body)
	return body


func _add_player_proxy(center: Vector2, size: Vector2) -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	_world.add_child(body)
	return body


func _wait_physics(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame


func _clear_world() -> void:
	if get_tree().paused:
		get_tree().paused = false
	for child: Node in _world.get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	_committed.clear()


func _count_physics_nodes(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is Area2D:
			count += 1
		count += _count_physics_nodes(child)
	return count


func _on_polarity_committed(positive: bool) -> void:
	_committed.append(positive)


func _section(title: String) -> void:
	_log("")
	_log("== %s ==" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, "" if detail.is_empty() else " | " + detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, "" if detail.is_empty() else " | " + detail])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if _world != null:
		for child: Node in _world.get_children():
			child.queue_free()
		_world.queue_free()
		_world = null
	await get_tree().process_frame
	_log("")
	_log("RESULT pass=%d fail=%d" % [_pass_count, _fail_count])

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://tests/logs")
	)
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("RUNE_STONE_FIELD_TEST_RESULT pass=%d fail=%d log=%s" % [
		_pass_count,
		_fail_count,
		LOG_PATH,
	])
	get_tree().quit(1 if _fail_count > 0 else 0)
