class_name TrialPhaseCrystal
extends Node2D

## The trial's first "key": a small stone stand holding one floating phase
## crystal.  Touching the player's body flips them to the crystal's colour
## (gold = 辉相, cyan = 澜相), plays a 0.20 s pulse and a short chime.
##
## The crystal does not replace Q: it only writes the same public
## set_polarity_state() the player already owns.  The second gate deliberately
## has no crystal, so the player must use Q there.  No collision body is added:
## the touch test is a read-only body rectangle overlap, so the crystal can
## never block movement or damage the player.
##
## Presentation is original pixel art (stone steps + gold/cyan floating shard)
## built from integer rects and polygons.  It borrows only the approved reading
## order seen in the references: a bright floating core framed by a dark stand,
## and the whole shard's colour states the affinity (see
## REF_GATE_KEY_20261126.md).  No third-party sprite, palette or shape is copied.

signal phase_set(positive: bool)

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const STONE: Color = Color("#2b3537")
const STONE_HI: Color = Color("#485558")
const STONE_LO: Color = Color("#0d1517")
const STONE_EDGE: Color = Color("#080d0f")
const WHITE: Color = Color(1.0, 0.98, 0.88, 1.0)
const PULSE_TIME: float = 0.20
const TRIGGER_RECT: Rect2 = Rect2(-10.0, -28.0, 20.0, 28.0)
const RETOUCH_MARGIN: float = 3.0

@export var crystal_positive: bool = true:
	set(value):
		crystal_positive = value
		queue_redraw()
@export var player_path: NodePath = NodePath()
## Exposed for a capture/test that wants to park the crystal for a still.
@export var animate_bob: bool = true

var _player: Node2D = null
var _time: float = 0.0
var _pulse_left: float = 0.0
var _inside: bool = false
var _trigger_count: int = 0
var _sound_count: int = 0
var _audio: AudioStreamPlayer = null


