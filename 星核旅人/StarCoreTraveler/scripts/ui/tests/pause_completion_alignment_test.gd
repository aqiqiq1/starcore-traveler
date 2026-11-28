extends Node

## Focused alignment gate for the six pause/completion pages.
##
##   ... --headless --path . res://scripts/ui/tests/pause_completion_alignment_test.tscn
##
## Checks the DLC2/DLC3 in-panel control reference (open/close, no misclick),
## the base completion timer and real completion callbacks/progress writes, and
## the unified 重玩本关 wording across all six completion pages.

const LEVEL_01: String = "res://scenes/level_01.tscn"
const LEVEL_02: String = "res://scenes/level_02.tscn"
const LEVEL_03: String = "res://scenes/level_03.tscn"
const TRIAL: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")
const P_L1: String = "user://pause_completion_l1.cfg"
const P_L2: String = "user://pause_completion_l2.cfg"
const P_L3: String = "user://pause_completion_l3.cfg"

var _checks: int = 0
var _failures: Array[String] = []
var _resume_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	_cleanup_progress()
	print("PAUSE_COMPLETION_ALIGNMENT checks=%d failures=%d" % [
		_checks, _failures.size()
	])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: " + label + ("" if detail.is_empty() else " [" + detail + "]"))
		return
	_failures.append(label + ("" if detail.is_empty() else " [" + detail + "]"))
	print("FAIL: " + label + ("" if detail.is_empty() else " [" + detail + "]"))


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_process(2)
	_push_key(code, false)
	await _wait_process(2)


func _has_property(object: Object, property_name: String) -> bool:
	for entry: Dictionary in object.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false


func _load_level(
	path: String, no_menu: bool, no_intro: bool, progress_path: String = ""
) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	var level: Node = packed.instantiate() if packed != null else null
	if level == null:
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
	await _wait_physics(2)
	return level


func _cleanup_level(level: Node) -> void:
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().paused = false
	get_tree().current_scene = null
	if is_instance_valid(level):
		level.queue_free()
	await _wait_process(10)


func _panel_border_width(hud: Node) -> int:
	var panel: Panel = hud.find_child("PausePanel", true, false) as Panel
	if panel == null:
		return -1
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	return style.border_width_left if style != null else -1


func _all_twelve(sizes: Array[int]) -> bool:
	if sizes.is_empty():
		return false
	for size: int in sizes:
		if size != 12:
			return false
	return true


## Every completion page owns the same 32x32 double-mirror emblem; it must not
## reuse a guard weakpoint, a star-core texture or the retired gate art.
func _check_completion_emblem(hud: Node, tag: String) -> void:
	var emblem: CompletionEmblem = hud.find_child(
		"CompletionEmblem", true, false
	) as CompletionEmblem
	_check(emblem != null, tag + " completion page has the shared mirror emblem")
	if emblem == null:
		return
	_check(emblem.get_art_id() == CompletionEmblem.ART_ID,
		tag + " emblem is the double-faced mirror art",
		emblem.get_art_id())
	_check(emblem.has_mirror_art() and emblem.is_dedicated_emblem(),
		tag + " emblem is not a guard/star core texture")
	_check(emblem.size == CompletionEmblem.ICON_SIZE,
		tag + " emblem is shown at 32x32", str(emblem.size))
	_check(emblem.position == CompletionEmblem.DEFAULT_POSITION,
		tag + " emblem is in the top-right panel slot", str(emblem.position))


## The primary leaving row must start the shared 0.5 s mirror ripple + black;
## the test tears the level down before the callback changes the scene.
func _check_completion_fade(hud: Node, tag: String) -> void:
	if not hud.has_method("get_completion_mirror_fade"):
		_check(false, tag + " completion page exposes the mirror fade")
		return
	var primary: PixelMenuButton = hud.call("get_completion_primary_button") as PixelMenuButton
	if primary == null or primary.disabled:
		_check(false, tag + " completion primary is pressable")
		return
	primary.pressed.emit()
	await _wait_process(2)
	var fade: CompletionMirrorFade = hud.call("get_completion_mirror_fade") as CompletionMirrorFade
	_check(fade != null, tag + " completion primary starts the mirror fade")
	if fade == null:
		return
	_check(fade.get_cover_alpha() < 0.5,
		tag + " mirror fade starts transparent and darkens", "%.2f" % fade.get_cover_alpha())


func _run() -> void:
	await _test_dlc_pause(TRIAL, "trial", "{Q}")
	await _test_dlc_pause(RIFT, "rift", "本章锁定")
	await _test_dlc_pause(LOOM, "loom", "{Q}")
	await _test_completion_wording_only()
	await _test_l1_completion()
	await _test_l2_completion()
	await _test_l3_completion()


