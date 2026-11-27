extends Node

## Headless mechanics test for the 2026-11-26 rift-workshop rework 2.
##
##   ... --headless --path . res://dlc/rift_workshop/tests/mechanics_test.tscn
##
## Covers: locked Q (deny cue + head icon, no flip), the reusable inversion
## curtain, the gate, low truss jump block, Q-less bridge crossing by killing
## deck wisps, wisp flip threat, checkpoint, arena layout, inversion crystals
## (2 s cooldown), the mirror boss (same/opposite face rules, core exposure,
## three phases), two-hit failure reset, R restart, completion and E -> title.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"

var _rift: RiftWorkshop
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	Input.action_release(&"jump")
	print("RIFT_MECHANICS_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- helpers ---------------------------------------------------------------

func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: " + label + ("" if detail.is_empty() else " [" + detail + "]"))
		return
	_failures.append(label + ("" if detail.is_empty() else " [" + detail + "]"))
	print("FAIL: " + label + ("" if detail.is_empty() else " [" + detail + "]"))


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_ms(duration_ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_process(2)
	_push_key(code, false)
	await _wait_process(4)


func _tap_polarity() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(2)
	Input.action_release(&"polarity")
	await _wait_physics(4)


func _move_until_x(target: float, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	for _index: int in range(max_frames):
		if _player.global_position.x >= target:
			Input.action_release(&"move_right")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	await _wait_physics(2)
	return _player.global_position.x >= target


func _move_left_until_x(target: float, max_frames: int) -> bool:
	Input.action_press(&"move_left")
	for _index: int in range(max_frames):
		if _player.global_position.x <= target:
			Input.action_release(&"move_left")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
	Input.action_release(&"move_left")
	await _wait_physics(2)
	return _player.global_position.x <= target


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	if _rift != null and is_instance_valid(_rift) and _rift != current:
		_rift.queue_free()
	await _wait_process(20)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()


func _close_popup_if_open() -> bool:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return false
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)
	return not popup.is_open()


func _jab() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(3)
	_push_key(KEY_J, false)
	# Full swing + the 0.12 s cooldown; the next J is accepted.
	await _wait_physics(45)


func _wait_for_boss_active(max_frames: int = 240) -> bool:
	var boss: RiftMirrorBoss = _rift.get_boss()
	for _index: int in range(max_frames):
		if boss.is_active() and boss.get_attack_state_name() != "INTRO":
			return true
		await get_tree().physics_frame
	return false


func _break_gold_face(boss: RiftMirrorBoss) -> void:
	var face_x: float = boss.get_face_center_global(true).x
	await _place(face_x - 50.0, 320.0, false)
	await _jab()


func _break_cyan_face(boss: RiftMirrorBoss) -> void:
	var face_x: float = boss.get_face_center_global(false).x
	await _place(face_x - 50.0, 320.0, true)
	await _jab()


## Kill one face anchor with a real J.  The anchors hover at y=292 and the
## player's 36 px forward rect reaches them from the floor.
func _kill_face_anchor(boss: RiftMirrorBoss, positive: bool) -> bool:
	var wisp: RiftPolarityWisp = boss.get_face_anchor(positive)
	if wisp == null or not is_instance_valid(wisp) or not wisp.is_alive():
		return false
	await _place(wisp.global_position.x - 44.0, 320.0, true)
	await _jab()
	return not wisp.is_alive()


func _wait_for_anchors(boss: RiftMirrorBoss, count: int, max_frames: int = 180) -> bool:
	return await _wait_until(
		func() -> bool: return boss.get_alive_anchor_count() == count,
		max_frames
	)


func _hit_core_three(boss: RiftMirrorBoss) -> void:
	for _index: int in range(3):
		await _place(boss.global_position.x - 20.0, 320.0, true)
		await _jab()


# --- main flow -------------------------------------------------------------

func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_check(packed != null, "rift scene loads")
	if packed == null:
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(4)
	await _wait_physics(10)

	_player = _rift.get_player()
	_check(_player != null, "chapter exposes an L3Player")
	if _player == null:
		return
	_check(_player.allow_polarity_toggle == false, "chapter locks the shared Q toggle")
	_check(_rift.get_node_or_null("GuardGold") == null
		and _rift.get_node_or_null("GuardCyan") == null,
		"old GuardGold / GuardCyan are removed")
	_check(_rift.get_node_or_null("GuardCue") == null, "old guard cue is removed")
	var hud: RiftWorkshopHUD = _rift.get_hud()
	_check(hud.get_title_text() == "裂隙工坊", "HUD title reads 裂隙工坊",
		hud.get_title_text())
	_check(hud.get_objective_text().begins_with("目标："), "HUD shows an objective",
		hud.get_objective_text())
	_check(hud.get_phase_icon_kind() == "sun" and not hud.is_affinity_text_visible(),
		"top-right phase is a sun icon, not 辉相 text")
	_check(hud.get_phase_icon().size == Vector2(20.0, 20.0),
		"phase icon is 20 x 20", str(hud.get_phase_icon().size))
	_check(hud.has_element_legend() == false
		and hud.find_child("ElementLegend", true, false) == null,
		"the permanent element legend row is gone")
	_check(not hud.is_boss_visible(), "boss status is hidden before the arena")
	_check(_rift.get_boss().get_boss_rect().size == Vector2(128.0, 112.0),
		"the mirror's hit body is 128 x 112",
		str(_rift.get_boss().get_boss_rect().size))
	var boss_sprite: Sprite2D = _rift.get_boss().get_boss_sprite()
	_check(boss_sprite != null and boss_sprite.texture.get_width() / boss_sprite.hframes == 128
		and boss_sprite.texture.get_height() == 112,
		"the generated boss sheet is 128 x 112 per frame")
	_check(hud.is_player_health_visible(), "the fixed health bar is visible in normal play")
	var health_bar: PlayerHealthBar = hud.get_player_health_bar()
	_check(health_bar != null and health_bar.get_style_name() == "bar"
		and not health_bar.is_heart_style(),
		"health display is the shared red bar, not hearts")
	_check(hud.get_player_health_rect().position == Vector2(14.0, 324.0),
		"bar is fixed at (14,324)", str(hud.get_player_health_rect()))
	var segment_rects: Array[Rect2] = health_bar.get_segment_rects()
	_check(segment_rects.size() == 2
		and segment_rects[0].size == Vector2(14.0, 8.0)
		and segment_rects[1].position.x == 30.0,
		"bar has two 14x8 segments with a 2 px gap", str(segment_rects))
	_check(health_bar.filled_color == Color("#d95757")
		and health_bar.low_color == Color("#ff7b7b"),
		"bar fill is red #d95757 with bright #ff7b7b low segment")
	_check(health_bar.get_heart_rect().size == Vector2(10.0, 10.0),
		"health group has the 10x10 heart at its left", str(health_bar.get_heart_rect()))
	_check(hud.get_health_label() == null,
		"no 生命值 word label remains on the HUD")
	await _place(300.0, 320.0, true)
	await _wait_process(4)
	_check(hud.get_player_health_rect().position == Vector2(14.0, 324.0),
		"bar does not follow the player", str(hud.get_player_health_rect()))
	Input.action_press(&"move_right")
	await _wait_physics(45)
	Input.action_release(&"move_right")
	await _wait_physics(2)
	var footstep: Node = _rift.get_footstep_audio()
	_check(footstep != null and int(footstep.call("get_step_count")) > 0,
		"walking emits real footsteps",
		str(footstep.call("get_step_count")) if footstep != null else "null")
	await _place(40.0, 320.0, true)
	await _wait_ms(1000)
	_check(_rift.get_field_hint_count() == 0 and _rift.get_gate_hint_count() == 0
		and hud.get_event_text().is_empty(),
		"DLC2 spawn shows no field or gate hint",
		hud.get_event_text())

	# The moon gate's own reminder is proximity-only: 60 px is silent, 56 px
	# speaks once and contact does not repeat it.
	await _place(210.0, 320.0, true)
	_player.face_direction(1)
	await _wait_ms(1000)
	_check(_rift.get_gate_hint_count() == 0,
		"60 px before the DLC2 gate shows no reminder",
		hud.get_event_text())
	await _place(214.0, 320.0, true)
	_player.face_direction(1)
	await _wait_physics(4)
	_check(_rift.get_gate_hint_count() == 1
		and hud.get_event_text() == "送青核入仓，为月门供电",
		"the DLC2 gate only reminds 送青核入仓，为月门供电",
		hud.get_event_text())
	_check(not hud.get_event_text().contains("推") and not hud.get_event_text().contains("拉"),
		"DLC2 does not restate the full push/pull lesson",
		hud.get_event_text())
	var gate_hint_before: int = _rift.get_gate_hint_count()
	Input.action_press(&"move_right")
	await _wait_physics(20)
	Input.action_release(&"move_right")
	await _wait_physics(2)
	_check(_rift.get_gate_hint_count() == gate_hint_before,
		"contact does not repeat the DLC2 gate reminder",
		str(_rift.get_gate_hint_count()))
	await _place(40.0, 320.0, true)

	# --- locked Q --------------------------------------------------------
	var q_before: bool = _player.is_positive()
	var toggles_before: int = _player.get_polarity_toggle_count()
	var deny_before: int = int(_rift.get_node("Audio").call("get_deny_play_count"))
	await _tap_polarity()
	_check(_player.is_positive() == q_before, "Q does not flip the player")
	_check(_player.get_polarity_toggle_count() == toggles_before,
		"Q does not increment the shared toggle count",
		str(_player.get_polarity_toggle_count()))
	_check(int(_rift.get_node("Audio").call("get_deny_play_count")) > deny_before,
		"Q plays the refusal cue")
	_check(hud.is_q_denied_visible(), "Q shows the cross-Q icon above the head")
	_check(_rift.get_q_denial_count() >= 1, "chapter counts the denied press")
	var denied_rect: Rect2 = hud.get_q_denied_rect()
	var feet: Vector2 = _player.get_global_transform_with_canvas().origin
	_check(absf(denied_rect.get_center().x - feet.x) <= 1.5
		and denied_rect.position.y < feet.y - 30.0,
		"cross-Q icon is centred above the player's head",
		"rect=%s feet=%s" % [str(denied_rect), str(feet)])
	await _wait_physics(60)
	_check(not hud.is_q_denied_visible(), "cross-Q icon expires after its short window")

	# --- room 1: inversion / star-core delivery / gate -------------------
	var field: RiftInversionField = _rift.get_field_a()
	var carrier: CoreDeliveryCarrier = _rift.get_core_carrier()
	var bay: CoreDeliveryBay = _rift.get_core_bay()
	var gate: PolarityGate = _rift.get_gate_moon()
	var proxy: CoreDeliveryGateProxy = _rift.get_gate_moon_proxy()
	_check(carrier != null and bay != null and gate != null and proxy != null,
		"the core carrier, bay and moon gate exist")
	if carrier == null or bay == null or gate == null or proxy == null:
		return
	var core_visual: StarCoreVisual = carrier.get_core_visual()
	_check(core_visual != null
		and core_visual.state == StarCoreVisual.CoreState.NEGATIVE
		and not carrier.is_core_positive(),
		"the delivered core is the cyan 澜相 core of the moon gate")
	await _place(40.0, 320.0, true)
	carrier.reset_state()
	await _wait_physics(3)
	_check(absf(carrier.global_position.x - carrier.get_start_x()) < 0.5,
		"the star core waits at its authored start",
		"core=%.1f" % carrier.global_position.x)
	_check(not bay.is_occupied() and bay.get_glow_strength() == 0.0,
		"the bay starts dark before delivery")
	_check(gate.is_blocking() and gate.get_collision_layer() == 1,
		"the first moon gate starts unpowered and solid")
	_check(proxy.is_positive() and gate.get_required_positive() == false,
		"the unpowered proxy feeds the gate its opposite phase")
	_check(carrier.get_node_or_null("CollisionShape2D") == null
		and bay.get_node_or_null("CollisionShape2D") == null,
		"the core and bay own no collision body (no pinch / no platform)")

	# The curtain is the only phase control.  Its lesson is proximity-only:
	# 60 px is silent, 56 px shows the first inversion prompt, and crossing does
	# not repeat it.
	await _place(100.0, 320.0, true)
	_player.face_direction(1)
	await _wait_ms(1000)
	_check(_rift.get_field_hint_count() == 0 and field.get_trigger_count() == 0,
		"60 px before the inversion field shows no hint",
		hud.get_event_text())
	_player.global_position = Vector2(104.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(true)
	_player.face_direction(-1)
	await _wait_physics(4)
	await _wait_ms(220)
	_check(_rift.get_field_hint_count() == 0,
		"56 px while facing away shows no field hint",
		hud.get_event_text())
	_player.face_direction(1)
	await _wait_physics(3)
	await _wait_ms(120)
	_check(_rift.get_field_hint_count() == 1,
		"the 56 px approach shows the inversion hint",
		"x=%.1f" % _player.global_position.x)
	_check(hud.get_event_text() == "紫幕反转 · 穿过换相",
		"the first inversion hint teaches crossing",
		hud.get_event_text())
	var field_hint_before: int = _rift.get_field_hint_count()

	# Its 澜相 is the core's own phase, so the same-phase field pushes the core
	# toward the bay.
	var walked: bool = await _move_until_x(165.0, 240)
	_check(walked and field.get_trigger_count() == 1,
		"walking through the violet curtain flips once",
		"x=%.1f triggers=%d" % [_player.global_position.x, field.get_trigger_count()])
	_check(not _player.is_positive(), "the post-curtain body is 澜相")
	_check(_rift.get_field_hint_count() == field_hint_before,
		"crossing the field does not repeat its hint")
	var seated: bool = await _wait_until(
		func() -> bool: return carrier.is_on_socket(), 240
	)
	_check(seated, "same-phase field pushes the core into the bay",
		"core=%.1f" % carrier.global_position.x)
	_check(bay.is_occupied() and bay.is_lit()
		and bay.get_glow_strength() == 1.0,
		"the bay lights when the core is seated",
		"glow=%.1f" % bay.get_glow_strength())
	_check(not gate.is_blocking() and gate.get_collision_layer() == 0,
		"the seated core powers the first moon gate open",
		"layer=%d" % gate.get_collision_layer())
	_check(hud.get_event_text().contains("青核入仓")
		and hud.get_event_text().contains("月门"),
		"the HUD event line explains the core powering the gate",
		hud.get_event_text())
	_check(hud.get_objective_text().contains("相性桥"),
		"the objective advances after the gate is powered",
		hud.get_objective_text())

	# Step out of the curtain first: exiting does not flip.  Walking back in
	# from the right is the real second pass and returns the body to 辉相.
	await _move_until_x(235.0, 240)
	_check(not field.is_player_inside(), "leaving the curtain re-arms it")
	await _move_left_until_x(140.0, 240)
	_check(field.get_trigger_count() == 2, "the same curtain re-arms and flips again",
		str(field.get_trigger_count()))
	_check(_player.is_positive(), "the body returns to 辉相 for the pull")
	var pulled: bool = await _wait_until(
		func() -> bool: return not carrier.is_on_socket(), 240
	)
	_check(pulled, "opposite-phase field pulls the core out of the bay",
		"core=%.1f" % carrier.global_position.x)
	_check(not bay.is_occupied() and not bay.is_lit()
		and bay.get_glow_strength() == 0.0,
		"pulling the core out darkens the bay")
	_check(gate.is_blocking() and gate.get_collision_layer() == 1,
		"the unpowered first moon gate closes again",
		"layer=%d" % gate.get_collision_layer())
	_check(hud.get_event_text().contains("青核离仓")
		and hud.get_event_text().contains("月门"),
		"the HUD event line also explains the power loss",
		hud.get_event_text())

	# Power, not phase, owns this gate now: even the moon phase is blocked while
	# the core is out.  Then re-arm the curtain and push it back in.
	await _place(240.0, 320.0, false)
	await _wait_physics(4)
	_check(gate.is_blocking() and _player.global_position.x < 266.0,
		"the moon phase alone cannot open the unpowered gate",
		"x=%.2f layer=%d" % [_player.global_position.x, gate.get_collision_layer()])
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	await _wait_physics(3)
	Input.action_release(&"jump")
	await _wait_physics(36)
	Input.action_release(&"move_right")
	_check(_player.global_position.x < 266.0,
		"the unpowered gate also stops a running jump",
		"x=%.2f" % _player.global_position.x)
	await _place(140.0, 320.0, true)
	await _move_until_x(165.0, 240)
	_check(field.get_trigger_count() == 3,
		"the curtain re-arms for the recovery push",
		str(field.get_trigger_count()))
	_check(not _player.is_positive(), "the recovery push starts in 澜相")
	var reseated: bool = await _wait_until(
		func() -> bool: return carrier.is_on_socket(), 300
	)
	_check(reseated, "the core can always be pushed back into the bay",
		"core=%.1f" % carrier.global_position.x)
	_check(bay.is_lit() and not gate.is_blocking(),
		"reseating relights the bay and reopens the gate")
	# The bay holds a seated core once the body is on its right, so crossing
	# cannot pull it back out from the far side.
	await _place(255.0, 320.0, true)
	await _wait_physics(6)
	_check(carrier.is_on_socket() and not gate.is_blocking(),
		"the bay holds the core while the body is on its right (no far-side softlock)",
		"core=%.1f" % carrier.global_position.x)
	await _move_until_x(300.0, 240)
	_check(_player.global_position.x > 280.0 and not gate.is_blocking(),
		"the powered gate lets the body through",
		"x=%.1f" % _player.global_position.x)

	# Leave more than 200 px and return inside the 10 s cooldown: the same field
	# line must stay silent.
	var field_hint_after_cross: int = _rift.get_field_hint_count()
	await _place(380.0, 320.0, true)
	await _wait_physics(3)
	await _place(104.0, 320.0, true)
	_player.face_direction(1)
	await _wait_ms(220)
	_check(_rift.get_field_hint_count() == field_hint_after_cross,
		"the same field hint does not repeat within 10 s",
		str(_rift.get_field_hint_count()))
	await _place(300.0, 320.0, true)

	# --- low truss / bridge fall ----------------------------------------
	var beams: RiftLowBeams = _rift.get_low_beams()
	_check(beams != null and beams.get_beam_count() == 3
		and is_equal_approx(beams.get_headroom(), 27.0),
		"three low beams keep the 27 px ceiling")
	await _place(650.0, 280.0, false)
	_check(not _rift.get_bridge_a().is_solid(), "wrong-phase BridgeA is gone")
	Input.action_press(&"move_right")
	await _wait_physics(8)
	Input.action_press(&"jump")
	var min_y: float = _player.global_position.y
	for _index: int in range(55):
		min_y = minf(min_y, _player.global_position.y)
		await get_tree().physics_frame
	Input.action_release(&"jump")
	Input.action_release(&"move_right")
	_check(min_y > 248.0, "the low truss caps the jump over the gap",
		"min_y=%.2f" % min_y)
	var fell: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 180
	)
	_check(fell, "jumping a missing deck falls into the cloud sea")
	var recovered: bool = await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 320
	)
	await _wait_physics(6)
	_check(recovered, "bridge fall recovery finishes")
	_check(absf(_player.global_position.x - 600.0) < 3.0
		and absf(_player.global_position.y - 280.0) < 3.0,
		"pre-checkpoint bridge fall returns to the bridge head",
		"x=%.1f y=%.1f" % [_player.global_position.x, _player.global_position.y])
	_check(_player.is_positive(), "bridge head restarts in 辉相 so the gold deck works without Q")
	_check(hud.get_event_text().contains("坠入云海"),
		"fall line explains the cloud sea without Q", hud.get_event_text())

	# --- Q-less bridge: kill deck wisps from the banks ------------------
	var wisp_a: RiftPolarityWisp = _rift.get_wisps()[0]
	var wisp_b: RiftPolarityWisp = _rift.get_wisps()[1]
	var wisp_c: RiftPolarityWisp = _rift.get_wisps()[2]
	var wisp_e: RiftPolarityWisp = _rift.get_wisps()[4]
	await _place(688.0, 280.0, true)
	await _jab()
	_check(not wisp_a.is_alive(), "J kills the wisp guarding BridgeA",
		"alive=%s" % str(wisp_a.is_alive()))
	_check(_rift.get_bridge_a().is_stabilized(), "BridgeA becomes permanent")
	# WispB on LandingA is a flip threat; let it fire once.  The stable bridge
	# behind the player does not fall.
	await _place(776.0, 280.0, true)
	var flips_before: int = wisp_b.get_flip_count()
	var flipped: bool = await _wait_until(
		func() -> bool: return wisp_b.get_flip_count() > flips_before, 180
	)
	_check(flipped, "a landing wisp dives and flips the player",
		"flips=%d" % wisp_b.get_flip_count())
	_check(_rift.get_bridge_a().is_solid(),
		"the stabilised BridgeA stays solid through the flip",
		_rift.get_bridge_a().get_state_name())
	# Kill BridgeB's wisp from the LandingA edge (x=800 -> J reaches 832).
	await _place(800.0, 280.0, true)
	await _jab()
	_check(not wisp_c.is_alive(), "J kills the wisp guarding BridgeB from LandingA",
		"alive=%s" % str(wisp_c.is_alive()))
	_check(_rift.get_bridge_b().is_stabilized(), "BridgeB becomes permanent")
	# Kill BridgeC's wisp from the LandingB edge (x=912 -> J reaches 944).
	await _place(912.0, 280.0, true)
	await _jab()
	_check(not wisp_e.is_alive(), "J kills the wisp guarding BridgeC from LandingB",
		"alive=%s" % str(wisp_e.is_alive()))
	_check(_rift.get_bridge_c().is_stabilized(), "BridgeC becomes permanent")
	await _place(710.0, 280.0, false)
	await _wait_physics(8)
	_check(_rift.get_bridge_a().is_solid(),
		"the Q-less route never needs Q: the deck is solid on the other phase")
	_check(_player.allow_polarity_toggle == false,
		"the wisp flips did not unlock Q")

	# --- checkpoint ------------------------------------------------------
	await _place(1030.0, 280.0, false)
	await _wait_physics(8)
	_check(_rift.is_checkpoint_active(), "the checkpoint marker records")
	_check(_rift.get_checkpoint().is_activated(), "checkpoint art is active")
	_check(hud.get_objective_text().contains("长廊"),
		"checkpoint objective advances to the arena corridor",
		hud.get_objective_text())
	_player.global_position = Vector2(710.0, 500.0)
	_player.velocity = Vector2.ZERO
	var cp_fall: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 80
	)
	_check(cp_fall, "falling below the kill line starts the recovery")
	var cp_done: bool = await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 320
	)
	await _wait_physics(4)
	_check(cp_done, "post-checkpoint fall recovery finishes")
	_check(absf(_player.global_position.x - 1030.0) < 3.0,
		"post-checkpoint fall returns to the checkpoint, not the bridge head",
		"x=%.1f" % _player.global_position.x)

	# --- arena layout / entry -------------------------------------------
	_check(_rift.get_arena_spawn() == Vector2(1250.0, 320.0),
		"arena spawn is the long corridor entrance (1250, 320)",
		str(_rift.get_arena_spawn()))
	_check(_rift.get_boss_center() == Vector2(1540.0, 260.0),
		"the mirror hangs at 1540 / 260", str(_rift.get_boss_center()))
	_check(_rift.get_crystal_left().global_position.x == 1320.0
		and _rift.get_crystal_right().global_position.x == 1760.0,
		"inversion crystals sit left / right of the mirror")
	_check(_rift.get_finish_position() == Vector2(1850.0, 320.0),
		"finish core sits at the far end (1850, 320)")
	await _place(1250.0, 320.0, true)
	await _wait_physics(3)
	_check(_rift.is_arena_entered(), "walking the corridor enters the arena")
	_check(_rift.is_arena_intro_active(), "the 0.9 s opening hover starts")
	_check(hud.get_event_text().contains("裂隙守门者"),
		"HUD announces the mirror gatekeeper waking", hud.get_event_text())
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	await _wait_process(2)
	await _close_popup_if_open()
	var boss_active: bool = await _wait_for_boss_active()
	_check(boss_active, "the mirror becomes active after the opening")
	var boss: RiftMirrorBoss = _rift.get_boss()
	boss.set_attacks_enabled(false)
	_check(hud.is_boss_visible(), "boss status row is visible in the arena")
	_check(hud.get_boss_status().get_phase_index() == 0
		and hud.get_boss_status().get_core_hp() == 3
		and hud.get_boss_status().is_gold_intact()
		and hud.get_boss_status().is_cyan_intact(),
		"boss status starts at phase 1, core 3/3, both shields intact")

	# --- crystals: flip and 2 s cooldown --------------------------------
	var crystal: RiftInversionCrystal = _rift.get_crystal_left()
	await _place(1320.0, 320.0, true)
	await _wait_physics(4)
	_check(not _player.is_positive(), "touching the left crystal flips to 澜相")
	_check(crystal.get_flip_count() == 1, "left crystal counts one flip")
	_check(crystal.get_cooldown_left() > 1.8, "left crystal starts its 2 s cooldown",
		"%.2f s" % crystal.get_cooldown_left())
	await _place(1270.0, 320.0, false)
	await _place(1320.0, 320.0, false)
	await _wait_physics(4)
	_check(crystal.get_flip_count() == 1,
		"the crystal will not flip again while cooling")
	await _place(1270.0, 320.0, false)
	await _wait_ms(2200)
	await _place(1320.0, 320.0, false)
	await _wait_physics(6)
	_check(crystal.get_flip_count() == 2,
		"after the cooldown, touching again flips once more",
		str(crystal.get_flip_count()))

	# --- failure: two mirror sweeps reset the boss ----------------------
	await _place(boss.global_position.x - 100.0, 320.0, true)
	boss.set_attacks_enabled(true)
	boss.debug_force_sweep()
	var sweep_one: bool = await _wait_until(
		func() -> bool: return boss.get_sweep_count() > 0, 120
	)
	await _wait_physics(4)
	_check(sweep_one and _rift.get_player_hits() == 1,
		"a low mirror sweep removes one bar segment", str(_rift.get_player_hits()))
	_check(health_bar.get_current() == 1,
		"hit drops the fixed bar to one segment", str(health_bar.get_current()))
	boss.set_attacks_enabled(false)
	await _wait_physics(45)
	boss.set_attacks_enabled(true)
	boss.debug_force_sweep()
	var sweep_two: bool = await _wait_until(
		func() -> bool: return boss.get_sweep_count() > 1, 120
	)
	await _wait_physics(4)
	boss.set_attacks_enabled(false)
	_check(sweep_two and _rift.get_player_hits() == 2,
		"the second sweep empties the bar", str(_rift.get_player_hits()))
	_check(health_bar.get_current() == 0,
		"second hit leaves zero filled segments", str(health_bar.get_current()))
	var retry: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 120
	)
	_check(retry, "two accepted hits start the failure transition")
	var retry_done: bool = await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 320
	)
	await _wait_physics(4)
	_check(retry_done, "failure recovery finishes without staying black")
	_check(absf(_player.global_position.x - 1250.0) < 3.0,
		"failure returns the player to the arena entrance",
		"x=%.1f" % _player.global_position.x)
	_check(boss.get_phase_number() == 1 and boss.get_core_hp() == 3
		and boss.get_intact_face_count() == 2,
		"failure resets the boss to phase 1, core 3/3, both plates",
		"phase=%d core=%d faces=%d" % [
			boss.get_phase_number(), boss.get_core_hp(), boss.get_intact_face_count()
		])
	_check(_rift.get_player_hits() == 0, "failure clears the hit count")
	_check(health_bar.get_current() == 2,
		"failure recovery refills both bar segments", str(health_bar.get_current()))
	_check(_rift.get_crystal_left().get_flip_count() == 0
		and _rift.get_crystal_right().get_flip_count() == 0,
		"failure resets both arena crystals")
	_check(_rift.is_arena_intro_active(), "failure restarts the arena opening")
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	var retry_active: bool = await _wait_for_boss_active()
	_check(retry_active, "the boss wakes again after the retry opening")
	boss.set_attacks_enabled(false)

	# --- an arena fall is the same full reset ---------------------------
	_player.global_position = Vector2(1500.0, 560.0)
	_player.velocity = Vector2.ZERO
	var fall_began: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 80
	)
	_check(fall_began, "an arena fall starts the recovery")
	var fall_done: bool = await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 320
	)
	await _wait_physics(4)
	_check(fall_done, "arena fall recovery finishes")
	_check(absf(_player.global_position.x - 1250.0) < 3.0,
		"an arena fall returns to the arena entrance",
		"x=%.1f" % _player.global_position.x)
	_check(boss.get_phase_number() == 1 and boss.get_core_hp() == 3
		and boss.get_intact_face_count() == 2,
		"an arena fall resets the mirror to phase 1 / core 3 / both plates")
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 180)
	var fall_active: bool = await _wait_for_boss_active()
	_check(fall_active, "the boss wakes again after a fall reset")
	boss.set_attacks_enabled(false)

	# --- form 1: face phase rule + core --------------------------------
	_check(boss.get_intact_face_count() == 2, "form 1 starts with two plates")
	_check(boss.get_form_transition_time() >= 1.0
		and boss.get_form_transition_time() <= 1.2,
		"form-break transition is 1.0-1.2 s",
		"%.2f s" % boss.get_form_transition_time())
	_check(is_equal_approx(boss.get_sweep_warn_time(), 0.85)
		and boss.get_face_orbit_speed() == 0.0,
		"form 1 keeps the slow teaching sweep and fixed plates",
		"warn=%.2f orbit=%.2f" % [
			boss.get_sweep_warn_time(), boss.get_face_orbit_speed()
		])
	_check(hud.get_boss_status().get_form_text() == "形态 1/3",
		"HUD names form 1", hud.get_boss_status().get_form_text())
	await _place(boss.get_face_center_global(true).x - 50.0, 320.0, true)
	await _jab()
	_check(boss.is_face_intact(true)
		and String(boss.get_last_result().get("code", "")) == "SAME_PHASE",
		"same-phase J bounces off the gold plate",
		String(boss.get_last_result().get("code", "")))
	await _break_gold_face(boss)
	_check(not boss.is_face_intact(true), "opposite-phase J shatters the gold plate",
		String(boss.get_last_result().get("code", "")))
	_check(hud.get_boss_status().is_gold_intact() == false,
		"boss HUD marks the gold plate broken")
	await _break_cyan_face(boss)
	_check(not boss.is_face_intact(false), "opposite-phase J shatters the cyan plate",
		String(boss.get_last_result().get("code", "")))
	_check(boss.is_core_exposed(), "both plates broken -> core exposed")
	_check(hud.get_boss_status().is_core_exposed(),
		"boss HUD shows the exposed core")
	_check(boss.get_core_window_max() == 10.0,
		"form 1 core window is 10 s", "%.1f" % boss.get_core_window_max())
	await _hit_core_three(boss)
	_check(boss.get_core_hp() == 0, "three core hits clear form 1",
		str(boss.get_core_hp()))
	var phase_two: bool = await _wait_until(
		func() -> bool: return boss.get_phase_number() == 2, 180
	)
	_check(phase_two, "form 2 starts after the core clear")
	var transition_ms: int = boss.get_last_form_transition_ms()
	_check(transition_ms >= 1000 and transition_ms <= 1450,
		"form 1 -> 2 transition lasts 1.1 s", "%d ms" % transition_ms)
	_check(boss.get_intact_face_count() == 2 and boss.get_core_hp() == 3
		and not boss.is_core_exposed(),
		"form 2 restores both plates and core 3/3")
	_check(hud.get_boss_status().get_form_text() == "形态 2/3",
		"HUD names form 2", hud.get_boss_status().get_form_text())
	var anchors_two: bool = await _wait_for_anchors(boss, 2)
	_check(anchors_two, "form 2 summons one anchor per plate",
		str(boss.get_alive_anchor_count()))
	_check(boss.has_face_anchor(true) and boss.has_face_anchor(false),
		"both plates report a live anchor")
	_check(hud.get_boss_status().is_gold_anchored()
		and hud.get_boss_status().is_cyan_anchored(),
		"HUD marks both plates anchored")
	_check(is_equal_approx(boss.get_sweep_warn_time(), 0.55)
		and is_equal_approx(boss.get_face_orbit_speed(), 0.55),
		"form 2 sweeps faster and plates begin a slow orbit",
		"warn=%.2f orbit=%.2f" % [
			boss.get_sweep_warn_time(), boss.get_face_orbit_speed()
		])

	# A living anchor makes the plate immune even with the right polarity.
	# Stand on the core side of the plate so auto-facing aims at the plate, not
	# at the anchor hovering outside it.
	await _place(boss.get_face_center_global(true).x + 50.0, 320.0, false)
	await _jab()
	_check(boss.is_face_intact(true)
		and String(boss.get_last_result().get("code", "")) == "ANCHORED",
		"anchored gold plate rejects the opposite-phase J",
		String(boss.get_last_result().get("code", "")))
	var gold_anchor_down: bool = await _kill_face_anchor(boss, true)
	_check(gold_anchor_down and boss.get_alive_anchor_count() == 1,
		"a real J kills the gold anchor", str(boss.get_alive_anchor_count()))
	var gold_window: float = boss.get_anchor_window_left(true)
	_check(gold_window > 5.0 and gold_window <= 6.0,
		"gold anchor opens a 6 s shatter window", "%.2f s" % gold_window)
	_check(hud.get_boss_status().get_gold_window() > 5.0,
		"HUD shows the gold anchor window",
		"%.2f s" % hud.get_boss_status().get_gold_window())
	await _break_gold_face(boss)
	_check(not boss.is_face_intact(true),
		"opposite-phase J shatters the unanchored gold plate",
		String(boss.get_last_result().get("code", "")))
	var cyan_anchor_down: bool = await _kill_face_anchor(boss, false)
	_check(cyan_anchor_down and boss.get_alive_anchor_count() == 0,
		"a real J kills the cyan anchor", str(boss.get_alive_anchor_count()))
	await _break_cyan_face(boss)
	_check(not boss.is_face_intact(false),
		"opposite-phase J shatters the unanchored cyan plate",
		String(boss.get_last_result().get("code", "")))
	_check(boss.is_core_exposed(), "both unanchored plates broken -> core exposed")
	_check(boss.get_core_window_max() == 8.0
		and boss.get_core_window_left() > 0.0,
		"form 2 core window is 8 s", "%.2f s" % boss.get_core_window_left())
	# Let the window expire once: the plates close, core returns to 3/3 and
	# new anchors descend.  This is the real _close_core path, not a fake reset.
	boss.debug_force_core_timeout()
	var core_closed: bool = await _wait_until(
		func() -> bool: return not boss.is_core_exposed(), 90
	)
	_check(core_closed and boss.get_core_hp() == 3
		and boss.get_intact_face_count() == 2,
		"an expired form 2 core window reseals both plates and core 3/3")
	var reanchored: bool = await _wait_for_anchors(boss, 2)
	_check(reanchored, "an expired core window resummons both plate anchors",
		str(boss.get_alive_anchor_count()))
	await _kill_face_anchor(boss, true)
	await _kill_face_anchor(boss, false)
	await _break_gold_face(boss)
	await _break_cyan_face(boss)
	_check(boss.is_core_exposed(), "form 2 core can be reopened after a timeout")
	await _hit_core_three(boss)
	var phase_three: bool = await _wait_until(
		func() -> bool: return boss.get_phase_number() == 3, 220
	)
	_check(phase_three, "form 3 starts after the second core clear")
	_check(boss.get_intact_face_count() == 2 and boss.get_core_hp() == 3,
		"form 3 restores both plates and core 3/3")
	_check(hud.get_boss_status().get_form_text() == "形态 3/3",
		"HUD names form 3", hud.get_boss_status().get_form_text())
	_check(is_equal_approx(boss.get_face_orbit_speed(), 1.9)
		and is_equal_approx(boss.get_extra_summon_period(), 9.0)
		and boss.get_next_attack_kind() == "wave",
		"form 3 orbits faster, summons more often, and alternates from a wave",
		"orbit=%.2f summon=%.1f next=%s" % [
			boss.get_face_orbit_speed(), boss.get_extra_summon_period(),
			boss.get_next_attack_kind()
		])
	# Forced double sweep is the form 3 pattern; stand outside the arena width
	# so the two releases are observed without spending a heart.
	await _place(1230.0, 320.0, true)
	var sweeps_before: int = boss.get_sweep_count()
	boss.debug_force_double_sweep()
	_check(boss.get_sweep_bursts_left() == 2,
		"form 3 double sweep queues two releases",
		str(boss.get_sweep_bursts_left()))
	var double_done: bool = await _wait_until(
		func() -> bool: return boss.get_sweep_count() >= sweeps_before + 2, 220
	)
	_check(double_done, "both double-sweep releases resolve",
		"%d -> %d" % [sweeps_before, boss.get_sweep_count()])
	await _wait_until(func() -> bool: return boss.get_attack_state_name() == "IDLE", 120)
	var anchors_three: bool = await _wait_for_anchors(boss, 2)
	_check(anchors_three, "form 3 summons one anchor per plate",
		str(boss.get_alive_anchor_count()))
	var gold_anchor_three_down: bool = await _kill_face_anchor(boss, true)
	var cyan_anchor_three_down: bool = await _kill_face_anchor(boss, false)
	_check(gold_anchor_three_down and cyan_anchor_three_down,
		"both form 3 anchors die to real J hits")
	await _break_gold_face(boss)
	await _break_cyan_face(boss)
	_check(boss.is_core_exposed(), "form 3 core exposed after both plates break")
	var complete_cue_before: int = int(
		_rift.get_node("Audio").call("get_complete_play_count")
	)
	_check(boss.get_core_window_max() == 5.5
		and boss.get_core_window_left() <= 5.5,
		"form 3 core window is shorter (5.5 s)",
		"max=%.1f left=%.2f" % [boss.get_core_window_max(), boss.get_core_window_left()])
	await _hit_core_three(boss)
	var defeat_started: bool = await _wait_until(
		func() -> bool: return boss.is_collapsing(), 220
	)
	_check(defeat_started, "the third core clear starts the collapse")
	_check(not hud.is_player_health_visible(),
		"boss collapse hides the fixed health bar")
	_check(boss.get_defeat_collapse_time() >= 1.2
		and boss.get_defeat_collapse_time() <= 1.5,
		"defeat collapse is 1.2-1.5 s",
		"%.2f s" % boss.get_defeat_collapse_time())
	_check(not _rift.is_boss_defeated(),
		"the chapter does not activate the finish during the collapse")
	_check(_rift.is_boss_collapse_invulnerable(),
		"the chapter marks the player invulnerable during the collapse")
	_check(_player.is_hit_protected(),
		"the shared player's hit protection is active during the collapse")
	_check(_rift.get_finish_sprite().modulate.r < 0.9,
		"the finish core stays dim until the collapse finishes")
	var collapse_start_ms: int = Time.get_ticks_msec()
	var hits_before_collapse: int = _rift.get_player_hits()
	boss.player_struck.emit(1)
	await _wait_physics(2)
	_check(_rift.get_player_hits() == hits_before_collapse,
		"a forced strike during the collapse deals no damage",
		str(_rift.get_player_hits()))
	var boss_down: bool = await _wait_until(
		func() -> bool: return _rift.is_boss_defeated(), 220
	)
	var collapse_ms: int = Time.get_ticks_msec() - collapse_start_ms
	_check(boss_down and boss.is_collapse_finished(),
		"the collapse finishes before the chapter registers defeat")
	_check(hud.is_player_health_visible(),
		"the bar returns after the collapse on the core route")
	_check(collapse_ms >= 1000 and collapse_ms <= 2000,
		"collapse wall time is in the 1.2-1.5 s neighbourhood",
		"%d ms" % collapse_ms)
	_check(_rift.get_finish_sprite().modulate.r > 0.9,
		"the finish core lights up only after the collapse")
	_check(int(_rift.get_node("Audio").call("get_complete_play_count"))
		== complete_cue_before + 1,
		"the completion cue plays once when the collapse finishes",
		str(int(_rift.get_node("Audio").call("get_complete_play_count"))))
	_check(hud.get_boss_status().get_phase_index() == 2
		and hud.get_boss_status().get_core_hp() == 0,
		"boss HUD ends on form 3 / core 0")
	var core_tip: bool = await _wait_until(
		func() -> bool:
			var popup: MechanicPopup = _rift.get_mechanic_popup()
			return popup.is_open() and popup.get_current_id() == "rift_core_tip",
		180
	)
	_check(core_tip, "boss defeat opens the core tip")
	if core_tip:
		_check(get_tree().paused, "core tip pauses the tree")
		var closed: bool = await _close_popup_if_open()
		_check(closed and not get_tree().paused, "F closes the core tip")

	# --- completion ------------------------------------------------------
	_player.global_position = Vector2(1848.0, 320.0)
	_player.velocity = Vector2.ZERO
	var completed: bool = await _wait_until(
		func() -> bool: return _rift.is_completed(), 120
	)
	_check(completed, "touching the far core completes the chapter")
	_check(hud.is_completion_visible(), "completion page is visible")
	_check(hud.get_completion_text().begins_with("裂隙封闭 · 用时 "),
		"completion text is 裂隙封闭 · 用时 mm:ss", hud.get_completion_text())
	_check(hud.get_completion_subtitle_text() == "双面镜碎裂，裂隙核心重新入睡。",
		"completion subtitle names the mirror",
		hud.get_completion_subtitle_text())
	_check(not hud.is_player_health_visible(),
		"completion page hides the fixed health bar")

	# --- R restart -------------------------------------------------------
	await _tap_key(KEY_R)
	await _wait_process(4)
	await _wait_physics(8)
	_check(absf(_player.global_position.x - 40.0) < 2.0,
		"R returns to the start", "x=%.1f" % _player.global_position.x)
	_check(not _rift.is_completed(), "R clears completion")
	_check(not _rift.is_checkpoint_active(), "R clears the checkpoint")
	_check(_rift.get_boss().get_phase_number() == 1
		and _rift.get_boss().get_core_hp() == 3
		and _rift.get_boss().get_intact_face_count() == 2,
		"R resets the mirror to phase 1 / core 3 / both plates")
	_check(not _rift.is_boss_defeated(), "R clears the boss defeat flag")
	_check(_rift.get_crystal_left().get_flip_count() == 0
		and _rift.get_crystal_right().get_flip_count() == 0,
		"R resets both inversion crystals")
	_check(_rift.get_wisps()[0].is_alive(), "R respawns the bridge wisps")
	_check(not _rift.get_bridge_a().is_stabilized(),
		"R clears the wisp-cleared deck stabilisation")
	_check(not hud.is_boss_visible(), "R hides the boss status row")
	Input.action_press(&"move_right")
	await _wait_physics(14)
	Input.action_release(&"move_right")
	_check(_player.global_position.x > 45.0, "player can move after R",
		"x=%.1f" % _player.global_position.x)
