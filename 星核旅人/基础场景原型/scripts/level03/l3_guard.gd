class_name L3Guard
extends Node2D

## Level-03 gate guard, revised after the first play-test.
##
## Teaching threshold:
##   - before the first teaching the guard only patrols and performs normal
##     forward slams; no field, no weakpoint, no true damage, no gravity action;
##   - the first invalid shell shatter leaves the authentic last rubble frame
##     waiting (no auto-rebuild, no attack, no force);
##   - only that real waiting rubble plus the player approaching the locked gate
##     may start the one-shot teaching; the cinematic then starts the real
##     rebuild and, immediately after it, shows the gravity charge.
##
## Combat rhythm after teaching / retry:
##   gravity charge -> normal slam -> normal slam -> gravity charge -> ...
##   Only completed normal slams count. A true hit interrupts and resets the
##   next action to a normal slam.
##
## J rule: opposite phase is effective for both ordinary shell damage and the
## gravity-charge weakpoint true damage. Same phase does no damage. The J
## snapshot (facing/phase), real forward melee, terrain ray, one resolution per
## swing id are unchanged.
##
## Gravity release: 360-degree damage around the body; once per release. Normal
## slam remains a forward fist zone. The attract field is wider (118 px) than
## the damage ring (92 px) and its force starts on frame 0 of the gravity charge.

signal charge_started(positive: bool)
signal slam_contact(facing: int)
signal gravity_release(positive: bool)
signal player_struck(facing: int)
signal true_damage_dealt(taken: int, remaining: int)
signal shattered
signal reassembly_started
signal reassembled
signal waiting_teaching_rubble
signal defeated
signal polarity_changed(positive: bool)

const FRAME_SIZE: Vector2i = Vector2i(90, 64)
const SPRITE_OFFSET: Vector2 = Vector2(-45.0, -64.0)
const SPRITE_SCALE: Vector2 = Vector2(2.0, 2.0)
const IDLE_FRAMES: int = 8
const IDLE_FPS: float = 8.0
const WALK_FRAMES: int = 10
const WALK_FPS: float = 10.0
const ATTACK_FRAMES: int = 11
const HURT_FRAMES: int = 4
const HURT_FPS: float = 12.0
const DIE_SHEET_FRAMES: int = 13
const DIE_LAST_CONTENT_FRAME: int = 11
const DIE_FPS: float = 16.0
const REASSEMBLE_FPS: float = 20.0
const REASSEMBLE_TIME: float = float(DIE_LAST_CONTENT_FRAME + 1) / REASSEMBLE_FPS
const SCATTER_TIME: float = float(DIE_LAST_CONTENT_FRAME + 1) / DIE_FPS
const HURT_TIME: float = float(HURT_FRAMES) / HURT_FPS
const DEATH_TIME: float = SCATTER_TIME
const DEATH_HOLD_TIME: float = 0.75

const MAX_TRUE_DAMAGE: int = 3
const SHELL_HITS_TO_BREAK: int = 2

const NORMAL_WINDUP_TIME: float = 0.50
const NORMAL_SLAM_TIME: float = 0.46
const NORMAL_STRIKE_TIME: float = 0.16
const GRAVITY_ENTRY_TIME: float = 0.20
const GRAVITY_LOOP_TIME: float = 1.10
const GRAVITY_CHARGE_TIME: float = GRAVITY_ENTRY_TIME + GRAVITY_LOOP_TIME
const GRAVITY_LOOP_FRAME_TIME: float = 0.15
const GRAVITY_RELEASE_TIME: float = 0.46
const RECOVER_TIME: float = 0.30
const GAP_TIME: float = 0.20
const POST_HURT_GAP: float = 0.30
const POST_REBUILD_GAP: float = 0.35

const ALERT_RANGE: float = 150.0
const ALERT_RELEASE_RANGE: float = 210.0
const ALERT_VERTICAL_TOLERANCE: float = 30.0
const NORMAL_TRIGGER_DISTANCE: float = 46.0
const GRAVITY_TRIGGER_DISTANCE: float = 100.0
const PATROL_SPEED: float = 40.0
const PURSUE_SPEED: float = 72.0
const STOP_DISTANCE: float = 34.0
const AI_STUCK_TIME: float = 0.6

const J_REACH: float = 36.0
const J_MIN_FORWARD: float = 2.0
const J_VERTICAL_TOLERANCE: float = 28.0

const STRIKE_FORWARD: float = 40.0
const STRIKE_SIZE: Vector2 = Vector2(34.0, 28.0)
const STRIKE_CENTER_Y: float = -12.0
const RING_DAMAGE_RADIUS: float = 92.0

const FIELD_RANGE: float = 118.0
const FIELD_INNER: float = 16.0
const FIELD_FULL: float = 42.0
const FIELD_OUTER_FADE: float = 24.0
const FIELD_ACCELERATION: float = 750.0

const WEAKPOINT_FRAMES: int = 64
const WEAKPOINT_FPS: float = 12.5
const WEAKPOINT_CENTER: Vector2 = Vector2(4.0, -34.0)

const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

const ORANGE_IDLE: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/orange/golem_1_idle.png")
const ORANGE_WALK: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/orange/golem_1_walk.png")
const ORANGE_ATTACK: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/orange/golem_1_attack.png")
const ORANGE_HURT: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/orange/golem_1_hurt.png")
const ORANGE_DIE: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/orange/golem_1_die.png")
const BLUE_IDLE: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/blue/golem_1_idle.png")
const BLUE_WALK: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/blue/golem_1_walk.png")
const BLUE_ATTACK: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/blue/golem_1_attack.png")
const BLUE_HURT: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/blue/golem_1_hurt.png")
const BLUE_DIE: Texture2D = preload("res://assets/experiments/polarity_golem/enemy/blue/golem_1_die.png")

const WEAKPOINT_GOLD: Texture2D = preload("res://assets/level03_prototype/weakpoint_gold_64f.png")
const WEAKPOINT_CYAN: Texture2D = preload("res://assets/level03_prototype/weakpoint_cyan_64f.png")
const FIELD_GOLD: Texture2D = preload("res://assets/level03_prototype/guard_field_gold_12f.png")
const FIELD_CYAN: Texture2D = preload("res://assets/level03_prototype/guard_field_cyan_12f.png")
const KEY_CORE_SHEET: Texture2D = preload("res://assets/level03_prototype/key_core_12f.png")

const ORANGE_COLOR: Color = Color("#ffa94d")
const BLUE_COLOR: Color = Color("#64c8ff")
const MUTED_COLOR: Color = Color("#9fb0b6")

