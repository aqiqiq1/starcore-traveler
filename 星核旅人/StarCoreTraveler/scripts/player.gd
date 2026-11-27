class_name PrototypePlayer
extends CharacterBody2D

## Single-screen prototype player.
##
## Design constraints:
## - 128x128 source frames but a ~33-36 px visible body.
## - The collision box is body-only (12x30); the scarf and canvas are excluded.
## - Physics state drives animation state; animation completion never drives physics.
## - Chest anchors are explicit per frame and stored in source-frame coordinates.
## - The talisman layers live under VisualRoot, which mirrors with facing.
##   The head glyph and HUD live outside VisualRoot and never mirror.

signal state_changed(anim: StringName, frame: int, frame_count: int)
signal polarity_changed(positive: bool)
## Emitted when a chapter locks the toggle and the player still presses Q.
signal polarity_toggle_denied
signal reset_performed(reason: String, count: int)

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_RUN: StringName = &"run"
const STATE_JUMP: StringName = &"jump"
const STATE_FALL: StringName = &"fall"
const STATE_FALL_LOOP: StringName = &"fall_loop"

const PIVOT_X: float = 59.0
const FRAME_BOTTOM: float = 79.0
const TALISMAN_OFFSET: Vector2 = Vector2(-2.0, -2.0)
const GLOW_OFFSET: Vector2 = Vector2(-5.0, -5.0)
const RING_OFFSET: Vector2 = Vector2(-12.0, -12.0)

const RUN_SPEED: float = 160.0
const WALK_SPEED: float = 100.0
const DOUBLE_TAP_WINDOW: float = 0.25
const GROUND_ACCEL: float = 900.0
const GROUND_DECEL: float = 1250.0
const AIR_ACCEL: float = 650.0
const AIR_DECEL: float = 180.0
const GRAVITY: float = 1100.0
const MAX_FALL_SPEED: float = 850.0
const JUMP_VELOCITY: float = -375.0
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER_TIME: float = 0.10
const DEFAULT_KILL_Y: float = 400.0
const DEFAULT_WORLD_LEFT: float = 6.0
const DEFAULT_WORLD_RIGHT: float = 634.0
const RUN_ANIM_THRESHOLD: float = 12.0

## Per-instance world limits. The single-screen prototypes keep the original
## 6 / 634 / 400 values; a wide level can move the clamp and fall line without
## changing the shared movement constants.
@export var world_left: float = DEFAULT_WORLD_LEFT
@export var world_right: float = DEFAULT_WORLD_RIGHT
@export var kill_y: float = DEFAULT_KILL_Y

## The formal level handles R itself so it can restart the whole level and
## replay the opening. The prototype rooms keep the older self-reset.
@export var allow_self_reset: bool = true

## Formal levels hide the debug +/- glyph above the head; the color talisman
## remains. Default true keeps every existing prototype unchanged.
## Chapter-level lock; DLC2 disables the free toggle so fields/wisps are the
## only phase changes. The base three levels keep the default true.
@export var allow_polarity_toggle: bool = true
@export var show_head_polarity: bool = true:
	set(value):
		show_head_polarity = value
		var badge: Node = get_node_or_null("PolarityBadge")
		if badge != null:
			badge.visible = value

## Anchor trial force limits. Normal walk/run/jump values above stay untouched;
## these only apply on a physics tick where the anchor room supplied a force.
const ANCHOR_MAX_HORIZONTAL_SPEED: float = 320.0
const ANCHOR_MAX_UP_SPEED: float = 500.0
## Level-02 opt-in only; not a change to walk/run/anchor caps.
const ANCHOR_HORIZONTAL_BRAKE_DECEL: float = 900.0

