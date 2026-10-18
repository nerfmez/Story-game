shader_type canvas_item;
// "Sharp bilinear" for pixel art (the node must use linear texture filtering).
// Inside a texel the colour stays flat like nearest filtering; only the ~1 screen
// pixel at each texel edge is blended. So art stays crisp, but layers can sit at
// fractional positions: slow far layers glide instead of jumping one whole pixel at
// a time, and texels stay even at non-integer screen scales (phones).

// COLOR in fragment() already holds texture * modulate, so keep the modulate
// (vertex colour) from vertex() and multiply the re-sampled texture by that only.
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * size;
	vec2 seam = floor(texel + 0.5);
	vec2 per_screen_px = max(fwidth(texel), vec2(1e-4));
	texel = seam + clamp((texel - seam) / per_screen_px, -0.5, 0.5);
	COLOR = texture(TEXTURE, texel / size) * modulate;
}
