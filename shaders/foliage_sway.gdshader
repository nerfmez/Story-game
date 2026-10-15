shader_type canvas_item;
// Leaves swaying in a light breeze, for the railway layer: only foliage moves (the
// viaduct, rails and trunks stay), by whole pixels (pixel-art look), in slow waves
// that travel along the tree line. Tree tops move more than the leaves near the deck.
// Sampled sharp-bilinear (needs linear filtering) so the slow layer still glides.

uniform float strength = 1.0;      // max shift in texels
uniform float speed = 0.9;
uniform float deck_y = 232.0;      // texel row of the rails; canopy above, lower trees below

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

// sharp-bilinear texel position (sampled in fragment(): TEXTURE can't be passed to functions)
vec2 sharp_uv(vec2 texel, vec2 per_px, vec2 size) {
	vec2 seam = floor(texel + 0.5);
	return (seam + clamp((texel - seam) / per_px, -0.5, 0.5)) / size;
}

bool leafy(vec4 c) {
	return c.a < 0.5 || (c.g > c.r && c.g >= c.b - 0.04);
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * size;
	float h = texel.y < deck_y
		? clamp((deck_y - texel.y) / 50.0, 0.0, 1.0)
		: clamp((texel.y - deck_y - 20.0) / 50.0, 0.0, 0.7);
	float wave = 0.65 * sin(TIME * speed + texel.x * 0.03 + texel.y * 0.04)
		+ 0.35 * sin(TIME * speed * 1.7 + texel.x * 0.011);
	float dx = round(wave * h * strength * 1.3);
	vec2 per_px = max(fwidth(texel), vec2(1e-4));
	vec4 c0 = texture(TEXTURE, sharp_uv(texel, per_px, size));
	vec4 c1 = texture(TEXTURE, sharp_uv(texel + vec2(dx, 0.0), per_px, size));
	COLOR = ((leafy(c0) && leafy(c1)) ? c1 : c0) * modulate;
}
