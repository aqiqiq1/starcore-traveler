extends Node

## Independent acceptance test for the star-core 12-frame animation.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_star_core_animation.tscn
##
## This test covers the six PNGs, per-frame alpha/position compatibility, the
## runtime loop, pause freeze, state/visibility reset, refresh idempotence, and
## in-bay/out-of-bay display. It does not test gameplay forces, collision, or the
## full interaction room.

const CORE_SCENE: PackedScene = preload("res://scenes/star_core_visual.tscn")
const BAY_SCENE: PackedScene = preload("res://scenes/star_core_bay_visual.tscn")
const KEYFRAME_SCENE: PackedScene = preload("res://tools/preview_star_core_animation.tscn")

const STATIC_PATHS: Array[String] = [
	"res://assets/star_core/star_core_locked.png",
	"res://assets/star_core/star_core_positive.png",
	"res://assets/star_core/star_core_negative.png",
]
const SHEET_PATHS: Array[String] = [
	"res://assets/star_core/star_core_locked_12f.png",
	"res://assets/star_core/star_core_positive_12f.png",
	"res://assets/star_core/star_core_negative_12f.png",
]
const SOURCE_SHEET_SHA256: String = (
	"1a7f8bfcb6f2c770b07002aad2d3419108971e731363297ee424fce975e63f4c"
)
const FRAME_SIZE: Vector2i = Vector2i(16, 16)
const SHEET_SIZE: Vector2i = Vector2i(192, 16)
const FRAME_COUNT: int = 12

var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_log("Star Core Traveler - independent star-core animation test")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	_test_sheet_assets()
	await _test_component_animation()
	await _test_pause_and_reset()
	await _test_state_switch_and_refresh()
	await _test_bay_and_outside_animation()
	await _test_keyframe_preview()
	_finish()


func _test_sheet_assets() -> void:
	_section("12-FRAME SHEETS AND PER-FRAME COMPATIBILITY")
	var images: Array[Image] = []
	for path: String in SHEET_PATHS:
		var image: Image = _load_rgba(path)
		images.append(image)
		_check(image != null, "sheet loads: %s" % path.get_file())
	if images.has(null):
		_skip("sheet pixel comparison deferred because a sheet is missing")
		return

	for index: int in range(images.size()):
		_check(images[index].get_size() == SHEET_SIZE, "%s is 192x16" % SHEET_PATHS[index].get_file())
		_check(images[index].detect_alpha() != Image.ALPHA_NONE, "%s keeps alpha" % SHEET_PATHS[index].get_file())

	var file_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SHEET_PATHS[0])
	var hash_context: HashingContext = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(file_bytes)
	var sheet_hash: String = hash_context.finish().hex_encode()
	_check(
		sheet_hash == SOURCE_SHEET_SHA256,
		"locked 12f sheet is a byte-identical copy of the source sheet",
		sheet_hash
	)

	var static_locked: Image = _load_rgba(STATIC_PATHS[0])
	_check(static_locked != null, "existing 16x16 locked still loads")
	if static_locked != null:
		_check(
			_frame_region(images[0], 0).get_data() == static_locked.get_data(),
			"locked sheet frame 0 matches the existing 16x16 still exactly"
		)

	var reference_alpha: PackedByteArray = _frame_alpha(images[0], 0)
	var alpha_frames_equal: bool = true
	var bboxes_equal: bool = true
	var counts_equal: bool = true
	var per_frame_counts: Array[int] = []
	for frame: int in range(FRAME_COUNT):
		var alpha: PackedByteArray = _frame_alpha(images[0], frame)
		var bbox: Rect2i = _frame_region(images[0], frame).get_used_rect()
		var count: int = _opaque_count(_frame_region(images[0], frame))
		per_frame_counts.append(count)
		for state: int in range(1, images.size()):
			alpha_frames_equal = alpha_frames_equal and alpha == _frame_alpha(images[state], frame)
			bboxes_equal = bboxes_equal and bbox == _frame_region(images[state], frame).get_used_rect()
			counts_equal = counts_equal and count == _opaque_count(_frame_region(images[state], frame))
		_check(count > 0, "frame %02d has visible pixels" % frame)
	_check(alpha_frames_equal, "all 12 frames keep identical alpha across all three states")
	_check(bboxes_equal, "all 12 frames keep identical silhouettes/positions across states")
	_check(counts_equal, "all 12 frames keep identical opaque counts across states")
	_check(
		per_frame_counts == [208, 196, 176, 144, 100, 68, 48, 68, 100, 144, 176, 196],
		"per-frame opaque counts match the source rotation",
		str(per_frame_counts)
	)

	# Rotation is left/right symmetric, so only 7 distinct alpha silhouettes
	# exist (0, 6, and five mirrored pairs); fewer than that means frame 0 was
	# repeated instead of the real sheet being copied.
	var distinct_alpha: Dictionary = {}
	for frame: int in range(FRAME_COUNT):
		distinct_alpha[str(_frame_alpha(images[0], frame))] = true
	_check(distinct_alpha.size() == 7, "sheet contains the real symmetric rotation, not repeated frame 0",
		str(distinct_alpha.size()))


