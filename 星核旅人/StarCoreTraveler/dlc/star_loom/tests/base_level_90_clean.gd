extends Node

## 90-frame clean smoke for one base level, used by the star-loom regression.
##
##   ... --headless --path . \
##     res://dlc/star_loom/tests/base_level_90_clean.tscn -- level_01
##
## Same load/run check as the raw `--quit-after 90` command, with one teardown
## step: stop the title BGM / world audio, free the scene and let the audio
## thread settle before quit.  That avoids the engine's "resources still in
## use at exit" title_theme.ogg artifact without changing any gameplay state.
## The scene itself still runs for exactly 90 process frames.  This is the same
## established pattern as dlc/rift_workshop/tests/base_level_90_clean.gd.

const SCENES: Dictionary = {
	"level_01": "res://scenes/level_01.tscn",
	"level_02": "res://scenes/level_02.tscn",
	"level_03": "res://scenes/level_03.tscn",
}
const FRAMES: int = 90


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var key: String = args[0] if args.size() > 0 else "level_01"
	var path: String = String(SCENES.get(key, ""))
	if path.is_empty():
		print("BASE_LEVEL_90_CLEAN FAIL: unknown key %s" % key)
		get_tree().quit(1)
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("BASE_LEVEL_90_CLEAN FAIL: cannot load %s" % path)
		get_tree().quit(1)
		return
	var scene: Node = packed.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	for _index: int in range(FRAMES):
		await get_tree().process_frame
	# Teardown only: release the title BGM and world audio before quit.
	var menu: Node = scene.get_node_or_null("StartMenu")
	if menu != null and menu.has_method("stop_title_music_for_test"):
		menu.call("stop_title_music_for_test")
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().current_scene = null
	scene.queue_free()
	for _index: int in range(20):
		await get_tree().process_frame
	print("BASE_LEVEL_90_CLEAN %s frames=%d" % [key, FRAMES])
	get_tree().quit(0)
