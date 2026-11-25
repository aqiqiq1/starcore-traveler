@tool
class_name L3Terrain
extends Node2D

## Level-03 stone platform: one authored rectangle, one real collision body.
##
## The top surface reuses the approved L2 stone ground strip (formal asset, not
## a preview). The fill/seams are drawn in the same warm-grey stone family with
## integer rectangles; nothing is stretched vertically. All values are scene
## exports so the greybox can be re-tuned without touching the shared level
## scripts or the shared terrain assets.

const GROUND_STRIP: Texture2D = preload(
	"res://assets/bridge_stone_v1/generated/l2_ground_1792x40.png"
)
const STRIP_HEIGHT: float = 40.0
const FILL_COLOR: Color = Color(0.196, 0.208, 0.203, 1.0)
const FILL_DARK: Color = Color(0.145, 0.157, 0.155, 1.0)
const SEAM_COLOR: Color = Color(0.105, 0.118, 0.118, 0.85)
const EDGE_COLOR: Color = Color(0.470, 0.500, 0.470, 0.95)
const TOP_LIGHT: Color = Color(0.575, 0.605, 0.560, 0.80)

@export var block_rect: Rect2 = Rect2(0.0, 0.0, 200.0, 40.0)
@export var make_collision: bool = true
## One-way top surface: the rise from the rune passes through from below, the
## landing from above still catches. Used only by the L3 device platform.
@export var one_way: bool = false
@export var tint: Color = Color.WHITE
@export var show_top_strip: bool = true
@export var joint_spacing: float = 64.0
@export var seam_spacing: float = 18.0

var _body: StaticBody2D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if make_collision:
		_body = StaticBody2D.new()
		_body.name = "Collision"
		_body.collision_layer = 1
		_body.collision_mask = 1
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(maxf(block_rect.size.x, 1.0), maxf(block_rect.size.y, 1.0))
		shape_node.shape = shape
		shape_node.position = block_rect.position + block_rect.size * 0.5
		shape_node.one_way_collision = one_way
		_body.add_child(shape_node)
		add_child(_body)
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = block_rect
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var strip_h: float = minf(STRIP_HEIGHT, rect.size.y)
	if show_top_strip:
		draw_texture_rect(
			GROUND_STRIP,
			Rect2(rect.position, Vector2(rect.size.x, strip_h)),
			true,
			tint
		)
		draw_line(
			Vector2(rect.position.x, rect.position.y + 0.5),
			Vector2(rect.end.x, rect.position.y + 0.5),
			Color(TOP_LIGHT, TOP_LIGHT.a * tint.a),
			1.0
		)
	else:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, strip_h)), FILL_COLOR * tint)

	if rect.size.y > strip_h:
		var fill_top: float = rect.position.y + strip_h
		var fill_height: float = rect.size.y - strip_h
		draw_rect(
			Rect2(Vector2(rect.position.x, fill_top), Vector2(rect.size.x, fill_height)),
			FILL_COLOR * tint
		)
		# Bottom shadow band and masonry seams. Integer lines only.
		draw_rect(
			Rect2(
				Vector2(rect.position.x, rect.end.y - 6.0),
				Vector2(rect.size.x, 6.0)
			),
			FILL_DARK * tint
		)
		var row_y: float = fill_top + seam_spacing
		var row_index: int = 0
		while row_y < rect.end.y - 6.0:
			draw_line(
				Vector2(rect.position.x, row_y),
				Vector2(rect.end.x, row_y),
				Color(SEAM_COLOR, SEAM_COLOR.a * tint.a),
				1.0
			)
			var joint_x: float = rect.position.x + joint_spacing * (0.5 + float(row_index % 2))
			while joint_x < rect.end.x:
				draw_line(
					Vector2(joint_x, row_y - seam_spacing),
					Vector2(joint_x, row_y),
					Color(SEAM_COLOR, SEAM_COLOR.a * tint.a),
					1.0
				)
				joint_x += joint_spacing
			row_y += seam_spacing
			row_index += 1

	# Vertical side faces keep the block readable against the cloud background.
	draw_rect(
		Rect2(Vector2(rect.position.x, rect.position.y + 2.0), Vector2(2.0, rect.size.y - 2.0)),
		FILL_DARK * tint
	)
	draw_rect(
		Rect2(Vector2(rect.end.x - 2.0, rect.position.y + 2.0), Vector2(2.0, rect.size.y - 2.0)),
		FILL_DARK * tint
	)
	draw_line(
		Vector2(rect.position.x, rect.position.y + 1.0),
		Vector2(rect.position.x, rect.end.y),
		Color(EDGE_COLOR, EDGE_COLOR.a * tint.a),
		1.0
	)
