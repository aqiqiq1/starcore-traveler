extends Node

## Acceptance test for the star-core bay interaction sandbox.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_star_core_interaction.tscn
##
## The main loop below uses real InputMap actions and real 60 Hz physics:
## walk to the start bay -> E release (snapshot opposite polarity) -> no Q,
## walk right past the target so the 30..60 px trail settles into its seat ->
## three-party proximity shows E: STORE -> E stores and closes the lid ->
## E re-release (new snapshot) -> walk back with the core -> E stores it in the
## start bay. Direct placement is used only for isolated field/proximity tests.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const STANDALONE_SCENE: PackedScene = preload("res://scenes/star_core_interaction_standalone.tscn")

var _game: PrototypeMain
var _player: PrototypePlayer
var _hud: PrototypeHUD
var _room: StarCoreInteractionRoom
var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_game = MAIN_SCENE.instantiate() as PrototypeMain
	add_child(_game)
	await get_tree().process_frame
	_player = _game.get_player()
	_hud = _game.get_hud()
	_room = _game.get_interaction_room()

	_log("Star Core Traveler - star-core bay interaction test")
	_log("Godot %s  display=%s  physics=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
		str(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")),
	])

	_test_environment_and_scene()
	await _test_entry_exit_and_cross_room()
	await _test_full_loop()
	await _test_same_sign_push_and_run_boundary()
	await _test_second_initial_polarity_and_rapid_input()
	await _test_pause_and_reset()
	await _test_manual_store_focus_and_core_out()
	await _test_field_rules()
	await _test_core_limits_and_no_push()
	await _test_standalone_entry()
	_finish()


