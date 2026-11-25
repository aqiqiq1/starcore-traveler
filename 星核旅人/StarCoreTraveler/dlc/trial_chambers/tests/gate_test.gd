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
	add_child(_trial)
	await _wait_process(3)
	await _wait_physics(6)

	_player = _trial.get_player()
	_gold = _trial.get_gate_gold()
	_cyan = _trial.get_gate_cyan()
	_check(_player != null and _gold != null and _cyan != null, "trial exposes player and both gates")

	# --- required states / initial phase -----------------------------------
	_check(not _player.is_positive(), "player starts in 澜相 (cyan)")
	_check(_gold.get_required_positive(), "gold gate requires 辉相")
	_check(not _cyan.get_required_positive(), "cyan gate requires 澜相")
	await _wait_physics(3)
	_check(not _gold.is_open(), "gold gate is solid for cyan player")
	_check(_gold.get_collision_layer() == 1, "gold gate collision layer is 1 when blocked",
		str(_gold.get_collision_layer()))
	_check(_gold.get_state_name() == "blocked", "gold gate reports blocked")

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

	# --- real Q / walking through the gold gate ----------------------------
	await _place_player(Vector2(240.0, 320.0))
	_player.set_polarity_state(false)
	await _wait_physics(3)
	await _hold_right(50)
	var blocked_x: float = _player.global_position.x
	_check(blocked_x <= 272.5, "cyan player is stopped by the gold gate",
		"x=%.2f" % blocked_x)
	_check(not _gold.is_open(), "gold gate stays closed while pushing into it")

	await _tap_polarity()
	_check(_player.is_positive(), "Q toggled the player to 辉相")
	_check(_gold.is_open(), "gold gate opens after Q")
	await _hold_right(45)
	var passed_x: float = _player.global_position.x
	_check(passed_x > 295.0, "辉相 player walks through the gold gate",
		"x=%.2f" % passed_x)

	# --- second gate requires switching back -------------------------------
	await _place_player(Vector2(475.0, 320.0))
	await _hold_right(55)
	var cyan_blocked_x: float = _player.global_position.x
	_check(cyan_blocked_x <= 512.5, "辉相 player is stopped by the cyan gate",
		"x=%.2f" % cyan_blocked_x)
	_check(not _cyan.is_open(), "cyan gate is closed for 辉相")

	await _tap_polarity()
	_check(not _player.is_positive(), "second Q returns the player to 澜相")
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
