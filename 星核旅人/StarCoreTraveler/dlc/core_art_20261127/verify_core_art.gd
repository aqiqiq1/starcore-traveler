extends Node

## Headless assertions for the 2026-11-27 star-core / bay art pass.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/core_art_20261127/verify_core_art.tscn
##
## Checks only presentation contracts; no gameplay values are touched.

const CORE_SHEETS: Array[String] = [
	"res://assets/star_core/star_core_positive_12f.png",
	"res://assets/star_core/star_core_negative_12f.png",
	"res://assets/star_core/star_core_locked_12f.png",
]
const CORE_STILLS: Array[String] = [
	"res://assets/star_core/star_core_positive.png",
	"res://assets/star_core/star_core_negative.png",
	"res://assets/star_core/star_core_locked.png",
]
const BAY_BASE: String = "res://assets/star_core_bay/star_core_bay_base.png"
const BAY_GLASS: String = "res://assets/star_core_bay/star_core_bay_glass.png"
const BAY_VISUAL: String = "res://scenes/star_core_bay_visual.tscn"
const LOOM_BAY: String = "res://dlc/shared/core_delivery/core_bay.tscn"
## The 2026-11-27 sheet had a fixed 1 px gold ring at radius ~6.9.  That band
## held ~580 opaque pixels across the 12 frames; after the removal only a few
## gem-edge/debris pixels may touch it.  < 60 proves the ring layer is gone.
const RING_BAND_BEFORE: int = 580
const RING_BAND_LIMIT: int = 60

