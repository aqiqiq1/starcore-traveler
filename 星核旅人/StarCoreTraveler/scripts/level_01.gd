class_name Level01
extends Node2D

## Formal level 01 "断桥庭院" (first playable version).
##
## The scene is the configuration source: terrain blocks, the two fixed
## manifestations of the watcher's echo, rune stones, checkpoint, exit, camera
## and the opening hand-off marker are real editor nodes. This script only wires
## them together. It deliberately does not teleport the player during normal
## play, inject fake Input actions, hide walls, gate a mechanism on reading a
## conversation, or hand out a test-only force.
##
## Failure model (first-version initial value): falling below the level restores
## the most recently touched checkpoint. R restarts the whole level, returns the
## player to the opening spawn with 辉相 (positive) and clears completion.

const BODY_CENTER_OFFSET: Vector2 = Vector2(0.0, -15.0)
const START_REASON: String = "level_start"
const RESTART_REASON: String = "level_restart"
const PAUSE_MENU_SCRIPT = preload("res://scripts/ui/pause_menu.gd")
const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")
const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")
const FOOTSTEP_SCRIPT = preload("res://scripts/audio/player_footstep_audio.gd")
const OPENING_SCRIPT = preload("res://scripts/narrative/opening_cinematic.gd")
const MECHANIC_POPUP_SCENE: PackedScene = preload("res://scenes/ui/mechanic_popup.tscn")
## The full gate lesson lives here, at the first same-phase door in the game.
## Later chapters only repeat the short phase reminder.
const GATE_FULL_HINT: String = "同相门只认同相 · 看门上日/月 · 按 Q 换相"
const GATE_SHORT_HINT: String = "按 Q 换相"

@export_range(2.0, 15.0, 0.05, "suffix:s") var intro_max_duration: float = 9.0
## Legacy safety cap for callers that inspect it. The opening itself hands off
## at the local stop point (HANDOFF_X = 286, just right of the stele), never at
## the old IntroEnd x=100.
## Opening auto-run axis, paired with sprint: target speed = ratio * RUN_SPEED.
## The default 0.75 is 120 px/s, slower than the normal 160 px/s run, while the
## run animation, path, local hand-off and normal gameplay stay unchanged.
@export_range(0.5, 1.0, 0.01) var intro_run_speed_ratio: float = 0.75

@export_group("Start Menu")
## Production default: F6 on level_01.tscn opens the integrated start menu.
## Automated gameplay tests set this to false before add_child().
@export var enable_start_menu: bool = true
@export_range(0.0, 2.0, 0.01, "suffix:s") var menu_title_fade_duration: float = 0.35
@export_range(0.1, 5.0, 0.01, "suffix:s") var menu_camera_pan_duration: float = 2.2
@export_range(0.0, 1.0, 0.01, "suffix:s") var menu_settle_duration: float = 0.15
@export var menu_camera_start_position: Vector2 = Vector2(320.0, -180.0)
@export var pause_audio_settings_path: String = "user://audio_settings.cfg"
@export var pause_display_settings_path: String = "user://display_settings.cfg"
## Empty = the shared user://chapter_progress.cfg.  Tests may point this at a
## throwaway file before add_child(); gameplay never sets it.
@export var chapter_progress_path: String = ""

@onready var _world: Node2D = $World
@onready var _player: PrototypePlayer = $World/Player
@onready var _camera: Camera2D = $World/Player/Camera2D
@onready var _intro_end: Node2D = $World/IntroEnd
@onready var _checkpoint: LevelCheckpoint = $World/Checkpoint
@onready var _exit_polarity_gate: PolarityGate = $World/PolarityGateExit
@onready var _exit: LevelExit = $World/Exit
@onready var _narrative_guide: GuideEcho = $World/GuideEchoMeeting
@onready var _mechanism_guide: GuideEcho = $World/GuideEchoHighstep
@onready var _gate_stele: GuideEcho = $World/GuideEchoGate
@onready var _rune_stones: Array[RuneStoneField] = [
	$World/RuneStoneHigh as RuneStoneField,
	$World/RuneStonePit as RuneStoneField,
]
@onready var _hud: Level01HUD = $HUD
@onready var _menu: StartMenu = $StartMenu
@onready var _menu_camera: Camera2D = $MenuCamera
@onready var _music: BaseLevelMusic = $BaseLevelMusic