## Explicit chest centres in source-frame pixel coordinates.
## The frame counts must stay in sync with the PNG sheet widths:
## idle 10, walk 10, run 10, jump 6, fall 4, fall_loop 3.
const IDLE_ANCHORS: Array[Vector2i] = [
	Vector2i(64, 63), Vector2i(64, 63), Vector2i(64, 63), Vector2i(64, 64),
	Vector2i(64, 64), Vector2i(64, 64), Vector2i(64, 64), Vector2i(64, 64),
	Vector2i(64, 64), Vector2i(64, 63),
]
const WALK_ANCHORS: Array[Vector2i] = [
	Vector2i(64, 62), Vector2i(64, 62), Vector2i(63, 60), Vector2i(64, 60),
	Vector2i(64, 61), Vector2i(62, 61), Vector2i(64, 60), Vector2i(64, 60),
	Vector2i(64, 59), Vector2i(64, 60),
]
const RUN_ANCHORS: Array[Vector2i] = [
	Vector2i(65, 60), Vector2i(64, 60), Vector2i(62, 61), Vector2i(66, 60),
	Vector2i(66, 58), Vector2i(64, 60), Vector2i(64, 60), Vector2i(65, 62),
	Vector2i(66, 59), Vector2i(67, 59),
]
const JUMP_ANCHORS: Array[Vector2i] = [
	Vector2i(63, 63), Vector2i(63, 59), Vector2i(62, 58),
	Vector2i(63, 59), Vector2i(63, 59), Vector2i(62, 59),
]
const FALL_ANCHORS: Array[Vector2i] = [
	Vector2i(63, 57), Vector2i(63, 58), Vector2i(63, 58), Vector2i(63, 58),
]
const FALL_LOOP_ANCHORS: Array[Vector2i] = [
	Vector2i(63, 58), Vector2i(63, 58), Vector2i(63, 58),
]

const IDLE_TEXTURE: Texture2D = preload("res://assets/characters/male_hero_idle.png")
const WALK_TEXTURE: Texture2D = preload("res://assets/characters/male_hero_walk.png")
const RUN_TEXTURE: Texture2D = preload("res://assets/characters/male_hero_run.png")
const JUMP_TEXTURE: Texture2D = preload("res://assets/characters/male_hero_jump.png")
const FALL_TEXTURE: Texture2D = preload("res://assets/characters/male_hero_fall.png")
const FALL_LOOP_TEXTURE: Texture2D = preload("res://assets/characters/male_hero_fall_loop.png")

const TALISMAN_GOLD: Texture2D = preload("res://assets/talisman/talisman_gold.png")
const TALISMAN_CYAN: Texture2D = preload("res://assets/talisman/talisman_cyan.png")
const GLOW_GOLD: Texture2D = preload("res://assets/talisman/glow_gold_4f.png")
const GLOW_CYAN: Texture2D = preload("res://assets/talisman/glow_cyan_4f.png")
const RING_GOLD: Texture2D = preload("res://assets/talisman/switch_ring_gold_4f.png")
const RING_CYAN: Texture2D = preload("res://assets/talisman/switch_ring_cyan_4f.png")

@onready var _visual_root: Node2D = $VisualRoot
@onready var _character_sprite: Sprite2D = $VisualRoot/CharacterSprite
@onready var _glow: Sprite2D = $VisualRoot/Glow
@onready var _talisman: Sprite2D = $VisualRoot/Talisman
@onready var _switch_ring: Sprite2D = $VisualRoot/SwitchRing
@onready var _debug_overlay: DebugOverlay = $VisualRoot/DebugOverlay
@onready var _badge: PolarityBadge = $PolarityBadge

var _state: StringName = STATE_IDLE
var _facing: int = 1
var _positive: bool = true
var _spawn_position: Vector2 = Vector2.ZERO
var _anim_time: float = 0.0
var _glow_time: float = 0.0
var _ring_time: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _reset_count: int = 0
var _anim_restart_count: int = 0
var _polarity_toggle_count: int = 0
var _showcase_mode: bool = false
var _debug_enabled: bool = false

## Walk/run intent and double-tap bookkeeping. Raw key events are forwarded by
## Main (which keeps processing while paused) so left/right Shift location and
## keyboard echo can be inspected explicitly.
var _move_input_axis: float = 0.0
var _left_shift_held: bool = false
var _sprint_intent: bool = false
var _double_tap_run_locked: bool = false
var _double_tap_direction: int = 0
var _last_tap_direction: int = 0
var _double_tap_timer: float = 0.0
var _left_keys_down: Dictionary = {}
var _right_keys_down: Dictionary = {}

