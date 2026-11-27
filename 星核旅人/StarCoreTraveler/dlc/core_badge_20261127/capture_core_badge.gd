extends Node

## 640x360 + nearest-neighbour 4x evidence for the 2026-11-27 core/badge pass.
## Run WITHOUT --headless (the viewport must render):
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/core_badge_20261127/capture_core_badge.tscn
##
## Saves to res://screenshots/core_badge_20261127/:
##   00_l1_delivery_640.png            real L1 opening film, 18.85 s handoff
##   00_l1_delivery_core_4x.png        4x crop around the handed-over core
##   01_dlc3_cyan_core_in_bay_640.png  real DLC3 push: cyan core seated, moon gate open
##   01_dlc3_cyan_core_in_bay_4x.png   4x crop of the lit bay/core
##   02_completion_emblem_640.png      real L1 completion callback + new emblem
##   02_completion_emblem_4x.png       4x crop of the top-right emblem
##   03_float_device_640.png           L3 fixed device (platform starter), active
##   03_float_device_4x.png            4x crop of the device/core
##   03b_float_device_idle_640.png     same device in its locked/idle state
##
## The L1/DLC3/completion frames use the real scene callbacks and the real
## RuneStoneField push.  The device frame uses the real activate() state; its
## normal E reach is covered by the level route tests, not posed here.

const OUT_DIR: String = "res://screenshots/core_badge_20261127"
const L1: String = "res://scenes/level_01.tscn"
const L3: String = "res://scenes/level_03.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"

var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _capture_l1()
	await _capture_loom()
	await _capture_completion()
	await _capture_device()
	print("CORE_BADGE_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0 if _saved.size() >= 8 else 1)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _press_f() -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_F
	down.keycode = KEY_F
	down.pressed = true
	get_viewport().push_input(down)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_F
	up.keycode = KEY_F
	up.pressed = false
	get_viewport().push_input(up)


func _wait_page_ready(echo: Node) -> void:
	var deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		if echo == null or not bool(echo.call("is_dialogue_open")):
			return
		var full: String = String(echo.call("get_full_page_text"))
		if int(echo.call("get_revealed_count")) >= full.length():
			return
		await get_tree().process_frame


func _save(image_name: String, detail_rect: Rect2i = Rect2i(), detail_scale: int = 4) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(image_name))
	_saved.append(image_name)
	print("SHOT %s size=%dx%d error=%d" % [
		image_name, image.get_width(), image.get_height(), error
	])
	if detail_rect.size.x <= 0 or detail_rect.size.y <= 0:
		return
	var clamped: Rect2i = detail_rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if clamped.size.x <= 0 or clamped.size.y <= 0:
		return
	var crop: Image = image.get_region(clamped)
	crop.resize(clamped.size.x * detail_scale, clamped.size.y * detail_scale,
		Image.INTERPOLATE_NEAREST)
	var detail_name: String = image_name.get_basename() + "_%dx.png" % detail_scale
	var detail_error: Error = crop.save_png(directory.path_join(detail_name))
	_saved.append(detail_name)
	print("SHOT %s size=%dx%d error=%d" % [
		detail_name, crop.get_width(), crop.get_height(), detail_error
	])


