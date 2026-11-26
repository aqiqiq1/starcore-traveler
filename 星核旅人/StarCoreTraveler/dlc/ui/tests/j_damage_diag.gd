extends Node

## Temporary real-J diagnostic for the DLC guard damage report.
##   ... --headless --path . res://dlc/ui/tests/j_damage_diag.tscn
##
## The guard may be pushed into GRAVITY_CHARGE with its existing
## debug_force_gravity() hook, but every attack below is a real physical J key
## delivered through Input.parse_input_event().  No request_attack() call.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _level: Node
var _player: L3Player
var _guard: L3Guard
var _started: int = 0
var _hit_windows: int = 0
var _started_facing: int = 0
var _started_positive: bool = false
var _hit_facing: int = 0
var _hit_positive: bool = false
var _swing_ids: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run_trial()
	await _run_rift()
	print("J_DIAG_DONE")
	get_tree().quit(0)


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


func _push_real_key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _key_down(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)


func _connect_player(player: L3Player) -> void:
	_started = 0
	_hit_windows = 0
	_swing_ids.clear()
	player.attack_started.connect(func(swing_id: int, facing: int, positive: bool) -> void:
		_started += 1
		_started_facing = facing
		_started_positive = positive
		_swing_ids.append(swing_id)
		print("  SIGNAL attack_started swing=%d facing=%d positive=%s" % [
			swing_id, facing, str(positive)
		])
	)
	player.attack_hit_window.connect(func(swing_id: int, facing: int, positive: bool) -> void:
		_hit_windows += 1
		_hit_facing = facing
		_hit_positive = positive
		print("  SIGNAL attack_hit_window swing=%d facing=%d positive=%s" % [
			swing_id, facing, str(positive)
		])
	)


