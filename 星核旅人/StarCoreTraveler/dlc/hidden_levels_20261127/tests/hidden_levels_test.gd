extends Node

## Hidden side-chapter acceptance test (DLC1/DLC2 as optional entrances).
##
## Covers:
##   - the two discovery flags (default / legacy six-bool files / kskbl);
##   - the 章节 page: four mainline rows always, trial/rift only after the
##     real in-level entrance was entered;
##   - the two entrance positions and their one-shot 56 px lines;
##   - DLC3 镜面裂隙 -> 裂隙工坊 -> 继续主线 back at the checkpoint with both
##     gate mechanisms and the seated core restored;
##   - L3 试炼碑 -> 星核试炼场 -> 继续主线 before the city gate with the real
##     guard/key/door/checkpoint snapshot preserved;
##   - a mid-run exit to the title does not write 已通关.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/hidden_levels_20261127/tests/hidden_levels_test.tscn

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")
const SIDE_ROUTE = preload("res://dlc/shared/side_route/side_route.gd")

const LEVEL_01: String = "res://scenes/level_01.tscn"
const LEVEL_03: String = "res://scenes/level_03.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const TRIAL: String = "res://dlc/trial_chambers/trial_chambers.tscn"

const P_FIELDS: String = "user://hidden_levels_fields.cfg"
const P_PAGE: String = "user://hidden_levels_page.cfg"
const P_RIFT: String = "user://hidden_levels_rift.cfg"
const P_TRIAL: String = "user://hidden_levels_trial.cfg"
const P_LEGACY: String = "user://hidden_levels_legacy.cfg"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	for tip_id: String in ["polarity", "core_carry", "relay_link", "float_platform"]:
		MechanicTips.mark_seen(tip_id)
	_clear_paths()
	await _test_progress_fields()
	await _test_chapter_page()
	await _test_rift_route()
	await _test_trial_route()
	_clear_paths()
	SIDE_ROUTE.abort()
	print("HIDDEN_LEVELS_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	await _wait_process(16)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _clear_paths() -> void:
	for path: String in [P_FIELDS, P_PAGE, P_RIFT, P_TRIAL, P_LEGACY]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- progress fields -------------------------------------------------------

func _test_progress_fields() -> void:
	print("=== PROGRESS FIELDS ===")
	var missing: Dictionary = CHAPTER_PROGRESS.load_completed(P_FIELDS)
	for id: String in [CHAPTER_PROGRESS.ID_TRIAL, CHAPTER_PROGRESS.ID_RIFT]:
		_check(not CHAPTER_PROGRESS.is_discovered(id, missing),
			"%s discovery defaults to false" % id)
		_check(not CHAPTER_PROGRESS.is_visible(id, missing),
			"%s row is hidden by default" % id)
	_check(CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_L1, missing),
		"L1 is always a visible mainline row")
	_check(CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_LOOM, missing),
		"城内 is always a visible mainline row")

	# Legacy file: only the six completion booleans existed.
	var legacy: ConfigFile = ConfigFile.new()
	legacy.set_value("chapters", "l1", true)
	legacy.set_value("chapters", "l2", true)
	legacy.save(P_LEGACY)
	var old: Dictionary = CHAPTER_PROGRESS.load_completed(P_LEGACY)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L1, old),
		"legacy file still loads l1")
	_check(not CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_TRIAL, old),
		"legacy file keeps trial hidden")
	_check(not CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_RIFT, old),
		"legacy file keeps rift hidden")

	# Entry writes discovery without completion.
	_check(CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_TRIAL, P_FIELDS) == OK,
		"mark_discovered writes the trial flag")
	var discovered: Dictionary = CHAPTER_PROGRESS.load_completed(P_FIELDS)
	_check(CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_TRIAL, discovered),
		"trial discovery persists")
	_check(not CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_TRIAL, discovered),
		"discovery alone is not a completion")
	_check(CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_TRIAL, discovered),
		"discovered trial is visible")
	_check(not CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_RIFT, discovered),
		"undiscovered rift stays hidden")
	_check(CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_L1, P_FIELDS)
			== ERR_INVALID_PARAMETER,
		"mainline ids reject discovery writes")

	# First-unfinished skips the hidden side chapters.
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, P_FIELDS)
	var after_l1: Dictionary = CHAPTER_PROGRESS.load_completed(P_FIELDS)
	_check(CHAPTER_PROGRESS.first_uncompleted(after_l1) == CHAPTER_PROGRESS.ID_L2,
		"L1 done: hidden trial does not become the 开始游戏 target",
		CHAPTER_PROGRESS.first_uncompleted(after_l1))

	# kskbl fills completion + discovery.
	_check(CHAPTER_PROGRESS.complete_all(P_FIELDS) == OK, "complete_all writes")
	var all: Dictionary = CHAPTER_PROGRESS.load_completed(P_FIELDS)
	for id: String in CHAPTER_PROGRESS.chapter_ids():
		_check(CHAPTER_PROGRESS.is_completed(id, all), "complete_all completes %s" % id)
		_check(CHAPTER_PROGRESS.is_visible(id, all), "complete_all reveals %s" % id)


