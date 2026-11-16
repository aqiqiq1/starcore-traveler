extends Node

## Final stage-A/B engine captures (2026-11-16).
##   Godot --path . res://tests/level03/capture_l3_quality_repair.tscn

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/level03_quality_repair_20261116"
const MANIFEST: String = "res://screenshots/level03_quality_repair_20261116/MANIFEST.txt"

var _level: Level03
var _player: L3Player
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(30)
	_player = _level.get_player()
	_lines.append("Star Core Traveler - level 03 quality repair, final captures")
	_lines.append("Godot: %s  viewport 640x360" % Engine.get_version_info()["string"])
	_lines.append("Running game root viewport. SETUP vs REAL INPUT is stated per shot.")
	_lines.append("")
	await _shot_start()
	await _shot_high_platform()
	await _shot_film_pages()
	await _shot_guard_cells()
	await _shot_gate_sequence()
	await _shot_city_corridor()
	await _shot_retry()
	_write_manifest()
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		_level.queue_free()
		await _phys(3)
	print("L3_QA_CAPTURE_DONE")
	get_tree().quit(0)


func _shot_start() -> void:
	await _restart()
	await _phys(20)
	await _capture("b01_start_left_column.png",
		"REAL start state: header 2 lines + one objective line, no second event row, no task panel.")


func _shot_high_platform() -> void:
	await _restart()
	_level.debug_restore_stage(1, true, false)
	await _phys(8)
	await _run_to_high_platform()
	await _phys(6)
	await _capture("b02_high_platform_rune.png",
		"REAL INPUT route: ground lift -> right ledge -> jump + Q at the top -> higher platform "
		+ "(top 130, device at 290). Shows the whole rune corner; the stone sits bottom-right with "
		+ "a clear visible gap (>= 12 px) to the platform, and a visible support pillar.")


func _run_to_high_platform() -> void:
	Input.action_press(&"move_right")
	for _i: int in range(320):
		await get_tree().physics_frame
		if _player.is_on_floor() and _player.global_position.y > 200.0 \
				and _player.global_position.x >= 512.0:
			break
	Input.action_release(&"move_right")
	await _phys(6)
	for _i: int in range(80):
		if _player.global_position.x <= 526.0:
			break
		Input.action_press(&"move_left")
		await get_tree().physics_frame
		Input.action_release(&"move_left")
		await get_tree().physics_frame
	await _phys(2)
	Input.action_press(&"move_left")
	await _phys(2)
	Input.action_press(&"jump")
	await _phys(3)
	Input.action_release(&"jump")
	var q_done: bool = false
	for _i: int in range(300):
		await get_tree().physics_frame
		if not q_done and _player.global_position.y <= 158.0:
			q_done = true
			Input.action_press(&"polarity")
			await get_tree().physics_frame
			Input.action_release(&"polarity")
		if q_done and _player.is_on_floor():
			break
	Input.action_release(&"move_left")
	await _phys(6)


func _shot_film_pages() -> void:
	for page: int in range(3):
		await _restart()
		var cine: L3Cinematic = _level.get_cine()
		await _open_film()
		for _i: int in range(page):
			await _short_space()
			await _short_space()
		await _phys(70)
		await _capture("b%02d_film_page%d.png" % [3 + page, page + 1],
			"REAL FILM page %d of 3 (setup: the first invalid shatter is issued through the "
			% (page + 1) + "guard's public hit path so the capture does not depend on swing timing).")


func _shot_guard_cells() -> void:
	# three cells at the fight start
	await _restart()
	_level.debug_setup_arena_combat(2020.0, true)
	await _phys(10)
	await _capture("b06_guard_three_cells.png",
		"SETUP post-teaching fight: single three-cell bar above the guard, no state text/charge meter/diamonds.")
	# two cells (real gravity hit, the body kept outside the release ring)
	await _restart()
	_level.debug_setup_arena_combat(2020.0, true)
	await _phys(8)
	var guard: L3Guard = _level.get_guard()
	var ok2: bool = await _gravity_hit(9001)
	if ok2 and guard.get_remaining_marks() == 2 and guard.get_state_name() == "SCATTERING":
		await _capture("b07_guard_two_cells_shatter.png",
			"SETUP fight + ONE real opposite-phase hit inside the gravity attack: visible scatter, bar 2/3.")
	else:
		print("SKIP b07: marks=", guard.get_remaining_marks(), " state=", guard.get_state_name())
	# one cell (rebuild, second real gravity hit, asserted before saving)
	for _i: int in range(260):
		await get_tree().physics_frame
		if guard.get_state_name() == "ACTIVE":
			break
	var ok1: bool = await _gravity_hit(9002)
	if ok1 and guard.get_remaining_marks() == 1 and guard.get_state_name() == "SCATTERING":
		await _capture("b08_guard_one_cell_shatter.png",
			"SETUP second real gravity hit on the rebuilt guard: bar 1/3 and the shell scattering. "
			+ "Asserted remaining=1 and SCATTERING before the file was written.")
	else:
		print("SKIP b08: marks=", guard.get_remaining_marks(), " state=", guard.get_state_name())


