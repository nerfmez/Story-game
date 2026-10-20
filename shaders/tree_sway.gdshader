shader_type canvas_item;
// Trees over the school wall swaying a little in the rain wind. The crowns shift sideways by whole
// art pixels (no smooth warping, which made trees ripple like water): nothing moves at the wall top
// where the trunks stand, up to max_shift texels at the top of the screen. Each tree drifts on its
// own slow clock (phase by x), and a slow gust passes along the wall now and then.
// Sharp-bilinear sampling like smooth_pixel.gdshader (the node must use linear texture filtering).

uniform float max_shift = 2.5;     // texels at the very top
uniform float root_row = 129.0;    // texel row where the trunks stand (the wall top): no sway below
uniform float art_pixel = 1.0;     // shift in whole texels (game pixels)
uniform float speed = 0.7;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * size;
	float lift = clamp((root_row - texel.y) / root_row, 0.0, 1.0);
	float sway = sin(TIME * speed + texel.x * 0.006) * 0.7
		+ sin(TIME * speed * 0.37 - texel.x * 0.0021) * 0.3;
	float gust = smoothstep(0.6, 1.0, sin(TIME * 0.11 - texel.x * 0.0013));
	float shift = (sway * (1.0 - 0.5 * gust) + gust) * max_shift * lift * lift;
	texel.x -= floor(shift / art_pixel + 0.5) * art_pixel;
	vec2 seam = floor(texel + 0.5);
	vec2 per_px = max(fwidth(UV * size), vec2(1e-4));
	texel = seam + clamp((texel - seam) / per_px, -0.5, 0.5);
	COLOR = texture(TEXTURE, texel / size) * modulate;
}
