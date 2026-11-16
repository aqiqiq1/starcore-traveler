class_name Level03
extends StarCoreInteractionRoom

## Level-03 play-test revision: turn back left/up to the extra device platform,
## per-block collapsing float stones, a teaching-gated guard with waiting rubble,
## opposite-phase J, gravity-charge true damage, 360-degree release, two-hit
## current-fight retry, wide arena, low HUD/head bubble.

signal level_completed

const PAUSE_MENU_SCRIPT = preload("res://scripts/level03/l3_pause_menu.gd")
const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")

const STAGE_START: int = 0
const STAGE_RUNE: int = 1
const STAGE_DEVICE: int = 2
const STAGE_ARENA: int = 3

## Approved short recovery transition (user play-test: resurrection was too
## abrupt). Existing hit reaction/red/knockback play fully first; only then does
## this cover fade in, reset at true alpha 1, hold black briefly, and fade out.
const RECOVERY_FADE_OUT_TIME: float = 0.25
const RECOVERY_BLACK_HOLD_TIME: float = 0.10
const RECOVERY_FADE_IN_TIME: float = 0.35

enum RecoveryPhase { NONE, FADE_OUT, BLACK_HOLD, FADE_IN }

const START_SPAWN: Vector2 = Vector2(40.0, 320.0)
const RUNE_SPAWN: Vector2 = Vector2(340.0, 320.0)
const DEVICE_SPAWN: Vector2 = Vector2(310.0, 130.0)
const ARENA_SPAWN: Vector2 = Vector2(1520.0, 252.0)
const GUARD_SPAWN: Vector2 = Vector2(2050.0, 320.0)
const KEY_PICKUP_RANGE: float = 44.0
const CINE_TRIGGER_X: float = 2310.0
const CITY_ENTER_X: float = 2460.0
const DEVICE_TARGET: Vector2 = Vector2(290.0, 130.0)
const RUNE_TARGET: Vector2 = Vector2(330.0, 304.0)
const FLOAT_TARGET: Vector2 = Vector2(1520.0, 252.0)
const GUARD_TARGET: Vector2 = Vector2(2050.0, 320.0)
const GATE_TARGET: Vector2 = Vector2(2380.0, 320.0)
const CITY_TARGET: Vector2 = Vector2(2460.0, 320.0)

const KEY_CORE_SHEET: Texture2D = preload("res://assets/level03_prototype/key_core_12f.png")

@export var pause_audio_settings_path: String = "user://audio_settings.cfg"
@export var pause_display_settings_path: String = "user://display_settings.cfg"

@onready var _l3_player: L3Player = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _hud03: L3HUD = $HUD
@onready var _device: L3FixedDevice = $FixedDevice
@onready var _float_route: L3FloatRoute = $FloatRoute
@onready var _guard: L3Guard = $Guard
@onready var _gate: L3Gate = $Gate
@onready var _cine: L3Cinematic = $Cine
@onready var _audio = $Audio
@onready var _checkpoint: LevelCheckpoint = $BufferCheckpoint
@onready var _link: BayRuneLink = $LinkController
@onready var _rune_field: RuneStoneField = $RuneField

var _pause_menu = null
var _completed: bool = false
var _resetting: bool = false
var _scene_leaving: bool = false
var _completion_count: int = 0
var _last_polarity_toggles: int = 0
var _stable_stage: int = STAGE_START
var _stable_core_positive: bool = true
var _stable_player_positive: bool = true
var _stable_spawn: Vector2 = START_SPAWN
var _key_taken: bool = false
var _key_embedded: bool = false
var _key_carried: bool = false
var _key_drop_position: Vector2 = GUARD_SPAWN + Vector2(0.0, -10.0)
var _key_pickup: Sprite2D = null
var _key_time: float = 0.0
var _checkpoint_mark: Sprite2D = null
var _checkpoint_mark_time: float = 0.0
var _attack_key_down: bool = false
var _resolved_swings: Dictionary = {}
var _player_hits: int = 0
var _last_guide_key: String = ""
var _retrying: bool = false
var _float_rule_shown: bool = false
var _replay_pending: bool = false
## Second hit: hold the fight's own 0.15 s hit reaction on screen before the
## current-fight retry resets the body. While pending, no third hit is accepted.
var _retry_pending: bool = false
var _retry_pending_left: float = 0.0
## A few physics ticks of the existing input override after a replay, so a
## Space/Enter/click that restarted the run cannot also become a jump.
var _replay_guard_ticks: int = 0
## Local recovery cover state. Only this level instance times it; the HUD merely
## owns the black rectangle, and the shared player is only asked to hold/reset.
var _recovery_phase: RecoveryPhase = RecoveryPhase.NONE
var _recovery_active: bool = false
var _recovery_kind: String = ""
var _recovery_alpha: float = 0.0
var _recovery_elapsed: float = 0.0
var _recovery_applying: bool = false
var _recovery_reset_alpha: float = -1.0
var _recovery_reset_count: int = 0
var _recovery_finished_count: int = 0
var _recovery_pre_reset_position: Vector2 = Vector2.ZERO
var _recovery_reset_position: Vector2 = Vector2.ZERO
var _window_has_focus: bool = true


func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10

	_player = _l3_player
	_player.allow_self_reset = false
	_player.set_spawn_point(START_SPAWN)
	_player.set_recovery_intercept_enabled(true)
	_player.reset_to_spawn("level_start", false)
	_player.polarity_changed.connect(_on_player_polarity_changed)
	_player.reset_performed.connect(_on_player_reset_performed)
	_player.attack_hit_window.connect(_on_player_attack_hit_window)
	_player.attack_started.connect(_on_player_attack_started)
	_player.recovery_transition_requested.connect(_on_player_recovery_transition_requested)
	core_released.connect(_on_core_released)

	_build_pickup()
	_build_checkpoint_mark()
	_guard.set_player_target(_player)
	_guard.reset_state(GUARD_SPAWN, true, false)
	_l3_player.set_strike_source(_guard)
	_connect_guard()
	_connect_link()
	_gate.door_opened.connect(_on_gate_opened)
	# The rise cue starts with the accepted insert, not with the 0.62 passable
	# threshold (door_opened) and not with the visual plate finishing.
	_gate.insert_started.connect(_on_gate_insert_started)
	_float_route.set_player_target(_player)
	_float_route.all_stable.connect(_on_float_all_stable)
	_float_route.block_warning.connect(_on_float_block_warning)
	_float_route.block_dropped.connect(_on_float_block_dropped)

	_link.reset_link()
	activate(_player, null)
	add_player_force_provider(_link)
	add_player_force_provider(_guard)

	_cine.setup(self, _l3_player, _guard, _gate)
	_cine.finished.connect(_on_cinematic_finished)
	_cine.stone_cue_requested.connect(_on_cine_stone_cue)
	_setup_pause_menu()
	_setup_process_modes()
	_checkpoint.checkpoint_entered.connect(_on_checkpoint_entered)

	if get_window() != null:
		get_window().focus_exited.connect(_on_window_focus_exited)
		get_window().focus_entered.connect(_on_window_focus_entered)

	_hud03.setup_player(_l3_player)
	_camera.reset_smoothing()
	_hud03.show_completion(false)
	_hud03.set_pause_visible(false)
	_hud03.set_polarity(true)
	# The demo-end page owns two real commands. They are connected exactly once
	# per level instance; the button signals are the only triggers.
	if not _hud03.replay_requested.is_connected(_on_hud_replay_requested):
		_hud03.replay_requested.connect(_on_hud_replay_requested)
	if not _hud03.return_to_menu_requested.is_connected(_on_hud_return_to_menu_requested):
		_hud03.return_to_menu_requested.connect(_on_hud_return_to_menu_requested)
	# A Space/Enter that activated the level-02 completion page (or any menu) is
	# still in the current input dispatch when this scene is created. Release the
	# one-shot actions and hold the approved input override for three ticks so
	# the confirm key cannot become a jump on the first level-03 frames.
	LEVEL_FLOW.release_one_shot_actions()
	_player.begin_input_override()
	_replay_guard_ticks = 3
	_update_level_hud()


