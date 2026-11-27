extends Node

## Audits the new-game hand-off:
##   title click -> full-black fade -> real change_scene -> fresh level_01 whose
##   first opening frame is already black.
## The old world and HUD must stay hidden throughout the fade, and the scene
## change may only be requested after the black overlay is exactly 1.0.

const LEVEL_SCENE: String = "res://scenes/level_01.tscn"
const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")

var _checks: int = 0
var _failures: Array[String] = []
var _change_alpha: float = -1.0
var _change_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("START_TRANSITION_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	LEVEL_FLOW.clear_new_game_request()
	var level: Level01 = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level01
	level.enable_start_menu = true
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(6)
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	_check(menu != null and menu.is_menu_open(), "title menu is open")
	if menu == null:
		return
	_check(menu.get_start_fade_duration() >= 0.8
		and menu.get_start_fade_duration() <= 1.2,
		"start fade duration is 0.8-1.2 s", str(menu.get_start_fade_duration()))
	_check(not level.get_node("World").visible,
		"title menu keeps the world hidden before start")
	_check(not level.get_hud().visible,
		"title menu keeps the HUD hidden before start")
	menu.start_scene_change_requested.connect(_on_start_scene_change)

	menu.get_start_button().pressed.emit()
	await _wait_process(2)
	_check(menu.get_phase_name() == "start_fade",
		"start enters the black fade phase", menu.get_phase_name())
	_check(menu.is_start_black_visible(), "start black overlay is visible")
	var early_alpha: float = menu.get_start_black_alpha()
	_check(early_alpha >= 0.0 and early_alpha < 1.0,
		"black overlay starts below 1.0", str(early_alpha))
	_check(not level.get_node("World").visible,
		"no world frame is exposed during the fade")
	_check(not level.get_hud().visible,
		"no HUD frame is exposed during the fade")

	await get_tree().create_timer(0.35).timeout
	_check(menu.get_start_black_alpha() > 0.10,
		"black overlay is rising", str(menu.get_start_black_alpha()))
	_check(_change_count == 0, "scene change does not happen before full black")

	var deadline: int = Time.get_ticks_msec() + 3000
	while _change_count == 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_change_count == 1, "scene change was requested exactly once")
	_check(_change_alpha >= 0.999,
		"scene change requested only at alpha 1", str(_change_alpha))

	var new_level: Level01 = null
	for _index: int in range(180):
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if current is Level01 and current != level:
			new_level = current as Level01
			break
	_check(new_level != null, "fresh level_01 became current")
	if new_level == null:
		return
	_check(not new_level.is_start_menu_enabled(),
		"new level skips the title menu")
	_check(new_level.is_intro_active(), "new level starts the opening film")
	var opening: OpeningCinematic = new_level.get_opening()
	_check(opening != null and opening.get_play_count() == 1,
		"new level starts exactly one opening")
	if opening != null:
		_check(opening.get_black_alpha() >= 0.999,
			"new level's first frame is covered by black",
			str(opening.get_black_alpha()))
		_check(opening.is_ui_visible(), "opening black UI is visible")
		_check(get_viewport().get_camera_2d() == opening.get_opening_camera(),
			"new level uses the authored opening camera")
		opening.abort()
	await _wait_process(8)


func _on_start_scene_change(alpha: float) -> void:
	_change_alpha = alpha
	_change_count += 1


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _cleanup() -> void:
	get_tree().paused = false
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
		for _index: int in range(24):
			await get_tree().process_frame
	print("START_TRANSITION_TEST cleanup")
