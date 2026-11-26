extends Node

## 640x360 evidence for the shared UiReveal.  Run WITHOUT --headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://scripts/ui/tests/capture_ui_reveal.tscn
##
## Saves mid-open / settled / mid-close frames for the base pause page, the
## mechanic popup and the shared DLC guide into scripts/ui/tests/out/.
## The shots are real viewport captures, not mockups.

const LEVEL_02: String = "res://scenes/level_02.tscn"
const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const OUT_DIR: String = "res://scripts/ui/tests/out"

var _saved: Array[String] = []
var _level: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _capture_pause()
	await _capture_popup()
	await _capture_guide()
	print("UI_REVEAL_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	_saved.append(name)
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _load_level_02() -> Node:
	var level: Node = (load(LEVEL_02) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	_level = level
	await _wait_process(10)
	return level


func _free_current() -> void:
	if _level == null:
		return
	get_tree().current_scene = null
	_level.queue_free()
	_level = null
	await _wait_process(6)


func _tap_f() -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_F
	down.keycode = KEY_F
	down.pressed = true
	get_viewport().push_input(down)
	await _wait_process(1)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_F
	up.keycode = KEY_F
	up.pressed = false
	get_viewport().push_input(up)
	await _wait_process(1)


func _capture_pause() -> void:
	print("=== PAUSE CAPTURE ===")
	var level: Node = await _load_level_02()
	var pause: Node = level.call("get_pause_menu") as Node
	if pause == null:
		print("CAPTURE_FAIL pause menu missing")
		await _free_current()
		return
	pause.call("open_pause")
	await _wait_seconds(0.07)
	await _save("base_pause_open_mid.png")
	await _wait_seconds(0.20)
	await _save("base_pause_open_end.png")
	pause.call("resume")
	await _wait_seconds(0.075)
	await _save("base_pause_close_mid.png")
	await _wait_seconds(0.15)
	await _save("base_pause_closed.png")
	await _free_current()


func _capture_popup() -> void:
	print("=== MECHANIC POPUP CAPTURE ===")
	var level: Node = await _load_level_02()
	var popup: MechanicPopup = level.call("get_mechanic_popup") as MechanicPopup
	if popup == null:
		print("CAPTURE_FAIL mechanic popup missing")
		await _free_current()
		return
	if not popup.open_for_test("core_carry"):
		print("CAPTURE_FAIL mechanic popup did not open")
		await _free_current()
		return
	await _wait_seconds(0.07)
	await _save("base_mechanic_open_mid.png")
	await _wait_seconds(0.20)
	await _save("base_mechanic_open_end.png")
	popup.close()
	await _wait_seconds(0.075)
	await _save("base_mechanic_close_mid.png")
	await _wait_seconds(0.15)
	await _save("base_mechanic_closed.png")
	await _free_current()


func _capture_guide() -> void:
	print("=== DLC GUIDE CAPTURE ===")
	var level: Node = (load(TRIAL_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	_level = level
	var guide: DlcGuide = null
	for _index: int in range(30):
		await get_tree().process_frame
		if level.has_method("get_intro_guide"):
			guide = level.call("get_intro_guide") as DlcGuide
			if guide != null and guide.is_open():
				break
	if guide == null or not guide.is_open():
		print("CAPTURE_FAIL trial guide missing")
		await _free_current()
		return
	# Let the auto-open start from a clean hidden rest, then capture the first
	# real open transition and the settled page.
	guide.close()
	await _wait_seconds(0.16)
	if not guide.open_guide():
		print("CAPTURE_FAIL trial guide did not reopen")
		await _free_current()
		return
	await _wait_seconds(0.07)
	await _save("dlc_guide_open_mid.png")
	await _wait_seconds(0.20)
	await _save("dlc_guide_open_end.png")
	# F closes from the last page; capture its 0.12 s exit.
	await _tap_f()
	await _wait_process(2)
	await _tap_f()
	await _wait_process(2)
	await _tap_f()
	await _wait_seconds(0.075)
	await _save("dlc_guide_close_mid.png")
	await _wait_seconds(0.15)
	await _save("dlc_guide_closed.png")
	await _free_current()
