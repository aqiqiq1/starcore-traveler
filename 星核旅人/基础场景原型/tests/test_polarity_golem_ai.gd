extends Node

## Minimal AI/slam smoke for the independent polarity-golem experiment.
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/test_polarity_golem_ai.tscn
##
## Scope: real patrol/alert approach/first slam, one knockback per slam,
## 0.6 s protection, real J same-phase interruption (no delayed hit), opposite
## pull keeping the slam alive, behind/jump dodge, wall blocking, pause freeze,
## shortened scatter/reassembly and R restore. No old 104/31 suite, no formal
## levels. The 0.5 s rebuild wait is test-only and logged.

const EXPERIMENT_SCENE: PackedScene = preload(
	"res://scenes/experiments/polarity_golem_experiment.tscn"
)

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

	_log("=== Polarity Golem AI / slam - headless smoke ===")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"], DisplayServer.get_name()
	])
	await _test_load_and_tuning()
	await _test_real_patrol_and_first_slam()
	await _test_single_knockback_and_protection()
	await _test_same_phase_interrupts_slam()
	await _test_opposite_pull_does_not_cancel_slam()
	await _test_dodge_and_wall()
	await _test_pause_freezes_ai_attack_and_protection()
	await _test_scatter_reassemble_reset()
	await _finish()


func _test_load_and_tuning() -> void:
	_section("1. REAL LOAD / TUNING")
	_check(_game != null and _player != null and _golem != null and _hud != null,
		"experiment scene, player, golem and HUD load")
	var tuning: Dictionary = _golem.get_ai_tuning()
	_log("  AI tuning: %s" % str(tuning))
	_check(_golem.get_state_name() == "ACTIVE" and _golem.get_ai_phase_name() == "PATROL",
		"golem starts ACTIVE on patrol",
		"%s / %s" % [_golem.get_state_name(), _golem.get_ai_phase_name()])
	_check(
		is_equal_approx(float(tuning["patrol_left"]), 240.0)
		and is_equal_approx(float(tuning["patrol_right"]), 520.0),
		"bounded patrol strip is 240..520",
		str(_golem.get_patrol_bounds()))
	_check(is_equal_approx(float(tuning["patrol_speed"]), 60.0)
		and is_equal_approx(float(tuning["pursue_speed"]), 100.0),
		"patrol 60 px/s, approach 100 px/s",
		"%.0f / %.0f" % [float(tuning["patrol_speed"]), float(tuning["pursue_speed"])])
	_check(is_equal_approx(float(tuning["alert_range"]), 120.0),
		"alert range is 120 px", "%.0f" % float(tuning["alert_range"]))
	_check(
		is_equal_approx(float(tuning["windup_time"]), 0.28)
		and is_equal_approx(float(tuning["strike_time"]), 0.12)
		and is_equal_approx(float(tuning["recover_time"]), 0.30)
		and is_equal_approx(float(tuning["gap_time"]), 0.15),
		"slam timing is 0.28 / 0.12 / 0.30 / 0.15 s",
		"%.2f/%.2f/%.2f/%.2f" % [
			float(tuning["windup_time"]), float(tuning["strike_time"]),
			float(tuning["recover_time"]), float(tuning["gap_time"])
		])
	_check(
		is_equal_approx(float(tuning["strike_zone_forward"]), 26.0)
		and (tuning["strike_zone_size"] as Vector2).is_equal_approx(Vector2(26.0, 20.0)),
		"live box is the forward fist area (26 px ahead, 26x20), not full screen",
		str(tuning["strike_zone_size"]))
	_check(_golem.get_sprite_frame_count() >= 8,
		"golem uses a real multi-frame strip at load",
		str(_golem.get_sprite_frame_count()))
	_check(_player.get_hit_protection_time() == 0.6
		and _player.get_hit_reaction_time() == 0.15
		and _player.get_hit_knockback_speed() == 160.0,
		"player slam reaction is 0.15 s / 0.6 s protection / 160 px/s",
		"%.2f / %.2f / %.0f" % [
			_player.get_hit_reaction_time(), _player.get_hit_protection_time(),
			_player.get_hit_knockback_speed()
		])
	var idle_tex: Texture2D = load(
		"res://assets/experiments/polarity_golem/enemy/orange/golem_1_idle.png"
	)
	var attack_tex: Texture2D = load(
		"res://assets/experiments/polarity_golem/enemy/orange/golem_1_attack.png"
	)
	_check(idle_tex != null and attack_tex != null
		and idle_tex.get_size() == Vector2(720.0, 64.0)
		and attack_tex.get_size() == Vector2(990.0, 64.0),
		"idle sheet is 8x90x64 and attack sheet is 11x90x64",
		"%s / %s" % [
			str(idle_tex.get_size() if idle_tex != null else Vector2.ZERO),
			str(attack_tex.get_size() if attack_tex != null else Vector2.ZERO)
		])
	_check(not _player.has_method("get_hp"),
		"player has no HP pool: a slam only knocks back",
		"has get_hp=%s" % str(_player.has_method("get_hp")))
	_check(_hud.get_native_font_size() == 12, "HUD keeps native 12 px text",
		str(_hud.get_native_font_size()))
	await _step(2)


