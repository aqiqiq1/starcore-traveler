class_name LoomGuide
extends DlcGuide

## Four-page intro guide for the city 星核织机 prototype.
##
## The shared guide (dlc/ui/dlc_guide.tscn/.gd) is used unchanged.  Its page
## table is a const keyed by chapter kind, so this small subclass supplies the
## third chapter's pages through the existing virtual `_page_data()` and adds
## the matching `open_guide()` gate.  The four demo ids are real 24-frame
## captures recorded from the formal star_loom scene into dlc/ui/demos/.

## Copy source: dlc/UI_PARITY_SPEC.md section 3 (星核织机, 4 pages).
## Every body line stays within 21 full-width characters; ASCII and digits
## count as half-width.  Several spec lines were shortened/reflowed for width;
## each change is listed in tests/README.md.
const LOOM_PAGES: Array = [
	{
		"title": "织机与双节点",
		"body": "织机以星核为梭，把全城命脉织进经线。\n两只节点替它守线；异相 J 打停，同相弹开。",
		"key": "Q 切异相 · J 打节点",
		"demo": "loom_nodes",
	},
	{
		"title": "核心暴露与阶段补给",
		"body": "节点停转，核心的金线网散开，露出紫色织结。\n核心每次真伤换相；阶段 1 结束补一次受击。",
		"key": "异相 J ×3 · 核心换相要追",
		"demo": "loom_core",
	},
	{
		"title": "地砖火柱与横扫",
		"body": "织机把城内火道接进地砖，又用横梁扫出光带。\n砖先亮起再喷火，光带会先给出预警。\n离开亮起的砖，跳过横扫光带。",
		"key": "离开发火砖 · 跳过光带",
		"demo": "loom_fire",
	},
	{
		"title": "三受击、齿轮与浮灵",
		"body": "织机用滚齿和浮灵补近身，城内星核护你三次。\n3 次受击才失败；失败从当前阶段重开。\n齿轮跳过，浮灵用 J 清。",
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
