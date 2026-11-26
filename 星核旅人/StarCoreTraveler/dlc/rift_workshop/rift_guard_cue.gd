class_name RiftGuardCue
extends Node2D

## Read-only charge cue for the twin guards.
##
## The guards already own the approved gravity field and weakpoint sprites; this
## node only reads their public state and adds three presentation hints:
##   - a 2 px (screen) four-corner frame around the chest while a guard is in its
##     real GRAVITY_CHARGE, breathing 0.55..0.90 over 0.6 s, so the weakpoint
##     stays readable against the busy shell;
##   - a 1 px (screen) dashed attraction line from the chest to the player while
##     the field is actually pulling (opposite phase, inside its range);
##   - a dim, animation-frozen tint on a suspended guard, so the waiting cyan
##     guard does not read as an active attacker.  Its state is restored when the
##     guard wakes.
##
## It never writes guard/player gameplay state and never resolves damage.  The
## only writes are the visuals of the Body / KeyCore sprites and they happen only
## when the suspended state changes, so the guard's own hit flash is untouched.

const CUE_Z_INDEX: int = 3
const FRAME_RADIUS: float = 20.0
const FRAME_TICK: float = 6.0
## Screen-space thickness; divided by camera zoom so it stays 2 px on screen.
const FRAME_WIDTH_PX: float = 2.0
const LINE_WIDTH_PX: float = 1.0
const BREATH_PERIOD: float = 0.6
const BREATH_MIN: float = 0.55
const BREATH_MAX: float = 0.90
const FRAME_COLOR: Color = Color(1.0, 0.93, 0.72)
const LINE_ALPHA: float = 0.20
const DASH_LENGTH: float = 4.0
const DASH_GAP: float = 5.0
const SUSPENDED_BODY_TINT: Color = Color(0.46, 0.52, 0.62, 1.0)
const SUSPENDED_CORE_TINT: Color = Color(0.62, 0.70, 0.78, 0.55)

var _player: Node2D = null
var _guards: Array = []
var _time: float = 0.0
var _weakpoint_ring_visible: bool = false
var _attraction_line_visible: bool = false
var _last_suspended: Dictionary = {}
## Presentation cleanup counters.  They are read-only for tests and make the
## true -> false redraw (the stale-frame fix) observable without inspecting the
## renderer's internal canvas state.
var _close_redraw_count: int = 0
var _draw_count: int = 0
var _last_draw_ring_count: int = 0
var _last_draw_ring_centers: Array[Vector2] = []


func _ready() -> void:
	z_index = CUE_Z_INDEX
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Nothing from this cue is allowed to outlive the chapter scene.  The canvas
## goes away with the node, and the read state is cleared before that so a test
## or a new scene never observes a stale "ring visible" flag.
func _exit_tree() -> void:
	_weakpoint_ring_visible = false
	_attraction_line_visible = false


func configure(player: Node2D, guards: Array) -> void:
	_player = player
	_guards = guards.duplicate()
	_last_suspended.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if get_tree() != null and get_tree().paused:
		# Breathing and tint updates freeze with the tree; the last frame stays.
		return
	_time += delta
	_refresh_suspension_tints()
	var ring: bool = false
	var line: bool = false
	for guard: L3Guard in _guards:
		if _is_guard_charging(guard):
			ring = true
			if _is_pulling(guard):
				line = true
	var changed: bool = ring != _weakpoint_ring_visible \
		or line != _attraction_line_visible
	_weakpoint_ring_visible = ring
	_attraction_line_visible = line
	if changed:
		# A state change in either direction must repaint.  In particular the
		# true -> false edge (charge ended, guard died, guard suspended) used
		# to leave the previous frame's corner brackets floating in the room.
		if not (ring or line):
			_close_redraw_count += 1
		queue_redraw()
	elif ring or line:
		# Breathing animation and a moving chest need a fresh frame.
		queue_redraw()


## Dim a suspended guard's body/core once per state change.  The guard's own
## _physics_process is skipped while suspended, so this tint persists; on wake
## the base's flicker code resumes and this helper restores white first.
func _refresh_suspension_tints() -> void:
	for guard: L3Guard in _guards:
		if guard == null or not is_instance_valid(guard):
			continue
		var suspended: bool = guard.is_suspended()
		var key: int = guard.get_instance_id()
		if _last_suspended.has(key) and bool(_last_suspended[key]) == suspended:
			continue
		_last_suspended[key] = suspended
		var body: CanvasItem = guard.get_node_or_null("Body") as CanvasItem
		if body != null:
			body.modulate = SUSPENDED_BODY_TINT if suspended else Color.WHITE
		var core: CanvasItem = guard.get_node_or_null("KeyCore") as CanvasItem
		if core != null:
			core.modulate = SUSPENDED_CORE_TINT if suspended else Color.WHITE