func _setup_process_modes() -> void:
	for node: Node in [
		$Background, $Bays, $Core, $Player, $RuneField, $PolarityLink,
		$LinkController, $FixedDevice, $FloatRoute, $Guard, $Gate, $Cine,
		$Terrain, $Decorations, $Audio
	]:
		if node != null:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE
	$HUD.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS


## World cues are scene-local: a real scene change must not carry a rise or a
## completion tail into the next scene. UI clicks finish naturally.
func _exit_tree() -> void:
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


func _build_checkpoint_mark() -> void:
	_checkpoint_mark = Sprite2D.new()
	_checkpoint_mark.name = "CheckpointMark"
	_checkpoint_mark.texture = preload("res://assets/level03_prototype/float_glow_64_8f.png")
	_checkpoint_mark.hframes = 8
	_checkpoint_mark.vframes = 1
	_checkpoint_mark.centered = true
	_checkpoint_mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_checkpoint_mark.scale = Vector2(0.45, 0.45)
	_checkpoint_mark.modulate = Color(0.55, 0.95, 1.0, 0.0)
	_checkpoint_mark.z_index = 3
	_checkpoint_mark.visible = false
	_checkpoint_mark.global_position = _checkpoint.global_position + Vector2(0.0, -10.0)
	add_child(_checkpoint_mark)


func _build_pickup() -> void:
	_key_pickup = Sprite2D.new()
	_key_pickup.name = "KeyCorePickup"
	_key_pickup.texture = KEY_CORE_SHEET
	_key_pickup.hframes = 12
	_key_pickup.vframes = 1
	_key_pickup.centered = true
	_key_pickup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_key_pickup.z_index = 6
	_key_pickup.visible = false
	add_child(_key_pickup)


func _connect_guard() -> void:
	_guard.charge_started.connect(_on_guard_charge_started)
	_guard.slam_contact.connect(_on_guard_slam_contact)
	_guard.gravity_release.connect(_on_guard_gravity_release)
	_guard.player_struck.connect(_on_guard_player_struck)
	_guard.true_damage_dealt.connect(_on_guard_true_damage)
	_guard.shattered.connect(_on_guard_shattered)
	_guard.reassembly_started.connect(_on_guard_reassembly_started)
	_guard.reassembled.connect(_on_guard_reassembled)
	_guard.waiting_teaching_rubble.connect(_on_guard_waiting_teaching_rubble)
	_guard.defeated.connect(_on_guard_defeated)
	_guard.polarity_changed.connect(_on_guard_polarity_changed)


func _connect_link() -> void:
	_link.pulse_started.connect(_on_link_pulse_started)
	_link.field_committed.connect(_on_link_field_committed)


func _setup_pause_menu() -> void:
	_pause_menu = PAUSE_MENU_SCRIPT.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.level_node = self
	_pause_menu.audio_settings_path = pause_audio_settings_path
	_pause_menu.display_settings_path = pause_display_settings_path
	_pause_menu.controls_rows = [
		["移动", "A / D · ← / →"],
		["奔跑", "左Shift"],
		["跳跃", "空格"],
		["切换相性", "Q"],
		["挥击", "J（异相有效）"],
		["操作 / 取核 / 嵌核", "E"],
		["失败恢复", "最近稳定点"],
		["整关重来", "R"],
		["暂停菜单", "Esc"],
	]
	add_child(_pause_menu)
	_pause_menu.restart_requested.connect(_restart_level)
	_pause_menu.return_to_menu_requested.connect(_return_to_main_menu)
	_pause_menu.opened.connect(_on_pause_opened)
	_pause_menu.resumed.connect(_on_pause_resumed)


func _physics_process(delta: float) -> void:
	if get_tree().paused or _completed or _resetting or _scene_leaving or _recovery_active:
		return
	if _retry_pending:
		_retry_pending_left = maxf(_retry_pending_left - delta, 0.0)
		if _retry_pending_left <= 0.0:
			_retry_pending = false
			_begin_recovery("combat_retry")
			return
	if _replay_guard_ticks > 0:
		_replay_guard_ticks -= 1
		_player.begin_input_override()
		if _replay_guard_ticks <= 0:
			_player.end_input_override()
		return
	if _cine.is_active():
		return
	super._physics_process(delta)
	if _player == null:
		return
	if _cine.is_active():
		return
	_check_cinematic_trigger()
	_check_city_entry()
	_update_level_hud()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_advance_recovery(delta)
	if _checkpoint_mark != null and _checkpoint_mark.visible:
		_checkpoint_mark_time += delta
		_checkpoint_mark.frame = int(_checkpoint_mark_time * 8.0) % 8
		_checkpoint_mark.modulate.a = 0.55 + 0.25 * (0.5 + 0.5 * sin(_checkpoint_mark_time * 3.0))
	if _key_pickup == null or not _key_pickup.visible:
		return
	_key_time += delta
	_key_pickup.frame = int(_key_time * 12.0) % 12
	if _key_carried and _player != null:
		var facing: float = float(_player.get_facing())
		_key_pickup.global_position = _player.global_position + Vector2(facing * 13.0, -23.0)
	else:
		var bob: int = 0 if fmod(_key_time, 1.2) < 0.6 else -1
		_key_pickup.global_position = _key_drop_position + Vector2(0.0, float(bob))


