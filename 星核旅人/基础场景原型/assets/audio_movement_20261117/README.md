# audio_movement_20261117 (runtime demo trials)

Six stone footsteps and the two 0.60 s reassembly candidates for the
2026-11-17 movement pass. **Not listening-approved.**

## Footsteps (runtime, played by the local 2-voice helper)

`footstep_stone_1..6.wav` — Fantozzi / qubodup upload, *Fantozzi's Footsteps
(Grass/Sand & Stone)*, OpenGameArt, CC0 1.0. FLAC sources from the research
folder; mono 44.1 kHz PCM16; 3 ms in / 5 ms out; peaks reduced to **-9 dBFS**
(no weak take was amplified). Six variants rotate without immediate repeat.
Game: walk -18 dB / pitch 1.0; run -15 dB / pitch 1.05. The helper is local to
the player, not the DemoAudio critical pool; pause freezes, menus/recovery stop,
scene change frees it with the player.

## Reassembly

- `reassembly_a_reverse.wav` (runtime default): 0.60 s, -6 dBFS. Reversed valid
  0.14–0.60 s fragment from `assets/audio_demo_v2_20261116/shell_shatter_heavy.wav`
  (Spring Spring break_stone + Kenney impactMining_000, both CC0) plus a short
  low-mid Kenney settle. No full 1.12 s speed-up, no silent pre-tail, no end
  explosion.
- `reassembly_b_pauliuw.wav` (audition only): 0.60 s, -6 dBFS. pauliuw,
  *Stone, rock or wood moved*, OpenGameArt, CC0 1.0. The stored MP3 decodes to
  0.456 s (the research page reported 0.558 s; both values are recorded), used
  at original speed with a light settle/fade. Not loaded by the game.

## Licensing / evidence

`SOURCE_MANIFEST.json` records source SHAs, output SHAs, parameters, author/page
links, CC0 note and the evidence copies. CC0 is the uploader declaration on the
OGA pages plus the stored deed/screenshots, not a legal review. Attribution is
not required; crediting Fantozzi, pauliuw, Spring Spring and Kenney is good
practice. Q was not changed this round; no BGM is included.

Derivation script: `previews/audio_movement_20261117/generate_movement_audio.py`
(previews is gitignored; the runtime evidence copies are not).
