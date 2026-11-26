class_name RiftGuide
extends DlcGuide

## Rift-only page data for the shared DlcGuide UI.
##
## dlc/ui/dlc_guide.gd is shared with the trial chapter and is intentionally not
## edited here.  It builds every page from the virtual `_page_data()` call, so
## this subclass supplies the rift's three pages while reusing the approved
## panel, 24-frame demo player, F paging, long-Space skip and tree pause exactly
## as they are.
##
## Copy follows dlc/UI_PARITY_SPEC.md section 3: the first sentence is the
## in-world reason, the following sentences are controls.  The permanent
## "金/青 相性 …" legend row was removed in the 2026-11-26 rework; these pages
## carry the rules as natural sentences instead.

const RIFT_PAGES: Array = [
	{
		"title": "裂隙回廊",
		"body": "星核裂开时留下紫幕，穿过会把相性翻面。\n门只认同相；这一章无法自由换相。\n看清门上的日/月，让紫幕把相性翻成同相。",
		"key": "穿过紫幕翻相，同相才能过门。",
		"demo": "rift_inversion",
	},
	{
		"title": "相性光桥",
		"body": "光桥只认同相，先用攻击熄灭桥上的光灵。\n光灵熄灭后，这座桥会一直亮着。\n俯冲的光灵会翻相，别停在桥上。",
		"key": "先熄桥上的光灵，再过桥；俯冲会翻相。",
		"demo": "rift_bridge",
	},
	{
		"title": "双面镜",
		"body": "双面镜的金、青两面盘护着中央核心。\n只有异相攻击能打碎面盘，同相会弹开。\n两面都碎后攻击核心三次；共三个阶段。",
		"key": "用异相攻击碎面盘，再打核心三次。",
		"demo": "rift_mirror",
	},
]


## The shared DlcGuide now uses a 24 px title.  Its label's minimum height is
## 32 px, so at the shared y=6 it reaches y=38 while the divider is still at
## y=36.  This rift-only subclass lifts the title to y=4 and drops the divider
## to y=39 (2 px / 3 px clear of the ink), without touching the shared file or
## reverting its 24 px size.
func _ready() -> void:
	super._ready()
	var title_label: Label = get_node_or_null(
		"DlcGuideRoot/GuidePanel/Title"
	) as Label
	var divider: ColorRect = get_node_or_null(
		"DlcGuideRoot/GuidePanel/Divider"
	) as ColorRect
	if title_label != null:
		title_label.position.y = 4.0
	if divider != null:
		divider.position.y = 39.0


func _page_data() -> Array:
	return RIFT_PAGES
