extends Node

## Headless assertions for the 2026-11-27 "core / badge" correction pass:
##   - free star cores have no +/− node and no 1 px outer ring;
##   - DLC2 / DLC3 delivered cores carry the cyan 澜相 sheet of the moon gate
##     they power, independent of the player's Q;
##   - the L3 floating-platform device shows the new 12-frame core sheets;
##   - the shared completion emblem draws the shipped game icon
##     (`res://assets/icon/icon_32.png`) at 32x32, not a mirror, a guard core,
##     a star core or the retired gate emblem.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/core_badge_20261127/verify_core_badge.tscn --quit-after 600

const BASE_CARRIER: String = "res://scenes/star_core_carrier.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_03: String = "res://scenes/level_03.tscn"
const POSITIVE_SHEET: String = "res://assets/star_core/star_core_positive_12f.png"
const NEGATIVE_SHEET: String = "res://assets/star_core/star_core_negative_12f.png"
const LOCKED_SHEET: String = "res://assets/star_core/star_core_locked_12f.png"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	print("CORE_BADGE_VERIFY checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: " + label + ("" if detail.is_empty() else " [" + detail + "]"))
		return
	_failures.append(label + ("" if detail.is_empty() else " [" + detail + "]"))
	print("FAIL: " + label + ("" if detail.is_empty() else " [" + detail + "]"))


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _run() -> void:
	await _check_base_carrier()
	await _check_delivery(LOOM, "DLC3", "second moon gate")
	await _check_delivery(RIFT, "DLC2", "first moon gate")
	await _check_fixed_device()
	_check_emblem()


func _check_base_carrier() -> void:
	var packed: PackedScene = load(BASE_CARRIER) as PackedScene
	_check(packed != null, "base star-core carrier scene loads")
	if packed == null:
		return
	var carrier: StarCoreCarrier = packed.instantiate() as StarCoreCarrier
	add_child(carrier)
	await _wait_process(2)
	_check(carrier.get_node_or_null("PolarityMark") == null,
		"base carrier has no +/− PolarityMark node")
	_check(carrier.visual.show_state_badge == false,
		"base core visual has no state badge")
	_check(carrier.find_child("PolarityMark", true, false) == null,
		"no PolarityMark exists anywhere under the base carrier")
	carrier.queue_free()
	await _wait_process(2)


