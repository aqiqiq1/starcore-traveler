extends Node

## Headless gate/route logic test for the trial.  Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/trial_chambers/tests/gate_test.tscn
##
## The test instantiates the real trial scene and drives the real player/gate
## code.  No screenshots are taken here; visual evidence is in capture_visuals.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"

var _trial: TrialChambers
var _player: L3Player
var _gold: PolarityGate
var _cyan: PolarityGate
var _crystal: TrialPhaseCrystal
var _q_hint: TrialQHint
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	if _trial != null and is_instance_valid(_trial):
		# The trial's ambience is still playing here; stop it and give the audio
		# thread a couple of frames before quitting so the exit report stays
		# clean (an Ogg playback cut off at process exit is reported as leaked).
		var ambience: DlcChapterAmbience = _trial.get_ambience()
		if ambience != null:
			ambience.stop(0.0)
		_trial.queue_free()
		await _wait_process(2)
		for _index: int in range(20):
			await get_tree().process_frame
	print("TRIAL_GATE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


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


func _tap_polarity() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(1)
	Input.action_release(&"polarity")
	await _wait_physics(3)


func _hold_right(frames: int) -> void:
	Input.action_press(&"move_right")
	await _wait_physics(frames)
	Input.action_release(&"move_right")
	await _wait_physics(2)


func _place_player(point: Vector2) -> void:
	_player.global_position = point
	_player.velocity = Vector2.ZERO
	await _wait_physics(3)


func _run() -> void:
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	_check(packed != null, "trial scene loads", TRIAL_SCENE)
	if packed == null:
		return
	_trial = packed.instantiate() as TrialChambers
	_trial.show_intro_guide = false
	_trial.show_intro_cinematic = false
	_trial.show_mechanic_tips = false
	add_child(_trial)
	await _wait_process(3)
	await _wait_physics(6)

	_player = _trial.get_player()
	_gold = _trial.get_gate_gold()
	_cyan = _trial.get_gate_cyan()
	_crystal = _trial.get_phase_crystal()
	_q_hint = _trial.get_q_hint()
	_check(
		_player != null and _gold != null and _cyan != null
		and _crystal != null and _q_hint != null,
		"trial exposes player, gates, crystal and Q hint"
	)

	# --- required states / initial phase -----------------------------------
	_check(not _player.is_positive(), "player starts in 澜相 (cyan)")
	_check(_gold.get_required_positive(), "gold gate requires 辉相")
	_check(not _cyan.get_required_positive(), "cyan gate requires 澜相")
	_check(_gold.get_emblem_kind() == "sun", "gold gate carries the sun emblem")
	_check(_cyan.get_emblem_kind() == "moon", "cyan gate carries the moon emblem")
	_check(_trial.get_hud().get_affinity_icon_rect().size.is_equal_approx(Vector2(20.0, 20.0)),
		"header affinity icon is 20x20")
	_check(not _trial.get_hud().is_affinity_text_visible(),
		"header affinity text is hidden")
	_check(_trial.get_hud().get_affinity_icon_positive() == false,
		"header affinity icon starts as the cyan moon")
	_check(_gold.get_lock_state() == "locked", "gold gate starts locked")
	_check(_cyan.get_lock_state() == "open", "cyan gate is open for the starting 澜相")
	_check(_crystal.get_crystal_positive(), "the phase crystal in front of gold is 辉相")
	_check(_gold.has_generated_audio() and _crystal.get_sound_play_count() == 0,
		"gate and crystal carry their own generated cues")
	var crystals: Array[Node] = []
	for node: Node in _trial.find_children("*", "Node2D", true, false):
		if node is TrialPhaseCrystal:
			crystals.append(node)
	_check(crystals.size() == 1, "only the first gate has a phase crystal",
		str(crystals.size()))
	_check(_trial.get_node_or_null("SealedCrystal") == null,
		"the removed sealed twin is not in the scene")
	_check(_crystal.global_position.x < _gold.global_position.x,
		"the crystal stands before the gold gate",
		"crystal=%.0f gold=%.0f" % [_crystal.global_position.x, _gold.global_position.x])
	await _wait_physics(3)
	_check(not _gold.is_open(), "gold gate is solid for cyan player")
	_check(_gold.get_collision_layer() == 1, "gold gate collision layer is 1 when blocked",
		str(_gold.get_collision_layer()))
	_check(_gold.get_state_name() == "blocked", "gold gate reports blocked")

	# --- the crystal is the first key --------------------------------------
	var gold_opens_before: int = _gold.get_open_count()
	var gold_open_sounds_before: int = _gold.get_open_sound_count()
	await _place_player(Vector2(_crystal.global_position.x, 320.0))
	_check(_crystal.get_trigger_count() == 1, "walking into the crystal triggers it once",
		str(_crystal.get_trigger_count()))
	_check(_player.is_positive(), "crystal flipped the player to 辉相")
	_check(_trial.get_hud().get_affinity_icon_positive(),
		"header affinity icon follows the 辉相 flip")
	_check(_crystal.is_pulsing(), "crystal plays its 0.20 s pulse")
	_check(_crystal.get_sound_play_count() == 1, "crystal played its chime")
	_check(_gold.is_open(), "gold gate opens after the crystal flip")
	_check(_gold.get_open_count() == gold_opens_before + 1,
		"the crystal open counts as a real gate opening",
		str(_gold.get_open_count()))
	_check(_gold.get_open_sound_count() == gold_open_sounds_before + 1,
		"gate played its opening cue")
	_check(_gold.get_lock_state() == "open", "gold gate reports the open lock state")

	# Re-blocking happens only after stepping away (anti-pinch untouched).
	await _place_player(Vector2(238.0, 320.0))
	_player.set_polarity_state(false)
	await _wait_physics(3)
	_check(not _gold.is_open(), "leaving and switching away re-blocks the gate")

	# --- same phase opens, opposite phase blocks ---------------------------
	_player.set_polarity_state(true)
	await _wait_physics(3)
	_check(_gold.is_open(), "same phase opens the gold gate")
	_check(_gold.get_collision_layer() == 0, "gold gate collision layer is 0 when open",
		str(_gold.get_collision_layer()))
	_check(_gold.get_state_name() == "open", "gold gate reports open")

	_player.set_polarity_state(false)
	await _wait_physics(3)
	_check(not _gold.is_open(), "opposite phase re-blocks the gold gate")
	_check(_gold.get_collision_layer() == 1, "gold gate returns to solid layer")

	# Gate must never change the phase it only reads.
	var phase_before: bool = _player.is_positive()
	_gold.set_required_positive(false)
	await _wait_physics(3)
	_check(_player.is_positive() == phase_before, "gate does not change player phase")
	_gold.set_required_positive(true)
	await _wait_physics(3)

	# --- wrong-phase contact: reject pulse + Q keycap ----------------------
	await _place_player(Vector2(240.0, 320.0))
	_player.set_polarity_state(false)
	await _wait_physics(3)
	var denies_before: int = _gold.get_deny_count()
	var deny_sounds_before: int = _gold.get_deny_sound_count()
	var q_shows_before: int = _q_hint.get_show_count()
	await _hold_right(50)
	var blocked_x: float = _player.global_position.x
	_check(blocked_x <= 272.5, "cyan player is stopped by the gold gate",
		"x=%.2f" % blocked_x)
	_check(not _gold.is_open(), "gold gate stays closed while pushing into it")
	_check(_gold.get_deny_count() > denies_before, "wrong-phase contact rejects the player",
		str(_gold.get_deny_count()))
	_check(_gold.get_deny_sound_count() > deny_sounds_before,
		"the denied door played its low cue")
	_check(_q_hint.is_active(), "the denied player gets the Q keycap over the head")
	_check(_q_hint.get_cap_rect().size.is_equal_approx(Vector2(18.0, 20.0)),
		"the head Q keycap is 18x20", str(_q_hint.get_cap_rect().size))
	_check(_q_hint.get_show_count() == q_shows_before + 1,
		"one Q keycap is shown per rejected contact")
	await _wait_physics(80)
	_check(not _q_hint.is_active(), "the Q keycap expires after one second")

	await _tap_polarity()
	_check(_player.is_positive(), "Q toggled the player to 辉相")
	_check(_gold.is_open(), "gold gate opens after Q")
	_check(_gold.is_opening(), "the open state starts its 0.15 s spread animation")
	await _hold_right(45)
	var passed_x: float = _player.global_position.x
	_check(passed_x > 295.0, "辉相 player walks through the gold gate",
		"x=%.2f" % passed_x)

	# --- second gate has no crystal: Q is the second key -------------------
	await _place_player(Vector2(475.0, 320.0))
	var cyan_denies_before: int = _cyan.get_deny_count()
	var cyan_q_shows_before: int = _q_hint.get_show_count()
	await _hold_right(55)
	var cyan_blocked_x: float = _player.global_position.x
	_check(cyan_blocked_x <= 512.5, "辉相 player is stopped by the cyan gate",
		"x=%.2f" % cyan_blocked_x)
	_check(not _cyan.is_open(), "cyan gate is closed for 辉相")
	_check(_cyan.get_deny_count() > cyan_denies_before,
		"the cyan gate also rejects a wrong-phase body")
	_check(_q_hint.get_show_count() == cyan_q_shows_before + 1,
		"the second door again raises the Q keycap")

	await _tap_polarity()
	_check(not _player.is_positive(), "second Q returns the player to 澜相")
	_check(_cyan.is_open(), "cyan gate opens after the second Q")
	_check(_cyan.is_opening(), "the cyan gate also plays the 0.15 s spread")
	await _hold_right(50)
	var cyan_passed_x: float = _player.global_position.x
	_check(cyan_passed_x > 535.0, "澜相 player walks through the cyan gate",
		"x=%.2f" % cyan_passed_x)

	# --- anti-pinch --------------------------------------------------------
	await _place_player(Vector2(250.0, 320.0))
	_player.set_polarity_state(true)
	_gold.set_required_positive(true)
	await _wait_physics(4)
	_check(_gold.is_open(), "gold gate is open before entering for anti-pinch test")
	await _place_player(Vector2(_gold.global_position.x, 320.0))
	_check(_gold.is_player_inside(), "player body detected inside the gate")
	_player.set_polarity_state(false)
	await _wait_physics(5)
	_check(_gold.is_open(), "phase change inside the gate does not clamp (still open)")
	_check(_gold.get_collision_layer() == 0, "gate stays pass-through while player is inside",
		str(_gold.get_collision_layer()))
	_check(_gold.is_player_inside(), "player is still inside the gate band")
	_check(not _player.is_positive(), "player really switched phase inside the gate")

	# Moving out to the left restores the solid layer.
	await _place_player(Vector2(_gold.global_position.x - 30.0, 320.0))
	_check(not _gold.is_player_inside(), "player body left the gate band")
	_check(not _gold.is_open(), "opposite-phase gate re-closes after the player leaves")
	_check(_gold.get_collision_layer() == 1, "gate returns to solid layer after leaving",
		str(_gold.get_collision_layer()))

	# Restore a clean trial for the user after the test.
	_gold.set_required_positive(true)
	_player.set_polarity_state(false)
	await _wait_physics(2)
