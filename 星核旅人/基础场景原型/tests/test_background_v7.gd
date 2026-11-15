extends Node

## Focused acceptance checks for the approved V7 static background asset and
## its retained-but-hidden reference node in level 01. The visible background
## moved to the DS03 component; this test keeps the V7 asset/hash/old-layer
## checks and verifies the comparison node is hidden, not re-displayed.
##
## Log prefix is DS03-specific so the previous V7-only evidence is not
## overwritten by this updated expectation.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const BACKGROUND_PATH: String = "res://assets/backgrounds/cloud_ruins_v7.png"
const MANIFEST_PATH: String = "res://assets/backgrounds/source_manifest.json"
const LOG_PATH: String = "res://tests/logs/ds03_v7_reference_test.log"
const APPROVED_SOURCE_SHA256: String = "2d65a27d432ce60d8562c71cf754049d49a106d08e63348d78cb08f4c8387aae"
const APPROVED_RUNTIME_SHA256: String = "0c81488d74eb87b0219ea3ead2aa31f074c1a371ab9a7aba0984b67a4a0f9092"

const HIDDEN_BACKGROUND_LAYERS: Array[String] = ["Sky", "FarRuins", "NearRuins", "Mist"]
const HIDDEN_WORLD_CLOUDS: Array[String] = ["PitCloudBack", "PitCloudFront", "PitCloudGlow"]

var _level: Level01
var _v7: TextureRect
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - V7 background acceptance")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	_test_exported_asset()
	await _test_level_background()
	await _test_runtime_stability_and_reload()
	_finish()


func _test_exported_asset() -> void:
	_section("EXPORTED PNG / MANIFEST / IMPORT")
	_check(FileAccess.file_exists(BACKGROUND_PATH), "runtime background exists")
	_check(FileAccess.file_exists(MANIFEST_PATH), "source manifest exists")
	_check(_sha256(BACKGROUND_PATH) == APPROVED_RUNTIME_SHA256, "runtime PNG matches the approved V7 export hash", _sha256(BACKGROUND_PATH))

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(parsed is Dictionary, "manifest parses as JSON")
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed as Dictionary
	_check(String(data.get("version", "")) == "v7", "manifest records the approved V7 revision", String(data.get("version", "")))
	_check(String(data.get("source_sha256", "")) == APPROVED_SOURCE_SHA256, "manifest records the approved source hash", String(data.get("source_sha256", "")))
	_check(String(data.get("runtime_sha256", "")) == APPROVED_RUNTIME_SHA256, "manifest records the approved runtime hash", String(data.get("runtime_sha256", "")))
	_check(_int_array_equal(data.get("source_size", []), [1280, 720]), "manifest records the 1280x720 2x source", str(data.get("source_size", [])))
	_check(_int_array_equal(data.get("runtime_size", []), [640, 360]), "manifest records the 640x360 logical runtime image", str(data.get("runtime_size", [])))
	var verification: Dictionary = data.get("verification", {}) as Dictionary
	_check(bool(verification.get("source_2x2_blocks_identical", false)), "manifest records identical source 2x2 blocks")
	_check(int(verification.get("source_2x2_mismatch_channel_samples", -1)) == 0, "manifest records zero 2x2 mismatch samples")
	_check(bool(verification.get("runtime_nearest_2x_equals_source", false)), "manifest records NEAREST 2x round-trip equals source")

	var texture: Texture2D = load(BACKGROUND_PATH) as Texture2D
	_check(texture != null, "background texture imports")
	if texture == null:
		return
	_check(texture.resource_path == BACKGROUND_PATH, "imported texture keeps the approved asset path", texture.resource_path)
	_check(texture.get_width() == 640 and texture.get_height() == 360, "imported texture is 640x360", "%dx%d" % [texture.get_width(), texture.get_height()])

	var texture_image: Image = texture.get_image()
	var file_image: Image = Image.load_from_file(ProjectSettings.globalize_path(BACKGROUND_PATH))
	_check(texture_image != null and not texture_image.is_empty(), "imported texture exposes its pixels")
	_check(file_image != null and not file_image.is_empty(), "runtime PNG decodes outside import")
	if texture_image == null or file_image == null:
		return
	_check(texture_image.get_width() == 640 and texture_image.get_height() == 360, "imported pixel buffer is not resized", "%dx%d" % [texture_image.get_width(), texture_image.get_height()])
	var imported_rgba: Image = texture_image.duplicate() as Image
	imported_rgba.convert(Image.FORMAT_RGBA8)
	var file_rgba: Image = file_image.duplicate() as Image
	file_rgba.convert(Image.FORMAT_RGBA8)
	_check(imported_rgba.get_data() == file_rgba.get_data(), "imported pixels are byte-identical to the exported PNG")
	_check(_image_has_opaque_alpha(imported_rgba), "runtime image is a complete opaque frame")


