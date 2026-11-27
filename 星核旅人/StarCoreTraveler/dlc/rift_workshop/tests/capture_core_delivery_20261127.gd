extends Node

## 640x360 evidence for the DLC2 star-core delivery before GateMoon.
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/rift_workshop/tests/capture_core_delivery_20261127.tscn
##
## Saves to res://screenshots/rift_core_20261127/:
##  01_core_before_bay.png        core at its start, bay dark, moon gate closed
##  02_core_in_transit.png        same-phase field is pushing it toward the bay
##  03_core_seated_lit.png        core seated, bay lit, first moon gate open
##  04_core_pulled_door_closed.png real opposite-phase pull, bay dark, gate shut
##  05_reseated_gate_open.png     pushed back in with the real curtain, no softlock
##
## Each full frame is the live 640x360 viewport with the HUD.  A nearest-
## neighbour 3x detail crop of the core/bay/gate area is saved next to it.
## Placement is only used to frame the state; every bay/gate state comes from
## the shared field sample and the real carrier x position.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://screenshots/rift_core_20261127"
const DETAIL_RECT: Rect2i = Rect2i(170, 244, 160, 86)

var _rift: RiftWorkshop
var _player: L3Player
var _carrier: CoreDeliveryCarrier
var _bay: CoreDeliveryBay
var _gate: PolarityGate
var _field: RiftInversionField
var _saved: Array[String] = []
var _failures: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("RIFT_CORE_CAPTURE saved=%d failures=%d files=%s" % [
		_saved.size(), _failures, ", ".join(_saved)
	])
	get_tree().quit(1 if _failures > 0 else 0)


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
	var crop: Image = image.get_region(DETAIL_RECT)
	crop.resize(DETAIL_RECT.size.x * 3, DETAIL_RECT.size.y * 3,
		Image.INTERPOLATE_NEAREST)
	var detail_name: String = image_name.get_basename() + "_detail_3x.png"
	var detail_error: Error = crop.save_png(directory.path_join(detail_name))
	_saved.append(detail_name)
	print("SHOT %s size=%dx%d error=%d" % [
		detail_name, crop.get_width(), crop.get_height(), detail_error
	])


func _place(x: float, positive: bool) -> void:
	_player.global_position = Vector2(x, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.face_direction(1)
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)
	await _wait_process(8)


func _walk_to(target: float, moving_right: bool, max_frames: int) -> bool:
	var action: StringName = &"move_right" if moving_right else &"move_left"
	Input.action_press(action)
	var reached: bool = await _wait_until(
		func() -> bool:
			if moving_right:
				return _player.global_position.x >= target
			return _player.global_position.x <= target,
		max_frames
	)
	Input.action_release(action)
	await _wait_physics(2)
	return reached


func _show_core_frame(zero: int = 0) -> void:
	var visual: StarCoreVisual = _carrier.get_core_visual()
	if visual != null:
		visual.set_animation_frame(zero)


func _check_state(frame_name: String, condition: bool, detail: String) -> void:
	if condition:
		print("FRAME %s state=ok detail=%s" % [frame_name, detail])
		return
	_failures += 1
	print("FRAME %s state=WRONG detail=%s" % [frame_name, detail])


