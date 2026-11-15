extends Node

## Focused acceptance for the polarity guard integrated into formal level 02.
##
## Run headless:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/test_level02_guard.tscn
##
## Scope is only the new integration: bridge guard placement/AI limits, colour
## only head readout, real J/Q combat, the fixed right ledge, reset/pause/
## completion cleanup and one short local transport route. It does not rerun the
## old full level-02 suite, the old 104/84/31 suites, level 01 or level 03.
##
## The short route explicitly starts from a logged setup: the moving core is
## already past the left throat at (343,312) and the player at (142,320). From
## there every step uses real InputMap actions and real key events; the core is
## never teleported to the target seat, E is real and completion is the exit gate.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const EXPERIMENT_SCENE: PackedScene = preload(
	"res://scenes/experiments/polarity_golem_experiment.tscn"
)
const LOG_PATH: String = "res://tests/logs/level02_guard_test.log"
const UPPER_Y: float = 264.0
const HIGH_STEP_Y: float = 274.0
const GROUND_Y: float = 320.0

var _level: Level02
var _player: PrototypePlayer
var _combat_player = null
var _guard = null
var _core: StarCoreCarrier
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("=== Level 02 polarity guard integration - focused headless test ===")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"], DisplayServer.get_name()
	])
	await _load_level()
	await _test_load_readout_and_experiment()
	await _test_guard_bridge_limits()
	await _test_ground_player_safety()
	await _test_right_ledge_and_core_pass()
	await _test_real_jq_combat()
	await _test_scatter_pause_and_reset()
	await _test_other_reset_paths()
	await _test_local_integration_route()
	_finish()


func _load_level() -> void:
	_level = LEVEL_SCENE.instantiate() as Level02
	add_child(_level)
	await _step(4)
	_player = _level.get_player()
	_combat_player = _level.get_player()
	_guard = _level.get_guard()
	_core = _level.get_core()


# ---------------------------------------------------------------------------
# A. Load, colour-only head readout, experiment still loads
# ---------------------------------------------------------------------------

