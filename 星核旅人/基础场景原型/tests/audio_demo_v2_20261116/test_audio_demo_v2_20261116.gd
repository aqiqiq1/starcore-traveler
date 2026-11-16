extends Node

## Focused checks for the 2026-11-16/17 audio wiring passes.
##
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/audio_demo_v2_20261116/test_audio_demo_v2_20261116.tscn
##
## Scope: the twelve wired cues (nine old offline candidates + Q/J/heavy shatter
## from the approved CC0 sources), the Q reset/spawn silence rule, the J lock
## states and the three shell-shatter states, plus the existing pause / master /
## scene-change behaviour. Input is driven through the real InputMap / GUI (keys,
## mouse clicks on the real PixelMenuButton / Button controls) and real gameplay
## signals; this is not a "call play()" smoke test. Setup teleports and the
## guard's own hit-resolution calls are called out where used. No old suite and
## no tests/logs output are touched.
##
## It does not measure audibility (headless, no listener). Pause is checked
## through the audio players' tree-pause state, master 0 % through the existing
## StartMenu volume path + the Master-bus routing, scene change through the
## world pool actually stopping.

const LEVEL01_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL02_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LEVEL03_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const LOG_DIR: String = "res://tests/audio_demo_v2_20261116/"
const LOG_PATH: String = LOG_DIR + "run_audio_demo_v2_20261117.log"
const RUNTIME_DIR: String = "res://assets/audio_demo_v2_20261116/"

const WIRED: Dictionary = {
	"ui_click": "ui_confirm.wav",
	"core_take": "core_take.wav",
	"core_seat": "core_seat.wav",
	"link": "link_pulse.wav",
	"player_hurt": "player_hurt.wav",
	"gate": "gate_rise.wav",
	"complete": "complete.wav",
	"failure": "failure.wav",
	"respawn": "respawn.wav",
	"polarity_switch": "polarity_switch_v2.wav",
	"swing": "swing_v2.wav",
	"shell_shatter": "shell_shatter_heavy_v2.wav",
}
const NEW_THREE: Array = ["polarity_switch", "swing", "shell_shatter"]

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []
var _level: Node = null
var _struck: int = 0
var _probe_pressed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - audio demo v2 wiring checks (2026-11-17)")
	_log("Godot %s  audio_driver=%s" % [
		Engine.get_version_info()["string"],
		AudioServer.get_driver_name(),
	])
	await _sec_service_contract()
	await _sec_new_three()
	await _sec_disabled_button()
	await _sec_l1_menu_ui()
	await _sec_l1_gameplay()
	await _sec_l2_to_l3()
	await _sec_l3()
	await _sec_l3_q_j_shatter()
	await _sec_pool_and_master()
	await _clear_levels()
	DemoAudio.release_streams()
	_finish()


# --- A. service contract ----------------------------------------------------

func _sec_service_contract() -> void:
	_section("A service contract: twelve wired files, two Master-bus pools")
	var events: Array = DemoAudio.get_runtime_events()
	_check(events.size() == 12, "service exposes exactly twelve wired events", str(events.size()))
	for event: String in WIRED.keys():
		var spec: Dictionary = (DemoAudio.get_event_specs() as Dictionary).get(event, {})
		_check(not spec.is_empty(), "'%s' has an event spec" % event)
		_check(String(spec.get("file", "")) == String(WIRED[event]),
			"'%s' maps to %s" % [event, String(WIRED[event])],
			String(spec.get("file", "")))
		_check(FileAccess.file_exists(RUNTIME_DIR + String(WIRED[event])),
			"runtime file exists for '%s'" % event)
		_check(float(spec.get("volume_db", 0.0)) <= -1.0,
			"'%s' keeps a restrained negative demo level" % event,
			"%.1f dB" % float(spec.get("volume_db", 0.0)))
	_check(DemoAudio.get_world_pool_size() == 6, "world pool is bounded at 6",
		str(DemoAudio.get_world_pool_size()))
	_check(DemoAudio.get_ui_pool_size() == 4, "UI pool is bounded at 4",
		str(DemoAudio.get_ui_pool_size()))
	_check(DemoAudio.are_all_players_on_master(), "every cue player uses the Master bus")
	_check(DemoAudio.get_total_play_count() == 0, "no cue played before any gameplay event",
		str(DemoAudio.get_total_play_count()))


# --- B. new three are real files, no placeholder machinery ------------------

func _sec_new_three() -> void:
	_section("B new Q / J / shatter are real file-backed events")
	DemoAudio.reset_counts()
	for event: String in NEW_THREE:
		var spec: Dictionary = (DemoAudio.get_event_specs() as Dictionary).get(event, {})
		_check(not spec.is_empty(), "'%s' has a real spec" % event)
		_check(not String(spec.get("file", "")).is_empty(), "'%s' has a file (not a placeholder)" % event)
		_check(FileAccess.file_exists(RUNTIME_DIR + String(spec.get("file", ""))),
			"'%s' runtime file exists" % event, String(spec.get("file", "")))
		_check(DemoAudio.get_play_count(event) == 0, "'%s' has not played before gameplay" % event)
	_check(DemoAudio.has_method("play_polarity_switch"), "play_polarity_switch exists")
	_check(DemoAudio.has_method("play_swing"), "play_swing exists")
	_check(DemoAudio.has_method("play_shell_shatter"), "play_shell_shatter exists")
	_check(not DemoAudio.has_method("get_reserved_call_count"),
		"old reserved-call placeholder accessor is gone")
	_check(not DemoAudio.has_method("is_reserved_event"),
		"old reserved-event placeholder accessor is gone")