func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if packed == null:
		print("RIFT_CORE_CAPTURE missing scene")
		_failures += 1
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	add_child(_rift)
	await _wait_process(6)
	await _wait_physics(10)
	_player = _rift.get_player()
	_carrier = _rift.get_core_carrier()
	_bay = _rift.get_core_bay()
	_gate = _rift.get_gate_moon()
	_field = _rift.get_field_a()
	if _player == null or _carrier == null or _bay == null or _gate == null:
		print("RIFT_CORE_CAPTURE missing nodes")
		_failures += 1
		return

	# 1. Core at its authored start, bay dark, gate solid.  At x=40 the body is
	# outside the tuned 120 px field, so the core really stays put.
	await _place(40.0, true)
	_carrier.reset_state()
	await _wait_seconds(0.22)
	_show_core_frame(0)
	await _save("01_core_before_bay.png")
	_check_state("01_core_before_bay",
		not _carrier.is_on_socket() and not _bay.is_lit()
		and _gate.is_blocking() and _field.get_trigger_count() == 0,
		"core=%.1f bay=%s gate=%s triggers=%d" % [
			_carrier.global_position.x, str(_bay.is_lit()),
			str(_gate.is_blocking()), _field.get_trigger_count()
		])

	# 2. Real curtain crossing -> 澜相 -> same-phase push.  Pause on the frame
	# where the core is between min_x and the socket, so the evidence is not
	# blurred by the 140 px/s travel.
	await _place(130.0, true)
	Input.action_press(&"move_right")
	var caught: bool = false
	for _index: int in range(360):
		if (
			_field.get_trigger_count() >= 1
			and _carrier.global_position.x >= 218.0
			and _carrier.global_position.x <= 232.0
		):
			caught = true
			break
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	if caught:
		get_tree().paused = true
	_show_core_frame(0)
	await _save("02_core_in_transit.png")
	_check_state("02_core_in_transit",
		caught and not _carrier.is_on_socket() and not _bay.is_lit(),
		"core=%.1f bay=%s triggers=%d" % [
			_carrier.global_position.x, str(_bay.is_lit()),
			_field.get_trigger_count()
		])
	get_tree().paused = false
	await _wait_physics(2)

	# 3. Seated: the bay lights, its conduit carries power, and GateMoon opens.
	var seated: bool = await _wait_until(
		func() -> bool: return _carrier.is_on_socket(), 240
	)
	await _wait_until(
		func() -> bool: return _bay.get_lit_blend() >= 0.95, 120
	)
	await _wait_seconds(0.22)
	_show_core_frame(0)
	await _save("03_core_seated_lit.png")
	_check_state("03_core_seated_lit",
		seated and _bay.is_lit() and not _gate.is_blocking()
		and _rift.get_hud().get_event_text().contains("青核入仓"),
		"core=%.1f bay=%s gate=%s event=%s" % [
			_carrier.global_position.x, str(_bay.is_lit()),
			str(_gate.is_blocking()), _rift.get_hud().get_event_text()
		])

	# 4. Step out of the curtain first (exiting does not flip), then walk back
	# into it from the right: the body becomes 辉相, the core is attracted out
	# of the bay, the conduit goes dark and GateMoon closes.
	await _place(235.0, false)
	var walked_left: bool = await _walk_to(130.0, false, 240)
	var pulled: bool = await _wait_until(
		func() -> bool: return not _carrier.is_on_socket(), 240
	)
	await _wait_until(
		func() -> bool: return _carrier.global_position.x <= 190.0, 180
	)
	await _wait_until(
		func() -> bool: return _bay.get_lit_blend() <= 0.05, 120
	)
	await _wait_seconds(0.18)
	_show_core_frame(0)
	await _save("04_core_pulled_door_closed.png")
	_check_state("04_core_pulled_door_closed",
		walked_left and pulled and not _bay.is_lit()
		and _gate.is_blocking() and _player.is_positive()
		and _rift.get_hud().get_event_text().contains("青核离仓"),
		"core=%.1f bay=%s gate=%s positive=%s event=%s" % [
			_carrier.global_position.x, str(_bay.is_lit()),
			str(_gate.is_blocking()), str(_player.is_positive()),
			_rift.get_hud().get_event_text()
		])

	# 5. Recover: cross the curtain again and push it back in.  This is the
	# same real loop a player uses, proving there is no soft lock.
	var walked_right: bool = await _walk_to(165.0, true, 240)
	var reseated: bool = await _wait_until(
		func() -> bool: return _carrier.is_on_socket(), 300
	)
	await _wait_until(
		func() -> bool: return _bay.get_lit_blend() >= 0.95, 120
	)
	await _wait_seconds(0.20)
	_show_core_frame(0)
	await _save("05_reseated_gate_open.png")
	_check_state("05_reseated_gate_open",
		walked_right and reseated and _bay.is_lit()
		and not _gate.is_blocking(),
		"core=%.1f bay=%s gate=%s triggers=%d" % [
			_carrier.global_position.x, str(_bay.is_lit()),
			str(_gate.is_blocking()), _field.get_trigger_count()
		])

	_input_release_all()
	_rift.queue_free()
	await _wait_process(20)


func _input_release_all() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity"]:
		Input.action_release(action)