func _press_real_j(wait_frames: int = 45) -> void:
	print("  real J down: Input.is_physical_key_pressed(J)=%s" % str(_key_down(KEY_J)))
	_push_real_key(KEY_J, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("  after down: input_pressed=%s attacking=%s phase=%s swing=%d" % [
		str(_key_down(KEY_J)),
		str(_player.is_attacking()),
		_player.get_attack_phase_label(),
		_player.get_attack_swing_id(),
	])
	_push_real_key(KEY_J, false)
	await _wait_physics(wait_frames)


func _report_guard(tag: String, guard: L3Guard) -> void:
	print("  [%s] state=%s suspended=%s active=%s defeated=%s marks=%d remaining=%d" % [
		tag, guard.get_state_name(), str(guard.is_suspended()), str(guard.is_active()),
		str(guard.is_defeated()), guard.get_true_marks_taken(), guard.get_remaining_marks(),
	])
	var result: Dictionary = guard.get_last_result()
	print("  [%s] last_result code=%s hit=%s true=%s remaining=%s state=%s" % [
		tag, String(result.get("code", "?")), str(result.get("hit", "?")),
		str(result.get("true_damage", "?")), str(result.get("remaining_marks", "?")),
		String(result.get("state", "?")),
	])
	var event_text: String = ""
	if _level.has_method("get_hud"):
		var hud: Node = _level.call("get_hud") as Node
		if hud != null and hud.has_method("get_event_text"):
			event_text = String(hud.call("get_event_text"))
	var player_hits: int = -1
	if _level.get("_player_hits") != null:
		player_hits = int(_level.get("_player_hits"))
	var resolved: int = -1
	var resolved_swings: Variant = _level.get("_resolved_swings")
	if resolved_swings is Dictionary:
		resolved = (resolved_swings as Dictionary).size()
	print("  [%s] event='%s' player_hits=%d resolved_swings=%d" % [
		tag, event_text, player_hits, resolved,
	])


func _force_charge(guard: L3Guard, player: L3Player) -> void:
	guard.set_suspended(false)
	guard.debug_force_gravity()
	await _wait_physics(2)
	print("  forced charge: guard state=%s vulnerable=%s player polarity=%s guard polarity=%s" % [
		guard.get_state_name(), str(guard.is_vulnerable()), str(player.is_positive()),
		str(guard.is_positive()),
	])


func _place_for_hit(guard: L3Guard, player: L3Player, gap: float = 22.0) -> void:
	player.global_position = Vector2(guard.global_position.x - gap, 320.0)
	player.velocity = Vector2.ZERO
	player.face_direction(1)
	player.cancel_attack()
	player.set_polarity_state(not guard.is_positive())
	await _wait_physics(1)
	print("  placed: player x=%.1f y=%.1f facing=%d polarity=%s guard x=%.1f" % [
		player.global_position.x, player.global_position.y, player.get_facing(),
		str(player.is_positive()), guard.global_position.x,
	])


func _run_trial() -> void:
	print("=== TRIAL ===")
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	_level = packed.instantiate()
	(_level as TrialChambers).show_intro_guide = false
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(3)
	await _wait_physics(8)
	_player = _level.get_player() as L3Player
	_guard = _level.get_guard() as L3Guard
	_connect_player(_player)
	_player.global_position = Vector2(880.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_physics(20)
	print("arena_entered=%s guard_state=%s suspended=%s" % [
		str(_level.is_arena_entered()), _guard.get_state_name(), str(_guard.is_suspended())
	])
	# Stand in front and let the real guard choose its first gravity charge.
	await _place_for_hit(_guard, _player, 60.0)
	var charging: bool = await _wait_until(
		func() -> bool: return _guard.get_state_name() == "GRAVITY_CHARGE", 180
	)
	print("natural GRAVITY_CHARGE=%s state=%s" % [str(charging), _guard.get_state_name()])
	if not charging:
		await _force_charge(_guard, _player)
	await _place_for_hit(_guard, _player, 22.0)
	print("before J: _attack_key_down=%s" % str(_level.get("_attack_key_down")))
	await _press_real_j()
	print("started=%d hit_windows=%d swing_ids=%s" % [
		_started, _hit_windows, str(_swing_ids)
	])
	print("start snapshot facing=%d positive=%s; hit facing=%d positive=%s" % [
		_started_facing, str(_started_positive), _hit_facing, str(_hit_positive),
	])
	var last: Dictionary = _guard.get_last_result()
	var forward_gap: float = (_guard.global_position.x - _player.global_position.x) \
		* float(_player.get_facing())
	print("forward_gap=%.2f facing=%d snapshot=%s guard_positive=%s" % [
		forward_gap, _player.get_facing(), str(_player.get_attack_positive_snapshot()),
		str(_guard.is_positive()),
	])
	print("last_result=%s" % str(last))
	_report_guard("trial", _guard)
	await _cleanup()


func _run_rift() -> void:
	print("=== RIFT ===")
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_level = packed.instantiate()
	(_level as RiftWorkshop).show_intro_guide = false
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(3)
	await _wait_physics(8)
	_player = _level.get_player() as L3Player
	var gold: L3Guard = _level.get_guard_gold() as L3Guard
	var cyan: L3Guard = _level.get_guard_cyan() as L3Guard
	_connect_player(_player)
	_player.global_position = Vector2(1100.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_until(func() -> bool: return _level.is_arena_entered(), 60)
	await _wait_until(func() -> bool: return not _level.is_arena_intro_active(), 180)
	await _wait_physics(6)
	print("arena_entered=%s gold=%s cyan=%s" % [
		str(_level.is_arena_entered()), gold.get_state_name(), cyan.get_state_name()
	])
	# Isolate each guard while still using the chapter's own hit dispatch.
	cyan.set_suspended(true)
	await _test_rift_guard("gold", gold, cyan)
	gold.set_suspended(true)
	await _test_rift_guard("cyan", cyan, gold)
	await _cleanup()


func _test_rift_guard(tag: String, guard: L3Guard, other: L3Guard) -> void:
	other.set_suspended(true)
	await _place_for_hit(guard, _player, 60.0)
	await _force_charge(guard, _player)
	await _place_for_hit(guard, _player, 22.0)
	# Both guards are live targets of the chapter's handler; only the guard in
	# front should resolve a hit even though the other is suspended.
	var before_marks: int = guard.get_true_marks_taken()
	await _press_real_j()
	print("[%s] started=%d hit_windows=%d marks %d -> %d" % [
		tag, _started, _hit_windows, before_marks, guard.get_true_marks_taken(),
	])
	var forward_gap: float = (guard.global_position.x - _player.global_position.x) \
		* float(_player.get_facing())
	print("[%s] forward_gap=%.2f facing=%d snapshot=%s guard_positive=%s" % [
		tag, forward_gap, _player.get_facing(),
		str(_player.get_attack_positive_snapshot()), str(guard.is_positive()),
	])
	_report_guard(tag, guard)
	_report_guard(tag + "_other", other)


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(4)