func _test_component_animation() -> void:
	_section("COMPONENT LOOP AND FRAME CONTRACT")
	var core: StarCoreVisual = CORE_SCENE.instantiate() as StarCoreVisual
	add_child(core)
	await get_tree().process_frame

	_check(core.is_using_animated_sheet(), "component uses the 12-frame sheet by default")
	_check(core.get_animation_frame_count() == FRAME_COUNT, "component exposes 12 frames")
	_check(core.get_animation_fps() == 12.0, "default animation speed is 12 FPS")
	_check(core.animate, "animation is enabled by default")
	_check(core.get_animation_frame() == 0, "component starts at frame 0")
	_check(core.get_art_sheet() != null, "full source sheet is exposed separately")
	if core.get_art_sheet() != null:
		_check(Vector2i(core.get_art_sheet().get_size()) == SHEET_SIZE, "source sheet is 192x16")
	var frame_texture: Texture2D = core.get_art_texture()
	_check(frame_texture != null, "current frame texture exists")
	if frame_texture != null:
		_check(Vector2i(frame_texture.get_size()) == FRAME_SIZE, "displayed frame remains 16x16")
	_check(core.get_source_size() == FRAME_SIZE, "legacy source size still reports one 16x16 frame")

	var seen_frames: Array[int] = []
	var all_frames_16: bool = true
	var all_unit_scale: bool = true
	var all_unmirrored: bool = true
	var all_badges_fixed: bool = true
	core.animate = false  # Keep the deterministic loop free of background _process.
	for step: int in range(FRAME_COUNT):
		core.advance_animation(1.0 / 12.0 + 0.0001)  # One whole frame plus epsilon.
		seen_frames.append(core.get_animation_frame())
		var sprite: Sprite2D = core.get_node_or_null("Gem") as Sprite2D
		if sprite != null:
			all_frames_16 = all_frames_16 and Vector2i(sprite.texture.get_size()) == FRAME_SIZE
			all_unit_scale = all_unit_scale and sprite.scale == Vector2.ONE
			all_unmirrored = all_unmirrored and not sprite.flip_h and not sprite.flip_v
		all_badges_fixed = all_badges_fixed and core.get_badge_kind() == &"lock"

	_check(seen_frames == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0],
		"12 updates visit every frame and wrap to 0", str(seen_frames))
	core.reset_animation()
	core.advance_animation(1.0)
	_check(core.get_animation_frame() == 0, "one full second at 12 FPS wraps back to frame 0")
	core.animate = true
	_check(all_frames_16, "no thin frame changes the displayed 16x16 size")
	_check(all_unit_scale, "sprite stays 1:1 through all frames")
	_check(all_unmirrored, "sprite is never mirrored")
	_check(all_badges_fixed, "lock badge stays fixed through the loop")

	core.set_animation_frame(6)
	_check(core.get_animation_frame() == 6, "set_animation_frame selects a fixed frame")
	core.animation_fps = 24.0
	_check(core.animation_fps == 24.0, "animation FPS is exportable/tunable")
	core.advance_animation(0.05)  # 24 FPS: 1.2 frames, wraps once.
	_check(core.get_animation_frame() == 7, "changed FPS affects advance math",
		str(core.get_animation_frame()))
	core.animation_fps = 12.0

	core.queue_free()
	await get_tree().process_frame


