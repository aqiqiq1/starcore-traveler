extends Node

## Focused acceptance for the 2026-11-12 art + guide-echo pass.
##
## This is deliberately not the old full-level suite. It checks:
##   - four entry scenes parse/instantiate (level 01 default menu, level 02,
##     the enemy experiment and legacy main; the old sandbox rooms still load);
##   - the three replaced runtime PNGs import with their expected sizes and the
##     approved HighStep alpha cut at y>=288;
##   - level 01 has exactly two GuideEcho manifestations and no old stele shell;
##   - approaching only shows "F 交谈"; real F opens/pages/closes; leaving and
##     re-entering can replay; menu/pause/completion/R/focus gates clear it;
##   - level 02's five real seams, HighStep/RightLedge geometry, 12 px labels,
##     single prompt/toast slot and one real guard hit still work;
##   - level-01 geometry/force/rune/camera values and level-02 transport/bay
##     fields remain the authored constants;
##   - the experiment HUD stays on 12/24 px native text.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://tests/test_art_guide_pass.tscn

const LOG_PATH: String = "res://tests/logs/art_guide_pass_test_20261112.log"
const LEVEL01_PATH: String = "res://scenes/level_01.tscn"
const LEVEL02_PATH: String = "res://scenes/level_02.tscn"
const EXPERIMENT_PATH: String = "res://scenes/experiments/polarity_golem_experiment.tscn"
const LEGACY_ENTRIES: Array[String] = [
	"res://scenes/main.tscn",
	"res://scenes/star_core_interaction_room.tscn",
	"res://scenes/polarity_record_test_room.tscn",
]

var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []
var _level01: Level01 = null
var _level02: Level02 = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Art + guide echo focused acceptance - 2026-11-12")
	_log("Godot: %s" % Engine.get_version_info()["string"])
	_log("This suite does not replay the old full-level suites.")
	await _test_entries_and_assets()
	await _test_level01()
	await _test_level02()
	await _test_experiment_hud()
	_lines.append("")
	_lines.append("TEST_SUMMARY pass=%d fail=%d" % [_pass, _fail])
	_lines.append("RESULT: " + ("PASS" if _fail == 0 else "FAIL"))
	_write_log()
	print("TEST_SUMMARY pass=%d fail=%d" % [_pass, _fail])
	print("RESULT: " + ("PASS" if _fail == 0 else "FAIL"))
	get_tree().quit(0 if _fail == 0 else 1)


func _test_entries_and_assets() -> void:
	_section("entries and shared assets")
	for path: String in [LEVEL01_PATH, LEVEL02_PATH, EXPERIMENT_PATH] + LEGACY_ENTRIES:
		var packed: PackedScene = ResourceLoader.load(path, "PackedScene") as PackedScene
		_check(packed != null, "scene parses: %s" % path)
		if packed != null:
			var instance: Node = packed.instantiate()
			_check(instance != null, "scene instantiates: %s" % path)
			if instance != null:
				instance.free()
	var atlas: Texture2D = ResourceLoader.load(
		"res://assets/map/ruin_platform_tiles.png", "Texture2D"
	) as Texture2D
	_check(atlas != null, "shared warm-grey atlas loads")
	if atlas != null:
		_check(Vector2i(atlas.get_size()) == Vector2i(192, 32), "shared atlas remains 192x32")
	var visual: Texture2D = ResourceLoader.load(
		"res://assets/level02_platform_v3/layer_platform_visual_640.png", "Texture2D"
	) as Texture2D
	var decor: Texture2D = ResourceLoader.load(
		"res://assets/level02_platform_v3/layer_platform_decor_640.png", "Texture2D"
	) as Texture2D
	_check(visual != null and Vector2i(visual.get_size()) == Vector2i(640, 360),
		"level-02 visual layer imports at 640x360")
	_check(decor != null and Vector2i(decor.get_size()) == Vector2i(640, 360),
		"level-02 decor layer imports at 640x360")
	_check(FileAccess.file_exists("res://assets/guide_echo_20261113/guide_echo_idle_6f.png"),
		"guide echo sheet exists")
	var guide_texture: Texture2D = ResourceLoader.load(
		"res://assets/guide_echo_20261113/guide_echo_idle_6f.png", "Texture2D"
	) as Texture2D
	_check(guide_texture != null and Vector2i(guide_texture.get_size()) == Vector2i(288, 64),
		"guide echo sheet imports at 288x64")


