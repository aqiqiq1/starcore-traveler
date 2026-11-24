extends Node

## 2026-11-19 popup presentation shots at the real 640x360 viewport.
##
## Run (windowed, NOT headless):
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://tests/mechanic_popup_20261119/capture_popup_shots.tscn
##
## Each shot is taken through the real per-level trigger, not by calling open()
## directly, except the final missing-asset degradation shot which uses the
## test-only override so the approved demo files stay untouched.

const LEVEL1_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LEVEL3_SCENE: PackedScene = preload("res://scenes/level_03.tscn")

const OUT_DIR: String = "res://tests/mechanic_popup_20261119"
const MISSING_DIR: String = "res://tests/mechanic_popup_20261119/missing_assets"
const EXPECTED_FRAMES: int = 24

var _fails: Array[String] = []
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	MechanicTips.reset_for_test()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MISSING_DIR))
	_log("viewport=%s window=%s" % [str(get_viewport().size), str(get_window().size)])

	await _shot_l1()
	await _shot_l2_core()
	await _shot_l2_relay()
	await _shot_l3_float()
	await _shot_l3_guard()

	_write_log()
	print("MECHANIC_POPUP_SHOTS_RESULT fail=%d" % _fails.size())
	for failure: String in _fails:
		print("SHOT FAIL: ", failure)
	if _fails.is_empty():
		print("MECHANIC_POPUP_SHOTS_OK")
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- L1 -------------------------------------------------------------------

