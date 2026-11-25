@tool
class_name RuneStoneField
extends Node2D

## Reusable rune-stone force field.
##
## This component owns one rune stone's presentation and its force *sample*.
## It never applies force to a player, a star core, or any other body. The
## containing room has the single force-entry point and decides whether, how
## often, and to which body the returned acceleration is applied:
##
##   var field: Dictionary = rune_stone.sample_field(
##       player_center, player.is_positive(), player.get_rid()
##   )
##   var acceleration: Vector2 = field["acceleration"]
##
## Only the player is expected to consume this value. Star-core transport and
## "keep the nearest polarity until the next deposit" belong to the bay/link
## layer; this component only knows how to commit its own polarity.
##
## Activation:
##   initial_active = false starts the stone dormant: the same shell is visible,
##   the crack mask stays dark, no +/- hint or force is produced. sample_field()
##   returns status INACTIVE and exact zero acceleration regardless of distance
##   or player polarity. Sampling never activates the stone.
##
##   The first request_polarity() on a dormant stone is a first light-up, even
##   when its target equals initial_positive: the visual starts from dark,
##   finishes in the target colour, and only then does the field set
##   _active = true, commit the polarity, and emit polarity_committed once.
##   Until that completion, sample_field() stays INACTIVE with zero force.
##   initial_active = true keeps the original always-active behaviour.
##
## Polarity:
##   request_polarity() asks the visual child to dim, then relight in the new
##   colour. The old polarity keeps producing the old force until the visual
##   emits transition_finished. Only then is the polarity committed and
##   polarity_committed emitted. A newer request replaces the target; a stale
##   completion can never overwrite the current request. reset_state() cancels
##   an in-flight transition, restores initial_active / initial_positive, and
##   emits nothing.
##
## Force shape (defaults match the approved F2 baseline):
##   range 160 px, inner 16 px, full 52 px, outer fade 40 px,
##   full acceleration 2400 px/s^2.
##   Same sign repels, opposite sign attracts. The centre line is blocked only
##   by physics bodies on layer 1. The caller's excluded_rid (normally the
##   player) and every collision body owned by this component are excluded.
##
## The scene is @tool and safely draggable in the editor. The stone visual is
## the existing rune_stone_visual.tscn; there is no physical ball collider.

signal polarity_committed(positive: bool)

const STATUS_ATTRACT: String = "ATTRACT"
const STATUS_REPEL: String = "REPEL"
const STATUS_OUT_OF_RANGE: String = "OUT OF RANGE"
const STATUS_BLOCKED: String = "BLOCKED"
const STATUS_NEAR: String = "NEAR / STABLE"
const STATUS_INACTIVE: String = "INACTIVE"

const MIN_DISTANCE: float = 0.5
const MIN_STRENGTH: float = 0.001
const MIN_RANGE: float = 1.0
const MAX_RANGE: float = 4096.0

const OCCLUSION_MASK: int = 1
const VISUAL_SCENE_PATH: String = "res://scenes/rune_stone_visual.tscn"

const POSITIVE_COLOR: Color = Color("#f4cd63")
const NEGATIVE_COLOR: Color = Color("#5fe1e6")
const INACTIVE_COLOR: Color = Color(0.42, 0.48, 0.48, 0.72)
const BLOCKED_COLOR: Color = Color("#ff7f72")
const CLEAR_LINE_COLOR: Color = Color(0.55, 1.0, 0.72, 0.78)
const RANGE_COLOR: Color = Color(0.40, 0.88, 0.90, 0.50)
const GUIDE_COLOR: Color = Color(0.50, 0.70, 0.72, 0.22)

## Initial activation and the value restored by reset_state(). False shows the
## dormant dark-crack stone; the first request_polarity() performs a first
## light-up and only becomes active when that visual finishes. True preserves
## every existing always-active caller.
@export var initial_active: bool = true:
	set(value):
		initial_active = value
		if Engine.is_editor_hint() or not is_inside_tree():
			_active = value
			_activation_pending = false
			_awaiting_completion = false
			if not is_instance_valid(_visual):
				var visual_node: Node = get_node_or_null("Visual")
				if visual_node is RuneStoneVisual:
					_visual = visual_node as RuneStoneVisual
			if _visual != null:
				_visual.set_energized(value, true)
				_visual.set_polarity(initial_positive, true)
			queue_redraw()