func _test_level_background() -> void:
	_section("LEVEL 01 BACKGROUND WIRING / OLD OVERLAYS HIDDEN")
	await _new_level()
	_check(_level != null, "level scene instantiates")
	if _level == null:
		return
	var background: CanvasLayer = _level.get_node_or_null("Background") as CanvasLayer
	_check(background != null and background.layer == -10, "Background CanvasLayer remains at layer -10")
	if background == null:
		return

	_v7 = background.get_node_or_null("CloudRuinsV7") as TextureRect
	_check(_v7 != null, "the real editor-visible CloudRuinsV7 TextureRect is present")
	if _v7 == null:
		return
	_check(_v7.get_parent() == background, "CloudRuinsV7 is a child of Background")
	_check(not _v7.visible and not _v7.is_visible_in_tree(), "CloudRuinsV7 is retained but hidden for comparison")
	_check(_v7.position == Vector2.ZERO and _v7.size == Vector2(640.0, 360.0), "CloudRuinsV7 fills the 640x360 screen frame", "%s %s" % [str(_v7.position), str(_v7.size)])
	_check(_v7.offset_left == 0.0 and _v7.offset_top == 0.0 and _v7.offset_right == 640.0 and _v7.offset_bottom == 360.0, "CloudRuinsV7 offsets are authored in the scene")
	_check(_v7.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "CloudRuinsV7 uses Nearest filtering")
	_check(_v7.mouse_filter == Control.MOUSE_FILTER_IGNORE, "CloudRuinsV7 ignores the mouse")
	_check(_v7.modulate == Color(1.0, 1.0, 1.0, 1.0), "CloudRuinsV7 uses white modulate", str(_v7.modulate))
	_check(_v7.expand_mode == TextureRect.EXPAND_IGNORE_SIZE and _v7.stretch_mode == TextureRect.STRETCH_SCALE, "CloudRuinsV7 keeps the authored 640x360 stretch mode")
	_check(_v7.get_script() == null and _v7.get_child_count() == 0, "CloudRuinsV7 is a plain scene TextureRect, not runtime-generated")
	_check(_v7.texture != null and _v7.texture.resource_path == BACKGROUND_PATH, "CloudRuinsV7 references the approved V7 PNG", _v7.texture.resource_path if _v7.texture != null else "missing")
	_check(_v7.texture.get_width() == 640 and _v7.texture.get_height() == 360, "CloudRuinsV7 texture is exactly 640x360")

	for layer_name: String in HIDDEN_BACKGROUND_LAYERS:
		var layer: TextureRect = background.get_node_or_null(layer_name) as TextureRect
		_check(layer != null, "old background layer is retained: " + layer_name)
		if layer == null:
			continue
		_check(not layer.visible and not layer.is_visible_in_tree(), "old background layer is hidden: " + layer_name)
		_check(layer.texture != null, "old background layer keeps its texture: " + layer_name)
	_check(_sky_gradient_retained(background.get_node_or_null("Sky") as TextureRect), "old sky gradient resource is retained")
	_check(_texture_retained(background.get_node_or_null("FarRuins") as TextureRect, "res://assets/map/background2.png"), "FarRuins keeps background2.png")
	_check(_texture_retained(background.get_node_or_null("NearRuins") as TextureRect, "res://assets/map/background4.png"), "NearRuins keeps background4.png")
	var far: TextureRect = background.get_node_or_null("FarRuins") as TextureRect
	var near: TextureRect = background.get_node_or_null("NearRuins") as TextureRect
	var mist: TextureRect = background.get_node_or_null("Mist") as TextureRect
	_check(far != null and far.offset_top == 88.0 and far.offset_right == 640.0 and far.offset_bottom == 360.0, "FarRuins authored geometry is preserved")
	_check(far != null and far.modulate.is_equal_approx(Color(0.38, 0.57, 0.58, 0.44)), "FarRuins authored tint is preserved")
	_check(near != null and near.offset_left == -8.0 and near.offset_top == 158.0 and near.offset_right == 648.0 and near.offset_bottom == 360.0, "NearRuins authored geometry is preserved")
	_check(near != null and near.modulate.is_equal_approx(Color(0.18, 0.34, 0.36, 0.42)), "NearRuins authored tint is preserved")
	_check(mist != null and mist.offset_top == 208.0 and mist.offset_bottom == 360.0, "Mist authored geometry is preserved")

	var visible_background_children: Array[Node] = []
	for child: Node in background.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			visible_background_children.append(child)
	var ds03: Node = background.get_node_or_null("CloudRuinsDS03")
	_check(ds03 != null and ds03.is_visible_in_tree(), "CloudRuinsDS03 is the visible comparison successor")
	_check(visible_background_children.size() == 1 and visible_background_children[0] == ds03, "CloudRuinsDS03 is the only visible Background child", str(visible_background_children))

	for cloud_name: String in HIDDEN_WORLD_CLOUDS:
		var cloud: Polygon2D = _level.get_node_or_null("World/" + cloud_name) as Polygon2D
		_check(cloud != null, "old pit cloud placeholder is retained: " + cloud_name)
		if cloud == null:
			continue
		_check(not cloud.visible and not cloud.is_visible_in_tree(), "old pit cloud placeholder is hidden: " + cloud_name)
		_check(cloud.polygon.size() > 0 and cloud.color.a > 0.0, "old pit cloud placeholder keeps its authored shape/color: " + cloud_name)

	var camera: Camera2D = _level.get_camera()
	_check(camera != null and camera.limit_right == 1952 and camera.limit_bottom == 360, "1952px camera/world framing is unchanged")
	var decor_root: Node = _level.get_node_or_null("World/Decorations")
	_check(decor_root != null and decor_root.get_child_count() == 10, "existing decoration layout remains in the scene", str(decor_root.get_child_count() if decor_root != null else "missing"))
	var exit_node: Node2D = _level.get_node_or_null("World/Exit") as Node2D
	_check(exit_node != null and exit_node.position == Vector2(1840.0, 300.0), "existing exit placement is unchanged")


