extends Node

## DLC2 双面镜 v2 headless test: 3-cell health / 3 lives, current-form retry,
## one-time form-1 refill, game-over page, and the two new readable attacks.
##
##   ... --headless --path . res://dlc/rift_workshop/tests/boss_v2_test.tscn
##
## The three real hazards are exercised through the boss states:
##   - mirror double: 0.6 s warning, one low sweep, same-phase J scatter;
##   - tracking light: 0.6 s charge, 60 px/s, max 1, floor impact/damage.
## No damage fakes are used for the new attacks; the life/game-over setup only
## emits the existing boss signal and clears the chapter grace between hits so
## the state machine (not a fake reset) drives recovery.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _rift: RiftWorkshop
var _player: L3Player
var _boss: RiftMirrorBoss
var _hud: RiftWorkshopHUD
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("RIFT_BOSS_V2_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- helpers ---------------------------------------------------------------

func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: " + label + ("" if detail.is_empty() else " [" + detail + "]"))
		return
	_failures.append(label + ("" if detail.is_empty() else " [" + detail + "]"))
	print("FAIL: " + label + ("" if detail.is_empty() else " [" + detail + "]"))


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_process(2)
	_push_key(code, false)
	await _wait_process(4)


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)


func _jab() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(3)
	_push_key(KEY_J, false)
	await _wait_physics(45)


func _close_popup_if_open() -> void:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)


func _wait_for_boss_active(max_frames: int = 300) -> bool:
	for _index: int in range(max_frames):
		if _boss.is_active() and _boss.get_attack_state_name() != "INTRO":
			return true
		await get_tree().physics_frame
	return false


func _wait_for_anchors(count: int, max_frames: int = 240) -> bool:
	return await _wait_until(
		func() -> bool: return _boss.get_alive_anchor_count() == count,
		max_frames
	)


## Test setup only: clear the 0.95 s chapter grace so a life can be spent
## quickly.  The real 0.95 s value is asserted separately.
func _force_hit() -> void:
	_rift.set("_damage_immunity_left", 0.0)
	_boss.player_struck.emit(1)
	await _wait_physics(3)


func _spend_health() -> void:
	for _index: int in range(3):
		await _force_hit()


func _wait_for_retry(max_frames: int = 420) -> bool:
	var began: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 120
	)
	if not began:
		return false
	return await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), max_frames
	)


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	if _rift != null and is_instance_valid(_rift) and _rift != current:
		_rift.queue_free()
	await _wait_process(20)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


# --- main flow -------------------------------------------------------------

