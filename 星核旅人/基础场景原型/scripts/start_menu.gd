class_name StartMenu
extends CanvasLayer

## In-level start menu and opening transition for 星核旅人 level 01.
##
## The menu is not a separate home scene: it lives in level_01.tscn as a
## CanvasLayer above the real world. The DS03 background is a screen-fixed
## CanvasLayer and keeps animating while the menu/settings are shown. Starting
## fades the approved V1 UI, reveals the real World under a temporary
## unconstrained Camera2D and pans that camera down to the normal player camera
## position. Only then does level_01.gd run the existing intro auto-run.
##
## Everything here is runtime UI: the approved V1 overlay is baked into static
## 640x360 UI textures (no background pixels) and real Button/Slider hot spots
## sit on top. No system font is used for the title or entries.

signal menu_activated
signal start_requested
signal quit_requested
signal transition_finished
signal settings_host_closed

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DIM: Color = Color("#728889")
const PANEL_BG: Color = Color(0.014, 0.032, 0.040, 0.96)
const PANEL_BORDER: Color = Color(0.45, 0.66, 0.63, 0.9)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

const UI_BASE: Texture2D = preload("res://assets/menu/main_menu_ui_640.png")
const UI_FOCUS_START: Texture2D = preload("res://assets/menu/main_menu_focus_start_640.png")
const UI_FOCUS_SETTINGS: Texture2D = preload("res://assets/menu/main_menu_focus_settings_640.png")
const UI_QUIT: Texture2D = preload("res://assets/menu/main_menu_quit_640.png")
const UI_FOCUS_QUIT: Texture2D = preload("res://assets/menu/main_menu_focus_quit_640.png")
const UI_SETTINGS: Texture2D = preload("res://assets/menu/settings_panel_640.png")
const UI_SETTINGS_RETURN_FOCUS: Texture2D = preload("res://assets/menu/settings_return_focus_640.png")

const START_RECT: Rect2 = Rect2(256.0, 138.0, 128.0, 36.0)
const SETTINGS_RECT: Rect2 = Rect2(294.0, 184.0, 52.0, 20.0)
const QUIT_RECT: Rect2 = Rect2(284.0, 212.0, 72.0, 20.0)
const RETURN_RECT: Rect2 = Rect2(324.0, 262.0, 144.0, 24.0)
const SLIDER_RECT: Rect2 = Rect2(172.0, 92.0, 296.0, 16.0)
const PERCENT_RECT: Rect2 = Rect2(386.0, 74.0, 80.0, 14.0)
const MODE_WINDOW_RECT: Rect2 = Rect2(250.0, 124.0, 86.0, 22.0)
const MODE_FULLSCREEN_RECT: Rect2 = Rect2(344.0, 124.0, 86.0, 22.0)
const RES_640_RECT: Rect2 = Rect2(172.0, 176.0, 144.0, 22.0)
const RES_1280_RECT: Rect2 = Rect2(324.0, 176.0, 144.0, 22.0)
const RES_1920_RECT: Rect2 = Rect2(172.0, 202.0, 144.0, 22.0)
const RES_2560_RECT: Rect2 = Rect2(324.0, 202.0, 144.0, 22.0)
const APPLY_RECT: Rect2 = Rect2(172.0, 262.0, 144.0, 24.0)
const DISPLAY_NOTE_RECT: Rect2 = Rect2(172.0, 230.0, 296.0, 14.0)
const STATUS_RECT: Rect2 = Rect2(172.0, 292.0, 296.0, 14.0)
const PENDING_PANEL_RECT: Rect2 = Rect2(150.0, 100.0, 340.0, 150.0)
const PENDING_CONFIRM_RECT: Rect2 = Rect2(166.0, 190.0, 140.0, 26.0)
const PENDING_CANCEL_RECT: Rect2 = Rect2(334.0, 190.0, 140.0, 26.0)

const MASTER_BUS_NAME: StringName = &"Master"
const DEFAULT_AUDIO_PATH: String = "user://audio_settings.cfg"
const DEFAULT_DISPLAY_PATH: String = "user://display_settings.cfg"

enum Phase { INACTIVE, MENU, TITLE_FADE, CAMERA_PAN, SETTLE, ENTRY, DONE }

@export var audio_settings_path: String = DEFAULT_AUDIO_PATH
@export var display_settings_path: String = DEFAULT_DISPLAY_PATH
## Pause-menu hosting: reuse this exact settings panel (master volume + display
## apply/confirm/timeout) without activating the title menu, world hiding,
## MenuCamera or the 2.2 s opening pan.  The pause page sets this before
## add_child().
@export var settings_host_mode: bool = false

var _level: Node = null
var _menu_camera: Camera2D = null
var _player_camera: Camera2D = null
var _world: Node2D = null
var _player: Node2D = null
var _hud: CanvasLayer = null
var _font: Font = null

var _root: Control = null
var _fade_group: Control = null
var _base_rect: TextureRect = null
var _focus_start_rect: TextureRect = null
var _focus_settings_rect: TextureRect = null
var _quit_row_rect: TextureRect = null
var _focus_quit_rect: TextureRect = null
var _start_button: Button = null
var _settings_button: Button = null
var _quit_button: Button = null

