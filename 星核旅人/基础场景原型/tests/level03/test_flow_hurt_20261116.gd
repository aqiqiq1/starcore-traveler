extends Node

## Critical A/B checks for 2026-11-16:
##   A. level-02 completion page -> real level 03 scene, plus the unchanged
##      replay/return commands on the same page;
##   B. level-03 player hurt: real guard strikes only, red body flash, visible
##      knockback away from the guard, 0.6 s protection, two-hit retry that
##      first shows the existing 0.15 s reaction, and pause/R cleanup.
##
## The two-hit retry and the protection boundary are also exercised through the
## guard's own resolution/protection code, never by modulating the sprite.
##
## Run (headless is enough for the functional checks):
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/level03/test_flow_hurt_20261116.tscn

const LEVEL02_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LEVEL03_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const TEMP_AUDIO: String = "user://test_flow_hurt_audio.cfg"
const TEMP_DISPLAY: String = "user://test_flow_hurt_display.cfg"

var _pass: int = 0
var _fail: int = 0
var _level: Node = null
var _struck_total: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_remove_temp(TEMP_AUDIO)
	_remove_temp(TEMP_DISPLAY)
	print("Star Core Traveler - flow / hurt critical checks (2026-11-16)")
	print("Godot %s" % Engine.get_version_info()["string"])

	await _section_l2_buttons()
	await _section_l2_to_l3_mouse()
	await _section_l2_to_l3_enter()
	await _section_l2_to_l3_space_carry()
	await _section_hurt_normal()
	await _section_hurt_right_and_air()
	await _section_hurt_ring_behind()
	await _section_two_hit_retry()
	await _section_pause_resume()
	await _section_pause_r_return()
	await _section_locks()

	await _clear_all()
	# Let any released audio playback finish before the process exits.
	await _physics(4)
	_remove_temp(TEMP_AUDIO)
	_remove_temp(TEMP_DISPLAY)
	print("")
	print("TEST_SUMMARY pass=%d fail=%d" % [_pass, _fail])
	print("RESULT: %s" % ("PASS" if _fail == 0 else "FAIL"))
	get_tree().quit(0 if _fail == 0 else 1)


# --- A. level-02 completion page commands ----------------------------------

func _section_l2_buttons() -> void:
	_print_section("A1 L2 completion page: 进入第三关 + 重玩本关 + 返回主界面")
	await _new_l2()
	_check(await _setup_l2_completion(), "L2 completion setup shows the result page")
	var hud: Level02HUD = _level.get_hud()
	var primary: PixelMenuButton = hud.get_completion_primary_button()
	var replay: PixelMenuButton = hud.get_completion_replay_button()
	var back: PixelMenuButton = hud.get_completion_return_button()
	_check(primary != null and primary.text == "进入第三关",
		"primary button is 进入第三关", primary.text if primary != null else "<none>")
	_check(replay != null and replay.text == "重玩本关", "secondary replay is 重玩本关")
	_check(back != null and back.text == "返回主界面", "secondary return is 返回主界面")
	_check(primary != replay and primary != back and replay != back,
		"the three commands are three real buttons")
	_check(primary.variant == PixelMenuButton.Variant.STONE,
		"primary keeps the approved STONE variant")
	_check(replay.variant == PixelMenuButton.Variant.OPTION
		and back.variant == PixelMenuButton.Variant.OPTION,
		"the two secondary commands keep the approved OPTION variant")
	_check(primary.position == Vector2(110.0, 86.0) and primary.size == Vector2(180.0, 28.0),
		"primary keeps the level-01 approved rect", str(primary.get_rect()))
	_check(replay.position == Vector2(32.0, 126.0) and back.position == Vector2(208.0, 126.0),
		"replay/return sit side by side like level 01")
	_check(_focus_owner() == primary, "completion focuses 进入第三关", _focus_name())
	_check(_find_label_containing("Enter 进入第三关") != null,
		"the hint names Enter 进入第三关")
	_check(_find_label_containing("R 重玩") != null and _find_label_containing("Esc 暂停") != null,
		"the hint keeps R/Esc")

	# Tab follows the same approved focus_next loop as level 01.
	await _tap_key(KEY_TAB)
	_check(_focus_owner() == replay, "Tab reaches 重玩本关", _focus_name())
	await _tap_key(KEY_TAB)
	_check(_focus_owner() == back, "Tab again reaches 返回主界面", _focus_name())
	await _tap_key(KEY_TAB)
	_check(_focus_owner() == primary, "Tab wraps back to 进入第三关", _focus_name())

	# Keyboard focus chain: Down visits replay then return, Up returns to primary.
	await _tap_key(KEY_DOWN)
	_check(_focus_owner() == replay, "Down reaches 重玩本关", _focus_name())
	await _tap_key(KEY_DOWN)
	_check(_focus_owner() == back, "Down again reaches 返回主界面", _focus_name())
	await _tap_key(KEY_UP)
	await _tap_key(KEY_UP)
	_check(_focus_owner() == primary, "Up returns to 进入第三关", _focus_name())

	# Real mouse: replay still restarts this level.
	await _click(replay)
	await _physics(6)
	_check(not _level.is_completed() and not hud.is_completion_visible(),
		"real mouse on 重玩本关 closes the page")
	_check(_level.get_player().global_position.distance_to(Vector2(36.0, 320.0)) < 3.0,
		"replay returns the body to the L2 spawn", str(_level.get_player().global_position))
	_check(_level.get_stable_stage() == 0, "replay resets the L2 stable stage")

	# Complete again and use the real return command.
	_check(await _setup_l2_completion(), "L2 completion setup works again after replay")
	hud = _level.get_hud()
	back = hud.get_completion_return_button()
	get_tree().current_scene = _level
	await _click(back)
	await _settle(8)
	var title: Node = await _wait_scene("Level01", 160)
	_check(title is Level01, "real mouse on 返回主界面 reaches the real Level01 title",
		str(title))
	if title is Level01:
		_check(not get_tree().paused, "returned title is unpaused")
		_check(title.get_menu() != null and title.get_menu().is_menu_open(),
			"returned title shows the start menu")
	_level = null
	await _clear_all()


