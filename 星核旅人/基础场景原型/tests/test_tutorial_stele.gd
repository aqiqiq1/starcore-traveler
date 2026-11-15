extends Node

## Independent acceptance test for the tutorial stele. It does not modify the
## existing 316-assertion runner. Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_tutorial_stele.tscn

const STELE_SCENE: PackedScene = preload("res://scenes/tutorial_stele.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const RECORD_SCENE_PATH: String = "res://scenes/polarity_record_test_room_standalone.tscn"
const GREY_PATH: String = "res://assets/tutorial_stele/tutorial_stele_grey.png"
const FRAME_PATH: String = "res://assets/tutorial_stele/tutorial_stele_frames.png"
const MASK_PATH: String = "res://assets/tutorial_stele/tutorial_stele_groove_mask.png"
const GOLD_PATH: String = "res://assets/tutorial_stele/tutorial_stele_gold.png"
const CYAN_PATH: String = "res://assets/tutorial_stele/tutorial_stele_cyan.png"
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

var _world: Node2D
var _player: PrototypePlayer
var _a: TutorialStele
var _b: TutorialStele
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - tutorial stele acceptance")
	_log("Godot %s  display=%s" % [Engine.get_version_info()["string"], DisplayServer.get_name()])

	_build_scene()
	await _step(3)

	_test_assets_and_component_shape()
	await _test_initial_grey_and_near_entry()
	await _test_paging_and_echo()
	await _test_leave_reset_and_reentry()
	await _test_hysteresis()
	await _test_two_steles_and_nearest()
	await _test_suspension_and_reset_clears()
	await _test_focus_loss_and_pause_freeze()
	await _test_screen_layout_and_world_anchor()
	await _test_wrapping_and_font_coverage()
	await _test_main_room_integration()

	_finish()


func _build_scene() -> void:
	_world = Node2D.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)

	_player = PLAYER_SCENE.instantiate() as PrototypePlayer
	_player.position = Vector2(100.0, 288.0)
	_world.add_child(_player)
	_player.set_physics_process(false)

	_a = STELE_SCENE.instantiate() as TutorialStele
	_a.position = Vector2(400.0, 288.0)
	_a.player_path = NodePath("../Player")
	_world.add_child(_a)

	_b = STELE_SCENE.instantiate() as TutorialStele
	_b.position = Vector2(900.0, 288.0)
	_b.player_path = NodePath("../Player")
	_world.add_child(_b)


