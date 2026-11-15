@tool
class_name CloudRuinsDS03
extends Node2D

## Screen-fixed 640x360 dynamic DS03 cloud-ruins background.
##
## Source of truth: assets/backgrounds/cloud_ruins_ds03/runtime_config.json
## (byte copy from the read-only DS03 preview) and the generated
## scripts/backgrounds/cloud_ruins_ds03_data.gd. The component draws the same
## layer order as DS03:
##   base sky -> sky clouds -> G3/G4/G5 -> G1/G2 -> sea_main + shadows
##   -> arch_stone -> sea_near + shadow_low -> rock remnants -> floating debris
##
## G1/G2 are never moved. G3/G4/G5 use the DS03 formula, but a native 640x360
## frame cannot show the web preview's half-logical-pixel positions. They are
## deliberately quantized to two adjacent native pixels: 0 for the neutral and
## positive lobe, -1 for the web preview's negative half-state (formula < -0.25).
## That keeps the actual rendered peak-to-peak at exactly 1 logical pixel and
## never moves a small ruin downward into the bridge. The web preview also shows
## +0.5 on the positive lobe; that extra half-pixel state has no native analogue.
##
## Sky/sea positions use integer native pixels. Sea phase advances only to the
## right; the two 1278 px copies are adjacent, so the seam has no gap. Shadows
## are children of their sea layer with CLIP_CHILDREN_AND_DRAW, which reproduces
## DS03's source-atop clip to cloud pixels without CPU image rebuilding.

const DATA := preload("res://scripts/backgrounds/cloud_ruins_ds03_data.gd")
const CANVAS_WIDTH: int = 640
const CANVAS_HEIGHT: int = 360
const SEA_PERIOD: int = 1278
const SKY_WRAP_MARGIN: float = 8.0
const GROUP_NEGATIVE_THRESHOLD: float = -0.25

signal clock_reset

const LAYER_ORDER: Array[String] = [
	"Base", "Sky", "Groups", "SeaMain", "Arch", "SeaNear", "Rocks", "Debris",
]
const GROUP_NODE_NAMES: Array[String] = ["G1", "G2", "G3", "G4", "G5"]
const SKY_NODE_BY_NAME: Dictionary = {
	"sky_bank_left": "SkyBankLeft",
	"sky_bank_right": "SkyBankRight",
	"sky_mid_wisp": "SkyMidWisp",
	"sky_low_wisp_r": "SkyLowWispR",
	"sky_left_wisp": "SkyLeftWisp",
	"sky_low_wisp_l": "SkyLowWispL",
	"sky_high_chip": "SkyHighChip",
}

var _time: float = 0.0
var _clock_paused: bool = false
var _layer_nodes: Dictionary = {}
var _draw_nodes: Array[CanvasItem] = []
var _groups_by_id: Dictionary = {}
var _sea_by_name: Dictionary = {}
var _debris_by_name: Dictionary = {}
var _static_by_id: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_index_config()
	_setup_nodes()
	if Engine.is_editor_hint():
		# The editor sees a deterministic t=0 preview, not a running clock.
		set_process(false)
		_time = 0.0
	else:
		set_process(true)
		_connect_player_reset()
	_refresh()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _clock_paused or get_tree().paused:
		return
	_time += delta
	_refresh()


func set_background_time(seconds: float) -> void:
	_time = maxf(0.0, seconds)
	_refresh()


func get_background_time() -> float:
	return _time


func set_clock_paused(paused: bool) -> void:
	_clock_paused = paused


func is_clock_paused() -> bool:
	return _clock_paused


func reset_background_clock() -> void:
	_time = 0.0
	_clock_paused = false
	clock_reset.emit()
	_refresh()


func get_canvas_size() -> Vector2i:
	return Vector2i(CANVAS_WIDTH, CANVAS_HEIGHT)


func get_group_render_dy(id: String) -> int:
	var spec: Dictionary = _groups_by_id.get(id, {})
	if spec.is_empty():
		return 0
	return _group_dy(spec)


