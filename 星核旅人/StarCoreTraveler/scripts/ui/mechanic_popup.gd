class_name MechanicPopup
extends CanvasLayer

## Reusable one-shot mechanic teaching popup.
##
## Teaches one mechanism with a real captured 256x144 loop on the left and a
## short what / which key / what happens text on the right. It only freezes the
## tree while open; it never changes level rules, collision, values or dialogue.
##
## Input while open:
##   F                 close
##   Space (tap)       inert
##   Space (0.5 s)     close with a 96x6 gold hold bar in the lower right
##   Esc               swallowed (the pause page is blocked by the level hook)
##
## See docs/MECHANIC_POPUP_SPEC.md. Visual language is copied from the approved
## pause page (2 px cyan-grey border, near-black fill, gold title, 12 px body).

signal closed(id: String)
signal opened(id: String)

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const PANEL_POSITION: Vector2 = Vector2(40.0, 62.0)
const PANEL_SIZE: Vector2 = Vector2(560.0, 236.0)
const DEMO_POSITION: Vector2 = Vector2(12.0, 12.0)
const DEMO_SIZE: Vector2 = Vector2(256.0, 144.0)
const RIGHT_X: float = 282.0
const RIGHT_WIDTH: float = 266.0
const SKIP_HOLD: float = 0.5

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DIM: Color = Color("#728889")
const PANEL_BG: Color = Color(0.014, 0.032, 0.040, 0.96)
const PANEL_BORDER: Color = Color(0.45, 0.66, 0.63, 0.9)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const DEMO_DIR: String = "res://assets/mechanic_demos"
## Shared capture format. The JSON beside each strip is documentation/evidence;
## the exported build must still play when only the imported PNG is packed.
const DEFAULT_DEMO_FRAME_WIDTH: int = 256
const DEFAULT_DEMO_FPS: float = 8.0

## All player-facing copy lives here so the six/five entries stay editable in
## one place. The wording only restates behaviour that already exists.
const TIPS: Dictionary = {
	"polarity": {
		"title": "相性 / 符石",
		"body": "同相推开，异相拉近。\n换相借力，用符石之力上高台、越坑。",
		"key": "站在符石旁按 {Q} 换相，就能借力。",
	},
	"core_carry": {
		"title": "运核入仓",
		"body": "取核后，核会变成与你相反的相性。\n借换相调节距离，把核送进空仓。",
		"key": "按 {E} 取核或入仓，换相能调节距离。",
	},
	"relay_link": {
		"title": "联动仓解锁",
		"body": "中继仓入仓后，力线可以穿过石墙。\n把核送入联动仓，符石会记住它的颜色。",
		"key": "按 {E} 把核送入联动仓，再借符石之力上高台。",
	},
	"float_platform": {
		"title": "浮地装置",
		"body": "启动装置后，石板升起并限时支撑。\n踩上后约 1 秒开始松动，别停太久。",
		"key": "按 {E} 启动装置，让它重新浮起。",
	},
	"guard_field": {
		"pages": [
			{
				"title": "守卫吸附 · 无效伤害",
				"body": "蓄力时异相被吸近、同相被弹开。\n异相普通攻击只碎壳、立刻重组，不计伤害。",
				"key": "被吸近还是被弹开，取决于相性是否相反。",
				"demo": "guard_invalid",
			},
			{
				"title": "守卫 · 有效伤害",
				"body": "趁蓄力被吸近，用攻击命中胸口弱点。\n命中 1 点真伤后守卫换相。\n再换成异相；累计 3 点。",
				"key": "贴身后按 {J} 命中弱点，命中后换回异相。",
				"demo": "guard_valid",
			},
		],
	},
}

## DLC chapters register their own tips once per launch. The base table above is
## never edited; ids are global, so a chapter may also reuse a base tip. The
## optional demo directory applies to the registered ids only, which keeps
## res://assets/mechanic_demos for the base three levels.
static var _extra_tips: Dictionary = {}
static var _extra_demo_dirs: Dictionary = {}


