extends CharacterBody2D

## Reusable polarity golem: the standalone experiment and the formal level-02
## bridge guard share this one script. Patrol/pursuit strips, floor_y and the
## head-label switch are authored per scene; leaving them unset keeps the old
## experiment floor values.
##
## Approved rules implemented here:
##   - one experimental golem, 3 HP, short bounded patrol + telegraphed slam;
##   - same-polarity swing: 1 damage + readable knockback;
##   - opposite-polarity swing: no damage, a short tether pull to a safe gap
##     (never through the player, never through terrain);
##   - HP 0 -> die frames -> the last non-empty die frame (index 11) is held
##     visible at the same spot for a configurable wait (default 8 s) ->
##     blink warning and reversed die frames -> full HP active;
##   - scattered / rubble / reassembling ignores all attacks and has no body
##     blocking the player;
##   - R resets position, polarity and HP to the experiment initial values.
##
## The golem is collision_layer 0, so it never pushes or blocks the player.
## Its mask 1 is used only by move_and_collide against the room terrain.

signal state_changed(state_name: String)
signal damaged(hp: int, max_hp: int)
signal scattered_at(position: Vector2)
signal reassembled
signal attack_started(facing: int)
signal attack_resolved(hit: bool)
signal player_struck(direction: int)

const FRAME_SIZE: Vector2i = Vector2i(90, 64)
const SPRITE_OFFSET: Vector2 = Vector2(-45.0, -64.0)
const IDLE_FRAMES: int = 8
const IDLE_FPS: float = 8.0
const HURT_FRAMES: int = 4
const HURT_FPS: float = 12.0
const DIE_SHEET_FRAMES: int = 13
const DIE_LAST_CONTENT_FRAME: int = 11
const DIE_FPS: float = 16.0
const REASSEMBLE_FPS: float = 20.0
const REASSEMBLE_TIME: float = float(DIE_LAST_CONTENT_FRAME + 1) / REASSEMBLE_FPS

## Approved combat tuning for this prototype, kept in one block.
const ATTACK_REACH: float = 52.0
const PULL_REACH: float = 130.0
const SAFE_DISTANCE: float = 46.0
const MIN_FORWARD_GAP: float = 4.0
const VERTICAL_TOLERANCE: float = 30.0
const MAX_HP: int = 3
const KNOCKBACK_SPEED: float = 260.0
const KNOCKBACK_FRICTION: float = 900.0
const KNOCKBACK_DAMAGE_SCALE: float = 0.6
const PULL_DURATION_MIN: float = 0.10
const PULL_DURATION_MAX: float = 0.24
const WORLD_LEFT: float = 28.0
const WORLD_RIGHT: float = 612.0
const FLOOR_Y: float = 288.0
const SCATTER_WAIT_DEFAULT: float = 8.0
const REASSEMBLE_WARNING_TIME: float = 1.0
const TETHER_TIME: float = 0.24

## --- Enemy AI / slam tuning (single place, experimental prototype) --------
## Bounded patrol strip. The golem never chases across the full room.
const PATROL_LEFT: float = 240.0
const PATROL_RIGHT: float = 520.0
## It may step slightly outside the patrol strip toward a nearby player, but
## never past the low wall (x=544) or the left guard edge.
const PURSUIT_LEFT: float = 200.0
const PURSUIT_RIGHT: float = 536.0
const PATROL_SPEED: float = 60.0
const PURSUE_SPEED: float = 100.0
const ALERT_RANGE: float = 120.0
const ALERT_RELEASE_RANGE: float = 148.0
const STOP_DISTANCE: float = 34.0
const ATTACK_TRIGGER_DISTANCE: float = 42.0
const ATTACK_VERTICAL_TOLERANCE: float = 34.0

## Real slam contact: the forward fist lands about 26 px ahead and just above
## the floor in attack sheet frame 6 (both arms fully down). This box only
## covers that fist, not the whole screen.
const STRIKE_ZONE_FORWARD: float = 26.0
const STRIKE_ZONE_CENTER_Y: float = -8.0
const STRIKE_ZONE_SIZE: Vector2 = Vector2(26.0, 20.0)

## 11-frame attack sheet remap:
##   frames 0..5  = arms raise / windup      0.28 s
##   frames 6..7  = fists down / live hit    0.12 s
##   frames 7..10 = recovery                 0.30 s
##   then 0.15 s short gap before the next decision.
## Detection only starts when frame 6 (fists actually down) is shown.
const ATTACK_FRAME_COUNT: int = 11
const ATTACK_WINDUP_FRAMES: int = 6
const ATTACK_STRIKE_FRAMES: int = 2
const ATTACK_WINDUP_TIME: float = 0.28
const ATTACK_STRIKE_TIME: float = 0.12
const ATTACK_RECOVER_TIME: float = 0.30
const ATTACK_GAP_TIME: float = 0.15
const ATTACK_TOTAL_TIME: float = ATTACK_WINDUP_TIME + ATTACK_STRIKE_TIME + ATTACK_RECOVER_TIME
const POST_REASSEMBLY_IDLE: float = 0.40
const AI_STUCK_TIME: float = 0.45
const WALK_FRAMES: int = 10
const WALK_FPS: float = 10.0

