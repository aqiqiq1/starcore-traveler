extends Node

## Third-round parity checks for the trial:
##   - three DlcGuide pages use the approved copy and the real 24-frame demos;
##   - the shared MechanicPopup opens all three trial tips from real state,
##     swallows Esc, closes with F and never repeats;
##   - the popup cannot open during the guide, pause page, failure recovery or
##     completion page, and opening it never opens the pause page as a side
##     effect;
##   - the pause page is 360x236 with four entries and the completion page is
##     400x210 with two entries.
##
##   ... --headless --path . res://dlc/trial_chambers/tests/teaching_test.tscn
##
## The route itself is walked for real; only the guard resets and the final
## completion setup use the guard's existing debug helpers, as in the other
## trial tests.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"

const GATE_PAGE_TITLE: String = "门只放同相的人"
const GATE_PAGE_BODY: String = (
	"试炼场的门由星核的辉、澜两面铸成。\n"
	+ "只放同相的人通过，门前立着相性晶体。\n"
	+ "第一道门靠晶体翻相；第二道门靠换相。"
)
const GATE_PAGE_KEY: String = "与门同色时按 {Q} 换相，门就会打开。"
const INSIDE_PAGE_TITLE: String = "门内的相性"
const INSIDE_PAGE_BODY: String = (
	"门只认相性：同相放行，异相拦停。\n"
	+ "门上大号日/月图标就是所需相性。\n"
	+ "门内换相不会被夹住，离开后才恢复。"
)
const INSIDE_PAGE_KEY: String = "门里换相不会被夹住，走出去后门才重新合拢。"
const GUARD_PAGE_TITLE: String = "守卫的胸口余烬"
const GUARD_PAGE_BODY: String = (
	"守卫胸口锁着星核余烬，蓄力时以引力拖近。\n"
	+ "蓄力时换相，被吸近后用攻击打弱点 ×3。\n"
	+ "两次受击失败，试炼场送你回入口。"
)
const GUARD_PAGE_KEY: String = "等它蓄力时换成异相，贴近后按 {J} 打弱点。"

const DENY_TIP_BODY: String = (
	"守卫的壳由星核余烬凝成。\n"
	+ "同相或未蓄力的攻击只碎壳。\n"
	+ "等它蓄力、切异相、贴近再打，才会留下真伤。"
)
const HIT_TIP_BODY: String = (
	"守卫胸口锁着星核余烬。\n"
	+ "蓄力时用引力把你拖近；切异相。\n"
	+ "被吸近后攻击弱点；每次真伤后换相。"
)
const HIT_TIP_KEY: String = "蓄力时换成异相，被吸近后按 {J} 打弱点。"

