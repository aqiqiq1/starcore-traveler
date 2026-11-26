class_name LoomPhaseGlyph
extends RefCounted

## Shared pixel geometry for the sun/moon phase icons used by the exposed core
## and the top-right HUD affinity marker.  Both callers draw the returned
## integer rects, so the glyph stays identical at any scale.

static func sun_pixels(
	center: Vector2, dark_radius: int, body_radius: int, ray_radii: Array,
	ink: Color, body: Color, rays: Color, highlight: Color = Color(0, 0, 0, 0)
) -> Array:
	var out: Array = []
	_disc_pixels(center, dark_radius, ink, out)
	_disc_pixels(center, body_radius, body, out)
	for radius_value: Variant in ray_radii:
		var radius: float = float(radius_value)
		for index: int in range(8):
			var angle: float = TAU * float(index) / 8.0
			var point: Vector2 = center + Vector2(
				round(cos(angle) * radius), round(sin(angle) * radius)
			)
			out.append({"rect": Rect2(point, Vector2.ONE), "color": rays})
	if highlight.a > 0.0:
		out.append({
			"rect": Rect2(
				center.x - float(body_radius) + 1.0,
				center.y - float(body_radius),
				1.0, 1.0
			),
			"color": highlight,
		})
	return out


## Crescent without a filled cut: only the dark rim and the body pixels outside
## the cut disc are returned, so the transparent control shows the world/HUD
## background through the moon's missing side.
static func moon_pixels(
	center: Vector2, dark_radius: int, body_radius: int,
	cut_offset: Vector2, cut_radius: int, ink: Color, body: Color
) -> Array:
	var cut_cells: Dictionary = {}
	_collect_disc(center + cut_offset, cut_radius, cut_cells)
	var out: Array = []
	_disc_pixels(center, dark_radius, ink, out, cut_cells)
	_disc_pixels(center, body_radius, body, out, cut_cells)
	return out


static func _disc_pixels(
	center: Vector2, radius: int, color: Color, out: Array,
	skip: Dictionary = {}
) -> void:
	var cx: int = int(round(center.x))
	var cy: int = int(round(center.y))
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if x * x + y * y > radius * radius + radius:
				continue
			var cell: Vector2i = Vector2i(cx + x, cy + y)
			if skip.has(cell):
				continue
			out.append({
				"rect": Rect2(float(cell.x), float(cell.y), 1.0, 1.0),
				"color": color,
			})


static func _collect_disc(center: Vector2, radius: int, out: Dictionary) -> void:
	var cx: int = int(round(center.x))
	var cy: int = int(round(center.y))
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if x * x + y * y > radius * radius + radius:
				continue
			out[Vector2i(cx + x, cy + y)] = true
