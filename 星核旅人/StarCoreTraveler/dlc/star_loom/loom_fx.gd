class_name LoomFx
extends Node2D

## World-space telegraphs and connective threads for the city star loom.
##
## Every warning is 0.70-1.00 s long and is drawn with 1 px lines, integer
## rects and small rings.  There is no additive glow or full-screen flash; the
## goal is to show *where* the next hazard will be, not to wash the arena.

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const PURPLE: Color = Color("#a874ff")
const AMBER: Color = Color("#ffb347")
const AMBER_HOT: Color = Color("#ffd27a")
const AMBER_DARK: Color = Color(0.16, 0.08, 0.02, 0.95)
const FLOOR_Y: float = 320.0
const CORE_POS: Vector2 = Vector2(700.0, 244.0)
## One-shot cyan/gold burst when the purple knot is first uncovered.  Every
## ring/particle starts outside the 19 px knot bracket, so the burst frames the
## weak point instead of painting a solid disc over it.
const EXPOSE_BURST_TIME: float = 0.55

var _chapter: Node = null
var _time: float = 0.0
var _burst_left: float = 0.0
var _burst_center: Vector2 = CORE_POS


func configure(chapter: Node) -> void:
	_chapter = chapter


## Called by the chapter exactly once per run, on the shielded -> exposed
## transition.  The persistent pulse lives on LoomCore; this is only the
## opening burst and its sparks.
func play_core_exposed_burst(center: Vector2 = CORE_POS) -> void:
	_burst_center = center
	_burst_left = EXPOSE_BURST_TIME
	queue_redraw()


func is_core_exposed_burst_active() -> bool:
	return _burst_left > 0.0


