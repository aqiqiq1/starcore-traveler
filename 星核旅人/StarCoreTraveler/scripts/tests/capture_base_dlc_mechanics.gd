extends Node

## 640x360 live-viewport evidence for the two base-story DLC mechanics.
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://scripts/tests/capture_base_dlc_mechanics.tscn
##
## Saves screenshots/base_dlc_mechanics_20261127/:
##   l1_gate_blocked.png  wrong-phase player held outside the moon gate
##   l1_gate_open.png     matching-phase player on the far side of the open gate
##   l2_veil_before.png   sun player approaching the violet inversion curtain
##   l2_veil_after.png    moon player past the curtain, HUD event row visible
##
## Every shot is the real level state; only test positioning/input is used.

const OUT_DIR: String = "res://screenshots/base_dlc_mechanics_20261127"
const L1_SCENE: String = "res://scenes/level_01.tscn"
const L2_SCENE: String = "res://scenes/level_02.tscn"

var _saved: Array[String] = []
var _level: Node = null


func _ready() -> void:
	await get_tree().process_frame
	await _capture_l1()
	await _capture_l2()
	print("BASE_DLC_MECHANICS_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0 if _saved.size() == 4 else 1)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	_saved.append(name)
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _tap_polarity() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(1)
	Input.action_release(&"polarity")
	await _wait_physics(4)


func _hold_right_until_x(player: PrototypePlayer, target: float, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	for _index: int in range(max_frames):
		if player.global_position.x >= target:
			Input.action_release(&"move_right")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	await _wait_physics(2)
	return player.global_position.x >= target


func _load(path: String, no_menu: bool = false) -> Node:
	_level = (load(path) as PackedScene).instantiate()
	if no_menu:
		_level.set("enable_start_menu", false)
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	get_tree().paused = false
	await _wait_process(8)
	return _level


func _cleanup() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	DemoAudio.stop_world()
	get_tree().paused = false
	get_tree().current_scene = null
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
	_level = null
	await _wait_process(10)


func _capture_l1() -> void:
	MechanicTips.mark_seen("polarity")
	var level: Node = await _load(L1_SCENE, true)
	level.call("_finish_intro")
	await _wait_process(8)
	var player: PrototypePlayer = level.call("get_player") as PrototypePlayer
	var gate: PolarityGate = level.call("get_exit_polarity_gate") as PolarityGate
	var camera: Camera2D = level.call("get_camera") as Camera2D
	if player == null or gate == null or camera == null:
		print("CAPTURE_FAIL l1 missing player/gate/camera")
		await _cleanup()
		return

	# Blocked: press the sun player into the moon gate with real movement.
	player.global_position = Vector2(1700.0, 300.0)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(true)
	camera.reset_smoothing()
	await _wait_physics(5)
	var deny_before: int = gate.get_deny_count()
	Input.action_press(&"move_right")
	for _index: int in range(90):
		await get_tree().physics_frame
		if gate.get_deny_count() > deny_before:
			break
	Input.action_release(&"move_right")
	await _wait_physics(2)
	await _save("l1_gate_blocked.png")

	# Open: Q to moon, let the deny hint expire, then walk past the open gate.
	await _tap_polarity()
	await _wait_seconds(1.6)
	await _hold_right_until_x(player, gate.global_position.x + 20.0, 80)
	await _wait_physics(4)
	await _save("l1_gate_open.png")
	await _cleanup()


func _capture_l2() -> void:
	MechanicTips.mark_seen("core_carry")
	MechanicTips.mark_seen("relay_link")
	var level: Node = await _load(L2_SCENE)
	await _wait_physics(8)
	var player: PrototypePlayer = level.call("get_player") as PrototypePlayer
	var field: RiftInversionField = level.call("get_inversion_field") as RiftInversionField
	var camera: Camera2D = level.call("get_camera") as Camera2D
	if player == null or field == null or camera == null:
		print("CAPTURE_FAIL l2 missing player/field/camera")
		await _cleanup()
		return

	# Before: sun player 40 px before the violet curtain.
	player.global_position = Vector2(720.0, 320.0)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(true)
	camera.reset_smoothing()
	await _wait_physics(5)
	await _save("l2_veil_before.png")

	# After: one real pass flips to moon and keeps the HUD event row visible.
	Input.action_press(&"move_right")
	for _index: int in range(120):
		await get_tree().physics_frame
		if field.get_trigger_count() > 0 \
				and player.global_position.x > field.global_position.x + 20.0:
			break
	Input.action_release(&"move_right")
	await _wait_physics(2)
	await _save("l2_veil_after.png")
	await _cleanup()