func _test_load_readout_and_experiment() -> void:
	_section("A. LOAD / HEAD READOUT / EXPERIMENT")
	_check(_level != null and _player != null and _guard != null,
		"formal level 02 loads with player and bridge guard")
	_check(_combat_player.has_method("request_attack")
		and _combat_player.has_method("receive_enemy_strike"),
		"level player uses the local swing/hit subclass, not the shared script")
	_check(_guard.get_state_name() == "ACTIVE", "guard starts ACTIVE",
		_guard.get_state_name())
	_check(_guard.get_hp() == 3 and _guard.get_max_hp() == 3,
		"guard starts at 3 / 3 HP")
	_check(_guard.is_positive(), "guard keeps its fixed initial bright phase")
	var tuning: Dictionary = _guard.get_ai_tuning()
	_check(
		is_equal_approx(float(tuning["windup_time"]), 0.28)
		and is_equal_approx(float(tuning["strike_time"]), 0.12)
		and is_equal_approx(float(tuning["recover_time"]), 0.30)
		and is_equal_approx(float(tuning["gap_time"]), 0.15),
		"approved 0.28 / 0.12 / 0.30 / 0.15 s slam timing is unchanged",
		"%.2f/%.2f/%.2f/%.2f" % [
			float(tuning["windup_time"]), float(tuning["strike_time"]),
			float(tuning["recover_time"]), float(tuning["gap_time"])
		])
	_check(_combat_player.get_hit_protection_time() == 0.6
		and _combat_player.get_hit_reaction_time() == 0.15
		and _combat_player.get_hit_knockback_speed() == 160.0,
		"player short knockback / 0.15 s reaction / 0.6 s protection unchanged",
		"%.2f / %.2f / %.0f" % [
			_combat_player.get_hit_reaction_time(),
			_combat_player.get_hit_protection_time(),
			_combat_player.get_hit_knockback_speed()
		])
	_check(_guard.get_head_tag_text() == "",
		"no polarity word/sign above the guard by default",
		_guard.get_head_tag_text())
	_check(_guard.show_polarity_label == false,
		"show_polarity_label defaults false")
	_check(_guard.get_head_overlay_z_index() >= 10,
		"HP readout stays on a high-z child",
		str(_guard.get_head_overlay_z_index()))
	var bar: Rect2 = _guard.get_head_bar_rect()
	_check(bar.size == Vector2(42.0, 6.0), "3-pip HP bar rectangle remains",
		str(bar))

	var grid: Rect2 = _level.get_upper_platform_rect()
	var corridor_label: Label = _level.get_node("CorridorLabel") as Label
	var upper_label: Label = _level.get_node("UpperLabel") as Label
	_check(grid == Rect2(232.0, 264.0, 168.0, 6.0),
		"formal upper platform is still the real x=232..400, top 264, 6 px deck",
		str(grid))
	_check(corridor_label.offset_bottom <= 200.0 and upper_label.offset_bottom <= 200.0,
		"both world labels moved to y<=200 so the guard bar at y=208 is clear",
		"%s / %s" % [str(corridor_label.offset_bottom), str(upper_label.offset_bottom)])
	_check(corridor_label.offset_bottom < bar.position.y
		and upper_label.offset_bottom < bar.position.y,
		"label bottoms stay above the guard HP bar",
		"label=%.0f bar_top=%.0f" % [
			maxf(corridor_label.offset_bottom, upper_label.offset_bottom), bar.position.y
		])

	# Two phases via setup, inspected as colours/texture families, not two
	# separate GUI screenshots.
	var orange_color: Color = _guard.get_polarity_text_color()
	var orange_path: String = _guard.get_sprite_texture_path()
	_check(_guard.set_polarity_positive(false), "test setup can switch guard to the blue phase")
	var blue_color: Color = _guard.get_polarity_text_color()
	var blue_path: String = _guard.get_sprite_texture_path()
	_check(orange_color == Color("#ffa94d") and blue_color == Color("#64c8ff"),
		"orange-gold and cyan-blue body phases stay distinguishable",
		"%s / %s" % [str(orange_color), str(blue_color)])
	_check(orange_path.contains("/orange/") and blue_path.contains("/blue/"),
		"each phase uses its own orange/blue body sheet",
		"%s / %s" % [orange_path, blue_path])
	_guard.set_polarity_positive(true)
	_check(_guard.get_head_tag_text() == "",
		"head stays wordless in either colour phase")

	# The standalone experiment still loads and now follows the same head rule,
	# while its debug HUD keeps the diagnostic enemy polarity text.
	var experiment = EXPERIMENT_SCENE.instantiate()
	add_child(experiment)
	await _step(3)
	var exp_golem = experiment.get_golem()
	var exp_hud = experiment.get_hud()
	_check(exp_golem != null and exp_golem.show_polarity_label == false,
		"standalone experiment guard head also defaults wordless")
	_check(exp_golem.get_head_tag_text() == "",
		"experiment head has no polarity text under the latest rule")
	_check(String(exp_hud.get_enemy_text()).contains("辉相"),
		"experiment debug HUD still exposes enemy polarity for diagnosis",
		exp_hud.get_enemy_text())
	experiment.queue_free()
	await _step(2)

	# The formal instance's stele pages stay short and carry every new rule.
	var pages: PackedStringArray = _level.get_start_stele().pages
	var joined: String = "\n".join(pages)
	var all_short: bool = not pages.is_empty()
	for page: String in pages:
		if page.split("\n").size() > 3:
			all_short = false
	_check(pages.size() == 6 and all_short,
		"level-02 stele has six short pages of at most three lines",
		"%d pages" % pages.size())
	for term: String in ["相反", "低廊", "嵌缝", "橙金", "青蓝", "扣血", "牵引", "8 秒", "入仓", "出口"]:
		_check(joined.contains(term), "stele covers: %s" % term)
	_check(not joined.contains("必须击杀") and not joined.contains("自动入仓"),
		"stele never requires killing or claims automatic storage")

	# The formal level's pause reference gained J without altering shared pause.
	_check(_level.get_pause_menu() != null, "shared pause page is present")
	var pause_page = _level.get_pause_menu()
	var rows: Array = pause_page.controls_rows
	_check(rows.size() > 4 and String(rows[4][1]) == "J",
		"pause controls right column lists J for the guard swing",
		str(rows))


# ---------------------------------------------------------------------------
# B. Guard only on the bridge; never falls, never reaches old experiment points
# ---------------------------------------------------------------------------

