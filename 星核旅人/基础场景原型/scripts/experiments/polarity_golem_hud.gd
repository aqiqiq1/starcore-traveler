extends CanvasLayer

## Experiment-only HUD. It is intentionally separate from the shared
## PrototypeHUD so the two formal levels and their menus keep their layout
## untouched.
##
## Readability pass:
##   - every Chinese label uses the existing Fusion Pixel font at its native
##     12 logical px (the pause heading may use 24); nothing is shrunk to 7-10;
##   - top bar is 62 px tall, the two bottom panels are 46 px tall and start at
##     y=300, below the feet line at y=288, so the 288..360 ground strip holds
##     the full information block without covering either body;
##   - redundant lines (old "last result" / rubble note) are removed; transient
##     attack results stay in the top toast and in the golem's own feedback.

const WIDTH: float = 640.0
const HEIGHT: float = 360.0
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e9efeb")
const MUTED: Color = Color("#a8bbb7")
const DIM: Color = Color("#6f8582")
const RED: Color = Color("#ff7f72")
const ORANGE: Color = Color("#ffa94d")
const BLUE: Color = Color("#64c8ff")
const PANEL_BG: Color = Color(0.012, 0.025, 0.031, 0.84)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const NATIVE_FONT_SIZE: int = 12
const PAUSE_TITLE_SIZE: int = 24

var _root: Control
var _enemy_label: Label
var _enemy_state_label: Label
var _player_label: Label
var _attack_label: Label
var _toast_label: Label
var _toast_panel: Panel
var _pause_overlay: ColorRect
var _pause_reason_label: Label
var _toast_time: float = 0.0
var _paused: bool = false

static var _shared_font: FontFile = null
static var _font_checked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root = Control.new()
	_root.name = "PolarityGolemHUDRoot"
	_root.size = Vector2(WIDTH, HEIGHT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top_bar()
	_build_enemy_panel()
	_build_player_panel()
	_build_toast()
	_build_pause_overlay()
	set_player_polarity(true)
	set_enemy_status("活动", MUTED)
	set_attack_status("就绪")


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time = maxf(_toast_time - delta, 0.0)
		if _toast_time <= 0.0:
			_toast_label.visible = false
			_toast_panel.visible = false


func _build_top_bar() -> void:
	var panel: Panel = Panel.new()
	panel.position = Vector2.ZERO
	panel.size = Vector2(WIDTH, 62.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_bottom = 1
	style.border_color = Color(0.33, 0.52, 0.51, 0.55)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	_root.add_child(_label(
		"星核旅人 / 极性石怪训练场（独立实验）",
		Vector2(8.0, 3.0), Vector2(624.0, 16.0), NATIVE_FONT_SIZE, GOLD,
		HORIZONTAL_ALIGNMENT_LEFT, 1
	))
	_root.add_child(_label(
		"A/D 移动　Shift 跑　空格 跳跃　J 挥击　Q 切相　Tab 切敌相　R 重开　Esc 暂停",
		Vector2(8.0, 22.0), Vector2(624.0, 16.0), NATIVE_FONT_SIZE, TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, 0
	))
	_root.add_child(_label(
		"同相：扣血＋击退　异相：牵引无伤　每次挥击只结算一次",
		Vector2(8.0, 41.0), Vector2(624.0, 16.0), NATIVE_FONT_SIZE, MUTED,
		HORIZONTAL_ALIGNMENT_LEFT, 0
	))


func _build_enemy_panel() -> void:
	var panel: Panel = _make_panel(Vector2(8.0, 300.0), Vector2(306.0, 46.0), CYAN)
	_root.add_child(panel)
	_enemy_label = _label(
		"敌方　辉相 +　HP ●●●",
		Vector2(10.0, 3.0), Vector2(286.0, 16.0), NATIVE_FONT_SIZE, ORANGE,
		HORIZONTAL_ALIGNMENT_LEFT, 1
	)
	panel.add_child(_enemy_label)
	_enemy_state_label = _label(
		"状态：活动",
		Vector2(10.0, 23.0), Vector2(286.0, 16.0), NATIVE_FONT_SIZE, TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, 0
	)
	panel.add_child(_enemy_state_label)


func _build_player_panel() -> void:
	var panel: Panel = _make_panel(Vector2(326.0, 300.0), Vector2(306.0, 46.0), GOLD)
	_root.add_child(panel)
	_player_label = _label(
		"我方　辉相 +",
		Vector2(10.0, 3.0), Vector2(286.0, 16.0), NATIVE_FONT_SIZE, GOLD,
		HORIZONTAL_ALIGNMENT_LEFT, 1
	)
	panel.add_child(_player_label)
	_attack_label = _label(
		"J 挥击：就绪",
		Vector2(10.0, 23.0), Vector2(286.0, 16.0), NATIVE_FONT_SIZE, TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, 0
	)
	panel.add_child(_attack_label)


func _build_toast() -> void:
	_toast_panel = Panel.new()
	_toast_panel.position = Vector2(80.0, 64.0)
	_toast_panel.size = Vector2(480.0, 22.0)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.031, 0.86)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.33, 0.52, 0.51, 0.55)
	_toast_panel.add_theme_stylebox_override("panel", style)
	_toast_panel.visible = false
	_root.add_child(_toast_panel)
	_toast_label = _label(
		"", Vector2(80.0, 65.0), Vector2(480.0, 18.0), NATIVE_FONT_SIZE, GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, 1
	)
	_toast_label.visible = false
	_root.add_child(_toast_label)


