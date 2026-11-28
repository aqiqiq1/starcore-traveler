extends Node

## Contract checks for the reworked level-01 opening:
##   - it plays on the first new game with HUD hidden and input locked;
##   - movement / polarity / jump / damage cannot happen during the film;
##   - F continues (complete line -> next page -> last page ends), it never
##     skips the film; holding Space for 0.6 s still skips;
##   - opening-film HUD hints are discarded, never queued to hand-off;
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
	await _test_f_continue()
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

	# A mechanism line raised behind the film is dropped.  It must not sit in a
	# pending slot and pop when control returns.
	hud.show_toast("远处机关提示 · 不应排队", 1.6)
	await _wait_process(3)
	_check(not hud.is_toast_visible() and String(hud.get_toast_text()).is_empty(),
		"opening film discards HUD hints instead of queueing",
		String(hud.get_toast_text()))

	# The 0-1.95 s black hold must have no lit pixel at all.  Sampling through
	# 2.45 s is stricter: not even one ember may appear before the scene fade.
	var dust_seen_early: bool = opening.is_dust_visible()
	while opening.get_elapsed() < 2.45:
		if opening.is_dust_visible():
			dust_seen_early = true
		await get_tree().process_frame
	_check(not dust_seen_early, "opening pure black / pre-fade has no dust motes",
		"alpha=%.2f" % opening.get_dust_alpha())
	_check(opening.get_dust_alpha() < 0.001,
		"dust alpha is still zero before the 2.5 s scene fade",
		str(opening.get_dust_alpha()))
	while opening.get_elapsed() < 3.3:
		await get_tree().process_frame
	var dust_color: Color = opening.get_dust_color()
	_check(opening.is_dust_visible() and opening.get_dust_alpha() >= 0.99,
		"warm embers have fully faded in after 2.5 s", str(opening.get_dust_alpha()))
	_check(opening.get_dust_count() >= 18 and opening.get_dust_count() <= 24,
		"ember count is 18-24", str(opening.get_dust_count()))
	_check(opening.get_dust_size() == 3,
		"each ember is a 3x3 grain", str(opening.get_dust_size()))
	_check(dust_color.r > dust_color.g and dust_color.g > dust_color.b,
		"ember colour is warm (R>G>B)", str(dust_color))

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

	# 2026-11-28 staging: the player now enters from the left edge and walks
	# right toward the stele.  Sample the real driven player, not a pose.
	var stele: GuideEcho = level.get_narrative_stele()
	var stele_x: float = stele.global_position.x if stele != null else 250.0
	var entry_start_x: float = player.global_position.x
	_check(entry_start_x <= -8.0,
		"opening starts off-screen on the left", str(entry_start_x))
	_check(stele_x - entry_start_x >= 200.0,
		"start is at least 200 px left of the stele",
		"stele=%.1f start=%.1f" % [stele_x, entry_start_x])
	while opening.get_elapsed() < 5.05 and opening.is_active():
		await get_tree().process_frame
	var entry_x_a: float = player.global_position.x
	var entry_facing_ok: bool = true
	while opening.get_elapsed() < 5.75 and opening.is_active():
		if player.get_facing() != 1:
			entry_facing_ok = false
		await get_tree().process_frame
	var entry_x_b: float = player.global_position.x
	_check(entry_x_b > entry_x_a + 10.0,
		"player enters from the left moving right",
		"x %.1f -> %.1f" % [entry_x_a, entry_x_b])
	_check(entry_facing_ok,
		"player faces the stele while entering from the left",
		str(player.get_facing()))

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

	await _wait_pages_and_finish(level, opening, echo, player)
	await _wait_seconds(1.0)
	_check(not hud.is_toast_visible() and String(hud.get_toast_text()).is_empty(),
		"no distant hint appears in the first second after the film",
		String(hud.get_toast_text()))
	_check(not level.is_intro_active(), "natural film ends")
	_check(opening.get_end_transition_duration() >= 1.5
		and opening.get_end_transition_duration() <= 1.8,
		"end transition is 1.5-1.8 s", str(opening.get_end_transition_duration()))
	_check(opening.get_camera_return_duration() >= 1.0
		and opening.get_camera_return_duration() <= 1.2,
		"camera return is 1.0-1.2 s", str(opening.get_camera_return_duration()))
	_check(absf(opening.get_hud_fade_duration() - 0.25) < 0.001,
		"HUD fade is 0.25 s", str(opening.get_hud_fade_duration()))
	_check(opening.get_stand_duration() >= 0.249,
		"standing lock after HUD fade is >=0.25 s", str(opening.get_stand_duration()))
	_check(opening.get_black_alpha() < 0.01, "no black flash at hand-off",
		str(opening.get_black_alpha()))
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
	_check(player.global_position.x > 278.0 and player.global_position.x < 298.0,
		"player stops in front of the stele", str(player.global_position.x))
	_check(absf(player.global_position.x - stele_x) <= 48.0,
		"hand-off stays beside the stele", str(player.global_position.x - stele_x))

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


