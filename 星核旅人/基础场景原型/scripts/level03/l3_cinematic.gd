class_name L3Cinematic
extends Node2D

## One-shot near-gate tutorial. It owns only presentation and the short scripted
## walk; gameplay timers are frozen by putting the guard in cinematic mode and
## the player in a movement override.
##
## Real branches:
##   - the guard is never faked into rubble. If it is actually scattered /
##     rebuilding when the camera reaches it, that real animation is shown and
##     the reassemble sound is already driven by the guard signal. Otherwise the
##     camera shows the real raised-arm charge.
##   - a defeated guard is never revived. If it is already dead the guard beat is
##     skipped and the echo still explains the core / gate step.
##
## Input: short Space completes the current line or advances; holding Space for
## 0.6 s skips the whole segment. Control returns only after Space is released,
## so the same press cannot jump the player. While the player is still holding
## that skip press, the cinematic remains a control-occupied state
## (is_active()/is_awaiting_release()); E/J, the pause page, focus loss and R
## all see it as active and clean it up explicitly.

signal finished(skipped: bool)
signal stone_cue_requested

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
## Head bubble (play-test revision): no bottom 608x68 dialogue bar; the 44 px
## top/bottom letterbox is kept.
const BAR_HEIGHT: float = 44.0
const BUBBLE_WIDTH: float = 246.0
const BUBBLE_HEIGHT: float = 54.0
const BUBBLE_PAD: float = 6.0
const BUBBLE_SAFE: Rect2 = Rect2(8.0, 48.0, 624.0, 264.0)
const TAIL_GAP: float = 6.0
const SKIP_HOLD: float = 0.6
const TEXT_CPS: float = 34.0
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const PANEL_BG: Color = Color(0.012, 0.028, 0.035, 0.95)
const PANEL_BORDER: Color = Color(0.45, 0.66, 0.63, 0.85)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

const ECHO_SHEET: Texture2D = preload("res://assets/guide_echo_20261113/guide_echo_idle_6f_s40.png")
const PROJECTION: Texture2D = preload("res://assets/level03_prototype/echo_projection.png")
const QUESTION: Texture2D = preload("res://assets/level03_prototype/emote_question.png")
const EXCLAIM: Texture2D = preload("res://assets/level03_prototype/emote_exclaim.png")

const PAGES: Array[String] = [
	"碎了还会再聚。\n支撑它的，是壳里的星核。",
	"它聚起引力时，\n胸前的星核便会露出来。",
	"让护符与它亮起不同的光，\n再向露出的星核出剑。",
]

## The post-fight branch points at the actual next action instead of describing
## a charge the player can no longer see. No guard state is reset or revived.
const DEFEATED_PAGES: Array[String] = [
	"将它留下的星核嵌入城门，\n那是通往城内的路。",
]

enum Phase { IDLE, INTRO, WALK, DOOR, GUARD, ECHO, DIALOGUE, OUTRO }

var _level: Node = null
var _player: L3Player = null
var _guard: L3Guard = null
var _gate: L3Gate = null
var _player_camera: Camera2D = null
var _cine_camera: Camera2D = null
var _ui: CanvasLayer = null
var _root: Control = null
var _bubble: Panel = null
var _top_bar: ColorRect = null
var _bottom_bar: ColorRect = null
var _bar_height: float = 0.0
var _bar_target: float = 0.0
var _speaker: Label = null
var _body: Label = null
var _page_label: Label = null
var _hint: Label = null
var _question: Sprite2D = null
var _exclaim: Sprite2D = null
var _echo: Sprite2D = null
var _projection: Sprite2D = null
var _font: Font = null

var _active: bool = false
var _played: bool = false
var _phase: Phase = Phase.IDLE
var _t: float = 0.0
var _cam_focus: Vector2 = Vector2(320.0, 180.0)
var _page_index: int = -1
var _reveal: float = 0.0
var _space_held: bool = false
var _space_time: float = 0.0
var _space_action_done: bool = false
var _await_release: bool = false
var _skipped: bool = false
var _echo_time: float = 0.0
var _symbol_time: float = 0.0
var _guard_beat_shown_rebuild: bool = false
var _pages: Array[String] = []
var _door_cue_fired: bool = false
var _door_turned: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_font = _load_font()
	_build_camera()
	_build_ui()
	_build_world_sprites()
	_set_visible_all(false)
	set_process(false)


