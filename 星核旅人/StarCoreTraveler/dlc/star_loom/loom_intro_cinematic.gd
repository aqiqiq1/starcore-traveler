class_name LoomIntroCinematic
extends Node2D

## DLC3 星核织机 opening, 2026-11-27 rework.
##
## The film is not a painted screen: every frame is the live chapter.  A real
## Camera2D hangs in front of the real loom (`Boss/Core`, `Boss/NodeA`,
## `Boss/NodeB`) and the real city wall, and the camera then pulls left through
## the real gate / star-core bay / checkpoint corridor to the real L3Player at the
## chapter start (x=40).  The three lamp rows, the two side-orb halos and the
## central core light are world-space overlays anchored to the real wall and
## real boss nodes; they never replace the loom sprite or the boss state.
##
## The real loom sprite's own four frames carry the shuttle motion: the film
## locks that frame clock at 4 fps from 1.08 s, so the shuttle visibly travels
## left -> centre -> behind the core -> right.  After the three lamp rows, the
## chapter's real 36x36 gear sheet turns on both flanks and the shuttle throws
## one deterministic spark burst; the core then dips and pulses once before the
## camera is allowed to pull back.  The boss stays inactive
## (`set_active(false)`) for the whole film; only the real node sprites get a
## temporary cinematic visibility/luminance, restored before `finished`.
##
## Input: F (or the shared tutorial_next action) skips at once; holding Space
## for SKIP_HOLD also skips.  A skip snaps the camera to the player's gameplay
## view in the same frame.  The chapter keeps the player locked and the HUD
## hidden until `finished` arrives; a held Space does not become the first jump.
##
## The film never starts or stops the chapter's boss BGM.  The chapter defers
## `start_music()` until this film is over; the film's own lamp/wood/shuttle
## cues play over silence so the hall reads as a dormant machine room.

signal finished(skipped: bool)

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
## Approved window is 4.0-4.6 s.  The last 0.30 s is the settled player view so
## the HUD can start its 0.35 s fade without a camera step.
##
## Jitter contract: the camera makes one short push during the dark opening,
## then holds the exact same centre AND zoom until the final pull.  No sine or
## noise ever moves the camera.  World overlays are anchored to real wall/loom
## coordinates and only animate alpha, integer-stepped sparks/gears or integer
## chain sway, so the held frame cannot creep by a sub-pixel.
const DURATION: float = 4.50
const SKIP_HOLD: float = 0.60
const PUSH_END: float = 0.55
const PULL_START: float = 3.36
const PULL_END: float = 4.18
const LAMP_ROWS: Array[float] = [1.08, 1.30, 1.52]
const GEAR_START: float = 1.78
const SPARK_START: float = 1.88
const ORB_START: float = 2.10
const CORE_START: float = 2.22
const CORE_DIM_END: float = 2.44
const CORE_PULSE_PEAK: float = 2.62
const CORE_SETTLE: float = 2.86
const CORE_FULL: float = CORE_SETTLE
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const AUDIO_POOL_SIZE: int = 6

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const PURPLE: Color = Color("#a874ff")
const PURPLE_PALE: Color = Color("#d7b8ff")
const WARM: Color = Color("#ffd58a")
const WARM_PALE: Color = Color("#fff2c9")
const INK: Color = Color(0.004, 0.010, 0.014, 1.0)
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DARK_GRADE: Color = Color(0.005, 0.012, 0.016, 1.0)

## Lamp installation: three horizontal rails on the real wall above the loom.
## The rails are dark from frame one; each row's bulbs and wall cones light as
## a group.  The rows sit low enough that all three are inside the opening
## loom framing, not clipped by the top of the viewport.
const LAMP_RAIL_X: float = 560.0
const LAMP_RAIL_W: float = 360.0
const LAMP_RAIL_YS: Array[float] = [44.0, 64.0, 84.0]
const LAMP_XS: Array[float] = [590.0, 650.0, 710.0, 770.0, 830.0, 890.0]

## The camera starts tight on the real loom (core x=700) and ends exactly on
## the player's gameplay-centre.  The x centre is shifted right of the gate so
## the first shot contains only the wall, lamps, chains and loom; a 1.20 zoom
## keeps the 208x152 loom, its chains and all three lamp rows in one readable
## frame.  The opening push lands on this one framing and then stops.
const LOOM_CAMERA: Vector2 = Vector2(678.0, 178.0)
const LOOM_CAMERA_FOCUS: Vector2 = Vector2(692.0, 180.0)
const LOOM_ZOOM: float = 1.10
const LOOM_ZOOM_FOCUS: float = 1.20

## The two flanking gears use the chapter's own four-frame brass sheet, not a
## painted substitute.  They sit just outside the loom piers, below the orb
## anchors, so both read without covering the weak point.
const GEAR_TEXTURE: Texture2D = preload(
	"res://dlc/star_loom/assets/city/gear_36x36_4f.png"
)
const GEAR_OFFSET: Vector2 = Vector2(132.0, 40.0)
const GEAR_FPS: float = 12.0


class WorldLightLayer:
	extends Node2D
	var host: LoomIntroCinematic = null

	func _draw() -> void:
		if host != null:
			host._draw_world_light(self)


var _core: LoomCore = null
var _node_a: LoomNode = null
var _node_b: LoomNode = null
var _player: L3Player = null
var _player_camera: Camera2D = null
var _hud: LoomHUD = null

var _opening_camera: Camera2D = null
var _world_layer: WorldLightLayer = null
var _gear_left: Sprite2D = null
var _gear_right: Sprite2D = null
var _grade_layer: CanvasLayer = null
var _grade: ColorRect = null
var _vignette: Control = null
var _ui_layer: CanvasLayer = null
var _footer: Control = null
var _hold_bg: ColorRect = null
var _hold_fill: ColorRect = null
var _font: Font = null

var _node_a_angle: float = 0.0
var _node_b_angle: float = 0.0
var _node_a_phase: bool = true
var _node_b_phase: bool = false
var _visuals_prepared: bool = false

var _lamp_streams: Array[AudioStream] = []
var _wood_stream: AudioStream = null
var _shuttle_stream: AudioStream = null
var _orb_low_stream: AudioStream = null
var _orb_high_stream: AudioStream = null
var _core_stream: AudioStream = null

var _active: bool = false
var _finished: bool = false
var _finished_emitted: bool = false
var _skipped: bool = false
var _await_release: bool = false
var _skip_count: int = 0
var _time: float = 0.0
var _space_held: bool = false
var _space_time: float = 0.0
var _space_latched: bool = false
var _capture_mode: bool = false