func _test_f_continue() -> void:
	print("=== L1 OPENING F CONTINUE ===")
	var level: Level01 = await _spawn()
	var opening: OpeningCinematic = level.get_opening()
	var player: PrototypePlayer = level.get_player()
	_check(opening != null and opening.is_playing(), "F continue: film started")
	if opening == null or player == null:
		level.queue_free()
		await get_tree().process_frame
		return

	# F during the prologue is inert; it is not a whole-film skip.
	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_process(6)
	_check(opening.is_active() and level.is_intro_active(),
		"F during the prologue does not skip the film")
	_check(not opening.is_skipped() and opening.get_skip_count() == 0,
		"F never marks the film skipped")

	var echo: GuideEcho = opening.get_dialogue_echo()
	var first_page: bool = await _wait_for_first_page(opening, echo, 15000)
	_check(first_page, "F continue: first page opened")
	if not first_page:
		opening.abort()
		level.queue_free()
		await _wait_process(8)
		return

	# First press on an unfinished line only completes that line.
	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_process(2)
	_check(echo.get_page_index() == 0,
		"F on a typing line completes it without turning the page",
		str(echo.get_page_index()))
	_check(echo.get_revealed_count() >= echo.get_full_page_text().length(),
		"the unfinished line is fully revealed")
	_check(opening.is_active(), "completing a line does not end the film")

	# Second press on the completed line turns exactly one page.
	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_process(3)
	_check(echo.get_page_index() == 1,
		"F on a completed line advances exactly one page",
		str(echo.get_page_index()))
	_check(opening.is_active() and level.is_intro_active(),
		"one page turn does not end the opening film")
	_check(not opening.is_skipped(), "page turn is not a skip")

	opening.abort()
	await _wait_process(6)
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
	_check(player.global_position.x > 278.0 and player.global_position.x < 298.0,
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


func _wait_pages_and_finish(
	level: Level01, opening: OpeningCinematic, echo: GuideEcho, player: PrototypePlayer
) -> void:
	# Wait on real elapsed time so the film reaches its natural end independently
	# of the headless frame rate. Every page must show the translucent projection,
	# the 1.6-1.8x camera and the 44 px letterbox. F is the only page control;
	# the first completed-page press must advance exactly one page and leave the
	# film running.
	var pages_seen: Array[int] = []
	var pressed_page: int = -1
	var hud_fade_checked: bool = false
	var input_probe_done: bool = false
	var probe_toggles: int = player.get_polarity_toggle_count()
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
		if (
			index >= 0
			and pressed_page != index
			and echo.is_dialogue_open()
			and echo.get_revealed_count() >= echo.get_full_page_text().length()
		):
			pressed_page = index
			_push_key(KEY_F, true)
			_push_key(KEY_F, false)
			await _wait_process(2)
			if index == 0:
				_check(echo.get_page_index() == 1,
					"one F advances exactly one page",
					str(echo.get_page_index()))
				_check(opening.is_active() and level.is_intro_active(),
					"one F does not end the opening film")
		if not hud_fade_checked and opening.get_elapsed() >= (
			OpeningCinematic.HUD_RETURN_TIME + 0.10
		):
			hud_fade_checked = true
			_check(level.is_intro_active(), "film still owns input during HUD fade")
			_check(player.is_input_override_active(),
				"player lock stays on during HUD fade")
			_check(absf(opening.get_camera_zoom() - 1.0) < 0.01,
				"camera is back at 1.0 before HUD fade",
				str(opening.get_camera_zoom()))
			_check(absf(opening.get_black_alpha()) < 0.01,
				"no black flash during the end transition",
				str(opening.get_black_alpha()))
			_check(absf(opening.get_letterbox_height()) < 0.1,
				"letterbox is gone before HUD fade",
				str(opening.get_letterbox_height()))
		if not input_probe_done and opening.get_elapsed() >= (
			OpeningCinematic.HANDOFF_TIME - 0.10
		):
			input_probe_done = true
			Input.action_press(&"jump")
			Input.action_press(&"polarity")
		await get_tree().process_frame
	_check(pages_seen.size() == 3, "all three echo pages were seen", str(pages_seen))
	_check(hud_fade_checked, "HUD-fade input lock was sampled")
	_check(input_probe_done, "late-film jump/polarity probe was sent")
	await _wait_physics(3)
	_check(player.get_polarity_toggle_count() == probe_toggles,
		"held polarity at hand-off did not toggle on the first frame")
	_check(player.get_state_name() != "jump",
		"held jump at hand-off did not start a jump", player.get_state_name())
	_check(absf(player.global_position.y - 300.0) < 0.75,
		"player stayed on the ground at hand-off", str(player.global_position.y))
	Input.action_release(&"jump")
	Input.action_release(&"polarity")


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
