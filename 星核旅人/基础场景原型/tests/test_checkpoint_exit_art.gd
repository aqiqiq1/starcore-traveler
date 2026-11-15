extends Node

## Focused acceptance checks for the approved checkpoint/exit art in level 01.
## Verifies the four byte-identical runtime copies, their native sizes and foot
## anchors, the transparent exit opening, and the two visual states wired to the
## existing gameplay nodes without changing triggers or positions.
## HASHES track the 2026-11-02 warm-stone revision; per-pixel palette fidelity is
## checked offline by tests/verify_checkpoint_exit_stone_palette.py.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const ASSET_DIR: String = "res://assets/checkpoint_exit"

const CHECKPOINT_INACTIVE: String = ASSET_DIR + "/checkpoint_inactive.png"
const CHECKPOINT_ACTIVE: String = ASSET_DIR + "/checkpoint_active.png"
const EXIT_OPEN: String = ASSET_DIR + "/exit_open.png"
const EXIT_COMPLETED: String = ASSET_DIR + "/exit_completed.png"

const HASHES: Dictionary = {
	CHECKPOINT_INACTIVE: "f6aedc7225fab5ebf6403dde666cb2b8f198199fc1c9bda2d59eef4d118646c6",
	CHECKPOINT_ACTIVE: "cba0c92bf76b911d4b96ae48de141f71c3c80bb13379df14814e3ed3a30cb99d",
	EXIT_OPEN: "9ce2857344474de877894384cc1fca2cee7b642ba3d58d7db560b6abd0ea8c16",
	EXIT_COMPLETED: "647325f7d0f6f9dabcac2be38b35035fc3a1e833de0f95523a1e3c19fc42e7db",
}
const SIZES: Dictionary = {
	CHECKPOINT_INACTIVE: Vector2i(40, 36),
	CHECKPOINT_ACTIVE: Vector2i(40, 36),
	EXIT_OPEN: Vector2i(76, 100),
	EXIT_COMPLETED: Vector2i(76, 100),
}
const ALPHA_BOUNDS: Dictionary = {
	CHECKPOINT_INACTIVE: Rect2i(3, 10, 35, 25),
	CHECKPOINT_ACTIVE: Rect2i(3, 5, 35, 30),
	EXIT_OPEN: Rect2i(4, 7, 67, 92),
	EXIT_COMPLETED: Rect2i(4, 3, 67, 96),
}

