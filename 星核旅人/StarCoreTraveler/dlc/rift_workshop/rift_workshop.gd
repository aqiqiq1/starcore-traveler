class_name RiftWorkshop
extends Node2D

## DLC chapter 2 "裂隙工坊" (Rift Workshop).
##
## Three connected rooms on one 1600 x 360 scene:
##   1. 反转回廊  x 0..560    : InversionA@160 flips the positive start to 澜相;
##                              GateGold@270 (requires 辉相) forces one Q; then
##                              GateCyan@490 (requires 澜相) forces a second Q
##                              before InversionB@520 flips back to 辉相;
##   2. 相性桥    x 560..1080 : a raised terrace, three 64x10 PhaseBridges
##                              alternating gold / cyan with stone landings, two
##                              more wisps and a checkpoint.  There is no floor
##                              under the bridge gaps: a fall is cloud sea;
##   3. 双生守卫  x 1080..1600: two reused scenes/level03/guard.tscn instances,
##                              one gold and one cyan, each with its own patrol
##                              range.  Both must be defeated to open the finish.
##
## Reused, never modified: L3Player (J / hurt / fall recovery), guard.tscn, the
## shared PolarityGate scene from the trial chapter, DS03, the L2 stone strip,
## the project fonts and palette.  New content lives only in dlc/rift_workshop/.

signal level_completed

@export var show_intro_guide: bool = true

const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")
const RIFT_GUIDE_SCRIPT: Script = preload("res://dlc/rift_workshop/rift_guide.gd")
const MECHANIC_POPUP_SCENE: PackedScene = preload("res://scenes/ui/mechanic_popup.tscn")
const MECHANIC_DEMO_DIR: String = "res://dlc/ui/demos"

## DLC copy registered through the shared MechanicPopup table.  Every body
## starts with the in-world cause and only then explains the keys.  Lines stay
## within the shared 62 px label (<= 21 full-width characters per line).
const RIFT_TIPS: Dictionary = {
	"rift_charge_tip": {
		"title": "引力锁核",
		"body": "星核余烬锁在守卫胸甲，蓄力时引力场拖近人。\n等蓄力、Q 切异相、被吸近后 J 打胸口菱形。",
		"key": "蓄力时异相 J · 只碎壳不算伤害",
		"demo": "rift_elements",
	},
	"rift_core_tip": {
		"title": "裂隙核心",
		"body": "双生守卫倒下，裂隙核心失去引力护持。\n核心处就是出口，走近触碰即可封闭裂隙。",
		"key": "走近核心 · 触碰封闭",
		"demo": "rift_core",
	},
}

const START_SPAWN: Vector2 = Vector2(40.0, 320.0)
## The bridge section's own reset point.  A fall from any bridge gap goes back
## here until the checkpoint is recorded, not all the way back to x = 40.
const BRIDGE_HEAD_SPAWN: Vector2 = Vector2(600.0, 280.0)
const BRIDGE_SECTION_LEFT: float = 540.0
const ARENA_SPAWN: Vector2 = Vector2(1100.0, 320.0)
const CHECKPOINT_POSITION: Vector2 = Vector2(1030.0, 280.0)
const FINISH_POSITION: Vector2 = Vector2(1560.0, 320.0)
const GUARD_GOLD_SPAWN: Vector2 = Vector2(1240.0, 320.0)
const GUARD_CYAN_SPAWN: Vector2 = Vector2(1450.0, 320.0)
const ARENA_ENTER_X: float = 1090.0
const ARENA_LEFT: float = 1080.0
const BRIDGE_FALL_LINE: String = "坠入云海 · 相性不符的桥会消失 · Q 换相"
const BRIDGE_EDGE_LINE: String = "断桥 · Q 换相让光桥实体化"
## Both guards hover asleep for this long after the arena entry event line, so
## the player is never caught between two charge-ups on the first step in.
const ARENA_INTRO_TIME: float = 0.8
## The gold guard's first real GRAVITY_CHARGE starts as soon as the player is
## this close after the opening.  The guard's own teaching state
## (`reset_state(..., keep_teaching = true)`) makes GRAVITY its first action;
## this range only decides when the queued teaching charge fires.
const TEACHING_TRIGGER_RANGE: float = 110.0
const FINISH_RANGE: float = 18.0
const KILL_Y: float = 430.0
const WORLD_RIGHT: float = 1600.0
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

const RECOVERY_FADE_OUT_TIME: float = 0.25
const RECOVERY_BLACK_HOLD_TIME: float = 0.10
const RECOVERY_FADE_IN_TIME: float = 0.35
## Same body centre the shared level-03 force providers use.  Both guards feed
## their already-approved gravity field through this one player call per tick.
const BODY_CENTER_OFFSET: Vector2 = Vector2(0.0, -15.0)
## Facing assist range while a real J is pressed inside the arena.
const AUTO_FACE_RANGE: float = 140.0

enum RecoveryPhase { NONE, FADE_OUT, BLACK_HOLD, FADE_IN }

