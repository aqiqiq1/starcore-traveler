extends Node

## Independent acceptance test for the first-pass 32x32 star-core bay visual
## component, its layered PNGs, and its standalone 640x360 preview.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_star_core_bay_visual.tscn
##
## This test does not exercise gameplay, physics, bay storage, or the default
## main scene. It only checks the visual contract and the real assets.

const BAY_SCENE: PackedScene = preload("res://scenes/star_core_bay_visual.tscn")
const PREVIEW_SCENE: PackedScene = preload("res://tools/preview_star_core_bay.tscn")
const CORE_SCENE: PackedScene = preload("res://scenes/star_core_visual.tscn")

const BASE_PATH: String = "res://assets/star_core_bay/star_core_bay_base.png"
const GLASS_PATH: String = "res://assets/star_core_bay/star_core_bay_glass.png"
const EMPTY_PATH: String = "res://assets/star_core_bay/star_core_bay_empty.png"
const CORE_PATH: String = "res://assets/star_core/star_core_locked.png"

const BAY_SIZE: Vector2i = Vector2i(32, 32)
const CORE_SIZE: Vector2i = Vector2i(16, 16)

var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_log("Star Core Traveler - star-core bay visual test")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	_test_project_config()
	await _test_component_contract()
	await _test_png_layers()
	await _test_occupied_toggle()
	await _test_lid_animation()
	await _test_preview_layout()
	_finish()


