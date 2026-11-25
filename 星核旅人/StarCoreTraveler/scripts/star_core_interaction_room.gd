class_name StarCoreInteractionRoom
extends Node2D

## Safe single-screen star-core interaction prototype.
##
## One moving core, one start bay (locked) and one empty target bay. The player
## can walk the continuous floor, press E near a loaded bay to open its lid,
## use Q to switch only their own polarity, and pull/push the core toward an
## empty bay. Storage is explicit: while the player, the moving core and an
## empty bay are all close together, HUD shows E: STORE; only that E brakes and
## locks the core and closes the lid. There is no automatic capture, no speed
## gate and no slow-zone drag.
##
## This is an interaction sandbox, not a formal puzzle: no doors, no anchors,
## no throw/pickup, no polarity converter, and success is only a HUD hint. The
## room never disables bay interaction after the target is reached.

signal target_stored
signal core_released
## Re-emitted for the room owner when a valid manual E store has captured the
## moving core's own polarity into a specific bay. This is data only; the bay
## owns the record and the link/visual subscribers react to it.
signal core_polarity_recorded(bay: StarCoreBayInteractable, positive: bool)

const BODY_CENTER_OFFSET: Vector2 = Vector2(0.0, -15.0)
const BODY_RECT: Rect2 = Rect2(0.0, 320.0, 640.0, 40.0)

const STATUS_LOCKED: String = "LOCKED"
const STATUS_EMPTY: String = "EMPTY"
const STATUS_ATTRACT: String = "ATTRACT"
const STATUS_REPEL: String = "REPEL"
const STATUS_OUT_OF_RANGE: String = "OUT OF RANGE"
const STATUS_BLOCKED: String = "BLOCKED"
const STATUS_NEAR: String = "NEAR / STABLE"
const STATUS_RELEASED: String = "RELEASED"
const STATUS_STORED: String = "STORED"

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const PURPLE: Color = Color("#c8a7f2")
const RED: Color = Color("#ff7f72")
const MUTED: Color = Color("#a8bbb7")

## Trial near-follow field: 100 px. Normal walk settles in a roughly 30..60 px
## trail; the inner 40 px is a stable no-force zone, full strength begins at
## 64 px, and the last 18 px fade to zero at 100 px. This is still a real
## two-way attraction/repulsion, not a position target.
@export var field_range: float = 100.0
@export var inner_radius: float = 40.0
@export var full_radius: float = 64.0
@export var outer_fade: float = 18.0
@export var core_acceleration: float = 620.0
@export var player_acceleration: float = 300.0
## The moving core must also be near the player before E can store it.
@export var store_player_core_range: float = 80.0
@export var core_kill_y: float = 380.0
@export var core_min_x: float = 4.0
@export var core_max_x: float = 636.0

@onready var _start_bay: StarCoreBayInteractable = $Bays/StartBay
@onready var _target_bay: StarCoreBayInteractable = $Bays/TargetBay
@onready var _core: StarCoreCarrier = $Core
@onready var _spawn_marker: Marker2D = $PlayerSpawn
@onready var _terrain_body: StaticBody2D = $TerrainBody
@onready var _terrain_top: TerrainStrip = $TerrainTop
@onready var _terrain_fill: TerrainStrip = $TerrainFill

var _player: PrototypePlayer
var _hud: PrototypeHUD
var _active: bool = false
var _pending_release: bool = false
var _pending_positive: bool = true
var _release_bay: StarCoreBayInteractable
var _store_bay: StarCoreBayInteractable
var _success: bool = false
var _last_status: String = STATUS_LOCKED
var _last_distance: float = 0.0
var _last_force: Vector2 = Vector2.ZERO
var _last_core_player_force: Vector2 = Vector2.ZERO
var _last_extra_player_force: Vector2 = Vector2.ZERO
## Sum of the core pair's player force and every registered provider's force.
## It is applied through one player.apply_external_force() call per tick.
var _last_player_force: Vector2 = Vector2.ZERO
var _last_extra_status: String = ""
var _last_extra_distance: float = 0.0
var _last_blocked: bool = false
var _player_force_providers: Array[Node] = []
var _last_e_preview: String = ""
var _last_store_hint: String = ""
var _last_release_position: Vector2 = Vector2.ZERO
var _last_release_initial_speed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = -10
	visible = false
	_set_collisions_active(false)
	_core.deactivate()
	_start_bay.reset_locked()
	_target_bay.reset_empty()