func _test_guard_bridge_limits() -> void:
	_section("B. BRIDGE-ONLY SPAWN / BOUNDED PATROL")
	await _restart()
	_check(_level.get_guard_spawn_position() == Vector2(344.0, 264.0),
		"guard authored foot point is (344,264)",
		str(_level.get_guard_spawn_position()))
	_check(absf(_guard.global_position.x - 344.0) <= 6.0
		and absf(_guard.global_position.y - 264.0) < 0.1,
		"guard reset starts at the authored bridge point",
		str(_guard.global_position))
	_check(is_equal_approx(_guard.floor_y, 264.0),
		"guard floor_y comes from the bridge top, not the experiment 288",
		"%.0f" % _guard.floor_y)
	_check(_guard.get_world_bounds() == Vector2(244.0, 388.0),
		"pull/knockback world clamp is the safe bridge strip 244..388",
		str(_guard.get_world_bounds()))
	_check(_guard.get_patrol_bounds() == Vector2(260.0, 376.0),
		"patrol strip is 260..376",
		str(_guard.get_patrol_bounds()))
	_check(_guard.get_pursuit_bounds() == Vector2(244.0, 388.0),
		"pursuit strip is 244..388",
		str(_guard.get_pursuit_bounds()))
	var shape: CollisionShape2D = _guard.get_node("CollisionShape2D") as CollisionShape2D
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	_check(rect.size == Vector2(20.0, 30.0), "guard collision body is 20 x 30",
		str(rect.size))

	# Keep the player far away so this section measures only patrol bounds.
	_player.global_position = Vector2(60.0, GROUND_Y)
	_player.velocity = Vector2.ZERO
	await _step(3)
	var min_x: float = 1e20
	var max_x: float = -1e20
	var min_y: float = 1e20
	var max_y: float = -1e20
	var ever_not_on_bridge: bool = false
	for _i: int in range(240):
		await get_tree().physics_frame
		min_x = minf(min_x, _guard.global_position.x)
		max_x = maxf(max_x, _guard.global_position.x)
		min_y = minf(min_y, _guard.global_position.y)
		max_y = maxf(max_y, _guard.global_position.y)
		if (
			_guard.global_position.y < 263.9
			or _guard.global_position.y > 264.1
			or _guard.global_position.x < 244.0
			or _guard.global_position.x > 388.0
		):
			ever_not_on_bridge = true
	_check(not ever_not_on_bridge,
		"four seconds of patrol never leaves the legal bridge strip or falls",
		"x %.1f..%.1f y %.1f..%.1f" % [min_x, max_x, min_y, max_y])
	_check(min_x >= 260.0 - 0.5 and max_x <= 376.0 + 0.5,
		"patrol actually stays inside 260..376",
		"x %.1f..%.1f" % [min_x, max_x])
	_check(absf(min_y - 264.0) < 0.01 and absf(max_y - 264.0) < 0.01,
		"guard foot stays exactly on y=264 (no lower corridor, no floor 288)",
		"y %.2f..%.2f" % [min_y, max_y])
	_check(_guard.global_position.x < 400.0 and _guard.global_position.x > 232.0,
		"guard never teleports to the old experiment point x=420")


# ---------------------------------------------------------------------------
# C. A ground player 56 px below is not a melee target
# ---------------------------------------------------------------------------

func _test_ground_player_safety() -> void:
	_section("C. GROUND PLAYER 56 px BELOW / NO SLAM THROUGH DECK")
	await _restart()
	_player.global_position = Vector2(344.0, 319.5)
	_player.velocity = Vector2.ZERO
	_guard.global_position = Vector2(344.0, 264.0)
	_guard.velocity = Vector2.ZERO
	await _step(4)
	var saw_attack: bool = false
	for _i: int in range(120):
		await get_tree().physics_frame
		if _guard.get_ai_phase_name() == "ATTACK":
			saw_attack = true
	_check(not saw_attack,
		"a player 56 px below on the ground never makes the bridge guard slam",
		_guard.get_ai_phase_name())
	_check(_combat_player.get_hit_count() == 0,
		"no hit reaches the ground player", str(_combat_player.get_hit_count()))
	_check(absf(_player.global_position.y - GROUND_Y) < 0.75,
		"player remains on the real ground", "y=%.1f" % _player.global_position.y)

	# Even a forced setup slam must not reach a body 56 px below.
	_guard.debug_begin_attack(1)
	await _step(20)
	_check(_combat_player.get_hit_count() == 0,
		"forced telegraphed slam still cannot hit the ground player",
		"%s / hits=%d" % [_guard.get_last_strike_code(), _combat_player.get_hit_count()])
	_check(String(_guard.get_last_strike_code()) in ["MISS", "BLOCKED", ""],
		"strike result is MISS/BLOCKED, never HIT",
		_guard.get_last_strike_code())


# ---------------------------------------------------------------------------
# D. Right ledge fix + real player block + core pass/recovery
# ---------------------------------------------------------------------------