var _pause_menu = null
var _start_position: Vector2 = Vector2.ZERO
var _checkpoint_position: Vector2 = Vector2.ZERO
var _intro_active: bool = false
var _intro_elapsed: float = 0.0
var _completed: bool = false
var _resetting: bool = false
var _completion_count: int = 0
## Real gameplay time for the completion page; frozen by pause and the opening
## film, reset by the menu hand-off/restart, exactly like the DLC chapters.
var _elapsed: float = 0.0
var _last_polarity_toggles: int = 0
var _last_force: Vector2 = Vector2.ZERO
var _intro_start_count: int = 0
var _next_level_started: bool = false
var _scene_leaving: bool = false
var _footsteps: Node = null
var _opening: OpeningCinematic = null
var _mechanic_popup: MechanicPopup = null
var _mechanic_teach: MechanicTeach = null
## The new opening plays once per Level01 instance. R and failure recovery
## never call the film again; a fresh new game is a fresh scene instance.
var _opening_played: bool = false
## Gate teaching: the full line fires once on a 56 px approach; contact only
## shortens it to the Q reminder.  The helper re-arms after 200 px and refuses
## the same full line again inside 10 s.
var _exit_gate_hint: ApproachHint = ApproachHint.new()
var _exit_gate_short_pending: bool = false
var _exit_gate_short_hint_count: int = 0


## Raw keyboard forwarding for left-Shift and double-tap intent. The movement
## axis still comes from InputMap, but Shift location and key echo need the real
## event. Ignore events while the level owns the player (opening/completion) or
## while paused, so those states never keep a stale Shift/double-tap latch.
func _input(event: InputEvent) -> void:
	if _menu != null and _menu.is_gameplay_blocked():
		return
	if _player == null or _intro_active or _completed or get_tree().paused:
		return
	if event is InputEventKey:
		_player.handle_key_event(event as InputEventKey)


func _ready() -> void:
	# The title fades to black, then switches to this fresh level_01. Consume the
	# one-shot request before the menu can activate so the opening film own black
	# overlay is the first thing the new scene presents (no world/HUD/old copy).
	if LEVEL_FLOW.consume_new_game_request():
		enable_start_menu = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS

	_start_position = _player.global_position
	_checkpoint_position = _start_position
	_player.set_spawn_point(_start_position)
	# PauseMenu is the single owner of R/Esc so one key press cannot both
	# self-reset the player and restart the level.
	_player.allow_self_reset = false
	_player.reset_performed.connect(_on_player_reset_performed)
	_player.polarity_changed.connect(_on_player_polarity_changed)
	_checkpoint.checkpoint_entered.connect(_on_checkpoint_entered)
	_exit_polarity_gate.denied.connect(_on_exit_polarity_gate_denied)
	_exit.player_reached_exit.connect(_on_exit_reached)
	get_window().focus_exited.connect(_on_window_focus_exited)
	get_window().focus_entered.connect(_on_window_focus_entered)
	_hud.next_level_requested.connect(_on_next_level_requested)
	_hud.replay_requested.connect(_restart_level)
	_hud.return_to_menu_requested.connect(_return_to_main_menu)
	_setup_pause_menu()
	_setup_mechanic_popup()
	_setup_mechanic_teach()
	_setup_footsteps()
	_setup_opening()

	_hud.set_polarity(true)
	_hud.show_completion(false)
	_hud.set_pause_visible(false)
	_checkpoint.set_activated(false)
	_exit.set_completed(false)
	_camera.reset_smoothing()
	if enable_start_menu and is_instance_valid(_menu) and is_instance_valid(_menu_camera):
		_set_guides_suspended(true)
		_hud.visible = false
		_menu.activate(self, _menu_camera)
	else:
		_hud.visible = true
		_begin_intro(true)
	_refresh_exit_gate_available()


