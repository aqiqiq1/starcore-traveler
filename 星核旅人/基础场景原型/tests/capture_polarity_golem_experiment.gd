extends Node

## One real-GUI capture for the polarity-golem prototype. It stages a real
## gameplay frame (mid-swing after a same-phase hit) so the screenshot shows the
## player, the golem, its head-top HP bar and the experiment HUD together.
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/capture_polarity_golem_experiment.tscn

const EXPERIMENT_SCENE: PackedScene = preload(
	"res://scenes/experiments/polarity_golem_experiment.tscn"
)
const CAPTURE_PATH: String = "res://screenshots/polarity_golem_experiment.png"

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
	_game.reset_experiment()
	await _physics(4)

	# Stage the review frame: same-phase pair, player in front, then a real J
	# swing so the sword arc, the -1 knockback feedback and the HP bar are live.
	player.global_position = Vector2(340.0, 288.0)
	player.velocity = Vector2.ZERO
	golem.global_position = Vector2(390.0, 288.0)
	await _physics(4)

	_send_key(KEY_J, true)
	await _physics(5)
	_send_key(KEY_J, false)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() != 640 or image.get_height() != 360:
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var path: String = ProjectSettings.globalize_path(CAPTURE_PATH)
	var error: Error = image.save_png(path)
	print("%s -> %s" % ["CAPTURE_OK" if error == OK else "CAPTURE_ERROR_%d" % error, path])
	print("player=%s golem=%s hp=%d state=%s result=%s" % [
		str(player.global_position), str(golem.global_position),
		golem.get_hp(), golem.get_state_name(), str(golem.get_last_result())
	])
	print("CAPTURE_DONE")
	get_tree().quit(0 if error == OK else 1)


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
