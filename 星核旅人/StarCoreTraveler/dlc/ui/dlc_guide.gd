class_name DlcGuide
extends CanvasLayer

## Shared "how to clear this chapter" guide for the two DLC chapters.
##
## One 560x236 page at a time, opened once at level start by
## TrialChambers / RiftWorkshop (each level sets show_intro_guide = false before
## add_child() in the automated tests).  The left 256x144 window plays a real
## 24-frame / 8 fps loop captured from the formal chapter scene; the right side
## is title + 2-3 body lines + key hint.
##
## Input while open (the tree is paused):
##   F                 next page, close on the last page
##   Space (tap)       inert
##   Space (0.5 s)     close the whole guide, 96x6 gold hold bar lower-right
##   Esc               swallowed (no pause page, no gameplay key)
##
## Visual language is copied from the approved trial/rift HUD and the mechanic
## popup: near-black panel, 2 px cyan-grey border, gold title, 12 px body.
## The demo strips live in dlc/ui/demos and are captured from the real scenes;
## no diagram or external screenshot is used as gameplay footage.

signal opened(kind: String)
signal closed(kind: String)

const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")
const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const PANEL_POSITION: Vector2 = Vector2(40.0, 62.0)
const PANEL_SIZE: Vector2 = Vector2(560.0, 236.0)
const DEMO_POSITION: Vector2 = Vector2(12.0, 12.0)
const DEMO_SIZE: Vector2 = Vector2(256.0, 144.0)
const RIGHT_X: float = 282.0
const RIGHT_WIDTH: float = 266.0
const TITLE_WIDTH: float = 196.0
const SKIP_HOLD: float = 0.5
const DEMO_DIR: String = "res://dlc/ui/demos"
const DEFAULT_DEMO_FRAME_WIDTH: int = 256
const DEFAULT_DEMO_FRAME_HEIGHT: int = 144
const DEFAULT_DEMO_FPS: float = 8.0

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DIM: Color = Color("#728889")
const PANEL_BG: Color = Color(0.014, 0.032, 0.040, 0.96)
const PANEL_BORDER: Color = Color(0.45, 0.66, 0.63, 0.9)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

## Copy is limited to rules that already exist in the two chapters' code/HUD.
const PAGES: Dictionary = {
	"trial": [
		{
			"title": "极性门：两道门",
			"body": "试炼场的门由星核的辉、澜两面铸成。\n只放同相的人通过，门后是竞技场。\nQ 换辉相过金门，再换澜相过青门。",
			"key": "Q 换相 · 与门同相才能通过",
			"demo": "trial_gate",
		},
		{
			"title": "门内的相性",
			"body": "门只认相性：同相放行，异相拦停。\n门内换相不会被夹住。\n门重新闭合前离开，门才会恢复。",
			"key": "门内切相不夹 · 同相才放行",
			"demo": "trial_gate_inside",
		},
		{
			"title": "守卫的胸口余烬",
			"body": "守卫胸口锁着星核余烬，蓄力时以引力拖近。\n蓄力时 Q 切异相，被吸近后 J 打弱点 ×3。\n两次受击失败，试炼场送你回入口。",
			"key": "蓄力时异相 J · 2 次受击重试",
			"demo": "trial_guard_hit",
		},
	],
	"rift": [
		{
			"title": "路线：回廊 → 光桥 → 守卫",
			"body": "穿过紫色光幕与极性门，按相性跨过三座光桥。\n高台尽头记录检查点，然后进入双生守卫竞技场。",
			"key": "Q 换相 · 紫色光幕会自动翻转相性",
			"demo": "rift_inversion",
		},
		{
			"title": "反转场与相性桥",
			"body": "紫色光幕进入即反转一次，停在幕内不重复翻转。\n光桥同相才实体化；异相消失会落到下层。",
			"key": "Q 换相 · 与桥同色才能站上去",
			"demo": "rift_bridge",
		},
		{
			"title": "双生守卫：两只都要打",
			"body": "两只都要打：蓄力时异相 J 命中弱点 3 次。\n每次真伤后守卫换相，再按 Q 切回异相。\n两只都倒才开核心；失败/坠落时两只完整重生。",
			"key": "J 命中弱点 · 每只 3 点真伤",
			"demo": "rift_twins",
		},
	],
}

## Set by the owning chapter before open_guide().
var level_node: Node = null
var guide_kind: String = ""
## Overridable so the guide test can exercise the missing-demo fallback without
## touching the approved capture directory.
var demo_dir: String = DEMO_DIR

var _root: Control = null
var _shade: ColorRect = null
var _panel: Panel = null
var _demo_border: Panel = null
var _demo_rect: TextureRect = null
var _demo_placeholder: Label = null
var _title_label: Label = null
var _body_label: Label = null
var _key_label: Label = null
var _footer_label: Label = null
var _page_indicator: Label = null
var _skip_bar: SkipHoldBar = null
var _font: Font = null
var _reveal: UiReveal = null

