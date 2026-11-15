extends Node

## Focused acceptance checks for the static Doric-column decorations in level 01.
## These are presentation-only nodes: the test proves they have no gameplay
## component and that every visible foot rests on the authored terrain.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const ASSET_DIR: String = "res://assets/doric_columns/"
const MANIFEST_PATH: String = ASSET_DIR + "source_manifest.json"
const SOURCE_MANIFEST_SHA256: String = "9213bec591131baa75bb2a36391adcdb4c3db134b2c3c4c4be7f2b3fdac0edc1"
const DECOR_ROOT: String = "World/Decorations"
const LOG_PATH: String = "res://tests/logs/test_doric_decorations.log"

const FILES: Array[String] = [
	"doric_column_tall.png",
	"doric_column_broken.png",
	"doric_column_base.png",
	"doric_column_fallen.png",
]

var _level: Level01
var _asset_data: Dictionary = {}
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - Doric decoration acceptance")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	_test_asset_sources()
	await _test_decorations_in_level()
	await _test_static_positions_and_reload()
	_finish()


func _test_asset_sources() -> void:
	_section("SOURCE PNG / MANIFEST / IMPORT")
	_check(FileAccess.file_exists(MANIFEST_PATH), "copied source manifest exists")
	_check(_sha256(MANIFEST_PATH) == SOURCE_MANIFEST_SHA256, "copied source manifest is byte-identical to the approved manifest", _sha256(MANIFEST_PATH))

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(parsed is Dictionary, "manifest parses as JSON")
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed as Dictionary
	_check(String(data.get("version", "")) == "v5_detail", "manifest records the approved v5 detail revision", String(data.get("version", "")))
	var assets: Array = data.get("assets", []) as Array
	_check(assets.size() == 4, "manifest lists exactly four column assets", str(assets.size()))

	var manifest_by_file: Dictionary = {}
	for entry: Variant in assets:
		if entry is Dictionary:
			manifest_by_file[String((entry as Dictionary).get("file", ""))] = entry as Dictionary
	for file: String in FILES:
		_check(manifest_by_file.has(file), "manifest has an entry for " + file)
		if not manifest_by_file.has(file):
			continue
		var entry: Dictionary = manifest_by_file[file] as Dictionary
		var size: Array = entry.get("size", []) as Array
		var anchor: Array = entry.get("foot_anchor", []) as Array
		var alpha_bbox: Array = entry.get("alpha_bbox", []) as Array
		_check(size.size() == 2 and anchor.size() == 2 and alpha_bbox.size() == 4, "manifest entry has size/anchor/alpha bbox: " + file)

		var path: String = ASSET_DIR + file
		_check(FileAccess.file_exists(path), "asset copy exists: " + file)
		var actual_sha: String = _sha256(path)
		_check(actual_sha == String(entry.get("sha256", "")).to_lower(), "copied PNG bytes match manifest SHA256: " + file, actual_sha)

		var texture: Texture2D = load(path) as Texture2D
		_check(texture != null, "texture imports: " + file)
		if texture != null:
			_check(texture.get_width() == int(size[0]) and texture.get_height() == int(size[1]),
				"imported texture size matches manifest: " + file,
				"%dx%d" % [texture.get_width(), texture.get_height()])

		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(image != null and not image.is_empty(), "source PNG decodes: " + file)
		if image == null or image.is_empty():
			continue
		_check(image.get_width() == int(size[0]) and image.get_height() == int(size[1]),
			"source PNG pixel size matches manifest: " + file,
			"%dx%d" % [image.get_width(), image.get_height()])
		var bbox: Array = _alpha_bbox(image)
		_check(_int_array_equal(bbox, alpha_bbox), "alpha bbox matches manifest: " + file, str(bbox))
		_check(int(anchor[0]) == image.get_width() / 2, "foot anchor x is the canvas centre: " + file, str(anchor[0]))
		_check(int(anchor[1]) == int(bbox[3]), "foot anchor y is the alpha bottom edge: " + file, "%s / bbox bottom %d" % [str(anchor[1]), bbox[3]])
		_check(int(bbox[0]) < int(bbox[2]) and int(bbox[1]) < int(bbox[3]), "visible alpha is non-empty: " + file, str(bbox))

		var scene_path: String = _scene_path_for(file)
		var packed: PackedScene = load(scene_path) as PackedScene
		_check(packed != null, "reusable decoration scene loads: " + file)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		_check(root is Sprite2D, "decoration scene root is a Sprite2D: " + file)
		if root is Sprite2D:
			var sprite: Sprite2D = root as Sprite2D
			var expected_offset := Vector2(
				float(size[0]) * 0.5 - float(anchor[0]),
				float(size[1]) * 0.5 - float(anchor[1])
			)
			_check(sprite.centered, "decoration uses centered texture space: " + file)
			_check(sprite.offset.is_equal_approx(expected_offset), "Sprite2D offset puts the foot anchor at the origin: " + file, "%s expected %s" % [str(sprite.offset), str(expected_offset)])
			_check(sprite.scale == Vector2.ONE, "decoration scene has scale 1: " + file, str(sprite.scale))
			_check(not sprite.flip_h and not sprite.flip_v, "decoration scene has no mirroring: " + file)
			_check(sprite.texture != null and sprite.texture.resource_path == path, "decoration scene references the approved PNG: " + file)
			_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "decoration scene uses Nearest filtering: " + file)
			_check(sprite.get_script() == null and sprite.get_child_count() == 0, "decoration scene is a bare static sprite: " + file)
		root.free()
		_asset_data[file] = {
			"bbox": bbox,
			"anchor": anchor,
			"size": size,
		}


