shader_type spatial;
// Heat haze over hot ground on a summer afternoon (scripts/konbini_summer.gd): a
// standing ribbon that shows what is behind it, wavering a little, strongest just
// above the ground and fading to nothing at its top and ends so it has no edge.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0022;

void fragment() {
	float fade = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x) * smoothstep(0.0, 0.85, 1.0 - UV.y) * smoothstep(1.0, 0.92, 1.0 - UV.y);
	vec2 w = vec2(sin(UV.y * 38.0 - TIME * 4.2 + UV.x * 9.0), sin(UV.y * 27.0 - TIME * 3.1 + UV.x * 23.0) * 0.5);
	vec2 uv = SCREEN_UV + w * strength * fade;
	ALBEDO = textureLod(screen, uv, 0.0).rgb;
	ALPHA = fade * 0.9;
}
