class_name LayeredCoreMaterial
extends Sprite2D

## Presentation-only crystal cover for ConductiveRoof or LinkedWall+Lip
## (approved 2026-11-18; second platform face mode 2026-11-19).
##
## It draws a full component-sized opaque/L-shaped material over the original
## stone sprites: the upper shell is copied verbatim from the source PNG at
## build time, the lower part is continuous star-core crystal. Both approved
## states share one facet layout and live with the masks in
## `assets/interaction_projection_20261117/layered_core/`.
##
## The second platform uses face mode: its own candidate mask/arrival/facet map
## are the real crossing test, and the real segment tints the crossed and
## adjacent facets by weight instead of drawing a radial spot. The first
## platform keeps the original shader path unchanged.
##
## The first relay store starts a ~0.7 s face-following lit flow: a per-facet
## arrival map drives connected facets in a staggered top-to-bottom order, not
## a straight row wipe. It is a CPU pausable delta clock; the shader has no
## TIME. Restore/debug snap to settled, repeated stores do not replay, and R
## returns to the dark-purple inactive.
##
## `update_force_state()` is called by Level02 after the real shared field
## calculation for this tick. Only a real, non-zero player-core pair force with
## ATTRACT/REPEL status can set a tint target, and only if the finite segment
## really crosses a mask pixel. Invalid data sets the target to zero; it never
## reuses an old valid sample as if it were live. Appear/fade uses a pausable
## delta clock, so a real pause freezes the display and resuming has no jump.
##
## This node never reads or changes gameplay state, physics, RIDs, the player,
## the core, bays, audio or the camera. It only consumes values passed in.

const BASE_TEXTURE_PATH: String = "res://assets/interaction_projection_20261117/layered_core/layered_core_approved_inactive_256x32.png"
const ACTIVE_TEXTURE_PATH: String = "res://assets/interaction_projection_20261117/layered_core/layered_core_approved_active_256x32.png"
const MASK_TEXTURE_PATH: String = "res://assets/interaction_projection_20261117/layered_core/layered_core_approved_mask_256x32.png"
const ARRIVAL_TEXTURE_PATH: String = "res://assets/interaction_projection_20261117/layered_core/layered_core_facetflow_arrival_256x32.png"
const SHADER_PATH: String = "res://scripts/narrative/layered_core.gdshader"
## Second platform face-based tint shader (2026-11-19). Preloaded so it is an
## explicit export dependency, unlike a path-only load.
const FACE_SHADER: Shader = preload("res://scripts/narrative/layered_core_faces.gdshader")
const FACE_RANGE_PX: float = 18.0
const FACE_MAX: int = 12
const FACE_ADJACENT_WEIGHT: float = 0.55
const FACE_CROSSED_WEIGHT: float = 0.95

const DEFAULT_TEXTURE_SIZE: Vector2 = Vector2(256.0, 32.0)
const MASK_ALPHA_THRESHOLD: int = 128
const TINT_RADIUS_PX: float = 13.0
## Gaussian spot profile, normalised to zero at TINT_RADIUS_PX (no inner plateau).
const TINT_FALLOFF_K: float = 2.6
const TINT_FALLOFF_EDGE: float = 0.074273578
## Maximum share of the base hue the spot replaces at its centre.
const TINT_BLEND_MAX: float = 0.78
## Hue-first luminance target for the spot: floor + gain * facet luminance,
## capped so pale facets do not become white light.
const TINT_LUM_FLOOR: float = 0.30
const TINT_LUM_GAIN: float = 0.80
const TINT_LUM_CAP: float = 0.60
const TINT_RISE_TIME: float = 0.12
const TINT_FALL_TIME: float = 0.25
const LIT_DURATION: float = 0.7
## Normalized 0.16 s soft arrival window on the 0.7 s CPU clock.
const ARRIVAL_WINDOW: float = 0.16 / 0.7
const COLOR_TIME: float = 0.12

const GOLD: Color = Color(0.957, 0.804, 0.388, 1.0)   # amulet positive
const CYAN: Color = Color(0.372, 0.882, 0.902, 1.0)   # amulet negative

