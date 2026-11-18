class_name DialogueVoice
extends Node

## Minimal non-semantic echo voice used by GuideEcho and L3Cinematic.
##
## Three short human mumble syllables (SilentStrikeZ, CC0; derived from the
## lossy HQ preview) are played one at a time while text is revealed, in random
## order with no immediate repeat. A page change does not reset the last pick.
## Dense pack: ~70 ms clips made with pitch-preserving ffmpeg atempo=12/7 from
## the already-licensed 120 ms runtime WAVs (F0 unchanged; no pitch_scale, no
## boost).
## Cadence: one syllable per valid character, at most every 0.08 s, never
## overlapping; requests that arrive while a clip or the interval is busy are
## dropped, never queued or replayed as a burst. Punctuation, whitespace and
## completed/skipped text do not trigger. Pause/suspend/leave closes the page and
## stops the players; a naturally finished page lets the last clip ring out.
##
## No pitch shift, synthesis or layering: the three WAVs keep original pitch.

const DIR: String = "res://assets/interaction_projection_20261117/voice_mid/"
const FILES: Array[String] = [
	"echo_mumble_1.wav",
	"echo_mumble_2.wav",
	"echo_mumble_3.wav",
]
const VOLUME_DB: float = -10.0
const MIN_INTERVAL: float = 0.08
const CHARS_PER_BLIP: int = 1
const HISTORY_LIMIT: int = 64
const PUNCT: String = "，。、！？：；“”‘’（）《》〈〉「」『』【】…—·,.!?;:'\"()[]{}<>\\/|-_ \n\r\t"

var _players: Array[AudioStreamPlayer] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_index: int = -1
var _history: Array[int] = []
var _cooldown: float = 0.0
var _chars_since: int = 0
var _last_revealed: int = 0
var _play_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	for index: int in range(FILES.size()):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "EchoVoice%d" % (index + 1)
		player.stream = ResourceLoader.load(
			DIR + FILES[index], "", ResourceLoader.CACHE_MODE_IGNORE
		) as AudioStream
		player.volume_db = VOLUME_DB
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


func begin_page() -> void:
	stop()
	_chars_since = 0
	_last_revealed = 0


func complete_reveal() -> void:
	stop()
	_chars_since = 0


func reset() -> void:
	begin_page()


func update_text(full_text: String, revealed: int, delta: float) -> void:
	if delta > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
	var capped: int = clampi(revealed, 0, full_text.length())
	if capped <= _last_revealed:
		_last_revealed = capped
		return
	var new_text: String = full_text.substr(_last_revealed, capped - _last_revealed)
	_last_revealed = capped
	for index: int in range(new_text.length()):
		var ch: String = new_text[index]
		if not _is_valid(ch):
			continue
		_chars_since += 1
		if _chars_since < CHARS_PER_BLIP:
			continue
		if _cooldown > 0.0 or is_playing():
			continue
		_play_next()
		_chars_since = 0
		_cooldown = MIN_INTERVAL


func _is_valid(ch: String) -> bool:
	return PUNCT.find(ch) == -1


func _play_next() -> void:
	if _players.is_empty():
		return
	var index: int = _rng.randi_range(0, _players.size() - 1)
	if _players.size() > 1:
		while index == _last_index:
			index = _rng.randi_range(0, _players.size() - 1)
	var player: AudioStreamPlayer = _players[index]
	_last_index = index
	_history.append(index)
	if _history.size() > HISTORY_LIMIT:
		_history = _history.slice(_history.size() - HISTORY_LIMIT)
	if player.stream == null:
		return
	player.play()
	_play_count += 1


func stop() -> void:
	for player: AudioStreamPlayer in _players:
		if player != null:
			player.stop()
	_cooldown = 0.0


func is_playing() -> bool:
	for player: AudioStreamPlayer in _players:
		if player != null and player.playing:
			return true
	return false


func get_play_count() -> int:
	return _play_count


func reset_play_count() -> void:
	_play_count = 0


func get_last_index() -> int:
	return _last_index


func get_history() -> Array[int]:
	return _history.duplicate()


func set_seed_for_test(value: int) -> void:
	_rng.seed = value
	_last_index = -1
	_history.clear()


func get_min_interval() -> float:
	return MIN_INTERVAL


func get_history_limit() -> int:
	return HISTORY_LIMIT


func get_chars_per_blip() -> int:
	return CHARS_PER_BLIP
