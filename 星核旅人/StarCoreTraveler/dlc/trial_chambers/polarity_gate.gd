class_name PolarityGate
extends Node2D

## Trial-only polarity door.
##
## A vertical 8x88 light curtain inside a stone frame.  The frame carries one
## large emblem: a gold sun for 辉相, a cyan moon for 澜相.  The gate never reads
## input and never changes the player's phase.  It only compares the player's
## own is_positive() with required_positive:
##   - same phase  -> collision layer 0, the player may walk through;
##   - other phase -> collision layer 1, the gate is solid.
##
## Reading order (approved after the 2026-11-26 play-test):
##   1. whole door + one large sun/moon emblem states the required phase;
##   2. a closed padlock means locked, an open padlock + bright bracket means
##      open;
##   3. walking into a locked gate pulses the emblem red (0.15 s) and raises
##      the trial's Q keycap; no text popup.
## The open transition plays a 0.15 s two-leaf spread and a short generated
## cue.  The deny transition plays a low generated thud.
##
## Anti-pinch rule: while the player's body already overlaps the curtain the
## gate stays passable, even if the phase changes inside it.  The solid layer
## only returns after the body has fully left the 8 px band.  No teleport, no
## damage, no input injection.
##
## Presentation reference: Sonic Unleashed Gaia Gate day/night doors (large sun
## vs moon emblem on a whole-colour door, gated by the matching tablet) and the
## project's approved Celeste Core Block state reading.  See
## REF_GATE_KEY_20261126.md.  Only the reading order is borrowed; the stone
## frame, pixel dimensions, palette, lock and animations are original.

signal opened
signal denied(required_positive: bool)

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const DARK_EDGE: Color = Color(0.004, 0.012, 0.016, 0.96)
const DARK_CAP: Color = Color(0.008, 0.022, 0.028, 0.92)
const STONE: Color = Color("#2b3537")
const STONE_HI: Color = Color("#485558")
const STONE_LO: Color = Color("#0d1517")
const STONE_EDGE: Color = Color("#080d0f")
const PLATE_BG: Color = Color(0.012, 0.028, 0.032, 0.98)
const DENY_RED: Color = Color("#e46755")
const WHITE: Color = Color(1.0, 0.98, 0.88, 1.0)
const OPEN_FIELD_ALPHA: float = 0.26
const CLOSED_FIELD_ALPHA: float = 0.66
## Three 1 px rising dashes inside the 8 px band.  Only the open state animates,
## so the curtain also reads as "alive / passable" by motion, not just by being
## dimmer.
const OPEN_CUE_COUNT: int = 3
const OPEN_CUE_PERIOD: float = 2.2
const OPEN_ANIM_TIME: float = 0.15
const DENY_ANIM_TIME: float = 0.15
const DENY_COOLDOWN: float = 0.90
## Audio is only started when the player is this close: the second gate is open
## at spawn (player starts 澜相) and must not chime away off-screen.
const AUDIO_RANGE: float = 260.0

@export var required_positive: bool = true:
	set(value):
		required_positive = value
		_open = _compute_open()
		_apply_collision()
		queue_redraw()
## Explicit player target.  Empty lets the gate resolve one from the parent at
## runtime (first child that exposes is_positive() and get_collision_size()).
@export var player_path: NodePath = NodePath()
@export var gate_width: float = 8.0
@export var gate_height: float = 88.0

var _player: Node2D = null
var _blocker: StaticBody2D = null
var _shape: CollisionShape2D = null
var _open: bool = false
## True only after the player has really entered the curtain while it was
## passable.  A blocked player pushing on the outside never sets this latch.
var _anti_pinch_latched: bool = false
var _time: float = 0.0
var _open_anim_left: float = 0.0
var _deny_anim_left: float = 0.0
var _deny_cooldown_left: float = 0.0
var _deny_latched: bool = false
var _open_count: int = 0
var _deny_count: int = 0
var _open_sound_count: int = 0
var _deny_sound_count: int = 0
var _open_audio: AudioStreamPlayer = null
var _deny_audio: AudioStreamPlayer = null