enum State { ACTIVE, NORMAL_WINDUP, NORMAL_SLAM, GRAVITY_CHARGE, GRAVITY_RELEASE, RECOVER, HURT, SCATTERING, REASSEMBLING, WAIT_RUBBLE, DEAD }
enum NextAction { NORMAL, GRAVITY }

@export var start_positive: bool = true
@export var floor_y: float = 320.0
@export var patrol_left: float = 1850.0
@export var patrol_right: float = 2150.0
@export var pursuit_left: float = 1780.0
@export var pursuit_right: float = 2200.0

var _sprite: Sprite2D = null
var _weakpoint: Sprite2D = null
var _field: Sprite2D = null
var _key_core: Sprite2D = null
var _head: Node2D = null

var _state: State = State.ACTIVE
var _positive: bool = true
var _facing: int = -1
var _player_target: Node2D = null
var _suspended: bool = false
var _cinematic: bool = false
var _defeated: bool = false
var _teaching_seen: bool = false
var _first_shatter_done: bool = false
var _waiting_teaching_rubble: bool = false
var _teaching_rebuild: bool = false
var _next_action: NextAction = NextAction.NORMAL
var _normal_completed: int = 0

var _state_time: float = 0.0
var _action_elapsed: float = 0.0
var _recover_elapsed: float = 0.0
var _gap_remaining: float = 0.0
var _hurt_time: float = 0.0
var _hurt_next: String = ""
var _scatter_time: float = 0.0
var _reassemble_time: float = 0.0
var _death_time: float = 0.0
var _death_emitted: bool = false
var _idle_time: float = 0.0
var _walk_time: float = 0.0
var _patrol_direction: int = 1
var _ai_stuck_time: float = 0.0
var _hit_flash_time: float = 0.0
var _vulnerable: bool = false
var _weak_time: float = 0.0
var _strike_resolved: bool = false
var _ring_resolved: bool = false

var _true_marks_taken: int = 0
var _shell_hits: int = 0
var _pending_true_switch: bool = false
var _pending_death: bool = false
var _last_swing_id: int = -1
var _last_result: Dictionary = {}
var _last_strike_code: String = ""
var _enemy_slam_count: int = 0
var _enemy_ring_count: int = 0
var _enemy_hit_count: int = 0
var _head_bar_visible: bool = false
var _alert_time: float = 0.0
var _alert_shown: bool = false

static var _shared_font: FontFile = null
static var _font_checked: bool = false


## One world-anchored three-cell health bar. No state text, no explanation
## panel, no charge meter, no diamond stack: the action, the colour, the lit
## weakpoint and the real damage ring carry the warning.
class GuardHealthBar extends Node2D:
	const CELL_WIDTH: float = 14.0
	const CELL_HEIGHT: float = 5.0
	const CELL_GAP: float = 3.0
	const BAR_Y: float = -152.0
	const SCREEN_MARGIN: float = 42.0
	var host = null

	func _draw() -> void:
		if host == null or not is_instance_valid(host):
			return
		if not host.should_draw_health():
			return
		var cells: int = host.get_max_true_damage()
		var remaining: int = host.get_remaining_marks()
		var color: Color = host.get_polarity_color()
		var total: float = float(cells) * CELL_WIDTH + float(cells - 1) * CELL_GAP
		var min_center: float = SCREEN_MARGIN + total * 0.5
		var max_center: float = 640.0 - SCREEN_MARGIN - total * 0.5
		var camera: Camera2D = get_viewport().get_camera_2d()
		if camera != null:
			var view_center: float = camera.get_screen_center_position().x
			min_center += view_center - 320.0
			max_center += view_center - 320.0
		var center_x: float = clampf(host.global_position.x, min_center, maxf(min_center, max_center))
		var left: float = center_x - total * 0.5 - host.global_position.x
		for index: int in range(cells):
			var cell: Rect2 = Rect2(
				Vector2(left + float(index) * (CELL_WIDTH + CELL_GAP), BAR_Y),
				Vector2(CELL_WIDTH, CELL_HEIGHT)
			)
			draw_rect(cell, Color(0.015, 0.025, 0.03, 0.92))
			if index < remaining:
				draw_rect(cell.grow(-1.0), color)
			draw_rect(cell, Color(color.r, color.g, color.b, 0.75), false, 1.0)


func _ready() -> void:
	_positive = start_positive
	position.y = floor_y
	_build_visuals()
	_head = GuardHealthBar.new()
	_head.name = "GuardHealthBar"
	_head.z_index = 20
	_head.host = self
	add_child(_head)
	queue_redraw()


func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.centered = false
	_sprite.offset = SPRITE_OFFSET
	_sprite.scale = SPRITE_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.flip_h = _facing < 0
	add_child(_sprite)

	_field = Sprite2D.new()
	_field.name = "InwardField"
	_field.centered = true
	_field.position = Vector2(0.0, -30.0)
	_field.hframes = 12
	_field.vframes = 1
	_field.frame = 0
	_field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_field.z_index = -2
	_field.visible = false
	add_child(_field)

	_weakpoint = Sprite2D.new()
	_weakpoint.name = "Weakpoint"
	_weakpoint.centered = true
	_weakpoint.hframes = WEAKPOINT_FRAMES
	_weakpoint.vframes = 1
	_weakpoint.frame = 0
	_weakpoint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weakpoint.z_index = 2
	_weakpoint.visible = false
	add_child(_weakpoint)

	_key_core = Sprite2D.new()
	_key_core.name = "KeyCore"
	_key_core.centered = true
	_key_core.hframes = 12
	_key_core.vframes = 1
	_key_core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_key_core.z_index = 2
	add_child(_key_core)
	_apply_visual_palette()


func _apply_visual_palette() -> void:
	if _sprite != null:
		_sprite.flip_h = _facing < 0
	if _weakpoint != null:
		_weakpoint.texture = WEAKPOINT_GOLD if _positive else WEAKPOINT_CYAN
	if _field != null:
		_field.texture = FIELD_GOLD if _positive else FIELD_CYAN
	_update_anchor_positions()


func _update_anchor_positions() -> void:
	var chest: Vector2 = Vector2(WEAKPOINT_CENTER.x * float(_facing), WEAKPOINT_CENTER.y)
	if _weakpoint != null:
		_weakpoint.position = chest
	if _key_core != null:
		_key_core.position = chest
	if _field != null:
		_field.position = Vector2(0.0, WEAKPOINT_CENTER.y + 4.0)