var _lamp_amounts: Array[float] = [0.0, 0.0, 0.0]
var _orbs_lit: float = 0.0
var _core_ignite: float = 0.0
var _core_flash: float = 0.0
var _gear_frame: int = 0
var _gear_power: float = 0.0
var _world_fade: float = 1.0
var _grade_alpha: float = 1.0
var _core_original_modulate: Color = Color.WHITE
var _core_modulate_saved: bool = false

var _played_cues: Dictionary = {}
var _cue_count: int = 0
var _audio_pool: Array[AudioStreamPlayer] = []
var _audio_cursor: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_camera()
	_build_world_layer()
	_build_grade()
	_build_film_ui()
	_set_film_layers_visible(false)
	set_process(false)
	set_process_unhandled_input(false)


func configure(
	core: LoomCore,
	node_a: LoomNode,
	node_b: LoomNode,
	player: L3Player,
	player_camera: Camera2D,
	hud: LoomHUD
) -> void:
	_core = core
	_node_a = node_a
	_node_b = node_b
	_player = player
	_player_camera = player_camera
	_hud = hud
	if _player_camera == null and _player != null:
		_player_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _player_camera != null and _opening_camera != null:
		_opening_camera.limit_left = _player_camera.limit_left
		_opening_camera.limit_top = _player_camera.limit_top
		_opening_camera.limit_right = _player_camera.limit_right
		_opening_camera.limit_bottom = _player_camera.limit_bottom


func _build_camera() -> void:
	_opening_camera = Camera2D.new()
	_opening_camera.name = "OpeningCamera2D"
	_opening_camera.enabled = false
	_opening_camera.position_smoothing_enabled = false
	_opening_camera.position_smoothing_speed = 0.0
	_opening_camera.limit_left = 0
	_opening_camera.limit_top = 0
	_opening_camera.limit_right = 960
	_opening_camera.limit_bottom = 360
	_opening_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(_opening_camera)


func _build_world_layer() -> void:
	# Every light here is positioned from a real wall/loom/node coordinate and
	# lives in world space; the real sprites are drawn underneath.
	_world_layer = WorldLightLayer.new()
	_world_layer.name = "OpeningWorldLight"
	_world_layer.host = self
	_world_layer.z_index = 7
	_world_layer.visible = false
	add_child(_world_layer)

	# Two real brass gears flank the loom.  They are world sprites (not a
	# screen-space decal), visible but unlit before the gear beat.  Four real
	# frames at 12 fps read as rotation without moving a single pixel.
	_gear_left = _make_gear("OpeningGearLeft")
	_gear_right = _make_gear("OpeningGearRight")


func _make_gear(node_name: String) -> Sprite2D:
	var gear: Sprite2D = Sprite2D.new()
	gear.name = node_name
	gear.texture = GEAR_TEXTURE
	gear.hframes = 4
	gear.vframes = 1
	gear.frame = 0
	gear.centered = true
	gear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gear.z_index = 5
	gear.modulate = Color(0.62, 0.58, 0.52, 0.72)
	gear.visible = false
	add_child(gear)
	return gear


func _build_grade() -> void:
	_grade_layer = CanvasLayer.new()
	_grade_layer.name = "OpeningGrade"
	_grade_layer.layer = 6
	_grade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_grade_layer)

	_grade = ColorRect.new()
	_grade.name = "DarkGrade"
	_grade.position = Vector2.ZERO
	_grade.size = VIEW_SIZE
	_grade.color = Color(DARK_GRADE, 1.0)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_layer.add_child(_grade)

	_vignette = Control.new()
	_vignette.name = "Vignette"
	_vignette.position = Vector2.ZERO
	_vignette.size = VIEW_SIZE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_layer.add_child(_vignette)
	for index: int in range(4):
		var width: float = 14.0 + float(index) * 10.0
		var alpha: float = 0.060 - float(index) * 0.012
		var edge: ColorRect = ColorRect.new()
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.color = Color(0.0, 0.0, 0.0, alpha)
		match index:
			0:
				edge.position = Vector2.ZERO
				edge.size = Vector2(VIEW_SIZE.x, width)
			1:
				edge.position = Vector2(0.0, VIEW_SIZE.y - width)
				edge.size = Vector2(VIEW_SIZE.x, width)
			2:
				edge.position = Vector2.ZERO
				edge.size = Vector2(width, VIEW_SIZE.y)
			_:
				edge.position = Vector2(VIEW_SIZE.x - width, 0.0)
				edge.size = Vector2(width, VIEW_SIZE.y)
		_vignette.add_child(edge)


func _build_film_ui() -> void:
	_font = _load_font()
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "OpeningUI"
	_ui_layer.layer = 21
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	_footer = Control.new()
	_footer.name = "SkipFooter"
	_footer.position = Vector2.ZERO
	_footer.size = VIEW_SIZE
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.visible = false
	_ui_layer.add_child(_footer)

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
	_hold_fill.visible = false
	_footer.add_child(_hold_fill)

	_add_keycap("F", Rect2(420.0, 334.0, 16.0, 16.0), 12)
	_add_footer_text("跳过", Vector2(440.0, 334.0), 30.0)
	_add_footer_text("·", Vector2(466.0, 334.0), 10.0)
	_add_footer_text("长按", Vector2(478.0, 334.0), 30.0)
	_add_keycap("空格", Rect2(506.0, 334.0, 34.0, 16.0), 12)


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

func start() -> bool:
	if _active or _await_release or _finished:
		return false
	if _core == null or not is_instance_valid(_core):
		_fail_start("core")
		return false
	if _node_a == null or not is_instance_valid(_node_a):
		_fail_start("node A")
		return false
	if _node_b == null or not is_instance_valid(_node_b):
		_fail_start("node B")
		return false
	if _player == null or not is_instance_valid(_player):
		_fail_start("player")
		return false
	if _player_camera == null or not is_instance_valid(_player_camera):
		_player_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _player_camera == null or _opening_camera == null:
		_fail_start("camera")
		return false

	_active = true
	_finished = false
	_finished_emitted = false
	_skipped = false
	_await_release = false
	_skip_count = 0
	_time = 0.0
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_capture_mode = false
	_played_cues.clear()
	_cue_count = 0
	_lamp_amounts = [0.0, 0.0, 0.0]
	_orbs_lit = 0.0
	_core_ignite = 0.0
	_core_flash = 0.0
	_gear_frame = 0
	_gear_power = 0.0
	_world_fade = 1.0
	_grade_alpha = 1.0

	_prepare_visuals()

	# Hand the viewport to the real film camera.  The gameplay camera is
	# disabled rather than merely outranked, so no later smoothing tick can
	# steal a frame.
	_player_camera.enabled = false
	_opening_camera.enabled = true
	var state: Vector3 = _camera_state_at(0.0)
	_opening_camera.zoom = Vector2(state.z, state.z)
	_opening_camera.global_position = Vector2(roundf(state.x), roundf(state.y))
	_opening_camera.reset_smoothing()
	_opening_camera.make_current()

	_set_film_layers_visible(true)
	_apply_time(0.0)
	set_process(true)
	set_process_unhandled_input(true)
	return true