func _section_l2_to_l3_mouse() -> void:
	_print_section("A2 L2 completion -> real level 03 by real mouse")
	await _new_l2()
	_check(await _setup_l2_completion(), "L2 completion page for the transition")
	var hud: Level02HUD = _level.get_hud()
	var primary: PixelMenuButton = hud.get_completion_primary_button()
	var replay: PixelMenuButton = hud.get_completion_replay_button()
	var back: PixelMenuButton = hud.get_completion_return_button()
	get_tree().current_scene = _level
	_send_mouse_click(primary)
	_check(_level.is_next_level_started(), "one real mouse press accepts the L3 command")
	_check(primary.disabled and replay.disabled and back.disabled,
		"all completion buttons disable on the accepted press")
	# A second activation attempt in the same frame must be refused.
	hud.next_level_requested.emit()
	_send_key(KEY_ENTER, true)
	_send_key(KEY_ENTER, false)
	_check(_level.is_next_level_started(), "a repeated press/Enter does not change the accepted state")
	var l3: Node = await _wait_scene("Level03", 200)
	_check(l3 is Level03, "the production scene change landed on the real Level03", str(l3))
	if not (l3 is Level03):
		_level = null
		await _clear_all()
		return
	_level = l3
	var count: int = get_tree().root.get_children().filter(
		func(n: Node) -> bool: return n.name == "Level03").size()
	_check(count == 1, "exactly one Level03 root exists after the single transition", str(count))
	await _physics(10)
	_check(not get_tree().paused, "the new level is not paused")
	var player: L3Player = _level.get_player()
	_check(player.global_position.distance_to(Vector2(40.0, 320.0)) < 3.0,
		"level 03 spawn is (40,320)", str(player.global_position))
	_check(player.global_position.y >= 319.0 and player.is_on_floor(),
		"the body starts on the floor, not mid-jump", str(player.global_position))
	_check(player.get_state_name() == "idle", "the body starts idle", player.get_state_name())
	_check(player.is_positive(), "the body starts in 辉相")
	_check(_level.get_guard().get_state_name() == "ACTIVE", "the guard starts ACTIVE",
		_level.get_guard().get_state_name())
	_check(_level.get_device() != null and not _level.get_device().is_active(),
		"the core device/door mechanism starts in its initial inactive state")
	_check(_level.get_stable_stage() == 0, "level 03 starts at the opening stage")
	_check(player.get_hurt_tint_amount() == 0.0 and not player.is_in_hit_reaction(),
		"no hurt flash or reaction is inherited from the completion page")
	_check(not player.is_attacking(), "Enter/mouse did not turn into a J swing")
	_check(_level.get_player_hits() == 0, "no hit was counted on the new level")
	var start_x: float = player.global_position.x
	Input.action_press(&"move_right")
	await _physics(14)
	Input.action_release(&"move_right")
	_check(player.global_position.x > start_x + 8.0,
		"real D input moves the body on level 03",
		"x %.1f -> %.1f" % [start_x, player.global_position.x])
	var moved_x: float = player.global_position.x
	Input.action_press(&"move_left")
	await _physics(20)
	Input.action_release(&"move_left")
	_check(player.global_position.x < moved_x - 3.0, "real A input moves the body back",
		"x %.1f -> %.1f" % [moved_x, player.global_position.x])
	_check(player.global_position.y >= 319.0, "movement did not launch a jump")
	_level = null
	await _clear_all()


