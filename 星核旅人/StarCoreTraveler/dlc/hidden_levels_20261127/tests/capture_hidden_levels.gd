extends Node

## 640x360 evidence for the two hidden side-chapter entrances.
## Run WITHOUT --headless:
##
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --resolution 640x360 \
##     --path . res://dlc/hidden_levels_20261127/tests/capture_hidden_levels.tscn
##
## Saves to res://screenshots/hidden_levels_20261127/:
##   00_chapter_page_before_discovery_640.png  four mainline rows only
##   01_dlc3_rift_entrance_640.png             mirror rift at x=420, no prompt
##   02_l3_trial_stele_640.png                 stele before the city gate
##   03_dlc3_rift_hint_56px_640.png            one-shot line at 56 px
##   04_l3_trial_hint_56px_640.png             one-shot line at 56 px
##   05_dlc3_return_checkpoint_640.png         continue-mainline return state
##   06_chapter_page_after_discovery_640.png   side rows revealed
##
## Every frame is the live 640x360 viewport; hints are caused by moving the
## real player into range, never by calling show_event() directly.

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")

const OUT_DIR: String = "res://screenshots/hidden_levels_20261127"
const LEVEL_01: String = "res://scenes/level_01.tscn"
const LEVEL_03: String = "res://scenes/level_03.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const PROGRESS: String = "user://hidden_levels_capture.cfg"

