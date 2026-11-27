class_name Level02
extends StarCoreInteractionRoom

## Formal level 02 "沉寂回廊" — unified stone ground rebuild, 1792 px.
##
## One active core. Four authored bays: start, relay, linked, final. The core
## starts in the start bay. Relay and linked stores are stable recovery points;
## only the final bay locks the exit. The linked bay records the core polarity
## through the existing BayRuneLink and lights one rune stone. The rune acts on
## the player only. The player uses it to climb the 80 px-high stone sill and
## pull the same core through the 20 px corridor to the final bay.
##
## The shared transport rules, player movement/force constants, core force,
## bay record timing, rune field and Q/E semantics are unchanged. This script
## only extends bay iteration to four authored nodes and adds checkpoint
## restore/flow.

signal level_completed

const PAUSE_MENU_SCRIPT = preload("res://scripts/ui/pause_menu.gd")
const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")
const FOOTSTEP_SCRIPT = preload("res://scripts/audio/player_footstep_audio.gd")
const CONDUCTIVE_ACTIVATION = preload("res://scripts/narrative/conductive_activation.gd")
const MECHANIC_POPUP_SCENE: PackedScene = preload("res://scenes/ui/mechanic_popup.tscn")

const STABLE_START: int = 0
const STABLE_RELAY: int = 1
const STABLE_LINKED: int = 2
const STABLE_SPAWN_START: Vector2 = Vector2(36.0, 320.0)
const STABLE_SPAWN_RELAY: Vector2 = Vector2(400.0, 320.0)
const STABLE_SPAWN_LINKED: Vector2 = Vector2(830.0, 320.0)

@export var pause_audio_settings_path: String = "user://audio_settings.cfg"
@export var pause_display_settings_path: String = "user://display_settings.cfg"

@onready var _hud02: Level02HUD = $HUD
@onready var _exit: LevelExit = $Exit
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _relay_bay: StarCoreBayInteractable = $Bays/RelayBay
@onready var _linked_bay: StarCoreBayInteractable = $Bays/LinkedBay
@onready var _final_bay: StarCoreBayInteractable = $Bays/TargetBay
@onready var _link: BayRuneLink = $LinkController
@onready var _rune_field: RuneStoneField = $RuneField
@onready var _inversion_field: RiftInversionField = $InversionField
@onready var _stele: GuideEcho = $StartStele
@onready var _relay_checkpoint: LevelCheckpoint = $RelayCheckpoint
@onready var _linked_checkpoint: LevelCheckpoint = $LinkedCheckpoint
@onready var _music: BaseLevelMusic = $BaseLevelMusic

var _all_bays: Array[StarCoreBayInteractable] = []
var _pause_menu = null
var _completed: bool = false
var _resetting: bool = false
var _completion_count: int = 0
var _last_polarity_toggles: int = 0
var _exit_was_inside: bool = false
var _scene_leaving: bool = false
var _footsteps: Node = null
## One accepted "进入第三关" press per completion; the button is disabled in the
## same call so a double click/key cannot request two scene changes.
var _next_level_started: bool = false
var _stable_stage: int = STABLE_START
var _stable_positive: bool = true
## Exactly the four approved conductive bodies. Their bodies remain on the
## normal terrain layer; only the player-core force ray excludes their RIDs.
var _special_force_rids: Array[RID] = []
## Presentation-only layer for the first relay unlock. It is created here so
## the scene file and all geometry/collision stay untouched; it reads the real
## bay/stone sprite bounds and never drives gameplay.
var _conductive_activation: ConductiveActivation = null
## Level-local progress: a completed store in RelayBay unlocks the player-core
## force ray through the four special bodies. It is never granted by StartBay,
## by merely approaching a bay, or by an unfinished store. It survives stable
## restores (fall / core out of bounds) and is cleared by R / restart / replay.
var _special_wall_unlocked: bool = false
## Pending record chime token: a new stage can complete while the core-seat cue
## is still ringing, so the record confirmation is played 0.40 s later and is
## cancelled by restart.
var _record_save_token: int = 0
var _mechanic_popup: MechanicPopup = null


