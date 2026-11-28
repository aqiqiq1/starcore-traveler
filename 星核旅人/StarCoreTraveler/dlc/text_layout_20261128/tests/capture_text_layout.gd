extends Node

## 640x360 evidence for the 2026-11-28 text-layout pass.
## Run WITHOUT --headless (the viewport must really render):
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/text_layout_20261128/tests/capture_text_layout.tscn
##
## Saves real viewport frames to res://screenshots/text_layout_20261128/:
##   01_title_page.png, 02_chapter_page.png, 03_opening_dialogue.png
##   04_pause_l1.png, 05_manual_page1.png, 06_manual_page2.png
##   07_completion_l1.png, 08_pause_l2.png, 09_completion_l2.png
##   10_pause_l3.png, 11_completion_l3.png, 12_pause_trial.png
##   13_completion_trial.png, 14_pause_rift.png, 15_completion_rift.png
##   16_pause_loom.png, 17_completion_loom.png
##   18_guide_rift_p1..p3.png, 19_guide_loom_p1..p2.png
##
## L1 completion uses the real exit callback; the DLC chapters use their real
## _complete_* callbacks.  L2/L3 use the completion HUD API because reaching the
## authored exit in a capture run is not what this evidence is about; the
## completion page itself (title/subtitle/buttons/footer) is the real HUD page.
## Progress goes to throwaway user files, never user://chapter_progress.cfg.

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")
const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")
const RIFT_GUIDE_SCRIPT = preload("res://dlc/rift_workshop/rift_guide.gd")
const LOOM_GUIDE_SCRIPT = preload("res://dlc/star_loom/loom_guide.gd")
const OUT_DIR: String = "res://screenshots/text_layout_20261128"
const P_PROGRESS: String = "user://text_layout_capture.cfg"
const P_MECHANIC: String = "user://text_layout_manual.cfg"

const L1: String = "res://scenes/level_01.tscn"
const L2: String = "res://scenes/level_02.tscn"
const L3: String = "res://scenes/level_03.tscn"
const TRIAL: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const GUIDE: String = "res://dlc/ui/dlc_guide.tscn"

var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MechanicTeach.set_progress_path_override(P_MECHANIC)
	await get_tree().process_frame
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	await _run()
	_cleanup_progress()
	MechanicTeach.clear_progress_path_override()
	print("TEXT_LAYOUT_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _run() -> void:
	await _capture_title_and_chapters()
	await _capture_opening_dialogue()
	await _capture_l1()
	await _capture_l2()
	await _capture_l3()
	await _capture_dlc_pause(TRIAL, "trial", "12_pause_trial.png", "13_completion_trial.png")
	await _capture_dlc_pause(RIFT, "rift", "14_pause_rift.png", "15_completion_rift.png")
	await _capture_dlc_pause(LOOM, "loom", "16_pause_loom.png", "17_completion_loom.png")
	await _capture_guides()


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _has_property(object: Object, property_name: String) -> bool:
	for entry: Dictionary in object.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(shot_name))
	_saved.append(shot_name)
	print("SHOT %s size=%dx%d error=%d" % [
		shot_name, image.get_width(), image.get_height(), error
	])


func _load(
	path: String, no_menu: bool, no_intro: bool, progress_path: String = ""
) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	var level: Node = packed.instantiate() if packed != null else null
	if level == null:
		print("CAPTURE_FAIL missing scene %s" % path)
		return null
	if no_menu and _has_property(level, "enable_start_menu"):
		level.set("enable_start_menu", false)
	if no_intro:
		for property_name: String in [
			"show_intro_guide", "show_intro_cinematic", "show_mechanic_tips",
		]:
			if _has_property(level, property_name):
				level.set(property_name, false)
	if not progress_path.is_empty() and _has_property(level, "chapter_progress_path"):
		level.set("chapter_progress_path", progress_path)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	get_tree().paused = false
	await _wait_process(8)
	return level


func _cleanup(level: Node) -> void:
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().paused = false
	get_tree().current_scene = null
	if is_instance_valid(level):
		level.queue_free()
	await _wait_process(10)


func _push_key(key: int) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key as Key
	down.keycode = key as Key
	down.pressed = true
	get_viewport().push_input(down)
	await _wait_process(2)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key as Key
	up.keycode = key as Key
	up.pressed = false
	get_viewport().push_input(up)
	await _wait_process(2)


