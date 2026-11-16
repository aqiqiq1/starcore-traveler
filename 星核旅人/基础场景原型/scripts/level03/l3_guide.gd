class_name L3Guide
extends Control

## L3-only low-HUD navigation and tiny feedback layer.
## One real target at a time; a short-lived dashed direction line / target
## diamond / screen-edge arrow appears for ~2.4 s after a stage change. Combat
## hides the navigation. E prompts are small text attached to the object; no
## panel. Two small talisman-crack pips carry the player's two-hit feedback.

const SAFE_RECT: Rect2 = Rect2(8.0, 48.0, 624.0, 252.0)
const GUIDE_TIME: float = 2.4
const GOLD: Color = Color("#f4cd63")
const MUTED: Color = Color("#a4b3be")
const DARK: Color = Color(0.01, 0.02, 0.024, 0.92)
const CHART: Color = Color("#ff7f72")

var player: L3Player = null
var target_world: Vector2 = Vector2.ZERO
var stage_key: String = ""
var guide_time: float = 0.0
var combat: bool = false
var hits: int = 0
var hit_pips: int = 0
## Two talismans are shown only while a fight is live.
var show_pips: bool = false
var prompt_text: String = ""
var prompt_world: Vector2 = Vector2.ZERO
var prompt_visible: bool = false
var event_text: String = ""
var event_time: float = 0.0
var world_text: String = ""
var world_text_world: Vector2 = Vector2.ZERO
var world_text_time: float = 0.0
var symbol_text: String = ""
var symbol_world: Vector2 = Vector2.ZERO
var symbol_time: float = 0.0
var _arrow_direction: Vector2 = Vector2.RIGHT
var _arrow_screen: Vector2 = Vector2.ZERO
var _target_screen: Vector2 = Vector2.ZERO
var _guide_alpha: float = 0.0
var _font: Font = null
var _event_duration: float = 1.4
var _world_text_duration: float = 0.7


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_font = _load_font()


func setup(owner_player: L3Player) -> void:
	player = owner_player


func set_target(world: Vector2, key: String) -> void:
	target_world = world
	if key != stage_key:
		stage_key = key
		guide_time = GUIDE_TIME


func set_combat(value: bool) -> void:
	combat = value
	show_pips = value
	queue_redraw()


func set_hits(value: int) -> void:
	hit_pips = clampi(value, 0, 2)
	queue_redraw()


func set_prompt(text_value: String, world_position: Vector2, visible_value: bool) -> void:
	prompt_text = text_value
	prompt_world = world_position
	prompt_visible = visible_value
	queue_redraw()


func show_event(text_value: String, duration: float = 1.4) -> void:
	event_text = text_value
	event_time = maxf(duration, 0.2)
	_event_duration = event_time
	queue_redraw()


## Short stable icon glyph at a world anchor: "?" (something did not answer)
## or "!" (something was noticed). Same glyphs as the emote sprites used by the
## near-gate film, drawn as 12 px text so no new icon art or black box is added.
func show_symbol(glyph: String, world_position: Vector2, duration: float = 0.8) -> void:
	symbol_text = glyph
	symbol_world = world_position
	symbol_time = maxf(duration, 0.2)
	queue_redraw()


func show_world_text(text_value: String, world_position: Vector2, duration: float = 0.7) -> void:
	world_text = text_value
	world_text_world = world_position
	world_text_time = maxf(duration, 0.15)
	_world_text_duration = world_text_time
	queue_redraw()


func _process(delta: float) -> void:
	if guide_time > 0.0:
		guide_time = maxf(guide_time - delta, 0.0)
	if event_time > 0.0:
		event_time = maxf(event_time - delta, 0.0)
		if event_time <= 0.0:
			event_text = ""
	if world_text_time > 0.0:
		world_text_time = maxf(world_text_time - delta, 0.0)
		if world_text_time <= 0.0:
			world_text = ""
	if symbol_time > 0.0:
		symbol_time = maxf(symbol_time - delta, 0.0)
		if symbol_time <= 0.0:
			symbol_text = ""
	queue_redraw()


func _screen_of(world: Vector2) -> Vector2:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return world
	return world - camera.get_screen_center_position() + Vector2(320.0, 180.0)


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var player_center: Vector2 = player.global_position + Vector2(0.0, -15.0)
	var player_screen: Vector2 = _screen_of(player_center)
	var target_screen: Vector2 = _screen_of(target_world)
	_target_screen = target_screen
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		_draw_pips(player_screen)
		if not combat and guide_time > 0.0:
			_draw_guide(player_center, player_screen, target_screen)
		if prompt_visible and not combat:
			_draw_prompt()
		if event_time > 0.0:
			_draw_event()
		if world_text_time > 0.0:
			_draw_world_text()
		if symbol_time > 0.0:
			_draw_symbol()
	else:
		_draw_pips(player_screen)


