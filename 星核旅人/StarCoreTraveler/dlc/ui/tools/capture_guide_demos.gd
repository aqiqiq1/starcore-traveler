extends Node

## Captures the six real-gameplay demo strips used by dlc/ui/dlc_guide.gd.
## Run WITHOUT --headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/ui/tools/capture_guide_demos.tscn
##
## Every clip is recorded from the formal trial_chambers.tscn / rift_workshop.tscn
## scene at 256x144, 24 frames, 8 fps, and saved as one horizontal strip plus a
## JSON sidecar in dlc/ui/demos/.  Debug placement and the guard's existing
## debug_force_gravity() are used only to set up the state; every Q / movement /
## J shown in the strip is real input or the scene's own automatic rule.
##
## This tool only writes res://dlc/ui/demos/.  It never touches base assets.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://dlc/ui/demos"
const FRAME_WIDTH: int = 256
const FRAME_HEIGHT: int = 144
const FRAMES: int = 24
const FPS: float = 8.0

var _level: Node
var _player: L3Player
var _camera: Camera2D
var _guard: L3Guard
var _guard_gold: L3Guard
var _guard_cyan: L3Guard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _capture_trial_gate()
	await _capture_trial_gate_inside()
	await _capture_trial_guard()
	await _capture_rift_inversion()
	await _capture_rift_bridge()
	await _capture_rift_twins()
	print("GUIDE_DEMO_CAPTURE_DONE")
	get_tree().quit(0)


# --- trial ----------------------------------------------------------------

