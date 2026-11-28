extends Node

## 640x360 evidence for the L3 fixed device: the stone device alone, idle and
## active.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://scripts/level03/tests/capture_fixed_device.tscn

const OUT_DIR: String = "res://screenshots/l3_device_20261128"


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	get_tree().quit(0)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	print("SHOT %s size=%dx%d error=%d" % [name, image.get_width(), image.get_height(), error])


func _run() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.11, 0.13, 0.15, 1.0)
	background.size = Vector2(640.0, 360.0)
	add_child(background)
	var device: L3FixedDevice = L3FixedDevice.new()
	device.position = Vector2(312.0, 236.0)
	add_child(device)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("01_device_idle.png")
	device.activate()
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("02_device_active.png")
	print("DEVICE_STATE active=%s" % str(device.is_active()))