func _input(event: InputEvent) -> void:
	if _scene_leaving or _completed or _resetting or _recovery_active or get_tree().paused:
		return
	if _cine.is_active():
		return
	if _player == null or not is_instance_valid(_player):
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	_player.handle_key_event(key_event)
	if key_event.echo:
		return
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)
	if code == int(KEY_J):
		if key_event.pressed:
			if not _attack_key_down:
				_attack_key_down = true
				_l3_player.request_attack()
				get_viewport().set_input_as_handled()
		else:
			_attack_key_down = false


# --- E routing -------------------------------------------------------------

func _try_interact() -> void:
	if _cine.is_active() or _completed or _resetting or _recovery_active:
		return
	if _player == null:
		return
	var player_pos: Vector2 = _player.global_position

	if _device.is_player_in_range(player_pos):
		if not _device.is_active():
			_activate_device()
			return
		_start_float_route()
		return

	if not _key_taken and _key_pickup != null and _key_pickup.visible:
		if _key_pickup.global_position.distance_to(player_pos + Vector2(0.0, -15.0)) <= KEY_PICKUP_RANGE:
			_take_key_core()
			return

	if _key_taken and not _key_embedded:
		if _gate.can_embed(player_pos):
			_embed_key_core()
			return
		if absf(player_pos.x - _gate.global_position.x) <= 90.0:
			_hud03.show_symbol("?", _gate.get_socket_world_position())
			return

	if _key_embedded or _gate.is_open():
		return

	if absf(player_pos.x - _gate.global_position.x) <= 70.0 and not _key_taken:
		_hud03.show_symbol("?", _gate.get_socket_world_position())
		return

	super._try_interact()


func _activate_device() -> void:
	_device.activate()
	_audio.play_core_seat()
	_stable_stage = maxi(_stable_stage, STAGE_DEVICE)
	_stable_player_positive = _player.is_positive()
	_stable_spawn = DEVICE_SPAWN
	_player.set_spawn_point(_stable_spawn)
	_start_float_route()
	_update_level_hud()


func _start_float_route() -> void:
	_float_route.start_cycle()
	if not _float_rule_shown:
		_float_rule_shown = true
		_hud03.show_event("踏过的石板会逐渐松动", 1.4)
	_update_level_hud()
func _take_key_core() -> void:
	_key_taken = true
	_key_carried = true
	_key_pickup.visible = true
	DemoAudio.play_core_take()
	_update_level_hud()


func _embed_key_core() -> void:
	if not _gate.insert_core():
		return
	_key_embedded = true
	_key_carried = false
	_key_pickup.visible = false
	DemoAudio.play_core_seat()
	_update_level_hud()


func _on_gate_insert_started() -> void:
	DemoAudio.play_gate()


func _on_gate_opened() -> void:
	_update_level_hud()


# --- store / rune ----------------------------------------------------------

func _on_core_stored_in_bay(bay: StarCoreBayInteractable, core_positive: bool) -> void:
	DemoAudio.play_core_seat()
	if bay == _target_bay:
		_stable_stage = maxi(_stable_stage, STAGE_RUNE)
		_stable_core_positive = core_positive
		_stable_player_positive = _player.is_positive()
		_stable_spawn = RUNE_SPAWN
		_player.set_spawn_point(_stable_spawn)
		var label: String = "辉相" if core_positive else "澜相"
	_update_level_hud()


func _complete_store() -> void:
	super._complete_store()
	_update_level_hud()


func _on_core_released() -> void:
	DemoAudio.play_core_take()
	_update_level_hud()


func _on_link_pulse_started(_positive: bool) -> void:
	pass


func _on_link_field_committed(positive: bool) -> void:
	var label: String = "辉相" if positive else "澜相"
	DemoAudio.play_link()
	_update_level_hud()


# --- guard events ----------------------------------------------------------

func _on_guard_charge_started(_positive: bool) -> void:
	if not _completed:
		_audio.play_charge()


func _on_guard_slam_contact(_facing: int) -> void:
	_audio.stop_charge(0.08)
	_audio.play_slam()


func _on_guard_gravity_release(_positive: bool) -> void:
	_audio.stop_charge(0.05)
	_audio.play_slam()


func _on_guard_player_struck(_facing: int) -> void:
	if _completed or _resetting or _recovery_active or _cine.is_active():
		return
	if _retry_pending:
		# The second accepted hit already owns the retry; a stray third signal
		# during the 0.15 s window changes nothing.
		return
	_player_hits += 1
	DemoAudio.play_player_hurt()
	_hud03.set_hits(_player_hits)
	if _player_hits >= 2:
		_begin_retry_pending()


## Keep the second hit's existing 0.15 s reaction/red/knockback visible first;
## the approved cover then fades in and performs the retry at black. A signal
## without a real reaction (older harness setups) falls through on the next
## physics tick instead of waiting artificially.
func _begin_retry_pending() -> void:
	_retry_pending = true
	_retry_pending_left = maxf(_l3_player.get_hit_reaction_remaining(), 0.0)


func _clear_retry_pending() -> void:
	_retry_pending = false
	_retry_pending_left = 0.0


# --- local recovery transition ---------------------------------------------
#
# Second accepted hit: the existing 0.15 s reaction/red/knockback finishes,
# then this level fades a full-screen cover to true alpha 1. Only at that
# moment does it call the already-approved current-fight retry or the existing
# stable restore. Black is held 0.10 s, then the normal scene fades back in
# over 0.35 s before control and the guard return. No new invulnerability,
# checkpoint, death text or long animation is added.

func _begin_recovery(kind: String) -> void:
	if _recovery_active or _completed or _resetting or _scene_leaving:
		return
	_clear_retry_pending()
	_recovery_active = true
	_recovery_kind = kind
	# One failure cue per real recovery entry. R / the completion page's replay
	# go through _cancel_recovery/_restart_level and never reach this branch.
	DemoAudio.play_failure()
	_recovery_phase = RecoveryPhase.FADE_OUT
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_attack_key_down = false
	# The red/reaction is not cleared here: it has already played its full
	# window and disappears only with the real reset at black.
	_hud03.set_gameplay_visible(true)
	_hud03.set_recovery_alpha(0.0)
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	_player.cancel_attack()
	_player.begin_recovery_hold()
	_guard.set_suspended(true)
	_update_level_hud()