func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10

	$Player.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Core.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Bays.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Background.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hud02.process_mode = Node.PROCESS_MODE_ALWAYS

	_register_special_force_bodies()
	_setup_conductive_activation()
	_all_bays = [
		$Bays/StartBay as StarCoreBayInteractable,
		_relay_bay,
		_linked_bay,
		_final_bay,
	]

	_player = $Player
	_player.allow_self_reset = false
	_player.set_anchor_horizontal_brake_enabled(true)
	_player.set_spawn_point(_spawn_marker.global_position)
	_player.reset_to_spawn("level_start", false)
	_player.polarity_changed.connect(_on_player_polarity_changed)
	_player.reset_performed.connect(_on_player_reset_performed)
	core_released.connect(_on_core_released)

	# The bay record markers are visual checkpoint markers only. Their progress
	# is owned by the completed E store, never by walking across the area.
	for marker: LevelCheckpoint in [_relay_checkpoint, _linked_checkpoint]:
		if marker != null:
			marker.monitoring = false
			marker.set_activated(false)

	_link.reset_link()
	if not _link.field_committed.is_connected(_on_link_field_committed):
		_link.field_committed.connect(_on_link_field_committed)
	if (
		_inversion_field != null
		and not _inversion_field.field_triggered.is_connected(_on_inversion_field_triggered)
	):
		_inversion_field.field_triggered.connect(_on_inversion_field_triggered)
	activate(_player, null)
	add_player_force_provider(_link)
	_hud02.set_pause_visible(false)
	_hud02.show_completion(false)
	_hud02.set_polarity(_player.is_positive())
	_hud02.replay_requested.connect(_restart_level)
	_hud02.return_to_menu_requested.connect(_return_to_main_menu)
	if not _hud02.next_level_requested.is_connected(_on_next_level_requested):
		_hud02.next_level_requested.connect(_on_next_level_requested)
	if not _exit.player_reached_exit.is_connected(_on_exit_reached):
		_exit.player_reached_exit.connect(_on_exit_reached)
	_exit.set_completed(false)
	_exit.set_gate_available(false)
	if get_window() != null:
		get_window().focus_exited.connect(_on_window_focus_exited)
		get_window().focus_entered.connect(_on_window_focus_entered)
	_setup_pause_menu()
	_setup_mechanic_popup()
	_camera.reset_smoothing()
	_update_level_hud()
	_setup_footsteps()


## World cues are scene-local: leaving for level 03 (or the title) must not
## carry a take/seat tail into the next scene. UI clicks finish naturally.
func _exit_tree() -> void:
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


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
	if _completed or _resetting or _scene_leaving or _next_level_started:
		return false
	if get_tree().paused:
		return false
	return true


func _footstep_stop() -> void:
	if _footsteps != null and is_instance_valid(_footsteps) and _footsteps.has_method("stop"):
		_footsteps.call("stop")


func _register_special_force_bodies() -> void:
	_special_force_rids.clear()
	for node_name: String in [
		"ConductiveRoof",
		"LinkedWall",
		"LinkedLip",
		"ReturnPlatform",
	]:
		var body: StaticBody2D = get_node_or_null(NodePath(node_name)) as StaticBody2D
		if body != null:
			var rid: RID = body.get_rid()
			if rid.is_valid() and not _special_force_rids.has(rid):
				_special_force_rids.append(rid)


func get_special_force_body_count() -> int:
	return _special_force_rids.size()


## The activation layer is visual only. It is inserted in code so level_02.tscn
## keeps the approved geometry/collision; no signal controls the unlock.
func _setup_conductive_activation() -> void:
	if _conductive_activation != null:
		return
	_conductive_activation = CONDUCTIVE_ACTIVATION.new()
	_conductive_activation.name = "ConductiveActivation"
	add_child(_conductive_activation)
	_conductive_activation.setup_from_level(self)
	_conductive_activation.set_unlocked(_special_wall_unlocked, false)


func _sync_conductive_activation(animate_first_unlock: bool = false, snap_held: bool = false) -> void:
	if _conductive_activation == null:
		return
	_conductive_activation.set_unlocked(_special_wall_unlocked, animate_first_unlock, snap_held)


func get_conductive_activation() -> ConductiveActivation:
	return _conductive_activation


func get_layered_core_material() -> LayeredCoreMaterial:
	if _conductive_activation == null:
		return null
	return _conductive_activation.get_layered_core()


func is_special_force_body(body: CollisionObject2D) -> bool:
	return body != null and _special_force_rids.has(body.get_rid())


## Only the player-core force line can skip the four registered conductive
## bodies, and only after the relay store has completed this run. While locked
## they are queried like any normal wall. Every ordinary layer-1 ray (including
## RuneStoneField occlusion) still hits them because the bodies stay on layer 1.
func _is_line_blocked(player_center: Vector2, core_center: Vector2) -> bool:
	if _player == null:
		return false
	var space: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	if space == null:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		player_center, core_center, 1
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclude: Array[RID] = [_player.get_rid()]
	if _core != null:
		exclude.append(_core.get_rid())
	if _special_wall_unlocked:
		for rid: RID in _special_force_rids:
			exclude.append(rid)
	query.exclude = exclude
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()


func is_special_wall_unlocked() -> bool:
	return _special_wall_unlocked


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if _completed:
		# Completed run: no target tint. The material fades on its own pausable
		# clock; gameplay state is not modified here.
		if _conductive_activation != null:
			_conductive_activation.clear_force_target()
		return
	super._physics_process(delta)
	if not is_active() or _player == null:
		return
	_check_exit_state()
	if _completed:
		if _conductive_activation != null:
			_conductive_activation.clear_force_target()
	else:
		_notify_force_visual()
		_tick_mechanic_popup()