# --- title chapter page ----------------------------------------------------

func _test_chapter_page() -> void:
	print("=== CHAPTER PAGE ===")
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, P_PAGE)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L2, P_PAGE)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L3, P_PAGE)
	var level: Node = await _load_level_01(P_PAGE)
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		_check(false, "title menu exists")
		await _drop_current_scene()
		return
	_check(menu.get_start_target_chapter_id() == CHAPTER_PROGRESS.ID_LOOM,
		"开始游戏 targets 城内, not a hidden side chapter",
		menu.get_start_target_chapter_id())
	await _open_chapters(menu)
	_check(menu.get_chapters_progress_text() == "已完成 3 / 4",
		"chapter page reports 3 / 4 before discovery",
		menu.get_chapters_progress_text())
	for id: String in [
		CHAPTER_PROGRESS.ID_L1, CHAPTER_PROGRESS.ID_L2, CHAPTER_PROGRESS.ID_L3,
		CHAPTER_PROGRESS.ID_LOOM,
	]:
		var row: PixelMenuButton = menu.get_chapter_row(id)
		_check(row != null and row.visible, "%s mainline row is present" % id)
	for id: String in [CHAPTER_PROGRESS.ID_TRIAL, CHAPTER_PROGRESS.ID_RIFT]:
		var side_row: PixelMenuButton = menu.get_chapter_row(id)
		_check(side_row != null and not side_row.visible,
			"%s side row is hidden before discovery" % id)
		_check(side_row != null and side_row.focus_mode == Control.FOCUS_NONE,
			"%s hidden side row cannot take focus" % id)

	menu.call("_close_chapters")
	await _wait_process(3)
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_TRIAL, P_PAGE)
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_RIFT, P_PAGE)
	await _open_chapters(menu)
	for id: String in [CHAPTER_PROGRESS.ID_TRIAL, CHAPTER_PROGRESS.ID_RIFT]:
		var side_row: PixelMenuButton = menu.get_chapter_row(id)
		_check(side_row != null and side_row.visible,
			"%s side row appears after discovery" % id)
		_check(side_row != null and not side_row.disabled,
			"%s discovered side row is enterable" % id)
		_check(menu.get_chapter_status_text(id) == "可进入",
			"%s discovered row reads 可进入" % id,
			menu.get_chapter_status_text(id))
	_check(menu.get_chapters_progress_text() == "已完成 3 / 6",
		"discovery adds the two rows to the visible total",
		menu.get_chapters_progress_text())

	# Same schema as kskbl: everything is completed and visible.
	CHAPTER_PROGRESS.complete_all(P_PAGE)
	menu.call("_refresh_chapters", false)
	_check(menu.get_chapters_progress_text() == "已完成 6 / 6",
		"kskbl schema shows 6 / 6", menu.get_chapters_progress_text())
	for id: String in CHAPTER_PROGRESS.chapter_ids():
		var row_after: PixelMenuButton = menu.get_chapter_row(id)
		_check(row_after != null and row_after.visible,
			"%s row visible after all-unlock" % id)
		_check(menu.get_chapter_status_text(id) == "已通关",
			"%s row reads 已通关" % id, menu.get_chapter_status_text(id))
	await _drop_current_scene()


func _load_level_01(progress_path: String) -> Node:
	var packed: PackedScene = load(LEVEL_01) as PackedScene
	if packed == null:
		_check(false, "level_01 loads")
		return null
	var level: Node = packed.instantiate()
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		_check(false, "level_01 carries StartMenu")
		level.queue_free()
		return null
	menu.chapter_progress_path = progress_path
	level.set("enable_start_menu", true)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(8)
	await _wait_physics(3)
	return level


func _open_chapters(menu: StartMenu) -> void:
	menu.get_chapter_button().pressed.emit()
	await _wait_process(5)


# --- DLC3 镜面裂隙 ---------------------------------------------------------

