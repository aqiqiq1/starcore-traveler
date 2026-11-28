extends Node

## Third-round DLC parity test for 星核织机.
##
##   ... --headless --path . res://dlc/star_loom/tests/ui_parity_test.tscn
##
## Covers the new player-facing layers only:
##   - the 20x20 phase icon, 9 px icon-row labels and the three-cell overhead
##     health meter (distinct from the three-heart life row);
##   - the one remaining shared MechanicPopup teaching window (the first
##     stage-2 fire telegraph): copy, 24-frame demo, tree pause, swallowed Esc,
##     F and long-Space close, and once-per-run behaviour;
##   - no entry/core popup: entering the hall and exposing the core must not
##     pause or repeat the guide's two pages;
##   - timer freeze while the popup is open (no stage/attack skip on resume);
##   - the exposed core's cyan/gold beacon contract and its one-shot first
##     exposure burst;
##   - the 360x236 four-button pause page, its copy and focus ring, and the
##     real restart wiring (full chapter reset);
##   - the 400x210 completion page, its copy, two buttons, focus ring, real
##     mouse click on 重玩本关, and the full chapter reset it performs.
## E/Enter back to the title from the completion page stays in mechanics_test.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const PAUSE_SIZE: Vector2 = Vector2(360.0, 236.0)
const COMPLETION_SIZE: Vector2 = Vector2(400.0, 210.0)
const TIP_FIRE: String = "loom_fire_tip"

