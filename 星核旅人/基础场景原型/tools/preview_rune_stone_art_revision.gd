extends Control

## Independent 640x360 art-review sheet for the concept-derived rune-stone states.
##
## Run:
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_rune_stone_art_revision.tscn
## Capture:
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_rune_stone_art_revision.tscn -- --capture-art-revision
##
## The sheet shows the same stone in three states (dormant, gold, cyan), each
## at actual 1x and integer 4x, over the project's real ruin background. The
## original player idle image is included only as a 1x size reference. This is
## an art review scene, not gameplay: it owns no physics, force, collision, map
## or shared F2 stone state.

const RUNE_SCENE: PackedScene = preload("res://scenes/rune_stone_visual.tscn")
const CHARACTER_IDLE_PATH: String = "res://assets/characters/male_hero-idle.png"
const CHARACTER_REGION: Rect2 = Rect2(41.0, 43.0, 32.0, 37.0)
const CAPTURE_PATH: String = "res://screenshots/rune_stone_art_revision.png"
const CAPTURE_SIZE: Vector2i = Vector2i(640, 360)

const COLUMN_X: Array[float] = [112.0, 320.0, 528.0]
const STONE_4X_CENTER_Y: float = 148.0
const STONE_1X_CENTER_Y: float = 250.0
const BASELINE_Y: float = 266.0
const CHARACTER_X: float = 344.0
const CHARACTER_Y: float = 229.0
const CENTER_1X_STONE_X: float = 292.0

const STATE_COLORS: Array[Color] = [
	Color("#aebbb8"),
	Color("#f4cd63"),
	Color("#5fe1e6"),
]
const STATE_TITLES: Array[String] = [
	"DORMANT / NO GLOW",
	"GOLD / POSITIVE",
	"CYAN / NEGATIVE",
]
const STATE_SUBTITLES: Array[String] = [
	"CONCEPT SPRITE / DARK CORE",
	"CONCEPT SPRITE / BAKED GOLD",
	"CONCEPT SPRITE / BAKED CYAN",
]

const TEXT_COLOR: Color = Color("#dce8e4")
const MUTED_COLOR: Color = Color("#7f999a")
const WARN_COLOR: Color = Color("#e8b96a")
const HEADER_FILL: Color = Color(0.02, 0.04, 0.05, 0.78)
const FOOTER_FILL: Color = Color(0.02, 0.04, 0.05, 0.84)
const DIM_OVERLAY: Color = Color(0.015, 0.03, 0.035, 0.18)
const BASELINE_COLOR: Color = Color(0.30, 0.46, 0.48, 0.48)

var _stones: Array[RuneStoneVisual] = []
var _status_label: Label
var _capture_mode: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)

	_add_ruins_background()
	_build()
	await get_tree().process_frame
	await get_tree().process_frame
	_update_art_status()

	if _capture_requested():
		_capture_mode = true
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var exit_code: int = _save_capture()
		get_tree().quit(exit_code)


func _add_ruins_background() -> void:
	# The real background layer from the game: sky gradient, ruin silhouettes
	# and mist. It sits on CanvasLayer -10, behind this review sheet.
	var background: PrototypeBackground = PrototypeBackground.new()
	background.name = "ActualRuinsBackground"
	add_child(background)


