@tool
class_name TutorialStele
extends Node2D

## Standalone tutorial stele: the approved 26x52 concept stone, proximity glow,
## and a small paged lesson. The component owns no collision, force, inventory or
## world state. Drop scenes/tutorial_stele.tscn into a 2D scene and set `pages`.
##
## Fidelity:
## - The shell is displayed 1:1 with nearest filtering. `grey` is the exact
##   concept stone('grey', band_y=26); the animation sheet is generated from the
##   same concept `stone()` function. Every frame keeps the shell unchanged and
##   changes pixels only inside groove_floor.
## - No tint is applied to the shell. The glow is baked into the 26x52 frames.
## - The node never rotates, scales, bobs or recolours the stone while idling or
##   animating. The prompt is a separate world-space Control above the stone.
##
## Interaction:
## - The nearest registered stele within `near_range` (default 56 px) is the only
##   stele that shows a prompt or reacts to F. A 10 px leave margin plus an 8 px
##   switch margin keeps a single frame at the boundary from flickering between
##   two steles.
## - Entering the range opens page 1 automatically. F advances once per real key
##   press (key-repeat echo is ignored), closes on the last page, and opens page
##   1 again while still in range. Leaving closes, resets to page 1 and restores
##   the grey stone.
## - Tree pause (Esc) freezes both the glow frame and page input. The component
##   is under the pausable world in the main scene.
##
## The font is loaded lazily and locally. It is never a preloaded path and never
## falls back to a Windows system font. If the font import is missing the prompt
## still appears with the fallback font and logs a warning; the real Chinese
## coverage is checked by tests/test_tutorial_stele.gd.

const GROUP_NAME: StringName = &"tutorial_stele"
const STONE_SIZE: Vector2i = Vector2i(26, 52)
const STONE_ORIGIN: Vector2 = Vector2(-13.0, -52.0)
const GREY_TEXTURE_PATH: String = "res://assets/tutorial_stele/tutorial_stele_grey.png"
const FRAME_SHEET_PATH: String = "res://assets/tutorial_stele/tutorial_stele_frames.png"
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const FRAME_WIDTH: int = 26
const FRAME_HEIGHT: int = 52
const DEFAULT_FRAME_COUNT: int = 64
const START_FRAME: int = 8
const PROMPT_WIDTH: float = 244.0
const PROMPT_PADDING: float = 10.0
const PROMPT_BODY_GAP: float = 4.0
const PROMPT_FOOTER_HEIGHT: float = 14.0
const PROMPT_GAP_ABOVE_STONE: float = 12.0
const PROMPT_NOTCH_HEIGHT: float = 8.0
const PROMPT_HUD_SAFE_TOP: float = 50.0
const PROMPT_SCREEN_MARGIN: float = 4.0
const FOCUS_SWITCH_MARGIN: float = 8.0
const DEFAULT_LEAVE_MARGIN: float = 10.0
const BODY_FONT_SIZE: int = 12

const TEXT_COLOR: Color = Color("#e7eceb")
const MUTED_COLOR: Color = Color("#a4b3be")
const GOLD_COLOR: Color = Color("#f4cd63")
const PANEL_BG: Color = Color(0.078, 0.122, 0.169, 0.95)
const PANEL_BORDER: Color = Color("#607380")

@export var pages: PackedStringArray = PackedStringArray([
	"护符能改变你的极性。\n按 Q 切换金色与青色。",
	"同号相斥，异号相吸。\n试着借固定符石的力量移动。",
	"靠近星核仓按 E 释放或放入。\n按 R 可重置当前房间。",
]):
	set(value):
		pages = value
		if is_inside_tree():
			if _page_index >= pages.size():
				_page_index = -1
			_refresh_prompt()

## Formal L2 uses false: entering range only shows an "F 阅读" prompt. The
## default true preserves every older stele that opens page 1 on approach.
@export var auto_open_on_focus: bool = true

## Distance from the player's feet to the stele's feet that opens the prompt.
@export_range(16.0, 160.0, 1.0, "suffix:px") var near_range: float = 56.0:
	set(value):
		near_range = maxf(value, 1.0)

## Extra distance kept while the player is already reading, so the near/leave
## boundary cannot flicker on a single frame.
@export_range(0.0, 64.0, 1.0, "suffix:px") var leave_margin: float = DEFAULT_LEAVE_MARGIN:
	set(value):
		leave_margin = maxf(value, 0.0)

## Optional explicit player path. If empty, the component finds the first
## PrototypePlayer in the tree, so the scene remains drag-and-drop.
@export var player_path: NodePath = NodePath()