var _demo_atlas: AtlasTexture = null
var _demo_id: String = ""
var _demo_frames: int = 0
var _demo_fps: float = DEFAULT_DEMO_FPS
var _demo_frame: int = 0
var _demo_time: float = 0.0
var _has_demo: bool = false
var _demo_still: bool = false

var _open: bool = false
var _page_index: int = 0
var _paused_before: bool = false
var _space_held: bool = false
var _space_hold: float = 0.0
var _space_armed: bool = false
var _open_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_font = _load_font()
	_build_ui()
	_reveal = UiReveal.new()
	_reveal.setup(self, _root, _shade, _panel, PANEL_POSITION)
	_root.visible = false
	set_process(true)


func configure(kind: String, level: Node) -> void:
	guide_kind = kind
	level_node = level


func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return ThemeDB.fallback_font
	var font_file: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if font_file == null:
		return ThemeDB.fallback_font
	var copy: FontFile = font_file.duplicate() as FontFile
	if copy != null:
		copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		copy.hinting = TextServer.HINTING_NONE
		copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		copy.allow_system_fallback = false
		return copy
	return font_file


func _label(
	text_value: String, position_value: Vector2, size_value: Vector2,
	font_size: int, color: Color
) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.006, 0.014, 0.018, 0.96))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_constant_override("line_spacing", 3)
	return label


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "DlcGuideRoot"
	_root.position = Vector2.ZERO
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.position = Vector2.ZERO
	_shade.size = VIEW_SIZE
	_shade.color = Color(0.006, 0.014, 0.018, 0.72)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_shade)

	_panel = Panel.new()
	_panel.name = "GuidePanel"
	_panel.position = PANEL_POSITION
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	_demo_border = Panel.new()
	_demo_border.name = "DemoBorder"
	_demo_border.position = DEMO_POSITION - Vector2.ONE
	_demo_border.size = DEMO_SIZE + Vector2(2.0, 2.0)
	_demo_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var demo_style: StyleBoxFlat = StyleBoxFlat.new()
	demo_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	demo_style.border_width_left = 1
	demo_style.border_width_top = 1
	demo_style.border_width_right = 1
	demo_style.border_width_bottom = 1
	demo_style.border_color = Color(0.45, 0.66, 0.63, 0.75)
	demo_style.anti_aliasing = false
	_demo_border.add_theme_stylebox_override("panel", demo_style)
	_panel.add_child(_demo_border)

	_demo_rect = TextureRect.new()
	_demo_rect.name = "Demo"
	_demo_rect.position = DEMO_POSITION
	_demo_rect.size = DEMO_SIZE
	_demo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_demo_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_demo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_demo_rect)

	_demo_placeholder = _label(
		"演示缺失", DEMO_POSITION, DEMO_SIZE, 12, MUTED
	)
	_demo_placeholder.name = "DemoPlaceholder"
	_demo_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demo_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_demo_placeholder.visible = false
	_panel.add_child(_demo_placeholder)

	_title_label = _label("", Vector2(RIGHT_X, 13.0), Vector2(TITLE_WIDTH, 20.0), 16, GOLD)
	_title_label.name = "Title"
	_panel.add_child(_title_label)

	_page_indicator = _label("", Vector2(486.0, 12.0), Vector2(62.0, 16.0), 12, MUTED)
	_page_indicator.name = "PageIndicator"
	_page_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_page_indicator)

	var divider: ColorRect = ColorRect.new()
	divider.name = "Divider"
	divider.position = Vector2(RIGHT_X, 36.0)
	divider.size = Vector2(RIGHT_WIDTH, 1.0)
	divider.color = Color(0.45, 0.66, 0.63, 0.35)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(divider)

	_body_label = _label("", Vector2(RIGHT_X, 43.0), Vector2(RIGHT_WIDTH, 62.0), 12, TEXT)
	_body_label.name = "Body"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_body_label)

	_key_label = _label("", Vector2(RIGHT_X, 108.0), Vector2(RIGHT_WIDTH, 38.0), 12, CYAN)
	_key_label.name = "Key"
	_key_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_key_label)

	_footer_label = _label(
		"F 下一页 · 长按空格 跳过", Vector2(16.0, 210.0), Vector2(420.0, 18.0), 12, DIM
	)
	_footer_label.name = "Footer"
	_panel.add_child(_footer_label)

	_skip_bar = SkipHoldBar.new()
	_skip_bar.name = "SkipHoldBar"
	_root.add_child(_skip_bar)


# --- Public API ------------------------------------------------------------

func is_open() -> bool:
	return _open


## Shared reveal state for tests/audits; F/hold-skip/close never wait on it.
func get_reveal() -> UiReveal:
	return _reveal


