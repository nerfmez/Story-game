shader_type sky;
// Backdrop behind the diorama: a dark rainy-night gradient with a faint city glow low down.

uniform vec3 top_color : source_color = vec3(0.025, 0.03, 0.08);
uniform vec3 horizon_color : source_color = vec3(0.1, 0.09, 0.2);
uniform vec3 glow_color : source_color = vec3(0.2, 0.13, 0.26);

void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(-0.25, 0.7, y));
	col += glow_color * exp(-abs(y + 0.05) * 9.0) * 0.6;
	COLOR = col;
}