func _ready() -> void:
	_blocker = get_node_or_null("Blocker") as StaticBody2D
	_shape = get_node_or_null("Blocker/CollisionShape2D") as CollisionShape2D
	_resolve_player()
	_open = _compute_open()
	_apply_collision()
	_build_audio()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	if _open_anim_left > 0.0:
		_open_anim_left = maxf(_open_anim_left - delta, 0.0)
	if _deny_anim_left > 0.0:
		_deny_anim_left = maxf(_deny_anim_left - delta, 0.0)
	if _deny_cooldown_left > 0.0:
		_deny_cooldown_left = maxf(_deny_cooldown_left - delta, 0.0)

	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	_update_anti_pinch_latch()
	var open_now: bool = _compute_open()
	if open_now != _open:
		_open = open_now
		if open_now:
			_open_count += 1
			_open_anim_left = OPEN_ANIM_TIME
			if _should_play_audio():
				_play_open_audio()
			opened.emit()
		queue_redraw()
	_apply_collision()
	_update_deny_contact(open_now)
	if open_now or _open_anim_left > 0.0:
		# The rising dashes are the only continuously animated part of the open
		# state.  Closed gates redraw only while their deny pulse runs.
		queue_redraw()
	elif _deny_anim_left > 0.0:
		queue_redraw()


# --- public read API -------------------------------------------------------

## True while the curtain is passable for the player's current phase, or while
## the player's body is still inside it (anti-pinch).
func is_open() -> bool:
	return _compute_open()


func is_player_inside() -> bool:
	return _compute_inside()


func get_required_positive() -> bool:
	return required_positive


func is_blocking() -> bool:
	return not _compute_open()


## Collision layer of the solid blocker: 1 = solid, 0 = pass-through.
func get_collision_layer() -> int:
	if _blocker == null:
		return -1
	return _blocker.collision_layer


func get_gate_size() -> Vector2:
	return Vector2(gate_width, gate_height)


func get_gate_rect() -> Rect2:
	return Rect2(
		global_position + Vector2(-gate_width * 0.5, -gate_height),
		Vector2(gate_width, gate_height)
	)


func get_player_rect() -> Rect2:
	if _player == null or not is_instance_valid(_player):
		return Rect2()
	var size: Vector2 = Vector2(12.0, 30.0)
	if _player.has_method("get_collision_size"):
		size = _player.call("get_collision_size") as Vector2
	return Rect2(
		_player.global_position + Vector2(-size.x * 0.5, -size.y),
		size
	)


func get_state_name() -> String:
	return "open" if _compute_open() else "blocked"


## "sun" for 辉相, "moon" for 澜相; used by tests and the capture harness.
func get_emblem_kind() -> String:
	return "sun" if required_positive else "moon"


## "locked" while a wrong-phase body is rejected; "open" while passable.
func get_lock_state() -> String:
	return "open" if _compute_open() else "locked"


func get_open_count() -> int:
	return _open_count


func get_deny_count() -> int:
	return _deny_count


func get_open_sound_count() -> int:
	return _open_sound_count


func get_deny_sound_count() -> int:
	return _deny_sound_count


func is_opening() -> bool:
	return _open_anim_left > 0.0


func is_denying() -> bool:
	return _deny_anim_left > 0.0


func get_open_anim_left() -> float:
	return _open_anim_left


func get_deny_anim_left() -> float:
	return _deny_anim_left


func has_generated_audio() -> bool:
	return _open_audio != null and _deny_audio != null


# --- public write API (tests / level wiring) --------------------------------

func set_required_positive(value: bool) -> void:
	required_positive = value


func set_player_node(player: Node2D) -> void:
	_player = player
	_anti_pinch_latched = false
	_open = _compute_open()
	_deny_latched = false
	_apply_collision()
	queue_redraw()


# --- internals -------------------------------------------------------------

func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if not player_path.is_empty():
		var target: Node = get_node_or_null(player_path)
		if target is Node2D:
			_player = target as Node2D
			return
	var parent: Node = get_parent()
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child is Node2D and child.has_method("is_positive") \
				and child.has_method("get_collision_size"):
			_player = child as Node2D
			return


func _compute_open() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var player_positive: bool = bool(_player.call("is_positive"))
	if player_positive == required_positive:
		return true
	# Only a player who really entered while the curtain was passable keeps it
	# open.  A blocked player standing against the outside can never trigger
	# the anti-pinch path.
	return _anti_pinch_latched and _compute_inside()


func _update_anti_pinch_latch() -> void:
	if not _compute_inside():
		_anti_pinch_latched = false
		return
	if _player == null or not is_instance_valid(_player):
		return
	var same_phase: bool = bool(_player.call("is_positive")) == required_positive
	# `_open` is the previous frame's result: it is still true on the exact tick
	# the player changes phase inside the gate, so the latch has no one-frame
	# hole that could clamp the body.
	if same_phase or _open:
		_anti_pinch_latched = true


