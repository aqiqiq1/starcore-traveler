extends Control

## Actual-engine keyframe sheet for the side-to-centre star-core bay lid.
## Each cell is a live StarCoreBayVisual instance rendered at 4x by the same
## shader used in gameplay. The labels are drawn by the engine, not composited
## afterwards. Run:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/preview_star_core_lid.tscn
## Capture:
##   ... res://tools/preview_star_core_lid.tscn -- --capture-preview

const BAY_SCENE: PackedScene = preload("res://scenes/star_core_bay_visual.tscn")
const CAPTURE_PATH: String = "res://screenshots/star_core_lid_keyframes.png"
const CAPTURE_SIZE: Vector2i = Vector2i(640, 360)
const CELL_SIZE: int = 128

const CELLS: Array[Dictionary] = [
	{"title": "CLOSING 66%", "center": Vector2(96.0, 112.0), "progress": 0.66, "closed": false},
	{"title": "CLOSING 33%", "center": Vector2(320.0, 112.0), "progress": 0.33, "closed": false},
	{"title": "CLOSED 0%", "center": Vector2(544.0, 112.0), "progress": 0.0, "closed": true},
	{"title": "CLOSED 0%", "center": Vector2(96.0, 262.0), "progress": 0.0, "closed": true},
	{"title": "OPENING 33%", "center": Vector2(320.0, 262.0), "progress": 0.33, "closed": false},
	{"title": "OPENING 66%", "center": Vector2(544.0, 262.0), "progress": 0.66, "closed": false},
]

const BG: Color = Color("#071016")
const PANEL: Color = Color("#0c181e")
const GRID: Color = Color(0.12, 0.22, 0.25, 0.42)
const BORDER: Color = Color(0.26, 0.43, 0.45, 0.75)
const TEXT: Color = Color("#dce8e4")
const MUTED: Color = Color("#7f999a")
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#8fdfe6")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)
	_build()
	await get_tree().process_frame
	if _capture_requested():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().quit(_save_capture())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for x: int in range(0, int(size.x) + 1, 32):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), size.y), GRID, 1.0)
	for y: int in range(0, int(size.y) + 1, 32):
		draw_line(Vector2(0.0, float(y)), Vector2(size.x, float(y)), GRID, 1.0)
	for cell: Dictionary in CELLS:
		var center: Vector2 = cell["center"]
		draw_rect(
			Rect2(center - Vector2(64.0, 64.0), Vector2(128.0, 128.0)),
			PANEL
		)
		draw_rect(
			Rect2(center - Vector2(64.0, 64.0), Vector2(128.0, 128.0)),
			BORDER,
			false,
			1.0
		)


func _build() -> void:
	add_label("STAR CORE BAY LID KEYFRAMES", Vector2(12.0, 5.0), Vector2(500.0, 16.0), 13, TEXT)
	add_label(
		"ACTUAL ENGINE RENDER OF SIX LIVE INSTANCES  /  NOT GAMEPLAY  /  NO COMPOSITE",
		Vector2(12.0, 22.0),
		Vector2(620.0, 10.0),
		7,
		MUTED
	)
	add_label("CLOSING: LOWER SIDES UP, TOP CENTRE LAST", Vector2(12.0, 38.0),
		Vector2(620.0, 10.0), 8, GOLD)
	add_label("OPENING: TOP CENTRE FIRST, SIDES DESCEND", Vector2(12.0, 186.0),
		Vector2(620.0, 10.0), 8, CYAN)

	for cell: Dictionary in CELLS:
		var center: Vector2 = cell["center"]
		var bay: StarCoreBayVisual = BAY_SCENE.instantiate() as StarCoreBayVisual
		bay.position = center
		bay.scale = Vector2(4.0, 4.0)
		bay.occupied = true
		bay.show_lock_marker = false
		add_child(bay)
		bay.set_lid_progress_for_capture(float(cell["progress"]))
		add_label(
			String(cell["title"]),
			Vector2(center.x - 62.0, center.y + 66.0),
			Vector2(124.0, 10.0),
			7,
			TEXT if bool(cell["closed"]) else MUTED,
			HORIZONTAL_ALIGNMENT_CENTER
		)

	add_label(
		"TOP ROW = CLOSING (66% -> 33% -> CLOSED)   BOTTOM ROW = OPENING (CLOSED -> 33% -> 66%)",
		Vector2(12.0, 350.0),
		Vector2(620.0, 8.0),
		6,
		MUTED
	)


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


