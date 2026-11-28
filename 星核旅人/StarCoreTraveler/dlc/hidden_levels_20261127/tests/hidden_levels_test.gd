extends Node

## Hidden side-chapter acceptance test (DLC2 as an optional entrance).
##
## Covers:
##   - the rift discovery flag (default / legacy six-bool files / kskbl);
##   - the 章节 page: four mainline rows + only the rift side row, with the
##     星核试炼场 row removed even when the old trial flag is present;
##   - the rift entrance position and its one-shot 56 px line;
##   - DLC3 镜面裂隙 -> 裂隙工坊 -> 继续主线 back at the checkpoint with both
##     gate mechanisms and the seated core restored;
##   - L3 has no TrialSteleGate node, while the trial scene still loads
##     standalone (its own files/tests are kept);
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
## Captured at the entrance's route_entered signal, before the cut.
var _mirror_commit_alpha: float = -1.0
var _mirror_commit_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	for tip_id: String in ["polarity", "core_carry", "relay_link", "float_platform"]:
		MechanicTips.mark_seen(tip_id)
	_clear_paths()
	await _test_progress_fields()
	await _test_chapter_page()
	await _test_rift_route()
	await _test_trial_disabled()
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
	_check(CHAPTER_PROGRESS.chapter_count() == 5,
		"chapter page has exactly five chapters",
		str(CHAPTER_PROGRESS.chapter_count()))
	_check(CHAPTER_PROGRESS.get_chapter(CHAPTER_PROGRESS.ID_TRIAL).is_empty(),
		"the trial is not a chapter entry")
	var missing: Dictionary = CHAPTER_PROGRESS.load_completed(P_FIELDS)
	_check(not CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_TRIAL, missing),
		"the trial can never be visible")
	var rift_id: String = CHAPTER_PROGRESS.ID_RIFT
	_check(not CHAPTER_PROGRESS.is_discovered(rift_id, missing),
		"rift discovery defaults to false")
	_check(not CHAPTER_PROGRESS.is_visible(rift_id, missing),
		"rift row is hidden by default")
	_check(CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_L1, missing),
		"L1 is always a visible mainline row")
	_check(CHAPTER_PROGRESS.is_visible(CHAPTER_PROGRESS.ID_LOOM, missing),
		"城内 is always a visible mainline row")

	# Legacy file: only the six completion booleans existed.
	var legacy: ConfigFile = ConfigFile.new()
	legacy.set_value("chapters", "l1", true)
	legacy.set_value("chapters", "l2", true)
	legacy.set_value("chapters", "trial", true)
	legacy.set_value("chapters", "discovered_trial", true)
	legacy.save(P_LEGACY)
	var old: Dictionary = CHAPTER_PROGRESS.load_completed(P_LEGACY)
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L1, old),
		"legacy file still loads l1")
	_check(not old.has(CHAPTER_PROGRESS.ID_TRIAL),
		"legacy trial booleans are ignored")
	_check(not CHAPTER_PROGRESS.is_discovered(CHAPTER_PROGRESS.ID_RIFT, old),
		"legacy file keeps rift hidden")

	# Entry writes discovery without completion.
	_check(CHAPTER_PROGRESS.mark_discovered(rift_id, P_FIELDS) == OK,
		"mark_discovered writes the rift flag")
	var discovered: Dictionary = CHAPTER_PROGRESS.load_completed(P_FIELDS)
	_check(CHAPTER_PROGRESS.is_discovered(rift_id, discovered),
		"rift discovery persists")
	_check(not CHAPTER_PROGRESS.is_completed(rift_id, discovered),
		"discovery alone is not a completion")
	_check(CHAPTER_PROGRESS.is_visible(rift_id, discovered),
		"discovered rift is visible")
	_check(CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_TRIAL, P_FIELDS)
			== ERR_INVALID_PARAMETER,
		"the trial can no longer write a discovery flag")
	_check(CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_L1, P_FIELDS)
			== ERR_INVALID_PARAMETER,
		"mainline ids reject discovery writes")

	# First-unfinished skips the hidden side chapter.
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, P_FIELDS)
	var after_l1: Dictionary = CHAPTER_PROGRESS.load_completed(P_FIELDS)
	_check(CHAPTER_PROGRESS.first_uncompleted(after_l1) == CHAPTER_PROGRESS.ID_L2,
		"L1 done: hidden rift does not become the 开始游戏 target",
		CHAPTER_PROGRESS.first_uncompleted(after_l1))

	# kskbl fills completion + discovery for the five listed chapters only.
	_check(CHAPTER_PROGRESS.complete_all(P_FIELDS) == OK, "complete_all writes")
	var all: Dictionary = CHAPTER_PROGRESS.load_completed(P_FIELDS)
	for id: String in CHAPTER_PROGRESS.chapter_ids():
		_check(CHAPTER_PROGRESS.is_completed(id, all), "complete_all completes %s" % id)
		_check(CHAPTER_PROGRESS.is_visible(id, all), "complete_all reveals %s" % id)
	_check(not all.has(CHAPTER_PROGRESS.ID_TRIAL),
		"kskbl does not write the trial flag")


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
	_check(menu.get_chapter_row(CHAPTER_PROGRESS.ID_TRIAL) == null,
		"the trial row is absent, not merely hidden")
	var side_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_RIFT)
	_check(side_row != null and not side_row.visible,
		"rift side row is hidden before discovery")
	_check(side_row != null and side_row.focus_mode == Control.FOCUS_NONE,
		"rift hidden side row cannot take focus")

	menu.call("_close_chapters")
	await _wait_process(3)
	_check(CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_TRIAL, P_PAGE)
			== ERR_INVALID_PARAMETER,
		"the old trial discovery write is rejected")
	# Even a hand-written legacy trial discovery/completion flag must not add a
	# row: load_completed only reads the five listed chapter ids.
	var legacy_trial: ConfigFile = ConfigFile.new()
	legacy_trial.load(P_PAGE)
	legacy_trial.set_value("chapters", "trial", true)
	legacy_trial.set_value("chapters", "discovered_trial", true)
	legacy_trial.save(P_PAGE)
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_RIFT, P_PAGE)
	await _open_chapters(menu)
	_check(menu.get_chapter_row(CHAPTER_PROGRESS.ID_TRIAL) == null,
		"the trial row stays absent even with a legacy trial flag")
	var rift_row: PixelMenuButton = menu.get_chapter_row(CHAPTER_PROGRESS.ID_RIFT)
	_check(rift_row != null and rift_row.visible,
		"rift side row appears after discovery")
	_check(rift_row != null and not rift_row.disabled,
		"rift discovered side row is enterable")
	_check(menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_RIFT) == "可进入",
		"rift discovered row reads 可进入",
		menu.get_chapter_status_text(CHAPTER_PROGRESS.ID_RIFT))
	_check(menu.get_chapters_progress_text() == "已完成 3 / 5",
		"discovery adds the rift row to the visible total",
		menu.get_chapters_progress_text())

	# Same schema as kskbl: everything listed is completed and visible.
	CHAPTER_PROGRESS.complete_all(P_PAGE)
	menu.call("_refresh_chapters", false)
	_check(menu.get_chapters_progress_text() == "已完成 5 / 5",
		"kskbl schema shows 5 / 5", menu.get_chapters_progress_text())
	for id: String in CHAPTER_PROGRESS.chapter_ids():
		var row_after: PixelMenuButton = menu.get_chapter_row(id)
		_check(row_after != null and row_after.visible,
			"%s row visible after all-unlock" % id)
		_check(menu.get_chapter_status_text(id) == "已通关",
			"%s row reads 已通关" % id, menu.get_chapter_status_text(id))
	_check(menu.get_chapter_row(CHAPTER_PROGRESS.ID_TRIAL) == null,
		"kskbl still leaves no trial row")
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
	_check(gate.get_hint_text() == "双面镜 · 进入裂隙工坊",
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
	_check(hud.get_event_text() == "双面镜 · 进入裂隙工坊",
		"rift hint shows the side line", hud.get_event_text())

	if not gate.route_entered.is_connected(_on_mirror_route_entered):
		gate.route_entered.connect(_on_mirror_route_entered.bind(gate))
	await _push_key(KEY_E)
	var entered: bool = await _wait_for_scene(RIFT, 240)
	_check(entered, "E at the mirror rift loads 裂隙工坊", _current_path())
	_check(_mirror_commit_count == 1 and _mirror_commit_alpha >= 0.999,
		"the entrance is fully black at the scene cut",
		"alpha=%.3f count=%d" % [_mirror_commit_alpha, _mirror_commit_count])
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


# --- L3 trial entrance removed ---------------------------------------------

func _test_trial_disabled() -> void:
	print("=== TRIAL ENTRANCE REMOVED ===")
	var packed: PackedScene = load(LEVEL_03) as PackedScene
	_check(packed != null, "level 03 loads")
	if packed == null:
		return
	var level: Node = packed.instantiate()
	level.set("chapter_progress_path", P_TRIAL)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(8)
	await _wait_physics(6)
	_check(level.get_node_or_null("TrialSteleGate") == null,
		"L3 scene has no TrialSteleGate node")
	_check(level.call("get_hidden_trial_gate") == null,
		"L3 exposes no trial gate")
	_check(CHAPTER_PROGRESS.get_chapter(CHAPTER_PROGRESS.ID_TRIAL).is_empty(),
		"trial has no chapter entry")
	_check(not CHAPTER_PROGRESS.chapter_ids().has(CHAPTER_PROGRESS.ID_TRIAL),
		"trial id is not in the chapter list")
	await _drop_current_scene()

	# The trial scene itself is kept and still starts standalone.
	_check(ResourceLoader.exists(TRIAL), "trial scene file still exists")
	SIDE_ROUTE.abort()
	var trial_packed: PackedScene = load(TRIAL) as PackedScene
	_check(trial_packed != null, "trial scene still loads")
	if trial_packed == null:
		return
	var trial: Node = trial_packed.instantiate()
	trial.set("show_intro_guide", false)
	trial.set("show_intro_cinematic", false)
	get_tree().root.add_child(trial)
	get_tree().current_scene = trial
	await _wait_process(8)
	await _wait_physics(6)
	_check(not bool(trial.call("is_side_entry")),
		"standalone trial is not a side-route entry")
	_check(trial.call("get_hud") != null, "standalone trial builds its HUD")
	await _drop_current_scene()


## Connected to the mirror entrance's one-shot signal.  The signal is emitted
## after the 0.8 s fade and before the real scene change, so this is the exact
## alpha the outgoing frame is drawn with.
func _on_mirror_route_entered(_target_id: String, gate: MirrorRiftGate) -> void:
	_mirror_commit_count += 1
	_mirror_commit_alpha = gate.get_cover_alpha()


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