@onready var _player: L3Player = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _guard_gold: L3Guard = $GuardGold
@onready var _guard_cyan: L3Guard = $GuardCyan
@onready var _field_a: RiftInversionField = $InversionA
@onready var _field_b: RiftInversionField = $InversionB
@onready var _bridge_a: RiftPhaseBridge = $BridgeA
@onready var _bridge_b: RiftPhaseBridge = $BridgeB
@onready var _bridge_c: RiftPhaseBridge = $BridgeC
@onready var _checkpoint: LevelCheckpoint = $RiftCheckpoint
@onready var _hud: RiftWorkshopHUD = $HUD
@onready var _finish_core: Sprite2D = $FinishPoint/Core
@onready var _audio = $Audio
@onready var _ambience: DlcChapterAmbience = $Ambience
@onready var _cue: RiftGuardCue = $GuardCue

var _wisps: Array[RiftPolarityWisp] = []

var _elapsed: float = 0.0
var _completed: bool = false
var _scene_leaving: bool = false
var _arena_entered: bool = false
var _guards_defeated: int = 0
var _gold_defeated: bool = false
var _cyan_defeated: bool = false
var _gold_teaching_pending: bool = false
var _arena_intro_left: float = 0.0
var _checkpoint_active: bool = false
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
var _last_bridge_sound_ms: int = -1000
## X where the current fall recovery started.  It decides whether a fall is a
## bridge-section fall (return to the bridge head) or a corridor fall (start).
var _fall_origin_x: float = 0.0
var _edge_hints_shown: Dictionary = {}
var _edge_hint_count: int = 0

var _recovery_active: bool = false
var _recovery_phase: RecoveryPhase = RecoveryPhase.NONE
var _recovery_kind: String = ""
var _recovery_alpha: float = 0.0
var _recovery_elapsed: float = 0.0
var _recovery_applying: bool = false
var _intro_guide: DlcGuide = null
var _mechanic_popup: MechanicPopup = null
var _charge_tip_pending: bool = false
var _core_tip_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10
	for node: Node in [
		$Background, $Terrain, $Decorations, $Player, $GuardGold, $GuardCyan,
		$InversionA, $InversionB, $BridgeA, $BridgeB, $BridgeC,
		$WispA, $WispB, $WispC, $WispD, $RiftCheckpoint, $FinishPoint,
	]:
		if node != null:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE
	$HUD.process_mode = Node.PROCESS_MODE_ALWAYS

	_wisps = [$WispA, $WispB, $WispC, $WispD]

	_player.allow_self_reset = false
	_player.set_world_bounds(0.0, WORLD_RIGHT)
	_player.set_kill_y(KILL_Y)
	_player.set_spawn_point(START_SPAWN)
	_player.set_recovery_intercept_enabled(true)
	_player.reset_to_spawn("level_start", false)
	# The chapter starts in 辉相 so InversionA@160 has real work to do; the two
	# gates then each require one Q press instead of auto-passing.
	_player.set_polarity_state(true)
	_player.global_position = START_SPAWN
	_player.velocity = Vector2.ZERO
	_player.polarity_changed.connect(_on_player_polarity_changed)
	_player.attack_hit_window.connect(_on_player_attack_hit_window)
	_player.attack_started.connect(_on_player_attack_started)
	_player.recovery_transition_requested.connect(_on_player_recovery_transition_requested)
	_last_polarity_toggles = _player.get_polarity_toggle_count()

	_field_a.set_player_node(_player)
	_field_b.set_player_node(_player)
	_field_a.field_triggered.connect(_on_field_triggered)
	_field_b.field_triggered.connect(_on_field_triggered)

	_bridge_a.set_player_node(_player)
	_bridge_b.set_player_node(_player)
	_bridge_c.set_player_node(_player)
	_bridge_a.solidity_changed.connect(_on_bridge_solidity_changed)
	_bridge_b.solidity_changed.connect(_on_bridge_solidity_changed)
	_bridge_c.solidity_changed.connect(_on_bridge_solidity_changed)

	_guard_gold.set_player_target(_player)
	_guard_cyan.set_player_target(_player)
	# keep_teaching = true: the guards' own approved teaching contract makes
	# GRAVITY_CHARGE their first action.  The old false value was the actual
	# reason neither guard ever exposed a weakpoint in real play.
	_guard_gold.reset_state(GUARD_GOLD_SPAWN, true, true)
	_guard_cyan.reset_state(GUARD_CYAN_SPAWN, false, true)
	_guard_gold.set_suspended(true)
	_guard_cyan.set_suspended(true)
	_player.set_strike_source(_guard_gold)
	_connect_guard(_guard_gold)
	_connect_guard(_guard_cyan)
	_cue.configure(_player, [_guard_gold, _guard_cyan])

	for wisp: RiftPolarityWisp in _wisps:
		wisp.defeated.connect(_on_wisp_defeated)

	_checkpoint.checkpoint_entered.connect(_on_checkpoint_entered)

	_hud.resume_requested.connect(_on_hud_resume_requested)
	_hud.restart_requested.connect(_restart_chapter)
	_hud.title_requested.connect(_on_hud_title_requested)
	_hud.quit_requested.connect(_on_hud_quit_requested)
	_hud.set_polarity(true)
	_hud.set_objective("目标：穿过反转回廊")
	_hud.show_completion(false, 0.0)
	_hud.show_pause(false)
	_hud.set_recovery_alpha(0.0)
	_update_finish_marker()

	MechanicPopup.register_tips(RIFT_TIPS, MECHANIC_DEMO_DIR)
	_setup_mechanic_popup()

	_camera.reset_smoothing()
	_elapsed = 0.0
	LEVEL_FLOW.release_one_shot_actions()
	_player.begin_input_override()
	_guard_ticks = 3
	if show_intro_guide:
		call_deferred("_open_intro_guide")
	else:
		_ambience.play(true)


