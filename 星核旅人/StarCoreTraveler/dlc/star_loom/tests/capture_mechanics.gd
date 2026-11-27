extends Node

## 640x360 evidence for the restored loom approach mechanics.
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/star_loom/tests/capture_mechanics.tscn
##
## Saves to res://screenshots/loom_mechanics_20261127/:
##   gate_closed.png       cyan body blocked by the sun gate, HUD names 辉相
##   gate_open.png         real Q to 辉相, same gate open
##   stone_socket.png      rune stone pushed onto the socket, moon gate open
##   stone_pulled_back.png real opposite-phase pull, stone off socket
##   checkpoint.png        checkpoint active after the moon gate
##
## The camera and HUD are the live 640x360 game view.  Placement is only used
## to frame the state; every gate/stone state is produced by the real phase
## comparison and the existing RuneStoneField sample.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://screenshots/loom_mechanics_20261127"

var _loom: StarLoom
var _player: L3Player
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	MechanicTips.mark_seen("loom_fire_tip")
	await _run()
	print("LOOM_MECHANICS_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


func _save(image_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(image_name))
	_saved.append(image_name)
	print("SHOT %s size=%dx%d error=%d" % [
		image_name, image.get_width(), image.get_height(), error
	])


func _place(x: float, positive: bool) -> void:
	_player.global_position = Vector2(x, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_loom.get_camera().reset_smoothing()
	await _wait_physics(4)
	await _wait_process(8)


func _tap_q() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(3)
	Input.action_release(&"polarity")
	await _wait_physics(5)


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		print("LOOM_MECHANICS_CAPTURE missing scene")
		return
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	_loom.show_intro_cinematic = false
	add_child(_loom)
	await _wait_process(6)
	await _wait_physics(10)
	_player = _loom.get_player()
	var gate_first: PolarityGate = _loom.get_gate_first()
	var stone: LoomRuneStone = _loom.get_rune_stone()

	# 1. Closed sun gate: the body is cyan, the gate is solid, the HUD line
	# names the gold phase.  Wait for the deny pulse so the padlock and red
	# ring are not a generic idle frame.
	await _place(139.0, false)
	await _wait_until(func() -> bool: return gate_first.get_deny_count() > 0, 60)
	await _wait_seconds(0.10)
	await _save("gate_closed.png")
	_check_state("gate_closed", not gate_first.is_open(),
		gate_first.get_collision_layer() == 1)

	# 2. Open sun gate: a real Q to gold.  Capture the 0.15 s two-leaf spread
	# in three consecutive frames (the AGENTS door-motion check), then the
	# settled open state.
	Input.action_press(&"polarity")
	await _wait_physics(2)
	Input.action_release(&"polarity")
	await _wait_physics(1)
	await _save("gate_opening_1.png")
	await _wait_physics(2)
	await _save("gate_opening_2.png")
	await _wait_physics(2)
	await _save("gate_opening_3.png")
	await _wait_seconds(0.12)
	await _save("gate_open.png")
	_check_state("gate_open", gate_first.is_open(),
		gate_first.get_collision_layer() == 0)
	await _tap_q()

	# 3. Stone on the socket, moon gate open.  The cyan body matches the cyan
	# stone and pushes it right; the event line reports the seating.  Wait the
	# last few pixels so the stone is visually centred in the groove.
	await _place(204.0, false)
	var socketed: bool = await _wait_until(
		func() -> bool: return stone.is_on_socket(), 420
	)
	await _wait_until(
		func() -> bool: return stone.global_position.x >= 329.5, 90
	)
	await _wait_seconds(0.18)
	await _save("stone_socket.png")
	_check_state("stone_socket", socketed and _loom.get_gate_second().is_open(),
		_loom.get_rune_socket().is_occupied())

	# 4. Pull it back with the opposite (gold) phase; the moon gate closes.
	# Wait until the stone has really travelled left, so the frame shows a
	# pulled-back stone rather than a 3 px "not on socket" edge case.
	await _tap_q()
	var pulled: bool = await _wait_until(
		func() -> bool: return not stone.is_on_socket(), 240
	)
	await _wait_until(
		func() -> bool:
			return stone.global_position.x <= _loom.get_rune_socket().global_position.x - 18.0,
		180
	)
	await _wait_seconds(0.12)
	await _save("stone_pulled_back.png")
	_check_state("stone_pulled_back", pulled and not _loom.get_gate_second().is_open(),
		not _loom.get_rune_socket().is_occupied())

	# 5. Push it back and walk on to the checkpoint.  The body stands just
	# left of the marker so the active 40x36 pedestal is not covered.
	await _tap_q()
	await _wait_until(func() -> bool: return stone.is_on_socket(), 420)
	await _place(386.0, false)
	await _wait_until(func() -> bool: return _loom.get_checkpoint().is_activated(), 120)
	await _wait_seconds(0.18)
	await _save("checkpoint.png")
	_check_state("checkpoint", _loom.get_checkpoint().is_activated(),
		absf(_player.global_position.x - _loom.get_checkpoint_position().x) < 30.0)

	# Release the gate cues and the scene before quitting; the capture tool is
	# not part of the suite, but a clean exit keeps its log usable.
	_loom.queue_free()
	await _wait_process(20)


func _check_state(frame_name: String, condition: bool, detail: bool) -> void:
	print("FRAME %s state=%s detail=%s" % [
		frame_name, "ok" if condition else "WRONG", str(detail)
	])
