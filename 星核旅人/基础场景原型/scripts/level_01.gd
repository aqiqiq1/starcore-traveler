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

@export_range(0.2, 5.0, 0.05, "suffix:s") var intro_max_duration: float = 1.5
## Opening auto-run axis, paired with sprint: target speed = ratio * RUN_SPEED.
## The default 0.75 is 120 px/s, slower than the normal 160 px/s run, while the
## run animation, path, IntroEnd handoff and normal gameplay stay unchanged.
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

@onready var _world: Node2D = $World
@onready var _player: PrototypePlayer = $World/Player
@onready var _camera: Camera2D = $World/Player/Camera2D
@onready var _intro_end: Node2D = $World/IntroEnd
@onready var _checkpoint: LevelCheckpoint = $World/Checkpoint
@onready var _exit: LevelExit = $World/Exit
@onready var _narrative_guide: GuideEcho = $World/GuideEchoMeeting
@onready var _mechanism_guide: GuideEcho = $World/GuideEchoHighstep
@onready var _rune_stones: Array[RuneStoneField] = [
	$World/RuneStoneHigh as RuneStoneField,
	$World/RuneStonePit as RuneStoneField,
]
@onready var _hud: Level01HUD = $HUD
@onready var _menu: StartMenu = $StartMenu
@onready var _menu_camera: Camera2D = $MenuCamera

var _pause_menu = null
var _start_position: Vector2 = Vector2.ZERO
var _checkpoint_position: Vector2 = Vector2.ZERO
var _intro_active: bool = false
var _intro_elapsed: float = 0.0
var _completed: bool = false
var _resetting: bool = false
var _completion_count: int = 0
var _last_polarity_toggles: int = 0
var _last_force: Vector2 = Vector2.ZERO
var _intro_start_count: int = 0
var _next_level_started: bool = false
var _scene_leaving: bool = false


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
	_exit.player_reached_exit.connect(_on_exit_reached)
	get_window().focus_exited.connect(_on_window_focus_exited)
	get_window().focus_entered.connect(_on_window_focus_entered)
	_hud.next_level_requested.connect(_on_next_level_requested)
	_hud.replay_requested.connect(_restart_level)
	_hud.return_to_menu_requested.connect(_return_to_main_menu)
	_setup_pause_menu()

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
	# Esc/R are owned by PauseMenu only.  There is no second polling path here,
	# so one key press cannot toggle pause twice or leak through in the same
	# frame as a GUI action.
	if _intro_active:
		_intro_elapsed += delta
		var reached_end: bool = _player.global_position.x >= _intro_end.global_position.x
		if reached_end or _intro_elapsed >= intro_max_duration:
			_finish_intro()
		elif not _player.is_input_override_active():
			# Pause/focus/reset safety: never leave a stale scripted axis.
			_finish_intro()


func _physics_process(_delta: float) -> void:
	if _menu != null and _menu.is_gameplay_blocked():
		return
	if get_tree().paused or _completed:
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
		["奔跑", "左Shift"],
		["跳跃", "空格"],
		["切换相性", "Q"],
		["交谈", "F"],
		["重来本关", "R"],
		["暂停菜单", "Esc"],
	]
	add_child(_pause_menu)
	_pause_menu.restart_requested.connect(_restart_level)
	_pause_menu.return_to_menu_requested.connect(_return_to_main_menu)
	_pause_menu.opened.connect(_on_pause_opened)
	_pause_menu.resumed.connect(_on_pause_resumed)


func _begin_intro(reset_player: bool) -> void:
	_completed = false
	_set_guides_suspended(true)
	_intro_active = true
	_refresh_exit_gate_available()
	_intro_elapsed = 0.0
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
	_player.begin_input_override()
	# Sprint with a reduced axis so the scripted target is 120 px/s by default.
	# The player's RUN_SPEED/WALK_SPEED constants, animation and physics step
	# stay untouched; normal input is unaffected once control is returned.
	_player.set_input_override_axis(clampf(intro_run_speed_ratio, 0.5, 1.0), true)
	_hud.set_polarity(true)
	_hud.show_completion(false)
	_hud.set_pause_visible(false)
	if _pause_menu != null:
		_pause_menu.set_completion_active(false)
	_hud.show_toast("", 0.0)
	_camera.reset_smoothing()