# --- C. shared PixelMenuButton disabled / enabled ---------------------------

func _sec_disabled_button() -> void:
	_section("C shared button: disabled is silent, enabled clicks once")
	DemoAudio.reset_counts()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var button: PixelMenuButton = PixelMenuButton.new()
	button.position = Vector2(240.0, 150.0)
	button.size = Vector2(160.0, 32.0)
	button.text = "TEST"
	button.disabled = true
	layer.add_child(button)
	await _process_frames(2)
	_probe_pressed = 0
	button.pressed.connect(func() -> void: _probe_pressed += 1)
	await _click(button)
	_check(_probe_pressed == 0, "disabled PixelMenuButton does not emit pressed", str(_probe_pressed))
	_check(DemoAudio.get_play_count("ui_click") == 0,
		"disabled PixelMenuButton is silent", str(DemoAudio.get_play_count("ui_click")))
	button.disabled = false
	await _process_frames(2)
	await _click(button)
	_check(_probe_pressed == 1, "enabled PixelMenuButton emits exactly once", str(_probe_pressed))
	_check(DemoAudio.get_play_count("ui_click") == 1,
		"enabled PixelMenuButton plays exactly one UI cue",
		str(DemoAudio.get_play_count("ui_click")))
	layer.queue_free()
	await _process_frames(2)


# --- D. L1 start menu: real Button + PixelMenuButton, one each --------------

func _sec_l1_menu_ui() -> void:
	_section("D L1 start menu: real buttons and pixel buttons are not double-played")
	await _new_l1(true)
	var menu: StartMenu = (_level as Level01).get_menu()
	_check(menu != null, "L1 start menu is active")
	if menu == null:
		return
	var before: int = DemoAudio.get_play_count("ui_click")
	await _click(menu.get_settings_button())
	_check(menu.is_settings_open(), "real settings Button opens the settings layer")
	_check(DemoAudio.get_play_count("ui_click") == before + 1,
		"real Button plays one UI cue (no double)",
		"%d -> %d" % [before, DemoAudio.get_play_count("ui_click")])
	before = DemoAudio.get_play_count("ui_click")
	var fullscreen: PixelMenuButton = menu.get_display_mode_button(true)
	_check(fullscreen != null and not fullscreen.disabled,
		"non-active display mode PixelMenuButton is enabled")
	await _click(fullscreen)
	_check(DemoAudio.get_play_count("ui_click") == before + 1,
		"PixelMenuButton plays one UI cue", "%d -> %d" % [before, DemoAudio.get_play_count("ui_click")])
	before = DemoAudio.get_play_count("ui_click")
	await _click(menu.get_return_button())
	_check(not menu.is_settings_open(), "real return Button closes settings")
	_check(DemoAudio.get_play_count("ui_click") == before + 1,
		"return Button plays one UI cue", "%d -> %d" % [before, DemoAudio.get_play_count("ui_click")])
	_check(get_tree().paused == false, "menu checks leave the tree unpaused")


# --- E. L1 gameplay: spawn/Q silent, complete once, fall respawn once -------

func _sec_l1_gameplay() -> void:
	_section("E L1: spawn silent, real Q once, reset silent, completion/fall once")
	await _new_l1(false)
	var l1: Level01 = _level as Level01
	_check(DemoAudio.get_total_play_count() == 0,
		"initial spawn does not fire a cue", str(DemoAudio.get_total_play_count()))
	_check(DemoAudio.get_play_count("polarity_switch") == 0,
		"initial polarity does not play the Q cue")
	await _wait_intro(l1)
	var player: PrototypePlayer = l1.get_player()
	var q_before: int = DemoAudio.get_play_count("polarity_switch")
	await _tap_key(KEY_Q)
	_check(not player.is_positive(), "real Q changes polarity (input still works)")
	_check(DemoAudio.get_play_count("polarity_switch") == q_before + 1,
		"real Q plays exactly one phase cue",
		"%d -> %d" % [q_before, DemoAudio.get_play_count("polarity_switch")])

	# Setup: teleport into the real exit trigger (the trigger is the real path;
	# the signal is only a fallback if the teleport misses one frame).
	player.global_position = Vector2(1838.0, 300.0)
	player.velocity = Vector2.ZERO
	var completed: bool = false
	for _i: int in range(40):
		await get_tree().physics_frame
		if l1.is_completed():
			completed = true
			break
	if not completed:
		l1.get_exit().player_reached_exit.emit()
		await _physics(4)
		completed = l1.is_completed()
	_check(completed, "reaching the exit completes L1")
	_check(DemoAudio.get_play_count("complete") == 1,
		"completion cue once", str(DemoAudio.get_play_count("complete")))
	await _physics(30)
	_check(DemoAudio.get_play_count("complete") == 1,
		"completion cue does not repeat", str(DemoAudio.get_play_count("complete")))

	# R restart must not be a failure or a phase cue.
	var failure_before: int = DemoAudio.get_play_count("failure")
	var respawn_before: int = DemoAudio.get_play_count("respawn")
	var q_before_restart: int = DemoAudio.get_play_count("polarity_switch")
	await _tap_key(KEY_R)
	await _physics(10)
	_check(not l1.is_completed(), "R restarts L1")
	_check(DemoAudio.get_play_count("failure") == failure_before
		and DemoAudio.get_play_count("respawn") == respawn_before,
		"R restart is not a failure or respawn event")
	await _wait_intro(l1)
	_check(DemoAudio.get_play_count("polarity_switch") == q_before_restart,
		"reset/spawn polarity does not play the Q cue",
		str(DemoAudio.get_play_count("polarity_switch")))
	await _tap_key(KEY_Q)
	_check(DemoAudio.get_play_count("polarity_switch") == q_before_restart + 1,
		"Q after a reset still plays once",
		"%d -> %d" % [q_before_restart, DemoAudio.get_play_count("polarity_switch")])
	var q_before_fall: int = DemoAudio.get_play_count("polarity_switch")
	player.global_position = Vector2(1200.0, 470.0)
	player.velocity = Vector2.ZERO
	var resets_before: int = player.get_reset_count()
	var fell: bool = false
	for _i: int in range(60):
		await get_tree().physics_frame
		if player.get_reset_count() > resets_before:
			fell = true
			break
	_check(fell, "the real fall reset ran",
		"resets=%d" % player.get_reset_count())
	await _physics(6)
	_check(DemoAudio.get_play_count("respawn") == respawn_before + 1,
		"real fall restore plays one respawn cue",
		"%d -> %d" % [respawn_before, DemoAudio.get_play_count("respawn")])
	_check(DemoAudio.get_play_count("failure") == failure_before,
		"L1 does not stack a failure cue on its instant restore")
	_check(DemoAudio.get_play_count("polarity_switch") == q_before_fall,
		"fall restore does not play the Q cue")


