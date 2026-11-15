extends Control

## Standalone 640x360 visual preview for the star-core component.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_star_core.tscn
## Optional engine capture:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_star_core.tscn -- --capture-preview
##
## This is a look-dev sheet, not gameplay. It does not create physics, suction,
## interaction, a star-core bay, or any substitute art. If the parallel art pass
## has not landed yet, the component's neutral placeholders are shown and the
## status line names the missing files.
##
## All six instances play the 12-frame sheets at 12 FPS. The optional engine
## capture freezes them on frame 3 first, so the screenshot is a set-frame still,
## not a claim about continuous playback.

const CORE_SCENE: PackedScene = preload("res://scenes/star_core_visual.tscn")
const CAPTURE_PATH: String = "res://screenshots/star_core_visual_preview.png"
const CAPTURE_SIZE: Vector2i = Vector2i(640, 360)
const CAPTURE_FRAME: int = 3

const COLUMN_X: Array[float] = [110.0, 320.0, 530.0]
const STATE_TITLES: Array[String] = ["LOCKED", "POSITIVE", "NEGATIVE"]
const STATE_SUBTITLES: Array[String] = ["STORED / LOCKED", "GOLD / PLUS", "CYAN / MINUS"]
const STATE_COLORS: Array[Color] = [
	Color("#c8a7f2"),
	Color("#f4cd63"),
	Color("#5fe1e6"),
]

const BG_COLOR: Color = Color("#071016")
const HEADER_COLOR: Color = Color("#0b171d")
const PANEL_COLOR: Color = Color("#0a141a")
const GRID_COLOR: Color = Color(0.12, 0.22, 0.25, 0.40)
const BORDER_COLOR: Color = Color(0.24, 0.40, 0.42, 0.75)
const TEXT_COLOR: Color = Color("#dce8e4")
const MUTED_COLOR: Color = Color("#7f999a")
const WARN_COLOR: Color = Color("#e8b96a")

var _cores: Array[StarCoreVisual] = []
var _status_label: Label
var _frame_label: Label
var _capture_mode: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)

	_build()
	await get_tree().process_frame
	_update_art_status()

	if _capture_requested():
		_capture_mode = true
		await get_tree().process_frame
		await get_tree().process_frame
		for core: StarCoreVisual in _cores:
			core.animate = false
			core.set_animation_frame(CAPTURE_FRAME)
		_frame_label.text = (
			"FRAME %02d/%d (SET FOR THIS ENGINE STILL; NOT CONTINUOUS PLAYBACK)"
			% [CAPTURE_FRAME + 1, StarCoreVisual.FRAME_COUNT]
		)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var exit_code: int = _save_capture()
		get_tree().quit(exit_code)


func _process(_delta: float) -> void:
	if _capture_mode or _frame_label == null or _cores.is_empty():
		return
	var core: StarCoreVisual = _cores[0]
	_frame_label.text = "LOOP %02d/%02d  |  12 FPS  |  FRAME SHOWN 16x16; SOURCE SHEET 192x16" % [
		core.get_animation_frame() + 1,
		maxi(core.get_animation_frame_count(), StarCoreVisual.FRAME_COUNT),
	]


func _draw() -> void:
	var canvas: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(canvas, BG_COLOR)

	for x: int in range(0, int(size.x) + 1, 32):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), size.y), GRID_COLOR, 1.0)
	for y: int in range(0, int(size.y) + 1, 32):
		draw_line(Vector2(0.0, float(y)), Vector2(size.x, float(y)), GRID_COLOR, 1.0)

	draw_rect(Rect2(0.0, 0.0, size.x, 48.0), HEADER_COLOR)
	draw_line(Vector2(0.0, 48.0), Vector2(size.x, 48.0), BORDER_COLOR, 1.0)
	draw_rect(Rect2(0.0, 270.0, size.x, size.y - 270.0), PANEL_COLOR)
	draw_line(Vector2(0.0, 270.0), Vector2(size.x, 270.0), BORDER_COLOR, 1.0)

	for separator_x: float in [215.0, 425.0]:
		draw_line(Vector2(separator_x, 54.0), Vector2(separator_x, 266.0), BORDER_COLOR, 1.0)

	for index: int in STATE_COLORS.size():
		draw_rect(
			Rect2(COLUMN_X[index] - 26.0, 84.0, 52.0, 1.0),
			STATE_COLORS[index]
		)


