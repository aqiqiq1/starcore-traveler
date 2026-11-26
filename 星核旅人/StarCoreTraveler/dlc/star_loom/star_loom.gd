class_name StarLoom
extends Node2D

## DLC chapter 3: 星核织机 (Star Loom), one 960 x 360 boss hall.
##
## The player enters from the left; the loom hangs in the middle/right.  Two
## gold/cyan nodes orbit the core.  Q switches the player's phase; only an
## opposite-phase J hit breaks a node or hurts the exposed core.  Both nodes
## down -> core open -> three true hits -> next stage (three stages total).
##
## The boss has three attacks, introduced by stage:
##   1. slow homing bolts      (0.70 s warning)
##   2. sweeping light band    (0.80 s warning)
##   3. summon 1-2 rift wisps  (1.00 s warning)
##
## Three accepted hits spend one of the run's three lives: the health meter
## empties, the current stage is restored at its entrance, and the life row
## drops by one.  At zero lives a game over page offers 重试本章 / 返回标题; R
## restarts the chapter and resets both lives and health.  Completion shows
## "织机停转 · 用时 mm:ss"; E / Enter returns to the title.  The exposed core is
## a 40x40 solid phase diamond and can only be hit from a jump.
##
## Reused, never modified: L3Player (J / hurt / fall), the shared DS03
## background, L3Terrain, CompactLevelHeader, the project font and palette, the
## shared DLC guide scene.  All new art and audio live in dlc/star_loom/.

signal level_completed

@export var show_intro_guide: bool = true

const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")
const DLC_GUIDE_SCENE: PackedScene = preload("res://dlc/ui/dlc_guide.tscn")
const LOOM_GUIDE_SCRIPT: Script = preload("res://dlc/star_loom/loom_guide.gd")
const MECHANIC_POPUP_SCENE: PackedScene = preload("res://scenes/ui/mechanic_popup.tscn")

## Copy source: dlc/UI_PARITY_SPEC.md section 2 (星核织机).  The body label is
## 58 px tall, so each line stays within 21 full-width characters; three lines
## are the maximum.  ASCII and digits count as half-width.  Spec lines that were
## split/shortened for width are listed in tests/README.md.
## After the two-page intro, the fire warning is the only in-chapter teaching
## window.  The entry/core lessons live in the guide pages now, so a run cannot
## repeat the same instruction in two places.
const LOOM_TIPS: Dictionary = {
	"loom_fire_tip": {
		"title": "地砖火道",
		"body": "织机把城内火道接进地砖，喷焰前砖面先亮。\n看到亮砖就离开，横扫光带跳过去。",
		"key": "先离开亮起的砖，再跳过横扫光带。",
		"demo": "loom_fire",
	},
}
const TIP_FIRE: String = "loom_fire_tip"

const WORLD_LEFT: float = 0.0
const WORLD_RIGHT: float = 960.0
const FLOOR_Y: float = 320.0
const KILL_Y: float = 430.0
const START_SPAWN: Vector2 = Vector2(40.0, 320.0)
const ARENA_SPAWN: Vector2 = Vector2(420.0, 320.0)
const ARENA_ENTER_X: float = 430.0
const CORE_POSITION: Vector2 = Vector2(700.0, 244.0)
const NODE_ORBIT_RADIUS: Vector2 = Vector2(120.0, 54.0)
const SWEEP_START_X: float = 930.0
const FIRE_VENTS: Array[Vector2] = [
	Vector2(500.0, 320.0), Vector2(640.0, 320.0), Vector2(820.0, 320.0),
]
const GEAR_WARNING_POINTS: Array[Vector2] = [
	Vector2(8.0, 302.0), Vector2(952.0, 302.0),
]
const GEAR_SPAWN_LEFT: float = -28.0
const GEAR_SPAWN_RIGHT: float = 988.0
const GEAR_Y: float = 302.0
const CORE_HITS_PER_STAGE: int = 3
const MAX_STAGE: int = 3
const PLAYER_HIT_LIMIT: int = 3
## Three lives for the whole run.  A death (three accepted hits, or a fall)
## removes one and retries the current stage; the third death opens game over.
## Health is a separate three-cell meter: hits empty it, and clearing stage 1
## refills it once.
const PLAYER_LIVES: int = 3
## Chapter-level grace after an accepted hit.  The shared L3Player owns 0.6 s;
## this covers the 0.6-0.95 s window the brief asked for.
const DAMAGE_IMMUNITY_TIME: float = 0.95
const BODY_CENTER_OFFSET: Vector2 = Vector2(0.0, -15.0)
const AUTO_FACE_RANGE: float = 240.0

## Warnings are 0.15-0.20 s wider than the first pass and far above the 0.3 s
## floor.  Stage 1 only uses homing; stage 2 adds sweep + floor fire; stage 3
## adds wisps + rolling gears.
const WINDUP_HOMING: float = 0.70
const WINDUP_SWEEP: float = 0.80
const WINDUP_FIRE: float = 0.95
const WINDUP_SUMMON: float = 1.00
const WINDUP_GEAR: float = 0.90
const RECOVER_HOMING: float = 1.10
const RECOVER_SWEEP: float = 1.00
const RECOVER_FIRE: float = 1.10
const RECOVER_SUMMON: float = 1.15
const RECOVER_GEAR: float = 1.00
const IDLE_TIME: float = 0.85
const START_GRACE: float = 1.20
const STAGE_GRACE: float = 1.50

const RECOVERY_FADE_OUT_TIME: float = 0.25
const RECOVERY_BLACK_HOLD_TIME: float = 0.10
const RECOVERY_FADE_IN_TIME: float = 0.35

enum AttackState { IDLE, TELEGRAPH, RECOVER }
enum RecoveryPhase { NONE, FADE_OUT, BLACK_HOLD, FADE_IN }

@onready var _player: L3Player = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _core: LoomCore = $Boss/Core
@onready var _node_a: LoomNode = $Boss/NodeA
@onready var _node_b: LoomNode = $Boss/NodeB
@onready var _hazards: Node2D = $Hazards
@onready var _fx: LoomFx = $Fx
@onready var _hud: LoomHUD = $HUD
@onready var _audio: LoomAudio = $Audio

var _footsteps: PlayerFootstepAudio = null
var _nodes: Array[LoomNode] = []
var _bullets: Array[LoomBullet] = []
var _wisps: Array[LoomWisp] = []
var _sweep: LoomSweep = null
var _fires: Array[LoomFire] = []
var _gears: Array[LoomGear] = []
var _fire_points: Array[Vector2] = []
var _gear_points: Array[Vector2] = []
var _fire_serial: int = 0
var _intro_guide: DlcGuide = null
var _mechanic_popup: MechanicPopup = null
var _fire_tip_pending: bool = false
## The white opening flash is a once-per-run event; later exposures keep the
## body-only diamond read but do not replay the flash.
var _core_burst_played: bool = false