## Short opening/outro movement override. This never writes to the global
## Input singleton: it only replaces the axis sampled inside this player while
## the override is active. clear_input_buffers()/reset_to_spawn()/focus-loss
## handling cancel it so a lost window cannot leave an invisible held key.
var _input_override_active: bool = false
var _input_override_axis: float = 0.0
var _input_override_sprint: bool = false

## Set by the anchor room immediately before the player's physics tick. The
## force is applied once, after normal input/gravity, and is not a new state.
var _external_force: Vector2 = Vector2.ZERO
var _external_force_pending: bool = false
var _last_anchor_assist: bool = false
## Default-off opt-in used only by level 02. When true, release/reverse can
## brake the horizontal field-driven drift in air or on ground, without
## touching vertical attraction/repulsion, jump physics or shared caps.
var _anchor_horizontal_brake_enabled: bool = false
var _last_anchor_horizontal_brake: bool = false
var _ceiling_y: float = -100000.0


func _ready() -> void:
	_spawn_position = global_position
	floor_snap_length = 4.0
	floor_stop_on_slope = true
	up_direction = Vector2.UP
	_visual_root.scale = Vector2(1.0, 1.0)
	_badge.visible = show_head_polarity
	_apply_polarity_visuals()
	_apply_animation(STATE_IDLE, true)
	_update_effect_positions()
	_update_debug_overlay()


func _physics_process(delta: float) -> void:
	if _showcase_mode:
		return

	# Consume the one-tick anchor force request before movement. The external
	# controller runs at process_priority -10, so this request is for this tick.
	var anchor_assist: bool = _external_force_pending
	_external_force_pending = false
	_last_anchor_assist = anchor_assist
	var carried_vx: float = velocity.x

	_double_tap_timer = maxf(_double_tap_timer - delta, 0.0)

	var on_floor_before: bool = is_on_floor()
	if on_floor_before:
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if allow_self_reset and Input.is_action_just_pressed(&"reset"):
		reset_to_spawn("manual", true)
		return

	if _input_override_active:
		_move_input_axis = clampf(_input_override_axis, -1.0, 1.0)
		_sprint_intent = _input_override_sprint and absf(_move_input_axis) > 0.01
	else:
		_move_input_axis = Input.get_axis(&"move_left", &"move_right")
		_update_movement_intent()

	if not _input_override_active and Input.is_action_just_pressed(&"polarity"):
		if allow_polarity_toggle:
			_toggle_polarity()
		else:
			polarity_toggle_denied.emit()

	if absf(_move_input_axis) > 0.01:
		_set_facing(1 if _move_input_axis > 0.0 else -1)

	if not _input_override_active and Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME

	if _jump_buffer_timer > 0.0 and (is_on_floor() or _coyote_timer > 0.0):
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_apply_animation(STATE_JUMP)

	var target_speed: float = _move_input_axis * (RUN_SPEED if _sprint_intent else WALK_SPEED)
	var horizontal_accel: float
	if is_on_floor():
		horizontal_accel = GROUND_ACCEL if absf(target_speed) > 0.01 else GROUND_DECEL
	else:
		horizontal_accel = AIR_ACCEL if absf(target_speed) > 0.01 else AIR_DECEL

	_last_anchor_horizontal_brake = false
	if anchor_assist and absf(carried_vx) > WALK_SPEED + 0.01:
		# Borrowed momentum is protected while the anchor field is acting. Normal
		# input may add speed in the same direction, but cannot brake the fling
		# back down to walk/run speed. Once the field releases the player, normal
		# air control resumes on the following tick.
		if (
			absf(target_speed) > absf(velocity.x)
			and (absf(target_speed) < 0.01 or signf(target_speed) == signf(velocity.x))
		):
			velocity.x = move_toward(velocity.x, target_speed, horizontal_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, target_speed, horizontal_accel * delta)

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if anchor_assist:
		var vx_before_force: float = velocity.x
		velocity += _external_force * delta
		velocity.x = clampf(velocity.x, -ANCHOR_MAX_HORIZONTAL_SPEED, ANCHOR_MAX_HORIZONTAL_SPEED)
		velocity.y = clampf(velocity.y, -ANCHOR_MAX_UP_SPEED, MAX_FALL_SPEED)
		if _anchor_horizontal_brake_enabled and _wants_anchor_horizontal_brake(carried_vx, target_speed):
			# Level-02 opt-in. Restore the pre-force horizontal velocity (not
			# "clamped result minus force", which over-brakes when the shared cap
			# truncated the push), then apply a gradual brake. Vertical force is
			# already applied and never changed. Same-direction input still
			# borrows the force.
			_last_anchor_horizontal_brake = true
			velocity.x = vx_before_force
			velocity.x = move_toward(velocity.x, target_speed, ANCHOR_HORIZONTAL_BRAKE_DECEL * delta)

	move_and_slide()
	_clamp_to_world()

	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0

	if global_position.y > kill_y:
		reset_to_spawn("fall", true)
		return

	_update_state_after_move()
	_update_animation(delta)
	_update_effects(delta)
	_update_debug_overlay()


