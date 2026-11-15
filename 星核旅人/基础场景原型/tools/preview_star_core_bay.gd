class_name StarCoreBayPreview
extends Control

## Standalone 640x360 look-dev preview for the 32x32 star-core bay.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_star_core_bay.tscn
## Optional engine capture:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_star_core_bay.tscn -- --capture-preview
##
## This is a visual preview, not gameplay. It does not create physics, collision,
## suction, interaction, storage/retrieval logic, or a formal room layout.
## The player idle frame is cropped from the real project idle sheet only to show
## true scale beside the 1x bay.

const BAY_SCENE: PackedScene = preload("res://scenes/star_core_bay_visual.tscn")
const PLAYER_IDLE: Texture2D = preload("res://assets/characters/male_hero-idle.png")
const CAPTURE_PATH: String = "res://screenshots/star_core_bay_preview.png"
const CAPTURE_SIZE: Vector2i = Vector2i(640, 360)

const BG_COLOR: Color = Color("#071016")
const HEADER_COLOR: Color = Color("#0b171d")
const PANEL_COLOR: Color = Color("#0a141a")
const PANEL_INNER: Color = Color("#0d1a20")
const GRID_COLOR: Color = Color(0.12, 0.22, 0.25, 0.40)
const BORDER_COLOR: Color = Color(0.24, 0.40, 0.42, 0.75)
const TEXT_COLOR: Color = Color("#dce8e4")
const MUTED_COLOR: Color = Color("#7f999a")
const WARN_COLOR: Color = Color("#e8b96a")
const CYAN_COLOR: Color = Color("#8fdfe6")
const GOLD_COLOR: Color = Color("#e2bd6a")
const PURPLE_COLOR: Color = Color("#c8a7f2")

const PLAYER_REGION: Rect2 = Rect2(41.0, 43.0, 32.0, 37.0)
const PLAYER_POSITION: Vector2 = Vector2(164.0, 113.0)

## Observable GUI screenshot check. The occupied 4x bay image starts at (398,102);
## the pedestal body/foot is image x=3..28, y=27..31, i.e. screen x=410..513,
## y=210..229. If Base is hidden behind the preview background this region is
## dark (plus the tiny gold lock), so it has no white pedestal pixels.
const BASE_CHECK_RECT: Rect2i = Rect2i(410, 210, 104, 20)
const BACKGROUND_CHECK_RECT: Rect2i = Rect2i(8, 54, 6, 6)
const BASE_WHITE_MIN: int = 500

var _bays: Array[StarCoreBayVisual] = []
var _status_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)

	_build()
	await get_tree().process_frame
	_update_art_status()

	if _capture_requested():
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var exit_code: int = _save_capture()
		get_tree().quit(exit_code)


func _draw() -> void:
	var canvas: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(canvas, BG_COLOR)

	for x: int in range(0, int(size.x) + 1, 32):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), size.y), GRID_COLOR, 1.0)
	for y: int in range(0, int(size.y) + 1, 32):
		draw_line(Vector2(0.0, float(y)), Vector2(size.x, float(y)), GRID_COLOR, 1.0)

	draw_rect(Rect2(0.0, 0.0, size.x, 50.0), HEADER_COLOR)
	draw_line(Vector2(0.0, 50.0), Vector2(size.x, 50.0), BORDER_COLOR, 1.0)
	draw_rect(Rect2(0.0, 270.0, size.x, size.y - 270.0), PANEL_COLOR)
	draw_line(Vector2(0.0, 270.0), Vector2(size.x, 270.0), BORDER_COLOR, 1.0)

	draw_line(Vector2(236.0, 56.0), Vector2(236.0, 264.0), BORDER_COLOR, 1.0)

	# True-size ground line.
	draw_line(Vector2(20.0, 150.0), Vector2(220.0, 150.0), BORDER_COLOR, 1.0)

	# 4x panel frames.
	draw_rect(Rect2(248.0, 98.0, 136.0, 136.0), PANEL_INNER)
	draw_rect(Rect2(394.0, 98.0, 136.0, 136.0), PANEL_INNER)
	draw_rect(Rect2(248.0, 98.0, 136.0, 136.0), BORDER_COLOR, false, 1.0)
	draw_rect(Rect2(394.0, 98.0, 136.0, 136.0), BORDER_COLOR, false, 1.0)
	draw_rect(Rect2(540.0, 98.0, 88.0, 136.0), PANEL_INNER)
	draw_rect(Rect2(540.0, 98.0, 88.0, 136.0), BORDER_COLOR, false, 1.0)