static func check_lid_keyframes(image: Image) -> Dictionary:
	if image == null:
		return {"ok": false, "reason": "null image"}
	if image.get_size() != CAPTURE_SIZE:
		return {"ok": false, "reason": "size %s" % str(image.get_size())}
	var results: Array[Dictionary] = []
	var ok: bool = true
	for cell: Dictionary in CELLS:
		var center: Vector2 = cell["center"]
		var left: int = 0
		var right: int = 0
		var top: int = 0
		var symmetric: bool = true
		var x0: int = int(center.x) - CELL_SIZE / 2
		var y0: int = int(center.y) - CELL_SIZE / 2
		var core_left: int = int(center.x) - 32
		var core_right: int = int(center.x) + 32
		var core_top: int = int(center.y) - 32
		var core_bottom: int = int(center.y) + 32
		# Exclude the 1 px frame and the 64x64 central core. The remaining pixels
		# are the glass rim/silhouette; white highlights are kept, the pedestal
		# and core highlights cannot bias the silhouette.
		# Only the glass dome rows (the pedestal starts at image y=24); this
		# keeps the white/gold base out of the glass-silhouette symmetry check.
		for y: int in range(y0 + 2, y0 + 94):
			var row_left: int = -1
			var row_right: int = -1
			for x: int in range(x0 + 2, x0 + CELL_SIZE - 2):
				if x >= core_left and x <= core_right and y >= core_top and y <= core_bottom:
					continue
				var color: Color = image.get_pixel(x, y)
				if not _is_glass_like(color):
					continue
				if x < int(center.x):
					left += 1
				else:
					right += 1
				if row_left < 0:
					row_left = x
				row_right = x
				if absf(float(x) - center.x) <= 24.0 and y < y0 + 24:
					top += 1
			if row_left >= 0 and row_right >= 0:
				var left_distance: float = center.x - float(row_left)
				var right_distance: float = float(row_right) - center.x
				if absf(left_distance - right_distance) > 6.0:
					symmetric = false
		var top_ok: bool = (top > 0) if bool(cell["closed"]) else (top == 0)
		if not symmetric or not top_ok:
			ok = false
		results.append({
			"title": String(cell["title"]),
			"left": left,
			"right": right,
			"top": top,
			"symmetric": symmetric,
			"top_ok": top_ok,
		})
	return {"ok": ok, "cells": results}


static func _is_glass_like(color: Color) -> bool:
	# Any sufficiently bright glass pixel, including the darker right wall and
	# white highlights. The dark teal panel is far below this luminance; the
	# pedestal rows and central core box are excluded separately.
	if color.a < 0.25:
		return false
	return maxf(maxf(color.r, color.g), color.b) > 0.28


func _capture_requested() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return args.has("--capture-preview")


func _save_capture() -> int:
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	var absolute_path: String = ProjectSettings.globalize_path(CAPTURE_PATH)
	var save_error: Error = image.save_png(absolute_path)
	if save_error != OK:
		printerr("LID_CAPTURE_FAILED %s error=%d" % [CAPTURE_PATH, save_error])
		return 1
	print("LID_CAPTURED %s size=%s" % [CAPTURE_PATH, str(image.get_size())])
	var result: Dictionary = check_lid_keyframes(image)
	for cell: Dictionary in result.get("cells", []):
		print("LID_CELL %s left=%d right=%d top=%d symmetric=%s top_ok=%s" % [
			cell["title"], cell["left"], cell["right"], cell["top"],
			str(cell["symmetric"]), str(cell["top_ok"])
		])
	print("LID_PIXEL_CHECK ok=%s" % str(result.get("ok", false)))
	_write_manifest(result)
	return 0 if bool(result.get("ok", false)) else 1


func _write_manifest(result: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(
		"res://screenshots/MANIFEST_LID.txt", FileAccess.WRITE
	)
	if file == null:
		return
	file.store_line("Star Core Traveler - star-core bay lid keyframes")
	file.store_line("Actual engine render of six live 32x32 bay instances at 4x; not a composite.")
	file.store_line("Top row: closing 66% -> 33% -> closed. Bottom row: closed -> opening 33% -> 66%.")
	file.store_line("Mask: lower sides reveal first; top centre is last to close / first to open.")
	file.store_line("Pixel check: symmetric=true is row-silhouette extents; raw left/right colour counts differ because the glass art has a left white reflection and darker right shading.")
	file.store_line("Top-centre glass band is absent at 33/66% and present only at closed 0%.")
	file.store_line("Pixel check result: %s" % str(result.get("ok", false)))
	for cell: Dictionary in result.get("cells", []):
		file.store_line("%s | left=%d right=%d top=%d symmetric=%s top_ok=%s" % [
			cell["title"], cell["left"], cell["right"], cell["top"],
			str(cell["symmetric"]), str(cell["top_ok"])
		])
	file.store_line("These keyframes are look-dev evidence, not human play and not final art.")
	file.close()
