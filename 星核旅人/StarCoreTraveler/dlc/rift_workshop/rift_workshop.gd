class_name RiftWorkshop
extends Node2D

## DLC chapter 2 "裂隙工坊" (Rift Workshop), 2026-11-26 rework 2.
##
## Three connected rooms on one 1880 x 360 scene:
##   1. 反转回廊  x 0..560    : InversionA@160 flips the positive start to 澜相.
##                              Q is LOCKED in this chapter.  GateMoon requires
##                              the post-curtain 澜相, so the curtain itself is
##                              the key.  The duplicate GateCyan/InversionB pair
##                              is gone.
##   2. 相性桥    x 560..1080 : raised terrace, three 64x10 PhaseBridges
##                              alternating gold/cyan with stone landings, five
##                              hazard wisps and a checkpoint.  Each bridge wisp
##                              can be killed from the previous landing to make
##                              its deck permanent; this is the Q-less crossing.
##                              A low iron truss caps every jump over a gap.
##   3. 双面镜竞技场 x 1240..1880: a longer approach corridor separates the
##                              bridge from the arena.  The single boss
##                              "双面镜 · 裂隙守门者" hangs from chains in the
##                              centre.  Gold/cyan face plates are shields; only
##                              an opposite-phase J shatters each one.  Both
##                              broken -> the core is exposed and J hits it three
##                              times.  Form 2 anchors each plate to a wisp: the
##                              plate is immune while it lives and breakable for
##                              6 s after its anchor dies.  Form 3 cracks the
##                              mirror, speeds the plate orbit, alternates phase
##                              waves with double sweeps, shortens the core
##                              window and summons extra wisps.  Two inversion
##                              crystals (left/right, 2 s cooldown) are the
##                              player's own phase control.  Failure or falling
##                              returns to the arena entrance and resets the boss.
##                              The final core clear is a 1.35 s collapse; only
##                              after it finishes does the finish core activate.
##
## Reused, never modified: L3Player (J / hurt / fall recovery / locked Q),
## the shared PolarityGate scene from the trial chapter, DS03, the L2 stone
## strip, the project fonts and palette.  New content lives only in
## dlc/rift_workshop/.

signal level_completed

@export var show_intro_guide: bool = true
## First-entry opening film; R and combat retries never replay it.
@export var show_intro_cinematic: bool = true

const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")
const RIFT_GUIDE_SCRIPT: Script = preload("res://dlc/rift_workshop/rift_guide.gd")
const INTRO_CINEMATIC_SCENE: PackedScene = preload(
	"res://dlc/rift_workshop/rift_intro_cinematic.tscn"
)
const MECHANIC_POPUP_SCENE: PackedScene = preload("res://scenes/ui/mechanic_popup.tscn")
const MECHANIC_DEMO_DIR: String = "res://dlc/ui/demos"
const FOOTSTEP_SCRIPT = preload("res://scripts/audio/player_footstep_audio.gd")
const WISP_SCENE: PackedScene = preload("res://dlc/rift_workshop/rift_polarity_wisp.tscn")

## DLC copy registered through the shared MechanicPopup table.  Every body
## starts with the in-world cause and only then explains the keys.
const RIFT_TIPS: Dictionary = {
	"rift_mirror_tip": {
		"title": "双面镜",
		"body": "金面盘同辉相，青面盘同澜相。\n第二形态起，两面盘各被一只光灵锚定；\n先熄光灵，六秒内用异相攻击击碎。",
		"key": "先熄锚定光灵，六秒内碎面盘，再打核心。",
		"demo": "rift_mirror",
	},
	"rift_core_tip": {
		"title": "裂隙核心",
		"body": "双面镜碎裂，中央核心失去护持。\n走到尽头的裂隙核心旁，触碰它即可封闭裂隙。",
		"key": "走到尽头，触碰核心封闭裂隙。",
		"demo": "rift_core",
	},
}

const START_SPAWN: Vector2 = Vector2(40.0, 320.0)
## The bridge section's own reset point.  A fall from any bridge gap goes back
## here until the checkpoint is recorded, not all the way back to x = 40.
const BRIDGE_HEAD_SPAWN: Vector2 = Vector2(600.0, 280.0)
const BRIDGE_SECTION_LEFT: float = 540.0
const ARENA_SPAWN: Vector2 = Vector2(1250.0, 320.0)
const CHECKPOINT_POSITION: Vector2 = Vector2(1030.0, 280.0)
const FINISH_POSITION: Vector2 = Vector2(1850.0, 320.0)
const ARENA_ENTER_X: float = 1240.0
const BOSS_CENTER: Vector2 = Vector2(1540.0, 260.0)
const CRYSTAL_LEFT_X: float = 1320.0
const CRYSTAL_RIGHT_X: float = 1760.0
const BOSS_WISP_OFFSET: float = 170.0
const BOSS_ANCHOR_OFFSET: float = 96.0
const BRIDGE_FALL_LINE: String = "坠入云海 · 光桥只认同相 · 先熄光灵再走"
const BRIDGE_EDGE_LINE: String = "断桥了 · 先熄灭光灵，桥才会稳定"
const WISP_FLIP_LINE: String = "光灵翻相了 · 快退回石台，或熄灭它"
const WISP_CLEAR_LINE: String = "光灵熄灭 · 这座光桥已稳定"
const PLAYER_MAX_HITS: int = 2
## The low truss leaves 27 px over the player's head.  This is the same number
## the beam script uses; tests compare the two.
const BRIDGE_HEADROOM: float = 27.0
## The boss hovers asleep for this long after the arena entry event line, so
## the player is never caught between two charge-ups on the first step in.
const ARENA_INTRO_TIME: float = 0.9
const FINISH_RANGE: float = 18.0
const KILL_Y: float = 430.0
const WORLD_RIGHT: float = 1880.0
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

const RECOVERY_FADE_OUT_TIME: float = 0.25
const RECOVERY_BLACK_HOLD_TIME: float = 0.10
const RECOVERY_FADE_IN_TIME: float = 0.35
## The opening film's last frame is already the player view.  Keep one short
## control beat (HUD fade is 0.35 s) before the first-play guide opens, so the
## hand-off is real rather than a modal appearing in the same frame.
const POST_INTRO_GUIDE_DELAY: float = 0.45
## Facing assist range while a real J is pressed inside the arena.
const AUTO_FACE_RANGE: float = 160.0

enum RecoveryPhase { NONE, FADE_OUT, BLACK_HOLD, FADE_IN }

