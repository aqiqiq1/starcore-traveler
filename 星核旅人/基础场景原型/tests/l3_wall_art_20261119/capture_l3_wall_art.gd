extends Node

## 2026-11-19 L3 gate depth wall art capture.
##
## Run (windowed, NOT headless, so the real renderer produces pixels):
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://tests/l3_wall_art_20261119/capture_l3_wall_art.tscn
##
## Presentation-only pass: same machine positions as the l3_gate_shadow_20261118
## after/ set (player x 2330 closed, 2320 open, 2365/2380/2400/2453 real walk),
## 640x360 viewport, HUD left on for the five comparison shots and hidden only
## for the clean wall-face crop. Wall geometry, z, clip and the gate flow are not
## touched; this script only places the real player, presses real E/D and reads
## the gate's own occlusion function.

const LEVEL3_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const OUT_ROOT: String = "res://tests/l3_wall_art_20261119"
const SHOT_DIR: String = "res://tests/l3_wall_art_20261119/shots"
const FRAME_SIZE: Vector2i = Vector2i(640, 360)

var _level: Level03 = null
var _log_lines: Array[String] = []
var _fails: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_ensure_dirs()
	_level = LEVEL3_SCENE.instantiate() as Level03
	add_child(_level)
	await _wait(1.0)
	_log("viewport=%s window=%s" % [str(get_viewport().size), str(get_window().size)])

	_level.debug_setup_gate_with_key(2330.0)
	await _wait(0.6)
	var gate: L3Gate = _level.get_gate()
	_log("gate closed: open=%s inserted=%s collision=%s" % [
		str(gate.is_open()), str(gate.is_inserted()), str(gate.is_collision_active())
	])
	_log_wall_pieces(gate)
	_log_occlusion(gate, [2247.0, 2330.0, 2407.0, 2453.0, 2490.0])

	_place(2330.0, 1)
	await _settle()
	await _shot("00_closed_facade.png")

	# Real E at the real embed point (2340), then wait for the plate to open.
	_place(2340.0, 1)
	await _settle()
	_press(KEY_E)
	await _wait_physics(2)
	_release(KEY_E)
	var opened: bool = false
	for _i: int in range(240):
		if gate.is_open():
			opened = true
			break
		await _wait_physics(1)
	_log("gate after E: open=%s progress=%.2f passing_collision=%s" % [
		str(gate.is_open()), gate.get_plate_progress(), str(gate.is_collision_active())
	])
	if not opened:
		_fails.append("gate did not open from the real embed point x=2340")
	# Let the plate finish its real travel so 01 matches the old fully-open
	# shot (is_open() flips at PASSABLE_PROGRESS 0.62, not at 1.00).
	for _i: int in range(180):
		if gate.get_plate_progress() >= 0.999:
			break
		await _wait_physics(1)
	_log("plate settled: progress=%.3f" % gate.get_plate_progress())
	await _wait(0.2)

	_place(2320.0, 1)
	await _settle()
	await _shot("01_open_empty.png")

	# Same walk line as the old evidence: hold D and shoot at each real x.
	_press(KEY_D)
	var targets: Array = [
		[2365.0, "02_outer_threshold.png"],
		[2380.0, "03_inside_doorway.png"],
		[2400.0, "04_right_pillar.png"],
	]
	for target: Array in targets:
		var reached: bool = false
		for _i: int in range(900):
			if _level.get_player().global_position.x >= float(target[0]):
				reached = true
				break
			await _wait_physics(1)
		if not reached:
			_fails.append("walk never reached %.0f for %s" % [
				float(target[0]), String(target[1])
			])
		await _shot(String(target[1]))
		_log("shot %s x=%.2f" % [
			String(target[1]), _level.get_player().global_position.x
		])

	# Just before CITY_ENTER_X (2460): stop the walk at the wall front so the
	# completion cannot fire during the capture.
	var near_wall: bool = false
	for _i: int in range(900):
		if _level.get_player().global_position.x >= 2452.0:
			near_wall = true
			break
		await _wait_physics(1)
	_release(KEY_D)
	await _wait_physics(2)
	_log("shot 05 x=%.2f completed=%s gate_open=%s" % [
		_level.get_player().global_position.x,
		str(_level.is_completed()), str(gate.is_open())
	])
	if not near_wall:
		_fails.append("walk never reached the wall front")
	if _level.is_completed():
		_fails.append("level completed before the wall-front capture")
	await _shot("05_before_completion.png")

	# Clean wall-face shot at the same camera (HUD hidden only here).
	_place(2330.0, 1)
	await _settle()
	_hide_hud()
	await _wait(0.25)
	await _shot("06_wall_face_cleanhud.png")

	_log("post: occlusions with the gate open")
	_log_occlusion(gate, [2247.0, 2330.0, 2407.0, 2453.0, 2490.0])

	_write_log()
	print("L3_WALL_ART_RESULT fail=%d" % _fails.size())
	for failure: String in _fails:
		print("L3_WALL_ART_FAIL: ", failure)
	if _fails.is_empty():
		print("L3_WALL_ART_OK")
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- capture helpers -------------------------------------------------------

func _ensure_dirs() -> void:
	for path: String in [OUT_ROOT, SHOT_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _place(x: float, facing: int) -> void:
	_level.debug_place_player_at(Vector2(x, 320.0))
	var player: L3Player = _level.get_player()
	if player.has_method("face_direction"):
		player.call("face_direction", facing)


func _settle() -> void:
	_level.get_camera().reset_smoothing()
	await _wait(0.45)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fails.append("%s: empty viewport image" % file_name)
		return
	if image.get_size() != FRAME_SIZE:
		_fails.append("%s: viewport image is %s, expected %s" % [
			file_name, str(image.get_size()), str(FRAME_SIZE)
		])
		return
	var error: Error = image.save_png("%s/%s" % [SHOT_DIR, file_name])
	if error != OK:
		_fails.append("%s: save_png failed %d" % [file_name, int(error)])
		return
	_log("saved shots/%s %dx%d" % [file_name, image.get_size().x, image.get_size().y])


func _hide_hud() -> void:
	var hud: L3HUD = _level.get_hud()
	if hud != null:
		hud.visible = false


func _press(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# --- state logging ---------------------------------------------------------

func _log_wall_pieces(gate: L3Gate) -> void:
	var pieces: Dictionary = gate.get_wall_pieces()
	for piece_name: String in pieces:
		var info: Dictionary = pieces[piece_name] as Dictionary
		_log("piece %s z=%d rect=%s foreground=%s" % [
			piece_name, int(info.get("z", -1)), str(info.get("rect")),
			str(info.get("foreground"))
		])
	_log("wall_world_rect=%s fixed_z=%d barrier=%d" % [
		str(gate.get_wall_world_rect()), gate.get_fixed_z(), gate.get_barrier_layer()
	])


func _log_occlusion(gate: L3Gate, xs: Array) -> void:
	for x: float in xs:
		var body: Rect2 = gate.get_body_art_rect_at(x)
		var coverage: float = gate.get_occlusion_coverage(body)
		_log("occlusion x=%.1f body=%s coverage=%.3f covered_px=%.2f" % [
			x, str(body), coverage, coverage * body.size.x
		])


func _wait(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(ceil(seconds * 1000.0))
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait_physics(frames: int) -> void:
	for _i: int in range(maxi(frames, 1)):
		await get_tree().physics_frame


func _log(line: String) -> void:
	_log_lines.append(line)
	print("L3_WALL_ART ", line)


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("%s/capture_log.txt" % OUT_ROOT, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_log_lines) + "\n")
	file.close()