func _is_guard_charging(guard: L3Guard) -> bool:
	if guard == null or not is_instance_valid(guard):
		return false
	if guard.is_suspended() or guard.is_defeated():
		return false
	return (
		guard.get_state_name() == "GRAVITY_CHARGE"
		and guard.is_vulnerable()
		and guard.is_weakpoint_visible()
	)


func _is_pulling(guard: L3Guard) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if guard.is_cinematic_mode():
		# The cinematic clamp holds the charge for demos/clips; its field does
		# not actually pull, so do not draw an attraction line for it.
		return false
	if _player.is_positive() == guard.is_positive():
		return false
	var chest: Vector2 = guard.get_chest_global_position()
	var tuning: Dictionary = guard.get_field_tuning()
	var field_range: float = float(tuning.get("range", 118.0))
	return _player.global_position.distance_to(chest) <= field_range


func _draw() -> void:
	_draw_count += 1
	_last_draw_ring_count = 0
	_last_draw_ring_centers.clear()
	var zoom: float = 1.0
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		zoom = maxf(camera.zoom.x, 0.01)
	var frame_width: float = clampf(FRAME_WIDTH_PX / zoom, FRAME_WIDTH_PX, 6.0)
	var line_width: float = clampf(LINE_WIDTH_PX / zoom, LINE_WIDTH_PX, 3.0)
	var breath: float = 0.5 + 0.5 * sin(_time * TAU / BREATH_PERIOD)
	var alpha: float = lerpf(BREATH_MIN, BREATH_MAX, breath)
	for guard: L3Guard in _guards:
		if not _is_guard_charging(guard):
			continue
		# The frame is anchored to the real chest, with no offset of its own.
		var chest: Vector2 = guard.get_chest_global_position()
		_last_draw_ring_count += 1
		_last_draw_ring_centers.append(chest)
		_draw_corner_frame(chest, alpha, frame_width)
		if _is_pulling(guard):
			_draw_attraction(
				chest, _player.global_position + Vector2(0.0, -15.0), line_width
			)


## Four L-shaped corner ticks: a frame, not a filled ring, so the shell and the
## weakpoint diamond stay readable.  Warm white/gold, never purple.
func _draw_corner_frame(center: Vector2, alpha: float, width: float) -> void:
	var half: float = FRAME_RADIUS
	var tick: float = FRAME_TICK
	var line_color: Color = Color(
		FRAME_COLOR.r, FRAME_COLOR.g, FRAME_COLOR.b, clampf(alpha, 0.0, 1.0)
	)
	var corners: Array[Vector2] = [
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(-half, half), Vector2(half, half),
	]
	for corner: Vector2 in corners:
		var p: Vector2 = center + corner
		var dx: float = tick if corner.x < 0.0 else -tick
		var dy: float = tick if corner.y < 0.0 else -tick
		draw_line(p, p + Vector2(dx, 0.0), line_color, width)
		draw_line(p, p + Vector2(0.0, dy), line_color, width)


func _draw_attraction(from: Vector2, to: Vector2, width: float) -> void:
	var delta: Vector2 = to - from
	var distance: float = delta.length()
	if distance <= 1.0:
		return
	var direction: Vector2 = delta / distance
	var line_color: Color = Color(
		FRAME_COLOR.r, FRAME_COLOR.g, FRAME_COLOR.b, LINE_ALPHA
	)
	var travelled: float = 12.0
	while travelled < distance - 6.0:
		var start: Vector2 = from + direction * travelled
		var end: Vector2 = from + direction * minf(travelled + DASH_LENGTH, distance)
		draw_line(start, end, line_color, width)
		travelled += DASH_LENGTH + DASH_GAP


# --- read API (tests) ------------------------------------------------------

func is_weakpoint_ring_visible() -> bool:
	return _weakpoint_ring_visible


func is_attraction_line_visible() -> bool:
	return _attraction_line_visible


## Number of true -> false transitions that requested a repaint.
func get_close_redraw_count() -> int:
	return _close_redraw_count


## Number of completed _draw passes; the last pass' ring count is 0 after the
## cue has closed, proving the stale frame was replaced with an empty one.
func get_draw_count() -> int:
	return _draw_count


func get_last_draw_ring_count() -> int:
	return _last_draw_ring_count


func get_last_draw_ring_centers() -> Array[Vector2]:
	return _last_draw_ring_centers.duplicate()