func setup(level: Node, player: L3Player, guard: L3Guard, gate: L3Gate) -> void:
	_level = level
	_player = player
	_guard = guard
	_gate = gate
	if _player != null:
		_player_camera = _player.get_node_or_null("Camera2D") as Camera2D


func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return ThemeDB.fallback_font
	var base: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if base == null:
		return ThemeDB.fallback_font
	var copy: FontFile = base.duplicate() as FontFile
	if copy != null:
		copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		copy.hinting = TextServer.HINTING_NONE
		copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		copy.allow_system_fallback = false
		return copy
	return base


func _build_camera() -> void:
	_cine_camera = Camera2D.new()
	_cine_camera.name = "CineCamera"
	_cine_camera.enabled = false
	_cine_camera.position_smoothing_enabled = false
	_cine_camera.limit_left = 0
	_cine_camera.limit_top = 0
	_cine_camera.limit_right = 2520
	_cine_camera.limit_bottom = 360
	add_child(_cine_camera)


func _build_ui() -> void:
	# 44 px letterbox bars are kept; the dialogue itself is one small bubble
	# bound to the echo's head plus a borderless key hint (no 608x68 panel).
	_ui = CanvasLayer.new()
	_ui.name = "CineUI"
	_ui.layer = 12
	_ui.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_ui)
	_root = Control.new()
	_root.name = "CineRoot"
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root)

	_top_bar = ColorRect.new()
	_top_bar.name = "TopBar"
	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(VIEW_SIZE.x, 0.0)
	_top_bar.color = Color(0.008, 0.014, 0.018, 0.96)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top_bar)

	_bottom_bar = ColorRect.new()
	_bottom_bar.name = "BottomBar"
	_bottom_bar.position = Vector2(0.0, VIEW_SIZE.y)
	_bottom_bar.size = Vector2(VIEW_SIZE.x, 0.0)
	_bottom_bar.color = Color(0.008, 0.014, 0.018, 0.96)
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom_bar)

	_bubble = Panel.new()
	_bubble.name = "EchoBubble"
	_bubble.position = Vector2(16.0, 180.0)
	_bubble.size = Vector2(BUBBLE_WIDTH, BUBBLE_HEIGHT)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.048, 0.058, 0.93)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.37, 0.72, 0.74, 0.85)
	style.set_corner_radius_all(3)
	style.anti_aliasing = false
	_bubble.add_theme_stylebox_override("panel", style)
	_root.add_child(_bubble)

	_speaker = _label("守望者残响", Vector2(BUBBLE_PAD, 3.0),
		Vector2(BUBBLE_WIDTH - 74.0, 14.0), 12, CYAN)
	_bubble.add_child(_speaker)
	_page_label = _label("", Vector2(BUBBLE_WIDTH - 62.0, 3.0),
		Vector2(56.0, 14.0), 12, MUTED)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bubble.add_child(_page_label)
	_body = _label("", Vector2(BUBBLE_PAD, 19.0),
		Vector2(BUBBLE_WIDTH - BUBBLE_PAD * 2.0, 32.0), 12, TEXT)
	_bubble.add_child(_body)
	_bubble.visible = false

	_hint = _label("", Vector2(16.0, 332.0), Vector2(608.0, 14.0), 12, MUTED)
	_hint.text = "空格 继续 · 长按 0.6s 跳过"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.72)
	_root.add_child(_hint)


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
	label.add_theme_constant_override("outline_size", 2)
	return label


func _build_world_sprites() -> void:
	_question = Sprite2D.new()
	_question.name = "QuestionMark"
	_question.texture = QUESTION
	_question.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_question.z_index = 20
	_question.visible = false
	add_child(_question)

	_exclaim = Sprite2D.new()
	_exclaim.name = "ExclaimMark"
	_exclaim.texture = EXCLAIM
	_exclaim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_exclaim.z_index = 20
	_exclaim.visible = false
	add_child(_exclaim)

	_echo = Sprite2D.new()
	_echo.name = "S40Echo"
	_echo.texture = ECHO_SHEET
	_echo.hframes = 6
	_echo.vframes = 1
	_echo.centered = false
	_echo.offset = Vector2(-24.0, -60.0)
	_echo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_echo.z_index = 19
	_echo.visible = false
	add_child(_echo)

	_projection = Sprite2D.new()
	_projection.name = "EchoProjection"
	_projection.texture = PROJECTION
	_projection.centered = true
	_projection.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_projection.z_index = 18
	_projection.visible = false
	add_child(_projection)


