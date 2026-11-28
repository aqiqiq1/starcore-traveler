class_name MechanicRegistry
extends RefCounted

## Read-only mechanism table for the first-encounter teaching line and the
## pause-page manual.
##
## Every row is player-facing copy and is deliberately the only source of that
## copy: levels trigger an id, MechanicTeach shows `summary`, and MechanicManual
## lists `name` / `summary` / `key` once the same id is unlocked.  Do not clone
## these strings into a level, HUD or another table.
##
## Icons are dedicated 12x12 PNGs under assets/ui/mechanic_icons/, drawn from
## the established gold / cyan / purple / stone palette with a 1 px ink
## outline.  The manual's left column draws these at 12x12; the key column
## still uses the real keycaps in assets/ui/keycaps/.
##
## `summary` is at most 40 CJK cells at 12 px.  `key` is the short key label for
## the manual (empty when the mechanism has no key of its own).

const ORDER: Array[String] = [
	"polarity",
	"gate",
	"rune",
	"bay",
	"checkpoint",
	"guard",
	"inversion",
	"bridge",
	"core_delivery",
	"loom_node",
	"fire",
	"gear",
	"wisp",
	"mirror",
	"lives",
]

const ENTRIES: Dictionary = {
	"polarity": {
		"name": "相性",
		"summary": "按换相键切换辉相 / 澜相",
		"key": "Q",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/polarity_12.png"},
	},
	"gate": {
		"name": "同相门",
		"summary": "同相门只认同相 · 看门上日/月 · 按换相键",
		"key": "Q",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/gate_12.png"},
	},
	"rune": {
		"name": "符文石",
		"summary": "同相推开，异相拉近；借力越坑",
		"key": "Q",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/rune_12.png"},
	},
	"bay": {
		"name": "联动仓",
		"summary": "联动仓记住星核相性，符石才会响应",
		"key": "E",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/bay_12.png"},
	},
	"checkpoint": {
		"name": "检查点",
		"summary": "触碰石碑记录恢复点，失败从这里回来",
		"key": "",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/checkpoint_12.png"},
	},
	"guard": {
		"name": "守卫",
		"summary": "守卫碎壳后打核；蓄力时切异相再打",
		"key": "J",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/guard_12.png"},
	},
	"inversion": {
		"name": "反转场",
		"summary": "紫幕反转 · 穿过换相",
		"key": "",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/inversion_12.png"},
	},
	"bridge": {
		"name": "相位桥",
		"summary": "相位桥只认同相；先熄桥上的光灵",
		"key": "J",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/bridge_12.png"},
	},
	"core_delivery": {
		"name": "星核",
		"summary": "把星核推入空仓，为门供电",
		"key": "E",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/core_delivery_12.png"},
	},
	"loom_node": {
		"name": "织机节点",
		"summary": "异相攻击打停节点，核心才会露出",
		"key": "J",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/loom_node_12.png"},
	},
	"fire": {
		"name": "火柱地砖",
		"summary": "亮砖将喷火柱；离开发光地砖",
		"key": "",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/fire_12.png"},
	},
	"gear": {
		"name": "齿轮",
		"summary": "两侧齿轮贴地扫来；跳起躲开",
		"key": "SPACE",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/gear_12.png"},
	},
	"wisp": {
		"name": "浮灵",
		"summary": "俯冲浮灵一剑清；会把你翻相",
		"key": "J",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/wisp_12.png"},
	},
	"mirror": {
		"name": "双面镜",
		"summary": "打碎两面盘、熄锚定光灵，再打核心",
		"key": "J",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/mirror_12.png"},
	},
	"lives": {
		"name": "生命数",
		"summary": "红心是三命；耗尽回到本章起点",
		"key": "",
		"icon": {"kind": "texture", "value": "res://assets/ui/mechanic_icons/lives_12.png"},
	},
}


static func all_ids() -> Array[String]:
	return ORDER.duplicate()


static func count() -> int:
	return ORDER.size()


static func has(id: String) -> bool:
	return ENTRIES.has(id)


static func get_entry(id: String) -> Dictionary:
	var data: Variant = ENTRIES.get(id, {})
	return data if data is Dictionary else {}


static func display_name(id: String) -> String:
	return String(get_entry(id).get("name", ""))


static func get_summary(id: String) -> String:
	return String(get_entry(id).get("summary", ""))


static func get_key_text(id: String) -> String:
	return String(get_entry(id).get("key", ""))


static func get_icon(id: String) -> Dictionary:
	var icon: Variant = get_entry(id).get("icon", {})
	return icon if icon is Dictionary else {}