func _test_decorations_in_level() -> void:
	_section("LEVEL PLACEMENT / GROUNDING / NO GAMEPLAY")
	var expected: Array = [
		{"name": "DoricTallEntry", "file": "doric_column_tall.png", "position": Vector2(150.0, 300.0)},
		{"name": "DoricBaseMidway", "file": "doric_column_base.png", "position": Vector2(390.0, 300.0)},
		{"name": "DoricBrokenMidway", "file": "doric_column_broken.png", "position": Vector2(435.0, 300.0)},
		{"name": "DoricTallRoadside", "file": "doric_column_tall.png", "position": Vector2(575.0, 300.0)},
		{"name": "DoricFallenRoadside", "file": "doric_column_fallen.png", "position": Vector2(608.0, 300.0)},
		{"name": "DoricBaseHighTerrace", "file": "doric_column_base.png", "position": Vector2(955.0, 220.0)},
		{"name": "DoricFallenHighTerrace", "file": "doric_column_fallen.png", "position": Vector2(1000.0, 220.0)},
		{"name": "DoricTallFarBank", "file": "doric_column_tall.png", "position": Vector2(1600.0, 300.0)},
		{"name": "DoricBrokenFarBank", "file": "doric_column_broken.png", "position": Vector2(1650.0, 300.0)},
		{"name": "DoricFallenFarBank", "file": "doric_column_fallen.png", "position": Vector2(1682.0, 300.0)},
	]
	await _new_level()
	var decor_root: Node2D = _level.get_node_or_null(DECOR_ROOT) as Node2D
	_check(decor_root != null, "World/Decorations branch exists")
	if decor_root == null:
		return
	var children: Array[Node] = decor_root.get_children()
	_check(children.size() == 10, "level has ten explicit decoration instances", str(children.size()))
	_check(children.size() >= 8 and children.size() <= 10, "decoration count stays in the approved 8-10 range", str(children.size()))

	var seen_positions: Dictionary = {}
	var high_terrace_count: int = 0
	for index: int in range(mini(children.size(), expected.size())):
		var item: Dictionary = expected[index] as Dictionary
		var node: Node = children[index]
		var sprite: Sprite2D = node as Sprite2D
		_check(sprite != null, "decoration instance is a Sprite2D: " + String(item["name"]), node.get_class())
		if sprite == null:
			continue
		_check(sprite.name == StringName(item["name"]), "decoration keeps its authored name", "%s / %s" % [sprite.name, item["name"]])
		_check(sprite.owner == _level, "decoration is owned by the level scene, not runtime-only: " + String(item["name"]))
		_check(sprite.get_script() == null, "decoration has no script: " + String(item["name"]))
		_check(sprite.get_child_count() == 0, "decoration has no gameplay children: " + String(item["name"]))
		_check(sprite.z_index == -1, "decoration draws behind player and mechanisms: " + String(item["name"]), str(sprite.z_index))
		_check(sprite.visible and sprite.is_visible_in_tree(), "decoration is visible in the editor and runtime: " + String(item["name"]))
		_check(sprite.scale == Vector2.ONE, "placed decoration has scale 1: " + String(item["name"]), str(sprite.scale))
		_check(not sprite.flip_h and not sprite.flip_v, "placed decoration is not mirrored: " + String(item["name"]))
		_check(sprite.rotation == 0.0 and sprite.skew == 0.0, "placed decoration has no rotation/skew: " + String(item["name"]))
		_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "placed decoration keeps Nearest filtering: " + String(item["name"]))
		_check(sprite.modulate == Color.WHITE and sprite.self_modulate == Color.WHITE, "placed decoration is not tinted: " + String(item["name"]))
		_check(sprite.texture != null, "decoration texture is visible: " + String(item["name"]))
		if sprite.texture != null:
			_check(sprite.texture.resource_path == ASSET_DIR + String(item["file"]), "decoration uses the expected PNG: " + String(item["name"]), sprite.texture.resource_path)
		_check(sprite.position.is_equal_approx(item["position"] as Vector2), "authored position is stored in the scene: " + String(item["name"]), str(sprite.position))
		seen_positions[sprite.position] = true

		_check(_no_gameplay_nodes(sprite), "decoration subtree has no collider/area/force node: " + String(item["name"]))
		_check(sprite.scene_file_path.begins_with("res://scenes/decorations/doric_column_"), "decoration is an instance of a reusable scene: " + String(item["name"]), sprite.scene_file_path)

		var file: String = String(item["file"])
		if _asset_data.has(file) and sprite.texture != null:
			var data: Dictionary = _asset_data[file] as Dictionary
			var expected_offset := Vector2(
				float((data["size"] as Array)[0]) * 0.5 - float((data["anchor"] as Array)[0]),
				float((data["size"] as Array)[1]) * 0.5 - float((data["anchor"] as Array)[1])
			)
			_check(sprite.offset.is_equal_approx(expected_offset), "placed Sprite2D offset still uses foot anchor: " + String(item["name"]), str(sprite.offset))
			var surface_y: float = _surface_y_at(sprite.global_position.x)
			_check(is_finite(surface_y), "decoration x lies over authored ground: " + String(item["name"]), "x=%.1f" % sprite.global_position.x)
			if is_finite(surface_y):
				var visible_bottom: float = _visible_foot_y(sprite, (data["bbox"] as Array)[3])
				_check(absf(visible_bottom - surface_y) < 0.01, "visible foot rests on the terrain surface: " + String(item["name"]), "foot=%.2f surface=%.2f" % [visible_bottom, surface_y])
			var zone_problem: String = _protected_zone_overlap(sprite, data["bbox"] as Array)
			_check(zone_problem.is_empty(), "decoration keeps interaction/jump zones clear: " + String(item["name"]), zone_problem)
			if sprite.global_position.y < 260.0:
				high_terrace_count += 1
				_check(file in ["doric_column_base.png", "doric_column_fallen.png"], "high terrace uses only low remnants: " + String(item["name"]), file)
			var mid_point := Vector2(sprite.global_position.x, (_visible_foot_y(sprite, (data["bbox"] as Array)[3]) + _visible_top_y(sprite, (data["bbox"] as Array)[1])) * 0.5)
			var point_query := PhysicsPointQueryParameters2D.new()
			point_query.position = mid_point
			point_query.collision_mask = 0xFFFFFFFF
			point_query.collide_with_bodies = true
			point_query.collide_with_areas = true
			var hits: Array[Dictionary] = _level.get_world_2d().direct_space_state.intersect_point(point_query, 8)
			_check(hits.is_empty(), "decoration adds no physics shape or ray occluder: " + String(item["name"]), str(hits.size()))

	_check(seen_positions.size() == children.size(), "all decoration positions are explicit and distinct", str(seen_positions.size()))
	_check(high_terrace_count == 2, "high platform has only two low remnants", str(high_terrace_count))