func _check_delivery(path: String, tag: String, gate_label: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	_check(packed != null, tag + " scene loads")
	if packed == null:
		return
	var level: Node = packed.instantiate()
	if level.has_method("set"):
		level.set("show_intro_guide", false)
		level.set("show_intro_cinematic", false)
	add_child(level)
	await _wait_process(6)
	await _wait_physics(4)
	var carrier: CoreDeliveryCarrier = level.call("get_core_carrier") as CoreDeliveryCarrier
	var visual: StarCoreVisual = carrier.get_core_visual() if carrier != null else null
	_check(carrier != null, tag + " exposes the shared core carrier")
	if carrier != null and visual != null:
		_check(carrier.is_core_positive() == false,
			tag + " core affinity is fixed to 澜相/青")
		_check(visual.state == StarCoreVisual.CoreState.NEGATIVE,
			tag + " visual uses the NEGATIVE cyan state")
		_check(visual.get_state_sheet_path() == NEGATIVE_SHEET,
			tag + " uses star_core_negative_12f.png",
			visual.get_state_sheet_path())
		_check(visual.show_state_badge == false,
			tag + " world core has no +/− badge")
		_check(carrier.find_child("PolarityMark", true, false) == null,
			tag + " carrier has no PolarityMark node")
		_check(visual.get_animation_frame_count() == 12,
			tag + " keeps the 12-frame sheet",
			str(visual.get_animation_frame_count()))
	var gate: PolarityGate = null
	if level.has_method("get_gate_second"):
		gate = level.call("get_gate_second") as PolarityGate
	elif level.has_method("get_gate_moon"):
		gate = level.call("get_gate_moon") as PolarityGate
	_check(gate != null, tag + " exposes " + gate_label)
	if gate != null:
		_check(gate.get_required_positive() == false,
			tag + " " + gate_label + " is a moon gate")
		_check(gate.get_emblem_kind() == "moon",
			tag + " " + gate_label + " draws the moon emblem")
		_check(visual != null and carrier.get_core_accent() == Color("#5fe1e6"),
			tag + " core accent matches the moon gate")
	level.queue_free()
	await _wait_process(4)


func _check_fixed_device() -> void:
	var packed: PackedScene = load(LEVEL_03) as PackedScene
	_check(packed != null, "level 03 loads for the fixed device")
	if packed == null:
		return
	var level: Node = packed.instantiate()
	if level.has_method("set"):
		level.set("show_intro_guide", false)
		level.set("show_intro_cinematic", false)
	add_child(level)
	await _wait_process(8)
	# The real E route is blocked while the opening film owns the screen; end
	# the film first, then use the mapped interact action (not activate()).
	var cine: Node = level.call("get_cine") as Node
	if cine != null and bool(cine.call("is_active")):
		cine.call("abort")
		await _wait_process(6)
	var device: L3FixedDevice = level.get_node_or_null("FixedDevice") as L3FixedDevice
	_check(device != null, "L3 FixedDevice exists")
	if device != null:
		var core: StarCoreVisual = device.get_core_visual()
		_check(core != null, "fixed device owns a StarCoreVisual")
		_check(device.get_texture_path() == LOCKED_SHEET,
			"fixed device idle path is star_core_locked_12f.png",
			device.get_texture_path())
		_check(core != null and core.get_animation_frame_count() == 12,
			"fixed device idle core keeps 12 frames")
		# Real E route: stand in interaction range and press the mapped action,
		# not a direct activate() call.
		var player: Node2D = level.get_node_or_null("Player") as Node2D
		if player != null:
			player.set_physics_process(false)
			player.global_position = device.global_position + Vector2(0.0, 20.0)
			await _wait_physics(2)
		# This is the exact function the E input calls; the input mapping itself
		# is covered by the prompt-footer suite, so the asset gate exercises the
		# proximity + activation route without faking a direct device state.
		level.call("_try_interact")
		await _wait_physics(2)
		_check(device.is_active(), "E interaction route in range activates the platform device",
			"player=%s device=%s" % [
				str(player.global_position) if player != null else "none",
				str(device.global_position)
			])
		if not device.is_active():
			device.activate()
			await _wait_process(2)
		_check(device.get_texture_path() == POSITIVE_SHEET,
			"fixed device active path is star_core_positive_12f.png",
			device.get_texture_path())
		_check(core != null and core.state == StarCoreVisual.CoreState.POSITIVE,
			"fixed device active core uses POSITIVE")
		_check(core != null and core.get_animation_frame_count() == 12,
			"fixed device active core keeps 12 frames")
		_check(device.find_child("PolarityMark", true, false) == null,
			"fixed device core has no +/− node")
	level.queue_free()
	await _wait_process(4)


func _check_emblem() -> void:
	var script: Script = load("res://scripts/ui/completion_emblem.gd") as Script
	_check(script != null, "completion emblem script loads")
	var emblem: CompletionEmblem = CompletionEmblem.new()
	add_child(emblem)
	await _wait_process(1)
	_check(emblem.get_texture_path() == "res://assets/icon/icon_32.png",
		"completion emblem draws res://assets/icon/icon_32.png",
		emblem.get_texture_path())
	_check(emblem.has_game_icon() and emblem.is_dedicated_emblem(),
		"completion emblem really loads the shipped game icon")
	_check(not emblem.has_mirror_art(),
		"completion emblem is no longer the double-mirror art")
	_check(emblem.size == CompletionEmblem.ICON_SIZE,
		"completion emblem is shown at 32x32",
		str(emblem.size))
	_check(emblem.get_texture() != null
		and emblem.get_texture().get_size() == Vector2(32.0, 32.0),
		"game icon texture is authored 32x32",
		str(emblem.get_texture().get_size()) if emblem.get_texture() != null else "null")
	emblem.queue_free()
	await _wait_process(1)