## Presentation only: hand this tick's real shared-field result to the layered
## material. The helper re-checks core activity, status, non-zero pair force,
## unlock and whether the finite segment really crosses the exposed core mask.
## It is never given a synthetic line or a distance glow.
func _notify_force_visual() -> void:
	if _conductive_activation == null or _player == null or _core == null:
		return
	var player_center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
	_conductive_activation.update_force_state(
		_core.is_active(),
		_last_status,
		_last_blocked,
		_last_force,
		_last_core_player_force,
		player_center,
		_core.global_position,
		_player.is_positive()
	)


## Raw keyboard forwarding for left-Shift location and same-direction double-tap.
## player.gd deliberately has no _input of its own; the formal level owns this
## route. Echo is ignored, and paused/completed/leaving states never latch a key.
func _input(event: InputEvent) -> void:
	if _scene_leaving or _completed or _resetting or get_tree().paused:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.echo:
		return
	_player.handle_key_event(key_event)


func _setup_pause_menu() -> void:
	_pause_menu = PAUSE_MENU_SCRIPT.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.level_node = self
	_pause_menu.audio_settings_path = pause_audio_settings_path
	_pause_menu.display_settings_path = pause_display_settings_path
	_pause_menu.controls_rows = [
		["移动", "A / D · ← / →"],
		["奔跑", "{SHIFT}"],
		["跳跃", "{SPACE}"],
		["切换相性", "{Q}"],
		["释放 / 入仓", "{E}"],
		["阅读 / 翻页", "{F}"],
		["失败恢复", "最近稳定仓"],
		["整关重来", "{R}"],
		["暂停菜单", "{ESC}"],
	]
	add_child(_pause_menu)
	_pause_menu.restart_requested.connect(_restart_level)
	_pause_menu.return_to_menu_requested.connect(_return_to_main_menu)
	_pause_menu.opened.connect(_on_pause_opened)
	_pause_menu.resumed.connect(_on_pause_resumed)


## Teaching layer only. Two entries: carrying the first core, then the real
## relay unlock. No level rule, bay timing or force is touched.
func _setup_mechanic_popup() -> void:
	_mechanic_popup = MECHANIC_POPUP_SCENE.instantiate() as MechanicPopup
	_mechanic_popup.name = "MechanicPopup"
	_mechanic_popup.level_node = self
	add_child(_mechanic_popup)


func _tick_mechanic_popup() -> void:
	if _mechanic_popup == null or _mechanic_popup.is_open():
		return
	if _player == null or not is_instance_valid(_player):
		return
	var player_x: float = _player.global_position.x
	# Start bay is at x=128 with a 46 px E radius (first E at x=82), so 78 is
	# just before the first core action, not on spawn.
	if _stable_stage == STABLE_START and player_x >= 78.0:
		_mechanic_popup.request("core_carry")
	# The relay unlock happens at the real relay store (player x<=398). The
	# special ConductiveRoof starts at x=464; trigger at 420 so the tip opens
	# before the player can step onto it. No upper bound: if paused/dialogue
	# blocks it, later ticks keep requesting until it has been seen.
	if _special_wall_unlocked and _stable_stage >= STABLE_RELAY and player_x >= 420.0:
		_mechanic_popup.request("relay_link")


func is_mechanic_popup_blocked() -> bool:
	if get_tree().paused:
		return true
	if _completed or _resetting or _scene_leaving or _next_level_started:
		return true
	if _pause_menu != null and _pause_menu.has_method("is_open") and bool(_pause_menu.call("is_open")):
		return true
	if _stele != null and _stele.is_dialogue_open():
		return true
	# A lid animation or a store-in-progress is a one-shot the player is already
	# reading; do not freeze halfway through it.
	if _pending_release or _store_bay != null:
		return true
	return false


func get_mechanic_popup() -> MechanicPopup:
	return _mechanic_popup


func _on_pause_opened() -> void:
	_music.set_paused(true)
	if _player != null:
		_player.reset_movement_input_state()
		_player.clear_input_buffers()
	if _stele != null:
		_stele.set_suspended(true)
	_hud02.set_pause_visible(true)
	_hud02.release_completion_focus()


func _on_pause_resumed() -> void:
	_music.set_paused(false)
	_hud02.set_pause_visible(false)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.reset_movement_input_state()
	if _stele != null:
		_stele.set_suspended(false)
	if _completed:
		_hud02.focus_completion_primary()


func is_pause_menu_blocked() -> bool:
	if _mechanic_popup != null and _mechanic_popup.is_open():
		return true
	return false


