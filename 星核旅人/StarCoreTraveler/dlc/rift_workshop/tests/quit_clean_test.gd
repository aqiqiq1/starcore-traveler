extends Node

## Real quit-button path: the chapter is playing its ambience, then the HUD's
## 退出游戏 request runs _release_ambience before get_tree().quit().  Run this
## with the console binary and check the log has no leaked OGG objects.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var scene: RiftWorkshop = (
		load(RIFT_SCENE) as PackedScene
	).instantiate() as RiftWorkshop
	scene.show_intro_cinematic = false
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	for _index: int in range(30):
		await get_tree().process_frame
	print("QUIT_CLEAN playing_before=%s" % str(
		scene.get_ambience().is_playing()
	))
	scene.get_hud().quit_requested.emit()