## Called once per scene load.  Tests set show_intro_guide = false before
## add_child(), so their input routes never meet a paused tree.
func _open_intro_guide() -> void:
	if not show_intro_guide or _completed or _scene_leaving:
		return
	if _intro_guide != null and is_instance_valid(_intro_guide):
		return
	_intro_guide = RIFT_GUIDE_SCRIPT.new() as DlcGuide
	if _intro_guide == null:
		_ambience.play(true)
		return
	add_child(_intro_guide)
	_intro_guide.closed.connect(_on_intro_guide_closed)
	_intro_guide.configure("rift", self)
	_intro_guide.open_guide()


func _on_intro_guide_closed(_kind: String) -> void:
	_attack_key_down = false
	_player.begin_input_override()
	_guard_ticks = 3
	# Held back while the guide covered the screen; starts with play.
	_ambience.play(true)


## Teaching layer only: one shared popup, same scene and input behaviour as the
## base levels.  It owns no gameplay state and is never a gate.
func _setup_mechanic_popup() -> void:
	_mechanic_popup = MECHANIC_POPUP_SCENE.instantiate() as MechanicPopup
	_mechanic_popup.name = "MechanicPopup"
	_mechanic_popup.level_node = self
	add_child(_mechanic_popup)


## A request is retried on later physics ticks while the chapter is in a state
## that must not be interrupted (guide, pause, recovery, opening, leaving).
func _tick_mechanic_popups() -> void:
	if _mechanic_popup == null:
		return
	if _charge_tip_pending:
		if MechanicTips.has_seen("rift_charge_tip"):
			_charge_tip_pending = false
		elif _request_mechanic_tip("rift_charge_tip"):
			_charge_tip_pending = false
	if _core_tip_pending:
		if MechanicTips.has_seen("rift_core_tip"):
			_core_tip_pending = false
		elif _request_mechanic_tip("rift_core_tip"):
			_core_tip_pending = false


func _request_mechanic_tip(id: String) -> bool:
	if _mechanic_popup == null or _mechanic_popup.is_open():
		return false
	if is_mechanic_popup_blocked():
		return false
	_mechanic_popup.request(id)
	return _mechanic_popup.is_open() or MechanicTips.has_seen(id)


## The shared popup must never open over the guide, the pause page, the
## completion page, a failure fade, the arena opening or a scene hand-off.
func is_mechanic_popup_blocked() -> bool:
	if get_tree().paused:
		return true
	if _completed or _scene_leaving or _recovery_active or _retry_pending:
		return true
	if _pause_open:
		return true
	if _guard_ticks > 0 or _arena_intro_left > 0.0:
		return true
	if _intro_guide != null and is_instance_valid(_intro_guide):
		if _intro_guide.is_open():
			return true
	return false


func _exit_tree() -> void:
	if _ambience != null:
		_ambience.stop(0.0)
	if _audio != null:
		_audio.stop_all()
	for wisp: RiftPolarityWisp in _wisps:
		if wisp != null and is_instance_valid(wisp):
			wisp.set_hum_enabled(false)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


func _connect_guard(guard: L3Guard) -> void:
	guard.player_struck.connect(_on_guard_player_struck)
	guard.true_damage_dealt.connect(_on_guard_true_damage.bind(guard))
	guard.shattered.connect(_on_guard_shattered.bind(guard))
	guard.defeated.connect(_on_guard_defeated.bind(guard))
	guard.charge_started.connect(_on_guard_charge_started.bind(guard))
	guard.slam_contact.connect(_on_guard_slam_contact.bind(guard))
	guard.gravity_release.connect(_on_guard_gravity_release.bind(guard))
	guard.reassembly_started.connect(_on_guard_reassembly_started.bind(guard))


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

	if _arena_intro_left > 0.0:
		_arena_intro_left = maxf(_arena_intro_left - delta, 0.0)
		if _arena_intro_left <= 0.0:
			_wake_gold_guard()

	_apply_guard_force()
	_update_strike_source()
	_tick_gold_teaching()
	_tick_bridge_edge_hints()

	if not _arena_entered and _player.global_position.x >= ARENA_ENTER_X:
		_arena_entered = true
		_arena_intro_left = ARENA_INTRO_TIME
		# Only the gold guard is introduced first; the cyan guard stays asleep
		# until the gold one is defeated, so the first fight is readable.
		_guard_gold.set_suspended(true)
		_guard_cyan.set_suspended(true)
		_gold_teaching_pending = false
		_hud.show_event("金守卫先苏醒 · 青守卫待机", 2.2)
		DemoAudio.play_record_save()
	_update_objective()
	if _guards_defeated >= 2 and not _completed:
		_check_finish()
	# Open at the end of the tick so the popup freezes a settled frame rather
	# than interrupting the guard force sample already in progress.
	_tick_mechanic_popups()


func _process(delta: float) -> void:
	if get_tree().paused or _scene_leaving:
		return
	if not _completed:
		_elapsed += delta
	_advance_recovery(delta)
	if _finish_core != null:
		_finish_time += delta
		_finish_core.frame = int(_finish_time * 10.0) % 12
	# The four hums only run close to the player, so an idle room is quiet.
	# They also stay off during the recovery black-out (the old code re-enabled
	# them on the very next frame) and on the completion page.
	for wisp: RiftPolarityWisp in _wisps:
		if wisp == null or not is_instance_valid(wisp):
			continue
		var near: bool = absf(wisp.global_position.x - _player.global_position.x) < 250.0
		wisp.set_hum_enabled(
			near and wisp.is_alive() and not _completed and not _recovery_active
		)