var _configured: bool = false
var _unlocked: bool = false
var _lit_target: float = 0.0
var _lit_progress: float = 0.0
var _activation_elapsed: float = 0.0
var _tint_target: float = 0.0
var _tint_strength: float = 0.0
var _tint_color_target: Color = GOLD
var _tint_color_current: Color = GOLD

var _line_valid: bool = false
var _line_intersects_mask: bool = false
var _line_a_px: Vector2 = Vector2.ZERO
var _line_b_px: Vector2 = Vector2.ZERO
var _line_hit_samples: int = 0
var _tint_center_px: Vector2 = Vector2.ZERO

var _last_status: String = ""
var _last_blocked: bool = false
var _last_core_active: bool = false
var _last_pair_core_force: Vector2 = Vector2.ZERO
var _last_pair_player_force: Vector2 = Vector2.ZERO
var _last_player_center: Vector2 = Vector2.ZERO
var _last_core_center: Vector2 = Vector2.ZERO
var _last_player_positive: bool = true

var _material: ShaderMaterial = null
var _texture_size: Vector2 = DEFAULT_TEXTURE_SIZE
var _mask_image: Image = null
var _mask_pixel_count: int = 0
var _arrival_image: Image = null

## Face-tint mode (second platform). The same node owns the real hit test and
## activation; it only changes how the force tint is drawn.
var _face_mode: bool = false
var _facet_image: Image = null
var _facet_centroids: Dictionary = {}
var _facet_neighbors: Dictionary = {}
var _face_ids: PackedFloat32Array = PackedFloat32Array()
var _face_weights: PackedFloat32Array = PackedFloat32Array()
var _active_faces: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1          # activation node is z=2 -> this draws at effective z=1
	z_as_relative = true
	visible = false
	set_process(false)


## Aligns the cover to the real roof Sprite2D. The source roof PNG is loaded
## only for its dimensions elsewhere; this cover owns its own original images.
func setup(roof_sprite: Sprite2D) -> bool:
	return setup_custom(roof_sprite, BASE_TEXTURE_PATH, ACTIVE_TEXTURE_PATH,
		MASK_TEXTURE_PATH, ARRIVAL_TEXTURE_PATH, DEFAULT_TEXTURE_SIZE)


## Reusable setup for another crystal component (for example LinkedWall+Lip).
## The anchor sprite supplies only the world transform; all four textures carry
## the component's own shell/crystal/mask/arrival at `size`.
func setup_custom(anchor_sprite: Sprite2D, base_path: String, active_path: String,
		mask_path: String, arrival_path: String, size: Vector2) -> bool:
	if anchor_sprite == null or anchor_sprite.texture == null:
		push_warning("LayeredCoreMaterial: anchor visual missing; material disabled")
		return false
	if anchor_sprite.centered:
		push_warning("LayeredCoreMaterial: centered anchor sprite unsupported; material disabled")
		return false
	var base_tex: Texture2D = load(base_path) as Texture2D
	var active_tex: Texture2D = load(active_path) as Texture2D
	var mask_tex: Texture2D = load(mask_path) as Texture2D
	var arrival_tex: Texture2D = load(arrival_path) as Texture2D
	var shader: Shader = load(SHADER_PATH) as Shader
	if base_tex == null or active_tex == null or mask_tex == null \
		or arrival_tex == null or shader == null:
		push_warning("LayeredCoreMaterial: crystal base/active/mask/arrival/shader missing; material disabled")
		return false
	if Vector2(base_tex.get_width(), base_tex.get_height()) != size \
		or Vector2(active_tex.get_width(), active_tex.get_height()) != size \
		or Vector2(mask_tex.get_width(), mask_tex.get_height()) != size \
		or Vector2(arrival_tex.get_width(), arrival_tex.get_height()) != size:
		push_warning("LayeredCoreMaterial: texture size is not %s; material disabled" % size)
		return false
	_texture_size = size
	_mask_image = mask_tex.get_image()
	_arrival_image = arrival_tex.get_image()
	if _mask_image == null or _arrival_image == null:
		push_warning("LayeredCoreMaterial: mask/arrival image unavailable; material disabled")
		return false
	if _mask_image.is_compressed():
		_mask_image.decompress()
	if _arrival_image.is_compressed():
		_arrival_image.decompress()
	_mask_pixel_count = 0
	for y: int in range(int(_texture_size.y)):
		for x: int in range(int(_texture_size.x)):
			if _mask_image.get_pixel(x, y).a * 255.0 >= float(MASK_ALPHA_THRESHOLD):
				_mask_pixel_count += 1
	if _mask_pixel_count <= 0:
		push_warning("LayeredCoreMaterial: mask has no exposed core pixels; material disabled")
		_mask_image = null
		_arrival_image = null
		return false

	texture = base_tex
	_material = ShaderMaterial.new()
	_material.shader = shader
	# Custom samplers are not the Sprite2D's built-in TEXTURE; bind all four.
	_material.set_shader_parameter("ore_base_tex", base_tex)
	_material.set_shader_parameter("ore_active_tex", active_tex)
	_material.set_shader_parameter("core_mask", mask_tex)
	_material.set_shader_parameter("arrival_tex", arrival_tex)
	material = _material
	# Same transform as the anchor stone sprite; the texture is 1:1 with its
	# own pixel grid and centered=false on both.
	global_transform = anchor_sprite.global_transform
	visible = true
	_configured = true
	_apply_uniforms()
	return true