func _test_dlc_pause(path: String, tag: String, phase_copy: String) -> void:
	var level: Node = await _load_level(path, false, true)
	if level == null:
		_check(false, tag + " loads for the pause check")
		return
	level.call("_set_paused", true)
	await _wait_process(6)
	var hud: Node = level.get_node_or_null("HUD")
	if hud == null:
		_check(false, tag + " exposes its HUD")
		await _cleanup_level(level)
		return
	_resume_count = 0
	hud.resume_requested.connect(func() -> void: _resume_count += 1)

	_check(bool(level.call("is_pause_open")) and bool(hud.call("is_pause_visible")),
		tag + " pause page opens")
	_check(get_tree().paused, tag + " pause page pauses the tree")
	_check(_panel_border_width(hud) == 2, tag + " pause panel border is 2 px",
		str(_panel_border_width(hud)))

	var labels: Array[String] = ["继续游戏", "重新开始本章", "返回主界面", "退出游戏", "操作", "手册"]
	var buttons: Array[PixelMenuButton] = [
		hud.call("get_continue_button") as PixelMenuButton,
		hud.call("get_restart_button") as PixelMenuButton,
		hud.call("get_title_button") as PixelMenuButton,
		hud.call("get_quit_button") as PixelMenuButton,
		hud.call("get_pause_controls_button") as PixelMenuButton,
		hud.call("get_manual_button") as PixelMenuButton,
	]
	var order_ok: bool = true
	for index: int in range(buttons.size()):
		if buttons[index] == null or buttons[index].text != labels[index]:
			order_ok = false
	_check(order_ok, tag + " keeps the four original rows then 操作/手册")
	_check(buttons[4] != null and buttons[4].position == Vector2(76.0, 192.0)
		and buttons[5] != null and buttons[5].position == Vector2(184.0, 192.0),
		tag + " 操作 / 手册 split the y=192 row")
	_check(not bool(hud.call("is_controls_visible")),
		tag + " starts on the pause menu, not the table")

	# Clicking 操作 opens the one-page table without touching the pause state.
	buttons[4].pressed.emit()
	await _wait_process(4)
	_check(bool(hud.call("is_controls_visible")), tag + " click opens 操作 table")
	_check(bool(hud.call("is_pause_visible")) and get_tree().paused,
		tag + " 操作 table keeps the pause page open")
	_check(_resume_count == 0, tag + " 操作 click never resumes")
	_check(not buttons[0].visible and not buttons[4].visible and not buttons[5].visible,
		tag + " menu rows hide behind the table")
	var controls_text: String = String(hud.call("get_controls_text"))
	_check(controls_text.contains("移动") and controls_text.contains("跳跃")
		and controls_text.contains("攻击") and controls_text.contains("换相")
		and controls_text.contains("暂停") and controls_text.contains("重开"),
		tag + " table lists all six real actions", controls_text)
	if phase_copy == "本章锁定":
		_check(controls_text.contains("本章锁定"),
			tag + " locked copy is 本章锁定", controls_text)
	else:
		_check(controls_text.contains("Q  换相") and not controls_text.contains("本章锁定"),
			tag + " live-Q copy is Q 换相", controls_text)
	_check(_all_twelve(hud.call("get_control_label_font_sizes")),
		tag + " every table label is 12 px",
		str(hud.call("get_control_label_font_sizes")))
	var back: PixelMenuButton = hud.call("get_pause_controls_back_button") as PixelMenuButton
	await _wait_process(2)
	_check(back != null and back.has_focus(), tag + " 返回 owns focus on the table")

	# Enter only closes the table; it must not resume the chapter.
	await _tap_key(KEY_ENTER)
	_check(not bool(hud.call("is_controls_visible")),
		tag + " Enter closes the 操作 table")
	_check(bool(hud.call("is_pause_visible")) and get_tree().paused,
		tag + " Enter leaves the pause page open")
	_check(_resume_count == 0, tag + " Enter in the table does not resume")

	# F re-opens; Esc closes only the table, then a second Esc resumes.
	await _tap_key(KEY_F)
	_check(bool(hud.call("is_controls_visible")), tag + " F opens the 操作 table")
	await _tap_key(KEY_ESCAPE)
	_check(not bool(hud.call("is_controls_visible"))
		and bool(hud.call("is_pause_visible")) and get_tree().paused,
		tag + " Esc closes only the table")
	_check(_resume_count == 0, tag + " closing the table does not resume")
	await _tap_key(KEY_ESCAPE)
	_check(not bool(level.call("is_pause_open")) and not get_tree().paused,
		tag + " second Esc closes the pause page")
	await _cleanup_level(level)


