extends Node

## Contract checks for the reworked level-01 opening:
##   - it plays on the first new game with HUD hidden and input locked;
##   - movement / polarity / jump / damage cannot happen during the film;
##   - F skips immediately, hold Space for 0.6 s also skips;
##   - the skip snaps to the hand-off point and does not leave half a film;
##   - the natural film hands control back, HUD appears and camera returns;
##   - failure recovery and R never replay the film.

const LEVEL_SCENE: String = "res://scenes/level_01.tscn"
const PROMPT_FOOTER_SCRIPT = preload("res://scripts/ui/prompt_footer.gd")

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _test_menu_entry()
	await _test_first_play_locks_and_finish()
	await _test_f_skip()
	await _test_space_skip()
	await _test_r_during_film()
	await _cleanup()
	print("OPENING_L1_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _spawn() -> Level01:
	var level: Level01 = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level01
	level.enable_start_menu = false
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(4)
	return level


func _test_menu_entry() -> void:
	print("=== L1 OPENING MENU ENTRY ===")
	var level: Level01 = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level01
	level.enable_start_menu = true
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(4)
	_check(not level.is_intro_active(), "title menu holds the opening before entry")
	level.begin_from_menu()
	await _wait_process(6)
	var opening: OpeningCinematic = level.get_opening()
	_check(level.is_intro_active(), "new-game entry starts the opening")
	_check(opening != null and opening.is_playing(), "menu entry film is playing")
	_check(opening != null and opening.get_play_count() == 1,
		"menu entry starts exactly one film")
	_check(get_viewport().get_camera_2d()
		== (opening.get_opening_camera() if opening != null else null),
		"menu entry selects the authored opening camera")
	_check(level.get_music().is_playing(), "menu entry starts the level music")
	if opening != null:
		opening.abort()
	await _wait_process(6)
	level.queue_free()
	await _wait_process(8)


func _test_first_play_locks_and_finish() -> void:
	print("=== L1 OPENING FIRST PLAY / LOCK / NATURAL FINISH ===")
	var level: Level01 = await _spawn()
	var opening: OpeningCinematic = level.get_opening()
	var player: PrototypePlayer = level.get_player()
	var hud: Level01HUD = level.get_hud()
	_check(opening != null, "opening exists on first play")
	if opening == null or player == null:
		if level != null:
			level.queue_free()
			await get_tree().process_frame
		return
	_check(level.is_intro_active(), "intro active on first new game")
	_check(opening.is_playing(), "film is playing")
	_check(level.has_played_opening(), "first play is recorded")
	_check(level.get_intro_start_count() == 1, "film started exactly once")
	_check(opening.get_play_count() == 1, "controller play count is 1")
	_check(opening.get_duration() >= 18.0 and opening.get_duration() <= 22.0,
		"duration is in 18-22 s", str(opening.get_duration()))
	_check(opening.get_dialogue_echo() != null, "film owns a real GuideEcho")
	_check(opening.get_prompt_footer() != null, "film owns a PromptFooter")
	_check(hud.visible, "HUD node stays present")
	_check(not hud.is_objective_visible(), "HUD chrome hidden during film")
	_check(not hud.is_health_bar_visible(), "health bar hidden during film")
	_check(player.is_input_override_active(), "player movement override on")
	_check(level.get_music().is_playing(), "level music continues")
	_check(get_viewport().get_camera_2d() == opening.get_opening_camera(),
		"authored OpeningCamera is current")
	_check(opening.get_shake_amplitude() <= 2.0,
		"earthquake shake is <= 2 px", str(opening.get_shake_amplitude()))

	var start_x: float = player.global_position.x
	var start_y: float = player.global_position.y
	var toggles: int = player.get_polarity_toggle_count()
	var hp: int = hud.get_player_health_bar().get_current()
	Input.action_press(&"move_right")
	_push_key(KEY_Q, true)
	Input.action_press(&"jump")
	await _wait_physics(8)
	_push_key(KEY_Q, false)
	Input.action_release(&"jump")
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check(absf(player.global_position.x - start_x) < 0.75,
		"movement locked during film", str(player.global_position.x - start_x))
	_check(absf(player.global_position.y - start_y) < 0.75,
		"jump locked during film", str(player.global_position.y - start_y))
	_check(player.get_polarity_toggle_count() == toggles,
		"polarity locked during film")
	_check(hud.get_player_health_bar().get_current() == hp,
		"no damage during film")

	await _test_doubt_performance(opening, player)

	# The echo must introduce herself by the project's existing display name on
	# the first page: the bubble title and the body both carry it.
	var echo: GuideEcho = opening.get_dialogue_echo()
	var first_page_seen: bool = await _wait_for_first_page(opening, echo, 15000)
	_check(first_page_seen, "first echo page opens")
	if first_page_seen:
		_check(echo.get_speaker_text() == "守望者残响",
			"echo bubble title is 守望者残响", echo.get_speaker_text())
		_check(echo.get_full_page_text().contains("守望者残响"),
			"first echo page names 守望者残响 in its body",
			echo.get_full_page_text())
		_check(echo.get_full_page_text().begins_with("别怕。"),
			"first echo page starts with 别怕。",
			echo.get_full_page_text())
		_check(opening.is_echo_visible() and echo.get_manifestation() > 0.0,
			"echo projection is visible on page 1",
			str(opening.get_echo_alpha()))
		_check(opening.get_camera_zoom() >= 1.6 and opening.get_camera_zoom() <= 1.8,
			"page camera zoom is 1.6-1.8x", str(opening.get_camera_zoom()))
		_check(opening.is_letterbox_visible()
			and absf(opening.get_letterbox_height() - 44.0) < 0.1,
			"page letterbox is 44 px", str(opening.get_letterbox_height()))

	await _wait_pages_and_finish(opening, echo)
	_check(not level.is_intro_active(), "natural film ends")
	_check(not opening.is_active(), "controller is idle after natural finish")
	_check(not opening.is_skipped(), "natural finish is not marked skipped")
	_check(opening.get_core_handoff_count() == 1, "first star core was handed over")
	_check(opening.has_touched_stele(), "real stele was touched")
	_check(not opening.is_echo_visible(), "echo projection hidden after the film")
	_check(absf(opening.get_echo_alpha()) < 0.01, "echo alpha cleared after the film")
	_check(absf(opening.get_camera_zoom() - 1.0) < 0.001,
		"opening camera zoom returns to 1.0", str(opening.get_camera_zoom()))
	_check(absf(level.get_camera().zoom.x - 1.0) < 0.001,
		"gameplay camera zoom is 1.0")
	_check(not opening.is_letterbox_visible(), "letterbox hidden after the film")
	_check(absf(opening.get_letterbox_height()) < 0.1,
		"letterbox height is 0 after the film", str(opening.get_letterbox_height()))
	_check(opening.get_cue_count() >= 7, "opening cue bank fired",
		str(opening.get_cue_count()))
	_check(hud.is_objective_visible(), "HUD chrome appears after film")
	_check(hud.is_health_bar_visible(), "health bar appears after film")
	_check(get_viewport().get_camera_2d() == level.get_camera(),
		"player camera is current after film")
	_check(not player.is_input_override_active(), "player override released")
	_check(level.get_music().is_playing(), "music still playing after film")
	_check(player.global_position.x > 240.0 and player.global_position.x < 340.0,
		"player handed off beside the stele", str(player.global_position.x))

	var resumed_x: float = player.global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(10)
	Input.action_release(&"move_right")
	_check(player.global_position.x > resumed_x + 1.0,
		"gameplay control resumes after film")

	# Failure recovery is in place and must not replay the film.
	player.global_position = Vector2(player.global_position.x, 500.0)
	await _wait_physics(6)
	await _wait_process(4)
	_check(not level.is_intro_active(), "failure recovery did not replay film")
	_check(opening.get_play_count() == 1, "failure recovery kept play count 1")

	# R restarts the level without a second film.
	Input.action_press(&"reset")
	await _wait_process(2)
	Input.action_release(&"reset")
	await _wait_process(8)
	_check(not level.is_intro_active(), "R did not start a second film")
	_check(opening.get_play_count() == 1, "R kept the film play count at 1")
	_check(level.get_intro_start_count() == 1, "R kept intro start count at 1")
	_check(not opening.is_active(), "old film stays idle after R")
	_check(hud.is_objective_visible(), "R leaves HUD on the gameplay path")
	_check(not player.is_input_override_active(), "R leaves player control on")

	level.queue_free()
	await _wait_process(8)


func _test_f_skip() -> void:
	print("=== L1 OPENING F SKIP ===")
	var level: Level01 = await _spawn()
	var opening: OpeningCinematic = level.get_opening()
	var player: PrototypePlayer = level.get_player()
	var hud: Level01HUD = level.get_hud()
	_check(opening != null and opening.is_playing(), "F skip: film started")
	if opening == null or player == null:
		level.queue_free()
		await get_tree().process_frame
		return
	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_process(6)
	_check(not level.is_intro_active(), "F skips the whole film immediately")
	_check(opening.is_skipped(), "F marks the film skipped")
	_check(not opening.is_ui_visible(), "F leaves no cinematic UI")
	_check(not opening.is_prompt_footer_visible(), "F leaves no footer")
	_check(not opening.is_skip_bar_visible(), "F leaves no hold bar")
	_check(hud.is_objective_visible(), "F shows the HUD")
	_check(get_viewport().get_camera_2d() == level.get_camera(),
		"F returns the player camera")
	_check(not player.is_input_override_active(), "F releases the player lock")
	_check(player.global_position.x > 240.0 and player.global_position.x < 340.0,
		"F snaps to the stele hand-off", str(player.global_position.x))
	_check(level.get_music().is_playing(), "F did not stop the music")

	var start_x: float = player.global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(8)
	Input.action_release(&"move_right")
	_check(player.global_position.x > start_x + 1.0, "F skip resumes control")

	level.queue_free()
	await _wait_process(8)


func _test_space_skip() -> void:
	print("=== L1 OPENING HOLD-SPACE SKIP ===")
	var level: Level01 = await _spawn()
	var opening: OpeningCinematic = level.get_opening()
	var player: PrototypePlayer = level.get_player()
	_check(opening != null and opening.is_playing(), "space skip: film started")
	if opening == null or player == null:
		level.queue_free()
		await get_tree().process_frame
		return
	_push_key(KEY_SPACE, true)
	await get_tree().create_timer(0.35).timeout
	_check(opening.is_skip_bar_visible(), "space skip: hold bar visible")
	await get_tree().create_timer(0.40).timeout
	_check(opening.get_space_hold_time() >= OpeningCinematic.SKIP_HOLD,
		"space skip: hold threshold reached", str(opening.get_space_hold_time()))
	_check(opening.is_skipped(), "space skip: long hold skips")
	_check(opening.is_awaiting_release(), "space skip: waits for the same key release")
	_check(player.is_input_override_active(), "space skip: lock held until release")
	_check(not opening.is_ui_visible(), "space skip: cinematic UI already gone")
	_push_key(KEY_SPACE, false)
	await _wait_process(4)
	_check(not level.is_intro_active(), "space skip: release hands control back")
	_check(not player.is_input_override_active(), "space skip: lock released")
	_check(not opening.is_awaiting_release(), "space skip: await-release cleared")
	_check(player.global_position.x > 240.0 and player.global_position.x < 340.0,
		"space skip: snapped to the stele", str(player.global_position.x))

	level.queue_free()
	await _wait_process(8)


func _test_r_during_film() -> void:
	print("=== L1 OPENING R DURING FILM ===")
	var level: Level01 = await _spawn()
	var opening: OpeningCinematic = level.get_opening()
	_check(opening != null and opening.is_playing(), "R during film: film started")
	if opening == null:
		level.queue_free()
		await get_tree().process_frame
		return
	Input.action_press(&"reset")
	await _wait_process(2)
	Input.action_release(&"reset")
	await _wait_process(8)
	_check(not level.is_intro_active(), "R during film aborts the film")
	_check(not opening.is_active(), "R during film leaves no active controller")
	_check(opening.get_play_count() == 1, "R during film does not start a second film")
	_check(level.get_intro_start_count() == 1, "R during film keeps intro count at 1")
	_check(level.get_hud().is_objective_visible(), "R during film leaves HUD on")
	_check(get_viewport().get_camera_2d() == level.get_camera(),
		"R during film returns the player camera")
	_check(not level.get_player().is_input_override_active(),
		"R during film returns player control")
	level.queue_free()
	await _wait_process(8)


func _test_doubt_performance(opening: OpeningCinematic, player: PrototypePlayer) -> void:
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and opening.get_elapsed() < OpeningCinematic.TOUCH_TIME:
		await get_tree().process_frame
	_check(opening.has_touched_stele(), "doubt: stele touched before the performance")
	var start_x: float = player.global_position.x
	var start_y: float = player.global_position.y
	var peak: float = 0.0
	var saw_question: bool = false
	var saw_question_before_form: bool = false
	var locked_during: bool = false
	var until: float = OpeningCinematic.DOUBT_RETURN_END + 0.15
	while opening.get_elapsed() < until and opening.is_active():
		peak = maxf(peak, absf(player.global_position.x - start_x))
		if opening.is_question_visible():
			saw_question = true
			if opening.get_elapsed() < OpeningCinematic.ECHO_FORM_END:
				saw_question_before_form = true
		if player.is_input_override_active():
			locked_during = true
		await get_tree().process_frame
	var end_offset: float = player.global_position.x - start_x
	_check(peak >= 3.0 and peak <= 10.0,
		"doubt: half-step stays within 0-10 px", str(peak))
	_check(absf(end_offset) <= 1.0,
		"doubt: player returns to the original x", str(end_offset))
	_check(absf(player.global_position.y - start_y) < 0.75,
		"doubt: step-back did not change the landing", str(player.global_position.y - start_y))
	_check(saw_question, "doubt: question emote appeared")
	_check(saw_question_before_form, "doubt: question appears before the echo forms")
	_check(not opening.is_question_visible(), "doubt: question emote is hidden after the beat")
	_check(locked_during, "doubt: input stayed locked through the performance")
	_check(opening.get_doubt_peak_offset() >= 3.0
		and opening.get_doubt_peak_offset() <= 10.0,
		"doubt: controller peak is also within 0-10 px",
		str(opening.get_doubt_peak_offset()))
	_check(opening.get_camera_zoom() >= 1.6 and opening.get_camera_zoom() <= 1.8,
		"doubt: camera is zoomed into 1.6-1.8x", str(opening.get_camera_zoom()))
	_check(opening.is_letterbox_visible()
		and absf(opening.get_letterbox_height() - 44.0) < 0.1,
		"doubt: 44 px letterbox is visible", str(opening.get_letterbox_height()))


func _wait_for_first_page(
	opening: OpeningCinematic, echo: GuideEcho, timeout_ms: int
) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if not opening.is_active():
			return false
		if echo != null and echo.is_dialogue_open() and echo.get_page_index() == 0:
			return true
		await get_tree().process_frame
	return false


func _wait_pages_and_finish(opening: OpeningCinematic, echo: GuideEcho) -> void:
	# Wait on real elapsed time so the 20.4 s film reaches its natural end
	# independently of the headless frame rate. Every page must show the
	# translucent projection, the 1.6-1.8x camera and the 44 px letterbox.
	var pages_seen: Array[int] = []
	var deadline: int = Time.get_ticks_msec() + 40000
	while opening.is_active() and Time.get_ticks_msec() < deadline:
		var index: int = echo.get_page_index()
		if index >= 0 and not pages_seen.has(index):
			pages_seen.append(index)
			_check(opening.is_echo_visible() and echo.get_manifestation() > 0.0,
				"echo projection visible on page %d" % (index + 1),
				str(opening.get_echo_alpha()))
			_check(opening.get_camera_zoom() >= 1.6
				and opening.get_camera_zoom() <= 1.8,
				"page %d camera zoom 1.6-1.8x" % (index + 1),
				str(opening.get_camera_zoom()))
			_check(opening.is_letterbox_visible()
				and absf(opening.get_letterbox_height() - 44.0) < 0.1,
				"page %d letterbox is 44 px" % (index + 1),
				str(opening.get_letterbox_height()))
		await get_tree().process_frame
	_check(pages_seen.size() == 3, "all three echo pages were seen", str(pages_seen))


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _cleanup() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"jump")
	Input.action_release(&"polarity")
	Input.action_release(&"reset")
	Input.action_release(&"tutorial_next")
	get_tree().paused = false
	await _wait_process(20)