func _advance_recovery(delta: float) -> void:
	if not _recovery_active:
		return
	_recovery_elapsed += delta
	match _recovery_phase:
		RecoveryPhase.FADE_OUT:
			_recovery_alpha = clampf(_recovery_elapsed / RECOVERY_FADE_OUT_TIME, 0.0, 1.0)
			_apply_recovery_alpha()
			if _recovery_alpha >= 1.0:
				_recovery_phase = RecoveryPhase.BLACK_HOLD
				_recovery_elapsed = 0.0
				_apply_recovery_reset()
		RecoveryPhase.BLACK_HOLD:
			_recovery_alpha = 1.0
			_apply_recovery_alpha()
			if _recovery_elapsed >= RECOVERY_BLACK_HOLD_TIME:
				_recovery_phase = RecoveryPhase.FADE_IN
				_recovery_elapsed = 0.0
				# The body is already reset at black; the return cue belongs to
				# the start of the visible fade-in, exactly once.
				DemoAudio.play_respawn()
		RecoveryPhase.FADE_IN:
			_recovery_alpha = clampf(
				1.0 - _recovery_elapsed / RECOVERY_FADE_IN_TIME, 0.0, 1.0)
			_apply_recovery_alpha()
			if _recovery_alpha <= 0.0:
				_finish_recovery()


func _apply_recovery_alpha() -> void:
	_hud03.set_recovery_alpha(_recovery_alpha)


## Called exactly once, only when the cover has really reached alpha 1.
func _apply_recovery_reset() -> void:
	if _recovery_applying:
		return
	_recovery_applying = true
	_recovery_reset_alpha = _recovery_alpha
	_recovery_pre_reset_position = _player.global_position
	if _recovery_kind == "fall":
		# L3Player still holds the body, so this real fall reset performs once
		# inside the existing stable restore; stage/spawn/teaching are unchanged.
		_restore_stable("fall")
	else:
		_retry_combat()
	# The reset above re-enables the body and clears the movement override.
	# Hold it again so black hold plus fade-in cannot accept input; only
	# _finish_recovery() hands control back at alpha 0.
	_player.begin_recovery_hold()
	if not _completed and not _scene_leaving:
		_guard.set_suspended(true)
	_recovery_reset_position = _player.global_position
	_recovery_reset_count += 1
	_recovery_applying = false


func _finish_recovery() -> void:
	if not _recovery_active:
		return
	_recovery_active = false
	_recovery_phase = RecoveryPhase.NONE
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_hud03.set_recovery_alpha(0.0)
	_player.end_recovery_hold()
	_player.end_input_override()
	_player.clear_input_buffers()
	_player.clear_external_force()
	_attack_key_down = false
	# A held E/Space/Enter from the black frames must not become an interaction
	# or a jump on the first restored tick.
	LEVEL_FLOW.release_one_shot_actions()
	if not _completed and not _scene_leaving and not get_tree().paused:
		_guard.set_suspended(not _window_has_focus)
	_recovery_finished_count += 1
	_update_level_hud()


## Used by R, pause-return, completion and a failed scene leave. It never runs
## the deferred reset itself. restore_control=false keeps the player frozen for
## an imminent scene change, so a fall cannot re-trigger behind a fresh cover.
func _cancel_recovery(restore_control: bool = true) -> void:
	_recovery_active = false
	_recovery_phase = RecoveryPhase.NONE
	_recovery_elapsed = 0.0
	_recovery_alpha = 0.0
	_recovery_kind = ""
	_recovery_applying = false
	if _hud03 != null:
		_hud03.set_recovery_alpha(0.0)
	if _player != null and is_instance_valid(_player):
		if restore_control:
			_player.end_recovery_hold()
			if not _cine.is_active() and not _completed:
				_player.end_input_override()
		else:
			_player.begin_recovery_hold()


func _on_player_recovery_transition_requested(reason: String) -> void:
	if reason != "fall" or _recovery_active:
		return
	_begin_recovery("fall")


func _on_guard_true_damage(taken: int, remaining: int) -> void:
	_update_level_hud()


func _on_guard_shattered() -> void:
	DemoAudio.play_shell_shatter()
	_update_level_hud()


func _on_guard_reassembly_started() -> void:
	_audio.play_reassemble()


func _on_guard_reassembled() -> void:
	_update_level_hud()


func _on_guard_waiting_teaching_rubble() -> void:
	_update_level_hud()


func _on_guard_defeated() -> void:
	_key_drop_position = _guard.get_key_core_drop_position()
	_key_pickup.visible = true
	_key_pickup.global_position = _key_drop_position
	_key_time = 0.0
	_player_hits = 0
	_hud03.set_hits(0)
	_audio.stop_charge(0.05)
	_update_level_hud()


func _on_guard_polarity_changed(_positive: bool) -> void:
	_update_level_hud()


func _on_player_attack_hit_window(swing_id: int, facing: int, positive: bool) -> void:
	if _completed or _cine.is_active() or _resetting or _recovery_active:
		return
	if _resolved_swings.has(swing_id):
		return
	_resolved_swings[swing_id] = true
	var result: Dictionary = _guard.receive_player_hit(_player, facing, positive, swing_id)
	_update_level_hud()


## Emitted only by a successful request_attack(): cooldown, an active swing, a
## completion/cinematic lock or a paused/rejected input never reaches it.
func _on_player_attack_started(_swing_id: int, _facing: int, _positive: bool) -> void:
	DemoAudio.play_swing()


func _on_checkpoint_entered(checkpoint: LevelCheckpoint) -> void:
	if _completed or checkpoint == null:
		return
	if _stable_stage >= STAGE_ARENA:
		return
	_stable_stage = STAGE_ARENA
	_stable_player_positive = _player.is_positive()
	_stable_core_positive = _target_bay.get_recorded_positive()
	_stable_spawn = ARENA_SPAWN
	_player.set_spawn_point(_stable_spawn)
	_checkpoint.set_activated(true)
	if _checkpoint_mark != null:
		_checkpoint_mark.visible = true
		_checkpoint_mark_time = 0.0
	_float_route.finish_crossing()
	_update_level_hud()


# --- float events ----------------------------------------------------------

func _on_float_all_stable() -> void:
	_audio.play_float_settle()
	_update_level_hud()


func _on_float_block_warning(index: int) -> void:
	_audio.play_float_warn()


func _on_float_block_dropped(_index: int) -> void:
	_audio.play_float_settle()
	_update_level_hud()


func _is_combat_active() -> bool:
	if _completed or _cine.is_active():
		return false
	if _guard == null or _guard.is_defeated() or _guard.is_waiting_teaching_rubble():
		return false
	if _player == null:
		return false
	if absf(_player.global_position.y - 320.0) > 40.0:
		return false
	return absf(_player.global_position.x - _guard.global_position.x) <= 165.0


# --- cinematic / city ------------------------------------------------------

func _check_cinematic_trigger() -> void:
	if _cine.has_played() or _cine.is_active() or _completed:
		return
	if _gate.is_open():
		return
	if not _guard.is_waiting_teaching_rubble():
		return
	if _player.global_position.x < CINE_TRIGGER_X:
		return
	if _player.global_position.y < 245.0 or _player.global_position.y > 335.0:
		return
	_start_cinematic()


