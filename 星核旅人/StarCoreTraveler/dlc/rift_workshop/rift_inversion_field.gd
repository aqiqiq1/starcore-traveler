class_name RiftInversionField
extends Node2D

## Rift-workshop inversion curtain: a 24 x 120 violet light screen that turns
## the player's phase over once per entry.
##
## Rules:
##   - entering the curtain (Area2D body_entered, player only) flips the player
##     exactly once;
##   - staying inside never flips again; Q is locked in this chapter;
##   - leaving re-arms the field, so the same curtain can be used again.
##
## The field never reads input, never hurts and never blocks movement: it only
## writes one polarity change through the player's existing set_polarity_state()
## API.  Visually it follows the same reading order as the trial's approved
## PolarityGate (whole screen in one hue + a central bright core, dark 1 px
## silhouette), with violet as the rift chapter's own accent.

signal field_triggered(positive_after: bool)

const PURPLE: Color = Color("#a874ff")
const PURPLE_LIGHT: Color = Color("#d8bcff")
const DARK_EDGE: Color = Color(0.004, 0.012, 0.016, 0.96)
const DARK_CAP: Color = Color(0.008, 0.022, 0.028, 0.92)
const FLASH_TIME: float = 0.28

@export var field_width: float = 24.0
@export var field_height: float = 120.0
## Explicit player target.  Empty resolves one from the parent at runtime.
@export var player_path: NodePath = NodePath()

var _player: Node2D = null
var _area: Area2D = null
var _inside: bool = false
var _trigger_count: int = 0
var _flash: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_area = get_node_or_null("Trigger") as Area2D
	if _area != null:
		_area.monitoring = true
		if not _area.body_entered.is_connected(_on_body_entered):
			_area.body_entered.connect(_on_body_entered)
		if not _area.body_exited.is_connected(_on_body_exited):
			_area.body_exited.connect(_on_body_exited)
	_resolve_player()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	queue_redraw()


# --- public read API -------------------------------------------------------

func get_trigger_count() -> int:
	return _trigger_count


func is_player_inside() -> bool:
	return _inside


func get_field_size() -> Vector2:
	return Vector2(field_width, field_height)


func get_field_rect() -> Rect2:
	return Rect2(
		global_position + Vector2(-field_width * 0.5, -field_height),
		Vector2(field_width, field_height)
	)


func get_state_name() -> String:
	return "inside" if _inside else "armed"


# --- public write API (scene wiring / tests) -------------------------------

func set_player_node(player: Node2D) -> void:
	_player = player
	_inside = false


## Re-arms the field after a restart without moving anybody.
func reset_inside_state() -> void:
	_inside = false
	_flash = 0.0


# --- internals -------------------------------------------------------------

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
				and child.has_method("is_positive"):
			_player = child as Node2D
			return


func _on_body_entered(body: Node2D) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	if body != _player:
		return
	if _inside:
		return
	_inside = true
	_trigger()


func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_inside = false


func _trigger() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.has_method("set_polarity_state"):
		return
	var positive: bool = not bool(_player.call("is_positive"))
	_player.call("set_polarity_state", positive)
	_trigger_count += 1
	_flash = 1.0
	field_triggered.emit(positive)
	queue_redraw()


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var half: float = field_width * 0.5
	var top: float = -field_height
	# 1 px dark silhouette first: the screen stays readable over bright sky.
	draw_rect(Rect2(-half, top, field_width, field_height), DARK_EDGE)
	var inner_x: float = -half + 1.0
	var inner_w: float = field_width - 2.0
	var inner_h: float = field_height - 2.0
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.4)

	# Vertical violet bands, brighter toward the centre column.
	for index: int in range(int(inner_w)):
		var column_x: float = inner_x + float(index)
		var distance: float = absf(column_x + 0.5) / maxf(half, 1.0)
		var alpha: float = 0.30 + 0.34 * (1.0 - distance) + 0.06 * pulse
		draw_rect(
			Rect2(column_x, top + 1.0, 1.0, inner_h),
			Color(PURPLE, clampf(alpha + _flash * 0.30, 0.0, 1.0))
		)

	# Dark caps keep the 24 x 120 screen from reading as a soft gradient.
	draw_rect(Rect2(inner_x, top + 1.0, inner_w, 7.0), DARK_CAP)
	draw_rect(Rect2(inner_x, -8.0, inner_w, 7.0), DARK_CAP)

	# 1 px bright side rails.
	draw_rect(Rect2(-half, top, 1.0, field_height), Color(PURPLE_LIGHT, 0.88))
	draw_rect(Rect2(half - 1.0, top, 1.0, field_height), Color(PURPLE_LIGHT, 0.88))

	# Upward-scrolling tick rows: the only motion while idle, 1 px wide, so it
	# never competes with the player or the wisps.
	var scroll: float = fmod(_time * 18.0, 12.0)
	var tick_y: float = top + 14.0 + scroll
	while tick_y < -14.0:
		draw_rect(Rect2(inner_x + 2.0, tick_y, inner_w - 4.0, 1.0),
			Color(PURPLE_LIGHT, 0.22))
		tick_y += 12.0

	# Central inversion core: one bright vertical slit plus a diamond.  Two
	# small chevrons point both ways to read as "turn over", not as a door.
	var core_y: float = top + field_height * 0.5
	var core_alpha: float = 0.75 + 0.25 * pulse + _flash * 0.25
	draw_rect(Rect2(-1.0, core_y - 24.0, 2.0, 48.0),
		Color(PURPLE_LIGHT, clampf(core_alpha * 0.55, 0.0, 1.0)))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, core_y - 8.0),
			Vector2(5.0, core_y),
			Vector2(0.0, core_y + 8.0),
			Vector2(-5.0, core_y),
		]),
		Color(PURPLE_LIGHT, clampf(core_alpha, 0.0, 1.0))
	)
	draw_rect(Rect2(-1.0, core_y - 1.0, 2.0, 2.0), Color(1.0, 0.98, 1.0, 1.0))

	var chevron_y: float = core_y + 16.0
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-8.0, chevron_y - 3.0),
			Vector2(-4.0, chevron_y),
			Vector2(-8.0, chevron_y + 3.0),
		]),
		Color(PURPLE_LIGHT, 0.55)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(8.0, chevron_y - 3.0),
			Vector2(4.0, chevron_y),
			Vector2(8.0, chevron_y + 3.0),
		]),
		Color(PURPLE_LIGHT, 0.55)
	)

	# Trigger flash: a white core and two outgoing horizontal lines.
	if _flash > 0.0:
		draw_rect(Rect2(inner_x, top + 1.0, inner_w, inner_h),
			Color(1.0, 0.94, 1.0, 0.30 * _flash))
		for offset: float in [-30.0, -18.0, 18.0, 30.0]:
			var length: float = 10.0 + 46.0 * (1.0 - _flash)
			draw_rect(Rect2(-half - length, core_y + offset, length, 1.0),
				Color(PURPLE_LIGHT, 0.7 * _flash))
			draw_rect(Rect2(half, core_y + offset, length, 1.0),
				Color(PURPLE_LIGHT, 0.7 * _flash))
