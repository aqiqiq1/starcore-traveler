class_name TrialChambers
extends Node2D

## Optional "星核试炼场" trial: two polarity gates then the existing guard
## fight, ending on a small completion page.  Nothing here changes the three
## formal levels, the shared player/guard rules, project.godot or the menus.
##
## Rules kept from the approved brief:
##   - the player starts in 澜相 (cyan), the first gate is 辉相, the second is
##     澜相, so the route is gold -> Q -> cyan -> Q;
##   - the gate only reads player.is_positive(); it never injects input;
##   - the guard fight reuses scenes/level03/guard.tscn and the L3 player's
##     existing J / hurt / retry rules.  Two accepted hits retry at the arena
##     entrance; R restarts the whole trial in place;
##   - completion is only reachable after the guard is defeated.

signal level_completed

@export var show_intro_guide: bool = true

const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")
const DLC_GUIDE_SCENE: PackedScene = preload("res://dlc/ui/dlc_guide.tscn")

const START_SPAWN: Vector2 = Vector2(40.0, 320.0)
const ARENA_SPAWN: Vector2 = Vector2(850.0, 320.0)
const GUARD_SPAWN: Vector2 = Vector2(1060.0, 320.0)
const FINISH_POSITION: Vector2 = Vector2(1218.0, 320.0)
const ARENA_ENTER_X: float = 820.0
const FINISH_RANGE: float = 18.0
const KILL_Y: float = 430.0
const WORLD_RIGHT: float = 1268.0
const TRIAL_PATH: String = "res://dlc/trial_chambers/trial_chambers.tscn"

const RECOVERY_FADE_OUT_TIME: float = 0.25
const RECOVERY_BLACK_HOLD_TIME: float = 0.10
const RECOVERY_FADE_IN_TIME: float = 0.35
## Same body centre the shared level-03 force providers use.  The guard's
## gravity field was already approved; this chapter must feed it to the player.
const BODY_CENTER_OFFSET: Vector2 = Vector2(0.0, -15.0)
## Facing assist only inside the arena and only when a live guard is this close.
const AUTO_FACE_RANGE: float = 140.0

enum RecoveryPhase { NONE, FADE_OUT, BLACK_HOLD, FADE_IN }

@onready var _player: L3Player = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _guard: L3Guard = $Guard
@onready var _gate_gold: PolarityGate = $GateGold
@onready var _gate_cyan: PolarityGate = $GateCyan
@onready var _hud: TrialHUD = $HUD
@onready var _finish_core: Sprite2D = $FinishPoint/Core
@onready var _audio = $Audio

var _elapsed: float = 0.0
var _completed: bool = false
var _scene_leaving: bool = false
var _arena_entered: bool = false
var _guard_defeated: bool = false
var _finish_time: float = 0.0
var _objective_key: String = ""
var _pause_open: bool = false
var _attack_key_down: bool = false
var _resolved_swings: Dictionary = {}
var _player_hits: int = 0
var _retry_pending: bool = false
var _retry_pending_left: float = 0.0
var _guard_ticks: int = 0
var _last_polarity_toggles: int = 0

var _recovery_active: bool = false
var _recovery_phase: RecoveryPhase = RecoveryPhase.NONE
var _recovery_kind: String = ""
var _recovery_alpha: float = 0.0
var _recovery_elapsed: float = 0.0
var _recovery_applying: bool = false
var _intro_guide: DlcGuide = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10

	for node: Node in [
		$Background, $Terrain, $Decorations, $Player, $Guard,
		$GateGold, $GateCyan, $FinishPoint,
	]:
		if node != null:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE
	$HUD.process_mode = Node.PROCESS_MODE_ALWAYS

	_player.allow_self_reset = false
	_player.set_world_bounds(0.0, WORLD_RIGHT)
	_player.set_kill_y(KILL_Y)
	_player.set_spawn_point(START_SPAWN)
	_player.set_recovery_intercept_enabled(true)
	_player.reset_to_spawn("level_start", false)
	_player.set_polarity_state(false)
	_player.global_position = START_SPAWN
	_player.velocity = Vector2.ZERO
	_player.polarity_changed.connect(_on_player_polarity_changed)
	_player.attack_hit_window.connect(_on_player_attack_hit_window)
	_player.attack_started.connect(_on_player_attack_started)
	_player.recovery_transition_requested.connect(_on_player_recovery_transition_requested)

	_gate_gold.set_player_node(_player)
	_gate_cyan.set_player_node(_player)
	_gate_gold.set_required_positive(true)
	_gate_cyan.set_required_positive(false)

	_guard.set_player_target(_player)
	_guard.reset_state(GUARD_SPAWN, true, true)
	_guard.set_suspended(true)
	_player.set_strike_source(_guard)
	_connect_guard()

	_hud.resume_requested.connect(_on_hud_resume_requested)
	_hud.title_requested.connect(_on_hud_title_requested)
	_hud.set_polarity(false)
	_hud.set_objective("目标：Q 换相，穿过金门")
	_hud.show_completion(false, 0.0)
	_hud.show_pause(false)
	_hud.set_recovery_alpha(0.0)
	_update_finish_marker()

	_camera.reset_smoothing()
	_elapsed = 0.0
	LEVEL_FLOW.release_one_shot_actions()
	_player.begin_input_override()
	_guard_ticks = 3
	if show_intro_guide:
		call_deferred("_open_intro_guide")