func _physics_process(delta: float) -> void:
	if _suspended:
		return
	_state_time += delta
	_hit_flash_time = maxf(_hit_flash_time - delta, 0.0)
	_weak_time += delta
	if _key_core != null and _key_core.visible:
		_key_core.frame = int(_weak_time * 12.0) % 12
	match _state:
		State.ACTIVE:
			_advance_active(delta)
		State.NORMAL_WINDUP:
			_advance_normal_windup(delta)
		State.NORMAL_SLAM:
			_advance_normal_slam(delta)
		State.GRAVITY_CHARGE:
			_advance_gravity_charge(delta)
		State.GRAVITY_RELEASE:
			_advance_gravity_release(delta)
		State.RECOVER:
			_advance_recover(delta)
		State.HURT:
			_advance_hurt(delta)
		State.SCATTERING:
			_advance_scattering(delta)
		State.REASSEMBLING:
			_advance_reassembling(delta)
		State.WAIT_RUBBLE:
			pass
		State.DEAD:
			_advance_dead(delta)
	_update_flicker()
	queue_redraw()
	if _head != null:
		_head.queue_redraw()


func _advance_active(delta: float) -> void:
	_idle_time += delta
	_alert_time = maxf(_alert_time - delta, 0.0)
	if _cinematic:
		_set_idle_visual()
		return
	if _gap_remaining > 0.0:
		_gap_remaining = maxf(_gap_remaining - delta, 0.0)
		_set_idle_visual()
		return
	var player: Node2D = _player_target
	if player == null or not is_instance_valid(player):
		_patrol(delta)
		return
	if not _can_alert_player(ALERT_RANGE):
		_patrol(delta)
		return
	if not _alert_shown and _alert_time <= 0.0:
		_alert_shown = true
		_alert_time = 0.45
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 1.0:
		_set_facing(1 if dx > 0.0 else -1)
	var action_distance: float = GRAVITY_TRIGGER_DISTANCE if (
		_teaching_seen and _next_action == NextAction.GRAVITY
	) else NORMAL_TRIGGER_DISTANCE
	if absf(dx) <= action_distance:
		if _teaching_seen and _next_action == NextAction.GRAVITY:
			_begin_gravity()
		else:
			_begin_normal()
		return
	var before_x: float = global_position.x
	global_position.x = clampf(
		global_position.x + float(_facing) * PURSUE_SPEED * delta,
		pursuit_left, pursuit_right
	)
	if absf(global_position.x - before_x) < 0.05:
		_ai_stuck_time += delta
		if _ai_stuck_time >= AI_STUCK_TIME:
			_ai_stuck_time = 0.0
			_patrol(delta)
	else:
		_ai_stuck_time = 0.0
	_set_walk_visual(delta)


func _patrol(delta: float) -> void:
	if _cinematic:
		_set_idle_visual()
		return
	_ai_stuck_time = 0.0
	if global_position.x <= patrol_left + 1.0:
		_patrol_direction = 1
	elif global_position.x >= patrol_right - 1.0:
		_patrol_direction = -1
	_set_facing(_patrol_direction)
	global_position.x = clampf(
		global_position.x + float(_patrol_direction) * PATROL_SPEED * delta,
		patrol_left, patrol_right
	)
	_set_walk_visual(delta)


func _can_alert_player(range_px: float) -> bool:
	var player: Node2D = _player_target
	if player == null or not is_instance_valid(player):
		return false
	var player_x: float = player.global_position.x
	if player_x < pursuit_left - 18.0 or player_x > pursuit_right + 18.0:
		return false
	if absf(player_x - global_position.x) > range_px:
		return false
	if absf(player.global_position.y - floor_y) > ALERT_VERTICAL_TOLERANCE:
		return false
	return not _line_blocked(player.global_position + Vector2(0.0, -15.0), _chest_global(), player)


# --- normal attack (pre-teaching and post-teaching 2x rhythm) -------------

func _draw_alert_mark() -> void:
	if _alert_time <= 0.0:
		return
	var blink: bool = fmod(_alert_time, 0.15) < 0.09
	var col: Color = Color(1.0, 0.84, 0.36, 0.95 if blink else 0.55)
	var x: float = -1.0
	var top: float = -158.0
	draw_rect(Rect2(Vector2(x, top), Vector2(2.0, 6.0)), col)
	draw_rect(Rect2(Vector2(x, top + 8.0), Vector2(2.0, 2.0)), col)


func _begin_normal() -> void:
	_state = State.NORMAL_WINDUP
	_action_elapsed = 0.0
	_strike_resolved = false
	_vulnerable = false
	_field.visible = false
	_weakpoint.visible = false
	_set_attack_frame(0)


func _advance_normal_windup(delta: float) -> void:
	_action_elapsed += delta
	var t: float = clampf(_action_elapsed / NORMAL_WINDUP_TIME, 0.0, 0.999)
	_set_attack_frame(clampi(int(t * 4.0), 0, 3))
	if _action_elapsed >= NORMAL_WINDUP_TIME:
		_begin_normal_slam()


func _begin_normal_slam() -> void:
	_state = State.NORMAL_SLAM
	_action_elapsed = 0.0
	_strike_resolved = false
	_set_attack_frame(6)
	_resolve_normal_strike()
	slam_contact.emit(_facing)
	_enemy_slam_count += 1


func _advance_normal_slam(delta: float) -> void:
	_action_elapsed += delta
	var frame_index: int
	if _action_elapsed < 0.08:
		frame_index = 6
	elif _action_elapsed < NORMAL_STRIKE_TIME:
		frame_index = 7
	else:
		var recover_t: float = clampf(
			(_action_elapsed - NORMAL_STRIKE_TIME) / (NORMAL_SLAM_TIME - NORMAL_STRIKE_TIME),
			0.0, 0.999
		)
		frame_index = 8 + clampi(int(recover_t * 3.0), 0, 2)
	_set_attack_frame(frame_index)
	if _action_elapsed >= NORMAL_SLAM_TIME:
		_finish_normal()


func _finish_normal() -> void:
	_normal_completed += 1
	if _normal_completed >= 2:
		_normal_completed = 0
		_next_action = NextAction.GRAVITY
	else:
		_next_action = NextAction.NORMAL
	_state = State.RECOVER
	_recover_elapsed = 0.0
	_set_idle_visual()


func _resolve_normal_strike() -> void:
	_last_strike_code = "MISS"
	var player: Node2D = _player_target
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("is_hit_protected") and bool(player.call("is_hit_protected")):
		_last_strike_code = "PROTECTED"
		return
	if not _strike_zone_world().intersects(_player_body_rect(player)):
		return
	var accepted: bool = true
	if player.has_method("receive_enemy_strike"):
		accepted = bool(player.call("receive_enemy_strike", _facing))
	if not accepted:
		_last_strike_code = "PROTECTED"
		return
	_last_strike_code = "HIT"
	_enemy_hit_count += 1
	player_struck.emit(_facing)