var _loom: StarLoom
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# A test process starts clean: the chapter's _ready() re-registers the one
	# remaining loom tip, and the run-scoped seen table starts empty.
	MechanicTips.reset_for_test()
	MechanicPopup.reset_registered_tips_for_test()
	await _run()
	await _cleanup()
	_release_all()
	print("STAR_LOOM_UI_PARITY_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- helpers ---------------------------------------------------------------

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


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _parse_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	Input.parse_input_event(event)


func _push_click(position: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.global_position = position
	get_viewport().push_input(down, true)
	await _wait_process(1)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.global_position = position
	get_viewport().push_input(up, true)


func _release_all() -> void:
	for action: StringName in [
		&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause",
	]:
		Input.action_release(action)
	for code: int in [KEY_SPACE, KEY_F, KEY_J, KEY_ESCAPE, KEY_ENTER]:
		_parse_key(code, false)


func _display_width(text_value: String) -> float:
	var width: float = 0.0
	for index: int in range(text_value.length()):
		width += 0.5 if text_value.unicode_at(index) < 128 else 1.0
	return width


func _max_line_width(text_value: String) -> float:
	var widest: float = 0.0
	for line: String in text_value.split("\n"):
		widest = maxf(widest, _display_width(line))
	return widest


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_loom.get_camera().reset_smoothing()
	await _wait_physics(3)


func _wait_attack_ready() -> void:
	await _wait_until(
		func() -> bool: return not _player.is_attacking() and _player.get_attack_cooldown() <= 0.0,
		90
	)


func _swing_j() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(7)
	_push_key(KEY_J, false)
	await _wait_physics(2)
	await _wait_attack_ready()


func _jump_swing_j() -> void:
	Input.action_press(&"jump")
	await _wait_physics(8)
	await _swing_j()
	Input.action_release(&"jump")
	await _wait_until(func() -> bool: return _player.is_on_floor(), 90)


func _core_hit() -> bool:
	await _place(660.0, 320.0, not _loom.get_core().get_phase())
	var before: int = _loom.get_core_hits()
	await _jump_swing_j()
	return _loom.get_core_hits() > before or _loom.is_completed()


## Drive one real death through the shared strike path.  With lives = 1 this
## opens game over; no hit or life rule is bypassed.
func _cause_game_over() -> bool:
	await _place(420.0, 320.0, false)
	await _wait_physics(50)
	await _wait_until(
		func() -> bool: return _loom.get_damage_immunity_left() <= 0.0, 120
	)
	for index: int in range(3):
		_loom.debug_apply_player_hit()
		await _wait_physics(2)
		if index < 2:
			await _wait_until(
				func() -> bool: return _loom.get_damage_immunity_left() <= 0.0,
				120
			)
	return await _wait_until(func() -> bool: return _loom.is_game_over(), 240)


func _load_loom() -> bool:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		return false
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	_loom.show_intro_cinematic = false
	get_tree().root.add_child(_loom)
	get_tree().current_scene = _loom
	await _wait_process(3)
	await _wait_physics(8)
	_player = _loom.get_player()
	return _player != null


func _cleanup() -> void:
	get_tree().paused = false
	if _loom != null and is_instance_valid(_loom):
		_loom.get_audio().stop_all()
	if is_instance_valid(DemoAudio):
		DemoAudio.release_streams()
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(12)


# --- main flow -------------------------------------------------------------

func _run() -> void:
	_check(await _load_loom(), "star_loom scene loads for the parity test")
	if _player == null:
		return
	var popup: MechanicPopup = _loom.get_mechanic_popup()
	_check(popup != null, "the chapter instantiates the shared MechanicPopup")
	if popup == null:
		return
	_check(popup.level_node == _loom, "the popup is bound to the loom level node")
	var parity_hud: LoomHUD = _loom.get_hud()
	_check(not parity_hud.has_top_hit_group(),
		"the top icon row has no hit group")
	_check(parity_hud.get_phase_icon_rect().size == Vector2(20.0, 20.0)
		and parity_hud.is_phase_text_hidden(),
		"the top-right phase read is a 20x20 icon with no 相 text")
	var status_texts: Array[String] = parity_hud.get_status_label_texts()
	var status_labels: Dictionary = parity_hud.get_status_labels()
	var labels_valid: bool = (
		status_texts.is_empty()
		and parity_hud.get_status_label_font_size() == 0
		and status_labels.is_empty()
	)
	_check(labels_valid, "the old 阶段/节点/核心/生命 label row is gone",
		str(status_texts) + " size=%d" % parity_hud.get_status_label_font_size())
	var boss_bar: HudBossBar = parity_hud.get_boss_bar()
	_check(boss_bar != null
		and boss_bar.size.is_equal_approx(Vector2(360.0, 16.0))
		and boss_bar.get_lives_current() == 3,
		"the shared boss bar carries the stage/core state and three lives")
	var health_bar: LoomHealthBar = parity_hud.get_player_health_bar()
	_check(health_bar != null and health_bar.get_style_name() == "bar"
		and not health_bar.is_heart_style()
		and health_bar.get_current() == 3 and health_bar.get_max() == 3
		and health_bar.get_segment_rects().size() == 3,
		"the health value is a three-segment red bar")
	var ids: Array[String] = MechanicPopup.get_registered_tip_ids()
	_check(
		ids.size() == 1 and ids[0] == TIP_FIRE,
		"the fire tip is the only registered loom tip",
		str(ids)
	)

	# --- 1. entering the hall must not open an entry popup ----------------
	await _place(400.0, 320.0, false)
	Input.action_press(&"move_right")
	var entered: bool = await _wait_until(
		func() -> bool: return _loom.is_boss_active(), 220
	)
	Input.action_release(&"move_right")
	_check(entered, "walking into the hall starts the boss")
	await _wait_process(20)
	_check(not popup.is_open(), "entering the hall opens no teaching popup")
	_check(not get_tree().paused, "entering the hall does not pause the tree")

	# The boss is now active; hazards are irrelevant to the UI checks.
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	await _wait_physics(4)

	# --- 2. exposed core: beacon, one burst, no core popup ----------------
	_loom.debug_expose_core()
	_check(_loom.is_core_exposed(), "both nodes down expose the core")
	_check(not popup.is_open(), "exposing the core opens no teaching popup")
	_check(not get_tree().paused, "exposing the core does not pause the tree")
	var fx: LoomFx = _loom.get_fx()
	_check(fx.is_core_exposed_burst_active(),
		"the first exposure starts a short white flash")
	if fx.is_core_exposed_burst_active():
		_check(fx.get_core_exposed_burst_progress() < 0.5,
			"the fresh flash is still in its opening half",
			"%.3f" % fx.get_core_exposed_burst_progress())
	var fx_info: Dictionary = fx.get_expose_fx_info()
	_check(is_equal_approx(float(fx_info["duration"]), 0.30),
		"the first-exposure flash lasts 0.30 s", str(fx_info["duration"]))
	_check(bool(fx_info["white_flash"]) and not bool(fx_info["has_ring"]),
		"the first exposure is a white flash with no ring")
	_check(int(fx_info["particles"]) <= 12,
		"the first exposure uses only a few particles",
		str(fx_info["particles"]))
	var visual: Dictionary = _loom.get_core().get_expose_visual_info()
	_check(visual["diamond_size"] == Vector2(40.0, 40.0),
		"the exposed core is a 40x40 diamond", str(visual["diamond_size"]))
	_check(visual["diamond_color"] == Color("#f4cd63")
		and visual["icon"] == "sun",
		"gold phase uses a solid gold diamond and sun icon",
		"%s / %s" % [visual["diamond_color"], visual["icon"]])
	_check(float(visual["net_gap"]) >= 24.0,
		"the opened gold net leaves at least a 24 px gap",
		"%.1f px" % float(visual["net_gap"]))
	_check(not bool(visual["has_ring"]),
		"the exposed core draws no cyan/gold ring")
	var burst_ended: bool = await _wait_until(
		func() -> bool: return not fx.is_core_exposed_burst_active(), 120
	)
	_check(burst_ended, "the white flash ends as a one-shot")
	# A later stage exposure keeps the same body-only read and does not replay
	# the flash.
	_loom.debug_set_stage(2)
	_loom.debug_expose_core()
	await _wait_physics(2)
	_check(not fx.is_core_exposed_burst_active(),
		"later exposures do not replay the first-exposure flash")

	# --- 3. stage-2 fire popup -------------------------------------------
	_loom.debug_set_stage(2)
	_loom.debug_set_attacks_enabled(true)
	_loom.debug_set_boss_grace(0.0)
	_loom.debug_clear_hazards()
	var audio: LoomAudio = _loom.get_audio()
	_check(audio.is_music_playing(),
		"chapter music is playing before the fire popup")
	var forced: bool = _loom.debug_force_attack("fire")
	_check(_loom.get_telegraph_points().size() == 2,
		"the fire popup is attached to the real two-vent warning",
		str(_loom.get_telegraph_points()))
	var fire_opened: bool = await _wait_until(
		func() -> bool: return popup.is_open(), 60
	)
	_check(forced and fire_opened, "the first stage-2 fire warning opens the fire popup")
	if fire_opened:
		_check(audio.is_music_playing() and not audio.is_music_paused(),
			"music keeps playing while the teaching popup pauses the tree")
		_check(popup.get_current_id() == TIP_FIRE,
			"fire popup id is loom_fire_tip", popup.get_current_id())
		_check(get_tree().paused, "the popup pauses the tree")
		_check(_loom.is_mechanic_popup_blocked(),
			"the level reports popups blocked while one is open")
		_check(not _loom.is_footstep_audio_allowed(),
			"footsteps are gated while the teaching popup is open")
		await _wait_process(2)
		_check(not _loom.get_hud().get_player_health_bar().visible,
			"overhead health meter hides while the teaching popup is open")
		_check(popup.get_title_text() == "地砖火道",
			"fire popup title matches UI_PARITY_SPEC", popup.get_title_text())
		_check(popup.get_body_text() == "织机把城内火道接进地砖，喷焰前砖面先亮。\n看到亮砖就离开，横扫光带跳过去。",
			"fire popup body matches UI_PARITY_SPEC", popup.get_body_text())
		_check(popup.get_key_text() == "先离开亮起的砖，再跳过横扫光带。",
			"fire popup key is a natural sentence", popup.get_key_text())
		_check(_max_line_width(popup.get_body_text()) <= 21.0,
			"fire popup body lines fit 21 full-width units",
			"%.1f" % _max_line_width(popup.get_body_text()))
		_check(popup.get_body_text().split("\n").size() <= 3,
			"fire popup body has at most three lines")
		_check(popup.get_demo_id() == "loom_fire",
			"fire popup demo id is loom_fire", popup.get_demo_id())
		_check(popup.has_demo() and popup.get_demo_frame_count() == 24,
			"fire popup plays the real 24-frame loom_fire demo",
			"frames=%d" % popup.get_demo_frame_count())
		var attack_before: float = _loom.get_attack_time_left()
		var stage_before: int = _loom.get_stage()
		var music_before: float = audio.get_music_position()
		await _wait_process(20)
		_check(absf(_loom.get_attack_time_left() - attack_before) < 0.001,
			"fire warning does not time out while the popup is open",
			"%.3f -> %.3f" % [attack_before, _loom.get_attack_time_left()])
		_check(audio.get_music_position() > music_before + 0.05,
			"music position advances while the popup pauses the game",
			"%.2f -> %.2f" % [music_before, audio.get_music_position()])
		_check(_loom.get_stage() == stage_before,
			"the stage does not jump while the popup is open",
			str(_loom.get_stage()))
		_push_key(KEY_F, true)
		await _wait_physics(2)
		_push_key(KEY_F, false)
		var fire_closed: bool = await _wait_until(
			func() -> bool: return not popup.is_open(), 60
		)
		_check(fire_closed, "F closes the fire popup")
		_check(not get_tree().paused, "closing the fire popup unpauses the tree")
		_check(audio.is_music_playing(),
			"music is still playing after the teaching popup closes")
		_check(MechanicTips.has_seen(TIP_FIRE), "the fire tip is marked seen")
		await _wait_physics(2)
		_check(_loom.get_attack_state_name() == "telegraph",
			"the paused fire warning resumes instead of being skipped",
			_loom.get_attack_state_name())
		_check(_loom.get_attack_time_left() >= attack_before - 0.10,
			"the fire warning resumes from the frozen value, without a jump",
			"%.3f -> %.3f" % [attack_before, _loom.get_attack_time_left()])
		# A second fire warning must not reopen the popup.
		_loom.debug_force_attack("fire")
		await _wait_process(20)
		_check(not popup.is_open(), "the fire popup does not open a second time")
		# The shared long-Space close still works; open_for_test ignores the
		# run-scoped seen bit without changing the real trigger count.
		var reopened: bool = popup.open_for_test(TIP_FIRE)
		_check(reopened, "the shared popup can be reopened for the skip check")
		if reopened:
			_parse_key(KEY_SPACE, true)
			var hold_armed: bool = await _wait_until(
				func() -> bool: return popup.is_skip_bar_visible(), 20
			)
			_check(hold_armed, "holding Space shows the shared skip bar")
			var held_closed: bool = await _wait_until(
				func() -> bool: return not popup.is_open(), 300
			)
			_parse_key(KEY_SPACE, false)
			_check(held_closed, "long Space hold closes the shared popup")
			_check(not get_tree().paused, "closing the held popup unpauses the tree")
		# R restarts the chapter but must not replay the already-seen tip.
		_push_key(KEY_R, true)
		await _wait_physics(2)
		_push_key(KEY_R, false)
		await _wait_process(12)
		_check(not popup.is_open(), "R does not replay the fire tip")
		_check(_loom.get_stage() == 1 and not _loom.is_boss_active(),
			"R still restarts the chapter while the tip stays seen")

	# --- 4. pause page ----------------------------------------------------
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(2)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(4)
	_check(_loom.is_pause_open() and get_tree().paused,
		"Esc opens the new pause page")
	var hud: LoomHUD = _loom.get_hud()
	_check(hud.is_pause_visible(), "the HUD pause page is visible")
	_check(not popup.open_for_test(TIP_FIRE),
		"a mechanic popup cannot open over the pause page")
	await _wait_process(6)
	_check(hud.get_pause_panel_rect().size == PAUSE_SIZE,
		"pause panel is 360x236", str(hud.get_pause_panel_rect().size))
	_check(hud.get_pause_panel_rect().position == Vector2(140.0, 56.0),
		"pause panel is centred and slightly high",
		str(hud.get_pause_panel_rect().position))
	_check(hud.get_pause_subtitle_text() == "星核织机 · 城内",
		"pause subtitle is 星核织机 · 城内", hud.get_pause_subtitle_text())
	_check(hud.get_pause_note_text() == "返回主界面不保存本章进度",
		"pause footnote matches the base game", hud.get_pause_note_text())
	_check(hud.get_continue_button().text == "继续游戏"
		and hud.get_continue_button().variant == PixelMenuButton.Variant.STONE,
		"pause button 1 is 继续游戏 / STONE")
	_check(hud.get_restart_button().text == "重新开始本章"
		and hud.get_restart_button().variant == PixelMenuButton.Variant.OPTION,
		"pause button 2 is 重新开始本章 / OPTION")
	_check(hud.get_title_button().text == "返回主界面"
		and hud.get_title_button().variant == PixelMenuButton.Variant.OPTION,
		"pause button 3 is 返回主界面 / OPTION")
	_check(hud.get_quit_button().text == "退出游戏"
		and hud.get_quit_button().variant == PixelMenuButton.Variant.OPTION,
		"pause button 4 is 退出游戏 / OPTION")
	_check(hud.get_pause_controls_button().text == "操作"
		and hud.get_pause_controls_button().variant == PixelMenuButton.Variant.OPTION,
		"pause button 5 is 操作 / OPTION")
	_check(hud.get_manual_button().text == "手册"
		and hud.get_manual_button().variant == PixelMenuButton.Variant.OPTION,
		"pause button 6 is 手册 / OPTION")
	var pause_buttons: Array[PixelMenuButton] = [
		hud.get_continue_button(), hud.get_restart_button(),
		hud.get_title_button(), hud.get_quit_button(),
		hud.get_pause_controls_button(), hud.get_manual_button(),
	]
	var pause_positions: Array[Vector2] = [
		Vector2(76.0, 56.0), Vector2(76.0, 90.0),
		Vector2(76.0, 124.0), Vector2(76.0, 158.0),
		Vector2(76.0, 192.0), Vector2(184.0, 192.0),
	]
	var pause_sizes: Array[Vector2] = [
		Vector2(208.0, 24.0), Vector2(208.0, 24.0),
		Vector2(208.0, 24.0), Vector2(208.0, 24.0),
		Vector2(100.0, 24.0), Vector2(100.0, 24.0),
	]
	var pause_layout_ok: bool = true
	for index: int in range(pause_buttons.size()):
		var button: PixelMenuButton = pause_buttons[index]
		if button.size != pause_sizes[index] or button.position != pause_positions[index]:
			pause_layout_ok = false
	_check(pause_layout_ok,
		"pause buttons keep the four full rows and split 操作/手册 on the last row")
	var pause_ring_ok: bool = true
	for index: int in range(pause_buttons.size()):
		var current: PixelMenuButton = pause_buttons[index]
		var next_button: PixelMenuButton = pause_buttons[(index + 1) % pause_buttons.size()]
		if current.get_node(current.focus_next) != next_button:
			pause_ring_ok = false
	_check(pause_ring_ok, "the pause page has a six-item focus ring")
	_check(hud.get_continue_button().has_focus(),
		"pause focus starts on 继续游戏")
	_check(hud.resume_requested.is_connected(Callable(_loom, "_on_hud_resume_requested")),
		"继续游戏 is wired to the level resume")
	_check(hud.title_requested.is_connected(Callable(_loom, "_on_hud_title_requested")),
		"返回主界面 is wired to the title flow")
	_check(hud.quit_requested.is_connected(Callable(_loom, "_on_hud_quit_requested")),
		"退出游戏 is wired to get_tree().quit()")
	_push_key(KEY_DOWN, true)
	await _wait_physics(2)
	_push_key(KEY_DOWN, false)
	await _wait_process(2)
	_check(hud.get_restart_button().has_focus(),
		"Down moves pause focus to 重新开始本章")
	_push_key(KEY_ENTER, true)
	await _wait_physics(2)
	_push_key(KEY_ENTER, false)
	await _wait_process(4)
	_check(not _loom.is_pause_open() and not get_tree().paused,
		"重新开始本章 closes the pause page and unpauses")
	_check(_loom.get_stage() == 1 and not _loom.is_boss_active(),
		"重新开始本章 resets the whole chapter to stage 1")
	_check(absf(_player.global_position.x - _loom.get_start_spawn().x) < 4.0,
		"重新开始本章 returns the player to the hall entrance",
		"x=%.1f" % _player.global_position.x)
	_check(not hud.is_completion_visible(),
		"重新开始本章 keeps the completion page hidden")

	# --- 5. completion page ----------------------------------------------
	_loom.debug_set_stage(3)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_set_boss_grace(0.0)
	_loom.debug_clear_hazards()
	_loom.debug_expose_core()
	await _wait_physics(3)
	var core_ok: bool = true
	for _index: int in range(3):
		if not await _core_hit():
			core_ok = false
			break
	_check(core_ok, "three real core hits complete the parity route")
	var completed: bool = await _wait_until(
		func() -> bool: return _loom.is_completed(), 180
	)
	_check(completed, "the completion page appears")
	if completed:
		_check(hud.is_completion_visible(), "completion page is visible")
		await _wait_process(6)
		_check(hud.get_completion_panel_rect().size == COMPLETION_SIZE,
			"completion panel is 400x210", str(hud.get_completion_panel_rect().size))
		_check(hud.get_completion_panel_rect().position == Vector2(120.0, 75.0),
			"completion panel sits at (120,75)",
			str(hud.get_completion_panel_rect().position))
		_check(hud.get_completion_subtitle_text() == "城内的经线松开，星核的梭子终于停下。",
			"completion subtitle matches UI_PARITY_SPEC",
			hud.get_completion_subtitle_text())
		_check(hud.get_completion_note_text() == "本章结算 · 暂停菜单可查看操作",
			"completion footnote matches the base game", hud.get_completion_note_text())
		var primary: PixelMenuButton = hud.get_completion_primary_button()
		var secondary: PixelMenuButton = hud.get_completion_secondary_button()
		_check(primary != null and primary.text == "返回主界面"
			and primary.variant == PixelMenuButton.Variant.STONE,
			"completion primary is 返回主界面 / STONE")
		_check(primary != null and primary.size == Vector2(180.0, 28.0)
			and primary.position == Vector2(110.0, 86.0),
			"completion primary is 180x28 at (110,86)")
		_check(secondary != null and secondary.text == "重玩本关"
			and secondary.variant == PixelMenuButton.Variant.OPTION,
			"completion secondary is 重玩本关 / OPTION")
		_check(secondary != null and secondary.size == Vector2(180.0, 24.0)
			and secondary.position == Vector2(110.0, 126.0),
			"completion secondary is 180x24 at (110,126)")
		_check(primary.get_node(primary.focus_next) == secondary
			and secondary.get_node(secondary.focus_next) == primary,
			"completion buttons form a two-item focus ring")
		_check(primary.has_focus(), "completion focus starts on 返回主界面")
		_check(hud.title_requested.is_connected(Callable(_loom, "_on_hud_title_requested")),
			"返回主界面 is wired to the title flow")
		_check(hud.restart_requested.is_connected(Callable(_loom, "_on_hud_restart_requested")),
			"重玩本关 is wired to the chapter reset")
		var click_rect: Rect2 = secondary.get_global_rect()
		await _push_click(click_rect.get_center())
		await _wait_process(6)
		_check(not _loom.is_completed(), "mouse click on 重玩本关 leaves completion")
		_check(not hud.is_completion_visible(), "completion page is hidden after replay")
		_check(_loom.get_stage() == 1 and not _loom.is_boss_active(),
			"重玩本关 resets the whole chapter to stage 1")
		_check(absf(_player.global_position.x - _loom.get_start_spawn().x) < 4.0,
			"重玩本关 returns the player to the hall entrance",
			"x=%.1f" % _player.global_position.x)

	# --- 6. game over page: keyboard retry --------------------------------
	_loom.debug_set_stage(2)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	_loom.debug_set_lives(1)
	_check(await _cause_game_over(), "one remaining heart can still reach game over")
	await _wait_process(6)
	_check(hud.is_game_over_visible(), "game over page is visible")
	_check(hud.get_game_over_panel_rect() == Rect2(
		Vector2(140.0, 75.0), Vector2(360.0, 210.0)),
		"game over panel is 360x210 at (140,75)",
		str(hud.get_game_over_panel_rect()))
	_check(hud.get_game_over_hearts().kind == HitPips.Kind.HEART
		and hud.get_game_over_hearts().get_current() == 0,
		"the game over page shows an empty heart row")
	_check(hud.get_game_over_title_text() == "生命耗尽",
		"game over title is 生命耗尽")
	_check(hud.get_game_over_retry_button().text == "重试本章"
		and hud.get_game_over_title_button().text == "返回标题",
		"game over buttons are 重试本章 / 返回标题")
	_check(hud.get_game_over_retry_button().has_focus(),
		"game over focus starts on 重试本章")
	_push_key(KEY_DOWN, true)
	await _wait_physics(2)
	_push_key(KEY_DOWN, false)
	await _wait_process(2)
	_check(hud.get_game_over_title_button().has_focus(),
		"Down moves game over focus to 返回标题")
	_push_key(KEY_UP, true)
	await _wait_physics(2)
	_push_key(KEY_UP, false)
	await _wait_process(2)
	_check(hud.get_game_over_retry_button().has_focus(),
		"Up moves game over focus back to 重试本章")
	_push_key(KEY_ENTER, true)
	await _wait_physics(2)
	_push_key(KEY_ENTER, false)
	await _wait_process(8)
	_check(not _loom.is_game_over() and not hud.is_game_over_visible(),
		"Enter on 重试本章 restarts through the keyboard")
	_check(_loom.get_lives() == 3 and _loom.get_stage() == 1,
		"keyboard retry resets lives and the chapter",
		"lives=%d stage=%d" % [_loom.get_lives(), _loom.get_stage()])
	_check(absf(_player.global_position.x - _loom.get_start_spawn().x) < 4.0,
		"keyboard retry returns to the start")

	# --- 7. game over page: mouse title ----------------------------------
	_loom.debug_set_stage(2)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	_loom.debug_set_lives(1)
	_check(await _cause_game_over(), "a second game over can be reached for the title click")
	await _wait_process(6)
	var title_rect: Rect2 = hud.get_game_over_title_button().get_global_rect()
	await _push_click(title_rect.get_center())
	var title_ok: bool = await _wait_until(
		func() -> bool:
			var current: Node = get_tree().current_scene
			return (
				current != null
				and current.scene_file_path == "res://scenes/level_01.tscn"
				and current.get_node_or_null("StartMenu") != null
			),
		240
	)
	_check(title_ok, "mouse click on 返回标题 returns to the title menu")
