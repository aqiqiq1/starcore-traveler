extends Node

## Cross-chapter audit harness (2026-11-28).
##
## Covers the gaps left by the focused suites:
##   1. real L1 -> L2 -> L3 -> 城内 completion-button scene changes;
##   2. 城内 completion -> title;
##   3. repeated Enter on a completion page changes the scene once;
##   4. long-Space skip hand-off: pause timing and held jump/polarity;
##   5. pause / manual / guide hide and restore the DLC HUD chrome;
##   6. missing-audio lookup is silent.
##
## State setup uses public level APIs where possible and documented private
## completion helpers only to reach the page under test; every scene change is
## the production change_scene_to_file() path.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/audit_20261128/global_audit_test.tscn

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")

const L1_PATH: String = "res://scenes/level_01.tscn"
const L2_PATH: String = "res://scenes/level_02.tscn"
const L3_PATH: String = "res://scenes/level_03.tscn"
const LOOM_PATH: String = "res://dlc/star_loom/star_loom.tscn"
const RIFT_PATH: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const PROGRESS: String = "user://global_audit_20261128.cfg"

var _checks: int = 0
var _failures: Array[String] = []
var _watching: bool = false
var _last_path: String = ""
var _changes: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_remove_progress()
	await _test_mainline_transitions()
	await _test_base_restart_recovery()
	await _test_loom_return_and_hud()
	await _test_intro_handoff()
	await _test_l1_skip_pause()
	_test_missing_audio()
	await _cleanup()
	print("GLOBAL_AUDIT_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _process(_delta: float) -> void:
	if not _watching:
		return
	var path: String = _current_path()
	if path != _last_path:
		_last_path = path
		_changes.append(path)


# --- helpers ---------------------------------------------------------------

func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_physics(1)
	_push_key(code, false)
	await _wait_process(2)


## PauseMenu reads Input.is_action_just_pressed() in _process; a pushed key
## event alone is not guaranteed to update the singleton action state while
## another physical key is held.  This drives the same action the real key maps
## to, for the base-level pause page only.
func _tap_pause_action() -> void:
	Input.action_press(&"pause")
	await _wait_process(2)
	Input.action_release(&"pause")
	await _wait_process(2)


func _current_path() -> String:
	var current: Node = get_tree().current_scene
	return current.scene_file_path if current != null else "null"


func _start_watch() -> void:
	_changes.clear()
	_last_path = _current_path()
	_watching = true


func _stop_watch() -> Array[String]:
	_watching = false
	var filtered: Array[String] = []
	for path: String in _changes:
		# SceneTree sets current_scene to null for the transition frame; that is
		# part of one change, not a second change.
		if path != "null":
			filtered.append(path)
	return filtered


func _wait_for_scene(path: String, max_frames: int = 360) -> bool:
	for _index: int in range(max_frames):
		if _current_path() == path:
			return true
		await get_tree().process_frame
	return false


func _drop_current_scene() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
		await _wait_process(6)


func _spawn(path: String, configure: Callable = Callable()) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var level: Node = packed.instantiate()
	if configure.is_valid():
		configure.call(level)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(4)
	await _wait_physics(2)
	return level


func _remove_progress() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))


func _enter_twice() -> void:
	# Two full Enter presses on the same completion page, ahead of any scene
	# frame.  A second accepted request would appear as a second path change.
	_push_key(KEY_ENTER, true)
	_push_key(KEY_ENTER, false)
	_push_key(KEY_ENTER, true)
	_push_key(KEY_ENTER, false)


func _primary(level: Node) -> PixelMenuButton:
	var hud: Node = level.call("get_hud")
	if hud == null or not hud.has_method("get_completion_primary_button"):
		return null
	return hud.call("get_completion_primary_button") as PixelMenuButton


func _completion_visible(level: Node) -> bool:
	var hud: Node = level.call("get_hud")
	return hud != null and bool(hud.call("is_completion_visible"))


# --- 1. mainline completion buttons ---------------------------------------

