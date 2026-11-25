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
		"body": "工坊紫幕是星核裂开时的反转场。\n穿过光幕换相；同相桥实体化，异相坠落。",
		"key": "Q 换相 · 紫幕反转一次",
		"demo": "rift_inversion",
	},
	{
		"title": "相性光桥",
		"body": "光桥只与同相脚步实体化，是工坊唯一的过道。\n按 Q 追上桥的颜色再走；异相时桥会消失。",
		"key": "同相过桥 · Q 切换",
		"demo": "rift_bridge",
	},
	{
		"title": "双生守卫：先金后青",
		"body": "两只守卫守着裂隙核心，金色先醒，青色待机。\n蓄力时切异相、被吸近后 J 打胸口。\n金倒后青才醒；两只都倒才开核心。",
		"key": "先金后青 · 蓄力时异相 J",
		"demo": "rift_twins",
	},
	{
		"title": "星核留下的四道痕迹",
		"body": "紫幕=裂痕换相，引力光环=吸附。\n菱形=弱点，金/青=相性。\n普通命中只碎壳；等蓄力、切相、靠近再 J。",
		"key": "看光环 · 切异相 · 贴近 J",
		"demo": "rift_elements",
	},
]


func _page_data() -> Array:
	return RIFT_PAGES
