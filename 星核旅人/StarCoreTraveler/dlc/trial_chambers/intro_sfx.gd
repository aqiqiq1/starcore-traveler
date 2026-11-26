class_name DlcIntroSfx
extends RefCounted

## Original, procedural cue bank for the three DLC opening films.
##
## No third-party sample is used and no binary file is added: every stream is
## 16-bit mono PCM built from sine partials and deterministic pulse noise, the
## same approach as TrialSfx.  The sounds are short and quiet; the chapter music
## keeps playing underneath because the films never pause the tree.
##
## All generators are deterministic so a replay of the same beat sounds the same
## and tests can count cues without caring about random variation.

const MIX_RATE: int = 22050
const TWO_PI: float = TAU


# --- DLC1: trial gate -------------------------------------------------------

static func crystal_pulse(frequency: float = 880.0) -> AudioStreamWAV:
	var duration: float = 0.34
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.010, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.9)
		var body: float = sin(TWO_PI * frequency * t) * 0.36
		var octave: float = sin(TWO_PI * frequency * 2.0 * t) * 0.16
		var fifth: float = sin(TWO_PI * frequency * 1.5 * t) * 0.10
		samples[index] = (body + octave + fifth) * attack * decay
	return _to_stream(samples)


static func lock_turn() -> AudioStreamWAV:
	# Low stone/metal grind with two short tooth clicks near the end.
	var duration: float = 0.58
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.020, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.4)
		var low: float = sin(TWO_PI * (72.0 + 10.0 * sin(progress * 9.0)) * t) * 0.34
		var scrape: float = sin(TWO_PI * 1430.0 * t) * 0.055
		scrape += sin(TWO_PI * 2170.0 * t) * 0.035
		var click: float = 0.0
		if (progress > 0.56 and progress < 0.60) or (progress > 0.82 and progress < 0.86):
			click = sin(TWO_PI * 3100.0 * t) * 0.22
		samples[index] = (low + scrape + click) * attack * decay
	return _to_stream(samples)


static func door_light() -> AudioStreamWAV:
	# A soft airy swell, not a musical sting: light arriving through a seam.
	var duration: float = 0.85
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.24, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.3)
		var hum: float = sin(TWO_PI * (156.0 + 44.0 * progress) * t) * 0.13
		var air: float = sin(TWO_PI * 1240.0 * t + sin(t * 31.0)) * 0.045
		air += sin(TWO_PI * 1860.0 * t) * 0.030
		samples[index] = (hum + air) * attack * decay
	return _to_stream(samples)


# --- DLC2: rift mirror ------------------------------------------------------

static func chain_rustle(seed_value: int = 0) -> AudioStreamWAV:
	# Short metallic rattles.  The seed only shifts the deterministic pattern.
	var duration: float = 0.56
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.008, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 2.0)
		var jitter: float = sin(TWO_PI * (412.0 + 18.0 * float(seed_value)) * t)
		jitter *= sin(TWO_PI * 7.0 * t + float(seed_value))
		var ring: float = sin(TWO_PI * 1860.0 * t) * 0.10
		ring += sin(TWO_PI * 2470.0 * t) * 0.07
		samples[index] = (jitter * 0.08 + ring) * attack * decay
	return _to_stream(samples)


static func mirror_eye() -> AudioStreamWAV:
	# Low mirror hum with a glassy rising open-eye shimmer.
	var duration: float = 1.10
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.16, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 0.9)
		var low: float = sin(TWO_PI * 55.0 * t) * 0.22
		var glass: float = sin(TWO_PI * (980.0 + 720.0 * progress) * t) * 0.075
		glass += sin(TWO_PI * (1470.0 + 620.0 * progress) * t) * 0.045
		var grain: float = sin(TWO_PI * 3300.0 * t) * 0.020 * sin(progress * PI)
		samples[index] = (low + glass + grain) * attack * decay
	return _to_stream(samples)


static func heartbeat() -> AudioStreamWAV:
	# Two low thumps, 0 and ~0.22 s, the second quieter.
	var duration: float = 0.55
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var value: float = 0.0
		for beat: int in range(2):
			var start: float = 0.0 if beat == 0 else 0.22
			var local: float = t - start
			if local >= 0.0 and local < 0.16:
				var env: float = clampf(local / 0.008, 0.0, 1.0)
				env *= pow(1.0 - local / 0.16, 2.0)
				var weight: float = 1.0 if beat == 0 else 0.72
				value += sin(TWO_PI * 46.0 * local) * 0.52 * env * weight
		samples[index] = value
	return _to_stream(samples)