## Both guards are fixed-field providers exactly like level 03.  Before this
## the chapter drew the charge field but never fed it to the player, so an
## opposite-phase body was not pulled into the 36 px J reach and a same-phase
## body was not pushed away.  This only reads the guard's existing contract.
func _apply_guard_force() -> void:
	if _player == null:
		return
	var player_center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
	var total: Vector2 = Vector2.ZERO
	for guard: L3Guard in [_guard_gold, _guard_cyan]:
		if guard == null or not is_instance_valid(guard):
			continue
		var sample: Dictionary = guard.sample_player_force(
			player_center, _player.is_positive(), _player.get_rid()
		)
		var acceleration: Vector2 = sample.get("acceleration", Vector2.ZERO)
		total += acceleration
	if total.is_zero_approx():
		_player.clear_external_force()
	else:
		_player.apply_external_force(total)


## Real J presses turn toward the nearest live guard in the arena.  With two
## targets a player who just stepped away can still face the old direction and
## snapshot a miss; only facing changes here.
func _face_nearest_guard_on_attack() -> void:
	if not _arena_entered:
		return
	var nearest: L3Guard = null
	var best_dx: float = INF
	for guard: L3Guard in [_guard_gold, _guard_cyan]:
		if guard == null or not is_instance_valid(guard) or guard.is_defeated():
			continue
		var dx: float = guard.global_position.x - _player.global_position.x
		if absf(dx) < best_dx:
			best_dx = absf(dx)
			nearest = guard
	if nearest != null and best_dx <= AUTO_FACE_RANGE:
		_player.face_direction(1 if nearest.global_position.x >= _player.global_position.x else -1)


func _update_strike_source() -> void:
	# One shared player has one knockback-source hint.  With two guards the
	# nearest live one is the honest choice, so a hit from the cyan guard never
	# pushes the body along the gold guard's facing.
	var source: L3Guard = _guard_gold
	if _gold_defeated and not _cyan_defeated:
		source = _guard_cyan
	elif not _gold_defeated and not _cyan_defeated:
		var gold_dx: float = absf(_guard_gold.global_position.x - _player.global_position.x)
		var cyan_dx: float = absf(_guard_cyan.global_position.x - _player.global_position.x)
		if cyan_dx < gold_dx:
			source = _guard_cyan
	_player.set_strike_source(source)


func _update_objective(force: bool = false) -> void:
	var text: String
	var key: String
	if _completed:
		text = "目标：裂隙封闭"
		key = "done"
	elif _guards_defeated >= 2:
		text = "目标：触碰裂隙核心"
		key = "finish"
	elif _arena_entered:
		if not _gold_defeated:
			text = "目标：先击败金守卫（蓄力时异相 J）"
			key = "arena_gold"
		else:
			text = "目标：再击败青守卫（%d / 2）" % _guards_defeated
			key = "arena_cyan"
	elif _checkpoint_active and _player.global_position.x >= 976.0:
		# The bridge section is behind the player; do not keep the old
		# "record the checkpoint" line next to the already-recorded event.
		text = "目标：先击败金守卫（蓄力时异相 J）"
		key = "checkpoint_done"
	elif _player.global_position.x >= 976.0:
		text = "目标：沿高台前进，记录检查点"
		key = "terrace"
	elif _player.global_position.x >= 560.0:
		# No Q instruction here: the fall / edge event lines own that hint, so
		# the persistent objective and the transient line do not repeat it.
		text = "目标：跨过三相性光桥"
		key = "bridge"
	elif _player.global_position.x >= 150.0:
		text = "目标：让紫色光幕翻相，穿过极性门"
		key = "corridor"
	else:
		text = "目标：穿过反转回廊"
		key = "start"
	if key == _objective_key and not force:
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
		_restart_chapter()
		get_viewport().set_input_as_handled()
		return
	if _scene_leaving:
		return
	if _pause_open:
		return
	if _completed:
		if key_event.pressed and not key_event.echo:
			if code == int(KEY_E):
				get_viewport().set_input_as_handled()
				_return_to_title()
			elif code == int(KEY_ENTER) or code == int(KEY_KP_ENTER):
				# The focused row wins: Down to 重玩本章 + Enter replays the
				# chapter.  With either no focus or 返回主界面 focused, Enter is
				# the retained shortcut back to the title.
				if get_viewport().gui_get_focus_owner() == _hud.get_completion_replay_button():
					return
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
	if _scene_leaving or _recovery_active:
		return
	if event.is_action_pressed(&"pause"):
		# Esc also opens the pause page over the completion page, matching its
		# own footnote; resume returns to the completion page unchanged.
		_set_paused(not _pause_open)
		get_viewport().set_input_as_handled()


func _on_hud_resume_requested() -> void:
	_set_paused(false)


func _on_hud_title_requested() -> void:
	_return_to_title()


