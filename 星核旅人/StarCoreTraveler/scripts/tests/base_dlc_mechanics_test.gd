extends Node

## Headless acceptance for the two base-story DLC mechanics.
##
## L1: the exit-side PolarityGate teaches on a 56 px approach, rejects the wrong
## phase, opens for the matching phase, never locks Q, and cannot block the
## checkpoint.
## L2: the removed entry inversion field really is absent, and the first linked
## bay remains solvable with the real E / core / rune-link APIs.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://scripts/tests/base_dlc_mechanics_test.tscn

const L1_SCENE: String = "res://scenes/level_01.tscn"
const L2_SCENE: String = "res://scenes/level_02.tscn"
const L1_GATE_FULL_TEXT: String = "同相门只认同相 · 看门上日/月 · 按换相键"
const L1_GATE_SHORT_TEXT: String = "按换相键"
## The shared mechanic progress would suppress the first-encounter lesson after
## any earlier run; this test uses a throwaway file so the lesson is real.
const TEST_MECH_PROGRESS: String = "user://test_base_mechanics.cfg"

var _checks: int = 0
var _failures: Array[String] = []
var _l1: Node = null
var _l2: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	MechanicTips.reset_for_test()
	if FileAccess.file_exists(TEST_MECH_PROGRESS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_MECH_PROGRESS))
	MechanicTeach.set_progress_path_override(TEST_MECH_PROGRESS)
	await _test_l1()
	await _test_l2()
	MechanicTeach.clear_progress_path_override()
	# Give the audio thread and queued frees a few frames to settle; this is
	# teardown only and does not change any assertion.
	await _wait_process(20)
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"jump")
	Input.action_release(&"polarity")
	Input.action_release(&"interact")
	print("BASE_DLC_MECHANICS_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


func _tap_polarity(player: PrototypePlayer) -> void:
	Input.action_press(&"polarity")
	await _wait_physics(1)
	Input.action_release(&"polarity")
	await _wait_physics(4)


func _hold_right_until_x(player: PrototypePlayer, target: float, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	for _index: int in range(max_frames):
		if player.global_position.x >= target:
			Input.action_release(&"move_right")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	await _wait_physics(2)
	return player.global_position.x >= target


func _press_interact() -> void:
	Input.action_press(&"interact")
	await _wait_physics(2)
	Input.action_release(&"interact")
	await _wait_physics(2)


func _unload(level: Node) -> void:
	if level != null and is_instance_valid(level):
		get_tree().current_scene = null
		level.queue_free()
	await _wait_process(20)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(4)


# --- L1: exit-side same-phase gate -----------------------------------------

func _test_l1() -> void:
	MechanicTips.mark_seen("polarity")
	var packed: PackedScene = load(L1_SCENE) as PackedScene
	_check(packed != null, "L1 scene loads", L1_SCENE)
	if packed == null:
		return
	_l1 = packed.instantiate()
	_l1.set("enable_start_menu", false)
	get_tree().root.add_child(_l1)
	get_tree().current_scene = _l1
	await _wait_process(6)
	var opening: Node = _l1.call("get_opening") as Node
	if opening != null and bool(opening.call("is_active")):
		opening.call("abort")
	await _wait_process(4)
	get_tree().paused = false

	var player: PrototypePlayer = _l1.call("get_player") as PrototypePlayer
	var gate: PolarityGate = _l1.call("get_exit_polarity_gate") as PolarityGate
	var checkpoint: LevelCheckpoint = _l1.call("get_checkpoint") as LevelCheckpoint
	var exit: LevelExit = _l1.call("get_exit") as LevelExit
	var hud: Level01HUD = _l1.call("get_hud") as Level01HUD
	_check(
		player != null and gate != null and checkpoint != null and exit != null and hud != null,
		"L1 exposes player, exit gate, checkpoint, exit and HUD"
	)
	if player == null or gate == null or checkpoint == null or exit == null or hud == null:
		await _unload(_l1)
		_l1 = null
		return

	var exit_rect: Rect2 = Rect2(
		exit.global_position + exit.get_trigger_rect().position,
		exit.get_trigger_rect().size
	)
	var cp_rect: Rect2 = Rect2(
		checkpoint.global_position + checkpoint.get_trigger_rect().position,
		checkpoint.get_trigger_rect().size
	)
	var gate_rect: Rect2 = gate.get_gate_rect()
	_check(gate.global_position.x < exit.global_position.x, "gate stands before Exit",
		"gate=%.0f exit=%.0f" % [gate.global_position.x, exit.global_position.x])
	_check(gate_rect.end.x < exit_rect.position.x, "gate does not enclose the Exit trigger",
		"gate_end=%.0f exit_start=%.0f" % [gate_rect.end.x, exit_rect.position.x])
	_check(not gate_rect.intersects(cp_rect), "gate cannot block the checkpoint trigger")
	_check(not gate.get_required_positive(), "gate requires the moon 澜相")
	_check(gate.get_emblem_kind() == "moon", "gate carries the moon emblem")
	_check(player.is_positive(), "L1 starts in the sun 辉相")
	var gate_stele: GuideEcho = _l1.call("get_gate_stele") as GuideEcho
	var stele_text: String = String(gate_stele.pages[0]) if gate_stele != null \
		and gate_stele.pages.size() > 0 else "missing"
	_check(gate_stele != null and gate_stele.get_page_count() == 1
		and stele_text.contains("同相门只认同相"),
		"the stele before the gate repeats the same lesson", stele_text)

	# Spawn is far from the door: one second of standing must stay silent.
	await _wait_seconds(1.0)
	_check(int(_l1.call("get_exit_gate_full_hint_count")) == 0
		and String(hud.call("get_toast_text")).is_empty(),
		"L1 spawn shows no gate hint",
		String(hud.call("get_toast_text")))

	# 60 px is still outside the 56 px approach window.
	player.global_position = Vector2(gate.global_position.x - 60.0, 300.0)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(true)
	player.set_facing_direction(1)
	await _wait_physics(4)
	await _wait_seconds(1.0)
	_check(gate.is_blocking(), "gate starts solid for the wrong phase")
	_check(int(_l1.call("get_exit_gate_full_hint_count")) == 0,
		"60 px before the gate still shows no full hint",
		String(hud.call("get_toast_text")))

	# At 56 px but facing away, the gate stays silent; turning toward it fires
	# the one-time full lesson before any contact.
	player.global_position = Vector2(gate.global_position.x - 56.0, 300.0)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(true)
	player.set_facing_direction(-1)
	await _wait_physics(3)
	await _wait_seconds(0.2)
	_check(gate.get_deny_count() == 0
		and int(_l1.call("get_exit_gate_full_hint_count")) == 0,
		"56 px while facing away shows no gate hint",
		String(hud.call("get_toast_text")))
	player.set_facing_direction(1)
	await _wait_physics(3)
	await _wait_seconds(0.2)
	_check(gate.get_deny_count() == 0,
		"the 56 px sample is taken before the gate contact",
		"x=%.2f" % player.global_position.x)
	_check(int(_l1.call("get_exit_gate_full_hint_count")) == 1,
		"the full gate lesson fires at 56 px",
		String(hud.call("get_toast_text")))
	_check(String(hud.call("get_toast_text")) == L1_GATE_FULL_TEXT,
		"L1 teaches same-phase / sun-moon / Q in one line",
		String(hud.call("get_toast_text")))
	_check(bool(hud.call("is_toast_visible")), "the full gate hint is visible")

	# Wrong phase: real contact is rejected and keeps the body outside.  Contact
	# replaces the full lesson with only the short Q reminder.
	var full_before_contact: int = int(_l1.call("get_exit_gate_full_hint_count"))
	var deny_before: int = gate.get_deny_count()
	Input.action_press(&"move_right")
	var denied: bool = false
	for _index: int in range(90):
		await get_tree().physics_frame
		if gate.get_deny_count() > deny_before:
			denied = true
			break
	Input.action_release(&"move_right")
	await _wait_physics(3)
	_check(denied, "wrong-phase contact raises the gate deny event")
	_check(player.global_position.x <= gate.global_position.x - 6.0,
		"wrong-phase player is stopped before the gate band",
		"x=%.2f" % player.global_position.x)
	_check(gate.is_blocking(), "gate remains blocked after the rejected push")
	_check(gate.get_collision_layer() == 1, "gate stays solid after the rejected push")
	_check(int(_l1.call("get_exit_gate_full_hint_count")) == full_before_contact,
		"contact does not repeat the full lesson")
	_check(int(_l1.call("get_exit_gate_short_hint_count")) == 1,
		"contact leaves exactly one short reminder",
		str(_l1.call("get_exit_gate_short_hint_count")))
	_check(String(hud.call("get_toast_text")) == L1_GATE_SHORT_TEXT,
		"the short contact reminder is only 按换相键",
		String(hud.call("get_toast_text")))
	_check(bool(hud.call("is_toast_visible")), "the short reminder is visible")

	# A normal jump apex is 64 px; the gate is 88 px tall.  Repeated jumps while
	# pushing right must not bypass the band either.
	Input.action_press(&"move_right")
	for index: int in range(120):
		if index % 20 == 0:
			Input.action_press(&"jump")
		elif index % 20 == 2:
			Input.action_release(&"jump")
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	await _wait_physics(4)
	_check(player.global_position.x <= gate.global_position.x - 6.0,
		"wrong-phase player cannot jump over the gate",
		"x=%.2f" % player.global_position.x)

	# Leave 200 px, come straight back: the same full line is still inside its
	# 10 s cooldown and must not repeat.
	var full_before_reapproach: int = int(_l1.call("get_exit_gate_full_hint_count"))
	player.global_position = Vector2(gate.global_position.x - 240.0, 300.0)
	player.velocity = Vector2.ZERO
	player.set_facing_direction(1)
	await _wait_physics(4)
	player.global_position = Vector2(gate.global_position.x - 56.0, 300.0)
	player.velocity = Vector2.ZERO
	player.set_facing_direction(1)
	await _wait_physics(3)
	await _wait_seconds(0.2)
	_check(int(_l1.call("get_exit_gate_full_hint_count")) == full_before_reapproach,
		"the same full hint does not repeat within 10 s",
		str(_l1.call("get_exit_gate_full_hint_count")))

	# Matching phase: Q opens the gate without injecting movement or a scripted flip.
	var toggles_before: int = player.get_polarity_toggle_count()
	await _tap_polarity(player)
	_check(not player.is_positive(), "Q toggles L1 player to 澜相")
	_check(player.get_polarity_toggle_count() == toggles_before + 1,
		"Q still owns the toggle counter", str(player.get_polarity_toggle_count()))
	_check(gate.is_open(), "matching phase opens the gate")
	_check(gate.get_collision_layer() == 0, "matching-phase gate blocker is on layer 0",
		str(gate.get_collision_layer()))
	var passed: bool = await _hold_right_until_x(player, gate.global_position.x + 20.0, 90)
	_check(passed and player.global_position.x > gate.global_position.x + 10.0,
		"matching-phase player walks through the gate",
		"x=%.2f" % player.global_position.x)

	# Q must always return the player, including after the gate.
	await _tap_polarity(player)
	_check(player.is_positive(), "Q flips the player back after passing")
	_check(gate.is_blocking(), "gate re-closes for the returned wrong phase")
	await _tap_polarity(player)
	_check(not player.is_positive() and gate.is_open(),
		"Q can match the gate again with no soft lock")

	# The gate is far from the checkpoint; the checkpoint still triggers.
	checkpoint.set_activated(false)
	player.global_position = checkpoint.global_position
	player.velocity = Vector2.ZERO
	await _wait_physics(8)
	_check(checkpoint.is_activated(), "checkpoint still triggers with the gate present")

	await _unload(_l1)
	_l1 = null


# --- L2: entry inversion curtain -------------------------------------------

func _test_l2() -> void:
	MechanicTips.mark_seen("core_carry")
	MechanicTips.mark_seen("relay_link")
	var packed: PackedScene = load(L2_SCENE) as PackedScene
	_check(packed != null, "L2 scene loads", L2_SCENE)
	if packed == null:
		return
	_l2 = packed.instantiate()
	get_tree().root.add_child(_l2)
	get_tree().current_scene = _l2
	await _wait_process(6)
	await _wait_physics(8)
	get_tree().paused = false

	var player: PrototypePlayer = _l2.call("get_player") as PrototypePlayer
	var linked: StarCoreBayInteractable = _l2.call("get_linked_bay") as StarCoreBayInteractable
	var hud: Level02HUD = _l2.call("get_hud") as Level02HUD
	var bays: Array = _l2.call("get_bays")
	var camera: Camera2D = _l2.call("get_camera") as Camera2D
	var start_bay: StarCoreBayInteractable = null
	if not bays.is_empty():
		start_bay = bays[0] as StarCoreBayInteractable
	_check(
		player != null and linked != null and hud != null and start_bay != null,
		"L2 exposes player, linked bay, start bay and HUD"
	)
	if player == null or linked == null or hud == null or start_bay == null:
		await _unload(_l2)
		_l2 = null
		return

	# The old violet entry curtain is gone in this chapter; only DLC2 keeps its
	# inversion field.  No node, no script wiring and no prompt may remain here.
	_check(_l2.get_node_or_null("InversionField") == null,
		"L2 scene has no InversionField")
	_check(_l2.find_children("*", "RiftInversionField", true, false).is_empty(),
		"L2 scene contains no RiftInversionField instance")
	_check(player.is_positive(), "L2 starts in 辉相")
	_check(player.allow_polarity_toggle, "Q remains available in L2")

	# First linked bay: release from StartBay, then store in LinkedBay with real E.
	var core: StarCoreCarrier = _l2.call("get_core") as StarCoreCarrier
	_check(core != null and not core.is_active(), "the core starts locked in StartBay")
	if core == null:
		await _unload(_l2)
		_l2 = null
		return
	player.global_position = Vector2(start_bay.global_position.x, 320.0)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(true)
	await _wait_physics(4)
	await _press_interact()
	var released: bool = await _wait_until(func() -> bool: return core.is_active(), 120)
	_check(released, "real E releases the core from StartBay")
	if not released:
		await _unload(_l2)
		_l2 = null
		return
	var core_positive: bool = core.is_positive()
	_check(not core_positive, "released core takes the opposite phase")

	core.global_position = linked.get_store_center()
	player.global_position = Vector2(linked.global_position.x - 40.0, 320.0)
	player.velocity = Vector2.ZERO
	if camera != null:
		camera.reset_smoothing()
	await _wait_physics(3)
	await _press_interact()
	var stored: bool = await _wait_until(func() -> bool: return linked.is_locked(), 120)
	_check(stored, "the linked bay accepts the transported core")
	_check(linked.has_record(), "first linked bay records the core phase")
	_check(linked.get_recorded_positive() == core_positive,
		"first linked bay keeps the core's own phase")
	_check(int(_l2.call("get_stable_stage")) == 2,
		"storing the first linked bay advances the stable stage",
		str(_l2.call("get_stable_stage")))
	var link: BayRuneLink = _l2.call("get_link") as BayRuneLink
	_check(link != null, "L2 exposes its bay-rune link")
	if link != null:
		var link_lit: bool = await _wait_until(
			func() -> bool: return link.is_field_activated(), 240
		)
		_check(link_lit, "the linked bay still lights its rune field")
		_check(link.get_field_positive() == linked.get_recorded_positive(),
			"the rune field commits the recorded core phase")

	await _unload(_l2)
	_l2 = null
