extends Node

## Real-engine captures for the DS03 background integration. These are scripted
## fixed poses/times, not a claim of manual continuous play.
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_ds03_background.tscn

const BG_SCENE: PackedScene = preload("res://scenes/backgrounds/cloud_ruins_ds03.tscn")
const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const DATA := preload("res://scripts/backgrounds/cloud_ruins_ds03_data.gd")
const CAPTURE_DIR: String = "res://screenshots"
const MANIFEST_PATH: String = "res://screenshots/MANIFEST_DS03_BACKGROUND.txt"
const JSON_MANIFEST_PATH: String = "res://screenshots/ds03_capture_manifest.json"

var _lines: Array[String] = []
var _bg: CloudRuinsDS03
var _level: Level01
var _player: PrototypePlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	if DisplayServer.window_get_size() == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _frames(3)

	_lines.append("Star Core Traveler - DS03 Godot background captures")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s  window: %s  logical viewport: 640x360" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size()),
	])
	_lines.append("All images are actual Godot viewport textures. Poses/times are scripted fixed frames, not manual continuous play.")
	_lines.append("")
	_lines.append("Quantization:")
	_lines.append("  native 640x360 viewport, viewport stretch, project 2D pixel snap on.")
	_lines.append("  G1/G2 are drawn at exact integer DS03 offsets and never move.")
	_lines.append("  G3/G4/G5: 0 on neutral/positive formula lobes; -1 on the web preview's negative half-state (formula < -0.25).")
	_lines.append("  Actual small-ruin peak-to-peak = 1 logical px, two adjacent native pixels. Web preview also shows +0.5; native center differs by 0.5 px on the positive lobe.")
	_lines.append("  Sky/sea use integer native positions. Sea keeps the 1278 px period and two adjacent copies.")
	_lines.append("")

	await _capture_background_only()
	await _capture_level()
	_write_manifests()
	print("DS03_CAPTURE_DONE")
	get_tree().quit(0)


func _capture_background_only() -> void:
	_bg = BG_SCENE.instantiate() as CloudRuinsDS03
	add_child(_bg)
	await _frames(3)
	_bg.set_clock_paused(true)
	var times: Array[float] = [0.0, 8.0, 12.0, 30.0, 60.0, 64.47]
	var names: Array[String] = ["00", "08", "12", "30", "60", "64_47"]
	for index: int in range(times.size()):
		var image: Image = await _capture_bg_at(times[index])
		var path: String = CAPTURE_DIR + "/ds03_bg_t" + names[index] + ".png"
		_save_image(image, path)
		_lines.append("ds03_bg_t%s.png | pure background component, t=%.2f s" % [names[index], times[index]])
	var hero: Image = await _capture_bg_at(0.0)
	_save_image(hero, CAPTURE_DIR + "/ds03_godot_background_only.png")
	_lines.append("ds03_godot_background_only.png | 640x360 pure background reference for art, t=0, no player/terrain/HUD")
	var hero_2x: Image = hero.duplicate() as Image
	hero_2x.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	_save_image(hero_2x, CAPTURE_DIR + "/ds03_godot_background_only_2x.png")
	_lines.append("ds03_godot_background_only_2x.png | nearest 2x reference")
	_lines.append("")
	_bg.queue_free()
	await _frames(3)