func _test_mainline_transitions() -> void:
	print("=== MAINLINE COMPLETION -> NEXT SCENE ===")

	# L1 -> L2
	var l1: Node = await _spawn(L1_PATH, func(node: Node) -> void:
		node.set("enable_start_menu", false)
		node.set("chapter_progress_path", PROGRESS)
	)
	_check(l1 != null, "L1 loads for the completion transition")
	if l1 == null:
		return
	l1.call("_on_exit_reached")
	await _wait_process(6)
	_check(bool(l1.call("is_completed")) and _completion_visible(l1),
		"L1 completion page opens")
	var l1_primary: PixelMenuButton = _primary(l1)
	_check(l1_primary != null and l1_primary.text == "进入第二关",
		"L1 primary is 进入第二关", l1_primary.text if l1_primary != null else "null")
	_check(l1_primary != null and l1_primary.has_focus(),
		"L1 completion primary owns focus")
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_L1,
		CHAPTER_PROGRESS.load_completed(PROGRESS)),
		"L1 completion wrote l1 to the audit progress file")
	_start_watch()
	_enter_twice()
	var l2_ok: bool = await _wait_for_scene(L2_PATH)
	await _wait_process(6)
	var l1_changes: Array[String] = _stop_watch()
	_check(l2_ok, "L1 completion Enter loads L2", _current_path())
	_check(l1_changes.size() == 1, "L1 completion page changes scene exactly once",
		str(l1_changes))

	var l2: Node = get_tree().current_scene
	if l2 == null or l2.scene_file_path != L2_PATH:
		return
	l2.set("chapter_progress_path", PROGRESS)

	# L2 -> L3.  Public debug restore + the real final-bay record state, then a
	# real exit contact.  This is setup for the completion page, not a fake
	# completion: is_exit_gate_ready() must become true first.
	l2.call("debug_restore_stage", 2, true)
	await _wait_process(2)
	var final_bay: Node = l2.get_node_or_null("Bays/TargetBay")
	_check(final_bay != null, "L2 exposes its final bay")
	if final_bay != null:
		l2.call("_place_record_in_bay", final_bay, true)
	await _wait_process(2)
	var gate_ready: bool = bool(l2.call("is_exit_gate_ready"))
	_check(gate_ready, "L2 final bay + linked record make the exit ready")
	var exit: LevelExit = l2.call("get_exit") as LevelExit
	var player: Node2D = l2.call("get_player") as Node2D
	if exit != null and player != null:
		var rect: Rect2 = exit.get_trigger_rect()
		player.global_position = exit.global_position + Vector2(
			rect.position.x + rect.size.x * 0.5, 0.0
		)
		player.velocity = Vector2.ZERO
	await _wait_physics(2)
	l2.call("_on_exit_reached")
	await _wait_process(6)
	_check(bool(l2.call("is_completed")) and _completion_visible(l2),
		"L2 completion page opens after the real exit contact")
	var l2_primary: PixelMenuButton = _primary(l2)
	_check(l2_primary != null and l2_primary.text == "进入第三关",
		"L2 primary is 进入第三关", l2_primary.text if l2_primary != null else "null")
	_check(l2_primary != null and l2_primary.has_focus(),
		"L2 completion primary owns focus")
	_start_watch()
	_enter_twice()
	var l3_ok: bool = await _wait_for_scene(L3_PATH)
	await _wait_process(6)
	var l2_changes: Array[String] = _stop_watch()
	_check(l3_ok, "L2 completion Enter loads L3", _current_path())
	_check(l2_changes.size() == 1, "L2 completion page changes scene exactly once",
		str(l2_changes))

	var l3: Node = get_tree().current_scene
	if l3 == null or l3.scene_file_path != L3_PATH:
		return
	l3.set("chapter_progress_path", PROGRESS)
	l3.call("_complete_city")
	await _wait_process(6)
	_check(bool(l3.call("is_completed")) and _completion_visible(l3),
		"L3 completion page opens")
	var l3_primary: PixelMenuButton = _primary(l3)
	_check(l3_primary != null and l3_primary.text == "进入城内",
		"L3 primary is 进入城内 when the loom scene exists",
		l3_primary.text if l3_primary != null else "null")
	_check(l3_primary != null and l3_primary.has_focus(),
		"L3 completion primary owns focus")
	_start_watch()
	_enter_twice()
	var loom_ok: bool = await _wait_for_scene(LOOM_PATH)
	await _wait_process(6)
	var l3_changes: Array[String] = _stop_watch()
	_check(loom_ok, "L3 进入城内 loads the loom chapter", _current_path())
	_check(l3_changes.size() == 1, "L3 completion page changes scene exactly once",
		str(l3_changes))
	var loom_loaded: Node = get_tree().current_scene
	if loom_loaded != null and loom_loaded.scene_file_path == LOOM_PATH:
		loom_loaded.set("chapter_progress_path", PROGRESS)
	await _drop_current_scene()