func play() -> void:
	if is_active() or _played:
		return
	_played = true
	_active = true
	_phase = Phase.INTRO
	_t = 0.0
	_page_index = -1
	_reveal = 0.0
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	_await_release = false
	_skipped = false
	_guard_beat_shown_rebuild = false
	_door_cue_fired = false
	_door_turned = false
	_pages = DEFEATED_PAGES if (_guard != null and _guard.is_defeated()) else PAGES
	if _player != null:
		_player.lock_for_cinematic()
		_cam_focus = _focus_on_player()
	if _guard != null:
		_guard.set_cinematic_mode(true)
		_guard_beat_shown_rebuild = _guard.is_scattered()
	if _cine_camera != null:
		_cine_camera.global_position = _cam_focus
		_cine_camera.enabled = true
		_cine_camera.make_current()
	_set_visible_all(true)
	_set_bubble_visible(false)
	_bar_target = BAR_HEIGHT
	_bar_height = 0.0
	_apply_bar_height()
	_update_symbols()
	set_process(true)


func _process(delta: float) -> void:
	if _await_release:
		if not _space_held and not Input.is_physical_key_pressed(KEY_SPACE):
			_restore_control()
		return
	if not _active:
		return
	if _space_held and not _space_action_done:
		_space_time += delta
		if _space_time >= SKIP_HOLD:
			_space_action_done = true
			_skipped = true
			if _phase == Phase.OUTRO:
				_complete_finish()
			else:
				_begin_outro()
			return
	_t += delta
	_update_bars(delta)
	_update_world_visuals(delta)
	match _phase:
		Phase.INTRO:
			_cam_focus = _focus_on_player()
			if _t >= 0.35:
				_phase = Phase.WALK
				_t = 0.0
				if _player != null:
					_player.begin_cinematic_walk(1.0)
		Phase.WALK:
			_cam_focus = _focus_on_player()
			if _t >= 1.10 or (_player != null and _player.global_position.x >= 2170.0):
				if _player != null:
					_player.end_cinematic_walk()
					_player.face_direction(1)
				_phase = Phase.DOOR
				_t = 0.0
				_door_cue_fired = false
				_door_turned = false
				_question.visible = true
				_exclaim.visible = false
				_update_symbols()
		Phase.DOOR:
			_cam_focus = _focus_on_player()
			_question.visible = not _door_turned
			_exclaim.visible = _door_turned
			_update_symbols()
			# The player first faces the closed door and gets the question mark.
			# Then a real stone-motion cue draws attention only when the guard is
			# alive and not currently rebuilding. A real scatter/reassemble keeps
			# its own event sound; a defeated guard has no fake motion.
			if not _door_cue_fired and _t >= 0.40:
				_door_cue_fired = true
				if _guard != null and not _guard.is_defeated() and not _guard.is_scattered():
					stone_cue_requested.emit()
			# After the cue the body actually turns toward the guard before the
			# camera leaves the player.
			if not _door_turned and _t >= 0.75:
				_door_turned = true
				if _player != null:
					var toward_guard: int = 1
					if _guard != null and _guard.global_position.x < _player.global_position.x:
						toward_guard = -1
					_player.face_direction(toward_guard)
				_question.visible = false
				_exclaim.visible = true
				_update_symbols()
			if _t >= 1.20:
				_phase = Phase.GUARD
				_t = 0.0
				_question.visible = false
				_exclaim.visible = true
				_update_symbols()
		Phase.GUARD:
			_cam_focus = _guard_focus()
			_question.visible = false
			_exclaim.visible = true
			_update_symbols()
			if _t >= 1.60:
				_phase = Phase.ECHO
				_t = 0.0
				_exclaim.visible = false
		Phase.ECHO:
			_cam_focus = _focus_on_player()
			_echo.visible = true
			_projection.visible = true
			var alpha: float = clampf(_t / 0.4, 0.0, 0.86)
			_echo.modulate = Color(1.0, 1.0, 1.0, alpha)
			_projection.modulate = Color(0.6, 0.95, 1.0, alpha)
			_update_echo_positions()
			if _t >= 0.55:
				_phase = Phase.DIALOGUE
				_t = 0.0
				_play_page(0)
		Phase.DIALOGUE:
			_reveal = minf(_reveal + delta * TEXT_CPS, float(_pages[_page_index].length()))
			_body.text = _pages[_page_index].substr(0, int(_reveal))
			_update_echo_positions()
			_update_bubble()
		Phase.OUTRO:
			if _t >= 0.30:
				_complete_finish()
	_update_camera(delta)


