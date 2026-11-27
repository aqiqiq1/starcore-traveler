extends Node

## 640x360 evidence for the 2026-11-27 form-3 crack layering fix.
##
## Run WITHOUT --headless (the live viewport is 640x360):
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://dlc/rift_workshop/tests/capture_phase3_layers.tscn
##
## Saves:
##   screenshots/rift_phase3_20261127/rift_phase3_faces_over_cracks.png
##
## The shot waits until an orbiting face plate is actually over the long
## centre crack (|face local x| < 3 px), so the saved frame proves the plate
## covers the crack rather than merely showing a form-3 pose.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://screenshots/rift_phase3_20261127"
const OUT_NAME: String = "rift_phase3_faces_over_cracks.png"

var _rift: RiftWorkshop
var _player: L3Player


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


func _wait_ms(duration_ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _save() -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(OUT_NAME))
	print("SHOT %s size=%dx%d error=%d" % [
		OUT_NAME, image.get_width(), image.get_height(), error
	])


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)
	await _wait_process(8)


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _jab() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(3)
	_push_key(KEY_J, false)
	await _wait_physics(45)


func _close_popup_if_open() -> void:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)


func _core_hits(boss: RiftMirrorBoss, count: int) -> void:
	for _index: int in range(count):
		await _place(boss.global_position.x - 20.0, 320.0, true)
		await _jab()


func _run() -> void:
	_rift = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(6)
	await _wait_physics(10)
	_player = _rift.get_player()

	await _place(1250.0, 320.0, true)
	await _wait_until(func() -> bool: return _rift.is_arena_entered(), 120)
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 200)
	await _wait_process(2)
	await _close_popup_if_open()
	var boss: RiftMirrorBoss = _rift.get_boss()
	await _wait_until(
		func() -> bool:
			return boss.is_active() and boss.get_attack_state_name() != "INTRO", 240
	)
	boss.set_attacks_enabled(false)

	# Form 1 -> 2 -> 3 without a 15-hit playthrough; the presentation layers
	# are what this capture proves.
	boss.debug_shatter_face(true)
	boss.debug_shatter_face(false)
	await _core_hits(boss, 3)
	await _wait_until(func() -> bool: return boss.get_phase_number() == 2, 180)
	boss.debug_shatter_face(true)
	boss.debug_shatter_face(false)
	await _core_hits(boss, 3)
	await _wait_until(func() -> bool: return boss.get_phase_number() == 3, 240)
	await _wait_process(4)
	await _place(boss.global_position.x - 150.0, 320.0, true)

	# Wait until one plate crosses the long centre crack.
	var crossed: bool = await _wait_until(
		func() -> bool:
			var gold_x: float = boss.get_face_center_local(true).x
			var cyan_x: float = boss.get_face_center_local(false).x
			return absf(gold_x) <= 3.0 or absf(cyan_x) <= 3.0,
		360
	)
	await _wait_process(2)
	await _save()
	var crack_layer: Node2D = boss.get_crack_layer()
	var gold: Sprite2D = boss.get_face_sprite(true)
	var cyan: Sprite2D = boss.get_face_sprite(false)
	print("STATE form=%d crossed=%s crack_abs_z=%d gold_abs_z=%d cyan_abs_z=%d" % [
		boss.get_phase_number(), str(crossed),
		boss.z_index + crack_layer.z_index,
		boss.z_index + gold.z_index,
		boss.z_index + cyan.z_index,
	])
	print("STATE face_local gold=%s cyan=%s crack_alpha=%.2f" % [
		str(boss.get_face_center_local(true)),
		str(boss.get_face_center_local(false)),
		float(crack_layer.call("get_crack_alpha")),
	])