# --- F. L2 real E flow, then the real completion page into L3 --------------

func _sec_l2_to_l3() -> void:
	_section("F L2 real take/store/link, completion page enters L3")
	await _new_l2()
	var l2: Level02 = _level as Level02
	var player: PrototypePlayer = l2.get_player()
	var core: StarCoreCarrier = l2.get_core()
	_check(DemoAudio.get_total_play_count() == 0,
		"L2 initial spawn does not fire a cue", str(DemoAudio.get_total_play_count()))
	_check(DemoAudio.get_play_count("polarity_switch") == 0,
		"L2 initial polarity does not play the Q cue")
	await _tap_key(KEY_Q)
	_check(DemoAudio.get_play_count("polarity_switch") == 1,
		"L2 real Q plays one phase cue", str(DemoAudio.get_play_count("polarity_switch")))
	await _tap_key(KEY_Q)
	_check(DemoAudio.get_play_count("polarity_switch") == 2,
		"L2 second real Q plays one more cue", str(DemoAudio.get_play_count("polarity_switch")))
	_check(player.is_positive(), "L2 two Q presses leave the player in 辉相")

	# Real fall into the kill line: one respawn at the existing stable restore.
	var q_before_fall: int = DemoAudio.get_play_count("polarity_switch")
	var resets_before: int = player.get_reset_count()
	player.global_position = Vector2(300.0, 460.0)
	player.velocity = Vector2.ZERO
	for _i: int in range(60):
		await get_tree().physics_frame
		if player.get_reset_count() > resets_before:
			break
	await _physics(4)
	_check(DemoAudio.get_play_count("respawn") == 1,
		"L2 real fall restore plays one respawn cue",
		str(DemoAudio.get_play_count("respawn")))
	_check(DemoAudio.get_play_count("polarity_switch") == q_before_fall,
		"L2 fall restore polarity does not play the Q cue")
	var failed_e_before: int = DemoAudio.get_total_play_count()
	await _tap_key(KEY_E)
	_check(DemoAudio.get_total_play_count() == failed_e_before,
		"an unavailable E (nothing in range) is silent",
		"%d -> %d" % [failed_e_before, DemoAudio.get_total_play_count()])

	var start_bay: StarCoreBayInteractable = l2.get_start_bay()
	var relay_bay: StarCoreBayInteractable = l2.get_relay_bay()
	var linked_bay: StarCoreBayInteractable = l2.get_linked_bay()
	var final_bay: StarCoreBayInteractable = l2.get_final_bay()

	# 1) real E release from the start bay.
	await _place_at_bay(player, start_bay)
	await _tap_key(KEY_E)
	var released: bool = await _wait_until(func() -> bool: return not l2.get_pending_release(), 120)
	_check(released, "real E releases the start-bay core")
	_check(DemoAudio.get_play_count("core_take") == 1, "take cue once",
		str(DemoAudio.get_play_count("core_take")))
	_check(DemoAudio.get_play_count("core_seat") == 0, "release is not a seat cue",
		str(DemoAudio.get_play_count("core_seat")))

	# 2) real E store into the relay bay (all bays use the same event).
	await _place_core_and_player(player, core, relay_bay)
	_log("  store setup core=%s active=%s player=%s relay=%s zone=%s range=%s" % [
		str(core.global_position), str(core.is_active()), str(player.global_position),
		relay_bay.get_state_name(), str(relay_bay.is_core_in_store_zone(core.global_position)),
		str(relay_bay.is_player_in_range(player.global_position)),
	])
	await _tap_key(KEY_E)
	var stored: bool = await _wait_until(func() -> bool: return l2.get_store_bay() == null, 120)
	_log("  after store E: storeBay=%s relay=%s seat=%d" % [
		str(l2.get_store_bay()), relay_bay.get_state_name(),
		DemoAudio.get_play_count("core_seat"),
	])
	_check(stored, "real E stores into the relay bay")
	_check(DemoAudio.get_play_count("core_seat") == 1, "relay store is one seat cue",
		str(DemoAudio.get_play_count("core_seat")))

	# 3) take from the relay, store into the linked bay, wait for the real field commit.
	await _place_at_bay(player, relay_bay)
	await _tap_key(KEY_E)
	await _wait_until(func() -> bool: return not l2.get_pending_release(), 120)
	await _place_core_and_player(player, core, linked_bay)
	await _tap_key(KEY_E)
	await _wait_until(func() -> bool: return l2.get_store_bay() == null, 120)
	_check(DemoAudio.get_play_count("core_take") == 2, "linked-bay take cue",
		str(DemoAudio.get_play_count("core_take")))
	_check(DemoAudio.get_play_count("core_seat") == 2, "linked-bay store cue",
		str(DemoAudio.get_play_count("core_seat")))
	var committed: bool = await _wait_until(func() -> bool: return DemoAudio.get_play_count("link") >= 1, 360)
	_check(committed, "rune-field commit plays the link cue once",
		str(DemoAudio.get_play_count("link")))
	await _physics(30)
	_check(DemoAudio.get_play_count("link") == 1, "link cue is not repeated by the pulse",
		str(DemoAudio.get_play_count("link")))

	# 4) take from linked, store into the final bay.
	await _place_at_bay(player, linked_bay)
	await _tap_key(KEY_E)
	await _wait_until(func() -> bool: return not l2.get_pending_release(), 120)
	await _place_core_and_player(player, core, final_bay)
	await _tap_key(KEY_E)
	await _wait_until(func() -> bool: return l2.get_store_bay() == null, 120)
	_check(DemoAudio.get_play_count("core_take") == 3, "final flow take cues",
		str(DemoAudio.get_play_count("core_take")))
	_check(DemoAudio.get_play_count("core_seat") == 3, "final store seat cue",
		str(DemoAudio.get_play_count("core_seat")))
	var ready: bool = await _wait_until(func() -> bool: return l2.is_exit_gate_ready(), 120)
	_check(ready, "final bay + link make the exit ready")

	# 5) real exit completion, then the real completion-page button.
	player.global_position = Vector2(1680.0, 320.0)
	player.velocity = Vector2.ZERO
	var completed: bool = await _wait_until(func() -> bool: return l2.is_completed(), 120)
	_check(completed, "player reaches the real exit and L2 completes")
	_check(DemoAudio.get_play_count("complete") == 1, "L2 completion cue once",
		str(DemoAudio.get_play_count("complete")))
	await _physics(20)
	_check(DemoAudio.get_play_count("complete") == 1, "L2 completion cue does not repeat",
		str(DemoAudio.get_play_count("complete")))
	var primary: PixelMenuButton = l2.get_hud().get_completion_primary_button()
	_check(primary != null and not primary.disabled, "completion primary button is usable")
	get_tree().current_scene = l2
	var world_before: int = DemoAudio.get_active_world_count()
	_check(world_before >= 1, "a world cue is still playing before the scene change",
		str(world_before))
	await _click(primary)
	var l3: Level03 = null
	for _i: int in range(300):
		await get_tree().process_frame
		if get_tree().current_scene is Level03:
			l3 = get_tree().current_scene as Level03
			break
	_check(l3 != null, "the real completion button loads level 03",
		str(get_tree().current_scene))
	_level = l3
	if l3 == null:
		return
	_check(DemoAudio.get_active_world_count() == 0,
		"scene change stops the world pool", str(DemoAudio.get_active_world_count()))
	_check(DemoAudio.get_ui_pool_size() == 4 and DemoAudio.get_play_count("ui_click") >= 1,
		"scene change keeps the UI pool (a short click may still be finishing)",
		"pool=%d clicks=%d" % [DemoAudio.get_ui_pool_size(), DemoAudio.get_play_count("ui_click")])
	_check(DemoAudio.get_play_count("respawn") == 1
		and DemoAudio.get_play_count("failure") == 0
		and DemoAudio.get_play_count("player_hurt") == 0
		and DemoAudio.get_play_count("polarity_switch") == 2
		and DemoAudio.get_play_count("swing") == 0
		and DemoAudio.get_play_count("shell_shatter") == 0,
		"L3 initial load adds no recovery/combat/Q/J/shatter cue",
		"respawn=%d failure=%d hurt=%d q=%d j=%d sh=%d" % [
			DemoAudio.get_play_count("respawn"),
			DemoAudio.get_play_count("failure"),
			DemoAudio.get_play_count("player_hurt"),
			DemoAudio.get_play_count("polarity_switch"),
			DemoAudio.get_play_count("swing"),
			DemoAudio.get_play_count("shell_shatter"),
		])
	DemoAudio.reset_counts()
	await _physics(24)