func _on_window_focus_exited() -> void:
	if _player == null:
		return
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.clear_external_force()
	if _stele != null:
		_stele.on_focus_lost()


func _on_window_focus_entered() -> void:
	if _player != null and not _completed and not get_tree().paused:
		_player.clear_input_buffers()
		_player.reset_movement_input_state()


func get_pause_menu() -> Node:
	return _pause_menu


# --- multi-bay overrides (shared force/transport rules untouched) ----------

func _find_store_bay() -> Dictionary:
	var candidate: StarCoreBayInteractable = null
	var candidate_distance: float = 1e20
	var best: StarCoreBayInteractable = null
	var best_distance: float = 1e20
	var best_reason: String = "附近没有空仓"
	if _player == null:
		return {"ok": false, "bay": null, "reason": "无玩家"}
	var player_near_core: bool = (
		_core.is_active()
		and _player.global_position.distance_to(_core.global_position) <= store_player_core_range
	)
	for bay: StarCoreBayInteractable in _all_bays:
		if bay == null or not bay.is_player_in_range(_player.global_position):
			continue
		if not bay.is_open_empty():
			continue
		var distance: float = absf(bay.global_position.x - _player.global_position.x)
		if candidate == null or distance < candidate_distance:
			candidate = bay
			candidate_distance = distance
		var reason: String = ""
		if not _core.is_active():
			reason = "没有活动核"
		elif not player_near_core:
			reason = "核离玩家太远"
		elif not bay.is_core_in_store_zone(_core.global_position):
			reason = "核不在仓座内"
		if reason.is_empty():
			if best == null or distance < best_distance:
				best = bay
				best_distance = distance
		elif candidate == bay:
			best_reason = reason
	if best != null:
		return {"ok": true, "bay": best, "reason": "READY"}
	return {
		"ok": false,
		"bay": candidate,
		"reason": best_reason if candidate != null else "附近没有空仓",
	}


func _nearest_loaded_bay() -> StarCoreBayInteractable:
	if _player == null:
		return null
	var best: StarCoreBayInteractable = null
	var best_distance: float = 1e20
	for bay: StarCoreBayInteractable in _all_bays:
		if bay == null or not bay.is_player_in_range(_player.global_position) or not bay.is_locked():
			continue
		var distance: float = absf(bay.global_position.x - _player.global_position.x)
		if distance < best_distance:
			best = bay
			best_distance = distance
	return best


func _nearest_empty_bay() -> StarCoreBayInteractable:
	if _player == null:
		return null
	var best: StarCoreBayInteractable = null
	var best_distance: float = 1e20
	for bay: StarCoreBayInteractable in _all_bays:
		if bay == null or not bay.is_player_in_range(_player.global_position) or not bay.is_open_empty():
			continue
		var distance: float = absf(bay.global_position.x - _player.global_position.x)
		if distance < best_distance:
			best = bay
			best_distance = distance
	return best


func _inactive_core_status() -> String:
	for bay: StarCoreBayInteractable in _all_bays:
		if bay != null and bay.has_core():
			return STATUS_LOCKED
	return STATUS_EMPTY


func _try_interact() -> void:
	if _pending_release or _store_bay != null:
		return
	if _core.is_active():
		var store_info: Dictionary = _find_store_bay()
		if bool(store_info.get("ok", false)):
			_begin_store(store_info["bay"] as StarCoreBayInteractable)
		else:
			_show_store_unavailable(store_info)
		return
	var bay: StarCoreBayInteractable = _nearest_loaded_bay()
	if bay == null:
		return
	if not bay.start_release():
		return
	_pending_positive = not _player.is_positive()
	_pending_release = true
	_release_bay = bay
	if _hud02 != null:
		_hud02.show_toast("开罩中 · 星核将取反相", 1.0)
	_update_level_hud()


func _show_store_unavailable(info: Dictionary) -> void:
	if _hud02 == null:
		return
	var bay: StarCoreBayInteractable = info.get("bay", null) as StarCoreBayInteractable
	if bay == null:
		_hud02.show_toast("无法存入：把核带到空仓座位", 1.4)
		return
	_hud02.show_toast("无法存入：%s（%s）" % [bay.bay_name, String(info.get("reason", ""))], 1.6)


func _on_core_released() -> void:
	DemoAudio.play_core_take()
	if _hud02 != null:
		_hud02.show_toast("星核已释放 · %s" % ("辉相" if _pending_positive else "澜相"), 1.0)
	_update_level_hud()


