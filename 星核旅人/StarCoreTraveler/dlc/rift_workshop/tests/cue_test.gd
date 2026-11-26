extends Node

## Focused telegraph test for the double-mirror boss (2026-11-26 rework 2).
##
##   ... --headless --path . res://dlc/rift_workshop/tests/cue_test.tscn
##
## Proves the three attacks have readable telegraph states and then clear:
##   - phase wave: split ring telegraph, then a floor wave that flips a grounded
##     player; the telegraph state and its draw count are observable;
##   - mirror sweep: low-line telegraph, then a low beam that costs one bar segment;
##     a jump clears the beam;
##   - summon: a cast state, then exactly two real hazard wisps.
## The test uses the boss's debug_force_* hooks only to start the normal attack
## states early; every flip/damage/summon is the real attack resolution.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _checks: int = 0
var _failures: Array[String] = []
var _rift: RiftWorkshop
var _player: L3Player
var _boss: RiftMirrorBoss


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("RIFT_CUE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


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


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)


func _close_popup_if_open() -> bool:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return false
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)
	return not popup.is_open()


func _wait_for_boss_active(max_frames: int = 240) -> bool:
	for _index: int in range(max_frames):
		if _boss.is_active() and _boss.get_attack_state_name() != "INTRO":
			return true
		await get_tree().physics_frame
	return false


func _cleanup() -> void:
	await _wait_process(2)
	get_tree().current_scene = null
	if _rift != null and is_instance_valid(_rift):
		_rift.queue_free()
	await _wait_process(20)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


