class_name L3Gate
extends Node2D

## Level-03 gate, depth revision (2026-11-16).
##
## The facade is split into layers derived from the approved PNGs
## (assets/level03_gate_depth/): a fixed stone facade (both towers, the arch,
## the lintel and BOTH inner pillars), a movable door plate (closed / filled
## with the 16 px core), and a dark passage silhouette behind them. Only the
## plate rises; the arch and both inner pillars never move.
##
## Doorway interior (2026-11-18): the passage silhouette keeps its alpha and
## now carries a derived dark-stone interior (gate_passage_interior.png): a
## lit sill/threshold that meets the facade plinth, a soft left-jamb ambient,
## low-contrast rear-wall courses and a gradient that deepens into the doorway.
## A separate doorway-local shadow (gate_passage_shadow.png, z6, only inside
## the aperture) fades in as the plate rises: it darkens the body that is
## already inside the opening with a blue-grey tint and fades out again at the
## lit sill, so the contour and the feet stay readable. It is not a screen
## layer, never reaches the facade/left approach and never hides the body.
##
## Depth order (player z = 5): passage (z -1, also the plate's clip stencil)
## -> plate (z -1 child) -> fixed gatehouse (z 4, BEHIND the player) -> the real
## right arch-pillar inner lip (z 6, 6 px) and the building's return side +
## corner pilaster (z 6) -> building front (z 7). The left tower, the left arch
## pillar and the left gap are therefore never in front of the body; only the
## right lip pinches the body after the doorway midline and the turning
## building occludes it afterwards. Nothing changes the player's visibility or
## alpha and nothing teleports the body.
##
## The building is scripts/level03/l3_gate_depth_wall.gd: a receding return
## side, a corner pilaster and a front with base, cornice at the gate's real
## lintel band and pilaster bays. It is visual only (no collision) and does not
## block walking.
##
## Behaviour: E embeds the core (short feedback) -> the plate rises for ~1 s.
## The real door collision is released only when the plate has cleared enough
## travel height; door_opened fires exactly once. Pause freezes the plate and
## collision together (no Tween is used); reset_state/R restores the plate,
## the empty socket, the closed collision and the progress.

signal insert_started
signal door_opened

const IMAGE_SIZE: Vector2 = Vector2(144.0, 160.0)
const IMAGE_LEFT: float = -72.0
const IMAGE_TOP: float = -157.0
## Door plate inside the 144x160 facade (only the plate pixels differ between
## the closed and open PNGs, x55 y79 34x73).
const PLATE_RECT: Rect2 = Rect2(55.0, 79.0, 34.0, 73.0)
const SOCKET_LOCAL: Vector2 = Vector2(-1.5, -31.5)
const EMBED_RANGE: float = 50.0
const RISE_TIME: float = 1.0
const RISE_HOLD: float = 0.14
## Plate travel needed before the passage is really walkable (73 * 0.62 = 45 px,
## well above the 30 px body height).
const PASSABLE_PROGRESS: float = 0.62
## World x of the building's left end. It does NOT move with the gate: the
## gate is embedded in this building's face (user layout change 2026-11-16).
const BUILDING_WORLD_LEFT: float = 2292.0
const WALL_TOP: float = -400.0
const WALL_SIZE: Vector2 = Vector2(320.0, 400.0)
const GROUND_WORLD_Y: float = 320.0
const DOOR_BARRIER_CENTER: Vector2 = Vector2(0.0, -49.0)
const DOOR_BARRIER_SIZE: Vector2 = Vector2(4.0, 100.0)

const PASSAGE_TEXTURE: Texture2D = preload("res://assets/level03_gate_depth/gate_passage.png")
## Derived from PASSAGE_TEXTURE (same alpha silhouette). The base passage stays
## the clip stencil; this copy is what the doorway shows.
const INTERIOR_TEXTURE: Texture2D = preload("res://assets/level03_gate_depth/gate_passage_interior.png")
## Doorway-local coloured shadow in front of the player (z6). Its alpha is the
## aperture shape only; the PNG already holds the inward/sill falloff.
const PASSAGE_SHADOW_TEXTURE: Texture2D = preload("res://assets/level03_gate_depth/gate_passage_shadow.png")
const FIXED_TEXTURE: Texture2D = preload("res://assets/level03_gate_depth/gate_fixed.png")
const PLATE_CLOSED_TEXTURE: Texture2D = preload("res://assets/level03_gate_depth/gate_plate_closed.png")
const PLATE_FILLED_TEXTURE: Texture2D = preload("res://assets/level03_gate_depth/gate_plate_filled.png")
const APERTURE_TEXTURE: Texture2D = preload("res://assets/level03_gate_depth/gate_aperture_mask.png")
## The real right half of the gatehouse (right arch pillar + filled jamb +
## right tower), copied pixel for pixel from gate_fixed.png x88..143, y18..159.
## It is the ONLY part of the gatehouse drawn in front of the body (z6).
const RIGHT_FOREGROUND_TEXTURE: Texture2D = preload(
	"res://assets/level03_gate_depth/gate_right_foreground.png")