func _test_assets_and_component_shape() -> void:
	_section("ASSETS / COMPONENT")
	var grey: Texture2D = load(GREY_PATH) as Texture2D
	var frames: Texture2D = load(FRAME_PATH) as Texture2D
	var mask: Texture2D = load(MASK_PATH) as Texture2D
	var gold: Texture2D = load(GOLD_PATH) as Texture2D
	var cyan: Texture2D = load(CYAN_PATH) as Texture2D
	_check(grey != null and grey.get_size() == Vector2(26, 52), "grey reference is 26x52", str(grey.get_size()) if grey else "missing")
	_check(gold != null and gold.get_size() == Vector2(26, 52), "gold reference is 26x52", str(gold.get_size()) if gold else "missing")
	_check(cyan != null and cyan.get_size() == Vector2(26, 52), "cyan reference is 26x52", str(cyan.get_size()) if cyan else "missing")
	_check(mask != null and mask.get_size() == Vector2(26, 52), "groove mask is 26x52", str(mask.get_size()) if mask else "missing")
	_check(frames != null and frames.get_size() == Vector2(1664, 52), "animation sheet is 64 x 26x52", str(frames.get_size()) if frames else "missing")
	_check(_a.get_animation_frame_count() == 64, "component slices 64 frames", str(_a.get_animation_frame_count()))
	_check(_a.get_stone_texture() == grey, "idle stele uses the exact grey reference", str(_a.get_stone_texture()))
	_check(_a.rotation == 0.0 and _a.scale == Vector2.ONE, "stone root is not rotated or scaled", "rotation=%.2f scale=%s" % [_a.rotation, str(_a.scale)])
	_check(_a.get_node("Stone").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "stone uses nearest filtering", str(_a.get_node("Stone").texture_filter))
	_check(_a.find_children("*", "CollisionObject2D", true, false).is_empty(), "stele has no physics collision", "no CollisionObject2D")
	_check(_a.find_children("*", "Area2D", true, false).is_empty(), "stele has no Area2D", "no Area2D")
	_check(InputMap.has_action(&"tutorial_next"), "tutorial_next action exists", "F")
	var has_f: bool = false
	for event: InputEvent in InputMap.action_get_events(&"tutorial_next"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_F:
			has_f = true
	_check(has_f, "tutorial_next is bound to physical F", "KEY_F")


func _test_initial_grey_and_near_entry() -> void:
	_section("GREY / NEAR ENTRY")
	_player.global_position = Vector2(100.0, 288.0)
	await _step(3)
	_check(not _a.is_focused(), "far stele has no focus", "dist=300")
	_check(_a.is_grey_visual(), "far stele is the grey reference", str(_a.get_stone_texture()))
	_check(not _a.is_prompt_visible(), "far stele has no prompt", "hidden")
	_check(_a.get_page_index() == -1, "far stele is closed", str(_a.get_page_index()))

	_player.global_position = Vector2(370.0, 288.0)
	await _step(2)
	_check(_a.is_focused(), "30 px enters focus", "dist=30")
	_check(_a.is_prompt_visible(), "page 1 opens automatically", "visible")
	_check(_a.get_page_index() == 0, "automatic opening is page 1", str(_a.get_page_index()))
	_check(_a.get_current_page_text().begins_with("护符能改变你的极性。"), "page 1 is the approved first lesson", _a.get_current_page_text().substr(0, 16))
	_check(_a.get_footer_text() == "F 继续", "page 1 footer says F 继续", _a.get_footer_text())
	_check(_a.is_glow_active(), "near stele uses the generated glow sheet", str(_a.get_stone_texture()))


func _test_paging_and_echo() -> void:
	_section("PAGING / ECHO")
	await _press_f()
	_check(_a.get_page_index() == 1, "one F advances exactly one page", str(_a.get_page_index()))
	_check(_a.get_current_page_text().begins_with("同号相斥，异号相吸。"), "page 2 text is correct", _a.get_current_page_text().substr(0, 16))
	_check(_a.get_footer_text() == "F 继续", "page 2 footer says F 继续", _a.get_footer_text())

	for index: int in range(5):
		_send_f(true)
	await _step(2)
	_check(_a.get_page_index() == 1, "five key-repeat echo events do not page", str(_a.get_page_index()))

	await _press_f()
	_check(_a.get_page_index() == 2, "second real F reaches page 3", str(_a.get_page_index()))
	_check(_a.get_current_page_text().begins_with("靠近星核仓按 E 释放或放入。"), "page 3 text is correct", _a.get_current_page_text().substr(0, 18))
	_check(_a.get_footer_text() == "F 收起", "last page footer says F 收起", _a.get_footer_text())

	await _press_f()
	_check(_a.get_page_index() == -1, "F on last page closes the prompt", str(_a.get_page_index()))
	_check(not _a.is_prompt_visible(), "closed prompt is hidden", "hidden")
	_check(_a.is_focused() and _a.get_stone_texture() == load(FRAME_PATH), "glow stays on while still near", str(_a.get_stone_texture()))

	await _press_f()
	_check(_a.get_page_index() == 0, "F while still near reopens page 1", str(_a.get_page_index()))
	_check(_a.is_prompt_visible(), "reopened prompt is visible", "visible")


func _test_leave_reset_and_reentry() -> void:
	_section("LEAVE / REENTRY")
	_player.global_position = Vector2(470.0, 288.0)
	await _step(3)
	_check(not _a.is_focused(), "70 px leaves after the hysteresis band", "dist=70")
	_check(not _a.is_prompt_visible(), "leave hides the prompt", "hidden")
	_check(_a.is_grey_visual(), "leave restores the grey stone", str(_a.get_stone_texture()))
	_check(_a.get_page_index() == -1, "leave clears the page", str(_a.get_page_index()))

	_player.global_position = Vector2(380.0, 288.0)
	await _step(2)
	_check(_a.is_focused() and _a.get_page_index() == 0, "re-entry starts at page 1 again", "page=%d" % _a.get_page_index())


func _test_hysteresis() -> void:
	_section("NEAR/LEAVE BOUNDARY")
	_player.global_position = Vector2(340.0, 288.0)
	await _step(2)
	_check(_a.is_focused(), "60 px keeps the already-open stele", "dist=60")
	_check(_a.get_page_index() == 0, "hysteresis does not reset the page", str(_a.get_page_index()))
	await _step(10)
	_check(_a.is_focused(), "60 px remains stable across frames", "dist=60")

	_player.global_position = Vector2(332.0, 288.0)
	await _step(2)
	_check(not _a.is_focused(), "68 px leaves cleanly", "dist=68")
	_check(_a.is_grey_visual(), "boundary departure is grey", str(_a.get_stone_texture()))


func _test_two_steles_and_nearest() -> void:
	_section("TWO STELES / NEAREST")
	_a.global_position = Vector2(300.0, 288.0)
	_b.global_position = Vector2(350.0, 288.0)
	_player.global_position = Vector2(342.0, 288.0)
	await _step(3)
	_check(_b.is_focused(), "the nearer stele takes focus", "b dist=8")
	_check(not _a.is_focused(), "the farther stele loses focus", "a dist=42")
	_check(_b.is_prompt_visible() and _b.get_page_index() == 0, "only the near stele shows page 1", "b page=0")
	_check(_a.is_grey_visual() and not _a.is_prompt_visible(), "the other stele is grey and silent", "a grey")

	await _press_f()
	_check(_b.get_page_index() == 1, "F pages only the focused stele", "b page=1")
	_check(_a.get_page_index() == -1, "the other stele never pages", "a page=-1")

	# Give the pair a small epsilon-style boundary: they must not both display.
	_player.global_position = Vector2(260.0, 288.0)
	await _step(3)
	_check(_a.is_focused(), "walking past the midpoint switches to the other stele", "a dist=40")
	_check(not _b.is_focused(), "the old stele releases focus", "b dist=90")
	_check(_a.is_prompt_visible() and _b.is_prompt_visible() == false, "only one prompt can be visible", "a visible, b hidden")
	_check(_a.get_page_index() == 0 and _b.get_page_index() == -1, "focus switch starts the new stele at page 1", "a=0 b=-1")


func _test_suspension_and_reset_clears() -> void:
	_section("SUSPEND / RESET / FOCUS LOSS")
	_a.set_suspended(true)
	await _step(2)
	_check(not _a.is_focused() and not _a.is_prompt_visible(), "suspend closes the prompt", "hidden")
	_check(_a.is_grey_visual(), "suspend restores grey", str(_a.get_stone_texture()))
	await _press_f()
	_check(_a.get_page_index() == -1, "suspended stele ignores F", str(_a.get_page_index()))

	_a.set_suspended(false)
	await _step(3)
	_check(_a.is_focused() and _a.get_page_index() == 0, "unsuspend reopens page 1 when near", "page=%d" % _a.get_page_index())

	await _press_f()
	_check(_a.get_page_index() == 1, "page 2 before reset", str(_a.get_page_index()))
	_a.on_player_reset("manual")
	await _step(1)
	_check(_a.get_page_index() == 0, "R clears back to page 1", str(_a.get_page_index()))

	await _press_f()
	_a.on_focus_lost()
	await _step(1)
	_check(_a.get_page_index() == 0, "focus loss clears back to page 1", str(_a.get_page_index()))


func _test_focus_loss_and_pause_freeze() -> void:
	_section("PAUSE / ANIMATION FREEZE")
	var before_frame: int = _a.get_animation_frame()
	get_tree().paused = true
	await _step(24)
	_check(_a.get_animation_frame() == before_frame, "Esc pause freezes the glow frame", "%d -> %d" % [before_frame, _a.get_animation_frame()])
	await _press_f()
	_check(_a.get_page_index() == 0, "F does not page while paused", str(_a.get_page_index()))
	get_tree().paused = false
	await _step(12)
	_check(_a.get_animation_frame() != before_frame, "glow resumes after unpause", "%d -> %d" % [before_frame, _a.get_animation_frame()])


func _test_screen_layout_and_world_anchor() -> void:
	_section("SCREEN CLAMP / WORLD ANCHOR")
	_b.global_position = Vector2(900.0, 288.0)
	_player.global_position = Vector2(300.0, 288.0)
	await _step(2)
	var first: Rect2 = _a.get_prompt_rect()
	_check(_within_screen(first), "prompt is inside 640x360 with its notch", str(first))
	_check(first.position.y >= 50.0, "prompt stays below the HUD safe top", str(first.position.y))

	_player.global_position = Vector2(350.0, 288.0)
	_a.global_position = Vector2(350.0, 288.0)
	await _step(2)
	var moved: Rect2 = _a.get_prompt_rect()
	_check(is_equal_approx(moved.position.x - first.position.x, 50.0), "prompt follows the moved stele by 50 px", "%s -> %s" % [str(first.position), str(moved.position)])

	_player.global_position = Vector2(5.0, 288.0)
	_a.global_position = Vector2(5.0, 288.0)
	await _step(2)
	var left_clamped: Rect2 = _a.get_prompt_rect()
	_check(left_clamped.position.x >= 4.0 and _within_screen(left_clamped), "left edge is clamped inside the screen", str(left_clamped))

	_player.global_position = Vector2(635.0, 288.0)
	_a.global_position = Vector2(635.0, 288.0)
	await _step(2)
	var right_clamped: Rect2 = _a.get_prompt_rect()
	_check(right_clamped.end.x <= 636.0 and _within_screen(right_clamped), "right edge is clamped inside the screen", str(right_clamped))

	_player.global_position = Vector2(300.0, 60.0)
	_a.global_position = Vector2(300.0, 60.0)
	await _step(2)
	var top_clamped: Rect2 = _a.get_prompt_rect()
	_check(top_clamped.position.y >= 50.0 and _within_screen(top_clamped), "top edge is clamped below the HUD band", str(top_clamped))

	# Restore the basic-room-like position for the remaining text checks.
	_player.global_position = Vector2(300.0, 288.0)
	_a.global_position = Vector2(300.0, 288.0)
	await _step(2)


func _test_wrapping_and_font_coverage() -> void:
	_section("WRAPPING / CHINESE FONT")
	var original_pages: PackedStringArray = _a.pages
	_a.pages = PackedStringArray([
		"护符能改变你的极性。按 Q 切换金色与青色。同号相斥，异号相吸。试着借固定符石的力量移动。"
	])
	_a.open_first_page()
	await _step(2)
	var wrapped: Rect2 = _a.get_prompt_rect()
	_check(wrapped.size.y > 70.0, "a long Chinese page wraps to more lines", str(wrapped.size))
	_check(_within_screen(wrapped), "wrapped prompt remains inside 640x360", str(wrapped))
	_a.pages = original_pages
	_a.open_first_page()
	await _step(1)

	var font: FontFile = load(FONT_PATH) as FontFile
	_check(font != null, "tutorial font is imported locally", FONT_PATH)
	var prompt_font: Font = _a.get_prompt_font()
	_check(prompt_font != null, "prompt label has a font", str(prompt_font))
	if prompt_font is FontFile:
		_check((prompt_font as FontFile).get_font_name().contains("Fusion Pixel"), "prompt uses the local Fusion Pixel font", (prompt_font as FontFile).get_font_name())

	var sample: String = "".join(original_pages) + "F继续收起12345QER按"
	var missing: String = ""
	for index: int in range(sample.length()):
		var character: String = sample.substr(index, 1)
		if character == "\n" or character == " ":
			continue
		if font == null or not font.has_char(character.unicode_at(0)):
			missing += character
	_check(missing.is_empty(), "the real page strings have full glyph coverage", "missing=%s" % missing)


func _test_main_room_integration() -> void:
	_section("MAIN ROOM / R / F2 / F4 / FOCUS")
	# Remove the standalone test world so the real main scene is the only owner
	# of the tutorial_stele group and the only source of focus.
	_world.queue_free()
	await _step(4)
	var main: PrototypeMain = MAIN_SCENE.instantiate() as PrototypeMain
	add_child(main)
	await _step(6)
	var side_player: PrototypePlayer = main.get_player()
	var side_stele: TutorialStele = main.get_node("World/TutorialStele") as TutorialStele
	_check(side_player != null and side_stele != null, "main scene contains the editable stele and player", str(side_stele))
	_check(side_stele.position == Vector2(224.0, 288.0), "main stele sits near spawn without moving map nodes", str(side_stele.position))

	side_player.global_position = Vector2(252.0, 288.0)
	side_player.velocity = Vector2.ZERO
	await _step(4)
	_check(side_stele.is_focused() and side_stele.get_page_index() == 0, "main room opens page 1 when the player walks close", "page=%d" % side_stele.get_page_index())
	await _press_f()
	_check(side_stele.get_page_index() == 1, "real F pages in the main room", str(side_stele.get_page_index()))

	await _tap_action_physics(&"reset")
	await _step(5)
	_check(side_player.global_position == main.get_spawn_position(), "R still resets the player to the room spawn", str(side_player.global_position))
	_check(not side_stele.is_prompt_visible() and side_stele.get_page_index() == -1, "R clears the open prompt", "page=%d" % side_stele.get_page_index())
	_check(side_stele.is_grey_visual(), "R restores grey because the player left the range", str(side_stele.get_stone_texture()))

	side_player.global_position = Vector2(252.0, 288.0)
	side_player.velocity = Vector2.ZERO
	await _step(4)
	await _press_f()
	_check(side_stele.get_page_index() == 1, "page 2 is open before F2", str(side_stele.get_page_index()))
	await _tap_action_process(&"toggle_anchor_room")
	await _step(4)
	_check(main.is_in_anchor_room(), "F2 still enters the anchor room", "anchor")
	_check(side_stele.is_suspended() and not side_stele.is_prompt_visible(), "F2 hides the tutorial prompt", "suspended")
	_check(side_stele.is_grey_visual(), "F2 restores grey", str(side_stele.get_stone_texture()))
	await _press_f()
	_check(side_stele.get_page_index() == -1, "F does not page inside the anchor room", str(side_stele.get_page_index()))
	await _tap_action_process(&"toggle_anchor_room")
	await _step(6)
	_check(not main.is_in_anchor_room() and not side_stele.is_suspended(), "F2 exits and unsuspends the stele", "base")
	_check(not side_stele.is_prompt_visible(), "returning to spawn does not leave a stale prompt", "hidden")

	side_player.global_position = Vector2(252.0, 288.0)
	side_player.velocity = Vector2.ZERO
	await _step(4)
	await _press_f()
	_check(side_stele.get_page_index() == 1, "page 2 is open before F4", str(side_stele.get_page_index()))
	await _tap_action_process(&"toggle_interaction_room")
	await _step(4)
	_check(main.is_in_interaction_room(), "F4 still enters the core interaction room", "interaction")
	_check(side_stele.is_suspended() and not side_stele.is_prompt_visible(), "F4 hides the tutorial prompt", "suspended")
	await _press_f()
	_check(side_stele.get_page_index() == -1, "F does not page inside the interaction room", str(side_stele.get_page_index()))
	await _tap_action_process(&"toggle_interaction_room")
	await _step(6)
	_check(not main.is_in_interaction_room() and not side_stele.is_suspended(), "F4 exits and unsuspends the stele", "base")

	side_player.global_position = Vector2(252.0, 288.0)
	side_player.velocity = Vector2.ZERO
	await _step(4)
	await _press_f()
	_check(side_stele.get_page_index() == 1, "page 2 is open before focus loss", str(side_stele.get_page_index()))
	main.handle_focus_lost()
	await _step(2)
	_check(side_stele.get_page_index() == 0 and side_stele.is_prompt_visible(), "window focus loss clears back to page 1", "page=%d" % side_stele.get_page_index())

	_check(ResourceLoader.exists(RECORD_SCENE_PATH), "F7 record scene still exists", RECORD_SCENE_PATH)
	var record_scene: PackedScene = load(RECORD_SCENE_PATH) as PackedScene
	if record_scene != null:
		var record_root: Node = record_scene.instantiate()
		var record_steles: Array[Node] = record_root.find_children("*", "TutorialStele", true, false)
		_check(record_steles.is_empty(), "F7 target scene contains no tutorial stele or prompt", "0 steles")
		record_root.free()

	main.queue_free()
	await _step(4)


func _tap_action_physics(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _tap_action_process(action: StringName) -> void:
	Input.action_press(action)
	await _step(2)
	Input.action_release(action)
	await _step(2)


func _within_screen(rect: Rect2) -> bool:
	return (
		rect.position.x >= 3.5
		and rect.position.y >= 49.5
		and rect.end.x <= 636.5
		and rect.end.y + 8.0 <= 356.5
	)


func _press_f() -> void:
	_send_f(false)
	await _step(1)
	_send_release_f()
	await _step(1)


func _send_f(echo: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_release_f() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _step(frames: int) -> void:
	for _index: int in range(frames):
		await get_tree().process_frame


func _section(name: String) -> void:
	_log("")
	_log("-- %s --" % name)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s  (%s)" % [label, detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s  (%s)" % [label, detail])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count])
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open("res://tests/logs/tutorial_stele_test.log", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log_lines) + "\n")
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