## Second-platform face mode: the component's own candidate mask/arrival/facet
## map are the hit-test and activation source (no v3 mask judge-first step).
## Textures arrive as preloaded resources so the export keeps them.
func setup_face_tint(anchor_sprite: Sprite2D, base_tex: Texture2D,
		active_tex: Texture2D, mask_tex: Texture2D, arrival_tex: Texture2D,
		facet_tex: Texture2D, size: Vector2) -> bool:
	if anchor_sprite == null or anchor_sprite.texture == null:
		push_warning("LayeredCoreMaterial: face anchor visual missing; material disabled")
		return false
	if anchor_sprite.centered:
		push_warning("LayeredCoreMaterial: centered anchor sprite unsupported")
		return false
	if base_tex == null or active_tex == null or mask_tex == null \
		or arrival_tex == null or facet_tex == null:
		push_warning("LayeredCoreMaterial: face textures missing; material disabled")
		return false
	if Vector2(base_tex.get_width(), base_tex.get_height()) != size \
		or Vector2(active_tex.get_width(), active_tex.get_height()) != size \
		or Vector2(mask_tex.get_width(), mask_tex.get_height()) != size \
		or Vector2(arrival_tex.get_width(), arrival_tex.get_height()) != size \
		or Vector2(facet_tex.get_width(), facet_tex.get_height()) != size:
		push_warning("LayeredCoreMaterial: face texture size is not %s" % size)
		return false
	_texture_size = size
	_mask_image = mask_tex.get_image()
	_arrival_image = arrival_tex.get_image()
	_facet_image = facet_tex.get_image()
	if _mask_image == null or _arrival_image == null or _facet_image == null:
		push_warning("LayeredCoreMaterial: face mask/arrival/facet image unavailable")
		return false
	for img: Image in [_mask_image, _arrival_image, _facet_image]:
		if img.is_compressed():
			img.decompress()
	_mask_pixel_count = 0
	for y: int in range(int(_texture_size.y)):
		for x: int in range(int(_texture_size.x)):
			if _mask_image.get_pixel(x, y).a * 255.0 >= float(MASK_ALPHA_THRESHOLD):
				_mask_pixel_count += 1
	if _mask_pixel_count <= 0:
		push_warning("LayeredCoreMaterial: face mask has no exposed core pixels")
		return false
	_build_faces()
	if _facet_centroids.is_empty():
		push_warning("LayeredCoreMaterial: facet map has no faces")
		return false

	_face_mode = true
	_face_ids.resize(FACE_MAX)
	_face_weights.resize(FACE_MAX)
	for i: int in range(FACE_MAX):
		_face_ids[i] = -1.0
		_face_weights[i] = 0.0

	texture = base_tex
	_material = ShaderMaterial.new()
	_material.shader = FACE_SHADER
	_material.set_shader_parameter("base_tex", base_tex)
	_material.set_shader_parameter("active_tex", active_tex)
	_material.set_shader_parameter("mask_tex", mask_tex)
	_material.set_shader_parameter("arrival_tex", arrival_tex)
	_material.set_shader_parameter("facetid_tex", facet_tex)
	material = _material
	global_transform = anchor_sprite.global_transform
	visible = true
	_configured = true
	_apply_uniforms()
	return true