@onready var _player: L3Player = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _boss: RiftMirrorBoss = $MirrorBoss
@onready var _field_a: RiftInversionField = $InversionA
@onready var _bridge_a: RiftPhaseBridge = $BridgeA
@onready var _bridge_b: RiftPhaseBridge = $BridgeB
@onready var _bridge_c: RiftPhaseBridge = $BridgeC
@onready var _low_beams: RiftLowBeams = $LowBeams
@onready var _crystal_left: RiftInversionCrystal = $CrystalLeft
@onready var _crystal_right: RiftInversionCrystal = $CrystalRight
@onready var _checkpoint: LevelCheckpoint = $RiftCheckpoint
@onready var _hud: RiftWorkshopHUD = $HUD
@onready var _finish_core: Sprite2D = $FinishPoint/Core
@onready var _audio = $Audio
@onready var _ambience: DlcChapterAmbience = $Ambience

var _wisps: Array[RiftPolarityWisp] = []
var _boss_wisps: Array[RiftPolarityWisp] = []
var _wisp_bridges: Dictionary = {}
var _footsteps: Node = null

var _elapsed: float = 0.0
var _completed: bool = false
var _scene_leaving: bool = false
var _arena_entered: bool = false
## True only while the mirror fight is actually running; drives the chapter
## BGM so leaving/retrying/defeating the boss cannot leave music behind.
var _boss_active: bool = false
var _boss_defeated: bool = false
var _boss_collapse_active: bool = false
var _boss_defeat_cue_played: bool = false
var _arena_intro_left: float = 0.0
var _mirror_tip_pending: bool = false
var _core_tip_pending: bool = false
var _checkpoint_active: bool = false
var _finish_time: float = 0.0
var _objective_key: String = ""
var _pause_open: bool = false
var _attack_key_down: bool = false
var _resolved_swings: Dictionary = {}
var _player_hits: int = 0
var _retry_pending: bool = false
var _retry_pending_left: float = 0.0
var _start_lock_ticks: int = 0
var _last_polarity_toggles: int = 0
var _last_bridge_sound_ms: int = -1000
var _q_denial_count: int = 0
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
var _intro_cinematic: RiftIntroCinematic = null
var _intro_active: bool = false
var _intro_played: bool = false
var _intro_skipped: bool = false
var _post_intro_guide_pending: bool = false
var _post_intro_guide_left: float = 0.0
var _mechanic_popup: MechanicPopup = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10
	for node: Node in [
		$Background, $Terrain, $Decorations, $Player, $MirrorBoss,
		$InversionA, $BridgeA, $BridgeB, $BridgeC, $LowBeams,
		$WispA, $WispB, $WispC, $WispD, $WispE,
		$CrystalLeft, $CrystalRight, $RiftCheckpoint, $FinishPoint,
	]:
		if node != null:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE
	$HUD.process_mode = Node.PROCESS_MODE_ALWAYS

	_wisps = [$WispA, $WispB, $WispC, $WispD, $WispE]

	_player.allow_self_reset = false
	# Keep the body in front of the z=5 mirror effects and the HUD-free arena.
	_player.z_index = 6
	# The whole chapter is a locked-Q chapter.  Q only emits the shared denied
	# signal (refusal sound + cross-Q icon); fields, wisps, the boss wave and
	# the arena crystals are the real phase changes.
	_player.allow_polarity_toggle = false
	_player.set_world_bounds(0.0, WORLD_RIGHT)
	_player.set_kill_y(KILL_Y)
	_player.set_spawn_point(START_SPAWN)
	_player.set_recovery_intercept_enabled(true)
	_player.reset_to_spawn("level_start", false)
	_player.set_polarity_state(true)
	_player.global_position = START_SPAWN
	_player.velocity = Vector2.ZERO
	_player.polarity_changed.connect(_on_player_polarity_changed)
	_player.polarity_toggle_denied.connect(_on_player_polarity_denied)
	_player.attack_hit_window.connect(_on_player_attack_hit_window)
	_player.attack_started.connect(_on_player_attack_started)
	_player.recovery_transition_requested.connect(_on_player_recovery_transition_requested)
	_last_polarity_toggles = _player.get_polarity_toggle_count()

	_field_a.set_player_node(_player)
	_field_a.field_triggered.connect(_on_field_triggered)

	_bridge_a.set_player_node(_player)
	_bridge_b.set_player_node(_player)
	_bridge_c.set_player_node(_player)
	_bridge_a.solidity_changed.connect(_on_bridge_solidity_changed)
	_bridge_b.solidity_changed.connect(_on_bridge_solidity_changed)
	_bridge_c.solidity_changed.connect(_on_bridge_solidity_changed)

	_boss.set_player_target(_player)
	_boss.reset_full()
	_boss.set_suspended(true)
	_boss.phase_wave_released.connect(_on_boss_phase_wave_released)
	_boss.player_struck.connect(_on_boss_player_struck)
	_boss.summon_requested.connect(_on_boss_summon_requested)
	_boss.anchors_requested.connect(_on_boss_anchors_requested)
	_boss.anchor_window_started.connect(_on_boss_anchor_window_started)
	_boss.anchor_window_expired.connect(_on_boss_anchor_window_expired)
	_boss.face_shattered.connect(_on_boss_face_shattered)
	_boss.core_hit.connect(_on_boss_core_hit)
	_boss.core_exposed.connect(_on_boss_core_exposed)
	_boss.core_closed.connect(_on_boss_core_closed)
	_boss.defeat_started.connect(_on_boss_defeat_started)
	_boss.phase_cleared.connect(_on_boss_phase_cleared)
	_boss.phase_started.connect(_on_boss_phase_started)
	_boss.defeated.connect(_on_boss_defeated)

	_crystal_left.set_player_node(_player)
	_crystal_right.set_player_node(_player)
	_crystal_left.flipped.connect(_on_crystal_flipped.bind(_crystal_left))
	_crystal_right.flipped.connect(_on_crystal_flipped.bind(_crystal_right))

	# One wisp guards each bridge/landing deck.  The three bridge wisps have a
	# deck that becomes permanently stable when their J kill lands; the two
	# landing wisps only own the flip threat themselves.
	_wisp_bridges = {
		_wisps[0]: _bridge_a,
		_wisps[2]: _bridge_b,
		_wisps[4]: _bridge_c,
	}
	for wisp: RiftPolarityWisp in _wisps:
		wisp.defeated.connect(_on_wisp_defeated)
		wisp.flip_requested.connect(_on_wisp_flip_requested)

	_checkpoint.checkpoint_entered.connect(_on_checkpoint_entered)

	_hud.resume_requested.connect(_on_hud_resume_requested)
	_hud.restart_requested.connect(_restart_chapter)
	_hud.title_requested.connect(_on_hud_title_requested)
	_hud.quit_requested.connect(_on_hud_quit_requested)
	_hud.set_polarity(true)
	_hud.set_player_hits(0, PLAYER_MAX_HITS)
	_hud.set_health_target(_player)
	_hud.set_player_health_visible(true)
	_hud.set_objective("目标：穿过反转回廊")
	_hud.set_boss_visible(false)
	_hud.show_completion(false, 0.0)
	_hud.show_pause(false)
	_hud.set_recovery_alpha(0.0)
	_sync_boss_hud()
	_update_finish_marker()

	MechanicPopup.register_tips(RIFT_TIPS, MECHANIC_DEMO_DIR)
	_setup_mechanic_popup()
	_setup_footsteps()
	# The chapter ambience is ALWAYS so it keeps playing under the guide and
	# every mechanic popup (both pause the tree).  The pause page still calls
	# set_paused(true) explicitly, so pausing music there remains deterministic.
	_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience.play(true)

	_camera.reset_smoothing()
	_elapsed = 0.0
	LEVEL_FLOW.release_one_shot_actions()
	_player.begin_input_override()
	_start_lock_ticks = 3
	call_deferred("_start_intro_cinematic_or_guide")


