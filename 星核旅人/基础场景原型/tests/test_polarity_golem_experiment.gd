extends Node

## Minimal headless smoke for the independent polarity-golem prototype.
## It drives real key events for J / Q / Tab / R / Esc and checks only the
## acceptance-critical flows. Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/test_polarity_golem_experiment.tscn
##
## The scatter wait is deliberately shortened in the test setup (0.35 s /
## 3.0 s) and clearly logged; the production default remains 8.0 s.

const EXPERIMENT_SCENE: PackedScene = preload(
	"res://scenes/experiments/polarity_golem_experiment.tscn"
)
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

var _game
var _player
var _golem
var _hud
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_game = EXPERIMENT_SCENE.instantiate()
	add_child(_game)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = _game.get_player()
	_golem = _game.get_golem()
	_hud = _game.get_hud()

	_log("=== Polarity Golem Experiment - headless smoke ===")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"], DisplayServer.get_name()
	])

	await _test_scene_load()
	await _test_same_phase_hit_and_single_resolution()
	await _test_reverse_and_out_of_range()
	await _test_q_snapshot_and_opposite_pull()
	await _test_tab_polarity_entry()
	await _test_wall_blocking()
	await _test_scatter_and_reassemble()
	await _test_pause_freeze_and_reset_while_waiting()
	await _test_focus_loss_safe_pause()
	await _finish()


func _test_scene_load() -> void:
	_section("1. PARSE / LOAD")
	_check(_game != null, "experiment scene instantiates")
	_check(_player != null and _golem != null and _hud != null, "player, golem and HUD resolve")
	_check(
		String(_player.get_script().resource_path).ends_with("polarity_golem_player.gd"),
		"player uses the independent attack subclass, not a copied player scene",
		String(_player.get_script().resource_path)
	)
	_check(
		String(_golem.get_script().resource_path).ends_with("polarity_golem_enemy.gd"),
		"golem uses the experiment enemy script",
		String(_golem.get_script().resource_path)
	)
	_check(_player.allow_self_reset == false, "R is owned by the experiment root, not the shared player")
	_check(
		String(ResourceLoader.load(FONT_PATH).resource_path).ends_with("tutorial_zh.ttf"),
		"HUD/enemy reuse the existing tutorial font",
		FONT_PATH
	)
	var spawn_ok: bool = _player.global_position.is_equal_approx(_game.get_spawn_position())
	_check(spawn_ok, "player spawns at (80, 288)", str(_player.global_position))
	_check(
		_golem.global_position.is_equal_approx(_game.get_golem_spawn_position()),
		"golem spawns at (420, 288)",
		str(_golem.global_position)
	)
	_check(_golem.get_hp() == 3 and _golem.get_state_name() == "ACTIVE", "golem starts 3 HP active",
		"hp=%d state=%s" % [_golem.get_hp(), _golem.get_state_name()])
	_check(_golem.is_positive(), "golem starts ORANGE / 辉 (+)", _golem.get_polarity_label())
	_check(absf(_golem.get_scatter_wait_setting() - 8.0) < 0.001,
		"production scatter wait default is 8.0 s",
		"%.1fs" % _golem.get_scatter_wait_setting())
	_check(_game.get_collision_body_count() == 2, "room has floor + one low wall collision",
		str(_game.get_collision_body_count()))
	_check(_golem.get_body_collision_layer() == 0, "golem body never collides with the player",
		"layer=%d" % _golem.get_body_collision_layer())

	# The sheet is a horizontal strip, not one giant frame.
	var idle_size: Vector2 = _golem.get_node("Sprite").texture.get_size()
	_check(
		_golem.get_sprite_frame_count() == 8 and int(idle_size.x / 8.0) == 90
		and int(idle_size.y) == 64,
		"golem idle is 8 frames of 90x64",
		"sheet=%s hframes=%d" % [str(idle_size), _golem.get_sprite_frame_count()]
	)
	_check(
		_golem.get_node("Sprite").offset == Vector2(-45, -64),
		"golem sprite offset aligns the 90x64 strip feet to the node origin",
		str(_golem.get_node("Sprite").offset)
	)
	_check(
		_hud.get_enemy_text().contains("HP") and _hud.get_enemy_text().contains("辉"),
		"HUD shows enemy polarity symbol and HP pips",
		_hud.get_enemy_text()
	)
	_check(_hud.get_attack_text().contains("就绪"), "HUD shows J ready", _hud.get_attack_text())
	_check(
		_hud.get_enemy_state_text().contains("活动"),
		"HUD shows golem state",
		_hud.get_enemy_state_text()
	)
	await _step(2)


