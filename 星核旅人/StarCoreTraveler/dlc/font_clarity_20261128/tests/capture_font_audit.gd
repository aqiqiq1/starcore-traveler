extends Node

## 640x360 font-clarity evidence + runtime label audit (2026-11-28).
## Run WITHOUT --headless (the viewport must really render):
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/font_clarity_20261128/tests/capture_font_audit.tscn
##
## Saves real 640x360 frames to res://screenshots/font_clarity_20261128/ and
## prints one AUDIT line per visible Label / RichTextLabel with the values that
## matter for pixel-font clarity: font size, rect, global scale, alpha, outline
## size and the effective font's AA / hinting / subpixel / oversampling.
## Progress goes to throwaway user files, never user://chapter_progress.cfg.

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")
const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")
const RIFT_GUIDE_SCRIPT = preload("res://dlc/rift_workshop/rift_guide.gd")
const LOOM_GUIDE_SCRIPT = preload("res://dlc/star_loom/loom_guide.gd")
const OUT_DIR: String = "res://screenshots/font_clarity_20261128"
const P_PROGRESS: String = "user://font_clarity_capture.cfg"
const P_MECHANIC: String = "user://font_clarity_manual.cfg"

const L1: String = "res://scenes/level_01.tscn"
const L2: String = "res://scenes/level_02.tscn"
const L3: String = "res://scenes/level_03.tscn"
const TRIAL: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const GUIDE: String = "res://dlc/ui/dlc_guide.tscn"

var _saved: Array[String] = []
var _audit_count: int = 0
var _bad_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MechanicTeach.set_progress_path_override(P_MECHANIC)
	await get_tree().process_frame
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	await _run()
	_cleanup_progress()
	MechanicTeach.clear_progress_path_override()
	print("FONT_AUDIT_DONE saved=%d audit=%d bad=%d files=%s" % [
		_saved.size(), _audit_count, _bad_count, ", ".join(_saved)
	])
	get_tree().quit(0)


func _run() -> void:
	await _capture_title_and_chapters()
	await _capture_opening_dialogue()
	await _capture_l1()
	await _capture_l2()
	await _capture_l3()
	await _capture_dlc(TRIAL, "trial", "12_pause_trial.png", "12b_controls_trial.png", "13_completion_trial.png")
	await _capture_dlc(RIFT, "rift", "14_pause_rift.png", "14b_controls_rift.png", "15_completion_rift.png")
	await _capture_dlc(LOOM, "loom", "16_pause_loom.png", "16b_controls_loom.png", "17_completion_loom.png")
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


# --- Runtime audit ---------------------------------------------------------

func _audit(page: String) -> void:
	_audit_count += 1
	print("AUDIT_PAGE %s" % page)
	for node: Node in get_tree().root.find_children("*", "Label", true, false):
		_emit_label(node as Label, page, false)
	for node: Node in get_tree().root.find_children("*", "RichTextLabel", true, false):
		_emit_label(node as RichTextLabel, page, true)


