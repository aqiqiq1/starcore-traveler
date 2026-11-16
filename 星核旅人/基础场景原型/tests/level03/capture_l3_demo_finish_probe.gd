extends Node

## Probe (2026-11-16 demo-finish pass): measure what is really visible at the
## wall's bottom edge and at the right end of the building, before any fix.
##   Godot --path . res://tests/level03/capture_l3_demo_finish_probe.tscn
##
## SETUP is explicit: the gate recovery point (defeated guard, carried core),
## the gate opened with a real E press, then the player is pinned at fixed x.
## Nothing here changes gameplay; it only reads rendered pixels.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const DIR: String = "res://screenshots/level03_demo_finish_20261116/probe"

var _level: Level03
var _player: L3Player
var _gate: L3Gate


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _phys(24)
	_player = _level.get_player()
	_gate = _level.get_gate()
	_level.debug_setup_gate_with_key(_gate.global_position.x - 180.0)
	await _phys(10)
	_level.debug_place_player_at(Vector2(_gate.global_position.x - 10.0, 320.0))
	await _phys(6)
	Input.action_press(&"interact")
	await _phys(1)
	Input.action_release(&"interact")
	await _phys(80)
	print("PROBE gate_open=%s progress=%.2f" % [_gate.is_open(), _gate.get_plate_progress()])
	print("PROBE wall_rect=%s fg=%s" % [
		str(_gate.get_wall_world_rect()),
		str(_gate.get_foreground_world_rects())])
	await _probe_wall_bottom(2455.0)
	await _probe_foot_leaks()
	await _probe_fix_ab()
	await _probe_decor(2455.0)
	await _probe_completion_view()
	_level.queue_free()
	await _phys(3)
	print("PROBE_DONE")
	get_tree().quit(0)