func _on_hud_quit_requested() -> void:
	if _scene_leaving:
		return
	_scene_leaving = true
	get_tree().paused = false
	_ambience.stop(0.0)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().quit()


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
		if _arena_entered:
			_guard_gold.set_suspended(true)
			_guard_cyan.set_suspended(true)
		_ambience.set_paused(true)
		get_tree().paused = true
		return
	get_tree().paused = false
	_ambience.set_paused(false)
	LEVEL_FLOW.release_one_shot_actions()
	_player.clear_input_buffers()
	# A pause during the 0.8 s intro must not shorten or skip it; the intro
	# timer resumes with the tree and wakes the gold guard itself.
	if _arena_entered and not _completed and _arena_intro_left <= 0.0:
		_resume_guards_after_pause()


# --- room 1: inversion / gates / wisps -------------------------------------

func _on_field_triggered(positive: bool) -> void:
	_audio.play_inversion()
	_hud.show_event(
		"相性反转 · " + ("辉相" if positive else "澜相"), 1.6
	)


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
	for wisp: RiftPolarityWisp in _wisps:
		if wisp != null and is_instance_valid(wisp) and wisp.is_alive():
			if wisp.try_player_hit(_player, facing, positive, swing_id):
				_hud.show_event("光灵熄灭", 1.0)
	var gold_result: Dictionary = _guard_gold.receive_player_hit(
		_player, facing, positive, swing_id
	)
	var cyan_result: Dictionary = _guard_cyan.receive_player_hit(
		_player, facing, positive, swing_id
	)
	_show_attack_result_hint(gold_result, cyan_result)


## Pick the nearest live guard's non-lethal result and explain it in one short
## event line.  A real true-damage hit keeps the guard's own "剩余 N" line.
func _show_attack_result_hint(gold_result: Dictionary, cyan_result: Dictionary) -> void:
	if (
		bool(gold_result.get("true_damage", false))
		or bool(cyan_result.get("true_damage", false))
	):
		return
	var gold_dx: float = absf(_guard_gold.global_position.x - _player.global_position.x)
	var cyan_dx: float = absf(_guard_cyan.global_position.x - _player.global_position.x)
	var result: Dictionary = gold_result if gold_dx <= cyan_dx else cyan_result
	var nearest: L3Guard = _guard_gold if gold_dx <= cyan_dx else _guard_cyan
	var dx: float = minf(gold_dx, cyan_dx)
	if dx > 220.0:
		return
	var code: String = String(result.get("code", ""))
	if code == "INACTIVE":
		if nearest != null and is_instance_valid(nearest) and nearest.is_suspended():
			# The persistent objective already carries the gold-first rule;
			# this line only explains the guard's current state.
			_hud.show_event("%s待机 · 稍后苏醒" % _guard_label(nearest), 1.5)
		return
	match code:
		"SHELL_SHATTER":
			_hud.show_event("仅碎壳 · 蓄力时异相 J 才是真伤", 1.5)
		"SAME_PHASE":
			_hud.show_event("同相无效 · Q 切异相，蓄力时再 J", 1.5)
		"MISS_RANGE":
			_hud.show_event("距离不够 · 贴近到 36px 内再 J", 1.4)
		"MISS_BEHIND":
			_hud.show_event("转身面向守卫再按 J", 1.4)
		"BLOCKED":
			_hud.show_event("守卫被石柱挡住 · 换个角度", 1.4)
		_:
			pass


func _on_wisp_defeated(_wisp: RiftPolarityWisp) -> void:
	var alive: int = 0
	for wisp: RiftPolarityWisp in _wisps:
		if wisp != null and is_instance_valid(wisp) and wisp.is_alive():
			alive += 1
	if alive > 0:
		_hud.show_event("光灵熄灭 · 剩余 %d" % alive, 1.2)


# --- room 2: bridges / checkpoint ------------------------------------------

func _on_bridge_solidity_changed(solid: bool) -> void:
	# One Q press changes all three decks at once: coalesce the chime so the
	# two gold decks and the cyan deck do not stack into a louder cue.
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_bridge_sound_ms < 90:
		return
	_last_bridge_sound_ms = now_ms
	_audio.play_bridge(solid)


## Optional readability aid, once per deck: standing at a gap edge while the
## next deck is ghosted earns one short HUD line.  It never blocks input and
## never opens the shared mechanic popup.  The deck itself stays the only
## source of truth for solidity.
func _tick_bridge_edge_hints() -> void:
	if _completed or _scene_leaving or _recovery_active or _retry_pending:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.is_on_floor() or absf(_player.global_position.y - 280.0) > 3.0:
		return
	var x: float = _player.global_position.x
	for bridge: RiftPhaseBridge in [_bridge_a, _bridge_b, _bridge_c]:
		if bridge == null or not is_instance_valid(bridge) or bridge.is_solid():
			continue
		var key: StringName = bridge.name
		if _edge_hints_shown.has(key):
			continue
		var rect: Rect2 = bridge.get_bridge_rect()
		var near_start: bool = x >= rect.position.x - 18.0 \
			and x <= rect.position.x + 2.0
		var near_end: bool = x >= rect.end.x - 2.0 \
			and x <= rect.end.x + 18.0
		if near_start or near_end:
			_edge_hints_shown[key] = true
			_edge_hint_count += 1
			_hud.show_event(BRIDGE_EDGE_LINE, 1.5)
			return


