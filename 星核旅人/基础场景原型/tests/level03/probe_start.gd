extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
var _level: Level03
var _player: L3Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(24)
	_player = _level.get_player()
	await _walk_to_x(150.0, 200)
	await _phys(4)
	await _press_interact()
	await _phys(40)
	print("released core_active=", _level.get_core().is_active(),
		" core=", _level.get_core().global_position.snapped(Vector2(1, 1)),
		" core_pol=", _level.get_core().is_positive(), " player_pol=", _player.is_positive())
	await _walk_to_x(362.0, 300)
	await _phys(40)
	print("near target player=", _player.global_position.snapped(Vector2(1, 1)),
		" core=", _level.get_core().global_position.snapped(Vector2(1, 1)),
		" bay=", _level.get_target_bay().global_position,
		" in_zone=", _level.get_target_bay().is_core_in_store_zone(_level.get_core().global_position))
	await _press_interact()
	await _phys(24)
	print("after store target_has_core=", _level.get_target_bay().has_core(),
		" rune_lit=", _level.get_rune_field().is_activated(), "/", _level.get_rune_field().is_positive(),
		" stage=", _level.get_stable_stage())
	get_tree().quit(0)


func _press_interact() -> void:
	Input.action_press(&"interact")
	await _phys(1)
	Input.action_release(&"interact")
	await get_tree().physics_frame


func _walk_to_x(target: float, max_frames: int) -> void:
	var held: StringName = &""
	for _i: int in range(max_frames):
		var dx: float = target - _player.global_position.x
		if absf(dx) <= 2.0:
			break
		var action: StringName = &"move_right" if dx > 0.0 else &"move_left"
		if action != held:
			if held != &"":
				Input.action_release(held)
			Input.action_press(action)
			held = action
		await get_tree().physics_frame
	if held != &"":
		Input.action_release(held)
	await _phys(2)


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