## Visible pixel centroid + edge adjacency per facet id, from the facet map.
func _build_faces() -> void:
	_facet_centroids.clear()
	_facet_neighbors.clear()
	var sums: Dictionary = {}
	var w: int = int(_texture_size.x)
	var h: int = int(_texture_size.y)
	for y: int in range(h):
		for x: int in range(w):
			if _mask_image.get_pixel(x, y).a < 0.5:
				continue
			var id: int = int(roundf(_facet_image.get_pixel(x, y).r * 255.0))
			if id <= 0:
				continue
			var rec: Dictionary = sums.get(id, {"x": 0.0, "y": 0.0, "n": 0})
			rec["x"] = float(rec["x"]) + float(x) + 0.5
			rec["y"] = float(rec["y"]) + float(y) + 0.5
			rec["n"] = int(rec["n"]) + 1
			sums[id] = rec
	for id: int in sums.keys():
		var rec: Dictionary = sums[id]
		var n: int = int(rec["n"])
		_facet_centroids[id] = Vector2(float(rec["x"]) / n, float(rec["y"]) / n)
	for y: int in range(h):
		for x: int in range(w):
			if _mask_image.get_pixel(x, y).a < 0.5:
				continue
			var id: int = int(roundf(_facet_image.get_pixel(x, y).r * 255.0))
			if id <= 0:
				continue
			for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nx: int = x + off.x
				var ny: int = y + off.y
				if nx >= w or ny >= h:
					continue
				if _mask_image.get_pixel(nx, ny).a < 0.5:
					continue
				var other: int = int(roundf(_facet_image.get_pixel(nx, ny).r * 255.0))
				if other <= 0 or other == id:
					continue
				var a: Array = _facet_neighbors.get(id, [])
				if not a.has(other):
					a.append(other)
				_facet_neighbors[id] = a
				var b: Array = _facet_neighbors.get(other, [])
				if not b.has(id):
					b.append(id)
				_facet_neighbors[other] = b


func _line_face_hits(a: Vector2, b: Vector2) -> Dictionary:
	var hits: Dictionary = {}
	if _mask_image == null or _facet_image == null:
		return hits
	var length: float = a.distance_to(b)
	if length <= 0.001:
		return hits
	var steps: int = maxi(2, int(ceilf(length * 2.0)))
	for i: int in range(steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		var x: int = int(floorf(p.x))
		var y: int = int(floorf(p.y))
		if x < 0 or y < 0 or x >= int(_texture_size.x) or y >= int(_texture_size.y):
			continue
		if _mask_alpha_at_px(p) <= 0.0:
			continue
		var id: int = int(roundf(_facet_image.get_pixel(x, y).r * 255.0))
		if id > 0:
			hits[id] = int(hits.get(id, 0)) + 1
	return hits


## Crossed faces get a strong fixed weight; edge neighbours a mid one; the rest
## fade with distance from the segment (compact, no long line-shaped stain).
func _update_face_weights(a: Vector2, b: Vector2) -> void:
	var hits: Dictionary = _line_face_hits(a, b)
	var picked: Array[Dictionary] = []
	for id: int in _facet_centroids.keys():
		var c: Vector2 = _facet_centroids[id]
		var d: float = _point_segment_distance(c, a, b)
		var crossed: bool = hits.has(id)
		var adjacent: bool = false
		if not crossed:
			for n: Variant in _facet_neighbors.get(id, []):
				if hits.has(int(n)):
					adjacent = true
					break
		if not crossed and not adjacent and d > FACE_RANGE_PX:
			continue
		var w: float = pow(clampf(1.0 - d / FACE_RANGE_PX, 0.0, 1.0), 0.9)
		if adjacent:
			w = maxf(w, FACE_ADJACENT_WEIGHT)
		if crossed:
			w = maxf(w, FACE_CROSSED_WEIGHT)
		if w <= 0.01:
			continue
		picked.append({"id": id, "w": w, "d": d, "crossed": crossed})
	picked.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["w"]) > float(y["w"]))
	if picked.size() > FACE_MAX:
		picked.resize(FACE_MAX)
	_active_faces = picked
	for i: int in range(FACE_MAX):
		if i < picked.size():
			_face_ids[i] = float(picked[i]["id"])
			_face_weights[i] = float(picked[i]["w"])
		else:
			_face_ids[i] = -1.0
			_face_weights[i] = 0.0
	if _material != null:
		_material.set_shader_parameter("face_ids", _face_ids)
		_material.set_shader_parameter("face_weights", _face_weights)