var _elapsed: float = 0.0
var _completed: bool = false
var _scene_leaving: bool = false
var _boss_active: bool = false
var _stage: int = 1
var _core_hits: int = 0
var _player_hits: int = 0
var _lives: int = PLAYER_LIVES
var _game_over: bool = false
var _damage_immunity_left: float = 0.0
var _stage_supply_used: bool = false
var _boss_grace: float = 0.0
var _objective_key: String = ""
var _pause_open: bool = false
var _attack_key_down: bool = false
var _resolved_swings: Dictionary = {}
var _input_ticks: int = 0
var _stage_flash: float = 0.0
var _last_polarity_toggles: int = 0

var _attack_state: AttackState = AttackState.IDLE
var _attack_kind: String = ""
var _attack_left: float = 0.0
var _telegraph_windup: float = 1.0
var _attack_cursor: int = 0
var _summon_serial: int = 0
var _homing_points: Array[Vector2] = []
var _homing_directions: Array[Vector2] = []
var _summon_points: Array[Vector2] = []
var _attacks_enabled: bool = true

var _retry_pending: bool = false
var _retry_pending_left: float = 0.0
## Set when the third stage's last true hit lands.  The completion page waits
## for the current J swing to finish before locking input: cancelling the swing
## from inside its own hit-window callback would leave the shared player's
## attack sprite applied for one more frame.
var _pending_completion: bool = false

var _recovery_active: bool = false
var _recovery_phase: RecoveryPhase = RecoveryPhase.NONE
var _recovery_alpha: float = 0.0
var _recovery_elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10
	# The shared popup table is static; registering is idempotent, so a chapter
	# restart or a test reload uses the same single loom entry.
	MechanicPopup.register_tips(LOOM_TIPS, "res://dlc/ui/demos")
	for node: Node in [
		$CityBack, $Terrain, $CityFloor, $Props, $Boss, $Boss/Core,
		$Boss/NodeA, $Boss/NodeB, $Hazards, $Player, $Fx, $CityFore,
	]:
		if node != null:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE
	$HUD.process_mode = Node.PROCESS_MODE_ALWAYS

	_nodes = [_node_a, _node_b]
	_core.configure()
	_node_a.broken.connect(_on_node_broken)
	_node_b.broken.connect(_on_node_broken)
	for node: LoomNode in _nodes:
		node.configure(CORE_POSITION, 0.0, true, NODE_ORBIT_RADIUS)
		node.set_active(false)
	_core.set_active(false)
	_fx.configure(self)

	_player.allow_self_reset = false
	_player.set_world_bounds(WORLD_LEFT, WORLD_RIGHT)
	_player.set_kill_y(KILL_Y)
	_player.set_spawn_point(START_SPAWN)
	_player.set_recovery_intercept_enabled(true)
	_player.reset_to_spawn("level_start", false)
	_player.set_polarity_state(false)
	_player.global_position = START_SPAWN
	_player.velocity = Vector2.ZERO
	_player.set_strike_source(_core)
	_player.polarity_changed.connect(_on_player_polarity_changed)
	_player.attack_started.connect(_on_player_attack_started)
	_player.attack_hit_window.connect(_on_player_attack_hit_window)
	_player.recovery_transition_requested.connect(_on_player_recovery_transition_requested)
	_last_polarity_toggles = _player.get_polarity_toggle_count()
	_setup_footsteps()

	_hud.resume_requested.connect(_on_hud_resume_requested)
	_hud.restart_requested.connect(_on_hud_restart_requested)
	_hud.title_requested.connect(_on_hud_title_requested)
	_hud.quit_requested.connect(_on_hud_quit_requested)
	_setup_mechanic_popup()
	_hud.bind_player_overhead(_player, Callable(self, "_overhead_hits_suppressed"))
	_hud.set_polarity(false)
	_hud.set_objective("目标：向右进入织机厅")
	_hud.set_boss_state(
		1, MAX_STAGE, 2, 0, CORE_HITS_PER_STAGE, false, 0,
		PLAYER_HIT_LIMIT, PLAYER_LIVES, PLAYER_LIVES
	)
	_hud.show_completion(false, 0.0)
	_hud.show_pause(false)
	_hud.show_game_over(false)
	_hud.set_recovery_alpha(0.0)
	# The intro guide pauses the tree; in a real window start the track before
	# it opens so the PROCESS_MODE_ALWAYS music really runs through the guide.
	# The headless 90-frame smoke run has no audio device, and starting an OGG
	# playback there leaves it referenced by AudioServer at forced exit, so the
	# real-window path is the one that owns this early start.
	if DisplayServer.get_name() != "headless":
		_audio.start_music()

	_camera.reset_smoothing()
	_elapsed = 0.0
	LEVEL_FLOW.release_one_shot_actions()
	_player.begin_input_override()
	_input_ticks = 3
	if show_intro_guide:
		call_deferred("_open_intro_guide")


func _exit_tree() -> void:
	if _footsteps != null and is_instance_valid(_footsteps):
		_footsteps.stop()
	if _audio != null:
		_audio.stop_all()
		_audio.shutdown()
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


## The shared footstep helper is parented to the real player.  Its gate keeps
## every menu/guide/popup/recovery/completion screen silent while normal
## walking and running still play the small stone bank.
func _setup_footsteps() -> void:
	if _footsteps != null and is_instance_valid(_footsteps):
		return
	_footsteps = PlayerFootstepAudio.new()
	_footsteps.name = "Footsteps"
	_footsteps.attach_to(_player)
	_footsteps.set_enabled_check(Callable(self, "_footsteps_allowed"))


## The health meter above the player's head is only part of normal boss
## gameplay.  It hides for every modal/transition state, including the tree
## pauses owned by the guide and teaching popup.
func _overhead_hits_suppressed() -> bool:
	if not _boss_active:
		return true
	if get_tree() == null or get_tree().paused:
		return true
	if (
		_pause_open or _game_over or _completed or _pending_completion
		or _recovery_active or _retry_pending
	):
		return true
	if _intro_guide != null and is_instance_valid(_intro_guide) and _intro_guide.is_open():
		return true
	if _mechanic_popup != null and is_instance_valid(_mechanic_popup) and _mechanic_popup.is_open():
		return true
	return false


func _footsteps_allowed() -> bool:
	if get_tree() == null or get_tree().paused:
		return false
	if (
		_completed or _pending_completion or _pause_open or _recovery_active
		or _retry_pending or _game_over
	):
		return false
	if _intro_guide != null and is_instance_valid(_intro_guide) and _intro_guide.is_open():
		return false
	if _mechanic_popup != null and is_instance_valid(_mechanic_popup) and _mechanic_popup.is_open():
		return false
	return true


## Teaching layer only: the shared MechanicPopup pauses on first contact with
## a real mechanism.  It owns no gameplay state and is never a gate.
func _setup_mechanic_popup() -> void:
	_mechanic_popup = MECHANIC_POPUP_SCENE.instantiate() as MechanicPopup
	_mechanic_popup.name = "MechanicPopup"
	_mechanic_popup.level_node = self
	add_child(_mechanic_popup)


## Retried every physics tick while a condition remains true; the popup itself
## refuses while the guide, pause page, completion, recovery or a stage switch
## owns the screen.  MechanicTips marks an id seen when it really opens, so a
## blocked attempt is not lost and a shown one never repeats.
func _tick_mechanic_popups() -> void:
	if _mechanic_popup == null or not is_instance_valid(_mechanic_popup):
		return
	if _fire_tip_pending:
		# Stay attached to the one real fire telegraph.  If another page owns
		# the screen and the warning is gone, drop the tip instead of popping it
		# later at the entrance or over a different attack.
		var same_warning: bool = (
			_attack_state == AttackState.TELEGRAPH and _attack_kind == "fire"
		)
		_fire_tip_pending = false
		if MechanicTips.has_seen(TIP_FIRE):
			return
		if not same_warning or is_mechanic_popup_blocked():
			MechanicTips.mark_seen(TIP_FIRE)
			return
		_mechanic_popup.request(TIP_FIRE)


## Same contract as level_01/02/03: the popup may not appear over the intro
## guide, the pause page, the completion page, a failure fade/retry, a stage
## switch, or a leaving scene.
func is_mechanic_popup_blocked() -> bool:
	if get_tree() == null:
		return true
	if get_tree().paused:
		return true
	if _completed or _pending_completion or _scene_leaving or _game_over:
		return true
	if _pause_open or _recovery_active or _retry_pending:
		return true
	if _stage_flash > 0.0:
		return true
	if _intro_guide != null and is_instance_valid(_intro_guide) and _intro_guide.is_open():
		return true
	return false


## Tests set show_intro_guide = false before add_child(), so their input routes
## never meet a paused tree.
func _open_intro_guide() -> void:
	if not show_intro_guide or _completed or _scene_leaving:
		return
	if _intro_guide != null and is_instance_valid(_intro_guide):
		return
	var guide: DlcGuide = DLC_GUIDE_SCENE.instantiate() as DlcGuide
	# The shared guide's page table is const, so this subclass supplies the
	# third chapter's two pages through the existing virtual `_page_data()`.
	guide.set_script(LOOM_GUIDE_SCRIPT)
	add_child(guide)
	_intro_guide = guide
	guide.closed.connect(_on_intro_guide_closed)
	guide.configure("loom", self)
	guide.open_guide()


func _on_intro_guide_closed(_kind: String) -> void:
	_attack_key_down = false
	_player.begin_input_override()
	_input_ticks = 3


# --- frame flow ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if get_tree().paused or _completed or _game_over or _scene_leaving:
		return
	_damage_immunity_left = maxf(_damage_immunity_left - delta, 0.0)
	if _recovery_active:
		return
	if _retry_pending:
		_retry_pending_left = maxf(_retry_pending_left - delta, 0.0)
		if _retry_pending_left <= 0.0:
			_retry_pending = false
			_begin_recovery("combat")
			return
	if _input_ticks > 0:
		_input_ticks -= 1
		_player.begin_input_override()
		if _input_ticks <= 0:
			_player.end_input_override()
		return

	if _pending_completion:
		# Do not cancel a swing from inside its own hit-window callback; wait
		# for the shared player to finish the animation, then show the page.
		if not _player.is_attacking():
			_pending_completion = false
			_complete_chapter()
		return

	# A blocked teaching request stays pending and retries once the guide,
	# pause page, recovery or stage switch releases the screen.
	_tick_mechanic_popups()

	if not _boss_active:
		if _player.global_position.x >= ARENA_ENTER_X:
			_start_boss()
		_update_objective()
		return

	if _boss_grace > 0.0:
		_boss_grace = maxf(_boss_grace - delta, 0.0)
	else:
		_tick_attack(delta)
	_sync_gear_warning()
	_update_objective()


func _process(delta: float) -> void:
	if get_tree().paused or _game_over or _scene_leaving:
		return
	if not _completed:
		_elapsed += delta
	_advance_recovery(delta)
	_stage_flash = maxf(_stage_flash - delta / 0.7, 0.0)
	_clean_hazard_lists()


func _clean_hazard_lists() -> void:
	for index: int in range(_bullets.size() - 1, -1, -1):
		if not is_instance_valid(_bullets[index]):
			_bullets.remove_at(index)
	for index: int in range(_wisps.size() - 1, -1, -1):
		if not is_instance_valid(_wisps[index]):
			_wisps.remove_at(index)
	for index: int in range(_fires.size() - 1, -1, -1):
		if not is_instance_valid(_fires[index]):
			_fires.remove_at(index)
	for index: int in range(_gears.size() - 1, -1, -1):
		if not is_instance_valid(_gears[index]):
			_gears.remove_at(index)
	if _sweep != null and not is_instance_valid(_sweep):
		_sweep = null


# --- boss start / stage flow ----------------------------------------------

func _start_boss() -> void:
	if _boss_active or _completed or _scene_leaving:
		return
	_boss_active = true
	_stage = 1
	_core_hits = 0
	_player_hits = 0
	_damage_immunity_left = 0.0
	_stage_supply_used = false
	_fire_serial = 0
	_retry_pending = false
	_core.configure()
	_core.set_active(true)
	_core.set_phase(true)
	_core.set_exposed(false)
	_respawn_nodes()
	_attack_state = AttackState.IDLE
	_attack_left = 1.4
	_attack_cursor = 0
	_summon_serial = 0
	_boss_grace = START_GRACE
	_audio.start_music()
	_audio.play_core_exposed()
	_hud.set_gear_warning(false, 0.0)
	_hud.show_event("星核织机启动 · 异相攻击打节点", 2.2)
	_hud.set_objective("目标：用异相攻击打掉两个节点")
	_update_hud_state()
	_core_burst_played = false


func _respawn_nodes() -> void:
	var a_positive: bool = _stage % 2 == 1
	var angle: float = 0.25 + 0.20 * float(_stage - 1)
	_node_a.configure(CORE_POSITION, angle, a_positive, NODE_ORBIT_RADIUS)
	_node_a.set_active(true)
	_node_b.configure(CORE_POSITION, angle + PI, not a_positive, NODE_ORBIT_RADIUS)
	_node_b.set_active(true)