var _failures: int = 0


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		print("PASS %s %s" % [label, detail])
	else:
		_failures += 1
		print("FAIL %s %s" % [label, detail])


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("CORE_ART_VERIFY failures=%d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _run() -> void:
	for path: String in CORE_SHEETS:
		var texture: Texture2D = load(path) as Texture2D
		_check(texture != null, "sheet loads", path)
		if texture != null:
			_check(texture.get_size() == Vector2(192, 16), "sheet is 192x16", path)
			var band: int = _count_ring_band(texture.get_image())
			_check(band < RING_BAND_LIMIT, "free core has no outer ring band",
				"%d px (was %d) %s" % [band, RING_BAND_BEFORE, path])
	for path: String in CORE_STILLS:
		var texture: Texture2D = load(path) as Texture2D
		_check(texture != null, "still loads", path)
		if texture != null:
			_check(texture.get_size() == Vector2(16, 16), "still is 16x16", path)

	# Animated 12-frame contract, real playback, not just file size.
	var core_scene: PackedScene = load("res://scenes/star_core_visual.tscn") as PackedScene
	_check(core_scene != null, "StarCoreVisual scene loads")
	if core_scene == null:
		return
	var core: StarCoreVisual = core_scene.instantiate() as StarCoreVisual
	add_child(core)
	await get_tree().process_frame
	core.state = StarCoreVisual.CoreState.POSITIVE
	await get_tree().process_frame
	_check(core.is_using_animated_sheet(), "positive uses animated sheet")
	_check(core.get_animation_frame_count() == 12, "frame count stays 12",
		str(core.get_animation_frame_count()))
	_check(core.get_source_size() == Vector2i(16, 16), "source size stays 16x16")
	_check(core.get_source_sheet_size() == Vector2i(192, 16), "sheet size stays 192x16")
	var frame_zero: Texture2D = core.get_art_texture()
	core.set_animation_frame(0)
	await get_tree().process_frame
	var frame_a: Image = core.get_art_texture().get_image()
	core.advance_animation(0.09)
	var frame_b: Texture2D = core.get_art_texture()
	_check(frame_b != frame_zero, "advance_animation changes frame")
	_check(core.get_animation_frame() != 0, "frame index advances")
	core.set_animation_frame(6)
	await get_tree().process_frame
	var frame_six: Image = core.get_art_texture().get_image()
	_check(frame_a.get_size() == Vector2i(16, 16) and frame_six.get_size() == Vector2i(16, 16),
		"played frames are 16x16")
	_check(frame_a.get_data() != frame_six.get_data(), "12-frame sheet has distinct poses")
	core.set_animation_frame(11)
	core.advance_animation(0.09)
	_check(core.get_animation_frame() == 0, "12-frame loop wraps 11 -> 0",
		str(core.get_animation_frame()))
	core.queue_free()
	await get_tree().process_frame

	# Shared bay: empty dims the stone, occupied brightens it and shows the
	# core; the glass is the closing lid layer in front.
	var bay_scene: PackedScene = load(BAY_VISUAL) as PackedScene
	_check(bay_scene != null, "shared bay scene loads")
	if bay_scene == null:
		return
	var bay: StarCoreBayVisual = bay_scene.instantiate() as StarCoreBayVisual
	add_child(bay)
	await get_tree().process_frame
	bay.occupied = true
	bay.set_lid_open_immediately(false)
	await get_tree().process_frame
	var lit_modulate: Color = bay.get_base_sprite().modulate
	var lit_core_visible: bool = bay.get_core_visual().visible
	var lit_glass_visible: bool = bay.get_glass_sprite().visible
	_check(bay.has_art(), "shared bay has base + glass art")
	_check(lit_core_visible, "occupied shows the core")
	_check(lit_glass_visible, "occupied closes/shows the glass")
	bay.occupied = false
	bay.set_lid_open_immediately(true)
	await get_tree().process_frame
	var empty_modulate: Color = bay.get_base_sprite().modulate
	_check(not bay.get_core_visual().visible, "empty hides the core")
	_check(not bay.get_glass_sprite().visible, "empty opens/hides the glass")
	_check(empty_modulate.r < lit_modulate.r and empty_modulate.g < lit_modulate.g,
		"empty pedestal is darker", "%s -> %s" % [str(lit_modulate), str(empty_modulate)])

	# DLC3 bay: its own empty/lit contract still toggles the base and glass.
	var loom_scene: PackedScene = load(LOOM_BAY) as PackedScene
	_check(loom_scene != null, "CoreDeliveryBay scene loads")
	if loom_scene == null:
		return
	var loom: CoreDeliveryBay = loom_scene.instantiate() as CoreDeliveryBay
	add_child(loom)
	await get_tree().process_frame
	loom.set_occupied(false)
	await _wait_process(2)
	_check(not loom.is_lit(), "DLC3 bay starts empty/dark")
	_check(not loom.get_glass_sprite().visible, "DLC3 empty bay hides glass")
	var dark_base: Color = loom.get_base_sprite().modulate
	loom.set_occupied(true)
	await _wait_process(20)
	_check(loom.is_lit(), "DLC3 bay lights when occupied")
	_check(loom.get_glass_sprite().visible, "DLC3 occupied bay shows glass")
	_check(loom.get_base_sprite().modulate.r > dark_base.r, "DLC3 occupied base is brighter",
		"%s -> %s" % [str(dark_base), str(loom.get_base_sprite().modulate)])
	_check(loom.get_glass_sprite().z_index > 0, "glass is a front layer")
	loom.queue_free()
	await get_tree().process_frame


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


## Opaque pixels whose centre distance from the 16x16 gem centre falls in the
## old outer-ring band (6.3..7.3 px).  The sheet is 192x16, 12 frames across.
func _count_ring_band(image: Image) -> int:
	if image == null or image.is_empty():
		return -1
	var count: int = 0
	for frame: int in range(12):
		for y: int in range(16):
			for x: int in range(16):
				if image.get_pixel(frame * 16 + x, y).a <= 0.0:
					continue
				var dx: float = (float(x) + 0.5) - 7.5
				var dy: float = (float(y) + 0.5) - 7.5
				var distance: float = sqrt(dx * dx + dy * dy)
				if distance >= 6.3 and distance <= 7.3:
					count += 1
	return count
