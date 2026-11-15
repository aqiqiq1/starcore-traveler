class_name GuideEcho
extends Node2D

## Fixed manifestation of the ancient watcher's echo ("守望者残响").
##
## The component owns only presentation and a small paged conversation:
## - a grey carrier stele (pure Sprite2D, no TutorialStele script/group/input) at the
##   authored foot point, always visible from any distance;
## - the approved 6-frame echo sheet, projected from the upper part of the stele, which
##   fades in when the player is close and fades out when they leave (runtime alpha only);
## - a short in-range "F 交谈" prompt; approaching never opens the first page;
## - F opens/advances/closes, key-repeat echo is ignored;
## - leaving range closes the page, re-entering allows listening again;
## - no collision, no force field, no platform, no ray obstruction, no follow AI;
## - no pause or player lock; nothing gates level completion on reading.
##
## UI follows the existing dark pixel panel / Fusion Pixel 12 px language. The
## component lives under the pausable World, so tree pause freezes the idle frame
## and all input. The level also suspends it during menu/opening/completion/
## scene changes and clears the page on focus loss.

const GROUP_NAME: StringName = &"guide_echo"
const DISPLAY_NAME: String = "守望者残响"
## Formal shared echo sheet: approved preview s40 derivative (original sheet
## remains on disk for provenance).
const SHEET_PATH: String = "res://assets/guide_echo_20261113/guide_echo_idle_6f_s40.png"
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const FRAME_SIZE: Vector2i = Vector2i(48, 64)
const FRAME_COUNT: int = 6
const FOOT_ANCHOR: Vector2 = Vector2(24.0, 60.0)
const SPRITE_OFFSET: Vector2 = Vector2(-24.0, -60.0)
const IDLE_FPS: float = 4.0
## Carrier stele: reuse only the grey stele PNG as a plain Sprite2D. The TutorialStele
## component (script, group, collision, read-page input) is never instantiated here.
const CARRIER_TEXTURE_PATH: String = "res://assets/tutorial_stele/tutorial_stele_grey.png"
const CARRIER_SIZE: Vector2i = Vector2i(26, 52)
const CARRIER_OFFSET: Vector2 = Vector2(-13.0, -52.0)
## The echo is drawn from the upper part of the stele, not on the stele's base.
const PROJECTION_LIFT: float = 18.0
const BODY_FONT_SIZE: int = 12
const PROMPT_FONT_SIZE: int = 12
const META_FONT_SIZE: int = 12
const DIALOG_WIDTH: float = 300.0
const PROMPT_WIDTH: float = 82.0
const PROMPT_HEIGHT: float = 22.0
const PADDING: float = 10.0
const SPEAKER_HEIGHT: float = 16.0
const FOOTER_HEIGHT: float = 16.0
const BODY_GAP: float = 2.0
const FOOTER_GAP: float = 4.0
const PROMPT_GAP: float = 6.0
const DIALOG_GAP: float = 10.0
const SCREEN_MARGIN: float = 4.0
const DEFAULT_SAFE_TOP: float = 56.0

const TEXT_COLOR: Color = Color("#e7eceb")
const MUTED_COLOR: Color = Color("#a4b3be")
const GOLD_COLOR: Color = Color("#f4cd63")
const PANEL_BG: Color = Color(0.078, 0.122, 0.169, 0.95)
const PANEL_BORDER: Color = Color("#607380")

@export var pages: PackedStringArray = PackedStringArray([
	"旅人，归路已经断了。\n我曾守望悬庭，如今只余回声。\n前方还有一扇通往外侧的旧门。",
	"群岛靠埋在石中的星核维系。\n它们并未熄灭，只是回路断了。\n把力量送回石座，道路才会回应。",
	"胸前的护符，是旧日的通行凭证。\n它能改变你自身的相性。\n金色叫辉相，青色叫澜相。",
]):
	set(value):
		pages = value
		if is_inside_tree() and _page_index >= pages.size():
			_page_index = -1
		_refresh_ui()

## Distance from the player's feet to this echo's foot point that shows the
## short prompt. Approaching never opens the conversation by itself.
@export_range(16.0, 160.0, 1.0, "suffix:px") var near_range: float = 56.0:
	set(value):
		near_range = maxf(value, 1.0)