func _update_bars(delta: float) -> void:
	var target: float = _bar_target
	if _phase == Phase.OUTRO:
		target = 0.0
	_bar_height = move_toward(_bar_height, target, delta * 220.0)
	_apply_bar_height()


func _apply_bar_height() -> void:
	if _top_bar != null:
		_top_bar.size.y = _bar_height
	if _bottom_bar != null:
		_bottom_bar.position.y = VIEW_SIZE.y - _bar_height
		_bottom_bar.size.y = _bar_height


func get_bar_height() -> float:
	return _bar_height


func _update_bubble() -> void:
	if _bubble == null or not _bubble.visible:
		return
	var anchor: Vector2 = _bubble_anchor_screen()
	var width: float = BUBBLE_WIDTH
	var height: float = _bubble_height()
	_bubble.size = Vector2(width, height)
	var pos: Vector2 = Vector2(
		anchor.x - width * 0.5,
		anchor.y - height - TAIL_GAP
	)
	# Keep it on screen and off the player's body: if the bubble would cover
	# the player's head, lift it above the player instead.
	pos.x = clampf(pos.x, BUBBLE_SAFE.position.x, BUBBLE_SAFE.end.x - width)
	pos.y = clampf(pos.y, BUBBLE_SAFE.position.y, BUBBLE_SAFE.end.y - height)
	var player_rect: Rect2 = _player_screen_rect()
	if player_rect.size != Vector2.ZERO and Rect2(pos, Vector2(width, height)).intersects(player_rect):
		pos.y = clampf(player_rect.position.y - height - TAIL_GAP,
			BUBBLE_SAFE.position.y, BUBBLE_SAFE.end.y - height)
	_bubble.position = pos
	if _body != null:
		_body.size = Vector2(width - BUBBLE_PAD * 2.0, height - 20.0)


func _bubble_height() -> float:
	return BUBBLE_HEIGHT + (2.0 if _pages.size() > 1 else 0.0)


func _bubble_anchor_screen() -> Vector2:
	if _echo == null:
		return Vector2(320.0, 180.0)
	var head: Vector2 = _echo.global_position + Vector2(0.0, -26.0)
	return _world_to_screen(head)


func _world_to_screen(world: Vector2) -> Vector2:
	if _cine_camera == null:
		return world
	return world - _cine_camera.get_screen_center_position() + VIEW_SIZE * 0.5


func _player_screen_rect() -> Rect2:
	if _player == null:
		return Rect2()
	var feet: Vector2 = _world_to_screen(_player.global_position)
	return Rect2(feet + Vector2(-8.0, -34.0), Vector2(16.0, 34.0))


func _set_bubble_visible(value: bool) -> void:
	if _bubble != null:
		_bubble.visible = value
	if _hint != null:
		_hint.visible = value
	if value:
		_update_bubble()


func _update_world_visuals(delta: float) -> void:
	_symbol_time += delta
	_echo_time += delta
	if _echo != null and _echo.visible:
		_echo.frame = int(_echo_time * 4.0) % 6
	_update_echo_positions()


func _update_echo_positions() -> void:
	if _player == null:
		return
	var feet: Vector2 = _player.global_position
	if _echo != null:
		_echo.global_position = feet + Vector2(-26.0, -74.0)
	if _projection != null:
		_projection.global_position = feet + Vector2(8.0, -1.0)
		if _phase == Phase.DIALOGUE:
			_projection.modulate.a = 0.42 + 0.16 * (0.5 + 0.5 * sin(_echo_time * 3.4))