var _settings_layer: Control = null
var _settings_return_focus_rect: TextureRect = null
var _return_button: Button = null
var _slider: PixelVolumeSlider = null
var _percent_label: Label = null
var _display: DisplaySettingsController = null
var _display_mode_window: PixelMenuButton = null
var _display_mode_fullscreen: PixelMenuButton = null
var _resolution_buttons: Dictionary = {}
var _apply_button: PixelMenuButton = null
var _display_note_label: Label = null
var _display_status_label: Label = null
var _pending_overlay: Control = null
var _pending_countdown_label: Label = null
var _pending_confirm_button: PixelMenuButton = null
var _pending_cancel_button: PixelMenuButton = null
var _draft_mode: int = DisplayOptions.Mode.WINDOWED
var _draft_window_size: Vector2i = DisplayOptions.DEFAULT_WINDOW_SIZE

var _pause_overlay: Control = null

var _phase: int = Phase.INACTIVE
var _settings_open: bool = false
var _start_locked: bool = false
var _quit_locked: bool = false
var _hover_kind: String = ""
var _transition_paused: bool = false
var _sequence: Tween = null
var _end_center: Vector2 = Vector2.ZERO
var _start_request_count: int = 0
var _volume_percent: int = 100
var _master_bus_index: int = -1
var _stele_prompt_layers: Array[CanvasLayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_font = _load_font()
	_display = DisplaySettingsController.new()
	_display.name = "DisplaySettings"
	add_child(_display)
	var apply_display: bool = true
	var parent: Node = get_parent()
	if parent != null and parent.has_method("is_start_menu_enabled"):
		apply_display = bool(parent.call("is_start_menu_enabled"))
	_display.initialize(get_window(), display_settings_path, apply_display)
	_build_ui()
	_display.pending_cancelled.connect(_on_display_pending_cancelled)
	_root.visible = false
	get_window().focus_exited.connect(_on_window_focus_exited)


func _process(_delta: float) -> void:
	if _display != null and _display.is_pending() and _pending_overlay != null and _pending_overlay.visible:
		_update_pending_countdown()


func activate(level: Node, menu_camera: Camera2D) -> void:
	if _phase != Phase.INACTIVE:
		return
	_level = level
	_menu_camera = menu_camera
	_world = _level.get_node("World") as Node2D
	_player = _world.get_node("Player") as Node2D
	_player_camera = _player.get_node("Camera2D") as Camera2D
	_hud = _level.get_node("HUD") as CanvasLayer

	get_tree().paused = false
	_phase = Phase.MENU
	_start_locked = false
	_quit_locked = false
	_settings_open = false
	_hover_kind = ""
	_root.visible = true
	_fade_group.visible = true
	_fade_group.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_start_button.disabled = false
	_settings_button.disabled = false
	_quit_button.disabled = false
	_settings_layer.visible = false
	_pending_overlay.visible = false
	_pause_overlay.visible = false
	_refresh_focus_overlays()
	_load_audio_settings()

	_player_camera.enabled = false
	_menu_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_menu_camera.position_smoothing_enabled = false
	_menu_camera.position = Vector2(
		_compute_player_camera_center().x,
		float(_level.get("menu_camera_start_position").y)
	)
	_menu_camera.enabled = true
	_menu_camera.make_current()

	_world.visible = false
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_player.visible = false
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.visible = false
	_set_stele_prompts_visible(false)

	call_deferred("_focus_start")
	menu_activated.emit()


# --- Public state / test accessors ----------------------------------------

func get_phase() -> int:
	return _phase


func get_phase_name() -> String:
	match _phase:
		Phase.INACTIVE:
			return "inactive"
		Phase.MENU:
			return "menu"
		Phase.TITLE_FADE:
			return "title_fade"
		Phase.CAMERA_PAN:
			return "camera_pan"
		Phase.SETTLE:
			return "settle"
		Phase.ENTRY:
			return "entry"
		_:
			return "done"


func is_gameplay_blocked() -> bool:
	return _phase != Phase.INACTIVE and _phase != Phase.DONE


func is_transition_active() -> bool:
	return _phase == Phase.TITLE_FADE or _phase == Phase.CAMERA_PAN or _phase == Phase.SETTLE


func is_transition_paused() -> bool:
	return _transition_paused


func is_settings_open() -> bool:
	return _settings_open


func is_menu_open() -> bool:
	return _phase == Phase.MENU


func is_start_locked() -> bool:
	return _start_locked


func is_quit_locked() -> bool:
	return _quit_locked


func get_start_request_count() -> int:
	return _start_request_count


func get_start_button() -> Button:
	return _start_button


func get_settings_button() -> Button:
	return _settings_button


func get_quit_button() -> Button:
	return _quit_button


func get_slider() -> PixelVolumeSlider:
	return _slider


func get_return_button() -> Button:
	return _return_button


func get_menu_camera() -> Camera2D:
	return _menu_camera


func get_end_camera_center() -> Vector2:
	return _end_center


func get_volume_percent() -> int:
	return _volume_percent


func get_volume_label_text() -> String:
	return _percent_label.text if _percent_label != null else ""


func get_audio_settings_path() -> String:
	return audio_settings_path


func get_pause_overlay() -> Control:
	return _pause_overlay


func get_display_controller() -> DisplaySettingsController:
	return _display


func get_display_settings_path() -> String:
	return display_settings_path


func get_display_mode_button(fullscreen: bool) -> PixelMenuButton:
	return _display_mode_fullscreen if fullscreen else _display_mode_window


func get_resolution_button(size: Vector2i) -> PixelMenuButton:
	return _resolution_buttons.get(size) as PixelMenuButton


func get_apply_button() -> PixelMenuButton:
	return _apply_button


func get_pending_overlay() -> Control:
	return _pending_overlay


func get_pending_confirm_button() -> PixelMenuButton:
	return _pending_confirm_button


func get_pending_cancel_button() -> PixelMenuButton:
	return _pending_cancel_button


func get_pending_countdown_text() -> String:
	return _pending_countdown_label.text if _pending_countdown_label != null else ""


func get_display_note_text() -> String:
	return _display_note_label.text if _display_note_label != null else ""


func get_display_status_text() -> String:
	return _display_status_label.text if _display_status_label != null else ""


func is_display_pending() -> bool:
	return _display != null and _display.is_pending()


# --- Build UI --------------------------------------------------------------

func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		push_warning("StartMenu: %s is missing; using fallback for small runtime labels" % FONT_PATH)
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
	_root.name = "StartMenuRoot"
	_root.position = Vector2.ZERO
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_fade_group = Control.new()
	_fade_group.name = "MenuGroup"
	_fade_group.position = Vector2.ZERO
	_fade_group.size = VIEW_SIZE
	_fade_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade_group)

	_base_rect = _texture_rect(UI_BASE)
	_base_rect.name = "BaseUI"
	_fade_group.add_child(_base_rect)
	_focus_start_rect = _texture_rect(UI_FOCUS_START)
	_focus_start_rect.name = "FocusStart"
	_focus_settings_rect = _texture_rect(UI_FOCUS_SETTINGS)
	_focus_settings_rect.name = "FocusSettings"
	_quit_row_rect = _texture_rect(UI_QUIT)
	_quit_row_rect.name = "QuitRow"
	_focus_quit_rect = _texture_rect(UI_FOCUS_QUIT)
	_focus_quit_rect.name = "FocusQuit"
	_focus_start_rect.visible = false
	_focus_settings_rect.visible = false
	_focus_quit_rect.visible = false
	_fade_group.add_child(_focus_start_rect)
	_fade_group.add_child(_focus_settings_rect)
	_fade_group.add_child(_quit_row_rect)
	_fade_group.add_child(_focus_quit_rect)

	_start_button = _hit_button("StartButton", START_RECT)
	_fade_group.add_child(_start_button)
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.focus_entered.connect(_deferred_refresh_focus)
	_start_button.focus_exited.connect(_deferred_refresh_focus)
	_start_button.mouse_entered.connect(_on_hover.bind("start"))
	_start_button.mouse_exited.connect(_on_unhover.bind("start"))

	_settings_button = _hit_button("SettingsButton", SETTINGS_RECT)
	_fade_group.add_child(_settings_button)
	_settings_button.pressed.connect(_on_settings_pressed)
	_settings_button.focus_entered.connect(_deferred_refresh_focus)
	_settings_button.focus_exited.connect(_deferred_refresh_focus)
	_settings_button.mouse_entered.connect(_on_hover.bind("settings"))
	_settings_button.mouse_exited.connect(_on_unhover.bind("settings"))

	_quit_button = _hit_button("QuitButton", QUIT_RECT)
	_fade_group.add_child(_quit_button)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_button.focus_entered.connect(_deferred_refresh_focus)
	_quit_button.focus_exited.connect(_deferred_refresh_focus)
	_quit_button.mouse_entered.connect(_on_hover.bind("quit"))
	_quit_button.mouse_exited.connect(_on_unhover.bind("quit"))
	_refresh_menu_focus_chain()

	_settings_layer = _build_settings_layer()
	_root.add_child(_settings_layer)
	_settings_layer.visible = false

	_pause_overlay = _build_pause_overlay()
	_root.add_child(_pause_overlay)
	_pause_overlay.visible = false