func _test_same_phase_hit_and_single_resolution() -> void:
	_section("2a. REAL J / SAME PHASE / ONE RESOLUTION PER SWING")
	await _prepare(300.0, 350.0, 0.35)
	var start_x: float = _golem.global_position.x
	_key_down(KEY_J)
	var hit_phase_seen: bool = false
	var swing_id: int = 0
	for _i: int in range(14):
		await _step(1)
		swing_id = _player.get_attack_swing_id()
		if _player.get_attack_phase_label() == "命中段":
			hit_phase_seen = true
		if _golem.get_hp() < 3:
			break
	await _step(2)
	_check(_player.is_attacking(), "J starts an actual swing", str(_player.is_attacking()))
	_check(swing_id == 1, "first real J produces swing id 1", str(swing_id))
	_check(hit_phase_seen, "hit resolves inside the forward hit window",
		_player.get_attack_phase_label())
	_check(_golem.get_hp() == 2, "same-polarity hit removes exactly 1 HP", "hp=%d" % _golem.get_hp())
	_check(_golem.get_times_damaged() == 1, "one damage application for the swing",
		str(_golem.get_times_damaged()))
	_check(_golem.get_knockback_count() == 1, "same-phase hit applies one knockback",
		str(_golem.get_knockback_count()))
	_check(_golem.global_position.x > start_x + 2.0, "golem is visibly knocked away",
		"x %.1f -> %.1f" % [start_x, _golem.global_position.x])
	var result: Dictionary = _golem.get_last_result()
	_check(String(result.get("code", "")) == "HIT", "result code is HIT", str(result.get("code")))

	# Holding J and injecting OS key-repeat echo must not create more hits.
	for _i: int in range(8):
		_send_key(KEY_J, true, KEY_LOCATION_UNSPECIFIED, true)
		await _step(5)
	_key_up(KEY_J)
	await _step(40)
	_check(_player.get_attack_swing_id() == 1, "held J + echo does not create a second swing",
		str(_player.get_attack_swing_id()))
	_check(_golem.get_hp() == 2 and _golem.get_times_damaged() == 1,
		"held J + echo never repeats damage", "hp=%d" % _golem.get_hp())

	# Direct duplicate resolution with the same swing id is also rejected.
	var before_hp: int = _golem.get_hp()
	var duplicate: Dictionary = _golem.receive_attack(_player, 1, true, swing_id)
	_check(String(duplicate.get("code", "")) == "DUPLICATE_SWING",
		"same swing id cannot resolve twice", str(duplicate.get("code")))
	_check(_golem.get_hp() == before_hp, "duplicate resolution changes no HP", "hp=%d" % _golem.get_hp())


