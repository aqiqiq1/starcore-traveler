extends Node

## 2026-11-19 mechanic teaching popup acceptance harness.
##
## Run:
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://tests/mechanic_popup_20261119/test_mechanic_popup_20261119.tscn
##
## Covered here:
##   - each real level trigger opens exactly once, in the real approach zone;
##   - F closes, a short Space tap does nothing, a 0.5 s Space hold closes with
##     the gold bar and leaves no jump behind;
##   - Esc is swallowed and never stacks the pause page;
##   - paused guard charge / core body / float-block countdown do not advance;
##   - R restart and level changes do not reset the run-scoped seen record;
##   - request queue and missing-demo degradation.
##
## Test-only setup: the existing level debug placement/restore entries, direct
## positioning, real key/Move events through Input.parse_input_event, and
## popup.open_for_test()/demo_dir for the freeze and missing-asset checks.
## Gameplay rules, collision, values and dialogue stay unmodified.

const LEVEL1_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LEVEL3_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const POPUP_SCENE: PackedScene = preload("res://scenes/ui/mechanic_popup.tscn")

const MISSING_DIR: String = "res://tests/mechanic_popup_20261119/missing_assets"

var _passes: int = 0
var _fails: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	MechanicTips.reset_for_test()
	await _test_l1()
	await _test_l2()
	await _test_l3()
	await _test_l3_pause_abort()
	await _test_queue_and_missing()
	print("MECHANIC_POPUP_TEST_RESULT pass=%d fail=%d" % [_passes, _fails.size()])
	for failure: String in _fails:
		print("FAIL: ", failure)
	if _fails.is_empty():
		print("MECHANIC_POPUP_TEST_OK")
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- A. L1 polarity -------------------------------------------------------