static func register_tips(entries: Dictionary, demo_dir_override: String = "") -> void:
	for raw_id: Variant in entries.keys():
		var id: String = String(raw_id)
		var data: Variant = entries[raw_id]
		if id.is_empty() or not (data is Dictionary):
			continue
		_extra_tips[id] = data
		if not demo_dir_override.is_empty():
			_extra_demo_dirs[id] = demo_dir_override


static func get_registered_tip_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in _extra_tips.keys():
		ids.append(String(key))
	ids.sort()
	return ids


## Test-only; a normal run never clears the registered table.
static func reset_registered_tips_for_test() -> void:
	_extra_tips.clear()
	_extra_demo_dirs.clear()


func _has_tip(id: String) -> bool:
	return TIPS.has(id) or _extra_tips.has(id)


func _tip(id: String) -> Dictionary:
	if TIPS.has(id):
		return TIPS[id] as Dictionary
	if _extra_tips.has(id):
		return _extra_tips[id] as Dictionary
	return {}


## Set by the owning level before add_child().
var level_node: Node = null
## Overridable only so the acceptance harness can exercise the real missing-file
## path without touching the approved asset directory.
var demo_dir: String = DEMO_DIR

var _root: Control = null
var _shade: ColorRect = null
var _panel: Panel = null
var _demo_border: Panel = null
var _demo_rect: TextureRect = null
var _demo_atlas: AtlasTexture = null
var _title_label: Label = null
var _body_label: Label = null
## Key/footer rows render inline keycaps, so they are RichTextLabel while the
## title/body stay plain Labels.  Tests read plain copy.
var _key_label: RichTextLabel = null
var _divider: ColorRect = null
var _page_indicator: Label = null
var _footer_label: RichTextLabel = null
var _key_raw: String = ""
var _footer_raw: String = ""
var _skip_bar: SkipHoldBar = null
var _font: Font = null
var _reveal: UiReveal = null

var _open: bool = false
var _current_id: String = ""
var _page_index: int = 0
var _page_count: int = 1
var _queue: Array[String] = []
var _paused_before: bool = false
var _space_armed: bool = false
var _space_hold: float = 0.0
var _demo_frames: int = 0
var _demo_fps: float = 8.0
var _demo_frame: int = 0
var _demo_time: float = 0.0
var _current_demo_id: String = ""
var _has_demo: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 14
	_font = _load_font()
	_build_ui()
	_reveal = UiReveal.new()
	_reveal.setup(self, _root, _shade, _panel, PANEL_POSITION)
	_root.visible = false
	set_process(true)


# --- Public API ------------------------------------------------------------

func is_open() -> bool:
	return _open


## Shared reveal state for tests/audits; gameplay never waits on it.
func get_reveal() -> UiReveal:
	return _reveal


func get_current_id() -> String:
	return _current_id


func get_page_index() -> int:
	return _page_index


func get_page_count() -> int:
	return _page_count


func get_page_indicator_text() -> String:
	if _page_indicator == null or not _page_indicator.visible:
		return ""
	return _page_indicator.text


func has_demo() -> bool:
	return _has_demo


func get_demo_frame_count() -> int:
	return _demo_frames


func get_demo_id() -> String:
	return _current_demo_id


func get_demo_frame() -> int:
	return _demo_frame


func get_skip_progress() -> float:
	return clampf(_space_hold / SKIP_HOLD, 0.0, 1.0)


func get_title_text() -> String:
	return _title_label.text if _title_label != null else ""


func get_body_text() -> String:
	return _body_label.text if _body_label != null else ""


## Plain copy for tests/logs: {Q}/{J}/{E}/{F} become Q/J/E/F, never [img].
func get_key_text() -> String:
	return KeyGlyph.plain(_key_raw)


func get_footer_text() -> String:
	return KeyGlyph.plain(_footer_raw)


## Rendered BBCode; harnesses can assert the inline keycap is really present.
func get_key_rich_text() -> String:
	return _key_label.text if _key_label != null else ""


func get_footer_rich_text() -> String:
	return _footer_label.text if _footer_label != null else ""


func is_skip_bar_visible() -> bool:
	return _skip_bar != null and _skip_bar.visible


func get_queued_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_queue)
	return ids


