extends Node

## Tiny leak-attribution probe (not part of the 214-check suite).
##
##   Godot --headless --verbose --path . \
##     res://tests/audio_demo_v2_20261116/probe_leaks.tscn -- <mode>
##
## Modes: none | one | ten | local | local_stop | l3_rel | l3_norel
## It never runs the full suite and never stays resident; it quits after a few
## frames. Compare the "Leaked instance" lines and the final count.

const L3_SCENE: PackedScene = preload("res://scenes/level_03.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "none"
	match mode:
		"one":
			DemoAudio.play_swing()
			await _frames(3)
			DemoAudio.stop_all()
			DemoAudio.release_streams()
		"six":
			for _i: int in range(6):
				DemoAudio.play_swing()
			await _frames(3)
			DemoAudio.stop_all()
			DemoAudio.release_streams()
		"ten":
			for _i: int in range(10):
				DemoAudio.play_swing()
			await _frames(3)
			DemoAudio.stop_all()
			DemoAudio.release_streams()
		"thirty":
			for _i: int in range(30):
				DemoAudio.play_swing()
			await _frames(3)
			DemoAudio.stop_all()
			DemoAudio.release_streams()
		"one_free":
			DemoAudio.play_swing()
			await _frames(3)
			DemoAudio.stop_all()
			DemoAudio.release_streams()
			DemoAudio.free()
		"one_relonly":
			DemoAudio.play_swing()
			await _frames(3)
			DemoAudio.release_streams()
		"one_wait":
			DemoAudio.play_swing()
			await _frames(3)
			DemoAudio.stop_all()
			DemoAudio.release_streams()
			await _frames(30)
		"six_relonly":
			for _i: int in range(6):
				DemoAudio.play_swing()
			await _frames(3)
			DemoAudio.release_streams()
		"six_twostop":
			for _i: int in range(6):
				DemoAudio.play_swing()
			await _frames(3)
			DemoAudio.stop_all()
			await _frames(2)
			DemoAudio.stop_all()
			DemoAudio.release_streams()
			await _frames(2)
		"local_one_stop":
			await _local_players(1, true)
		"local_one_keep2":
			await _local_players(1, false)
		"local":
			await _local_loop(10, false)
		"local_stop":
			await _local_loop(10, true)
		"local_one_keep":
			await _local_players(1, false)
		"local6_keep":
			await _local_players(6, false)
		"local6_stop":
			await _local_players(6, true)
		"l3_rel":
			await _l3(true)
		"l3_norel":
			await _l3(false)
		"l3_cue_rel":
			await _l3_cue(true)
		"l3_cue_norel":
			await _l3_cue(false)
		_:
			pass
	await _frames(4)
	get_tree().quit(0)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _local_loop(count: int, stop_before: bool) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = &"Master"
	add_child(player)
	var stream: AudioStream = ResourceLoader.load(
		"res://assets/audio_demo_v2_20261116/swing_v2.wav", "",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	for _i: int in range(count):
		if stop_before and player.playing:
			player.stop()
		player.stream = stream
		player.play()
		await get_tree().process_frame
	player.stop()
	player.stream = null
	await _frames(2)


func _local_players(count: int, stop_after: bool) -> void:
	var stream: AudioStream = ResourceLoader.load(
		"res://assets/audio_demo_v2_20261116/swing_v2.wav", "",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	var players: Array[AudioStreamPlayer] = []
	for _i: int in range(count):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		player.stream = stream
		player.play()
		players.append(player)
	await _frames(2)
	if stop_after:
		for player: AudioStreamPlayer in players:
			player.stop()
			player.stream = null
	await _frames(2)


func _l3(release_old: bool) -> void:
	var level: Level03 = L3_SCENE.instantiate() as Level03
	get_tree().root.add_child(level)
	for _i: int in range(24):
		await get_tree().physics_frame
	if release_old:
		var bank: Node = level.get_audio()
		if bank != null and bank.has_method("release_streams"):
			bank.call("release_streams")
	if get_tree().current_scene == level:
		get_tree().current_scene = null
	level.queue_free()
	await _frames(3)


func _l3_cue(release_old: bool) -> void:
	var level: Level03 = L3_SCENE.instantiate() as Level03
	get_tree().root.add_child(level)
	for _i: int in range(24):
		await get_tree().physics_frame
	var bank: Node = level.get_audio()
	bank.call("play_charge")
	bank.call("play_slam")
	await _frames(3)
	if release_old and bank.has_method("release_streams"):
		bank.call("release_streams")
	if get_tree().current_scene == level:
		get_tree().current_scene = null
	level.queue_free()
	await _frames(3)
