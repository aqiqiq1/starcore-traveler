extends Node

## Focused cleanup/gate check:
##  - L2 world labels removed; HUD short objective/core; no permanent recovery
##    line; central prompt only for a real E action; F GuideEcho/feedback/pause.
##  - L1 default gate FX appears only in interactive gameplay; menu/opening,
##    R intro, pause freeze, completion hide; default LevelExit sheet ready.
##  - L2 real gate open/E/R still drives the shared FX.
## No old suite/full route.

const L1_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const L2_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LOG_PATH: String = "res://tests/logs/gate_text_cleanup_20261114.log"

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_l2_cleanup_and_gate()
	await _test_l1_gate_lifecycle()
	_write_log()
	print("GATE_TEXT_CLEANUP pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _test_l2_cleanup_and_gate() -> void:
	var level: Level02 = L2_SCENE.instantiate() as Level02
	add_child(level)
	await _frames(6)
	await _physics(4)
	for node_name: String in [
		"StartBayLabel", "RelayBayLabel", "LinkedBayLabel", "FinalBayLabel",
		"CorridorLabel", "ExitStatus",
	]:
		_check(level.get_node_or_null(NodePath(node_name)) == null, "L2 world label %s removed" % node_name)
	var hud: Level02HUD = level.get_hud()
	_check(hud != null, "L2 HUD exists")
	_check(hud.get_compact_header() != null, "compact header retained")
	_check(not hud.get_phase_text().is_empty(), "short current objective remains")
	_check(not hud.get_core_text().is_empty(), "short core state remains")
	_check(not hud.get_core_text().contains("记录") and not hud.get_core_text().contains("符石"), "long record/field readout is not visible")
	_check(not hud.is_prompt_visible(), "no idle central prompt on normal spawn")
	_check(hud.get_recovery_hint_text().is_empty(), "no stored permanent recovery text")
	_check(not _has_label_containing(hud, "失败回最近稳定仓"), "no permanent bottom recovery label")
	_check(hud.get_completion_primary_button() != null, "completion primary button retained")

	# A real loaded bay in range produces the E action prompt; leaving hides it.
	level.get_player().global_position = Vector2(100, 320)
	level.get_player().velocity = Vector2.ZERO
	await _physics(4)
	_check(hud.is_prompt_visible() and hud.get_prompt_text().contains("E 释放"), "real E release prompt appears in bay range")
	level.get_player().global_position = Vector2(300, 320)
	level.get_player().velocity = Vector2.ZERO
	await _physics(4)
	_check(not hud.is_prompt_visible() and hud.get_prompt_text().is_empty(), "idle walk has no repeating target prompt")

	# F remains the GuideEcho conversation; no old stele/second F surface.
	var guide: GuideEcho = level.get_start_stele()
	level.get_player().global_position = Vector2(100, 320)
	level.get_player().velocity = Vector2.ZERO
	await _frames(12)
	_check(guide != null and get_tree().get_nodes_in_group(&"guide_echo").size() == 1, "one L2 GuideEcho remains")
	_check(guide.is_prompt_visible(), "GuideEcho F prompt remains")
	await _tap_key(KEY_F)
	await _frames(2)
	_check(guide.is_dialogue_open(), "real F opens GuideEcho")
	await _tap_key(KEY_F)
	await _frames(2)
	guide.force_close()
	_check(guide.get_page_count() == 4, "four teaching pages retained")

	# Failure/recovery still gives a short event toast.
	level.call("_restore_stable", "fall")
	await _physics(3)
	_check(hud.is_toast_visible() and hud.get_toast_text().contains("跌落"), "failure recovery still gives a short toast")
	_check(hud.get_recovery_hint_text().is_empty(), "recovery does not restore a permanent bottom line")

	# Pause controls keep R; HUD pause state remains usable.
	var pause = level.get_pause_menu()
	_check(pause.get_controls_text().contains("整关重来"), "pause controls still list R restart")
	await _tap_ui_key(KEY_ESCAPE)
	await _wait_paused(true)
	_check(pause.is_open() and hud.is_pause_visible(), "real Esc opens pause")
	await _tap_ui_key(KEY_ESCAPE)
	await _wait_paused(false)

	# L2 gate still comes from the real lock/record contract, not a default door.
	level.debug_restore_stage(2, true)
	if hud != null:
		hud.show_toast("", 0.0)
	var player: PrototypePlayer = level.get_player()
	var core: StarCoreCarrier = level.get_core()
	var linked: StarCoreBayInteractable = level.get_linked_bay()
	var final_bay: StarCoreBayInteractable = level.get_final_bay()
	var exit: LevelExit = level.get_exit()
	player.global_position = Vector2(1600, 320)
	player.velocity = Vector2.ZERO
	level.get_camera().reset_smoothing()
	await _physics(4)
	_check(not level.is_exit_gate_ready(), "L2 default shared FX does not open an unlocked gate")
	_check(linked.has_core() and not final_bay.has_core(), "closed L2 keeps one linked core")
	_check(exit.get_gate_fx_sprite() != null and not exit.is_gate_fx_visible(), "closed L2 FX hidden")
	await _open_gate(level, core)
	await _physics(3)
	_check(level.is_exit_gate_ready(), "L2 real lock/record opens gate")
	_check(exit.is_gate_fx_visible(), "L2 open gate shows shared FX")
	_check(not hud.get_core_text().contains("记录") and not hud.get_core_text().contains("符石"), "open L2 HUD stays short")
	await _tap_key(KEY_E)
	await _physics(28)
	_check(core.is_active() and not level.is_exit_gate_ready(), "L2 E takes core and closes gate")
	await _frames(4)
	_check(not exit.is_gate_fx_visible(), "L2 E hides shared FX")
	await _open_gate(level, core)
	await _physics(3)
	await _tap_key(KEY_R)
	await _frames(20)
	await _physics(4)
	_check(not level.is_exit_gate_ready(), "L2 real R closes gate")
	_check(not exit.is_gate_fx_visible(), "L2 real R hides shared FX")
	_check(exit.get_gate_fx_frames() == 8 and is_equal_approx(exit.get_gate_fx_fps(), 8.0), "shared FX constants remain 8/8")
	level.queue_free()
	await _frames(4)


func _test_l1_gate_lifecycle() -> void:
	var level: Level01 = L1_SCENE.instantiate() as Level01
	level.enable_start_menu = false
	level.intro_max_duration = 0.5
	add_child(level)
	await _frames(3)
	await _physics(3)
	var exit: LevelExit = level.get_exit()
	var pause = level.get_pause_menu()
	_check(exit.gate_portal_fx_enabled, "L1 default LevelExit enables the shared FX")
	_check(exit.get_gate_fx_sprite() != null, "L1 default LevelExit creates the FX sprite")
	_check(exit.get_gate_fx_sprite().texture != null and Vector2i(exit.get_gate_fx_sprite().texture.get_size()) == Vector2i(608, 100), "L1 default sheet is v2 608x100")
	_check(level.is_intro_active() and not exit.is_gate_available(), "L1 opening/intro keeps gate FX hidden")
	for _i: int in range(80):
		await _frames(1)
		if not level.is_intro_active():
			break
	await _frames(4)
	_check(not level.is_intro_active(), "L1 intro finished")
	_check(exit.is_gate_available() and exit.is_gate_fx_visible(), "L1 normal gameplay shows gate FX")

	var frame_before: int = exit.get_gate_fx_frame()
	await _tap_ui_key(KEY_ESCAPE)
	await _wait_paused(true)
	_check(pause.is_open(), "L1 real Esc opens pause")
	var frozen: int = exit.get_gate_fx_frame()
	await _frames(30)
	_check(exit.get_gate_fx_frame() == frozen, "L1 pause freezes gate FX")
	await _tap_ui_key(KEY_ESCAPE)
	await _wait_paused(false)
	await _frames(20)
	_check(exit.get_gate_fx_frame() != frame_before or exit.get_gate_fx_frame() != frozen, "L1 resume advances gate FX")

	await _tap_key(KEY_R)
	await _frames(4)
	_check(level.is_intro_active() and not exit.is_gate_available(), "L1 R starts intro with gate FX closed")
	for _i: int in range(80):
		await _frames(1)
		if not level.is_intro_active():
			break
	await _frames(4)
	_check(exit.is_gate_available() and exit.is_gate_fx_visible(), "L1 R intro handoff restores gate FX")

	var player: PrototypePlayer = level.get_player()
	player.global_position = Vector2(1760, 300)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	level.get_camera().reset_smoothing()
	await _physics(4)
	_check(exit.is_gate_fx_visible(), "L1 reachable normal exit has visible FX")
	Input.action_press(&"move_right")
	for _i: int in range(120):
		await get_tree().physics_frame
		if player.global_position.x >= 1828.0:
			break
	Input.action_release(&"move_right")
	await _frames(12)
	_check(level.is_completed() and exit.is_completed(), "L1 real exit completes")
	_check(exit.get_state_texture().resource_path.ends_with("exit_completed.png"), "L1 completed texture preserved")
	_check(not exit.is_gate_fx_visible(), "L1 completion hides gate FX")
	level.queue_free()
	await _frames(4)

	# Separate menu instance: the title menu blocks gameplay and keeps FX off.
	var menu_level: Level01 = L1_SCENE.instantiate() as Level01
	add_child(menu_level)
	await _frames(6)
	var menu_exit: LevelExit = menu_level.get_exit()
	_check(menu_level.get_menu() != null and menu_level.get_menu().is_gameplay_blocked(), "L1 title menu blocks gameplay")
	_check(not menu_exit.is_gate_available() and not menu_exit.is_gate_fx_visible(), "L1 menu keeps gate FX hidden")
	menu_level.queue_free()
	await _frames(4)


func _open_gate(level: Level02, core: StarCoreCarrier) -> void:
	var start_bay: StarCoreBayInteractable = level.get_start_bay()
	var linked: StarCoreBayInteractable = level.get_linked_bay()
	var final_bay: StarCoreBayInteractable = level.get_final_bay()
	var link: BayRuneLink = level.get_link()
	start_bay.reset_empty()
	linked.reset_empty()
	final_bay.reset_empty()
	core.deactivate()
	core.collision_mask = 0
	linked.start_store_core(true)
	linked.finish_store()
	link.restore_committed(true, true)
	linked.start_release()
	linked.finish_release()
	final_bay.start_store_core(true)
	final_bay.finish_store()
	core.global_position = final_bay.get_store_center()
	core.collision_mask = 0
	await _physics(3)


func _has_label_containing(root: Node, needle: String) -> bool:
	for node: Node in root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.text.contains(needle):
			return true
	return false


func _tap_ui_key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait_paused(expected: bool) -> void:
	for _i: int in range(40):
		if get_tree().paused == expected:
			return
		await get_tree().process_frame


func _tap_key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("GATE TEXT CLEANUP FAIL: " + text)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