func activate(player: PrototypePlayer, hud: PrototypeHUD) -> void:
	_player = player
	_hud = hud
	_active = true
	visible = true
	_set_collisions_active(true)
	if _player != null:
		_player.clear_external_force()
		_player.set_anchor_room_bounds(false)
	_core.ignore_body(_player)
	_reset_room_state()
	_update_hud()
	queue_redraw()


func deactivate() -> void:
	_active = false
	visible = false
	_pending_release = false
	_release_bay = null
	_store_bay = null
	_player_force_providers.clear()
	_core.deactivate()
	_start_bay.stop_animation()
	_target_bay.stop_animation()
	if _player != null:
		_player.clear_external_force()
	_player = null
	_hud = null
	_set_collisions_active(false)
	queue_redraw()


func _set_collisions_active(active: bool) -> void:
	if _terrain_body == null:
		return
	_terrain_body.collision_layer = 1 if active else 0
	_terrain_body.collision_mask = 1 if active else 0


func _physics_process(_delta: float) -> void:
	if not _active or _player == null:
		return

	if _pending_release and _release_bay != null and _release_bay.is_release_ready():
		_perform_release()

	if _store_bay != null and _store_bay.is_store_ready():
		_complete_store()

	if _core.is_active() and _is_core_out_of_bounds():
		_handle_core_out_of_bounds()
		return

	if Input.is_action_just_pressed(&"interact"):
		_try_interact()

	if _core.is_active():
		_update_live_field()
	else:
		_last_status = _inactive_core_status()
		_last_distance = 0.0
		_last_force = Vector2.ZERO
		_last_core_player_force = Vector2.ZERO
		_last_extra_player_force = Vector2.ZERO
		_last_extra_status = ""
		_last_extra_distance = 0.0
		_last_player_force = Vector2.ZERO
		_last_blocked = false
		_last_store_hint = ""
		if _player != null:
			# Fixed-field providers (for example a linked rune stone) still act
			# on the player while the core is locked. The core receives nothing.
			var player_center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
			_last_extra_player_force = _sample_extra_player_force(player_center)
			_last_player_force = _last_extra_player_force
			if _last_player_force.is_zero_approx():
				_player.clear_external_force()
			else:
				_player.apply_external_force(_last_player_force)
		_core.clear_external_force()

	_update_hud()
	if _player != null and _player.is_debug_enabled():
		queue_redraw()


func _try_interact() -> void:
	if _pending_release or _store_bay != null:
		return
	if _core.is_active():
		var store_info: Dictionary = _find_store_bay()
		if bool(store_info.get("ok", false)):
			_begin_store(store_info["bay"] as StarCoreBayInteractable)
		else:
			_show_store_unavailable(store_info)
		return
	var bay: StarCoreBayInteractable = _nearest_loaded_bay()
	if bay == null:
		var empty_bay: StarCoreBayInteractable = _nearest_empty_bay()
		if empty_bay != null and _hud != null:
			_hud.show_toast("E IGNORED - NO CORE TO STORE (%s)" % empty_bay.bay_name)
		return
	if not bay.start_release():
		return
	_pending_positive = not _player.is_positive()
	_pending_release = true
	_release_bay = bay
	_last_e_preview = "E: OPENING..."
	if _hud != null:
		_hud.show_toast(
			"RELEASE SNAPSHOT: %s" % ("GOLD +" if _pending_positive else "CYAN -")
		)
	_update_hud()


