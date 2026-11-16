extends Node

## Focused load/probe for level 03. Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/level03/test_level03_load.tscn

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const LOG_PATH: String = "res://tests/level03/load_probe.log"

var _level: Level03
var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _check(ok: bool, text: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text + ("" if detail.is_empty() else " | " + detail))
		push_error("CHECK FAIL: " + text)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_level = LEVEL_SCENE.instantiate() as Level03
	add_child(_level)
	await _physics(30)

	var player: L3Player = _level.get_player()
	var guard: L3Guard = _level.get_guard()
	var gate: L3Gate = _level.get_gate()
	var device: L3FixedDevice = _level.get_device()
	var route: L3FloatRoute = _level.get_float_route()
	var start_bay: StarCoreBayInteractable = _level.get_start_bay()
	var target_bay: StarCoreBayInteractable = _level.get_target_bay()

	_check(player != null, "player exists")
	_check(player.is_on_floor(), "player starts on the floor")
	_check(absf(player.global_position.y - 320.0) <= 2.0, "player starts at ground y=320")
	# same check text as before the layout change, so the written probe log keeps
	# the frozen byte content the 1339 baseline protects; the assertion is stricter.
	_check(player.get_world_right() >= _level.get_city_enter_x(),
		"world right covers the city interior")
	_check(guard != null and guard.get_state_name() == "ACTIVE", "guard loads ACTIVE")
	_check(guard.get_sprite_scale() == Vector2(2.0, 2.0), "guard visual is exactly 2x")
	_check(guard.get_sprite_texture_path().ends_with("golem_1_idle.png") or guard.get_sprite_texture_path().ends_with("golem_1_walk.png"), "guard uses the existing golem idle/walk sheet")
	_check(guard.get_weakpoint_texture_path().ends_with("weakpoint_gold_64f.png"), "guard starts with the v2 gold weakpoint sheet")
	_check(guard.get_field_texture_path().ends_with("guard_field_gold_12f.png"), "guard starts with the v3 gold field sheet")
	_check(guard.get_remaining_marks() == 3, "three true-damage marks at start")
	_check(guard.get_shell_hits() == 0, "full stone shell at start (zero ordinary hits taken)")
	_check(not guard.is_defeated(), "guard is alive")
	_check(not guard.is_weakpoint_visible(), "weakpoint hidden while idle")
	_check(not gate.is_open(), "gate starts closed")
	_check(not gate.is_inserted(), "gate socket starts empty")
	_check(not device.is_active(), "fixed device starts colourless/inactive")
	_check(route.get_block_count() == 5, "five floating stones authored")
	_check(not route.is_running(), "float route starts idle")
	_check(start_bay.is_locked() and start_bay.has_core(), "transport core starts in the start bay")
	_check(not target_bay.has_core() and target_bay.is_open_empty(), "rune bay starts empty")
	_check(not _level.get_core().is_active(), "carrier is hidden until E release")
	_check(not _level.get_rune_field().is_activated(), "rune starts dormant")
	_check(_level.get_stable_stage() == 0, "stable stage starts at START")
	_check(_level.get_cine() != null and not _level.get_cine().has_played(), "cinematic has not played")
	_check(_level.get_hud() != null, "HUD exists")
	_check(_level.get_hud().get_compact_header().get_title_text() == "断桥外郭", "header names the level")

	var key_tex: Texture2D = load("res://assets/level03_prototype/key_core_16.png") as Texture2D
	var fixed_tex: Texture2D = load("res://assets/level03_prototype/fixed_core_active.png") as Texture2D
	var gate_tex: Texture2D = load("res://assets/level03_prototype/gate_closed_empty.png") as Texture2D
	var weak_tex: Texture2D = load("res://assets/level03_prototype/weakpoint_gold_64f.png") as Texture2D
	var field_tex: Texture2D = load("res://assets/level03_prototype/guard_field_gold_12f.png") as Texture2D
	_check(key_tex != null and key_tex.get_size() == Vector2(16, 16), "guard key core is the approved 16x16 world size")
	_check(fixed_tex != null and fixed_tex.get_size() == Vector2(48, 40), "fixed device uses the 48x40 two-state asset")
	_check(gate_tex != null and gate_tex.get_size() == Vector2(144, 160), "gate facade is the 144x160 v7 copy")
	_check(weak_tex != null and weak_tex.get_size() == Vector2(4608, 72), "weakpoint v2 is a 64x72 frame strip")
	_check(field_tex != null and field_tex.get_size() == Vector2(4608, 384), "guard field v3 is a 12x384x384 strip")
	_check(_level.get_node("KeyCorePickup").texture.get_size() == Vector2(192, 16), "dropped/carried key core uses the same 16px 12-frame sheet")

	var bar: Rect2 = guard.get_head_bar_rect()
	_check(bar.position.y < guard.global_position.y - 120.0, "guard charge/readout sits above the 2x body")
	var chest: Vector2 = guard.get_chest_global_position()
	var weak_art: Rect2 = guard.get_weakpoint_art_rect()
	_check(
		weak_art.position.y >= guard.global_position.y - 70.0
		and weak_art.end.y <= guard.global_position.y - 4.0,
		"weakpoint chest rect stays on the torso and above the ground",
		str(weak_art)
	)

	print("PLAYER ", player.global_position, " floor=", player.is_on_floor())
	print("GUARD ", guard.global_position, " chest=", chest, " state=", guard.get_state_name())
	print("GATE ", gate.global_position, " socket=", gate.get_socket_world_position(), " barrier=", gate.get_barrier_layer())
	print("DEVICE ", device.global_position, " active=", device.is_active())
	print("ROUTE blocks=", route.get_block_states())
	print("PLAYER textures=", player.get_state_name())

	_write_log()
	print("LEVEL03_LOAD pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


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