func _fail_start(reason: String) -> void:
	push_warning("LoomIntroCinematic: missing real " + reason + "; skipping film")
	_finished = true
	_emit_finished.call_deferred()


## The real boss nodes stay inactive.  Their sprites are only shown for the
## two-orb beat and are hidden again in `_restore_visuals`.  The loom sprite's
## frame clock is locked so the film can show its real four shuttle frames on
## the storyboard beat instead of drifting with process time.
func _prepare_visuals() -> void:
	if _visuals_prepared:
		return
	_visuals_prepared = true
	if _core != null:
		_core_original_modulate = _core.modulate
		_core_modulate_saved = true
	if _gear_left != null and _core != null:
		_gear_left.global_position = _core.global_position \
			+ Vector2(-GEAR_OFFSET.x, GEAR_OFFSET.y)
		_gear_left.visible = true
	if _gear_right != null and _core != null:
		_gear_right.global_position = _core.global_position \
			+ Vector2(GEAR_OFFSET.x, GEAR_OFFSET.y)
		_gear_right.visible = true
	if _node_a != null:
		_node_a_angle = _node_a.get_orbit_angle()
		_node_a_phase = _node_a.is_positive()
		_node_a.set_cinematic_pose(0.0, true)
	if _node_b != null:
		_node_b_angle = _node_b.get_orbit_angle()
		_node_b_phase = _node_b.is_positive()
		_node_b.set_cinematic_pose(PI, false)
		_node_b.set_cinematic_visible(false)
	if _node_a != null:
		_node_a.set_cinematic_visible(false)
	if _core != null:
		_core.set_cinematic_frame_lock(true, 0)


func _restore_visuals() -> void:
	if _core != null and is_instance_valid(_core):
		_core.set_cinematic_frame_lock(false)
		if _core_modulate_saved:
			_core.modulate = _core_original_modulate
	if _gear_left != null:
		_gear_left.visible = false
		_gear_left.frame = 0
	if _gear_right != null:
		_gear_right.visible = false
		_gear_right.frame = 0
	if _node_a != null and is_instance_valid(_node_a):
		_node_a.set_cinematic_visible(false)
		if not _node_a.is_active():
			_node_a.set_cinematic_pose(_node_a_angle, _node_a_phase)
	if _node_b != null and is_instance_valid(_node_b):
		_node_b.set_cinematic_visible(false)
		if not _node_b.is_active():
			_node_b.set_cinematic_pose(_node_b_angle, _node_b_phase)
	_visuals_prepared = false


func _process(delta: float) -> void:
	if _capture_mode or not _active:
		return
	if _await_release:
		_set_hold_bar(false, 0.0)
		if not _space_held and not Input.is_physical_key_pressed(KEY_SPACE):
			_complete_await_release()
		return

	_time += delta
	if _space_held and not _space_latched:
		_space_time += delta
		if _space_time >= SKIP_HOLD:
			_space_latched = true
			_request_skip()
			return
	_set_hold_bar(_space_held, clampf(_space_time / SKIP_HOLD, 0.0, 1.0))
	_apply_time(_time)
	_tick_cues()
	if _time >= DURATION:
		_finish_natural()


func _apply_time(value: float) -> void:
	_time = value
	var state: Vector3 = _camera_state_at(value)
	if _opening_camera != null:
		_opening_camera.zoom = Vector2(state.z, state.z)
		# Snap to whole pixels: the project renders at 1x and the wall/loom
		# edges must not shimmer while the camera crosses the room.
		_opening_camera.global_position = Vector2(
			roundf(state.x), roundf(state.y)
		)

	for row: int in range(LAMP_ROWS.size()):
		_lamp_amounts[row] = smoothstep(
			LAMP_ROWS[row], LAMP_ROWS[row] + 0.16, value
		)
	_orbs_lit = smoothstep(ORB_START, ORB_START + 0.22, value)
	_core_ignite = _core_level_at(value)
	_core_flash = _core_flash_at(value)
	_gear_power = smoothstep(GEAR_START, GEAR_START + 0.16, value)
	_gear_frame = _gear_frame_at(value)
	# The powered hall is a film state, not a gameplay state.  It fades out
	# during the pull so the delivered player view is the real, unlit chapter
	# view (and the real boss nodes are already hidden in it).
	_world_fade = 1.0 - smoothstep(PULL_START + 0.04, PULL_END - 0.10, value)
	_grade_alpha = _grade_alpha_at(value)

	if _core != null and is_instance_valid(_core):
		_core.set_cinematic_frame(_loom_frame_at(value))
		if _core_modulate_saved:
			var dim: Color = Color(0.78, 0.76, 0.74, 1.0)
			var hot: Color = Color(1.22, 1.16, 1.02, 1.0)
			var tint: Color = _core_original_modulate
			if value >= CORE_START:
				tint = dim.lerp(hot, _core_ignite)
				if _core_flash > 0.0:
					tint = tint.lerp(
						Color(1.45, 1.38, 1.20, 1.0), _core_flash * 0.55
					)
			_core.modulate = tint
	if _gear_left != null:
		_gear_left.frame = _gear_frame
		_gear_left.modulate = Color(0.62, 0.58, 0.52, 0.72).lerp(
			Color.WHITE, _gear_power
		)
	if _gear_right != null:
		_gear_right.frame = _gear_frame
		_gear_right.modulate = Color(0.62, 0.58, 0.52, 0.72).lerp(
			Color.WHITE, _gear_power
		)

	var show_orbs: bool = value >= ORB_START
	if _node_a != null and is_instance_valid(_node_a):
		_node_a.set_cinematic_visible(show_orbs)
		_node_a.set_cinematic_lit(_orbs_lit * _world_fade if show_orbs else 0.0)
	if _node_b != null and is_instance_valid(_node_b):
		_node_b.set_cinematic_visible(show_orbs)
		_node_b.set_cinematic_lit(_orbs_lit * _world_fade if show_orbs else 0.0)

	if _grade != null:
		_grade.color = Color(DARK_GRADE, _grade_alpha)
	if _vignette != null:
		_vignette.modulate.a = clampf(_grade_alpha * 1.25, 0.0, 1.0)

	if _world_layer != null:
		_world_layer.visible = _active or _capture_mode
		_world_layer.queue_redraw()

	if _footer != null:
		var footer_alpha: float = 0.0
		if value > 0.34 and not _finished:
			footer_alpha = clampf((value - 0.34) / 0.22, 0.0, 1.0)
		_footer.modulate.a = footer_alpha
		_footer.visible = footer_alpha > 0.0


