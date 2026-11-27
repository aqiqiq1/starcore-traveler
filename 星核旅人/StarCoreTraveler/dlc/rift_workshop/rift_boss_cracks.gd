class_name RiftBossCracks
extends Node2D

## Form-3 mirror cracks, kept in their own child layer so the orbiting face
## plates can be drawn on top of them.
##
## Layering inside RiftMirrorBoss (parent z_index = 5):
##   MirrorBase      z = -2  -> effective 3 (above the z=2 stone strip)
##   MirrorCracks    z = -2  -> effective 3, added after the base, so the
##                              cracks cover the mirror body
##   GoldFace/CyanFace z = -1 -> effective 4, added after this node, so the
##                              plates always cover the cracks
##   parent _draw    z = 5   -> chains, attack telegraphs, shatter bursts,
##                              core effects and the defeat flash stay above
##                              the plates.
##
## Only the long crack geometry lives here; every other effect stays on the
## boss's own draw layer.

const INK: Color = Color(0.008, 0.018, 0.024, 1.0)
const WHITE: Color = Color(1.0, 0.985, 0.92)
const GOLD_PALE: Color = Color("#ffe796")
const CYAN_PALE: Color = Color("#bcffff")

var _crack_lines: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-2.0, -54.0), Vector2(4.0, -30.0), Vector2(-4.0, -8.0), Vector2(3.0, 16.0), Vector2(-2.0, 52.0)]),
	PackedVector2Array([Vector2(-36.0, -42.0), Vector2(-10.0, -15.0), Vector2(-24.0, 18.0), Vector2(2.0, 44.0)]),
	PackedVector2Array([Vector2(30.0, -48.0), Vector2(12.0, -20.0), Vector2(30.0, 8.0), Vector2(18.0, 38.0)]),
	PackedVector2Array([Vector2(-48.0, 8.0), Vector2(-22.0, 4.0), Vector2(-4.0, -18.0), Vector2(22.0, -12.0)]),
	PackedVector2Array([Vector2(-18.0, -36.0), Vector2(-8.0, -26.0), Vector2(-14.0, -16.0)]),
	PackedVector2Array([Vector2(20.0, 24.0), Vector2(34.0, 32.0), Vector2(28.0, 44.0)]),
]

var _phase_index: int = 0
var _alpha: float = 0.0


func set_crack_state(phase_index: int, alpha: float) -> void:
	var next_alpha: float = clampf(alpha, 0.0, 1.0)
	if phase_index == _phase_index and is_equal_approx(next_alpha, _alpha):
		return
	_phase_index = phase_index
	_alpha = next_alpha
	queue_redraw()


func get_crack_alpha() -> float:
	return _alpha


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var pale: Color = GOLD_PALE if _phase_index >= 2 else CYAN_PALE
	for crack: PackedVector2Array in _crack_lines:
		for index: int in range(crack.size() - 1):
			var start: Vector2 = crack[index]
			var end: Vector2 = crack[index + 1]
			draw_line(start, end, Color(INK, _alpha), 3.0)
			draw_line(start + Vector2(1.0, 0.0), end + Vector2(1.0, 0.0),
				Color(WHITE, _alpha * 0.75), 1.0)
			if index % 2 == 0:
				draw_line(start, start.lerp(end, 0.55),
					Color(pale, _alpha * 0.55), 1.0)
