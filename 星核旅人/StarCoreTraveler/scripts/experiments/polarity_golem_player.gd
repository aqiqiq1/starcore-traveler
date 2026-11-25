extends PrototypePlayer

## Experiment-only single-swing attack layer for the polarity-golem prototype.
##
## This is a subclass of the unchanged PrototypePlayer. It adds one melee swing
## (J) and never rewrites the shared movement, polarity, jump or reset code:
##   - physics/state/animation of the base player still runs every tick;
##   - while the swing is active this script overwrites only the body sprite
##     (texture / hframes / frame) and skips the base frame stepper;
##   - when the swing ends the base animation is restored with _apply_animation.
##
## Design rules from the approved prototype brief:
##   - J is a single swing. Holding J or OS key-repeat echo never repeats it;
##     the room root forwards only real, non-echo key presses.
##   - Facing and polarity are snapshotted when the swing starts, so pressing Q
##     during the swing changes the NEXT swing, not the one in flight.
##   - The room root resolves the hit exactly once per swing, at the hit window,
##     against the golem. There is no per-tick damage here.
##   - All timings live in one block below so they can be tuned in one place.
##   - Enemy slam reactions (short real-velocity knockback, 0.15 s input
##     suppression, 0.6 s protection) also live only in this experiment
##     subclass; shared player.gd is untouched.

signal attack_started(swing_id: int, facing: int, positive: bool)
signal attack_hit_window(swing_id: int, facing: int, positive: bool)
signal attack_finished(swing_id: int)

const ATTACK_TEXTURE: Texture2D = preload(
	"res://assets/experiments/polarity_golem/hero/male_hero_combo_1.png"
)
const ATTACK_END_TEXTURE: Texture2D = preload(
	"res://assets/experiments/polarity_golem/hero/male_hero_combo_1_end.png"
)

# --- tunable swing parameters (single place) -------------------------------
## Seconds before the sword arc is considered live.
const HIT_OPEN_TIME: float = 0.06
## Seconds after which the live window closes (still part of the swing visual).
const HIT_CLOSE_TIME: float = 0.20
const SWING_FRAME_COUNT: int = 3
const SWING_FPS: float = 14.0
const END_FRAME_COUNT: int = 4
const END_FPS: float = 14.0
## Seconds the next swing is locked after this one's recovery ends.
const COOLDOWN_TIME: float = 0.12
# --- enemy slam reaction (experiment only) ---------------------------------
## Horizontal launch speed. Applied for the full 0.15 s reaction, then the
## shared ground deceleration bleeds it off: about 30-35 px total travel.
const HIT_KNOCKBACK_SPEED: float = 160.0
const HIT_REACTION_TIME: float = 0.15
const HIT_PROTECTION_TIME: float = 0.60
const HIT_FLASH_TIME: float = 0.15
# ---------------------------------------------------------------------------

const SWING_DURATION: float = float(SWING_FRAME_COUNT) / SWING_FPS
const END_DURATION: float = float(END_FRAME_COUNT) / END_FPS
const SWING_TOTAL_TIME: float = SWING_DURATION + END_DURATION

enum AttackPhase {
	READY,
	WINDUP,
	HIT,
	RECOVER,
	COOLDOWN,
}

var _attack_active: bool = false
var _attack_elapsed: float = 0.0
var _attack_cooldown: float = 0.0
var _attack_swing_id: int = 0
var _attack_facing: int = 1
var _attack_positive: bool = true
var _attack_hit_emitted: bool = false
var _hit_reaction_remaining: float = 0.0
var _hit_protection_remaining: float = 0.0
var _hit_flash_remaining: float = 0.0
var _hit_knockback_velocity: float = 0.0
var _hit_count: int = 0
var _last_hit_direction: int = 0
## Set on the formal-level completion page. The base input override must survive
## a hit reaction ending, so the player can never walk behind the result panel.
var _completion_locked: bool = false