func _loom_frame_at(value: float) -> int:
	# The real loom sheet has four frames; the shuttle is left of the core in
	# frame 0, crosses in 1, hides behind the core in 2 and exits right in 3.
	if value >= LAMP_ROWS[0] and value < PULL_START:
		return int((value - LAMP_ROWS[0]) * 4.0) % 4
	return 0


## Core light: a normal lit level, one visible dip, then one bright pulse,
## then a steady hold while the camera stays parked on the core.
func _core_level_at(value: float) -> float:
	if value < CORE_START:
		return 0.0
	if value < CORE_START + 0.16:
		return lerpf(0.0, 0.86, smoothstep(CORE_START, CORE_START + 0.16, value))
	if value < CORE_DIM_END:
		return lerpf(0.86, 0.18,
			smoothstep(CORE_START + 0.16, CORE_DIM_END, value))
	if value < CORE_PULSE_PEAK:
		return lerpf(0.18, 1.0, smoothstep(CORE_DIM_END, CORE_PULSE_PEAK, value))
	if value < CORE_SETTLE:
		return lerpf(1.0, 0.86, smoothstep(CORE_PULSE_PEAK, CORE_SETTLE, value))
	return 0.86


func _core_flash_at(value: float) -> float:
	if value < CORE_PULSE_PEAK or value > CORE_PULSE_PEAK + 0.36:
		return 0.0
	return 1.0 - smoothstep(
		CORE_PULSE_PEAK, CORE_PULSE_PEAK + 0.36, value
	)


func _gear_frame_at(value: float) -> int:
	if value < GEAR_START:
		return 0
	return int((value - GEAR_START) * GEAR_FPS) % 4


func _camera_state_at(value: float) -> Vector3:
	var gameplay: Vector2 = _gameplay_camera_center()
	var center: Vector2 = LOOM_CAMERA_FOCUS
	var zoom: float = LOOM_ZOOM_FOCUS
	if value <= PUSH_END:
		# One short push only while the hall is still near-black.  After this
		# exact frame both centre and zoom are bit-for-bit constant.
		var k: float = smoothstep(0.0, PUSH_END, value)
		center = LOOM_CAMERA.lerp(LOOM_CAMERA_FOCUS, k)
		zoom = lerpf(LOOM_ZOOM, LOOM_ZOOM_FOCUS, k)
	elif value > PULL_START:
		var k: float = smoothstep(PULL_START, PULL_END, value)
		center = LOOM_CAMERA_FOCUS.lerp(gameplay, k)
		zoom = lerpf(LOOM_ZOOM_FOCUS, 1.0, k)
	# The film follows the same limits as the player camera.  Clamping here
	# keeps the final frame exactly equal to the delivered gameplay view.
	var half: Vector2 = VIEW_SIZE * 0.5 / zoom
	var left: float = float(_opening_camera.limit_left) if _opening_camera != null else 0.0
	var top: float = float(_opening_camera.limit_top) if _opening_camera != null else 0.0
	var right: float = float(_opening_camera.limit_right) if _opening_camera != null else 960.0
	var bottom: float = float(_opening_camera.limit_bottom) if _opening_camera != null else 360.0
	center.x = clampf(center.x, left + half.x, right - half.x)
	center.y = clampf(center.y, top + half.y, bottom - half.y)
	return Vector3(center.x, center.y, zoom)


## The exact centre the real player camera would use for the current player.
func _gameplay_camera_center() -> Vector2:
	var half: Vector2 = VIEW_SIZE * 0.5
	if _player == null or _player_camera == null:
		return half
	var target: Vector2 = _player.global_position
	return Vector2(
		clampf(target.x, float(_player_camera.limit_left) + half.x,
			float(_player_camera.limit_right) - half.x),
		clampf(target.y, float(_player_camera.limit_top) + half.y,
			float(_player_camera.limit_bottom) - half.y)
	)


func _grade_alpha_at(value: float) -> float:
	# The first beat is dark but never black: the real wall, the loom's wood
	# frame and its hanging chains stay readable.  Each lamp row lifts the
	# grade on the real wall; the final pull returns to full gameplay light.
	if value < LAMP_ROWS[0]:
		return lerpf(0.78, 0.70, smoothstep(0.0, LAMP_ROWS[0], value))
	if value < LAMP_ROWS[2] + 0.16:
		return lerpf(0.70, 0.46,
			smoothstep(LAMP_ROWS[0], LAMP_ROWS[2] + 0.16, value))
	if value < ORB_START:
		return lerpf(0.46, 0.30,
			smoothstep(LAMP_ROWS[2] + 0.16, ORB_START, value))
	if value < CORE_SETTLE:
		return lerpf(0.30, 0.10, smoothstep(ORB_START, CORE_SETTLE, value))
	# Fully lit for the whole held shot: the grade itself must not change
	# between the two static comparison frames.
	return 0.0


func _finish_natural() -> void:
	if _finished:
		return
	_apply_time(DURATION)
	_ended_state()
	_emit_finished()


func _request_skip() -> void:
	if not _active or _finished:
		return
	_skipped = true
	_skip_count += 1
	_ended_state()
	# Even after the picture has snapped to the player, a held Space is not
	# allowed to become the first jump.  The chapter stays input-locked until
	# the release arrives.
	if _space_held or Input.is_physical_key_pressed(KEY_SPACE):
		_await_release = true
		_space_latched = true
		_footer.visible = false
		set_process_unhandled_input(true)
		return
	_emit_finished()


func _ended_state() -> void:
	_time = minf(_time, DURATION)
	_active = false
	_finished = true
	# Park on the exact gameplay view before the camera is disabled; capture
	# and tests can then read a truthful last film frame.
	if _opening_camera != null:
		_opening_camera.zoom = Vector2.ONE
		_opening_camera.global_position = _gameplay_camera_center()
	if _grade != null:
		_grade.color = Color(DARK_GRADE, 0.0)
	if _vignette != null:
		_vignette.modulate.a = 0.0
	if _world_layer != null:
		_world_layer.visible = false
	if _footer != null:
		_footer.visible = false
	_set_hold_bar(false, 0.0)
	_restore_visuals()
	_stop_audio()
	_restore_player_camera()


func _restore_player_camera() -> void:
	if _opening_camera != null:
		_opening_camera.enabled = false
	if _player_camera != null and is_instance_valid(_player_camera) \
			and _player_camera.is_inside_tree():
		_player_camera.enabled = true
		_player_camera.make_current()
		_player_camera.reset_smoothing()


func _complete_await_release() -> void:
	if not _await_release:
		return
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_emit_finished()


## Pause while the post-skip "wait for Space release" latch is held.  The
## player has already seen the gameplay view, so consume the latch and finish
## the hand-off now.  The chapter's three-tick input override owns the still
## held Space after resume, so it cannot become the first jump.
func handle_pause_opened() -> void:
	if not _await_release:
		return
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_set_hold_bar(false, 0.0)
	_complete_await_release()


## Safety net for a pause path that did not consume the latch on open; do not
## finish while Space is still physically held, or the release would be lost.
func handle_pause_resumed() -> void:
	if not _await_release:
		return
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_set_hold_bar(false, 0.0)
	if not Input.is_physical_key_pressed(KEY_SPACE):
		_complete_await_release()


func _emit_finished() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	_active = false
	set_process(false)
	set_process_unhandled_input(false)
	finished.emit(_skipped)


func abort() -> void:
	if not _active and not _await_release and not _finished:
		return
	_active = false
	_finished = true
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_capture_mode = false
	_skipped = false
	if _grade != null:
		_grade.color = Color(DARK_GRADE, 0.0)
	if _footer != null:
		_footer.visible = false
	if _world_layer != null:
		_world_layer.visible = false
	_set_hold_bar(false, 0.0)
	_restore_visuals()
	_stop_audio()
	_restore_player_camera()
	set_process(false)
	set_process_unhandled_input(false)


# --- input ------------------------------------------------------------------

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
			_space_held = false
			_complete_await_release()
			get_viewport().set_input_as_handled()
		return

	if key_event.echo:
		get_viewport().set_input_as_handled()
		return

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


# --- cue bank ---------------------------------------------------------------

func _setup_cues() -> void:
	if not _lamp_streams.is_empty():
		return
	_lamp_streams = [
		DlcIntroSfx.lamp_on(0),
		DlcIntroSfx.lamp_on(1),
		DlcIntroSfx.lamp_on(2),
	]
	_wood_stream = DlcIntroSfx.wood_creak()
	_shuttle_stream = DlcIntroSfx.shuttle_slide()
	_orb_low_stream = DlcIntroSfx.orb_on(false)
	_orb_high_stream = DlcIntroSfx.orb_on(true)
	_core_stream = DlcIntroSfx.core_ignite()


func _tick_cues() -> void:
	if _lamp_streams.is_empty():
		_setup_cues()
	_play_cue("lamp_row_1", LAMP_ROWS[0], _lamp_streams[0], -12.0)
	_play_cue("wood_creak", 1.18, _wood_stream, -11.0)
	_play_cue("lamp_row_2", LAMP_ROWS[1], _lamp_streams[1], -12.0)
	_play_cue("lamp_row_3", LAMP_ROWS[2], _lamp_streams[2], -12.0)
	_play_cue("shuttle", SPARK_START, _shuttle_stream, -9.0)
	_play_cue("orb_left", ORB_START, _orb_low_stream, -9.0)
	_play_cue("orb_right", ORB_START + 0.12, _orb_high_stream, -9.0)
	_play_cue("core_ignite", CORE_START + 0.06, _core_stream, -6.0)


func _play_cue(id: String, at_time: float, stream: AudioStream, volume_db: float) -> void:
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


func _stop_audio() -> void:
	for player: AudioStreamPlayer in _audio_pool:
		if player == null:
			continue
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	_stop_audio()
	_audio_pool.clear()


# --- world-space light (real wall / loom / nodes / core) ---------------------

func _draw_world_light(canvas: Node2D) -> void:
	if _core == null or not is_instance_valid(_core):
		return
	_draw_lamp_rails(canvas)
	_draw_chain_light(canvas)
	_draw_orb_light(canvas, _node_b, _orbs_lit, CYAN)
	_draw_orb_light(canvas, _node_a, _orbs_lit, GOLD)
	_draw_core_light(canvas, _core_ignite)
	_draw_shuttle_sparks(canvas)
	_draw_motes(canvas)


## Three dark fixture rails are visible from the first frame; each row lights
## the bulbs and lays a warm cone on the real wall behind the loom.
func _draw_lamp_rails(canvas: Node2D) -> void:
	if _world_fade <= 0.001:
		return
	for row: int in range(LAMP_RAIL_YS.size()):
		var rail_y: float = LAMP_RAIL_YS[row]
		var lit: float = _lamp_amounts[row] * _world_fade
		canvas.draw_rect(
			Rect2(LAMP_RAIL_X, rail_y, LAMP_RAIL_W, 2.0),
			Color(0.10, 0.09, 0.08, 0.94)
		)
		canvas.draw_rect(
			Rect2(LAMP_RAIL_X, rail_y + 2.0, LAMP_RAIL_W, 1.0),
			Color(0.28, 0.23, 0.18, 0.55)
		)
		if lit > 0.001:
			# A wall-wide wash makes the whole row read as a light source, not
			# only six small bulbs.  Both bands are world-space rectangles on
			# the real wall, not a full-screen grade change.
			canvas.draw_rect(
				Rect2(LAMP_RAIL_X - 12.0, rail_y + 3.0, LAMP_RAIL_W + 24.0, 26.0),
				Color(WARM, 0.040 * lit)
			)
			canvas.draw_rect(
				Rect2(LAMP_RAIL_X - 18.0, rail_y + 3.0, LAMP_RAIL_W + 36.0, 12.0),
				Color(WARM, 0.035 * lit)
			)
			canvas.draw_rect(
				Rect2(LAMP_RAIL_X, rail_y - 1.0, LAMP_RAIL_W, 1.0),
				Color(WARM, 0.30 * lit)
			)
		for x: float in LAMP_XS:
			_draw_lamp(canvas, x, rail_y, lit, row)


