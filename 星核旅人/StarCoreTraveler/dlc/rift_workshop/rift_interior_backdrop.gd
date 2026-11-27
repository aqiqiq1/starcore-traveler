class_name RiftInteriorBackdrop
extends CanvasLayer

## Presentation-only parallax for the DLC2 interior layers.
##
## The Background CanvasLayer stays at layer -10 and the RiftFog node keeps its
## name; this script offsets the sprite children and the throat overlay so a
## 1880 px workshop can be traversed without turning into one repeated screen.
## Every offset is rounded to a whole pixel.  It reads the current Camera2D's
## screen centre and never touches gameplay, collision, the boss or the HUD.

const VIEW_WIDTH: float = 640.0
const MAX_SCROLL: float = 1240.0
const BACK_FACTOR: float = 0.90
const MID_FACTOR: float = 0.97

var _back: Sprite2D = null
var _mid: Sprite2D = null
var _depth_overlay: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_back = get_node_or_null("Back") as Sprite2D
	_mid = get_node_or_null("Mid") as Sprite2D
	_depth_overlay = get_node_or_null("DepthOverlay") as Control
	if Engine.is_editor_hint():
		set_process(false)
		_apply(0.0)
		return
	set_process(true)
	_apply(0.0)


func _process(_delta: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var centre_x: float = camera.get_screen_center_position().x
	var scroll: float = clampf(centre_x - VIEW_WIDTH * 0.5, 0.0, MAX_SCROLL)
	_apply(scroll)


func _apply(scroll: float) -> void:
	# Every layer position is a whole pixel.  The depth overlay shares the
	# Back offset so its throat mask stays aligned; its shader handles the
	# different 0.65 deep-content speed.
	var back_x: float = -roundf(scroll * BACK_FACTOR)
	if _back != null:
		_back.position.x = back_x
	if _depth_overlay != null:
		_depth_overlay.position.x = back_x
	if _mid != null:
		_mid.position.x = -roundf(scroll * MID_FACTOR)
