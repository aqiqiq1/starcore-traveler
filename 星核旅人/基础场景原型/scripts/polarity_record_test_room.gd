class_name PolarityRecordTestRoom
extends StarCoreInteractionRoom

## Focused sandbox for the approved bay-record -> rune-stone linkage.
##
## It reuses the existing interaction room mechanics unchanged (100 px transport,
## explicit E store, opposite-player release snapshot) and adds:
##   - one start bay with the preloaded purple core and no history;
##   - one linked bay that records the active core's own polarity on E store;
##   - one real RuneStoneField that only affects the player;
##   - a BayRuneLink that lights the record lamp immediately, runs the existing
##     pulse, then requests the field's visual change; actual force flips only
##     after that visual finishes;
##   - R resets record, pulse/transition and the field to its initial polarity.
##
## There is no door, target gate, formal puzzle, extra core, or auto capture.

@onready var _link: BayRuneLink = $LinkController
@onready var _rune_field: RuneStoneField = $RuneField
@onready var _linked_bay: StarCoreBayInteractable = $Bays/TargetBay

var _last_debug_enabled: bool = false


func _ready() -> void:
	super._ready()
	if _link != null:
		_link.reset_link()
	_update_record_hud()


func activate(player: PrototypePlayer, hud: PrototypeHUD) -> void:
	super.activate(player, hud)
	if _link != null:
		add_player_force_provider(_link)
	if _hud != null:
		_hud.set_interaction_navigation(
			"F7: MAIN   R: RESET RECORD/STONE   ESC: PAUSE   F3: RANGE/FORCE"
		)
		_hud.set_interaction_tips(
			"F7: MAIN   R: RESET RECORD   F3: RANGE/FORCE   ESC: PAUSE"
		)
		_hud.set_record_link_visible(true)
	_update_record_hud()


func deactivate() -> void:
	if _link != null:
		remove_player_force_provider(_link)
		# Leaving the room abandons any in-flight pulse/transition, so no old
		# request can land while another room or the main scene is active.
		_link.reset_link()
	if _hud != null:
		_hud.set_record_link_visible(false)
	super.deactivate()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_active() or _player == null:
		return
	var debug_enabled: bool = _player.is_debug_enabled()
	if debug_enabled != _last_debug_enabled and _rune_field != null:
		_last_debug_enabled = debug_enabled
		_rune_field.set_debug_enabled(debug_enabled)
	_update_record_hud()


func _reset_room_state() -> void:
	super._reset_room_state()
	if _link != null:
		_link.reset_link()
	_update_record_hud()


## This sandbox is not a formal target puzzle: a store in the linked bay is the
## record event, not a completion banner. The base room keeps its original
## success behavior.
func _on_core_stored_in_bay(bay: StarCoreBayInteractable, core_positive: bool) -> void:
	_success = false
	if _hud == null:
		return
	_hud.set_interaction_success(false)
	var polarity_text: String = "GOLD +" if core_positive else "CYAN -"
	if bay == _linked_bay:
		_hud.show_toast("RECORDED %s - STONE UPDATES AFTER PULSE" % polarity_text)
	else:
		_hud.show_toast("STORED %s IN START BAY - NO STONE LINK" % polarity_text)


func _update_record_hud() -> void:
	if _hud == null or _link == null or _linked_bay == null:
		return
	var lamp_text: String = "NEUTRAL"
	if _link.get_link_visual() != null and _link.get_link_visual().is_record_available():
		lamp_text = "GOLD +" if _link.get_record_positive() else "CYAN -"
	var extra_status: String = get_last_extra_status()
	if _rune_field != null and not _rune_field.is_activated():
		extra_status = RuneStoneField.STATUS_INACTIVE
	elif extra_status.is_empty():
		extra_status = "IDLE"
	var force_text: String = "F(%+.0f,%+.0f)" % [
		get_last_extra_player_force().x, get_last_extra_player_force().y
	]
	_hud.set_record_link_state(
		"BAY: %s   LAMP: %s" % [_linked_bay.get_record_label(), lamp_text],
		"STONE: %s   FIELD: %s   %s" % [
			_link.get_field_label(), extra_status, force_text
		],
		"STAGE: %s   R: CLEAR RECORD / RESET" % _link.get_link_stage_label()
	)


func get_link() -> BayRuneLink:
	return _link


func get_linked_bay() -> StarCoreBayInteractable:
	return _linked_bay


func get_rune_field() -> RuneStoneField:
	return _rune_field
