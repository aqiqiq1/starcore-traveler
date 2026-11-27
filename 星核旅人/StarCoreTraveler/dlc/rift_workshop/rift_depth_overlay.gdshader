shader_type canvas_item;
render_mode unshaded;

// DLC2 far-hall composite.  The ColorRect is a child of the Background
// CanvasLayer, aligned with the approved Back sprite.  The mask is only the
// two arch throats, so the stone frame, recess gap, inner lip, mirror hall and
// furnace breast remain untouched.  `deep_shift` is in 1880-px image units and
// is updated once per frame from rounded scroll offsets.

uniform sampler2D deep_texture : filter_nearest, repeat_disable;
uniform sampler2D depth_mask : filter_nearest, repeat_disable;
uniform vec2 deep_shift = vec2(0.0, 0.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 mask = texture(depth_mask, UV);
	vec2 deep_uv = vec2(UV.x + deep_shift.x, UV.y);
	vec4 deep = texture(deep_texture, deep_uv);
	COLOR = vec4(deep.rgb, mask.a * strength);
}