# --- G. L3 accepted hit / protection / recovery / gate / pause / complete --

func _sec_l3() -> void:
	_section("G L3: accepted hit, protection, recovery timing, gate, pause, completion")
	var l3: Level03 = _level as Level03
	if l3 == null:
		_check(false, "L3 instance is available")
		return
	var player: L3Player = l3.get_player()
	var guard: L3Guard = l3.get_guard()
	_struck = 0
	if not guard.player_struck.is_connected(_on_player_struck):
		guard.player_struck.connect(_on_player_struck)

	# Real first hit through the guard's own gravity attack.
	l3.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	_check(await _wait_for_struck(1, 600), "first real guard strike lands")
	_check(DemoAudio.get_play_count("player_hurt") == 1,
		"accepted hit plays one player_hurt cue",
		str(DemoAudio.get_play_count("player_hurt")))
	_check(player.is_hit_protected(), "the player is inside the 0.6 s protection window")

	# The guard's real strike resolution rejects a protected target: no signal,
	# no cue, no extra hit.
	var hit_count_before: int = player.get_hit_count()
	var hurt_before: int = DemoAudio.get_play_count("player_hurt")
	guard.call("_resolve_normal_strike")
	await _physics(2)
	_check(String(guard.get("_last_strike_code")) == "PROTECTED",
		"protection branch reports PROTECTED", String(guard.get("_last_strike_code")))
	_check(player.get_hit_count() == hit_count_before,
		"protected strike does not add a player hit")
	_check(DemoAudio.get_play_count("player_hurt") == hurt_before,
		"protected strike is silent", str(DemoAudio.get_play_count("player_hurt")))

	# Second accepted real hit -> the existing 0.15 s reaction, then recovery.
	_check(await _wait_for_struck(2, 900), "second real guard strike lands")
	_check(DemoAudio.get_play_count("player_hurt") == 2,
		"second accepted hit is the second hurt cue",
		str(DemoAudio.get_play_count("player_hurt")))
	var recovery_started: bool = await _wait_until(func() -> bool: return l3.is_recovery_active(), 90)
	_check(recovery_started, "the second hit opens the real recovery cover")
	_check(DemoAudio.get_play_count("failure") == 1,
		"failure cue once at the recovery entry",
		str(DemoAudio.get_play_count("failure")))
	_check(DemoAudio.get_play_count("respawn") == 0,
		"respawn is not played during fade-out/black",
		str(DemoAudio.get_play_count("respawn")))
	_check(l3.get_recovery_phase() != "fade_in", "cover is still fading out at the failure cue",
		l3.get_recovery_phase())
	var respawn_at_fade_in: bool = false
	var respawn_early: bool = false
	for _i: int in range(1200):
		await get_tree().process_frame
		if l3.get_recovery_phase() == "fade_in":
			respawn_at_fade_in = DemoAudio.get_play_count("respawn") == 1
			break
		if DemoAudio.get_play_count("respawn") > 0:
			respawn_early = true
			break
	_check(not respawn_early, "respawn stays silent until the fade-in begins")
	_check(respawn_at_fade_in, "respawn plays exactly once when the black hold ends",
		"count=%d" % DemoAudio.get_play_count("respawn"))
	_check(await _wait_until(func() -> bool: return not l3.is_recovery_active(), 1200),
		"recovery completes")
	_check(DemoAudio.get_play_count("failure") == 1 and DemoAudio.get_play_count("respawn") == 1,
		"one failure and one respawn for one recovery",
		"failure=%d respawn=%d" % [DemoAudio.get_play_count("failure"), DemoAudio.get_play_count("respawn")])

	# R restart is not a failure, and does not add a respawn.
	var failure_before: int = DemoAudio.get_play_count("failure")
	var respawn_before: int = DemoAudio.get_play_count("respawn")
	await _tap_key(KEY_R)
	await _physics(12)
	_check(not l3.is_recovery_active(), "R leaves no recovery running")
	_check(l3.get_stable_stage() == 0, "R returns to the opening stage",
		str(l3.get_stable_stage()))
	_check(DemoAudio.get_play_count("failure") == failure_before
		and DemoAudio.get_play_count("respawn") == respawn_before,
		"R restart is not judged as a failure/recovery")

	# Gate: real E inserts the key core; one rise cue from insert_started and one
	# seat cue at the socket, never the old l3_audio seat on top.
	l3.debug_setup_gate_with_key()
	await _physics(8)
	var gate_before: int = DemoAudio.get_play_count("gate")
	var seat_before: int = DemoAudio.get_play_count("core_seat")
	await _tap_key(KEY_E)
	await _physics(3)
	_check(l3.is_key_embedded(), "real E embeds the key core")
	_check(DemoAudio.get_play_count("gate") == gate_before + 1,
		"gate rise cue starts once at insert_started",
		"%d -> %d" % [gate_before, DemoAudio.get_play_count("gate")])
	_check(DemoAudio.get_play_count("core_seat") == seat_before + 1,
		"embed plays one new seat cue", "%d -> %d" % [seat_before, DemoAudio.get_play_count("core_seat")])
	_check(String(l3.get_audio().get_last_played()) != "core_seat",
		"old l3_audio seat is not played on top", String(l3.get_audio().get_last_played()))
	var world_active: int = DemoAudio.get_active_world_count()
	_check(world_active >= 1, "the gate cue is really playing", str(world_active))

	# Pause: world freezes, pause-menu UI still confirms once while paused.
	await _tap_key(KEY_ESCAPE)
	_check(get_tree().paused, "Esc opens the real pause page")
	_check(DemoAudio.is_world_paused() and DemoAudio.get_paused_world_count() >= 1,
		"world cue is paused by the tree",
		"paused=%d" % DemoAudio.get_paused_world_count())
	var pause_menu: Node = l3.get_pause_menu()
	var settings_button: PixelMenuButton = pause_menu.call("get_settings_button") as PixelMenuButton
	var ui_before: int = DemoAudio.get_play_count("ui_click")
	await _click(settings_button)
	_check(bool(pause_menu.call("is_settings_open")), "pause settings opens while paused")
	_check(DemoAudio.get_play_count("ui_click") == ui_before + 1,
		"UI cue plays inside the pause", "%d -> %d" % [ui_before, DemoAudio.get_play_count("ui_click")])
	_check(DemoAudio.get_paused_ui_count() == 0,
		"UI cue player is not paused by the tree",
		str(DemoAudio.get_paused_ui_count()))
	var host: StartMenu = pause_menu.call("get_settings_host") as StartMenu
	ui_before = DemoAudio.get_play_count("ui_click")
	await _click(host.get_return_button())
	_check(not bool(pause_menu.call("is_settings_open")), "real return Button closes pause settings")
	_check(DemoAudio.get_play_count("ui_click") == ui_before + 1,
		"return inside pause plays one UI cue",
		"%d -> %d" % [ui_before, DemoAudio.get_play_count("ui_click")])

	# Master 0 %: the existing slider path mutes Master, and every pool player is
	# on that bus, so nothing bypasses it. Restored without saving settings.
	var volume_before: int = int(host.get("_volume_percent"))
	var muted_before: bool = AudioServer.is_bus_mute(0)
	var db_before: float = AudioServer.get_bus_volume_db(0)
	host.set("_volume_percent", 0)
	host.call("_apply_master_volume")
	_check(AudioServer.is_bus_mute(0), "StartMenu 0% mutes the Master bus")
	_check(DemoAudio.are_all_players_on_master(),
		"both pools stay on Master at 0% (no bypass bus)")
	host.set("_volume_percent", volume_before)
	host.call("_apply_master_volume")
	_check(AudioServer.is_bus_mute(0) == muted_before
		and absf(AudioServer.get_bus_volume_db(0) - db_before) < 0.01,
		"master volume restored after the routing check")

	await _tap_key(KEY_ESCAPE)
	_check(not get_tree().paused, "Esc resumes after the pause checks")
	await _physics(2)
	_check(DemoAudio.get_paused_world_count() == 0,
		"world cue resumes after unpause", str(DemoAudio.get_paused_world_count()))

	# The paused gate finishes; walking into the city completes once.
	var opened: bool = await _wait_until(func() -> bool: return l3.get_gate().is_open(), 360)
	_check(opened, "gate opens after the resumed rise")
	player.global_position = Vector2(2465.0, 320.0)
	player.velocity = Vector2.ZERO
	var complete_before: int = DemoAudio.get_play_count("complete")
	var city_done: bool = await _wait_until(func() -> bool: return l3.is_completed(), 120)
	_check(city_done, "entering the city completes L3")
	_check(DemoAudio.get_play_count("complete") == complete_before + 1,
		"L3 completion cue once",
		"%d -> %d" % [complete_before, DemoAudio.get_play_count("complete")])
	await _physics(30)
	_check(DemoAudio.get_play_count("complete") == complete_before + 1,
		"L3 completion cue does not repeat", str(DemoAudio.get_play_count("complete")))
	var swing_at_complete: int = DemoAudio.get_play_count("swing")
	await _tap_key(KEY_J)
	_check(DemoAudio.get_play_count("swing") == swing_at_complete,
		"J on the completion page is silent",
		str(DemoAudio.get_play_count("swing")))

	# The completion page's own replay button uses the same restart path: a
	# replay is not a defeat.
	var replay: PixelMenuButton = l3.get_hud().get_completion_replay_button()
	_check(replay != null and not replay.disabled, "completion replay button is usable")
	var replay_failure: int = DemoAudio.get_play_count("failure")
	var replay_respawn: int = DemoAudio.get_play_count("respawn")
	await _click(replay)
	await _physics(14)
	_check(not l3.is_completed(), "completion replay restarts L3")
	_check(DemoAudio.get_play_count("failure") == replay_failure
		and DemoAudio.get_play_count("respawn") == replay_respawn,
		"completion replay is not judged as a failure/recovery",
		"failure=%d respawn=%d" % [DemoAudio.get_play_count("failure"), DemoAudio.get_play_count("respawn")])

	# Freeing the level (what a scene change does) stops the world pool.
	_check(DemoAudio.get_active_world_count() >= 1, "completion tail is playing before teardown",
		str(DemoAudio.get_active_world_count()))
	if get_tree().current_scene == l3:
		get_tree().current_scene = null
	l3.queue_free()
	_level = null
	await _process_frames(3)
	_check(DemoAudio.get_active_world_count() == 0,
		"level teardown stops the world pool", str(DemoAudio.get_active_world_count()))


