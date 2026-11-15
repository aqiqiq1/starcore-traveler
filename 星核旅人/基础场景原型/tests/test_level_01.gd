extends Node

## Acceptance runner for the formal first level. It drives the actual scene
## with the real InputMap at the fixed 60 Hz physics step. The main route below
## never teleports the player and never applies a test-only force; teleports are
## used only in isolated control/editor checks after a fresh scene is created.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

var _level: Level01
var _player: PrototypePlayer
var _hud: Level01HUD
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - Level 01 acceptance")
	_log("Godot %s  display=%s  physics=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
		str(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")),
	])

	await _test_editable_scene_shape()
	await _test_intro_handoff()
	await _test_real_keyboard_run_input()
	await _test_full_playthrough()
	await _test_fall_checkpoint_and_restart()
	await _test_pause_focus_and_replay()
	await _test_plain_jump_and_pit_controls()
	await _test_switch_window()
	await _test_terrain_sync_and_scene_reload()
	await _test_terrain_shape_isolation()
	_finish()


func _test_editable_scene_shape() -> void:
	_section("EDITABLE SCENE SHAPE")
	await _new_level()
	_check(_level != null and _player != null and _hud != null, "level scene instantiates")
	var background: CanvasLayer = _level.get_node("Background") as CanvasLayer
	_check(background != null and background.layer == -10, "background CanvasLayer is present")
	_check(background.get_node_or_null("FarRuins") != null and background.get_node_or_null("NearRuins") != null, "background silhouette layers are scene nodes")
	var start_ground: LevelTerrainBlock = _level.get_node("World/StartGround") as LevelTerrainBlock
	var high_platform: LevelTerrainBlock = _level.get_node("World/HighPlatform") as LevelTerrainBlock
	var far_bank: LevelTerrainBlock = _level.get_node("World/FarBank") as LevelTerrainBlock
	_check(start_ground != null and high_platform != null and far_bank != null, "three editable terrain blocks")
	_check(start_ground.get_collision_size() == start_ground.get_block_size(), "start ground collision matches block_size", str(start_ground.get_collision_size()))
	_check(high_platform.get_collision_size() == high_platform.get_block_size(), "high platform collision matches block_size", str(high_platform.get_collision_size()))
	_check(far_bank.get_collision_size() == far_bank.get_block_size(), "far bank collision matches block_size", str(far_bank.get_collision_size()))
	_check(high_platform.global_position == Vector2(864.0, 220.0), "high platform position comes from the scene node", str(high_platform.global_position))
	_check(start_ground.get_collision_top_left().is_equal_approx(start_ground.global_position), "terrain collision top-left equals node position", str(start_ground.get_collision_top_left()))
	_check(_level.get_narrative_guide() != null and _level.get_mechanism_guide() != null, "two editable guide echoes")
	_check(_level.get_rune_stones().size() == 2, "two editable rune stones", str(_level.get_rune_stones().size()))
	_check(_level.get_checkpoint() != null and _level.get_exit() != null, "checkpoint and exit are scene nodes")
	var camera: Camera2D = _level.get_camera()
	_check(camera.get_parent() == _player, "camera follows the player")
	_check(camera.limit_left == 0 and camera.limit_right == 1952 and camera.limit_bottom == 360, "camera bounds are editable scene properties", "L%d R%d T%d B%d" % [camera.limit_left, camera.limit_right, camera.limit_top, camera.limit_bottom])
	var intro_end: Marker2D = _level.get_node("World/IntroEnd") as Marker2D
	_check(intro_end != null and intro_end.position == Vector2(100.0, 300.0), "opening handoff marker is an editable Marker2D", str(intro_end.position))
	var guide: LevelGuide = _level.get_node("World/Guide") as LevelGuide
	_check(guide != null and not guide.visible, "editor guide is hidden at runtime", str(guide.visible if guide != null else "missing"))
	var stones: Array[RuneStoneField] = _level.get_rune_stones()
	_check(stones.size() == 2 and stones[0].initial_positive and stones[1].initial_positive, "both fixed rune stones start in 辉相")
	_check(stones[0].auto_hint_in_range == false and stones[1].auto_hint_in_range == false, "formal rune stones hide the prototype +/- proximity hint")
	_check(stones[0].get_visual() != null and stones[0].get_visual().is_energized(), "high-platform rune stone is lit in the editor/game")
	_check(_level.get_checkpoint().get_trigger_rect().size == Vector2(40.0, 72.0), "checkpoint trigger is editable")
	_check(_level.get_exit().get_trigger_rect().size == Vector2(36.0, 76.0), "exit trigger is editable")
	_check(_level.get_narrative_guide().pages.size() == 3, "meeting guide echo has three pages")
	_check(_level.get_mechanism_guide().pages.size() == 3, "high-step guide echo has three pages")
	_check_level_font_coverage()
	_check(not _player.show_head_polarity, "formal level hides the head polarity glyph")
	var badge: Node2D = _player.get_node("PolarityBadge") as Node2D
	_check(badge != null and not badge.visible, "head badge is actually hidden in the scene")
	var sprite: Sprite2D = _player.get_node("VisualRoot/CharacterSprite") as Sprite2D
	var talisman: Sprite2D = _player.get_node("VisualRoot/Talisman") as Sprite2D
	_check(sprite.texture != null and sprite.hframes == 10, "player scene has a visible idle preview frame")
	_check(talisman.texture != null, "player scene has a visible talisman preview")
	_check(_hud is Level01HUD, "formal HUD is Level01HUD")
	var hud_script: Script = _level.get_node("HUD").get_script() as Script
	_check(hud_script != null and hud_script.resource_path.ends_with("level_hud.gd"), "formal HUD uses the level HUD script, not PrototypeHUD", str(hud_script.resource_path if hud_script != null else ""))
	_check(_hud.get_polarity_text() == "辉相", "HUD starts on 辉相", _hud.get_polarity_text())
	_check(_hud.get_controls_text().contains("Q 切换") and _hud.get_controls_text().contains("空格 跳跃"), "HUD uses Chinese controls", _hud.get_controls_text())