func _run() -> void:
	MechanicTips.reset_for_test()
	MechanicPopup.reset_registered_tips_for_test()
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_check(packed != null, "rift scene loads")
	if packed == null:
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(4)
	await _wait_physics(10)
	_player = _rift.get_player()
	_boss = _rift.get_boss()
	_check(_boss != null, "boss node exists")

	await _place(1250.0, 320.0, true)
	await _wait_physics(4)
	_check(_rift.is_arena_entered(), "arena entry")
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	await _wait_process(2)
	await _close_popup_if_open()
	var active: bool = await _wait_for_boss_active()
	_check(active, "boss is active", _boss.get_attack_state_name())
	_boss.set_attacks_enabled(false)

	# --- phase wave ------------------------------------------------------
	await _place(_boss.global_position.x - 80.0, 320.0, true)
	var wave_draws_before: int = _boss.get_wave_telegraph_draw_count()
	_boss.debug_force_wave()
	var wave_warn: bool = await _wait_until(
		func() -> bool: return _boss.is_phase_wave_telegraph_visible(), 60
	)
	_check(wave_warn, "phase wave shows its ground-band telegraph")
	_check(is_equal_approx(_boss.get_wave_warning_time(), 0.6),
		"phase wave warning is exactly 0.6 s",
		"%.2f s" % _boss.get_wave_warning_time())
	_check(not _boss.get_wave_result_positive(),
		"wave icon/band names the resulting 澜相 for a 辉相 player")
	var wave_release: bool = await _wait_until(
		func() -> bool: return _boss.get_phase_wave_count() > 0, 120
	)
	_check(wave_release, "phase wave releases after the ring telegraph")
	_check(_boss.get_wave_telegraph_draw_count() > wave_draws_before,
		"the ring telegraph was really drawn",
		"%d -> %d" % [wave_draws_before, _boss.get_wave_telegraph_draw_count()])
	_check(not _player.is_positive(),
		"a grounded player is flipped by the wave",
		str(_player.is_positive()))
	_check(not _boss.is_phase_wave_telegraph_visible(),
		"the ring telegraph clears on release")
	await _wait_until(func() -> bool: return _boss.get_attack_state_name() == "IDLE", 90)

	# --- mirror sweep: hit, then jump over ------------------------------
	await _place(_boss.global_position.x - 80.0, 320.0, true)
	var hits_before: int = _rift.get_player_hits()
	var sweep_draws_before: int = _boss.get_sweep_telegraph_draw_count()
	_boss.debug_force_sweep()
	var sweep_warn: bool = await _wait_until(
		func() -> bool: return _boss.is_sweep_telegraph_visible(), 60
	)
	_check(sweep_warn, "mirror sweep shows its red low-line telegraph")
	_check(is_equal_approx(_boss.get_sweep_warn_time(), 0.85),
		"form 1 sweep keeps the slow warning", "%.2f s" % _boss.get_sweep_warn_time())
	var sweep_one: bool = await _wait_until(
		func() -> bool: return _boss.get_sweep_count() > 0, 120
	)
	await _wait_physics(4)
	_check(sweep_one, "mirror sweep releases")
	_check(_boss.get_sweep_telegraph_draw_count() > sweep_draws_before,
		"the sweep telegraph was really drawn",
		"%d -> %d" % [sweep_draws_before, _boss.get_sweep_telegraph_draw_count()])
	_check(_rift.get_player_hits() == hits_before + 1,
		"a grounded player takes one sweep hit",
		"%d -> %d" % [hits_before, _rift.get_player_hits()])
	_check(not _boss.is_sweep_telegraph_visible(),
		"the sweep telegraph clears on release")
	await _wait_until(func() -> bool: return _boss.get_attack_state_name() == "IDLE", 90)
	# The player's 0.6 s protection has expired by now; jump just before the
	# next release and stay above the low beam.
	await _wait_physics(45)
	await _place(_boss.global_position.x - 80.0, 320.0, true)
	var hits_after_first: int = _rift.get_player_hits()
	_boss.debug_force_sweep()
	await _wait_physics(38)
	Input.action_press(&"jump")
	await _wait_physics(2)
	Input.action_release(&"jump")
	var sweep_two: bool = await _wait_until(
		func() -> bool: return _boss.get_sweep_count() > 1, 60
	)
	await _wait_physics(4)
	_check(sweep_two, "the second sweep releases while the player is airborne")
	_check(_rift.get_player_hits() == hits_after_first,
		"jumping clears the low mirror sweep",
		"hits=%d y=%.1f" % [_rift.get_player_hits(), _player.global_position.y])
	await _wait_until(func() -> bool: return _boss.get_attack_state_name() == "IDLE", 90)

	# --- summon ----------------------------------------------------------
	var summon_draws_before: int = _boss.get_summon_draw_count()
	_boss.debug_force_summon()
	var summon_cast: bool = await _wait_until(
		func() -> bool: return _boss.get_attack_state_name() == "SUMMON_CAST", 30
	)
	_check(summon_cast, "the summon has its own cast state")
	var summoned: bool = await _wait_until(
		func() -> bool: return _boss.get_summon_count() > 0, 90
	)
	await _wait_physics(6)
	_check(summoned, "the summon resolves")
	_check(_boss.get_summon_draw_count() > summon_draws_before,
		"violet portal rings and chains were really drawn",
		"%d -> %d" % [summon_draws_before, _boss.get_summon_draw_count()])
	_check(_rift.get_boss_wisps().size() == 2,
		"exactly two rift wisps are summoned",
		str(_rift.get_boss_wisps().size()))
	var all_hazard: bool = true
	for wisp: RiftPolarityWisp in _rift.get_boss_wisps():
		if wisp == null or not is_instance_valid(wisp) or not wisp.is_alive() \
				or not wisp.hazard_mode:
			all_hazard = false
	_check(all_hazard, "both summoned wisps use the real hazard-flip mode")
	_check(_boss.get_attack_state_name() == "IDLE" or _boss.get_attack_state_name() == "SUMMON_CAST",
		"summon leaves the boss in a readable state",
		_boss.get_attack_state_name())

	# --- no stale telegraph after the sequence ----------------------------
	await _wait_until(func() -> bool: return _boss.get_attack_state_name() == "IDLE", 120)
	_check(not _boss.is_phase_wave_telegraph_visible()
		and not _boss.is_sweep_telegraph_visible()
		and not _boss.is_phase_wave_release_visible()
		and not _boss.is_sweep_release_visible(),
		"all attack telegraphs are clear in idle")

