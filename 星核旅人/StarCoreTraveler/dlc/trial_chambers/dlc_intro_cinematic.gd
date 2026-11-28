class_name DlcIntroCinematic
extends CanvasLayer

## Shared, skippable opening film for the three DLC chapters.
##
## One full-screen CanvasLayer above the chapter HUD.  It never pauses the tree
## and never starts/stops the chapter music; the owning chapter keeps the player
## in `lock_for_cinematic()` and calls `start()`.  The chapter music therefore
## runs underneath every beat.
##
## Input: F (or the shared `tutorial_next` action) skips at once; holding Space
## for SKIP_HOLD also skips.  A short Space tap is inert.  When the skip came
## from a held Space, the film stays control-occupied until that key is released,
## so the same press cannot become a jump.  Every key the film consumes is
## marked handled; other gameplay keys stay ignored by the chapter's own
## `_intro_active` early return and the player's cinematic lock.
##
## Timeline: black -> beats -> fade to the live scene -> finished(skipped).
## Subclasses only set `duration`, register cue sounds and draw their stage.
## The stage is a Node2D inside this CanvasLayer, so it is in 640x360 screen
## space and never affected by the gameplay Camera2D.

signal finished(skipped: bool)

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const VIEW_CENTER: Vector2 = Vector2(320.0, 180.0)
const FADE_IN_TIME: float = 0.30
const FADE_OUT_TIME: float = 0.38
const SKIP_FADE_TIME: float = 0.20
const SKIP_HOLD: float = 0.60
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DIM: Color = Color("#728889")
const BLACK: Color = Color(0.004, 0.010, 0.013, 1.0)

const AUDIO_POOL_SIZE: int = 6


class IntroStage:
	extends Node2D
	var host: DlcIntroCinematic = null

	func _draw() -> void:
		if host != null:
			host._draw_intro(self)


var duration: float = 3.0

var _active: bool = false
var _finished: bool = false
var _finished_emitted: bool = false
var _skipped: bool = false
var _skip_count: int = 0
var _time: float = 0.0
var _finishing: bool = false
var _finish_left: float = 0.0
var _finish_total: float = 1.0
var _finish_start_alpha: float = 1.0
var _await_release: bool = false
var _space_held: bool = false
var _space_time: float = 0.0
var _space_latched: bool = false
var _capture_mode: bool = false

var _bg: ColorRect = null
var _stage: IntroStage = null
var _ui_root: Control = null
var _footer: Control = null
var _hold_bg: ColorRect = null
var _hold_fill: ColorRect = null
var _font: Font = null
var _played_cues: Dictionary = {}
var _cue_count: int = 0
var _audio_pool: Array[AudioStreamPlayer] = []
var _audio_cursor: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = true
	_font = _load_font()
	_build_surface()
	_apply_alpha(0.0)
	set_process(false)
	set_process_unhandled_input(false)
	_setup_intro()


func _load_font() -> Font:
	return UiFont.get_font()


func _build_surface() -> void:
	_bg = ColorRect.new()
	_bg.name = "Black"
	_bg.position = Vector2.ZERO
	_bg.size = VIEW_SIZE
	_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_stage = IntroStage.new()
	_stage.name = "Stage"
	_stage.host = self
	add_child(_stage)

	_ui_root = Control.new()
	_ui_root.name = "IntroUI"
	_ui_root.position = Vector2.ZERO
	_ui_root.size = VIEW_SIZE
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	_footer = Control.new()
	_footer.name = "SkipFooter"
	_footer.position = Vector2.ZERO
	_footer.size = VIEW_SIZE
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_footer)

	_hold_bg = ColorRect.new()
	_hold_bg.name = "HoldBarBG"
	_hold_bg.position = Vector2(420.0, 326.0)
	_hold_bg.size = Vector2(96.0, 4.0)
	_hold_bg.color = Color(0.02, 0.04, 0.05, 0.85)
	_hold_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_bg.visible = false
	_footer.add_child(_hold_bg)

	_hold_fill = ColorRect.new()
	_hold_fill.name = "HoldBarFill"
	_hold_fill.position = Vector2(421.0, 327.0)
	_hold_fill.size = Vector2(0.0, 2.0)
	_hold_fill.color = GOLD
	_hold_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(_hold_fill)

	# Footer: F 跳过 · 长按空格.  The keycaps are real 16 px boxes so they read
	# like the project's other key hints instead of plain text; the hold bar
	# under 空格 shows the hold, so the verb appears once.
	_add_keycap("F", Rect2(420.0, 334.0, 16.0, 16.0), 12)
	_add_footer_text("跳过", Vector2(440.0, 334.0), 30.0)
	_add_footer_text("·", Vector2(466.0, 334.0), 10.0)
	_add_footer_text("长按", Vector2(478.0, 334.0), 30.0)
	_add_keycap("空格", Rect2(506.0, 334.0, 34.0, 16.0), 12)

	_footer.modulate.a = 0.0


