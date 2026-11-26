class_name RiftMirrorBoss
extends Node2D

## "双面镜 · 裂隙守门者" — the single original rift-workshop boss.
##
## Reading order at 1x:
##   iron mirror frame -> two crescent face plates (gold sun left, cyan moon
##   right) -> central core.  Both plates are shields.  Only a J whose phase is
##   OPPOSITE the plate's phase can shatter that plate.  When both are broken the
##   central eye opens and J can damage the core three times.  The boss has three
##   phases; every phase the plates grow back and the core needs three more hits.
##
## Attack set (deliberately sparse and telegraphed):
##   - phase wave: two closing rings around the mirror, then a floor wave that
##     flips the grounded player's polarity; jumping clears it;
##   - mirror sweep: a bright floor line, then a low beam; jump over it;
##   - summon: two rift wisps dive/flip (chapter owns their real nodes).
##
## The boss never asks the player to press Q.  It only changes the player's
## phase through the real set_polarity_state() API, and the chapter supplies
## arena crystals for the player's own changes.
##
## Sprite evidence: tools/gen_assets.py writes the 128x112 base and the four
## 48x48 face plates from code.  Reference record:
## REFERENCE_MIRROR_BOSS_20261126.md.

signal fight_started
signal phase_wave_released(positive_after: bool, flipped: bool)
signal player_struck(away_direction: int)
signal summon_requested(count: int)
signal face_shattered(positive: bool)
signal core_hit(remaining: int)
signal core_exposed
signal phase_cleared(phase_index: int)
signal phase_started(phase_index: int)
signal defeated

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

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const GOLD_PALE: Color = Color("#ffe796")
const CYAN_PALE: Color = Color("#bcffff")
const IRON: Color = Color("#343c40")
const IRON_DARK: Color = Color(0.035, 0.047, 0.055, 0.98)
const WHITE: Color = Color(1.0, 0.985, 0.92)
const INK: Color = Color(0.008, 0.018, 0.024, 1.0)

const MAX_PHASES: int = 3
const CORE_HITS_PER_PHASE: int = 3
const FACE_OFFSET: Vector2 = Vector2(32.0, 18.0)
const FACE_SIZE: float = 48.0
## Hit rects are a little more generous than the drawn plate so a J that visibly
## reaches the lower rim is accepted at 1x.
const GOLD_HIT_RECT: Rect2 = Rect2(-62.0, -10.0, 48.0, 58.0)
const CYAN_HIT_RECT: Rect2 = Rect2(14.0, -10.0, 48.0, 58.0)
const CORE_HIT_RECT: Rect2 = Rect2(-18.0, -20.0, 36.0, 52.0)
const BOSS_RECT: Rect2 = Rect2(-64.0, -56.0, 128.0, 112.0)

const INTRO_TIME: float = 1.0
const WAVE_WARN_TIME: float = 0.95
const WAVE_RELEASE_TIME: float = 0.45
const SWEEP_WARN_TIME: float = 0.75
const SWEEP_RELEASE_TIME: float = 0.30
const SUMMON_CAST_TIME: float = 0.60
const PHASE_CLEAR_TIME: float = 1.35
const ATTACK_GAP: float = 0.85
const FLOOR_WAVE_HEIGHT: float = 12.0

enum State {
	DORMANT,
	INTRO,
	IDLE,
	WAVE_WARN,
	WAVE_RELEASE,
	SWEEP_WARN,
	SWEEP_RELEASE,
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
var _face_gold: Sprite2D = null
var _face_cyan: Sprite2D = null

var _state: State = State.DORMANT
var _state_time: float = 0.0
var _state_duration: float = 0.0
var _attack_gap: float = 0.0
var _attack_index: int = 0
var _active: bool = false
var _suspended: bool = true
var _defeated: bool = false

var _phase_index: int = 0
var _core_hp: int = CORE_HITS_PER_PHASE
var _gold_intact: bool = true
var _cyan_intact: bool = true
var _core_exposed: bool = false
var _summoned_this_phase: bool = false

var _phase_wave_count: int = 0
var _sweep_count: int = 0
var _summon_count: int = 0
## Test/capture hook: keep the boss hittable but stop starting new attacks.
var _attacks_enabled: bool = true

var _last_swing_id: int = -1
var _last_result: Dictionary = {}

var _sway_time: float = 0.0
var _wave_flip_done: bool = false
var _sweep_resolved: bool = false
var _expose_flash: float = 0.0
var _core_hit_flash: float = 0.0
var _phase_flash: float = 0.0
var _bursts: Array[Dictionary] = []
var _defeat_time: float = 0.0
var _wave_warning_draws: int = 0
var _sweep_warning_draws: int = 0
var _summon_draws: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 0
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
	add_child(_base)

