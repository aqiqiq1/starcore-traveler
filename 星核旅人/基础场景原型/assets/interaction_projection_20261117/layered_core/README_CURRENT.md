# Current material index (2026-11-19, approved two-state)

Current runtime (second platform face-tint material, 2026-11-19):

- `layered_core_approved_inactive_256x32.png` — proposed unlit / inactive: current old dark-purple crystal (not black). SHA `1a6ec24e…c69ac`.
- `layered_core_approved_active_256x32.png` — approved v2 internal-lit purple crystal (5 tones). SHA `4e2c412c…f9b93`.
- `layered_core_approved_mask_256x32.png` — same lower coverage/facet mask.
- `layered_core_facetflow_arrival_256x32.png` — per-facet arrival map (R) for the face-following flow; generator `make_layered_core_facetflow_arrival.py`, manifest `manifest_facetflow_20261118.json`.
- `layered_core_first_facetids_256x32.png` — first-platform facet id map for the shared face tint (R = triangle index + 1, 0 = not crystal), reproduced from the approved generator's own SEED/points/triangulation; generator `make_layered_core_first_facetids.py`, manifest `manifest_first_facetids_20261119.json`. SHA `0812b6df…67fe9`.
- `layered_linked_crystal_{base,active,mask,arrival,facetid}_200x60.png` — current LinkedWall+Lip component (second platform): long diagonal stone/crystal fold, crystal palette contact step, crystal to the left/right/bottom, facet-id map. The official linked material runs in face-tint mode with `scripts/narrative/layered_core_faces.gdshader`, using this mask as the real hit test. Generator `make_linked_crystal_candidate.py` and manifest `manifest_linked_candidate_20261118.json` retain their historical filenames (base `a91579b5…d446`, active `41366e94…9929`, mask `59f42d0a…aeec`, arrival `b4f54574…d71f`, facetid `e0ef5c1c…852b`).
- `manifest_approved_20261118.json` — palette, hashes, geometry, state mapping.
- `make_layered_core_approved_material.py` — reproducible generator (Pillow only); outputs exactly the two approved hashes above.

The shader/helper load the approved first-platform files (plus the first facet id map) and the linked candidate 200x60 set. Both components run in face-tint mode with `layered_core_faces.gdshader`: each uses its own mask as the real crossing test, and the real segment tints the crossed/adjacent facets with per-face weights (no radial spot). The first platform keeps its approved base/active/mask/arrival and its 0.7 s face-following clock; the second keeps the candidate set and the hidden-source fallback. Activation is a CPU pausable clock; no Shader.TIME. The linked component is one texture that also carries the stone cap and lip, so after it binds the runtime hides the original `LinkedWall/Visual` and `LinkedLip/Visual` (previous `visible` remembered for rebuild/cleanup); a failed bind leaves the original art as the fallback. ReturnPlatform keeps its mark.

History kept, not current:

- `layered_core_base_256x32.png`, `layered_core_mask_256x32.png`, `manifest.json`, `make_layered_core_material.py` — first layered draft.
- `layered_linked_*_200x60.png` (v1) with `make_linked_crystal_assets.py` / `manifest_linked_20261118.json` — first linked component; kept as history, no longer loaded (its lip had a purple L at the seam and the crystal read as a front slab).
- `layered_linked_v2_*_200x60.png` with `make_linked_crystal_assets_v2.py` / `manifest_linked_v2_20261118.json` — rejected by the user: thin stone strips on the left, right and bottom, and no readable thickness at the shell mouth.
- `layered_core_crystal_*` and `manifest_crystal_20261118.json` — previous crystal revision.
- `layered_linked_v3_*_200x60.png` with `make_linked_crystal_assets_v3.py` / `manifest_linked_v3_20261118.json` — rejected by the user: the short rectangular shell steps and the dark contact band read as a hard seam; replaced by the candidate assets above.
- `superseded_mother_ore_20261118/` — unaccepted mid-task trial, never wired in.
