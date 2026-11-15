extends Node

## Focused acceptance for the DS03 dynamic background integration.
##
## Run with the GUI executable so the actual rendered checks execute:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tests/test_ds03_background.tscn
##
## Headless still runs the asset/config/clock checks and clearly reports that
## rendered checks were skipped. Rendered checks read the real 640x360 viewport
## texture; they are not a substitute-only parameter test.

const BG_SCENE: PackedScene = preload("res://scenes/backgrounds/cloud_ruins_ds03.tscn")
const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const DATA := preload("res://scripts/backgrounds/cloud_ruins_ds03_data.gd")
const CONFIG_PATH: String = "res://assets/backgrounds/cloud_ruins_ds03/runtime_config.json"
const MANIFEST_PATH: String = "res://assets/backgrounds/cloud_ruins_ds03/source_manifest.json"
const LOG_PATH: String = "res://tests/logs/ds03_background_test.log"
const APPROVED_RUNTIME_CONFIG_SHA256: String = "c1e7b4779416d0e268b130be7ee286d32cc4eb87dd87bd7f80fa1c9605859899"

const GROUP_IDS: Array[String] = ["G1", "G2", "G3", "G4", "G5"]
const DYNAMIC_GROUP_IDS: Array[String] = ["G3", "G4", "G5"]
const SKY_NODE_NAMES: Array[String] = [
	"SkyBankLeft", "SkyBankRight", "SkyMidWisp", "SkyLowWispR",
	"SkyLeftWisp", "SkyLowWispL", "SkyHighChip",
]
const TOP_LAYERS: Array[String] = [
	"Base", "Sky", "Groups", "SeaMain", "Arch", "SeaNear", "Rocks", "Debris",
]
const LEFT_FOOT_ROI: Rect2i = Rect2i(30, 250, 120, 34)
const RIGHT_FOOT_ROI: Rect2i = Rect2i(455, 250, 105, 34)

var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []
var _bg: CloudRuinsDS03
var _level: Level01
var _rendered: bool = false
var _bg_reset_seen: bool = false
var _bg_reset_time: float = -1.0
var _player_reset_reason: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - DS03 dynamic background acceptance")
	_log("Godot %s  display=%s  window=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
		str(DisplayServer.window_get_size()),
	])
	if DisplayServer.get_name() == "headless":
		_log("Rendered checks: SKIPPED (headless display); run this scene with the GUI executable.")
	else:
		_rendered = true
		if DisplayServer.window_get_size() == Vector2i(640, 360):
			DisplayServer.window_set_size(Vector2i(1280, 720))
			await _frames(3)

	_test_asset_integrity()
	_test_config_and_order()
	await _test_component_clock_and_motion()
	if _rendered:
		await _test_rendered_layers()
		await _test_rendered_occlusion_and_shadows()
	await _test_level_wiring()
	await _test_pause_reset_and_reload()
	_finish()


func _test_asset_integrity() -> void:
	_section("24 PNG BYTE COPIES / IMPORT / CONFIG")
	_check(FileAccess.file_exists(CONFIG_PATH), "runtime config copy exists")
	_check(_sha256(CONFIG_PATH) == APPROVED_RUNTIME_CONFIG_SHA256, "runtime config is a byte copy of DS03", _sha256(CONFIG_PATH))
	var config: Dictionary = _read_json(CONFIG_PATH)
	_check(not config.is_empty(), "runtime config parses")
	if config.is_empty():
		return
	_check(_int_array_equal(config.get("canvas", []), [640, 360]), "config canvas is 640x360")
	_check(int(config.get("render_scale", 0)) == 2, "config keeps DS03 render_scale 2")
	_check(int(config.get("sea_period", 0)) == 1278, "config sea period is 1278")

	var items: Array[Dictionary] = _config_items(config)
	_check(items.size() == 24, "config describes 24 PNG layers", str(items.size()))
	var verified: int = 0
	for item: Dictionary in items:
		var relative: String = String(item["file"])
		var path: String = "res://assets/backgrounds/cloud_ruins_ds03/" + relative
		_check(FileAccess.file_exists(path), "runtime PNG exists: " + relative)
		if not FileAccess.file_exists(path):
			continue
		_check(_sha256(path) == String(item["sha256"]).to_lower(), "runtime PNG hash matches source: " + relative)
		var texture: Texture2D = load(path) as Texture2D
		_check(texture != null, "runtime PNG imports: " + relative)
		if texture == null:
			continue
		_check(
			texture.get_width() == int(item["size"][0])
			and texture.get_height() == int(item["size"][1]),
			"imported size matches config: " + relative,
			"%dx%d" % [texture.get_width(), texture.get_height()]
		)
		var imported: Image = texture.get_image()
		var file_image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if imported == null or file_image == null:
			_check(false, "pixel buffers decode: " + relative)
			continue
		imported.convert(Image.FORMAT_RGBA8)
		file_image.convert(Image.FORMAT_RGBA8)
		_check(_image_visual_equal(imported, file_image), "imported visible pixels are byte-identical: " + relative)
		verified += 1
	_check(verified == 24, "all 24 imported PNGs were pixel-verified", str(verified))
	_check(DATA.TEXTURES.size() == 24, "generated data exposes 24 textures", str(DATA.TEXTURES.size()))

	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	_check(not manifest.is_empty(), "source manifest parses")
	_check(int(manifest.get("png_count", 0)) == 24, "source manifest records 24 PNGs")
	_check(
		String(manifest.get("source_runtime_config_sha256", "")) == APPROVED_RUNTIME_CONFIG_SHA256,
		"source manifest records the DS03 runtime config hash"
	)
	var old_layers: Array = config.get("source", {}).get("old_layers_used", [])
	_check(old_layers.is_empty(), "DS03 config uses no old static cloud layers", str(old_layers))
	var raw_config: String = FileAccess.get_file_as_string(CONFIG_PATH)
	_check(not raw_config.contains("island_overlay"), "config contains no island_overlay branch")
	_check(not raw_config.contains("arch_overlay"), "config contains no arch_overlay branch")