## Called by a level when its real trigger condition is satisfied. A request
## made while another popup is open is queued; a blocked request is retried by
## the level on later ticks.
func request(id: String) -> void:
	if not _has_tip(id) or MechanicTips.has_seen(id):
		return
	if _open:
		if id != _current_id and not _queue.has(id):
			_queue.append(id)
		return
	open(id)


func open(id: String) -> bool:
	return _open_internal(id, false)


## Test-only entry that ignores the run-scoped seen record. It still respects
## the live open/blocker rules.
func open_for_test(id: String) -> bool:
	return _open_internal(id, true)


func _open_internal(id: String, ignore_seen: bool) -> bool:
	if _open:
		return false
	if not _has_tip(id):
		return false
	if not ignore_seen and MechanicTips.has_seen(id):
		return false
	if get_tree() == null or get_tree().paused:
		return false
	if level_node != null and level_node.has_method("is_mechanic_popup_blocked"):
		if bool(level_node.call("is_mechanic_popup_blocked")):
			return false

	_current_id = id
	_page_index = 0
	_page_count = _page_count_for(id)
	_open = true
	_paused_before = get_tree().paused
	MechanicTips.mark_seen(id)
	get_tree().paused = true
	_apply_page()
	_load_demo(id, _page_demo_id(id, 0))
	_reset_space_state()
	_clean_player_input()
	_root.visible = true
	if _reveal != null:
		_reveal.play_open()
	opened.emit(id)
	return true


func close() -> void:
	if not _open:
		return
	var closed_id: String = _current_id
	# State and pause are released before the 0.12 s exit fade.
	_open = false
	get_tree().paused = _paused_before
	_space_hold = 0.0
	_space_armed = false
	if _skip_bar != null:
		_skip_bar.hide_progress()
	if _reveal != null:
		_reveal.play_close()
	else:
		_root.visible = false
	_current_id = ""
	_clean_player_input()
	closed.emit(closed_id)


# --- Input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo:
		var code: int = int(key_event.physical_keycode)
		if code == 0:
			code = int(key_event.keycode)
		if code == KEY_F:
			_advance_page()
			get_viewport().set_input_as_handled()
			return
	# Esc, Space and every other gameplay key stay inside the popup.
	get_viewport().set_input_as_handled()


# --- Page / process --------------------------------------------------------

func _advance_page() -> void:
	if not _open:
		return
	if _page_index + 1 < _page_count:
		_page_index += 1
		_apply_page()
		_load_demo(_current_id, _page_demo_id(_current_id, _page_index))
		_space_hold = 0.0
		_space_armed = not Input.is_physical_key_pressed(KEY_SPACE)
		if _skip_bar != null:
			_skip_bar.hide_progress()
		return
	close()


func _page_count_for(id: String) -> int:
	var tip: Dictionary = _tip(id)
	if tip.has("pages"):
		var pages: Array = tip["pages"] as Array
		return maxi(pages.size(), 1)
	return 1


func _page_data(id: String, index: int) -> Dictionary:
	var tip: Dictionary = _tip(id)
	if tip.has("pages"):
		var pages: Array = tip["pages"] as Array
		if index >= 0 and index < pages.size():
			return pages[index] as Dictionary
		return {}
	return tip


func _page_demo_id(id: String, index: int) -> String:
	var data: Dictionary = _page_data(id, index)
	return String(data.get("demo", id))


func _apply_page() -> void:
	var data: Dictionary = _page_data(_current_id, _page_index)
	_title_label.text = String(data.get("title", ""))
	_body_label.text = String(data.get("body", ""))
	_key_raw = String(data.get("key", ""))
	_key_label.text = KeyGlyph.decorate(_key_raw)
	if _footer_label != null:
		if _page_count <= 1:
			_footer_raw = "{F} 继续 · 长按空格 跳过"
		elif _page_index + 1 < _page_count:
			_footer_raw = "{F} 下一页 · 长按空格 跳过"
		else:
			_footer_raw = "{F} 关闭 · 长按空格 跳过"
		_footer_label.text = KeyGlyph.decorate(_footer_raw)
	if _page_indicator != null:
		_page_indicator.visible = _page_count > 1
		_page_indicator.text = "%d / %d" % [_page_index + 1, _page_count]


