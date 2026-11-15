extends Control

## Engine-rendered keyframe sheet for the 12-frame star-core animation.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_star_core_animation.tscn
## Optional capture:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_star_core_animation.tscn -- --capture-keyframes
##
## The image is a 640x360 engine viewport capture of four deliberately set
## frames (0/3/6/9) for each state. It is not a video and not a claim about
## continuous playback. All sprites are 16x16 frames at integer 4x preview
## magnification; the badge is drawn by StarCoreVisual and stays fixed.

const CORE_SCENE: PackedScene = preload("res://scenes/star_core_visual.tscn")
const CAPTURE_PATH: String = "res://screenshots/star_core_animation_keyframes.png"
const CAPTURE_SIZE: Vector2i = Vector2i(640, 360)
const DISPLAY_SCALE: float = 3.0
const CELL_SIZE: float = 48.0
const FRAMES: Array[int] = [0, 3, 6, 9]

const STATE_TITLES: Array[String] = ["LOCKED", "POSITIVE", "NEGATIVE"]
const STATE_NOTES: Array[String] = ["PURPLE / IN BAY", "GOLD / PLUS", "CYAN / MINUS"]
const STATE_COLORS: Array[Color] = [
	Color("#c8a7f2"),
	Color("#f4cd63"),
	Color("#5fe1e6"),
]

const GRID_X: float = 190.0
const ROW_Y: float = 72.0
const ROW_STEP: float = 70.0
const CELL_STEP: float = 64.0

const BG_COLOR: Color = Color("#071016")
const PANEL_COLOR: Color = Color("#0a141a")
const GRID_COLOR: Color = Color(0.12, 0.22, 0.25, 0.40)
const BORDER_COLOR: Color = Color(0.24, 0.40, 0.42, 0.75)
const TEXT_COLOR: Color = Color("#dce8e4")
const MUTED_COLOR: Color = Color("#7f999a")

var _cores: Array[StarCoreVisual] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)

	_build()
	await get_tree().process_frame
	await get_tree().process_frame

	if _capture_requested():
		await RenderingServer.frame_post_draw
		var exit_code: int = _save_capture()
		get_tree().quit(exit_code)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)

	for x: int in range(0, int(size.x) + 1, 32):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), size.y), GRID_COLOR, 1.0)
	for y: int in range(0, int(size.y) + 1, 32):
		draw_line(Vector2(0.0, float(y)), Vector2(size.x, float(y)), GRID_COLOR, 1.0)

	draw_rect(Rect2(0.0, 0.0, size.x, 54.0), PANEL_COLOR)
	draw_line(Vector2(0.0, 54.0), Vector2(size.x, 54.0), BORDER_COLOR, 1.0)
	draw_line(Vector2(0.0, 306.0), Vector2(size.x, 306.0), BORDER_COLOR, 1.0)

	for row: int in range(STATE_TITLES.size()):
		var y: float = ROW_Y + row * ROW_STEP
		for column: int in range(FRAMES.size()):
			var x: float = GRID_X + column * CELL_STEP
			draw_rect(Rect2(x, y, CELL_SIZE, CELL_SIZE), Color(0.10, 0.17, 0.20, 0.58))
			draw_rect(Rect2(x, y, CELL_SIZE, CELL_SIZE), Color(0.30, 0.45, 0.47, 0.55), false, 1.0)
		draw_line(
			Vector2(16.0, y + CELL_SIZE + 6.0),
			Vector2(624.0, y + CELL_SIZE + 6.0),
			Color(BORDER_COLOR, 0.35),
			1.0
		)