func _test_project_config() -> void:
	_section("PROJECT AND LAYOUT CONFIG")
	_check(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
		"project logic viewport remains 640x360"
	)
	_check(
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"project default texture filter remains nearest"
	)
	_check(
		String(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/main.tscn",
		"default main scene is unchanged (bay is not wired into gameplay)"
	)


func _test_component_contract() -> void:
	_section("COMPONENT CONTRACT AND LAYER ORDER")
	var bay: StarCoreBayVisual = BAY_SCENE.instantiate() as StarCoreBayVisual
	add_child(bay)
	await get_tree().process_frame

	_check(bay != null, "bay scene instantiates as StarCoreBayVisual")
	if bay == null:
		return
	_check(bay is Node2D, "bay root is Node2D")
	_check(bay.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "bay root uses nearest filtering")
	_check(_count_physics_nodes(bay) == 0, "bay has no collision, area, or body nodes")
	_check(bay.get_child_count() == 4, "bay owns Base, LockMark, Core, and Glass children", str(bay.get_child_count()))

	var script: Script = bay.get_script()
	_check(script != null and script.is_tool(), "bay script is @tool (editor-visible)")

	var base: Sprite2D = bay.get_node_or_null("Base") as Sprite2D
	var lock: StarCoreBayLockMark = bay.get_node_or_null("LockMark") as StarCoreBayLockMark
	var core: StarCoreVisual = bay.get_node_or_null("Core") as StarCoreVisual
	var glass: Sprite2D = bay.get_node_or_null("Glass") as Sprite2D
	_check(base != null and glass != null, "Base and Glass sprites exist")
	_check(lock != null, "LockMark is a separate code-drawn child node")
	_check(core != null, "Core is the existing StarCoreVisual instance")
	if base == null or glass == null or core == null or lock == null:
		return

	_check(bay.get_base_sprite() == base, "get_base_sprite returns the Base layer")
	_check(bay.get_glass_sprite() == glass, "get_glass_sprite returns the Glass layer")
	_check(bay.get_core_visual() == core, "get_core_visual returns the Core layer")
	_check(bay.get_lock_marker() == lock, "get_lock_marker returns the LockMark layer")
	_check(lock.get_script() != null and lock.get_script().is_tool(), "LockMark script is @tool")

	_check(base.position == Vector2.ZERO, "Base shares the bay origin")
	_check(lock.position == Vector2.ZERO, "LockMark shares the bay origin")
	_check(core.position == Vector2.ZERO, "Core shares the bay origin")
	_check(glass.position == Vector2.ZERO, "Glass shares the bay origin")
	_check(base.centered and glass.centered, "Base and Glass are centered on the same origin")
	_check(base.scale == Vector2.ONE and core.scale == Vector2.ONE and glass.scale == Vector2.ONE,
		"all sprite layers are displayed 1:1")
	_check(
		base.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and core.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and glass.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"all sprite layers use nearest filtering"
	)
	_check(
		base.z_index == 1 and lock.z_index == 1 and core.z_index == 2 and glass.z_index == 3,
		"all bay z indices are non-negative: Base=1, LockMark=1, Core=2, Glass=3"
	)
	_check(
		base.z_index <= lock.z_index and lock.z_index < core.z_index and core.z_index < glass.z_index,
		"layer order is Base/LockMark < Core < Glass"
	)
	_check(base.get_index() < lock.get_index() and lock.get_index() < core.get_index(),
		"LockMark is between Base and Core in tree order so it draws over the pedestal"
	)

	_check(core.state == StarCoreVisual.CoreState.LOCKED, "core is in the purple LOCKED state")
	_check(not core.show_state_badge, "original bottom-right core badge is disabled")
	_check(not core.get_badge_kind().is_empty(), "core still exposes its visual badge kind")
	_check(core.get_art_texture() != null, "core has its existing 16x16 texture")
	if core.get_art_texture() != null:
		_check(Vector2i(core.get_art_texture().get_size()) == CORE_SIZE, "core texture is 16x16")

	_check(bay.get_source_size() == BAY_SIZE, "declared bay source size is 32x32")
	_check(bay.get_bay_rect() == Rect2(-16.0, -16.0, 32.0, 32.0), "bay rect is 32x32 around the origin")
	_check(bay.get_core_rect() == Rect2(-8.0, -8.0, 16.0, 16.0), "core rect is 16x16 around the origin")
	_check(bay.get_pedestal_top_y() == 8.0, "pedestal top is local y=+8")
	_check(bay.get_core_rect().end.y == bay.get_pedestal_top_y(),
		"core bottom meets, but does not overlap, the pedestal top")
	_check(not bay.get_core_rect().intersects(Rect2(-16.0, 8.0, 32.0, 24.0)),
		"core rect does not intersect the pedestal rect")
	var lock_rect: Rect2 = bay.get_lock_marker_rect()
	_check(lock_rect == Rect2(4.0, 11.0, 4.0, 3.0), "lock marker is a 4x3 mark on the pedestal")
	_check(lock.get_marker_rect() == lock_rect, "LockMark draws the same 4x3 rect exposed by the bay")
	_check(lock_rect.position.y >= bay.get_pedestal_top_y(), "lock marker sits on the pedestal, below the core")
	_check(not lock_rect.intersects(bay.get_core_rect()), "lock marker never overlaps the core rect")
	_check(bay.get_bay_rect().encloses(lock_rect), "lock marker stays inside the 32x32 bay")

	_check(bay.occupied, "occupied defaults to true")
	_check(bay.show_lock_marker, "show_lock_marker defaults to true")
	_check(bay.is_lock_marker_visible() and lock.visible, "occupied bay draws the lock marker by default")

	var occupied_exported: bool = false
	var lock_exported: bool = false
	for property: Dictionary in bay.get_property_list():
		if property.name == "occupied":
			occupied_exported = true
		if property.name == "show_lock_marker":
			lock_exported = true
	_check(occupied_exported, "occupied is exposed to the inspector")
	_check(lock_exported, "show_lock_marker is exposed to the inspector")

	_check(bay.has_art(), "Base and Glass art are loaded")
	_check(bay.get_missing_texture_paths().is_empty(), "no bay layer reports missing art")
	_check(
		StarCoreBayVisual.load_texture_safely("res://assets/star_core_bay/__missing__.png") == null,
		"safe loader returns null for a missing path"
	)

	bay.queue_free()
	await get_tree().process_frame


func _test_png_layers() -> void:
	_section("PNG DIMENSIONS, ALPHA, AND CORE CLEARANCE")
	var base_image: Image = _load_rgba(BASE_PATH)
	var glass_image: Image = _load_rgba(GLASS_PATH)
	var empty_image: Image = _load_rgba(EMPTY_PATH)
	var core_image: Image = _load_rgba(CORE_PATH)

	_check(base_image != null and glass_image != null and empty_image != null,
		"all three bay PNGs load")
	_check(core_image != null, "existing purple core PNG loads")
	if base_image == null or glass_image == null or empty_image == null or core_image == null:
		return

	_check(base_image.get_size() == BAY_SIZE, "base PNG is 32x32")
	_check(glass_image.get_size() == BAY_SIZE, "glass PNG is 32x32")
	_check(empty_image.get_size() == BAY_SIZE, "empty composite PNG is 32x32")
	_check(core_image.get_size() == CORE_SIZE, "core PNG remains 16x16")
	_check(base_image.detect_alpha() != Image.ALPHA_NONE, "base keeps an alpha channel")
	_check(glass_image.detect_alpha() != Image.ALPHA_NONE, "glass keeps an alpha channel")
	_check(empty_image.detect_alpha() != Image.ALPHA_NONE, "empty composite keeps an alpha channel")

	var base_used: Rect2i = base_image.get_used_rect()
	var glass_used: Rect2i = glass_image.get_used_rect()
	_check(base_used.position.y == 24, "base pixels start at image y=24", str(base_used))
	_check(base_used.end.y == 32, "base pixels reach the bottom of the canvas", str(base_used))
	_check(glass_used.position.y >= 1 and glass_used.end.y <= 25,
		"glass stays above the pedestal body (y=1..24)", str(glass_used))

	var base_above_pedestal: int = 0
	for y: int in range(0, 24):
		for x: int in range(BAY_SIZE.x):
			if _alpha_at(base_image, x, y) > 0:
				base_above_pedestal += 1
	_check(base_above_pedestal == 0, "base has no pixels above y=24; it stays behind the core")

	var base_in_core_rect: int = 0
	var glass_in_core_rect: int = 0
	var glass_core_rect_max_alpha: int = 0
	for y: int in range(8, 24):
		for x: int in range(8, 24):
			if _alpha_at(base_image, x, y) > 0:
				base_in_core_rect += 1
			var alpha: int = _alpha_at(glass_image, x, y)
			if alpha > 0:
				glass_in_core_rect += 1
			glass_core_rect_max_alpha = maxi(glass_core_rect_max_alpha, alpha)
	_check(base_in_core_rect == 0, "base does not occupy the core's 16x16 rect")
	_check(glass_in_core_rect == 0, "glass is fully transparent over the core's 16x16 rect")
	_check(glass_core_rect_max_alpha == 0, "glass alpha over the core rect is exactly 0")

	var core_outside_glass: int = 0
	for y: int in range(8, 24):
		var leftmost: int = BAY_SIZE.x
		var rightmost: int = -1
		for x: int in range(BAY_SIZE.x):
			if _alpha_at(glass_image, x, y) > 0:
				leftmost = mini(leftmost, x)
				rightmost = maxi(rightmost, x)
		if leftmost > 8 or rightmost < 23:
			core_outside_glass += 1
	_check(core_outside_glass == 0,
		"core stays inside the glass outer silhouette on every core row")

	var mean_luminance: float = 0.0
	var opaque_base_pixels: int = 0
	var gold_pixels: int = 0
	for y: int in range(BAY_SIZE.y):
		for x: int in range(BAY_SIZE.x):
			var color: Color = base_image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			opaque_base_pixels += 1
			mean_luminance += 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
			if color.r > 0.55 and color.r > color.b + 0.25 and color.g > color.b + 0.12:
				gold_pixels += 1
	if opaque_base_pixels > 0:
		mean_luminance /= float(opaque_base_pixels)
	_check(opaque_base_pixels > 100, "base has a substantial opaque silhouette", str(opaque_base_pixels))
	_check(mean_luminance >= 0.60, "base reads as a white/light pedestal, not a dark base",
		"mean=%.3f" % mean_luminance)
	_check(gold_pixels >= 4 and gold_pixels <= 24,
		"base has a small gold rune accent, not a gold-covered base",
		str(gold_pixels))

	var bright_glints: int = 0
	var cyan_pixels: int = 0
	for y: int in range(BAY_SIZE.y):
		for x: int in range(BAY_SIZE.x):
			var color: Color = glass_image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if color.r > 0.90 and color.g > 0.90 and color.b > 0.90 and color.a > 0.45:
				bright_glints += 1
			if color.g > color.r + 0.08 and color.b > color.r + 0.08:
				cyan_pixels += 1
	_check(bright_glints >= 3, "glass has a few bright white reflections", str(bright_glints))
	_check(cyan_pixels >= 20, "glass edge is pale cyan", str(cyan_pixels))

	var empty_purple: int = 0
	for y: int in range(BAY_SIZE.y):
		for x: int in range(BAY_SIZE.x):
			var color: Color = empty_image.get_pixel(x, y)
			if color.r > 0.75 and color.b > 0.75 and color.g < 0.70:
				empty_purple += 1
	_check(empty_purple == 0, "empty composite contains no purple core pixels")

	_check(_alpha_at(empty_image, 15, 15) == 0,
		"empty composite center is fully transparent: no baked core, only the glass interior")


func _test_occupied_toggle() -> void:
	_section("OCCUPIED DISPLAY TOGGLE")
	var bay: StarCoreBayVisual = BAY_SCENE.instantiate() as StarCoreBayVisual
	add_child(bay)
	await get_tree().process_frame

	var core: StarCoreVisual = bay.get_core_visual()
	var lock: StarCoreBayLockMark = bay.get_lock_marker()
	_check(core != null and core.visible, "occupied bay starts with the core visible")
	_check(lock != null and lock.visible, "occupied bay starts with the lock mark enabled")

	bay.occupied = false
	await get_tree().process_frame
	_check(not bay.occupied, "occupied=false is applied")
	_check(core != null and not core.visible, "occupied=false hides the core")
	_check(lock != null and not lock.visible, "occupied=false hides the actual LockMark node")
	_check(not bay.is_lock_marker_visible(), "occupied=false reports the lock mark hidden")
	_check(core != null and core.state == StarCoreVisual.CoreState.LOCKED,
		"occupied=false does not change the purple core state")
	_check(core != null and not core.show_state_badge, "core badge stays off while empty")

	bay.occupied = true
	await get_tree().process_frame
	_check(bay.occupied and core != null and core.visible, "occupied=true restores the core")
	_check(lock != null and lock.visible, "occupied=true restores the actual LockMark node")
	_check(bay.is_lock_marker_visible(), "occupied=true reports the lock mark visible")

	bay.show_lock_marker = false
	_check(lock != null and not lock.visible, "show_lock_marker=false hides the actual LockMark node")
	_check(core != null and core.visible, "hiding the lock mark does not hide the core")
	bay.show_lock_marker = true
	_check(lock != null and lock.visible, "show_lock_marker=true restores the actual LockMark node")

	bay.queue_free()
	await get_tree().process_frame


func _test_lid_animation() -> void:
	_section("LID ANIMATION (STATIC OCCUPIED API PRESERVED)")
	var bay: StarCoreBayVisual = BAY_SCENE.instantiate() as StarCoreBayVisual
	add_child(bay)
	await get_tree().process_frame

	var glass: Sprite2D = bay.get_glass_sprite()
	_check(glass != null, "lid animation has a Glass node")
	if glass == null:
		bay.queue_free()
		return
	_check(bay.is_lid_closed() and not bay.is_lid_open(),
		"default lid state is closed/visible")
	_check(glass.visible and glass.position == Vector2.ZERO and glass.scale == Vector2.ONE,
		"default closed glass stays at the old static transform")
	_check(bay.get_lid_progress() == 0.0, "default lid progress is zero")

	var material: ShaderMaterial = glass.material as ShaderMaterial
	_check(material != null and material.shader != null,
		"glass uses the side-to-centre lid shader")
	_check(material != null and is_equal_approx(
		float(material.get_shader_parameter("open_progress")), 0.0),
		"closed glass has a full reveal mask")
	_check(glass.position == Vector2.ZERO and glass.scale == Vector2.ONE,
		"mask animation does not squash or move the glass")

	bay.start_open(0.01)
	await _wait_for_lid_state(bay, true)
	_check(bay.is_lid_open(), "short open animation reaches fully open")
	_check(not glass.visible, "fully open glass is hidden")
	_check(glass.position == Vector2.ZERO and glass.scale == Vector2.ONE,
		"open glass keeps a 1:1 transform (no scale.y squash)")
	_check(material != null and is_equal_approx(
		float(material.get_shader_parameter("open_progress")), 1.0),
		"open glass is fully discarded by the shader mask")

	# CPU mirror of the shader mask: symmetry and top-last ordering.
	_check(
		StarCoreBayVisual.is_lid_mask_pixel_visible(0.33, 3, 16)
		and StarCoreBayVisual.is_lid_mask_pixel_visible(0.33, 28, 16),
		"mid-close mask keeps both side walls symmetrically"
	)
	_check(
		StarCoreBayVisual.is_lid_mask_pixel_visible(0.33, 3, 16)
		== StarCoreBayVisual.is_lid_mask_pixel_visible(0.33, 28, 16)
		and StarCoreBayVisual.is_lid_mask_pixel_visible(0.33, 2, 23)
		== StarCoreBayVisual.is_lid_mask_pixel_visible(0.33, 29, 23),
		"mask visibility is mirrored left/right"
	)
	_check(not StarCoreBayVisual.is_lid_mask_pixel_visible(0.33, 15, 1),
		"top centre is still open at 33% closed")
	_check(StarCoreBayVisual.is_lid_mask_pixel_visible(0.33, 2, 23),
		"lower side wall is already closed at 33%")
	_check(StarCoreBayVisual.is_lid_mask_pixel_visible(0.66, 3, 16),
		"upper side remains at 66% open")
	_check(not StarCoreBayVisual.is_lid_mask_pixel_visible(0.8, 3, 16)
		and StarCoreBayVisual.is_lid_mask_pixel_visible(0.8, 2, 23),
		"only the lower side remains at 80% open")
	_check(not StarCoreBayVisual.is_lid_mask_pixel_visible(0.05, 15, 1)
		and StarCoreBayVisual.is_lid_mask_pixel_visible(0.0, 15, 1),
		"top centre is the last pixel to close")
	_check(not StarCoreBayVisual.is_lid_mask_pixel_visible(1.0, 2, 23),
		"fully open mask hides even the lower side")
	_check(StarCoreBayVisual.is_lid_mask_pixel_visible(0.0, 15, 1)
		and StarCoreBayVisual.is_lid_mask_pixel_visible(0.0, 2, 23),
		"fully closed mask shows the original dome")

	bay.start_close(0.01)
	await _wait_for_lid_state(bay, false)
	_check(bay.is_lid_closed(), "short close animation reaches fully closed")
	_check(glass.visible and glass.position == Vector2.ZERO and glass.scale == Vector2.ONE,
		"closed glass returns to the old static transform")
	_check(material != null and is_equal_approx(
		float(material.get_shader_parameter("open_progress")), 0.0),
		"closed mask is full again")

	bay.set_lid_open_immediately(true)
	_check(bay.is_lid_open(), "set_lid_open_immediately(true) is compatible")
	bay.set_lid_open_immediately(false)
	_check(bay.is_lid_closed(), "set_lid_open_immediately(false) is compatible")

	bay.queue_free()
	await get_tree().process_frame


func _test_preview_layout() -> void:
	_section("STANDALONE 640x360 PREVIEW")
	var preview: Control = PREVIEW_SCENE.instantiate() as Control
	add_child(preview)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(preview != null, "preview scene instantiates")
	if preview == null:
		return
	_check(preview.size == Vector2(640.0, 360.0), "preview canvas is 640x360", str(preview.size))
	_check(_count_physics_nodes(preview) == 0, "preview contains no physics nodes")

	var bays: Array[StarCoreBayVisual] = []
	_collect_bays(preview, bays)
	_check(bays.size() == 4, "preview shows empty and occupied twice (1x and 4x)", str(bays.size()))

	var names: Array[String] = []
	var empty_1x: StarCoreBayVisual = null
	var occupied_1x: StarCoreBayVisual = null
	var empty_4x: StarCoreBayVisual = null
	var occupied_4x: StarCoreBayVisual = null
	for bay: StarCoreBayVisual in bays:
		names.append(String(bay.name))
		match String(bay.name):
			"Empty_1x":
				empty_1x = bay
			"Occupied_1x":
				occupied_1x = bay
			"Empty_4x":
				empty_4x = bay
			"Occupied_4x":
				occupied_4x = bay
	_check(
		names.has("Empty_1x") and names.has("Occupied_1x")
		and names.has("Empty_4x") and names.has("Occupied_4x"),
		"preview names all four bay instances",
		str(names)
	)
	_check(empty_1x != null and occupied_1x != null and empty_4x != null and occupied_4x != null,
		"preview provides empty/occupied at 1x and 4x")
	if empty_1x == null or occupied_1x == null or empty_4x == null or occupied_4x == null:
		preview.queue_free()
		return

	_check(empty_1x.scale == Vector2.ONE and occupied_1x.scale == Vector2.ONE,
		"1x bay instances are actual size")
	_check(empty_4x.scale == Vector2(4.0, 4.0) and occupied_4x.scale == Vector2(4.0, 4.0),
		"4x bay instances use integer 4x magnification")
	_check(not empty_1x.occupied and not empty_4x.occupied, "empty bays are not occupied")
	_check(occupied_1x.occupied and occupied_4x.occupied, "occupied bays are occupied")
	_check(empty_1x.get_core_visual() != null and not empty_1x.get_core_visual().visible,
		"empty 1x bay hides its core")
	_check(empty_4x.get_core_visual() != null and not empty_4x.get_core_visual().visible,
		"empty 4x bay hides its core")
	_check(occupied_1x.get_core_visual() != null and occupied_1x.get_core_visual().visible,
		"occupied 1x bay shows its core")
	_check(occupied_4x.get_core_visual() != null and occupied_4x.get_core_visual().visible,
		"occupied 4x bay shows its core")

	var all_nearest: bool = true
	var all_art_loaded: bool = true
	var all_cores_16: bool = true
	for bay: StarCoreBayVisual in bays:
		all_nearest = all_nearest and bay.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		all_art_loaded = all_art_loaded and bay.has_art()
		var core: StarCoreVisual = bay.get_core_visual()
		all_cores_16 = all_cores_16 and core != null \
			and core.get_art_texture() != null \
			and Vector2i(core.get_art_texture().get_size()) == CORE_SIZE
	_check(all_nearest, "all preview bay instances keep nearest filtering")
	_check(all_art_loaded, "all preview bay instances have both bay PNGs")
	_check(all_cores_16, "all preview cores stay 16x16")

	var player: Sprite2D = _find_sprite(preview, "PlayerIdleReference")
	_check(player != null, "preview contains the real idle-frame player reference")
	if player != null:
		_check(player.position == Vector2(164.0, 113.0), "player reference sits on the 1x ground line")
		_check(player.scale == Vector2.ONE, "player reference is shown at 1:1")
		_check(player.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"player reference uses nearest filtering")
		var atlas: AtlasTexture = player.texture as AtlasTexture
		_check(atlas != null, "player reference uses the original idle sheet via AtlasTexture")
		if atlas != null:
			_check(atlas.region == Rect2(41.0, 43.0, 32.0, 37.0),
				"player idle frame is the real 32x37 visible crop")

	var labels: Array[Label] = []
	_collect_labels(preview, labels)
	var joined: String = ""
	var non_ascii_labels: int = 0
	for label: Label in labels:
		joined += label.text + "\n"
		if _has_non_ascii(label.text):
			non_ascii_labels += 1
	_check(non_ascii_labels == 0, "all preview labels are ASCII-only", str(labels.size()))
	_check(labels.size() >= 20, "preview has title, scale, layer, and footer labels", str(labels.size()))
	_check(joined.contains("STAR CORE BAY VISUAL PREVIEW"), "preview has a title")
	_check(joined.contains("VISUAL PREVIEW ONLY") and joined.contains("NOT GAMEPLAY"),
		"preview clearly says it is not gameplay")
	_check(joined.contains("ACTUAL SIZE (1x)"), "preview labels the true 1x row")
	_check(joined.contains("NEAR VIEW (4x"), "preview labels the 4x near view")
	_check(joined.contains("EMPTY 1x") and joined.contains("OCCUPIED 1x"),
		"preview labels empty and occupied at 1x")
	_check(joined.contains("32x32 EMPTY / 4x") and joined.contains("32x32 OCCUPIED / 4x"),
		"preview labels empty and occupied at 4x")
	_check(joined.contains("PLAYER IDLE 1:1") and joined.contains("32x37 PX"),
		"preview labels the true-scale player reference")
	_check(joined.contains("LAYER ORDER") and joined.contains("BASE / REAR")
		and joined.contains("GLASS / FRONT") and joined.contains("LOCK MARK"),
		"preview names the layer order and code-drawn lock mark")
	_check(joined.contains("ART STATUS:"), "preview shows art readiness status")
	_check(joined.contains("base 32x32 + glass 32x32 + core 16x16 loaded"),
		"preview reports all bay art loaded")
	_check(joined.contains("NO PHYSICS, COLLISION, SUCTION, INTERACTION, OR BAY LOGIC"),
		"preview lists excluded systems")
	_check(joined.contains("FIRST-PASS LOOK DEV") and joined.contains("PENDING USER VISUAL FEEDBACK"),
		"preview marks the asset as a pending first-pass, not final art")

	preview.queue_free()
	await get_tree().process_frame


func _load_rgba(path: String) -> Image:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var texture: Texture2D = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _alpha_at(image: Image, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return 0
	return int(round(image.get_pixel(x, y).a * 255.0))


func _count_physics_nodes(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is Area2D:
			count += 1
		count += _count_physics_nodes(child)
	return count


func _collect_bays(node: Node, out: Array[StarCoreBayVisual]) -> void:
	for child: Node in node.get_children():
		if child is StarCoreBayVisual:
			out.append(child as StarCoreBayVisual)
		_collect_bays(child, out)


func _collect_labels(node: Node, out: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			out.append(child as Label)
		_collect_labels(child, out)


func _find_sprite(node: Node, desired_name: String) -> Sprite2D:
	for child: Node in node.get_children():
		if child is Sprite2D and String(child.name) == desired_name:
			return child as Sprite2D
		var found: Sprite2D = _find_sprite(child, desired_name)
		if found != null:
			return found
	return null


func _has_non_ascii(text: String) -> bool:
	for index: int in text.length():
		if text.unicode_at(index) > 126:
			return true
	return false


func _wait_for_lid_state(bay: StarCoreBayVisual, open: bool) -> void:
	# Timing-independent: the engine may deliver a zero/first-frame delta under
	# headless load, so wait for the real animated state instead of a fixed
	# frame count. The animation itself is still driven by _process.
	for i: int in range(30):
		if open and bay.is_lid_open():
			return
		if not open and bay.is_lid_closed():
			return
		await get_tree().process_frame


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, "" if detail.is_empty() else " | " + detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, "" if detail.is_empty() else " | " + detail])


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
		"res://tests/logs/star_core_bay_visual_test.log",
		FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("STAR_CORE_BAY_VISUAL_TEST_RESULT pass=%d fail=%d skipped=%d" % [
		_pass_count,
		_fail_count,
		_skip_count,
	])
	get_tree().quit(1 if _fail_count > 0 else 0)