func _test_rift_route() -> void:
	print("=== RIFT ROUTE ===")
	var level: Node = await _load_loom(P_RIFT)
	if level == null:
		return
	var gate: HiddenRouteGate = level.call("get_hidden_rift_gate") as HiddenRouteGate
	var player: L3Player = level.call("get_player") as L3Player
	var hud: LoomHUD = level.call("get_hud") as LoomHUD
	var checkpoint: LevelCheckpoint = level.call("get_checkpoint") as LevelCheckpoint
	_check(gate != null, "DLC3 has a mirror-rift entrance")
	if gate == null or player == null:
		await _drop_current_scene()
		return
	_check(gate.global_position.x >= 410.0 and gate.global_position.x <= 430.0,
		"rift entrance sits after the checkpoint and before the arena",
		"x=%.1f" % gate.global_position.x)
	_check(gate.global_position.x > checkpoint.global_position.x,
		"rift entrance is after the recorded checkpoint")
	_check(level.call("get_arena_enter_x") > gate.global_position.x,
		"rift entrance is before the arena trigger")
	_check(gate.get_hint_text() == "镜面裂隙 · 可进入支线",
		"rift entrance carries the requested line", gate.get_hint_text())
	_check(not _gate_has_collision(gate), "rift entrance has no collision")

	player.global_position = Vector2(gate.global_position.x - 80.0, 320.0)
	player.velocity = Vector2.ZERO
	await _wait_physics(4)
	_check(gate.get_hint_shown_count() == 0,
		"rift hint is silent at 80 px")
	player.global_position = Vector2(gate.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	await _wait_physics(4)
	_check(gate.get_hint_shown_count() == 1,
		"rift hint fires once at 56 px")
	_check(hud.get_event_text() == "镜面裂隙 · 可进入支线",
		"rift hint shows the side line", hud.get_event_text())

	await _push_key(KEY_E)
	var entered: bool = await _wait_for_scene(RIFT, 240)
	_check(entered, "E at the mirror rift loads 裂隙工坊", _current_path())
	var rift: Node = get_tree().current_scene
	_check(rift != null and bool(rift.call("is_side_entry")),
		"裂隙工坊 knows it was entered from the mainline")
	var after_entry: Dictionary = CHAPTER_PROGRESS.load_completed(P_RIFT)
	_check(CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_RIFT, after_entry),
		"entering the rift writes discovered_rift")
	_check(not CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_RIFT, after_entry),
		"entering the rift does not mark it completed")

	# Mid-run exit (pause/game over route): title, no completion, no seed.
	rift.call("_on_hud_title_requested")
	var back_to_title: bool = await _wait_for_scene(LEVEL_01, 240)
	_check(back_to_title, "leaving the rift mid-run returns to the title",
		_current_path())
	_check(not SIDE_ROUTE.is_active(), "mid-run exit clears the side route")
	var after_abort: Dictionary = CHAPTER_PROGRESS.load_completed(P_RIFT)
	_check(not CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_RIFT, after_abort),
		"mid-run exit writes no 已通关")

	# The real entry is now visible on the title's chapter page.
	await _wait_process(8)
	var title: Node = get_tree().current_scene
	var menu: StartMenu = title.get_node_or_null("StartMenu") as StartMenu
	var row_visible: bool = false
	if menu != null:
		menu.chapter_progress_path = P_RIFT
		await _open_chapters(menu)
		var row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_RIFT)
		row_visible = row != null and row.visible
	_check(row_visible, "rift row appears on the title page after the real entry")
	await _drop_current_scene()

	# Second run: complete and return to the mainline.
	var level2: Node = await _load_loom(P_RIFT)
	if level2 == null:
		return
	var gate2: HiddenRouteGate = level2.call("get_hidden_rift_gate") as HiddenRouteGate
	var player2: L3Player = level2.call("get_player") as L3Player
	player2.global_position = Vector2(gate2.global_position.x - 20.0, 320.0)
	player2.velocity = Vector2.ZERO
	await _wait_physics(4)
	await _push_key(KEY_E)
	var entered2: bool = await _wait_for_scene(RIFT, 240)
	_check(entered2, "second rift entry loads the side chapter", _current_path())
	if not entered2:
		await _drop_current_scene()
		return
	var rift2: Node = get_tree().current_scene
	await _settle_side_intro(rift2)
	rift2.call("_complete_chapter")
	await _wait_process(4)
	var rift_hud: RiftWorkshopHUD = rift2.call("get_hud") as RiftWorkshopHUD
	_check(rift_hud.get_completion_primary_button().text == "继续主线",
		"completed side page changes 返回主界面 to 继续主线",
		rift_hud.get_completion_primary_button().text)
	_check(rift_hud.is_completion_primary_mainline(),
		"completed side page uses the mainline action")
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_RIFT,
			CHAPTER_PROGRESS.load_completed(P_RIFT)),
		"real rift completion writes the discovery file")
	rift_hud.get_completion_primary_button().pressed.emit()
	var returned: bool = await _wait_for_scene(LOOM, 240)
	_check(returned, "继续主线 changes back to 星核织机", _current_path())
	if not returned:
		await _drop_current_scene()
		return
	await _wait_process(8)
	var loom: Node = get_tree().current_scene
	var loom_player: L3Player = loom.call("get_player") as L3Player
	var loom_checkpoint: LevelCheckpoint = loom.call("get_checkpoint") as LevelCheckpoint
	var loom_hud: LoomHUD = loom.call("get_hud") as LoomHUD
	_check(bool(loom.call("is_side_resume_active")),
		"returned loom consumed the one-shot resume seed")
	_check(bool(loom.call("get_gate_first").is_open()),
		"first gate is open on return (辉相)")
	_check(bool(loom.call("is_second_gate_powered")),
		"second gate is powered on return (core bay + checkpoint)")
	_check(bool(loom.call("get_gate_second").is_open()),
		"second gate curtain is passable on return (powered proxy)")
	_check(bool(loom.call("get_core_bay").is_occupied()),
		"cyan core is seated in the bay on return")
	_check(bool(loom.call("get_checkpoint").is_activated()),
		"checkpoint is recorded on return")
	_check(loom_player.global_position.distance_to(loom_checkpoint.global_position) <= 1.0,
		"player returns to the recorded checkpoint",
		str(loom_player.global_position))
	_check(not bool(loom.call("is_boss_active")),
		"return does not start the boss fight")
	_check(loom_hud.get_event_text() == "回到检查点 · 继续主线",
		"return shows the mainline continuation line", loom_hud.get_event_text())
	await _drop_current_scene()