## Called once per scene load.  Tests set show_intro_guide = false before
## add_child(), so their input routes never meet a paused tree.
func _open_intro_guide() -> void:
	if not show_intro_guide or _completed or _scene_leaving:
		return
	if _intro_guide != null and is_instance_valid(_intro_guide):
		return
	_intro_guide = DLC_GUIDE_SCENE.instantiate() as DlcGuide
	add_child(_intro_guide)
	_intro_guide.closed.connect(_on_intro_guide_closed)
	_intro_guide.configure("trial", self)
	_intro_guide.open_guide()


func _on_intro_guide_closed(_kind: String) -> void:
	# Closing the guide must not let its F/Space key become a jump or a Q
	# press.  Re-arm the same three-tick opening hold the scene starts with.
	_attack_key_down = false
	_player.begin_input_override()
	_guard_ticks = 3


func _exit_tree() -> void:
	if _audio != null:
		_audio.stop_all()
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


func _connect_guard() -> void:
	_guard.player_struck.connect(_on_guard_player_struck)
	_guard.true_damage_dealt.connect(_on_guard_true_damage)
	_guard.shattered.connect(_on_guard_shattered)
	_guard.defeated.connect(_on_guard_defeated)
	_guard.charge_started.connect(_on_guard_charge_started)
	_guard.slam_contact.connect(_on_guard_slam_contact)
	_guard.gravity_release.connect(_on_guard_gravity_release)
	_guard.reassembly_started.connect(_on_guard_reassembly_started)


# --- frame flow ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if get_tree().paused or _completed or _scene_leaving or _recovery_active:
		return
	if _retry_pending:
		_retry_pending_left = maxf(_retry_pending_left - delta, 0.0)
		if _retry_pending_left <= 0.0:
			_retry_pending = false
			_begin_recovery("combat")
			return
	if _guard_ticks > 0:
		_guard_ticks -= 1
		_player.begin_input_override()
		if _guard_ticks <= 0:
			_player.end_input_override()
		return

	if not _arena_entered and _player.global_position.x >= ARENA_ENTER_X:
		_arena_entered = true
		_guard.set_suspended(false)
		_hud.show_event("守卫苏醒", 1.8)
		DemoAudio.play_record_save()
	_apply_guard_force()
	_update_objective()
	if _guard_defeated and not _completed:
		_check_finish()


func _process(delta: float) -> void:
	if get_tree().paused or _scene_leaving:
		return
	if not _completed:
		_elapsed += delta
	_advance_recovery(delta)
	if _finish_core != null:
		_finish_time += delta
		_finish_core.frame = int(_finish_time * 10.0) % 12


## The approved level-03 guard is a force provider: opposite phase is pulled in,
## same phase is pushed away during GRAVITY_CHARGE.  The trial omitted that
## feed, so the weakpoint stayed outside the 36 px J reach in real play even
## though the guard drew its field.  This is the existing guard contract, not a
## new rule or a damage change.
func _apply_guard_force() -> void:
	if _player == null or _guard == null:
		return
	var player_center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
	var sample: Dictionary = _guard.sample_player_force(
		player_center, _player.is_positive(), _player.get_rid()
	)
	var acceleration: Vector2 = sample.get("acceleration", Vector2.ZERO)
	if acceleration.is_zero_approx():
		_player.clear_external_force()
	else:
		_player.apply_external_force(acceleration)


## A real J press turns toward the nearest live guard inside the arena.  The
## shared player faces its last movement direction, so after stepping back or
## between two targets a swing could snapshot the old facing and miss behind.
## Only facing changes here; reach, phase, charge and damage rules are untouched.
func _face_nearest_guard_on_attack() -> void:
	if not _arena_entered or _guard == null or _guard.is_defeated():
		return
	var dx: float = _guard.global_position.x - _player.global_position.x
	if absf(dx) <= AUTO_FACE_RANGE:
		_player.face_direction(1 if dx >= 0.0 else -1)