## The film owns the screen before the guide.  The ambience player is ALWAYS and
## was started above, so the music keeps running under every film beat.
func _start_intro_cinematic_or_guide() -> void:
	if show_intro_cinematic and not _intro_played and not _completed and not _scene_leaving:
		if _intro_cinematic == null or not is_instance_valid(_intro_cinematic):
			_intro_cinematic = INTRO_CINEMATIC_SCENE.instantiate() as RiftIntroCinematic
		if _intro_cinematic != null:
			_intro_active = true
			_intro_skipped = false
			_hud.visible = false
			_footstep_stop()
			_boss.set_suspended(true)
			_player.lock_for_cinematic()
			add_child(_intro_cinematic)
			_intro_cinematic.configure(_boss, _player, _camera, _hud)
			_intro_cinematic.finished.connect(_on_intro_cinematic_finished)
			_intro_cinematic.start()
			return
	if show_intro_guide:
		_open_intro_guide()


func _on_intro_cinematic_finished(skipped: bool) -> void:
	_intro_active = false
	_intro_played = true
	_intro_skipped = skipped
	_hud.visible = true
	_hud.fade_in_after_intro()
	_attack_key_down = false
	_player.unlock_after_cinematic()
	_player.begin_input_override()
	_start_lock_ticks = 3
	if show_intro_guide and not _completed and not _scene_leaving:
		_post_intro_guide_pending = true
		_post_intro_guide_left = POST_INTRO_GUIDE_DELAY


func _tick_post_intro_guide(delta: float) -> void:
	if not _post_intro_guide_pending:
		return
	# A pause freezes _process before this tick; on resume the short hand-off
	# window continues.  Only states that will never return to this screen
	# cancel the pending guide.
	if _completed or _scene_leaving or _recovery_active or _retry_pending:
		_post_intro_guide_pending = false
		return
	_post_intro_guide_left = maxf(_post_intro_guide_left - delta, 0.0)
	if _post_intro_guide_left > 0.0:
		return
	_post_intro_guide_pending = false
	_open_intro_guide()


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
	_start_lock_ticks = 3
	# Music already runs under the guide (PROCESS_MODE_ALWAYS); do not restart
	# the track here or the opening would audibly jump.


func _setup_footsteps() -> void:
	if _player == null:
		return
	_footsteps = FOOTSTEP_SCRIPT.new()
	_footsteps.name = "PlayerFootstepAudio"
	if not bool(_footsteps.call("attach_to", _player)):
		_footsteps.queue_free()
		_footsteps = null
		return
	_footsteps.call("set_enabled_check", Callable(self, "_footstep_allowed"))


func _footstep_allowed() -> bool:
	if _completed or _recovery_active or _retry_pending or _scene_leaving:
		return false
	if _pause_open or get_tree().paused or _intro_active:
		return false
	if _start_lock_ticks > 0 or _arena_intro_left > 0.0:
		return false
	if _intro_guide != null and is_instance_valid(_intro_guide) \
			and _intro_guide.is_open():
		return false
	if _mechanic_popup != null and _mechanic_popup.is_open():
		return false
	return true


func _footstep_stop() -> void:
	if _footsteps != null and is_instance_valid(_footsteps):
		_footsteps.call("stop")


## Drop the active OGG stream and player before a real quit / title hand-off.
func _release_ambience() -> void:
	if _ambience == null or not is_instance_valid(_ambience):
		return
	var player: AudioStreamPlayer = _ambience.get_player()
	if player != null:
		player.stop()
		player.stream = null
	_ambience.stop(0.0)
	_ambience.set("_stream", null)
	_ambience.free()
	_ambience = null


## Teaching layer only: one shared popup, same scene and input behaviour as the
## base levels.  It owns no gameplay state and is never a gate.
func _setup_mechanic_popup() -> void:
	_mechanic_popup = MECHANIC_POPUP_SCENE.instantiate() as MechanicPopup
	_mechanic_popup.name = "MechanicPopup"
	_mechanic_popup.level_node = self
	add_child(_mechanic_popup)


func _tick_mechanic_popups() -> void:
	if _mechanic_popup == null:
		return
	if _mirror_tip_pending:
		if MechanicTips.has_seen("rift_mirror_tip"):
			_mirror_tip_pending = false
		elif _request_mechanic_tip("rift_mirror_tip"):
			_mirror_tip_pending = false
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
	if _intro_active:
		return true
	if _start_lock_ticks > 0 or _arena_intro_left > 0.0:
		return true
	if _intro_guide != null and is_instance_valid(_intro_guide):
		if _intro_guide.is_open():
			return true
	return false


func _exit_tree() -> void:
	_intro_active = false
	if _intro_cinematic != null and is_instance_valid(_intro_cinematic):
		_intro_cinematic.abort()
		_intro_cinematic.queue_free()
		_intro_cinematic = null
	_footstep_stop()
	_release_ambience()
	if _audio != null:
		_audio.shutdown()
	for wisp: RiftPolarityWisp in _all_wisps():
		if wisp != null and is_instance_valid(wisp):
			wisp.set_hum_enabled(false)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


