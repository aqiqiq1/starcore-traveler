extends Node

## 640x360 evidence for the DLC2 three-form / collapse / anchor pass.
##
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://dlc/rift_workshop/tests/capture_dlc2_forms.tscn
##
## Saves to res://dlc/rift_workshop/tests/out/:
##   dlc2_form1.png             form 1: both plates, old HUD row
##   dlc2_attack_wave.png       phase-wave warning: ground band + moon icon
##   dlc2_attack_wave_sun.png   same warning for a 澜相 player: gold + sun icon
##   dlc2_attack_wave_release.png
##   dlc2_attack_sweep.png      sweep release: thin white beam + ground dust
##   dlc2_attack_sweep_warning.png
##   dlc2_attack_summon.png     violet portal rings + chain links
##   dlc2_form_transition.png   plate shards / crack / white core flash
##   dlc2_form2_anchors.png     form 2 plates anchored by two wisps
##   dlc2_anchor_window.png     gold anchor dead, amber 6 s window
##   dlc2_form3.png             cracked mirror, fast orbit, anchors
##   dlc2_defeat_collapse.png   plate shards, broken chains, imploding core
##   dlc2_guide_page3.png       updated guide page 3
##
## Uses the real attack / hit / transition states.  Only face shattering for
## form 2/3 setup uses debug_shatter_face, because this capture is about the
## form presentation, not a fifteen-hit playthrough.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://dlc/rift_workshop/tests/out"

var _rift: RiftWorkshop
var _player: L3Player
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("RIFT_DLC2_CAPTURE saved=%d files=%s" % [
		_saved.size(), ", ".join(_saved)
	])
	get_tree().quit(0)


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


func _wait_ms(duration_ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	_saved.append(name)
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)
	await _wait_process(8)


## The shared guide swaps copy at the midpoint of a 0.12 s crossfade; do not
## press F again or save until that page is settled.
func _wait_page_flip(guide: DlcGuide) -> void:
	if guide == null:
		return
	for _index: int in range(600):
		if not guide.is_page_transitioning():
			return
		await get_tree().process_frame


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


func _jab() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(3)
	_push_key(KEY_J, false)
	await _wait_physics(45)


## Fast third core hit: return as soon as the transition starts so the form
## break can be photographed before it finishes.
func _jab_for_transition() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(3)
	_push_key(KEY_J, false)
	for _index: int in range(30):
		if _rift.get_boss().get_attack_state_name() == "PHASE_CLEAR" \
				or _rift.get_boss().is_defeated():
			return
		await get_tree().physics_frame


func _close_popup_if_open() -> void:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)


func _free_scene() -> void:
	get_tree().paused = false
	get_tree().current_scene = null
	if _rift != null and is_instance_valid(_rift):
		_rift.queue_free()
	_rift = null
	_player = null
	await _wait_process(20)


func _spawn(show_guide: bool) -> void:
	_rift = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	_rift.show_intro_guide = show_guide
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(6)
	await _wait_physics(10)
	_player = _rift.get_player()


func _enter_arena() -> RiftMirrorBoss:
	await _place(1250.0, 320.0, true)
	await _wait_until(func() -> bool: return _rift.is_arena_entered(), 120)
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 200)
	await _wait_process(2)
	await _close_popup_if_open()
	var boss: RiftMirrorBoss = _rift.get_boss()
	await _wait_until(
		func() -> bool:
			return boss.is_active() and boss.get_attack_state_name() != "INTRO", 240
	)
	boss.set_attacks_enabled(false)
	return boss


func _core_hits(boss: RiftMirrorBoss, count: int, transition_last: bool) -> void:
	for index: int in range(count):
		await _place(boss.global_position.x - 20.0, 320.0, true)
		if transition_last and index == count - 1:
			await _jab_for_transition()
		else:
			await _jab()