	_face_gold = _make_face("GoldFace", FACE_GOLD, Vector2(-FACE_OFFSET.x, FACE_OFFSET.y))
	_face_cyan = _make_face("CyanFace", FACE_CYAN, Vector2(FACE_OFFSET.x, FACE_OFFSET.y))


func _make_face(node_name: String, texture: Texture2D, face_position: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = face_position
	sprite.z_index = 0
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
	_animate_sprites()
	_update_flashes(delta)
	if not _active or _defeated:
		queue_redraw()
		return
	_state_time += delta
	match _state:
		State.INTRO:
			if _state_time >= _state_duration:
				_enter_idle(ATTACK_GAP)
		State.IDLE:
			if _attacks_enabled:
				_attack_gap = maxf(_attack_gap - delta, 0.0)
				if _attack_gap <= 0.0:
					_start_next_attack()
		State.WAVE_WARN:
			if _state_time >= _state_duration:
				_release_wave()
		State.WAVE_RELEASE:
			if _state_time >= _state_duration:
				_enter_idle(ATTACK_GAP)
		State.SWEEP_WARN:
			if _state_time >= _state_duration:
				_release_sweep()
		State.SWEEP_RELEASE:
			if _state_time >= _state_duration:
				_enter_idle(ATTACK_GAP)
		State.SUMMON_CAST:
			if _state_time >= _state_duration:
				_finish_summon()
		State.PHASE_CLEAR:
			if _state_time >= _state_duration:
				_finish_phase_clear()
		State.DEFEATED:
			_defeat_time += delta
	queue_redraw()


func _animate_sprites() -> void:
	if _base != null:
		var base_offset: int = 4 if _core_exposed else 0
		_base.frame = base_offset + int(_sway_time * 2.0) % 4
	if _face_gold != null:
		var sway: float = sin(_sway_time * 1.5)
		_face_gold.position = Vector2(-FACE_OFFSET.x + sway * 1.5, FACE_OFFSET.y + cos(_sway_time * 1.2) * 1.2)
		_face_gold.rotation = sway * 0.018
	if _face_cyan != null:
		var sway2: float = sin(_sway_time * 1.5 + PI)
		_face_cyan.position = Vector2(FACE_OFFSET.x + sway2 * 1.5, FACE_OFFSET.y + cos(_sway_time * 1.2 + PI) * 1.2)
		_face_cyan.rotation = sway2 * 0.018


func _update_flashes(delta: float) -> void:
	_expose_flash = maxf(_expose_flash - delta * 4.0, 0.0)
	_core_hit_flash = maxf(_core_hit_flash - delta * 6.0, 0.0)
	_phase_flash = maxf(_phase_flash - delta * 2.5, 0.0)
	var alive: Array[Dictionary] = []
	for burst: Dictionary in _bursts:
		burst["t"] = float(burst.get("t", 0.0)) + delta
		if float(burst["t"]) < 0.40:
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
	queue_redraw()


func set_suspended(value: bool) -> void:
	# Freeze only.  Do not consume a queued wave/sweep resolution: a pause in
	# the middle of a telegraph must resume the same attack, not cancel it.
	_suspended = value


func reset_full() -> void:
	_active = false
	_suspended = true
	_defeated = false
	_phase_index = 0
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
	_wave_warning_draws = 0
	_sweep_warning_draws = 0
	_summon_draws = 0
	_attacks_enabled = true
	_update_face_visuals()
	queue_redraw()


func get_boss_sprite() -> Sprite2D:
	return _base


# --- hit resolution --------------------------------------------------------

## Called by the chapter at the player's real hit window, once per swing id.
## Returns a code the chapter can surface in the HUD:
## FACE_SHATTER / CORE_HIT / SAME_PHASE / SHIELDED / MISS_RANGE / MISS_BEHIND /
## INACTIVE / DUPLICATE.
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
		if positive:
			return _remember({"code": "SAME_PHASE", "positive": true})
		_shatter_face(true)
		return _remember({"code": "FACE_SHATTER", "positive": true})
	if _cyan_intact and hit_rect.intersects(get_face_rect(false)):
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
		_bursts.append({
			"center": Vector2(-FACE_OFFSET.x, FACE_OFFSET.y),
			"color": GOLD, "t": 0.0,
		})
	else:
		if not _cyan_intact:
			return
		_cyan_intact = false
		_bursts.append({
			"center": Vector2(FACE_OFFSET.x, FACE_OFFSET.y),
			"color": CYAN, "t": 0.0,
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
	_enter_state(State.CORE_OPEN, 0.0)
	_update_face_visuals()
	core_exposed.emit()
	queue_redraw()


func _start_phase_clear() -> void:
	_phase_flash = 1.0
	_enter_state(State.PHASE_CLEAR, PHASE_CLEAR_TIME)
	phase_cleared.emit(_phase_index)
	queue_redraw()


func _finish_phase_clear() -> void:
	if _phase_index >= MAX_PHASES - 1:
		_defeat()
		return
	_phase_index += 1
	_core_hp = CORE_HITS_PER_PHASE
	_gold_intact = true
	_cyan_intact = true
	_core_exposed = false
	_summoned_this_phase = false
	_attack_index = 0
	_phase_flash = 1.0
	_update_face_visuals()
	_enter_idle(1.15)
	phase_started.emit(_phase_index)
	queue_redraw()


func _defeat() -> void:
	if _defeated:
		return
	_defeated = true
	_active = false
	_core_exposed = true
	_state = State.DEFEATED
	_state_time = 0.0
	_defeat_time = 0.0
	_gold_intact = false
	_cyan_intact = false
	_update_face_visuals()
	defeated.emit()
	queue_redraw()


## Capture/test setup only: use the real defeat signal without a 15-hit fight.
func debug_force_defeat() -> void:
	if _defeated:
		return
	_core_exposed = true
	_gold_intact = false
	_cyan_intact = false
	_update_face_visuals()
	_defeat()


func debug_shatter_face(positive: bool) -> void:
	if positive:
		if _gold_intact:
			_shatter_face(true)
	else:
		if _cyan_intact:
			_shatter_face(false)


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


func _start_next_attack() -> void:
	if _core_exposed or _defeated:
		return
	var slot: int = _attack_index % 4
	_attack_index += 1
	match slot:
		0:
			_start_wave()
		1:
			_start_sweep()
		2:
			if not _summoned_this_phase:
				_start_summon()
			else:
				_start_sweep()
		_:
			_start_sweep()


func _start_wave() -> void:
	_wave_flip_done = false
	_enter_state(State.WAVE_WARN, WAVE_WARN_TIME)


func _release_wave() -> void:
	_enter_state(State.WAVE_RELEASE, WAVE_RELEASE_TIME)
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


func _start_sweep() -> void:
	_sweep_resolved = false
	_enter_state(State.SWEEP_WARN, SWEEP_WARN_TIME)


func _release_sweep() -> void:
	_enter_state(State.SWEEP_RELEASE, SWEEP_RELEASE_TIME)
	_sweep_count += 1
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
	_summoned_this_phase = true
	_enter_state(State.SUMMON_CAST, SUMMON_CAST_TIME)


func _finish_summon() -> void:
	_summon_count += 1
	summon_requested.emit(2)
	_enter_idle(1.15)


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
	_start_sweep()


func debug_force_summon() -> void:
	if not _active or _defeated or _core_exposed:
		return
	_start_summon()


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
	if _state == State.SUMMON_CAST:
		_draw_summon_cast()
	_draw_face_bursts()
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


func _draw_wave_warning() -> void:
	_wave_warning_draws += 1
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var pulse: float = 0.55 + 0.45 * sin(_state_time * 18.0)
	for ring: int in range(2):
		# Start just outside the 64 px mirror body so the warning is visible
		# from the first frame instead of hiding behind the boss.
		var radius: float = 68.0 + 54.0 * progress + float(ring) * 12.0
		_draw_split_ring(radius, 0.55 + 0.35 * pulse - float(ring) * 0.18)
	# A short floor tick line tells the player the wave is grounded.
	var y: float = floor_y - global_position.y - 4.0
	draw_rect(Rect2(arena_left - global_position.x, y, arena_right - arena_left, 1.0),
		Color(GOLD_PALE if int(_state_time * 12.0) % 2 == 0 else CYAN_PALE, 0.25))
	# Eight closing gate ticks around the mirror.
	for index: int in range(8):
		var angle: float = float(index) * TAU / 8.0
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * (52.0 - 10.0 * progress)
		var end: Vector2 = Vector2(cos(angle), sin(angle)) * (60.0 - 10.0 * progress)
		draw_line(start, end, Color(WHITE, 0.30 + 0.40 * progress), 1.0)


func _draw_split_ring(radius: float, alpha: float) -> void:
	var segments: int = 48
	var clamped: float = clampf(alpha, 0.0, 0.92)
	for index: int in range(segments):
		var a0: float = float(index) * TAU / float(segments)
		var a1: float = float(index + 1) * TAU / float(segments)
		var color: Color = GOLD if index < segments / 2 else CYAN
		draw_line(
			Vector2(cos(a0), sin(a0)) * radius,
			Vector2(cos(a1), sin(a1)) * radius,
			Color(color, clamped), 2.0
		)
	# Eight outward ticks make the ring read as a warning, not a thin outline.
	for index: int in range(8):
		var angle: float = float(index) * TAU / 8.0
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(
			direction * radius, direction * (radius + 8.0),
			Color(GOLD if index % 2 == 0 else CYAN, clamped), 2.0
		)


func _draw_wave_release() -> void:
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var y: float = floor_y - global_position.y - 4.0
	var half: float = 38.0 + 300.0 * progress
	var left: float = maxf(arena_left - global_position.x, -half)
	var right: float = minf(arena_right - global_position.x, half)
	draw_rect(Rect2(left, y, right - left, 2.0), Color(CYAN_PALE, 0.80 * (1.0 - progress * 0.5)))
	draw_rect(Rect2(left, y + 2.0, right - left, 1.0), Color(GOLD_PALE, 0.70 * (1.0 - progress * 0.4)))
	for index: int in range(9):
		var x: float = left + (right - left) * (float(index) + 0.5) / 9.0
		var rise: float = 3.0 + 7.0 * progress
		draw_rect(Rect2(x, y - rise, 1.0, rise), Color(GOLD if index % 2 == 0 else CYAN, 0.65))


func _draw_sweep_warning() -> void:
	_sweep_warning_draws += 1
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var y: float = floor_y - global_position.y - 14.0
	var left: float = arena_left - global_position.x
	var width: float = arena_right - arena_left
	var flash: float = 0.35 + 0.55 * absf(sin(_state_time * 16.0))
	draw_rect(Rect2(left, y, width, 1.0), Color(WHITE, flash))
	for index: int in range(13):
		var x: float = left + 10.0 + float(index) * 46.0
		draw_rect(Rect2(x, y + 3.0, 1.0, 3.0), Color(CYAN, 0.45 + 0.35 * progress))
		draw_rect(Rect2(x - 1.0, y + 6.0, 3.0, 1.0), Color(CYAN, 0.35 + 0.35 * progress))


func _draw_sweep_release() -> void:
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var left: float = arena_left - global_position.x
	var width: float = arena_right - arena_left
	var y: float = floor_y - global_position.y - 16.0
	var alpha: float = 0.85 * (1.0 - progress * 0.55)
	draw_rect(Rect2(left, y, width, 10.0), Color(GOLD, 0.30 * alpha))
	draw_rect(Rect2(left, y + 2.0, width, 5.0), Color(CYAN, 0.55 * alpha))
	draw_rect(Rect2(left, y + 4.0, width, 2.0), Color(WHITE, 0.90 * alpha))
	for index: int in range(15):
		var x: float = left + float(index) * width / 14.0
		draw_rect(Rect2(x, y - 5.0, 1.0, 5.0), Color(GOLD_PALE, 0.45 * alpha))


func _draw_summon_cast() -> void:
	_summon_draws += 1
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	for side: float in [-170.0, 170.0]:
		var center: Vector2 = Vector2(side, 250.0 - global_position.y)
		_draw_glyph(center, 13.0 + 5.0 * progress, GOLD if side < 0.0 else CYAN, 0.35 + 0.55 * progress)
		for index: int in range(4):
			var angle: float = progress * TAU + float(index) * TAU / 4.0
			draw_rect(
				Rect2(center + Vector2(cos(angle), sin(angle)) * (18.0 + 8.0 * progress),
					Vector2(1.0, 1.0)),
				Color(WHITE, 0.55 * (1.0 - progress))
			)


func _draw_glyph(center: Vector2, radius: float, color: Color, alpha: float) -> void:
	for index: int in range(20):
		var angle: float = float(index) * TAU / 20.0
		draw_rect(
			Rect2(center + Vector2(round(cos(angle) * radius), round(sin(angle) * radius)),
				Vector2(1.0, 1.0)),
			Color(color, alpha)
		)
	draw_rect(Rect2(center - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(color, alpha * 0.8))
	draw_rect(Rect2(center - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(WHITE, alpha))


func _draw_face_bursts() -> void:
	for burst: Dictionary in _bursts:
		var t: float = float(burst.get("t", 0.0))
		if t >= 0.40:
			continue
		var center: Vector2 = burst.get("center", Vector2.ZERO)
		var color: Color = burst.get("color", GOLD)
		var fade: float = 1.0 - t / 0.40
		if t < 0.10:
			draw_rect(Rect2(center - Vector2(18.0, 18.0), Vector2(36.0, 36.0)),
				Color(WHITE, 0.65 * (1.0 - t / 0.10)))
		for index: int in range(8):
			var angle: float = float(index) * TAU / 8.0 + 0.35
			var distance: float = 8.0 + 34.0 * t
			var size: float = 2.0 - t * 2.0
			draw_rect(
				Rect2(center + Vector2(cos(angle), sin(angle)) * distance,
					Vector2(maxf(size, 1.0), maxf(size, 1.0))),
				Color(color.lerp(WHITE, 0.35), 0.85 * fade)
			)


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
			Color(GOLD if int(_sway_time * 6.0) % 2 == 0 else CYAN, 0.05 + 0.05 * pulse))
	if _core_hit_flash > 0.0:
		draw_rect(Rect2(core - Vector2(17.0, 13.0), Vector2(34.0, 26.0)),
			Color(WHITE, 0.78 * _core_hit_flash))
		for index: int in range(6):
			var angle: float = float(index) * TAU / 6.0 + _sway_time
			draw_line(core, core + Vector2(cos(angle), sin(angle)) * (18.0 + 22.0 * _core_hit_flash),
				Color(WHITE, 0.55 * _core_hit_flash), 1.0)


func _draw_phase_flash() -> void:
	var progress: float = clampf(_state_time / maxf(_state_duration, 0.01), 0.0, 1.0)
	var alpha: float = 0.55 * (1.0 - progress)
	draw_rect(Rect2(-64.0, -56.0, 128.0, 112.0), Color(WHITE, alpha * 0.45))
	for index: int in range(10):
		var angle: float = float(index) * TAU / 10.0
		var outer: Vector2 = Vector2(cos(angle), sin(angle)) * (54.0 + 40.0 * progress)
		draw_line(Vector2(cos(angle), sin(angle)) * 22.0, outer,
			Color(GOLD if index % 2 == 0 else CYAN, alpha), 1.0)


func _draw_defeat() -> void:
	var t: float = minf(_defeat_time / 1.2, 1.0)
	if t < 0.35:
		draw_rect(Rect2(-64.0, -56.0, 128.0, 112.0),
			Color(WHITE, 0.55 * (1.0 - t / 0.35)))
	for index: int in range(12):
		var angle: float = float(index) * TAU / 12.0 + 0.2
		var distance: float = 12.0 + 70.0 * t
		draw_rect(
			Rect2(Vector2(cos(angle), sin(angle)) * distance - Vector2(1.0, 1.0),
				Vector2(2.0, 2.0)),
			Color((GOLD if index % 2 == 0 else CYAN), 0.70 * (1.0 - t))
		)


# --- read API (HUD / tests / capture) --------------------------------------

func is_active() -> bool:
	return _active


func is_suspended() -> bool:
	return _suspended


func is_defeated() -> bool:
	return _defeated


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


func is_face_intact(positive: bool) -> bool:
	return _gold_intact if positive else _cyan_intact


func get_intact_face_count() -> int:
	return (1 if _gold_intact else 0) + (1 if _cyan_intact else 0)


func get_face_rect(positive: bool) -> Rect2:
	var rect: Rect2 = GOLD_HIT_RECT if positive else CYAN_HIT_RECT
	return Rect2(global_position + rect.position, rect.size)


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


func get_boss_center() -> Vector2:
	return global_position


func get_floor_y() -> float:
	return floor_y