func _section_l2_to_l3_enter() -> void:
	_print_section("A3 Enter on the focused L2 primary enters real level 03")
	await _new_l2()
	_check(await _setup_l2_completion(), "L2 completion page for the Enter check")
	var hud: Level02HUD = _level.get_hud()
	var primary: PixelMenuButton = hud.get_completion_primary_button()
	_check(_focus_owner() == primary, "primary owns focus for the Enter confirm")
	get_tree().current_scene = _level
	_send_key(KEY_ENTER, true)
	_check(_level.is_next_level_started(), "Enter accepts the L3 command once")
	_send_key(KEY_ENTER, false)
	var l3: Node = await _wait_scene("Level03", 200)
	_check(l3 is Level03, "Enter path reaches the real Level03", str(l3))
	if l3 is Level03:
		_level = l3
		await _physics(12)
		var player: L3Player = _level.get_player()
		_check(player.global_position.y >= 319.0 and player.is_on_floor(),
			"Enter does not become a jump in level 03", str(player.global_position))
		_check(not player.is_attacking() and _level.get_player_hits() == 0,
			"Enter does not become a J swing or a guard hit")
		_check(_level.get_stable_stage() == 0, "Enter does not restart level 03")
	_level = null
	await _clear_all()


func _section_l2_to_l3_space_carry() -> void:
	_print_section("A4 Space confirms on the L2 page but must not jump in level 03")
	await _new_l2()
	_check(await _setup_l2_completion(), "L2 completion page for the Space carry check")
	var hud: Level02HUD = _level.get_hud()
	var primary: PixelMenuButton = hud.get_completion_primary_button()
	_check(_focus_owner() == primary, "primary owns focus for the Space confirm")
	get_tree().current_scene = _level
	# Send only the key-down edge: the same physical Space is still held when
	# level 03 becomes the running scene.
	_send_key(KEY_SPACE, true)
	_check(_level.is_next_level_started(), "Space on the focused primary accepts the L3 command")
	var l3: Node = await _wait_scene("Level03", 200)
	_check(l3 is Level03, "Space path also reaches the real Level03", str(l3))
	if l3 is Level03:
		_level = l3
		await _physics(12)
		var player: L3Player = _level.get_player()
		_check(player.global_position.y >= 319.0 and player.is_on_floor(),
			"held Space does not become a jump on the first level-03 frames",
			str(player.global_position))
		_check(player.get_state_name() == "idle", "held Space leaves the body idle",
			player.get_state_name())
		_check(not player.is_attacking(), "held Space does not become a J swing")
		_check(_level.get_player_hits() == 0, "held Space does not hit the guard")
		_check(_level.get_stable_stage() == 0, "held Space does not restart level 03")
	_send_key(KEY_SPACE, false)
	await _settle(2)
	_level = null
	await _clear_all()


# --- B. hurt ---------------------------------------------------------------