## World cues are scene-local: a real scene change must not carry a gate rise or
## completion tail into the next level. UI clicks are not stopped here.
func _exit_tree() -> void:
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


func _process(delta: float) -> void:
	_refresh_exit_gate_available()
	if _menu != null and _menu.is_gameplay_blocked():
		return
	if (
		not get_tree().paused
		and not _intro_active
		and not _completed
		and not _resetting
		and not _scene_leaving
	):
		_elapsed += delta
	# The local opening controller owns bar easing, the scripted run, the
	# echo's pages, the F advance and the Space skip hold. This level keeps only
	# compatibility state and the safe pause/focus/reset hand-offs.
	if _intro_active and _opening != null:
		_intro_elapsed = _opening.get_elapsed()
	if (
		not get_tree().paused
		and not _intro_active
		and not _completed
		and not _resetting
		and not _scene_leaving
	):
		_tick_exit_gate_hint()
		_tick_mechanic_teach()


func _physics_process(_delta: float) -> void:
	if _menu != null and _menu.is_gameplay_blocked():
		return
	if get_tree().paused or _completed or _intro_active:
		return
	if not is_instance_valid(_player):
		return
	var total_force: Vector2 = Vector2.ZERO
	var player_center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
	for stone: RuneStoneField in _rune_stones:
		if stone == null:
			continue
		var sample: Dictionary = stone.sample_field(
			player_center,
			_player.is_positive(),
			_player.get_rid()
		)
		total_force += sample["acceleration"] as Vector2
	_last_force = total_force
	if total_force.is_zero_approx():
		_player.clear_external_force()
	else:
		# Single aggregation point: individual field rules (range, inner safety,
		# occlusion, caps) stay owned by RuneStoneField.
		_player.apply_external_force(total_force)
	_tick_mechanic_popup()


func _setup_pause_menu() -> void:
	_pause_menu = PAUSE_MENU_SCRIPT.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.level_node = self
	if enable_start_menu and is_instance_valid(_menu):
		# Keep tests and production on the same config files as the title menu.
		_pause_menu.audio_settings_path = _menu.audio_settings_path
		_pause_menu.display_settings_path = _menu.display_settings_path
	else:
		_pause_menu.audio_settings_path = pause_audio_settings_path
		_pause_menu.display_settings_path = pause_display_settings_path
	_pause_menu.controls_rows = [
		["移动", "A / D · ← / →"],
		["奔跑", "{SHIFT}"],
		["跳跃", "{SPACE}"],
		["切换相性", "{Q}"],
		["交谈 / 取核", "{E}"],
		["阅读 / 翻页", "{F}"],
		["重来本关", "{R}"],
		["暂停菜单", "{ESC}"],
	]
	add_child(_pause_menu)
	_pause_menu.restart_requested.connect(_restart_level)
	_pause_menu.return_to_menu_requested.connect(_return_to_main_menu)
	_pause_menu.opened.connect(_on_pause_opened)
	_pause_menu.resumed.connect(_on_pause_resumed)


## Teaching layer only: a run-scoped popup that pauses on first contact with a
## mechanism. It owns no gameplay state and is never a gate.
func _setup_mechanic_popup() -> void:
	_mechanic_popup = MECHANIC_POPUP_SCENE.instantiate() as MechanicPopup
	_mechanic_popup.name = "MechanicPopup"
	_mechanic_popup.level_node = self
	add_child(_mechanic_popup)


## The shared first-encounter teaching node.  It shows the registry summary
## once through the existing event line and persists it; it owns no gameplay.
func _setup_mechanic_teach() -> void:
	_mechanic_teach = MechanicTeach.new()
	_mechanic_teach.name = "MechanicTeach"
	_mechanic_teach.show_line = func(text_value: String) -> void:
		_hud.show_toast(text_value, 2.4)
	_mechanic_teach.blocked_check = Callable(self, "_is_mechanic_teach_blocked")
	add_child(_mechanic_teach)


## The old chapter-fixed popup trigger for 相性 is disabled here; the rune
## stones below own the first teaching request.  The popup node stays for the
## shared UI tests, but it never opens a duplicate on its own.
func _tick_mechanic_popup() -> void:
	pass


