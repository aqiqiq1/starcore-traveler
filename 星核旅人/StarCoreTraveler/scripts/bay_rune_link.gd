class_name BayRuneLink
extends Node2D

## Gameplay glue between one real star-core bay, one PolarityLinkVisual and one
## RuneStoneField (duck-typed; the field component is owned by its own scene).
##
## Timing contract, all driven by real events rather than polling:
##   1. The bay accepts an explicit E store and captures the moving core's own
##      polarity. `polarity_recorded` arrives here synchronously.
##   2. The record lamp immediately shows that real record. No default gold is
##      invented before the first store.
##   3. The existing short visual pulse starts toward the stone.
##   4. Only when the pulse reaches the stone is `request_polarity()` called.
##   5. The field's own visual transition finishes, then it commits its actual
##      force polarity and emits `polarity_committed`. A dormant field emits
##      nothing before this point and stays INACTIVE with zero force.
##
## Releasing the core does not touch the record or the stone. A later valid
## store overwrites the lamp and starts a new pulse; the newest request always
## wins. If the field was already changing for the older record, that pending
## field request is cancelled before the new pulse starts, so its late
## completion cannot activate the stone. `reset_link()` stops the pulse and
## resets the field, so an old request cannot land after R or a room reset.
##
## This node applies no force. The room calls `sample_player_force()` and sums
## it with the player-core pair force exactly once per tick.

signal record_lamp_updated(positive: bool, available: bool)
signal pulse_started(positive: bool)
signal pulse_delivered(positive: bool)
signal field_requested(positive: bool)
signal field_committed(positive: bool)
signal link_reset

@export var bay_path: NodePath
@export var field_path: NodePath
@export var link_visual_path: NodePath
## Used only when the field is missing or does not expose is_positive().
@export var initial_field_positive: bool = true
@export var transfer_duration: float = 0.75

var _bay: StarCoreBayInteractable
var _field: Node
var _link_visual: PolarityLinkVisual

var _has_pending_pulse: bool = false
var _pending_positive: bool = true
var _field_pending: bool = false
var _field_pending_positive: bool = true
var _field_committed_positive: bool = true


func _ready() -> void:
	_bay = get_node_or_null(bay_path) as StarCoreBayInteractable
	_field = get_node_or_null(field_path)
	_link_visual = get_node_or_null(link_visual_path) as PolarityLinkVisual
	_connect_sources()
	_apply_initial_display()


func _process(_delta: float) -> void:
	# The field normally emits polarity_committed. This fallback only handles
	# legal no-emission cases: requesting the already-committed polarity, or a
	# rapid request that returns to the committed value mid-transition. It
	# observes committed state; it never applies force or advances visuals.
	if not _field_pending or _field == null or not is_instance_valid(_field):
		return
	if _field.has_method("is_transitioning") and bool(_field.call("is_transitioning")):
		return
	# A dormant field may internally default to the requested sign. Do not
	# settle on that value: only a finished first light-up makes it live.
	if not _field_is_active():
		return
	if not _field.has_method("is_positive"):
		return
	if bool(_field.call("is_positive")) != _field_pending_positive:
		return
	_settle_field_commit(_field_pending_positive)


func _exit_tree() -> void:
	if _link_visual != null and is_instance_valid(_link_visual):
		_link_visual.stop_transfer()


func _connect_sources() -> void:
	if _bay != null and _bay.has_signal(&"polarity_recorded"):
		var bay_callable: Callable = Callable(self, "_on_bay_polarity_recorded")
		if not _bay.is_connected(&"polarity_recorded", bay_callable):
			_bay.polarity_recorded.connect(bay_callable)
	if _link_visual != null:
		var visual_callable: Callable = Callable(self, "_on_visual_delivery_finished")
		if not _link_visual.is_connected(&"visual_delivery_finished", visual_callable):
			_link_visual.visual_delivery_finished.connect(visual_callable)
		_link_visual.update_record_on_delivery = false
		_link_visual.transfer_duration = transfer_duration
	if _field != null and _field.has_signal(&"polarity_committed"):
		var field_callable: Callable = Callable(self, "_on_field_polarity_committed")
		if not _field.is_connected(&"polarity_committed", field_callable):
			_field.connect(&"polarity_committed", field_callable)


func _apply_initial_display() -> void:
	_field_committed_positive = _read_field_positive()
	if _bay != null and _bay.has_record():
		_show_record(_bay.get_recorded_positive())
	else:
		_show_no_record()


func _on_bay_polarity_recorded(positive: bool) -> void:
	# A newer record supersedes any field change for the previous record. Cancel
	# that pending change (visual only, committed force untouched) so its late
	# completion can never activate the stone or win over this new pulse.
	if _field_pending:
		_field_pending = false
		_field_pending_positive = _field_committed_positive
		if _field != null and is_instance_valid(_field) and _field.has_method("cancel_pending_request"):
			_field.call("cancel_pending_request")

	# 1) Real record and lamp first. 2) Then the existing light pulse.
	_has_pending_pulse = true
	_pending_positive = positive
	_show_record(positive)
	record_lamp_updated.emit(positive, true)
	if _link_visual != null:
		_link_visual.play_transfer(positive)
	pulse_started.emit(positive)