func _test_l1() -> void:
	print("== A. L1 polarity ==")
	var level: Level01 = LEVEL1_SCENE.instantiate() as Level01
	level.enable_start_menu = false
	add_child(level)
	await _wait_seconds(0.6)
	_abort_intro(level)
	await _wait_seconds(0.3)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(660.0, 300.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	level.get_camera().reset_smoothing()

	var popup: MechanicPopup = level.get_mechanic_popup()
	var menu: Node = level.get_pause_menu()
	var opened: bool = await _wait_until(func() -> bool: return popup.is_open(), 2.0)
	_check(opened, "L1 polarity trigger opens")
	_check(popup.get_current_id() == "polarity", "L1 id=polarity")
	_check(get_tree().paused, "L1 popup pauses the tree")
	_check(not bool(menu.call("is_open")), "L1 pause page is not open")
	_check(popup.has_demo() and popup.get_demo_frame_count() == 24, "L1 demo strip loaded (24 frames)")
	_check(popup.get_page_count() == 1, "L1 popup is single page")
	_check(popup.get_page_indicator_text() == "", "single page hides the page label")
	_check(popup.get_footer_text() == "F 继续 · 长按空格 跳过", "single page footer says F 继续")
	var demo_frame_before: int = popup.get_demo_frame()
	await _wait_seconds(0.3)
	_check(popup.get_demo_frame() != demo_frame_before, "demo animates while the tree is paused")
	_check(get_tree().paused, "demo animation does not unpause the tree")

	# Short Space: bar starts but a tap below 0.5 s must not close.
	var start_y: float = player.global_position.y
	_press(KEY_SPACE)
	await _wait_seconds(0.2)
	_check(popup.is_open(), "short Space keeps popup open")
	_check(popup.get_skip_progress() > 0.2 and popup.get_skip_progress() < 0.6,
		"short Space advances the hold bar")
	_check(popup.is_skip_bar_visible(), "short Space shows the gold bar")
	_release(KEY_SPACE)
	await _wait_seconds(0.12)
	_check(popup.is_open(), "Space release before 0.5 s does not close")
	_check(popup.get_skip_progress() == 0.0, "Space release clears the bar")

	# Long Space: 0.5 s closes, restores pause and leaves no jump.
	_press(KEY_SPACE)
	await _wait_seconds(0.32)
	_check(popup.is_open(), "0.32 s hold still open")
	_check(popup.get_skip_progress() >= 0.55, "0.32 s hold shows >55% gold bar")
	await _wait_seconds(0.3)
	_check(not popup.is_open(), "0.5 s hold closes")
	_check(not get_tree().paused, "close restores unpaused tree")
	_release(KEY_SPACE)
	await _wait_seconds(0.25)
	_check(player.is_on_floor(), "player is still on the floor after skip")
	_check(player.global_position.y >= start_y - 0.5, "no jump left behind")
	_check(not bool(menu.call("is_open")), "L1 pause page stays closed")

	# Dedup: leave and re-enter the trigger zone.
	player.global_position = Vector2(620.0, 300.0)
	await _wait_seconds(0.2)
	player.global_position = Vector2(660.0, 300.0)
	await _wait_seconds(0.5)
	_check(not popup.is_open(), "L1 trigger does not repeat")
	_check(MechanicTips.has_seen("polarity"), "L1 seen record is set")

	# R restart does not reset the run-scoped record.
	_tap(KEY_R)
	await _wait_seconds(0.6)
	_abort_intro(level)
	await _wait_seconds(0.2)
	player.global_position = Vector2(660.0, 300.0)
	player.velocity = Vector2.ZERO
	level.get_camera().reset_smoothing()
	await _wait_seconds(0.5)
	_check(not popup.is_open(), "R restart does not re-show L1 popup")
	_check(MechanicTips.has_seen("polarity"), "R restart keeps the seen record")

	await _free_level(level)


# --- B. L2 core carry + relay link ---------------------------------------

func _test_l2() -> void:
	print("== B. L2 core carry + relay link ==")
	_check(MechanicTips.has_seen("polarity"), "L1 seen record survives the level change")
	var level: Level02 = LEVEL2_SCENE.instantiate() as Level02
	add_child(level)
	await _wait_seconds(0.6)
	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(60.0, 320.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()
	level.get_camera().reset_smoothing()
	await _wait_seconds(0.15)

	# Dialogue open -> no popup, even inside the trigger band.
	var stele: GuideEcho = level.get_start_guide()
	var dialogue_open: bool = stele.open_dialogue()
	_check(dialogue_open, "L2 start echo dialogue opened")
	player.global_position = Vector2(100.0, 320.0)
	await _wait_seconds(0.45)
	var popup: MechanicPopup = level.get_mechanic_popup()
	_check(not popup.is_open(), "dialogue blocks the core popup")
	stele.close_dialogue()
	var opened: bool = await _wait_until(func() -> bool: return popup.is_open(), 2.0)
	_check(opened, "core popup opens after dialogue closes")
	_check(popup.get_current_id() == "core_carry", "L2 id=core_carry")
	_check(get_tree().paused, "core popup pauses the tree")
	_check(popup.get_page_count() == 1, "core popup is single page")

	# F closes.
	_tap(KEY_F)
	await _wait_seconds(0.15)
	_check(not popup.is_open(), "F closes the popup")
	_check(not get_tree().paused, "F close restores the tree")

	# Dedup.
	player.global_position = Vector2(70.0, 320.0)
	await _wait_seconds(0.2)
	player.global_position = Vector2(100.0, 320.0)
	await _wait_seconds(0.45)
	_check(not popup.is_open(), "core popup does not repeat")

	# Relay trigger: 400 does not open, 420 opens before the ConductiveRoof
	# starts at x=464. The pause page also blocks the 420 request until resume.
	level.debug_restore_stage(Level02.STABLE_RELAY, true)
	await _wait_seconds(0.35)
	player.global_position = Vector2(400.0, 320.0)
	player.velocity = Vector2.ZERO
	level.get_camera().reset_smoothing()
	await _wait_seconds(0.5)
	_check(not popup.is_open(), "relay popup does not open at x=400")
	_check(player.global_position.x < 420.0, "x=400 is before the relay trigger")

	var menu: Node = level.get_pause_menu()
	menu.call("open_pause")
	_check(get_tree().paused and bool(menu.call("is_open")), "L2 pause page opened")
	player.global_position = Vector2(420.0, 320.0)
	await _wait_seconds(0.45)
	_check(not popup.is_open(), "pause page blocks the relay popup at x=420")
	menu.call("resume")
	var relay_opened: bool = await _wait_until(func() -> bool: return popup.is_open(), 2.0)
	_check(relay_opened, "relay popup opens after resume at x=420")
	_check(popup.get_current_id() == "relay_link", "L2 id=relay_link")
	_check(player.global_position.x >= 420.0 and player.global_position.x < 464.0,
		"relay popup opens before the x=464 ConductiveRoof")

	# Esc is swallowed, no pause page stack.
	_tap(KEY_ESCAPE)
	await _wait_seconds(0.2)
	_check(popup.is_open(), "Esc does not close the popup")
	_check(not bool(menu.call("is_open")), "Esc does not stack the pause page")
	_check(get_tree().paused, "Esc keeps the popup pause")

	_tap(KEY_F)
	await _wait_seconds(0.15)
	_check(not popup.is_open(), "F closes the relay popup")

	# Core body frozen while a popup is open.
	player.global_position = Vector2(390.0, 320.0)
	player.velocity = Vector2.ZERO
	await _wait_seconds(0.2)
	_press(KEY_E)
	await _wait_physics(2)
	_release(KEY_E)
	await _wait_seconds(0.45)
	var core: StarCoreCarrier = level.get_node("Core") as StarCoreCarrier
	_check(core != null, "L2 core node exists")
	var core_position: Vector2 = core.global_position
	var core_velocity: Vector2 = core.velocity
	var core_popup: bool = popup.open_for_test("core_carry")
	_check(core_popup, "core freeze probe popup opened")
	await _wait_seconds(0.5)
	_check(core.global_position.is_equal_approx(core_position), "core position frozen")
	_check(core.velocity.is_equal_approx(core_velocity), "core velocity frozen")
	popup.close()
	await _wait_seconds(0.15)

	# R restart keeps both L2 records.
	_tap(KEY_R)
	await _wait_seconds(0.6)
	player.global_position = Vector2(100.0, 320.0)
	player.velocity = Vector2.ZERO
	level.get_camera().reset_smoothing()
	await _wait_seconds(0.5)
	_check(not popup.is_open(), "R restart does not re-show L2 popups")
	_check(MechanicTips.has_seen("core_carry"), "R restart keeps core_carry seen")
	_check(MechanicTips.has_seen("relay_link"), "R restart keeps relay_link seen")

	await _free_level(level)


# --- C. L3 float device + guard ------------------------------------------

func _test_l3() -> void:
	print("== C. L3 float + guard ==")
	_check(MechanicTips.has_seen("core_carry"), "core_carry seen survives the level change")
	_check(MechanicTips.has_seen("relay_link"), "relay_link seen survives the level change")
	var level: Level03 = LEVEL3_SCENE.instantiate() as Level03
	add_child(level)
	await _wait_seconds(0.9)
	level.debug_restore_stage(Level03.STAGE_RUNE)
	await _wait_seconds(0.4)
	level.debug_place_player_at(Vector2(300.0, 140.0))

	var popup: MechanicPopup = level.get_mechanic_popup()
	var float_opened: bool = await _wait_until(func() -> bool: return popup.is_open(), 2.0)
	_check(float_opened, "float trigger opens")
	_check(popup.get_current_id() == "float_platform", "L3 id=float_platform")
	_check(get_tree().paused, "float popup pauses the tree")
	_tap(KEY_F)
	await _wait_seconds(0.15)
	_check(not popup.is_open(), "F closes the float popup")

	# Dedup.
	level.debug_place_player_at(Vector2(600.0, 300.0))
	await _wait_seconds(0.2)
	level.debug_place_player_at(Vector2(300.0, 140.0))
	await _wait_seconds(0.45)
	_check(not popup.is_open(), "float popup does not repeat")

	# Float-block countdown frozen while paused.
	level.debug_restore_stage(Level03.STAGE_DEVICE)
	await _wait_seconds(0.5)
	_press(KEY_E)
	await _wait_physics(2)
	_release(KEY_E)
	await _wait_seconds(1.6)
	level.debug_place_player_at(Vector2(1082.0, 248.0))
	await _wait_seconds(0.45)
	var blocks: Array[L3FloatBlock] = level.get_float_route().get_blocks()
	_check(blocks.size() >= 2, "float blocks exist")
	var block: L3FloatBlock = blocks[1]
	var block_phase: Variant = block.get("_phase")
	var block_time: float = float(block.get("_phase_time"))
	var block_y: float = block.position.y
	_check(block_time > 0.0, "float block countdown is running before pause")
	var float_probe: bool = popup.open_for_test("float_platform")
	_check(float_probe, "float freeze probe popup opened")
	await _wait_seconds(0.5)
	_check(block.get("_phase") == block_phase, "float block phase frozen")
	_check(is_equal_approx(float(block.get("_phase_time")), block_time), "float block timer frozen")
	_check(is_equal_approx(block.position.y, block_y), "float block position frozen")
	popup.close()
	await _wait_seconds(0.15)

	# Guard teaching waits for the near-gate echo film to hand control back.
	_check(not level.is_guard_tip_ready(), "guard tip is not ready before the echo film")
	level.debug_setup_pre_teaching(1900.0)
	await _wait_seconds(0.4)
	level.debug_place_player_at(Vector2(1900.0, 320.0))
	await _wait_seconds(0.5)
	_check(not popup.is_open(), "guard popup stays closed before the echo film")
	_check(not level.is_guard_tip_ready(), "guard tip still not ready before the film")

	var cine_started: bool = await _start_guard_cine(level)
	_check(cine_started, "near-gate echo film started")
	await _wait_seconds(0.35)
	_check(level.get_cine().is_active(), "echo film is active")
	_check(not popup.is_open(), "guard popup stays closed during the echo film")
	_check(not level.is_guard_tip_ready(), "guard tip not ready during the film")

	var guard_opened: bool = await _skip_guard_cine(level, popup)
	_check(guard_opened, "guard popup opens after the echo film hands control back")
	_check(level.is_guard_tip_ready(), "guard tip ready after the film")
	_check(popup.get_current_id() == "guard_field", "L3 id=guard_field")
	_check(popup.get_page_count() == 2, "guard popup has two pages")
	_check(popup.get_page_index() == 0, "guard opens on page 1")
	_check(popup.get_page_indicator_text() == "1 / 2", "guard page label 1 / 2")
	_check(popup.get_footer_text() == "F 下一页 · 长按空格 跳过", "guard page 1 footer says F 下一页")
	_check(popup.get_key_text() == "Q 换相性 · 被吸近 / 被弹开", "guard page 1 key line")
	_check(popup.get_demo_id() == "guard_invalid", "guard page 1 uses guard_invalid demo")
	_check(popup.get_title_text().contains("无效伤害"), "guard page 1 title is invalid damage")
	_check(popup.get_body_text().contains("不计伤害"), "guard page 1 text says no damage")
	_check(get_tree().paused, "guard page 1 paused")

	var guard: L3Guard = level.get_guard()
	_check(guard.get_state_name() != "NORMAL_SLAM" and guard.get_state_name() != "GRAVITY_RELEASE",
		"guard has not started a damaging attack when the tip opens")
	_check(guard.get_enemy_slam_count() == 0, "guard has not slam-hit before the tip")

	_tap(KEY_F)
	await _wait_seconds(0.08)
	_check(popup.is_open(), "F on page 1 keeps the popup open")
	_check(popup.get_page_index() == 1, "F advances to page 2")
	_check(popup.get_page_indicator_text() == "2 / 2", "guard page label 2 / 2")
	_check(popup.get_footer_text() == "F 关闭 · 长按空格 跳过", "guard page 2 footer says F 关闭")
	_check(popup.get_demo_id() == "guard_valid", "guard page 2 uses guard_valid demo")
	_check(popup.get_title_text().contains("有效伤害"), "guard page 2 title is valid damage")
	_check(popup.get_body_text().contains("趁蓄力被吸近"), "guard page 2 text says during the charge")
	_check(popup.get_body_text().contains("3 点"), "guard page 2 text carries the 3-hit total")
	_check(popup.get_demo_frame() == 0, "page change restarts the demo at frame 0")
	_check(get_tree().paused, "page change keeps the tree paused")
	_check(MechanicTips.has_seen("guard_field"), "page change keeps the seen record")

	_tap(KEY_F)
	await _wait_seconds(0.15)
	_check(not popup.is_open(), "F on the last page closes the guard popup")
	_check(not get_tree().paused, "guard close restores the tree")

	# Hold probe: short Space does not page or close; one long Space closes the
	# whole guard popup from page 1.
	var reopen: bool = popup.open_for_test("guard_field")
	_check(reopen, "guard popup reopens for the hold probe")
	_check(popup.get_page_index() == 0, "hold probe starts on page 1")
	_press(KEY_SPACE)
	await _wait_seconds(0.2)
	_check(popup.is_open() and popup.get_page_index() == 0, "short Space does not page")
	_check(popup.is_skip_bar_visible(), "guard hold shows the shared SkipHoldBar")
	_release(KEY_SPACE)
	await _wait_seconds(0.12)
	_check(popup.is_open() and popup.get_page_index() == 0, "short Space does not close")
	_press(KEY_SPACE)
	await _wait_seconds(0.6)
	_check(not popup.is_open(), "long Space closes the whole guard popup")
	_check(not get_tree().paused, "long Space close restores the tree")
	_release(KEY_SPACE)
	await _wait_seconds(0.1)

	# Charge clock frozen while a popup is open. The player stays same phase so
	# the field repels and the release ring cannot interrupt this probe.
	for _i: int in range(180):
		if not level.is_recovery_active():
			break
		await get_tree().physics_frame
	level.debug_setup_arena_combat(1900.0, true)
	await _wait_seconds(0.4)
	var player: Node = level.get_player()
	player.call("set_polarity_state", true)
	guard = level.get_guard()
	var charged: bool = await _wait_until(
		func() -> bool: return guard.get_state_name() == "GRAVITY_CHARGE", 4.0
	)
	_check(charged, "guard reaches GRAVITY_CHARGE for the freeze probe")
	if charged:
		var guard_state_before: String = guard.get_state_name()
		var guard_elapsed_before: float = guard.get_action_elapsed()
		var guard_ratio_before: float = guard.get_charge_ratio()
		var guard_probe: bool = popup.open_for_test("guard_field")
		_check(guard_probe, "guard freeze probe popup opened")
		await _wait_seconds(0.5)
		_check(guard.get_state_name() == guard_state_before, "guard state frozen")
		_check(is_equal_approx(guard.get_action_elapsed(), guard_elapsed_before),
			"guard charge elapsed frozen")
		_check(is_equal_approx(guard.get_charge_ratio(), guard_ratio_before),
			"guard charge ratio frozen")
		popup.close()
		await _wait_seconds(0.15)

	await _free_level(level)


func _start_guard_cine(level: Level03) -> bool:
	var guard: L3Guard = level.get_guard()
	guard.debug_set_waiting_rubble()
	var waiting: bool = false
	for _i: int in range(120):
		if guard.is_waiting_teaching_rubble():
			waiting = true
			break
		await get_tree().physics_frame
	if not waiting:
		return false
	level.call("_start_cinematic")
	for _i: int in range(60):
		if level.get_cine().is_active():
			return true
		await get_tree().physics_frame
	return level.get_cine().is_active()


func _skip_guard_cine(_level: Level03, popup: MechanicPopup) -> bool:
	_press(KEY_SPACE)
	await _wait_seconds(0.7)
	_release(KEY_SPACE)
	return await _wait_until(func() -> bool: return popup.is_open(), 2.5)


# --- C2. Pause-aborted echo still allows the guard tip --------------------

func _test_l3_pause_abort() -> void:
	print("== C2. guard tip after pause-aborted echo ==")
	MechanicTips.reset_for_test()
	var level: Level03 = LEVEL3_SCENE.instantiate() as Level03
	add_child(level)
	await _wait_seconds(0.9)
	level.debug_setup_pre_teaching(1900.0)
	await _wait_seconds(0.4)
	level.debug_place_player_at(Vector2(1900.0, 320.0))
	var started: bool = await _start_guard_cine(level)
	_check(started, "pause-abort: echo film started")
	await _wait_seconds(0.3)
	_check(level.get_cine().is_active(), "pause-abort: film active")
	var popup: MechanicPopup = level.get_mechanic_popup()
	_check(not popup.is_open(), "pause-abort: tip not open during film")
	var menu: Node = level.get_pause_menu()
	menu.call("open_pause")
	await _wait_seconds(0.2)
	_check(get_tree().paused, "pause-abort: pause page opened")
	_check(not popup.is_open(), "pause-abort: tip not open while paused")
	_check(level.is_guard_tip_ready(), "pause-abort: abort makes the tip ready")
	menu.call("resume")
	var opened: bool = await _wait_until(func() -> bool: return popup.is_open(), 2.5)
	_check(opened, "pause-abort: tip opens after resume")
	_check(popup.get_current_id() == "guard_field", "pause-abort: id=guard_field")
	popup.close()
	await _wait_seconds(0.2)
	_tap(KEY_R)
	await _wait_seconds(0.6)
	_check(not level.is_guard_tip_ready(), "R resets the guard tip ready flag")
	await _free_level(level)


# --- D. Queue / missing demo / paused gate --------------------------------

func _test_queue_and_missing() -> void:
	print("== D. queue / missing demo ==")
	MechanicTips.reset_for_test()
	var popup: MechanicPopup = POPUP_SCENE.instantiate() as MechanicPopup
	popup.name = "StandaloneMechanicPopup"
	add_child(popup)
	await _wait_seconds(0.1)

	var first: bool = popup.open_for_test("polarity")
	_check(first, "standalone popup opens")
	popup.request("core_carry")
	_check(popup.get_queued_ids().has("core_carry"), "second request is queued")
	popup.close()
	await _wait_seconds(0.2)
	_check(popup.is_open() and popup.get_current_id() == "core_carry",
		"queued request opens after close")
	popup.close()
	await _wait_seconds(0.1)

	# Missing assets: real files absent, text must stay usable.
	popup.demo_dir = MISSING_DIR
	var missing: bool = popup.open_for_test("relay_link")
	_check(missing, "missing-demo popup still opens")
	_check(not popup.has_demo(), "missing demo is hidden")
	_check(not popup.get_body_text().is_empty(), "missing demo keeps the body text")
	popup.close()
	popup.demo_dir = MechanicPopup.DEMO_DIR
	await _wait_seconds(0.1)

	# A popup must never open from a tree another system already paused.
	get_tree().paused = true
	var refused: bool = popup.open_for_test("guard_field")
	_check(not refused, "paused tree refuses a popup")
	_check(get_tree().paused, "refused open does not unpause the tree")
	get_tree().paused = false

	popup.queue_free()
	await _wait_seconds(0.1)


# --- Helpers --------------------------------------------------------------

func _abort_intro(level: Level01) -> void:
	if level == null:
		return
	if level.get_opening() != null and level.get_opening().is_active():
		level.get_opening().abort()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("  PASS ", label)
	else:
		_fails.append(label)
		print("  FAIL ", label)


func _wait_seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(ceil(seconds * 1000.0))
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait_physics(frames: int) -> void:
	for _i: int in range(maxi(frames, 1)):
		await get_tree().physics_frame


func _wait_until(predicate: Callable, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
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


func _tap(code: Key) -> void:
	_press(code)
	await _wait_physics(2)
	_release(code)
	await _wait_physics(1)


func _free_level(level: Node) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	await _wait_seconds(0.15)
	get_tree().paused = false
