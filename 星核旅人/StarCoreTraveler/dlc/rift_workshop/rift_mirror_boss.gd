class_name RiftMirrorBoss
extends Node2D

## "双面镜 · 裂隙守门者" — the single original rift-workshop boss.
##
## Three forms, each declared before the player ever meets it:
##   form 1: both plates intact, slow phase wave + one sweep (teaching);
##   form 2: both plates are anchored by one rift wisp.  A living anchor makes
##           its plate immune; killing the anchor opens a 6 s shatter window.
##           The mirror summons the two anchors, sweeps faster, and every third
##           attack splits off one translucent mirror double.  The double is the
##           only threat while the real body holds still: a 0.6 s sweep warning,
##           one low sweep, then it fades.  A same-phase J scatters it early;
##           jumping clears the low beam.  It never fires on the same frame as a
##           wave, sweep or summon;
##   form 3: the mirror cracks, the plates orbit the core quickly, phase wave
##           and double sweep alternate, the exposed-core window is shorter and
##           extra summons are more frequent.  Every third attack is a tracking
##           mirror light: a 0.6 s core charge, then one 60 px/s homing orb that
##           vanishes on the floor (or on the player).  Only one orb may exist;
##           the real body waits until it resolves.  Jump over it, or move so it
##           is led into the ground.
##
## A form break is a 1.1 s transition (plate shards, mirror crack, white core
## flash).  The final core clear is a 1.35 s collapse: the plates fall, the
## chains snap, the core implodes with a white flash and particles.  Only when
## that collapse finishes does `defeated` fire, so the chapter cannot activate
## the finish point during the animation.
##
## Attack read order at 1x:
##   phase wave  = thick gold/cyan 2 px ground band with a sun/moon icon;
##   mirror sweep= thin white beam, red line warning, ground dust;
##   summon      = violet portal rings and hanging chain links.
##
## Sprite evidence: tools/gen_assets.py writes the 128x112 base and the four
## 48x48 face plates from code.  Reference record:
## tests/out/ref/REFERENCE_DLC2_FORMS_20261126.md.

signal fight_started
signal phase_wave_released(positive_after: bool, flipped: bool)
signal player_struck(away_direction: int)
signal summon_requested(count: int)
signal anchors_requested(count: int)
signal anchor_window_started(positive: bool, seconds: float)
signal anchor_window_expired(positive: bool)
signal face_shattered(positive: bool)
signal core_hit(remaining: int)
signal core_exposed
signal core_closed
signal phase_cleared(phase_index: int)
signal phase_started(phase_index: int)
signal defeat_started
signal collapse_finished
signal defeated
signal clone_cast_started(positive: bool)
signal homing_cast_started

const BOSS_SHEET: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_boss_128x112_8f.png"
)
const FACE_GOLD: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_face_gold_48x48.png"
)
const FACE_GOLD_BROKEN: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_face_gold_broken_48x48.png"
)
const FACE_CYAN: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_face_cyan_48x48.png"
)
const FACE_CYAN_BROKEN: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_face_cyan_broken_48x48.png"
)
const CRACK_LAYER_SCRIPT: Script = preload(
	"res://dlc/rift_workshop/rift_boss_cracks.gd"
)
const ORB_DRAWER_SCRIPT: Script = preload(
	"res://dlc/rift_workshop/rift_boss_orb.gd"
)

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const GOLD_PALE: Color = Color("#ffe796")
const CYAN_PALE: Color = Color("#bcffff")
const IRON: Color = Color("#343c40")
const IRON_DARK: Color = Color(0.035, 0.047, 0.055, 0.98)
const WHITE: Color = Color(1.0, 0.985, 0.92)
const INK: Color = Color(0.008, 0.018, 0.024, 1.0)
const PURPLE: Color = Color("#a86cff")
const PURPLE_PALE: Color = Color("#e0c8ff")
const PURPLE_DARK: Color = Color("#2a123f")
const RED: Color = Color("#ff5a4f")
const DUST: Color = Color("#cdb98f")
const MAGENTA: Color = Color("#ff74d1")

const MAX_PHASES: int = 3
const CORE_HITS_PER_PHASE: int = 3
const FACE_OFFSET: Vector2 = Vector2(32.0, 18.0)
const FACE_SIZE: float = 48.0
## Hit rects are a little more generous than the drawn plate so a J that visibly
## reaches the lower rim is accepted at 1x.
const FACE_HIT_SIZE: Vector2 = Vector2(48.0, 58.0)
const CORE_HIT_RECT: Rect2 = Rect2(-18.0, -20.0, 36.0, 52.0)
const BOSS_RECT: Rect2 = Rect2(-64.0, -56.0, 128.0, 112.0)

const INTRO_TIME: float = 1.0
## Exactly 0.6 s, named by the guide and read by cue_test.
const WAVE_WARN_TIME: float = 0.60
const SWEEP_WARN_SLOW: float = 0.85
const SWEEP_WARN_FAST: float = 0.55
const SWEEP_WARN_FORM_3: float = 0.46
## 2026-11-27 readability pass: the second sweep of form 3 gets a full
## 0.65 s telegraph plus a 0.12 s landing gap after the first beam.  The
## single-sweep hit width (48 px body / low beam) and damage are unchanged.
const DOUBLE_SWEEP_WARN: float = 0.65
const DOUBLE_SWEEP_GAP: float = 0.12
const SUMMON_CAST_TIME: float = 0.60
## 1.0-1.2 s is the approved form-break window.
const PHASE_CLEAR_TIME: float = 1.10
## 1.2-1.5 s is the approved final collapse window.
const DEFEAT_COLLAPSE_TIME: float = 1.35
const FACE_ANCHOR_WINDOW: float = 6.0
const CORE_WINDOW_FORM_1: float = 10.0
const CORE_WINDOW_FORM_2: float = 8.0
const CORE_WINDOW_FORM_3: float = 5.5
const FORM_3_SUMMON_PERIOD: float = 9.0
const FLOOR_WAVE_HEIGHT: float = 12.0
const FACE_ORBIT_RADIUS_FORM_2: float = 34.0
const FACE_ORBIT_RADIUS_FORM_3: float = 40.0
const FACE_ORBIT_SPEED_FORM_2: float = 0.55
const FACE_ORBIT_SPEED_FORM_3: float = 1.90

## Form-2 mirror double.  The warning is exactly 0.6 s; the double stays
## translucent through warning and release, and a same-phase J scatters it.
const CLONE_WARN_TIME: float = 0.60
const CLONE_RELEASE_TIME: float = 0.24
const CLONE_OFFSET_X: float = 72.0
const CLONE_OFFSET_Y: float = -24.0
const CLONE_HIT_SIZE: Vector2 = Vector2(56.0, 100.0)

## Form-3 tracking mirror light.  60 px/s is inside the approved 55-65 px/s
## band; the turn rate keeps it dodgeable, and the floor always ends it.
const HOMING_WARN_TIME: float = 0.60
const HOMING_SPEED: float = 60.0
const HOMING_TURN_RATE: float = 1.90
const HOMING_LIFETIME: float = 5.0
const HOMING_RADIUS: float = 5.0
const HOMING_GROUND_MARGIN: float = 4.0
const HOMING_MAX_ACTIVE: int = 1

enum State {
	DORMANT,
	INTRO,
	IDLE,
	WAVE_WARN,
	WAVE_RELEASE,
	SWEEP_WARN,
	SWEEP_RELEASE,
	## Short readable landing gap between the two form-3 sweeps.
	SWEEP_GAP,
	## Form-2 mirror double: one 0.6 s warning, then one low sweep.
	CLONE_WARN,
	CLONE_RELEASE,
	## Form-3 tracking mirror light: 0.6 s charge at the core, then flight.
	HOMING_CHARGE,
	SUMMON_CAST,
	CORE_OPEN,
	PHASE_CLEAR,
	DEFEATED,
}

@export var floor_y: float = 320.0
@export var arena_left: float = 1240.0
@export var arena_right: float = 1880.0
@export var player_path: NodePath = NodePath()

var _player: L3Player = null
var _base: Sprite2D = null
var _cracks: Node2D = null
var _face_gold: Sprite2D = null
var _face_cyan: Sprite2D = null
var _clone_sprite: Sprite2D = null
var _orb_drawer: Node2D = null

var _state: State = State.DORMANT
var _state_time: float = 0.0
var _state_duration: float = 0.0
var _attack_gap: float = 0.0
var _attack_index: int = 0
var _active: bool = false
var _suspended: bool = true
var _defeated: bool = false
var _collapse_finished: bool = false

var _phase_index: int = 0
var _form_time: float = 0.0
var _core_hp: int = CORE_HITS_PER_PHASE
var _gold_intact: bool = true
var _cyan_intact: bool = true
var _core_exposed: bool = false
var _summoned_this_phase: bool = false

var _gold_anchor: RiftPolarityWisp = null
var _cyan_anchor: RiftPolarityWisp = null
var _gold_anchor_window: float = 0.0
var _cyan_anchor_window: float = 0.0
var _anchor_retry_left: float = 0.0
var _anchor_portal_time: float = 0.0
var _anchor_pending: bool = false

var _phase_wave_count: int = 0
var _sweep_count: int = 0
var _summon_count: int = 0
## Test/capture hook: keep the boss hittable but stop starting new attacks.
var _attacks_enabled: bool = true

var _last_swing_id: int = -1
var _last_result: Dictionary = {}

var _sway_time: float = 0.0
var _wave_flip_done: bool = false
var _wave_result_positive: bool = false
var _sweep_resolved: bool = false
var _sweep_bursts_left: int = 0
var _summon_clock: float = 0.0
var _expose_flash: float = 0.0
var _core_hit_flash: float = 0.0
var _phase_flash: float = 0.0
var _bursts: Array[Dictionary] = []
var _defeat_time: float = 0.0
var _transition_started_msec: int = 0
var _last_transition_ms: int = 0
var _wave_warning_draws: int = 0
var _sweep_warning_draws: int = 0
var _summon_draws: int = 0
var _face_local_gold: Vector2 = Vector2(-FACE_OFFSET.x, FACE_OFFSET.y)
var _face_local_cyan: Vector2 = Vector2(FACE_OFFSET.x, FACE_OFFSET.y)

# Mirror double (form 2).
var _clone_active: bool = false
var _clone_positive: bool = true
var _clone_local: Vector2 = Vector2.ZERO
var _clone_resolved: bool = true
var _clone_hit_flash: float = 0.0
var _clone_warn_draws: int = 0
var _clone_release_draws: int = 0
var _clone_cast_count: int = 0
var _clone_release_count: int = 0
var _clone_shatter_count: int = 0

# Tracking mirror light (form 3).
var _homing_active: bool = false
var _homing_position: Vector2 = Vector2.ZERO
var _homing_direction: Vector2 = Vector2.DOWN
var _homing_time_left: float = 0.0
var _homing_trail: Array[Vector2] = []
var _homing_charge_draws: int = 0
var _homing_cast_count: int = 0
var _homing_fire_count: int = 0
var _homing_ground_hit_count: int = 0
var _homing_hit_player_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Absolute draw order in the arena:
	#   terrain 2 < body/cracks 3 < face plates 4 < effects 5 < player 6.
	# The mirror body and the crack layer share z=-2; the crack child is added
	# after the body so it covers the stone, and both face plates are added
	# after the crack layer at z=-1 so an orbiting plate always covers a crack
	# it passes over.  The parent _draw (chains, floor wave, shatter bursts,
	# core flashes, defeat) stays above the plates.  Player is raised to z=6.
	z_index = 5
	_build_sprites()
	_resolve_player()
	_update_face_visuals()
	queue_redraw()