func _on_node_broken(_node: LoomNode) -> void:
	_audio.play_node_break()
	if _nodes_alive_count() == 0 and not _core.is_exposed():
		_core.set_exposed(true)
		_audio.play_core_exposed()
		_hud.show_event("节点停转 · 核心暴露", 2.0)
		_hud.set_objective("目标：核心暴露 · 异相攻击打核心")
		# The first exposure gets one 0.3 s white flash and a few sparks; the
		# core then reads from its solid phase diamond and opened net only.
		if not _core_burst_played:
			_core_burst_played = true
			_fx.play_core_exposed_burst(_core.global_position)
	_update_hud_state()


func _resolve_core_hit(snapshot_positive: bool) -> void:
	if snapshot_positive == _core.get_phase():
		_core.flash_shield()
		_audio.play_deny()
		_hud.show_event("同相无效 · 换相成异相再打核心", 1.4)
		return
	_core_hits += 1
	_core.flash_hit()
	_audio.play_core_hit()
	# The core changes phase after every accepted hit, so Q is always the next
	# input the player must read.
	_core.set_phase(not _core.get_phase())
	if _core_hits >= CORE_HITS_PER_STAGE:
		_advance_stage()
	else:
		_hud.show_event("核心真伤 · 核心已换相", 1.6)
	_update_hud_state()


func _advance_stage() -> void:
	if _stage >= MAX_STAGE:
		_pending_completion = true
		_boss_active = false
		_clear_hazards()
		_hud.show_event("织机停转", 2.0)
		return
	if _stage < MAX_STAGE:
		_stage += 1
	_core_hits = 0
	_clear_hazards()
	_core.set_exposed(false)
	_core.set_phase(_stage % 2 == 1)
	_respawn_nodes()
	_attack_state = AttackState.IDLE
	_attack_left = 1.5
	_attack_cursor = 0
	_boss_grace = STAGE_GRACE
	_stage_flash = 1.0
	_audio.play_stage()
	_audio.play_core_exposed()
	# One-time city supply: the stage-1 clear refills the three-cell health
	# meter.  A later death retries the current stage, so this never becomes an
	# infinite mid-fight heal.
	if _stage == 2 and not _stage_supply_used:
		_stage_supply_used = true
		_player_hits = 0
		_hud.show_event("阶段推进 · 城垣补给：生命值补满", 2.4)
	else:
		_hud.show_event("阶段推进 · 节点重生", 2.0)
	_hud.set_objective("目标：用异相攻击打掉两个节点")
	_update_hud_state()


func _update_hud_state() -> void:
	if _hud == null:
		return
	_hud.set_boss_state(
		_stage, MAX_STAGE, _nodes_alive_count(), _core_hits,
		CORE_HITS_PER_STAGE, _core.is_exposed(), _player_hits, PLAYER_HIT_LIMIT,
		_lives, PLAYER_LIVES
	)


func _sync_gear_warning() -> void:
	if _hud == null:
		return
	var active: bool = _attack_state == AttackState.TELEGRAPH and _attack_kind == "gear"
	_hud.set_gear_warning(active, get_telegraph_progress() if active else 0.0)


func _update_objective(force: bool = false) -> void:
	var text: String
	var key: String
	if _completed:
		text = "目标：织机停转"
		key = "done"
	elif not _boss_active:
		text = "目标：向右进入织机厅"
		key = "enter"
	elif _core.is_exposed():
		text = "目标：核心暴露 · 异相攻击打核心"
		key = "core"
	else:
		text = "目标：用异相攻击打掉两个节点"
		key = "nodes"
	if key == _objective_key and not force:
		return
	_objective_key = key
	_hud.set_objective(text)


# --- attacks ---------------------------------------------------------------

func _tick_attack(delta: float) -> void:
	if not _attacks_enabled:
		return
	match _attack_state:
		AttackState.IDLE:
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				_begin_telegraph(_next_attack_kind())
		AttackState.TELEGRAPH:
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				_execute_attack()
				_attack_state = AttackState.RECOVER
				_attack_left = _recover_time(_attack_kind)
		AttackState.RECOVER:
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				_attack_state = AttackState.IDLE
				_attack_left = IDLE_TIME


func _next_attack_kind() -> String:
	var pool: Array = get_attack_pool()
	var kind: String = String(pool[_attack_cursor % pool.size()])
	_attack_cursor += 1
	return kind


func get_attack_pool() -> Array:
	match _stage:
		1:
			return ["homing"]
		2:
			return ["homing", "sweep", "fire"]
		_:
			return ["homing", "sweep", "fire", "summon", "gear"]


func _begin_telegraph(kind: String) -> void:
	_attack_kind = kind
	_attack_state = AttackState.TELEGRAPH
	_telegraph_windup = get_attack_windup(kind)
	_attack_left = _telegraph_windup
	_prepare_telegraph_points(kind)
	_audio.play_telegraph()
	match kind:
		"homing":
			_hud.show_event("预警 · 慢速追踪弹", 1.1)
		"sweep":
			_hud.show_event("预警 · 横扫光带 · 跳起", 1.2)
		"summon":
			_hud.show_event("预警 · 召唤裂隙浮灵", 1.4)
		"fire":
			_hud.show_event("预警 · 地砖火柱 · 离开发光地砖", 1.4)
		"gear":
			_hud.show_event("预警 · 两侧齿轮 · 跳起", 1.3)
	# Trigger 2: the first stage-2 floor-fire warning.  The popup pauses right
	# at the telegraph start, so the 0.95 s warning is not consumed while the
	# player reads it.
	if kind == "fire" and _stage == 2 and not MechanicTips.has_seen(TIP_FIRE):
		_fire_tip_pending = true
		_tick_mechanic_popups()


func _prepare_telegraph_points(kind: String) -> void:
	_homing_points.clear()
	_homing_directions.clear()
	_summon_points.clear()
	_fire_points.clear()
	_gear_points.clear()
	match kind:
		"homing":
			var player_center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
			var base: Vector2 = (player_center - CORE_POSITION)
			if base.length_squared() < 1.0:
				base = Vector2.LEFT
			base = base.normalized()
			var count: int = 2 + _stage
			for index: int in range(count):
				var spread: float = lerp(
					-0.45, 0.45, float(index) / maxf(float(count - 1), 1.0)
				)
				var direction: Vector2 = base.rotated(spread)
				_homing_directions.append(direction)
				_homing_points.append(CORE_POSITION + direction * 52.0)
		"summon":
			_summon_points.append(Vector2(548.0, 262.0))
			_summon_points.append(Vector2(852.0, 262.0))
		"fire":
			# Two of the three vents alternate, so a safe gap always remains.
			var first: int = _fire_serial % 3
			var second: int = (first + 1 + _fire_serial % 2) % 3
			if first == second:
				second = (second + 1) % 3
			_fire_points.append(FIRE_VENTS[first])
			_fire_points.append(FIRE_VENTS[second])
			_fire_serial += 1
		"gear":
			_gear_points.append(GEAR_WARNING_POINTS[0])
			_gear_points.append(GEAR_WARNING_POINTS[1])