func _test_intro_handoff() -> void:
	_section("OPENING AUTO-RUN / HANDOFF")
	await _new_level()
	var start: Vector2 = _level.get_start_position()
	_check(_level.is_intro_active(), "opening auto-run starts active")
	_check(start.x < 0.0, "spawn is off-screen left of the camera", str(start))
	await _physics(20)
	_check(_player.global_position.x > start.x + 20.0, "opening auto-run moves the player right", "x=%.1f" % _player.global_position.x)
	_check(_player.is_input_override_active(), "opening override is active")
	# Real input must not fight the opening run. The auto-run is slower than the
	# normal 160 run now, so compare against the position at key-down instead of
	# the old fixed x > 0 threshold that assumed the previous pace.
	var before_held_left: float = _player.global_position.x
	Input.action_press(&"move_left")
	await _physics(8)
	Input.action_release(&"move_left")
	_check(
		_player.global_position.x > before_held_left + 6.0,
		"held left input does not cancel the short opening",
		"x=%.1f -> %.1f" % [before_held_left, _player.global_position.x]
	)
	for i: int in range(240):
		await get_tree().process_frame
		if not _level.is_intro_active():
			break
	_check(not _level.is_intro_active(), "opening ends within its maximum duration")
	_check(not _player.is_input_override_active(), "control is returned after the opening")
	_check(_player.global_position.x >= _level.get_intro_end_position().x - 6.0, "opening reaches the editable handoff marker", "x=%.1f marker=%.1f" % [_player.global_position.x, _level.get_intro_end_position().x])
	await _physics(12)
	_check(_player.is_on_floor(), "player is standing after handoff", str(_player.global_position))
	_check(
		not _hud.is_toast_visible() and not _hud.get_toast_text().contains("交还"),
		"opening handoff shows no control-return notice",
		"visible=%s text=%s" % [str(_hud.is_toast_visible()), _hud.get_toast_text()]
	)
	var handoff_x: float = _player.global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	_check(
		_player.global_position.x > handoff_x + 2.0 and _player.get_target_speed() > 0.0,
		"control works after the opening handoff",
		"x=%.1f target=%.1f" % [_player.global_position.x, _player.get_target_speed()]
	)
	Input.action_release(&"move_right")
	await _physics(4)