func _physics_process(delta: float) -> void:
	if _completion_locked:
		# Keep the base override asserted even if a reaction/other path tried to
		# end it. Movement stays zero while the completion page is up.
		begin_input_override()
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_hit_protection_remaining = maxf(_hit_protection_remaining - delta, 0.0)
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	if _hit_flash_remaining <= 0.0 and _character_sprite != null:
		_character_sprite.modulate = Color.WHITE

	if _hit_reaction_remaining > 0.0:
		_hit_reaction_remaining = maxf(_hit_reaction_remaining - delta, 0.0)
		# Re-assert the away velocity every tick so held A/D (or the shared
		# move-toward step) cannot erase the visible knockback.
		if not _input_override_active:
			begin_input_override()
			set_input_override_axis(0.0)
		velocity.x = _hit_knockback_velocity
		if _hit_reaction_remaining <= 0.0 and not _completion_locked:
			end_input_override()

	var hit_due: bool = false
	if _attack_active:
		_attack_elapsed += delta
		if not _attack_hit_emitted and _attack_elapsed >= HIT_OPEN_TIME:
			_attack_hit_emitted = true
			hit_due = true

	# Base movement, jump, Q polarity and state selection run unchanged.
	super._physics_process(delta)

	if _attack_active:
		if hit_due:
			attack_hit_window.emit(_attack_swing_id, _attack_facing, _attack_positive)
		_apply_attack_visual()
		if _attack_elapsed >= SWING_TOTAL_TIME:
			_finish_attack()


## While the swing is active this script owns the body sprite, so the base
## per-tick frame stepper must not touch it.
func _update_animation(delta: float) -> void:
	if _attack_active:
		return
	super._update_animation(delta)


## R / fall / room reset must never leave a swing running with stale timing.
func reset_to_spawn(reason: String, count_it: bool = true) -> void:
	_completion_locked = false
	cancel_attack()
	_clear_enemy_hit_state()
	super.reset_to_spawn(reason, count_it)


## Enemy slam contact entry point. Returns false when the 0.6 s protection is
## active, so one smash can never chain-push the player.
## Knockback uses real velocity + move_and_slide, not a teleport.
func receive_enemy_strike(away_direction: int) -> bool:
	if _completion_locked or _hit_protection_remaining > 0.0:
		return false
	var direction: int = 1 if away_direction >= 0 else -1
	# A landed slam interrupts the current player swing; its pending hit window
	# is cleared by cancel_attack so no delayed damage can resolve.
	cancel_attack()
	_hit_reaction_remaining = HIT_REACTION_TIME
	_hit_protection_remaining = HIT_PROTECTION_TIME
	_hit_flash_remaining = HIT_FLASH_TIME
	_hit_knockback_velocity = float(direction) * HIT_KNOCKBACK_SPEED
	_hit_count += 1
	_last_hit_direction = direction
	# Suppress direction/jump/Q intent for the short reaction only. R and Esc
	# are handled by the experiment root and stay available.
	begin_input_override()
	set_input_override_axis(0.0)
	velocity.x = _hit_knockback_velocity
	if _character_sprite != null:
		_character_sprite.modulate = Color(1.0, 0.62, 0.55, 1.0)
	return true


func _clear_enemy_hit_state() -> void:
	_hit_reaction_remaining = 0.0
	_hit_protection_remaining = 0.0
	_hit_flash_remaining = 0.0
	_hit_knockback_velocity = 0.0
	_hit_count = 0
	_last_hit_direction = 0
	if _character_sprite != null:
		_character_sprite.modulate = Color.WHITE
	if _input_override_active:
		end_input_override()


func is_hit_protected() -> bool:
	return _hit_protection_remaining > 0.0


func is_in_hit_reaction() -> bool:
	return _hit_reaction_remaining > 0.0


func get_hit_count() -> int:
	return _hit_count


func get_hit_protection_remaining() -> float:
	return _hit_protection_remaining


func get_hit_reaction_remaining() -> float:
	return _hit_reaction_remaining


func get_hit_knockback_velocity() -> float:
	return _hit_knockback_velocity


func get_last_hit_direction() -> int:
	return _last_hit_direction


func get_hit_protection_time() -> float:
	return HIT_PROTECTION_TIME


func get_hit_reaction_time() -> float:
	return HIT_REACTION_TIME


func get_hit_knockback_speed() -> float:
	return HIT_KNOCKBACK_SPEED


## Called by the room root for a real, non-echo J press.
func request_attack() -> bool:
	if _completion_locked or _attack_active or _attack_cooldown > 0.0:
		return false
	_attack_active = true
	_attack_elapsed = 0.0
	_attack_hit_emitted = false
	_attack_swing_id += 1
	# Snapshot at swing start: Q during the swing affects the next swing only.
	_attack_facing = get_facing()
	_attack_positive = is_positive()
	_character_sprite.texture = ATTACK_TEXTURE
	_character_sprite.hframes = SWING_FRAME_COUNT
	_character_sprite.vframes = 1
	_character_sprite.frame = 0
	attack_started.emit(_attack_swing_id, _attack_facing, _attack_positive)
	return true