var _trial: TrialChambers
var _player: L3Player
var _guard: L3Guard
var _hud: TrialHUD
var _popup: MechanicPopup
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	MechanicTips.reset_for_test()
	await _run()
	await _cleanup()
	print("TRIAL_TEACHING_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


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
	await _wait_process(2)


## The shared guide swaps page copy at the midpoint of a 0.12 s crossfade.
func _wait_page_transition(guide: DlcGuide) -> void:
	for _index: int in range(600):
		if not guide.is_page_transitioning():
			return
		await get_tree().process_frame


func _hold_right(frames: int) -> void:
	Input.action_press(&"move_right")
	await _wait_physics(frames)
	Input.action_release(&"move_right")
	await _wait_physics(2)


func _tap_polarity() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(1)
	Input.action_release(&"polarity")
	await _wait_physics(4)


func _push_click(position: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.global_position = position
	get_viewport().push_input(down, true)
	await _wait_process(1)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.global_position = position
	get_viewport().push_input(up, true)
	await _wait_process(2)


func _place_player(point: Vector2) -> void:
	_player.global_position = point
	_player.velocity = Vector2.ZERO
	await _wait_physics(3)


func _display_width(line: String) -> float:
	var width: float = 0.0
	for index: int in range(line.length()):
		var code: int = line.unicode_at(index)
		width += 1.0 if code >= 0x2E80 else 0.5
	return width


func _body_fits(body: String, max_lines: int = 3, max_width: float = 21.0) -> bool:
	var lines: PackedStringArray = body.split("\n", true)
	if lines.size() > max_lines:
		return false
	for line: String in lines:
		if _display_width(line) > max_width:
			return false
	return true


## The rework bans the old "noun + key" legend rows.  A natural key line is a
## sentence that ends with a full stop and uses no list separator.
func _is_natural_key(key_text: String) -> bool:
	return (
		key_text.ends_with("。")
		and not key_text.contains("·")
		and not key_text.contains("=")
		and not key_text.contains("|")
	)


func _label_line_count(parent: Node, text: String) -> int:
	for node: Node in parent.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.text == text:
			return label.get_line_count()
	return -1


## Key rows are RichTextLabel now: compare the decorated BBCode, then return the
## rendered line count.
func _rich_line_count(parent: Node, raw: String) -> int:
	var expected: String = KeyGlyph.decorate(raw)
	for node: Node in parent.find_children("*", "RichTextLabel", true, false):
		var label: RichTextLabel = node as RichTextLabel
		if label != null and label.text == expected:
			return label.get_line_count()
	return -1


## A standalone Q/J/E/F (not the E of "Esc") is banned outside key rows.
func _has_bare_key_letter(text: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("(^|[^A-Za-z])[QJEF]([^A-Za-z]|$)")
	return regex.search(text) != null


func _cleanup() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	_push_key(KEY_J, false)
	get_tree().paused = false
	await _wait_process(2)
	if _trial != null and is_instance_valid(_trial):
		var ambience: DlcChapterAmbience = _trial.get_ambience()
		if ambience != null:
			ambience.stop(0.0)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	_trial = null
	await _wait_process(2)
	# Let the audio thread and the exit tweens release their objects before quit.
	for _index: int in range(20):
		await get_tree().process_frame


# --- main ----------------------------------------------------------------

func _run() -> void:
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	_check(packed != null, "trial scene loads")
	if packed == null:
		return
	_trial = packed.instantiate() as TrialChambers
	_trial.show_intro_guide = true
	_trial.show_intro_cinematic = false
	_trial.show_mechanic_tips = true
	get_tree().root.add_child(_trial)
	get_tree().current_scene = _trial
	await _wait_process(8)
	await _wait_physics(8)
	_player = _trial.get_player()
	_guard = _trial.get_guard()
	_hud = _trial.get_hud()
	_popup = _trial.get_mechanic_popup()
	_check(_player != null and _guard != null and _hud != null, "trial exposes its live nodes")
	_check(_popup != null, "trial creates the shared MechanicPopup")
	if _popup == null:
		return
	_check(_popup.level_node == _trial, "popup level_node is the trial")
	_check(not _popup.is_open(), "no popup before the guide closes")

	await _check_guide()
	await _check_gate_icons()
	await _walk_the_route()
	await _check_guard_deny_tip()
	await _check_guard_hit_tip()
	await _check_pause_blocks_popup()
	await _check_recovery_blocks_popup()
	await _check_completion_blocks_popup()


func _check_guide() -> void:
	print("=== GUIDE PAGES ===")
	var guide: DlcGuide = _trial.get_intro_guide()
	_check(guide != null, "trial auto-creates the shared guide")
	if guide == null:
		return
	_check(guide.is_open(), "guide opens at level start")
	_check(get_tree().paused, "guide pauses the tree")
	_check(not _hud.is_hit_pips_visible(), "intro guide hides the fixed health bar")
	var guide_bar: PlayerHealthBar = _hud.get_hit_pips()
	_check(guide_bar != null and guide_bar.get_style_name() == "bar"
		and _hud.get_hit_pips_position() == Vector2(14.0, 324.0),
		"the health value stays a bar fixed at (14,324) under the guide")
	_check(_trial.is_mechanic_popup_blocked(), "guide blocks the popup")
	_check(guide.get_page_count() == 3, "guide has three trial pages",
		str(guide.get_page_count()))

	var pages: Array[Dictionary] = [
		{
			"title": GATE_PAGE_TITLE, "body": GATE_PAGE_BODY,
			"key": GATE_PAGE_KEY, "demo": "trial_gate",
		},
		{
			"title": INSIDE_PAGE_TITLE, "body": INSIDE_PAGE_BODY,
			"key": INSIDE_PAGE_KEY, "demo": "trial_gate_inside",
		},
		{
			"title": GUARD_PAGE_TITLE, "body": GUARD_PAGE_BODY,
			"key": GUARD_PAGE_KEY, "demo": "trial_guard_hit",
		},
	]
	for index: int in range(pages.size()):
		if index > 0:
			await _tap_key(KEY_F)
			await _wait_page_transition(guide)
		var page: Dictionary = pages[index]
		_check(guide.is_open(), "guide stays open on page %d" % (index + 1))
		_check(guide.get_page_index() == index,
			"guide page index is %d" % index, str(guide.get_page_index()))
		_check(guide.get_title_text() == String(page["title"]),
			"page %d title matches the spec" % (index + 1), guide.get_title_text())
		_check(guide.get_body_text() == String(page["body"]),
			"page %d body matches the approved 3-line copy" % (index + 1))
		_check(guide.get_key_text() == KeyGlyph.plain(String(page["key"])),
			"page %d key plain matches the spec" % (index + 1), guide.get_key_text())
		_check(not _has_bare_key_letter(guide.get_title_text()),
			"page %d title has no bare Q/J/E/F" % (index + 1))
		_check(not _has_bare_key_letter(guide.get_body_text()),
			"page %d body has no bare Q/J/E/F" % (index + 1))
		if String(page["key"]).contains("{"):
			_check(guide.get_key_rich_text().contains("[img=16x16]"),
				"page %d key row renders a 16x16 keycap" % (index + 1),
				guide.get_key_rich_text())
		_check(not guide.get_key_text().contains("[img]")
			and not guide.get_key_text().contains("{"),
			"page %d get_key_text is plain, not markup" % (index + 1))
		_check(guide.get_demo_id() == String(page["demo"]),
			"page %d demo id is %s" % [index + 1, String(page["demo"])],
			guide.get_demo_id())
		_check(guide.get_demo_frame_count() == 24,
			"page %d demo is 24 frames" % (index + 1),
			str(guide.get_demo_frame_count()))
		_check(is_equal_approx(guide.get_demo_fps(), 8.0),
			"page %d demo runs at 8 fps" % (index + 1),
			"%.2f" % guide.get_demo_fps())
		_check(_body_fits(String(page["body"])),
			"page %d body is at most 3 lines / 21 cells" % (index + 1))
		_check(_label_line_count(guide, String(page["body"])) in [1, 2, 3],
			"page %d body renders in at most 3 lines" % (index + 1),
			str(_label_line_count(guide, String(page["body"]))))
		_check(_is_natural_key(guide.get_key_text()),
			"page %d key is a natural sentence, not a noun+key legend" % (index + 1),
			guide.get_key_text())
		_check(_rich_line_count(guide, String(page["key"])) in [1, 2],
			"page %d key renders in at most 2 lines" % (index + 1),
			str(_rich_line_count(guide, String(page["key"]))))

	# The first page really animates while the tree is paused.
	await _wait_seconds(0.35)
	_check(guide.get_demo_frame() > 0, "page 1 demo advances while paused",
		"frame=%d" % guide.get_demo_frame())

	_check(guide.get_footer_text() == "F 关闭 · 长按空格 跳过",
		"last footer plain text keeps the F name", guide.get_footer_text())
	_check(guide.get_footer_rich_text().contains("[img=16x16]"),
		"footer renders the F keycap", guide.get_footer_rich_text())
	await _tap_key(KEY_F)
	await _wait_process(5)
	_check(not guide.is_open(), "F closes the last guide page")
	_check(not get_tree().paused, "closing the guide unpauses the tree")
	_check(_hud.is_hit_pips_visible(), "closing the guide shows the fixed health bar")


func _check_gate_icons() -> void:
	print("=== GATE ICONS ===")
	var ids: Array[String] = MechanicPopup.get_registered_tip_ids()
	_check(not ids.has("trial_gate_tip"),
		"the old gate text popup is no longer registered", str(ids))
	_check(not MechanicTips.has_seen("trial_gate_tip"),
		"no gate text popup was ever marked seen")
	await _place_player(Vector2(238.0, 320.0))
	await _wait_process(12)
	_check(not _popup.is_open(), "standing before the gate opens no text popup")
	await _hold_right(30)
	_check(not _trial.get_gate_gold().is_open(),
		"gold gate still blocks a cyan player")
	_check(_trial.get_q_hint().is_active(),
		"wrong-phase contact shows the icon-only Q keycap")
	_check(not _popup.is_open(), "the rejection is icon-only, not a popup")
	_check(not get_tree().paused, "the icon feedback never pauses the tree")
	await _place_player(Vector2(198.0, 320.0))
	_player.set_polarity_state(false)
	await _wait_physics(4)
	_check(not _player.is_positive(), "route setup is back to the 澜相 start")


func _walk_the_route() -> void:
	print("=== ROUTE ===")
	# The real route: walk into the crystal (first key), pass gold, then Q at
	# the crystal-less cyan gate (second key).
	await _hold_right(90)
	_check(_player.is_positive(), "crystal flipped the real walk to 辉相",
		"x=%.2f" % _player.global_position.x)
	_check(_trial.has_gate_gold_passed(), "real crossing marks the gold gate passed",
		"x=%.2f" % _player.global_position.x)
	await _place_player(Vector2(475.0, 320.0))
	await _wait_physics(3)
	await _hold_right(20)
	_check(not _trial.has_gate_cyan_passed(), "cyan gate does not let the 辉相 body through")
	await _tap_polarity()
	_check(not _player.is_positive(), "Q returns the real walk to 澜相")
	await _hold_right(70)
	_check(_trial.has_gate_cyan_passed(), "real crossing marks the cyan gate passed",
		"x=%.2f" % _player.global_position.x)
	await _place_player(Vector2(880.0, 320.0))
	await _wait_physics(10)
	_check(_trial.is_arena_entered(), "arena entry wakes the guard for the hit tips")
	_check(not _has_bare_key_letter(_hud.get_objective_text()),
		"HUD objective has no bare Q/J/E/F", _hud.get_objective_text())


func _check_guard_deny_tip() -> void:
	print("=== GUARD DENY TIP ===")
	_guard.set_suspended(true)
	_guard.reset_state(Vector2(1060.0, 320.0), true, false)
	_guard.set_player_target(_player)
	_player.global_position = Vector2(1038.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.cancel_attack()
	_player.face_direction(1)
	# Guard is positive, player negative: a normal hit is opposite phase and does
	# not enter GRAVITY, so the guard's own rules return SHELL_SHATTER.
	_player.set_polarity_state(false)
	await _wait_physics(2)
	_guard.set_suspended(false)
	await _wait_physics(1)
	_push_key(KEY_J, true)
	await _wait_physics(2)
	_push_key(KEY_J, false)
	var shell_seen: bool = false
	for _index: int in range(80):
		if String(_guard.get_last_result().get("code", "")) == "SHELL_SHATTER":
			shell_seen = true
			break
		await _wait_physics(1)
	_check(shell_seen, "real J produced the first SHELL_SHATTER",
		String(_guard.get_last_result().get("code", "")))
	await _wait_process(6)
	_check(_popup.is_open() and _popup.get_current_id() == "trial_guard_deny",
		"shell-only hit opens trial_guard_deny", _popup.get_current_id())
	_check(_popup.get_title_text() == "只碎壳的一击",
		"deny tip title matches the spec", _popup.get_title_text())
	_check(_popup.get_body_text() == DENY_TIP_BODY,
		"deny tip body matches the approved copy")
	_check(not _has_bare_key_letter(_popup.get_body_text()),
		"deny tip body has no bare Q/J/E/F")
	_check(_popup.get_key_text() == "等它蓄力、换成异相再打，才会留下真伤。",
		"deny tip key plain matches the natural-sentence spec", _popup.get_key_text())
	_check(_is_natural_key(_popup.get_key_text()),
		"deny tip key is a natural sentence, not a noun+key legend")
	_check(_body_fits(DENY_TIP_BODY), "deny tip body is at most 3 lines / 21 cells")
	_check(_popup.get_demo_id() == "trial_guard_hit",
		"deny tip uses trial_guard_hit", _popup.get_demo_id())
	_check(_popup.get_demo_frame_count() == 24, "deny tip demo is 24 frames",
		str(_popup.get_demo_frame_count()))
	_check(not _trial.is_pause_open() and not _hud.is_pause_visible(),
		"deny tip does not open the pause page")
	await _tap_key(KEY_F)
	await _wait_process(6)
	_check(not _popup.is_open(), "F closes the deny tip")
	_check(MechanicTips.has_seen("trial_guard_deny"), "deny tip is remembered as seen")
	_popup.request("trial_guard_deny")
	await _wait_process(3)
	_check(not _popup.is_open(), "deny tip does not open twice")


func _check_guard_hit_tip() -> void:
	print("=== GUARD HIT TIP ===")
	_guard.set_suspended(true)
	_guard.reset_state(Vector2(1060.0, 320.0), true, true)
	_guard.set_player_target(_player)
	_player.global_position = Vector2(1038.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.cancel_attack()
	_player.face_direction(1)
	_player.set_polarity_state(false)
	await _wait_physics(2)
	_guard.set_suspended(false)
	_guard.debug_force_gravity()
	await _wait_physics(2)
	var marks_before: int = _guard.get_true_marks_taken()
	_push_key(KEY_J, true)
	await _wait_physics(2)
	_push_key(KEY_J, false)
	var true_hit: bool = false
	for _index: int in range(80):
		if _guard.get_true_marks_taken() > marks_before:
			true_hit = true
			break
		await _wait_physics(1)
	_check(true_hit, "real J in GRAVITY_CHARGE produced true damage",
		"marks=%d" % _guard.get_true_marks_taken())
	await _wait_process(6)
	_check(_popup.is_open() and _popup.get_current_id() == "trial_guard_hit",
		"first true damage opens trial_guard_hit", _popup.get_current_id())
	_check(_popup.get_title_text() == "守卫的胸口余烬",
		"hit tip title matches the spec", _popup.get_title_text())
	_check(_popup.get_body_text() == HIT_TIP_BODY,
		"hit tip body matches the approved copy")
	_check(not _has_bare_key_letter(_popup.get_body_text()),
		"hit tip body has no bare Q/J/E/F")
	_check(_popup.get_key_text() == KeyGlyph.plain(HIT_TIP_KEY),
		"hit tip key plain matches the natural-sentence spec", _popup.get_key_text())
	_check(_popup.get_key_rich_text().contains("[img=16x16]"),
		"hit tip key row renders a 16x16 keycap", _popup.get_key_rich_text())
	_check(_popup.get_footer_text() == "F 继续 · 长按空格 跳过",
		"popup footer plain keeps the F name", _popup.get_footer_text())
	_check(_popup.get_footer_rich_text().contains("[img=16x16]"),
		"popup footer renders the F keycap", _popup.get_footer_rich_text())
	_check(_is_natural_key(_popup.get_key_text()),
		"hit tip key is a natural sentence, not a noun+key legend")
	_check(_body_fits(HIT_TIP_BODY), "hit tip body is at most 3 lines / 21 cells")
	_check(_popup.get_demo_id() == "trial_guard_hit",
		"hit tip uses trial_guard_hit", _popup.get_demo_id())
	_check(_popup.get_demo_frame_count() == 24, "hit tip demo is 24 frames",
		str(_popup.get_demo_frame_count()))
	_check(not _trial.is_pause_open() and not _hud.is_pause_visible(),
		"hit tip does not open the pause page")
	await _tap_key(KEY_F)
	await _wait_process(6)
	_check(not _popup.is_open(), "F closes the hit tip")
	_check(MechanicTips.has_seen("trial_guard_hit"), "hit tip is remembered as seen")
	_popup.request("trial_guard_hit")
	await _wait_process(3)
	_check(not _popup.is_open(), "hit tip does not open twice")


func _check_pause_blocks_popup() -> void:
	print("=== PAUSE BLOCK ===")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	_check(_trial.is_pause_open(), "Esc still opens the pause page after the tips")
	_check(_trial.is_mechanic_popup_blocked(), "pause page blocks the popup")
	MechanicTips.reset_for_test()
	_popup.request("trial_guard_deny")
	await _wait_process(3)
	_check(not _popup.is_open(), "unseen tip still cannot open while paused")
	_check(not MechanicTips.has_seen("trial_guard_deny"),
		"a blocked popup is not marked seen")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	_check(not _trial.is_pause_open(), "Esc resumes from the pause page")
	_check(not get_tree().paused, "resume unpauses the tree")


func _check_recovery_blocks_popup() -> void:
	print("=== RECOVERY BLOCK ===")
	_guard.player_struck.emit(1)
	await _wait_physics(3)
	_guard.player_struck.emit(1)
	await _wait_physics(3)
	_check(_trial.is_mechanic_popup_blocked(),
		"pending failure retry blocks the popup")
	_popup.request("trial_guard_deny")
	await _wait_process(3)
	_check(not _popup.is_open(), "popup stays closed during failure recovery")
	var started: bool = false
	var finished: bool = false
	for _index: int in range(300):
		if _trial.is_recovery_active():
			started = true
		elif started:
			finished = true
			break
		await get_tree().physics_frame
	_check(started and finished, "failure recovery runs and finishes",
		"started=%s finished=%s" % [str(started), str(finished)])
	await _wait_physics(4)
	_check(not _has_bare_key_letter(_hud.get_event_text()),
		"failure/event row has no bare Q/J/E/F", _hud.get_event_text())
	_check(not _trial.is_mechanic_popup_blocked(),
		"recovery no longer blocks after it finishes")


func _check_completion_blocks_popup() -> void:
	print("=== COMPLETION BLOCK ===")
	_guard.debug_force_death()
	_guard.defeated.emit()
	await _wait_process(6)
	_player.global_position = Vector2(1204.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_physics(8)
	_check(_trial.is_completed(), "completion page reached for the block check")
	_check(_hud.is_completion_visible(), "completion overlay is visible")
	_check(_trial.is_mechanic_popup_blocked(), "completion page blocks the popup")
	_popup.request("trial_guard_deny")
	await _wait_process(3)
	_check(not _popup.is_open(), "popup stays closed on the completion page")

	# The primary 返回主界面 button is also a real mouse target, not only the
	# E shortcut covered by route_test.
	var primary: PixelMenuButton = _hud.get_completion_primary_button()
	_check(primary != null and primary.text == "返回主界面",
		"completion exposes the 返回主界面 button")
	await _push_click(primary.get_global_rect().get_center())
	var changed: bool = false
	for _index: int in range(120):
		var current: Node = get_tree().current_scene
		if current != null and current != _trial:
			changed = true
			break
		await get_tree().process_frame
	var current: Node = get_tree().current_scene
	var path: String = current.scene_file_path if current != null else ""
	_check(changed and path == "res://scenes/level_01.tscn",
		"mouse click on 返回主界面 returns to level_01.tscn", path)
