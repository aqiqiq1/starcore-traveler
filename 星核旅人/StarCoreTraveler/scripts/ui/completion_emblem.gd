class_name CompletionEmblem
extends Control

## One shared settlement mark for all six completion pages: the shipped game
## icon, the half-gold / half-cyan star core (`assets/icon/icon_32.png`).
##
## 2026-11-28: replaces the old double-faced mirror thumbnail and every earlier
## guard-weakpoint / star-core texture experiment.  The icon is authored at
## 32x32 and drawn 1:1 with nearest filtering, no extra frame and no scaling,
## so it stays crisp at 640x360.  The completion ripple/black hand-off is owned
## by CompletionMirrorFade, which finds this node by name and centres its rings
## on the emblem rect; the icon owns no animation and no gameplay state.

const ICON_PATH: String = "res://assets/icon/icon_32.png"
const ART_ID: String = "game_icon_32"
const ICON_SIZE: Vector2 = Vector2(32.0, 32.0)
const DEFAULT_POSITION: Vector2 = Vector2(356.0, 12.0)

var _texture: Texture2D = null


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
	_texture = _load_icon()
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	# 1:1 blit into the 32x32 box: no scale, no frame, no tint.
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, ICON_SIZE), false)


func _load_icon() -> Texture2D:
	if not ResourceLoader.exists(ICON_PATH):
		return null
	return ResourceLoader.load(ICON_PATH) as Texture2D


func get_art_id() -> String:
	return ART_ID


## The exact asset the page draws; tests compare this string.
func get_texture_path() -> String:
	return ICON_PATH


func get_texture() -> Texture2D:
	return _texture


func has_game_icon() -> bool:
	return _texture != null


## Kept for older call sites: the settlement page no longer uses mirror art.
func has_mirror_art() -> bool:
	return false


## True only when the shipped game icon really loaded; never a fallback drawing.
func is_dedicated_emblem() -> bool:
	return has_game_icon() and get_art_id() == ART_ID