func _build_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.position = Vector2.ZERO
	_pause_overlay.size = Vector2(WIDTH, HEIGHT)
	_pause_overlay.color = Color(0.008, 0.016, 0.02, 0.66)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	_root.add_child(_pause_overlay)

	var panel: Panel = _make_panel(Vector2(170.0, 118.0), Vector2(300.0, 124.0), CYAN)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(panel)
	var title: Label = _label(
		"已暂停", Vector2(0.0, 10.0), Vector2(300.0, 32.0), PAUSE_TITLE_SIZE, GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, 1
	)
	panel.add_child(title)
	var resume: Label = _label(
		"Esc 继续　R 重开实验", Vector2(0.0, 52.0), Vector2(300.0, 18.0),
		NATIVE_FONT_SIZE, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 0
	)
	panel.add_child(resume)
	_pause_reason_label = _label(
		"物理、攻击计时与重组倒计时已冻结",
		Vector2(0.0, 78.0), Vector2(300.0, 18.0), NATIVE_FONT_SIZE, MUTED,
		HORIZONTAL_ALIGNMENT_CENTER, 0
	)
	panel.add_child(_pause_reason_label)


func _make_panel(pos: Vector2, size: Vector2, border_color: Color) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = pos
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(
	text: String,
	pos: Vector2,
	box_size: Vector2,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment,
	outline_size: int
) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.size = box_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	var font: Font = _get_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.025, 0.95))
		label.add_theme_constant_override("outline_size", outline_size)
	return label


func set_player_polarity(positive: bool) -> void:
	_player_label.text = "我方　辉相 +" if positive else "我方　澜相 -"
	_player_label.add_theme_color_override("font_color", GOLD if positive else CYAN)


func set_enemy_status(text: String, color: Color) -> void:
	_enemy_state_label.text = "状态：%s" % text
	_enemy_state_label.add_theme_color_override("font_color", color)


func set_enemy_polarity(positive: bool, hp: int, max_hp: int) -> void:
	var pips: String = ""
	for index: int in range(max_hp):
		pips += "●" if index < hp else "○"
	_enemy_label.text = "敌方　%s　HP %s" % [
		"辉相 +" if positive else "澜相 -", pips
	]
	_enemy_label.add_theme_color_override("font_color", ORANGE if positive else BLUE)


func set_attack_status(text: String) -> void:
	_attack_label.text = "J 挥击：%s" % text


func show_toast(text: String, color: Color) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_label.visible = true
	_toast_panel.visible = true
	_toast_time = 1.8


func set_pause_visible(value: bool, reason: String = "") -> void:
	_paused = value
	_pause_overlay.visible = value
	if value:
		_pause_reason_label.text = (
			reason if not reason.is_empty() else "物理、攻击计时与重组倒计时已冻结"
		)
		_pause_reason_label.add_theme_color_override(
			"font_color", RED if not reason.is_empty() else MUTED
		)


func get_native_font_size() -> int:
	return NATIVE_FONT_SIZE


## Read-only audit helper: no experiment label may use a shrunken 7-10 px size.
func get_label_font_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for node: Node in _root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null:
			sizes.append(label.get_theme_font_size("font_size"))
	return sizes


func get_enemy_text() -> String:
	return _enemy_label.text


func get_enemy_state_text() -> String:
	return _enemy_state_label.text


func get_player_text() -> String:
	return _player_label.text


func get_attack_text() -> String:
	return _attack_label.text


func get_toast_text() -> String:
	return _toast_label.text


func is_toast_visible() -> bool:
	return _toast_label.visible


func is_pause_visible() -> bool:
	return _paused


func get_pause_reason_text() -> String:
	return _pause_reason_label.text


static func _get_font() -> FontFile:
	if _font_checked:
		return _shared_font
	_font_checked = true
	if not ResourceLoader.exists(FONT_PATH):
		return null
	var base: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if base == null:
		return null
	var font: FontFile = base.duplicate() as FontFile
	if font != null:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.allow_system_fallback = false
		font.oversampling = 1.0
		_shared_font = font
	else:
		_shared_font = base
	return _shared_font
