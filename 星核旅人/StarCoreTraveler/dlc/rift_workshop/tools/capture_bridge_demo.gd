extends Node

## Re-records the "rift_bridge" guide strip from the formal rift scene.
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/rift_workshop/tools/capture_bridge_demo.tscn
##
## Why this tool exists: the 2026-11-26 strip showed the retired Q-fed bridge.
## The current chapter locks Q; the bridge is made permanent by killing the
## hovering wisp with a real J ("先熄桥上的光灵，再过桥").  This captures that
## current rule end to end:
##   frames 0-3   player stands on the gold deck, hazard wisp charging above it
##   frame  4     real J; the wisp pops and the chapter stabilises the deck
##   frames 5-11  pale locked deck + pop shards
##   frames 12-23 real move_right across the now-permanent deck
##
## Only placement and camera framing are debug calls.  No fake damage, no
## direct `kill()`, no phase change: the hit is the chapter's real swing path.
##
## Output: 24 frames x 8 fps x 256x144, horizontal strip + JSON in
## res://dlc/ui/demos/, the shared guide/popup demo folder.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://dlc/ui/demos"
const DEMO_ID: String = "rift_bridge"
const FRAME_WIDTH: int = 256
const FRAME_HEIGHT: int = 144
const FRAMES: int = 24
const FPS: float = 8.0
const CROP: Rect2i = Rect2i(190, 200, FRAME_WIDTH, FRAME_HEIGHT)
const PLAYER_X: float = 700.0
const PLAYER_Y: float = 280.0

var _rift: RiftWorkshop
var _player: L3Player
var _camera: Camera2D
var _wisp: RiftPolarityWisp
var _bridge: RiftPhaseBridge


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if packed == null:
		push_error("capture_bridge_demo: missing rift scene")
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(3)
	await _wait_physics(10)
	_player = _rift.get_player()
	_camera = _rift.get_camera()
	var hud: CanvasLayer = _rift.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	_bridge = _rift.get_bridge_a()
	_wisp = _rift.get_wisps()[0] if not _rift.get_wisps().is_empty() else null
	if _bridge == null or _wisp == null:
		push_error("capture_bridge_demo: bridge/wisp missing")
		return
	_player.global_position = Vector2(PLAYER_X, PLAYER_Y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(true)
	_player.face_direction(1)
	_player.cancel_attack()
	_player.clear_external_force()
	_camera.zoom = Vector2.ONE
	_camera.reset_smoothing()
	await _wait_physics(10)
	await _wait_seconds(0.30)
	print("BRIDGE_DEMO start solid=%s stable=%s wisp=%s wisp_pos=%s player=%s" % [
		str(_bridge.is_solid()), str(_bridge.is_stabilized()),
		str(_wisp.is_alive()), str(_wisp.global_position),
		str(_player.global_position)
	])

	var frames: Array[Image] = []
	for index: int in range(FRAMES):
		if index == 4:
			_real_key(KEY_J, true)
		elif index == 5:
			_real_key(KEY_J, false)
		elif index == 12:
			Input.action_press(&"move_right")
		elif index == 21:
			Input.action_release(&"move_right")
		await _wait_seconds(1.0 / FPS)
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		if shot == null:
			push_error("capture_bridge_demo: no viewport image")
			return
		var frame: Image = shot.get_region(CROP)
		if frame.get_format() != Image.FORMAT_RGBA8:
			frame.convert(Image.FORMAT_RGBA8)
		frames.append(frame)
	Input.action_release(&"move_right")
	print("BRIDGE_DEMO end solid=%s stable=%s wisp_alive=%s player_x=%.1f" % [
		str(_bridge.is_solid()), str(_bridge.is_stabilized()),
		str(_wisp.is_alive()), _player.global_position.x
	])

	if frames.size() != FRAMES:
		push_error("capture_bridge_demo: wrong frame count")
		return
	var strip: Image = Image.create(FRAME_WIDTH * FRAMES, FRAME_HEIGHT, false, Image.FORMAT_RGBA8)
	for index: int in range(frames.size()):
		strip.blit_rect(
			frames[index], Rect2i(0, 0, FRAME_WIDTH, FRAME_HEIGHT),
			Vector2i(index * FRAME_WIDTH, 0)
		)
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var error: Error = strip.save_png(directory.path_join("%s.png" % DEMO_ID))
	var data: Dictionary = {
		"id": DEMO_ID,
		"source": "formal DLC scene, real J hit and real walk",
		"frames": FRAMES,
		"fps": FPS,
		"frame_width": FRAME_WIDTH,
		"frame_height": FRAME_HEIGHT,
		"crop": {"x": CROP.position.x, "y": CROP.position.y, "w": FRAME_WIDTH, "h": FRAME_HEIGHT},
		"camera": {"zoom": 1.0, "wide_limits": false},
		"note": "Formal rift terrace. Current rule: the gold deck is only solid on its phase. A real J at frame 4 kills the hovering wisp; the chapter then marks the deck stable (pale locked core) and it stays solid for either phase. Frames 12-23 walk across the permanent deck. No Q, no fake kill.",
	}
	var file: FileAccess = FileAccess.open(
		directory.path_join("%s.json" % DEMO_ID), FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	print("BRIDGE_DEMO frames=%d size=%dx%d error=%d crop=%s" % [
		frames.size(), strip.get_width(), strip.get_height(), error, str(CROP)
	])
	get_tree().current_scene = null
	_rift.queue_free()
	await _wait_process(4)


func _real_key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame
