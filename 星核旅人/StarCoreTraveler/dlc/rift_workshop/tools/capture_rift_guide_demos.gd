extends Node

## Re-records the current rift guide strips that had no capture path left:
## `rift_inversion` and `rift_mirror`.
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/rift_workshop/tools/capture_rift_guide_demos.tscn
##
## Both strips are 24 frames x 8 fps x 256x144 from the formal
## rift_workshop.tscn (the 2026-11-27/28 indoor workshop), because the archived
## strips still showed the retired outdoor terrace and the removed InversionB.
##
## `rift_inversion` — player at the current InversionA (x=160), walks left
## through the violet curtain, which flips the phase once and flashes, with the
## moon gate visible ahead.
## `rift_mirror`  — double-mirror arena. Three real J swings:
##   frame 6  cyan player, J on the gold face  -> gold plate shatters
##   frame 13 gold player, J on the cyan face  -> cyan plate shatters
##   frame 18 J on the exposed core            -> CORE_HIT
## The boss is put into its own fight state and its attacks are disabled only
## so the 3 s clip is readable; each hit goes through receive_player_hit() from
## the player's real attack hit window.  No debug shatter / fake damage.
##
## Output: res://dlc/ui/demos/rift_inversion.png+json, rift_mirror.png+json.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://dlc/ui/demos"
const FRAME_WIDTH: int = 256
const FRAME_HEIGHT: int = 144
const FRAMES: int = 24
const FPS: float = 8.0

var _rift: RiftWorkshop
var _player: L3Player
var _camera: Camera2D
var _boss: RiftMirrorBoss


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _capture_inversion()
	await _capture_mirror()
	print("RIFT_GUIDE_DEMO_CAPTURE_DONE")
	get_tree().quit(0)


# --- inversion -------------------------------------------------------------

