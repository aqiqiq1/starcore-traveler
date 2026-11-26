extends Node

## 640x360 visual evidence for the rift workshop.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://dlc/rift_workshop/tests/capture_visuals.tscn
##
## Saves to res://dlc/rift_workshop/tests/out/:
##   ambience_state.png  test-only strip with the live ambience player state
##   inversion.png        real walk into InversionA, flip flash + event line
##   gate_closed.png      gold polarity gate closed (澜相 player outside)
##   gate_open.png        gold polarity gate open, 3 rising dashes visible
##   bridge_solid.png     player standing on the gold PhaseBridge
##   bridge_gone.png      same spot after Q: deck gone, dissolve burst + body
##                        already falling toward the safe lower shelf
##   wisp.png             PolarityWisp with its pre-pulse telegraph ring
##   wisp_burst.png       wisp kill burst (0.14 s; visual-only kill here, the
##                        real J kill is covered by mechanics/route tests)
##   twins_intro.png      0.8 s opening hover, both guards suspended, HUD line
##   twins.png            both guards live after the intro
##   failure_retry.png    two accepted hits -> black fade -> arena entrance
##   completion.png       "裂隙封闭 · 用时 mm:ss" (visual state only; the real
##                        three-hit + three-hit route is route_test.tscn)
##   title_rift_button.png  title menu with 裂隙工坊 focused
##
## Every image is the live 640x360 viewport, including the HUD; nothing is
## composited from separate sprites.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"
const OUT_DIR: String = "res://dlc/rift_workshop/tests/out"

var _rift: RiftWorkshop
var _player: L3Player
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("RIFT_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
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


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(3)
	await _wait_process(12)


func _press_right_until(target: float, max_frames: int) -> void:
	Input.action_press(&"move_right")
	for _index: int in range(max_frames):
		if _player.global_position.x >= target:
			break
		await get_tree().physics_frame
	Input.action_release(&"move_right")


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


func _wait_until_intro_done() -> void:
	for _index: int in range(180):
		if not _rift.is_arena_intro_active():
			return
		await get_tree().physics_frame


func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if packed == null:
		print("RIFT_CAPTURE missing scene")
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	_rift.show_intro_cinematic = false
	add_child(_rift)
	await _wait_process(6)
	await _wait_physics(10)
	_player = _rift.get_player()

	# Ambience state evidence (live AudioStreamPlayer values drawn by the test
	# harness only).
	await _save_ambience_state(_rift.get_ambience())

	# 1. Inversion: a real walk into the curtain, captured during the flash.
	await _place(118.0, 320.0, false)
	await _wait_process(10)
	await _press_right_until(160.0, 120)
	await _wait_physics(2)
	await _save("inversion.png")

	# 1b. Polarity gate: closed and open at the chapter's own gold gate.  The
	# open state now adds three rising dashes, so hold it for a few frames.
	await _place(235.0, 320.0, false)
	await _wait_physics(6)
	await _wait_process(6)
	await _save("gate_closed.png")
	await _place(235.0, 320.0, true)
	await _wait_physics(10)
	await _wait_process(8)
	await _save("gate_open.png")

	# 2. Bridge solid: 辉相 player on the gold deck.
	await _place(710.0, 280.0, true)
	await _wait_process(24)
	await _save("bridge_solid.png")

	# 3. Bridge gone: the same spot one Q later, body just starting to fall and
	# the 0.18 s dissolve burst still bright.
	_player.set_polarity_state(false)
	await _wait_physics(2)
	await _save("bridge_gone.png")

	# 4. Wisp telegraph: stand on landing A and wait for the charging ring.
	await _place(760.0, 280.0, true)
	var wisp: RiftPolarityWisp = _rift.get_wisps()[2]
	for _index: int in range(420):
		if wisp.get_pulse_time_left() < 0.42 and wisp.is_alive():
			break
		await get_tree().physics_frame
	await _save("wisp.png")

	# 4b. Wisp burst: kill this one for the picture only, so the white burst is
	# not covered by the player's swing arc.  mechanics_test.tscn proves the
	# same burst arrives from a real J hit.
	wisp.kill()
	await _wait_physics(1)
	await _save("wisp_burst.png")

	# 5. Twin guards: the 0.8 s opening hover with both guards suspended and the
	# HUD event line, then the live fight state after the intro.
	await _place(1100.0, 320.0, false)
	await _wait_physics(10)
	await _place(1338.0, 320.0, false)
	await _wait_physics(6)
	await _wait_process(4)
	await _save("twins_intro.png")
	await _wait_until_intro_done()
	await _wait_physics(12)
	await _wait_process(6)
	await _save("twins.png")

	# Failure restart with both guards: two accepted hits fade to black, then
	# both guards are rebuilt at their spawns with the 0.8 s intro again and the
	# player is back at the arena entrance (no stuck black screen).
	_rift.get_guard_gold().player_struck.emit(1)
	await _wait_physics(4)
	_rift.get_guard_gold().player_struck.emit(1)
	var seen_recovery: bool = false
	for _index: int in range(3000):
		if _rift.is_recovery_active():
			seen_recovery = true
		elif seen_recovery:
			break
		await get_tree().process_frame
	await _wait_process(6)
	await _save("failure_retry.png")

	# 6. Completion page.  Visual state only: debug_force_death() + the same
	# defeated signal the real death path emits.  route_test.tscn proves the
	# real six-true-hit route.
	_rift.get_guard_gold().debug_force_death()
	_rift.get_guard_gold().defeated.emit()
	_rift.get_guard_cyan().debug_force_death()
	_rift.get_guard_cyan().defeated.emit()
	await _wait_process(20)
	await _place(1550.0, 320.0, true)
	await _wait_process(20)
	await _save("completion.png")

	# 7. Title menu with the real 裂隙工坊 button focused.
	_rift.queue_free()
	_rift = null
	await _wait_process(6)
	var level: Node = (load(LEVEL_01) as PackedScene).instantiate()
	add_child(level)
	await _wait_process(20)
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu != null:
		var button: PixelMenuButton = menu.get_rift_button()
		if button != null:
			button.grab_focus()
	await _wait_process(10)
	await _save("title_rift_button.png")
	Input.action_release(&"move_right")