func _compute_inside() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	# Exact body/curtain overlap.  No outside margin: touching the closed gate
	# must not count as inside.
	return get_player_rect().intersects(get_gate_rect())


func _update_deny_contact(open_now: bool) -> void:
	if open_now:
		_deny_latched = false
		return
	if _player == null or not is_instance_valid(_player):
		_deny_latched = false
		return
	var player_rect: Rect2 = get_player_rect().grow(RETOUCH_MARGIN)
	var gate_rect: Rect2 = get_gate_rect().grow(RETOUCH_MARGIN)
	var touching: bool = player_rect.intersects(gate_rect)
	if not touching:
		_deny_latched = false
		return
	if _deny_latched:
		return
	_deny_latched = true
	if _deny_cooldown_left > 0.0:
		return
	_deny_cooldown_left = DENY_COOLDOWN
	_deny_anim_left = DENY_ANIM_TIME
	_deny_count += 1
	_play_deny_audio()
	denied.emit(required_positive)
	queue_redraw()


const RETOUCH_MARGIN: float = 2.0


func _apply_collision() -> void:
	if _blocker == null:
		return
	var layer: int = 0 if _open else 1
	if _blocker.collision_layer != layer:
		_blocker.collision_layer = layer


# --- generated audio -------------------------------------------------------

func _build_audio() -> void:
	if _open_audio != null and _deny_audio != null:
		return
	_open_audio = AudioStreamPlayer.new()
	_open_audio.name = "GateOpenCue"
	_open_audio.stream = TrialSfx.gate_open()
	_open_audio.volume_db = -9.0
	_open_audio.bus = &"Master"
	add_child(_open_audio)

	_deny_audio = AudioStreamPlayer.new()
	_deny_audio.name = "GateDenyCue"
	_deny_audio.stream = TrialSfx.gate_deny()
	_deny_audio.volume_db = -4.0
	_deny_audio.bus = &"Master"
	add_child(_deny_audio)


func _should_play_audio() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return absf(_player.global_position.x - global_position.x) <= AUDIO_RANGE


func _play_open_audio() -> void:
	if _open_audio == null:
		return
	_open_audio.stop()
	_open_audio.play()
	_open_sound_count += 1