func _on_visual_delivery_finished(positive: bool) -> void:
	# The visual component is already last-call-wins; this guard keeps a reset
	# or a newer store from accepting an abandoned completion.
	if not _has_pending_pulse or positive != _pending_positive:
		return
	_has_pending_pulse = false
	pulse_delivered.emit(positive)
	if _field == null or not _field.has_method("request_polarity"):
		return
	_field_pending = true
	_field_pending_positive = positive
	_field.call("request_polarity", positive)
	field_requested.emit(positive)
	# request_polarity() deliberately does nothing when an ACTIVE stone is
	# already committed to this polarity, so no transition would ever emit.
	# Treat only that case as an immediate same-polarity acknowledgement. A
	# dormant stone always runs a first light-up, even when its internal default
	# already equals the target.
	if _field_is_active() and _field.has_method("is_positive") and bool(_field.call("is_positive")) == positive:
		var transitioning: bool = (
			_field.has_method("is_transitioning")
			and bool(_field.call("is_transitioning"))
		)
		if not transitioning:
			_settle_field_commit(positive)


func _on_field_polarity_committed(positive: bool) -> void:
	# After reset_link() the field should have cancelled its transition. If a
	# late callback still arrives, it must not revive the old request state.
	if not _field_pending:
		return
	if positive != _field_pending_positive:
		return
	_settle_field_commit(positive)


func _settle_field_commit(positive: bool) -> void:
	_field_pending = false
	_field_committed_positive = positive
	field_committed.emit(positive)


## Restores the initial presentation and cancels in-flight pulse/field work.
## Repeated calls are safe and create no nodes.
func reset_link() -> void:
	_has_pending_pulse = false
	_field_pending = false
	_field_pending_positive = _field_committed_positive
	if _link_visual != null and is_instance_valid(_link_visual):
		_link_visual.stop_transfer()
	if _field != null and is_instance_valid(_field) and _field.has_method("reset_state"):
		_field.call("reset_state")
	_field_committed_positive = _read_field_positive()
	_show_no_record()
	link_reset.emit()


## Checkpoint restore only: cancel in-flight work and present a known committed
## record/field state immediately. The bay already owns the same record; this
## method emits nothing, so no stale callback can revive an older pulse.
func restore_committed(positive: bool, field_active: bool) -> void:
	_has_pending_pulse = false
	_field_pending = false
	_field_pending_positive = positive
	_field_committed_positive = positive
	if _link_visual != null and is_instance_valid(_link_visual):
		_link_visual.stop_transfer()
		_link_visual.set_record_display(positive, true)
	if _field != null and is_instance_valid(_field) and _field.has_method("restore_committed_state"):
		_field.call("restore_committed_state", positive, field_active)
	elif not field_active and _field != null and is_instance_valid(_field) and _field.has_method("reset_state"):
		_field.call("reset_state")


func _show_record(positive: bool) -> void:
	if _link_visual != null:
		_link_visual.set_record_display(positive, true)


func _show_no_record() -> void:
	if _link_visual != null:
		_link_visual.set_record_display(_field_committed_positive, false)


## Provider contract used by the room. It never applies anything.
func sample_player_force(
	player_center: Vector2,
	player_positive: bool,
	excluded_rid: RID = RID()
) -> Dictionary:
	var result: Dictionary = {
		"acceleration": Vector2.ZERO,
		"status": "NO FIELD",
		"distance": 0.0,
		"blocked": false,
	}
	if _field == null or not is_instance_valid(_field):
		return result
	if not _field.has_method("sample_field"):
		return result
	var sample: Variant = _field.call("sample_field", player_center, player_positive, excluded_rid)
	if not sample is Dictionary:
		return result
	var dictionary: Dictionary = sample as Dictionary
	result["acceleration"] = dictionary.get("acceleration", Vector2.ZERO)
	result["status"] = String(dictionary.get("status", ""))
	result["distance"] = float(dictionary.get("distance", 0.0))
	result["blocked"] = bool(dictionary.get("blocked", false))
	return result


func _read_field_positive() -> bool:
	if _field != null and is_instance_valid(_field) and _field.has_method("is_positive"):
		return bool(_field.call("is_positive"))
	return initial_field_positive


## Backward compatible with older duck-typed fields that have no activation
## state: such fields are treated as always active.
func _field_is_active() -> bool:
	if _field == null or not is_instance_valid(_field):
		return false
	if _field.has_method("is_activated"):
		return bool(_field.call("is_activated"))
	return true


func get_bay() -> StarCoreBayInteractable:
	return _bay


func get_field() -> Node:
	return _field


func get_link_visual() -> PolarityLinkVisual:
	return _link_visual


func has_record() -> bool:
	return _bay != null and _bay.has_record()


func get_record_positive() -> bool:
	return _bay.get_recorded_positive() if _bay != null else false


func get_record_label() -> String:
	return _bay.get_record_label() if _bay != null else "NO RECORD"


func get_field_positive() -> bool:
	return _read_field_positive()


func is_field_activated() -> bool:
	return _field_is_active()


func get_field_label() -> String:
	if _field == null or not is_instance_valid(_field):
		return "NO FIELD"
	if not _field.has_method("is_positive"):
		return "NO API"
	# The internal default sign is not a live sign while dormant. Never present
	# an inactive stone as GOLD + or CYAN -.
	if not _field_is_active():
		return "INACTIVE"
	return "GOLD +" if _read_field_positive() else "CYAN -"


func has_pending_pulse() -> bool:
	return _has_pending_pulse


func get_pending_positive() -> bool:
	return _pending_positive


func is_field_pending() -> bool:
	return _field_pending


func is_transfer_active() -> bool:
	return _link_visual != null and _link_visual.is_transfer_active()


func get_link_stage_label() -> String:
	if _has_pending_pulse:
		return "PULSE IN FLIGHT"
	if _field_pending:
		return "STONE CHANGING"
	if has_record():
		return "STONE LIVE / RECORD HELD"
	return "NO RECORD"