func _on_core_stored_in_bay(bay: StarCoreBayInteractable, core_positive: bool) -> void:
	DemoAudio.play_core_seat()
	_success = false
	if _hud02 == null:
		return
	var polarity_text: String = "辉相" if core_positive else "澜相"
	if bay == _relay_bay:
		_hud02.show_toast("中继仓记录 %s · 尚未通关" % polarity_text, 1.5)
	elif bay == _linked_bay:
		_hud02.show_toast("联动仓记录 %s · 脉冲将点亮符石" % polarity_text, 1.8)
	elif bay == _final_bay:
		_hud02.show_toast("最终仓已锁定 · 出口开启", 1.8)
	else:
		_hud02.show_toast("起始仓已记录 %s" % polarity_text, 1.2)
	_update_level_hud()


func _complete_store() -> void:
	var bay: StarCoreBayInteractable = _store_bay
	var stage_before: int = _stable_stage
	super._complete_store()
	if bay == null:
		return
	if bay == _relay_bay:
		# The first completed relay store of this run is the unlock. An unfinished
		# store, approaching the bay, or any StartBay record never reaches here.
		# The presentation layer is notified only after this gameplay boolean
		# really changes; it never sets the boolean back.
		var was_unlocked: bool = _special_wall_unlocked
		_special_wall_unlocked = true
		_sync_conductive_activation(not was_unlocked)
		_set_stable(STABLE_RELAY, bay.get_recorded_positive())
	elif bay == _linked_bay:
		_set_stable(STABLE_LINKED, bay.get_recorded_positive())
	if _stable_stage > stage_before:
		_queue_record_save()
	_update_level_hud()


## One confirmation for a real new stable stage, after the 0.25 s lid close and
## the 0.65 s core-seat cue have mostly cleared. Init/restore/setup/R never call
## this; a same-point repeat does not raise the stage.
func _queue_record_save(delay: float = 0.40) -> void:
	_record_save_token += 1
	var token: int = _record_save_token
	await get_tree().create_timer(delay, false).timeout
	if token != _record_save_token or not is_inside_tree():
		return
	if _scene_leaving or _resetting or _completed:
		return
	DemoAudio.play_record_save()


## Real rune-field commit (pulse delivered + stone transition finished). The
## pulse start is not a second cue: one commit, one sound.
func _on_link_field_committed(_positive: bool) -> void:
	DemoAudio.play_link()


func _set_stable(stage: int, positive: bool) -> void:
	# Never downgrade a later checkpoint. Re-storing the same checkpoint bay
	# with a different valid polarity must update the latest stable record,
	# otherwise a later death would restore the first phase and contradict the
	# bay/link/rune state.
	if stage < _stable_stage:
		return
	_stable_stage = stage
	_stable_positive = positive
	if _relay_checkpoint != null:
		_relay_checkpoint.set_activated(stage >= STABLE_RELAY)
	if _linked_checkpoint != null:
		_linked_checkpoint.set_activated(stage >= STABLE_LINKED)


func get_stable_stage() -> int:
	return _stable_stage


func get_stable_positive() -> bool:
	return _stable_positive


func get_stable_spawn_position() -> Vector2:
	match _stable_stage:
		STABLE_RELAY:
			return STABLE_SPAWN_RELAY
		STABLE_LINKED:
			return STABLE_SPAWN_LINKED
		_:
			return STABLE_SPAWN_START


func _reset_runtime_without_progress() -> void:
	_pending_release = false
	_pending_positive = true
	_release_bay = null
	_store_bay = null
	_core.deactivate()
	_core.clear_external_force()
	_success = false
	_last_status = STATUS_LOCKED
	_last_distance = 0.0
	_last_force = Vector2.ZERO
	_last_core_player_force = Vector2.ZERO
	_last_extra_player_force = Vector2.ZERO
	_last_player_force = Vector2.ZERO
	_last_blocked = false
	_last_e_preview = ""
	_last_store_hint = ""
	if _player != null:
		_player.clear_external_force()
	if _link != null:
		_link.reset_link()