func _test_real_patrol_and_first_slam() -> void:
	_section("2. REAL PATROL / ALERT APPROACH / FIRST SLAM")
	await _prepare(80.0, 420.0)
	var patrol_start: float = _golem.global_position.x
	await _step(60)
	var patrol_end: float = _golem.global_position.x
	_check(patrol_end - patrol_start >= 40.0 and patrol_end - patrol_start <= 75.0,
		"far player: golem walks about 60 px in 1 s instead of idling",
		"x %.1f -> %.1f" % [patrol_start, patrol_end])
	_check(_golem.is_ai_walking_visual(), "patrol uses the authentic walk sheet",
		_golem.get_sprite_texture_path())

	await _prepare(300.0, 420.0)
	var start_player_x: float = _player.global_position.x
	var saw_pursue: bool = false
	var hit_frame: int = -1
	for index: int in range(120):
		await _step(1)
		if _golem.get_ai_phase_name() == "PURSUE":
			saw_pursue = true
		if _player.get_hit_count() > 0:
			hit_frame = index + 1
			break
	var hit_seconds: float = float(hit_frame) / 60.0
	_check(saw_pursue, "player inside ~120 px triggers a real approach")
	_check(
		(_golem.get_node("Sprite") as Sprite2D).flip_h
		and (_golem.get_node("HeadReadout") as Node2D).scale.is_equal_approx(Vector2.ONE),
		"facing only mirrors the Sprite, not the head readout",
		"sprite flip=%s head scale=%s" % [
			str((_golem.get_node("Sprite") as Sprite2D).flip_h),
			str((_golem.get_node("HeadReadout") as Node2D).scale)
		])
	_check(hit_frame > 0, "standing in front gets a real slam",
		"frame=%d" % hit_frame)
	_check(hit_frame >= 30 and hit_frame <= 110,
		"first slam lands in the ~1 s range (approach + 0.28 s warning)",
		"%.2f s" % hit_seconds)
	_check(_player.get_hit_count() == 1, "the first slam applies one hit",
		str(_player.get_hit_count()))
	_check(String(_golem.get_last_strike_code()) == "HIT",
		"strike code is HIT", _golem.get_last_strike_code())
	_check(_player.get_hit_protection_remaining() > 0.45,
		"hit starts the 0.6 s protection window",
		"%.2f s" % _player.get_hit_protection_remaining())

	await _step(4)
	_check(_player.is_in_hit_reaction(),
		"the short 0.15 s hit reaction is active right after contact",
		"%.2f s" % _player.get_hit_reaction_remaining())
	await _step(8)
	_check(not _player.is_in_hit_reaction(), "the reaction ends within about 0.15 s",
		"%.2f s" % _player.get_hit_reaction_remaining())
	await _step(8)
	var pushed_x: float = _player.global_position.x
	_check(start_player_x - pushed_x >= 18.0 and start_player_x - pushed_x <= 55.0,
		"slam visibly pushes the player away by a short distance",
		"x %.1f -> %.1f (%.1f px)" % [
			start_player_x, pushed_x, start_player_x - pushed_x
		])
	_check(absf(_player.global_position.y - 288.0) < 0.75,
		"knockback stays on the real floor", "y=%.1f" % _player.global_position.y)
	_check(not _player.is_in_hit_reaction(), "the 0.15 s reaction has already ended",
		"%.2f s" % _player.get_hit_reaction_remaining())
	await _step(10)
	_check(_player.get_hit_count() == 1,
		"the same slam cannot knock the player a second time",
		str(_player.get_hit_count()))


