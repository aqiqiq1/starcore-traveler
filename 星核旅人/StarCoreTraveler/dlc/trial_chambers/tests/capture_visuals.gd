extends Node

## 640x360 visual evidence for the trial.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://dlc/trial_chambers/tests/capture_visuals.tscn
##
## Saves to res://dlc/trial_chambers/tests/out/:
##   ambience_state.png (test-only strip with the live ambience player state),
##   phase_crystal.png, gate_wrong_q.png, gate_gold_closed.png,
##   gate_gold_open.png, health_bar_hit.png, health_bar_pause.png,
##   gate_cyan_closed.png, arena.png, failure_retry.png, pause.png,
##   completion.png, title_trial_button.png
##
## phase_crystal / gate_wrong_q / gate_gold_open / health_bar_hit are the
## current evidence: the crystal key, the red reject + Q keycap, the open sun
## door and the fixed two-segment red bar after one real accepted hit.  The hit
## shot is followed by a real R restart so the later arena and failure shots
## start from a full two-segment bar.  health_bar_pause.png proves the bar and
## its 生命值 label are hidden by the pause page.
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


## Evidence shot for the ambience integration.  The strip is drawn by this test
## harness only (not by the game) and reads the live AudioStreamPlayer state.
func _save_ambience_state(ambience: DlcChapterAmbience) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var background: ColorRect = ColorRect.new()
	background.position = Vector2(8.0, 334.0)
	background.size = Vector2(624.0, 20.0)
	background.color = Color(0.008, 0.02, 0.026, 0.86)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(background)
	var label: Label = Label.new()
	label.position = Vector2(12.0, 337.0)
	label.size = Vector2(616.0, 16.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.92, 0.97, 0.94))
	label.text = "%s | %.2f s | vol %.1f dB | loop %s | playing %s | pos %.2f s" % [
		ambience.get_stream_path().get_file(),
		ambience.get_stream_length(),
		ambience.get_volume_db(),
		"on" if ambience.is_stream_looping() else "off",
		"yes" if ambience.is_playing() else "no",
		ambience.get_playback_position(),
	]
	layer.add_child(label)
	await _save("ambience_state.png")
	layer.queue_free()
	await _wait_process(2)


func _run() -> void:
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	_trial = packed.instantiate() as TrialChambers
	_trial.show_intro_guide = false
	_trial.show_intro_cinematic = false
	# The parity capture scene owns the teaching-popup shot; this route capture
	# stays deterministic and never pauses on a gate approach.
	_trial.show_mechanic_tips = false
	add_child(_trial)
	await _wait_process(4)
	await _wait_physics(10)
	var player: L3Player = _trial.get_player()

	# Ambience state evidence (live AudioStreamPlayer values drawn by the test
	# harness only).
	await _save_ambience_state(_trial.get_ambience())

	# The crystal key before the gold gate.
	await _place(player, 190.0, false)
	await _wait_process(14)
	await _save("phase_crystal.png")

	# Wrong-phase contact: red deny pulse + the icon-only Q keycap.  Hold the
	# real right input until the gate rejects; capture immediately while the
	# one-second keycap is visible.
	await _place(player, 248.0, false)
	Input.action_press(&"move_right")
	for _index: int in range(80):
		if _trial.get_q_hint().is_active():
			break
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	# Step back a few pixels while the one-second keycap is still up, so the
	# fixed lower-left bar is not confused with the bright gate band.  This is
	# still the real denied state; no state is forced.
	Input.action_press(&"move_left")
	await _wait_physics(6)
	Input.action_release(&"move_left")
	await _wait_process(1)
	await _save("gate_wrong_q.png")

	# Let the keycap and red pulse expire before the clean open still.
	await get_tree().create_timer(1.2).timeout
	# Same-phase open: a 辉相 player beside the gold door, no padlock and the
	# bright open brackets + rising pass cue visible.  Wait past the 0.15 s
	# spread so the still is the settled open state, not the opening flash.
	await _place(player, 250.0, true)
	await get_tree().create_timer(0.35).timeout
	await _wait_process(2)
	await _save("gate_gold_open.png")

	# Two-segment hit bar: one real accepted guard hit, then R restarts the
	# chapter so the later failure/arena pictures begin with a full bar.
	_trial.get_guard().player_struck.emit(1)
	await _wait_physics(4)
	await _wait_process(2)
	await _save("health_bar_hit.png")
	# Legacy filename kept so older links do not show a stale heart row.
	await _save("hit_pips.png")
	_push_key(KEY_R, true)
	await _wait_physics(1)
	_push_key(KEY_R, false)
	await _wait_process(8)

	# Gold gate closed: cyan player, gold requirement.
	await _place(player, 235.0, false)
	_trial.get_gate_gold().set_required_positive(true)
	await _wait_process(30)
	await _save("gate_gold_closed.png")

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

	# Failure restart: two accepted hits (the guard's own signal) must fade to
	# black, rebuild the guard and put the player back at the arena entrance
	# instead of leaving the scene stuck.  Wait on the real state, not a frame
	# count: the windowed build is not locked to 60 fps.
	_trial.get_guard().player_struck.emit(1)
	await _wait_physics(4)
	_trial.get_guard().player_struck.emit(1)
	var seen_recovery: bool = false
	for _index: int in range(3000):
		if _trial.is_recovery_active():
			seen_recovery = true
		elif seen_recovery:
			break
		await get_tree().process_frame
	await _wait_process(6)
	await _save("failure_retry.png")

	# Simple two-item pause page.
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(1)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(12)
	await _save("pause.png")
	await _save("health_bar_pause.png")
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