func _clear_faces() -> void:
	if not _face_mode:
		return
	_active_faces.clear()
	if _face_ids.size() == FACE_MAX:
		for i: int in range(FACE_MAX):
			_face_ids[i] = -1.0
			_face_weights[i] = 0.0
	if _material != null:
		_material.set_shader_parameter("face_ids", _face_ids)
		_material.set_shader_parameter("face_weights", _face_weights)


func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## False immediately returns to the approved dark-purple inactive (R/restart),
## not black, and clears tint. True is the first relay completion: animate_first
## starts the ~0.7 s face-following lit flow. A restore/debug/repeat call with
## animate_first=false snaps directly to the approved settled bright state and
## never replays.
func set_unlocked(unlocked: bool, animate_first: bool = false) -> void:
	_unlocked = unlocked
	if not unlocked:
		_lit_target = 0.0
		_lit_progress = 0.0
		_activation_elapsed = 0.0
		_tint_target = 0.0
		_tint_strength = 0.0
		_line_valid = false
		_line_intersects_mask = false
		_tint_color_current = _tint_color_target
		_clear_faces()
		_apply_uniforms()
		set_process(false)
		return
	_lit_target = 1.0
	if not animate_first:
		_lit_progress = 1.0
		_activation_elapsed = LIT_DURATION
		_apply_uniforms()
		# A restore can arrive during a live tint; do not freeze its clock.
		set_process(_tint_strength > 0.0001 or _tint_target > 0.0001)
	else:
		# First unlock starts from the inactive dark state. If a caller somehow
		# already has progress, continue from it; no pulse/loop is created.
		_activation_elapsed = 0.0
		_lit_progress = 0.0
		_apply_uniforms()
		set_process(true)


## Called by Level02 once per unpaused physics tick, after the shared field
## calculation. Values are the real state of that tick, not a shader bypass.
func update_force_state(
	core_active: bool,
	status: String,
	blocked: bool,
	pair_core_force: Vector2,
	pair_player_force: Vector2,
	player_center: Vector2,
	core_center: Vector2,
	player_positive: bool
) -> void:
	_last_core_active = core_active
	_last_status = status
	_last_blocked = blocked
	_last_pair_core_force = pair_core_force
	_last_pair_player_force = pair_player_force
	_last_player_center = player_center
	_last_core_center = core_center
	_last_player_positive = player_positive
	_tint_color_target = GOLD if player_positive else CYAN
	if _tint_strength <= 0.0001 and _tint_target <= 0.0001:
		# Nothing visible: adopt the current amulet colour without a stale lerp.
		_tint_color_current = _tint_color_target

	var status_ok: bool = status == "ATTRACT" or status == "REPEL"
	var force_nonzero: bool = (
		pair_core_force.length() > 0.001 or pair_player_force.length() > 0.001
	)
	if not _unlocked or not core_active or blocked or not status_ok or not force_nonzero:
		# Target zero immediately. The shader may keep the last valid segment
		# only for the 0.25 s fade already in progress; it is not reported as a
		# live sample and no new endpoints are accepted from this invalid frame.
		_line_valid = false
		_line_intersects_mask = false
		_tint_target = 0.0
		_keep_processing_if_visible()
		return

	var a: Vector2 = _world_to_px(player_center)
	var b: Vector2 = _world_to_px(core_center)
	var run: Dictionary = _longest_mask_run(a, b)
	var hits: int = int(run.get("hits", 0))
	if hits <= 0:
		_line_valid = false
		_line_intersects_mask = false
		_line_hit_samples = 0
		_tint_target = 0.0
		_keep_processing_if_visible()
		return

	_line_a_px = a
	_line_b_px = b
	if _face_mode:
		_update_face_weights(a, b)
	else:
		_tint_center_px = run["center"]
	_line_valid = true
	_line_intersects_mask = true
	_line_hit_samples = hits
	_tint_target = 1.0
	set_process(true)