func _tick_mechanic_teach() -> void:
	if _mechanic_teach == null or _player == null or not is_instance_valid(_player):
		return
	if _intro_active or _resetting or _scene_leaving or _completed:
		return
	var player_position: Vector2 = _player.global_position
	var facing: int = _player.get_facing()
	# The first rune is where Q is actually needed.  Polarity (the key) is
	# queued before the rune's push/pull rule so the two lines never stack.
	for stone: RuneStoneField in _rune_stones:
		if stone == null or not is_instance_valid(stone):
			continue
		if _mechanic_teach.observe_near(
			"polarity", stone.global_position, player_position, facing, 64.0, 96.0
		):
			break
	for stone: RuneStoneField in _rune_stones:
		if stone == null or not is_instance_valid(stone):
			continue
		if _mechanic_teach.observe_near(
			"rune", stone.global_position, player_position, facing, 64.0, 96.0
		):
			break


func _is_mechanic_teach_blocked() -> bool:
	if get_tree().paused:
		return true
	if _completed or _intro_active or _resetting or _scene_leaving:
		return true
	if _menu != null and _menu.is_gameplay_blocked():
		return true
	if _pause_menu != null and _pause_menu.has_method("is_open") and bool(_pause_menu.call("is_open")):
		return true
	if _mechanic_popup != null and _mechanic_popup.is_open():
		return true
	if _pause_menu != null and _pause_menu.has_method("is_manual_open") \
			and bool(_pause_menu.call("is_manual_open")):
		return true
	if is_instance_valid(_narrative_guide) and _narrative_guide.is_dialogue_open():
		return true
	if is_instance_valid(_mechanism_guide) and _mechanism_guide.is_dialogue_open():
		return true
	return false


## Local footstep bank, owned by the player. No DemoAudio change and no shared
## player/physics change; the level only supplies the gameplay gate.
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


## Local opening film. It reuses the echo's public page API and the approved
## L3 letterbox/F-advance/Space-skip rules; it does not fake a guard cinematic or a new camera.
func _setup_opening() -> void:
	_opening = OPENING_SCRIPT.new()
	_opening.name = "OpeningCinematic"
	_opening.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_opening)
	_opening.setup(self, _player, _narrative_guide, _hud)
	_opening.finished.connect(_on_opening_finished)
	_opening.aborted.connect(_on_opening_aborted)


func _footstep_allowed() -> bool:
	if _scene_leaving or _completed or _resetting or _intro_active:
		return false
	if get_tree().paused:
		return false
	if _menu != null and _menu.is_gameplay_blocked():
		return false
	return true


func _footstep_stop() -> void:
	if _footsteps != null and is_instance_valid(_footsteps) and _footsteps.has_method("stop"):
		_footsteps.call("stop")


## Starts the new-game film exactly once for this scene instance. R and failure
## recovery never pass through here; they use _begin_play()/the checkpoint.
func _begin_intro(reset_player: bool) -> void:
	if _opening_played:
		_begin_play(reset_player, START_REASON)
		return
	_completed = false
	_footstep_stop()
	# Music belongs to actual gameplay, not the integrated title page. The film
	# never pauses or stops it.
	_music.play(true)
	if _opening != null:
		_opening.abort()
	_intro_active = true
	_refresh_exit_gate_available()
	_intro_elapsed = 0.0
	_elapsed = 0.0
	_intro_start_count += 1
	_checkpoint_position = _start_position
	_checkpoint.set_activated(false)
	_exit.set_completed(false)
	_player.set_spawn_point(_start_position)
	if reset_player:
		_resetting = true
		_player.reset_to_spawn(START_REASON, false)
		_resetting = false
	_player.set_spawn_point(_start_position)
	# The narrative echo is awake and owned by the film; the high-step echo is
	# far away and waits for the hand-off.
	if _mechanism_guide != null and is_instance_valid(_mechanism_guide):
		_mechanism_guide.set_suspended(true)
	if _gate_stele != null and is_instance_valid(_gate_stele):
		_gate_stele.set_suspended(true)
	if _narrative_guide != null and is_instance_valid(_narrative_guide):
		_narrative_guide.set_suspended(false)
		_narrative_guide.set_cinematic_owned(true)
	_hud.set_polarity(true)
	_hud.show_completion(false)
	_hud.set_pause_visible(false)
	_hud.set_opening_active(true)
	if _pause_menu != null:
		_pause_menu.set_completion_active(false)
	_hud.show_toast("", 0.0)
	_camera.reset_smoothing()
	_opening_played = true
	if _opening == null or not _opening.start():
		_begin_play(true, START_REASON)


