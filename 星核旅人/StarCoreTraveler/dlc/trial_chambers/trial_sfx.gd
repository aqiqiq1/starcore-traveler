class_name TrialSfx
extends RefCounted

## Tiny original, procedural cue bank for the trial-only phase crystal and
## polarity gates.  No third-party audio is used and no file is imported: each
## stream is 16-bit mono PCM built from simple sine/triangle partials, so the
## chapter still loads when the project is copied without binary assets.
##
## The sounds are deliberately short (0.15 - 0.24 s): the gate's open/deny
## animation is 0.15 s, the crystal's activation pulse is 0.20 s.  They are
## presentation only and never own collision, phase or damage state.

const MIX_RATE: int = 22050
const TWO_PI: float = TAU


static func gate_open() -> AudioStreamWAV:
	# 0.15 s rising two-partial shimmer: airy, not a musical note.
	var duration: float = 0.15
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var frequency: float = 480.0 + 280.0 * progress
		var attack: float = clampf(t / 0.012, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.8)
		var tone: float = sin(TWO_PI * frequency * t)
		var overtone: float = sin(TWO_PI * frequency * 1.5 * t) * 0.32
		samples[index] = (tone + overtone) * attack * decay * 0.33
	return _to_stream(samples)


static func gate_deny() -> AudioStreamWAV:
	# 0.18 s low, soft thud + a short gritty tap at the start.
	var duration: float = 0.18
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var frequency: float = 104.0 - 42.0 * progress
		var attack: float = clampf(t / 0.008, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 2.2)
		var low: float = sin(TWO_PI * frequency * t)
		var body: float = sin(TWO_PI * (frequency * 0.5) * t) * 0.4
		var grit: float = 0.0
		if t < 0.035:
			# Deterministic pseudo-noise, only inside the first 35 ms.
			grit = (
				sin(TWO_PI * 1743.0 * t)
				+ sin(TWO_PI * 2371.0 * t)
				+ sin(TWO_PI * 3119.0 * t)
			) * 0.055 * (1.0 - t / 0.035)
		samples[index] = (low + body + grit) * attack * decay * 0.62
	return _to_stream(samples)


static func crystal_flip() -> AudioStreamWAV:
	# 0.24 s two-note rising chime: a clear "the crystal answered" cue.
	var duration: float = 0.24
	var samples: PackedFloat32Array = _buffer(duration)
	var count: int = samples.size()
	for index: int in range(count):
		var t: float = float(index) / float(MIX_RATE)
		var progress: float = t / duration
		var attack: float = clampf(t / 0.010, 0.0, 1.0)
		var decay: float = pow(1.0 - progress, 1.6)
		var first: float = sin(TWO_PI * 784.0 * t) * (1.0 - clampf(progress / 0.45, 0.0, 1.0))
		var second: float = sin(TWO_PI * 1174.7 * t) * clampf((progress - 0.16) / 0.30, 0.0, 1.0)
		var sparkle: float = sin(TWO_PI * 2349.3 * t) * 0.16 * decay
		samples[index] = (first * 0.38 + second * 0.34 + sparkle) * attack * decay
	return _to_stream(samples)


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
