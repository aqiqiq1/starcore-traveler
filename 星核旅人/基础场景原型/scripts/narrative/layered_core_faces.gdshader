shader_type canvas_item;
render_mode unshaded;

// Official second-platform crystal material (face-based force tint).
//
// The CPU (LayeredCoreMaterial, face mode) selects the crystal facets near the
// real finite crossing segment and passes their ids/weights. Only those pixels
// shift toward the gold/cyan hue, each at its own luminance, so intra-face
// shading and dark faces stay exactly as dark as before. No radial spot, no
// brightness floor, no glow, no line, no particles.
//
// The first platform keeps layered_core.gdshader unchanged.

uniform sampler2D base_tex : filter_nearest, repeat_disable;
uniform sampler2D active_tex : filter_nearest, repeat_disable;
uniform sampler2D mask_tex : filter_nearest, repeat_disable;
uniform sampler2D arrival_tex : filter_nearest, repeat_disable;
uniform sampler2D facetid_tex : filter_nearest, repeat_disable;
uniform vec2 texture_size_px = vec2(200.0, 60.0);

uniform float lit_progress : hint_range(0.0, 1.0) = 0.0;
uniform float arrival_window : hint_range(0.01, 0.5) = 0.228571;

uniform float face_ids[12];
uniform float face_weights[12];
uniform vec4 face_color : source_color = vec4(0.957, 0.804, 0.388, 1.0);
uniform float face_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(base_tex, UV);
	vec4 active = texture(active_tex, UV);
	vec4 mk = texture(mask_tex, UV);
	vec4 arrival_sample = texture(arrival_tex, UV);

	float arrival = arrival_sample.r;
	float local_act = smoothstep(arrival, min(1.0, arrival + arrival_window), lit_progress);
	vec3 ore = mix(base.rgb, active.rgb, local_act);

	if (mk.a > 0.001 && face_strength > 0.0001) {
		float fid = floor(texture(facetid_tex, UV).r * 255.0 + 0.5);
		float w = 0.0;
		for (int i = 0; i < 12; i++) {
			if (abs(face_ids[i] - fid) < 0.25) {
				w += face_weights[i];
			}
		}
		w = clamp(w, 0.0, 1.0) * face_strength;
		if (w > 0.001) {
			vec3 lw = vec3(0.299, 0.587, 0.114);
			float lum = dot(ore, lw);
			float tint_lum = max(dot(face_color.rgb, lw), 0.0001);
			// Same luminance, target hue; chroma is kept around that luminance
			// so dark faces read amber/teal instead of grey mud.
			vec3 hue = face_color.rgb * (lum / tint_lum);
			float hue_lum = dot(hue, lw);
			hue = clamp(vec3(hue_lum) + (hue - vec3(hue_lum)) * 2.2, 0.0, 1.0);
			ore = mix(ore, hue, w);
		}
	}

	COLOR = vec4(ore, mix(base.a, active.a, local_act));
}
