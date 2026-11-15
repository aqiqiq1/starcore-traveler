extends Node

## Independent acceptance test for the star-core display component and its
## standalone preview. It never preloads a star-core PNG, so it runs both before
## and after the parallel art pass has produced the three source files.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_star_core_visual.tscn

const CORE_SCENE: PackedScene = preload("res://scenes/star_core_visual.tscn")
const PREVIEW_SCENE: PackedScene = preload("res://tools/preview_star_core.tscn")
const EXPECTED_PATHS: Array[String] = [
	"res://assets/star_core/star_core_locked.png",
	"res://assets/star_core/star_core_positive.png",
	"res://assets/star_core/star_core_negative.png",
]
const EXPECTED_BADGES: Array[StringName] = [&"lock", &"plus", &"minus"]

var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_log("Star Core Traveler - independent star-core visual test")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	_test_project_config()
	await _test_component_contract()
	await _test_state_updates()
	await _test_preview_layout()
	_finish()


func _test_project_config() -> void:
	_section("PROJECT AND ASSET CONFIG")
	_check(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
		"project logic viewport is 640x360"
	)
	_check(
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"project default texture filter is nearest"
	)


func _test_component_contract() -> void:
	_section("COMPONENT CONTRACT")
	var core: StarCoreVisual = CORE_SCENE.instantiate() as StarCoreVisual
	add_child(core)
	await get_tree().process_frame

	_check(core != null, "component scene instantiates as StarCoreVisual")
	if core == null:
		return
	_check(core is Node2D, "component root is Node2D")
	_check(core.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "root uses nearest filtering")
	_check(core.get_child_count() == 1, "component owns only the Gem sprite child (no logic nodes)")
	_check(_count_physics_nodes(core) == 0, "component has no collision or area nodes")

	var script: Script = core.get_script()
	_check(script != null and script.is_tool(), "component script is @tool (visible in editor)")
	_check(
		StarCoreVisual.CoreState.LOCKED == 0
		and StarCoreVisual.CoreState.POSITIVE == 1
		and StarCoreVisual.CoreState.NEGATIVE == 2,
		"state enum is LOCKED/POSITIVE/NEGATIVE in order"
	)
	_check(core.state == StarCoreVisual.CoreState.LOCKED, "default state is LOCKED")

	var state_hint: String = ""
	var state_hint_mode: int = -1
	var state_exported: bool = false
	for property: Dictionary in core.get_property_list():
		if property.name == "state":
			state_exported = true
			state_hint_mode = int(property.hint)
			state_hint = String(property.hint_string)
	var state_hint_upper: String = state_hint.to_upper()
	_check(state_exported, "state is exposed to the inspector")
	_check(state_hint_mode == PROPERTY_HINT_ENUM, "state is an enum export")
	_check(
		state_hint_upper.contains("LOCKED")
		and state_hint_upper.contains("POSITIVE")
		and state_hint_upper.contains("NEGATIVE"),
		"state enum labels are present",
		state_hint
	)

	var sprite: Sprite2D = core.get_node_or_null("Gem") as Sprite2D
	_check(sprite != null, "Gem sprite exists")
	if sprite != null:
		_check(sprite.centered, "Gem sprite is centered on the component origin")
		_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Gem sprite uses nearest filtering")
		_check(sprite.scale == Vector2.ONE, "Gem sprite is displayed 1:1")
		_check(not sprite.flip_h and not sprite.flip_v, "Gem sprite is not mirrored")
		_check(sprite.modulate == Color.WHITE, "Gem sprite is not tinted or recoloured")

	_check(core.get_source_size() == Vector2i(16, 16), "declared source size is 16x16")
	var gem_rect: Rect2 = core.get_gem_rect()
	var badge_rect: Rect2 = core.get_badge_rect()
	_check(gem_rect == Rect2(-8.0, -8.0, 16.0, 16.0), "gem occupies the 16x16 rect around origin")
	_check(not gem_rect.intersects(badge_rect), "state badge never overlaps the gem body")
	_check(
		badge_rect.position.x > gem_rect.end.x and badge_rect.position.y > gem_rect.end.y,
		"state badge sits outside the gem's bottom-right corner"
	)

	_check(core.get_state_texture_path() == EXPECTED_PATHS[0], "LOCKED points at the locked PNG")
	_check(core.get_badge_kind() == EXPECTED_BADGES[0], "LOCKED uses the lock badge")
	_check(core.show_state_badge and core.show_missing_placeholder, "badge and missing placeholder default on")
	_check(
		StarCoreVisual.load_texture_safely("res://assets/star_core/__missing_for_test__.png") == null,
		"safe loader returns null for a missing path without throwing"
	)

	core.queue_free()
	await get_tree().process_frame


func _test_state_updates() -> void:
	_section("STATE SWITCHING AND ART FALLBACK")
	var core: StarCoreVisual = CORE_SCENE.instantiate() as StarCoreVisual
	add_child(core)
	await get_tree().process_frame

	var sprite: Sprite2D = core.get_node_or_null("Gem") as Sprite2D
	var missing_paths: Array[String] = []
	var ready_paths: Array[String] = []
	var all_ready: bool = true

	for index: int in range(3):
		_apply_state(core, index)
		var expected_path: String = EXPECTED_PATHS[index]
		_check(int(core.state) == index, "state %d applies through the exported property" % index)
		_check(core.get_state_texture_path() == expected_path, "state %d resolves the expected path" % index)
		_check(core.get_state_texture_path(index) == expected_path, "path lookup by state %d is stable" % index)
		_check(core.get_badge_kind() == EXPECTED_BADGES[index], "state %d selects the expected badge" % index)
		_check(sprite != null and sprite.modulate == Color.WHITE, "state %d keeps source colours untinted" % index)
		_check(
			sprite != null and not sprite.flip_h and not sprite.flip_v,
			"state %d badge and sprite remain unmirrored" % index
		)

		if core.has_art():
			all_ready = all_ready and true
			ready_paths.append(expected_path)
			var texture: Texture2D = core.get_art_texture()
			_check(texture != null, "state %d loaded a Texture2D" % index)
			_check(Vector2i(texture.get_size()) == Vector2i(16, 16), "state %d texture is 16x16" % index)
			var image: Image = texture.get_image()
			_check(
				image != null and image.detect_alpha() != Image.ALPHA_NONE,
				"state %d texture keeps an alpha channel" % index
			)
			_check(sprite.texture == texture, "state %d auto-updated the Gem sprite" % index)
		else:
			all_ready = false
			missing_paths.append(expected_path)
			_check(core.is_art_missing(), "state %d reports missing art" % index)
			_check(core.get_missing_texture_path() == expected_path, "state %d reports the missing path" % index)
			_check(sprite.texture == null, "state %d leaves the sprite empty instead of faking art" % index)

	_check(
		_check_ready_assets_consistent(ready_paths),
		"every reported-ready PNG resolves in ResourceLoader"
	)

	_apply_state(core, 1)
	core.set_core_state(StarCoreVisual.CoreState.NEGATIVE)
	_check(core.state == StarCoreVisual.CoreState.NEGATIVE, "set_core_state switches state")
	core.refresh()
	_check(int(core.state) == 2, "refresh keeps the current state")

	if all_ready:
		_log("[INFO] all 3 star-core PNGs are present and 16x16")
	else:
		for path: String in missing_paths:
			_skip("PNG not ready at test time; loaded-art branch deferred: %s" % path)

	core.queue_free()
	await get_tree().process_frame


func _test_preview_layout() -> void:
	_section("STANDALONE PREVIEW")
	var preview: Control = PREVIEW_SCENE.instantiate() as Control
	add_child(preview)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(preview != null, "preview scene instantiates")
	if preview == null:
		return
	_check(preview.size == Vector2(640.0, 360.0), "preview canvas is 640x360", str(preview.size))
	_check(_count_physics_nodes(preview) == 0, "preview contains no physics nodes")

	var cores: Array[StarCoreVisual] = []
	_collect_cores(preview, cores)
	_check(cores.size() == 6, "preview shows three states twice (1x and 4x)", str(cores.size()))

	var state_counts: Array[int] = [0, 0, 0]
	var pair_keys: Dictionary = {}
	var all_positive_scale: bool = true
	for core: StarCoreVisual in cores:
		state_counts[int(core.state)] += 1
		pair_keys["%d@%.0f" % [int(core.state), core.scale.x]] = true
		all_positive_scale = all_positive_scale and core.scale.x > 0.0 and core.scale.y > 0.0
		if core.has_art():
			_check(Vector2i(core.get_art_texture().get_size()) == Vector2i(16, 16), "preview core keeps 16x16 source")

	_check(state_counts[0] == 2 and state_counts[1] == 2 and state_counts[2] == 2, "each state appears twice")
	_check(
		pair_keys.has("0@1") and pair_keys.has("0@4")
		and pair_keys.has("1@1") and pair_keys.has("1@4")
		and pair_keys.has("2@1") and pair_keys.has("2@4"),
		"all states have both actual-size and 4x near views",
		str(pair_keys.keys())
	)
	_check(all_positive_scale, "preview never mirrors the cores")

	var labels: Array[Label] = []
	_collect_labels(preview, labels)
	var joined: String = ""
	for label: Label in labels:
		joined += label.text + "\n"
		_check(not _has_non_ascii(label.text), "preview label is ASCII-only", label.text)

	_check(labels.size() >= 14, "preview has title, state, scale, and status labels", str(labels.size()))
	_check(joined.contains("STAR CORE VISUAL PREVIEW"), "preview has a title")
	_check(joined.contains("NOT GAMEPLAY"), "preview states that it is not gameplay")
	_check(joined.contains("ACTUAL SIZE (1x)"), "preview labels actual-size row")
	_check(joined.contains("NEAR VIEW (4x"), "preview labels integer near view")
	_check(joined.contains("LOCKED") and joined.contains("POSITIVE") and joined.contains("NEGATIVE"), "preview names all states")
	_check(joined.contains("ART STATUS:"), "preview shows art readiness status")
	_check(joined.contains("NO PHYSICS, SUCTION, INTERACTION, OR STAR-CORE BAY LOGIC"), "preview lists excluded systems")

	if _all_preview_art_ready(cores):
		_check(joined.contains("3/3 state sheets loaded"), "preview reports all art loaded")
		_check(joined.contains("12 FPS") and joined.contains("192x16"), "preview reports 12 FPS sheet playback")
	else:
		_check(joined.contains("Neutral dashed placeholders shown"), "preview reports neutral placeholders")
		_skip("preview loaded-art status text deferred until PNGs exist")

	preview.queue_free()
	await get_tree().process_frame


func _apply_state(core: StarCoreVisual, index: int) -> void:
	match index:
		1:
			core.state = StarCoreVisual.CoreState.POSITIVE
		2:
			core.state = StarCoreVisual.CoreState.NEGATIVE
		_:
			core.state = StarCoreVisual.CoreState.LOCKED


func _check_ready_assets_consistent(paths: Array[String]) -> bool:
	for path: String in paths:
		if not ResourceLoader.exists(path, "Texture2D"):
			return false
	return true


func _all_preview_art_ready(cores: Array[StarCoreVisual]) -> bool:
	for core: StarCoreVisual in cores:
		if not core.has_art():
			return false
	return true


func _count_physics_nodes(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is Area2D:
			count += 1
		count += _count_physics_nodes(child)
	return count


func _collect_cores(node: Node, out: Array[StarCoreVisual]) -> void:
	for child: Node in node.get_children():
		if child is StarCoreVisual:
			out.append(child as StarCoreVisual)
		_collect_cores(child, out)


func _collect_labels(node: Node, out: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			out.append(child as Label)
		_collect_labels(child, out)


func _has_non_ascii(text: String) -> bool:
	for index: int in text.length():
		if text.unicode_at(index) > 126:
			return true
	return false


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, "" if detail.is_empty() else " | " + detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, "" if detail.is_empty() else " | " + detail])


func _skip(label: String) -> void:
	_skip_count += 1
	_log("[SKIP] %s" % label)


func _section(title: String) -> void:
	_log("")
	_log("== %s ==" % title)


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	_log("")
	_log("RESULT pass=%d fail=%d skipped=%d" % [_pass_count, _fail_count, _skip_count])
	var log_directory: String = ProjectSettings.globalize_path("res://tests/logs")
	DirAccess.make_dir_recursive_absolute(log_directory)
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/star_core_visual_test.log",
		FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("STAR_CORE_VISUAL_TEST_RESULT pass=%d fail=%d skipped=%d" % [
		_pass_count,
		_fail_count,
		_skip_count,
	])
	get_tree().quit(1 if _fail_count > 0 else 0)
