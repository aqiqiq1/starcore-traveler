class_name DlcGuide
extends CanvasLayer

## Shared "how to clear this chapter" guide for the two DLC chapters.
##
## One 560x236 page at a time, opened once at level start by
## TrialChambers / RiftWorkshop (each level sets show_intro_guide = false before
## add_child() in the automated tests).  The left 160x90 window is a 1x pixel
## diagram drawn in code; the right side is title + 2-3 body lines + key hint.
##
## Input while open (the tree is paused):
##   F                 next page, close on the last page
##   Space (tap)       inert
##   Space (0.5 s)     close the whole guide, 96x6 gold hold bar lower-right
##   Esc               swallowed (no pause page, no gameplay key)
##
## Visual language is copied from the approved trial/rift HUD and the mechanic
## popup: near-black panel, 2 px cyan-grey border, gold title, 12 px body.
## No external art is added; the diagrams are draw_rect pixels only.

signal opened(kind: String)
signal closed(kind: String)

const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")
const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const PANEL_POSITION: Vector2 = Vector2(40.0, 62.0)
const PANEL_SIZE: Vector2 = Vector2(560.0, 236.0)
const DIAGRAM_POSITION: Vector2 = Vector2(12.0, 12.0)
const DIAGRAM_SIZE: Vector2 = Vector2(160.0, 90.0)
const RIGHT_X: float = 188.0
const RIGHT_WIDTH: float = 356.0
const SKIP_HOLD: float = 0.5

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
			"title": "目标：穿过两道极性门",
			"body": "从澜相出发：Q 换辉相过金门，再 Q 回澜相过青门。\n门后是守卫竞技场，击败守卫才会点亮完成点。",
			"key": "Q 换相 · 与门同相才能通过",
			"diagram": "gates",
		},
		{
			"title": "Q 换相与门内安全",
			"body": "门只读取你的相性：同相放行，异相拦停。\n站在门内切换相性不会被夹住，离开后门才重新闭合。",
			"key": "Q 切换辉相 / 澜相 · 门内切相不夹",
			"diagram": "gates",
		},
		{
			"title": "守卫战：异相 J 打弱点",
			"body": "守卫蓄力时保持异相，靠近后按 J 命中弱点。\n每次真伤后守卫换相，再按 Q 切回异相，累计 3 次。\n两次受击失败会回到竞技场入口，守卫重置。",
			"key": "J 攻击 · Q 保持异相",
			"diagram": "twins",
		},
	],
	"rift": [
		{
			"title": "路线：回廊 · 光桥 · 双生守卫",
			"body": "穿过紫色反转光幕与极性门，再按相性跨过三座光桥。\n高台尽头记录检查点，然后进入双生守卫竞技场。",
			"key": "Q 换相 · 紫色光幕会自动翻转相性",
			"diagram": "curtain",
		},
		{
			"title": "反转场与相性桥",
			"body": "进入紫色光幕会自动反转一次相性，停在幕内不会反复翻转。\n光桥只在与你同相时实体化；异相时桥面消失，会落到下层安全台。",
			"key": "Q 换相 · 与桥同色才能站上去",
			"diagram": "bridge",
		},
		{
			"title": "双生守卫：两只都要打",
			"body": "金守卫与青守卫都要打：蓄力时保持异相，按 J 命中弱点 3 次。\n每次真伤后守卫换相，需再按 Q 切回异相。\n两只都倒下才会打开裂隙核心；失败或坠落后两只都会完整重生。",
			"key": "J 命中弱点 · 每只 3 点真伤",
			"diagram": "twins",
		},
	],
}

## Set by the owning chapter before open_guide().
var level_node: Node = null
var guide_kind: String = ""

var _root: Control = null
var _panel: Panel = null
var _diagram: PixelDiagram = null
var _title_label: Label = null
var _body_label: Label = null
var _key_label: Label = null
var _footer_label: Label = null
var _page_indicator: Label = null
var _skip_bar: SkipHoldBar = null
var _font: Font = null

var _open: bool = false
var _page_index: int = 0
var _paused_before: bool = false
var _space_held: bool = false
var _space_hold: float = 0.0
var _space_armed: bool = false
var _open_count: int = 0