func _ready() -> void:
	_resolve_player()
	_build_audio()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	if _pulse_left > 0.0:
		_pulse_left = maxf(_pulse_left - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	var touching: bool = _compute_touching()
	if touching and not _inside:
		_inside = true
		_trigger()
	elif not touching:
		_inside = false
	# The bob, pulse ring and orbit sparks are cheap but only need redrawing
	# while the crystal is on screen; the camera keeps it visible for most of
	# the opening route, so continuous redraw is acceptable and matches the
	# gate's own open cue.
	if _pulse_left > 0.0 or animate_bob:
		queue_redraw()


# --- touch / phase ---------------------------------------------------------

func _compute_touching() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if not _player.has_method("get_collision_size"):
		return false
	var size: Vector2 = _player.call("get_collision_size") as Vector2
	var player_rect: Rect2 = Rect2(
		_player.global_position + Vector2(-size.x * 0.5, -size.y), size
	)
	return player_rect.intersects(get_trigger_rect())


func _trigger() -> void:
	_trigger_count += 1
	_pulse_left = PULSE_TIME
	_play_chime()
	var already: bool = false
	if _player != null and _player.has_method("is_positive"):
		already = bool(_player.call("is_positive")) == crystal_positive
	if not already and _player != null and _player.has_method("set_polarity_state"):
		_player.call("set_polarity_state", crystal_positive)
	phase_set.emit(crystal_positive)
	queue_redraw()


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if not player_path.is_empty():
		var target: Node = get_node_or_null(player_path)
		if target is Node2D:
			_player = target as Node2D
			return
	var parent: Node = get_parent()
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child is Node2D and child.has_method("set_polarity_state") \
				and child.has_method("get_collision_size"):
			_player = child as Node2D
			return


# --- audio (procedural, original) -----------------------------------------

func _build_audio() -> void:
	if _audio != null:
		return
	_audio = AudioStreamPlayer.new()
	_audio.name = "CrystalChime"
	_audio.stream = TrialSfx.crystal_flip()
	_audio.volume_db = -7.0
	_audio.bus = &"Master"
	add_child(_audio)


func _play_chime() -> void:
	if _audio == null:
		return
	_audio.stop()
	_audio.play()
	_sound_count += 1


# --- public read/reset API -------------------------------------------------

func get_trigger_rect() -> Rect2:
	return Rect2(global_position + TRIGGER_RECT.position, TRIGGER_RECT.size)


func get_trigger_count() -> int:
	return _trigger_count


func is_pulsing() -> bool:
	return _pulse_left > 0.0


func get_pulse_left() -> float:
	return _pulse_left


func get_sound_play_count() -> int:
	return _sound_count


func get_crystal_positive() -> bool:
	return crystal_positive


## World-space centre of the floating shard.  The opening film anchors its gold
## halo here; the shard itself is still drawn by this node in `_draw()`.
func get_shard_center_global() -> Vector2:
	var bob: float = 0.0
	if animate_bob:
		bob = roundf(sin(_time * 2.4) * 1.0)
	return global_position + Vector2(0.0, -19.0 + bob)


func is_player_inside() -> bool:
	return _compute_touching()


func set_player_node(player: Node2D) -> void:
	_player = player
	_inside = _compute_touching()


func reset_state() -> void:
	_pulse_left = 0.0
	_inside = false
	_trigger_count = 0
	_sound_count = 0
	if _audio != null:
		_audio.stop()
	queue_redraw()


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var color: Color = GOLD if crystal_positive else CYAN
	var bob: float = 0.0
	if animate_bob:
		bob = roundf(sin(_time * 2.4) * 1.0)
	var shard_center: Vector2 = Vector2(0.0, -19.0 + bob)
	_draw_stand(color, bob)
	_draw_glow(shard_center, color)
	_draw_shard(shard_center, color)
	_draw_pulse(shard_center, color)


func _draw_stand(color: Color, bob: float) -> void:
	# Three dark stone steps, widening to the floor; a short metal stem holds
	# the shard.  Integer rects keep the 1x pixel silhouette crisp.
	draw_rect(Rect2(-12.0, -1.0, 24.0, 1.0), STONE_EDGE)
	draw_rect(Rect2(-11.0, -3.0, 22.0, 2.0), STONE)
	draw_rect(Rect2(-11.0, -3.0, 22.0, 1.0), STONE_HI)
	draw_rect(Rect2(-8.0, -6.0, 16.0, 3.0), STONE)
	draw_rect(Rect2(-8.0, -6.0, 16.0, 1.0), STONE_HI)
	draw_rect(Rect2(-5.0, -9.0, 10.0, 3.0), STONE)
	draw_rect(Rect2(-5.0, -9.0, 10.0, 1.0), STONE_HI)
	draw_rect(Rect2(-8.0, -6.0, 1.0, 3.0), STONE_LO)
	draw_rect(Rect2(-5.0, -9.0, 1.0, 3.0), STONE_LO)
	draw_rect(Rect2(7.0, -6.0, 1.0, 3.0), STONE_LO)
	draw_rect(Rect2(4.0, -9.0, 1.0, 3.0), STONE_LO)
	# Two faint chips keep the stand from reading as a clean UI widget.
	draw_rect(Rect2(-9.0, -4.0, 2.0, 1.0), Color(0.22, 0.27, 0.28, 1.0))
	draw_rect(Rect2(6.0, -2.0, 3.0, 1.0), STONE_LO)

	# Metal stem: 2 px dark shaft with a bright 1 px inner edge in the phase
	# colour, so the stand itself also hints at the shard's affiliation.
	draw_rect(Rect2(-2.0, -13.0 + roundf(bob * 0.25), 4.0, 4.0), STONE_EDGE)
	draw_rect(Rect2(-1.0, -13.0 + roundf(bob * 0.25), 2.0, 4.0), color.darkened(0.25))
	draw_rect(Rect2(-1.0, -12.0 + roundf(bob * 0.25), 1.0, 2.0), color)
	# A tiny affinity mark engraved on the front step: sun for 辉, moon for 澜.
	_draw_base_mark(Vector2(0.0, -4.0), color)


func _draw_base_mark(center: Vector2, color: Color) -> void:
	if crystal_positive:
		draw_rect(Rect2(center.x - 1.0, center.y - 2.0, 2.0, 2.0), color)
		for offset: Vector2 in [
			Vector2(0.0, -4.0), Vector2(0.0, 2.0),
			Vector2(-3.0, -1.0), Vector2(3.0, -1.0),
		]:
			draw_rect(Rect2(center + offset, Vector2.ONE), color)
	else:
		draw_rect(Rect2(center.x - 2.0, center.y - 2.0, 2.0, 4.0), color)
		draw_rect(Rect2(center.x, center.y - 2.0, 1.0, 1.0), color)
		draw_rect(Rect2(center.x, center.y + 1.0, 1.0, 1.0), color)
		draw_rect(Rect2(center.x + 2.0, center.y - 3.0, 1.0, 1.0), color)


func _draw_glow(center: Vector2, color: Color) -> void:
	# Layered diamonds instead of a soft blur: still pixel-shaped at 1x.
	for layer: int in range(3):
		var inflate: float = 6.0 + float(layer) * 5.0
		var alpha: float = 0.10 - float(layer) * 0.025
		draw_colored_polygon(
			PackedVector2Array([
				center + Vector2(0.0, -13.0 - inflate),
				center + Vector2(8.0 + inflate * 0.55, 0.0),
				center + Vector2(0.0, 13.0 + inflate),
				center + Vector2(-8.0 - inflate * 0.55, 0.0),
			]),
			Color(color, alpha)
		)
	# Three sparks orbit the shard; their colour changes with the shard.
	for index: int in range(3):
		var angle: float = _time * (1.1 + float(index) * 0.17) + TAU * float(index) / 3.0
		var radius: float = 12.0 + float(index) * 3.0
		var spark: Vector2 = center + Vector2(
			roundf(cos(angle) * radius), roundf(sin(angle) * radius * 0.55)
		)
		var spark_alpha: float = 0.45 + 0.35 * sin(_time * 3.0 + float(index))
		draw_rect(Rect2(spark, Vector2.ONE), Color(color.lightened(0.45), spark_alpha))


func _draw_shard(center: Vector2, color: Color) -> void:
	# 10x16 diamond: dark 1 px outline, solid phase fill, brighter left facet,
	# white 2x2 core.  It is deliberately larger than the player's badge so the
	# colour is readable from the start of the route.
	var outline: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -10.0),
		center + Vector2(7.0, -2.0),
		center + Vector2(0.0, 10.0),
		center + Vector2(-7.0, -2.0),
	])
	draw_colored_polygon(outline, STONE_EDGE)
	var fill: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -8.0),
		center + Vector2(5.0, -2.0),
		center + Vector2(0.0, 8.0),
		center + Vector2(-5.0, -2.0),
	])
	draw_colored_polygon(fill, color)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -8.0),
			center + Vector2(2.0, -2.0),
			center + Vector2(0.0, 6.0),
			center + Vector2(-3.0, -2.0),
		]),
		color.lightened(0.35)
	)
	draw_rect(Rect2(center + Vector2(-1.0, -3.0), Vector2(2.0, 2.0)), WHITE)
	draw_rect(Rect2(center + Vector2(0.0, -1.0), Vector2.ONE), Color(1.0, 1.0, 1.0, 0.75))
	# A 1 px rim light on the upper-left facet.
	draw_rect(Rect2(center + Vector2(-2.0, -6.0), Vector2(1.0, 1.0)), Color(WHITE, 0.75))
	draw_rect(Rect2(center + Vector2(-3.0, -5.0), Vector2(1.0, 1.0)), Color(WHITE, 0.55))


func _draw_pulse(center: Vector2, color: Color) -> void:
	if _pulse_left <= 0.0:
		return
	var progress: float = 1.0 - _pulse_left / PULSE_TIME
	var radius: float = 12.0 + progress * 16.0
	var alpha: float = (1.0 - progress) * 0.8
	# Expanding diamond ring + four cardinal ticks: an unmistakable pulse
	# without a screen-wide flash.
	draw_polyline(
		PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.8, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.8, 0.0),
			center + Vector2(0.0, -radius),
		]),
		Color(color.lightened(0.4), alpha),
		1.0
	)
	for offset: Vector2 in [
		Vector2(0.0, -radius - 2.0), Vector2(0.0, radius + 1.0),
		Vector2(-radius * 0.8 - 2.0, 0.0), Vector2(radius * 0.8 + 1.0, 0.0),
	]:
		draw_rect(Rect2(center + offset, Vector2.ONE), Color(WHITE, alpha))
	if progress < 0.35:
		draw_rect(Rect2(center + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)),
			Color(WHITE, (0.35 - progress) / 0.35))