func _build() -> void:
	add_label(
		"STAR CORE 12-FRAME ANIMATION KEYFRAMES",
		Vector2(18.0, 8.0),
		Vector2(604.0, 18.0),
		14,
		TEXT_COLOR
	)
	add_label(
		"ENGINE VIEWPORT CAPTURE  /  SET FRAMES 0 / 3 / 6 / 9 OF 12  /  12 FPS LOOP  /  NOT CONTINUOUS PLAYBACK",
		Vector2(18.0, 30.0),
		Vector2(604.0, 12.0),
		8,
		MUTED_COLOR
	)
	add_label(
		"16x16 FRAME AT INTEGER 3x  /  BADGES OMITTED HERE; SEE THE COMPONENT PREVIEW",
		Vector2(18.0, 42.0),
		Vector2(604.0, 10.0),
		7,
		MUTED_COLOR
	)

	for column: int in range(FRAMES.size()):
		add_label(
			"FRAME %02d" % FRAMES[column],
			Vector2(GRID_X + column * CELL_STEP, 58.0),
			Vector2(CELL_SIZE, 10.0),
			7,
			STATE_COLORS[0],
			HORIZONTAL_ALIGNMENT_CENTER
		)

	for row: int in range(STATE_TITLES.size()):
		var y: float = ROW_Y + row * ROW_STEP
		add_label(
			STATE_TITLES[row],
			Vector2(18.0, y + 8.0),
			Vector2(130.0, 14.0),
			10,
			STATE_COLORS[row]
		)
		add_label(
			STATE_NOTES[row],
			Vector2(18.0, y + 24.0),
			Vector2(130.0, 10.0),
			7,
			MUTED_COLOR
		)
		add_label(
			"192x16 / 12 FRAMES",
			Vector2(18.0, y + 38.0),
			Vector2(130.0, 10.0),
			7,
			MUTED_COLOR
		)

		for column: int in range(FRAMES.size()):
			_spawn_core(row, FRAMES[column], Vector2(
				GRID_X + column * CELL_STEP + CELL_SIZE * 0.5,
				y + CELL_SIZE * 0.5
			))

	add_label(
		"FRAME PHASE IS SET EXPLICITLY FOR THIS STILL. THE COMPONENT LOOPS ALL 12 FRAMES AT 12 FPS AT RUNTIME.",
		Vector2(18.0, 296.0),
		Vector2(604.0, 10.0),
		7,
		TEXT_COLOR
	)
	add_label(
		"VISUAL PREVIEW ONLY - NO PHYSICS, SUCTION, INTERACTION, OR STAR-CORE BAY LOGIC.",
		Vector2(18.0, 312.0),
		Vector2(604.0, 10.0),
		8,
		TEXT_COLOR
	)
	add_label(
		"SOURCE: Frakassets Free Shiny Gem \"Round\" / CC BY 4.0 / 12-frame 16px 0d sheet, recoloured by this project.",
		Vector2(18.0, 330.0),
		Vector2(604.0, 10.0),
		6,
		MUTED_COLOR
	)


func _spawn_core(state_index: int, frame: int, at: Vector2) -> void:
	var core: StarCoreVisual = CORE_SCENE.instantiate() as StarCoreVisual
	core.name = "Core_%s_F%02d" % [STATE_TITLES[state_index], frame]
	core.position = at
	core.scale = Vector2.ONE * DISPLAY_SCALE
	core.animate = false
	core.show_state_badge = false
	add_child(core)
	match state_index:
		1:
			core.state = StarCoreVisual.CoreState.POSITIVE
		2:
			core.state = StarCoreVisual.CoreState.NEGATIVE
		_:
			core.state = StarCoreVisual.CoreState.LOCKED
	core.set_animation_frame(frame)
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


func _capture_requested() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return args.has("--capture-keyframes")


func _save_capture() -> int:
	var directory: String = ProjectSettings.globalize_path("res://screenshots")
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		printerr("KEYFRAME_CAPTURE_FAILED cannot create %s error=%d" % [directory, dir_error])
		return 1

	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != CAPTURE_SIZE:
		printerr(
			"KEYFRAME_CAPTURE_NOTE viewport image %s resized to %s with nearest filtering."
			% [str(image.get_size()), str(CAPTURE_SIZE)]
		)
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)

	var absolute_path: String = ProjectSettings.globalize_path(CAPTURE_PATH)
	var save_error: Error = image.save_png(absolute_path)
	if save_error != OK:
		printerr("KEYFRAME_CAPTURE_FAILED %s error=%d" % [CAPTURE_PATH, save_error])
		return 1
	print("KEYFRAME_CAPTURED %s size=%s frames=%s" % [
		CAPTURE_PATH,
		str(image.get_size()),
		str(FRAMES),
	])
	return 0
