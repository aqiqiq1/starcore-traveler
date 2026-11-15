extends Node

## Focused formal-L2 transport on the integrated 256x32 conductive roof.
## Setup is explicit; after setup the player uses real walk/jump input and never
## teleports inside 464..720. No old suite.

const L2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LOG_PATH: String = "res://tests/logs/l2_transport_formal_20261114.log"

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level: Level02 = L2_SCENE.instantiate() as Level02
	add_child(level)
	await _frames(5)
	await _physics(3)
	var player: PrototypePlayer = level.get_player()
	var core: StarCoreCarrier = level.get_core()
	level.debug_restore_stage(1, true)
	var relay: StarCoreBayInteractable = level.get_relay_bay()
	relay.start_release()
	relay.finish_release()
	player.global_position = Vector2(430, 320)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	core.activate_at(Vector2(500, 312), true)
	core.collision_mask = 1
	core.ignore_body(player)
	level.get_link().reset_link()
	level.get_rune_field().reset_state()
	level.get_camera().reset_smoothing()
	await _physics(5)

	_check(level.get_stable_stage() == 1, "relay checkpoint is completed in setup")
	_check(relay.has_record() and not relay.has_core(), "relay record kept without a second core")
	_check(core.is_active(), "one active core starts under the roof")
	_check(level.get_interaction_range() == 100.0, "100px player-core range unchanged")
	_check(level.get_hud().get_phase_text().contains("联动仓"), "HUD points to the linked bay")

	var start_core_x: float = core.global_position.x
	var on_roof: bool = false
	var blocked_seen: bool = false
	var crossed: bool = false
	Input.action_press(&"move_right")
	await _tap_key(KEY_SPACE)
	for _i: int in range(460):
		await get_tree().physics_frame
		var position: Vector2 = player.global_position
		if position.x > 480.0 and position.x < 700.0 and position.y <= 270.0:
			on_roof = true
		if level.is_last_blocked():
			blocked_seen = true
		if (
			core.global_position.x > 728.0
			and position.x > 730.0
			and position.y >= 318.0
		):
			crossed = true
			break
	Input.action_release(&"move_right")
	await _physics(8)

	_check(on_roof, "player really walks on the complete solid roof")
	_check(crossed, "same core is pushed past the roof right end")
	_check(core.global_position.x > start_core_x + 228.0, "core movement is a full crossing, not a nudge")
	_check(player.global_position.y >= 318.0, "player finishes on the right-side ground")
	_check(core.global_position.y >= 304.0 and core.global_position.y <= 313.0, "core stays in the 20px lower channel")
	_check(not blocked_seen, "full transport is never force-blocked")
	_check(level.get_special_force_body_count() == 4, "four special bodies remain registered")

	# Real Q twice: only the player changes, the core keeps its own phase.
	var core_positive: bool = core.is_positive()
	await _tap_key(KEY_Q)
	_check(not player.is_positive() and core.is_positive() == core_positive, "real Q changes only the player phase")
	await _tap_key(KEY_Q)
	_check(player.is_positive(), "second real Q returns the player to GOLD")
	_check(core.is_positive() == core_positive, "core phase is unchanged by Q")

	level.queue_free()
	await _frames(4)
	_write_log()
	print("L2_TRANSPORT_FORMAL pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _tap_key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("L2 TRANSPORT FAIL: " + text)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