func _process(delta: float) -> void:
	if not _open:
		_maybe_open_queued()
		return

	_advance_demo(delta)
	_tick_space_hold(delta)


func _maybe_open_queued() -> void:
	if _queue.is_empty():
		return
	var id: String = _queue[0]
	if MechanicTips.has_seen(id):
		_queue.pop_front()
		return
	if open(id):
		_queue.pop_front()


func _tick_space_hold(delta: float) -> void:
	var pressed: bool = Input.is_physical_key_pressed(KEY_SPACE)
	if not _space_armed:
		if not pressed:
			_space_armed = true
		if _skip_bar != null:
			_skip_bar.update_hold(false, 0.0, SKIP_HOLD)
		return
	if not pressed:
		if _space_hold > 0.0:
			_space_hold = 0.0
			if _skip_bar != null:
				_skip_bar.hide_progress()
		return
	_space_hold = minf(_space_hold + delta, SKIP_HOLD)
	if _skip_bar != null:
		_skip_bar.update_hold(true, _space_hold, SKIP_HOLD)
	if _space_hold >= SKIP_HOLD:
		# A long hold closes the whole popup; it never turns a page.
		close()


func _reset_space_state() -> void:
	_space_hold = 0.0
	# A Space already held when the popup opens must be released once, so the
	# opening state cannot count as a skip hold.
	_space_armed = not Input.is_physical_key_pressed(KEY_SPACE)
	if _skip_bar != null:
		_skip_bar.hide_progress()


# --- Demo ------------------------------------------------------------------

func _advance_demo(delta: float) -> void:
	if not _has_demo or _demo_frames <= 1:
		return
	_demo_time += delta
	var next_frame: int = int(_demo_time * _demo_fps)
	if next_frame == _demo_frame:
		return
	_demo_frame = next_frame % _demo_frames
	_demo_atlas.region = Rect2(
		float(_demo_frame) * float(_demo_atlas.region.size.x),
		0.0,
		_demo_atlas.region.size.x,
		_demo_atlas.region.size.y
	)


