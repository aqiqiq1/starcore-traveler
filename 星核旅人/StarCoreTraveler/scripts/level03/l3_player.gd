class_name L3Player
extends "res://scripts/experiments/polarity_golem_player.gd"

## Level-03 player: the unchanged shared PrototypePlayer plus the already
## approved single-swing J layer from the polarity-golem experiment.
##
## Nothing in player.gd or the experiment script is edited. This subclass only
## adds:
##   - a restore hook that writes a real polarity state (used by checkpoints so
##     the player phase cannot silently drift from the stored record);
##   - cinematic/completion lock wrappers that reuse the experiment's hard input
##     lock and always release the movement override when control returns;
##   - the level-03-only hit presentation: a local shader flash that is clearly
##     red while keeping the body's texture, and an away-from-the-guard knockback
##     direction resolved at this receive entry point (the guard script and its
##     state machine are not changed);
##   - a small clear hook so pause / cinematic / scene change / completion never
##     leave a red flash, knockback speed or short input lock behind.
##
## J timings, the 0.15 s reaction, 0.6 s protection and the swing snapshot all
## stay owned by the experiment subclass.

const HURT_SHADER: Shader = preload("res://scripts/level03/l3_player_hurt.gdshader")
## The flash holds full red for most of the existing 0.15 s reaction, then fades
## back over this short tail. It never outlives the reaction window.
const HURT_FADE_TIME: float = 0.05

## Emitted when the shared player's own automatic fall reaches the kill line.
## Level 03 covers the screen and performs its existing stable restore at black;
## the shared player.gd and the experiment subclass stay untouched.
signal recovery_transition_requested(reason: String)

var _walk_override_active: bool = false
var _cinematic_lock: bool = false
var _hurt_material: ShaderMaterial = null
var _hurt_visual_remaining: float = 0.0
## Level 03 enables this once. A fall reset request is then held until the
## level's cover is fully black, instead of teleporting the body behind a
## visible frame.
var _recovery_intercept_enabled: bool = false
var _recovery_hold: bool = false
## Read-only use of the guard's position so the push always points away from
## the real damage source, including a ring released behind the player.
var _strike_source: Node2D = null


func _ready() -> void:
	super._ready()
	_setup_hurt_material()


func _setup_hurt_material() -> void:
	if _character_sprite == null:
		return
	if _character_sprite.material is ShaderMaterial:
		_hurt_material = _character_sprite.material as ShaderMaterial
		if _hurt_material.shader == HURT_SHADER:
			return
	_hurt_material = ShaderMaterial.new()
	_hurt_material.shader = HURT_SHADER
	_character_sprite.material = _hurt_material


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _hurt_visual_remaining <= 0.0:
		return
	_hurt_visual_remaining = maxf(_hurt_visual_remaining - delta, 0.0)
	# Full red through the reaction, short fade at its very end.
	var amount: float = clampf(_hurt_visual_remaining / HURT_FADE_TIME, 0.0, 1.0)
	_apply_hurt_visual(amount)


func set_polarity_state(positive: bool) -> void:
	if _positive == positive:
		return
	_positive = positive
	_switch_ring.visible = false
	_ring_time = 0.0
	_apply_polarity_visuals()
	polarity_changed.emit(_positive)


## Called once by level 03. Only the guard's position is read here; its state
## machine, strike zone, damage numbers and timings stay untouched.
func set_strike_source(source: Node2D) -> void:
	_strike_source = source


## Enemy slam / ring contact entry. The guard still calls this through its real
## resolution path; only the away direction is corrected here so a player to the
## left of the guard is always pushed left (and vice versa), not along the
## guard's facing.
func receive_enemy_strike(away_direction: int) -> bool:
	var corrected: int = _resolve_away_direction(away_direction)
	var accepted: bool = super.receive_enemy_strike(corrected)
	if accepted:
		# The experiment's modulate tint is too subtle to read in motion. The
		# L3-local shader owns the visible red; keep the sprite modulate neutral
		# so it cannot darken the flash.
		if _character_sprite != null:
			_character_sprite.modulate = Color.WHITE
		_hurt_visual_remaining = get_hit_reaction_time()
		_apply_hurt_visual(1.0)
	return accepted


