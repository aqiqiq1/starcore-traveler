class_name GuideEcho
extends Node2D

## Fixed manifestation of the ancient watcher's echo ("守望者残响").
##
## Presentation phase (2026-11-17): the in-world echo keeps its carrier stele and
## 6-frame sheet, but the page now uses the same compact 246 px bubble language
## as the level-03 cinematic: 12 px font, cyan speaker, light body, grey page
## number, 34 cps reveal. The page is positioned from the actual Sprite2D
## screen rect, never from a feet offset, so the bubble cannot cover the echo's
## head. F first completes the current line, then advances/closes; the page
## height is measured from the full text once so it cannot grow while typing.
## The ordinary talk hint is one approved 11x13 F keycap plus 交谈, drawn through
## the shared InteractionKeyHint helper. It is hidden while the opening film
## owns the echo (_cinematic_owned), while paused, out of range, or blocked.
##
## The echo itself is still pure presentation: no collision, no force, no AI,
## no level gating, no player lock.

const GROUP_NAME: StringName = &"guide_echo"
const DISPLAY_NAME: String = "守望者残响"
const SHEET_PATH: String = "res://assets/guide_echo_20261113/guide_echo_idle_6f_s40.png"
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const DIALOGUE_VOICE_SCRIPT = preload("res://scripts/narrative/dialogue_voice.gd")
const INTERACTION_KEY_HINT = preload("res://scripts/ui/interaction_key_hint.gd")
const PROMPT_FOOTER_SCRIPT = preload("res://scripts/ui/prompt_footer.gd")
const FRAME_SIZE: Vector2i = Vector2i(48, 64)
const FRAME_COUNT: int = 6
const FOOT_ANCHOR: Vector2 = Vector2(24.0, 60.0)
const SPRITE_OFFSET: Vector2 = Vector2(-24.0, -60.0)
const IDLE_FPS: float = 4.0
const CARRIER_TEXTURE_PATH: String = "res://assets/tutorial_stele/tutorial_stele_grey.png"
const CARRIER_SIZE: Vector2i = Vector2i(26, 52)
const CARRIER_OFFSET: Vector2 = Vector2(-13.0, -52.0)
const PROJECTION_LIFT: float = 18.0

const BODY_FONT_SIZE: int = 12
const META_FONT_SIZE: int = 12
const DIALOG_WIDTH: float = 246.0
const PADDING: float = 6.0
const SPEAKER_HEIGHT: float = 16.0
const BODY_GAP: float = 2.0
const BUBBLE_GAP: float = 8.0
const SAFE_RECT: Rect2 = Rect2(8.0, 48.0, 624.0, 264.0)
const TYPE_CPS: float = 34.0
const PROMPT_TEXT: String = "交谈"
const PROMPT_KEY: String = "F"
const PROMPT_HEIGHT: float = 13.0
const KEY_MIN_WIDTH: float = 44.0
const PROMPT_GAP: float = 8.0
const SCREEN_MARGIN: float = 4.0
const DEFAULT_SAFE_TOP: float = 56.0

const CYAN: Color = Color("#5fe1e6")
const GOLD: Color = Color("#f4cd63")
const TEXT_COLOR: Color = Color("#e7eceb")
const MUTED_COLOR: Color = Color("#a4b3be")
const PANEL_BG: Color = Color(0.020, 0.048, 0.058, 0.93)
const PANEL_BORDER: Color = Color(0.37, 0.72, 0.74, 0.85)

@export var pages: PackedStringArray = PackedStringArray([
	"后面的桥断了，回不去了。\n沿着这条路往前，旧门还在。",
	"你胸前那枚护符还能用。\n换一种相性，再看看符石的反应。",
	"金色是辉相，青色是澜相。\n颜色相同会推开，不同会拉近。",
]):
	set(value):
		pages = value
		if is_inside_tree() and _page_index >= pages.size():
			_page_index = -1
		_refresh_ui()

@export_range(16.0, 160.0, 1.0, "suffix:px") var near_range: float = 56.0:
	set(value):
		near_range = maxf(value, 1.0)

@export_range(0.0, 64.0, 1.0, "suffix:px") var leave_margin: float = 10.0:
	set(value):
		leave_margin = maxf(value, 0.0)

@export var player_path: NodePath = NodePath()

@export_range(240.0, 480.0, 1.0, "suffix:px") var prompt_width: float = DIALOG_WIDTH