func _test_real_keyboard_run_input() -> void:
	_section("REAL KEYBOARD ROUTE - SHIFT / DOUBLE TAP / CLEANUP")
	# Every event below goes through Input.parse_input_event(), so it is routed
	# by the engine to Level01._input and then to the player. The test never
	# calls player.handle_key_event() directly.

	# Left Shift must sprint; a real run should reach 160 px/s.
	await _new_level()
	await _wait_intro_done()
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	_send_key(KEY_D, true)
	await _physics(20)
	_log("  left Shift: held=%s sprint=%s target=%.1f vx=%.1f axis=%.2f" % [
		str(_player.is_left_shift_held()), str(_player.is_sprint_intent()),
		_player.get_target_speed(), _player.velocity.x, _player.get_move_input_axis(),
	])
	_check(_player.is_left_shift_held(), "real left Shift key-down reaches the player")
	_check(_player.is_sprint_intent(), "left Shift sets sprint intent")
	_check(absf(_player.get_target_speed() - _player.get_run_speed()) < 0.5, "left Shift target is run speed 160", "%.1f" % _player.get_target_speed())
	_check(absf(_player.velocity.x - _player.get_run_speed()) <= 2.0, "left Shift actually runs at 160", "%.1f" % _player.velocity.x)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	await _physics(2)
	_check(not _player.is_left_shift_held() and not _player.is_sprint_intent(), "left Shift key-up drops sprint")
	await _physics(10)
	_check(absf(_player.velocity.x - _player.get_walk_speed()) <= 2.0, "same held direction settles back to walk 100", "%.1f" % _player.velocity.x)
	_send_key(KEY_D, false)
	await _physics(2)

	# Right Shift is a separate physical key and must not sprint.
	await _new_level()
	await _wait_intro_done()
	_send_key(KEY_SHIFT, true, KEY_LOCATION_RIGHT)
	_send_key(KEY_D, true)
	await _physics(20)
	_log("  right Shift: held=%s sprint=%s target=%.1f vx=%.1f" % [
		str(_player.is_left_shift_held()), str(_player.is_sprint_intent()),
		_player.get_target_speed(), _player.velocity.x,
	])
	_check(not _player.is_left_shift_held(), "right Shift does not set the left-Shift latch")
	_check(not _player.is_sprint_intent(), "right Shift does not set sprint intent")
	_check(absf(_player.get_target_speed() - _player.get_walk_speed()) < 0.5, "right Shift target is walk speed 100", "%.1f" % _player.get_target_speed())
	_check(absf(_player.velocity.x - _player.get_walk_speed()) <= 2.0, "right Shift actually walks at 100", "%.1f" % _player.velocity.x)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_RIGHT)
	_send_key(KEY_D, false)
	await _physics(2)

	# Two real direction presses within the window lock a run.
	await _new_level()
	await _wait_intro_done()
	_send_key(KEY_D, true)
	await _physics(1)
	_send_key(KEY_D, false)
	await _physics(2)
	_send_key(KEY_D, true)
	await _physics(2)
	_log("  double tap: locked=%s sprint=%s target=%.1f vx=%.1f" % [
		str(_player.is_double_tap_run_locked()), str(_player.is_sprint_intent()),
		_player.get_target_speed(), _player.velocity.x,
	])
	_check(_player.is_double_tap_run_locked(), "real double-tap direction locks a run")
	_check(_player.is_sprint_intent(), "double-tap sets sprint intent")
	_check(absf(_player.get_target_speed() - _player.get_run_speed()) < 0.5, "double-tap target is run speed 160", "%.1f" % _player.get_target_speed())
	await _physics(18)
	_check(absf(_player.velocity.x - _player.get_run_speed()) <= 2.0, "double-tap actually runs at 160", "%.1f" % _player.velocity.x)
	_send_key(KEY_D, false)
	await _physics(2)
	_check(not _player.is_double_tap_run_locked(), "direction release clears the double-tap run latch")
	await _physics(12)
	_check(absf(_player.velocity.x) <= 2.0, "double-tap cleanup stops the player", "%.1f" % _player.velocity.x)

	# Real presses during the opening must not pollute the scripted override,
	# and must not be retained when control is handed over.
	await _new_level()
	_check(_level.is_intro_active(), "opening is active before the keyboard pollution check")
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	_send_key(KEY_D, true)
	await _physics(1)
	_send_key(KEY_D, false)
	await _physics(2)
	_send_key(KEY_D, true)
	await _physics(2)
	_check(not _player.is_left_shift_held(), "opening ignores real Shift key-down")
	_check(not _player.is_double_tap_run_locked(), "opening ignores real double-tap")
	_check(_player.is_input_override_active(), "opening override stays in control")
	await _wait_intro_done()
	_check(not _player.is_left_shift_held(), "opening-period Shift is not retained after handoff")
	_check(not _player.is_double_tap_run_locked(), "opening-period double-tap is not retained after handoff")
	await _physics(20)
	_log("  after opening (keys came from intro): target=%.1f vx=%.1f" % [_player.get_target_speed(), _player.velocity.x])
	_check(absf(_player.get_target_speed() - _player.get_walk_speed()) < 0.5, "direction held from the opening walks after handoff")
	_check(absf(_player.velocity.x - _player.get_walk_speed()) <= 2.0, "no opening-period run latch survives the handoff", "%.1f" % _player.velocity.x)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	_send_key(KEY_D, false)
	await _physics(2)

	# Pause must clear both latches, even though the physical keys stay down.
	await _new_level()
	await _wait_intro_done()
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	_send_key(KEY_D, true)
	await _physics(1)
	_send_key(KEY_D, false)
	await _physics(2)
	_send_key(KEY_D, true)
	await _physics(14)
	_check(_player.is_left_shift_held() and _player.is_double_tap_run_locked(), "Shift and double-tap are latched before pausing")
	await _tap_key(KEY_ESCAPE)
	_check(_level.is_paused(), "Esc pauses through the real key route")
	_check(not _player.is_left_shift_held() and not _player.is_double_tap_run_locked(), "pause clears Shift and double-tap latches")
	var paused_position: Vector2 = _player.global_position
	await _physics(8)
	_check(_player.global_position.is_equal_approx(paused_position), "paused player stays put with keys held", str(_player.global_position))
	await _tap_key(KEY_ESCAPE)
	await _physics(16)
	_log("  after pause resume: target=%.1f vx=%.1f" % [_player.get_target_speed(), _player.velocity.x])
	_check(absf(_player.get_target_speed() - _player.get_walk_speed()) < 0.5 and absf(_player.velocity.x - _player.get_walk_speed()) <= 2.0, "Shift held across a pause no longer runs after resume")
	_send_key(KEY_D, false)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	await _physics(20)

	# R must clear both latches and restart the opening.
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	_send_key(KEY_D, true)
	await _physics(1)
	_send_key(KEY_D, false)
	await _physics(2)
	_send_key(KEY_D, true)
	await _physics(4)
	_check(_player.is_left_shift_held() and _player.is_double_tap_run_locked(), "Shift and double-tap are latched before R")
	await _tap_key(KEY_R)
	await _physics(4)
	_check(_level.is_intro_active(), "R restarts the opening through the real key route")
	_check(not _player.is_left_shift_held() and not _player.is_double_tap_run_locked(), "R clears Shift and double-tap latches")
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	_send_key(KEY_D, false)
	await _physics(2)

	# Focus loss must clear both latches too.
	await _new_level()
	await _wait_intro_done()
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	_send_key(KEY_D, true)
	await _physics(1)
	_send_key(KEY_D, false)
	await _physics(2)
	_send_key(KEY_D, true)
	await _physics(8)
	_check(_player.is_left_shift_held() and _player.is_double_tap_run_locked(), "Shift and double-tap are latched before focus loss")
	get_window().focus_exited.emit()
	await _physics(2)
	_check(not _player.is_left_shift_held() and not _player.is_double_tap_run_locked(), "focus loss clears Shift and double-tap latches")
	await _physics(20)
	_log("  after focus loss (keys still down): target=%.1f vx=%.1f" % [_player.get_target_speed(), _player.velocity.x])
	_check(absf(_player.get_target_speed() - _player.get_walk_speed()) < 0.5 and absf(_player.velocity.x - _player.get_walk_speed()) <= 2.0, "focus loss leaves no retained run")
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	_send_key(KEY_D, false)
	await _physics(2)

	# Completion keeps its local override; real keys must not latch behind it.
	_level.get_exit().player_reached_exit.emit()
	await _physics(3)
	_check(_level.is_completed() and _player.is_input_override_active(), "completion freeze is active before the keyboard check")
	var completed_position: Vector2 = _player.global_position
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	_send_key(KEY_D, true)
	await _physics(4)
	_check(not _player.is_left_shift_held(), "completed level ignores real Shift key-down")
	_check(_player.global_position.is_equal_approx(completed_position), "completed level ignores real movement keys")
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	_send_key(KEY_D, false)
	await _physics(2)