func _strike_zone_world() -> Rect2:
	var center: Vector2 = global_position + Vector2(
		float(_facing) * STRIKE_FORWARD, STRIKE_CENTER_Y
	)
	return Rect2(center - STRIKE_SIZE * 0.5, STRIKE_SIZE)


func _player_body_rect(player: Node2D) -> Rect2:
	var shape_node: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = shape_node.shape as RectangleShape2D
		var center: Vector2 = player.global_position + shape_node.position
		return Rect2(center - rect_shape.size * 0.5, rect_shape.size)
	return Rect2(player.global_position + Vector2(-6.0, -30.0), Vector2(12.0, 30.0))


# --- gravity attack --------------------------------------------------------

func _begin_gravity() -> void:
	_state = State.GRAVITY_CHARGE
	_action_elapsed = 0.0
	_weak_time = 0.0
	_vulnerable = true
	_strike_resolved = false
	_ring_resolved = false
	var player: Node2D = _player_target
	if player != null and is_instance_valid(player):
		var dx: float = player.global_position.x - global_position.x
		if absf(dx) > 0.5:
			_set_facing(1 if dx > 0.0 else -1)
	_apply_visual_palette()
	_set_attack_frame(0)
	_weakpoint.visible = true
	_weakpoint.frame = 0
	_field.visible = true
	_field.frame = 0
	_field.modulate = Color.WHITE
	_head_bar_visible = true
	charge_started.emit(_positive)


func _advance_gravity_charge(delta: float) -> void:
	_action_elapsed += delta
	if _cinematic:
		_action_elapsed = minf(_action_elapsed, GRAVITY_ENTRY_TIME + 0.90)
	elif _action_elapsed >= GRAVITY_CHARGE_TIME:
		_begin_gravity_release()
		return
	var frame_index: int
	if _action_elapsed < GRAVITY_ENTRY_TIME:
		var entry_t: float = clampf(_action_elapsed / GRAVITY_ENTRY_TIME, 0.0, 0.999)
		frame_index = clampi(int(entry_t * 4.0), 0, 3)
	else:
		var loop_t: float = _action_elapsed - GRAVITY_ENTRY_TIME
		frame_index = 4 + (int(floor(loop_t / GRAVITY_LOOP_FRAME_TIME)) % 2)
	_set_attack_frame(frame_index)
	_vulnerable = true
	_weakpoint.visible = true
	_weakpoint.frame = int(_weak_time * WEAKPOINT_FPS) % WEAKPOINT_FRAMES
	_field.visible = true
	var progress: float = clampf(_action_elapsed / GRAVITY_CHARGE_TIME, 0.0, 1.0)
	_field.frame = clampi(int(progress * 12.0), 0, 11)
	_head_bar_visible = true
	_update_anchor_positions()


func _begin_gravity_release() -> void:
	_state = State.GRAVITY_RELEASE
	_action_elapsed = 0.0
	_vulnerable = false
	_weakpoint.visible = false
	_field.visible = false
	_head_bar_visible = false
	_set_attack_frame(6)
	_resolve_ring_release()
	_enemy_ring_count += 1
	gravity_release.emit(_positive)


func _advance_gravity_release(delta: float) -> void:
	_action_elapsed += delta
	var frame_index: int
	if _action_elapsed < 0.08:
		frame_index = 6
	elif _action_elapsed < 0.16:
		frame_index = 7
	else:
		var recover_t: float = clampf(
			(_action_elapsed - 0.16) / (GRAVITY_RELEASE_TIME - 0.16), 0.0, 0.999
		)
		frame_index = 8 + clampi(int(recover_t * 3.0), 0, 2)
	_set_attack_frame(frame_index)
	if _action_elapsed >= GRAVITY_RELEASE_TIME:
		_normal_completed = 0
		_next_action = NextAction.NORMAL
		_state = State.RECOVER
		_recover_elapsed = 0.0
		_set_idle_visual()


func _resolve_ring_release() -> void:
	_last_strike_code = "MISS"
	_ring_resolved = true
	var player: Node2D = _player_target
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("is_hit_protected") and bool(player.call("is_hit_protected")):
		_last_strike_code = "PROTECTED"
		return
	var guard_center: Vector2 = global_position + Vector2(0.0, -20.0)
	var player_center: Vector2 = player.global_position + Vector2(0.0, -15.0)
	if guard_center.distance_to(player_center) > RING_DAMAGE_RADIUS:
		return
	var accepted: bool = true
	if player.has_method("receive_enemy_strike"):
		accepted = bool(player.call("receive_enemy_strike", _facing))
	if not accepted:
		_last_strike_code = "PROTECTED"
		return
	_last_strike_code = "RING_HIT"
	_enemy_hit_count += 1
	player_struck.emit(_facing)


func _advance_recover(delta: float) -> void:
	_recover_elapsed += delta
	_idle_time += delta
	_set_idle_visual()
	if _recover_elapsed >= RECOVER_TIME:
		_state = State.ACTIVE
		_gap_remaining = GAP_TIME


# --- hit resolution --------------------------------------------------------

func receive_player_hit(
	player: Node2D,
	facing: int,
	snapshot_positive: bool,
	swing_id: int
) -> Dictionary:
	if swing_id == _last_swing_id:
		return _make_result("DUPLICATE_SWING", "same swing resolves once", MUTED_COLOR, false)
	_last_swing_id = swing_id
	if _suspended or _cinematic:
		return _make_result("INACTIVE", "cinematic: no resolution", MUTED_COLOR, false)
	if _state == State.SCATTERING or _state == State.REASSEMBLING or _state == State.WAIT_RUBBLE or _state == State.DEAD:
		return _make_result("INACTIVE", "rubble/reassembly/dead: no follow-up", MUTED_COLOR, false)
	if _state == State.HURT:
		return _make_result("INACTIVE", "reaction: no follow-up", MUTED_COLOR, false)
	if player == null or not is_instance_valid(player):
		return _make_result("NO_TARGET", "no target", MUTED_COLOR, false)
	var forward_gap: float = (global_position.x - player.global_position.x) * float(facing)
	if forward_gap <= J_MIN_FORWARD:
		return _make_result("MISS_BEHIND", "miss: behind the guard", MUTED_COLOR, false)
	if forward_gap > J_REACH:
		return _make_result("MISS_RANGE", "miss: out of reach", MUTED_COLOR, false)
	if absf(player.global_position.y - floor_y) > J_VERTICAL_TOLERANCE:
		return _make_result("MISS_RANGE", "miss: too much height", MUTED_COLOR, false)
	if _line_blocked(player.global_position + Vector2(0.0, -15.0), _chest_global(), player):
		return _make_result("BLOCKED", "miss: stone in the way", Color("#ff7f72"), false)
	if snapshot_positive == _positive:
		return _make_result("SAME_PHASE", "same starlight: no effect", MUTED_COLOR, false)
	if _state == State.GRAVITY_CHARGE or _state == State.GRAVITY_RELEASE:
		return _apply_gravity_break()
	return _apply_normal_break()