func _load_demo(_id: String, demo_id: String) -> void:
	_current_demo_id = demo_id
	_has_demo = false
	_demo_frames = 0
	_demo_fps = 8.0
	_demo_frame = 0
	_demo_time = 0.0
	_demo_atlas = null
	_demo_rect.texture = null
	_set_full_width_layout(true)

	var resolved_demo_dir: String = String(_extra_demo_dirs.get(_id, demo_dir))
	var json_path: String = "%s/%s.json" % [resolved_demo_dir, demo_id]
	var png_path: String = "%s/%s.png" % [resolved_demo_dir, demo_id]
	var fps: float = DEFAULT_DEMO_FPS
	var frame_width: int = DEFAULT_DEMO_FRAME_WIDTH
	var frame_height: int = 0
	if FileAccess.file_exists(json_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			var data: Dictionary = parsed as Dictionary
			fps = float(data.get("fps", fps))
			frame_width = int(data.get("frame_width", frame_width))
			frame_height = int(data.get("frame_height", 0))
	if fps <= 0.0 or frame_width <= 0:
		return
	var texture: Texture2D = _load_demo_texture(png_path)
	if texture == null:
		return
	# The strip itself owns the frame count: width / 256. The JSON frames value
	# is documentation only, so a longer/shorter capture cannot desynchronise
	# the animation from its pixels.
	if texture.get_width() % frame_width != 0:
		return
	var frames: int = texture.get_width() / frame_width
	if frames <= 0:
		return
	if frame_height <= 0:
		frame_height = texture.get_height()
	if frame_height <= 0:
		return

	_demo_atlas = AtlasTexture.new()
	_demo_atlas.atlas = texture
	_demo_atlas.region = Rect2(0.0, 0.0, float(frame_width), float(frame_height))
	_demo_rect.texture = _demo_atlas
	_demo_frames = frames
	_demo_fps = fps
	_has_demo = true
	_set_full_width_layout(false)


func _load_demo_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	# The capture harness writes a fresh PNG before the editor import pass. This
	# direct read keeps the same frame runnable; a missing file simply degrades.
	var absolute: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return null
	var image: Image = Image.load_from_file(absolute)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _set_full_width_layout(missing: bool) -> void:
	_demo_border.visible = not missing
	_demo_rect.visible = not missing
	var x: float = 16.0 if missing else RIGHT_X
	var width: float = 528.0 if missing else RIGHT_WIDTH
	_title_label.position.x = x
	_title_label.size.x = width
	_body_label.position.x = x
	_body_label.size.x = width
	_key_label.position.x = x
	_key_label.size.x = width
	_divider.position.x = x
	_divider.size.x = width


# --- Pause / input cleanup -------------------------------------------------

func _clean_player_input() -> void:
	if level_node == null or not level_node.has_method("get_player"):
		return
	var player: Node = level_node.call("get_player") as Node
	if player == null:
		return
	if player.has_method("clear_input_buffers"):
		player.call("clear_input_buffers")
	if player.has_method("clear_external_force"):
		player.call("clear_external_force")


# --- Build UI --------------------------------------------------------------

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


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MechanicPopupRoot"
	_root.position = Vector2.ZERO
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_shade = ColorRect.new()
	_shade.position = Vector2.ZERO
	_shade.size = VIEW_SIZE
	_shade.color = Color(0.006, 0.014, 0.018, 0.72)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_shade)

	_panel = Panel.new()
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
	style.set_corner_radius_all(2)
	style.anti_aliasing = false
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	# Left demo window: 1 px border frame first, then the exact 256x144 frame.
	_demo_border = Panel.new()
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
	_demo_rect.position = DEMO_POSITION
	_demo_rect.size = DEMO_SIZE
	_demo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_demo_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_demo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_demo_rect)

	_title_label = _label("", Vector2(RIGHT_X, 6.0), Vector2(RIGHT_WIDTH, 28.0), 24, GOLD)
	_panel.add_child(_title_label)

	_page_indicator = _label("", Vector2(486.0, 12.0), Vector2(62.0, 16.0), 12, MUTED)
	_page_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page_indicator.visible = false
	_panel.add_child(_page_indicator)

	_divider = ColorRect.new()
	_divider.position = Vector2(RIGHT_X, 36.0)
	_divider.size = Vector2(RIGHT_WIDTH, 1.0)
	_divider.color = Color(0.45, 0.66, 0.63, 0.35)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_divider)

	_body_label = _label("", Vector2(RIGHT_X, 43.0), Vector2(RIGHT_WIDTH, 58.0), 12, TEXT)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_body_label)

	_key_label = _rich_label(
		Vector2(RIGHT_X, 108.0), Vector2(RIGHT_WIDTH, 42.0), 12, CYAN
	)
	_key_label.name = "Key"
	_panel.add_child(_key_label)

	_footer_label = _rich_label(
		Vector2(16.0, 210.0), Vector2(400.0, 18.0), 12, DIM
	)
	_footer_label.name = "Footer"
	_footer_raw = "{F} 继续 · 长按空格 跳过"
	_footer_label.text = KeyGlyph.decorate(_footer_raw)
	_panel.add_child(_footer_label)

	# Shared hold-to-skip feedback (same 96x6 track, gold fill and 12 px label
	# as the approved cinematics). It sits at the logical viewport's lower-right,
	# below the panel, and never draws a second hand-rolled bar.
	_skip_bar = SkipHoldBar.new()
	_skip_bar.name = "SkipHoldBar"
	_root.add_child(_skip_bar)


func _label(
	text_value: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
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
	label.add_theme_constant_override("outline_size", 0)
	return label


## Key/footer row: same 12 px pixel font/colour, BBCode on so {Q}/{J}/{E}/{F}
## become inline 16x16 caps.  Fixed height, no scrolling, no fit-to-content.
func _rich_label(
	position_value: Vector2, size_value: Vector2, font_size: int, color: Color
) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.scroll_active = false
	label.fit_content = false
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _font != null:
		label.add_theme_font_override("normal_font", _font)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.006, 0.014, 0.018, 0.96))
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("line_separation", 3)
	return label