func _test_completion_wording_only() -> void:
	var trial: Node = await _load_level(TRIAL, false, true)
	if trial != null:
		var trial_hud: Node = trial.get_node("HUD")
		var trial_replay: PixelMenuButton = (
			trial_hud.call("get_completion_replay_button") as PixelMenuButton
		)
		_check(trial_replay != null and trial_replay.text == "重玩本关",
			"trial completion replay is 重玩本关")
		_check(bool(trial_hud.call("has_controls_section")),
			"trial pause owns the control table")
		_check(String(trial_hud.call("get_completion_note_text"))
			== "本章结算 · 暂停菜单可查看操作",
			"trial footnote keeps the true table promise",
			String(trial_hud.call("get_completion_note_text")))
		_check_completion_emblem(trial_hud, "trial")
		await _check_completion_fade(trial_hud, "trial")
		await _cleanup_level(trial)

	var rift: Node = await _load_level(RIFT, false, true)
	if rift != null:
		var rift_hud: Node = rift.get_node("HUD")
		var rift_replay: PixelMenuButton = (
			rift_hud.call("get_completion_replay_button") as PixelMenuButton
		)
		_check(rift_replay != null and rift_replay.text == "重玩本关",
			"rift completion replay is 重玩本关")
		_check(bool(rift_hud.call("has_controls_section")),
			"rift pause owns the control table")
		_check(String(rift_hud.call("get_completion_footer_text"))
			== "本章结算 · 暂停菜单可查看操作",
			"rift footnote keeps the true table promise")
		_check_completion_emblem(rift_hud, "rift")
		await _check_completion_fade(rift_hud, "rift")
		await _cleanup_level(rift)

	var loom: Node = await _load_level(LOOM, false, true)
	if loom != null:
		var loom_hud: Node = loom.get_node("HUD")
		var loom_replay: PixelMenuButton = (
			loom_hud.call("get_completion_secondary_button") as PixelMenuButton
		)
		_check(loom_replay != null and loom_replay.text == "重玩本关",
			"loom completion replay is 重玩本关")
		_check(bool(loom_hud.call("has_controls_section")),
			"loom pause owns the control table")
		_check(String(loom_hud.call("get_completion_note_text"))
			== "本章结算 · 暂停菜单可查看操作",
			"loom footnote keeps the true table promise")
		_check_completion_emblem(loom_hud, "loom")
		await _check_completion_fade(loom_hud, "loom")
		await _cleanup_level(loom)


func _time_pattern_for(prefix: String) -> RegEx:
	var expression: RegEx = RegEx.new()
	expression.compile("^%s · 用时 [0-9]{2}:[0-9]{2}$" % prefix)
	return expression


func _test_l1_completion() -> void:
	var level: Node = await _load_level(LEVEL_01, true, false, P_L1)
	if level == null:
		_check(false, "L1 loads for completion")
		return
	level.call("_finish_intro")
	await _wait_process(10)
	await _wait_seconds(1.2)
	_check(float(level.call("get_elapsed_seconds")) > 0.0,
		"L1 gameplay timer is running", "%.2f" % float(level.call("get_elapsed_seconds")))
	level.call("_on_exit_reached")
	await _wait_process(5)
	var hud: Node = level.get_node("HUD")
	var text: String = String(hud.call("get_completion_text"))
	_check(bool(level.call("is_completed")), "L1 completion callback still fires")
	_check(_time_pattern_for("第一关完成").search(text) != null,
		"L1 completion shows 第一关完成 · 用时 mm:ss", text)
	_check(not text.contains("00:00"), "L1 completion time is greater than zero", text)
	_check(_completion_buttons_match(hud, "进入第二关"),
		"L1 buttons are 进入第二关 / 重玩本关 / 返回主界面")
	_check_completion_emblem(hud, "L1")
	await _check_completion_fade(hud, "L1")
	var completed: Dictionary = CHAPTER_PROGRESS.load_completed(P_L1)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L1, completed),
		"L1 completion still writes l1 progress")
	await _cleanup_level(level)


func _completion_buttons_match(hud: Node, primary_text: String) -> bool:
	var primary: PixelMenuButton = hud.call("get_completion_primary_button") as PixelMenuButton
	var replay: PixelMenuButton = hud.call("get_completion_replay_button") as PixelMenuButton
	var return_button: PixelMenuButton = (
		hud.call("get_completion_return_button") as PixelMenuButton
	)
	return (
		primary != null and primary.text == primary_text
		and replay != null and replay.text == "重玩本关"
		and return_button != null and return_button.text == "返回主界面"
	)