func _start_cinematic() -> void:
	_clear_retry_pending()
	_hud03.set_gameplay_visible(false)
	_player.lock_for_cinematic()
	_cine.play()


func _on_cinematic_finished(_skipped: bool) -> void:
	_hud03.set_gameplay_visible(true)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_attack_key_down = false
	# One independent key reminder after the first real hand-back; it never
	# repeats on in-combat shatter or retry, only on R.
	_hud03.show_control_hint(3.0)
	_update_level_hud()
func _on_cine_stone_cue() -> void:
	_audio.play_stone_cue()


func before_pause_opened() -> void:
	if _cine.is_active():
		_cine.abort()
		_hud03.set_gameplay_visible(true)
		_player.clear_input_buffers()
		_update_level_hud()


func _on_pause_opened() -> void:
	# A decided second-hit retry is NOT cancelled by opening pause. Its 0.15 s
	# countdown is frozen by the tree pause and resumes into one recovery.
	# Only the visible red/reaction/knockback is cleared here.
	_l3_player.clear_hit_feedback()
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	if _recovery_active:
		# The recovery clock and its black cover freeze with the tree pause.
		# Keep the body held and re-assert the movement override that
		# clear_hit_feedback may just have released.
		_player.begin_input_override()
		_player.set_input_override_axis(0.0, false)
		_player.begin_recovery_hold()
		_guard.set_suspended(true)
	_hud03.set_pause_visible(true)
	_hud03.release_completion_focus()


func _on_pause_resumed() -> void:
	_hud03.set_pause_visible(false)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.reset_movement_input_state()
	if _recovery_active:
		# Resume continues the same approved transition; the guard stays hung
		# until the fade-in really ends.
		_player.begin_input_override()
		_player.set_input_override_axis(0.0, false)
		_player.begin_recovery_hold()
		_guard.set_suspended(true)
		_update_level_hud()
		return
	if not _completed:
		_guard.set_suspended(false)
	# The second hit already decided this fight's retry before the pause. R and
	# 返回 close the pause page without emitting resumed and still clear the
	# pending themselves, so only a real resume lands here.
	if not _completed and not _resetting and not _scene_leaving \
			and (_retry_pending or _player_hits >= 2):
		_clear_retry_pending()
		_begin_recovery("combat_retry")
	if _completed:
		_hud03.focus_completion_primary()
	_update_level_hud()


func is_pause_menu_blocked() -> bool:
	return false


func _on_window_focus_exited() -> void:
	_window_has_focus = false
	if _completed:
		return
	if _cine.is_active():
		_cine.abort()
		_hud03.set_gameplay_visible(true)
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	_attack_key_down = false
	if _recovery_active:
		_player.begin_input_override()
		_player.set_input_override_axis(0.0, false)
		_player.begin_recovery_hold()
	_guard.set_suspended(true)


func _on_window_focus_entered() -> void:
	_window_has_focus = true
	if _completed or get_tree().paused or _recovery_active:
		return
	_guard.set_suspended(false)
	_player.clear_input_buffers()
	_player.reset_movement_input_state()
	_update_level_hud()


func _check_city_entry() -> void:
	if _completed or not _gate.is_open():
		return
	if _player.global_position.x < CITY_ENTER_X:
		return
	if _player.global_position.y < 240.0 or _player.global_position.y > 340.0:
		return
	_complete_city()


func _complete_city() -> void:
	if _completed:
		return
	_cancel_recovery()
	_completed = true
	_completion_count += 1
	_clear_retry_pending()
	DemoAudio.play_complete()
	_audio.stop_all()
	if _cine.is_active():
		_cine.abort()
	_guard.set_suspended(true)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.lock_completion_input()
	_hud03.set_pause_visible(false)
	_hud03.show_completion(true, _completion_count)
	if _pause_menu != null:
		_pause_menu.set_completion_active(true)
	_update_level_hud()
	level_completed.emit()


func _on_player_polarity_changed(positive: bool) -> void:
	# Real Q only: reset/spawn returns the counter to 0 and a scripted
	# set_polarity_state (retry/recovery) emits without incrementing.
	var toggles: int = _player.get_polarity_toggle_count()
	if toggles > _last_polarity_toggles:
		DemoAudio.play_polarity_switch()
	_last_polarity_toggles = toggles
	if _hud03 != null:
		_hud03.set_polarity(positive)
	_update_level_hud()


func _on_player_reset_performed(reason: String, _count: int) -> void:
	if _resetting or _recovery_active:
		return
	_restore_stable(reason)


func on_player_reset(reason: String) -> void:
	if _resetting or _recovery_active:
		return
	_restore_stable(reason)


func _handle_core_out_of_bounds() -> void:
	if _resetting:
		return
	_restore_stable("core_out")


# --- two-hit retry ---------------------------------------------------------

func _retry_combat() -> void:
	if _resetting or _completed or _retrying:
		return
	_clear_retry_pending()
	_retrying = true
	_resetting = true
	if _cine.is_active():
		_cine.abort()
	_stable_stage = STAGE_ARENA
	_stable_player_positive = _player.is_positive()
	_stable_core_positive = _target_bay.get_recorded_positive()
	_stable_spawn = ARENA_SPAWN
	_player_hits = 0
	_hud03.set_hits(0)
	var was_waiting: bool = _guard.is_waiting_teaching_rubble()
	var taught: bool = _guard.has_teaching_seen() or _cine.has_played()
	_rebuild_world_for_stage()
	if was_waiting:
		# The real first-invalid-shatter fact must survive a two-hit retry: the
		# guard keeps waiting for the one-shot teaching instead of quietly
		# becoming "taught".
		_guard.restore_waiting_rubble(GUARD_SPAWN)
	else:
		_guard.reset_state(GUARD_SPAWN, true, taught)
	_guard.set_player_target(_player)
	_player.set_spawn_point(ARENA_SPAWN)
	_player.reset_to_spawn("combat_retry", true)
	_player.set_polarity_state(_stable_player_positive)
	_player.global_position = ARENA_SPAWN
	_player.velocity = Vector2.ZERO
	_player.clear_input_buffers()
	_player.clear_external_force()
	_camera.reset_smoothing()
	_resetting = false
	_retrying = false
	_hud03.show_event("再试一次", 1.6)
	_update_level_hud()


# --- restore / restart -----------------------------------------------------

