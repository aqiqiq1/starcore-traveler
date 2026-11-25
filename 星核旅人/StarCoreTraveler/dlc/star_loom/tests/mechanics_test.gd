extends Node

## Headless mechanics test for dlc/star_loom.
##
##   ... --headless --path . res://dlc/star_loom/tests/mechanics_test.tscn
##
## Covers: real movement into the hall starting the boss; a same-phase J doing
## no damage to a node; a real opposite-phase J breaking a node; both nodes
## down opening the core; a real J on the core with the same-phase bounce and
## three true hits advancing the stage; the three attack pools / telegraphs /
## spawned hazards; two accepted hits fully resetting the boss at the entrance;
## R restarting the chapter; the completion page and E returning to the title.
##
## Debug calls are used only to place a node at a readable orbit angle / pick a
## stage or attack pattern for the test.  Every hit still goes through the real
## J key -> attack_hit_window -> phase comparison path, and every player hit
## goes through L3Player.receive_enemy_strike().

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"

var _loom: StarLoom
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	_release_all()
	print("STAR_LOOM_MECHANICS_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_process(count: int) -> void:
	for _index: int in range(count):
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


func _release_all() -> void:
	for action: StringName in [
		&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause",
	]:
		Input.action_release(action)


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


## Real physical J through the viewport: the chapter's _input requests the
## shared L3Player swing and the hit is resolved by the real hit window.
func _press_j() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(7)
	_push_key(KEY_J, false)
	await _wait_physics(2)


func _swing_j() -> void:
	await _press_j()
	await _wait_attack_ready()


func _park_node(index: int, positive: bool) -> void:
	var target: LoomNode = _loom.get_nodes()[index]
	var other: LoomNode = _loom.get_nodes()[1 - index]
	target.set_orbit_enabled(false)
	target.set_phase_timer_enabled(false)
	target.debug_set_angle(PI * 0.5)
	target.debug_set_phase(positive)
	other.set_orbit_enabled(false)
	other.set_phase_timer_enabled(false)
	other.debug_set_angle(-PI * 0.5)
	await _wait_physics(2)


func _break_both_nodes() -> bool:
	# Node A: gold (true), hit with the player in cyan (false).
	await _park_node(0, true)
	await _place(660.0, 320.0, false)
	await _swing_j()
	var a_dead: bool = not _loom.get_nodes()[0].is_alive()
	# Node B: cyan (false), hit with the player gold (true).
	await _park_node(1, false)
	await _place(660.0, 320.0, true)
	await _swing_j()
	var b_dead: bool = not _loom.get_nodes()[1].is_alive()
	return a_dead and b_dead


## One real core hit.  Sets the player opposite to the current core phase first.
func _core_hit() -> bool:
	await _place(660.0, 320.0, not _loom.get_core().get_phase())
	var before: int = _loom.get_core_hits()
	await _swing_j()
	return _loom.get_core_hits() > before or _loom.get_stage() > 1


func _load_loom() -> bool:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		return false
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	get_tree().root.add_child(_loom)
	get_tree().current_scene = _loom
	await _wait_process(3)
	await _wait_physics(8)
	_player = _loom.get_player()
	return _player != null


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(6)
	_release_all()


# --- main flow -------------------------------------------------------------

func _run() -> void:
	_check(await _load_loom(), "star_loom scene loads and exposes an L3Player")
	if _player == null:
		return
	_check(_loom.get_stage() == 1 and not _loom.is_boss_active(),
		"boss starts dormant at stage 1")
	_check(_loom.get_player_hits() == 0 and _loom.get_core_hits() == 0,
		"fresh attempt has 0 hits and 0 core damage")
	_check(_loom.get_hud().get_title_text() == "星核织机",
		"HUD title is 星核织机", _loom.get_hud().get_title_text())
	_check(_loom.get_hud().get_objective_text().begins_with("目标：向右进入织机厅"),
		"HUD starts with the entry objective", _loom.get_hud().get_objective_text())

	# --- real movement starts the boss ------------------------------------
	await _place(400.0, 320.0, false)
	Input.action_press(&"move_right")
	var entered: bool = await _wait_until(
		func() -> bool: return _loom.is_boss_active(), 120
	)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check(entered, "walking past the entrance starts the loom")
	_check(_loom.get_nodes_alive_count() == 2, "both nodes are live on start")
	_check(not _loom.is_core_exposed(), "core is shielded on start")
	var audio: LoomAudio = _loom.get_audio()
	_check(audio.is_music_available(), "boss music stream is loaded")
	_check(audio.is_music_playing(), "boss music starts with the fight")
	_check(audio.get_music_loop(), "boss music looping is set in code (not .import)")
	_check(
		audio.get_music_volume_db() >= -7.0 and audio.get_music_volume_db() <= -5.0,
		"boss music player volume is between -7 and -5 dB",
		str(audio.get_music_volume_db())
	)
	print("LOOM_MUSIC_FINAL_PEAK_DBFS=%.2f" % (-8.05 + audio.get_music_volume_db()))
	_check(audio.get_music_length() > 30.0,
		"boss music stream has a real length", "%.1fs" % audio.get_music_length())

	# Pause page: tree + HUD pause and a clean resume.
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(2)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(4)
	_check(_loom.is_pause_open() and get_tree().paused,
		"Esc opens the pause page and pauses the tree")
	_check(_loom.get_hud().is_pause_visible(), "HUD pause page is visible")
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(2)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(4)
	_check(not _loom.is_pause_open() and not get_tree().paused,
		"Esc resumes the fight")
	_loom.debug_set_attacks_enabled(false)

	# --- same phase does nothing, opposite phase breaks -------------------
	await _park_node(0, true)
	await _place(660.0, 320.0, true)
	var alive_before: int = _loom.get_nodes_alive_count()
	await _swing_j()
	_check(_loom.get_nodes_alive_count() == alive_before,
		"same-phase real J does not damage a node")
	_check(_loom.get_nodes()[0].is_alive(), "the same-phase node stays alive")
	_check(_loom.get_hud().get_event_text().contains("同相"),
		"same-phase swing reports 同相", _loom.get_hud().get_event_text())

	await _place(660.0, 320.0, false)
	await _swing_j()
	_check(not _loom.get_nodes()[0].is_alive(),
		"opposite-phase real J breaks node A")
	_check(_loom.get_nodes_alive_count() == 1, "one node remains")
	_check(not _loom.is_core_exposed(), "core stays shielded with one node alive")

	await _park_node(1, false)
	await _place(660.0, 320.0, false)
	await _swing_j()
	_check(_loom.get_nodes()[1].is_alive(),
		"same-phase real J does not break node B")
	await _place(660.0, 320.0, true)
	await _swing_j()
	_check(not _loom.get_nodes()[1].is_alive(),
		"opposite-phase real J breaks node B")
	_check(_loom.get_nodes_alive_count() == 0, "the node ring is empty")
	_check(_loom.is_core_exposed(), "both nodes down exposes the core")
	_check(_loom.get_hud().get_core_text().contains("核心 0 / 3"),
		"HUD shows the exposed core counter", _loom.get_hud().get_core_text())

	# --- core true hits / same-phase bounce -------------------------------
	_loom.debug_set_core_phase(true)
	await _place(660.0, 320.0, true)
	await _swing_j()
	_check(_loom.get_core_hits() == 0, "same-phase real J does not hurt the core")
	await _place(660.0, 320.0, false)
	await _swing_j()
	_check(_loom.get_core_hits() == 1, "first opposite-phase core hit registers")
	_check(not _loom.get_core().get_phase(),
		"core flips to cyan after the first true hit")
	await _place(660.0, 320.0, false)
	await _swing_j()
	_check(_loom.get_core_hits() == 1,
		"the new same phase is bounced (core still 1 / 3)")
	await _place(660.0, 320.0, true)
	await _swing_j()
	_check(_loom.get_core_hits() == 2, "second true core hit registers")
	await _place(660.0, 320.0, false)
	await _swing_j()
	_check(_loom.get_core_hits() == 0 and _loom.get_stage() == 2,
		"third true hit advances to stage 2 and resets core damage")
	_check(_loom.get_nodes_alive_count() == 2, "stage 2 respawns both nodes")
	_check(not _loom.is_core_exposed(), "stage 2 re-shields the core")
	_check(_loom.get_hud().get_stage_text() == "阶段 2 / 3",
		"HUD stage row reads 阶段 2 / 3", _loom.get_hud().get_stage_text())

	# --- attack pools, telegraphs and real hazards ------------------------
	_check(_loom.get_attack_pool().has("homing")
		and _loom.get_attack_pool().has("sweep")
		and not _loom.get_attack_pool().has("summon"),
		"stage 2 pool is homing + sweep", str(_loom.get_attack_pool()))
	_loom.debug_set_attacks_enabled(true)
	_loom.debug_set_boss_grace(0.0)
	_loom.debug_clear_hazards()

	var homing_ok: bool = _loom.debug_force_attack("homing")
	_check(homing_ok, "homing attack can be forced inside the stage-2 pool")
	_check(_loom.get_attack_state_name() == "telegraph", "homing starts in telegraph")
	_check(_loom.get_attack_windup("homing") >= 0.3,
		"homing warning is at least 0.3 s", str(_loom.get_attack_windup("homing")))
	var bolts: bool = await _wait_until(
		func() -> bool: return _loom.get_active_bullets() > 0, 90
	)
	_check(bolts, "homing telegraph really spawns bolts")

	var sweep_ok: bool = _loom.debug_force_attack("sweep")
	_check(sweep_ok, "sweep attack can be forced inside the stage-2 pool")
	_check(_loom.get_attack_windup("sweep") >= 0.3,
		"sweep warning is at least 0.3 s", str(_loom.get_attack_windup("sweep")))
	var band: bool = await _wait_until(
		func() -> bool: return _loom.is_sweep_active(), 90
	)
	_check(band, "sweep telegraph really spawns the light band")

	_loom.debug_set_stage(3)
	_check(_loom.get_stage() == 3 and _loom.get_core_hits() == 0,
		"stage 3 resets core damage")
	_check(_loom.get_nodes_alive_count() == 2, "stage 3 respawns both nodes")
	_check(_loom.get_attack_pool().has("homing")
		and _loom.get_attack_pool().has("sweep")
		and _loom.get_attack_pool().has("summon"),
		"stage 3 pool contains all three attacks", str(_loom.get_attack_pool()))
	var summon_ok: bool = _loom.debug_force_attack("summon")
	_check(summon_ok, "summon attack can be forced in stage 3")
	_check(_loom.get_attack_windup("summon") >= 0.3,
		"summon warning is at least 0.3 s", str(_loom.get_attack_windup("summon")))
	var wisps: bool = await _wait_until(
		func() -> bool: return _loom.get_active_wisps() >= 1, 90
	)
	_check(wisps, "summon telegraph really spawns at least one wisp")
	_check(_loom.get_active_wisps() <= 2, "summon spawns one or two wisps",
		str(_loom.get_active_wisps()))

	# A summoned wisp still dies to a real J.
	_loom.debug_clear_hazards()
	_loom.debug_force_attack("summon")
	await _wait_until(func() -> bool: return _loom.get_active_wisps() >= 1, 90)
	var wisp_alive_before: int = _loom.get_active_wisps()
	if wisp_alive_before > 0:
		var wisp: LoomWisp = _loom.get_node("Hazards").get_children().filter(
			func(child: Node) -> bool: return child is LoomWisp
		)[0] as LoomWisp
		_player.global_position = Vector2(wisp.global_position.x - 26.0, 320.0)
		_player.velocity = Vector2.ZERO
		_player.face_direction(1)
		await _swing_j()
		_check(not wisp.is_alive(), "a real J kills a summoned wisp")
	else:
		_check(false, "a summoned wisp existed for the J-kill check")

	# --- two hits fully reset at the entrance ----------------------------
	# The forced attack checks above may have already grazed the stationary
	# player, so start this block from a clean stage-1 state and wait out the
	# shared 0.6 s hit protection.
	_loom.debug_set_stage(1)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	await _place(420.0, 320.0, false)
	await _wait_physics(45)
	_check(_loom.get_player_hits() == 0, "failure block starts from 0 hits")
	var hit_one: bool = _loom.debug_apply_player_hit()
	await _wait_physics(2)
	_check(hit_one and _loom.get_player_hits() == 1,
		"first accepted hit counts (1 / 2)", str(_loom.get_player_hits()))
	await _wait_physics(45)
	var hit_two: bool = _loom.debug_apply_player_hit()
	await _wait_physics(2)
	_check(hit_two and _loom.get_player_hits() == 2,
		"second accepted hit counts (2 / 2)", str(_loom.get_player_hits()))
	var recovery_started: bool = await _wait_until(
		func() -> bool: return _loom.is_recovery_active(), 40
	)
	_check(recovery_started, "two hits start the recovery cover")
	var recovery_ended: bool = await _wait_until(
		func() -> bool: return not _loom.is_recovery_active(), 160
	)
	_check(recovery_ended, "the recovery fade finishes")
	if recovery_ended:
		await _wait_physics(6)
		_check(_loom.get_stage() == 1, "failure restores stage 1", str(_loom.get_stage()))
		_check(_loom.get_nodes_alive_count() == 2, "failure restores both nodes")
		_check(_loom.get_core_hits() == 0 and not _loom.is_core_exposed(),
			"failure restores the shielded core")
		_check(_loom.get_player_hits() == 0, "failure clears the hit counter")
		_check(absf(_player.global_position.x - _loom.get_arena_spawn().x) < 4.0,
			"failure returns the player to the hall entrance",
			"x=%.1f" % _player.global_position.x)
		_check(_loom.is_boss_active(), "the boss stays active after the retry")
		_check(_loom.get_audio().is_music_playing(),
			"boss music keeps playing through the retry")
		Input.action_press(&"move_right")
		await _wait_physics(12)
		Input.action_release(&"move_right")
		_check(_player.global_position.x > _loom.get_arena_spawn().x + 2.0,
			"the player can move again after the retry")

	# --- R restarts the whole chapter ------------------------------------
	_loom.debug_set_stage(2)
	_loom.debug_expose_core()
	await _wait_physics(2)
	_check(_loom.is_core_exposed(), "R setup: core exposed")
	var before_r: float = _loom.get_elapsed_seconds()
	_push_key(KEY_R, true)
	await _wait_physics(2)
	_push_key(KEY_R, false)
	await _wait_physics(8)
	_check(_loom.get_elapsed_seconds() < before_r + 0.5 and _loom.get_elapsed_seconds() < 1.0,
		"R resets the chapter timer", "t=%.2f" % _loom.get_elapsed_seconds())
	_check(_loom.get_stage() == 1 and not _loom.is_boss_active(),
		"R returns to the dormant stage-1 state")
	_check(_loom.get_player_hits() == 0 and _loom.get_core_hits() == 0,
		"R clears hits and core damage")
	_check(absf(_player.global_position.x - _loom.get_start_spawn().x) < 4.0,
		"R returns the player to the start", "x=%.1f" % _player.global_position.x)
	_check(not _loom.is_completed(), "R leaves the completion page hidden")
	_check(not _loom.get_audio().is_music_playing(),
		"R stops the fight music until the boss starts again")

	# --- stage 3 completion and E -> title -------------------------------
	_loom.debug_set_stage(3)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_set_boss_grace(0.0)
	_check(await _break_both_nodes(), "real J clears both nodes in stage 3")
	_check(_loom.is_core_exposed(), "stage-3 core is exposed")
	var core_ok: bool = true
	for index: int in range(3):
		if not await _core_hit():
			core_ok = false
			break
	_check(core_ok, "three real opposite-phase core hits land in stage 3")
	_check(_loom.is_completed(), "the third stage completes the boss")
	_check(not _loom.get_audio().is_music_playing(),
		"completion stops the fight music")
	var hud: LoomHUD = _loom.get_hud()
	_check(hud.is_completion_visible(), "completion page is visible")
	_check(hud.get_completion_text().begins_with("织机停转 · 用时"),
		"completion title is 织机停转 · 用时 mm:ss", hud.get_completion_text())
	var time_pattern: RegEx = RegEx.new()
	time_pattern.compile("^织机停转 · 用时 \\d{2}:\\d{2}$")
	_check(time_pattern.search(hud.get_completion_text()) != null,
		"completion title includes a mm:ss timer", hud.get_completion_text())
	_check(absf(_loom.get_player().velocity.x) < 0.01,
		"completion locks player movement")
	_push_key(KEY_E, true)
	await _wait_physics(2)
	_push_key(KEY_E, false)
	var title_ok: bool = await _wait_until(
		func() -> bool:
			var current: Node = get_tree().current_scene
			return (
				current != null
				and current.scene_file_path == LEVEL_01
				and current.get_node_or_null("StartMenu") != null
			),
		180
	)
	_check(title_ok, "E returns to level_01 with the title menu")
	if title_ok:
		var menu: StartMenu = get_tree().current_scene.get_node_or_null("StartMenu") as StartMenu
		_check(menu != null and menu.is_menu_open(), "the returned title menu is open")
