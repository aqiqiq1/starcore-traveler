extends Node

## UI parity / copy test for the 2026-11-26 rift-workshop rework 2.
##
##   ... --headless --path . res://dlc/rift_workshop/tests/parity_test.tscn
##
## Covers the three guide pages and their demos, no permanent legend, the
## 20 x 20 phase icon, the boss status row, the mirror tip, the three-hit failure
## line, the core tip, the pause page and the completion page.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"

var _checks: int = 0
var _failures: Array[String] = []
var _rift: RiftWorkshop = null
var _player: L3Player = null
var _hud: RiftWorkshopHUD = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("RIFT_PARITY_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


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


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_process(2)
	_push_key(code, false)
	await _wait_process(4)


## The shared guide swaps page copy at the midpoint of a 0.12 s crossfade.
func _wait_page_transition(guide: DlcGuide) -> void:
	for _index: int in range(600):
		if not guide.is_page_transitioning():
			return
		await get_tree().process_frame


func _display_width(text_value: String) -> float:
	var width: float = 0.0
	for index: int in range(text_value.length()):
		width += 0.5 if text_value.unicode_at(index) < 128 else 1.0
	return width


## A standalone Q/J/E/F (not the E of "Esc") is banned outside key rows.
func _has_bare_key_letter(text: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("(^|[^A-Za-z])[QJEF]([^A-Za-z]|$)")
	return regex.search(text) != null


func _check_lines(label: String, body: String, key: String) -> void:
	var lines: PackedStringArray = body.split("\n")
	_check(lines.size() <= 3, label + " body has at most 3 lines", str(lines.size()))
	var all_fit: bool = true
	for line: String in lines:
		if _display_width(line) > 21.001:
			all_fit = false
			_check(false, label + " line fits 21 cells",
				"%s (%.1f)" % [line, _display_width(line)])
	_check(all_fit, label + " body lines fit 21 cells")
	_check(_display_width(key) <= 21.001, label + " key fits 21 cells",
		"%.1f" % _display_width(key))


func _place(x: float, y: float, positive: bool = false) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(3)


func _wait_popup_open(id: String, max_frames: int) -> bool:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null:
		return false
	return await _wait_until(
		func() -> bool: return popup.is_open() and popup.get_current_id() == id,
		max_frames
	)


func _close_popup() -> bool:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return false
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)
	return not popup.is_open()


func _cleanup() -> void:
	get_tree().paused = false
	# The parity run returns to level_01; release the title scene and its new
	# title BGM before quit (test teardown only, no gameplay assertion changed).
	var current: Node = get_tree().current_scene
	if current != null and current != _rift:
		var menu: Node = current.get_node_or_null("StartMenu")
		if menu != null and menu.has_method("stop_title_music_for_test"):
			menu.call("stop_title_music_for_test")
		get_tree().current_scene = null
		current.queue_free()
		await _wait_process(20)
	get_tree().current_scene = null
	if _rift != null and is_instance_valid(_rift):
		_rift.queue_free()
	await _wait_process(20)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


func _run() -> void:
	MechanicTips.reset_for_test()
	MechanicPopup.reset_registered_tips_for_test()
	await _test_missing_demo_fallback()

	_rift = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(8)
	await _wait_physics(4)
	_player = _rift.get_player()
	_hud = _rift.get_hud()
	_check(_rift.get_intro_guide() != null and _rift.get_intro_guide().is_open(),
		"normal entry opens the guide")
	_check(_rift.get_ambience().is_playing(),
		"ambience keeps playing under the paused guide")
	var health_bar: PlayerHealthBar = _hud.get_player_health_bar()
	_check(health_bar != null and health_bar.get_style_name() == "bar"
		and health_bar.get_segment_rects().size() == 3,
		"the player health value is the three-segment shared bar")
	_check(_hud.is_lives_visible() and _hud.get_lives() == 3
		and _hud.get_max_lives() == 3,
		"three life hearts sit under the boss bar")
	_check(not _hud.is_player_health_visible(), "guide hides the fixed health bar")
	_check(_hud.get_phase_icon_kind() == "sun"
		and not _hud.is_affinity_text_visible(),
		"HUD uses the sun icon instead of 辉相 text")
	_check(_hud.get_phase_icon().size == Vector2(20.0, 20.0),
		"phase icon is 20 x 20", str(_hud.get_phase_icon().size))
	_check(_hud.has_element_legend() == false
		and _hud.find_child("ElementLegend", true, false) == null,
		"no permanent element legend row exists")
	var music_pos_before: float = _rift.get_ambience().get_playback_position()
	await _wait_process(24)
	_check(_rift.get_ambience().get_playback_position() > music_pos_before + 0.05,
		"ambience playback position advances under the guide")
	await _test_guide()
	await _test_blocked_while_guide()
	await _close_guide()
	await _test_pause_page_and_restart()
	await _test_boss_status_and_mirror_tip()
	await _test_failure_line()
	await _test_core_tip()
	await _test_completion_page()


func _test_missing_demo_fallback() -> void:
	MechanicPopup.register_tips({
		"parity_missing_demo": {
			"title": "缺失演示降级",
			"body": "演示缺失时正文仍然可读。\n用继续键关闭。",
			"key": "{F} 继续",
			"demo": "rift_mirror",
		},
	}, "res://dlc/ui/demos/__missing_mirror_demo__")
	var popup: MechanicPopup = (
		load("res://scenes/ui/mechanic_popup.tscn") as PackedScene
	).instantiate() as MechanicPopup
	add_child(popup)
	await _wait_process(2)
	var opened: bool = popup.open_for_test("parity_missing_demo")
	await _wait_process(2)
	_check(opened and popup.is_open(), "missing-demo tip still opens")
	_check(not popup.has_demo() and popup.get_demo_frame_count() == 0
		and popup.get_demo_id() == "rift_mirror",
		"missing mirror strip degrades without a demo")
	popup.close()
	await _wait_process(4)
	_check(not popup.is_open() and not get_tree().paused,
		"missing-demo tip closes and unpauses")
	popup.queue_free()
	await _wait_process(2)
	MechanicTips.reset_for_test()


func _test_guide() -> void:
	var guide: DlcGuide = _rift.get_intro_guide()
	if guide == null:
		return
	_check(guide.get_page_count() == 3, "guide has three pages",
		str(guide.get_page_count()))
	_check(guide.get_page_indicator_text() == "1 / 3",
		"page indicator starts at 1 / 3", guide.get_page_indicator_text())
	var titles: Array[String] = ["紫幕与月门", "相性光桥", "双面镜"]
	var bodies: Array[String] = [
		"星核裂开时留下紫幕，穿过会把相性翻面。\n这一章无法自由换相；同相才能过门。\n送澜相青核入仓，月门才会通电。",
		"光桥只认同相，先用攻击熄灭桥上的光灵。\n光灵熄灭后，这座桥会一直亮着。\n俯冲的光灵会翻相，别停在桥上。",
		"双面镜有三形态，金、青面盘护着核心。\n第二形态起面盘被光灵锚定，先熄光灵，\n六秒内用异相攻击击碎；核心有时限。",
	]
	var keys: Array[String] = [
		"穿过紫幕翻相；送青核入仓，月门通电。",
		"先熄桥上的光灵，再过桥；俯冲会翻相。",
		"先熄锚定光灵，六秒内碎面盘，再打核心。",
	]
	var demos: Array[String] = ["rift_inversion", "rift_bridge", "rift_mirror"]
	for index: int in range(3):
		_check(guide.get_title_text() == titles[index],
			"guide page %d title" % (index + 1), guide.get_title_text())
		_check(guide.get_body_text() == bodies[index],
			"guide page %d body" % (index + 1), guide.get_body_text())
		_check(not _has_bare_key_letter(guide.get_body_text()),
			"guide page %d body has no bare Q/J/E/F" % (index + 1),
			guide.get_body_text())
		_check(guide.get_key_text() == KeyGlyph.plain(keys[index]),
			"guide page %d key plain" % (index + 1), guide.get_key_text())
		_check(not guide.get_key_text().contains("[img]")
			and not guide.get_key_text().contains("{"),
			"guide page %d get_key_text is plain" % (index + 1))
		_check(guide.get_demo_id() == demos[index],
			"guide page %d demo" % (index + 1), guide.get_demo_id())
		_check(guide.get_demo_frame_count() == 24,
			"guide page %d demo has 24 frames" % (index + 1),
			str(guide.get_demo_frame_count()))
		_check(absf(guide.get_demo_fps() - 8.0) < 0.01,
			"guide page %d demo is 8 fps" % (index + 1),
			"%.2f" % guide.get_demo_fps())
		_check_lines("guide page %d" % (index + 1), bodies[index], keys[index])
		_check(not keys[index].contains(" · "),
			"guide page %d key is a natural sentence, not a noun+key list" % (index + 1),
			keys[index])
		if index < 2:
			await _tap_key(KEY_F)
			await _wait_page_transition(guide)
	_check(guide.get_page_indicator_text() == "3 / 3",
		"guide reaches 3 / 3", guide.get_page_indicator_text())
	_check(guide.get_footer_rich_text().contains("[img=16x16]"),
		"guide footer renders the F keycap", guide.get_footer_rich_text())
	await _wait_process(24)
	_check(guide.get_demo_frame() > 0, "rift_mirror demo advances",
		"frame=%d" % guide.get_demo_frame())
	var registered: Array[String] = MechanicPopup.get_registered_tip_ids()
	_check(registered.has("rift_mirror_tip") and registered.has("rift_core_tip"),
		"both current rift tips are registered", str(registered))


func _test_blocked_while_guide() -> void:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	_check(popup != null, "chapter instantiates the shared MechanicPopup")
	if popup == null:
		return
	_check(_rift.is_mechanic_popup_blocked(), "guide counts as a popup blocker")
	popup.request("rift_mirror_tip")
	await _wait_process(2)
	_check(not popup.is_open(), "blocked guide request does not open a tip")


func _close_guide() -> void:
	var guide: DlcGuide = _rift.get_intro_guide()
	if guide == null or not guide.is_open():
		return
	await _tap_key(KEY_F)
	_check(not guide.is_open(), "F closes the guide")
	_check(not get_tree().paused, "closing the guide unpauses")
	await _wait_physics(8)
	_check(not _rift.is_mechanic_popup_blocked(),
		"normal play no longer blocks the popup")


func _test_pause_page_and_restart() -> void:
	await _wait_process(3)
	_check(_hud.is_player_health_visible(),
		"the fixed health bar is visible before the pause page")
	var pause_started: bool = false
	_push_key(KEY_ESCAPE, true)
	for _index: int in range(6):
		if _rift.is_pause_open():
			pause_started = true
			break
		await get_tree().process_frame
	_check(pause_started, "Esc opens the pause page")
	_push_key(KEY_ESCAPE, false)
	await _wait_process(1)
	_check(get_tree().paused, "pause page pauses the tree")
	_check(_rift.is_mechanic_popup_blocked(), "pause counts as a popup blocker")
	_check(_rift.get_ambience().is_music_paused()
		and not _rift.get_ambience().is_playing(),
		"pause page explicitly pauses the ambience")
	_check(not _hud.is_player_health_visible(),
		"pause page hides the fixed health bar")
	_check(_hud.get_pause_panel_rect()
		== Rect2(Vector2(140.0, 56.0), Vector2(360.0, 236.0)),
		"pause panel is 360x236, centred high")
	_check(_hud.get_pause_title_text() == "已暂停", "pause heading is 已暂停")
	_check(_hud.get_pause_subtitle_text() == "裂隙工坊 · 隐藏关",
		"pause subtitle is the branch chapter name")
	_check(_hud.get_pause_footer_text() == "返回主界面不保存本章进度",
		"pause footnote warns about progress")
	var buttons: Array[PixelMenuButton] = [
		_hud.get_continue_button(), _hud.get_restart_button(),
		_hud.get_title_button(), _hud.get_quit_button(),
		_hud.get_pause_controls_button(), _hud.get_manual_button(),
	]
	var labels: Array[String] = [
		"继续游戏", "重新开始本章", "返回主界面", "退出游戏", "操作", "手册",
	]
	for index: int in range(buttons.size()):
		_check(buttons[index].text == labels[index],
			"pause row %d text" % (index + 1), buttons[index].text)
	await _wait_process(2)
	_check(_hud.get_continue_button().has_focus(),
		"pause focus starts on 继续游戏")
	_check(_hud.is_panel_animating(), "pause page uses the UiReveal entrance")
	await _wait_process(30)
	_check(_hud.get_pause_panel_alpha() > 0.98,
		"pause page finishes its reveal")
	# Down once to 重新开始本章, then Enter.
	_push_key(KEY_DOWN, true)
	await _wait_process(2)
	_push_key(KEY_DOWN, false)
	await _wait_process(2)
	_push_key(KEY_ENTER, true)
	await _wait_process(2)
	_push_key(KEY_ENTER, false)
	await _wait_process(10)
	_check(not _rift.is_pause_open() and not get_tree().paused,
		"重新开始本章 closes the pause page and unpauses")
	_check(_rift.get_ambience().is_playing(), "ambience resumes after restart")
	_check(absf(_player.global_position.x - 40.0) < 2.0,
		"重新开始本章 returns to the start", "x=%.2f" % _player.global_position.x)
	await _wait_process(3)
	_check(_hud.is_player_health_visible(), "the health bar returns after restart")


func _test_boss_status_and_mirror_tip() -> void:
	await _wait_physics(6)
	_check(not _hud.is_boss_visible(), "boss status is hidden before the arena")
	await _place(1250.0, 320.0, true)
	await _wait_until(func() -> bool: return _rift.is_arena_entered(), 90)
	_check(_rift.is_arena_entered(), "player enters the mirror arena")
	_check(_hud.is_boss_visible(), "boss status becomes visible in the arena")
	var status: RiftBossStatus = _hud.get_boss_status()
	_check(status.get_phase_index() == 0 and status.get_core_hp() == 3
		and status.is_gold_intact() and status.is_cyan_intact()
		and status.get_form_text() == "形态 1/3",
		"boss status shows form 1/3, core 3/3, both plates",
		status.get_form_text())
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	var opened: bool = await _wait_popup_open("rift_mirror_tip", 180)
	_check(opened, "the mirror tip opens after the arena opening")
	if not opened:
		return
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	_check(get_tree().paused, "mirror tip pauses the tree")
	_check(_rift.is_mechanic_popup_blocked(), "an open tip counts as blocked")
	_check(popup.get_title_text() == "双面镜", "mirror tip title")
	_check(popup.get_body_text()
		== "金面盘同辉相，青面盘同澜相。\n第二形态起，两面盘各被一只光灵锚定；\n先熄光灵，六秒内用异相攻击击碎。",
		"mirror tip body", popup.get_body_text())
	_check(not _has_bare_key_letter(popup.get_body_text()),
		"mirror tip body has no bare Q/J/E/F", popup.get_body_text())
	_check(popup.get_key_text() == "先熄锚定光灵，六秒内碎面盘，再打核心。",
		"mirror tip key plain", popup.get_key_text())
	_check(popup.get_footer_rich_text().contains("[img=16x16]"),
		"mirror tip footer renders the F keycap", popup.get_footer_rich_text())
	_check(popup.get_demo_id() == "rift_mirror"
		and popup.get_demo_frame_count() == 24,
		"mirror tip plays the rift_mirror demo, 24 frames")
	_check_lines("mirror tip", popup.get_body_text(), popup.get_key_text())
	_check(not popup.get_key_text().contains(" · "),
		"mirror tip key is a natural sentence", popup.get_key_text())
	var closed: bool = await _close_popup()
	_check(closed and not get_tree().paused, "F closes the mirror tip")
	_check(MechanicTips.has_seen("rift_mirror_tip"),
		"mirror tip is remembered for the run")
	popup.request("rift_mirror_tip")
	await _wait_process(4)
	_check(not popup.is_open(), "mirror tip never opens twice")


func _test_failure_line() -> void:
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	_rift.get_boss().set_attacks_enabled(false)
	_rift.get_boss().player_struck.emit(1)
	await _wait_physics(65)
	_rift.get_boss().player_struck.emit(1)
	await _wait_physics(65)
	_rift.get_boss().player_struck.emit(1)
	await _wait_physics(3)
	var began: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 120
	)
	_check(began, "three accepted hits start the failure recovery")
	_check(not _hud.is_player_health_visible(),
		"failure recovery hides the fixed health bar")
	_check(_rift.is_mechanic_popup_blocked(),
		"failure recovery counts as a popup blocker")
	var finished: bool = await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 360
	)
	_check(finished, "failure recovery finishes")
	_check(_hud.get_event_text() == "命数 -1 · 形态 1 开头重来 · 生命值补满",
		"failure line names the spent life and current-form retry",
		_hud.get_event_text())
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)


