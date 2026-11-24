extends Node

## 2026-11-19 hold-to-skip screen-feedback acceptance harness.
##
## Run (assertions only, headless):
##   Godot --headless --path . \
##     res://tests/skip_progress_20261119/test_skip_progress_20261119.tscn
##
## Run (also saves 640x360 PNGs of the charging bar):
##   Godot --path . \
##     res://tests/skip_progress_20261119/test_skip_progress_20261119.tscn -- --capture
##
## Scope: the L1 opening and L3 cinematic bars only. Both films start through
## their real level entry paths; only the L1 title menu is disabled, as in the
## earlier 2026-11-19 harness. Space is injected as real InputEventKey events.
##
## Checks:
##   - the 96x6 bar sits at (528, 336), the 12 px "跳过" label is to its left,
##     the border/background/fill follow the approved pause-panel colors;
##   - a short Space tap never shows it;
##   - during a hold, progress only rises and fill width = round(94 * progress);
##   - ~0.2 / 0.4 / 0.6 progress is captured (windowed --capture run);
##   - release hides it, a completed skip hides it, and the finished film
##     leaves no visible bar behind;
##   - the real skip end, await-release boundary and hand-off still work.

const LEVEL1_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL3_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const SHOT_DIR: String = "res://tests/skip_progress_20261119/"
const INNER_WIDTH: float = 94.0

var _passes: int = 0
var _fails: Array[String] = []
var _capture: bool = false
var _shot_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture = DisplayServer.get_name() != "headless" \
		and OS.get_cmdline_user_args().has("--capture")
	print("SKIP_PROGRESS capture=%s display=%s" % [str(_capture), DisplayServer.get_name()])
	await get_tree().process_frame
	await _run_level1()
	await _run_level3()
	print("SKIP_PROGRESS_RESULT pass=%d fail=%d shots=%d" % [_passes, _fails.size(), _shot_count])
	for failure: String in _fails:
		print("FAIL: ", failure)
	if _fails.is_empty():
		print("SKIP_PROGRESS_OK")
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- helpers ---------------------------------------------------------------

func _check(ok: bool, label: String) -> bool:
	if ok:
		_passes += 1
		print("  PASS ", label)
	else:
		_fails.append(label)
		print("  FAIL ", label)
	return ok


func _wait_process(seconds: float) -> void:
	var frames: int = maxi(int(ceil(seconds * 60.0)), 1)
	for _i: int in range(frames):
		await get_tree().process_frame


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return bool(predicate.call())


func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _press(code: Key) -> void:
	Input.parse_input_event(_key_event(code, true))
	Input.flush_buffered_events()


func _release(code: Key) -> void:
	Input.parse_input_event(_key_event(code, false))
	Input.flush_buffered_events()


func _snapshot(file_name: String) -> void:
	if not _capture:
		return
	# Freeze the pausable film on the exact sampled frame, draw it, save the
	# 640x360 root viewport, then resume the same hold.
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(SHOT_DIR + file_name)
	var error: int = image.save_png(path)
	_shot_count += 1
	print("SHOT %s size=%dx%d error=%d" % [path, image.get_width(), image.get_height(), error])
	_check(image.get_width() == 640 and image.get_height() == 360,
		"%s is 640x360" % file_name)
	_check(error == OK, "%s saved" % file_name)
	get_tree().paused = false
	await get_tree().process_frame


# --- shared bar checks -----------------------------------------------------