## Two small talismans, always visible in a fight: whole while the hit is
## still available, cracked/extinguished once it was taken. 0 hits = two whole,
## 1 hit = one cracked, 2 hits = both cracked (then the fight resets).
func _draw_pips(player_screen: Vector2) -> void:
	if not show_pips:
		return
	var base: Vector2 = player_screen + Vector2(0.0, -54.0)
	for index: int in range(2):
		var c: Vector2 = base + Vector2(float(index) * 12.0 - 6.0, 0.0)
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(c.x, c.y - 4.0), Vector2(c.x + 4.0, c.y),
			Vector2(c.x, c.y + 4.0), Vector2(c.x - 4.0, c.y),
		])
		if index < hit_pips:
			# Taken: dark cracked shard, clearly not a live hit.
			draw_colored_polygon(points, Color(0.16, 0.10, 0.10, 0.85))
			draw_polyline(PackedVector2Array([
				points[0], points[1], points[2], points[3], points[0]
			]), Color(CHART, 0.55), 1.0)
			draw_line(Vector2(c.x - 3.0, c.y - 3.0), Vector2(c.x + 2.0, c.y + 3.0),
				Color(CHART, 0.85), 1.0)
			draw_line(Vector2(c.x + 2.0, c.y + 3.0), Vector2(c.x + 3.0, c.y - 1.0),
				Color(CHART, 0.85), 1.0)
		else:
			draw_colored_polygon(points, GOLD)
			draw_polyline(PackedVector2Array([
				points[0], points[1], points[2], points[3], points[0]
			]), Color(DARK, 0.9), 1.0)
			draw_line(Vector2(c.x, c.y - 2.0), Vector2(c.x, c.y + 2.0),
				Color(DARK, 0.75), 1.0)


func _line_blocked(player_center: Vector2) -> bool:
	if player == null:
		return false
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	if space == null:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		player_center, target_world, 1, [player.get_rid()]
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not space.intersect_ray(query).is_empty()


func _draw_guide(player_center: Vector2, player_screen: Vector2, target_screen: Vector2) -> void:
	var dir: Vector2 = target_screen - player_screen
	var distance: float = dir.length()
	if distance <= 1.0:
		return
	dir /= distance
	var target_on_screen: bool = SAFE_RECT.grow(4.0).has_point(target_screen)
	var blocked: bool = _line_blocked(player_center)
	var fade: float = 1.0
	if guide_time > GUIDE_TIME - 0.15:
		fade = clampf((GUIDE_TIME - guide_time) / 0.15, 0.0, 1.0)
	elif guide_time < 0.45:
		fade = clampf(guide_time / 0.45, 0.0, 1.0)
	_guide_alpha = fade
	var use_line: bool = target_on_screen and distance <= 260.0 and not blocked
	if use_line:
		_draw_dashed_line(player_screen + dir * 14.0, dir, minf(96.0, distance - 10.0), fade)
		_draw_diamond(target_screen, fade)
		_arrow_direction = dir
		_arrow_screen = target_screen
	else:
		_draw_edge_arrow(player_center, player_screen, target_screen, dir, fade)


func _draw_dashed_line(start: Vector2, dir: Vector2, length: float, alpha: float) -> void:
	var travelled: float = 0.0
	while travelled < length:
		var seg: float = minf(4.0, length - travelled)
		var a: Vector2 = start + dir * travelled
		var b: Vector2 = start + dir * (travelled + seg)
		var local_alpha: float = alpha * (1.0 - travelled / maxf(length, 1.0) * 0.45)
		draw_line(a + Vector2(0.0, 1.0), b + Vector2(0.0, 1.0), Color(DARK, 0.7 * local_alpha), 2.0)
		draw_line(a, b, Color(GOLD, 0.82 * local_alpha), 2.0)
		travelled += 9.0


func _draw_diamond(center: Vector2, alpha: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(center.x, center.y - 3.0), Vector2(center.x + 3.0, center.y),
		Vector2(center.x, center.y + 3.0), Vector2(center.x - 3.0, center.y),
	])
	draw_colored_polygon(points, Color(GOLD, alpha))
	var closed: PackedVector2Array = PackedVector2Array([
		points[0], points[1], points[2], points[3], points[0]
	])
	draw_polyline(closed, Color(DARK, alpha), 1.0)