func _execute_attack() -> void:
	match _attack_kind:
		"homing":
			_spawn_homing_bolts()
		"sweep":
			_spawn_sweep()
		"summon":
			_spawn_wisps()
		"fire":
			_spawn_fire()
		"gear":
			_spawn_gears()
		_:
			pass


func _spawn_homing_bolts() -> void:
	if _bullets.size() >= 6:
		return
	var available: int = 6 - _bullets.size()
	var count: int = mini(_homing_points.size(), available)
	for index: int in range(count):
		var bullet: LoomBullet = LoomBullet.new()
		bullet.name = "HomingBolt"
		_hazards.add_child(bullet)
		bullet.position = _homing_points[index]
		bullet.setup(_player, self, _homing_directions[index])
		_bullets.append(bullet)
	_audio.play_bullet()


func _spawn_sweep() -> void:
	var sweep: LoomSweep = LoomSweep.new()
	sweep.name = "SweepBand"
	_hazards.add_child(sweep)
	sweep.setup(_player, self, SWEEP_START_X, -1)
	_sweep = sweep
	_audio.play_sweep()


func _spawn_wisps() -> void:
	if _wisps.size() >= 3:
		return
	_summon_serial += 1
	var count: int = 1 + (1 if _summon_serial % 2 == 0 else 0)
	count = mini(count, mini(_summon_points.size(), 3 - _wisps.size()))
	for index: int in range(count):
		var wisp: LoomWisp = LoomWisp.new()
		wisp.name = "RiftWisp"
		_hazards.add_child(wisp)
		wisp.position = _summon_points[index] + Vector2(0.0, -8.0 * float(index))
		wisp.setup(_player, self)
		_wisps.append(wisp)
	_audio.play_summon()


func _spawn_fire() -> void:
	var fire: LoomFire = LoomFire.new()
	fire.name = "FloorFire"
	_hazards.add_child(fire)
	fire.setup(_player, self, _fire_points)
	_fires.append(fire)
	_audio.play_fire()


func _spawn_gears() -> void:
	if _gears.size() >= 4:
		return
	var left: LoomGear = LoomGear.new()
	left.name = "GearLeft"
	_hazards.add_child(left)
	left.setup(_player, self, GEAR_SPAWN_LEFT, 1)
	_gears.append(left)
	var right: LoomGear = LoomGear.new()
	right.name = "GearRight"
	_hazards.add_child(right)
	right.setup(_player, self, GEAR_SPAWN_RIGHT, -1)
	_gears.append(right)
	_audio.play_gear()


func get_attack_windup(kind: String) -> float:
	match kind:
		"homing":
			return WINDUP_HOMING
		"sweep":
			return WINDUP_SWEEP
		"fire":
			return WINDUP_FIRE
		"summon":
			return WINDUP_SUMMON
		"gear":
			return WINDUP_GEAR
	return 0.0


func _recover_time(kind: String) -> float:
	match kind:
		"homing":
			return RECOVER_HOMING
		"sweep":
			return RECOVER_SWEEP
		"fire":
			return RECOVER_FIRE
		"summon":
			return RECOVER_SUMMON
		"gear":
			return RECOVER_GEAR
	return 1.0


func _clear_hazards() -> void:
	for bullet: LoomBullet in _bullets:
		if bullet != null and is_instance_valid(bullet):
			bullet.queue_free()
	_bullets.clear()
	for wisp: LoomWisp in _wisps:
		if wisp != null and is_instance_valid(wisp):
			wisp.queue_free()
	_wisps.clear()
	for fire: LoomFire in _fires:
		if fire != null and is_instance_valid(fire):
			fire.queue_free()
	_fires.clear()
	for gear: LoomGear in _gears:
		if gear != null and is_instance_valid(gear):
			gear.queue_free()
	_gears.clear()
	if _sweep != null and is_instance_valid(_sweep):
		_sweep.queue_free()
	_sweep = null


# --- player attack / damage -----------------------------------------------

func _on_player_attack_started(_swing_id: int, _facing: int, _positive: bool) -> void:
	DemoAudio.play_swing()


func _on_player_attack_hit_window(swing_id: int, facing: int, positive: bool) -> void:
	if (
		_completed or _scene_leaving or _recovery_active or _retry_pending
		or not _boss_active
	):
		return
	if _resolved_swings.has(swing_id):
		return
	_resolved_swings[swing_id] = true
	# A real J swing may kill a summoned wisp first: it is the nearest target
	# and the swing should not also hit the boss behind it.
	if _try_kill_wisp(facing):
		return
	var attack_rect: Rect2 = _player_attack_rect(facing)
	if _core.is_exposed() and attack_rect.intersects(_core.get_hit_rect()):
		_resolve_core_hit(positive)
		return
	var best_node: LoomNode = null
	var best_dx: float = INF
	for node: LoomNode in _nodes:
		if node == null or not is_instance_valid(node) or not node.is_alive():
			continue
		if not attack_rect.intersects(node.get_hit_rect()):
			continue
		var dx: float = absf(node.global_position.x - _player.global_position.x)
		if dx < best_dx:
			best_dx = dx
			best_node = node
	if best_node == null:
		return
	if positive == best_node.is_positive():
		best_node.flash_deny()
		_audio.play_deny()
		_hud.show_event("同相弹开 · 换成异相再攻击", 1.4)
		return
	_audio.play_node_hit()
	best_node.break_node()
	if not _core.is_exposed():
		_hud.show_event("节点停转", 1.0)


func _try_kill_wisp(facing: int) -> bool:
	for wisp: LoomWisp in _wisps:
		if wisp == null or not is_instance_valid(wisp) or not wisp.is_alive():
			continue
		if wisp.try_player_hit(_player, facing):
			_audio.play_node_hit()
			_hud.show_event("浮灵消散", 0.9)
			return true
	return false


func _player_attack_rect(facing: int) -> Rect2:
	var direction: float = 1.0 if facing >= 0 else -1.0
	var origin_x: float = _player.global_position.x + (2.0 if direction > 0.0 else -40.0)
	return Rect2(origin_x, _player.global_position.y - 38.0, 38.0, 40.0)