func _on_checkpoint_entered(checkpoint: LevelCheckpoint) -> void:
	if _checkpoint_active:
		return
	_checkpoint_active = true
	checkpoint.set_activated(true)
	_hud.show_event("检查点已记录 · 光桥之后", 1.8)
	DemoAudio.play_record_save()
	# Refresh immediately so the old "record the checkpoint" goal does not sit
	# under the "checkpoint recorded" event line.
	_update_objective(true)


# --- room 3: twin guards ---------------------------------------------------

## Gold first: after the 0.8 s arena hover only the gold guard wakes.  Its
## reset_state(keep_teaching = true) already queued GRAVITY as the first action;
## the queued teaching charge below fires as soon as the player is close enough.
func _wake_gold_guard() -> void:
	if _completed or _scene_leaving or _recovery_active:
		return
	if not _arena_entered or _gold_defeated:
		return
	_guard_gold.set_suspended(false)
	_gold_teaching_pending = true
	_charge_tip_pending = true


func _wake_cyan_guard() -> void:
	if _completed or _scene_leaving or _recovery_active:
		return
	if not _arena_entered or _cyan_defeated:
		return
	_guard_cyan.set_suspended(false)


## The guard's own force_gravity_first() requires teaching_seen and ACTIVE; it
## starts the already-approved GRAVITY_CHARGE (not a scripted hit).  If the
## player is far, the action stays queued, and the guard's own 100 px trigger
## would fire first anyway.
func _tick_gold_teaching() -> void:
	if not _gold_teaching_pending:
		return
	if _gold_defeated or not is_instance_valid(_guard_gold) or _guard_gold.is_defeated():
		_gold_teaching_pending = false
		return
	if _guard_gold.is_suspended():
		return
	if _guard_gold.get_state_name() == "GRAVITY_CHARGE":
		_gold_teaching_pending = false
		return
	var dx: float = absf(_player.global_position.x - _guard_gold.global_position.x)
	if dx <= TEACHING_TRIGGER_RANGE:
		_gold_teaching_pending = false
		_guard_gold.force_gravity_first()


## After a pause, only the guard that is allowed to be awake resumes: gold
## while it lives, cyan only after the gold one is down.
func _resume_guards_after_pause() -> void:
	if not _arena_entered:
		return
	if not _gold_defeated:
		_guard_gold.set_suspended(false)
	elif not _cyan_defeated:
		_guard_cyan.set_suspended(false)


func _on_guard_player_struck(_facing: int) -> void:
	if _completed or _scene_leaving or _recovery_active or _retry_pending:
		return
	_player_hits += 1
	DemoAudio.play_player_hurt()
	_hud.show_event("受击 %d / 2" % _player_hits, 1.1)
	if _player_hits >= 2:
		_retry_pending = true
		_retry_pending_left = maxf(_player.get_hit_reaction_remaining(), 0.0)


func _on_guard_true_damage(_taken: int, remaining: int, guard: L3Guard) -> void:
	_hud.show_event(
		"%s · 剩余 %d" % [_guard_label(guard), remaining], 1.2
	)


func _on_guard_shattered(guard: L3Guard) -> void:
	DemoAudio.play_shell_shatter()
	_hud.show_event("%s外壳碎裂" % _guard_label(guard), 1.0)


func _on_guard_charge_started(_positive: bool, guard: L3Guard) -> void:
	# The objective already says "蓄力时异相 J"; keep this line about the
	# guard's state only.
	_hud.show_event("%s蓄力中 · 弱点暴露" % _guard_label(guard), 1.4)
	# Fallback for the gold guard's very first charge if the opening-end
	# request could not open (for example the player paused on that frame).
	if guard == _guard_gold and not MechanicTips.has_seen("rift_charge_tip"):
		_charge_tip_pending = true


func _on_guard_slam_contact(_facing: int, _guard: L3Guard) -> void:
	# The twin room had no impact cue at all; the approved level-03 slam sound
	# now plays through the DLC-local player (coalesced across both guards).
	_audio.play_slam()


func _on_guard_gravity_release(_positive: bool, _guard: L3Guard) -> void:
	_audio.play_slam()


func _on_guard_reassembly_started(_guard: L3Guard) -> void:
	DemoAudio.play_respawn()


func _on_guard_defeated(guard: L3Guard) -> void:
	if _completed or _scene_leaving:
		return
	if guard == _guard_gold:
		if _gold_defeated:
			return
		_gold_defeated = true
		_guard_gold.set_suspended(true)
	elif guard == _guard_cyan:
		if _cyan_defeated:
			return
		_cyan_defeated = true
		_guard_cyan.set_suspended(true)
	else:
		return
	_guards_defeated += 1
	_player_hits = 0
	_retry_pending = false
	DemoAudio.play_record_save()
	if _guards_defeated >= 2:
		# One merged line: the old code wrote "已倒下 · 2 / 2" and immediately
		# replaced it with the core line, so the final count was never readable.
		_hud.show_event("双生守卫已倒下 · 2 / 2 · 裂隙核心开启", 2.4)
		_audio.play_bridge(true)
		_core_tip_pending = true
	elif guard == _guard_gold:
		# Gold first: its fall is what releases the cyan guard.
		_gold_teaching_pending = false
		_wake_cyan_guard()
		_hud.show_event("金守卫已倒下 · 1 / 2 · 青守卫苏醒", 2.4)
	else:
		_hud.show_event(
			"%s已倒下 · %d / 2" % [_guard_label(guard), _guards_defeated], 2.0
		)
	_update_finish_marker()
	_update_objective(true)


