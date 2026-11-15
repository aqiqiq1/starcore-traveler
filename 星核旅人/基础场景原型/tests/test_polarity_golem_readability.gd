extends Node

## Minimal readability/rubble smoke for the latest review.
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/test_polarity_golem_readability.tscn
##
## Scope: parse/load, authentic die frame 11 held during RUBBLE, no custom
## rubble drawing, pause freeze, reversed reassembly to full HP, R restore.
## The wait is shortened to 0.6 s in test setup and logged; production stays 8 s.

const EXPERIMENT_SCENE: PackedScene = preload(
	"res://scenes/experiments/polarity_golem_experiment.tscn"
)

var _game
var _player
var _golem
var _hud
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_game = EXPERIMENT_SCENE.instantiate()
	add_child(_game)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = _game.get_player()
	_golem = _game.get_golem()
	_hud = _game.get_hud()

	_log("=== Polarity Golem readability / rubble smoke ===")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"], DisplayServer.get_name()
	])
	await _test_load_and_text()
	await _test_rubble_frame_pause_and_reassembly()
	await _finish()


func _test_load_and_text() -> void:
	_section("1. PARSE / LOAD / TEXT")
	_check(_game != null and _player != null and _golem != null and _hud != null,
		"experiment scene and nodes load")
	_check(not _golem.has_method("_draw_rubble"),
		"custom rubble drawing is removed, not recoloured")
	_check(_golem.get_head_overlay_z_index() >= 10,
		"head readout is on a higher-z child above the player",
		"z=%d" % _golem.get_head_overlay_z_index())
	_check(_hud.get_native_font_size() == 12,
		"HUD native Fusion Pixel size is 12", str(_hud.get_native_font_size()))
	var sizes: Array[int] = _hud.get_label_font_sizes()
	var min_size: int = 999
	var max_size: int = 0
	for size_value: int in sizes:
		min_size = mini(min_size, size_value)
		max_size = maxi(max_size, size_value)
	_log("  HUD label sizes: %s" % str(sizes))
	_check(sizes.size() > 0 and min_size >= 12 and max_size <= 24,
		"no HUD label is shrunk to 7-10 px", "min=%d max=%d" % [min_size, max_size])
	_check(
		_hud.get_enemy_text().contains("辉相")
		and not _hud.get_enemy_text().contains("◇")
		and not _hud.get_enemy_text().contains("◆"),
		"enemy HUD uses 辉相 + without diamonds", _hud.get_enemy_text())
	_check(
		_hud.get_player_text().contains("辉相")
		and not _hud.get_player_text().contains("金"),
		"player HUD uses the same 辉相 naming", _hud.get_player_text())
	_check(_golem.get_head_tag_text() == "辉相 +",
		"active head tag is the readable 辉相 +", _golem.get_head_tag_text())
	_check(absf(_golem.get_scatter_wait_setting() - 8.0) < 0.001,
		"production wait remains 8.0 s",
		"%.1fs" % _golem.get_scatter_wait_setting())
	await _step(2)