func _update_objective() -> void:
	var text: String
	var key: String
	if _guard_defeated:
		text = "目标：触碰完成点"
		key = "finish"
	elif _arena_entered:
		text = "目标：击败守卫（异相 J 有效）"
		key = "arena"
	elif _player.global_position.x >= 540.0:
		text = "目标：前往守卫竞技场"
		key = "approach"
	elif _player.global_position.x >= 300.0:
		text = "目标：再按 Q 回澜相，穿过青门"
		key = "cyan_gate"
	else:
		text = "目标：Q 换相，穿过金门"
		key = "gold_gate"
	if key == _objective_key:
		return
	_objective_key = key
	_hud.set_objective(text)


# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _intro_guide != null and is_instance_valid(_intro_guide) and _intro_guide.is_open():
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)
	if key_event.pressed and not key_event.echo and code == int(KEY_R):
		_restart_trial()
		get_viewport().set_input_as_handled()
		return
	if _scene_leaving:
		return
	if _pause_open:
		return
	if _completed:
		if key_event.pressed and not key_event.echo and (
			code == int(KEY_E) or code == int(KEY_ENTER) or code == int(KEY_KP_ENTER)
		):
			# Mark handled before the scene change: _return_to_title() may free
			# this node during the same dispatch, leaving get_viewport() null.
			get_viewport().set_input_as_handled()
			_return_to_title()
		return
	if _recovery_active:
		return
	_player.handle_key_event(key_event)
	if key_event.echo:
		return
	if code == int(KEY_J):
		if key_event.pressed:
			if not _attack_key_down:
				_attack_key_down = true
				_face_nearest_guard_on_attack()
				_player.request_attack()
				get_viewport().set_input_as_handled()
		else:
			_attack_key_down = false


func _unhandled_input(event: InputEvent) -> void:
	if _intro_guide != null and is_instance_valid(_intro_guide) and _intro_guide.is_open():
		return
	if _scene_leaving or _completed or _recovery_active:
		return
	if event.is_action_pressed(&"pause"):
		_set_paused(not _pause_open)
		get_viewport().set_input_as_handled()


func _on_hud_resume_requested() -> void:
	_set_paused(false)


func _on_hud_title_requested() -> void:
	_return_to_title()


func _set_paused(value: bool) -> void:
	if value == _pause_open:
		return
	_pause_open = value
	_hud.show_pause(value)
	_attack_key_down = false
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	if value:
		if _arena_entered and not _guard_defeated:
			_guard.set_suspended(true)
		get_tree().paused = true
		return
	get_tree().paused = false
	LEVEL_FLOW.release_one_shot_actions()
	_player.clear_input_buffers()
	if _arena_entered and not _guard_defeated and not _completed:
		_guard.set_suspended(false)


# --- guard / combat --------------------------------------------------------

func _on_player_polarity_changed(positive: bool) -> void:
	var toggles: int = _player.get_polarity_toggle_count()
	if toggles > _last_polarity_toggles:
		DemoAudio.play_polarity_switch()
	_last_polarity_toggles = toggles
	if _hud != null:
		_hud.set_polarity(positive)


func _on_player_attack_started(_swing_id: int, _facing: int, _positive: bool) -> void:
	DemoAudio.play_swing()


func _on_player_attack_hit_window(swing_id: int, facing: int, positive: bool) -> void:
	if _completed or _scene_leaving or _recovery_active:
		return
	if _resolved_swings.has(swing_id):
		return
	_resolved_swings[swing_id] = true
	var result: Dictionary = _guard.receive_player_hit(
		_player, facing, positive, swing_id
	)
	_show_attack_result_hint(result)


## One short, non-blocking line that explains why a J did not remove a cell.
## Successful true damage keeps the existing "剩余 N" event from the guard
## signal, so this helper never overwrites a real hit.
func _show_attack_result_hint(result: Dictionary) -> void:
	if bool(result.get("true_damage", false)):
		return
	match String(result.get("code", "")):
		"SHELL_SHATTER":
			_hud.show_event("仅碎壳 · 蓄力时异相 J 才掉血", 1.4)
		"SAME_PHASE":
			_hud.show_event("同相无效 · Q 切异相再按 J", 1.4)
		"MISS_RANGE":
			_hud.show_event("距离不够 · 贴近守卫再按 J", 1.4)
		"MISS_BEHIND":
			_hud.show_event("转身面向守卫再按 J", 1.4)
		"BLOCKED":
			_hud.show_event("守卫被石柱挡住 · 换个角度", 1.4)
		_:
			pass


