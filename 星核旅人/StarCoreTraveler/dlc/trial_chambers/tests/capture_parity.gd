extends Node

## 640x360 evidence for the third-round UI parity pass.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/trial_chambers/tests/capture_parity.tscn
##
## Saves to res://dlc/trial_chambers/tests/out/:
##   trial_guide_1.png, trial_guide_2.png, trial_guide_3.png,
##   pause.png, completion.png
## (The old trial_gate_tip.png is retired: the gate now teaches through its
## sun/moon lock and the Q keycap, captured by capture_visuals.gd.)
## Each shot is the live 640x360 viewport; the guide and popup are paused by
## their real nodes, and the completion page is reached through the guard's
## existing debug death + defeated signal (the real route is in route_test).

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const OUT_DIR: String = "res://dlc/trial_chambers/tests/out"

var _trial: TrialChambers
var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	MechanicTips.reset_for_test()
	await _run()
	print("TRIAL_PARITY_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	_saved.append(name)
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_process(2)
	_push_key(code, false)
	await _wait_process(3)


func _run() -> void:
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	_trial = packed.instantiate() as TrialChambers
	_trial.show_intro_guide = true
	_trial.show_intro_cinematic = false
	_trial.show_mechanic_tips = true
	get_tree().root.add_child(_trial)
	get_tree().current_scene = _trial
	await _wait_process(8)
	await _wait_physics(8)

	var guide: DlcGuide = _trial.get_intro_guide()
	if guide != null and guide.is_open():
		await _wait_seconds(1.2)
		await _save("trial_guide_1.png")
		await _tap_key(KEY_F)
		await _wait_seconds(1.2)
		await _save("trial_guide_2.png")
		await _tap_key(KEY_F)
		await _wait_seconds(1.2)
		await _save("trial_guide_3.png")
		await _tap_key(KEY_F)
		await _wait_process(5)
	else:
		print("CAPTURE_FAIL guide not open")

	# Stop later teaching triggers from pausing the remaining shots.
	var player: L3Player = _trial.get_player()
	player.global_position = Vector2(238.0, 320.0)
	player.velocity = Vector2.ZERO
	await _wait_process(10)
	_trial.show_mechanic_tips = false
	await _tap_key(KEY_ESCAPE)
	await _wait_seconds(0.35)
	await _wait_process(2)
	await _save("pause.png")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)

	var guard: L3Guard = _trial.get_guard()
	guard.debug_force_death()
	guard.defeated.emit()
	await _wait_process(10)
	player.global_position = Vector2(1204.0, 320.0)
	player.velocity = Vector2.ZERO
	await _wait_process(20)
	await _save("completion.png")

	# Release the live scene and its audio before quit so the capture exits
	# without ObjectDB leak warnings.
	if _trial != null and is_instance_valid(_trial):
		var ambience: DlcChapterAmbience = _trial.get_ambience()
		if ambience != null:
			ambience.stop(0.0)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().current_scene = null
	_trial.queue_free()
	_trial = null
	await _wait_process(2)
	for _index: int in range(20):
		await get_tree().process_frame
