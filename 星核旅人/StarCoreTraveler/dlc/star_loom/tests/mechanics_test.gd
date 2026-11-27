extends Node

## Headless mechanics test for dlc/star_loom.
##
##   ... --headless --path . res://dlc/star_loom/tests/mechanics_test.tscn
##
## Covers: real movement into the hall starting the boss; a same-phase J doing
## no damage to a node; a real opposite-phase J breaking a node; both nodes
## down opening the core; a real J on the core with the same-phase bounce and
## three true hits advancing the stage; the three attack pools / telegraphs /
## spawned hazards; three accepted hits emptying the health meter and spending
## one life; the stage-1 refill; R restarting the chapter; the completion page
## and E returning to the title.  The separate three-heart life row and the
## three-cell health meter are asserted independently.
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
	# The one remaining teaching window has its own test (ui_parity_test).
	# Mark it seen so this mechanics route is never paused by the fire popup;
	# no hit/stage rule is bypassed.
	MechanicTips.mark_seen("loom_fire_tip")
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


## A standalone Q/J/E/F (not the E of "Esc") is banned outside key rows.
func _has_bare_key_letter(text: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("(^|[^A-Za-z])[QJEF]([^A-Za-z]|$)")
	return regex.search(text) != null


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


## The core weak point is raised: a real jump (Space / jump action) is required
## before the J swing can reach its 40x36 box.
func _jump_swing_j() -> void:
	Input.action_press(&"jump")
	await _wait_physics(8)
	await _press_j()
	Input.action_release(&"jump")
	await _wait_physics(2)
	await _wait_attack_ready()


func _wait_land() -> void:
	await _wait_until(func() -> bool: return _player.is_on_floor(), 90)


func _hold_left_shift(pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_SHIFT as Key
	event.keycode = KEY_SHIFT as Key
	event.location = KEY_LOCATION_LEFT
	event.pressed = pressed
	get_viewport().push_input(event)


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


## One real core hit.  Sets the player opposite to the current core phase first,
## then jumps so the raised 40x36 weak point is actually reachable.
func _core_hit() -> bool:
	await _place(660.0, 320.0, not _loom.get_core().get_phase())
	var before: int = _loom.get_core_hits()
	await _jump_swing_j()
	await _wait_land()
	return _loom.get_core_hits() > before or _loom.get_stage() > 1


func _load_loom() -> bool:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		return false
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	_loom.show_intro_cinematic = false
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
	# The route ends on the level_01 title.  Give the title BGM/audio thread
	# enough frames to release its OGG after the scene is freed, otherwise the
	# headless exit prints a misleading "resources still in use" engine error.
	await _wait_process(20)
	_release_all()


# --- main flow -------------------------------------------------------------

func _run() -> void:
	_check(await _load_loom(), "star_loom scene loads and exposes an L3Player")
	if _player == null:
		return
	_check(_loom.get_stage() == 1 and not _loom.is_boss_active(),
		"boss starts dormant at stage 1")
	_check(_loom.get_gate_first() != null and _loom.get_gate_second() != null
		and _loom.get_core_carrier() != null and _loom.get_core_bay() != null
		and _loom.get_checkpoint() != null,
		"the approach restores the base gate / star core / checkpoint mechanisms")
	_check(not _loom.get_checkpoint().is_activated()
		and not _loom.get_gate_second().is_open(),
		"the checkpoint and second gate start clear")
	_check(_loom.get_player_hits() == 0 and _loom.get_core_hits() == 0,
		"fresh attempt has 0 hits and 0 core damage")
	_check(_loom.get_lives() == 3 and _loom.get_max_lives() == 3,
		"the run starts with three lives",
		"%d / %d" % [_loom.get_lives(), _loom.get_max_lives()])
	var hud_start: LoomHUD = _loom.get_hud()
	var start_boss: HudBossBar = hud_start.get_boss_bar()
	_check(start_boss != null and start_boss.is_lives_visible()
		and start_boss.get_lives_current() == 3
		and start_boss.get_lives_max() == 3,
		"the separate life count is three filled hearts under the boss bar")
	var start_health: LoomHealthBar = hud_start.get_player_health_bar()
	_check(start_health != null and start_health.get_max() == 3
		and start_health.get_current() == 3
		and start_health.get_style_name() == "bar"
		and not start_health.is_heart_style(),
		"the separate health value is a three-segment red bar")
	var status_texts: Array[String] = hud_start.get_status_label_texts()
	_check(status_texts.is_empty() and hud_start.get_status_label_font_size() == 0,
		"the old 阶段/节点/核心/生命 label row is gone", str(status_texts))
	_check(start_boss.size.is_equal_approx(Vector2(360.0, 16.0))
		and start_boss.position == Vector2(140.0, 22.0),
		"the shared boss bar is 360x16 at the top centre",
		"%s %s" % [str(start_boss.size), str(start_boss.position)])
	_check(start_boss.get_phase_index() == 0
		and start_boss.get_phase_count() == 3
		and start_boss.get_nodes_alive() == 2
		and start_boss.get_core_hp() == 0,
		"the boss bar carries stage / node / core state")
	_check(not hud_start.has_top_hit_group(),
		"the top icon row no longer contains a hit group")
	_check(hud_start.get_player_health_bar().get_current() == 3
		and hud_start.get_player_health_bar().visible,
		"the lower-left health bar starts full and visible before the boss")
	_check(hud_start.shows_text_counters() == false,
		"the old 受击 0 / 3 text counter is gone")
	_check(hud_start.get_phase_icon_state() == "moon"
		and hud_start.get_phase_icon_rect().size == Vector2(20.0, 20.0),
		"the top-right phase marker is a 20x20 cyan moon for the initial 澜相")
	_check(hud_start.is_phase_text_hidden(),
		"the old 辉相/澜相 text is hidden")
	_check(hud_start.get_title_text() == "星核织机",
		"HUD title is 星核织机", hud_start.get_title_text())
	_check(hud_start.get_objective_text().begins_with("目标：向右进入织机厅"),
		"HUD starts with the entry objective", hud_start.get_objective_text())
	_check(not _has_bare_key_letter(hud_start.get_objective_text()),
		"HUD objective has no bare Q/J/E/F", hud_start.get_objective_text())

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
	_check(_loom.get_attack_pool() == ["homing"],
		"stage 1 only uses the slow homing bolt", str(_loom.get_attack_pool()))
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
	_check(audio.is_music_paused() == false,
		"music is not stream-paused during normal play")
	var reverb: AudioEffectReverb = audio.get_reverb_effect()
	_check(audio.has_reverb_bus() and reverb != null,
		"the city reverb bus exists with an AudioEffectReverb",
		audio.get_reverb_bus_name())
	if reverb != null:
		_check(reverb.room_size >= 0.5 and reverb.room_size <= 0.7
			and reverb.wet >= 0.15 and reverb.wet <= 0.25,
			"reverb room is 0.5-0.7 and wet is 0.15-0.25",
			"room=%.2f wet=%.2f" % [reverb.room_size, reverb.wet])
	_check(audio.get_music_player().bus == audio.get_reverb_bus_name()
		and audio.get_player_bus("Fire") == audio.get_reverb_bus_name()
		and audio.get_player_bus("Telegraph") == audio.get_reverb_bus_name(),
		"loom music and main SFX players are routed to the reverb bus")
	_check(audio.is_music_playing(),
		"routing through the reverb bus leaves the music playing")

	# Top-right phase icon follows the real Q toggle, not just the header text.
	_check(_loom.get_hud().get_phase_icon_state() == "moon",
		"the HUD phase icon starts as the cyan moon")
	Input.action_press(&"polarity")
	await _wait_physics(4)
	Input.action_release(&"polarity")
	await _wait_physics(4)
	_check(_loom.get_hud().get_phase_icon_state() == "sun",
		"Q flips the top-right marker to the gold sun")
	Input.action_press(&"polarity")
	await _wait_physics(4)
	Input.action_release(&"polarity")
	await _wait_physics(4)
	_check(_loom.get_hud().get_phase_icon_state() == "moon",
		"a second Q flips the marker back to the cyan moon")

	# Shared footstep helper: really parented to the player, really plays the
	# stone bank while running on the floor.
	var footsteps: PlayerFootstepAudio = _loom.get_footstep_audio()
	_check(footsteps != null and footsteps.get_parent() == _player,
		"the shared footstep helper is attached to the player")
	if footsteps != null:
		_hold_left_shift(true)
		Input.action_press(&"move_right")
		await _wait_physics(70)
		Input.action_release(&"move_right")
		_hold_left_shift(false)
		await _wait_physics(4)
		_check(footsteps.get_step_count() > 0,
			"running on the floor produces footstep phases",
			"steps=%d" % footsteps.get_step_count())
		_check(footsteps.get_played_count() > 0
			and footsteps.get_last_played_anim() == &"run",
			"the footstep bank really plays during a run",
			"plays=%d anim=%s" % [
				footsteps.get_played_count(), footsteps.get_last_played_anim()
			])

	# Health VALUE is fixed at the lower-left HUD corner, never over the player.
	var health_bar: LoomHealthBar = _loom.get_hud().get_player_health_bar()
	await _place(660.0, 320.0, false)
	await _wait_process(2)
	_check(health_bar.visible, "health value is visible during the fight")
	var fixed_a: Vector2 = health_bar.position
	await _place(820.0, 320.0, false)
	await _wait_process(2)
	_check(health_bar.position == fixed_a,
		"health value stays fixed when the player walks",
		"%.1f,%.1f -> %.1f,%.1f" % [fixed_a.x, fixed_a.y, health_bar.position.x, health_bar.position.y])
	await _place(660.0, 320.0, false)
	await _wait_process(2)
	Input.action_press(&"jump")
	await _wait_physics(10)
	var fixed_jump: Vector2 = health_bar.position
	Input.action_release(&"jump")
	await _wait_land()
	_check(fixed_jump == fixed_a,
		"health value stays fixed while jumping",
		"%.1f,%.1f -> %.1f,%.1f" % [fixed_a.x, fixed_a.y, fixed_jump.x, fixed_jump.y])
	_check(fixed_a == Vector2(14.0, 324.0),
		"health value sits at the lower-left HUD corner",
		"%.1f,%.1f" % [fixed_a.x, fixed_a.y])

	# Pause page: tree + HUD pause and a clean resume.
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(2)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(4)
	_check(_loom.is_pause_open() and get_tree().paused,
		"Esc opens the pause page and pauses the tree")
	var hud0: LoomHUD = _loom.get_hud()
	_check(hud0.is_pause_visible(), "HUD pause page is visible")
	_check(_loom.is_mechanic_popup_blocked(),
		"the mechanic popup is blocked while paused")
	_check(not _loom.is_footstep_audio_allowed(),
		"footsteps are gated while paused")
	await _wait_process(2)
	_check(not _loom.get_hud().get_player_health_bar().visible,
		"overhead health meter hides on the pause page")
	_check(hud0.get_pause_panel_alpha() < 0.8,
		"pause panel starts its short fade", str(hud0.get_pause_panel_alpha()))
	var pause_settled: bool = await _wait_until(
		func() -> bool: return hud0.get_pause_panel_alpha() > 0.9, 160
	)
	_check(pause_settled and absf(hud0.get_pause_panel_offset()) < 1.5,
		"pause panel fades/slides to its resting position",
		"alpha=%.2f offset=%.1f" % [
			hud0.get_pause_panel_alpha(), hud0.get_pause_panel_offset()
		])
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(2)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(4)
	_check(not _loom.is_pause_open() and not get_tree().paused,
		"Esc resumes the fight")
	await _wait_process(2)
	_check(_loom.get_hud().get_player_health_bar().visible,
		"overhead health meter returns after the pause page closes")
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
	_check(_loom.get_hud().get_boss_bar().get_core_hp() == 0
		and _loom.get_hud().get_boss_bar().get_core_max() == 3
		and not _loom.get_hud().get_boss_bar().has_core_diamonds()
		and _loom.get_hud().get_boss_bar().get_red_bar_segment_count() == 3,
		"HUD keeps the core in the three-segment red bar, with no diamond row")

	var core: LoomCore = _loom.get_core()
	var visual: Dictionary = core.get_expose_visual_info()
	_check(visual["diamond_size"] == Vector2(40.0, 40.0),
		"the exposed core is one 40x40 phase diamond", str(visual["diamond_size"]))
	_check(String(visual["icon"]) == "sun"
		and Color(visual["diamond_color"]) == Color("#f4cd63"),
		"gold phase shows a sun on a gold diamond",
		"%s / %s" % [visual["icon"], visual["diamond_color"]])
	_check(visual["icon_size"] == Vector2(15.0, 15.0),
		"the core sun/moon icon is enlarged to about 14x14",
		str(visual["icon_size"]))
	_check(Color(visual["edge_color"]) == Color(0.02, 0.01, 0.05, 1.0)
		and Color(visual["highlight_color"]) == Color(1.0, 0.98, 0.94, 1.0),
		"the diamond has the 1 px dark edge and white highlight")
	_check(float(visual["net_gap"]) >= 24.0,
		"the gold net opens at least 24 px",
		"%.1f px" % float(visual["net_gap"]))
	_check(bool(visual["has_ring"]) == false,
		"the exposed core draws no ring")
	var hit_rect: Rect2 = core.get_hit_rect()
	_check(hit_rect.size == Vector2(40.0, 36.0),
		"core hit box is 40x36", str(hit_rect.size))
	_check(hit_rect.get_center().y < _loom.get_arena_spawn().y - 50.0,
		"core hit box is raised above a grounded swing",
		"center_y=%.1f" % hit_rect.get_center().y)
	_check(visual["hit_rect"] == hit_rect, "visual info reports the live hit box")

	# --- standing J misses, jumping J reaches ----------------------------
	core.set_phase(true)
	await _place(660.0, 320.0, false)
	await _swing_j()
	_check(_loom.get_core_hits() == 0,
		"standing J misses the raised core")
	await _place(660.0, 320.0, true)
	await _jump_swing_j()
	await _wait_land()
	_check(_loom.get_core_hits() == 0,
		"same-phase jumping J still bounces off the core")

	await _place(660.0, 320.0, false)
	await _jump_swing_j()
	await _wait_land()
	_check(_loom.get_core_hits() == 1, "jumping J lands the first true core hit")
	_check(not core.get_phase(),
		"core flips to cyan after the first true hit")
	_check(core.get_phase_icon_name() == "moon"
		and core.get_phase_color() == Color("#5fe1e6"),
		"the whole diamond turns cyan with a moon icon")
	await _place(660.0, 320.0, false)
	await _jump_swing_j()
	await _wait_land()
	_check(_loom.get_core_hits() == 1,
		"the new same phase is bounced (core still 1 / 3)")
	await _place(660.0, 320.0, true)
	await _jump_swing_j()
	await _wait_land()
	_check(_loom.get_core_hits() == 2, "second true core hit registers")
	await _place(660.0, 320.0, false)
	await _jump_swing_j()
	await _wait_land()
	_check(_loom.get_core_hits() == 0 and _loom.get_stage() == 2,
		"third true hit advances to stage 2 and resets core damage")
	_check(_loom.get_nodes_alive_count() == 2, "stage 2 respawns both nodes")
	_check(not _loom.is_core_exposed(), "stage 2 re-shields the core")
	_check(_loom.get_hud().get_boss_bar().get_phase_index() == 1
		and _loom.get_hud().get_boss_bar().get_phase_count() == 3,
		"HUD stage cells show stage 2 of 3")
	_check(_loom.get_stage_flash() > 0.0 and _loom.is_mechanic_popup_blocked(),
		"the mechanic popup is blocked during the stage switch")

	# --- attack pools, telegraphs and real hazards ------------------------
	_check(_loom.get_attack_pool().has("homing")
		and _loom.get_attack_pool().has("sweep")
		and _loom.get_attack_pool().has("fire")
		and not _loom.get_attack_pool().has("summon"),
		"stage 2 pool is homing + sweep + fire", str(_loom.get_attack_pool()))
	_loom.debug_set_attacks_enabled(true)
	_loom.debug_set_boss_grace(0.0)
	_loom.debug_clear_hazards()

	var homing_ok: bool = _loom.debug_force_attack("homing")
	_check(homing_ok, "homing attack can be forced inside the stage-2 pool")
	_check(_loom.get_attack_state_name() == "telegraph", "homing starts in telegraph")
	_check(_loom.get_attack_windup("homing") >= 0.69,
		"homing warning is widened to about 0.7 s",
		str(_loom.get_attack_windup("homing")))
	var bolts: bool = await _wait_until(
		func() -> bool: return _loom.get_active_bullets() > 0, 90
	)
	_check(bolts, "homing telegraph really spawns bolts")

	var sweep_ok: bool = _loom.debug_force_attack("sweep")
	_check(sweep_ok, "sweep attack can be forced inside the stage-2 pool")
	_check(_loom.get_attack_windup("sweep") >= 0.79,
		"sweep warning is widened to about 0.8 s",
		str(_loom.get_attack_windup("sweep")))
	var band: bool = await _wait_until(
		func() -> bool: return _loom.is_sweep_active(), 90
	)
	_check(band, "sweep telegraph really spawns the light band")

	var fire_ok: bool = _loom.debug_force_attack("fire")
	_check(fire_ok, "floor fire can be forced inside the stage-2 pool")
	_check(_loom.get_attack_windup("fire") >= 0.94,
		"floor fire warning is about 0.95 s", str(_loom.get_attack_windup("fire")))
	_check(_loom.get_last_fire_points().size() == 2,
		"floor fire telegraph marks two vents",
		str(_loom.get_last_fire_points().size()))
	var fire_spawned: bool = await _wait_until(
		func() -> bool: return _loom.get_active_fires() > 0, 120
	)
	_check(fire_spawned, "floor fire telegraph really spawns flame columns")

	_loom.debug_set_stage(3)
	_check(_loom.get_stage() == 3 and _loom.get_core_hits() == 0,
		"stage 3 resets core damage")
	_check(_loom.get_nodes_alive_count() == 2, "stage 3 respawns both nodes")
	_check(_loom.get_attack_pool().has("homing")
		and _loom.get_attack_pool().has("sweep")
		and _loom.get_attack_pool().has("fire")
		and _loom.get_attack_pool().has("summon")
		and _loom.get_attack_pool().has("gear"),
		"stage 3 pool contains all five city attacks", str(_loom.get_attack_pool()))
	var summon_ok: bool = _loom.debug_force_attack("summon")
	_check(summon_ok, "summon attack can be forced in stage 3")
	_check(_loom.get_attack_windup("summon") >= 0.99,
		"summon warning is widened to about 1.0 s",
		str(_loom.get_attack_windup("summon")))
	var wisps: bool = await _wait_until(
		func() -> bool: return _loom.get_active_wisps() >= 1, 90
	)
	_check(wisps, "summon telegraph really spawns at least one wisp")
	_check(_loom.get_active_wisps() <= 2, "summon spawns one or two wisps",
		str(_loom.get_active_wisps()))

	var gear_ok: bool = _loom.debug_force_attack("gear")
	_check(gear_ok, "rolling gears can be forced in stage 3")
	_check(_loom.get_attack_windup("gear") >= 0.89,
		"gear warning is about 0.9 s", str(_loom.get_attack_windup("gear")))
	var gears_spawned: bool = await _wait_until(
		func() -> bool: return _loom.get_active_gears() >= 2, 120
	)
	_check(gears_spawned, "gear telegraph really spawns gears from both sides")

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

	# --- stage-1 supply clears the hit counter once ---------------------
	_loom.debug_set_stage(1)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	await _place(420.0, 320.0, false)
	await _wait_physics(60)
	_check(_loom.get_player_hit_limit() == 3, "player has three accepted hits",
		str(_loom.get_player_hit_limit()))
	_check(_loom.get_damage_immunity_time() >= 0.9,
		"chapter hit grace is about one second", str(_loom.get_damage_immunity_time()))
	_check(_loom.get_player_hits() == 0, "supply block starts from 0 hits")
	var supply_hit: bool = _loom.debug_apply_player_hit()
	await _wait_physics(2)
	_check(supply_hit and _loom.get_player_hits() == 1,
		"one hit is recorded before the supply", str(_loom.get_player_hits()))
	_check(_loom.get_hud().get_player_health_bar().get_current() == 2,
		"one hit leaves two of the three health cells",
		str(_loom.get_hud().get_player_health_bar().get_current()))
	_check(_loom.get_lives() == 3 and _loom.get_hud().get_boss_bar().get_lives_current() == 3,
		"a health hit does not change the three-life count")
	await _wait_until(func() -> bool: return _loom.get_damage_immunity_left() <= 0.0, 120)
	_check(await _break_both_nodes(), "supply setup: both nodes broken by real J")
	var supply_core_ok: bool = true
	for _index: int in range(3):
		if not await _core_hit():
			supply_core_ok = false
			break
	_check(supply_core_ok, "supply setup: three real core hits reach stage 2")
	_check(_loom.get_stage() == 2, "supply setup reached stage 2", str(_loom.get_stage()))
	_check(_loom.get_player_hits() == 0,
		"stage 1 clear resets the hit counter", str(_loom.get_player_hits()))
	_check(_loom.get_hud().get_player_health_bar().get_current() == 3,
		"stage 1 clear refills the three-cell health meter",
		str(_loom.get_hud().get_player_health_bar().get_current()))
	_check(_loom.is_stage_supply_used(), "the one-time stage-1 supply is marked used")
	_check(_loom.get_hud().get_event_text().contains("补给"),
		"stage 2 event reports the city supply", _loom.get_hud().get_event_text())
	_check(_loom.get_hud().get_event_text().contains("生命值补满"),
		"the supply event says the health meter is refilled",
		_loom.get_hud().get_event_text())
	_check(_loom.get_lives() == 3,
		"stage progress and the supply never add lives", str(_loom.get_lives()))

	# --- three hits retry the CURRENT stage at its entrance --------------
	_loom.debug_set_stage(2)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	await _place(420.0, 320.0, false)
	await _wait_physics(60)
	_check(_loom.get_player_hits() == 0, "failure block starts from 0 hits")
	var hit_one: bool = _loom.debug_apply_player_hit()
	await _wait_physics(2)
	_check(hit_one and _loom.get_player_hits() == 1,
		"first accepted hit counts (1 / 3)", str(_loom.get_player_hits()))
	_check(_loom.get_hud().get_player_health_bar().get_current() == 2
		and _loom.get_hud().get_player_hit_pulse_left() > 0.0,
		"a hit empties one health cell and starts the 1 s pulse")
	# 40 frames is about 0.67 s: the shared 0.6 s protection has expired, but
	# the chapter's ~0.95 s grace must still block this second hit.
	await _wait_physics(40)
	var blocked_hit: bool = _loom.debug_apply_player_hit()
	await _wait_physics(2)
	_check(not blocked_hit and _loom.get_player_hits() == 1,
		"chapter grace blocks a hit after the shared 0.6 s protection",
		"hits=%d immunity=%.2f" % [
			_loom.get_player_hits(), _loom.get_damage_immunity_left()
		])
	await _wait_until(func() -> bool: return _loom.get_damage_immunity_left() <= 0.0, 120)
	_check(_loom.get_hud().get_player_hit_pulse_left() <= 0.1,
		"the overhead hit pulse lasts about one second",
		"%.2f" % _loom.get_hud().get_player_hit_pulse_left())
	var hit_two: bool = _loom.debug_apply_player_hit()
	await _wait_physics(2)
	_check(hit_two and _loom.get_player_hits() == 2,
		"second accepted hit counts (2 / 3)", str(_loom.get_player_hits()))
	_check(_loom.get_hud().get_player_health_bar().get_current() == 1,
		"second accepted hit leaves one health cell",
		str(_loom.get_hud().get_player_health_bar().get_current()))
	await _wait_until(func() -> bool: return _loom.get_damage_immunity_left() <= 0.0, 120)
	var hit_three: bool = _loom.debug_apply_player_hit()
	await _wait_physics(2)
	_check(hit_three and _loom.get_player_hits() == 3,
		"third accepted hit counts (3 / 3)", str(_loom.get_player_hits()))
	_check(_loom.get_hud().get_player_health_bar().get_current() == 0,
		"third accepted hit empties the health meter",
		str(_loom.get_hud().get_player_health_bar().get_current()))
	var recovery_started: bool = await _wait_until(
		func() -> bool: return _loom.is_recovery_active(), 40
	)
	_check(recovery_started, "three hits start the recovery cover")
	_check(_loom.is_mechanic_popup_blocked(),
		"the mechanic popup is blocked during the failure recovery")
	_check(not _loom.is_footstep_audio_allowed(),
		"footsteps are gated during the failure recovery")
	await _wait_process(2)
	_check(not _loom.get_hud().get_player_health_bar().visible,
		"overhead health meter hides during the failure recovery")
	var recovery_ended: bool = await _wait_until(
		func() -> bool: return not _loom.is_recovery_active(), 160
	)
	_check(recovery_ended, "the recovery fade finishes")
	if recovery_ended:
		_check(_loom.get_hud().is_event_visible()
			and _loom.get_hud().get_event_text() == "失败 · 从门前检查点恢复",
			"failure row is 失败 · 从门前检查点恢复",
			_loom.get_hud().get_event_text())
		await _wait_physics(6)
		_check(_loom.get_stage() == 2,
			"failure retries stage 2, not the whole chapter", str(_loom.get_stage()))
		_check(_loom.get_nodes_alive_count() == 2, "failure restores both nodes")
		_check(_loom.get_core_hits() == 0 and not _loom.is_core_exposed(),
			"failure restores the shielded core")
		_check(_loom.get_player_hits() == 0, "failure clears the hit counter")
		_check(_loom.get_hud().get_player_health_bar().get_current() == 3,
			"the retry refills the health meter")
		_check(_loom.get_lives() == 2,
			"one death removes exactly one life", str(_loom.get_lives()))
		_check(_loom.get_hud().get_boss_bar().get_lives_current() == 2,
			"the HUD life-heart row drops to 2")
		_check(absf(_player.global_position.x - _loom.get_checkpoint_position().x) < 4.0,
			"failure returns the player to the checkpoint",
			"x=%.1f" % _player.global_position.x)
		_check(_loom.is_boss_active(), "the boss stays active after the retry")
		_check(_loom.is_stage_supply_used(),
			"a stage-2 retry does not re-arm the stage-1 supply")
		_check(_loom.get_audio().is_music_playing(),
			"boss music keeps playing through the retry")
		Input.action_press(&"move_right")
		await _wait_physics(12)
		Input.action_release(&"move_right")
		_check(_player.global_position.x > _loom.get_checkpoint_position().x + 2.0,
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
	_check(_loom.get_lives() == 3,
		"R restores the three lives", str(_loom.get_lives()))
	_check(_loom.get_hud().get_player_health_bar().get_current() == 3,
		"R refills the health meter")
	_check(absf(_player.global_position.x - _loom.get_start_spawn().x) < 4.0,
		"R returns the player to the start", "x=%.1f" % _player.global_position.x)
	_check(not _loom.is_completed(), "R leaves the completion page hidden")
	_check(not _loom.get_audio().is_music_playing(),
		"R stops the fight music until the boss starts again")
	_check(not _loom.get_checkpoint().is_activated(),
		"R clears the checkpoint")
	_check(absf(_loom.get_core_carrier().global_position.x
		- _loom.get_core_carrier().get_start_x()) < 0.5,
		"R restores the star core initial position",
		"x=%.1f" % _loom.get_core_carrier().global_position.x)
	_check(not _loom.get_gate_second().is_open()
		and not _loom.get_core_bay().is_occupied(),
		"R closes the second gate and darkens the star-core bay")

	# --- 3 -> 0 lives and the game over page -----------------------------
	_loom.debug_set_stage(2)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_clear_hazards()
	_loom.debug_set_lives(3)
	await _place(420.0, 320.0, false)
	await _wait_physics(50)
	for death_index: int in range(3):
		await _wait_until(
			func() -> bool: return _loom.get_damage_immunity_left() <= 0.0, 120
		)
		for _hit_index: int in range(3):
			_loom.debug_apply_player_hit()
			await _wait_physics(2)
			if _hit_index < 2:
				await _wait_until(
					func() -> bool: return _loom.get_damage_immunity_left() <= 0.0,
					120
				)
		if death_index < 2:
			var death_started: bool = await _wait_until(
				func() -> bool: return _loom.is_recovery_active(), 80
			)
			_check(death_started, "death %d starts its cover" % (death_index + 1))
			var death_ended: bool = await _wait_until(
				func() -> bool: return not _loom.is_recovery_active(), 240
			)
			_check(death_ended, "death %d finishes its fade" % (death_index + 1))
			_check(_loom.get_lives() == 2 - death_index,
				"death %d leaves %d lives" % [death_index + 1, 2 - death_index],
				str(_loom.get_lives()))
			_check(not _loom.is_game_over(),
				"death %d does not open game over" % (death_index + 1))
		else:
			var game_over_on: bool = await _wait_until(
				func() -> bool: return _loom.is_game_over(), 240
			)
			_check(game_over_on, "the third death opens game over")
	var game_hud: LoomHUD = _loom.get_hud()
	_check(_loom.get_lives() == 0, "lives reach 0", str(_loom.get_lives()))
	_check(game_hud.get_player_health_bar().get_current() == 0,
		"the health meter is empty at game over")
	_check(_loom.is_game_over(), "the chapter reports game over")
	_check(not _loom.is_boss_active(), "the loom stops attacking at game over")
	_check(_player.is_recovery_held(), "the player is held at game over")
	await _wait_process(2)
	_check(not game_hud.get_player_health_bar().visible,
		"overhead health meter hides on the game over page")
	_check(game_hud.is_game_over_visible(), "the game over page is visible")
	_check(game_hud.get_game_over_hearts().get_current() == 0
		and game_hud.get_game_over_hearts().kind == HitPips.Kind.HEART,
		"the game over icon is an empty three-heart row")
	_check(game_hud.get_game_over_title_text() == "生命耗尽",
		"the game over title is 生命耗尽", game_hud.get_game_over_title_text())
	_check(game_hud.get_game_over_panel_rect() == Rect2(
		Vector2(140.0, 75.0), Vector2(360.0, 210.0)),
		"the game over panel is 360x210 at (140,75)",
		str(game_hud.get_game_over_panel_rect()))
	var retry_button: PixelMenuButton = game_hud.get_game_over_retry_button()
	var title_button: PixelMenuButton = game_hud.get_game_over_title_button()
	_check(retry_button != null and retry_button.text == "重试本章"
		and retry_button.variant == PixelMenuButton.Variant.STONE,
		"game over primary is 重试本章 / STONE")
	_check(title_button != null and title_button.text == "返回标题"
		and title_button.variant == PixelMenuButton.Variant.OPTION,
		"game over secondary is 返回标题 / OPTION")
	_check(retry_button.get_node(retry_button.focus_next) == title_button
		and title_button.get_node(title_button.focus_next) == retry_button,
		"game over buttons form a focus ring")
	_check(retry_button.has_focus(), "game over focus starts on 重试本章")
	_check(game_hud.restart_requested.is_connected(
		Callable(_loom, "_on_hud_restart_requested")),
		"重试本章 is wired to the chapter retry")
	_check(game_hud.title_requested.is_connected(
		Callable(_loom, "_on_hud_title_requested")),
		"返回标题 is wired to the title flow")
	_check(_loom.is_mechanic_popup_blocked(),
		"the mechanic popup is blocked on the game over page")
	# R resets the run and the hearts.
	_push_key(KEY_R, true)
	await _wait_physics(2)
	_push_key(KEY_R, false)
	await _wait_physics(8)
	_check(not _loom.is_game_over() and not game_hud.is_game_over_visible(),
		"R closes the game over page")
	_check(_loom.get_lives() == 3 and game_hud.get_boss_bar().get_lives_current() == 3,
		"R resets lives to three", str(_loom.get_lives()))
	_check(_loom.get_stage() == 1 and not _loom.is_boss_active(),
		"R from game over restarts the chapter")
	_check(absf(_player.global_position.x - _loom.get_start_spawn().x) < 4.0,
		"R from game over returns to the start",
		"x=%.1f" % _player.global_position.x)

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
	var completion_settled: bool = await _wait_until(
		func() -> bool: return hud.get_completion_panel_alpha() > 0.9, 120
	)
	_check(completion_settled and absf(hud.get_completion_panel_offset()) < 1.5,
		"completion panel fades/slides to its resting position",
		"alpha=%.2f offset=%.1f" % [
			hud.get_completion_panel_alpha(), hud.get_completion_panel_offset()
		])
	_check(hud.get_completion_panel_rect().size == Vector2(400.0, 210.0)
		and hud.get_completion_panel_rect().position == Vector2(120.0, 75.0),
		"completion panel is 400x210 at (120,75)",
		str(hud.get_completion_panel_rect()))
	_check(hud.get_completion_subtitle_text() == "城内的经线松开，星核的梭子终于停下。",
		"completion subtitle is the loom world-line",
		hud.get_completion_subtitle_text())
	_check(hud.get_completion_note_text() == "本章结算 · 暂停菜单可查看操作",
		"completion footnote matches the base game", hud.get_completion_note_text())
	var primary: PixelMenuButton = hud.get_completion_primary_button()
	var secondary: PixelMenuButton = hud.get_completion_secondary_button()
	_check(primary != null and primary.text == "返回主界面"
		and primary.variant == PixelMenuButton.Variant.STONE
		and primary.size == Vector2(180.0, 28.0),
		"completion primary is 返回主界面 / STONE / 180x28")
	_check(secondary != null and secondary.text == "重玩本关"
		and secondary.variant == PixelMenuButton.Variant.OPTION
		and secondary.size == Vector2(180.0, 24.0),
		"completion secondary is 重玩本关 / OPTION / 180x24")
	_check(primary.get_node(primary.focus_next) == secondary
		and secondary.get_node(secondary.focus_next) == primary,
		"completion buttons form a two-item focus ring")
	_check(primary.has_focus(), "completion focus starts on 返回主界面")
	_check(_loom.is_mechanic_popup_blocked(),
		"the mechanic popup is blocked on the completion page")
	_check(not _loom.is_footstep_audio_allowed(),
		"footsteps are gated on the completion page")
	await _wait_process(2)
	_check(not hud.get_player_health_bar().visible,
		"overhead health meter hides on the completion page")
	_check(hud.get_completion_text().begins_with("织机停转 · 用时"),
		"completion title is 织机停转 · 用时 mm:ss", hud.get_completion_text())
	var time_pattern: RegEx = RegEx.new()
	time_pattern.compile("^织机停转 · 用时 \\d{2}:\\d{2}$")
	_check(time_pattern.search(hud.get_completion_text()) != null,
		"completion title includes a mm:ss timer", hud.get_completion_text())
	_check(absf(_loom.get_player().velocity.x) < 0.01,
		"completion locks player movement")
	# The completion footnote promises Esc opens the pause page.
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(2)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(4)
	_check(_loom.is_pause_open() and get_tree().paused,
		"Esc on the completion page opens the pause page")
	_push_key(KEY_ESCAPE, true)
	await _wait_physics(2)
	_push_key(KEY_ESCAPE, false)
	await _wait_process(4)
	_check(not _loom.is_pause_open() and not get_tree().paused,
		"Esc closes the pause page back to completion")
	_check(hud.is_completion_visible(),
		"the completion page stays visible after the pause round-trip")
	# Default focus is 返回主界面, so Enter must activate that button; the E
	# shortcut itself stays covered by route_test.
	_push_key(KEY_ENTER, true)
	await _wait_physics(2)
	_push_key(KEY_ENTER, false)
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
	_check(title_ok, "Enter on the focused 返回主界面 returns to level_01")
	if title_ok:
		var menu: StartMenu = get_tree().current_scene.get_node_or_null("StartMenu") as StartMenu
		_check(menu != null and menu.is_menu_open(), "the returned title menu is open")