func _test_core_tip() -> void:
	var boss: RiftMirrorBoss = _rift.get_boss()
	boss.debug_force_defeat()
	var opened: bool = await _wait_popup_open("rift_core_tip", 240)
	_check(opened, "boss defeat opens the core tip")
	if not opened:
		return
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	_check(get_tree().paused, "core tip pauses the tree")
	_check(_rift.is_mechanic_popup_blocked(), "core tip open blocks another popup")
	_check(popup.get_title_text() == "裂隙核心", "core tip title")
	_check(popup.get_body_text()
		== "双面镜碎裂，中央核心失去护持。\n走到尽头的裂隙核心旁，触碰它即可封闭裂隙。",
		"core tip body", popup.get_body_text())
	_check(popup.get_key_text() == "走到尽头，触碰核心封闭裂隙。",
		"core tip key", popup.get_key_text())
	_check(popup.get_demo_id() == "rift_core" and popup.has_demo()
		and popup.get_demo_frame_count() == 24,
		"core tip plays the rift_core demo, 24 frames")
	await _wait_process(24)
	_check(popup.get_demo_frame() > 0, "rift_core demo advances",
		"frame=%d" % popup.get_demo_frame())
	_check_lines("core tip", popup.get_body_text(), popup.get_key_text())
	var closed: bool = await _close_popup()
	_check(closed and not get_tree().paused, "F closes the core tip")
	popup.request("rift_core_tip")
	await _wait_process(4)
	_check(not popup.is_open(), "core tip never opens twice")