func _test_environment_and_scene() -> void:
	_section("ENVIRONMENT / SCENE / INPUT")
	_check(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
		"logic viewport is 640x360"
	)
	_check(
		String(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/main.tscn",
		"default main scene remains main.tscn"
	)
	_check(_action_has_key(&"toggle_anchor_room", KEY_F2), "F2 remains bound")
	_check(_action_has_key(&"toggle_interaction_room", KEY_F4), "F4 is bound")
	_check(_action_has_key(&"interact", KEY_E), "E is bound")
	_check(_action_has_key(&"polarity", KEY_Q), "Q remains bound")
	_check(_game.get_node_or_null("InteractionRoom") != null, "main scene instantiates InteractionRoom")
	_check(_room != null and _room.get_node_or_null("Bays/StartBay") != null,
		"room has a scene-authored StartBay")
	_check(_room != null and _room.get_node_or_null("Bays/TargetBay") != null,
		"room has a scene-authored TargetBay")
	_check(_room != null and _room.get_node_or_null("TerrainBody") != null,
		"room has a scene-authored floor collision")
	_check(_room != null and _room.get_node_or_null("PlayerSpawn") != null,
		"room has an editable PlayerSpawn marker")
	_check(_room != null and _room.get_start_bay().is_locked(), "start bay begins LOCKED")
	_check(_room != null and _room.get_target_bay().is_open_empty(), "target bay begins OPEN/EMPTY")
	_check(_room != null and not _room.get_core().is_active(), "moving core begins disabled")
	_check(_count_carriers() == 1, "room owns exactly one moving core", str(_count_carriers()))
	_check(_hud.get_hint_text().contains("F4"), "basic HUD hint advertises F4", _hud.get_hint_text())
	_check(
		_room.get_interaction_range() >= 95.0
		and _room.get_interaction_range() <= 105.0,
		"interaction range is the approved ~100 px trial, not 190",
		"%.1f" % _room.get_interaction_range()
	)
	_check(
		_room.inner_radius >= 30.0 and _room.inner_radius <= 45.0,
		"near-follow stable zone is around 30..45 px",
		"%.1f" % _room.inner_radius
	)
	_check(
		_room.full_radius > _room.inner_radius
		and _room.full_radius < _room.get_interaction_range(),
		"full-strength band starts before the outer edge",
		"%.1f" % _room.full_radius
	)
	_check(
		_room.outer_fade > 0.0
		and _room.outer_fade < _room.get_interaction_range() - _room.full_radius,
		"outer fade is a short zero-force edge band",
		"%.1f" % _room.outer_fade
	)


func _test_entry_exit_and_cross_room() -> void:
	_section("F4 ENTRY / EXIT / F2-F4 CLEANUP")
	await _tap_process_action(&"toggle_interaction_room")
	await _step(5)
	_check(_game.is_in_interaction_room(), "F4 enters the interaction room")
	_check(_room.is_active() and _room.visible, "interaction room controller is active and visible")
	_check(_player.global_position.is_equal_approx(_room.get_spawn_position()),
		"player spawns at the interaction-room marker", str(_player.global_position))
	_check(_hud.is_interaction_panel_visible() and _hud.is_bay_panel_visible(),
		"interaction HUD panels are visible")
	_check(not _hud.is_anchor_panel_visible() and not _hud.is_state_panel_visible(),
		"anchor/state panels are hidden in interaction mode")
	_check(_base_body().collision_layer == 0, "base-room collision is disabled in interaction")
	_check(_anchor_body().collision_layer == 0, "anchor-room collision stays disabled")
	_check(_room_floor_body().collision_layer == 1, "interaction floor collision is enabled")
	_check(_hud.get_interaction_polarity_text().contains("PLAYER"),
		"HUD shows the player polarity line", _hud.get_interaction_polarity_text())
	_check(_hud.get_interaction_polarity_text().contains("CORE"),
		"HUD shows the core polarity/state line", _hud.get_interaction_polarity_text())
	await _tap_process_action(&"toggle_debug")
	await _step(1)
	_check(_player.is_debug_enabled(), "F3 enables interaction range/line debug")
	await _tap_process_action(&"toggle_debug")
	_check(not _player.is_debug_enabled(), "F3 disables interaction debug")

	await _tap_process_action(&"toggle_interaction_room")
	await _step(5)
	_check(not _game.is_in_interaction_room(), "F4 exits to the basic room")
	_check(not _room.visible and not _room.is_active(), "interaction room deactivates on exit")
	_check(_base_body().collision_layer == 1, "basic collision returns on exit")
	_check(_hud.is_state_panel_visible() and not _hud.is_interaction_panel_visible(),
		"HUD returns to the basic layout")
	_check(not _player.is_anchor_force_pending() and _player.get_anchor_force_x() == 0.0,
		"exit clears any pending external force")

	# F2 -> F4 while the anchor room is active must not leak collision or force.
	await _tap_process_action(&"toggle_anchor_room")
	await _step(5)
	_check(_game.is_in_anchor_room(), "F2 enters the anchor room")
	_check(_anchor_body().collision_layer == 1, "anchor collision is active")
	_check(_room_floor_body().collision_layer == 0, "interaction floor stays off in anchor room")
	await _tap_process_action(&"toggle_interaction_room")
	await _step(5)
	_check(not _game.is_in_anchor_room() and _game.is_in_interaction_room(),
		"F4 from anchor switches to interaction")
	_check(not _game.get_anchor_room().is_active(), "anchor controller is deactivated")
	_check(_anchor_body().collision_layer == 0, "anchor collision is disabled after F4")
	_check(_room_floor_body().collision_layer == 1, "interaction floor is enabled after F4")
	_check(not _player.is_anchor_force_pending() and _player.get_anchor_force_x() == 0.0,
		"anchor force is cleared across rooms")
	_check(_player.global_position.is_equal_approx(_room.get_spawn_position()),
		"interaction spawn is restored after cross-room switch")

	# F2 out of interaction must also clean the core room.
	await _tap_process_action(&"toggle_anchor_room")
	await _step(5)
	_check(_game.is_in_anchor_room() and not _room.is_active(),
		"F2 from interaction enters anchor and deactivates core room")
	_check(_room_floor_body().collision_layer == 0 and not _room.get_core().is_active(),
		"core-room collision and core are disabled")
	await _tap_process_action(&"toggle_anchor_room")
	await _step(5)
	_check(not _game.is_in_anchor_room(), "F2 returns to the basic room")
	await _tap_process_action(&"toggle_interaction_room")
	await _step(5)
	_check(_game.is_in_interaction_room() and _room.is_active(),
		"interaction room re-enters for the interaction tests")


func _test_full_loop() -> void:
	_section("FULL LOOP: HETEROPOLAR PULL -> MANUAL E STORE -> RELEASE -> RETURN")
	await _reset_room()
	_check(_player.is_positive(), "loop starts with GOLD player polarity")
	_check(_room.get_start_bay().is_locked(), "start bay is locked after reset")
	_check(_room.get_target_bay().is_open_empty(), "target bay is empty/open after reset")

	await _walk_to_x(84.0)
	_check(_hud.get_interaction_e_text().contains("RELEASE"),
		"standing near the start bay shows an E release preview", _hud.get_interaction_e_text())
	_check(_hud.get_interaction_e_text().contains("CYAN -"),
		"GOLD player previews a CYAN - snapshot", _hud.get_interaction_e_text())

	await _tap_action(&"interact")
	await _step(2)
	_check(_room.get_pending_release(), "E starts the opening sequence")
	_check(not _room.get_pending_positive(), "E snapshots opposite polarity (CYAN -)")
	_check(_hud.is_toast_visible()
		and _hud.get_toast_text().contains("RELEASE SNAPSHOT: CYAN -"),
		"GOLD player opening toast announces CYAN -", _hud.get_toast_text())
	_check(_room.get_start_bay().is_opening(), "start bay lid is opening")
	_check(not _room.get_core().is_active(), "core is not released until the lid is fully open")

	# Deliberately no Q here: natural heteropolar follow from the left.
	await _step(18)
	_check(_room.get_core().is_active(), "core becomes active after the lid opens")
	if not _room.get_core().is_active():
		return
	_check(not _room.get_core().is_positive(), "released core keeps the snapshot CYAN -")
	_check(_room.get_last_release_position().is_equal_approx(Vector2(160.0, 312.0)),
		"core exits to the safe start-bay side point", str(_room.get_last_release_position()))
	_check(_room.get_start_bay().is_open_empty(), "start bay is empty/open after release")
	_check(_count_carriers() == 1, "release does not duplicate the core")
	_check(_room.get_last_release_initial_speed() < 0.01,
		"released core starts at rest", "%.3f" % _room.get_last_release_initial_speed())

	# Opposite-sign attraction from the core's left side pulls the core left.
	var core_x_before: float = _room.get_core().global_position.x
	await _step(10)
	_check(_room.get_last_status() == "ATTRACT",
		"GOLD player / CYAN core reports ATTRACT")
	_check(_room.get_core().global_position.x < core_x_before - 2.0,
		"core is pulled toward the player from its left side", "%.1f -> %.1f" % [
			core_x_before, _room.get_core().global_position.x
		])

	# Walk to the right, pass the core naturally, and lead it to the target.
	# The near-follow trail is 30..60 px, so the player walks a little past the
	# target bay and lets the core settle into its seat instead of expecting it
	# to hug the player at the bay centre.
	await _walk_to_x(552.0, 360)
	await _wait_until(
		func() -> bool:
			return (
				_room.get_target_bay().is_core_in_store_zone(
					_room.get_core().global_position
				)
				and _hud.get_interaction_e_text().contains("STORE CORE (TARGET)")
			),
		90
	)
	_check(_room.get_core().is_active(), "core remains active during the walk")
	_check(_room.get_core().global_position.x > 400.0,
		"heteropolar follow reaches the far half of the room", str(_room.get_core().global_position))
	_check(_room.get_target_bay().is_open_empty() and not _room.get_target_bay().has_core(),
		"walking to the target without E never auto-stores the core")
	_check(not _room.is_success(), "no success before the player stores the core")
	_check(_hud.get_interaction_e_text().contains("STORE CORE (TARGET)"),
		"three-party proximity shows E: STORE CORE (TARGET)", _hud.get_interaction_e_text())
	_check(_room.get_target_bay().is_core_in_store_zone(_room.get_core().global_position),
		"core is inside the target's small seat zone")
	_check(_room.get_target_bay().is_player_in_range(_player.global_position),
		"player stays inside the target bay interaction range",
		"player_x=%.1f" % _player.global_position.x)
	_log("  near-follow at target: player_x=%.1f core_x=%.1f gap=%.1f status=%s" % [
		_player.global_position.x,
		_room.get_core().global_position.x,
		_room.get_last_distance(),
		_room.get_last_status(),
	])

	await _tap_action(&"interact")
	await _step(2)
	_check(_room.get_store_bay() == _room.get_target_bay(), "E selects the target bay")
	_check(_room.get_target_bay().is_closing(), "manual E starts the target closing animation")
	_check(not _room.get_core().is_active(), "manual E brakes/hides the core")
	_check(_room.get_target_bay().has_core(), "target owns the stored purple core")
	_check(_room.is_success() and _hud.is_interaction_success_visible(),
		"manual target store shows the success hint")
	_check(_hud.get_toast_text().contains("CORE STORED"),
		"store toast names the manual action", _hud.get_toast_text())
	_check(_room.is_active(), "success does not stop room physics")
	await _wait_until(func() -> bool: return _room.get_target_bay().is_locked(), 40)
	_check(_room.get_target_bay().is_locked(), "target bay reaches LOCKED after manual store")
	_check(_room.get_target_bay().get_visual().is_lid_closed(), "target lid is fully closed")
	_check(_count_carriers() == 1, "manual store does not duplicate the core")

	# Release from the target and pull the core back to the start under GOLD.
	_check(_hud.get_interaction_e_text().contains("RELEASE"),
		"near the locked target E previews re-release", _hud.get_interaction_e_text())
	await _tap_action(&"interact")
	await _step(2)
	_check(not _room.get_pending_positive(), "target re-release snapshots CYAN - for GOLD player")
	await _step(18)
	_check(_room.get_core().is_active(), "core re-releases from the target after opening")
	if not _room.get_core().is_active():
		return
	_check(not _room.get_core().is_positive(), "re-released core stays CYAN -")
	_check(_player.global_position.x > _room.get_target_bay().global_position.x,
		"player is on the right of the target at re-release",
		"player_x=%.1f" % _player.global_position.x)
	_check(_room.get_last_release_position().is_equal_approx(Vector2(480.0, 312.0)),
		"target release uses the away-from-player side point",
		str(_room.get_last_release_position()))
	_check(_room.get_target_bay().is_open_empty(), "target bay is empty/open after re-release")

	# The player walks past the start bay to the left so the 30..60 px trailing
	# core can settle into the start seat without a snap or a remote pull.
	await _walk_left_to_x(84.0, 360)
	await _wait_until(
		func() -> bool:
			return (
				_room.get_start_bay().is_core_in_store_zone(
					_room.get_core().global_position
				)
				and _hud.get_interaction_e_text().contains("STORE CORE (START)")
			),
		90
	)
	_check(_room.get_core().is_active(), "core follows the player back across the room")
	_check(_room.get_core().global_position.x < 180.0,
		"heteropolar return brings the core back to the start half", str(_room.get_core().global_position))
	_check(_hud.get_interaction_e_text().contains("STORE CORE (START)"),
		"return position shows E: STORE CORE (START)", _hud.get_interaction_e_text())
	_check(_room.get_start_bay().is_player_in_range(_player.global_position),
		"player stays inside the start bay interaction range",
		"player_x=%.1f" % _player.global_position.x)
	_check(_room.get_start_bay().is_core_in_store_zone(_room.get_core().global_position),
		"returning core is inside the start bay seat")
	_check(_room.get_target_bay().is_open_empty(), "target remains empty/open after return")
	_log("  near-follow at start: player_x=%.1f core_x=%.1f gap=%.1f status=%s" % [
		_player.global_position.x,
		_room.get_core().global_position.x,
		_room.get_last_distance(),
		_room.get_last_status(),
	])

	await _tap_action(&"interact")
	await _step(2)
	_check(_room.get_store_bay() == _room.get_start_bay(), "E selects the start bay for return storage")
	_check(_room.get_start_bay().is_closing(), "return storage starts the start lid closing")
	_check(not _room.get_core().is_active(), "return storage brakes the core")
	_check(_count_carriers() == 1, "return storage still keeps exactly one core")
	await _wait_until(func() -> bool: return _room.get_start_bay().is_locked(), 40)
	_check(_room.get_start_bay().is_locked(), "start bay locks after return store")
	_check(_room.is_active(), "room stays live after the full return loop")


func _test_same_sign_push_and_run_boundary() -> void:
	_section("SAME-SIGN PUSH / RUN BOUNDARY")
	await _reset_room()
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	_check(_room.get_core().is_active(), "core active for same-sign push")
	if not _room.get_core().is_active():
		return
	await _tap_action(&"polarity")
	_check(not _player.is_positive() and not _room.get_core().is_positive(),
		"Q makes player and core CYAN - for same-sign push")
	var push_start_x: float = _room.get_core().global_position.x
	Input.action_press(&"move_right")
	await _step(60)
	Input.action_release(&"move_right")
	await _step(2)
	_check(_room.get_core().global_position.x > push_start_x + 40.0,
		"same-sign physical push moves the core right", "%.1f -> %.1f" % [
			push_start_x, _room.get_core().global_position.x
		])
	_check(_room.get_last_status() == "REPEL" or _room.get_last_status() == "NEAR / STABLE",
		"same-sign state is readable during physical push", _room.get_last_status())
	_check(_count_carriers() == 1, "same-sign push keeps one core")

	# Run boundary: normal walk follows; sprint 160 can outrun the 120 core.
	await _reset_room()
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	if not _room.get_core().is_active():
		return
	_send_key(KEY_D, true)
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	await _step(90)
	var run_player_x: float = _player.global_position.x
	var run_core_x: float = _room.get_core().global_position.x
	var run_gap: float = absf(run_player_x - run_core_x)
	_check(absf(_room.get_core().velocity.x) <= _room.get_core().get_max_speed() + 0.1,
		"run test never raises the core beyond its 120 px/s cap")
	_log("  run boundary: player_x=%.1f core_x=%.1f gap=%.1f status=%s" % [
		run_player_x, run_core_x, run_gap, _room.get_last_status()
	])

	# Keep running beyond the 100 px field. The core is faster than a walk but
	# slower than run; once the gap exceeds the range, force must cut and the
	# core must not snap back or chase from outside the range.
	await _step(120)
	var late_player_x: float = _player.global_position.x
	var late_core_x: float = _room.get_core().global_position.x
	var late_gap: float = absf(late_player_x - late_core_x)
	var late_status: String = _room.get_last_status()
	_send_key(KEY_D, false)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	await _step(60)
	_check(late_gap > _room.get_interaction_range(),
		"run can leave the ~100 px field", "gap=%.1f" % late_gap)
	_check(late_status == "OUT OF RANGE",
		"outside the range is reported as OUT OF RANGE", late_status)
	var out_of_range_core_x: float = _room.get_core().global_position.x
	await _step(30)
	_check(absf(_room.get_core().global_position.x - out_of_range_core_x) < 8.0,
		"out-of-range core does not resume chasing after the run",
		"x %.1f -> %.1f" % [out_of_range_core_x, _room.get_core().global_position.x])
	_check(absf(_room.get_core().velocity.x) < 1.0,
		"out-of-range core coasts to rest", "vx=%.1f" % _room.get_core().velocity.x)
	_log("  run beyond range: player_x=%.1f core_x=%.1f gap=%.1f status=%s" % [
		late_player_x, late_core_x, late_gap, late_status
	])


func _test_second_initial_polarity_and_rapid_input() -> void:
	_section("SECOND INITIAL POLARITY / RAPID E / HOLD")
	await _reset_room()
	if _player.is_positive():
		await _tap_action(&"polarity")
	await _walk_to_x(84.0)
	_check(not _player.is_positive(), "second scenario starts with CYAN player")
	_check(_hud.get_interaction_e_text().contains("GOLD +"),
		"CYAN player previews a GOLD + snapshot", _hud.get_interaction_e_text())
	# Rapid extra E presses during opening must not duplicate or alter the snapshot.
	await _tap_action(&"interact")
	await _step(1)
	_check(_hud.is_toast_visible()
		and _hud.get_toast_text().contains("RELEASE SNAPSHOT: GOLD +"),
		"CYAN player opening toast announces GOLD +", _hud.get_toast_text())
	await _tap_action(&"polarity")
	_check(_player.is_positive(), "Q during opening changes the player to GOLD")
	_check(_room.get_pending_positive(), "Q during opening keeps the GOLD + snapshot")
	await _tap_action(&"interact")
	await _tap_action(&"interact")
	_check(_room.get_pending_release(), "rapid E keeps the single opening sequence")
	_check(_room.get_pending_positive(), "rapid E does not change the GOLD + snapshot")
	await _step(18)
	_check(_room.get_core().is_active(), "second-polarity release completes")
	if _room.get_core().is_active():
		_check(_room.get_core().is_positive(), "initial CYAN player releases a GOLD + core")
	_check(_count_carriers() == 1, "rapid E keeps one core")

	# Fresh CYAN -> GOLD run without Q: the other initial polarity must also
	# produce a real pull, not only the GOLD -> CYAN case.
	await _reset_room()
	if _player.is_positive():
		await _tap_action(&"polarity")
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	_check(
		not _player.is_positive()
		and _room.get_core().is_active()
		and _room.get_core().is_positive(),
		"fresh CYAN run releases an active GOLD core"
	)
	var cyan_follow_start: float = _room.get_core().global_position.x
	await _walk_to_x(240.0)
	await _step(10)
	_check(
		_room.get_core().global_position.x > cyan_follow_start + 30.0,
		"GOLD core is pulled along by the CYAN player",
		"%.1f -> %.1f" % [
			cyan_follow_start, _room.get_core().global_position.x
		]
	)
	_check(_room.get_last_status() != "OUT OF RANGE",
		"fresh CYAN follow stays in field range", _room.get_last_status())
	_check(_count_carriers() == 1, "fresh CYAN follow keeps one core")

	# Hold E through a release: action echoes must not create extra cores.
	await _reset_room()
	await _walk_to_x(84.0)
	Input.action_press(&"interact")
	for i: int in range(40):
		await _step(1)
	Input.action_release(&"interact")
	await _step(2)
	_check(_count_carriers() == 1, "held E does not duplicate the core")
	_check(_room.get_core().is_active(), "held E still performs exactly one release")
	_check(_room.get_start_bay().is_open_empty(), "start bay is open after held E release")


func _test_pause_and_reset() -> void:
	_section("PAUSE MID-LID / R FULL RESET")
	await _reset_room()
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(3)
	var paused_progress: float = _room.get_start_bay().get_visual().get_lid_progress()
	_check(paused_progress > 0.0 and paused_progress < 1.0, "lid is mid-animation before pause",
		"%.2f" % paused_progress)
	await _tap_process_action(&"pause")
	_check(_game.is_paused(), "Esc pauses during the lid animation")
	var frozen_progress: float = _room.get_start_bay().get_visual().get_lid_progress()
	var frozen_player_position: Vector2 = _player.global_position
	var frozen_player_velocity: Vector2 = _player.velocity
	await _step(20)
	_check(is_equal_approx(_room.get_start_bay().get_visual().get_lid_progress(), frozen_progress),
		"pause freezes the lid progress")
	_check(_player.global_position.is_equal_approx(frozen_player_position),
		"pause freezes the player position")
	_check(_player.velocity.is_equal_approx(frozen_player_velocity),
		"pause freezes the player velocity")
	_check(not _room.get_core().is_active(), "pause prevents the pending release")
	await _tap_process_action(&"pause")
	_check(not _game.is_paused(), "Esc resumes the room")
	await _step(20)
	_check(_room.get_core().is_active(), "pending release finishes after resume")

	var resets_before: int = _player.get_reset_count()
	await _tap_action(&"reset")
	await _step(8)
	_check(_player.global_position.is_equal_approx(_room.get_spawn_position()),
		"R returns to the interaction spawn", str(_player.global_position))
	_check(_player.is_positive(), "R restores GOLD player polarity")
	_check(_player.get_reset_count() == resets_before + 1, "R increments the reset count")
	_check(_room.get_start_bay().is_locked() and _room.get_target_bay().is_open_empty(),
		"R restores start LOCKED and target OPEN")
	_check(not _room.get_core().is_active(), "R hides the moving core")
	_check(not _room.is_success() and not _hud.is_interaction_success_visible(),
		"R clears the success hint")
	_check(_count_carriers() == 1, "R does not duplicate the core")


func _test_manual_store_focus_and_core_out() -> void:
	_section("MANUAL E STORE / THREE-PARTY PROXIMITY / FOCUS / CORE OUT")
	await _reset_room()
	var target: StarCoreBayInteractable = _room.get_target_bay()
	var center: Vector2 = target.get_store_center()
	_check(target.is_core_in_store_zone(center + Vector2(8.0, 0.0)),
		"core inside the small bay seat is store-eligible")
	_check(not target.is_core_in_store_zone(center + Vector2(60.0, 0.0)),
		"core outside the small bay seat is not eligible")
	_check(not _room.get_start_bay().is_core_in_store_zone(
		_room.get_start_bay().get_store_center()),
		"a loaded bay is not a store target")

	# Empty target, no active core: E must say why and not store anything.
	_player.global_position = Vector2(480.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(2)
	_check(_hud.get_interaction_e_text().contains("NO CORE TO STORE (TARGET)"),
		"empty target without a core names the unavailable E action",
		_hud.get_interaction_e_text())
	await _tap_action(&"interact")
	await _step(1)
	_check(not target.has_core() and not _room.get_core().is_active(),
		"E at an empty bay without a core does not store")
	_check(_hud.get_toast_text().contains("E IGNORED"),
		"invalid E explains itself in the toast", _hud.get_toast_text())

	# Release a core, then test core proximity / seat range / manual high-speed E.
	await _reset_room()
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	_check(_room.get_core().is_active(), "core active for manual store checks")
	if not _room.get_core().is_active():
		return
	_player.global_position = Vector2(480.0, 320.0)
	_player.velocity = Vector2.ZERO
	_room.get_core().global_position = center + Vector2(30.0, 0.0)
	_room.get_core().velocity = Vector2.ZERO
	await _step(1)
	_check(target.is_open_empty() and _room.get_core().is_active(),
		"core just outside the seat is not automatically stored")
	_check(_hud.get_interaction_e_text().contains("STORE UNAVAILABLE (TARGET)"),
		"out-of-seat E preview names the target and reason", _hud.get_interaction_e_text())
	await _tap_action(&"interact")
	await _step(1)
	_check(target.is_open_empty() and _room.get_core().is_active(),
		"E outside the seat does not store")
	_check(_hud.get_toast_text().contains("E IGNORED"),
		"out-of-seat E toast explains the refusal", _hud.get_toast_text())

	_player.global_position = Vector2(300.0, 320.0)
	_room.get_core().global_position = center
	_room.get_core().velocity = Vector2.ZERO
	await _step(1)
	await _tap_action(&"interact")
	await _step(1)
	_check(target.is_open_empty() and _room.get_core().is_active(),
		"core in the seat but player far from the bay cannot store")

	_player.global_position = Vector2(480.0, 320.0)
	_player.velocity = Vector2.ZERO
	_room.get_core().global_position = center + Vector2(8.0, 0.0)
	_room.get_core().velocity = Vector2(200.0, 0.0)
	await _step(1)
	_check(_hud.get_interaction_e_text().contains("STORE CORE (TARGET)"),
		"three-party proximity shows manual E: STORE", _hud.get_interaction_e_text())
	await _tap_action(&"interact")
	await _step(1)
	_check(_room.get_store_bay() == target and target.is_closing(),
		"high-speed core is accepted by manual E (no speed gate)")
	_check(not _room.get_core().is_active(),
		"manual E brakes/hides the core before closing")
	_check(target.is_closing() and target.has_core(),
		"target owns the core after manual E")

	# Focus loss clears held movement intent; the player's normal movement code
	# is unchanged while the room is active.
	await _reset_room()
	await _walk_to_x(70.0)
	_send_key(KEY_D, true)
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	await _step(2)
	_game.handle_focus_lost()
	await _step(1)
	_check(not _player.is_left_shift_held() and not _player.is_double_tap_run_locked(),
		"focus loss clears Shift and double-tap intent")
	_send_key(KEY_D, false)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	await _step(1)

	# Explicitly put the moving core out of bounds; the room must restore the
	# whole sandbox rather than leaving a hidden/free core.
	await _reset_room()
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	_check(_room.get_core().is_active(), "core active before out-of-bounds test")
	if _room.get_core().is_active():
		_room.get_core().global_position = Vector2(700.0, 312.0)
		await _step(3)
	_check(not _room.get_core().is_active(), "out-of-bounds core is disabled")
	_check(_room.get_start_bay().is_locked() and _room.get_target_bay().is_open_empty(),
		"out-of-bounds restores start LOCKED / target OPEN")
	_check(_player.global_position.is_equal_approx(_room.get_spawn_position()),
		"out-of-bounds restores the player spawn")
	_check(not _room.is_success(), "out-of-bounds clears success")
	_check(_count_carriers() == 1, "out-of-bounds keeps one core")


func _test_field_rules() -> void:
	_section("FIELD SIGN / RANGE / NEAR / OCCLUSION / TWO-WAY")
	await _ensure_interaction()
	var player_center: Vector2 = Vector2(300.0, 305.0)
	var core_center: Vector2 = Vector2(380.0, 312.0)
	var attract: Dictionary = _room.compute_field(player_center, core_center, true, false)
	var to_core: Vector2 = core_center - player_center
	var attract_core: Vector2 = attract["core_acceleration"]
	var attract_player: Vector2 = attract["player_acceleration"]
	_check(String(attract["status"]) == "ATTRACT", "opposite signs report ATTRACT")
	_check(attract_core.dot(-to_core) > 0.0,
		"opposite signs pull the core toward the player")
	_check(attract_player.dot(to_core) > 0.0,
		"opposite signs pull the player toward the core")
	var repel: Dictionary = _room.compute_field(player_center, core_center, true, true)
	var repel_core: Vector2 = repel["core_acceleration"]
	var repel_player: Vector2 = repel["player_acceleration"]
	_check(String(repel["status"]) == "REPEL", "same signs report REPEL")
	_check(repel_core.dot(to_core) > 0.0,
		"same signs push the core away from the player")
	_check(repel_player.dot(-to_core) > 0.0,
		"same signs push the player away from the core")
	_check(
		not repel_core.is_zero_approx()
		and repel_core.length() <= _room.core_acceleration + 0.01,
		"core acceleration is bounded by its base strength"
	)

	# The 100 px trial field must still act at a 40..60 px walking trail, and
	# the inner stable zone must be the only place where force is neutral.
	var walk_trail: Dictionary = _room.compute_field(
		Vector2(300.0, 305.0), Vector2(342.0, 312.0), true, false
	)
	var walk_trail_distance: float = float(walk_trail["distance"])
	var walk_trail_core: Vector2 = walk_trail["core_acceleration"]
	_check(
		String(walk_trail["status"]) == "ATTRACT"
		and walk_trail_distance >= 30.0
		and walk_trail_distance <= 60.0,
		"40..60 px walking trail remains inside the attract field",
		"distance=%.1f" % walk_trail_distance
	)
	_check(walk_trail_core.dot(-(Vector2(342.0, 312.0) - Vector2(300.0, 305.0))) > 0.0,
		"walking-trail force still points at the player")
	var stable_zone: Dictionary = _room.compute_field(
		Vector2(300.0, 305.0), Vector2(330.0, 312.0), true, false
	)
	_check(String(stable_zone["status"]).contains("NEAR"),
		"inside the near-follow stable zone is NEAR/STABLE",
		"%s d=%.1f" % [String(stable_zone["status"]), float(stable_zone["distance"])])
	_check((stable_zone["core_acceleration"] as Vector2).is_zero_approx(),
		"inside the near-follow stable zone force is zero")

	var edge_in: Dictionary = _room.compute_field(
		Vector2(20.0, 305.0),
		Vector2(20.0 + _room.get_interaction_range() - 1.0, 305.0),
		true, false
	)
	var edge_in_core: Vector2 = edge_in["core_acceleration"]
	_check(bool(edge_in["in_range"]) and not edge_in_core.is_zero_approx(),
		"one pixel inside the ~100 px range still has force",
		"d=%.1f force=%.2f" % [float(edge_in["distance"]), edge_in_core.length()])
	var edge_out: Dictionary = _room.compute_field(
		Vector2(20.0, 305.0), Vector2(20.0 + _room.get_interaction_range(), 305.0),
		true, false
	)
	_check(String(edge_out["status"]) == "OUT OF RANGE"
		and (edge_out["core_acceleration"] as Vector2).is_zero_approx(),
		"force cuts to zero exactly at the ~100 px range")

	var far: Dictionary = _room.compute_field(
		Vector2(20.0, 305.0), Vector2(20.0 + _room.get_interaction_range() + 20.0, 312.0),
		true, false
	)
	var far_core: Vector2 = far["core_acceleration"]
	_check(String(far["status"]) == "OUT OF RANGE", "outside the range is OUT OF RANGE")
	_check(far_core.is_zero_approx(), "out-of-range force is zero")

	var near: Dictionary = _room.compute_field(
		Vector2(300.0, 305.0), Vector2(304.0, 312.0), true, false
	)
	var near_core: Vector2 = near["core_acceleration"]
	_check(String(near["status"]).contains("NEAR"), "close range is NEAR/STABLE")
	_check(near_core.is_zero_approx(), "near force is neutral")
	var zero: Dictionary = _room.compute_field(
		Vector2(300.0, 305.0), Vector2(300.0, 305.0), true, false
	)
	var zero_core: Vector2 = zero["core_acceleration"]
	_check(zero_core.is_zero_approx(), "zero distance has no NaN")
	_check(is_finite(zero_core.x), "zero distance stays finite")

	var blocker: StaticBody2D = StaticBody2D.new()
	blocker.name = "InteractionTestOccluder"
	blocker.collision_layer = 1
	blocker.collision_mask = 1
	blocker.position = Vector2(340.0, 300.0)
	var blocker_shape: CollisionShape2D = CollisionShape2D.new()
	var blocker_rect: RectangleShape2D = RectangleShape2D.new()
	blocker_rect.size = Vector2(20.0, 20.0)
	blocker_shape.shape = blocker_rect
	blocker.add_child(blocker_shape)
	_room.add_child(blocker)
	await _step(3)
	var blocked: Dictionary = _room.compute_field(player_center, core_center, true, false)
	var blocked_core: Vector2 = blocked["core_acceleration"]
	_check(bool(blocked["blocked"]) and String(blocked["status"]) == "BLOCKED",
		"solid terrain blocks the centre line")
	_check(blocked_core.is_zero_approx(), "blocked force is zero")
	blocker.queue_free()
	await _step(3)


func _test_core_limits_and_no_push() -> void:
	_section("CORE SPEED / GROUND DRAG / NO BODY PUSH")
	await _reset_room()
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	_check(_room.get_core().is_active(), "core active for physics-limit checks")
	if not _room.get_core().is_active():
		return

	# Move the player far away so the room clears the field for the speed/drag check.
	_player.global_position = Vector2(600.0, 320.0)
	_player.velocity = Vector2.ZERO
	_room.get_core().global_position = Vector2(300.0, 312.0)
	_room.get_core().velocity = Vector2(500.0, 0.0)
	await _step(1)
	_check(absf(_room.get_core().velocity.x) <= _room.get_core().get_max_speed() + 0.05,
		"core horizontal speed is capped at 120", "vx=%.1f" % _room.get_core().velocity.x)
	_room.get_core().velocity = Vector2(120.0, 0.0)
	await _step(20)
	_check(absf(_room.get_core().velocity.x) < 1.0,
		"ground drag stops a free core", "vx=%.1f" % _room.get_core().velocity.x)

	# Put the player and core almost on top of each other (near force zero) and
	# walk into it. The core must not be pushed by the body.
	_room.get_core().global_position = Vector2(300.0, 312.0)
	_room.get_core().velocity = Vector2.ZERO
	_player.global_position = Vector2(292.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(1)
	var core_x_before: float = _room.get_core().global_position.x
	Input.action_press(&"move_right")
	for i: int in range(16):
		await _step(1)
	Input.action_release(&"move_right")
	await _step(2)
	_check(absf(_room.get_core().global_position.x - core_x_before) < 0.6,
		"player body cannot push the core", "x %.3f -> %.3f" % [
			core_x_before, _room.get_core().global_position.x
		])
	_check(_room.get_core().is_active(), "core is still active after body overlap")
	_check(_room.get_last_status().contains("NEAR"),
		"overlapping test is outside the force band", _room.get_last_status())

	# Leave the room while the core is active; collisions/body/physics and the
	# player's external force must all be cleared, then F4 must reset the room.
	await _tap_process_action(&"toggle_anchor_room")
	await _step(5)
	_check(_game.is_in_anchor_room() and not _room.is_active(),
		"F2 from an active core deactivates the interaction room")
	_check(not _room.get_core().is_active(),
		"active core is disabled on cross-room switch")
	_check(not _player.is_anchor_force_pending() and _player.get_anchor_force_x() == 0.0,
		"external force is cleared on cross-room switch")
	await _tap_process_action(&"toggle_interaction_room")
	await _step(5)
	_check(_game.is_in_interaction_room() and _room.is_active()
		and _room.get_start_bay().is_locked() and _room.get_target_bay().is_open_empty(),
		"F4 return resets start LOCKED / target OPEN")
	_check(not _room.get_core().is_active() and _count_carriers() == 1,
		"returning keeps one hidden core")


func _test_standalone_entry() -> void:
	_section("STANDALONE SCENE ENTRY")
	# Free the main game first. Keeping it alive would put a second player and
	# floor at the same world coordinates and make the standalone spawn test
	# collide with unrelated test state.
	if _game != null:
		_game.queue_free()
		_game = null
		await get_tree().process_frame
		await get_tree().physics_frame
	var standalone: Node2D = STANDALONE_SCENE.instantiate() as Node2D
	add_child(standalone)
	await get_tree().process_frame
	await get_tree().process_frame
	var room: StarCoreInteractionRoom = standalone.get_room()
	var player: PrototypePlayer = standalone.get_player()
	var hud: PrototypeHUD = standalone.get_hud()
	_check(room != null and room.is_active(), "standalone wrapper activates its room")
	_check(
		player != null and player.global_position.distance_to(room.get_spawn_position()) < 1.0,
		"standalone player starts at the room spawn",
		str(player.global_position) if player != null else "player missing"
	)
	_check(room.get_start_bay().is_locked() and room.get_target_bay().is_open_empty(),
		"standalone room starts with LOCKED start / OPEN target")
	_check(hud != null and hud.is_interaction_panel_visible(),
		"standalone HUD starts in interaction mode")
	_check(hud != null and hud.get_interaction_polarity_text().contains("PLAYER"),
		"standalone HUD shows player/core state")
	var carriers: int = 0
	for child: Node in room.get_children():
		if child is StarCoreCarrier:
			carriers += 1
	_check(carriers == 1, "standalone room owns one moving core")
	standalone.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Helpers


func _ensure_interaction() -> void:
	if get_tree().paused:
		get_tree().paused = false
		_hud.set_pause_visible(false)
	if not _game.is_in_interaction_room():
		_game.enter_interaction_room()
		await _step(5)


func _reset_room() -> void:
	if get_tree().paused:
		get_tree().paused = false
		_hud.set_pause_visible(false)
	if not _game.is_in_interaction_room():
		_game.enter_interaction_room()
		await _step(5)
	await _tap_action(&"reset")
	await _step(8)


func _walk_to_x(target_x: float, max_frames: int = 240) -> void:
	Input.action_press(&"move_right")
	for i: int in range(max_frames):
		await _step(1)
		if _player.global_position.x >= target_x:
			break
	Input.action_release(&"move_right")
	await _step(3)


func _walk_left_to_x(target_x: float, max_frames: int = 240) -> void:
	Input.action_press(&"move_left")
	for i: int in range(max_frames):
		await _step(1)
		if _player.global_position.x <= target_x:
			break
	Input.action_release(&"move_left")
	await _step(3)


func _wait_until(predicate: Callable, max_frames: int) -> void:
	for i: int in range(max_frames):
		if bool(predicate.call()):
			return
		await _step(1)


func _count_carriers() -> int:
	var count: int = 0
	for child: Node in _room.get_children():
		if child is StarCoreCarrier:
			count += 1
	return count


func _base_body() -> StaticBody2D:
	return _game.get_node("World/PlatformCollision0") as StaticBody2D


func _anchor_body() -> StaticBody2D:
	return _game.get_node("AnchorRoom/AnchorPlatformCollision0") as StaticBody2D


func _room_floor_body() -> StaticBody2D:
	return _game.get_node("InteractionRoom/TerrainBody") as StaticBody2D


func _action_has_key(action: StringName, key: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and int((event as InputEventKey).physical_keycode) == int(key):
			return true
	return false


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await _step(1)
	Input.action_release(action)
	await _step(1)


func _tap_process_action(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _send_key(key: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.location = location
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _step(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame


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
	_log("")
	_log("RESULT pass=%d fail=%d skipped=%d" % [_pass_count, _fail_count, _skip_count])
	var log_directory: String = ProjectSettings.globalize_path("res://tests/logs")
	DirAccess.make_dir_recursive_absolute(log_directory)
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/star_core_interaction_test.log",
		FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("STAR_CORE_INTERACTION_TEST_RESULT pass=%d fail=%d skipped=%d" % [
		_pass_count, _fail_count, _skip_count
	])
	get_tree().quit(1 if _fail_count > 0 else 0)