func _test_config_and_order() -> void:
	_section("DS03 PARAMETERS / LAYER ORDER")
	var config: Dictionary = _read_json(CONFIG_PATH)
	if config.is_empty():
		_check(false, "config parameter checks skipped")
		return
	var groups: Array = config["groups"]
	var by_id: Dictionary = {}
	for group: Dictionary in groups:
		by_id[String(group["id"])] = group
	_check(by_id.size() == 5, "five rigid group specs", str(by_id.size()))
	for id: String in ["G1", "G2"]:
		var f: Dictionary = by_id[id]["float"]
		_check(bool(f["enabled"]) == false, id + " float is disabled", str(f))
	_check(is_equal_approx(float(by_id["G3"]["float"]["amp"]), 0.35), "G3 formula amp 0.35")
	_check(is_equal_approx(float(by_id["G3"]["float"]["period"]), 18.0), "G3 period 18 s")
	_check(is_equal_approx(float(by_id["G3"]["float"]["phase"]), 0.8), "G3 phase 0.8")
	_check(is_equal_approx(float(by_id["G4"]["float"]["amp"]), 0.30), "G4 formula amp 0.30")
	_check(is_equal_approx(float(by_id["G4"]["float"]["period"]), 22.0), "G4 period 22 s")
	_check(is_equal_approx(float(by_id["G4"]["float"]["phase"]), 1.1), "G4 phase 1.1")
	_check(is_equal_approx(float(by_id["G5"]["float"]["amp"]), 0.45), "G5 formula amp 0.45")
	_check(is_equal_approx(float(by_id["G5"]["float"]["period"]), 20.0), "G5 period 20 s")
	_check(is_equal_approx(float(by_id["G5"]["float"]["phase"]), 0.15), "G5 phase 0.15")

	var sky: Array = config["sky"]
	_check(sky.size() == 7, "seven sky cloud layers", str(sky.size()))
	var sky_speeds: Array[float] = []
	for spec: Dictionary in sky:
		sky_speeds.append(float(spec["speed"]))
	_check(sky_speeds == [6.2, 6.2, 3.6, 3.6, 3.6, 3.6, 3.6], "sky speeds are 6.2 / 3.6 rightward", str(sky_speeds))
	var sea: Array = config["sea"]
	_check(sea.size() == 2, "two sea layers", str(sea.size()))
	_check(String(sea[0]["name"]) == "sea_main" and is_equal_approx(float(sea[0]["speed"]), 4.2), "sea_main speed 4.2")
	_check(String(sea[1]["name"]) == "sea_near" and is_equal_approx(float(sea[1]["speed"]), 7.2), "sea_near speed 7.2")
	_check(int(sea[0]["period"]) == 1278 and int(sea[1]["period"]) == 1278, "both sea layers use period 1278")
	var sea_main_top: Array = sea[0]["top"]
	var sea_near_top: Array = sea[1]["top"]
	_check(sea_main_top.size() == 1278 and sea_near_top.size() == 1278, "both sea top tables have 1278 entries")
	_check(int(sea_main_top[0]) == 280, "sea_main top[0] comes from DS03", str(sea_main_top[0]))
	_check(int(sea_near_top[0]) == 312, "sea_near top[0] comes from DS03", str(sea_near_top[0]))

	var stack: Array = config["stack"]
	var flat: Array[String] = []
	for depth_entry: Dictionary in stack:
		for item: String in depth_entry["items"]:
			flat.append(item)
	var groups_pos: int = flat.find("G3")
	var bridges_pos: int = flat.find("G1")
	var sea_main_pos: int = flat.find("sea_main")
	var arch_pos: int = flat.find("arch_stone")
	var sea_near_pos: int = flat.find("sea_near")
	var rock_pos: int = flat.find("rock_remnants_static")
	var debris_pos: int = flat.find("debris_central")
	_check(groups_pos >= 0 and groups_pos < bridges_pos, "G3/G4/G5 precede G1/G2")
	_check(bridges_pos < sea_main_pos, "both bridges are before sea_main")
	_check(sea_main_pos < arch_pos and arch_pos < sea_near_pos, "sea_main -> arch_stone -> sea_near order")
	_check(sea_near_pos < rock_pos and rock_pos < debris_pos, "sea_near -> rocks -> debris order")
	_check(flat.find("G2") < sea_main_pos, "the right bridge is also before sea_main")


