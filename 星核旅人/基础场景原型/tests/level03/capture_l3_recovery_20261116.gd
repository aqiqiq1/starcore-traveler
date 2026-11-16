extends Node

## Rendered evidence for the L3 local recovery cover (2026-11-16).
##
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/level03/capture_l3_recovery_20261116.tscn
##
## Real 640x360 engine frames. The headline sequence uses two real guard
## strikes; the remaining frames use the guard's own player_struck signal to
## reach the same transition quickly. All frames are state setup, not a full
## level playthrough. Old screenshots are never overwritten.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/l3_recovery_20261116"
const MANIFEST: String = "res://screenshots/l3_recovery_20261116/MANIFEST.txt"

var _level: Level03 = null
var _lines: Array[String] = []
var _struck_total: int = 0
var _num: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_clear_output()
	_lines.append("Star Core Traveler - L3 recovery cover evidence (2026-11-16)")
	_lines.append("Godot: %s  viewport 640x360, normal game viewport"
		% Engine.get_version_info()["string"])
	_lines.append("Approved timing: fade-out 0.25 s -> black hold 0.10 s -> fade-in 0.35 s.")
	_lines.append("All sequences are SETUP states (arena combat / edge walk), not a full playthrough.")
	_lines.append("Headline A uses two real guard strikes. B/C/D use the guard's own player_struck signal.")
	_lines.append("")
	await _seq_second_hit()
	await _seq_transition_strip()
	await _seq_auto_fall()
	await _seq_pause_freeze()
	await _seq_r_cleanup()
	_write_manifest()
	if _level != null and is_instance_valid(_level):
		_free_audio(_level)
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("L3_RECOVERY_CAPTURE_DONE frames=%d" % _num)
	get_tree().quit(0)


# --- A. real second hit -----------------------------------------------------

func _seq_second_hit() -> void:
	_lines.append("== A. real guard: first hit, second hit, fade-out, black reset, fade-in ==")
	await _new_level()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	var player: L3Player = _level.get_player()
	var base: int = _struck_total
	_check(await _wait_for_struck(base + 1, 600), "A first real guard hit")
	await _capture("a01_first_hit_no_reset.png",
		"SETUP real first hit only: hits=1, no cover, no reset. "
		+ "This proves the first hit does not respawn.")
	_check(await _wait_for_struck(base + 2, 900), "A second real guard hit")
	await _capture("a02_second_hit_red_pending.png",
		"SETUP real second hit: the existing 0.15 s red/reaction/pending is still on screen; "
		+ "the body has not been moved to the recovery point yet.")
	for _i: int in range(30):
		await get_tree().physics_frame
		if not _level.is_retry_pending():
			break
	_check(_level.is_recovery_active(), "A cover starts after the reaction")
	for _i: int in range(180):
		await get_tree().process_frame
		if _level.get_recovery_overlay_alpha() >= 0.45:
			break
	await _capture("a03_fade_out_partly_dark.png",
		"SETUP fade-out (not fully black yet): body is still away from the recovery point, "
		+ "reset_count must be 0.")
	for _i: int in range(180):
		await get_tree().process_frame
		if _level.get_recovery_reset_count() >= 1:
			break
	await _capture("a04_black_reset.png",
		"SETUP fully black cover: the reset ran exactly now (reset_alpha=1.0). "
		+ "Player is already at the unchanged guard-front recovery point; hits=0, no red.")
	for _i: int in range(240):
		await get_tree().process_frame
		if _level.get_recovery_phase() == "fade_in" \
				and _level.get_recovery_overlay_alpha() <= 0.55:
			break
	await _capture("a05_fade_in_partly_light.png",
		"SETUP fade-in: the normal body colour is back at the recovery point, no red carried over.")
	await _wait_recovery_done()
	var x0: float = _level.get_player().global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	Input.action_release(&"move_right")
	_check(_level.get_player().global_position.x > x0 + 8.0, "A real movement after the cover")
	await _capture("a06_after_fade_in_can_move.png",
		"SETUP after fade-in: alpha=0, override released, guard resumed, real D moved the body.")
	await _free_level()


# --- B. automatic fall ------------------------------------------------------

