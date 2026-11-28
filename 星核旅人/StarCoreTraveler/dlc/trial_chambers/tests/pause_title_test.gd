extends Node

## Focused check that the pause page's 返回主界面 entry really returns to the
## title scene (继续游戏 and 重新开始本章 are covered here and in route_test).
##
##   ... --headless --path . res://dlc/trial_chambers/tests/pause_title_test.tscn

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("TRIAL_PAUSE_TITLE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_physics(2)
	_push_key(code, false)
	await _wait_physics(2)


func _cleanup() -> void:
	var current: Node = get_tree().current_scene
	# The 返回主界面 route starts the title BGM; stop it before freeing the
	# scene so the engine's exit teardown does not report a false resource leak.
	if current != null:
		var menu: Node = current.get_node_or_null("StartMenu")
		if menu != null and menu.has_method("stop_title_music_for_test"):
			menu.call("stop_title_music_for_test")
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(20)


func _run() -> void:
	var trial: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	trial.show_intro_guide = false
	trial.show_intro_cinematic = false
	trial.show_mechanic_tips = false
	get_tree().root.add_child(trial)
	get_tree().current_scene = trial
	await _wait_process(3)
	await _wait_physics(6)

	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	_check(trial.is_pause_open(), "Esc opens the pause page")
	var hud: TrialHUD = trial.get_hud()
	_check(hud.get_continue_button().has_focus(), "继续游戏 starts focused")
	_check(hud.get_pause_subtitle_text() == "星核试炼场 · 支线试炼",
		"pause subtitle is 星核试炼场 · 支线试炼", hud.get_pause_subtitle_text())
	var health_bar: PlayerHealthBar = hud.get_hit_pips()
	_check(health_bar != null and health_bar.get_style_name() == "bar",
		"pause keeps the shared red health bar as the value display")
	_check(hud.get_hit_pips_current() == 2 and hud.get_hit_pips_max() == 2,
		"pause page leaves the two bar segments intact",
		"%d / %d" % [hud.get_hit_pips_current(), hud.get_hit_pips_max()])
	_check(hud.get_hit_pips_position() == Vector2(14.0, 324.0),
		"pause bar stays fixed at (14,324)", str(hud.get_hit_pips_position()))
	_check(not hud.is_hit_pips_visible(),
		"pause page hides the fixed health bar")
	_check(hud.get_continue_button().text == "继续游戏"
		and hud.get_restart_button().text == "重新开始本章"
		and hud.get_title_button().text == "返回主界面"
		and hud.get_quit_button().text == "退出游戏"
		and hud.get_pause_controls_button().text == "操作"
		and hud.get_manual_button().text == "手册",
		"pause page exposes all six entries")
	_check(hud.get_continue_button().get_node(hud.get_continue_button().focus_next)
		== hud.get_restart_button(),
		"continue focus_next reaches restart")
	_check(hud.get_quit_button().get_node(hud.get_quit_button().focus_next)
		== hud.get_pause_controls_button(),
		"quit focus_next reaches 操作")
	_check(hud.get_pause_controls_button().get_node(
		hud.get_pause_controls_button().focus_next) == hud.get_manual_button(),
		"操作 focus_next reaches 手册")
	_check(hud.get_manual_button().get_node(
		hud.get_manual_button().focus_next) == hud.get_continue_button(),
		"手册 focus_next cycles to continue")
	_check(hud.get_pause_controls_button().position == Vector2(76.0, 192.0)
		and hud.get_manual_button().position == Vector2(184.0, 192.0),
		"操作 / 手册 share the last row")

	# Down once reaches 重新开始本章 and really resets the chapter.
	await _tap_key(KEY_DOWN)
	await _wait_process(3)
	_check(hud.get_restart_button().has_focus(), "Down moves focus to 重新开始本章")
	await _tap_key(KEY_ENTER)
	await _wait_process(5)
	_check(not trial.is_pause_open(), "重新开始本章 closes the pause page")
	_check(not get_tree().paused, "重新开始本章 unpauses the tree")
	_check(absf(trial.get_player().global_position.x - trial.get_start_spawn().x) < 2.0,
		"重新开始本章 returns to the entrance",
		"x=%.2f" % trial.get_player().global_position.x)
	_check(not trial.is_completed(), "重新开始本章 clears completion")

	# Reopen and move focus to 返回主界面, then activate it with the real key path.
	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	await _tap_key(KEY_DOWN)
	await _tap_key(KEY_DOWN)
	await _wait_process(3)
	_check(hud.get_title_button().has_focus(), "Down twice moves focus to 返回主界面")
	await _tap_key(KEY_ENTER)
	var changed: bool = false
	for _index: int in range(120):
		var current: Node = get_tree().current_scene
		if current != null and current != trial:
			changed = true
			break
		await get_tree().process_frame
	await _wait_process(4)
	var current: Node = get_tree().current_scene
	var path: String = current.scene_file_path if current != null else ""
	_check(changed and path == LEVEL_01, "pause 返回主界面 returns to level_01.tscn", path)
	_check(not get_tree().paused, "returning clears the tree pause")
