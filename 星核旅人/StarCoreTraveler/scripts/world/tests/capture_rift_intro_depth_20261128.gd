extends Node

## Film check for the DLC2 indoor-depth pass.  The opening film's final
## pull-back uses the real entry room, so this captures that frame with the new
## depth/atmosphere on and off.  The mirror-hall main shot is unchanged.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://screenshots/depth_indoor_20261128"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _run()
	print("RIFT_INTRO_DEPTH_CAPTURE done dir=%s" % OUT_DIR)
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
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if packed == null:
		printerr("RIFT_INTRO_DEPTH_CAPTURE missing scene")
		return
	var rift: RiftWorkshop = packed.instantiate() as RiftWorkshop
	rift.show_intro_guide = false
	rift.show_intro_cinematic = true
	get_tree().root.add_child(rift)
	get_tree().current_scene = rift
	await _wait_process(6)
	var cine: RiftIntroCinematic = rift.get_intro_cinematic()
	if cine == null:
		printerr("RIFT_INTRO_DEPTH_CAPTURE missing film")
		rift.queue_free()
		return
	var depth: Node = rift.get_node_or_null("Background/DepthOverlay")
	var atmosphere: Node = rift.get_node_or_null("Atmosphere")
	cine.set_time_for_capture(4.42)
	await _wait_process(2)
	await _save("rift_intro_4.42.png")
	cine.finish_capture()
	await get_tree().create_timer(0.08).timeout
	if depth != null:
		print("RIFT_HANDOFF mid strength=%.2f target=%.2f" % [
			float(depth.call("get_strength")),
			float(depth.call("get_target_strength"))
		])
	await _save("rift_handoff_mid.png")
	await get_tree().create_timer(0.45).timeout
	if depth != null:
		print("RIFT_HANDOFF after strength=%.2f target=%.2f" % [
			float(depth.call("get_strength")),
			float(depth.call("get_target_strength"))
		])
	if atmosphere != null:
		print("RIFT_HANDOFF atmosphere=%.2f" % atmosphere.modulate.a)
	await _save("rift_handoff_after.png")
	await _wait_process(12)
	rift.queue_free()
	await _wait_process(12)
	get_tree().current_scene = null
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(6)
