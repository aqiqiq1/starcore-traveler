extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _game: PrototypeMain
var _player: PrototypePlayer
var _room: AnchorRoom


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_game = MAIN_SCENE.instantiate() as PrototypeMain
	add_child(_game)
	await get_tree().process_frame
	_player = _game.get_player()
	_room = _game.get_anchor_room()
	_game.enter_anchor_room()
	await _step(6)

	# Pure attraction return after actual success (no second switch), no reset.
	var pure := await _try_return(-1)
	print("PURE ", pure)

	var wins: Array[int] = []
	var details: Dictionary = {}
	for switch_frame in range(10, 51):
		var result: Dictionary = await _try_return(switch_frame)
		if bool(result["ok"]):
			wins.append(switch_frame)
			details[switch_frame] = result
	print("WINS=", wins)
	if wins.size() > 0:
		print("FIRST=", wins[0], " LAST=", wins[-1], " COUNT=", wins.size())
		for f in [wins[0], wins[int(wins.size() / 2)], wins[-1]]:
			print("  f", f, " ", details[f])
	get_tree().quit(0)


func _try_return(switch_frame: int) -> Dictionary:
	await _land_right()
	# Release forward keys without extra movement frames.
	_key_up(KEY_D)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	# Settle on the right ledge, then walk back to x<=408.
	await _step(120)
	_key_down(KEY_A)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	for f in range(1, 90):
		await _step(1)
		if _player.global_position.x <= 408.0:
			break
	_key_up(KEY_A)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(2)
	if _player.is_positive():
		await _tap(&"polarity")
	await _step(1)
	var resets_before: int = _player.get_reset_count()
	_key_down(KEY_A)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	Input.action_press(&"jump")
	await _step(2)
	Input.action_release(&"jump")
	var minx := 9999.0
	var miny := 9999.0
	var landed := false
	var reset_seen := false
	var land_frame := -1
	for f in range(1, 181):
		if switch_frame >= 0 and f == switch_frame:
			Input.action_press(&"polarity")
		await _step(1)
		if switch_frame >= 0 and f == switch_frame:
			Input.action_release(&"polarity")
		minx = min(minx, _player.global_position.x)
		miny = min(miny, _player.global_position.y)
		if _player.get_reset_count() > resets_before:
			reset_seen = true
			break
		if _player.is_on_floor() and _player.global_position.x <= 177.0 and absf(_player.global_position.y - 288.0) < 2.0:
			landed = true
			land_frame = f
			break
	_key_up(KEY_A)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(2)
	return {
		"ok": landed and not reset_seen,
		"reset": reset_seen,
		"frame": land_frame,
		"x": _player.global_position.x,
		"y": _player.global_position.y,
		"minx": minx,
		"miny": miny,
	}


func _land_right() -> void:
	_release_all()
	_player.reset_to_spawn("probe", false)
	await _step(2)
	if _player.is_positive():
		await _tap(&"polarity")
	_player.global_position = Vector2(160, 288)
	_player.velocity = Vector2(160, 0)
	await _step(1)
	_key_down(KEY_D)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	Input.action_press(&"jump")
	await _step(1)
	Input.action_release(&"jump")
	await _step(1)
	for f in range(1, 100):
		if f == 45:
			Input.action_press(&"polarity")
		await _step(1)
		if f == 45:
			Input.action_release(&"polarity")
		if _room.is_success():
			return


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _step(1)
	Input.action_release(action)
	await _step(1)


func _send_key(key: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.location = location
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key_down(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, true, location)


func _key_up(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, false, location)


func _release_all() -> void:
	for key: Key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		_send_key(key, false)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_RIGHT)
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity", &"reset"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _step(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame
