extends Node

## DLC2/DLC3 indoor-depth acceptance test (2026-11-28).
##
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://scripts/world/tests/indoor_depth_test.tscn
##
## Covers:
##   * static 10-frame layer positions: delta 0;
##   * every parallax offset is round(scroll * factor), never scaled by zoom;
##   * atmosphere / danger-zone / player-clearance rects never overlap;
##   * foreground count per chapter <= 2 (currently 0);
##   * atmosphere alpha stays inside 0.12..0.22;
##   * the DLC2 far hall is 25-35% darker than the approved arch interior.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const RIFT_DEEP: String = "res://dlc/rift_workshop/assets/interior/interior_deep_1880x360.png"
const RIFT_BACK: String = "res://dlc/rift_workshop/assets/interior/interior_back_1880x360.png"
const LOOM_MASK: String = "res://dlc/star_loom/assets/city_v2/loom_niche_door_mask_960x360.png"
const LOOM_DEEP: String = "res://dlc/star_loom/assets/city_v2/loom_hall_deep_1280x360.png"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _test_rift()
	await _test_loom()
	print("INDOOR_DEPTH_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: " + label + ("" if detail.is_empty() else " [" + detail + "]"))
		return
	_failures.append(label + ("" if detail.is_empty() else " [" + detail + "]"))
	print("FAIL: " + label + ("" if detail.is_empty() else " [" + detail + "]"))


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _count_foreground(chapter: Node) -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("indoor_depth_foreground"):
		if chapter.is_ancestor_of(node):
			count += 1
	return count


func _check_rift_static_layers(label: String, depth: RiftDepthOverlay,
		atmosphere: IndoorAtmosphereBase, camera: Camera2D) -> void:
	var position_start: Vector2 = depth.position
	var offset_start: float = depth.get_deep_pixel_offset()
	var strength_start: float = depth.get_strength()
	var atmosphere_start: float = atmosphere.modulate.a
	var stable: bool = true
	for _index: int in range(10):
		await get_tree().process_frame
		if depth.position != position_start:
			stable = false
		if depth.get_deep_pixel_offset() != offset_start:
			stable = false
		if depth.get_strength() != strength_start:
			stable = false
		if atmosphere.modulate.a != atmosphere_start:
			stable = false
		if atmosphere.position != Vector2.ZERO:
			stable = false
	_check(stable, label + " static 10-frame layer delta is 0",
		"pos=%s offset=%.1f strength=%.2f" % [
			str(position_start), offset_start, strength_start
		])
	var camera_x: float = camera.get_screen_center_position().x
	var scroll: float = camera_x - 320.0
	var wall_x: float = -roundf(scroll * depth.get_wall_factor())
	var expected: float = roundf(scroll * depth.get_factor()) + wall_x
	_check(position_start.x == wall_x,
		label + " depth overlay shares the rounded Back offset",
		"x=%.1f expected=%.1f" % [position_start.x, wall_x])
	_check(offset_start == expected,
		label + " deep content uses round(scroll * factor)",
		"offset=%.1f expected=%.1f camera=%.1f" % [
			offset_start, expected, camera_x
		])
	_check(position_start.x - offset_start == -roundf(scroll * depth.get_factor()),
		label + " deep content screen offset is round(scroll * factor)",
		"screen=%.1f" % (position_start.x - offset_start))
	_check(position_start.x == roundf(position_start.x),
		label + " overlay position is a whole pixel", "x=%.3f" % position_start.x)
	_check(depth.get_factor() >= 0.60 and depth.get_factor() <= 0.70,
		label + " parallax factor stays 0.60..0.70",
		"factor=%.2f" % depth.get_factor())
	_check(is_equal_approx(depth.get_wall_factor(), 0.90),
		label + " depth overlay follows the 0.90 wall factor",
		"wall=%.2f" % depth.get_wall_factor())
	_check(is_equal_approx(strength_start, 1.0),
		label + " far hall is fully on outside the film",
		"strength=%.2f" % strength_start)


func _check_loom_static_layers(label: String, depth: LoomDepthOverlay,
		atmosphere: IndoorAtmosphereBase, camera: Camera2D) -> void:
	var offset_start: float = depth.get_deep_pixel_offset()
	var strength_start: float = depth.get_strength()
	var position_start: Vector2 = depth.position
	var atmosphere_start: float = atmosphere.modulate.a
	var stable: bool = true
	for _index: int in range(10):
		await get_tree().process_frame
		if depth.get_deep_pixel_offset() != offset_start:
			stable = false
		if depth.get_strength() != strength_start:
			stable = false
		if depth.position != position_start:
			stable = false
		if atmosphere.position != Vector2.ZERO:
			stable = false
		if atmosphere.modulate.a != atmosphere_start:
			stable = false
	_check(stable, label + " static 10-frame layer delta is 0",
		"offset=%.1f strength=%.2f pos=%s" % [
			offset_start, strength_start, str(position_start)
		])
	var camera_x: float = camera.get_screen_center_position().x
	var scroll: float = camera_x - 320.0
	var expected: float = roundf(scroll * depth.get_factor()) - scroll
	_check(offset_start == expected,
		label + " deep content uses round(scroll * factor)",
		"offset=%.1f expected=%.1f camera=%.1f" % [
			offset_start, expected, camera_x
		])
	_check(offset_start == roundf(offset_start),
		label + " deep sample offset is a whole pixel", "offset=%.3f" % offset_start)
	_check(position_start == position_start.round(),
		label + " overlay position is a whole pixel", str(position_start))
	_check(depth.get_factor() >= 0.60 and depth.get_factor() <= 0.70,
		label + " parallax factor stays 0.60..0.70",
		"factor=%.2f" % depth.get_factor())
	_check(is_equal_approx(strength_start, 1.0),
		label + " far hall is fully on outside the film",
		"strength=%.2f" % strength_start)


func _check_atmosphere(label: String, atmosphere: IndoorAtmosphereBase) -> void:
	var rects: Array[Rect2] = atmosphere.get_visible_rects()
	var alphas: Array[float] = atmosphere.get_visible_alphas()
	var player_clear: Rect2 = atmosphere.get_player_clear_rect()
	var hazards: Array[Rect2] = atmosphere.get_hazard_rects()
	_check(rects.size() > 0, label + " atmosphere has visible local pieces",
		"rects=%d" % rects.size())
	var no_player: bool = true
	var no_hazard: bool = true
	var integral: bool = true
	var alpha_ok: bool = true
	for rect: Rect2 in rects:
		if rect.intersects(player_clear):
			no_player = false
		for hazard: Rect2 in hazards:
			if rect.intersects(hazard):
				no_hazard = false
		if rect.position != rect.position.round() or rect.size != rect.size.round():
			integral = false
	for alpha: float in alphas:
		if alpha < 0.12 - 0.0001 or alpha > 0.22 + 0.0001:
			alpha_ok = false
	_check(no_player, label + " no atmosphere rect covers player box +8 px",
		"player_clear=%s" % str(player_clear))
	_check(no_hazard, label + " no atmosphere rect covers a danger zone",
		"hazards=%d" % hazards.size())
	_check(integral, label + " atmosphere rects are whole-pixel")
	_check(alpha_ok, label + " atmosphere alpha stays 0.12..0.22",
		"count=%d" % alphas.size())
	_check(atmosphere.get_foreground_count() <= 2,
		label + " optional foreground count <= 2",
		"count=%d" % atmosphere.get_foreground_count())
	_check(_count_foreground(atmosphere.get_parent()) <= 2,
		label + " chapter foreground count <= 2")


func _move_player(player: Node2D, camera: Camera2D, x: float, y: float) -> void:
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	player.set_physics_process(false)
	await _wait_process(8)


func _test_rift() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_check(packed != null, "DLC2 scene loads")
	if packed == null:
		return
	var rift: RiftWorkshop = packed.instantiate() as RiftWorkshop
	rift.show_intro_guide = false
	rift.show_intro_cinematic = false
	get_tree().root.add_child(rift)
	get_tree().current_scene = rift
	await _wait_process(4)
	await _wait_physics(8)
	var player: L3Player = rift.get_player()
	var camera: Camera2D = rift.get_camera()
	var depth: RiftDepthOverlay = rift.get_node_or_null("Background/DepthOverlay") as RiftDepthOverlay
	var atmosphere: IndoorAtmosphereBase = rift.get_node_or_null("Atmosphere") as IndoorAtmosphereBase
	var hud: CanvasLayer = rift.get_node_or_null("HUD") as CanvasLayer
	var background: CanvasLayer = rift.get_node_or_null("Background") as CanvasLayer
	_check(player != null and camera != null and depth != null and atmosphere != null,
		"DLC2 depth/atmosphere nodes exist")
	if player == null or camera == null or depth == null or atmosphere == null:
		rift.queue_free()
		await _wait_process(8)
		return
	_check(background != null and background.layer == -10 and depth.z_index == 0
		and depth.get_parent() == background,
		"DLC2 masked far hall is composed in the background depth",
		"background=%d overlay=%d" % [
			-10 if background == null else background.layer, depth.z_index
		])
	_check(atmosphere.z_index == 10 and hud != null and hud.layer == 10,
		"DLC2 atmosphere is world-front and HUD-back",
		"z=%d hud=%d" % [atmosphere.z_index, 10 if hud == null else hud.layer])
	_check(is_equal_approx(atmosphere.modulate.a, 1.0),
		"DLC2 atmosphere is fully on outside the film",
		"modulate=%.2f" % atmosphere.modulate.a)
	await _move_player(player, camera, 1100.0, 320.0)
	_check(depth.get_scroll() > 0.0, "DLC2 camera scroll is non-zero",
		"scroll=%.1f" % depth.get_scroll())
	await _check_rift_static_layers("DLC2", depth, atmosphere, camera)

	# Zoom must not scale the far-layer offset.
	var before_zoom: float = depth.get_deep_pixel_offset()
	camera.zoom = Vector2(2.0, 2.0)
	await _wait_process(3)
	_check(depth.get_deep_pixel_offset() == before_zoom,
		"DLC2 deep content ignores camera zoom",
		"offset=%.1f" % depth.get_deep_pixel_offset())
	camera.zoom = Vector2.ONE

	# Player under the forge: the plume is above the clearance box.
	await _move_player(player, camera, 46.0, 320.0)
	await _check_atmosphere("DLC2", atmosphere)

	# Player jumping into the lower plume: those puffs must be skipped.
	await _move_player(player, camera, 46.0, 270.0)
	var rects: Array[Rect2] = atmosphere.get_visible_rects()
	var clear: Rect2 = atmosphere.get_player_clear_rect()
	var overlap: bool = false
	for rect: Rect2 in rects:
		if rect.intersects(clear):
			overlap = true
	_check(not overlap, "DLC2 jumping player is never covered")

	# Darkening: sample the far hall and the approved arch interior.
	var ratio: float = _rift_darkening_ratio()
	_check(ratio >= 0.65 and ratio <= 0.75,
		"DLC2 far hall is 25-35% darker than the approved arch interior",
		"ratio=%.3f" % ratio)

	rift.queue_free()
	await _wait_process(20)
	get_tree().current_scene = null
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(8)


func _test_loom() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	_check(packed != null, "DLC3 scene loads")
	if packed == null:
		return
	var loom: StarLoom = packed.instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = false
	get_tree().root.add_child(loom)
	get_tree().current_scene = loom
	await _wait_process(4)
	await _wait_physics(8)
	var player: L3Player = loom.get_player()
	var camera: Camera2D = loom.get_camera()
	var depth: LoomDepthOverlay = loom.get_node_or_null("Depth") as LoomDepthOverlay
	var atmosphere: IndoorAtmosphereBase = loom.get_node_or_null("Atmosphere") as IndoorAtmosphereBase
	var hud: CanvasLayer = loom.get_node_or_null("HUD") as CanvasLayer
	var city_back: Sprite2D = loom.get_node_or_null("CityBack") as Sprite2D
	_check(player != null and camera != null and depth != null and atmosphere != null,
		"DLC3 depth/atmosphere nodes exist")
	if player == null or camera == null or depth == null or atmosphere == null:
		loom.queue_free()
		await _wait_process(8)
		return
	_check(city_back != null and city_back.z_index == -10 and depth.z_index == -9,
		"DLC3 masked far hall is composed in the wall depth",
		"wall=%d overlay=%d" % [
			-10 if city_back == null else city_back.z_index, depth.z_index
		])
	_check(atmosphere.z_index == 10 and hud != null and hud.layer == 10,
		"DLC3 atmosphere is world-front and HUD-back",
		"z=%d hud=%d" % [atmosphere.z_index, 10 if hud == null else hud.layer])
	_check(is_equal_approx(atmosphere.modulate.a, 1.0),
		"DLC3 atmosphere is fully on outside the film",
		"modulate=%.2f" % atmosphere.modulate.a)
	var gate: MirrorRiftGate = loom.get_node_or_null("MirrorRiftGate") as MirrorRiftGate
	_check(gate != null and is_equal_approx(gate.get_depth_strength(), 1.0),
		"DLC3 mirror-door depth is on outside the film",
		"strength=%.2f" % (0.0 if gate == null else gate.get_depth_strength()))
	_check_dlc3_mask()
	await _move_player(player, camera, 400.0, 320.0)
	_check(depth.get_scroll() > 0.0, "DLC3 camera scroll is non-zero",
		"scroll=%.1f" % depth.get_scroll())
	await _check_loom_static_layers("DLC3", depth, atmosphere, camera)

	var before_zoom: float = depth.get_deep_pixel_offset()
	camera.zoom = Vector2(2.0, 2.0)
	await _wait_process(3)
	_check(depth.get_deep_pixel_offset() == before_zoom,
		"DLC3 deep content ignores camera zoom",
		"offset=%.1f" % depth.get_deep_pixel_offset())
	camera.zoom = Vector2.ONE

	# Player between the two braziers: dust and fibres stay visible.
	await _move_player(player, camera, 400.0, 320.0)
	await _check_atmosphere("DLC3", atmosphere)

	# Player at the left brazier: the near cone motes must be skipped.
	await _move_player(player, camera, 236.0, 300.0)
	var rects: Array[Rect2] = atmosphere.get_visible_rects()
	var clear: Rect2 = atmosphere.get_player_clear_rect()
	var overlap: bool = false
	for rect: Rect2 in rects:
		if rect.intersects(clear):
			overlap = true
	_check(not overlap, "DLC3 brazier-side player is never covered")

	var dust: LoomDustAtmosphere = atmosphere as LoomDustAtmosphere
	if dust != null:
		var inside: bool = true
		for rect: Rect2 in dust.get_visible_rects():
			# Fibres live above the cones; only check 1x1 dust motes.
			if rect.size == Vector2.ONE and not dust.is_inside_cone(rect.position):
				inside = false
		_check(inside, "DLC3 dust motes stay inside a lamp cone")

	loom.queue_free()
	await _wait_process(20)
	get_tree().current_scene = null
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(8)


func _check_dlc3_mask() -> void:
	var mask_texture: Texture2D = load(LOOM_MASK) as Texture2D
	var deep_texture: Texture2D = load(LOOM_DEEP) as Texture2D
	if mask_texture == null or deep_texture == null:
		_check(false, "DLC3 niche/door mask and deep texture load")
		return
	var mask: Image = mask_texture.get_image()
	var deep: Image = deep_texture.get_image()
	if mask == null or deep == null:
		_check(false, "DLC3 niche/door mask image is readable")
		return
	# The three same-pattern cloud-sea window panes must be completely absent
	# from the new layer mask.
	var window_pixels: int = 0
	for window_x: int in [76, 264, 452]:
		for y: int in range(92, 296):
			for x: int in range(window_x, window_x + 126):
				if mask.get_pixel(x, y).a > 0.0:
					window_pixels += 1
	_check(window_pixels == 0,
		"DLC3 three cloud-sea window panes get zero dark layer",
		"mask_pixels=%d" % window_pixels)

	# Central apse and the right mirror-door recess must both carry the far
	# hall.  The deep texture itself must still contain readable structure.
	var apse_pixels: int = 0
	for y: int in range(70, 299):
		for x: int in range(604, 837):
			if mask.get_pixel(x, y).a > 0.0:
				apse_pixels += 1
	var door_pixels: int = 0
	for y: int in range(224, 320):
		for x: int in range(402, 438):
			if mask.get_pixel(x, y).a > 0.0:
				door_pixels += 1
	_check(apse_pixels > 10000,
		"DLC3 central loom apse has a deep-layer opening",
		"mask_pixels=%d" % apse_pixels)
	_check(door_pixels > 1000,
		"DLC3 right mirror door has a deep-layer opening",
		"mask_pixels=%d" % door_pixels)
	var colors: Dictionary = {}
	for y: int in range(72, 296, 4):
		for x: int in range(606, 835, 4):
			var pixel: Color = deep.get_pixel(x, y)
			colors[Color(pixel.r, pixel.g, pixel.b)] = true
	_check(colors.size() > 16,
		"DLC3 apse deep slice contains far columns/beams/threads",
		"unique_colors=%d" % colors.size())


func _rift_darkening_ratio() -> float:
	var deep_texture: Texture2D = load(RIFT_DEEP) as Texture2D
	var back_texture: Texture2D = load(RIFT_BACK) as Texture2D
	if deep_texture == null or back_texture == null:
		return -1.0
	var deep_image: Image = deep_texture.get_image()
	var back_image: Image = back_texture.get_image()
	if deep_image == null or back_image == null:
		return -1.0
	var deep_values: Array[float] = []
	var back_values: Array[float] = []
	for y: int in range(102, 297, 4):
		for x: int in range(616, 995, 4):
			var d: Color = deep_image.get_pixel(x, y)
			var b: Color = back_image.get_pixel(x, y)
			deep_values.append(0.2126 * d.r + 0.7152 * d.g + 0.0722 * d.b)
			back_values.append(0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b)
	deep_values.sort()
	back_values.sort()
	if deep_values.is_empty() or back_values.is_empty():
		return -1.0
	var deep_median: float = deep_values[deep_values.size() / 2]
	var back_median: float = back_values[back_values.size() / 2]
	if back_median <= 0.0:
		return -1.0
	return deep_median / back_median