# --- 2. base-level restart / recovery --------------------------------------

func _test_base_restart_recovery() -> void:
	print("=== BASE L2/L3 RESTART / RECOVERY ===")
	var l2: Node = await _spawn(L2_PATH, func(node: Node) -> void:
		node.set("chapter_progress_path", PROGRESS)
	)
	_check(l2 != null, "L2 loads for restart/recovery checks")
	if l2 != null:
		l2.call("debug_restore_stage", 2, true)
		await _wait_process(3)
		l2.call("on_player_reset", "audit_fall")
		await _wait_process(4)
		_check(int(l2.call("get_stable_stage")) == 2,
			"L2 failure keeps the reached linked stage",
			str(l2.call("get_stable_stage")))
		var l2_player: Node2D = l2.call("get_player") as Node2D
		var l2_spawn: Vector2 = l2.call("get_stable_spawn_position")
		_check(l2_player != null and l2_player.global_position.distance_to(l2_spawn) < 3.0,
			"L2 failure returns the player to the stable spawn")
		_check(not bool(l2.call("is_completed")), "L2 failure does not complete the chapter")
		l2.call("_restart_level")
		await _wait_process(4)
		_check(int(l2.call("get_stable_stage")) == 0, "L2 R restart returns to stage 0")
		_check(not bool(l2.call("is_completed")) and not get_tree().paused,
			"L2 R restart leaves a live, unpaused chapter")
		await _drop_current_scene()

	var l3: Node = await _spawn(L3_PATH, func(node: Node) -> void:
		node.set("chapter_progress_path", PROGRESS)
	)
	_check(l3 != null, "L3 loads for restart/recovery checks")
	if l3 != null:
		l3.call("debug_setup_arena_combat", 1900.0, true)
		await _wait_process(3)
		var l3_guard: Node = l3.call("get_guard")
		if l3_guard != null:
			l3_guard.call("debug_force_death")
			await _wait_process(4)
			var l3_hud_text: Node = l3.call("get_hud")
			_check(l3_hud_text != null
				and String(l3_hud_text.call("get_objective_text")) == "取走守卫的星核",
				"L3 defeated-guard objective names the star core",
				String(l3_hud_text.call("get_objective_text")) if l3_hud_text != null else "null")
		l3.call("_retry_combat")
		await _wait_process(4)
		_check(not bool(l3.call("is_completed")) and not bool(l3.call("is_recovery_active")),
			"L3 two-hit retry leaves a live chapter")
		_check(int(l3.call("get_player_hits")) == 0,
			"L3 two-hit retry clears the hit counter")
		l3.call("_complete_city")
		await _wait_process(4)
		_check(bool(l3.call("is_completed")), "L3 completion opens for the R check")
		l3.call("_restart_level")
		await _wait_process(4)
		_check(not bool(l3.call("is_completed")), "L3 R restart clears completion")
		var l3_hud: Node = l3.call("get_hud")
		_check(l3_hud != null and not bool(l3_hud.call("is_completion_visible")),
			"L3 R restart hides the completion page")
		await _drop_current_scene()


# --- 3. loom completion -> title, DLC HUD chrome ---------------------------

