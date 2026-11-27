extends Node

## Film-only check for the DLC3 indoor-depth pass.  The opening cinematic uses
## the real room, so this captures one early frame and the final pull-back with
## the new window depth on and off.  It writes into the same evidence folder as
## the gameplay capture; it does not overwrite the older intro evidence.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://screenshots/depth_indoor_20261128"
const LOOM_BACK: String = "res://dlc/star_loom/assets/city_v2/city_back_960x360.png"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _run()
	print("LOOM_INTRO_DEPTH_CAPTURE done dir=%s" % OUT_DIR)
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var absolute: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(absolute.path_join(name))
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		printerr("LOOM_INTRO_DEPTH_CAPTURE missing scene")
		return
	var loom: StarLoom = packed.instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = true
	get_tree().root.add_child(loom)
	get_tree().current_scene = loom
	await _wait_process(6)
	var cine: LoomIntroCinematic = loom.get_intro_cinematic()
	if cine == null:
		printerr("LOOM_INTRO_DEPTH_CAPTURE missing film")
		loom.queue_free()
		return
	var back: Sprite2D = loom.get_node_or_null("CityBack") as Sprite2D
	var depth: Node = loom.get_node_or_null("Depth")
	var atmosphere: Node = loom.get_node_or_null("Atmosphere")
	var gate: Node = loom.get_node_or_null("MirrorRiftGate")
	var after_texture: Texture2D = back.texture if back != null else null
	var before_texture: Texture2D = load(LOOM_BACK) as Texture2D

	for entry: Array in [[1.70, "loom_intro_1.70_after.png"],
			[4.42, "loom_intro_4.42_after.png"]]:
		cine.set_time_for_capture(float(entry[0]))
		await _wait_process(2)
		await _save(String(entry[1]))

	# Same frame with the original sky windows and the far layer hidden.
	cine.set_time_for_capture(1.70)
	await _wait_process(2)
	if back != null:
		back.texture = before_texture
	if depth != null:
		depth.set("visible", false)
	await _wait_process(2)
	await _save("loom_intro_1.70_before.png")
	if back != null:
		back.texture = after_texture
	if depth != null:
		depth.set("visible", true)
	await _wait_process(2)

	cine.finish_capture()
	await get_tree().create_timer(0.08).timeout
	if depth != null:
		print("HANDOFF mid strength=%.2f target=%.2f visible=%s" % [
			float(depth.call("get_strength")),
			float(depth.call("get_target_strength")),
			str(depth.get("visible"))
		])
	await _save("loom_handoff_mid.png")
	await get_tree().create_timer(0.45).timeout
	if depth != null:
		print("HANDOFF after strength=%.2f target=%.2f visible=%s" % [
			float(depth.call("get_strength")),
			float(depth.call("get_target_strength")),
			str(depth.get("visible"))
		])
	if atmosphere != null:
		print("HANDOFF atmosphere=%.2f" % atmosphere.modulate.a)
	if gate != null:
		print("HANDOFF gate=%.2f" % float(gate.call("get_depth_strength")))
	await _save("loom_handoff_after.png")
	await _wait_process(12)
	loom.queue_free()
	await _wait_process(12)
	get_tree().current_scene = null
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(6)
