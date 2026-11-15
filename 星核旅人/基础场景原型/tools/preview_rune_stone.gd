extends Control

## Standalone 640x360 look-dev sheet for the rune-stone visual component.
##
## Run:
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_rune_stone.tscn
## Optional engine capture:
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_rune_stone.tscn -- --capture-preview
##
## Gold and cyan are shown side by side at actual size and at integer 4x. The
## original character idle #0 is shown at actual 1x for scale only. SPACE swaps
## the two columns through the component's dim-then-relight transition.
##
## Both columns use the same concept-derived 32x32 state PNGs (direct 96->32
## NEAREST). This scene is a visual preview, not gameplay: it has no physics,
## force field, collision, map, or connection to the shared F2 temporary stone.

const RUNE_SCENE: PackedScene = preload("res://scenes/rune_stone_visual.tscn")
const CHARACTER_IDLE_PATH: String = "res://assets/characters/male_hero-idle.png"
const CHARACTER_REGION: Rect2 = Rect2(41.0, 43.0, 32.0, 37.0)
const CAPTURE_PATH: String = "res://screenshots/rune_stone_visual_preview.png"
const CAPTURE_SIZE: Vector2i = Vector2i(640, 360)

const COLUMN_X: Array[float] = [150.0, 490.0]
const STONE_1X_Y: float = 244.0
const STONE_4X_Y: float = 196.0
const CHARACTER_X: float = 304.0
const CHARACTER_Y: float = 223.0
const BASELINE_Y: float = 260.0

const STATE_COLORS: Array[Color] = [
	Color("#f4cd63"),
	Color("#5fe1e6"),
]
const STATE_TITLES: Array[String] = ["GOLD / POSITIVE", "CYAN / NEGATIVE"]

const BG_COLOR: Color = Color("#071016")
const HEADER_COLOR: Color = Color("#0b171d")
const PANEL_COLOR: Color = Color("#0a141a")
const PANEL_BORDER: Color = Color(0.21, 0.33, 0.36, 0.75)
const GRID_COLOR: Color = Color(0.10, 0.18, 0.21, 0.42)
const TEXT_COLOR: Color = Color("#dce8e4")
const MUTED_COLOR: Color = Color("#7f999a")
const WARN_COLOR: Color = Color("#e8b96a")
const BASELINE_COLOR: Color = Color(0.30, 0.46, 0.48, 0.60)

var _stones_1x: Array[RuneStoneVisual] = []
var _stones_4x: Array[RuneStoneVisual] = []
var _column_positive: Array[bool] = [true, false]
var _title_labels: Array[Label] = []
var _state_labels: Array[Label] = []
var _hint_labels: Array[Label] = []
var _status_label: Label
var _capture_mode: bool = false
var _demo_busy: bool = false
var _demo_finished_count: int = 0


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
		await RenderingServer.frame_post_draw
		var exit_code: int = _save_capture()
		get_tree().quit(exit_code)


func _process(_delta: float) -> void:
	if _capture_mode or _status_label == null:
		return
	if _demo_busy and not _stones_4x.is_empty():
		var stone: RuneStoneVisual = _stones_4x[0]
		var target: String = "CYAN" if _column_positive[0] else "GOLD"
		_status_label.text = (
			"TRANSITION: %s  |  DIM %d%% / RELIGHT  |  STONE TRANSFORM FIXED"
			% [target, int(round(stone.get_transition_progress() * 100.0))]
		)
		_status_label.add_theme_color_override(
			"font_color",
			STATE_COLORS[0] if _column_positive[0] else STATE_COLORS[1]
		)


func _unhandled_input(event: InputEvent) -> void:
	if _capture_mode:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_SPACE:
			toggle_demo()
			get_viewport().set_input_as_handled()


## Exposed for the independent test and for the SPACE demo. It never changes
## gameplay state; it only calls the visual component's set_polarity.
func toggle_demo() -> void:
	if _demo_busy:
		return
	if _stones_1x.size() != 2 or _stones_4x.size() != 2:
		return
	_demo_busy = true
	_demo_finished_count = 0
	for index: int in range(2):
		_column_positive[index] = not _column_positive[index]
		_stones_1x[index].set_polarity(_column_positive[index], false)
		_stones_4x[index].set_polarity(_column_positive[index], false)
	_status_label.text = "TRANSITION: DIM FIRST, THEN RELIGHT IN THE NEW COLOUR."
	_status_label.add_theme_color_override("font_color", MUTED_COLOR)


