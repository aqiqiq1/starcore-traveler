extends Node

## 640x360 visual evidence for the 2026-11-26 rework 2.
##
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##     res://dlc/rift_workshop/tests/capture_rework2.tscn
##
## Saves to res://dlc/rift_workshop/tests/out/:
##   rework2_boss_faces.png   both face plates intact + boss status row
##   rework2_boss_core.png    both plates broken, central core exposed
##   rework2_boss_wave.png    phase-wave warning ring
##   rework2_q_denied.png     locked-Q cross icon above the head
##   rework2_crystal.png      arena inversion crystal + HUD phase
##   rework2_low_bridge.png   missing deck under the low truss
##   health_bar_hit.png       fixed two-segment bar after one accepted hit
##   rework2_guide_page1.png  guide page 1 copy
##   rework2_guide_page3.png  guide page 3 double mirror + demo

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://dlc/rift_workshop/tests/out"

var _rift: RiftWorkshop
var _player: L3Player
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("RIFT_REWORK2_CAPTURE saved=%d files=%s" % [
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


func _spawn(show_guide: bool) -> void:
	_rift = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	_rift.show_intro_guide = show_guide
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(6)
	await _wait_physics(10)
	_player = _rift.get_player()


func _free_scene() -> void:
	get_tree().paused = false
	get_tree().current_scene = null
	if _rift != null and is_instance_valid(_rift):
		_rift.queue_free()
	_rift = null
	_player = null
	await _wait_process(20)


func _close_popup_if_open() -> void:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)


func _run() -> void:
	# --- gameplay shots ---------------------------------------------------
	await _spawn(false)
	# Locked Q: the cross icon is short-lived, so save immediately.
	await _place(300.0, 320.0, true)
	Input.action_press(&"polarity")
	await _wait_physics(2)
	Input.action_release(&"polarity")
	await _wait_process(2)
	await _save("rework2_q_denied.png")
	print("STATE q_denied visible=%s count=%d" % [
		str(_rift.get_hud().is_q_denied_visible()), _rift.get_q_denial_count()
	])
	await _wait_ms(1000)

	# Low beam / missing BridgeA.
	await _place(650.0, 280.0, false)
	await _save("rework2_low_bridge.png")
	print("STATE low_bridge bridge_solid=%s y=%.1f" % [
		str(_rift.get_bridge_a().is_solid()), _player.global_position.y
	])

	# Arena: clear the opening and the mirror tip, then hold the boss.
	await _place(1250.0, 320.0, true)
	await _wait_until(func() -> bool: return _rift.is_arena_entered(), 90)
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	await _wait_process(2)
	await _close_popup_if_open()
	var boss: RiftMirrorBoss = _rift.get_boss()
	await _wait_until(
		func() -> bool:
			return boss.is_active() and boss.get_attack_state_name() != "INTRO", 240
	)
	boss.set_attacks_enabled(false)
	await _place(boss.global_position.x - 78.0, 320.0, false)
	await _save("rework2_boss_faces.png")
	print("STATE boss_faces phase=%d faces=%d core=%s" % [
		boss.get_phase_number(), boss.get_intact_face_count(),
		str(boss.is_core_exposed())
	])

	# Crystal shot (left crystal, still cooling from the touch).  Step off to
	# 1290 so the crystal is visible beside the body, not hidden by it.
	await _place(1320.0, 320.0, true)
	await _place(1290.0, 320.0, false)
	# Let the 2 s cooldown finish and the event line expire; the shot then
	# shows a ready crystal beside the player, not a dim cooling stub.
	await _wait_ms(2400)
	await _place(1290.0, 320.0, true)
	await _save("rework2_crystal.png")
	print("STATE crystal flips=%d cooldown=%.2f phase=%s" % [
		_rift.get_crystal_left().get_flip_count(),
		_rift.get_crystal_left().get_cooldown_left(),
		_rift.get_hud().get_phase_icon_kind()
	])

	# Core exposed.
	boss.debug_shatter_face(true)
	boss.debug_shatter_face(false)
	await _place(boss.global_position.x - 20.0, 320.0, true)
	await _wait_process(8)
	await _save("rework2_boss_core.png")
	print("STATE boss_core faces=%d core=%s hp=%d" % [
		boss.get_intact_face_count(), str(boss.is_core_exposed()),
		boss.get_core_hp()
	])

	# Phase wave warning (fresh scene state: reset the boss so the plates are
	# back, then force the warning).
	_rift.get_boss().reset_full()
	_rift.get_boss().set_player_target(_player)
	_rift.get_boss().begin_fight()
	await _place(1400.0, 320.0, true)
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	await _wait_process(2)
	await _close_popup_if_open()
	await _wait_until(
		func() -> bool:
			return boss.is_active() and boss.get_attack_state_name() != "INTRO", 240
	)
	boss.set_attacks_enabled(false)
	await _wait_ms(2100)
	boss.debug_force_wave()
	await _wait_until(func() -> bool: return boss.is_phase_wave_telegraph_visible(), 60)
	await _wait_ms(600)
	await _save("rework2_boss_wave.png")
	print("STATE boss_wave warning=%s" % str(boss.is_phase_wave_telegraph_visible()))
	# One real accepted boss hit: the shared bar drops to one of two segments
	# at its fixed lower-left position.  Saved before the scene is freed.
	boss.player_struck.emit(1)
	await _wait_process(4)
	await _save("health_bar_hit.png")
	print("STATE health_bar current=%d max=%d pos=%s" % [
		_rift.get_hud().get_player_health_bar().get_current(),
		_rift.get_hud().get_player_health_bar().get_max(),
		str(_rift.get_hud().get_player_health_rect().position),
	])
	await _free_scene()
	await _wait_ms(350)

	# --- guide shots ------------------------------------------------------
	await _spawn(true)
	await _wait_process(20)
	await _save("rework2_guide_page1.png")
	await _tap_key(KEY_F)
	await _tap_key(KEY_F)
	await _wait_process(10)
	await _save("rework2_guide_page3.png")
	print("STATE guide page=%d title=%s demo=%s frames=%d" % [
		_rift.get_intro_guide().get_page_index() + 1,
		_rift.get_intro_guide().get_title_text(),
		_rift.get_intro_guide().get_demo_id(),
		_rift.get_intro_guide().get_demo_frame_count()
	])
	await _free_scene()
	await _wait_ms(350)