func _test_right_ledge_and_core_pass() -> void:
	_section("D. RIGHT LEDGE 32x24 / PLAYER BLOCK / CORE PASS")
	await _restart()
	var ledge: Level02Block = _level.get_node("RightLedge") as Level02Block
	var ledge_rect: Rect2 = ledge.get_block_rect()
	_check(ledge.get_block_size() == Vector2(32.0, 24.0),
		"RightLedge block_size is the fixed 32 x 24", str(ledge.get_block_size()))
	_check(ledge_rect == Rect2(400.0, 276.0, 32.0, 24.0),
		"RightLedge real rect is x=400..432, y=276..300", str(ledge_rect))
	_check(is_equal_approx(ledge_rect.end.y, 300.0),
		"ledge bottom is y=300, matching the approved facade lower edge")
	_check(is_equal_approx(GROUND_Y - ledge_rect.end.y, 20.0),
		"net clearance under the ledge is 20 px")
	var core_shape_node: CollisionShape2D = (
		_core.get_node("CollisionShape2D") as CollisionShape2D
	)
	var core_shape: RectangleShape2D = core_shape_node.shape as RectangleShape2D
	_check(core_shape.size.y == 16.0 and core_shape.size.y < 20.0,
		"16 px core still fits the 20 px under-ledge band",
		str(core_shape.size))

	# Walking left from the right side must stop on the real ledge face.
	_player.global_position = Vector2(470.0, GROUND_Y)
	_player.velocity = Vector2.ZERO
	await _step(3)
	Input.action_press(&"move_left")
	var walk_min_x: float = 1e20
	for _i: int in range(80):
		await get_tree().physics_frame
		walk_min_x = minf(walk_min_x, _player.global_position.x)
	Input.action_release(&"move_left")
	await _step(3)
	_check(walk_min_x >= 437.5,
		"walking into the right underpass is blocked by real collision",
		"min x=%.1f" % walk_min_x)

	# Running left also cannot enter.
	_player.global_position = Vector2(500.0, GROUND_Y)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	Input.action_press(&"move_left")
	var run_min_x: float = 1e20
	for _i: int in range(90):
		await get_tree().physics_frame
		run_min_x = minf(run_min_x, _player.global_position.x)
	Input.action_release(&"move_left")
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	await _step(3)
	_check(run_min_x >= 437.5,
		"running into the right underpass is blocked by real collision",
		"min x=%.1f" % run_min_x)

	# Jumping left must not place the body inside the under-ledge volume.
	_player.global_position = Vector2(450.0, GROUND_Y)
	_player.velocity = Vector2.ZERO
	await _step(3)
	Input.action_press(&"move_left")
	Input.action_press(&"jump")
	await _step(2)
	Input.action_release(&"jump")
	var entered_underpass: bool = false
	for _i: int in range(70):
		await get_tree().physics_frame
		if (
			_player.global_position.x < 437.5
			and _player.global_position.y > 278.0
			and _player.global_position.y < 320.5
		):
			entered_underpass = true
	Input.action_release(&"move_left")
	await _step(5)
	_check(not entered_underpass,
		"jumping into the right underpass never crosses the real face",
		"end=%s" % str(_player.global_position))

	# Core was already released in setup: it can be pushed right through the
	# 20 px band and then attracted back left; the player is only a field source.
	var hits_before_transport: int = _combat_player.get_hit_count()
	_core.activate_at(Vector2(420.0, 312.0), true)
	_player.global_position = Vector2(350.0, GROUND_Y)
	_player.velocity = Vector2.ZERO
	await _step(3)
	for _i: int in range(90):
		await get_tree().physics_frame
		if _core.global_position.x >= 444.0:
			break
	var pushed_x: float = _core.global_position.x
	_check(pushed_x >= 444.0,
		"same-phase field pushes the core out under/past the right ledge",
		"core x=%.1f" % pushed_x)
	_check(absf(_core.global_position.y - 312.0) < 1.0,
		"core stays on the 20 px lower band, not embedded in the ledge",
		"y=%.1f" % _core.global_position.y)
	_player.global_position = Vector2(530.0, GROUND_Y)
	_player.velocity = Vector2.ZERO
	await _step(3)
	for _i: int in range(120):
		await get_tree().physics_frame
		if _core.global_position.x <= 430.0:
			break
	_check(_core.global_position.x <= 430.0,
		"same-phase field can recover the core back under the ledge",
		"core x=%.1f" % _core.global_position.x)
	_check(_combat_player.get_hit_count() == hits_before_transport,
		"the bridge guard never adds a hit during ground transport",
		"%d -> %d" % [
			hits_before_transport, _combat_player.get_hit_count()
		])

	# The upper seams still pass the unchanged field ray while solid beams
	# block it. This is a local field check, not a rerun of the old suite.
	_guard.set_ai_suspended(true)
	_core.activate_at(Vector2(320.0, 312.0), false)
	_player.global_position = Vector2(360.0, UPPER_Y)
	_player.velocity = Vector2.ZERO
	await _step(3)
	var seam_field: Dictionary = _level.compute_field(
		_player.global_position + Vector2(0.0, -15.0),
		_core.global_position,
		_player.is_positive(),
		_core.is_positive()
	)
	_check(String(seam_field["status"]) == "ATTRACT"
		and not bool(seam_field["blocked"]),
		"a real upper seam passes the unchanged attraction ray to the core",
		"%s blocked=%s" % [
			String(seam_field["status"]), str(seam_field["blocked"])
		])
	var seam_core_before: float = _core.global_position.x
	await _step(14)
	_check(_core.global_position.x > seam_core_before + 0.5,
		"the seam field moves the core through the real 8 px opening",
		"core x %.1f -> %.1f" % [seam_core_before, _core.global_position.x])
	_guard.set_ai_suspended(false)