func _update_symbols() -> void:
	if _player == null:
		return
	var bob: int = 0 if fmod(_symbol_time, 0.56) < 0.30 else -1
	var base: Vector2 = _player.global_position + Vector2(0.0, -54.0 + float(bob))
	if _question != null:
		_question.global_position = base
	if _exclaim != null:
		_exclaim.global_position = base


func _update_camera(delta: float) -> void:
	if _cine_camera == null:
		return
	var follow: float = clampf(delta * 7.0, 0.0, 1.0)
	_cine_camera.global_position = _cine_camera.global_position.lerp(_cam_focus, follow)


func _focus_on_player() -> Vector2:
	if _player == null:
		return Vector2(320.0, 180.0)
	return Vector2(clampf(_player.global_position.x, 320.0, 2200.0), 180.0)


func _guard_focus() -> Vector2:
	if _guard == null:
		return _focus_on_player()
	return Vector2(clampf(_guard.global_position.x, 320.0, 2200.0), 180.0)


func _play_page(index: int) -> void:
	if index < 0 or index >= _pages.size():
		return
	_page_index = index
	_reveal = 0.0
	_body.text = ""
	_page_label.text = "%d / %d" % [index + 1, _pages.size()]
	_set_bubble_visible(true)
	_echo.visible = true
	_projection.visible = true
	_echo.modulate = Color(1.0, 1.0, 1.0, 0.86)
	_projection.modulate = Color(0.6, 0.95, 1.0, 0.62)
	_update_echo_positions()
	_update_bubble()


func _short_press() -> void:
	if not _active or _phase != Phase.DIALOGUE or _page_index < 0:
		return
	var full: String = _pages[_page_index]
	if _reveal < float(full.length()):
		_reveal = float(full.length())
		_body.text = full
		return
	if _page_index + 1 >= _pages.size():
		_skipped = false
		_begin_outro()
		return
	_play_page(_page_index + 1)


func _begin_outro() -> void:
	if not _active:
		return
	_phase = Phase.OUTRO
	_t = 0.0
	_bar_target = 0.0
	_set_bubble_visible(false)
	_question.visible = false
	_exclaim.visible = false
	_echo.visible = false
	_projection.visible = false


func _complete_finish() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	_ui.visible = false
	_bar_height = 0.0
	_bar_target = 0.0
	_apply_bar_height()
	_set_bubble_visible(false)
	_question.visible = false
	_exclaim.visible = false
	_echo.visible = false
	_projection.visible = false
	if _player != null:
		_player.end_cinematic_walk()
	_await_release = _space_held or Input.is_physical_key_pressed(KEY_SPACE)
	if _await_release:
		# Keep the control lock, guard cinematic mode, camera ownership and HUD
		# hidden until the same skip press is released. is_active() includes
		# this state, so pause/focus/R still abort it explicitly.
		set_process(true)
		return
	_space_held = false
	_restore_control()


func _restore_control() -> void:
	_await_release = false
	_space_held = false
	if _cine_camera != null:
		_cine_camera.enabled = false
	if _player_camera != null:
		_player_camera.make_current()
	if _player != null:
		_player.unlock_after_cinematic()
	if _guard != null:
		_guard.set_cinematic_mode(false)
	finished.emit(_skipped)


func abort() -> void:
	var was_controlling: bool = _active or _await_release
	if not was_controlling:
		return
	_active = false
	_await_release = false
	_space_held = false
	_skipped = true
	set_process(false)
	_bar_height = 0.0
	_bar_target = 0.0
	_apply_bar_height()
	_set_visible_all(false)
	_set_bubble_visible(false)
	_question.visible = false
	_exclaim.visible = false
	_echo.visible = false
	_projection.visible = false
	if _cine_camera != null:
		_cine_camera.enabled = false
	if _player_camera != null:
		_player_camera.make_current()
	if _player != null:
		_player.end_cinematic_walk()
		_player.unlock_after_cinematic()
	if _guard != null:
		_guard.set_cinematic_mode(false)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.echo:
		return
	if int(key_event.physical_keycode) != int(KEY_SPACE):
		return
	if not _active:
		# The await-release boundary has no animation, but it still owns input.
		if _await_release:
			if not key_event.pressed:
				_space_held = false
				if not Input.is_physical_key_pressed(KEY_SPACE):
					_restore_control()
			get_viewport().set_input_as_handled()
		return
	if key_event.pressed:
		_space_held = true
		_space_time = 0.0
		_space_action_done = false
		get_viewport().set_input_as_handled()
	else:
		if (
			_space_held
			and not _space_action_done
			and _space_time < SKIP_HOLD
			and not _await_release
		):
			_short_press()
		_space_held = false
		get_viewport().set_input_as_handled()