## Gameplay entry without the film. Used by R (restart), a failed film start,
## and tests that finish the film from the outside. It never replays the film.
func _begin_play(reset_player: bool, reason: String = START_REASON) -> void:
	_completed = false
	_footstep_stop()
	_music.play(true)
	if _opening != null:
		_opening.abort()
	_intro_active = false
	_intro_elapsed = 0.0
	_elapsed = 0.0
	_opening_played = true
	_exit_gate_hint.reset()
	_exit_gate_short_pending = false
	_exit_gate_short_hint_count = 0
	_exit.set_completed(false)
	_checkpoint.set_activated(false)
	_checkpoint_position = _start_position
	for stone: RuneStoneField in _rune_stones:
		if stone != null:
			stone.reset_state()
	_player.clear_external_force()
	_player.set_spawn_point(_start_position)
	_player.set_physics_process(true)
	if reset_player:
		_resetting = true
		_player.reset_to_spawn(reason, true)
		_resetting = false
	_player.set_spawn_point(_start_position)
	_narrative_guide.on_player_reset(reason)
	_mechanism_guide.on_player_reset(reason)
	if _gate_stele != null and is_instance_valid(_gate_stele):
		_gate_stele.on_player_reset(reason)
	_set_guides_suspended(false)
	_hud.set_polarity(true)
	_hud.show_completion(false)
	_hud.set_pause_visible(false)
	_hud.set_opening_active(false)
	_hud.visible = true
	if _pause_menu != null:
		_pause_menu.set_completion_active(false)
	_camera.enabled = true
	_camera.make_current()
	_camera.reset_smoothing()
	_player.end_input_override()
	_player.clear_input_buffers()
	_refresh_exit_gate_available()


func _finish_intro() -> void:
	_opening_played = true
	if _opening != null and _opening.is_active():
		# Aborting cleans the override, page voice, camera and the hidden chrome;
		# the aborted signal sets _intro_active=false.
		_opening.abort()
		return
	_intro_active = false
	if _player != null:
		_player.end_input_override()
	_camera.enabled = true
	_camera.make_current()
	_camera.reset_smoothing()
	_hud.set_opening_active(false)
	_hud.visible = true
	_refresh_exit_gate_available()
	if not _completed and not get_tree().paused:
		_set_guides_suspended(false)


func _on_opening_finished(_skipped: bool) -> void:
	_intro_active = false
	_opening_played = true
	if _opening != null:
		_intro_elapsed = _opening.get_elapsed()
	_camera.enabled = true
	_camera.make_current()
	_camera.reset_smoothing()
	_hud.set_opening_active(false)
	_hud.visible = true
	_refresh_exit_gate_available()
	if not _completed and not get_tree().paused:
		_set_guides_suspended(false)


func _on_opening_aborted() -> void:
	_intro_active = false
	_opening_played = true
	if _opening != null:
		_intro_elapsed = _opening.get_elapsed()
	_camera.enabled = true
	_camera.make_current()
	_camera.reset_smoothing()
	_hud.set_opening_active(false)
	_hud.visible = true
	_refresh_exit_gate_available()
	if not _completed and not get_tree().paused:
		_set_guides_suspended(false)


## Called once by StartMenu after the camera has settled. Starts the local
## opening film from the real spawn; normal starting physics is unchanged.
func begin_from_menu() -> void:
	if _menu_camera != null:
		_menu_camera.enabled = false
	_world.visible = true
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	_player.visible = true
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.clear_input_buffers()
	_camera.enabled = true
	_camera.make_current()
	_camera.reset_smoothing()
	_hud.visible = true
	_hud.set_pause_visible(false)
	_hud.show_completion(false)
	_begin_intro(true)


