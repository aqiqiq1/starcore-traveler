class_name CompletionEmblem
extends Control

## One shared settlement mark for all six completion pages: the same
## gold/cyan double-faced mirror with one eye that opens 裂隙工坊.  It is
## deliberately not the guard's chest core, not a star core and no longer the
## old gate roundel.
##
## The mark is drawn at runtime by MirrorFaceArt, the same module the DLC3
## entrance uses for its frame, eye and ripple.  It is authored at 32x32 and
## drawn 1:1 with nearest filtering, matching the HUD's 1 px gold-line
## language.  It owns no animation and no gameplay state.

const ART = preload("res://dlc/shared/side_route/mirror_face_art.gd")
const ART_ID: String = "double_mirror_eye_32"
const ICON_SIZE: Vector2 = Vector2(32.0, 32.0)
const DEFAULT_POSITION: Vector2 = Vector2(356.0, 12.0)


## Shared insertion point for all six completion panels.  The panel already
## owns its 400x210 layout; the emblem sits in the top-right corner without
## moving the title or the buttons.
static func attach_to(
	parent: Control, position_value: Vector2 = DEFAULT_POSITION
) -> CompletionEmblem:
	var emblem: CompletionEmblem = CompletionEmblem.new()
	emblem.name = "CompletionEmblem"
	emblem.position = position_value
	parent.add_child(emblem)
	return emblem


func _ready() -> void:
	custom_minimum_size = ICON_SIZE
	size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	var diameter: float = minf(size.x, size.y)
	ART.draw_emblem(self, size * 0.5, diameter)


func get_art_id() -> String:
	return ART_ID


func has_mirror_art() -> bool:
	return true


## Test hook: the paint is the dedicated mirror, never a guard/star core and
## never the retired gate emblem.
func is_dedicated_emblem() -> bool:
	return get_art_id() == ART_ID
