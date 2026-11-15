extends Node

## Headless acceptance runner for the basic scene and the single-anchor trial.
## It drives the real scene and real InputMap actions; it does not just
## return a canned PASS. Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_runner.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _game: PrototypeMain
var _player: PrototypePlayer
var _hud: PrototypeHUD
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_game = MAIN_SCENE.instantiate() as PrototypeMain
	add_child(_game)
	await get_tree().process_frame
	_player = _game.get_player()
	_hud = _game.get_hud()

	_log("Star Core Traveler - headless acceptance run")
	_log("Godot %s  display=%s  physics_ticks=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
		str(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")),
	])

	await _test_environment_and_visual_config()
	await _test_initial_spawn_and_body()
	await _test_frame_counts_and_chest_anchors()
	await _test_movement_and_facing()
	await _test_double_tap_rules()
	await _test_walk_sprint_cleanup()
	await _test_jump_fall_landing()
	await _test_air_intent()
	await _test_platform_collisions()
	await _test_pit_respawn()
	await _test_polarity_and_ring()
	await _test_manual_reset()
	await _test_coyote_and_jump_buffer()
	await _test_world_bounds()
	await _test_pause_and_debug()
	await _test_effect_node_integrity()
	await _test_anchor_room_entry()
	await _test_anchor_field_rules()
	await _test_anchor_occlusion_limits_and_bounds()
	await _test_anchor_pause_and_reset()
	await _test_anchor_plain_run_jump_fails()
	await _test_anchor_attraction_only_fails()
	await _test_anchor_switch_window_and_success()
	await _test_anchor_return_after_success()
	await _test_anchor_full_spawn_route()

	_finish()