@export_range(1.0, 24.0, 0.1, "suffix:fps") var glow_fps: float = 8.0

@export_range(160.0, 480.0, 1.0, "suffix:px") var prompt_width: float = PROMPT_WIDTH

@export_range(0.0, 120.0, 1.0, "suffix:px") var prompt_hud_safe_top: float = PROMPT_HUD_SAFE_TOP

static var _focus_owner_ref: WeakRef = null
static var _shared_font: FontFile = null
static var _shared_font_checked: bool = false

var _stone: Sprite2D = null
var _grey_texture: Texture2D = null
var _sheet_texture: Texture2D = null
var _sheet_frame_count: int = DEFAULT_FRAME_COUNT
var _player: PrototypePlayer = null
var _focused: bool = false
var _suspended: bool = false
var _page_index: int = -1
var _animation_frame: int = START_FRAME
var _animation_accumulator: float = 0.0
var _prompt_root: Control = null
var _prompt_layer: CanvasLayer = null
var _prompt_body: Label = null
var _prompt_page: Label = null
var _prompt_footer: Label = null
var _prompt_style: StyleBoxFlat = null
var _screen_anchor_x: float = 0.0
var _font_missing_warned: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP_NAME)


func _exit_tree() -> void:
	remove_from_group(GROUP_NAME)
	if _focus_owner_ref != null and _focus_owner_ref.get_ref() == self:
		_focus_owner_ref = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_stone()
	_load_textures()
	_apply_grey_stone()

	if Engine.is_editor_hint():
		set_process(false)
		set_process_unhandled_input(false)
		return

	_ensure_prompt()
	_resolve_player()
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null:
		_resolve_player()
	_resolve_focus()
	if _suspended or not _focused:
		return
	if _prompt_root != null and _prompt_root.visible:
		# The world-anchored prompt follows the stele root if the creator moves
		# it, while still clamping itself to the 640x360 screen.
		_layout_prompt()
	_advance_glow(delta)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _suspended or not _focused:
		return
	if get_tree() == null or get_tree().paused:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	# `echo` is the OS key-repeat stream. A held F must not page continuously.
	if key_event.echo or not key_event.pressed:
		return
	if not key_event.is_action_pressed(&"tutorial_next"):
		return
	if advance_page():
		get_viewport().set_input_as_handled()


## Public page control. `true` means the event was consumed by this stele.
func advance_page() -> bool:
	if pages.is_empty():
		return false
	if _page_index < 0:
		_page_index = 0
	elif _page_index + 1 >= pages.size():
		_page_index = -1
	else:
		_page_index += 1
	_refresh_prompt()
	return true


func open_first_page() -> void:
	if pages.is_empty():
		_page_index = -1
	else:
		_page_index = 0
	_refresh_prompt()


func close_reading() -> void:
	_page_index = -1
	_refresh_prompt()


## Called by the main scene when F2/F4 changes rooms or F7 leaves the room.
## Suspension closes the prompt, stops the glow and makes this stele ineligible
## for nearest-stele focus. Another stele can take over immediately.
func set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	if _suspended:
		_release_focus()
	# On unsuspend the next process tick re-evaluates proximity and opens page 1
	# if the player is already within range.


func is_suspended() -> bool:
	return _suspended


## Main calls this on R / fall / room reset. The page is cleared back to the
## first page when the stele is still the active one.
func on_player_reset(_reason: String = "") -> void:
	if _suspended:
		return
	if _focused:
		if auto_open_on_focus and not pages.is_empty():
			_page_index = 0
		else:
			_page_index = -1
		_refresh_prompt()


## Main calls this when the OS window loses focus. No page is left half-read.
func on_focus_lost() -> void:
	if _suspended:
		return
	if _focused:
		if auto_open_on_focus and not pages.is_empty():
			_page_index = 0
		else:
			_page_index = -1
		_refresh_prompt()


func get_page_index() -> int:
	return _page_index


func get_page_count() -> int:
	return pages.size()


func get_current_page_text() -> String:
	if _page_index < 0 or _page_index >= pages.size():
		return ""
	return pages[_page_index]


func is_prompt_visible() -> bool:
	return _prompt_root != null and _prompt_root.visible


func is_focused() -> bool:
	return _focused


func is_glow_active() -> bool:
	return _focused and not _suspended and _stone != null and _stone.texture == _sheet_texture


func get_animation_frame() -> int:
	return _animation_frame


func get_animation_frame_count() -> int:
	return _sheet_frame_count


func get_footer_text() -> String:
	return _prompt_footer.text if _prompt_footer != null else ""


