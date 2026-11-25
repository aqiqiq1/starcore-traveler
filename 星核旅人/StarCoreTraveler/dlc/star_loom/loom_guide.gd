class_name LoomGuide
extends DlcGuide

## Four-page intro guide for the city 星核织机 prototype.
##
## The shared guide (dlc/ui/dlc_guide.tscn/.gd) is used unchanged.  Its page
## table is a const keyed by chapter kind, so this small subclass supplies the
## third chapter's pages through the existing virtual `_page_data()` and adds
## the matching `open_guide()` gate.  The four demo ids are real 24-frame
## captures recorded from the formal star_loom scene into dlc/ui/demos/.

const LOOM_PAGES: Array = [
	{
		"title": "织机与双节点",
		"body": "Q 换相。只有异相 J 才能打停环绕节点；\n同相命中被弹开，节点不掉血。",
		"key": "Q 切异相 · J 打节点",
		"demo": "loom_nodes",
	},
	{
		"title": "核心暴露与阶段补给",
		"body": "两个节点都停转，中央核心才会打开。\n核心受创换相：Q 追相，异相 J 共 3 次。\n阶段 1 结束补给：受击数清零。",
		"key": "异相 J ×3 · 核心换相要追",
		"demo": "loom_core",
	},
	{
		"title": "地砖火柱与横扫",
		"body": "地砖先亮约 0.95 秒，再喷出火柱；横扫光带约 0.8 秒预警。\n离开亮起的地砖，跳过横扫光带。",
		"key": "看预警 · 离开火柱 / 跳过光带",
		"demo": "loom_fire",
	},
	{
		"title": "三受击、齿轮与浮灵",
		"body": "被击中 3 次才失败，受击后约 1 秒保护。\n失败从当前阶段重开。\n齿轮跳过，浮灵用 J 清掉。",
		"key": "3 次受击 · 齿轮跳过 · J 清浮灵",
		"demo": "loom_gear",
	},
]


func _page_data() -> Array:
	if guide_kind == "loom":
		return LOOM_PAGES
	return super._page_data()


func open_guide() -> bool:
	if guide_kind != "loom":
		return super.open_guide()
	if _open:
		return false
	_open = true
	_open_count += 1
	_page_index = 0
	_paused_before = get_tree().paused
	get_tree().paused = true
	_apply_page()
	_space_held = false
	_space_hold = 0.0
	# A Space already held before the guide opens must be released once, so the
	# opening state cannot count as a skip hold.
	_space_armed = not Input.is_physical_key_pressed(KEY_SPACE)
	if _skip_bar != null:
		_skip_bar.hide_progress()
	_root.visible = true
	_clean_player_input()
	opened.emit(guide_kind)
	return true
