shader_type canvas_item;

// Level-03-local player hit flash.
//
// The shared player texture is never edited. This shader only tints the body
// toward a clear red for the existing 0.15 s hit reaction. The per-pixel
// luminance is kept, so the outline, cloth folds and the silhouette stay
// readable instead of turning into a flat red block. Only the character sprite
// carries this material - the talisman/polarity badge, the glow, the enemies,
// the HUD and the whole screen are untouched.
//
// CanvasItem fragment COLOR already contains vertex color * default TEXTURE, so
// the texture must not be multiplied a second time. The vertex color (which
// carries CanvasItem modulate/self_modulate) is passed as a varying and the
// default texture is sampled exactly once. At hit_amount = 0.0 this produces
// the same pixels as having no material at all.
//
// hit_amount: 1.0 = full red flash, 0.0 = original texture.

uniform float hit_amount : hint_range(0.0, 1.0) = 0.0;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	// Bright pixels stay brighter, dark pixels stay shaded: the same red flash
	// keeps the sprite's internal drawing instead of hiding it.
	vec3 red = vec3(1.0, 0.17, 0.13) * (0.40 + 1.30 * luma);
	vec3 rgb = mix(tex.rgb, clamp(red, 0.0, 1.0), hit_amount);
	// One texture sample * vertex/modulate color, and the original alpha.
	COLOR = vec4(rgb, tex.a) * vertex_color;
}