# --- H. L3 real Q / J / shell shatter --------------------------------------

func _sec_l3_q_j_shatter() -> void:
	_section("H L3 real Q, J lock and three shell-shatter states")
	await _new_l3()
	var l3: Level03 = _level as Level03
	var player: L3Player = l3.get_player()
	var guard: L3Guard = l3.get_guard()
	_check(DemoAudio.get_play_count("polarity_switch") == 0,
		"fresh L3 starts with no Q cue")
	await _tap_key(KEY_Q)
	_check(not player.is_positive(), "L3 real Q changes polarity")
	_check(DemoAudio.get_play_count("polarity_switch") == 1,
		"L3 real Q plays exactly one cue")
	await _tap_key(KEY_R)
	await _physics(12)
	_check(l3.get_stable_stage() == 0, "R resets L3")
	_check(DemoAudio.get_play_count("polarity_switch") == 1,
		"L3 R reset does not play a Q cue")
	await _tap_key(KEY_Q)
	_check(DemoAudio.get_play_count("polarity_switch") == 2,
		"Q after the L3 reset plays once")

	# Recovery cover: Q and J are rejected and silent; the scripted polarity
	# restore inside the retry is silent too.
	l3.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	guard.player_struck.emit(-1)
	await _physics(2)
	guard.player_struck.emit(-1)
	await _physics(2)
	_check(await _wait_until(func() -> bool: return l3.is_recovery_active(), 60),
		"recovery cover is active for the Q/J lock check")
	var q_at_cover: int = DemoAudio.get_play_count("polarity_switch")
	var j_at_cover: int = DemoAudio.get_play_count("swing")
	var positive_at_cover: bool = player.is_positive()
	await _tap_key(KEY_Q)
	await _tap_key(KEY_J)
	_check(player.is_positive() == positive_at_cover
		and DemoAudio.get_play_count("polarity_switch") == q_at_cover,
		"Q during the recovery cover is silent")
	_check(DemoAudio.get_play_count("swing") == j_at_cover,
		"J during the recovery cover does not play a swing cue")
	_check(await _wait_until(func() -> bool: return not l3.is_recovery_active(), 1200),
		"recovery completes")
	_check(DemoAudio.get_play_count("polarity_switch") == q_at_cover,
		"the recovery's scripted polarity restore is silent")
	await _physics(4)
	await _tap_key(KEY_Q)
	_check(DemoAudio.get_play_count("polarity_switch") == q_at_cover + 1,
		"Q after the recovery plays once")

	# Real J: one accepted swing; cooldown and pause are silent.
	var j0: int = DemoAudio.get_play_count("swing")
	await _tap_key(KEY_J)
	_check(DemoAudio.get_play_count("swing") == j0 + 1, "real J plays one swing cue")
	await _tap_key(KEY_J)
	_check(DemoAudio.get_play_count("swing") == j0 + 1,
		"J during the same swing/cooldown is silent",
		str(DemoAudio.get_play_count("swing")))
	await _tap_key(KEY_ESCAPE)
	_check(get_tree().paused, "pause opens before the J lock check")
	await _tap_key(KEY_J)
	_check(DemoAudio.get_play_count("swing") == j0 + 1, "J while paused is silent")
	await _tap_key(KEY_ESCAPE)
	_check(not get_tree().paused, "pause closes after the J lock check")
	for _i: int in range(120):
		await get_tree().physics_frame
		if not player.is_attacking() and player.get_attack_cooldown() <= 0.0:
			break

	# Normal shell shatter: one cue, no cell lost, pre-teaching rubble.
	DemoAudio.reset_counts()
	l3.debug_setup_pre_teaching(2020.0)
	await _physics(8)
	if player.is_positive():
		await _tap_key(KEY_Q)
		_check(DemoAudio.get_play_count("polarity_switch") == 1,
			"Q before the normal shatter plays once")
	var sh0: int = DemoAudio.get_play_count("shell_shatter")
	await _tap_key(KEY_J)
	var normal_seen: bool = await _wait_until(
		func() -> bool: return guard.get_state_name() == "WAIT_RUBBLE", 120)
	_check(normal_seen, "real J shatters the shell before the teaching")
	_check(DemoAudio.get_play_count("shell_shatter") == sh0 + 1,
		"normal shatter plays exactly one cue",
		"%d -> %d" % [sh0, DemoAudio.get_play_count("shell_shatter")])
	_check(guard.get_true_marks_taken() == 0,
		"normal shatter spends no true-damage cell",
		str(guard.get_true_marks_taken()))
	await _physics(20)
	_check(DemoAudio.get_play_count("shell_shatter") == sh0 + 1,
		"normal shatter does not repeat")

	# Gravity true damage: still exactly one shatter cue, not one per signal.
	l3.debug_setup_arena_combat(2020.0, true)
	await _physics(8)
	if player.is_positive():
		await _tap_key(KEY_Q)
	var sh1: int = DemoAudio.get_play_count("shell_shatter")
	var marks_before: int = guard.get_true_marks_taken()
	_check(await _wait_until(
		func() -> bool: return guard.get_state_name() == "GRAVITY_CHARGE", 180),
		"real gravity charge reaches the hittable window")
	await _tap_key(KEY_J)
	_check(await _wait_until(
		func() -> bool: return guard.get_true_marks_taken() == marks_before + 1, 120),
		"real J inside the gravity attack spends one true-damage cell")
	_check(DemoAudio.get_play_count("shell_shatter") == sh1 + 1,
		"gravity true damage plays exactly one shatter cue",
		"%d -> %d" % [sh1, DemoAudio.get_play_count("shell_shatter")])
	_check(await _wait_until(
		func() -> bool: return guard.get_state_name() == "ACTIVE", 300),
		"the guard reassembles after the first true-damage cell")

	# Second and third cells through the guard's own hit resolution.
	l3.debug_place_player_at(Vector2(2020.0, 320.0))
	await _physics(4)
	var sh2: int = DemoAudio.get_play_count("shell_shatter")
	guard.force_gravity_first()
	await _physics(1)
	var res2: Dictionary = guard.receive_player_hit(player, 1, not guard.is_positive(), 9001)
	_check(bool(res2.get("true_damage", false)),
		"second cell is a true-damage break", str(res2))
	_check(DemoAudio.get_play_count("shell_shatter") == sh2 + 1,
		"second true-damage break plays one shatter cue",
		"%d -> %d" % [sh2, DemoAudio.get_play_count("shell_shatter")])
	_check(await _wait_until(
		func() -> bool: return guard.get_state_name() == "ACTIVE", 300),
		"the guard reassembles after the second cell")

	l3.debug_place_player_at(Vector2(2020.0, 320.0))
	await _physics(4)
	var sh3: int = DemoAudio.get_play_count("shell_shatter")
	guard.force_gravity_first()
	await _physics(1)
	var res3: Dictionary = guard.receive_player_hit(player, 1, not guard.is_positive(), 9002)
	_check(bool(res3.get("true_damage", false)),
		"third cell is the lethal true-damage break", str(res3))
	_check(DemoAudio.get_play_count("shell_shatter") == sh3 + 1,
		"the final (third) break plays exactly one shatter cue",
		"%d -> %d" % [sh3, DemoAudio.get_play_count("shell_shatter")])
	_check(guard.get_state_name() == "SCATTERING",
		"the lethal break scatters once", guard.get_state_name())
	_check(await _wait_until(func() -> bool: return guard.get_state_name() == "DEAD", 300),
		"the lethal break does not reassemble")
	await _physics(20)
	_check(DemoAudio.get_play_count("shell_shatter") == sh3 + 1,
		"death after the final break adds no second shatter cue")
	_check(guard.get_true_marks_taken() == 3,
		"all three cells were spent", str(guard.get_true_marks_taken()))

	get_tree().paused = false
	DemoAudio.stop_all()
	if get_tree().current_scene == l3:
		get_tree().current_scene = null
	l3.queue_free()
	_level = null
	await _process_frames(3)