func _play_deny_audio() -> void:
	if _deny_audio == null:
		return
	_deny_audio.stop()
	_deny_audio.play()
	_deny_sound_count += 1


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var half: float = gate_width * 0.5
	var color: Color = GOLD if required_positive else CYAN
	var open: bool = _open or _compute_open()
	var denying: bool = _deny_anim_left > 0.0
	var deny_progress: float = (
		1.0 - _deny_anim_left / DENY_ANIM_TIME if denying else 0.0
	)
	var shake: float = 0.0
	if denying:
		shake = roundf(sin(_time * 90.0) * 1.0)
	var frame_shift: Vector2 = Vector2(shake, 0.0)

	_draw_stone_frame(frame_shift, color, open, denying)

	# 1 px dark border around the whole 8x88 screen.
	draw_rect(Rect2(-half, -gate_height, gate_width, gate_height), DARK_EDGE)
	var inner_x: float = -half + 1.0
	var inner_w: float = gate_width - 2.0
	var inner_h: float = gate_height - 2.0
	var field_alpha: float = OPEN_FIELD_ALPHA if open else CLOSED_FIELD_ALPHA
	draw_rect(Rect2(inner_x, -gate_height + 1.0, inner_w, inner_h),
		Color(color, field_alpha))

	# Vertical light bands: darker at the sides, brighter toward the middle.
	for index: int in range(int(inner_w)):
		var column_x: float = inner_x + float(index)
		var distance: float = absf(column_x + 0.5)
		var band_alpha: float = field_alpha * (0.55 + 0.45 * (1.0 - distance / half))
		if open:
			band_alpha *= 0.55
		draw_rect(Rect2(column_x, -gate_height + 1.0, 1.0, inner_h),
			Color(color, clampf(band_alpha, 0.0, 1.0)))

	# Dark top and bottom caps keep the curtain from reading as a soft gradient.
	draw_rect(Rect2(inner_x, -gate_height + 1.0, inner_w, 7.0), DARK_CAP)
	draw_rect(Rect2(inner_x, -8.0, inner_w, 7.0), DARK_CAP)

	# Bright 1 px side rails: the silhouette reads in both states.
	var rail_alpha: float = 0.55 if open else 0.96
	draw_rect(Rect2(-half, -gate_height, 1.0, gate_height), Color(color, rail_alpha))
	draw_rect(Rect2(half - 1.0, -gate_height, 1.0, gate_height), Color(color, rail_alpha))

	if not open:
		for tick_y: float in [-66.0, -58.0, -30.0, -22.0, -14.0]:
			draw_rect(Rect2(-half + 1.0, tick_y, gate_width - 2.0, 1.0),
				Color(color.lightened(0.25), 0.72))
	else:
		var span: float = gate_height - 18.0
		for index: int in range(OPEN_CUE_COUNT):
			var phase: float = fmod(
				_time / OPEN_CUE_PERIOD + float(index) / float(OPEN_CUE_COUNT),
				1.0
			)
			var cue_y: float = -8.0 - phase * span
			var cue_alpha: float = 0.35 + 0.65 * sin(phase * PI)
			draw_rect(Rect2(-2.0, round(cue_y), 4.0, 1.0),
				Color(1.0, 0.99, 0.94, cue_alpha))
			draw_rect(Rect2(-1.0, round(cue_y) - 2.0, 1.0, 1.0),
				Color(1.0, 1.0, 1.0, 0.8 * cue_alpha))
			draw_rect(Rect2(1.0, round(cue_y) - 2.0, 1.0, 1.0),
				Color(1.0, 1.0, 1.0, 0.8 * cue_alpha))
			draw_rect(Rect2(0.0, round(cue_y) - 3.0, 1.0, 1.0),
				Color(1.0, 1.0, 1.0, 0.8 * cue_alpha))

	# Central bright diamond core, shared by both phases.
	var core_y: float = -gate_height * 0.5
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, core_y - 9.0),
			Vector2(7.0, core_y),
			Vector2(0.0, core_y + 9.0),
			Vector2(-7.0, core_y),
		]),
		Color(color, 0.18 if not open else 0.10)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, core_y - 5.0),
			Vector2(4.0, core_y),
			Vector2(0.0, core_y + 5.0),
			Vector2(-4.0, core_y),
		]),
		color.lerp(Color.WHITE, 0.42)
	)
	draw_rect(Rect2(-1.0, core_y - 1.0, 2.0, 2.0), color.lerp(Color.WHITE, 0.92))

	_draw_open_spread(frame_shift, color)
	_draw_emblem_plate(frame_shift, color, open, denying, deny_progress)


func _draw_stone_frame(shift: Vector2, color: Color, open: bool, denying: bool) -> void:
	var half: float = gate_width * 0.5
	var post_inner: float = half + 1.0
	var post_outer: float = half + 5.0
	var top: float = -104.0
	# Base plinth: connects the two posts to the floor.
	draw_rect(Rect2(-post_outer - 4.0 + shift.x, -4.0, (post_outer + 4.0) * 2.0, 4.0), STONE_EDGE)
	draw_rect(Rect2(-post_outer - 3.0 + shift.x, -3.0, (post_outer + 3.0) * 2.0, 3.0), STONE)
	draw_rect(Rect2(-post_outer - 3.0 + shift.x, -3.0, (post_outer + 3.0) * 2.0, 1.0), STONE_HI)
	# Left / right posts.
	draw_rect(Rect2(-post_outer + shift.x, top, post_outer - post_inner, -top), STONE)
	draw_rect(Rect2(post_inner + shift.x, top, post_outer - post_inner, -top), STONE)
	draw_rect(Rect2(-post_outer + shift.x, top, post_outer - post_inner, 1.0), STONE_HI)
	draw_rect(Rect2(post_inner + shift.x, top, post_outer - post_inner, 1.0), STONE_HI)
	draw_rect(Rect2(-post_outer + shift.x, top, 1.0, -top), STONE_HI)
	draw_rect(Rect2(post_outer - 1.0 + shift.x, top, 1.0, -top), STONE_LO)
	draw_rect(Rect2(post_inner + shift.x, top, 1.0, -top), STONE_LO)
	draw_rect(Rect2(post_inner - 1.0 + shift.x, top, 1.0, -top), STONE_EDGE)
	# Chipped masonry marks.
	for y: float in [-82.0, -53.0, -26.0]:
		draw_rect(Rect2(-post_outer + 1.0 + shift.x, y, 2.0, 1.0), STONE_LO)
		draw_rect(Rect2(post_inner + 2.0 + shift.x, y + 7.0, 1.0, 1.0), STONE_HI)
	# Lintel.
	draw_rect(Rect2(-post_outer - 1.0 + shift.x, top - 8.0, (post_outer + 1.0) * 2.0, 8.0), STONE_EDGE)
	draw_rect(Rect2(-post_outer + shift.x, top - 7.0, post_outer * 2.0, 6.0), STONE)
	draw_rect(Rect2(-post_outer + shift.x, top - 7.0, post_outer * 2.0, 1.0), STONE_HI)
	for x: float in [-7.0, 3.0]:
		draw_rect(Rect2(x + shift.x, top - 5.0, 2.0, 1.0), STONE_LO)
	# A 5 px neck carries the emblem plate, so the icon is visibly mounted on
	# the same door rather than floating as a separate rectangle.
	draw_rect(Rect2(-2.0 + shift.x, top - 12.0, 4.0, 6.0), STONE_EDGE)
	draw_rect(Rect2(-2.0 + shift.x, top - 12.0, 1.0, 6.0), STONE_HI)
	var border_color: Color = color
	if denying:
		border_color = DENY_RED
	border_color.a = 0.92 if open else 0.55
	draw_rect(Rect2(-17.0 + shift.x, -140.0, 34.0, 34.0), STONE_EDGE)
	draw_rect(Rect2(-16.0 + shift.x, -139.0, 32.0, 32.0), PLATE_BG)
	draw_rect(Rect2(-16.0 + shift.x, -139.0, 32.0, 32.0), border_color, false, 1.0)
	for corner: Vector2 in [
		Vector2(-13.0, -136.0), Vector2(12.0, -136.0),
		Vector2(-13.0, -110.0), Vector2(12.0, -110.0),
	]:
		draw_rect(Rect2(corner + shift, Vector2.ONE), border_color)