func _test_component_clock_and_motion() -> void:
	_section("COMPONENT / NATIVE QUANTIZATION / ONE-WAY MOTION")
	_bg = BG_SCENE.instantiate() as CloudRuinsDS03
	add_child(_bg)
	await _frames(3)
	_check(_bg != null, "background component instantiates")
	if _bg == null:
		return
	_bg.set_clock_paused(true)
	_check(_bg.get_canvas_size() == Vector2i(640, 360), "component canvas is 640x360")
	_check(_bg.process_mode == Node.PROCESS_MODE_PAUSABLE, "component pauses with the scene tree")
	var groups_root: Node = _bg.get_node("Groups")
	var group_names: Array[String] = []
	for child: Node in groups_root.get_children():
		group_names.append(String(child.name))
	_check(group_names == ["G3", "G4", "G5", "G1", "G2"], "actual group draw order is G3/G4/G5 then G1/G2", str(group_names))
	_check(_bg.get_node("Groups").get_index() < _bg.get_node("SeaMain").get_index(), "Groups draw before SeaMain")
	_check(_bg.get_node("SeaMain").get_index() < _bg.get_node("Arch").get_index(), "SeaMain draws before Arch")
	_check(_bg.get_node("Arch").get_index() < _bg.get_node("SeaNear").get_index(), "Arch draws before SeaNear")
	_check(_bg.get_node("SeaNear").get_index() < _bg.get_node("Rocks").get_index(), "SeaNear draws before Rocks")
	_check(_bg.get_node("Rocks").get_index() < _bg.get_node("Debris").get_index(), "Rocks draw before Debris")
	_check((_bg.get_node("SeaMain") as Node2D).clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW, "sea_main clip mode is clip+draw")
	_check((_bg.get_node("SeaNear") as Node2D).clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW, "sea_near clip mode is clip+draw")
	_check(_bg.find_child("island_overlay", true, false) == null, "no island_overlay node exists")
	var collision_free: bool = true
	var input_free: bool = true
	for descendant: Node in _bg.find_children("*", "", true, false):
		if descendant is CollisionObject2D or descendant is CollisionShape2D or descendant is CollisionPolygon2D:
			collision_free = false
		if descendant is Control:
			input_free = false
	_check(collision_free, "background has no collision nodes")
	_check(input_free, "background has no Control input nodes")
	for layer_name: String in TOP_LAYERS:
		var layer: CanvasItem = _bg.get_node_or_null(layer_name) as CanvasItem
		_check(layer != null and layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "layer %s is Nearest" % layer_name)

	var min_dy: Dictionary = {}
	var max_dy: Dictionary = {}
	var changes: Dictionary = {}
	var previous: Dictionary = {}
	for id: String in GROUP_IDS:
		min_dy[id] = 999
		max_dy[id] = -999
		changes[id] = 0
		previous[id] = null
	for step: int in range(0, 1201):
		var t: float = float(step) * 0.05
		_bg.set_background_time(t)
		for id: String in GROUP_IDS:
			var dy: int = _bg.get_group_render_dy(id)
			min_dy[id] = mini(int(min_dy[id]), dy)
			max_dy[id] = maxi(int(max_dy[id]), dy)
			if previous[id] != null and int(previous[id]) != dy:
				changes[id] = int(changes[id]) + 1
			previous[id] = dy
	for id: String in ["G1", "G2"]:
		_check(int(min_dy[id]) == 0 and int(max_dy[id]) == 0, id + " is absolutely fixed over 60 s")
		_check(int(changes[id]) == 0, id + " never changes rendered position")
	for id: String in DYNAMIC_GROUP_IDS:
		_check(int(max_dy[id]) - int(min_dy[id]) <= 1, id + " rendered peak-to-peak is <= 1 px", "%d..%d" % [int(min_dy[id]), int(max_dy[id])])
		_check(int(min_dy[id]) == -1 and int(max_dy[id]) == 0, id + " uses the two native states {0,-1}")
		_check(int(changes[id]) > 0, id + " actually moves (not snap-frozen)")

	var periods: Dictionary = {"G3": 18.0, "G4": 22.0, "G5": 20.0}
	for id: String in DYNAMIC_GROUP_IDS:
		var period_changes: int = 0
		var last_dy: int = -999
		var period_steps: int = int(ceil(float(periods[id]) / 0.05))
		for step: int in range(0, period_steps + 1):
			_bg.set_background_time(float(step) * 0.05)
			var dy: int = _bg.get_group_render_dy(id)
			if last_dy != -999 and dy != last_dy:
				period_changes += 1
			last_dy = dy
		_check(period_changes <= 2, id + " changes at most twice per period", str(period_changes))
	for id: String in DYNAMIC_GROUP_IDS:
		_bg.set_background_time(0.0)
		var at_zero: int = _bg.get_group_render_dy(id)
		_bg.set_background_time(float(periods[id]))
		var at_period: int = _bg.get_group_render_dy(id)
		_check(at_zero == at_period, id + " repeats at its period", "%d vs %d" % [at_zero, at_period])

	_bg.set_background_time(0.0)
	_check(_bg.get_sea_phase("sea_main") == 0 and _bg.get_sea_phase("sea_near") == 0, "both sea phases start at 0")
	var previous_main: int = -1
	var previous_near: int = -1
	var monotonic_main: bool = true
	var monotonic_near: bool = true
	for step: int in range(0, 200):
		var t: float = float(step) * 0.25
		_bg.set_background_time(t)
		var main: int = _bg.get_sea_phase("sea_main")
		var near: int = _bg.get_sea_phase("sea_near")
		if previous_main >= 0 and main < previous_main:
			monotonic_main = false
		if previous_near >= 0 and near < previous_near:
			monotonic_near = false
		previous_main = main
		previous_near = near
	_check(monotonic_main, "sea_main display phase only advances (one-way rightward)")
	_check(monotonic_near, "sea_near display phase only advances (one-way rightward)")
	_bg.set_background_time(304.2857142857143)
	_check(_bg.get_sea_phase("sea_main") == 0, "sea_main wraps at 304.2857 s", str(_bg.get_sea_phase("sea_main")))
	_bg.set_background_time(177.5)
	_check(_bg.get_sea_phase("sea_near") == 0, "sea_near wraps at 177.5 s", str(_bg.get_sea_phase("sea_near")))

	var sky_expect: Dictionary = {
		"sky_bank_left": [-56, 6.2], "sky_bank_right": [376, 6.2],
		"sky_mid_wisp": [243, 3.6], "sky_low_wisp_r": [466, 3.6],
		"sky_left_wisp": [91, 3.6], "sky_low_wisp_l": [198, 3.6],
		"sky_high_chip": [321, 3.6],
	}
	for name: String in sky_expect:
		_bg.set_background_time(0.0)
		var x0: int = _bg.get_sky_x(name)
		_bg.set_background_time(1.0)
		var x1: int = _bg.get_sky_x(name)
		_check(x0 == int(sky_expect[name][0]), name + " starts at its DS03 x0", str(x0))
		_check(x1 > x0, name + " moves right", "%d -> %d" % [x0, x1])
		_check(absf(float(x1 - x0) - float(sky_expect[name][1])) <= 0.51, name + " one-second step matches its speed", str(x1 - x0))
	_bg.set_background_time(113.0)
	var before_wrap: int = _bg.get_sky_x("sky_bank_left")
	_bg.set_background_time(114.0)
	var after_wrap: int = _bg.get_sky_x("sky_bank_left")
	_check(before_wrap > 600, "left sky bank reaches the right edge before wrapping", str(before_wrap))
	_check(after_wrap < 0 and after_wrap + 287 <= 0, "left sky bank wraps wholly off-screen", str(after_wrap))

	_bg.set_background_time(0.0)
	var shadows_zero: Array[Dictionary] = _bg.get_shadow_positions("sea_main")
	_bg.set_background_time(5.625)
	var shadows_high: Array[Dictionary] = _bg.get_shadow_positions("sea_main")
	_check(shadows_zero.size() == 2 and shadows_high.size() == 2, "two central/cluster shadows are exposed")
	if shadows_zero.size() == 2 and shadows_high.size() == 2:
		_check(float(shadows_high[0]["bob"]) < -3.0, "central debris is high at 5.625 s", str(shadows_high[0]["bob"]))
		_check(bool(shadows_high[0]["high"]) and int(shadows_high[0]["grow"]) == 1, "high shadow uses the DS03 grow rule")
		_check(not is_equal_approx(float(shadows_zero[0]["sy"]), float(shadows_high[0]["sy"])), "shadow y follows the debris height")
		_check(float(shadows_high[0]["alpha"]) < float(shadows_zero[0]["alpha"]), "high shadow fades according to DS03")
	_bg.set_background_time(0.0)
	var near_shadows: Array[Dictionary] = _bg.get_shadow_positions("sea_near")
	_check(near_shadows.size() == 1 and String(near_shadows[0]["surface"]) == "sea_near", "low shadow is owned by sea_near")
	var debris_zero: Array[Dictionary] = _bg.get_debris_positions()
	_bg.set_background_time(3.0)
	var debris_three: Array[Dictionary] = _bg.get_debris_positions()
	_check(debris_zero.size() == 4, "four floating debris groups are exposed", str(debris_zero.size()))
	var moved_debris: int = 0
	for index: int in range(mini(debris_zero.size(), debris_three.size())):
		if int(debris_zero[index]["y"]) != int(debris_three[index]["y"]):
			moved_debris += 1
	_check(moved_debris == 4, "all floating debris groups bob between t=0 and t=3", str(moved_debris))


func _test_level_wiring() -> void:
	_section("LEVEL 01 BACKGROUND BRANCH")
	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _physics(6)
	var background: CanvasLayer = _level.get_node_or_null("Background") as CanvasLayer
	_check(background != null and background.layer == -10, "Background CanvasLayer stays at -10")
	if background == null:
		return
	var v7: TextureRect = background.get_node_or_null("CloudRuinsV7") as TextureRect
	_check(v7 != null and not v7.visible and not v7.is_visible_in_tree(), "CloudRuinsV7 is retained but hidden")
	_check(v7 != null and v7.texture != null, "CloudRuinsV7 keeps its old texture for comparison")
	var ds03: CloudRuinsDS03 = background.get_node_or_null("CloudRuinsDS03") as CloudRuinsDS03
	_check(ds03 != null and ds03.visible and ds03.is_visible_in_tree(), "CloudRuinsDS03 is the visible background")
	_check(ds03 != null and ds03.get_parent() == background, "CloudRuinsDS03 is a Background child")
	if ds03 != null:
		_check(ds03.position == Vector2.ZERO, "CloudRuinsDS03 is at the screen origin", str(ds03.position))
		_check(ds03.get_canvas_size() == Vector2i(640, 360), "CloudRuinsDS03 fills 640x360")
	for layer_name: String in ["Sky", "FarRuins", "NearRuins", "Mist"]:
		var old_layer: TextureRect = background.get_node_or_null(layer_name) as TextureRect
		_check(old_layer != null and not old_layer.visible, "old background layer stays hidden: " + layer_name)
	for cloud_name: String in ["PitCloudBack", "PitCloudFront", "PitCloudGlow"]:
		var cloud: Polygon2D = _level.get_node_or_null("World/" + cloud_name) as Polygon2D
		_check(cloud != null and not cloud.visible, "old pit cloud stays hidden: " + cloud_name)
	var visible_children: Array[Node] = []
	for child: Node in background.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			visible_children.append(child)
	_check(visible_children.size() == 1 and visible_children[0] == ds03, "only DS03 is visible under Background", str(visible_children))
	var camera: Camera2D = _level.get_camera()
	_check(camera != null and camera.limit_right == 1952 and camera.limit_bottom == 360, "camera framing is unchanged")
	_check(_level.get_exit().position == Vector2(1840, 300), "exit placement is unchanged")
	_check((_level.get_node("World/Decorations") as Node).get_child_count() == 10, "decoration layout is unchanged")


func _test_rendered_layers() -> void:
	_section("ACTUAL RENDER: BRIDGES FIXED / SMALL RUINS MOVE / SEA + SKY RIGHT")
	_bg.visible = true
	_bg.set_clock_paused(true)

	_show_only(["G1", "G2"])
	var bridge_a: Image = await _render(0.0)
	var bridge_b: Image = await _render(12.0)
	var bridge_c: Image = await _render(30.0)
	var bridge_d: Image = await _render(60.0)
	var bridge_e: Image = await _render(64.47)
	_check(bridge_a.get_size() == Vector2i(640, 360), "render target is 640x360", str(bridge_a.get_size()))
	_check(_same_image(bridge_a, bridge_b), "G1/G2 rendered pixels are identical at 0/12 s")
	_check(_same_image(bridge_a, bridge_c), "G1/G2 rendered pixels are identical at 0/30 s")
	_check(_same_image(bridge_a, bridge_d), "G1/G2 rendered pixels are identical at 0/60 s")
	_check(_same_image(bridge_a, bridge_e), "G1/G2 rendered pixels are identical at 0/64.47 s")

	var island_times: Dictionary = {"G3": 12.7, "G4": 15.4, "G5": 14.85}
	var island_boxes: Dictionary = {
		"G3": Rect2i(31, 168, 70, 32),
		"G4": Rect2i(244, 174, 66, 44),
		"G5": Rect2i(444, 138, 91, 53),
	}
	for id: String in DYNAMIC_GROUP_IDS:
		_show_only([id])
		var base_image: Image = await _render(0.0)
		var moved_image: Image = await _render(float(island_times[id]))
		var box: Rect2i = island_boxes[id]
		var shift: Dictionary = _best_vertical_shift(base_image, moved_image, box, 3)
		_check(int(shift["dy"]) == -1, id + " rendered motion is exactly one native pixel up", str(shift))
		_check(int(shift["mismatch"]) == 0, id + " moved image matches a -1 px shift exactly", str(shift["mismatch"]))
		_check(not _same_image(base_image, moved_image), id + " is visibly not snap-frozen")

	_show_only(["SeaMain"])
	var sea_main_0: Image = await _render(0.0)
	var sea_main_8: Image = await _render(8.0)
	var sea_main_shift: Dictionary = _best_horizontal_shift(sea_main_0, sea_main_8, 300, 359, 70)
	_check(int(sea_main_shift["dx"]) == 34 and int(sea_main_shift["mismatch"]) == 0, "sea_main actually moves +34 px in 8 s", str(sea_main_shift))
	var sea_main_period: Image = await _render(304.2857142857143)
	_check(_same_image(sea_main_0, sea_main_period), "sea_main image repeats at 304.2857 s")
	var sea_main_seam: Image = await _render(59.72222222222222)
	_check(_count_clear(sea_main_seam, Rect2i(0, 330, 640, 30)) == 0, "sea_main seam has no transparent gap at t=59.722")

	_show_only(["SeaNear"])
	var sea_near_0: Image = await _render(0.0)
	var sea_near_8: Image = await _render(8.0)
	var sea_near_shift: Dictionary = _best_horizontal_shift(sea_near_0, sea_near_8, 330, 359, 90)
	_check(int(sea_near_shift["dx"]) == 58 and int(sea_near_shift["mismatch"]) == 0, "sea_near actually moves +58 px in 8 s", str(sea_near_shift))
	var sea_near_period: Image = await _render(177.5)
	_check(_same_image(sea_near_0, sea_near_period), "sea_near image repeats at 177.5 s")
	var sea_near_seam: Image = await _render(59.72222222222222)
	_check(_count_clear(sea_near_seam, Rect2i(0, 335, 640, 25)) == 0, "sea_near seam has no transparent gap at t=59.722")

	_show_only(["SkyBankLeft"])
	var sky_0: Image = await _render(0.0)
	var sky_8: Image = await _render(8.0)
	var sky_shift: Dictionary = _best_horizontal_shift(sky_0, sky_8, 56, 105, 70)
	_check(int(sky_shift["dx"]) == 50 and int(sky_shift["mismatch"]) == 0, "left sky bank actually moves +50 px in 8 s", str(sky_shift))

	_show_only(["SkyBankRight"])
	var right_sky_0: Image = await _render(0.0)
	var right_sky_8: Image = await _render(8.0)
	var right_sky_shift: Dictionary = _best_horizontal_shift(right_sky_0, right_sky_8, 43, 88, 70)
	_check(int(right_sky_shift["dx"]) == 50 and int(right_sky_shift["mismatch"]) == 0, "right sky bank actually moves +50 px in 8 s", str(right_sky_shift))

	_show_only(["SkyMidWisp"])
	var wisp_0: Image = await _render(0.0)
	var wisp_8: Image = await _render(8.0)
	var wisp_shift: Dictionary = _best_horizontal_shift(wisp_0, wisp_8, 65, 97, 40)
	_check(int(wisp_shift["dx"]) == 29 and int(wisp_shift["mismatch"]) == 0, "far wisp actually moves +29 px in 8 s", str(wisp_shift))

	_show_only(["Rocks"])
	var rocks_image: Image = await _render(0.0)
	var clear: Color = rocks_image.get_pixel(0, 0)
	_check(rocks_image.get_pixel(247, 330).is_equal_approx(clear), "runtime filter removes the 5 px old spot under debris_low")
	_check(not rocks_image.get_pixel(214, 185).is_equal_approx(clear), "other static rock remnants still render")