@export_range(0.0, 120.0, 1.0, "suffix:px") var prompt_hud_safe_top: float = DEFAULT_SAFE_TOP

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
var _prompt_canvas: Control = null
## Compatibility data carrier for the old prompt label; the visible F cap and
## 交谈 word are drawn by the shared InteractionKeyHint helper.
var _prompt_label: Label = null
var _dialog_root: Control = null
var _dialog_panel: Panel = null
var _speaker_label: Label = null
var _body_label: Label = null
var _page_label: Label = null
var _prompt_footer: Control = null
var _screen_anchor_x: float = 0.0
var _reveal: float = 0.0
var _dialog_size: Vector2 = Vector2(246.0, 60.0)
var _last_echo_rect: Rect2 = Rect2()
var _voice = null
var _font_missing_warned: bool = false
## Set by the level-01 opening film. While owned, the echo still exposes its
## public page API to that controller, but F is not accepted and the small
## "交谈" prompt cannot compete with the opening's own pages.
var _cinematic_owned: bool = false


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
	_ensure_voice()
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
		_update_prompt_footer()
		return
	if _page_index >= 0:
		_advance_reveal(delta)
		_layout_dialog()
	else:
		_layout_prompt()
	_update_prompt_footer()


## Node pause notification covers the pause page even if a caller forgets to
## suspend the echo.  It only refreshes presentation; page/input state is not
## changed here.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		if is_inside_tree() and not Engine.is_editor_hint():
			_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _suspended or _cinematic_owned or not _in_range:
		return
	if _manifest <= 0.0:
		return
	if get_tree() == null or get_tree().paused:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.echo or not key_event.pressed:
		return
	if not key_event.is_action_pressed(&"tutorial_next"):
		return
	if _page_index < 0:
		if open_dialogue():
			get_viewport().set_input_as_handled()
	elif _press_page():
		get_viewport().set_input_as_handled()


func open_dialogue() -> bool:
	if _suspended or not _in_range or pages.is_empty():
		return false
	if _manifest <= 0.0:
		return false
	_page_index = 0
	_begin_page()
	_refresh_ui()
	return true


## F semantics: while the line is still revealing, the first press completes
## it; only a press on the completed line advances. The last page closes.
func _press_page() -> bool:
	if _page_index < 0 or pages.is_empty():
		return false
	var full: String = get_current_page_text()
	if _reveal < float(full.length()):
		_reveal = float(full.length())
		_body_label.text = full
		if _voice != null:
			_voice.complete_reveal()
		return true
	if _page_index + 1 >= pages.size():
		close_dialogue()
		return true
	_page_index += 1
	_begin_page()
	_refresh_ui()
	return true


## Compatibility: tests may call advance_page() directly. It follows the same
## complete-first rule as F.
func advance_page() -> bool:
	if _page_index < 0 or pages.is_empty():
		return false
	return _press_page()


func close_dialogue() -> void:
	_page_index = -1
	if _voice != null:
		_voice.stop()
	_refresh_ui()


func set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	if _suspended:
		_in_range = false
		_page_index = -1
		if _voice != null:
			_voice.stop()
	_refresh_ui()


func is_suspended() -> bool:
	return _suspended


## Explicit ownership hand-off for the level-01 opening. It does not suspend
## the echo or close its page; it only reserves page input for the opening.
func set_cinematic_owned(value: bool) -> void:
	if _cinematic_owned == value:
		return
	_cinematic_owned = value
	_refresh_ui()


func is_cinematic_owned() -> bool:
	return _cinematic_owned


func on_player_reset(_reason: String = "") -> void:
	_page_index = -1
	if _voice != null:
		_voice.stop()
	_refresh_ui()


func on_focus_lost() -> void:
	_page_index = -1
	if _voice != null:
		_voice.stop()
	_refresh_ui()


func force_close() -> void:
	_page_index = -1
	if _voice != null:
		_voice.stop()
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


## Text currently drawn (after the 34 cps reveal).
func get_page_text() -> String:
	return _body_label.text if _body_label != null else ""


func get_full_page_text() -> String:
	return get_current_page_text()


func get_revealed_count() -> int:
	return int(_reveal)


func get_display_name() -> String:
	return DISPLAY_NAME


func get_prompt_text() -> String:
	return _prompt_label.text if _prompt_label != null else ""


## The key drawn on the visible hint. Ordinary echo talk is F and only while
## the prompt is actually shown (not during the opening film, pause, out of
## range, or after a level block).
func get_prompt_key() -> String:
	return PROMPT_KEY if is_prompt_visible() else ""


