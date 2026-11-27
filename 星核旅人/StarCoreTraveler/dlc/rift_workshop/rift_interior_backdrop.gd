class_name RiftInteriorBackdrop
extends CanvasLayer

## Presentation-only parallax for the DLC2 interior layers.
##
## The Background CanvasLayer stays at layer -10 and the RiftFog node keeps its
## name; this script only offsets the sprite children so a 1880 px workshop can
## be traversed without turning into one repeated screen.  It reads the current
## Camera2D's screen centre and never touches gameplay, collision, the boss or
## the HUD.

const VIEW_WIDTH: float = 640.0
const MAX_SCROLL: float = 1240.0
const BACK_FACTOR: float = 0.90
const MID_FACTOR: float = 0.97

var _back: Sprite2D = null
var _mid: Sprite2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_back = get_node_or_null("Back") as Sprite2D
	_mid = get_node_or_null("Mid") as Sprite2D
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
	if _back != null:
		_back.position.x = -scroll * BACK_FACTOR
	if _mid != null:
		_mid.position.x = -scroll * MID_FACTOR