func get_open_count() -> int:
	return _open_count


func get_page_count() -> int:
	return _page_data().size()


func get_page_index() -> int:
	return _page_index


func get_page_indicator_text() -> String:
	return _page_indicator.text if _page_indicator != null else ""


func get_title_text() -> String:
	return _title_label.text if _title_label != null else ""


func get_body_text() -> String:
	return _body_label.text if _body_label != null else ""


func get_key_text() -> String:
	return _key_label.text if _key_label != null else ""


func get_footer_text() -> String:
	return _footer_label.text if _footer_label != null else ""


func get_demo_id() -> String:
	return _demo_id


func get_demo_frame_count() -> int:
	return _demo_frames


func get_demo_fps() -> float:
	return _demo_fps


func get_demo_frame() -> int:
	return _demo_frame


func has_demo() -> bool:
	return _has_demo


func is_demo_playing() -> bool:
	return _has_demo and _demo_frames > 1


func is_demo_still() -> bool:
	return _demo_still


func is_demo_placeholder_visible() -> bool:
	return _demo_placeholder != null and _demo_placeholder.visible


func get_demo_placeholder_text() -> String:
	return _demo_placeholder.text if _demo_placeholder != null else ""


func get_panel_rect() -> Rect2:
	return Rect2(PANEL_POSITION, PANEL_SIZE)


func get_demo_rect() -> Rect2:
	return Rect2(DEMO_POSITION, DEMO_SIZE)


func is_skip_bar_visible() -> bool:
	return _skip_bar != null and _skip_bar.visible


func get_skip_progress() -> float:
	return clampf(_space_hold / SKIP_HOLD, 0.0, 1.0)


func open_guide() -> bool:
	if _open:
		return false
	if not PAGES.has(guide_kind):
		return false
	_open = true
	_open_count += 1
	_page_index = 0
	_paused_before = get_tree().paused
	get_tree().paused = true
	_apply_page()
	_space_held = false
	_space_hold = 0.0
	# A Space already held before the guide opens must be released once, so the
	# opening state cannot count as a skip hold.
	_space_armed = not Input.is_physical_key_pressed(KEY_SPACE)
	if _skip_bar != null:
		_skip_bar.hide_progress()
	_root.visible = true
	if _reveal != null:
		_reveal.play_open()
	_clean_player_input()
	opened.emit(guide_kind)
	return true


func close() -> void:
	if not _open:
		return
	var closed_kind: String = guide_kind
	# Close/unpause is immediate; the panel only performs its 0.12 s exit and
	# no longer receives input.
	_open = false
	get_tree().paused = _paused_before
	_space_held = false
	_space_hold = 0.0
	_space_armed = false
	if _skip_bar != null:
		_skip_bar.hide_progress()
	if _reveal != null:
		_reveal.play_close()
	else:
		_root.visible = false
	_clean_player_input()
	closed.emit(closed_kind)


func _exit_tree() -> void:
	# A scene change while the guide is open must not leave the tree paused.
	if _open and get_tree() != null:
		get_tree().paused = _paused_before
		_open = false
	if _reveal != null:
		_reveal.snap_closed()


# --- Input / pages ---------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey):
		get_viewport().set_input_as_handled()
		return
	var key_event: InputEventKey = event as InputEventKey
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)
	if key_event.pressed and not key_event.echo:
		if code == int(KEY_F):
			_advance_page()
			get_viewport().set_input_as_handled()
			return
		if code == int(KEY_SPACE):
			if _space_armed:
				_space_held = true
				_space_hold = 0.0
			get_viewport().set_input_as_handled()
			return
		# Esc and every gameplay key stay inside the guide.
		get_viewport().set_input_as_handled()
		return
	if not key_event.pressed and code == int(KEY_SPACE):
		# A short tap only releases the arming latch; it never closes a page.
		_space_held = false
		_space_hold = 0.0
		_space_armed = true
		if _skip_bar != null:
			_skip_bar.hide_progress()
		get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _open:
		return
	_advance_demo(delta)
	if not _space_armed or not _space_held:
		return
	_space_hold = minf(_space_hold + delta, SKIP_HOLD)
	if _skip_bar != null:
		_skip_bar.update_hold(true, _space_hold, SKIP_HOLD)
	if _space_hold >= SKIP_HOLD:
		# The long hold closes the whole guide from any page.
		close()


func _advance_page() -> void:
	if not _open:
		return
	if _page_index + 1 < get_page_count():
		_page_index += 1
		_apply_page()
		_space_hold = 0.0
		_space_armed = not Input.is_physical_key_pressed(KEY_SPACE)
		if _skip_bar != null:
			_skip_bar.hide_progress()
		return
	close()


func _page_data() -> Array:
	var pages: Array = PAGES.get(guide_kind, []) as Array
	return pages