func _build_sprites() -> void:
	_base = Sprite2D.new()
	_base.name = "MirrorBase"
	_base.texture = BOSS_SHEET
	_base.hframes = 8
	_base.vframes = 1
	_base.centered = true
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base.frame = 0
	_base.z_index = -2
	add_child(_base)

	# Same effective z as the body but a later sibling, so the cracks sit on
	# the stone.  The plates below are added even later at z=-1, so they stay
	# above this layer.
	_cracks = CRACK_LAYER_SCRIPT.new() as Node2D
	_cracks.name = "MirrorCracks"
	_cracks.z_index = -2
	add_child(_cracks)

	_face_gold = _make_face("GoldFace", FACE_GOLD, Vector2(-FACE_OFFSET.x, FACE_OFFSET.y))
	_face_cyan = _make_face("CyanFace", FACE_CYAN, Vector2(FACE_OFFSET.x, FACE_OFFSET.y))

	# Form-2 double: the same stone sheet, translucent and phase-tinted.  It is
	# a child at z=0, so it reads above the plates but below the player (z=6)
	# and never creates a second solid-looking mirror.
	_clone_sprite = Sprite2D.new()
	_clone_sprite.name = "MirrorDouble"
	_clone_sprite.texture = BOSS_SHEET
	_clone_sprite.hframes = 8
	_clone_sprite.vframes = 1
	_clone_sprite.centered = true
	_clone_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clone_sprite.z_index = 0
	_clone_sprite.visible = false
	add_child(_clone_sprite)

	# Draw-only sibling above the body/plates but below the player.  The parent
	# _draw() is behind opaque child sprites, so the orb needs its own node.
	_orb_drawer = ORB_DRAWER_SCRIPT.new() as Node2D
	_orb_drawer.name = "MirrorLight"
	add_child(_orb_drawer)