## Any effective hit outside the gravity attack shatters the shell once: the
## three-cell life is untouched and the guard visibly scatters, then rebuilds.
func _apply_normal_break() -> Dictionary:
	_hit_flash_time = 0.10
	_normal_completed = 0
	_next_action = NextAction.NORMAL
	_pending_true_switch = false
	_pending_death = false
	_begin_scatter()
	return _make_result("SHELL_SHATTER", "shell scattered: no life lost", MUTED_COLOR,
		true, false, get_remaining_marks())


## Effective hit inside the whole gravity attack (charge..release): one cell is
## lost, the shell visibly scatters, then it rebuilds. The first two rebuilds
## switch polarity; the third (zero cells) only scatters and drops the core.
func _apply_gravity_break() -> Dictionary:
	_true_marks_taken += 1
	_hit_flash_time = 0.16
	_normal_completed = 0
	_next_action = NextAction.NORMAL
	true_damage_dealt.emit(_true_marks_taken, get_remaining_marks())
	var lethal: bool = _true_marks_taken >= MAX_TRUE_DAMAGE
	_pending_death = lethal
	_pending_true_switch = not lethal
	_begin_scatter()
	if lethal:
		return _make_result("TRUE_KILL", "third cell gone: only scattering, one core",
			_guard_color(), true, true, 0)
	return _make_result("TRUE_HIT", "cell %d lost: scatter, rebuild, phase turns" % _true_marks_taken,
		_guard_color(), true, true, get_remaining_marks())


func _begin_hurt(next: String) -> void:
	_state = State.HURT
	_state_time = 0.0
	_hurt_time = 0.0
	_hurt_next = next
	_vulnerable = false
	_action_elapsed = 0.0
	_field.visible = false
	_weakpoint.visible = false
	_head_bar_visible = false
	_sprite.visible = true
	_sprite.texture = _hurt_texture()
	_sprite.hframes = HURT_FRAMES
	_sprite.vframes = 1
	_sprite.frame = 0


func _advance_hurt(delta: float) -> void:
	_hurt_time += delta
	_sprite.frame = mini(int(_hurt_time * HURT_FPS), HURT_FRAMES - 1)
	if _hurt_time < HURT_TIME:
		return
	if _hurt_next == "switch":
		_positive = not _positive
		_apply_visual_palette()
		polarity_changed.emit(_positive)
		_normal_completed = 0
		_next_action = NextAction.NORMAL
		_state = State.ACTIVE
		_gap_remaining = POST_HURT_GAP
		_set_idle_visual()
	elif _hurt_next == "deactivate":
		_begin_death()
	else:
		_state = State.ACTIVE
		_gap_remaining = 0.25
		_set_idle_visual()


# --- shell / rubble / rebuild ---------------------------------------------

func _begin_scatter() -> void:
	_state = State.SCATTERING
	_state_time = 0.0
	_scatter_time = 0.0
	_shell_hits = 0
	_vulnerable = false
	_field.visible = false
	_weakpoint.visible = false
	_head_bar_visible = false
	_key_core.visible = false
	_sprite.visible = true
	_sprite.texture = _die_texture()
	_sprite.hframes = DIE_SHEET_FRAMES
	_sprite.vframes = 1
	_sprite.frame = 0
	shattered.emit()


func _advance_scattering(delta: float) -> void:
	_scatter_time += delta
	_sprite.frame = mini(int(_scatter_time * DIE_FPS), DIE_LAST_CONTENT_FRAME)
	if _scatter_time < SCATTER_TIME:
		return
	if _pending_death:
		# The third cell only scatters: keep the rubble's last frame, never
		# restart the death sheet from frame 0.
		_begin_death(true)
		return
	if not _teaching_seen and not _first_shatter_done:
		_first_shatter_done = true
		_waiting_teaching_rubble = true
		_state = State.WAIT_RUBBLE
		_state_time = 0.0
		_sprite.frame = DIE_LAST_CONTENT_FRAME
		waiting_teaching_rubble.emit()
		return
	_begin_reassembly(false)


func _begin_reassembly(teaching_rebuild: bool) -> void:
	_state = State.REASSEMBLING
	_state_time = 0.0
	_reassemble_time = 0.0
	_teaching_rebuild = teaching_rebuild
	_waiting_teaching_rubble = false
	_sprite.visible = true
	_sprite.texture = _die_texture()
	_sprite.hframes = DIE_SHEET_FRAMES
	_sprite.vframes = 1
	_sprite.frame = DIE_LAST_CONTENT_FRAME
	reassembly_started.emit()


func _advance_reassembling(delta: float) -> void:
	_reassemble_time += delta
	var progress: float = clampf(_reassemble_time / REASSEMBLE_TIME, 0.0, 1.0)
	var frame_index: int = DIE_LAST_CONTENT_FRAME - int(progress * float(DIE_LAST_CONTENT_FRAME + 1))
	_sprite.frame = clampi(frame_index, 0, DIE_LAST_CONTENT_FRAME)
	if progress < 1.0:
		return
	_shell_hits = 0
	_key_core.visible = true
	_apply_visual_palette()
	reassembled.emit()
	if _teaching_rebuild:
		_teaching_rebuild = false
		_teaching_seen = true
		_first_shatter_done = true
		_waiting_teaching_rubble = false
		_normal_completed = 0
		_next_action = NextAction.GRAVITY
		if _cinematic:
			_begin_gravity()
		else:
			_begin_gravity()
		return
	if _pending_true_switch:
		_pending_true_switch = false
		_positive = not _positive
		_apply_visual_palette()
		polarity_changed.emit(_positive)
		_normal_completed = 0
		_next_action = NextAction.NORMAL
	_state = State.ACTIVE
	_gap_remaining = POST_REBUILD_GAP
	_idle_time = 0.0
	_set_idle_visual()
	if _cinematic:
		_begin_gravity()


