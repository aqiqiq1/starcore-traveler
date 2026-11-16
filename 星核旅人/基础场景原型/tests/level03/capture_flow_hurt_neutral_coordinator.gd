extends SceneTree

## Coordinator read-only rendered A/B. It never changes files or original art.
const DIR: String = "res://screenshots/flow_hurt_audio_20261116/neutral_coordinator_verified"

func _initialize() -> void:
	call_deferred("_run")

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/level_03.tscn")
	var level: Node = scene.instantiate()
	root.add_child(level)
	for _i: int in range(24):
		await physics_frame
	_freeze(level)
	var player: Node = level.get_player()
	var body: Sprite2D = player.get("_character_sprite") as Sprite2D
	var material: Material = body.material
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var with_shader: Image = await _image()
	body.material = null
	await process_frame
	var without_shader: Image = await _image()
	body.material = material
	var changed: int = 0
	for y: int in range(with_shader.get_height()):
		for x: int in range(with_shader.get_width()):
			if with_shader.get_pixel(x, y) != without_shader.get_pixel(x, y):
				changed += 1
	with_shader.save_png(ProjectSettings.globalize_path(DIR + "/neutral_shader.png"))
	without_shader.save_png(ProjectSettings.globalize_path(DIR + "/no_material.png"))
	print("NEUTRAL_SHADER_RENDER_DIFF pixels=%d tint=%.2f" % [changed, player.get_hurt_tint_amount()])
	level.queue_free()
	await process_frame
	quit(0 if changed == 0 else 1)