func _capture_level() -> void:
	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _frames(8)
	_player = _level.get_player()
	var bg: CloudRuinsDS03 = _level.get_node("Background/CloudRuinsDS03") as CloudRuinsDS03
	if _player == null or bg == null:
		push_error("DS03 level capture setup failed")
		return
	bg.set_clock_paused(true)
	await _wait_intro_done()

	await _place(Vector2(420.0, 300.0))
	bg.set_background_time(0.0)
	await _frames(3)
	_save_image(await _capture_viewport(), CAPTURE_DIR + "/ds03_level01_start.png")
	_lines.append("ds03_level01_start.png | opening courtyard near the start ground, background t=0, scripted pose (420,300)")

	await _place(Vector2(1174.0, 220.0))
	bg.set_background_time(0.0)
	await _frames(3)
	_save_image(await _capture_viewport(), CAPTURE_DIR + "/ds03_level01_pit.png")
	_lines.append("ds03_level01_pit.png | pit edge/high platform, background t=0, scripted pose (1174,220)")

	bg.set_background_time(64.47)
	await _frames(3)
	_save_image(await _capture_viewport(), CAPTURE_DIR + "/ds03_level01_pit_t64.png")
	_lines.append("ds03_level01_pit_t64.png | same pit pose, background t=64.47; both bridge feet under the same moved sea_main")

	await _place(Vector2(1790.0, 300.0))
	bg.set_background_time(30.0)
	await _frames(3)
	_save_image(await _capture_viewport(), CAPTURE_DIR + "/ds03_level01_exit.png")
	_lines.append("ds03_level01_exit.png | far bank near the exit gate, background t=30, scripted pose (1790,300), not a completion capture")


func _wait_intro_done() -> void:
	for _index: int in range(400):
		await get_tree().process_frame
		if _level != null and not _level.is_intro_active():
			break
	await _frames(6)


func _place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_level.get_camera().reset_smoothing()
	await _frames(5)


func _capture_bg_at(time_seconds: float) -> Image:
	if _bg != null:
		_bg.set_clock_paused(true)
		_bg.set_background_time(time_seconds)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _capture_viewport() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save_image(image: Image, path: String) -> void:
	if image.get_size() != Vector2i(640, 360) and not path.ends_with("_2x.png"):
		push_error("Unexpected capture size for %s: %s" % [path, str(image.get_size())])
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Capture failed for %s error=%d" % [path, error])
	else:
		print("CAPTURED %s size=%s" % [path, str(image.get_size())])


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _write_manifests() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines) + "\n")
		file.close()
	var data: Dictionary = {
		"godot": Engine.get_version_info()["string"],
		"display": DisplayServer.get_name(),
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"viewport": [640, 360],
		"date": "2026-11-03",
		"scripted_fixed_frames": true,
		"manual_play": false,
		"background_only": {
			"times": [0.0, 8.0, 12.0, 30.0, 60.0, 64.47],
			"reference": "res://screenshots/ds03_godot_background_only.png",
			"reference_2x": "res://screenshots/ds03_godot_background_only_2x.png",
			"no_player": true,
			"no_terrain": true,
			"no_hud": true,
		},
		"level": [
			{"file": "ds03_level01_start.png", "pose": [420, 300], "background_t": 0.0},
			{"file": "ds03_level01_pit.png", "pose": [1174, 220], "background_t": 0.0},
			{"file": "ds03_level01_pit_t64.png", "pose": [1174, 220], "background_t": 64.47},
			{"file": "ds03_level01_exit.png", "pose": [1790, 300], "background_t": 30.0},
		],
		"quantization": {
			"native_viewport": [640, 360],
			"global_2d_pixel_snap": true,
			"bridges": "G1/G2 exact DS03 integer offsets, no motion",
			"small_ruins_formula": "amp 0.35/0.30/0.45 px, period 18/22/20 s, phase 0.8/1.1/0.15",
			"small_ruins_native": "0 or -1 px; -1 only when formula < -0.25; actual peak-to-peak 1 logical px",
			"web_difference": "web shows -0.5/0/+0.5 logical px; native omits +0.5 and centers the negative step on -1",
			"sea": "integer phase, speed 4.2/7.2 right, period 1278, two adjacent copies",
			"sky": "integer x, speed 3.6/6.2 right, off-screen wrap",
		},
		"runtime_config_sha256": _sha256("res://assets/backgrounds/cloud_ruins_ds03/runtime_config.json"),
		"runtime_png_count": DATA.TEXTURES.size(),
		"test_log": "res://tests/logs/ds03_background_test.log",
	}
	var json_file: FileAccess = FileAccess.open(JSON_MANIFEST_PATH, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(data, "\t", false) + "\n")
		json_file.close()


func _sha256(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode().to_lower()