func _check_bar_contract(cine, prefix: String) -> void:
	var rect: Rect2 = cine.get_skip_bar_rect()
	_check(rect.position.is_equal_approx(Vector2(528.0, 336.0)),
		"%s bar at (528, 336)" % prefix)
	_check(rect.size.is_equal_approx(Vector2(96.0, 6.0)),
		"%s bar is 96x6" % prefix)
	var label_rect: Rect2 = cine.get_skip_bar_label_rect()
	_check(cine.get_skip_bar_label_text() == "跳过", "%s label text is 跳过" % prefix)
	_check(cine.get_skip_bar_label_font_size() == 12, "%s label font is 12" % prefix)
	_check(label_rect.end.x <= -4.0,
		"%s label sits left of the bar with a gap" % prefix)
	var label_center_y: float = label_rect.position.y + label_rect.size.y * 0.5
	_check(label_center_y >= 0.0 and label_center_y <= rect.size.y,
		"%s label is vertically centred on the bar" % prefix)
	var style: StyleBoxFlat = cine.get_skip_bar_style()
	_check(style != null, "%s bar style exists" % prefix)
	if style != null:
		_check(style.border_width_left == 1 and style.border_width_top == 1
			and style.border_width_right == 1 and style.border_width_bottom == 1,
			"%s bar has a 1 px border" % prefix)
		_check(not style.anti_aliasing, "%s bar anti_aliasing=false" % prefix)
		_check(style.corner_radius_top_left == 0 and style.corner_radius_top_right == 0
			and style.corner_radius_bottom_left == 0 and style.corner_radius_bottom_right == 0,
			"%s bar has no corner radius" % prefix)
		_check(style.border_color.is_equal_approx(Color("#739e9f")),
			"%s bar border is #739e9f" % prefix)
		_check(style.bg_color.a >= 0.9, "%s bar has a near-opaque dark track" % prefix)
	var fill: ColorRect = cine.get_node_or_null(
		"OpeningCinematicUI/OpeningCinematicRoot/SkipHoldBar/Track/Fill"
	) as ColorRect
	if fill == null:
		fill = cine.get_node_or_null("CineUI/CineRoot/SkipHoldBar/Track/Fill") as ColorRect
	_check(fill != null and fill.color.is_equal_approx(Color("#f4cd63")),
		"%s bar fill is #f4cd63" % prefix)


func _check_hidden(cine, label: String) -> void:
	_check(not cine.is_skip_bar_visible(), label)


# --- per-film exercise -----------------------------------------------------

func _exercise(cine, prefix: String) -> void:
	_check_bar_contract(cine, prefix)
	_check_hidden(cine, "%s bar hidden before any Space press" % prefix)
	await _wait_process(0.05)

	# Short tap (3 frames, about 0.05 s): must never appear.
	_press(KEY_SPACE)
	await get_tree().process_frame
	_check_hidden(cine, "%s bar hidden on short-tap press frame" % prefix)
	await _wait_process(0.05)
	_check_hidden(cine, "%s bar still hidden after a short tap" % prefix)
	_release(KEY_SPACE)
	await _wait_process(0.03)
	_check_hidden(cine, "%s bar hidden after short-tap release" % prefix)

	# A real charge: sample the bar at ~0.2 / 0.4 / 0.6 progress.
	_press(KEY_SPACE)
	var targets: Array[float] = [0.2, 0.4, 0.6]
	var target_index: int = 0
	var previous_progress: float = -1.0
	var previous_width: float = -1.0
	var monotonic: bool = true
	var width_matches: bool = true
	var started: int = Time.get_ticks_msec()
	while target_index < targets.size() and Time.get_ticks_msec() - started < 5000:
		await get_tree().process_frame
		if not cine.is_skip_bar_visible():
			continue
		var progress: float = cine.get_skip_bar_progress()
		var width: float = cine.get_skip_bar_fill_width()
		if progress + 0.0001 < previous_progress:
			monotonic = false
		if absf(width - roundf(INNER_WIDTH * progress)) > 0.01:
			width_matches = false
		previous_progress = progress
		previous_width = width
		if progress >= targets[target_index]:
			print("HOLD_SAMPLE %s target=%.1f progress=%.4f width=%.1f" % [
				prefix, targets[target_index], progress, width
			])
			await _snapshot("%s_hold_%03d.png" % [prefix, int(round(targets[target_index] * 100.0))])
			target_index += 1
	_check(target_index == targets.size(), "%s reached 0.2/0.4/0.6 progress" % prefix)
	_check(monotonic, "%s progress only increased during the hold" % prefix)
	_check(width_matches, "%s fill width tracks progress (round(94*p))" % prefix)
	_check(previous_width > 0.0 and previous_width <= INNER_WIDTH,
		"%s fill width stayed inside the track" % prefix)
	_release(KEY_SPACE)
	await _wait_process(0.05)
	_check_hidden(cine, "%s bar hidden after releasing the charge" % prefix)

	# Hold to the real skip end: the bar must disappear immediately and the
	# await-release boundary must still exist.
	_press(KEY_SPACE)
	var skipped: bool = await _wait_until(
		func() -> bool: return bool(cine.get("_skipped")), 2.0
	)
	_check(skipped, "%s long Space still skipped the segment" % prefix)
	_check_hidden(cine, "%s bar hidden once the skip is committed" % prefix)
	var boundary: bool = await _wait_until(
		func() -> bool: return cine.is_awaiting_release() or not cine.is_active(), 2.0
	)
	_check(boundary, "%s skip still reaches the hand-off boundary" % prefix)
	_check(cine.is_awaiting_release(), "%s held Space still owns control until release" % prefix)
	_check_hidden(cine, "%s bar hidden during await-release" % prefix)
	await _snapshot("%s_after_skip_hidden.png" % prefix)

	_release(KEY_SPACE)
	await _wait_process(0.12)
	_check(not cine.is_active(), "%s control returned after Space release" % prefix)
	_check_hidden(cine, "%s bar has no residue after hand-off" % prefix)
	_check(not cine.is_ui_visible(), "%s cinematic UI layer is gone" % prefix)


