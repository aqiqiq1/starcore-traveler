extends Node

## Teaching-layer test for the 2026-11-26 rift-workshop rework 2.
##
##   ... --headless --path . res://dlc/rift_workshop/tests/teaching_test.tscn
##
## Focus: the three-page guide, the removed legend, the 20 px phase icon, the
## locked-Q refusal presentation, the arena crystals, the mirror tip and the
## boss status row.  Gameplay hit resolution stays in mechanics_test.tscn.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

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
	print("RIFT_TEACHING_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_ms(duration_ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


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


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)


func _close_popup_if_open() -> bool:
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
	get_tree().current_scene = null
	if _rift != null and is_instance_valid(_rift):
		_rift.queue_free()
	await _wait_process(20)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


# --- test ------------------------------------------------------------------

func _run() -> void:
	MechanicTips.reset_for_test()
	MechanicPopup.reset_registered_tips_for_test()
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_check(packed != null, "rift scene loads")
	if packed == null:
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(8)
	await _wait_physics(6)
	_player = _rift.get_player()
	_hud = _rift.get_hud()
	_check(_player != null and _hud != null, "player / HUD exist")
	var guide: DlcGuide = _rift.get_intro_guide()
	_check(guide != null and guide.is_open(), "guide opens on a normal entry")
	_check(get_tree().paused, "opening the guide pauses the tree")
	_check(_rift.get_ambience().is_playing(),
		"ambience keeps playing under the guide")
	_check(_hud.get_phase_icon_kind() == "sun"
		and not _hud.is_affinity_text_visible(),
		"HUD shows the sun icon without 辉相 text")
	_check(_hud.get_phase_icon().size == Vector2(20.0, 20.0),
		"phase icon is 20 x 20")
	_check(not _hud.has_element_legend(), "no permanent legend row")
	_check(guide.get_page_count() == 3, "guide has 3 pages",
		str(guide.get_page_count()))
	_check(guide.get_title_text() == "裂隙回廊", "page 1 is 裂隙回廊")
	_check(guide.get_body_text().contains("无法自由换相"),
		"page 1 states free phase switching is locked",
		guide.get_body_text())
	_check(guide.get_key_text() == "穿过紫幕翻相，同相才能过门。",
		"page 1 key is a natural sentence", guide.get_key_text())
	_check(not _has_bare_key_letter(guide.get_title_text())
		and not _has_bare_key_letter(guide.get_body_text()),
		"page 1 title/body have no bare Q/J/E/F", guide.get_body_text())
	await _tap_key(KEY_F)
	_check(guide.get_title_text() == "相性光桥", "page 2 is 相性光桥")
	_check(guide.get_body_text().contains("先用攻击熄灭桥上的光灵"),
		"page 2 teaches the phase-free bridge kill", guide.get_body_text())
	_check(not guide.get_key_text().contains(" · "),
		"page 2 key is a natural sentence", guide.get_key_text())
	_check(not _has_bare_key_letter(guide.get_body_text()),
		"page 2 body has no bare Q/J/E/F", guide.get_body_text())
	await _tap_key(KEY_F)
	_check(guide.get_title_text() == "双面镜", "page 3 is the double mirror")
	_check(guide.get_body_text().contains("异相攻击")
		and guide.get_body_text().contains("光灵锚定")
		and guide.get_body_text().contains("六秒"),
		"page 3 teaches opposite-phase plates, anchors and the 6 s window",
		guide.get_body_text())
	_check(not _has_bare_key_letter(guide.get_body_text()),
		"page 3 body has no bare Q/J/E/F", guide.get_body_text())
	_check(guide.get_footer_rich_text().contains("[img=16x16]"),
		"guide footer renders the F keycap", guide.get_footer_rich_text())
	_check(guide.get_footer_text() == "F 下一页 · 长按空格 跳过"
		or guide.get_footer_text() == "F 关闭 · 长按空格 跳过",
		"guide footer plain keeps the F name", guide.get_footer_text())
	_check(guide.get_demo_id() == "rift_mirror"
		and guide.get_demo_frame_count() == 24,
		"page 3 uses the 24-frame rift_mirror demo")
	_check(not guide.get_key_text().contains(" · "),
		"page 3 key is a natural sentence", guide.get_key_text())
	for page_index: int in range(3):
		var body: String = guide.get_body_text()
		var lines: PackedStringArray = body.split("\n")
		_check(lines.size() <= 3, "page %d has at most 3 lines" % (page_index + 1))
		var fits: bool = true
		for line: String in lines:
			if _display_width(line) > 21.001:
				fits = false
		_check(fits, "page %d body lines fit 21 cells" % (page_index + 1))
		_check(_display_width(guide.get_key_text()) <= 21.001,
			"page %d key fits 21 cells" % (page_index + 1))
		if page_index < 2:
			await _tap_key(KEY_F)
	await _tap_key(KEY_F)
	_check(not guide.is_open() and not get_tree().paused,
		"F on page 3 closes the guide and unpauses")
	_check(_rift.get_ambience().is_playing(),
		"ambience is still playing after the guide")
	await _wait_physics(8)

	# Locked Q presentation.
	var before: bool = _player.is_positive()
	Input.action_press(&"polarity")
	await _wait_physics(2)
	Input.action_release(&"polarity")
	await _wait_physics(3)
	_check(_player.is_positive() == before, "Q does not change the phase")
	_check(_hud.is_q_denied_visible(), "the cross-Q icon appears above the head")
	_check(_rift.get_q_denial_count() == 1, "the refusal is counted")
	_check(int(_rift.get_node("Audio").call("get_deny_play_count")) == 1,
		"the refusal sound plays once")
	await _wait_physics(60)
	_check(not _hud.is_q_denied_visible(), "the cross-Q icon hides again")

	# Arena entry / mirror tip.
	await _place(1250.0, 320.0, true)
	await _wait_until(func() -> bool: return _rift.is_arena_entered(), 90)
	_check(_rift.is_arena_entered(), "player enters the arena")
	_check(not _has_bare_key_letter(_hud.get_objective_text()),
		"HUD objective has no bare Q/J/E/F", _hud.get_objective_text())
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	var opened: bool = await _wait_until(
		func() -> bool:
			var popup: MechanicPopup = _rift.get_mechanic_popup()
			return popup.is_open() and popup.get_current_id() == "rift_mirror_tip",
		180
	)
	_check(opened, "the mirror teaching tip opens after the opening")
	if opened:
		_check(get_tree().paused, "mirror tip pauses the tree")
		_check(_rift.get_ambience().is_playing(),
			"ambience keeps playing under the mirror tip")
		_check(not _hud.is_player_health_visible(),
			"mirror tip hides the fixed health bar")
		var popup: MechanicPopup = _rift.get_mechanic_popup()
		_check(popup.get_key_text() == "先熄锚定光灵，六秒内碎面盘，再打核心。",
			"mirror tip key plain is natural", popup.get_key_text())
		_check(not _has_bare_key_letter(popup.get_body_text()),
			"mirror tip body has no bare Q/J/E/F", popup.get_body_text())
		_check(popup.get_footer_rich_text().contains("[img=16x16]"),
			"mirror popup footer renders the F keycap",
			popup.get_footer_rich_text())
		var closed: bool = await _close_popup_if_open()
		_check(closed and not get_tree().paused, "F closes the mirror tip")
		await _wait_process(3)
		_check(_hud.is_player_health_visible(),
			"the fixed health bar returns after the tip")
	var boss: RiftMirrorBoss = _rift.get_boss()
	boss.set_attacks_enabled(false)

	# Arena crystal is the player's own phase control.  It sits inside the
	# arena, so this runs after the arena tip has been closed.
	await _place(1320.0, 320.0, true)
	await _wait_physics(4)
	_check(not _player.is_positive(), "left crystal flips the player")
	_check(_rift.get_crystal_left().get_cooldown_left() > 1.0,
		"left crystal is cooling")
	_check(_hud.get_phase_icon_kind() == "moon",
		"HUD phase icon follows the crystal flip")
	await _place(1270.0, 320.0, false)
	await _wait_ms(2200)
	await _place(1320.0, 320.0, false)
	await _wait_physics(6)
	_check(_rift.get_crystal_left().get_flip_count() == 2,
		"the crystal can be touched again after 2 s",
		str(_rift.get_crystal_left().get_flip_count()))

	_check(_hud.is_boss_visible(), "boss status row is visible in the arena")
	var status: RiftBossStatus = _hud.get_boss_status()
	_check(status.get_phase_index() == 0 and status.get_core_hp() == 3
		and status.is_gold_intact() and status.is_cyan_intact()
		and status.get_form_text() == "形态 1/3",
		"boss status shows form 1/3, core 3/3, both plates",
		status.get_form_text())
	boss.debug_shatter_face(true)
	await _wait_physics(3)
	_check(not status.is_gold_intact() and status.is_cyan_intact()
		and not status.is_core_exposed(),
		"boss status marks one broken plate and the still-shielded core")
	boss.debug_shatter_face(false)
	await _wait_physics(3)
	_check(status.is_core_exposed()
		and status.get_core_hp() == 3,
		"boss status shows the exposed core at 3/3")

	# Pause still hides the fixed health bar and pauses the ambience.
	boss.set_attacks_enabled(false)
	await _tap_key(KEY_ESCAPE)
	await _wait_process(3)
	_check(_rift.is_pause_open(), "Esc opens the pause page")
	_check(not _hud.is_player_health_visible(),
		"pause page hides the fixed health bar")
	_check(_hud.get_player_health_rect().position == Vector2(14.0, 324.0),
		"bar stays at (14,324) through pause",
		str(_hud.get_player_health_rect()))
	_check(_rift.get_ambience().is_music_paused(),
		"pause page pauses the ambience")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(3)
	_check(not _rift.is_pause_open() and not get_tree().paused,
		"Esc closes the pause page")
