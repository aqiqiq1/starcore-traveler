class_name RiftHeartShadow
extends Control

## 1 px dark silhouette behind the two HitPips hearts.  The row follows the
## player over bright sky, gold hair and the pale stable bridge, so the gold
## fill needs a hard edge to stay readable.  The shared HitPips art is reused;
## this node only supplies an outline and never changes the count.

const HEART_ROWS: Array[String] = [
	".xx.xx.",
	"xxxxxxx",
	"xxxxxxx",
	".xxxxx.",
	"..xxx..",
	"...x...",
]

var pip_size: float = 8.0
var gap: float = 3.0
var max_pips: int = 2
var outline_color: Color = Color(0.010, 0.022, 0.028, 0.96)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(
		float(max_pips) * pip_size + float(maxi(max_pips - 1, 0)) * gap + 2.0,
		pip_size + 2.0
	)
	size = custom_minimum_size


func _draw() -> void:
	for index: int in range(max_pips):
		var origin: Vector2 = Vector2(
			float(index) * (pip_size + gap) + 1.0, 1.0
		)
		# Eight neighbours make a hard 1 px outline; the HitPips fill covers the
		# centre, leaving only the rim visible.
		for offset: Vector2 in [
			Vector2(-1.0, -1.0), Vector2(0.0, -1.0), Vector2(1.0, -1.0),
			Vector2(-1.0, 0.0), Vector2(1.0, 0.0),
			Vector2(-1.0, 1.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0),
		]:
			_draw_heart(origin + offset)
		_draw_heart(origin)


func _draw_heart(origin: Vector2) -> void:
	for y: int in range(HEART_ROWS.size()):
		for x: int in range(HEART_ROWS[y].length()):
			if HEART_ROWS[y][x] != "x":
				continue
			draw_rect(
				Rect2(origin + Vector2(float(x), float(y)), Vector2.ONE),
				outline_color
			)