func _section_hurt_normal() -> void:
	_print_section("B1 real normal slam: red + visible left knockback + 0.6 protection")
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, false)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	_check(guard.get_state_name() == "ACTIVE" or guard.get_state_name() == "NORMAL_WINDUP",
		"the arena guard is live", guard.get_state_name())
	var base: int = _struck_total
	var hit: bool = await _wait_for_struck(base + 1, 420)
	_check(hit, "a real guard slam strikes the player through the guard's own resolution")
	if not hit:
		return
	var hit_x: float = player.global_position.x
	# Hold the direction toward the guard while the knockback is active: the
	# away push must still win for the whole reaction.
	Input.action_press(&"move_right")
	_check(player.get_hurt_tint_amount() >= 0.99,
		"the body is fully red on the hit frame",
		"tint=%.2f" % player.get_hurt_tint_amount())
	_check(player.is_in_hit_reaction(), "the existing 0.15 s reaction is running",
		"%.3f" % player.get_hit_reaction_remaining())
	_check(player.get_hit_protection_remaining() > 0.5,
		"the existing 0.6 s protection is running",
		"%.3f" % player.get_hit_protection_remaining())
	_check(player.velocity.x < -100.0,
		"knockback uses real negative velocity away from the guard while D is held",
		"%.1f" % player.velocity.x)
	_check(player.get_last_hit_direction() == -1, "the pushed direction is away from the guard")
	await _physics(6)
	_check(player.global_position.x <= hit_x - 4.0,
		"the body visibly moved left (not a teleport)",
		"%.1f -> %.1f" % [hit_x, player.global_position.x])
	_check(player.get_hurt_tint_amount() >= 0.99, "red is still visible inside the reaction")
	_check(player.is_hit_protected(), "protection still covers the early follow-up")
	Input.action_release(&"move_right")

	# The guard's own resolve runs again inside the protection window: it must
	# answer PROTECTED and change nothing. This is a boundary check of the real
	# guard gate, not combat evidence.
	var hits_before: int = _level.get_player_hits()
	var accepted_before: int = player.get_hit_count()
	guard.call("_resolve_normal_strike")
	await _physics(1)
	_check(guard.get_last_strike_code() == "PROTECTED",
		"the guard's own protection gate answers PROTECTED", guard.get_last_strike_code())
	_check(_level.get_player_hits() == hits_before, "protected contact does not count a hit")
	_check(player.get_hit_count() == accepted_before, "protected contact does not re-enter the hurt state")

	await _physics(6)
	_check(not player.is_in_hit_reaction(), "the reaction ends on its own 0.15 s window")
	_check(player.get_hurt_tint_amount() == 0.0, "red clears when the reaction ends",
		"tint=%.2f" % player.get_hurt_tint_amount())
	_check(player.is_hit_protected(), "the 0.6 s protection outlives the red flash")
	# After the reaction, normal controls return (guard's next strike is >1 s away).
	var x0: float = player.global_position.x
	Input.action_press(&"move_left")
	await _physics(10)
	Input.action_release(&"move_left")
	_check(player.global_position.x < x0 - 3.0, "A works again after the reaction",
		"%.1f -> %.1f" % [x0, player.global_position.x])
	var polarity_before: bool = player.is_positive()
	Input.action_press(&"polarity")
	await get_tree().physics_frame
	Input.action_release(&"polarity")
	await _physics(2)
	_check(player.is_positive() != polarity_before, "Q works again after the reaction")
	var attack_before: bool = player.is_attacking()
	_send_key(KEY_J, true)
	await _physics(1)
	_send_key(KEY_J, false)
	_check(not attack_before and player.is_attacking(), "J works again after the reaction")
	_level = null
	await _clear_all()