@export_range(0.0, 64.0, 1.0, "suffix:px") var leave_margin: float = 10.0:
	set(value):
		leave_margin = maxf(value, 0.0)

@export var player_path: NodePath = NodePath()

@export_range(240.0, 480.0, 1.0, "suffix:px") var prompt_width: float = DIALOG_WIDTH

@export_range(0.0, 120.0, 1.0, "suffix:px") var prompt_hud_safe_top: float = DEFAULT_SAFE_TOP

## Manifestation: the echo only exists inside this ring. Start appearing at
## manifest_range, start fading out beyond hide_range (hysteresis keeps it from
## flickering at the boundary). Both are >= near_range so the figure is visible
## before the F prompt appears.
## Defaults are already valid: near_range 56 < manifest_range 96 < hide_range 112.
## Exported values are taken as authored (no clamp/repair framework for illegal ones).
@export_range(48.0, 200.0, 1.0, "suffix:px") var manifest_range: float = 96.0
@export_range(48.0, 240.0, 1.0, "suffix:px") var hide_range: float = 112.0
@export_range(0.05, 1.5, 0.01, "suffix:s") var fade_in_duration: float = 0.25
@export_range(0.05, 1.5, 0.01, "suffix:s") var fade_out_duration: float = 0.20

static var _shared_font: FontFile = null
static var _font_checked: bool = false

var _sprite: Sprite2D = null
var _texture: Texture2D = null
var _stone: Sprite2D = null
var _projection: Node2D = null
var _manifest: float = 0.0
var _manifest_target: float = 0.0
var _manifest_was_visible: bool = false
var _player: PrototypePlayer = null
var _suspended: bool = false
var _in_range: bool = false
var _page_index: int = -1
var _animation_frame: int = 0
var _animation_accumulator: float = 0.0
var _ui_layer: CanvasLayer = null
var _prompt_root: Control = null
var _prompt_panel: Panel = null
var _prompt_label: Label = null
var _dialog_root: Control = null
var _dialog_panel: Panel = null
var _speaker_label: Label = null
var _body_label: Label = null
var _page_label: Label = null
var _action_label: Label = null
var _screen_anchor_x: float = 0.0
var _font_missing_warned: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP_NAME)


func _exit_tree() -> void:
	remove_from_group(GROUP_NAME)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_carrier()
	_ensure_projection()
	_ensure_sprite()
	_load_texture()
	_apply_frame()
	_apply_manifestation()
	if Engine.is_editor_hint():
		set_process(false)
		set_process_unhandled_input(false)
		return
	_ensure_ui()
	_resolve_player()
	set_process(true)
	set_process_unhandled_input(true)
	_refresh_ui()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _suspended:
		return
	if get_tree() != null and get_tree().paused:
		return
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	_advance_idle(delta)
	if _player == null:
		return
	var distance: float = global_position.distance_to(_player.global_position)
	_update_manifestation(delta, distance)
	var limit: float = get_leave_range() if _in_range else near_range
	var within: bool = distance <= limit
	if within != _in_range:
		_set_in_range(within)
	if not _in_range:
		return
	if _page_index >= 0:
		_layout_dialog()
	else:
		_layout_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _suspended or not _in_range:
		return
	if _manifest <= 0.0:
		return                      # still fully transparent: do not eat the first F
	if get_tree() == null or get_tree().paused:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	# OS key-repeat must not page the dialogue while F is held.
	if key_event.echo or not key_event.pressed:
		return
	if not key_event.is_action_pressed(&"tutorial_next"):
		return
	if _page_index < 0:
		if open_dialogue():
			get_viewport().set_input_as_handled()
	elif advance_page():
		get_viewport().set_input_as_handled()


## Opens page 1 only when the player is already in range and the echo is awake.
func open_dialogue() -> bool:
	if _suspended or not _in_range or pages.is_empty():
		return false
	_page_index = 0
	_refresh_ui()
	return true