func _test_loom_return_and_hud() -> void:
	print("=== LOOM COMPLETION -> TITLE / HUD CHROME ===")
	var loom: Node = await _spawn(LOOM_PATH, func(node: Node) -> void:
		node.set("show_intro_cinematic", false)
		node.set("show_intro_guide", false)
		node.set("chapter_progress_path", PROGRESS)
	)
	_check(loom != null, "loom loads for completion and HUD checks")
	if loom == null:
		return
	var hud: Node = loom.call("get_hud")
	_check(hud != null, "loom exposes its HUD")

	# Pause hides the header and health bar; resume restores both.
	await _tap_key(KEY_ESCAPE)
	await _wait_process(6)
	_check(bool(loom.call("is_pause_open")), "Esc opens the loom pause page")
	_check(hud != null and not bool(hud.call("get_header").call("is_chrome_visible")),
		"loom pause hides the header chrome")
	_check(hud != null and not bool(hud.call("is_health_bar_visible")),
		"loom pause hides the fixed health bar")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(12)
	_check(not bool(loom.call("is_pause_open")), "Esc resumes the loom pause page")
	_check(hud != null and bool(hud.call("get_header").call("is_chrome_visible")),
		"loom resume restores the header chrome")
	_check(hud != null and bool(hud.call("is_health_bar_visible")),
		"loom resume restores the fixed health bar")

	# Manual above the pause page keeps the chrome hidden, and the pause page
	# remains behind it until the manual closes.
	await _tap_key(KEY_ESCAPE)
	await _wait_process(6)
	hud.call("open_manual")
	await _wait_process(4)
	var manual: Node = hud.call("get_manual")
	_check(manual != null and bool(manual.call("is_open")),
		"loom manual opens above the pause page")
	_check(hud != null and not bool(hud.call("get_header").call("is_chrome_visible")),
		"loom manual keeps the header chrome hidden")
	manual.call("close")
	await _wait_process(4)
	_check(bool(loom.call("is_pause_open")), "closing the manual leaves the pause page open")
	_check(hud != null and not bool(hud.call("get_header").call("is_chrome_visible")),
		"pause page still hides chrome after the manual closes")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(12)
	_check(hud != null and bool(hud.call("get_header").call("is_chrome_visible")),
		"chrome returns after closing manual and pause")

	# Completion page and its repeated Enter.
	loom.call("_complete_chapter")
	await _wait_process(8)
	_check(bool(loom.call("is_completed")) and _completion_visible(loom),
		"loom completion page opens")
	var primary: PixelMenuButton = _primary(loom)
	_check(primary != null and primary.text == "返回主界面",
		"loom primary is 返回主界面", primary.text if primary != null else "null")
	_check(primary != null and primary.has_focus(),
		"loom completion primary owns focus")
	_start_watch()
	_enter_twice()
	var title_ok: bool = await _wait_for_scene(L1_PATH)
	await _wait_process(8)
	var changes: Array[String] = _stop_watch()
	_check(title_ok, "loom completion Enter returns to the title scene", _current_path())
	_check(changes.size() == 1, "loom completion page changes scene exactly once",
		str(changes))
	var title: Node = get_tree().current_scene
	var menu: Node = title.get_node_or_null("StartMenu") if title != null else null
	_check(menu != null and bool(menu.call("is_menu_open")),
		"returned title opens its menu")
	_check(CHAPTER_PROGRESS.is_completed(CHAPTER_PROGRESS.ID_LOOM,
		CHAPTER_PROGRESS.load_completed(PROGRESS)),
		"loom completion wrote loom to the audit progress file")
	await _drop_current_scene()


# --- 3. long-Space skip hand-off ------------------------------------------