func _test_completion_page() -> void:
	await _place(1848.0, 320.0, true)
	var completed: bool = await _wait_until(
		func() -> bool: return _rift.is_completed(), 180
	)
	_check(completed, "touching the core completes the chapter")
	if not completed:
		return
	_check(_rift.is_mechanic_popup_blocked(), "completion counts as a popup blocker")
	_check(not _hud.is_player_health_visible(),
		"completion page hides the fixed health bar")
	_check(not _hud.is_boss_visible(), "completion hides the boss status row")
	_check(_hud.get_completion_panel_rect()
		== Rect2(Vector2(120.0, 75.0), Vector2(400.0, 210.0)),
		"completion panel is 400x210 at (120,75)")
	var expression: RegEx = RegEx.new()
	expression.compile("^裂隙封闭 · 用时 [0-9]{2}:[0-9]{2}$")
	_check(expression.search(_hud.get_completion_text()) != null,
		"completion title keeps 裂隙封闭 · 用时 mm:ss", _hud.get_completion_text())
	_check(_hud.get_completion_subtitle_text() == "双面镜碎裂，裂隙核心重新入睡。",
		"completion subtitle is the mirror epilogue")
	_check(_hud.get_completion_footer_text() == "本章结算 · 暂停菜单可查看操作",
		"completion footnote")
	var primary: PixelMenuButton = _hud.get_completion_primary_button()
	var replay: PixelMenuButton = _hud.get_completion_replay_button()
	_check(primary.text == "返回主界面"
		and primary.position == Vector2(110.0, 86.0)
		and primary.size == Vector2(180.0, 28.0)
		and primary.variant == PixelMenuButton.Variant.STONE,
		"completion primary is 180x28 STONE at (110,86)")
	_check(replay.text == "重玩本关"
		and replay.position == Vector2(110.0, 126.0)
		and replay.size == Vector2(180.0, 24.0)
		and replay.variant == PixelMenuButton.Variant.OPTION,
		"completion secondary is 重玩本关 / 180x24 OPTION at (110,126)")
	await _wait_process(4)
	_check(primary.has_focus(), "completion focus starts on 返回主界面")
	_push_key(KEY_DOWN, true)
	await _wait_process(2)
	_push_key(KEY_DOWN, false)
	await _wait_process(2)
	_check(replay.has_focus(), "Down reaches 重玩本关")
	_push_key(KEY_UP, true)
	await _wait_process(2)
	_push_key(KEY_UP, false)
	await _wait_process(2)
	_check(primary.has_focus(), "Up returns to 返回主界面")

	# Esc opens pause over the completion page and returns to it.
	await _tap_key(KEY_ESCAPE)
	_check(_rift.is_pause_open() and _hud.is_pause_visible(),
		"Esc opens the pause page over completion")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(6)
	_check(not _rift.is_pause_open() and _rift.is_completed()
		and _hud.is_completion_visible(),
		"Esc closes pause back to completion")

	await _tap_key(KEY_E)
	var changed: bool = await _wait_until(
		func() -> bool:
			return get_tree().current_scene != null \
				and get_tree().current_scene != _rift,
		180
	)
	await _wait_process(6)
	var current_path: String = ""
	if get_tree().current_scene != null:
		current_path = get_tree().current_scene.scene_file_path
	_check(changed and current_path == LEVEL_01,
		"E returns to level_01.tscn title", current_path)
	if get_tree().current_scene != null:
		_check(get_tree().current_scene.has_node("StartMenu"),
			"returned scene contains the title menu")