func _test_runtime_stability_and_reload() -> void:
	_section("AUTHORED CONFIG SURVIVES FRAMES / SCENE RE-ENTRY")
	if _v7 == null:
		_check(false, "runtime stability skipped because CloudRuinsV7 is missing")
		return
	var texture_path: String = _v7.texture.resource_path if _v7.texture != null else ""
	var authored_size: Vector2 = _v7.size
	for _index: int in range(8):
		await get_tree().process_frame
	_check(_v7.size == authored_size and _v7.position == Vector2.ZERO, "CloudRuinsV7 geometry is not rebuilt while running")
	_check(_v7.texture != null and _v7.texture.resource_path == texture_path, "CloudRuinsV7 texture is not replaced while running")
	_check(_v7.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and _v7.modulate == Color.WHITE, "CloudRuinsV7 filtering/modulate survive runtime frames")

	await _new_level()
	var background: CanvasLayer = _level.get_node_or_null("Background") as CanvasLayer
	var reloaded: TextureRect = background.get_node_or_null("CloudRuinsV7") as TextureRect if background != null else null
	_check(reloaded != null, "CloudRuinsV7 is present after scene re-entry")
	if reloaded == null:
		return
	_check(reloaded != _v7, "scene re-entry uses a fresh authored node")
	_check(not reloaded.visible and reloaded.size == Vector2(640.0, 360.0), "re-entered V7 reference stays hidden at the authored size")
	_check(reloaded.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and reloaded.mouse_filter == Control.MOUSE_FILTER_IGNORE, "re-entered background keeps filtering/mouse settings")
	_check(reloaded.texture != null and reloaded.texture.resource_path == BACKGROUND_PATH, "re-entered background keeps the approved texture")
	var ds03_reload: Node = background.get_node_or_null("CloudRuinsDS03")
	_check(ds03_reload != null and ds03_reload.is_visible_in_tree(), "scene re-entry keeps the DS03 background visible")
	var duplicates: int = 0
	for child: Node in background.get_children():
		if child.name == "CloudRuinsV7":
			duplicates += 1
	_check(duplicates == 1, "scene re-entry does not duplicate the background node", str(duplicates))
	_v7 = reloaded


func _sky_gradient_retained(sky: TextureRect) -> bool:
	if sky == null:
		return false
	var gradient_texture: GradientTexture2D = sky.texture as GradientTexture2D
	return gradient_texture != null and gradient_texture.gradient != null and gradient_texture.gradient.colors.size() == 4


func _texture_retained(rect: TextureRect, path: String) -> bool:
	return rect != null and rect.texture != null and rect.texture.resource_path == path


func _image_has_opaque_alpha(image: Image) -> bool:
	if image.get_format() != Image.FORMAT_RGBA8:
		return false
	var data: PackedByteArray = image.get_data()
	for index: int in range(3, data.size(), 4):
		if data[index] != 255:
			return false
	return true


func _new_level() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
		_level = null
		_v7 = null
		await get_tree().process_frame
		await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _physics(6)


func _physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _int_array_equal(value: Variant, expected: Array) -> bool:
	if not value is Array:
		return false
	var actual: Array = value as Array
	if actual.size() != expected.size():
		return false
	for index: int in range(actual.size()):
		if int(actual[index]) != int(expected[index]):
			return false
	return true


func _sha256(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode().to_lower()


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