## Higher-z child that owns its own drawing. Keeping the draw code in this
## node (rather than calling the enemy's draw_rect) is required by Godot and
## also lets the HP bar/tag stay readable when the player overlaps the golem.
class HeadReadout extends Node2D:
	const FONT_SIZE: int = 12
	const SCREEN_MARGIN: float = 4.0
	const PANEL_TOP: float = -76.0
	const PANEL_HEIGHT: float = 16.0
	const TEXT_BASELINE: float = -63.0
	const BAR_TOP: float = -56.0
	const BAR_WIDTH: float = 42.0
	const BAR_HEIGHT: float = 6.0
	const PANEL_BG: Color = Color(0.015, 0.03, 0.036, 0.86)

	var host = null

	func _draw() -> void:
		if host == null or not is_instance_valid(host):
			return
		var font: Font = host.get_head_font()
		var tag: String = host.get_head_tag_text()
		var color: Color = host.get_polarity_text_color()
		var tag_color: Color = host.get_head_tag_color()
		var text_width: float = font.get_string_size(
			tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE
		).x
		var panel_width: float = maxf(text_width, BAR_WIDTH) + 6.0
		var min_center: float = SCREEN_MARGIN + panel_width * 0.5
		var max_center: float = 640.0 - SCREEN_MARGIN - panel_width * 0.5
		var center_x: float = clampf(
			host.global_position.x, min_center, maxf(min_center, max_center)
		)
		var local_center: float = center_x - host.global_position.x
		# The HP bar is always drawn. With the latest readability direction the
		# polarity word is normally empty and the phase is read from the body
		# colour; only the neutral scatter countdown still occupies a tag panel.
		if not tag.is_empty():
			var panel_rect: Rect2 = Rect2(
				local_center - panel_width * 0.5, PANEL_TOP, panel_width, PANEL_HEIGHT
			)
			draw_rect(panel_rect, PANEL_BG)
			draw_rect(panel_rect, Color(color.r, color.g, color.b, 0.55), false, 1.0)
			draw_string(
				font,
				Vector2(local_center - text_width * 0.5, TEXT_BASELINE),
				tag,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				FONT_SIZE,
				tag_color
			)

		var bar_x: float = local_center - BAR_WIDTH * 0.5
		var bar_rect: Rect2 = Rect2(bar_x, BAR_TOP, BAR_WIDTH, BAR_HEIGHT)
		draw_rect(bar_rect, PANEL_BG)
		draw_rect(bar_rect, Color(color.r, color.g, color.b, 0.9), false, 1.0)
		var hp: int = host.get_hp()
		var max_hp: int = host.get_max_hp()
		for index: int in range(max_hp):
			var pip: Rect2 = Rect2(
				bar_x + 2.0 + float(index) * 13.0, BAR_TOP + 1.5, 11.0, 3.0
			)
			if index < hp:
				draw_rect(pip, color)
			else:
				draw_rect(pip, Color(color.r, color.g, color.b, 0.18))

const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

const ORANGE_IDLE: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/orange/golem_1_idle.png"
)
const ORANGE_WALK: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/orange/golem_1_walk.png"
)
const ORANGE_ATTACK: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/orange/golem_1_attack.png"
)
const ORANGE_HURT: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/orange/golem_1_hurt.png"
)
const ORANGE_DIE: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/orange/golem_1_die.png"
)
const BLUE_IDLE: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/blue/golem_1_idle.png"
)
const BLUE_WALK: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/blue/golem_1_walk.png"
)
const BLUE_ATTACK: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/blue/golem_1_attack.png"
)
const BLUE_HURT: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/blue/golem_1_hurt.png"
)
const BLUE_DIE: Texture2D = preload(
	"res://assets/experiments/polarity_golem/enemy/blue/golem_1_die.png"
)

const ORANGE_COLOR: Color = Color("#ffa94d")
const BLUE_COLOR: Color = Color("#64c8ff")
const TEXT_COLOR: Color = Color("#eef3ef")
const MUTED_COLOR: Color = Color("#9fb0b6")
const BAR_BG: Color = Color(0.015, 0.03, 0.036, 0.92)
const WALL_HIT_COLOR: Color = Color("#ff7f72")

enum State {
	ACTIVE,
	HURT,
	SCATTERING,
	RUBBLE,
	REASSEMBLING,
}

enum AiPhase {
	PATROL,
	PURSUE,
	ATTACK,
	GAP,
}

@export var start_positive: bool = true
@export var scatter_wait_time: float = SCATTER_WAIT_DEFAULT
@export var world_left: float = WORLD_LEFT
@export var world_right: float = WORLD_RIGHT
@export var floor_y: float = FLOOR_Y

## Level-placed AI strip. The defaults are the independent experiment room's
## original 240..520 / 200..536 values, so loading that scene alone is
## unchanged; a formal level can author a narrower legal platform strip.
@export var patrol_left: float = PATROL_LEFT:
	set(value):
		patrol_left = value
		queue_redraw()
@export var patrol_right: float = PATROL_RIGHT:
	set(value):
		patrol_right = value
		queue_redraw()
@export var pursuit_left: float = PURSUIT_LEFT:
	set(value):
		pursuit_left = value
		queue_redraw()
@export var pursuit_right: float = PURSUIT_RIGHT:
	set(value):
		pursuit_right = value
		queue_redraw()

## Vertical gate for noticing / slam-triggering a player. A bridge guard sets a
## narrow value so a player 56 px below on the ground is never treated as a
## melee target through the deck.
@export var alert_vertical_tolerance: float = 80.0
@export var attack_vertical_tolerance: float = ATTACK_VERTICAL_TOLERANCE

## The head readout always keeps the 3-pip HP bar. The polarity word is off by
## default per the latest readability direction: the orange-gold / cyan-blue body
## itself carries the phase. The neutral scatter countdown still shows.
@export var show_polarity_label: bool = false:
	set(value):
		show_polarity_label = value
		if _head_overlay != null:
			_head_overlay.queue_redraw()

## When true, physics (AI, slam frame clock, pull, knockback, scatter wait) is
## frozen without changing the tree pause. Used by a level when the OS window
## loses focus or the completion page is showing.
var _ai_suspended: bool = false

@onready var _sprite: Sprite2D = $Sprite

var _state: State = State.ACTIVE
var _positive: bool = true
var _hp: int = MAX_HP
var _spawn_position: Vector2 = Vector2.ZERO
var _state_time: float = 0.0
var _idle_time: float = 0.0
var _scatter_wait_remaining: float = 0.0
var _knockback_velocity: float = 0.0
var _pull_active: bool = false
var _pull_elapsed: float = 0.0
var _pull_duration: float = 0.0
var _pull_start_x: float = 0.0
var _pull_target_x: float = 0.0
var _pull_facing: int = 1
var _pull_player = null
var _last_resolved_swing: int = -1
var _times_damaged: int = 0
var _pull_count: int = 0
var _knockback_count: int = 0
var _last_result: Dictionary = {}
var _last_move_blocked: bool = false
var _tether_timer: float = 0.0
var _tether_from: Vector2 = Vector2.ZERO
var _hit_flash_timer: float = 0.0
var _dust_timer: float = 0.0
var _dust_direction: int = 1
var _shape: CollisionShape2D = null
var _head_overlay: Node2D = null

