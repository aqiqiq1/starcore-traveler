extends Node

## Read-only 640x360 audit capture of the three base levels, for this session's
## "正作只审计、不改" requirement.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://dlc/rift_workshop/tests/audit_base_levels.tscn
##
## It loads the production scenes, presses the real Start button once (instead
## of hiding the menu), waits for the normal intro, and saves the live viewport.
## Nothing in the base levels is modified and no state is persisted.

const LEVEL_01: String = "res://scenes/level_01.tscn"
const LEVEL_02: String = "res://scenes/level_02.tscn"
const LEVEL_03: String = "res://scenes/level_03.tscn"
const OUT_DIR: String = "res://dlc/rift_workshop/tests/out"

var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("BASE_AUDIT saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
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


func _load_level(path: String) -> Node:
	var level: Node = (load(path) as PackedScene).instantiate()
	add_child(level)
	await _wait_process(10)
	return level


func _run() -> void:
	# 1. Title.
	var level_01: Node = await _load_level(LEVEL_01)
	await _wait_physics(20)
	await _save("audit_title.png")

	# 2. Level 01 gameplay after the real Start press.
	var menu: StartMenu = level_01.get_node_or_null("StartMenu") as StartMenu
	if menu != null:
		var start_button: Button = menu.get_start_button()
		if start_button != null:
			start_button.pressed.emit()
		await _wait_process(10)
		# Launching from a console can leave the OS focus on the terminal, which
		# trips the production "lost focus pauses the transition" rule.  Take the
		# window back and resume the same transition with its own method.
		if menu.is_transition_paused():
			DisplayServer.window_move_to_foreground()
			menu.call("_set_transition_paused", false)
	var deadline: int = Time.get_ticks_msec() + 4500
	while Time.get_ticks_msec() < deadline:
		if get_tree().paused:
			get_tree().paused = false
		if menu != null and menu.is_transition_paused():
			menu.call("_set_transition_paused", false)
		await get_tree().process_frame
	print("AUDIT_LEVEL01 phase=%s" % (str(menu.get("_phase")) if menu != null else "-"))
	await _wait_physics(30)
	await _save("audit_level_01.png")
	level_01.queue_free()
	await _wait_process(8)

	# 3. Level 02 spawn.
	var level_02: Node = await _load_level(LEVEL_02)
	await _wait_physics(40)
	await _save("audit_level_02.png")
	level_02.queue_free()
	await _wait_process(8)

	# 4. Level 03 spawn (its own intro overlay may be visible).
	var level_03: Node = await _load_level(LEVEL_03)
	await _wait_physics(40)
	await _save("audit_level_03.png")
	level_03.queue_free()
	await _wait_process(8)