## F advances one page; on the last page it closes the conversation instead.
func advance_page() -> bool:
	if _page_index < 0 or pages.is_empty():
		return false
	if _page_index + 1 >= pages.size():
		_page_index = -1
	else:
		_page_index += 1
	_refresh_ui()
	return true


func close_dialogue() -> void:
	_page_index = -1
	_refresh_ui()


## The level owns menu/opening/pause/completion gates. Suspending clears both
## the page and the prompt; unsuspending lets the next process tick re-evaluate
## proximity, so a player already standing nearby can talk again.
func set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	if _suspended:
		_in_range = false
		_page_index = -1
	_refresh_ui()


func is_suspended() -> bool:
	return _suspended


## R / fall / reset clears the old page. The prompt may remain if still nearby;
## reading is never part of any completion condition.
func on_player_reset(_reason: String = "") -> void:
	_page_index = -1
	_refresh_ui()


## OS focus loss clears a half-read page. Input is not replayed automatically.
func on_focus_lost() -> void:
	_page_index = -1
	_refresh_ui()


func force_close() -> void:
	_page_index = -1
	_refresh_ui()


func get_leave_range() -> float:
	return near_range + leave_margin


func is_in_range() -> bool:
	return _in_range


func is_prompt_visible() -> bool:
	return _prompt_root != null and _prompt_root.visible


func is_dialogue_open() -> bool:
	return _page_index >= 0 and _dialog_root != null and _dialog_root.visible


func get_page_index() -> int:
	return _page_index


func get_page_count() -> int:
	return pages.size()


func get_current_page_text() -> String:
	if _page_index < 0 or _page_index >= pages.size():
		return ""
	return pages[_page_index]


func get_display_name() -> String:
	return DISPLAY_NAME


func get_prompt_text() -> String:
	return _prompt_label.text if _prompt_label != null else ""


func get_speaker_text() -> String:
	return _speaker_label.text if _speaker_label != null else ""


func get_action_text() -> String:
	return _action_label.text if _action_label != null else ""


func get_page_text() -> String:
	return _page_label.text if _page_label != null else ""


func get_prompt_rect() -> Rect2:
	if _prompt_root == null or not _prompt_root.visible:
		return Rect2()
	return Rect2(_prompt_root.global_position, _prompt_root.size)


func get_dialogue_rect() -> Rect2:
	if _dialog_root == null or not _dialog_root.visible:
		return Rect2()
	return Rect2(_dialog_root.global_position, _dialog_root.size)


func get_body_font() -> Font:
	return _body_label.get_theme_font("font") if _body_label != null else null


func get_body_font_size() -> int:
	return _body_label.get_theme_font_size("font_size") if _body_label != null else 0


func get_animation_frame() -> int:
	return _animation_frame


func get_animation_frame_count() -> int:
	return FRAME_COUNT


func get_player() -> PrototypePlayer:
	return _player


func get_sheet_texture() -> Texture2D:
	return _texture


## Manifestation state, for the focused checks and for any later gate that needs it.
func get_manifestation() -> float:
	return _manifest


func is_manifestation_visible() -> bool:
	return _manifest > 0.0


func get_manifest_range() -> float:
	return manifest_range


func get_hide_range() -> float:
	return hide_range


func get_carrier_stone() -> Sprite2D:
	return _stone


func get_carrier_texture() -> Texture2D:
	return _stone.texture if _stone != null else null


func get_projection_lift() -> float:
	return PROJECTION_LIFT


func get_foot_anchor() -> Vector2:
	return FOOT_ANCHOR


func get_sprite_offset() -> Vector2:
	return SPRITE_OFFSET


func has_collision_body() -> bool:
	return not find_children("*", "CollisionObject2D", true, false).is_empty()


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


func _set_in_range(value: bool) -> void:
	_in_range = value
	if not _in_range:
		_page_index = -1
	_refresh_ui()