## Initial polarity and the value restored by reset_state(). Changing this in
## the editor previews the stone immediately; at runtime it changes the reset
## value and does not by itself re-request a transition. While dormant,
## is_positive() still reports this internal default but the field has no force
## and callers must check is_activated() before presenting it as a live sign.
@export var initial_positive: bool = true:
	set(value):
		initial_positive = value
		if Engine.is_editor_hint() or not is_inside_tree():
			_positive = value
			_requested_positive = value
			# During scene instantiation the child Visual may not have been
			# added yet. Never create a fallback here: that would duplicate
			# the packed visual. _ready() resolves the real child.
			if not is_instance_valid(_visual):
				var visual_node: Node = get_node_or_null("Visual")
				if visual_node is RuneStoneVisual:
					_visual = visual_node as RuneStoneVisual
			if _visual != null:
				_visual.set_polarity(value, true)
		queue_redraw()

@export_range(1.0, 4096.0, 1.0, "suffix:px") var field_range: float = 160.0:
	set(value):
		field_range = clampf(value, MIN_RANGE, MAX_RANGE)
		queue_redraw()

@export_range(0.0, 4096.0, 1.0, "suffix:px") var inner_radius: float = 16.0:
	set(value):
		inner_radius = clampf(value, 0.0, MAX_RANGE)
		queue_redraw()

@export_range(0.0, 4096.0, 1.0, "suffix:px") var full_radius: float = 52.0:
	set(value):
		full_radius = clampf(value, 0.0, MAX_RANGE)
		queue_redraw()

@export_range(0.0, 4096.0, 1.0, "suffix:px") var outer_fade: float = 40.0:
	set(value):
		outer_fade = clampf(value, 0.0, MAX_RANGE)
		queue_redraw()

@export_range(0.0, 20000.0, 10.0, "suffix:px/s^2") var full_acceleration: float = 2400.0:
	set(value):
		full_acceleration = clampf(value, 0.0, 20000.0)
		queue_redraw()

## When true, sample_field shows/hides the visual's small +/- hint as the
## player's centre enters/leaves the range. Call set_polarity_hint_visible()
## to take manual control, or clear_polarity_hint_override() to resume auto.
@export var auto_hint_in_range: bool = true

var _visual: RuneStoneVisual
var _active: bool = true
var _positive: bool = true
var _requested_positive: bool = true
var _activation_pending: bool = false
## Accept exactly one completion for the current request. reset_state() and
## cancel_pending_request() clear it so an abandoned callback cannot activate
## the stone or change its polarity.
var _awaiting_completion: bool = false
var _debug_enabled: bool = false

var _hint_manual: bool = false

var _last_sample_valid: bool = false
var _last_player_center: Vector2 = Vector2.ZERO
var _last_acceleration: Vector2 = Vector2.ZERO
var _last_distance: float = 0.0
var _last_blocked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	_ensure_visual()

	_active = initial_active
	_positive = initial_positive
	_requested_positive = initial_positive
	_activation_pending = false
	_awaiting_completion = false
	if _visual != null:
		if not Engine.is_editor_hint():
			if not _visual.transition_finished.is_connected(_on_visual_transition_finished):
				_visual.transition_finished.connect(_on_visual_transition_finished)
		_visual.show_polarity_hint = false
		_visual.set_energized(initial_active, true)
		_visual.set_polarity(initial_positive, true)
	queue_redraw()