func _restore_stable(reason: String) -> void:
	_clear_retry_pending()
	if _resetting or _player == null:
		return
	_resetting = true
	if _cine.is_active():
		_cine.abort()
	_hud03.set_gameplay_visible(true)
	if _pause_menu != null:
		_pause_menu.set_completion_active(false)
	_hud03.show_completion(false)
	_hud03.set_pause_visible(false)
	_completed = false
	_attack_key_down = false
	_resolved_swings.clear()
	_player_hits = 0
	_hud03.set_hits(0)
	_rebuild_world_for_stage()
	_player.set_spawn_point(_stable_spawn)
	_player.reset_to_spawn(reason, true)
	_player.set_polarity_state(_stable_player_positive)
	_player.global_position = _stable_spawn
	_player.velocity = Vector2.ZERO
	_player.clear_input_buffers()
	_player.clear_external_force()
	_camera.reset_smoothing()
	_resetting = false
	if reason != "debug_setup":
		match reason:
			"fall":
				if _stable_stage == STAGE_DEVICE:
					_hud03.show_event("跌落 · 回装置前", 1.6)
				else:
					_hud03.show_event("跌落 · 回恢复点", 1.4)
			"core_out":
				_hud03.show_event("运输核越界 · 回最近稳定点", 1.8)
			"combat_retry":
				_hud03.show_event("再试一次", 1.4)
			_:
				_hud03.show_event("已回最近稳定点", 1.2)
	_update_level_hud()


func _clear_room_runtime() -> void:
	if _store_bay != null:
		_store_bay.stop_animation()
	_pending_release = false
	_pending_positive = true
	_release_bay = null
	_store_bay = null
	_success = false
	_last_status = STATUS_LOCKED
	_last_distance = 0.0
	_last_force = Vector2.ZERO
	_last_core_player_force = Vector2.ZERO
	_last_extra_player_force = Vector2.ZERO
	_last_extra_status = ""
	_last_extra_distance = 0.0
	_last_player_force = Vector2.ZERO
	_last_blocked = false
	_last_e_preview = ""
	_last_store_hint = ""
	if _player != null:
		_player.clear_external_force()
	if _core != null:
		_core.clear_external_force()


func _rebuild_world_for_stage() -> void:
	_clear_room_runtime()
	_start_bay.reset_empty()
	_target_bay.reset_empty()
	if _stable_stage == STAGE_START:
		_start_bay.reset_locked()
		_core.global_position = _start_bay.get_store_center()
		_core.deactivate()
		_link.reset_link()
	else:
		_target_bay.start_store_core(_stable_core_positive)
		_target_bay.finish_store()
		_core.global_position = _target_bay.get_store_center()
		_core.deactivate()
		_link.reset_link()
		_link.restore_committed(_stable_core_positive, true)

	_device.reset_state()
	if _stable_stage >= STAGE_DEVICE:
		_device.activate()
	_float_route.reset_idle()
	_float_route.set_player_target(_player)

	var guard_defeated: bool = _guard.is_defeated()
	if guard_defeated:
		if _gate.is_open():
			pass
		elif not _key_taken:
			_gate.reset_state()
			_key_pickup.visible = true
			_key_pickup.global_position = _key_drop_position
	elif _guard.is_waiting_teaching_rubble() and not _cine.has_played():
		_guard.restore_waiting_rubble(GUARD_SPAWN)
		_gate.reset_state()
		_key_taken = false
		_key_carried = false
		_key_embedded = false
		_key_pickup.visible = false
	else:
		_guard.reset_state(GUARD_SPAWN, true, _cine.has_played())
		_gate.reset_state()
		_key_taken = false
		_key_carried = false
		_key_embedded = false
		_key_pickup.visible = false
	_checkpoint.set_activated(_stable_stage >= STAGE_ARENA)
	if _checkpoint_mark != null:
		_checkpoint_mark.visible = _checkpoint.is_activated()
	if _checkpoint.is_activated():
		_float_route.finish_crossing()
	if _checkpoint_mark != null:
		_checkpoint_mark.visible = _checkpoint.is_activated()
		_checkpoint_mark.modulate.a = 0.75 if _checkpoint.is_activated() else 0.0


func _reset_room_state() -> void:
	super._reset_room_state()
	_clear_room_runtime()
	_start_bay.reset_empty()
	_target_bay.reset_empty()
	_start_bay.reset_locked()
	_core.global_position = _start_bay.get_store_center()
	_core.deactivate()
	_link.reset_link()
	_device.reset_state()
	_float_route.reset_idle()
	_guard.reset_state(GUARD_SPAWN, true, false)
	_gate.reset_state()
	_checkpoint.set_activated(false)
	_stable_stage = STAGE_START
	_stable_core_positive = true
	_stable_player_positive = true
	_stable_spawn = START_SPAWN
	_key_taken = false
	_key_embedded = false
	_key_carried = false
	_key_drop_position = GUARD_SPAWN + Vector2(0.0, -10.0)
	_player_hits = 0
	_resolved_swings.clear()
	if _key_pickup != null:
		_key_pickup.visible = false


func _restart_level() -> void:
	if _scene_leaving:
		return
	_cancel_recovery()
	_clear_retry_pending()
	_replay_pending = false
	if _pause_menu != null:
		_pause_menu.force_close()
		_pause_menu.set_completion_active(false)
	get_tree().paused = false
	# A Space/Enter used on the completion page must not become a jump on the
	# first tick of the fresh run.
	LEVEL_FLOW.release_one_shot_actions()
	_resetting = true
	_float_rule_shown = false
	_cine.reset_for_new_run()
	_hud03.set_gameplay_visible(true)
	_hud03.show_completion(false)
	# The page may have been disabled by a failed return attempt, and the replay
	# button must work again on the next completion.
	_hud03.set_completion_buttons_enabled(true)
	_hud03.set_pause_visible(false)
	_completed = false
	_attack_key_down = false
	_reset_room_state()
	_player.set_spawn_point(START_SPAWN)
	# Reuses the subclass reset: it clears the completion lock and the input
	# override, so real A/D input moves the body again on the next tick.
	_player.reset_to_spawn("level_restart", true)
	_player.set_polarity_state(true)
	_player.global_position = START_SPAWN
	_player.velocity = Vector2.ZERO
	_player.clear_input_buffers()
	_player.clear_external_force()
	_camera.reset_smoothing()
	_resetting = false
	# Keep the body still for three physics ticks with the existing input
	# override, so the key that activated 重玩本关 cannot become a jump.
	_replay_guard_ticks = 3
	_player.begin_input_override()
	_hud03.set_polarity(true)
	_hud03.set_hits(0)
	_hud03.show_event("本关已重新开始", 1.4)
	_hud03.show_control_hint(3.0)
	_update_level_hud()


