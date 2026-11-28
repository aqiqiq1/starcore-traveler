extends Node

## Acceptance test for the unified HUD (dlc/PRESENTATION_SYSTEM.md).
##
## Loads the three base levels and the three DLC chapters on their real scenes
## and checks, at 640x360:
##   - one top-left row: chapter 12 warm white + one objective 12 gold,
##     event replaces the objective, no second row / no affinity word;
##   - one shared 20x20 phase icon with a dark plate at the right-top;
##   - lower-left health group at (14,324): 10x10 heart + 14x8 cells, gap 2,
##     no "生命值" word;
##   - shared 360x16 boss bar for L3 guard / trial guard / mirror / loom,
##     hidden until the enemy appears, with DLC3 life hearts under it;
##   - pause / guide-popup / recovery / completion hide the chrome and restore.
##
## Run headless:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://scripts/ui/tests/hud_unified_test.tscn

const BASE_LEVELS: Array[Array] = [
	["res://scenes/level_01.tscn", "level_01", true],
	["res://scenes/level_02.tscn", "level_02", false],
	["res://scenes/level_03.tscn", "level_03", false],
]
const DLC_LEVELS: Array[Array] = [
	["res://dlc/trial_chambers/trial_chambers.tscn", "trial", "守卫"],
	["res://dlc/rift_workshop/rift_workshop.tscn", "rift", "双面镜"],
	["res://dlc/star_loom/star_loom.tscn", "loom", "织机"],
]

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	for entry: Array in BASE_LEVELS:
		await _test_base(String(entry[0]), String(entry[1]), bool(entry[2]))
	for entry: Array in DLC_LEVELS:
		await _test_dlc(String(entry[0]), String(entry[1]), String(entry[2]))
	DemoAudio.stop_world()
	print("HUD_UNIFIED_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _load_level(path: String, no_menu: bool) -> Node:
	var level: Node = (load(path) as PackedScene).instantiate()
	if no_menu:
		level.set("enable_start_menu", false)
	if _has_property(level, "show_intro_guide"):
		level.set("show_intro_guide", false)
	if _has_property(level, "show_intro_cinematic"):
		level.set("show_intro_cinematic", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(8)
	await _wait_physics(6)
	return level


func _has_property(object: Object, property_name: String) -> bool:
	for entry: Dictionary in object.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false


func _cleanup(level: Node) -> void:
	DemoAudio.stop_world()
	get_tree().paused = false
	get_tree().current_scene = null
	level.queue_free()
	await _wait_process(6)


func _test_base(path: String, tag: String, finish_intro: bool) -> void:
	print("=== %s ===" % tag.to_upper())
	var level: Node = await _load_level(path, tag == "level_01")
	if finish_intro:
		level.call("_finish_intro")
		await _wait_process(4)
	var hud: Node = level.get_node_or_null("HUD")
	_check(hud != null, tag + " has a HUD")
	if hud == null:
		await _cleanup(level)
		return
	await _check_common(hud, tag, "断桥庭院" if tag == "level_01" else ("沉寂回廊" if tag == "level_02" else "断桥外郭"))
	var bar: PlayerHealthBar = hud.call("get_player_health_bar") as PlayerHealthBar
	_check_health_bar(bar, tag, 3 if tag != "level_03" else 2)

	if tag == "level_03":
		var boss: HudBossBar = hud.call("get_boss_bar") as HudBossBar
		_check_boss_bar(boss, tag, "守卫", false)
		if boss != null:
			_check(not boss.is_bar_visible(), tag + " boss bar starts hidden")
			hud.call("set_boss_state", 3, 3)
			hud.call("set_boss_visible", true)
			await _wait_process(14)
			_check(boss.is_bar_visible(), tag + " boss bar fades in with the guard")
			_check(boss.get_core_hp() == 3 and boss.get_core_max() == 3,
				tag + " boss bar uses the guard's existing three points")
			_check(not boss.are_faces_visible() and boss.get_node_icon_count() == 0,
				tag + " guard bar has no independent-object icons")
		var guard: L3Guard = level.call("get_guard") as L3Guard
		_check(guard != null and guard.is_health_bar_suppressed(),
			tag + " old guard overhead bar is suppressed")

	# Modal completion hides all chrome, closing restores it.
	hud.call("show_completion", true, 1)
	await _wait_process(3)
	_check_chrome_hidden(hud, tag, "completion")
	hud.call("show_completion", false)
	await _wait_process(3)
	_check_chrome_visible(hud, tag, "completion close")

	# A paused guide/popup is the same rule; no separate HUD panel survives.
	get_tree().paused = true
	await _wait_process(2)
	_check_chrome_hidden(hud, tag, "paused guide/popup")
	get_tree().paused = false
	await _wait_process(2)
	_check_chrome_visible(hud, tag, "guide/popup close")

	await _cleanup(level)


func _test_dlc(path: String, tag: String, boss_name: String) -> void:
	print("=== %s ===" % tag.to_upper())
	var level: Node = await _load_level(path, false)
	var hud: Node = level.get_node_or_null("HUD")
	_check(hud != null, tag + " has a HUD")
	if hud == null:
		await _cleanup(level)
		return
	var expected_chapter: String = "星核试炼场" if tag == "trial" else ("裂隙工坊" if tag == "rift" else "星核织机")
	await _check_common(hud, tag, expected_chapter)
	var health: PlayerHealthBar = (
		hud.call("get_player_health_bar") as PlayerHealthBar
		if hud.has_method("get_player_health_bar")
		else hud.call("get_hit_pips") as PlayerHealthBar
	)
	_check_health_bar(health, tag, 3 if tag in ["loom", "rift"] else 2)

	var boss: HudBossBar
	if tag == "rift":
		boss = hud.call("get_boss_status") as HudBossBar
	else:
		boss = hud.call("get_boss_bar") as HudBossBar
	_check_boss_bar(boss, tag, boss_name, tag in ["loom", "rift"])
	if boss != null:
		_check(not boss.is_bar_visible(), tag + " boss bar starts hidden")
		if tag == "trial":
			hud.call("set_boss_state", 3, 3)
		elif tag == "rift":
			hud.call("set_boss_state", 0, 3, 3, 3, true, true, false)
		else:
			hud.call("set_boss_state", 2, 3, 1, 1, 3, true, 1, 3, 2, 3)
		hud.call("set_boss_visible", true)
		await _wait_process(14)
		_check(boss.is_bar_visible(), tag + " boss bar fades in with the enemy")
		_check(boss.get_name_text() == boss_name,
			tag + " boss bar uses the shared name row", boss.get_name_text())
		if tag == "rift":
			_check(boss.are_faces_visible() and boss.get_face_icon_count() == 2,
				tag + " mirror keeps its two face-plate icons",
				str(boss.get_face_icon_count()))
			_check(not boss.has_core_diamonds() and boss.get_core_diamond_count() == 0,
				tag + " mirror has no duplicate core diamonds")
		elif tag == "loom":
			_check(boss.is_nodes_visible() and boss.get_node_icon_count() == 2,
				tag + " loom keeps its two orbit-node diamonds",
				str(boss.get_node_icon_count()))
			_check(not boss.has_core_diamonds() and boss.get_core_diamond_count() == 0,
				tag + " loom has no duplicate core diamonds")
			_check(boss.is_lives_visible() and boss.get_lives_current() == 2
				and boss.get_lives_max() == 3,
				tag + " three life hearts sit under the boss bar",
				"%d/%d" % [boss.get_lives_current(), boss.get_lives_max()])

	# Pause and completion hide the chrome; recovery uses the same group.
	hud.call("show_pause", true)
	await _wait_process(3)
	_check_chrome_hidden(hud, tag, "pause")
	hud.call("show_pause", false)
	await _wait_process(3)
	_check_chrome_visible(hud, tag, "pause close")
	hud.call("show_completion", true, 1.0)
	await _wait_process(3)
	_check_chrome_hidden(hud, tag, "completion")
	hud.call("show_completion", false)
	await _wait_process(3)
	_check_chrome_visible(hud, tag, "completion close")
	if tag != "loom":
		hud.call("set_recovery_alpha", 0.5)
		await _wait_process(2)
		_check_chrome_hidden(hud, tag, "recovery")
		hud.call("set_recovery_alpha", 0.0)
		await _wait_process(2)
		_check_chrome_visible(hud, tag, "recovery close")

	await _cleanup(level)


func _check_common(hud: Node, tag: String, expected_chapter: String) -> void:
	var header: HudObjective
	if hud.has_method("get_compact_header"):
		header = hud.call("get_compact_header") as HudObjective
	else:
		header = hud.call("get_header") as HudObjective
	_check(header != null, tag + " uses the shared HudObjective / CompactLevelHeader")
	if header == null:
		return
	_check(header.get_title_text() == expected_chapter,
		tag + " chapter text is the chapter name", header.get_title_text())
	_check(not header.get_display_objective_text().is_empty(),
		tag + " has a visible one-line objective", header.get_display_objective_text())
	_check(header.get_phase_icon() is PolarityPhaseIcon,
		tag + " top-right icon is the shared PolarityPhaseIcon")
	_check(header.get_icon_size().is_equal_approx(Vector2(20.0, 20.0)),
		tag + " phase icon is 20x20", str(header.get_icon_size()))
	_check(header.get_icon_rect().position == Vector2(610.0, 4.0),
		tag + " phase icon sits at the approved right-top slot",
		str(header.get_icon_rect()))
	_check(header.get_node_or_null("AffinityText") == null,
		tag + " has no 相 / 辉相 / 澜相 text node")
	_check(not header.is_phase_text_visible(), tag + " phase text is not visible")

	var title_rect: Rect2 = header.get_title_rect()
	var objective_rect: Rect2 = header.get_subtitle_rect()
	_check(absf(title_rect.position.y - objective_rect.position.y) < 0.01,
		tag + " chapter and objective share one baseline",
		"%s / %s" % [str(title_rect.position), str(objective_rect.position)])
	_check(objective_rect.position.x >= title_rect.position.x + title_rect.size.x,
		tag + " objective starts after the measured chapter name")
	_check(title_rect.position.y <= 8.0,
		tag + " top-left row is at the top edge", str(title_rect.position))

	var visible_sizes: Array[int] = []
	for node: Node in header.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.is_visible_in_tree():
			visible_sizes.append(label.get_theme_font_size("font_size"))
	_check(visible_sizes.size() == 2 and visible_sizes.count(12) == 2,
		tag + " only chapter + objective labels are visible, both 12 px",
		str(visible_sizes))

	# A running event still uses the same slot, never a second line.
	header.show_event("事件测试", 1.0)
	await _wait_process(4)
	_check(header.is_event_visible(), tag + " event takes over the objective slot")
	_check(header.get_event_text() == "事件测试", tag + " event text is readable")
	var event_label: Label = header.get_node("EventLabel") as Label
	_check(event_label != null and absf(event_label.position.y - objective_rect.position.y) < 0.01,
		tag + " event is on the same row as the objective")
	header.clear_event()

	var forbidden_font: bool = false
	for node: Node in hud.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label == null or not label.is_visible_in_tree():
			continue
		var font_size: int = label.get_theme_font_size("font_size")
		if font_size == 7 or font_size == 8 or font_size == 9 or font_size == 10:
			forbidden_font = true
			break
	_check(not forbidden_font, tag + " no 9/10 px HUD label survives")


func _check_health_bar(bar: PlayerHealthBar, tag: String, expected_segments: int) -> void:
	_check(bar != null, tag + " exposes the shared PlayerHealthBar")
	if bar == null:
		return
	_check(bar.position == Vector2(14.0, 324.0),
		tag + " health group is fixed at (14,324)", str(bar.position))
	_check(bar.get_max() == expected_segments,
		tag + " health bar has %d cells" % expected_segments, str(bar.get_max()))
	_check(bar.get_heart_rect().size == Vector2(10.0, 10.0),
		tag + " has a 10x10 heart at the left", str(bar.get_heart_rect()))
	var rects: Array[Rect2] = bar.get_segment_rects()
	var gap_ok: bool = rects.size() >= 2 and (
		rects[1].position.x - rects[0].position.x - rects[0].size.x
	) == 2.0
	_check(rects.size() == expected_segments
		and rects[0].size == Vector2(14.0, 8.0) and gap_ok,
		tag + " cells are 14x8 with a 2 px gap", str(rects))
	_check(rects[0].position.x >= 14.0,
		tag + " hearts sits left of the first red cell", str(rects[0].position))
	for node: Node in bar.find_children("*", "Label", true, false):
		var label: Label = node as Label
		_check(label == null or not label.text.contains("生命值"),
			tag + " health bar has no 生命值 word")


func _check_boss_bar(bar: HudBossBar, tag: String, expected_name: String, hearts: bool) -> void:
	_check(bar != null, tag + " exposes the shared HudBossBar")
	if bar == null:
		return
	_check(bar.size.is_equal_approx(Vector2(360.0, 16.0)),
		tag + " boss bar is 360x16", str(bar.size))
	_check(bar.position == Vector2(140.0, 22.0),
		tag + " boss bar is top-centre", str(bar.position))
	_check(bar.get_name_text() == expected_name,
		tag + " boss bar name is 12 px data text", bar.get_name_text())
	_check(bar.get_node_or_null("AffinityText") == null,
		tag + " boss bar has no separate affinity text")
	_check(bar.is_lives_visible() == hearts,
		tag + " life hearts follow the DLC boss bar", str(bar.is_lives_visible()))
	_check(not bar.has_core_diamonds() and bar.get_core_diamond_count() == 0,
		tag + " boss bar has no core diamond row",
		str(bar.get_core_diamond_count()))
	_check(bar.get_red_bar_segment_count() == 3,
		tag + " red core bar is split into three true-damage segments",
		str(bar.get_red_bar_segment_count()))
	var segments: Array[Rect2] = bar.get_red_segment_rects()
	_check(segments.size() == 3,
		tag + " red bar exposes three segment rects", str(segments.size()))
	if segments.size() == 3:
		var gap: float = segments[1].position.x - segments[0].end.x
		_check(absf(gap - 1.0) < 0.01 and segments[0].size.x >= 50.0,
			tag + " red segments are equal 52 px cells with 1 px gaps",
			"w=%.0f gap=%.0f" % [segments[0].size.x, gap])


func _check_chrome_hidden(hud: Node, tag: String, state: String) -> void:
	var header: HudObjective = (
		hud.call("get_compact_header") as HudObjective
		if hud.has_method("get_compact_header")
		else hud.call("get_header") as HudObjective
	)
	_check(header != null and not header.is_chrome_visible(),
		tag + " " + state + " hides chapter/objective/icon")
	_check(not bool(hud.call("is_health_bar_visible")),
		tag + " " + state + " hides the health bar")
	var boss: HudBossBar = null
	if hud.has_method("get_boss_bar"):
		boss = hud.call("get_boss_bar") as HudBossBar
	elif hud.has_method("get_boss_status"):
		boss = hud.call("get_boss_status") as HudBossBar
	if boss != null:
		_check(boss.is_modal_suppressed() or not boss.is_bar_visible(),
			tag + " " + state + " hides the boss bar")


func _check_chrome_visible(hud: Node, tag: String, state: String) -> void:
	var header: HudObjective = (
		hud.call("get_compact_header") as HudObjective
		if hud.has_method("get_compact_header")
		else hud.call("get_header") as HudObjective
	)
	_check(header != null and header.is_chrome_visible(),
		tag + " " + state + " restores chapter/objective/icon")
	_check(bool(hud.call("is_health_bar_visible")),
		tag + " " + state + " restores the health bar")