func _make_face(node_name: String, texture: Texture2D, face_position: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = face_position
	sprite.z_index = -1
	add_child(sprite)
	return sprite


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if not player_path.is_empty():
		var target: Node = get_node_or_null(player_path)
		if target is L3Player:
			_player = target as L3Player
			return
	var parent: Node = get_parent()
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child is L3Player:
			_player = child as L3Player
			return


func _process(delta: float) -> void:
	if _suspended:
		return
	_sway_time += delta
	_form_time += delta
	_animate_sprites()
	_update_flashes(delta)
	_tick_homing(delta)
	if _defeated:
		_defeat_time += delta
		if not _collapse_finished and _defeat_time >= DEFEAT_COLLAPSE_TIME:
			_finish_collapse()
		queue_redraw()
		return
	if not _active:
		queue_redraw()
		return
	_tick_anchor_state(delta)
	_state_time += delta
	match _state:
		State.INTRO:
			if _state_time >= _state_duration:
				_enter_idle(_form_attack_gap())
		State.IDLE:
			_tick_extra_summon(delta)
			if _attacks_enabled:
				_attack_gap = maxf(_attack_gap - delta, 0.0)
				if _attack_gap <= 0.0:
					_start_next_attack()
		State.WAVE_WARN:
			if _state_time >= _state_duration:
				_release_wave()
		State.WAVE_RELEASE:
			if _state_time >= _state_duration:
				_enter_idle(_form_attack_gap())
		State.SWEEP_WARN:
			if _state_time >= _state_duration:
				_release_sweep()
		State.SWEEP_RELEASE:
			if _state_time >= _state_duration:
				if _sweep_bursts_left > 0:
					# The first beam has passed.  Hold a short, visibly empty
					# landing gap before the full second-sweep telegraph.
					_enter_state(State.SWEEP_GAP, DOUBLE_SWEEP_GAP)
				else:
					_enter_idle(_form_attack_gap())
		State.SWEEP_GAP:
			if _state_time >= _state_duration:
				_sweep_resolved = false
				_enter_state(State.SWEEP_WARN, DOUBLE_SWEEP_WARN)
		State.CLONE_WARN:
			if _state_time >= _state_duration:
				_release_clone()
		State.CLONE_RELEASE:
			if _state_time >= _state_duration:
				_finish_clone()
		State.HOMING_CHARGE:
			if _state_time >= _state_duration:
				_launch_homing()
		State.SUMMON_CAST:
			if _state_time >= _state_duration:
				_finish_summon()
		State.CORE_OPEN:
			if _state_duration > 0.0 and _state_time >= _state_duration:
				_close_core()
		State.PHASE_CLEAR:
			if _state_time >= _state_duration:
				_finish_phase_clear()
	_update_crack_layer()
	queue_redraw()


func _tick_extra_summon(delta: float) -> void:
	if _phase_index < 2 or _core_exposed or not _attacks_enabled:
		return
	if _homing_active or _clone_active:
		return
	_summon_clock += delta
	if _summon_clock >= FORM_3_SUMMON_PERIOD:
		_summon_clock = 0.0
		_start_summon()


func _animate_sprites() -> void:
	_animate_clone()
	if _base != null:
		var base_offset: int = 4 if _core_exposed else 0
		_base.frame = base_offset + int(_sway_time * 2.0) % 4
	if _defeated:
		var t: float = clampf(_defeat_time / DEFEAT_COLLAPSE_TIME, 0.0, 1.0)
		_base.rotation = sin(t * 38.0) * 0.035 * (1.0 - t)
		_base.scale = Vector2.ONE * (1.0 - 0.08 * t)
		# After the first quarter of the collapse the whole sheet is gone; the
		# parent draw then shows a broken ring, falling shards and the imploding
		# core instead of a still-intact mirror.
		_base.visible = t < 0.26
		if _face_gold != null:
			_face_gold.modulate.a = clampf(1.0 - t * 2.2, 0.0, 1.0)
		if _face_cyan != null:
			_face_cyan.modulate.a = clampf(1.0 - t * 2.2, 0.0, 1.0)
		return
	if _face_gold == null or _face_cyan == null:
		return
	if _phase_index == 0:
		var sway: float = sin(_sway_time * 1.5)
		_face_local_gold = Vector2(
			-FACE_OFFSET.x + sway * 1.5,
			FACE_OFFSET.y + cos(_sway_time * 1.2) * 1.2
		)
		var sway2: float = sin(_sway_time * 1.5 + PI)
		_face_local_cyan = Vector2(
			FACE_OFFSET.x + sway2 * 1.5,
			FACE_OFFSET.y + cos(_sway_time * 1.2 + PI) * 1.2
		)
		_face_gold.rotation = sway * 0.018
		_face_cyan.rotation = sway2 * 0.018
	elif _phase_index == 1:
		_orbit_faces(FACE_ORBIT_SPEED_FORM_2, FACE_ORBIT_RADIUS_FORM_2)
	else:
		_orbit_faces(FACE_ORBIT_SPEED_FORM_3, FACE_ORBIT_RADIUS_FORM_3)
	_face_gold.position = _face_local_gold
	_face_cyan.position = _face_local_cyan


func _orbit_faces(speed: float, radius: float) -> void:
	var angle: float = _form_time * speed
	_face_local_gold = Vector2(
		cos(PI + angle) * radius,
		FACE_OFFSET.y + sin(PI + angle) * radius * 0.55
	)
	_face_local_cyan = Vector2(
		cos(angle) * radius,
		FACE_OFFSET.y + sin(angle) * radius * 0.55
	)
	_face_gold.rotation = sin(angle) * 0.06
	_face_cyan.rotation = sin(angle + PI) * 0.06


## The double stays a translucent copy in the air.  Alpha rises during the
## 0.6 s warning, then holds a firmer ghost for the single release frame; a
## same-phase hit flashes it white before it scatters.
func _animate_clone() -> void:
	if _clone_sprite == null:
		return
	if not _clone_active:
		_clone_sprite.visible = false
		return
	_clone_sprite.visible = true
	_clone_sprite.position = _clone_local
	_clone_sprite.frame = int(_sway_time * 2.0) % 4
	var pulse: float = 0.5 + 0.5 * sin(_sway_time * 9.0)
	var alpha: float = 0.42 + 0.10 * pulse
	if _state == State.CLONE_RELEASE:
		alpha = 0.72
	var tint: Color = GOLD_PALE if _clone_positive else CYAN_PALE
	if _clone_hit_flash > 0.0:
		tint = WHITE
		alpha = minf(alpha + 0.35 * _clone_hit_flash, 0.96)
	_clone_sprite.modulate = Color(tint.r, tint.g, tint.b, alpha)


func _update_flashes(delta: float) -> void:
	_expose_flash = maxf(_expose_flash - delta * 4.0, 0.0)
	_core_hit_flash = maxf(_core_hit_flash - delta * 6.0, 0.0)
	_phase_flash = maxf(_phase_flash - delta * 2.5, 0.0)
	_clone_hit_flash = maxf(_clone_hit_flash - delta * 6.0, 0.0)
	_anchor_portal_time = maxf(_anchor_portal_time - delta, 0.0)
	var alive: Array[Dictionary] = []
	for burst: Dictionary in _bursts:
		burst["t"] = float(burst.get("t", 0.0)) + delta
		if float(burst["t"]) < float(burst.get("life", 0.50)):
			alive.append(burst)
	_bursts = alive


# --- public lifecycle ------------------------------------------------------

func set_player_target(player: L3Player) -> void:
	_player = player


func begin_fight() -> void:
	if _defeated:
		return
	_active = true
	_suspended = false
	_enter_state(State.INTRO, INTRO_TIME)
	fight_started.emit()
	if _phase_index > 0:
		# A current-form retry starts suspended; the form's anchors must descend
		# again as the fight resumes.  On a normal phase change they already
		# exist, and this is a no-op.
		_request_missing_anchors()
	queue_redraw()


func set_suspended(value: bool) -> void:
	# Freeze only.  Do not consume a queued wave/sweep resolution: a pause in
	# the middle of a telegraph must resume the same attack, not cancel it.
	_suspended = value


func reset_full() -> void:
	_active = false
	_suspended = true
	_defeated = false
	_collapse_finished = false
	_phase_index = 0
	_form_time = 0.0
	_core_hp = CORE_HITS_PER_PHASE
	_gold_intact = true
	_cyan_intact = true
	_core_exposed = false
	_summoned_this_phase = false
	_attack_index = 0
	_expose_flash = 0.0
	_core_hit_flash = 0.0
	_phase_flash = 0.0
	_bursts.clear()
	_state = State.DORMANT
	_state_time = 0.0
	_state_duration = 0.0
	_attack_gap = 0.0
	_last_swing_id = -1
	_last_result = {}
	_defeat_time = 0.0
	_transition_started_msec = 0
	_last_transition_ms = 0
	_wave_warning_draws = 0
	_sweep_warning_draws = 0
	_summon_draws = 0
	_attacks_enabled = true
	_summon_clock = 0.0
	_sweep_bursts_left = 0
	_clear_anchors()
	_clear_new_attacks()
	_clone_cast_count = 0
	_clone_release_count = 0
	_clone_shatter_count = 0
	_clone_warn_draws = 0
	_clone_release_draws = 0
	_clone_hit_flash = 0.0
	_homing_cast_count = 0
	_homing_fire_count = 0
	_homing_ground_hit_count = 0
	_homing_hit_player_count = 0
	_homing_charge_draws = 0
	_base.rotation = 0.0
	_base.scale = Vector2.ONE
	_base.modulate = Color.WHITE
	_base.visible = true
	if _face_gold != null:
		_face_gold.visible = true
		_face_gold.modulate = Color.WHITE
	if _face_cyan != null:
		_face_cyan.visible = true
		_face_cyan.modulate = Color.WHITE
	_update_face_visuals()
	_update_crack_layer()
	queue_redraw()


## A health death replays the CURRENT form, not the whole three-form fight.
## Every form-owned state returns to its opening (plates, core 3/3, anchors,
## attack cursor, cracks); only _phase_index and the form count are kept.
func reset_current_form() -> void:
	var phase: int = clampi(_phase_index, 0, MAX_PHASES - 1)
	reset_full()
	_phase_index = phase
	_form_time = 0.0
	_state = State.DORMANT
	_state_time = 0.0
	_state_duration = 0.0
	_active = false
	_suspended = true
	_update_face_visuals()
	_update_crack_layer()
	queue_redraw()


func get_boss_sprite() -> Sprite2D:
	return _base


# --- hit resolution --------------------------------------------------------

## Called by the chapter at the player's real hit window, once per swing id.
## Returns a code the chapter can surface in the HUD:
## FACE_SHATTER / CORE_HIT / SAME_PHASE / SHIELDED / ANCHORED /
## MISS_RANGE / MISS_BEHIND / INACTIVE / DUPLICATE.
func receive_player_hit(
	player: Node2D, facing: int, positive: bool, swing_id: int
) -> Dictionary:
	if _last_swing_id == swing_id:
		return {"code": "DUPLICATE"}
	_last_swing_id = swing_id
	if not _active or _suspended or _defeated:
		return _remember({"code": "INACTIVE"})
	if _state == State.INTRO or _state == State.PHASE_CLEAR or _state == State.DORMANT:
		return _remember({"code": "INACTIVE"})
	if player == null or not is_instance_valid(player):
		return _remember({"code": "MISS_RANGE"})
	var hit_rect: Rect2 = _player_hit_rect(player, facing)
	# Form-2 double: it is a real target, not a fake that ignores the swing.
	# It must be checked before the boss body because it stands beside it; a
	# same-phase J scatters it, an opposite-phase J is refused.
	if _clone_active:
		var clone_center: Vector2 = get_clone_global_position()
		var clone_dx: float = clone_center.x - player.global_position.x
		if hit_rect.intersects(get_clone_rect()):
			if clone_dx > 1.0 and facing < 0:
				return _remember({"code": "MISS_BEHIND"})
			if clone_dx < -1.0 and facing > 0:
				return _remember({"code": "MISS_BEHIND"})
			if positive == _clone_positive:
				_shatter_clone()
				return _remember({
					"code": "CLONE_SHATTER", "positive": _clone_positive,
				})
			return _remember({
				"code": "CLONE_SHIELDED", "positive": _clone_positive,
			})
	if not hit_rect.intersects(get_boss_rect()):
		return _remember({"code": "MISS_RANGE"})
	# Facing must point at the mirror, not away from it.
	var dx: float = global_position.x - player.global_position.x
	if dx >= 0.0 and facing < 0:
		return _remember({"code": "MISS_BEHIND"})
	if dx < 0.0 and facing > 0:
		return _remember({"code": "MISS_BEHIND"})

	if _core_exposed:
		if hit_rect.intersects(get_core_rect()):
			var remaining: int = maxi(_core_hp - 1, 0)
			_core_hp = remaining
			_core_hit_flash = 1.0
			core_hit.emit(remaining)
			if remaining <= 0:
				_start_phase_clear()
			return _remember({"code": "CORE_HIT", "remaining": remaining})
		return _remember({"code": "SHIELDED"})

	if _gold_intact and hit_rect.intersects(get_face_rect(true)):
		if not is_face_breakable(true):
			return _remember({
				"code": "ANCHORED", "positive": true,
				"window": _gold_anchor_window,
			})
		if positive:
			return _remember({"code": "SAME_PHASE", "positive": true})
		_shatter_face(true)
		return _remember({"code": "FACE_SHATTER", "positive": true})
	if _cyan_intact and hit_rect.intersects(get_face_rect(false)):
		if not is_face_breakable(false):
			return _remember({
				"code": "ANCHORED", "positive": false,
				"window": _cyan_anchor_window,
			})
		if not positive:
			return _remember({"code": "SAME_PHASE", "positive": false})
		_shatter_face(false)
		return _remember({"code": "FACE_SHATTER", "positive": false})
	return _remember({"code": "SHIELDED"})


func _player_hit_rect(player: Node2D, facing: int) -> Rect2:
	var direction: float = 1.0 if facing >= 0 else -1.0
	var origin_x: float = player.global_position.x + (2.0 if direction > 0.0 else -40.0)
	return Rect2(origin_x, player.global_position.y - 36.0, 38.0, 36.0)


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result
	return result


func _shatter_face(positive: bool) -> void:
	if positive:
		if not _gold_intact:
			return
		_gold_intact = false
		_gold_anchor = null
		_gold_anchor_window = 0.0
		_bursts.append({
			"center": _face_local_gold,
			"color": GOLD, "t": 0.0, "life": 0.52, "kind": "face",
		})
	else:
		if not _cyan_intact:
			return
		_cyan_intact = false
		_cyan_anchor = null
		_cyan_anchor_window = 0.0
		_bursts.append({
			"center": _face_local_cyan,
			"color": CYAN, "t": 0.0, "life": 0.52, "kind": "face",
		})
	_update_face_visuals()
	face_shattered.emit(positive)
	if not _gold_intact and not _cyan_intact:
		_expose_core()


func _update_face_visuals() -> void:
	if _face_gold != null:
		_face_gold.texture = FACE_GOLD if _gold_intact else FACE_GOLD_BROKEN
		_face_gold.modulate = Color.WHITE if _gold_intact else Color(0.78, 0.74, 0.66, 1.0)
	if _face_cyan != null:
		_face_cyan.texture = FACE_CYAN if _cyan_intact else FACE_CYAN_BROKEN
		_face_cyan.modulate = Color.WHITE if _cyan_intact else Color(0.70, 0.80, 0.80, 1.0)
	if _base != null:
		_base.frame = (4 if _core_exposed else 0) + int(_sway_time * 2.0) % 4


func _expose_core() -> void:
	if _core_exposed:
		return
	_core_exposed = true
	_expose_flash = 1.0
	_clear_new_attacks()
	_clear_anchors()
	var window: float = _core_window_for_form()
	_enter_state(State.CORE_OPEN, window)
	_bursts.append({
		"center": Vector2(0.0, 0.0), "color": WHITE,
		"t": 0.0, "life": 0.60, "kind": "core",
	})
	_update_face_visuals()
	core_exposed.emit()
	queue_redraw()


func _close_core() -> void:
	if not _core_exposed:
		return
	_core_exposed = false
	_core_hp = CORE_HITS_PER_PHASE
	_gold_intact = true
	_cyan_intact = true
	_attack_index = 0
	_bursts.append({
		"center": Vector2(0.0, 0.0), "color": PURPLE_PALE,
		"t": 0.0, "life": 0.50, "kind": "core",
	})
	_update_face_visuals()
	_enter_idle(1.0)
	core_closed.emit()
	if _phase_index > 0:
		_anchor_retry_left = 0.0
		_request_missing_anchors()
	queue_redraw()


func _start_phase_clear() -> void:
	if _state == State.PHASE_CLEAR or _defeated:
		return
	_phase_flash = 1.0
	_transition_started_msec = Time.get_ticks_msec()
	_clear_new_attacks()
	_clear_anchors()
	# The two plates visibly shatter for the whole form break, then return with
	# the new form.  The hit rule still uses _gold_intact, so this is visual only.
	if _face_gold != null:
		_face_gold.texture = FACE_GOLD_BROKEN
		_face_gold.modulate = Color(0.82, 0.72, 0.56, 0.82)
	if _face_cyan != null:
		_face_cyan.texture = FACE_CYAN_BROKEN
		_face_cyan.modulate = Color(0.62, 0.78, 0.78, 0.82)
	_bursts.append({
		"center": _face_local_gold, "color": GOLD,
		"t": 0.0, "life": 0.60, "kind": "form",
	})
	_bursts.append({
		"center": _face_local_cyan, "color": CYAN,
		"t": 0.0, "life": 0.60, "kind": "form",
	})
	_bursts.append({
		"center": Vector2(0.0, 0.0), "color": PURPLE_PALE,
		"t": 0.0, "life": 0.70, "kind": "form",
	})
	_enter_state(State.PHASE_CLEAR, PHASE_CLEAR_TIME)
	phase_cleared.emit(_phase_index)
	queue_redraw()


func _finish_phase_clear() -> void:
	_last_transition_ms = Time.get_ticks_msec() - _transition_started_msec
	if _phase_index >= MAX_PHASES - 1:
		_start_defeat()
		return
	_phase_index += 1
	_form_time = 0.0
	_core_hp = CORE_HITS_PER_PHASE
	_gold_intact = true
	_cyan_intact = true
	_core_exposed = false
	_core_hp = CORE_HITS_PER_PHASE
	_attack_index = 0
	_phase_flash = 0.9
	_summon_clock = 0.0
	_sweep_bursts_left = 0
	_anchor_retry_left = 0.0
	_update_face_visuals()
	_update_crack_layer()
	_enter_idle(1.0)
	phase_started.emit(_phase_index)
	if _phase_index > 0:
		_request_missing_anchors()
	queue_redraw()


func _start_defeat() -> void:
	if _defeated:
		return
	_defeated = true
	_collapse_finished = false
	_active = false
	_core_exposed = true
	_state = State.DEFEATED
	_state_time = 0.0
	_defeat_time = 0.0
	_gold_intact = false
	_cyan_intact = false
	_clear_new_attacks()
	_clear_anchors()
	_bursts.append({
		"center": _face_local_gold, "color": GOLD,
		"t": 0.0, "life": 0.85, "kind": "defeat",
	})
	_bursts.append({
		"center": _face_local_cyan, "color": CYAN,
		"t": 0.0, "life": 0.85, "kind": "defeat",
	})
	_bursts.append({
		"center": Vector2(0.0, 0.0), "color": PURPLE_PALE,
		"t": 0.0, "life": 1.10, "kind": "defeat",
	})
	_update_face_visuals()
	_update_crack_layer()
	defeat_started.emit()
	queue_redraw()


func _finish_collapse() -> void:
	if _collapse_finished:
		return
	_collapse_finished = true
	_defeated = true
	_active = false
	defeated.emit()
	collapse_finished.emit()
	queue_redraw()


## Capture/test setup only: use the real defeat signal without a 15-hit fight.
func debug_force_defeat() -> void:
	if _defeated:
		return
	_phase_index = MAX_PHASES - 1
	_core_exposed = true
	_gold_intact = false
	_cyan_intact = false
	_update_face_visuals()
	_start_defeat()


func debug_shatter_face(positive: bool) -> void:
	if positive:
		if _gold_intact:
			_shatter_face(true)
	else:
		if _cyan_intact:
			_shatter_face(false)


# --- anchors ---------------------------------------------------------------

func attach_anchor(positive: bool, wisp: RiftPolarityWisp) -> void:
	if wisp == null or not is_instance_valid(wisp):
		return
	if positive:
		_gold_anchor = wisp
		_gold_anchor_window = 0.0
	else:
		_cyan_anchor = wisp
		_cyan_anchor_window = 0.0
	_anchor_pending = not get_missing_anchor_sides().is_empty()
	_anchor_portal_time = maxf(_anchor_portal_time, 0.55)


func notify_anchor_defeated(positive: bool) -> void:
	if _phase_index < 1 or _core_exposed or _defeated:
		return
	if positive:
		if not _gold_intact:
			return
		_gold_anchor = null
		_gold_anchor_window = FACE_ANCHOR_WINDOW
		_bursts.append({
			"center": _face_local_gold, "color": PURPLE,
			"t": 0.0, "life": 0.55, "kind": "anchor",
		})
		anchor_window_started.emit(true, FACE_ANCHOR_WINDOW)
	else:
		if not _cyan_intact:
			return
		_cyan_anchor = null
		_cyan_anchor_window = FACE_ANCHOR_WINDOW
		_bursts.append({
			"center": _face_local_cyan, "color": PURPLE,
			"t": 0.0, "life": 0.55, "kind": "anchor",
		})
		anchor_window_started.emit(false, FACE_ANCHOR_WINDOW)
	_anchor_retry_left = maxf(_anchor_retry_left, FACE_ANCHOR_WINDOW)
	queue_redraw()


func clear_anchors() -> void:
	_clear_anchors()


func _clear_anchors() -> void:
	_gold_anchor = null
	_cyan_anchor = null
	_gold_anchor_window = 0.0
	_cyan_anchor_window = 0.0
	_anchor_pending = false
	_anchor_retry_left = 0.0


func _has_anchor(anchor: RiftPolarityWisp) -> bool:
	return (
		anchor != null and is_instance_valid(anchor) and anchor.is_alive()
		and not anchor.is_queued_for_deletion()
	)


func has_face_anchor(positive: bool) -> bool:
	return _has_anchor(_gold_anchor if positive else _cyan_anchor)


func get_face_anchor(positive: bool) -> RiftPolarityWisp:
	return _gold_anchor if positive else _cyan_anchor


func get_alive_anchor_count() -> int:
	return (1 if has_face_anchor(true) else 0) + (1 if has_face_anchor(false) else 0)


## 1 = gold anchor, -1 = cyan anchor, 0 = not an anchor.
func get_anchor_side_for(wisp: RiftPolarityWisp) -> int:
	if wisp == null or not is_instance_valid(wisp):
		return 0
	if wisp == _gold_anchor:
		return 1
	if wisp == _cyan_anchor:
		return -1
	return 0


func get_anchor_window_left(positive: bool) -> float:
	return _gold_anchor_window if positive else _cyan_anchor_window


func get_missing_anchor_sides() -> Array[bool]:
	var missing: Array[bool] = []
	if _phase_index < 1 or _core_exposed or _defeated:
		return missing
	if _gold_intact and not has_face_anchor(true) and _gold_anchor_window <= 0.0:
		missing.append(true)
	if _cyan_intact and not has_face_anchor(false) and _cyan_anchor_window <= 0.0:
		missing.append(false)
	return missing


func is_face_breakable(positive: bool) -> bool:
	if _phase_index < 1:
		return true
	if has_face_anchor(positive):
		return false
	return get_anchor_window_left(positive) > 0.0


func _request_missing_anchors() -> void:
	var missing: Array[bool] = get_missing_anchor_sides()
	if missing.is_empty():
		_anchor_pending = false
		return
	_anchor_pending = true
	_anchor_retry_left = 1.15
	_anchor_portal_time = maxf(_anchor_portal_time, 0.85)
	anchors_requested.emit(missing.size())


func _tick_anchor_state(delta: float) -> void:
	if _phase_index < 1 or _core_exposed or _defeated:
		return
	if _gold_intact and _gold_anchor_window > 0.0:
		_gold_anchor_window = maxf(_gold_anchor_window - delta, 0.0)
		if _gold_anchor_window <= 0.0:
			_bursts.append({
				"center": _face_local_gold, "color": PURPLE_PALE,
				"t": 0.0, "life": 0.45, "kind": "anchor",
			})
			anchor_window_expired.emit(true)
			_anchor_retry_left = minf(_anchor_retry_left, 0.35)
			_anchor_pending = true
	if _cyan_intact and _cyan_anchor_window > 0.0:
		_cyan_anchor_window = maxf(_cyan_anchor_window - delta, 0.0)
		if _cyan_anchor_window <= 0.0:
			_bursts.append({
				"center": _face_local_cyan, "color": PURPLE_PALE,
				"t": 0.0, "life": 0.45, "kind": "anchor",
			})
			anchor_window_expired.emit(false)
			_anchor_retry_left = minf(_anchor_retry_left, 0.35)
			_anchor_pending = true
	_anchor_retry_left = maxf(_anchor_retry_left - delta, 0.0)
	if _anchor_retry_left <= 0.0:
		_request_missing_anchors()


# --- attacks ---------------------------------------------------------------

func _enter_state(value: State, duration: float) -> void:
	_state = value
	_state_time = 0.0
	_state_duration = duration
	queue_redraw()


func _enter_idle(gap: float) -> void:
	_state = State.IDLE
	_state_time = 0.0
	_state_duration = 0.0
	_attack_gap = maxf(gap, 0.0)
	queue_redraw()


func _form_attack_gap() -> float:
	match _phase_index:
		0:
			return 1.20
		1:
			return 0.75
		_:
			return 0.55


func _core_window_for_form() -> float:
	match _phase_index:
		0:
			return CORE_WINDOW_FORM_1
		1:
			return CORE_WINDOW_FORM_2
		_:
			return CORE_WINDOW_FORM_3


func _start_next_attack() -> void:
	if _core_exposed or _defeated:
		return
	# A resolved new attack never shares the frame with an old one: the mirror
	# double owns its warning/release, and the tracking light makes the real
	# body wait until the single orb has hit the floor or the player.
	if _clone_active or _homing_active:
		return
	match _phase_index:
		0:
			var slot: int = _attack_index % 2
			_attack_index += 1
			if slot == 0:
				_start_wave()
			else:
				_start_sweep(false)
		1:
			var slot: int = _attack_index % 3
			_attack_index += 1
			if slot == 0:
				_start_wave()
			elif slot == 1:
				_start_sweep(false)
			else:
				_start_clone()
		_:
			var slot: int = _attack_index % 3
			_attack_index += 1
			if slot == 0:
				_start_wave()
			elif slot == 1:
				_start_sweep(true)
			else:
				_start_homing()


func _start_wave() -> void:
	_wave_flip_done = false
	_resolve_player()
	_wave_result_positive = true
	if _player != null and is_instance_valid(_player):
		_wave_result_positive = not _player.is_positive()
	_enter_state(State.WAVE_WARN, WAVE_WARN_TIME)


func _release_wave() -> void:
	var release_time: float = 0.50
	if _phase_index == 2:
		release_time = 0.42
	_enter_state(State.WAVE_RELEASE, release_time)
	_phase_wave_count += 1
	if _wave_flip_done:
		return
	_wave_flip_done = true
	_resolve_player()
	if _player != null and is_instance_valid(_player):
		# The floor wave is a grounded threat.  A jump clears it, so the flip
		# is avoidable with movement rather than another key.
		if _player.global_position.y >= floor_y - FLOOR_WAVE_HEIGHT:
			_player.set_polarity_state(not _player.is_positive())
			phase_wave_released.emit(_player.is_positive(), true)
		else:
			phase_wave_released.emit(_player.is_positive(), false)


func _start_sweep(double_sweep: bool = false) -> void:
	_sweep_resolved = false
	_sweep_bursts_left = 2 if double_sweep else 1
	var warn: float = SWEEP_WARN_SLOW
	if _phase_index == 1:
		warn = SWEEP_WARN_FAST
	elif _phase_index == 2:
		warn = SWEEP_WARN_FORM_3
	_enter_state(State.SWEEP_WARN, warn)


func _release_sweep() -> void:
	var release: float = 0.30 if _phase_index == 0 else 0.24
	_enter_state(State.SWEEP_RELEASE, release)
	_sweep_count += 1
	_sweep_bursts_left = maxi(_sweep_bursts_left - 1, 0)
	if _sweep_resolved:
		return
	_sweep_resolved = true
	_resolve_player()
	if _player == null or not is_instance_valid(_player):
		return
	if _player.global_position.x < arena_left or _player.global_position.x > arena_right:
		return
	if _player.global_position.y < floor_y - FLOOR_WAVE_HEIGHT:
		# Jumped over the low sweep.
		return
	var away: int = 1 if _player.global_position.x >= global_position.x else -1
	if _player.receive_enemy_strike(away):
		player_struck.emit(away)


func _start_summon() -> void:
	_enter_state(State.SUMMON_CAST, SUMMON_CAST_TIME)


func _finish_summon() -> void:
	_summon_count += 1
	summon_requested.emit(2)
	_enter_idle(1.0)


# --- form-2 mirror double ---------------------------------------------------

## One translucent double appears on the side opposite the player, so it never
## spawns on top of them.  The real body enters the double's state and does
## nothing else until the single sweep finishes or the double is scattered.
func _start_clone() -> void:
	if _clone_active or _homing_active or _defeated or _core_exposed:
		return
	_resolve_player()
	_clone_positive = true
	var player_x: float = global_position.x
	if _player != null and is_instance_valid(_player):
		_clone_positive = _player.is_positive()
		player_x = _player.global_position.x
	var side: float = 1.0 if player_x <= global_position.x else -1.0
	_clone_local = Vector2(CLONE_OFFSET_X * side, CLONE_OFFSET_Y)
	_clone_active = true
	_clone_resolved = false
	_clone_hit_flash = 0.0
	_clone_cast_count += 1
	_animate_clone()
	_enter_state(State.CLONE_WARN, CLONE_WARN_TIME)
	clone_cast_started.emit(_clone_positive)
	queue_redraw()


func _release_clone() -> void:
	if not _clone_active:
		_enter_idle(_form_attack_gap())
		return
	_enter_state(State.CLONE_RELEASE, CLONE_RELEASE_TIME)
	_clone_release_count += 1
	_resolve_clone_sweep()
	queue_redraw()


func _resolve_clone_sweep() -> void:
	if _clone_resolved:
		return
	_clone_resolved = true
	_resolve_player()
	if _player == null or not is_instance_valid(_player):
		return
	if _player.global_position.x < arena_left or _player.global_position.x > arena_right:
		return
	if _player.global_position.y < floor_y - FLOOR_WAVE_HEIGHT:
		# The double's beam is the same low line as the mirror sweep: jump it.
		return
	var clone_x: float = get_clone_global_position().x
	var away: int = 1 if _player.global_position.x >= clone_x else -1
	if _player.receive_enemy_strike(away):
		player_struck.emit(away)


## Same-phase J entry from receive_player_hit().  A warning-phase hit cancels
## the whole sweep; a release-phase hit only scatters the already-fired ghost.
func _shatter_clone() -> void:
	if not _clone_active:
		return
	_clone_shatter_count += 1
	_clone_hit_flash = 1.0
	_bursts.append({
		"center": _clone_local, "color": PURPLE_PALE,
		"t": 0.0, "life": 0.50, "kind": "clone",
	})
	_clone_active = false
	if _clone_sprite != null:
		_clone_sprite.visible = false
	_clone_resolved = true
	if _state == State.CLONE_WARN:
		_enter_idle(0.90)
	queue_redraw()


func _finish_clone() -> void:
	if _clone_active:
		_bursts.append({
			"center": _clone_local,
			"color": GOLD_PALE if _clone_positive else CYAN_PALE,
			"t": 0.0, "life": 0.40, "kind": "clone",
		})
	_clone_active = false
	if _clone_sprite != null:
		_clone_sprite.visible = false
	_clone_resolved = true
	_enter_idle(_form_attack_gap())


# --- form-3 tracking mirror light ------------------------------------------

func _start_homing() -> void:
	if _homing_active or _clone_active or _defeated or _core_exposed:
		return
	_homing_cast_count += 1
	_enter_state(State.HOMING_CHARGE, HOMING_WARN_TIME)
	homing_cast_started.emit()
	queue_redraw()


## Launch exactly one orb toward the floor under the player.  The target is the
## floor point, not the airborne body, so jumping over it leads it into the
## ground; the slow turn rate lets a moving player curve it sideways.  The real
## body idles until this orb resolves (see _start_next_attack).
func _launch_homing() -> void:
	if _homing_active:
		_enter_idle(0.60)
		return
	_resolve_player()
	_homing_position = global_position + Vector2(0.0, -6.0)
	var target_x: float = global_position.x
	if _player != null and is_instance_valid(_player):
		target_x = _player.global_position.x
	target_x = clampf(target_x, arena_left + HOMING_RADIUS, arena_right - HOMING_RADIUS)
	var target: Vector2 = Vector2(target_x, floor_y - 2.0)
	var direction: Vector2 = (target - _homing_position).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.DOWN
	_homing_direction = direction
	_homing_time_left = HOMING_LIFETIME
	_homing_trail.clear()
	_homing_active = true
	_homing_fire_count += 1
	_bursts.append({
		"center": Vector2(0.0, -6.0), "color": MAGENTA,
		"t": 0.0, "life": 0.42, "kind": "homing",
	})
	_update_homing_visual()
	_enter_idle(1.20)
	queue_redraw()


func _tick_homing(delta: float) -> void:
	if not _homing_active:
		return
	_homing_time_left = maxf(_homing_time_left - delta, 0.0)
	if _homing_time_left <= 0.0:
		_deactivate_homing()
		return
	_resolve_player()
	var target: Vector2 = _homing_position + _homing_direction * 32.0
	if _player != null and is_instance_valid(_player):
		var target_x: float = clampf(
			_player.global_position.x, arena_left + HOMING_RADIUS,
			arena_right - HOMING_RADIUS
		)
		target = Vector2(target_x, floor_y - 2.0)
	var desired: Vector2 = target - _homing_position
	if desired.length_squared() > 0.0001:
		desired = desired.normalized()
		var turn: float = _homing_direction.angle_to(desired)
		turn = clampf(turn, -HOMING_TURN_RATE * delta, HOMING_TURN_RATE * delta)
		_homing_direction = _homing_direction.rotated(turn).normalized()
	_homing_position += _homing_direction * HOMING_SPEED * delta
	_homing_trail.append(_homing_position)
	while _homing_trail.size() > 14:
		_homing_trail.pop_front()
	_update_homing_visual()
	if _player != null and is_instance_valid(_player):
		var body_rect: Rect2 = Rect2(
			_player.global_position - Vector2(6.0, 30.0), Vector2(12.0, 30.0)
		)
		if _homing_rect().intersects(body_rect):
			var away: int = 1 if _player.global_position.x >= _homing_position.x else -1
			if _player.receive_enemy_strike(away):
				_homing_hit_player_count += 1
				_bursts.append({
					"center": _homing_position - global_position,
					"color": WHITE, "t": 0.0, "life": 0.50, "kind": "homing",
				})
				player_struck.emit(away)
				_deactivate_homing()
				return
	if _homing_position.y >= floor_y - HOMING_GROUND_MARGIN:
		_homing_ground_hit_count += 1
		_bursts.append({
			"center": Vector2(
				_homing_position.x - global_position.x, floor_y - global_position.y
			),
			"color": MAGENTA, "t": 0.0, "life": 0.55, "kind": "homing",
		})
		_deactivate_homing()


func _homing_rect() -> Rect2:
	return Rect2(
		_homing_position - Vector2(HOMING_RADIUS, HOMING_RADIUS),
		Vector2(HOMING_RADIUS, HOMING_RADIUS) * 2.0
	)


func _update_homing_visual() -> void:
	if _orb_drawer == null:
		return
	var offsets: Array[Vector2] = []
	for point: Vector2 in _homing_trail:
		offsets.append(point - _homing_position)
	if not _orb_drawer.has_method("set_state"):
		return
	_orb_drawer.call("set_state", _homing_position, offsets, _homing_active)


func _deactivate_homing() -> void:
	_homing_active = false
	_homing_time_left = 0.0
	_homing_trail.clear()
	_update_homing_visual()
	# Give the real body a short, visibly empty recovery after the orb resolves
	# instead of starting the next attack on the same frame.
	if _state == State.IDLE and not _core_exposed and not _defeated:
		_enter_idle(0.80)
	queue_redraw()


func _clear_new_attacks() -> void:
	_clone_active = false
	_clone_resolved = true
	_clone_hit_flash = 0.0
	if _clone_sprite != null:
		_clone_sprite.visible = false
	_homing_active = false
	_homing_time_left = 0.0
	_homing_trail.clear()
	_update_homing_visual()


## Test/capture setup only: start the normal attack state, not fake damage.
func set_attacks_enabled(value: bool) -> void:
	_attacks_enabled = value


func debug_force_wave() -> void:
	if not _active or _defeated or _core_exposed:
		return
	_start_wave()


func debug_force_sweep() -> void:
	if not _active or _defeated or _core_exposed:
		return
	_start_sweep(false)


func debug_force_double_sweep() -> void:
	if not _active or _defeated or _core_exposed:
		return
	_start_sweep(true)


## Test/capture only: let the current CORE_OPEN window expire on the next tick.
func debug_force_core_timeout() -> void:
	if _core_exposed and _state == State.CORE_OPEN:
		_state_time = _state_duration


func debug_force_summon() -> void:
	if not _active or _defeated or _core_exposed:
		return
	_start_summon()


## Capture/test setup only: start the real mirror-double state.
func debug_force_clone() -> void:
	if not _active or _defeated or _core_exposed:
		return
	_start_clone()


## Capture/test setup only: start the real tracking-light charge.
func debug_force_homing() -> void:
	if not _active or _defeated or _core_exposed:
		return
	_start_homing()


## Capture/test setup only: move to a form without replaying the whole fight.
## Plates, core, cracks and anchors are rebuilt for that form; possession/
## durability is not faked.
func debug_set_phase(index: int) -> void:
	if _defeated:
		return
	_phase_index = clampi(index, 0, MAX_PHASES - 1)
	_form_time = 0.0
	_core_hp = CORE_HITS_PER_PHASE
	_gold_intact = true
	_cyan_intact = true
	_core_exposed = false
	_attack_index = 0
	_phase_flash = 0.0
	_summon_clock = 0.0
	_sweep_bursts_left = 0
	_clear_new_attacks()
	_clear_anchors()
	_update_face_visuals()
	_update_crack_layer()
	if _active:
		_enter_idle(0.40)
		_request_missing_anchors()
	queue_redraw()


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	_draw_chains()
	if _state == State.WAVE_WARN:
		_draw_wave_warning()
	elif _state == State.WAVE_RELEASE:
		_draw_wave_release()
	if _state == State.SWEEP_WARN:
		_draw_sweep_warning()
	elif _state == State.SWEEP_RELEASE:
		_draw_sweep_release()
	elif _state == State.SWEEP_GAP:
		_draw_sweep_gap()
	if _state == State.CLONE_WARN:
		_draw_clone_warning()
	elif _state == State.CLONE_RELEASE:
		_draw_clone_release()
	if _state == State.HOMING_CHARGE:
		_draw_homing_charge()
	if _state == State.SUMMON_CAST:
		_draw_summon_cast()
	if _anchor_portal_time > 0.0:
		_draw_anchor_portals()
	_draw_face_bursts()
	_draw_anchor_links()
	_draw_core_effects()
	if _state == State.PHASE_CLEAR:
		_draw_phase_flash()
	if _defeated:
		_draw_defeat()


func _draw_chains() -> void:
	var top_y: float = -global_position.y
	var bottom_y: float = -56.0
	# Top mount plate on the arena ceiling line.
	draw_rect(Rect2(-26.0, top_y, 52.0, 5.0), IRON_DARK)
	draw_rect(Rect2(-22.0, top_y + 1.0, 44.0, 2.0), IRON)
	if _defeated:
		var t: float = clampf(_defeat_time / DEFEAT_COLLAPSE_TIME, 0.0, 1.0)
		for strand: float in [-10.0, 10.0]:
			draw_rect(Rect2(strand - 1.0, top_y + 6.0, 3.0, 14.0), IRON)
		# Loose chain links fall away from the crown.
		for index: int in range(8):
			var fall: float = maxf(t - 0.18 - float(index) * 0.035, 0.0)
			var x: float = -24.0 + float(index) * 7.0 + sin(t * 9.0 + index) * 5.0
			var y: float = -50.0 + fall * 180.0
			draw_rect(Rect2(x, y, 2.0, 3.0), IRON)
			draw_rect(Rect2(x, y, 1.0, 1.0), PURPLE_PALE)
		return
	for strand: float in [-10.0, 10.0]:
		var y: float = top_y + 6.0
		var link: int = 0
		while y < bottom_y - 4.0:
			var sway: float = sin(_sway_time * 1.15 + y * 0.02) * 1.8
			var x: float = strand + sway
			if link % 2 == 0:
				draw_rect(Rect2(x - 1.0, y, 3.0, 2.0), IRON)
				draw_rect(Rect2(x, y + 1.0, 1.0, 1.0), GOLD_PALE if strand < 0.0 else CYAN_PALE)
			else:
				draw_rect(Rect2(x, y, 1.0, 3.0), IRON_DARK)
			y += 4.0
			link += 1
	# Hanger ring at the mirror crown.
	draw_rect(Rect2(-8.0, bottom_y - 3.0, 16.0, 3.0), IRON_DARK)
	draw_rect(Rect2(-6.0, bottom_y - 2.0, 12.0, 1.0), IRON)


func _draw_phase_icon(center: Vector2, color: Color, alpha: float) -> void:
	var pale: Color = GOLD_PALE if color == GOLD else CYAN_PALE
	# 15 x 15 dark badge keeps the 11 px sun/moon legible on the stone face.
	draw_rect(Rect2(center - Vector2(7.0, 7.0), Vector2(15.0, 15.0)), Color(INK, 0.78 * alpha))
	draw_rect(Rect2(center - Vector2(7.0, 7.0), Vector2(15.0, 1.0)), Color(color, 0.62 * alpha))
	draw_rect(Rect2(center - Vector2(7.0, 6.0), Vector2(1.0, 13.0)), Color(color, 0.32 * alpha))
	draw_rect(Rect2(center + Vector2(6.0, -6.0), Vector2(1.0, 13.0)), Color(color, 0.32 * alpha))
	draw_rect(Rect2(center - Vector2(5.0, 5.0), Vector2(11.0, 11.0)), Color(INK, 0.65 * alpha))
	if color == GOLD:
		draw_rect(Rect2(center - Vector2(4.0, 4.0), Vector2(9.0, 9.0)), Color(color, alpha))
		for offset: Vector2 in [
			Vector2(-1.0, -8.0), Vector2(-1.0, 7.0),
			Vector2(-8.0, -1.0), Vector2(7.0, -1.0),
		]:
			draw_rect(Rect2(center + offset, Vector2(3.0, 2.0)), Color(pale, alpha))
		draw_rect(Rect2(center - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), Color(WHITE, alpha))
	else:
		# Crescent: a 6 px cyan disc with an offset ink disc carved out.
		draw_circle(center, 6.0, Color(color, alpha))
		draw_circle(center + Vector2(2.5, 0.0), 5.0, Color(INK, 0.96 * alpha))
		draw_rect(Rect2(center + Vector2(-5.0, -3.0), Vector2(1.0, 2.0)), Color(pale, alpha))
		draw_rect(Rect2(center + Vector2(-4.0, -1.0), Vector2(1.0, 1.0)), Color(pale, alpha))


func _draw_ground_dust(alpha: float, tint: Color = DUST) -> void:
	if alpha <= 0.0:
		return
	var left: float = arena_left - global_position.x
	var width: float = arena_right - arena_left
	var y: float = floor_y - global_position.y
	for index: int in range(24):
		var seed: float = float(index) * 12.9898
		var x: float = left + fposmod(seed * 37.0 + _sway_time * (14.0 + float(index % 4) * 4.0), width)
		var rise: float = fposmod(seed * 11.0 + _sway_time * (8.0 + float(index % 3) * 3.0), 13.0)
		var size: float = 1.0 if index % 3 == 0 else 2.0
		draw_rect(Rect2(x, y - rise, size, 1.0), Color(tint, alpha * (0.55 - rise * 0.02)))


func _draw_wave_warning() -> void:
	_wave_warning_draws += 1
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var pulse: float = 0.62 + 0.38 * sin(_state_time * 20.0)
	var color: Color = GOLD if _wave_result_positive else CYAN
	var left: float = arena_left - global_position.x
	var width: float = arena_right - arena_left
	var y: float = floor_y - global_position.y - 1.0
	# Thick horizontal ground ring: a filled 2 px band plus a soft upper glow.
	draw_rect(Rect2(left, y, width, 2.0), Color(color, 0.55 + 0.30 * pulse))
	draw_rect(Rect2(left, y - 4.0, width, 1.0), Color(color, 0.14 + 0.12 * progress))
	draw_rect(Rect2(left, y + 2.0, width, 1.0), Color(color, 0.18 + 0.14 * progress))
	# Short upward teeth read as a wave, not a flat UI line.
	for index: int in range(18):
		var x: float = left + float(index) * width / 17.0
		var height: float = 3.0 + 4.0 * absf(sin(_state_time * 14.0 + float(index)))
		draw_rect(Rect2(x, y - height, 1.0, height), Color(color, 0.55))
	# Sun / moon icon sits on the stone front face just below the line, where
	# the mirror body cannot cover it at 1x.
	draw_rect(Rect2(-1.0, y, 2.0, 7.0), Color(color, 0.55))
	_draw_phase_icon(Vector2(0.0, y + 10.0), color, 0.78 + 0.22 * pulse)
	# Edge caps keep the whole width readable at 1x.
	draw_rect(Rect2(left, y - 7.0, 2.0, 9.0), Color(color, 0.85))
	draw_rect(Rect2(left + width - 2.0, y - 7.0, 2.0, 9.0), Color(color, 0.85))


func _draw_wave_release() -> void:
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var color: Color = GOLD if _wave_result_positive else CYAN
	var y: float = floor_y - global_position.y - 1.0
	var half: float = 40.0 + 310.0 * progress
	var left: float = maxf(arena_left - global_position.x, -half)
	var right: float = minf(arena_right - global_position.x, half)
	if right <= left:
		return
	var fade: float = 1.0 - progress * 0.35
	draw_rect(Rect2(left, y, right - left, 2.0), Color(color, 0.92 * fade))
	draw_rect(Rect2(left, y - 5.0, right - left, 1.0), Color(color, 0.20 * fade))
	draw_rect(Rect2(left, y + 2.0, right - left, 1.0), Color(color, 0.30 * fade))
	for index: int in range(20):
		var x: float = left + (right - left) * (float(index) + 0.5) / 20.0
		var rise: float = 3.0 + 5.0 * absf(sin(progress * PI + float(index) * 0.7))
		draw_rect(Rect2(x, y - rise, 1.0, rise), Color(color, 0.72 * fade))
	draw_rect(Rect2(-1.0, y + 1.0, 2.0, 7.0), Color(color, 0.65))
	_draw_phase_icon(Vector2(0.0, y + 10.0), color, 0.95 * (1.0 - progress * 0.45))


func _draw_sweep_warning() -> void:
	_sweep_warning_draws += 1
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var y: float = floor_y - global_position.y - 18.0
	var left: float = arena_left - global_position.x
	var width: float = arena_right - arena_left
	var flash: float = 0.45 + 0.55 * absf(sin(_state_time * 18.0))
	draw_rect(Rect2(left, y, width, 1.0), Color(RED, flash))
	draw_rect(Rect2(left, y - 4.0, width, 1.0), Color(RED, 0.16 + 0.22 * progress))
	# Dashed red teeth: a laser warning, not the wide coloured floor ring.
	for index: int in range(20):
		var x: float = left + float(index) * width / 19.0
		draw_rect(Rect2(x, y - 5.0 - 2.0 * progress, 1.0, 3.0), Color(RED, 0.55))
		draw_rect(Rect2(x - 1.0, y + 3.0, 3.0, 1.0), Color(RED, 0.45))
	_draw_ground_dust(0.30 + 0.25 * progress, DUST)


func _draw_sweep_release() -> void:
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var left: float = arena_left - global_position.x
	var width: float = arena_right - arena_left
	var y: float = floor_y - global_position.y - 18.0
	var alpha: float = 0.95 * (1.0 - progress * 0.45)
	# Thin white beam, red lower edge: deliberately unlike the coloured wave.
	draw_rect(Rect2(left, y, width, 2.0), Color(WHITE, alpha))
	draw_rect(Rect2(left, y - 2.0, width, 1.0), Color(WHITE, 0.38 * alpha))
	draw_rect(Rect2(left, y + 2.0, width, 1.0), Color(RED, 0.60 * alpha))
	for index: int in range(24):
		var x: float = left + float(index) * width / 23.0
		draw_rect(Rect2(x, y - 5.0 - 3.0 * progress, 1.0, 4.0), Color(WHITE, 0.35 * alpha))
	_draw_ground_dust(0.55 * alpha, DUST)


## Landing gap between the two form-3 sweeps: the first beam's afterglow dies
## out and a short red "next pass" sight marks the low line.  It is deliberately
## much quieter than the real telegraph that follows for 0.65 s.
func _draw_sweep_gap() -> void:
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var left: float = arena_left - global_position.x
	var width: float = arena_right - arena_left
	var y: float = floor_y - global_position.y - 18.0
	var fade: float = 1.0 - progress
	# Thin afterglow from the beam that just passed.
	draw_rect(Rect2(left, y, width, 1.0), Color(WHITE, 0.28 * fade))
	draw_rect(Rect2(left, y + 2.0, width, 1.0), Color(RED, 0.16 * fade))
	_draw_ground_dust(0.22 * fade, DUST)
	# Three small brackets mark the low line for the coming second pass; the
	# full-width red warning is drawn only by _draw_sweep_warning().
	for offset: float in [-42.0, 0.0, 42.0]:
		var blink: float = 0.55 + 0.45 * absf(sin(_sway_time * 18.0 + offset))
		draw_rect(Rect2(offset - 4.0, y - 1.0, 8.0, 1.0), Color(RED, 0.62 * blink))
		draw_rect(Rect2(offset - 4.0, y - 4.0, 1.0, 3.0), Color(RED, 0.62 * blink))
		draw_rect(Rect2(offset + 3.0, y - 4.0, 1.0, 3.0), Color(RED, 0.62 * blink))


## Form-2 double warning: a red low-line laser warning (same dodge read as the
## real sweep) plus a phase-coloured bracket around the ghost.  The ghost body
## itself is drawn by the child sprite; this only adds the read.
func _draw_clone_warning() -> void:
	_clone_warn_draws += 1
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var y: float = floor_y - global_position.y - 18.0
	var left: float = arena_left - global_position.x
	var width: float = arena_right - arena_left
	var flash: float = 0.45 + 0.55 * absf(sin(_state_time * 18.0))
	draw_rect(Rect2(left, y, width, 1.0), Color(RED, flash))
	draw_rect(Rect2(left, y - 4.0, width, 1.0), Color(RED, 0.16 + 0.22 * progress))
	for index: int in range(20):
		var x: float = left + float(index) * width / 19.0
		draw_rect(Rect2(x, y - 5.0 - 2.0 * progress, 1.0, 3.0), Color(RED, 0.55))
	# The ghost's phase colour sits on the same low line, so the player reads
	# "this beam is the double's, and its phase is X" in one glance.
	var tint: Color = GOLD if _clone_positive else CYAN
	var center: Vector2 = _clone_local
	draw_rect(
		Rect2(center + Vector2(-30.0, -54.0), Vector2(60.0, 108.0)),
		Color(tint, 0.10 + 0.10 * progress)
	)
	draw_rect(
		Rect2(center + Vector2(-31.0, -55.0), Vector2(62.0, 110.0)),
		Color(tint, 0.62), false, 1.0
	)
	for offset: Vector2 in [Vector2(-24.0, -46.0), Vector2(18.0, -46.0)]:
		draw_rect(Rect2(center + offset, Vector2(6.0, 2.0)), Color(tint, 0.80))
	for index: int in range(12):
		var x: float = center.x - 26.0 + float(index) * 4.6
		draw_rect(Rect2(x, y - 2.0, 2.0, 1.0), Color(tint, 0.45 + 0.35 * flash))
	_draw_phase_icon(Vector2(center.x, y + 10.0), tint, 0.82)


func _draw_clone_release() -> void:
	_clone_release_draws += 1
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var left: float = arena_left - global_position.x
	var width: float = arena_right - arena_left
	var y: float = floor_y - global_position.y - 18.0
	var alpha: float = 0.95 * (1.0 - progress * 0.45)
	var tint: Color = GOLD_PALE if _clone_positive else CYAN_PALE
	draw_rect(Rect2(left, y, width, 2.0), Color(WHITE, alpha))
	draw_rect(Rect2(left, y - 2.0, width, 1.0), Color(tint, 0.48 * alpha))
	draw_rect(Rect2(left, y + 2.0, width, 1.0), Color(RED, 0.55 * alpha))
	var center: Vector2 = _clone_local
	draw_rect(
		Rect2(center + Vector2(-30.0, -54.0), Vector2(60.0, 108.0)),
		Color(tint, 0.26 * alpha)
	)
	_draw_phase_icon(Vector2(center.x, y + 10.0), tint, 0.92 * alpha)


## Form-3 charge: the core opens a white/cyan eye and a dashed sight line runs
## to the floor under the player.  The 0.6 s charge is the only warning before
## the orb exists.
func _draw_homing_charge() -> void:
	_homing_charge_draws += 1
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var pulse: float = 0.55 + 0.45 * absf(sin(_state_time * 20.0))
	_resolve_player()
	var target: Vector2 = Vector2(0.0, floor_y - global_position.y)
	if _player != null and is_instance_valid(_player):
		target.x = _player.global_position.x - global_position.x
		target.x = clampf(
			_player.global_position.x, arena_left + HOMING_RADIUS,
			arena_right - HOMING_RADIUS
		) - global_position.x
	# Dashed sight line from the core eye to the floor target.
	var start: Vector2 = Vector2(0.0, 0.0)
	var delta: Vector2 = target - start
	for index: int in range(10):
		var t0: float = float(index) / 10.0
		var t1: float = t0 + 0.55 / 10.0
		if index % 2 == 0:
			continue
		draw_line(start + delta * t0, start + delta * t1,
			Color(1.0, 0.62, 0.90, 0.24 + 0.24 * pulse), 1.0)
	for ring_index: int in range(3):
		var radius: float = 8.0 + 12.0 * float(ring_index) + 6.0 * progress
		_draw_ring_segments(Vector2.ZERO, radius,
			Color(MAGENTA if ring_index % 2 == 0 else WHITE, 0.68 - 0.14 * float(ring_index)))
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), Color(WHITE, 0.98))
	draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), Color(1.0, 0.62, 0.90, 0.60 + 0.24 * pulse), false, 1.0)
	# The floor point gets a small crosshair, not a full damage zone.
	var ground: Vector2 = Vector2(target.x, target.y)
	draw_rect(Rect2(ground.x - 7.0, ground.y - 1.0, 14.0, 1.0), Color(MAGENTA, 0.68))
	draw_rect(Rect2(ground.x - 1.0, ground.y - 7.0, 1.0, 14.0), Color(MAGENTA, 0.46))