func _advance_dead(delta: float) -> void:
	if _death_emitted:
		return
	_death_time += delta
	_sprite.frame = mini(int(_death_time * DIE_FPS), DIE_LAST_CONTENT_FRAME)
	if _death_time >= DEATH_HOLD_TIME:
		_sprite.frame = DIE_LAST_CONTENT_FRAME
		_death_emitted = true
		defeated.emit()


func _begin_death(keep_rubble_frame: bool = false) -> void:
	_state = State.DEAD
	_state_time = 0.0
	_death_time = DEATH_HOLD_TIME if keep_rubble_frame else 0.0
	_defeated = true
	_vulnerable = false
	_field.visible = false
	_weakpoint.visible = false
	_head_bar_visible = false
	_key_core.visible = false
	_sprite.visible = true
	_sprite.texture = _die_texture()
	_sprite.hframes = DIE_SHEET_FRAMES
	_sprite.vframes = 1
	_sprite.frame = DIE_LAST_CONTENT_FRAME if keep_rubble_frame else 0


func _return_to_active(gap: float) -> void:
	_state = State.ACTIVE
	_gap_remaining = gap
	_idle_time = 0.0
	_apply_visual_palette()
	_set_idle_visual()


# --- teaching / cinematic --------------------------------------------------

func set_cinematic_mode(value: bool) -> void:
	if _cinematic == value:
		return
	_cinematic = value
	if value:
		_field.visible = false
		_weakpoint.visible = false
		_head_bar_visible = false
		if _state == State.WAIT_RUBBLE:
			_begin_reassembly(true)
		elif (
			_state == State.ACTIVE or _state == State.NORMAL_WINDUP
			or _state == State.NORMAL_SLAM or _state == State.GRAVITY_CHARGE
			or _state == State.GRAVITY_RELEASE or _state == State.RECOVER
		):
			_state = State.ACTIVE
			_action_elapsed = 0.0
			_gap_remaining = 0.0
			_set_idle_visual()
	else:
		_vulnerable = false
		_field.visible = false
		_weakpoint.visible = false
		_head_bar_visible = false
		if _state == State.GRAVITY_CHARGE:
			_begin_gravity()
		elif _state == State.ACTIVE and _teaching_seen and not _defeated and not _suspended:
			_normal_completed = 0
			_next_action = NextAction.GRAVITY
			_begin_gravity()


func start_teaching_rebuild() -> void:
	if _state != State.WAIT_RUBBLE:
		return
	_begin_reassembly(true)


func force_gravity_first() -> void:
	if _defeated or _cinematic or _suspended:
		return
	if not _teaching_seen:
		return
	if _state != State.ACTIVE:
		return
	_normal_completed = 0
	_next_action = NextAction.GRAVITY
	_begin_gravity()


func set_player_target(player: Node2D) -> void:
	_player_target = player


func set_suspended(value: bool) -> void:
	_suspended = value
	if value:
		_field.visible = false
		_weakpoint.visible = false


func is_suspended() -> bool:
	return _suspended


func is_cinematic_mode() -> bool:
	return _cinematic


func reset_state(spawn: Vector2, positive: bool = true, keep_teaching: bool = false) -> void:
	_state = State.ACTIVE
	_state_time = 0.0
	_positive = positive
	_defeated = false
	_death_emitted = false
	_suspended = false
	_cinematic = false
	_vulnerable = false
	_teaching_seen = keep_teaching
	_first_shatter_done = keep_teaching
	_waiting_teaching_rubble = false
	_teaching_rebuild = false
	_pending_true_switch = false
	_pending_death = false
	_next_action = NextAction.GRAVITY if keep_teaching else NextAction.NORMAL
	_normal_completed = 0
	_true_marks_taken = 0
	_shell_hits = 0
	_last_swing_id = -1
	_last_result = {}
	_last_strike_code = ""
	_enemy_slam_count = 0
	_enemy_ring_count = 0
	_enemy_hit_count = 0
	_action_elapsed = 0.0
	_recover_elapsed = 0.0
	_gap_remaining = 0.0
	_hurt_time = 0.0
	_hurt_next = ""
	_scatter_time = 0.0
	_reassemble_time = 0.0
	_death_time = 0.0
	_idle_time = 0.0
	_walk_time = 0.0
	_hit_flash_time = 0.0
	_weak_time = 0.0
	_head_bar_visible = false
	_alert_time = 0.0
	_alert_shown = false
	global_position = spawn
	position.y = floor_y
	_facing = -1
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	_key_core.visible = true
	_field.visible = false
	_weakpoint.visible = false
	_apply_visual_palette()
	_set_idle_visual()
	if _head != null:
		_head.queue_redraw()
	queue_redraw()


func restore_waiting_rubble(spawn: Vector2) -> void:
	_state = State.WAIT_RUBBLE
	_state_time = 0.0
	_positive = true
	_defeated = false
	_death_emitted = false
	_suspended = false
	_cinematic = false
	_vulnerable = false
	_teaching_seen = false
	_first_shatter_done = true
	_waiting_teaching_rubble = true
	_teaching_rebuild = false
	_pending_true_switch = false
	_pending_death = false
	_next_action = NextAction.NORMAL
	_normal_completed = 0
	_true_marks_taken = 0
	_shell_hits = 0
	_field.visible = false
	_weakpoint.visible = false
	_head_bar_visible = false
	_key_core.visible = false
	_sprite.visible = true
	_sprite.texture = _die_texture()
	_sprite.hframes = DIE_SHEET_FRAMES
	_sprite.vframes = 1
	_sprite.frame = DIE_LAST_CONTENT_FRAME
	global_position = spawn
	position.y = floor_y
	_facing = -1
	queue_redraw()
	if _head != null:
		_head.queue_redraw()


func debug_force_death() -> void:
	_state = State.DEAD
	_state_time = 0.0
	_death_time = DEATH_HOLD_TIME
	_death_emitted = true
	_defeated = true
	_suspended = false
	_cinematic = false
	_vulnerable = false
	_field.visible = false
	_weakpoint.visible = false
	_key_core.visible = false
	_head_bar_visible = false
	_sprite.visible = true
	_sprite.texture = _die_texture()
	_sprite.hframes = DIE_SHEET_FRAMES
	_sprite.vframes = 1
	_sprite.frame = DIE_LAST_CONTENT_FRAME
	queue_redraw()
	if _head != null:
		_head.queue_redraw()


func debug_set_waiting_rubble() -> void:
	_begin_scatter()


func debug_force_gravity() -> void:
	if _defeated or _suspended:
		return
	_teaching_seen = true
	_begin_gravity()


# --- visuals --------------------------------------------------------------