func _test_reverse_and_out_of_range() -> void:
	_section("2b. REVERSE / OUT OF RANGE = NO HIT")
	await _prepare(300.0, 250.0, 0.35)
	_key_down(KEY_J)
	await _step(14)
	_key_up(KEY_J)
	await _step(20)
	_check(_golem.get_hp() == 3, "enemy behind the player takes no damage", "hp=%d" % _golem.get_hp())
	_check(String(_golem.get_last_result().get("code", "")) == "MISS_BEHIND",
		"behind result is MISS_BEHIND", str(_golem.get_last_result().get("code")))

	await _prepare(300.0, 470.0, 0.35)
	_key_down(KEY_J)
	await _step(14)
	_key_up(KEY_J)
	await _step(20)
	_check(_golem.get_hp() == 3, "same-phase target beyond reach takes no damage",
		"hp=%d" % _golem.get_hp())
	_check(String(_golem.get_last_result().get("code", "")) == "MISS_RANGE",
		"far result is MISS_RANGE", str(_golem.get_last_result().get("code")))
	_check(_golem.get_knockback_count() == 0, "miss applies no knockback",
		str(_golem.get_knockback_count()))


func _test_q_snapshot_and_opposite_pull() -> void:
	_section("2c. Q MID-SWING SNAPSHOT / OPPOSITE PULL = ZERO DAMAGE")
	await _prepare(300.0, 350.0, 0.35)
	_key_down(KEY_J)
	# Real Q key event while the swing is already in flight.
	_send_key(KEY_Q, true)
	await _step(1)
	_send_key(KEY_Q, false)
	await _step(10)
	_check(not _player.is_positive(), "Q during the swing really flips player polarity",
		str(_player.is_positive()))
	_check(_player.get_attack_positive_snapshot(), "swing polarity snapshot stays GOLD", 
		str(_player.get_attack_positive_snapshot()))
	_check(_golem.get_hp() == 2, "in-flight swing still deals same-phase damage after Q",
		"hp=%d" % _golem.get_hp())
	_key_up(KEY_J)
	await _step(45)

	# Next swing is CYAN vs ORANGE: opposite phase, no damage, short pull.
	var before_x: float = _golem.global_position.x
	var distance_before: float = before_x - _player.global_position.x
	_key_down(KEY_J)
	await _step(12)
	_key_up(KEY_J)
	await _step(24)
	var distance_after: float = _golem.global_position.x - _player.global_position.x
	_check(String(_golem.get_last_result().get("code", "")) == "PULL",
		"next swing resolves as PULL", str(_golem.get_last_result().get("code")))
	_check(_golem.get_hp() == 2, "opposite-phase pull deals zero damage", "hp=%d" % _golem.get_hp())
	_check(_golem.get_pull_count() == 1, "one pull applied", str(_golem.get_pull_count()))
	_check(distance_before > 60.0, "pull setup starts outside safe distance",
		"%.1f" % distance_before)
	_check(distance_after < distance_before - 5.0, "golem is pulled toward the player",
		"%.1f -> %.1f" % [distance_before, distance_after])
	_check(distance_after >= 40.0, "pull stops before overlapping the player",
		"%.1f" % distance_after)
	_check(distance_after <= 50.0, "pull settles near the 46 px safe distance",
		"%.1f" % distance_after)


func _test_tab_polarity_entry() -> void:
	_section("2d. TAB ENEMY POLARITY ENTRY")
	await _prepare(300.0, 350.0, 0.35)
	_check(_golem.is_positive(), "reset restores ORANGE / 辉 (+)", _golem.get_polarity_label())
	_key_down(KEY_TAB)
	await _step(2)
	_key_up(KEY_TAB)
	await _step(2)
	_check(not _golem.is_positive(), "Tab flips the golem to BLUE / 澜 (-)",
		_golem.get_polarity_label())
	_check(_hud.get_enemy_text().contains("澜"), "HUD shows the non-colour 澜 symbol",
		_hud.get_enemy_text())
	_key_down(KEY_TAB)
	await _step(2)
	_key_up(KEY_TAB)
	await _step(2)
	_check(_golem.is_positive(), "Tab flips back to ORANGE / 辉 (+)", _golem.get_polarity_label())


