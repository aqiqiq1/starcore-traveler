extends Node

## Hidden-side light hints: the first recorded DLC3 checkpoint names the mirror
## once per save, and the chapter page shows a weak footer only while the rift
## is still undiscovered.
##
## Covers:
##   - the exact HUD line on the first checkpoint trigger;
##   - the marker file written when the line is really shown;
##   - a second chapter start (restart) does not repeat it and falls back to the
##     existing "检查点已记录 · 失败从门前恢复" line;
##   - a fresh save that still needs the checkpoint lesson gets the lesson
##     first and the mirror nudge after it, never two lines at once;
##   - the footer line/12 px/slot/ring checks plus discovery and kskbl removal
##     live in dlc/chapter_select/tests/chapter_select_test.gd.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/star_loom/tests/hidden_hint_test.tscn

const HIDDEN_HINT = preload("res://dlc/shared/side_route/hidden_hint_progress.gd")
const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const P_HINT: String = "user://hidden_hint_test.cfg"
const P_MECH: String = "user://hidden_hint_test_mechanics.cfg"
const P_CHAPTER: String = "user://hidden_hint_test_chapters.cfg"
const CHECKPOINT_LINE: String = "检查点已记录 · 失败从门前恢复"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_remove_test_files()
	MechanicTeach.set_progress_path_override(P_MECH)
	await _test_first_checkpoint_and_restart()
	await _test_teaching_line_is_not_clobbered()
	_remove_test_files()
	MechanicTeach.clear_progress_path_override()
	print("HIDDEN_HINT_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	await _wait_process(10)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _remove_test_files() -> void:
	for path: String in [P_HINT, P_MECH, P_CHAPTER]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _load_loom() -> StarLoom:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		_check(false, "star_loom scene loads")
		return null
	var loom: StarLoom = packed.instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = false
	loom.hint_progress_path = P_HINT
	loom.chapter_progress_path = P_CHAPTER
	get_tree().root.add_child(loom)
	get_tree().current_scene = loom
	await _wait_process(6)
	await _wait_physics(10)
	# Teleport tests start from the real post-bay approach state: the core is
	# seated, so the checkpoint is the only new event this frame.  (Walking the
	# whole puzzle is gate_test's job.)
	var carrier: CoreDeliveryCarrier = loom.get_core_carrier()
	if carrier != null:
		carrier.debug_set_x(carrier.socket_x)
	await _wait_physics(6)
	return loom


func _touch_checkpoint(loom: StarLoom) -> void:
	var player: L3Player = loom.get_player()
	var checkpoint: LevelCheckpoint = loom.get_checkpoint()
	player.global_position = checkpoint.global_position
	player.velocity = Vector2.ZERO
	await _wait_physics(8)


func _drop_loom(loom: StarLoom) -> void:
	get_tree().paused = false
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().current_scene = null
	if loom != null and is_instance_valid(loom):
		loom.queue_free()
	await _wait_process(12)


func _test_first_checkpoint_and_restart() -> void:
	print("=== FIRST CHECKPOINT ===")
	var loom: StarLoom = await _load_loom()
	if loom == null:
		return
	# Simulate the normal save: the checkpoint was already taught in L1/L2/L3,
	# so this trigger must produce only the mirror line.
	loom.get_mechanic_teach().mark_unlocked("checkpoint")
	await _touch_checkpoint(loom)
	var checkpoint: LevelCheckpoint = loom.get_checkpoint()
	var hud: LoomHUD = loom.get_hud()
	_check(checkpoint.is_activated(), "the checkpoint activates")
	_check(hud.get_event_text() == loom.get_checkpoint_mirror_hint_text(),
		"the first checkpoint shows the mirror nudge", hud.get_event_text())
	_check(not hud.get_event_text().contains("失败从门前恢复"),
		"the first line is not the generic checkpoint line")
	_check(HIDDEN_HINT.is_shown(HIDDEN_HINT.CHECKPOINT_MIRROR, P_HINT),
		"showing the line writes the one-shot marker")
	_check(not loom.is_checkpoint_mirror_hint_queued(),
		"the shown hint leaves nothing queued")
	await _drop_loom(loom)

	# Second chapter start with the same hint file: no repeat.
	loom = await _load_loom()
	if loom == null:
		return
	loom.get_mechanic_teach().mark_unlocked("checkpoint")
	await _touch_checkpoint(loom)
	checkpoint = loom.get_checkpoint()
	hud = loom.get_hud()
	_check(checkpoint.is_activated(), "the restarted checkpoint activates")
	_check(hud.get_event_text() == CHECKPOINT_LINE,
		"a restart does not repeat the mirror nudge", hud.get_event_text())
	_check(hud.get_event_text() != loom.get_checkpoint_mirror_hint_text(),
		"the restart line is the old generic checkpoint line")
	await _drop_loom(loom)


func _test_teaching_line_is_not_clobbered() -> void:
	print("=== TEACHING ORDER ===")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P_HINT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P_MECH))
	var loom: StarLoom = await _load_loom()
	if loom == null:
		return
	var hud: LoomHUD = loom.get_hud()
	await _touch_checkpoint(loom)
	var first_line: String = hud.get_event_text()
	_check(first_line == REGISTRY.get_summary("checkpoint"),
		"a fresh save gets the checkpoint lesson first", first_line)
	_check(first_line != loom.get_checkpoint_mirror_hint_text(),
		"the mirror nudge does not replace the lesson")
	_check(not HIDDEN_HINT.is_shown(HIDDEN_HINT.CHECKPOINT_MIRROR, P_HINT),
		"the marker waits until the nudge is really shown")
	await _wait_seconds(2.9)
	_check(hud.get_event_text() == loom.get_checkpoint_mirror_hint_text(),
		"the mirror nudge follows the lesson", hud.get_event_text())
	_check(HIDDEN_HINT.is_shown(HIDDEN_HINT.CHECKPOINT_MIRROR, P_HINT),
		"the delayed nudge writes the marker")
	await _drop_loom(loom)
