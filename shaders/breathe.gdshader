shader_type canvas_item;
// Idle breathing for a pixel-art sprite, without redrawing frames: the chest
// stretches smoothly (nothing at the waist, fully at the shoulders) and the head
// rides on top, so no row is duplicated. Movement is sub-pixel, drawn with
// sharp-bilinear sampling (needs linear filtering), so it glides instead of
// popping a whole pixel.

uniform float strength = 1.0;      // 0 = off (e.g. while walking)
uniform float amount = 0.9;        // how far the shoulders rise, in texels
uniform float period = 3.8;        // seconds per breath
uniform float waist = 62.0;        // texel row where the body stays still
uniform float shoulder = 24.0;     // texel row (and everything above) that moves fully

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * size;
	// inhale = up (smooth ease in/out); weight ramps from the waist to the shoulders
	float breath = 0.5 - 0.5 * cos(TIME * 6.2831853 / period);
	float w = clamp((waist - texel.y) / (waist - shoulder), 0.0, 1.0);
	texel.y += strength * amount * breath * w;
	vec4 c = vec4(0.0);
	if (texel.y >= 0.0) {
		vec2 seam = floor(texel + 0.5);
		vec2 per_px = max(fwidth(texel), vec2(1e-4));
		vec2 t = seam + clamp((texel - seam) / per_px, -0.5, 0.5);
		c = texture(TEXTURE, t / size);
	}
	COLOR = c * modulate;
}