func _test_single_knockback_and_protection() -> void:
	_section("3. ONE KNOCKBACK PER SLAM / 0.6 s PROTECTION")
	await _prepare(300.0, 420.0)
	var hit_base: int = _player.get_hit_count()
	for _i: int in range(120):
		await _step(1)
		if _player.get_hit_count() > hit_base:
			break
	_check(_player.get_hit_count() == hit_base + 1, "setup got one natural slam hit",
		str(_player.get_hit_count()))
	var hit_x: float = _player.global_position.x
	await _step(10)
	_check(_player.get_hit_count() == hit_base + 1, "strike window does not add a second hit",
		str(_player.get_hit_count()))
	var accepted_while_protected: bool = _player.receive_enemy_strike(1)
	_check(not accepted_while_protected,
		"new contact is rejected while protection is active")
	_check(_player.get_hit_count() == hit_base + 1, "rejected protection contact adds no hit",
		str(_player.get_hit_count()))
	await _step(12)
	_check(_player.get_hit_protection_remaining() > 0.15,
		"protection is still active about one third of a second after contact",
		"%.2f s" % _player.get_hit_protection_remaining())
	await _step(30)
	var accepted_after: bool = _player.receive_enemy_strike(1)
	_check(accepted_after and _player.get_hit_count() == hit_base + 2,
		"protection expires and a later contact is accepted",
		"count=%d" % _player.get_hit_count())

	# Holding a direction at the moment of contact must not erase the push.
	await _prepare(300.0, 420.0)
	_key_down(KEY_D)
	await _step(6)
	var held_x: float = _player.global_position.x
	var held_hit: bool = _player.receive_enemy_strike(-1)
	await _step(8)
	_key_up(KEY_D)
	_check(held_hit and _player.global_position.x <= held_x - 10.0,
		"knockback stays visible even while the player holds toward the enemy",
		"x %.1f -> %.1f" % [held_x, _player.global_position.x])
	await _step(3)
	_log("  natural hit x=%.1f; protection-gated manual contacts verified" % hit_x)


func _test_same_phase_interrupts_slam() -> void:
	_section("4a. REAL J SAME PHASE CANCELS THE WINDUP")
	await _prepare(346.0, 380.0)
	var windup_seen: bool = await _wait_for_windup(80)
	_check(windup_seen, "golem reaches the arm-raise warning",
		_golem.get_ai_phase_label())
	var enemy_x_before: float = _golem.global_position.x
	_key_down(KEY_J)
	await _step(2)
	_key_up(KEY_J)
	var hp_dropped: bool = false
	for _i: int in range(24):
		await _step(1)
		if _golem.get_hp() == 2:
			hp_dropped = true
			break
	_check(hp_dropped, "same-phase J removes 1 HP during the warning",
		"hp=%d" % _golem.get_hp())
	await _step(8)
	_check(_golem.global_position.x > enemy_x_before + 5.0,
		"the hurt knockback moves the golem before the AI resumes",
		"x %.1f -> %.1f" % [enemy_x_before, _golem.global_position.x])
	_check(_golem.get_state_name() == "HURT" or _golem.get_ai_phase_name() != "ATTACK",
		"the slam is interrupted (HURT / no ATTACK phase)",
		"%s / %s" % [_golem.get_state_name(), _golem.get_ai_phase_name()])
	await _step(18)
	_check(_player.get_hit_count() == 0,
		"cancelled slam never lands a delayed hit in its original window",
		str(_player.get_hit_count()))
	_check(_golem.get_last_strike_code() != "HIT",
		"no strike was resolved by the interrupted slam",
		_golem.get_last_strike_code())