## Pure force sample. Presentation may update the +/- hint and debug cache, but
## no body or external-force channel is touched here.
func sample_field(
	player_center: Vector2,
	player_positive: bool,
	excluded_rid: RID = RID()
) -> Dictionary:
	var field_center: Vector2 = global_position
	var to_field: Vector2 = field_center - player_center
	var distance: float = to_field.length()
	var result: Dictionary = {
		"acceleration": Vector2.ZERO,
		"status": STATUS_OUT_OF_RANGE,
		"distance": distance,
		"blocked": false,
	}

	# Dormant stones never produce force and sampling never wakes them. This
	# check comes before range/polarity so every dormant sample is exactly zero.
	if not _active:
		result["status"] = STATUS_INACTIVE
		_publish_sample(player_center, result)
		return result

	if distance >= field_range:
		_publish_sample(player_center, result)
		return result

	var blocked: bool = false
	if distance > MIN_DISTANCE:
		blocked = _is_line_blocked(player_center, excluded_rid)
	if blocked:
		result["status"] = STATUS_BLOCKED
		result["blocked"] = true
		_publish_sample(player_center, result)
		return result

	# At, or extremely close to, the stone centre the direction is undefined.
	# Return a finite zero vector instead of normalising a near-zero vector.
	if distance <= MIN_DISTANCE:
		result["status"] = STATUS_NEAR
		_publish_sample(player_center, result)
		return result

	var strength: float = _strength_for(distance)
	if strength <= MIN_STRENGTH:
		result["status"] = STATUS_NEAR
		_publish_sample(player_center, result)
		return result

	var direction: Vector2 = to_field / distance
	var same_polarity: bool = player_positive == _positive
	if same_polarity:
		direction = -direction

	result["status"] = STATUS_REPEL if same_polarity else STATUS_ATTRACT
	result["acceleration"] = direction * full_acceleration * strength
	_publish_sample(player_center, result)
	return result


## Request a target polarity. The committed polarity (and therefore the force
## sign) changes only after the visual child finishes its dim/relight. On a
## dormant stone this is the first light-up: even a target equal to
## initial_positive runs the transition and emits exactly one commit at the end.
func request_polarity(positive: bool) -> void:
	if Engine.is_editor_hint():
		_active = true
		_positive = positive
		_requested_positive = positive
		_activation_pending = false
		_awaiting_completion = false
		if _visual != null:
			_visual.set_energized(true, true)
			_visual.set_polarity(positive, true)
		queue_redraw()
		return

	if not is_inside_tree():
		_active = true
		_positive = positive
		_requested_positive = positive
		_activation_pending = false
		_awaiting_completion = false
		if not is_instance_valid(_visual):
			var visual_node: Node = get_node_or_null("Visual")
			if visual_node is RuneStoneVisual:
				_visual = visual_node as RuneStoneVisual
		if _visual != null:
			_visual.set_energized(true, true)
			_visual.set_polarity(positive, true)
		queue_redraw()
		return

	_ensure_visual()
	if _visual == null:
		_active = true
		_positive = positive
		_requested_positive = positive
		_activation_pending = false
		_awaiting_completion = false
		queue_redraw()
		return

	if not _active:
		# Repeated same target while the first light-up is already running is a
		# no-op; a different target replaces it and the latest target wins.
		if (
			_activation_pending
			and positive == _requested_positive
			and _visual.is_transitioning()
		):
			return
		_requested_positive = positive
		_activation_pending = true
		_awaiting_completion = true
		_visual.energize_to(positive, false)
		queue_redraw()
		return

	# Same target while it is already committed or already animating is a
	# no-op: no colour replay, no duplicate commit.
	if (
		positive == _requested_positive
		and positive == _visual.polarity_positive
		and (positive == _positive or _visual.is_transitioning())
	):
		return

	_requested_positive = positive
	_awaiting_completion = true
	if _visual.is_energized():
		_visual.set_polarity(positive, false)
	else:
		_visual.energize_to(positive, false)
	queue_redraw()


## Whether the stone is live and may produce force. False after construction
## with initial_active=false and after reset_state() when that export is false.
func is_activated() -> bool:
	return _active


## Committed polarity. This is the value used by sample_field, not the target
## currently being animated toward. While dormant it is only the internal
## initial default; presentation must check is_activated() before claiming the
## stone is currently positive or negative.
func is_positive() -> bool:
	return _positive


