extends Node

## Headless assertion test for the restored loom approach mechanics:
##   - the trial PolarityGate blocks a wrong-phase body and passes the matching
##     phase (real movement, real Q);
##   - the reused RuneStoneField moves the delivered **star core** onto the bay
##     (real Q and field sample), lights the bay, opens the second gate, and
##     can be pulled back;
##   - the payload really is the project's animated cyan star core, and the
##     field's old rune-stone sprite never draws over it;
##   - the bay holds the core while the player walks past it;
##   - the base LevelCheckpoint records a spawn and failure returns there;
##   - the checkpoint permanently powers the second gate, so pulling the core
##     back after the checkpoint cannot lock the player out;
##   - R restores the gate/core/bay/checkpoint initial state.
##
##   ... --headless --path . res://dlc/star_loom/tests/gate_test.tscn

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")
const TEST_MECH_PROGRESS: String = "user://test_loom_gate_mechanics.cfg"
const TEST_HINT_PROGRESS: String = "user://test_loom_gate_hints.cfg"

var _loom: StarLoom
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# A run that previously taught the gate must not turn this assertion into a
	# silent no-line case; use a throwaway progress file for this test.
	MechanicTeach.set_progress_path_override(TEST_MECH_PROGRESS)
	_remove_test_progress()
	MechanicTips.mark_seen("loom_fire_tip")
	await _run()
	await _cleanup()
	_release_all()
	_remove_test_progress()
	MechanicTeach.clear_progress_path_override()
	print("STAR_LOOM_GATE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _remove_test_progress() -> void:
	for path: String in [TEST_MECH_PROGRESS, TEST_HINT_PROGRESS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_polarity() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(3)
	Input.action_release(&"polarity")
	await _wait_physics(5)


func _release_all() -> void:
	for action: StringName in [
		&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause",
	]:
		Input.action_release(action)


func _load_loom() -> bool:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		return false
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	_loom.show_intro_cinematic = false
	_loom.hint_progress_path = TEST_HINT_PROGRESS
	get_tree().root.add_child(_loom)
	get_tree().current_scene = _loom
	await _wait_process(3)
	await _wait_physics(10)
	_player = _loom.get_player()
	# gate_test covers gate/core/checkpoint mechanics, not the one-time
	# checkpoint lesson.  Mark it seen so this run always reaches the checkpoint
	# HUD line without a queued teaching page in front of it.
	if _loom.get_mechanic_teach() != null:
		_loom.get_mechanic_teach().mark_unlocked("checkpoint")
	return _player != null


func _cleanup() -> void:
	get_tree().paused = false
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(20)
	_release_all()


func _walk_right_until(predicate: Callable, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	var reached: bool = await _wait_until(predicate, max_frames)
	Input.action_release(&"move_right")
	await _wait_physics(3)
	return reached


func _walk_left_until(predicate: Callable, max_frames: int) -> bool:
	Input.action_press(&"move_left")
	var reached: bool = await _wait_until(predicate, max_frames)
	Input.action_release(&"move_left")
	await _wait_physics(3)
	return reached


func _run() -> void:
	_check(await _load_loom(), "star_loom scene loads and exposes an L3Player")
	if _player == null:
		return
	var gate_first: PolarityGate = _loom.get_gate_first()
	var gate_second: PolarityGate = _loom.get_gate_second()
	var carrier: CoreDeliveryCarrier = _loom.get_core_carrier()
	var bay: CoreDeliveryBay = _loom.get_core_bay()
	var checkpoint: LevelCheckpoint = _loom.get_checkpoint()
	_check(gate_first != null and gate_second != null and carrier != null
		and bay != null and checkpoint != null,
		"all three restored mechanisms exist in the scene")
	if gate_first == null or gate_second == null or carrier == null \
			or bay == null or checkpoint == null:
		return

	# --- payload identity: a real animated star core, not a rune stone ---
	var core_visual: StarCoreVisual = carrier.get_core_visual()
	_check(core_visual != null,
		"the carrier exposes a StarCoreVisual payload")
	if core_visual != null:
		_check(core_visual.state == StarCoreVisual.CoreState.NEGATIVE,
			"the payload is the cyan NEGATIVE star core for the moon gate")
		_check(carrier.is_using_star_core_art()
			and core_visual.is_using_animated_sheet(),
			"the payload uses the 12-frame star_core sheet")
		_check(core_visual.get_animation_frame_count() == 12,
			"the core sheet really has 12 frames",
			str(core_visual.get_animation_frame_count()))
		_check(core_visual.get_art_texture() != null
			and core_visual.get_art_texture().get_size() == Vector2(16.0, 16.0),
			"the core is the project's 16x16 art",
			str(core_visual.get_art_texture().get_size()))
	_check(carrier.is_rune_stone_visual_hidden(),
		"the field's old 32x32 rune-stone sprite is hidden")
	_check(carrier.get_node_or_null("CollisionShape2D") == null
		and bay.get_node_or_null("CollisionShape2D") == null,
		"the core and bay own no collision body (no pinch / no platform)")
	_check(bay.z_index + bay.get_glass_sprite().z_index
		> carrier.z_index + core_visual.z_index,
		"the bay glass draws in front of the core, so the core is inside it",
		"glass=%d core=%d" % [
			bay.z_index + bay.get_glass_sprite().z_index,
			carrier.z_index + core_visual.z_index
		])

	_check(gate_first.get_emblem_kind() == "sun"
		and gate_first.get_required_positive(),
		"first gate reads the gold sun / 辉相")
	_check(gate_second.get_emblem_kind() == "moon"
		and not gate_second.get_required_positive(),
		"second gate reads the cyan moon / 澜相")
	_check(not gate_first.is_open() and gate_first.get_collision_layer() == 1,
		"both gates start solid for the cyan player")
	_check(not gate_second.is_open() and gate_second.get_collision_layer() == 1,
		"second gate starts solid before the core is seated")
	_check(not carrier.get_field().is_positive()
		and carrier.get_field().is_activated(),
		"the core's force field starts live in 澜相")
	_check(absf(carrier.global_position.x - carrier.get_start_x()) < 0.5,
		"the star core starts at its authored position",
		"x=%.1f" % carrier.global_position.x)
	_check(not bay.is_occupied() and not bay.is_lit()
		and bay.get_glow_strength() == 0.0 and not checkpoint.is_activated(),
		"bay, glow and checkpoint start clear/dark")

	# --- wrong phase blocks, Q opens, real walk passes -------------------
	# Spawn is 114 px from the gate: one second of standing stays silent.
	await _wait_seconds(1.0)
	_check(_loom.get_gate_hint_count() == 0
		and _loom.get_hud().get_event_text().is_empty(),
		"DLC3 spawn shows no gate hint",
		_loom.get_hud().get_event_text())

	# 60 px is still outside the 56 px window.
	var gate_x: float = gate_first.global_position.x
	var at_60: bool = await _walk_right_until(
		func() -> bool: return _player.global_position.x >= gate_x - 60.0,
		220
	)
	_check(at_60 and gate_first.get_deny_count() == 0
		and _loom.get_gate_hint_count() == 0,
		"60 px before the DLC3 gate shows no hint",
		"x=%.1f" % _player.global_position.x)

	# 56 px while facing away stays silent; turning toward the gate fires only
	# the short phase reminder, never the L1 lesson.
	_player.global_position = Vector2(gate_x - 56.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.face_direction(-1)
	await _wait_physics(3)
	await _wait_seconds(0.2)
	_check(_loom.get_gate_hint_count() == 0,
		"56 px while facing away shows no DLC3 hint",
		_loom.get_hud().get_event_text())
	_player.face_direction(1)
	await _wait_physics(3)
	await _wait_seconds(0.2)
	_check(_loom.get_gate_hint_count() == 1,
		"the 56 px approach fires the DLC3 reminder",
		"x=%.1f" % _player.global_position.x)
	_check(_loom.get_hud().get_event_text() == REGISTRY.get_summary("gate"),
		"DLC3 shows the shared registry gate line",
		_loom.get_hud().get_event_text())
	var hint_count_before_contact: int = _loom.get_gate_hint_count()

	var blocked: bool = await _walk_right_until(
		func() -> bool: return gate_first.get_deny_count() > 0,
		220
	)
	_check(blocked, "real walk reaches and touches the closed first gate")
	_check(_player.global_position.x < gate_first.global_position.x - 2.0,
		"wrong-phase body is stopped before the gate",
		"x=%.1f" % _player.global_position.x)
	_check(not gate_first.is_open() and gate_first.get_collision_layer() == 1,
		"wrong phase keeps the gate solid")
	_check(_loom.get_gate_hint_count() == hint_count_before_contact,
		"contact does not repeat the DLC3 reminder",
		str(_loom.get_gate_hint_count()))
	_check(_loom.get_hud().get_event_text().contains("同相门")
		and _loom.get_hud().get_event_text().contains("同相"),
		"the HUD event line names the same-phase rule",
		_loom.get_hud().get_event_text())

	await _tap_polarity()
	_check(_player.is_positive(), "Q switches the body to 辉相")
	_check(gate_first.is_open() and gate_first.get_collision_layer() == 0,
		"matching phase opens the gate and clears its blocker",
		"layer=%d" % gate_first.get_collision_layer())
	var passed_gate: bool = await _walk_right_until(
		func() -> bool: return _player.global_position.x > gate_first.global_position.x + 18.0,
		120
	)
	_check(passed_gate, "matching-phase body really walks through the gate",
		"x=%.1f" % _player.global_position.x)

	# Stop left of the core and switch back to its cyan phase.  The push from
	# the gold body is allowed to settle first.
	var reached_core: bool = await _walk_right_until(
		func() -> bool: return _player.global_position.x >= 200.0,
		160
	)
	_check(reached_core, "the route reaches the star-core delivery section",
		"x=%.1f" % _player.global_position.x)
	await _tap_polarity()
	_check(not _player.is_positive(), "Q returns the body to 澜相")
	_check(_loom.get_hud().get_objective_text().contains("入仓")
		and _loom.get_hud().get_objective_text().contains("第二道月门"),
		"the HUD objective names the star-core bay and the moon gate it powers",
		_loom.get_hud().get_objective_text())

	# --- push the core into the bay -------------------------------------
	_check(not bay.is_lit(),
		"the bay is dark before the core arrives",
		"base=%s" % str(bay.get_base_sprite().modulate))
	var seated: bool = await _wait_until(
		func() -> bool: return carrier.is_on_socket(), 420
	)
	_check(seated, "same-phase push seats the core in the bay",
		"core=%.1f" % carrier.global_position.x)
	_check(bay.is_occupied() and bay.is_lit(),
		"the bay reports and shows the core")
	_check(bay.get_glow_strength() == 1.0 and bay.get_flash_left() > 0.0,
		"seating lights the bay and starts its flash",
		"glow=%.1f flash=%.2f" % [bay.get_glow_strength(), bay.get_flash_left()])
	_check(gate_second.is_open() and gate_second.get_collision_layer() == 0,
		"core in the bay opens the second gate",
		"layer=%d" % gate_second.get_collision_layer())
	await _wait_physics(2)
	_check(_loom.get_hud().get_event_text().contains("青核入仓")
		and _loom.get_hud().get_event_text().contains("第二道月门"),
		"the HUD event line reports the core seating and the door",
		_loom.get_hud().get_event_text())
	_check(core_visual.is_animating(),
		"the seated core keeps spinning/animating inside the bay")

	# --- pull it back, then push it in again ----------------------------
	await _tap_polarity()
	var pulled_off: bool = await _wait_until(
		func() -> bool: return not carrier.is_on_socket(), 240
	)
	_check(pulled_off, "opposite-phase pull moves the core back off the bay",
		"core=%.1f" % carrier.global_position.x)
	_check(not bay.is_occupied() and not bay.is_lit()
		and bay.get_glow_strength() == 0.0,
		"pulling the core out makes the bay dark again")
	_check(not gate_second.is_open() and gate_second.get_collision_layer() == 1,
		"second gate closes again while the core is out",
		"layer=%d" % gate_second.get_collision_layer())
	await _tap_polarity()
	var reseated: bool = await _wait_until(
		func() -> bool: return carrier.is_on_socket(), 420
	)
	_check(reseated, "same-phase push returns the core to the bay",
		"core=%.1f" % carrier.global_position.x)
	_check(bay.is_lit() and gate_second.is_open(),
		"the bay relights and the second gate reopens")

	# --- walk past the core; the bay holds it, then checkpoint ----------
	var crossed_second: bool = await _walk_right_until(
		func() -> bool: return _player.global_position.x > gate_second.global_position.x + 12.0,
		220
	)
	_check(crossed_second, "the body walks through the opened second gate",
		"x=%.1f" % _player.global_position.x)
	_check(carrier.is_on_socket(),
		"walking past the core does not push it back out",
		"core=%.1f" % carrier.global_position.x)
	var checkpoint_on: bool = await _wait_until(
		func() -> bool: return checkpoint.is_activated(), 120
	)
	_check(checkpoint_on, "the checkpoint activates after the second gate",
		"x=%.1f" % _player.global_position.x)
	_check(_loom.get_hud().get_event_text().contains("检查点"),
		"the HUD event line confirms the checkpoint",
		_loom.get_hud().get_event_text())
	_check(checkpoint.get_state_texture() != null
		and checkpoint.get_state_texture().resource_path.ends_with("checkpoint_active.png"),
		"the checkpoint uses the base active texture")
	_check(checkpoint.get_texture_size() == Vector2(40.0, 36.0),
		"the checkpoint keeps its native 40x36 art", str(checkpoint.get_texture_size()))
	_check(absf(_loom.get_checkpoint_position().x - checkpoint.global_position.x) < 0.5,
		"the checkpoint stores its real feet position",
		"x=%.1f" % _loom.get_checkpoint_position().x)

	# --- checkpoint keeps the second gate open after a pull -------------
	# Walk back left of the core, then pull it off.  The gate must stay open
	# because the checkpoint is now the stable progress record.
	var back_left: bool = await _walk_left_until(
		func() -> bool: return _player.global_position.x <= 300.0,
		260
	)
	_check(back_left, "the player can walk back through the open gate",
		"x=%.1f" % _player.global_position.x)
	await _tap_polarity()
	var off_after_checkpoint: bool = await _wait_until(
		func() -> bool: return not carrier.is_on_socket(), 240
	)
	_check(off_after_checkpoint, "the core can still be pulled back after the checkpoint",
		"core=%.1f" % carrier.global_position.x)
	_check(gate_second.is_open(),
		"checkpoint latch keeps the second gate open (no far-side softlock)")

	# --- the boss starts, failure returns to the checkpoint -------------
	var entered: bool = await _walk_right_until(
		func() -> bool: return _loom.is_boss_active(), 260
	)
	_check(entered, "walking on starts the loom after the approach puzzle")
	if entered:
		_loom.debug_set_attacks_enabled(false)
		_loom.debug_clear_hazards()
		_loom.debug_set_stage(2)
		await _wait_physics(60)
		for _hit_index: int in range(3):
			_loom.debug_apply_player_hit()
			await _wait_physics(2)
			if _hit_index < 2:
				await _wait_until(
					func() -> bool: return _loom.get_damage_immunity_left() <= 0.0,
					160
				)
		var recovery_started: bool = await _wait_until(
			func() -> bool: return _loom.is_recovery_active(), 80
		)
		_check(recovery_started, "three accepted hits start the failure cover")
		var recovery_ended: bool = await _wait_until(
			func() -> bool: return not _loom.is_recovery_active(), 300
		)
		_check(recovery_ended, "the failure fade finishes")
		_check(absf(_player.global_position.x - checkpoint.global_position.x) < 4.0,
			"failure respawns at the checkpoint, not the old arena spawn",
			"x=%.1f" % _player.global_position.x)
		_check(checkpoint.is_activated(),
			"the checkpoint survives the failure")
		_check(gate_second.is_open(),
			"the checkpoint-powered gate survives the failure")
		_check(_loom.get_stage() == 2,
			"failure still retries the current stage", str(_loom.get_stage()))

	# --- R restores the whole approach ----------------------------------
	_push_key(KEY_R, true)
	await _wait_physics(2)
	_push_key(KEY_R, false)
	await _wait_physics(12)
	_check(absf(_player.global_position.x - _loom.get_start_spawn().x) < 4.0,
		"R returns the body to the chapter start",
		"x=%.1f" % _player.global_position.x)
	_check(absf(carrier.global_position.x - carrier.get_start_x()) < 0.5,
		"R restores the star core initial position",
		"x=%.1f" % carrier.global_position.x)
	_check(not bay.is_occupied() and not gate_second.is_open()
		and gate_second.get_collision_layer() == 1,
		"R closes the second gate and darkens the bay")
	_check(not checkpoint.is_activated(),
		"R clears the checkpoint")
	_check(not gate_first.is_open() and gate_first.get_collision_layer() == 1,
		"R leaves the first gate solid for the reset cyan body")