func _shot_l1() -> void:
	var level: Level01 = LEVEL1_SCENE.instantiate() as Level01
	level.enable_start_menu = false
	add_child(level)
	await _wait(0.6)
	if level.get_opening() != null:
		level.get_opening().abort()
	await _wait(0.4)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(660.0, 300.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	level.get_camera().reset_smoothing()

	var popup: MechanicPopup = level.get_mechanic_popup()
	var opened: bool = await _wait_open(popup, 2.0)
	_check(opened, "L1 polarity trigger opened")
	await _snap_popup(popup, "popup_polarity.png", "polarity")
	_check(popup.get_footer_text() == "F 继续 · 长按空格 跳过", "single page footer stays F 继续")
	_press_key(KEY_SPACE)
	await _wait(0.28)
	_check(popup.is_skip_bar_visible(), "shared SkipHoldBar is visible during a hold")
	_check(popup.is_open(), "0.28 s hold keeps the popup open")
	var bar_image: Image = await _grab()
	bar_image.save_png("%s/popup_skip_hold.png" % OUT_DIR)
	_log("shot popup_skip_hold.png progress=%.2f" % popup.get_skip_progress())
	_release_key(KEY_SPACE)
	await _wait(0.12)
	_check(popup.is_open(), "released sub-0.5 hold does not close")
	await _close_popup(popup)

	# Missing-asset path with the real code path (no demo files in this dir).
	popup.demo_dir = MISSING_DIR
	var missing_opened: bool = popup.open_for_test("polarity")
	_check(missing_opened, "missing-demo popup opened")
	await _wait(0.06)
	_check(not popup.has_demo(), "missing-demo popup reports no demo")
	var image: Image = await _grab()
	image.save_png("%s/popup_missing_demo.png" % OUT_DIR)
	_log("shot popup_missing_demo.png has_demo=false")
	popup.close()
	popup.demo_dir = MechanicPopup.DEMO_DIR
	await _wait(0.1)

	await _free_level(level)


# --- L2 -------------------------------------------------------------------

func _shot_l2_core() -> void:
	var level: Level02 = LEVEL2_SCENE.instantiate() as Level02
	add_child(level)
	await _wait(0.6)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(100.0, 320.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	level.get_camera().reset_smoothing()

	var popup: MechanicPopup = level.get_mechanic_popup()
	var opened: bool = await _wait_open(popup, 2.0)
	_check(opened, "L2 core_carry trigger opened")
	await _snap_popup(popup, "popup_core_carry.png", "core_carry")
	await _close_popup(popup)
	await _free_level(level)


func _shot_l2_relay() -> void:
	var level: Level02 = LEVEL2_SCENE.instantiate() as Level02
	add_child(level)
	await _wait(0.6)
	level.debug_restore_stage(Level02.STABLE_RELAY, true)
	await _wait(0.4)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(400.0, 320.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	level.get_camera().reset_smoothing()
	# Let the debug-restore toast clear, then capture the real x=400 state for
	# the trigger map before the popup is allowed to open.
	await _wait(1.5)

	var popup: MechanicPopup = level.get_mechanic_popup()
	_check(not popup.is_open(), "L2 x=400 does not open the relay popup")
	_check(player.global_position.x < 420.0, "L2 trigger-map player is before x=420")
	var map_image: Image = await _grab()
	map_image.save_png("%s/relay_trigger_map_raw.png" % OUT_DIR)

	player.global_position = Vector2(420.0, 320.0)
	player.velocity = Vector2.ZERO
	level.get_camera().reset_smoothing()
	var opened: bool = await _wait_open(popup, 2.0)
	_check(opened, "L2 relay_link trigger opened at x=420")
	_check(player.global_position.x >= 420.0 and player.global_position.x < 464.0,
		"L2 popup opened before the x=464 ConductiveRoof")
	await _snap_popup(popup, "popup_relay_link.png", "relay_link")
	await _close_popup(popup)
	await _free_level(level)


# --- L3 -------------------------------------------------------------------

func _shot_l3_float() -> void:
	var level: Level03 = LEVEL3_SCENE.instantiate() as Level03
	add_child(level)
	await _wait(0.9)
	level.debug_restore_stage(Level03.STAGE_RUNE)
	await _wait(0.4)
	level.debug_place_player_at(Vector2(300.0, 140.0))

	var popup: MechanicPopup = level.get_mechanic_popup()
	var opened: bool = await _wait_open(popup, 2.0)
	_check(opened, "L3 float_platform trigger opened")
	await _snap_popup(popup, "popup_float_platform.png", "float_platform")
	await _close_popup(popup)
	await _free_level(level)


func _shot_l3_guard() -> void:
	var level: Level03 = LEVEL3_SCENE.instantiate() as Level03
	add_child(level)
	await _wait(0.9)
	level.debug_setup_pre_teaching(1900.0)
	await _wait(0.4)
	level.debug_place_player_at(Vector2(1900.0, 320.0))

	var popup: MechanicPopup = level.get_mechanic_popup()
	var started: bool = await _start_guard_cine(level)
	_check(started, "near-gate echo film started")
	await _wait(0.35)
	_check(level.get_cine().is_active(), "echo film active before the tip")
	_check(not popup.is_open(), "guard tip stays closed during the echo film")

	var opened: bool = await _skip_guard_cine(level, popup)
	_check(opened, "guard tip opens after the echo film")
	_check(level.is_guard_tip_ready(), "guard tip ready at hand-back")
	await _snap_guard_after_cine(level, popup)
	await _snap_popup(popup, "popup_guard_page1.png", "guard_field")
	_check(popup.get_page_indicator_text() == "1 / 2", "guard page 1 label")
	_check(popup.get_footer_text() == "F 下一页 · 长按空格 跳过", "guard page 1 footer")
	_check(popup.get_key_text() == "Q 换相性 · 被吸近 / 被弹开", "guard page 1 key line")
	await _tap_key(KEY_F)
	await _wait(0.30)
	_check(popup.is_open(), "F keeps the guard popup open")
	await _snap_page(popup, "popup_guard_page2.png", "guard_field", 1, "guard_valid")
	_check(popup.get_page_indicator_text() == "2 / 2", "guard page 2 label")
	_check(popup.get_footer_text() == "F 关闭 · 长按空格 跳过", "guard page 2 footer")
	await _tap_key(KEY_F)
	await _wait(0.15)
	_check(not popup.is_open(), "F on last guard page closes")
	await _free_level(level)


func _start_guard_cine(level: Level03) -> bool:
	var guard: L3Guard = level.get_guard()
	guard.debug_set_waiting_rubble()
	var waiting: bool = false
	var deadline: int = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline:
		if guard.is_waiting_teaching_rubble():
			waiting = true
			break
		await _wait(0.02)
	if not waiting:
		return false
	level.call("_start_cinematic")
	deadline = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		if level.get_cine().is_active():
			return true
		await _wait(0.02)
	return level.get_cine().is_active()


func _skip_guard_cine(_level: Level03, popup: MechanicPopup) -> bool:
	_press_key(KEY_SPACE)
	await _wait(0.7)
	_release_key(KEY_SPACE)
	return await _wait_open(popup, 2.5)


func _snap_guard_after_cine(level: Level03, popup: MechanicPopup) -> void:
	var image: Image = await _grab()
	image.save_png("%s/popup_guard_after_cine.png" % OUT_DIR)
	var guard: L3Guard = level.get_guard()
	var player: Node = level.get_player()
	var state_text: String = "\n".join([
		"state=echo dialogue just ended, guard teaching popup opened",
		"guard_tip_ready=%s" % str(level.is_guard_tip_ready()),
		"cine_has_played=%s" % str(level.get_cine().has_played()),
		"player_position=%s" % str(player.global_position),
		"stable_stage=%d (STAGE_ARENA=3)" % level.get_stable_stage(),
		"guard_state=%s" % guard.get_state_name(),
		"guard_action_elapsed=%.3f" % guard.get_action_elapsed(),
		"guard_enemy_slam_count=%d" % guard.get_enemy_slam_count(),
		"popup_page=%d/%d" % [popup.get_page_index() + 1, popup.get_page_count()],
		"player_input_handed_back=true",
	])
	var state_file: FileAccess = FileAccess.open(
		"%s/popup_guard_after_cine_state.txt" % OUT_DIR, FileAccess.WRITE
	)
	if state_file != null:
		state_file.store_string(state_text + "\n")
		state_file.close()
	_log("shot popup_guard_after_cine.png %s" % state_text.replace("\n", " | "))

func _snap_popup(popup: MechanicPopup, file_name: String, expected_id: String) -> void:
	if popup == null:
		_fails.append("%s: popup missing" % expected_id)
		return
	_check(popup.is_open(), "%s: popup open" % expected_id)
	_check(popup.get_current_id() == expected_id, "%s: current id" % expected_id)
	_check(popup.has_demo(), "%s: demo loaded" % expected_id)
	_check(popup.get_demo_frame_count() == EXPECTED_FRAMES,
		"%s: %d demo frames" % [expected_id, EXPECTED_FRAMES])
	_check(not popup.get_body_text().is_empty(), "%s: body text" % expected_id)
	await _wait(0.06)
	var image: Image = await _grab()
	image.save_png("%s/%s" % [OUT_DIR, file_name])
	_log("shot %s id=%s frame=%d demo=%s text=%s" % [
		file_name, popup.get_current_id(), popup.get_demo_frame(),
		str(popup.has_demo()), popup.get_title_text()
	])


func _snap_page(
	popup: MechanicPopup,
	file_name: String,
	expected_id: String,
	expected_page: int,
	expected_demo: String
) -> void:
	if popup == null:
		_fails.append("%s: popup missing" % expected_id)
		return
	_check(popup.is_open(), "%s page %d: popup open" % [expected_id, expected_page + 1])
	_check(popup.get_current_id() == expected_id, "%s page %d: current id" % [expected_id, expected_page + 1])
	_check(popup.get_page_index() == expected_page, "%s page %d: page index" % [expected_id, expected_page + 1])
	_check(popup.get_demo_id() == expected_demo, "%s page %d: demo id" % [expected_id, expected_page + 1])
	_check(popup.has_demo(), "%s page %d: demo loaded" % [expected_id, expected_page + 1])
	_check(popup.get_demo_frame_count() == EXPECTED_FRAMES,
		"%s page %d: %d demo frames" % [expected_id, expected_page + 1, EXPECTED_FRAMES])
	_check(not popup.get_body_text().is_empty(), "%s page %d: body text" % [expected_id, expected_page + 1])
	await _wait(0.06)
	var image: Image = await _grab()
	image.save_png("%s/%s" % [OUT_DIR, file_name])
	_log("shot %s page=%d id=%s frame=%d demo=%s text=%s" % [
		file_name, popup.get_page_index() + 1, popup.get_current_id(),
		popup.get_demo_frame(), str(popup.has_demo()), popup.get_title_text()
	])


func _press_key(code: Key) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()


func _release_key(code: Key) -> void:
	var release: InputEventKey = InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _tap_key(code: Key) -> void:
	_press_key(code)
	await _wait(0.05)
	_release_key(code)
	await _wait(0.05)


func _wait_open(popup: MechanicPopup, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if popup != null and popup.is_open():
			return true
		await get_tree().process_frame
	return popup != null and popup.is_open()


func _close_popup(popup: MechanicPopup) -> void:
	if popup == null:
		return
	popup.close()
	await _wait(0.15)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _free_level(level: Node) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false


func _wait(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(ceil(seconds * 1000.0))
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		_log("PASS %s" % label)
	else:
		_fails.append(label)
		_log("FAIL %s" % label)


func _log(line: String) -> void:
	_log_lines.append(line)
	print("SHOT ", line)


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("%s/shot_log.txt" % OUT_DIR, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_log_lines) + "\n")
	file.close()
