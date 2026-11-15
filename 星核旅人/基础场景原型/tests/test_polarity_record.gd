extends Node

## Acceptance test for the real bay-record -> rune-stone link test room.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_polarity_record.tscn
##
## The first full scenario uses real InputMap actions and 60 Hz physics for
## release -> walk -> E store -> pulse -> field transition. Later edge cases use
## direct placement for the specific state under test, as the existing
## interaction suite does. No assertion is based on a canned PASS.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const STANDALONE_SCENE: PackedScene = preload("res://scenes/polarity_record_test_room_standalone.tscn")
const NEUTRAL_COLOR: Color = Color("#7f938f")

var _standalone: Node2D
var _room: PolarityRecordTestRoom
var _player: PrototypePlayer
var _hud: PrototypeHUD
var _link: BayRuneLink
var _field: RuneStoneField
var _linked_bay: StarCoreBayInteractable

var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0
var _log_lines: Array[String] = []
var _record_events: Array[bool] = []
var _pulse_events: Array[bool] = []
var _field_commit_events: Array[bool] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("Star Core Traveler - bay record / rune link test")
	_log("Godot %s  display=%s  physics=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
		str(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")),
	])

	_test_environment()
	await _boot_standalone()
	await _test_initial_state()
	await _test_empty_bay_has_no_fake_record()
	await _test_record_is_bay_specific()
	await _test_full_release_walk_store_and_force_flip()
	await _test_takeout_keeps_record()
	await _test_overwrite_then_reset_mid_transition()
	await _test_new_record_supersedes_first_light_up()
	await _test_same_polarity_record_is_valid()
	await _test_first_activation_same_as_initial_default()
	await _test_pause_freezes_link_pulse()
	await _test_reset_mid_pulse()
	await _test_combined_forces_do_not_overwrite()
	await _test_no_auto_store_long_e_and_unique_core()
	await _test_room_exit_clears_in_flight()
	await _test_main_entry_and_standalone_reentry()
	_finish()