# ---------------------------------------------------------------------------
# E. Real J/Q same-phase damage/interrupt and opposite pull
# ---------------------------------------------------------------------------

func _test_real_jq_combat() -> void:
	_section("E. REAL J/Q COMBAT")
	await _restart()
	await _place_bridge_player(296.0)
	var swing_before: int = _combat_player.get_attack_swing_id()
	_send_key(KEY_J, true)
	await _step(1)
	# Key-repeat echo while held must not start a second swing.
	_send_key(KEY_J, true, KEY_LOCATION_UNSPECIFIED, true)
	await _step(24)
	_send_key(KEY_J, false)
	await _step(2)
	_check(_combat_player.get_attack_swing_id() == swing_before + 1,
		"one real J press makes exactly one swing; held echo adds none",
		"%d -> %d" % [swing_before, _combat_player.get_attack_swing_id()])
	_check(_guard.get_hp() == 2,
		"same-phase J removes exactly 1 HP", str(_guard.get_hp()))
	_check(_guard.get_times_damaged() == 1 and _guard.get_knockback_count() >= 1,
		"same-phase J damages and knocks the guard back",
		"damage=%d knock=%d" % [
			_guard.get_times_damaged(), _guard.get_knockback_count()
		])
	_check(not _core.is_active(),
		"J never activates, pushes or stores the star core")

	# Same-phase hit during windup cancels the slam and leaves no delayed hit.
	await _restart()
	await _place_bridge_player(296.0)
	_guard.debug_begin_attack(-1)
	await _step(2)
	_send_key(KEY_J, true)
	await _step(1)
	_send_key(KEY_J, false)
	for _i: int in range(24):
		await get_tree().physics_frame
		if _guard.get_state_name() == "HURT":
			break
	_check(_guard.get_state_name() == "HURT",
		"same-phase J interrupts the raised slam", _guard.get_state_name())
	await _step(45)
	_check(_combat_player.get_hit_count() == 0,
		"the interrupted slam has no delayed hit", str(_combat_player.get_hit_count()))
	_check(_guard.get_hp() == 2, "interrupted guard still lost one HP",
		str(_guard.get_hp()))

	# Opposite phase pulls without damage and does not cancel a live slam.
	await _restart()
	_player.global_position = Vector2(284.0, UPPER_Y)
	_player.velocity = Vector2.ZERO
	await _step(3)
	_send_key(KEY_Q, true)
	await _step(2)
	_send_key(KEY_Q, false)
	await _step(2)
	_check(not _player.is_positive(), "real Q switches the player to the blue phase")
	_guard.debug_begin_attack(-1)
	await _step(2)
	var attack_before: float = _guard.get_attack_elapsed_time()
	_send_key(KEY_J, true)
	await _step(1)
	_send_key(KEY_J, false)
	await _step(10)
	_check(_guard.get_hp() == 3,
		"opposite-phase J deals no damage", str(_guard.get_hp()))
	_check(_guard.get_pull_count() == 1,
		"opposite-phase J performs one tether pull",
		str(_guard.get_pull_count()))
	_check(_guard.get_ai_phase_name() == "ATTACK"
		and _guard.get_attack_elapsed_time() > attack_before,
		"opposite-phase pull does not cancel the already-raised slam",
		"%s %.2f->%.2f" % [
			_guard.get_ai_phase_name(), attack_before, _guard.get_attack_elapsed_time()
		])


# ---------------------------------------------------------------------------
# F. Scatter / pause freeze / real R restore
# ---------------------------------------------------------------------------