func get_prompt_font() -> Font:
	return _prompt_body.get_theme_font("font") if _prompt_body != null else null


func get_tutorial_font_path() -> String:
	return FONT_PATH


func has_tutorial_font() -> bool:
	return _get_tutorial_font() != null


func is_grey_visual() -> bool:
	return _stone != null and _grey_texture != null and _stone.texture == _grey_texture


func get_stone_texture() -> Texture2D:
	return _stone.texture if _stone != null else null


func get_prompt_rect() -> Rect2:
	if _prompt_root == null or not _prompt_root.visible:
		return Rect2()
	return Rect2(_prompt_root.global_position, _prompt_root.size)


func get_leave_range() -> float:
	return near_range + leave_margin


func get_player() -> PrototypePlayer:
	return _player


func _ensure_stone() -> void:
	_stone = get_node_or_null("Stone") as Sprite2D
	if _stone == null:
		_stone = Sprite2D.new()
		_stone.name = "Stone"
		add_child(_stone)
	_stone.centered = false
	_stone.position = STONE_ORIGIN
	_stone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stone.z_index = 0


func _load_textures() -> void:
	_grey_texture = _load_texture(GREY_TEXTURE_PATH)
	_sheet_texture = _load_texture(FRAME_SHEET_PATH)
	if _sheet_texture == null:
		_sheet_frame_count = 0
		return
	var size: Vector2 = _sheet_texture.get_size()
	if int(size.y) != FRAME_HEIGHT or int(size.x) % FRAME_WIDTH != 0:
		push_warning(
			"TutorialStele: frame sheet is %s, expected width multiple of %d and height %d"
			% [str(size), FRAME_WIDTH, FRAME_HEIGHT]
		)
		_sheet_frame_count = 0
		return
	_sheet_frame_count = int(size.x) / FRAME_WIDTH


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path, "Texture2D"):
		push_warning("TutorialStele: missing texture %s" % path)
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	return resource as Texture2D


func _resolve_player() -> void:
	if player_path != NodePath():
		var node: Node = get_node_or_null(player_path)
		if node is PrototypePlayer:
			_player = node as PrototypePlayer
			return

	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		if node is PrototypePlayer:
			_player = node as PrototypePlayer
			return
	var found: Array[Node] = get_tree().root.find_children("*", "PrototypePlayer", true, false)
	if not found.is_empty():
		_player = found[0] as PrototypePlayer
		return
	# Fallback for a project that has not registered the class cache yet.
	var bodies: Array[Node] = get_tree().root.find_children("*", "CharacterBody2D", true, false)
	for node: Node in bodies:
		if node is PrototypePlayer:
			_player = node as PrototypePlayer
			return


func _resolve_focus() -> void:
	if get_tree() == null:
		return
	var owner: TutorialStele = _owner_from_ref()
	if owner != null and not owner._is_available():
		owner = null
	var owner_distance: float = INF
	if owner != null:
		owner_distance = owner.global_position.distance_to(owner._player.global_position)

	var nearest: TutorialStele = null
	var nearest_distance: float = INF
	var nodes: Array[Node] = get_tree().get_nodes_in_group(GROUP_NAME)
	for node: Node in nodes:
		var stele: TutorialStele = node as TutorialStele
		if stele == null or not stele._is_available():
			continue
		var distance: float = stele.global_position.distance_to(stele._player.global_position)
		var within: bool = distance <= stele.near_range
		if stele == owner:
			within = distance <= stele.get_leave_range()
		if within and distance < nearest_distance:
			nearest = stele
			nearest_distance = distance

	var chosen: TutorialStele = null
	if owner != null and owner_distance <= owner.get_leave_range():
		if nearest == null or nearest == owner:
			chosen = owner
		elif owner_distance <= nearest_distance + FOCUS_SWITCH_MARGIN:
			chosen = owner
		else:
			chosen = nearest
	elif nearest != null:
		chosen = nearest

	if chosen == null:
		_focus_owner_ref = null
	else:
		_focus_owner_ref = weakref(chosen)

	for node: Node in nodes:
		var stele: TutorialStele = node as TutorialStele
		if stele != null:
			stele._set_focused(stele == chosen)


func _is_available() -> bool:
	return (
		not _suspended
		and is_inside_tree()
		and is_visible_in_tree()
		and _player != null
	)


func _owner_from_ref() -> TutorialStele:
	if _focus_owner_ref == null:
		return null
	var ref: Object = _focus_owner_ref.get_ref()
	if ref == null or not is_instance_valid(ref):
		_focus_owner_ref = null
		return null
	return ref as TutorialStele