func _test_environment() -> void:
	_section("ENVIRONMENT / INPUT")
	_check(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
		"logic viewport stays 640x360"
	)
	_check(
		String(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/main.tscn",
		"default main scene remains main.tscn"
	)
	_check(_action_has_key(&"toggle_record_room", KEY_F7), "F7 is bound for the record test room")
	_check(_action_has_key(&"toggle_anchor_room", KEY_F2), "F2 remains bound")
	_check(_action_has_key(&"toggle_interaction_room", KEY_F4), "F4 remains bound")
	_check(_action_has_key(&"interact", KEY_E), "E remains bound")
	_check(_action_has_key(&"polarity", KEY_Q), "Q remains bound")
	_check(
		ResourceLoader.exists("res://scenes/polarity_record_test_room.tscn")
		and ResourceLoader.exists("res://scenes/rune_stone_field.tscn"),
		"test room and rune field scenes are present"
	)


func _boot_standalone() -> void:
	_standalone = STANDALONE_SCENE.instantiate() as Node2D
	add_child(_standalone)
	await get_tree().process_frame
	await get_tree().process_frame
	_room = _standalone.get_room() as PolarityRecordTestRoom
	_player = _standalone.get_player() as PrototypePlayer
	_hud = _standalone.get_hud() as PrototypeHUD
	_link = _room.get_link()
	_field = _room.get_rune_field()
	_linked_bay = _room.get_linked_bay()
	_linked_bay.polarity_recorded.connect(_on_bay_recorded)
	_link.pulse_started.connect(_on_pulse_started)
	_link.field_committed.connect(_on_field_committed)


func _test_initial_state() -> void:
	_section("INITIAL STATE / NO INVENTED HISTORY")
	_check(_room != null and _room.is_active(), "standalone wrapper activates the record room")
	_check(_room.visible and _link != null and _field != null,
		"record room, link controller and rune field are visible/resolved")
	_check(_linked_bay != null and _linked_bay.bay_name == "LINKED",
		"target bay is the linked record bay")
	_check(_linked_bay.is_open_empty() and not _linked_bay.has_core(),
		"linked bay begins OPEN/EMPTY")
	_check(not _linked_bay.has_record(), "linked bay begins with NO record")
	_check(_linked_bay.get_record_label() == "NO RECORD", "empty record label is explicit")
	var start: StarCoreBayInteractable = _room.get_start_bay()
	_check(start.is_locked() and start.has_core(), "start bay begins LOCKED with the preloaded core")
	_check(not start.has_record(), "the preloaded purple core is not counted as history")
	_check(_room.get_core().is_active() == false, "moving core begins disabled")
	_check(_count_cores() == 1, "room owns exactly one core", str(_count_cores()))
	_check(not _field.is_activated(), "rune field begins INACTIVE")
	_check(_field.is_positive(), "dormant field keeps its internal GOLD + default")
	_check(_field.get_visual() != null and not _field.get_visual().is_energized(),
		"rune visual begins dormant with dark cracks")
	_check(_field.get_visual().get_hint_kind() == &"none",
		"dormant rune visual offers no +/- hint")
	_check(not _field.get_visual().should_draw_polarity_hint(),
		"dormant rune visual draws no near hint")
	var dormant_sample: Dictionary = _field.sample_field(Vector2(450.0, 305.0), true)
	_check(String(dormant_sample["status"]) == "INACTIVE",
		"initial in-range field sample is INACTIVE", String(dormant_sample["status"]))
	_check(dormant_sample["acceleration"] == Vector2.ZERO,
		"initial inactive field force is exactly zero")
	_check(not _link.has_pending_pulse() and not _link.is_field_pending(),
		"link begins with no pulse or field request")
	var visual: PolarityLinkVisual = _link.get_link_visual()
	_check(visual != null and not visual.is_transfer_active(), "link visual begins idle")
	_check(not visual.is_record_available(), "record lamp begins neutral/unavailable")
	_check(visual.get_record_lamp_accent_color() == NEUTRAL_COLOR,
		"neutral lamp does not fake a gold record", str(visual.get_record_lamp_accent_color()))
	_check(visual.get_record_symbol() == &"none", "neutral lamp has no plus/minus symbol")
	_check(_link.get_record_label() == "NO RECORD", "link reports no record")
	_check(_hud.is_record_link_visible(), "record/link HUD panel is visible")
	_check(_hud.get_record_link_bay_text().contains("NO RECORD"),
		"HUD starts with NO RECORD", _hud.get_record_link_bay_text())
	_check(_hud.get_record_link_stage_text().contains("NO RECORD"),
		"HUD stage starts with NO RECORD", _hud.get_record_link_stage_text())
	_check(_hud.get_record_link_stone_text().contains("INACTIVE"),
		"HUD names the dormant stone INACTIVE, not a fake GOLD +",
		_hud.get_record_link_stone_text())
	_check(not _hud.get_record_link_stone_text().contains("GOLD"),
		"HUD does not present the dormant internal default as live GOLD")
	_check(_link.get_field_label() == "INACTIVE",
		"link field label is INACTIVE while dormant", _link.get_field_label())
	_check(_room.get_player_force_provider_count() == 1,
		"rune link is registered once as the extra player-force provider")
	_check(_player.is_positive(), "player starts GOLD +")
	_check(_player.global_position.distance_to(_room.get_spawn_position()) < 1.0,
		"player starts at the room spawn", str(_player.global_position))


func _test_empty_bay_has_no_fake_record() -> void:
	_section("EMPTY E / NO FAKE RECORD")
	var before: int = _record_events.size()
	_player.global_position = Vector2(340.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(2)
	_check(_hud.get_interaction_e_text().contains("NO CORE TO STORE (LINKED)"),
		"empty linked bay E preview explains there is no core", _hud.get_interaction_e_text())
	await _tap_action(&"interact")
	await _step(2)
	_check(not _linked_bay.has_record(), "invalid E never records")
	_check(not _linked_bay.has_core(), "invalid E never stores")
	_check(_record_events.size() == before, "invalid E emits no record signal")
	_check(_link.get_link_visual().get_record_lamp_accent_color() == NEUTRAL_COLOR,
		"lamp stays neutral after invalid E")


func _test_record_is_bay_specific() -> void:
	_section("RECORD BELONGS TO THE STORED-IN BAY")
	await _reset_via_input()
	# Isolated setup: open the start bay and put an active CYAN core in its seat.
	# The player stands at the start, not at the linked bay.
	var start: StarCoreBayInteractable = _room.get_start_bay()
	start.reset_empty()
	_player.global_position = Vector2(100.0, 320.0)
	_player.velocity = Vector2.ZERO
	_room.get_core().activate_at(start.get_store_center(), false)
	_room.get_core().ignore_body(_player)
	await _step(1)
	_check(_hud.get_interaction_e_text().contains("STORE CORE (START)"),
		"E is offered at the start bay seat", _hud.get_interaction_e_text())
	await _tap_action(&"interact")
	await _step(1)
	_check(start.has_record() and not start.get_recorded_positive(),
		"start bay records the CYAN core in its own data slot")
	_check(not _linked_bay.has_record(), "linked bay does not inherit another bay's record")
	_check(not _link.has_pending_pulse() and not _link.get_link_visual().is_record_available(),
		"a store in the unlinked start bay neither pulses nor lights the linked lamp")
	_check(not _field.is_activated(), "unlinked start-bay storage does not activate the stone")
	_check(String(_field.sample_field(Vector2(450.0, 305.0), true)["status"]) == "INACTIVE",
		"unlinked storage leaves the dormant stone at zero force")
	await _tap_action(&"reset")
	await _step(8)
	_check(not start.has_record() and not _linked_bay.has_record(),
		"R clears the bay-specific start record too")


func _test_full_release_walk_store_and_force_flip() -> void:
	_section("FULL FLOW: RELEASE -> WALK -> E STORE -> PULSE -> REAL FORCE FLIP")
	await _reset_via_input()
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(2)
	_check(_room.get_pending_release() and not _room.get_pending_positive(),
		"GOLD player release snapshots CYAN - for the core")
	_check(_hud.get_toast_text().contains("CYAN -"),
		"release toast names the core snapshot", _hud.get_toast_text())
	# Q during opening must not change the release snapshot.
	await _tap_action(&"polarity")
	_check(not _player.is_positive(), "Q during opening changes only the player")
	_check(not _room.get_pending_positive(), "Q during opening leaves the core snapshot CYAN -")
	await _step(20)
	_check(_room.get_core().is_active(), "core activates after the lid opens")
	_check(not _room.get_core().is_positive(), "released core keeps its CYAN - snapshot")
	await _set_player_polarity(true)
	_check(_player.is_positive(), "player returns to GOLD + for transport")

	await _walk_to_x(338.0)
	await _wait_until(
		func() -> bool:
			return (
				_linked_bay.is_core_in_store_zone(_room.get_core().global_position)
				and _hud.get_interaction_e_text().contains("STORE CORE (LINKED)")
			),
		150
	)
	var bay_record_before: bool = _linked_bay.has_record()
	var record_count_before: int = _record_events.size()
	_check(_player.is_positive() and not _room.get_core().is_positive(),
		"at store time the player is GOLD and the core is CYAN")
	_check(not bay_record_before, "walking over the empty bay does not auto-record")
	_check(_linked_bay.is_core_in_store_zone(_room.get_core().global_position),
		"core is inside the linked bay seat", str(_room.get_core().global_position))
	_check(_hud.get_interaction_e_text().contains("STORE CORE (LINKED)"),
		"HUD offers manual E store", _hud.get_interaction_e_text())

	await _tap_action(&"interact")
	await _step(1)
	_check(_linked_bay.is_closing() and _linked_bay.has_core(),
		"manual E starts closing and locks the core")
	_check(_linked_bay.has_record() and not _linked_bay.get_recorded_positive(),
		"record captures the CORE's CYAN -, not the GOLD player or purple display")
	_check(_record_events.size() == record_count_before + 1 and not _record_events[-1],
		"valid E emits exactly one CYAN record event")
	var visual: PolarityLinkVisual = _link.get_link_visual()
	_check(visual.is_record_available() and not visual.record_positive,
		"record lamp is immediately CYAN at store acceptance")
	_check(visual.is_transfer_active() and _link.has_pending_pulse(),
		"the existing pulse starts after the record lamp update")
	_check(not _field.is_activated(), "field stays INACTIVE during the pulse")
	_check(_field.is_positive(), "dormant field keeps its internal GOLD + default")
	var pulse_sample: Dictionary = _field.sample_field(Vector2(450.0, 305.0), true)
	_check(String(pulse_sample["status"]) == "INACTIVE",
		"pulse-time sample is INACTIVE", String(pulse_sample["status"]))
	_check(pulse_sample["acceleration"] == Vector2.ZERO,
		"pulse-time field force is exactly zero")
	_check(_hud.get_record_link_bay_text().contains("CYAN -")
		and _hud.get_record_link_stage_text().contains("PULSE")
		and _hud.get_record_link_stone_text().contains("INACTIVE"),
		"HUD shows the real record, pulse and INACTIVE stone",
		"%s | %s | %s" % [
			_hud.get_record_link_bay_text(),
			_hud.get_record_link_stage_text(),
			_hud.get_record_link_stone_text(),
		])
	# Q while the lid closes must not alter the already captured record.
	await _tap_action(&"polarity")
	_check(not _player.is_positive(), "Q during store closing changes the player")
	_check(_linked_bay.has_record() and not _linked_bay.get_recorded_positive(),
		"Q during store closing leaves the record CYAN -")
	_check(not visual.record_positive, "Q during store closing leaves the lamp CYAN -")
	await _set_player_polarity(true)

	var dormant_drift: Dictionary = await _force_drift(450.0, 6)
	_check(String(dormant_drift["status"]) == "INACTIVE",
		"pre-activation force sample is INACTIVE", String(dormant_drift["status"]))
	_check((dormant_drift["force"] as Vector2) == Vector2.ZERO,
		"pre-activation force sample is exactly zero", str(dormant_drift["force"]))
	_check(absf(float(dormant_drift["dx"])) < 0.1,
		"dormant stone does not move the player", "dx=%.2f" % float(dormant_drift["dx"]))

	var commits_before_light: int = _field_commit_events.size()
	await _wait_until(
		func() -> bool:
			return not _link.has_pending_pulse() and _link.is_field_pending(),
		90
	)
	_check(not _field.is_activated() and _field.is_transitioning(),
		"pulse arrival starts a dark-to-colour light-up, not an early activation")
	_check(_field.get_visual().is_energized(),
		"the first light-up has energized the visual target")
	var lighting_sample: Dictionary = _field.sample_field(Vector2(450.0, 305.0), true)
	_check(String(lighting_sample["status"]) == "INACTIVE",
		"field is still INACTIVE during the first light-up", String(lighting_sample["status"]))
	_check(lighting_sample["acceleration"] == Vector2.ZERO,
		"field force is still exactly zero during the first light-up")
	_check(_field_commit_events.size() == commits_before_light,
		"no field commit is emitted before the light-up finishes")
	await _wait_committed(false)
	_check(_field.is_activated(), "field becomes active when the first light-up finishes")
	_check(not _field.is_positive(), "field commits CYAN - only after its visual finishes")
	_check(not _field.is_transitioning(), "field transition is complete")
	_check(_link.get_link_stage_label().contains("LIVE"), "link reports the stone live",
		_link.get_link_stage_label())

	var new_drift: Dictionary = await _force_drift(450.0, 6)
	_check(String(new_drift["status"]) == "ATTRACT",
		"new CYAN field + GOLD player reports ATTRACT", String(new_drift["status"]))
	_check((new_drift["force"] as Vector2).x > 100.0,
		"new field force points right", str(new_drift["force"]))
	_check(float(new_drift["dx"]) > 0.5,
		"real physics moves the player right under the new field", "dx=%.2f" % float(new_drift["dx"]))
	_check(_field.get_visual().should_draw_polarity_hint(),
		"activated in-range stone now draws the +/- hint")
	_check(_linked_bay.has_record() and not _linked_bay.get_recorded_positive(),
		"record persists after the pulse and field commit")
	await _wait_until(func() -> bool: return _linked_bay.is_locked(), 40)
	_check(_linked_bay.is_locked() and _linked_bay.get_visual().is_lid_closed(),
		"linked bay finishes LOCKED with the lid closed")
	_check(_count_cores() == 1, "full flow keeps exactly one core")


func _test_takeout_keeps_record() -> void:
	_section("TAKEOUT KEEPS RECORD AND STONE")
	var record_count_before: int = _record_events.size()
	_player.global_position = Vector2(340.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(2)
	await _set_player_polarity(false)
	_check(_hud.get_interaction_e_text().contains("RELEASE"),
		"loaded linked bay offers E release", _hud.get_interaction_e_text())
	await _tap_action(&"interact")
	await _step(2)
	_check(_room.get_pending_release() and _room.get_pending_positive(),
		"CYAN player releasing snapshots GOLD + for the new core")
	_check(_linked_bay.has_record() and not _linked_bay.get_recorded_positive(),
		"release does not clear the CYAN record")
	await _step(20)
	_check(_room.get_core().is_active() and _room.get_core().is_positive(),
		"core re-releases as GOLD +")
	_check(_linked_bay.is_open_empty(), "linked bay is empty/open after release")
	_check(_linked_bay.has_record() and _linked_bay.get_record_label() == "CYAN -",
		"linked bay keeps the most recent CYAN record")
	_check(_field.is_activated() and _field.is_positive() == false,
		"rune stone stays active CYAN after takeout")
	_check(_link.get_link_visual().record_positive == false
		and _link.get_link_visual().is_record_available(),
		"record lamp stays CYAN after takeout")
	_check(_record_events.size() == record_count_before,
		"takeout emits no new record event")
	_check(not _link.has_pending_pulse(), "takeout starts no pulse")


func _test_overwrite_then_reset_mid_transition() -> void:
	_section("OVERWRITE + R DURING FIELD TRANSITION")
	# The active core is GOLD from the takeout above and the player is CYAN.
	# Place the real active core in the seat, then use a normal E store.
	_room.get_core().global_position = _linked_bay.get_store_center()
	_room.get_core().velocity = Vector2.ZERO
	await _step(1)
	_check(_hud.get_interaction_e_text().contains("STORE CORE (LINKED)"),
		"different-polarity core is eligible at the linked seat", _hud.get_interaction_e_text())
	var record_count_before: int = _record_events.size()
	await _tap_action(&"interact")
	await _step(1)
	_check(_linked_bay.has_record() and _linked_bay.get_recorded_positive(),
		"second store overwrites the record with the core's GOLD +")
	_check(_record_events.size() == record_count_before + 1 and _record_events[-1],
		"overwrite emits one GOLD record event")
	_check(_link.get_link_visual().record_positive,
		"lamp changes to GOLD immediately at overwrite")
	_check(_field.is_positive() == false, "field is still CYAN during the new pulse")
	_check(_link.has_pending_pulse(), "overwrite starts a new pulse")

	await _wait_until(
		func() -> bool:
			return not _link.has_pending_pulse() and _link.is_field_pending(),
		90
	)
	_check(_field.is_transitioning() and not _field.is_positive(),
		"field is mid-transition from CYAN to GOLD when R is pressed")
	await _tap_action(&"reset")
	await _step(8)
	_check(_player.global_position.distance_to(_room.get_spawn_position()) < 1.0,
		"R returns to spawn")
	_check(_player.is_positive(), "R restores player GOLD +")
	_check(_room.get_start_bay().is_locked() and _room.get_start_bay().has_core(),
		"R restores the start bay with the preloaded core")
	_check(not _room.get_start_bay().has_record(), "R clears the start bay record")
	_check(_linked_bay.is_open_empty() and not _linked_bay.has_record(),
		"R restores linked bay OPEN/EMPTY and clears its record")
	_check(not _field.is_activated() and not _field.is_transitioning(),
		"R immediately restores the field to INACTIVE")
	_check(_field.is_positive(), "R restores the dormant internal GOLD + default")
	_check(not _field.get_visual().is_energized(),
		"R returns the visual to dark cracks")
	_check(_field.get_visual().get_applied_positive(),
		"R restores the dormant visual's internal GOLD target")
	_check(not _link.has_pending_pulse() and not _link.is_field_pending(),
		"R clears in-flight pulse and field request")
	_check(_link.get_link_stage_label() == "NO RECORD", "R clears the link stage")
	_check(not _link.get_link_visual().is_record_available(),
		"R returns the lamp to neutral/no record")
	var commits_after_reset: int = _field_commit_events.size()
	await _step(120)
	_check(not _field.is_activated() and not _field.is_transitioning(),
		"no stale field activation lands after R")
	_check(_field_commit_events.size() == commits_after_reset,
		"R emits no delayed field commit")
	_check(_linked_bay.has_record() == false, "record does not reappear after waiting")


func _test_new_record_supersedes_first_light_up() -> void:
	_section("NEWER RECORD CANCELS AN OLD FIRST LIGHT-UP")
	await _reset_via_input()
	await _direct_store(false, true)
	await _wait_until(
		func() -> bool:
			return not _link.has_pending_pulse() and _link.is_field_pending(),
		90
	)
	_check(not _field.is_activated() and _field.is_transitioning(),
		"setup is mid first light-up toward CYAN")
	var commits_before: int = _field_commit_events.size()
	# Simulate the next accepted record arriving while the previous first
	# light-up is still in flight. The real bay cannot reopen that quickly, so
	# the timing is injected directly; all field/link reactions are real.
	_link.call("_on_bay_polarity_recorded", true)
	_check(not _field.is_activated() and not _field.is_transitioning(),
		"newer record cancels the older first light-up before it activates")
	_check(not _link.is_field_pending(), "newer record clears the older field request")
	_check(_link.has_pending_pulse(), "newer record starts its own pulse")
	_check(_link.get_link_visual().record_positive,
		"newer record updates the lamp immediately to GOLD")
	_field.get_visual().transition_finished.emit(false)
	_check(not _field.is_activated(),
		"late completion from the cancelled light-up cannot activate the stone")
	_check(_field_commit_events.size() == commits_before,
		"late completion from the cancelled light-up emits no commit")
	await _wait_until(
		func() -> bool:
			return not _link.has_pending_pulse() and _link.is_field_pending(),
		90
	)
	_check(not _field.is_activated() and _field.is_transitioning(),
		"newer record's pulse starts a fresh first light-up")
	await _wait_committed(true)
	_check(_field.is_activated() and _field.is_positive(),
		"newest record wins and activates the stone GOLD")
	_check(_field_commit_events.size() == commits_before + 1,
		"only the newest record causes one final activation commit",
		str(_field_commit_events.size() - commits_before))


func _test_same_polarity_record_is_valid() -> void:
	_section("SAME-POLARITY STORE IS A VALID RECORD")
	await _reset_via_input()
	await _direct_store(true, true)
	await _wait_committed(true)
	_check(_linked_bay.has_record() and _linked_bay.get_recorded_positive(),
		"setup records GOLD +")
	# Take out with a CYAN player -> GOLD core, then store it again as GOLD.
	await _release_linked(false)
	_room.get_core().global_position = _linked_bay.get_store_center()
	_room.get_core().velocity = Vector2.ZERO
	await _step(1)
	var before: int = _record_events.size()
	await _tap_action(&"interact")
	await _step(1)
	_check(_linked_bay.has_record() and _linked_bay.get_recorded_positive(),
		"same GOLD store keeps a valid GOLD record")
	_check(_record_events.size() == before + 1 and _record_events[-1],
		"same-polarity store still emits one record event")
	_check(_link.get_link_visual().record_positive and _link.has_pending_pulse(),
		"same-polarity store still updates the lamp and plays the pulse")
	_check(_field.is_activated() and _field.is_positive(),
		"same-polarity request does not change the live GOLD field")
	await _step(3)
	_check(not _link.is_field_pending(),
		"same-polarity request settles without a stuck transition")
	await _wait_until(func() -> bool: return not _link.has_pending_pulse(), 90)
	_check(_link.get_link_stage_label().contains("LIVE"), "same-polarity link returns to LIVE")
	_check(_field.is_activated() and _field.is_positive() and not _field.is_transitioning(),
		"same-polarity field stays active GOLD and idle")


func _test_first_activation_same_as_initial_default() -> void:
	_section("FIRST STORE EQUAL TO INITIAL DEFAULT STILL ACTIVATES")
	await _reset_via_input()
	_check(not _field.is_activated(), "setup begins with a dormant stone")
	_check(_field.is_positive(), "dormant internal default is GOLD +")
	var commits_before: int = _field_commit_events.size()
	await _direct_store(true, true)
	_check(_linked_bay.has_record() and _linked_bay.get_recorded_positive(),
		"GOLD core is recorded immediately")
	_check(_link.get_link_visual().record_positive and _link.has_pending_pulse(),
		"lamp and pulse react even though the target equals the internal default")
	_check(not _field.is_activated(), "same-as-default store does not activate early")
	_check(String(_field.sample_field(Vector2(450.0, 305.0), false)["status"]) == "INACTIVE",
		"same-as-default store has zero field force during the pulse")
	await _wait_until(
		func() -> bool:
			return not _link.has_pending_pulse() and _link.is_field_pending(),
		90
	)
	_check(not _field.is_activated() and _field.is_transitioning(),
		"pulse arrival starts the first light-up for the default-colour target")
	_check(_link.is_field_pending(),
		"link does not settle merely because the dormant internal sign matches")
	_check(_field_commit_events.size() == commits_before,
		"no commit is emitted before the same-as-default light-up finishes")
	_check(String(_field.sample_field(Vector2(450.0, 305.0), false)["status"]) == "INACTIVE",
		"force is still zero while the same-colour target lights up")
	await _wait_committed(true)
	_check(_field.is_activated() and _field.is_positive(),
		"same-as-default first store finishes as an active GOLD stone")
	_check(_field_commit_events.size() == commits_before + 1,
		"same-as-default first store emits one final commit",
		str(_field_commit_events.size() - commits_before))
	_check(not _link.is_field_pending() and _link.get_link_stage_label().contains("LIVE"),
		"link settles only after the real commit")
	_check(String(_field.sample_field(Vector2(450.0, 305.0), true)["status"]) == "REPEL",
		"activated GOLD field repels a GOLD player")
	_check(String(_field.sample_field(Vector2(450.0, 305.0), false)["status"]) == "ATTRACT",
		"activated GOLD field attracts a CYAN player")


func _test_pause_freezes_link_pulse() -> void:
	_section("PAUSE FREEZES THE LINK PULSE")
	await _reset_via_input()
	await _direct_store(false, true)
	var visual: PolarityLinkVisual = _link.get_link_visual()
	await _step(5)
	var progress_before: float = visual.get_transfer_progress()
	_check(progress_before > 0.0 and progress_before < 1.0,
		"pulse is in flight before pause", "%.2f" % progress_before)
	await _tap_process_action(&"pause")
	_check(get_tree().paused, "Esc pauses the tree")
	await _step(20)
	_check(is_equal_approx(visual.get_transfer_progress(), progress_before),
		"pulse progress is frozen while paused")
	_check(_link.has_pending_pulse() and not _field.is_activated(),
		"pause does not deliver the request or activate the dormant field")
	await _tap_process_action(&"pause")
	_check(not get_tree().paused, "Esc resumes the tree")
	await _wait_committed(false)
	_check(not _link.has_pending_pulse() and not _field.is_positive() and _field.is_activated(),
		"pulse completes and the first light-up commits after resume")


func _test_reset_mid_pulse() -> void:
	_section("R DURING PULSE CLEARS EVERYTHING")
	await _reset_via_input()
	await _direct_store(false, true)
	await _step(5)
	_check(_link.has_pending_pulse(), "pulse is active before R")
	var commits_before: int = _field_commit_events.size()
	await _tap_action(&"reset")
	await _step(8)
	_check(not _link.has_pending_pulse() and not _link.get_link_visual().is_transfer_active(),
		"R stops the in-flight visual pulse")
	_check(not _linked_bay.has_record() and not _room.get_start_bay().has_record(),
		"R clears both bay records")
	_check(not _field.is_activated() and not _field.is_transitioning(),
		"R restores the field to INACTIVE")
	_check(not _field.get_visual().is_energized(),
		"R returns the visual to dark cracks after an interrupted pulse")
	await _step(120)
	_check(_field_commit_events.size() == commits_before,
		"no stale field request lands after R")
	_check(not _field.is_activated() and not _linked_bay.has_record(),
		"room stays clean and dormant after waiting")


func _test_combined_forces_do_not_overwrite() -> void:
	_section("CORE FORCE + RUNE FORCE: ONE SUM, CORE UNAFFECTED BY RUNE")
	await _reset_via_input()
	# Activate the STONE GOLD first, then release a CYAN core from the bay so
	# both the live stone and the player-core pair contribute in this sample.
	await _direct_store(true, true)
	await _wait_committed(true)
	_check(_field.is_activated() and _field.is_positive(),
		"combined-force setup has a live GOLD rune stone")
	await _release_linked(true)
	_check(_room.get_core().is_active() and not _room.get_core().is_positive(),
		"combined-force setup has a CYAN core")
	_check(_player.is_positive(), "combined-force setup keeps the player GOLD")
	_player.global_position = Vector2(420.0, 320.0)
	_player.velocity = Vector2.ZERO
	_room.get_core().global_position = Vector2(480.0, 312.0)
	_room.get_core().velocity = Vector2.ZERO
	await _step(1)
	var pair_player: Vector2 = _room.get_last_core_player_force()
	var rune_player: Vector2 = _room.get_last_extra_player_force()
	var combined: Vector2 = _room.get_last_player_force()
	_check(String(_room.get_last_extra_status()) == "REPEL",
		"rune field reports its own REPEL for the GOLD player",
		_room.get_last_extra_status())
	_check(pair_player.x > 0.0, "core pair pulls the player toward the CYAN core", str(pair_player))
	_check(rune_player.x < 0.0, "rune stone pushes the GOLD player away", str(rune_player))
	_check(combined.is_equal_approx(pair_player + rune_player),
		"combined player force is the exact sum, not a later overwrite",
		"pair=%s rune=%s combined=%s" % [str(pair_player), str(rune_player), str(combined)])
	var expected: Dictionary = _room.compute_field(
		Vector2(420.0, 305.0), Vector2(480.0, 312.0), true, false
	)
	var expected_core: Vector2 = expected["core_acceleration"]
	expected_core.y = 0.0
	# The pair geometry can move a fraction of a pixel between the force sample
	# and this readback. Tolerance stays far below the 2400 px/s^2 rune force,
	# so a stone-to-core contribution would still fail loudly.
	_check((_room.get_last_force() - expected_core).length() < 2.0,
		"core acceleration still comes only from the player-core pair",
		"actual=%s expected=%s" % [str(_room.get_last_force()), str(expected_core)])
	var core_x_before: float = _room.get_core().global_position.x
	await _step(6)
	_check(_room.get_core().global_position.x < core_x_before - 0.5,
		"the rune stone does not hold the core back or pull it",
		"%.2f -> %.2f" % [core_x_before, _room.get_core().global_position.x])
	_check(_count_cores() == 1, "combined forces keep exactly one core")


func _test_no_auto_store_long_e_and_unique_core() -> void:
	_section("NO AUTO STORE / LONG E / UNIQUE CORE")
	await _reset_via_input()
	_player.global_position = Vector2(340.0, 320.0)
	_player.velocity = Vector2.ZERO
	_room.get_core().activate_at(_linked_bay.get_store_center(), false)
	_room.get_core().ignore_body(_player)
	await _step(8)
	_check(not _linked_bay.has_record() and _linked_bay.is_open_empty(),
		"core resting in an empty seat is never auto-stored/recorded")
	_check(not _link.has_pending_pulse(), "no pulse without an accepted E")
	# Out-of-seat E must not record.
	_room.get_core().global_position = _linked_bay.get_store_center() + Vector2(50.0, 0.0)
	await _step(1)
	await _tap_action(&"interact")
	await _step(1)
	_check(not _linked_bay.has_record(), "out-of-seat E does not record")
	# Long E through a valid store records exactly once.
	_room.get_core().global_position = _linked_bay.get_store_center()
	_room.get_core().velocity = Vector2.ZERO
	await _step(1)
	var before: int = _record_events.size()
	Input.action_press(&"interact")
	await _step(35)
	Input.action_release(&"interact")
	await _step(3)
	_check(_linked_bay.has_record() and not _linked_bay.get_recorded_positive(),
		"held E performs one valid store with the core's CYAN record")
	_check(_record_events.size() == before + 1,
		"held E emits exactly one record event", str(_record_events.size() - before))
	_check(_count_cores() == 1, "held E never duplicates the core")
	_check(_room.get_core().is_active() == false, "held E leaves the core stored, not duplicated")


func _test_room_exit_clears_in_flight() -> void:
	_section("ROOM EXIT CLEARS IN-FLIGHT WORK")
	await _reset_via_input()
	await _direct_store(false, true)
	await _step(4)
	_check(_link.has_pending_pulse(), "pulse active before exiting the room")
	_room.deactivate()
	await _step(2)
	_check(_link.get_link_visual().is_transfer_active() == false,
		"room exit stops the link pulse")
	_check(not _link.has_pending_pulse() and not _link.is_field_pending(),
		"room exit clears pending link requests")
	_check(not _field.is_activated() and not _field.is_transitioning(),
		"room exit restores the field to INACTIVE")
	_check(not _field.get_visual().is_energized(),
		"room exit returns the rune visual to dark cracks")
	_check(_room.get_player_force_provider_count() == 0,
		"room exit unregisters the force provider")
	_check(not _player.is_anchor_force_pending() and _player.get_anchor_force_x() == 0.0,
		"room exit clears the player's external force")
	await _step(90)
	_check(not _field.is_activated(),
		"no stale field request activates the stone while the room is inactive")
	_room.activate(_player, _hud)
	await _step(3)
	_check(_room.is_active() and _room.get_player_force_provider_count() == 1,
		"re-entering the room re-registers the link once")
	_check(not _linked_bay.has_record() and not _field.is_activated(),
		"re-entering starts clean with no record and a dormant field")
	_check(_hud.is_record_link_visible(), "re-entry restores the record HUD panel")


func _test_main_entry_and_standalone_reentry() -> void:
	_section("F7 MAIN ENTRY / FRESH STANDALONE")
	_standalone.queue_free()
	_standalone = null
	await get_tree().process_frame
	await get_tree().physics_frame
	var main: PrototypeMain = MAIN_SCENE.instantiate() as PrototypeMain
	add_child(main)
	await get_tree().process_frame
	_check(main.get_hud().get_hint_text().contains("F7"),
		"basic HUD advertises the F7 record test", main.get_hud().get_hint_text())
	_check(main.get_player() != null, "main scene still loads normally with the F7 entry")
	main.queue_free()
	await get_tree().process_frame

	var fresh: Node2D = STANDALONE_SCENE.instantiate() as Node2D
	add_child(fresh)
	await get_tree().process_frame
	await get_tree().process_frame
	var room: PolarityRecordTestRoom = fresh.get_room() as PolarityRecordTestRoom
	_check(room != null and room.is_active(), "a fresh standalone entry activates")
	_check(room.get_start_bay().is_locked() and not room.get_start_bay().has_record(),
		"fresh entry has LOCKED start and no history")
	_check(room.get_linked_bay().is_open_empty() and not room.get_linked_bay().has_record(),
		"fresh entry has OPEN linked bay and no history")
	_check(not room.get_rune_field().is_activated(),
		"fresh entry restores the field to INACTIVE")
	_check(room.get_rune_field().is_positive(),
		"fresh dormant field keeps the internal GOLD + default")
	_check(room.get_rune_field().get_visual().get_hint_kind() == &"none",
		"fresh dormant field offers no +/- hint")
	var fresh_core_count: int = 0
	for child: Node in room.get_children():
		if child is StarCoreCarrier:
			fresh_core_count += 1
	_check(fresh_core_count == 1, "fresh entry still owns exactly one core")
	fresh.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Helpers


func _reset_via_input() -> void:
	if get_tree().paused:
		get_tree().paused = false
		_hud.set_pause_visible(false)
	await _tap_action(&"reset")
	await _step(10)


func _release_from_start() -> void:
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	_check(_room.get_core().is_active(), "core active after start release")


func _release_linked(player_positive: bool) -> void:
	await _set_player_polarity(player_positive)
	_player.global_position = Vector2(340.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(2)
	await _tap_action(&"interact")
	await _step(20)


func _direct_store(core_positive: bool, player_positive: bool) -> void:
	await _set_player_polarity(player_positive)
	_player.global_position = Vector2(340.0, 320.0)
	_player.velocity = Vector2.ZERO
	_room.get_core().activate_at(_linked_bay.get_store_center(), core_positive)
	_room.get_core().ignore_body(_player)
	await _step(1)
	await _tap_action(&"interact")
	await _step(1)


func _wait_committed(expected_positive: bool) -> void:
	await _wait_until(
		func() -> bool:
			return (
				not _link.has_pending_pulse()
				and not _link.is_field_pending()
				and _field.is_activated()
				and _field.is_positive() == expected_positive
				and not _field.is_transitioning()
			),
		180
	)


func _force_drift(x: float, frames: int) -> Dictionary:
	_player.global_position = Vector2(x, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(1)
	var force: Vector2 = _room.get_last_extra_player_force()
	var status: String = _room.get_last_extra_status()
	var start_x: float = _player.global_position.x
	await _step(frames)
	return {
		"force": force,
		"status": status,
		"dx": _player.global_position.x - start_x,
	}


func _set_player_polarity(positive: bool) -> void:
	var guard: int = 0
	while _player.is_positive() != positive and guard < 4:
		await _tap_action(&"polarity")
		guard += 1


func _walk_to_x(target_x: float, max_frames: int = 240) -> void:
	Input.action_press(&"move_right")
	for i: int in range(max_frames):
		await _step(1)
		if _player.global_position.x >= target_x:
			break
	Input.action_release(&"move_right")
	await _step(3)


func _wait_until(predicate: Callable, max_frames: int) -> void:
	for i: int in range(max_frames):
		if bool(predicate.call()):
			return
		await _step(1)


func _count_cores() -> int:
	if _room == null:
		return 0
	var count: int = 0
	for child: Node in _room.get_children():
		if child is StarCoreCarrier:
			count += 1
	return count


func _on_bay_recorded(positive: bool) -> void:
	_record_events.append(positive)


func _on_pulse_started(positive: bool) -> void:
	_pulse_events.append(positive)


func _on_field_committed(positive: bool) -> void:
	_field_commit_events.append(positive)


func _action_has_key(action: StringName, key: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and int((event as InputEventKey).physical_keycode) == int(key):
			return true
	return false


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await _step(1)
	Input.action_release(action)
	await _step(1)


func _tap_process_action(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _step(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame


func _section(title: String) -> void:
	_log("")
	_log("== %s ==" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, "" if detail.is_empty() else " | " + detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, "" if detail.is_empty() else " | " + detail])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	_log("")
	_log("RESULT pass=%d fail=%d skipped=%d" % [_pass_count, _fail_count, _skip_count])
	var directory: String = ProjectSettings.globalize_path("res://tests/logs")
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open("res://tests/logs/polarity_record_test.log", FileAccess.WRITE)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("POLARITY_RECORD_TEST_RESULT pass=%d fail=%d skipped=%d" % [
		_pass_count, _fail_count, _skip_count
	])
	get_tree().quit(1 if _fail_count > 0 else 0)
