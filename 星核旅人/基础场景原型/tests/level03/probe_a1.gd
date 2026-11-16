extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
var _level: Level03
var _player: L3Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(20)
	_player = _level.get_player()
	# SETUP: device already active + the player standing on the high platform
	# (the forward route above was proved by real input in the previous probe).
	_level.debug_restore_stage(2, true, false)
	await _phys(8)
	_level.debug_place_player_at(Vector2(390.0, 130.0))
	await _phys(8)
	print("START ", _player.global_position.snapped(Vector2(0.1, 0.1)), " floor=", _player.is_on_floor(),
		" pol=", _player.is_positive(), " rune_pol=", _level.get_rune_field().is_positive())
	# opposite phase, jump right off the platform, ride the attract to the ledge
	Input.action_press(&"jump")
	await _phys(2)
	Input.action_press(&"move_right")
	await _phys(3)
	Input.action_release(&"jump")
	var landed: bool = false
	for i: int in range(260):
		await get_tree().physics_frame
		if _player.is_on_floor() and _player.global_position.y > 200.0 and _player.global_position.x > 500.0:
			landed = true
			break
		if i % 4 == 0:
			print("R", i, " p=", _player.global_position.snapped(Vector2(0.1, 0.1)),
				" v=", _player.velocity.snapped(Vector2(1, 1)),
				" f=", _level.get_last_player_force().snapped(Vector2(1, 1)), " floor=", _player.is_on_floor())
	var ok: bool = landed
	Input.action_release(&"move_right")
	await _phys(6)
	print("RETURN landed=", ok, " end=", _player.global_position.snapped(Vector2(0.1, 0.1)),
		" floor=", _player.is_on_floor())
	if not ok:
		get_tree().quit(0)
		return
	# same phase again: the stone pushes the body right along the ledge
	Input.action_press(&"polarity")
	await get_tree().physics_frame
	Input.action_release(&"polarity")
	await _phys(4)
	Input.action_press(&"move_right")
	for _i: int in range(220):
		await get_tree().physics_frame
		if _player.global_position.x >= 640.0:
			break
	Input.action_release(&"move_right")
	await _phys(4)
	print("LEDGE ", _player.global_position.snapped(Vector2(0.1, 0.1)), " floor=", _player.is_on_floor())
	get_tree().quit(0)


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
