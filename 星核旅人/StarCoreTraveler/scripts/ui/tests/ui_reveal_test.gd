extends Node

## Minimal acceptance test for the shared UiReveal on the base pause page and
## mechanic popup.  Run headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://scripts/ui/tests/ui_reveal_test.tscn
##
## It checks the real UI state (open/paused/focus) on the same frame as the
## command, then checks the visual tween finishes correctly while the tree is
## paused, and that close never delays unpausing.

const POPUP_SCENE: PackedScene = preload("res://scenes/ui/mechanic_popup.tscn")
const PAUSE_MENU_SCRIPT = preload("res://scripts/ui/pause_menu.gd")

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _test_spec()
	await _test_mechanic_popup()
	await _test_pause_menu()
	print("UI_REVEAL_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _near(value: float, expected: float, tolerance: float = 0.001) -> bool:
	return absf(value - expected) <= tolerance


## A standalone Q/J/E/F (not the E of "Esc") is banned outside key rows.
func _has_bare_key_letter(text: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("(^|[^A-Za-z])[QJEF]([^A-Za-z]|$)")
	return regex.search(text) != null


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _push_key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	get_viewport().push_input(event)


func _press_key(code: Key) -> void:
	_push_key(code, true)
	_push_key(code, false)


func _test_spec() -> void:
	print("=== UI REVEAL SPEC ===")
	_check(UiReveal.OPEN_DURATION >= 0.16 and UiReveal.OPEN_DURATION <= 0.20,
		"open duration is 0.16-0.20 s", "%.2f" % UiReveal.OPEN_DURATION)
	_check(UiReveal.CLOSE_DURATION >= 0.10 and UiReveal.CLOSE_DURATION <= 0.14,
		"close duration is 0.10-0.14 s", "%.2f" % UiReveal.CLOSE_DURATION)
	_check(UiReveal.SLIDE_IN_PX >= 4.0 and UiReveal.SLIDE_IN_PX <= 6.0,
		"slide-in is 4-6 px", "%.1f" % UiReveal.SLIDE_IN_PX)
	_check(_near(UiReveal.PANEL_SCALE_FROM, 1.0),
		"panel keeps 1.0 scale so text is not resampled", "%.2f" % UiReveal.PANEL_SCALE_FROM)


func _test_mechanic_popup() -> void:
	print("=== MECHANIC POPUP ===")
	var popup: MechanicPopup = POPUP_SCENE.instantiate() as MechanicPopup
	add_child(popup)
	await _wait_process(2)
	_check(not popup.is_open(), "popup starts closed")
	var reveal: UiReveal = popup.get_reveal()
	_check(reveal != null, "popup has the shared UiReveal")
	if reveal == null:
		popup.queue_free()
		return
	_check(not reveal.is_root_visible(), "popup root starts hidden")

	_check(popup.open_for_test("guard_field"), "popup opens for test")
	_check(popup.is_open(), "popup state is open immediately")
	_check(get_tree().paused, "popup pauses the tree immediately")
	_check(reveal.is_open_animating(), "popup open tween is running")
	_check(reveal.get_shade_alpha() < 0.05,
		"shade starts near 0", "%.3f" % reveal.get_shade_alpha())
	_check(_near(reveal.get_panel_scale(), 1.0),
		"panel does not scale while opening", "%.3f" % reveal.get_panel_scale())
	_check(reveal.get_panel_offset_y() >= 4.0 and reveal.get_panel_offset_y() <= 6.0,
		"panel starts 4-6 px low", "%.2f" % reveal.get_panel_offset_y())

	# The tree is paused here; TWEEN_PAUSE_PROCESS must still finish the reveal.
	await _wait_seconds(0.22)
	_check(not reveal.is_animating(), "popup open tween ends while tree is paused")
	_check(_near(reveal.get_shade_alpha(), 1.0), "shade settles at 1",
		"%.3f" % reveal.get_shade_alpha())
	_check(_near(reveal.get_panel_scale(), 1.0), "panel settles at 1x",
		"%.3f" % reveal.get_panel_scale())
	_check(_near(reveal.get_panel_offset_y(), 0.0), "panel settles at its base position",
		"%.2f" % reveal.get_panel_offset_y())
	_check(popup.get_page_index() == 0, "popup page index is unchanged")
	_check(not _has_bare_key_letter(popup.get_body_text()),
		"popup page 1 body has no bare Q/J/E/F", popup.get_body_text())
	_check(popup.get_footer_rich_text().contains("[img=16x16]"),
		"popup footer renders the F keycap", popup.get_footer_rich_text())

	# F is real input and must still work normally after the reveal.
	_press_key(KEY_F)
	await _wait_process(2)
	_check(popup.is_open() and popup.get_page_index() == 1,
		"F advances the two-page tip", "page=%d" % popup.get_page_index())
	_check(not _has_bare_key_letter(popup.get_body_text()),
		"popup page 2 body has no bare Q/J/E/F", popup.get_body_text())
	_check(popup.get_key_rich_text().contains("[img=16x16]"),
		"popup page 2 key row renders the J keycap", popup.get_key_rich_text())
	_press_key(KEY_F)
	_check(not popup.is_open(), "F on the last page closes the popup")
	_check(not get_tree().paused, "popup close unpauses immediately")
	_check(reveal.is_close_animating(), "popup close tween is running")
	_check(reveal.is_root_visible(), "popup stays visible only for the exit fade")
	await _wait_seconds(0.16)
	_check(not reveal.is_root_visible(), "popup root is hidden after the exit fade")
	_check(not reveal.is_animating(), "popup close tween ends")
	_check(_near(reveal.get_panel_scale(), UiReveal.PANEL_SCALE_FROM),
		"popup resets to closed scale", "%.3f" % reveal.get_panel_scale())

	# Reopen and close directly: state is still immediate, and the second open
	# starts cleanly after a finished exit.
	_check(popup.open_for_test("polarity"), "popup reopens after closing")
	_check(get_tree().paused, "popup second open pauses immediately")
	await _wait_seconds(0.22)
	_check(_near(reveal.get_panel_scale(), 1.0), "popup second open settles at 1x",
		"%.3f" % reveal.get_panel_scale())
	_check(not _has_bare_key_letter(popup.get_body_text()),
		"polarity body has no bare Q/J/E/F", popup.get_body_text())
	_check(popup.get_key_rich_text().contains("[img=16x16]"),
		"polarity key row renders the Q keycap", popup.get_key_rich_text())
	popup.close()
	_check(not popup.is_open() and not get_tree().paused,
		"direct popup close is state-immediate")
	await _wait_seconds(0.16)
	_check(not reveal.is_root_visible() and not reveal.is_animating(),
		"direct popup close finishes hidden")

	popup.queue_free()
	await _wait_process(2)


func _test_pause_menu() -> void:
	print("=== PAUSE MENU ===")
	var pause = PAUSE_MENU_SCRIPT.new()
	pause.name = "PauseMenuRevealTest"
	# Keep the test from rewriting the real user settings files.
	pause.audio_settings_path = "user://ui_reveal_test_audio.cfg"
	pause.display_settings_path = "user://ui_reveal_test_display.cfg"
	add_child(pause)
	await _wait_process(3)
	_check(not pause.is_open(), "pause menu starts closed")
	var reveal: UiReveal = pause.get_reveal()
	_check(reveal != null, "pause menu has the shared UiReveal")
	if reveal == null:
		pause.queue_free()
		return

	pause.open_pause()
	_check(pause.is_open(), "pause state is open immediately")
	_check(get_tree().paused, "pause pauses the tree immediately")
	_check(pause.is_pause_root_visible(), "pause root is visible immediately")
	_check(reveal.is_open_animating(), "pause open tween is running")
	_check(reveal.get_shade_alpha() < 0.05,
		"pause shade starts near 0", "%.3f" % reveal.get_shade_alpha())
	_check(_near(reveal.get_panel_scale(), 1.0),
		"pause panel does not scale while opening", "%.3f" % reveal.get_panel_scale())
	_check(reveal.get_panel_offset_y() >= 4.0 and reveal.get_panel_offset_y() <= 6.0,
		"pause panel starts 4-6 px low", "%.2f" % reveal.get_panel_offset_y())
	await _wait_process(2)
	_check(get_viewport().gui_get_focus_owner() == pause.get_continue_button(),
		"continue button receives focus after opening")

	await _wait_seconds(0.22)
	_check(not reveal.is_animating(), "pause open tween ends while tree is paused")
	_check(_near(reveal.get_shade_alpha(), 1.0), "pause shade settles at 1")
	_check(_near(reveal.get_panel_scale(), 1.0), "pause panel settles at 1x")
	_check(get_viewport().gui_get_focus_owner() == pause.get_continue_button(),
		"focus is kept through the reveal tween")

	# Resume must not wait for the 0.12 s exit.
	pause.resume()
	_check(not pause.is_open(), "resume closes the pause state immediately")
	_check(not get_tree().paused, "resume unpauses the tree immediately")
	_check(reveal.is_close_animating(), "pause close tween is running")
	_check(reveal.is_root_visible(), "pause root stays only for the exit fade")
	await _wait_seconds(0.16)
	_check(not reveal.is_root_visible(), "pause root is hidden after the exit fade")
	_check(not reveal.is_animating(), "pause close tween ends")

	# Focus is restored on the next real open.
	pause.open_pause()
	await _wait_process(2)
	_check(pause.is_open() and get_tree().paused, "pause reopens normally")
	_check(get_viewport().gui_get_focus_owner() == pause.get_continue_button(),
		"continue focus is restored after resume/reopen")
	await _wait_seconds(0.22)

	# Settings is part of the same pause page; returning must re-reveal the
	# panel and put focus back on the settings row.
	pause.open_settings()
	_check(pause.is_settings_open(), "pause settings opens")
	_check(not pause.is_pause_root_visible(), "pause root hides for settings")
	_check(get_tree().paused, "settings keeps the tree paused")
	await _wait_process(2)
	pause.close_settings()
	_check(not pause.is_settings_open(), "pause settings closes")
	_check(pause.is_pause_root_visible(), "pause root returns immediately")
	_check(get_tree().paused, "returning from settings keeps the tree paused")
	await _wait_process(2)
	_check(get_viewport().gui_get_focus_owner() == pause.get_settings_button(),
		"settings focus returns to the settings row")
	await _wait_seconds(0.22)
	_check(not reveal.is_animating(), "return-from-settings reveal ends")

	pause.resume()
	await _wait_seconds(0.16)
	_check(not reveal.is_root_visible(), "pause closes after settings route")

	# Force close is used by restart/leave; it cancels the reveal instantly.
	pause.open_pause()
	_check(reveal.is_open_animating(), "pause open starts before force close")
	pause.force_close()
	_check(not pause.is_open() and not get_tree().paused,
		"force close restores state immediately")
	_check(not reveal.is_root_visible() and not reveal.is_animating(),
		"force close leaves no tween or visible root")

	pause.queue_free()
	await _wait_process(2)
	_check(not get_tree().paused, "tree is left unpaused")
