class_name RiftGuide
extends DlcGuide

## Rift-only page data for the shared DlcGuide UI.
##
## dlc/ui/dlc_guide.gd is shared with the trial chapter and is intentionally not
## edited here.  It builds every page from the virtual `_page_data()` call, so
## this subclass supplies the rift's four pages (the three route pages plus the
## "元素含义" page) while reusing the approved panel, 24-frame demo player, F
## paging, long-Space skip and tree pause exactly as they are.
##
## Copy follows dlc/UI_PARITY_SPEC.md section 3: the first sentence is the
## in-world reason, the following sentences are controls.  Two spec lines were
## shortened only because they exceeded the shared 21-character line width;
## see the implementation report for the exact substitutions.

const RIFT_PAGES: Array = [
	{
		"title": "裂隙回廊",
		"body": "星核裂开时留下紫幕，进入会把相性翻面。\n同相才能过极性门；门后只剩断桥高廊。",
		"key": "Q 换相 · 紫幕反转一次",
		"demo": "rift_inversion",
	},
	{
		"title": "相性光桥",
		"body": "光桥只与同相脚步实体化，异相会坠入云海。\n光灵每 1.5 秒翻相；J 熄灭后该桥永久稳定。\n清掉光灵后桥不再消失，Q 只留给下一座。",
		"key": "同相过桥 · J 清光灵后稳定",
		"demo": "rift_bridge",
	},
	{
		"title": "双生守卫",
		"body": "两只守卫守着裂隙核心，金色先醒，青色待机。\n蓄力时切异相、被吸近后 J 打胸口。\n金倒后青才醒；两只都倒才开核心。",
		"key": "先金后青 · 蓄力时异相 J",
		"demo": "rift_twins",
	},
	{
		"title": "元素含义",
		"body": "紫幕=裂痕换相，引力光环=吸附。\n菱形=弱点，金/青=相性。\n普通命中只碎壳；等蓄力、切相、靠近再 J。",
		"key": "看光环 · 切异相 · 贴近 J",
		"demo": "rift_elements",
	},
]


## The shared DlcGuide now uses a 24 px title.  Its label's minimum height is
## 32 px, so at the shared y=6 it reaches y=38 while the divider is still at
## y=36.  This rift-only subclass lifts the title to y=4 and drops the divider
## to y=39 (2 px / 3 px clear of the ink), without touching the shared file or
## reverting its 24 px size.  The 640x360 capture rework_guide_title.png is the
## visual check for the same frame.
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