func _draw_summon_cast() -> void:
	_summon_draws += 1
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	for side: float in [-170.0, 170.0]:
		var center: Vector2 = Vector2(side, 250.0 - global_position.y)
		# Hanging chain links descend into the portal.
		var top: float = -global_position.y
		var y: float = top + 20.0
		var link: int = 0
		while y < center.y - 12.0:
			var x: float = side + sin(y * 0.05 + _sway_time) * 1.5
			if link % 2 == 0:
				draw_rect(Rect2(x - 1.0, y, 3.0, 2.0), Color(PURPLE_DARK, 0.92))
				draw_rect(Rect2(x, y + 1.0, 1.0, 1.0), Color(PURPLE_PALE, 0.65))
			else:
				draw_rect(Rect2(x, y, 1.0, 3.0), Color(PURPLE_DARK, 0.92))
			y += 4.0
			link += 1
		# Violet portal: an oval throat, three rings and rotating chain studs.
		draw_colored_polygon(
			_ellipse_points(center, 11.0, 14.0), Color(PURPLE_DARK, 0.88)
		)
		draw_colored_polygon(
			_ellipse_points(center, 6.0, 8.0), Color(0.05, 0.01, 0.09, 0.90)
		)
		for ring_index: int in range(3):
			var radius: float = 10.0 + 5.0 * float(ring_index) + 4.0 * progress
			_draw_ring_segments(center, radius, Color(PURPLE, 0.70 - 0.16 * float(ring_index)))
		for index: int in range(8):
			var angle: float = progress * TAU + float(index) * TAU / 8.0
			var stud: Vector2 = center + Vector2(cos(angle), sin(angle)) * (16.0 + 2.0 * progress)
			draw_rect(Rect2(stud, Vector2(2.0, 2.0)), Color(PURPLE_PALE, 0.85))
		draw_rect(Rect2(center - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(PURPLE_PALE, 0.82))


func _draw_anchor_portals() -> void:
	var alpha: float = clampf(_anchor_portal_time / 0.85, 0.0, 1.0)
	for side: float in [-104.0, 104.0]:
		var center: Vector2 = Vector2(side, 272.0 - global_position.y)
		draw_colored_polygon(
			_ellipse_points(center, 9.0, 12.0), Color(PURPLE_DARK, 0.82 * alpha)
		)
		draw_colored_polygon(
			_ellipse_points(center, 4.0, 6.0), Color(0.05, 0.01, 0.09, 0.88 * alpha)
		)
		_draw_ring_segments(center, 12.0 + 3.0 * (1.0 - alpha), Color(PURPLE, 0.82 * alpha))
		draw_rect(Rect2(center - Vector2(1.0, 1.0), Vector2(2.0, 2.0)),
			Color(PURPLE_PALE, 0.85 * alpha))


func _ellipse_points(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(16):
		var angle: float = float(index) * TAU / 16.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func _draw_ring_segments(center: Vector2, radius: float, color: Color) -> void:
	for index: int in range(24):
		var angle: float = float(index) * TAU / 24.0
		draw_rect(
			Rect2(center + Vector2(round(cos(angle) * radius), round(sin(angle) * radius)),
				Vector2(1.0, 1.0)),
			color
		)


func _draw_face_bursts() -> void:
	for burst: Dictionary in _bursts:
		var t: float = float(burst.get("t", 0.0))
		var life: float = float(burst.get("life", 0.50))
		if t >= life:
			continue
		var center: Vector2 = burst.get("center", Vector2.ZERO)
		var color: Color = burst.get("color", GOLD)
		var kind: String = String(burst.get("kind", "face"))
		var fade: float = 1.0 - t / life
		if t < 0.10:
			draw_rect(
				Rect2(center - Vector2(18.0, 18.0), Vector2(36.0, 36.0)),
				Color(WHITE, 0.70 * (1.0 - t / 0.10))
			)
		var count: int = 8 if kind == "face" else 12
		for index: int in range(count):
			var angle: float = float(index) * TAU / float(count) + 0.35
			var distance: float = 8.0 + (34.0 if kind == "face" else 48.0) * t
			var size: float = 2.0 - t * 2.0
			draw_rect(
				Rect2(center + Vector2(cos(angle), sin(angle)) * distance,
					Vector2(maxf(size, 1.0), maxf(size, 1.0))),
				Color(color.lerp(WHITE, 0.35), 0.85 * fade)
			)


func _draw_anchor_links() -> void:
	if _phase_index < 1 or _core_exposed or _defeated:
		return
	for positive: bool in [true, false]:
		if not (_gold_intact if positive else _cyan_intact):
			continue
		var center: Vector2 = _face_local_gold if positive else _face_local_cyan
		var color: Color = GOLD if positive else CYAN
		if has_face_anchor(positive):
			# A violet chain ring around the live-anchored plate.
			_draw_ring_segments(center, 30.0, Color(PURPLE, 0.55 + 0.20 * sin(_sway_time * 4.0)))
			for index: int in range(4):
				var angle: float = float(index) * TAU / 4.0 + _sway_time * 1.2
				var stud: Vector2 = center + Vector2(cos(angle), sin(angle)) * 30.0
				draw_rect(Rect2(stud - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), PURPLE_PALE)
		else:
			var window: float = get_anchor_window_left(positive)
			if window > 0.0:
				var progress: float = clampf(window / FACE_ANCHOR_WINDOW, 0.0, 1.0)
				# Amber countdown arc shows the 6 s shatter window.
				var lit: int = int(round(progress * 20.0))
				for index: int in range(20):
					var angle: float = -PI * 0.5 + float(index) * TAU / 20.0
					var dot: Vector2 = center + Vector2(round(cos(angle) * 30.0), round(sin(angle) * 30.0))
					var dot_color: Color = Color(GOLD_PALE, 0.88) if index < lit else Color(IRON_DARK, 0.70)
					draw_rect(Rect2(dot, Vector2(2.0, 2.0)), dot_color)
				draw_line(center + Vector2(-8.0, -34.0), center + Vector2(8.0, -34.0),
					Color(RED, 0.55 + 0.35 * sin(_sway_time * 10.0)), 1.0)
			else:
				# Resealed: a broken violet link is still visible, but no window.
				draw_rect(Rect2(center + Vector2(-5.0, -33.0), Vector2(10.0, 2.0)), Color(PURPLE_DARK, 0.55))


## The long form-3 centre split and its branches live in RiftBossCracks, a
## child at z=-2 that is added after the body and before both plates.  This
## keeps the plates (z=-1) and every parent effect (z=5) above the cracks.
func _update_crack_layer() -> void:
	if _cracks == null:
		return
	var alpha: float = 0.0
	if _phase_index >= 2:
		alpha = 0.82
	elif _state == State.PHASE_CLEAR:
		var progress: float = clampf(
			_state_time / maxf(_state_duration, 0.01), 0.0, 1.0
		)
		alpha = 0.70 * sin(progress * PI)
	_cracks.call("set_crack_state", _phase_index, alpha)


func _draw_core_effects() -> void:
	var core: Vector2 = Vector2(0.0, 0.0)
	if _expose_flash > 0.0:
		draw_rect(Rect2(core - Vector2(22.0, 18.0), Vector2(44.0, 36.0)),
			Color(WHITE, 0.65 * _expose_flash))
		for index: int in range(8):
			var angle: float = float(index) * TAU / 8.0
			var length: float = 16.0 + 42.0 * (1.0 - _expose_flash)
			draw_line(core, core + Vector2(cos(angle), sin(angle)) * length,
				Color(GOLD if index % 2 == 0 else CYAN, 0.65 * _expose_flash), 1.0)
	if _core_exposed and not _defeated:
		var pulse: float = 0.5 + 0.5 * sin(_sway_time * 4.0)
		draw_rect(Rect2(core - Vector2(20.0, 14.0), Vector2(40.0, 28.0)),
			Color(PURPLE if int(_sway_time * 6.0) % 2 == 0 else MAGENTA, 0.06 + 0.06 * pulse))
		# Form-specific exposed-core window, visible as a shrinking ring.
		var window_max: float = maxf(_state_duration, 0.01)
		var window_left: float = clampf(window_max - _state_time, 0.0, window_max)
		var ratio: float = window_left / window_max
		for index: int in range(20):
			var angle: float = -PI * 0.5 + float(index) * TAU / 20.0
			var dot: Vector2 = core + Vector2(round(cos(angle) * 23.0), round(sin(angle) * 16.0))
			var dot_color: Color = Color(MAGENTA, 0.85) if float(index) / 20.0 < ratio else Color(IRON_DARK, 0.60)
			draw_rect(Rect2(dot, Vector2(1.0, 1.0)), dot_color)
	if _core_hit_flash > 0.0:
		draw_rect(Rect2(core - Vector2(17.0, 13.0), Vector2(34.0, 26.0)),
			Color(WHITE, 0.80 * _core_hit_flash))
		draw_rect(Rect2(core - Vector2(8.0, 6.0), Vector2(16.0, 12.0)),
			Color(MAGENTA, 0.65 * _core_hit_flash))
		for index: int in range(8):
			var angle: float = float(index) * TAU / 8.0 + _sway_time
			draw_line(core, core + Vector2(cos(angle), sin(angle)) * (18.0 + 24.0 * _core_hit_flash),
				Color(MAGENTA if index % 2 == 0 else WHITE, 0.60 * _core_hit_flash), 1.0)


func _draw_phase_flash() -> void:
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var flash: float = maxf(1.0 - progress * 1.75, 0.0)
	# Core white flash, then a violet form ring and (on the way to form 3) cracks.
	draw_rect(Rect2(-24.0, -22.0, 48.0, 44.0), Color(WHITE, 0.82 * flash))
	for index: int in range(14):
		var angle: float = float(index) * TAU / 14.0 + progress
		var outer: Vector2 = Vector2(cos(angle), sin(angle)) * (44.0 + 52.0 * progress)
		draw_line(Vector2(cos(angle), sin(angle)) * 20.0, outer,
			Color(PURPLE if index % 2 == 0 else PURPLE_PALE, 0.72 * (1.0 - progress)), 2.0)
	draw_rect(Rect2(-64.0, -56.0, 128.0, 112.0), Color(WHITE, 0.20 * flash))
	# Gold/cyan shard ring is visible outside the mirror silhouette.
	for index: int in range(20):
		var angle: float = float(index) * TAU / 20.0 + 0.2
		var distance: float = 42.0 + 66.0 * progress
		var shard: Vector2 = Vector2(cos(angle), sin(angle)) * distance
		draw_rect(Rect2(shard - Vector2(1.0, 1.0), Vector2(2.0, 2.0)),
			Color(GOLD if index % 2 == 0 else CYAN, 0.78 * (1.0 - progress)))


func _draw_defeat() -> void:
	var t: float = clampf(_defeat_time / DEFEAT_COLLAPSE_TIME, 0.0, 1.0)
	# The outer frame is already broken: a gapped iron ring remains behind the
	# imploding core.  It reads as the mirror shell, not an empty arena.
	if t > 0.20:
		for index: int in range(28):
			if index % 7 >= 2:
				continue
			var angle: float = float(index) * TAU / 28.0 + t * 0.8
			var radius: float = 58.0 - 12.0 * t
			var point: Vector2 = Vector2(cos(angle), sin(angle) * 0.88) * radius
			draw_rect(Rect2(point, Vector2(2.0, 2.0)), Color(IRON, 0.70 * (1.0 - t * 0.5)))
	# Large gold/cyan plate shards plus violet frame fragments fall away.
	for index: int in range(16):
		var angle: float = float(index) * TAU / 16.0 + 0.2
		var distance: float = 10.0 + 72.0 * t
		var size: float = 3.0 if index % 3 == 0 else 2.0
		var shard: Vector2 = Vector2(cos(angle), sin(angle)) * distance
		shard.y += 44.0 * t * t
		draw_rect(
			Rect2(shard - Vector2(1.0, 1.0), Vector2(size, size)),
			Color((GOLD if index % 2 == 0 else CYAN), 0.82 * (1.0 - t))
		)
	for index: int in range(8):
		var angle: float = float(index) * TAU / 8.0 + 0.5
		var shard: Vector2 = Vector2(cos(angle), sin(angle)) * (16.0 + 54.0 * t)
		shard.y += 30.0 * t
		draw_rect(Rect2(shard, Vector2(2.0, 2.0)), Color(PURPLE, 0.68 * (1.0 - t)))
	# Core implosion: a dark throat with a shrinking white eye and closing rings.
	if t > 0.18:
		var core_scale: float = clampf(1.0 - t * 0.55, 0.25, 1.0)
		draw_colored_polygon(
			_ellipse_points(Vector2.ZERO, 22.0 * core_scale, 16.0 * core_scale),
			Color(0.04, 0.01, 0.06, 0.92)
		)
		draw_colored_polygon(
			_ellipse_points(Vector2.ZERO, 10.0 * core_scale, 13.0 * core_scale),
			Color(WHITE, 0.92 * (1.0 - t * 0.45))
		)
	for ring_index: int in range(3):
		var radius: float = (58.0 - 48.0 * t) + float(ring_index) * 7.0
		var alpha: float = 0.90 * (1.0 - t)
		_draw_ring_segments(Vector2.ZERO, maxf(radius, 1.0),
			Color(PURPLE if ring_index % 2 == 0 else MAGENTA, alpha))
	if t < 0.22:
		draw_rect(Rect2(-64.0, -56.0, 128.0, 112.0),
			Color(WHITE, 0.78 * (1.0 - t / 0.22)))
	# Final white pop near the end of the 1.35 s collapse.
	if t > 0.72:
		var pop: float = sin((t - 0.72) / 0.28 * PI)
		# Layered pixel glow: wide soft wash, then a brighter core band.  The
		# steps avoid the hard rectangle seam of a single full-alpha square.
		draw_rect(Rect2(-420.0, -300.0, 840.0, 600.0), Color(WHITE, 0.28 * pop))
		draw_rect(Rect2(-240.0, -180.0, 480.0, 360.0), Color(WHITE, 0.40 * pop))
		draw_rect(Rect2(-110.0, -80.0, 220.0, 160.0), Color(WHITE, 0.62 * pop))
		for index: int in range(18):
			var angle: float = float(index) * TAU / 18.0 + 0.1
			var distance: float = 24.0 + 110.0 * pop
			draw_rect(
				Rect2(Vector2(cos(angle), sin(angle)) * distance - Vector2(1.0, 1.0),
					Vector2(2.0, 2.0)),
				Color(PURPLE_PALE if index % 2 == 0 else GOLD_PALE, 0.86 * pop)
			)


# --- read API (HUD / tests / capture) --------------------------------------

func is_active() -> bool:
	return _active


func is_suspended() -> bool:
	return _suspended


func is_defeated() -> bool:
	return _defeated


func is_collapsing() -> bool:
	return _defeated and not _collapse_finished


func is_collapse_finished() -> bool:
	return _collapse_finished


func get_defeat_collapse_time() -> float:
	return DEFEAT_COLLAPSE_TIME


func get_defeat_time() -> float:
	return _defeat_time


func get_form_transition_time() -> float:
	return PHASE_CLEAR_TIME


func get_form_transition_remaining() -> float:
	if _state != State.PHASE_CLEAR:
		return 0.0
	return maxf(_state_duration - _state_time, 0.0)


func get_last_form_transition_ms() -> int:
	return _last_transition_ms


func get_phase_index() -> int:
	return _phase_index


func get_phase_number() -> int:
	return _phase_index + 1


func get_phase_count() -> int:
	return MAX_PHASES


func get_core_hp() -> int:
	return _core_hp


func get_max_core_hits() -> int:
	return CORE_HITS_PER_PHASE


func is_core_exposed() -> bool:
	return _core_exposed


func get_core_window_left() -> float:
	if not _core_exposed or _state != State.CORE_OPEN:
		return 0.0
	return maxf(_state_duration - _state_time, 0.0)


func get_core_window_max() -> float:
	return _core_window_for_form()


func is_face_intact(positive: bool) -> bool:
	return _gold_intact if positive else _cyan_intact


func get_intact_face_count() -> int:
	return (1 if _gold_intact else 0) + (1 if _cyan_intact else 0)


func get_face_center_local(positive: bool) -> Vector2:
	return _face_local_gold if positive else _face_local_cyan


func get_face_center_global(positive: bool) -> Vector2:
	return global_position + get_face_center_local(positive)


func get_face_rect(positive: bool) -> Rect2:
	var center: Vector2 = global_position + get_face_center_local(positive)
	return Rect2(
		center - FACE_HIT_SIZE * 0.5,
		FACE_HIT_SIZE
	)


func get_core_rect() -> Rect2:
	return Rect2(global_position + CORE_HIT_RECT.position, CORE_HIT_RECT.size)


func get_boss_rect() -> Rect2:
	return Rect2(global_position + BOSS_RECT.position, BOSS_RECT.size)


func get_attack_state_name() -> String:
	return State.keys()[_state]


func is_phase_wave_telegraph_visible() -> bool:
	return _state == State.WAVE_WARN


func is_phase_wave_release_visible() -> bool:
	return _state == State.WAVE_RELEASE


func is_sweep_telegraph_visible() -> bool:
	return _state == State.SWEEP_WARN


func is_sweep_release_visible() -> bool:
	return _state == State.SWEEP_RELEASE


func is_core_open_state() -> bool:
	return _state == State.CORE_OPEN


func get_phase_wave_count() -> int:
	return _phase_wave_count


func get_sweep_count() -> int:
	return _sweep_count


func get_summon_count() -> int:
	return _summon_count


func get_last_result() -> Dictionary:
	return _last_result


func get_face_burst_count() -> int:
	return _bursts.size()


func get_wave_warning_draw_count() -> int:
	return _wave_warning_draws


func get_wave_telegraph_draw_count() -> int:
	return _wave_warning_draws


func get_sweep_warning_draw_count() -> int:
	return _sweep_warning_draws


func get_sweep_telegraph_draw_count() -> int:
	return _sweep_warning_draws


func get_summon_draw_count() -> int:
	return _summon_draws


func get_wave_result_positive() -> bool:
	return _wave_result_positive


func get_wave_warning_time() -> float:
	return WAVE_WARN_TIME


func get_sweep_warn_time() -> float:
	match _phase_index:
		0:
			return SWEEP_WARN_SLOW
		1:
			return SWEEP_WARN_FAST
		_:
			return SWEEP_WARN_FORM_3


func get_face_orbit_speed() -> float:
	if _phase_index == 2:
		return FACE_ORBIT_SPEED_FORM_3
	if _phase_index == 1:
		return FACE_ORBIT_SPEED_FORM_2
	return 0.0


func get_extra_summon_period() -> float:
	return FORM_3_SUMMON_PERIOD if _phase_index == 2 else 0.0


func get_next_attack_kind() -> String:
	if _phase_index == 2:
		match _attack_index % 3:
			0:
				return "wave"
			1:
				return "double_sweep"
			_:
				return "homing"
	if _phase_index == 1:
		match _attack_index % 3:
			0:
				return "wave"
			1:
				return "sweep"
			_:
				return "clone"
	return "wave" if _attack_index % 2 == 0 else "sweep"


func get_sweep_bursts_left() -> int:
	return _sweep_bursts_left


func get_double_sweep_warn_time() -> float:
	return DOUBLE_SWEEP_WARN


func get_double_sweep_gap_time() -> float:
	return DOUBLE_SWEEP_GAP


## Time from the first sweep release to the second sweep release: release
## animation + landing gap + second telegraph.  Tests assert this stays
## comfortably above 0.6 s.
func get_double_sweep_interval() -> float:
	var release: float = 0.24 if _phase_index > 0 else 0.30
	return release + DOUBLE_SWEEP_GAP + DOUBLE_SWEEP_WARN


func get_crack_layer() -> Node2D:
	return _cracks


func get_face_sprite(positive: bool) -> Sprite2D:
	return _face_gold if positive else _face_cyan


func get_boss_center() -> Vector2:
	return global_position


func get_floor_y() -> float:
	return floor_y


# --- mirror double / tracking light read API -------------------------------

func is_clone_active() -> bool:
	return _clone_active


func is_clone_telegraph_visible() -> bool:
	return _clone_active and _state == State.CLONE_WARN


func is_clone_release_visible() -> bool:
	return _clone_active and _state == State.CLONE_RELEASE


func get_clone_positive() -> bool:
	return _clone_positive


func get_clone_global_position() -> Vector2:
	return global_position + _clone_local


func get_clone_rect() -> Rect2:
	# The hit rect reaches down to the player's swing band even though the
	# translucent ghost sits a little above the real mirror.
	var center: Vector2 = get_clone_global_position() + Vector2(0.0, 18.0)
	return Rect2(
		center - CLONE_HIT_SIZE * Vector2(0.5, 0.5),
		CLONE_HIT_SIZE
	)


func get_clone_warn_time() -> float:
	return CLONE_WARN_TIME


func get_clone_warn_draw_count() -> int:
	return _clone_warn_draws


func get_clone_release_draw_count() -> int:
	return _clone_release_draws


func get_clone_cast_count() -> int:
	return _clone_cast_count


func get_clone_release_count() -> int:
	return _clone_release_count


func get_clone_shatter_count() -> int:
	return _clone_shatter_count


func is_homing_active() -> bool:
	return _homing_active


func is_homing_charging() -> bool:
	return _state == State.HOMING_CHARGE


func get_homing_position() -> Vector2:
	return _homing_position


func get_homing_speed() -> float:
	return HOMING_SPEED


func get_homing_warn_time() -> float:
	return HOMING_WARN_TIME


func get_homing_lifetime() -> float:
	return HOMING_LIFETIME


func get_active_homing_count() -> int:
	return 1 if _homing_active else 0


func get_max_homing_count() -> int:
	return HOMING_MAX_ACTIVE


func get_homing_cast_count() -> int:
	return _homing_cast_count


func get_homing_fire_count() -> int:
	return _homing_fire_count


func get_homing_ground_hit_count() -> int:
	return _homing_ground_hit_count


func get_homing_hit_player_count() -> int:
	return _homing_hit_player_count


func get_homing_charge_draw_count() -> int:
	return _homing_charge_draws


func get_homing_orb_draw_count() -> int:
	if _orb_drawer != null and _orb_drawer.has_method("get_draw_count"):
		return int(_orb_drawer.call("get_draw_count"))
	return 0