## AI runtime. Patrol/pursue use walk frames; ATTACK remaps the 11-frame
## attack sheet to the approved timings; GAP is the small post-slam pause.
var _player_target = null
var _ai_phase: AiPhase = AiPhase.PATROL
var _ai_facing: int = 1
var _ai_time: float = 0.0
var _ai_stuck_time: float = 0.0
var _patrol_direction: int = 1
var _walk_time: float = 0.0
var _attack_elapsed: float = 0.0
var _attack_facing: int = 1
var _attack_hit_consumed: bool = true
var _enemy_hit_count: int = 0
var _last_strike_code: String = ""

static var _shared_font: FontFile = null
static var _font_checked: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_sprite.centered = false
	_sprite.offset = SPRITE_OFFSET
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hframes = IDLE_FRAMES
	_sprite.vframes = 1
	_spawn_position = global_position
	_positive = start_positive
	_reset_visual_to_idle()

	# The head tag/HP bar live on a higher-z child so an overlapping player
	# cannot hide the readability fix. Its text is clamped to the screen.
	var readout: HeadReadout = HeadReadout.new()
	readout.name = "HeadReadout"
	readout.z_index = 10
	readout.host = self
	_head_overlay = readout
	add_child(readout)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _ai_suspended:
		return
	_advance_effect_timers(delta)
	match _state:
		State.ACTIVE:
			_advance_active(delta)
		State.HURT:
			_advance_hurt(delta)
			_advance_knockback(delta)
		State.SCATTERING:
			_advance_scattering(delta)
			_advance_knockback(delta)
		State.RUBBLE:
			_advance_rubble(delta)
		State.REASSEMBLING:
			_advance_reassembling(delta)
	_update_flicker()
	queue_redraw()
	if _head_overlay != null:
		_head_overlay.queue_redraw()


## ACTIVE owns both combat resolution and the short AI loop. Pulls/knockback
## are advanced first so an enemy displaced by the player is never instantly
## erased by the next AI step; AI translation is skipped while a pull is live.
func _advance_active(delta: float) -> void:
	_advance_pull(delta)
	_advance_knockback(delta)
	match _ai_phase:
		AiPhase.PATROL:
			_advance_patrol(delta)
		AiPhase.PURSUE:
			_advance_pursue(delta)
		AiPhase.ATTACK:
			_advance_attack(delta)
		AiPhase.GAP:
			_advance_gap(delta)


func _advance_patrol(delta: float) -> void:
	_update_walk_visual(delta)
	if _pull_active:
		return
	if _can_alert_player(ALERT_RANGE):
		_enter_pursue()
		return
	if global_position.x <= patrol_left + 1.0:
		_patrol_direction = 1
	elif global_position.x >= patrol_right - 1.0:
		_patrol_direction = -1
	_set_facing(_patrol_direction)
	var step: float = float(_patrol_direction) * PATROL_SPEED * delta
	_last_move_blocked = false
	_move_enemy_x_bounded(step, patrol_left, patrol_right)
	if _last_move_blocked:
		_patrol_direction = -_patrol_direction


func _advance_pursue(delta: float) -> void:
	_update_walk_visual(delta)
	if _pull_active:
		return
	var player = _player_target
	if player == null or not is_instance_valid(player):
		_enter_patrol()
		return
	if not _can_alert_player(ALERT_RELEASE_RANGE):
		_enter_patrol()
		return

	var dx: float = player.global_position.x - global_position.x
	var distance: float = absf(dx)
	var vertical_gap: float = absf(player.global_position.y - floor_y)
	if distance > 1.0:
		_set_facing(1 if dx > 0.0 else -1)

	if (
		distance <= ATTACK_TRIGGER_DISTANCE
		and vertical_gap <= attack_vertical_tolerance
		and not _line_blocked_by_terrain(player)
	):
		_begin_attack()
		return
	if distance <= STOP_DISTANCE:
		return

	var direction: int = 1 if dx > 0.0 else -1
	var before_x: float = global_position.x
	_last_move_blocked = false
	_move_enemy_x_bounded(float(direction) * PURSUE_SPEED * delta, pursuit_left, pursuit_right)
	if _last_move_blocked or absf(global_position.x - before_x) < 0.05:
		_ai_stuck_time += delta
		if _ai_stuck_time >= AI_STUCK_TIME:
			_enter_patrol()
	else:
		_ai_stuck_time = 0.0


func _advance_attack(delta: float) -> void:
	# Facing is locked at attack start; the player can circle behind safely.
	_attack_elapsed += delta
	var frame_index: int = _attack_frame_for(_attack_elapsed)
	_apply_attack_frame(frame_index)
	if _is_strike_window() and not _attack_hit_consumed:
		_try_strike_hit()
	if _attack_elapsed >= ATTACK_TOTAL_TIME:
		_enter_gap(ATTACK_GAP_TIME)


func _advance_gap(delta: float) -> void:
	_advance_idle(delta)
	_ai_time = maxf(_ai_time - delta, 0.0)
	if _ai_time > 0.0:
		return
	var player = _player_target
	if player == null or not is_instance_valid(player) or not _can_alert_player(ALERT_RELEASE_RANGE):
		_enter_patrol()
		return
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 1.0:
		_set_facing(1 if dx > 0.0 else -1)
	if (
		absf(dx) <= ATTACK_TRIGGER_DISTANCE
		and absf(player.global_position.y - floor_y) <= attack_vertical_tolerance
		and not _line_blocked_by_terrain(player)
	):
		_begin_attack()
	else:
		_enter_pursue()


func _begin_attack() -> void:
	_ai_phase = AiPhase.ATTACK
	_attack_elapsed = 0.0
	_attack_hit_consumed = false
	_attack_facing = _ai_facing
	_apply_attack_frame(0)
	attack_started.emit(_attack_facing)