func _ensure_carrier() -> void:
	_stone = get_node_or_null("CarrierStone") as Sprite2D
	if _stone == null:
		_stone = Sprite2D.new()
		_stone.name = "CarrierStone"
		add_child(_stone)
		move_child(_stone, 0)
	_stone.centered = false
	_stone.position = CARRIER_OFFSET
	_stone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(CARRIER_TEXTURE_PATH, "Texture2D"):
		_stone.texture = ResourceLoader.load(
			CARRIER_TEXTURE_PATH, "Texture2D", ResourceLoader.CACHE_MODE_REUSE
		) as Texture2D
	else:
		push_warning("GuideEcho: missing carrier texture %s" % CARRIER_TEXTURE_PATH)


func _ensure_projection() -> void:
	_projection = get_node_or_null("EchoProjection") as Node2D
	if _projection == null:
		_projection = Node2D.new()
		_projection.name = "EchoProjection"
		add_child(_projection)
	_projection.position = Vector2(0.0, -PROJECTION_LIFT)
	_projection.z_index = 1


func _ensure_sprite() -> void:
	var host: Node = _projection if _projection != null else self
	_sprite = host.get_node_or_null("EchoSprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "EchoSprite"
		host.add_child(_sprite)
	_sprite.centered = false
	_sprite.position = SPRITE_OFFSET
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hframes = FRAME_COUNT
	_sprite.vframes = 1


func _load_texture() -> void:
	if not ResourceLoader.exists(SHEET_PATH, "Texture2D"):
		push_warning("GuideEcho: missing texture %s" % SHEET_PATH)
		return
	_texture = ResourceLoader.load(SHEET_PATH, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	if _texture == null:
		push_warning("GuideEcho: %s did not load as Texture2D" % SHEET_PATH)
		return
	if Vector2i(_texture.get_size()) != Vector2i(FRAME_SIZE.x * FRAME_COUNT, FRAME_SIZE.y):
		push_warning(
			"GuideEcho: sheet is %s, expected %s"
			% [str(_texture.get_size()), str(Vector2i(FRAME_SIZE.x * FRAME_COUNT, FRAME_SIZE.y))]
		)
	_sprite.texture = _texture
	_sprite.hframes = FRAME_COUNT
	_sprite.vframes = 1


func _apply_frame() -> void:
	if _sprite == null:
		return
	_sprite.frame = clampi(_animation_frame, 0, FRAME_COUNT - 1)


func _advance_idle(delta: float) -> void:
	_animation_accumulator += delta * IDLE_FPS
	var steps: int = int(_animation_accumulator)
	if steps <= 0:
		return
	_animation_accumulator -= float(steps)
	_animation_frame = wrapi(_animation_frame + steps, 0, FRAME_COUNT)
	_apply_frame()


## Runtime alpha only: the approved sheet is never redrawn, tinted or rescaled.
func _apply_manifestation() -> void:
	if _sprite == null:
		return
	_sprite.modulate.a = clampf(_manifest, 0.0, 1.0)


## Appear inside manifest_range, disappear beyond hide_range; between the two the
## current target is kept (hysteresis). Walking back in mid-fade reverses smoothly.
func _update_manifestation(delta: float, distance: float) -> void:
	if distance <= manifest_range:
		_manifest_target = 1.0
	elif distance > hide_range:
		_manifest_target = 0.0
	var duration: float = fade_in_duration if _manifest_target > _manifest else fade_out_duration
	if duration <= 0.001:
		_manifest = _manifest_target
	else:
		_manifest = move_toward(_manifest, _manifest_target, delta / duration)
	_apply_manifestation()
	var visible_now: bool = _manifest > 0.0
	if visible_now != _manifest_was_visible:
		_manifest_was_visible = visible_now
		_refresh_ui()


func _ensure_ui() -> void:
	if _ui_layer != null:
		return
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "GuideEchoLayer"
	_ui_layer.layer = 8
	add_child(_ui_layer)

	var font: FontFile = _get_shared_font()
	if font == null:
		font = ThemeDB.fallback_font
		if not _font_missing_warned:
			push_warning("GuideEcho: %s is not imported; Chinese text will be missing" % FONT_PATH)
			_font_missing_warned = true

	_prompt_root = Control.new()
	_prompt_root.name = "TalkPrompt"
	_prompt_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.visible = false
	_prompt_root.draw.connect(_draw_prompt_frame)
	_ui_layer.add_child(_prompt_root)

	_prompt_panel = Panel.new()
	_prompt_panel.position = Vector2.ZERO
	_prompt_panel.size = Vector2(PROMPT_WIDTH, PROMPT_HEIGHT)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_theme_stylebox_override("panel", _make_style())
	_prompt_root.add_child(_prompt_panel)
	_prompt_label = _make_label(font, PROMPT_FONT_SIZE, GOLD_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.text = "F 交谈"
	_prompt_label.position = Vector2(0.0, 3.0)
	_prompt_label.size = Vector2(PROMPT_WIDTH, 16.0)
	_prompt_root.add_child(_prompt_label)

	_dialog_root = Control.new()
	_dialog_root.name = "Dialogue"
	_dialog_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_root.visible = false
	_dialog_root.draw.connect(_draw_dialog_frame)
	_ui_layer.add_child(_dialog_root)

	_dialog_panel = Panel.new()
	_dialog_panel.position = Vector2.ZERO
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_panel.add_theme_stylebox_override("panel", _make_style())
	_dialog_root.add_child(_dialog_panel)

	_speaker_label = _make_label(font, META_FONT_SIZE, GOLD_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_speaker_label.text = DISPLAY_NAME
	_dialog_root.add_child(_speaker_label)

	_body_label = _make_label(font, BODY_FONT_SIZE, TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialog_root.add_child(_body_label)

	_page_label = _make_label(font, META_FONT_SIZE, MUTED_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_dialog_root.add_child(_page_label)

	_action_label = _make_label(font, META_FONT_SIZE, GOLD_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_dialog_root.add_child(_action_label)


func _make_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.anti_aliasing = false
	return style


func _make_label(font: Font, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 0)
	return label


func _refresh_ui() -> void:
	if _prompt_root == null or _dialog_root == null:
		return
	var paused: bool = get_tree() != null and get_tree().paused
	var awake: bool = not _suspended and not paused
	var visible_echo: bool = _manifest > 0.0
	var show_dialog: bool = awake and _in_range and _page_index >= 0
	var show_prompt: bool = awake and _in_range and _page_index < 0 and visible_echo
	_dialog_root.visible = show_dialog
	_prompt_root.visible = show_prompt
	if show_dialog:
		_layout_dialog()
	elif show_prompt:
		_layout_prompt()


func _layout_prompt() -> void:
	if _prompt_root == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = minf(PROMPT_WIDTH, maxf(60.0, viewport_size.x - SCREEN_MARGIN * 2.0))
	var anchor: Vector2 = get_viewport().get_canvas_transform() * global_position
	var target_x: float = clampf(
		anchor.x - width * 0.5,
		SCREEN_MARGIN,
		maxf(SCREEN_MARGIN, viewport_size.x - width - SCREEN_MARGIN)
	)
	var target_y: float = clampf(
		anchor.y - FRAME_SIZE.y - PROJECTION_LIFT - PROMPT_GAP - PROMPT_HEIGHT,
		prompt_hud_safe_top,
		maxf(prompt_hud_safe_top, viewport_size.y - SCREEN_MARGIN - PROMPT_HEIGHT)
	)
	_prompt_root.size = Vector2(roundf(width), PROMPT_HEIGHT)
	_prompt_root.global_position = Vector2(roundf(target_x), roundf(target_y))
	_screen_anchor_x = anchor.x
	_prompt_panel.size = _prompt_root.size
	_prompt_label.position = Vector2(0.0, 3.0)
	_prompt_label.size = Vector2(width, 16.0)
	_prompt_root.queue_redraw()


func _layout_dialog() -> void:
	if _dialog_root == null or _body_label == null:
		return
	var font: Font = _body_label.get_theme_font("font")
	if font == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = minf(prompt_width, maxf(240.0, viewport_size.x - SCREEN_MARGIN * 2.0))
	var body_width: float = maxf(width - PADDING * 2.0, 120.0)
	var text: String = get_current_page_text()
	var measured: Vector2 = font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, body_width, BODY_FONT_SIZE
	)
	var body_height: float = maxf(ceilf(measured.y), float(BODY_FONT_SIZE))
	var panel_height: float = (
		PADDING * 2.0 + SPEAKER_HEIGHT + BODY_GAP + body_height + FOOTER_GAP + FOOTER_HEIGHT
	)
	var anchor: Vector2 = get_viewport().get_canvas_transform() * global_position
	var target_x: float = clampf(
		anchor.x - width * 0.5,
		SCREEN_MARGIN,
		maxf(SCREEN_MARGIN, viewport_size.x - width - SCREEN_MARGIN)
	)
	var target_y: float = clampf(
		anchor.y - FRAME_SIZE.y - PROJECTION_LIFT - DIALOG_GAP - panel_height,
		prompt_hud_safe_top,
		maxf(prompt_hud_safe_top, viewport_size.y - SCREEN_MARGIN - panel_height)
	)
	_dialog_root.size = Vector2(roundf(width), roundf(panel_height))
	_dialog_root.global_position = Vector2(roundf(target_x), roundf(target_y))
	_dialog_panel.size = _dialog_root.size
	_screen_anchor_x = anchor.x

	_speaker_label.text = DISPLAY_NAME
	_speaker_label.position = Vector2(PADDING, PADDING)
	_speaker_label.size = Vector2(body_width, SPEAKER_HEIGHT)

	_body_label.text = text
	_body_label.position = Vector2(PADDING, PADDING + SPEAKER_HEIGHT + BODY_GAP)
	_body_label.size = Vector2(body_width, body_height + 3.0)

	var footer_y: float = PADDING + SPEAKER_HEIGHT + BODY_GAP + body_height + FOOTER_GAP
	_page_label.text = "%d / %d" % [_page_index + 1, pages.size()]
	_page_label.position = Vector2(PADDING, footer_y)
	_page_label.size = Vector2(70.0, FOOTER_HEIGHT)
	var last_page: bool = _page_index + 1 >= pages.size()
	_action_label.text = "F 收起" if last_page else "F 继续"
	_action_label.position = Vector2(width - PADDING - 90.0, footer_y)
	_action_label.size = Vector2(90.0, FOOTER_HEIGHT)
	_dialog_root.queue_redraw()


func _draw_prompt_frame() -> void:
	if _prompt_root == null:
		return
	var size: Vector2 = _prompt_root.size
	var notch_center: float = clampf(_screen_anchor_x - _prompt_root.global_position.x, 12.0, size.x - 12.0)
	var bottom: float = size.y - 1.0
	_prompt_root.draw_colored_polygon(
		PackedVector2Array([
			Vector2(notch_center - 5.0, bottom),
			Vector2(notch_center + 5.0, bottom),
			Vector2(notch_center, bottom + 6.0),
		]),
		PANEL_BORDER
	)


func _draw_dialog_frame() -> void:
	if _dialog_root == null:
		return
	var size: Vector2 = _dialog_root.size
	# A thin stone-coloured divider under the speaker keeps the existing panel
	# language without introducing a new ornament system.
	_dialog_root.draw_rect(
		Rect2(Vector2(PADDING, PADDING + SPEAKER_HEIGHT - 1.0), Vector2(size.x - PADDING * 2.0, 1.0)),
		Color(PANEL_BORDER, 0.55),
		true
	)
	var notch_center: float = clampf(_screen_anchor_x - _dialog_root.global_position.x, 12.0, size.x - 12.0)
	var bottom: float = size.y - 1.0
	_dialog_root.draw_colored_polygon(
		PackedVector2Array([
			Vector2(notch_center - 7.0, bottom),
			Vector2(notch_center + 7.0, bottom),
			Vector2(notch_center, bottom + 7.0),
		]),
		PANEL_BORDER
	)
	_dialog_root.draw_colored_polygon(
		PackedVector2Array([
			Vector2(notch_center - 5.0, bottom),
			Vector2(notch_center + 5.0, bottom),
			Vector2(notch_center, bottom + 5.0),
		]),
		PANEL_BG
	)


static func _get_shared_font() -> FontFile:
	if _font_checked:
		return _shared_font
	_font_checked = true
	if not ResourceLoader.exists(FONT_PATH):
		return null
	var base_font: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if base_font == null:
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