func _section_hurt_right_and_air() -> void:
	_print_section("B2 right side and airborne hits move away from the guard")
	await _new_l3()
	# Right side: the player is to the right of the guard and must be pushed right.
	_level.debug_setup_arena_combat(2080.0, false)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	var base: int = _struck_total
	var hit: bool = await _wait_for_struck(base + 1, 420)
	_check(hit, "real slam connects on the right side")
	if hit:
		var hit_x: float = player.global_position.x
		_check(player.get_hurt_tint_amount() >= 0.99, "right-side hit shows red")
		_check(player.velocity.x > 100.0,
			"right-side knockback points right (away from the guard)",
			"%.1f" % player.velocity.x)
		_check(player.get_last_hit_direction() == 1, "right-side pushed direction is +1")
		await _physics(6)
		_check(player.global_position.x >= hit_x + 4.0, "right-side body visibly moved right",
			"%.1f -> %.1f" % [hit_x, player.global_position.x])

	# Airborne: place the body above the floor just before the real ring release.
	_level.debug_setup_arena_combat(2000.0, true)
	await _physics(8)
	guard = _level.get_guard()
	player = _level.get_player()
	await _wait_for_charge(guard, 0.90)
	var guard_x: float = guard.global_position.x
	player.global_position = Vector2(guard_x - 70.0, 300.0)
	player.velocity = Vector2.ZERO
	var base_air: int = _struck_total
	var air_hit: bool = await _wait_for_struck(base_air + 1, 80)
	_check(air_hit, "the real gravity ring hits the airborne body")
	if air_hit:
		_check(not player.is_on_floor(), "the body was really airborne at the hit",
			str(player.global_position))
		_check(player.get_hurt_tint_amount() >= 0.99, "airborne hit shows red")
		_check(player.velocity.x < -100.0, "airborne knockback points left, away from the guard",
			"%.1f" % player.velocity.x)
		_check(player.get_last_hit_direction() == -1, "airborne pushed direction is -1")
	_level = null
	await _clear_all()