func _draw_lamp(
	canvas: Node2D, x: float, rail_y: float, lit: float, row: int
) -> void:
	# Housing and cradle stay readable while the row is off, so the three rows
	# read as real fixtures on the wall instead of appearing out of nothing.
	canvas.draw_rect(
		Rect2(x - 5.0, rail_y + 2.0, 10.0, 5.0),
		Color(0.07, 0.06, 0.05, 0.96)
	)
	canvas.draw_rect(
		Rect2(x - 4.0, rail_y + 3.0, 8.0, 2.0),
		Color(0.26, 0.20, 0.15, 0.95)
	)
	if lit <= 0.001:
		return
	# Alpha-only flicker at 12 fps; the bulb/rail coordinates never move.
	var flicker_t: float = floorf(_time * 12.0) / 12.0
	var pulse: float = 0.94 + 0.06 * sin(flicker_t * 7.0 + float(row) * 1.3)
	for layer: int in range(3):
		canvas.draw_circle(
			Vector2(x, rail_y + 5.0),
			5.0 + float(layer) * 5.0,
			Color(WARM, (0.30 - float(layer) * 0.075) * lit * pulse)
		)
	canvas.draw_rect(
		Rect2(x - 4.0, rail_y + 3.0, 8.0, 3.0),
		Color(WARM, 0.62 + 0.38 * lit)
	)
	canvas.draw_rect(
		Rect2(x - 3.0, rail_y + 3.0, 6.0, 1.0),
		Color(WARM_PALE, 0.95 * lit)
	)
	canvas.draw_rect(
		Rect2(x - 5.0, rail_y + 6.0, 10.0, 1.0),
		Color(WARM, 0.40 * lit)
	)
	# A short downward cone on the wall, ending at the loom's top beam so the
	# light reads as wall illumination, not a screen wash.
	var cone_bottom: float = rail_y + 84.0
	canvas.draw_colored_polygon(
		PackedVector2Array([
			Vector2(x - 6.0, rail_y + 6.0),
			Vector2(x + 6.0, rail_y + 6.0),
			Vector2(x + 30.0 - float(row) * 4.0, cone_bottom),
			Vector2(x - 30.0 + float(row) * 4.0, cone_bottom),
		]),
		Color(WARM, 0.045 * lit)
	)
	canvas.draw_rect(
		Rect2(x - 16.0, rail_y + 11.0, 32.0, 1.0),
		Color(WARM, 0.18 * lit)
	)


## Warm vertical highlights on the two real hanging chains once the rows are
## up.  The chain itself is still the real LoomCore drawing underneath.
func _draw_chain_light(canvas: Node2D) -> void:
	var amount: float = clampf(
		(_lamp_amounts[1] + _lamp_amounts[2]) * 0.5, 0.0, 1.0
	) * _world_fade
	if amount <= 0.001:
		return
	var core_pos: Vector2 = _core.global_position
	# 8 fps, whole-pixel sway: the highlight never crawls by a sub-pixel.
	var step_t: float = floorf(_time * 8.0) / 8.0
	for chain_x: float in [-32.0, 32.0]:
		var toggle: int = 0
		var y: float = -190.0
		while y < -76.0:
			var depth: float = (y + 192.0) / 116.0
			var sway: float = float(round(
				sin(step_t * 0.9 + chain_x) * 1.4 * depth
			))
			var px: float = roundf(core_pos.x + chain_x + sway)
			if toggle % 2 == 0:
				canvas.draw_rect(
					Rect2(px, core_pos.y + y, 1.0, 1.0),
					Color(WARM, 0.42 * amount)
				)
			y += 4.0
			toggle += 1


func _draw_orb_light(
	canvas: Node2D, node: LoomNode, amount: float, color: Color
) -> void:
	amount *= _world_fade
	if node == null or not is_instance_valid(node) or amount <= 0.001:
		return
	var center: Vector2 = node.global_position
	var step_t: float = floorf(_time * 12.0) / 12.0
	var pulse: float = 0.82 + 0.18 * sin(step_t * 12.0 + (0.0 if color == GOLD else 1.4))
	# Halos sit outside the real 40x40 node sprite, so the sprite stays intact.
	for layer: int in range(3):
		canvas.draw_arc(
			center, 23.0 + float(layer) * 5.0, 0.0, TAU, 28,
			Color(color, (0.34 - float(layer) * 0.10) * amount * pulse), 1.0
		)
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0 + step_t * 0.20
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * 25.0
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (31.0 + 2.0 * pulse)
		canvas.draw_line(inner, outer, Color(color, 0.40 * amount), 1.0)
	# Four whole-pixel orbit sparks make the orb feel driven by the loom.  The
	# quantised angle keeps them from sub-pixel crawling in the held shot.
	for index: int in range(4):
		var angle: float = step_t * 1.4 + TAU * float(index) / 4.0
		var point: Vector2 = center + Vector2(
			roundf(cos(angle) * 28.0), roundf(sin(angle) * 18.0)
		)
		canvas.draw_rect(
			Rect2(point, Vector2.ONE),
			Color(color.lightened(0.45), 0.65 * amount)
		)
	# A 1 px stain on the floor under the real node.
	canvas.draw_rect(
		Rect2(center.x - 8.0, 320.0, 16.0, 1.0),
		Color(color, 0.16 * amount)
	)