func _restart_level() -> void:
	if _scene_leaving or _next_level_started:
		return
	if _menu != null and _menu.is_gameplay_blocked():
		return
	_footstep_stop()
	if _opening != null:
		_opening.abort()
	if _pause_menu != null:
		_pause_menu.force_close()
		_pause_menu.set_completion_active(false)
	get_tree().paused = false
	_hud.set_pause_visible(false)
	_hud.show_completion(false)
	# R is a gameplay restart, not a new game: it never starts the opening
	# film again, even if the film had just been aborted.
	_begin_play(true, RESTART_REASON)
	_hud.show_toast("本关已重新开始", 1.2)


func _on_pause_opened() -> void:
	_music.set_paused(true)
	if _intro_active and _opening != null and _opening.is_active():
		# Freeze in place: do not finish the run or close the page. The tree
		# pause stops the opening's own timers; re-assert the movement lock and
		# drop a held Space latch so resume cannot skip the segment or jump.
		_opening.handle_pause_opened()
		_footstep_stop()
		_hud.set_pause_visible(true)
		_hud.release_completion_focus()
		return
	if _intro_active:
		_finish_intro()
	_set_guides_suspended(true)
	_hud.set_pause_visible(true)
	_hud.release_completion_focus()


func _on_pause_resumed() -> void:
	_music.set_paused(false)
	_hud.set_pause_visible(false)
	_player.clear_input_buffers()
	_player.clear_external_force()
	if _intro_active and _opening != null and _opening.is_active():
		# clear_input_buffers() also cleared the override; re-assert the exact
		# opening lock (running axis or stationary page lock) before the next
		# physics tick, and ignore any Space held across the pause.
		_opening.handle_pause_resumed()
		return
	if _completed:
		_hud.focus_completion_primary()
	else:
		_set_guides_suspended(false)


func is_pause_menu_blocked() -> bool:
	if _mechanic_popup != null and _mechanic_popup.is_open():
		return true
	return _menu != null and _menu.is_gameplay_blocked()


func get_mechanic_popup() -> MechanicPopup:
	return _mechanic_popup


func get_mechanic_teach() -> MechanicTeach:
	return _mechanic_teach


func is_mechanic_popup_blocked() -> bool:
	return _is_mechanic_teach_blocked()


func get_pause_menu() -> Node:
	return _pause_menu


func _on_next_level_requested() -> void:
	if not _completed or _next_level_started or _scene_leaving:
		return
	_next_level_started = true
	_footstep_stop()
	_music.stop(0.0)
	if _opening != null:
		_opening.abort()
	_refresh_exit_gate_available()
	_set_guides_suspended(true)
	if _pause_menu != null:
		_pause_menu.prepare_scene_change()
	_hud.set_completion_buttons_enabled(false)
	LEVEL_FLOW.start_level_02(get_tree())


func _return_to_main_menu() -> void:
	if _scene_leaving:
		return
	_scene_leaving = true
	_footstep_stop()
	_music.stop(0.0)
	if _opening != null:
		_opening.abort()
	_refresh_exit_gate_available()
	_set_guides_suspended(true)
	if _pause_menu != null:
		_pause_menu.prepare_scene_change()
	_hud.set_completion_buttons_enabled(false)
	LEVEL_FLOW.return_to_title(get_tree())


func _on_player_polarity_changed(positive: bool) -> void:
	# Only a real Q toggle increments the player's toggle counter. Reset/spawn
	# emits polarity_changed with the counter back at 0, and a scripted
	# set_polarity_state emits without incrementing, so neither can sound.
	var toggles: int = _player.get_polarity_toggle_count()
	if toggles > _last_polarity_toggles:
		DemoAudio.play_polarity_switch(positive)
	_last_polarity_toggles = toggles
	_hud.set_polarity(positive)