func _emit_label(control: Control, page: String, rich: bool) -> void:
	if control == null or not control.is_visible_in_tree():
		return
	var label: Label = control as Label
	var rich_label: RichTextLabel = control as RichTextLabel
	var font_size: int = 0
	var font: Font = null
	var outline_size: int = 0
	var text: String = ""
	if rich and rich_label != null:
		font_size = rich_label.get_theme_font_size("normal_font_size")
		font = rich_label.get_theme_font("normal_font")
		outline_size = rich_label.get_theme_constant("outline_size")
		text = rich_label.text
	elif label != null:
		font_size = label.get_theme_font_size("font_size")
		font = label.get_theme_font("font")
		outline_size = label.get_theme_constant("outline_size")
		text = label.text
	var global_scale: Vector2 = control.get_global_transform().get_scale()
	var global_origin: Vector2 = control.get_global_transform().origin
	var alpha: float = _global_alpha(control)
	var flags: Array[String] = []
	if font_size != 12 and font_size != 24:
		flags.append("BAD_SIZE")
	if not _is_int(global_origin.x) or not _is_int(global_origin.y):
		flags.append("BAD_XY")
	if not _is_int(control.position.x) or not _is_int(control.position.y):
		flags.append("BAD_LOCAL_XY")
	if not _is_int(control.size.x) or not _is_int(control.size.y):
		flags.append("BAD_WH")
	if not is_equal_approx(global_scale.x, 1.0) or not is_equal_approx(global_scale.y, 1.0):
		flags.append("BAD_SCALE")
	if alpha < 0.99:
		flags.append("ALPHA")
	if outline_size > 1:
		flags.append("OUTLINE")
	var font_file: FontFile = font as FontFile
	if font_file == null:
		flags.append("NOT_FONTFILE")
	else:
		if font_file.antialiasing != TextServer.FONT_ANTIALIASING_NONE:
			flags.append("AA_ON")
		if font_file.hinting != TextServer.HINTING_NONE:
			flags.append("HINT_ON")
		if font_file.subpixel_positioning != TextServer.SUBPIXEL_POSITIONING_DISABLED:
			flags.append("SUBPIXEL_ON")
		if font_file.generate_mipmaps:
			flags.append("MIPMAPS_ON")
		if not is_equal_approx(font_file.oversampling, 1.0):
			flags.append("OVERSAMPLE_%s" % str(font_file.oversampling))
	var bad: bool = not flags.is_empty()
	if bad:
		_bad_count += 1
	print("AUDIT %s %s text_len=%d size=%d rect=(%.1f,%.1f,%.1f,%.1f) gpos=(%.1f,%.1f) scale=(%.2f,%.2f) alpha=%.2f outline=%d font=%s flags=%s" % [
		page, String(get_tree().root.get_path_to(control)), text.length(),
		font_size, control.position.x, control.position.y, control.size.x, control.size.y,
		global_origin.x, global_origin.y, global_scale.x, global_scale.y, alpha,
		outline_size, font_file.resource_path if font_file != null else "<none>",
		",".join(flags) if bad else "ok",
	])


func _is_int(value: float) -> bool:
	return is_equal_approx(value, roundf(value))


func _global_alpha(node: Node) -> float:
	var alpha: float = 1.0
	var current: Node = node
	while current != null:
		if current is CanvasItem:
			alpha *= (current as CanvasItem).modulate.a
		current = current.get_parent()
	return alpha


# --- Scene loading ---------------------------------------------------------

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
	# The title opens through a 1.0 s black fade; wait it out so the screenshot
	# shows the real menu contrast instead of a half-faded black plate.
	await _wait_seconds(1.25)
	await _save("01_title_page.png")
	_audit("title")
	menu.get_chapter_button().pressed.emit()
	await _wait_process(6)
	await _wait_seconds(0.25)
	var loom_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_LOOM)
	if loom_row != null:
		loom_row.grab_focus()
	await _wait_process(4)
	await _save("02_chapter_page.png")
	_audit("chapter")
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
	_audit("opening_dialogue")
	await _cleanup(level)


# --- L1: pause + manual + completion + HUD event --------------------------

