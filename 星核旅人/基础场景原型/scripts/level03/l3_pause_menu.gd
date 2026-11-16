extends "res://scripts/ui/pause_menu.gd"

## Level-03 pause page: the shared pause menu is reused unchanged for input,
## settings and restart ownership. This tiny subclass only corrects the fixed
## chapter subtitle, which the shared component otherwise hard-codes to level 02
## for every non-level-01 caller. No shared UI file is edited.

const L3_SUBTITLE: String = "断桥外郭 · 第三关"
const L2_SUBTITLE: String = "沉寂回廊 · 第二关"


func _ready() -> void:
	super._ready()
	_fix_subtitle()


func _fix_subtitle() -> void:
	if _panel == null:
		return
	for child: Node in _panel.get_children():
		if child is Label:
			var label: Label = child as Label
			if label.text.contains(L2_SUBTITLE):
				label.text = L3_SUBTITLE
				return
