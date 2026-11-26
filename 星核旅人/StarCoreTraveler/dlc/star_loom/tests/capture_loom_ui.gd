extends Node

## 640x360 third-round UI evidence for 星核织机.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/star_loom/tests/capture_loom_ui.tscn
##
## Saves to res://dlc/star_loom/tests/out/:
##   loom_tip_fire.png    first stage-2 fire warning, shared MechanicPopup
##   loom_pause.png       360x236 four-button pause page
##   loom_completion.png  400x210 completion page with both buttons
##
## Every frame is the live 640x360 viewport.  The fire popup is opened by the
## chapter's real stage-2 telegraph trigger, and the completion page follows
## three real J core hits.  The two guide pages are captured separately by
## capture_guide_city.tscn.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://dlc/star_loom/tests/out"

var _loom: StarLoom
var _player: L3Player
var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	MechanicTips.reset_for_test()
	MechanicPopup.reset_registered_tips_for_test()
	await _run()
	await _cleanup()
	print("LOOM_UI_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
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


func _real_key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_key(code: Key) -> void:
	_real_key(code, true)
	await _wait_physics(2)
	_real_key(code, false)
	await _wait_physics(2)


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_loom.get_camera().reset_smoothing()
	await _wait_physics(3)
	await _wait_process(8)


func _swing() -> void:
	_real_key(KEY_J, true)
	await _wait_physics(8)
	_real_key(KEY_J, false)
	await _wait_until(
		func() -> bool:
			return not _player.is_attacking() and _player.get_attack_cooldown() <= 0.0,
		120
	)


func _jump_swing() -> void:
	Input.action_press(&"jump")
	await _wait_physics(8)
	await _swing()
	Input.action_release(&"jump")
	await _wait_until(func() -> bool: return _player.is_on_floor(), 90)


func _cause_game_over() -> bool:
	await _place(420.0, 320.0, false)
	await _wait_physics(50)
	for index: int in range(3):
		_loom.debug_apply_player_hit()
		await _wait_physics(2)
		if index < 2:
			await _wait_until(
				func() -> bool: return _loom.get_damage_immunity_left() <= 0.0,
				120
			)
	return await _wait_until(func() -> bool: return _loom.is_game_over(), 240)


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		print("LOOM_UI_CAPTURE missing scene")
		return
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	_loom.show_intro_cinematic = false
	get_tree().root.add_child(_loom)
	get_tree().current_scene = _loom
	await _wait_process(6)
	await _wait_physics(10)
	_player = _loom.get_player()
	var popup: MechanicPopup = _loom.get_mechanic_popup()

	# 1. Fire popup from the first stage-2 fire telegraph.  Entering the hall
	# and exposing the core no longer open their own popups.
	_loom.debug_set_stage(2)
	_loom.debug_set_attacks_enabled(true)
	_loom.debug_set_boss_grace(0.0)
	_loom.debug_clear_hazards()
	_loom.debug_force_attack("fire")
	var fire_open: bool = await _wait_until(
		func() -> bool: return popup != null and popup.is_open(), 60
	)
	await _wait_process(14)
	if fire_open:
		await _save("loom_tip_fire.png")
		await _tap_key(KEY_F)
		await _wait_until(func() -> bool: return not popup.is_open(), 60)

	# 2. Pause page after a clean resume.
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	await _wait_physics(4)
	await _tap_key(KEY_ESCAPE)
	await _wait_process(20)
	await _save("loom_pause.png")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(12)

	# 3. Game over page: one heart left, then three real accepted hits.
	_loom.debug_set_stage(2)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	_loom.debug_set_lives(1)
	if await _cause_game_over():
		await _wait_process(24)
		await _save("loom_game_over.png")
		await _tap_key(KEY_R)
		await _wait_process(12)

	# 4. Completion page after three real jumping J core hits in stage 3.
	_loom.debug_set_stage(3)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_set_boss_grace(0.0)
	_loom.debug_clear_hazards()
	_loom.debug_expose_core()
	await _wait_physics(3)
	for _index: int in range(3):
		await _place(660.0, 320.0, not _loom.get_core().get_phase())
		await _jump_swing()
	await _wait_until(func() -> bool: return _loom.is_completed(), 180)
	await _wait_process(24)
	await _save("loom_completion.png")


func _cleanup() -> void:
	get_tree().paused = false
	if _loom != null and is_instance_valid(_loom):
		_loom.queue_free()
		_loom = null
	await _wait_process(8)