func _enter_gap(seconds: float) -> void:
	_ai_phase = AiPhase.GAP
	_ai_time = maxf(seconds, 0.0)
	_idle_time = 0.0
	_attack_hit_consumed = true
	_reset_visual_to_idle()


func _enter_patrol() -> void:
	_ai_phase = AiPhase.PATROL
	_ai_time = 0.0
	_ai_stuck_time = 0.0
	_attack_hit_consumed = true
	_attack_elapsed = 0.0
	var center: float = (patrol_left + patrol_right) * 0.5
	_patrol_direction = 1 if global_position.x <= center else -1


func _enter_pursue() -> void:
	_ai_phase = AiPhase.PURSUE
	_ai_time = 0.0
	_ai_stuck_time = 0.0


func _set_facing(direction: int) -> void:
	_ai_facing = 1 if direction >= 0 else -1
	_sprite.flip_h = _ai_facing < 0


func _update_walk_visual(delta: float) -> void:
	_walk_time += delta
	if _sprite.texture != _walk_texture() or _sprite.hframes != WALK_FRAMES:
		_sprite.texture = _walk_texture()
		_sprite.hframes = WALK_FRAMES
		_sprite.vframes = 1
	_sprite.frame = int(_walk_time * WALK_FPS) % WALK_FRAMES
	_sprite.flip_h = _ai_facing < 0


func _attack_frame_for(elapsed: float) -> int:
	if elapsed < ATTACK_WINDUP_TIME:
		var windup_t: float = clampf(elapsed / ATTACK_WINDUP_TIME, 0.0, 0.999)
		return clampi(int(windup_t * float(ATTACK_WINDUP_FRAMES)), 0, ATTACK_WINDUP_FRAMES - 1)
	var strike_elapsed: float = elapsed - ATTACK_WINDUP_TIME
	if strike_elapsed < ATTACK_STRIKE_TIME:
		var strike_t: float = clampf(strike_elapsed / ATTACK_STRIKE_TIME, 0.0, 0.999)
		return ATTACK_WINDUP_FRAMES + clampi(
			int(strike_t * float(ATTACK_STRIKE_FRAMES)), 0, ATTACK_STRIKE_FRAMES - 1
		)
	var recover_elapsed: float = strike_elapsed - ATTACK_STRIKE_TIME
	var recover_t: float = clampf(recover_elapsed / ATTACK_RECOVER_TIME, 0.0, 0.999)
	return 7 + clampi(int(recover_t * 4.0), 0, 3)


func _apply_attack_frame(frame_index: int) -> void:
	if _sprite.texture != _attack_texture() or _sprite.hframes != ATTACK_FRAME_COUNT:
		_sprite.texture = _attack_texture()
		_sprite.hframes = ATTACK_FRAME_COUNT
		_sprite.vframes = 1
	_sprite.frame = clampi(frame_index, 0, ATTACK_FRAME_COUNT - 1)
	_sprite.flip_h = _attack_facing < 0


func _is_strike_window() -> bool:
	return (
		_attack_elapsed >= ATTACK_WINDUP_TIME
		and _attack_elapsed < ATTACK_WINDUP_TIME + ATTACK_STRIKE_TIME
	)


## Exactly one accepted hit per slam. The live box is the forward fist's real
## landing area; the same strike cannot knock the player twice.
func _try_strike_hit() -> void:
	var player = _player_target
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("is_hit_protected") and player.is_hit_protected():
		_last_strike_code = "PROTECTED"
		return
	if _line_blocked_by_terrain(player):
		_last_strike_code = "BLOCKED"
		return
	if not _player_in_strike_zone(player):
		_last_strike_code = "MISS"
		return
	var accepted: bool = true
	if player.has_method("receive_enemy_strike"):
		accepted = bool(player.receive_enemy_strike(_attack_facing))
	if not accepted:
		_last_strike_code = "PROTECTED"
		return
	_attack_hit_consumed = true
	_enemy_hit_count += 1
	_last_strike_code = "HIT"
	_dust_timer = 0.22
	_dust_direction = _attack_facing
	player_struck.emit(_attack_facing)
	attack_resolved.emit(true)


func _player_in_strike_zone(player) -> bool:
	return _attack_zone_world().intersects(_player_body_rect(player))


func _attack_zone_world() -> Rect2:
	var center: Vector2 = global_position + Vector2(
		float(_attack_facing) * STRIKE_ZONE_FORWARD, STRIKE_ZONE_CENTER_Y
	)
	return Rect2(center - STRIKE_ZONE_SIZE * 0.5, STRIKE_ZONE_SIZE)


func _player_body_rect(player) -> Rect2:
	var shape_node: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = shape_node.shape as RectangleShape2D
		var center: Vector2 = player.global_position + shape_node.position
		return Rect2(center - rect_shape.size * 0.5, rect_shape.size)
	return Rect2(player.global_position + Vector2(-6.0, -30.0), Vector2(12.0, 30.0))


func _can_alert_player(range_px: float) -> bool:
	var player = _player_target
	if player == null or not is_instance_valid(player):
		return false
	var player_x: float = player.global_position.x
	if player_x < pursuit_left - 16.0 or player_x > pursuit_right + 16.0:
		return false
	if absf(player_x - global_position.x) > range_px:
		return false
	if absf(player.global_position.y - floor_y) > alert_vertical_tolerance:
		return false
	return not _line_blocked_by_terrain(player)


func _advance_idle(delta: float) -> void:
	_idle_time += delta
	_sprite.frame = int(_idle_time * IDLE_FPS) % IDLE_FRAMES


func _advance_hurt(delta: float) -> void:
	_state_time += delta
	_sprite.frame = mini(int(_state_time * HURT_FPS), HURT_FRAMES - 1)
	if _state_time >= float(HURT_FRAMES) / HURT_FPS:
		_enter_active()


func _advance_scattering(delta: float) -> void:
	_state_time += delta
	_sprite.frame = mini(int(_state_time * DIE_FPS), DIE_LAST_CONTENT_FRAME)
	if _state_time >= float(DIE_LAST_CONTENT_FRAME + 1) / DIE_FPS:
		_enter_rubble()