func _set_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	if _focused:
		if auto_open_on_focus and _page_index < 0 and not pages.is_empty():
			_page_index = 0
		_start_glow()
	else:
		_page_index = -1
		_stop_glow()
		if _focus_owner_ref != null and _focus_owner_ref.get_ref() == self:
			_focus_owner_ref = null
	_refresh_prompt()


func _release_focus() -> void:
	_focused = false
	_page_index = -1
	_stop_glow()
	_refresh_prompt()
	if _focus_owner_ref != null and _focus_owner_ref.get_ref() == self:
		_focus_owner_ref = null


func _start_glow() -> void:
	if _sheet_texture == null or _sheet_frame_count <= 0:
		_apply_grey_stone()
		return
	_animation_frame = clampi(START_FRAME, 0, _sheet_frame_count - 1)
	_animation_accumulator = 0.0
	_apply_glow_frame()


func _stop_glow() -> void:
	_apply_grey_stone()


func _apply_grey_stone() -> void:
	if _stone == null:
		return
	if _grey_texture == null:
		_stone.texture = null
		return
	_stone.texture = _grey_texture
	_stone.hframes = 1
	_stone.vframes = 1
	_stone.frame = 0


func _apply_glow_frame() -> void:
	if _stone == null or _sheet_texture == null or _sheet_frame_count <= 0:
		return
	if _stone.texture != _sheet_texture:
		_stone.texture = _sheet_texture
		_stone.hframes = _sheet_frame_count
		_stone.vframes = 1
	_stone.frame = _animation_frame


func _advance_glow(delta: float) -> void:
	if _sheet_texture == null or _sheet_frame_count <= 0:
		return
	if _stone.texture != _sheet_texture:
		_apply_glow_frame()
	var fps: float = maxf(glow_fps, 1.0)
	_animation_accumulator += delta * fps
	if _animation_accumulator < 1.0:
		return
	var steps: int = int(_animation_accumulator)
	_animation_accumulator -= float(steps)
	_animation_frame = wrapi(_animation_frame + steps, 0, _sheet_frame_count)
	_apply_glow_frame()