# --- Title / chapter page --------------------------------------------------

func _capture_title_and_chapters() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P_PROGRESS))
	# L1..L3 cleared and the rift already found: five rows, 绗洓鍏?/ 闅愯棌鍏?tags.
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, P_PROGRESS)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L2, P_PROGRESS)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L3, P_PROGRESS)
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_RIFT, P_PROGRESS)
	var level: Node = await _load(L1, false, true, P_PROGRESS)
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		print("CAPTURE_FAIL title menu missing")
		await _cleanup(level)
		return
	menu.get_start_button().grab_focus()
	await _wait_process(4)
	await _save("01_title_page.png")
	menu.get_chapter_button().pressed.emit()
	await _wait_process(6)
	var loom_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_LOOM)
	if loom_row != null:
		loom_row.grab_focus()
	await _wait_process(4)
	print("CHAPTER_TAGS loom=%s rift=%s" % [
		menu.get_chapter_row(CHAPTER_PROGRESS.ID_LOOM) != null,
		menu.get_chapter_row(CHAPTER_PROGRESS.ID_RIFT) != null,
	])
	await _save("02_chapter_page.png")
	menu.call("_close_chapters")
	await _wait_process(2)
	await _cleanup(level)


# --- Opening dialogue ------------------------------------------------------

func _capture_opening_dialogue() -> void:
	var level: Node = await _load(L1, true, false)
	if level == null:
		return
	var opening: Node = level.call("get_opening") as Node
	var guide: GuideEcho = level.call("get_narrative_guide") as GuideEcho
	var ready_frame: bool = false
	# PAGES_START is 10.7 s into the film and the window may run faster than
	# 60 fps, so wait on the real elapsed time instead of a frame count.
	for _index: int in range(600):
		if opening != null and bool(opening.call("is_active")) \
				and float(opening.call("get_elapsed")) >= 11.6 \
				and guide != null and guide.is_dialogue_open():
			ready_frame = true
			break
		await _wait_seconds(0.05)
	await _wait_seconds(0.45)
	print("OPENING_DIALOGUE visible=%s page=%d" % [
		str(ready_frame), guide.get_page_index() if guide != null else -1
	])
	await _save("03_opening_dialogue.png")
	await _cleanup(level)


# --- L1: pause + manual + completion --------------------------------------

func _capture_l1() -> void:
	_write_mechanic(REGISTRY.all_ids())
	var level: Node = await _load(L1, true, true)
	if level == null:
		return
	var pause: Node = level.call("get_pause_menu") as Node
	var hud: Level01HUD = level.call("get_hud") as Level01HUD
	if pause != null:
		pause.call("open_pause")
		await _wait_process(4)
		await _wait_seconds(0.25)
		print("PAUSE_L1 controls=%s" % str(pause.call("has_controls_section")))
		await _save("04_pause_l1.png")
		pause.call("open_manual")
		await _wait_process(4)
		var manual: MechanicManual = pause.call("get_manual") as MechanicManual
		if manual != null:
			print("MANUAL p1=%s rows=%s step=%.0f" % [
				manual.get_page_indicator_text(),
				str(manual.get_visible_row_ids()),
				manual.get_row_step(),
			])
			await _save("05_manual_page1.png")
			await _push_key(KEY_RIGHT)
			print("MANUAL p2=%s rows=%s" % [
				manual.get_page_indicator_text(), str(manual.get_visible_row_ids())
			])
			await _save("06_manual_page2.png")
			manual.close()
			await _wait_process(2)
			# Locked-row evidence: only three recorded, so the rest really draw
			# ？？？ on the same 24 px grid.
			_write_mechanic(["polarity", "gate", "rune"])
			manual.open()
			await _wait_process(3)
			await _save("05b_manual_locked_rows.png")
			manual.close()
			await _wait_process(2)
		pause.call("force_close")
		await _wait_process(2)
	# Real opening end + real exit callback.
	var opening: Node = level.call("get_opening") as Node
	if opening != null and bool(opening.call("is_active")):
		opening.call("abort")
	await _wait_process(6)
	get_tree().paused = false
	level.call("_finish_intro")
	await _wait_process(6)
	level.call("_on_exit_reached")
	await _wait_seconds(0.45)
	if hud != null:
		print("COMPLETION_L1 %s" % hud.get_completion_text())
	await _save("07_completion_l1.png")
	await _cleanup(level)


