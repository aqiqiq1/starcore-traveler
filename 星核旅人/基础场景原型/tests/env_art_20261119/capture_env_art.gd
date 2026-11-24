extends Node

## 2026-11-19 environment-art before/after capture.
##
## Run (windowed, NOT headless, so the real renderer produces pixels):
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://tests/env_art_20261119/capture_env_art.tscn -- --tag before
##
## Stations are the formal level scenes in real gameplay states. For each
## station two 640x360 frames are written:
##   <id>_full.png   normal composition (HUD hidden only)
##   <id>_clean.png  animated actors hidden, background clock frozen at t=4.0
## The clean frame is the deterministic before/after pixel-diff source; the full
## frame is for reading the normal composition.
##
## Test-only setup uses existing debug entry points (L3 gate setup) and direct
## node placement. No collision, layout, dialogue, camera limit or gameplay
## value is modified.

const LEVEL1_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LEVEL3_SCENE: PackedScene = preload("res://scenes/level_03.tscn")

const OUT_ROOT: String = "res://tests/env_art_20261119"
const BG_TIME: float = 4.0
const FRAME_SIZE: Vector2i = Vector2i(640, 360)
const DS03_SCENE: PackedScene = preload("res://scenes/backgrounds/cloud_ruins_ds03.tscn")
const TIP_IDS: Array[String] = [
	"polarity", "core_carry", "relay_link", "float_platform", "guard_field",
]

var _tag: String = "before"
var _log_lines: Array[String] = []
var _fails: Array[String] = []
var _current_level: Node = null
var _skip_l1: bool = false
var _baseline: bool = false
var _station_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_parse_args()
	_ensure_dir("%s/%s" % [OUT_ROOT, _tag])
	# Teaching popups are unrelated to the environment; mark them seen for the
	# capture run only (same approach as tests/mechanic_popup_20261119).
	for id: String in TIP_IDS:
		MechanicTips.mark_seen(id)
	_log("tag=%s viewport=%s window=%s" % [
		_tag, str(get_viewport().size), str(get_window().size)
	])

	if not _skip_l1:
		await _capture_l1_start()
		await _capture_l1_high()
	await _capture_l2_start()
	await _capture_l2_clearance()
	await _capture_l2_lowcorridor()
	await _capture_l2_linked()
	await _capture_l3_start()
	await _capture_l3_gate()
	await _capture_ds03_default()

	_write_log()
	print("ENV_ART_CAPTURE_RESULT fail=%d" % _fails.size())
	for failure: String in _fails:
		print("CAPTURE FAIL: ", failure)
	if _fails.is_empty():
		print("ENV_ART_CAPTURE_OK")
	get_tree().quit(0 if _fails.is_empty() else 1)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg == "--skip-l1":
			_skip_l1 = true
		elif arg == "--baseline":
			_baseline = true
		elif arg == "--tag":
			continue
	# Also accept "--tag before" (two tokens).
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--tag":
			_tag = args[i + 1]
	if _tag.is_empty():
		_tag = "before"


# --- stations -------------------------------------------------------------

func _capture_l1_start() -> void:
	var level: Node = await _open_level(LEVEL1_SCENE, true)
	await _place_player(level, Vector2(-60.0, 300.0))
	await _capture_station("l1_start", level, ["World/GuideEchoMeeting",
		"World/GuideEchoHighstep", "World/RuneStoneHigh", "World/RuneStonePit",
		"World/Checkpoint", "World/Exit", "World/Guide"])
	await _free_level(level)


func _capture_l1_high() -> void:
	var level: Node = await _open_level(LEVEL1_SCENE, true)
	await _place_player(level, Vector2(960.0, 220.0))
	await _capture_station("l1_high", level, ["World/GuideEchoMeeting",
		"World/GuideEchoHighstep", "World/RuneStoneHigh", "World/RuneStonePit",
		"World/Checkpoint", "World/Exit", "World/Guide"])
	await _free_level(level)


func _capture_l2_start() -> void:
	var level: Node = await _open_level(LEVEL2_SCENE, true)
	await _place_player(level, Vector2(140.0, 320.0))
	await _capture_station("l2_start", level, ["Core", "RuneField",
		"PolarityLink", "RelayCheckpoint", "LinkedCheckpoint", "Exit",
		"StartStele"])
	await _free_level(level)


func _capture_l2_clearance() -> void:
	# Presentation-only check that the new edge decoration stays behind the
	# player's feet and the carried core. The core is shown at the first moss
	# tuft (x=32) and the player stands over the x=96 chip; no game rule changes.
	var level: Node = await _open_level(LEVEL2_SCENE, true)
	await _place_player(level, Vector2(96.0, 320.0))
	var core: Node = level.get_node_or_null("Core")
	if core != null and core.has_method("activate_at"):
		core.call("activate_at", Vector2(32.0, 312.0), true)
		var body: CharacterBody2D = core as CharacterBody2D
		if body != null:
			body.velocity = Vector2.ZERO
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	var image: Image = _viewport_image()
	if image != null:
		_save(image, "%s/%s/l2_edge_clearance_full.png" % [OUT_ROOT, _tag])
	_log("station l2_edge_clearance saved")
	await _free_level(level)


