class_name RiftPolarityWisp
extends Node2D

## Rift-workshop enemy "PolarityWisp".
##
## 16 x 16 art, 4-frame float loop, two states (gold / cyan).  Movement and
## behaviour are original:
##   - hovers on a sine path around its authored base position;
##   - switches phase every 2.2 s, so its colour is a real timer the player can
##     read before the next pulse;
##   - pulses every 3.0 s.  A matching player is pushed away, an opposite player
##     is pulled in.  The last 0.45 s before a pulse draws a charging ring;
##   - one J hit destroys it (no true-damage requirement, no phase requirement).
##     The hit is resolved by the chapter from the player's real attack hit
##     window with a forward rectangle.
##
## Presentation: a dark silhouette, a two-tone body, one large eye and a tail,
## so the 16 px enemy reads at 2x zoom.  Reference read on Celeste's Seeker was
## used only for "one big eye + strong orbiting silhouette"; no sprite, palette
## or animation is copied.  See REFERENCE.md.

signal defeated(wisp: RiftPolarityWisp)
signal phase_switched(positive: bool)
signal pulsed(mode: String, force: float)

const SPRITE: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/polarity_wisp_16x16_8f.png"
)
const HUM_STREAM: AudioStreamWAV = preload(
	"res://dlc/rift_workshop/assets/audio/sfx_wisp_hum.wav"
)
const POP_STREAM: AudioStreamWAV = preload(
	"res://dlc/rift_workshop/assets/audio/sfx_wisp_pop.wav"
)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")

@export var start_positive: bool = true
@export var hover_amplitude: float = 6.0
@export var hover_speed: float = 2.1
@export var phase_period: float = 2.2
@export var pulse_period: float = 3.0
@export var pulse_radius: float = 82.0
@export var push_force: float = 215.0
@export var pull_force: float = 170.0
@export var player_path: NodePath = NodePath()
@export var hum_enabled: bool = true

var _sprite: Sprite2D = null
var _hum: AudioStreamPlayer = null
var _sfx: AudioStreamPlayer = null
var _player: L3Player = null
var _base: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _positive: bool = true
var _alive: bool = true
var _phase_left: float = 0.0
var _pulse_left: float = 0.0
var _pulse_flash: float = 0.0
var _pop_time: float = 0.0
var _pulse_count: int = 0
var _last_pulse_mode: String = "none"
var _last_pulse_force: float = 0.0
var _last_swing_id: int = -1
var _phase_switch_count: int = 0


func _ready() -> void:
	_base = position
	_positive = start_positive
	_phase_left = phase_period
	_pulse_left = pulse_period
	z_index = 4
	_build_sprite()
	_build_audio()
	_resolve_player()
	_apply_frame(0.0)


func _exit_tree() -> void:
	if _hum != null:
		_hum.stop()


func _build_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.texture = SPRITE
	_sprite.hframes = 8
	_sprite.vframes = 1
	_sprite.centered = true
	_sprite.scale = Vector2(2.0, 2.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _build_audio() -> void:
	_hum = AudioStreamPlayer.new()
	_hum.name = "Hum"
	var hum_stream: AudioStreamWAV = HUM_STREAM.duplicate() as AudioStreamWAV
	if hum_stream != null:
		hum_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		hum_stream.loop_begin = 0
		# 1.000 s at 44.1 kHz, mono 16-bit: two bytes per frame.
		hum_stream.loop_end = maxi(hum_stream.data.size() / 2 - 1, 1)
	_hum.stream = hum_stream
	_hum.volume_db = -24.0
	_hum.pitch_scale = 0.94 + 0.03 * float(get_index() % 4)
	add_child(_hum)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "Sfx"
	_sfx.stream = POP_STREAM
	_sfx.volume_db = -10.0
	add_child(_sfx)


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


# --- frame flow ------------------------------------------------------------

func _process(delta: float) -> void:
	if not _alive:
		_pop_time += delta
		if _sprite != null:
			_sprite.modulate.a = maxf(1.0 - _pop_time / 0.22, 0.0)
		queue_redraw()
		return

	_time += delta
	position = _base + Vector2(
		sin(_time * 0.7) * 2.0,
		sin(_time * hover_speed) * hover_amplitude
	)
	_apply_frame(_time)

	_phase_left -= delta
	if _phase_left <= 0.0:
		_phase_left = phase_period
		_set_phase(not _positive)

	_pulse_left -= delta
	if _pulse_left <= 0.0:
		_pulse_left = pulse_period
		_do_pulse()
	_pulse_flash = maxf(_pulse_flash - delta / 0.42, 0.0)
	queue_redraw()


func _apply_frame(time: float) -> void:
	if _sprite == null:
		return
	var anim_frame: int = int(time * 9.0) % 4
	_sprite.frame = anim_frame + (0 if _positive else 4)


func _set_phase(value: bool) -> void:
	if _positive == value:
		return
	_positive = value
	_phase_switch_count += 1
	phase_switched.emit(_positive)


# --- pulse -----------------------------------------------------------------

func _do_pulse() -> void:
	_pulse_flash = 1.0
	_pulse_count += 1
	var mode: String = "none"
	var force: float = 0.0
	if _player != null and is_instance_valid(_player) and _alive:
		var player_center: Vector2 = _player.global_position + Vector2(0.0, -15.0)
		var distance: float = player_center.distance_to(global_position)
		if distance <= pulse_radius:
			var direction: Vector2 = (player_center - global_position).normalized()
			if direction == Vector2.ZERO:
				direction = Vector2.RIGHT
			var same_phase: bool = _player.is_positive() == _positive
			force = push_force if same_phase else pull_force
			mode = "push" if same_phase else "pull"
			# Horizontal-dominant impulse: the lift must never become a free
			# jump, and the downward part must never slam the player through
			# the floor.  0.35 keeps it readable instead of disorienting.
			var impulse: Vector2 = Vector2(direction.x, direction.y * 0.35) * force
			if not same_phase:
				impulse = -impulse
			_player.velocity += impulse
	pulsed.emit(mode, force)
	_last_pulse_mode = mode
	_last_pulse_force = force
	_play_sfx(0.72, -15.0)


func _play_sfx(pitch: float, volume_db: float) -> void:
	if _sfx == null:
		return
	_sfx.pitch_scale = pitch
	_sfx.volume_db = volume_db
	_sfx.play()


# --- hit / death -----------------------------------------------------------

## Called by the chapter with the player's real swing snapshot.  Any phase
## counts; one accepted swing is lethal.  Returns true on the killing hit.
func try_player_hit(
	player: Node2D, facing: int, _snapshot_positive: bool, swing_id: int
) -> bool:
	if not _alive or swing_id == _last_swing_id:
		return false
	_last_swing_id = swing_id
	if player == null or not is_instance_valid(player):
		return false
	var direction: float = 1.0 if facing >= 0 else -1.0
	var origin_x: float = player.global_position.x + (2.0 if direction > 0.0 else -38.0)
	var hit_rect: Rect2 = Rect2(
		origin_x,
		player.global_position.y - 32.0,
		36.0,
		32.0
	)
	if not hit_rect.intersects(get_hit_rect()):
		return false
	kill()
	return true


func get_hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(10.0, 10.0), Vector2(20.0, 20.0))