func _test_scatter_pause_and_reset() -> void:
	_section("F. SCATTER / PAUSE / R RESTORE")
	await _restart()
	await _place_bridge_player(296.0)
	_guard.debug_set_hp(1)
	_send_key(KEY_J, true)
	await _step(1)
	_send_key(KEY_J, false)
	for _i: int in range(30):
		await get_tree().physics_frame
		if _guard.get_state_name() in ["SCATTERING", "RUBBLE"]:
			break
	_check(_guard.get_hp() == 0, "final same-phase hit scatters the guard",
		str(_guard.get_hp()))
	_check(_guard.is_scattered(), "guard enters the scatter/reassemble state",
		_guard.get_state_name())
	for _i: int in range(80):
		await get_tree().physics_frame
		if _guard.get_state_name() == "RUBBLE":
			break
	_check(_guard.get_state_name() == "RUBBLE",
		"guard reaches the visible wait state", _guard.get_state_name())
	_check(_guard.get_sprite_visible() and _guard.get_sprite_frame() == 11,
		"wait uses authentic die frame 11 and stays visible",
		"frame=%d visible=%s" % [
			_guard.get_sprite_frame(), str(_guard.get_sprite_visible())
		])
	_check(_guard.get_head_tag_text().contains("秒后重组"),
		"neutral scatter countdown stays readable", _guard.get_head_tag_text())
	_check(not _guard.get_head_tag_text().contains("辉相")
		and not _guard.get_head_tag_text().contains("澜相"),
		"countdown text carries no polarity word")

	var wait_before: float = _guard.get_scatter_wait_remaining()
	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await _step(2)
	_check(get_tree().paused, "Esc opens the real pause page")
	var swing_at_pause: int = _combat_player.get_attack_swing_id()
	await _step(30)
	_check(absf(_guard.get_scatter_wait_remaining() - wait_before) < 0.02,
		"scatter wait timer freezes while paused",
		"%.2f -> %.2f" % [wait_before, _guard.get_scatter_wait_remaining()])
	_send_key(KEY_J, true)
	await _step(6)
	_send_key(KEY_J, false)
	_check(_combat_player.get_attack_swing_id() == swing_at_pause,
		"J cannot fire through the pause page")
	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await _step(2)
	_check(not get_tree().paused, "Esc resumes the level")

	# A fresh real R restores player and guard completely.
	_send_key(KEY_R, true)
	await get_tree().process_frame
	_send_key(KEY_R, false)
	await _step(6)
	_check(not _level.is_completed(), "R leaves the level incomplete")
	_check(_player.global_position == _level.get_spawn_position(),
		"R restores the player spawn", str(_player.global_position))
	_check(absf(_guard.global_position.x - _level.get_guard_spawn_position().x) <= 8.0
		and absf(_guard.global_position.y - 264.0) < 0.1,
		"R restores the guard bridge spawn",
		str(_guard.global_position))
	_check(_guard.get_hp() == 3 and _guard.is_positive()
		and _guard.get_state_name() == "ACTIVE",
		"R restores guard full HP, initial phase and ACTIVE AI",
		"%d HP %s %s" % [
			_guard.get_hp(), str(_guard.is_positive()), _guard.get_state_name()
		])
	_check(not _combat_player.is_attacking(),
		"R clears any in-flight player swing")
	_check(_combat_player.get_hit_protection_remaining() <= 0.0
		and not _combat_player.is_in_hit_reaction(),
		"R clears player hit protection/reaction")
	_check(not _combat_player.is_completion_locked(),
		"R releases the completion input lock")


# ---------------------------------------------------------------------------
# F2. Pause restart / player fall / core out-of-bounds all restore the guard
# ---------------------------------------------------------------------------

func _test_other_reset_paths() -> void:
	_section("F2. PAUSE RESTART / FALL / CORE OUT RESET")

	# Pause restart through the real shared page.
	await _restart()
	_guard.debug_set_hp(2)
	_guard.set_polarity_positive(false)
	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await _step(2)
	_check(get_tree().paused, "pause page is open before a paused R restart")
	_send_key(KEY_R, true)
	await get_tree().process_frame
	_send_key(KEY_R, false)
	await _step(6)
	_check(not get_tree().paused and not _level.is_completed(),
		"paused R returns to play")
	_check(absf(_guard.global_position.x - _level.get_guard_spawn_position().x) <= 8.0
		and _guard.get_hp() == 3 and _guard.is_positive()
		and _guard.get_state_name() == "ACTIVE",
		"paused R restores guard spawn/HP/phase/AI",
		"%s %dHP %s %s" % [
			str(_guard.global_position), _guard.get_hp(),
			str(_guard.is_positive()), _guard.get_state_name()
		])

	# Player fall below kill_y triggers the shared reset path.
	await _restart()
	_guard.debug_set_hp(2)
	_guard.set_polarity_positive(false)
	_combat_player.receive_enemy_strike(1)
	_player.global_position = Vector2(200.0, 410.0)
	_player.velocity = Vector2.ZERO
	await _step(5)
	_check(_player.global_position == _level.get_spawn_position(),
		"fall reset returns the player to spawn", str(_player.global_position))
	_check(absf(_guard.global_position.x - _level.get_guard_spawn_position().x) <= 8.0
		and _guard.get_hp() == 3 and _guard.is_positive(),
		"fall reset restores guard spawn/HP/phase",
		"%s %dHP %s" % [
			str(_guard.global_position), _guard.get_hp(), str(_guard.is_positive())
		])
	_check(_combat_player.get_hit_protection_remaining() <= 0.0
		and not _combat_player.is_in_hit_reaction(),
		"fall reset clears player hit protection/reaction")

	# Core out of bounds also restores the guard and player once.
	await _restart()
	_guard.debug_set_hp(2)
	_guard.set_polarity_positive(false)
	_core.activate_at(Vector2(700.0, 312.0), false)
	await _step(4)
	_check(_player.global_position == _level.get_spawn_position(),
		"core-out reset returns the player to spawn", str(_player.global_position))
	_check(not _core.is_active(), "core-out reset deactivates the moving core")
	_check(absf(_guard.global_position.x - _level.get_guard_spawn_position().x) <= 8.0
		and _guard.get_hp() == 3 and _guard.is_positive()
		and _guard.get_state_name() == "ACTIVE",
		"core-out reset restores guard spawn/HP/phase/AI",
		"%s %dHP %s %s" % [
			str(_guard.global_position), _guard.get_hp(),
			str(_guard.is_positive()), _guard.get_state_name()
		])


