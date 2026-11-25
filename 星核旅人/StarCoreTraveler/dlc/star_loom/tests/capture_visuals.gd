extends Node

## 640x360 visual evidence for 星核织机.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/star_loom/tests/capture_visuals.tscn
##
## Saves to res://dlc/star_loom/tests/out/:
##   entry.png        the hall entrance, loom dormant, HUD entry objective
##   nodes.png        both orbit nodes live, shield ring, HUD node counter
##   core.png         both nodes down, bright exposed core, 0/3
##   stage.png        real third core hit -> stage 2, nodes respawn, event line
##   sweep.png        stage-3 sweep warning + band (live telegraph)
##   summon.png       stage-3 summon warning / summoned wisps
##   completion.png   "织机停转 · 用时 mm:ss"
##   title_loom_button.png  title menu with 星核织机 focused
##
## Every image is the live 640x360 viewport including the HUD.  Debug calls
## only pick a readable state (park a node, choose a stage/attack); the visible
## hits in core/stage are real J presses resolved by the shared player.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"
const OUT_DIR: String = "res://dlc/star_loom/tests/out"

var _loom: StarLoom
var _player: L3Player
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("LOOM_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
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
	_loom.get_camera().reset_smoothing()
	await _wait_physics(3)
	await _wait_process(10)


func _real_key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _swing() -> void:
	_real_key(KEY_J, true)
	await _wait_physics(8)
	_real_key(KEY_J, false)
	await _wait_seconds(0.5)


func _tap_q() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(2)
	Input.action_release(&"polarity")
	await _wait_physics(4)


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _park_nodes() -> void:
	_loom.debug_set_node_angle(0, PI * 0.5)
	_loom.debug_set_node_phase(0, true)
	_loom.debug_set_node_angle(1, -PI * 0.5)
	_loom.debug_set_node_phase(1, false)
	for node: LoomNode in _loom.get_nodes():
		node.set_orbit_enabled(false)
		node.set_phase_timer_enabled(false)


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		print("LOOM_CAPTURE missing scene")
		return
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	add_child(_loom)
	await _wait_process(6)
	await _wait_physics(10)
	_player = _loom.get_player()

	# 1. Entrance: player at the left edge, loom dormant in the distance.
	await _place(70.0, 320.0, false)
	await _wait_process(8)
	await _save("entry.png")

	# 2. Live nodes: walk far enough to start the boss, then park the two nodes
	# at readable top/bottom points and freeze attacks for one clean frame.
	await _place(470.0, 320.0, false)
	await _wait_physics(10)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_set_boss_grace(0.0)
	await _place(660.0, 320.0, false)
	_park_nodes()
	await _wait_process(10)
	await _save("nodes.png")

	# 3. Exposed core: remove both nodes in the formal way (their break path),
	# then show the bright diamond at 0 / 3.
	_loom.debug_expose_core()
	_loom.debug_set_core_phase(true)
	await _place(660.0, 320.0, false)
	await _wait_process(14)
	await _save("core.png")

	# 4. Stage 2 from a real third true hit: three real J swings, Q between.
	await _swing()
	await _tap_q()
	await _swing()
	await _tap_q()
	await _swing()
	await _wait_physics(6)
	await _wait_process(4)
	await _save("stage.png")

	# 5. Sweep warning + band at stage 3.
	_loom.debug_set_stage(3)
	_loom.debug_set_attacks_enabled(true)
	_loom.debug_set_boss_grace(0.0)
	_loom.debug_force_attack("sweep")
	# Telegraph first (the >=0.65 s warning lane), then the live band.
	await _wait_seconds(0.40)
	await _save("sweep_warning.png")
	await _wait_seconds(0.35)
	await _save("sweep.png")

	# 6. Summon warning and one/two wisps.  Step left of the active band so the
	# frame shows the summon, not a hit reaction.
	await _place(520.0, 320.0, false)
	_loom.debug_force_attack("summon")
	await _wait_seconds(0.85)
	await _wait_seconds(0.20)
	await _save("summon.png")

	# 7. Completion: stage 3 exposed core, three real J true hits.
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	_loom.debug_expose_core()
	_loom.debug_set_core_phase(true)
	await _place(660.0, 320.0, false)
	for index: int in range(3):
		await _swing()
		if index < 2:
			await _tap_q()
	await _wait_process(20)
	await _save("completion.png")

	# 8. Title menu with the real 星核织机 button focused.
	_loom.queue_free()
	_loom = null
	await _wait_process(6)
	var level: Node = (load(LEVEL_01) as PackedScene).instantiate()
	add_child(level)
	await _wait_process(20)
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu != null:
		var button: PixelMenuButton = menu.get_loom_button()
		if button != null:
			button.grab_focus()
	await _wait_process(10)
	await _save("title_loom_button.png")
	Input.action_release(&"move_right")