func _build_settings_layer() -> Control:
	var layer_control: Control = Control.new()
	layer_control.name = "SettingsLayer"
	layer_control.position = Vector2.ZERO
	layer_control.size = VIEW_SIZE
	layer_control.mouse_filter = Control.MOUSE_FILTER_STOP

	var background: TextureRect = _texture_rect(UI_SETTINGS)
	layer_control.add_child(background)

	_settings_return_focus_rect = _texture_rect(UI_SETTINGS_RETURN_FOCUS)
	_settings_return_focus_rect.visible = false
	layer_control.add_child(_settings_return_focus_rect)

	# The static panel already contains 设置 / 主音量 / 显示模式 / 窗口分辨率 /
	# 返回.  Values, options and focus are real runtime controls.
	_percent_label = _label("100%", PERCENT_RECT.position, PERCENT_RECT.size, 12, TEXT)
	_percent_label.name = "VolumePercent"
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer_control.add_child(_percent_label)

	_slider = PixelVolumeSlider.new()
	_slider.name = "VolumeSlider"
	_slider.position = SLIDER_RECT.position
	_slider.size = SLIDER_RECT.size
	_slider.value = 100.0
	_slider.value_changed.connect(_on_volume_changed)
	_slider.focus_entered.connect(_refresh_return_focus)
	_slider.focus_exited.connect(_refresh_return_focus)
	layer_control.add_child(_slider)

	_display_mode_window = _menu_button(
		"ModeWindow", "窗口", MODE_WINDOW_RECT, PixelMenuButton.Variant.OPTION
	)
	_display_mode_window.pressed.connect(
		_on_display_mode_selected.bind(DisplayOptions.Mode.WINDOWED)
	)
	layer_control.add_child(_display_mode_window)

	_display_mode_fullscreen = _menu_button(
		"ModeFullscreen", "全屏", MODE_FULLSCREEN_RECT, PixelMenuButton.Variant.OPTION
	)
	_display_mode_fullscreen.pressed.connect(
		_on_display_mode_selected.bind(DisplayOptions.Mode.FULLSCREEN)
	)
	layer_control.add_child(_display_mode_fullscreen)

	for candidate: Vector2i in DisplayOptions.CANDIDATES:
		var resolution_button: PixelMenuButton = _menu_button(
			"Resolution%s" % DisplayOptions.format_size(candidate).replace("×", "x"),
			DisplayOptions.format_size(candidate),
			_resolution_rect(candidate),
			PixelMenuButton.Variant.OPTION
		)
		resolution_button.pressed.connect(_on_resolution_selected.bind(candidate))
		_resolution_buttons[candidate] = resolution_button
		layer_control.add_child(resolution_button)

	_apply_button = _menu_button(
		"ApplyDisplay", "应用", APPLY_RECT, PixelMenuButton.Variant.STONE
	)
	_apply_button.pressed.connect(_on_apply_display_pressed)
	layer_control.add_child(_apply_button)

	_return_button = _hit_button("ReturnButton", RETURN_RECT)
	layer_control.add_child(_return_button)
	_return_button.pressed.connect(_on_return_pressed)
	_return_button.focus_entered.connect(_refresh_return_focus)
	_return_button.focus_exited.connect(_refresh_return_focus)
	_return_button.mouse_entered.connect(_refresh_return_focus)
	_return_button.mouse_exited.connect(_refresh_return_focus)

	_display_note_label = _label("", DISPLAY_NOTE_RECT.position, DISPLAY_NOTE_RECT.size, 12, MUTED)
	_display_note_label.name = "DisplayNote"
	layer_control.add_child(_display_note_label)

	_display_status_label = _label("", STATUS_RECT.position, STATUS_RECT.size, 12, CYAN)
	_display_status_label.name = "DisplayStatus"
	layer_control.add_child(_display_status_label)

	_pending_overlay = _build_pending_overlay()
	layer_control.add_child(_pending_overlay)
	return layer_control