func _update_movement_intent() -> void:
	var direction: int = 0
	if _move_input_axis > 0.01:
		direction = 1
	elif _move_input_axis < -0.01:
		direction = -1

	if direction == 0:
		# Releasing the direction (or holding both opposite directions) ends a
		# double-tap run and clears its history so re-pressing is a fresh walk.
		if _double_tap_run_locked:
			_cancel_double_tap_run()
	elif _double_tap_run_locked and direction != _double_tap_direction:
		_cancel_double_tap_run()

	_sprint_intent = _left_shift_held or _double_tap_run_locked


func _cancel_double_tap_run() -> void:
	_double_tap_run_locked = false
	_double_tap_direction = 0
	_last_tap_direction = 0
	_double_tap_timer = 0.0


func _clamp_to_world() -> void:
	if global_position.x < world_left:
		global_position.x = world_left
		if velocity.x < 0.0:
			velocity.x = 0.0
	elif global_position.x > world_right:
		global_position.x = world_right
		if velocity.x > 0.0:
			velocity.x = 0.0
	if _ceiling_y > -10000.0 and global_position.y < _ceiling_y:
		global_position.y = _ceiling_y
		if velocity.y < 0.0:
			velocity.y = 0.0


func _update_state_after_move() -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
		if absf(_move_input_axis) > 0.01:
			_apply_animation(STATE_RUN if _sprint_intent else STATE_WALK)
		elif absf(velocity.x) > RUN_ANIM_THRESHOLD:
			_apply_animation(STATE_WALK)
		else:
			_apply_animation(STATE_IDLE)
		return

	if velocity.y < 0.0:
		_apply_animation(STATE_JUMP)
		return

	if _state == STATE_FALL:
		var fall_duration: float = float(_frame_count_for(STATE_FALL)) / _fps_for(STATE_FALL)
		if _anim_time >= fall_duration:
			_apply_animation(STATE_FALL_LOOP)
	elif _state != STATE_FALL_LOOP:
		_apply_animation(STATE_FALL)


func _update_animation(delta: float) -> void:
	_anim_time += delta
	var frame_count: int = _frame_count_for(_state)
	var fps: float = _fps_for(_state)
	var raw_frame: int = int(_anim_time * fps)
	if _loops(_state):
		_character_sprite.frame = raw_frame % frame_count
	else:
		_character_sprite.frame = mini(raw_frame, frame_count - 1)


func _update_effects(delta: float) -> void:
	_glow_time += delta
	_glow.frame = int(_glow_time * 8.0) % 4

	if _switch_ring.visible:
		_ring_time += delta
		if _ring_time >= 0.20:
			_switch_ring.visible = false
		else:
			_switch_ring.frame = mini(int(_ring_time * 20.0), 3)

	_update_effect_positions()