## Single entry point for every hazard contact (bolt, band, fire, wisp, gear).
## The shared L3Player owns its 0.6 s protection and the real knockback; this
## adds a chapter-level 0.95 s grace and counts accepted hits against 3.
func apply_enemy_hit(source_position: Vector2) -> bool:
	if (
		not _boss_active or _completed or _scene_leaving or _recovery_active
		or _retry_pending or get_tree().paused
	):
		return false
	if _damage_immunity_left > 0.0:
		return false
	var away: int = 1 if _player.global_position.x >= source_position.x else -1
	if not _player.receive_enemy_strike(away):
		return false
	_damage_immunity_left = DAMAGE_IMMUNITY_TIME
	_player_hits += 1
	if is_instance_valid(DemoAudio):
		DemoAudio.play_player_hurt()
	_hud.show_event("受击 · 生命值 -1", 1.2)
	_update_hud_state()
	if _player_hits >= PLAYER_HIT_LIMIT:
		_retry_pending = true
		_retry_pending_left = maxf(_player.get_hit_reaction_remaining(), 0.02)
	return true


func _on_player_polarity_changed(positive: bool) -> void:
	# A reset also emits polarity_changed; only a real Q toggle should chime.
	var toggles: int = _player.get_polarity_toggle_count()
	if toggles > _last_polarity_toggles and is_instance_valid(DemoAudio):
		DemoAudio.play_polarity_switch()
	_last_polarity_toggles = toggles
	if _hud != null:
		_hud.set_polarity(positive)


func _on_player_recovery_transition_requested(reason: String) -> void:
	if reason != "fall" or _recovery_active or _completed or _scene_leaving:
		return
	_begin_recovery("fall")


# --- recovery (same approved timing as the other DLC chapters) -------------

func _begin_recovery(kind: String) -> void:
	if _recovery_active or _completed or _scene_leaving or _game_over:
		return
	# One recovery == one death.  The life row is the only read of the new
	# count; stage progress and the one-time stage-1 supply are not restored.
	_lives = maxi(_lives - 1, 0)
	_update_hud_state()
	_recovery_active = true
	_recovery_phase = RecoveryPhase.FADE_OUT
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_attack_key_down = false
	_retry_pending = false
	if _footsteps != null and is_instance_valid(_footsteps):
		_footsteps.stop()
	_clear_hazards()
	_attack_state = AttackState.IDLE
	_attack_left = 1.2
	_hud.set_gear_warning(false, 0.0)
	if is_instance_valid(DemoAudio):
		DemoAudio.play_failure()
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	_player.cancel_attack()
	_player.begin_recovery_hold()
	_player.clear_external_force()


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
				if _lives <= 0:
					_start_game_over()
				else:
					_apply_recovery_reset()
		RecoveryPhase.BLACK_HOLD:
			_recovery_alpha = 1.0
			_hud.set_recovery_alpha(1.0)
			if _recovery_elapsed >= RECOVERY_BLACK_HOLD_TIME:
				_recovery_phase = RecoveryPhase.FADE_IN
				_recovery_elapsed = 0.0
				if is_instance_valid(DemoAudio):
					DemoAudio.play_respawn()
		RecoveryPhase.FADE_IN:
			_recovery_alpha = clampf(
				1.0 - _recovery_elapsed / RECOVERY_FADE_IN_TIME, 0.0, 1.0
			)
			_hud.set_recovery_alpha(_recovery_alpha)
			if _recovery_alpha <= 0.0:
				_finish_recovery()


func _apply_recovery_reset() -> void:
	_reset_current_stage()
	_reset_player_at(ARENA_SPAWN)
	_player.begin_recovery_hold()
	_hud.show_event("失败 · 织机把你抛回阶段入口", 2.2)


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


## Third death: the arena stays in the background under a dim page with the
## empty heart row, 重试本章 / 返回标题 and R as the keyboard reset.  R resets
## lives through _restart_chapter; no path can add a fourth heart.
func _start_game_over() -> void:
	if _game_over or _completed or _scene_leaving:
		return
	_game_over = true
	_boss_active = false
	_pending_completion = false
	_retry_pending = false
	_fire_tip_pending = false
	_clear_hazards()
	_recovery_active = false
	_recovery_phase = RecoveryPhase.NONE
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_hud.set_recovery_alpha(0.0)
	_hud.set_gear_warning(false, 0.0)
	_hud.hide_event()
	_hud.show_game_over(true, 0)
	_update_hud_state()
	_audio.stop_music()
	if _footsteps != null and is_instance_valid(_footsteps):
		_footsteps.stop()
	_attack_key_down = false
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	_player.cancel_attack()
	_player.begin_recovery_hold()


## A failure retries the CURRENT stage at its entrance: stage is preserved,
## both nodes and the shielded core return, hazards clear, hits and immunity
## reset.  R still restarts the whole chapter from stage 1 (see _restart_chapter).
func _reset_current_stage() -> void:
	_resolved_swings.clear()
	_player_hits = 0
	_damage_immunity_left = 0.8
	_retry_pending = false
	_retry_pending_left = 0.0
	_pending_completion = false
	_core_hits = 0
	_boss_active = true
	_boss_grace = START_GRACE
	_attack_state = AttackState.IDLE
	_attack_left = 1.2
	_attack_cursor = 0
	_summon_serial = 0
	_fire_serial = 0
	_stage_flash = 0.0
	_clear_hazards()
	_hud.set_gear_warning(false, 0.0)
	_core.set_active(true)
	_core.set_exposed(false)
	_core.set_phase(_stage % 2 == 1)
	_respawn_nodes()
	_hud.set_objective("目标：用异相攻击打掉两个节点")
	_update_hud_state()


func _reset_player_at(point: Vector2) -> void:
	_player.set_spawn_point(point)
	_player.reset_to_spawn("combat_retry", true)
	_player.set_polarity_state(false)
	_player.global_position = point
	_player.velocity = Vector2.ZERO
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.face_direction(1)
	_camera.reset_smoothing()
	_hud.set_polarity(false)


# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _intro_guide != null and is_instance_valid(_intro_guide) and _intro_guide.is_open():
		return
	if _mechanic_popup != null and is_instance_valid(_mechanic_popup) and _mechanic_popup.is_open():
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)
	if _pause_open:
		# The pause page owns Enter/Space/arrows and its own buttons while open.
		return
	if key_event.pressed and not key_event.echo and code == int(KEY_R):
		_restart_chapter()
		get_viewport().set_input_as_handled()
		return
	if _scene_leaving:
		return
	if _game_over:
		# R above already restarts; the game over page owns Enter/Space and
		# arrows through LoomHUD's own fallback.
		return
	if _completed:
		if key_event.pressed and not key_event.echo:
			if code == int(KEY_E):
				get_viewport().set_input_as_handled()
				_return_to_title()
			elif (
				(code == int(KEY_ENTER) or code == int(KEY_KP_ENTER))
				and not _hud.is_completion_button_focused()
			):
				# Default state focuses 返回主界面, so Enter still returns to the
				# title.  Once focus moves to 重玩本章, Enter activates that
				# button instead of being stolen here.
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
				_face_nearest_target_on_attack()
				_player.request_attack()
				get_viewport().set_input_as_handled()
		else:
			_attack_key_down = false