func _test_full_playthrough() -> void:
	_section("FULL ROUTE - REAL INPUT, NO TELEPORT")
	await _new_level()
	await _wait_intro_done()

	# Meeting guide echo: approach only shows the prompt; real F opens page 1.
	await _move_until_x(245.0, 500)
	await _physics(6)
	var narrative: GuideEcho = _level.get_narrative_guide()
	_check(narrative.is_in_range(), "meeting guide echo is in range on approach", str(_player.global_position))
	_check(narrative.is_prompt_visible() and narrative.get_page_index() == -1, "meeting guide only shows the F prompt on approach")
	await _press_f()
	_check(narrative.get_page_index() == 0, "meeting F opens page 1")
	await _press_f()
	_check(narrative.get_page_index() == 1, "meeting F advances to page 2")
	await _press_f()
	_check(narrative.get_page_index() == 2, "meeting F advances to page 3")
	await _press_f()
	_check(narrative.get_page_index() == -1, "meeting F closes the last page")

	# High-step guide echo: same three-page F interaction, same in-range prompt.
	await _move_until_x(725.0, 600)
	await _physics(6)
	var mechanism: GuideEcho = _level.get_mechanism_guide()
	_check(mechanism.is_in_range(), "high-step guide echo is in range before the field")
	_check(mechanism.is_prompt_visible() and mechanism.get_page_index() == -1, "high-step guide only shows the F prompt on approach")
	var prompt_rect: Rect2 = mechanism.get_prompt_rect()
	_check(prompt_rect.position.y >= 49.5 and prompt_rect.end.x <= 636.5 and prompt_rect.end.y <= 356.0, "scrolled guide prompt stays inside the screen", str(prompt_rect))
	await _press_f()
	_check(mechanism.get_page_index() == 0, "high-step F opens page 1")
	await _press_f()
	_check(mechanism.get_page_index() == 1, "high-step F advances to page 2")
	await _press_f()
	_check(mechanism.get_page_index() == 2, "high-step F advances to page 3")
	await _press_f()
	_check(mechanism.get_page_index() == -1, "high-step F closes the last page")

	# High platform: normal jump is impossible; attraction lifts, then switching
	# to the same phase repels right off the platform.
	Input.action_press(&"move_right")
	await _physics(80)
	await _tap_action(&"polarity")
	_check(not _player.is_positive(), "Q selects 澜相 for the attraction")
	_check(_hud.get_polarity_text() == "澜相", "HUD shows 澜相", _hud.get_polarity_text())
	await _physics(8)
	var high_stone: RuneStoneField = _level.get_rune_stones()[0]
	var to_high_stone: Vector2 = high_stone.global_position - (_player.global_position + Vector2(0.0, -15.0))
	var attract_force: Vector2 = _level.get_last_force()
	_check(attract_force.dot(to_high_stone) > 0.0 and attract_force.y < 0.0, "异相吸引 force points toward the high stone and lifts", str(attract_force))
	var landed: bool = false
	for i: int in range(280):
		await get_tree().physics_frame
		if _player.is_on_floor() and _player.global_position.y <= 222.0 and _player.global_position.x >= 864.0:
			landed = true
			break
	_check(landed, "异相吸引 carries the player onto the high platform", str(_player.global_position))
	await _tap_action(&"polarity")
	_check(_player.is_positive(), "Q returns to 辉相 for the rightward repel")
	await _physics(3)
	var repel_force: Vector2 = _level.get_last_force()
	_check(repel_force.x > 50.0, "同相排斥 pushes the player right off the high platform", str(repel_force))
	# Let the same-phase repel carry the player to the checkpoint.
	for i: int in range(240):
		await get_tree().physics_frame
		if _level.get_checkpoint().is_activated() or _player.global_position.x >= 1125.0:
			break
	_check(_level.get_checkpoint().is_activated(), "checkpoint activates on the platform", str(_player.global_position))
	_check(_player.global_position.y < 230.0, "checkpoint run stays on the platform", str(_player.global_position))
	# Stop before the pit edge.
	for i: int in range(160):
		await get_tree().physics_frame
		if _player.global_position.x >= 1172.0:
			break
	Input.action_release(&"move_right")
	await _physics(12)
	_check(_player.global_position.y < 230.0, "player waits safely before the pit", str(_player.global_position))

	# Pit: attraction first, then same-phase repulsion to the far bank.
	await _tap_action(&"polarity")
	_check(not _player.is_positive(), "pit attempt starts on 澜相")
	Input.action_press(&"move_right")
	await _tap_action(&"jump")
	var switched: bool = false
	var pit_repel_right: bool = false
	for i: int in range(220):
		await get_tree().physics_frame
		if not switched and _player.global_position.x >= 1405.0 and _player.global_position.y <= 262.0 and _player.velocity.x > 0.0:
			await _tap_action(&"polarity")
			switched = true
			await _physics(2)
			pit_repel_right = _level.get_last_force().x > 50.0
			continue
		if _player.is_on_floor() and _player.global_position.x >= 1500.0:
			break
		if _player.global_position.y > 420.0:
			break
	_check(switched, "pit route switches phase while airborne", "x=%.1f y=%.1f" % [_player.global_position.x, _player.global_position.y])
	_check(pit_repel_right, "同相排斥 points across the pit, not back to the platform")
	Input.action_release(&"move_right")
	await _physics(16)
	_check(_player.global_position.x >= 1500.0 and _player.global_position.y < 310.0, "attract->repel crosses the wide pit", str(_player.global_position))
	_check(_player.is_on_floor(), "player is safely on the far bank", str(_player.global_position))

	# Exit.
	Input.action_press(&"move_right")
	for i: int in range(420):
		await get_tree().physics_frame
		if _level.is_completed():
			break
	Input.action_release(&"move_right")
	await _physics(4)
	_check(_level.is_completed(), "reaching the exit completes level 01", str(_player.global_position))
	_check(_level.get_completion_count() == 1, "exit completes exactly once", str(_level.get_completion_count()))
	_check(_hud.is_completion_visible(), "completion panel is visible")
	_check(_hud.is_completion_visible() and _hud.get_completion_text().contains("第一关完成"), "completion panel says 第一关完成", _hud.get_completion_text())
	_check(_player.is_input_override_active(), "movement is frozen at completion")
	_check(_level.get_exit().is_completed() and not _level.get_exit().monitoring, "completed exit disables its trigger")
	# Calling the completion entry again must not add a second settlement.
	_level._on_exit_reached()
	await _physics(2)
	_check(_level.get_completion_count() == 1, "completion remains once after a repeated entry", str(_level.get_completion_count()))
	# Real replay entry after a real exit.
	await _tap_action(&"reset")
	await _physics(4)
	_log("  after real-exit R: completed=%s intro=%s pos=%s polarity=%s count=%d" % [
		str(_level.is_completed()), str(_level.is_intro_active()), str(_player.global_position),
		str(_player.is_positive()), _level.get_completion_count()
	])
	_check(not _level.is_completed() and not _hud.is_completion_visible(), "R after the real exit clears completion", str(_level.is_completed()))
	_check(_level.is_intro_active() and _player.is_positive(), "R after the real exit restores the opening and 辉相")
	await _wait_intro_done()
	_check(
		not _hud.get_toast_text().contains("交还"),
		"R after the real exit handoff shows no control-return notice",
		"visible=%s text=%s" % [str(_hud.is_toast_visible()), _hud.get_toast_text()]
	)


