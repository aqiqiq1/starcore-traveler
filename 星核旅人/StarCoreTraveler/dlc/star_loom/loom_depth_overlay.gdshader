shader_type canvas_item;
render_mode unshaded;

// DLC3 far-hall composite.  The ColorRect covers the 960x360 city wall; the
// mask is the three glass panes only, so the stone frame, leaded bars and
// accents stay untouched.  `deep_shift` is in deep-texture UV units and is
// updated once per frame from a rounded pixel offset.

uniform sampler2D deep_texture : filter_nearest, repeat_disable;
uniform sampler2D depth_mask : filter_nearest, repeat_disable;
uniform vec2 deep_shift = vec2(0.0, 0.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 mask = texture(depth_mask, UV);
	vec2 deep_uv = vec2(UV.x * 0.75 + deep_shift.x, UV.y);
	vec4 deep = texture(deep_texture, deep_uv);
	COLOR = vec4(deep.rgb, mask.a * strength);
}