func _test_static_positions_and_reload() -> void:
	_section("STATIC EDIT / RUN / RELOAD")
	await _new_level()
	var decor_root: Node2D = _level.get_node_or_null(DECOR_ROOT) as Node2D
	_check(decor_root != null, "decorations available for edit/reload check")
	if decor_root == null:
		return
	var children: Array[Node] = decor_root.get_children()
	_check(children.size() == 10, "load A owns ten decorations", str(children.size()))
	if children.is_empty():
		return
	var edited: Sprite2D = children[0] as Sprite2D
	var authored: Vector2 = edited.position
	edited.position += Vector2(19.0, 0.0)
	await _physics(30)
	_check(edited.position.is_equal_approx(authored + Vector2(19.0, 0.0)), "runtime never re-lays-out an edited decoration", str(edited.position))
	_level.queue_free()
	_level = null
	await get_tree().process_frame
	await get_tree().process_frame
	await _new_level()
	decor_root = _level.get_node_or_null(DECOR_ROOT) as Node2D
	_check(decor_root != null and decor_root.get_child_count() == 10, "reloaded scene owns ten decorations without ghosts", str(decor_root.get_child_count() if decor_root != null else -1))
	if decor_root != null and decor_root.get_child_count() > 0:
		var reloaded: Sprite2D = decor_root.get_child(0) as Sprite2D
		_check(reloaded != edited, "reload creates fresh decoration nodes")
		_check(reloaded.position.is_equal_approx(authored), "reload restores the authored scene position", str(reloaded.position))
		var total_decor_roots: int = 0
		for node: Node in get_tree().root.find_children("Decorations", "Node2D", true, false):
			total_decor_roots += 1
		_check(total_decor_roots == 1, "scene reload leaves exactly one World/Decorations branch", str(total_decor_roots))


