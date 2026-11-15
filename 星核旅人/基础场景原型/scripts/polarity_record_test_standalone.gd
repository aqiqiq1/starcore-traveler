extends Node2D

## Standalone entry for the polarity-record test room. Open
## res://scenes/polarity_record_test_room_standalone.tscn and press F6, or press
## F7 from the default main scene. F7 returns to main; R resets record/stone;
## Esc pauses; F3 shows the core and rune-stone force debug.

const MAIN_SCENE: String = "res://scenes/main.tscn"

@onready var _room: PolarityRecordTestRoom = $Room
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
		"F7: MAIN   R: RESET RECORD/STONE   ESC: PAUSE   F3: RANGE/FORCE"
	)
	_hud.set_polarity(true)
	_room.activate(_player, _hud)
	_player.reset_performed.connect(_on_player_reset_performed)
	_player.polarity_changed.connect(_on_player_polarity_changed)
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
	if Input.is_action_just_pressed(&"toggle_record_room") and not get_tree().paused:
		get_tree().change_scene_to_file(MAIN_SCENE)


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_hud.set_pause_visible(_paused)
	_player.clear_input_buffers()
	_player.clear_external_force()


func _on_player_reset_performed(reason: String, _count: int) -> void:
	_room.on_player_reset(reason)
	if reason == "manual":
		_hud.show_toast("RESET - RECORD CLEARED / STONE INITIAL")
	elif reason == "fall":
		_hud.show_toast("FELL - RECORD CLEARED / ROOM RESET")


func _on_player_polarity_changed(positive: bool) -> void:
	_hud.set_polarity(positive)


func _on_window_focus_exited() -> void:
	_player.reset_movement_input_state()
	_room.on_focus_lost()


func get_room() -> PolarityRecordTestRoom:
	return _room


func get_player() -> PrototypePlayer:
	return _player


func get_hud() -> PrototypeHUD:
	return _hud