func _set_facing(direction: int) -> void:
	var new_facing: int = 1 if direction >= 0 else -1
	if new_facing == _facing:
		return
	_facing = new_facing
	_sprite.flip_h = _facing < 0
	_update_anchor_positions()


func _set_idle_visual() -> void:
	_sprite.texture = _idle_texture()
	_sprite.hframes = IDLE_FRAMES
	_sprite.vframes = 1
	_sprite.frame = int(_idle_time * IDLE_FPS) % IDLE_FRAMES
	_sprite.flip_h = _facing < 0


func _set_walk_visual(delta: float) -> void:
	_walk_time += delta
	_sprite.texture = _walk_texture()
	_sprite.hframes = WALK_FRAMES
	_sprite.vframes = 1
	_sprite.frame = int(_walk_time * WALK_FPS) % WALK_FRAMES
	_sprite.flip_h = _facing < 0


func _set_attack_frame(frame_index: int) -> void:
	_sprite.texture = _attack_texture()
	_sprite.hframes = ATTACK_FRAMES
	_sprite.vframes = 1
	_sprite.frame = clampi(frame_index, 0, ATTACK_FRAMES - 1)
	_sprite.flip_h = _facing < 0


func _update_flicker() -> void:
	if _hit_flash_time > 0.0:
		_sprite.modulate = Color(1.0, 0.72, 0.62, 1.0)
	else:
		_sprite.modulate = Color.WHITE


# --- force / queries -------------------------------------------------------

func sample_player_force(
	player_center: Vector2,
	player_positive: bool,
	_excluded_rid: RID = RID()
) -> Dictionary:
	var result: Dictionary = {
		"acceleration": Vector2.ZERO,
		"status": "GUARD IDLE",
		"distance": 0.0,
		"blocked": false,
	}
	if _suspended or _cinematic or _state != State.GRAVITY_CHARGE:
		return result
	var center: Vector2 = _chest_global()
	var to_guard: Vector2 = center - player_center
	var distance: float = to_guard.length()
	if distance >= FIELD_RANGE:
		result["status"] = "GUARD OUT"
		return result
	if distance <= 0.5:
		result["status"] = "GUARD NEAR"
		return result
	if _line_blocked(player_center, center, _player_target):
		result["status"] = "GUARD BLOCKED"
		result["blocked"] = true
		return result
	var near_factor: float = smoothstep(FIELD_INNER, FIELD_FULL, distance)
	var outer_factor: float = 1.0 - smoothstep(FIELD_RANGE - FIELD_OUTER_FADE, FIELD_RANGE, distance)
	var strength: float = near_factor * outer_factor
	if strength <= 0.001:
		result["status"] = "GUARD NEAR"
		return result
	var direction: Vector2 = to_guard / distance
	var same: bool = player_positive == _positive
	if same:
		direction = -direction
	result["status"] = "GUARD REPEL" if same else "GUARD ATTRACT"
	result["acceleration"] = direction * FIELD_ACCELERATION * strength
	return result


func _line_blocked(from: Vector2, to: Vector2, player: Node2D = null) -> bool:
	if not is_inside_tree():
		return false
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclude: Array[RID] = []
	if player != null:
		exclude.append(player.get_rid())
	query.exclude = exclude
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()


func _make_result(
	code: String, message: String, color: Color, hit: bool,
	true_hit: bool = false, remaining: int = -1
) -> Dictionary:
	_last_result = {
		"code": code,
		"message": message,
		"color": color,
		"hit": hit,
		"true_damage": true_hit,
		"remaining_marks": remaining if remaining >= 0 else get_remaining_marks(),
		"state": get_state_name(),
		"vulnerable": _vulnerable,
		"position": global_position,
	}
	return _last_result


# --- textures / geometry ---------------------------------------------------

func _idle_texture() -> Texture2D:
	return ORANGE_IDLE if _positive else BLUE_IDLE


func _walk_texture() -> Texture2D:
	return ORANGE_WALK if _positive else BLUE_WALK


func _attack_texture() -> Texture2D:
	return ORANGE_ATTACK if _positive else BLUE_ATTACK


func _hurt_texture() -> Texture2D:
	return ORANGE_HURT if _positive else BLUE_HURT


func _die_texture() -> Texture2D:
	return ORANGE_DIE if _positive else BLUE_DIE


func _guard_color() -> Color:
	return ORANGE_COLOR if _positive else BLUE_COLOR


func _chest_global() -> Vector2:
	return global_position + Vector2(WEAKPOINT_CENTER.x * float(_facing), WEAKPOINT_CENTER.y)


# --- head / accessors ------------------------------------------------------

func get_head_font() -> Font:
	var font: Font = _get_font()
	if font == null:
		return ThemeDB.fallback_font
	return font


func should_draw_health() -> bool:
	if _defeated or _state == State.DEAD:
		return false
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		var center: Vector2 = camera.get_screen_center_position()
		if absf(global_position.x - center.x) > 370.0:
			return false
		if absf(global_position.y - center.y) > 220.0:
			return false
	return true


func get_head_text() -> String:
	# No state text: the bar is the only head readout.
	return ""


func get_charge_ratio() -> float:
	if _state == State.GRAVITY_CHARGE:
		return clampf(_action_elapsed / GRAVITY_CHARGE_TIME, 0.0, 1.0)
	return 0.0


func get_remaining_marks() -> int:
	return maxi(MAX_TRUE_DAMAGE - _true_marks_taken, 0)


func get_max_true_damage() -> int:
	return MAX_TRUE_DAMAGE


func get_true_marks_taken() -> int:
	return _true_marks_taken


func get_shell_hits() -> int:
	return _shell_hits


func is_vulnerable() -> bool:
	return _vulnerable and _state == State.GRAVITY_CHARGE and not _cinematic


func is_weakpoint_visible() -> bool:
	return _weakpoint != null and _weakpoint.visible


func is_field_visible() -> bool:
	return _field != null and _field.visible


func get_weakpoint_frame() -> int:
	return _weakpoint.frame if _weakpoint != null else -1


func get_field_frame() -> int:
	return _field.frame if _field != null else -1


func get_weakpoint_art_rect() -> Rect2:
	if _weakpoint == null:
		return Rect2()
	return Rect2(_weakpoint.global_position - Vector2(24.0, 24.0), Vector2(48.0, 48.0))


func get_chest_global_position() -> Vector2:
	return _chest_global()


func get_head_bar_rect() -> Rect2:
	# Three cells (14 px each, 3 px gaps) at y = -152.
	return Rect2(global_position.x - 24.0, global_position.y - 152.0, 48.0, 5.0)


func get_health_cells() -> int:
	return get_remaining_marks()