func _on_guard_player_struck(_facing: int) -> void:
	if _completed or _scene_leaving or _recovery_active or _retry_pending:
		return
	_player_hits += 1
	DemoAudio.play_player_hurt()
	_hud.show_event("受击 %d / 2" % _player_hits, 1.1)
	if _player_hits >= 2:
		_retry_pending = true
		_retry_pending_left = maxf(_player.get_hit_reaction_remaining(), 0.0)


func _on_guard_true_damage(_taken: int, remaining: int) -> void:
	_hud.show_event("守卫星核外露 · 剩余 %d" % remaining, 1.2)


func _on_guard_shattered() -> void:
	_audio.stop_charge(0.04)
	DemoAudio.play_shell_shatter()


func _on_guard_charge_started(_positive: bool) -> void:
	_audio.play_charge()
	_hud.show_event("引力蓄力 · 异相 J 有效", 1.2)


func _on_guard_slam_contact(_facing: int) -> void:
	_audio.stop_charge(0.08)
	_audio.play_slam()


func _on_guard_gravity_release(_positive: bool) -> void:
	_audio.stop_charge(0.05)
	_audio.play_slam()


func _on_guard_reassembly_started() -> void:
	_audio.play_reassemble()


func _on_guard_defeated() -> void:
	if _completed or _guard_defeated:
		return
	_guard_defeated = true
	_player_hits = 0
	_audio.stop_charge(0.05)
	_hud.show_event("守卫已击败 · 完成点激活", 2.0)
	DemoAudio.play_record_save()
	_update_finish_marker()
	_update_objective()


# --- recovery transition (same approved timing as level 03) ----------------

func _on_player_recovery_transition_requested(reason: String) -> void:
	if reason != "fall" or _recovery_active or _completed or _scene_leaving:
		return
	_begin_recovery("fall")


func _begin_recovery(kind: String) -> void:
	if _recovery_active or _completed or _scene_leaving:
		return
	_recovery_active = true
	_recovery_kind = kind
	_recovery_phase = RecoveryPhase.FADE_OUT
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_attack_key_down = false
	_audio.stop_charge(0.05)
	DemoAudio.play_failure()
	_hud.set_recovery_alpha(0.0)
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	_player.cancel_attack()
	_player.begin_recovery_hold()
	_player.clear_external_force()
	_guard.set_suspended(true)


func _advance_recovery(delta: float) -> void:
	if not _recovery_active:
		return
	_recovery_elapsed += delta
	match _recovery_phase:
		RecoveryPhase.FADE_OUT:
			_recovery_alpha = clampf(_recovery_elapsed / RECOVERY_FADE_OUT_TIME, 0.0, 1.0)
			_hud.set_recovery_alpha(_recovery_alpha)
			if _recovery_alpha >= 1.0:
				_recovery_phase = RecoveryPhase.BLACK_HOLD
				_recovery_elapsed = 0.0
				_apply_recovery_reset()
		RecoveryPhase.BLACK_HOLD:
			_recovery_alpha = 1.0
			_hud.set_recovery_alpha(1.0)
			if _recovery_elapsed >= RECOVERY_BLACK_HOLD_TIME:
				_recovery_phase = RecoveryPhase.FADE_IN
				_recovery_elapsed = 0.0
				DemoAudio.play_respawn()
		RecoveryPhase.FADE_IN:
			_recovery_alpha = clampf(
				1.0 - _recovery_elapsed / RECOVERY_FADE_IN_TIME, 0.0, 1.0
			)
			_hud.set_recovery_alpha(_recovery_alpha)
			if _recovery_alpha <= 0.0:
				_finish_recovery()


func _apply_recovery_reset() -> void:
	if _recovery_applying:
		return
	_recovery_applying = true
	if _recovery_kind == "fall" and not _arena_entered:
		_reset_player_at(START_SPAWN)
	else:
		_retry_combat()
	_player.begin_recovery_hold()
	_guard.set_suspended(true)
	_recovery_applying = false


func _finish_recovery() -> void:
	if not _recovery_active:
		return
	_recovery_active = false
	_recovery_phase = RecoveryPhase.NONE
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_hud.set_recovery_alpha(0.0)
	_player.end_recovery_hold()
	_player.end_input_override()
	_player.clear_input_buffers()
	_player.clear_external_force()
	_attack_key_down = false
	LEVEL_FLOW.release_one_shot_actions()
	if _arena_entered and not _guard_defeated and not _completed and not _scene_leaving:
		_guard.set_suspended(false)