# --- frame flow ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if get_tree().paused or _completed or _scene_leaving or _recovery_active:
		return
	if _intro_active:
		return
	if _retry_pending:
		_retry_pending_left = maxf(_retry_pending_left - delta, 0.0)
		if _retry_pending_left <= 0.0:
			_retry_pending = false
			_begin_recovery("combat")
			return
	if _start_lock_ticks > 0:
		_start_lock_ticks -= 1
		_player.begin_input_override()
		if _start_lock_ticks <= 0:
			_player.end_input_override()
		return

	if _arena_intro_left > 0.0:
		_arena_intro_left = maxf(_arena_intro_left - delta, 0.0)
		if _arena_intro_left <= 0.0:
			_wake_boss()
	# The intro hover is not the fight; BGM starts only in _wake_boss().

	_tick_bridge_edge_hints()

	if not _arena_entered and _player.global_position.x >= ARENA_ENTER_X:
		_arena_entered = true
		_arena_intro_left = ARENA_INTRO_TIME
		_boss.set_suspended(true)
		_hud.set_boss_visible(true)
		_hud.show_event("双面镜 · 裂隙守门者苏醒", 2.2)
		DemoAudio.play_record_save()
		_sync_boss_hud()
	_update_objective()
	if _boss_defeated and not _completed:
		_check_finish()
	_tick_mechanic_popups()
	_sync_boss_hud()


func _process(delta: float) -> void:
	if get_tree().paused or _scene_leaving:
		return
	if _intro_active:
		return
	_tick_post_intro_guide(delta)
	if not _completed:
		_elapsed += delta
	_advance_recovery(delta)
	if _finish_core != null:
		_finish_time += delta
		_finish_core.frame = int(_finish_time * 10.0) % 12
	# Hums only run close to the player, stay off during the recovery black-out
	# and on the completion page.  This includes the boss's summoned wisps.
	for wisp: RiftPolarityWisp in _all_wisps():
		if wisp == null or not is_instance_valid(wisp):
			continue
		var near: bool = absf(wisp.global_position.x - _player.global_position.x) < 250.0
		wisp.set_hum_enabled(
			near and wisp.is_alive() and not _completed and not _recovery_active
		)


func _all_wisps() -> Array[RiftPolarityWisp]:
	var combined: Array[RiftPolarityWisp] = []
	combined.append_array(_wisps)
	combined.append_array(_boss_wisps)
	return combined


func _sync_boss_hud() -> void:
	if _hud == null or _boss == null:
		return
	if not _arena_entered or _completed:
		_hud.set_boss_visible(false)
		return
	_hud.set_boss_visible(true)
	_hud.set_boss_state(
		_boss.get_phase_index(), _boss.get_phase_count(),
		_boss.get_core_hp(), _boss.get_max_core_hits(),
		_boss.is_face_intact(true), _boss.is_face_intact(false),
		_boss.is_core_exposed()
	)
	_hud.set_anchor_state(
		_boss.has_face_anchor(true), _boss.has_face_anchor(false),
		_boss.get_anchor_window_left(true), _boss.get_anchor_window_left(false)
	)


## Real J presses turn toward the nearest live arena target.  The bridge
## wisps are left alone: there the player's movement direction is the honest
## aim and auto-facing would fight the platforming.
func _face_nearest_arena_target_on_attack() -> void:
	if not _arena_entered or _boss_defeated:
		return
	var target: Node2D = null
	var best_dx: float = INF
	if not _boss.is_defeated():
		var boss_dx: float = absf(_boss.global_position.x - _player.global_position.x)
		target = _boss
		best_dx = boss_dx
	for wisp: RiftPolarityWisp in _boss_wisps:
		if wisp == null or not is_instance_valid(wisp) or not wisp.is_alive():
			continue
		var dx: float = absf(wisp.global_position.x - _player.global_position.x)
		if dx < best_dx:
			best_dx = dx
			target = wisp
	if target != null and best_dx <= AUTO_FACE_RANGE:
		_player.face_direction(
			1 if target.global_position.x >= _player.global_position.x else -1
		)


func _update_objective(force: bool = false) -> void:
	var text: String
	var key: String
	if _completed:
		text = "目标：裂隙封闭"
		key = "done"
	elif _boss_collapse_active:
		text = "目标：双面镜正在崩塌"
		key = "boss_collapse"
	elif _boss_defeated:
		text = "目标：触碰裂隙核心"
		key = "finish"
	elif _arena_entered:
		if _boss.is_core_exposed():
			var core_left: int = int(ceil(_boss.get_core_window_left()))
			text = "目标：攻击中央核心（还剩 %d 次 · %ds）" % [
				_boss.get_core_hp(), core_left
			]
			key = "arena_core_%d_%d" % [_boss.get_core_hp(), core_left]
		elif _boss.get_anchor_window_left(true) > 0.0 \
				or _boss.get_anchor_window_left(false) > 0.0:
			var window_left: float = maxf(
				_boss.get_anchor_window_left(true),
				_boss.get_anchor_window_left(false)
			)
			var side_name: String = "金"
			if _boss.get_anchor_window_left(true) <= 0.0:
				side_name = "青"
			text = "目标：%s面盘 %.0fs 内击碎" % [side_name, ceil(window_left)]
			key = "arena_window_%s_%d" % [side_name, int(ceil(window_left))]
		elif _boss.get_phase_index() >= 1 and _boss.get_alive_anchor_count() > 0:
			text = "目标：先熄灭锚定光灵"
			key = "arena_anchor"
		elif _boss.get_intact_face_count() >= 2:
			text = "目标：用异相攻击打碎两面盘"
			key = "arena_faces"
		else:
			text = "目标：打碎剩下的面盘"
			key = "arena_one_face"
	elif _player.global_position.x >= 1080.0:
		text = "目标：沿长廊进入双面镜竞技场"
		key = "approach"
	elif _checkpoint_active:
		text = "目标：沿长廊前进"
		key = "checkpoint_done"
	elif _player.global_position.x >= 560.0:
		text = "目标：跨过三相性光桥"
		key = "bridge"
	elif _player.global_position.x >= 150.0:
		text = "目标：穿过紫幕，让门同相"
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
	if _intro_active:
		return
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
				_face_nearest_arena_target_on_attack()
				_player.request_attack()
				get_viewport().set_input_as_handled()
		else:
			_attack_key_down = false


func _unhandled_input(event: InputEvent) -> void:
	if _intro_active:
		return
	if _intro_guide != null and is_instance_valid(_intro_guide) and _intro_guide.is_open():
		return
	if _scene_leaving or _recovery_active:
		return
	if event.is_action_pressed(&"pause"):
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
	_boss_active = false
	_audio.stop_music()
	get_tree().paused = false
	_release_ambience()
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	_quit_after_audio_release()


func _quit_after_audio_release() -> void:
	for _index: int in range(16):
		await get_tree().process_frame
	get_tree().quit()