func _test_intro_handoff() -> void:
	print("=== LONG-SPACE SKIP / HAND-OFF ===")
	var loom: Node = await _spawn(LOOM_PATH, func(node: Node) -> void:
		node.set("show_intro_cinematic", true)
		node.set("show_intro_guide", false)
		node.set("chapter_progress_path", PROGRESS)
	)
	_check(loom != null and bool(loom.call("is_intro_active")),
		"loom intro starts for the skip check")
	if loom == null or not bool(loom.call("is_intro_active")):
		return
	var cinematic: Node = loom.call("get_intro_cinematic")
	_check(cinematic != null, "loom exposes its opening cinematic")
	if cinematic == null:
		return
	_push_key(KEY_SPACE, true)
	await _wait_seconds(0.75)
	_check(bool(cinematic.call("is_skipped")),
		"long Space skips the loom film")
	_check(bool(cinematic.call("is_awaiting_release")),
		"loom keeps the held Space latch until release")
	# "Long-Space skip then immediately pause": press Esc while Space is still
	# held.  The pause page must open and must clear the latch/hand off before
	# the tree freezes, so a release or a held jump/polarity cannot fire later.
	await _tap_key(KEY_ESCAPE)
	await _wait_process(4)
	var paused_during_latch: bool = bool(loom.call("is_pause_open"))
	var latch_cleared: bool = not bool(cinematic.call("is_awaiting_release"))
	var handoff_done: bool = not bool(loom.call("is_intro_active"))
	_check(paused_during_latch and latch_cleared and handoff_done,
		"Esc opens the pause page and clears the Space skip latch",
		"paused=%s latch_cleared=%s handoff=%s" % [
			str(paused_during_latch), str(latch_cleared), str(handoff_done)
		])

	# Hold jump/polarity and release Space while the pause page is still open,
	# then resume.  Neither held action may become the first gameplay input.
	var player: Node = loom.call("get_player")
	var toggles_before: int = int(player.call("get_polarity_toggle_count"))
	Input.action_press(&"jump")
	Input.action_press(&"polarity")
	_push_key(KEY_SPACE, false)
	await _tap_key(KEY_ESCAPE)
	await _wait_physics(4)
	_check(not bool(loom.call("is_intro_active")),
		"loom releases control after the paused skip hand-off")
	_check((player.call("get_state_name") as String) != "jump",
		"held jump at the loom paused hand-off did not start a jump",
		player.call("get_state_name") as String)
	_check(int(player.call("get_polarity_toggle_count")) == toggles_before,
		"held polarity at the loom paused hand-off did not toggle")
	Input.action_release(&"jump")
	Input.action_release(&"polarity")
	await _wait_process(4)

	# A normal Esc after the hand-off must still open the pause page.
	await _tap_key(KEY_ESCAPE)
	await _wait_process(4)
	_check(bool(loom.call("is_pause_open")),
		"Esc opens the loom pause page after the hand-off")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(6)
	await _drop_current_scene()


# --- 4. missing audio ------------------------------------------------------

func _test_l1_skip_pause() -> void:
	print("=== L1 LONG-SPACE SKIP -> PAUSE ===")
	var l1: Node = await _spawn(L1_PATH, func(node: Node) -> void:
		node.set("enable_start_menu", false)
		node.set("chapter_progress_path", PROGRESS)
	)
	_check(l1 != null and bool(l1.call("is_intro_active")),
		"L1 intro starts for the skip-pause check")
	if l1 == null or not bool(l1.call("is_intro_active")):
		return
	var opening: Node = l1.call("get_opening")
	if opening == null:
		return
	_push_key(KEY_SPACE, true)
	await _wait_seconds(0.75)
	_check(bool(opening.call("is_awaiting_release")),
		"L1 keeps the Space latch after the long-hold skip")
	await _tap_pause_action()
	await _wait_process(5)
	_check(bool(l1.call("is_paused")),
		"L1 Esc pauses while the Space skip latch is held")
	await _tap_pause_action()
	await _wait_process(5)
	_check(not bool(l1.call("is_paused")), "L1 second Esc resumes after the skip")
	_push_key(KEY_SPACE, false)
	await _wait_process(5)
	await _drop_current_scene()


func _test_missing_audio() -> void:
	var missing: String = "res://assets/audio/__audit_missing__.ogg"
	var stream: AudioStream = DemoAudio.load_stream_if_exists(missing)
	_check(stream == null, "missing audio path loads as null without an error")
	var played: bool = bool(DemoAudio.call("_play_event", "__audit_missing_event__"))
	_check(not played, "unknown audio event is a silent no-op", str(played))


func _cleanup() -> void:
	Input.action_release(&"jump")
	Input.action_release(&"polarity")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	get_tree().paused = false
	await _drop_current_scene()
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	_remove_progress()
	await _wait_process(16)