func _perform_release() -> void:
	if _release_bay == null:
		return
	var bay: StarCoreBayInteractable = _release_bay
	var release_position: Vector2 = bay.get_release_point(_player.global_position.x)
	_last_release_position = release_position
	_core.activate_at(release_position, _pending_positive)
	_last_release_initial_speed = _core.velocity.length()
	_core.ignore_body(_player)
	bay.finish_release()
	_release_bay = null
	_pending_release = false
	_last_status = STATUS_RELEASED
	if _hud != null:
		_hud.show_toast(
			"RELEASED: %s" % ("GOLD +" if _pending_positive else "CYAN -")
		)
	core_released.emit()
	_update_hud()


func _update_live_field() -> void:
	if _player == null or not _core.is_active():
		return
	var player_center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
	var core_center: Vector2 = _core.global_position
	var field: Dictionary = compute_field(
		player_center,
		core_center,
		_player.is_positive(),
		_core.is_positive()
	)
	_last_status = String(field["status"])
	_last_distance = float(field["distance"])
	_last_blocked = bool(field["blocked"])
	_last_force = field["core_acceleration"]
	_last_core_player_force = field["player_acceleration"]
	_last_extra_player_force = _sample_extra_player_force(player_center)
	_last_player_force = _last_core_player_force + _last_extra_player_force

	# Ground transport uses the horizontal projection of the core pair's
	# centre-line force. This keeps a player standing above the core from
	# launching it upward. Provider forces (fixed rune stones) are added after
	# this projection and keep their own vertical component, like the anchor
	# trial; the core still receives only the player-core pair force.
	if _core.is_on_floor():
		_last_force.y = 0.0
		_last_core_player_force.y = 0.0
		_last_player_force = _last_core_player_force + _last_extra_player_force

	# Exactly one application per body. A provider must never overwrite the
	# pair force after this point.
	if _last_force.is_zero_approx():
		_core.clear_external_force()
	else:
		_core.apply_external_force(_last_force)
	if _last_player_force.is_zero_approx():
		_player.clear_external_force()
	else:
		_player.apply_external_force(_last_player_force)


## Registers a fixed-field source that contributes to the player force only.
## The provider contract is duck-typed and deliberately small:
##   sample_player_force(player_center: Vector2, player_positive: bool,
##                       excluded_rid: RID) -> Dictionary
## with at least {"acceleration": Vector2}. Extra keys status, distance and
## blocked are preserved for display. Providers never receive the core and
## never apply forces themselves.
func add_player_force_provider(provider: Node) -> void:
	if provider == null or _player_force_providers.has(provider):
		return
	_player_force_providers.append(provider)


func remove_player_force_provider(provider: Node) -> void:
	_player_force_providers.erase(provider)


func clear_player_force_providers() -> void:
	_player_force_providers.clear()


func _sample_extra_player_force(player_center: Vector2) -> Vector2:
	var total: Vector2 = Vector2.ZERO
	_last_extra_status = ""
	_last_extra_distance = 0.0
	if _player == null:
		return total
	var index: int = _player_force_providers.size() - 1
	while index >= 0:
		var provider: Node = _player_force_providers[index]
		if not is_instance_valid(provider):
			_player_force_providers.remove_at(index)
			index -= 1
			continue
		if provider.has_method("sample_player_force"):
			var sample: Dictionary = provider.sample_player_force(
				player_center,
				_player.is_positive(),
				_player.get_rid()
			)
			var acceleration: Vector2 = sample.get("acceleration", Vector2.ZERO)
			total += acceleration
			var status: String = String(sample.get("status", ""))
			if not status.is_empty():
				_last_extra_status = status
			_last_extra_distance = float(sample.get("distance", 0.0))
		index -= 1
	return total