func clear_force_target() -> void:
	_line_valid = false
	_line_intersects_mask = false
	_tint_target = 0.0
	_keep_processing_if_visible()


func _keep_processing_if_visible() -> void:
	if _tint_strength > 0.0001 or _tint_target > 0.0001 \
		or not is_equal_approx(_lit_progress, _lit_target):
		set_process(true)


func _process(delta: float) -> void:
	if not _configured:
		set_process(false)
		return
	var moving: bool = false
	if not is_equal_approx(_lit_progress, _lit_target):
		if _lit_progress < _lit_target:
			_activation_elapsed = minf(_activation_elapsed + delta, LIT_DURATION)
			var p: float = clampf(_activation_elapsed / LIT_DURATION, 0.0, 1.0)
			# Smooth temporal easing; the shader adds the soft spatial wavefront.
			_lit_progress = p * p * (3.0 - 2.0 * p)
			moving = true
		else:
			_lit_progress = 0.0
			_activation_elapsed = 0.0
			moving = true

	if _tint_strength < _tint_target:
		_tint_strength = minf(_tint_strength + delta / TINT_RISE_TIME, _tint_target)
		moving = true
	elif _tint_strength > _tint_target:
		_tint_strength = maxf(_tint_strength - delta / TINT_FALL_TIME, _tint_target)
		moving = true

	if not _tint_color_current.is_equal_approx(_tint_color_target):
		var step: float = clampf(delta / COLOR_TIME, 0.0, 1.0)
		_tint_color_current = _tint_color_current.lerp(_tint_color_target, step)
		if absf(_tint_color_current.r - _tint_color_target.r) < 0.004 \
			and absf(_tint_color_current.g - _tint_color_target.g) < 0.004 \
			and absf(_tint_color_current.b - _tint_color_target.b) < 0.004:
			_tint_color_current = _tint_color_target
		moving = true

	_apply_uniforms()
	if _face_mode and _tint_strength <= 0.0001 and _tint_target <= 0.0001 \
		and not _active_faces.is_empty():
		_clear_faces()
	if not moving:
		set_process(false)


func _apply_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("texture_size_px", _texture_size)
	_material.set_shader_parameter("lit_progress", _lit_progress)
	_material.set_shader_parameter("arrival_window", ARRIVAL_WINDOW)
	if _face_mode:
		_material.set_shader_parameter("face_ids", _face_ids)
		_material.set_shader_parameter("face_weights", _face_weights)
		_material.set_shader_parameter("face_color", _tint_color_current)
		_material.set_shader_parameter("face_strength", _tint_strength)
		return
	_material.set_shader_parameter("tint_center_px", _tint_center_px)
	_material.set_shader_parameter("tint_strength", _tint_strength)
	_material.set_shader_parameter("tint_color", _tint_color_current)
	_material.set_shader_parameter("tint_radius_px", TINT_RADIUS_PX)


# --- coordinate / mask helpers ---------------------------------------------

func _world_to_px(world: Vector2) -> Vector2:
	return to_local(world)


