extends Node

## Feedback polish test for the 2026-11-26 rift-workshop rework 2.
##
##   ... --headless --path . res://dlc/rift_workshop/tests/polish_test.tscn
##
## Covers the boss event lines and their audio, the boss status row state, the
## Q refusal not writing a text line, and the proximity wisp hum staying off
## through the recovery black-out and returning at the bridge head.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _checks: int = 0
var _failures: Array[String] = []
var _rift: RiftWorkshop = null
var _player: L3Player = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("RIFT_POLISH_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_ms(duration_ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
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


func _jab() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(3)
	_push_key(KEY_J, false)
	await _wait_physics(45)


func _close_popup_if_open() -> bool:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return false
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)
	return not popup.is_open()


func _cleanup() -> void:
	get_tree().paused = false
	get_tree().current_scene = null
	if _rift != null and is_instance_valid(_rift):
		_rift.queue_free()
	await _wait_process(20)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


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
	await _wait_process(3)
	await _wait_physics(8)
	_player = _rift.get_player()
	var hud: RiftWorkshopHUD = _rift.get_hud()
	var audio: Node = _rift.get_node("Audio")
	var boss: RiftMirrorBoss = _rift.get_boss()

	# Q refusal is icon/audio only; no event line.
	Input.action_press(&"polarity")
	await _wait_physics(2)
	Input.action_release(&"polarity")
	await _wait_physics(3)
	_check(int(audio.call("get_deny_play_count")) == 1,
		"Q refusal plays the deny cue")
	_check(hud.get_event_text() == "",
		"Q refusal writes no text line", hud.get_event_text())
	_check(hud.is_q_denied_visible(), "Q refusal shows the icon")

	# Wisp hum: near, off during recovery, back at the bridge head.  This runs
	# before the arena so a fall still resolves to the bridge-head reset.
	await _place(700.0, 280.0, true)
	await _wait_process(12)
	var wisp: RiftPolarityWisp = _rift.get_wisps()[0]
	_check(wisp.is_hum_playing(), "near wisp hum is audible while playing")
	_player.global_position = Vector2(700.0, 540.0)
	_player.velocity = Vector2.ZERO
	var fell: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 2000
	)
	await _wait_process(5)
	_check(fell, "falling starts the recovery fade")
	_check(not wisp.is_hum_playing(), "wisp hum stays off during the recovery fade")
	await _wait_ms(300)
	_check(not wisp.is_hum_playing(), "wisp hum is still off later in the fade")
	var recovered: bool = await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 3000
	)
	_check(recovered, "recovery fade finishes")
	_check(absf(_player.global_position.x - 600.0) < 3.0,
		"player is back at the bridge head", "x=%.2f" % _player.global_position.x)
	await _wait_process(12)
	_check(wisp.is_hum_playing(), "near wisp hum returns after the recovery")

	# Enter the arena and close the mirror tip.
	await _place(1250.0, 320.0, true)
	await _wait_until(func() -> bool: return _rift.is_arena_entered(), 90)
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	await _wait_process(2)
	await _close_popup_if_open()
	await _wait_until(
		func() -> bool:
			return boss.is_active() and boss.get_attack_state_name() != "INTRO", 240
	)
	boss.set_attacks_enabled(false)
	_check(hud.is_boss_visible(), "boss status row is visible")
	_check(hud.get_boss_status().get_core_hp() == 3,
		"boss status starts on core 3/3")

	# Face shatter lines and audio.
	var shatter_before: int = int(DemoAudio.get_play_count("shell_shatter"))
	boss.debug_shatter_face(true)
	await _wait_physics(3)
	_check(hud.get_event_text() == "金面盘碎裂 · 还差一面",
		"gold shatter event keeps the remaining-plate count",
		hud.get_event_text())
	_check(int(DemoAudio.get_play_count("shell_shatter")) == shatter_before + 1,
		"gold shatter plays the shell cue")
	_check(hud.get_boss_status().is_gold_intact() == false
		and hud.get_boss_status().is_cyan_intact(),
		"boss status row shows one broken plate")
	boss.debug_shatter_face(false)
	await _wait_physics(3)
	_check(hud.get_event_text() == "两面盘已碎 · 中央核心暴露",
		"second shatter settles on the exposed-core line", hud.get_event_text())
	_check(hud.get_boss_status().is_core_exposed(),
		"boss status row shows the exposed core")

	# Core hit line and audio.
	var core_before: int = int(DemoAudio.get_play_count("core_take"))
	await _place(boss.global_position.x - 20.0, 320.0, true)
	await _jab()
	_check(boss.get_core_hp() == 2, "a core hit removes one core cell",
		str(boss.get_core_hp()))
	_check(hud.get_event_text() == "核心命中 · 还剩 2 次",
		"core hit line keeps the remaining count", hud.get_event_text())
	_check(int(DemoAudio.get_play_count("core_take")) == core_before + 1,
		"core hit plays the core-take cue")

	# Collapse line, then the delayed defeat / finish marker.
	boss.debug_force_defeat()
	await _wait_physics(4)
	_check(boss.is_collapsing(), "boss collapse starts")
	_check(not _rift.is_boss_defeated(),
		"chapter defeat waits for the collapse to finish")
	_check(hud.get_event_text() == "双面镜崩塌 · 面盘碎裂 · 核心内爆",
		"collapse line names the broken plates and imploding core",
		hud.get_event_text())
	_check(_rift.get_finish_sprite().modulate.r < 0.9,
		"finish core stays dim during the collapse")
	var collapse_done: bool = await _wait_until(
		func() -> bool: return _rift.is_boss_defeated(), 160
	)
	_check(collapse_done, "boss defeat registers after the collapse")
	_check(hud.get_event_text() == "双面镜碎裂 · 裂隙核心开启",
		"defeat line names the mirror and the core", hud.get_event_text())
	_check(_rift.get_finish_sprite().modulate.r > 0.9,
		"finish core lights up after the collapse")
	_check(hud.get_boss_status().get_core_hp() == 2,
		"status keeps the last core count on defeat (debug defeat does not fake hits)",
		str(hud.get_boss_status().get_core_hp()))
	var core_tip: bool = await _wait_until(
		func() -> bool:
			var popup: MechanicPopup = _rift.get_mechanic_popup()
			return popup.is_open() and popup.get_current_id() == "rift_core_tip",
		180
	)
	_check(core_tip, "boss defeat opens the core tip")
	if core_tip:
		await _close_popup_if_open()
