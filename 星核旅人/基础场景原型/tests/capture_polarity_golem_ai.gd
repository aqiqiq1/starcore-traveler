extends Node

## Two real-GUI shots for the approved enemy-interference pass:
##   1) polarity_golem_ai_windup.png  - arms raised, before the fist lands
##   2) polarity_golem_ai_hit.png     - fists down and the player visibly pushed
## Old readability/experiment screenshots are never touched.
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/capture_polarity_golem_ai.tscn

const EXPERIMENT_SCENE: PackedScene = preload(
	"res://scenes/experiments/polarity_golem_experiment.tscn"
)
const WINDUP_PATH: String = "res://screenshots/polarity_golem_ai_windup.png"
const HIT_PATH: String = "res://screenshots/polarity_golem_ai_hit.png"

var _game
var _player
var _golem


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
	_player = _game.get_player()
	_golem = _game.get_golem()

	# 1) Windup: enemy stopped, facing locked, arms up (attack sheet frame 4-5).
	_player.global_position = Vector2(346.0, 288.0)
	_player.velocity = Vector2.ZERO
	_golem.global_position = Vector2(380.0, 288.0)
	var windup_frame: int = -1
	for _i: int in range(120):
		await get_tree().physics_frame
		if _golem.get_ai_phase_label() == "举臂预警" and _golem.get_sprite_frame() >= 4:
			windup_frame = _golem.get_sprite_frame()
			break
	await _capture(WINDUP_PATH, "WINDUP", windup_frame)

	# Wait for the real contact, then let the short knockback become visible.
	for _i: int in range(80):
		await get_tree().physics_frame
		if _player.get_hit_count() > 0:
			break
	await _physics(7)
	await _capture(HIT_PATH, "HIT", _golem.get_sprite_frame())

	print("CAPTURE_DONE")
	get_tree().quit(0)


func _capture(path: String, label: String, frame_index: int) -> void:
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
	print("  state=%s ai=%s frame=%d hit_count=%d player=%s golem=%s" % [
		_golem.get_state_name(), _golem.get_ai_phase_label(), frame_index,
		_player.get_hit_count(), str(_player.global_position), str(_golem.global_position)
	])


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