func _build_pending_overlay() -> Control:
	var overlay: Control = Control.new()
	overlay.name = "DisplayPending"
	overlay.position = Vector2.ZERO
	overlay.size = VIEW_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false

	var shade: ColorRect = ColorRect.new()
	shade.position = Vector2.ZERO
	shade.size = VIEW_SIZE
	shade.color = Color(0.006, 0.014, 0.018, 0.68)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var panel: Panel = Panel.new()
	panel.position = PENDING_PANEL_RECT.position
	panel.size = PENDING_PANEL_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var title: Label = _label("保留显示设置？", Vector2(0.0, 8.0), Vector2(340.0, 30.0), 24, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	_pending_countdown_label = _label("10 秒后自动恢复", Vector2(0.0, 42.0), Vector2(340.0, 16.0), 12, TEXT)
	_pending_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_pending_countdown_label)
	var hint: Label = _label("保留后才保存；Esc 或超时自动恢复", Vector2(0.0, 60.0), Vector2(340.0, 14.0), 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

	_pending_confirm_button = _menu_button(
		"PendingConfirm", "保留设置", PENDING_CONFIRM_RECT, PixelMenuButton.Variant.STONE
	)
	_pending_confirm_button.pressed.connect(_on_pending_confirm_pressed)
	overlay.add_child(_pending_confirm_button)
	_pending_cancel_button = _menu_button(
		"PendingCancel", "恢复原样", PENDING_CANCEL_RECT, PixelMenuButton.Variant.STONE
	)
	_pending_cancel_button.pressed.connect(_on_pending_cancel_pressed)
	overlay.add_child(_pending_cancel_button)
	_pending_confirm_button.focus_next = _pending_confirm_button.get_path_to(
		_pending_cancel_button
	)
	_pending_confirm_button.focus_previous = _pending_confirm_button.get_path_to(
		_pending_cancel_button
	)
	_pending_cancel_button.focus_next = _pending_cancel_button.get_path_to(
		_pending_confirm_button
	)
	_pending_cancel_button.focus_previous = _pending_cancel_button.get_path_to(
		_pending_confirm_button
	)
	return overlay


func _menu_button(
	button_name: String,
	button_text: String,
	rect: Rect2,
	variant: int
) -> PixelMenuButton:
	var button: PixelMenuButton = PixelMenuButton.new()
	button.name = button_name
	button.text = button_text
	button.position = rect.position
	button.size = rect.size
	button.font = _font
	button.variant = variant
	return button


func _resolution_rect(size: Vector2i) -> Rect2:
	match size:
		Vector2i(640, 360):
			return RES_640_RECT
		Vector2i(1280, 720):
			return RES_1280_RECT
		Vector2i(1920, 1080):
			return RES_1920_RECT
		Vector2i(2560, 1440):
			return RES_2560_RECT
	return RES_640_RECT


func _build_pause_overlay() -> Control:
	var overlay: Control = Control.new()
	overlay.name = "TransitionPause"
	overlay.position = Vector2.ZERO
	overlay.size = VIEW_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var shade: ColorRect = ColorRect.new()
	shade.position = Vector2.ZERO
	shade.size = VIEW_SIZE
	shade.color = Color(0.006, 0.014, 0.018, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)

	var panel: Panel = Panel.new()
	panel.position = Vector2(204.0, 138.0)
	panel.size = Vector2(232.0, 84.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var title: Label = _label("已暂停", Vector2(0.0, 8.0), Vector2(232.0, 30.0), 24, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var hint: Label = _label("Esc 继续", Vector2(0.0, 48.0), Vector2(232.0, 16.0), 12, TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)
	return overlay


func _texture_rect(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.position = Vector2.ZERO
	rect.size = VIEW_SIZE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _hit_button(button_name: String, rect: Rect2) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.text = ""
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		empty.content_margin_left = 0.0
		empty.content_margin_top = 0.0
		empty.content_margin_right = 0.0
		empty.content_margin_bottom = 0.0
		button.add_theme_stylebox_override(state, empty)
	return button


func _label(text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
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
	return label


# --- Focus / hover ---------------------------------------------------------

func _focus_start() -> void:
	if _phase != Phase.MENU or _settings_open:
		return
	_start_button.grab_focus()
	_refresh_focus_overlays()


func _focus_settings() -> void:
	if _phase != Phase.MENU or _settings_open:
		return
	_settings_button.grab_focus()
	_refresh_focus_overlays()


func _focus_slider() -> void:
	if not _settings_open:
		return
	_slider.grab_focus()
	_slider.queue_redraw()
	_refresh_return_focus()


func _deferred_refresh_focus() -> void:
	call_deferred("_refresh_focus_overlays")


func _on_hover(kind: String) -> void:
	_hover_kind = kind
	_refresh_focus_overlays()


func _on_unhover(kind: String) -> void:
	if _hover_kind == kind:
		_hover_kind = ""
	_refresh_focus_overlays()


func _refresh_focus_overlays() -> void:
	if (
		_focus_start_rect == null or _focus_settings_rect == null
		or _focus_quit_rect == null
	):
		return
	var show_start: bool = false
	var show_settings: bool = false
	var show_quit: bool = false
	if (
		_phase == Phase.MENU and not _settings_open
		and not _quit_locked and _fade_group.visible
	):
		var kind: String = _hover_kind
		if kind.is_empty():
			var owner: Control = get_viewport().gui_get_focus_owner()
			if owner == _start_button:
				kind = "start"
			elif owner == _settings_button:
				kind = "settings"
			elif owner == _quit_button:
				kind = "quit"
		show_start = kind == "start"
		show_settings = kind == "settings"
		show_quit = kind == "quit"
	_focus_start_rect.visible = show_start
	_focus_settings_rect.visible = show_settings
	_focus_quit_rect.visible = show_quit


func _refresh_menu_focus_chain() -> void:
	if _start_button == null or _settings_button == null or _quit_button == null:
		return
	var chain: Array[Control] = [_start_button, _settings_button, _quit_button]
	for index: int in range(chain.size()):
		var current: Control = chain[index]
		var next: Control = chain[(index + 1) % chain.size()]
		var previous: Control = chain[(index - 1 + chain.size()) % chain.size()]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		# Up/Down follow the same three-entry loop as Tab/Shift+Tab.
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(previous)


func _refresh_return_focus() -> void:
	if _settings_return_focus_rect == null:
		return
	if not _settings_open:
		_settings_return_focus_rect.visible = false
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	_settings_return_focus_rect.visible = owner == _return_button or _return_button.is_hovered()


# --- Menu actions ----------------------------------------------------------

func _on_start_pressed() -> void:
	if _phase != Phase.MENU or _settings_open or _start_locked or _quit_locked:
		return
	if _display != null and _display.is_pending():
		return
	DemoAudio.play_ui_click()
	_start_locked = true
	_start_request_count += 1
	_start_button.release_focus()
	_settings_button.release_focus()
	_quit_button.release_focus()
	_start_button.disabled = true
	_settings_button.disabled = true
	_quit_button.disabled = true
	_hover_kind = ""
	_focus_start_rect.visible = false
	_focus_settings_rect.visible = false
	_focus_quit_rect.visible = false
	_phase = Phase.TITLE_FADE
	start_requested.emit()
	_start_sequence()


func _on_settings_pressed() -> void:
	if _phase != Phase.MENU or _settings_open or _start_locked or _quit_locked:
		return
	if _display != null and _display.is_pending():
		return
	DemoAudio.play_ui_click()
	_open_settings()


func _on_quit_pressed() -> void:
	if _phase != Phase.MENU or _settings_open or _start_locked or _quit_locked:
		return
	if _display != null and _display.is_pending():
		return
	# Accepting the quit locks every menu hot zone before the process exits, so
	# a double click or a held Enter cannot run the handler twice.
	DemoAudio.play_ui_click()
	_quit_locked = true
	_start_button.release_focus()
	_settings_button.release_focus()
	_quit_button.release_focus()
	_start_button.disabled = true
	_settings_button.disabled = true
	_quit_button.disabled = true
	_hover_kind = ""
	_focus_start_rect.visible = false
	_focus_settings_rect.visible = false
	_focus_quit_rect.visible = false
	quit_requested.emit()
	get_tree().quit(0)


## Settings "返回" is a real Button. Confirm it only when it will actually
## close (no pending display confirmation), so a blocked return stays silent.
func _on_return_pressed() -> void:
	if not _settings_open:
		return
	if _display != null and _display.is_pending():
		return
	DemoAudio.play_ui_click()
	_close_settings()


func _start_sequence() -> void:
	var fade_duration: float = maxf(float(_level.get("menu_title_fade_duration")), 0.01)
	var pan_duration: float = maxf(float(_level.get("menu_camera_pan_duration")), 0.01)
	var settle_duration: float = maxf(float(_level.get("menu_settle_duration")), 0.0)
	_end_center = _compute_player_camera_center()
	var start_y: float = float(_level.get("menu_camera_start_position").y)
	_menu_camera.position = Vector2(_end_center.x, start_y)
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
		_sequence = null
	_sequence = create_tween()
	# The background and camera tween freeze together with the scene tree while
	# the transition is paused, then continue from the exact same progress.
	_sequence.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_sequence.tween_property(_fade_group, "modulate:a", 0.0, fade_duration)
	_sequence.tween_callback(_on_title_faded)
	_sequence.tween_property(_menu_camera, "position:y", _end_center.y, pan_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sequence.tween_callback(_on_pan_finished)
	_sequence.tween_interval(settle_duration)
	_sequence.tween_callback(_on_settle_finished)


func _on_title_faded() -> void:
	if _phase != Phase.TITLE_FADE:
		return
	_phase = Phase.CAMERA_PAN
	_fade_group.visible = false
	_world.visible = true
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Player stays disabled and invisible until the camera has settled.
	_player.visible = false
	_player.process_mode = Node.PROCESS_MODE_DISABLED


func _on_pan_finished() -> void:
	if _phase != Phase.CAMERA_PAN:
		return
	_phase = Phase.SETTLE
	_menu_camera.position.y = _end_center.y


func _on_settle_finished() -> void:
	if _phase != Phase.SETTLE:
		return
	_phase = Phase.ENTRY
	_transition_paused = false
	_pause_overlay.visible = false
	_menu_camera.enabled = false
	_set_stele_prompts_visible(true)
	_level.begin_from_menu()
	_root.visible = false
	_phase = Phase.DONE
	_sequence = null
	transition_finished.emit()


func _set_stele_prompts_visible(value: bool) -> void:
	for stele: Node in get_tree().get_nodes_in_group(&"tutorial_stele"):
		var layer: CanvasLayer = stele.get_node_or_null("PromptLayer") as CanvasLayer
		if layer == null:
			continue
		layer.visible = value
		if not _stele_prompt_layers.has(layer):
			_stele_prompt_layers.append(layer)


func _compute_player_camera_center() -> Vector2:
	var viewport_size: Vector2 = _level.get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = VIEW_SIZE
	var half: Vector2 = viewport_size * 0.5
	var zoom: Vector2 = _player_camera.zoom
	if zoom.x != 0.0:
		half.x /= zoom.x
	if zoom.y != 0.0:
		half.y /= zoom.y
	var min_x: float = float(_player_camera.limit_left) + half.x
	var max_x: float = float(_player_camera.limit_right) - half.x
	var min_y: float = float(_player_camera.limit_top) + half.y
	var max_y: float = float(_player_camera.limit_bottom) - half.y
	var center_x: float = (
		_player_camera.global_position.x
		if max_x >= min_x
		else (float(_player_camera.limit_left) + float(_player_camera.limit_right)) * 0.5
	)
	var center_y: float = (
		_player_camera.global_position.y
		if max_y >= min_y
		else (float(_player_camera.limit_top) + float(_player_camera.limit_bottom)) * 0.5
	)
	if max_x >= min_x:
		center_x = clampf(center_x, min_x, max_x)
	if max_y >= min_y:
		center_y = clampf(center_y, min_y, max_y)
	return Vector2(center_x, center_y)


# --- Transition pause / focus safety ---------------------------------------

func _set_transition_paused(value: bool) -> void:
	if not is_transition_active():
		return
	if value == _transition_paused:
		return
	_transition_paused = value
	get_tree().paused = value
	_pause_overlay.visible = value
	if value:
		if _player != null:
			_player.reset_movement_input_state()
			_player.clear_input_buffers()
		_hover_kind = ""
		_refresh_focus_overlays()


func _toggle_transition_pause() -> void:
	_set_transition_paused(not _transition_paused)


func _on_window_focus_exited() -> void:
	if _settings_open and _slider != null:
		_slider.cancel_drag()
	if is_transition_active():
		# Do not let a lost window deliver the rest of a pan or settle; the
		# player must explicitly resume with Esc.
		_set_transition_paused(true)


func _unhandled_input(event: InputEvent) -> void:
	if settings_host_mode:
		# The pause page owns Esc routing in host mode (display pending ->
		# settings -> pause root -> resume).  Do not consume it twice here.
		return
	if not event.is_action_pressed(&"pause"):
		return
	match _phase:
		Phase.MENU:
			if _settings_open:
				if _display != null and _display.is_pending():
					_display.cancel_pending("escape")
				else:
					_close_settings()
			get_viewport().set_input_as_handled()
		Phase.TITLE_FADE, Phase.CAMERA_PAN, Phase.SETTLE:
			_toggle_transition_pause()
			get_viewport().set_input_as_handled()
		_:
			pass


# --- Settings --------------------------------------------------------------

## Pause-page entry: show the same settings layer without the title menu,
## world/camera hand-off or opening transition.  The caller keeps the tree
## paused; this only builds/shows the settings UI.
func open_settings_host() -> void:
	if not settings_host_mode:
		return
	_phase = Phase.MENU
	_settings_open = false
	_root.visible = true
	_fade_group.visible = false
	_pause_overlay.visible = false
	_pending_overlay.visible = false
	_load_audio_settings()
	_open_settings()


func hide_settings_host() -> void:
	if not settings_host_mode:
		return
	_settings_open = false
	_phase = Phase.INACTIVE
	if _slider != null:
		_slider.cancel_drag()
	if _settings_layer != null:
		_settings_layer.visible = false
	if _pending_overlay != null:
		_pending_overlay.visible = false
	if _root != null:
		_root.visible = false


func cancel_display_pending(reason: String = "escape") -> void:
	if _display == null or not _display.is_pending():
		return
	_display.cancel_pending(reason)


func cancel_display_pending_for_leave() -> void:
	cancel_display_pending("leave")


func _open_settings() -> void:
	if _phase != Phase.MENU or _settings_open:
		return
	_settings_open = true
	_start_button.disabled = true
	_settings_button.disabled = true
	_quit_button.disabled = true
	_start_button.release_focus()
	_settings_button.release_focus()
	_quit_button.release_focus()
	_hover_kind = ""
	_focus_quit_rect.visible = false
	_fade_group.visible = false
	_settings_layer.visible = true
	_pending_overlay.visible = false
	_slider.set_value_silent(float(_volume_percent))
	_update_volume_label()
	_settings_return_focus_rect.visible = false
	_draft_mode = _display.get_active_mode()
	_draft_window_size = _display.get_active_window_size()
	_ensure_draft_window_fits()
	_display_status_label.text = _display.get_startup_notice()
	_sync_display_controls()
	call_deferred("_focus_slider")


func _close_settings() -> void:
	if not _settings_open:
		return
	if _display != null and _display.is_pending():
		return
	if settings_host_mode:
		_settings_open = false
		_phase = Phase.INACTIVE
		_slider.cancel_drag()
		_settings_layer.visible = false
		_pending_overlay.visible = false
		_root.visible = false
		settings_host_closed.emit()
		return
	_settings_open = false
	_slider.cancel_drag()
	_settings_layer.visible = false
	_pending_overlay.visible = false
	_fade_group.visible = true
	_fade_group.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_start_button.disabled = false
	_settings_button.disabled = false
	_quit_button.disabled = false
	_settings_return_focus_rect.visible = false
	call_deferred("_focus_settings")


func _ensure_draft_window_fits() -> void:
	if _draft_mode != DisplayOptions.Mode.WINDOWED:
		return
	if not _display.is_size_available(_draft_window_size):
		_draft_window_size = _display.get_default_window_size()


func _on_display_mode_selected(mode: int) -> void:
	if _display == null or _display.is_pending() or _draft_mode == mode:
		return
	_draft_mode = mode
	_ensure_draft_window_fits()
	_mark_draft_changed()


func _on_resolution_selected(size: Vector2i) -> void:
	if _display == null or _display.is_pending():
		return
	if _draft_mode != DisplayOptions.Mode.WINDOWED:
		return
	if not _display.is_size_available(size):
		return
	if _draft_window_size == size:
		return
	_draft_window_size = size
	_mark_draft_changed()


func _mark_draft_changed() -> void:
	var changed: bool = (
		_draft_mode != _display.get_active_mode()
		or _draft_window_size != _display.get_active_window_size()
	)
	_display_status_label.text = "显示设置待应用" if changed else ""
	_sync_display_controls()


func _on_apply_display_pressed() -> void:
	if _display == null or _display.is_pending():
		return
	if (
		_draft_mode == _display.get_active_mode()
		and _draft_window_size == _display.get_active_window_size()
	):
		return
	var result: Dictionary = _display.begin_apply(_draft_mode, _draft_window_size)
	if not bool(result.get("ok", false)):
		_display_status_label.text = String(result.get("message", "无法切换显示设置"))
		_sync_display_controls()
		return
	_draft_mode = _display.get_pending_mode()
	_draft_window_size = _display.get_pending_window_size()
	_display_status_label.text = "显示已切换，等待确认"
	_pending_overlay.visible = true
	_sync_display_controls()
	_update_pending_countdown()
	if _pending_cancel_button != null:
		_pending_cancel_button.grab_focus()


func _sync_display_controls() -> void:
	if _display == null or _apply_button == null:
		return
	var pending: bool = _display.is_pending()
	_display_mode_window.selected = _draft_mode == DisplayOptions.Mode.WINDOWED
	_display_mode_fullscreen.selected = _draft_mode == DisplayOptions.Mode.FULLSCREEN
	_display_mode_window.disabled = pending
	_display_mode_fullscreen.disabled = pending

	var disabled_names: Array[String] = []
	for candidate: Vector2i in DisplayOptions.CANDIDATES:
		var button: PixelMenuButton = _resolution_buttons.get(candidate) as PixelMenuButton
		if button == null:
			continue
		var fits_now: bool = _display.is_size_available(candidate)
		button.selected = _draft_window_size == candidate
		button.disabled = pending or _draft_mode != DisplayOptions.Mode.WINDOWED or not fits_now
		if not fits_now:
			disabled_names.append(DisplayOptions.format_size(candidate))

	if pending:
		_display_note_label.text = "显示设置待确认，其他选项暂时锁定"
	elif _draft_mode == DisplayOptions.Mode.FULLSCREEN:
		_display_note_label.text = "全屏使用桌面分辨率；仅窗口模式可选分辨率"
	elif not disabled_names.is_empty():
		if disabled_names.size() <= 2:
			_display_note_label.text = "超出本屏：" + "、".join(disabled_names)
		else:
			_display_note_label.text = "超出本屏：%s 等%d项" % [
				disabled_names[0], disabled_names.size()
			]
	else:
		_display_note_label.text = "窗口按 16:9 整数放大；余区黑边"

	var changed: bool = (
		_draft_mode != _display.get_active_mode()
		or _draft_window_size != _display.get_active_window_size()
	)
	_apply_button.disabled = pending or not changed
	_return_button.disabled = pending
	_slider.focus_mode = Control.FOCUS_NONE if pending else Control.FOCUS_ALL
	_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE if pending else Control.MOUSE_FILTER_STOP
	if pending:
		_slider.cancel_drag()
	_refresh_settings_focus_chain()
	_refresh_return_focus()


func _refresh_settings_focus_chain() -> void:
	var chain: Array[Control] = []
	if _slider != null and _slider.focus_mode != Control.FOCUS_NONE:
		chain.append(_slider)
	var controls: Array[Control] = [
		_display_mode_window,
		_display_mode_fullscreen,
		_resolution_buttons.get(Vector2i(640, 360)) as Control,
		_resolution_buttons.get(Vector2i(1280, 720)) as Control,
		_resolution_buttons.get(Vector2i(1920, 1080)) as Control,
		_resolution_buttons.get(Vector2i(2560, 1440)) as Control,
		_apply_button,
		_return_button,
	]
	for control: Control in controls:
		if control != null and control.focus_mode != Control.FOCUS_NONE:
			chain.append(control)
	if chain.is_empty():
		return
	for index: int in range(chain.size()):
		var current: Control = chain[index]
		var next: Control = chain[(index + 1) % chain.size()]
		var previous: Control = chain[(index - 1 + chain.size()) % chain.size()]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
	# Explicit left/right links make the two mode buttons and the bottom action
	# row predictable even before the user learns the spatial layout.
	if _display_mode_window.focus_mode != Control.FOCUS_NONE:
		_display_mode_window.focus_neighbor_right = _display_mode_window.get_path_to(
			_display_mode_fullscreen
		)
	if _display_mode_fullscreen.focus_mode != Control.FOCUS_NONE:
		_display_mode_fullscreen.focus_neighbor_left = _display_mode_fullscreen.get_path_to(
			_display_mode_window
		)
	if _apply_button.focus_mode != Control.FOCUS_NONE:
		_apply_button.focus_neighbor_right = _apply_button.get_path_to(_return_button)
	if _return_button.focus_mode != Control.FOCUS_NONE:
		_return_button.focus_neighbor_left = _return_button.get_path_to(_apply_button)
	var res_640: PixelMenuButton = _resolution_buttons.get(Vector2i(640, 360)) as PixelMenuButton
	var res_1280: PixelMenuButton = _resolution_buttons.get(Vector2i(1280, 720)) as PixelMenuButton
	if res_640 != null and res_1280 != null:
		if res_640.focus_mode != Control.FOCUS_NONE:
			res_640.focus_neighbor_right = res_640.get_path_to(res_1280)
		if res_1280.focus_mode != Control.FOCUS_NONE:
			res_1280.focus_neighbor_left = res_1280.get_path_to(res_640)


func _on_pending_confirm_pressed() -> void:
	if _display == null or not _display.is_pending():
		return
	var result: Dictionary = _display.confirm_pending()
	_pending_overlay.visible = false
	_draft_mode = _display.get_active_mode()
	_draft_window_size = _display.get_active_window_size()
	if bool(result.get("ok", false)):
		_display_status_label.text = (
			"显示设置已保存"
			if bool(result.get("saved", false))
			else String(result.get("message", "显示设置已应用，但保存失败"))
		)
	else:
		_display_status_label.text = String(result.get("message", "显示设置未保留，已恢复"))
	_sync_display_controls()
	call_deferred("_focus_after_pending")


func _on_pending_cancel_pressed() -> void:
	if _display == null or not _display.is_pending():
		return
	_display.cancel_pending("button")


func _on_display_pending_cancelled(reason: String) -> void:
	if _display == null:
		return
	_pending_overlay.visible = false
	_draft_mode = _display.get_active_mode()
	_draft_window_size = _display.get_active_window_size()
	_ensure_draft_window_fits()
	match reason:
		"timeout":
			_display_status_label.text = "已超时，恢复上次显示设置"
		"escape":
			_display_status_label.text = "已取消，恢复上次显示设置"
		_:
			_display_status_label.text = "已恢复上次显示设置"
	_sync_display_controls()
	call_deferred("_focus_after_pending")


func _update_pending_countdown() -> void:
	if _display == null or not _display.is_pending():
		return
	var seconds: int = maxi(ceili(_display.get_pending_remaining_seconds()), 1)
	_pending_countdown_label.text = "%d 秒后自动恢复" % seconds


func _focus_after_pending() -> void:
	if not _settings_open:
		return
	if _return_button != null and _return_button.focus_mode != Control.FOCUS_NONE:
		_return_button.grab_focus()
	elif _apply_button != null and _apply_button.focus_mode != Control.FOCUS_NONE:
		_apply_button.grab_focus()
	_refresh_return_focus()


func _on_volume_changed(value: float) -> void:
	var percent: int = clampi(roundi(value), 0, 100)
	if percent == _volume_percent and _master_bus_index >= 0:
		_update_volume_label()
		return
	_volume_percent = percent
	_apply_master_volume()
	_update_volume_label()
	_save_audio_settings()


func _update_volume_label() -> void:
	if _percent_label != null:
		_percent_label.text = "%d%%" % _volume_percent


func _load_audio_settings() -> void:
	_master_bus_index = AudioServer.get_bus_index(MASTER_BUS_NAME)
	var volume: float = 100.0
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(audio_settings_path)
	if error == OK:
		var raw: Variant = config.get_value("audio", "master_volume", 100.0)
		if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
			volume = float(raw)
			if is_nan(volume) or is_inf(volume):
				volume = 100.0
			volume = clampf(volume, 0.0, 100.0)
	_volume_percent = clampi(roundi(volume), 0, 100)
	_apply_master_volume()
	_update_volume_label()


func _apply_master_volume() -> void:
	if _master_bus_index < 0:
		return
	if _volume_percent <= 0:
		AudioServer.set_bus_mute(_master_bus_index, true)
		AudioServer.set_bus_volume_db(_master_bus_index, -80.0)
	else:
		AudioServer.set_bus_mute(_master_bus_index, false)
		AudioServer.set_bus_volume_db(
			_master_bus_index,
			linear_to_db(float(_volume_percent) / 100.0)
		)


func _save_audio_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", float(_volume_percent))
	var error: Error = config.save(audio_settings_path)
	if error != OK:
		push_warning("StartMenu: could not save %s (error %d)" % [audio_settings_path, error])