func get_sea_phase(name: String) -> int:
	var spec: Dictionary = _sea_by_name.get(name, {})
	if spec.is_empty():
		return 0
	return _sea_phase_i(spec)


func get_sky_x(name: String) -> int:
	for spec: Dictionary in DATA.CONFIG["sky"]:
		if String(spec["name"]) == name:
			return _sky_x(spec)
	return 0


func get_shadow_positions(surface: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sea_spec: Dictionary = _sea_by_name.get(surface, {})
	if sea_spec.is_empty():
		return result
	var phase: int = _sea_phase_i(sea_spec)
	for shadow: Dictionary in DATA.CONFIG["shadows"]:
		if String(shadow["surface"]) != surface:
			continue
		var placement: Dictionary = _shadow_placement(shadow, sea_spec, phase)
		result.append(placement)
	return result


func get_debris_positions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rock: Dictionary in DATA.CONFIG["debris"]:
		result.append({
			"name": String(rock["name"]),
			"x": int(rock["x0"]),
			"y": roundi(float(rock["y0"]) + _rock_bob(rock)),
			"bob": _rock_bob(rock),
		})
	return result


func _index_config() -> void:
	for group: Dictionary in DATA.CONFIG["groups"]:
		_groups_by_id[String(group["id"])] = group
	for sea: Dictionary in DATA.CONFIG["sea"]:
		_sea_by_name[String(sea["name"])] = sea
	for debris: Dictionary in DATA.CONFIG["debris"]:
		_debris_by_name[String(debris["name"])] = debris
	for item: Dictionary in DATA.CONFIG["static"]:
		_static_by_id[String(item["id"])] = item


func _setup_nodes() -> void:
	for layer_name: String in LAYER_ORDER:
		var layer: Node2D = get_node_or_null(layer_name) as Node2D
		if layer == null:
			push_error("CloudRuinsDS03: missing layer " + layer_name)
			continue
		_layer_nodes[layer_name] = layer
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_draw_nodes.append(layer)
	var base_node: CanvasItem = _layer_node("Base")
	var sea_main_node: CanvasItem = _layer_node("SeaMain")
	var arch_node: CanvasItem = _layer_node("Arch")
	var sea_near_node: CanvasItem = _layer_node("SeaNear")
	var rocks_node: CanvasItem = _layer_node("Rocks")
	var debris_node: CanvasItem = _layer_node("Debris")
	_connect(base_node, _draw_base.bind(base_node))
	_connect(sea_main_node, _draw_sea_main.bind(sea_main_node))
	_connect(arch_node, _draw_arch.bind(arch_node))
	_connect(sea_near_node, _draw_sea_near.bind(sea_near_node))
	_connect(rocks_node, _draw_rocks.bind(rocks_node))
	_connect(debris_node, _draw_debris.bind(debris_node))

	var sea_main: Node2D = _layer_node("SeaMain")
	var sea_near: Node2D = _layer_node("SeaNear")
	sea_main.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	sea_near.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var shadows_main_node: CanvasItem = sea_main.get_node("ShadowsMain") as CanvasItem
	var shadows_near_node: CanvasItem = sea_near.get_node("ShadowsNear") as CanvasItem
	_connect(shadows_main_node, _draw_shadows_main.bind(shadows_main_node))
	_connect(shadows_near_node, _draw_shadows_near.bind(shadows_near_node))
	# Child canvas items keep their command list when the sea parent redraws, so
	# they must be refreshed explicitly or shadow position/alpha freezes at t=0.
	_draw_nodes.append(shadows_main_node)
	_draw_nodes.append(shadows_near_node)

	var groups_root: Node2D = _layer_node("Groups")
	for id: String in GROUP_NODE_NAMES:
		var holder: Node2D = groups_root.get_node_or_null(id) as Node2D
		if holder == null:
			push_error("CloudRuinsDS03: missing group " + id)
			continue
		holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_draw_nodes.append(holder)
		_connect(holder, _draw_group.bind(holder, id))

	var sky_root: Node2D = _layer_node("Sky")
	for spec: Dictionary in DATA.CONFIG["sky"]:
		var node_name: String = String(SKY_NODE_BY_NAME.get(String(spec["name"]), ""))
		var holder: Node2D = sky_root.get_node_or_null(node_name) as Node2D
		if holder == null:
			push_error("CloudRuinsDS03: missing sky layer " + String(spec["name"]))
			continue
		holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_draw_nodes.append(holder)
		_connect(holder, _draw_sky.bind(holder, spec))


func _connect(node: CanvasItem, callback: Callable) -> void:
	if node == null:
		return
	if not node.draw.is_connected(callback):
		node.draw.connect(callback)


func _layer_node(layer_name: String) -> Node2D:
	return _layer_nodes.get(layer_name) as Node2D


func _refresh() -> void:
	for node: CanvasItem in _draw_nodes:
		if is_instance_valid(node):
			node.queue_redraw()


func _connect_player_reset() -> void:
	var node: Node = get_parent()
	while node != null:
		var player: Node = node.get_node_or_null("World/Player")
		if player != null and player.has_signal("reset_performed"):
			var callback: Callable = Callable(self, "_on_player_reset_performed")
			if not player.is_connected("reset_performed", callback):
				player.connect("reset_performed", callback)
			return
		node = node.get_parent()


func _on_player_reset_performed(reason: String, _count: int) -> void:
	# Only a whole-level R restart rewinds the background. Falling to a
	# checkpoint must not jump the clouds or small ruins back to t=0.
	if reason == "level_restart":
		reset_background_clock()


func _draw_base(canvas: CanvasItem) -> void:
	var spec: Dictionary = DATA.CONFIG["base"]
	_draw_texture(canvas, spec, int(spec["offset"][0]), int(spec["offset"][1]))


func _draw_sky(canvas: CanvasItem, spec: Dictionary) -> void:
	var texture: Texture2D = _texture(spec)
	if texture == null:
		return
	var width: int = int(spec["size"][0])
	var height: int = int(spec["size"][1])
	var x: int = _sky_x(spec)
	if x >= CANVAS_WIDTH or x + width <= 0:
		return
	canvas.draw_texture_rect(
		texture,
		Rect2(x, int(spec["y0"]), width, height),
		false,
		Color.WHITE
	)


func _draw_group(canvas: CanvasItem, id: String) -> void:
	var spec: Dictionary = _groups_by_id.get(id, {})
	if spec.is_empty():
		return
	var texture: Texture2D = _texture(spec)
	if texture == null:
		return
	canvas.draw_texture_rect(
		texture,
		Rect2(
			int(spec["offset"][0]),
			int(spec["offset"][1]) + _group_dy(spec),
			int(spec["size"][0]),
			int(spec["size"][1])
		),
		false,
		Color.WHITE
	)


func _draw_sea_main(canvas: CanvasItem) -> void:
	_draw_sea(canvas, "sea_main")


func _draw_sea_near(canvas: CanvasItem) -> void:
	_draw_sea(canvas, "sea_near")


func _draw_sea(canvas: CanvasItem, sea_name: String) -> void:
	var spec: Dictionary = _sea_by_name.get(sea_name, {})
	if spec.is_empty():
		return
	var texture: Texture2D = _texture(spec)
	if texture == null:
		return
	var phase: int = _sea_phase_i(spec)
	# Copy at phase-P first, then phase, exactly like DS03. Integer positions and
	# a 1278 px period keep the two copies adjacent with no seam gap.
	for base_x: int in [phase - SEA_PERIOD, phase]:
		var left: int = maxi(base_x, 0)
		var right: int = mini(base_x + SEA_PERIOD, CANVAS_WIDTH)
		if right <= left:
			continue
		var source_x: int = left - base_x
		var width: int = right - left
		canvas.draw_texture_rect_region(
			texture,
			Rect2(left, 0, width, CANVAS_HEIGHT),
			Rect2(source_x, 0, width, CANVAS_HEIGHT)
		)


func _draw_shadows_main(canvas: CanvasItem) -> void:
	_draw_shadows(canvas, "sea_main")


func _draw_shadows_near(canvas: CanvasItem) -> void:
	_draw_shadows(canvas, "sea_near")


func _draw_shadows(canvas: CanvasItem, surface: String) -> void:
	var sea_spec: Dictionary = _sea_by_name.get(surface, {})
	if sea_spec.is_empty():
		return
	var phase: int = _sea_phase_i(sea_spec)
	for shadow: Dictionary in DATA.CONFIG["shadows"]:
		if String(shadow["surface"]) != surface:
			continue
		var texture: Texture2D = _texture(shadow)
		if texture == null:
			continue
		var placement: Dictionary = _shadow_placement(shadow, sea_spec, phase)
		canvas.draw_texture_rect(
			texture,
			Rect2(
				roundi(float(placement["sx"])),
				roundi(float(placement["sy"])),
				int(placement["width"]),
				int(placement["height"])
			),
			false,
			Color(1.0, 1.0, 1.0, float(placement["alpha"]))
		)


func _draw_arch(canvas: CanvasItem) -> void:
	var spec: Dictionary = _static_by_id.get("arch_stone", {})
	if spec.is_empty():
		return
	_draw_texture(canvas, spec, int(spec["offset"][0]), int(spec["offset"][1]))


func _draw_rocks(canvas: CanvasItem) -> void:
	var spec: Dictionary = _static_by_id.get("rock_remnants_static", {})
	if spec.is_empty():
		return
	var texture: Texture2D = _texture(spec)
	if texture == null:
		return
	var offset_x: int = int(spec["offset"][0])
	var offset_y: int = int(spec["offset"][1])
	var width: int = int(spec["size"][0])
	var height: int = int(spec["size"][1])
	var masks: Array = spec.get("exclude_mask_rects", [])
	if masks.is_empty():
		canvas.draw_texture_rect_region(
			texture,
			Rect2(offset_x, offset_y, width, height),
			Rect2(0, 0, width, height)
		)
		return
	# Runtime-only filter for the isolated 5 px old shadow/blade under
	# debris_low. The source PNG is never modified. Split drawing around the
	# excluded local rectangle instead of rebuilding the image.
	var rect: Array = masks[0]
	var cut_x0: int = int(rect[0])
	var cut_y0: int = int(rect[1])
	var cut_x1: int = int(rect[2])
	var cut_y1: int = int(rect[3])
	if cut_y0 > 0:
		_draw_rock_region(canvas, texture, offset_x, offset_y, 0, 0, width, cut_y0)
	if cut_y1 > cut_y0:
		if cut_x0 > 0:
			_draw_rock_region(
				canvas, texture, offset_x, offset_y, 0, cut_y0, cut_x0, cut_y1 - cut_y0
			)
		if cut_x1 < width:
			_draw_rock_region(
				canvas,
				texture,
				offset_x,
				offset_y,
				cut_x1,
				cut_y0,
				width - cut_x1,
				cut_y1 - cut_y0
			)
	if cut_y1 < height:
		_draw_rock_region(
			canvas, texture, offset_x, offset_y, 0, cut_y1, width, height - cut_y1
		)


func _draw_rock_region(
	canvas: CanvasItem,
	texture: Texture2D,
	offset_x: int,
	offset_y: int,
	source_x: int,
	source_y: int,
	width: int,
	height: int
) -> void:
	if width <= 0 or height <= 0:
		return
	canvas.draw_texture_rect_region(
		texture,
		Rect2(offset_x + source_x, offset_y + source_y, width, height),
		Rect2(source_x, source_y, width, height)
	)


func _draw_debris(canvas: CanvasItem) -> void:
	for rock: Dictionary in DATA.CONFIG["debris"]:
		var texture: Texture2D = _texture(rock)
		if texture == null:
			continue
		var y: int = roundi(float(rock["y0"]) + _rock_bob(rock))
		canvas.draw_texture_rect(
			texture,
			Rect2(int(rock["x0"]), y, int(rock["size"][0]), int(rock["size"][1])),
			false,
			Color.WHITE
		)


func _draw_texture(canvas: CanvasItem, spec: Dictionary, x: int, y: int) -> void:
	var texture: Texture2D = _texture(spec)
	if texture == null:
		return
	canvas.draw_texture_rect(
		texture,
		Rect2(x, y, int(spec["size"][0]), int(spec["size"][1])),
		false,
		Color.WHITE
	)


func _texture(spec: Dictionary) -> Texture2D:
	return DATA.TEXTURES.get(String(spec["file"])) as Texture2D


func _group_dy(spec: Dictionary) -> int:
	var float_spec: Dictionary = spec.get("float", {})
	if not bool(float_spec.get("enabled", false)):
		return 0
	var raw: float = float(float_spec["amp"]) * sin(
		TAU * (_time + float(float_spec["phase"])) / float(float_spec["period"])
	)
	# Native 640x360 cannot show the web preview's +0.5/-0.5 pair. Keep the
	# original offset for neutral/positive values and use -1 only for the
	# web preview's negative half-state. Actual peak-to-peak is 1 px.
	return -1 if raw < GROUP_NEGATIVE_THRESHOLD else 0


func _sky_x(spec: Dictionary) -> int:
	var cycle: float = float(
		CANVAS_WIDTH + int(spec["size"][0]) + int(spec["wrap_gap"])
	)
	var x: float = float(spec["x0"]) + fposmod(float(spec["speed"]) * _time, cycle)
	if x > float(CANVAS_WIDTH) + SKY_WRAP_MARGIN:
		x -= cycle
	return roundi(x)


func _sea_phase_i(spec: Dictionary) -> int:
	return roundi(fposmod(float(spec["speed"]) * _time, float(SEA_PERIOD))) % SEA_PERIOD


func _rock_bob(rock: Dictionary) -> float:
	return float(rock["amp_y"]) * sin(
		TAU * _time / float(rock["period"]) + float(rock["phase"])
	)


func _shadow_placement(
	shadow: Dictionary,
	sea_spec: Dictionary,
	phase: int
) -> Dictionary:
	var rock: Dictionary = _debris_by_name.get(String(shadow["rock"]), {})
	if rock.is_empty():
		return {}
	var bob: float = _rock_bob(rock)
	var amp: float = maxf(0.1, float(rock["amp_y"]))
	var high: bool = bob < -0.5 * float(rock["amp_y"])
	var grow: int = 1 if high and String(shadow["name"]) != "shadow_low" else 0
	var sx: float
	var alpha: float
	if String(shadow["name"]) == "shadow_low":
		sx = float(rock["x0"]) + float(shadow["dx"]) - 0.2 * bob
		alpha = clampf(1.0 + 0.12 * (bob / amp), 0.88, 1.0)
	else:
		sx = float(rock["x0"]) + float(shadow["dx"]) - 0.4 * bob
		alpha = clampf(1.0 + 0.3 * (bob / amp), 0.7, 1.0)
	var width: int = int(shadow["size"][0])
	var idx: int = clampi(floori(sx + float(width) / 2.0), 0, CANVAS_WIDTH - 1)
	var top: Array = sea_spec["top"]
	var surf: int = int(top[posmod(idx - phase, SEA_PERIOD)])
	var sy: float
	if String(shadow["name"]) == "shadow_low":
		sy = float(surf) + float(shadow["dy"]) - 0.3 * bob
	else:
		sy = float(surf) + float(shadow["dy"]) - 0.5 * bob
	return {
		"name": String(shadow["name"]),
		"surface": String(shadow["surface"]),
		"sx": sx,
		"sy": sy,
		"alpha": alpha,
		"width": width + grow * 2,
		"height": int(shadow["size"][1]) + grow,
		"bob": bob,
		"high": high,
		"grow": grow,
		"cloud_top": surf,
	}