func _on_player_reset_performed(reason: String, _count: int) -> void:
	if _resetting:
		return
	_footstep_stop()
	if _intro_active:
		_finish_intro()
	_player.clear_external_force()
	_narrative_guide.on_player_reset(reason)
	_mechanism_guide.on_player_reset(reason)
	if _gate_stele != null and is_instance_valid(_gate_stele):
		_gate_stele.on_player_reset(reason)
	_camera.reset_smoothing()
	match reason:
		"fall":
			DemoAudio.play_respawn()
			_hud.show_toast("跌入云海 · 回到最近恢复点", 2.0)
		"manual":
			_hud.show_toast("已回到本关起点", 1.4)
		_:
			pass


## The full teaching is proximity-only: 56 px in front, facing the closed door,
## never during the opening film or after the run has left gameplay.
func _tick_exit_gate_hint() -> void:
	if _exit_polarity_gate == null or _player == null:
		return
	var dx: float = _exit_polarity_gate.global_position.x - _player.global_position.x
	var distance: float = absf(dx)
	var in_scene: bool = absf(
		_player.global_position.y - _exit_polarity_gate.global_position.y
	) <= 72.0
	var facing_toward: bool = (
		in_scene
		and dx > 0.0
		and signf(dx) == float(_player.get_facing())
	)
	var can_show: bool = not _exit_polarity_gate.is_open()
	if _exit_gate_hint.tick(
		distance, can_show and facing_toward, Time.get_ticks_msec()
	):
		_exit_gate_short_pending = true
		# Registry copy is the single source of the full door lesson.
		if _mechanic_teach != null:
			_mechanic_teach.request("gate")


## The exit-side polarity gate only reads the player's phase.  Contact never
## repeats the full line; after a real approach it leaves only the short Q
## reminder.  No new UI, no key injection, and Q always remains the player's
## own toggle.
func _on_exit_polarity_gate_denied(_required_positive: bool) -> void:
	if _completed or _scene_leaving or _resetting:
		return
	if not _exit_gate_short_pending:
		return
	_exit_gate_short_pending = false
	_exit_gate_short_hint_count += 1
	_hud.show_toast(GATE_SHORT_HINT, 1.4)


func _on_checkpoint_entered(checkpoint: LevelCheckpoint) -> void:
	if _completed or checkpoint == null:
		return
	if _checkpoint.is_activated():
		return
	_checkpoint_position = checkpoint.global_position
	_player.set_spawn_point(_checkpoint_position)
	checkpoint.set_activated(true)
	DemoAudio.play_record_save()
	var taught: bool = _mechanic_teach != null and _mechanic_teach.request("checkpoint")
	if not taught:
		_hud.show_toast("恢复点已激活", 1.4)


func _on_exit_reached() -> void:
	if _completed:
		return
	if _opening != null and _opening.is_active():
		_opening.abort()
	_completed = true
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, chapter_progress_path)
	_footstep_stop()
	_completion_count += 1
	DemoAudio.play_complete()
	_music.stop(BaseLevelMusic.STOP_FADE_SECONDS)
	_exit.set_completed(true)
	_refresh_exit_gate_available()
	_set_guides_suspended(true)
	_intro_active = false
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	_player.velocity = Vector2.ZERO
	if _pause_menu != null:
		_pause_menu.set_completion_active(true)
	_hud.show_completion(true, _elapsed)


func _on_window_focus_exited() -> void:
	if _menu != null and _menu.is_gameplay_blocked():
		# The menu owns settings drag cleanup and transition pause; the level
		# must not finish an intro that has not begun.
		return
	if _completed:
		# Completion freezes the player through the local override. Do not clear
		# that override on focus loss, or the player could walk behind the
		# completion panel when the window regains focus.
		_set_guides_suspended(true)
		return
	if _intro_active and _opening != null and _opening.is_active():
		# Keep the opening's real stage/page/letterbox: open the actual pause page
		# instead of aborting the film. The pause page freezes the tree, drops the
		# Space latch and the controller re-asserts its own movement lock. Focus
		# return does not auto-resume; Esc/继续 is required.
		_footstep_stop()
		if _pause_menu != null:
			_pause_menu.open_pause()
		else:
			_finish_intro()
		return
	if _intro_active:
		_finish_intro()
	_player.reset_movement_input_state()
	_player.clear_external_force()
	# Clear a half-read page even though the tree is not paused; F cannot open
	# or page anything until focus returns.
	_set_guides_suspended(true)