func _test_level01() -> void:
	_section("level 01 guide echo")
	var packed: PackedScene = ResourceLoader.load(LEVEL01_PATH, "PackedScene") as PackedScene
	_level01 = packed.instantiate() as Level01
	_level01.enable_start_menu = false
	_level01.intro_max_duration = 0.2
	add_child(_level01)
	await _wait_until(func() -> bool: return not _level01.is_intro_active(), 180)
	await _process_frames(4)

	var guides: Array[Node] = get_tree().get_nodes_in_group(&"guide_echo")
	_check(guides.size() == 2, "level 01 has exactly two GuideEcho nodes (got %d)" % guides.size())
	_check(get_tree().get_nodes_in_group(&"tutorial_stele").is_empty(),
		"level 01 no longer contains a TutorialStele shell")
	var first: GuideEcho = _level01.get_narrative_guide()
	var second: GuideEcho = _level01.get_mechanism_guide()
	_check(first != null and second != null, "both guide accessors resolve")
	if first == null or second == null:
		return
	_check(first.global_position == Vector2(250, 300), "first echo keeps authored point (250,300)")
	_check(second.global_position == Vector2(735, 300), "second echo keeps authored point (735,300)")
	_check(first.get_page_count() == 3 and second.get_page_count() == 3, "each echo has three pages")
	_check(first.get_display_name() == "守望者残响" and second.get_display_name() == "守望者残响",
		"both manifestations use the same speaker name")
	_check(not first.has_collision_body() and not second.has_collision_body(),
		"guide echoes have no CollisionObject2D")
	_check(first.get_foot_anchor() == Vector2(24, 60), "guide foot anchor is (24,60)")
	var sprite: Sprite2D = first.get_node("EchoProjection/EchoSprite") as Sprite2D
	_check(sprite != null and sprite.hframes == 6 and not sprite.centered and sprite.position == Vector2(-24, -60),
		"guide sprite uses 6 frames at the approved 48x64 foot alignment")
	_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"guide sprite keeps Nearest filtering")
	var carrier: Sprite2D = first.get_carrier_stone()
	_check(carrier != null and carrier.texture != null and not first.has_collision_body(),
		"guide stands on a pure-visual carrier stele (no collision)")
	_check(not first.is_in_group(&"tutorial_stele"), "carrier is not the TutorialStele component")

	# Authored level-01 geometry and force-related settings.
	var start_ground: LevelTerrainBlock = _level01.get_node("World/StartGround") as LevelTerrainBlock
	var high_platform: LevelTerrainBlock = _level01.get_node("World/HighPlatform") as LevelTerrainBlock
	var far_bank: LevelTerrainBlock = _level01.get_node("World/FarBank") as LevelTerrainBlock
	_check(start_ground.position == Vector2(-160, 300) and start_ground.block_size == Vector2(1024, 64),
		"StartGround geometry unchanged")
	_check(high_platform.position == Vector2(864, 220) and high_platform.block_size == Vector2(336, 144),
		"HighPlatform geometry unchanged")
	_check(far_bank.position == Vector2(1456, 300) and far_bank.block_size == Vector2(496, 64),
		"FarBank geometry unchanged")
	_check(_level01.get_start_position() == Vector2(-60, 300), "authored spawn remains (-60,300)")
	_check(_level01.get_player().world_left == -220.0 and _level01.get_player().world_right == 1936.0,
		"player world bounds unchanged")
	_check(_level01.get_player().kill_y == 430.0, "player kill line remains 430")
	var camera: Camera2D = _level01.get_camera()
	_check(camera.limit_left == 0 and camera.limit_top == 0 and camera.limit_right == 1952
		and camera.limit_bottom == 360, "level-01 camera limits unchanged")
	_check(_level01.get_checkpoint().global_position == Vector2(1120, 220), "checkpoint point unchanged")
	_check(_level01.get_exit().global_position == Vector2(1840, 300), "exit point unchanged")
	var stones: Array[RuneStoneField] = _level01.get_rune_stones()
	_check(stones.size() == 2, "two rune stones remain")
	_check(stones[0].global_position == Vector2(864, 155) and stones[1].global_position == Vector2(1360, 150),
		"rune stone points unchanged")
	_check(is_equal_approx(_level01.intro_run_speed_ratio, 0.75), "intro run ratio remains 0.75")
	_check(is_equal_approx(_level01.menu_camera_pan_duration, 2.2), "menu pan remains 2.2 s")
	_check(_all_native_sizes(_level01.get_hud().get_label_font_sizes()),
		"level-01 HUD labels are all 12/24 px")

	var player: PrototypePlayer = _level01.get_player()
	player.global_position = Vector2(250, 300)
	player.velocity = Vector2.ZERO
	await _process_frames(5)
	_check(first.is_in_range(), "standing at the echo enters range")
	_check(first.is_prompt_visible(), "approach shows the short F-talk prompt")
	_check(first.get_prompt_text() == "F 交谈", "prompt text is the short F 交谈 hint")
	_check(not first.is_dialogue_open() and first.get_page_index() == -1,
		"approach does not auto-open page 1")

	await _tap_f()
	_check(first.is_dialogue_open() and first.get_page_index() == 0,
		"real F opens page 1")
	_check(first.get_speaker_text() == "守望者残响", "dialogue labels the speaker")
	_check(first.get_body_font_size() == 12, "dialogue body is native 12 px")
	_check(first.get_action_text() == "F 继续", "page 1 asks F to continue")
	var rect: Rect2 = first.get_dialogue_rect()
	_check(rect.size.x <= 632.0 and rect.position.x >= 4.0, "dialogue stays inside the 640-wide screen")
	_check(rect.end.y <= player.global_position.y - 30.0,
		"dialogue panel stays above the player's visible body")
	_check(first.get_current_page_text().begins_with("旅人"),
		"first manifestation uses the approved meeting text")

	await _tap_f()
	_check(first.get_page_index() == 1, "second F advances to page 2")
	var page2_rect: Rect2 = first.get_dialogue_rect()
	_check(page2_rect.position.x >= 4.0 and page2_rect.end.x <= 636.0
		and page2_rect.position.y >= 56.0 and page2_rect.end.y <= 356.0,
		"page 2 panel is measured and stays inside the screen")
	await _tap_f()
	_check(first.get_page_index() == 2, "third F advances to page 3")
	var page3_rect: Rect2 = first.get_dialogue_rect()
	_check(page3_rect.position.x >= 4.0 and page3_rect.end.x <= 636.0
		and page3_rect.position.y >= 56.0 and page3_rect.end.y <= 356.0,
		"page 3 panel is measured and stays inside the screen")
	_check(first.get_action_text() == "F 收起", "last page asks F to close")
	await _tap_f()
	_check(not first.is_dialogue_open() and first.get_page_index() == -1, "F on the last page closes")
	_check(first.is_prompt_visible(), "prompt returns after closing")

	await _tap_f()
	_check(first.get_page_index() == 0, "F can open the echo again while still in range")
	# Key repeat echo must not page.
	await _send_key(KEY_F, true, true)
	_check(first.get_page_index() == 0, "key-repeat echo does not page")
	await _send_key(KEY_F, false, true)

	player.global_position = Vector2(420, 300)
	await _process_frames(5)
	_check(not first.is_in_range() and not first.is_prompt_visible() and not first.is_dialogue_open(),
		"leaving range closes the page and prompt")
	player.global_position = Vector2(250, 300)
	await _process_frames(4)
	_check(first.is_prompt_visible(), "re-entering range shows the prompt again")

	# Second manifestation text and screen clamp. The camera is intentionally
	# moved far left of the echo while its process is paused, then the layout is
	# evaluated once: this is a layout setup check, not a claim that the player
	# can talk from 765 px away.
	player.global_position = Vector2(735, 300)
	player.velocity = Vector2.ZERO
	_level01.get_camera().reset_smoothing()
	await _process_frames(4)
	_check(second.open_dialogue() and second.get_current_page_text().begins_with("我能指路"),
		"second manifestation uses the approved high-step text")
	second.set_process(false)
	player.global_position = Vector2(1500, 300)
	_level01.get_camera().reset_smoothing()
	await _process_frames(3)
	second._layout_dialog()
	var far_rect: Rect2 = second.get_dialogue_rect()
	_check(far_rect.position.x >= 4.0 and far_rect.end.x <= 636.0,
		"far-camera second manifestation dialogue is clamped on screen (x %.1f..%.1f)"
		% [far_rect.position.x, far_rect.end.x])
	second.close_dialogue()
	second.set_process(true)
	await _process_frames(3)

	# Menu gate: a normal production instance starts with the menu owning input.
	var menu_level: Level01 = packed.instantiate() as Level01
	menu_level.enable_start_menu = true
	add_child(menu_level)
	await _process_frames(4)
	var menu_first: GuideEcho = menu_level.get_narrative_guide()
	_check(menu_level.get_menu() != null and menu_level.get_menu().is_gameplay_blocked(),
		"default level-01 entry starts in the menu")
	_check(menu_first.is_suspended() and not menu_first.is_prompt_visible(),
		"guide is suspended behind the title menu")
	menu_level.get_player().global_position = Vector2(250, 300)
	await _process_frames(3)
	_check(not menu_first.is_prompt_visible(), "menu does not show the talk prompt")
	_check(not menu_first.open_dialogue(), "menu cannot open the echo dialogue")
	menu_level.queue_free()
	await _process_frames(3)

	# Pause gate and resume.
	first.open_dialogue()
	var pause = _level01.get_pause_menu()
	pause.open_pause()
	await get_tree().process_frame
	_check(first.is_suspended() and not first.is_dialogue_open(), "pause clears the echo page")
	get_tree().paused = false
	pause.resume()
	await get_tree().process_frame
	await _process_frames(3)
	_check(not first.is_suspended(), "resume lets the echo listen again")

	# Focus loss/return clears, then allows again.
	player.global_position = Vector2(250, 300)
	await _process_frames(3)
	first.open_dialogue()
	_level01._on_window_focus_exited()
	await get_tree().process_frame
	_check(first.is_suspended() and not first.is_dialogue_open(),
		"OS focus loss clears the old page")
	_level01._on_window_focus_entered()
	await _process_frames(3)
	_check(not first.is_suspended(), "focus return restores the echo")

	# Completion gate, then real R resets and allows replay.
	player.global_position = Vector2(1840, 300)
	player.velocity = Vector2.ZERO
	await _wait_until(func() -> bool: return _level01.is_completed(), 120)
	_check(_level01.is_completed(), "real exit completes level 01")
	_check(first.is_suspended() and not first.is_dialogue_open(), "completion clears and gates the echo")
	await _tap_key(KEY_R)
	await _wait_until(func() -> bool: return not _level01.is_intro_active(), 240)
	await _process_frames(4)
	_check(not _level01.is_completed(), "R leaves the completion state")
	_check(not first.is_suspended(), "after R + intro the echo can be used again")

	# Pause-menu wording uses 交谈 for level 01, never 阅读石碑.
	_check(pause.get_controls_text().contains("交谈"), "level-01 pause lists F 交谈")
	_check(not pause.get_controls_text().contains("阅读石碑"), "level-01 pause no longer says 阅读石碑")
	var pause_sizes: Array[int] = pause.get_control_label_font_sizes()
	_check(_all_native_sizes(pause_sizes),
		"pause control rows use 12 px native text (got %s)" % str(pause_sizes))

	_level01.queue_free()
	_level01 = null
	await _process_frames(4)
	_check(get_tree().get_nodes_in_group(&"guide_echo").is_empty(),
		"freeing the level leaves no GuideEcho node or prompt CanvasLayer behind")


