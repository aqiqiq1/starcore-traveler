extends Node

## Acceptance for the first-encounter teaching + pause manual.
##
## Headless:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://scripts/ui/tests/mechanic_manual_test.tscn
##
## Covers:
##   - registry shape, 12 px summary budget, icon vocabulary
##   - first request shows once, second request and a fresh node stay silent
##   - missing/corrupt progress files never crash and start empty
##   - manual shows unlocked registry copy and ？？？ for locked rows
##   - Esc, F and the 返回 button close the page
##   - the six chapter pause pages expose a working 手册 entry

const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")
const TEST_PATH: String = "user://test_mechanic_manual_acceptance.cfg"

const BASE_PAUSE = preload("res://scripts/ui/pause_menu.gd")
const L3_PAUSE = preload("res://scripts/level03/l3_pause_menu.gd")

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	print("MECHANIC_MANUAL_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		print("FAIL: %s" % failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: %s%s" % [label, (" [%s]" % detail) if not detail.is_empty() else ""])
		return
	_failures.append(label + ((" [" + detail + "]") if not detail.is_empty() else ""))
	print("FAIL: %s%s" % [label, (" [%s]" % detail) if not detail.is_empty() else ""])


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _remove_file(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _make_teach(lines: Array[String]) -> MechanicTeach:
	var teach: MechanicTeach = MechanicTeach.new()
	teach.name = "TeachUnderTest"
	teach.show_line = func(text_value: String) -> void:
		lines.append(text_value)
	teach.blocked_check = func() -> bool: return false
	add_child(teach)
	return teach


func _push_key(key: int) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key as Key
	down.keycode = key as Key
	down.pressed = true
	get_viewport().push_input(down)
	await _wait_process(2)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key as Key
	up.keycode = key as Key
	up.pressed = false
	get_viewport().push_input(up)
	await _wait_process(2)


func _run() -> void:
	MechanicTeach.set_progress_path_override(TEST_PATH)
	_remove_file(TEST_PATH)

	# --- registry --------------------------------------------------------
	_check(REGISTRY.count() >= 15, "registry has at least 15 mechanics", str(REGISTRY.count()))
	var required: Array[String] = [
		"polarity", "gate", "rune", "bay", "checkpoint", "guard",
		"inversion", "bridge", "core_delivery", "loom_node", "fire",
		"gear", "wisp", "mirror", "lives",
	]
	for id: String in required:
		var entry: Dictionary = REGISTRY.get_entry(id)
		_check(not entry.is_empty(), "registry row exists: %s" % id)
		var summary: String = String(entry.get("summary", ""))
		_check(
			not summary.is_empty() and summary.length() <= 40,
			"row %s summary fits 40 cells" % id,
			"%d cells" % summary.length()
		)
		_check(not String(entry.get("name", "")).is_empty(), "row %s has a name" % id)
		var icon: Dictionary = REGISTRY.get_icon(id)
		var icon_kind: String = String(icon.get("kind", ""))
		_check(
			icon_kind in ["key", "phase", "heart"],
			"row %s has an existing-art icon" % id,
			icon_kind
		)

	# --- missing / corrupt progress --------------------------------------
	var missing_path: String = "user://definitely_missing_mechanic_progress.cfg"
	_remove_file(missing_path)
	var missing: Dictionary = MechanicTeach.load_unlocked_ids(missing_path)
	_check(missing.is_empty(), "missing progress loads as empty")

	_write_text(TEST_PATH, "[mechanics\ngate=maybe\npolarity=not-a-bool")
	var corrupt: Dictionary = MechanicTeach.load_unlocked_ids(TEST_PATH)
	_check(corrupt.is_empty(), "corrupt progress loads as empty, no crash")

	# --- first encounter / second / chapter change -----------------------
	_remove_file(TEST_PATH)
	var lines: Array[String] = []
	var teach: MechanicTeach = _make_teach(lines)
	await _wait_process(2)
	var first_request: bool = teach.request("gate")
	_check(first_request, "the first gate request displays immediately")
	_check(
		lines.size() == 1 and lines[0] == REGISTRY.get_summary("gate"),
		"the displayed line is the registry summary",
		str(lines)
	)
	_check(teach.is_unlocked("gate"), "first display records the gate")
	_check(FileAccess.file_exists(TEST_PATH), "mechanic_progress.cfg is written")
	var second_request: bool = teach.request("gate")
	_check(not second_request and lines.size() == 1, "the second approach stays silent")
	_check(teach.get_taught_count() == 1, "exactly one line was taught")

	var chapter_lines: Array[String] = []
	var chapter_two: MechanicTeach = _make_teach(chapter_lines)
	await _wait_process(2)
	var chapter_request: bool = chapter_two.request("gate")
	_check(
		not chapter_request and chapter_lines.is_empty(),
		"a later chapter does not re-teach the gate"
	)
	_check(chapter_two.is_unlocked("gate"), "the new chapter already sees the record")

	# Two more rows so the manual has a mixed page.
	chapter_two.mark_unlocked("polarity")
	chapter_two.mark_unlocked("rune")

	# --- manual ----------------------------------------------------------
	var manual: MechanicManual = MechanicManual.new()
	manual.name = "ManualUnderTest"
	manual.progress_path = TEST_PATH
	add_child(manual)
	await _wait_process(2)
	_check(manual.open(), "manual opens")
	_check(manual.is_open(), "manual reports open")
	var rows: Array[Dictionary] = manual.get_rows()
	_check(rows.size() == REGISTRY.count(), "manual lists one row per registry entry")
	var gate_row: Dictionary = {}
	for row: Dictionary in rows:
		if String(row.get("id", "")) == "gate":
			gate_row = row
	_check(
		String(gate_row.get("shown_name", "")) == REGISTRY.display_name("gate"),
		"unlocked row shows its real name"
	)
	_check(
		String(gate_row.get("shown_summary", "")) == REGISTRY.get_summary("gate"),
		"unlocked row shows its registry summary"
	)
	var locked_name: String = ""
	var locked_summary: String = ""
	for row: Dictionary in rows:
		if not bool(row.get("unlocked", false)):
			locked_name = String(row.get("shown_name", ""))
			locked_summary = String(row.get("shown_summary", ""))
			break
	_check(locked_name == "？？？", "locked row names are ？？？", locked_name)
	_check(locked_summary.is_empty(), "locked row detail stays blank", locked_summary)
	_check(
		manual.get_visible_unlocked_count() == 3 and manual.get_locked_count() == 12,
		"manual reports 3 unlocked / 12 locked",
		"%d / %d" % [manual.get_visible_unlocked_count(), manual.get_locked_count()]
	)
	var sizes: Array[int] = manual.get_row_font_sizes()
	var all_twelve: bool = not sizes.is_empty()
	for size_value: int in sizes:
		if size_value != 12:
			all_twelve = false
	_check(all_twelve, "every manual row uses 12 px", str(sizes))

	await _push_key(KEY_ESCAPE)
	_check(not manual.is_open(), "Esc closes the manual")
	_check(manual.open(), "manual reopens after Esc")
	await _push_key(KEY_F)
	_check(not manual.is_open(), "F closes the manual")
	_check(manual.open(), "manual reopens before the button check")
	var back: PixelMenuButton = manual.get_back_button()
	_check(back != null and back.text == "返回", "manual has a 返回 button")
	if back != null:
		back.pressed.emit()
		await _wait_process(2)
	_check(not manual.is_open(), "返回 closes the manual")
	manual.queue_free()
	await _wait_process(3)

	# --- real level trigger + cross-chapter silence ----------------------
	await _check_level_trigger_once()

	# --- six chapter pause pages -----------------------------------------
	await _check_shared_pause(BASE_PAUSE.new(), "shared/base pause")
	await _check_shared_pause(L3_PAUSE.new(), "L3 pause subclass")
	await _check_hud_pause(TrialHUD.new(), "DLC1 trial pause")
	await _check_hud_pause(RiftWorkshopHUD.new(), "DLC2 rift pause")
	await _check_hud_pause(LoomHUD.new(), "DLC3 loom pause")

	# Leave no pause state behind.
	get_tree().paused = false
	_remove_file(TEST_PATH)
	MechanicTeach.clear_progress_path_override()


func _check_level_trigger_once() -> void:
	_remove_file(TEST_PATH)
	var packed: PackedScene = load("res://scenes/level_01.tscn") as PackedScene
	_check(packed != null, "L1 loads for the real trigger check")
	if packed == null:
		return
	var level: Node = packed.instantiate()
	level.set("enable_start_menu", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(8)
	var opening: Node = level.call("get_opening") as Node
	if opening != null and bool(opening.call("is_active")):
		opening.call("abort")
	await _wait_process(4)
	get_tree().paused = false
	var player: Node2D = level.call("get_player") as Node2D
	var gate: Node2D = level.call("get_exit_polarity_gate") as Node2D
	var hud: Node = level.call("get_hud")
	var teach: MechanicTeach = level.call("get_mechanic_teach") as MechanicTeach
	_check(player != null and gate != null and hud != null and teach != null,
		"L1 exposes player, gate, HUD and teach")
	if player != null and gate != null and hud != null and teach != null:
		player.global_position = Vector2(gate.global_position.x - 56.0, 300.0)
		player.velocity = Vector2.ZERO
		player.set("allow_polarity_toggle", true)
		player.call("set_polarity_state", true)
		player.call("set_facing_direction", 1)
		await _wait_physics(4)
		await _wait_process(4)
		_check(teach.is_unlocked("gate"), "real L1 gate approach records the gate")
		_check(
			String(hud.call("get_toast_text")) == REGISTRY.get_summary("gate"),
			"real L1 gate approach shows the registry line",
			String(hud.call("get_toast_text"))
		)
		var taught_before: int = teach.get_taught_count()
		player.global_position = Vector2(gate.global_position.x - 240.0, 300.0)
		player.velocity = Vector2.ZERO
		await _wait_physics(4)
		hud.call("show_toast", "", 0.0)
		player.global_position = Vector2(gate.global_position.x - 56.0, 300.0)
		player.velocity = Vector2.ZERO
		player.call("set_facing_direction", 1)
		await _wait_physics(4)
		await _wait_process(4)
		_check(
			teach.get_taught_count() == taught_before
			and not bool(hud.call("is_toast_visible")),
			"the second L1 approach shows no second line",
			String(hud.call("get_toast_text"))
		)
	get_tree().current_scene = null
	level.queue_free()
	await _wait_process(12)
	get_tree().paused = false

	var loom_packed: PackedScene = load("res://dlc/star_loom/star_loom.tscn") as PackedScene
	_check(loom_packed != null, "DLC3 loads for the cross-chapter check")
	if loom_packed == null:
		return
	var loom: Node = loom_packed.instantiate()
	loom.set("show_intro_guide", false)
	loom.set("show_intro_cinematic", false)
	get_tree().root.add_child(loom)
	get_tree().current_scene = loom
	await _wait_process(10)
	get_tree().paused = false
	var loom_player: Node2D = loom.call("get_player") as Node2D
	var loom_gate: Node2D = loom.call("get_gate_first") as Node2D
	var loom_hud: Node = loom.call("get_hud")
	var loom_teach: MechanicTeach = loom.call("get_mechanic_teach") as MechanicTeach
	_check(loom_teach != null and loom_teach.is_unlocked("gate"),
		"DLC3 already sees the gate record")
	if loom_player != null and loom_gate != null and loom_hud != null and loom_teach != null:
		loom_player.global_position = Vector2(loom_gate.global_position.x - 56.0, 320.0)
		loom_player.velocity = Vector2.ZERO
		loom_player.call("face_direction", 1)
		await _wait_physics(4)
		await _wait_process(4)
		_check(
			int(loom.call("get_gate_hint_count")) >= 1,
			"the DLC3 gate approach trigger really ran"
		)
		_check(
			loom_teach.get_taught_count() == 0
			and not String(loom_hud.call("get_event_text")).contains(
				REGISTRY.get_summary("gate")
			),
			"the DLC3 gate does not re-teach an already seen gate",
			String(loom_hud.call("get_event_text"))
		)
	get_tree().current_scene = null
	loom.queue_free()
	await _wait_process(12)
	get_tree().paused = false


func _check_shared_pause(pause: Node, label: String) -> void:
	pause.set("controls_rows", [["移动", "A / D"], ["暂停菜单", "{ESC}"]])
	add_child(pause)
	await _wait_process(3)
	pause.call("open_pause")
	await _wait_process(2)
	var button: PixelMenuButton = pause.call("get_manual_button") as PixelMenuButton
	_check(button != null and button.text == "手册", "%s exposes 手册" % label)
	pause.call("open_manual")
	await _wait_process(2)
	_check(
		bool(pause.call("is_manual_open")),
		"%s opens the manual" % label
	)
	var manual: MechanicManual = pause.call("get_manual") as MechanicManual
	if manual != null and manual.is_open():
		manual.close()
	pause.call("force_close")
	await _wait_process(2)
	pause.queue_free()
	await _wait_process(3)


func _check_hud_pause(hud: CanvasLayer, label: String) -> void:
	add_child(hud)
	await _wait_process(3)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.call("show_pause", true)
	await _wait_process(2)
	var button: PixelMenuButton = hud.call("get_manual_button") as PixelMenuButton
	_check(button != null and button.text == "手册", "%s exposes 手册" % label)
	hud.call("open_manual")
	await _wait_process(2)
	_check(
		bool(hud.call("is_manual_open")),
		"%s opens the manual" % label
	)
	hud.call("show_pause", false)
	await _wait_process(2)
	hud.queue_free()
	await _wait_process(3)