func _capture_l2_lowcorridor() -> void:
	var level: Node = await _open_level(LEVEL2_SCENE, true)
	await _place_player(level, Vector2(520.0, 268.0))
	await _capture_station("l2_lowcorridor", level, ["Core", "RuneField",
		"PolarityLink", "RelayCheckpoint", "LinkedCheckpoint", "Exit",
		"StartStele"])
	await _free_level(level)


func _capture_l2_linked() -> void:
	var level: Node = await _open_level(LEVEL2_SCENE, true)
	await _place_player(level, Vector2(1150.0, 240.0))
	await _capture_station("l2_linked", level, ["Core", "RuneField",
		"PolarityLink", "RelayCheckpoint", "LinkedCheckpoint", "Exit",
		"StartStele"])
	await _free_level(level)


func _capture_l3_start() -> void:
	var level: Node = await _open_level(LEVEL3_SCENE, true)
	await _place_player(level, Vector2(60.0, 320.0))
	await _capture_station("l3_start", level, ["Core", "Guard", "FloatRoute",
		"RuneField", "PolarityLink", "BufferCheckpoint", "Cine", "FixedDevice",
		"KeyCorePickup"])
	await _free_level(level)


func _capture_l3_gate() -> void:
	var level: Node = await _open_level(LEVEL3_SCENE, true)
	level.call("debug_setup_gate_with_key", 2260.0)
	await _wait(0.6)
	await _place_player(level, Vector2(2260.0, 320.0))
	await _capture_station("l3_gate", level, ["Core", "Guard", "FloatRoute",
		"RuneField", "PolarityLink", "BufferCheckpoint", "Cine", "FixedDevice",
		"KeyCorePickup"])
	await _free_level(level)


func _capture_ds03_default() -> void:
	# Shared-background default check: the scene with no grade override, exactly
	# as L1 instances it. Captured without a level camera.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var bg: Node = DS03_SCENE.instantiate()
	layer.add_child(bg)
	await _wait(0.4)
	if bg.has_method("set_background_time"):
		bg.call("set_background_time", BG_TIME)
	if bg.has_method("set_clock_paused"):
		bg.call("set_clock_paused", true)
	await _wait(0.2)
	await RenderingServer.frame_post_draw
	var image: Image = _viewport_image()
	if image != null:
		_save(image, "%s/%s/ds03_default.png" % [OUT_ROOT, _tag])
	_log("station ds03_default saved")
	layer.queue_free()
	await get_tree().process_frame


# --- level plumbing -------------------------------------------------------

func _open_level(scene: PackedScene, abort_opening: bool) -> Node:
	var level: Node = scene.instantiate()
	if level is Level01:
		(level as Level01).enable_start_menu = false
	add_child(level)
	_current_level = level
	await _wait(0.5)
	if abort_opening and level.has_method("get_opening"):
		var opening: Node = level.call("get_opening") as Node
		if opening != null and opening.has_method("abort"):
			opening.call("abort")
		await _wait(0.3)
	_hide_hud(level)
	_freeze_background(level)
	if _baseline:
		_apply_baseline(level)
	await _wait(0.2)
	var decor: Node = level.get_node_or_null("EdgeDecor")
	if decor != null:
		var rects: Array = decor.call("get_decor_rects")
		var corridor: Rect2 = Rect2(0, 300, 1792, 20)
		var overlaps: int = 0
		for r: Rect2 in rects:
			# Strict interior overlap: a rect ending exactly at y=300 (the block
			# bottom row) is not inside the corridor.
			if (
				r.position.y < corridor.end.y
				and r.end.y > corridor.position.y
				and r.position.x < corridor.end.x
				and r.end.x > corridor.position.x
			):
				overlaps += 1
		_log("EdgeDecor roof=%s drawn=%d corridor_overlaps=%d" % [
			str(decor.get("roof_rect")), rects.size(), overlaps
		])
		if overlaps != 0:
			_fails.append("EdgeDecor: %d rect(s) enter the 20 px core corridor" % overlaps)
		_log("L2 collision ground=%s roof=%s wall=%s lip=%s return=%s" % [
			_collision_size(level, "TerrainBody"),
			_collision_size(level, "ConductiveRoof"),
			_collision_size(level, "LinkedWall"),
			_collision_size(level, "LinkedLip"),
			_collision_size(level, "ReturnPlatform"),
		])
	return level


func _collision_size(level: Node, body_name: String) -> String:
	var shape: CollisionShape2D = level.get_node_or_null(
		body_name + "/CollisionShape2D"
	) as CollisionShape2D
	if shape == null or shape.shape == null:
		return "missing"
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	if rect == null:
		return "not-rect"
	return str(rect.size)