func _test_l2_completion() -> void:
	var level: Node = await _load_level(LEVEL_02, false, false, P_L2)
	if level == null:
		_check(false, "L2 loads for completion")
		return
	await _wait_seconds(1.2)
	_check(float(level.call("get_elapsed_seconds")) > 0.0,
		"L2 gameplay timer is running", "%.2f" % float(level.call("get_elapsed_seconds")))
	var player: Node2D = level.get_node("Player") as Node2D
	player.set_physics_process(false)
	var final_bay: StarCoreBayInteractable = (
		level.get_node("Bays/TargetBay") as StarCoreBayInteractable
	)
	final_bay.reset_locked()
	var linked_bay: StarCoreBayInteractable = (
		level.get_node("Bays/LinkedBay") as StarCoreBayInteractable
	)
	linked_bay.reset_empty()
	linked_bay.start_store_core(true)
	linked_bay.finish_store()
	var link: BayRuneLink = level.get_node("LinkController") as BayRuneLink
	link.restore_committed(true, true)
	var rune: RuneStoneField = level.get_node("RuneField") as RuneStoneField
	rune.restore_committed_state(true, true)
	var exit_node: LevelExit = level.get_node("Exit") as LevelExit
	player.global_position = exit_node.global_position + Vector2(0.0, -10.0)
	level.call("_on_exit_reached")
	await _wait_process(5)
	var hud: Node = level.get_node("HUD")
	var text: String = String(hud.call("get_completion_text"))
	_check(bool(level.call("is_completed")), "L2 completion callback still fires")
	_check(_time_pattern_for("第二关完成").search(text) != null,
		"L2 completion shows 第二关完成 · 用时 mm:ss", text)
	_check(not text.contains("00:00"), "L2 completion time is greater than zero", text)
	_check(_completion_buttons_match(hud, "进入第三关"),
		"L2 buttons are 进入第三关 / 重玩本关 / 返回主界面")
	_check_completion_emblem(hud, "L2")
	await _check_completion_fade(hud, "L2")
	var completed: Dictionary = CHAPTER_PROGRESS.load_completed(P_L2)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L2, completed),
		"L2 completion still writes l2 progress")
	await _cleanup_level(level)


func _test_l3_completion() -> void:
	var level: Node = await _load_level(LEVEL_03, false, false, P_L3)
	if level == null:
		_check(false, "L3 loads for completion")
		return
	await _wait_seconds(1.2)
	_check(float(level.call("get_elapsed_seconds")) > 0.0,
		"L3 gameplay timer is running", "%.2f" % float(level.call("get_elapsed_seconds")))
	level.call("_complete_city")
	await _wait_process(5)
	var hud: L3HUD = level.get_node("HUD") as L3HUD
	var text: String = String(hud.call("get_completion_text"))
	_check(bool(level.call("is_completed")), "L3 completion callback still fires")
	_check(_time_pattern_for("第三关完成").search(text) != null,
		"L3 completion shows 第三关完成 · 用时 mm:ss", text)
	_check(not text.contains("00:00"), "L3 completion time is greater than zero", text)
	_check(hud.has_next_level_button() and _completion_buttons_match(hud, "进入城内"),
		"L3 buttons are 进入城内 / 重玩本关 / 返回主界面")
	_check_completion_emblem(hud, "L3")
	await _check_completion_fade(hud, "L3")
	var completed: Dictionary = CHAPTER_PROGRESS.load_completed(P_L3)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L3, completed),
		"L3 completion still writes l3 progress")

	# 进入城内 must be a real route, not only a label.
	var next_button: PixelMenuButton = hud.get_completion_primary_button()
	next_button.pressed.emit()
	var changed: bool = false
	for _index: int in range(240):
		var current: Node = get_tree().current_scene
		if current != null and current != level:
			changed = true
			break
		await get_tree().process_frame
	await _wait_process(6)
	var new_path: String = ""
	if get_tree().current_scene != null:
		new_path = get_tree().current_scene.scene_file_path
	_check(changed and new_path == "res://dlc/star_loom/star_loom.tscn",
		"L3 进入城内 starts the loom scene", new_path)
	if changed and get_tree().current_scene != null:
		await _cleanup_level(get_tree().current_scene)
	else:
		await _cleanup_level(level)


func _cleanup_progress() -> void:
	get_tree().paused = false
	for path: String in [P_L1, P_L2, P_L3]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
