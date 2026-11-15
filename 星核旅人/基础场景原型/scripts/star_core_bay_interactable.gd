@tool
class_name StarCoreBayInteractable
extends Node2D

## Gameplay wrapper around StarCoreBayVisual. The visual component remains a
## pure layered display; this node owns the small bay state machine:
##   LOCKED -> OPENING -> OPEN -> CLOSING -> LOCKED
##
## The core is stored only by an explicit E pressed by the player while the
## player is near this empty bay, the moving core is near the player, and the
## core is inside this bay's small seat zone. There is no automatic capture,
## no speed gate, no slow-zone drag and no long-range attraction into a bay.
##
## `@tool` applies the initial LOCKED/OPEN pose in the editor so the room scene
## is readable without running it. Animation still runs only at runtime.
##
## Record contract (separate from the purple LOCKED core display):
##   - A bay begins with NO record. A preloaded purple core is not history.
##   - The accepted instant of an explicit E store captures the moving core's
##     own `is_positive()` into this bay via `start_store_core()` and emits
##     exactly one `polarity_recorded(positive)`.
##   - The snapshot is never re-read from the player, the bay colour, or the
##     lid animation. Q during opening/closing and later state changes do not
##     alter it.
##   - Releasing the core keeps the record. A later valid store overwrites it,
##     including a store whose polarity equals the current record.
##   - `reset_locked()` / `reset_empty()` clear the record to the initial state.

signal polarity_recorded(positive: bool)

@export var bay_name: String = "BAY"
@export var start_locked: bool = false:
	set(value):
		start_locked = value
		if is_inside_tree():
			_apply_initial_state()
@export var interaction_radius: float = 46.0
## Small seat zone around local (0, +8), the moving core's ground centre.
@export var store_half_extents: Vector2 = Vector2(24.0, 18.0)
@export var release_distance: float = 40.0
@export var lid_duration: float = 0.25

@onready var _visual: StarCoreBayVisual = $BayVisual

enum State { LOCKED, OPENING, OPEN, CLOSING }

var _state: State = State.OPEN
var _has_record: bool = false
var _recorded_positive: bool = true


func _ready() -> void:
	_apply_initial_state()


func _apply_initial_state() -> void:
	if _visual == null:
		_visual = get_node_or_null("BayVisual") as StarCoreBayVisual
	if _visual == null:
		return
	if start_locked:
		_apply_locked_immediate()
	else:
		_apply_empty_open_immediate()


func _apply_locked_immediate() -> void:
	_state = State.LOCKED
	_clear_record()
	_visual.occupied = true
	_visual.show_lock_marker = true
	_visual.set_lid_open_immediately(false)


func _apply_empty_open_immediate() -> void:
	_state = State.OPEN
	_clear_record()
	_visual.occupied = false
	_visual.show_lock_marker = false
	_visual.set_lid_open_immediately(true)


func reset_locked() -> void:
	_apply_locked_immediate()


func reset_empty() -> void:
	_apply_empty_open_immediate()


func stop_animation() -> void:
	if _visual != null:
		_visual.stop_lid_animation()


## Starts opening from the locked state. The caller snapshots the core polarity
## and spawns the moving core only when is_release_ready() becomes true.
func start_release() -> bool:
	if _state != State.LOCKED:
		return false
	_state = State.OPENING
	_visual.show_lock_marker = false
	_visual.occupied = true
	_visual.start_open(lid_duration)
	return true


func is_release_ready() -> bool:
	return _state == State.OPENING and _visual != null and _visual.is_lid_open()


func finish_release() -> void:
	if _state != State.OPENING:
		return
	_state = State.OPEN
	_visual.occupied = false
	_visual.show_lock_marker = false
	_visual.set_lid_open_immediately(true)


## Explicit E store. Position is the only eligibility condition; speed is not
## checked. The room brakes/locks the carrier at store time.
##
## Explicit E store with the active moving core's own polarity at the accepted
## instant. It becomes this bay's record before the lid finishes and is
## independent of the player's Q state. A valid store always records and emits,
## even when the polarity equals the previous record.
func start_store_core(core_positive: bool) -> bool:
	if not _start_closing():
		return false
	_set_record(core_positive, true)
	return true