func _section_hurt_ring_behind() -> void:
	_print_section("B3 gravity ring released behind the guard: push is still away from the guard")
	await _new_l3()
	_level.debug_setup_arena_combat(2000.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	await _wait_for_charge(guard, 0.90)
	_check(int(guard.get("_facing")) == -1, "the guard faces the left player when the charge starts",
		str(guard.get("_facing")))
	# Move to the guard's back side after facing is locked in; the ring is real.
	player.global_position = guard.global_position + Vector2(80.0, 0.0)
	player.velocity = Vector2.ZERO
	var base: int = _struck_total
	var hit: bool = await _wait_for_struck(base + 1, 80)
	_check(hit, "the real ring release hits the body behind the guard")
	if hit:
		_check(player.get_hurt_tint_amount() >= 0.99, "behind-side ring hit shows red")
		_check(player.get_last_hit_direction() == 1,
			"the behind-side hit is corrected away from the guard (+1)",
			str(player.get_last_hit_direction()))
		_check(player.velocity.x > 100.0, "behind-side ring push points away from the guard",
			"%.1f" % player.velocity.x)
	_level = null
	await _clear_all()


func _section_two_hit_retry() -> void:
	_print_section("B4 second real hit: show its 0.15 s reaction, then the existing retry")
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	var base: int = _struck_total
	_check(await _wait_for_struck(base + 1, 500), "first real hit lands")
	_check(_level.get_player_hits() == 1, "first hit counts once")
	_check(not _level.is_retry_pending(), "one hit does not schedule a retry")
	_check(await _wait_for_struck(base + 2, 900), "second real hit lands")
	_check(_level.get_player_hits() == 2, "second hit counts once")
	_check(_level.is_retry_pending(), "the second hit schedules the existing current-fight retry")
	_check(player.is_in_hit_reaction(), "the second hit's own reaction starts before the retry",
		"%.3f" % player.get_hit_reaction_remaining())
	_check(player.get_hurt_tint_amount() >= 0.99, "the second hit is red before the retry")
	var hit_pos: Vector2 = player.global_position
	await _physics(2)
	_check(_level.is_retry_pending(), "the retry waits for the visible reaction")
	_check(player.global_position.distance_to(hit_pos) < 8.0,
		"the body is not teleported while the reaction is showing",
		str(player.global_position))
	# A third signal during the pending window is refused (boundary check).
	guard.player_struck.emit(-1)
	await _physics(1)
	_check(_level.get_player_hits() == 2, "a third signal during pending is not accepted")
	var retried: bool = false
	for _i: int in range(30):
		await get_tree().physics_frame
		if not _level.is_retry_pending():
			retried = true
			break
	_check(retried, "the pending retry is committed after the existing reaction window")
	_check(_level.is_recovery_active(),
		"the approved cover starts after the complete 0.15 s reaction")
	_check(await _wait_recovery_done(),
		"the approved recovery transition completes (fade / black / fade)")
	_check(_level.get_recovery_reset_alpha() >= 0.999,
		"the retry runs only at a fully black cover",
		"reset_alpha=%.3f" % _level.get_recovery_reset_alpha())
	await _physics(2)
	_check(_level.get_player_hits() == 0, "the retry resets the two-hit counter")
	_check(player.global_position.distance_to(_level.get_arena_spawn()) <= 6.0,
		"the retry returns the body to the guard-front recovery point",
		str(player.global_position))
	_check(player.get_hurt_tint_amount() == 0.0, "the retry leaves no red behind")
	_check(player.velocity == Vector2.ZERO, "the retry leaves no knockback velocity",
		str(player.velocity))
	_check(_level.get_stable_stage() >= 3, "the retry keeps the arena recovery stage")
	_check(guard.has_teaching_seen(), "the retry keeps the already-seen teaching")
	_check(guard.get_state_name() == "ACTIVE" or guard.get_state_name() == "GRAVITY_CHARGE",
		"the guard is reset, not left broken", guard.get_state_name())
	_level = null
	await _clear_all()


func _section_pause_resume() -> void:
	_print_section("B5 pause: first hit keeps 1 hit; a decided second-hit retry still runs")
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	var base: int = _struck_total
	_check(await _wait_for_struck(base + 1, 520), "a real first hit lands")
	_check(_level.get_player_hits() == 1, "first hit counts once")
	await _tap_key(KEY_ESCAPE)
	_check(get_tree().paused and _level.get_pause_menu().call("is_open"),
		"Esc opens the real pause page after the first hit")
	_check(not _level.is_retry_pending(), "a first hit has no decided retry to preserve")
	_check(player.get_hurt_tint_amount() == 0.0 and not player.is_in_hit_reaction(),
		"pause clears the visible red flash/reaction")
	await _tap_key(KEY_ESCAPE)
	await _physics(6)
	_check(not get_tree().paused, "Esc resumes after the first hit")
	_check(_level.get_player_hits() == 1, "first-hit resume keeps exactly one hit, no retry")
	_check(not _level.is_retry_pending(), "first-hit resume does not invent a retry")
	_check(player.global_position.distance_to(_level.get_arena_spawn()) > 20.0,
		"first-hit resume did not teleport to the recovery point",
		str(player.global_position))

	# Second real hit -> decided current-fight retry -> pause inside its 0.15 s
	# window. The pause must not cancel the decided failure.
	_check(await _wait_for_struck(base + 2, 900), "a second real hit lands")
	_check(_level.get_player_hits() == 2 and _level.is_retry_pending(),
		"the second hit decides the current-fight retry")
	await _open_pause_now()
	_check(get_tree().paused and _level.get_pause_menu().call("is_open"),
		"Esc opens the pause page inside the 0.15 s window")
	_check(_level.is_retry_pending(), "pause preserves the decided retry")
	_check(_level.get_player_hits() == 2, "pause does not clear the two-hit count")
	_check(player.get_hurt_tint_amount() == 0.0 and not player.is_in_hit_reaction(),
		"pause still clears the visible red/reaction/knockback")
	var pre_resume_pos: Vector2 = player.global_position
	await _tap_key(KEY_ESCAPE)
	await _physics(2)
	_check(not get_tree().paused, "resume closes the pause page")
	_check(_level.is_recovery_active() or _level.get_recovery_finished_count() > 0,
		"resume continues the decided recovery instead of dropping it")
	_check(await _wait_recovery_done(),
		"the resumed recovery transition completes")
	_check(_level.get_player_hits() == 0, "resume executes the existing retry exactly once")
	_check(not _level.is_retry_pending(), "the retry consumes the pending flag")
	_check(player.global_position.distance_to(_level.get_arena_spawn()) <= 6.0,
		"the retry restores the guard-front recovery point",
		"%s -> %s" % [pre_resume_pos, player.global_position])
	_check(player.get_hurt_tint_amount() == 0.0 and player.velocity == Vector2.ZERO,
		"the retry leaves no red or knockback velocity")
	_check(_level.get_stable_stage() >= 3, "the retry keeps the arena progress")
	_check(guard.has_teaching_seen(), "the retry keeps the already-seen teaching")
	_check(guard.get_state_name() == "ACTIVE" or guard.get_state_name() == "GRAVITY_CHARGE",
		"the retry resets the guard, not leaves it broken", guard.get_state_name())
	await _physics(12)
	_check(_level.get_player_hits() == 0 and not _level.is_retry_pending(),
		"no duplicate retry after the resume")
	_level = null
	await _clear_all()


func _section_pause_r_return() -> void:
	_print_section("B6 pause R / 返回 override a decided retry without repeating it")
	# Pending + R: R is the restart command and must win once, with no retry.
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, false)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	var base: int = _struck_total
	_check(await _wait_for_struck(base + 1, 520), "first hit before the pending-R check")
	_check(await _wait_for_struck(base + 2, 900), "second hit decides the retry before R")
	_check(_level.is_retry_pending(), "the retry is pending before the pause-R")
	await _open_pause_now()
	_check(get_tree().paused and _level.is_retry_pending(),
		"pause preserves pending for the R check")
	await _tap_key(KEY_R)
	await _settle(4)
	_check(not get_tree().paused and not _level.get_pause_menu().call("is_open"),
		"R on the pause root restarts and closes the page")
	_check(_level.get_stable_stage() == 0, "R returns to the opening stage")
	_check(_level.get_player_hits() == 0 and not _level.is_retry_pending(),
		"R clears the two-hit pending state")
	_check(player.global_position.distance_to(Vector2(40.0, 320.0)) < 6.0,
		"R returns the body to the level-03 start, not the retry point",
		str(player.global_position))
	await _physics(16)
	_check(player.global_position.distance_to(Vector2(40.0, 320.0)) < 6.0
		and _level.get_player_hits() == 0,
		"no retry fires after R", str(player.global_position))
	_level = null
	await _clear_all()

	# Pending + 返回: the real pause-page return leaves for the title; no retry is
	# observable or needed because the fight instance is replaced.
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, false)
	await _physics(8)
	guard = _level.get_guard()
	player = _level.get_player()
	base = _struck_total
	_check(await _wait_for_struck(base + 1, 520), "first hit before the pending-return check")
	_check(await _wait_for_struck(base + 2, 900), "second hit decides the retry before 返回")
	_check(_level.is_retry_pending(), "the retry is pending before the pause-return")
	await _open_pause_now()
	var back: PixelMenuButton = _level.get_pause_menu().call("get_return_button") as PixelMenuButton
	_check(back != null and _level.is_retry_pending(), "pause-return keeps the pending decision")
	get_tree().current_scene = _level
	await _click(back)
	var title: Node = await _wait_scene("Level01", 240)
	_check(title is Level01, "pause 返回 really reaches the Level01 title", str(title))
	_check(not get_tree().paused, "returned title is unpaused")
	var leftovers: int = get_tree().root.get_children().filter(
		func(n: Node) -> bool: return n is Level03).size()
	_check(leftovers == 0, "the failed L3 instance is gone; no retry runs in the title",
		str(leftovers))
	_level = null
	await _clear_all()