func _phys(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _shot(file_name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if not file_name.is_empty():
		image.save_png(ProjectSettings.globalize_path(DIR + "/" + file_name))
		print("CAPTURED ", file_name)
	return image


func _pin(x: float) -> void:
	_level.debug_place_player_at(Vector2(x, 320.0))


## Freeze the frame, then expose it with and without the player's own visuals.
func _frozen_pair(prefix: String) -> Array:
	get_tree().paused = true
	await get_tree().process_frame
	var hud: L3HUD = _level.get_hud()
	var hud_was: bool = hud.visible
	hud.visible = false
	var a: Image = await _shot(prefix + "_with.png")
	_player.visible = false
	var key_pickup: CanvasItem = _level.get_node_or_null("KeyCorePickup") as CanvasItem
	var key_was: bool = key_pickup != null and key_pickup.visible
	if key_pickup != null:
		key_pickup.visible = false
	await get_tree().process_frame
	var b: Image = await _shot(prefix + "_without.png")
	_player.visible = true
	if key_pickup != null:
		key_pickup.visible = key_was
	hud.visible = hud_was
	get_tree().paused = false
	await get_tree().process_frame
	return [a, b]


func _diff(a: Image, b: Image) -> Dictionary:
	var min_y: int = 9999
	var max_y: int = -1
	var min_x: int = 9999
	var max_x: int = -1
	var count: int = 0
	for py: int in range(0, a.get_height()):
		for px: int in range(0, a.get_width()):
			if a.get_pixel(px, py) != b.get_pixel(px, py):
				count += 1
				min_y = mini(min_y, py)
				max_y = maxi(max_y, py)
				min_x = mini(min_x, px)
				max_x = maxi(max_x, px)
	return {"count": count, "min_x": min_x, "max_x": max_x, "min_y": min_y, "max_y": max_y}


func _probe_wall_bottom(x: float) -> void:
	print("[A] wall bottom rows at player x=%.0f" % x)
	_pin(x)
	await _phys(6)
	get_tree().paused = true
	await get_tree().process_frame
	var image: Image = await _shot("a01_wall_bottom_idle.png")
	get_tree().paused = false
	await get_tree().process_frame
	for wx: float in [2460.0, 2480.0, 2500.0, 2515.0]:
		var sx: int = int(round(wx - 1880.0))
		var rows: String = ""
		for wy: int in range(313, 328):
			var c: Color = image.get_pixel(sx, wy)
			rows += "%d:%02x%02x%02x " % [wy, int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]
		print("  screen x=%d (world %.0f) " % [sx, wx], rows)
	for state: String in ["idle", "walk", "attack"]:
		if state == "walk":
			Input.action_press(&"move_right")
		elif state == "attack":
			_player.request_attack()
		for _i: int in range(4):
			_pin(x)
			await get_tree().physics_frame
		var pair: Array = await _frozen_pair("a02_leak_" + state)
		if state == "walk":
			Input.action_release(&"move_right")
		if state == "attack":
			_player.cancel_attack()
		var d: Dictionary = _diff(pair[0], pair[1])
		print("  [%s] visible-pixel diff count=%d bbox x %d..%d y %d..%d" % [
			state, d["count"], d["min_x"], d["max_x"], d["min_y"], d["max_y"]])
	# Zoom crop of the wall's bottom edge for a visual check (4x nearest).
	_pin(x)
	await _phys(6)
	get_tree().paused = true
	await get_tree().process_frame
	var crop: Image = (await _shot("a03_wall_bottom_full.png")).get_region(
		Rect2i(540, 296, 100, 56))
	crop.resize(100 * 4, 56 * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(DIR + "/a03_wall_bottom_zoom4x.png"))
	print("CAPTURED a03_wall_bottom_zoom4x.png")
	get_tree().paused = false
	await get_tree().process_frame


## Everywhere the body stands behind a foreground piece (the gate's jamb foot
## at 2396..2417 and the wall from 2452), measure the really visible pixels.
func _probe_foot_leaks() -> void:
	print("[A2] visible body pixels behind the foreground run")
	for x: float in [2398.0, 2406.0, 2414.0, 2446.0, 2455.0]:
		for state: String in ["idle", "walk"]:
			if state == "walk":
				Input.action_press(&"move_right")
			for _i: int in range(4):
				_pin(x)
				await get_tree().physics_frame
			var pair: Array = await _frozen_pair("a04_foot_%s_%d" % [state, int(x)])
			if state == "walk":
				Input.action_release(&"move_right")
			var d: Dictionary = _diff(pair[0], pair[1])
			print("  x=%.0f %s visible-pixel diff count=%d bbox y %d..%d" % [
				x, state, d["count"], d["min_y"], d["max_y"]])


## Same build, same body: A/B of the foot/seam fills only (runtime switch, no
## file change). Proves the 1 px leak existed and that the fix removes it.
func _probe_fix_ab() -> void:
	print("[A3] foot/seam fill A/B on the same build")
	var fills: Array[CanvasItem] = []
	for node_name: String in ["PillarBaseFill", "PillarBaseContact", "SeamBaseBacking"]:
		var node: CanvasItem = _gate.get_node_or_null(node_name) as CanvasItem
		if node != null:
			fills.append(node)
	var fg: L3GateDepthWall = _gate.get_node_or_null("WallRightForeground") as L3GateDepthWall
	if fg == null:
		print("  SKIP: no foreground wall piece")
		return
	var drop: float = fg.base_drop
	# OFF: the previous art-only base
	for node: CanvasItem in fills:
		node.visible = false
	fg.base_drop = 0.0
	fg.queue_redraw()
	await _phys(4)
	for state: String in ["idle", "walk", "attack"]:
		await _foot_state_ab(state, "d01_before_fix_")
	# ON: the shipped base
	for node: CanvasItem in fills:
		node.visible = true
	fg.base_drop = drop
	fg.queue_redraw()
	await _phys(4)
	for state: String in ["idle", "walk", "attack"]:
		await _foot_state_ab(state, "d02_after_fix_")


func _foot_state_ab(state: String, prefix: String) -> void:
	if state == "walk":
		Input.action_press(&"move_right")
	elif state == "attack":
		_player.request_attack()
	for _i: int in range(4):
		_pin(2455.0)
		await get_tree().physics_frame
	var pair: Array = await _frozen_pair(prefix + state)
	if state == "walk":
		Input.action_release(&"move_right")
	if state == "attack":
		_player.cancel_attack()
	var d: Dictionary = _diff(pair[0], pair[1])
	print("  %s%s visible-pixel diff count=%d bbox x %d..%d y %d..%d" % [
		prefix, state, d["count"], d["min_x"], d["max_x"], d["min_y"], d["max_y"]])


## Right-end check: are the old city columns really hidden by the wall?
func _probe_decor(x: float) -> void:
	print("[B] right-end decor visibility")
	_pin(x)
	await _phys(6)
	get_tree().paused = true
	await get_tree().process_frame
	var hud: L3HUD = _level.get_hud()
	var hud_was: bool = hud.visible
	hud.visible = false
	var with_decor: Image = await _shot("b01_decor_with.png")
	var decos: Array[CanvasItem] = []
	for node_name: String in ["Decorations/ColumnCityLeft", "Decorations/ColumnCityRight"]:
		var node: CanvasItem = _level.get_node_or_null(node_name) as CanvasItem
		if node != null:
			decos.append(node)
			node.visible = false
	await get_tree().process_frame
	var without_decor: Image = await _shot("b02_decor_without.png")
	for node: CanvasItem in decos:
		node.visible = true
	var crop: Image = without_decor.get_region(Rect2i(430, 240, 210, 120))
	crop.resize(210 * 4, 120 * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(DIR + "/b03_right_end_zoom4x.png"))
	print("CAPTURED b03_right_end_zoom4x.png")
	hud.visible = hud_was
	get_tree().paused = false
	await get_tree().process_frame
	var d: Dictionary = _diff(with_decor, without_decor)
	print("  ColumnCityLeft/Right visible-pixel diff count=%d bbox x %d..%d y %d..%d (nodes found: %d)" % [
		d["count"], d["min_x"], d["max_x"], d["min_y"], d["max_y"], decos.size()])


## Completion view: walk past the line with real input, then look at the right
## end of the building at 4x (old decorative instances vs the wall).
func _probe_completion_view() -> void:
	print("[C] completion view / right end")
	_pin(2430.0)
	await _phys(6)
	Input.action_press(&"move_right")
	for _i: int in range(180):
		await get_tree().physics_frame
		if _level.is_completed():
			break
	Input.action_release(&"move_right")
	await _phys(8)
	print("  completed=%s player_x=%.1f" % [_level.is_completed(), _player.global_position.x])
	get_tree().paused = true
	await get_tree().process_frame
	var image: Image = await _shot("c01_completion_city.png")
	var crop: Image = image.get_region(Rect2i(520, 296, 120, 64))
	crop.resize(120 * 5, 64 * 5, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(DIR + "/c02_right_end_zoom5x.png"))
	print("CAPTURED c02_right_end_zoom5x.png")
	get_tree().paused = false
	await get_tree().process_frame