func _guard_label(guard: L3Guard) -> String:
	return "金守卫" if guard == _guard_gold else "青守卫"


# --- recovery transition (same approved timing as level 03) ----------------

func _on_player_recovery_transition_requested(reason: String) -> void:
	if reason != "fall" or _recovery_active or _completed or _scene_leaving:
		return
	_fall_origin_x = _player.global_position.x
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
	_gold_teaching_pending = false
	_charge_tip_pending = false
	_core_tip_pending = false
	DemoAudio.play_failure()
	_hud.set_recovery_alpha(0.0)
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	_player.cancel_attack()
	_player.begin_recovery_hold()
	_player.clear_external_force()
	_arena_intro_left = 0.0
	_guard_gold.set_suspended(true)
	_guard_cyan.set_suspended(true)
	for wisp: RiftPolarityWisp in _wisps:
		if wisp != null and is_instance_valid(wisp):
			wisp.set_hum_enabled(false)


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
		var bridge_fall: bool = _fall_origin_x >= BRIDGE_SECTION_LEFT \
			and _fall_origin_x < ARENA_ENTER_X
		if _checkpoint_active:
			_reset_player_at(CHECKPOINT_POSITION)
		elif bridge_fall:
			# No PitFloor under the gaps: the bridge section retries from its
			# own head instead of sending the player back to x = 40.
			_reset_player_at(BRIDGE_HEAD_SPAWN)
		else:
			_reset_player_at(START_SPAWN, true)
		if bridge_fall:
			_hud.show_event(BRIDGE_FALL_LINE, 3.0)
	else:
		_retry_combat()
	_player.begin_recovery_hold()
	_guard_gold.set_suspended(true)
	_guard_cyan.set_suspended(true)
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
	# A retry always restarts the approved 0.8 s arena opening.  The timer was
	# written at the black frame; physics stays blocked while recovery is active,
	# so this frame must not wake the guards early.
	if (
		_arena_entered and not _completed and not _scene_leaving
		and _arena_intro_left <= 0.0
	):
		if _gold_defeated:
			_wake_cyan_guard()
		else:
			_wake_gold_guard()


## A failure or a fall inside the arena returns the whole twin fight to its
## opening state: both guards are rebuilt at full cells at their own spawns,
## even when one had already been defeated.  R remains the full chapter restart.
func _retry_combat() -> void:
	_resolved_swings.clear()
	_player_hits = 0
	_retry_pending = false
	_retry_pending_left = 0.0
	_gold_defeated = false
	_cyan_defeated = false
	_guards_defeated = 0
	_charge_tip_pending = false
	_core_tip_pending = false
	_guard_gold.reset_state(GUARD_GOLD_SPAWN, true, true)
	_guard_gold.set_player_target(_player)
	_guard_gold.set_suspended(true)
	_guard_cyan.reset_state(GUARD_CYAN_SPAWN, false, true)
	_guard_cyan.set_player_target(_player)
	_guard_cyan.set_suspended(true)
	# Written at black; the first physics tick after the fade finishes starts
	# counting it down, then the gold guard wakes and re-runs its teaching
	# GRAVITY_CHARGE (keep_teaching = true above).
	_arena_intro_left = ARENA_INTRO_TIME
	_gold_teaching_pending = true
	_reset_player_at(ARENA_SPAWN)
	_update_finish_marker()
	_update_objective(true)
	_hud.show_event("失败 · 引力把你甩回入口 · 先打金守卫", 2.0)


func _reset_player_at(point: Vector2, positive: bool = false) -> void:
	_player.set_spawn_point(point)
	_player.reset_to_spawn("combat_retry", true)
	_player.set_polarity_state(positive)
	_player.global_position = point
	_player.velocity = Vector2.ZERO
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.face_direction(1)
	_camera.reset_smoothing()
	_hud.set_polarity(positive)


# --- finish / completion ---------------------------------------------------

func _check_finish() -> void:
	if _completed:
		return
	var offset: float = absf(_player.global_position.x - FINISH_POSITION.x)
	if offset > FINISH_RANGE:
		return
	if _player.global_position.y < 250.0:
		return
	_complete_chapter()


func _update_finish_marker() -> void:
	if _finish_core == null:
		return
	if _guards_defeated >= 2:
		_finish_core.modulate = Color(1.0, 0.92, 0.72, 1.0)
	else:
		_finish_core.modulate = Color(0.42, 0.52, 0.56, 0.62)


func _complete_chapter() -> void:
	if _completed or _scene_leaving:
		return
	_completed = true
	_retry_pending = false
	_arena_intro_left = 0.0
	_gold_teaching_pending = false
	_charge_tip_pending = false
	_core_tip_pending = false
	_player_hits = 0
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.lock_completion_input()
	_guard_gold.set_suspended(true)
	_guard_cyan.set_suspended(true)
	for wisp: RiftPolarityWisp in _wisps:
		if wisp != null and is_instance_valid(wisp):
			wisp.set_hum_enabled(false)
	_hud.show_pause(false)
	_hud.show_completion(true, _elapsed)
	_hud.set_objective("目标：裂隙封闭")
	_ambience.stop(DlcChapterAmbience.STOP_FADE_SECONDS)
	_audio.play_complete()
	LEVEL_FLOW.release_one_shot_actions()
	level_completed.emit()