func _test_rubble_frame_pause_and_reassembly() -> void:
	_section("2. DIE FRAME 11 / PAUSE / REASSEMBLE")
	_game.reset_experiment()
	await _step(3)
	_golem.set_scatter_wait_time(0.6)
	_log("  TEST SETUP: scatter wait shortened to 0.6 s (production default 8.0 s)")
	_golem.debug_set_hp(1)
	_player.global_position = Vector2(300.0, 288.0)
	_player.velocity = Vector2.ZERO
	_golem.global_position = Vector2(350.0, 288.0)
	await _step(3)

	_key_down(KEY_J)
	await _step(14)
	_key_up(KEY_J)
	_check(_golem.get_hp() == 0 and _golem.get_state_name() == "SCATTERING",
		"real J kill starts the die/scatter sequence",
		"%s hp=%d" % [_golem.get_state_name(), _golem.get_hp()])

	var reached_rubble: bool = false
	for _i: int in range(70):
		await _step(1)
		if _golem.get_state_name() == "RUBBLE":
			reached_rubble = true
			break
	_check(reached_rubble, "die sequence reaches RUBBLE", _golem.get_state_name())
	var die_path: String = _golem.get_sprite_texture_path()
	_check(_golem.get_sprite_visible(), "RUBBLE keeps the die sprite visible",
		str(_golem.get_sprite_visible()))
	_check(die_path.ends_with("golem_1_die.png"),
		"RUBBLE texture is the source die sheet", die_path)
	_check(_golem.get_sprite_frame() == 11,
		"RUBBLE holds the last non-empty die frame 11",
		"frame=%d" % _golem.get_sprite_frame())
	var scatter_x: float = _golem.global_position.x
	var tag: String = _golem.get_head_tag_text()
	_check(tag.ends_with("秒后重组") and not tag.contains("碎石"),
		"head tag reads N.N秒后重组", tag)
	_log("  RUBBLE: visible=%s frame=%d texture=%s head=%s remaining=%.2fs" % [
		str(_golem.get_sprite_visible()), _golem.get_sprite_frame(), die_path,
		tag, _golem.get_scatter_wait_remaining()
	])

	# Pause while the authentic die frame is held.
	await _tap_key_process(KEY_ESCAPE)
	_check(_game.is_paused() and _hud.is_pause_visible(),
		"Esc pauses the rubble wait")
	var frozen_frame: int = _golem.get_sprite_frame()
	var frozen_visible: bool = _golem.get_sprite_visible()
	var frozen_texture: String = _golem.get_sprite_texture_path()
	var frozen_wait: float = _golem.get_scatter_wait_remaining()
	await _step(30)
	_check(
		_golem.get_sprite_frame() == frozen_frame
		and _golem.get_sprite_visible() == frozen_visible
		and _golem.get_sprite_texture_path() == frozen_texture,
		"pause freezes the die frame/texture/visibility",
		"frame=%d visible=%s" % [_golem.get_sprite_frame(), str(_golem.get_sprite_visible())])
	_check(absf(_golem.get_scatter_wait_remaining() - frozen_wait) < 0.02,
		"pause freezes the countdown",
		"%.2f -> %.2f" % [frozen_wait, _golem.get_scatter_wait_remaining()])
	await _tap_key_process(KEY_ESCAPE)
	_check(not _game.is_paused(), "Esc resumes after the freeze check")

	# Reversed reassembly: observe descending die frames, then full HP active.
	var reassemble_seen: bool = false
	var min_frame: int = 99
	var max_frame: int = -1
	var became_active: bool = false
	for _i: int in range(220):
		await _step(1)
		var state_name: String = _golem.get_state_name()
		if state_name == "REASSEMBLING":
			reassemble_seen = true
			min_frame = mini(min_frame, _golem.get_sprite_frame())
			max_frame = maxi(max_frame, _golem.get_sprite_frame())
		elif state_name == "ACTIVE":
			became_active = true
			break
	_check(reassemble_seen, "reassembly state is observed")
	_check(max_frame <= 11 and min_frame >= 0 and min_frame < 11,
		"reassembly plays reversed die frames 11..0",
		"min=%d max=%d" % [min_frame, max_frame])
	_check(became_active, "reassembly returns to ACTIVE", _golem.get_state_name())
	_check(_golem.get_hp() == 3, "reassembly restores full 3 HP", "hp=%d" % _golem.get_hp())
	_check(_golem.get_sprite_visible()
		and _golem.get_sprite_texture_path().ends_with("golem_1_idle.png"),
		"active golem is visible with the idle texture",
		_golem.get_sprite_texture_path())
	_check(absf(_golem.global_position.x - scatter_x) < 1.0,
		"reassembly stays at the scatter spot",
		"%.1f vs %.1f" % [_golem.global_position.x, scatter_x])
	_check(_golem.get_head_tag_text() == "辉相 +",
		"active head tag returns to 辉相 +", _golem.get_head_tag_text())

	# R restores spawn/polarity/HP and the active readout.
	_key_down(KEY_R)
	await _step(1)
	_key_up(KEY_R)
	await _step(4)
	_check(not _game.is_paused(), "R leaves the experiment unpaused")
	_check(_golem.get_state_name() == "ACTIVE" and _golem.get_hp() == 3,
		"R restores the golem to active full HP",
		"%s hp=%d" % [_golem.get_state_name(), _golem.get_hp()])
	_check(_golem.global_position.is_equal_approx(_game.get_golem_spawn_position()),
		"R restores the golem spawn", str(_golem.global_position))
	_check(_player.global_position.is_equal_approx(_game.get_spawn_position()),
		"R restores the player spawn", str(_player.global_position))
	_check(_golem.get_head_tag_text() == "辉相 +",
		"R restores the readable head tag", _golem.get_head_tag_text())


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key_down(key: Key) -> void:
	_send_key(key, true)


func _key_up(key: Key) -> void:
	_send_key(key, false)


func _tap_key_process(key: Key) -> void:
	_key_down(key)
	await get_tree().process_frame
	await get_tree().process_frame
	_key_up(key)
	await get_tree().process_frame


func _step(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _section(title: String) -> void:
	_log("")
	_log("--- %s ---" % title)


func _check(condition: bool, label: String, details: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, ("  (" + details + ")") if details != "" else ""])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, ("  (" + details + ")") if details != "" else ""])
		printerr("[FAIL] %s %s" % [label, details])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	if get_tree().paused:
		get_tree().paused = false
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count])
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/polarity_golem_readability_smoke.log", FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