func _retry_combat() -> void:
	_resolved_swings.clear()
	_player_hits = 0
	_retry_pending = false
	_retry_pending_left = 0.0
	_guard.reset_state(GUARD_SPAWN, true, true)
	_guard.set_player_target(_player)
	_guard.set_suspended(true)
	_reset_player_at(ARENA_SPAWN)
	_hud.show_event("失败 · 回竞技场入口", 1.8)


func _reset_player_at(point: Vector2) -> void:
	_player.set_spawn_point(point)
	_player.reset_to_spawn("combat_retry", true)
	_player.set_polarity_state(false)
	_player.global_position = point
	_player.velocity = Vector2.ZERO
	_player.clear_input_buffers()
	_player.clear_external_force()
	_camera.reset_smoothing()
	_hud.set_polarity(false)


# --- finish / completion ---------------------------------------------------

func _check_finish() -> void:
	if _completed:
		return
	var offset: float = absf(_player.global_position.x - FINISH_POSITION.x)
	if offset > FINISH_RANGE:
		return
	if _player.global_position.y < 280.0:
		return
	_complete_trial()


func _update_finish_marker() -> void:
	if _finish_core == null:
		return
	if _guard_defeated:
		_finish_core.modulate = Color(1.0, 0.92, 0.72, 1.0)
	else:
		_finish_core.modulate = Color(0.42, 0.52, 0.56, 0.62)


func _complete_trial() -> void:
	if _completed or _scene_leaving:
		return
	_completed = true
	_retry_pending = false
	_player_hits = 0
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.lock_completion_input()
	_guard.set_suspended(true)
	_hud.show_pause(false)
	_hud.show_completion(true, _elapsed)
	_hud.set_objective("目标：试炼完成")
	DemoAudio.play_complete()
	LEVEL_FLOW.release_one_shot_actions()
	level_completed.emit()


func _return_to_title() -> void:
	if _scene_leaving:
		return
	get_tree().paused = false
	_pause_open = false
	_scene_leaving = true
	_hud.show_pause(false)
	_hud.show_completion(false, _elapsed)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	_guard.set_suspended(true)
	LEVEL_FLOW.return_to_title(get_tree())


# --- restart / accessors ---------------------------------------------------

func _restart_trial() -> void:
	if _scene_leaving:
		return
	get_tree().paused = false
	_pause_open = false
	_completed = false
	_arena_entered = false
	_guard_defeated = false
	_retry_pending = false
	_retry_pending_left = 0.0
	_recovery_active = false
	_recovery_phase = RecoveryPhase.NONE
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_recovery_kind = ""
	_resolved_swings.clear()
	_player_hits = 0
	_elapsed = 0.0
	_finish_time = 0.0
	_objective_key = ""
	_attack_key_down = false
	_last_polarity_toggles = 0
	_audio.stop_all()
	_hud.set_recovery_alpha(0.0)
	_hud.show_completion(false, 0.0)
	_hud.show_pause(false)
	_hud.set_objective("目标：Q 换相，穿过金门")
	_hud.set_polarity(false)
	_player.end_recovery_hold()
	_player.unlock_completion_input()
	_reset_player_at(START_SPAWN)
	_guard.reset_state(GUARD_SPAWN, true, true)
	_guard.set_player_target(_player)
	_guard.set_suspended(true)
	_gate_gold.set_required_positive(true)
	_gate_cyan.set_required_positive(false)
	_update_finish_marker()
	LEVEL_FLOW.release_one_shot_actions()
	_player.begin_input_override()
	_guard_ticks = 3
	_hud.show_event("试炼已重新开始", 1.5)


func get_player() -> L3Player:
	return _player


func get_guard() -> L3Guard:
	return _guard


func get_hud() -> TrialHUD:
	return _hud


func get_intro_guide() -> DlcGuide:
	return _intro_guide


func get_camera() -> Camera2D:
	return _camera


func get_gate_gold() -> PolarityGate:
	return _gate_gold


func get_gate_cyan() -> PolarityGate:
	return _gate_cyan


func get_finish_position() -> Vector2:
	return FINISH_POSITION


func get_arena_spawn() -> Vector2:
	return ARENA_SPAWN


func get_start_spawn() -> Vector2:
	return START_SPAWN


func get_elapsed_seconds() -> float:
	return _elapsed


func is_completed() -> bool:
	return _completed


func is_guard_defeated() -> bool:
	return _guard_defeated


func is_arena_entered() -> bool:
	return _arena_entered


func is_pause_open() -> bool:
	return _pause_open


func is_recovery_active() -> bool:
	return _recovery_active


func get_player_hits() -> int:
	return _player_hits


func get_finish_sprite() -> Sprite2D:
	return _finish_core