const RIGHT_FOREGROUND_RECT: Rect2 = Rect2(88.0, 18.0, 56.0, 142.0)
## Inner lip of the real right arch pillar inside the facade image; kept as a
## sub-rect of the foreground for compatibility (the pillar runs x88..99).
const RIGHT_EDGE_RECT: Rect2 = Rect2(88.0, 88.0, 6.0, 68.0)
## Visible character art inside the 128 px player frame (offset -59,-79 and the
## art bbox x41..72, y43..79). Used to measure how much of the body the
## foreground really covers.
const BODY_ART_OFFSET: Vector2 = Vector2(-18.0, -36.0)
const BODY_ART_SIZE: Vector2 = Vector2(31.0, 36.0)
## The wall's foreground copy carries its base three rows below the ground line
## (world 320..322) so the body's lowest visible alpha row (world 320) cannot
## show under it. Same plinth stone, one dark contact row at the bottom.
const FOREGROUND_BASE_DROP: float = 3.0
## The gate art's own foot: the right foreground's last column (texture x55) is
## cut 8 px above its plinth, and its jamb foot stops on the ground line
## (world 319) for the first 22 columns. Both one-pixel gaps are filled with the
## art's own tones so no player pixel leaks through the seam or the foot.
const RIGHT_FG_FOOT_COLUMNS: float = 22.0
const ART_FIELD: Color = Color(0.369, 0.329, 0.345, 1.0)   # 94 84 88
const ART_EDGE: Color = Color(0.235, 0.204, 0.224, 1.0)    # 60 52 57

@export var embed_range: float = EMBED_RANGE

var _passage: Sprite2D = null
var _passage_interior: Sprite2D = null
var _passage_shadow: Sprite2D = null
var _plate_clip: Sprite2D = null
var _plate: Sprite2D = null
var _fixed: Sprite2D = null
var _wall: Node2D = null
var _right_fg: Sprite2D = null
var _wall_front: Node2D = null
var _px_texture: ImageTexture = null
var _base_fills: Dictionary = {}
var _door_body: StaticBody2D = null
var _door_shape: CollisionShape2D = null
var _open: bool = false
var _inserted: bool = false
var _rise_progress: float = 0.0
var _rise_delay: float = 0.0
var _opened_emitted: bool = false


func _ready() -> void:
	_build_visuals()
	_build_door_body()
	set_process(true)


