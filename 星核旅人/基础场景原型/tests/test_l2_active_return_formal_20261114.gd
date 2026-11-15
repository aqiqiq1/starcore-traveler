extends Node

## Focused formal-L2 active-field return. Real mode-2 checkpoint, live GOLD
## rune field, two ordinary jumps, two real Q presses, E at the linked bay.
## No field reset, no provider/layout change, no teleport inside the return,
## no R/death.

const L2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LOG_PATH: String = "res://tests/logs/l2_active_return_formal_20261114.log"

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
	var link: BayRuneLink = level.get_link()
	var rune: RuneStoneField = level.get_rune_field()
	var linked: StarCoreBayInteractable = level.get_linked_bay()
	level.debug_restore_stage(2, true)
	if level.get_hud() != null:
		level.get_hud().show_toast("", 0.0)
	player.global_position = Vector2(1360, 320)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	level.get_camera().reset_smoothing()
	await _physics(5)
	_check(player.global_position.is_equal_approx(Vector2(1360, 320)), "formal mode2 starts on the right side")
	_check(link.is_field_activated() and rune.is_activated(), "formal mode2 field is active")
	_check(link.has_record() and linked.has_record(), "formal mode2 record is real")
	_check(linked.has_core() and not core.is_active(), "formal mode2 has exactly the linked core")
	_check(level.get_player_force_provider_count() == 1, "one real force provider")
	var resets_before: int = player.get_reset_count()

	Input.action_press(&"move_left")
	await _tap_key(KEY_SPACE)
	var on_platform: bool = false
	for _i: int in range(130):
		await get_tree().physics_frame
		var position: Vector2 = player.global_position
		if position.y <= 282.0 and position.y >= 276.0 and position.x >= 1264.0 and position.x <= 1312.0:
			on_platform = true
			break
	_check(on_platform, "formal first jump reaches the return platform")
	await _physics(4)
	for _i: int in range(70):
		await get_tree().physics_frame
		if player.global_position.x <= 1278.0:
			break
	await _tap_key(KEY_SPACE)
	var on_wall: bool = false
	for _i: int in range(130):
		await get_tree().physics_frame
		var position: Vector2 = player.global_position
		if position.y <= 242.0 and position.x >= 1080.0 and position.x <= 1240.0:
			on_wall = true
			break
	_check(on_wall, "formal second jump reaches the wall top")

	var q1: bool = false
	var q2: bool = false
	var field_force_seen: bool = false
	for _i: int in range(620):
		await get_tree().physics_frame
		var position: Vector2 = player.global_position
		if not level.get_last_extra_player_force().is_zero_approx():
			field_force_seen = true
		if not q1 and position.x < 1208.0 and position.y <= 250.0:
			await _tap_key(KEY_Q)
			q1 = true
			_check(not player.is_positive(), "first real Q switches the player to CYAN")
		if q1 and not q2 and not player.is_positive() and position.x < 1012.0:
			await _tap_key(KEY_Q)
			q2 = true
			_check(player.is_positive(), "second real Q returns the player to GOLD")
		if position.x < 990.0 and position.y >= 318.0:
			break
	Input.action_release(&"move_left")
	await _physics(20)
	_check(field_force_seen, "live GOLD field acted during the return")
	_check(q1 and q2, "both real Q phase switches were used")
	_check(link.is_field_activated() and rune.is_activated(), "field/rune stay active through the return")
	_check(player.get_reset_count() == resets_before, "no R/death/reset during the return")

	var direction: float = 0.0
	for _i: int in range(220):
		var distance: float = player.global_position.x - 960.0
		if absf(distance) <= 24.0 and player.global_position.y >= 318.0:
			break
		direction = -1.0 if distance > 0.0 else 1.0
		if direction < 0.0:
			Input.action_press(&"move_left")
			Input.action_release(&"move_right")
		else:
			Input.action_press(&"move_right")
			Input.action_release(&"move_left")
		await get_tree().physics_frame
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	await _physics(6)
	_check(absf(player.global_position.x - 960.0) <= 52.0 and player.global_position.y >= 318.0, "normal movement reaches the linked bay")

	await _tap_key(KEY_E)
	await _physics(28)
	_check(core.is_active(), "E takes the linked core after the live-field return")
	_check(level.get_stable_stage() == 2, "linked checkpoint remains stable without reset")
	_check(link.is_field_activated() and link.has_record(), "field/record survive return and E")
	_check(not level.is_exit_gate_ready(), "return/E does not falsely open the gate")
	_check(level.get_player_force_provider_count() == 1, "force provider count unchanged")
	_check(player.get_reset_count() == resets_before, "no reset occurred by the end")
	_check(not level.is_completed(), "return is not a completion")

	# Continue after E: the same core moves with real input.
	var before_continue: float = core.global_position.x
	Input.action_press(&"move_right")
	await _physics(70)
	Input.action_release(&"move_right")
	_check(absf(core.global_position.x - before_continue) > 5.0, "same core continues responding after E")

	level.queue_free()
	await _frames(4)
	_write_log()
	print("L2_ACTIVE_RETURN_FORMAL pass=%d fail=%d" % [_pass, _fail])
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
		push_error("L2 ACTIVE RETURN FAIL: " + text)


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