func _test_fall_checkpoint_and_restart() -> void:
	_section("FALL / CHECKPOINT / R RESTART")
	await _new_level()
	await _wait_intro_done()
	# Setup teleports are allowed here: this is a failure-state check, not the
	# main route. Walk is covered independently.
	_player.global_position = Vector2(1120.0, 220.0)
	_player.velocity = Vector2.ZERO
	await _physics(8)
	_check(_level.get_checkpoint().is_activated(), "checkpoint activates when touched")
	var checkpoint_pos: Vector2 = _level.get_checkpoint_position()
	_player.global_position = Vector2(1250.0, 380.0)
	_player.velocity = Vector2.ZERO
	for i: int in range(180):
		await get_tree().physics_frame
		if _player.global_position.distance_to(checkpoint_pos) < 4.0 and _player.is_on_floor():
			break
	_check(_player.global_position.distance_to(checkpoint_pos) < 4.0, "fall returns to the nearest checkpoint", "pos=%s checkpoint=%s" % [_player.global_position, checkpoint_pos])
	_check(_player.is_positive(), "fall recovery restores 辉相", str(_player.is_positive()))
	_check(_hud.get_toast_text().contains("恢复点") or _hud.get_toast_text().contains("云海"), "fall shows recovery feedback", _hud.get_toast_text())

	# Open a guide page, then let R clear it; the reset must not leave a stale page.
	_player.global_position = Vector2(250.0, 300.0)
	_player.velocity = Vector2.ZERO
	await _physics(6)
	var reset_guide: GuideEcho = _level.get_narrative_guide()
	await _press_f()
	_check(reset_guide.get_page_index() == 0, "guide page is open before R")
	await _tap_action(&"reset")
	await _physics(4)
	_check(reset_guide.get_page_index() == -1 and reset_guide.is_suspended(), "R clears the guide page")
	_check(_level.is_intro_active(), "R restarts the level opening")
	_check(not _level.is_completed(), "R clears completion state")
	_check(_player.is_positive(), "R restores 辉相", str(_player.is_positive()))
	_check(_player.global_position.distance_to(_level.get_start_position()) < 8.0, "R returns to the opening spawn", str(_player.global_position))
	_check(_hud.get_toast_text().contains("本关已重新开始"), "R keeps its restart notice", _hud.get_toast_text())
	await _wait_intro_done()
	_check(not _level.get_checkpoint().is_activated(), "R clears the checkpoint for the new run")
	_check(
		not _hud.get_toast_text().contains("交还"),
		"R restart handoff shows no control-return notice",
		"visible=%s text=%s" % [str(_hud.is_toast_visible()), _hud.get_toast_text()]
	)
	var restart_x: float = _player.global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	_check(
		_player.global_position.x > restart_x + 2.0 and _player.get_target_speed() > 0.0,
		"control works after the R restart handoff",
		"x=%.1f target=%.1f" % [_player.global_position.x, _player.get_target_speed()]
	)
	Input.action_release(&"move_right")
	await _physics(4)