func _test_opposite_pull_does_not_cancel_slam() -> void:
	_section("4b. OPPOSITE PULL = NO DAMAGE, SLAM CONTINUES")
	await _prepare(346.0, 380.0)
	_send_key(KEY_Q, true)
	await _step(1)
	_send_key(KEY_Q, false)
	await _step(1)
	_check(not _player.is_positive(), "Q really switches the player to 澜相 -",
		str(_player.is_positive()))
	var windup_seen: bool = await _wait_for_windup(80)
	_check(windup_seen, "golem is in the same windup before the opposite J",
		_golem.get_ai_phase_label())
	_key_down(KEY_J)
	await _step(2)
	_key_up(KEY_J)
	await _step(10)
	var result: Dictionary = _golem.get_last_result()
	_check(String(result.get("code", "")) == "PULL_ALREADY_CLOSE",
		"opposite J resolves as a zero-damage close pull",
		str(result.get("code")))
	_check(_golem.get_hp() == 3, "opposite pull changes no HP", "hp=%d" % _golem.get_hp())
	var saw_strike: bool = false
	for _i: int in range(30):
		await _step(1)
		if _golem.get_ai_phase_label() == "砸击":
			saw_strike = true
		if _player.get_hit_count() > 0:
			break
	_check(saw_strike, "the existing slam still reaches its strike segment")
	_check(_player.get_hit_count() == 1,
		"the slam still hits the player after the pull",
		str(_player.get_hit_count()))
	_check(not _player.is_attacking(),
		"the landed slam interrupts the in-flight player swing")
	_check(_golem.get_hp() == 3, "the interrupted swing leaves no delayed HP damage",
		"hp=%d" % _golem.get_hp())