# --- L1 opening ------------------------------------------------------------

func _run_level1() -> void:
	print("== L1 opening hold-to-skip bar ==")
	var level: Level01 = LEVEL1_SCENE.instantiate() as Level01
	level.enable_start_menu = false
	add_child(level)
	await _wait_process(0.25)
	var opening: OpeningCinematic = level.get_opening()
	var echo: GuideEcho = level.get_narrative_guide()
	var player: PrototypePlayer = level.get_player()
	if not _check(opening != null and echo != null and player != null,
			"L1 opening/echo/player exist"):
		level.queue_free()
		return

	var reached: bool = await _wait_until(
		func() -> bool: return opening.get_phase_name() == "DIALOGUE", 20.0
	)
	if not _check(reached, "L1 opening reached DIALOGUE"):
		level.queue_free()
		return
	await _wait_until(func() -> bool: return echo.is_dialogue_open(), 3.0)
	await _wait_process(0.10)
	_check(opening.is_playing(), "L1 opening is still playing at DIALOGUE")

	await _exercise(opening, "l1_opening")

	var y_before: float = player.global_position.y
	await _wait_process(0.20)
	_check(player.velocity.y >= -1.0 and absf(player.global_position.y - y_before) < 1.0,
		"L1 no jump from the skip Space after hand-off")

	level.queue_free()
	await _wait_process(0.10)


# --- L3 cinematic ----------------------------------------------------------

func _run_level3() -> void:
	print("== L3 cinematic hold-to-skip bar ==")
	var level: Level03 = LEVEL3_SCENE.instantiate() as Level03
	add_child(level)
	await _wait_process(0.35)
	var cine: L3Cinematic = level.get_cine()
	var player: L3Player = level.get_player()
	if not _check(cine != null and player != null, "L3 cinematic/player exist"):
		level.queue_free()
		return
	level.call("_start_cinematic")
	await _wait_process(0.10)
	if not _check(cine.is_playing(), "L3 cinematic started through the level entry"):
		level.queue_free()
		return

	var reached: bool = await _wait_until(
		func() -> bool: return cine.get_phase_name() == "DIALOGUE", 20.0
	)
	if not _check(reached, "L3 cinematic reached DIALOGUE"):
		level.queue_free()
		return
	await _wait_until(
		func() -> bool: return cine.is_bubble_visible() and cine.get_page_index() == 0, 3.0
	)
	await _wait_process(0.10)
	_check(cine.is_active(), "L3 cinematic is still active at DIALOGUE")

	await _exercise(cine, "l3_cinematic")

	var y_before: float = player.global_position.y
	await _wait_process(0.20)
	_check(player.velocity.y >= -1.0 and absf(player.global_position.y - y_before) < 1.0,
		"L3 no jump from the skip Space after hand-off")

	level.queue_free()
	await _wait_process(0.10)