func _run() -> void:
	await _spawn(false)
	var boss: RiftMirrorBoss = await _enter_arena()

	# --- form 1 -----------------------------------------------------------
	await _place(boss.global_position.x - 76.0, 320.0, false)
	await _save("dlc2_form1.png")
	print("STATE form1 form=%d faces=%d core=%s" % [
		boss.get_phase_number(), boss.get_intact_face_count(),
		str(boss.is_core_exposed())
	])

	# --- phase wave warning + release ------------------------------------
	await _place(boss.global_position.x - 100.0, 320.0, true)
	boss.debug_force_wave()
	await _wait_until(func() -> bool: return boss.is_phase_wave_telegraph_visible(), 60)
	await _wait_ms(300)
	await _save("dlc2_attack_wave.png")
	await _wait_until(func() -> bool: return boss.is_phase_wave_release_visible(), 90)
	await _wait_ms(80)
	await _save("dlc2_attack_wave_release.png")
	await _wait_until(func() -> bool: return boss.get_attack_state_name() == "IDLE", 120)

	# Same telegraph with a 澜相 player: the icon/band turns gold and names 辉相.
	await _place(boss.global_position.x - 100.0, 320.0, false)
	boss.debug_force_wave()
	await _wait_until(func() -> bool: return boss.is_phase_wave_telegraph_visible(), 60)
	await _wait_ms(280)
	await _save("dlc2_attack_wave_sun.png")
	await _wait_until(func() -> bool: return boss.get_attack_state_name() == "IDLE", 160)

	# --- mirror sweep warning + release ----------------------------------
	await _place(boss.global_position.x - 100.0, 320.0, true)
	boss.debug_force_sweep()
	await _wait_until(func() -> bool: return boss.is_sweep_telegraph_visible(), 60)
	await _wait_ms(260)
	await _save("dlc2_attack_sweep_warning.png")
	await _wait_until(func() -> bool: return boss.is_sweep_release_visible(), 90)
	await _wait_ms(60)
	await _save("dlc2_attack_sweep.png")
	await _wait_until(func() -> bool: return boss.get_attack_state_name() == "IDLE", 120)

	# --- summon cast (violet portals + chains) ---------------------------
	await _place(boss.global_position.x - 130.0, 320.0, true)
	boss.debug_force_summon()
	await _wait_until(func() -> bool: return boss.get_attack_state_name() == "SUMMON_CAST", 40)
	await _wait_ms(330)
	await _save("dlc2_attack_summon.png")
	await _wait_until(func() -> bool: return boss.get_attack_state_name() == "IDLE", 120)
	await _wait_process(2)
	await _close_popup_if_open()

	# --- break form 1, photograph the transition -------------------------
	boss.debug_shatter_face(true)
	boss.debug_shatter_face(false)
	await _core_hits(boss, 3, true)
	await _wait_ms(180)
	await _save("dlc2_form_transition.png")
	print("STATE transition state=%s" % boss.get_attack_state_name())
	var form_two: bool = await _wait_until(
		func() -> bool: return boss.get_phase_number() == 2, 180
	)
	var anchors_two: bool = await _wait_until(
		func() -> bool: return boss.get_alive_anchor_count() == 2, 180
	)
	print("STATE form2=%s anchors2=%s" % [str(form_two), str(anchors_two)])

	# --- form 2 anchors ---------------------------------------------------
	await _place(boss.global_position.x - 120.0, 320.0, true)
	await _wait_ms(950)
	await _save("dlc2_form2_anchors.png")
	print("STATE form2 form=%d anchors=%d gold_window=%.2f" % [
		boss.get_phase_number(), boss.get_alive_anchor_count(),
		boss.get_anchor_window_left(true)
	])

	# Kill the gold anchor with a real J, then show the amber window.
	var gold_anchor: RiftPolarityWisp = boss.get_face_anchor(true)
	if gold_anchor != null:
		await _place(gold_anchor.global_position.x - 44.0, 320.0, true)
		await _jab()
	await _wait_process(4)
	await _save("dlc2_anchor_window.png")
	print("STATE anchor_window anchors=%d gold_window=%.2f" % [
		boss.get_alive_anchor_count(), boss.get_anchor_window_left(true)
	])

	# --- form 3 -----------------------------------------------------------
	boss.debug_shatter_face(true)
	boss.debug_shatter_face(false)
	await _core_hits(boss, 3, true)
	var form_three: bool = await _wait_until(
		func() -> bool: return boss.get_phase_number() == 3, 220
	)
	var anchors_three: bool = await _wait_until(
		func() -> bool: return boss.get_alive_anchor_count() == 2, 180
	)
	print("STATE form3=%s anchors3=%s" % [str(form_three), str(anchors_three)])
	await _place(boss.global_position.x - 120.0, 320.0, true)
	await _wait_ms(1000)
	await _save("dlc2_form3.png")

	# --- defeat collapse --------------------------------------------------
	boss.debug_force_defeat()
	await _wait_ms(650)
	await _save("dlc2_defeat_collapse.png")
	print("STATE collapse t=%.2f/%.2f" % [
		boss.get_defeat_time(), boss.get_defeat_collapse_time()
	])
	await _wait_ms(380)
	await _save("dlc2_defeat_flash.png")
	await _free_scene()
	await _wait_ms(350)

	# --- updated guide page 3 --------------------------------------------
	await _spawn(true)
	await _wait_process(20)
	await _tap_key(KEY_F)
	await _wait_page_flip(_rift.get_intro_guide())
	await _tap_key(KEY_F)
	await _wait_page_flip(_rift.get_intro_guide())
	await _wait_process(10)
	await _save("dlc2_guide_page3.png")
	print("STATE guide page=%d title=%s key=%s" % [
		_rift.get_intro_guide().get_page_index() + 1,
		_rift.get_intro_guide().get_title_text(),
		_rift.get_intro_guide().get_key_text()
	])
	await _free_scene()
	await _wait_ms(350)