## Demo-end page: "重玩本关". The page's own button signal is the only source.
## The restart waits two frames: the Space/Enter that activated the button (or
## any key still held) must be fully consumed before the body can move again,
## otherwise the same press would become a jump on the fresh run.
func _on_hud_replay_requested() -> void:
	if _scene_leaving or _resetting or _replay_pending:
		return
	_replay_pending = true
	LEVEL_FLOW.release_one_shot_actions()
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_replay()


func _finish_replay() -> void:
	_replay_pending = false
	if _scene_leaving:
		return
	_restart_level()


## Demo-end page: "返回主界面". Real SceneTree change to the level-flow title
## scene; the test harness may stay alive as a separate root child.
func _on_hud_return_to_menu_requested() -> void:
	_return_to_main_menu()


func _return_to_main_menu() -> void:
	if _scene_leaving:
		return
	# Freeze the body and clear the cover without re-enabling physics: if the
	# scene change fails, _verify_title_transition restores control safely.
	_cancel_recovery(false)
	_clear_retry_pending()
	_player.clear_hit_feedback()
	if not ResourceLoader.exists(LEVEL_FLOW.LEVEL_01_PATH):
		# Visible failure, buttons usable again - never a dead page or a frozen body.
		_player.end_recovery_hold()
		if not _completed:
			_player.end_input_override()
			_guard.set_suspended(not _window_has_focus)
		_hud03.set_completion_buttons_enabled(true)
		_hud03.show_event("无法返回主界面", 1.8)
		_hud03.focus_completion_primary()
		return
	_scene_leaving = true
	_hud03.set_completion_buttons_enabled(false)
	_hud03.release_completion_focus()
	_hud03.set_pause_visible(false)
	if _cine.is_active():
		_cine.abort()
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	_attack_key_down = false
	_guard.set_suspended(true)
	if _pause_menu != null:
		_pause_menu.prepare_scene_change()
	LEVEL_FLOW.return_to_title(get_tree())
	call_deferred("_verify_title_transition")


## If the change did not commit (only possible when this node is still the
## running scene), show it and give the page its buttons back.
func _verify_title_transition() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene != self:
		return
	_scene_leaving = false
	_player.end_recovery_hold()
	_player.end_input_override()
	_player.clear_input_buffers()
	_player.clear_external_force()
	if not _completed and not get_tree().paused:
		_guard.set_suspended(not _window_has_focus)
	_hud03.set_completion_buttons_enabled(true)
	_hud03.show_event("无法返回主界面", 1.8)
	_hud03.focus_completion_primary()


# --- HUD / guide -----------------------------------------------------------

func _update_level_hud() -> void:
	if _hud03 == null or _player == null:
		return
	_hud03.set_polarity(_player.is_positive())
	var phase: String = "送核入符石仓"
	var target: Vector2 = RUNE_TARGET
	var stage_key: String = "store"
	var show_guide: bool = true
	if _completed:
		phase = "已完成"
		show_guide = false
	elif _gate.is_open():
		phase = "走入城内"
		target = CITY_TARGET
		stage_key = "city"
	elif _key_embedded and not _gate.is_open():
		phase = "城门正在开启"
		target = GATE_TARGET
		stage_key = "opening"
	elif _key_taken and not _key_embedded:
		phase = "嵌入城门"
		target = GATE_TARGET
		stage_key = "gate"
	elif _guard != null and _guard.is_defeated():
		phase = "取走守卫核心"
		target = _key_drop_position
		stage_key = "key"
	elif _guard != null and _guard.is_waiting_teaching_rubble():
		phase = "石壳已碎 · 去门前"
		target = GATE_TARGET
		stage_key = "waiting"
	elif _stable_stage >= STAGE_ARENA:
		phase = "击败守卫取核"
		target = GUARD_TARGET
		stage_key = "guard"
	elif _device.is_active() or _stable_stage >= STAGE_DEVICE:
		phase = "渡过浮地"
		target = FLOAT_TARGET
		stage_key = "float"
	elif _stable_stage >= STAGE_RUNE or _target_bay.has_core():
		phase = "借符石上升 · 回左上高台"
		if _player.global_position.y < 240.0:
			target = DEVICE_TARGET
			stage_key = "device_air"
		else:
			target = _rune_field.global_position + Vector2(0.0, 34.0)
			stage_key = "device_ground"
	_hud03.set_objective(phase)
	var combat: bool = _is_combat_active()
	_hud03.set_combat(combat)
	if show_guide:
		_hud03.set_guide(target, stage_key)
	else:
		_hud03.set_guide(target, stage_key)
	_hud03.set_hits(_player_hits if combat else 0)
	_update_prompt(combat)
	if _last_guide_key != stage_key:
		_last_guide_key = stage_key


func _update_prompt(combat: bool) -> void:
	var player_pos: Vector2 = _player.global_position
	var text: String = ""
	var world: Vector2 = Vector2.ZERO
	if _cine.is_active() or _completed or combat:
		_hud03.set_prompt("", Vector2.ZERO, false)
		return
	if _device.is_player_in_range(player_pos):
		text = "启动" if not _device.is_active() else "重建浮地"
		world = _device.global_position + Vector2(0.0, -28.0)
	elif not _key_taken and _key_pickup != null and _key_pickup.visible:
		if _key_pickup.global_position.distance_to(player_pos + Vector2(0.0, -15.0)) <= KEY_PICKUP_RANGE:
			text = "取核"
			world = _key_pickup.global_position + Vector2(0.0, -18.0)
	elif _key_taken and not _key_embedded and _gate.can_embed(player_pos):
		text = "嵌核"
		world = _gate.get_socket_world_position() + Vector2(0.0, -18.0)
	elif _core.is_active():
		var info: Dictionary = _find_store_bay()
		if bool(info.get("ok", false)):
			var bay = info.get("bay", null) as StarCoreBayInteractable
			if bay != null:
				text = "存入"
				world = bay.get_store_center() + Vector2(0.0, -26.0)
	else:
		var loaded: StarCoreBayInteractable = _nearest_loaded_bay()
		if loaded != null:
			text = "释放核"
			world = loaded.get_store_center() + Vector2(0.0, -26.0)
	_hud03.set_prompt(text, world, not text.is_empty())


# --- accessors / test helpers ---------------------------------------------

func get_player() -> L3Player:
	return _l3_player


func get_hud() -> L3HUD:
	return _hud03


func get_camera() -> Camera2D:
	return _camera


func get_guard() -> L3Guard:
	return _guard


func get_gate() -> L3Gate:
	return _gate


func get_device() -> L3FixedDevice:
	return _device


func get_float_route() -> L3FloatRoute:
	return _float_route


func get_cine() -> L3Cinematic:
	return _cine


func get_audio() -> Node:
	return _audio


func get_start_bay() -> StarCoreBayInteractable:
	return _start_bay


func get_target_bay() -> StarCoreBayInteractable:
	return _target_bay