## 160x90 pixel diagram. Everything is an axis-aligned rect so it stays 1x and
## crisp under the project's nearest-neighbour scaling.
class PixelDiagram extends Control:
	const BG: Color = Color("#050b0e")
	const BORDER: Color = Color(0.45, 0.66, 0.63, 0.55)
	const FLOOR: Color = Color("#24323a")
	const FLOOR_LIGHT: Color = Color("#3a4f58")
	const GOLD: Color = Color("#f4cd63")
	const CYAN: Color = Color("#5fe1e6")
	const PURPLE: Color = Color("#b06ce8")
	const WHITE: Color = Color("#e7eceb")
	const DIM: Color = Color("#728889")

	var kind: String = ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		queue_redraw()

	func set_kind(value: String) -> void:
		kind = value
		queue_redraw()

	func _px(x: float, y: float, w: float, h: float, color: Color) -> void:
		draw_rect(Rect2(x, y, w, h), color)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BG)
		match kind:
			"gates":
				_draw_gates()
			"curtain":
				_draw_curtain()
			"bridge":
				_draw_bridge()
			"twins":
				_draw_twins()
		draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 1.0)

	func _draw_gates() -> void:
		# Floor and two gates: gold first, cyan second (the trial route).
		_px(8.0, 74.0, 144.0, 2.0, FLOOR)
		_px(52.0, 46.0, 6.0, 28.0, GOLD)
		_px(54.0, 50.0, 2.0, 20.0, Color(GOLD, 0.55))
		_px(100.0, 46.0, 6.0, 28.0, CYAN)
		_px(102.0, 50.0, 2.0, 20.0, Color(CYAN, 0.55))
		# Start player (澜相) + forward hint.
		_px(28.0, 62.0, 6.0, 10.0, CYAN)
		_px(30.0, 58.0, 2.0, 4.0, CYAN)
		_px(37.0, 63.0, 8.0, 1.0, WHITE)
		_px(43.0, 60.0, 2.0, 2.0, WHITE)
		_px(43.0, 66.0, 2.0, 2.0, WHITE)
		# Dotted path between the gates.
		for index: int in range(5):
			_px(66.0 + float(index) * 6.0, 72.0, 2.0, 2.0, DIM)
		# Dim finish core beyond the second gate.
		_px(128.0, 64.0, 6.0, 8.0, Color(GOLD, 0.55))
		_px(130.0, 62.0, 2.0, 2.0, WHITE)

	func _draw_curtain() -> void:
		# Purple inversion curtain with two 1 px edges and alternating bands.
		_px(8.0, 74.0, 144.0, 2.0, FLOOR)
		_px(67.0, 18.0, 1.0, 58.0, BORDER)
		_px(78.0, 18.0, 1.0, 58.0, BORDER)
		for index: int in range(10):
			var alpha: float = 0.72 if index % 2 == 0 else 0.34
			_px(69.0, 22.0 + float(index) * 5.0, 8.0, 3.0, Color(PURPLE, alpha))
		# Player before the curtain (澜相) and after it (辉相).
		_px(44.0, 62.0, 6.0, 10.0, CYAN)
		_px(46.0, 58.0, 2.0, 4.0, CYAN)
		_px(94.0, 62.0, 6.0, 10.0, GOLD)
		_px(96.0, 58.0, 2.0, 4.0, GOLD)
		_px(53.0, 63.0, 10.0, 1.0, WHITE)
		_px(60.0, 60.0, 2.0, 2.0, WHITE)
		_px(60.0, 66.0, 2.0, 2.0, WHITE)
		_px(84.0, 63.0, 7.0, 1.0, WHITE)
		_px(89.0, 60.0, 2.0, 2.0, WHITE)
		_px(89.0, 66.0, 2.0, 2.0, WHITE)

	func _draw_bridge() -> void:
		# Left / right stone landings, three alternating decks, safe lower shelf.
		_px(8.0, 74.0, 144.0, 2.0, FLOOR)
		_px(10.0, 62.0, 38.0, 12.0, FLOOR)
		_px(10.0, 60.0, 38.0, 2.0, FLOOR_LIGHT)
		_px(112.0, 62.0, 38.0, 12.0, FLOOR)
		_px(112.0, 60.0, 38.0, 2.0, FLOOR_LIGHT)
		_px(48.0, 60.0, 20.0, 3.0, GOLD)
		_px(70.0, 60.0, 20.0, 3.0, CYAN)
		_px(92.0, 60.0, 20.0, 3.0, GOLD)
		# Standing player on the first gold deck.
		_px(54.0, 48.0, 6.0, 10.0, CYAN)
		_px(56.0, 44.0, 2.0, 4.0, CYAN)
		# Lower safe shelf under the gap.
		_px(48.0, 80.0, 64.0, 1.0, Color(DIM, 0.8))
		for index: int in range(5):
			_px(52.0 + float(index) * 14.0, 77.0, 2.0, 2.0, Color(DIM, 0.55))

	func _draw_twins() -> void:
		# Two guard colour blocks with three health cells each, player between.
		_px(8.0, 74.0, 144.0, 2.0, FLOOR)
		_px(42.0, 46.0, 24.0, 28.0, Color(0.10, 0.09, 0.05, 1.0))
		_px(44.0, 48.0, 20.0, 24.0, GOLD)
		_px(49.0, 54.0, 10.0, 12.0, Color(0.10, 0.09, 0.05, 1.0))
		_px(52.0, 58.0, 4.0, 4.0, WHITE)
		_px(94.0, 46.0, 24.0, 28.0, Color(0.03, 0.08, 0.10, 1.0))
		_px(96.0, 48.0, 20.0, 24.0, CYAN)
		_px(101.0, 54.0, 10.0, 12.0, Color(0.03, 0.08, 0.10, 1.0))
		_px(104.0, 58.0, 4.0, 4.0, WHITE)
		for index: int in range(3):
			_px(44.0 + float(index) * 8.0, 38.0, 5.0, 3.0, Color(GOLD, 0.85))
			_px(96.0 + float(index) * 8.0, 38.0, 5.0, 3.0, Color(CYAN, 0.85))
		# Player with a J spark between the two guards.
		_px(76.0, 60.0, 6.0, 12.0, WHITE)
		_px(78.0, 56.0, 2.0, 4.0, WHITE)
		_px(72.0, 64.0, 4.0, 1.0, GOLD)
		_px(82.0, 64.0, 4.0, 1.0, CYAN)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_font = _load_font()
	_build_ui()
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

	var shade: ColorRect = ColorRect.new()
	shade.name = "Shade"
	shade.position = Vector2.ZERO
	shade.size = VIEW_SIZE
	shade.color = Color(0.006, 0.014, 0.018, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

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

	var diagram_border: Panel = Panel.new()
	diagram_border.name = "DiagramBorder"
	diagram_border.position = DIAGRAM_POSITION - Vector2.ONE
	diagram_border.size = DIAGRAM_SIZE + Vector2(2.0, 2.0)
	diagram_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var diagram_style: StyleBoxFlat = StyleBoxFlat.new()
	diagram_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	diagram_style.border_width_left = 1
	diagram_style.border_width_top = 1
	diagram_style.border_width_right = 1
	diagram_style.border_width_bottom = 1
	diagram_style.border_color = Color(0.45, 0.66, 0.63, 0.75)
	diagram_style.anti_aliasing = false
	diagram_border.add_theme_stylebox_override("panel", diagram_style)
	_panel.add_child(diagram_border)

	_diagram = PixelDiagram.new()
	_diagram.name = "Diagram"
	_diagram.position = DIAGRAM_POSITION
	_diagram.size = DIAGRAM_SIZE
	_panel.add_child(_diagram)

	_title_label = _label("", Vector2(RIGHT_X, 13.0), Vector2(274.0, 20.0), 16, GOLD)
	_title_label.name = "Title"
	_panel.add_child(_title_label)

	_page_indicator = _label("", Vector2(470.0, 12.0), Vector2(74.0, 16.0), 12, MUTED)
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

	_body_label = _label("", Vector2(RIGHT_X, 44.0), Vector2(RIGHT_WIDTH, 64.0), 12, TEXT)
	_body_label.name = "Body"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_body_label)

	_key_label = _label("", Vector2(RIGHT_X, 112.0), Vector2(RIGHT_WIDTH, 40.0), 12, CYAN)
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


func get_diagram_kind() -> String:
	return _diagram.kind if _diagram != null else ""


func get_diagram_size() -> Vector2:
	return _diagram.size if _diagram != null else Vector2.ZERO


func get_panel_rect() -> Rect2:
	return Rect2(PANEL_POSITION, PANEL_SIZE)


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
	_clean_player_input()
	opened.emit(guide_kind)
	return true


func close() -> void:
	if not _open:
		return
	var closed_kind: String = guide_kind
	_open = false
	_root.visible = false
	get_tree().paused = _paused_before
	_space_held = false
	_space_hold = 0.0
	_space_armed = false
	if _skip_bar != null:
		_skip_bar.hide_progress()
	_clean_player_input()
	closed.emit(closed_kind)


func _exit_tree() -> void:
	# A scene change while the guide is open must not leave the tree paused.
	if _open and get_tree() != null:
		get_tree().paused = _paused_before
		_open = false


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
	_diagram.set_kind(String(data.get("diagram", "")))
	var count: int = get_page_count()
	_page_indicator.text = "%d / %d" % [_page_index + 1, count]
	_footer_label.text = (
		"F 下一页 · 长按空格 跳过"
		if _page_index + 1 < count
		else "F 关闭 · 长按空格 跳过"
	)


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
