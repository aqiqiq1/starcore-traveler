class_name RiftGuide
extends DlcGuide

## Rift-only page data for the shared DlcGuide UI.
##
## dlc/ui/dlc_guide.gd is shared with the trial chapter and is intentionally not
## edited here.  It builds every page from the virtual `_page_data()` call, so
## this subclass supplies the rift's four pages (the three route pages plus the
## "元素含义" page) while reusing the approved panel, 24-frame demo player, F
## paging, long-Space skip and tree pause exactly as they are.

const RIFT_PAGES: Array = [
	{
		"title": "路线：回廊 → 光桥 → 守卫",
		"body": "穿过紫色光幕与极性门，按相性跨过三座光桥。\n高台尽头记录检查点，然后进入双生守卫竞技场。",
		"key": "Q 换相 · 紫色光幕会自动翻转相性",
		"demo": "rift_inversion",
	},
	{
		"title": "反转场与相性桥",
		"body": "紫色光幕进入即反转一次，停在幕内不重复翻转。\n光桥同相才实体化；异相消失会落到下层。",
		"key": "Q 换相 · 与桥同色才能站上去",
		"demo": "rift_bridge",
	},
	{
		"title": "双生守卫：先金后青",
		"body": "金守卫先苏醒；先击败它，青守卫才解除待机。\n蓄力时异相 J 打弱点，每次 1 格共 3 格。\n倒后再打青守卫；失败/坠落两只满血重生。",
		"key": "两只都倒才开核心 · 蓄力时异相 J",
		"demo": "rift_twins",
	},
	{
		"title": "元素含义",
		"body": "金/青=相性：同相过桥，异相打弱点。\n紫幕=反转场换相；引力光环=吸附。\n菱形=弱点：蓄力时异相贴近 J 扣 1 格。",
		"key": "普通命中只碎壳 · 等蓄力、切相、靠近再 J",
		"demo": "rift_elements",
	},
]


func _page_data() -> Array:
	return RIFT_PAGES
