extends Node

## Audio wiring test for the 2026-11-27 hand-off.
##
##   ... --headless --path . res://dlc/rift_workshop/tests/audio_test.tscn
##
## Proves all four guarded wirings without depending on an audio device:
##   1. rift boss BGM path / loop / Master bus / start-stop,
##   2. rift defeat cue at the collapse,
##   3. title-menu BGM loop, UI click unaffected, stop on leaving the menu,
##   4. shared DemoAudio polarity switch now points at polarity_switch_v2.wav.
##
## Missing fixed-path files are a supported silent state.  The positive
## existence branch is exercised with real stand-in audio that already ships
## (loom_boss.ogg / sfx_complete.wav), so these checks keep their value even
## before the music route delivers the new files.

const RIFT_AUDIO_SCRIPT: Script = preload("res://dlc/rift_workshop/rift_audio.gd")
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"
const STAND_IN_OGG: String = "res://dlc/audio/music/loom_boss.ogg"
const STAND_IN_WAV: String = "res://dlc/rift_workshop/assets/audio/sfx_complete.wav"
const OLD_POLARITY_WAV: String = "res://assets/audio_demo_v2_20261116/polarity_switch.wav"

var _checks: int = 0
var _failures: Array[String] = []
var _rift: RiftWorkshop = null
var _level: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("RIFT_AUDIO_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _place(x: float, y: float, positive: bool) -> void:
	var player: L3Player = _rift.get_player()
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO
	player.set_polarity_state(positive)
	player.cancel_attack()
	player.clear_external_force()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(4)


func _close_popup_if_open() -> void:
	var popup: MechanicPopup = _rift.get_mechanic_popup()
	if popup == null or not popup.is_open():
		return
	_push_key(KEY_F, true)
	await _wait_process(2)
	_push_key(KEY_F, false)
	await _wait_process(4)


func _drop_scene(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	get_tree().current_scene = null
	node.queue_free()
	await _wait_process(12)


func _cleanup() -> void:
	get_tree().paused = false
	await _drop_scene(_rift)
	_rift = null
	await _drop_scene(_level)
	_level = null
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(20)


func _run() -> void:
	await _test_rift_audio_node()
	await _test_boss_and_defeat_wiring()
	await _test_title_music()
	_test_demo_audio_polarity()


# --- 1/2. rift-local BGM + defeat cue --------------------------------------

func _test_rift_audio_node() -> void:
	var audio: Node = RIFT_AUDIO_SCRIPT.new()
	audio.name = "RiftAudioProbe"
	add_child(audio)
	await _wait_process(2)
	var music_path: String = String(audio.call("get_music_path"))
	var defeat_path: String = String(audio.call("get_defeat_path"))
	_check(music_path == "res://dlc/rift_workshop/assets/audio/mirror_boss.ogg",
		"boss BGM path is the fixed hand-off path", music_path)
	_check(defeat_path == "res://dlc/rift_workshop/assets/audio/mirror_defeat.ogg",
		"boss defeat path is the fixed hand-off path", defeat_path)

	# Fixed path, absent at test time: guarded silence, not an error.
	if ResourceLoader.exists(music_path):
		_check(bool(audio.call("is_music_available")),
			"existing boss BGM file is wired", music_path)
		_check(bool(audio.call("is_music_loop")),
			"existing boss BGM file is looped", music_path)
	else:
		_check(not bool(audio.call("is_music_available")),
			"missing boss BGM stays silent without blocking", music_path)
	if ResourceLoader.exists(defeat_path):
		_check(bool(audio.call("is_defeat_available")),
			"existing defeat cue file is wired", defeat_path)
	else:
		_check(not bool(audio.call("is_defeat_available")),
			"missing defeat cue stays silent without blocking", defeat_path)

	# Positive existence branch with a shipped OGG.
	audio.call("setup_music_for_test", STAND_IN_OGG)
	_check(bool(audio.call("is_music_available")),
		"existing OGG wires the boss music player", STAND_IN_OGG)
	_check(bool(audio.call("is_music_loop")),
		"wired boss music stream loops", STAND_IN_OGG)
	var music_player: AudioStreamPlayer = audio.call("get_music_player") as AudioStreamPlayer
	_check(music_player != null and music_player.bus == &"Master",
		"boss music uses the existing Master volume bus",
		music_player.bus if music_player != null else "null")
	audio.call("start_music")
	_check(bool(audio.call("is_music_playing")),
		"boss music really starts", "starts=%d" % int(audio.call("get_music_start_count")))
	audio.call("pause_music")
	_check(bool(audio.call("is_music_paused")), "boss music pauses with the pause page")
	audio.call("resume_music")
	_check(not bool(audio.call("is_music_paused")), "boss music resumes")
	audio.call("stop_music")
	_check(not bool(audio.call("is_music_playing")), "boss music stops on request")

	# Positive existence branch for the defeat cue with a shipped WAV.
	audio.call("setup_defeat_for_test", STAND_IN_WAV)
	_check(bool(audio.call("is_defeat_available")),
		"existing WAV wires the defeat cue", STAND_IN_WAV)
	var defeat_before: int = int(audio.call("get_defeat_play_count"))
	_check(bool(audio.call("play_defeat")),
		"defeat cue plays once on request", STAND_IN_WAV)
	_check(int(audio.call("get_defeat_play_count")) == defeat_before + 1,
		"defeat cue counter increments once",
		str(int(audio.call("get_defeat_play_count"))))
	audio.queue_free()
	await _wait_process(2)


# --- chapter wiring: start on wake, stop + cue on collapse -----------------

func _test_boss_and_defeat_wiring() -> void:
	_rift = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(4)
	await _wait_physics(10)
	var audio: Node = _rift.get_node("Audio")
	audio.call("setup_music_for_test", STAND_IN_OGG)
	audio.call("setup_defeat_for_test", STAND_IN_WAV)
	await _place(1250.0, 320.0, true)
	await _wait_until(func() -> bool: return _rift.is_arena_entered(), 120)
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 200)
	await _wait_process(2)
	await _close_popup_if_open()
	var woke: bool = await _wait_until(
		func() -> bool: return _rift.is_boss_active(), 240
	)
	_check(woke, "the chapter marks the boss fight active after the opening")
	_check(bool(audio.call("is_music_playing")),
		"entering the boss fight starts the looping BGM", STAND_IN_OGG)
	_check(int(audio.call("get_music_start_count")) >= 1,
		"boss BGM start is counted", str(int(audio.call("get_music_start_count"))))

	var boss: RiftMirrorBoss = _rift.get_boss()
	var defeat_before: int = int(audio.call("get_defeat_play_count"))
	boss.debug_force_defeat()
	await _wait_physics(4)
	_check(not _rift.is_boss_active(),
		"defeat collapse clears the boss-active flag")
	_check(not bool(audio.call("is_music_playing")),
		"defeat collapse stops the boss BGM")
	_check(int(audio.call("get_defeat_play_count")) == defeat_before + 1,
		"defeat collapse plays the defeat cue exactly once",
		"%d -> %d" % [defeat_before, int(audio.call("get_defeat_play_count"))])
	audio.call("stop_all")
	await _drop_scene(_rift)
	_rift = null


# --- 3. title menu BGM -----------------------------------------------------

func _test_title_music() -> void:
	_level = (load(LEVEL_01) as PackedScene).instantiate()
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(8)
	await _wait_physics(4)
	var menu: StartMenu = _level.get_node_or_null("StartMenu") as StartMenu
	_check(menu != null and menu.is_menu_open(), "title menu is open for the BGM test")
	if menu == null:
		return
	var title_path: String = menu.get_title_music_path()
	_check(title_path == "res://assets/audio/music/title_theme.ogg",
		"title BGM path is the fixed hand-off path", title_path)
	if ResourceLoader.exists(title_path):
		_check(menu.is_title_music_available(),
			"existing title BGM file is wired", title_path)
		_check(menu.get_title_music_loop(),
			"existing title BGM file loops", title_path)
	else:
		_check(not menu.is_title_music_available(),
			"missing title BGM leaves the menu silent", title_path)

	# Positive branch with a shipped OGG.
	menu.setup_title_music_for_test(STAND_IN_OGG)
	menu.start_title_music_for_test()
	_check(menu.is_title_music_available(),
		"existing OGG wires the title music player", STAND_IN_OGG)
	_check(menu.get_title_music_loop(), "wired title BGM loops", STAND_IN_OGG)
	var player: AudioStreamPlayer = menu.get_title_music_player()
	_check(player != null and player.bus == &"Master",
		"title BGM uses the existing Master volume bus",
		player.bus if player != null else "null")
	_check(menu.is_title_music_playing(),
		"title BGM is playing while the menu is open",
		"starts=%d" % menu.get_title_music_start_count())

	# The existing UI click route is untouched by the separate music player.
	var click_before: int = DemoAudio.get_play_count("ui_click")
	DemoAudio.play_ui_click()
	_check(DemoAudio.get_play_count("ui_click") == click_before + 1,
		"title UI click still plays through DemoAudio",
		str(DemoAudio.get_play_count("ui_click")))

	menu.stop_title_music_for_test()
	_check(not menu.is_title_music_playing(), "title BGM stops on request")
	menu.start_title_music_for_test()
	menu.call("_on_start_pressed")
	await _wait_process(2)
	_check(not menu.is_title_music_playing(),
		"leaving the menu (开始游戏) stops the title BGM")
	await _drop_scene(_level)
	_level = null


# --- 4. shared polarity switch --------------------------------------------

func _test_demo_audio_polarity() -> void:
	var path: String = DemoAudio.get_event_stream_path("polarity_switch")
	_check(path == "res://assets/audio/sfx/polarity_switch_v2.wav",
		"DemoAudio polarity_switch points at the v2 WAV", path)
	_check(ResourceLoader.exists(OLD_POLARITY_WAV),
		"the old polarity_switch.wav is retained", OLD_POLARITY_WAV)
	if ResourceLoader.exists(path):
		_check(DemoAudio.load_stream_if_exists(path) != null,
			"existing v2 polarity WAV loads through the guard", path)
		var before: int = DemoAudio.get_play_count("polarity_switch")
		var played: bool = DemoAudio.play_polarity_switch()
		_check(played and DemoAudio.get_play_count("polarity_switch") == before + 1,
			"play_polarity_switch still plays the v2 WAV",
			"%s count=%d" % [path, DemoAudio.get_play_count("polarity_switch")])
	else:
		_check(DemoAudio.load_stream_if_exists(path) == null,
			"missing v2 polarity WAV is guarded, not an error", path)
	# Positive loader branch with a shipped WAV, independent of the new file.
	_check(DemoAudio.load_stream_if_exists(STAND_IN_WAV) != null,
		"the guarded loader loads an existing WAV", STAND_IN_WAV)