func _seq_auto_fall() -> void:
	_lines.append("")
	_lines.append("== B. automatic fall at the unchanged shared kill line ==")
	await _new_level()
	# Setup places the body on the real upper ledge; the fall itself is a real
	# D walk off its x=900 end into the open pit (not a teleport into the pit).
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	_level.debug_place_player_at(Vector2(850.0, 210.0))
	await _physics(2)
	await _capture("b01_ledge_before_fall.png",
		"SETUP standing on the real upper ledge before a real D walk off its end.")
	Input.action_press(&"move_right")
	var fell: bool = false
	for _i: int in range(140):
		await get_tree().physics_frame
		if _level.is_recovery_active():
			fell = true
			break
	Input.action_release(&"move_right")
	_check(fell, "B real edge walk starts the fall cover")
	await _capture("b02_fall_cover_active.png",
		"SETUP automatic fall cover: local intercept, not the shared player resetting visibly.")
	for _i: int in range(180):
		await get_tree().process_frame
		if _level.get_recovery_reset_count() >= 1:
			break
	await _capture("b03_fall_black_restore.png",
		"SETUP fall cover fully black: reset_alpha=1.0, opening stable point restored.")
	await _wait_recovery_done()
	var x0: float = _level.get_player().global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	Input.action_release(&"move_right")
	_check(_level.get_player().global_position.x > x0 + 8.0, "B real movement after the fall cover")
	await _capture("b04_fall_after_can_move.png",
		"SETUP after the fall fade-in: no black, no lock, real D moves the body.")
	await _free_level()


# --- C. pause freezes the clock --------------------------------------------

func _seq_pause_freeze() -> void:
	_lines.append("")
	_lines.append("== C. Esc pause over the cover; clock frozen ==")
	await _new_level()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	guard.player_struck.emit(-1)
	await _physics(2)
	guard.player_struck.emit(-1)
	await _physics(2)
	for _i: int in range(120):
		await get_tree().process_frame
		if _level.get_recovery_overlay_alpha() >= 0.05:
			break
	_check(_level.is_recovery_active(), "C cover active before pause")
	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await get_tree().process_frame
	_check(get_tree().paused, "C pause really opened")
	# Freeze once and keep the tree paused across both captures. The transition
	# clock must not advance between them.
	var alpha_a: float = _level.get_recovery_overlay_alpha()
	var phase_a: String = _level.get_recovery_phase()
	await _snap_paused("c01_pause_over_cover.png",
		"SETUP real pause page above the recovery cover; ordinary HUD is under the cover. "
		+ "Tree stays paused for c02 as well.")
	for _i: int in range(30):
		await get_tree().process_frame
	await _snap_paused("c02_pause_clock_frozen.png",
		"SETUP 30 paused idle frames later: same cover alpha/phase as c01 proves the clock is frozen.")
	_check(absf(_level.get_recovery_overlay_alpha() - alpha_a) < 0.001,
		"C alpha frozen across 30 paused frames (%.3f -> %.3f)"
			% [alpha_a, _level.get_recovery_overlay_alpha()])
	_check(_level.get_recovery_phase() == phase_a, "C phase frozen across the pause")
	get_tree().paused = false
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await get_tree().process_frame
	_check(await _wait_recovery_done(), "C cover continues and completes after resume")
	var x0: float = _level.get_player().global_position.x
	Input.action_press(&"move_right")
	await _physics(12)
	Input.action_release(&"move_right")
	_check(_level.get_player().global_position.x > x0 + 8.0, "C control after pause + cover")
	await _capture("c03_after_pause_resume.png",
		"SETUP after pause + resume: alpha=0 and real movement is restored.")
	await _free_level()


# --- D. R cleanup -----------------------------------------------------------

func _seq_r_cleanup() -> void:
	_lines.append("")
	_lines.append("== D. R during the cover: fast restart, no black left ==")
	await _new_level()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	guard.player_struck.emit(-1)
	await _physics(2)
	guard.player_struck.emit(-1)
	await _physics(2)
	for _i: int in range(120):
		await get_tree().process_frame
		if _level.get_recovery_overlay_alpha() >= 0.05:
			break
	_check(_level.is_recovery_active(), "D cover active before R")
	_send_key(KEY_R, true)
	await get_tree().process_frame
	_send_key(KEY_R, false)
	await get_tree().process_frame
	await _physics(4)
	_check(not _level.is_recovery_active() and _level.get_recovery_overlay_alpha() == 0.0,
		"D R clears the cover and black")
	await _capture("d01_r_restart_no_black.png",
		"SETUP R during the cover: opening stage restored, alpha=0, no black/lock left.")
	await _free_level()


# --- E. continuous strip ----------------------------------------------------