func _update_effect_positions() -> void:
	var anchor: Vector2i = _current_anchor()
	var base: Vector2 = Vector2(float(anchor.x) - PIVOT_X, float(anchor.y) - FRAME_BOTTOM)
	_talisman.position = base + TALISMAN_OFFSET
	_glow.position = base + GLOW_OFFSET
	_switch_ring.position = base + RING_OFFSET
	_badge.position = Vector2(0.0, _head_top_for(_state) - FRAME_BOTTOM - 14.0)
	_debug_overlay.update_overlay(base, Rect2(-6.0, -30.0, 12.0, 30.0))


func _update_debug_overlay() -> void:
	_debug_overlay.visible = _debug_enabled


func _apply_animation(anim: StringName, force: bool = false) -> void:
	if not force and _state == anim:
		return
	_state = anim
	_character_sprite.texture = _texture_for(anim)
	_character_sprite.hframes = _frame_count_for(anim)
	_character_sprite.frame = 0
	_anim_time = 0.0
	_anim_restart_count += 1
	_update_effect_positions()
	state_changed.emit(anim, 0, _frame_count_for(anim))


func _set_facing(direction: int) -> void:
	var new_facing: int = 1 if direction > 0 else -1
	if new_facing == _facing:
		return
	_facing = new_facing
	_visual_root.scale = Vector2(float(_facing), 1.0)
	_update_effect_positions()


## Presentation-only facing for a scripted beat (the L1 opening looks left and
## right in place). It never changes movement, physics or input state.
func set_facing_direction(direction: int) -> void:
	if direction == 0:
		return
	_set_facing(1 if direction > 0 else -1)


## Called by Main._input for every raw keyboard event. Using the actual
## InputEventKey lets us distinguish left/right Shift by location and ignore
## OS key-repeat echo events; an InputMap sprint action would conflate them.
func handle_key_event(event: InputEventKey) -> void:
	if _showcase_mode or event.echo:
		return
	var code: int = int(event.physical_keycode)
	if code == 0:
		code = int(event.keycode)

	if code == KEY_SHIFT:
		if event.location != KEY_LOCATION_LEFT:
			return
		_left_shift_held = event.pressed
		return

	var direction: int = 0
	if code == KEY_A or code == KEY_LEFT:
		direction = -1
	elif code == KEY_D or code == KEY_RIGHT:
		direction = 1
	else:
		return

	if event.pressed:
		_handle_direction_press(direction, code)
	else:
		_handle_direction_release(direction, code)


func _handle_direction_press(direction: int, key_code: int) -> void:
	var keys_down: Dictionary = _left_keys_down if direction < 0 else _right_keys_down
	if keys_down.has(key_code):
		return
	var was_empty: bool = keys_down.is_empty()
	keys_down[key_code] = true
	if not was_empty:
		# A/Left or D/Right held together is still one direction press.
		return

	if _double_tap_run_locked and _double_tap_direction != direction:
		_cancel_double_tap_run()

	var is_double: bool = _last_tap_direction == direction and _double_tap_timer > 0.0
	if is_double:
		_double_tap_run_locked = true
		_double_tap_direction = direction
	_last_tap_direction = direction
	_double_tap_timer = DOUBLE_TAP_WINDOW


func _handle_direction_release(direction: int, key_code: int) -> void:
	var keys_down: Dictionary = _left_keys_down if direction < 0 else _right_keys_down
	keys_down.erase(key_code)
	if keys_down.is_empty() and _double_tap_run_locked and _double_tap_direction == direction:
		_cancel_double_tap_run()


func reset_movement_input_state() -> void:
	_left_shift_held = false
	_sprint_intent = false
	_move_input_axis = 0.0
	_cancel_double_tap_run()
	_left_keys_down.clear()
	_right_keys_down.clear()
	_input_override_active = false
	_input_override_axis = 0.0
	_input_override_sprint = false


## Start a short scripted movement segment (opening run, completion stop). Real
## InputMap actions are ignored until end_input_override(); this does not touch
## Input.action_press or any global input state.
func begin_input_override() -> void:
	_cancel_double_tap_run()
	_left_shift_held = false
	_jump_buffer_timer = 0.0
	_input_override_active = true
	_input_override_axis = 0.0
	_input_override_sprint = false


func set_input_override_axis(axis: float, sprint: bool = false) -> void:
	_input_override_active = true
	_input_override_axis = clampf(axis, -1.0, 1.0)
	_input_override_sprint = sprint and absf(_input_override_axis) > 0.01