func _draw_open_spread(shift: Vector2, color: Color) -> void:
	if _open_anim_left <= 0.0:
		return
	var progress: float = 1.0 - _open_anim_left / OPEN_ANIM_TIME
	var spread: float = progress * 7.0
	var alpha: float = (1.0 - progress)
	# Two bright leaves move outward from the centre as the door opens.
	for side: float in [-1.0, 1.0]:
		var x: float = side * (2.0 + spread)
		draw_rect(Rect2(roundf(x) - 1.0, -gate_height + 4.0, 2.0, gate_height - 8.0),
			Color(color.lightened(0.8), 0.75 * alpha))
	# A short white seam flash at the top of the curtain.
	draw_rect(Rect2(-12.0 - spread, -gate_height + 2.0, 24.0 + spread * 2.0, 1.0),
		Color(WHITE, 0.65 * alpha))


func _draw_emblem_plate(
	shift: Vector2, color: Color, open: bool, denying: bool, deny_progress: float
) -> void:
	var center: Vector2 = Vector2(0.0, -123.0) + shift
	var icon_color: Color = color
	if not open:
		icon_color = color.lerp(Color(0.60, 0.65, 0.63), 0.42)
	if denying:
		icon_color = icon_color.lerp(DENY_RED, 0.35 + 0.3 * deny_progress)
	if open:
		icon_color = icon_color.lightened(0.08)

	if required_positive:
		_draw_sun(center, icon_color)
	else:
		_draw_moon(center, icon_color)
	# Locked is the only state with a padlock.  Open is the absence of the
	# lock plus the bright bracket corners below: one binary read, not a tiny
	# "slightly different lock" that disappears at 1x.
	if not open:
		_draw_closed_padlock(center + Vector2(-5.0, 10.0), color)

	if open:
		# Open bracket corners: a second, non-colour cue that the lock is gone.
		var bracket_color: Color = Color(color.lightened(0.4), 0.75)
		for corner: Vector2 in [
			Vector2(-15.0, -137.0), Vector2(11.0, -137.0),
			Vector2(-15.0, -109.0), Vector2(11.0, -109.0),
		]:
			var origin: Vector2 = corner + shift
			var sx: float = 3.0 if origin.x < center.x else -3.0
			var sy: float = 3.0 if origin.y < center.y else -3.0
			draw_rect(Rect2(origin, Vector2(absf(sx), 1.0)), bracket_color)
			draw_rect(Rect2(origin, Vector2(1.0, absf(sy))), bracket_color)

	if denying:
		# Expanding red pulse ring around the emblem.
		var ring_half: float = 15.0 + deny_progress * 12.0
		var ring_alpha: float = 1.0 - deny_progress
		var ring_color: Color = Color(DENY_RED, ring_alpha)
		draw_rect(
			Rect2(center + Vector2(-ring_half, -ring_half),
				Vector2(ring_half * 2.0, ring_half * 2.0)),
			ring_color, false, 1.0
		)