## Legacy compatibility entry that only starts the lid. It deliberately does
## not invent a polarity record; gameplay uses start_store_core().
func start_store() -> bool:
	return _start_closing()


func _start_closing() -> bool:
	if _state != State.OPEN:
		return false
	_state = State.CLOSING
	_visual.occupied = true
	_visual.show_lock_marker = false
	_visual.start_close(lid_duration)
	return true


func is_store_ready() -> bool:
	return _state == State.CLOSING and _visual != null and _visual.is_lid_closed()


func finish_store() -> void:
	if _state != State.CLOSING:
		return
	_state = State.LOCKED
	_visual.occupied = true
	_visual.show_lock_marker = true
	_visual.set_lid_open_immediately(false)


## True after at least one accepted E store. A preloaded LOCKED bay starts
## without a record, so the UI must not invent a default polarity.
func has_record() -> bool:
	return _has_record


func get_recorded_positive() -> bool:
	return _recorded_positive


func get_record_label() -> String:
	if not _has_record:
		return "NO RECORD"
	return "GOLD +" if _recorded_positive else "CYAN -"


## Clears history without changing the bay state. Normal gameplay uses the
## reset_* methods; this is exposed for explicit data resets.
func clear_record() -> void:
	_clear_record()


func _set_record(positive: bool, emit_signal: bool) -> void:
	_has_record = true
	_recorded_positive = positive
	if emit_signal:
		polarity_recorded.emit(positive)


func _clear_record() -> void:
	_has_record = false
	_recorded_positive = true


func has_core() -> bool:
	return _state != State.OPEN


func is_locked() -> bool:
	return _state == State.LOCKED


func is_open_empty() -> bool:
	return _state == State.OPEN


func is_opening() -> bool:
	return _state == State.OPENING


func is_closing() -> bool:
	return _state == State.CLOSING


func get_state_name() -> String:
	match _state:
		State.LOCKED:
			return "LOCKED"
		State.OPENING:
			return "OPENING"
		State.CLOSING:
			return "CLOSING"
		_:
			return "OPEN"


func get_state_label() -> String:
	return "%s %s" % [bay_name, get_state_name()]


func get_visual() -> StarCoreBayVisual:
	return _visual


func is_player_in_range(player_position: Vector2) -> bool:
	var floor_y: float = global_position.y + 16.0
	if absf(player_position.y - floor_y) > 26.0:
		return false
	return absf(player_position.x - global_position.x) <= interaction_radius


func get_release_point(player_x: float) -> Vector2:
	# Release on the side away from the player. This keeps the core out of the
	# player's body and out of the pedestal at the moment of release.
	var side: float = 1.0 if player_x <= global_position.x else -1.0
	var point: Vector2 = global_position + Vector2(side * release_distance, 8.0)
	point.x = clampf(point.x, 16.0, 624.0)
	return point


func get_store_center() -> Vector2:
	return global_position + Vector2(0.0, 8.0)


func get_store_half_extents() -> Vector2:
	return store_half_extents


## Position-only seat check. No speed, cooldown, or automatic trigger.
func is_core_in_store_zone(core_position: Vector2) -> bool:
	if _state != State.OPEN:
		return false
	var local: Vector2 = to_local(core_position) - Vector2(0.0, 8.0)
	return (
		absf(local.x) <= store_half_extents.x
		and absf(local.y) <= store_half_extents.y
	)


func get_e_release_preview(player_positive: bool, player_in_range: bool) -> String:
	if not player_in_range or _state != State.LOCKED:
		return ""
	var core_label: String = "CYAN -" if player_positive else "GOLD +"
	return "E: RELEASE %s (%s)" % [core_label, bay_name]


func get_e_store_preview(player_in_range: bool) -> String:
	if not player_in_range or _state != State.OPEN:
		return ""
	return "E: STORE CORE (%s)" % bay_name