func end_input_override() -> void:
	reset_movement_input_state()


func cancel_input_override() -> void:
	reset_movement_input_state()


func is_input_override_active() -> bool:
	return _input_override_active


func set_world_bounds(left: float, right: float) -> void:
	world_left = left
	world_right = maxf(right, left)


func set_kill_y(value: float) -> void:
	kill_y = value


func get_world_left() -> float:
	return world_left


func get_world_right() -> float:
	return world_right


func get_kill_y() -> float:
	return kill_y


func _toggle_polarity() -> void:
	# Each owning chapter already plays the shared DemoAudio switch cue from its
	# polarity_changed handler (gated by the real toggle counter). Keeping the
	# cue here as well would double-play it on every Q press.
	_positive = not _positive
	_polarity_toggle_count += 1
	_ring_time = 0.0
	_switch_ring.visible = true
	_switch_ring.frame = 0
	_apply_polarity_visuals()
	polarity_changed.emit(_positive)


func _apply_polarity_visuals() -> void:
	_talisman.texture = TALISMAN_GOLD if _positive else TALISMAN_CYAN
	_glow.texture = GLOW_GOLD if _positive else GLOW_CYAN
	_switch_ring.texture = RING_GOLD if _positive else RING_CYAN
	_badge.set_positive(_positive)


func _texture_for(anim: StringName) -> Texture2D:
	match anim:
		STATE_IDLE:
			return IDLE_TEXTURE
		STATE_WALK:
			return WALK_TEXTURE
		STATE_RUN:
			return RUN_TEXTURE
		STATE_JUMP:
			return JUMP_TEXTURE
		STATE_FALL:
			return FALL_TEXTURE
		STATE_FALL_LOOP:
			return FALL_LOOP_TEXTURE
		_:
			return IDLE_TEXTURE


func _frame_count_for(anim: StringName) -> int:
	return int(_texture_for(anim).get_width() / 128)


func _fps_for(anim: StringName) -> float:
	match anim:
		STATE_IDLE:
			return 6.0
		STATE_WALK:
			return 9.0
		STATE_RUN:
			return 14.0
		STATE_JUMP:
			return 12.0
		STATE_FALL:
			return 12.0
		STATE_FALL_LOOP:
			return 9.0
		_:
			return 8.0


func _loops(anim: StringName) -> bool:
	return anim == STATE_IDLE or anim == STATE_WALK or anim == STATE_RUN or anim == STATE_FALL_LOOP


func _head_top_for(anim: StringName) -> float:
	match anim:
		STATE_IDLE:
			return 43.0
		STATE_WALK:
			return 42.0
		STATE_RUN:
			return 44.0
		STATE_JUMP:
			return 36.0
		STATE_FALL:
			return 46.0
		STATE_FALL_LOOP:
			return 46.0
		_:
			return 43.0


func _anchors_for(anim: StringName) -> Array[Vector2i]:
	match anim:
		STATE_IDLE:
			return IDLE_ANCHORS
		STATE_WALK:
			return WALK_ANCHORS
		STATE_RUN:
			return RUN_ANCHORS
		STATE_JUMP:
			return JUMP_ANCHORS
		STATE_FALL:
			return FALL_ANCHORS
		STATE_FALL_LOOP:
			return FALL_LOOP_ANCHORS
		_:
			return IDLE_ANCHORS


func _current_anchor() -> Vector2i:
	var anchors: Array[Vector2i] = _anchors_for(_state)
	var index: int = clampi(_character_sprite.frame, 0, anchors.size() - 1)
	return anchors[index]


func reset_to_spawn(reason: String, count_it: bool = true) -> void:
	_showcase_mode = false
	set_physics_process(true)
	reset_movement_input_state()
	_external_force = Vector2.ZERO
	_external_force_pending = false
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_facing = 1
	_visual_root.scale = Vector2(1.0, 1.0)
	_positive = true
	_ring_time = 0.0
	_switch_ring.visible = false
	_glow_time = 0.0
	_polarity_toggle_count = 0
	_apply_polarity_visuals()
	_apply_animation(STATE_IDLE, true)
	_update_effect_positions()
	if count_it:
		_reset_count += 1
	polarity_changed.emit(true)
	reset_performed.emit(reason, _reset_count)


