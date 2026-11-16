extends Node

## Real-engine captures for the level-03 prototype. Run with a windowed Godot:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/level03/capture_level03.tscn
##
## Each image is the real 640x360 root viewport, frozen without the pause page.
## Setup vs real action is recorded in the manifest and in the report.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const CAPTURE_DIR: String = "res://screenshots/level03_prototype_20261115"
const MANIFEST_PATH: String = "res://screenshots/level03_prototype_20261115/MANIFEST.txt"
const LOG_PATH: String = "res://tests/level03/capture.log"

var _level: Level03
var _player: L3Player
var _guard: L3Guard
var _lines: Array[String] = []
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _physics(30)
	_player = _level.get_player()
	_guard = _level.get_guard()

	_lines.append("Star Core Traveler - level 03 prototype engine captures")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s  logical viewport: 640x360  window: %s" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size())
	])
	_lines.append("Captured from the running game root viewport, not offline art boards.")
	_lines.append("Each item states SETUP vs REAL INPUT. No manual continuous play is claimed.")
	_lines.append("")

	await _capture("level03_00_start.png",
		"start; SETUP none. Spawn bay/core, rune in the distance, budget HUD, DS03 + far gate silhouette.")
	await _shot_rune_climb()
	await _shot_float_route()
	await _shot_guard_weakpoint()
	await _shot_gate_city()
	await _shot_completion()
	await _shot_cinematic()

	_write_manifest()
	_write_log()
	print("LEVEL03_CAPTURE_DONE")
	get_tree().quit(0)


func _shot_rune_climb() -> void:
	_restart()
	await _physics(20)
	# SETUP: rune-bay/record/world state after the transport. The climb itself
	# below uses real A/D/Q input.
	_level.debug_restore_stage(1, true, false)
	await _physics(10)
	await _walk_to_x(482.0, 240)
	Input.action_press(&"move_right")
	var frames: int = 0
	while frames < 200:
		await get_tree().physics_frame
		frames += 1
		if _player.global_position.y <= 272.0 and _player.global_position.x >= 505.0:
			break
	Input.action_release(&"move_right")
	await _physics(2)
	_level.get_hud().show_toast("", 0.0)
	await _capture("level03_01_rune_climb.png",
		"rune climb; SETUP rune stage; REAL: player walked to the ledge and was lifted by the opposite-phase rune. Shows the rune, ledge edge, live link line and HUD.")


func _shot_float_route() -> void:
	_restart()
	await _physics(20)
	_level.debug_restore_stage(2, true, false)
	await _physics(8)
	# REAL: E at the fixed device starts the real cycle.
	await _tap_action(&"interact")
	await _physics(20)
	var up_wait: int = 0
	while up_wait < 180:
		await get_tree().physics_frame
		up_wait += 1
		var states: Array[String] = _level.get_float_route().get_block_states()
		var all_up: bool = true
		for state: String in states:
			if state != "UP":
				all_up = false
		if all_up:
			break
	await _walk_to_x(870.0, 200)
	await _jump_right_until_x(960.0, 120)
	await _wait_floor(222.0, 90)
	await _capture("level03_02_float_route.png",
		"floating route; SETUP device-stage world; REAL: E started the cycle and the player jumped onto the first raised stone. Shows device, five stones, safe buffer in the distance.")


func _shot_guard_weakpoint() -> void:
	_restart()
	await _physics(20)
	# SETUP: arena state and a forced real charge for a stable capture pose.
	_level.debug_setup_arena_combat(1745.0)
	await _physics(6)
	_guard.force_fresh_charge()
	var wait: int = 0
	while wait < 180 and not _guard.is_vulnerable():
		await get_tree().physics_frame
		wait += 1
	_player.set_polarity_state(_guard.is_positive())
	_level.debug_place_player_at(Vector2(_guard.global_position.x - 54.0, 320.0))
	await _physics(2)
	_level.get_hud().show_toast("", 0.0)
	await _capture("level03_03_guard_weakpoint.png",
		"guard weakpoint/field/head bar; SETUP arena + forced charge + same-phase player pose. The weakpoint is the accepted corner-motion v2 gold sheet at the chest; field is v3 inward; 2x golem; code-drawn charge bar and 3 marks.")


func _shot_gate_city() -> void:
	_restart()
	await _physics(20)
	_level.debug_setup_gate_with_key(1938.0)
	# SETUP note: this focused capture marks the one-shot tutorial as played so
	# the gate visual can be shown without the black bars.
	_level.get_cine().mark_played()
	await _physics(8)
	await _tap_action(&"interact")
	var open_wait: int = 0
	while open_wait < 120 and not _level.get_gate().is_open():
		await get_tree().physics_frame
		open_wait += 1
	await _walk_to_x(1950.0, 60)
	await _physics(6)
	await _capture("level03_04_gate_open_city.png",
		"open gate / city beyond; SETUP gate-with-key state + tutorial marked played; REAL: E embedded the key and opened the door. Shows the v2 portal FX and the interior arch/light through the door.")


func _shot_completion() -> void:
	await _walk_to_x(2085.0, 180)
	await _physics(20)
	await _capture("level03_05_city_complete.png",
		"completion; REAL: player physically walked into the city past the gate. The completion page is level 03 and the city interior is behind it.")


func _shot_cinematic() -> void:
	_restart()
	await _physics(20)
	_level.debug_setup_arena_combat(1890.0)
	await _physics(4)
	await _walk_to_x(1902.0, 80)
	var phase_wait: int = 0
	while phase_wait < 360 and _level.get_cine().get_phase_name() != "DIALOGUE":
		await get_tree().physics_frame
		phase_wait += 1
	await _physics(50)
	await _capture("level03_06_cine_bars.png",
		"near-gate cinematic; SETUP arena; REAL: walked to the locked door and triggered the one-shot. Shows black bars, s40 echo projection and the first dialogue page.")


func _restart() -> void:
	_level.get_pause_menu().restart_requested.emit()


func _capture(file_name: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
		_log_lines.append("CAPTURED %s size=%s path=%s" % [file_name, str(image.get_size()), path])
	_lines.append("%s | %s" % [file_name, note])
	get_tree().paused = false
	await get_tree().process_frame


func _jump_right_until_x(target_x: float, max_frames: int) -> void:
	Input.action_press(&"move_right")
	await _physics(4)
	await _tap_action(&"jump")
	var frames: int = 0
	while frames < max_frames and _player.global_position.x < target_x:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_right")
	await _physics(4)


func _wait_floor(target_y: float, max_frames: int) -> void:
	var frames: int = 0
	while frames < max_frames:
		await get_tree().physics_frame
		frames += 1
		if _player.is_on_floor() and absf(_player.global_position.y - target_y) <= 3.0:
			return
		if _player.global_position.y > 380.0:
			return


func _walk_to_x(target: float, max_frames: int) -> void:
	for _i: int in range(max_frames):
		var dx: float = target - _player.global_position.x
		if absf(dx) <= 2.0:
			break
		var action: StringName = &"move_right" if dx > 0.0 else &"move_left"
		Input.action_press(action)
		await get_tree().physics_frame
		Input.action_release(action)
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	await _physics(2)


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()


func _write_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _log_lines:
		file.store_line(line)
	file.close()
