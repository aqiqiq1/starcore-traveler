extends Node

## 640x360 evidence for the 2026-11-27 HUD/opening fixes.
##
## Run WITHOUT --headless so the real viewport renders at 640x360:
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/hud_fix_20261127/capture_hud_fix.tscn
##
## 01 is the real L1 opening at ~1.0 s (pure black hold, dust must be absent).
## 02 is the same black at ~2.05 s after the 0.6 s dust fade-in.
## 03-06 are the real L3 / DLC1 / DLC2 / DLC3 levels with their shared boss bar
## driven through the real HUD API.  Each also saves a 2x crop for inspection.

const OUT_DIR: String = "res://screenshots/hud_fix_20261127"
var _failures: int = 0
const LEVEL_01: String = "res://scenes/level_01.tscn"
const LEVEL_03: String = "res://scenes/level_03.tscn"
const TRIAL: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _capture_opening()
	await _capture_boss(LEVEL_03, "l3", "03_l3_guard_bar.png")
	await _capture_boss(TRIAL, "trial", "04_dlc1_guard_bar.png")
	await _capture_boss(RIFT, "rift", "05_rift_mirror_bar.png")
	await _capture_boss(LOOM, "loom", "06_loom_bar.png")
	print("CAPTURE_HUD_FIX done dir=%s failures=%d" % [OUT_DIR, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _capture_opening() -> void:
	var level: Node = (load(LEVEL_01) as PackedScene).instantiate()
	level.set("enable_start_menu", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(6)
	var opening: Node = level.call("get_opening")
	if opening == null:
		printerr("CAPTURE_HUD_FIX missing opening")
		return
	while opening.call("get_elapsed") < 1.9 and opening.call("is_active"):
		await get_tree().process_frame
	print("STATE black elapsed=%.2f dust=%.2f visible=%s" % [
		opening.call("get_elapsed"), opening.call("get_dust_alpha"),
		str(opening.call("is_dust_visible")),
	])
	var black_image: Image = await _save("01_l1_black_no_dust.png")
	var black_bright: int = _count_bright(black_image, 40)
	print("CHECK black_bright_pixels_ge40=%d expected=0" % black_bright)
	if black_bright != 0:
		_failures += 1
	while opening.call("get_elapsed") < 4.55 and opening.call("is_active"):
		await get_tree().process_frame
	var dust_color: Color = opening.call("get_dust_color")
	print("STATE embers elapsed=%.2f alpha=%.2f visible=%s count=%d size=%d color=%s" % [
		opening.call("get_elapsed"), opening.call("get_dust_alpha"),
		str(opening.call("is_dust_visible")), opening.call("get_dust_count"),
		opening.call("get_dust_size"), str(dust_color),
	])
	if opening.call("get_dust_count") > 24:
		_failures += 1
	if not (dust_color.r > dust_color.g and dust_color.g > dust_color.b):
		_failures += 1
	var dust_image: Image = await _save("02_l1_dust_faded_in.png")
	var warm_pixels: int = _count_warm(dust_image)
	print("CHECK dust_warm_pixels=%d expected>0" % warm_pixels)
	if warm_pixels <= 0:
		_failures += 1
	opening.call("abort")
	await _free_current(level)


func _capture_boss(scene_path: String, kind: String, file_name: String) -> void:
	var level: Node = (load(scene_path) as PackedScene).instantiate()
	if _has_property(level, "show_intro_guide"):
		level.set("show_intro_guide", false)
	if _has_property(level, "show_intro_cinematic"):
		level.set("show_intro_cinematic", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(24)
	var hud: Node = level.get_node_or_null("HUD")
	if hud == null:
		printerr("CAPTURE_HUD_FIX missing HUD in " + scene_path)
		await _free_current(level)
		return
	# The chapter's own process keeps re-driving its boss-bar visibility from
	# the route.  Freeze only the level logic so the real HUD can be sampled
	# with the requested state; the HUD itself is PROCESS_MODE_ALWAYS.
	level.set_process(false)
	level.set_physics_process(false)
	hud.set("visible", true)
	match kind:
		"l3":
			if hud.has_method("set_gameplay_visible"):
				hud.call("set_gameplay_visible", true)
			hud.call("set_boss_state", 3, 3)
		"trial":
			hud.call("set_boss_state", 3, 3)
		"rift":
			hud.call("set_boss_state", 1, 3, 2, 3, false, true, false)
		"loom":
			hud.call("set_boss_state", 2, 3, 1, 1, 3, false, 1, 3, 2, 3)
	hud.call("set_boss_visible", true)
	await _wait_process(18)
	var boss: Node = hud.call("get_boss_bar") if hud.has_method("get_boss_bar") else hud.call("get_boss_status")
	if boss != null:
		print("STATE boss %s visible=%s alpha=%.2f rect=%s parent=%s paused=%s suppressed=%s hud=%s" % [
			kind, str(boss.get("visible")), (boss.get("modulate") as Color).a,
			str(boss.get("position")), str(boss.get_parent().name),
			str(get_tree().paused), str(boss.call("is_modal_suppressed")),
			str(hud.get("visible")),
		])
		await _wait_process(30)
		print("STATE boss_late %s alpha=%.2f visible=%s" % [
			kind, (boss.get("modulate") as Color).a, str(boss.get("visible")),
		])
	await _save(file_name)
	await _save_bar_crop(file_name.get_basename() + "_bar_2x.png")
	await _free_current(level)


func _save_bar_crop(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		return
	var crop: Image = image.get_region(Rect2i(140, 22, 360, 16))
	crop.resize(720, 32, Image.INTERPOLATE_NEAREST)
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	var error: Error = crop.save_png(directory.path_join(file_name))
	print("CROP %s size=720x32 error=%d" % [file_name, error])


func _save(file_name: String) -> Image:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(file_name))
	print("SHOT %s size=%dx%d error=%d" % [
		file_name, image.get_width(), image.get_height(), error
	])
	return image


func _count_bright(image: Image, threshold: int) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) * 255.0 >= float(threshold):
				count += 1
	return count


## Counts pixels that already read as warm (R > G > B and bright enough).
func _count_warm(image: Image) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			var r: float = pixel.r * 255.0
			var g: float = pixel.g * 255.0
			var b: float = pixel.b * 255.0
			if r >= 40.0 and r > g and g > b:
				count += 1
	return count


func _free_current(level: Node) -> void:
	get_tree().current_scene = null
	level.queue_free()
	await _wait_process(10)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _has_property(object: Object, property_name: String) -> bool:
	for entry: Dictionary in object.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false