func set_spawn_point(point: Vector2) -> void:
	_spawn_position = point


func set_debug_enabled(value: bool) -> void:
	_debug_enabled = value
	_update_debug_overlay()


func is_debug_enabled() -> bool:
	return _debug_enabled


func clear_input_buffers() -> void:
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	reset_movement_input_state()


## Called once per physics tick by the anchor room before this node moves.
## The force is an acceleration in px/s^2, not a velocity or position change.
func apply_external_force(acceleration: Vector2) -> void:
	_external_force = acceleration
	_external_force_pending = true


func clear_external_force() -> void:
	_external_force = Vector2.ZERO
	_external_force_pending = false


func set_anchor_room_bounds(active: bool) -> void:
	_ceiling_y = 8.0 if active else -100000.0


func get_anchor_force_x() -> float:
	return _external_force.x


func get_anchor_force_y() -> float:
	return _external_force.y


func is_anchor_force_pending() -> bool:
	return _external_force_pending


func set_anchor_horizontal_brake_enabled(value: bool) -> void:
	_anchor_horizontal_brake_enabled = value


func is_anchor_horizontal_brake_enabled() -> bool:
	return _anchor_horizontal_brake_enabled


func was_anchor_horizontal_brake_applied() -> bool:
	return _last_anchor_horizontal_brake


## Compatibility names for the first focused probe/log.
func set_anchor_ground_brake_enabled(value: bool) -> void:
	set_anchor_horizontal_brake_enabled(value)


func is_anchor_ground_brake_enabled() -> bool:
	return is_anchor_horizontal_brake_enabled()


func was_anchor_ground_brake_applied() -> bool:
	return was_anchor_horizontal_brake_applied()


## Level-02-only horizontal gate: neutral release or reverse only. It never
## touches vertical force and never checks/changes is_on_floor. A neutral target
## must brake even when the tracked vx is already ~0; otherwise the field
## re-adds one tick of horizontal push every other tick and the body takes a
## spontaneous step. Non-zero same-direction input still borrows the force.
func _wants_anchor_horizontal_brake(carried_vx: float, target_speed: float) -> bool:
	if _input_override_active:
		return false
	if absf(target_speed) <= 0.01:
		return true
	if absf(carried_vx) < 0.5:
		return false
	if absf(target_speed) > 0.01 and signf(target_speed) == signf(carried_vx):
		return false
	return true


func get_anchor_horizontal_speed_cap() -> float:
	return ANCHOR_MAX_HORIZONTAL_SPEED


func was_anchor_assisted() -> bool:
	return _last_anchor_assist


## Capture/test helper. Freezes physics, applies a specific animation frame,
## polarity, facing and optional ring frame for an actual engine viewport shot.
func show_showcase(anim: StringName, frame_index: int, facing: int, positive: bool, ring_frame: int = -1) -> void:
	_showcase_mode = true
	set_physics_process(false)
	_external_force = Vector2.ZERO
	_external_force_pending = false
	_facing = 1 if facing >= 0 else -1
	_visual_root.scale = Vector2(float(_facing), 1.0)
	_positive = positive
	_apply_polarity_visuals()
	_state = anim
	_character_sprite.texture = _texture_for(anim)
	_character_sprite.hframes = _frame_count_for(anim)
	_character_sprite.frame = clampi(frame_index, 0, _frame_count_for(anim) - 1)
	_anim_time = float(_character_sprite.frame) / _fps_for(anim)
	_glow_time = 0.0
	_glow.frame = 2
	_ring_time = 0.0
	_switch_ring.visible = ring_frame >= 0
	if ring_frame >= 0:
		_switch_ring.frame = clampi(ring_frame, 0, 3)
	_update_effect_positions()
	state_changed.emit(_state, _character_sprite.frame, _frame_count_for(_state))
	polarity_changed.emit(_positive)


