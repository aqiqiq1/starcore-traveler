extends Node

## 640x360 evidence for the corrected proximity-hint timing.
## Run WITHOUT --headless:
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --resolution 640x360 \
##     --path . res://dlc/hint_timing/tests/capture_hint_timing.tscn
##
## Saves to res://screenshots/hint_timing_20261127/:
##   01_l1_spawn_no_hint.png        L1 spawn, one second, no event row
##   02_l1_gate_56px_full.png       L1 gate at 56 px, full teaching line
##   03_dlc3_spawn_no_hint.png      DLC3 spawn, no reminder
##   04_dlc3_gate_56px_reminder.png DLC3 gate at 56 px, short reminder
##   05_dlc2_spawn_no_hint.png      DLC2 spawn, no field/gate hint
##   06_dlc2_field_56px.png         DLC2 inversion field at 56 px
##   07_dlc2_gate_56px.png          DLC2 moon gate at 56 px, power reminder
##
## Every frame is the live viewport after real movement into range; no hint is
## forced by calling show_event() directly.

const OUT_DIR: String = "res://screenshots/hint_timing_20261127"
const L1_SCENE: String = "res://scenes/level_01.tscn"
const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for tip_id: String in ["polarity", "core_carry", "relay_link", "float_platform"]:
		MechanicTips.mark_seen(tip_id)
	await get_tree().process_frame
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	await _capture_l1()
	await _capture_loom()
	await _capture_rift()
	print("HINT_TIMING_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0 if _saved.size() == 7 else 1)


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


func _load(
	scene_path: String, no_menu: bool = false, configure: Callable = Callable()
) -> Node:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		print("CAPTURE_FAIL load %s" % scene_path)
		return null
	var level: Node = packed.instantiate()
	if no_menu and level.has_method("set"):
		level.set("enable_start_menu", false)
	if configure.is_valid():
		configure.call(level)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	get_tree().paused = false
	await _wait_process(6)
	return level


func _cleanup(level: Node) -> void:
	DemoAudio.stop_world()
	get_tree().paused = false
	get_tree().current_scene = null
	if level != null and is_instance_valid(level):
		level.queue_free()
	await _wait_process(10)


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


func _capture_l1() -> void:
	var level: Node = await _load(L1_SCENE, true)
	if level == null:
		return
	await _wait_process(4)
	level.call("_finish_intro")
	await _wait_process(6)
	var player: PrototypePlayer = level.call("get_player") as PrototypePlayer
	var gate: PolarityGate = level.call("get_exit_polarity_gate") as PolarityGate
	var camera: Camera2D = level.call("get_camera") as Camera2D
	if player == null or gate == null or camera == null:
		print("CAPTURE_FAIL l1")
		await _cleanup(level)
		return
	await _wait_seconds(1.0)
	await _save("01_l1_spawn_no_hint")
	var hud: Level01HUD = level.call("get_hud") as Level01HUD
	print("L1_SPAWN hint_count=%d event=%s" % [
		int(level.call("get_exit_gate_full_hint_count")),
		hud.get_toast_text()
	])

	player.global_position = Vector2(gate.global_position.x - 56.0, 300.0)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(true)
	player.set_facing_direction(1)
	camera.reset_smoothing()
	await _wait_physics(5)
	await _wait_seconds(0.2)
	print("L1_56 hint_count=%d event=%s" % [
		int(level.call("get_exit_gate_full_hint_count")),
		hud.get_toast_text()
	])
	await _save("02_l1_gate_56px_full")
	await _cleanup(level)


func _capture_loom() -> void:
	var level: Node = await _load(LOOM_SCENE, false, func(node: Node) -> void:
		node.set("show_intro_guide", false)
		node.set("show_intro_cinematic", false)
	)
	if level == null:
		return
	await _wait_process(6)
	await _wait_physics(10)
	var player: L3Player = level.call("get_player") as L3Player
	var gate: PolarityGate = level.call("get_gate_first") as PolarityGate
	var camera: Camera2D = level.call("get_camera") as Camera2D
	if player == null or gate == null or camera == null:
		print("CAPTURE_FAIL loom")
		await _cleanup(level)
		return
	await _wait_seconds(1.0)
	await _save("03_dlc3_spawn_no_hint")
	var hud: LoomHUD = level.call("get_hud") as LoomHUD
	print("DLC3_SPAWN hint_count=%d event=%s" % [
		int(level.call("get_gate_hint_count")), hud.get_event_text()
	])

	player.global_position = Vector2(gate.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	player.face_direction(1)
	camera.reset_smoothing()
	await _wait_physics(8)
	await _wait_seconds(0.2)
	print("DLC3_56 hint_count=%d event=%s" % [
		int(level.call("get_gate_hint_count")), hud.get_event_text()
	])
	await _save("04_dlc3_gate_56px_reminder")
	await _cleanup(level)


func _capture_rift() -> void:
	var level: Node = await _load(RIFT_SCENE, false, func(node: Node) -> void:
		node.set("show_intro_guide", false)
		node.set("show_intro_cinematic", false)
	)
	if level == null:
		return
	await _wait_process(6)
	await _wait_physics(10)
	var player: L3Player = level.call("get_player") as L3Player
	var field: RiftInversionField = level.call("get_field_a") as RiftInversionField
	var gate: PolarityGate = level.call("get_gate_moon") as PolarityGate
	var camera: Camera2D = level.call("get_camera") as Camera2D
	if player == null or field == null or gate == null or camera == null:
		print("CAPTURE_FAIL rift")
		await _cleanup(level)
		return
	await _wait_seconds(1.0)
	await _save("05_dlc2_spawn_no_hint")
	var hud: RiftWorkshopHUD = level.call("get_hud") as RiftWorkshopHUD
	print("DLC2_SPAWN field=%d gate=%d event=%s" % [
		int(level.call("get_field_hint_count")),
		int(level.call("get_gate_hint_count")),
		hud.get_event_text()
	])

	player.global_position = Vector2(field.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	player.face_direction(1)
	camera.reset_smoothing()
	await _wait_physics(8)
	await _wait_seconds(0.2)
	print("DLC2_FIELD_56 field=%d event=%s" % [
		int(level.call("get_field_hint_count")), hud.get_event_text()
	])
	await _save("06_dlc2_field_56px")

	player.global_position = Vector2(gate.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	player.face_direction(1)
	camera.reset_smoothing()
	await _wait_physics(8)
	await _wait_seconds(0.2)
	print("DLC2_GATE_56 gate=%d event=%s" % [
		int(level.call("get_gate_hint_count")), hud.get_event_text()
	])
	await _save("07_dlc2_gate_56px")
	await _cleanup(level)