func _draw_core_light(canvas: Node2D, ignite: float) -> void:
	ignite *= _world_fade
	if ignite <= 0.001:
		return
	var center: Vector2 = _core.global_position
	var step_t: float = floorf(_time * 12.0) / 12.0
	var pulse: float = 0.88 + 0.12 * sin(step_t * 18.0)
	# Purple knot halo outside the real 26/20 px dim diamonds.
	for layer: int in range(3):
		canvas.draw_circle(
			center, 18.0 + float(layer) * 9.0,
			Color(PURPLE, (0.13 - float(layer) * 0.035) * ignite * pulse)
		)
	# Gold rail ring: an incomplete circle so it reads as woven metal, not a
	# UI ring.  The real net/threads stay underneath.  The ring is quantised
	# so its 1 px dashes do not shimmer while the camera is parked.
	for index: int in range(12):
		var angle: float = TAU * float(index) / 12.0 + step_t * 0.12
		if index % 4 == 2:
			continue
		var from: Vector2 = center + Vector2(cos(angle), sin(angle)) * 30.0
		var to: Vector2 = center + Vector2(cos(angle), sin(angle)) * 37.0
		canvas.draw_line(from, to, Color(GOLD, 0.50 * ignite), 1.0)
	# One expanding pulse ring sells the dark -> bright beat.  It is alpha and
	# radius only; the centre never moves.
	if _core_flash > 0.001:
		var ring: float = 1.0 - _core_flash
		canvas.draw_arc(
			center, 22.0 + 42.0 * ring, 0.0, TAU, 32,
			Color(WARM_PALE, 0.55 * _core_flash), 1.0
		)
		canvas.draw_arc(
			center, 28.0 + 52.0 * ring, 0.0, TAU, 32,
			Color(PURPLE_PALE, 0.30 * _core_flash), 1.0
		)
	# The ignited knot: a translucent purple diamond over the real dim one,
	# plus a small white heart.  No gameplay diamond is duplicated.  The fill
	# starts after the knot has real sub-pixel size, so the polygon never
	# degenerates during the first ignite frames.
	if ignite >= 0.10:
		canvas.draw_colored_polygon(
			_diamond_points(center, 12.0 * ignite, 13.0 * ignite),
			Color(PURPLE, 0.62 * ignite)
		)
		canvas.draw_colored_polygon(
			_diamond_points(center, 7.0 * ignite, 8.0 * ignite),
			Color(PURPLE_PALE, 0.55 * ignite)
		)
		var outline: PackedVector2Array = _diamond_points(
			center, 14.0 * ignite, 15.0 * ignite
		)
		outline.append(outline[0])
		canvas.draw_polyline(outline, Color(GOLD, 0.55 * ignite), 1.0)
	canvas.draw_rect(
		Rect2(roundf(center.x) - 1.0, roundf(center.y) - 1.0, 3.0, 3.0),
		Color(WARM_PALE, 0.92 * ignite)
	)
	# Eight short gold rays leave the knot.
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0 + 0.2
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * 15.0
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (22.0 + 7.0 * ignite)
		canvas.draw_line(inner, outer, Color(GOLD, 0.40 * ignite), 1.0)
	# A faint vertical thread up the real chains: the loom answering.
	if ignite > 0.35:
		var thread: float = clampf((ignite - 0.35) / 0.65, 0.0, 1.0)
		canvas.draw_rect(
			Rect2(center.x, center.y - 192.0, 1.0, 112.0),
			Color(GOLD, 0.10 * thread)
		)


## A short deterministic burst from the real shuttle's right-hand mouth.  The
## sparks are 1-2 px rects with a tail; nothing is randomised at draw time, so
## capture frames are repeatable.
func _draw_shuttle_sparks(canvas: Node2D) -> void:
	var age: float = _time - SPARK_START
	if age < 0.0 or age > 0.52 or _core == null:
		return
	var origin: Vector2 = _core.global_position + Vector2(26.0, -16.0)
	if age < 0.28:
		var flare: float = 1.0 - age / 0.28
		canvas.draw_rect(
			Rect2(roundf(origin.x) - 1.0, roundf(origin.y) - 1.0, 3.0, 3.0),
			Color(WARM_PALE, 0.95 * flare)
		)
		canvas.draw_rect(
			Rect2(roundf(origin.x) - 2.0, roundf(origin.y), 5.0, 1.0),
			Color(GOLD, 0.70 * flare)
		)
	for index: int in range(20):
		var stagger: float = float(index % 8) * 0.018
		var t: float = age - stagger
		var life: float = 0.34 + float(index % 4) * 0.06
		if t < 0.0 or t >= life:
			continue
		var ratio: float = float(index) / 19.0
		var angle: float = lerpf(-2.70, -0.35, ratio)
		var speed: float = 36.0 + float((index * 13) % 31)
		var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * speed
		var point: Vector2 = origin + velocity * t + Vector2(0.0, 54.0 * t * t)
		point = point.round()
		var tail: Vector2 = (point - velocity * 0.040).round()
		var fade: float = 1.0 - t / life
		var spark_color: Color = Color(1.0, 1.0, 1.0) if index % 3 == 0 else GOLD
		canvas.draw_line(tail, point, Color(spark_color, 0.58 * fade), 1.0)
		canvas.draw_rect(
			Rect2(point, Vector2(2.0 if index % 3 == 0 else 1.0, 1.0)),
			Color(spark_color, 1.0 * fade)
		)


## Dust only inside the three real lamp cones.  Each mote belongs to one bulb
## and is clamped to that bulb's trapezoid, so the hall is never covered by a
## full-screen particle field.
func _draw_motes(canvas: Node2D) -> void:
	if _world_fade <= 0.001:
		return
	var step_t: float = floorf(_time * 12.0) / 12.0
	for row: int in range(LAMP_RAIL_YS.size()):
		var lit: float = _lamp_amounts[row] * _world_fade
		if lit <= 0.001:
			continue
		var rail_y: float = LAMP_RAIL_YS[row]
		for index: int in range(6):
			var bulb: int = (index * 5 + row) % LAMP_XS.size()
			var bulb_x: float = LAMP_XS[bulb]
			var phase: float = fposmod(
				step_t * 0.09 + float(index) * 0.137 + float(row) * 0.29,
				1.0
			)
			var depth: float = 1.0 - phase
			var y: float = rail_y + 10.0 + depth * 62.0
			var half_width: float = lerpf(
				6.0, 30.0 - float(row) * 4.0, depth
			)
			var offset: float = (
				float((index * 7 + row * 3) % 11) / 10.0 - 0.5
			) * 1.30
			var x: float = bulb_x + offset * half_width
			var alpha: float = sin(phase * PI) * 0.34 * lit
			canvas.draw_rect(
				Rect2(roundf(x), roundf(y), 1.0, 1.0),
				Color(WARM_PALE, alpha)
			)


func _diamond_points(center: Vector2, half_x: float, half_y: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -half_y),
		center + Vector2(half_x, 0.0),
		center + Vector2(0.0, half_y),
		center + Vector2(-half_x, 0.0),
	])


# --- visibility / UI helpers ------------------------------------------------

func _set_film_layers_visible(value: bool) -> void:
	if _grade_layer != null:
		_grade_layer.visible = value
	if _ui_layer != null:
		_ui_layer.visible = value
	if not value:
		if _world_layer != null:
			_world_layer.visible = false
		if _gear_left != null:
			_gear_left.visible = false
		if _gear_right != null:
			_gear_right.visible = false