func _test_pause_and_reset() -> void:
	_section("PAUSE, RESET, AND REACTIVATION")
	var core: StarCoreVisual = CORE_SCENE.instantiate() as StarCoreVisual
	add_child(core)
	await get_tree().process_frame

	core.set_animation_frame(5)
	core.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	await get_tree().process_frame
	core.advance_animation(1.0)
	_check(core.get_animation_frame() == 5, "pause freezes the current frame")
	get_tree().paused = false
	core.advance_animation(0.09)
	_check(core.get_animation_frame() == 6, "resume continues from the frozen frame")

	core.set_animation_frame(9)
	core.reset_animation()
	_check(core.get_animation_frame() == 0, "reset_animation returns to frame 0")

	core.set_animation_frame(7)
	core.visible = false
	await get_tree().process_frame
	core.visible = true
	await get_tree().process_frame
	_check(core.get_animation_frame() == 0, "becoming visible again restarts at frame 0")

	core.animate = false
	var frozen_frame: int = core.get_animation_frame()
	core._process(1.0)
	_check(core.get_animation_frame() == frozen_frame, "animate=false stops automatic _process advancement")
	core.animate = true

	core.queue_free()
	get_tree().paused = false
	await get_tree().process_frame


func _test_state_switch_and_refresh() -> void:
	_section("STATE SWITCH AND REFRESH COMPATIBILITY")
	var core: StarCoreVisual = CORE_SCENE.instantiate() as StarCoreVisual
	add_child(core)
	await get_tree().process_frame

	var positive_sheet: Texture2D = StarCoreVisual.load_texture_safely(SHEET_PATHS[1])
	core.set_animation_frame(5)
	core.state = StarCoreVisual.CoreState.POSITIVE
	_check(core.get_animation_frame() == 0, "state change resets to frame 0 immediately")
	_check(core.get_art_sheet() == positive_sheet, "state change swaps to the positive sheet")
	var atlas: AtlasTexture = core.get_art_texture() as AtlasTexture
	_check(atlas != null and atlas.region.position.x == 0.0,
		"state change does not leave a stale frame region")

	core.set_animation_frame(4)
	var before_refresh: int = core.get_animation_frame()
	for i: int in range(5):
		core.refresh()
	_check(core.get_animation_frame() == before_refresh,
		"refresh() re-checks art without restarting playback", str(core.get_animation_frame()))
	_check(core.state == StarCoreVisual.CoreState.POSITIVE, "refresh() keeps the current state")

	core.queue_free()
	await get_tree().process_frame


