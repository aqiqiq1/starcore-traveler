class_name LoomGuide
extends DlcGuide

## Two-page intro guide for the city 星核织机 prototype.
##
## The shared guide (dlc/ui/dlc_guide.tscn/.gd) is used unchanged.  Its page
## table is a const keyed by chapter kind, so this small subclass supplies the
## third chapter's pages through the existing virtual `_page_data()` and adds
## the matching `open_guide()` gate.  Both demo ids are real 24-frame captures
## recorded from the formal star_loom scene into dlc/ui/demos/.
##
## Page 1 is the world/goal page; page 2 folds the three-hit protection, the
## stage-1 supply, the current-stage retry and the gear/wisp answers into one
## page.  This removes the old entry/core teaching popups: every instruction
## now has exactly one home in a run.

## Copy source: dlc/UI_PARITY_SPEC.md section 3 (星核织机), condensed from the
## approved four-page copy.  Every body line stays within 21 full-width
## characters; ASCII and digits count as half-width.  Widths are recorded in
## tests/README.md.
const LOOM_PAGES: Array = [
	{
		"title": "星核织机",
		"body": "织机以星核为梭，把全城命脉织进经线。\n打停两节点→打暴露核心；核心受创换相。",
		"key": "异相 J 打节点 · 核心换相",
		"demo": "loom_nodes",
	},
	{
		"title": "城垣的护持",
		"body": "城内星核护你三次；3 次受击才失败。\n阶段 1 结束补一次；失败从当前阶段重开。\n齿轮跳过，浮灵用 J 清。",
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
