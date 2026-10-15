shader_type canvas_item;
// Post-process for the HD-2D look, applied to the 3D SubViewport image:
// tilt-shift blur (top and bottom of the screen) + warm colour grade + vignette.

// Screen-height band (0 = top, 1 = bottom) that stays sharp.
uniform float focus_center : hint_range(0.0, 1.0) = 0.58;
uniform float focus_width : hint_range(0.0, 1.0) = 0.22;
uniform float blur_amount : hint_range(0.0, 6.0) = 2.5;
uniform vec3 tint : source_color = vec3(1.05, 0.97, 0.92);
uniform float saturation : hint_range(0.0, 2.0) = 1.15;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float d = max(abs(UV.y - focus_center) - focus_width, 0.0) / (1.0 - focus_width);
	float radius = blur_amount * smoothstep(0.0, 0.6, d);
	vec3 col = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 o = vec2(float(x), float(y)) * radius * TEXTURE_PIXEL_SIZE;
			float w = 1.0 / (1.0 + float(x * x + y * y));
			col += texture(TEXTURE, UV + o).rgb * w;
			total += w;
		}
	}
	col /= total;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation) * tint;
	float v = smoothstep(0.85, 0.25, length(UV - 0.5));
	col *= mix(1.0, v, vignette);
	COLOR = vec4(col, 1.0);
}
