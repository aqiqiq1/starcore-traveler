extends Node

## One extra engine capture for the fixed door->guard turn. It does not rerender
## or overwrite the original seven-image set.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const CAPTURE_DIR: String = "res://screenshots/level03_prototype_20261115"
const MANIFEST_PATH: String = "res://screenshots/level03_prototype_20261115/MANIFEST_TURN.txt"

var _level: Level03
var _player: L3Player
var _cine: L3Cinematic


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _physics(24)
	_player = _level.get_player()
	_cine = _level.get_cine()
	_level.debug_setup_arena_combat(1890.0)
	await _physics(4)
	await _walk_to_x(1902.0, 80)
	var wait: int = 0
	while wait < 420:
		await get_tree().physics_frame
		wait += 1
		if _player.get_facing() == -1 and _cine.get_phase_name() == "DOOR":
			break
	await _physics(2)
	await _capture("level03_07_cine_turn.png",
		"near-gate turn; SETUP arena; REAL: player walked to the locked door. After the closed-door question and the live, unshattered guard's short stone cue, the body actually faces the guard (get_facing=-1) and the exclamation replaces the question; the camera is still on the player before the guard pan.")
	_write_manifest()
	print("LEVEL03_TURN_CAPTURE_DONE")
	get_tree().quit(0)


func _capture(file_name: String, note: String) -> void:
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
	get_tree().paused = false
	await get_tree().process_frame
	_note = note


var _note: String = ""


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_line("Star Core Traveler - level 03 additional engine capture")
	file.store_line("Godot: %s  viewport: 640x360" % Engine.get_version_info()["string"])
	file.store_line("level03_07_cine_turn.png | " + _note)
	file.store_line("This is a focused extra frame; the original seven captures in MANIFEST.txt were not re-rendered.")
	file.close()


func _walk_to_x(target: float, max_frames: int) -> void:
	for _i: int in range(max_frames):
		var dx: float = target - _player.global_position.x
		if absf(dx) <= 2.0:
			break
		var action: StringName = &"move_right" if dx > 0.0 else &"move_left"
		Input.action_press(action)
		await get_tree().physics_frame
		Input.action_release(action)
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	await _physics(2)


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