func _test_rendered_occlusion_and_shadows() -> void:
	_section("ACTUAL RENDER: SAME CLOUD ON BOTH BRIDGES / NO OLD CLOUD / SHADOW CLIP")
	_show_all()
	var full: Image = await _render(64.47)
	_show_only(["SeaMain"])
	var main_only: Image = await _render(64.47)
	var left_occlusion: int = _occlusion_mismatch(full, main_only, LEFT_FOOT_ROI)
	var right_occlusion: int = _occlusion_mismatch(full, main_only, RIGHT_FOOT_ROI)
	_check(left_occlusion == 0, "left bridge foot is covered by the same sea_main pixels", str(left_occlusion))
	_check(right_occlusion == 0, "right bridge foot is covered by the same sea_main pixels", str(right_occlusion))

	# Both ROIs should actually contain cloud pixels at 64.47 s, not just agree
	# on transparent sky.
	_check(_count_non_clear(main_only, LEFT_FOOT_ROI) > 0, "left foot ROI contains cloud at 64.47 s")
	_check(_count_non_clear(main_only, RIGHT_FOOT_ROI) > 0, "right foot ROI contains cloud at 64.47 s")

	_show_only(["Base", "Sky", "Groups", "Arch", "Rocks", "Debris"])
	var no_sea: Image = await _render(64.47)
	var cloud_palette: Array[Color] = _cloud_palette()
	_check(_count_palette(no_sea, RIGHT_FOOT_ROI, cloud_palette) == 0, "right foot ROI has no old static cloud pixels with sea layers hidden")
	_check(_count_palette(no_sea, LEFT_FOOT_ROI, cloud_palette) == 0, "left foot ROI has no old static cloud pixels with sea layers hidden")

	_show_only(["SeaMain"])
	var sea_zero: Image = await _render(0.0)
	_check(_region_mismatch(sea_zero, main_only, LEFT_FOOT_ROI) > 0, "left foot cloud pixels change between t=0 and t=64.47")
	_check(_region_mismatch(sea_zero, main_only, RIGHT_FOOT_ROI) > 0, "right foot cloud pixels change between t=0 and t=64.47")
	_show_only(["SeaMain", "ShadowsMain"])
	var with_shadow: Image = await _render(0.0)
	var clip: Dictionary = _shadow_clip_check(with_shadow, sea_zero, sea_zero)
	_check(int(clip["changed"]) > 0, "central shadows actually render over sea_main", str(clip["changed"]))
	_check(int(clip["outside_sea"]) == 0, "central shadows are clipped to cloud pixels", str(clip["outside_sea"]))

	_show_only(["SeaNear", "ShadowsNear"])
	var low_with: Image = await _render(0.0)
	_show_only(["SeaNear"])
	var low_without: Image = await _render(0.0)
	var low_clip: Dictionary = _shadow_clip_check(low_with, low_without, low_without)
	_check(int(low_clip["changed"]) > 0, "low shadow actually renders over sea_near", str(low_clip["changed"]))
	_check(int(low_clip["outside_sea"]) == 0, "low shadow is clipped to cloud pixels", str(low_clip["outside_sea"]))

	_show_only(["SeaMain", "ShadowsMain"])
	var shadow_high: Image = await _render(5.625)
	_show_only(["SeaMain"])
	var sea_high: Image = await _render(5.625)
	var high_clip: Dictionary = _shadow_clip_check(shadow_high, sea_high, sea_high)
	_check(int(high_clip["changed"]) > 0, "high-position central shadow still renders over cloud", str(high_clip["changed"]))
	_check(int(high_clip["outside_sea"]) == 0, "high-position central shadow stays cloud-clipped", str(high_clip["outside_sea"]))
	var shadow_zero_stats: Dictionary = _diff_stats(with_shadow, sea_zero)
	var shadow_high_stats: Dictionary = _diff_stats(shadow_high, sea_high)
	var moved: bool = (
		int(shadow_zero_stats["min_x"]) != int(shadow_high_stats["min_x"])
		or int(shadow_zero_stats["min_y"]) != int(shadow_high_stats["min_y"])
		or int(shadow_zero_stats["max_x"]) != int(shadow_high_stats["max_x"])
		or int(shadow_zero_stats["max_y"]) != int(shadow_high_stats["max_y"])
	)
	_check(moved, "rendered central shadow footprint changes with debris height", "%s vs %s" % [str(shadow_zero_stats), str(shadow_high_stats)])

	var gap_low: Dictionary = _group_gap("G5", "G2")
	var gap_left: Dictionary = _group_gap("G3", "G1")
	_check(float(gap_low["gap"]) > 0.0, "G5/G2 keep a positive air gap after native quantization", str(gap_low))
	_check(float(gap_left["gap"]) > 0.0, "G3/G1 keep a positive air gap after native quantization", str(gap_left))
	_log("G5/G2 min gap %.1f at x=%d; G3/G1 min gap %.1f at x=%d" % [
		float(gap_low["gap"]), int(gap_low["x"]), float(gap_left["gap"]), int(gap_left["x"]),
	])

	_show_all()
	_bg.visible = false


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
	var sum_x: int = 0
	var sum_y: int = 0
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
			sum_x += x
			sum_y += y
	return {
		"changed": changed,
		"min_x": min_x,
		"min_y": min_y,
		"max_x": max_x,
		"max_y": max_y,
		"cx": sum_x / maxi(1, changed),
		"cy": sum_y / maxi(1, changed),
	}


