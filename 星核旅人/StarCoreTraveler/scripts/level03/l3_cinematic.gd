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
## Input: F completes the current line or advances (the same tutorial_next
## action as GuideEcho); holding Space for 0.6 s skips the whole segment. A
## short Space tap never advances. Control returns only after Space is released,
## so the same press cannot jump the player. While the player is still holding
## that skip press, the cinematic remains a control-occupied state
## (is_active()/is_awaiting_release()); E/J, the pause page, focus loss and R
## all see it as active and clean it up explicitly.
##
## Framing (2026-11-18): only this film's own Camera2D moves. With the full
## 44 px letterbox it looks from Y194 (limit_bottom 374) instead of the normal
## Y180, so the player's and the guard's feet stay 10 px above the bottom bar.
## The Y offset follows the bar height itself in and out, so the push-in and the
## OUTRO hand-off back to the normal player camera are continuous (no jump, no
## hidden feet, no shortened bars). The normal Camera2D, body coordinates and
## collisions are untouched.
##
## The echo is projected from the real `VisualRoot/Talisman` chest sprite (see
## echo_amulet_projection.gd). The old foot-origin EchoProjection texture is
## kept as a source but is never shown again.

signal finished(skipped: bool)
signal stone_cue_requested

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
## Head bubble (play-test revision): no bottom 608x68 dialogue bar; the 44 px
## top/bottom letterbox is kept.
const BAR_HEIGHT: float = 44.0
## Normal gameplay camera centre; the film returns to exactly this on OUTRO.
const NORMAL_FOCUS_Y: float = 180.0
## Full-letterbox film centring: feet at world 320 map to screen 306, the
## bottom bar starts at 316 -> 10 px clear (>= 8 px).
const CINE_FOCUS_Y: float = 194.0
## limit_bottom must allow the centre to reach 194 (194 + 360/2 = 374).
const CINE_LIMIT_BOTTOM: float = 374.0
## The chest projection beat length before the original page 1 opens.
const ECHO_DURATION: float = 0.90
const BUBBLE_WIDTH: float = 246.0
const BUBBLE_HEIGHT: float = 60.0
const BUBBLE_PAD: float = 6.0
const BUBBLE_SAFE: Rect2 = Rect2(8.0, 48.0, 624.0, 264.0)
const TAIL_GAP: float = 8.0
const SKIP_HOLD: float = 0.6
const TEXT_CPS: float = 34.0
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const PANEL_BG: Color = Color(0.012, 0.028, 0.035, 0.95)
const PANEL_BORDER: Color = Color(0.45, 0.66, 0.63, 0.85)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const PROMPT_FOOTER_SCRIPT = preload("res://scripts/ui/prompt_footer.gd")
const DIALOGUE_VOICE_SCRIPT = preload("res://scripts/narrative/dialogue_voice.gd")

const ECHO_SHEET: Texture2D = preload("res://assets/guide_echo_20261113/guide_echo_idle_6f_s40.png")
const PROJECTION: Texture2D = preload("res://assets/level03_prototype/echo_projection.png")
const QUESTION: Texture2D = preload("res://assets/level03_prototype/emote_question.png")
const EXCLAIM: Texture2D = preload("res://assets/level03_prototype/emote_exclaim.png")

const PAGES: Array[String] = [
	"光打碎石壳没用。\n胸口的星核还在，它就会重新站起来。",
	"等它开始把你往身边拉。\n那时候，胸口的星核会露出来。",
	"换成和它不同的相性，\n趁星核露出来，朝胸口挥剑。",
]