func get_max_health_cells() -> int:
	return MAX_TRUE_DAMAGE


func is_pending_death() -> bool:
	return _pending_death


func get_state_name() -> String:
	match _state:
		State.ACTIVE: return "ACTIVE"
		State.NORMAL_WINDUP: return "NORMAL_WINDUP"
		State.NORMAL_SLAM: return "NORMAL_SLAM"
		State.GRAVITY_CHARGE: return "GRAVITY_CHARGE"
		State.GRAVITY_RELEASE: return "GRAVITY_RELEASE"
		State.RECOVER: return "RECOVER"
		State.HURT: return "HURT"
		State.SCATTERING: return "SCATTERING"
		State.REASSEMBLING: return "REASSEMBLING"
		State.WAIT_RUBBLE: return "WAIT_RUBBLE"
		State.DEAD: return "DEAD"
		_: return "UNKNOWN"


func is_positive() -> bool:
	return _positive


func get_polarity_color() -> Color:
	return _guard_color()


func is_defeated() -> bool:
	return _defeated


func is_active() -> bool:
	return _state != State.DEAD and not _defeated


func is_scattered() -> bool:
	return _state == State.SCATTERING or _state == State.REASSEMBLING


func is_alert_mark_visible() -> bool:
	return _alert_time > 0.0


func is_waiting_teaching_rubble() -> bool:
	return _waiting_teaching_rubble and _state == State.WAIT_RUBBLE


func has_first_invalid_shatter() -> bool:
	return _first_shatter_done


func has_teaching_seen() -> bool:
	return _teaching_seen


func get_next_action_name() -> String:
	return "GRAVITY" if _next_action == NextAction.GRAVITY else "NORMAL"


func get_normal_completed() -> int:
	return _normal_completed


func get_action_elapsed() -> float:
	return _action_elapsed


func get_gravity_charge_time() -> float:
	return GRAVITY_CHARGE_TIME


func get_j_reach() -> float:
	return J_REACH


func get_ring_damage_radius() -> float:
	return RING_DAMAGE_RADIUS


func get_last_result() -> Dictionary:
	return _last_result


func get_last_strike_code() -> String:
	return _last_strike_code


func get_enemy_slam_count() -> int:
	return _enemy_slam_count


func get_enemy_ring_count() -> int:
	return _enemy_ring_count


func get_enemy_hit_count() -> int:
	return _enemy_hit_count


func get_key_core_drop_position() -> Vector2:
	return global_position + Vector2(0.0, -10.0)


func get_sprite_scale() -> Vector2:
	return _sprite.scale if _sprite != null else Vector2.ONE


func get_sprite_texture_path() -> String:
	return _sprite.texture.resource_path if _sprite != null and _sprite.texture != null else ""


func get_sprite_hframes() -> int:
	return _sprite.hframes if _sprite != null else 0


func get_sprite_frame() -> int:
	return _sprite.frame if _sprite != null else -1


func get_weakpoint_texture_path() -> String:
	return _weakpoint.texture.resource_path if _weakpoint != null and _weakpoint.texture != null else ""


func get_field_texture_path() -> String:
	return _field.texture.resource_path if _field != null and _field.texture != null else ""


func get_patrol_bounds() -> Vector2:
	return Vector2(patrol_left, patrol_right)


func get_field_tuning() -> Dictionary:
	return {
		"range": FIELD_RANGE,
		"inner": FIELD_INNER,
		"full": FIELD_FULL,
		"fade": FIELD_OUTER_FADE,
		"acceleration": FIELD_ACCELERATION,
		"ring_damage_radius": RING_DAMAGE_RADIUS,
		"gravity_entry": GRAVITY_ENTRY_TIME,
		"gravity_loop": GRAVITY_LOOP_TIME,
		"gravity_charge": GRAVITY_CHARGE_TIME,
		"normal_windup": NORMAL_WINDUP_TIME,
		"normal_slam": NORMAL_SLAM_TIME,
		"reach": J_REACH,
		"vertical": J_VERTICAL_TOLERANCE,
	}


func _draw() -> void:
	_draw_alert_mark()
	var color: Color = _guard_color()
	if _state == State.NORMAL_WINDUP:
		var warn_start: float = NORMAL_WINDUP_TIME - 0.30
		if _action_elapsed >= warn_start:
			var ratio: float = clampf((_action_elapsed - warn_start) / 0.30, 0.0, 1.0)
			_draw_forward_zone(Color(color.r, color.g, color.b, 0.10 + 0.20 * ratio))
	elif _state == State.NORMAL_SLAM and _action_elapsed < NORMAL_STRIKE_TIME:
		_draw_forward_zone(Color(color.r, color.g, color.b, 0.34))
	if _state == State.GRAVITY_CHARGE or _state == State.GRAVITY_RELEASE:
		_draw_ring_warning(color)


func _draw_forward_zone(zone_color: Color) -> void:
	var x0: float = minf(float(_facing) * 8.0, float(_facing) * (8.0 + STRIKE_SIZE.x))
	var rect: Rect2 = Rect2(Vector2(x0, -STRIKE_SIZE.y - 2.0), STRIKE_SIZE)
	draw_rect(rect, zone_color)
	draw_line(Vector2(rect.position.x, -1.0), Vector2(rect.end.x, -1.0), Color(zone_color, 0.85), 2.0)


func _draw_ring_warning(color: Color) -> void:
	var center: Vector2 = Vector2(0.0, -20.0)
	var alpha: float = 0.55
	if _state == State.GRAVITY_CHARGE:
		var progress: float = clampf(_action_elapsed / GRAVITY_CHARGE_TIME, 0.0, 1.0)
		alpha = 0.25 + 0.35 * progress
		draw_arc(center, FIELD_RANGE, 0.0, TAU, 96, Color(color.r, color.g, color.b, 0.14), 1.0)
	else:
		alpha = 0.85
	var segments: int = 48
	for index: int in range(segments):
		if index % 2 != 0:
			continue
		var a0: float = TAU * float(index) / float(segments)
		var a1: float = TAU * float(index + 1) / float(segments)
		draw_arc(center, RING_DAMAGE_RADIUS, a0, a1, 4, Color(color.r, color.g, color.b, alpha), 2.0)


static func _get_font() -> FontFile:
	if _font_checked:
		return _shared_font
	_font_checked = true
	if not ResourceLoader.exists(FONT_PATH):
		return null
	var base: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if base == null:
		return null
	var font: FontFile = base.duplicate() as FontFile
	if font != null:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.allow_system_fallback = false
		font.oversampling = 1.0
		_shared_font = font
	else:
		_shared_font = base
	return _shared_font