func _build() -> void:
	add_label("STAR CORE VISUAL PREVIEW", Vector2(20.0, 9.0), Vector2(600.0, 18.0), 14, TEXT_COLOR)
	add_label(
		"VISUAL COMPONENT ONLY  /  NOT GAMEPLAY  /  12 FRAMES  /  16x16 FRAME AT 1:1 NEAREST",
		Vector2(20.0, 31.0),
		Vector2(600.0, 12.0),
		8,
		MUTED_COLOR
	)

	for index: int in range(3):
		var x: float = COLUMN_X[index]
		add_label(
			STATE_TITLES[index],
			Vector2(x - 90.0, 57.0),
			Vector2(180.0, 14.0),
			10,
			STATE_COLORS[index],
			HORIZONTAL_ALIGNMENT_CENTER
		)
		add_label(
			STATE_SUBTITLES[index],
			Vector2(x - 90.0, 70.0),
			Vector2(180.0, 10.0),
			7,
			MUTED_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		add_label(
			"ACTUAL SIZE (1x)",
			Vector2(x - 90.0, 93.0),
			Vector2(180.0, 10.0),
			7,
			MUTED_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_spawn_core(index, Vector2(x, 118.0), 1.0)
		add_label(
			"NEAR VIEW (4x, INTEGER SCALE)",
			Vector2(x - 90.0, 151.0),
			Vector2(180.0, 10.0),
			7,
			MUTED_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_spawn_core(index, Vector2(x, 204.0), 4.0)

	_status_label = add_label(
		"ART STATUS: checking source PNGs...",
		Vector2(20.0, 274.0),
		Vector2(600.0, 20.0),
		8,
		MUTED_COLOR
	)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_frame_label = add_label(
		"LOOP 01/12  |  12 FPS  |  FRAME SHOWN 16x16; SOURCE SHEET 192x16",
		Vector2(20.0, 295.0),
		Vector2(600.0, 10.0),
		7,
		MUTED_COLOR
	)

	add_label(
		"STATE BADGES ARE DRAWN IN CODE, OUTSIDE THE 16x16 FRAME AND NEVER MIRRORED OR ROTATED.",
		Vector2(20.0, 307.0),
		Vector2(600.0, 10.0),
		7,
		MUTED_COLOR
	)
	add_label(
		"SOURCE SHEETS ARE 192x16 (12 FRAMES); EACH DISPLAYED FRAME IS 16x16. 4x MAGNIFICATION IS PREVIEW ONLY.",
		Vector2(20.0, 319.0),
		Vector2(600.0, 10.0),
		7,
		MUTED_COLOR
	)
	add_label(
		"VISUAL PREVIEW ONLY - NO PHYSICS, SUCTION, INTERACTION, OR STAR-CORE BAY LOGIC.",
		Vector2(20.0, 338.0),
		Vector2(600.0, 12.0),
		8,
		TEXT_COLOR
	)


func _spawn_core(state_index: int, at: Vector2, zoom: float) -> void:
	var core: StarCoreVisual = CORE_SCENE.instantiate() as StarCoreVisual
	core.name = "Core_%s_%s" % [STATE_TITLES[state_index], "1x" if zoom == 1.0 else "4x"]
	core.position = at
	core.scale = Vector2.ONE * zoom
	add_child(core)
	match state_index:
		1:
			core.state = StarCoreVisual.CoreState.POSITIVE
		2:
			core.state = StarCoreVisual.CoreState.NEGATIVE
		_:
			core.state = StarCoreVisual.CoreState.LOCKED
	_cores.append(core)


func add_label(
	text: String,
	at: Vector2,
	box_size: Vector2,
	font_size: int,
	color: Color,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.size = box_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _update_art_status() -> void:
	var loaded_states: Dictionary = {}
	var bad_size_states: Dictionary = {}
	var bad_sheet_states: Dictionary = {}
	var missing_names: Array[String] = []

	for core: StarCoreVisual in _cores:
		if core.has_art():
			loaded_states[core.state] = true
			var texture: Texture2D = core.get_art_texture()
			if texture == null or Vector2i(texture.get_size()) != core.get_source_size():
				bad_size_states[core.state] = true
			var sheet: Texture2D = core.get_art_sheet()
			if sheet != null and Vector2i(sheet.get_size()) != core.get_source_sheet_size():
				bad_sheet_states[core.state] = true
		else:
			var file_name: String = core.get_missing_texture_path().get_file()
			if not missing_names.has(file_name):
				missing_names.append(file_name)

	var loaded_count: int = loaded_states.size()
	var text: String
	if loaded_count == 3:
		text = (
			"ART STATUS: 3/3 state sheets loaded at 12 FPS; each frame is 16x16. "
			+ "Colours come from the 192x16 source sheets; badges are code-drawn."
		)
	else:
		text = (
			"ART STATUS: %d/3 state sheets loaded. Missing: %s. "
			+ "Neutral dashed placeholders shown; no substitute art is generated."
		) % [loaded_count, ", ".join(missing_names)]

	if not bad_size_states.is_empty():
		text += " FRAME SIZE MISMATCH: expected 16x16, shown 1:1 without rescaling."
	if not bad_sheet_states.is_empty():
		text += " SHEET SIZE MISMATCH: expected 192x16."

	_status_label.text = text
	_status_label.add_theme_color_override(
		"font_color",
		MUTED_COLOR if missing_names.is_empty() and bad_size_states.is_empty() and bad_sheet_states.is_empty() else WARN_COLOR
	)
	print(
		"PREVIEW_ART states_loaded=%d missing=%s size_mismatch=%d sheet_mismatch=%d"
		% [loaded_count, ",".join(missing_names), bad_size_states.size(), bad_sheet_states.size()]
	)


func _capture_requested() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return args.has("--capture-preview")


func _save_capture() -> int:
	var directory: String = ProjectSettings.globalize_path("res://screenshots")
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		printerr("PREVIEW_CAPTURE_FAILED cannot create %s error=%d" % [directory, dir_error])
		return 1

	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != CAPTURE_SIZE:
		printerr(
			"PREVIEW_CAPTURE_NOTE viewport image %s resized to %s with nearest filtering."
			% [str(image.get_size()), str(CAPTURE_SIZE)]
		)
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)

	var absolute_path: String = ProjectSettings.globalize_path(CAPTURE_PATH)
	var save_error: Error = image.save_png(absolute_path)
	if save_error != OK:
		printerr("PREVIEW_CAPTURE_FAILED %s error=%d" % [CAPTURE_PATH, save_error])
		return 1
	print("PREVIEW_CAPTURED %s size=%s" % [CAPTURE_PATH, str(image.get_size())])
	return 0