static func plate_on(high: bool = false) -> AudioStreamWAV:
	var duration: float = 0.32
	var base: float = 1046.5 if high else 783.99
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.008, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 2.2)
		var tone: float = sin(TWO_PI * base * t) * 0.28
		tone += sin(TWO_PI * base * 2.0 * t) * 0.10
		samples[index] = tone * attack * decay
	return _to_stream(samples)


static func phase_sweep() -> AudioStreamWAV:
	# A low wave crossing the floor: pitch rises then falls away.
	var duration: float = 0.78
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.05, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.2)
		var frequency: float = 118.0 + 280.0 * sin(progress * PI)
		var body: float = sin(TWO_PI * frequency * t) * 0.24
		var overtone: float = sin(TWO_PI * frequency * 2.03 * t) * 0.09
		samples[index] = (body + overtone) * attack * decay
	return _to_stream(samples)


# --- DLC3: star loom --------------------------------------------------------

static func lamp_on(row: int = 0) -> AudioStreamWAV:
	# A soft relay click followed by a small warm hum.
	var duration: float = 0.30
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var click: float = 0.0
		if t < 0.020:
			click = sin(TWO_PI * 2600.0 * t) * (1.0 - t / 0.020) * 0.24
		var hum: float = sin(TWO_PI * (174.0 + 12.0 * float(row)) * t) * 0.10
		hum *= clampf((t - 0.010) / 0.08, 0.0, 1.0) * pow(1.0 - progress, 1.4)
		samples[index] = click + hum
	return _to_stream(samples)


static func wood_creak() -> AudioStreamWAV:
	var duration: float = 0.62
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.04, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.1)
		var wobble: float = sin(TWO_PI * 90.0 * t + sin(TWO_PI * 5.0 * t) * 2.2)
		var body: float = wobble * 0.20
		var grit: float = sin(TWO_PI * 620.0 * t) * 0.035
		grit += sin(TWO_PI * 930.0 * t) * 0.020
		samples[index] = (body + grit) * attack * decay
	return _to_stream(samples)


static func shuttle_slide() -> AudioStreamWAV:
	var duration: float = 0.44
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.03, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.4)
		var scrape: float = sin(TWO_PI * (760.0 + 180.0 * progress) * t) * 0.10
		scrape += sin(TWO_PI * 1210.0 * t) * 0.055
		var tick: float = 0.0
		if progress > 0.48 and progress < 0.52:
			tick = sin(TWO_PI * 2400.0 * t) * 0.16
		samples[index] = (scrape + tick) * attack * decay
	return _to_stream(samples)


static func orb_on(high: bool = false) -> AudioStreamWAV:
	var duration: float = 0.46
	var base: float = 392.0 if high else 261.63
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.04, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.6)
		var tone: float = sin(TWO_PI * base * t) * 0.22
		tone += sin(TWO_PI * base * 2.0 * t) * 0.08
		tone += sin(TWO_PI * base * 3.0 * t) * 0.04
		samples[index] = tone * attack * decay
	return _to_stream(samples)


static func core_ignite() -> AudioStreamWAV:
	# Rising low hum plus a bright bloom; the chapter's final beat.
	var duration: float = 1.25
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.12, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 0.8)
		var frequency: float = 82.0 + 210.0 * progress * progress
		var low: float = sin(TWO_PI * frequency * t) * 0.26
		var high: float = sin(TWO_PI * (frequency * 3.01) * t) * 0.08
		high += sin(TWO_PI * (frequency * 5.02) * t) * 0.045
		var bloom: float = sin(TWO_PI * 1046.5 * t) * 0.05 * clampf((progress - 0.45) / 0.4, 0.0, 1.0)
		samples[index] = (low + high + bloom) * attack * decay
	return _to_stream(samples)


# --- PCM helpers ------------------------------------------------------------

static func _buffer(duration: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(maxi(int(round(duration * float(MIX_RATE))), 1))
	return samples


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
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
	return stream