func _build() -> void:
	add_label(
		"RUNE STONE / CONCEPT SPRITE DIRECT 96->32",
		Vector2(18.0, 7.0),
		Vector2(430.0, 18.0),
		14,
		TEXT_COLOR
	)
	add_label(
		"APPROVED CONCEPT SPRITE / 32x32 NEAREST / SLEEP + GOLD + CYAN / SAME GEOMETRY / NOT GAMEPLAY",
		Vector2(18.0, 28.0),
		Vector2(604.0, 12.0),
		8,
		MUTED_COLOR
	)
	add_label(
		"CONCEPT-DERIVED / PENDING REVIEW",
		Vector2(288.0, 8.0),
		Vector2(350.0, 10.0),
		7,
		WARN_COLOR,
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	for index: int in range(3):
		var x: float = COLUMN_X[index]
		add_label(
			STATE_TITLES[index],
			Vector2(x - 90.0, 52.0),
			Vector2(180.0, 14.0),
			11,
			STATE_COLORS[index],
			HORIZONTAL_ALIGNMENT_CENTER
		)
		add_label(
			STATE_SUBTITLES[index],
			Vector2(x - 90.0, 66.0),
			Vector2(180.0, 10.0),
			7,
			MUTED_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		add_label(
			"4x INTEGER NEAR VIEW",
			Vector2(x - 90.0, 72.0),
			Vector2(180.0, 10.0),
			7,
			MUTED_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_spawn_stone(index, Vector2(x, STONE_4X_CENTER_Y), 4.0)
		add_label(
			"1x + PLAYER 1x" if index == 1 else "1x ACTUAL SIZE",
			Vector2(x - 90.0, 218.0),
			Vector2(180.0, 10.0),
			7,
			STATE_COLORS[index],
			HORIZONTAL_ALIGNMENT_CENTER
		)
		var one_x: float = CENTER_1X_STONE_X if index == 1 else x
		_spawn_stone(index, Vector2(one_x, STONE_1X_CENTER_Y), 1.0)

	_add_character_1x()
	add_label(
		"PLAYER 1x / IDLE #0",
		Vector2(320.0 - 60.0, 270.0),
		Vector2(120.0, 10.0),
		7,
		MUTED_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	add_label(
		"DIRECT 96->32 NEAREST: THE CONCEPT'S BAKED CORE, INNER WALL AND COLOURED REFLECTION ARE KEPT.",
		Vector2(18.0, 304.0),
		Vector2(604.0, 10.0),
		8,
		TEXT_COLOR
	)
	add_label(
		"SLEEP BASE + GOLD/CYAN ACCENT OVERLAY; DORMANT IS THE CONCEPT'S OWN DARK-CORE IMAGE.",
		Vector2(18.0, 316.0),
		Vector2(604.0, 10.0),
		7,
		MUTED_COLOR
	)
	add_label(
		"ACTUAL RUINS BACKGROUND USED FOR CONTRAST; NO PHYSICS, FORCE, MAP OR GAMEPLAY CHANGE.",
		Vector2(18.0, 328.0),
		Vector2(604.0, 10.0),
		7,
		MUTED_COLOR
	)
	_status_label = add_label(
		"ART: CHECKING LAYERS...",
		Vector2(18.0, 344.0),
		Vector2(604.0, 10.0),
		7,
		MUTED_COLOR
	)


func _spawn_stone(index: int, at: Vector2, scale_value: float) -> void:
	var stone: RuneStoneVisual = RUNE_SCENE.instantiate() as RuneStoneVisual
	stone.name = "RuneStone_%s_%s" % [
		"DORMANT" if index == 0 else ("GOLD" if index == 1 else "CYAN"),
		"1x" if is_equal_approx(scale_value, 1.0) else "4x",
	]
	stone.position = at
	stone.scale = Vector2.ONE * scale_value
	add_child(stone)
	if index == 0:
		stone.set_energized(false, true)
	else:
		stone.set_polarity(index == 1, true)
	_stones.append(stone)


func _add_character_1x() -> void:
	var image_texture: Texture2D = load_texture_safely(CHARACTER_IDLE_PATH)
	if image_texture == null:
		add_label(
			"CHARACTER PNG MISSING",
			Vector2(CHARACTER_X - 44.0, CHARACTER_Y + 12.0),
			Vector2(120.0, 10.0),
			7,
			WARN_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		return

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = image_texture
	atlas.region = CHARACTER_REGION
	atlas.filter_clip = true

	var character: TextureRect = TextureRect.new()
	character.name = "PlayerIdle1x"
	character.texture = atlas
	character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character.stretch_mode = TextureRect.STRETCH_KEEP
	character.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	character.position = Vector2(CHARACTER_X, CHARACTER_Y)
	character.size = CHARACTER_REGION.size
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(character)


func _update_art_status() -> void:
	if _status_label == null:
		return
	var loaded: int = 0
	var missing: Array[String] = []
	for stone: RuneStoneVisual in _stones:
		if stone.has_art():
			loaded += 1
		else:
			var file_name: String = stone.get_missing_texture_path().get_file()
			if not missing.has(file_name):
				missing.append(file_name)
	if loaded == _stones.size() and missing.is_empty():
		_status_label.text = (
			"ART: %d/%d STONES / 3/3 STATES 32x32  |  DIRECT 96->32 NEAREST  |  CONCEPT SPRITE / PENDING REVIEW"
			% [loaded, _stones.size()]
		)
		_status_label.add_theme_color_override("font_color", MUTED_COLOR)
	else:
		_status_label.text = (
			"ART: %d/%d STONES LOADED; MISSING %s"
			% [loaded, _stones.size(), ", ".join(missing)]
		)
		_status_label.add_theme_color_override("font_color", WARN_COLOR)
	print(
		"PREVIEW_RUNE_STONE_ART_REVISION stones=%d missing=%s"
		% [_stones.size(), ",".join(missing)]
	)


func load_texture_safely(path: String) -> Texture2D:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	return resource as Texture2D


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


func _draw() -> void:
	# A light dim keeps the review readable while the real ruins remain visible.
	draw_rect(Rect2(Vector2.ZERO, size), DIM_OVERLAY)
	draw_rect(Rect2(0.0, 0.0, size.x, 46.0), HEADER_FILL)
	draw_line(Vector2(0.0, 46.0), Vector2(size.x, 46.0), Color(0.21, 0.33, 0.36, 0.75), 1.0)
	draw_rect(Rect2(0.0, 298.0, size.x, size.y - 298.0), FOOTER_FILL)
	draw_line(Vector2(0.0, 298.0), Vector2(size.x, 298.0), Color(0.21, 0.33, 0.36, 0.75), 1.0)

	for index: int in range(3):
		var x: float = COLUMN_X[index]
		var accent: Color = STATE_COLORS[index]
		draw_rect(
			Rect2(x - 70.0, 80.0, 140.0, 148.0),
			Color(accent.r, accent.g, accent.b, 0.14),
			false,
			1.0
		)
		draw_line(
			Vector2(x - 70.0, 80.0),
			Vector2(x - 70.0, 88.0),
			Color(accent.r, accent.g, accent.b, 0.72),
			2.0
		)
		draw_line(
			Vector2(x + 70.0, 220.0),
			Vector2(x + 70.0, 228.0),
			Color(accent.r, accent.g, accent.b, 0.72),
			2.0
		)

	draw_line(Vector2(28.0, BASELINE_Y), Vector2(612.0, BASELINE_Y), BASELINE_COLOR, 1.0)
	draw_line(Vector2(216.0, 52.0), Vector2(216.0, 292.0), Color(0.21, 0.33, 0.36, 0.32), 1.0)
	draw_line(Vector2(424.0, 52.0), Vector2(424.0, 292.0), Color(0.21, 0.33, 0.36, 0.32), 1.0)


func _capture_requested() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return args.has("--capture-art-revision")


func _save_capture() -> int:
	var directory: String = ProjectSettings.globalize_path("res://screenshots")
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		printerr("ART_REVISION_CAPTURE_FAILED cannot create %s error=%d" % [directory, dir_error])
		return 1

	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != CAPTURE_SIZE:
		printerr(
			"ART_REVISION_CAPTURE_NOTE viewport image %s resized to %s with nearest filtering."
			% [str(image.get_size()), str(CAPTURE_SIZE)]
		)
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)

	var absolute_path: String = ProjectSettings.globalize_path(CAPTURE_PATH)
	var save_error: Error = image.save_png(absolute_path)
	if save_error != OK:
		printerr("ART_REVISION_CAPTURE_FAILED %s error=%d" % [CAPTURE_PATH, save_error])
		return 1
	print("ART_REVISION_CAPTURED %s size=%s" % [CAPTURE_PATH, str(image.get_size())])
	return 0
