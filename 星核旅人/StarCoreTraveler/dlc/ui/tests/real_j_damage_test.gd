extends Node

## Real-key J damage test for the trial guard and the rift double mirror.
##
##   ... --headless --path . res://dlc/ui/tests/real_j_damage_test.tscn
##
## Every attack below is a real physical J key delivered through
## Input.parse_input_event().  request_attack() is never called by the test.
## The trial's debug_force_gravity() is used only to put the guard into its
## existing GRAVITY_CHARGE state without waiting for the 3 s AI cycle; damage is
## still resolved by the guard's own receive_player_hit() from the real hit
## window.  The rift boss uses set_attacks_enabled(false) only to keep the
## automatic wave/sweep/summon out of this focused hit test.
##
## Covers:
##   - trial: real J with the player initially facing AWAY (auto-face fixes it)
##   - trial: opposite-phase charge field really pulls the body toward the guard
##   - trial: same phase keeps the cell and shows the HUD explanation
##   - rift: real J shatters the gold face from its opposite phase
##   - rift: real J shatters the cyan face; both broken -> core exposed
##   - rift: real J then removes one exposed core cell

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _level: Node
var _player: L3Player
var _started: int = 0
var _hit_windows: int = 0
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# This shared J test is not a teaching test: each chapter covers its own
	# popups. Mark every DLC tip as seen so a popup cannot pause the tree
	# between the input and the hit window.
	for id: String in [
		"trial_gate_tip", "trial_guard_deny", "trial_guard_hit",
		"rift_mirror_tip", "rift_core_tip",
		"loom_entry_tip", "loom_fire_tip", "loom_core_tip",
	]:
		MechanicTips.mark_seen(id)
	await get_tree().process_frame
	await _run_trial()
	await _run_rift()
	print("REAL_J_DAMAGE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	await _wait_process(2)
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


func _real_j(wait_frames: int = 45) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_J
	down.keycode = KEY_J
	down.pressed = true
	Input.parse_input_event(down)
	await _wait_physics(2)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_J
	up.keycode = KEY_J
	up.pressed = false
	Input.parse_input_event(up)
	await _wait_physics(wait_frames)


func _connect_player(player: L3Player) -> void:
	_started = 0
	_hit_windows = 0
	player.attack_started.connect(func(_id: int, _f: int, _p: bool) -> void:
		_started += 1
	)
	player.attack_hit_window.connect(func(_id: int, _f: int, _p: bool) -> void:
		_hit_windows += 1
	)


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(4)


func _load_scene(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	var node: Node = packed.instantiate()
	if node is TrialChambers:
		(node as TrialChambers).show_intro_guide = false
		# This is a damage test: the real J must reach the guard/player without
		# the chapter's opening film holding the control lock.
		(node as TrialChambers).show_intro_cinematic = false
	elif node is RiftWorkshop:
		(node as RiftWorkshop).show_intro_guide = false
		(node as RiftWorkshop).show_intro_cinematic = false
	get_tree().root.add_child(node)
	get_tree().current_scene = node
	await _wait_process(3)
	await _wait_physics(8)
	return node


func _place(guard: L3Guard, player: L3Player, gap: float, facing: int) -> void:
	player.global_position = Vector2(guard.global_position.x - gap, 320.0)
	player.velocity = Vector2.ZERO
	player.cancel_attack()
	player.set_polarity_state(not guard.is_positive())
	player.face_direction(facing)
	await _wait_physics(2)


# --- trial -----------------------------------------------------------------

func _run_trial() -> void:
	print("=== TRIAL REAL J ===")
	_level = await _load_scene(TRIAL_SCENE)
	_player = _level.get_player() as L3Player
	var guard: L3Guard = _level.get_guard() as L3Guard
	_connect_player(_player)
	_player.global_position = Vector2(880.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_until(func() -> bool: return _level.is_arena_entered(), 90)
	await _wait_physics(6)
	_check(_level.is_arena_entered(), "trial arena entered")
	_check(not guard.is_suspended(), "trial guard is awake", guard.get_state_name())

	# 1) Field feed: opposite phase at 70 px is pulled toward the guard.
	guard.reset_state(_level.get_guard().global_position, true, true)
	guard.set_player_target(_player)
	guard.set_suspended(false)
	await _place(guard, _player, 70.0, 1)
	guard.debug_force_gravity()
	await _wait_physics(2)
	var x_before: float = _player.global_position.x
	await _wait_physics(24)
	var pulled: float = _player.global_position.x - x_before
	_check(pulled >= 3.0, "trial opposite-phase field pulls the player inward",
		"dx=%.2f force=%.1f" % [pulled, _player.get_anchor_force_x()])
	_check(_player.get_anchor_force_x() > 100.0, "trial guard force reaches the player",
		"%.1f" % _player.get_anchor_force_x())
	guard.set_suspended(true)

	# 2) Real J with a stale/away facing: auto-face must correct it and hit.
	guard.reset_state(_level.get_guard().global_position, true, true)
	guard.set_player_target(_player)
	guard.set_suspended(false)
	await _place(guard, _player, 22.0, -1)
	guard.debug_force_gravity()
	await _wait_physics(2)
	var marks_before: int = guard.get_true_marks_taken()
	await _real_j()
	_check(_started == 1, "trial real J produced attack_started", str(_started))
	_check(_hit_windows == 1, "trial real J produced attack_hit_window", str(_hit_windows))
	_check(_player.get_facing() == 1, "trial auto-face turned toward the guard",
		"facing=%d" % _player.get_facing())
	_check(guard.get_true_marks_taken() == marks_before + 1,
		"trial real J removed one true mark", "marks=%d" % guard.get_true_marks_taken())
	_check(String(guard.get_last_result().get("code", "")) == "TRUE_HIT",
		"trial guard resolved TRUE_HIT", String(guard.get_last_result().get("code", "")))
	guard.set_suspended(true)
	await _wait_physics(4)

	# 3) Same phase keeps the cell and explains why in the HUD.
	guard.reset_state(_level.get_guard().global_position, true, false)
	guard.set_player_target(_player)
	guard.set_suspended(false)
	await _place(guard, _player, 22.0, 1)
	_player.set_polarity_state(true)
	guard.debug_force_gravity()
	await _wait_physics(2)
	var marks_before_same: int = guard.get_true_marks_taken()
	await _real_j()
	_check(guard.get_true_marks_taken() == marks_before_same,
		"trial same phase keeps the true marks", "marks=%d" % guard.get_true_marks_taken())
	_check(String(guard.get_last_result().get("code", "")) == "SAME_PHASE",
		"trial same-phase result is SAME_PHASE",
		String(guard.get_last_result().get("code", "")))
	_check(_level.get_hud().get_event_text().contains("同相"),
		"trial HUD explains the same-phase rule", _level.get_hud().get_event_text())
	guard.set_suspended(true)
	await _cleanup()


# --- rift ------------------------------------------------------------------

## Place the body beside the mirror and set the phase needed for the face.
## The real J path still snapshots facing/polarity itself; this helper only
## gives the focused test a deterministic starting side.
func _place_for_face(x: float, positive: bool, facing: int) -> void:
	_player.global_position = Vector2(x, 320.0)
	_player.velocity = Vector2.ZERO
	_player.cancel_attack()
	_player.clear_external_force()
	_player.set_polarity_state(positive)
	_player.face_direction(facing)
	await _wait_physics(2)


func _run_rift() -> void:
	print("=== RIFT REAL J ===")
	_level = await _load_scene(RIFT_SCENE)
	var rift: RiftWorkshop = _level as RiftWorkshop
	_player = rift.get_player() as L3Player
	var boss: RiftMirrorBoss = rift.get_boss()
	_connect_player(_player)
	_player.global_position = Vector2(1250.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_until(func() -> bool: return rift.is_arena_entered(), 90)
	await _wait_until(func() -> bool: return not rift.is_arena_intro_active(), 180)
	await _wait_until(
		func() -> bool:
			return boss.is_active() and boss.get_attack_state_name() != "INTRO",
		240
	)
	# This is a focused hit-window test, not an attack-pattern test.  Stop the
	# automatic wave/sweep/summon so the three real swings below are the only
	# state changes.
	boss.set_attacks_enabled(false)
	await _wait_physics(2)
	_check(rift.is_arena_entered(), "rift arena entered")
	_check(boss.is_active() and not boss.is_defeated(),
		"rift double mirror is active", boss.get_attack_state_name())
	_check(rift.get_hud().is_boss_visible(), "rift boss status row is visible")
	_check(boss.is_face_intact(true) and boss.is_face_intact(false)
		and not boss.is_core_exposed(),
		"rift starts with both face plates intact and the core shielded")

	# Gold face: gold is 辉相; the player stands on its left in 澜相.
	await _place_for_face(boss.global_position.x - 58.0, false, 1)
	await _real_j()
	_check(_started == 1 and _hit_windows == 1,
		"rift gold face real J produced start + hit window",
		"start=%d hit=%d" % [_started, _hit_windows])
	_check(String(boss.get_last_result().get("code", "")) == "FACE_SHATTER",
		"rift gold face resolved FACE_SHATTER",
		String(boss.get_last_result().get("code", "")))
	_check(not boss.is_face_intact(true),
		"rift gold face is broken after the real J")
	_check(boss.is_face_intact(false) and not boss.is_core_exposed(),
		"cyan face still shields the core after the gold break",
		"cyan=%s core=%s" % [
			str(boss.is_face_intact(false)), str(boss.is_core_exposed())
		])

	# Cyan face: cyan is 澜相; the player stands on its right in 辉相.
	await _place_for_face(boss.global_position.x + 58.0, true, -1)
	await _real_j()
	_check(_started == 2 and _hit_windows == 2,
		"rift cyan face real J produced start + hit window",
		"start=%d hit=%d" % [_started, _hit_windows])
	_check(String(boss.get_last_result().get("code", "")) == "FACE_SHATTER",
		"rift cyan face resolved FACE_SHATTER",
		String(boss.get_last_result().get("code", "")))
	_check(not boss.is_face_intact(false),
		"rift cyan face is broken after the real J")
	_check(boss.is_core_exposed() and boss.get_core_hp() == 3,
		"both faces broken -> core exposed at 3/3",
		"core_hp=%d" % boss.get_core_hp())

	# Core: a third real J from the exposed front removes one core cell.
	await _place_for_face(boss.global_position.x - 20.0, true, 1)
	await _real_j()
	_check(_started == 3 and _hit_windows == 3,
		"rift core real J produced start + hit window",
		"start=%d hit=%d" % [_started, _hit_windows])
	_check(String(boss.get_last_result().get("code", "")) == "CORE_HIT",
		"rift exposed core resolved CORE_HIT",
		String(boss.get_last_result().get("code", "")))
	_check(boss.get_core_hp() == 2,
		"rift real J removed one exposed core cell",
		"core_hp=%d" % boss.get_core_hp())
	await _cleanup()