func _capture_trial_gate() -> void:
	await _load_level(TRIAL_SCENE)
	_player.global_position = Vector2(235.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(1)
	_player.cancel_attack()
	_camera.zoom = Vector2.ONE
	_camera.reset_smoothing()
	await _wait_seconds(0.35)
	await _record(
		"trial_gate", Rect2i(190, 190, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_trial_gate,
		"Formal trial scene. Player starts 澜相 left of the gold gate; a real Q opens it and the player walks through.",
		{"zoom": 1.0, "wide_limits": false}
	)
	await _free_level()


func _tick_trial_gate(index: int) -> void:
	if index == 3:
		Input.action_press(&"polarity")
	elif index == 4:
		Input.action_release(&"polarity")
	elif index == 5:
		Input.action_press(&"move_right")
	elif index == 15:
		Input.action_release(&"move_right")


func _capture_trial_gate_inside() -> void:
	await _load_level(TRIAL_SCENE)
	_player.global_position = Vector2(520.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(1)
	_player.cancel_attack()
	_camera.zoom = Vector2.ONE
	_camera.reset_smoothing()
	await _wait_seconds(0.35)
	await _record(
		"trial_gate_inside", Rect2i(190, 190, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_trial_gate_inside,
		"Formal trial scene. Player stands inside the cyan gate; real Q flips phase while the anti-pinch latch keeps it passable, then it closes after the body leaves.",
		{"zoom": 1.0, "wide_limits": false}
	)
	await _free_level()


func _tick_trial_gate_inside(index: int) -> void:
	if index == 4:
		Input.action_press(&"polarity")
	elif index == 5:
		Input.action_release(&"polarity")
	elif index == 10:
		Input.action_press(&"move_right")
	elif index == 16:
		Input.action_release(&"move_right")


func _capture_trial_guard() -> void:
	await _load_level(TRIAL_SCENE)
	_player.global_position = Vector2(880.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_until(func() -> bool: return _level.is_arena_entered(), 90)
	await _wait_physics(6)
	_guard = _level.get_guard() as L3Guard
	_guard.set_suspended(true)
	_player.global_position = Vector2(_guard.global_position.x - 28.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(1)
	_player.cancel_attack()
	_guard.set_player_target(_player)
	_set_wide_camera(0.8)
	await _wait_seconds(0.35)
	await _record(
		"trial_guard_hit", Rect2i(190, 50, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_trial_guard,
		"Formal trial arena. Guard is put into its existing GRAVITY_CHARGE; opposite phase, real J at reach, one true cell lost and the shell scatters.",
		{"zoom": 0.8, "wide_limits": true}
	)
	await _free_level()


func _tick_trial_guard(index: int) -> void:
	if index == 0:
		_guard.set_suspended(false)
		_guard.debug_force_gravity()
	elif index == 5:
		_real_key(KEY_J, true)
	elif index == 6:
		_real_key(KEY_J, false)


# --- rift -----------------------------------------------------------------

func _capture_rift_inversion() -> void:
	await _load_level(RIFT_SCENE)
	# Start between the two curtains so the camera's left clamp cannot push the
	# player out of the 256 px window; walk into InversionB at x=400.
	_player.global_position = Vector2(300.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(1)
	_player.cancel_attack()
	_camera.zoom = Vector2.ONE
	_camera.reset_smoothing()
	await _wait_seconds(0.35)
	await _record(
		"rift_inversion", Rect2i(190, 190, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_rift_inversion,
		"Formal rift corridor. Player walks into InversionB; the automatic field flips the phase once and flashes.",
		{"zoom": 1.0, "wide_limits": false}
	)
	await _free_level()


func _tick_rift_inversion(index: int) -> void:
	if index == 4:
		Input.action_press(&"move_right")
	elif index == 13:
		Input.action_release(&"move_right")


func _capture_rift_bridge() -> void:
	await _load_level(RIFT_SCENE)
	_player.global_position = Vector2(620.0, 280.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(1)
	_player.cancel_attack()
	_camera.zoom = Vector2.ONE
	_camera.reset_smoothing()
	await _wait_seconds(0.35)
	await _record(
		"rift_bridge", Rect2i(190, 200, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_rift_bridge,
		"Formal rift terrace. Real Q materialises the gold deck, the player walks on, Q again dissolves it and the body falls to the safe lower shelf.",
		{"zoom": 1.0, "wide_limits": false}
	)
	await _free_level()


func _tick_rift_bridge(index: int) -> void:
	if index == 4:
		Input.action_press(&"polarity")
	elif index == 5:
		Input.action_release(&"polarity")
	elif index == 6:
		Input.action_press(&"move_right")
	elif index == 14:
		Input.action_release(&"move_right")
	elif index == 15:
		Input.action_press(&"polarity")
	elif index == 16:
		Input.action_release(&"polarity")


func _capture_rift_twins() -> void:
	await _load_level(RIFT_SCENE)
	# Close enough for a real J to land while both guards stay inside the crop.
	_player.global_position = Vector2(1270.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(-1)
	_player.cancel_attack()
	await _wait_until(func() -> bool: return _level.is_arena_entered(), 90)
	_guard_gold = _level.get_guard_gold() as L3Guard
	_guard_cyan = _level.get_guard_cyan() as L3Guard
	_set_wide_camera(0.45)
	# The arena entry already started the 0.8 s hover; do not spend it before
	# the first recorded frame.
	await _wait_physics(1)
	await _record(
		"rift_twins", Rect2i(190, 104, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_rift_twins,
		"Formal rift arena. Both guards hover for the opening; the gold guard is then put into its existing GRAVITY_CHARGE and a real J removes one true cell while both bars stay visible.",
		{"zoom": 0.45, "wide_limits": true}
	)
	await _free_level()


func _tick_rift_twins(index: int) -> void:
	if index == 7:
		_guard_gold.set_suspended(false)
		_guard_gold.debug_force_gravity()
	elif index == 11:
		_real_key(KEY_J, true)
	elif index == 12:
		_real_key(KEY_J, false)


# --- shared capture -------------------------------------------------------

func _load_level(path: String) -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	Input.action_release(&"jump")
	_real_key(KEY_J, false)
	var packed: PackedScene = load(path) as PackedScene
	_level = packed.instantiate()
	if _level is TrialChambers:
		(_level as TrialChambers).show_intro_guide = false
	elif _level is RiftWorkshop:
		(_level as RiftWorkshop).show_intro_guide = false
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(3)
	await _wait_physics(8)
	_player = _level.get_player() as L3Player
	_camera = _level.get_camera() as Camera2D
	var hud: CanvasLayer = _level.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	_player.cancel_attack()
	_player.velocity = Vector2.ZERO


func _free_level() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	Input.action_release(&"jump")
	_real_key(KEY_J, false)
	await _wait_process(2)
	get_tree().current_scene = null
	if _level != null:
		_level.queue_free()
		_level = null
	await _wait_process(6)


func _set_wide_camera(zoom_value: float) -> void:
	_camera.limit_smoothed = false
	_camera.limit_left = -2000
	_camera.limit_top = -2000
	_camera.limit_right = 4000
	_camera.limit_bottom = 2000
	_camera.zoom = Vector2(zoom_value, zoom_value)
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
			push_error("capture_guide_demos: no viewport image")
			return
		var frame: Image = shot.get_region(crop)
		if frame.get_format() != Image.FORMAT_RGBA8:
			frame.convert(Image.FORMAT_RGBA8)
		frames.append(frame)
	if frames.size() != FRAMES:
		push_error("capture_guide_demos: wrong frame count for %s" % id)
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
		"source": "formal DLC scene, real input/state",
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


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())