func _section_locks() -> void:
	_print_section("B7 cinematic/completion locks clear an active flash")
	await _new_l3()
	_level.debug_setup_arena_combat(2020.0, false)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	var base: int = _struck_total
	_check(await _wait_for_struck(base + 1, 420), "a real hit lands before the cinematic lock check")
	player.lock_for_cinematic()
	_check(player.get_hurt_tint_amount() == 0.0 and not player.is_in_hit_reaction(),
		"the cinematic lock clears red/reaction")
	player.unlock_after_cinematic()
	_level.debug_setup_arena_combat(2020.0, false)
	await _physics(8)
	base = _struck_total
	_check(await _wait_for_struck(base + 1, 420), "a real hit lands before the completion lock check")
	player.lock_completion_input()
	_check(player.get_hurt_tint_amount() == 0.0 and not player.is_in_hit_reaction(),
		"the completion lock clears red/reaction/knockback")
	_check(player.velocity == Vector2.ZERO, "the completion lock clears knockback velocity")
	player.unlock_completion_input()
	_level = null
	await _clear_all()


# --- harness ---------------------------------------------------------------

func _new_l2() -> void:
	await _clear_all()
	_level = LEVEL02_SCENE.instantiate() as Level02
	_level.pause_audio_settings_path = TEMP_AUDIO
	_level.pause_display_settings_path = TEMP_DISPLAY
	get_tree().root.add_child(_level)
	await _physics(8)
	await _settle(2)