var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for tip_id: String in ["polarity", "core_carry", "relay_link", "float_platform"]:
		MechanicTips.mark_seen(tip_id)
	await get_tree().process_frame
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
	await _capture_dlc3()
	await _capture_l3()
	await _capture_return()
	await _capture_chapter_pages()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
	print("HIDDEN_LEVELS_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0 if _saved.size() == 7 else 1)


func _capture_dlc3() -> void:
	var level: Node = await _load(LOOM, func(node: Node) -> void:
		node.set("chapter_progress_path", PROGRESS)
		node.set("show_intro_guide", false)
		node.set("show_intro_cinematic", false)
	)
	if level == null:
		return
	var gate: HiddenRouteGate = level.call("get_hidden_rift_gate") as HiddenRouteGate
	var player: L3Player = level.call("get_player") as L3Player
	var camera: Camera2D = level.call("get_camera") as Camera2D
	# 120 px left of the entrance: outside every 56 px world hint, so the
	# entrance frame has no stale event line.
	player.global_position = Vector2(gate.global_position.x - 120.0, 320.0)
	player.velocity = Vector2.ZERO
	player.face_direction(1)
	camera.reset_smoothing()
	await _wait_physics(6)
	# Let any mainline approach line from the teleport (second gate / core)
	# expire so the entrance frame itself is quiet.  The entrance's own hint
	# stays silent because this spot is outside 56 px.
	await _wait_seconds(3.6)
	print("SHOT_DLC3_ENTRANCE gate=%s hint=%d event=%s" % [
		str(gate.global_position), gate.get_hint_shown_count(),
		(level.call("get_hud") as LoomHUD).get_event_text()
	])
	await _save("01_dlc3_rift_entrance_640")
	player.global_position = Vector2(gate.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()
	await _wait_physics(5)
	await _wait_seconds(0.3)
	print("SHOT_DLC3_HINT hint=%d event=%s" % [
		gate.get_hint_shown_count(),
		(level.call("get_hud") as LoomHUD).get_event_text()
	])
	await _save("03_dlc3_rift_hint_56px_640")
	await _cleanup(level)


func _capture_l3() -> void:
	var level: Node = await _load(LEVEL_03)
	if level == null:
		return
	(level.call("get_guard") as L3Guard).set_suspended(true)
	var gate: HiddenRouteGate = level.call("get_hidden_trial_gate") as HiddenRouteGate
	var player: L3Player = level.call("get_player") as L3Player
	var camera: Camera2D = level.call("get_camera") as Camera2D
	player.global_position = Vector2(gate.global_position.x - 80.0, 320.0)
	player.velocity = Vector2.ZERO
	player.face_direction(1)
	camera.reset_smoothing()
	await _wait_physics(6)
	await _wait_seconds(0.4)
	print("SHOT_L3_ENTRANCE gate=%s hint=%d event=%s" % [
		str(gate.global_position), gate.get_hint_shown_count(),
		(level.call("get_hud") as L3HUD).get_event_text()
	])
	await _save("02_l3_trial_stele_640")
	player.global_position = Vector2(gate.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()
	await _wait_physics(5)
	await _wait_seconds(0.3)
	print("SHOT_L3_HINT hint=%d event=%s" % [
		gate.get_hint_shown_count(),
		(level.call("get_hud") as L3HUD).get_event_text()
	])
	await _save("04_l3_trial_hint_56px_640")
	await _cleanup(level)


func _capture_return() -> void:
	var level: Node = await _load(LOOM, func(node: Node) -> void:
		node.set("chapter_progress_path", PROGRESS)
		node.set("resume_from_side", true)
	)
	if level == null:
		return
	await _wait_process(8)
	await _wait_seconds(0.4)
	var player: L3Player = level.call("get_player") as L3Player
	print("SHOT_RETURN resume=%s player=%s checkpoint=%s bay=%s gate1=%s gate2powered=%s event=%s" % [
		str(level.call("is_side_resume_active")), str(player.global_position),
		str((level.call("get_checkpoint") as LevelCheckpoint).is_activated()),
		str((level.call("get_core_bay") as CoreDeliveryBay).is_occupied()),
		str((level.call("get_gate_first") as PolarityGate).is_open()),
		str(level.call("is_second_gate_powered")),
		(level.call("get_hud") as LoomHUD).get_event_text()
	])
	await _save("05_dlc3_return_checkpoint_640")
	await _cleanup(level)


func _capture_chapter_pages() -> void:
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, PROGRESS)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L2, PROGRESS)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L3, PROGRESS)
	var level: Node = await _load(LEVEL_01, func(node: Node) -> void:
		var menu: StartMenu = node.get_node_or_null("StartMenu") as StartMenu
		if menu != null:
			menu.chapter_progress_path = PROGRESS
		node.set("enable_start_menu", true)
	)
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		await _cleanup(level)
		return
	await _wait_process(8)
	menu.get_chapter_button().pressed.emit()
	await _wait_process(8)
	print("SHOT_PAGE_BEFORE trial_visible=%s rift_visible=%s text=%s" % [
		str(menu.get_chapter_row(CHAPTER_PROGRESS.ID_TRIAL).visible),
		str(menu.get_chapter_row(CHAPTER_PROGRESS.ID_RIFT).visible),
		menu.get_chapters_progress_text()
	])
	await _save("00_chapter_page_before_discovery_640")
	menu.call("_close_chapters")
	await _wait_process(3)
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_TRIAL, PROGRESS)
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_RIFT, PROGRESS)
	menu.get_chapter_button().pressed.emit()
	await _wait_process(8)
	print("SHOT_PAGE_AFTER trial_visible=%s rift_visible=%s text=%s" % [
		str(menu.get_chapter_row(CHAPTER_PROGRESS.ID_TRIAL).visible),
		str(menu.get_chapter_row(CHAPTER_PROGRESS.ID_RIFT).visible),
		menu.get_chapters_progress_text()
	])
	await _save("06_chapter_page_after_discovery_640")
	await _cleanup(level)


# --- helpers ---------------------------------------------------------------

func _load(scene_path: String, configure: Callable = Callable()) -> Node:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		print("HIDDEN_LEVELS_CAPTURE missing %s" % scene_path)
		return null
	var level: Node = packed.instantiate()
	if configure.is_valid():
		configure.call(level)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	get_tree().paused = false
	await _wait_process(8)
	await _wait_physics(8)
	return level


func _cleanup(level: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null and is_instance_valid(current):
		current.queue_free()
	await _wait_process(14)


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() != 640 or image.get_height() != 360:
		print("CAPTURE_SIZE unexpected %dx%d, resizing" % [
			image.get_width(), image.get_height()
		])
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var error: Error = image.save_png(directory.path_join(shot_name + ".png"))
	_saved.append(shot_name)
	print("SHOT %s size=%dx%d error=%d" % [
		shot_name, image.get_width(), image.get_height(), error
	])


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