func _restore_stable(reason: String) -> void:
	if _player == null:
		return
	_record_save_token += 1
	_resetting = true
	_footstep_stop()
	_completed = false
	_success = false
	_exit_was_inside = false
	_next_level_started = false
	if _exit != null:
		_exit.set_completed(false)
		_exit.set_gate_available(false)
	if _pause_menu != null:
		_pause_menu.set_completion_active(false)
	if _hud02 != null:
		_hud02.show_completion(false)
		_hud02.set_pause_visible(false)
	_reset_runtime_without_progress()

	for bay: StarCoreBayInteractable in _all_bays:
		if bay != null:
			bay.reset_empty()
	$Bays/StartBay.reset_empty()

	if _stable_stage == STABLE_START:
		$Bays/StartBay.reset_locked()
		_core.global_position = $Bays/StartBay.get_store_center()
	elif _stable_stage == STABLE_RELAY:
		_place_record_in_bay(_relay_bay, _stable_positive)
	elif _stable_stage == STABLE_LINKED:
		_place_record_in_bay(_linked_bay, _stable_positive)

	if _relay_checkpoint != null:
		_relay_checkpoint.set_activated(_stable_stage >= STABLE_RELAY)
	if _linked_checkpoint != null:
		_linked_checkpoint.set_activated(_stable_stage >= STABLE_LINKED)

	if _inversion_field != null:
		# Respawning outside the curtain must re-arm it; a body that died inside
		# cannot leave the field with a stale "still inside" latch.
		_inversion_field.reset_inside_state()
	_player.global_position = get_stable_spawn_position()
	_player.velocity = Vector2.ZERO
	_player.visible = true
	_player.set_physics_process(true)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_camera.reset_smoothing()
	_resetting = false
	if reason != "debug_setup":
		# L1/L2 restore in one instant (no fade). Their existing stable-restore
		# event gets the single "back on the checkpoint" cue; failure has no
		# separate entry here and is not stacked on top.
		DemoAudio.play_respawn()
	if _stele != null:
		_stele.set_suspended(false)
		_stele.on_player_reset(reason)
	_update_level_hud()
	if _hud02 != null:
		if reason == "core_out":
			_hud02.show_toast("星核越界 · 回到最近稳定仓", 1.8)
		elif reason == "fall":
			_hud02.show_toast("跌落 · 回到最近稳定仓", 1.8)
		else:
			_hud02.show_toast("已回到最近稳定仓", 1.2)
	# A restore (fall / core out / debug late state) presents the current state
	# directly: unlocked stays lit, locked stays dark, and nothing replays. A
	# restore during the 0.9 s one-shot snaps to the held seam, not replay.
	_sync_conductive_activation(false, true)


func _place_record_in_bay(bay: StarCoreBayInteractable, positive: bool) -> void:
	if bay == null:
		return
	bay.reset_empty()
	bay.start_store_core(positive)
	bay.finish_store()
	_core.global_position = bay.get_store_center()
	_core.deactivate()
	if bay == _linked_bay and _link != null:
		# The E record already started a pulse; cancel it, then present the
		# normalized committed checkpoint without a stale callback.
		_link.reset_link()
		_link.restore_committed(positive, true)


func _handle_core_out_of_bounds() -> void:
	if _resetting:
		return
	_restore_stable("core_out")


func _on_player_reset_performed(reason: String, _count: int) -> void:
	if _resetting:
		return
	_restore_stable(reason)


func on_player_reset(reason: String) -> void:
	if _resetting:
		return
	_restore_stable(reason)


func _reset_room_state() -> void:
	super._reset_room_state()
	if _inversion_field != null:
		_inversion_field.reset_inside_state()
	for bay: StarCoreBayInteractable in [_relay_bay, _linked_bay]:
		if bay != null:
			bay.reset_empty()
	if _link != null:
		_link.reset_link()
	_stable_stage = STABLE_START
	_stable_positive = true
	_special_wall_unlocked = false
	_record_save_token += 1
	if _relay_checkpoint != null:
		_relay_checkpoint.set_activated(false)
	if _linked_checkpoint != null:
		_linked_checkpoint.set_activated(false)
	_core.global_position = $Bays/StartBay.get_store_center()
	_core.deactivate()
	_sync_conductive_activation(false)
	_update_level_hud()


func _restart_level() -> void:
	if _scene_leaving or _next_level_started:
		return
	_footstep_stop()
	if _pause_menu != null:
		_pause_menu.force_close()
		_pause_menu.set_completion_active(false)
	get_tree().paused = false
	_completed = false
	_exit_was_inside = false
	_next_level_started = false
	if _exit != null:
		_exit.set_completed(false)
		_exit.set_gate_available(false)
	_resetting = true
	_reset_room_state()
	_player.set_spawn_point(_spawn_marker.global_position)
	_player.reset_to_spawn("level_restart", true)
	_resetting = false
	_player.set_spawn_point(_spawn_marker.global_position)
	_camera.reset_smoothing()
	if _stele != null:
		_stele.set_suspended(false)
		_stele.on_player_reset("level_restart")
	if _hud02 != null:
		_hud02.set_pause_visible(false)
		_hud02.show_completion(false)
		# A failed attempt must not leave the page's buttons disabled on the
		# next completion.
		_hud02.set_completion_buttons_enabled(true)
		_hud02.set_polarity(_player.is_positive())
		_hud02.show_toast("本关已重新开始", 1.2)
	_update_level_hud()
	_music.play(true)


## Completion page: "进入第三关". One accepted request per completion; the
## buttons are disabled in the same call, so a double click or Enter repeat
## cannot request a second scene change. The real LevelFlow change unpauses the
## tree and releases held gameplay actions before loading level_03.tscn.
func _on_next_level_requested() -> void:
	if not _completed or _next_level_started or _scene_leaving:
		return
	_next_level_started = true
	_footstep_stop()
	_music.stop(0.0)
	if _pause_menu != null:
		_pause_menu.prepare_scene_change()
	if _hud02 != null:
		_hud02.set_completion_buttons_enabled(false)
		_hud02.release_completion_focus()
	if _stele != null:
		_stele.set_suspended(true)
	_player.clear_input_buffers()
	_player.clear_external_force()
	LEVEL_FLOW.start_level_03(get_tree())