var _level: Level01
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []
var _log_path: String = "res://tests/logs/checkpoint_exit_art_%s.log" % (
	Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - checkpoint / exit art acceptance")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	_test_runtime_copies()
	await _test_level_wiring_and_states()
	_finish()


func _test_runtime_copies() -> void:
	_section("RUNTIME COPIES / SIZE / ANCHOR / TRANSPARENT OPENING")
	for path: String in HASHES.keys():
		var expected_hash: String = String(HASHES[path])
		var expected_size: Vector2i = SIZES[path]
		var expected_bounds: Rect2i = ALPHA_BOUNDS[path]
		_check(FileAccess.file_exists(path), "runtime PNG exists: " + path.get_file())
		if not FileAccess.file_exists(path):
			continue
		_check(_sha256(path) == expected_hash, "runtime PNG is byte-identical to the approved copy: " + path.get_file(), _sha256(path))

		var texture: Texture2D = load(path) as Texture2D
		_check(texture != null, "PNG imports as a texture: " + path.get_file())
		if texture == null:
			continue
		_check(texture.get_width() == expected_size.x and texture.get_height() == expected_size.y, "imported texture keeps native size: " + path.get_file(), "%dx%d" % [texture.get_width(), texture.get_height()])

		var file_image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(file_image != null and not file_image.is_empty(), "PNG decodes outside import: " + path.get_file())
		if file_image == null or file_image.is_empty():
			continue
		_check(file_image.get_size() == expected_size, "decoded PNG keeps native size: " + path.get_file(), str(file_image.get_size()))
		_check(_alpha_bbox(file_image) == expected_bounds, "alpha silhouette matches the approved art: " + path.get_file(), str(_alpha_bbox(file_image)))

		var imported: Image = texture.get_image()
		if imported == null or imported.is_empty():
			_check(false, "imported texture exposes pixels: " + path.get_file())
			continue
		imported.convert(Image.FORMAT_RGBA8)
		file_image.convert(Image.FORMAT_RGBA8)
		_check(imported.get_data() == file_image.get_data(), "imported pixels are untouched: " + path.get_file())

	# The foot anchor is the bottom edge of the last opaque row, not the canvas
	# height. This catches the classic 1 px float caused by using 36/100.
	var checkpoint_anchor: Vector2 = LevelCheckpoint.TEXTURE_FOOT_ANCHOR
	var exit_anchor: Vector2 = LevelExit.TEXTURE_FOOT_ANCHOR
	_check(checkpoint_anchor == Vector2(20.0, 35.0), "checkpoint foot anchor is (20,35)", str(checkpoint_anchor))
	_check(exit_anchor == Vector2(38.0, 99.0), "exit foot anchor is (38,99)", str(exit_anchor))
	_check(int(checkpoint_anchor.y) == ALPHA_BOUNDS[CHECKPOINT_INACTIVE].end.y, "checkpoint anchor sits on the last opaque row edge")
	_check(int(exit_anchor.y) == ALPHA_BOUNDS[EXIT_OPEN].end.y, "exit anchor sits on the last opaque row edge")

	# The gate opening must stay pure alpha zero in both approved states.
	for path: String in [EXIT_OPEN, EXIT_COMPLETED]:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			_check(false, "exit image decodes for opening check: " + path.get_file())
			continue
		image.convert(Image.FORMAT_RGBA8)
		var opening_transparent: bool = true
		for y: int in range(35, 92):
			for x: int in range(30, 50):
				if image.get_pixel(x, y).a > 0.0:
					opening_transparent = false
					break
			if not opening_transparent:
				break
		_check(opening_transparent, "exit opening is transparent in " + path.get_file())
		_check(image.get_pixel(12, 60).a > 0.0 and image.get_pixel(60, 60).a > 0.0, "exit keeps opaque side masonry in " + path.get_file())


func _test_level_wiring_and_states() -> void:
	_section("LEVEL 01 WIRING / TWO STATES / R RESET")
	await _new_level()
	if _level == null:
		_check(false, "level scene instantiates")
		return

	var checkpoint: LevelCheckpoint = _level.get_checkpoint()
	var exit_gate: LevelExit = _level.get_exit()
	_check(checkpoint != null and exit_gate != null, "checkpoint and exit remain authored scene nodes")
	if checkpoint == null or exit_gate == null:
		return

	# Position, trigger and collision shape are the existing gameplay source.
	_check(checkpoint.global_position == Vector2(1120.0, 220.0), "checkpoint position is unchanged", str(checkpoint.global_position))
	_check(exit_gate.global_position == Vector2(1840.0, 300.0), "exit position is unchanged", str(exit_gate.global_position))
	_check(checkpoint.get_trigger_rect().size == Vector2(40.0, 72.0), "checkpoint trigger size is unchanged")
	_check(exit_gate.get_trigger_rect().size == Vector2(36.0, 76.0), "exit trigger size is unchanged")
	_check(checkpoint.z_index == 2 and exit_gate.z_index == 3, "existing draw order is unchanged")
	_check(exit_gate.label_text == "出口", "existing Chinese exit label is preserved", exit_gate.label_text)

	var checkpoint_shape: CollisionShape2D = checkpoint.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var exit_shape: CollisionShape2D = exit_gate.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check(checkpoint_shape != null and checkpoint_shape.position == Vector2(0.0, -36.0), "checkpoint collision shape offset is unchanged")
	_check(exit_shape != null and exit_shape.position == Vector2(0.0, -38.0), "exit collision shape offset is unchanged")

	var scripts_are_tools: bool = true
	var checkpoint_script: Script = checkpoint.get_script() as Script
	var exit_script: Script = exit_gate.get_script() as Script
	if checkpoint_script == null or exit_script == null or not checkpoint_script.is_tool() or not exit_script.is_tool():
		scripts_are_tools = false
	_check(scripts_are_tools, "@tool keeps both props visible in the editor")

	# Native-size display rect: white modulate, 1:1, foot contact at y=0.
	_check(checkpoint.get_state_texture().resource_path == CHECKPOINT_INACTIVE, "checkpoint starts on the inactive art", checkpoint.get_state_texture().resource_path)
	_check(exit_gate.get_state_texture().resource_path == EXIT_OPEN, "exit starts on the open art", exit_gate.get_state_texture().resource_path)
	_check(checkpoint.get_display_rect() == Rect2(Vector2(-20.0, -35.0), Vector2(40.0, 36.0)), "checkpoint is drawn 1:1 from its foot anchor", str(checkpoint.get_display_rect()))
	_check(exit_gate.get_display_rect() == Rect2(Vector2(-38.0, -99.0), Vector2(76.0, 100.0)), "exit is drawn 1:1 from its foot anchor", str(exit_gate.get_display_rect()))
	_check(checkpoint.get_display_rect().position.y + 35.0 == 0.0 and exit_gate.get_display_rect().position.y + 99.0 == 0.0, "both visible bottoms sit on the feet line, not 1 px above")
	_check(checkpoint.get_display_rect().end.y == 1.0 and exit_gate.get_display_rect().end.y == 1.0, "the transparent canvas row overhangs 1 px below the feet, as authored")
	_check(checkpoint.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "checkpoint uses Nearest filtering")
	_check(exit_gate.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "exit uses Nearest filtering")
	_check(checkpoint.modulate == Color.WHITE and exit_gate.modulate == Color.WHITE, "both props use white modulate")

	checkpoint.set_activated(true)
	_check(checkpoint.is_activated() and checkpoint.get_state_texture().resource_path == CHECKPOINT_ACTIVE, "checkpoint activation swaps to the active art")
	checkpoint.set_activated(false)
	_check(not checkpoint.is_activated() and checkpoint.get_state_texture().resource_path == CHECKPOINT_INACTIVE, "clearing the checkpoint restores the inactive art")

	exit_gate.set_completed(true)
	await _physics(2)
	_check(exit_gate.is_completed() and exit_gate.get_state_texture().resource_path == EXIT_COMPLETED, "exit completion swaps to the gold art")
	_check(not exit_gate.monitoring, "completed exit still disables its trigger")
	exit_gate.set_completed(false)
	await _physics(2)
	_check(not exit_gate.is_completed() and exit_gate.get_state_texture().resource_path == EXIT_OPEN, "clearing completion restores the open art")
	_check(exit_gate.monitoring, "reopened exit still enables its trigger")

	# R must restore both visual states along with the existing gameplay state.
	checkpoint.set_activated(true)
	exit_gate.set_completed(true)
	await _physics(2)
	_level._restart_level()
	await _physics(4)
	_check(not _level.is_completed() and not _level.get_hud().is_completion_visible(), "R clears the level completion panel")
	_check(not checkpoint.is_activated() and checkpoint.get_state_texture().resource_path == CHECKPOINT_INACTIVE, "R restores the inactive checkpoint art")
	_check(not exit_gate.is_completed() and exit_gate.get_state_texture().resource_path == EXIT_OPEN, "R restores the open exit art")

	# A fresh scene entry must start from the same authored pair of states.
	await _new_level()
	checkpoint = _level.get_checkpoint()
	exit_gate = _level.get_exit()
	_check(checkpoint != null and not checkpoint.is_activated() and checkpoint.get_state_texture().resource_path == CHECKPOINT_INACTIVE, "scene re-entry starts with the inactive checkpoint art")
	_check(exit_gate != null and not exit_gate.is_completed() and exit_gate.get_state_texture().resource_path == EXIT_OPEN, "scene re-entry starts with the open exit art")


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


func _alpha_bbox(image: Image) -> Rect2i:
	var left: int = image.get_width()
	var top: int = image.get_height()
	var right: int = -1
	var bottom: int = -1
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	if right < left or bottom < top:
		return Rect2i()
	return Rect2i(left, top, right - left + 1, bottom - top + 1)


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
	var file: FileAccess = FileAccess.open(_log_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log_lines) + "\n")
		file.close()
		print("LOG_FILE %s" % _log_path)
	get_tree().quit(0 if _fail_count == 0 else 1)
