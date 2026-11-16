extends Node

## Real-viewport evidence for the 2026-11-16 A/B work (640x360).
##
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/level03/capture_flow_hurt_20261116.tscn
##
## A: level-02 completion page (three approved buttons) -> real level 03 by a
##    real mouse click -> real A/D movement.
## B: a real guard slam: baseline, then 16 sampled frames through the red flash
##    and the return to normal (real sim_ms/physics_frame per line; some steps
##    skip 1 frame), with a manifest of time/x/velocity/tint/reaction/protection/
##    guard state. The GIF/contact sheet are built from these exact PNGs and the
##    GIF is deliberately slowed for viewing; no drawing is edited.
##
## Output: screenshots/flow_hurt_audio_20261116/

const LEVEL02_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LEVEL03_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/flow_hurt_audio_20261116"
const MANIFEST: String = "res://screenshots/flow_hurt_audio_20261116/MANIFEST.txt"

var _level: Node = null
var _lines: Array[String] = []
var _hit_seen: bool = false
var _struck_total: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	# This evidence folder is owned by this capture; drop only its own old
	# frame PNGs so a re-run cannot mix two takes.
	var frames_dir: String = ProjectSettings.globalize_path(DIR + "/hurt_frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	for old_name: String in DirAccess.get_files_at(frames_dir):
		if old_name.ends_with(".png"):
			DirAccess.remove_absolute(frames_dir + "/" + old_name)
	_lines.append("Star Core Traveler - flow + hurt evidence (2026-11-16)")
	_lines.append("Godot: %s  viewport 640x360" % Engine.get_version_info()["string"])
	_lines.append("Normal game viewport; no debug overlay. Setup vs real input is stated per shot.")
	_lines.append("")
	await _capture_l2_and_transition()
	await _capture_hurt_sequence()
	await _capture_second_hit_pending()
	_write_manifest()
	if _level != null and is_instance_valid(_level):
		var audio: Node = _level.get_audio()
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("FLOW_HURT_CAPTURE_DONE")
	get_tree().quit(0)


# --- A. L2 page -> real L3 -------------------------------------------------

func _capture_l2_and_transition() -> void:
	await _clear_levels()
	_level = LEVEL02_SCENE.instantiate()
	get_tree().root.add_child(_level)
	await _physics(10)
	_level.debug_restore_stage(2, false)
	await _physics(4)
	var final_bay: StarCoreBayInteractable = _level.get_final_bay()
	final_bay.reset_empty()
	final_bay.start_store_core(false)
	final_bay.finish_store()
	_level.get_player().global_position = _level.get_exit().global_position
	await _physics(8)
	if not _level.is_completed():
		_level._try_complete_at_exit()
		await _physics(3)
	await _settle(6)
	_check_state(_level.is_completed() and _level.get_hud().is_completion_visible(),
		"L2 completion page appears after the real completion path")
	await _capture("a01_l2_completion_three_buttons.png",
		"SETUP completion via the L2 stable checkpoint + final bay + exit trigger (not a full route). "
		+ "Primary 进入第三关 (STONE) with 重玩本关 / 返回主界面 side by side, focused primary.")
	# Real mouse click on the primary.
	get_tree().current_scene = _level
	var primary: PixelMenuButton = _level.get_hud().get_completion_primary_button()
	await _click(primary)
	var l3: Node = await _wait_scene("Level03", 220)
	_check_state(l3 is Level03, "real mouse click on 进入第三关 reaches Level03")
	if not (l3 is Level03):
		return
	_level = l3
	await _physics(12)
	_check_state(_level.get_player().global_position.distance_to(Vector2(40.0, 320.0)) < 3.0,
		"L3 spawn (40,320), body on the floor")
	await _capture("a02_l3_arrival_from_l2.png",
		"REAL scene change from the L2 completion page: level 03 opening view, body at (40,320), "
		+ "core device inactive, guard in its initial state.")
	# Real D movement after the transition.
	var start_x: float = _level.get_player().global_position.x
	Input.action_press(&"move_right")
	await _physics(16)
	Input.action_release(&"move_right")
	await _physics(2)
	var moved_x: float = _level.get_player().global_position.x
	_check_state(moved_x > start_x + 8.0,
		"real D moves the body after the transition (x %.1f -> %.1f)" % [start_x, moved_x])
	await _capture("a03_l3_real_move_right.png",
		"REAL D input after the L2->L3 change: body moved from x=%.1f to x=%.1f, still on the ground."
		% [start_x, moved_x])


# --- B. hurt sequence ------------------------------------------------------

func _capture_hurt_sequence() -> void:
	await _clear_levels()
	_level = LEVEL03_SCENE.instantiate()
	get_tree().root.add_child(_level)
	await _physics(24)
	_level.debug_setup_arena_combat(2020.0, false)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	if not guard.player_struck.is_connected(_on_player_struck):
		guard.player_struck.connect(_on_player_struck)
	_hit_seen = false
	await _capture("b01_arena_before_hit.png",
		"SETUP arena fight, real guard ACTIVE/NORMAL at x=%.0f, player at x=%.0f before the strike. "
		% [guard.global_position.x, player.global_position.x]
		+ "No hit flash. This is the baseline for the pixel check.")
	# Wait for the guard's own real slam resolution.
	for _i: int in range(420):
		await get_tree().physics_frame
		if _hit_seen:
			break
	_check_state(_hit_seen, "a real guard slam hit the player through the guard's own resolution")
	var hit_frame: int = Engine.get_physics_frames()
	var hit_start_x: float = player.global_position.x
	var entries: Array[String] = []
	for i: int in range(16):
		var frame_now: int = Engine.get_physics_frames()
		var sim_ms: int = int(round(float(frame_now - hit_frame) * 1000.0 / 60.0))
		var file_name: String = "hurt_frames/h%02d_%03dms.png" % [i, sim_ms]
		var state_line: String = (
			"%s | sim_ms=%d | physics_frame=%d | x=%.2f | y=%.2f | vx=%.1f | vy=%.1f "
			+ "| tint=%.2f | reaction=%.3f | protection=%.3f | hits=%d | guard=%s"
		) % [
			file_name, sim_ms, frame_now, player.global_position.x, player.global_position.y,
			player.velocity.x, player.velocity.y, player.get_hurt_tint_amount(),
			player.get_hit_reaction_remaining(), player.get_hit_protection_remaining(),
			_level.get_player_hits(), guard.get_state_name(),
		]
		await _snap_paused(file_name)
		entries.append(state_line)
		# Advance exactly one real physics step after the snapshot. The pause in
		# _snap_paused happens before a step, so waiting for the idle frame lets
		# the player/guard tick before the next freeze.
		await get_tree().physics_frame
		await get_tree().process_frame
	for line: String in entries:
		_lines.append(line)
	var end_x: float = player.global_position.x
	_check_state(end_x < hit_start_x - 10.0,
		"the real hit moved the body away from the guard (x %.1f -> %.1f)" % [hit_start_x, end_x])
	_lines.append("")
	_lines.append("# The 16 frames above are sampled at the real times on each line (sim_ms /")
	_lines.append("# physics_frame); some steps skip 1 physics frame, so this is not an")
	_lines.append("# uninterrupted 16.7 ms sequence. The GIF plays each frame for 50 ms only")
	_lines.append("# to slow it down for viewing, not as the real speed. The GIF/contact sheet")
	_lines.append("# are built from exactly these PNGs by build_flow_hurt_evidence.py.")
	_lines.append("")


func _capture_second_hit_pending() -> void:
	await _clear_levels()
	_level = LEVEL03_SCENE.instantiate()
	get_tree().root.add_child(_level)
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
	_check_state(_level.is_retry_pending(), "the second real hit keeps its reaction pending before the retry")
	var second_x: float = player.global_position.x
	await _capture("b02_second_hit_pending.png",
		"REAL second hit through the guard (gravity release + normal slam): hits=%d, pending retry, "
		% _level.get_player_hits()
		+ "red tint=%.2f at x=%.1f; the body has not been teleported back yet."
		% [player.get_hurt_tint_amount(), second_x])
	for _i: int in range(30):
		await get_tree().physics_frame
		if not _level.is_retry_pending():
			break
	await _physics(4)
	_check_state(_level.get_player_hits() == 0, "the current-fight retry reset the hit counter")
	await _capture("b03_after_retry.png",
		"After the existing 0.15 s reaction the current-fight retry runs: body back at the "
		+ "guard-front recovery point, no red, guard reset, progress kept.")


# --- harness ---------------------------------------------------------------

func _on_player_struck(_facing: int) -> void:
	_hit_seen = true
	_struck_total += 1


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


## Used inside the hurt sequence: freezes the current simulated state so the
## PNG and the manifest line describe exactly the same physics frame.
func _snap_paused(file_name: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR + "/hurt_frames"))
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(DIR + "/" + file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	get_tree().paused = false
	await get_tree().process_frame


func _clear_levels() -> void:
	get_tree().paused = false
	for child: Node in get_tree().root.get_children():
		if child == self:
			continue
		if child is Level01 or child is Level02 or child is Level03:
			if child.has_method("get_audio"):
				var audio: Node = child.call("get_audio") as Node
				if audio != null and audio.has_method("release_streams"):
					audio.call("release_streams")
			if get_tree().current_scene == child:
				get_tree().current_scene = null
			child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_level = null
	_struck_total = 0
	_hit_seen = false


func _wait_scene(prefix: String, max_frames: int) -> Node:
	for _i: int in range(max_frames):
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if current != null and current.name.begins_with(prefix):
			await _settle(4)
			return current
	return get_tree().current_scene


func _click(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var center: Vector2 = control.get_global_rect().get_center()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	get_viewport().push_input(up, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _settle(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _check_state(condition: bool, label: String) -> void:
	_lines.append("%s | %s" % ["STATE_OK" if condition else "STATE_FAIL", label])
	if not condition:
		push_error("CAPTURE STATE FAIL: " + label)


func _write_manifest() -> void:
	_lines.append("")
	_lines.append("# Reference: Terraria contact/GIF in previews/player_hurt_20261116/refs")
	_lines.append("# (coordinator-verified 399.0-400.1 s: hit, away step, short dark flash).")
	_lines.append("# This project flash is red because the user explicitly required red; it does not")
	_lines.append("# claim the reference showed a pure red flash. No third-party asset is copied.")
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