func _set_paused(value: bool) -> void:
	if _intro_active or value == _pause_open:
		return
	_pause_open = value
	_hud.show_pause(value)
	_attack_key_down = false
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	if value:
		_footstep_stop()
		if _arena_entered:
			_boss.set_suspended(true)
		_ambience.set_paused(true)
		_audio.pause_music()
		get_tree().paused = true
		return
	get_tree().paused = false
	_ambience.set_paused(false)
	_audio.resume_music()
	LEVEL_FLOW.release_one_shot_actions()
	_player.clear_input_buffers()
	# A pause during the 0.9 s intro must not shorten or skip it; the intro
	# timer resumes with the tree and wakes the boss itself.
	if _arena_entered and not _completed and _arena_intro_left <= 0.0:
		if not _boss.is_defeated():
			_boss.set_suspended(false)


# --- room 1: inversion / gate / wisps --------------------------------------

func _on_field_triggered(positive: bool) -> void:
	_audio.play_inversion()
	_hud.show_event(
		"紫幕翻相 · " + ("辉相" if positive else "澜相"), 1.6
	)


func _on_player_polarity_changed(positive: bool) -> void:
	var toggles: int = _player.get_polarity_toggle_count()
	if toggles > _last_polarity_toggles:
		DemoAudio.play_polarity_switch()
	_last_polarity_toggles = toggles
	if _hud != null:
		_hud.set_polarity(positive)


## Q is locked in this chapter.  The shared player emits this signal instead of
## flipping; the chapter answers with the refusal cue and the head icon only.
func _on_player_polarity_denied() -> void:
	if _completed or _scene_leaving or _recovery_active or _pause_open:
		return
	_q_denial_count += 1
	_audio.play_deny()
	_hud.flash_q_denied(_player)


func _on_player_attack_started(_swing_id: int, _facing: int, _positive: bool) -> void:
	DemoAudio.play_swing()


func _on_player_attack_hit_window(swing_id: int, facing: int, positive: bool) -> void:
	if _completed or _scene_leaving or _recovery_active:
		return
	if _resolved_swings.has(swing_id):
		return
	_resolved_swings[swing_id] = true
	var killed_anchor: bool = false
	for wisp: RiftPolarityWisp in _all_wisps():
		if wisp != null and is_instance_valid(wisp) and wisp.is_alive():
			var was_anchor: bool = wisp.is_anchor()
			# _on_wisp_defeated owns the deck-stable / remaining-count line.
			wisp.try_player_hit(_player, facing, positive, swing_id)
			if was_anchor and not wisp.is_alive():
				killed_anchor = true
	# The swing that breaks an anchor only breaks the anchor.  The plate is
	# shattered by the next real J inside the 6 s window, never by the same hit.
	if not killed_anchor and _arena_entered and not _boss_defeated and _boss.is_active():
		var result: Dictionary = _boss.receive_player_hit(
			_player, facing, positive, swing_id
		)
		_show_boss_attack_result(result)


func _show_boss_attack_result(result: Dictionary) -> void:
	var code: String = String(result.get("code", ""))
	match code:
		"SAME_PHASE":
			_hud.show_event("同相打不碎面盘 · 先借晶体或相位波翻相", 1.8)
		"ANCHORED":
			var window: float = float(result.get("window", 0.0))
			if window > 0.0:
				_hud.show_event("面盘已脱锚 · %.0f 秒内用异相攻击击碎" % ceil(window), 1.8)
			else:
				_hud.show_event("面盘被光灵锚定 · 先熄灭锚定光灵", 1.8)
		"SHIELDED":
			if _boss.is_core_exposed():
				_hud.show_event("没打中核心 · 对准中央再攻击", 1.4)
			else:
				_hud.show_event("面盘护着核心 · 先打碎两面", 1.5)
		"MISS_RANGE":
			_hud.show_event("距离不够 · 再靠近双面镜", 1.4)
		"MISS_BEHIND":
			_hud.show_event("先面向双面镜再攻击", 1.4)
		_:
			pass


func _on_wisp_defeated(wisp: RiftPolarityWisp) -> void:
	var anchor_side: int = _boss.get_anchor_side_for(wisp)
	if anchor_side != 0:
		_boss.notify_anchor_defeated(anchor_side > 0)
		_sync_boss_hud()
		return
	var bridge: RiftPhaseBridge = _wisp_bridges.get(wisp, null) as RiftPhaseBridge
	if bridge != null and is_instance_valid(bridge):
		bridge.set_stabilized(true)
		_audio.play_bridge(true)
		_hud.show_event(WISP_CLEAR_LINE, 1.8)
		return
	var alive: int = 0
	for other: RiftPolarityWisp in _all_wisps():
		if other != null and is_instance_valid(other) and other.is_alive():
			alive += 1
	if alive > 0:
		_hud.show_event("光灵熄灭 · 剩余 %d" % alive, 1.2)
	else:
		_hud.show_event("光灵熄灭 · 双面镜的召唤清空", 1.3)


## Forced flip: the wisp dives and the chapter performs the same flip as the
## old Q path (so the shared player ring, HUD polarity and switch cue all stay
## honest).  Q itself remains locked; the player answers with movement, a J
## kill, or an arena crystal.  A bridge deck holds solid for 0.55 s so a fast
## retreat to the landing is a real save.
func _on_wisp_flip_requested(wisp: RiftPolarityWisp) -> void:
	if _completed or _scene_leaving or _recovery_active or _retry_pending:
		return
	if _boss_collapse_active or _boss_defeated:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if wisp == null or not is_instance_valid(wisp) or not wisp.is_alive():
		return
	if _player.has_method("is_input_override_active") \
			and bool(_player.call("is_input_override_active")):
		return
	var guarded_bridge: RiftPhaseBridge = _wisp_bridges.get(
		wisp, null
	) as RiftPhaseBridge
	if guarded_bridge != null and is_instance_valid(guarded_bridge):
		if guarded_bridge.is_stabilized():
			_hud.show_event("光灵翻相 · 桥已稳定，继续走", 1.2)
		else:
			guarded_bridge.hold_solid(0.55)
			_hud.show_event(WISP_FLIP_LINE, 1.4)
	else:
		_hud.show_event("光灵扑来 · 相性被翻", 1.2)
	_player.call("_toggle_polarity")


# --- room 2: bridges / checkpoint ------------------------------------------

func _on_bridge_solidity_changed(solid: bool) -> void:
	# One phase change changes all three decks at once: coalesce the chime.
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_bridge_sound_ms < 90:
		return
	_last_bridge_sound_ms = now_ms
	_audio.play_bridge(solid)


## Optional readability aid, once per deck: standing at a gap edge while the
## next deck is ghosted earns one short HUD line.  It never blocks input and
## never opens the shared mechanic popup.
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
	_hud.show_event("检查点已记录 · 前方是双面镜长廊", 1.8)
	DemoAudio.play_record_save()
	_update_objective(true)


# --- room 3: double mirror boss --------------------------------------------