func _test_pause_focus_and_replay() -> void:
	_section("PAUSE / FOCUS / REPLAY")
	# Pause during the opening must hand control back, not resume a hidden run.
	await _new_level()
	_check(_level.is_intro_active(), "opening is active before the pause check")
	await _tap_action(&"pause")
	_check(_level.is_paused() and _hud.is_pause_visible(), "Esc pauses during the opening")
	_check(not _level.is_intro_active() and not _player.is_input_override_active(), "pause during opening clears the scripted axis")
	await _tap_action(&"pause")
	await _physics(18)
	var intro_pause_x: float = _player.global_position.x
	await _physics(20)
	_check(absf(_player.global_position.x - intro_pause_x) < 2.0, "resuming after an opening pause does not auto-run", "x=%.1f" % _player.global_position.x)

	await _new_level()
	await _wait_intro_done()
	await _physics(26)
	await _tap_action(&"pause")
	_check(_level.is_paused() and _hud.is_pause_visible(), "Esc pauses level 01")
	_check(not _player.is_input_override_active(), "pause clears any movement override")
	var paused_position: Vector2 = _player.global_position
	Input.action_press(&"move_right")
	await _physics(20)
	Input.action_release(&"move_right")
	_check(_player.global_position.is_equal_approx(paused_position), "physics freezes while paused", str(_player.global_position))
	await _tap_action(&"pause")
	_check(not _level.is_paused() and not _hud.is_pause_visible(), "Esc resumes level 01")
	# Focus loss during a fresh opening must hand control back, not auto-run.
	await _tap_action(&"reset")
	await _physics(6)
	_check(_level.is_intro_active(), "R before focus check restarts the opening")
	get_window().focus_exited.emit()
	await _physics(3)
	_check(not _level.is_intro_active() and not _player.is_input_override_active(), "focus loss cancels the opening override")
	await _physics(12)
	var focus_x: float = _player.global_position.x
	await _physics(20)
	_check(absf(_player.global_position.x - focus_x) < 2.0, "focus loss does not leave an invisible auto-run", "x=%.1f" % _player.global_position.x)
	# Completion + replay.
	_level.get_exit().player_reached_exit.emit()
	await _physics(3)
	_check(_level.is_completed() and _hud.is_completion_visible(), "exit completes and shows replay panel")
	get_window().focus_exited.emit()
	await _physics(4)
	_check(_player.is_input_override_active(), "completion freeze survives window focus loss")
	var before_replay: int = _level.get_completion_count()
	await _tap_action(&"reset")
	await _physics(4)
	_check(not _level.is_completed() and not _hud.is_completion_visible(), "R clears completion and hides replay panel")
	_check(_level.is_intro_active(), "R starts the opening again")
	_check(_level.get_completion_count() == before_replay, "completion count is not duplicated by restart")
	await _wait_intro_done()