func _on_window_focus_entered() -> void:
	if _menu != null and _menu.is_gameplay_blocked():
		return
	if _completed or _intro_active or get_tree().paused:
		return
	_set_guides_suspended(false)


func _set_guides_suspended(value: bool) -> void:
	if is_instance_valid(_narrative_guide):
		_narrative_guide.set_suspended(value)
	if is_instance_valid(_mechanism_guide):
		_mechanism_guide.set_suspended(value)
	if is_instance_valid(_gate_stele):
		_gate_stele.set_suspended(value)


# --- Test / documentation accessors ---------------------------------------

func get_player() -> PrototypePlayer:
	return _player


func get_hud() -> Level01HUD:
	return _hud


func get_footstep_audio() -> Node:
	return _footsteps


func get_music() -> BaseLevelMusic:
	return _music


func get_camera() -> Camera2D:
	return _camera


func get_opening_camera() -> Camera2D:
	return get_node_or_null("World/OpeningCamera") as Camera2D


func get_checkpoint() -> LevelCheckpoint:
	return _checkpoint


func get_exit_polarity_gate() -> PolarityGate:
	return _exit_polarity_gate


func get_exit_gate_full_hint_count() -> int:
	return _exit_gate_hint.get_shown_count()


func get_exit_gate_short_hint_count() -> int:
	return _exit_gate_short_hint_count


func _refresh_exit_gate_available() -> void:
	if _exit == null:
		return
	var available: bool = (
		not _completed
		and not _intro_active
		and not _scene_leaving
		and not _next_level_started
	)
	if _menu != null and _menu.is_gameplay_blocked():
		available = false
	_exit.set_gate_available(available)


func get_exit() -> LevelExit:
	return _exit


func get_narrative_guide() -> GuideEcho:
	return _narrative_guide


func get_mechanism_guide() -> GuideEcho:
	return _mechanism_guide


func get_gate_stele() -> GuideEcho:
	return _gate_stele


## Deprecated compatibility alias. The old stone shell is gone; this returns the
## GuideEcho that now stands at the same authored point. Do not treat it as a
## TutorialStele.
func get_narrative_stele() -> GuideEcho:
	return _narrative_guide


## Deprecated compatibility alias; see get_narrative_stele().
func get_mechanism_stele() -> GuideEcho:
	return _mechanism_guide


func get_rune_stones() -> Array[RuneStoneField]:
	return _rune_stones.duplicate()


func get_start_position() -> Vector2:
	return _start_position


func get_checkpoint_position() -> Vector2:
	return _checkpoint_position


func get_intro_end_position() -> Vector2:
	# The old IntroEnd marker at x=100 is no longer the hand-off point. The real
	# local stop is about 32 px left of the first narrative echo.
	if _opening != null and is_instance_valid(_opening):
		return Vector2(_opening.get_stop_position_x(), _intro_end.global_position.y)
	return _intro_end.global_position


func get_intro_max_duration() -> float:
	return intro_max_duration


func get_intro_run_speed_ratio() -> float:
	return intro_run_speed_ratio


func get_intro_elapsed() -> float:
	return _intro_elapsed


func get_menu_camera_pan_duration() -> float:
	return menu_camera_pan_duration


func is_intro_active() -> bool:
	return _intro_active


func is_completed() -> bool:
	return _completed


func get_completion_count() -> int:
	return _completion_count


func get_elapsed_seconds() -> float:
	return _elapsed


func get_intro_start_count() -> int:
	return _intro_start_count


func has_played_opening() -> bool:
	return _opening_played


func get_opening() -> OpeningCinematic:
	return _opening


func get_menu() -> StartMenu:
	return _menu


func get_menu_camera() -> Camera2D:
	return _menu_camera


func is_start_menu_enabled() -> bool:
	return enable_start_menu


func get_last_force() -> Vector2:
	return _last_force


func is_paused() -> bool:
	return get_tree().paused


func is_next_level_started() -> bool:
	return _next_level_started


func is_scene_leaving() -> bool:
	return _scene_leaving