func _finish_intro() -> void:
	if not _intro_active:
		return
	_intro_active = false
	_player.end_input_override()
	_refresh_exit_gate_available()
	if not _completed and not get_tree().paused:
		_set_guides_suspended(false)


## Called once by StartMenu after the camera has settled on the first frame of
## the opening run. The real intro auto-run below is unchanged.
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
	if _pause_menu != null:
		_pause_menu.force_close()
		_pause_menu.set_completion_active(false)
	get_tree().paused = false
	_hud.set_pause_visible(false)
	_hud.show_completion(false)
	_completed = false
	_intro_active = false
	_exit.set_completed(false)
	_checkpoint.set_activated(false)
	_checkpoint_position = _start_position
	for stone: RuneStoneField in _rune_stones:
		if stone != null:
			stone.reset_state()
	_player.clear_external_force()
	_player.set_spawn_point(_start_position)
	_player.set_physics_process(true)
	_resetting = true
	_player.reset_to_spawn(RESTART_REASON, true)
	_resetting = false
	_player.set_spawn_point(_start_position)
	_narrative_guide.on_player_reset(RESTART_REASON)
	_mechanism_guide.on_player_reset(RESTART_REASON)
	_hud.set_polarity(true)
	_camera.reset_smoothing()
	_begin_intro(false)
	_hud.show_toast("本关已重新开始", 1.2)


func _on_pause_opened() -> void:
	if _intro_active:
		_finish_intro()
	_set_guides_suspended(true)
	_hud.set_pause_visible(true)
	_hud.release_completion_focus()


func _on_pause_resumed() -> void:
	_hud.set_pause_visible(false)
	_player.clear_input_buffers()
	_player.clear_external_force()
	if _completed:
		_hud.focus_completion_primary()
	else:
		_set_guides_suspended(false)


func is_pause_menu_blocked() -> bool:
	return _menu != null and _menu.is_gameplay_blocked()


func get_pause_menu() -> Node:
	return _pause_menu


func _on_next_level_requested() -> void:
	if not _completed or _next_level_started or _scene_leaving:
		return
	_next_level_started = true
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
		DemoAudio.play_polarity_switch()
	_last_polarity_toggles = toggles
	_hud.set_polarity(positive)


func _on_player_reset_performed(reason: String, _count: int) -> void:
	if _resetting:
		return
	if _intro_active:
		_finish_intro()
	_player.clear_external_force()
	_narrative_guide.on_player_reset(reason)
	_mechanism_guide.on_player_reset(reason)
	_camera.reset_smoothing()
	match reason:
		"fall":
			DemoAudio.play_respawn()
			_hud.show_toast("跌入云海 · 回到最近恢复点", 2.0)
		"manual":
			_hud.show_toast("已回到本关起点", 1.4)
		_:
			pass


func _on_checkpoint_entered(checkpoint: LevelCheckpoint) -> void:
	if _completed or checkpoint == null:
		return
	if _checkpoint.is_activated():
		return
	_checkpoint_position = checkpoint.global_position
	_player.set_spawn_point(_checkpoint_position)
	checkpoint.set_activated(true)
	_hud.show_toast("恢复点已激活", 1.4)


func _on_exit_reached() -> void:
	if _completed:
		return
	_completed = true
	_completion_count += 1
	DemoAudio.play_complete()
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
	_hud.show_completion(true, _completion_count)


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
	if _intro_active:
		# Do not leave an auto-run axis latched while the OS owns the keyboard.
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


# --- Test / documentation accessors ---------------------------------------

func get_player() -> PrototypePlayer:
	return _player


func get_hud() -> Level01HUD:
	return _hud


func get_camera() -> Camera2D:
	return _camera


func get_checkpoint() -> LevelCheckpoint:
	return _checkpoint


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


func get_intro_start_count() -> int:
	return _intro_start_count


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