func _set_visible_all(value: bool) -> void:
	if _ui != null:
		_ui.visible = value
	if not value:
		_question.visible = false
		_exclaim.visible = false
		_echo.visible = false
		_projection.visible = false


func has_played() -> bool:
	return _played


func mark_played() -> void:
	_played = true


func reset_for_new_run() -> void:
	_active = false
	_await_release = false
	_space_held = false
	_played = false
	_phase = Phase.IDLE
	_page_index = -1
	_skipped = false
	_door_cue_fired = false
	_door_turned = false
	_pages = PAGES
	set_process(false)
	_set_visible_all(false)
	if _player_camera != null:
		_player_camera.make_current()
	if _player != null:
		_player.end_cinematic_walk()
		_player.unlock_after_cinematic()
	if _guard != null:
		_guard.set_cinematic_mode(false)


func is_active() -> bool:
	# Active animation OR the held-space await-release boundary. Both occupy
	# control, so the level's E/J gates, pause, focus and R paths all see it.
	return _active or _await_release


func is_playing() -> bool:
	return _active


func is_awaiting_release() -> bool:
	return _await_release


func get_phase_name() -> String:
	match _phase:
		Phase.IDLE:
			return "IDLE"
		Phase.INTRO:
			return "INTRO"
		Phase.WALK:
			return "WALK"
		Phase.DOOR:
			return "DOOR"
		Phase.GUARD:
			return "GUARD"
		Phase.ECHO:
			return "ECHO"
		Phase.DIALOGUE:
			return "DIALOGUE"
		Phase.OUTRO:
			return "OUTRO"
		_:
			return "UNKNOWN"


func get_page_index() -> int:
	return _page_index


func get_body_text() -> String:
	return _body.text if _body != null else ""


func get_full_page_text() -> String:
	if _page_index < 0 or _page_index >= _pages.size():
		return ""
	return _pages[_page_index]


func get_page_count() -> int:
	return _pages.size()


func is_defeated_dialogue() -> bool:
	return _pages == DEFEATED_PAGES


## Test-only finite setup for the held-space boundary. It deliberately does not
## emit finished; E/J/pause/focus/R must clean it through abort()/reset.
func debug_force_await_release() -> void:
	if not _active and not _await_release:
		return
	_active = false
	_await_release = true
	_space_held = true
	_ui.visible = false
	_set_bubble_visible(false)
	_question.visible = false
	_exclaim.visible = false
	_echo.visible = false
	_projection.visible = false
	set_process(true)


func get_question_visible() -> bool:
	return _question != null and _question.visible


func get_exclaim_visible() -> bool:
	return _exclaim != null and _exclaim.visible


func get_echo_visible() -> bool:
	return _echo != null and _echo.visible


func is_bubble_visible() -> bool:
	return _bubble != null and _bubble.visible


func get_bubble_rect() -> Rect2:
	if _bubble == null or not _bubble.visible:
		return Rect2()
	return Rect2(_bubble.position, _bubble.size)


func get_bubble_anchor_screen() -> Vector2:
	return _bubble_anchor_screen()


func get_echo_screen_rect() -> Rect2:
	if _echo == null:
		return Rect2()
	var p: Vector2 = _world_to_screen(_echo.global_position) + Vector2(-20.0, -40.0)
	return Rect2(p, Vector2(40.0, 40.0))


func get_hint_visible() -> bool:
	return _hint != null and _hint.visible


func get_hint_rect() -> Rect2:
	if _hint == null:
		return Rect2()
	return Rect2(_hint.position, _hint.size)


func get_hint_text() -> String:
	return _hint.text if _hint != null else ""


func get_hint_text_width() -> float:
	if _hint == null or _font == null:
		return 0.0
	return _font.get_string_size(_hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x


func get_guard_beat_showed_rebuild() -> bool:
	return _guard_beat_shown_rebuild


func is_ui_visible() -> bool:
	return _ui != null and _ui.visible
