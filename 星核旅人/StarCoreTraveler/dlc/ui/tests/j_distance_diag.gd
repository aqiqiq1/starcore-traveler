extends Node

## Temporary distance/facing diagnostic for real J vs the trial guard.
##   ... --headless --path . res://dlc/ui/tests/j_distance_diag.tscn

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"

var _level: TrialChambers
var _player: L3Player
var _guard: L3Guard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	_level = packed.instantiate() as TrialChambers
	_level.show_intro_guide = false
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(3)
	await _wait_physics(10)
	_player = _level.get_player()
	_guard = _level.get_guard()
	_player.global_position = Vector2(880.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_until(func() -> bool: return _level.is_arena_entered(), 60)
	await _wait_physics(6)
	print("guard ACTIVE=%s" % _guard.get_state_name())

	# Field feed check: opposite phase at 70 px must be pulled toward the chest.
	_guard.reset_state(_guard.global_position, true, true)
	_guard.set_player_target(_player)
	_guard.set_suspended(false)
	_player.global_position = Vector2(_guard.global_position.x - 70.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(1)
	await _wait_physics(2)
	_guard.debug_force_gravity()
	await _wait_physics(2)
	var x_before: float = _player.global_position.x
	await _wait_physics(24)
	print("field feed: guard=%s x %.2f -> %.2f (toward +%.2f) force_x=%.1f" % [
		_guard.get_state_name(), x_before, _player.global_position.x,
		_player.global_position.x - x_before, _player.get_anchor_force_x(),
	])
	_guard.set_suspended(true)

	for gap: float in [18.0, 22.0, 28.0, 34.0, 36.0, 38.0, 42.0, 48.0, 56.0, 70.0]:
		await _trial_hit(-gap, 1, true)

	# Facing away while the guard is on the right.
	await _trial_hit(-22.0, -1, true)
	# Player to the right of the guard, facing left.
	await _trial_hit(22.0, -1, true)

	print("J_DISTANCE_DONE")
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


func _real_j() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_J
	event.keycode = KEY_J
	event.pressed = true
	Input.parse_input_event(event)
	await _wait_physics(2)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_J
	up.keycode = KEY_J
	up.pressed = false
	Input.parse_input_event(up)
	await _wait_physics(40)


func _trial_hit(offset: float, facing: int, opposite: bool) -> void:
	_guard.reset_state(_level.get_guard().global_position, true, true)
	_guard.set_player_target(_player)
	_guard.set_suspended(true)
	_player.global_position = Vector2(_guard.global_position.x + offset, 320.0)
	_player.velocity = Vector2.ZERO
	_player.cancel_attack()
	_player.set_polarity_state(false if opposite else true)
	_player.face_direction(facing)
	await _wait_physics(2)
	_guard.set_suspended(false)
	_guard.debug_force_gravity()
	await _wait_physics(2)
	await _real_j()
	var result: Dictionary = _guard.get_last_result()
	print("offset=%+.0f facing=%+d opposite=%s -> state=%s code=%s remaining=%s marks=%d" % [
		offset, facing, str(opposite), _guard.get_state_name(),
		String(result.get("code", "?")), str(result.get("remaining_marks", "?")),
		_guard.get_true_marks_taken(),
	])
	_guard.set_suspended(true)
	await _wait_physics(4)