func _test_plain_jump_and_pit_controls() -> void:
	_section("PLAIN JUMP / PIT MODE CONTROLS")
	# Plain gold jump against the high wall must fail.
	await _new_level()
	await _wait_intro_done()
	await _place_player(Vector2(815.0, 300.0), true)
	Input.action_press(&"move_right")
	await _tap_action(&"jump")
	for i: int in range(150):
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	await _physics(10)
	_check(_player.global_position.y > 250.0, "plain jump cannot climb the high platform", str(_player.global_position))
	_check(_player.global_position.x < 864.0, "plain jump stays left of the high wall", str(_player.global_position))

	# Gold-only pit attempt must fail.
	await _new_level()
	await _wait_intro_done()
	await _place_player(Vector2(1180.0, 220.0), true)
	Input.action_press(&"move_right")
	await _tap_action(&"jump")
	for i: int in range(200):
		await get_tree().physics_frame
		if _player.global_position.y > 420.0:
			break
	Input.action_release(&"move_right")
	await _physics(10)
	_check(not (_player.global_position.x >= 1500.0 and _player.is_on_floor()), "same phase alone cannot cross the pit", str(_player.global_position))

	# Cyan-only pit attempt orbits the stone and must also fail.
	await _new_level()
	await _wait_intro_done()
	await _place_player(Vector2(1180.0, 220.0), false)
	Input.action_press(&"move_right")
	await _tap_action(&"jump")
	for i: int in range(200):
		await get_tree().physics_frame
		if _player.global_position.y > 420.0:
			break
	Input.action_release(&"move_right")
	await _physics(10)
	_check(not (_player.global_position.x >= 1500.0 and _player.is_on_floor()), "attraction alone does not cross the pit", str(_player.global_position))


func _test_switch_window() -> void:
	_section("SWITCH WINDOW (NOT SINGLE-FRAME)")
	# A switch that is clearly too early fails, while two deliberately different
	# timings both land. This shows a real timing window rather than a one-frame
	# trick.
	var early: bool = await _attempt_pit_switch(50)
	_check(not early, "switching too early does not cross the pit")
	var successes: int = 0
	for switch_frame: int in [60, 70]:
		if await _attempt_pit_switch(switch_frame):
			successes += 1
	_check(successes == 2, "two different switch timings both cross the pit", "%d/2" % successes)


func _attempt_pit_switch(switch_frame: int) -> bool:
	await _new_level()
	await _wait_intro_done()
	await _place_player(Vector2(1180.0, 220.0), false)
	Input.action_press(&"move_right")
	await _tap_action(&"jump")
	for i: int in range(switch_frame):
		await get_tree().physics_frame
	await _tap_action(&"polarity")
	var crossed: bool = false
	for i: int in range(200):
		await get_tree().physics_frame
		if _player.is_on_floor() and _player.global_position.x >= 1500.0:
			crossed = true
			break
		if _player.global_position.y > 420.0:
			break
	Input.action_release(&"move_right")
	await _physics(4)
	return crossed


func _test_terrain_sync_and_scene_reload() -> void:
	_section("TERRAIN EDIT / SCENE RELOAD")
	await _new_level()
	await _wait_intro_done()
	var high: LevelTerrainBlock = _level.get_node("World/HighPlatform") as LevelTerrainBlock
	var old_top_left: Vector2 = high.get_collision_top_left()
	var old_size: Vector2 = high.get_collision_size()
	high.block_size = Vector2(352.0, 160.0)
	high.global_position += Vector2(16.0, 8.0)
	await _physics(2)
	_check(high.get_collision_size() == Vector2(352.0, 160.0), "changing block_size updates the collision size", str(high.get_collision_size()))
	_check(high.get_collision_top_left().is_equal_approx(high.global_position), "moving the block moves art and collision together", str(high.get_collision_top_left()))
	_check(high.get_collision_top_left() != old_top_left and high.get_collision_size() != old_size, "terrain edit actually changed both geometry values")

	var old_guide: GuideEcho = _level.get_narrative_guide()
	_player.global_position = Vector2(250.0, 300.0)
	_player.velocity = Vector2.ZERO
	await _physics(6)
	_check(old_guide.is_in_range(), "first scene owns its meeting guide echo")
	await _press_f()
	_check(old_guide.get_page_index() == 0, "first scene guide opens page 1 with real F")
	get_window().focus_exited.emit()
	await _physics(3)
	_check(old_guide.get_page_index() == -1 and old_guide.is_suspended(), "focus loss clears/suspends the guide page")
	_level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_level = null
	_player = null
	await _new_level()
	await _wait_intro_done()
	_check(get_tree().get_nodes_in_group("guide_echo").size() == 2, "reloaded level owns exactly two guide echoes", str(get_tree().get_nodes_in_group("guide_echo").size()))
	var reloaded: GuideEcho = _level.get_narrative_guide()
	_check(reloaded != old_guide, "reloaded scene has fresh guide nodes")
	_player.global_position = Vector2(250.0, 300.0)
	_player.velocity = Vector2.ZERO
	await _physics(6)
	_check(reloaded.is_in_range() and reloaded.is_prompt_visible(), "reloaded guide prompt works without a stale page", str(reloaded.get_page_index()))
	_check(reloaded.get_page_index() == -1, "reloaded guide starts closed")