# ---------------------------------------------------------------------------
# G. Local integrated route: setup past throat -> bridge guard -> drop ->
#    real right pull -> E store -> real exit completion -> cleanup
# ---------------------------------------------------------------------------

func _test_local_integration_route() -> void:
	_section("G. LOCAL INTEGRATION ROUTE")
	await _restart()
	# SETUP (explicit): the left release/push is not replayed. The moving core
	# is already past the left throat at the previous approved x~343, and the
	# player stands before the high step. Nothing about the target/exit result
	# is pre-set; all of it is earned below with real input.
	_core.activate_at(Vector2(343.0, 312.0), false)
	_player.global_position = Vector2(142.0, GROUND_Y)
	_player.velocity = Vector2.ZERO
	await _step(4)
	_log("  SETUP core=(343,312,negative) player=(142,320); target bay still EMPTY")

	var on_upper: bool = false
	for _attempt: int in range(3):
		if (
			_player.is_on_floor()
			and absf(_player.global_position.y - HIGH_STEP_Y) <= 2.0
		):
			await _try_platform_jump(UPPER_Y, 232.0, 300.0, 120)
		elif (
			_player.is_on_floor()
			and absf(_player.global_position.y - UPPER_Y) <= 2.0
		):
			on_upper = true
			break
		else:
			await _move_to_x(142.0, 180, true)
			await _try_platform_jump(HIGH_STEP_Y, 150.0, 208.0, 120)
			await _try_platform_jump(UPPER_Y, 232.0, 300.0, 120)
		if (
			_player.is_on_floor()
			and absf(_player.global_position.y - UPPER_Y) <= 2.0
			and _player.global_position.x >= 232.0
		):
			on_upper = true
			break
	_check(on_upper, "real jump route reaches the upper bridge",
		str(_player.global_position))
	if not on_upper:
		return

	# Meet the guard and land one same-phase J so the bridge is really contested.
	var guard_hp_before: int = _guard.get_hp()
	var swing_landed: bool = false
	for _attempt: int in range(14):
		var gap: float = _guard.global_position.x - _player.global_position.x
		if gap > 5.0 and gap < 52.0:
			_send_key(KEY_J, true)
			await _step(1)
			_send_key(KEY_J, false)
			for _i: int in range(20):
				await get_tree().physics_frame
				if _guard.get_hp() < guard_hp_before:
					break
			if _guard.get_hp() < guard_hp_before:
				swing_landed = true
				break
		if gap <= 5.0:
			await _move_to_x(_guard.global_position.x - 48.0, 60, true)
		else:
			await _move_to_x(_guard.global_position.x - 48.0, 60)
	_check(swing_landed,
		"player meets the guard on the bridge and real J lands",
		"guard=%s player=%s" % [str(_guard.global_position), str(_player.global_position)])
	if not swing_landed:
		return

	# Continue right, drop off the deck and the repaired ledge to the ground.
	await _move_to_x(394.0, 220)
	await _move_right_until(
		func() -> bool:
			return (
				_player.is_on_floor()
				and _player.global_position.y >= 318.0
				and _player.global_position.x >= 438.0
			),
		260
	)
	_check(_player.global_position.y >= 318.0
		and _player.global_position.x >= 438.0,
		"player descends on the right and can still meet the core side",
		str(_player.global_position))
	await _move_to_x(440.0, 120, true)
	_check(_core.global_position.x > 320.0,
		"core remains in the lower corridor after the bridge fight",
		"core x=%.1f" % _core.global_position.x)

	# Real ground pull toward the target seat, short steps, no teleport.
	var ready: bool = false
	for _pull_step: int in range(7):
		var pull_target: float = clampf(_core.global_position.x + 70.0, 440.0, 560.0)
		await _move_to_x(pull_target, 200)
		await _step(30)
		_log("  ground pull %d player=%s core=%s status=%s" % [
			_pull_step, str(_player.global_position), str(_core.global_position),
			_level.get_last_status()
		])
		if bool(_level._find_store_bay().get("ok", false)):
			ready = true
			break
	if not ready:
		for _i: int in range(180):
			await get_tree().physics_frame
			if bool(_level._find_store_bay().get("ok", false)):
				ready = true
				break
	_check(ready, "real 100 px field brings the core into the target seat",
		"player=%s core=%s" % [str(_player.global_position), str(_core.global_position)])
	if not ready:
		return

	await _move_to_x(548.0, 120)
	await _step(8)
	_send_key(KEY_E, true)
	await get_tree().process_frame
	_send_key(KEY_E, false)
	for _i: int in range(120):
		await get_tree().physics_frame
		if _level.get_target_bay().is_locked():
			break
	_check(_level.get_target_bay().is_locked(),
		"real E stores and locks the target bay",
		"core=%s" % str(_core.global_position))

	await _move_to_x(600.0, 300)
	await _step(8)
	_check(_level.is_completed(),
		"real exit gate completes the local integrated route",
		"completed=%s" % str(_level.is_completed()))
	if not _level.is_completed():
		return

	# Completion must not leave a swing, a guard attack, or a way for a hit
	# reaction ending to release the player input lock.
	var completed_x: float = _player.global_position.x
	_check(_combat_player.is_completion_locked(),
		"completion hard-locks the level player")
	_check(_guard.is_ai_suspended(),
		"completion freezes the guard AI/timers")
	_check(_guard.get_ai_phase_name() != "ATTACK",
		"completion leaves no live guard slam", _guard.get_ai_phase_name())
	var swing_at_complete: int = _combat_player.get_attack_swing_id()
	_send_key(KEY_J, true)
	await _step(2)
	_send_key(KEY_J, false)
	await _step(50)
	_check(_combat_player.get_attack_swing_id() == swing_at_complete,
		"J cannot fire on the completion page")
	_check(absf(_player.global_position.x - completed_x) < 0.01,
		"completion input lock keeps the player from walking behind the panel",
		"x %.2f -> %.2f" % [completed_x, _player.global_position.x])
	_check(not _combat_player.receive_enemy_strike(1),
		"no post-completion slam reaction is accepted")
	await _step(10)
	_check(_player.is_input_override_active(),
		"override remains after a would-be 0.6 s protection window",
		"override=%s" % str(_player.is_input_override_active()))

	# Real R from the completion page restores both actors.
	_send_key(KEY_R, true)
	await get_tree().process_frame
	_send_key(KEY_R, false)
	await _step(6)
	_check(not _level.is_completed(), "R clears the completion page")
	_check(absf(_guard.global_position.x - _level.get_guard_spawn_position().x) <= 8.0
		and _guard.get_hp() == 3 and _guard.is_positive(),
		"R restores the guard after completion",
		"%s %dHP %s" % [
			str(_guard.global_position), _guard.get_hp(), str(_guard.is_positive())
		])
	_check(not _combat_player.is_completion_locked()
		and not _player.is_input_override_active(),
		"R releases the completion lock and player override")