func _wake_boss() -> void:
	if _completed or _scene_leaving or _recovery_active:
		return
	if not _arena_entered or _boss_defeated:
		return
	_boss_active = true
	_audio.start_music()
	_boss.set_suspended(false)
	_boss.begin_fight()
	_mirror_tip_pending = true
	_hud.set_boss_visible(true)
	_hud.show_event("守门者睁眼 · 异相攻击才能碎面盘", 2.2)
	_sync_boss_hud()


func _on_boss_phase_wave_released(positive_after: bool, flipped: bool) -> void:
	_audio.play_inversion()
	if flipped:
		_hud.show_event(
			"相位波翻相 · 现在是" + ("辉相" if positive_after else "澜相"), 1.8
		)
	else:
		_hud.show_event("相位波掠过 · 跳起躲开了翻相", 1.5)


func _on_boss_player_struck(_away: int) -> void:
	if _completed or _scene_leaving or _recovery_active or _retry_pending:
		return
	if _boss_collapse_active:
		return
	_player_hits += 1
	DemoAudio.play_player_hurt()
	_audio.play_slam()
	_hud.set_player_hits(_player_hits, PLAYER_MAX_HITS)
	if _player_hits >= PLAYER_MAX_HITS:
		_retry_pending = true
		_retry_pending_left = maxf(_player.get_hit_reaction_remaining(), 0.0)


func _on_boss_summon_requested(count: int) -> void:
	if _completed or _scene_leaving or _boss_defeated:
		return
	_spawn_extra_wisps(count)
	DemoAudio.play_link()
	_hud.show_event("双面镜召来两只光灵 · 攻击可以熄灭", 1.8)
	_sync_boss_hud()


func _on_boss_anchors_requested(_count: int) -> void:
	if _completed or _scene_leaving or _boss_defeated:
		return
	var sides: Array[bool] = _boss.get_missing_anchor_sides()
	_spawn_anchor_wisps(sides)
	DemoAudio.play_link()
	if _boss.get_phase_index() == 1:
		_hud.show_event("紫色锚链落下 · 光灵护住面盘", 1.9)
	else:
		_hud.show_event("锚链重织 · 先熄光灵，六秒内碎面盘", 1.9)
	_sync_boss_hud()


func _on_boss_anchor_window_started(positive: bool, seconds: float) -> void:
	DemoAudio.play_shell_shatter()
	_hud.show_event(
		"%s面盘锚已断 · %.0f 秒内可击碎" % [
			"金" if positive else "青", seconds
		], 2.0
	)
	_sync_boss_hud()


func _on_boss_anchor_window_expired(positive: bool) -> void:
	_hud.show_event(
		"%s面盘锚链重织 · 光灵即将归来" % ("金" if positive else "青"), 1.8
	)
	_sync_boss_hud()


func _on_boss_face_shattered(positive: bool) -> void:
	DemoAudio.play_shell_shatter()
	var remaining: int = _boss.get_intact_face_count()
	if remaining > 0:
		_hud.show_event(
			("金" if positive else "青") + "面盘碎裂 · 还差一面", 1.8
		)
	else:
		_hud.show_event("两面盘已碎 · 中央核心暴露", 1.9)
	_sync_boss_hud()


func _on_boss_core_hit(remaining: int) -> void:
	DemoAudio.play_core_take()
	if remaining > 0:
		_hud.show_event("核心命中 · 还剩 %d 次" % remaining, 1.4)
	_sync_boss_hud()


func _on_boss_core_exposed() -> void:
	_audio.play_bridge(true)
	_clear_boss_wisps()
	_hud.show_event("两面盘已碎 · 中央核心暴露", 1.9)
	_sync_boss_hud()


func _on_boss_core_closed() -> void:
	_clear_boss_wisps()
	_audio.play_bridge(false)
	_hud.show_event("核心闭合 · 面盘与锚链重生", 1.9)
	_sync_boss_hud()


func _on_boss_phase_cleared(phase_index: int) -> void:
	_audio.play_inversion()
	_hud.show_event(
		"形态 %d 破碎 · 核心闪白 · 镜面重组中" % (phase_index + 1), 2.0
	)
	_clear_boss_wisps()
	_sync_boss_hud()


func _on_boss_phase_started(phase_index: int) -> void:
	if phase_index == 1:
		_hud.show_event("形态 2 · 面盘被光灵锚定 · 横扫更快", 2.2)
	elif phase_index == 2:
		_hud.show_event("形态 3 · 镜面裂开 · 双横扫与短核心窗", 2.2)
	else:
		_hud.show_event("形态 1 · 异相攻击才能碎面盘", 2.0)
	_sync_boss_hud()


func _on_boss_defeat_started() -> void:
	if _completed or _scene_leaving or _boss_defeated:
		return
	# The 1.35 s collapse owns the audio: stop the BGM at its first frame and
	# play the defeat cue exactly once for this collapse.
	_boss_active = false
	_audio.stop_music()
	_audio.play_defeat()
	_boss_collapse_active = true
	# Display only: the 1.35 s collapse owns the screen, so the player health
	# bar is suppressed until the mirror has finished falling apart.
	_hud.set_player_health_visible(false)
	# No attack, wisp dive or reflected hazard may damage the player while the
	# 1.35 s collapse owns the screen.  The chapter also paints the shared hit
	# protection window so even a stray call is refused by the player itself.
	_player.set("_hit_protection_remaining", 999.0)
	_clear_boss_wisps()
	_hud.show_event("双面镜崩塌 · 面盘碎裂 · 核心内爆", 2.0)
	_update_objective(true)
	_sync_boss_hud()


func _on_boss_defeated() -> void:
	if _completed or _scene_leaving or _boss_defeated:
		return
	_boss_collapse_active = false
	_boss_active = false
	_audio.stop_music()
	_boss_defeated = true
	# The collapse is over; the post-fight route shows the bar again until the
	# completion page or a modal pauses it.
	_hud.set_player_health_visible(true)
	_clear_boss_wisps()
	_hud.show_event("双面镜碎裂 · 裂隙核心开启", 2.4)
	_audio.play_complete()
	_boss_defeat_cue_played = true
	_core_tip_pending = true
	_update_finish_marker()
	_update_objective(true)
	_sync_boss_hud()