## The post-fight branch points at the actual next action instead of describing
## a charge the player can no longer see. No guard state is reset or revived.
const DEFEATED_PAGES: Array[String] = [
	"它留下的星核能打开城门。\n把核带到门边，嵌进去。",
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
var _skip_bar: SkipHoldBar = null
var _prompt_footer: Control = null
var _speaker: Label = null
var _body: Label = null
var _page_label: Label = null
var _hint: Label = null
var _question: Sprite2D = null
var _exclaim: Sprite2D = null
var _echo: Sprite2D = null
var _projection: Sprite2D = null
var _projection_fx: EchoAmuletProjection = null
var _voice = null
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
	# Film-only overscan: the extra 14 px below the normal view is always under
	# the 44 px letterbox. The normal player camera keeps limit_bottom 360.
	_cine_camera.limit_bottom = CINE_LIMIT_BOTTOM
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

	# Hold-to-skip feedback only (bottom-right, same 96x6 geometry as the L1
	# opening). It is part of this film's CanvasLayer and never changes the
	# skip timer, await-release boundary or input handling.
	_skip_bar = SkipHoldBar.new()
	_skip_bar.name = "SkipHoldBar"
	_root.add_child(_skip_bar)

	# Shared one-line page footer in this film's own CanvasLayer.  It is
	# presentation only and yields the corner to the hold-to-skip bar.
	_prompt_footer = PROMPT_FOOTER_SCRIPT.new()
	_prompt_footer.name = "PromptFooter"
	_root.add_child(_prompt_footer)

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

	# No bottom key hint: bindings live only on the pause page. The reveal voice
	# is a minimal helper shared with GuideEcho.
	_voice = DIALOGUE_VOICE_SCRIPT.new()
	_voice.name = "EchoVoice"
	add_child(_voice)


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
	# Source kept, usage retired: the echo no longer originates at the feet.
	_projection.visible = false
	add_child(_projection)

	_projection_fx = EchoAmuletProjection.new()
	_projection_fx.name = "AmuletEchoProjection"
	# Above the echo (19) so the 1 px scan band and rim really cover the imaged
	# sprite instead of hiding behind it; below the HUD bubble/letterbox (>=12
	# CanvasLayer) and level with the emote marks.
	_projection_fx.z_index = 20
	_projection_fx.visible = false
	add_child(_projection_fx)


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
	if _skip_bar != null:
		_skip_bar.hide_progress()
	_hide_prompt_footer()
	_pages = DEFEATED_PAGES if (_guard != null and _guard.is_defeated()) else PAGES
	if _player != null:
		_player.lock_for_cinematic()
		_cam_focus = _focus_on_player()
	if _projection_fx != null:
		_projection_fx.setup(_player, _echo)
		_projection_fx.start()
	if _guard != null:
		_guard.set_cinematic_mode(true)
		_guard_beat_shown_rebuild = _guard.is_scattered()
	if _cine_camera != null:
		_cine_camera.global_position = _cam_focus
		_cine_camera.enabled = true
		_cine_camera.make_current()
	_set_visible_all(true)
	_set_bubble_visible(false)
	_echo.visible = false
	_projection.visible = false
	_bar_target = BAR_HEIGHT
	_bar_height = 0.0
	_apply_bar_height()
	_update_symbols()
	set_process(true)


func _process(delta: float) -> void:
	if _await_release:
		_hide_prompt_footer()
		if _skip_bar != null:
			_skip_bar.hide_progress()
		if not _space_held and not Input.is_physical_key_pressed(KEY_SPACE):
			_restore_control()
		return
	if not _active:
		_hide_prompt_footer()
		if _skip_bar != null:
			_skip_bar.hide_progress()
		return
	if _space_held and not _space_action_done:
		_space_time += delta
		if _space_time >= SKIP_HOLD:
			_space_action_done = true
			_skipped = true
			if _skip_bar != null:
				_skip_bar.hide_progress()
			if _phase == Phase.OUTRO:
				_complete_finish()
			else:
				_begin_outro()
			return
		if _skip_bar != null:
			_skip_bar.update_hold(true, _space_time, SKIP_HOLD)
	else:
		if _skip_bar != null:
			_skip_bar.hide_progress()
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
			_update_echo_positions()
			if _projection_fx != null:
				_projection_fx.set_time(_t)
				_echo.visible = _projection_fx.is_echo_visible()
				_echo.modulate = Color(1.0, 1.0, 1.0, _projection_fx.get_echo_alpha())
			_projection.visible = false
			if _t >= ECHO_DURATION:
				_phase = Phase.DIALOGUE
				_t = 0.0
				_play_page(0)
		Phase.DIALOGUE:
			_reveal = minf(_reveal + delta * TEXT_CPS, float(_pages[_page_index].length()))
			_body.text = _pages[_page_index].substr(0, int(_reveal))
			if _voice != null:
				_voice.update_text(_pages[_page_index], int(_reveal), delta)
			_update_echo_positions()
			if _projection_fx != null:
				_projection_fx.set_link_time(_echo_time)
			_update_bubble()
		Phase.OUTRO:
			if _t >= 0.30:
				_complete_finish()
	_update_prompt_footer()
	_update_camera(delta)


## Only a fully revealed page that really waits for F shows the footer.
## Typing, OUTRO/AWAIT_RELEASE and the hold-to-skip bar all hide it.
func _update_prompt_footer() -> void:
	if _prompt_footer == null:
		return
	var waiting: bool = (
		_active
		and _phase == Phase.DIALOGUE
		and _page_index >= 0
		and _page_index < _pages.size()
		and _bubble != null
		and _bubble.visible
		and not (_skip_bar != null and _skip_bar.visible)
	)
	if waiting:
		var full: String = _pages[_page_index]
		if _reveal < float(full.length()):
			waiting = false
		else:
			var text: String = (
				PROMPT_FOOTER_SCRIPT.PAGE_FOOTER
				if _page_index + 1 < _pages.size()
				else PROMPT_FOOTER_SCRIPT.SINGLE_FOOTER
			)
			_prompt_footer.call("show_footer", text)
	if not waiting:
		_prompt_footer.call("hide_footer")


func _hide_prompt_footer() -> void:
	if _prompt_footer != null:
		_prompt_footer.call("hide_footer")


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
	var width: float = BUBBLE_WIDTH
	var height: float = _bubble_height()
	var echo_rect: Rect2 = get_echo_screen_rect()
	var player_rect: Rect2 = _player_screen_rect()
	var pos: Vector2 = _bubble_position(echo_rect, player_rect, width, height)
	_bubble.size = Vector2(width, height)
	_bubble.position = pos
	if _body != null:
		_body.size = Vector2(width - BUBBLE_PAD * 2.0, height - 20.0)


func _bubble_height() -> float:
	if _font == null or _page_index < 0 or _page_index >= _pages.size():
		return BUBBLE_HEIGHT
	var body_width: float = BUBBLE_WIDTH - BUBBLE_PAD * 2.0
	var measured: Vector2 = _font.get_multiline_string_size(
		_pages[_page_index], HORIZONTAL_ALIGNMENT_LEFT, body_width, 12
	)
	var body_height: float = maxf(ceilf(measured.y), 12.0)
	return 19.0 + body_height + 6.0


## Prefer above the real echo pixels, 8 px clear. If the HUD safe area blocks
## the top, try above the player, then the side. Deterministic for the same
## geometry, so the reveal cannot flip it.
func _bubble_position(echo_rect: Rect2, player_rect: Rect2, width: float, height: float) -> Vector2:
	var above: Vector2 = Vector2(
		echo_rect.get_center().x - width * 0.5,
		echo_rect.position.y - height - TAIL_GAP
	)
	above.x = clampf(above.x, BUBBLE_SAFE.position.x, BUBBLE_SAFE.end.x - width)
	var rect: Rect2 = Rect2(above, Vector2(width, height))
	if above.y >= BUBBLE_SAFE.position.y and not rect.intersects(player_rect):
		return above
	var above_player: Vector2 = Vector2(
		player_rect.get_center().x - width * 0.5,
		player_rect.position.y - height - TAIL_GAP
	)
	above_player.x = clampf(above_player.x, BUBBLE_SAFE.position.x, BUBBLE_SAFE.end.x - width)
	var prect: Rect2 = Rect2(above_player, Vector2(width, height))
	if above_player.y >= BUBBLE_SAFE.position.y and not prect.intersects(echo_rect):
		return above_player
	var right: Vector2 = Vector2(echo_rect.end.x + TAIL_GAP, echo_rect.position.y - 4.0)
	right.x = clampf(right.x, BUBBLE_SAFE.position.x, BUBBLE_SAFE.end.x - width)
	right.y = clampf(right.y, BUBBLE_SAFE.position.y, BUBBLE_SAFE.end.y - height)
	var right_rect: Rect2 = Rect2(right, Vector2(width, height))
	if right_rect.end.x <= BUBBLE_SAFE.end.x and not right_rect.intersects(player_rect):
		return right
	var left: Vector2 = Vector2(echo_rect.position.x - width - TAIL_GAP, echo_rect.position.y - 4.0)
	left.x = clampf(left.x, BUBBLE_SAFE.position.x, BUBBLE_SAFE.end.x - width)
	left.y = clampf(left.y, BUBBLE_SAFE.position.y, BUBBLE_SAFE.end.y - height)
	var left_rect: Rect2 = Rect2(left, Vector2(width, height))
	if left_rect.position.x >= BUBBLE_SAFE.position.x and not left_rect.intersects(player_rect):
		return left
	above.x = clampf(above.x, BUBBLE_SAFE.position.x, BUBBLE_SAFE.end.x - width)
	above.y = clampf(above.y, BUBBLE_SAFE.position.y, BUBBLE_SAFE.end.y - height)
	return above


func _bubble_anchor_screen() -> Vector2:
	var echo_rect: Rect2 = get_echo_screen_rect()
	if echo_rect.size == Vector2.ZERO:
		return Vector2(320.0, 180.0)
	return Vector2(echo_rect.get_center().x, echo_rect.position.y)


func _world_to_screen(world: Vector2) -> Vector2:
	if _cine_camera == null:
		return world
	return world - _cine_camera.get_screen_center_position() + VIEW_SIZE * 0.5


func _player_screen_rect() -> Rect2:
	if _player == null:
		return Rect2()
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var feet: Vector2 = canvas * _player.global_position
	return Rect2(feet + Vector2(-8.0, -34.0), Vector2(16.0, 34.0))


## Actual visible sprite rectangle in viewport coordinates. The projection
## module resolves the echo sheet's real alpha bounding box (frame 48x64 has
## transparent margins) so the bubble avoids the drawn pixels; the full frame
## rect is used only before the module has measured it.
func get_echo_screen_rect() -> Rect2:
	if _echo == null or not is_inside_tree():
		return Rect2()
	if _projection_fx != null:
		if not _projection_fx.has_origin():
			# Aborted chest projection: there is no placed echo, so the bubble
			# must not treat the untouched sprite origin as a real anchor.
			return Rect2()
		if _projection_fx.has_art():
			return _projection_fx.get_echo_art_screen_rect()
	var xf: Transform2D = _echo.get_global_transform_with_canvas()
	return xf * _echo.get_rect()


func _set_bubble_visible(value: bool) -> void:
	if _bubble != null:
		_bubble.visible = value
	if value:
		_update_bubble()
	else:
		if _voice != null:
			_voice.stop()


func _update_world_visuals(delta: float) -> void:
	_symbol_time += delta
	_echo_time += delta
	if _echo != null and _echo.visible:
		_echo.frame = int(_echo_time * 4.0) % 6
	_update_echo_positions()


func _update_echo_positions() -> void:
	if _player == null:
		return
	# The imaging area is placed forward/above the real chest talisman. When the
	# chest node is missing the projection module aborts, so the echo stays
	# hidden instead of falling back to a foot position.
	if _projection_fx != null and _projection_fx.has_origin():
		_projection_fx.place_echo()
	else:
		_echo.visible = false
	if _projection != null:
		_projection.visible = false


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
	if _phase == Phase.OUTRO:
		# The vertical offset rides the closing letterbox, so the picture slides
		# back to the normal Y180 exactly as the bars reveal it. No snap.
		_cam_focus.y = _focus_y()
	var follow: float = clampf(delta * _follow_speed(), 0.0, 1.0)
	var pos: Vector2 = _cine_camera.global_position
	pos.x = lerpf(pos.x, _cam_focus.x, follow)
	pos.y = _cam_focus.y
	_cine_camera.global_position = pos


## The film's vertical centre is tied to the real bar height (also during the
## 0.2 s bar entrance and the OUTRO exit), which keeps the foot clearance at
## >= 10 px on every frame instead of lagging behind the screen edge.
func _focus_y() -> float:
	var k: float = clampf(_bar_height / BAR_HEIGHT, 0.0, 1.0)
	return lerpf(NORMAL_FOCUS_Y, CINE_FOCUS_Y, k)


func _follow_speed() -> float:
	# The chest beat starts right after the guard close-up; a slightly quicker
	# pan lands the camera on the player before the beam/imaging starts.
	if _phase == Phase.ECHO or _phase == Phase.DIALOGUE:
		return 16.0
	return 7.0


func _focus_on_player() -> Vector2:
	if _player == null:
		return Vector2(320.0, _focus_y())
	return Vector2(clampf(_player.global_position.x, 320.0, 2200.0), _focus_y())


func _guard_focus() -> Vector2:
	if _guard == null:
		return _focus_on_player()
	return Vector2(clampf(_guard.global_position.x, 320.0, 2200.0), _focus_y())


func _play_page(index: int) -> void:
	if index < 0 or index >= _pages.size():
		return
	_page_index = index
	_reveal = 0.0
	_body.text = ""
	if _voice != null:
		_voice.begin_page()
	_page_label.text = "%d / %d" % [index + 1, _pages.size()]
	_set_bubble_visible(true)
	_update_echo_positions()
	if _projection_fx != null:
		_projection_fx.enter_link()
		_echo.visible = _projection_fx.is_echo_visible()
	_echo.modulate = Color(1.0, 1.0, 1.0, 0.86)
	_projection.visible = false
	_update_bubble()


func _short_press() -> void:
	if not _active or _phase != Phase.DIALOGUE or _page_index < 0:
		return
	var full: String = _pages[_page_index]
	if _reveal < float(full.length()):
		_reveal = float(full.length())
		_body.text = full
		if _voice != null:
			_voice.complete_reveal()
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
	if _voice != null:
		_voice.stop()
	_set_bubble_visible(false)
	_hide_prompt_footer()
	if _skip_bar != null:
		_skip_bar.hide_progress()
	_question.visible = false
	_exclaim.visible = false
	_clear_projection_fx()


## Beam, rim, scan and the echo itself are presentation only: skip, abort,
## completion, pause/focus and R clear them immediately, and the echo returns to
## its neutral modulate so no tint or material state survives.
func _clear_projection_fx() -> void:
	if _projection_fx != null:
		_projection_fx.stop()
	if _echo != null:
		_echo.visible = false
		_echo.modulate = Color.WHITE
	if _projection != null:
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
	if _skip_bar != null:
		_skip_bar.hide_progress()
	_set_bubble_visible(false)
	_hide_prompt_footer()
	_question.visible = false
	_exclaim.visible = false
	_clear_projection_fx()
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
	if _skip_bar != null:
		_skip_bar.hide_progress()
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
	if _voice != null:
		_voice.stop()
	set_process(false)
	_bar_height = 0.0
	_bar_target = 0.0
	_apply_bar_height()
	_set_visible_all(false)
	_set_bubble_visible(false)
	_hide_prompt_footer()
	_question.visible = false
	_exclaim.visible = false
	_clear_projection_fx()
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
	if not _active and not _await_release:
		return
	# F is the one dialogue key, shared with GuideEcho. It only does something
	# while a page is open, but it is consumed so an ended film cannot leak it.
	if key_event.is_action_pressed(&"tutorial_next"):
		if key_event.pressed and not _await_release:
			_short_press()
		get_viewport().set_input_as_handled()
		return
	if int(key_event.physical_keycode) != int(KEY_SPACE):
		return
	if not _active:
		# The await-release boundary has no animation, but it still owns input.
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
		# A short Space tap is deliberately inert; only the SKIP_HOLD timer in
		# _process skips, and it skips the whole segment.
		_space_held = false
		if _skip_bar != null:
			_skip_bar.hide_progress()
		get_viewport().set_input_as_handled()


func _set_visible_all(value: bool) -> void:
	if _ui != null:
		_ui.visible = value
	if not value:
		if _skip_bar != null:
			_skip_bar.hide_progress()
		_hide_prompt_footer()
		_question.visible = false
		_exclaim.visible = false
		_clear_projection_fx()


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
	_bar_height = 0.0
	_bar_target = 0.0
	_apply_bar_height()
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


## Seconds inside the current phase (the same pausable clock that drives the
## chest projection). Read-only evidence helper.
func get_phase_time() -> float:
	return _t


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
	if _skip_bar != null:
		_skip_bar.hide_progress()
	_set_bubble_visible(false)
	_hide_prompt_footer()
	_question.visible = false
	_exclaim.visible = false
	_clear_projection_fx()
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


func get_hint_visible() -> bool:
	return false


func get_hint_rect() -> Rect2:
	return Rect2()


func get_hint_text() -> String:
	return ""


func get_hint_text_width() -> float:
	return 0.0


func get_guard_beat_showed_rebuild() -> bool:
	return _guard_beat_shown_rebuild


func is_ui_visible() -> bool:
	return _ui != null and _ui.visible


# --- read-only evidence helpers (used by the 2026-11-18 cinematic probe) ------

func get_projection_fx() -> EchoAmuletProjection:
	return _projection_fx


func get_projection_state() -> Dictionary:
	if _projection_fx == null:
		return {"beat": "MISSING", "failed": true}
	return _projection_fx.get_debug_state()


func get_cine_camera() -> Camera2D:
	return _cine_camera


func get_cine_limit_bottom() -> float:
	return float(_cine_camera.limit_bottom) if _cine_camera != null else 0.0


## Actual rendered screen centre (limits applied), not the requested target.
func get_cine_screen_center() -> Vector2:
	if _cine_camera == null:
		return Vector2.ZERO
	return _cine_camera.get_screen_center_position()


func get_focus_target() -> Vector2:
	return _cam_focus


func get_bottom_bar_top() -> float:
	return VIEW_SIZE.y - _bar_height


func get_player_feet_screen() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	return get_viewport().get_canvas_transform() * _player.global_position


## Guard feet: the guard sprite's own foot row, which is its global position for
## the 2x golem sheet. Read-only.
func get_guard_feet_screen() -> Vector2:
	if _guard == null:
		return Vector2.ZERO
	return get_viewport().get_canvas_transform() * _guard.global_position


# --- Hold-to-skip bar read-only helpers (tests / captures) ------------------

func is_skip_bar_visible() -> bool:
	return _skip_bar != null and _skip_bar.visible


func get_skip_bar_progress() -> float:
	return _skip_bar.get_progress() if _skip_bar != null else 0.0


func get_skip_bar_fill_width() -> float:
	return _skip_bar.get_fill_width() if _skip_bar != null else 0.0


func get_skip_bar_rect() -> Rect2:
	return _skip_bar.get_bar_rect() if _skip_bar != null else Rect2()


func get_skip_bar_label_text() -> String:
	return _skip_bar.get_label_text() if _skip_bar != null else ""


func get_skip_bar_label_rect() -> Rect2:
	return _skip_bar.get_label_rect() if _skip_bar != null else Rect2()


func get_skip_bar_label_font_size() -> int:
	return _skip_bar.get_label_font_size() if _skip_bar != null else 0


func get_skip_bar_style() -> StyleBoxFlat:
	return _skip_bar.get_style() if _skip_bar != null else null


# --- Shared page footer read-only helpers (tests / captures) ----------------

func get_prompt_footer() -> Control:
	return _prompt_footer


func is_prompt_footer_visible() -> bool:
	return _prompt_footer != null and _prompt_footer.visible


func get_prompt_footer_text() -> String:
	if _prompt_footer == null:
		return ""
	return String(_prompt_footer.call("get_text"))