func _capture_inversion() -> void:
	await _load_level()
	_player.global_position = Vector2(210.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(-1)
	_player.cancel_attack()
	# Keep the camera centred on world x=200 so the current InversionA (x=160)
	# and the moon gate (x=270) both stay inside the 256 px window; the old
	# strip was framed on the removed InversionB at x=400.
	_camera.limit_smoothed = false
	_camera.limit_left = -2000
	_camera.limit_right = 2000
	_camera.zoom = Vector2.ONE
	_camera.position = Vector2(200.0 - _player.global_position.x, 0.0)
	_camera.reset_smoothing()
	await _wait_seconds(0.35)
	print("RIFT_INVERSION start player=%s field_x=%.1f" % [
		str(_player.global_position), _rift.get_field_a().global_position.x
	])
	await _record(
		"rift_inversion", Rect2i(190, 190, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_inversion,
		"Formal rift workshop. Player walks left through the current InversionA at x=160; the violet curtain flips the phase once and flashes, with the moon gate ahead. No Q (the chapter locks it).",
		{"zoom": 1.0, "wide_limits": true},
	)
	print("RIFT_INVERSION end triggers=%d positive=%s x=%.1f" % [
		_rift.get_field_a().get_trigger_count(), str(_player.is_positive()),
		_player.global_position.x
	])
	await _free_level()


func _tick_inversion(index: int) -> void:
	if index == 4:
		Input.action_press(&"move_left")
	elif index == 13:
		Input.action_release(&"move_left")


# --- mirror ----------------------------------------------------------------

func _capture_mirror() -> void:
	# Both tips belong to the real player flow; the guide strip must not be
	# covered by the popup that the same proximity opens.  Their copy is the
	# guide's own page text, so nothing is hidden from the demo.
	MechanicTips.mark_seen("rift_mirror_tip")
	MechanicTips.mark_seen("rift_core_tip")
	await _load_level()
	_boss = _rift.get_boss()
	_player.global_position = Vector2(1480.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.face_direction(1)
	_player.cancel_attack()
	_boss.set_player_target(_player)
	# Let the chapter's own arena intro (0.9 s) and boss intro (1.0 s) run; a
	# manual begin_fight() here is overwritten by _wake_boss().
	for _index: int in range(80):
		if _rift.is_boss_active() and _boss.get_attack_state_name() == "IDLE":
			break
		await _wait_seconds(0.05)
	_boss.set_attacks_enabled(false)
	_frame_mirror_camera()
	await _wait_seconds(0.20)
	print("RIFT_MIRROR start state=%s gold=%s cyan=%s core=%s boss=%s cam_center=%s" % [
		_boss.get_attack_state_name(), str(_boss.is_face_intact(true)),
		str(_boss.is_face_intact(false)), str(_boss.is_core_exposed()),
		str(_boss.global_position), str(_camera.get_screen_center_position())
	])
	await _record(
		"rift_mirror", Rect2i(192, 108, FRAME_WIDTH, FRAME_HEIGHT),
		_tick_mirror,
		"Formal mirror arena. Frames 0-5 show both face plates; frame 6 is a real J with 澜相 at the gold face, frame 13 a real J with 辉相 at the cyan face, and frame 18 a real J into the exposed core. No debug shatter or fake damage. The HUD is hidden in this strip.",
		{"zoom": 1.0, "wide_limits": true},
	)
	await _free_level()


func _tick_mirror(index: int) -> void:
	if index == 6:
		_set_player_for_swing(1480.0, false)
		_real_key(KEY_J, true)
	elif index == 7:
		_real_key(KEY_J, false)
	elif index == 12:
		_set_player_for_swing(1522.0, true)
	elif index == 13:
		_real_key(KEY_J, true)
	elif index == 14:
		_real_key(KEY_J, false)
	elif index == 18:
		_set_player_for_swing(1508.0, false)
		_real_key(KEY_J, true)
	elif index == 19:
		_real_key(KEY_J, false)
	_frame_mirror_camera()


func _set_player_for_swing(x: float, positive: bool) -> void:
	_player.global_position = Vector2(x, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.face_direction(1)
	_player.cancel_attack()
	_player.clear_external_force()
	_frame_mirror_camera()


func _frame_mirror_camera() -> void:
	_camera.limit_smoothed = false
	_camera.limit_left = -3000
	_camera.limit_right = 5000
	_camera.limit_top = -3000
	_camera.limit_bottom = 3000
	_camera.zoom = Vector2.ONE
	_camera.position = Vector2(
		1540.0 - _player.global_position.x,
		260.0 - _player.global_position.y
	)
	_camera.reset_smoothing()


# --- shared ----------------------------------------------------------------

func _load_level() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	Input.action_release(&"jump")
	_real_key(KEY_J, false)
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(3)
	await _wait_physics(8)
	_player = _rift.get_player()
	_camera = _rift.get_camera()
	var hud: CanvasLayer = _rift.get_node_or_null("HUD") as CanvasLayer
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
	if _rift != null:
		_rift.queue_free()
		_rift = null
	await _wait_process(6)


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
			push_error("capture_rift_guide_demos: no viewport image")
			return
		var frame: Image = shot.get_region(crop)
		if frame.get_format() != Image.FORMAT_RGBA8:
			frame.convert(Image.FORMAT_RGBA8)
		frames.append(frame)
	if frames.size() != FRAMES:
		push_error("capture_rift_guide_demos: wrong frame count for %s" % id)
		return
	var strip: Image = Image.create(FRAME_WIDTH * FRAMES, FRAME_HEIGHT, false, Image.FORMAT_RGBA8)
	for index: int in range(frames.size()):
		strip.blit_rect(
			frames[index], Rect2i(0, 0, FRAME_WIDTH, FRAME_HEIGHT),
			Vector2i(index * FRAME_WIDTH, 0)
		)
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var error: Error = strip.save_png(directory.path_join("%s.png" % id))
	var data: Dictionary = {
		"id": id,
		"source": "formal DLC scene, real input/state",
		"frames": FRAMES,
		"fps": FPS,
		"frame_width": FRAME_WIDTH,
		"frame_height": FRAME_HEIGHT,
		"crop": {
			"x": crop.position.x, "y": crop.position.y,
			"w": crop.size.x, "h": crop.size.y,
		},
		"camera": camera_info,
		"note": note,
	}
	var file: FileAccess = FileAccess.open(
		directory.path_join("%s.json" % id), FileAccess.WRITE
	)
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
