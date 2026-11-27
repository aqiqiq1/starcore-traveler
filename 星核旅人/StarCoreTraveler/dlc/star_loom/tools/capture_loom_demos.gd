extends Node

## Captures the real-gameplay guide demo strips for the city 星核织机.
## Run WITHOUT --headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/star_loom/tools/capture_loom_demos.tscn
##
## Every clip is recorded from the formal dlc/star_loom/star_loom.tscn scene at
## 256x144, 24 frames, 8 fps, and written as one horizontal strip + a JSON
## sidecar in dlc/ui/demos/ (the shared guide's demo directory):
##   loom_nodes.png/json  same-phase bounce, real Q, opposite-phase node break
##   loom_fire.png/json   stage 2 floor-fire warning/flames and sweep warning
##   loom_gear.png/json   stage 3 gear warning/roll and a summoned wisp
##
## The 2026-11-28 pass only re-captures loom_nodes, because its shielded loom
## core changed after the 2026-11-26 strip.  The fire/gear strips still match
## the live scene and are not overwritten.  loom_core was retired with the old
## entry/core popups, so its capture path is gone too.
##
## Debug calls only place the player, park a node's orbit or advance the stage.
## Every Q / J / jump shown is a real input event resolved by the chapter and
## the shared L3Player; the frames are the live viewport.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://dlc/ui/demos"
const FRAME_WIDTH: int = 256
const FRAME_HEIGHT: int = 144
const FRAMES: int = 24
const FPS: float = 8.0

var _level: StarLoom
var _player: L3Player
var _camera: Camera2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _capture_nodes()
	print("LOOM_DEMO_CAPTURE_DONE")
	get_tree().quit(0)


# --- clips ----------------------------------------------------------------