## Finds the nearest empty bay that currently offers a valid manual E store.
## A valid store requires: player in bay interaction range, moving core near the
## player, and core centre inside the bay's small seat zone. No speed gate.
func _find_store_bay() -> Dictionary:
	var candidate: StarCoreBayInteractable = null
	var candidate_distance: float = 1e20
	var best: StarCoreBayInteractable = null
	var best_distance: float = 1e20
	var best_reason: String = "NO EMPTY BAY NEAR"
	if _player == null:
		return {"ok": false, "bay": null, "reason": "NO PLAYER"}
	var player_near_core: bool = (
		_core.is_active()
		and _player.global_position.distance_to(_core.global_position)
		<= store_player_core_range
	)
	for bay: StarCoreBayInteractable in [_start_bay, _target_bay]:
		if not bay.is_player_in_range(_player.global_position):
			continue
		if not bay.is_open_empty():
			continue
		var distance: float = absf(bay.global_position.x - _player.global_position.x)
		if candidate == null or distance < candidate_distance:
			candidate = bay
			candidate_distance = distance
		var reason: String = ""
		if not _core.is_active():
			reason = "NO ACTIVE CORE"
		elif not player_near_core:
			reason = "CORE TOO FAR FROM PLAYER"
		elif not bay.is_core_in_store_zone(_core.global_position):
			reason = "CORE NOT IN BAY SEAT"
		if reason.is_empty():
			if best == null or distance < best_distance:
				best = bay
				best_distance = distance
		elif candidate == bay:
			best_reason = reason
	if best != null:
		return {"ok": true, "bay": best, "reason": "READY"}
	return {
		"ok": false,
		"bay": candidate,
		"reason": best_reason if candidate != null else "NO EMPTY BAY NEAR",
	}


func _show_store_unavailable(info: Dictionary) -> void:
	var bay: StarCoreBayInteractable = info.get("bay", null) as StarCoreBayInteractable
	if _hud == null:
		return
	if bay != null:
		_hud.show_toast(
			"E IGNORED - %s (%s)" % [String(info.get("reason", "")), bay.bay_name]
		)
	else:
		_hud.show_toast("E IGNORED - LEAD THE CORE TO AN EMPTY BAY")


func _begin_store(bay: StarCoreBayInteractable) -> void:
	# Snapshot before the lid moves and before any later Q input. This is the
	# moving core's own value, not the player's polarity and not the purple
	# LOCKED display. start_store() records and emits synchronously on accept.
	var core_positive: bool = _core.is_positive()
	if not bay.start_store_core(core_positive):
		return
	core_polarity_recorded.emit(bay, core_positive)
	_store_bay = bay
	# Small local alignment only: the carrier was already inside the bay's seat
	# zone, so this snap is at most the seat diagonal (~30 px), not a remote pull.
	_core.global_position = bay.get_store_center()
	_core.deactivate()
	_last_force = Vector2.ZERO
	_last_core_player_force = Vector2.ZERO
	_last_extra_player_force = Vector2.ZERO
	_last_extra_status = ""
	_last_extra_distance = 0.0
	_last_player_force = Vector2.ZERO
	_last_distance = 0.0
	_last_blocked = false
	if _player != null:
		_player.clear_external_force()
	_pending_release = false
	_release_bay = null
	_last_status = STATUS_STORED
	_last_store_hint = ""
	if _hud != null:
		_hud.show_toast("CORE STORED - LID CLOSING")
	_on_core_stored_in_bay(bay, core_positive)
	_update_hud()


## Overridable outcome hook for a test/sandbox that repurposes the target bay.
## The base interaction room keeps its original success behavior.
func _on_core_stored_in_bay(bay: StarCoreBayInteractable, _core_positive: bool) -> void:
	if bay == _target_bay:
		_success = true
		if _hud != null:
			_hud.set_interaction_success(true)
		target_stored.emit()