func _return_to_main_menu() -> void:
	if _scene_leaving or _next_level_started:
		return
	_scene_leaving = true
	_footstep_stop()
	_music.stop(0.0)
	if _pause_menu != null:
		_pause_menu.prepare_scene_change()
	if _hud02 != null:
		_hud02.set_completion_buttons_enabled(false)
	LEVEL_FLOW.return_to_title(get_tree())


## The rift curtain flips the player once per entry. It never blocks movement,
## never touches the core, and Q always remains available to flip back. The HUD
## event row is the only new prompt; no new UI node is added.
func _on_inversion_field_triggered(positive_after: bool) -> void:
	if _completed or _resetting or _scene_leaving or _next_level_started:
		return
	if _hud02 != null:
		_hud02.show_toast("紫幕翻相 · 按 Q 换回来", 1.8)
		_hud02.set_polarity(positive_after)


func _on_player_polarity_changed(positive: bool) -> void:
	# Real Q only: resets put the player counter back at 0 and scripted state
	# changes do not increment it, so neither plays the phase cue.
	var toggles: int = _player.get_polarity_toggle_count()
	if toggles > _last_polarity_toggles:
		DemoAudio.play_polarity_switch()
	_last_polarity_toggles = toggles
	if _hud02 != null:
		_hud02.set_polarity(positive)


func _check_exit_state() -> void:
	if _player == null or _exit == null:
		return
	var inside: bool = _is_player_inside_exit()
	if inside and is_exit_gate_ready():
		_try_complete_at_exit()
		_exit_was_inside = true
		return
	if inside and not _exit_was_inside and _hud02 != null:
		_hud02.show_toast("最终仓未锁定或联动未完成 · 出口暂未开启", 1.8)
	_exit_was_inside = inside


func _try_complete_at_exit() -> void:
	if _completed or not _is_player_inside_exit():
		return
	if not is_exit_gate_ready():
		return
	_completed = true
	_footstep_stop()
	_completion_count += 1
	DemoAudio.play_complete()
	_music.stop(BaseLevelMusic.STOP_FADE_SECONDS)
	_exit.set_gate_available(false)
	_exit.set_completed(true)
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	_player.velocity = Vector2.ZERO
	if _stele != null:
		_stele.set_suspended(true)
	if _hud02 != null:
		_hud02.set_pause_visible(false)
		_hud02.show_completion(true, _completion_count)
	if _pause_menu != null:
		_pause_menu.set_completion_active(true)
	_update_level_hud()
	level_completed.emit()


func _is_player_inside_exit() -> bool:
	if _player == null or _exit == null:
		return false
	var local: Vector2 = _player.global_position - _exit.global_position
	var rect: Rect2 = _exit.get_trigger_rect()
	return (
		local.x >= rect.position.x - 1.0
		and local.x <= rect.end.x + 1.0
		and local.y >= rect.position.y - 1.0
		and local.y <= 1.0
	)


func _on_exit_reached() -> void:
	_try_complete_at_exit()


func _update_hud() -> void:
	_update_level_hud()


func _update_level_hud() -> void:
	if _hud02 == null or _player == null:
		return
	if _exit != null:
		_exit.set_gate_available(is_exit_gate_ready() and not _completed)
	_hud02.set_polarity(_player.is_positive())

	var phase: String = "任务：释放星核"
	var core_text: String = "星核：起始仓"
	var prompt: String = ""

	if _completed:
		phase = "任务：已完成"
	elif is_exit_gate_ready():
		phase = "任务：前往出口"
	elif _final_bay.is_locked():
		phase = "任务：补全联动记录"
	elif _core.is_active() and _stable_stage >= STABLE_LINKED and _link.is_field_activated():
		if _player.global_position.y <= 245.0:
			phase = "任务：拉核过石栅"
		else:
			phase = "任务：借符石上高台"
	elif _linked_bay.is_locked():
		phase = "任务：取核 · 借符石越石栅"
	elif _relay_bay.is_locked() and not _core.is_active():
		phase = "任务：把星核送入联动仓"
	elif _core.is_active():
		if _stable_stage == STABLE_START:
			phase = "任务：把星核送入中继仓"
		elif _stable_stage == STABLE_RELAY:
			phase = "任务：把星核送入联动仓"
		else:
			phase = "任务：运输星核"

	if _core.is_active():
		core_text = "星核：运输中"
	else:
		if $Bays/StartBay.has_core():
			core_text = "星核：起始仓"
		elif _relay_bay.has_core():
			core_text = "星核：中继仓"
		elif _linked_bay.has_core():
			core_text = "星核：联动仓"
		elif _final_bay.has_core():
			core_text = "星核：最终仓"
		else:
			core_text = "星核：未知"
	# Keep the visual core line short. Record/field remain internal state and
	# APIs, but are not a permanent technical readout.
	if _core.is_active():
		var store_info: Dictionary = _find_store_bay()
		if bool(store_info.get("ok", false)):
			var store_target: StarCoreBayInteractable = store_info.get("bay", null) as StarCoreBayInteractable
			if store_target != null:
				prompt = "存入%s" % store_target.bay_name
	elif _pending_release:
		prompt = "开罩中…"
	elif _store_bay != null:
		prompt = "合罩中…"
	else:
		var loaded: StarCoreBayInteractable = _nearest_loaded_bay()
		if loaded != null:
			prompt = "取出%s的星核" % loaded.bay_name

	_hud02.set_status(phase, core_text, prompt)


