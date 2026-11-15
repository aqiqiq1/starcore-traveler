extends Node

## Focused z-order check for the level-02 HighStep facade.
##
## Background: with player z=5 and the HighStep V3 slices at z=0, a player
## standing in the 32 px gap under the 14 px step drew hair above the real
## stone front edge. The fix is only the two HighStep slices: z_index=6, above
## the player, so the true stone occludes hair at y274..287 while the body above
## the top remains fully visible.
##
## This script performs exactly one GUI load and two render states:
##   - under the step: re-capture only screenshots/art_guide_pass_03_...png;
##   - on top of the step: compare visible vs hidden slices in memory only,
##     no extra screenshot files.
## It freezes the tree for pixel comparisons so the animated background does
## not create false differences.
##
## Run:
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/check_art_guide_pass_highstep_z.tscn

const LEVEL02: PackedScene = preload("res://scenes/level_02.tscn")
const LOG_PATH: String = "res://tests/logs/art_guide_pass_highstep_z_order_20261112.log"
const SHOT_PATH: String = "res://screenshots/art_guide_pass_03_level02_under_highstep.png"

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("HighStep z-order focused check - 2026-11-12")
	_log("Godot: %s" % Engine.get_version_info()["string"])
	_log("One GUI load, two render states. Only the existing 03 screenshot is re-captured.")
	_log("This does not replay test_art_guide_pass (147-check pre-fix run).")

	var level: Level02 = LEVEL02.instantiate() as Level02
	add_child(level)
	await _physics_frames(12)
	var high_step: Level02Block = level.get_node("HighStep") as Level02Block
	var visual: Sprite2D = level.get_node("HighStep/V3PlatformVisual") as Sprite2D
	var decor: Sprite2D = level.get_node("HighStep/V3PlatformDecor") as Sprite2D
	var player: PrototypePlayer = level.get_player()
	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D") as CollisionShape2D
	var collision: RectangleShape2D = player_shape.shape as RectangleShape2D

	_section("attributes")
	_check(high_step.position == Vector2(152, 274) and high_step.block_size == Vector2(56, 14),
		"HighStep position/size unchanged (56x14, bottom 288)")
	_check(visual != null and decor != null, "both HighStep V3 slices exist")
	_check(visual.z_index == 6 and decor.z_index == 6,
		"only HighStep visual/decor are raised to z=6 (got %d / %d)"
		% [visual.z_index, decor.z_index])
	_check(visual.position == Vector2.ZERO and decor.position == Vector2.ZERO,
		"HighStep slices keep local position (0,0)")
	_check(visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and decor.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"HighStep slices keep Nearest filtering")
	_check(visual.scale == Vector2.ONE and decor.scale == Vector2.ONE
		and visual.modulate == Color.WHITE and decor.modulate == Color.WHITE,
		"HighStep slices keep scale 1 / white modulate")
	_check(player.z_index == 5, "player stays at z=5")
	_check(player.scale == Vector2.ONE, "player scale remains 1")
	_check(collision != null and collision.size == Vector2(12, 30),
		"player collision remains 12x30")
	var main_visual: Sprite2D = level.get_node("UpperDeck/V3PlatformVisual") as Sprite2D
	var right_visual: Sprite2D = level.get_node("RightLedge/V3PlatformVisual") as Sprite2D
	_check(main_visual.z_index == 0 and right_visual.z_index == 0,
		"main bridge and RightLedge slices keep their z-order")
	var guard = level.get_guard()
	_check(guard != null and guard.z_index == 3, "guard root z-order unchanged (z=3)")

	_section("under HighStep render")
	player.global_position = Vector2(180, 320)
	player.velocity = Vector2.ZERO
	await _physics_frames(18)
	_check(absf(player.global_position.y - 320.0) <= 0.5,
		"under-step player stands on ground y=320 (got %.2f)" % player.global_position.y)
	await _capture_to_path(SHOT_PATH)
	_log("RE-CAPTURED only %s" % SHOT_PATH)

	get_tree().paused = true
	await get_tree().process_frame
	var under_visible: Image = await _grab()
	visual.visible = false
	decor.visible = false
	await _redraw()
	var under_hidden: Image = await _grab()
	visual.visible = true
	decor.visible = true
	await _redraw()
	get_tree().paused = false

	var hair_diff: int = _diff_count(under_visible, under_hidden, Rect2i(160, 284, 40, 4))
	var below_diff: int = _diff_count(under_visible, under_hidden, Rect2i(160, 289, 40, 12))
	_check(hair_diff > 0,
		"front stone occludes hair at y284..287 (changed pixels=%d)" % hair_diff)
	_check(below_diff == 0,
		"no extra facade occludes the player below y288 (changed pixels=%d)" % below_diff)

	_section("on-top HighStep render")
	player.global_position = Vector2(180, 274)
	player.velocity = Vector2.ZERO
	await _physics_frames(20)
	_check(absf(player.global_position.y - 274.0) <= 0.5,
		"on-top player feet stay at step top y=274 (got %.2f)" % player.global_position.y)
	_check(player.is_on_floor(), "on-top player remains grounded on the step")
	get_tree().paused = true
	await get_tree().process_frame
	var top_visible: Image = await _grab()
	visual.visible = false
	decor.visible = false
	await _redraw()
	var top_hidden: Image = await _grab()
	visual.visible = true
	decor.visible = true
	await _redraw()
	get_tree().paused = false

	var body_diff: int = _diff_count(top_visible, top_hidden, Rect2i(160, 238, 40, 36))
	_check(body_diff == 0,
		"platform front edge does not cover the body above y=274 (changed pixels=%d)" % body_diff)
	# The 1 px sole overlap is the intended front-edge relationship, not a body
	# occlusion; it is documented rather than treated as a failure.
	var foot_diff: int = _diff_count(top_visible, top_hidden, Rect2i(160, 274, 40, 2))
	_log("foot/sole overlap pixels at y274..275: %d (expected small; body above y274 unchanged)" % foot_diff)

	level.queue_free()
	await _process_frames(3)
	_write_log()
	print("HIGHSTEP_Z_SUMMARY pass=%d fail=%d" % [_pass, _fail])
	print("RESULT: " + ("PASS" if _fail == 0 else "FAIL"))
	get_tree().quit(0 if _fail == 0 else 1)


func _capture_to_path(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_check(false, "failed to save %s error=%d" % [path, error])
	else:
		_log("CAPTURED %s size=%s" % [path, str(image.get_size())])


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _redraw() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _diff_count(a: Image, b: Image, rect: Rect2i) -> int:
	var count: int = 0
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count


func _process_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _section(title: String) -> void:
	_log("")
	_log("--- %s ---" % title)


func _check(condition: bool, label: String) -> void:
	if condition:
		_pass += 1
		_log("PASS  " + label)
	else:
		_fail += 1
		_log("FAIL  " + label)
		print("FAIL  " + label)


func _log(line: String) -> void:
	_lines.append(line)
	print(line)


func _write_log() -> void:
	_lines.append("")
	_lines.append("HIGHSTEP_Z_SUMMARY pass=%d fail=%d" % [_pass, _fail])
	_lines.append("RESULT: " + ("PASS" if _fail == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % LOG_PATH)
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
