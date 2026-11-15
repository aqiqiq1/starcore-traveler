extends Node

## Engine screenshots for the polarity-record test room.
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tools/capture_polarity_record.tscn
##
## All four images are stills from a scripted 60 Hz physics run using the real
## InputMap actions, not a manual playthrough and not pre-rendered art. The
## manifest labels each image and the store/commit timing.

const STANDALONE_SCENE: PackedScene = preload("res://scenes/polarity_record_test_room_standalone.tscn")
const CAPTURE_DIR: String = "res://screenshots"

var _standalone: Node2D
var _room: PolarityRecordTestRoom
var _player: PrototypePlayer
var _hud: PrototypeHUD
var _link: BayRuneLink
var _field: RuneStoneField
var _linked_bay: StarCoreBayInteractable
var _capture_label: Label
var _manifest: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))

	_standalone = STANDALONE_SCENE.instantiate() as Node2D
	add_child(_standalone)
	await get_tree().process_frame
	await get_tree().process_frame
	_room = _standalone.get_room() as PolarityRecordTestRoom
	_player = _standalone.get_player() as PrototypePlayer
	_hud = _standalone.get_hud() as PrototypeHUD
	_link = _room.get_link()
	_field = _room.get_rune_field()
	_linked_bay = _room.get_linked_bay()
	_build_capture_overlay()

	_manifest.append("Star Core Traveler - polarity record test room engine captures")
	_manifest.append("Godot: %s" % Engine.get_version_info()["string"])
	_manifest.append("Display: %s  renderer: %s" % [
		DisplayServer.get_name(),
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
	])
	_manifest.append("Window: %s  logical viewport: 640x360" % str(DisplayServer.window_get_size()))
	_manifest.append("All images are stills captured from the running engine viewport.")
	_manifest.append("Each still comes from a scripted 60 Hz physics run driven by the same")
	_manifest.append("InputMap actions as the acceptance tests. They are not a video and not")
	_manifest.append("a manual playthrough; continuous behaviour is covered by the 210 headless")
	_manifest.append("record assertions plus the existing F2/visual/field/link regressions.")
	_manifest.append("The F7 stone uses the shared 32x32 concept-derived sleep/gold/cyan")
	_manifest.append("states (96->32 NEAREST); its initial dormant state, first light-up")
	_manifest.append("and late polarity commit are unchanged.")
	_manifest.append("")

	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await get_tree().process_frame
		await get_tree().process_frame

	print("CAPTURE_INITIAL field_active=%s visual_energized=%s hint=%s" % [
		str(_field.is_activated()),
		str(_field.get_visual().is_energized()),
		str(_field.get_visual().get_hint_kind()),
	])
	await _capture(
		"record_01_initial_no_history.png",
		"ENGINE CAPTURE 640x360  |  SCRIPTED STILL: INITIAL  |  LAMP NEUTRAL / NO RECORD  |  STONE INACTIVE / CONCEPT SLEEP DARK / NO FORCE  |  F7 BACK"
	)

	# Real input route: GOLD player -> E release (CYAN core) -> walk -> E store.
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(2)
	await _step(19)
	await _walk_to_x(338.0)
	await _wait_until(
		func() -> bool:
			return (
				_linked_bay.is_core_in_store_zone(_room.get_core().global_position)
				and _hud.get_interaction_e_text().contains("STORE CORE (LINKED)")
			),
		180
	)
	await _tap_action(&"interact")
	await _step(6)
	await _capture(
		"record_02_store_cyan_lamp_immediate.png",
		"ENGINE CAPTURE 640x360  |  SCRIPTED STILL: E STORE ACCEPTED  |  CORE CYAN RECORDED -> LAMP CYAN NOW  |  PULSE IN FLIGHT / FIELD INACTIVE / ZERO FORCE"
	)

	# Wait for the pulse and the stone's own dim/relight to finish, then stand in
	# the stone field with F3 debug for readable force direction.
	await _wait_until(
		func() -> bool:
			return (
				not _link.has_pending_pulse()
				and not _link.is_field_pending()
				and _field.is_activated()
				and not _field.is_positive()
				and not _field.is_transitioning()
			),
		240
	)
	_check_capture("first activation commits CYAN only after light-up", _field.is_activated() and not _field.is_positive())
	_player.set_debug_enabled(true)
	_hud.set_debug_visible(true)
	_field.set_debug_enabled(true)
	_player.global_position = Vector2(450.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(2)
	await _capture(
		"record_03_cyan_stone_live.png",
		"ENGINE CAPTURE 640x360  |  SCRIPTED STILL: FIRST DARK-TO-CYAN LIGHT-UP COMPLETE  |  CONCEPT CYAN ACTIVE / RECORD HELD  |  F3 RANGE+FORCE"
	)

	# Overwrite: CYAN player releases a GOLD core from the linked bay, then stores
	# it again into the same bay. The record/lamp changes at accept, field waits.
	_player.global_position = Vector2(340.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(2)
	await _tap_action(&"polarity")
	await _tap_action(&"interact")
	await _step(20)
	_room.get_core().global_position = _linked_bay.get_store_center()
	_room.get_core().velocity = Vector2.ZERO
	await _step(1)
	await _tap_action(&"interact")
	await _step(1)
	await _wait_until(
		func() -> bool:
			return (
				not _link.has_pending_pulse()
				and not _link.is_field_pending()
				and _field.is_activated()
				and _field.is_positive()
				and not _field.is_transitioning()
			),
		240
	)
	_check_capture("overwrite commits GOLD after light-up", _field.is_activated() and _field.is_positive())
	_player.global_position = Vector2(450.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(2)
	await _capture(
		"record_04_overwrite_gold_live.png",
		"ENGINE CAPTURE 640x360  |  SCRIPTED STILL: SECOND E STORE OVERWRITES RECORD  |  LAMP GOLD / STONE GOLD LIVE  |  CORE GOLD IN LINKED BAY"
	)

	_manifest.append("record_01_initial_no_history.png | SCRIPTED STILL | spawn; linked bay empty; lamp neutral; stone INACTIVE with the concept sleep image and no force; HUD NO RECORD / INACTIVE")
	_manifest.append("record_02_store_cyan_lamp_immediate.png | SCRIPTED STILL | 6 frames after real E store; bay record CYAN; lamp CYAN before pulse arrival; field still INACTIVE with exact zero force")
	_manifest.append("record_03_cyan_stone_live.png | SCRIPTED STILL | first dark-to-cyan light-up finished on the concept-derived stone; field becomes active CYAN; player in F3 range view")
	_manifest.append("record_04_overwrite_gold_live.png | SCRIPTED STILL | second real E store records GOLD; lamp and stone commit GOLD; HUD record held")
	_manifest.append("")
	_manifest.append("Store/commit timing shown: record and lamp update at E accept; the field's")
	_manifest.append("force sign changes only after its own visual transition. The screenshots do")
	_manifest.append("not test continuous play feel.")
	_write_manifest()
	print("CAPTURE_POLARITY_RECORD_DONE shots=4")
	get_tree().quit(0)


func _check_capture(label: String, condition: bool) -> void:
	if condition:
		print("CAPTURE_CHECK OK %s" % label)
	else:
		printerr("CAPTURE_CHECK FAILED %s" % label)


func _capture(file_name: String, caption: String) -> void:
	_capture_label.text = caption
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var absolute_path: String = ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
	var error: Error = image.save_png(absolute_path)
	if error != OK:
		printerr("CAPTURE FAILED %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])


func _build_capture_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CaptureOverlay"
	layer.layer = 20
	add_child(layer)

	var root: Control = Control.new()
	root.size = Vector2(640.0, 360.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Bottom strip sits on the floor tiles, away from the toast and play area, so
	# temporary HUD toasts stay readable in the proof image.
	var panel: Panel = Panel.new()
	panel.position = Vector2(7.0, 330.0)
	panel.size = Vector2(626.0, 16.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.04, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.55, 0.75, 0.70, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	_capture_label = Label.new()
	_capture_label.position = Vector2(12.0, 332.0)
	_capture_label.size = Vector2(616.0, 12.0)
	_capture_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_label.add_theme_font_size_override("font_size", 7)
	_capture_label.add_theme_color_override("font_color", Color("#e9efeb"))
	root.add_child(_capture_label)


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(CAPTURE_DIR + "/MANIFEST_RECORD.txt", FileAccess.WRITE)
	if file == null:
		printerr("Could not write MANIFEST_RECORD.txt")
		return
	for line: String in _manifest:
		file.store_line(line)
	file.close()


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await _step(1)
	Input.action_release(action)
	await _step(1)


func _walk_to_x(target_x: float, max_frames: int = 240) -> void:
	Input.action_press(&"move_right")
	for i: int in range(max_frames):
		await _step(1)
		if _player.global_position.x >= target_x:
			break
	Input.action_release(&"move_right")
	await _step(3)


func _wait_until(predicate: Callable, max_frames: int) -> void:
	for i: int in range(max_frames):
		if bool(predicate.call()):
			return
		await _step(1)


func _step(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame
