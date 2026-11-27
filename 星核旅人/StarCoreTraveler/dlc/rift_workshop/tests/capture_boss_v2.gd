extends Node

## 640x360 evidence for the DLC2 mirror v2 pass.
##
## Run WITHOUT --headless:
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/rift_workshop/tests/capture_boss_v2.tscn
##
## Saves to res://screenshots/rift_boss_v2_20261127/:
##   01_hud_health3_lives3.png   3-cell health bar + 3 hearts under the boss bar
##   02_clone_warning.png        form-2 double, 0.6 s low-line warning
##   03_clone_release.png        the same double releasing its single sweep
##   04_homing_charge.png        form-3 core charge / floor sight line
##   05_homing_light.png         the single 60 px/s tracking orb in flight
##   06_life_lost_retry.png      lives 2, current form replayed, health refilled
##   07_game_over.png            zero lives, star-loom-style page
##
## Uses the real boss states and real HUD.  Form selection uses debug_set_phase;
## life loss uses the real retry transition.  No screenshot is a mock-up.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://screenshots/rift_boss_v2_20261127"

var _rift: RiftWorkshop
var _player: L3Player
var _boss: RiftMirrorBoss
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("RIFT_BOSS_V2_CAPTURE saved=%d files=%s" % [
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


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)
	await _wait_process(8)


func _close_popup_if_open() -> void:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)


func _wait_for_boss_active(max_frames: int = 300) -> bool:
	for _index: int in range(max_frames):
		if _boss.is_active() and _boss.get_attack_state_name() != "INTRO":
			return true
		await get_tree().physics_frame
	return false


func _force_hit() -> void:
	_rift.set("_damage_immunity_left", 0.0)
	_boss.player_struck.emit(1)
	await _wait_physics(3)


func _spend_health() -> void:
	for _index: int in range(3):
		await _force_hit()


func _wait_for_retry() -> bool:
	var began: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 120
	)
	if not began:
		return false
	return await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 420
	)


func _clear_anchors_for_shot() -> void:
	# The capture is about the double / light, so the form's anchor wisps are
	# removed for a clean silhouette.  The boss keeps its real phase and HUD.
	_rift.call("_clear_boss_wisps")
	_boss.clear_anchors()
	_rift.call("_sync_boss_hud")
	await _wait_physics(4)


func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if packed == null:
		printerr("RIFT scene missing")
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(6)
	await _wait_physics(8)
	_player = _rift.get_player()
	_boss = _rift.get_boss()

	await _place(1400.0, 320.0, true)
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 240)
	await _close_popup_if_open()
	await _wait_for_boss_active()
	_boss.set_attacks_enabled(false)
	_rift.call("_sync_boss_hud")
	await _wait_process(10)
	await _save("01_hud_health3_lives3.png")

	# --- form 2: mirror double ------------------------------------------
	_boss.debug_set_phase(1)
	await _wait_physics(8)
	await _clear_anchors_for_shot()
	await _place(1360.0, 320.0, true)
	_boss.debug_force_clone()
	await _wait_until(
		func() -> bool: return _boss.get_attack_state_name() == "CLONE_WARN", 40
	)
	await _wait_physics(18)
	await _save("02_clone_warning.png")
	await _wait_until(
		func() -> bool: return _boss.get_clone_release_count() > 0, 90
	)
	await _wait_physics(2)
	await _save("03_clone_release.png")
	await _wait_until(
		func() -> bool: return _boss.get_attack_state_name() == "IDLE", 90
	)

	# --- form 3: tracking mirror light ----------------------------------
	_boss.debug_set_phase(2)
	await _wait_physics(8)
	await _clear_anchors_for_shot()
	await _place(1360.0, 320.0, true)
	_boss.debug_force_homing()
	await _wait_until(func() -> bool: return _boss.is_homing_charging(), 40)
	await _wait_physics(18)
	await _save("04_homing_charge.png")
	await _wait_until(func() -> bool: return _boss.is_homing_active(), 90)
	await _wait_physics(84)
	print("STATE homing active=%s pos=%s draw=%d ground=%d player=%d cam=%s" % [
		str(_boss.is_homing_active()), str(_boss.get_homing_position()),
		_boss.get_homing_orb_draw_count(), _boss.get_homing_ground_hit_count(),
		_boss.get_homing_hit_player_count(), str(_rift.get_camera().get_screen_center_position())
	])
	await _save("05_homing_light.png")
	# Let the orb resolve so the life test starts from a clean arena.
	await _wait_until(func() -> bool: return not _boss.is_homing_active(), 360)

	# --- one life lost: current form replayed, health refilled ----------
	_boss.debug_set_phase(1)
	await _wait_physics(8)
	await _clear_anchors_for_shot()
	await _place(1300.0, 320.0, true)
	_boss.set_attacks_enabled(false)
	await _spend_health()
	await _wait_for_retry()
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 240)
	await _wait_for_boss_active()
	_boss.set_attacks_enabled(false)
	_rift.call("_sync_boss_hud")
	await _place(1390.0, 320.0, true)
	await _wait_process(12)
	await _save("06_life_lost_retry.png")

	# --- two more lives -> game over ------------------------------------
	_boss.debug_set_phase(1)
	await _wait_physics(8)
	_boss.set_attacks_enabled(false)
	await _spend_health()
	await _wait_for_retry()
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 240)
	await _wait_for_boss_active()
	_boss.set_attacks_enabled(false)
	await _spend_health()
	await _wait_until(func() -> bool: return _rift.is_game_over(), 420)
	await _wait_process(18)
	await _save("07_game_over.png")