func _add_footer_text(text_value: String, position_value: Vector2, width: float) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.position = position_value
	label.size = Vector2(width, 16.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(label)


func _add_keycap(text_value: String, rect: Rect2, font_size: int) -> void:
	var outer: ColorRect = ColorRect.new()
	outer.position = rect.position
	outer.size = rect.size
	outer.color = Color(0.018, 0.032, 0.038, 0.96)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(outer)

	var inner: ColorRect = ColorRect.new()
	inner.position = rect.position + Vector2(1.0, 1.0)
	inner.size = rect.size - Vector2(2.0, 2.0)
	inner.color = Color(0.10, 0.14, 0.15, 0.98)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(inner)

	var label: Label = Label.new()
	label.text = text_value
	label.position = rect.position + Vector2(1.0, 0.0)
	label.size = rect.size - Vector2(2.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(label)


# --- lifecycle --------------------------------------------------------------

## Subclasses set `duration` and build their cue streams here.
func _setup_intro() -> void:
	pass


## Subclasses draw the whole film into this CanvasLayer.  Coordinates are the
## project's 640x360 screen space.
func _draw_intro(_canvas: CanvasItem) -> void:
	pass


func start() -> bool:
	if _active or _finished:
		return false
	_active = true
	_finished = false
	_finished_emitted = false
	_skipped = false
	_time = 0.0
	_finishing = false
	_finish_left = 0.0
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_played_cues.clear()
	_cue_count = 0
	visible = true
	_apply_alpha(0.0)
	if _footer != null:
		_footer.modulate.a = 0.0
	_set_hold_bar(false, 0.0)
	set_process(true)
	set_process_unhandled_input(true)
	return true


func _process(delta: float) -> void:
	if _capture_mode or not _active:
		return
	if _finishing:
		_finish_left = maxf(_finish_left - delta, 0.0)
		var progress: float = _finish_left / maxf(_finish_total, 0.001)
		_apply_alpha(clampf(progress, 0.0, 1.0) * _finish_start_alpha)
		if _footer != null:
			_footer.modulate.a = clampf(progress, 0.0, 1.0) * _finish_start_alpha
		if _finish_left <= 0.0:
			_complete_finish()
		return

	_time += delta
	if _space_held and not _space_latched:
		_space_time += delta
		if _space_time >= SKIP_HOLD:
			_space_latched = true
			_request_skip()
			return
	_set_hold_bar(_space_held, clampf(_space_time / SKIP_HOLD, 0.0, 1.0))

	var reveal: float = clampf(_time / FADE_IN_TIME, 0.0, 1.0)
	var footer_alpha: float = 0.0
	if _time > 0.34:
		footer_alpha = clampf((_time - 0.34) / 0.22, 0.0, 1.0)
	if _footer != null:
		_footer.modulate.a = footer_alpha
	_apply_alpha(reveal)

	if _time >= duration - FADE_OUT_TIME:
		_begin_fade(FADE_OUT_TIME)

	_tick_cues()
	if _stage != null:
		_stage.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _capture_mode or not (_active or _await_release):
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)

	if _await_release:
		if code == int(KEY_SPACE) and not key_event.pressed:
			_await_release = false
			_emit_finished()
			get_viewport().set_input_as_handled()
		return

	if key_event.echo:
		get_viewport().set_input_as_handled()
		return

	# F and the shared tutorial_next action both skip immediately.
	if key_event.pressed and (
		code == int(KEY_F) or key_event.is_action_pressed(&"tutorial_next")
	):
		_request_skip()
		get_viewport().set_input_as_handled()
		return

	if code != int(KEY_SPACE):
		return
	if key_event.pressed:
		_space_held = true
		_space_time = 0.0
		_space_latched = false
		get_viewport().set_input_as_handled()
	else:
		_space_held = false
		_space_time = 0.0
		_space_latched = false
		_set_hold_bar(false, 0.0)
		get_viewport().set_input_as_handled()


func _request_skip() -> void:
	if not _active or _finishing:
		return
	_skip_count += 1
	_skipped = true
	_begin_fade(SKIP_FADE_TIME)


func _begin_fade(seconds: float) -> void:
	if _finishing:
		return
	_finishing = true
	_finish_total = maxf(seconds, 0.01)
	_finish_left = _finish_total
	_finish_start_alpha = _stage.modulate.a if _stage != null else 1.0
	_set_hold_bar(false, 0.0)
	set_process(true)


func _complete_finish() -> void:
	if _finished:
		return
	_finished = true
	_active = false
	_finishing = false
	set_process(false)
	if _footer != null:
		_footer.modulate.a = 0.0
	if _bg != null:
		_bg.color.a = 0.0
	if _stage != null:
		_stage.modulate.a = 0.0
	if _space_held or Input.is_physical_key_pressed(KEY_SPACE):
		_await_release = true
		visible = false
		return
	visible = false
	_emit_finished()


func _emit_finished() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	set_process(false)
	set_process_unhandled_input(false)
	visible = false
	finished.emit(_skipped)


func abort() -> void:
	_active = false
	_finishing = false
	_await_release = false
	_stop_audio()
	set_process(false)
	set_process_unhandled_input(false)
	visible = false


func _stop_audio() -> void:
	for player: AudioStreamPlayer in _audio_pool:
		if player == null:
			continue
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	_stop_audio()
	_audio_pool.clear()


func _apply_alpha(value: float) -> void:
	if _stage != null:
		_stage.modulate.a = value
	if _bg != null:
		_bg.color.a = value


func _set_hold_bar(visible_value: bool, progress: float) -> void:
	if _hold_bg == null or _hold_fill == null:
		return
	_hold_bg.visible = visible_value
	_hold_fill.visible = visible_value
	_hold_fill.size.x = 94.0 * clampf(progress, 0.0, 1.0)


# --- cue bank ---------------------------------------------------------------

func _play_cue(id: String, at_time: float, stream: AudioStream, volume_db: float = -8.0) -> void:
	if _played_cues.has(id):
		return
	if _time < at_time:
		return
	_played_cues[id] = true
	_cue_count += 1
	if _capture_mode or stream == null:
		return
	_play_stream(stream, volume_db)


func _play_stream(stream: AudioStream, volume_db: float) -> void:
	_ensure_audio_pool()
	if _audio_pool.is_empty():
		return
	var player: AudioStreamPlayer = null
	for candidate: AudioStreamPlayer in _audio_pool:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _audio_pool[_audio_cursor % _audio_pool.size()]
		_audio_cursor += 1
		player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _ensure_audio_pool() -> void:
	if not _audio_pool.is_empty():
		return
	for index: int in range(AUDIO_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "IntroVoice%d" % (index + 1)
		player.bus = &"Master"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_audio_pool.append(player)


func _tick_cues() -> void:
	pass


func has_played_cue(id: String) -> bool:
	return _played_cues.has(id)


# --- capture helpers --------------------------------------------------------

## Freeze the film at an exact beat for a 640x360 still.  This does not run the
## cue bank and never emits finished; the capture harness frees the chapter.
func set_time_for_capture(value: float) -> void:
	_capture_mode = true
	_active = true
	_finishing = false
	_await_release = false
	_time = clampf(value, 0.0, duration)
	visible = true
	_apply_alpha(1.0)
	if _footer != null:
		_footer.modulate.a = 1.0
	_set_hold_bar(false, 0.0)
	if _stage != null:
		_stage.queue_redraw()


# --- read API (chapter / tests) --------------------------------------------

func is_playing() -> bool:
	return _active and not _finishing and not _capture_mode


func is_active() -> bool:
	return _active or _await_release


func is_finished() -> bool:
	return _finished


func is_skipped() -> bool:
	return _skipped


func is_awaiting_release() -> bool:
	return _await_release


func get_elapsed() -> float:
	return _time


func get_duration() -> float:
	return duration


func get_skip_count() -> int:
	return _skip_count


func get_cue_count() -> int:
	return _cue_count


func get_space_hold_time() -> float:
	return _space_time


func is_skip_bar_visible() -> bool:
	return _hold_bg != null and _hold_bg.visible


func get_skip_progress() -> float:
	if _hold_fill == null:
		return 0.0
	return _hold_fill.size.x / 94.0


func get_stage_alpha() -> float:
	return _stage.modulate.a if _stage != null else 0.0
