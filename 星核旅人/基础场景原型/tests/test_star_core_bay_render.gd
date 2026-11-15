extends Node

## GUI render check for the star-core bay preview. This exists because a
## pure-headless node/PNG test cannot catch the white pedestal being hidden
## behind a Control background.
##
## Run non-headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tests/test_star_core_bay_render.tscn
##
## It instantiates the real preview, captures the actual viewport, and samples
## the pedestal body/foot in the 4x occupied bay. It does not save a screenshot;
## the preview's --capture-preview path does that and runs the same pixel check.

const PREVIEW_SCENE: PackedScene = preload("res://tools/preview_star_core_bay.tscn")
const CAPTURE_SIZE: Vector2i = Vector2i(640, 360)

var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_log("Star Core Traveler - GUI render check for star-core bay preview")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	if DisplayServer.get_name() == "headless":
		_log("RENDER_TEST_REQUIRES_GUI this test must run with a real display; no pixel claim is made.")
		_write_log()
		print("STAR_CORE_BAY_RENDER_RESULT ok=false reason=headless")
		get_tree().quit(2)
		return

	DisplayServer.window_set_size(CAPTURE_SIZE)
	var preview: Control = PREVIEW_SCENE.instantiate() as Control
	add_child(preview)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		_log("RENDER_CAPTURE_FAILED viewport image is null")
		_write_log()
		print("STAR_CORE_BAY_RENDER_RESULT ok=false reason=null_image")
		get_tree().quit(1)
		return
	if image.get_size() != CAPTURE_SIZE:
		_log("RENDER_CAPTURE_NOTE viewport image %s resized to %s" % [
			str(image.get_size()), str(CAPTURE_SIZE)
		])
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)

	var result: Dictionary = StarCoreBayPreview.check_rendered_base(image)
	_log_pixel_result("normal", result)

	# Negative control: hide only the 4x occupied bay's Base sprite. The same
	# pixel check must then fail. This proves the check observes the white
	# pedestal and cannot pass merely because the glass/core/lock are present.
	var occupied_4x: StarCoreBayVisual = _find_bay(preview, "Occupied_4x")
	if occupied_4x == null or occupied_4x.get_base_sprite() == null:
		_log("negative control failed: Occupied_4x or its Base is missing")
		_write_log()
		print("STAR_CORE_BAY_RENDER_RESULT ok=false reason=missing_occupied_4x")
		get_tree().quit(1)
		return

	occupied_4x.get_base_sprite().visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var negative_image: Image = get_viewport().get_texture().get_image()
	if negative_image.get_size() != CAPTURE_SIZE:
		negative_image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	var negative_result: Dictionary = StarCoreBayPreview.check_rendered_base(negative_image)
	_log_pixel_result("base_hidden_control", negative_result)
	occupied_4x.get_base_sprite().visible = true

	var negative_ok: bool = (
		not bool(negative_result.get("ok", true))
		and int(negative_result.get("white_pixels", 99999)) < int(result.get("white_pixels", 0))
	)
	_log("negative control expected failure: %s" % ("OK" if negative_ok else "FAILED"))
	_log("regions: base=%s background=%s" % [
		str(result.get("base_rect")), str(result.get("background_rect"))
	])
	_write_log()
	var overall_ok: bool = bool(result.get("ok", false)) and negative_ok
	print(
		"STAR_CORE_BAY_RENDER_RESULT ok=%s white=%d negative_white=%d base_mean=%.3f background_mean=%.3f"
		% [
			str(overall_ok),
			int(result.get("white_pixels", 0)),
			int(negative_result.get("white_pixels", 0)),
			float(result.get("base_mean", 0.0)),
			float(result.get("background_mean", 0.0)),
		]
	)
	get_tree().quit(0 if overall_ok else 1)


func _log_pixel_result(label: String, result: Dictionary) -> void:
	_log(
		"%s: white=%d/%d base_pixels=%d base_mean=%.3f background_mean=%.3f ok=%s"
		% [
			label,
			int(result.get("white_pixels", 0)),
			int(result.get("white_min", 500)),
			int(result.get("base_pixels", 0)),
			float(result.get("base_mean", 0.0)),
			float(result.get("background_mean", 0.0)),
			str(result.get("ok", false)),
		]
	)


func _find_bay(node: Node, desired_name: String) -> StarCoreBayVisual:
	for child: Node in node.get_children():
		if child is StarCoreBayVisual and String(child.name) == desired_name:
			return child as StarCoreBayVisual
		var found: StarCoreBayVisual = _find_bay(child, desired_name)
		if found != null:
			return found
	return null


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _write_log() -> void:
	var log_directory: String = ProjectSettings.globalize_path("res://tests/logs")
	DirAccess.make_dir_recursive_absolute(log_directory)
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/star_core_bay_render_test.log",
		FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