# --- L2 / L3: pause + completion ------------------------------------------

func _capture_l2() -> void:
	var level: Node = await _load(L2, true, true, P_PROGRESS)
	if level == null:
		return
	var pause: Node = level.call("get_pause_menu") as Node
	if pause != null:
		pause.call("open_pause")
		await _wait_process(4)
		await _wait_seconds(0.25)
		print("PAUSE_L2 controls=%s" % str(pause.call("has_controls_section")))
		await _save("08_pause_l2.png")
		pause.call("force_close")
		await _wait_process(2)
	var hud: Level02HUD = level.get_node_or_null("HUD") as Level02HUD
	if hud != null:
		hud.show_completion(true, 92.0)
		await _wait_seconds(0.45)
		print("COMPLETION_L2 %s" % hud.get_completion_text())
	await _save("09_completion_l2.png")
	await _cleanup(level)


func _capture_l3() -> void:
	var level: Node = await _load(L3, true, true, P_PROGRESS)
	if level == null:
		return
	var pause: Node = level.call("get_pause_menu") as Node
	if pause != null:
		pause.call("open_pause")
		await _wait_process(4)
		await _wait_seconds(0.25)
		print("PAUSE_L3 controls=%s" % str(pause.call("has_controls_section")))
		await _save("10_pause_l3.png")
		pause.call("force_close")
		await _wait_process(2)
	level.call("_complete_city")
	await _wait_seconds(0.45)
	await _save("11_completion_l3.png")
	await _cleanup(level)


# --- DLC chapters: pause controls page + completion -----------------------

func _capture_dlc_pause(
	path: String, _tag: String, pause_shot: String, completion_shot: String
) -> void:
	var level: Node = await _load(path, false, true)
	if level == null:
		return
	level.call("_set_paused", true)
	await _wait_process(4)
	await _wait_seconds(0.30)
	var hud: Node = level.get_node_or_null("HUD")
	var controls: PixelMenuButton = hud.call("get_pause_controls_button") as PixelMenuButton
	if controls != null:
		controls.pressed.emit()
	await _wait_process(3)
	await _wait_seconds(0.15)
	await _save(pause_shot)
	var back: PixelMenuButton = hud.call("get_pause_controls_back_button") as PixelMenuButton
	if back != null:
		back.pressed.emit()
	await _wait_process(2)
	level.call("_set_paused", false)
	await _wait_process(2)
	get_tree().paused = false
	if path == TRIAL:
		hud.call("show_completion", true, 92.0)
	elif path == RIFT or path == LOOM:
		level.call("_complete_chapter")
	await _wait_seconds(0.60)
	print("COMPLETION %s %s" % [
		path.get_file(),
		String(hud.call("get_completion_text"))
		if hud != null and hud.has_method("get_completion_text") else "",
	])
	await _save(completion_shot)
	await _cleanup(level)


# --- DLC guide pages -------------------------------------------------------

func _capture_guides() -> void:
	await _capture_guide(RIFT_GUIDE_SCRIPT, "rift", 3)
	await _capture_guide(LOOM_GUIDE_SCRIPT, "loom", 2)


func _capture_guide(script: Script, kind: String, pages: int) -> void:
	var packed: PackedScene = load(GUIDE) as PackedScene
	var guide: DlcGuide = packed.instantiate() as DlcGuide
	guide.set_script(script)
	guide.name = "CaptureGuide"
	add_child(guide)
	await _wait_process(2)
	guide.configure(kind, null)
	guide.open_guide()
	await _wait_seconds(0.30)
	for page: int in range(pages):
		print("GUIDE %s page=%s title=%s" % [
			kind, guide.get_page_indicator_text(), guide.get_title_text()
		])
		await _save("1%d_guide_%s_p%d.png" % [
			8 if kind == "rift" else 9, kind, page + 1
		])
		if page + 1 < pages:
			await _push_key(KEY_F)
			await _wait_seconds(0.25)
	guide.close()
	await _wait_process(3)
	guide.queue_free()
	await _wait_process(3)
	get_tree().paused = false


func _cleanup_progress() -> void:
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P_PROGRESS))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P_MECHANIC))


func _write_mechanic(ids: Array[String]) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P_MECHANIC))
	var config: ConfigFile = ConfigFile.new()
	for id: String in ids:
		config.set_value("mechanics", id, true)
	config.save(P_MECHANIC)

