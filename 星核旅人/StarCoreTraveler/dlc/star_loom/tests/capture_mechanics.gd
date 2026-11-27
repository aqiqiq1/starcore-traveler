extends Node

## 640x360 evidence for the DLC3 star-core delivery and the early stage-1 wisp.
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/star_loom/tests/capture_mechanics.tscn
##
## Saves to res://screenshots/loom_core_wisp_20261127/:
##  01_core_before_bay.png       gold star core at its start, bay dark, moon
##                               gate still closed
##  02_core_in_transit.png       core between start and the bay, bay still dark
##  03_core_seated_lit.png       core inside the lit bay, moon gate open
##  03b_core_spin_1..3.png       three settled frames of the 12-frame core spin
##  04_core_pulled_door_closed.png  real opposite-phase pull, bay dark, gate
##                               closed again
##  05_wisp_stage1_telegraph.png first boss round is the wisp summon telegraph
##                               (stage 1)
##  06_wisp_stage1_spawned.png   the purple wisp really exists in stage 1
##
## Each full frame also gets a nearest-neighbour 3x detail crop
## (`*_detail_3x.png`) of the core/bay or wisp area, so the 16x16 core can be
## inspected without changing the normal 640x360 game view.  Placement is only
## used to frame the state; every bay/gate state is produced by the real field
## sample, and the first wisp is the chapter's own first natural attack.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://screenshots/loom_core_wisp_20261127"