# --- I. bounded pools ------------------------------------------------------

func _sec_pool_and_master() -> void:
	_section("I bounded pools: repeated cues reuse players")
	DemoAudio.reset_counts()
	for _i: int in range(30):
		DemoAudio.play_core_take()
	_check(DemoAudio.get_world_pool_size() == 6, "world pool stays at 6 players")
	_check(DemoAudio.get_node_or_null("WorldCue7") == null, "no seventh world player is created")
	_check(DemoAudio.get_active_world_count() <= 6, "active world voices stay bounded",
		str(DemoAudio.get_active_world_count()))
	for _i: int in range(20):
		DemoAudio.play_ui_click()
	_check(DemoAudio.get_ui_pool_size() == 4, "UI pool stays at 4 players")
	_check(DemoAudio.get_node_or_null("UICue5") == null, "no fifth UI player is created")
	_check(DemoAudio.get_active_ui_count() <= 4, "active UI voices stay bounded",
		str(DemoAudio.get_active_ui_count()))
	DemoAudio.stop_all()
	_check(DemoAudio.get_active_world_count() == 0 and DemoAudio.get_active_ui_count() == 0,
		"stop_all clears both pools")


# --- harness ---------------------------------------------------------------

func _new_l1(enable_menu: bool) -> void:
	await _clear_levels()
	DemoAudio.reset_counts()
	var l1: Level01 = LEVEL01_SCENE.instantiate() as Level01
	l1.enable_start_menu = enable_menu
	get_tree().root.add_child(l1)
	await _physics(8)
	_level = l1