# --- L3 试炼碑 -------------------------------------------------------------

func _test_trial_route() -> void:
	print("=== TRIAL ROUTE ===")
	var packed: PackedScene = load(LEVEL_03) as PackedScene
	var level: Node = packed.instantiate()
	level.set("chapter_progress_path", P_TRIAL)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(8)
	await _wait_physics(6)
	var gate: HiddenRouteGate = level.call("get_hidden_trial_gate") as HiddenRouteGate
	var player: L3Player = level.call("get_player") as L3Player
	var hud: L3HUD = level.call("get_hud") as L3HUD
	_check(gate != null, "L3 has a trial-stele entrance")
	if gate == null or player == null:
		await _drop_current_scene()
		return
	var gate_x: float = gate.global_position.x
	var distance_to_end: float = float(level.call("get_city_enter_x")) - gate_x
	_check(distance_to_end >= 200.0 and distance_to_end <= 300.0,
		"trial stele sits 200-300 px before the city end",
		"%.1f px" % distance_to_end)
	_check(gate_x < float(level.call("get_gate").global_position.x),
		"trial stele is before the city gate")
	_check(not _gate_has_collision(gate), "trial stele has no collision")

	# Simulate the real post-guard state the player would have when reaching
	# the stele, then prove the return seed preserves it.
	var guard: L3Guard = level.call("get_guard") as L3Guard
	var city_gate: L3Gate = level.call("get_gate") as L3Gate
	var checkpoint: LevelCheckpoint = level.call("get_checkpoint") as LevelCheckpoint
	guard.debug_force_death()
	city_gate.force_open()
	level.set("_key_taken", true)
	level.set("_key_embedded", true)
	level.set("_stable_stage", 3)
	checkpoint.set_activated(true)
	(level.call("get_cine") as L3Cinematic).mark_played()
	player.global_position = Vector2(gate.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	await _wait_physics(5)
	_check(gate.get_hint_shown_count() == 1, "trial hint fires once at 56 px")
	_check(hud.get_event_text() == "试炼碑 · 可进入支线",
		"trial hint shows the side line", hud.get_event_text())

	await _push_key(KEY_E)
	var entered: bool = await _wait_for_scene(TRIAL, 240)
	_check(entered, "E at the trial stele loads 星核试炼场", _current_path())
	var trial: Node = get_tree().current_scene
	_check(trial != null and bool(trial.call("is_side_entry")),
		"星核试炼场 knows it was entered from L3")
	var after_entry: Dictionary = CHAPTER_PROGRESS.load_completed(P_TRIAL)
	_check(CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_TRIAL, after_entry),
		"entering the trial writes discovered_trial")
	_check(not CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_TRIAL, after_entry),
		"entering the trial does not mark it completed")

	await _settle_side_intro(trial)
	trial.call("_complete_trial")
	await _wait_process(4)
	var trial_hud: TrialHUD = trial.call("get_hud") as TrialHUD
	_check(trial_hud.get_completion_primary_button().text == "继续主线",
		"completed trial page changes 返回主界面 to 继续主线",
		trial_hud.get_completion_primary_button().text)
	_check(trial_hud.is_completion_primary_mainline(),
		"completed trial page uses the mainline action")
	trial_hud.get_completion_primary_button().pressed.emit()
	var returned: bool = await _wait_for_scene(LEVEL_03, 240)
	_check(returned, "继续主线 changes back to 断桥外郭", _current_path())
	if not returned:
		await _drop_current_scene()
		return
	await _wait_process(8)
	var l3: Node = get_tree().current_scene
	var l3_player: L3Player = l3.call("get_player") as L3Player
	var l3_gate: L3Gate = l3.call("get_gate") as L3Gate
	var l3_guard: L3Guard = l3.call("get_guard") as L3Guard
	var l3_checkpoint: LevelCheckpoint = l3.call("get_checkpoint") as LevelCheckpoint
	var l3_hud: L3HUD = l3.call("get_hud") as L3HUD
	_check(bool(l3.call("is_side_resume_active")),
		"returned L3 consumed the one-shot resume seed")
	_check(absf(l3_player.global_position.x - (gate_x - 56.0)) <= 2.0,
		"player returns to the stele spot before the city gate",
		str(l3_player.global_position))
	_check(l3_gate.is_open(), "city gate stays open on return")
	_check(l3_guard.is_defeated(), "defeated guard stays defeated on return")
	_check(bool(l3.call("is_key_taken")), "key core stays taken on return")
	_check(bool(l3.call("is_key_embedded")), "key core stays embedded on return")
	_check(l3_checkpoint.is_activated(), "L3 checkpoint stays recorded on return")
	_check(bool(l3.call("is_checkpoint_mark_visible")),
		"checkpoint mark stays visible on return")
	_check(int(l3.call("get_stable_stage")) >= 3,
		"stable stage stays at the arena")
	_check(bool(l3.call("get_cine").has_played()),
		"near-gate echo film does not replay")
	_check(l3_hud.get_event_text() == "回到城门前 · 继续主线",
		"L3 return shows the mainline continuation line", l3_hud.get_event_text())
	await _drop_current_scene()


