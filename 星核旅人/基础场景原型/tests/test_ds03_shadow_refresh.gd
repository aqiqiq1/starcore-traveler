extends Node

## Directed DS03 shadow-refresh probe.
##
## Proves that the two shadow canvas items (ShadowsMain / ShadowsNear) are
## rebuilt during ordinary playback while every layer stays visible. It never
## toggles visibility, re-instantiates during playback, or manually redraws the
## shadow nodes for the assertion path; the only manual redraw is the reference
## frame used to prove that a normal frame was stale.
##
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tests/test_ds03_shadow_refresh.tscn -- before_fix
## The optional user arg becomes the log suffix (default: after_fix).

const BG_SCENE: PackedScene = preload("res://scenes/backgrounds/cloud_ruins_ds03.tscn")
const LOG_DIR: String = "res://tests/logs"
const SAMPLE_TIME: float = 5.625

var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []
var _bg: CloudRuinsDS03
var _viewport: SubViewport
var _rendered: bool = false
var _counts: Dictionary = {}
var _shadow_draws: Dictionary = {}
var _log_tag: String = "after_fix"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].is_empty():
		_log_tag = args[0]
	await get_tree().process_frame
	_log("Star Core Traveler - DS03 shadow refresh probe (%s)" % _log_tag)
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])
	if DisplayServer.get_name() == "headless":
		_log("Rendered checks: SKIPPED (headless display); run with the GUI executable.")
		_finish()
		return
	_rendered = true
	await _setup()
	await _test_t0_reference()
	await _test_forced_time_refresh()
	await _test_pause_and_resume()
	await _test_live_process_advance()
	_finish()


func _setup() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	add_child(_viewport)
	_bg = BG_SCENE.instantiate() as CloudRuinsDS03
	_viewport.add_child(_bg)
	# Freeze immediately after _ready so the first rendered frame is exactly t=0.
	_bg.set_clock_paused(true)
	_connect_counter("sea_main", _bg.get_node("SeaMain") as CanvasItem)
	_connect_counter("sea_near", _bg.get_node("SeaNear") as CanvasItem)
	_connect_counter("groups", _bg.get_node("Groups") as CanvasItem)
	_connect_counter("debris", _bg.get_node("Debris") as CanvasItem)
	_connect_counter("shadows_main", _bg.get_node("SeaMain/ShadowsMain") as CanvasItem)
	_connect_counter("shadows_near", _bg.get_node("SeaNear/ShadowsNear") as CanvasItem)
	# Recorders attached after the component's own callbacks: they fire on the
	# same draw dispatch that rebuilds the shadow command list and capture the
	# time/placement actually used by that rebuild.
	_bg.get_node("SeaMain/ShadowsMain").draw.connect(_record_shadow_draw.bind("sea_main"))
	_bg.get_node("SeaNear/ShadowsNear").draw.connect(_record_shadow_draw.bind("sea_near"))
	await _frames(4)


func _connect_counter(key: String, node: CanvasItem) -> void:
	_counts[key] = 0
	node.draw.connect(_bump_count.bind(key))


func _bump_count(key: String) -> void:
	_counts[key] = int(_counts[key]) + 1


func _record_shadow_draw(surface: String) -> void:
	if not _shadow_draws.has(surface):
		_shadow_draws[surface] = []
	var placements: Array[Dictionary] = _bg.get_shadow_positions(surface)
	var entry: Dictionary = {
		"t": _bg.get_background_time(),
		"placements": placements,
	}
	var list: Array = _shadow_draws[surface]
	list.append(entry)
	_shadow_draws[surface] = list


