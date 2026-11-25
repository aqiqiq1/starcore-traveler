class_name LoomEdgeWarning
extends Control

## Screen-edge amber warning for the two rolling gears.
##
## The world-space gear warning sits at the hall edges; at the fight camera one
## of those edges is off-screen.  This HUD overlay puts a 3 px amber chevron on
## BOTH screen edges while the gear telegraph runs, with a dark 1 px outline and
## a short dust line on the floor.  It never takes input.

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const AMBER: Color = Color("#ffb347")
const AMBER_HOT: Color = Color("#ffd27a")
const OUTLINE: Color = Color(0.16, 0.08, 0.02, 1.0)

var _active: bool = false
var _progress: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	name = "GearEdgeWarning"
	position = Vector2.ZERO
	size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func set_warning(active: bool, progress: float = 0.0) -> void:
	if _active == active and is_equal_approx(_progress, progress):
		return
	_active = active
	_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	_time += delta
	if _active:
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * 12.0)
	var alpha: float = 0.75 + 0.25 * pulse
	# Left edge chevrons point right, right edge chevrons point left.
	for side in [0, 1]:
		var base_x: float = 4.0 if side == 0 else VIEW_SIZE.x - 24.0
		var direction: float = 1.0 if side == 0 else -1.0
		for index in range(3):
			var y: float = 142.0 + float(index) * 26.0
			var x0: float = base_x
			var x1: float = base_x + 16.0 * direction
			# 3 px dark outline, then a 2 px amber bar and a hot core.
			for offset in range(3):
				draw_rect(
					Rect2(minf(x0, x1) + (1.0 if direction < 0.0 else 0.0), y + offset - 1.0,
						16.0, 1.0),
					Color(OUTLINE, alpha)
				)
			draw_rect(Rect2(minf(x0, x1) + 1.0, y, 14.0, 3.0), Color(AMBER, alpha))
			draw_rect(
				Rect2(minf(x0, x1) + 5.0, y + 1.0, 6.0, 1.0),
				Color(AMBER_HOT, alpha)
			)
			# A short inward arrow head.
			draw_rect(Rect2(x1 - 3.0 * direction, y - 2.0, 3.0, 9.0), Color(OUTLINE, alpha))
			draw_rect(Rect2(x1 - 2.0 * direction, y - 1.0, 2.0, 7.0), Color(AMBER, alpha))
		# Dust along the floor at the edge.
		draw_rect(
			Rect2(float(6 if side == 0 else 604), 316.0, 30.0, 3.0),
			Color(AMBER, 0.55)
		)
		for dot in range(5):
			draw_rect(
				Rect2(
					float(10 + dot * 5) if side == 0 else float(610 + dot * 4),
					312.0 - float(dot % 3) * 2.0,
					2.0, 2.0
				),
				Color(AMBER_HOT, 0.65)
			)