func cancel_attack() -> void:
	if not _attack_active:
		_attack_cooldown = 0.0
		return
	_attack_active = false
	_attack_elapsed = 0.0
	_attack_hit_emitted = false
	_attack_cooldown = 0.0
	_apply_animation(_state, true)


## Completion is a hard input lock for this attempt. It also cancels any swing
## and hit reaction so no late hit can resolve behind the result panel.
func lock_completion_input() -> void:
	_completion_locked = true
	cancel_attack()
	_hit_reaction_remaining = 0.0
	_hit_protection_remaining = 0.0
	_hit_flash_remaining = 0.0
	_hit_knockback_velocity = 0.0
	if _character_sprite != null:
		_character_sprite.modulate = Color.WHITE
	begin_input_override()
	set_input_override_axis(0.0)
	velocity = Vector2.ZERO


func unlock_completion_input() -> void:
	_completion_locked = false


func is_completion_locked() -> bool:
	return _completion_locked


func _finish_attack() -> void:
	var finished_id: int = _attack_swing_id
	_attack_active = false
	_attack_elapsed = 0.0
	_attack_cooldown = COOLDOWN_TIME
	_apply_animation(_state, true)
	# Base movement may have turned the body during the swing. The swing was
	# snapshotted, so restore the live facing only after it has finished.
	_visual_root.scale = Vector2(float(_facing), 1.0)
	attack_finished.emit(finished_id)


func _apply_attack_visual() -> void:
	# Keep the swing sprite pointing where the hit will resolve, even if A/D
	# turned the base body during the swing. After recovery, live facing returns.
	_visual_root.scale = Vector2(float(_attack_facing), 1.0)
	var elapsed: float = _attack_elapsed
	if elapsed < SWING_DURATION:
		_character_sprite.texture = ATTACK_TEXTURE
		_character_sprite.hframes = SWING_FRAME_COUNT
		_character_sprite.vframes = 1
		_character_sprite.frame = clampi(int(elapsed * SWING_FPS), 0, SWING_FRAME_COUNT - 1)
		return
	var end_elapsed: float = elapsed - SWING_DURATION
	_character_sprite.texture = ATTACK_END_TEXTURE
	_character_sprite.hframes = END_FRAME_COUNT
	_character_sprite.vframes = 1
	_character_sprite.frame = clampi(int(end_elapsed * END_FPS), 0, END_FRAME_COUNT - 1)


func is_attacking() -> bool:
	return _attack_active


func get_attack_phase() -> AttackPhase:
	if _attack_active:
		if _attack_elapsed < HIT_OPEN_TIME:
			return AttackPhase.WINDUP
		if _attack_elapsed < HIT_CLOSE_TIME:
			return AttackPhase.HIT
		return AttackPhase.RECOVER
	if _attack_cooldown > 0.0:
		return AttackPhase.COOLDOWN
	return AttackPhase.READY


func get_attack_phase_label() -> String:
	match get_attack_phase():
		AttackPhase.WINDUP:
			return "前摇"
		AttackPhase.HIT:
			return "命中段"
		AttackPhase.RECOVER:
			return "收招"
		AttackPhase.COOLDOWN:
			return "冷却 %.2fs" % _attack_cooldown
		_:
			return "就绪"


func get_attack_swing_id() -> int:
	return _attack_swing_id


func get_attack_elapsed() -> float:
	return _attack_elapsed


func get_attack_facing_snapshot() -> int:
	return _attack_facing


func get_attack_positive_snapshot() -> bool:
	return _attack_positive


func was_hit_window_emitted() -> bool:
	return _attack_hit_emitted


func get_attack_cooldown() -> float:
	return _attack_cooldown


func get_attack_total_time() -> float:
	return SWING_TOTAL_TIME


func get_attack_hit_open_time() -> float:
	return HIT_OPEN_TIME


func get_attack_hit_close_time() -> float:
	return HIT_CLOSE_TIME


func get_attack_body_texture() -> Texture2D:
	return _character_sprite.texture