func is_transitioning() -> bool:
	return _visual != null and _visual.is_transitioning()


func is_activation_pending() -> bool:
	return _activation_pending


## Abandon an in-flight request without changing committed gameplay state.
## Used when a newer record supersedes an older field request. The visual
## restores its last committed look (dark while dormant) and emits nothing.
func cancel_pending_request() -> void:
	_activation_pending = false
	_awaiting_completion = false
	_requested_positive = _positive
	if _visual != null:
		if _active:
			_visual.cancel_transition()
		else:
			# First-light-up abandoned before commit: return to the dormant dark
			# crack, not to a lit initial-colour stone.
			_visual.set_energized(false, true)
	queue_redraw()


func get_requested_positive() -> bool:
	return _requested_positive


func get_visual() -> RuneStoneVisual:
	return _visual


## Restore initial_active / initial_positive immediately. Used by R and room
## exit only. Any in-flight transition is cancelled without emitting a stale
## completion, and no delayed callback can activate the stone afterwards.
func reset_state() -> void:
	_requested_positive = initial_positive
	_positive = initial_positive
	_active = initial_active
	_activation_pending = false
	_awaiting_completion = false
	_hint_manual = false
	_last_sample_valid = false
	_last_acceleration = Vector2.ZERO
	_last_distance = 0.0
	_last_blocked = false

	if _visual != null:
		_visual.show_polarity_hint = false
		_visual.set_energized(initial_active, true)
		_visual.set_polarity(initial_positive, true)
	queue_redraw()


## Checkpoint restore only: commit a known record without replaying the pulse or
## first light-up. It is not a gameplay request and emits no signal. Used by the
## formal L2 stable-checkpoint restore after pending work has been cancelled.
func restore_committed_state(positive: bool, activated: bool) -> void:
	_requested_positive = positive
	_positive = positive
	_active = activated
	_activation_pending = false
	_awaiting_completion = false
	_hint_manual = false
	_last_sample_valid = false
	_last_acceleration = Vector2.ZERO
	_last_distance = 0.0
	_last_blocked = false
	if _visual != null:
		_visual.show_polarity_hint = false
		_visual.set_energized(activated, true)
		_visual.set_polarity(positive, true)
	queue_redraw()


func set_debug_enabled(enabled: bool) -> void:
	_debug_enabled = enabled
	queue_redraw()


func is_debug_enabled() -> bool:
	return _debug_enabled


## Manual hint control. While manual, sample_field will not auto-toggle it.
func set_polarity_hint_visible(visible: bool) -> void:
	_hint_manual = true
	if _visual != null:
		_visual.show_polarity_hint = visible


func clear_polarity_hint_override() -> void:
	_hint_manual = false
	_update_auto_hint()


func get_field_range() -> float:
	return field_range


func get_full_acceleration() -> float:
	return full_acceleration


func _on_visual_transition_finished(positive: bool) -> void:
	if Engine.is_editor_hint():
		return
	# A reset, cancel or superseded request clears this gate, so an abandoned
	# completion cannot activate the stone.
	if not _awaiting_completion:
		return
	# Ignore completions that belong to an older, superseded request.
	if positive != _requested_positive:
		return
	_awaiting_completion = false
	_activation_pending = false
	if not _active:
		# First light-up: the visual has finished in the target colour, so this
		# is the one moment the stone becomes live and gains real force.
		_active = true
		_positive = positive
		polarity_committed.emit(_positive)
		queue_redraw()
		return
	if positive == _positive:
		return
	_positive = positive
	polarity_committed.emit(_positive)
	queue_redraw()


func _publish_sample(player_center: Vector2, result: Dictionary) -> void:
	_last_sample_valid = true
	_last_player_center = player_center
	_last_distance = float(result["distance"])
	_last_acceleration = result["acceleration"]
	_last_blocked = bool(result["blocked"])
	_update_auto_hint()
	if _debug_enabled:
		queue_redraw()