func _test_wall_blocking() -> void:
	_section("2e. SOLID WALL BLOCKS ATTACK / TETHER")
	# Room wall + opposite phase: the 96 px gap is inside PULL_REACH (130) but
	# the low wall at 544..576 sits between the bodies, so the tether must stop.
	await _prepare(300.0, 350.0, 0.35)
	_send_key(KEY_Q, true)
	await _step(1)
	_send_key(KEY_Q, false)
	await _step(1)
	_check(not _player.is_positive(), "wall-test player is CYAN", str(_player.is_positive()))
	_player.global_position = Vector2(500.0, 288.0)
	_player.velocity = Vector2.ZERO
	_golem.global_position = Vector2(596.0, 288.0)
	await _step(4)
	var before_x: float = _golem.global_position.x
	var before_hp: int = _golem.get_hp()
	_key_down(KEY_J)
	await _step(14)
	_key_up(KEY_J)
	await _step(12)
	_check(String(_golem.get_last_result().get("code", "")) == "BLOCKED",
		"room wall between player and golem reports BLOCKED",
		str(_golem.get_last_result().get("code")))
	_check(_golem.get_hp() == before_hp, "blocked tether deals no damage", "hp=%d" % _golem.get_hp())
	_check(absf(_golem.global_position.x - before_x) < 0.1, "blocked tether does not pull through the wall",
		"x=%.1f" % _golem.global_position.x)
	_log("  room wall rect=%s  player_x=%.1f  golem_x=%.1f" % [
		str(_game.get_wall_rect()), _player.global_position.x, _golem.global_position.x
	])

	# Same-phase, thin temporary blocker: both bodies stay inside ATTACK_REACH
	# (38 px) while the chest ray is interrupted. This is test setup only and is
	# removed immediately; the room wall itself is unchanged.
	await _prepare(300.0, 338.0, 0.35)
	var blocker: StaticBody2D = StaticBody2D.new()
	blocker.name = "TemporaryWallBlocker"
	blocker.collision_layer = 1
	blocker.collision_mask = 1
	blocker.position = Vector2(319.0, 274.0)
	var blocker_shape: CollisionShape2D = CollisionShape2D.new()
	var blocker_rect: RectangleShape2D = RectangleShape2D.new()
	blocker_rect.size = Vector2(6.0, 28.0)
	blocker_shape.shape = blocker_rect
	blocker.add_child(blocker_shape)
	_game.get_node("World").add_child(blocker)
	await _step(3)
	_key_down(KEY_J)
	await _step(14)
	_key_up(KEY_J)
	await _step(8)
	_check(String(_golem.get_last_result().get("code", "")) == "BLOCKED",
		"thin wall inside attack reach blocks the same-phase swing",
		str(_golem.get_last_result().get("code")))
	_check(_golem.get_hp() == 3, "same-phase wall block deals no damage", "hp=%d" % _golem.get_hp())
	blocker.queue_free()
	await _step(3)

	# Knockback must stop at the room wall instead of pushing through it.
	await _prepare(490.0, 530.0, 0.35)
	var pre_knock_x: float = _golem.global_position.x
	_key_down(KEY_J)
	await _step(14)
	_key_up(KEY_J)
	await _step(16)
	_check(_golem.get_hp() == 2, "wall-adjacent same-phase hit still damages",
		"hp=%d" % _golem.get_hp())
	_check(
		_golem.global_position.x > pre_knock_x
		and _golem.global_position.x < 540.0,
		"knockback stops before penetrating the room wall",
		"x %.1f -> %.1f (wall left 544)" % [pre_knock_x, _golem.global_position.x]
	)

	# Repeated same-phase knockback near the right edge stays inside the
	# experiment world bounds instead of pushing the golem out of the room.
	await _prepare(590.0, 606.0, 0.35)
	_key_down(KEY_J)
	await _step(14)
	_key_up(KEY_J)
	await _step(16)
	_check(_golem.get_hp() == 2, "edge same-phase hit damages", "hp=%d" % _golem.get_hp())
	_check(
		_golem.global_position.x <= 612.01 and _golem.global_position.x > 606.0,
		"same-phase knockback clamps at the 612 world bound",
		"x=%.1f (bound 612)" % _golem.global_position.x
	)