## Form 2/3 face anchors.  They hover at the player's strike height (y=292) so
## the real J can actually kill them; the boss owns immunity/window timing.
func _spawn_anchor_wisps(sides: Array[bool]) -> void:
	if _boss == null or _boss_defeated:
		return
	for positive: bool in sides:
		if _boss.has_face_anchor(positive):
			continue
		var side: float = -1.0 if positive else 1.0
		var spawn_x: float = BOSS_CENTER.x + side * BOSS_ANCHOR_OFFSET
		var wisp: RiftPolarityWisp = WISP_SCENE.instantiate() as RiftPolarityWisp
		if wisp == null:
			continue
		wisp.name = "GoldAnchor" if positive else "CyanAnchor"
		wisp.position = Vector2(spawn_x, 292.0)
		wisp.hazard_mode = true
		wisp.zone_center_x = spawn_x
		wisp.zone_half_width = 36.0
		wisp.hazard_deck_y = 320.0
		wisp.hazard_y_tolerance = 10.0
		wisp.flip_interval = 2.2 if _boss.get_phase_index() == 1 else 1.6
		wisp.start_positive = positive
		wisp.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(wisp)
		wisp.set_anchor_target(_boss, positive)
		wisp.defeated.connect(_on_wisp_defeated)
		wisp.flip_requested.connect(_on_wisp_flip_requested)
		wisp.set_hum_enabled(true)
		_boss_wisps.append(wisp)
		_boss.attach_anchor(positive, wisp)


## Form 3's independent summon timer.  Extra hazard wisps never replace a live
## anchor; the arena caps them at two so the core window stays readable.
func _spawn_extra_wisps(count: int) -> void:
	if _boss == null or _boss_defeated:
		return
	var extra_existing: int = 0
	for wisp: RiftPolarityWisp in _boss_wisps:
		if wisp != null and is_instance_valid(wisp) and not wisp.is_anchor():
			extra_existing += 1
	var spawn_count: int = mini(maxi(count, 1), 2)
	spawn_count = mini(spawn_count, maxi(2 - extra_existing, 0))
	for index: int in range(spawn_count):
		var side: float = -1.0 if index == 0 else 1.0
		var spawn_x: float = BOSS_CENTER.x + side * BOSS_WISP_OFFSET
		var wisp: RiftPolarityWisp = WISP_SCENE.instantiate() as RiftPolarityWisp
		if wisp == null:
			continue
		wisp.name = "BossWispExtra%d" % (index + 1)
		wisp.position = Vector2(spawn_x, 292.0)
		wisp.hazard_mode = true
		wisp.zone_center_x = spawn_x
		wisp.zone_half_width = 34.0
		wisp.hazard_deck_y = 320.0
		wisp.hazard_y_tolerance = 10.0
		wisp.flip_interval = 1.6
		wisp.start_positive = index == 0
		wisp.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(wisp)
		wisp.defeated.connect(_on_wisp_defeated)
		wisp.flip_requested.connect(_on_wisp_flip_requested)
		wisp.set_hum_enabled(true)
		_boss_wisps.append(wisp)


func _clear_boss_wisps() -> void:
	for wisp: RiftPolarityWisp in _boss_wisps:
		if wisp != null and is_instance_valid(wisp):
			wisp.set_hum_enabled(false)
			wisp.queue_free()
	_boss_wisps.clear()
	if _boss != null:
		_boss.clear_anchors()


func _on_crystal_flipped(positive: bool, crystal: RiftInversionCrystal) -> void:
	if _completed or _scene_leaving or _recovery_active:
		return
	_audio.play_inversion()
	_hud.show_event(
		"反转晶体 · " + ("辉相" if positive else "澜相"), 1.2
	)
	if crystal != null:
		crystal.queue_redraw()


# --- recovery transition ---------------------------------------------------

func _on_player_recovery_transition_requested(reason: String) -> void:
	if reason != "fall" or _recovery_active or _completed or _scene_leaving:
		return
	_fall_origin_x = _player.global_position.x
	_begin_recovery("fall")


func _begin_recovery(kind: String) -> void:
	if _recovery_active or _completed or _scene_leaving:
		return
	_post_intro_guide_pending = false
	_boss_active = false
	_audio.stop_music()
	_footstep_stop()
	_hud.set_player_health_visible(false)
	_recovery_active = true
	_recovery_kind = kind
	_recovery_phase = RecoveryPhase.FADE_OUT
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_attack_key_down = false
	_mirror_tip_pending = false
	_core_tip_pending = false
	DemoAudio.play_failure()
	_hud.set_recovery_alpha(0.0)
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	_player.cancel_attack()
	_player.begin_recovery_hold()
	_player.clear_external_force()
	_arena_intro_left = 0.0
	_boss.set_suspended(true)
	for wisp: RiftPolarityWisp in _all_wisps():
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
			_reset_player_at(CHECKPOINT_POSITION, true)
		elif bridge_fall:
			# No PitFloor under the gaps: the bridge section retries from its
			# own head instead of sending the player back to x = 40.  The head
			# starts 辉相 so the first gold deck is immediately usable without Q.
			_reset_player_at(BRIDGE_HEAD_SPAWN, true)
		else:
			_reset_player_at(START_SPAWN, true)
		if bridge_fall:
			_hud.show_event(BRIDGE_FALL_LINE, 3.0)
	else:
		_retry_boss()
	_player.begin_recovery_hold()
	_boss.set_suspended(true)
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
	_hud.set_player_health_visible(true)
	_attack_key_down = false
	LEVEL_FLOW.release_one_shot_actions()
	# A retry already wrote the 0.9 s arena opening at black.  Physics stays
	# blocked while recovery is active, so this frame must not wake the boss
	# early; the timer resumes on the next physics tick.
	if (
		_arena_entered and not _completed and not _scene_leaving
		and _arena_intro_left <= 0.0 and not _boss_defeated
	):
		_boss.set_suspended(false)


## A failure or a fall inside the arena returns the whole mirror fight to its
## opening state: phase 1, both face plates intact, core at 3/3, summons gone.
## R remains the full chapter restart.
func _retry_boss() -> void:
	_boss_active = false
	_audio.stop_music()
	_resolved_swings.clear()
	_player_hits = 0
	_hud.set_player_hits(0, PLAYER_MAX_HITS)
	_retry_pending = false
	_retry_pending_left = 0.0
	_boss_collapse_active = false
	_boss_defeat_cue_played = false
	_mirror_tip_pending = false
	_core_tip_pending = false
	_clear_boss_wisps()
	_boss.reset_full()
	_boss.set_suspended(true)
	_crystal_left.reset_state()
	_crystal_right.reset_state()
	_arena_intro_left = ARENA_INTRO_TIME
	_reset_player_at(ARENA_SPAWN, true)
	_update_finish_marker()
	_update_objective(true)
	_sync_boss_hud()
	_hud.show_event("失败 · 回到竞技场入口 · 双面镜复原", 2.0)


