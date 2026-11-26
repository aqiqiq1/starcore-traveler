extends Node

## Acceptance test for the animated base completion page (level 02 / level 03).
## Run headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://scripts/ui/tests/completion_reveal_test.tscn
##
## The page must be usable on the request frame (visible, active, primary button
## enabled), the alpha must travel during 0.18 s, settle at 1.0, and hiding must
## be immediate with the rest values restored for a later replay.

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
	print("COMPLETION_REVEAL_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _test_case(scene_path: String, tag: String) -> void:
	var level: Node = (load(scene_path) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(10)
	var hud: Node = level.get_node_or_null("HUD")
	_check(hud != null, "%s HUD exists" % tag)
	if hud == null:
		get_tree().current_scene = null
		level.queue_free()
		return

	hud.call("show_completion", true, 1)
	# Same frame as the request: the page is already the real state.
	_check(bool(hud.call("is_completion_active")), "%s active on request frame" % tag)
	var alpha_start: float = float(hud.call("get_completion_reveal_alpha"))
	_check(alpha_start <= 0.05, "%s starts from the dark frame" % tag, "%.2f" % alpha_start)
	var primary: PixelMenuButton = hud.call("get_completion_primary_button") as PixelMenuButton
	_check(primary != null and not primary.disabled, "%s primary button enabled at once" % tag)

	await _wait_process(2)
	var alpha_focus: float = float(hud.call("get_completion_reveal_alpha"))
	_check(primary != null and primary.has_focus(), "%s focus lands while fading" % tag)
	var alpha_mid: float = float(hud.call("get_completion_reveal_alpha"))
	_check(
		alpha_mid > 0.0 and alpha_mid < 1.0,
		"%s alpha is travelling mid-tween" % tag,
		"%.2f" % alpha_mid
	)

	await _wait_seconds(0.3)
	var alpha_end: float = float(hud.call("get_completion_reveal_alpha"))
	_check(_near(alpha_end, 1.0, 0.01), "%s settles fully opaque" % tag, "%.2f" % alpha_end)

	hud.call("show_completion", false)
	_check(not bool(hud.call("is_completion_active")), "%s hides on request frame" % tag)
	_check(
		_near(float(hud.call("get_completion_reveal_alpha")), 1.0, 0.01),
		"%s rest values restored for the next open" % tag
	)

	# Re-open after a hide must animate again instead of showing a stale tween.
	hud.call("show_completion", true, 2)
	var alpha_again: float = float(hud.call("get_completion_reveal_alpha"))
	_check(alpha_again <= 0.05, "%s second open fades again" % tag, "%.2f" % alpha_again)
	hud.call("show_completion", false)
	await _wait_process(2)
	_check(not bool(hud.call("is_completion_active")), "%s second hide is immediate" % tag)

	get_tree().current_scene = null
	level.queue_free()
	await _wait_process(6)


func _near(value: float, expected: float, tolerance: float = 0.001) -> bool:
	return absf(value - expected) <= tolerance