func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_check(packed != null, "rift scene loads")
	if packed == null:
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(6)
	await _wait_physics(8)
	_player = _rift.get_player()
	_boss = _rift.get_boss()
	_hud = _rift.get_hud()
	_check(_player != null and _boss != null and _hud != null,
		"chapter exposes player, mirror boss and HUD")
	if _player == null or _boss == null or _hud == null:
		return

	# --- the aligned 3 / 3 read -----------------------------------------
	var bar: PlayerHealthBar = _hud.get_player_health_bar()
	_check(bar != null and bar.get_max() == 3 and bar.get_current() == 3,
		"health starts as a full three-cell bar",
		"current=%d max=%d" % [bar.get_current(), bar.get_max()])
	_check(_rift.get_lives() == 3 and _rift.get_max_lives() == 3,
		"the run starts with three lives",
		"%d / %d" % [_rift.get_lives(), _rift.get_max_lives()])
	_check(_hud.get_lives() == 3 and _hud.get_max_lives() == 3
		and _hud.get_boss_status().is_lives_visible(),
		"three life hearts are wired under the boss bar")
	_check(is_equal_approx(_rift.get_damage_immunity_time(), 0.95),
		"chapter hit grace is 0.95 s like the star loom",
		"%.2f s" % _rift.get_damage_immunity_time())

	await _place(1300.0, 320.0, true)
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 240)
	await _close_popup_if_open()
	var boss_active: bool = await _wait_for_boss_active()
	_check(boss_active, "the mirror is active in the arena")
	_boss.set_attacks_enabled(false)
	_check(_hud.is_boss_visible() and _hud.is_lives_visible()
		and _hud.get_lives() == 3,
		"arena HUD shows the boss bar with three full hearts")

	# --- form 2: mirror double ------------------------------------------
	_boss.debug_set_phase(1)
	var anchors: bool = await _wait_for_anchors(2)
	_check(anchors, "form 2 restores both plate anchors",
		str(_boss.get_alive_anchor_count()))
	_check(_boss.get_next_attack_kind() == "wave",
		"form 2 still opens with the phase wave")
	# Let the real rotation reach the double without debug forcing: wave, sweep,
	# then the third attack.  The player waits outside the arena width.
	await _place(1230.0, 320.0, true)
	_boss.set_attacks_enabled(true)
	var natural_clone: bool = await _wait_until(
		func() -> bool: return _boss.get_clone_cast_count() > 0, 700
	)
	_check(natural_clone, "form 2 naturally rotates to the mirror double",
		str(_boss.get_clone_cast_count()))
	await _wait_until(
		func() -> bool:
			return (
				not _boss.is_clone_active()
				and _boss.get_attack_state_name() == "IDLE"
			),
		180
	)
	_boss.set_attacks_enabled(false)
	var wave_before: int = _boss.get_phase_wave_count()
	var sweep_before: int = _boss.get_sweep_count()
	var release_before_debug: int = _boss.get_clone_release_count()
	await _place(1300.0, 320.0, true)
	_boss.debug_force_clone()
	var clone_warn: bool = await _wait_until(
		func() -> bool: return _boss.get_attack_state_name() == "CLONE_WARN", 40
	)
	_check(clone_warn and _boss.is_clone_telegraph_visible(),
		"the mirror double enters its warning state")
	_check(is_equal_approx(_boss.get_clone_warn_time(), 0.6),
		"mirror-double warning is exactly 0.6 s",
		"%.2f s" % _boss.get_clone_warn_time())
	await _wait_physics(6)
	_check(_boss.get_clone_warn_draw_count() > 0,
		"the double warning was really drawn",
		str(_boss.get_clone_warn_draw_count()))
	_check(_boss.get_phase_wave_count() == wave_before
		and _boss.get_sweep_count() == sweep_before,
		"the real body does not fire a wave or sweep during the double",
		"wave=%d sweep=%d" % [_boss.get_phase_wave_count(), _boss.get_sweep_count()])
	var release_started: bool = await _wait_until(
		func() -> bool: return _boss.get_clone_release_count() > release_before_debug, 90
	)
	await _wait_physics(4)
	_check(release_started and _boss.get_clone_release_count() == release_before_debug + 1,
		"the double releases exactly one low sweep",
		"%d -> %d" % [release_before_debug, _boss.get_clone_release_count()])
	_check(_rift.get_player_hits() == 1,
		"a grounded player takes one health-cell hit from the double",
		str(_rift.get_player_hits()))
	_check(_rift.get_damage_immunity_left() > 0.0
		and _rift.get_damage_immunity_left() <= 0.95,
		"the accepted hit starts the 0.95 s chapter grace",
		"%.2f s" % _rift.get_damage_immunity_left())
	# A second signal inside the grace must not spend another cell.
	var hits_after_first: int = _rift.get_player_hits()
	_boss.player_struck.emit(1)
	await _wait_physics(2)
	_check(_rift.get_player_hits() == hits_after_first,
		"a second hit inside the grace is refused",
		"%d -> %d" % [hits_after_first, _rift.get_player_hits()])
	await _wait_until(
		func() -> bool: return _boss.get_attack_state_name() == "IDLE", 90
	)

	# Same-phase J scatters the double during the warning; no sweep resolves.
	var hits_before_scatter: int = _rift.get_player_hits()
	var release_before: int = _boss.get_clone_release_count()
	_boss.debug_force_clone()
	await _wait_until(
		func() -> bool: return _boss.get_attack_state_name() == "CLONE_WARN", 40
	)
	var clone_x: float = _boss.get_clone_global_position().x
	await _place(clone_x - 44.0, 320.0, _boss.get_clone_positive())
	_player.face_direction(1)
	await _jab()
	_check(String(_boss.get_last_result().get("code", "")) == "CLONE_SHATTER",
		"a same-phase J scatters the mirror double",
		String(_boss.get_last_result().get("code", "")))
	_check(_boss.get_clone_shatter_count() == 1 and not _boss.is_clone_active(),
		"the scattered double is gone")
	await _wait_physics(40)
	_check(_boss.get_clone_release_count() == release_before,
		"a scattered double never releases its sweep",
		"%d -> %d" % [release_before, _boss.get_clone_release_count()])
	_check(_rift.get_player_hits() == hits_before_scatter,
		"scattering the double deals no damage to the player")

	# The double's low sweep is dodgeable with the same jump read as the real
	# sweep: jump early, stay above the 12 px line through the release.
	await _place(1450.0, 320.0, true)
	var jump_release_before: int = _boss.get_clone_release_count()
	var jump_hits_before: int = _rift.get_player_hits()
	_boss.debug_force_clone()
	await _wait_until(
		func() -> bool: return _boss.get_attack_state_name() == "CLONE_WARN", 40
	)
	await _wait_physics(24)
	Input.action_press(&"jump")
	await _wait_physics(2)
	Input.action_release(&"jump")
	var jump_release: bool = await _wait_until(
		func() -> bool: return _boss.get_clone_release_count() > jump_release_before, 60
	)
	await _wait_physics(4)
	_check(jump_release and _rift.get_player_hits() == jump_hits_before,
		"jumping clears the mirror double's low sweep",
		"hits=%d y=%.1f" % [_rift.get_player_hits(), _player.global_position.y])
	await _wait_until(func() -> bool: return not _boss.is_clone_active(), 90)

	# --- form 3: tracking mirror light ----------------------------------
	_boss.debug_set_phase(2)
	await _wait_for_anchors(2)
	_check(_boss.get_next_attack_kind() == "wave",
		"form 3 still opens with the phase wave")
	# Let the real rotation reach the tracking light: wave, double sweep, then
	# the light.  Waiting outside the arena keeps the damage test below clean.
	await _place(1230.0, 320.0, true)
	var natural_fire_before: int = _boss.get_homing_fire_count()
	_boss.set_attacks_enabled(true)
	var natural_homing: bool = await _wait_until(
		func() -> bool: return _boss.get_homing_fire_count() > natural_fire_before, 900
	)
	_check(natural_homing, "form 3 naturally rotates to the tracking light",
		str(_boss.get_homing_fire_count()))
	await _wait_until(func() -> bool: return not _boss.is_homing_active(), 600)
	_boss.set_attacks_enabled(false)
	await _place(1500.0, 320.0, true)
	var fire_before_light: int = _boss.get_homing_fire_count()
	var ground_before_light: int = _boss.get_homing_ground_hit_count()
	var wave_before_light: int = _boss.get_phase_wave_count()
	var sweep_before_light: int = _boss.get_sweep_count()
	_boss.debug_force_homing()
	var charge: bool = await _wait_until(
		func() -> bool: return _boss.is_homing_charging(), 40
	)
	_check(charge, "tracking light enters its core charge")
	_check(is_equal_approx(_boss.get_homing_warn_time(), 0.6),
		"tracking-light warning is exactly 0.6 s",
		"%.2f s" % _boss.get_homing_warn_time())
	await _wait_physics(6)
	_check(_boss.get_homing_charge_draw_count() > 0,
		"the core charge/sight line was really drawn",
		str(_boss.get_homing_charge_draw_count()))
	var fired: bool = await _wait_until(
		func() -> bool: return _boss.is_homing_active(), 90
	)
	_check(fired, "the charge launches one orb")
	_check(is_equal_approx(_boss.get_homing_speed(), 60.0),
		"orb speed is 60 px/s (inside 55-65)", "%.0f px/s" % _boss.get_homing_speed())
	_check(_boss.get_active_homing_count() == 1
		and _boss.get_homing_fire_count() == fire_before_light + 1,
		"only one tracking orb exists")
	await _wait_physics(6)
	_check(_boss.get_homing_orb_draw_count() > 0,
		"the tracking orb was really drawn",
		str(_boss.get_homing_orb_draw_count()))
	_boss.debug_force_homing()
	await _wait_physics(2)
	_check(_boss.get_active_homing_count() == 1
		and _boss.get_homing_fire_count() == fire_before_light + 1,
		"the light refuses a second orb while one is in flight")
	await _wait_physics(20)
	_check(_boss.get_phase_wave_count() == wave_before_light
		and _boss.get_sweep_count() == sweep_before_light,
		"the real body waits while the light is in flight",
		"wave=%d sweep=%d" % [
			_boss.get_phase_wave_count(), _boss.get_sweep_count()
		])
	_check(_boss.get_attack_state_name() == "IDLE",
		"the real body is idle, not double-sweeping, during the light",
		_boss.get_attack_state_name())
	# Freeze the player high above the floor so the orb is led into the ground
	# without touching the body.  This is setup, not a fake ground collision.
	_player.begin_recovery_hold()
	_player.global_position = Vector2(1260.0, 180.0)
	_player.velocity = Vector2.ZERO
	var ground_hit: bool = await _wait_until(
		func() -> bool: return _boss.get_homing_ground_hit_count() > ground_before_light,
		360
	)
	_check(ground_hit and not _boss.is_homing_active(),
		"the tracking light vanishes on the floor",
		"ground=%d active=%s" % [
			_boss.get_homing_ground_hit_count(), str(_boss.is_homing_active())
		])
	_player.end_recovery_hold()
	await _place(1500.0, 320.0, true)
	await _wait_physics(65)

	# A grounded player is the other legal outcome: one health cell.
	_boss.debug_force_homing()
	await _wait_until(func() -> bool: return _boss.is_homing_active(), 90)
	var player_hit_before: int = _rift.get_player_hits()
	var light_hit: bool = await _wait_until(
		func() -> bool: return _boss.get_homing_hit_player_count() > 0, 240
	)
	await _wait_physics(3)
	_check(light_hit and _rift.get_player_hits() == player_hit_before + 1,
		"a grounded player takes one health-cell hit from the light",
		"%d -> %d" % [player_hit_before, _rift.get_player_hits()])
	_check(not _boss.is_homing_active(),
		"the light disappears after hitting the player")

	# --- a health death replays the current form ------------------------
	_boss.set_attacks_enabled(false)
	var phase_before_death: int = _boss.get_phase_number()
	await _force_hit()
	await _force_hit()
	await _force_hit()
	var retried: bool = await _wait_for_retry()
	await _wait_physics(6)
	_check(retried, "the third health-cell hit finishes the retry transition")
	_check(_rift.get_lives() == 2,
		"a health death spends exactly one life",
		str(_rift.get_lives()))
	_check(_boss.get_phase_number() == phase_before_death
		and _boss.get_core_hp() == 3
		and _boss.get_intact_face_count() == 2
		and not _boss.is_core_exposed(),
		"the current form is restored from its opening",
		"phase=%d core=%d faces=%d" % [
			_boss.get_phase_number(), _boss.get_core_hp(),
			_boss.get_intact_face_count()
		])
	_check(_rift.get_player_hits() == 0 and bar.get_current() == 3,
		"the replay refills all three health cells",
		"hits=%d bar=%d" % [_rift.get_player_hits(), bar.get_current()])
	_check(_hud.get_lives() == 2,
		"the HUD heart row drops to two", str(_hud.get_lives()))
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 240)
	await _wait_for_boss_active()
	_boss.set_attacks_enabled(false)

	# --- second and third deaths -> game over -> R reset ----------------
	_boss.debug_set_phase(1)
	await _wait_physics(8)
	await _spend_health()
	var second_retry: bool = await _wait_for_retry()
	_check(second_retry and _rift.get_lives() == 1,
		"the second death leaves one life", str(_rift.get_lives()))
	_check(_boss.get_phase_number() == 2 and bar.get_current() == 3,
		"the second death also replays the current form with full health",
		"phase=%d bar=%d" % [_boss.get_phase_number(), bar.get_current()])
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 240)
	await _wait_for_boss_active()
	_boss.set_attacks_enabled(false)
	await _spend_health()
	var game_over: bool = await _wait_until(
		func() -> bool: return _rift.is_game_over(), 420
	)
	await _wait_physics(4)
	_check(game_over, "zero lives opens the game-over page")
	_check(_rift.get_lives() == 0 and _hud.get_lives() == 0,
		"the life row is empty at game over",
		"lives=%d hud=%d" % [_rift.get_lives(), _hud.get_lives()])
	_check(_hud.is_game_over_visible(),
		"the game-over page is visible")
	_check(_hud.get_game_over_title_text() == "生命耗尽",
		"game-over title matches the star loom", _hud.get_game_over_title_text())
	_check(_hud.get_game_over_retry_button().text == "重试本章"
		and _hud.get_game_over_title_button().text == "返回标题",
		"game-over buttons are 重试本章 / 返回标题")
	_check(_hud.get_game_over_hearts().get_current() == 0
		and _hud.get_game_over_hearts().get_max() == 3,
		"game-over heart row shows 0 / 3")
	_check(not _hud.is_player_health_visible() and not _hud.is_boss_visible(),
		"game over hides the health bar and boss bar")
	_check(not _hud.get_header().is_chrome_visible(),
		"game over hides the top chapter/objective row")
	_check(_hud.get_game_over_note_text().contains("R 重试本章"),
		"game-over note names R", _hud.get_game_over_note_text())

	await _tap_key(KEY_R)
	await _wait_process(4)
	await _wait_physics(10)
	_check(not _rift.is_game_over() and not _hud.is_game_over_visible(),
		"R leaves the game-over page")
	_check(_rift.get_lives() == 3 and _rift.get_player_hits() == 0
		and bar.get_current() == 3,
		"R restores three lives and three health cells",
		"lives=%d hits=%d bar=%d" % [
			_rift.get_lives(), _rift.get_player_hits(), bar.get_current()
		])
	_check(_boss.get_phase_number() == 1 and _boss.get_core_hp() == 3,
		"R restarts the mirror at form 1 / core 3")
	_check(absf(_player.global_position.x - 40.0) < 3.0,
		"R returns the player to the chapter spawn",
		"x=%.1f" % _player.global_position.x)