func _new_l2() -> void:
	await _clear_levels()
	DemoAudio.reset_counts()
	var l2: Level02 = LEVEL02_SCENE.instantiate() as Level02
	get_tree().root.add_child(l2)
	await _physics(24)
	_level = l2


func _new_l3() -> void:
	await _clear_levels()
	DemoAudio.reset_counts()
	var l3: Level03 = LEVEL03_SCENE.instantiate() as Level03
	get_tree().root.add_child(l3)
	await _physics(24)
	_level = l3


func _clear_levels() -> void:
	get_tree().paused = false
	for child: Node in get_tree().root.get_children():
		if child == self:
			continue
		if child is Level01 or child is Level02 or child is Level03:
			if get_tree().current_scene == child:
				get_tree().current_scene = null
			var audio: Node = child.call("get_audio") if child.has_method("get_audio") else null
			if audio != null and audio.has_method("release_streams"):
				audio.call("release_streams")
			child.queue_free()
	await _process_frames(2)
	_level = null
	_struck = 0
	for action: StringName in [
		&"move_left", &"move_right", &"jump", &"polarity", &"interact",
		&"reset", &"pause", &"tutorial_next",
	]:
		Input.action_release(action)


func _on_player_struck(_facing: int) -> void:
	_struck += 1


func _wait_for_struck(target: int, limit: int) -> bool:
	for _i: int in range(limit):
		await get_tree().physics_frame
		if _struck >= target:
			return true
	return false


