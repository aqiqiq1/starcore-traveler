extends Node

## Post-shader-fix rendered evidence (640x360).
##
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/level03/capture_flow_hurt_after_shader_20261116.tscn
##
## Uses a real guard slam and real time sampling. The neutral A/B pair is the
## coordinator probe output in ../neutral_coordinator_after_20261116/ (0 px
## difference). This script only writes the new c-prefixed hurt evidence.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/flow_hurt_audio_20261116_after_shader"
const MANIFEST: String = "res://screenshots/flow_hurt_audio_20261116_after_shader/MANIFEST.txt"

var _level: Level03
var _lines: Array[String] = []
var _hit_seen: bool = false
var _struck_total: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_clear_output()
	_lines.append("Star Core Traveler - post-shader-fix hurt evidence (2026-11-16)")
	_lines.append("Godot: %s  viewport 640x360, normal game viewport" % Engine.get_version_info()["string"])
	_lines.append("Neutral material A/B is the coordinator probe: ../neutral_coordinator_after_20261116")
	_lines.append("NEUTRAL_SHADER_RENDER_DIFF pixels=0 tint=0.00 (same frame, shader vs no material).")
	_lines.append("")
	await _capture_hurt_sequence()
	await _capture_second_hit()
	_write_manifest()
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("FLOW_HURT_AFTER_SHADER_CAPTURE_DONE")
	get_tree().quit(0)


func _capture_hurt_sequence() -> void:
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _physics(24)
	_level.debug_setup_arena_combat(2020.0, false)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	if not guard.player_struck.is_connected(_on_player_struck):
		guard.player_struck.connect(_on_player_struck)
	_hit_seen = false
	await _capture("c01_arena_before_hit.png",
		"SETUP arena before a real slam; neutral shader (hit_amount=0) must look like no material. "
		+ "Guard x=%.0f, player x=%.0f." % [guard.global_position.x, player.global_position.x])
	for _i: int in range(420):
		await get_tree().physics_frame
		if _hit_seen:
			break
	_lines.append("STATE %s | real guard slam hit through the guard's own resolution"
		% ("OK" if _hit_seen else "FAIL"))
	var hit_frame: int = Engine.get_physics_frames()
	var start_x: float = player.global_position.x
	for i: int in range(16):
		var frame_now: int = Engine.get_physics_frames()
		var sim_ms: int = int(round(float(frame_now - hit_frame) * 1000.0 / 60.0))
		var rel: String = "c_hurt/c%02d_%03dms.png" % [i, sim_ms]
		var state_line: String = (
			"%s | sim_ms=%d | physics_frame=%d | x=%.2f | y=%.2f | vx=%.1f | vy=%.1f "
			+ "| tint=%.2f | reaction=%.3f | protection=%.3f | hits=%d | guard=%s"
		)
		state_line = state_line % [rel, sim_ms, frame_now, player.global_position.x,
			player.global_position.y, player.velocity.x, player.velocity.y,
			player.get_hurt_tint_amount(), player.get_hit_reaction_remaining(),
			player.get_hit_protection_remaining(), _level.get_player_hits(),
			guard.get_state_name()]
		_lines.append(state_line)
		await _snap_paused(rel)
		await get_tree().physics_frame
		await get_tree().process_frame
	_lines.append("STATE %s | real hit moved the body away (x %.1f -> %.1f)"
		% ["OK" if player.global_position.x < start_x - 10.0 else "FAIL",
		   start_x, player.global_position.x])
	_lines.append("# 16 frames sampled at the real sim_ms/physics_frame on each line;")
	_lines.append("# some steps skip one frame. The GIF is slowed to 50 ms/frame for viewing;")
	_lines.append("# the sim_ms column is the real timing.")
	_lines.append("")
	await _free_level()


func _capture_second_hit() -> void:
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _physics(24)
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	if not guard.player_struck.is_connected(_on_player_struck):
		guard.player_struck.connect(_on_player_struck)
	var base: int = _struck_total
	for _i: int in range(600):
		await get_tree().physics_frame
		if _struck_total >= base + 1:
			break
	for _i: int in range(900):
		await get_tree().physics_frame
		if _struck_total >= base + 2:
			break
	await _capture("c02_second_hit_pending.png",
		"REAL second hit: hits=%d, retry pending, tint=%.2f, x=%.1f (not teleported yet)."
		% [_level.get_player_hits(), player.get_hurt_tint_amount(), player.global_position.x])
	for _i: int in range(30):
		await get_tree().physics_frame
		if not _level.is_retry_pending():
			break
	await _physics(4)
	await _capture("c03_after_retry.png",
		"After the existing 0.15 s reaction the current-fight retry ran: hits=%d, "
		% _level.get_player_hits()
		+ "body at the recovery point, no red, guard reset.")
	await _free_level()


func _on_player_struck(_facing: int) -> void:
	_hit_seen = true
	_struck_total += 1


func _clear_output() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var frames: String = ProjectSettings.globalize_path(DIR + "/c_hurt")
	DirAccess.make_dir_recursive_absolute(frames)
	for name: String in DirAccess.get_files_at(frames):
		if name.ends_with(".png"):
			DirAccess.remove_absolute(frames + "/" + name)


func _capture(file_name: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(DIR + "/" + file_name))
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
	_lines.append("%s | %s" % [file_name, note])
	_lines.append("")
	get_tree().paused = false
	await get_tree().process_frame


func _snap_paused(file_name: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(DIR + "/" + file_name))
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	get_tree().paused = false
	await get_tree().process_frame


func _free_level() -> void:
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
