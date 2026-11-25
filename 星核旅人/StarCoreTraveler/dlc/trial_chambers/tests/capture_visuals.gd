extends Node

## 640x360 visual evidence for the trial.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://dlc/trial_chambers/tests/capture_visuals.tscn
##
## Saves to tests/trial_20261125/out/:
##   gate_gold_closed.png, gate_gold_open.png, gate_cyan_closed.png,
##   arena.png, pause.png, completion.png, title_trial_button.png
##
## The completion shot uses guard.debug_force_death() only to reach the page for
## a picture; the real three-hit route is verified separately in route_test.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"
const OUT_DIR: String = "res://dlc/trial_chambers/tests/out"

var _trial: TrialChambers
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("TRIAL_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


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


func _place(player: L3Player, x: float, positive: bool) -> void:
	player.global_position = Vector2(x, 320.0)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(positive)
	_trial.get_camera().reset_smoothing()
	await _wait_physics(2)


func _run() -> void:
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	_trial = packed.instantiate() as TrialChambers
	_trial.show_intro_guide = false
	add_child(_trial)
	await _wait_process(4)
	await _wait_physics(10)
	var player: L3Player = _trial.get_player()

	# Gold gate closed: cyan player, gold requirement.
	await _place(player, 235.0, false)
	_trial.get_gate_gold().set_required_positive(true)
	await _wait_process(30)
	await _save("gate_gold_closed.png")

	# Gold gate open: same approach position, player switches to 辉相.  Stand
	# beside the gate (not inside) so the three rising dashes stay visible.
	await _place(player, 250.0, true)
	await _wait_process(12)
	await _save("gate_gold_open.png")

	# Cyan gate closed: 辉相 player facing the cyan requirement.
	await _place(player, 470.0, true)
	_trial.get_gate_cyan().set_required_positive(false)
	await _wait_process(30)
	await _save("gate_cyan_closed.png")

	# Arena with the live guard.
	await _place(player, 885.0, true)
	_trial.get_guard().set_suspended(false)
	await _wait_process(40)
	await _save("arena.png")

	# Simple two-item pause page.
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(1)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(12)
	await _save("pause.png")
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(1)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(6)

	# Completion page (visual state only; see route_test for the real fight).
	# debug_force_death() marks the guard dead without its deferred signal, so
	# emit the same defeated signal the real death path uses to activate the
	# trial's finish point.
	_trial.get_guard().debug_force_death()
	_trial.get_guard().defeated.emit()
	await _wait_process(20)
	await _place(player, 1204.0, true)
	await _wait_process(20)
	await _save("completion.png")

	# Title menu with the real 试炼场 button focused.
	_trial.queue_free()
	_trial = null
	await _wait_process(6)
	var level: Node = (load(LEVEL_01) as PackedScene).instantiate()
	add_child(level)
	await _wait_process(20)
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu != null:
		var button: PixelMenuButton = menu.get_trial_button()
		if button != null:
			button.grab_focus()
	await _wait_process(10)
	await _save("title_trial_button.png")