func _ensure_prompt() -> void:
	if _prompt_root != null:
		return
	# The prompt is a screen-space HUD-like overlay. Keeping it in a CanvasLayer
	# (instead of directly under this world-space Node2D) means a scrolling
	# camera never drags it off-screen. Its horizontal anchor still follows the
	# stele through the camera transform in _layout_prompt().
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "PromptLayer"
	_prompt_layer.layer = 8
	add_child(_prompt_layer)

	_prompt_root = Control.new()
	_prompt_root.name = "Prompt"
	_prompt_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.z_index = 20
	_prompt_root.visible = false
	_prompt_root.draw.connect(_draw_prompt_frame)
	_prompt_layer.add_child(_prompt_root)

	_prompt_style = StyleBoxFlat.new()
	_prompt_style.bg_color = PANEL_BG
	_prompt_style.border_color = PANEL_BORDER
	_prompt_style.set_border_width_all(1)
	_prompt_style.set_corner_radius_all(4)
	_prompt_style.anti_aliasing = false

	var font: FontFile = _get_tutorial_font()
	if font == null:
		font = ThemeDB.fallback_font
		if not _font_missing_warned:
			push_warning(
				"TutorialStele: %s is not imported; Chinese pages will be missing glyphs"
				% FONT_PATH
			)
			_font_missing_warned = true

	_prompt_body = _make_label(font, TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_prompt_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_prompt_root.add_child(_prompt_body)

	_prompt_page = _make_label(font, MUTED_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_prompt_root.add_child(_prompt_page)

	_prompt_footer = _make_label(font, GOLD_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_prompt_root.add_child(_prompt_footer)


func _make_label(font: Font, color: Color, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 0)
	return label


static func _get_tutorial_font() -> FontFile:
	if _shared_font_checked:
		return _shared_font
	_shared_font_checked = true
	if not ResourceLoader.exists(FONT_PATH):
		push_warning("TutorialStele: font not found at %s" % FONT_PATH)
		return null
	var base_font: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if base_font == null:
		push_warning("TutorialStele: %s did not load as a FontFile" % FONT_PATH)
		return null
	var font: FontFile = base_font.duplicate() as FontFile
	if font == null:
		font = base_font
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.allow_system_fallback = false
	font.generate_mipmaps = false
	font.oversampling = 1.0
	_shared_font = font
	return font


func _refresh_prompt() -> void:
	if _prompt_root == null:
		return
	if _page_index < 0 or _page_index >= pages.size():
		if _focused and not auto_open_on_focus and not pages.is_empty():
			_prompt_body.text = "按 F 阅读操作提示"
			_prompt_page.text = ""
			_prompt_footer.text = "F 阅读"
			_layout_prompt()
			_prompt_root.visible = true
		else:
			_prompt_root.visible = false
		return

	var text: String = pages[_page_index]
	_prompt_body.text = text
	_prompt_page.text = "%d / %d" % [_page_index + 1, pages.size()]
	_prompt_footer.text = "F 收起" if _page_index + 1 >= pages.size() else "F 继续"
	_layout_prompt()
	_prompt_root.visible = true


func _layout_prompt() -> void:
	if _prompt_root == null:
		return
	var font: Font = _prompt_body.get_theme_font("font")
	var font_size: int = _prompt_body.get_theme_font_size("font_size")
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = minf(prompt_width, maxf(160.0, viewport_size.x - PROMPT_SCREEN_MARGIN * 2.0))
	var body_width: float = maxf(width - PROMPT_PADDING * 2.0, 80.0)
	var measured: Vector2 = font.get_multiline_string_size(
		_prompt_body.text, HORIZONTAL_ALIGNMENT_LEFT, body_width, font_size
	)
	var body_height: float = maxf(ceilf(measured.y), float(font_size))
	var panel_height: float = (
		PROMPT_PADDING * 2.0
		+ body_height
		+ PROMPT_BODY_GAP
		+ PROMPT_FOOTER_HEIGHT
	)

	# The stele is a world node; the prompt lives in a screen-space CanvasLayer.
	# Convert the world anchor through the current camera so scrolling levels
	# keep the panel attached to the stone without using global_position as if
	# it were a screen coordinate.
	var screen_anchor: Vector2 = get_viewport().get_canvas_transform() * global_position
	var target_x: float = screen_anchor.x - width * 0.5
	var target_y: float = (
		screen_anchor.y
		- float(STONE_SIZE.y)
		- PROMPT_GAP_ABOVE_STONE
		- panel_height
	)
	var max_x: float = maxf(PROMPT_SCREEN_MARGIN, viewport_size.x - width - PROMPT_SCREEN_MARGIN)
	var min_y: float = prompt_hud_safe_top
	var max_y: float = maxf(
		min_y,
		viewport_size.y - PROMPT_SCREEN_MARGIN - panel_height - PROMPT_NOTCH_HEIGHT
	)
	target_x = clampf(target_x, PROMPT_SCREEN_MARGIN, max_x)
	target_y = clampf(target_y, min_y, max_y)

	_prompt_root.size = Vector2(roundf(width), roundf(panel_height))
	_prompt_root.global_position = Vector2(roundf(target_x), roundf(target_y))
	_screen_anchor_x = screen_anchor.x

	_prompt_body.position = Vector2(PROMPT_PADDING, PROMPT_PADDING)
	_prompt_body.size = Vector2(body_width, body_height + 3.0)
	var footer_y: float = PROMPT_PADDING + body_height + PROMPT_BODY_GAP
	_prompt_page.position = Vector2(PROMPT_PADDING, footer_y)
	_prompt_page.size = Vector2(70.0, PROMPT_FOOTER_HEIGHT)
	_prompt_footer.position = Vector2(width - PROMPT_PADDING - 110.0, footer_y)
	_prompt_footer.size = Vector2(110.0, PROMPT_FOOTER_HEIGHT)
	_prompt_root.queue_redraw()


func _draw_prompt_frame() -> void:
	if _prompt_root == null or _prompt_style == null:
		return
	var panel_size: Vector2 = _prompt_root.size
	_prompt_root.draw_style_box(_prompt_style, Rect2(Vector2.ZERO, panel_size))

	var notch_center: float = _screen_anchor_x - _prompt_root.global_position.x
	notch_center = clampf(notch_center, 12.0, panel_size.x - 12.0)
	var bottom: float = panel_size.y - 1.0
	var border_points: PackedVector2Array = PackedVector2Array([
		Vector2(notch_center - 7.0, bottom),
		Vector2(notch_center + 7.0, bottom),
		Vector2(notch_center, bottom + PROMPT_NOTCH_HEIGHT),
	])
	var fill_points: PackedVector2Array = PackedVector2Array([
		Vector2(notch_center - 5.0, bottom),
		Vector2(notch_center + 5.0, bottom),
		Vector2(notch_center, bottom + PROMPT_NOTCH_HEIGHT - 2.0),
	])
	_prompt_root.draw_colored_polygon(border_points, PANEL_BORDER)
	_prompt_root.draw_colored_polygon(fill_points, PANEL_BG)