func _mask_alpha_at_px(px: Vector2) -> float:
	if _mask_image == null:
		return 0.0
	var x: int = int(floorf(px.x))
	var y: int = int(floorf(px.y))
	if x < 0 or y < 0 or x >= int(_texture_size.x) or y >= int(_texture_size.y):
		return 0.0
	var a: float = _mask_image.get_pixel(x, y).a
	return a if a * 255.0 >= float(MASK_ALPHA_THRESHOLD) else 0.0


## Samples the finite segment in texture-pixel space and returns the longest
## contiguous run of exposed crystal. The run midpoint is the stable compact
## spot centre; the line itself is not rendered. A 0.5 px step cannot skip the
## 11..14 px band.
func _longest_mask_run(a: Vector2, b: Vector2) -> Dictionary:
	if _mask_image == null:
		return {"hits": 0, "center": Vector2.ZERO}
	var length: float = a.distance_to(b)
	if length <= 0.001:
		return {"hits": 0, "center": Vector2.ZERO}
	var steps: int = maxi(2, int(ceilf(length * 2.0)))
	var best_start: int = -1
	var best_end: int = -1
	var cur_start: int = -1
	for i: int in range(steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		var hit: bool = _mask_alpha_at_px(p) > 0.0
		if hit and cur_start < 0:
			cur_start = i
		elif not hit and cur_start >= 0:
			if best_start < 0 or (i - cur_start) > (best_end - best_start):
				best_start = cur_start
				best_end = i - 1
			cur_start = -1
	if cur_start >= 0:
		if best_start < 0 or (steps + 1 - cur_start) > (best_end - best_start):
			best_start = cur_start
			best_end = steps
	if best_start < 0:
		return {"hits": 0, "center": Vector2.ZERO}
	var mid_t: float = (float(best_start) + float(best_end)) * 0.5 / float(steps)
	return {"hits": best_end - best_start + 1, "center": a.lerp(b, mid_t)}


## CPU mirror of the shader's compact spot weight for inspection. Same
## plateau-free Gaussian profile as the shader; the shader additionally caps the
## replace share at TINT_BLEND_MAX, which is not part of the spatial weight.
func get_weight_at_world(world: Vector2) -> float:
	if not _configured or not _line_valid or _tint_strength <= 0.0001:
		return 0.0
	var px: Vector2 = _world_to_px(world)
	var mask: float = _mask_alpha_at_px(px)
	if mask <= 0.0:
		return 0.0
	var u: float = clampf(px.distance_to(_tint_center_px) / TINT_RADIUS_PX, 0.0, 1.0)
	var spot: float = clampf((exp(-TINT_FALLOFF_K * u * u) - TINT_FALLOFF_EDGE)
		/ (1.0 - TINT_FALLOFF_EDGE), 0.0, 1.0)
	return mask * spot * _tint_strength


# --- read-only accessors ----------------------------------------------------

func is_configured() -> bool:
	return _configured


func is_unlocked() -> bool:
	return _unlocked


func is_line_valid() -> bool:
	return _line_valid


func did_line_intersect_mask() -> bool:
	return _line_intersects_mask


func is_face_mode() -> bool:
	return _face_mode


func get_face_count() -> int:
	return _facet_centroids.size()


func get_face_centroid_px(id: int) -> Vector2:
	return _facet_centroids.get(id, Vector2.ZERO)


## Faces tinted by the last valid real crossing (id / weight / distance).
func get_active_faces() -> Array[Dictionary]:
	return _active_faces.duplicate()


func get_line_hit_samples() -> int:
	return _line_hit_samples


func get_lit_progress() -> float:
	return _lit_progress


func get_lit_target() -> float:
	return _lit_target


func get_activation_elapsed() -> float:
	return _activation_elapsed


func get_lit_duration() -> float:
	return LIT_DURATION


func get_arrival_window() -> float:
	return ARRIVAL_WINDOW


func get_arrival_at_px(x: int, y: int) -> float:
	if _arrival_image == null:
		return 0.0
	if x < 0 or x >= int(_texture_size.x) or y < 0 or y >= int(_texture_size.y):
		return 0.0
	return _arrival_image.get_pixel(x, y).r


## CPU mirror of the face-following activation for diagnostics. Actual
## rendering is driven by the shader's arrival_tex/lit_progress uniforms.
func get_lit_weight_at_px(x: int, y: int) -> float:
	if not _configured or _mask_image == null or _arrival_image == null:
		return 0.0
	if x < 0 or x >= int(_texture_size.x) or y < 0 or y >= int(_texture_size.y):
		return 0.0
	var mask: float = _mask_alpha_at_px(Vector2(float(x), float(y)))
	if mask <= 0.0:
		return 0.0
	var arrival: float = _arrival_image.get_pixel(x, y).r
	return smoothstep(arrival, minf(1.0, arrival + ARRIVAL_WINDOW), _lit_progress) * mask


func get_tint_strength() -> float:
	return _tint_strength


func get_tint_target() -> float:
	return _tint_target


func get_tint_color_current() -> Color:
	return _tint_color_current


func get_tint_color_target() -> Color:
	return _tint_color_target


func get_line_px() -> Array:
	return [_line_a_px.x, _line_a_px.y, _line_b_px.x, _line_b_px.y]


func get_mask_pixel_count() -> int:
	return _mask_pixel_count


func get_texture_size() -> Vector2:
	return _texture_size


func get_tint_radius_px() -> float:
	return TINT_RADIUS_PX


func get_tint_blend_max() -> float:
	return TINT_BLEND_MAX


func get_tint_center_px() -> Vector2:
	return _tint_center_px


func get_tint_feather_px() -> float:
	# Continuous radial falloff; there is no separate flat inner radius.
	return 0.0


func get_last_status() -> String:
	return _last_status


func was_last_blocked() -> bool:
	return _last_blocked


func was_core_active() -> bool:
	return _last_core_active


func get_last_pair_forces() -> Array:
	return [
		_last_pair_core_force.x, _last_pair_core_force.y,
		_last_pair_player_force.x, _last_pair_player_force.y,
	]


func get_last_player_positive() -> bool:
	return _last_player_positive


func get_last_player_center() -> Vector2:
	return _last_player_center


func get_last_core_center() -> Vector2:
	return _last_core_center


## First exposed row in a texture column (i.e. upper shell thickness there).
func get_shell_thickness_at_px(x: int) -> int:
	if _mask_image == null or x < 0 or x >= int(_texture_size.x):
		return 0
	for y: int in range(int(_texture_size.y)):
		if _mask_alpha_at_px(Vector2(float(x), float(y))) > 0.0:
			return y
	return int(_texture_size.y)


func get_mask_alpha_px(x: int, y: int) -> float:
	return _mask_alpha_at_px(Vector2(float(x), float(y)))


func get_state() -> Dictionary:
	return {
		"configured": _configured,
		"unlocked": _unlocked,
		"lit_progress": _lit_progress,
		"lit_target": _lit_target,
		"activation_elapsed": _activation_elapsed,
		"lit_duration": LIT_DURATION,
		"arrival_window": ARRIVAL_WINDOW,
		"arrival_window_s": ARRIVAL_WINDOW * LIT_DURATION,
		"tint_strength": _tint_strength,
		"tint_target": _tint_target,
		"tint_color": [_tint_color_current.r, _tint_color_current.g,
			_tint_color_current.b, _tint_color_current.a],
		"tint_color_target": [_tint_color_target.r, _tint_color_target.g,
			_tint_color_target.b, _tint_color_target.a],
		"line_valid": _line_valid,
		"line_intersects_mask": _line_intersects_mask,
		"line_hit_samples": _line_hit_samples,
		"tint_center_px": [_tint_center_px.x, _tint_center_px.y],
		"line_px": get_line_px(),
		"last_status": _last_status,
		"last_blocked": _last_blocked,
		"last_core_active": _last_core_active,
		"last_pair_forces": get_last_pair_forces(),
		"last_player_positive": _last_player_positive,
		"last_player_center": [_last_player_center.x, _last_player_center.y],
		"last_core_center": [_last_core_center.x, _last_core_center.y],
		"mask_pixels": _mask_pixel_count,
	}