func _apply_baseline(level: Node) -> void:
	# Reproduce the pre-change presentation from the same files: shared DS03
	# default grade and no L2 edge decoration. Used only for the "before" run.
	var bg: Node = level.get_node_or_null("Background/CloudRuinsDS03")
	if bg != null and bg.has_method("set_depth_grade"):
		bg.call("set_depth_grade", "default")
	var decor: CanvasItem = level.get_node_or_null("EdgeDecor") as CanvasItem
	if decor != null:
		decor.visible = false
	_log("baseline: depth_grade=default, EdgeDecor hidden")


func _hide_hud(level: Node) -> void:
	if level != null and level.has_method("get_hud"):
		var hud: Node = level.call("get_hud") as Node
		if hud != null:
			hud.visible = false


func _freeze_background(level: Node) -> void:
	var bg: Node = level.get_node_or_null("Background/CloudRuinsDS03")
	if bg == null:
		_fails.append("missing Background/CloudRuinsDS03")
		return
	if bg.has_method("set_background_time"):
		bg.call("set_background_time", BG_TIME)
	if bg.has_method("set_clock_paused"):
		bg.call("set_clock_paused", true)
	_log("background frozen t=%.2f" % BG_TIME)


func _place_player(level: Node, position: Vector2) -> void:
	_station_position = position
	var player: Node = level.call("get_player") as Node if level.has_method("get_player") else null
	if player == null:
		_fails.append("level has no get_player() (script failed to load?)")
		return
	player.global_position = position
	if player.has_method("clear_input_buffers"):
		player.call("clear_input_buffers")
	if player.has_method("clear_external_force"):
		player.call("clear_external_force")
	var body: CharacterBody2D = player as CharacterBody2D
	if body != null:
		body.velocity = Vector2.ZERO
	var camera: Camera2D = null
	if level.has_method("get_camera"):
		camera = level.call("get_camera") as Camera2D
	if camera == null:
		camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
	await _wait(0.4)
	# Re-apply after the settle wait so gravity/animation cannot drift the
	# station. A grounded player keeps the same integer position.
	player.global_position = position
	if body != null:
		body.velocity = Vector2.ZERO
	if camera != null:
		camera.reset_smoothing()
	await _wait(0.25)


func _capture_station(id: String, level: Node, clean_hide: Array) -> void:
	await RenderingServer.frame_post_draw
	var full: Image = _viewport_image()
	if full != null:
		_save(full, "%s/%s/%s_full.png" % [OUT_ROOT, _tag, id])
	# Clean frame: freeze every animated actor and the player's own visuals,
	# keeping the Camera2D (child of Player) alive.
	var player: Node = level.call("get_player") as Node if level.has_method("get_player") else null
	if player != null:
		for child_name: String in ["VisualRoot", "PolarityBadge", "DebugOverlay"]:
			var child: CanvasItem = player.get_node_or_null(child_name) as CanvasItem
			if child != null:
				child.visible = false
	for path: String in clean_hide:
		var node: CanvasItem = level.get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = false
	# Stored/inspect cores and rune glows animate inside structural nodes; hide
	# them by class so the clean frame contains only the environment.
	for node: Node in level.find_children("*", "StarCoreVisual", true, false):
		(node as CanvasItem).visible = false
	for child: Node in level.get_children():
		if child is CanvasLayer and child.name != "Background":
			(child as CanvasLayer).visible = false
	# Freeze physics before the clean frame so before/after runs capture the
	# exact same camera position (no gravity settle or smoothing drift). The
	# level root runs ALWAYS for gameplay; make it pausable for this frame so a
	# re-showing pickup/glow cannot re-appear between hide and capture.
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	var camera: Camera2D = null
	if level.has_method("get_camera"):
		camera = level.call("get_camera") as Camera2D
	if camera == null and player != null:
		camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		# Use the station's authored integer position, not whatever sub-pixel
		# value the last physics frame settled on. force_update_scroll applies
		# the level limits, so 0..1792 and 0..360 stay intact.
		camera.position_smoothing_enabled = false
		camera.global_position = _station_position
		camera.force_update_scroll()
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var clean: Image = _viewport_image()
	if clean != null:
		_save(clean, "%s/%s/%s_clean.png" % [OUT_ROOT, _tag, id])
	get_tree().paused = false
	_log("station %s saved full+clean" % id)


func _viewport_image() -> Image:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fails.append("empty viewport image")
		return null
	if image.get_size() != FRAME_SIZE:
		image.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_NEAREST)
	return image


func _save(image: Image, path: String) -> void:
	var error: Error = image.save_png(path)
	if error != OK:
		_fails.append("save_png failed %d for %s" % [int(error), path])


func _free_level(level: Node) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	_current_level = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _wait(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(ceil(seconds * 1000.0))
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _log(line: String) -> void:
	_log_lines.append(line)
	print("CAPTURE ", line)


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("%s/capture_%s.log" % [OUT_ROOT, _tag], FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_log_lines) + "\n")
	file.close()
