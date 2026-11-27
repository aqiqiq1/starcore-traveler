extends Node

## 640x360 evidence shots for the 2026-11-27 star-core art pass.
## Run WITHOUT --headless so the viewport renders:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/core_art_20261127/capture_core_art.tscn
##
## The L1 shot is the real opening film at 18.85 s (star-core handoff), not a
## posed scene.  The L3 shots use the real level scene and the ordinary player
## camera; only the player position is set so the bay is framed.  DLC3 is
## captured by the existing real-gameplay capture_mechanics harness.

const OUT_DIR: String = "res://screenshots/core_art_20261127"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _capture_l1()
	await _capture_l3()
	print("CORE_ART_CAPTURE done")
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(file_name))
	print("SHOT %s size=%dx%d error=%d" % [
		file_name, image.get_width(), image.get_height(), error
	])


func _capture_l1() -> void:
	var packed: PackedScene = load("res://scenes/level_01.tscn") as PackedScene
	if packed == null:
		print("CORE_ART_CAPTURE missing level_01")
		return
	var level: Node = packed.instantiate()
	level.set("enable_start_menu", false)
	add_child(level)
	await _wait_process(6)
	var opening: Node = level.get_node_or_null("OpeningCinematic")
	if opening == null:
		print("CORE_ART_CAPTURE missing level_01 opening")
		level.queue_free()
		return
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if not bool(opening.call("is_active")):
			break
		if float(opening.call("get_elapsed")) >= 18.40:
			break
		await get_tree().process_frame
	await _save("01b_l1_core_in_flight.png")
	while Time.get_ticks_msec() < deadline:
		if not bool(opening.call("is_active")):
			break
		if float(opening.call("get_elapsed")) >= 18.85:
			break
		await get_tree().process_frame
	await _save("01_l1_handoff.png")
	level.queue_free()
	await _wait_process(12)


func _capture_l3() -> void:
	var packed: PackedScene = load("res://scenes/level_03.tscn") as PackedScene
	if packed == null:
		print("CORE_ART_CAPTURE missing level_03")
		return
	var level: Node = packed.instantiate()
	# Level03 has no intro props; Object.set is a no-op for missing names.
	level.set("show_intro_guide", false)
	level.set("show_intro_cinematic", false)
	add_child(level)
	await _wait_process(10)
	var player: Node2D = level.get_node_or_null("Player") as Node2D
	if player == null:
		print("CORE_ART_CAPTURE missing level_03 player")
		level.queue_free()
		return
	# Empty TargetBay at x=330.  Stand left of it so the 4x crop excludes the
	# player and shows the bay alone.
	await _place_player(player, Vector2(276.0, 320.0))
	await _save("02_l3_bay_empty.png")
	# Locked StartBay at x=150: the full/shared-bay state.
	await _place_player(player, Vector2(70.0, 320.0))
	await _save("02b_l3_bay_locked.png")
	level.queue_free()
	await _wait_process(12)


func _place_player(player: Node2D, position: Vector2) -> void:
	player.global_position = position
	player.set("velocity", Vector2.ZERO)
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
	await get_tree().create_timer(0.35, true).timeout
	await _wait_process(4)