func _unhandled_input(event: InputEvent) -> void:
	if _intro_guide != null and is_instance_valid(_intro_guide) and _intro_guide.is_open():
		return
	if _mechanic_popup != null and is_instance_valid(_mechanic_popup) and _mechanic_popup.is_open():
		return
	if _scene_leaving or _game_over:
		return
	# The completion page's footnote promises Esc can open the pause page, so
	# Esc is live there too; only the failure fade/retry owns no pause.
	if not _completed and _recovery_active:
		return
	if event.is_action_pressed(&"pause"):
		_set_paused(not _pause_open)
		get_viewport().set_input_as_handled()


## A real J turns toward the nearest live node (or the exposed core) within
## reach, so a swing never snapshots the old facing while standing on a boss.
func _face_nearest_target_on_attack() -> void:
	if not _boss_active:
		return
	var nearest_x: float = INF
	var target_x: float = NAN
	if _core.is_exposed():
		var core_dx: float = absf(_core.global_position.x - _player.global_position.x)
		if core_dx <= AUTO_FACE_RANGE and core_dx < nearest_x:
			nearest_x = core_dx
			target_x = _core.global_position.x
	for node: LoomNode in _nodes:
		if node == null or not is_instance_valid(node) or not node.is_alive():
			continue
		var dx: float = absf(node.global_position.x - _player.global_position.x)
		if dx <= AUTO_FACE_RANGE and dx < nearest_x:
			nearest_x = dx
			target_x = node.global_position.x
	if not is_nan(target_x):
		_player.face_direction(1 if target_x >= _player.global_position.x else -1)


func _on_hud_resume_requested() -> void:
	_set_paused(false)


func _on_hud_restart_requested() -> void:
	_restart_chapter()


func _on_hud_title_requested() -> void:
	_return_to_title()


func _on_hud_quit_requested() -> void:
	# Same direct quit as the base game's pause page; no export/git side effect.
	get_tree().quit()


func _set_paused(value: bool) -> void:
	if value == _pause_open:
		return
	_pause_open = value
	_hud.show_pause(value)
	if value:
		_hud.set_gear_warning(false, 0.0)
	_attack_key_down = false
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	if value:
		if _footsteps != null and is_instance_valid(_footsteps):
			_footsteps.stop()
		_audio.pause_music()
		get_tree().paused = true
		return
	get_tree().paused = false
	_audio.resume_music()
	LEVEL_FLOW.release_one_shot_actions()
	_player.clear_input_buffers()


# --- completion / restart --------------------------------------------------

func _complete_chapter() -> void:
	if _completed or _scene_leaving:
		return
	_completed = true
	_boss_active = false
	_pending_completion = false
	_retry_pending = false
	_fire_tip_pending = false
	_player_hits = 0
	_clear_hazards()
	_core.set_active(false)
	_core.set_exposed(false)
	for node: LoomNode in _nodes:
		node.set_active(false)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.lock_completion_input()
	if _footsteps != null and is_instance_valid(_footsteps):
		_footsteps.stop()
	_hud.show_pause(false)
	_hud.set_recovery_alpha(0.0)
	_hud.set_gear_warning(false, 0.0)
	_hud.show_completion(true, _elapsed)
	_hud.set_objective("目标：织机停转")
	# The completion row should show all three core pips and no shielded icon.
	_hud.set_boss_state(
		_stage, MAX_STAGE, 0, CORE_HITS_PER_STAGE, CORE_HITS_PER_STAGE, true,
		0, PLAYER_HIT_LIMIT, _lives, PLAYER_LIVES
	)
	_hud.show_event("织机停转", 3.0)
	_audio.stop_music()
	_audio.play_complete()
	LEVEL_FLOW.release_one_shot_actions()
	level_completed.emit()


func _return_to_title() -> void:
	if _scene_leaving:
		return
	get_tree().paused = false
	_pause_open = false
	_scene_leaving = true
	_hud.show_pause(false)
	_hud.show_game_over(false)
	_hud.show_completion(false, _elapsed)
	_audio.stop_all()
	if _footsteps != null and is_instance_valid(_footsteps):
		_footsteps.stop()
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	LEVEL_FLOW.return_to_title(get_tree())


func _restart_chapter() -> void:
	if _scene_leaving:
		return
	get_tree().paused = false
	_pause_open = false
	_completed = false
	_game_over = false
	_boss_active = false
	_stage = 1
	_core_hits = 0
	_player_hits = 0
	_lives = PLAYER_LIVES
	_damage_immunity_left = 0.0
	_stage_supply_used = false
	_fire_serial = 0
	_elapsed = 0.0
	_boss_grace = 0.0
	_stage_flash = 0.0
	_retry_pending = false
	_retry_pending_left = 0.0
	_pending_completion = false
	_recovery_active = false
	_recovery_phase = RecoveryPhase.NONE
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_resolved_swings.clear()
	_attack_state = AttackState.IDLE
	_attack_left = 0.0
	_attack_cursor = 0
	_summon_serial = 0
	_attack_kind = ""
	_telegraph_windup = 1.0
	_attack_key_down = false
	_objective_key = ""
	_fire_tip_pending = false
	_core_burst_played = false
	_clear_hazards()
	_hud.set_gear_warning(false, 0.0)
	_core.configure()
	_core.set_active(false)
	for node: LoomNode in _nodes:
		node.configure(CORE_POSITION, 0.0, true, NODE_ORBIT_RADIUS)
		node.set_active(false)
	_audio.stop_all()
	_hud.set_recovery_alpha(0.0)
	_hud.show_completion(false, 0.0)
	_hud.show_pause(false)
	_hud.show_game_over(false)
	_hud.set_boss_state(
		1, MAX_STAGE, 2, 0, CORE_HITS_PER_STAGE, false, 0,
		PLAYER_HIT_LIMIT, PLAYER_LIVES, PLAYER_LIVES
	)
	_hud.set_objective("目标：向右进入织机厅")
	_hud.set_polarity(false)
	_player.end_recovery_hold()
	_player.unlock_completion_input()
	_reset_player_at(START_SPAWN)
	_last_polarity_toggles = _player.get_polarity_toggle_count()
	LEVEL_FLOW.release_one_shot_actions()
	_player.begin_input_override()
	_input_ticks = 3
	_hud.show_event("星核织机已重新开始", 1.5)


# --- public read API -------------------------------------------------------

func get_player() -> L3Player:
	return _player


func get_camera() -> Camera2D:
	return _camera


func get_core() -> LoomCore:
	return _core


func get_nodes() -> Array[LoomNode]:
	return _nodes


func get_node_a() -> LoomNode:
	return _node_a