func _build_visuals() -> void:
	_init_px_texture()
	# The dark passage silhouette is also the clip stencil: it is really drawn
	# (AND_DRAW) so the doorway is dark stone, not sky, and its alpha is exactly
	# the real doorway aperture, so the plate disappears into the arch/lintel
	# instead of popping above the facade. The plate is its child, drawn clipped
	# over the passage but below the player.
	## The building's back face sits at z3, so the doorway backdrop has to be in
	## front of it (still behind the player z5) or the wall would show through
	## the doorway instead of the dark passage.
	_passage = _layer("Passage", PASSAGE_TEXTURE, Vector2(IMAGE_LEFT, IMAGE_TOP), 4)
	_passage.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_plate_clip = _passage
	# The derived interior is a child of the passage and is added BEFORE the
	# plate, so the moving plate still covers it while the door is closed. The
	# base passage keeps its alpha and remains the clip stencil.
	_passage_interior = Sprite2D.new()
	_passage_interior.name = "PassageInterior"
	_passage_interior.centered = false
	_passage_interior.offset = Vector2.ZERO
	_passage_interior.position = Vector2.ZERO
	_passage_interior.texture = INTERIOR_TEXTURE
	_passage_interior.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_passage.add_child(_passage_interior)
	_plate = Sprite2D.new()
	_plate.name = "DoorPlate"
	_plate.centered = false
	_plate.offset = Vector2.ZERO
	_plate.position = PLATE_RECT.position
	_plate.texture = PLATE_CLOSED_TEXTURE
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_passage.add_child(_plate)
	# Fixed gatehouse stays BEHIND the player (z4 < player z5): the left tower,
	# the left arch pillar and the left gap never cover the body.
	_fixed = _layer("FixedFacade", FIXED_TEXTURE, Vector2(IMAGE_LEFT, IMAGE_TOP), 4)
	# Right half of the gatehouse in front of the body: the real right pillar,
	# the filled jamb between it and the right tower, and the right tower itself.
	# A local pad, not the whole facade: the body is progressively covered from
	# the pillar's inner edge (world 2236) and stays covered through the tower.
	# The seam backing is a child at the same z created first, so the art draws
	# over it and only the art's own 1 px cut column shows the backing.
	# Doorway-local player shadow: same aperture alpha with an authored inward
	# falloff, drawn in front of the body (z6) but added BEFORE the right
	# foreground, so the real right pillar still draws over it. Its top/side
	# alpha is zero at the outer edge: nothing is covered before the doorway.
	_passage_shadow = _layer("PassageShadow", PASSAGE_SHADOW_TEXTURE,
		Vector2(IMAGE_LEFT, IMAGE_TOP), 6)
	_passage_shadow.visible = false
	_build_seam_backing()
	_right_fg = _layer("RightForeground", RIGHT_FOREGROUND_TEXTURE,
		Vector2(IMAGE_LEFT + RIGHT_FOREGROUND_RECT.position.x,
			IMAGE_TOP + RIGHT_FOREGROUND_RECT.position.y), 6)
	# Then the turning building: receding return + corner (z6), front (z7).
	_build_wall()
	_build_base_fills()


func _layer(node_name: String, texture: Texture2D, pos: Vector2, z: int) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.centered = false
	sprite.offset = Vector2.ZERO
	sprite.position = pos
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z
	add_child(sprite)
	return sprite


## Warm-grey masonry wall that continues the right tower into the city and
## above the camera; visual only (make_collision = false).
## The building keeps its world placement; only the gate moves inside it.
##   back layer (z3, behind the player): left end + the whole face the body
##   walks in front of;
##   right foreground (z7, in front of the player): the SAME front drawing,
##   clipped from the gate's right edge, so nothing jumps at the gate seam.
func _build_wall() -> void:
	# Local y 0 is the ground line (world 320); WALL_TOP is the (negative) local
	# top, so the drawn height is -WALL_TOP and the front runs from world -80
	# (above the 360 px camera top) down to the ground.
	var height: float = -WALL_TOP
	var anchor_x: float = BUILDING_WORLD_LEFT - global_position.x
	var return_side: L3GateDepthWall = L3GateDepthWall.new()
	return_side.name = "WallReturnSide"
	return_side.mode = L3GateDepthWall.Mode.RETURN_SIDE
	return_side.position = Vector2(anchor_x, WALL_TOP)
	return_side.size = Vector2(12.0, height)
	return_side.z_index = 3
	return_side.foreground = false
	add_child(return_side)
	var corner: L3GateDepthWall = L3GateDepthWall.new()
	corner.name = "WallCornerColumn"
	corner.mode = L3GateDepthWall.Mode.CORNER_PILASTER
	corner.position = Vector2(anchor_x + 12.0, WALL_TOP)
	corner.size = Vector2(16.0, height)
	corner.z_index = 3
	corner.foreground = false
	add_child(corner)
	var front: L3GateDepthWall = L3GateDepthWall.new()
	front.name = "WallFront"
	front.mode = L3GateDepthWall.Mode.FRONT
	front.position = Vector2(anchor_x + 28.0, WALL_TOP)
	front.size = Vector2(WALL_SIZE.x - 28.0, height)
	front.z_index = 3
	front.foreground = false
	add_child(front)
	_wall = front
	_wall_front = front
	# In front of the body from the gate's right tower edge: same drawing, only
	# clipped, so the body is occluded after it passes the gate and never before.
	var right_fg: L3GateDepthWall = L3GateDepthWall.new()
	right_fg.name = "WallRightForeground"
	right_fg.mode = L3GateDepthWall.Mode.FRONT
	right_fg.position = Vector2(anchor_x + 28.0, WALL_TOP)
	right_fg.size = Vector2(WALL_SIZE.x - 28.0, height)
	right_fg.clip_world_x = Vector2(global_position.x + IMAGE_LEFT + IMAGE_SIZE.x, 100000.0)
	right_fg.z_index = 7
	right_fg.foreground = true
	right_fg.base_drop = FOREGROUND_BASE_DROP
	add_child(right_fg)


## Two 1 px-class fills at the gate art's own foot, in front of the body (z6):
## the 22 px jamb foot that stops on the ground line, and the 1 px seam column
## where the right foreground's last texture column is cut 8 px short.
## Both use the gate art's tones (94,84,88 / 60,52,57); no black band, no
## collision, no visibility change.
func _init_px_texture() -> void:
	var image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_px_texture = ImageTexture.create_from_image(image)


## 1 px backing behind the right foreground's last art column. It closes the
## art's cut foot plus its few already-transparent edge pixels with the same
## dark tone the column itself uses, so a 1-2 px band of the body cannot pass.
func _build_seam_backing() -> void:
	var art_left: float = IMAGE_LEFT + RIGHT_FOREGROUND_RECT.position.x
	var art_top: float = IMAGE_TOP + RIGHT_FOREGROUND_RECT.position.y
	var bottom: float = (GROUND_WORLD_Y - global_position.y) + FOREGROUND_BASE_DROP
	_fill_rect("SeamBaseBacking", Vector2(art_left + RIGHT_FOREGROUND_RECT.size.x - 1.0, art_top),
		Vector2(1.0, bottom - art_top), ART_EDGE, 6)


func _build_base_fills() -> void:
	var art_left: float = IMAGE_LEFT + RIGHT_FOREGROUND_RECT.position.x
	# jamb foot: two field rows below the ground line, then the dark contact row
	_fill_rect("PillarBaseFill", Vector2(art_left, 0.0),
		Vector2(RIGHT_FG_FOOT_COLUMNS, FOREGROUND_BASE_DROP - 1.0), ART_FIELD, 6)
	_fill_rect("PillarBaseContact", Vector2(art_left, FOREGROUND_BASE_DROP - 1.0),
		Vector2(RIGHT_FG_FOOT_COLUMNS, 1.0), ART_EDGE, 6)


func _fill_rect(node_name: String, local_position: Vector2, rect_size: Vector2,
		color: Color, z: int) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	sprite.centered = false
	sprite.texture = _px_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = local_position
	sprite.scale = rect_size
	sprite.modulate = color
	sprite.z_index = z
	add_child(sprite)
	_base_fills[node_name] = Rect2(global_position + local_position, rect_size)
	return sprite


func _build_door_body() -> void:
	_door_body = StaticBody2D.new()
	_door_body.name = "DoorBarrier"
	_door_body.collision_layer = 1
	_door_body.collision_mask = 0
	_door_body.position = DOOR_BARRIER_CENTER
	_door_shape = CollisionShape2D.new()
	_door_shape.name = "CollisionShape2D"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = DOOR_BARRIER_SIZE
	_door_shape.shape = shape
	_door_body.add_child(_door_shape)
	add_child(_door_body)


func _process(delta: float) -> void:
	if not _inserted:
		return
	if _rise_delay > 0.0:
		_rise_delay = maxf(_rise_delay - delta, 0.0)
		return
	_rise_progress = clampf(_rise_progress + delta / RISE_TIME, 0.0, 1.0)
	_apply_plate()
	_update_passage_shadow()
	if not _opened_emitted and _rise_progress >= PASSABLE_PROGRESS:
		_release_passage()


## The doorway shadow follows the real plate travel (never the player's state):
## hidden while the plate is closed, in over the first part of the rise, full
## once the passage is really open. Reset writes 0 so no in-between survives.
func _update_passage_shadow() -> void:
	if _passage_shadow == null:
		return
	var t: float = clampf((_rise_progress - 0.08) / 0.42, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	_passage_shadow.visible = t > 0.001
	_passage_shadow.modulate = Color(1.0, 1.0, 1.0, t)


func _apply_plate() -> void:
	if _plate == null:
		return
	# Only the plate travels; the facade around it never moves. The plate sits
	# behind the facade so its top disappears into the lintel as it rises.
	_plate.position.y = PLATE_RECT.position.y - PLATE_RECT.size.y * _rise_progress


func _release_passage() -> void:
	_opened_emitted = true
	_open = true
	if _door_body != null:
		_door_body.collision_layer = 0
	if _door_shape != null:
		_door_shape.set_deferred("disabled", true)
	door_opened.emit()


func insert_core() -> bool:
	if _open or _inserted:
		return false
	_inserted = true
	if _plate != null:
		_plate.texture = PLATE_FILLED_TEXTURE
	_rise_delay = RISE_HOLD
	insert_started.emit()
	return true


## One-shot resume seed only (returning from a hidden side chapter): restore
## the already-open gate without replaying the insert/rise cue.  Normal play
## still goes through insert_core() and the real 1 s plate travel.
func force_open() -> void:
	_open = true
	_inserted = true
	_rise_progress = 1.0
	_rise_delay = 0.0
	_opened_emitted = true
	if _plate != null:
		_plate.texture = PLATE_FILLED_TEXTURE
	_apply_plate()
	_update_passage_shadow()
	if _door_body != null:
		_door_body.collision_layer = 0
	if _door_shape != null:
		_door_shape.set_deferred("disabled", true)


func reset_state() -> void:
	_open = false
	_inserted = false
	_rise_progress = 0.0
	_rise_delay = 0.0
	_opened_emitted = false
	if _plate != null:
		_plate.texture = PLATE_CLOSED_TEXTURE
	_apply_plate()
	if _passage_shadow != null:
		_passage_shadow.visible = false
		_passage_shadow.modulate = Color.WHITE
	if _door_body != null:
		_door_body.collision_layer = 1
	if _door_shape != null:
		_door_shape.set_deferred("disabled", false)


func can_embed(player_position: Vector2) -> bool:
	if _inserted or _open:
		return false
	return global_position.distance_to(player_position + Vector2(0.0, -15.0)) <= embed_range


func get_socket_world_position() -> Vector2:
	var rise: float = PLATE_RECT.size.y * _rise_progress
	return global_position + Vector2(SOCKET_LOCAL.x, SOCKET_LOCAL.y - rise)


func get_door_world_rect() -> Rect2:
	return Rect2(global_position + Vector2(IMAGE_LEFT, IMAGE_TOP), IMAGE_SIZE)


# --- accessors for the gate-focused tests / captures -----------------------

func is_open() -> bool:
	return _open


func is_inserted() -> bool:
	return _inserted


func get_plate_progress() -> float:
	return _rise_progress


func is_plate_moving() -> bool:
	return _inserted and not _opened_emitted and _rise_delay <= 0.0 and _rise_progress < 1.0


func is_collision_active() -> bool:
	return _door_shape != null and not _door_shape.disabled


func get_plate_world_rect() -> Rect2:
	if _plate == null or _plate_clip == null:
		return Rect2()
	return Rect2(_plate_clip.position + _plate.position + global_position, PLATE_RECT.size)


func get_passage_interior_sprite() -> Sprite2D:
	return _passage_interior


func get_passage_shadow_sprite() -> Sprite2D:
	return _passage_shadow


## 0 = no doorway shadow, 1 = fully open passage. Read by the gate-focused
## tests; it is presentation only and never gates the collision or completion.
func get_passage_shadow_amount() -> float:
	if _passage_shadow == null or not _passage_shadow.visible:
		return 0.0
	return clampf(_passage_shadow.modulate.a, 0.0, 1.0)


func get_fixed_world_rect() -> Rect2:
	return get_door_world_rect()


func get_inner_pillar_world_rects() -> Dictionary:
	# The two fixed inner pillars, read off the facade art: local x 43..54 and
	# 88..99, y 90..154. Both are drawn in the fixed layer at all times; these
	# rects describe them, they are not a pixel-symmetry proof.
	return {
		"left": Rect2(global_position + Vector2(IMAGE_LEFT + 43.0, IMAGE_TOP + 90.0), Vector2(12.0, 64.0)),
		"right": Rect2(global_position + Vector2(IMAGE_LEFT + 88.0, IMAGE_TOP + 90.0), Vector2(12.0, 64.0)),
	}


func get_wall_world_rect() -> Rect2:
	# World-space rect of the whole building block (fixed world placement, not
	# relative to the gate): from its left end to the right and from above the
	# camera top down to the ground line.
	return Rect2(Vector2(BUILDING_WORLD_LEFT, global_position.y + WALL_TOP),
		Vector2(WALL_SIZE.x, -WALL_TOP))


func get_wall_pieces() -> Dictionary:
	var pieces: Dictionary = {}
	for child: Node in get_children():
		if child is L3GateDepthWall:
			var piece: L3GateDepthWall = child as L3GateDepthWall
			pieces[piece.name] = {
				"z": piece.z_index,
				"rect": piece.get_draw_rect(),
				"mode": piece.mode,
				"foreground": piece.foreground,
			}
	return pieces


func get_right_edge_world_rect() -> Rect2:
	return Rect2(global_position + Vector2(IMAGE_LEFT + RIGHT_EDGE_RECT.position.x,
		IMAGE_TOP + RIGHT_EDGE_RECT.position.y), RIGHT_EDGE_RECT.size)


func get_right_foreground_world_rect() -> Rect2:
	return Rect2(global_position + Vector2(IMAGE_LEFT + RIGHT_FOREGROUND_RECT.position.x,
		IMAGE_TOP + RIGHT_FOREGROUND_RECT.position.y), RIGHT_FOREGROUND_RECT.size)


## World rects of the small foot/seam fills, for the coverage assertions.
func get_base_fill_rects() -> Dictionary:
	return _base_fills.duplicate()


func get_foreground_base_drop() -> float:
	if _wall_front == null:
		return 0.0
	for piece: Node in get_children():
		if piece is L3GateDepthWall and (piece as L3GateDepthWall).foreground \
				and (piece as L3GateDepthWall).mode == L3GateDepthWall.Mode.FRONT:
			return (piece as L3GateDepthWall).base_drop
	return 0.0


## Every real piece that stands in front of the player, left to right. The run
## is continuous from the right pillar's inner edge to the building front, so a
## body walking right can never become fully visible again.
func get_foreground_world_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = [get_right_foreground_world_rect()]
	for piece: Node in get_children():
		if piece is L3GateDepthWall:
			var wall: L3GateDepthWall = piece as L3GateDepthWall
			if wall.foreground:
				rects.append(wall.get_draw_rect())
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	return rects


## Fraction of a body rectangle covered by the foreground run (0 = fully
## visible, 1 = fully hidden). Only x overlap at the body's height counts.
func get_occlusion_coverage(body_world_rect: Rect2) -> float:
	if body_world_rect.size.x <= 0.0:
		return 0.0
	var covered: float = 0.0
	var body_left: float = body_world_rect.position.x
	var body_right: float = body_world_rect.end.x
	for rect: Rect2 in get_foreground_world_rects():
		if rect.end.y <= body_world_rect.position.y or rect.position.y >= body_world_rect.end.y:
			continue
		var left: float = maxf(rect.position.x, body_left)
		var right: float = minf(rect.end.x, body_right)
		if right > left:
			covered += right - left
	return clampf(covered / body_world_rect.size.x, 0.0, 1.0)


## Body art rect at a given player x (feet on the ground line).
func get_body_art_rect_at(x: float) -> Rect2:
	return Rect2(Vector2(x + BODY_ART_OFFSET.x, GROUND_WORLD_Y + BODY_ART_OFFSET.y), BODY_ART_SIZE)


func get_fixed_z() -> int:
	return _fixed.z_index if _fixed != null else 0


func has_wall_collision() -> bool:
	return false


func get_barrier_layer() -> int:
	# Compatibility accessor kept for the load/regression tests.
	return _door_body.collision_layer if _door_body != null else 0


func get_layer_z(node_name: String) -> int:
	var node: Node = get_node_or_null(node_name)
	if node is CanvasItem:
		return (node as CanvasItem).z_index
	return 0


func get_texture_paths() -> Dictionary:
	return {
		"passage": PASSAGE_TEXTURE.resource_path,
		"passage_interior": INTERIOR_TEXTURE.resource_path,
		"passage_shadow": PASSAGE_SHADOW_TEXTURE.resource_path,
		"fixed": FIXED_TEXTURE.resource_path,
		"plate_closed": PLATE_CLOSED_TEXTURE.resource_path,
		"plate_filled": PLATE_FILLED_TEXTURE.resource_path,
		"plate_current": _plate.texture.resource_path if _plate != null and _plate.texture != null else "",
		"aperture": APERTURE_TEXTURE.resource_path,
	}
