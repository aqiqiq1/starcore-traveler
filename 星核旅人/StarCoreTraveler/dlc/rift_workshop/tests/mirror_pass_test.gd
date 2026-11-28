extends Node

## Headless assertions for the 2026-11-28 mirror pass:
##   - the DLC3 entrance is the 40x64 double mirror with the 0.35 s walk and
##     0.8 s black fade, not the old stone recess;
##   - the destination opens with a full-alpha black cover on its first frame;
##   - all six settlement pages share the 32x32 shipped game icon and no
##     longer reference the gate emblem;
##   - the mirror defeat pop is a circular 124x108 child flash with no
##     full-screen rectangle;
##   - the base-game bay uses the shared bay's insert/remove cues, flash and
##     lit blend.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/rift_workshop/tests/mirror_pass_test.tscn

const STAR_LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const BASE_BAY: String = "res://scenes/star_core_bay_visual.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _check_entrance()
	await _check_black_cover()
	await _check_emblem()
	await _check_defeat_flash()
	await _check_base_bay()
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(20)
	print("MIRROR_PASS_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _check_entrance() -> void:
	var packed: PackedScene = load(STAR_LOOM) as PackedScene
	_check(packed != null, "star loom loads for the entrance")
	if packed == null:
		return
	var level: Node = packed.instantiate()
	level.set("show_intro_guide", false)
	level.set("show_intro_cinematic", false)
	add_child(level)
	await _wait_process(4)
	var gate: MirrorRiftGate = level.call("get_hidden_rift_gate") as MirrorRiftGate
	_check(gate != null, "DLC3 exposes the mirror entrance")
	if gate == null:
		level.queue_free()
		return
	_check(gate.get_hint_text() == "双面镜 · 进入裂隙工坊",
		"entrance hint renamed to the double mirror",
		gate.get_hint_text())
	_check(gate.get_mirror_size().is_equal_approx(Vector2(40.0, 64.0)),
		"entrance footprint is 40x64", str(gate.get_mirror_size()))
	_check(absf(gate.get_walk_time() - 0.35) < 0.001,
		"entry walk is 0.35 s", str(gate.get_walk_time()))
	_check(absf(gate.get_fade_time() - 0.80) < 0.001,
		"entry fade is 0.8 s", str(gate.get_fade_time()))
	_check(gate.get_cover_alpha() == 0.0, "entry cover starts transparent")
	_check(not gate.is_ripple_active(), "idle mirror has no ripple")
	level.queue_free()
	await _wait_process(3)


func _check_black_cover() -> void:
	var host: Node2D = Node2D.new()
	add_child(host)
	await _wait_process(1)
	var cover: MirrorBlackCover = MirrorBlackCover.attach(host)
	_check(cover != null, "black cover node is created")
	if cover == null:
		host.queue_free()
		return
	# add_child() runs _ready synchronously; no process/render has happened, so
	# this is the alpha the destination's first frame is drawn with.
	_check(cover.get_alpha() >= 0.999,
		"destination first frame is fully black", "alpha=%.3f" % cover.get_alpha())
	_check(cover.is_covering(), "cover reports full coverage")
	host.queue_free()
	await _wait_process(3)


func _check_emblem() -> void:
	_check(
		CompletionEmblem.ART_ID == "game_icon_32",
		"completion art id is the shipped game icon", CompletionEmblem.ART_ID
	)
	var emblem: CompletionEmblem = CompletionEmblem.new()
	add_child(emblem)
	await _wait_process(1)
	_check(emblem.size.is_equal_approx(Vector2(32.0, 32.0)),
		"completion emblem is 32x32", str(emblem.size))
	_check(emblem.get_texture_path() == "res://assets/icon/icon_32.png",
		"completion emblem draws the game icon", emblem.get_texture_path())
	_check(emblem.has_game_icon() and emblem.is_dedicated_emblem(),
		"completion emblem really loads the icon, not a fallback drawing")
	_check(not emblem.has_mirror_art(),
		"completion emblem no longer uses the mirror art")
	_check(emblem.get_texture() != null
		and emblem.get_texture().get_size() == Vector2(32.0, 32.0),
		"game icon texture is 32x32")
	_check(not CompletionEmblem.ICON_PATH.contains("mirror")
		and not CompletionEmblem.ICON_PATH.contains("guard")
		and not CompletionEmblem.ICON_PATH.contains("star_core"),
		"completion icon path carries no mirror/guard/star-core source")
	emblem.queue_free()
	await _wait_process(2)


func _check_defeat_flash() -> void:
	var flash: RiftDefeatFlash = RiftDefeatFlash.new()
	add_child(flash)
	await _wait_process(1)
	_check(flash.has_fullscreen_rect() == false,
		"defeat flash is not a full-screen rectangle")
	_check(flash.is_circular_flash(), "defeat flash reports a circular shape")
	_check(flash.get_flash_diameter().is_equal_approx(Vector2(124.0, 108.0)),
		"defeat flash matches the boss mirror disc",
		str(flash.get_flash_diameter()))
	flash.play()
	_check(flash.is_playing(), "defeat flash starts on demand")
	_check(flash.get_flash_radius().x <= 62.0 and flash.get_flash_radius().y <= 54.0,
		"defeat flash never exceeds the mirror radius",
		str(flash.get_flash_radius()))
	await get_tree().create_timer(0.30, true).timeout
	_check(not flash.is_playing() and not flash.visible,
		"defeat flash contracts and ends within 0.30 s")
	flash.queue_free()
	await _wait_process(2)


func _check_base_bay() -> void:
	var packed: PackedScene = load(BASE_BAY) as PackedScene
	_check(packed != null, "base bay scene loads")
	if packed == null:
		return
	var bay: StarCoreBayVisual = packed.instantiate() as StarCoreBayVisual
	add_child(bay)
	await _wait_process(2)
	_check(bay.has_art(), "base bay still uses the approved base/glass PNGs")
	_check(bay.get_seat_sfx_path(true) == CoreDeliveryBay.INSERT_SFX,
		"base bay insert cue is the shared bay cue",
		bay.get_seat_sfx_path(true))
	_check(bay.get_seat_sfx_path(false) == CoreDeliveryBay.REMOVE_SFX,
		"base bay remove cue is the shared bay cue",
		bay.get_seat_sfx_path(false))
	_check(absf(StarCoreBayVisual.BAY_FLASH_TIME - 0.55) < 0.001,
		"base bay flash is the shared 0.55 s", str(StarCoreBayVisual.BAY_FLASH_TIME))
	# The cue paths are the contract under test; do not load an AudioStream in
	# this headless suite (the audio thread would outlive the quit).
	bay.set("_sfx_enabled", false)
	bay.occupied = false
	await _wait_process(3)
	var dark_lit: float = bay.get_lit_blend()
	bay.occupied = true
	await get_tree().create_timer(0.35, true).timeout
	_check(bay.get_lit_blend() > dark_lit,
		"base bay lights the shared ring on insert",
		"%.2f -> %.2f" % [dark_lit, bay.get_lit_blend()])
	_check(bay.get_flash_left() > 0.0,
		"base bay plays the shared insert flash", "%.2f" % bay.get_flash_left())
	bay.queue_free()
	await _wait_process(2)