func get_node_b() -> LoomNode:
	return _node_b


func get_hud() -> LoomHUD:
	return _hud


func get_audio() -> LoomAudio:
	return _audio


func get_fx() -> LoomFx:
	return _fx


func get_intro_guide() -> DlcGuide:
	return _intro_guide


func get_mechanic_popup() -> MechanicPopup:
	return _mechanic_popup


func get_attack_time_left() -> float:
	return _attack_left


func get_boss_grace_left() -> float:
	return _boss_grace


func get_elapsed_seconds() -> float:
	return _elapsed


func get_stage() -> int:
	return _stage


func get_max_stage() -> int:
	return MAX_STAGE


func get_core_hits() -> int:
	return _core_hits


func get_core_hits_per_stage() -> int:
	return CORE_HITS_PER_STAGE


func get_player_hits() -> int:
	return _player_hits


func get_lives() -> int:
	return _lives


func get_max_lives() -> int:
	return PLAYER_LIVES


func is_game_over() -> bool:
	return _game_over


func get_footstep_audio() -> PlayerFootstepAudio:
	return _footsteps


func is_footstep_audio_allowed() -> bool:
	return _footsteps_allowed()


func get_nodes_alive_count() -> int:
	return _nodes_alive_count()


func _nodes_alive_count() -> int:
	var count: int = 0
	for node: LoomNode in _nodes:
		if node != null and is_instance_valid(node) and node.is_alive():
			count += 1
	return count


func is_boss_active() -> bool:
	return _boss_active


func is_core_exposed() -> bool:
	return _core != null and _core.is_exposed()


func is_completed() -> bool:
	return _completed


func is_pause_open() -> bool:
	return _pause_open


func is_recovery_active() -> bool:
	return _recovery_active


func is_retry_pending() -> bool:
	return _retry_pending


func get_attack_state_name() -> String:
	match _attack_state:
		AttackState.TELEGRAPH:
			return "telegraph"
		AttackState.RECOVER:
			return "recover"
		_:
			return "idle"


func get_attack_kind() -> String:
	return _attack_kind


func get_telegraph_progress() -> float:
	if _attack_state != AttackState.TELEGRAPH or _telegraph_windup <= 0.0:
		return 0.0
	return clampf(1.0 - _attack_left / _telegraph_windup, 0.0, 1.0)


func get_telegraph_points() -> Array:
	match _attack_kind:
		"homing":
			return _homing_points.duplicate()
		"summon":
			return _summon_points.duplicate()
		"fire":
			return _fire_points.duplicate()
		"gear":
			return _gear_points.duplicate()
		_:
			return [Vector2(SWEEP_START_X, FLOOR_Y)]


func get_gear_points() -> Array:
	return GEAR_WARNING_POINTS.duplicate()


func get_fire_points() -> Array:
	return _fire_points.duplicate()


func get_sweep_start_x() -> float:
	return SWEEP_START_X


func get_stage_flash() -> float:
	return _stage_flash


func get_active_bullets() -> int:
	var count: int = 0
	for bullet: LoomBullet in _bullets:
		if bullet != null and is_instance_valid(bullet):
			count += 1
	return count


func get_active_wisps() -> int:
	var count: int = 0
	for wisp: LoomWisp in _wisps:
		if wisp != null and is_instance_valid(wisp):
			count += 1
	return count


func get_active_fires() -> int:
	var count: int = 0
	for fire: LoomFire in _fires:
		if fire != null and is_instance_valid(fire):
			count += 1
	return count


func get_active_gears() -> int:
	var count: int = 0
	for gear: LoomGear in _gears:
		if gear != null and is_instance_valid(gear):
			count += 1
	return count


func get_last_fire_points() -> Array:
	return _fire_points.duplicate()


func is_sweep_active() -> bool:
	return _sweep != null and is_instance_valid(_sweep)


func get_player_hit_limit() -> int:
	return PLAYER_HIT_LIMIT


func get_damage_immunity_left() -> float:
	return _damage_immunity_left


func get_damage_immunity_time() -> float:
	return DAMAGE_IMMUNITY_TIME


func is_stage_supply_used() -> bool:
	return _stage_supply_used


func get_start_spawn() -> Vector2:
	return START_SPAWN


func get_arena_spawn() -> Vector2:
	return ARENA_SPAWN


func get_arena_enter_x() -> float:
	return ARENA_ENTER_X


func get_core_position() -> Vector2:
	return CORE_POSITION


# --- debug / capture hooks (never bypass a hit rule) ------------------------

func debug_set_stage(stage: int) -> void:
	if stage < 1 or stage > MAX_STAGE:
		return
	_stage = stage
	_core_hits = 0
	_player_hits = 0
	_damage_immunity_left = 0.0
	_stage_supply_used = stage > 1
	_boss_active = true
	_boss_grace = 0.0
	_attack_state = AttackState.IDLE
	_attack_left = 1.0
	_attack_cursor = 0
	_summon_serial = 0
	_clear_hazards()
	_core.configure()
	_core.set_active(true)
	_core.set_exposed(false)
	_core.set_phase(stage % 2 == 1)
	_respawn_nodes()
	_hud.set_objective("目标：用异相攻击打掉两个节点")
	_update_hud_state()


func debug_force_attack(kind: String) -> bool:
	if not _boss_active or _completed or _recovery_active:
		return false
	if not get_attack_pool().has(kind):
		return false
	_boss_grace = 0.0
	_begin_telegraph(kind)
	return true


func debug_set_attacks_enabled(value: bool) -> void:
	_attacks_enabled = value
	if not value:
		_attack_state = AttackState.IDLE
		_attack_left = 9999.0


func debug_set_node_angle(index: int, angle: float) -> void:
	if index < 0 or index >= _nodes.size():
		return
	_nodes[index].debug_set_angle(angle)


func debug_set_node_phase(index: int, positive: bool) -> void:
	if index < 0 or index >= _nodes.size():
		return
	_nodes[index].debug_set_phase(positive)


func debug_set_core_phase(positive: bool) -> void:
	if _core != null:
		_core.set_phase(positive)


func debug_expose_core() -> void:
	for node: LoomNode in _nodes:
		if node != null and is_instance_valid(node) and node.is_alive():
			node.break_node()


func debug_apply_player_hit() -> bool:
	return apply_enemy_hit(_core.global_position)


func debug_clear_hazards() -> void:
	_clear_hazards()


func debug_set_boss_grace(seconds: float) -> void:
	_boss_grace = maxf(seconds, 0.0)


## Capture/test hook only: choose a readable heart count before driving a real
## death through apply_enemy_hit.  It can never exceed the run's 3-heart cap.
func debug_set_lives(value: int) -> void:
	_lives = clampi(value, 0, PLAYER_LIVES)
	_update_hud_state()