func _test_dodge_and_wall() -> void:
	_section("5. DODGE / WALL")
	await _prepare(346.0, 380.0)
	_check(await _wait_for_windup(80), "windup before the behind-dodge")
	_player.global_position = Vector2(420.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(34)
	_check(_player.get_hit_count() == 0,
		"stepping behind the locked slam avoids the fist",
		str(_player.get_hit_count()))

	await _prepare(346.0, 380.0)
	_check(await _wait_for_windup(80), "windup before the jump-dodge")
	_send_key(KEY_SPACE, true)
	await _step(1)
	_send_key(KEY_SPACE, false)
	await _step(34)
	_check(_player.get_hit_count() == 0,
		"jumping over the downward fist avoids it",
		"feet y=%.1f" % _player.global_position.y)

	await _prepare(346.0, 380.0)
	var blocker: StaticBody2D = StaticBody2D.new()
	blocker.name = "AIWallBlocker"
	blocker.collision_layer = 1
	blocker.collision_mask = 1
	blocker.position = Vector2(360.0, 274.0)
	var blocker_shape: CollisionShape2D = CollisionShape2D.new()
	var blocker_rect: RectangleShape2D = RectangleShape2D.new()
	blocker_rect.size = Vector2(6.0, 28.0)
	blocker_shape.shape = blocker_rect
	blocker.add_child(blocker_shape)
	_game.get_node("World").add_child(blocker)
	await _step(2)
	_golem.debug_begin_attack(1)
	await _step(30)
	_check(_golem.get_last_strike_code() == "BLOCKED",
		"a wall between the fist and the player blocks the slam",
		_golem.get_last_strike_code())
	_check(_player.get_hit_count() == 0, "blocked slam applies no knockback",
		str(_player.get_hit_count()))
	blocker.queue_free()
	await _step(2)

	# Knockback uses real movement, so the low wall stops it instead of
	# teleporting the player through x=544.
	await _prepare(530.0, 496.0)
	_golem.debug_begin_attack(1)
	for _i: int in range(30):
		await _step(1)
		if _player.get_hit_count() > 0:
			break
	await _step(10)
	_check(_player.get_hit_count() == 1, "wall-adjacent slam still knocks back",
		str(_player.get_hit_count()))
	_check(_player.global_position.x <= 538.5,
		"player knockback is stopped by the real low wall, never teleported through",
		"x=%.1f (wall left 544, body half 6)" % _player.global_position.x)

	# The real low wall also blocks alert/approach from the far right.
	await _prepare(600.0, 500.0)
	await _step(30)
	_check(_golem.get_ai_phase_name() != "PURSUE",
		"real low wall blocks alert/approach across it",
		_golem.get_ai_phase_name())
	_check(_player.get_hit_count() == 0, "no slam through the real low wall",
		str(_player.get_hit_count()))


func _test_pause_freezes_ai_attack_and_protection() -> void:
	_section("6. PAUSE FREEZES AI / WINDUP / PROTECTION")
	await _prepare(80.0, 420.0)
	await _step(10)
	await _tap_key_process(KEY_ESCAPE)
	_check(_game.is_paused(), "Esc pauses the experiment")
	var patrol_x: float = _golem.global_position.x
	await _step(20)
	_check(absf(_golem.global_position.x - patrol_x) < 0.01,
		"patrol is frozen while paused",
		"x %.2f -> %.2f" % [patrol_x, _golem.global_position.x])
	await _tap_key_process(KEY_ESCAPE)
	_check(not _game.is_paused(), "Esc resumes the experiment")

	await _prepare(346.0, 380.0)
	_check(await _wait_for_windup(80), "windup for the pause check")
	await _tap_key_process(KEY_ESCAPE)
	var elapsed_before: float = _golem.get_attack_elapsed_time()
	var frame_before: int = _golem.get_sprite_frame()
	await _step(20)
	_check(absf(_golem.get_attack_elapsed_time() - elapsed_before) < 0.0001
		and _golem.get_sprite_frame() == frame_before,
		"windup timer and attack frame freeze while paused",
		"%.3f / %d" % [_golem.get_attack_elapsed_time(), _golem.get_sprite_frame()])
	await _tap_key_process(KEY_ESCAPE)
	await _step(30)

	await _prepare(300.0, 420.0)
	var hit_base: int = _player.get_hit_count()
	for _i: int in range(120):
		await _step(1)
		if _player.get_hit_count() > hit_base:
			break
	_check(_player.get_hit_count() == hit_base + 1, "pause setup got one natural hit",
		str(_player.get_hit_count()))
	await _tap_key_process(KEY_ESCAPE)
	var protect_before: float = _player.get_hit_protection_remaining()
	var knockback_before: Vector2 = _player.global_position
	await _step(20)
	_check(absf(_player.get_hit_protection_remaining() - protect_before) < 0.0001,
		"0.6 s protection countdown freezes while paused",
		"%.3f -> %.3f" % [protect_before, _player.get_hit_protection_remaining()])
	_check(_player.global_position.is_equal_approx(knockback_before),
		"paused player knockback does not continue",
		str(_player.global_position))
	await _tap_key_process(KEY_ESCAPE)
	await _step(3)


func _test_scatter_reassemble_reset() -> void:
	_section("7. SCATTER / REASSEMBLE / PAUSE / R (shortened wait)")
	await _prepare(346.0, 380.0)
	_golem.set_scatter_wait_time(0.5)
	_golem.debug_set_hp(1)
	_log("  TEST SETUP: scatter wait shortened to 0.5 s (production default 8.0 s)")
	_check(await _wait_for_windup(80), "windup before the killing same-phase J")
	_key_down(KEY_J)
	await _step(8)
	_key_up(KEY_J)
	_check(_golem.get_hp() == 0 and _golem.get_state_name() == "SCATTERING",
		"same-phase J scatters the golem at 0 HP",
		"%s hp=%d" % [_golem.get_state_name(), _golem.get_hp()])
	var rubble_ready: bool = false
	for _i: int in range(70):
		await _step(1)
		if _golem.get_state_name() == "RUBBLE":
			rubble_ready = true
			break
	_check(rubble_ready, "die sequence reaches the rubble wait",
		_golem.get_state_name())
	_check(_golem.get_sprite_visible()
		and _golem.get_sprite_frame() == 11
		and _golem.get_sprite_texture_path().ends_with("golem_1_die.png"),
		"RUBBLE holds authentic die frame 11 visibly",
		"frame=%d %s" % [_golem.get_sprite_frame(), _golem.get_sprite_texture_path()])
	_check(_golem.get_scatter_wait_remaining() <= 0.5,
		"shortened wait is active", "%.2f" % _golem.get_scatter_wait_remaining())
	_check(_golem.get_ai_phase_name() == "RUBBLE",
		"no patrol/pursue/attack while scattered", _golem.get_ai_phase_name())

	await _tap_key_process(KEY_ESCAPE)
	var wait_before: float = _golem.get_scatter_wait_remaining()
	await _step(20)
	_check(absf(_golem.get_scatter_wait_remaining() - wait_before) < 0.0001,
		"reassembly countdown freezes while paused",
		"%.3f -> %.3f" % [wait_before, _golem.get_scatter_wait_remaining()])
	_key_down(KEY_R)
	await _step(1)
	_key_up(KEY_R)
	await _step(4)
	_check(not _game.is_paused(), "R while paused resumes the experiment")
	_check(_golem.get_state_name() == "ACTIVE" and _golem.get_hp() == 3
		and _golem.get_ai_phase_name() == "PATROL",
		"R restores ACTIVE / full HP / initial patrol",
		"%s hp=%d %s" % [
			_golem.get_state_name(), _golem.get_hp(), _golem.get_ai_phase_name()
		])
	_check(_golem.global_position.distance_to(_game.get_golem_spawn_position()) <= 6.0,
		"R restores the golem spawn (AI resumes patrol from there)",
		str(_golem.global_position))
	_check(_player.get_hit_protection_remaining() == 0.0
		and _player.get_hit_count() == 0,
		"R clears protection and hit count",
		"protect=%.2f count=%d" % [
			_player.get_hit_protection_remaining(), _player.get_hit_count()
		])
	_check(_player.global_position.is_equal_approx(_game.get_spawn_position()),
		"R restores the player spawn", str(_player.global_position))

	# Reassembly at the scatter spot, then a real warning before it can hit.
	await _prepare(346.0, 380.0)
	_golem.set_scatter_wait_time(0.5)
	_golem.debug_set_hp(1)
	_check(await _wait_for_windup(80), "windup before the reassembly test kill")
	_key_down(KEY_J)
	await _step(8)
	_key_up(KEY_J)
	for _i: int in range(80):
		await _step(1)
		if _golem.get_state_name() == "RUBBLE":
			break
	var rubble_x: float = _golem.global_position.x
	var active_frame: int = -1
	for index: int in range(140):
		await _step(1)
		if _golem.get_state_name() == "ACTIVE":
			active_frame = index + 1
			break
	_check(active_frame > 0, "reassembly returns to ACTIVE", _golem.get_state_name())
	_check(absf(_golem.global_position.x - rubble_x) < 1.0,
		"reassembly happens at the scatter spot",
		"%.1f vs %.1f" % [_golem.global_position.x, rubble_x])
	_check(_golem.get_hp() == 3, "reassembly restores 3 HP", "hp=%d" % _golem.get_hp())
	var hits_at_active: int = _player.get_hit_count()
	await _step(18)
	_check(_player.get_hit_count() == hits_at_active,
		"revive does not hit with zero warning in the first 0.3 s",
		str(_player.get_hit_count()))
	var post_active_hit_frame: int = -1
	for index: int in range(90):
		await _step(1)
		if _player.get_hit_count() > hits_at_active:
			post_active_hit_frame = index + 1
			break
	var revive_to_hit_seconds: float = float(18 + post_active_hit_frame) / 60.0
	_check(revive_to_hit_seconds >= 0.55,
		"the first post-revive slam still has the full windup warning",
		"%.2f s after ACTIVE" % revive_to_hit_seconds)


func _prepare(player_x: float, golem_x: float) -> void:
	_release_all()
	_game.reset_experiment()
	await _step(3)
	_player.global_position = Vector2(player_x, 288.0)
	_player.velocity = Vector2.ZERO
	_golem.global_position = Vector2(golem_x, 288.0)
	_golem.velocity = Vector2.ZERO
	await _step(3)


func _wait_for_windup(max_frames: int) -> bool:
	for _i: int in range(max_frames):
		await _step(1)
		if _golem.get_ai_phase_label() == "举臂预警":
			return true
	return false


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
	for key: Key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT, KEY_J, KEY_TAB, KEY_Q, KEY_SPACE, KEY_ESCAPE]:
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
		"res://tests/logs/polarity_golem_ai_smoke.log", FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