func _capture_l1() -> void:
	_write_mechanic(REGISTRY.all_ids())
	var level: Node = await _load(L1, true, true)
	if level == null:
		return
	var pause: Node = level.call("get_pause_menu") as Node
	var hud: Level01HUD = level.call("get_hud") as Level01HUD
	# The HUD chrome only fades in after the opening film hands over; end the
	# film first so the row/event shots show the real in-game chrome instead of
	# a black frame.
	var opening: Node = level.call("get_opening") as Node
	if opening != null and bool(opening.call("is_active")):
		opening.call("abort")
	await _wait_process(6)
	get_tree().paused = false
	level.call("_finish_intro")
	await _wait_process(6)
	if hud != null:
		await _wait_seconds(0.35)
		await _save("04a_hud_row.png")
		_audit("hud_row_l1")
		var header: Node = hud.get_node_or_null("LevelHUDRoot/HudObjective")
		if header != null and header.has_method("show_event"):
			header.call("show_event", "机关已启动 · 门扉正在开启", 2.4)
			await _wait_seconds(0.35)
			await _save("04b_event_row.png")
			_audit("event_row_l1")
			header.call("clear_event")
			await _wait_seconds(0.2)
	if pause != null:
		pause.call("open_pause")
		await _wait_process(4)
		await _wait_seconds(0.35)
		print("PAUSE_L1 controls=%s" % str(pause.call("has_controls_section")))
		await _save("05_pause_l1.png")
		_audit("pause_l1")
		pause.call("open_manual")
		await _wait_process(4)
		await _wait_seconds(0.25)
		var manual: MechanicManual = pause.call("get_manual") as MechanicManual
		if manual != null:
			print("MANUAL p1=%s rows=%s step=%.0f" % [
				manual.get_page_indicator_text(),
				str(manual.get_visible_row_ids()),
				manual.get_row_step(),
			])
			await _save("06_manual_page1.png")
			_audit("manual_page1")
			await _push_key(KEY_RIGHT)
			await _wait_seconds(0.25)
			print("MANUAL p2=%s rows=%s" % [
				manual.get_page_indicator_text(), str(manual.get_visible_row_ids())
			])
			await _save("07_manual_page2.png")
			_audit("manual_page2")
			manual.close()
			await _wait_process(2)
		pause.call("force_close")
		await _wait_process(2)
	level.call("_on_exit_reached")
	await _wait_seconds(0.65)
	if hud != null:
		print("COMPLETION_L1 %s" % hud.get_completion_text())
	await _save("08_completion_l1.png")
	_audit("completion_l1")
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
		await _wait_seconds(0.35)
		print("PAUSE_L2 controls=%s" % str(pause.call("has_controls_section")))
		await _save("09_pause_l2.png")
		_audit("pause_l2")
		pause.call("force_close")
		await _wait_process(2)
	var hud: Level02HUD = level.get_node_or_null("HUD") as Level02HUD
	if hud != null:
		hud.show_completion(true, 92.0)
		await _wait_seconds(0.65)
		print("COMPLETION_L2 %s" % hud.get_completion_text())
	await _save("10_completion_l2.png")
	_audit("completion_l2")
	await _cleanup(level)


func _capture_l3() -> void:
	var level: Node = await _load(L3, true, true, P_PROGRESS)
	if level == null:
		return
	var pause: Node = level.call("get_pause_menu") as Node
	if pause != null:
		pause.call("open_pause")
		await _wait_process(4)
		await _wait_seconds(0.35)
		print("PAUSE_L3 controls=%s" % str(pause.call("has_controls_section")))
		await _save("11_pause_l3.png")
		_audit("pause_l3")
		pause.call("force_close")
		await _wait_process(2)
	level.call("_complete_city")
	await _wait_seconds(0.65)
	await _save("11b_completion_l3.png")
	_audit("completion_l3")
	await _cleanup(level)


# --- DLC chapters: pause controls page + completion -----------------------

func _capture_dlc(
	path: String, _tag: String, pause_shot: String, controls_shot: String,
	completion_shot: String
) -> void:
	var level: Node = await _load(path, false, true)
	if level == null:
		return
	level.call("_set_paused", true)
	await _wait_process(4)
	await _wait_seconds(0.35)
	await _save(pause_shot)
	_audit(pause_shot.get_basename())
	var hud: Node = level.get_node_or_null("HUD")
	var controls: PixelMenuButton = hud.call("get_pause_controls_button") as PixelMenuButton
	if controls != null:
		controls.pressed.emit()
		await _wait_process(3)
		await _wait_seconds(0.20)
		await _save(controls_shot)
		_audit(controls_shot.get_basename())
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
	await _wait_seconds(0.75)
	print("COMPLETION %s %s" % [
		path.get_file(),
		String(hud.call("get_completion_text"))
		if hud != null and hud.has_method("get_completion_text") else "",
	])
	await _save(completion_shot)
	_audit(completion_shot.get_basename())
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
	await _wait_seconds(0.35)
	for page: int in range(pages):
		var shot_name: String = "%s_guide_%s_p%d.png" % [
			"18" if kind == "rift" else "19", kind, page + 1
		]
		print("GUIDE %s page=%s title=%s demo=%s frames=%d" % [
			kind, guide.get_page_indicator_text(), guide.get_title_text(),
			guide.get_demo_id(), guide.get_demo_frame_count()
		])
		await _save(shot_name)
		_audit(shot_name.get_basename())
		if page + 1 < pages:
			await _push_key(KEY_F)
			await _wait_seconds(0.30)
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
