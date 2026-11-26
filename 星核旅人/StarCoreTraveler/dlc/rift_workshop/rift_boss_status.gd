class_name RiftBossStatus
extends HudBossBar

## Mirror-boss adapter over the shared HudBossBar.  It keeps the old
## set_state / set_anchor_state signatures used by rift_workshop.gd and the
## existing tests, but draws the same 360x16 bar as every other chapter:
## name 双面镜, red core fill, two face plates, three core diamonds, three
## phase cells.  There is no separate 340x28 panel or 10 px status text.

const BOSS_NAME: String = "双面镜"
const MAX_PHASES: int = 3
const CORE_HITS_PER_PHASE: int = 3


func _ready() -> void:
	super._ready()
	boss_name = BOSS_NAME
	_core_max = CORE_HITS_PER_PHASE
	_phase_count = MAX_PHASES
	set_faces(_gold_intact, _cyan_intact, _exposed, true)
	set_bar_values(_core_current, _core_max, _phase_index, _phase_count)
	queue_redraw()


func set_state(
	phase_index: int, phase_count: int, core_hp: int, max_core: int,
	gold_intact: bool, cyan_intact: bool, exposed: bool
) -> void:
	var clamped_phase: int = clampi(phase_index, 0, maxi(phase_count - 1, 0))
	var clamped_core: int = clampi(core_hp, 0, maxi(max_core, 1))
	_gold_intact = gold_intact
	_cyan_intact = cyan_intact
	_exposed = exposed
	set_bar_values(
		clamped_core, maxi(max_core, 1), clamped_phase, maxi(phase_count, 1),
		float(clamped_core) / float(maxi(max_core, 1))
	)
	set_faces(_gold_intact, _cyan_intact, _exposed, true)


func set_anchor_state(
	gold_anchored: bool, cyan_anchored: bool,
	gold_window: float, cyan_window: float
) -> void:
	super.set_anchor_state(gold_anchored, cyan_anchored, gold_window, cyan_window)


func get_max_core_hits() -> int:
	return _core_max


func get_form_text() -> String:
	return "形态 %d/%d" % [_phase_index + 1, _phase_count]
