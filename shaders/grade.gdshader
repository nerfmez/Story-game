shader_type canvas_item;
// Whole-screen evening grade: violet in the shadows, warm in the highlights,
// a soft vignette. Pixels are read with nearest filtering, so nothing blurs.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec3 shadow_tint = vec3(0.09, 0.03, 0.15);
uniform vec3 highlight_tint = vec3(0.08, 0.04, -0.04);
uniform float tint_amount = 0.4;
uniform float vignette = 0.3;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c += (shadow_tint * (1.0 - l) + highlight_tint * l) * tint_amount;
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	c *= 1.0 - vignette * smoothstep(0.3, 0.75, length(d));
	COLOR = vec4(c, 1.0);
}
