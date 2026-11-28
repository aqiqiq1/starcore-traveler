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
## Page 1 is the world/goal page; page 2 explains the separate three-cell
## health meter, the one-time stage-1 refill, the current-stage retry and the
## gear/wisp answers in one page.  This removes the old entry/core teaching
## popups: every instruction now has exactly one home in a run.

## Copy source: dlc/UI_PARITY_SPEC.md section 3 (星核织机), with the key rows
## rewritten as natural sentences per dlc/REWORK2_20261126.md.  Every body line
## stays within 21 full-width characters; ASCII and digits count as half-width.
## Widths are recorded in tests/README.md.
const LOOM_PAGES: Array = [
	{
		"title": "星核织机",
		"body": "入口青核供第二道月门；同相推、异相拉。\n织机以星核为梭，把全城命脉织进经线。\n打停两节点→打暴露核心；核心受创换相。",
		"key": "先送青核入仓，再看相位打节点与核心。",
		"demo": "loom_nodes",
	},
	{
		"title": "城垣的护持",
		"body": "生命值三格，每受击掉一格；三格耗尽折一命。\n阶段 1 结束补满；失败从当前阶段重开。\n齿轮跳过，浮灵用攻击清。",
		"key": "跳过齿轮，用攻击清掉浮灵。",
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
	# The base open_guide() plays the shared 0.18 s reveal; this override must
	# too, otherwise the panel stays at its closed +5 px offset and the dimmer
	# never fades in (the page would sit 5 px lower than the rift guide).
	if _reveal != null:
		_reveal.play_open()
	_clean_player_input()
	opened.emit(guide_kind)
	return true
