extends Node

## 640x360 visual evidence for the L3 fixed health bar.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://scripts/level03/tests/capture_health_bar.tscn
##
## Saves to res://scripts/level03/tests/out/:
##   health_bar_hit.png    one real accepted guard hit -> one of two segments
##   health_bar_pause.png  pause page -> bar and its 生命值 label hidden

const LEVEL_03: String = "res://scenes/level_03.tscn"
const OUT_DIR: String = "res://scripts/level03/tests/out"

var _level: Level03
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("L3_HEALTH_BAR_CAPTURE saved=%d files=%s" % [
		_saved.size(), ", ".join(_saved)
	])
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


func _run() -> void:
	_level = (load(LEVEL_03) as PackedScene).instantiate() as Level03
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(6)
	await _wait_physics(10)
	var player: L3Player = _level.get_player()
	var guard: L3Guard = _level.get_guard()
	var hud: L3HUD = _level.get_hud()
	guard.set_suspended(true)
	# Setup places the body just outside the guard read; the final approach is
	# made with the real right input, not by teleporting into the arena shot.
	player.global_position = Vector2(1900.0, 320.0)
	player.velocity = Vector2.ZERO
	_level.get_camera().reset_smoothing()
	await _wait_physics(4)
	Input.action_press(&"move_right")
	for _index: int in range(90):
		if player.global_position.x >= 2000.0:
			break
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	player.velocity = Vector2.ZERO
	_level.get_camera().reset_smoothing()
	await _wait_physics(4)
	await _wait_process(8)

	# The level's own accepted-hit handler updates the bar; no HUD shortcut.
	guard.player_struck.emit(1)
	await _wait_physics(3)
	await _wait_process(3)
	await _save("health_bar_hit.png")
	print("STATE health_bar current=%d max=%d pos=%s hits=%d" % [
		hud.get_player_health_bar().get_current(),
		hud.get_player_health_bar().get_max(),
		str(hud.get_health_bar_rect().position),
		hud.get_hits(),
	])

	var pause_menu: Node = _level.get_pause_menu()
	pause_menu.call("open_pause")
	await _wait_process(10)
	await _save("health_bar_pause.png")
	print("STATE pause bar_visible=%s label_visible=%s paused=%s" % [
		str(hud.is_health_bar_visible()),
		str(hud.get_health_label().visible),
		str(get_tree().paused),
	])
	# Stop owned audio/players before quitting so the process exit is clean.
	var music: BaseLevelMusic = _level.get_music()
	if music != null:
		music.stop(0.0)
	var footsteps: Node = _level.get_node_or_null("Player/PlayerFootstepAudio")
	if footsteps != null:
		footsteps.call("stop")
	get_tree().paused = false
	_level.get_pause_menu().call("force_close")
	await _wait_process(20)