func _update_auto_hint() -> void:
	if _visual == null or not auto_hint_in_range or _hint_manual:
		return
	# Dormant stones never draw a +/- that could be mistaken for a live sign.
	var visible: bool = _active and _last_sample_valid and _last_distance < field_range
	if _visual.show_polarity_hint != visible:
		_visual.show_polarity_hint = visible


func _strength_for(distance: float) -> float:
	if distance >= field_range:
		return 0.0

	var inner: float = clampf(inner_radius, 0.0, field_range)
	var full: float = clampf(full_radius, inner, field_range)
	var near_factor: float
	if full - inner <= 0.001:
		near_factor = 1.0 if distance > inner else 0.0
	else:
		near_factor = smoothstep(inner, full, distance)

	var fade: float = clampf(outer_fade, 0.0, field_range)
	var outer_factor: float = 1.0
	if fade > 0.001:
		outer_factor = 1.0 - smoothstep(field_range - fade, field_range, distance)
	return near_factor * outer_factor


func _is_line_blocked(origin: Vector2, excluded_rid: RID) -> bool:
	if not is_inside_tree():
		return false
	var world: World2D = get_world_2d()
	if world == null:
		return false
	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	if space == null:
		return false

	var exclusions: Array[RID] = []
	if excluded_rid.is_valid():
		exclusions.append(excluded_rid)
	_collect_owned_rids(self, exclusions)

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		origin, global_position, OCCLUSION_MASK
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = exclusions
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()


## The rune stone itself must never occlude its own field. Any collision body
## that belongs to this component's subtree is excluded from the ray.
func _collect_owned_rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject2D:
		var rid: RID = (node as CollisionObject2D).get_rid()
		if rid.is_valid() and not out.has(rid):
			out.append(rid)
	for child: Node in node.get_children():
		_collect_owned_rids(child, out)


func _ensure_visual() -> void:
	if is_instance_valid(_visual):
		return
	var existing: Node = get_node_or_null("Visual")
	if existing is RuneStoneVisual:
		_visual = existing as RuneStoneVisual
		return
	if Engine.is_editor_hint():
		return
	var packed: PackedScene = load(VISUAL_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	if instance is RuneStoneVisual:
		instance.name = "Visual"
		add_child(instance)
		_visual = instance as RuneStoneVisual


func _draw() -> void:
	if not _debug_enabled:
		return

	var accent: Color = (
		INACTIVE_COLOR if not _active
		else (POSITIVE_COLOR if _positive else NEGATIVE_COLOR)
	)
	draw_arc(Vector2.ZERO, field_range, 0.0, TAU, 96, RANGE_COLOR, 1.0, true)
	draw_arc(Vector2.ZERO, clampf(full_radius, 0.0, field_range), 0.0, TAU, 64, GUIDE_COLOR, 1.0, true)
	draw_arc(Vector2.ZERO, clampf(inner_radius, 0.0, field_range), 0.0, TAU, 32, GUIDE_COLOR, 1.0, true)

	if _last_sample_valid:
		var local_center: Vector2 = to_local(_last_player_center)
		if not _active:
			# Range stays readable under F3, but no line or arrow implies a
			# force that does not exist yet.
			draw_circle(local_center, 2.0, INACTIVE_COLOR)
		else:
			var line_color: Color = BLOCKED_COLOR if _last_blocked else CLEAR_LINE_COLOR
			draw_line(local_center, Vector2.ZERO, line_color, 1.0, true)
			draw_circle(local_center, 2.0, line_color)
		if _active and not _last_acceleration.is_zero_approx():
			var direction: Vector2 = _last_acceleration.normalized()
			var denominator: float = maxf(full_acceleration, 0.001)
			var length: float = clampf(
				_last_acceleration.length() / denominator * 30.0, 8.0, 30.0
			)
			var tip: Vector2 = local_center + direction * length
			draw_line(local_center, tip, accent, 1.5, true)
			draw_line(tip, tip - direction.rotated(0.55) * 5.0, accent, 1.0, true)
			draw_line(tip, tip - direction.rotated(-0.55) * 5.0, accent, 1.0, true)

	draw_circle(Vector2.ZERO, 2.5, accent)