func _test_scatter_and_reassemble() -> void:
	_section("3. SCATTER / WAIT / REASSEMBLE (shortened test wait)")
	await _prepare(300.0, 350.0, 0.35)
	_golem.set_scatter_wait_time(0.35)
	_log("  TEST SETUP: scatter wait shortened to 0.35 s (production default 8.0 s)")
	_golem.debug_set_hp(1)
	_check(_golem.get_hp() == 1, "TEST SETUP: golem HP set to 1 for the kill flow",
		"hp=%d" % _golem.get_hp())
	_key_down(KEY_J)
	await _step(12)
	_key_up(KEY_J)
	_check(_golem.get_hp() == 0, "same-phase killing hit removes the last HP",
		"hp=%d" % _golem.get_hp())
	_check(_golem.get_state_name() == "SCATTERING", "HP 0 enters the die/scatter sequence",
		_golem.get_state_name())
	_check(_golem.get_sprite_frame_count() == 13, "die sheet uses 13 frame slots",
		str(_golem.get_sprite_frame_count()))
	var max_frame: int = 0
	for _i: int in range(55):
		await _step(1)
		max_frame = maxi(max_frame, _golem.get_sprite_frame())
		if _golem.get_state_name() == "RUBBLE":
			break
	_check(_golem.get_state_name() == "RUBBLE", "die sequence ends in rubble wait",
		_golem.get_state_name())
	_check(max_frame <= 11, "the empty 13th die frame (index 12) is never shown",
		"max_frame=%d" % max_frame)
	var rubble_x: float = _golem.global_position.x
	var wait_before: float = _golem.get_scatter_wait_remaining()
	_check(wait_before <= 0.36, "shortened wait is active and visible",
		"%.2fs" % wait_before)
	_check(not _golem.is_attackable(), "rubble is not attackable", _golem.get_state_name())
	_check(_golem.get_body_collision_layer() == 0, "rubble has no layer-1 body",
		"layer=%d" % _golem.get_body_collision_layer())

	# Attack while scattered: explicitly no effect and no delayed damage.
	_player.global_position = Vector2(rubble_x - 46.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(2)
	var hp_before_wait: int = _golem.get_hp()
	_key_down(KEY_J)
	await _step(14)
	_key_up(KEY_J)
	_check(String(_golem.get_last_result().get("code", "")) == "INACTIVE",
		"attack during rubble is rejected as INACTIVE",
		str(_golem.get_last_result().get("code")))
	_check(_golem.get_hp() == hp_before_wait, "attack during rubble cannot damage",
		"hp=%d" % _golem.get_hp())
	_check(_golem.get_state_name() == "RUBBLE" or _golem.get_state_name() == "REASSEMBLING",
		"attack does not interrupt the rebuild state", _golem.get_state_name())

	# Stand on the rubble spot: no physics body may lock the player.
	_player.global_position = Vector2(rubble_x, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(10)
	_check(absf(_player.global_position.x - rubble_x) < 1.0,
		"player is not pushed off the rubble spot", "x=%.1f" % _player.global_position.x)
	_check(absf(_player.global_position.y - 288.0) < 0.75, "player stays on solid floor over rubble",
		"y=%.1f" % _player.global_position.y)
	_player.global_position = Vector2(rubble_x - 90.0, 288.0)

	var active: bool = false
	for _i: int in range(180):
		await _step(1)
		if _golem.get_state_name() == "ACTIVE":
			active = true
			break
	_check(active, "golem returns to ACTIVE after the shortened wait",
		_golem.get_state_name())
	_check(_golem.get_hp() == 3, "reassembly restores full 3 HP", "hp=%d" % _golem.get_hp())
	_check(absf(_golem.global_position.x - rubble_x) < 1.0,
		"reassembly happens at the scatter spot, not the initial spawn",
		"%.1f vs %.1f" % [_golem.global_position.x, rubble_x])
	_check(_golem.is_positive(), "reassembly preserves the golem polarity",
		_golem.get_polarity_label())
	_check(_golem.get_times_damaged() == 1, "no delayed post-death damage was applied",
		str(_golem.get_times_damaged()))


func _test_pause_freeze_and_reset_while_waiting() -> void:
	_section("4. PAUSE FREEZE / R DURING RUBBLE")
	await _prepare(300.0, 350.0, 0.35)
	_key_down(KEY_J)
	await _step(4)
	_key_up(KEY_J)
	await _tap_key_process(KEY_ESCAPE)
	_check(_game.is_paused(), "Esc pauses the experiment", str(_game.is_paused()))
	_check(_hud.is_pause_visible(), "pause overlay is visible", str(_hud.is_pause_visible()))
	var elapsed_before: float = _player.get_attack_elapsed()
	var frame_before: int = _player.get_anim_frame()
	await _step(30)
	_check(absf(_player.get_attack_elapsed() - elapsed_before) < 0.0001,
		"attack animation timer freezes while paused",
		"%.4f -> %.4f" % [elapsed_before, _player.get_attack_elapsed()])
	_check(_player.get_anim_frame() == frame_before, "attack sprite frame freezes while paused",
		"%d -> %d" % [frame_before, _player.get_anim_frame()])
	await _tap_key_process(KEY_ESCAPE)
	_check(not _game.is_paused(), "Esc resumes the experiment", str(_game.is_paused()))

	# Get to rubble with a 3 s wait so the paused countdown is unambiguous.
	await _prepare(300.0, 350.0, 3.0)
	_golem.set_scatter_wait_time(3.0)
	_log("  TEST SETUP: scatter wait shortened to 3.0 s for the pause countdown check")
	_golem.debug_set_hp(1)
	_key_down(KEY_J)
	await _step(12)
	_key_up(KEY_J)
	var rubble_ready: bool = false
	for _i: int in range(60):
		await _step(1)
		if _golem.get_state_name() == "RUBBLE":
			rubble_ready = true
			break
	_check(rubble_ready, "golem reaches rubble for the pause check", _golem.get_state_name())
	await _step(10)
	await _tap_key_process(KEY_ESCAPE)
	_check(_game.is_paused(), "Esc pauses during the rubble countdown", str(_game.is_paused()))
	var wait_before: float = _golem.get_scatter_wait_remaining()
	await _step(40)
	_check(absf(_golem.get_scatter_wait_remaining() - wait_before) < 0.05,
		"rubble countdown freezes while paused",
		"%.2f -> %.2f" % [wait_before, _golem.get_scatter_wait_remaining()])
	_check(_golem.get_state_name() == "RUBBLE", "rubble state freezes while paused",
		_golem.get_state_name())

	# R while paused interrupts the wait and restores the whole experiment.
	_key_down(KEY_R)
	await _step(1)
	_key_up(KEY_R)
	await _step(4)
	_check(not _game.is_paused(), "R while paused also resumes the experiment",
		str(_game.is_paused()))
	_check(_golem.get_state_name() == "ACTIVE" and _golem.get_hp() == 3,
		"R while waiting restores the golem active at full HP",
		"%s hp=%d" % [_golem.get_state_name(), _golem.get_hp()])
	_check(_golem.global_position.is_equal_approx(_game.get_golem_spawn_position()),
		"R restores the golem spawn position", str(_golem.global_position))
	_check(_golem.is_positive(), "R restores the initial ORANGE polarity",
		_golem.get_polarity_label())
	_check(_player.global_position.is_equal_approx(_game.get_spawn_position()),
		"R restores the player spawn", str(_player.global_position))
	_check(_player.is_positive(), "R restores player GOLD polarity", str(_player.is_positive()))
	_check(_game.get_last_result().is_empty(), "R clears the last attack result",
		str(_game.get_last_result()))

	# R must also interrupt an in-flight swing, not only the rubble timer.
	_key_down(KEY_J)
	await _step(4)
	_key_up(KEY_J)
	_check(_player.is_attacking(), "R setup: a swing is in flight", str(_player.is_attacking()))
	_key_down(KEY_R)
	await _step(1)
	_key_up(KEY_R)
	await _step(3)
	_check(not _player.is_attacking(), "R cancels the in-flight swing",
		str(_player.is_attacking()))
	_check(_player.get_attack_cooldown() < 0.0001, "R clears the swing cooldown",
		"%.4f" % _player.get_attack_cooldown())


func _test_focus_loss_safe_pause() -> void:
	_section("5. FOCUS LOSS AUTO-PAUSE / INPUT CLEAR")
	await _prepare(300.0, 350.0, 0.35)
	_key_down(KEY_D)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(10)
	_check(_player.is_left_shift_held() and _player.is_sprint_intent(),
		"focus-loss setup is holding left Shift + D",
		"shift=%s sprint=%s" % [
			str(_player.is_left_shift_held()), str(_player.is_sprint_intent())
		])
	_game.handle_focus_lost()
	_check(_game.is_paused(), "focus loss auto-pauses", str(_game.is_paused()))
	_check(_hud.is_pause_visible(), "focus loss shows the pause overlay",
		str(_hud.is_pause_visible()))
	_check(_hud.get_pause_reason_text().contains("失焦"),
		"pause overlay explains the focus-loss reason", _hud.get_pause_reason_text())
	_check(not _player.is_left_shift_held() and not _player.is_sprint_intent(),
		"focus loss clears Shift and sprint latches",
		"shift=%s sprint=%s" % [
			str(_player.is_left_shift_held()), str(_player.is_sprint_intent())
		])
	_check(not _player.is_double_tap_run_locked(), "focus loss clears double-tap run",
		str(_player.is_double_tap_run_locked()))
	await _tap_key_process(KEY_ESCAPE)
	_check(not _game.is_paused(), "Esc resumes after focus-loss pause", str(_game.is_paused()))
	_key_up(KEY_D)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)
	await _step(3)


func _prepare(player_x: float, golem_x: float, wait_seconds: float) -> void:
	_release_all()
	_game.reset_experiment()
	await _step(3)
	_golem.set_scatter_wait_time(wait_seconds)
	_player.global_position = Vector2(player_x, 288.0)
	_player.velocity = Vector2.ZERO
	_golem.global_position = Vector2(golem_x, 288.0)
	await _step(3)


func _send_key(
	key: Key,
	pressed: bool,
	location: KeyLocation = KEY_LOCATION_UNSPECIFIED,
	echo: bool = false
) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.echo = echo
	event.location = location
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key_down(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, true, location, false)


func _key_up(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, false, location, false)


func _tap_key_process(key: Key) -> void:
	_key_down(key)
	await get_tree().process_frame
	await get_tree().process_frame
	_key_up(key)
	await get_tree().process_frame


func _release_all() -> void:
	for key: Key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT, KEY_J, KEY_TAB, KEY_Q, KEY_ESCAPE]:
		_key_up(key)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_RIGHT)
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _step(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _section(title: String) -> void:
	_log("")
	_log("--- %s ---" % title)


func _check(condition: bool, label: String, details: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, ("  (" + details + ")") if details != "" else ""])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, ("  (" + details + ")") if details != "" else ""])
		printerr("[FAIL] %s %s" % [label, details])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	_release_all()
	if get_tree().paused:
		get_tree().paused = false
	var summary: String = "TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count]
	_log("")
	_log(summary)
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/polarity_golem_smoke.log", FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