func _build() -> void:
	add_label("STAR CORE BAY VISUAL PREVIEW", Vector2(20.0, 9.0), Vector2(600.0, 18.0), 14, TEXT_COLOR)
	add_label(
		"VISUAL PREVIEW ONLY  /  NOT GAMEPLAY  /  32x32 SIDE-VIEW PIXEL LAYERS",
		Vector2(20.0, 31.0),
		Vector2(600.0, 12.0),
		8,
		MUTED_COLOR
	)

	add_label("ACTUAL SIZE (1x)", Vector2(20.0, 58.0), Vector2(210.0, 12.0), 9, TEXT_COLOR)
	add_label("TRUE PIXEL SIZE / NO SCALING", Vector2(20.0, 72.0), Vector2(210.0, 10.0), 7, MUTED_COLOR)

	# 1x empty and occupied bays, sharing a ground line with the player.
	_spawn_bay("Empty_1x", Vector2(48.0, 134.0), 1.0, false)
	_spawn_bay("Occupied_1x", Vector2(112.0, 134.0), 1.0, true)
	add_label("EMPTY 1x", Vector2(8.0, 158.0), Vector2(80.0, 10.0), 7, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	add_label("OCCUPIED 1x", Vector2(72.0, 158.0), Vector2(80.0, 10.0), 7, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)

	_add_player_reference()

	add_label("REAL-SCALE CHECK", Vector2(20.0, 190.0), Vector2(200.0, 10.0), 7, CYAN_COLOR)
	var check_text: Label = add_label(
		"Occupied bay: 32 px tall.\nPlayer idle: 32x37 px (real pixels).\nThe bay is nearly the character's\nheight at 1:1. This is a size\nreference only; no room is built.",
		Vector2(20.0, 204.0),
		Vector2(200.0, 58.0),
		7,
		MUTED_COLOR
	)
	check_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	add_label("NEAR VIEW (4x, INTEGER SCALE)", Vector2(252.0, 58.0), Vector2(360.0, 12.0), 9, TEXT_COLOR)
	add_label("32px SOURCE / NEAREST / NO MIRROR", Vector2(252.0, 72.0), Vector2(360.0, 10.0), 7, MUTED_COLOR)
	add_label("EMPTY", Vector2(248.0, 80.0), Vector2(136.0, 12.0), 8, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	add_label("OCCUPIED", Vector2(394.0, 80.0), Vector2(136.0, 12.0), 8, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)

	_spawn_bay("Empty_4x", Vector2(316.0, 166.0), 4.0, false)
	_spawn_bay("Occupied_4x", Vector2(462.0, 166.0), 4.0, true)
	add_label("32x32 EMPTY / 4x", Vector2(248.0, 238.0), Vector2(136.0, 10.0), 7, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	add_label("32x32 OCCUPIED / 4x", Vector2(394.0, 238.0), Vector2(136.0, 10.0), 7, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)

	add_label("LAYER ORDER", Vector2(544.0, 102.0), Vector2(80.0, 10.0), 7, TEXT_COLOR)
	add_label("GLASS / FRONT", Vector2(544.0, 122.0), Vector2(80.0, 10.0), 7, CYAN_COLOR)
	add_label("CORE 16px", Vector2(544.0, 140.0), Vector2(80.0, 10.0), 7, PURPLE_COLOR)
	add_label("BASE / REAR", Vector2(544.0, 158.0), Vector2(80.0, 10.0), 7, TEXT_COLOR)
	add_label("SAME 32x32\nORIGIN", Vector2(544.0, 180.0), Vector2(80.0, 22.0), 7, MUTED_COLOR)
	add_label("LOCK MARK\nCODE-DRAWN", Vector2(544.0, 210.0), Vector2(80.0, 20.0), 7, GOLD_COLOR)

	_status_label = add_label(
		"ART STATUS: checking layers...",
		Vector2(252.0, 252.0),
		Vector2(376.0, 16.0),
		7,
		MUTED_COLOR
	)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	add_label(
		"VISUAL PREVIEW ONLY - NOT GAMEPLAY. NO PHYSICS, COLLISION, SUCTION, INTERACTION, OR BAY LOGIC.",
		Vector2(20.0, 278.0),
		Vector2(600.0, 10.0),
		7,
		TEXT_COLOR
	)
	add_label(
		"LAYERS: BASE (REAR) + EXISTING 16px PURPLE CORE + GLASS (FRONT), ALL 32x32 BAY LAYERS AT ONE ORIGIN.",
		Vector2(20.0, 292.0),
		Vector2(600.0, 10.0),
		7,
		MUTED_COLOR
	)
	add_label(
		"CORE RECT x8..23 / y8..23; PEDESTAL STARTS AT y24: NO OVERLAP. GLASS IS FULLY TRANSPARENT OVER THE CORE RECT.",
		Vector2(20.0, 306.0),
		Vector2(600.0, 10.0),
		7,
		MUTED_COLOR
	)
	add_label(
		"DOME: SEMICIRCULAR CAP + SHORT WALLS. A STRICT SEMICIRCLE WOULD NOT FIT A 16px CORE IN 32x32.",
		Vector2(20.0, 320.0),
		Vector2(600.0, 10.0),
		7,
		MUTED_COLOR
	)
	add_label(
		"FIRST-PASS LOOK DEV, PENDING USER VISUAL FEEDBACK. NOT FINAL ART.",
		Vector2(20.0, 338.0),
		Vector2(600.0, 10.0),
		7,
		WARN_COLOR
	)


func _spawn_bay(node_name: String, at: Vector2, zoom: float, is_occupied: bool) -> void:
	var bay: StarCoreBayVisual = BAY_SCENE.instantiate() as StarCoreBayVisual
	bay.name = node_name
	bay.position = at
	bay.scale = Vector2.ONE * zoom
	bay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bay.occupied = is_occupied
	add_child(bay)
	_bays.append(bay)


func _add_player_reference() -> void:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = PLAYER_IDLE
	atlas.region = PLAYER_REGION
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "PlayerIdleReference"
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = PLAYER_POSITION
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	add_label("PLAYER IDLE 1:1", Vector2(140.0, 158.0), Vector2(80.0, 10.0), 7, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	add_label("32x37 PX", Vector2(140.0, 168.0), Vector2(80.0, 10.0), 7, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)


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
	var loaded: int = 0
	var missing: Array[String] = []
	for bay: StarCoreBayVisual in _bays:
		if bay.has_art():
			loaded += 1
		else:
			for path: String in bay.get_missing_texture_paths():
				if not missing.has(path):
					missing.append(path)

	if missing.is_empty():
		_status_label.text = (
			"ART STATUS: base 32x32 + glass 32x32 + core 16x16 loaded. "
			+ "Occupied is a display toggle only; no bay logic."
		)
		_status_label.add_theme_color_override("font_color", MUTED_COLOR)
	else:
		_status_label.text = (
			"ART STATUS: %d/4 bay instances loaded. Missing: %s. "
			% [loaded, ", ".join(missing)]
			+ "No substitute PNG is generated."
		)
		_status_label.add_theme_color_override("font_color", WARN_COLOR)
	print(
		"PREVIEW_BAY_ART loaded_instances=%d missing=%s"
		% [loaded, ",".join(missing)]
	)


static func check_rendered_base(image: Image) -> Dictionary:
	## Samples the real captured GUI image, not just node z indices. The pedestal
	## body/foot must contain a substantial number of white/light pixels and its
	## mean luminance must be clearly above a plain background patch.
	if image == null:
		return {"ok": false, "reason": "image is null"}
	if image.get_size() != CAPTURE_SIZE:
		return {
			"ok": false,
			"reason": "image size %s, expected %s" % [str(image.get_size()), str(CAPTURE_SIZE)],
		}

	var white_pixels: int = 0
	var base_sum: float = 0.0
	var base_count: int = 0
	for y: int in range(BASE_CHECK_RECT.position.y, BASE_CHECK_RECT.end.y):
		for x: int in range(BASE_CHECK_RECT.position.x, BASE_CHECK_RECT.end.x):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.5:
				continue
			base_count += 1
			base_sum += 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
			if color.r > 0.70 and color.g > 0.70 and color.b > 0.70:
				white_pixels += 1

	var background_sum: float = 0.0
	var background_count: int = 0
	for y: int in range(BACKGROUND_CHECK_RECT.position.y, BACKGROUND_CHECK_RECT.end.y):
		for x: int in range(BACKGROUND_CHECK_RECT.position.x, BACKGROUND_CHECK_RECT.end.x):
			var color: Color = image.get_pixel(x, y)
			background_sum += 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
			background_count += 1

	var base_mean: float = base_sum / float(maxi(base_count, 1))
	var background_mean: float = background_sum / float(maxi(background_count, 1))
	var ok: bool = (
		white_pixels >= BASE_WHITE_MIN
		and base_mean >= 0.35
		and background_mean <= 0.20
		and base_mean - background_mean >= 0.15
	)
	return {
		"ok": ok,
		"white_pixels": white_pixels,
		"white_min": BASE_WHITE_MIN,
		"base_pixels": base_count,
		"base_mean": base_mean,
		"background_mean": background_mean,
		"base_rect": BASE_CHECK_RECT,
		"background_rect": BACKGROUND_CHECK_RECT,
	}


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

	var pixel_check: Dictionary = check_rendered_base(image)
	print(
		"PREVIEW_PIXEL_CHECK white=%d/%d base_pixels=%d base_mean=%.3f background_mean=%.3f ok=%s"
		% [
			int(pixel_check.get("white_pixels", 0)),
			int(pixel_check.get("white_min", BASE_WHITE_MIN)),
			int(pixel_check.get("base_pixels", 0)),
			float(pixel_check.get("base_mean", 0.0)),
			float(pixel_check.get("background_mean", 0.0)),
			str(pixel_check.get("ok", false)),
		]
	)
	if not bool(pixel_check.get("ok", false)):
		printerr(
			"PREVIEW_PIXEL_CHECK_FAILED pedestal region is not visibly white; "
			+ "Base may be hidden behind the preview background. reason=%s"
			% str(pixel_check.get("reason", "white/base mean thresholds failed"))
		)
		return 1
	return 0
