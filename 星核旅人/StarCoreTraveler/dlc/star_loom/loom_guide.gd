class_name LoomGuide
extends DlcGuide

## Three-page intro guide for 星核织机.
##
## The shared guide (dlc/ui/dlc_guide.tscn/.gd) is used unchanged.  Its page
## table is a const keyed by chapter kind, so this small subclass supplies the
## third chapter's pages through the existing virtual `_page_data()` and adds
## the matching `open_guide()` gate.  The three demo ids are real 24-frame
## captures recorded from the formal star_loom scene into dlc/ui/demos/.

const LOOM_PAGES: Array = [
	{
		"title": "织机与双节点",
		"body": "Q 切换辉相 / 澜相。只有异相 J 才能打停环绕节点；\n同相命中会被弹开，节点不会掉血。",
		"key": "Q 切异相 · J 打节点",
		"demo": "loom_nodes",
	},
	{
		"title": "核心暴露与三段真伤",
		"body": "两个节点都停转，中央核心才会打开。\n核心每次受创都会换相：Q 追相，异相 J 共 3 次进入下一阶段。",
		"key": "异相 J ×3 · 核心换相要追",
		"demo": "loom_core",
	},
	{
		"title": "三段攻击与失败重置",
		"body": "织机会用慢速追踪弹、横扫光带和召唤裂隙浮灵。\n每次攻击前有 0.5 秒以上预警；两次受击回到入口，织机完整重置。",
		"key": "跳起躲光带 · J 清浮灵",
		"demo": "loom_attacks",
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