func _cleanup(level: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	if is_instance_valid(level):
		level.queue_free()
	await _wait_process(8)


func _crop_around(node: Node2D, size: Vector2i) -> Rect2i:
	if node == null:
		return Rect2i()
	var screen: Vector2 = node.get_global_transform_with_canvas().origin
	return Rect2i(
		Vector2i(roundi(screen.x - float(size.x) * 0.5),
			roundi(screen.y - float(size.y) * 0.5)),
		size
	)


func _capture_l1() -> void:
	var packed: PackedScene = load(L1) as PackedScene
	if packed == null:
		print("CORE_BADGE_CAPTURE missing L1")
		return
	var level: Node = packed.instantiate()
	level.set("enable_start_menu", false)
	add_child(level)
	await _wait_process(8)
	var opening: Node = level.get_node_or_null("OpeningCinematic")
	if opening == null:
		await _cleanup(level)
		return
	# The real opening film holds three echo pages before the handoff.  Use the
	# same real F route as the opening capture so the frame is the handoff, not
	# the dialogue overlay.  The echo node only exists once its first page is
	# close to opening, so poll for it instead of reading it at frame 8.
	var echo: Node = null
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		echo = opening.call("get_dialogue_echo") as Node
		if echo != null and bool(echo.call("is_dialogue_open")):
			break
		await get_tree().process_frame
	var guard: int = 0
	while echo != null and bool(echo.call("is_dialogue_open")) and guard < 12:
		await _wait_page_ready(echo)
		_press_f()
		await _wait_process(6)
		guard += 1
	deadline = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if not bool(opening.call("is_active")):
			break
		if float(opening.call("get_elapsed")) >= 18.85:
			break
		await get_tree().process_frame
	var player: Node2D = level.get_node_or_null("World/Player") as Node2D
	var core: Node2D = level.find_child("OpeningStarCore", true, false) as Node2D
	var core_started: bool = core != null and core.visible and core.position.length() > 4.0
	var focus: Node2D = core if core_started else player
	print("FRAME L1_HANDOFF core=%s player=%s" % [
		str(core.position) if core != null else "none",
		str(player.global_position) if player != null else "none"
	])
	if focus == null:
		await _save("00_l1_delivery_640.png")
	else:
		await _save("00_l1_delivery_640.png", _crop_around(focus, Vector2i(80, 64)))
	await _cleanup(level)


func _capture_loom() -> void:
	var packed: PackedScene = load(LOOM) as PackedScene
	if packed == null:
		print("CORE_BADGE_CAPTURE missing DLC3")
		return
	var loom: Node = packed.instantiate()
	loom.set("show_intro_guide", false)
	loom.set("show_intro_cinematic", false)
	add_child(loom)
	await _wait_process(8)
	await _wait_physics(10)
	var player: Node2D = loom.call("get_player") as Node2D
	var carrier: CoreDeliveryCarrier = loom.call("get_core_carrier") as CoreDeliveryCarrier
	var bay: CoreDeliveryBay = loom.call("get_core_bay") as CoreDeliveryBay
	if player == null or carrier == null or bay == null:
		await _cleanup(loom)
		return
	# The real same-phase push: stand left of the cyan core in 澜相 and let the
	# shared RuneStoneField carry it into the x=330 bay.
	player.global_position = Vector2(204.0, 320.0)
	player.velocity = Vector2.ZERO
	player.call("set_polarity_state", false)
	player.call("face_direction", 1)
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
	for _index: int in range(420):
		if carrier.is_on_socket():
			break
		await get_tree().physics_frame
	await _wait_seconds(0.22)
	var visual: StarCoreVisual = carrier.get_core_visual()
	if visual != null:
		visual.set_animation_frame(0)
	await _save("01_dlc3_cyan_core_in_bay_640.png", Rect2i(250, 246, 130, 86))
	var state_ok: bool = carrier.is_on_socket() and bay.is_lit() \
		and visual != null and visual.state == StarCoreVisual.CoreState.NEGATIVE
	print("FRAME DLC3_CYAN_IN_BAY state=%s core=%.1f bay=%s gate=%s" % [
		"ok" if state_ok else "WRONG",
		carrier.global_position.x,
		str(bay.is_lit()),
		str(bool(loom.call("is_second_gate_powered")))
	])
	await _cleanup(loom)


func _capture_completion() -> void:
	var packed: PackedScene = load(L1) as PackedScene
	if packed == null:
		print("CORE_BADGE_CAPTURE missing L1 completion")
		return
	var level: Node = packed.instantiate()
	level.set("enable_start_menu", false)
	add_child(level)
	await _wait_process(6)
	level.call("_finish_intro")
	await _wait_process(10)
	await _wait_seconds(1.2)
	level.call("_on_exit_reached")
	await _wait_seconds(0.40)
	# L1 panel is at (120,80); the emblem sits at panel + (356,12).
	await _save("02_completion_emblem_640.png", Rect2i(466, 84, 72, 56))
	await _cleanup(level)


func _capture_device() -> void:
	var packed: PackedScene = load(L3) as PackedScene
	if packed == null:
		print("CORE_BADGE_CAPTURE missing L3")
		return
	var level: Node = packed.instantiate()
	level.set("show_intro_guide", false)
	level.set("show_intro_cinematic", false)
	add_child(level)
	await _wait_process(10)
	var player: Node2D = level.get_node_or_null("Player") as Node2D
	var device: L3FixedDevice = level.get_node_or_null("FixedDevice") as L3FixedDevice
	if player == null or device == null:
		await _cleanup(level)
		return
	# Frame the device from the normal 640x360 camera; the device is in the
	# upper route at (290,130), so the player is moved to its x on the floor.
	player.global_position = Vector2(290.0, 320.0)
	player.velocity = Vector2.ZERO
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
	await _wait_seconds(0.25)
	await _save("03b_float_device_idle_640.png")
	device.activate()
	await _wait_process(4)
	await _wait_seconds(0.20)
	await _save("03_float_device_640.png", Rect2i(246, 82, 88, 64))
	var visual: StarCoreVisual = device.get_core_visual()
	print("FRAME FLOAT_DEVICE path=%s frames=%d active=%s" % [
		device.get_texture_path(),
		visual.get_animation_frame_count() if visual != null else -1,
		str(device.is_active())
	])
	await _cleanup(level)
