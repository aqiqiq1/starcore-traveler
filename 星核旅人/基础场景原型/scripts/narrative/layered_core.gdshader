shader_type canvas_item;
render_mode unshaded;

// L2 approved crystals: face-following activation + compact local force spot.
//
// The CPU owns all state; no TIME. The real finite player-core segment is only
// a hit test. When it crosses the exposed crystal mask, the CPU passes the
// stable centre of the crossing in texture pixels; this shader draws a compact,
// near-round soft spot there (not a line-following band). The spot has no inner
// plateau: it decays smoothly from the centre and reaches zero exactly at the
// radius. The tint shifts hue far more than it adds brightness and follows each
// pixel's own facet brightness, so neighbouring bright/dark faces keep their
// step and dark purple faces are not filled in by a flat disc. Stone shell is
// never tinted. At lit 0/1 the approved inactive/active textures are exact.

uniform sampler2D ore_base_tex : filter_nearest, repeat_disable;
uniform sampler2D ore_active_tex : filter_nearest, repeat_disable;
uniform sampler2D core_mask : filter_nearest, repeat_disable;
uniform sampler2D arrival_tex : filter_nearest, repeat_disable;
uniform vec2 texture_size_px = vec2(256.0, 32.0);

// CPU pausable activation sweep. 0=inactive dark purple, 1=approved lit purple.
uniform float lit_progress : hint_range(0.0, 1.0) = 0.0;
uniform float arrival_window : hint_range(0.01, 0.5) = 0.228571;

// Compact local force spot. The line is only the mask hit test.
uniform vec2 tint_center_px = vec2(0.0, 0.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.957, 0.804, 0.388, 1.0);
uniform float tint_radius_px = 13.0;

// Gaussian falloff, normalised to exactly zero at tint_radius_px. No inner
// flat radius: the profile is highest at the centre and only decreases.
const float TINT_FALLOFF_K = 2.6;
const float TINT_FALLOFF_EDGE = 0.074273578;   // exp(-2.6)

// Hue takes over before brightness. The tint's luminance target follows the
// pixel's own facet, with a small floor so the hue stays legible on the darkest
// faces; the cap keeps pale faces from turning into white light.
const float TINT_LUM_FLOOR = 0.30;
const float TINT_LUM_GAIN = 0.80;
const float TINT_LUM_CAP = 0.60;
const float TINT_CHROMA = 1.45;

// Share of the base hue replaced at the very centre; below 1 so the crystal's
// own tone still contributes and the facet steps are not painted out.
const float TINT_BLEND_MAX = 0.78;

void fragment() {
	vec4 base = texture(ore_base_tex, UV);
	vec4 active = texture(ore_active_tex, UV);
	vec4 mk = texture(core_mask, UV);
	vec4 arrival_sample = texture(arrival_tex, UV);
	vec2 px = UV * texture_size_px;

	float arrival = arrival_sample.r;
	float local_act = smoothstep(arrival, min(1.0, arrival + arrival_window), lit_progress);
	vec3 ore = mix(base.rgb, active.rgb, local_act);

	float core = mk.a;

	if (core > 0.001 && tint_strength > 0.0001) {
		float u = clamp(length(px - tint_center_px) / tint_radius_px, 0.0, 1.0);
		float spot = (exp(-TINT_FALLOFF_K * u * u) - TINT_FALLOFF_EDGE)
			/ (1.0 - TINT_FALLOFF_EDGE);
		spot = clamp(spot, 0.0, 1.0);
		float w = spot * core * tint_strength * TINT_BLEND_MAX;

		vec3 lw = vec3(0.299, 0.587, 0.114);
		float lum = dot(ore, lw);
		float target = min(TINT_LUM_FLOOR + TINT_LUM_GAIN * lum, TINT_LUM_CAP);
		float tint_lum = max(dot(tint_color.rgb, lw), 0.0001);
		vec3 tinted = tint_color.rgb * (target / tint_lum);
		// Keep the hue's chroma instead of letting dark faces fade to grey.
		tinted = clamp(vec3(target) + (tinted - vec3(target)) * TINT_CHROMA, 0.0, 1.0);

		ore = mix(ore, tinted, clamp(w, 0.0, 1.0));
	}

	COLOR = vec4(ore, mix(base.a, active.a, local_act));
}
