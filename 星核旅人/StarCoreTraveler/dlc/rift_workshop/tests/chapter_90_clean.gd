extends Node

## Boot the real rift scene for 90 frames (guide open, ambience under it), then
## stop the OGG playback and give the audio thread a few frames before quitting.
## This is the run_all 90-frame chapter check; the raw --quit-after command is
## also run separately and only differs in engine audio teardown time.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var scene: Node = (load(RIFT_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	for _index: int in range(90):
		await get_tree().process_frame
	var ambience: DlcChapterAmbience = scene.get_ambience()
	if ambience != null:
		var player: AudioStreamPlayer = ambience.get_player()
		if player != null:
			player.stop()
			player.stream = null
		ambience.stop(0.0)
		ambience.set("_stream", null)
		ambience.free()
	for _index: int in range(16):
		await get_tree().process_frame
	get_tree().quit(0)