func _return_to_title() -> void:
	if _scene_leaving:
		return
	get_tree().paused = false
	_pause_open = false
	_scene_leaving = true
	_charge_tip_pending = false
	_core_tip_pending = false
	_hud.show_pause(false)
	_hud.show_completion(false, _elapsed)
	_ambience.stop(0.0)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	LEVEL_FLOW.return_to_title(get_tree())


# --- restart / accessors ---------------------------------------------------

func _restart_chapter() -> void:
	if _scene_leaving:
		return
	get_tree().paused = false
	_pause_open = false
	_completed = false
	_arena_entered = false
	_guards_defeated = 0
	_gold_defeated = false
	_cyan_defeated = false
	_arena_intro_left = 0.0
	_checkpoint_active = false
	_retry_pending = false
	_retry_pending_left = 0.0
	_recovery_active = false
	_recovery_phase = RecoveryPhase.NONE
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_recovery_kind = ""
	_resolved_swings.clear()
	_player_hits = 0
	_charge_tip_pending = false
	_core_tip_pending = false
	_elapsed = 0.0
	_finish_time = 0.0
	_objective_key = ""
	_attack_key_down = false
	_fall_origin_x = 0.0
	_edge_hints_shown.clear()
	_edge_hint_count = 0
	_last_polarity_toggles = _player.get_polarity_toggle_count()
	_audio.stop_all()
	_ambience.play(true)
	_hud.set_recovery_alpha(0.0)
	_hud.show_completion(false, 0.0)
	_hud.show_pause(false)
	_hud.set_objective("目标：穿过反转回廊")
	_hud.set_polarity(true)
	_player.end_recovery_hold()
	_player.unlock_completion_input()
	_reset_player_at(START_SPAWN, true)
	_guard_gold.reset_state(GUARD_GOLD_SPAWN, true, true)
	_guard_gold.set_player_target(_player)
	_guard_gold.set_suspended(true)
	_guard_cyan.reset_state(GUARD_CYAN_SPAWN, false, true)
	_guard_cyan.set_player_target(_player)
	_guard_cyan.set_suspended(true)
	_gold_teaching_pending = false
	for wisp: RiftPolarityWisp in _wisps:
		if wisp != null and is_instance_valid(wisp):
			wisp.respawn()
	_field_a.reset_inside_state()
	_field_b.reset_inside_state()
	_checkpoint.set_activated(false)
	_update_finish_marker()
	LEVEL_FLOW.release_one_shot_actions()
	_player.begin_input_override()
	_guard_ticks = 3
	_hud.show_event("裂隙工坊已重新开始", 1.5)


func get_player() -> L3Player:
	return _player


func get_mechanic_popup() -> MechanicPopup:
	return _mechanic_popup


func get_guard_gold() -> L3Guard:
	return _guard_gold


func get_guard_cyan() -> L3Guard:
	return _guard_cyan


func get_field_a() -> RiftInversionField:
	return _field_a


func get_field_b() -> RiftInversionField:
	return _field_b


func get_bridge_a() -> RiftPhaseBridge:
	return _bridge_a


func get_bridge_b() -> RiftPhaseBridge:
	return _bridge_b


func get_bridge_c() -> RiftPhaseBridge:
	return _bridge_c


func get_wisps() -> Array[RiftPolarityWisp]:
	return _wisps


func get_hud() -> RiftWorkshopHUD:
	return _hud


func get_ambience() -> DlcChapterAmbience:
	return _ambience


func get_guard_cue() -> RiftGuardCue:
	return _cue


func is_gold_teaching_pending() -> bool:
	return _gold_teaching_pending


func get_teaching_trigger_range() -> float:
	return TEACHING_TRIGGER_RANGE


func get_intro_guide() -> DlcGuide:
	return _intro_guide


func get_camera() -> Camera2D:
	return _camera


func get_checkpoint() -> LevelCheckpoint:
	return _checkpoint


func get_finish_position() -> Vector2:
	return FINISH_POSITION


func get_start_spawn() -> Vector2:
	return START_SPAWN


func get_bridge_head_spawn() -> Vector2:
	return BRIDGE_HEAD_SPAWN


## Read-only for tests: X where the last fall transition began.
func get_last_fall_origin_x() -> float:
	return _fall_origin_x


func get_edge_hint_count() -> int:
	return _edge_hint_count


func get_arena_spawn() -> Vector2:
	return ARENA_SPAWN


func get_checkpoint_position() -> Vector2:
	return CHECKPOINT_POSITION


func get_elapsed_seconds() -> float:
	return _elapsed


func is_completed() -> bool:
	return _completed


func is_both_defeated() -> bool:
	return _guards_defeated >= 2


func get_guards_defeated() -> int:
	return _guards_defeated


func is_gold_defeated() -> bool:
	return _gold_defeated


func is_cyan_defeated() -> bool:
	return _cyan_defeated


func is_arena_entered() -> bool:
	return _arena_entered


## Remaining opening hover after arena entry (0 when the guards are live).
func get_arena_intro_left() -> float:
	return _arena_intro_left


func is_arena_intro_active() -> bool:
	return _arena_intro_left > 0.0


func is_checkpoint_active() -> bool:
	return _checkpoint_active


func is_pause_open() -> bool:
	return _pause_open


func is_recovery_active() -> bool:
	return _recovery_active


func get_player_hits() -> int:
	return _player_hits


func get_finish_sprite() -> Sprite2D:
	return _finish_core