func _reset_player_at(point: Vector2, positive: bool = true) -> void:
	_player.set_spawn_point(point)
	_player.reset_to_spawn("combat_retry", true)
	_player.set_polarity_state(positive)
	_player.global_position = point
	_player.velocity = Vector2.ZERO
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.face_direction(1)
	_camera.reset_smoothing()
	_last_polarity_toggles = _player.get_polarity_toggle_count()
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
	if _boss_defeated:
		_finish_core.modulate = Color(1.0, 0.92, 0.72, 1.0)
	else:
		_finish_core.modulate = Color(0.42, 0.52, 0.56, 0.62)


func _complete_chapter() -> void:
	if _completed or _scene_leaving:
		return
	_post_intro_guide_pending = false
	_footstep_stop()
	_hud.set_player_health_visible(false)
	_completed = true
	_boss_active = false
	_audio.stop_music()
	_boss_collapse_active = false
	_retry_pending = false
	_arena_intro_left = 0.0
	_mirror_tip_pending = false
	_core_tip_pending = false
	_player_hits = 0
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.lock_completion_input()
	_boss.set_suspended(true)
	_clear_boss_wisps()
	for wisp: RiftPolarityWisp in _wisps:
		if wisp != null and is_instance_valid(wisp):
			wisp.set_hum_enabled(false)
	_hud.show_pause(false)
	_hud.set_boss_visible(false)
	_hud.show_completion(true, _elapsed)
	_hud.set_objective("目标：裂隙封闭")
	_ambience.stop(DlcChapterAmbience.STOP_FADE_SECONDS)
	if not _boss_defeat_cue_played:
		_audio.play_complete()
		_boss_defeat_cue_played = true
	LEVEL_FLOW.release_one_shot_actions()
	level_completed.emit()


func _return_to_title() -> void:
	if _scene_leaving:
		return
	_post_intro_guide_pending = false
	_footstep_stop()
	get_tree().paused = false
	_pause_open = false
	_scene_leaving = true
	_mirror_tip_pending = false
	_core_tip_pending = false
	_hud.show_pause(false)
	_hud.show_completion(false, _elapsed)
	_boss_active = false
	_audio.stop_music()
	_release_ambience()
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
	_post_intro_guide_pending = false
	_footstep_stop()
	get_tree().paused = false
	_pause_open = false
	_completed = false
	_arena_entered = false
	_boss_active = false
	_boss_defeated = false
	_boss_collapse_active = false
	_boss_defeat_cue_played = false
	_arena_intro_left = 0.0
	_mirror_tip_pending = false
	_core_tip_pending = false
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
	_elapsed = 0.0
	_finish_time = 0.0
	_objective_key = ""
	_attack_key_down = false
	_fall_origin_x = 0.0
	_edge_hints_shown.clear()
	_edge_hint_count = 0
	_q_denial_count = 0
	_audio.stop_all()
	_ambience.play(true)
	_hud.set_recovery_alpha(0.0)
	_hud.show_completion(false, 0.0)
	_hud.show_pause(false)
	_hud.set_objective("目标：穿过反转回廊")
	_hud.set_polarity(true)
	_hud.set_player_hits(0, PLAYER_MAX_HITS)
	_hud.set_health_target(_player)
	_hud.set_player_health_visible(true)
	_hud.set_boss_visible(false)
	_player.end_recovery_hold()
	_player.unlock_completion_input()
	_reset_player_at(START_SPAWN, true)
	_last_polarity_toggles = _player.get_polarity_toggle_count()
	_clear_boss_wisps()
	_boss.reset_full()
	_boss.set_suspended(true)
	_bridge_a.set_stabilized(false)
	_bridge_b.set_stabilized(false)
	_bridge_c.set_stabilized(false)
	for wisp: RiftPolarityWisp in _wisps:
		if wisp != null and is_instance_valid(wisp):
			wisp.respawn()
	_crystal_left.reset_state()
	_crystal_right.reset_state()
	_field_a.reset_inside_state()
	_checkpoint.set_activated(false)
	_update_finish_marker()
	_sync_boss_hud()
	LEVEL_FLOW.release_one_shot_actions()
	_player.begin_input_override()
	_start_lock_ticks = 3
	_hud.show_event("裂隙工坊已重新开始", 1.5)


func get_player() -> L3Player:
	return _player


func get_mechanic_popup() -> MechanicPopup:
	return _mechanic_popup


func get_boss() -> RiftMirrorBoss:
	return _boss


func get_boss_wisps() -> Array[RiftPolarityWisp]:
	return _boss_wisps


func get_crystal_left() -> RiftInversionCrystal:
	return _crystal_left


func get_crystal_right() -> RiftInversionCrystal:
	return _crystal_right


func get_field_a() -> RiftInversionField:
	return _field_a


func get_bridge_a() -> RiftPhaseBridge:
	return _bridge_a


func get_bridge_b() -> RiftPhaseBridge:
	return _bridge_b


func get_bridge_c() -> RiftPhaseBridge:
	return _bridge_c


func get_wisps() -> Array[RiftPolarityWisp]:
	return _wisps


func get_wisp_bridge(wisp: RiftPolarityWisp) -> RiftPhaseBridge:
	return _wisp_bridges.get(wisp, null) as RiftPhaseBridge


func get_low_beams() -> RiftLowBeams:
	return _low_beams


func get_footstep_audio() -> Node:
	return _footsteps


func get_bridge_headroom() -> float:
	return BRIDGE_HEADROOM


func get_player_max_hits() -> int:
	return PLAYER_MAX_HITS


func get_hud() -> RiftWorkshopHUD:
	return _hud


func get_ambience() -> DlcChapterAmbience:
	return _ambience


func get_intro_guide() -> DlcGuide:
	return _intro_guide


func get_intro_cinematic() -> RiftIntroCinematic:
	return _intro_cinematic


func get_audio() -> Node:
	return _audio


func is_intro_active() -> bool:
	return _intro_active


func has_played_intro() -> bool:
	return _intro_played


func was_intro_skipped() -> bool:
	return _intro_skipped


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


func get_boss_center() -> Vector2:
	return BOSS_CENTER


func get_elapsed_seconds() -> float:
	return _elapsed


func is_completed() -> bool:
	return _completed


func is_boss_active() -> bool:
	return _boss_active


func is_boss_defeated() -> bool:
	return _boss_defeated


func is_boss_collapse_active() -> bool:
	return _boss_collapse_active


## True during the 1.35 s collapse, when no arena hazard may damage the player.
func is_boss_collapse_invulnerable() -> bool:
	return _boss_collapse_active


func is_arena_entered() -> bool:
	return _arena_entered


## Remaining opening hover after arena entry (0 when the boss is live).
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


func get_q_denial_count() -> int:
	return _q_denial_count


func get_finish_sprite() -> Sprite2D:
	return _finish_core
