extends Node

## Focused check that L3 uses the same fixed red segmented health VALUE bar as
## the DLC chapters, and that it (not overhead talisman shards) shows hits.
##
##   ... --headless --path . res://scripts/level03/tests/health_bar_test.tscn

const LEVEL_03: String = "res://scenes/level_03.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("L3_HEALTH_BAR_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _cleanup() -> void:
	get_tree().paused = false
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		if current.has_method("get_music"):
			var music: BaseLevelMusic = current.call("get_music") as BaseLevelMusic
			if music != null:
				music.stop(0.0)
		current.queue_free()
	await _wait_process(8)


func _run() -> void:
	var level: Level03 = (load(LEVEL_03) as PackedScene).instantiate() as Level03
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(4)
	await _wait_physics(8)

	var hud: L3HUD = level.get_hud()
	var player: L3Player = level.get_player()
	var guard: L3Guard = level.get_guard()
	_check(hud != null and player != null and guard != null,
		"level 03 exposes HUD, player and guard")
	if hud == null:
		return
	var bar: PlayerHealthBar = hud.get_player_health_bar()
	_check(bar != null and bar.get_style_name() == "bar"
		and not bar.is_heart_style(),
		"health display is the shared red bar, not hearts")
	_check(bar.get_current() == 2 and bar.get_max() == 2,
		"bar starts with two full segments",
		"%d / %d" % [bar.get_current(), bar.get_max()])
	_check(hud.get_health_bar_rect().position == Vector2(14.0, 324.0),
		"bar is fixed at (14,324)", str(hud.get_health_bar_rect()))
	var rects: Array[Rect2] = bar.get_segment_rects()
	_check(rects.size() == 2
		and rects[0].size == Vector2(14.0, 8.0)
		and rects[1].position.x == 30.0,
		"bar has two 14x8 segments with a 2 px gap", str(rects))
	_check(bar.get_heart_rect().size == Vector2(10.0, 10.0),
		"bar has the 10x10 heart at its left", str(bar.get_heart_rect()))
	_check(bar.filled_color == Color("#d95757")
		and bar.low_color == Color("#ff7b7b")
		and bar.empty_color == Color(0.13, 0.07, 0.08, 0.98),
		"bar uses the approved red / bright-red / dark-empty colours",
		"%s / %s" % [bar.filled_color, bar.low_color])
	_check(hud.get_health_label() == null,
		"no 生命值 word label remains on the HUD")
	_check(hud.is_health_bar_visible(), "bar is visible in normal gameplay")

	# The bar is screen-fixed: moving the body cannot drag it.  Stay within the
	# real combat read (<=165 px from the guard, floor height) so the level's
	# HUD update keeps the hit value instead of clearing it outside combat.
	guard.set_suspended(true)
	player.global_position = Vector2(2000.0, 320.0)
	player.velocity = Vector2.ZERO
	await _wait_physics(4)
	_check(hud.get_health_bar_rect().position == Vector2(14.0, 324.0),
		"bar does not follow the player", str(hud.get_health_bar_rect()))

	# Pause hides the bar; resume restores it.  There is no separate word label.
	var pause_menu: Node = level.get_pause_menu()
	_check(pause_menu != null and pause_menu.has_method("open_pause"),
		"level 03 exposes the shared pause page")
	if pause_menu != null:
		pause_menu.call("open_pause")
		await _wait_process(4)
		_check(get_tree().paused and hud.is_pause_visible(),
			"pause page really opens and pauses the tree")
		_check(not hud.is_health_bar_visible(),
			"pause page hides the fixed health bar")
		_check(hud.get_health_label() == null,
			"pause page has no 生命值 word to hide")
		_check(hud.get_health_bar_rect().position == Vector2(14.0, 324.0),
			"pause keeps the bar anchored at (14,324)",
			str(hud.get_health_bar_rect()))
		pause_menu.call("resume")
		await _wait_process(4)
		_check(not get_tree().paused and hud.is_health_bar_visible(),
			"resume restores the fixed health bar")

	# Recovery cover and completion page are modal reads: both hide the bar.
	hud.set_recovery_alpha(0.5)
	await _wait_process(2)
	_check(not hud.is_health_bar_visible(), "recovery cover hides the health bar")
	hud.set_recovery_alpha(0.0)
	await _wait_process(2)
	_check(hud.is_health_bar_visible(), "recovery end restores the health bar")
	hud.show_completion(true)
	await _wait_process(2)
	_check(not hud.is_health_bar_visible(), "completion page hides the health bar")
	hud.show_completion(false)
	await _wait_process(2)
	_check(hud.is_health_bar_visible(), "closing completion restores the health bar")

	# The real guard hit path (used by gameplay) drops the bar segment.
	_check(hud.get_hits() == 0 and bar.get_current() == 2,
		"no hits before the guard strike")
	guard.player_struck.emit(1)
	await _wait_process(3)
	_check(hud.get_hits() == 1 and bar.get_current() == 1,
		"first accepted hit drops the bar to one segment",
		"hits=%d current=%d" % [hud.get_hits(), bar.get_current()])
	_check(hud.get_health_bar_rect().position == Vector2(14.0, 324.0),
		"hit keeps the bar fixed at (14,324)")
	guard.player_struck.emit(1)
	await _wait_process(3)
	_check(hud.get_hits() == 2 and bar.get_current() == 0,
		"second accepted hit empties the two-segment bar",
		"hits=%d current=%d" % [hud.get_hits(), bar.get_current()])