func _resolve_away_direction(fallback: int) -> int:
	if _strike_source != null and is_instance_valid(_strike_source):
		var dx: float = global_position.x - _strike_source.global_position.x
		if absf(dx) >= 1.0:
			return 1 if dx > 0.0 else -1
	return 1 if fallback >= 0 else -1


## Clears only presentation/motion feedback: red flash, the remaining short
## reaction, knockback speed and (when one is running) the reaction input
## override. Loading, completion and cinematic locks are respected. Protection
## time and gameplay progress are not rewritten here.
func clear_hit_feedback() -> void:
	var was_reacting: bool = _hit_reaction_remaining > 0.0
	_hit_reaction_remaining = 0.0
	_hit_flash_remaining = 0.0
	_hit_knockback_velocity = 0.0
	_hurt_visual_remaining = 0.0
	_apply_hurt_visual(0.0)
	if _character_sprite != null:
		_character_sprite.modulate = Color.WHITE
	if was_reacting:
		velocity.x = 0.0
		if _input_override_active and not _cinematic_lock and not _completion_locked:
			end_input_override()


func get_hurt_tint_amount() -> float:
	if _hurt_material == null:
		return 0.0
	return float(_hurt_material.get_shader_parameter("hit_amount"))


func get_hurt_visual_remaining() -> float:
	return _hurt_visual_remaining


func _apply_hurt_visual(amount: float) -> void:
	if _hurt_material != null:
		_hurt_material.set_shader_parameter("hit_amount", clampf(amount, 0.0, 1.0))


func reset_to_spawn(reason: String, count_it: bool = true) -> void:
	# The shared player calls this from its own automatic-fall check. L3 does not
	# teleport on that request: it asks the level to fade to black first. When the
	# level later performs its existing restore, _recovery_hold is already true,
	# so this branch performs the real reset once and never re-enters.
	if reason == "fall" and _recovery_intercept_enabled and not _recovery_hold:
		begin_recovery_hold()
		recovery_transition_requested.emit("fall")
		return
	if _recovery_hold:
		end_recovery_hold()
	_hurt_visual_remaining = 0.0
	_apply_hurt_visual(0.0)
	super.reset_to_spawn(reason, count_it)


## Level-03-local handshake for the recovery cover. Freezing physics prevents a
## falling body from re-triggering the kill line during the fade and prevents any
## walk/jump/polarity tick while the transition owns the screen.
func set_recovery_intercept_enabled(value: bool) -> void:
	_recovery_intercept_enabled = value


func begin_recovery_hold() -> void:
	_recovery_hold = true
	velocity = Vector2.ZERO
	set_physics_process(false)


func end_recovery_hold() -> void:
	_recovery_hold = false
	set_physics_process(true)


func is_recovery_held() -> bool:
	return _recovery_hold


func lock_completion_input() -> void:
	_hurt_visual_remaining = 0.0
	_apply_hurt_visual(0.0)
	super.lock_completion_input()


## Used only by the near-gate cinematic so the body visibly turns toward the
## guard after the question mark / real stone cue. It changes facing only; the
## shared movement, input and collision rules are untouched.
func face_direction(direction: int) -> void:
	if direction == 0:
		return
	_set_facing(1 if direction > 0 else -1)


## Used only by the near-gate cinematic for a short scripted walk. It is not a
## new gameplay state: the player still owns its sprite/physics and J/E are
## blocked by the level while the cinematic is active.
func begin_cinematic_walk(axis: float) -> void:
	_walk_override_active = true
	begin_input_override()
	set_input_override_axis(axis, false)
	cancel_attack()


func set_cinematic_walk_axis(axis: float) -> void:
	if not _walk_override_active:
		return
	set_input_override_axis(axis, false)


func end_cinematic_walk() -> void:
	if not _walk_override_active:
		return
	_walk_override_active = false
	set_input_override_axis(0.0, false)


func lock_for_cinematic() -> void:
	_walk_override_active = false
	_cinematic_lock = true
	# No hit red or knockback may survive into the film.
	clear_hit_feedback()
	begin_input_override()
	set_input_override_axis(0.0, false)
	cancel_attack()


func unlock_after_cinematic() -> void:
	_cinematic_lock = false
	_walk_override_active = false
	unlock_completion_input()
	end_input_override()
	clear_input_buffers()
	clear_external_force()


func is_cinematic_locked() -> bool:
	return _cinematic_lock