func _test_level02() -> void:
	_section("level 02 readability and guard integration")
	var packed: PackedScene = ResourceLoader.load(LEVEL02_PATH, "PackedScene") as PackedScene
	_level02 = packed.instantiate() as Level02
	add_child(_level02)
	await _physics_frames(10)

	# Historical check; L2's start stele is now GuideEcho. Keep dynamic access
	# for parse compatibility, not as current L2 runtime verification.
	var stele = _level02.get_start_stele()
	_check(stele != null and stele.get_page_count() == 6, "level 02 keeps its six-page stele")
	_check(get_tree().get_nodes_in_group(&"guide_echo").is_empty(),
		"level 02 does not replace its stele with a GuideEcho")
	var gaps: Array[Rect2] = _level02.get_upper_gap_rects()
	_check(gaps.size() == 5, "five real upper seams remain")
	for gap: Rect2 in gaps:
		_check(is_equal_approx(gap.size.x, 8.0), "seam width remains 8 px at x=%s" % str(gap.position.x))
	# The new decor marks are visual only: a real mask-1 vertical ray still
	# passes through each 8 px seam to the ground, while a solid beam blocks it.
	var player_for_ray: PrototypePlayer = _level02.get_player()
	var ray_exclude: Array[RID] = [player_for_ray.get_rid()]
	for center: float in [260.0, 284.0, 324.0, 348.0, 372.0]:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			Vector2(center, 240.0), Vector2(center, 330.0), 1, ray_exclude
		)
		var hit: Dictionary = _level02.get_world_2d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty() and float((hit.get("position", Vector2.ZERO) as Vector2).y) >= 318.0,
			"vertical ray passes through real seam at x=%.0f" % center)
	var solid_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		Vector2(250.0, 240.0), Vector2(250.0, 330.0), 1, ray_exclude
	)
	var solid_hit: Dictionary = _level02.get_world_2d().direct_space_state.intersect_ray(solid_query)
	_check(not solid_hit.is_empty() and float((solid_hit.get("position", Vector2.ZERO) as Vector2).y) <= 271.0,
		"vertical ray is still blocked by solid beam at x=250")
	var high_step: Level02Block = _level02.get_node("HighStep") as Level02Block
	var right_ledge: Level02Block = _level02.get_node("RightLedge") as Level02Block
	_check(high_step.position == Vector2(152, 274) and high_step.block_size == Vector2(56, 14),
		"HighStep collision/position unchanged (bottom 288)")
	_check(right_ledge.position == Vector2(400, 276) and right_ledge.block_size == Vector2(32, 24),
		"RightLedge remains the repaired 32x24 / bottom 300")
	for visual_path: String in [
		"UpperDeck/V3PlatformVisual",
		"UpperDeck/V3PlatformDecor",
		"HighStep/V3PlatformVisual",
		"HighStep/V3PlatformDecor",
		"RightLedge/V3PlatformVisual",
	]:
		var visual: Sprite2D = _level02.get_node(visual_path) as Sprite2D
		_check(visual != null and visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and visual.scale == Vector2.ONE and visual.modulate == Color.WHITE,
			"platform visual keeps Nearest / scale 1 / white modulate: %s" % visual_path)
	_check(_level02.field_range == 100.0 and _level02.inner_radius == 40.0
		and _level02.full_radius == 64.0 and _level02.outer_fade == 18.0,
		"shared 100 px / 40 / 64 / 18 force field untouched")
	_check(_level02.core_acceleration == 620.0 and _level02.player_acceleration == 300.0,
		"transport accelerations remain 620 / 300")
	_check(_level02.store_player_core_range == 80.0, "E store range remains 80 px")
	_check(_level02.get_player().world_left == 6.0 and _level02.get_player().world_right == 634.0
		and _level02.get_player().kill_y == 400.0, "level-02 player bounds unchanged")
	_check(_level02.get_guard_spawn_position() == Vector2(344, 264),
		"guard authored foot point remains (344,264)")
	var guard = _level02.get_guard()
	_check(guard != null and is_equal_approx(guard.global_position.y, 264.0)
		and guard.global_position.x >= 244.0 and guard.global_position.x <= 388.0,
		"guard stays on its authored bridge strip")
	_check(guard.scale == Vector2.ONE, "guard keeps scale 1")
	_check(_level02.get_player().scale == Vector2.ONE, "player keeps scale 1")

	var label_expectations: Dictionary = {
		"StartBayLabel": "起始仓",
		"TargetBayLabel": "目标仓",
		"CorridorLabel": "低廊 · 仅星核",
		"UpperLabel": "嵌缝施力",
		"ExitStatus": "出口 · 未就绪",
	}
	for node_name: String in label_expectations:
		var label: Label = _level02.get_node(node_name) as Label
		_check(label != null, "world label exists: %s" % node_name)
		if label == null:
			continue
		_check(label.text == String(label_expectations[node_name]), "world label text: %s" % node_name)
		_check(label.get_theme_font_size("font_size") == 12, "world label is 12 px: %s" % node_name)
		var font: Font = label.get_theme_font("font")
		var measured: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
		_check(measured <= label.size.x, "world label text fits its box: %s (%.1f <= %.1f)"
			% [node_name, measured, label.size.x])
		_check(_label_is_on_screen(label), "world label stays on screen: %s" % node_name)

	var hud: Level02HUD = _level02.get_hud()
	_check(_all_native_sizes(hud.get_label_font_sizes()), "level-02 HUD labels are all 12/24 px")
	_check(hud.get_phase_text().begins_with("任务："), "status panel shows a short objective")
	_check(not hud.get_phase_text().contains("按 E"), "status panel does not duplicate the E prompt")
	_check(hud.get_prompt_text().contains("E"), "one immediate action prompt remains")
	hud.set_status("任务：运输星核", "星核：运输中", "地形遮挡 · 换个位置")
	hud.show_toast("星核已放入目标座", 0.35)
	_check(not hud.is_prompt_visible() and hud.is_toast_visible(),
		"toast takes the single shared slot and hides the prompt")
	await get_tree().create_timer(0.5).timeout
	_check(hud.is_prompt_visible() and not hud.is_toast_visible(),
		"prompt returns after the toast expires")

	# One real hit through the level's signal wiring.
	var player: PrototypePlayer = _level02.get_player()
	player.set_physics_process(false)
	player.global_position = Vector2(320, 264)
	player.velocity = Vector2.ZERO
	guard.reset_experiment_state(Vector2(344, 264), true)
	guard.set_ai_suspended(true)
	await _physics_frames(2)
	var hp_before: int = guard.get_hp()
	player.emit_signal("attack_hit_window", 1, 1, true)
	await _physics_frames(2)
	_check(guard.get_hp() == hp_before - 1,
		"same-phase attack through level signal still removes 1 HP (%d -> %d)" % [hp_before, guard.get_hp()])
	player.emit_signal("attack_hit_window", 1, 1, true)
	await _physics_frames(2)
	_check(guard.get_hp() == hp_before - 1, "duplicate swing id cannot resolve twice")

	_level02.queue_free()
	_level02 = null
	await _process_frames(4)