func _complete_store() -> void:
	if _store_bay == null:
		return
	_store_bay.finish_store()
	_store_bay = null
	_last_status = STATUS_LOCKED
	if _hud != null:
		_hud.show_toast("CORE LOCKED - E: RELEASE")
	_update_hud()


func _handle_core_out_of_bounds() -> void:
	if _hud != null:
		_hud.show_toast("CORE OUT - ROOM RESET")
	_reset_room_state()
	if _player != null:
		_player.reset_to_spawn("core_out", false)


func _is_core_out_of_bounds() -> bool:
	if not _core.is_active():
		return false
	var position: Vector2 = _core.global_position
	return (
		position.x < core_min_x
		or position.x > core_max_x
		or position.y > core_kill_y
	)


func _reset_room_state() -> void:
	_start_bay.reset_locked()
	_target_bay.reset_empty()
	_core.deactivate()
	_pending_release = false
	_pending_positive = true
	_release_bay = null
	_store_bay = null
	_success = false
	_last_status = STATUS_LOCKED
	_last_distance = 0.0
	_last_force = Vector2.ZERO
	_last_core_player_force = Vector2.ZERO
	_last_extra_player_force = Vector2.ZERO
	_last_extra_status = ""
	_last_extra_distance = 0.0
	_last_player_force = Vector2.ZERO
	_last_blocked = false
	_last_e_preview = ""
	_last_store_hint = ""
	_last_release_position = Vector2.ZERO
	_last_release_initial_speed = 0.0
	if _player != null:
		_player.clear_external_force()
	if _hud != null:
		_hud.set_interaction_success(false)
	queue_redraw()


func on_player_reset(_reason: String) -> void:
	_reset_room_state()
	_update_hud()


func on_focus_lost() -> void:
	if _player != null:
		_player.clear_input_buffers()


func _inactive_core_status() -> String:
	if _start_bay != null and _start_bay.has_core():
		return STATUS_LOCKED
	if _target_bay != null and _target_bay.has_core():
		return STATUS_LOCKED
	return STATUS_EMPTY


func _nearest_loaded_bay() -> StarCoreBayInteractable:
	if _player == null:
		return null
	var best: StarCoreBayInteractable = null
	var best_distance: float = 1e20
	for bay: StarCoreBayInteractable in [_start_bay, _target_bay]:
		if not bay.is_player_in_range(_player.global_position) or not bay.is_locked():
			continue
		var distance: float = absf(bay.global_position.x - _player.global_position.x)
		if distance < best_distance:
			best = bay
			best_distance = distance
	return best


func _nearest_empty_bay() -> StarCoreBayInteractable:
	if _player == null:
		return null
	var best: StarCoreBayInteractable = null
	var best_distance: float = 1e20
	for bay: StarCoreBayInteractable in [_start_bay, _target_bay]:
		if not bay.is_player_in_range(_player.global_position) or not bay.is_open_empty():
			continue
		var distance: float = absf(bay.global_position.x - _player.global_position.x)
		if distance < best_distance:
			best = bay
			best_distance = distance
	return best


