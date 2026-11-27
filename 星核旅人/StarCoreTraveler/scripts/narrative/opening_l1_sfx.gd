class_name OpeningL1Sfx
extends RefCounted

## Original, procedurally synthesised cue bank for the level-01 opening
## "地震 · 石碑 · 残响" (2026-11-27).
##
## No third-party sample is used and no audio file is added: every stream is
## 16-bit mono PCM built from sine partials, deterministic pulse noise and a
## one-pole low-pass. The chapter music is a separate BaseLevelMusic stream and
## is never touched by this bank.
##
## The opening controller plays these streams through its own pausable voices.
## All generators are deterministic, so playback and test peaks are repeatable.

const MIX_RATE: int = 22050
const TWO_PI: float = TAU


# --- 0 s: low rumble through the earthquake until the touch ----------------


static func low_rumble() -> AudioStreamWAV:
	# 9.3 s: a low two-layer bed with slow ground swell. It is stopped by the
	# opening controller at the stele touch, not by an internal fade at 2.5 s.
	var duration: float = 9.30
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	var low_pass: float = 0.0
	var seed_value: int = 9127
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.18, 0.0, 1.0)
		var release: float = 1.0 if progress < 0.965 else clampf((1.0 - progress) / 0.035, 0.0, 1.0)
		var swell: float = 0.72 + 0.28 * sin(TWO_PI * 0.17 * t + 0.6)
		var sub: float = sin(TWO_PI * 27.5 * t) * 0.17
		var body: float = sin(TWO_PI * (41.0 + 2.2 * sin(TWO_PI * 0.13 * t)) * t) * 0.25
		var grind: float = sin(TWO_PI * (61.0 + 3.5 * sin(TWO_PI * 0.21 * t + 1.1)) * t) * 0.075
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var noise: float = float(seed_value) / 1073741823.5 - 1.0
		low_pass += (noise - low_pass) * 0.035
		var grit: float = low_pass * 0.11
		samples[index] = (sub + body + grind + grit) * swell * attack * release * 0.82
	return _to_stream(samples)


static func debris(seed_value: int = 0) -> AudioStreamWAV:
	# Short dry chips of stone falling close to the camera. A fixed pulse train
	# keeps the same pattern for every replay; the seed only shifts it.
	var duration: float = 1.10
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	var starts: Array[float] = [0.05, 0.18, 0.41, 0.72, 0.96]
	var state: int = 3311 + seed_value * 977
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var value: float = 0.0
		for pulse_index: int in range(starts.size()):
			var local: float = t - starts[pulse_index]
			if local < 0.0 or local >= 0.13:
				continue
			var envelope: float = clampf(local / 0.004, 0.0, 1.0)
			envelope *= pow(1.0 - local / 0.13, 2.1)
			state = (state * 1103515245 + 12345) & 0x7fffffff
			var grain: float = float(state) / 1073741823.5 - 1.0
			var tone: float = sin(TWO_PI * (1750.0 + 340.0 * float(pulse_index)) * local) * 0.14
			var tick: float = sin(TWO_PI * (3150.0 + 170.0 * float(pulse_index)) * local) * 0.07
			value += (tone + tick + grain * 0.10) * envelope
		samples[index] = value * 0.72
	return _to_stream(samples)


static func wind_loop() -> AudioStreamWAV:
	# 6.0 s seamless cold-air bed. A 6.5 s body is crossfaded by 0.5 s so the
	# loop point has no click; the mix is filtered deterministic noise plus slow
	# sine gusts. The opening ducks this bed while the echo speaks.
	var body_seconds: float = 6.5
	var cross_seconds: float = 0.5
	var body: PackedFloat32Array = _buffer(body_seconds)
	var count: int = body.size()
	var low_pass: float = 0.0
	var seed_value: int = 7727
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var noise: float = float(seed_value) / 1073741823.5 - 1.0
		low_pass += (noise - low_pass) * 0.12
		var gust: float = 0.55 + 0.45 * sin(TWO_PI * (1.0 / 6.5) * t + 0.4)
		var slow: float = 0.35 + 0.25 * sin(TWO_PI * (2.0 / 6.5) * t + 1.7)
		var fine: float = low_pass * 0.20 + noise * 0.025
		body[index] = (fine * gust + low_pass * slow * 0.06) * 0.8
	var cross: int = int(round(cross_seconds * float(MIX_RATE)))
	var out_count: int = count - cross
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(out_count)
	for index: int in range(out_count):
		if index < cross:
			var mix: float = float(index) / float(maxi(cross - 1, 1))
			samples[index] = body[index] * mix + body[count - cross + index] * (1.0 - mix)
		else:
			samples[index] = body[index]
	return _to_stream(samples, true)


# --- 9.25 s: touch, echo, core, return --------------------------------------


