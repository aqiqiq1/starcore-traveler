extends Node

## Feedback polish test for dlc/rift_workshop (2026-11-26 round).
##
##   ... --headless --path . res://dlc/rift_workshop/tests/polish_test.tscn
##
## Covers the three objective presentation fixes of this round:
##   1. the final "2 / 2" count is no longer overwritten by the core line;
##   2. the twin guards now have a real slam cue (previously silent), and two
##      impacts in the same 60 ms window still play only one thud;
##   3. the proximity wisp hum stays off during the recovery black-out instead
##      of being re-enabled on the next frame.
##
## The guards' defeat signals are emitted directly because this test is about
## the chapter's HUD/audio reactions, not the hit rules (mechanics_test.tscn
## already proves the real six-hit route).

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _checks: int = 0
var _failures: Array[String] = []
var _rift: RiftWorkshop = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("RIFT_POLISH_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: " + label + ("" if detail.is_empty() else " [" + detail + "]"))
		return
	_failures.append(label + ("" if detail.is_empty() else " [" + detail + "]"))
	print("FAIL: " + label + ("" if detail.is_empty() else " [" + detail + "]"))


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_ms(duration_ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return bool(predicate.call())


func _cleanup() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(3)
	# Give the audio thread a mix cycle to release the stopped playbacks (hum,
	# slam, ambience) before the process exits.
	await _wait_ms(250)


func _run() -> void:
	_rift = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(3)
	await _wait_physics(8)

	var hud: RiftWorkshopHUD = _rift.get_hud()
	var audio: Node = _rift.get_node("Audio")
	var player: L3Player = _rift.get_player()

	# 1. Slam cue: one real emit per guard, coalesced inside the same window.
	var slam_before: int = int(audio.call("get_slam_play_count"))
	_rift.get_guard_gold().slam_contact.emit(1)
	await _wait_process(2)
	var slam_one: int = int(audio.call("get_slam_play_count"))
	_check(slam_one == slam_before + 1, "gold guard slam plays the impact cue",
		"%d -> %d" % [slam_before, slam_one])
	_rift.get_guard_cyan().slam_contact.emit(-1)
	await _wait_process(2)
	_check(int(audio.call("get_slam_play_count")) == slam_one,
		"two guards slamming together play one thud",
		str(int(audio.call("get_slam_play_count"))))
	await _wait_ms(120)
	_rift.get_guard_gold().gravity_release.emit(true)
	await _wait_process(2)
	_check(int(audio.call("get_slam_play_count")) == slam_one + 1,
		"a later impact cue plays again")

	# 2. Defeat HUD: first guard keeps its own line, the second one merges the
	# final count and the core opening instead of overwriting the count.
	_rift.get_guard_gold().debug_force_death()
	_rift.get_guard_gold().defeated.emit()
	await _wait_process(3)
	_check(hud.get_event_text() == "金守卫已倒下 · 1 / 2",
		"first guard defeat shows 1 / 2", hud.get_event_text())
	_rift.get_guard_cyan().debug_force_death()
	_rift.get_guard_cyan().defeated.emit()
	await _wait_process(3)
	_check(_rift.is_both_defeated(), "both guards are registered as defeated")
	_check(hud.get_event_text() == "双生守卫已倒下 · 2 / 2 · 裂隙核心开启",
		"final line keeps 2 / 2 and the core opening", hud.get_event_text())
	var core: Sprite2D = _rift.get_finish_sprite()
	_check(core != null and core.modulate.r > 0.9 and core.modulate.a > 0.9,
		"finish core lights up after both defeats")

	# 3. Wisp hum: audible near, muted for the whole recovery fade, back after.
	player.global_position = Vector2(1030.0, 280.0)
	player.velocity = Vector2.ZERO
	await _wait_physics(24)
	_check(_rift.is_checkpoint_active(), "checkpoint records before the fall test")
	player.global_position = Vector2(1000.0, 280.0)
	player.velocity = Vector2.ZERO
	await _wait_process(12)
	var wisp: RiftPolarityWisp = _rift.get_wisps()[3]
	_check(wisp.is_hum_playing(), "near wisp hum is audible while playing")

	player.global_position = Vector2(1000.0, 520.0)
	var fell: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 2000
	)
	await _wait_process(5)
	_check(fell, "falling starts the recovery fade")
	_check(not wisp.is_hum_playing(), "wisp hum stays off during the recovery fade")
	await _wait_ms(300)
	_check(not wisp.is_hum_playing(), "wisp hum is still off later in the fade")

	var recovered: bool = await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 3000
	)
	_check(recovered, "recovery fade finishes")
	_check(absf(player.global_position.x - _rift.get_checkpoint_position().x) < 2.0,
		"player is back on the checkpoint", "x=%.2f" % player.global_position.x)
	await _wait_process(12)
	_check(wisp.is_hum_playing(), "near wisp hum returns after the recovery")
