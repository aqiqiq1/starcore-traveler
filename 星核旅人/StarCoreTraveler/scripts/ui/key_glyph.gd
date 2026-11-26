class_name KeyGlyph
extends RefCounted

## Inline pixel keycaps for guide/popup copy.  The approved text used to spell
## "Q 换相" / "J 打" as letters; the creator wants key icons instead.  A
## RichTextLabel renders [img] tags, so copy uses {Q}, {J}, {E}, {F}, {R},
## {ESC}, {SHIFT}, {ENTER} and this helper expands them.
##
## UI copy uses 16 px caps so a 12 px key line keeps a normal line height.  The
## source art is 18 px tall; smaller caps keep the source aspect ratio.

const ICON_DIR: String = "res://assets/ui/keycaps/"
const ICON_HEIGHT: int = 18
const INLINE_HEIGHT: int = 16

const KEYS: Dictionary = {
	"Q": {"file": "key_q.png", "width": 18},
	"J": {"file": "key_j.png", "width": 18},
	"E": {"file": "key_e.png", "width": 18},
	"F": {"file": "key_f.png", "width": 18},
	"R": {"file": "key_r.png", "width": 18},
	"ESC": {"file": "key_esc.png", "width": 26},
	"SHIFT": {"file": "key_shift.png", "width": 30},
	"ENTER": {"file": "key_enter.png", "width": 30},
	"SPACE": {"file": "key_space.png", "width": 30},
}


## Expands every {KEY} placeholder into an inline [img] tag.  `height` defaults
## to the 16 px UI size; the cap width follows the 18 px source art.
static func decorate(text: String, height: int = INLINE_HEIGHT) -> String:
	var out: String = text
	var target_height: int = maxi(height, 1)
	for raw_key: Variant in KEYS.keys():
		var key: String = String(raw_key)
		var data: Dictionary = KEYS[raw_key] as Dictionary
		var path: String = ICON_DIR + String(data["file"])
		if not ResourceLoader.exists(path):
			out = out.replace("{%s}" % key, key)
			continue
		var base_width: int = int(data["width"])
		var width: int = maxi(
			roundi(float(base_width) * float(target_height) / float(ICON_HEIGHT)),
			1
		)
		out = out.replace(
			"{%s}" % key,
			"[img=%dx%d]%s[/img]" % [width, target_height, path]
		)
	return out


## Plain copy for tests/logs: placeholders become their readable key names.
static func plain(text: String) -> String:
	var out: String = text
	for raw_key: Variant in KEYS.keys():
		out = out.replace("{%s}" % raw_key, String(raw_key).capitalize())
	return out