func _test_t0_reference() -> void:
	_section("T0: NORMAL DRAW MATCHES A FORCED REFERENCE")
	var normal: Image = await _render()
	var counts_before: Dictionary = _counts.duplicate(true)
	_force_shadow_redraw()
	var reference: Image = await _render()
	_check(_same_image(normal, reference), "t=0 normal frame equals forced-shadow reference", _image_hash(normal))
	_check(int(_counts["shadows_main"]) > int(counts_before["shadows_main"]), "forced reference rebuilds ShadowsMain draw")
	_check(int(_counts["shadows_near"]) > int(counts_before["shadows_near"]), "forced reference rebuilds ShadowsNear draw")
	_log("t0 draw counts: %s" % str(_counts))
	_log("t0 shadow placements: %s" % str(_shadow_draws))


func _test_forced_time_refresh() -> void:
	_section("T=5.625: NORMAL TIME ADVANCE MUST REFRESH BOTH SHADOWS")
	_check(_bg.is_clock_paused(), "clock is frozen for the scripted time step")
	var before: Dictionary = _counts.duplicate(true)
	_bg.set_background_time(SAMPLE_TIME)
	var normal: Image = await _render()
	var after_normal: Dictionary = _counts.duplicate(true)
	_log("t=5.625 draw counts after normal advance: %s (delta from %s)" % [str(after_normal), str(before)])
	_check(float(_bg.get_background_time()) == SAMPLE_TIME, "clock reads 5.625 s", str(_bg.get_background_time()))
	_check(
		int(after_normal["shadows_main"]) > int(before["shadows_main"]),
		"normal set_background_time rebuilds ShadowsMain draw",
		"%d -> %d" % [int(before["shadows_main"]), int(after_normal["shadows_main"])]
	)
	_check(
		int(after_normal["shadows_near"]) > int(before["shadows_near"]),
		"normal set_background_time rebuilds ShadowsNear draw",
		"%d -> %d" % [int(before["shadows_near"]), int(after_normal["shadows_near"])]
	)
	_check(
		int(after_normal["sea_main"]) > int(before["sea_main"]),
		"normal set_background_time rebuilds SeaMain draw",
		"%d -> %d" % [int(before["sea_main"]), int(after_normal["sea_main"])]
	)
	_check(
		int(after_normal["debris"]) > int(before["debris"]),
		"normal set_background_time rebuilds Debris draw",
		"%d -> %d" % [int(before["debris"]), int(after_normal["debris"])]
	)

	var placements: Dictionary = _shadow_draws
	_log("shadow draw recorder at 5.625: %s" % str(placements))
	_check(_shadow_records_include(placements, "sea_main", SAMPLE_TIME, true), "ShadowsMain drew at 5.625 with grown/faded placement")
	_check(_shadow_records_include(placements, "sea_near", SAMPLE_TIME, false), "ShadowsNear drew at 5.625")

	_force_shadow_redraw()
	var reference: Image = await _render()
	var diff: Dictionary = _diff_stats(normal, reference)
	_log("normal-vs-forced at 5.625: changed=%d bbox=(%d,%d)-(%d,%d)" % [
		int(diff["changed"]), int(diff["min_x"]), int(diff["min_y"]),
		int(diff["max_x"]), int(diff["max_y"]),
	])
	_check(
		int(diff["changed"]) == 0,
		"normal 5.625 frame equals forced-shadow reference (no stale shadow pixels)",
		str(diff)
	)
	_check(_same_image(normal, reference), "normal 5.625 frame is pixel-identical to reference")


func _test_pause_and_resume() -> void:
	_section("PAUSE FREEZES DRAW / RESUME CONTINUES")
	_check(_bg.is_clock_paused(), "clock is paused at this point")
	var frozen_time: float = _bg.get_background_time()
	var frozen: Dictionary = _counts.duplicate(true)
	await get_tree().create_timer(0.30, true).timeout
	_check(is_equal_approx(_bg.get_background_time(), frozen_time), "paused clock does not advance", "%.3f" % frozen_time)
	_check(_counts == frozen, "paused clock does not redraw any shadow or sea layer", str(_counts))
	_bg.set_clock_paused(false)
	await get_tree().create_timer(0.30, true).timeout
	var resumed: Dictionary = _counts.duplicate(true)
	_check(_bg.get_background_time() > frozen_time, "resume advances the clock", "%.3f -> %.3f" % [frozen_time, _bg.get_background_time()])
	_check(
		int(resumed["shadows_main"]) > int(frozen["shadows_main"]),
		"resume redraws ShadowsMain",
		"%d -> %d" % [int(frozen["shadows_main"]), int(resumed["shadows_main"])]
	)
	_check(
		int(resumed["shadows_near"]) > int(frozen["shadows_near"]),
		"resume redraws ShadowsNear",
		"%d -> %d" % [int(frozen["shadows_near"]), int(resumed["shadows_near"])]
	)
	_bg.set_clock_paused(true)


