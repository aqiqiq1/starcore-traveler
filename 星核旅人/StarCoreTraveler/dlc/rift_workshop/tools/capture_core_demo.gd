extends Node

## Captures the core tip demo strip: "rift_core".
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/rift_workshop/tools/capture_core_demo.tscn
##
## 24 frames x 8 fps, 256x144, written as one horizontal strip + JSON sidecar
## under res://dlc/ui/demos/.  The formal rift scene is used end to end:
##   - the boss's own defeat path is used through debug_force_defeat();
##   - the chapter's own boss-defeat handler opens the finish core;
##   - the finish core texture is whatever the live scene uses.  On
##     2026-11-28 that is still assets/level03_prototype/key_core_12f.png;
##     showing the new star core would require a scene texture change, which
##     is not part of this capture tool;
##   - the player walks from 40 px to 22 px from the core (outside the 18 px
##     completion radius) with the player's existing cinematic walk, then stops.
## No J input, damage or completion state is used.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://dlc/ui/demos"
const DEMO_ID: String = "rift_core"
const FRAME_WIDTH: int = 256
const FRAME_HEIGHT: int = 144
const FRAMES: int = 24
const FPS: float = 8.0
const CORE_X: float = 1850.0
## 40 world px -> 22 world px from the core; 18 px is the completion radius.
const APPROACH_START_X: float = CORE_X - 40.0
const APPROACH_STOP_X: float = CORE_X - 22.0
## 0.15 of walk speed is 15 px/s, so the 18 px approach lasts about 1.2 s.
const APPROACH_AXIS: float = 0.15
const CROP: Rect2i = Rect2i(188, 80, FRAME_WIDTH, FRAME_HEIGHT)

var _rift: RiftWorkshop
var _player: L3Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if packed == null:
		push_error("capture_core_demo: missing rift scene")
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	# The 2026-11-27 intro film suspends the boss until the arena is entered.
	# This capture is a post-fight state, so skip the film and wake the boss for
	# its own collapse clock; no gameplay rule is changed.
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(3)
	await _wait_physics(8)
	_player = _rift.get_player()
	var hud: CanvasLayer = _rift.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false

	var boss: RiftMirrorBoss = _rift.get_boss()
	# Setup only: use the boss's own defeat path, then the real chapter handler
	# lights the finish core and opens the core tip.
	boss.set_suspended(false)
	boss.debug_force_defeat()
	for _index: int in range(240):
		if _rift.is_boss_defeated() and _rift.get_finish_sprite().modulate.r > 0.9:
			break
		await get_tree().physics_frame
	await _close_core_tip()

	_player.global_position = Vector2(APPROACH_START_X, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(true)
	_player.face_direction(1)
	_player.cancel_attack()
	_player.clear_external_force()
	_set_wide_camera(0.4)
	_player.begin_cinematic_walk(APPROACH_AXIS)
	await _wait_physics(4)
	_sync_camera_to_core()
	print("CORE_DEMO start boss_down=%s core_r=%.2f player_x=%.1f" % [
		str(_rift.is_boss_defeated()), _rift.get_finish_sprite().modulate.r,
		_player.global_position.x
	])

	var frames: Array[Image] = []
	var walking: bool = true
	for index: int in range(FRAMES):
		if walking and _player.global_position.x >= APPROACH_STOP_X:
			_player.global_position.x = APPROACH_STOP_X
			_player.velocity = Vector2.ZERO
			_player.end_cinematic_walk()
			walking = false
		elif not walking:
			_player.global_position = Vector2(APPROACH_STOP_X, 320.0)
			_player.velocity = Vector2.ZERO
		_player.face_direction(1)
		# The camera is deliberately offset from the player so the core stays
		# fixed near the centre of the 256 px crop while the body approaches it.
		_sync_camera_to_core()
		await _wait_seconds(1.0 / FPS)
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		if shot == null:
			push_error("capture_core_demo: no viewport image")
			return
		var frame: Image = shot.get_region(CROP)
		if frame.get_format() != Image.FORMAT_RGBA8:
			frame.convert(Image.FORMAT_RGBA8)
		frames.append(frame)
	if walking:
		_player.global_position.x = APPROACH_STOP_X
		_player.velocity = Vector2.ZERO
		_player.end_cinematic_walk()
	print("CORE_DEMO end player_x=%.1f core_distance=%.1f core_r=%.2f" % [
		_player.global_position.x, CORE_X - _player.global_position.x,
		_rift.get_finish_sprite().modulate.r
	])

	var strip: Image = Image.create(FRAME_WIDTH * FRAMES, FRAME_HEIGHT, false, Image.FORMAT_RGBA8)
	for index: int in range(frames.size()):
		strip.blit_rect(
			frames[index], Rect2i(0, 0, FRAME_WIDTH, FRAME_HEIGHT),
			Vector2i(index * FRAME_WIDTH, 0)
		)
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var png_path: String = directory.path_join("%s.png" % DEMO_ID)
	var error: Error = strip.save_png(png_path)
	var data: Dictionary = {
		"id": DEMO_ID,
		"source": "formal DLC scene, real defeated state, real cinematic walk",
		"frames": FRAMES,
		"fps": FPS,
		"frame_width": FRAME_WIDTH,
		"frame_height": FRAME_HEIGHT,
		"crop": {"x": CROP.position.x, "y": CROP.position.y, "w": FRAME_WIDTH, "h": FRAME_HEIGHT},
		"camera": {"zoom": 0.4, "wide_limits": true},
		"note": "Formal rift core. The double-mirror boss is put through its real defeat path; the chapter's boss-defeat handler lights the core. The player walks with the player's own cinematic-walk API from 40 px to 22 px from the core (outside the 18 px completion radius), then stops. No J input is sent. The core's own 12-frame animation runs.",
	}
	var file: FileAccess = FileAccess.open(
		directory.path_join("%s.json" % DEMO_ID), FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	print("CORE_DEMO frames=%d size=%dx%d error=%d crop=%s" % [
		frames.size(), strip.get_width(), strip.get_height(), error, str(CROP)
	])
	get_tree().current_scene = null
	_rift.queue_free()
	await _wait_process(4)


func _close_core_tip() -> void:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null:
		return
	for _index: int in range(180):
		if popup.is_open():
			break
		await get_tree().process_frame
	if not popup.is_open():
		return
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(6)
	print("CORE_DEMO core_tip_closed=%s paused=%s" % [
		str(not popup.is_open()), str(get_tree().paused)
	])


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	Input.parse_input_event(event)


func _set_wide_camera(zoom_value: float) -> void:
	var camera: Camera2D = _rift.get_camera()
	camera.limit_smoothed = false
	camera.limit_left = -2000
	camera.limit_top = -2000
	camera.limit_right = 4000
	camera.limit_bottom = 2000
	camera.zoom = Vector2(zoom_value, zoom_value)
	camera.position = Vector2(0.0, 0.0)
	camera.reset_smoothing()


func _sync_camera_to_core() -> void:
	var camera: Camera2D = _rift.get_camera()
	camera.position = Vector2(CORE_X - _player.global_position.x, 0.0)
	camera.reset_smoothing()


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame
