class_name MirrorFaceArt
extends RefCounted

## Shared pixel art for the "double-faced mirror with one eye" used by the
## DLC3 镜面裂隙 entrance and the boss defeat flash.  (The six settlement pages
## stopped using it on 2026-11-28; they now draw the shipped game icon.)
##
## The only source art is the approved 双面镜 boss material:
##   - `mirror_face_gold_48x48.png`  (left crescent)
##   - `mirror_face_cyan_48x48.png`  (right crescent)
## The entrance pastes the outer 20x46 px of each crescent 1:1; the smaller
## defeat flash redraws the same split-disc silhouette and eye from the same
## palette here.
##
## Everything is integer-rect drawing: one-pixel rims stay crisp at 640x360.
## No animation state, no gameplay state.

const GOLD: Color = Color("#f4cd63")
const GOLD_DEEP: Color = Color("#8a6a28")
const GOLD_PALE: Color = Color("#ffe796")
const CYAN: Color = Color("#5fe1e6")
const CYAN_DEEP: Color = Color("#2f8e93")
const CYAN_PALE: Color = Color("#bcffff")
const IRON: Color = Color("#343c40")
const IRON_DARK: Color = Color("#161e22")
const INK: Color = Color("#0a1218")
const WHITE: Color = Color("#fffbe6")

const GOLD_FACE: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_face_gold_48x48.png"
)
const CYAN_FACE: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_face_cyan_48x48.png"
)
## 1:1 crop of each approved crescent used by the entrance.  Bounds come from
## the two 48x48 images' alpha: gold fills x=1..37, cyan x=10..47, both y=1..46.
const PLATE_REGION_SIZE: Vector2 = Vector2(20.0, 46.0)
const GOLD_PLATE_REGION: Rect2 = Rect2(0.0, 1.0, 20.0, 46.0)
const CYAN_PLATE_REGION: Rect2 = Rect2(28.0, 1.0, 20.0, 46.0)


## Settlement emblem: a 32x32 split-disc mirror with one large eye, drawn at
## the emblem Control's local centre.  `size` is the outer diameter.
static func draw_emblem(
	canvas: CanvasItem, center: Vector2, size: float = 32.0
) -> void:
	# `size` is the outer diameter.  `ellipse` takes a diameter, not a radius.
	var diameter: float = size
	# Dark outer rim, cold-iron frame, then the split glass.  The 1 px pale
	# rim below is the same "light catching the frame" language as the entrance.
	ellipse(canvas, center, Vector2(diameter, diameter), IRON_DARK)
	ellipse(canvas, center, Vector2(diameter - 2.0, diameter - 2.0), IRON)
	ellipse_halves(
		canvas, center, Vector2(diameter - 4.0, diameter - 4.0), GOLD, CYAN
	)
	# 1 px inner rim.  Draw only the top-left arc bright and the bottom-right
	# arc dark, so the disc reads as a recessed mirror rather than a coin.
	ellipse_arc(
		canvas, center, Vector2(diameter - 2.0, diameter - 2.0),
		0.62, GOLD_PALE, 0.0, PI
	)
	ellipse_arc(
		canvas, center, Vector2(diameter - 2.0, diameter - 2.0),
		0.42, INK, PI, TAU
	)
	# One-pixel seam between the gold and cyan faces.
	var seam_x: float = round(center.x) - 0.5
	var seam_half: float = diameter * 0.5 - 3.0
	canvas.draw_rect(
		Rect2(seam_x, center.y - seam_half, 1.0, seam_half * 2.0),
		Color(INK, 0.62)
	)
	# The eye owns the centre; at 32 px it is 12x8 with a 2 px pupil.
	draw_eye(canvas, center, Vector2(size * 0.375, size * 0.25))
	# Two glass glints, kept to 2 px so the 32x32 icon stays legible.
	var glint: Vector2 = center + Vector2(-diameter * 0.21, -diameter * 0.25)
	canvas.draw_rect(Rect2(glint, Vector2(2.0, 1.0)), Color(WHITE, 0.55))
	canvas.draw_rect(Rect2(glint + Vector2(0.0, 1.0), Vector2(1.0, 1.0)), Color(WHITE, 0.30))


## The entrance's single eye.  `size` is the white sclera; the socket adds 4 px.
## Gold is always the left iris, cyan the right, matching the face split.
static func draw_eye(
	canvas: CanvasItem, center: Vector2, size: Vector2, highlight: bool = true
) -> void:
	var socket: Vector2 = size + Vector2(4.0, 4.0)
	ellipse(canvas, center, socket, INK)
	ellipse(canvas, center, size, WHITE)
	var iris: Vector2 = Vector2(size.x * 0.56, size.y * 0.84)
	ellipse_halves(canvas, center, iris, GOLD, CYAN)
	# Vertical slit pupil; 2 px wide at 32, 3 px at the entrance's 18x12 eye.
	var pupil_w: float = 2.0 if size.x < 14.0 else 3.0
	var pupil_h: float = maxf(size.y * 0.58, 3.0)
	canvas.draw_rect(
		Rect2(round(center.x) - pupil_w * 0.5, round(center.y - pupil_h * 0.5),
			pupil_w, pupil_h),
		INK
	)
	if not highlight:
		return
	# A single 1 px catchlight on the upper-left of the pupil.
	canvas.draw_rect(
		Rect2(round(center.x - pupil_w * 0.5) - 2.0,
			round(center.y - pupil_h * 0.5) + 1.0, 1.0, 1.0),
		Color(WHITE, 0.92)
	)
	canvas.draw_rect(
		Rect2(round(center.x - pupil_w * 0.5) - 1.0,
			round(center.y - pupil_h * 0.5) + 2.0, 1.0, 1.0),
		Color(WHITE, 0.55)
	)


## Filled axis-aligned ellipse made of 1 px rows, so it never anti-aliases.
static func ellipse(
	canvas: CanvasItem, center: Vector2, size: Vector2, color: Color
) -> void:
	var spans: Array = _row_spans(center, size)
	for span: Array in spans:
		var y: float = span[0]
		var x0: float = span[1]
		var x1: float = span[2]
		canvas.draw_rect(Rect2(x0, y, x1 - x0, 1.0), color)


## One ellipse split down the middle: gold left, cyan right.  The seam is one
## integer column, matching the boss's two face plates.
static func ellipse_halves(
	canvas: CanvasItem, center: Vector2, size: Vector2, left: Color, right: Color
) -> void:
	var seam: float = round(center.x)
	var spans: Array = _row_spans(center, size)
	for span: Array in spans:
		var y: float = span[0]
		var x0: float = span[1]
		var x1: float = span[2]
		if x0 < seam:
			canvas.draw_rect(Rect2(x0, y, seam - x0, 1.0), left)
		if x1 > seam:
			canvas.draw_rect(Rect2(seam, y, x1 - seam, 1.0), right)


## 1 px ellipse arc between two angles (0 = +x, clockwise in screen space).
static func ellipse_arc(
	canvas: CanvasItem,
	center: Vector2,
	size: Vector2,
	span: float,
	color: Color,
	from_angle: float,
	to_angle: float
) -> void:
	var half: Vector2 = size * 0.5
	var segments: int = maxi(int(absf(to_angle - from_angle) * maxf(half.x, half.y) * 0.9), 8)
	for index: int in range(segments + 1):
		var angle: float = lerpf(from_angle, to_angle, float(index) / float(segments))
		var point: Vector2 = Vector2(
			round(center.x + cos(angle) * half.x),
			round(center.y + sin(angle) * half.y)
		)
		canvas.draw_rect(Rect2(point, Vector2.ONE), color)


static func _row_spans(center: Vector2, size: Vector2) -> Array:
	var half: Vector2 = size * 0.5
	var result: Array = []
	if half.x < 1.0 or half.y < 1.0:
		return result
	var y_start: int = int(round(center.y - half.y))
	var y_end: int = int(round(center.y + half.y))
	for y: int in range(y_start, y_end):
		var cy: float = (float(y) + 0.5 - center.y) / half.y
		if absf(cy) > 1.0:
			continue
		var span: float = half.x * sqrt(maxf(1.0 - cy * cy, 0.0))
		var x0: float = round(center.x - span)
		var x1: float = round(center.x + span)
		if x1 - x0 < 1.0:
			continue
		result.append([float(y), x0, x1])
	return result
