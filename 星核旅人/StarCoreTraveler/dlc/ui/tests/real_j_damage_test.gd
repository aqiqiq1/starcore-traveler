extends Node

## Real-key J damage test for both DLC guard arenas.
##
##   ... --headless --path . res://dlc/ui/tests/real_j_damage_test.tscn
##
## Every attack below is a real physical J key delivered through
## Input.parse_input_event().  request_attack() is never called by the test.
## debug_force_gravity() is used only to put the guard into its existing
## GRAVITY_CHARGE state without waiting for the 3 s AI cycle; damage is still
## resolved by the guard's own receive_player_hit() from the real hit window.
##
## Covers:
##   - trial: real J with the player initially facing AWAY (auto-face fixes it)
##   - trial: opposite-phase charge field really pulls the body toward the guard
##   - trial: same phase keeps the cell and shows the HUD explanation
##   - rift: real J vs gold, then vs cyan
##   - rift: one swing reaches both guards (near one true hit, far one MISS_RANGE)

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
	elif node is RiftWorkshop:
		(node as RiftWorkshop).show_intro_guide = false
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

func _run_rift() -> void:
	print("=== RIFT REAL J ===")
	_level = await _load_scene(RIFT_SCENE)
	_player = _level.get_player() as L3Player
	var gold: L3Guard = _level.get_guard_gold() as L3Guard
	var cyan: L3Guard = _level.get_guard_cyan() as L3Guard
	_connect_player(_player)
	_player.global_position = Vector2(1100.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_until(func() -> bool: return _level.is_arena_entered(), 90)
	await _wait_until(func() -> bool: return not _level.is_arena_intro_active(), 180)
	await _wait_physics(6)
	_check(_level.is_arena_entered(), "rift arena entered")
	_check(not gold.is_suspended() and not cyan.is_suspended(),
		"rift both guards are awake",
		"gold=%s cyan=%s" % [gold.get_state_name(), cyan.get_state_name()])

	var gold_spawn: Vector2 = gold.global_position
	var cyan_spawn: Vector2 = cyan.global_position

	# Gold: cyan stays suspended so only the real gold resolution can pass.
	cyan.set_suspended(true)
	gold.reset_state(gold_spawn, true, false)
	gold.set_player_target(_player)
	gold.set_suspended(false)
	await _place(gold, _player, 22.0, -1)
	gold.debug_force_gravity()
	await _wait_physics(2)
	await _real_j()
	_check(_started == 1 and _hit_windows == 1,
		"rift gold real J produced start + hit window",
		"start=%d hit=%d" % [_started, _hit_windows])
	_check(gold.get_true_marks_taken() == 1, "rift gold real J removed one true mark",
		"marks=%d" % gold.get_true_marks_taken())
	_check(String(gold.get_last_result().get("code", "")) == "TRUE_HIT",
		"rift gold guard resolved TRUE_HIT",
		String(gold.get_last_result().get("code", "")))
	# The other guard is still a target of the same dispatch; suspended = INACTIVE.
	_check(String(cyan.get_last_result().get("code", "")) == "INACTIVE",
		"rift suspended cyan received the swing as INACTIVE",
		String(cyan.get_last_result().get("code", "")))
	gold.set_suspended(true)
	await _wait_physics(4)

	# Cyan: gold stays suspended, real J from the left with away facing.
	gold.set_suspended(true)
	cyan.reset_state(cyan_spawn, false, false)
	cyan.set_player_target(_player)
	cyan.set_suspended(false)
	await _place(cyan, _player, 22.0, -1)
	cyan.debug_force_gravity()
	await _wait_physics(2)
	await _real_j()
	_check(_started == 2 and _hit_windows == 2,
		"rift cyan real J produced start + hit window",
		"start=%d hit=%d" % [_started, _hit_windows])
	_check(cyan.get_true_marks_taken() == 1, "rift cyan real J removed one true mark",
		"marks=%d" % cyan.get_true_marks_taken())
	_check(String(cyan.get_last_result().get("code", "")) == "TRUE_HIT",
		"rift cyan guard resolved TRUE_HIT",
		String(cyan.get_last_result().get("code", "")))
	cyan.set_suspended(true)
	await _wait_physics(4)

	# Both live: one real swing must be dispatched to both guards.  The near
	# gold target takes the cell; the far cyan target reads MISS_RANGE.
	gold.reset_state(gold_spawn, true, false)
	cyan.reset_state(cyan_spawn, false, false)
	gold.set_player_target(_player)
	cyan.set_player_target(_player)
	gold.set_suspended(false)
	cyan.set_suspended(false)
	await _place(gold, _player, 22.0, 1)
	gold.debug_force_gravity()
	await _wait_physics(2)
	await _real_j()
	_check(gold.get_true_marks_taken() == 1,
		"rift dual dispatch: near gold took the cell",
		"gold_marks=%d" % gold.get_true_marks_taken())
	_check(String(cyan.get_last_result().get("code", "")) == "MISS_RANGE",
		"rift dual dispatch: far cyan also resolved the same swing",
		String(cyan.get_last_result().get("code", "")))
	gold.set_suspended(true)
	cyan.set_suspended(true)
	await _cleanup()