func _wait_intro(l1: Level01) -> void:
	for _i: int in range(300):
		await get_tree().process_frame
		if not l1.is_intro_active():
			break
	await _physics(6)


func _place_at_bay(player: PrototypePlayer, bay: StarCoreBayInteractable) -> void:
	player.global_position = bay.global_position + Vector2(0.0, 16.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	await _physics(2)


func _place_core_and_player(
	player: PrototypePlayer, core: StarCoreCarrier, bay: StarCoreBayInteractable
) -> void:
	core.global_position = bay.get_store_center()
	core.velocity = Vector2.ZERO
	player.global_position = bay.global_position + Vector2(0.0, 16.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	await _physics(2)


func _wait_until(predicate: Callable, limit: int) -> bool:
	for _i: int in range(limit):
		await get_tree().physics_frame
		if bool(predicate.call()):
			return true
	return false


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _process_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _tap_key(key: Key) -> void:
	_send_key(key, true)
	await get_tree().process_frame
	await get_tree().physics_frame
	_send_key(key, false)
	await get_tree().process_frame
	await get_tree().physics_frame


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _click(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var center: Vector2 = control.get_global_rect().get_center()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	get_viewport().push_input(up, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _section(title: String) -> void:
	_log("")
	_log("-- %s --" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass += 1
		_log("[PASS] %s  (%s)" % [label, detail])
	else:
		_fail += 1
		_log("[FAIL] %s  (%s)" % [label, detail])


func _log(line: String) -> void:
	_lines.append(line)
	print(line)


func _finish() -> void:
	_log("")
	_log("AUDIO_DEMO_V2_SUMMARY pass=%d fail=%d" % [_pass, _fail])
	_log("RESULT: %s" % ("PASS" if _fail == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	get_tree().quit(0 if _fail == 0 else 1)
