class_name CompletionEmblem
extends TextureRect

## One shared settlement mark for all six completion pages: a dark stone
## roundel, a gold gate silhouette and a thin ring of pale light.  It is
## deliberately not the guard's chest core and not a star core.
##
## The art is authored at 32x32 and shown 1:1 (nearest), matching the HUD's
## 1 px gold-line language.  It owns no animation and no gameplay state.

const TEXTURE_PATH: String = "res://assets/ui/icons/completion_gate_emblem_32.png"
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
	_ensure_icon()
	custom_minimum_size = ICON_SIZE
	size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP


func _ensure_icon() -> void:
	if _texture == null:
		_texture = load(TEXTURE_PATH) as Texture2D
	texture = _texture


func get_texture_path() -> String:
	return _texture.resource_path if _texture != null else TEXTURE_PATH


## Test hook: the paint is the dedicated gate emblem, never a guard/star core.
func is_dedicated_emblem() -> bool:
	return get_texture_path() == TEXTURE_PATH and not (
		get_texture_path().contains("weakpoint")
		or get_texture_path().contains("guard")
		or get_texture_path().contains("star_core")
	)