func _advance_rubble(delta: float) -> void:
	_state_time += delta
	_scatter_wait_remaining = maxf(_scatter_wait_remaining - delta, 0.0)
	if _scatter_wait_remaining <= 0.0:
		_enter_reassembling()


func _advance_reassembling(delta: float) -> void:
	_state_time += delta
	var progress: float = clampf(_state_time / REASSEMBLE_TIME, 0.0, 1.0)
	var frame_index: int = DIE_LAST_CONTENT_FRAME - int(progress * float(DIE_LAST_CONTENT_FRAME + 1))
	_sprite.frame = clampi(frame_index, 0, DIE_LAST_CONTENT_FRAME)
	if progress >= 1.0:
		_complete_reassembly()


func _advance_pull(delta: float) -> void:
	if not _pull_active:
		return
	_pull_elapsed += delta
	var t: float = clampf(_pull_elapsed / maxf(_pull_duration, 0.01), 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var desired_x: float = lerpf(_pull_start_x, _pull_target_x, eased)
	# If the player advances during the short pull, keep the golem on the safe
	# side instead of letting the two bodies overlap.
	if is_instance_valid(_pull_player):
		var player_x: float = _pull_player.global_position.x
		if _pull_facing > 0:
			desired_x = maxf(desired_x, player_x + SAFE_DISTANCE)
		else:
			desired_x = minf(desired_x, player_x - SAFE_DISTANCE)
	desired_x = clampf(desired_x, world_left, world_right)
	_last_move_blocked = false
	_move_enemy_x(desired_x - global_position.x)
	if t >= 1.0 or _last_move_blocked:
		_pull_active = false
		_pull_player = null


func _advance_knockback(delta: float) -> void:
	if absf(_knockback_velocity) < 1.0:
		_knockback_velocity = 0.0
		return
	var step: float = _knockback_velocity * delta
	_last_move_blocked = false
	_move_enemy_x(step)
	_knockback_velocity = move_toward(_knockback_velocity, 0.0, KNOCKBACK_FRICTION * delta)
	if _last_move_blocked:
		_knockback_velocity = 0.0


func _advance_effect_timers(delta: float) -> void:
	_tether_timer = maxf(_tether_timer - delta, 0.0)
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	_dust_timer = maxf(_dust_timer - delta, 0.0)


func _update_flicker() -> void:
	if _state == State.RUBBLE:
		if _scatter_wait_remaining <= REASSEMBLE_WARNING_TIME:
			var blink_on: bool = fmod(_state_time, 0.20) < 0.11
			modulate = Color(1.0, 1.0, 1.0, 1.0 if blink_on else 0.28)
		else:
			modulate = Color.WHITE
	elif _state == State.REASSEMBLING:
		var blink_on: bool = fmod(_state_time, 0.14) < 0.09
		modulate = Color(1.0, 1.0, 1.0, 1.0 if blink_on else 0.30)
	else:
		modulate = (
			Color(1.0, 0.74, 0.64, 1.0) if _hit_flash_timer > 0.0 else Color.WHITE
		)


## Resolves one swing against this golem. Called exactly once per swing by the
## experiment root at the attack hit window. Same swing id can never resolve
## twice, even if the caller repeats it.
func receive_attack(
	player: PrototypePlayer,
	facing: int,
	positive: bool,
	swing_id: int
) -> Dictionary:
	if swing_id == _last_resolved_swing:
		return _make_result("DUPLICATE_SWING", "本挥击已结算", MUTED_COLOR)
	_last_resolved_swing = swing_id

	if _state == State.SCATTERING or _state == State.RUBBLE or _state == State.REASSEMBLING:
		return _make_result("INACTIVE", "重组中：不受攻击", MUTED_COLOR)
	if player == null:
		return _make_result("NO_TARGET", "没有目标", MUTED_COLOR)

	var forward_gap: float = (global_position.x - player.global_position.x) * float(facing)
	if forward_gap <= MIN_FORWARD_GAP:
		return _make_result("MISS_BEHIND", "未命中：目标在身后", MUTED_COLOR)
	if absf(global_position.y - player.global_position.y) > VERTICAL_TOLERANCE:
		return _make_result("MISS_RANGE", "未命中：垂直错位", MUTED_COLOR)

	var same_polarity: bool = positive == _positive
	var reach: float = ATTACK_REACH if same_polarity else PULL_REACH
	if forward_gap > reach:
		return _make_result("MISS_RANGE", "未命中：超出范围", MUTED_COLOR)

	if _line_blocked_by_terrain(player):
		return _make_result("BLOCKED", "未命中：实体墙阻挡", WALL_HIT_COLOR)

	if same_polarity:
		return _apply_same_phase_hit(facing, player)
	return _apply_opposite_phase_pull(player, facing)


func _apply_same_phase_hit(facing: int, player: PrototypePlayer) -> Dictionary:
	_pull_active = false
	_pull_player = null
	_hp = maxi(_hp - 1, 0)
	_times_damaged += 1
	_knockback_velocity = float(facing) * KNOCKBACK_SPEED
	_knockback_count += 1
	_dust_timer = 0.28
	_dust_direction = -facing
	_hit_flash_timer = 0.16
	damaged.emit(_hp, MAX_HP)

	if _hp <= 0:
		_begin_scatter()
		_knockback_velocity = float(facing) * KNOCKBACK_SPEED * KNOCKBACK_DAMAGE_SCALE
		return _make_result("HIT_SCATTER", "同相击散：HP 0/%d" % MAX_HP, ORANGE_COLOR if _positive else BLUE_COLOR, true, 1, false, _hp)

	_begin_hurt()
	return _make_result("HIT", "同相命中：-1 HP / 击退", ORANGE_COLOR if _positive else BLUE_COLOR, true, 1, false, _hp)


func _apply_opposite_phase_pull(player: PrototypePlayer, facing: int) -> Dictionary:
	var forward_gap: float = (global_position.x - player.global_position.x) * float(facing)
	if forward_gap <= SAFE_DISTANCE + 2.0:
		return _make_result("PULL_ALREADY_CLOSE", "异相牵引：无伤害，已在安全距离", MUTED_COLOR, false, 0, false, _hp)

	var target_x: float = player.global_position.x + float(facing) * SAFE_DISTANCE
	_pull_start_x = global_position.x
	_pull_target_x = clampf(target_x, world_left, world_right)
	_pull_elapsed = 0.0
	_pull_duration = clampf(absf(_pull_target_x - _pull_start_x) / 420.0, PULL_DURATION_MIN, PULL_DURATION_MAX)
	_pull_facing = facing
	_pull_player = player
	_pull_active = true
	_pull_count += 1
	_tether_timer = TETHER_TIME
	_tether_from = player.global_position + Vector2(0.0, -18.0)
	return _make_result("PULL", "异相牵引：无伤害，拉近到安全距离", BLUE_COLOR if _positive else ORANGE_COLOR, false, 0, true, _hp)


func _line_blocked_by_terrain(player: PrototypePlayer) -> bool:
	var from: Vector2 = player.global_position + Vector2(0.0, -18.0)
	var to: Vector2 = global_position + Vector2(0.0, -19.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		from, to, 1, [player.get_rid()]
	)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func _move_enemy_x(dx: float) -> void:
	_move_enemy_x_bounded(dx, world_left, world_right)


## Moves inside an optional AI strip. If the golem was displaced outside the
## strip (pull/knockback), it may walk back in without snapping to the edge.
func _move_enemy_x_bounded(dx: float, min_x: float, max_x: float) -> void:
	if absf(dx) < 0.001:
		return
	var lo: float = maxf(world_left, min_x)
	var hi: float = minf(world_right, maxf(min_x, max_x))
	if global_position.x <= lo and dx < 0.0:
		_last_move_blocked = true
		return
	if global_position.x >= hi and dx > 0.0:
		_last_move_blocked = true
		return
	var target_x: float = global_position.x + dx
	if global_position.x >= lo and global_position.x <= hi:
		target_x = clampf(target_x, lo, hi)
	var delta_x: float = target_x - global_position.x
	if absf(delta_x) < 0.001:
		_last_move_blocked = true
		return
	var collision: KinematicCollision2D = move_and_collide(Vector2(delta_x, 0.0))
	global_position.x = clampf(global_position.x, world_left, world_right)
	if collision != null:
		_last_move_blocked = true


func _begin_hurt() -> void:
	# A same-polarity hit cancels this slam immediately. No stale strike timer
	# can resolve after the visible attack was interrupted.
	_cancel_slam()
	_state = State.HURT
	_state_time = 0.0
	_sprite.visible = true
	_sprite.texture = _hurt_texture()
	_sprite.hframes = HURT_FRAMES
	_sprite.frame = 0
	state_changed.emit(get_state_name())


func _begin_scatter() -> void:
	_cancel_slam()
	_state = State.SCATTERING
	_state_time = 0.0
	_pull_active = false
	_tether_timer = 0.0
	_sprite.visible = true
	_sprite.texture = _die_texture()
	_sprite.hframes = DIE_SHEET_FRAMES
	_sprite.frame = 0
	state_changed.emit(get_state_name())
	scattered_at.emit(global_position)


func _cancel_slam() -> void:
	_ai_phase = AiPhase.GAP
	_ai_time = 0.0
	_attack_elapsed = 0.0
	_attack_hit_consumed = true
	_ai_stuck_time = 0.0


func _enter_rubble() -> void:
	_state = State.RUBBLE
	_state_time = 0.0
	_scatter_wait_remaining = maxf(scatter_wait_time, 0.0)
	_knockback_velocity = 0.0
	_pull_active = false
	# Hold the authentic last non-empty die frame (sheet index 11). Index 12 is
	# empty on the source strip, so it must never be shown. No custom rubble is
	# drawn; this visible frame is the whole "scattered" readout.
	_sprite.visible = true
	_sprite.texture = _die_texture()
	_sprite.hframes = DIE_SHEET_FRAMES
	_sprite.vframes = 1
	_sprite.frame = DIE_LAST_CONTENT_FRAME
	collision_mask = 0
	if _shape != null:
		_shape.disabled = true
	state_changed.emit(get_state_name())
	if _head_overlay != null:
		_head_overlay.queue_redraw()


func _enter_reassembling() -> void:
	_state = State.REASSEMBLING
	_state_time = 0.0
	_sprite.visible = true
	_sprite.texture = _die_texture()
	_sprite.hframes = DIE_SHEET_FRAMES
	_sprite.frame = DIE_LAST_CONTENT_FRAME
	state_changed.emit(get_state_name())


func _complete_reassembly() -> void:
	global_position.x = clampf(global_position.x, world_left, world_right)
	global_position.y = floor_y
	_hp = MAX_HP
	_knockback_velocity = 0.0
	_pull_active = false
	collision_mask = 1
	if _shape != null:
		_shape.disabled = false
	_enter_active()
	# Revive is never a zero-warning hit: one short idle beat before the AI can
	# even decide to pursue, then the normal 0.28 s arm raise.
	_enter_gap(POST_REASSEMBLY_IDLE)
	reassembled.emit()


func _enter_active() -> void:
	_state = State.ACTIVE
	_state_time = 0.0
	_idle_time = 0.0
	_ai_phase = AiPhase.PATROL
	_ai_time = 0.0
	_ai_stuck_time = 0.0
	_attack_elapsed = 0.0
	_attack_hit_consumed = true
	_walk_time = 0.0
	_sprite.visible = true
	_reset_visual_to_idle()
	state_changed.emit(get_state_name())


func _reset_visual_to_idle() -> void:
	_sprite.texture = _idle_texture()
	_sprite.hframes = IDLE_FRAMES
	_sprite.vframes = 1
	_sprite.frame = 0
	_sprite.flip_h = _ai_facing < 0


func _make_result(
	code: String,
	message: String,
	color: Color,
	hit: bool = false,
	damage: int = 0,
	pulled: bool = false,
	hp: int = -1
) -> Dictionary:
	_last_result = {
		"code": code,
		"message": message,
		"color": color,
		"hit": hit,
		"damage": damage,
		"pulled": pulled,
		"hp": _hp if hp < 0 else hp,
		"state": get_state_name(),
		"position": global_position,
	}
	return _last_result


func _set_polarity_internal(positive: bool) -> void:
	_positive = positive
	if _state == State.HURT:
		_sprite.texture = _hurt_texture()
	elif _state == State.SCATTERING or _state == State.REASSEMBLING:
		_sprite.texture = _die_texture()
	elif _state == State.ACTIVE and _ai_phase == AiPhase.ATTACK:
		# Tab must not hide an in-progress slam behind an idle frame.
		_apply_attack_frame(_attack_frame_for(_attack_elapsed))
	else:
		_reset_visual_to_idle()
	queue_redraw()


## Tab entry from the experiment root. Polarity is intentionally locked while
## scattered/rubble/reassembling so the golem keeps its polarity through the
## rebuild, as approved.
func set_polarity_positive(positive: bool) -> bool:
	if _state != State.ACTIVE and _state != State.HURT:
		return false
	_set_polarity_internal(positive)
	return true


func toggle_polarity() -> bool:
	return set_polarity_positive(not _positive)


func reset_experiment_state(spawn: Vector2, positive: bool) -> void:
	_spawn_position = spawn
	global_position = spawn
	global_position.y = floor_y
	velocity = Vector2.ZERO
	_positive = positive
	_hp = MAX_HP
	_state = State.ACTIVE
	_state_time = 0.0
	_idle_time = 0.0
	_scatter_wait_remaining = 0.0
	_knockback_velocity = 0.0
	_pull_active = false
	_pull_player = null
	_last_resolved_swing = -1
	_times_damaged = 0
	_pull_count = 0
	_knockback_count = 0
	_last_result = {}
	_last_move_blocked = false
	_tether_timer = 0.0
	_hit_flash_timer = 0.0
	_dust_timer = 0.0
	_ai_phase = AiPhase.PATROL
	_ai_facing = 1
	_ai_time = 0.0
	_ai_stuck_time = 0.0
	_patrol_direction = 1
	_walk_time = 0.0
	_attack_elapsed = 0.0
	_attack_facing = 1
	_attack_hit_consumed = true
	_enemy_hit_count = 0
	_last_strike_code = ""
	_ai_suspended = false
	modulate = Color.WHITE
	_sprite.visible = true
	collision_mask = 1
	if _shape != null:
		_shape.disabled = false
	_reset_visual_to_idle()
	state_changed.emit(get_state_name())
	queue_redraw()
	if _head_overlay != null:
		_head_overlay.queue_redraw()


func set_scatter_wait_time(seconds: float) -> void:
	scatter_wait_time = maxf(seconds, 0.05)
	if _state == State.RUBBLE:
		_scatter_wait_remaining = minf(_scatter_wait_remaining, scatter_wait_time)


func set_player_target(player) -> void:
	_player_target = player


## Freezes/restores AI and every effect timer without touching the tree pause.
## A level uses this on OS focus loss and while the completion page is up.
func set_ai_suspended(value: bool) -> void:
	_ai_suspended = value


func is_ai_suspended() -> bool:
	return _ai_suspended


## Completion is final for this attempt: stop any live slam immediately and
## freeze the guard. The next R reset re-enables it through reset_experiment_state.
func freeze_for_completion() -> void:
	_cancel_slam()
	_attack_hit_consumed = true
	_pull_active = false
	_pull_player = null
	_knockback_velocity = 0.0
	_ai_suspended = true


func cancel_active_attack() -> void:
	_cancel_slam()
	_attack_hit_consumed = true
	if _state == State.ACTIVE:
		_reset_visual_to_idle()


## TEST SETUP ONLY (production AI is unchanged): starts a slam immediately so
## a local mechanic such as terrain blocking can be checked without waiting for
## the patrol/pursue entry. It never touches HP, polarity or world bounds.
func debug_begin_attack(facing: int = 1) -> void:
	if _state != State.ACTIVE:
		return
	_set_facing(facing)
	_begin_attack()


## TEST SETUP ONLY: lets the smoke test reach the kill/scatter flow without
## three timed swings. It never changes the production default (3 HP); the
## normal receive_attack path still removes the final hit point.
func debug_set_hp(value: int) -> void:
	_hp = clampi(value, 0, MAX_HP)
	damaged.emit(_hp, MAX_HP)


func get_state_name() -> String:
	match _state:
		State.ACTIVE:
			return "ACTIVE"
		State.HURT:
			return "HURT"
		State.SCATTERING:
			return "SCATTERING"
		State.RUBBLE:
			return "RUBBLE"
		State.REASSEMBLING:
			return "REASSEMBLING"
		_:
			return "UNKNOWN"


func get_ai_phase_name() -> String:
	if _state != State.ACTIVE:
		return get_state_name()
	match _ai_phase:
		AiPhase.PATROL:
			return "PATROL"
		AiPhase.PURSUE:
			return "PURSUE"
		AiPhase.ATTACK:
			return "ATTACK"
		AiPhase.GAP:
			return "GAP"
		_:
			return "PATROL"


func get_ai_phase_label() -> String:
	if _state == State.HURT:
		return "受击"
	if _state != State.ACTIVE:
		return "非活动"
	match _ai_phase:
		AiPhase.PATROL:
			return "巡逻"
		AiPhase.PURSUE:
			return "接近"
		AiPhase.ATTACK:
			if _attack_elapsed < ATTACK_WINDUP_TIME:
				return "举臂预警"
			if _attack_elapsed < ATTACK_WINDUP_TIME + ATTACK_STRIKE_TIME:
				return "砸击"
			return "收招"
		AiPhase.GAP:
			return "间隔"
		_:
			return "巡逻"


func get_hp() -> int:
	return _hp


func get_max_hp() -> int:
	return MAX_HP


func is_positive() -> bool:
	return _positive


func get_polarity_label() -> String:
	if _positive:
		return "辉相 +"
	return "澜相 -"


func get_polarity_text_color() -> Color:
	return ORANGE_COLOR if _positive else BLUE_COLOR


func get_head_tag_color() -> Color:
	if _state == State.RUBBLE or _state == State.REASSEMBLING:
		return TEXT_COLOR
	return get_polarity_text_color()


func get_head_font() -> Font:
	var font: Font = _get_font()
	if font == null:
		return ThemeDB.fallback_font
	return font


func get_spawn_position() -> Vector2:
	return _spawn_position


func get_scatter_wait_remaining() -> float:
	return _scatter_wait_remaining


func is_scattered() -> bool:
	return _state == State.SCATTERING or _state == State.RUBBLE or _state == State.REASSEMBLING


func is_attackable() -> bool:
	return _state == State.ACTIVE or _state == State.HURT


func get_last_result() -> Dictionary:
	return _last_result


func get_times_damaged() -> int:
	return _times_damaged


func get_pull_count() -> int:
	return _pull_count


func get_knockback_count() -> int:
	return _knockback_count


func get_scatter_wait_setting() -> float:
	return scatter_wait_time


func get_sprite_frame_count() -> int:
	return _sprite.hframes


func get_sprite_frame() -> int:
	return _sprite.frame


func get_sprite_visible() -> bool:
	return _sprite.visible


func get_head_tag_text() -> String:
	if _state == State.RUBBLE:
		return "%.1f秒后重组" % maxf(_scatter_wait_remaining, 0.0)
	if _state == State.REASSEMBLING:
		return "重组中"
	if not show_polarity_label:
		return ""
	return get_polarity_label()


func is_polarity_label_visible() -> bool:
	return show_polarity_label and not get_head_tag_text().is_empty()


func get_head_overlay_z_index() -> int:
	return _head_overlay.z_index if _head_overlay != null else 0


## The 3-pip bar rectangle in world space for layout assertions. On the bridge
## the guard is far from either screen edge, so no clamp is involved.
func get_head_bar_rect() -> Rect2:
	return Rect2(
		global_position.x - 21.0,
		global_position.y - 56.0,
		42.0,
		6.0
	)


func get_sprite_texture_path() -> String:
	return _sprite.texture.resource_path if _sprite.texture != null else ""


func get_body_collision_layer() -> int:
	return collision_layer


func get_world_bounds() -> Vector2:
	return Vector2(world_left, world_right)


func get_patrol_bounds() -> Vector2:
	return Vector2(patrol_left, patrol_right)


func get_pursuit_bounds() -> Vector2:
	return Vector2(pursuit_left, pursuit_right)


func get_ai_tuning() -> Dictionary:
	return {
		"patrol_left": patrol_left,
		"patrol_right": patrol_right,
		"pursuit_left": pursuit_left,
		"pursuit_right": pursuit_right,
		"alert_vertical_tolerance": alert_vertical_tolerance,
		"attack_vertical_tolerance": attack_vertical_tolerance,
		"patrol_speed": PATROL_SPEED,
		"pursue_speed": PURSUE_SPEED,
		"alert_range": ALERT_RANGE,
		"alert_release_range": ALERT_RELEASE_RANGE,
		"stop_distance": STOP_DISTANCE,
		"attack_trigger_distance": ATTACK_TRIGGER_DISTANCE,
		"windup_time": ATTACK_WINDUP_TIME,
		"strike_time": ATTACK_STRIKE_TIME,
		"recover_time": ATTACK_RECOVER_TIME,
		"gap_time": ATTACK_GAP_TIME,
		"windup_frames": ATTACK_WINDUP_FRAMES,
		"strike_frames": ATTACK_STRIKE_FRAMES,
		"strike_zone_forward": STRIKE_ZONE_FORWARD,
		"strike_zone_size": STRIKE_ZONE_SIZE,
		"post_reassembly_idle": POST_REASSEMBLY_IDLE,
	}


func get_attack_elapsed_time() -> float:
	return _attack_elapsed


func get_attack_facing_snapshot() -> int:
	return _attack_facing


func get_enemy_hit_count() -> int:
	return _enemy_hit_count


func get_last_strike_code() -> String:
	return _last_strike_code


func get_strike_zone_rect() -> Rect2:
	return _attack_zone_world()


func get_strike_zone_rect_for_facing(facing: int) -> Rect2:
	var center: Vector2 = global_position + Vector2(
		float(1 if facing >= 0 else -1) * STRIKE_ZONE_FORWARD, STRIKE_ZONE_CENTER_Y
	)
	return Rect2(center - STRIKE_ZONE_SIZE * 0.5, STRIKE_ZONE_SIZE)


func is_ai_walking_visual() -> bool:
	return _sprite.texture == _walk_texture()


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


func _draw() -> void:
	var color: Color = ORANGE_COLOR if _positive else BLUE_COLOR
	var alpha: float = modulate.a

	# World-space effects only. The custom rubble drawing has been removed; the
	# authentic die frame 11 is the scattered visual.
	_draw_tether(color, alpha)

	if _dust_timer > 0.0:
		var dust_alpha: float = clampf(_dust_timer / 0.28, 0.0, 1.0)
		var dust_color: Color = Color(0.62, 0.68, 0.62, 0.55 * dust_alpha)
		for index: int in range(3):
			var offset: float = float(index) * 5.0 + 4.0
			var dust: Rect2 = Rect2(
				float(_dust_direction) * (10.0 + offset),
				-3.0 - float(index) * 2.0,
				3.0,
				3.0
			)
			draw_rect(dust, dust_color)


func _draw_tether(color: Color, alpha: float) -> void:
	if _tether_timer <= 0.0:
		return
	var from_local: Vector2 = to_local(_tether_from)
	var tether_alpha: float = clampf(_tether_timer / TETHER_TIME, 0.0, 1.0)
	var tether_color: Color = Color(color.r, color.g, color.b, 0.75 * tether_alpha)
	draw_line(Vector2(0.0, -19.0), from_local, tether_color, 1.0)
	draw_circle(from_local, 2.0, tether_color)