func get_core_exposed_burst_progress() -> float:
	if _burst_left <= 0.0:
		return 1.0
	return clampf(1.0 - _burst_left / EXPOSE_BURST_TIME, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_burst_left = maxf(_burst_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _chapter == null or not is_instance_valid(_chapter):
		return
	if not bool(_chapter.call("is_boss_active")):
		return
	var flash: float = float(_chapter.call("get_stage_flash"))
	if flash > 0.0:
		_draw_stage_flash(flash)

	_draw_core_exposed_burst()
	_draw_core_threads()

	var state: String = String(_chapter.call("get_attack_state_name"))
	if state != "telegraph":
		return
	var kind: String = String(_chapter.call("get_attack_kind"))
	var progress: float = float(_chapter.call("get_telegraph_progress"))
	match kind:
		"homing":
			_draw_homing_warning(progress)
		"sweep":
			_draw_sweep_warning(progress)
		"summon":
			_draw_summon_warning(progress)
		"fire":
			_draw_fire_warning(progress)
		"gear":
			_draw_gear_warning(progress)
		_:
			pass


func _draw_core_exposed_burst() -> void:
	if _burst_left <= 0.0:
		return
	var progress: float = get_core_exposed_burst_progress()
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	var fade: float = 1.0 - progress
	var center: Vector2 = _burst_center
	# Two opening rings: cyan leads, gold follows a step behind.  The extra
	# half-alpha neighbour gives each ring a 2 px read at 1x.
	var cyan_radius: float = lerpf(22.0, 54.0, eased)
	var gold_radius: float = lerpf(24.0, 46.0, eased)
	_solid_ring(center, cyan_radius, 2.0, Color(CYAN, 0.95 * fade))
	_solid_ring(center, gold_radius, 2.0, Color(GOLD, 0.82 * fade))
	# Eight short rays just outside the knot (r 22..36) at the opening instant;
	# solid 1 px steps read better at 1x than the older dotted hints.
	if progress < 0.45:
		var ray_fade: float = (1.0 - progress / 0.45) * fade
		var ray_length: int = int(round(10.0 + 8.0 * eased))
		for index: int in range(8):
			var direction: Vector2 = Vector2(
				cos(TAU * float(index) / 8.0 + PI * 0.25),
				sin(TAU * float(index) / 8.0 + PI * 0.25)
			)
			var ray_color: Color = GOLD if index % 2 == 0 else CYAN
			for step: int in range(ray_length + 1):
				var point: Vector2 = center + direction * (22.0 + float(step))
				draw_rect(
					Rect2(round(point.x), round(point.y), 1.0, 1.0),
					Color(ray_color, ray_fade)
				)
	# 18 two-pixel sparks fly outward, alternating cyan/gold with a white hot
	# cap and a short tail.  They start beyond the 19 px bracket so the diamond
	# stays clear, and the 2 px body survives the gold net behind it at 1x.
	for index: int in range(18):
		var angle: float = TAU * float(index) / 18.0 + 0.13
		var speed: float = 30.0 + 6.0 * float(index % 5)
		var distance: float = 20.0 + speed * progress
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var spark: Vector2 = center + direction * distance
		var spark_color: Color = CYAN if index % 2 == 0 else GOLD
		if index % 5 == 0:
			spark_color = Color(1.0, 0.97, 0.86, 1.0)
		var tail: Vector2 = spark - direction * 2.0
		draw_rect(
			Rect2(round(tail.x), round(tail.y), 1.0, 1.0),
			Color(spark_color, fade * 0.45)
		)
		# A 2x2 body with a 1 px down/right ink shadow separates each spark from
		# the gold net behind it; the white 1 px cap keeps the hot centre.
		draw_rect(
			Rect2(round(spark.x), round(spark.y) + 1.0, 2.0, 2.0),
			Color(0.02, 0.01, 0.05, fade * 0.65)
		)
		draw_rect(
			Rect2(round(spark.x), round(spark.y), 2.0, 2.0),
			Color(spark_color, fade * 0.92)
		)
		draw_rect(
			Rect2(round(spark.x), round(spark.y), 1.0, 1.0),
			Color(1.0, 1.0, 1.0, fade * 0.95)
		)


func _draw_core_threads() -> void:
	# Three loose threads from the bottom of the 208x152 loom frame to the floor,
	# so the body is visibly anchored to the hall.
	var palette: Array[Color] = [GOLD, PURPLE, CYAN]
	for index: int in range(3):
		var x: float = CORE_POS.x - 30.0 + 30.0 * float(index)
		var sway: float = sin(_time * 0.9 + float(index) * 1.7) * 2.0
		var color: Color = palette[index]
		var y: float = CORE_POS.y + 64.0
		while y < FLOOR_Y:
			draw_rect(
				Rect2(round(x + sway * ((y - CORE_POS.y) / 64.0)), y, 1.0, 1.0),
				Color(color, 0.22)
			)
			y += 4.0


func _draw_stage_flash(flash: float) -> void:
	var grow: float = 1.0 - flash
	var half: float = 60.0 + 360.0 * grow
	draw_rect(
		Rect2(CORE_POS.x - half, CORE_POS.y - 1.0, half * 2.0, 1.0),
		Color(1.0, 0.96, 0.86, 0.55 * flash)
	)
	draw_rect(
		Rect2(CORE_POS.x - half * 0.7, CORE_POS.y + 1.0, half * 1.4, 1.0),
		Color(GOLD, 0.35 * flash)
	)


func _draw_homing_warning(progress: float) -> void:
	var points: Array = _chapter.call("get_telegraph_points")
	var player: Node2D = _chapter.call("get_player")
	var pulse: float = 0.5 + 0.5 * sin(progress * PI * 5.0)
	for point_value: Variant in points:
		var point: Vector2 = point_value
		_ring(point, 7.0 + 5.0 * pulse, Color(PURPLE, 0.55 + 0.40 * pulse), 18)
		_ring(point, 14.0 + 7.0 * (1.0 - pulse), Color(PURPLE, 0.28 + 0.30 * pulse), 22)
		# A 3 px diamond marks the exact future bolt position.
		draw_rect(Rect2(point.x - 1.0, point.y - 2.0, 2.0, 4.0), Color(1.0, 0.94, 1.0, 0.9))
		draw_rect(Rect2(point.x - 2.0, point.y - 1.0, 4.0, 2.0), Color(PURPLE, 0.95))
		if player != null and is_instance_valid(player):
			_dotted_line(point, player.global_position + Vector2(0.0, -15.0), Color(PURPLE, 0.34))


func _draw_sweep_warning(progress: float) -> void:
	var start_x: float = float(_chapter.call("get_sweep_start_x"))
	var pulse: float = 0.5 + 0.5 * sin(progress * PI * 6.0)
	# A bright dashed lane at knee height across the whole hall: this is where
	# the band will travel, so the player can jump before it arrives.
	var x: float = 8.0
	while x < 952.0:
		draw_rect(Rect2(x, 297.0, 6.0, 2.0), Color(PURPLE, 0.38 + 0.22 * pulse))
		x += 13.0
	# Ghost of the band at its start point.
	var left: float = start_x - 11.0
	var top: float = FLOOR_Y - 50.0
	draw_rect(Rect2(left, top, 22.0, 50.0), Color(PURPLE, 0.18 + 0.16 * pulse))
	draw_rect(Rect2(left + 10.0, top, 2.0, 50.0), Color(1.0, 0.94, 1.0, 0.55 + 0.30 * pulse))
	for dash_y in range(int(top), int(FLOOR_Y), 6):
		draw_rect(Rect2(left, float(dash_y), 2.0, 4.0), Color(PURPLE, 0.75 + 0.25 * pulse))
		draw_rect(Rect2(left + 20.0, float(dash_y), 2.0, 4.0), Color(PURPLE, 0.75 + 0.25 * pulse))
	# Direction chevrons on the lane, pointing left with the band.
	var chevron_x: float = 900.0
	while chevron_x > 30.0:
		draw_rect(Rect2(chevron_x, 292.0, 1.0, 5.0), Color(PURPLE, 0.75))
		draw_rect(Rect2(chevron_x - 2.0, 294.0, 1.0, 2.0), Color(PURPLE, 0.6))
		draw_rect(Rect2(chevron_x + 2.0, 294.0, 1.0, 2.0), Color(PURPLE, 0.6))
		chevron_x -= 52.0


func _draw_summon_warning(progress: float) -> void:
	var points: Array = _chapter.call("get_telegraph_points")
	var pulse: float = 0.5 + 0.5 * sin(progress * PI * 4.0)
	for point_value: Variant in points:
		var point: Vector2 = point_value
		# A torn vertical slit with a purple rim and rising white specks.
		draw_rect(Rect2(point.x - 2.0, point.y - 14.0, 5.0, 28.0), Color(PURPLE, 0.34 + 0.30 * pulse))
		draw_rect(Rect2(point.x - 3.0, point.y - 10.0, 2.0, 20.0), Color(PURPLE, 0.75 + 0.25 * pulse))
		draw_rect(Rect2(point.x + 2.0, point.y - 10.0, 2.0, 20.0), Color(PURPLE, 0.75 + 0.25 * pulse))
		for index: int in range(4):
			var rise: float = fmod(_time * 18.0 + float(index) * 7.0, 28.0)
			draw_rect(
				Rect2(point.x - 0.5, point.y + 13.0 - rise, 2.0, 2.0),
				Color(1.0, 0.92, 1.0, 0.80)
			)


func _draw_fire_warning(progress: float) -> void:
	var points: Array = _chapter.call("get_telegraph_points")
	var pulse: float = 0.5 + 0.5 * sin(progress * PI * 6.0)
	for point_value: Variant in points:
		var point: Vector2 = point_value
		# Amber/heat only: a hot grate, a 3 px heat column on each side and
		# rising sparks.  No purple here, so fire never reads as polarity.
		draw_rect(Rect2(point.x - 15.0, point.y - 4.0, 30.0, 4.0), Color(AMBER_DARK, 0.9))
		draw_rect(
			Rect2(point.x - 14.0, point.y - 3.0, 28.0, 2.0),
			Color(AMBER, 0.55 + 0.40 * pulse)
		)
		draw_rect(
			Rect2(point.x - 12.0, point.y - 3.0, 24.0, 1.0),
			Color(AMBER_HOT, 0.60 + 0.35 * pulse)
		)
		for y in range(248, 318, 6):
			var flick: float = 0.65 + 0.35 * sin(_time * 18.0 + float(y) * 0.15)
			for side in [-1.0, 1.0]:
				var x: float = point.x + side * 10.0
				# Dark 1 px bed + a 3 px amber body + a hot 1 px core.
				draw_rect(Rect2(x - 2.5, float(y), 6.0, 3.0), Color(AMBER_DARK, 0.55))
				draw_rect(Rect2(x - 1.5, float(y), 4.0, 3.0), Color(AMBER, 0.80 * flick))
				draw_rect(Rect2(x - 0.5, float(y) + 1.0, 2.0, 1.0), Color(AMBER_HOT, 0.85))
		# Rising sparks.
		for index in range(5):
			var rise: float = fmod(_time * 30.0 + float(index) * 11.0, 44.0)
			draw_rect(
				Rect2(point.x - 8.0 + float(index) * 4.0, point.y - 12.0 - rise, 2.0, 2.0),
				Color(AMBER_HOT, 0.85)
			)
		# A short hot bar right at the grate.
		draw_rect(Rect2(point.x - 9.0, point.y - 7.0, 18.0, 2.0), Color(AMBER, 0.9))


func _draw_gear_warning(progress: float) -> void:
	var points: Array = _chapter.call("get_gear_points")
	var pulse: float = 0.5 + 0.5 * sin(progress * PI * 5.0)
	for point_value: Variant in points:
		var point: Vector2 = point_value
		var inward: int = 1 if point.x < 480.0 else -1
		var cx: float = point.x
		var cy: float = 298.0
		# Amber ghost gear with a dark bed, 2 px thick.
		_ring(Vector2(cx, cy), 17.0, Color(AMBER_DARK, 0.75), 26)
		_ring(Vector2(cx, cy), 16.0, Color(AMBER, 0.55 + 0.40 * pulse), 26)
		_ring(Vector2(cx, cy), 8.0, Color(AMBER_DARK, 0.65), 18)
		_ring(Vector2(cx, cy), 7.0, Color(AMBER, 0.45 + 0.35 * pulse), 18)
		for index in range(8):
			var angle: float = float(index) * TAU / 8.0 + _time * 1.2
			var tx: float = cx + cos(angle) * 20.0
			var ty: float = cy + sin(angle) * 20.0
			draw_rect(
				Rect2(round(tx) - 2.0, round(ty) - 2.0, 4.0, 4.0),
				Color(AMBER_HOT, 0.65 + 0.30 * pulse)
			)
		# Inward 3 px chevrons on the floor.
		var ax: float = cx + float(inward) * 24.0
		for index in range(3):
			var x: float = ax + float(inward) * float(index) * 9.0
			draw_rect(Rect2(x - 2.0, 288.0, 5.0, 3.0), Color(AMBER_DARK, 0.8))
			draw_rect(Rect2(x - 1.0, 289.0, 3.0, 3.0), Color(AMBER, 0.85))
			draw_rect(Rect2(x - 4.0, 292.0, 3.0, 3.0), Color(AMBER, 0.70))
		# Dust/drag line.
		draw_rect(Rect2(cx - 22.0, 314.0, 44.0, 3.0), Color(AMBER_DARK, 0.45))
		draw_rect(Rect2(cx - 18.0, 315.0, 36.0, 1.0), Color(AMBER, 0.55))


## Solid pixel annulus for the one-shot exposure burst.
func _solid_ring(center: Vector2, radius: float, thickness: float, color: Color) -> void:
	var outer_r: float = radius + thickness * 0.5
	var inner_r: float = maxf(radius - thickness * 0.5, 0.0)
	var y_start: int = int(floor(center.y - outer_r))
	var y_end: int = int(ceil(center.y + outer_r))
	for y: int in range(y_start, y_end):
		var row: float = float(y) + 0.5 - center.y
		var outer_sq: float = outer_r * outer_r - row * row
		if outer_sq <= 0.0:
			continue
		var outer_x: float = sqrt(outer_sq)
		var inner_x: float = 0.0
		var inner_sq: float = inner_r * inner_r - row * row
		if inner_sq > 0.0:
			inner_x = sqrt(inner_sq)
		var left: int = int(floor(center.x - outer_x))
		var right: int = int(ceil(center.x + outer_x))
		var gap_left: int = int(floor(center.x - inner_x))
		var gap_right: int = int(ceil(center.x + inner_x))
		if gap_left > left:
			draw_rect(Rect2(float(left), float(y), float(gap_left - left), 1.0), color)
		if right > gap_right:
			draw_rect(Rect2(float(gap_right), float(y), float(right - gap_right), 1.0), color)


func _ring(center: Vector2, radius: float, color: Color, segments: int) -> void:
	for index: int in range(segments):
		var angle: float = float(index) * TAU / float(segments)
		draw_rect(
			Rect2(
				round(center.x + cos(angle) * radius),
				round(center.y + sin(angle) * radius),
				1.0, 1.0
			),
			color
		)


func _dotted_line(from: Vector2, to: Vector2, color: Color) -> void:
	var distance: float = from.distance_to(to)
	if distance < 4.0:
		return
	var direction: Vector2 = (to - from) / distance
	var travelled: float = 8.0
	while travelled < distance:
		draw_rect(
			Rect2((from + direction * travelled) - Vector2(0.5, 0.5), Vector2(1.0, 1.0)),
			color
		)
		travelled += 8.0