func _no_gameplay_nodes(root: Node) -> bool:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionObject2D or node is Area2D or node is CollisionShape2D or node is CollisionPolygon2D:
			return false
		if node is RuneStoneField:
			return false
		if node.get_script() != null:
			return false
		for child: Node in node.get_children():
			stack.append(child)
	return true


func _protected_zone_overlap(sprite: Sprite2D, bbox: Array) -> String:
	var rect: Rect2 = _visible_rect(sprite, bbox)
	var zones: Array = [
		{"name": "pit", "rect": Rect2(1200.0, 220.0, 256.0, 140.0)},
		{"name": "pit launch", "rect": Rect2(1148.0, 150.0, 52.0, 70.0)},
		{"name": "far-bank landing buffer", "rect": Rect2(1456.0, 240.0, 124.0, 120.0)},
		{"name": "exit", "rect": Rect2(1800.0, 200.0, 80.0, 160.0)},
		{"name": "checkpoint", "rect": Rect2(1080.0, 130.0, 80.0, 90.0)},
		{"name": "narrative stele", "rect": Rect2(186.0, 196.0, 128.0, 104.0)},
		{"name": "mechanism stele", "rect": Rect2(671.0, 204.0, 128.0, 96.0)},
		{"name": "high rune stone", "rect": Rect2(824.0, 103.0, 80.0, 117.0)},
		{"name": "pit rune stone", "rect": Rect2(1320.0, 98.0, 80.0, 122.0)},
	]
	for zone: Dictionary in zones:
		if rect.intersects(zone["rect"] as Rect2):
			return "%s overlaps %s" % [str(rect), String(zone["name"])]
	return ""


func _visible_rect(sprite: Sprite2D, bbox: Array) -> Rect2:
	var size: Vector2 = sprite.texture.get_size()
	var top_left: Vector2 = sprite.offset
	if sprite.centered:
		top_left -= size * 0.5
	var p1: Vector2 = sprite.to_global(top_left + Vector2(float(bbox[0]), float(bbox[1])))
	var p2: Vector2 = sprite.to_global(top_left + Vector2(float(bbox[2]), float(bbox[3])))
	return Rect2(p1, p2 - p1)


func _visible_foot_y(sprite: Sprite2D, bbox_bottom: int) -> float:
	var size: Vector2 = sprite.texture.get_size()
	var top_left: Vector2 = sprite.offset
	if sprite.centered:
		top_left -= size * 0.5
	return sprite.to_global(top_left + Vector2(0.0, float(bbox_bottom))).y


func _visible_top_y(sprite: Sprite2D, bbox_top: int) -> float:
	var size: Vector2 = sprite.texture.get_size()
	var top_left: Vector2 = sprite.offset
	if sprite.centered:
		top_left -= size * 0.5
	return sprite.to_global(top_left + Vector2(0.0, float(bbox_top))).y


func _surface_y_at(world_x: float) -> float:
	for path: String in ["World/StartGround", "World/HighPlatform", "World/FarBank"]:
		var block: LevelTerrainBlock = _level.get_node_or_null(path) as LevelTerrainBlock
		if block == null:
			continue
		var left: float = block.global_position.x
		var right: float = left + block.block_size.x
		if world_x >= left and world_x < right:
			return block.global_position.y
	return NAN


func _scene_path_for(file: String) -> String:
	match file:
		"doric_column_tall.png":
			return "res://scenes/decorations/doric_column_tall.tscn"
		"doric_column_broken.png":
			return "res://scenes/decorations/doric_column_broken.tscn"
		"doric_column_base.png":
			return "res://scenes/decorations/doric_column_base.tscn"
		"doric_column_fallen.png":
			return "res://scenes/decorations/doric_column_fallen.tscn"
	return ""


func _alpha_bbox(image: Image) -> Array:
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = 0
	var max_y: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x + 1)
				max_y = maxi(max_y, y + 1)
	return [min_x, min_y, max_x, max_y]


func _int_array_equal(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if int(left[index]) != int(right[index]):
			return false
	return true


func _sha256(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode().to_lower()


func _new_level() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
		_level = null
		await get_tree().process_frame
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _physics(6)


func _physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _section(title: String) -> void:
	_log("")
	_log("-- %s --" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s  (%s)" % [label, detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s  (%s)" % [label, detail])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count])
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log_lines) + "\n")
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
