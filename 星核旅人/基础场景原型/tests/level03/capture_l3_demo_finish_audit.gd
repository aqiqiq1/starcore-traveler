extends Node

## Read-only scene audit: every CanvasItem right of x=2200 with its real
## world placement, z and texture, so nothing "old" is guessed at.
##   Godot --headless --path . res://tests/level03/capture_l3_demo_finish_audit.tscn

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")


func _ready() -> void:
	await get_tree().process_frame
	var level: Level03 = LEVEL_SCENE.instantiate() as Level03
	add_child(level)
	for _i: int in range(24):
		await get_tree().physics_frame
	_dump(level, level, 0)
	level.get_gate()
	await get_tree().process_frame
	level.queue_free()
	await get_tree().process_frame
	print("AUDIT_DONE")
	get_tree().quit(0)


func _dump(root: Node, node: Node, depth: int) -> void:
	var pad: String = "  ".repeat(depth)
	if node is CanvasItem:
		var item: CanvasItem = node as CanvasItem
		var gx: float = 0.0
		var gy: float = 0.0
		if node is Node2D:
			var n2: Node2D = node as Node2D
			gx = n2.global_position.x
			gy = n2.global_position.y
		if gx > 2200.0 or node.name.begins_with("Wall") or node.name.contains("Column"):
			var tex: String = ""
			if node is Sprite2D:
				var s: Sprite2D = node as Sprite2D
				tex = s.texture.resource_path if s.texture != null else ""
			if tex.is_empty() and not (node is Sprite2D):
				tex = ""
			print("%s%s [%s] x=%.0f y=%.0f z=%d vis=%s tex=%s" % [
				pad, node.name, node.get_class(), gx, gy, item.z_index,
				str(item.visible), tex])
	for child: Node in node.get_children():
		_dump(root, child, depth + 1)