func _stable_label() -> String:
	match _stable_stage:
		STABLE_RELAY:
			return "中继仓"
		STABLE_LINKED:
			return "联动仓"
		_:
			return "起点"


func _record_label_zh() -> String:
	if _link == null or not _link.has_record():
		return "无记录"
	return "辉相" if _link.get_record_positive() else "澜相"


func _field_label_zh() -> String:
	if _link == null or _rune_field == null:
		return "无符石"
	if not _rune_field.is_activated():
		return "未激活"
	return "辉相" if _rune_field.is_positive() else "澜相"


# --- accessors -------------------------------------------------------------

func get_player() -> PrototypePlayer:
	return _player


func get_camera() -> Camera2D:
	return _camera


func get_exit() -> LevelExit:
	return _exit


func get_hud() -> Level02HUD:
	return _hud02


func get_footstep_audio() -> Node:
	return _footsteps


func get_music() -> BaseLevelMusic:
	return _music


func get_bays() -> Array[StarCoreBayInteractable]:
	return _all_bays.duplicate()


func get_relay_bay() -> StarCoreBayInteractable:
	return _relay_bay


func get_linked_bay() -> StarCoreBayInteractable:
	return _linked_bay


func get_final_bay() -> StarCoreBayInteractable:
	return _final_bay


func get_link() -> BayRuneLink:
	return _link


func get_rune_field() -> RuneStoneField:
	return _rune_field


func get_inversion_field() -> RiftInversionField:
	return _inversion_field


func get_start_stele() -> GuideEcho:
	return _stele


## Explicit name for the migrated L2 echo; same object as get_start_stele().
func get_start_guide() -> GuideEcho:
	return _stele


func get_relay_checkpoint() -> LevelCheckpoint:
	return _relay_checkpoint


func get_linked_checkpoint() -> LevelCheckpoint:
	return _linked_checkpoint


func get_spawn_position() -> Vector2:
	return _spawn_marker.global_position


func get_platform_rects() -> Array[Rect2]:
	return [
		Rect2(0.0, 320.0, 1792.0, 40.0),
		Rect2(464.0, 268.0, 256.0, 32.0),
		Rect2(1080.0, 240.0, 160.0, 60.0),
		Rect2(1040.0, 240.0, 40.0, 12.0),
		Rect2(1264.0, 280.0, 48.0, 12.0),
	]


func is_completed() -> bool:
	return _completed


func get_completion_count() -> int:
	return _completion_count


func is_scene_leaving() -> bool:
	return _scene_leaving


func is_next_level_started() -> bool:
	return _next_level_started


func is_target_locked() -> bool:
	return _final_bay.is_locked()


## Single source of truth for the exit contract: the final bay is LOCKED, the
## linked bay has a real record, the rune is actually active (not its dormant
## initial_positive), the pulse/field transition is settled, and the recorded
## phase equals the rune's committed phase.
func is_exit_gate_ready() -> bool:
	if _final_bay == null or not _final_bay.is_locked():
		return false
	if _link == null or not _link.has_record():
		return false
	if _rune_field == null or not _rune_field.is_activated():
		return false
	if _link.has_pending_pulse() or _link.is_field_pending() or _link.is_transfer_active():
		return false
	return _link.get_record_positive() == _rune_field.is_positive()


func can_exit_now() -> bool:
	return is_exit_gate_ready() and not _completed


func debug_restore_stage(stage: int, positive: bool = true) -> void:
	_stable_stage = clampi(stage, STABLE_START, STABLE_LINKED)
	_stable_positive = positive
	# A debug state that explicitly represents post-relay progress must also
	# represent the unlock; STABLE_START stays locked. The real first-delivery
	# flow is still verified separately with real E input in the focused test.
	_special_wall_unlocked = _stable_stage >= STABLE_RELAY
	_restore_stable("debug_setup")