func _draw_edge_arrow(
	player_center: Vector2, player_screen: Vector2, target_screen: Vector2,
	dir: Vector2, alpha: float
) -> void:
	# Intersection with the safe rectangle from the player's screen point.
	var t: float = 100000.0
	if absf(dir.x) > 0.0001:
		var tx: float = (SAFE_RECT.end.x - player_screen.x) / dir.x if dir.x > 0.0 else (SAFE_RECT.position.x - player_screen.x) / dir.x
		if tx > 0.0:
			var py: float = player_screen.y + dir.y * tx
			if py >= SAFE_RECT.position.y and py <= SAFE_RECT.end.y:
				t = minf(t, tx)
	if absf(dir.y) > 0.0001:
		var ty: float = (SAFE_RECT.end.y - player_screen.y) / dir.y if dir.y > 0.0 else (SAFE_RECT.position.y - player_screen.y) / dir.y
		if ty > 0.0:
			var px: float = player_screen.x + dir.x * ty
			if px >= SAFE_RECT.position.x and px <= SAFE_RECT.end.x:
				t = minf(t, ty)
	if t >= 100000.0:
		return
	var edge: Vector2 = player_screen + dir * t
	var pos: Vector2 = edge - dir * 8.0
	_arrow_direction = dir
	_arrow_screen = pos
	var angle: float = atan2(dir.y, dir.x)
	var tip: Vector2 = pos + dir * 5.0
	var base1: Vector2 = pos - dir * 2.0 + dir.rotated(PI * 0.5) * 4.0
	var base2: Vector2 = pos - dir * 2.0 - dir.rotated(PI * 0.5) * 4.0
	var tri: PackedVector2Array = PackedVector2Array([tip, base1, base2])
	draw_colored_polygon(tri, Color(GOLD, 0.85 * alpha))
	var closed: PackedVector2Array = PackedVector2Array([tip, base1, base2, tip])
	draw_polyline(closed, Color(DARK, alpha), 1.0)


## Object-bound interaction hint: one 11x13 E keycap plus a 2-3 character
## verb. No sentence, no panel.
func _draw_prompt() -> void:
	if player == null:
		return
	if prompt_world.distance_to(player.global_position + Vector2(0.0, -15.0)) > 48.0:
		return
	var screen: Vector2 = _screen_of(prompt_world) + Vector2(0.0, -8.0)
	var verb: String = prompt_text.trim_prefix("E ").strip_edges()
	var verb_width: float = _text_width(verb)
	var width: float = 11.0 + 4.0 + verb_width
	var pos: Vector2 = Vector2(
		clampf(screen.x - width * 0.5, 8.0, 632.0 - width),
		clampf(screen.y, 92.0, 306.0)
	)
	var key_rect: Rect2 = Rect2(pos + Vector2(0.0, -1.0), Vector2(11.0, 13.0))
	draw_rect(key_rect, Color(DARK, 0.92))
	draw_rect(key_rect, Color(GOLD, 0.9), false, 1.0)
	draw_string(_font, key_rect.position + Vector2(2.0, 10.0), "E",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, GOLD)
	draw_string(_font, pos + Vector2(15.0, 9.0) + Vector2(1.0, 1.0), verb,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, DARK)
	draw_string(_font, pos + Vector2(15.0, 9.0), verb, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, GOLD)


func _draw_event() -> void:
	# The event line now lives in the HUD objective slot (y = 58), so this
	# world-space row is intentionally not drawn any more.
	return
	var alpha: float = clampf(event_time / 0.4, 0.0, 1.0)
	var pos: Vector2 = Vector2(15.0, 78.0)
	draw_string(_font, pos + Vector2(1.0, 1.0), event_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(DARK, alpha))
	draw_string(_font, pos, event_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(GOLD, alpha))


func _draw_symbol() -> void:
	if symbol_text.is_empty():
		return
	var alpha: float = clampf(symbol_time / 0.25, 0.0, 1.0)
	var screen: Vector2 = _screen_of(symbol_world) + Vector2(0.0, -14.0)
	var bob: float = -1.0 if fmod(symbol_time, 0.5) < 0.25 else 0.0
	var pos: Vector2 = Vector2(clampf(screen.x - 4.0, 8.0, 624.0),
		clampf(screen.y + bob, 92.0, 300.0))
	draw_string(_font, pos + Vector2(1.0, 1.0), symbol_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, DARK)
	draw_string(_font, pos, symbol_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, GOLD)


func _draw_world_text() -> void:
	if world_text.is_empty():
		return
	var alpha: float = clampf(world_text_time / 0.25, 0.0, 1.0)
	var screen: Vector2 = _screen_of(world_text_world)
	var width: float = _text_width(world_text)
	var pos: Vector2 = Vector2(clampf(screen.x - width * 0.5, 8.0, 632.0 - width), clampf(screen.y, 92.0, 306.0))
	draw_string(_font, pos + Vector2(1.0, 1.0), world_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(DARK, alpha))
	draw_string(_font, pos, world_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(GOLD, alpha))


func _text_width(text: String) -> float:
	if text.is_empty() or _font == null:
		return 0.0
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x


func _load_font() -> Font:
	var path: String = "res://assets/fonts/tutorial_zh.ttf"
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var base: FontFile = ResourceLoader.load(path) as FontFile
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


func get_guide_visible() -> bool:
	return guide_time > 0.0 and not combat


func get_guide_alpha() -> float:
	return _guide_alpha


func get_arrow_direction() -> Vector2:
	return _arrow_direction


func get_arrow_screen() -> Vector2:
	return _arrow_screen


func get_target_screen() -> Vector2:
	return _target_screen


func get_hit_pips() -> int:
	return hit_pips


func get_pips_visible() -> bool:
	return show_pips


func get_symbol_text() -> String:
	return symbol_text


func get_prompt_text() -> String:
	return prompt_text


func get_prompt_visible() -> bool:
	return prompt_visible


func get_event_text() -> String:
	return event_text


func is_combat() -> bool:
	return combat