func _capture_nodes() -> void:
	await _load_level()
	_player.global_position = Vector2(660.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(true)
	_player.face_direction(1)
	_player.cancel_attack()
	_level.debug_set_attacks_enabled(false)
	_level.debug_set_boss_grace(0.0)
	_level.debug_set_node_angle(0, PI * 0.5)
	_level.debug_set_node_phase(0, true)
	_level.debug_set_node_angle(1, -PI * 0.5)
	_level.debug_set_node_phase(1, false)
	for node: LoomNode in _level.get_nodes():
		node.set_orbit_enabled(false)
		node.set_phase_timer_enabled(false)
	_set_wide_camera(0.75, Vector2(700.0, 235.0))
	await _wait_seconds(0.35)
	await _record(
		"loom_nodes", Rect2i(190, 120, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_nodes,
		"Formal city star_loom hall. The gold bottom node bounces a same-phase real J; a real Q switches to cyan and the next real J breaks the node.",
		{"zoom": 0.75, "wide_limits": true}
	)
	await _free_level()


func _tick_nodes(index: int) -> void:
	if index == 4:
		_real_key(KEY_J, true)
	elif index == 5:
		_real_key(KEY_J, false)
	elif index == 10:
		Input.action_press(&"polarity")
	elif index == 11:
		Input.action_release(&"polarity")
	elif index == 14:
		_real_key(KEY_J, true)
	elif index == 15:
		_real_key(KEY_J, false)


func _capture_fire() -> void:
	await _load_level()
	_level.debug_set_stage(2)
	_level.debug_set_attacks_enabled(true)
	_level.debug_set_boss_grace(0.0)
	_player.global_position = Vector2(700.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(1)
	_player.cancel_attack()
	_set_wide_camera(0.55, Vector2(700.0, 240.0))
	await _wait_seconds(0.35)
	await _record(
		"loom_fire", Rect2i(190, 100, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_fire,
		"Formal city star_loom stage 2. Real floor-fire warning at two lit vents, then flame columns; a sweep warning follows at the right edge.",
		{"zoom": 0.55, "wide_limits": true}
	)
	await _free_level()


func _tick_fire(index: int) -> void:
	if index == 0:
		_level.debug_force_attack("fire")
	elif index == 14:
		_level.debug_force_attack("sweep")


func _capture_gear() -> void:
	await _load_level()
	_level.debug_set_stage(3)
	_level.debug_set_attacks_enabled(true)
	_level.debug_set_boss_grace(0.0)
	_player.global_position = Vector2(700.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(1)
	_player.cancel_attack()
	_set_wide_camera(0.55, Vector2(700.0, 240.0))
	await _wait_seconds(0.35)
	await _record(
		"loom_gear", Rect2i(190, 100, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_gear,
		"Formal city star_loom stage 3. Edge gear warning, real gears rolling inward, and a summoned rift wisp under a real jump.",
		{"zoom": 0.55, "wide_limits": true}
	)
	await _free_level()


func _tick_gear(index: int) -> void:
	if index == 0:
		_level.debug_force_attack("gear")
	elif index == 10:
		_level.debug_force_attack("summon")
	elif index == 19:
		Input.action_press(&"jump")
	elif index == 20:
		Input.action_release(&"jump")


# --- shared capture -------------------------------------------------------

func _load_level() -> void:
	_release_inputs()
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	_level = packed.instantiate() as StarLoom
	_level.show_intro_guide = false
	# The 2026-11-27 opening film would fade the hall and draw its own orbit
	# rings; these strips must show the live fight only.
	_level.show_intro_cinematic = false
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(3)
	await _wait_physics(10)
	_player = _level.get_player()
	_camera = _level.get_camera()
	var hud: CanvasLayer = _level.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	_player.cancel_attack()
	_player.velocity = Vector2.ZERO
	# Put the boss in its active state before the first recorded frame.
	_player.global_position = Vector2(440.0, 320.0)
	await _wait_physics(4)
	_level.debug_set_attacks_enabled(false)
	_level.debug_set_boss_grace(0.0)


func _free_level() -> void:
	_release_inputs()
	await _wait_process(2)
	get_tree().current_scene = null
	if _level != null:
		_level.queue_free()
		_level = null
	await _wait_process(6)


func _release_inputs() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	Input.action_release(&"jump")
	_real_key(KEY_J, false)


func _set_wide_camera(zoom_value: float, center: Vector2) -> void:
	_camera.limit_smoothed = false
	_camera.limit_left = -2000
	_camera.limit_top = -2000
	_camera.limit_right = 4000
	_camera.limit_bottom = 2000
	_camera.zoom = Vector2(zoom_value, zoom_value)
	# Camera2D is a child of Player, so its local offset is what puts the chosen
	# world point at the centre of the 640x360 viewport.
	_camera.position_smoothing_enabled = false
	_camera.position = center - _player.global_position
	_camera.reset_smoothing()


func _record(
	id: String, crop: Rect2i, tick: Callable, note: String, camera_info: Dictionary
) -> void:
	var frames: Array[Image] = []
	for index: int in range(FRAMES):
		tick.call(index)
		await _wait_seconds(1.0 / FPS)
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		if shot == null:
			push_error("capture_loom_demos: no viewport image")
			return
		var frame: Image = shot.get_region(crop)
		if frame.get_format() != Image.FORMAT_RGBA8:
			frame.convert(Image.FORMAT_RGBA8)
		frames.append(frame)
	if frames.size() != FRAMES:
		push_error("capture_loom_demos: wrong frame count for %s" % id)
		return

	var strip: Image = Image.create(FRAME_WIDTH * FRAMES, FRAME_HEIGHT, false, Image.FORMAT_RGBA8)
	for index: int in range(frames.size()):
		strip.blit_rect(
			frames[index], Rect2i(0, 0, FRAME_WIDTH, FRAME_HEIGHT),
			Vector2i(index * FRAME_WIDTH, 0)
		)
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var png_path: String = directory.path_join("%s.png" % id)
	var error: Error = strip.save_png(png_path)
	var data: Dictionary = {
		"id": id,
		"source": "formal star_loom scene, real input/state",
		"frames": FRAMES,
		"fps": FPS,
		"frame_width": FRAME_WIDTH,
		"frame_height": FRAME_HEIGHT,
		"crop": {
			"x": crop.position.x,
			"y": crop.position.y,
			"w": crop.size.x,
			"h": crop.size.y,
		},
		"camera": camera_info,
		"note": note,
	}
	var file: FileAccess = FileAccess.open(directory.path_join("%s.json" % id), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	print("DEMO %s frames=%d size=%dx%d error=%d crop=%s" % [
		id, frames.size(), strip.get_width(), strip.get_height(), error, str(crop)
	])


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