# --- helpers ---------------------------------------------------------------

func _load_loom(progress_path: String) -> Node:
	var packed: PackedScene = load(LOOM) as PackedScene
	if packed == null:
		_check(false, "star_loom loads")
		return null
	var level: Node = packed.instantiate()
	level.set("chapter_progress_path", progress_path)
	level.set("show_intro_guide", false)
	level.set("show_intro_cinematic", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(8)
	await _wait_physics(8)
	return level


func _settle_side_intro(scene: Node) -> void:
	scene.set("show_intro_guide", false)
	var intro: Variant = scene.get("_intro_cinematic")
	if intro != null and bool(intro.call("is_active")):
		intro.call("_request_skip")
	for _index: int in range(90):
		var guide: Variant = scene.get("_intro_guide")
		if guide != null and bool(guide.call("is_open")):
			guide.call("close")
			break
		if not bool(scene.get("_intro_active")):
			break
		await _wait_process(1)
	await _wait_process(4)
	var guide_after: Variant = scene.get("_intro_guide")
	if guide_after != null and bool(guide_after.call("is_open")):
		guide_after.call("close")
	await _wait_process(3)


func _gate_has_collision(gate: Node) -> bool:
	for child: Node in gate.get_children():
		if child is CollisionObject2D:
			return true
	return false


func _push_key(code: int) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = code as Key
	down.keycode = code as Key
	down.pressed = true
	get_viewport().push_input(down)
	await _wait_physics(1)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = code as Key
	up.keycode = code as Key
	up.pressed = false
	get_viewport().push_input(up)
	await _wait_process(2)


func _wait_for_scene(path: String, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		var current: Node = get_tree().current_scene
		if current != null and current.scene_file_path == path:
			return true
		await get_tree().process_frame
	return false


func _current_path() -> String:
	var current: Node = get_tree().current_scene
	return current.scene_file_path if current != null else "null"


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _drop_current_scene() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null and is_instance_valid(current):
		current.queue_free()
	await _wait_process(12)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(4)