func _new_l3() -> void:
	await _clear_all()
	_struck_total = 0
	_level = LEVEL03_SCENE.instantiate() as Level03
	_level.pause_audio_settings_path = TEMP_AUDIO
	_level.pause_display_settings_path = TEMP_DISPLAY
	get_tree().root.add_child(_level)
	await _physics(24)
	var guard: L3Guard = _level.get_guard()
	if not guard.player_struck.is_connected(_on_player_struck):
		# Deferred: the level's own handler runs first in the same emission, so
		# the harness observes the already-updated hits/pending state.
		guard.player_struck.connect(_on_player_struck, CONNECT_DEFERRED)


func _on_player_struck(_facing: int) -> void:
	_struck_total += 1


func _setup_l2_completion() -> bool:
	_level.debug_restore_stage(2, false)
	await _physics(4)
	var final_bay: StarCoreBayInteractable = _level.get_final_bay()
	final_bay.reset_empty()
	final_bay.start_store_core(false)
	final_bay.finish_store()
	var player = _level.get_player()
	player.global_position = _level.get_exit().global_position
	player.velocity = Vector2.ZERO
	await _physics(8)
	if not _level.is_completed():
		_level._try_complete_at_exit()
		await _physics(3)
	await _settle(3)
	return _level.is_completed() and _level.get_hud().is_completion_visible()


func _wait_for_struck(target: int, limit: int) -> bool:
	for _i: int in range(limit):
		await get_tree().physics_frame
		if _struck_total >= target:
			return true
	return false


## The 2026-11-16 recovery cover is timed on idle frames. The old assertions
## still run after the real transition completes; nothing is skipped.
func _wait_recovery_done(limit: int = 1200) -> bool:
	if _level == null:
		return false
	for _i: int in range(limit):
		await get_tree().process_frame
		if not _level.is_recovery_active():
			await _physics(2)
			return true
	return false


func _wait_for_charge(guard: L3Guard, ratio: float) -> void:
	for _i: int in range(360):
		await get_tree().physics_frame
		if guard.get_state_name() == "GRAVITY_CHARGE" and guard.get_charge_ratio() >= ratio:
			return


func _clear_all() -> void:
	get_tree().paused = false
	# Free every level root this harness created, not only the last tracked one.
	# A stale Level03 would otherwise keep running its guard and pollute the
	# next section's hit counter.
	for child: Node in get_tree().root.get_children():
		if child == self:
			continue
		if child is Level01 or child is Level02 or child is Level03:
			if child.has_method("get_audio"):
				var audio: Node = child.call("get_audio") as Node
				if audio != null and audio.has_method("release_streams"):
					audio.call("release_streams")
			if get_tree().current_scene == child:
				get_tree().current_scene = null
			child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_level = null
	_struck_total = 0
	get_tree().paused = false
	# Clear any input left pressed by a failed step.
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity",
			&"interact", &"reset", &"pause", &"tutorial_next"]:
		Input.action_release(action)


func _wait_scene(prefix: String, max_frames: int) -> Node:
	for _i: int in range(max_frames):
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if current != null and current.name.begins_with(prefix):
			await _settle(4)
			return current
	return get_tree().current_scene


func _click(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var center: Vector2 = control.get_global_rect().get_center()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	get_viewport().push_input(up, true)
	await get_tree().process_frame
	await get_tree().process_frame


## Synchronous real mouse click: the button handlers run inside push_input, so a
## scene-change command can be inspected before the deferred scene swap.
func _send_mouse_click(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var center: Vector2 = control.get_global_rect().get_center()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	get_viewport().push_input(down, true)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	get_viewport().push_input(up, true)


func _open_pause_now() -> void:
	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await get_tree().process_frame


func _tap_key(key: Key) -> void:
	_send_key(key, true)
	await get_tree().process_frame
	_send_key(key, false)
	await get_tree().process_frame
	await get_tree().process_frame


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _find_label_containing(fragment: String) -> Label:
	for node: Node in get_tree().root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.text.contains(fragment):
			return label
	return null


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


func _focus_name() -> String:
	var owner: Control = _focus_owner()
	return owner.name if owner != null else "<none>"


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _settle(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _remove_temp(path: String) -> void:
	var global: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)


func _print_section(title: String) -> void:
	print("")
	print("-- %s --" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass += 1
		print("[PASS] %s  (%s)" % [label, detail])
	else:
		_fail += 1
		print("[FAIL] %s  (%s)" % [label, detail])