# ---------------------------------------------------------------------------
# Input / route helpers
# ---------------------------------------------------------------------------

func _restart() -> void:
	_release_all()
	_level._restart_level()
	await _step(4)


func _place_bridge_player(player_x: float) -> void:
	_player.global_position = Vector2(player_x, UPPER_Y)
	_player.velocity = Vector2.ZERO
	_guard.global_position = Vector2(344.0, UPPER_Y)
	_guard.velocity = Vector2.ZERO
	await _step(4)
	# A brief real D press makes the swing snapshot face right.
	Input.action_press(&"move_right")
	await _step(2)
	Input.action_release(&"move_right")
	await _step(2)


func _try_platform_jump(
	target_y: float, min_x: float, max_x: float, max_frames: int
) -> bool:
	Input.action_press(&"move_right")
	await _tap_key(KEY_SPACE)
	var landed: bool = false
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if (
			_player.is_on_floor()
			and absf(_player.global_position.y - target_y) <= 2.0
			and _player.global_position.x >= min_x
			and _player.global_position.x <= max_x
		):
			landed = true
			break
	Input.action_release(&"move_right")
	await _step(5)
	return landed


func _move_to_x(target_x: float, max_frames: int, move_left: bool = false) -> void:
	var action: StringName = &"move_left" if move_left else &"move_right"
	Input.action_press(action)
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if move_left:
			if _player.global_position.x <= target_x:
				break
		else:
			if _player.global_position.x >= target_x:
				break
	Input.action_release(action)
	await _step(6)


func _move_right_until(condition: Callable, max_frames: int) -> void:
	Input.action_press(&"move_right")
	for _i: int in range(max_frames):
		await get_tree().physics_frame
		if bool(condition.call()):
			break
	Input.action_release(&"move_right")
	await _step(5)


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


func _tap_key(key: Key) -> void:
	_send_key(key, true)
	await get_tree().process_frame
	_send_key(key, false)
	await get_tree().process_frame
	await get_tree().physics_frame


func _release_all() -> void:
	for key: Key in [
		KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT, KEY_J, KEY_Q, KEY_SPACE,
		KEY_ESCAPE, KEY_R, KEY_E
	]:
		_send_key(key, false)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_RIGHT)
	for action: StringName in [
		&"move_left", &"move_right", &"jump", &"polarity", &"reset",
		&"pause", &"interact"
	]:
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
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