func _test_bay_and_outside_animation() -> void:
	_section("IN-BAY LOCKED AND OUTSIDE DISPLAY")
	var bay: StarCoreBayVisual = BAY_SCENE.instantiate() as StarCoreBayVisual
	add_child(bay)
	await get_tree().process_frame

	var bay_core: StarCoreVisual = bay.get_core_visual()
	_check(bay_core != null and bay_core.visible, "occupied bay shows its purple core")
	_check(bay_core != null and bay_core.state == StarCoreVisual.CoreState.LOCKED,
		"bay core stays in LOCKED state")
	_check(bay_core != null and bay_core.is_using_animated_sheet(), "bay core uses the purple 12-frame sheet")
	if bay_core != null:
		var start_frame: int = bay_core.get_animation_frame()
		bay_core.advance_animation(0.09)
		_check(bay_core.get_animation_frame() != start_frame, "bay core keeps animating while locked")
		_check(bay_core.get_animation_frame() == 1, "bay core advances exactly one frame")
		_check(Vector2i(bay_core.get_art_texture().get_size()) == FRAME_SIZE,
			"bay core frame remains 16x16")
		_check(bay_core.get_badge_kind() == &"lock", "bay core still uses the lock badge kind")
		_check(not bay_core.show_state_badge, "bay keeps the badge hidden")

	var external: StarCoreVisual = CORE_SCENE.instantiate() as StarCoreVisual
	add_child(external)
	await get_tree().process_frame
	external.state = StarCoreVisual.CoreState.NEGATIVE
	var external_start: int = external.get_animation_frame()
	external.advance_animation(0.09)
	_check(external.get_animation_frame() != external_start, "outside negative core animates")
	_check(external.get_badge_kind() == &"minus", "outside negative core keeps its minus badge")

	bay.queue_free()
	external.queue_free()
	await get_tree().process_frame


func _test_keyframe_preview() -> void:
	_section("FIXED-FRAME ENGINE PREVIEW")
	var preview: Control = KEYFRAME_SCENE.instantiate() as Control
	add_child(preview)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(preview != null, "keyframe preview instantiates")
	if preview == null:
		return
	_check(preview.size == Vector2(640.0, 360.0), "keyframe preview is 640x360")
	_check(_count_physics_nodes(preview) == 0, "keyframe preview has no physics nodes")

	var cores: Array[StarCoreVisual] = []
	_collect_cores(preview, cores)
	_check(cores.size() == 12, "preview shows 3 states x 4 set frames", str(cores.size()))

	var states_seen: Dictionary = {}
	var frames_seen: Dictionary = {}
	var all_frozen: bool = true
	var all_16: bool = true
	for core: StarCoreVisual in cores:
		states_seen[int(core.state)] = true
		frames_seen[core.get_animation_frame()] = true
		all_frozen = all_frozen and not core.animate
		all_16 = all_16 and core.get_art_texture() != null \
			and Vector2i(core.get_art_texture().get_size()) == FRAME_SIZE
	_check(states_seen.size() == 3, "preview includes all three states")
	_check(frames_seen.has(0) and frames_seen.has(3) and frames_seen.has(6) and frames_seen.has(9),
		"preview uses fixed frames 0/3/6/9", str(frames_seen.keys()))
	_check(all_frozen, "preview cores are explicitly frozen for the still")
	_check(all_16, "preview cores keep a 16x16 displayed frame")

	var labels: Array[Label] = []
	_collect_labels(preview, labels)
	var joined: String = ""
	for label: Label in labels:
		joined += label.text + "\n"
	_check(joined.contains("NOT CONTINUOUS PLAYBACK"), "preview labels the image as set-frame stills")
	_check(joined.contains("SET FRAMES 0 / 3 / 6 / 9"), "preview names the set frames")
	_check(joined.contains("12 FPS"), "preview names the runtime FPS")
	_check(joined.contains("192x16"), "preview names the sheet size")
	_check(joined.contains("VISUAL PREVIEW ONLY"), "preview is explicitly not gameplay")

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


func _frame_region(sheet: Image, frame: int) -> Image:
	return sheet.get_region(Rect2i(frame * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y))


func _frame_alpha(sheet: Image, frame: int) -> PackedByteArray:
	var region: Image = _frame_region(sheet, frame)
	var alpha: PackedByteArray = PackedByteArray()
	for y: int in range(FRAME_SIZE.y):
		for x: int in range(FRAME_SIZE.x):
			alpha.append(int(round(region.get_pixel(x, y).a * 255.0)))
	return alpha


func _opaque_count(image: Image) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count


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
		"res://tests/logs/star_core_animation_test.log",
		FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("STAR_CORE_ANIMATION_TEST_RESULT pass=%d fail=%d skipped=%d" % [
		_pass_count,
		_fail_count,
		_skip_count,
	])
	get_tree().quit(1 if _fail_count > 0 else 0)