func kill() -> void:
	if not _alive:
		return
	_alive = false
	_pop_time = 0.0
	if _hum != null and _hum.playing:
		_hum.stop()
	_play_sfx(1.28, -7.0)
	if _sprite != null:
		_sprite.modulate.a = 1.0
	defeated.emit(self)
	queue_redraw()


## Restores the wisp after an R restart.  `_base` is the authored position.
func respawn() -> void:
	_alive = true
	_pop_time = 0.0
	_time = 0.0
	_positive = start_positive
	_phase_left = phase_period
	_pulse_left = pulse_period
	_pulse_flash = 0.0
	_last_swing_id = -1
	position = _base
	if _sprite != null:
		_sprite.modulate.a = 1.0
		_sprite.visible = true
	_apply_frame(0.0)
	_restart_hum()
	queue_redraw()


func _restart_hum() -> void:
	if not hum_enabled or _hum == null:
		return
	if _hum.stream != null:
		_hum.play()


func set_hum_enabled(value: bool) -> void:
	hum_enabled = value
	if _hum == null:
		return
	if value and _alive and not _hum.playing:
		_hum.play()
	elif not value:
		_hum.stop()


# --- read API --------------------------------------------------------------

func is_alive() -> bool:
	return _alive


func is_positive() -> bool:
	return _positive


func get_pulse_count() -> int:
	return _pulse_count


func get_last_pulse_mode() -> String:
	return _last_pulse_mode


func get_last_pulse_force() -> float:
	return _last_pulse_force


func get_phase_switch_count() -> int:
	return _phase_switch_count


func get_pulse_time_left() -> float:
	return _pulse_left


func get_phase_time_left() -> float:
	return _phase_left


func get_base_position() -> Vector2:
	return _base


func get_sprite() -> Sprite2D:
	return _sprite


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var color: Color = GOLD if _positive else CYAN
	if not _alive:
		# Six shards flying out for 0.34 s: a clear death read without a
		# separate sheet.
		var t: float = clampf(_pop_time / 0.34, 0.0, 1.0)
		if t >= 1.0:
			return
		for index: int in range(6):
			var angle: float = float(index) * TAU / 6.0 + 0.4
			var radius: float = 4.0 + 20.0 * t
			var size: float = 3.0 - 2.0 * t
			draw_rect(
				Rect2(Vector2(cos(angle), sin(angle)) * radius - Vector2(1, 1), Vector2(size, size)),
				Color(color, 0.9 * (1.0 - t))
			)
		return

	# Charging ring: the last 0.45 s before a pulse.
	var telegraph: float = clampf(1.0 - _pulse_left / 0.45, 0.0, 1.0)
	if _pulse_left > 0.0 and telegraph > 0.0:
		var ring_radius: float = 12.0 + 8.0 * telegraph
		_draw_ring(ring_radius, Color(color, 0.20 + 0.35 * telegraph))
	# Pulse burst: one expanding 1 px ring, 0.42 s.
	if _pulse_flash > 0.0:
		var grow: float = 1.0 - _pulse_flash
		_draw_ring(11.0 + 46.0 * grow, Color(color, 0.75 * _pulse_flash))
	# A faint 1 px halo keeps the 16 px body readable over the bright sky.
	_draw_ring(11.0, Color(color, 0.22 + 0.08 * sin(_time * 3.0)))


func _draw_ring(radius: float, color: Color) -> void:
	# Integer 1 px ring: 24 segments is plenty at this size and stays crisp.
	var segments: int = 24
	for index: int in range(segments):
		var angle: float = float(index) * TAU / float(segments)
		draw_rect(
			Rect2(round(cos(angle) * radius), round(sin(angle) * radius), 1.0, 1.0),
			color
		)
