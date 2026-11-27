extends Node

## Acceptance test for the base-level 20x20 phase badge and the shared Q cue.
## Run headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://scripts/ui/tests/phase_icon_test.tscn
##
## Each of the three real levels is loaded, its HUD header is checked for an
## icon-only 20x20 sun/moon badge, and one real player toggle must increment the
## shared DemoAudio polarity-switch count by exactly one (no double playback).

const CASES: Array[Array] = [
	["res://scenes/level_01.tscn", "level_01"],
	["res://scenes/level_02.tscn", "level_02"],
	["res://scenes/level_03.tscn", "level_03"],
]

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	for entry: Array in CASES:
		await _test_case(String(entry[0]), String(entry[1]))
	DemoAudio.stop_world()
	print("PHASE_ICON_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _near(value: float, expected: float, tolerance: float = 0.001) -> bool:
	return absf(value - expected) <= tolerance


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _test_case(scene_path: String, tag: String) -> void:
	print("=== %s ===" % tag.to_upper())
	var level: Node = (load(scene_path) as PackedScene).instantiate()
	if tag == "level_01":
		# Match the other automated gameplay tests: no title menu over the HUD.
		level.set("enable_start_menu", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(8)
	await _wait_physics(4)
	if tag == "level_01":
		# End the opening film so the header is on its real gameplay path.
		level.call("_finish_intro")
		await _wait_process(4)

	var hud: Node = level.call("get_hud") as Node
	_check(hud != null, "%s exposes its HUD" % tag)
	if hud == null:
		await _cleanup(level)
		return
	var header: CompactLevelHeader = hud.call("get_compact_header") as CompactLevelHeader
	_check(header != null, "%s HUD has the shared compact header" % tag)
	if header == null:
		await _cleanup(level)
		return

	var icon: Control = header.get_node_or_null("AffinityIcon") as Control
	_check(icon is PolarityPhaseIcon, "%s affinity node is the shared drawn phase icon" % tag)
	_check(header.get_icon_size().is_equal_approx(Vector2(20.0, 20.0)),
		"%s phase icon is 20x20" % tag, str(header.get_icon_size()))
	_check(header.get_phase_kind() == "sun",
		"%s starts on the gold sun (辉相)" % tag, header.get_phase_kind())
	_check(not header.is_phase_text_visible(),
		"%s shows no 辉相/澜相 text" % tag)

	header.set_polarity(false)
	_check(header.get_phase_kind() == "moon",
		"%s switches immediately to the cyan moon" % tag, header.get_phase_kind())
	_check(_near(header.get_phase_color().r, Color("#5fe1e6").r)
		and _near(header.get_phase_color().g, Color("#5fe1e6").g)
		and _near(header.get_phase_color().b, Color("#5fe1e6").b),
		"%s moon uses the cyan phase colour" % tag)
	_check(header.get_icon_size().is_equal_approx(Vector2(20.0, 20.0)),
		"%s moon keeps the 20x20 slot" % tag)

	header.set_polarity(true)
	_check(header.get_phase_kind() == "sun",
		"%s switches back to the gold sun" % tag, header.get_phase_kind())

	# One real player toggle must be one cue.  Calling the same private method
	# Q calls keeps this deterministic without faking the owning level callback.
	DemoAudio.reset_counts()
	# The switch cue plays once per toggle: v2 when delivered, otherwise the
	# v1 fallback keeps the base levels audible (never silent).
	var cue_path: String = DemoAudio.get_polarity_switch_effective_path()
	var cue_expected: int = 1 if ResourceLoader.exists(cue_path) else 0
	var player: Node = level.call("get_player") as Node
	_check(player != null, "%s exposes its player" % tag)
	if player == null:
		await _cleanup(level)
		return
	player.call("_toggle_polarity")
	await _wait_process(2)
	_check(DemoAudio.get_play_count("polarity_switch") == cue_expected,
		"%s plays the phase cue exactly once per toggle" % tag,
		"%d (expected %d) %s" % [
			DemoAudio.get_play_count("polarity_switch"), cue_expected, cue_path
		])
	_check(header.get_phase_kind() == "moon",
		"%s HUD follows the real player toggle" % tag, header.get_phase_kind())

	player.call("_toggle_polarity")
	await _wait_process(2)
	_check(DemoAudio.get_play_count("polarity_switch") == cue_expected * 2,
		"%s two toggles play two cues, not four" % tag,
		"%d (expected %d) %s" % [
			DemoAudio.get_play_count("polarity_switch"), cue_expected * 2, cue_path
		])
	_check(header.get_phase_kind() == "sun",
		"%s HUD returns to the sun" % tag, header.get_phase_kind())

	await _cleanup(level)


func _cleanup(level: Node) -> void:
	DemoAudio.stop_world()
	get_tree().current_scene = null
	level.queue_free()
	await _wait_process(6)
