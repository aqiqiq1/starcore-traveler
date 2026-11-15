extends Node

## Two real-GUI readability screenshots for the latest review:
##   1) ACTIVE: native 12 px head tag "辉相 +" + uncropped bottom HUD;
##   2) RUBBLE: authentic die frame 11 held with "8.0秒后重组".
## Existing screenshots/polarity_golem_experiment.png is never touched.
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/capture_polarity_golem_readability.tscn

const EXPERIMENT_SCENE: PackedScene = preload(
	"res://scenes/experiments/polarity_golem_experiment.tscn"
)
const ACTIVE_PATH: String = "res://screenshots/polarity_golem_readability_active.png"
const RUBBLE_PATH: String = "res://screenshots/polarity_golem_readability_rubble.png"

var _game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://screenshots")
	)
	_game = EXPERIMENT_SCENE.instantiate()
	add_child(_game)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player = _game.get_player()
	var golem = _game.get_golem()

	# 1) Active readable head tag + bottom HUD. The freshly loaded scene is
	# already in the initial active state, so no reset toast is shown.
	await _physics(4)
	player.global_position = Vector2(340.0, 288.0)
	player.velocity = Vector2.ZERO
	golem.global_position = Vector2(390.0, 288.0)
	await _physics(16)
	await _capture(ACTIVE_PATH, "ACTIVE", player, golem)

	# 2) Authentic last die frame held at the production 8 s wait.
	_game.reset_experiment()
	await _physics(3)
	golem.set_scatter_wait_time(8.0)
	golem.debug_set_hp(1)
	player.global_position = Vector2(340.0, 288.0)
	player.velocity = Vector2.ZERO
	golem.global_position = Vector2(390.0, 288.0)
	await _physics(3)
	_send_key(KEY_J, true)
	await _physics(9)
	_send_key(KEY_J, false)
	for _i: int in range(90):
		await get_tree().physics_frame
		if golem.get_state_name() == "RUBBLE":
			break
	await _physics(1)
	await _capture(RUBBLE_PATH, "RUBBLE", player, golem)

	print("CAPTURE_DONE")
	get_tree().quit(0)


func _capture(path: String, label: String, player, golem) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() != 640 or image.get_height() != 360:
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var global_path: String = ProjectSettings.globalize_path(path)
	var error: Error = image.save_png(global_path)
	print("%s %s -> %s" % [
		"CAPTURE_OK" if error == OK else "CAPTURE_ERROR_%d" % error, label, global_path
	])
	print("  state=%s frame=%d visible=%s head=%s player=%s golem=%s" % [
		golem.get_state_name(), golem.get_sprite_frame(),
		str(golem.get_sprite_visible()), golem.get_head_tag_text(),
		str(player.global_position), str(golem.global_position)
	])


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
