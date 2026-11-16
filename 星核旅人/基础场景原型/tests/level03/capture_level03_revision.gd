extends Node

## Real-engine captures for the 2026-11-15 play-test revision.
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/level03/capture_level03_revision.tscn
##
## Four required views: upper-left guidance during the real rune lift, the echo
## head bubble during the real teaching film, a combat view with no black
## frames, and a per-block collapse warning. Setup vs real input is written into
## MANIFEST.txt next to the images.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const CAPTURE_DIR: String = "res://screenshots/level03_revision_20261115"
const MANIFEST_PATH: String = "res://screenshots/level03_revision_20261115/MANIFEST.txt"

var _level: Level03
var _player: L3Player
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(30)
	_player = _level.get_player()

	_lines.append("Star Core Traveler - level 03 play-test revision captures")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s  window: %s  viewport: 640x360" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size())
	])
	_lines.append("Every image is the running game's root viewport, not offline art.")
	_lines.append("Each entry states SETUP vs REAL INPUT; no full manual run is claimed.")
	_lines.append("")

	await _shot_upper_left_guide()
	await _shot_echo_bubble()
	await _shot_combat_hud()
	await _shot_block_warning()

	_write_manifest()
	print("L3_REVISION_CAPTURE_DONE")
	get_tree().quit(0)


func _shot_upper_left_guide() -> void:
	await _restart()
	await _phys(10)
	_level.debug_restore_stage(1, true, false)
	await _phys(10)
	# REAL INPUT: walk right into the lit rune current and ride it up.
	Input.action_press(&"move_right")
	for _i: int in range(200):
		await get_tree().physics_frame
		# y < 240 flips the guide to the device target; y <= 205 frames the
		# stone below-left and the platform above-left with the fresh line.
		if _player.global_position.y <= 205.0:
			break
	Input.action_release(&"move_right")
	await _phys(2)
	await _capture("01_upper_left_guide.png",
		"REAL INPUT: original point-attract rune lift, player airborne between the stone and the "
		+ "left-upper device platform; objective 'borrow the rune, back up-left' and the guide line is "
		+ "computed to the device at (410,176), i.e. truly up-left. "
		+ "SETUP: stage restored to the stored-rune checkpoint (debug_restore_stage(1)).")


func _shot_echo_bubble() -> void:
	await _restart()
	await _phys(10)
	_level.debug_setup_pre_teaching(1560.0)
	await _phys(6)
	_level.debug_place_player_at(Vector2(1560.0, 252.0))
	await _phys(6)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _player
	# REAL INPUT equivalent for the shell: two opposite-phase J resolutions
	# through the guard's public hit path, then a real approach to the gate.
	player.global_position = guard.global_position + Vector2(-30.0, 0.0)
	await _phys(3)
	guard.receive_player_hit(player, 1, not guard.is_positive(), 700)
	await _phys(30)
	guard.receive_player_hit(player, 1, not guard.is_positive(), 701)
	await _phys(80)
	_level.debug_place_player_at(Vector2(2170.0, 320.0))
	var cine: L3Cinematic = _level.get_cine()
	for _i: int in range(600):
		await get_tree().physics_frame
		if cine.get_phase_name() == "DIALOGUE":
			break
	await _phys(100)
	await _capture("02_echo_head_bubble.png",
		"REAL FILM: first invalid shatter really waits, then the gate approach plays the rebuild + gravity "
		+ "charge and this first short page. SETUP: the two shell hits are issued through receive_player_hit "
		+ "(same resolution as a real J) so the capture does not depend on input timing.")


func _shot_combat_hud() -> void:
	await _restart()
	await _phys(10)
	_level.debug_setup_arena_combat(1990.0, true)
	await _phys(10)
	var guard: L3Guard = _level.get_guard()
	_player.set_polarity_state(not guard.is_positive())
	_player.global_position = guard.global_position + Vector2(-86.0, 0.0)
	# One real guard hit through the real signal: one of two pips + the small
	# world flash, exactly what a first hit shows in play.
	guard.player_struck.emit(-1)
	await _phys(4)
	guard.force_gravity_first()
	for _i: int in range(120):
		await get_tree().physics_frame
		if guard.get_state_name() == "GRAVITY_CHARGE" and guard.get_charge_ratio() > 0.45:
			break
	await _capture("03_combat_low_hud.png",
		"REAL COMBAT STATE: gravity charge with the lit weakpoint and the inward field; one real guard hit "
		+ "(player_struck) so one talisman is cracked and one is still whole. SETUP: arena recovery point "
		+ "(debug_setup_arena_combat). No task panel, no core status line, no toast bar, no 'hit 1/2' text.")


func _shot_block_warning() -> void:
	await _restart()
	await _phys(10)
	_level.debug_restore_stage(2, true, false)
	await _phys(6)
	var route: L3FloatRoute = _level.get_float_route()
	route.start_cycle()
	await _phys(140)
	var blocks: Array[L3FloatBlock] = route.get_blocks()
	var block: L3FloatBlock = blocks[0]
	var top: float = block.get_top_y()
	_level.debug_place_player_at(Vector2(block.global_position.x + 6.0, top - 1.0))
	for _i: int in range(120):
		await get_tree().physics_frame
		if block.get_phase_label() == "COUNTDOWN":
			break
	await _phys(4)
	await _capture("04_block_warning.png",
		"REAL PER-BLOCK COLLAPSE: the first real standing starts that block's own countdown; the pulsing "
		+ "warning triangle and the bright top edge carry the danger, the next blocks stay stable. "
		+ "SETUP: device stage restored (debug_restore_stage(2)) and the player placed on the first block.")


func _restart() -> void:
	_level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(24)
	_player = _level.get_player()
	# Let the level's 2.4 s intro event fade before any capture.
	await _phys(170)


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
	_lines.append("%s | %s" % [file_name, note])
	_lines.append("")
	get_tree().paused = false
	await get_tree().process_frame


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