## Leaves the capture/showcase pose without moving or resetting the player.
## The level-01 opening uses one real walk frame as the "reach" pose at the
## stele, then returns to ordinary idle physics before the echo speaks.
func end_showcase() -> void:
	if not _showcase_mode:
		return
	_showcase_mode = false
	set_physics_process(true)
	velocity = Vector2.ZERO
	_apply_animation(STATE_IDLE, true)
	_update_effect_positions()


func get_state_name() -> String:
	return String(_state)


func get_anim_frame() -> int:
	return _character_sprite.frame


func get_anim_frame_count() -> int:
	return _frame_count_for(_state)


func get_frame_count_for(anim: StringName) -> int:
	return _frame_count_for(anim)


func get_facing() -> int:
	return _facing


func is_positive() -> bool:
	return _positive


func get_reset_count() -> int:
	return _reset_count


func get_anim_restart_count() -> int:
	return _anim_restart_count


func get_polarity_toggle_count() -> int:
	return _polarity_toggle_count


func get_talisman_texture() -> Texture2D:
	return _talisman.texture


func get_glow_texture() -> Texture2D:
	return _glow.texture


func get_glow_frame() -> int:
	return _glow.frame


func get_ring_texture() -> Texture2D:
	return _switch_ring.texture


func get_visual_root_scale() -> Vector2:
	return _visual_root.scale


func get_badge_global_position() -> Vector2:
	return _badge.global_position


func get_chest_anchor_frame() -> Vector2i:
	return _current_anchor()


func get_chest_anchor_global() -> Vector2:
	var center_local: Vector2 = _talisman.position + Vector2(2.5, 2.5)
	return _visual_root.to_global(center_local)


func get_talisman_global_position() -> Vector2:
	return _talisman.global_position


func get_glow_global_position() -> Vector2:
	var center_local: Vector2 = _glow.position + Vector2(5.5, 5.5)
	return _visual_root.to_global(center_local)


func get_ring_global_position() -> Vector2:
	var center_local: Vector2 = _switch_ring.position + Vector2(12.0, 12.0)
	return _visual_root.to_global(center_local)


func get_switch_ring_node_count() -> int:
	var count: int = 0
	for child: Node in _visual_root.get_children():
		if child.name == &"SwitchRing":
			count += 1
	return count


func is_ring_visible() -> bool:
	return _switch_ring.visible


func get_ring_frame() -> int:
	return _switch_ring.frame


func get_anchor_for(anim: StringName, frame_index: int) -> Vector2i:
	var anchors: Array[Vector2i] = _anchors_for(anim)
	var index: int = clampi(frame_index, 0, anchors.size() - 1)
	return anchors[index]


func get_anchor_table() -> Dictionary:
	return {
		"idle": IDLE_ANCHORS.duplicate(),
		"walk": WALK_ANCHORS.duplicate(),
		"run": RUN_ANCHORS.duplicate(),
		"jump": JUMP_ANCHORS.duplicate(),
		"fall": FALL_ANCHORS.duplicate(),
		"fall_loop": FALL_LOOP_ANCHORS.duplicate(),
	}


func get_collision_size() -> Vector2:
	var shape_node: CollisionShape2D = $CollisionShape2D
	var shape: RectangleShape2D = shape_node.shape as RectangleShape2D
	return shape.size


func get_hud_on_floor() -> bool:
	if _showcase_mode:
		return _state == STATE_IDLE or _state == STATE_WALK or _state == STATE_RUN
	return is_on_floor()


func get_visible_frame_size() -> Vector2i:
	return Vector2i(128, 128)


func get_walk_speed() -> float:
	return WALK_SPEED


func get_run_speed() -> float:
	return RUN_SPEED


func is_left_shift_held() -> bool:
	return _left_shift_held


func is_double_tap_run_locked() -> bool:
	return _double_tap_run_locked


func is_sprint_intent() -> bool:
	return _sprint_intent


func get_move_input_axis() -> float:
	return _move_input_axis


func get_target_speed() -> float:
	return _move_input_axis * (RUN_SPEED if _sprint_intent else WALK_SPEED)


func get_double_tap_timer() -> float:
	return _double_tap_timer