func _test_experiment_hud() -> void:
	_section("enemy experiment HUD")
	var packed: PackedScene = ResourceLoader.load(EXPERIMENT_PATH, "PackedScene") as PackedScene
	var experiment: Node = packed.instantiate()
	add_child(experiment)
	await _process_frames(6)
	var hud: CanvasLayer = experiment.get_node_or_null("HUD") as CanvasLayer
	_check(hud != null, "experiment HUD loads")
	if hud != null and hud.has_method("get_label_font_sizes"):
		var sizes: Array[int] = hud.call("get_label_font_sizes")
		_check(_all_native_sizes(sizes), "experiment labels stay 12/24 px (got %s)" % str(sizes))
	experiment.queue_free()
	await _process_frames(4)


func _all_native_sizes(sizes: Array[int]) -> bool:
	if sizes.is_empty():
		return false
	for size: int in sizes:
		if size != 12 and size != 24:
			return false
	return true


func _label_is_on_screen(label: Label) -> bool:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var measured: Vector2 = font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	)
	var center_x: float = label.global_position.x + label.size.x * 0.5
	return (
		center_x - measured.x * 0.5 >= 0.0
		and center_x + measured.x * 0.5 <= 640.0
		and label.global_position.y >= 0.0
		and label.global_position.y + label.size.y <= 360.0
	)


func _send_key(key: Key, pressed: bool, echo: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _tap_f() -> void:
	await _send_key(KEY_F, true)
	await _send_key(KEY_F, false)
	await get_tree().physics_frame


func _tap_key(key: Key) -> void:
	await _send_key(key, true)
	await _send_key(key, false)
	await get_tree().physics_frame


func _process_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if bool(condition.call()):
			return
		await get_tree().process_frame


func _section(title: String) -> void:
	_log("")
	_log("--- %s ---" % title)


func _check(condition: bool, label: String) -> void:
	if condition:
		_pass += 1
		_log("PASS  " + label)
	else:
		_fail += 1
		_log("FAIL  " + label)
		print("FAIL  " + label)


func _log(line: String) -> void:
	_lines.append(line)
	print(line)


func _write_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % LOG_PATH)
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