func _test_terrain_shape_isolation() -> void:
	_section("TERRAIN SHAPE ISOLATION")
	# Reproduce the editor hazard directly: two blocks share one shape resource,
	# as duplicated editor instances can. Editing one block_size must not resize
	# the sibling's collision.
	var host: Node2D = Node2D.new()
	host.position = Vector2(5000.0, 5000.0)
	add_child(host)
	var shared: RectangleShape2D = RectangleShape2D.new()
	shared.size = Vector2(256.0, 64.0)
	var first: LevelTerrainBlock = LevelTerrainBlock.new()
	var second: LevelTerrainBlock = LevelTerrainBlock.new()
	first.name = "FirstBlock"
	second.name = "SecondBlock"
	for block: LevelTerrainBlock in [first, second]:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		shape_node.position = Vector2(128.0, 32.0)
		shape_node.shape = shared
		block.add_child(shape_node)
		host.add_child(block)
	await _physics(3)
	_check(first.get_collision_size() == Vector2(256.0, 64.0) and second.get_collision_size() == Vector2(256.0, 64.0), "two blocks start on one shared RectangleShape2D", "%s / %s" % [first.get_collision_size(), second.get_collision_size()])
	first.block_size = Vector2(352.0, 96.0)
	await _physics(2)
	_check(first.get_collision_size() == Vector2(352.0, 96.0), "edited block gets its new collision size", str(first.get_collision_size()))
	_check(second.get_collision_size() == Vector2(256.0, 64.0), "sibling block keeps its own collision size", str(second.get_collision_size()))
	_check(shared.size == Vector2(256.0, 64.0), "the original shared shape resource is not mutated", str(shared.size))
	var first_shape: RectangleShape2D = (first.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var second_shape: RectangleShape2D = (second.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	_check(first_shape != second_shape, "each block owns a separate shape resource")
	host.queue_free()
	await get_tree().process_frame


func _check_level_font_coverage() -> void:
	var font: FontFile = load("res://assets/fonts/tutorial_zh.ttf") as FontFile
	_check(font != null, "tutorial Chinese font is available")
	if font == null:
		return
	var sample: String = "断桥庭院第一关护符相性辉相澜相Q切换恢复点已激活跌入云海回到最近本关重新开始出口第一关完成·你抵达了按R再次可重玩已暂停继续重来本关结算"
	sample += _hud.get_controls_text()
	sample += "断桥庭院 · 你抵达了出口"
	sample += "本关结算 · 再次按 R 可重玩"
	var guides: Array[GuideEcho] = [_level.get_narrative_guide(), _level.get_mechanism_guide()]
	for guide: GuideEcho in guides:
		for page: String in guide.pages:
			sample += page
	var missing: String = ""
	var seen: Dictionary = {}
	for index: int in range(sample.length()):
		var character: String = sample.substr(index, 1)
		if character == "\n" or character == " " or character == "\t":
			continue
		if seen.has(character):
			continue
		seen[character] = true
		if not font.has_char(character.unicode_at(0)):
			missing += character
	_check(missing.is_empty(), "level HUD and guide text have full font coverage", "missing=%s" % missing)


# --- Harness helpers -------------------------------------------------------

func _new_level() -> void:
	_release_inputs()
	get_tree().paused = false
	if is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _physics(6)
	_player = _level.get_player()
	_hud = _level.get_hud()


func _wait_intro_done() -> void:
	for i: int in range(300):
		await get_tree().process_frame
		if not _level.is_intro_active():
			break
	await _physics(6)


func _move_until_x(target_x: float, max_frames: int) -> void:
	Input.action_press(&"move_right")
	for i: int in range(max_frames):
		await get_tree().physics_frame
		if _player.global_position.x >= target_x:
			break
	Input.action_release(&"move_right")
	await _physics(8)


func _place_player(pos: Vector2, positive: bool) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_player.set_spawn_point(pos)
	_player.reset_to_spawn("test_setup", false)
	if not positive:
		await _tap_action(&"polarity")
	await _physics(4)


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _press_f() -> void:
	_send_key(KEY_F, true)
	await get_tree().process_frame
	_send_key(KEY_F, false)
	await get_tree().process_frame


func _send_key(key: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.location = location
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap_key(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, true, location)
	await get_tree().process_frame
	_send_key(key, false, location)
	await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause"]:
		Input.action_release(action)


func _section(title: String) -> void:
	_log("")
	_log("-- %s --" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s  (%s)" % [label, detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s  (%s)" % [label, detail])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count])
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open("res://tests/logs/level_01_test.log", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log_lines) + "\n")
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