func _test_live_process_advance() -> void:
	_section("LIVE _PROCESS: SHADOWS FOLLOW THE CLOCK")
	var before_time: float = _bg.get_background_time()
	var before: Dictionary = _counts.duplicate(true)
	_bg.set_clock_paused(false)
	await get_tree().create_timer(0.50, true).timeout
	_bg.set_clock_paused(true)
	var after: Dictionary = _counts.duplicate(true)
	_check(_bg.get_background_time() > before_time + 0.30, "live process advances the clock", "%.3f -> %.3f" % [before_time, _bg.get_background_time()])
	for key: String in ["sea_main", "sea_near", "groups", "debris", "shadows_main", "shadows_near"]:
		_check(
			int(after[key]) > int(before[key]),
			"live process redraws %s" % key,
			"%d -> %d" % [int(before[key]), int(after[key])]
		)
	var main_placements: Array = _shadow_draws.get("sea_main", [])
	_check(not main_placements.is_empty(), "ShadowsMain draw recorder has entries")
	if not main_placements.is_empty():
		var last: Dictionary = main_placements[main_placements.size() - 1]
		_check(absf(float(last["t"]) - _bg.get_background_time()) < 0.05, "last ShadowsMain draw used the live clock", str(last["t"]))


func _shadow_records_include(surface_records: Dictionary, surface: String, t: float, expect_grow: bool) -> bool:
	var list: Array = surface_records.get(surface, [])
	for entry: Dictionary in list:
		if absf(float(entry["t"]) - t) > 0.001:
			continue
		var placements: Array = entry["placements"]
		if placements.is_empty():
			continue
		var first: Dictionary = placements[0]
		if expect_grow:
			if bool(first.get("high", false)) and int(first.get("grow", 0)) == 1:
				return true
		else:
			return true
	return false


func _force_shadow_redraw() -> void:
	# Test-only reference: rebuild the exact command list the normal path
	# should have produced. Never used as a stand-in for normal redraw.
	(_bg.get_node("SeaMain/ShadowsMain") as CanvasItem).queue_redraw()
	(_bg.get_node("SeaNear/ShadowsNear") as CanvasItem).queue_redraw()


func _render() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _same_image(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	return a.get_data() == b.get_data()


func _diff_stats(a: Image, b: Image) -> Dictionary:
	var width: int = a.get_width()
	var height: int = a.get_height()
	var ad: PackedByteArray = a.get_data()
	var bd: PackedByteArray = b.get_data()
	var changed: int = 0
	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(height):
		for x: int in range(width):
			var index: int = (y * width + x) * 4
			if ad[index] == bd[index] and ad[index + 1] == bd[index + 1] and ad[index + 2] == bd[index + 2] and ad[index + 3] == bd[index + 3]:
				continue
			changed += 1
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	return {
		"changed": changed,
		"min_x": min_x, "min_y": min_y,
		"max_x": max_x, "max_y": max_y,
	}


func _image_hash(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode().to_lower()


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


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
	get_tree().paused = false
	var path: String = LOG_DIR + "/ds03_shadow_refresh_%s.log" % _log_tag
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d rendered=%s" % [_pass_count, _fail_count, str(_rendered)])
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log_lines) + "\n")
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