func get_rune_field() -> RuneStoneField:
	return _rune_field


func get_link() -> BayRuneLink:
	return _link


func get_stable_stage() -> int:
	return _stable_stage


func get_stable_spawn() -> Vector2:
	return _stable_spawn


func get_stable_player_positive() -> bool:
	return _stable_player_positive


func get_stable_core_positive() -> bool:
	return _stable_core_positive


func is_key_taken() -> bool:
	return _key_taken


func is_key_embedded() -> bool:
	return _key_embedded


func is_completed() -> bool:
	return _completed


func get_completion_count() -> int:
	return _completion_count


func is_scene_leaving() -> bool:
	return _scene_leaving


func get_cine_trigger_x() -> float:
	return CINE_TRIGGER_X


func get_city_enter_x() -> float:
	return CITY_ENTER_X


func get_key_drop_position() -> Vector2:
	return _key_drop_position


func get_guard_spawn() -> Vector2:
	return GUARD_SPAWN


func get_arena_spawn() -> Vector2:
	return ARENA_SPAWN


func get_device_spawn() -> Vector2:
	return DEVICE_SPAWN


func get_rune_spawn() -> Vector2:
	return RUNE_SPAWN


func get_start_spawn() -> Vector2:
	return START_SPAWN


func get_device_target() -> Vector2:
	return DEVICE_TARGET


func is_checkpoint_mark_visible() -> bool:
	return _checkpoint_mark != null and _checkpoint_mark.visible


func get_player_hits() -> int:
	return _player_hits


func is_retry_pending() -> bool:
	return _retry_pending


func get_retry_pending_left() -> float:
	return _retry_pending_left


func get_pause_menu() -> Node:
	return _pause_menu


# --- recovery accessors (tests / captures) ---------------------------------

func is_recovery_active() -> bool:
	return _recovery_active


func get_recovery_phase() -> String:
	match _recovery_phase:
		RecoveryPhase.FADE_OUT:
			return "fade_out"
		RecoveryPhase.BLACK_HOLD:
			return "black_hold"
		RecoveryPhase.FADE_IN:
			return "fade_in"
		_:
			return "none"


func get_recovery_alpha() -> float:
	return _recovery_alpha


func get_recovery_kind() -> String:
	return _recovery_kind


func get_recovery_reset_alpha() -> float:
	return _recovery_reset_alpha


func get_recovery_reset_count() -> int:
	return _recovery_reset_count


func get_recovery_finished_count() -> int:
	return _recovery_finished_count


func get_recovery_pre_reset_position() -> Vector2:
	return _recovery_pre_reset_position


func get_recovery_reset_position() -> Vector2:
	return _recovery_reset_position


func get_recovery_durations() -> Dictionary:
	return {
		"fade_out": RECOVERY_FADE_OUT_TIME,
		"black_hold": RECOVERY_BLACK_HOLD_TIME,
		"fade_in": RECOVERY_FADE_IN_TIME,
	}


func get_recovery_overlay_alpha() -> float:
	return _hud03.get_recovery_alpha() if _hud03 != null else 0.0


func debug_restore_stage(stage: int, player_positive: bool = true, core_positive: bool = true) -> void:
	_stable_stage = clampi(stage, STAGE_START, STAGE_ARENA)
	_stable_core_positive = core_positive
	_stable_player_positive = player_positive
	match _stable_stage:
		STAGE_RUNE:
			_stable_spawn = RUNE_SPAWN
		STAGE_DEVICE:
			_stable_spawn = DEVICE_SPAWN
		STAGE_ARENA:
			_stable_spawn = ARENA_SPAWN
		_:
			_stable_spawn = START_SPAWN
	_restore_stable("debug_setup")


func debug_place_player_at(position: Vector2) -> void:
	if _player == null:
		return
	_player.global_position = position
	_player.velocity = Vector2.ZERO
	_player.clear_input_buffers()
	_player.clear_external_force()
	_camera.reset_smoothing()


func debug_setup_arena_combat(player_x: float = 1900.0, teaching_seen: bool = true) -> void:
	_stable_stage = STAGE_ARENA
	_stable_core_positive = _target_bay.get_recorded_positive()
	_stable_player_positive = _player.is_positive()
	_stable_spawn = ARENA_SPAWN
	_rebuild_world_for_stage()
	_guard.reset_state(GUARD_SPAWN, true, teaching_seen)
	_guard.set_player_target(_player)
	if teaching_seen:
		_cine.mark_played()
	_player_hits = 0
	_hud03.set_hits(0)
	_l3_player.set_polarity_state(true)
	debug_place_player_at(Vector2(player_x, 320.0))
	_update_level_hud()


func debug_setup_pre_teaching(player_x: float = 1900.0) -> void:
	_stable_stage = STAGE_ARENA
	_stable_core_positive = _target_bay.get_recorded_positive()
	_stable_player_positive = _player.is_positive()
	_stable_spawn = ARENA_SPAWN
	_rebuild_world_for_stage()
	_guard.reset_state(GUARD_SPAWN, true, false)
	_guard.set_player_target(_player)
	_player_hits = 0
	_hud03.set_hits(0)
	_l3_player.set_polarity_state(true)
	debug_place_player_at(Vector2(player_x, 320.0))
	_update_level_hud()


func debug_setup_gate_with_key(player_x: float = -100000.0) -> void:
	# Default: just left of wherever the gate really is (layout may move it).
	if player_x < -1000.0:
		player_x = _gate.global_position.x - 40.0
	_resetting = true
	_stable_stage = STAGE_ARENA
	_stable_core_positive = _target_bay.get_recorded_positive()
	_stable_player_positive = _player.is_positive()
	_stable_spawn = ARENA_SPAWN
	_guard.reset_state(GUARD_SPAWN, true, true)
	_guard.debug_force_death()
	_key_drop_position = GUARD_SPAWN + Vector2(0.0, -10.0)
	_key_taken = true
	_key_carried = true
	_key_embedded = false
	_key_pickup.visible = true
	_gate.reset_state()
	_submerge_for_debug_gate()
	_player.set_spawn_point(Vector2(player_x, 320.0))
	_player.reset_to_spawn("debug_setup", false)
	_player.global_position = Vector2(player_x, 320.0)
	_player.set_polarity_state(true)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_camera.reset_smoothing()
	_resetting = false
	_update_level_hud()


func _submerge_for_debug_gate() -> void:
	if not _target_bay.has_core():
		_start_bay.reset_empty()
		_target_bay.reset_empty()
		_target_bay.start_store_core(true)
		_target_bay.finish_store()
		_core.global_position = _target_bay.get_store_center()
		_core.deactivate()
		_link.reset_link()
		_link.restore_committed(true, true)