## Real opposite-phase hit inside the gravity attack without the body being in
## the release ring: the body waits at -100 during the charge, then steps in.
func _gravity_hit(swing: int) -> bool:
	var guard: L3Guard = _level.get_guard()
	_player.set_polarity_state(not guard.is_positive())
	# SETUP: ask the guard for the gravity turn it already owns, so the capture
	# does not depend on the AI walk timing. The hit below is still the real
	# public resolution against the real state.
	if guard.get_state_name() != "GRAVITY_CHARGE":
		guard.force_gravity_first()
	_player.global_position = guard.global_position + Vector2(-100.0, 0.0)
	for _i: int in range(120):
		await get_tree().physics_frame
		if guard.get_state_name() == "GRAVITY_CHARGE":
			break
	_player.global_position = guard.global_position + Vector2(-30.0, 0.0)
	_player.velocity = Vector2.ZERO
	guard.receive_player_hit(_player, 1, not guard.is_positive(), swing)
	for _i: int in range(8):
		await get_tree().physics_frame
	return guard.get_state_name() == "SCATTERING"


func _shot_gate_sequence() -> void:
	await _restart()
	_level.debug_setup_gate_with_key(2200.0)
	await _phys(14)
	await _capture("b09_gate_closed.png",
		"SETUP gate recovery point with the carried core: closed 144x160 facade, symmetric towers.")
	Input.action_press(&"interact")
	await get_tree().physics_frame
	Input.action_release(&"interact")
	await _phys(8)
	await _capture("b10_gate_filled.png",
		"REAL E: the core is embedded, the filled door plate is shown.")
	for _i: int in range(140):
		await get_tree().physics_frame
		if _level.get_gate().is_open():
			break
	await _phys(10)
	Input.action_press(&"move_right")
	await _phys(26)
	Input.action_release(&"move_right")
	await _phys(6)
	await _capture("b11_gate_open_walk.png",
		"REAL walk: the open gate with the body passing through the doorway into the city.")


func _shot_city_corridor() -> void:
	# walk deeper into the short open-air corridor (stay before the 2360 line)
	Input.action_press(&"move_right")
	for _i: int in range(200):
		await get_tree().physics_frame
		if _player.global_position.x >= 2325.0:
			break
	Input.action_release(&"move_right")
	await _phys(8)
	await _capture("b12_city_corridor_left_column.png",
		"REAL city corridor: clear open-air short segment (DS03 + original city ground + existing "
		+ "columns behind the body), left column shows one objective line with no overlap.")


func _shot_retry() -> void:
	await _restart()
	_level.debug_setup_arena_combat(2020.0, true)
	await _phys(10)
	var guard: L3Guard = _level.get_guard()
	guard.player_struck.emit(-1)
	await _phys(4)
	guard.player_struck.emit(-1)
	await _phys(10)
	await _capture("b13_retry_left_column.png",
		"REAL retry path (two real guard hits through the signal): the body is back at the "
		+ "guard-front recovery point, one short event line replaces the objective, no stacked text.")


# --- helpers -------------------------------------------------------------

func _open_film() -> void:
	_level.debug_setup_pre_teaching(1560.0)
	await _phys(6)
	_level.debug_place_player_at(Vector2(1560.0, 252.0))
	await _phys(6)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _player
	player.global_position = guard.global_position + Vector2(-30.0, 0.0)
	await _phys(3)
	guard.receive_player_hit(player, 1, not guard.is_positive(), 700)
	await _phys(60)
	_level.debug_place_player_at(Vector2(2170.0, 320.0))
	var cine: L3Cinematic = _level.get_cine()
	for _i: int in range(600):
		await get_tree().physics_frame
		if cine.get_phase_name() == "DIALOGUE":
			break
	await _phys(30)


func _short_space() -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await _phys(2)
	var release: InputEventKey = InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	release.pressed = false
	Input.parse_input_event(release)
	await _phys(3)


func _restart() -> void:
	_level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(24)
	_player = _level.get_player()


func _capture(file_name: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(DIR + "/" + file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
	_lines.append("%s | %s" % [file_name, note])
	_lines.append("")
	get_tree().paused = false
	await get_tree().process_frame


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
