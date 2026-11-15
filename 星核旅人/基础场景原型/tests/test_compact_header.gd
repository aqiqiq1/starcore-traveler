extends Node

## Focused compact-header checks for both formal level HUDs.
## Run:
##   Godot --headless --path . res://tests/test_compact_header.tscn

const L1: PackedScene = preload("res://scenes/level_01.tscn")
const L2: PackedScene = preload("res://scenes/level_02.tscn")

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_level01()
	await _test_level02()
	await _test_title_menu_hides_hud()
	_write_log()
	print("COMPACT_HEADER_TEST pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _test_level01() -> void:
	var level: Level01 = L1.instantiate() as Level01
	level.enable_start_menu = false
	level.set("intro_max_duration", 0.05)
	add_child(level)
	await _frames(20)
	var hud: Level01HUD = level.get_hud()
	var header: CompactLevelHeader = hud.get_compact_header()
	_validate_header(header, "断桥庭院", "第一关", "L1")
	_check(hud.get_polarity_text() == "辉相", "L1 HUD getter returns gold affinity")
	await _key(KEY_Q)
	await _physics(4)
	_check(header.get_affinity_text() == "澜相", "L1 real Q switches to 澜相")
	_check(header.get_icon_texture_path().ends_with("talisman_cyan.png"), "L1 real Q uses cyan icon")
	await _key(KEY_Q)
	await _physics(4)
	_check(header.get_affinity_text() == "辉相", "L1 second Q returns 辉相")
	_check(header.get_icon_texture_path().ends_with("talisman_gold.png"), "L1 second Q uses gold icon")
	level.get_pause_menu().restart_requested.emit()
	await _frames(12)
	await _physics(4)
	_check(header.get_affinity_text() == "辉相", "L1 R restart restores gold text")
	_check(header.get_icon_texture_path().ends_with("talisman_gold.png"), "L1 R restart restores gold icon")
	hud.show_completion(true)
	hud.set_polarity(false)
	_check(header.get_affinity_text() == "澜相", "L1 completion page still updates header without null panel")
	hud.show_completion(false)
	hud.set_pause_visible(true)
	hud.set_polarity(true)
	_check(header.get_affinity_text() == "辉相", "L1 pause state leaves header usable")
	hud.set_pause_visible(false)
	level.queue_free()
	await _frames(4)


func _test_level02() -> void:
	var level: Level02 = L2.instantiate() as Level02
	add_child(level)
	await _frames(10)
	var hud: Level02HUD = level.get_hud()
	var header: CompactLevelHeader = hud.get_compact_header()
	_validate_header(header, "沉寂回廊", "第二关 · 石栅通路", "L2")
	_check(hud.get_polarity_text() == "辉相", "L2 HUD getter returns gold affinity")
	# Header ends at y=40; the existing L2 status block starts at y=54.
	_check(header.get_header_rect().end.y <= 40.0, "L2 compact header stays in the top 40 px")
	_check(header.get_header_rect().end.y < 54.0, "L2 header does not overlap the existing status block")
	await _key(KEY_Q)
	await _physics(4)
	_check(header.get_affinity_text() == "澜相", "L2 real Q switches to 澜相")
	_check(header.get_icon_texture_path().ends_with("talisman_cyan.png"), "L2 real Q uses cyan icon")
	await _key(KEY_Q)
	await _physics(4)
	_check(header.get_affinity_text() == "辉相", "L2 second Q returns 辉相")
	level.get_pause_menu().restart_requested.emit()
	await _frames(12)
	await _physics(4)
	_check(header.get_affinity_text() == "辉相", "L2 R restart restores gold text")
	_check(header.get_icon_texture_path().ends_with("talisman_gold.png"), "L2 R restart restores gold icon")
	level.get_pause_menu().open_pause()
	await _physics(2)
	hud.set_polarity(false)
	_check(header.get_affinity_text() == "澜相", "L2 pause state header has no null panel")
	level.get_pause_menu().resume()
	await _physics(4)
	hud.show_completion(true)
	hud.set_polarity(true)
	_check(header.get_affinity_text() == "辉相", "L2 completion page header has no null panel")
	hud.show_completion(false)
	_check(_same_l1_geometry(header), "L1 and L2 compact headers share exact geometry")
	level.queue_free()
	await _frames(4)


var _l1_header_geometry: Dictionary = {}


func _validate_header(header: CompactLevelHeader, title: String, subtitle: String, tag: String) -> void:
	_check(header != null, tag + " compact header exists")
	if header == null:
		return
	_check(header.get_title_text() == title, tag + " title text")
	_check(header.get_subtitle_text() == subtitle, tag + " chapter text")
	_check(header.get_affinity_text() == "辉相" or header.get_affinity_text() == "澜相", tag + " affinity word")
	_check(header.get_label_font_sizes() == [12, 12, 12], tag + " all three header labels are 12 px")
	_check(header.get_title_rect().position.is_equal_approx(Vector2(12, 7)), tag + " title at (12,7)")
	_check(header.get_subtitle_rect().position.is_equal_approx(Vector2(12, 23)), tag + " chapter at (12,23)")
	_check(header.get_icon_size().is_equal_approx(Vector2(20, 20)), tag + " icon is 20x20")
	_check(header.get_icon_source_size().is_equal_approx(Vector2(5, 5)), tag + " source icon is native 5x5")
	_check(header.get_icon_texture_path().ends_with("talisman_gold.png"), tag + " starts with gold talisman PNG")
	_check(header.get_icon_rect().end.x <= 640.0 - 8.0, tag + " icon leaves right safe margin")
	_check(header.get_affinity_rect().end.x <= 640.0 - 8.0, tag + " affinity text leaves right safe margin")
	_check(header.get_affinity_rect().position.x - header.get_icon_rect().end.x >= 4.0, tag + " icon/text gap")
	_check(
		is_equal_approx(header.get_icon_rect().get_center().y, header.get_affinity_rect().get_center().y),
		tag + " icon/text vertical centers align"
	)
	_check(not header.has_panel(), tag + " no big panel")
	_check(not _has_text(header, "护符相性"), tag + " no 护符相性 caption")
	_check(not _has_text(header, "Q 切换"), tag + " no permanent Q hint")
	_check(not _has_text(header, "隔离预览"), tag + " no preview disclosure in formal header")
	_check(header.is_mouse_ignored(), tag + " header controls ignore mouse")
	var title_label: Label = header.get_node("CompactTitle") as Label
	var subtitle_label: Label = header.get_node("CompactSubtitle") as Label
	var affinity: Label = header.get_node("AffinityText") as Label
	_check(title_label.get_theme_color("font_color") == Color("#e8e2d5"), tag + " title uses TEXT_WARM")
	_check(subtitle_label.get_theme_color("font_color") == Color("#9fb0b2"), tag + " chapter uses MUTED")
	_check(title_label.get_theme_constant("outline_size") == 1, tag + " title outline is 1 px")
	_check(subtitle_label.get_theme_constant("outline_size") == 1, tag + " chapter outline is 1 px")
	_check(affinity.get_theme_constant("outline_size") == 1, tag + " affinity outline is 1 px")
	var icon: TextureRect = header.get_node("AffinityIcon") as TextureRect
	_check(icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, tag + " icon uses Nearest")
	_check(icon.stretch_mode == TextureRect.STRETCH_SCALE and icon.size == Vector2(20, 20), tag + " icon is exact 4x control")
	if tag == "L1":
		_l1_header_geometry = {
			"title": header.get_title_rect(),
			"subtitle": header.get_subtitle_rect(),
			"icon": header.get_icon_rect(),
			"affinity": header.get_affinity_rect(),
		}


func _has_text(header: CompactLevelHeader, text: String) -> bool:
	for node: Node in header.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.text == text:
			return true
	return false


func _same_l1_geometry(header: CompactLevelHeader) -> bool:
	if header == null or _l1_header_geometry.is_empty():
		return false
	return (
		header.get_title_rect() == _l1_header_geometry["title"]
		and header.get_subtitle_rect() == _l1_header_geometry["subtitle"]
		and header.get_icon_rect() == _l1_header_geometry["icon"]
		and header.get_affinity_rect() == _l1_header_geometry["affinity"]
	)


func _test_title_menu_hides_hud() -> void:
	var level: Level01 = L1.instantiate() as Level01
	add_child(level)
	await _frames(20)
	var hud: Level01HUD = level.get_hud()
	var header: CompactLevelHeader = hud.get_compact_header()
	_check(not hud.visible, "title menu hides the formal game HUD")
	_check(not header.is_visible_in_tree(), "title menu hides the compact header")
	level.begin_from_menu()
	await _frames(10)
	_check(hud.visible and header.is_visible_in_tree(), "game entry restores HUD/header")
	level.queue_free()
	await _frames(4)


func _key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("HEADER FAIL: " + text)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("res://tests/logs/compact_header_test.log", FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