func get_prompt_verb() -> String:
	return PROMPT_TEXT


func get_prompt_hint_width() -> float:
	if _prompt_root == null or not _prompt_root.visible:
		return 0.0
	return _prompt_root.size.x


func is_prompt_keycap_visible() -> bool:
	return _prompt_canvas != null and _prompt_root != null and _prompt_root.visible


## Frameless action-hint audit: no Panel child is created under the prompt root.
func has_prompt_panel() -> bool:
	if _prompt_root == null:
		return false
	return not _prompt_root.find_children("*", "Panel", true, false).is_empty()


func get_prompt_font_size() -> int:
	return _prompt_label.get_theme_font_size("font_size") if _prompt_label != null else 0


func get_prompt_color() -> Color:
	return _prompt_label.get_theme_color("font_color") if _prompt_label != null else Color.WHITE


func get_speaker_text() -> String:
	return _speaker_label.text if _speaker_label != null else ""


func get_action_text() -> String:
	return ""


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


func get_voice():
	return _voice


# --- Shared page footer read-only helpers (tests / captures) ----------------

func get_prompt_footer() -> Control:
	return _prompt_footer


func is_prompt_footer_visible() -> bool:
	return _prompt_footer != null and _prompt_footer.visible


func get_prompt_footer_text() -> String:
	if _prompt_footer == null:
		return ""
	return String(_prompt_footer.call("get_text"))


## Actual visible sprite rectangle in viewport coordinates. Uses the real
## Sprite2D transform + get_rect(), including the projection offset.
func get_echo_screen_rect() -> Rect2:
	if _sprite == null or not is_inside_tree():
		return Rect2()
	var xf: Transform2D = _sprite.get_global_transform_with_canvas()
	return xf * _sprite.get_rect()


func get_player_screen_rect() -> Rect2:
	if _player == null or not is_inside_tree():
		return Rect2()
	var feet: Vector2 = get_viewport().get_canvas_transform() * _player.global_position
	return Rect2(feet + Vector2(-8.0, -34.0), Vector2(16.0, 34.0))


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
		if _voice != null:
			_voice.stop()
	_refresh_ui()


func _begin_page() -> void:
	_reveal = 0.0
	_last_echo_rect = Rect2()
	if _body_label != null:
		_body_label.text = ""
	if _voice != null:
		_voice.begin_page()
	_layout_dialog()


func _advance_reveal(delta: float) -> void:
	if _page_index < 0 or _page_index >= pages.size():
		return
	var full: String = pages[_page_index]
	if _reveal >= float(full.length()):
		return
	_reveal = minf(_reveal + delta * TYPE_CPS, float(full.length()))
	if _body_label != null:
		_body_label.text = full.substr(0, int(_reveal))
	if _voice != null:
		_voice.update_text(full, int(_reveal), delta)


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


