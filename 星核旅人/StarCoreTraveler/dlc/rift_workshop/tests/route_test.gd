extends Node

## Headless full-route test for the 2026-11-26 rift-workshop rework 2.
##
##   ... --headless --path . res://dlc/rift_workshop/tests/route_test.tscn
##
## A real-input route: Q is pressed once and denied; the inversion curtain is
## walked through twice to open the gate; the player jumps the terrace step,
## kills each bridge wisp from the previous bank (J) so the decks are permanent,
## crosses all three, records the checkpoint, walks the longer corridor into the
## arena, breaks both face plates with real opposite-phase J and hits the core
## three times in each of three phases, then touches the finish and returns to
## the title.  Only the boss positioning uses a test teleport; every hit is the
## player's real swing window and the boss's real receive_player_hit.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"

var _rift: RiftWorkshop
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []
var _legs: Array[String] = []
var _q_presses: int = 0
var _denied_q: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	Input.action_release(&"jump")
	print("RIFT_ROUTE q_total=%d denied_q=%d legs=%s" % [
		_q_presses, _denied_q, ", ".join(_legs)
	])
	print("RIFT_ROUTE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _jab() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(3)
	_push_key(KEY_J, false)
	await _wait_physics(45)


func _kill_face_anchor(boss: RiftMirrorBoss, positive: bool) -> bool:
	var wisp: RiftPolarityWisp = boss.get_face_anchor(positive)
	if wisp == null or not is_instance_valid(wisp) or not wisp.is_alive():
		return false
	await _place(wisp.global_position.x - 44.0, 320.0, true)
	await _jab()
	return not wisp.is_alive()


func _break_face(boss: RiftMirrorBoss, positive: bool) -> void:
	var face_x: float = boss.get_face_center_global(positive).x
	await _place(face_x - 50.0, 320.0, not positive)
	await _jab()


func _tap_polarity() -> void:
	_q_presses += 1
	Input.action_press(&"polarity")
	await _wait_physics(2)
	Input.action_release(&"polarity")
	await _wait_physics(4)


func _move_until_x(target: float, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	for _index: int in range(max_frames):
		if _player.global_position.x >= target:
			Input.action_release(&"move_right")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	await _wait_physics(2)
	return _player.global_position.x >= target


func _move_left_until_x(target: float, max_frames: int) -> bool:
	Input.action_press(&"move_left")
	for _index: int in range(max_frames):
		if _player.global_position.x <= target:
			Input.action_release(&"move_left")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
	Input.action_release(&"move_left")
	await _wait_physics(2)
	return _player.global_position.x <= target


func _walk_with_auto_jump(target: float, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	var last_x: float = _player.global_position.x
	var stall: int = 0
	for _index: int in range(max_frames):
		if _player.global_position.x >= target:
			Input.action_release(&"move_right")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
		if _player.is_on_floor() and absf(_player.global_position.x - last_x) < 0.15:
			stall += 1
		else:
			stall = 0
		last_x = _player.global_position.x
		if stall >= 6:
			stall = 0
			Input.action_press(&"jump")
			await _wait_physics(1)
			Input.action_release(&"jump")
	Input.action_release(&"move_right")
	await _wait_physics(2)
	return _player.global_position.x >= target


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
	var boss: RiftMirrorBoss = _rift.get_boss()
	for _index: int in range(max_frames):
		if boss.is_active() and boss.get_attack_state_name() != "INTRO":
			return true
		await get_tree().physics_frame
	return false


func _cleanup() -> void:
	await _wait_process(2)
	# The route ends on the level_01 title screen, whose title BGM is a new
	# 2026-11-27 hand-off.  Release that scene (and its audio player) before
	# quitting so the engine does not report a false resource-leak ERROR during
	# teardown.  This changes no gameplay state and no assertion.
	var current: Node = get_tree().current_scene
	if current != null and current != _rift:
		var menu: Node = current.get_node_or_null("StartMenu")
		if menu != null and menu.has_method("stop_title_music_for_test"):
			menu.call("stop_title_music_for_test")
		get_tree().current_scene = null
		current.queue_free()
		await _wait_process(20)
	get_tree().current_scene = null
	if _rift != null and is_instance_valid(_rift):
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
	await _wait_process(3)
	await _wait_physics(8)
	_player = _rift.get_player()
	_check(_player != null, "chapter exposes an L3Player")
	if _player == null:
		return
	_check(_player.is_positive(), "spawn is 辉相")
	_check(_player.allow_polarity_toggle == false, "Q is locked on the real route")

	# Q is refused at the start; the phase cannot change.
	await _tap_polarity()
	_denied_q = _rift.get_q_denial_count()
	_check(_denied_q >= 1 and _player.is_positive(),
		"Q is denied at the start without a phase change", str(_denied_q))

	# --- room 1: curtain, delivered star core, then the gate ------------
	var gate: PolarityGate = _rift.get_gate_moon()
	var carrier: CoreDeliveryCarrier = _rift.get_core_carrier()
	var bay: CoreDeliveryBay = _rift.get_core_bay()
	_check(carrier != null and bay != null and gate != null,
		"the route scene exposes the star core, bay and GateMoon")
	if carrier == null or bay == null or gate == null:
		return
	var reached: bool = await _walk_with_auto_jump(255.0, 1200)
	_legs.append("gate_approach(255)=%.1f" % _player.global_position.x)
	_check(reached, "real walk reaches the first gate",
		"x=%.2f" % _player.global_position.x)
	_check(_rift.get_field_a().get_trigger_count() == 1 and not _player.is_positive(),
		"the first curtain pass turns 澜相",
		"triggers=%d positive=%s" % [
			_rift.get_field_a().get_trigger_count(), str(_player.is_positive())
		])
	var core_seated: bool = await _wait_until(
		func() -> bool: return carrier.is_on_socket(), 180
	)
	_check(core_seated and bay.is_lit() and not gate.is_blocking(),
		"the 澜相 field delivers the star core and powers GateMoon open",
		"core=%.1f glow=%.1f layer=%d" % [
			carrier.global_position.x, bay.get_glow_strength(),
			gate.get_collision_layer()
		])
	_check(_rift.get_hud().get_event_text().contains("星核入仓")
		and _rift.get_hud().get_event_text().contains("第一道门"),
		"the route HUD line names the star core and the first gate",
		_rift.get_hud().get_event_text())
	var through_gate: bool = await _move_until_x(300.0, 400)
	_legs.append("gate_pass(300)=%.1f" % _player.global_position.x)
	_check(through_gate and not gate.is_blocking() and carrier.is_on_socket(),
		"the powered gate lets the real route through and the bay holds the core",
		"x=%.2f core=%.1f" % [
			_player.global_position.x, carrier.global_position.x
		])

	# --- room 2: bridge head, kill each deck wisp -----------------------
	reached = await _walk_with_auto_jump(682.0, 900)
	await _wait_until(func() -> bool: return _player.is_on_floor(), 120)
	_legs.append("bridge_head(682)=%.1f/%.1f" % [
		_player.global_position.x, _player.global_position.y
	])
	_check(reached and absf(_player.global_position.y - 280.0) < 2.0
		and not _player.is_positive(),
		"real jump reaches the raised bridge terrace in 澜相",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])
	var bridge_a: RiftPhaseBridge = _rift.get_bridge_a()
	var bridge_b: RiftPhaseBridge = _rift.get_bridge_b()
	var bridge_c: RiftPhaseBridge = _rift.get_bridge_c()
	var wisp_a: RiftPolarityWisp = _rift.get_wisps()[0]
	var wisp_c: RiftPolarityWisp = _rift.get_wisps()[2]
	var wisp_e: RiftPolarityWisp = _rift.get_wisps()[4]
	_check(not bridge_a.is_solid(),
		"BridgeA is ghosted for the arriving 澜相; the kill is the Q-less key")
	await _jab()
	_check(not wisp_a.is_alive() and bridge_a.is_stabilized(),
		"J kills the BridgeA wisp and makes the deck permanent")
	var cross_a: bool = await _move_until_x(764.0, 500)
	_legs.append("bridge1(764)=%.1f/%.1f" % [
		_player.global_position.x, _player.global_position.y
	])
	_check(cross_a and absf(_player.global_position.y - 280.0) < 2.0,
		"walked across BridgeA to LandingA",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])
	# Kill BridgeB's wisp from the landing edge, then cross the permanent deck.
	await _move_until_x(800.0, 200)
	await _jab()
	_check(not wisp_c.is_alive() and bridge_b.is_stabilized(),
		"J kills the BridgeB wisp from LandingA")
	var cross_b: bool = await _move_until_x(876.0, 500)
	_legs.append("bridge2(876)=%.1f/%.1f" % [
		_player.global_position.x, _player.global_position.y
	])
	_check(cross_b and absf(_player.global_position.y - 280.0) < 2.0,
		"walked across BridgeB to LandingB",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])
	await _move_until_x(912.0, 200)
	await _jab()
	_check(not wisp_e.is_alive() and bridge_c.is_stabilized(),
		"J kills the BridgeC wisp from LandingB")
	var cross_c: bool = await _move_until_x(1000.0, 500)
	_legs.append("bridge3(1000)=%.1f/%.1f" % [
		_player.global_position.x, _player.global_position.y
	])
	_check(cross_c and absf(_player.global_position.y - 280.0) < 2.0,
		"walked across BridgeC to the end terrace",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])

	# --- checkpoint and the longer corridor -----------------------------
	var checkpoint_reached: bool = await _move_until_x(1040.0, 500)
	_legs.append("checkpoint(1040)=%.1f" % _player.global_position.x)
	_check(checkpoint_reached and _rift.is_checkpoint_active(),
		"walking over the marker records the checkpoint")
	var arena_walk: bool = await _move_until_x(1256.0, 900)
	_legs.append("arena(1256)=%.1f/%.1f" % [
		_player.global_position.x, _player.global_position.y
	])
	_check(arena_walk and _rift.is_arena_entered(),
		"the longer corridor reaches the mirror arena",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])
	_check(absf(_player.global_position.y - 320.0) < 4.0,
		"the arena floor sits 40 px below the bridge terrace",
		"y=%.2f" % _player.global_position.y)
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	await _wait_process(2)
	await _close_popup_if_open()
	var boss_active: bool = await _wait_for_boss_active()
	_check(boss_active, "the mirror becomes active after the opening")
	var boss: RiftMirrorBoss = _rift.get_boss()
	boss.set_attacks_enabled(false)
	_check(_rift.get_hud().is_boss_visible(), "boss HUD row is visible")
	_check(_rift.get_hud().get_boss_status().get_core_hp() == 3,
		"boss starts on core 3/3")

	# --- three real-hit forms -------------------------------------------
	for phase: int in range(3):
		_check(boss.get_phase_number() == phase + 1,
			"form %d begins" % (phase + 1), str(boss.get_phase_number()))
		if phase > 0:
			var anchored: bool = await _wait_until(
				func() -> bool: return boss.get_alive_anchor_count() == 2, 180
			)
			_check(anchored, "form %d summons two plate anchors" % (phase + 1),
				str(boss.get_alive_anchor_count()))
			await _kill_face_anchor(boss, true)
			await _kill_face_anchor(boss, false)
			_check(boss.get_alive_anchor_count() == 0,
				"both anchors die to real J in form %d" % (phase + 1))
		await _break_face(boss, true)
		_check(not boss.is_face_intact(true), "gold plate shattered in form %d" % (phase + 1))
		await _break_face(boss, false)
		_check(not boss.is_face_intact(false), "cyan plate shattered in form %d" % (phase + 1))
		_check(boss.is_core_exposed(), "core exposed in form %d" % (phase + 1))
		for _hit: int in range(3):
			await _place(boss.global_position.x - 20.0, 320.0, true)
			await _jab()
		_check(boss.get_core_hp() == 0, "core cleared in form %d" % (phase + 1))
		if phase < 1:
			var advanced: bool = await _wait_until(
				func() -> bool: return boss.get_phase_number() == phase + 2, 180
			)
			_check(advanced, "form %d transition completes" % (phase + 1))
			_check(boss.get_intact_face_count() == 2 and boss.get_core_hp() == 3,
				"form %d restores plates and core" % (phase + 2))
		elif phase == 1:
			var advanced_three: bool = await _wait_until(
				func() -> bool: return boss.get_phase_number() == 3, 240
			)
			_check(advanced_three, "form 2 transition completes")
			_check(boss.get_intact_face_count() == 2 and boss.get_core_hp() == 3,
				"form 3 restores plates and core")
	var boss_down: bool = await _wait_until(
		func() -> bool: return boss.is_collapsing(), 240
	)
	_check(boss_down, "three forms collapse the mirror")
	var defeat_finished: bool = await _wait_until(
		func() -> bool: return _rift.is_boss_defeated(), 240
	)
	_check(defeat_finished, "the collapse finishes and the finish opens")
	_check(_rift.get_finish_sprite().modulate.r > 0.9,
		"finish core lights after the mirror falls")
	var core_tip: bool = await _wait_until(
		func() -> bool:
			var popup: MechanicPopup = _rift.get_mechanic_popup()
			return popup.is_open() and popup.get_current_id() == "rift_core_tip",
		180
	)
	_check(core_tip, "boss defeat opens the core tip")
	if core_tip:
		await _close_popup_if_open()

	# --- finish / completion / title ------------------------------------
	await _place(1848.0, 320.0, true)
	var completed: bool = await _wait_until(
		func() -> bool: return _rift.is_completed(), 120
	)
	_check(completed, "walking into the finish closes the rift")
	_check(_rift.get_hud().is_completion_visible(), "completion page is visible")
	var completion_text: String = _rift.get_hud().get_completion_text()
	var expression: RegEx = RegEx.new()
	expression.compile("^裂隙封闭 · 用时 [0-9]{2}:[0-9]{2}$")
	_check(expression.search(completion_text) != null,
		"completion text is 裂隙封闭 · 用时 mm:ss", completion_text)
	print("RIFT_ROUTE_COMPLETION_TEXT %s" % completion_text)
	_push_key(KEY_E, true)
	await _wait_physics(2)
	_push_key(KEY_E, false)
	var changed: bool = await _wait_until(
		func() -> bool:
			return get_tree().current_scene != null \
				and get_tree().current_scene != _rift, 180
	)
	await _wait_process(6)
	var current_path: String = ""
	if get_tree().current_scene != null:
		current_path = get_tree().current_scene.scene_file_path
	_check(changed and current_path == LEVEL_01,
		"E returns to level_01.tscn title", current_path)
	if get_tree().current_scene != null:
		_check(get_tree().current_scene.has_node("StartMenu"),
			"returned scene contains the title menu")