func _seq_transition_strip() -> void:
	_lines.append("")
	_lines.append("== E. continuous engine strip of one recovery transition (GIF source) ==")
	await _new_level()
	_level.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	var guard: L3Guard = _level.get_guard()
	guard.player_struck.emit(-1)
	await _physics(2)
	guard.player_struck.emit(-1)
	await _physics(2)
	for _i: int in range(120):
		await get_tree().process_frame
		if _level.is_recovery_active():
			break
	_check(_level.is_recovery_active(), "E strip starts on an active cover")
	var strip_dir: String = ProjectSettings.globalize_path(DIR + "/strip")
	DirAccess.make_dir_recursive_absolute(strip_dir)
	for name: String in DirAccess.get_files_at(strip_dir):
		if name.ends_with(".png"):
			DirAccess.remove_absolute(strip_dir + "/" + name)
	var frame_index: int = 0
	var start_ms: int = Time.get_ticks_msec()
	for _i: int in range(400):
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var name: String = "f%03d.png" % frame_index
		image.save_png(strip_dir + "/" + name)
		_lines.append("STRIP %s ms=%d %s" % [
			name, Time.get_ticks_msec() - start_ms, _state_line()])
		frame_index += 1
		if not _level.is_recovery_active() and frame_index > 3:
			break
		await get_tree().process_frame
	_lines.append("STRIP frames=%d total_ms=%d" % [
		frame_index, Time.get_ticks_msec() - start_ms])
	await _free_level()


# --- capture / state --------------------------------------------------------

func _capture(file_name: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await _snap_paused(file_name, note)
	get_tree().paused = false
	await get_tree().process_frame


## Capture while the caller already owns the paused state. The state line is
## read after the pause, so it matches the image.
func _snap_paused(file_name: String, note: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(DIR + "/" + file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		_num += 1
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
	_lines.append("%s | %s" % [file_name, note])
	_lines.append("  STATE %s" % _state_line())
	_lines.append("")


func _state_line() -> String:
	if _level == null or not is_instance_valid(_level):
		return "level=<none>"
	var player: L3Player = _level.get_player()
	var guard: L3Guard = _level.get_guard()
	return (
		"phase=%s alpha=%.3f hud_alpha=%.3f reset_alpha=%.3f reset_count=%d "
		+ "finished=%d kind=%s | x=%.2f y=%.2f tint=%.2f hits=%d "
		+ "guard=%s suspended=%s paused=%s"
	) % [
		_level.get_recovery_phase(), _level.get_recovery_alpha(),
		_level.get_recovery_overlay_alpha(), _level.get_recovery_reset_alpha(),
		_level.get_recovery_reset_count(), _level.get_recovery_finished_count(),
		_level.get_recovery_kind(), player.global_position.x, player.global_position.y,
		player.get_hurt_tint_amount(), _level.get_player_hits(),
		guard.get_state_name(), str(guard.is_suspended()), str(get_tree().paused),
	]


# --- harness ---------------------------------------------------------------

func _new_level() -> void:
	await _clear_level()
	_struck_total = 0
	_level = LEVEL_SCENE.instantiate() as Level03
	get_tree().root.add_child(_level)
	await _physics(24)
	var guard: L3Guard = _level.get_guard()
	if not guard.player_struck.is_connected(_on_struck):
		guard.player_struck.connect(_on_struck, CONNECT_DEFERRED)


func _on_struck(_facing: int) -> void:
	_struck_total += 1


func _wait_for_struck(target: int, limit: int) -> bool:
	for _i: int in range(limit):
		await get_tree().physics_frame
		if _struck_total >= target:
			return true
	return false


func _wait_recovery_done(limit: int = 1200) -> bool:
	for _i: int in range(limit):
		await get_tree().process_frame
		if _level != null and not _level.is_recovery_active():
			await _physics(2)
			return true
	return false


func _free_level() -> void:
	if _level != null and is_instance_valid(_level):
		_free_audio(_level)
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null


func _clear_level() -> void:
	get_tree().paused = false
	if _level != null and is_instance_valid(_level):
		_free_audio(_level)
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null
	get_tree().paused = false


func _free_audio(level: Node) -> void:
	if level != null and level.has_method("get_audio"):
		var audio: Node = level.call("get_audio") as Node
		if audio != null and audio.has_method("release_streams"):
			audio.call("release_streams")


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _clear_output() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for name: String in DirAccess.get_files_at(DIR):
		if name.ends_with(".png"):
			DirAccess.remove_absolute(DIR + "/" + name)


func _check(condition: bool, label: String) -> void:
	_lines.append("CHECK %s | %s" % ["OK" if condition else "FAIL", label])
	if not condition:
		push_warning("CAPTURE_CHECK_FAIL " + label)


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