func _current_page() -> Dictionary:
	var pages: Array = _page_data()
	if _page_index < 0 or _page_index >= pages.size():
		return {}
	return pages[_page_index] as Dictionary


func _apply_page() -> void:
	var data: Dictionary = _current_page()
	_title_label.text = String(data.get("title", ""))
	_body_label.text = String(data.get("body", ""))
	_key_label.text = String(data.get("key", ""))
	_load_demo(String(data.get("demo", "")))
	var count: int = get_page_count()
	_page_indicator.text = "%d / %d" % [_page_index + 1, count]
	_footer_label.text = (
		"F 下一页 · 长按空格 跳过"
		if _page_index + 1 < count
		else "F 关闭 · 长按空格 跳过"
	)


# --- Demo strip ------------------------------------------------------------

## Loads a 24-frame horizontal strip and starts from frame 0.  A missing strip
## never falls back to a code diagram: the 256x144 window shows the "演示缺失"
## placeholder and the page's title/body/key stay readable.
func _load_demo(id: String) -> void:
	_demo_id = id
	_demo_atlas = null
	_demo_frames = 0
	_demo_fps = DEFAULT_DEMO_FPS
	_demo_frame = 0
	_demo_time = 0.0
	_has_demo = false
	_demo_still = false
	if _demo_rect != null:
		_demo_rect.texture = null
		_demo_rect.visible = true
	if _demo_placeholder != null:
		_demo_placeholder.visible = false
	if id.is_empty():
		_show_missing_demo()
		return

	var json_path: String = "%s/%s.json" % [demo_dir, id]
	var png_path: String = "%s/%s.png" % [demo_dir, id]
	var fps: float = DEFAULT_DEMO_FPS
	var frame_width: int = DEFAULT_DEMO_FRAME_WIDTH
	var frame_height: int = DEFAULT_DEMO_FRAME_HEIGHT
	if FileAccess.file_exists(json_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			var data: Dictionary = parsed as Dictionary
			fps = float(data.get("fps", fps))
			frame_width = int(data.get("frame_width", frame_width))
			frame_height = int(data.get("frame_height", frame_height))
	if fps <= 0.0:
		fps = DEFAULT_DEMO_FPS
	if frame_width <= 0 or frame_height <= 0:
		_show_missing_demo()
		return

	var texture: Texture2D = _load_demo_texture(png_path)
	if texture == null:
		_show_missing_demo()
		return
	# A non-strip texture (for example a single still) is shown as the first
	# frame, without animation and without an error.
	if texture.get_width() % frame_width != 0 or texture.get_height() != frame_height:
		_demo_rect.texture = texture
		_demo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_demo_still = true
		return
	var frames: int = texture.get_width() / frame_width
	if frames <= 0:
		_show_missing_demo()
		return
	_demo_atlas = AtlasTexture.new()
	_demo_atlas.atlas = texture
	_demo_atlas.region = Rect2(0.0, 0.0, float(frame_width), float(frame_height))
	_demo_rect.texture = _demo_atlas
	_demo_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_demo_rect.visible = true
	_demo_frames = frames
	_demo_fps = fps
	_has_demo = frames > 1
	_demo_still = not _has_demo


func _show_missing_demo() -> void:
	_demo_atlas = null
	_demo_frames = 0
	_has_demo = false
	_demo_still = false
	if _demo_rect != null:
		_demo_rect.texture = null
		_demo_rect.visible = false
	if _demo_placeholder != null:
		_demo_placeholder.visible = true


func _advance_demo(delta: float) -> void:
	if not _has_demo or _demo_frames <= 1 or _demo_fps <= 0.0:
		return
	_demo_time += delta
	var next_frame: int = int(_demo_time * _demo_fps)
	if next_frame == _demo_frame:
		return
	_demo_frame = next_frame % _demo_frames
	_demo_atlas.region = Rect2(
		float(_demo_frame) * _demo_atlas.region.size.x,
		0.0,
		_demo_atlas.region.size.x,
		_demo_atlas.region.size.y
	)


func _load_demo_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	# The capture tool may write a fresh PNG before the editor import pass.  A
	# direct read keeps the same page runnable in that window.
	var absolute: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return null
	var image: Image = Image.load_from_file(absolute)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


# --- Input cleanup ---------------------------------------------------------

func _clean_player_input() -> void:
	if level_node == null or not level_node.has_method("get_player"):
		return
	var player: Node = level_node.call("get_player") as Node
	if player != null:
		if player.has_method("reset_movement_input_state"):
			player.call("reset_movement_input_state")
		if player.has_method("clear_input_buffers"):
			player.call("clear_input_buffers")
		if player.has_method("clear_external_force"):
			player.call("clear_external_force")
	# Menu Enter/Space must not become a jump in the first frame after closing.
	LEVEL_FLOW.release_one_shot_actions()
