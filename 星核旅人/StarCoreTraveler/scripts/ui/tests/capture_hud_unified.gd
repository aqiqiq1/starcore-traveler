extends Node

## 640x360 evidence capture for the unified HUD.
## Run WITHOUT --headless (the viewport must actually render):
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://scripts/ui/tests/capture_hud_unified.tscn
##
## Each shot loads the real chapter scene, ends the opening film/guide on a
## normal path, sets the HUD's public boss/health state, and saves the live
## viewport.  No scene layout, gameplay or assets are modified.

const OUT_DIR: String = "res://screenshots/hud_unified_20261127"

var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("HUD_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0 if _saved.size() >= 6 else 1)


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


func _load(path: String, no_menu: bool, no_film: bool) -> Node:
	var level: Node = (load(path) as PackedScene).instantiate()
	if no_menu:
		level.set("enable_start_menu", false)
	if no_film and _has_property(level, "show_intro_guide"):
		level.set("show_intro_guide", false)
	if no_film and _has_property(level, "show_intro_cinematic"):
		level.set("show_intro_cinematic", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	get_tree().paused = false
	await _wait_process(10)
	await _wait_physics(8)
	return level


func _has_property(object: Object, property_name: String) -> bool:
	for entry: Dictionary in object.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false


func _cleanup(level: Node) -> void:
	DemoAudio.stop_world()
	get_tree().paused = false
	get_tree().current_scene = null
	level.queue_free()
	await _wait_process(8)


func _run() -> void:
	# Base level 01: finish the real opening film, keep the gameplay HUD.
	var l1: Node = await _load("res://scenes/level_01.tscn", true, false)
	l1.call("_finish_intro")
	await _wait_process(10)
	get_tree().paused = false
	await _wait_seconds(0.35)
	await _save("hud_level_01.png")
	await _cleanup(l1)

	# Base level 02.
	var l2: Node = await _load("res://scenes/level_02.tscn", false, false)
	get_tree().paused = false
	await _wait_seconds(0.35)
	await _save("hud_level_02.png")
	await _cleanup(l2)

	# Base level 03 + guard boss bar (existing three true-damage points).
	var l3: Node = await _load("res://scenes/level_03.tscn", false, false)
	l3.set_process(false)
	l3.set_physics_process(false)
	var l3_hud: L3HUD = l3.get_node("HUD") as L3HUD
	l3_hud.set_boss_state(3, 3)
	l3_hud.set_boss_visible(true)
	l3_hud.set_objective("击败守卫取核")
	get_tree().paused = false
	await _wait_seconds(0.35)
	await _save("hud_level_03_boss.png")
	await _cleanup(l3)

	# DLC1 trial: shared 2-cell health + guard boss bar.
	var trial: Node = await _load(
		"res://dlc/trial_chambers/trial_chambers.tscn", false, true
	)
	trial.set_process(false)
	trial.set_physics_process(false)
	var trial_hud: TrialHUD = trial.get_node("HUD") as TrialHUD
	trial_hud.set_objective("目标：击败守卫（异相攻击有效）")
	trial_hud.set_boss_state(2, 3)
	trial_hud.set_boss_visible(true)
	trial_hud.set_player_hits(2, 2)
	get_tree().paused = false
	await _wait_seconds(0.35)
	await _save("hud_trial_boss.png")
	await _cleanup(trial)

	# DLC2 rift: shared 2-cell health + double-mirror boss bar.
	var rift: Node = await _load(
		"res://dlc/rift_workshop/rift_workshop.tscn", false, true
	)
	rift.set_process(false)
	rift.set_physics_process(false)
	var rift_hud: RiftWorkshopHUD = rift.get_node("HUD") as RiftWorkshopHUD
	rift_hud.set_objective("目标：击败双面镜（1 / 2）")
	rift_hud.set_boss_state(1, 3, 2, 3, true, false, false)
	rift_hud.set_anchor_state(false, false, 0.0, 4.0)
	rift_hud.set_boss_visible(true)
	rift_hud.set_player_hits(0, 2)
	get_tree().paused = false
	await _wait_seconds(0.35)
	await _save("hud_rift_boss.png")
	await _cleanup(rift)

	# DLC3 loom: shared 3-cell health + boss bar + 3 life hearts underneath.
	var loom: Node = await _load(
		"res://dlc/star_loom/star_loom.tscn", false, true
	)
	loom.set_process(false)
	loom.set_physics_process(false)
	var loom_hud: LoomHUD = loom.get_node("HUD") as LoomHUD
	loom_hud.set_objective("目标：异相攻击暴露的核心")
	loom_hud.set_boss_state(2, 3, 1, 1, 3, true, 1, 3, 2, 3)
	loom_hud.set_boss_visible(true)
	get_tree().paused = false
	await _wait_seconds(0.35)
	await _save("hud_loom_boss.png")
	await _cleanup(loom)