func _set_hold_bar(visible_value: bool, progress: float) -> void:
	if _hold_bg == null or _hold_fill == null:
		return
	_hold_bg.visible = visible_value
	_hold_fill.visible = visible_value
	_hold_fill.size.x = 94.0 * clampf(progress, 0.0, 1.0)


# --- capture helpers --------------------------------------------------------

## Freeze the live scene at an exact beat.  The capture harness owns the chapter
## and calls `finish_capture()` for the control-returned still; this never emits
## `finished` on its own.
func set_time_for_capture(value: float) -> void:
	if _core == null or _player == null:
		return
	_capture_mode = true
	_active = true
	_finished = false
	_finished_emitted = false
	_skipped = false
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_time = clampf(value, 0.0, DURATION)
	_prepare_visuals()
	if _player_camera != null:
		_player_camera.enabled = false
	if _opening_camera != null:
		_opening_camera.enabled = true
		_opening_camera.make_current()
	_set_film_layers_visible(true)
	_apply_time(_time)
	_footer.visible = _time > 0.34
	_footer.modulate.a = 1.0 if _footer.visible else 0.0
	if _vignette != null:
		_vignette.modulate.a = clampf(_grade_alpha * 1.25, 0.0, 1.0)
	if _world_layer != null:
		_world_layer.visible = true
		_world_layer.queue_redraw()


func finish_capture() -> void:
	if not _capture_mode:
		return
	_capture_mode = false
	_time = DURATION
	_apply_time(_time)
	_ended_state()
	_emit_finished()


func is_capture_mode() -> bool:
	return _capture_mode


# --- read API (chapter / tests / capture) -----------------------------------

func is_playing() -> bool:
	return _active and not _finished and not _await_release and not _capture_mode


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
	return DURATION


func get_skip_count() -> int:
	return _skip_count


func get_cue_count() -> int:
	return _cue_count


func has_played_cue(id: String) -> bool:
	return _played_cues.has(id)


func get_space_hold_time() -> float:
	return _space_time


func is_skip_bar_visible() -> bool:
	return _hold_bg != null and _hold_bg.visible


func get_skip_progress() -> float:
	if _hold_fill == null:
		return 0.0
	return _hold_fill.size.x / 94.0


func get_stage_alpha() -> float:
	return 1.0 if _active else 0.0


func get_grade_alpha() -> float:
	return _grade_alpha


func get_phase_name() -> String:
	if not _active and not _capture_mode:
		return "DONE"
	if _time < LAMP_ROWS[0]:
		return "LOOM_SILHOUETTE"
	if _time < ORB_START:
		return "LAMP_GEARS"
	if _time < PULL_START:
		return "CORE_PULSE"
	if _time < PULL_END:
		return "PULL_BACK"
	return "PLAYER_VIEW"


func get_opening_camera() -> Camera2D:
	return _opening_camera


func get_player_camera() -> Camera2D:
	return _player_camera


func get_core() -> LoomCore:
	return _core


func get_node_a() -> LoomNode:
	return _node_a


func get_node_b() -> LoomNode:
	return _node_b


func get_player() -> L3Player:
	return _player


func get_camera_center() -> Vector2:
	if _opening_camera == null:
		return Vector2.ZERO
	return _opening_camera.get_screen_center_position()


func get_camera_zoom() -> float:
	if _opening_camera == null:
		return 1.0
	return _opening_camera.zoom.x


func get_player_view_center() -> Vector2:
	return _gameplay_camera_center()


func get_lamp_rows_lit() -> int:
	var count: int = 0
	for amount: float in _lamp_amounts:
		if amount >= 0.5:
			count += 1
	return count


func get_lamp_row_amount(row: int) -> float:
	if row < 0 or row >= _lamp_amounts.size():
		return 0.0
	return _lamp_amounts[row]


func get_orbs_lit_amount() -> float:
	return _orbs_lit


func get_core_ignite_amount() -> float:
	return _core_ignite


func get_core_sprite_frame() -> int:
	return _core.get_sprite_frame() if _core != null else -1


func get_core_flash_amount() -> float:
	return _core_flash


func get_core_flash_at(value: float) -> float:
	return _core_flash_at(value)


func get_core_level_at(value: float) -> float:
	return _core_level_at(value)


func get_gear_frame() -> int:
	return _gear_frame


func get_gear_frame_at(value: float) -> int:
	return _gear_frame_at(value)


func is_gear_running() -> bool:
	return _gear_power >= 1.0


func get_world_layer() -> Node2D:
	return _world_layer


func get_gear_left() -> Sprite2D:
	return _gear_left


func get_gear_right() -> Sprite2D:
	return _gear_right


## Exact world-space positions the jitter assertion samples.  All of these are
## fixed for the whole held shot; only alpha/frame values animate.
func get_world_overlay_positions() -> Dictionary:
	var result: Dictionary = {}
	if _world_layer != null:
		result["layer"] = _world_layer.global_position
	if _gear_left != null:
		result["gear_left"] = _gear_left.global_position
	if _gear_right != null:
		result["gear_right"] = _gear_right.global_position
	if _core != null:
		result["core"] = _core.global_position
		result["chain_left"] = _core.global_position + Vector2(-32.0, -190.0)
		result["chain_right"] = _core.global_position + Vector2(32.0, -190.0)
	if _node_a != null:
		result["node_a"] = _node_a.global_position
	if _node_b != null:
		result["node_b"] = _node_b.global_position
	return result


## Screen-space anchors of every world overlay.  Rounded to whole pixels; a
## 10-frame comparison of this array is the direct "no ±1 px jump" assertion.
func get_overlay_anchor_screen_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if _world_layer == null:
		return points
	var world_points: Array[Vector2] = [
		Vector2(LAMP_RAIL_X, LAMP_RAIL_YS[0]),
		Vector2(LAMP_RAIL_X, LAMP_RAIL_YS[1]),
		Vector2(LAMP_RAIL_X, LAMP_RAIL_YS[2]),
	]
	if _core != null:
		world_points.append(_core.global_position)
		world_points.append(_core.global_position + Vector2(-32.0, -190.0))
		world_points.append(_core.global_position + Vector2(32.0, -190.0))
	if _node_a != null:
		world_points.append(_node_a.global_position)
	if _node_b != null:
		world_points.append(_node_b.global_position)
	var transform: Transform2D = _world_layer.get_global_transform_with_canvas()
	for world_point: Vector2 in world_points:
		points.append((transform * world_point).round())
	return points


## (held_start, held_end): the camera is bit-for-bit static in this window.
func get_static_hold_span() -> Vector2:
	return Vector2(PUSH_END, PULL_START)
