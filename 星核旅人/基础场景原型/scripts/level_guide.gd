@tool
class_name LevelGuide
extends Node2D

## Editor-only construction aids for level 01. Nothing here draws at runtime:
## the camera rect, opening path, checkpoint/exit anchors and pit guide are
## guides for the creator, not hidden walls or gameplay triggers.

@export var player_path: NodePath = NodePath("../Player")
@export var intro_end_path: NodePath = NodePath("../IntroEnd")
@export var camera_path: NodePath = NodePath("../Player/Camera2D")
@export var checkpoint_path: NodePath = NodePath("../Checkpoint")
@export var exit_path: NodePath = NodePath("../Exit")
@export var pit_guide_rect: Rect2 = Rect2(1200.0, 220.0, 256.0, 140.0)

const PATH_COLOR: Color = Color(0.96, 0.80, 0.40, 0.58)
const CAMERA_COLOR: Color = Color(0.42, 0.72, 0.78, 0.42)
const PIT_COLOR: Color = Color(0.95, 0.52, 0.42, 0.5)
const LABEL_COLOR: Color = Color(0.80, 0.88, 0.86, 0.85)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

var _font: Font


func _ready() -> void:
	_load_font()
	if Engine.is_editor_hint():
		set_process(true)
	else:
		set_process(false)
		visible = false
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _load_font() -> void:
	if _font != null or not ResourceLoader.exists(FONT_PATH):
		return
	var font_file: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if font_file == null:
		return
	var copy: FontFile = font_file.duplicate() as FontFile
	if copy != null:
		copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		copy.hinting = TextServer.HINTING_NONE
		copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		copy.allow_system_fallback = false
		_font = copy


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	_draw_intro_path()
	_draw_camera_rect()
	_draw_pit_rect()


func _draw_intro_path() -> void:
	var player: Node2D = get_node_or_null(player_path) as Node2D
	var end_marker: Node2D = get_node_or_null(intro_end_path) as Node2D
	if player == null or end_marker == null:
		return
	_dashed_line(player.position, end_marker.position, PATH_COLOR)
	draw_circle(player.position, 4.0, PATH_COLOR)
	draw_circle(end_marker.position, 4.0, PATH_COLOR)
	draw_line(end_marker.position + Vector2(0.0, -14.0), end_marker.position + Vector2(0.0, 14.0), PATH_COLOR, 1.0)
	if _font != null:
		draw_string(_font, player.position + Vector2(-34.0, -20.0), "出生 / 开场起点", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, LABEL_COLOR)
		draw_string(_font, end_marker.position + Vector2(6.0, -8.0), "交还控制", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, LABEL_COLOR)


func _draw_camera_rect() -> void:
	var camera: Camera2D = get_node_or_null(camera_path) as Camera2D
	if camera == null:
		return
	var rect: Rect2 = Rect2(
		Vector2(float(camera.limit_left), float(camera.limit_top)),
		Vector2(
			maxf(float(camera.limit_right - camera.limit_left), 1.0),
			maxf(float(camera.limit_bottom - camera.limit_top), 1.0)
		)
	)
	draw_rect(rect, Color(CAMERA_COLOR, 0.03), true)
	_dashed_rect(rect, CAMERA_COLOR)
	if _font != null:
		draw_string(_font, rect.position + Vector2(6.0, 14.0), "相机边界（Camera2D 属性）", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, LABEL_COLOR)


func _draw_pit_rect() -> void:
	draw_rect(pit_guide_rect, Color(PIT_COLOR, 0.06), true)
	_dashed_rect(pit_guide_rect, PIT_COLOR)
	if _font != null:
		draw_string(_font, pit_guide_rect.position + Vector2(8.0, pit_guide_rect.size.y - 8.0), "大坑 / 借力区", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, PIT_COLOR)


func _dashed_rect(rect: Rect2, color: Color) -> void:
	_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color)
	_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color)
	_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color)
	_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color)


func _dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var length: float = from.distance_to(to)
	if length <= 0.0:
		return
	var direction: Vector2 = (to - from) / length
	var travelled: float = 0.0
	while travelled < length:
		var segment: float = minf(6.0, length - travelled)
		draw_line(from + direction * travelled, from + direction * (travelled + segment), color, 1.0)
		travelled += 10.0