func _test_pause_reset_and_reload() -> void:
	_section("PAUSE / R / RELOAD CLOCK")
	get_tree().paused = false

	# R on a clean level: the background must rewind through the same
	# level_restart signal the real key route uses.
	await _new_level()
	var bg: CloudRuinsDS03 = _level.get_node("Background/CloudRuinsDS03") as CloudRuinsDS03
	_check(bg != null, "level background component is reachable")
	if bg == null:
		return
	for _index: int in range(30):
		await get_tree().process_frame
	var running_before: float = bg.get_background_time()
	_check(running_before > 0.05, "background clock runs during normal play", str(running_before))
	_bg_reset_seen = false
	_bg_reset_time = -1.0
	_player_reset_reason = ""
	if not bg.clock_reset.is_connected(_on_bg_clock_reset):
		bg.clock_reset.connect(_on_bg_clock_reset.bind(bg))
	var player: PrototypePlayer = _level.get_player()
	if player != null and not player.reset_performed.is_connected(_on_player_reset_seen):
		player.reset_performed.connect(_on_player_reset_seen)
	await _tap_key(KEY_R)
	await _frames(2)
	_check(_level.is_intro_active(), "R restarts the level through the real key route")
	_check(_player_reset_reason == "level_restart", "player reset signal reports level_restart", _player_reset_reason)
	_check(_bg_reset_seen, "R emits the background clock reset")
	_check(_bg_reset_time >= 0.0 and _bg_reset_time < 0.001, "R rewinds the background clock to its start time", str(_bg_reset_time))
	await get_tree().create_timer(0.20, true).timeout
	_check(bg.get_background_time() > _bg_reset_time, "background clock runs again after R")

	# Pause on another clean level. The full level suite owns the real Esc
	# resume/handoff checks; here we verify the visual clock freezes and resumes
	# without a jump.
	await _new_level()
	var pause_bg: CloudRuinsDS03 = _level.get_node("Background/CloudRuinsDS03") as CloudRuinsDS03
	for _index: int in range(30):
		await get_tree().process_frame
	var pause_before: float = pause_bg.get_background_time()
	_check(pause_before > 0.05, "background clock runs before pause", str(pause_before))
	await _tap_key(KEY_ESCAPE)
	_check(_level.is_paused(), "Esc pauses the level")
	var paused_at: float = pause_bg.get_background_time()
	await get_tree().create_timer(0.35, true).timeout
	_check(is_equal_approx(pause_bg.get_background_time(), paused_at), "pause freezes the background clock", "%.3f -> %.3f" % [paused_at, pause_bg.get_background_time()])
	# Leave the paused tree through the tree state itself; the separate full
	# level suite already covers the real Esc resume route.
	get_tree().paused = false
	var resume_at: float = pause_bg.get_background_time()
	await get_tree().create_timer(0.20, true).timeout
	var resume_after: float = pause_bg.get_background_time()
	_check(resume_after > resume_at and resume_after - resume_at < 0.35, "resume continues without a time jump", "%.3f -> %.3f" % [resume_at, resume_after])

	var old_bg: CloudRuinsDS03 = pause_bg
	_level.queue_free()
	await _frames(3)
	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _physics(6)
	var reloaded: CloudRuinsDS03 = _level.get_node("Background/CloudRuinsDS03") as CloudRuinsDS03
	_check(reloaded != null and reloaded != old_bg, "scene re-entry creates a fresh background component")
	_check(reloaded != null and reloaded.get_background_time() < 0.15, "reloaded background starts clean at t=0")


func _new_level() -> void:
	get_tree().paused = false
	if is_instance_valid(_level):
		_level.queue_free()
		await _frames(2)
	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _physics(6)



func _on_bg_clock_reset(bg: CloudRuinsDS03) -> void:
	_bg_reset_seen = true
	_bg_reset_time = bg.get_background_time()


func _on_player_reset_seen(reason: String, _count: int) -> void:
	_player_reset_reason = reason


func _show_only(names: Array) -> void:
	var selected: Dictionary = {}
	for name: String in names:
		selected[name] = true
	var any_group: bool = false
	for id: String in GROUP_IDS:
		if selected.has(id):
			any_group = true
	(_bg.get_node("Groups") as Node2D).visible = any_group
	for id: String in GROUP_IDS:
		(_bg.get_node("Groups/" + id) as Node2D).visible = selected.has(id)
	var any_sky: bool = false
	for name: String in SKY_NODE_NAMES:
		if selected.has(name):
			any_sky = true
	(_bg.get_node("Sky") as Node2D).visible = any_sky
	for name: String in SKY_NODE_NAMES:
		(_bg.get_node("Sky/" + name) as Node2D).visible = selected.has(name)
	(_bg.get_node("Base") as Node2D).visible = selected.has("Base")
	(_bg.get_node("SeaMain") as Node2D).visible = selected.has("SeaMain") or selected.has("ShadowsMain")
	(_bg.get_node("SeaMain/ShadowsMain") as Node2D).visible = selected.has("ShadowsMain")
	(_bg.get_node("Arch") as Node2D).visible = selected.has("Arch")
	(_bg.get_node("SeaNear") as Node2D).visible = selected.has("SeaNear") or selected.has("ShadowsNear")
	(_bg.get_node("SeaNear/ShadowsNear") as Node2D).visible = selected.has("ShadowsNear")
	(_bg.get_node("Rocks") as Node2D).visible = selected.has("Rocks")
	(_bg.get_node("Debris") as Node2D).visible = selected.has("Debris")