func _apply_manifestation() -> void:
	if _sprite == null:
		return
	_sprite.modulate.a = clampf(_manifest, 0.0, 1.0)


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
	if _manifest <= 0.0 and _voice != null:
		_voice.stop()


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
	_ui_layer.add_child(_prompt_root)

	# Ordinary talk hint: one approved 11x13 F cap plus 交谈, drawn by the one
	# shared keycap helper. Only the dialogue bubble keeps its cyan speaker and
	# bordered panel.
	_prompt_canvas = Control.new()
	_prompt_canvas.name = "TalkKeyHint"
	_prompt_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_canvas.draw.connect(_draw_prompt_hint)
	_prompt_root.add_child(_prompt_canvas)

	_prompt_label = _make_label(font, META_FONT_SIZE, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.text = PROMPT_TEXT
	_prompt_label.position = Vector2(0.0, 3.0)
	_prompt_label.size = Vector2(16.0, 16.0)
	# Kept only so existing prompt text/size/colour accessors stay valid; it is
	# never the visible prompt any more.
	_prompt_label.visible = false
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

	_speaker_label = _make_label(font, META_FONT_SIZE, CYAN, HORIZONTAL_ALIGNMENT_LEFT)
	_speaker_label.text = DISPLAY_NAME
	_dialog_root.add_child(_speaker_label)

	_body_label = _make_label(font, BODY_FONT_SIZE, TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialog_root.add_child(_body_label)

	_page_label = _make_label(font, META_FONT_SIZE, MUTED_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_dialog_root.add_child(_page_label)

	# Shared one-line page footer, added under the echo's existing UI layer.
	# It never reads input; this node decides when the bubble waits for F.
	_prompt_footer = PROMPT_FOOTER_SCRIPT.new()
	_prompt_footer.name = "PromptFooter"
	_ui_layer.add_child(_prompt_footer)


func _ensure_voice() -> void:
	if _voice != null:
		return
	_voice = DIALOGUE_VOICE_SCRIPT.new()
	_voice.name = "EchoVoice"
	add_child(_voice)


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
	label.add_theme_color_override("font_outline_color", Color(0.006, 0.014, 0.018, 0.96))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_constant_override("line_spacing", 0)
	return label


func _refresh_ui() -> void:
	if _prompt_root == null or _dialog_root == null:
		return
	var paused: bool = get_tree() != null and get_tree().paused
	var awake: bool = not _suspended and not paused
	var visible_echo: bool = _manifest > 0.0
	var show_dialog: bool = awake and _in_range and _page_index >= 0
	var show_prompt: bool = (
		awake and not _cinematic_owned and _in_range and _page_index < 0 and visible_echo
	)
	_dialog_root.visible = show_dialog
	_prompt_root.visible = show_prompt
	if show_dialog:
		_layout_dialog()
	elif show_prompt:
		_layout_prompt()
	_update_prompt_footer()


## Footer appears only while the dialogue bubble is open, the player is in
## range, no film owns the echo, the tree is not paused and the line has fully
## revealed.  Every other state hides it in the same frame.
func _update_prompt_footer() -> void:
	if _prompt_footer == null:
		return
	var paused: bool = get_tree() != null and get_tree().paused
	var waiting: bool = (
		not _suspended
		and not _cinematic_owned
		and _in_range
		and not paused
		and _page_index >= 0
		and _page_index < pages.size()
		and _manifest > 0.0
		and _dialog_root != null
		and _dialog_root.visible
	)
	if waiting:
		var full: String = get_current_page_text()
		if full.is_empty() or _reveal < float(full.length()):
			waiting = false
		else:
			var text: String = (
				PROMPT_FOOTER_SCRIPT.PAGE_FOOTER
				if _page_index + 1 < pages.size()
				else PROMPT_FOOTER_SCRIPT.SINGLE_FOOTER
			)
			_prompt_footer.call("show_footer", text)
	if not waiting:
		_prompt_footer.call("hide_footer")


func _layout_prompt() -> void:
	if _prompt_root == null or _prompt_canvas == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var echo_rect: Rect2 = get_echo_screen_rect()
	var font: Font = _prompt_label.get_theme_font("font") if _prompt_label != null else null
	var width: float = INTERACTION_KEY_HINT.action_width(font, PROMPT_TEXT)
	width = minf(width, maxf(KEY_MIN_WIDTH, viewport_size.x - SCREEN_MARGIN * 2.0))
	var target_x: float = clampf(
		echo_rect.get_center().x - width * 0.5,
		SCREEN_MARGIN,
		maxf(SCREEN_MARGIN, viewport_size.x - width - SCREEN_MARGIN)
	)
	var target_y: float = clampf(
		echo_rect.position.y - PROMPT_GAP - PROMPT_HEIGHT,
		prompt_hud_safe_top,
		maxf(prompt_hud_safe_top, viewport_size.y - SCREEN_MARGIN - PROMPT_HEIGHT)
	)
	_prompt_root.size = Vector2(roundf(width), PROMPT_HEIGHT)
	_prompt_root.global_position = Vector2(roundf(target_x), roundf(target_y))
	_screen_anchor_x = echo_rect.get_center().x
	_prompt_canvas.position = Vector2.ZERO
	_prompt_canvas.size = _prompt_root.size
	_prompt_canvas.queue_redraw()


## One approved 11x13 F cap + 4 px gap + 12 px 交谈 (dark shadow). The range,
## anchor and cinematic/pause/in-range gating all stay in the existing prompt
## state; this only changes how the visible hint is drawn.
func _draw_prompt_hint() -> void:
	if _prompt_canvas == null or _prompt_label == null:
		return
	var font: Font = _prompt_label.get_theme_font("font")
	INTERACTION_KEY_HINT.draw_action(
		_prompt_canvas, font, Vector2.ZERO, PROMPT_KEY, PROMPT_TEXT
	)


func _layout_dialog() -> void:
	if _dialog_root == null or _body_label == null or _page_index < 0:
		return
	var font: Font = _body_label.get_theme_font("font")
	if font == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = minf(DIALOG_WIDTH, maxf(240.0, viewport_size.x - SCREEN_MARGIN * 2.0))
	var body_width: float = maxf(width - PADDING * 2.0, 120.0)
	var full: String = get_current_page_text()
	var measured: Vector2 = font.get_multiline_string_size(
		full, HORIZONTAL_ALIGNMENT_LEFT, body_width, BODY_FONT_SIZE
	)
	var body_height: float = maxf(ceilf(measured.y), float(BODY_FONT_SIZE))
	var panel_height: float = PADDING * 2.0 + SPEAKER_HEIGHT + BODY_GAP + body_height

	var echo_rect: Rect2 = get_echo_screen_rect()
	var player_rect: Rect2 = get_player_screen_rect()
	var pos: Vector2 = _bubble_position(echo_rect, player_rect, width, panel_height)
	_dialog_root.size = Vector2(roundf(width), roundf(panel_height))
	_dialog_root.global_position = Vector2(roundf(pos.x), roundf(pos.y))
	_dialog_panel.size = _dialog_root.size
	_screen_anchor_x = echo_rect.get_center().x
	_last_echo_rect = echo_rect

	_speaker_label.text = DISPLAY_NAME
	_speaker_label.position = Vector2(PADDING, PADDING)
	_speaker_label.size = Vector2(body_width - 56.0, SPEAKER_HEIGHT)
	_page_label.text = "%d / %d" % [_page_index + 1, pages.size()]
	_page_label.position = Vector2(width - PADDING - 52.0, PADDING)
	_page_label.size = Vector2(52.0, SPEAKER_HEIGHT)
	_body_label.position = Vector2(PADDING, PADDING + SPEAKER_HEIGHT + BODY_GAP)
	_body_label.size = Vector2(body_width, body_height + 3.0)
	_dialog_root.queue_redraw()


## Prefer above the actual sprite rect; keep 8 px clear. If the top is blocked
## by the HUD safe area or the player body, try above the player, then the
## right/left side. The chosen side is deterministic for the same geometry, so
## typing cannot flip it.
func _bubble_position(echo_rect: Rect2, player_rect: Rect2, width: float, height: float) -> Vector2:
	var safe: Rect2 = SAFE_RECT
	var above: Vector2 = Vector2(
		echo_rect.get_center().x - width * 0.5,
		echo_rect.position.y - height - BUBBLE_GAP
	)
	above.x = clampf(above.x, safe.position.x, safe.end.x - width)
	var rect: Rect2 = Rect2(above, Vector2(width, height))
	if above.y >= safe.position.y and not rect.intersects(player_rect):
		return above
	var above_player: Vector2 = Vector2(
		player_rect.get_center().x - width * 0.5,
		player_rect.position.y - height - BUBBLE_GAP
	)
	above_player.x = clampf(above_player.x, safe.position.x, safe.end.x - width)
	var prect: Rect2 = Rect2(above_player, Vector2(width, height))
	if above_player.y >= safe.position.y and not prect.intersects(echo_rect):
		return above_player
	var right: Vector2 = Vector2(echo_rect.end.x + BUBBLE_GAP, echo_rect.position.y - 4.0)
	right.x = clampf(right.x, safe.position.x, safe.end.x - width)
	right.y = clampf(right.y, safe.position.y, safe.end.y - height)
	var right_rect: Rect2 = Rect2(right, Vector2(width, height))
	if right_rect.end.x <= safe.end.x and not right_rect.intersects(player_rect):
		return right
	var left: Vector2 = Vector2(echo_rect.position.x - width - BUBBLE_GAP, echo_rect.position.y - 4.0)
	left.x = clampf(left.x, safe.position.x, safe.end.x - width)
	left.y = clampf(left.y, safe.position.y, safe.end.y - height)
	var left_rect: Rect2 = Rect2(left, Vector2(width, height))
	if left_rect.position.x >= safe.position.x and not left_rect.intersects(player_rect):
		return left
	above.x = clampf(above.x, safe.position.x, safe.end.x - width)
	above.y = clampf(above.y, safe.position.y, safe.end.y - height)
	return above


func _draw_dialog_frame() -> void:
	if _dialog_root == null:
		return
	var size: Vector2 = _dialog_root.size
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