func _update_hud() -> void:
	if _hud == null or _player == null:
		return
	var core_state: int = -1
	if _core.is_active():
		core_state = 1 if _core.is_positive() else 0
	else:
		if _start_bay.is_locked() or _target_bay.is_locked():
			core_state = -1
	var bay_text: String = "%s / %s" % [
		_start_bay.get_state_label(), _target_bay.get_state_label()
	]
	var e_text: String = ""
	var hint: String = ""
	if _pending_release:
		e_text = "E: OPENING..."
		hint = "SNAPSHOT LOCKED - Q ONLY CHANGES PLAYER"
	elif _store_bay != null:
		e_text = "E: STORING..."
		hint = "LID CLOSING..."
	elif _core.is_active():
		var store_info: Dictionary = _find_store_bay()
		var store_target: StarCoreBayInteractable = (
			store_info.get("bay", null) as StarCoreBayInteractable
		)
		if bool(store_info.get("ok", false)) and store_target != null:
			e_text = store_target.get_e_store_preview(true)
			hint = "PRESS E TO STORE - NO POLARITY MATCH"
		elif store_target != null:
			e_text = "E: STORE UNAVAILABLE (%s) - %s" % [
				store_target.bay_name, String(store_info.get("reason", ""))
			]
			match String(store_info.get("reason", "")):
				"CORE NOT IN BAY SEAT":
					hint = "MOVE CORE INTO THE BAY SEAT"
				"CORE TOO FAR FROM PLAYER":
					hint = "BRING CORE CLOSER TO YOU"
				_:
					hint = "STORE UNAVAILABLE"
		else:
			e_text = "E: CORE IS FREE - BRING TO AN EMPTY BAY"
			hint = "LEAD CORE TO AN EMPTY BAY"
	else:
		var loaded: StarCoreBayInteractable = _nearest_loaded_bay()
		if loaded != null:
			e_text = loaded.get_e_release_preview(
				_player.is_positive(),
				loaded.is_player_in_range(_player.global_position)
			)
			hint = "PRESS E TO RELEASE - OPPOSITE SNAPSHOT"
		else:
			var empty: StarCoreBayInteractable = _nearest_empty_bay()
			if empty != null:
				e_text = "E: NO CORE TO STORE (%s)" % empty.bay_name
				hint = "NO ACTIVE CORE - E UNAVAILABLE"
			else:
				e_text = "E: --"
				hint = "Q: SWITCH PLAYER POLARITY"
	_last_e_preview = e_text
	_last_store_hint = hint
	_hud.set_interaction_state(
		_player.is_positive(),
		core_state,
		_last_status,
		_last_distance,
		_last_force,
		bay_text,
		e_text,
		hint
	)
	_hud.set_interaction_success(_success)


func compute_field(
	player_center: Vector2,
	core_center: Vector2,
	player_positive: bool,
	core_positive: bool
) -> Dictionary:
	var to_core: Vector2 = core_center - player_center
	var distance: float = to_core.length()
	var result: Dictionary = {
		"status": STATUS_OUT_OF_RANGE,
		"distance": distance,
		"strength": 0.0,
		"player_acceleration": Vector2.ZERO,
		"core_acceleration": Vector2.ZERO,
		"in_range": false,
		"blocked": false,
	}
	if distance >= field_range:
		return result
	result["in_range"] = true
	if _is_line_blocked(player_center, core_center):
		result["status"] = STATUS_BLOCKED
		result["blocked"] = true
		return result
	if distance <= 0.5:
		result["status"] = STATUS_NEAR
		return result
	if distance <= inner_radius:
		result["status"] = STATUS_NEAR
		return result
	var strength: float = _strength_for(distance)
	if strength <= 0.001:
		result["status"] = STATUS_NEAR
		return result
	var direction: Vector2 = to_core / distance
	var same_sign: bool = player_positive == core_positive
	var core_direction: Vector2 = direction if same_sign else -direction
	var player_direction: Vector2 = -core_direction
	result["status"] = STATUS_REPEL if same_sign else STATUS_ATTRACT
	result["strength"] = strength
	result["core_acceleration"] = core_direction * core_acceleration * strength
	result["player_acceleration"] = player_direction * player_acceleration * strength
	return result


func _strength_for(distance: float) -> float:
	if distance >= field_range or distance <= inner_radius:
		return 0.0
	var near_factor: float = smoothstep(inner_radius, full_radius, distance)
	var outer_factor: float = 1.0 - smoothstep(field_range - outer_fade, field_range, distance)
	return near_factor * outer_factor


func _is_line_blocked(player_center: Vector2, core_center: Vector2) -> bool:
	if _player == null:
		return false
	var space: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	if space == null:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		player_center, core_center, 1
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclude: Array[RID] = [_player.get_rid()]
	if _core != null:
		exclude.append(_core.get_rid())
	query.exclude = exclude
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()