func _show_all() -> void:
	_show_only([
		"Base", "G1", "G2", "G3", "G4", "G5",
		"SkyBankLeft", "SkyBankRight", "SkyMidWisp", "SkyLowWispR",
		"SkyLeftWisp", "SkyLowWispL", "SkyHighChip",
		"SeaMain", "ShadowsMain", "Arch", "SeaNear", "ShadowsNear",
		"Rocks", "Debris",
	])


func _render(time_seconds: float) -> Image:
	_bg.set_clock_paused(true)
	_bg.set_background_time(time_seconds)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _same_image(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	return a.get_data() == b.get_data()


func _image_visual_equal(imported: Image, source: Image) -> bool:
	if imported.get_size() != source.get_size():
		return false
	var imported_data: PackedByteArray = imported.get_data()
	var source_data: PackedByteArray = source.get_data()
	if imported_data.size() != source_data.size():
		return false
	for index: int in range(0, source_data.size(), 4):
		var source_alpha: int = source_data[index + 3]
		var imported_alpha: int = imported_data[index + 3]
		if source_alpha == 0:
			# Godot's lossless import may border-fix RGB under fully transparent
			# pixels. That is invisible; alpha must still stay transparent.
			if imported_alpha != 0:
				return false
			continue
		if (
			imported_data[index] != source_data[index]
			or imported_data[index + 1] != source_data[index + 1]
			or imported_data[index + 2] != source_data[index + 2]
			or imported_alpha != source_alpha
		):
			return false
	return true


func _best_vertical_shift(a: Image, b: Image, box: Rect2i, radius: int) -> Dictionary:
	var width: int = a.get_width()
	var height: int = a.get_height()
	var ad: PackedByteArray = a.get_data()
	var bd: PackedByteArray = b.get_data()
	var best_dy: int = 0
	var best_mismatch: int = 1 << 30
	for dy: int in range(-radius, radius + 1):
		var mismatch: int = 0
		for y: int in range(maxi(box.position.y + 1, radius), mini(box.end.y - 1, height - radius)):
			for x: int in range(box.position.x + 1, box.end.x - 1):
				var ia: int = (y * width + x) * 4
				var ib: int = ((y + dy) * width + x) * 4
				if ad[ia] != bd[ib] or ad[ia + 1] != bd[ib + 1] or ad[ia + 2] != bd[ib + 2] or ad[ia + 3] != bd[ib + 3]:
					mismatch += 1
		if mismatch < best_mismatch:
			best_mismatch = mismatch
			best_dy = dy
	return {"dy": best_dy, "mismatch": best_mismatch}


func _best_horizontal_shift(
	a: Image, b: Image, y_min: int, y_max: int, max_dx: int
) -> Dictionary:
	var width: int = a.get_width()
	var ad: PackedByteArray = a.get_data()
	var bd: PackedByteArray = b.get_data()
	var best_dx: int = 0
	var best_mismatch: int = 1 << 30
	for dx: int in range(0, max_dx + 1):
		var mismatch: int = 0
		for y: int in range(y_min, y_max + 1):
			for x: int in range(0, width - dx):
				var ia: int = (y * width + x) * 4
				var ib: int = (y * width + x + dx) * 4
				if ad[ia] != bd[ib] or ad[ia + 1] != bd[ib + 1] or ad[ia + 2] != bd[ib + 2] or ad[ia + 3] != bd[ib + 3]:
					mismatch += 1
		if mismatch < best_mismatch:
			best_mismatch = mismatch
			best_dx = dx
	return {"dx": best_dx, "mismatch": best_mismatch}


func _region_mismatch(a: Image, b: Image, roi: Rect2i) -> int:
	var width: int = a.get_width()
	var ad: PackedByteArray = a.get_data()
	var bd: PackedByteArray = b.get_data()
	var mismatch: int = 0
	for y: int in range(roi.position.y, roi.end.y):
		for x: int in range(roi.position.x, roi.end.x):
			var index: int = (y * width + x) * 4
			if ad[index] != bd[index] or ad[index + 1] != bd[index + 1] or ad[index + 2] != bd[index + 2] or ad[index + 3] != bd[index + 3]:
				mismatch += 1
	return mismatch


func _occlusion_mismatch(full: Image, sea_only: Image, roi: Rect2i) -> int:
	var width: int = full.get_width()
	var fd: PackedByteArray = full.get_data()
	var sd: PackedByteArray = sea_only.get_data()
	var clear: Color = sea_only.get_pixel(0, 0)
	var clear_bytes: PackedByteArray = _color_bytes(clear)
	var mismatch: int = 0
	for y: int in range(roi.position.y, roi.end.y):
		for x: int in range(roi.position.x, roi.end.x):
			var index: int = (y * width + x) * 4
			var is_cloud: bool = (
				sd[index] != clear_bytes[0] or sd[index + 1] != clear_bytes[1]
				or sd[index + 2] != clear_bytes[2] or sd[index + 3] != clear_bytes[3]
			)
			if not is_cloud:
				continue
			if fd[index] != sd[index] or fd[index + 1] != sd[index + 1] or fd[index + 2] != sd[index + 2] or fd[index + 3] != sd[index + 3]:
				mismatch += 1
	return mismatch


func _shadow_clip_check(with_shadow: Image, without_shadow: Image, sea_reference: Image) -> Dictionary:
	var width: int = with_shadow.get_width()
	var height: int = with_shadow.get_height()
	var wd: PackedByteArray = with_shadow.get_data()
	var od: PackedByteArray = without_shadow.get_data()
	var sd: PackedByteArray = sea_reference.get_data()
	var clear: Color = sea_reference.get_pixel(0, 0)
	var clear_bytes: PackedByteArray = _color_bytes(clear)
	var changed: int = 0
	var outside_sea: int = 0
	for y: int in range(height):
		for x: int in range(width):
			var index: int = (y * width + x) * 4
			if wd[index] == od[index] and wd[index + 1] == od[index + 1] and wd[index + 2] == od[index + 2] and wd[index + 3] == od[index + 3]:
				continue
			changed += 1
			var sea_is_opaque: bool = (
				sd[index] != clear_bytes[0] or sd[index + 1] != clear_bytes[1]
				or sd[index + 2] != clear_bytes[2] or sd[index + 3] != clear_bytes[3]
			)
			if not sea_is_opaque:
				outside_sea += 1
	return {"changed": changed, "outside_sea": outside_sea}


func _group_gap(upper_id: String, lower_id: String) -> Dictionary:
	var upper: Dictionary = _group_spec(upper_id)
	var lower: Dictionary = _group_spec(lower_id)
	if upper.is_empty() or lower.is_empty():
		return {"gap": 0.0, "x": -1}
	var upper_image: Image = (DATA.TEXTURES[upper["file"]] as Texture2D).get_image()
	var lower_image: Image = (DATA.TEXTURES[lower["file"]] as Texture2D).get_image()
	upper_image.convert(Image.FORMAT_RGBA8)
	lower_image.convert(Image.FORMAT_RGBA8)
	var upper_dy: int = _dynamic_dy_at(upper, 0.0)
	var lower_dy: int = _dynamic_dy_at(lower, 0.0)
	var min_gap: float = 99999.0
	var best_x: int = -1
	for x: int in range(640):
		var upper_bottom: int = _opaque_bottom(
			upper_image, x - int(upper["offset"][0]), int(upper["size"][0])
		)
		var lower_top: int = _opaque_top(
			lower_image, x - int(lower["offset"][0]), int(lower["size"][0])
		)
		if upper_bottom < 0 or lower_top < 0:
			continue
		var upper_y: int = int(upper["offset"][1]) + upper_dy + upper_bottom
		var lower_y: int = int(lower["offset"][1]) + lower_dy + lower_top
		var gap: float = float(lower_y - upper_y)
		if gap > 0.0 and gap < min_gap:
			min_gap = gap
			best_x = x
	return {"gap": min_gap if best_x >= 0 else 0.0, "x": best_x}


func _group_spec(id: String) -> Dictionary:
	for group: Dictionary in DATA.CONFIG["groups"]:
		if String(group["id"]) == id:
			return group
	return {}


func _dynamic_dy_at(spec: Dictionary, time_seconds: float) -> int:
	var float_spec: Dictionary = spec.get("float", {})
	if not bool(float_spec.get("enabled", false)):
		return 0
	var raw: float = float(float_spec["amp"]) * sin(
		TAU * (time_seconds + float(float_spec["phase"])) / float(float_spec["period"])
	)
	return -1 if raw < -0.25 else 0


func _opaque_top(image: Image, x: int, width: int) -> int:
	if x < 0 or x >= width:
		return -1
	for y: int in range(image.get_height()):
		if image.get_pixel(x, y).a > 0.0:
			return y
	return -1


func _opaque_bottom(image: Image, x: int, width: int) -> int:
	if x < 0 or x >= width:
		return -1
	for y: int in range(image.get_height() - 1, -1, -1):
		if image.get_pixel(x, y).a > 0.0:
			return y
	return -1


func _count_clear(image: Image, roi: Rect2i) -> int:
	var clear: Color = image.get_pixel(0, 0)
	var count: int = 0
	for y: int in range(roi.position.y, roi.end.y):
		for x: int in range(roi.position.x, roi.end.x):
			if image.get_pixel(x, y).is_equal_approx(clear):
				count += 1
	return count


func _count_non_clear(image: Image, roi: Rect2i) -> int:
	var clear: Color = image.get_pixel(0, 0)
	var count: int = 0
	for y: int in range(roi.position.y, roi.end.y):
		for x: int in range(roi.position.x, roi.end.x):
			if not image.get_pixel(x, y).is_equal_approx(clear):
				count += 1
	return count


func _count_palette(image: Image, roi: Rect2i, palette: Array[Color]) -> int:
	var count: int = 0
	for y: int in range(roi.position.y, roi.end.y):
		for x: int in range(roi.position.x, roi.end.x):
			var pixel: Color = image.get_pixel(x, y)
			for color: Color in palette:
				if pixel.r8 == color.r8 and pixel.g8 == color.g8 and pixel.b8 == color.b8:
					count += 1
					break
	return count


func _cloud_palette() -> Array[Color]:
	var palette: Array[Color] = []
	for sea_name: String in ["sea_main", "sea_near"]:
		var path: String = "res://assets/backgrounds/cloud_ruins_ds03/common/" + sea_name + ".png"
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		image.convert(Image.FORMAT_RGBA8)
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a8 == 0:
					continue
				var color: Color = Color8(pixel.r8, pixel.g8, pixel.b8, 255)
				var exists: bool = false
				for existing: Color in palette:
					if existing.r8 == color.r8 and existing.g8 == color.g8 and existing.b8 == color.b8:
						exists = true
						break
				if not exists:
					palette.append(color)
	_check(palette.size() == 8, "cloud palette is the DS03 8-color set", str(palette.size()))
	return palette


func _color_bytes(color: Color) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(color.r8)
	bytes.append(color.g8)
	bytes.append(color.b8)
	bytes.append(color.a8)
	return bytes


func _config_items(config: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	items.append(config["base"])
	for section: String in ["groups", "static", "sky", "sea", "shadows", "debris"]:
		for item: Dictionary in config[section]:
			items.append(item)
	return items


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _sha256(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode().to_lower()


func _int_array_equal(value: Variant, expected: Array) -> bool:
	if not value is Array:
		return false
	var actual: Array = value as Array
	if actual.size() != expected.size():
		return false
	for index: int in range(actual.size()):
		if int(actual[index]) != int(expected[index]):
			return false
	return true


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap_key(key: Key) -> void:
	_send_key(key, true)
	await get_tree().process_frame
	_send_key(key, false)
	await get_tree().process_frame


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


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
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d rendered=%s" % [_pass_count, _fail_count, str(_rendered)])
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log_lines) + "\n")
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
