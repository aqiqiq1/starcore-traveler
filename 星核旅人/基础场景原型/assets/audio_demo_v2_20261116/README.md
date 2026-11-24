# audio_demo_v2_20261116 (runtime, demo wiring only)

Twelve per-event SFX files wired through the `DemoAudio` autoload
(`scripts/audio/demo_audio.gd`). No music is wired.

## Nine original offline candidates

Copied byte-identically from `previews/audio_review_20261116/candidates/`.
Source: project-internal offline synthesis (`generate_audio_candidates.py`,
numpy, fixed seed 20261116), no third-party sample. 16-bit PCM mono 44.1 kHz
WAV, peak -3.0 dBFS. No new attribution obligation; this project does not claim
CC0 for its own synthesis. Hashes/uses are in `SOURCE_MANIFEST.json`.

## Three newly approved CC0-derived sounds

Built on 2026-11-17 from the approved sources in
`previews/audio_sources_v2_20261116/source/` (plus the stored Kenney Impact
Sounds zip). Parameters, source SHA256, output SHA256, CC0 note and evidence
copies are in `NEW3_DERIVATION.json` and `source_evidence/`.

| event | file | source | peak |
| --- | --- | --- | --- |
| `polarity_switch` | `polarity_switch.wav` | PWL `bell_ding1.wav` (0.52 s segment) + Bobjt `gem-gather-stereo.wav` at -12 dB | -6 dBFS |
| `swing` | `swing.wav` | artisticdude `swish-9.wav` (full 0.197 s air swing) | -6 dBFS |
| `shell_shatter` | `shell_shatter_heavy.wav` | Spring Spring `break_stone.wav` 96k→44.1k, 1.12 s + Kenney `impactMining_000` short low-mid first hit | -3 dBFS |

All three source pages declare CC0 1.0 (uploader statement; no legal review).
They may be modified, bundled with the game and redistributed with the public
source repository. Evidence screenshots and the Kenney license text are copied
into `source_evidence/` because `previews/` is gitignored. Authors: PWL, Bobjt,
artisticdude, Spring Spring (Julie Damsgaard); Kenney for the impact layer.

- Status: **demo trials, not listening-approved**. Nobody has listened to this
  pass. Q/J/shatter are wired into the real gameplay events; the old three
  candidates remain in `previews/audio_review_20261116/` for A/B and are not
  played at runtime.
- Godot uses the project default WAV import (one-shot, no loop).
- The old 12 candidates and the 6 existing OGG files are untouched;
  `assets/level03_prototype/*.ogg` keeps its own paths and cues.
- Music: no BGM file in runtime. The two CC0 tracks exist only as audition
  copies in `previews/audio_demo_v2_20261116/bgm/`.