func _draw_sun(center: Vector2, color: Color) -> void:
	# 15 px core + eight 3 px rays: readable as a sun at 1x without a texture.
	for y: int in range(-7, 8):
		var span: int = int(round(sqrt(maxf(49.0 - float(y * y), 0.0))))
		draw_rect(Rect2(center.x - float(span), center.y + float(y),
			float(span * 2 + 1), 1.0), color)
	for rect: Rect2 in [
		Rect2(-1.0, -11.0, 2.0, 3.0), Rect2(-1.0, 8.0, 2.0, 3.0),
		Rect2(-11.0, -1.0, 3.0, 2.0), Rect2(8.0, -1.0, 3.0, 2.0),
		Rect2(-10.0, -10.0, 2.0, 2.0), Rect2(8.0, -10.0, 2.0, 2.0),
		Rect2(-10.0, 8.0, 2.0, 2.0), Rect2(8.0, 8.0, 2.0, 2.0),
	]:
		draw_rect(Rect2(center + rect.position, rect.size), color)
	draw_rect(Rect2(center + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), WHITE)
	draw_rect(Rect2(center + Vector2(4.0, -4.0), Vector2.ONE),
		Color(1.0, 1.0, 1.0, 0.55))


func _draw_moon(center: Vector2, color: Color) -> void:
	# 17 px crescent carved from a filled circle, plus three small stars.
	for y: int in range(-8, 9):
		var span: int = int(round(sqrt(maxf(64.0 - float(y * y), 0.0))))
		draw_rect(Rect2(center.x - float(span), center.y + float(y),
			float(span * 2 + 1), 1.0), color)
	for y: int in range(-8, 9):
		var inner_y: int = y - 1
		var span: int = int(round(sqrt(maxf(49.0 - float(inner_y * inner_y), 0.0))))
		draw_rect(Rect2(center.x + 4.0 - float(span), center.y + float(y),
			float(span * 2 + 1), 1.0), PLATE_BG)
	# Outer-left rim light.
	for y: int in range(-7, 8):
		var span: int = int(round(sqrt(maxf(64.0 - float(y * y), 0.0))))
		if span > 0:
			draw_rect(Rect2(center.x - float(span), center.y + float(y), 1.0, 1.0),
				color.lightened(0.35))
	for star: Vector2 in [Vector2(6.0, -9.0), Vector2(10.0, -4.0), Vector2(4.0, -12.0)]:
		var origin: Vector2 = center + star
		draw_rect(Rect2(origin, Vector2(3.0, 1.0)), WHITE)
		draw_rect(Rect2(origin + Vector2(1.0, -1.0), Vector2(1.0, 3.0)), WHITE)


func _draw_closed_padlock(origin: Vector2, color: Color) -> void:
	# 10x11 padlock hanging from the plate's bottom edge.  At 1x this is the
	# unmistakable locked read; the open state removes it entirely instead of
	# swapping in a two-pixel "open shackle".
	draw_rect(Rect2(origin + Vector2(0.0, 4.0), Vector2(10.0, 8.0)), STONE_EDGE)
	draw_rect(Rect2(origin + Vector2(1.0, 5.0), Vector2(8.0, 6.0)),
		Color(color, 0.98))
	# Shackle: bright arch entering the top of the body.
	draw_rect(Rect2(origin + Vector2(1.0, 0.0), Vector2(8.0, 1.0)),
		Color(color.lightened(0.25), 0.98))
	draw_rect(Rect2(origin + Vector2(1.0, 1.0), Vector2(1.0, 4.0)),
		Color(color.lightened(0.25), 0.98))
	draw_rect(Rect2(origin + Vector2(8.0, 1.0), Vector2(1.0, 4.0)),
		Color(color.lightened(0.25), 0.98))
	# Keyhole.
	draw_rect(Rect2(origin + Vector2(4.0, 6.0), Vector2(2.0, 2.0)), STONE_EDGE)
	draw_rect(Rect2(origin + Vector2(4.0, 8.0), Vector2(2.0, 2.0)), STONE_EDGE)