var _loom: StarLoom
var _player: L3Player
var _carrier: CoreDeliveryCarrier
var _bay: CoreDeliveryBay
var _gate_second: PolarityGate
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	MechanicTips.mark_seen("loom_fire_tip")
	await _run()
	print("LOOM_CORE_WISP_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


func _save(image_name: String, detail_rect: Rect2i = Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(image_name))
	_saved.append(image_name)
	print("SHOT %s size=%dx%d error=%d" % [
		image_name, image.get_width(), image.get_height(), error
	])
	if detail_rect.size.x > 0 and detail_rect.size.y > 0:
		var crop: Image = image.get_region(detail_rect)
		crop.resize(detail_rect.size.x * 3, detail_rect.size.y * 3,
			Image.INTERPOLATE_NEAREST)
		var detail_name: String = image_name.get_basename() + "_detail_3x.png"
		var detail_error: Error = crop.save_png(directory.path_join(detail_name))
		_saved.append(detail_name)
		print("SHOT %s size=%dx%d error=%d" % [
			detail_name, crop.get_width(), crop.get_height(), detail_error
		])


func _place(x: float, positive: bool) -> void:
	_player.global_position = Vector2(x, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.face_direction(1)
	_loom.get_camera().reset_smoothing()
	await _wait_physics(4)
	await _wait_process(8)


func _tap_q() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(3)
	Input.action_release(&"polarity")
	await _wait_physics(5)


func _show_core_frame(zero: int = 0) -> void:
	var visual: StarCoreVisual = _carrier.get_core_visual()
	if visual != null:
		visual.set_animation_frame(zero)


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		print("LOOM_CORE_WISP_CAPTURE missing scene")
		return
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	_loom.show_intro_cinematic = false
	add_child(_loom)
	await _wait_process(6)
	await _wait_physics(10)
	_player = _loom.get_player()
	_carrier = _loom.get_core_carrier()
	_bay = _loom.get_core_bay()
	_gate_second = _loom.get_gate_second()
	if _player == null or _carrier == null or _bay == null or _gate_second == null:
		print("LOOM_CORE_WISP_CAPTURE missing nodes")
		return

	# Frame the delivery corridor from the left of the core.  The camera limit
	# clamps the view to world x 0..640, so both the core (x~270) and the bay
	# (x=330) are in the same normal 640x360 frame.
	var bay_detail: Rect2i = Rect2i(250, 246, 130, 86)

	# 1. Core at its start; bay dark; moon gate closed.  Wait out the shared
	# objective/event 0.15 s cross-fade first, so the header is a stable
	# one-line read rather than two lines overprinted.
	await _place(204.0, false)
	await _wait_seconds(0.20)
	await _wait_physics(2)
	_show_core_frame(0)
	await _save("01_core_before_bay.png", bay_detail)
	_check_state("01_core_before_bay",
		not _bay.is_lit() and not _gate_second.is_open()
		and not _carrier.is_on_socket(),
		"core=%.1f bay=%s gate=%s" % [
			_carrier.global_position.x, str(_bay.is_lit()), str(_gate_second.is_open())
		])

	# 2. Core between start and bay, while the same-phase field pushes it.
	var in_transit: bool = await _wait_until(
		func() -> bool:
			return (
				_carrier.global_position.x >= 306.0
				and _carrier.global_position.x <= 320.0
			),
		240
	)
	_show_core_frame(0)
	await _save("02_core_in_transit.png", bay_detail)
	_check_state("02_core_in_transit", in_transit and not _bay.is_lit(),
		"core=%.1f" % _carrier.global_position.x)

	# 3. Seated: the bay's pedestal/dome light, the gold seams and conduit are
	# on, and the moon gate is open.  The 0.18 s wait also lets the shared
	# objective/event header finish its 0.15 s cross-fade, so the evidence frame
	# is clean rather than double-drawn.
	var seated: bool = await _wait_until(
		func() -> bool: return _carrier.is_on_socket(), 420
	)
	await _wait_until(
		func() -> bool: return _carrier.global_position.x >= 329.5, 120
	)
	await _wait_seconds(0.22)
	_show_core_frame(0)
	await _save("03_core_seated_lit.png", bay_detail)
	_check_state("03_core_seated_lit", seated and _bay.is_lit()
		and _gate_second.is_open(),
		"core=%.1f bay=%s gate=%s" % [
			_carrier.global_position.x, str(_bay.is_lit()), str(_gate_second.is_open())
		])

	# 3b. Three settled frames 0.24 s apart (12 fps sheet) prove the core really
	# spins inside the bay; the detail crop keeps the 16x16 core readable.
	await _save("03b_core_spin_1.png", bay_detail)
	await _wait_seconds(0.24)
	await _save("03b_core_spin_2.png", bay_detail)
	await _wait_seconds(0.24)
	await _save("03b_core_spin_3.png", bay_detail)

	# 4. Real opposite-phase pull: the bay goes dark and the moon gate closes.
	await _tap_q()
	var pulled: bool = await _wait_until(
		func() -> bool: return not _carrier.is_on_socket(), 240
	)
	await _wait_until(
		func() -> bool:
			return (
				_carrier.global_position.x <= _bay.global_position.x - 66.0
			),
		180
	)
	_show_core_frame(0)
	await _save("04_core_pulled_door_closed.png", bay_detail)
	_check_state("04_core_pulled_door_closed",
		pulled and not _bay.is_lit() and not _gate_second.is_open(),
		"core=%.1f bay=%s gate=%s" % [
			_carrier.global_position.x, str(_bay.is_lit()), str(_gate_second.is_open())
		])

	# Push it back in so the route can continue; the checkpoint/gate state is
	# not bypassed.
	await _tap_q()
	var reseated: bool = await _wait_until(
		func() -> bool: return _carrier.is_on_socket(), 420
	)
	_check_state("05_reseated_for_route", reseated and _bay.is_lit()
		and _gate_second.is_open(),
		"core=%.1f" % _carrier.global_position.x)

	# Walk into the arena: cross the checkpoint and the arena line with real
	# movement, then frame the first boss round.
	await _place(420.0, false)
	Input.action_press(&"move_right")
	var entered: bool = await _wait_until(
		func() -> bool: return _loom.is_boss_active(), 180
	)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check_state("06_boss_started", entered,
		"x=%.1f stage=%d" % [_player.global_position.x, _loom.get_stage()])
	if not entered:
		_loom.queue_free()
		await _wait_process(20)
		return
	# Keep the wisp's spawn point (548,262) and the lit bay both in frame.
	await _place(460.0, false)
	var wisp_detail: Rect2i = Rect2i(352, 214, 176, 118)

	# 5. The first boss request is the wisp summon telegraph, in stage 1.
	var telegraphed: bool = await _wait_until(
		func() -> bool: return _loom.get_attack_state_name() == "telegraph", 420
	)
	# The shared header cross-fades the objective out over 0.15 s; wait for the
	# event line to settle so the evidence frame is readable, not double-drawn.
	await _wait_seconds(0.20)
	_show_core_frame(0)
	await _save("05_wisp_stage1_telegraph.png", wisp_detail)
	_check_state("05_wisp_stage1_telegraph",
		telegraphed and _loom.get_stage() == 1
		and _loom.get_attack_kind() == "summon",
		"stage=%d kind=%s" % [_loom.get_stage(), _loom.get_attack_kind()])

	# 6. The wisp itself is present in stage 1.
	var spawned: bool = await _wait_until(
		func() -> bool: return _loom.get_active_wisps() >= 1, 120
	)
	await _wait_seconds(0.16)
	_show_core_frame(0)
	await _save("06_wisp_stage1_spawned.png", wisp_detail)
	_check_state("06_wisp_stage1_spawned",
		spawned and _loom.get_stage() == 1 and _loom.get_active_wisps() >= 1,
		"stage=%d wisps=%d" % [_loom.get_stage(), _loom.get_active_wisps()])

	_loom.queue_free()
	await _wait_process(20)


func _check_state(frame_name: String, condition: bool, detail: String) -> void:
	print("FRAME %s state=%s detail=%s" % [
		frame_name, "ok" if condition else "WRONG", detail
	])