func _draw() -> void:
	if not _active or _player == null or not _player.is_debug_enabled():
		return
	var player_center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
	var field_color: Color = MUTED
	if _last_status == STATUS_ATTRACT:
		field_color = CYAN
	elif _last_status == STATUS_REPEL:
		field_color = GOLD
	elif _last_status == STATUS_BLOCKED:
		field_color = RED
	draw_arc(player_center, field_range, 0.0, TAU, 96, Color(field_color, 0.42), 1.0)
	for bay: StarCoreBayInteractable in [_start_bay, _target_bay]:
		var center: Vector2 = bay.get_store_center()
		var half: Vector2 = bay.get_store_half_extents()
		draw_rect(
			Rect2(center - half, half * 2.0),
			Color(CYAN if bay.is_open_empty() else PURPLE, 0.55),
			false,
			1.0
		)
	if not _core.is_active():
		return
	var core_center: Vector2 = _core.global_position
	var line_color: Color = RED if _last_blocked else field_color
	draw_line(player_center, core_center, Color(line_color, 0.8), 1.0)
	draw_circle(player_center, 2.0, line_color)
	draw_circle(core_center, 2.0, line_color)
	_draw_force_arrow(player_center, _last_player_force, line_color)
	_draw_force_arrow(core_center, _last_force, line_color)


func _draw_force_arrow(origin: Vector2, force: Vector2, color: Color) -> void:
	if force.is_zero_approx():
		return
	var direction: Vector2 = force.normalized()
	var length: float = clampf(force.length() / core_acceleration * 34.0, 8.0, 34.0)
	var tip: Vector2 = origin + direction * length
	draw_line(origin, tip, color, 1.5)
	draw_line(tip, tip - direction.rotated(0.55) * 5.0, color, 1.0)
	draw_line(tip, tip - direction.rotated(-0.55) * 5.0, color, 1.0)


func get_spawn_position() -> Vector2:
	return _spawn_marker.global_position


func get_start_bay() -> StarCoreBayInteractable:
	return _start_bay


func get_target_bay() -> StarCoreBayInteractable:
	return _target_bay


func get_core() -> StarCoreCarrier:
	return _core


func is_active() -> bool:
	return _active


func is_success() -> bool:
	return _success


func get_last_status() -> String:
	return _last_status


func get_last_distance() -> float:
	return _last_distance


func get_last_force() -> Vector2:
	return _last_force


## Combined player force (core pair + registered providers). This is exactly
## the value passed to player.apply_external_force() this tick.
func get_last_player_force() -> Vector2:
	return _last_player_force


func get_last_core_player_force() -> Vector2:
	return _last_core_player_force


func get_last_extra_player_force() -> Vector2:
	return _last_extra_player_force


func get_last_extra_status() -> String:
	return _last_extra_status


func get_last_extra_distance() -> float:
	return _last_extra_distance


func get_player_force_provider_count() -> int:
	return _player_force_providers.size()


func is_last_blocked() -> bool:
	return _last_blocked


func get_e_preview_text() -> String:
	return _last_e_preview


func get_store_hint_text() -> String:
	return _last_store_hint


func get_store_player_core_range() -> float:
	return store_player_core_range


func get_last_release_position() -> Vector2:
	return _last_release_position


func get_last_release_initial_speed() -> float:
	return _last_release_initial_speed


func get_pending_release() -> bool:
	return _pending_release


func get_pending_positive() -> bool:
	return _pending_positive


func get_release_bay() -> StarCoreBayInteractable:
	return _release_bay


func get_store_bay() -> StarCoreBayInteractable:
	return _store_bay


func get_interaction_range() -> float:
	return field_range


func get_platform_rects() -> Array[Rect2]:
	return [BODY_RECT]


func get_collision_body_count() -> int:
	return 1 if _terrain_body != null else 0
