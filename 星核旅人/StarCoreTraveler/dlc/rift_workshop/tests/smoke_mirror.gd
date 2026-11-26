extends Node

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _rift: RiftWorkshop
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	print("SMOKE checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	print(("PASS: " if condition else "FAIL: ") + label + ("" if detail.is_empty() else " [" + detail + "]"))
	if not condition:
		_failures.append(label)


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _jab() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(3)
	_push_key(KEY_J, false)
	await _wait_physics(45)


func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(4)
	await _wait_physics(10)
	_player = _rift.get_player()
	_check(_player != null, "player")
	_check(_player.allow_polarity_toggle == false, "Q locked")
	_check(_rift.get_node_or_null("GuardGold") == null, "no old guards")
	_check(_rift.get_hud().has_element_legend() == false, "no legend")
	_check(_rift.get_hud().get_phase_icon().size == Vector2(20, 20), "20 icon")
	_check(_rift.get_boss() != null, "boss exists")
	_check(_rift.get_crystal_left() != null, "crystal left")
	_check(_rift.get_crystal_right() != null, "crystal right")
	_check(_rift.get_boss().get_phase_number() == 1
		and _rift.get_boss().get_core_hp() == 3
		and _rift.get_boss().get_intact_face_count() == 2, "boss initial state")

	# Q denial.
	var before: bool = _player.is_positive()
	Input.action_press(&"polarity")
	await _wait_physics(2)
	Input.action_release(&"polarity")
	await _wait_physics(3)
	_check(_player.is_positive() == before, "Q does not flip")
	_check(_rift.get_hud().is_q_denied_visible(), "Q denied icon")
	_check(int(_rift.get_node("Audio").call("get_deny_play_count")) == 1, "Q deny sound")

	# Crystal.
	await _place(1320.0, 320.0, true)
	await _wait_physics(3)
	_check(not _player.is_positive(), "crystal flips", str(_player.is_positive()))
	_check(_rift.get_crystal_left().get_cooldown_left() > 1.8, "crystal cooldown")
	await _place(1300.0, 320.0, not _player.is_positive())
	await _wait_physics(2)
	_check(_rift.get_crystal_left().get_flip_count() == 1, "crystal one flip")
	await _place(1400.0, 320.0, true)
	await _wait_physics(3)

	# Enter arena.
	await _place(1250.0, 320.0, true)
	await _wait_physics(6)
	_check(_rift.is_arena_entered(), "arena entered")
	var boss: RiftMirrorBoss = _rift.get_boss()
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	for _index: int in range(120):
		if popup.is_open():
			break
		await get_tree().physics_frame
	if popup.is_open():
		_push_key(KEY_F, true)
		await _wait_process(2)
		_push_key(KEY_F, false)
		await _wait_process(4)
	_check(not get_tree().paused, "mirror tip closed")
	var woke: bool = false
	for _index: int in range(180):
		if boss.is_active() and boss.get_attack_state_name() != "INTRO":
			woke = true
			break
		await get_tree().physics_frame
	_check(woke, "boss active", boss.get_attack_state_name())
	boss.set_attacks_enabled(false)
	_check(_rift.get_hud().is_boss_visible(), "boss HUD visible")
	_check(_rift.get_hud().get_boss_status().is_gold_intact(), "hud gold")
	_check(_rift.get_hud().get_boss_status().is_cyan_intact(), "hud cyan")

	# Same-phase gold hit: player positive at left face.
	await _place(boss.global_position.x - 58.0, 320.0, true)
	await _jab()
	_check(boss.is_face_intact(true), "same phase does not break gold",
		boss.get_last_result().get("code", ""))
	# Opposite phase gold.
	await _place(boss.global_position.x - 58.0, 320.0, false)
	await _jab()
	_check(not boss.is_face_intact(true), "opposite breaks gold",
		boss.get_last_result().get("code", ""))
	# Opposite phase cyan.
	await _place(boss.global_position.x + 58.0, 320.0, true)
	await _jab()
	_check(not boss.is_face_intact(false), "opposite breaks cyan",
		boss.get_last_result().get("code", ""))
	_check(boss.is_core_exposed(), "core exposed")
	# Core hits.
	await _place(boss.global_position.x - 20.0, 320.0, true)
	for index: int in range(3):
		await _jab()
		print("CORE HIT %d hp=%d result=%s" % [
			index + 1, boss.get_core_hp(), boss.get_last_result().get("code", "")
		])
	_check(boss.get_core_hp() == 0, "core hp 0")
	await _wait_physics(120)
	print("PHASE after clear=%d faces=%d hp=%d state=%s" % [
		boss.get_phase_number(), boss.get_intact_face_count(), boss.get_core_hp(),
		boss.get_attack_state_name()
	])
	_check(boss.get_phase_number() == 2, "phase 2")
	_check(boss.get_intact_face_count() == 2, "faces respawn")
	_check(boss.get_core_hp() == 3, "core reset")

	# Force wave/sweep.
	boss.debug_force_wave()
	var warning: bool = false
	for _index: int in range(80):
		if boss.is_phase_wave_telegraph_visible():
			warning = true
			break
		await get_tree().physics_frame
	_check(warning, "wave warning")
	var flips: int = 0
	var before_phase: bool = _player.is_positive()
	for _index: int in range(120):
		if boss.get_phase_wave_count() > 0:
			flips = 1
			break
		await get_tree().physics_frame
	_check(flips == 1, "wave released")
	print("WAVE player positive before=%s after=%s count=%d" % [
		str(before_phase), str(_player.is_positive()), boss.get_phase_wave_count()
	])

	boss.debug_force_sweep()
	var sweep_warning: bool = false
	for _index: int in range(80):
		if boss.is_sweep_telegraph_visible():
			sweep_warning = true
			break
		await get_tree().physics_frame
	_check(sweep_warning, "sweep warning")
	var hits_before: int = _rift.get_player_hits()
	for _index: int in range(120):
		if boss.get_sweep_count() > 0:
			break
		await get_tree().physics_frame
	await _wait_physics(4)
	print("SWEEP player hits %d -> %d" % [hits_before, _rift.get_player_hits()])
	_check(_rift.get_player_hits() == hits_before + 1, "sweep hits")

	# Summon.
	boss.debug_force_summon()
	for _index: int in range(120):
		if boss.get_summon_count() > 0:
			break
		await get_tree().physics_frame
	await _wait_physics(4)
	_check(_rift.get_boss_wisps().size() >= 2, "at least two wisps present",
		str(_rift.get_boss_wisps().size()))

	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(4)