func is_demo_busy() -> bool:
	return _demo_busy


func get_demo_stones_1x() -> Array[RuneStoneVisual]:
	return _stones_1x


func get_demo_stones_4x() -> Array[RuneStoneVisual]:
	return _stones_4x


func _on_column_transition_finished(positive: bool, column: int) -> void:
	if column < 0 or column >= _title_labels.size():
		return
	_update_column_label(column, positive)
	_demo_finished_count += 1
	if _demo_finished_count >= 2:
		_demo_busy = false
		_status_label.text = (
			"TRANSITION FINISHED: A=%s  B=%s  |  VISUAL SIGNAL ONLY"
			% [
				"GOLD" if _column_positive[0] else "CYAN",
				"GOLD" if _column_positive[1] else "CYAN",
			]
		)
		_status_label.add_theme_color_override("font_color", MUTED_COLOR)


func _build() -> void:
	add_label(
		"RUNE STONE VISUAL PREVIEW",
		Vector2(18.0, 7.0),
		Vector2(604.0, 18.0),
		14,
		TEXT_COLOR
	)
	add_label(
		"32x32 CONCEPT STATE PNGS  /  DIRECT 96->32 NEAREST  /  SAME GEOMETRY BOTH POLARITIES  /  NOT GAMEPLAY",
		Vector2(18.0, 28.0),
		Vector2(604.0, 12.0),
		8,
		MUTED_COLOR
	)
	add_label(
		"NEAREST / 96->32",
		Vector2(470.0, 7.0),
		Vector2(152.0, 12.0),
		8,
		WARN_COLOR,
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	for index: int in range(2):
		var x: float = COLUMN_X[index]
		_title_labels.append(add_label(
			STATE_TITLES[index],
			Vector2(x - 90.0, 54.0),
			Vector2(180.0, 14.0),
			11,
			STATE_COLORS[index],
			HORIZONTAL_ALIGNMENT_CENTER
		))
		_state_labels.append(add_label(
			"COLUMN %s  /  SAME STONE" % ("A" if index == 0 else "B"),
			Vector2(x - 90.0, 68.0),
			Vector2(180.0, 10.0),
			7,
			MUTED_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER
		))
		add_label(
			"4x INTEGER NEAR VIEW",
			Vector2(x - 90.0, 112.0),
			Vector2(180.0, 10.0),
			7,
			MUTED_COLOR,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_spawn_stone(index, Vector2(x, STONE_4X_Y), 4.0, false)
		_hint_labels.append(add_label(
			"1x + FORCED HINT",
			Vector2(x - 45.0, 262.0),
			Vector2(90.0, 10.0),
			7,
			STATE_COLORS[index],
			HORIZONTAL_ALIGNMENT_CENTER
		))
		_spawn_stone(
			index,
			Vector2(54.0 if index == 0 else 586.0, STONE_1X_Y),
			1.0,
			true
		)

	add_label(
		"PLAYER 1x",
		Vector2(255.0, 202.0),
		Vector2(130.0, 11.0),
		8,
		TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	add_label(
		"idle #0 / visible pixels",
		Vector2(255.0, 214.0),
		Vector2(130.0, 9.0),
		7,
		MUTED_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_add_character_1x()

	_status_label = add_label(
		"TRANSITION: SETTLED  |  ART: checking layers...",
		Vector2(18.0, 281.0),
		Vector2(604.0, 11.0),
		8,
		MUTED_COLOR
	)
	add_label(
		"SPACE: SWAP A/B POLARITIES THROUGH THE DIM-THEN-RELIGHT TRANSITION.",
		Vector2(18.0, 296.0),
		Vector2(604.0, 10.0),
		7,
		MUTED_COLOR
	)
	add_label(
		"1x EXAMPLES FORCE THE NEAR HINT ON; THE COMPONENT ITSELF DOES NOT DETECT PROXIMITY.",
		Vector2(18.0, 309.0),
		Vector2(604.0, 10.0),
		7,
		MUTED_COLOR
	)
	add_label(
		"CHARACTER idle #0 IS THE PROJECT'S ORIGINAL PNG, CROPPED TO VISIBLE PIXELS AT 1x FOR SCALE ONLY.",
		Vector2(18.0, 322.0),
		Vector2(604.0, 10.0),
		7,
		MUTED_COLOR
	)
	add_label(
		"VISUAL PREVIEW ONLY - NO PHYSICS, FORCE, COLLISION, PROXIMITY, MAP, OR SHARED F2 STONE CHANGES.",
		Vector2(18.0, 339.0),
		Vector2(604.0, 11.0),
		8,
		TEXT_COLOR
	)


func _spawn_stone(index: int, at: Vector2, scale_value: float, hint: bool) -> void:
	var stone: RuneStoneVisual = RUNE_SCENE.instantiate() as RuneStoneVisual
	stone.name = "RuneStone_%s_%s" % ["A" if index == 0 else "B", "1x" if scale_value == 1.0 else "4x"]
	stone.position = at
	stone.scale = Vector2.ONE * scale_value
	add_child(stone)
	stone.set_polarity(_column_positive[index], true)
	stone.show_polarity_hint = hint
	if scale_value == 1.0:
		_stones_1x.append(stone)
	else:
		_stones_4x.append(stone)
		stone.transition_finished.connect(_on_column_transition_finished.bind(index))


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


func _update_column_label(column: int, positive: bool) -> void:
	if column < 0 or column >= _title_labels.size():
		return
	_title_labels[column].text = STATE_TITLES[0] if positive else STATE_TITLES[1]
	var color: Color = STATE_COLORS[0] if positive else STATE_COLORS[1]
	_title_labels[column].add_theme_color_override("font_color", color)
	if column < _state_labels.size():
		_state_labels[column].text = "COLUMN %s  /  SAME STONE" % ("A" if column == 0 else "B")
	if column < _hint_labels.size():
		_hint_labels[column].add_theme_color_override("font_color", color)
	queue_redraw()


func _update_art_status() -> void:
	var loaded: int = 0
	var missing: Array[String] = []
	for stone: RuneStoneVisual in _stones_1x + _stones_4x:
		if stone.has_art():
			loaded += 1
		else:
			var file_name: String = stone.get_missing_texture_path().get_file()
			if not missing.has(file_name):
				missing.append(file_name)

	var text: String
	if loaded == 4 and missing.is_empty():
		text = (
			"TRANSITION: SETTLED  |  ART: 3/3 STATES 32x32  |  DIRECT 96->32 NEAREST / SLEEP+GOLD+CYAN"
		)
	else:
		text = (
			"TRANSITION: SETTLED  |  ART: %d/4 VIEWS LOADED; MISSING %s"
			% [loaded, ", ".join(missing)]
		)
	_status_label.text = text
	_status_label.add_theme_color_override(
		"font_color",
		MUTED_COLOR if loaded == 4 and missing.is_empty() else WARN_COLOR
	)
	print(
		"PREVIEW_RUNE_STONE loaded_views=%d missing=%s same_geometry=%s"
		% [loaded, ",".join(missing), "true" if loaded == 4 else "unknown"]
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
	var canvas: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(canvas, BG_COLOR)

	for x: int in range(0, int(size.x) + 1, 32):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), size.y), GRID_COLOR, 1.0)
	for y: int in range(0, int(size.y) + 1, 32):
		draw_line(Vector2(0.0, float(y)), Vector2(size.x, float(y)), GRID_COLOR, 1.0)

	draw_rect(Rect2(0.0, 0.0, size.x, 46.0), HEADER_COLOR)
	draw_line(Vector2(0.0, 46.0), Vector2(size.x, 46.0), PANEL_BORDER, 1.0)
	draw_rect(Rect2(0.0, 276.0, size.x, size.y - 276.0), PANEL_COLOR)
	draw_line(Vector2(0.0, 276.0), Vector2(size.x, 276.0), PANEL_BORDER, 1.0)

	for index: int in range(2):
		var x: float = COLUMN_X[index]
		draw_rect(Rect2(x - 140.0, 50.0, 280.0, 216.0), PANEL_COLOR)
		draw_rect(Rect2(x - 140.0, 50.0, 280.0, 216.0), PANEL_BORDER, false, 1.0)
		draw_rect(
			Rect2(x - 28.0, 82.0, 56.0, 1.0),
			STATE_COLORS[0] if _column_positive[index] else STATE_COLORS[1]
		)

	# A shared baseline makes the actual-size comparison honest. The stones are
	# visual objects, not grounded gameplay props; the line is only for review.
	draw_line(
		Vector2(30.0, BASELINE_Y),
		Vector2(610.0, BASELINE_Y),
		BASELINE_COLOR,
		1.0
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
