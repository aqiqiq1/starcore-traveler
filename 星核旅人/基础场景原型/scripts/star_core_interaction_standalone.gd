extends Node2D

## Standalone entry for the star-core interaction room.
##
## The room scene itself is world-only so Main can share its existing Player and
## HUD. This wrapper supplies the same Player/HUD/background when the room is
## run by itself. F4 returns to the normal main scene; R and Esc work normally.

@onready var _room: StarCoreInteractionRoom = $Room
@onready var _player: PrototypePlayer = $World/Player
@onready var _hud: PrototypeHUD = $HUD

var _paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$World.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Room.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Background.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS

	_player.set_spawn_point(_room.get_spawn_position())
	_player.clear_input_buffers()
	_player.clear_external_force()
	_player.set_anchor_room_bounds(false)
	_player.reset_to_spawn("spawn", false)
	_hud.set_interaction_mode(true)
	_hud.set_interaction_navigation(
		"F4: MAIN SCENE   R: RESET   ESC: PAUSE   F3: RANGE/LINE"
	)
	_hud.set_polarity(true)
	_room.activate(_player, _hud)
	_player.reset_performed.connect(_on_player_reset_performed)
	get_window().focus_exited.connect(_on_window_focus_exited)


func _input(event: InputEvent) -> void:
	if _player == null or get_tree().paused:
		return
	if event is InputEventKey:
		_player.handle_key_event(event as InputEventKey)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		_toggle_pause()
	if Input.is_action_just_pressed(&"toggle_debug"):
		var debug_visible: bool = not _player.is_debug_enabled()
		_player.set_debug_enabled(debug_visible)
		_hud.set_debug_visible(debug_visible)
	if Input.is_action_just_pressed(&"toggle_interaction_room") and not get_tree().paused:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_hud.set_pause_visible(_paused)
	_player.clear_input_buffers()
	_player.clear_external_force()


func _on_player_reset_performed(reason: String, _count: int) -> void:
	_room.on_player_reset(reason)
	if reason == "manual":
		_hud.show_toast("RESET - CORE BACK IN START BAY")
	elif reason == "core_out":
		_hud.show_toast("CORE OUT - ROOM RESET")


func _on_window_focus_exited() -> void:
	_player.reset_movement_input_state()
	_room.on_focus_lost()


func get_room() -> StarCoreInteractionRoom:
	return _room


func get_player() -> PrototypePlayer:
	return _player


func get_hud() -> PrototypeHUD:
	return _hud