func _test_environment_and_visual_config() -> void:
	_section("ENVIRONMENT")
	_check(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
		"logic viewport is 640x360",
		"viewport=%sx%s" % [
			str(ProjectSettings.get_setting("display/window/size/viewport_width")),
			str(ProjectSettings.get_setting("display/window/size/viewport_height")),
		]
	)
	_check(
		int(ProjectSettings.get_setting("display/window/size/window_width_override")) == 1280
		and int(ProjectSettings.get_setting("display/window/size/window_height_override")) == 720,
		"window override is 1280x720",
		"window=%sx%s" % [
			str(ProjectSettings.get_setting("display/window/size/window_width_override")),
			str(ProjectSettings.get_setting("display/window/size/window_height_override")),
		]
	)
	_check(
		String(ProjectSettings.get_setting("display/window/stretch/mode")) == "viewport",
		"stretch mode is viewport (crisp integer upscale)",
		str(ProjectSettings.get_setting("display/window/stretch/mode"))
	)
	_check(
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"default canvas texture filter is nearest",
		str(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))
	)
	_check(
		int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")) == 60,
		"fixed physics step is 60 Hz",
		str(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
	)
	_check(
		_action_has_physical_key(&"move_left", KEY_A)
		and _action_has_physical_key(&"move_left", KEY_LEFT)
		and _action_has_physical_key(&"move_right", KEY_D)
		and _action_has_physical_key(&"move_right", KEY_RIGHT)
		and _action_has_physical_key(&"jump", KEY_SPACE)
		and _action_has_physical_key(&"polarity", KEY_Q)
		and _action_has_physical_key(&"reset", KEY_R)
		and _action_has_physical_key(&"pause", KEY_ESCAPE)
		and _action_has_physical_key(&"toggle_debug", KEY_F3)
		and _action_has_physical_key(&"toggle_anchor_room", KEY_F2),
		"InputMap binds A/D, arrows, Space, Q, R, Esc, F3 and F2",
		"runtime-registered physical keys"
	)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_log("  runtime viewport=%s" % str(viewport_size))
	_check(
		int(viewport_size.x) == 640 and int(viewport_size.y) == 360,
		"runtime viewport is 640x360",
		str(viewport_size)
	)
	await get_tree().process_frame


func _test_initial_spawn_and_body() -> void:
	_section("SPAWN / BODY")
	await _reset_player()
	var spawn: Vector2 = _game.get_spawn_position()
	_check(_player.global_position.is_equal_approx(spawn), "spawn position is (80, 288)", str(_player.global_position))
	_check(_player.is_on_floor(), "player starts supported by ground", str(_player.global_position))
	_check(_player.get_state_name() == "idle", "initial state is idle", _player.get_state_name())
	var body_size: Vector2 = _player.get_collision_size()
	_check(
		absf(body_size.x - 12.0) < 0.01 and absf(body_size.y - 30.0) < 0.01,
		"body collision is 12x30, excluding scarf/canvas",
		str(body_size)
	)
	_check(_player.get_visible_frame_size() == Vector2i(128, 128), "source frame canvas is 128x128", str(_player.get_visible_frame_size()))
	_check(_hud.get_polarity_text().contains("GOLD"), "HUD starts on GOLD polarity", _hud.get_polarity_text())
	_check(_hud.get_state_text().contains("IDLE"), "HUD mirrors idle state", _hud.get_state_text())
	await _step(60)
	_check(
		absf(_player.global_position.y - 288.0) < 0.75 and _player.is_on_floor(),
		"idle feet stay on the ground for 1 s",
		"y=%.2f floor=%s" % [_player.global_position.y, str(_player.is_on_floor())]
	)


func _test_frame_counts_and_chest_anchors() -> void:
	_section("FRAME COUNTS / CHEST ANCHORS")
	var expected_counts: Array[int] = [10, 10, 10, 6, 4, 3]
	var anims: Array[StringName] = [&"idle", &"walk", &"run", &"jump", &"fall", &"fall_loop"]
	var anchor_table: Dictionary = _player.get_anchor_table()
	var total_checked: int = 0
	var anchor_failures: int = 0
	var body_height_failures: int = 0
	var idle_baselines: Array[int] = []
	var walk_baselines: Array[int] = []

	for i: int in range(anims.size()):
		var anim: StringName = anims[i]
		var expected: int = expected_counts[i]
		var actual: int = _player.get_frame_count_for(anim)
		var anchors: Array = anchor_table[String(anim)] as Array
		_check(actual == expected, "%s sheet frame count" % String(anim), "expected %d, got %d" % [expected, actual])
		_check(anchors.size() == expected, "%s anchor array length" % String(anim), "expected %d, got %d" % [expected, anchors.size()])

		var texture: Texture2D = load("res://assets/characters/male_hero-%s.png" % String(anim))
		var image: Image = texture.get_image()
		for frame_index: int in range(actual):
			var anchor: Vector2i = _player.get_anchor_for(anim, frame_index)
			var color: Color = image.get_pixel(frame_index * 128 + anchor.x, anchor.y)
			# get_used_rect() scans the whole sheet, so check each 128 px frame separately.
			var frame_image: Image = image.get_region(Rect2i(frame_index * 128, 0, 128, 128))
			var bbox: Rect2i = frame_image.get_used_rect()
			total_checked += 1
			if anim == &"idle":
				idle_baselines.append(bbox.position.y + bbox.size.y)
			if anim == &"walk":
				walk_baselines.append(bbox.position.y + bbox.size.y)
			if anim == &"idle" or anim == &"walk" or anim == &"run":
				if bbox.size.y < 30 or bbox.size.y > 40:
					body_height_failures += 1

			var is_scarf: bool = color.r > 0.47 and color.g < 0.35 and color.b > 0.31
			var is_skin: bool = color.r > 0.78 and color.g > 0.55 and color.b > 0.39 and color.r > color.g + 0.12
			var max_channel: float = maxf(color.r, maxf(color.g, color.b))
			var min_channel: float = minf(color.r, minf(color.g, color.b))
			var is_white_armor: bool = max_channel > 0.58 and (max_channel - min_channel) < 0.14
			var is_blue_armor: bool = color.b > color.r + 0.015 and color.b > 0.47 and color.g > 0.43
			var is_chest_armor: bool = is_white_armor or is_blue_armor
			var inside_bbox: bool = bbox.has_point(anchor)

			if color.a <= 0.5 or is_scarf or is_skin or not is_chest_armor or not inside_bbox:
				anchor_failures += 1
				_log("  ANCHOR FAIL %s#%d %s color=%s bbox=%s scarf=%s skin=%s chest=%s" % [
					String(anim), frame_index, str(anchor), str(color), str(bbox),
					str(is_scarf), str(is_skin), str(is_chest_armor)
				])

	var expected_total: int = 0
	for count_value: int in expected_counts:
		expected_total += count_value
	_check(total_checked == expected_total, "all implemented frames inspected", "checked %d/%d" % [total_checked, expected_total])
	_check(anchor_failures == 0, "all anchors land on opaque chest armor, not scarf/skin", "%d/%d passed" % [expected_total - anchor_failures, expected_total])
	_check(
		idle_baselines.count(80) == idle_baselines.size(),
		"all idle source frames share the foot baseline y=79",
		str(idle_baselines)
	)
	_check(
		walk_baselines.count(80) == walk_baselines.size(),
		"all walk source frames share the foot baseline y=79",
		str(walk_baselines)
	)
	_check(
		body_height_failures == 0,
		"idle/walk/run visible body height stays around 33-38 px",
		"%d bad frames" % body_height_failures
	)
	var walk_anchors_differ: bool = false
	for frame_index: int in range(10):
		if _player.get_anchor_for(&"walk", frame_index) != _player.get_anchor_for(&"run", frame_index):
			walk_anchors_differ = true
			break
	_check(walk_anchors_differ, "walk uses its own anchors, not the run anchor set", "compared 10 frames")
	_log("  anchor frame counts: idle=10 walk=10 run=10 jump=6 fall=4 fall_loop=3; anchors=43")
	await get_tree().process_frame


func _test_movement_and_facing() -> void:
	_section("MOVEMENT / WALK DEFAULT")
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	var start_x: float = _player.global_position.x
	_key_down(KEY_D)
	await _step(15)
	_check(_player.get_state_name() == "walk", "right input defaults to walk", _player.get_state_name())
	_check(absf(_player.get_target_speed() - 100.0) < 0.01, "default walk target is 100 px/s", "target=%.1f" % _player.get_target_speed())
	_check(_player.get_facing() == 1, "right input faces right", str(_player.get_facing()))
	var restart_before: int = _player.get_anim_restart_count()
	await _step(15)
	var restart_after: int = _player.get_anim_restart_count()
	_check(restart_after == restart_before, "walk animation does not restart every physics tick", "%d -> %d" % [restart_before, restart_after])
	var end_x: float = _player.global_position.x
	_check(end_x > start_x + 25.0, "default walk moves the player", "x %.1f -> %.1f" % [start_x, end_x])
	_check(_player.velocity.x <= 100.01, "default walk does not exceed walk speed", "vx=%.2f" % _player.velocity.x)
	_check(absf(_player.global_position.y - 288.0) < 0.75, "feet stay on the ground while walking", "y=%.2f" % _player.global_position.y)
	_key_up(KEY_D)
	await _step(30)
	_check(_player.get_state_name() == "idle", "release decelerates to idle", _player.get_state_name())
	_check(absf(_player.velocity.x) < 2.0, "horizontal velocity settles near zero", "vx=%.2f" % _player.velocity.x)

	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	start_x = _player.global_position.x
	_key_down(KEY_A)
	await _step(24)
	end_x = _player.global_position.x
	_check(end_x < start_x - 20.0, "left default walk moves the player", "x %.1f -> %.1f" % [start_x, end_x])
	_check(_player.get_facing() == -1, "left input faces left", str(_player.get_facing()))
	_check(_player.get_state_name() == "walk", "left default state is walk", _player.get_state_name())
	_key_up(KEY_A)
	await _step(22)

	# Left Shift can be pressed mid-walk; release returns to walk immediately.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	await _step(10)
	_check(_player.get_state_name() == "walk", "walk starts before Shift", _player.get_state_name())
	var walk_vx: float = _player.velocity.x
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(15)
	_check(_player.is_left_shift_held(), "left Shift is detected by KEY_LOCATION_LEFT", str(_player.is_left_shift_held()))
	_check(_player.get_state_name() == "run", "left Shift mid-walk selects run", _player.get_state_name())
	_check(absf(_player.get_target_speed() - 160.0) < 0.01, "run target is 160 px/s", "target=%.1f" % _player.get_target_speed())
	_check(_player.velocity.x > walk_vx + 20.0, "run speed rises above walk", "walk_vx=%.1f run_vx=%.1f" % [walk_vx, _player.velocity.x])
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(2)
	_check(not _player.is_left_shift_held(), "left Shift release clears Shift latch", str(_player.is_left_shift_held()))
	_check(_player.get_state_name() == "walk", "Shift release without double-tap returns to walk immediately", _player.get_state_name())
	_check(absf(_player.get_target_speed() - 100.0) < 0.01, "Shift release retargets walk speed", "target=%.1f" % _player.get_target_speed())
	_key_up(KEY_D)
	await _step(18)

	# Right Shift must not trigger run.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	await _step(10)
	_key_down(KEY_SHIFT, KEY_LOCATION_RIGHT)
	await _step(15)
	_check(not _player.is_left_shift_held(), "right Shift does not set left Shift latch", str(_player.is_left_shift_held()))
	_check(not _player.is_sprint_intent(), "right Shift does not select run", "sprint=%s" % str(_player.is_sprint_intent()))
	_check(_player.get_state_name() == "walk", "right Shift leaves state walking", _player.get_state_name())
	_check(absf(_player.get_target_speed() - 100.0) < 0.01, "right Shift leaves walk target at 100", "target=%.1f" % _player.get_target_speed())
	_key_up(KEY_SHIFT, KEY_LOCATION_RIGHT)
	_key_up(KEY_D)
	await _step(18)

	# Shift held before movement also selects run, and Q does not disturb it.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	_key_down(KEY_D)
	await _step(15)
	_check(_player.get_state_name() == "run", "Shift-before-direction selects run", _player.get_state_name())
	var run_restart: int = _player.get_anim_restart_count()
	await _step(5)
	_check(_player.get_anim_restart_count() == run_restart, "run animation does not restart every physics tick", "%d" % _player.get_anim_restart_count())
	await _tap_action(&"polarity")
	await _step(2)
	_check(_player.get_state_name() == "run", "Q while running does not reset movement state", _player.get_state_name())
	_check(not _player.is_positive(), "Q while running still switches polarity", str(_player.is_positive()))
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(2)
	_check(_player.get_state_name() == "walk", "Shift release during Q-run returns to walk", _player.get_state_name())
	_key_up(KEY_D)
	await _step(18)

	# Fixed walk showcase frame checks all effect layers mirror with facing.
	await _reset_player()
	_player.show_showcase(&"walk", 4, 1, true)
	var right_center: Vector2 = _player.get_chest_anchor_global()
	var right_glow: Vector2 = _player.get_glow_global_position()
	var right_ring: Vector2 = _player.get_ring_global_position()
	var right_origin: Vector2 = _player.global_position
	_player.show_showcase(&"walk", 4, -1, true)
	var left_center: Vector2 = _player.get_chest_anchor_global()
	var left_glow: Vector2 = _player.get_glow_global_position()
	var left_ring: Vector2 = _player.get_ring_global_position()
	var left_origin: Vector2 = _player.global_position
	var right_offset: float = right_center.x - right_origin.x
	var left_offset: float = left_center.x - left_origin.x
	_check(absf(right_offset + left_offset) < 0.02, "walk talisman X mirrors with facing", "right=%.2f left=%.2f" % [right_offset, left_offset])
	_check(
		absf((right_glow.x - right_origin.x) + (left_glow.x - left_origin.x)) < 0.02,
		"walk glow X mirrors with facing",
		"right=%.2f left=%.2f" % [right_glow.x - right_origin.x, left_glow.x - left_origin.x]
	)
	_check(
		absf((right_ring.x - right_origin.x) + (left_ring.x - left_origin.x)) < 0.02,
		"walk switch-ring X mirrors with facing",
		"right=%.2f left=%.2f" % [right_ring.x - right_origin.x, left_ring.x - left_origin.x]
	)
	_check(absf(_player.get_badge_global_position().x - _player.global_position.x) < 0.01, "head glyph stays outside mirrored VisualRoot", str(_player.get_badge_global_position()))
	_check(absf(_player.get_visual_root_scale().x + 1.0) < 0.01, "VisualRoot is mirrored for left facing", str(_player.get_visual_root_scale()))
	await _reset_player()


func _test_double_tap_rules() -> void:
	_section("DOUBLE-TAP RUN RULES")

	# Two complete presses of the same direction within 0.25 s, second held.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	await _step(1)
	_key_up(KEY_D)
	await _step(1)
	_key_down(KEY_D)
	await _step(12)
	_check(_player.is_double_tap_run_locked(), "same-direction double tap locks run", str(_player.is_double_tap_run_locked()))
	_check(_player.get_state_name() == "run", "double-tap held state is run", _player.get_state_name())
	_check(_player.velocity.x > 100.0, "double-tap run exceeds walk speed", "vx=%.1f" % _player.velocity.x)
	_key_up(KEY_D)
	await _step(12)
	_check(not _player.is_double_tap_run_locked(), "releasing direction cancels double-tap run", str(_player.is_double_tap_run_locked()))
	_check(_player.get_state_name() == "idle", "double-tap release returns to idle", _player.get_state_name())
	# Immediate re-press after release must not reuse the old tap window.
	_key_down(KEY_D)
	await _step(10)
	_check(_player.get_state_name() == "walk", "re-press after double-tap release starts walk", _player.get_state_name())
	_check(not _player.is_double_tap_run_locked(), "release cleared double-tap history", str(_player.is_double_tap_run_locked()))
	_key_up(KEY_D)
	await _step(12)

	# A gap longer than 0.25 s is not a double tap.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	await _step(1)
	_key_up(KEY_D)
	await _step(20)
	_key_down(KEY_D)
	await _step(10)
	_check(not _player.is_double_tap_run_locked(), "tap gap over 0.25 s does not lock run", "timer=%.3f" % _player.get_double_tap_timer())
	_check(_player.get_state_name() == "walk", "timed-out second press stays walk", _player.get_state_name())
	_key_up(KEY_D)
	await _step(12)

	# Alternating left/right does not form a same-direction double tap.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	await _step(1)
	_key_up(KEY_D)
	await _step(1)
	_key_down(KEY_A)
	await _step(1)
	_key_up(KEY_A)
	await _step(1)
	_key_down(KEY_D)
	await _step(10)
	_check(not _player.is_double_tap_run_locked(), "left/right alternation does not lock run", "last=%d" % _player.get_facing())
	_check(_player.get_state_name() == "walk", "alternating taps stay walk", _player.get_state_name())
	_key_up(KEY_D)
	await _step(12)

	# A and Left (or D and Right) are one direction; simultaneous equivalent
	# keys do not create a second press until both are released.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_A)
	await _step(1)
	_key_down(KEY_LEFT)
	await _step(2)
	_check(not _player.is_double_tap_run_locked(), "A+Left held together is not a second tap", str(_player.is_double_tap_run_locked()))
	_check(_player.get_state_name() == "walk", "equivalent-key hold stays walk", _player.get_state_name())
	_key_up(KEY_A)
	await _step(1)
	_key_up(KEY_LEFT)
	await _step(1)
	_key_down(KEY_A)
	await _step(10)
	_check(_player.is_double_tap_run_locked(), "second press after full equivalent-key release locks run", str(_player.is_double_tap_run_locked()))
	_check(_player.get_state_name() == "run", "equivalent-key double tap reaches run", _player.get_state_name())
	_key_up(KEY_A)
	await _step(12)

	# OS key-repeat echo is not a second press.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	await _step(1)
	_key_up(KEY_D)
	await _step(1)
	_send_key(KEY_D, true, KEY_LOCATION_UNSPECIFIED, true)
	await _step(10)
	_check(not _player.is_double_tap_run_locked(), "keyboard echo does not count as second tap", str(_player.is_double_tap_run_locked()))
	_check(_player.get_state_name() == "walk", "echo-held direction stays walk", _player.get_state_name())
	_key_up(KEY_D)
	await _step(12)

	# Double-tap run survives Shift release, but a direction change cancels it.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	_key_down(KEY_D)
	await _step(1)
	_key_up(KEY_D)
	await _step(1)
	_key_down(KEY_D)
	await _step(10)
	_check(_player.is_double_tap_run_locked(), "double tap with Shift held locks run", str(_player.is_double_tap_run_locked()))
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(2)
	_check(_player.get_state_name() == "run", "Shift release keeps double-tap run", _player.get_state_name())
	_check(_player.is_double_tap_run_locked(), "Shift release keeps double-tap lock", str(_player.is_double_tap_run_locked()))
	_key_down(KEY_A)
	await _step(3)
	_check(not _player.is_double_tap_run_locked(), "direction change cancels double-tap run", str(_player.is_double_tap_run_locked()))
	_check(_player.get_state_name() != "run", "direction change does not stay in run", _player.get_state_name())
	_key_up(KEY_D)
	await _step(5)
	_check(_player.get_state_name() == "walk", "remaining left input is walk after direction change", _player.get_state_name())
	_key_up(KEY_A)
	await _step(12)
	await _reset_player()


func _test_walk_sprint_cleanup() -> void:
	_section("SPRINT CLEANUP")

	# Pause while a double-tap run is active and the direction key is held.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	await _step(1)
	_key_up(KEY_D)
	await _step(1)
	_key_down(KEY_D)
	await _step(10)
	_check(_player.is_double_tap_run_locked(), "pause setup is double-tap run", str(_player.is_double_tap_run_locked()))
	await _tap_process_action(&"pause")
	_check(not _player.is_double_tap_run_locked(), "pause clears double-tap lock", str(_player.is_double_tap_run_locked()))
	_check(not _player.is_left_shift_held(), "pause clears Shift latch", str(_player.is_left_shift_held()))
	_check(_player.get_double_tap_timer() < 0.001, "pause clears double-tap timer", "timer=%.3f" % _player.get_double_tap_timer())
	await _tap_process_action(&"pause")
	await _step(8)
	_check(_player.get_state_name() == "walk", "resume with direction held is walk, not run", _player.get_state_name())
	_check(absf(_player.get_target_speed() - 100.0) < 0.01, "resume target is walk speed", "target=%.1f" % _player.get_target_speed())
	_key_up(KEY_D)
	await _step(12)

	# R reset while a double-tap run is active and the direction key is held.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	await _step(1)
	_key_up(KEY_D)
	await _step(1)
	_key_down(KEY_D)
	await _step(10)
	_check(_player.is_double_tap_run_locked(), "reset setup is double-tap run", str(_player.is_double_tap_run_locked()))
	await _tap_action(&"reset")
	await _step(8)
	_check(not _player.is_double_tap_run_locked(), "reset clears double-tap lock", str(_player.is_double_tap_run_locked()))
	_check(not _player.is_left_shift_held(), "reset clears Shift latch", str(_player.is_left_shift_held()))
	_check(_player.get_double_tap_timer() < 0.001, "reset clears double-tap timer", "timer=%.3f" % _player.get_double_tap_timer())
	_check(_player.get_state_name() == "walk", "reset with held direction resumes as walk", _player.get_state_name())
	_check(absf(_player.get_target_speed() - 100.0) < 0.01, "reset target is walk speed", "target=%.1f" % _player.get_target_speed())
	_key_up(KEY_D)
	await _step(12)

	# Focus loss while Shift-run is active.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	_key_down(KEY_D)
	await _step(12)
	_check(_player.get_state_name() == "run", "focus-loss setup is Shift run", _player.get_state_name())
	_game.handle_focus_lost()
	await _step(8)
	_check(not _player.is_left_shift_held(), "focus loss clears Shift latch", str(_player.is_left_shift_held()))
	_check(not _player.is_double_tap_run_locked(), "focus loss clears double-tap lock", str(_player.is_double_tap_run_locked()))
	_check(_player.get_state_name() == "walk", "focus loss with direction held resumes as walk", _player.get_state_name())
	_check(absf(_player.get_target_speed() - 100.0) < 0.01, "focus-loss target is walk speed", "target=%.1f" % _player.get_target_speed())
	_key_up(KEY_D)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(12)

	# Focus loss while a double-tap run is active.
	await _reset_player()
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	await _step(1)
	_key_up(KEY_D)
	await _step(1)
	_key_down(KEY_D)
	await _step(10)
	_check(_player.is_double_tap_run_locked(), "focus-loss double-tap setup", str(_player.is_double_tap_run_locked()))
	_game.handle_focus_lost()
	await _step(8)
	_check(not _player.is_double_tap_run_locked(), "focus loss clears double-tap run", str(_player.is_double_tap_run_locked()))
	_check(_player.get_state_name() == "walk", "focus loss after double tap is walk", _player.get_state_name())
	_key_up(KEY_D)
	await _step(12)
	await _reset_player()


func _test_jump_fall_landing() -> void:
	_section("JUMP / FALL / LANDING")
	await _reset_player()
	Input.action_press(&"jump")
	await _step(2)
	Input.action_release(&"jump")
	await _step(3)
	_check(_player.velocity.y < 0.0, "jump produces upward velocity", "vy=%.2f" % _player.velocity.y)
	_check(_player.get_state_name() == "jump", "ascending state is jump", _player.get_state_name())
	_check(not _player.is_on_floor(), "player leaves the floor", str(_player.global_position))
	var jump_restart: int = _player.get_anim_restart_count()
	await _step(4)
	_check(_player.get_anim_restart_count() == jump_restart, "jump animation does not re-trigger each tick", "%d" % _player.get_anim_restart_count())

	var state_seen: String = ""
	for i: int in range(80):
		await _step(1)
		state_seen = _player.get_state_name()
		if _player.velocity.y >= 0.0:
			break
	_check(state_seen == "fall" or state_seen == "fall_loop", "descent switches to fall/fall_loop", "%s vy=%.1f" % [state_seen, _player.velocity.y])

	var landed: bool = false
	for i: int in range(160):
		await _step(1)
		if _player.is_on_floor():
			landed = true
			break
	_check(landed, "player lands after a jump", str(_player.global_position))
	await _step(2)
	_check(_player.get_state_name() == "idle" or _player.get_state_name() == "walk" or _player.get_state_name() == "run", "landing clears fall state", _player.get_state_name())
	_check(not _player.get_state_name().begins_with("fall"), "no fall animation residue after landing", _player.get_state_name())
	_check(absf(_player.global_position.y - 288.0) < 0.75, "landing returns feet to ground top", "y=%.2f" % _player.global_position.y)

	# Long fall must use fall_loop before landing on platform A.
	await _reset_player()
	_player.global_position = Vector2(288.0, 40.0)
	_player.velocity = Vector2.ZERO
	await _step(32)
	_check(_player.get_state_name() == "fall_loop", "long descent reaches fall_loop", "%s y=%.1f" % [_player.get_state_name(), _player.global_position.y])
	var long_landed: bool = false
	for i: int in range(160):
		await _step(1)
		if _player.is_on_floor():
			long_landed = true
			break
	_check(long_landed, "long fall lands on platform A", str(_player.global_position))
	_check(absf(_player.global_position.y - 224.0) < 0.75, "long fall lands at platform A top (224)", "y=%.2f" % _player.global_position.y)
	await _reset_player()


func _test_air_intent() -> void:
	_section("AIR SPEED INTENT")
	await _reset_player()
	_player.global_position = Vector2(100.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_key_down(KEY_D)
	Input.action_press(&"jump")
	await _step(2)
	Input.action_release(&"jump")
	await _step(4)
	_check(_player.get_state_name() == "jump", "air-intent setup is jump", _player.get_state_name())
	_check(absf(_player.get_target_speed() - 100.0) < 0.01, "air target with no Shift is walk speed", "target=%.1f" % _player.get_target_speed())
	var air_walk_vx: float = _player.velocity.x
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(6)
	_check(absf(_player.get_target_speed() - 160.0) < 0.01, "air target with left Shift is run speed", "target=%.1f" % _player.get_target_speed())
	_check(_player.velocity.x > air_walk_vx + 10.0, "air velocity follows run intent", "before=%.1f after=%.1f" % [air_walk_vx, _player.velocity.x])
	_check(_player.get_state_name() == "jump" or _player.get_state_name() == "fall" or _player.get_state_name() == "fall_loop", "air intent adds no walk/run animation", _player.get_state_name())
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(3)
	_check(absf(_player.get_target_speed() - 100.0) < 0.01, "air target returns to walk after Shift release", "target=%.1f" % _player.get_target_speed())
	_check(_player.get_state_name() == "jump" or _player.get_state_name() == "fall" or _player.get_state_name() == "fall_loop", "air state remains jump/fall after Shift release", _player.get_state_name())
	await _reset_player()


func _test_platform_collisions() -> void:
	_section("PLATFORMS")
	_check(_game.get_collision_body_count() == 5, "five explicit collision rectangles", str(_game.get_collision_body_count()))
	var cases: Array[Dictionary] = [
		{"name": "short step", "drop": Vector2(176.0, 240.0), "top": 272.0},
		{"name": "platform A", "drop": Vector2(288.0, 190.0), "top": 224.0},
		{"name": "platform B", "drop": Vector2(416.0, 160.0), "top": 192.0},
		{"name": "right ground", "drop": Vector2(560.0, 250.0), "top": 288.0},
	]
	for test_case: Dictionary in cases:
		await _reset_player()
		var drop: Vector2 = test_case["drop"]
		var top: float = test_case["top"]
		_player.global_position = drop
		_player.velocity = Vector2.ZERO
		var supported: bool = false
		for i: int in range(90):
			await _step(1)
			if _player.is_on_floor():
				supported = true
				break
		_check(supported, "%s supports the body" % String(test_case["name"]), "pos=%s" % str(_player.global_position))
		_check(absf(_player.global_position.y - top) < 0.75, "%s collision top is %.0f" % [String(test_case["name"]), top], "y=%.2f" % _player.global_position.y)
		await _step(2)
		_check(_player.get_state_name() == "idle", "%s landing is idle" % String(test_case["name"]), _player.get_state_name())
	await _reset_player()


func _test_pit_respawn() -> void:
	_section("PIT RESPAWN")
	await _reset_player()
	var resets_before: int = _player.get_reset_count()
	_player.global_position = Vector2(480.0, 240.0)
	_player.velocity = Vector2.ZERO
	var respawned: bool = false
	for i: int in range(180):
		await _step(1)
		if _player.get_reset_count() > resets_before:
			respawned = true
			break
	_check(respawned, "falling into the gap triggers reset", "reset_count=%d" % _player.get_reset_count())
	await _step(4)
	_check(_player.global_position.is_equal_approx(_game.get_spawn_position()), "pit reset returns to spawn", str(_player.global_position))
	_check(_player.velocity.is_zero_approx(), "pit reset clears velocity", str(_player.velocity))
	_check(_player.is_positive(), "pit reset restores GOLD polarity", str(_player.is_positive()))
	_check(not _player.is_ring_visible(), "pit reset hides switch ring", "ring_visible=%s" % str(_player.is_ring_visible()))
	_check(_player.get_state_name() == "idle", "pit reset restores idle animation", _player.get_state_name())


func _test_polarity_and_ring() -> void:
	_section("POLARITY / RING")
	await _reset_player()
	_check(_player.is_positive(), "initial polarity is GOLD", str(_player.is_positive()))
	_check(_player.get_talisman_texture().resource_path.ends_with("talisman_gold.png"), "gold talisman texture active", _player.get_talisman_texture().resource_path)
	_check(_player.get_glow_texture().resource_path.ends_with("glow_gold_4f.png"), "gold glow texture active", _player.get_glow_texture().resource_path)
	_check(not _player.is_ring_visible(), "ring hidden at spawn", "ring_visible=false")

	await _tap_action(&"polarity")
	await _step(1)
	_check(not _player.is_positive(), "Q toggles to CYAN", str(_player.is_positive()))
	_check(_player.get_talisman_texture().resource_path.ends_with("talisman_cyan.png"), "cyan talisman texture active", _player.get_talisman_texture().resource_path)
	_check(_player.get_glow_texture().resource_path.ends_with("glow_cyan_4f.png"), "cyan glow texture active", _player.get_glow_texture().resource_path)
	_check(_player.get_ring_texture().resource_path.ends_with("switch_ring_cyan_4f.png"), "cyan ring texture active", _player.get_ring_texture().resource_path)
	_check(_hud.get_polarity_text().contains("CYAN"), "HUD updates to CYAN", _hud.get_polarity_text())
	_check(_player.is_ring_visible(), "switch ring is visible after toggle", "ring_frame=%d" % _player.get_ring_frame())
	_check(_player.get_switch_ring_node_count() == 1, "exactly one ring node", str(_player.get_switch_ring_node_count()))
	await _step(20)
	_check(not _player.is_ring_visible(), "switch ring hides after ~0.2 s", "ring_time elapsed")

	await _reset_player()
	Input.action_press(&"polarity")
	await _step(120)
	Input.action_release(&"polarity")
	await _step(3)
	_check(_player.get_polarity_toggle_count() == 1, "holding Q for 2 s toggles exactly once", "toggles=%d" % _player.get_polarity_toggle_count())
	_check(not _player.is_positive(), "long hold ends on CYAN", str(_player.is_positive()))

	await _reset_player()
	for i: int in range(5):
		Input.action_press(&"polarity")
		await _step(1)
		Input.action_release(&"polarity")
		await _step(1)
	_check(_player.get_polarity_toggle_count() == 5, "five rapid taps toggle five times", "toggles=%d" % _player.get_polarity_toggle_count())
	_check(not _player.is_positive(), "five toggles end on CYAN", str(_player.is_positive()))
	_check(_player.get_switch_ring_node_count() == 1, "rapid taps do not accumulate ring nodes", str(_player.get_switch_ring_node_count()))
	_check(_player.is_ring_visible(), "rapid taps leave one active ring", "ring_frame=%d" % _player.get_ring_frame())
	await _step(20)
	_check(not _player.is_ring_visible(), "rapid-tap ring eventually hides", "ring_visible=false")
	await _reset_player()


func _test_manual_reset() -> void:
	_section("MANUAL RESET")
	await _reset_player()
	await _tap_action(&"move_right")
	await _step(12)
	await _tap_action(&"polarity")
	await _step(4)
	var resets_before: int = _player.get_reset_count()
	await _tap_action(&"reset")
	await _step(3)
	_check(_player.global_position.is_equal_approx(_game.get_spawn_position()), "R returns to spawn", str(_player.global_position))
	_check(_player.velocity.is_zero_approx(), "R clears velocity", str(_player.velocity))
	_check(_player.is_positive(), "R restores GOLD polarity", str(_player.is_positive()))
	_check(not _player.is_ring_visible(), "R hides switch ring", "ring_visible=false")
	_check(_player.get_state_name() == "idle", "R restores idle animation", _player.get_state_name())
	_check(_player.get_reset_count() == resets_before + 1, "R increments reset count", "%d -> %d" % [resets_before, _player.get_reset_count()])
	_check(_hud.get_polarity_text().contains("GOLD"), "HUD returns to GOLD after R", _hud.get_polarity_text())


func _test_coyote_and_jump_buffer() -> void:
	_section("JUMP TOLERANCE")
	await _reset_player()
	await _player_stable()
	# Coyote jump: leave the ledge and press jump within 0.1 s.
	_player.global_position = Vector2(430.0, 280.0)
	_player.velocity = Vector2.ZERO
	await _step(2)
	_check(not _player.is_on_floor(), "coyote setup is airborne", str(_player.global_position))
	Input.action_press(&"jump")
	await _step(2)
	Input.action_release(&"jump")
	_check(_player.velocity.y < 0.0, "coyote jump still launches after leaving ledge", "vy=%.2f" % _player.velocity.y)
	await _reset_player()

	# Buffered jump: press just before landing and let the buffer fire on contact.
	await _reset_player()
	_player.global_position = Vector2(80.0, 250.0)
	_player.velocity = Vector2.ZERO
	var pressed: bool = false
	for i: int in range(120):
		await _step(1)
		if _player.global_position.y >= 281.0 and not _player.is_on_floor():
			Input.action_press(&"jump")
			await _step(1)
			Input.action_release(&"jump")
			pressed = true
			break
	_check(pressed, "jump buffer test found the approach window", str(_player.global_position))
	await _step(18)
	_check(_player.velocity.y < 0.0, "buffered jump fires on landing", "vy=%.2f state=%s" % [_player.velocity.y, _player.get_state_name()])
	await _reset_player()


func _test_world_bounds() -> void:
	_section("WORLD BOUNDS")
	await _reset_player()
	_player.global_position = Vector2(630.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	Input.action_press(&"move_right")
	await _step(40)
	Input.action_release(&"move_right")
	await _step(10)
	_check(_player.global_position.x <= 634.01, "right edge clamp prevents running out of the room", "x=%.2f" % _player.global_position.x)

	await _reset_player()
	_player.global_position = Vector2(10.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(3)
	Input.action_press(&"move_left")
	await _step(40)
	Input.action_release(&"move_left")
	await _step(10)
	_check(_player.global_position.x >= 5.99, "left edge clamp prevents running out of the room", "x=%.2f" % _player.global_position.x)
	await _reset_player()


func _test_pause_and_debug() -> void:
	_section("PAUSE / DEBUG")
	await _reset_player()
	await _tap_process_action(&"pause")
	_check(_game.is_paused(), "Esc pauses the scene tree", str(_game.is_paused()))
	_check(_hud.is_pause_visible(), "pause overlay is visible", str(_hud.is_pause_visible()))
	var paused_position: Vector2 = _player.global_position
	Input.action_press(&"move_right")
	await _step(20)
	Input.action_release(&"move_right")
	_check(_player.global_position.is_equal_approx(paused_position), "player physics is frozen while paused", str(_player.global_position))
	await _tap_process_action(&"pause")
	_check(not _game.is_paused(), "Esc resumes the scene tree", str(_game.is_paused()))
	_check(not _hud.is_pause_visible(), "pause overlay hides after resume", str(_hud.is_pause_visible()))
	await _reset_player()

	await _tap_process_action(&"toggle_debug")
	_check(_player.is_debug_enabled(), "F3 enables chest/collision debug overlay", str(_player.is_debug_enabled()))
	_check(_hud.get_debug_visible(), "HUD shows debug anchor text", str(_hud.get_debug_visible()))
	_check(_hud.get_state_text().contains("STATE"), "bottom-right state panel remains readable", _hud.get_state_text())
	await _tap_process_action(&"toggle_debug")
	_check(not _player.is_debug_enabled(), "F3 toggles debug overlay off", str(_player.is_debug_enabled()))
	await _reset_player()

	# Effects must freeze with the scene while paused, then finish after resume.
	await _tap_action(&"polarity")
	var ring_visible_before: bool = _player.is_ring_visible()
	await _tap_process_action(&"pause")
	var frozen_ring_frame: int = _player.get_ring_frame()
	await _step(30)
	_check(ring_visible_before and _player.is_ring_visible(), "switch ring stays visible while paused", "visible=%s" % str(_player.is_ring_visible()))
	_check(_player.get_ring_frame() == frozen_ring_frame, "switch-ring frame freezes while paused", "%d -> %d" % [frozen_ring_frame, _player.get_ring_frame()])
	await _tap_process_action(&"pause")
	await _step(20)
	_check(not _player.is_ring_visible(), "switch ring finishes after resume", "visible=false")
	await _reset_player()


func _test_effect_node_integrity() -> void:
	_section("EFFECT NODES")
	await _reset_player()
	var visual_root: Node = _player.get_node("VisualRoot")
	var names: Array[String] = []
	for child: Node in visual_root.get_children():
		names.append(String(child.name))
	_check(names.count("Talisman") == 1, "one talisman node", str(names))
	_check(names.count("Glow") == 1, "one glow node", str(names))
	_check(names.count("SwitchRing") == 1, "one switch-ring node", str(names))
	_check(_player.get_glow_texture().get_width() == 44, "glow sheet width is 44 (4x11)", str(_player.get_glow_texture().get_size()))
	_check(_player.get_ring_texture().get_width() == 96, "ring sheet width is 96 (4x24)", str(_player.get_ring_texture().get_size()))
	_check(_player.get_talisman_texture().get_width() == 5, "talisman texture is 5x5", str(_player.get_talisman_texture().get_size()))

	var glow_node: Sprite2D = _player.get_node("VisualRoot/Glow") as Sprite2D
	var talisman_node: Sprite2D = _player.get_node("VisualRoot/Talisman") as Sprite2D
	var ring_node: Sprite2D = _player.get_node("VisualRoot/SwitchRing") as Sprite2D
	var char_node: Sprite2D = _player.get_node("VisualRoot/CharacterSprite") as Sprite2D
	var badge_node: Node2D = _player.get_node("PolarityBadge") as Node2D
	_check(
		glow_node.z_index == -1 and char_node.z_index == 0
		and talisman_node.z_index == 1 and ring_node.z_index == 2
		and badge_node.z_index == 6,
		"effect layer order is glow < body < talisman < ring < badge",
		"z=%d/%d/%d/%d/%d" % [glow_node.z_index, char_node.z_index, talisman_node.z_index, ring_node.z_index, badge_node.z_index]
	)
	var glow_frame_before: int = _player.get_glow_frame()
	await _step(12)
	var glow_frame_after: int = _player.get_glow_frame()
	_check(glow_frame_before != glow_frame_after, "4-frame glow pulse advances over time", "%d -> %d" % [glow_frame_before, glow_frame_after])
	await _reset_player()


func _test_anchor_room_entry() -> void:
	_section("ANCHOR ROOM ENTRY / F2")
	_check(not _game.is_in_anchor_room(), "starts in the basic room", str(_game.is_in_anchor_room()))
	_check(_game.get_collision_body_count() == 5, "basic room keeps its five collision rectangles", str(_game.get_collision_body_count()))
	_check(_game.get_anchor_room().get_collision_body_count() == 2, "anchor room has two solid platforms", str(_game.get_anchor_room().get_collision_body_count()))
	_check(not _game.get_anchor_room().visible, "anchor room is hidden before entry", str(_game.get_anchor_room().visible))
	var base_terrain: TileMapLayer = _game.get_node("World/Terrain") as TileMapLayer
	var base_body: StaticBody2D = _game.get_node("World/PlatformCollision0") as StaticBody2D
	_check(base_terrain.visible and base_body.collision_layer == 1, "basic terrain and collisions are active initially", str(base_body.collision_layer))

	await _tap_process_action(&"toggle_anchor_room")
	await _step(6)
	_check(_game.is_in_anchor_room(), "F2 enters the anchor room", str(_game.is_in_anchor_room()))
	_check(_game.get_anchor_room().is_active(), "anchor room controller is active", str(_game.get_anchor_room().is_active()))
	_check(_game.get_anchor_room().visible, "anchor room becomes visible", str(_game.get_anchor_room().visible))
	_check(_player.global_position.is_equal_approx(_game.get_anchor_room().get_spawn_position()), "anchor room spawns at its own point", str(_player.global_position))
	_check(_player.is_positive(), "anchor room entry restores GOLD polarity", str(_player.is_positive()))
	_check(_hud.is_anchor_panel_visible(), "HUD shows anchor field panel", str(_hud.is_anchor_panel_visible()))
	_check(not _hud.is_state_panel_visible(), "basic-room state panel is hidden in anchor mode", str(_hud.is_state_panel_visible()))
	_check(_hud.get_anchor_guide_text().contains("ATTRACT") and _hud.get_anchor_guide_text().contains("REPEL"), "HUD gives attract/repel route guidance", _hud.get_anchor_guide_text())
	_check(_hud.get_anchor_status_text().contains("OUT OF RANGE"), "spawn is outside the anchor range", _hud.get_anchor_status_text())
	_check(not base_terrain.visible and base_body.collision_layer == 0, "basic terrain is hidden and its collision disabled", str(base_body.collision_layer))
	var anchor_body: StaticBody2D = _game.get_node("AnchorRoom/AnchorPlatformCollision0") as StaticBody2D
	_check(anchor_body.collision_layer == 1, "anchor platform collision is enabled", str(anchor_body.collision_layer))

	await _tap_process_action(&"toggle_debug")
	_check(_player.is_debug_enabled(), "F3 enables anchor range/force drawing", str(_player.is_debug_enabled()))
	_check(absf(_game.get_anchor_room().get_range() - 160.0) < 0.01, "anchor range is 160 px", "%.1f" % _game.get_anchor_room().get_range())
	_check(_game.get_anchor_room().get_anchor_position().is_equal_approx(Vector2(320.0, 200.0)), "fixed anchor is at (320, 200)", str(_game.get_anchor_room().get_anchor_position()))
	var anchor_visual: RuneStoneVisual = _game.get_anchor_room().get_rune_stone()
	_check(
		anchor_visual != null
		and anchor_visual.has_art()
		and anchor_visual.polarity_positive
		and anchor_visual.is_energized(),
		"F2 fixed anchor reuses the shared GOLD rune-stone visual"
	)
	await _tap_process_action(&"toggle_debug")
	_check(not _player.is_debug_enabled(), "F3 toggles anchor debug off", str(_player.is_debug_enabled()))

	await _tap_process_action(&"toggle_anchor_room")
	await _step(6)
	_check(not _game.is_in_anchor_room(), "F2 returns to the basic room", str(_game.is_in_anchor_room()))
	_check(_player.global_position.is_equal_approx(_game.get_spawn_position()), "basic room spawn is restored", str(_player.global_position))
	_check(base_terrain.visible and base_body.collision_layer == 1, "basic terrain and collisions are restored", str(base_body.collision_layer))
	_check(not _hud.is_anchor_panel_visible() and _hud.is_state_panel_visible(), "HUD returns to the basic layout", str(_hud.is_anchor_panel_visible()))
	_check(
		is_zero_approx(_player.get_anchor_force_x())
		and is_zero_approx(_player.get_anchor_force_y())
		and not _player.is_anchor_force_pending(),
		"F2 exit clears any hidden anchor force",
		"F(%+.0f,%+.0f) pending=%s" % [
			_player.get_anchor_force_x(),
			_player.get_anchor_force_y(),
			str(_player.is_anchor_force_pending()),
		]
	)

	await _tap_process_action(&"toggle_anchor_room")
	await _step(6)
	_check(_game.is_in_anchor_room(), "anchor room re-enters for the remaining tests", str(_game.is_in_anchor_room()))
	await _reset_player()


func _test_anchor_field_rules() -> void:
	_section("ANCHOR RANGE / SIGN / ZERO / GRAVITY")
	await _prepare_anchor_trial(Vector2(200.0, 240.0), true)
	var center: Vector2 = Vector2(200.0, 225.0)
	var to_anchor: Vector2 = _game.get_anchor_room().get_anchor_position() - center
	var attract_field: Dictionary = _game.get_anchor_room().compute_field(center)
	var attract_force: Vector2 = attract_field["acceleration"]
	_check(String(attract_field["status"]) == "ATTRACT", "opposite polarity is ATTRACT", String(attract_field["status"]))
	_check(attract_force.dot(to_anchor) > 0.0 and attract_force.length() > 1100.0, "attract acceleration points at the stone", str(attract_force))
	_check(not bool(attract_field["blocked"]), "clear line of sight is not blocked", str(attract_field["blocked"]))

	await _tap_action(&"polarity")
	var repel_field: Dictionary = _game.get_anchor_room().compute_field(center)
	var repel_force: Vector2 = repel_field["acceleration"]
	_check(String(repel_field["status"]) == "REPEL", "same polarity is REPEL", String(repel_field["status"]))
	_check(repel_force.dot(to_anchor) < 0.0 and repel_force.length() > 1100.0, "repel acceleration points away from the stone", str(repel_force))

	var far_field: Dictionary = _game.get_anchor_room().compute_field(Vector2(72.0, 273.0))
	var far_force: Vector2 = far_field["acceleration"]
	_check(String(far_field["status"]) == "OUT OF RANGE", "outside 160 px is OUT OF RANGE", String(far_field["status"]))
	_check(far_force.is_zero_approx(), "out-of-range force is zero", str(far_field["acceleration"]))
	_check(float(far_field["distance"]) > 160.0, "out-of-range distance exceeds range", "%.1f" % float(far_field["distance"]))

	var zero_field: Dictionary = _game.get_anchor_room().compute_field(_game.get_anchor_room().get_anchor_position())
	var zero_force: Vector2 = zero_field["acceleration"]
	_check(String(zero_field["status"]).contains("NEAR"), "zero distance reports NEAR/STABLE", String(zero_field["status"]))
	_check(zero_force.is_zero_approx(), "zero distance force is neutral", str(zero_force))
	_check(is_finite(zero_force.x) and is_finite(zero_force.y), "zero distance never produces NaN", str(zero_force))

	await _tap_action(&"polarity")
	var lift_field: Dictionary = _game.get_anchor_room().compute_field(Vector2(320.0, 285.0))
	var lift_force: Vector2 = lift_field["acceleration"]
	_check(-lift_force.y > 1100.0, "full-strength attraction exceeds gravity (1100)", "ay=%.1f" % -lift_force.y)

	_player.global_position = Vector2(200.0, 240.0)
	_player.velocity = Vector2.ZERO
	await _step(1)
	_check(_game.get_anchor_room().get_status() == "ATTRACT", "live field reports ATTRACT", _game.get_anchor_room().get_status())
	_check(_hud.get_anchor_status_text().contains("ATTRACT"), "HUD reports ATTRACT", _hud.get_anchor_status_text())
	await _tap_action(&"polarity")
	await _step(1)
	_check(_game.get_anchor_room().get_status() == "REPEL", "live field reports REPEL", _game.get_anchor_room().get_status())
	_check(_hud.get_anchor_status_text().contains("REPEL"), "HUD reports REPEL", _hud.get_anchor_status_text())

	await _prepare_anchor_trial(Vector2(320.0, 300.0), true)
	var lift_y_before: float = _player.global_position.y
	await _step(8)
	_check(_player.global_position.y < lift_y_before - 1.0, "actual physics lifts the body upward", "y %.1f -> %.1f" % [lift_y_before, _player.global_position.y])
	_check(_player.velocity.y < 0.0, "net vertical velocity is upward", "vy=%.1f" % _player.velocity.y)


func _test_anchor_occlusion_limits_and_bounds() -> void:
	_section("ANCHOR LOS / SPEED CAP / INERTIA / BOUNDS")
	await _prepare_anchor_trial(Vector2(200.0, 240.0), true)

	var blocker: StaticBody2D = StaticBody2D.new()
	blocker.name = "AnchorTestOccluder"
	blocker.collision_layer = 1
	blocker.collision_mask = 1
	blocker.position = Vector2(250.0, 214.0)
	var blocker_shape: CollisionShape2D = CollisionShape2D.new()
	var blocker_rect: RectangleShape2D = RectangleShape2D.new()
	blocker_rect.size = Vector2(30.0, 20.0)
	blocker_shape.shape = blocker_rect
	blocker.add_child(blocker_shape)
	_game.get_node("World").add_child(blocker)
	await _step(3)

	var blocked_field: Dictionary = _game.get_anchor_room().compute_field(Vector2(200.0, 225.0))
	var blocked_force: Vector2 = blocked_field["acceleration"]
	_check(bool(blocked_field["blocked"]), "solid body between centre line blocks the field", str(blocked_field["blocked"]))
	_check(String(blocked_field["status"]) == "BLOCKED", "blocked line reports BLOCKED", String(blocked_field["status"]))
	_check(blocked_force.is_zero_approx(), "blocked force is zero", str(blocked_field["acceleration"]))
	await _step(1)
	_check(_game.get_anchor_room().get_status() == "BLOCKED", "live field reports BLOCKED", _game.get_anchor_room().get_status())
	_check(_hud.get_anchor_status_text().contains("BLOCKED"), "HUD reports BLOCKED", _hud.get_anchor_status_text())

	blocker.queue_free()
	await _step(3)
	var clear_field: Dictionary = _game.get_anchor_room().compute_field(Vector2(200.0, 225.0))
	_check(not bool(clear_field["blocked"]), "removing the occluder restores line of sight", str(clear_field["blocked"]))

	await _prepare_anchor_trial(Vector2(320.0, 260.0), true)
	_player.velocity = Vector2(800.0, 0.0)
	await _step(1)
	_check(absf(_player.velocity.x) <= _player.get_anchor_horizontal_speed_cap() + 0.05, "anchor-assisted horizontal speed is capped at 320", "vx=%.1f" % _player.velocity.x)

	# Borrowed inertia: apply a vertical force directly while holding the opposite
	# direction, then repeat without the force. The first case must keep the
	# carried 300 px/s; normal air control in the second case must brake it.
	await _prepare_anchor_trial(Vector2(72.0, 200.0), true)
	_player.velocity = Vector2(300.0, 0.0)
	_key_down(KEY_A)
	for i: int in range(8):
		_player.apply_external_force(Vector2(0.0, -300.0))
		await _step(1)
	_key_up(KEY_A)
	_check(_player.was_anchor_assisted(), "external force was applied for the inertia test", str(_player.was_anchor_assisted()))
	_check(_player.velocity.x > 280.0, "opposite input cannot erase borrowed horizontal inertia", "vx=%.1f" % _player.velocity.x)

	await _prepare_anchor_trial(Vector2(72.0, 200.0), true)
	_player.velocity = Vector2(300.0, 0.0)
	_key_down(KEY_A)
	await _step(8)
	_key_up(KEY_A)
	_check(_player.velocity.x < 240.0, "normal air control still brakes when no force is active", "vx=%.1f" % _player.velocity.x)

	await _prepare_anchor_trial(Vector2(320.0, 260.0), true)
	_player.global_position = Vector2(320.0, -50.0)
	_player.velocity = Vector2(0.0, -100.0)
	await _step(2)
	_check(_player.global_position.y >= 7.99, "anchor room ceiling keeps the player on screen", "y=%.2f" % _player.global_position.y)
	_check(_player.global_position.x >= 5.99 and _player.global_position.x <= 634.01, "anchor room keeps the player inside the screen width", "x=%.2f" % _player.global_position.x)
	await _reset_player()


func _test_anchor_pause_and_reset() -> void:
	_section("ANCHOR PAUSE / R RESET")
	await _prepare_anchor_trial(Vector2(320.0, 260.0), true)
	await _step(2)
	await _tap_process_action(&"pause")
	_check(_game.is_paused(), "Esc pauses in the anchor room", str(_game.is_paused()))
	var frozen_position: Vector2 = _player.global_position
	var frozen_velocity: Vector2 = _player.velocity
	var frozen_status: String = _game.get_anchor_room().get_status()
	var frozen_hud: String = _hud.get_anchor_status_text()
	await _step(30)
	_check(_player.global_position.is_equal_approx(frozen_position), "anchor player position freezes while paused", str(_player.global_position))
	_check(_player.velocity.is_equal_approx(frozen_velocity), "anchor player velocity freezes while paused", str(_player.velocity))
	_check(_game.get_anchor_room().get_status() == frozen_status, "anchor field status freezes while paused", _game.get_anchor_room().get_status())
	_check(_hud.get_anchor_status_text() == frozen_hud, "anchor HUD freezes while paused", _hud.get_anchor_status_text())
	await _tap_process_action(&"pause")
	_check(not _game.is_paused(), "Esc resumes the anchor room", str(_game.is_paused()))

	var resets_before: int = _player.get_reset_count()
	await _tap_action(&"reset")
	await _step(5)
	_check(_player.global_position.is_equal_approx(_game.get_anchor_room().get_spawn_position()), "R returns to the anchor-room spawn", str(_player.global_position))
	_check(_player.is_positive(), "R restores GOLD polarity in the anchor room", str(_player.is_positive()))
	_check(_player.get_reset_count() == resets_before + 1, "R increments the anchor-room reset count", "%d -> %d" % [resets_before, _player.get_reset_count()])
	_check(not _game.get_anchor_room().is_success(), "R clears anchor success state", str(_game.get_anchor_room().is_success()))
	_check(not _hud.is_anchor_success_visible(), "R hides the success banner", str(_hud.is_anchor_success_visible()))
	_check(_hud.get_anchor_status_text().contains("OUT OF RANGE"), "R restores out-of-range field feedback", _hud.get_anchor_status_text())


func _test_anchor_plain_run_jump_fails() -> void:
	_section("ANCHOR ROUTE / PLAIN RUN-JUMP FAILS")
	await _prepare_anchor_trial(Vector2(160.0, 288.0), false, Vector2(160.0, 0.0))
	var resets_before: int = _player.get_reset_count()
	await _start_anchor_jump_run()
	var max_x: float = _player.global_position.x
	var success: bool = false
	for i: int in range(150):
		await _step(1)
		max_x = maxf(max_x, _player.global_position.x)
		if _game.get_anchor_room().is_success():
			success = true
			break
		if _player.get_reset_count() > resets_before:
			break
	await _stop_anchor_run()
	_check(not success, "plain run-jump cannot reach the destination", str(_player.global_position))
	_check(max_x < _game.get_anchor_room().get_destination_rect().position.x, "plain run-jump stays left of the destination", "max_x=%.1f" % max_x)
	_check(_player.get_reset_count() > resets_before, "plain run-jump falls and auto-respawns", "resets=%d" % (_player.get_reset_count() - resets_before))
	_log("  plain run-jump: max_x=%.1f reset_delta=%d" % [max_x, _player.get_reset_count() - resets_before])


func _test_anchor_attraction_only_fails() -> void:
	_section("ANCHOR ROUTE / ATTRACTION-ONLY")
	await _prepare_anchor_trial(Vector2(160.0, 288.0), true, Vector2(160.0, 0.0))
	await _start_anchor_jump_run()
	var max_x: float = _player.global_position.x
	var success: bool = false
	for i: int in range(180):
		await _step(1)
		max_x = maxf(max_x, _player.global_position.x)
		if _game.get_anchor_room().is_success():
			success = true
			break
	await _stop_anchor_run()
	_check(not success, "attraction without the second switch does not finish", str(_player.global_position))
	_check(max_x < _game.get_anchor_room().get_destination_rect().position.x, "attraction-only path falls short of the ledge", "max_x=%.1f" % max_x)
	_log("  attraction-only: max_x=%.1f success=%s status=%s" % [max_x, str(success), _game.get_anchor_room().get_status()])
	await _reset_player()


func _test_anchor_switch_window_and_success() -> void:
	_section("ANCHOR ROUTE / SWITCH WINDOW")
	var wins: Array[int] = []
	var longest_run: int = 0
	for switch_frame: int in range(15, 56):
		await _prepare_anchor_trial(Vector2(160.0, 288.0), true, Vector2(160.0, 0.0))
		await _start_anchor_jump_run()
		for frame: int in range(1, 101):
			if frame == switch_frame:
				Input.action_press(&"polarity")
			await _step(1)
			if frame == switch_frame:
				Input.action_release(&"polarity")
			if _game.get_anchor_room().is_success():
				break
		await _stop_anchor_run()
		if _game.get_anchor_room().is_success():
			wins.append(switch_frame)

	var run_length: int = 0
	for index: int in range(wins.size()):
		if index > 0 and wins[index] == wins[index - 1] + 1:
			run_length += 1
		else:
			run_length = 1
		longest_run = maxi(longest_run, run_length)

	var first_window: int = wins[0] if wins.size() > 0 else -1
	var last_window: int = wins[-1] if wins.size() > 0 else -1
	_check(wins.size() >= 15, "switch corridor is at least 0.25 s wide", "%d frames" % wins.size())
	_check(longest_run >= 15, "switch corridor is continuous", "%d consecutive frames" % longest_run)
	_check(first_window >= 0 and first_window <= 40, "early edge of switch window is reasonable", "first=%d" % first_window)
	_check(last_window >= 40, "late edge of switch window is reasonable", "last=%d" % last_window)
	_check(not wins.has(15), "switching long before the stone fails", "frame 15")
	_check(not wins.has(55), "switching long after the stone fails", "frame 55")
	_log("  Q switch window after jump: %d..%d (%d frames / %.2f s)" % [
		first_window, last_window, wins.size(), float(wins.size()) / 60.0
	])

	var switch_at: int = wins[int(wins.size() / 2)]
	await _prepare_anchor_trial(Vector2(160.0, 288.0), true, Vector2(160.0, 0.0))
	await _start_anchor_jump_run()
	var max_vx: float = 0.0
	var max_x: float = 0.0
	var min_y: float = 9999.0
	var success: bool = false
	var landing_frame: int = -1
	for frame: int in range(1, 101):
		if frame == switch_at:
			Input.action_press(&"polarity")
		await _step(1)
		if frame == switch_at:
			Input.action_release(&"polarity")
		max_vx = maxf(max_vx, absf(_player.velocity.x))
		max_x = maxf(max_x, _player.global_position.x)
		min_y = minf(min_y, _player.global_position.y)
		if _game.get_anchor_room().is_success():
			success = true
			landing_frame = frame
			break
	var success_position: Vector2 = _player.global_position
	var success_status: String = _game.get_anchor_room().get_status()
	var success_force: Vector2 = _game.get_anchor_room().get_last_force()
	_key_up(KEY_D)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	max_x = maxf(max_x, success_position.x)
	var destination: Rect2 = _game.get_anchor_room().get_destination_rect()
	_check(success, "attract then repel reaches the destination", "switch=%d" % switch_at)
	_check(success_position.x >= destination.position.x - 1.0 and success_position.x <= destination.end.x + 1.0, "landing x is on the wide ledge", "x=%.1f" % success_position.x)
	_check(absf(success_position.y - destination.position.y) <= 1.5, "landing y is the ledge top 336", "y=%.1f" % success_position.y)
	_check(_player.is_positive(), "successful finish is GOLD polarity", str(_player.is_positive()))
	_check(_player.is_on_floor(), "successful finish stands on solid floor", str(_player.is_on_floor()))
	_check(success_status != "COMPLETE", "success does not mask the real field state", success_status)
	_check(success_status == "REPEL" and success_force.length() > 0.0, "field still applies REPEL on the destination", "%s %.0f" % [success_status, success_force.length()])
	_check(_hud.is_anchor_success_visible(), "HUD shows destination success banner", str(_hud.is_anchor_success_visible()))
	_check(_hud.get_anchor_status_text().contains("REPEL"), "HUD field line still reports REPEL after arrival", _hud.get_anchor_status_text())
	_check(max_vx <= _player.get_anchor_horizontal_speed_cap() + 0.05 and max_vx > 250.0, "successful fling obeys the 320 px/s cap", "max_vx=%.1f" % max_vx)
	_check(min_y >= 8.0, "successful route never leaves the top of the screen", "min_y=%.1f" % min_y)
	_check(max_x <= 634.01, "successful route never leaves the right edge", "max_x=%.1f" % max_x)
	_log("  successful switch=%d landing_frame=%d x=%.1f y=%.1f max_vx=%.1f min_y=%.1f" % [
		switch_at, landing_frame, success_position.x, success_position.y, max_vx, min_y
	])

	# Q immediately after success must flip the live field to ATTRACT and apply
	# an actual force; completion is only a banner/record, not a force latch.
	await _tap_action(&"polarity")
	_check(not _player.is_positive(), "Q after success switches to CYAN", str(_player.is_positive()))
	_check(_game.get_anchor_room().get_status() == "ATTRACT", "Q after success shows real ATTRACT", _game.get_anchor_room().get_status())
	_check(_hud.get_anchor_status_text().contains("ATTRACT"), "HUD reports ATTRACT after success", _hud.get_anchor_status_text())
	var post_success_force: Vector2 = _game.get_anchor_room().get_last_force()
	_check(post_success_force.length() > 0.0 and post_success_force.x < 0.0, "attraction force is actually applied after success", str(post_success_force))
	_check(_player.was_anchor_assisted(), "player consumed the post-success attraction force", str(_player.was_anchor_assisted()))

	var resets_before: int = _player.get_reset_count()
	await _tap_action(&"reset")
	await _step(5)
	_check(_player.global_position.is_equal_approx(_game.get_anchor_room().get_spawn_position()), "R after success returns to anchor spawn", str(_player.global_position))
	_check(_player.is_positive() and not _game.get_anchor_room().is_success(), "R after success restores GOLD and clears completion", str(_player.is_positive()))
	_check(not _hud.is_anchor_success_visible(), "R after success clears the success banner", str(_hud.is_anchor_success_visible()))
	_check(_hud.get_anchor_status_text().contains("OUT OF RANGE"), "R after success restores field feedback", _hud.get_anchor_status_text())
	_check(_player.get_reset_count() == resets_before + 1, "R after success increments reset count", "%d" % _player.get_reset_count())


func _test_anchor_return_after_success() -> void:
	_section("ANCHOR RETURN / FIELD AFTER SUCCESS")
	var samples: Array[int] = [5, 10, 21, 31, 36]
	var wins: Array[int] = []
	for switch_frame: int in samples:
		var result: Dictionary = await _attempt_return_after_success(switch_frame)
		_log("  return switch=%d ok=%s reset=%s land_frame=%d x=%.1f y=%.1f edge=%.1f launch=%s minx=%.1f miny=%.1f" % [
			switch_frame,
			str(result["ok"]),
			str(result["reset"]),
			int(result["frame"]),
			float(result["x"]),
			float(result["y"]),
			float(result["edge_x"]),
			String(result["launch_status"]),
			float(result["minx"]),
			float(result["miny"]),
		])
		if bool(result["ok"]):
			wins.append(switch_frame)
	_check(wins.has(10) and wins.has(21) and wins.has(31), "return samples 10/21/31 land on the left platform", str(wins))
	_check(not wins.has(5), "return switch frame 5 is too early", str(wins))
	_check(not wins.has(36), "return switch frame 36 is too late", str(wins))
	_log("  return sampled window: 10/21/31 succeed, 5/36 fail; dedicated scan measured 10..31")


func _attempt_return_after_success(switch_frame: int) -> Dictionary:
	var forward: bool = await _land_on_right_ledge()
	_key_up(KEY_D)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	if not forward:
		return {
			"ok": false, "reset": false, "frame": -1, "x": _player.global_position.x,
			"y": _player.global_position.y, "edge_x": 0.0, "launch_status": "NO_SUCCESS",
			"minx": 9999.0, "miny": 9999.0,
		}
	# Let the post-landing momentum stop on the wide ledge, then walk back to
	# the edge area. This is movement, not a teleport in the production path.
	await _step(120)
	_key_down(KEY_A)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	for i: int in range(90):
		await _step(1)
		if _player.global_position.x <= 408.0:
			break
	_key_up(KEY_A)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(2)
	var edge_x: float = _player.global_position.x
	if _player.is_positive():
		await _tap_action(&"polarity")
	await _step(1)
	var launch_status: String = _game.get_anchor_room().get_status()
	var launch_force: Vector2 = _game.get_anchor_room().get_last_force()
	_check(launch_status == "ATTRACT" and launch_force.length() > 0.0, "return edge launch is ATTRACT with real force", "%s %.0f" % [launch_status, launch_force.length()])
	var resets_before: int = _player.get_reset_count()
	_key_down(KEY_A)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	Input.action_press(&"jump")
	await _step(2)
	Input.action_release(&"jump")
	var landed: bool = false
	var reset_seen: bool = false
	var frame_found: int = -1
	var minx: float = 9999.0
	var miny: float = 9999.0
	for frame: int in range(1, 181):
		if frame == switch_frame:
			Input.action_press(&"polarity")
		await _step(1)
		if frame == switch_frame:
			Input.action_release(&"polarity")
		minx = minf(minx, _player.global_position.x)
		miny = minf(miny, _player.global_position.y)
		if _player.get_reset_count() > resets_before:
			reset_seen = true
			break
		if _player.is_on_floor() and _player.global_position.x <= 177.0 and absf(_player.global_position.y - 288.0) < 2.0:
			landed = true
			frame_found = frame
			break
	_key_up(KEY_A)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(2)
	return {
		"ok": landed and not reset_seen,
		"reset": reset_seen,
		"frame": frame_found,
		"x": _player.global_position.x,
		"y": _player.global_position.y,
		"edge_x": edge_x,
		"launch_status": launch_status,
		"minx": minx,
		"miny": miny,
	}


func _land_on_right_ledge() -> bool:
	await _prepare_anchor_trial(Vector2(160.0, 288.0), true, Vector2(160.0, 0.0))
	await _start_anchor_jump_run()
	for frame: int in range(1, 101):
		if frame == 45:
			Input.action_press(&"polarity")
		await _step(1)
		if frame == 45:
			Input.action_release(&"polarity")
		if _game.get_anchor_room().is_success():
			return true
	return false


func _test_anchor_full_spawn_route() -> void:
	_section("ANCHOR ROUTE / CONTINUOUS RUN FROM SPAWN")
	await _prepare_anchor_trial(_game.get_anchor_room().get_spawn_position(), true)
	_key_down(KEY_D)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	var takeoff_x: float = -1.0
	var jumped: bool = false
	for i: int in range(70):
		if _player.global_position.x >= 158.0:
			takeoff_x = _player.global_position.x
			Input.action_press(&"jump")
			await _step(2)
			Input.action_release(&"jump")
			jumped = true
			break
		await _step(1)
	var success: bool = false
	var landing_frame: int = -1
	for frame: int in range(1, 121):
		if frame == 40:
			Input.action_press(&"polarity")
		await _step(1)
		if frame == 40:
			Input.action_release(&"polarity")
		if _game.get_anchor_room().is_success():
			success = true
			landing_frame = frame
			break
	await _stop_anchor_run()
	_check(jumped, "continuous route takes off from the start ledge", "x=%.1f" % takeoff_x)
	_check(success, "continuous run + jump + Q at frame 40 reaches the ledge", "land_frame=%d" % landing_frame)
	_check(_player.global_position.x >= 400.0, "continuous route lands on the wide ledge", "x=%.1f" % _player.global_position.x)
	_check(_game.get_anchor_room().is_success() and _hud.is_anchor_success_visible(), "continuous route shows success feedback", str(_game.get_anchor_room().is_success()))
	_log("  continuous route: takeoff_x=%.1f switch_frame=40 landing_frame=%d x=%.1f y=%.1f" % [
		takeoff_x, landing_frame, _player.global_position.x, _player.global_position.y
	])

	await _tap_process_action(&"toggle_anchor_room")
	await _step(6)
	_check(not _game.is_in_anchor_room(), "F2 exits after the successful route", str(_game.is_in_anchor_room()))
	_check(_player.global_position.is_equal_approx(_game.get_spawn_position()), "exit restores the basic-room spawn", str(_player.global_position))


func _prepare_anchor_trial(
	position: Vector2,
	negative: bool,
	initial_velocity: Vector2 = Vector2.ZERO
) -> void:
	_release_all()
	if get_tree().paused:
		get_tree().paused = false
		_hud.set_pause_visible(false)
	_player.reset_to_spawn("test", false)
	await _step(2)
	if negative and _player.is_positive():
		await _tap_action(&"polarity")
	elif not negative and not _player.is_positive():
		await _tap_action(&"polarity")
	_player.global_position = position
	_player.velocity = initial_velocity
	await _step(1)


func _start_anchor_jump_run() -> void:
	_key_down(KEY_D)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	Input.action_press(&"jump")
	await _step(1)
	Input.action_release(&"jump")
	await _step(1)


func _stop_anchor_run() -> void:
	_key_up(KEY_D)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	if Input.is_action_pressed(&"polarity"):
		Input.action_release(&"polarity")
	await _step(2)


func _action_has_physical_key(action: StringName, key: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == key:
				return true
	return false


func _reset_player() -> void:
	_release_all()
	if get_tree().paused:
		get_tree().paused = false
		_hud.set_pause_visible(false)
	_player.reset_to_spawn("test", false)
	await _step(4)


func _player_stable() -> void:
	for i: int in range(24):
		await _step(1)
		if _player.is_on_floor() and absf(_player.velocity.y) < 0.01:
			return


func _tap_action(action: StringName, hold_frames: int = 1) -> void:
	Input.action_press(action)
	await _step(hold_frames)
	Input.action_release(action)
	await _step(1)


func _send_key(
	key: Key,
	pressed: bool,
	location: KeyLocation = KEY_LOCATION_UNSPECIFIED,
	echo: bool = false
) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.echo = echo
	event.location = location
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key_down(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, true, location, false)


func _key_up(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, false, location, false)


func _tap_process_action(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _step(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame


func _release_all() -> void:
	for key: Key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		_send_key(key, false)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_RIGHT)
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity", &"reset"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _section(title: String) -> void:
	_log("")
	_log("--- %s ---" % title)


func _check(condition: bool, label: String, details: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, ("  (" + details + ")") if details != "" else ""])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, ("  (" + details + ")") if details != "" else ""])
		printerr("[FAIL] %s %s" % [label, details])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("res://tests/logs/last_run.log", FileAccess.WRITE)
	if file == null:
		printerr("Could not write tests/logs/last_run.log")
		return
	for line: String in _log_lines:
		file.store_line(line)
	file.close()


func _finish() -> void:
	_release_all()
	if get_tree().paused:
		get_tree().paused = false
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count])
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	_write_log()
	get_tree().quit(0 if _fail_count == 0 else 1)