static func stele_touch() -> AudioStreamWAV:
	# A dark contact thump followed by a narrow gold/cyan overtone: the stele
	# answers, and the earthquake is over.
	var duration: float = 1.05
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var thump_env: float = clampf(t / 0.008, 0.0, 1.0) * pow(1.0 - progress, 2.4)
		var tone_env: float = clampf(t / 0.12, 0.0, 1.0) * pow(1.0 - progress, 1.3)
		var thump: float = sin(TWO_PI * (54.0 - 12.0 * progress) * t) * 0.34
		var body: float = sin(TWO_PI * (196.0 + 28.0 * progress) * t) * 0.10
		var gold: float = sin(TWO_PI * 523.25 * t) * 0.10
		var cyan: float = sin(TWO_PI * 783.99 * t) * 0.055
		samples[index] = thump * thump_env + (body + gold + cyan) * tone_env
	return _to_stream(samples)


static func echo_whisper() -> AudioStreamWAV:
	# Breath before form: filtered air, a soft low vowel and a small rising
	# shimmer. No words are encoded; the page text carries the meaning.
	var duration: float = 1.40
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	var low_pass: float = 0.0
	var seed_value: int = 5519
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.22, 0.0, 1.0)
		var release: float = clampf((1.0 - progress) / 0.30, 0.0, 1.0)
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var noise: float = float(seed_value) / 1073741823.5 - 1.0
		low_pass += (noise - low_pass) * 0.09
		var breath: float = low_pass * 0.16
		var vowel: float = sin(TWO_PI * (220.0 + 6.0 * sin(TWO_PI * 4.3 * t)) * t) * 0.055
		vowel += sin(TWO_PI * 330.0 * t) * 0.030
		var shimmer: float = sin(TWO_PI * (660.0 + 180.0 * progress) * t) * 0.018
		samples[index] = (breath + vowel + shimmer) * attack * release
	return _to_stream(samples)


static func core_emerge() -> AudioStreamWAV:
	# The first core leaves the groove: a small rising crystal arpeggio.
	var duration: float = 0.95
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	var root: float = 392.0
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.035, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.8)
		var step: int = clampi(int(progress * 3.4), 0, 3)
		var note: float = root * pow(1.259921, float(step))
		var tone: float = sin(TWO_PI * note * t) * 0.22
		tone += sin(TWO_PI * note * 2.01 * t) * 0.075
		tone += sin(TWO_PI * note * 3.02 * t) * 0.035
		samples[index] = tone * attack * decay
	return _to_stream(samples)


static func core_handoff() -> AudioStreamWAV:
	# Warm three-note arrival at the chest; intentionally softer than the touch.
	var duration: float = 1.20
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.08, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.5)
		var value: float = sin(TWO_PI * 261.63 * t) * 0.10
		value += sin(TWO_PI * 329.63 * t) * 0.085
		value += sin(TWO_PI * 392.00 * t) * 0.075
		value += sin(TWO_PI * 523.25 * t) * 0.030 * clampf((progress - 0.22) / 0.3, 0.0, 1.0)
		samples[index] = value * attack * decay
	return _to_stream(samples)


static func return_whoosh() -> AudioStreamWAV:
	# A short airy pull back to the gameplay camera; not a musical sting.
	var duration: float = 0.80
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	var low_pass: float = 0.0
	var seed_value: int = 8821
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.10, 0.0, 1.0)
		var release: float = clampf((1.0 - progress) / 0.28, 0.0, 1.0)
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var noise: float = float(seed_value) / 1073741823.5 - 1.0
		low_pass += (noise - low_pass) * (0.03 + 0.22 * progress)
		var tone: float = sin(TWO_PI * (98.0 + 70.0 * progress) * t) * 0.08
		samples[index] = (low_pass * 0.30 + tone) * attack * release
	return _to_stream(samples)


# --- measurement helpers ----------------------------------------------------


static func stream_peak(stream: AudioStreamWAV) -> float:
	if stream == null:
		return 0.0
	var peak: float = 0.0
	var data: PackedByteArray = stream.data
	var index: int = 0
	while index + 1 < data.size():
		var value: float = absf(float(data.decode_s16(index)) / 32767.0)
		peak = maxf(peak, value)
		index += 2
	return peak


static func stream_seconds(stream: AudioStreamWAV) -> float:
	if stream == null or stream.mix_rate <= 0:
		return 0.0
	return float(stream.data.size() / 2) / float(stream.mix_rate)


# --- PCM helpers ------------------------------------------------------------


static func _buffer(duration: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(maxi(int(round(duration * float(MIX_RATE))), 1))
	return samples


static func _to_stream(samples: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index: int in range(samples.size()):
		var value: int = int(round(clampf(samples[index], -1.0, 1.0) * 32767.0))
		bytes.encode_s16(index * 2, value)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
